/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Scaler Top
    (c) 2022, 2023 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Added polyphase support

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

module prt_scaler_top
#(
	// System
	parameter 								P_VENDOR = "none",  // Vendor "xilsx" or "lattice"

	// Video
	parameter 								P_PPC = 4,          // Pixels per clock
	parameter 								P_BPC = 8           // Bits per component
)
(
	// System
	input wire                              SYS_RST_IN,
	input wire                              SYS_CLK_IN,

	// Local bus interface
	prt_dp_lb_if.lb_in   					LB_IF,

	// Video
	input wire                              VID_CLK_IN,

     // Video in
	input wire								VID_CKE_IN,	 	// Clock enable
	input wire								VID_LOCK_IN,    // Lock
	input wire								VID_VS_IN,      // Vertical sync
	input wire                              VID_HS_IN,      // Horizontal sync    
	input wire     [(P_PPC * P_BPC)-1:0]    VID_R_IN,       // Red
	input wire     [(P_PPC * P_BPC)-1:0]    VID_G_IN,       // Green
	input wire     [(P_PPC * P_BPC)-1:0]    VID_B_IN,       // Blue
	input wire                              VID_DE_IN,      // Data enable

     // Video out
	output wire 							VID_CKE_OUT,	// Clock enable
	output wire                             VID_VS_OUT,     // Vertical sync    
	output wire                             VID_HS_OUT,     // Horizontal sync    
	output wire     [(P_PPC * P_BPC)-1:0]  	VID_R_OUT,      // Red
	output wire     [(P_PPC * P_BPC)-1:0]   VID_G_OUT,      // Green
	output wire     [(P_PPC * P_BPC)-1:0]   VID_B_OUT,      // Blue
	output wire                             VID_DE_OUT      // Data enable
);

// Parameters
localparam P_COEF_MODE = 2; // Coefficient mode width
localparam P_COEF_IDX = 7; // Coefficient index width
localparam P_COEF_DAT = 8; // Coefficient data width
localparam P_COEF_SEL = P_COEF_MODE + P_COEF_IDX; // Coefficient select width
localparam P_MUX_SEL = 4;

// Signals

// Clock enable generator
logic [3:0]						vclk_cke_cnt;
logic							vclk_cke;

// Input registers
logic							vclk_lock_in;
logic							vclk_vs_in;
logic							vclk_hs_in;
logic [(P_PPC * P_BPC)-1:0]  	vclk_r_in;
logic [(P_PPC * P_BPC)-1:0]  	vclk_g_in;
logic [(P_PPC * P_BPC)-1:0]  	vclk_b_in;
logic							vclk_de_in;

// Controller
wire							run_from_ctl;
wire [3:0]						mode_from_ctl;
wire [3:0]						cr_from_ctl;
wire [3:0]						vps_idx_from_ctl;
wire [15:0]						vps_dat_from_ctl;
wire 							vps_vld_from_ctl;

// Timing generator
wire							vs_from_tg;
wire							hs_from_tg;
wire							de_from_tg;

// Config
logic 							vclk_run;
logic [15:0]					vclk_dst_hwidth;
logic [15:0]					vclk_dst_vheight;
logic [15:0]					vclk_src_vheight;

// Agent
wire 							slw_lrst_from_agnt;
wire 							slw_lnxt_from_agnt;
wire [1:0] 						slw_step_from_agnt;
wire [(16*P_COEF_SEL)-1:0]		coef_sel_from_agnt;
wire [(16*P_MUX_SEL)-1:0]       mux_sel_from_agnt;
wire 							krnl_de_from_agnt;

// Line store
wire [2:0] 						rdy_from_lst;
wire [(P_PPC * P_BPC)-1:0]		dat_to_lst[0:2];
wire [(P_PPC * P_BPC)-1:0]		dat_from_lst[0:2][0:1];

// Sliding window
wire [3:0]		   				lst_rd_from_slw[0:2][0:1];
wire [(5 * P_BPC)-1:0]			dat_from_slw[0:2][0:1];
wire [2:0] 						rdy_from_slw;
wire [2:0]						lst_lrst_from_slw;
wire [2:0]						lst_lnxt_from_slw;

// Coefficients
wire [P_COEF_DAT-1:0]			dat_from_coef[0:15];

// Kernel
wire [(P_PPC * P_BPC)-1:0]		dat_from_krnl[0:2];
wire [2:0]  					de_from_krnl;

// Line buffer
wire [2:0]  					rdy_from_lbf;
wire [2:0]  					vs_from_lbf;
wire [2:0]  					hs_from_lbf;
wire [(P_PPC * P_BPC)-1:0]		dat_from_lbf[0:2];
wire [2:0]  					de_from_lbf;
wire [2:0]  					tg_run_from_lbf;

genvar i;

