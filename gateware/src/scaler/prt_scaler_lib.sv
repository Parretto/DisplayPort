/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Scaler Library
    (c) 2022 by Parretto B.V.

    History
    =======
    v1.0 - Initial release

    License
    =======
    This License will apply to the use of the IP-core (as defined in the License). 
    Please read the License carefully so that you know what your rights and obligations are when using the IP-core.
    The acceptance of this License constitutes a valid and binding agreement between Parretto and you for the use of the IP-core. 
    If you download and/or make any use of the IP-core you agree to be bound by this License. 
    The License is available for download and print at www.parretto.com/license.html
    Parretto grants you, as the Licensee, a free, non-exclusive, non-transferable, limited right to use the IP-core 
    solely for internal business purposes for the term and conditions of the License. 
    You are also allowed to create Modifications for internal business purposes, but explicitly only under the conditions of art. 3.2.
    You are, however, obliged to pay the License Fees to Parretto for the use of the IP-core, or any Modification, in, or embodied in, 
    a physical or non-tangible product or service that has substantial commercial, industrial or non-consumer uses. 
*/

`timescale 1 ps / 1 ps
`default_nettype none

/*
	Edge Detector
*/
module prt_scaler_lib_edge
(
	input wire	CLK_IN,			// Clock
	input wire	CKE_IN,			// Clock enable
	input wire	A_IN,			// Input
	output wire	RE_OUT,			// Rising edge
	output wire	FE_OUT			// Falling edge
);

// Signals
logic clk_a_del;
logic clk_a_re;
logic clk_a_fe;

// Logic
// Input Registers
	always_ff @ (posedge CLK_IN)
	begin
			// Clock enable
			if (CKE_IN)
				clk_a_del	<= A_IN;
	end

// Rising Edge Detector
	always_comb
	begin
		if (A_IN && !clk_a_del)
			clk_a_re = 1;
		else
			clk_a_re = 0;
	end

// Falling Edge Detector
	always_comb
	begin
		if (!A_IN && clk_a_del)
			clk_a_fe = 1;
		else
			clk_a_fe = 0;
	end

// Outputs
	assign RE_OUT = clk_a_re;
	assign FE_OUT = clk_a_fe;

endmodule

/*
	Bit clock domain crossing
*/
module prt_scaler_lib_cdc_bit
(
	input wire		SRC_CLK_IN,		// Clock
	input wire 		SRC_DAT_IN,		// Data
	input wire		DST_CLK_IN,		// Clock
	output wire 	DST_DAT_OUT		// Data
);

// Parameters
localparam P_STAGES = 4;

// Signals
// The signals must have an unique name,
// so they can be found by the set_false_path constraint
(* dont_touch = "yes" *) logic 					prt_scaler_lib_cdc_bit_sclk_dat;
(* dont_touch = "yes" *) logic [P_STAGES-1:0]	prt_scaler_lib_cdc_bit_dclk_dat;

// Logic

// Source register
	always_ff @ (posedge SRC_CLK_IN)
	begin
		prt_scaler_lib_cdc_bit_sclk_dat <= SRC_DAT_IN;
	end

// Destination register
	always_ff @ (posedge DST_CLK_IN)
	begin
		prt_scaler_lib_cdc_bit_dclk_dat <= {prt_scaler_lib_cdc_bit_dclk_dat[0+:P_STAGES-1], prt_scaler_lib_cdc_bit_sclk_dat};
	end

// Output
	assign DST_DAT_OUT = prt_scaler_lib_cdc_bit_dclk_dat[P_STAGES-1];

endmodule


