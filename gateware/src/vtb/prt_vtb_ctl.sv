/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Video Toolbox Control
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

module prt_vtb_ctl
#(
	parameter P_VENDOR = "none",	// Vendor
	parameter P_IG_PORTS = 8,	// Ingress Ports
	parameter P_OG_PORTS = 8		// Outgress Ports
)
(
	// System
	input wire 						SYS_RST_IN,			// Reset
	input wire 						SYS_CLK_IN,			// Clock

	// Video
	input wire 						VID_RST_IN,			// Reset
	input wire 						VID_CLK_IN,			// Clock

	// Local bus interface
	prt_dp_lb_if.lb_in   				LB_IF,

	// Ingress 
	input wire [(P_IG_PORTS * 32)-1:0]		IG_IN,	
	
	// Outgress
	output wire [(P_OG_PORTS * 32)-1:0]	OG_OUT,	

	// Video parameter set
	output wire [3:0]					VPS_IDX_OUT,			// Index
	output wire [15:0]					VPS_DAT_OUT,			// Data
	output wire 						VPS_VLD_OUT			// Valid	
);

// Parameters
localparam P_CTL_WIDTH = 32;

localparam P_RAM_ADR = 4;
localparam P_RAM_DAT = 16;

// Structures
typedef struct {
	logic	[7:0]		adr;
	logic				wr;
	logic				rd;
	logic	[31:0]		din;
	logic	[31:0]		dout;
	logic				vld;
} lb_struct;

typedef struct {
	logic 					sel;
	logic [P_CTL_WIDTH-1:0]	r;
	logic [3:0]				ig;
	logic [3:0]				og;
	logic [3:0]				vps;
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
	logic [P_RAM_ADR-1:0]	adr;
	logic 					wr;
	logic [P_RAM_DAT-1:0]	din;
} vps_wr_struct;

typedef struct {
	logic [P_RAM_ADR-1:0]	adr[0:1];
	logic 					rd;
	logic [P_RAM_DAT-1:0]	dout;
	logic 					vld;
} vps_rd_struct;

// Signals
lb_struct		sclk_lb;	
ctl_struct		sclk_ctl;
ig_struct		sclk_ig;
og_struct		sclk_og;
vps_wr_struct 	sclk_vps;
vps_rd_struct 	vclk_vps;

genvar i;

// Logic

// Local bus inputs
	always_ff @ (posedge SYS_CLK_IN)
	begin
		sclk_lb.adr	<= LB_IF.adr;
		sclk_lb.rd	<= LB_IF.rd;
		sclk_lb.wr	<= LB_IF.wr;
		sclk_lb.din	<= LB_IF.din;
	end

// Address selector
// Must be combinatorial
	always_comb
	begin
		// Default
		sclk_ctl.sel	= 0;
		sclk_ig.sel 	= 0;
		sclk_og.sel 	= 0;
		sclk_vps.sel	= 0;

		case (sclk_lb.adr)
			'd1  	: sclk_ig.sel = 1;
			'd2  	: sclk_og.sel = 1;
			'd3  	: sclk_vps.sel = 1;
			default 	: sclk_ctl.sel = 1;
		endcase
	end

// Control
	always_ff @ (posedge SYS_RST_IN, posedge SYS_CLK_IN)
	begin
		// Reset
		if (SYS_RST_IN)
			sclk_ctl.r <= 0;

		else
		begin
			// Data
			if (sclk_ctl.sel && sclk_lb.wr)
				sclk_ctl.r <= sclk_lb.din[0+:$size(sclk_ctl.r)];
		end
	end

// Assign control bits
	assign sclk_ctl.ig 	= sclk_ctl.r[0+:4];		// Ingress port
	assign sclk_ctl.og 	= sclk_ctl.r[8+:4];		// Outgress port
	assign sclk_ctl.vps	= sclk_ctl.r[16+:4];	// Video parameters address

// Register data out
// Must be combinatorial
	always_comb
	begin
		// Default
		sclk_lb.dout = 0;

		// Control register
		if (sclk_ctl.sel)
			sclk_lb.dout[$size(sclk_ctl.r)-1:0] = sclk_ctl.r;

		// Outgress data
		else if (sclk_og.sel)
			sclk_lb.dout = sclk_og.dat;

		// Ingress data
		else if (sclk_ig.sel)
			sclk_lb.dout = sclk_ig.dat;
	end

