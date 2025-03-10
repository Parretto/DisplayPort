/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Video Toolbox Timing Generator
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

// Module
module prt_vtb_tg
#(
	parameter P_PPC = 2					// Pixels per clock
)
(
	// Reset and clock
	input wire 			RST_IN,			// Reset
	input wire 			CLK_IN,			// Clock
 	input wire 			CKE_IN,			// Clock enable

	// Control
 	input wire 			CTL_RUN_IN,		// Run
 	input wire 			CTL_MODE_IN,	// Mode ; 0 - free running / 1 - sync

	// Video parameter set
	input wire [3:0]	VPS_IDX_IN,		// Index
	input wire [15:0]	VPS_DAT_IN,		// Data
	input wire 			VPS_VLD_IN,		// Valid	

	// Native video
 	output wire 		VID_VS_OUT,		// Vsync
 	output wire 		VID_HS_OUT,		// Hsync
 	output wire 		VID_DE_OUT		// Data enable
);

// Localparam

// Structures
typedef struct {
	logic						run;		// Run
	logic						run_re;		// Run
	logic						mode;		// Mode
} ctl_struct;

typedef struct {
	logic 	[15:0]				r;			// Register
	logic						sel;		// Select
} reg_struct;

typedef struct {
	logic [15:0]				hblk;		// Horizontal blanking period
	logic [15:0]				vblk;		// Vertical blanking period
	logic [15:0]				hs_str;		// Horizontal sync start
	logic [15:0]				hs_end;		// Horizontal sync end
	logic [15:0]				hde_str;	// Horizontal de start
	logic [15:0]				vs_str;		// Vertical sync start
	logic [15:0]				vs_end;		// Vertical sync end
	logic [15:0]				vde_str;	// Vertical de start
	logic [15:0]				hcnt;		// Horizontal counter
	logic [15:0]				vcnt;		// Vertical counter
	logic 						vs;			// Vsync
	logic [2:0]  				hs;			// Hsync
	logic 						hs_re;		// Hsync rising edge
	logic [2:0] 				de;			// Data enable
} vid_struct;

// Signals
ctl_struct 		clk_ctl;
reg_struct 		clk_reg_htotal;
reg_struct 		clk_reg_hwidth;
reg_struct 		clk_reg_hstart;
reg_struct 		clk_reg_hsw;
reg_struct 		clk_reg_vtotal;
reg_struct 		clk_reg_vheight;
reg_struct 		clk_reg_vstart;
reg_struct 		clk_reg_vsw;
vid_struct 		clk_vid;

// Logic

// Inputs
	always_ff @ (posedge CLK_IN)
	begin
		clk_ctl.run 	<= CTL_RUN_IN;
		clk_ctl.mode 	<= CTL_MODE_IN;
	end

// run edge detector
// This is used to set the counter when in sync mode
    prt_dp_lib_edge
    RUN_EDGE_INST
    (
        .CLK_IN    (CLK_IN), 		       	// Clock
        .CKE_IN    (CKE_IN),           	 	// Clock enable
        .A_IN      (clk_ctl.run), 	     	// Input
        .RE_OUT    (clk_ctl.run_re),  		// Rising edge
        .FE_OUT    ()   					// Falling edge
    );

// Register select
	always_comb
	begin
		// Default
		clk_reg_htotal.sel  = 0;
		clk_reg_hwidth.sel  = 0;
		clk_reg_hstart.sel  = 0;
		clk_reg_hsw.sel 	= 0;
		clk_reg_vtotal.sel  = 0;
		clk_reg_vheight.sel = 0;
		clk_reg_vstart.sel  = 0;
		clk_reg_vsw.sel 	= 0;
		
		case (VPS_IDX_IN)
			'd4  : clk_reg_htotal.sel  = 1;
			'd5  : clk_reg_hwidth.sel  = 1;
			'd6  : clk_reg_hstart.sel  = 1;
			'd7  : clk_reg_hsw.sel 	   = 1;
			'd8  : clk_reg_vtotal.sel  = 1;
			'd9  : clk_reg_vheight.sel = 1;
			'd10 : clk_reg_vstart.sel  = 1;
			'd11 : clk_reg_vsw.sel 	   = 1;
			default : ;
		endcase
	end	

// Htotal register
	always_ff @ (posedge CLK_IN)
	begin
		// Write
		if (clk_reg_htotal.sel && VPS_VLD_IN)
			clk_reg_htotal.r <= VPS_DAT_IN[0+:$size(clk_reg_htotal.r)];	
	end

// Hwidth register
	always_ff @ (posedge CLK_IN)
	begin
		// Write
		if (clk_reg_hwidth.sel && VPS_VLD_IN)
			clk_reg_hwidth.r <= VPS_DAT_IN[0+:$size(clk_reg_hwidth.r)]; 
	end

// Hstart register
	always_ff @ (posedge CLK_IN)
	begin
		// Write
		if (clk_reg_hstart.sel && VPS_VLD_IN)
			clk_reg_hstart.r <= VPS_DAT_IN[0+:$size(clk_reg_hstart.r)]; 
	end

// Hsw register
	always_ff @ (posedge CLK_IN)
	begin
		// Write
		if (clk_reg_hsw.sel && VPS_VLD_IN)
			clk_reg_hsw.r <= VPS_DAT_IN[0+:$size(clk_reg_hsw.r)]; 
	end

// Vtotal register
	always_ff @ (posedge CLK_IN)
	begin
		// Write
		if (clk_reg_vtotal.sel && VPS_VLD_IN)
			clk_reg_vtotal.r <= VPS_DAT_IN[0+:$size(clk_reg_vtotal.r)];
	end

