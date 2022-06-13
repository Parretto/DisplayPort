/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP Library
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
	Reset module
*/
module prt_dp_lib_rst
(
   input wire    SRC_RST_IN,
   input wire    SRC_CLK_IN,
   input wire    DST_CLK_IN,
   output wire   DST_RST_OUT
);

// Parameters
localparam P_STAGES = 8;

// Signals
// The signals must have an unique name,
// so they can be found by the set_false_path constraint
(* dont_touch = "yes" *) logic           			prt_dp_lib_sclk_rst;
(* dont_touch = "yes" *) logic [P_STAGES-1:0]	prt_dp_lib_dclk_rst;

// Logic
// Source reset register
    always_ff @ (posedge SRC_CLK_IN)
    begin
    	prt_dp_lib_sclk_rst <= SRC_RST_IN;
    end

// Destination reset
    always_ff @ (posedge prt_dp_lib_sclk_rst, posedge DST_CLK_IN)
    begin
    	// Reset
    	if (prt_dp_lib_sclk_rst)
    		prt_dp_lib_dclk_rst <= '1;

    	else
    		prt_dp_lib_dclk_rst <= {prt_dp_lib_dclk_rst[0+:P_STAGES-1], 1'b0};
    end

// Output
	assign DST_RST_OUT = prt_dp_lib_dclk_rst[P_STAGES-1];

endmodule

/*
	Capture
*/
module prt_dp_lib_cap
(
	input wire	SRC_DAT_IN,
	input wire	DST_CLK_IN,
	output wire	DST_DAT_OUT
);

// Parameters
localparam P_STAGES = 4;

// Signals
(* dont_touch = "yes" *) logic [P_STAGES-1:0]	clk_cap;

// Logic
	always_ff @ (posedge DST_CLK_IN)
	begin
		clk_cap <= {clk_cap[0+:P_STAGES-1], SRC_DAT_IN};
	end

// Output
	assign DST_DAT_OUT = clk_cap[P_STAGES-1];

endmodule

/*
	Edge Detector
*/
module prt_dp_lib_edge
(
	input wire	CLK_IN,			// Clock
	input wire	CKE_IN,			// Clock enable
	input wire	A_IN,				// Input
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
module prt_dp_lib_cdc_bit
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
(* dont_touch = "yes" *) logic 					prt_dp_lib_cdc_bit_sclk_dat;
(* dont_touch = "yes" *) logic [P_STAGES-1:0]	prt_dp_lib_cdc_bit_dclk_dat;

// Logic

// Source register
	always_ff @ (posedge SRC_CLK_IN)
	begin
		prt_dp_lib_cdc_bit_sclk_dat <= SRC_DAT_IN;
	end

// Destination register
	always_ff @ (posedge DST_CLK_IN)
	begin
		prt_dp_lib_cdc_bit_dclk_dat <= {prt_dp_lib_cdc_bit_dclk_dat[0+:P_STAGES-1], prt_dp_lib_cdc_bit_sclk_dat};
	end

// Output
	assign DST_DAT_OUT = prt_dp_lib_cdc_bit_dclk_dat[P_STAGES-1];

endmodule

/*
	Vector clock domain crossing
*/
module prt_dp_lib_cdc_vec
#(
	parameter 						P_WIDTH = 8
)
(
	input wire						SRC_CLK_IN,		// Clock
	input wire [P_WIDTH-1:0] 		SRC_DAT_IN,		// Data
	input wire						DST_CLK_IN,		// Clock
	output wire [P_WIDTH-1:0]		DST_DAT_OUT		// Data
);

// Parameters
localparam P_STAGES = 2;

// Signals
// The signals must have an unique name,
// so they can be found by the set_false_path constraint
(* dont_touch = "yes" *) logic [3:0]            prt_dp_lib_cdc_vec_sclk_por_line = 0;
wire									        prt_dp_lib_cdc_vec_sclk_por;
(* dont_touch = "yes" *) logic [P_STAGES:0]		prt_dp_lib_cdc_vec_sclk_hs;
wire 											prt_dp_lib_cdc_vec_sclk_hs_re;
wire 											prt_dp_lib_cdc_vec_sclk_hs_fe;
logic 											prt_dp_lib_cdc_vec_sclk_en;
(* dont_touch = "yes" *) logic [P_WIDTH-1:0]	prt_dp_lib_cdc_vec_sclk_dat;

(* dont_touch = "yes" *) logic [3:0]            prt_dp_lib_cdc_vec_dclk_por_line = 0;
wire									        prt_dp_lib_cdc_vec_dclk_por;
(* dont_touch = "yes" *) logic [P_STAGES:0]		prt_dp_lib_cdc_vec_dclk_hs;
wire 											prt_dp_lib_cdc_vec_dclk_hs_re;
wire 											prt_dp_lib_cdc_vec_dclk_hs_fe;
logic 											prt_dp_lib_cdc_vec_dclk_en;
(* dont_touch = "yes" *) logic [P_WIDTH-1:0]	prt_dp_lib_cdc_vec_dclk_cap[P_STAGES-1:0];
(* dont_touch = "yes" *) logic [P_WIDTH-1:0]	prt_dp_lib_cdc_vec_dclk_dat;

// Logic

// Source power on reset
    always_ff @ (posedge SRC_CLK_IN)
    begin
        prt_dp_lib_cdc_vec_sclk_por_line <= {prt_dp_lib_cdc_vec_sclk_por_line[$size(prt_dp_lib_cdc_vec_sclk_por_line)-2:0], 1'b1};            
    end

    assign prt_dp_lib_cdc_vec_sclk_por = ~prt_dp_lib_cdc_vec_sclk_por_line[$size(prt_dp_lib_cdc_vec_sclk_por_line)-1];

// Source register
	always_ff @ (posedge prt_dp_lib_cdc_vec_sclk_por, posedge SRC_CLK_IN)
	begin
		// Reset
		if (prt_dp_lib_cdc_vec_sclk_por)
			prt_dp_lib_cdc_vec_sclk_dat <= 0;

		else
		begin
			// Enable
			if (prt_dp_lib_cdc_vec_sclk_en)
				prt_dp_lib_cdc_vec_sclk_dat <= SRC_DAT_IN;
		end
	end

// Handshake registers
	always_ff @ (posedge prt_dp_lib_cdc_vec_sclk_por, posedge SRC_CLK_IN)
	begin
		// Reset
		if (prt_dp_lib_cdc_vec_sclk_por)
			prt_dp_lib_cdc_vec_sclk_hs <= 0;

		else
			prt_dp_lib_cdc_vec_sclk_hs <= {prt_dp_lib_cdc_vec_sclk_hs[0+:$size(prt_dp_lib_cdc_vec_sclk_hs)-1], ~prt_dp_lib_cdc_vec_dclk_hs[$size(prt_dp_lib_cdc_vec_dclk_hs)-1]}; 
	end

	prt_dp_lib_edge
	SRC_HS_EDGE_INST
	(
		.CLK_IN		(SRC_CLK_IN),														// Clock
		.CKE_IN		(1'b1),																// Clock enable
		.A_IN		(prt_dp_lib_cdc_vec_sclk_hs[$size(prt_dp_lib_cdc_vec_sclk_hs)-1]),	// Input
		.RE_OUT		(prt_dp_lib_cdc_vec_sclk_hs_re),									// Rising edge
		.FE_OUT		(prt_dp_lib_cdc_vec_sclk_hs_fe)										// Falling edge
	);

// Enable
	always_ff @ (posedge SRC_CLK_IN)
	begin
		if (prt_dp_lib_cdc_vec_sclk_hs_re || prt_dp_lib_cdc_vec_sclk_hs_fe)
			prt_dp_lib_cdc_vec_sclk_en <= 1;
		else
			prt_dp_lib_cdc_vec_sclk_en <= 0;
	end

// Destination power on reset
    always_ff @ (posedge DST_CLK_IN)
    begin
        prt_dp_lib_cdc_vec_dclk_por_line <= {prt_dp_lib_cdc_vec_dclk_por_line[$size(prt_dp_lib_cdc_vec_dclk_por_line)-2:0], 1'b1};            
    end

    assign prt_dp_lib_cdc_vec_dclk_por = ~prt_dp_lib_cdc_vec_dclk_por_line[$size(prt_dp_lib_cdc_vec_dclk_por_line)-1];

// Destination capture register
	always_ff @ (posedge DST_CLK_IN)
	begin
		for (int i = 0; i < $size(prt_dp_lib_cdc_vec_dclk_cap); i++)
		begin
			if (i == 0)
				prt_dp_lib_cdc_vec_dclk_cap[i] <= prt_dp_lib_cdc_vec_sclk_dat;
			else
				prt_dp_lib_cdc_vec_dclk_cap[i] <= prt_dp_lib_cdc_vec_dclk_cap[i-1];
		end
	end

// Destination dout 
	always_ff @ (posedge prt_dp_lib_cdc_vec_dclk_por, posedge DST_CLK_IN)
	begin
		// Reset
		if (prt_dp_lib_cdc_vec_dclk_por)
			prt_dp_lib_cdc_vec_dclk_dat <= 0; 

		else
		begin
			// Enable
			if (prt_dp_lib_cdc_vec_dclk_en)
				prt_dp_lib_cdc_vec_dclk_dat <= prt_dp_lib_cdc_vec_dclk_cap[$size(prt_dp_lib_cdc_vec_dclk_cap)-1]; 
		end
	end

// Handshake registers
	always_ff @ (posedge prt_dp_lib_cdc_vec_dclk_por, posedge DST_CLK_IN)
	begin
		// Reset
		if (prt_dp_lib_cdc_vec_dclk_por)
			prt_dp_lib_cdc_vec_dclk_hs <= 0;
		else
			prt_dp_lib_cdc_vec_dclk_hs <= {prt_dp_lib_cdc_vec_dclk_hs[0+:$size(prt_dp_lib_cdc_vec_dclk_hs)-1], prt_dp_lib_cdc_vec_sclk_hs[$size(prt_dp_lib_cdc_vec_sclk_hs)-1]}; 
	end

	prt_dp_lib_edge
	DCLK_HS_EDGE_INST
	(
		.CLK_IN		(DST_CLK_IN),														// Clock
		.CKE_IN		(1'b1),																// Clock enable
		.A_IN		(prt_dp_lib_cdc_vec_dclk_hs[$size(prt_dp_lib_cdc_vec_dclk_hs)-1]),	// Input
		.RE_OUT		(prt_dp_lib_cdc_vec_dclk_hs_re),									// Rising edge
		.FE_OUT		(prt_dp_lib_cdc_vec_dclk_hs_fe)										// Falling edge
	);

// Enable
	always_ff @ (posedge DST_CLK_IN)
	begin
		if (prt_dp_lib_cdc_vec_dclk_hs_re || prt_dp_lib_cdc_vec_dclk_hs_fe)
			prt_dp_lib_cdc_vec_dclk_en <= 1;
		else
			prt_dp_lib_cdc_vec_dclk_en <= 0;
	end

// Output
	assign DST_DAT_OUT = prt_dp_lib_cdc_vec_dclk_dat;

endmodule

/*
	Gray clock domain crossing
*/
module prt_dp_lib_cdc_gray
#(
	parameter 						P_WIDTH = 8
)
(
	input wire						SRC_CLK_IN,		// Clock
	input wire [P_WIDTH-1:0] 		SRC_DAT_IN,		// Data
	input wire						DST_CLK_IN,		// Clock
	output wire [P_WIDTH-1:0]		DST_DAT_OUT		// Data
);

// Parameters
localparam P_STAGES = 2;

// Signals
// The signals must have an unique name,
// so they can be found by the set_false_path constraint
logic [P_WIDTH-1:0]	prt_dp_lib_cdc_gray_sclk_dat;
logic [P_WIDTH-1:0]	prt_dp_lib_cdc_gray_sclk_enc;

(* dont_touch = "yes" *) logic [P_WIDTH-1:0]	prt_dp_lib_cdc_gray_dclk_cap[P_STAGES-1:0];
(* dont_touch = "yes" *) logic [P_WIDTH-1:0]	prt_dp_lib_cdc_gray_dclk_dec;
(* dont_touch = "yes" *) logic [P_WIDTH-1:0]	prt_dp_lib_cdc_gray_dclk_dat;

genvar i;

// Logic

// Source register
	always_ff @ (posedge SRC_CLK_IN)
	begin
		prt_dp_lib_cdc_gray_sclk_dat <= SRC_DAT_IN;
		prt_dp_lib_cdc_gray_sclk_enc <= prt_dp_lib_cdc_gray_sclk_dat ^ {1'b0, prt_dp_lib_cdc_gray_sclk_dat[P_WIDTH-1:1]};
	end

// Destination capture register
	always_ff @ (posedge DST_CLK_IN)
	begin
		for (int i = 0; i < $size(prt_dp_lib_cdc_gray_dclk_cap); i++)
		begin
			if (i == 0)
				prt_dp_lib_cdc_gray_dclk_cap[i] <= prt_dp_lib_cdc_gray_sclk_enc;
			else
				prt_dp_lib_cdc_gray_dclk_cap[i] <= prt_dp_lib_cdc_gray_dclk_cap[i-1];
		end
	end

// Decoder
generate
	for (i = P_WIDTH-2; i >= 0; i--)
		assign prt_dp_lib_cdc_gray_dclk_dec[i] = prt_dp_lib_cdc_gray_dclk_dec[i + 1] ^ prt_dp_lib_cdc_gray_dclk_cap[P_STAGES-1][i];
endgenerate
	assign prt_dp_lib_cdc_gray_dclk_dec[P_WIDTH-1] = prt_dp_lib_cdc_gray_dclk_cap[P_STAGES-1][P_WIDTH-1];

// Data
	always_ff @ (posedge DST_CLK_IN)
	begin
		prt_dp_lib_cdc_gray_dclk_dat <= prt_dp_lib_cdc_gray_dclk_dec;
	end

// Outputs
	assign DST_DAT_OUT = prt_dp_lib_cdc_gray_dclk_dat;

endmodule

`default_nettype wire
