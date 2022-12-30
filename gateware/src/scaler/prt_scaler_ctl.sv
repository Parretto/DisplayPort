/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Scaler Control
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

`default_nettype none

module prt_scaler_ctl
#(
	// System
	parameter 						P_VENDOR = "none"  // Vendor "xilinx" or "lattice"
)
(
	// System
	input wire 						SYS_RST_IN,			// Reset
	input wire 						SYS_CLK_IN,			// Clock

	// Video
	input wire 						VID_CLK_IN,			// Clock

	// Local bus interface
	prt_dp_lb_if.lb_in   			LB_IF,

	// Control output
	output wire 					CTL_RUN_OUT,		// Run
	output wire [3:0]				CTL_MODE_OUT, 		// Mode
	output wire [3:0]				CTL_CR_OUT,			// Clock ratio

	// Video parameter set
	output wire [3:0]				VPS_IDX_OUT,		// Index
	output wire [15:0]				VPS_DAT_OUT,		// Data
	output wire 					VPS_VLD_OUT			// Valid	
);

// Parameters
localparam P_CTL_RUN = 0;
localparam P_CTL_WIDTH = 32;
localparam P_RAM_ADR = 4;
localparam P_RAM_DAT = 16;

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
	logic					run;
	logic [3:0]				mode;
	logic [3:0]				cr;
	logic [3:0]				vps;
} ctl_struct;

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
vps_wr_struct 	sclk_vps;
vps_rd_struct 	vclk_vps;
wire			vclk_run;
wire  [3:0]		vclk_mode;
wire  [3:0]		vclk_cr;

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
		sclk_vps.sel	= 0;

		case (sclk_lb.adr)
			'd1  	: sclk_vps.sel = 1;
			default : sclk_ctl.sel = 1;
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
	assign sclk_ctl.run		= sclk_ctl.r[P_CTL_RUN];	// Run
	assign sclk_ctl.mode	= sclk_ctl.r[1+:4];			// Mode
	assign sclk_ctl.cr		= sclk_ctl.r[5+:4];			// Clock ratio
	assign sclk_ctl.vps		= sclk_ctl.r[9+:4];			// Video parameters address

// Register data out
// Must be combinatorial
	always_comb
	begin
		// Default
		sclk_lb.dout = 0;

		// Control register
		if (sclk_ctl.sel)
			sclk_lb.dout[$size(sclk_ctl.r)-1:0] = sclk_ctl.r;
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

// Control run clock domain crossing
    prt_scaler_lib_cdc
    #(
    	.P_WIDTH 		(1) 
    )
    CTL_RUN_CDC_INST
    (
        .SRC_CLK_IN     (SYS_CLK_IN),  	// Clock
        .SRC_DAT_IN  	(sclk_ctl.run), // Data
        .DST_CLK_IN     (VID_CLK_IN),   // Clock
        .DST_DAT_OUT 	(vclk_run)   	// Data
    );

// Cross mode value
	prt_scaler_lib_cdc
	#(
		.P_WIDTH		($size(sclk_ctl.mode))
	)
	CTL_MODE_CDC_INST
	(
		.SRC_CLK_IN		(SYS_CLK_IN),		// Clock
		.SRC_DAT_IN		(sclk_ctl.mode),	// Data
		.DST_CLK_IN		(VID_CLK_IN),		// Clock
		.DST_DAT_OUT	(vclk_mode)			// Data
	);

// Cross clock ratio value
	prt_scaler_lib_cdc
	#(
		.P_WIDTH		($size(sclk_ctl.cr))
	)
	CTL_CR_CDC_INST
	(
		.SRC_CLK_IN		(SYS_CLK_IN),		// Clock
		.SRC_DAT_IN		(sclk_ctl.cr),		// Data
		.DST_CLK_IN		(VID_CLK_IN),		// Clock
		.DST_DAT_OUT	(vclk_cr)			// Data
	);

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
	prt_scaler_lib_sdp_ram_dc
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
		.B_RST_IN		(~vclk_run),		// Reset
		.B_CLK_IN		(VID_CLK_IN),		// Clock
		.B_ADR_IN		(vclk_vps.adr[0]),	// Address
		.B_RD_IN		(vclk_vps.rd),		// Read in
		.B_DAT_OUT		(vclk_vps.dout),	// Read data
		.B_VLD_OUT		(vclk_vps.vld)		// Read data valid
	);

// VPS address
	always_ff @ (posedge VID_CLK_IN)
	begin
		// Run
		if (vclk_run)
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

		// Idle
		else
			vclk_vps.adr <= '{0, 0};

	end

// Read
// The memory is always reading
	always_ff @ (posedge VID_CLK_IN)
	begin
		// Run
		if (vclk_run)
			vclk_vps.rd <= 1;

		// Idle
		else
			vclk_vps.rd <= 0;
	end

// Outputs
	assign LB_IF.dout 		= sclk_lb.dout;
	assign LB_IF.vld		= sclk_lb.vld;

	// Control
	assign CTL_RUN_OUT		= vclk_run;
	assign CTL_MODE_OUT		= vclk_mode;
	assign CTL_CR_OUT		= vclk_cr;

	// VPS	
	assign VPS_DAT_OUT 		= vclk_vps.dout;
	assign VPS_IDX_OUT 		= vclk_vps.adr[1];
	assign VPS_VLD_OUT 		= vclk_vps.vld;
	
endmodule

`default_nettype wire