// Valid
// Must be combinatorial
	always_comb
	begin
		if (sclk_lb.rd)
			sclk_lb.vld = 1;
		else
			sclk_lb.vld = 0;
	end

/*
	Ingress
*/
	// Read data register
	always_ff @ (posedge SYS_CLK_IN)
	begin
		sclk_ig.dat <= sclk_ig.r[sclk_ctl.ig];
	end

	// Input
	generate
		for (i = 0; i < P_IG_PORTS; i++)
		begin : gen_ig_r
			assign sclk_ig.r[i] = IG_IN[(i*32)+:32];
		end
	endgenerate

/*
	Outgress
*/
	// Read data register
	always_ff @ (posedge SYS_CLK_IN)
	begin
		sclk_og.dat <= sclk_og.r[sclk_ctl.og];
	end

	generate
		for (i = 0; i < P_OG_PORTS; i++)
		begin : gen_og_r
			always_ff @ (posedge SYS_RST_IN, posedge SYS_CLK_IN)
			begin
				// Reset
				if (SYS_RST_IN)
					sclk_og.r[i] <= 0;

				else
				begin
					if ((sclk_ctl.og == i) && sclk_og.sel && sclk_lb.wr)
						sclk_og.r[i] <= sclk_lb.din;
				end
			end
		end
	endgenerate

/*
	VPS
*/
// Address
	assign sclk_vps.adr = sclk_ctl.vps;

// Write
	always_comb
	begin
		if (sclk_vps.sel && sclk_lb.wr)
			sclk_vps.wr = 1;
		else
			sclk_vps.wr = 0;
	end

// Data out
	assign sclk_vps.din = sclk_lb.din[0+:$size(sclk_vps.din)];

// Dual ported ram
// This is used to cross the video parameters into the video clock domain
	prt_dp_lib_sdp_ram_dc
	#(
		.P_VENDOR		(P_VENDOR),
		.P_RAM_STYLE	("distributed"),	// "distributed", "block" or "ultra"
		.P_ADR_WIDTH 	(P_RAM_ADR),
		.P_DAT_WIDTH 	(P_RAM_DAT)
	)
	RAM_INST
	(
		// Port A
		.A_RST_IN		(SYS_RST_IN),		// Reset
		.A_CLK_IN		(SYS_CLK_IN),		// Clock
		.A_ADR_IN		(sclk_vps.adr),		// Address
		.A_WR_IN		(sclk_vps.wr),		// Write in
		.A_DAT_IN		(sclk_vps.din),		// Write data

		// Port B
		.B_RST_IN		(VID_RST_IN),		// Reset
		.B_CLK_IN		(VID_CLK_IN),		// Clock
		.B_ADR_IN		(vclk_vps.adr[0]),	// Address
		.B_RD_IN		(vclk_vps.rd),		// Read in
		.B_DAT_OUT		(vclk_vps.dout),	// Read data
		.B_VLD_OUT		(vclk_vps.vld)		// Read data valid
	);

// VPS address
	always_ff @ (posedge VID_RST_IN, posedge VID_CLK_IN)
	begin
		// Reset
		if (VID_RST_IN)
			vclk_vps.adr <= '{0, 0};
		
		else
		begin		
			// Overflow
			if (&vclk_vps.adr[0])
				vclk_vps.adr[0] <= 0;
			
			// Increment
			else
				vclk_vps.adr[0] <= vclk_vps.adr[0] + 'd1;
		
			// The memory has a read latency of one clock.
			// So the read adress needs to be delayed
			vclk_vps.adr[1] <= vclk_vps.adr[0];
		end
	end

// Read
// The memory is always reading
	always_ff @ (posedge VID_RST_IN, posedge VID_CLK_IN)
	begin
		// Reset
		if (VID_RST_IN)
			vclk_vps.rd <= 0;

		else
			vclk_vps.rd <= 1;
	end

// Outputs
	assign LB_IF.dout 		= sclk_lb.dout;
	assign LB_IF.vld		= sclk_lb.vld;

	// Outgress
generate
	for (i = 0; i < P_OG_PORTS; i++)
	begin : gen_og_out
		assign OG_OUT[(i*32)+:32] = sclk_og.r[i];
	end
endgenerate

	// VPS	
	assign VPS_DAT_OUT 		= vclk_vps.dout;
	assign VPS_IDX_OUT 		= vclk_vps.adr[1];
	assign VPS_VLD_OUT 		= vclk_vps.vld;
	
endmodule

`default_nettype wire