// Input registers
	always_ff @ (posedge VID_CLK_IN)
	begin
		// Clock enable
		if (VID_CKE_IN)
		begin
			vclk_lock_in 	<= VID_LOCK_IN;
			vclk_vs_in 		<= VID_VS_IN;
			vclk_hs_in 		<= VID_HS_IN;
			vclk_r_in 		<= VID_R_IN;
			vclk_g_in 		<= VID_G_IN;
			vclk_b_in 		<= VID_B_IN;
			vclk_de_in 		<= VID_DE_IN;
		end
	end

// Control 
	prt_scaler_ctl
	#(
		.P_VENDOR			(P_VENDOR)
	)
	CTL_INST
	(
		// System
		.SYS_RST_IN			(SYS_RST_IN),			// Reset
		.SYS_CLK_IN			(SYS_CLK_IN),			// Clock

		// Video
		.VID_CLK_IN			(VID_CLK_IN),			// Clock

		// Local bus
		.LB_IF				(LB_IF),

		// Control
		.CTL_RUN_OUT		(run_from_ctl),			// Run
		.CTL_MODE_OUT		(mode_from_ctl),		// Mode
		.CTL_CR_OUT			(cr_from_ctl),			// Clock ratio

		// Video parameter set
		.VPS_IDX_OUT		(vps_idx_from_ctl),		// Index
		.VPS_DAT_OUT		(vps_dat_from_ctl),		// Data
		.VPS_VLD_OUT		(vps_vld_from_ctl)		// Valid
	);

// Run 
// The scaler operation needs to be aligned with the incoming vsync.
// This process assures that the run flag is synchronized with the start of the frame.
	always_ff @ (posedge VID_CLK_IN)
	begin
		// Set
		if (run_from_ctl)
		begin
			if (vclk_vs_in)
				vclk_run <= 1;
		end

		// Idle
		else
			vclk_run <= 0;
	end