/*
	Single clock FIFO
*/
module prt_scaler_lib_fifo_sc
#(
	parameter							P_MODE         = "single",		// "single" or "burst"
	parameter 						P_RAM_STYLE	= "distributed",	// "distributed" or "block"
	parameter							P_WRDS 		= 128,
	parameter 						P_ADR_WIDTH 	= 7,
	parameter							P_DAT_WIDTH 	= 512
)
(
	// Clocks and reset
	input wire						RST_IN,		// Reset
	input wire						CLK_IN,		// Clock
	input wire						CLR_IN,		// Clear

	// Write
	input wire						WR_EN_IN,		// Write enable
	input wire						WR_IN,		// Write in
	input wire 	[P_DAT_WIDTH-1:0]		DAT_IN,		// Write data

	// Read
	input wire						RD_EN_IN,		// Read enable in
	input wire						RD_IN,		// Read in
	output wire [P_DAT_WIDTH-1:0]			DAT_OUT,		// Data out
	output wire						DE_OUT,		// Data enable

	// Status
	output wire	[P_ADR_WIDTH:0]		WRDS_OUT,		// Used words
	output wire						EP_OUT,		// Empty
	output wire						FL_OUT		// Full
);

// Signals
(* ram_style = P_RAM_STYLE *) logic	[P_DAT_WIDTH-1:0]	clk_ram[0:P_WRDS-1];

logic	[P_ADR_WIDTH-1:0]		clk_wp;			// Write pointer
logic 	[P_ADR_WIDTH-1:0]		clk_rp;			// Read pointer
logic	[P_DAT_WIDTH-1:0]		prt_scaler_lib_dout;
logic	[P_DAT_WIDTH-1:0]		prt_scaler_lib_dout_reg;
logic	[1:0]				clk_da;
logic	[1:0]				clk_de;
logic	[P_ADR_WIDTH-1:0]		clk_wrds;
logic						clk_ep;
logic						clk_fl;

// Logic

// Write memory
// Registered
	always_ff @ (posedge CLK_IN)
	begin
		// Write enable
		if (WR_EN_IN)
		begin
			// Write
			if (WR_IN)
				clk_ram[clk_wp] <= DAT_IN;
		end
	end

// Read memory
generate
	if (P_RAM_STYLE == "block")
	begin : gen_dout_block
		always_ff @ (posedge CLK_IN)
		begin
			// Read enable
			if (RD_EN_IN)
			begin
				prt_scaler_lib_dout <= clk_ram[clk_rp];
				prt_scaler_lib_dout_reg <= prt_scaler_lib_dout;
			end
		end
	end

	else
	begin : gen_dout_distributed
		assign prt_scaler_lib_dout_reg = clk_ram[clk_rp];
	end
endgenerate

// Write pointer
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		if (RST_IN)
			clk_wp <= 0;

		else
		begin
			// Clear
			if (CLR_IN)
				clk_wp <= 0;

			// Write enable
			else if (WR_EN_IN)
			begin
				// Write
				if (WR_IN)
				begin
					// Check for overflow
					if (&clk_wp)
						clk_wp <= 0;
					else
						clk_wp <= clk_wp + 'd1;
				end
			end
		end
	end

// Read pointer
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		if (RST_IN)
			clk_rp <= 0;

		else
		begin
			// Clear
			if (CLR_IN)
				clk_rp <= 0;

			// Read enable
			else if (RD_EN_IN)
			begin
				// Read
				if (RD_IN && !clk_ep)
				begin
					// Check for overflow
					if (&clk_rp)
						clk_rp <= 0;
					else
						clk_rp <= clk_rp + 'd1;
				end
			end
		end
	end

// Data available
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		if (RST_IN)
			clk_da <= 0;

		else
		begin
			// Enable
			if (RD_EN_IN)
			begin
				if (clk_ep || RD_IN)
					clk_da <= 0;
				else
				begin
					clk_da[0] <= 1;
					clk_da[1] <= clk_da[0];
				end
			end
		end
	end

// Data enable
generate
	if (P_RAM_STYLE == "distributed")
	begin
		always_comb
		begin
			if (RD_IN && !clk_ep)
				clk_de = 'b01;
			else
				clk_de = 'b00;
		end
	end

	else
	begin
		always_ff @ (posedge RST_IN, posedge CLK_IN)
		begin
			if (RST_IN)
				clk_de <= 0;

			else
			begin
				// Enable
				if (RD_EN_IN)
				begin
					if (!clk_ep)
						clk_de[0] <= RD_IN;
					else
						clk_de[0] <= 0;
					clk_de[1] <= clk_de[0];
				end
			end
		end
	end
