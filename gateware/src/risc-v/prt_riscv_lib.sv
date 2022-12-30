/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: RISC-V Library
    (c) 2022, 2023 by Parretto B.V.

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
	ROM interface
*/
interface prt_riscv_rom_if
#(
	parameter P_ADR_WIDTH = 16				// Address width
);
	logic					en;
	logic	[P_ADR_WIDTH-1:0] 	adr;
	logic	[31:0]			dat;
	logic					rd;
	logic					vld;
	modport mst	(output en, output adr, output rd, input dat, input vld);
	modport slv (input en, input adr, input rd, output dat, output vld);

endinterface

/*
	RAM interface
*/
interface prt_riscv_ram_if
#(
	parameter P_ADR_WIDTH = 16				// Address width
);
	logic	[P_ADR_WIDTH-1:0] 	adr;
	logic					wr;
	logic					rd;
	logic	[31:0]			wr_dat;
	logic	[3:0]			wr_strb;
	logic	[31:0]			rd_dat;
	logic					rd_vld;

	modport mst	(output adr, output wr, output rd, output wr_dat, output wr_strb, input rd_dat, input rd_vld);
	modport slv (input adr, input wr, input rd, input wr_dat, input wr_strb, output rd_dat, output rd_vld);

endinterface


/*
	Edge Detector
*/
module prt_riscv_lib_edge
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

`default_nettype wire