// Timing generator
	prt_scaler_tg
	#(
	    .P_PPC 				(P_PPC)         		// Pixels per clock
	)
	TG_INST
	(
		// Reset and clock
		.RST_IN 			(~vclk_lock_in),		// Reset
		.CLK_IN				(VID_CLK_IN),			// Clock
		.CKE_IN				(1'b1),					// Clock enable

		// Control
		.CTL_RUN_IN			(tg_run_from_lbf[0]),	// Run

		// Video parameter set
		.VPS_IDX_IN			(vps_idx_from_ctl),		// Index
		.VPS_DAT_IN			(vps_dat_from_ctl),		// Data
		.VPS_VLD_IN			(vps_vld_from_ctl),		// Valid

		// Video in
		.VID_VS_OUT			(vs_from_tg),			// Vsync
		.VID_HS_OUT			(hs_from_tg),			// Hsync
		.VID_DE_OUT			(de_from_tg)			// Data enable
	);

// Map ls input
	assign dat_to_lst[0] = vclk_r_in;
	assign dat_to_lst[1] = vclk_g_in;
	assign dat_to_lst[2] = vclk_b_in;

// Destination Horizontal width
     always_ff @ (posedge VID_CLK_IN)
     begin
          // Horizontal width
          if ((vps_idx_from_ctl == 'd1) && vps_vld_from_ctl)
               vclk_dst_hwidth <= vps_dat_from_ctl[0+:$size(vclk_dst_hwidth)]; 
     end

// Destination Vertical height
     always_ff @ (posedge VID_CLK_IN)
     begin
          // Vertical height
          if ((vps_idx_from_ctl == 'd5) && vps_vld_from_ctl)
               vclk_dst_vheight <= vps_dat_from_ctl[0+:$size(vclk_dst_vheight)]; 
     end

// Source Vertical height
     always_ff @ (posedge VID_CLK_IN)
     begin
          // Vertical height
          if ((vps_idx_from_ctl == 'd9) && vps_vld_from_ctl)
               vclk_src_vheight <= vps_dat_from_ctl[0+:$size(vclk_src_vheight)]; 
     end

// Agent
	prt_scaler_agnt
	#(
		.P_COEF_MODE		(P_COEF_MODE),        // Coefficient mode width
		.P_COEF_IDX			(P_COEF_IDX),         // Coefficient index width
		.P_COEF_SEL			(P_COEF_SEL),         // Coefficient select width
		.P_MUX_SEL			(P_MUX_SEL)           // Mux select width
	)
	AGNT_INST
	(
		// Reset and clock
		.RST_IN 			(~vclk_lock_in),		// Reset
		.CLK_IN				(VID_CLK_IN),			// Clock

		// Control
		.CTL_RUN_IN			(vclk_run),  	        // Run
		.CTL_FS_IN			(vclk_vs_in),			// Frame start
		.CTL_MODE_IN 		(mode_from_ctl),		// Mode
		.CTL_HWIDTH_IN 		(vclk_dst_hwidth),		// Horizontal width
		.CTL_VHEIGHT_IN 	(vclk_dst_vheight),		// Vertical height

		// Line buffer
		.LBF_RDY_IN 		(rdy_from_lbf[0]),		// Ready

		// Sliding window
		.SLW_RDY_IN 		(rdy_from_slw[0]),		// Ready
		.SLW_LRST_OUT		(slw_lrst_from_agnt),	// Restore line
		.SLW_LNXT_OUT		(slw_lnxt_from_agnt),	// Next line
		.SLW_STEP_OUT		(slw_step_from_agnt),	// Position

		// Coefficients
		.COEF_SEL_OUT		(coef_sel_from_agnt),

		// Mux
		.MUX_SEL_OUT		(mux_sel_from_agnt),

		// Kernel
		.KRNL_DE_OUT 		(krnl_de_from_agnt)
	);

// Line store
generate
	for (i = 0; i < 3; i++)
	begin : gen_lst
		prt_scaler_lst
		#(
		    .P_VENDOR			(P_VENDOR),
		    .P_PPC 				(P_PPC),          	// Pixels per clock
		    .P_BPC 				(P_BPC)           	// Bits per component
		)
		LST_INST
		(
			// Reset and clock
			.RST_IN 			(~vclk_lock_in),		// Reset
			.CLK_IN				(VID_CLK_IN),

			// Control
			.CTL_RUN_IN			(vclk_run),				// Run
			.CTL_VHEIGHT_IN 	(vclk_src_vheight),		// Vertical height

			// Video
			.VID_CKE_IN			(VID_CKE_IN),
			.VID_VS_IN			(vclk_vs_in),
			.VID_HS_IN			(vclk_hs_in),
			.VID_DE_IN			(vclk_de_in),
			.VID_DAT_IN			(dat_to_lst[i]),

			// Lines out
			.LST_RDY_OUT 		(rdy_from_lst[i]),				// Ready
			.LST_LRST_IN		(lst_lrst_from_slw[0]),	  		// Restore
			.LST_LNXT_IN		(lst_lnxt_from_slw[0]),    		// Next
			.LST_RD0_IN			(lst_rd_from_slw[i][0]),   		// Read line 0
			.LST_RD1_IN			(lst_rd_from_slw[i][1]),   		// Read line 1
			.LST_DAT0_OUT		(dat_from_lst[i][0]),  			// Data line 0
			.LST_DAT1_OUT		(dat_from_lst[i][1])  			// Data line 1
		);
	end
endgenerate

// Sliding window
generate
	for (i = 0; i < 3; i++)
	begin : gen_slw
		prt_scaler_slw
		#(
			.P_PPC				(P_PPC),          // Pixels per clock
			.P_BPC 				(P_BPC)           // Bits per component
		)
		SLW_INST
		(
			// Reset and clock
			.RST_IN 			(~vclk_lock_in),			// Reset
			.CLK_IN				(VID_CLK_IN),

			// Control
			.CTL_RUN_IN			(vclk_run),					// Run
			.CTL_FS_IN			(vclk_vs_in),				// Frame start

			// Line store
			.LST_RDY_IN			(rdy_from_lst[0]),			// Ready
			.LST_DAT0_IN		(dat_from_lst[i][0]),		// Data line 0
			.LST_DAT1_IN		(dat_from_lst[i][1]),		// Data line 1
			.LST_RD0_OUT		(lst_rd_from_slw[i][0]),	// Read line 0
			.LST_RD1_OUT		(lst_rd_from_slw[i][1]),	// Read line 1
			.LST_LRST_OUT 		(lst_lrst_from_slw[i]),		// Restore
			.LST_LNXT_OUT 		(lst_lnxt_from_slw[i]),		// Next

			// Sliding window
			.SLW_LRST_IN		(slw_lrst_from_agnt),		// Restore
			.SLW_LNXT_IN		(slw_lnxt_from_agnt),		// Next
			.SLW_STEP_IN		(slw_step_from_agnt),		// Position
			.SLW_DAT0_OUT		(dat_from_slw[i][0]),		// Data line 0
			.SLW_DAT1_OUT		(dat_from_slw[i][1]),		// Data line 1
			.SLW_RDY_OUT		(rdy_from_slw[i])			// Ready
		);
	end
endgenerate

// Coefficients
generate
	for (i = 0; i < 16; i++)
	begin : gen_coef
		prt_scaler_coef
		#(
			.P_MODE		(P_COEF_MODE),         // Ratio width
			.P_IDX		(P_COEF_IDX),         // Index width
			.P_DAT		(P_COEF_DAT)          // Coefficient width
		)
		COEF_INST
		(
			// Reset and clock
			.CLK_IN			(VID_CLK_IN),
			.SEL_IN			(coef_sel_from_agnt[(i*P_COEF_SEL)+:P_COEF_SEL]), 	// Select
			.DAT_OUT		(dat_from_coef[i])
		);
	end
endgenerate

// Kernel
generate
	for (i = 0; i < 3; i++)
	begin : gen_krnl
		prt_scaler_krnl
		#(
			.P_PPC 				(P_PPC),          	// Pixels per clock
			.P_BPC 				(P_BPC)           	// Bits per component
		)
		KRNL_INST
		(
			// Reset and clock
			.RST_IN 			(~vclk_lock_in),		// Reset
			.CLK_IN				(VID_CLK_IN),

			// Agent
			.AGNT_DE_IN			(krnl_de_from_agnt),	// Data enable

			// Coefficients
			.COEF_P0_IN			({dat_from_coef[3],  dat_from_coef[2],  dat_from_coef[1],  dat_from_coef[0]}),
			.COEF_P1_IN			({dat_from_coef[7],  dat_from_coef[6],  dat_from_coef[5],  dat_from_coef[4]}),
			.COEF_P2_IN			({dat_from_coef[11], dat_from_coef[10], dat_from_coef[9],  dat_from_coef[8]}),
			.COEF_P3_IN			({dat_from_coef[15], dat_from_coef[14], dat_from_coef[13], dat_from_coef[12]}),

			// Mux
			.MUX_SEL_IN			(mux_sel_from_agnt),

			// Sliding window
			.SLW_DAT0_IN		(dat_from_slw[i][0]),     	// Data line 0
			.SLW_DAT1_IN		(dat_from_slw[i][1]),       // Data line 1
			
			// Video out
			.VID_DAT_OUT		(dat_from_krnl[i]),
			.VID_DE_OUT			(de_from_krnl[i])
		);
	end
endgenerate

// Line buffer
generate
	for (i = 0; i < 3; i++)
	begin : gen_lbf
		prt_scaler_lbf
		#(
			.P_VENDOR			(P_VENDOR),
			.P_PPC 				(P_PPC),          	// Pixels per clock
			.P_BPC 				(P_BPC)           	// Bits per component
		)
		LBF_INST
		(
			// Reset and clock
			.RST_IN 			(~vclk_lock_in),		// Reset
			.CLK_IN				(VID_CLK_IN),

			// Control
			.CTL_RUN_IN			(vclk_run),				// Run
			.CTL_FS_IN			(vclk_vs_in),			// Frame start

			// FIFO
			.LBF_RDY_OUT 		(rdy_from_lbf[i]),		// Ready

			// Timing generator
			.TG_VS_IN			(vs_from_tg),      		// Vsync
			.TG_HS_IN			(hs_from_tg),      		// Hsync
			.TG_DE_IN			(de_from_tg),      		// Data enable
			.TG_RUN_OUT			(tg_run_from_lbf[i]),   // Run

			// Video in
			.VID_DAT_IN			(dat_from_krnl[i]),		// Data
			.VID_DE_IN			(de_from_krnl[i]),		// Data enable

			// Video out
			.VID_VS_OUT			(vs_from_lbf[i]),		// Vsync
			.VID_HS_OUT			(hs_from_lbf[i]),		// Hsync
			.VID_DAT_OUT		(dat_from_lbf[i]),		// Data
			.VID_DE_OUT			(de_from_lbf[i])		// Data enable
		);
	end
endgenerate

// Clock enable generator
	always_ff @ (posedge VID_CLK_IN)
	begin
		// Run
		if (vclk_run)
		begin
			if (vclk_cke_cnt == 0)
			begin
				vclk_cke <= 1;
				vclk_cke_cnt <= cr_from_ctl - 'd1;
			end

			else
			begin
				vclk_cke <= 0;
				vclk_cke_cnt <= vclk_cke_cnt - 'd1;
			end
		end

		// Idle
		else
		begin
			vclk_cke <= 1;
			vclk_cke_cnt <= 0;
		end		
	end

// Outputs
	assign VID_CKE_OUT = vclk_cke;
	assign VID_VS_OUT = (run_from_ctl) ? vs_from_lbf[0] : vclk_vs_in;
	assign VID_HS_OUT = (run_from_ctl) ? hs_from_lbf[0] : vclk_hs_in;
	assign VID_R_OUT = (run_from_ctl) ? dat_from_lbf[0] : vclk_r_in;
	assign VID_G_OUT = (run_from_ctl) ? dat_from_lbf[1] : vclk_g_in;
	assign VID_B_OUT = (run_from_ctl) ? dat_from_lbf[2] : vclk_b_in;
	assign VID_DE_OUT = (run_from_ctl) ? de_from_lbf[0] : vclk_de_in;

endmodule

`default_nettype wire
