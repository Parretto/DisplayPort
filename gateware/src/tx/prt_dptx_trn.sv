/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP TX Training
    (c) 2021 - 2025 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Updated interface

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

module prt_dptx_trn
#(
    // System
    parameter P_VENDOR      = "none",      // Vendor - "AMD", "ALTERA" or "LSC" 

    // PHY
    parameter P_LANES       = 2,           // Lanes
    parameter P_SPL         = 2,           // Symbols per lane

    // Message
    parameter P_MSG_IDX     = 5,          // Message index width
    parameter P_MSG_DAT     = 16,         // Message data width
    parameter P_MSG_ID      = 0           // Message ID Training Pattern Sequence
)
(
    // Reset and clock
    input wire              RST_IN,
    input wire              CLK_IN,

    // Control
    input wire [1:0]        CTL_LANES_IN,   // Active lanes (1 - 1 lane / 2 - 2 lanes / 3 - 4 lanes)
    input wire              CTL_SEL_IN,     // Select 0 - main link / 1 - training 

    // Message
    prt_dp_msg_if.snk       MSG_SNK_IF,     // Sink
    prt_dp_msg_if.src       MSG_SRC_IF,     // Source

    // Link 
    prt_dp_tx_phy_if.snk    LNK_SNK_IF,    // Sink
    prt_dp_tx_phy_if.src    LNK_SRC_IF     // Source
);

// Parameters
localparam P_DAT_WIDTH = 11;
localparam P_RAM_WRDS = 32;
localparam P_RAM_ADR = $clog2(P_RAM_WRDS);
localparam P_RAM_DAT = P_SPL * P_DAT_WIDTH;

// Structures
typedef struct {
    logic	[P_MSG_IDX-1:0]	      idx;
    logic                         first;
    logic                         last;
	logic	[P_MSG_DAT-1:0]	      dat;
	logic				          vld;
} msg_struct;

typedef struct {
    logic	[P_RAM_ADR-1:0]	      wp;                // Write pointer
	logic	[P_SPL-1:0]	          wr;                // Write
    logic   [P_SPL-1:0]           wr_msk;            // Write mask 
    logic	[P_RAM_DAT-1:0]	      din;               // Write data
    logic	[P_RAM_ADR-1:0]	      rp;                // Read pointer
	logic				          rd;                // Read 
	logic	[P_RAM_DAT-1:0]	      dout[0:P_SPL-1];   // Read data
} ram_struct;   

typedef struct {
    logic   [1:0]           lanes;                              // Active lanes
    logic                   sel;                                // Select (0 - pass trough / 1 - training)
    logic   [P_SPL-1:0]     disp_ctl[0:P_LANES-1];              // Disparity control (0-automatic / 1-force)
    logic   [P_SPL-1:0]     disp_val[0:P_LANES-1];              // Disparity value (0-negative / 1-postive) 
    logic   [P_SPL-1:0]     k[0:P_LANES-1];                     // k character
    logic   [7:0]           dat[0:P_LANES-1][0:P_SPL-1];        // Data
    logic   [P_SPL-1:0]     disp_ctl_reg[0:P_LANES-1];          // Disparity control registered (0-automatic / 1-force)
    logic   [P_SPL-1:0]     disp_val_reg[0:P_LANES-1];          // Disparity value registered (0-negative / 1-postive) 
    logic   [P_SPL-1:0]     k_reg[0:P_LANES-1];                 // k character registered 
    logic   [7:0]           dat_reg[0:P_LANES-1][0:P_SPL-1];    // Data registered 
} lnk_struct;   

// Signals
msg_struct  clk_msg;
ram_struct  clk_ram;
lnk_struct  clk_lnk;

genvar i;

// Inputs
    always_ff @ (posedge CLK_IN)
    begin
        clk_lnk.lanes   <= CTL_LANES_IN;
        clk_lnk.sel     <= CTL_SEL_IN;
    end

// Message Slave
    prt_dp_msg_slv_egr
    #(
        .P_ID           (P_MSG_ID),       // Identifier
        .P_IDX_WIDTH    (P_MSG_IDX),      // Index width
        .P_DAT_WIDTH    (P_MSG_DAT)       // Data width
    )
    MSG_SLV_EGR_INST
    (
        // Reset and clock
        .RST_IN         (RST_IN),
        .CLK_IN         (CLK_IN),

        // MSG sink
        .MSG_SNK_IF     (MSG_SNK_IF),

        // MSG source
        .MSG_SRC_IF     (MSG_SRC_IF),

        // Eggress
        .EGR_IDX_OUT    (clk_msg.idx),    // Index
        .EGR_FIRST_OUT  (clk_msg.first),  // First
        .EGR_LAST_OUT   (clk_msg.last),   // Last
        .EGR_DAT_OUT    (clk_msg.dat),    // Data
        .EGR_VLD_OUT    (clk_msg.vld)     // Valid
    );

