/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: Video toolbox clock enable DCO
    (c) 2026 by Parretto B.V.

    Digitally controlled oscillator for the video clock recovery, for a video clock that can't be
    tuned (Altera Agilex 5). The video clock runs slightly faster than the pixel clock of the source.
    A numerically controlled oscillator in the video clock domain drops a fraction of the clock
    cycles with the clock enable of the video toolbox and the DPTX, so the average pixel rate
    follows the source.

    The controller output of the clock recovery (direct I2C access interface) sets the increment:
        increment = base + (controller output >>> shift)
    The clock enable is the carry of the 32-bit phase accumulator, so the fraction of enabled cycles
    is increment / 2^32. When the DCO is disabled the clock enable is always asserted.

    History
    =======
    v1.0 - Initial release

    License
    =======
    This License will apply to the use of the IP-core (as defined in the License).
    Please read the License carefully so that you know what your rights and obligations are when using the IP-core.
    The acceptance of this License constitutes a valid and binding agreement between Parretto and you for the use of the IP-core.
    If you download and/or make any use of the IP-core you agree to be bound by this License.
    The License is available for download and print at www.parretto.com/license
    Parretto grants you, as the Licensee, a free, non-exclusive, non-transferable, limited right to use the IP-core
    solely for internal business purposes for the term and conditions of the License.
    You are also allowed to create Modifications for internal business purposes, but explicitly only under the conditions of art. 3.2.
    You are, however, obliged to pay the License Fees to Parretto for the use of the IP-core, or any Modification, in, or embodied in,
    a physical or non-tangible product or service that has substantial commercial, industrial or non-consumer uses.
*/

`default_nettype none

module prt_vtb_dco
(
    // System
    input wire          SYS_RST_IN,         // Reset
    input wire          SYS_CLK_IN,         // Clock

    // Control
    input wire          CTL_EN_IN,          // Enable
    input wire          CTL_INV_IN,         // Invert the controller output
    input wire [4:0]    CTL_SHIFT_IN,       // Shift of the controller output
    input wire [31:0]   CTL_BASE_IN,        // Base increment

    // Status
    output wire [31:0]  STA_INC_OUT,        // Current increment

    // Controller output (direct I2C access interface of the video toolbox)
    input wire [31:0]   DIA_DAT_IN,         // Data
    input wire          DIA_VLD_IN,         // Valid
    output wire         DIA_RDY_OUT,        // Ready

    // Video
    input wire          VID_CLK_IN,         // Clock
    output wire         VID_CKE_OUT         // Clock enable
);

/*
    System clock domain
*/

logic signed [28:0] co;                     // Controller output
logic [31:0]        inc;                    // Increment
logic               dia_rdy;
logic               dia_vld_del;
logic               upd_tgl;                // Toggle to the video clock domain
logic [2:0]         ack_sync;               // Toggle returned by the video clock domain
logic [31:0]        inc_hold;               // Increment for the video clock domain

// Video clock domain
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
logic [2:0]         vclk_sync = '0;
logic               vclk_tgl = 0;
logic [31:0]        vclk_inc = '1;
logic [32:0]        vclk_acc = '0;
logic               vclk_cke = 1;

// Controller output
// The video toolbox asserts valid when ready is asserted and clears it when ready is deasserted.
always_ff @ (posedge SYS_CLK_IN)
begin
    if (SYS_RST_IN)
    begin
        dia_rdy <= 1;
        dia_vld_del <= 0;
        co <= '0;
    end

    else
    begin
        dia_vld_del <= DIA_VLD_IN;

        // New controller output
        if (DIA_VLD_IN && !dia_vld_del)
        begin
            co <= DIA_DAT_IN[28:0];
            dia_rdy <= 0;
        end

        // Handshake done
        else if (!DIA_VLD_IN)
            dia_rdy <= 1;
    end
end

assign DIA_RDY_OUT = dia_rdy;

// Increment
// Saturates at the limits of the 32-bit increment
always_ff @ (posedge SYS_CLK_IN)
begin
    logic signed [33:0] corr;
    logic signed [33:0] sum;

    corr = (CTL_INV_IN) ? -(34'(co) >>> CTL_SHIFT_IN) : (34'(co) >>> CTL_SHIFT_IN);
    sum = $signed({2'b00, CTL_BASE_IN}) + corr;

    if (sum < 0)
        inc <= '0;
    else if (sum > 34'sh0_ffff_ffff)
        inc <= '1;
    else
        inc <= sum[31:0];
end

// The increment goes to the video clock domain with a toggle handshake
always_ff @ (posedge SYS_CLK_IN)
begin
    if (SYS_RST_IN)
    begin
        upd_tgl <= 0;
        inc_hold <= '1;
        ack_sync <= '0;
    end

    else
    begin
        ack_sync <= {ack_sync[1:0], vclk_tgl};

        // The video clock domain has taken over the previous value
        if (ack_sync[2] == upd_tgl)
        begin
            inc_hold <= (CTL_EN_IN) ? inc : '1;
            upd_tgl <= ~upd_tgl;
        end
    end
end

/*
    Video clock domain
*/

always_ff @ (posedge VID_CLK_IN)
begin
    vclk_sync <= {vclk_sync[1:0], upd_tgl};

    // New increment (the system clock domain holds it stable until the toggle is returned)
    if (vclk_sync[2] != vclk_tgl)
    begin
        vclk_inc <= inc_hold;
        vclk_tgl <= vclk_sync[2];
    end

    // Phase accumulator
    // The clock enable is the carry. An increment of all ones enables nearly every cycle;
    // with the DCO disabled the clock enable is always asserted.
    vclk_acc <= {1'b0, vclk_acc[31:0]} + {1'b0, vclk_inc};
    vclk_cke <= vclk_acc[32] || (vclk_inc == '1);
end

assign VID_CKE_OUT = vclk_cke;
assign STA_INC_OUT = inc_hold;

endmodule

`default_nettype wire
