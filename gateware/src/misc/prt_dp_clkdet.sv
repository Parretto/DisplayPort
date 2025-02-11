/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP Clock Detector
    (c) 2021 - 2025 by Parretto B.V.

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

// Module
module prt_dp_clkdet
(
    // System reset and clock
    input wire      SYS_RST_IN,
    input wire      SYS_CLK_IN,

    // Monitor reset and clock
    input wire      MON_RST_IN,
    input wire      MON_CLK_IN,

    // Status
    output wire     STA_ACT_OUT     // Active
);

// Signals
logic [3:0]     mclk_cnt;
logic           mclk_cnt_end;
logic           mclk_beacon;

wire            sclk_beacon;
wire            sclk_beacon_re;
wire            sclk_beacon_fe;
logic [7:0]     sclk_cnt;
logic           sclk_cnt_end;
logic           sclk_act;

/*
    Monitor domain
*/

// Counter
    always_ff @ (posedge MON_RST_IN, posedge MON_CLK_IN)
    begin
        // Reset
        if (MON_RST_IN)
            mclk_cnt <= 0;

        else
        begin
            // Load
            if (mclk_cnt_end)
                mclk_cnt <= '1;

            // Decrement
            else
                mclk_cnt <= mclk_cnt - 'd1;
        end
    end

// Clock counter end
    always_comb
    begin
        if (mclk_cnt == 0)
            mclk_cnt_end = 1;
        else
            mclk_cnt_end = 0;
    end

// Beacon
// This signal will toggle when the monitor clock is running
    always_ff @ (posedge MON_RST_IN, posedge MON_CLK_IN)
    begin
        // Reset
        if (MON_RST_IN)
            mclk_beacon <= 0;

        else
        begin
            if (mclk_cnt_end)
                mclk_beacon <= ~mclk_beacon;
        end
    end

// Clock domain Adapter
// This crosses the beacon signal from the link domain to the system domain
    prt_dp_lib_cdc_bit
    BEACON_CDC_INST
    (
    	.SRC_CLK_IN      (MON_CLK_IN),	// Clock
    	.SRC_DAT_IN      (mclk_beacon),	// Data
    	.DST_CLK_IN      (SYS_CLK_IN),	// Clock
    	.DST_DAT_OUT     (sclk_beacon)	// Data
    );

/*
    System domain
*/

// Beacon edge detector
    prt_dp_lib_edge
    BEACON_EDGE_INST
    (
    	.CLK_IN    (SYS_CLK_IN),	   // Clock
    	.CKE_IN    (1'b1),			   // Clock enable
    	.A_IN      (sclk_beacon),	   // Input
    	.RE_OUT    (sclk_beacon_re),   // Rising edge
    	.FE_OUT	   (sclk_beacon_fe)	   // Falling edge
    );

// Counter
    always_ff @ (posedge SYS_RST_IN, posedge SYS_CLK_IN)
    begin
        // Reset
        if (SYS_RST_IN)
            sclk_cnt <= 0;

        else
        begin
            // Load
            if (sclk_beacon_re || sclk_beacon_fe)
                sclk_cnt <= '1;

            // Decrement
            else if (!sclk_cnt_end)
                sclk_cnt <= sclk_cnt - 'd1;
        end
    end

// Counter end
    always_comb
    begin
        if (sclk_cnt == 0)
            sclk_cnt_end = 1;
        else
            sclk_cnt_end = 0;
    end

// Active flag
// This flag is asserted when a link clock is detected.
    always_ff @ (posedge SYS_RST_IN, posedge SYS_CLK_IN)
    begin
        // Reset
        if (SYS_RST_IN)
            sclk_act <= 0;

        else
        begin
            // Set
            if (sclk_beacon_re || sclk_beacon_fe)
                sclk_act <= 1;

            // Clear
            else if (sclk_cnt_end)
                sclk_act <= 0;
        end
    end

// Outputs
    assign STA_ACT_OUT = sclk_act;

endmodule

`default_nettype wire
