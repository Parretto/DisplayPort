/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Library modules
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

/*
	Reset synchronizer module
*/
module prt_lib_rst
#(
	parameter 	 P_VENDOR = "none"  		// Vendor
)
(
   input wire    SRC_CLK_IN,
   input wire    SRC_RST_IN,
   input wire    DST_CLK_IN,
   output wire   DST_RST_OUT
);


// Lattice
generate
	if (P_VENDOR == "LSC")
		begin : gen_lsc

			logic sclk_rstn;

			always_ff @ (posedge SRC_CLK_IN)
			begin
				sclk_rstn <= ~SRC_RST_IN;	// The Lattice reset module has a negative reset input
			end

		    lscc_reset 
		    #(
		        .RESET_MODE     ("ASYNC"),
		        .SYNC_STAGE     (2),
		        .SIM_ASSERT_EN  (1)
		    )
		    RST_SYNC_INST
		    (
		        .src_rst_n      (sclk_rstn),
		        .dest_clk       (DST_CLK_IN),
		        .dest_rst       (DST_RST_OUT),
		        .dest_rst_n     ()
		    );
		end 

		// Generic
		else
		begin : gen_generic
			// Parameters
			localparam P_STAGES = 8;

			// Signals
			// The signals must have an unique name,
			// so they can be found by the set_false_path constraint
			(* syn_preserve=1 *) logic           			prt_lib_mod_sclk_rst;
			(* syn_preserve=1 *) logic [P_STAGES-1:0]	prt_lib_mod_dclk_rst;

			// Logic
			// Source reset register
			    always_ff @ (posedge SRC_CLK_IN)
			    begin
			    	prt_lib_mod_sclk_rst <= SRC_RST_IN;
			    end

			// Destination reset
			    always_ff @ (posedge prt_lib_mod_sclk_rst, posedge DST_CLK_IN)
			    begin
			    	// Reset
			    	if (prt_lib_mod_sclk_rst)
			    		prt_lib_mod_dclk_rst <= '1;

			    	else
			    		prt_lib_mod_dclk_rst <= {prt_lib_mod_dclk_rst[0+:P_STAGES-1], 1'b0};
			    end

			// Output
				assign DST_RST_OUT = prt_lib_mod_dclk_rst[P_STAGES-1];
		end
	endgenerate
endmodule

/*
	Capture
*/
module prt_lib_cap
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
module prt_lib_edge
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
			clk_a_del <= A_IN;
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
module prt_lib_cdc_bit
#(
	parameter      	P_VENDOR = "none"  		// Vendor
)
(
	input wire		SRC_CLK_IN,		// Clock
	input wire 		SRC_DAT_IN,		// Data
	input wire		DST_CLK_IN,		// Clock
	output wire 	DST_DAT_OUT		// Data
);

generate
	// Lattice
	if (P_VENDOR == "LSC")
	begin : lscc_cdc
		lscc_sync 
		#(
			.SYNC_STAGE    	(2),
			.DEST_RST_MODE 	("ASYNC"),
			.RST_INIT      	(0),
			.REGMODE       	(0)
		)
		CDC_INST
		(
			.in_data		(SRC_DAT_IN),
			.dest_rst_n  	(1'b1),
			.dest_clk    	(DST_CLK_IN),
			.out_data		(DST_DAT_OUT)
		);
	end

	// AMD
	else if (P_VENDOR == "AMD")
	begin : amd_cdc
		xpm_cdc_single 
		#(
			.DEST_SYNC_FF	(4),
			.INIT_SYNC_FF   (0),
			.SIM_ASSERT_CHK (0),
			.SRC_INPUT_REG  (1),
			.VERSION        (0)
		) 
		CDC_INST
		(
			.src_clk		(SRC_CLK_IN),
			.src_in			(SRC_DAT_IN),
			.dest_clk		(DST_CLK_IN),
			.dest_out		(DST_DAT_OUT)
		);
	end

	else
	begin
		$error ("No Vendor specified!");
	end
endgenerate

endmodule

/*
	Vector clock domain crossing
*/
module prt_lib_cdc_vec
#(
	parameter                 	P_VENDOR = "none",  		// Vendor
	parameter 						P_WIDTH = 8
)
(
	input wire						SRC_RST_IN,		// Reset
	input wire						SRC_CLK_IN,		// Clock
	input wire [P_WIDTH-1:0] 	SRC_DAT_IN,		// Data

	input wire						DST_RST_IN,		// Reset
	input wire						DST_CLK_IN,		// Clock
	output wire [P_WIDTH-1:0]	DST_DAT_OUT		// Data
);

// Logic