// RAM
generate
    for (i = 0; i < P_SPL; i++)
    begin : gen_ram
    	prt_dp_lib_sdp_ram_sc
    	#(
    		.P_VENDOR       (P_VENDOR),
            .P_RAM_STYLE	("distributed"),	// "distributed", "block" or "ultra"
    		.P_ADR_WIDTH 	(P_RAM_ADR),
    		.P_DAT_WIDTH 	(P_RAM_DAT)
    	)
    	RAM_INST
    	(
    		// Clocks and reset
    		.RST_IN		(RST_IN),			    // Reset
    		.CLK_IN		(CLK_IN),			    // Clock

    		// Port A
            .A_ADR_IN   (clk_ram.wp),           // Write pointer
    		.A_WR_IN	(clk_ram.wr[i]),		// Write in
    		.A_DAT_IN	(clk_ram.din),		    // Write data

    		// Read
            .B_EN_IN    (1'b1),                 // Enable
            .B_ADR_IN   (clk_ram.rp),           // Read pointer
    		.B_RD_IN	(clk_ram.rd),	    	// Read in
    		.B_DAT_OUT  (clk_ram.dout[i]),		// Data out
    		.B_VLD_OUT	()		                // Valid
    	);
    end
endgenerate

// Write pointer
    always_ff @ (posedge CLK_IN)
    begin
        // Clear
        // The first message will clear the write pointer
        if (clk_msg.first)
            clk_ram.wp <= 0;

        // Increment
        else if (clk_ram.wr[P_SPL-1])
            clk_ram.wp <= clk_ram.wp + 'd1;
    end

// Write data
    assign clk_ram.din = clk_msg.dat[P_DAT_WIDTH-1:0];

// Write mask
    always_ff @ (posedge CLK_IN)
    begin
        // Clear
        // The first message will set the write mask
        if (clk_msg.first)
            clk_ram.wr_msk <= 'b1;

        // Shift
        else if (clk_msg.vld)
            clk_ram.wr_msk <= {clk_ram.wr_msk[P_SPL-2:0], clk_ram.wr_msk[P_SPL-1]};
    end

// Write
    always_comb
    begin
        clk_ram.wr = 0;

        // Valid
        if (clk_msg.vld && !clk_msg.first)
            clk_ram.wr = clk_ram.wr_msk;
    end

// Read pointer
    always_ff @ (posedge CLK_IN)
    begin
        if (clk_ram.rd)
        begin
            // Restart
            if (clk_ram.rp == (clk_ram.wp - 'd1))
                clk_ram.rp <= 0;

            // Increment
            else
                clk_ram.rp <= clk_ram.rp + 'd1;
        end

        else
            clk_ram.rp <= 0;
    end

// Read
    always_ff @ (posedge RST_IN, posedge CLK_IN)
    begin
        // Reset
        if (RST_IN)
            clk_ram.rd <= 0;

        else
        begin
            // Stop reading when a new message arrives
            if (clk_msg.first)
                clk_ram.rd <= 0;

            // Start reading again at the end of the message
            else if (clk_msg.last)
                clk_ram.rd <= 1;
        end
    end

// Output Mux
    always_comb
    begin
        for (int i = 0; i < P_LANES; i++)
        begin
            // Training
            if (clk_lnk.sel)
            begin
                for (int j = 0; j < P_SPL; j++)
                    {clk_lnk.disp_ctl[i][j], clk_lnk.disp_val[i][j], clk_lnk.k[i][j], clk_lnk.dat[i][j]} = clk_ram.dout[j];
            end

            // Sink
            else
            begin
                clk_lnk.disp_ctl[i] = LNK_SNK_IF.disp_ctl[i];
                clk_lnk.disp_val[i] = LNK_SNK_IF.disp_val[i];
                clk_lnk.k[i]        = LNK_SNK_IF.k[i];
                clk_lnk.dat[i]      = LNK_SNK_IF.dat[i];
            end
        end
    end

// Output registers
generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_output
        always_ff @ (posedge CLK_IN)
        begin
            // Disable two upper lanes when only one lane is active
            if (((i == 1) || (i == 2) || (i == 3)) && (clk_lnk.lanes == 'd1))
            begin
                clk_lnk.disp_ctl_reg[i] <= 0;
                clk_lnk.disp_val_reg[i] <= 0;
                clk_lnk.k_reg[i]        <= 0;
                clk_lnk.dat_reg[i]      <= '{P_SPL{0}};
            end

            // Disable two upper lanes when only two lanes are active
            else if (((i == 2) || (i == 3)) && (clk_lnk.lanes == 'd2))
            begin
                clk_lnk.disp_ctl_reg[i] <= 0;
                clk_lnk.disp_val_reg[i] <= 0;
                clk_lnk.k_reg[i]        <= 0;
                clk_lnk.dat_reg[i]      <= '{P_SPL{0}};
            end

            else
            begin
                clk_lnk.disp_ctl_reg[i] <= clk_lnk.disp_ctl[i];
                clk_lnk.disp_val_reg[i] <= clk_lnk.disp_val[i];
                clk_lnk.k_reg[i]        <= clk_lnk.k[i];
                clk_lnk.dat_reg[i]      <= clk_lnk.dat[i];
            end
        end
    end
endgenerate

// Outputs
generate
    for (i = 0; i < P_LANES; i++)
    begin
        assign LNK_SRC_IF.disp_ctl[i]   = clk_lnk.disp_ctl_reg[i];
        assign LNK_SRC_IF.disp_val[i]   = clk_lnk.disp_val_reg[i];
        assign LNK_SRC_IF.k[i]          = clk_lnk.k_reg[i];
        assign LNK_SRC_IF.dat[i]        = clk_lnk.dat_reg[i];
    end
endgenerate

endmodule

`default_nettype wire