endgenerate

// Empty
// Must be combinatorial
	always_comb
	begin
		if (clk_wp == clk_rp)
			clk_ep = 1;
		else
			clk_ep = 0;
	end

// Full
// Must be combinatorial
	always_comb
	begin
		if (clk_wrds > (P_WRDS - 'd2))
			clk_fl = 1;
		else
			clk_fl = 0;
	end

// Words
	always_comb
	begin
		if (clk_wp > clk_rp)
			clk_wrds = clk_wp - clk_rp;

		else if (clk_wp < clk_rp)
			clk_wrds = (P_WRDS - clk_rp) + clk_wp;

		else
			clk_wrds = 0;
	end

// Outputs
	assign DAT_OUT 	= prt_scaler_lib_dout_reg;
	assign DE_OUT 		= (P_MODE == "burst") ? ((P_RAM_STYLE == "block") ? clk_de[$size(clk_de)-1] : clk_de[0]) : ((P_RAM_STYLE == "block") ? clk_da[$size(clk_da)-1] : clk_da[0]);
	assign WRDS_OUT 	= clk_wrds;
	assign EP_OUT 		= clk_ep;
	assign FL_OUT 		= clk_fl;

endmodule

/*
	Simple dual port RAM dual clock
*/
module prt_scaler_lib_sdp_ram_dc
#(
	parameter 					P_RAM_STYLE	= "distributed",	// "distributed", "block" or "ultra"
	parameter 					P_ADR_WIDTH 	= 7,
	parameter						P_DAT_WIDTH 	= 512
)
(
	// Port A
	input wire					A_RST_IN,		// Reset
	input wire					A_CLK_IN,		// Clock
	input wire [P_ADR_WIDTH-1:0]		A_ADR_IN,		// Address
	input wire					A_WR_IN,		// Write in
	input wire [P_DAT_WIDTH-1:0]		A_DAT_IN,		// Write data

	// Port B
	input wire					B_RST_IN,		// Reset
	input wire					B_CLK_IN,		// Clock
	input wire [P_ADR_WIDTH-1:0]		B_ADR_IN,		// Address
	input wire					B_RD_IN,		// Read in
	output wire [P_DAT_WIDTH-1:0]		B_DAT_OUT,	// Read data
	output wire					B_VLD_OUT		// Read data valid
);

// Local parameters
localparam P_WRDS = 2**P_ADR_WIDTH;

// Signals
// The dpram signals must have an unique name,
// so they can be found by the set_false_path constraint
(* ram_style = P_RAM_STYLE *) logic	[P_DAT_WIDTH-1:0]	prt_scaler_lib_mem_aclk_ram[0:P_WRDS-1];
(* dont_touch = "yes" *) logic [P_DAT_WIDTH-1:0]		prt_scaler_lib_mem_bclk_dout;
(* dont_touch = "yes" *) logic 		 			prt_scaler_lib_mem_bclk_vld;

// Logic

	// Clear memory during simulation
	// synthesis translate_off
	initial
	begin
		for (int i = 0; i < P_WRDS; i++)
			prt_scaler_lib_mem_aclk_ram[i] <= 0;
	end
	// synthesis translate_on

	// Write
	always_ff @ (posedge A_CLK_IN)
	begin
		if (A_WR_IN)
			prt_scaler_lib_mem_aclk_ram[A_ADR_IN] <= A_DAT_IN;
	end

	// Read output registers
	always_ff @ (posedge B_CLK_IN)
	begin
		prt_scaler_lib_mem_bclk_dout <= prt_scaler_lib_mem_aclk_ram[B_ADR_IN];
	end

	// Valid
   	always_ff @ (posedge B_CLK_IN)
   	begin
   		prt_scaler_lib_mem_bclk_vld <= B_RD_IN;
	end

   	// Outputs
   	assign B_DAT_OUT = prt_scaler_lib_mem_bclk_dout;
   	assign B_VLD_OUT = prt_scaler_lib_mem_bclk_vld;

endmodule


`default_nettype wire
