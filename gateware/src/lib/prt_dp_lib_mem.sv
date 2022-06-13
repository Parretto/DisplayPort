/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP Library Memory
    (c) 2021, 2022 by Parretto B.V.

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

`default_nettype none

/*
	Single clock FIFO
*/
module prt_dp_lib_fifo_sc
#(
	parameter							P_MODE         = "single",		// "single" or "burst"
	parameter 						P_RAM_STYLE	= "distributed",	// "distributed", "block" or "ultra"
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

logic	[P_ADR_WIDTH-1:0]	clk_wp;			// Write pointer
logic 	[P_ADR_WIDTH-1:0]	clk_rp;			// Read pointer
logic	[P_DAT_WIDTH-1:0]	clk_dout[0:1];
logic	[1:0]			clk_da;
logic	[1:0]			clk_de;
logic	[P_ADR_WIDTH-1:0]	clk_wrds;
logic					clk_ep;
logic					clk_fl;

// Logic

// Write memory
// Registered
	always_ff @ (posedge CLK_IN)
	begin
		if (WR_IN)
			clk_ram[clk_wp] <= DAT_IN;
	end

// Read memory
generate
	if (P_RAM_STYLE == "ultra")
	begin : gen_dout_ultra
		always_ff @ (posedge CLK_IN)
		begin
			// Read enable
			if (RD_EN_IN)
			begin
				clk_dout[0] <= clk_ram[clk_rp];
				clk_dout[1] <= clk_dout[0];
			end
		end
	end

	else
	begin : gen_dout_distributed
		assign clk_dout[1] = clk_ram[clk_rp];
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

			// Write
			else if (WR_IN)
			begin
				// Check for overflow
				if (&clk_wp)
					clk_wp <= 0;
				else
					clk_wp <= clk_wp + 'd1;
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
// To improve timing performance the output words are registered
	always_ff @ (posedge CLK_IN)
	begin
		if (clk_wp > clk_rp)
			clk_wrds = clk_wp - clk_rp;

		else if (clk_wp < clk_rp)
			clk_wrds = (P_WRDS - clk_rp) + clk_wp;

		else
			clk_wrds = 0;
	end
	
// Outputs
	assign DAT_OUT 	= clk_dout[1];
	assign DE_OUT 		= (P_MODE == "burst") ? ((P_RAM_STYLE == "ultra") ? clk_de[$size(clk_de)-1] : clk_de[0]) : ((P_RAM_STYLE == "ultra") ? clk_da[$size(clk_da)-1] : clk_da[0]);
	assign WRDS_OUT 	= clk_wrds;
	assign EP_OUT 		= clk_ep;
	assign FL_OUT 		= clk_fl;

endmodule

/*
	Dual Clock FIFO 
*/
module prt_dp_lib_fifo_dc
#(
	parameter							P_MODE         = "single",		// "single" or "burst"
	parameter 						P_RAM_STYLE	= "distributed",	// "distributed" or "block"
	parameter							P_ADR_WIDTH	= 5,
	parameter							P_DAT_WIDTH	= 32
)
(
	input wire						A_RST_IN,		// Reset
	input wire						B_RST_IN,
	input wire						A_CLK_IN,		// Clock
	input wire						B_CLK_IN,
	input wire						A_CKE_IN,		// Clock enable
	input wire						B_CKE_IN,

	// Input (A)
	input wire						A_WR_IN,		// Write
	input wire	[P_DAT_WIDTH-1:0]		A_DAT_IN,		// Write data

	// Output (B)
	input wire						B_RD_IN,		// Read
	output wire	[P_DAT_WIDTH-1:0]		B_DAT_OUT,	// Read data
	output wire						B_DE_OUT,		// Data enable

	// Status (A)
	output wire	[P_ADR_WIDTH:0]		A_WRDS_OUT,	// Used words
	output wire						A_FL_OUT,		// Full
	output wire						A_EP_OUT,		// Empty

	// Status (B)
	output wire	[P_ADR_WIDTH:0]		B_WRDS_OUT,	// Used words
	output wire						B_FL_OUT,		// Full
	output wire						B_EP_OUT		// Empty
);

/*
	Parameters
*/
localparam P_WRDS = 2**P_ADR_WIDTH;

/*
	Signals
*/
// The dpram signals must have an unique name,
// so they can be found by the set_false_path constraint

(* ram_style = P_RAM_STYLE *) logic	[P_DAT_WIDTH-1:0]	prt_dp_lib_mem_aclk_ram[0:P_WRDS-1];

logic 	[P_ADR_WIDTH-1:0]		aclk_wp;
wire 	[P_ADR_WIDTH-1:0]		aclk_rp;
logic	[P_ADR_WIDTH:0]		aclk_wrds;
logic						aclk_fl;
logic						aclk_ep;

logic 	[P_ADR_WIDTH-1:0]		bclk_rp;
wire 	[P_ADR_WIDTH-1:0]		bclk_wp;
logic	[P_ADR_WIDTH:0]		bclk_wrds;
logic						bclk_fl;
logic						bclk_ep;
logic	[1:0]				bclk_da;
logic	[1:0]				bclk_de;
logic [P_DAT_WIDTH-1:0]			prt_dp_lib_mem_bclk_dout;
(* dont_touch = "yes" *) logic [P_DAT_WIDTH-1:0]		prt_dp_lib_mem_bclk_dout_reg;


/*
	Logic
*/

// RAM inference
	always_ff @ (posedge A_CLK_IN)
	begin
		// Clock enable
		if (A_CKE_IN)
		begin
			if (A_WR_IN)
				prt_dp_lib_mem_aclk_ram[aclk_wp] <= A_DAT_IN;
		end
	end

// Port A
// Write Pointer
	always_ff @ (posedge A_RST_IN, posedge A_CLK_IN)
	begin
		if (A_RST_IN)
			aclk_wp <= 0;

		else
		begin
			// Clock enable
			if (A_CKE_IN)
			begin
				// Increment 
				if (A_WR_IN)
				begin
					if (aclk_wp == P_WRDS-1)
						aclk_wp <= 0;
					else
						aclk_wp <= aclk_wp + 'd1;
				end
			end
		end
	end

// Clock Domain Crossing
// This adapter crosses the (original size) read pointer to the write pointer domain.
	prt_dp_lib_cdc_gray
	#(
		.P_WIDTH		(P_ADR_WIDTH)
	)
	RP_CDC_INST
	(
		.SRC_CLK_IN	(B_CLK_IN),
		.SRC_DAT_IN	(bclk_rp),
		.DST_CLK_IN	(A_CLK_IN),
		.DST_DAT_OUT	(aclk_rp)
	);

// Words
// To improve timing performance the words are registered
	always_ff @ (posedge A_CLK_IN)
	begin
		if (aclk_wp > aclk_rp)
			aclk_wrds = aclk_wp - aclk_rp;

		else if (aclk_wp < aclk_rp)
			aclk_wrds = (P_WRDS - aclk_rp) + aclk_wp;

		else
			aclk_wrds = 0;
	end

// Full Flag
// Must be combinatorial
	always_comb
	begin
		if (aclk_wrds > (P_WRDS - 'd4))
			aclk_fl = 1;
		else
			aclk_fl = 0;
	end

// Empty Flag
// Must be combinatorial
	always_comb
	begin
		// Set
		if (aclk_wp == aclk_rp)
			aclk_ep = 1;

		// Clear
		else
			aclk_ep = 0;
	end

// Port B
// Read Pointer
	always_ff @ (posedge B_RST_IN, posedge B_CLK_IN)
	begin
		if (B_RST_IN)
			bclk_rp <= 0;

		else
		begin
			// Clock enable
			if (B_CKE_IN)
			begin
				// Increment
				if (B_RD_IN && !bclk_ep)
				begin
					if (bclk_rp == P_WRDS-1)
						bclk_rp <= 0;
					else
						bclk_rp <= bclk_rp + 'd1;
				end
			end
		end
	end

// Clock Domain Crossing
// This adapter crosses the (original size) write pointer to the read pointer domain.
	prt_dp_lib_cdc_gray
	#(
		.P_WIDTH		(P_ADR_WIDTH)
	)
	WP_CDC_INST
	(
		.SRC_CLK_IN	(A_CLK_IN),
		.SRC_DAT_IN	(aclk_wp),
		.DST_CLK_IN	(B_CLK_IN),
		.DST_DAT_OUT	(bclk_wp)
	);

// Words
// To improve timing performance the words are registered
	always_ff @ (posedge B_CLK_IN)
	begin
		if (bclk_wp > bclk_rp)
			bclk_wrds = bclk_wp - bclk_rp;

		else if (bclk_wp < bclk_rp)
			bclk_wrds = (P_WRDS - bclk_rp) + bclk_wp;

		else
			bclk_wrds = 0;
	end

// Full Flag
// Must be combinatorial
	always_comb
	begin
		if (bclk_wrds > (P_WRDS - 'd4))
			bclk_fl = 1;
		else
			bclk_fl = 0;
	end

// Empty Flag
// Must be combinatorial
	always_comb
	begin
		// Set
		if (bclk_wp == bclk_rp)
			bclk_ep = 1;

		// Clear
		else
			bclk_ep = 0;
	end

// Data available
	always_ff @ (posedge B_RST_IN, posedge B_CLK_IN)
	begin
		if (B_RST_IN)
			bclk_da <= 0;

		else
		begin
			// Enable
			if (B_CKE_IN)
			begin
				if (bclk_ep || B_RD_IN)
					bclk_da <= 0;
				else
				begin
					bclk_da[0] <= 1;
					bclk_da[1] <= bclk_da[0];
				end
			end
		end
	end

// Data enable
	always_ff @ (posedge B_RST_IN, posedge B_CLK_IN)
	begin
		if (B_RST_IN)
			bclk_de <= 0;

		else
		begin
			// Enable
			if (B_CKE_IN)
			begin
				if (!bclk_ep)
					bclk_de[0] <= B_RD_IN;
				else
					bclk_de[0] <= 0;
				bclk_de[1] <= bclk_de[0];
			end
		end
	end

// Data output
	always_ff @ (posedge B_CLK_IN)
	begin
		prt_dp_lib_mem_bclk_dout <= prt_dp_lib_mem_aclk_ram[bclk_rp];
	end

	always_ff @ (posedge B_CLK_IN)
	begin
		// Clock enable
		if (B_CKE_IN)
		begin
			prt_dp_lib_mem_bclk_dout_reg	<= prt_dp_lib_mem_bclk_dout;			// Output is registered
		end
	end

// Outputs
	assign A_FL_OUT 	= aclk_fl;
	assign A_EP_OUT 	= aclk_ep;
	assign A_WRDS_OUT 	= aclk_wrds;
	assign B_DAT_OUT 	= prt_dp_lib_mem_bclk_dout_reg;
	assign B_DE_OUT 	= (P_MODE == "burst") ? bclk_de[$size(bclk_de)-1] : bclk_da[$size(bclk_da)-1];
	assign B_FL_OUT 	= bclk_fl;
	assign B_EP_OUT 	= bclk_ep;
	assign B_WRDS_OUT 	= bclk_wrds;

endmodule


/*
	Dual Clock FIFO sliced
	v1 - Initial release
	v2 - Changed data enable behavior. 
		The DE is not supressed if the fifo is empty
*/
/*
module prt_dp_lib_fifo_dc_slice
#(
	parameter							P_MODE         = "single",		// "single" or "burst"
	parameter 						P_RAM_STYLE	= "distributed",	// "distributed" or "block"
	parameter							P_ADR_WIDTH	= 5,
	parameter							P_DAT_WIDTH	= 32,
	parameter 						P_WR_WIDTH	= 1
)
(
	input wire						A_RST_IN,		// Reset
	input wire						B_RST_IN,
	input wire						A_CLK_IN,		// Clock
	input wire						B_CLK_IN,
	input wire						A_CKE_IN,		// Clock enable
	input wire						B_CKE_IN,

	// Input (A)
	input wire	[P_WR_WIDTH-1:0]		A_WR_IN,		// Write
	input wire	[P_DAT_WIDTH-1:0]		A_DAT_IN,		// Write data

	// Output (B)
	input wire						B_RD_IN,		// Read
	output wire	[P_DAT_WIDTH-1:0]		B_DAT_OUT,	// Read data
	output wire						B_DE_OUT,		// Data enable

	// Status (A)
	output wire	[P_ADR_WIDTH:0]		A_WRDS_OUT,	// Used words
	output wire						A_FL_OUT,		// Full
	output wire						A_EP_OUT,		// Empty

	// Status (B)
	output wire	[P_ADR_WIDTH:0]		B_WRDS_OUT,	// Used words
	output wire						B_FL_OUT,		// Full
	output wire						B_EP_OUT		// Empty
);


// Parameters

localparam P_WRDS = 2**P_ADR_WIDTH;
localparam P_SLICE = P_DAT_WIDTH / P_WR_WIDTH;

// Signals

// The dpram signals must have an unique name,
// so they can be found by the set_false_path constraint

(* ram_style = P_RAM_STYLE *) logic	[P_DAT_WIDTH-1:0]	prt_dp_lib_mem_aclk_ram[0:P_WRDS-1];

logic 	[P_ADR_WIDTH-1:0]		aclk_wp;
wire 	[P_ADR_WIDTH-1:0]		aclk_rp;
logic	[P_ADR_WIDTH:0]		aclk_wrds;
logic						aclk_fl;
logic						aclk_ep;

logic 	[P_ADR_WIDTH-1:0]		bclk_rp;
wire 	[P_ADR_WIDTH-1:0]		bclk_wp;
logic	[P_ADR_WIDTH:0]		bclk_wrds;
logic						bclk_fl;
logic						bclk_ep;
logic	[1:0]				bclk_da;
logic	[1:0]				bclk_de;
(* dont_touch = "yes" *) logic [P_DAT_WIDTH-1:0]		prt_dp_lib_mem_bclk_dout;
(* dont_touch = "yes" *) logic [P_DAT_WIDTH-1:0]		prt_dp_lib_mem_bclk_dout_reg;



//	Logic

// RAM inference
	always_ff @ (posedge A_CLK_IN)
	begin
		// Clock enable
		if (A_CKE_IN)
		begin
			// Write
			for (int i=0; i<P_WR_WIDTH; i++)
			begin
				if (A_WR_IN[i])
					prt_dp_lib_mem_aclk_ram[aclk_wp][(i*P_SLICE)+:P_SLICE] <= A_DAT_IN[(i*P_SLICE)+:P_SLICE];
			end
		end
	end

// Port A
// Write Pointer
	always_ff @ (posedge A_RST_IN, posedge A_CLK_IN)
	begin
		if (A_RST_IN)
			aclk_wp <= 0;

		else
		begin
			// Clock enable
			if (A_CKE_IN)
			begin
				// Increment when the upper chunk has been written
				if (A_WR_IN[P_WR_WIDTH-1])
				begin
					if (aclk_wp == P_WRDS-1)
						aclk_wp <= 0;
					else
						aclk_wp <= aclk_wp + 'd1;
				end
			end
		end
	end

// Clock Domain Crossing
// This adapter crosses the (original size) read pointer to the write pointer domain.
	prt_dp_lib_cdc_vec
	#(
		.P_WIDTH		(P_ADR_WIDTH)
	)
	RP_CDC_INST
	(
		.SRC_CLK_IN	(B_CLK_IN),
		.SRC_DAT_IN	(bclk_rp),
		.DST_CLK_IN	(A_CLK_IN),
		.DST_DAT_OUT	(aclk_rp)
	);

// Words
	always_comb
	begin
		if (aclk_wp > aclk_rp)
			aclk_wrds = aclk_wp - aclk_rp;

		else if (aclk_wp < aclk_rp)
			aclk_wrds = (P_WRDS - aclk_rp) + aclk_wp;

		else
			aclk_wrds = 0;
	end

// Full Flag
// Must be combinatorial
	always_comb
	begin
		if (aclk_wrds > (P_WRDS - 'd4))
			aclk_fl = 1;
		else
			aclk_fl = 0;
	end

// Empty Flag
// Must be combinatorial
	always_comb
	begin
		// Set
		if (aclk_wrds == 0)
			aclk_ep = 1;

		// Clear
		else
			aclk_ep = 0;
	end

// Port B
// Read Pointer
	always_ff @ (posedge B_RST_IN, posedge B_CLK_IN)
	begin
		if (B_RST_IN)
			bclk_rp <= 0;

		else
		begin
			// Clock enable
			if (B_CKE_IN)
			begin
				// Increment
				if (B_RD_IN)
				begin
					if (bclk_rp == P_WRDS-1)
						bclk_rp <= 0;
					else
						bclk_rp <= bclk_rp + 'd1;
				end
			end
		end
	end

// Clock Domain Crossing
// This adapter crosses the (original size) write pointer to the read pointer domain.
	prt_dp_lib_cdc_vec
	#(
		.P_WIDTH		(P_ADR_WIDTH)
	)
	WP_CDC_INST
	(
		.SRC_CLK_IN	(A_CLK_IN),
		.SRC_DAT_IN	(aclk_wp),
		.DST_CLK_IN	(B_CLK_IN),
		.DST_DAT_OUT	(bclk_wp)
	);

// Words
	always_comb
	begin
		if (bclk_wp > bclk_rp)
			bclk_wrds = bclk_wp - bclk_rp;

		else if (bclk_wp < bclk_rp)
			bclk_wrds = (P_WRDS - bclk_rp) + bclk_wp;

		else
			bclk_wrds = 0;
	end

// Full Flag
// Must be combinatorial
	always_comb
	begin
		if (bclk_wrds > (P_WRDS - 'd4))
			bclk_fl = 1;
		else
			bclk_fl = 0;
	end

// Empty Flag
// Must be combinatorial
	always_comb
	begin
		// Set
		if (bclk_wrds == 0)
			bclk_ep = 1;

		// Clear
		else
			bclk_ep = 0;
	end

// Data available
	always_ff @ (posedge B_RST_IN, posedge B_CLK_IN)
	begin
		if (B_RST_IN)
			bclk_da <= 0;

		else
		begin
			// Enable
			if (B_CKE_IN)
			begin
				if (B_RD_IN)
					bclk_da <= 0;
				else
				begin
					bclk_da[0] <= 1;
					bclk_da[1] <= bclk_da[0];
				end
			end
		end
	end

// Data enable
	always_ff @ (posedge B_RST_IN, posedge B_CLK_IN)
	begin
		if (B_RST_IN)
			bclk_de <= 0;

		else
		begin
			// Enable
			if (B_CKE_IN)
			begin
				bclk_de[0] <= B_RD_IN;
				bclk_de[1] <= bclk_de[0];
			end
		end
	end

// Data output
	always_ff @ (posedge B_CLK_IN)
	begin
		// Clock enable
		if (B_CKE_IN)
		begin
			prt_dp_lib_mem_bclk_dout 	<= prt_dp_lib_mem_aclk_ram[bclk_rp];
			prt_dp_lib_mem_bclk_dout_reg	<= prt_dp_lib_mem_bclk_dout;			// Output is registered
		end
	end

// Outputs
	assign A_FL_OUT 	= aclk_fl;
	assign A_EP_OUT 	= aclk_ep;
	assign A_WRDS_OUT 	= aclk_wrds;
	assign B_DAT_OUT 	= prt_dp_lib_mem_bclk_dout_reg;
	assign B_DE_OUT 	= (P_MODE == "burst") ? bclk_de[$size(bclk_de)-1] : bclk_da[$size(bclk_da)-1];
	assign B_FL_OUT 	= bclk_fl;
	assign B_EP_OUT 	= bclk_ep;
	assign B_WRDS_OUT 	= bclk_wrds;

endmodule
*/


/*
	Simple dual port RAM single clock
*/
module prt_dp_lib_sdp_ram_sc
#(
	parameter 					P_RAM_STYLE	= "distributed",	// "distributed", "block" or "ultra"
	parameter 					P_ADR_WIDTH 	= 7,
	parameter						P_DAT_WIDTH 	= 512
)
(
	// Clocks and reset
	input wire					RST_IN,		// Reset
	input wire					CLK_IN,		// Clock

	// Port A
	input wire [P_ADR_WIDTH-1:0]		A_ADR_IN,		// Address
	input wire					A_WR_IN,		// Write in
	input wire [P_DAT_WIDTH-1:0]		A_DAT_IN,		// Write data

	// Port B
	input wire [P_ADR_WIDTH-1:0]		B_ADR_IN,		// Address
	input wire					B_RD_IN,		// Read in
	output wire [P_DAT_WIDTH-1:0]		B_DAT_OUT,	// Read data
	output wire					B_VLD_OUT		// Read data valid
);

// Parameters
localparam P_WRDS = 2**P_ADR_WIDTH;

// Signals
(* ram_style = P_RAM_STYLE *) logic	[P_DAT_WIDTH-1:0]	clk_ram[0:P_WRDS-1];
logic [P_DAT_WIDTH-1:0]		clk_b_dout;
logic  					clk_b_vld;

// Logic

	// Clear memory during simulation
	// synthesis translate_off
	initial
	begin
		for (int i = 0; i < P_WRDS; i++)
			clk_ram[i] <= 0;
	end
	// synthesis translate_on

	// Write
	always_ff @ (posedge CLK_IN)
	begin
		if (A_WR_IN)
			clk_ram[A_ADR_IN] <= A_DAT_IN;
	end

	// Read output register
	always_ff @ (posedge CLK_IN)
	begin
		clk_b_dout <= clk_ram[B_ADR_IN];
	end

	// Valid
   	always_ff @ (posedge CLK_IN)
   	begin
   		clk_b_vld <= B_RD_IN;
	end

	// Outputs
   	assign B_DAT_OUT = clk_b_dout;
   	assign B_VLD_OUT = clk_b_vld;

endmodule

/*
	Simple dual port RAM dual clock
*/
module prt_dp_lib_sdp_ram_dc
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
(* ram_style = P_RAM_STYLE *) logic	[P_DAT_WIDTH-1:0]	prt_dp_lib_mem_aclk_ram[0:P_WRDS-1];
(* dont_touch = "yes" *) logic [P_DAT_WIDTH-1:0]		prt_dp_lib_mem_bclk_dout;
(* dont_touch = "yes" *) logic 		 			prt_dp_lib_mem_bclk_vld;

// Logic

	// Clear memory during simulation
	// synthesis translate_off
	initial
	begin
		for (int i = 0; i < P_WRDS; i++)
			prt_dp_lib_mem_aclk_ram[i] <= 0;
	end
	// synthesis translate_on

	// Write
	always_ff @ (posedge A_CLK_IN)
	begin
		if (A_WR_IN)
			prt_dp_lib_mem_aclk_ram[A_ADR_IN] <= A_DAT_IN;
	end

	// Read output registers
	always_ff @ (posedge B_CLK_IN)
	begin
		prt_dp_lib_mem_bclk_dout <= prt_dp_lib_mem_aclk_ram[B_ADR_IN];
	end

	// Valid
   	always_ff @ (posedge B_CLK_IN)
   	begin
   		prt_dp_lib_mem_bclk_vld <= B_RD_IN;
	end

   	// Outputs
   	assign B_DAT_OUT = prt_dp_lib_mem_bclk_dout;
   	assign B_VLD_OUT = prt_dp_lib_mem_bclk_vld;

endmodule

`default_nettype wire
