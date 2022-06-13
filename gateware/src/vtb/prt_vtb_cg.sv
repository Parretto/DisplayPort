/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Video toolbox Clock Generator
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

module prt_vtb_cg
(
	// Reset and clock
	input wire 			RST_IN,			// Reset
	input wire 			CLK_IN,			// Clock
	input wire			CKE_IN,			// Clock enable

	// Control
 	input wire 			CTL_RUN_IN,		// Run

	// Video parameter set
	input wire [3:0]		VPS_IDX_IN,		// Index
	input wire [15:0]		VPS_DAT_IN,		// Data
	input wire 			VPS_VLD_IN,		// Valid	

	// Clock enable
	output wire			CKE_OUT	
);

// Parameters
// Structures
typedef struct {
	logic				run;		// Run
	logic				mode;	// Mode
} ctl_struct;

typedef struct {
	logic 	[31:0]		r;		// Register
	logic	[1:0]		sel;		// Select
} reg_struct;

typedef struct {
	logic	[31:0]		cnt_a;
	logic				cnt_a_msb_del;
	logic				cnt_a_of;
	logic	[31:0]		cnt_a_in;
	logic	[31:0]		cnt_b;
	logic	[31:0]		cnt_b_in;
	logic				cke;
} gen_struct;

// Signals
ctl_struct 		clk_ctl;
reg_struct 		clk_reg_refclk;
reg_struct 		clk_reg_vidclk;
gen_struct 		clk_gen;

// Logic

// Inputs
	always_ff @ (posedge CLK_IN)
	begin
		clk_ctl.run  <= CTL_RUN_IN;
	end

// Register select
	always_comb
	begin
		// Default
		clk_reg_refclk.sel  = 0;
		clk_reg_vidclk.sel  = 0;
		
		case (VPS_IDX_IN)
			'd0 : clk_reg_refclk.sel[0]  = 1;	// High
			'd1 : clk_reg_refclk.sel[1]  = 1;	// Low
			'd2 : clk_reg_vidclk.sel[0]  = 1;	// High
			'd3 : clk_reg_vidclk.sel[1]  = 1;	// Low
			default : ;
		endcase
	end	

// Reference clock register
	always_ff @ (posedge CLK_IN)
	begin
		// Run
		if (clk_ctl.run)
		begin
			// Write high
			if (clk_reg_refclk.sel[0] && VPS_VLD_IN)
				clk_reg_refclk.r[31:16] <= VPS_DAT_IN;	

			// Write low
			else if (clk_reg_refclk.sel[1] && VPS_VLD_IN)
				clk_reg_refclk.r[15:0] <= VPS_DAT_IN;	
		end

		// idle
		else
			clk_reg_refclk.r <= 0;
	end

// Video clock register
	always_ff @ (posedge CLK_IN)
	begin
		// Run
		if (clk_ctl.run)
		begin
			// Write high
			if (clk_reg_vidclk.sel[0] && VPS_VLD_IN)
				clk_reg_vidclk.r[31:16] <= VPS_DAT_IN;	

			// Write low
			else if (clk_reg_vidclk.sel[1] && VPS_VLD_IN)
				clk_reg_vidclk.r[15:0] <= VPS_DAT_IN;	
		end

		// idle
		else
			clk_reg_vidclk.r <= 0;	
	end


/*
	Generator
	In this part the clock enable is generated. 
	Two counters are running. This first counter increments at every clock with the video frequency value.
	The other counter is incremented with the reference clock value when the clock enable is asserted. 
	When the video counter value is less than the reference counter value, then the clock enable is active. 
*/

// Counter A
// This counter is incremented on every clock with the video clock value
	always_ff @ (posedge CLK_IN)
	begin
		// Run
		if (clk_ctl.run)
		begin
			clk_gen.cnt_a <= clk_gen.cnt_a + clk_gen.cnt_a_in;
		end

		else
			clk_gen.cnt_a <= 0;
	end

// Counter A input
	always_ff @ (posedge CLK_IN)
	begin
		clk_gen.cnt_a_in <= clk_reg_vidclk.r;
	end

// Counter A overflow
	always_ff @ (posedge CLK_IN)
	begin
		clk_gen.cnt_a_msb_del <= clk_gen.cnt_a[$size(clk_gen.cnt_a)-1];

		// Run
		if (clk_ctl.run)
		begin
			// Set
			if (clk_gen.cnt_a_msb_del && !clk_gen.cnt_a[$size(clk_gen.cnt_a)-1])
				clk_gen.cnt_a_of <= 1;

			// Clear
			// When counter B has overflown 
			else if (!clk_gen.cnt_b[$size(clk_gen.cnt_b)-1])
				clk_gen.cnt_a_of <= 0;	
		end

		else
			clk_gen.cnt_a_of <= 0;	
	end

// Counter B
// This counter is incremented when the clock enable is asserted the reference clock value
	always_ff @ (posedge CLK_IN)
	begin
		// Run
		if (clk_ctl.run)
		begin
			// Enable
			if (CKE_IN)
				clk_gen.cnt_b <= clk_gen.cnt_b + clk_gen.cnt_b_in;
		end

		else
			clk_gen.cnt_b <= 0;
	end

// Counter B input
	assign clk_gen.cnt_b_in = clk_reg_refclk.r;

// Clock enable
// The clock enable is asserted when counter a is greater than counter b
	always_ff @ (posedge CLK_IN)
	begin
		// Run
		if (clk_ctl.run)
		begin
			if ((clk_gen.cnt_a > clk_gen.cnt_b) || clk_gen.cnt_a_of)
				clk_gen.cke <= 1;
			else
				clk_gen.cke <= 0;
		end

		// Idle
		else
			clk_gen.cke <= 1;
	end

// Outputs
	assign CKE_OUT = clk_gen.cke;

endmodule

`default_nettype wire
