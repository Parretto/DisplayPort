/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: FALD Control
    (c) 2023 by Parretto B.V.

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

module prt_fald_ctl
#(
	parameter P_VENDOR = "none",	// Vendor
	parameter P_IG_PORTS = 8,	// Ingress Ports
	parameter P_OG_PORTS = 8		// Outgress Ports
)
(
	// System
	input wire 								RST_IN,			// Reset
	input wire 								CLK_IN,			// Clock

	// Local bus interface
	prt_dp_lb_if.lb_in   					LB_IF,

	// Ingress 
	input wire [(P_IG_PORTS * 32)-1:0]		IG_IN,	
	
	// Outgress
	output wire [(P_OG_PORTS * 32)-1:0]		OG_OUT,	

	// Led pixel buffer
	output wire [3:0]						LPB_DAT_OUT,	// Data
	output wire 							LPB_VLD_OUT		// Valid	
);

// Parameters
localparam P_CTL_WIDTH = 32;

// Structures
typedef struct {
	logic	[7:0]			adr;
	logic					wr;
	logic					rd;
	logic	[31:0]			din;
	logic	[31:0]			dout;
	logic					vld;
} lb_struct;

typedef struct {
	logic 					sel;
	logic [P_CTL_WIDTH-1:0]	r;
	logic [3:0]				ig;
	logic [3:0]				og;
} ctl_struct;

typedef struct {
	logic 					sel;
	logic [31:0]			r[0:P_IG_PORTS-1];
	logic [31:0]			dat;
} ig_struct;

typedef struct {
	logic 					sel;
	logic [31:0]			r[0:P_OG_PORTS-1];
	logic [31:0]			dat;
} og_struct;

typedef struct {
	logic 					sel;
	logic [3:0]				dat;
	logic 					vld;
} lpb_struct;

// Signals
lb_struct		clk_lb;	
ctl_struct		clk_ctl;
ig_struct		clk_ig;
og_struct		clk_og;
lpb_struct 		clk_lpb;

genvar i;

// Logic

// Local bus inputs
	always_ff @ (posedge CLK_IN)
	begin
		clk_lb.adr	<= LB_IF.adr;
		clk_lb.rd	<= LB_IF.rd;
		clk_lb.wr	<= LB_IF.wr;
		clk_lb.din	<= LB_IF.din;
	end

// Address selector
// Must be combinatorial
	always_comb
	begin
		// Default
		clk_ctl.sel	= 0;
		clk_ig.sel 	= 0;
		clk_og.sel 	= 0;
		clk_lpb.sel	= 0;

		case (clk_lb.adr)
			'd1  	: clk_ig.sel = 1;
			'd2  	: clk_og.sel = 1;
			'd3  	: clk_lpb.sel = 1;
			default : clk_ctl.sel = 1;
		endcase
	end

// Control
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_ctl.r <= 0;

		else
		begin
			// Data
			if (clk_ctl.sel && clk_lb.wr)
				clk_ctl.r <= clk_lb.din[0+:$size(clk_ctl.r)];
		end
	end

// Assign control bits
	assign clk_ctl.ig 	= clk_ctl.r[0+:4];		// Ingress port
	assign clk_ctl.og 	= clk_ctl.r[8+:4];		// Outgress port
	
// Register data out
// Must be combinatorial
	always_comb
	begin
		// Default
		clk_lb.dout = 0;

		// Control register
		if (clk_ctl.sel)
			clk_lb.dout[$size(clk_ctl.r)-1:0] = clk_ctl.r;

		// Outgress data
		else if (clk_og.sel)
			clk_lb.dout = clk_og.dat;

		// Ingress data
		else if (clk_ig.sel)
			clk_lb.dout = clk_ig.dat;
	end

// Valid
// Must be combinatorial
	always_comb
	begin
		if (clk_lb.rd)
			clk_lb.vld = 1;
		else
			clk_lb.vld = 0;
	end

/*
	Ingress
*/
	// Read data register
	always_ff @ (posedge CLK_IN)
	begin
		clk_ig.dat <= clk_ig.r[clk_ctl.ig];
	end

	// Input
	generate
		for (i = 0; i < P_IG_PORTS; i++)
		begin : gen_ig_r
			assign clk_ig.r[i] = IG_IN[(i*32)+:32];
		end
	endgenerate

/*
	Outgress
*/
	// Read data register
	always_ff @ (posedge CLK_IN)
	begin
		clk_og.dat <= clk_og.r[clk_ctl.og];
	end

	generate
		for (i = 0; i < P_OG_PORTS; i++)
		begin : gen_og_r
			always_ff @ (posedge RST_IN, posedge CLK_IN)
			begin
				// Reset
				if (RST_IN)
					clk_og.r[i] <= 0;

				else
				begin
					if ((clk_ctl.og == i) && clk_og.sel && clk_lb.wr)
						clk_og.r[i] <= clk_lb.din;
				end
			end
		end
	endgenerate

/*
	LED pixel buffer
*/

// Write
	always_comb
	begin
		if (clk_lpb.sel && clk_lb.wr)
			clk_lpb.vld = 1;
		else
			clk_lpb.vld = 0;
	end

// Data out
	assign clk_lpb.dat = clk_lb.din[0+:$size(clk_lpb.dat)];

// Outputs
	assign LB_IF.dout 		= clk_lb.dout;
	assign LB_IF.vld		= clk_lb.vld;

	// Outgress
generate
	for (i = 0; i < P_OG_PORTS; i++)
	begin : gen_og_out
		assign OG_OUT[(i*32)+:32] = clk_og.r[i];
	end
endgenerate

	// LED pixel buffer
	assign LPB_DAT_OUT 		= clk_lpb.dat;
	assign LPB_VLD_OUT 		= clk_lpb.vld;
	
endmodule

`default_nettype wire