// Vheight register
	always_ff @ (posedge CLK_IN)
	begin
		// Write
		if (clk_reg_vheight.sel && VPS_VLD_IN)
			clk_reg_vheight.r <= VPS_DAT_IN[0+:$size(clk_reg_vheight.r)];
	end

// Vstart register
	always_ff @ (posedge CLK_IN)
	begin
		// Write
		if (clk_reg_vstart.sel && VPS_VLD_IN)
			clk_reg_vstart.r <= VPS_DAT_IN[0+:$size(clk_reg_vstart.r)];
	end

// Vsw register
	always_ff @ (posedge CLK_IN)
	begin
		// Write
		if (clk_reg_vsw.sel && VPS_VLD_IN)
			clk_reg_vsw.r <= VPS_DAT_IN[0+:$size(clk_reg_vsw.r)];
	end

// Register timing properties to improve timing
	always_ff @ (posedge CLK_IN)
	begin
		
		// Horizontal blanking period
		clk_vid.hblk <= clk_reg_htotal.r - clk_reg_hwidth.r;

		// Horizontal sync start
		clk_vid.hs_str <= clk_vid.hblk - clk_reg_hstart.r;

		// Horizontal sync end
		clk_vid.hs_end <= clk_vid.hs_str + clk_reg_hsw.r;

		// Horizontal de start
		clk_vid.hde_str <= clk_vid.hblk;

		// Vertical blanking period
		clk_vid.vblk <= clk_reg_vtotal.r - clk_reg_vheight.r;

		// Vertical sync start
		clk_vid.vs_str <= clk_vid.vblk - clk_reg_vstart.r;

		// Vertical sync end
		clk_vid.vs_end <= clk_vid.vs_str + clk_reg_vsw.r;

		// Vertical de start
		clk_vid.vde_str <= clk_vid.vblk;
	end

// Horizontal counter
	always_ff @ (posedge CLK_IN)
	begin
		// Preset counter in sync mode
		if (clk_ctl.run_re && clk_ctl.mode)
			clk_vid.hcnt <= clk_vid.hde_str;

		// Run
		else if (clk_ctl.run)
		begin
			// Clock enable
			if (CKE_IN)
			begin
				// Increment
				if (clk_vid.hcnt < clk_reg_htotal.r - P_PPC)
					clk_vid.hcnt <= clk_vid.hcnt + P_PPC;

				// Reset
				else
					clk_vid.hcnt <= 0;
			end
		end

		// Idle
		else
			clk_vid.hcnt <= 0;
	end

// Vertical counter
	always_ff @ (posedge CLK_IN)
	begin
		// Preset counter in sync mode
		if (clk_ctl.run_re && clk_ctl.mode)
			clk_vid.vcnt <= clk_vid.vde_str;

		// Run
		else if (clk_ctl.run)
		begin
			// Clock enable
			if (CKE_IN)
			begin
				// Increment
				if (clk_vid.hs_re)
				begin
					if (clk_vid.vcnt < clk_reg_vtotal.r - 'd1)
						clk_vid.vcnt <= clk_vid.vcnt + 'd1;

					else
						clk_vid.vcnt <= 0;
				end
			end
		end

		// Idle
		else
			clk_vid.vcnt <= 0;
	end

// Hsync
	always_ff @ (posedge CLK_IN)
	begin
		// Run
		if (clk_ctl.run)
		begin
			// Clock enable
			if (CKE_IN)
			begin
				if ((clk_vid.hcnt >= clk_vid.hs_str) && (clk_vid.hcnt < clk_vid.hs_end))
					clk_vid.hs[0] <= 1;
				else
					clk_vid.hs[0] <= 0;	

				// The hsync is used to increment the vertical counter
				// To align the hsync with the vsync, the hsync must be delayed for two clock cycles
				clk_vid.hs[2:1] <= clk_vid.hs[1:0];
			end
		end

		// Idle
		else
			clk_vid.hs <= 0;
	end

// Hsync edge detector
// This is used to increment the vertical counter
    prt_dp_lib_edge
    HS_EDGE_INST
    (
        .CLK_IN    (CLK_IN), 		       	// Clock
        .CKE_IN    (CKE_IN),           	 	// Clock enable
        .A_IN      (clk_vid.hs[0]),      	// Input
        .RE_OUT    (clk_vid.hs_re),  		// Rising edge
        .FE_OUT    ()   					// Falling edge
    );

// Vsync
	always_ff @ (posedge CLK_IN)
	begin
		// Run
		if (clk_ctl.run)
		begin
			// Clock enable
			if (CKE_IN)
			begin
				if ((clk_vid.vcnt >= clk_vid.vs_str) && (clk_vid.vcnt < clk_vid.vs_end))
					clk_vid.vs <= 1;
				else
					clk_vid.vs <= 0;	
			end
		end

		// Idle
		else
			clk_vid.vs <= 0;
	end

// Data enable
	always_ff @ (posedge CLK_IN)
	begin
		// Run
		if (clk_ctl.run)
		begin
			// Clock enable
			if (CKE_IN)
			begin
				if ((clk_vid.hcnt >= clk_vid.hde_str) && (clk_vid.vcnt >= clk_vid.vde_str))
					clk_vid.de[0] <= 1;

				else
					clk_vid.de[0] <= 0;

				// To align with the hsync, de must be delayed for two clock cycles
				clk_vid.de[2:1] <= clk_vid.de[1:0];
			end
		end

		// Idle
		else
			clk_vid.de <= 0;
	end

// Outputs
	assign VID_VS_OUT = clk_vid.vs;
	assign VID_HS_OUT = clk_vid.hs[$size(clk_vid.hs)-1];
	assign VID_DE_OUT = clk_vid.de[$size(clk_vid.de)-1];
	
endmodule

`default_nettype wire
