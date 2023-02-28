/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: RISC-V CPU registers
    (c) 2022 - 2023 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
	v1.1 - Added ramstyle property
		
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

module prt_riscv_cpu_reg
#(
	parameter P_REGS = 16,				// Number of registers
	parameter P_IDX = 4
)
(
	// Clock
	input wire 					CLK_IN,			// Clock

	// Destination register
	input wire [P_IDX-1:0]		RD_IDX_IN,		// IDX
	input wire [31:0]			RD_DAT_IN,		// Data
	input wire 					RD_WR_IN,		// Write

	// Source register 1
	input wire [P_IDX-1:0]		RS1_IDX_IN,
	output wire [31:0]			RS1_DAT_OUT,

	// Source register 2
	input wire [P_IDX-1:0]		RS2_IDX_IN,
	output wire [31:0]			RS2_DAT_OUT
);

// Signals
// The ram style is needed for Lattice.
// If not set Lattice Radiant 2022.1 will map the registers into block rams (EBR)
// and this results in unknown read outputs.
(* syn_ramstyle = "distributed" *) logic [31:0]	clk_reg[0:P_REGS-1];
//(* ramstyle = "no_rw_check" *) logic [31:0]	clk_reg[0:P_REGS-1];
logic [31:0]	clk_rs1_dat;
logic [31:0]	clk_rs2_dat;

// Write
// The destination register is always updated.
// In case of idle the first register is written.
// This register is hardwired to zero when read.
	always_ff @ (posedge CLK_IN)
	begin
		// Write
		if (RD_WR_IN)
			clk_reg[RD_IDX_IN] <= RD_DAT_IN;
	end

// RS1
	always_comb
	begin
		// First register is hardwired to zero
		if (RS1_IDX_IN == 0)
			clk_rs1_dat = 0;
		else
			clk_rs1_dat = clk_reg[RS1_IDX_IN];
	end

// RS2
	always_comb
	begin
		// First register is hardwired to zero
		if (RS2_IDX_IN == 0)
			clk_rs2_dat = 0;
		else
			clk_rs2_dat = clk_reg[RS2_IDX_IN];
	end

// Outputs
	assign RS1_DAT_OUT = clk_rs1_dat;
	assign RS2_DAT_OUT = clk_rs2_dat;

endmodule

`default_nettype wire