generate
	// Lattice
	if (P_VENDOR == "LSC")
	begin : lscc_cdc

		wire src_rdy;
		wire dst_vld;

		lscc_cdc_hs_bus 
		#(
			.WIDTH          (P_WIDTH),
			.SYNC_STAGE     (2),
			.UNRELATED_RST  (1),
			.SRC_RST_MODE   ("ASYNC"),
			.DEST_RST_MODE  ("ASYNC"),
			.RST_INIT       (0),
			.SRC_REQ_EN     (1),
			.REGMODE        (0),
			.SIM_ASSERT_EN  (0)
		) 
		CDC_INST
		(
			.src_rst_n      (~SRC_RST_IN),
			.src_clk        (SRC_CLK_IN),
			.src_req        (src_rdy),
			.src_ready      (src_rdy),
			.in_data        (SRC_DAT_IN),
			.dest_rst_n     (~DST_RST_IN),
			.dest_clk       (DST_CLK_IN),
			.dest_valid     (dst_vld),
			.dest_ack       (dst_vld),
			.out_data       (DST_DAT_OUT)
		);
	end

	// AMD
	else if (P_VENDOR == "AMD")
	begin : amd_cdc
		xpm_cdc_gray 
		#(
			.DEST_SYNC_FF			(2),        // DECIMAL; range: 2-10
			.INIT_SYNC_FF			(0),        // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
			.REG_OUTPUT				(1),        // DECIMAL; 0=disable registered output, 1=enable registered output
			.SIM_ASSERT_CHK			(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
			.SIM_LOSSLESS_GRAY_CHK	(0), 		// DECIMAL; 0=disable lossless check, 1=enable lossless check
			.WIDTH					(P_WIDTH)   // DECIMAL; range: 2-32
		)
		CDC_INST 
		(
			.src_clk				(SRC_CLK_IN),       
			.src_in_bin				(SRC_DAT_IN), 
			.dest_clk				(DST_CLK_IN),
			.dest_out_bin			(DST_DAT_OUT)
		);
	end

	else
	begin
		$error ("No Vendor specified!");
	end
endgenerate

endmodule

/*
	Gray clock domain crossing
*/
module prt_lib_cdc_gray
#(
	parameter                  P_VENDOR    	= "none",  		// Vendor
	parameter 						P_WIDTH = 8
)
(
	input wire						SRC_RST_IN,		// Reset
	input wire						SRC_CLK_IN,		// Clock
	input wire [P_WIDTH-1:0] 	SRC_DAT_IN,		// Data
	input wire						DST_RST_IN,		// Reset
	input wire						DST_CLK_IN,		// Clock
	output wire [P_WIDTH-1:0]	DST_DAT_OUT		// Data
);

generate
	if (P_VENDOR == "AMD")
	begin : amd_cdc
		xpm_cdc_gray 
		#(
			.DEST_SYNC_FF			(2),        // DECIMAL; range: 2-10
			.INIT_SYNC_FF			(0),        // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
			.REG_OUTPUT				(1),        // DECIMAL; 0=disable registered output, 1=enable registered output
			.SIM_ASSERT_CHK			(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
			.SIM_LOSSLESS_GRAY_CHK	(0), 		// DECIMAL; 0=disable lossless check, 1=enable lossless check
			.WIDTH					(P_WIDTH)   // DECIMAL; range: 2-32
		)
		CDC_INST 
		(
			.src_clk				(SRC_CLK_IN),       
			.src_in_bin				(SRC_DAT_IN), 
			.dest_clk				(DST_CLK_IN),
			.dest_out_bin			(DST_DAT_OUT)
		);
	end

	else
	begin : gen_gray

		// Signals
		logic [P_WIDTH-1:0]	sclk_dat;
		logic [P_WIDTH-1:0]	sclk_enc;
		wire [P_WIDTH-1:0]	dclk_cap;
		wire [P_WIDTH-1:0]	dclk_dec;
		logic [P_WIDTH-1:0]	dclk_dat;

		genvar i;

		// Logic

		// Source register
			always_ff @ (posedge SRC_CLK_IN)
			begin
				sclk_dat <= SRC_DAT_IN;
				sclk_enc <= sclk_dat ^ {1'b0, sclk_dat[P_WIDTH-1:1]};
			end

		// CDC
			prt_lib_cdc_vec
			#(
				.P_VENDOR 		(P_VENDOR),
				.P_WIDTH 		(P_WIDTH)
			)
			CDC_INST
			(
				.SRC_RST_IN		(SRC_RST_IN),	// Reset
				.SRC_CLK_IN		(SRC_CLK_IN),	// Clock
				.SRC_DAT_IN		(sclk_enc),		// Data

				.DST_RST_IN		(DST_RST_IN),	// Reset
				.DST_CLK_IN		(DST_CLK_IN),	// Clock
				.DST_DAT_OUT	(dclk_cap)		// Data
			);

		// Decoder
			for (i = P_WIDTH-2; i >= 0; i--)
				assign dclk_dec[i] = dclk_dec[i + 1] ^ dclk_cap[i];
			assign dclk_dec[P_WIDTH-1] = dclk_cap[P_WIDTH-1];

		// Data
			always_ff @ (posedge DST_CLK_IN)
			begin
				dclk_dat <= dclk_dec;
			end

		// Outputs
			assign DST_DAT_OUT = dclk_dat;
	end
endgenerate

endmodule

`default_nettype wire
