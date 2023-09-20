/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Video Toolbox Top
    (c) 2021 - 2023 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
	v1.1 - Added color format to TPG
	v1.2 - Added overlay module

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

module prt_vtb_top
#(
    parameter P_VENDOR = "none",  			// Vendor "xilinx", "intel" or "lattice"
	parameter P_SYS_FREQ = 'd50_000_000,	// System frequency
	parameter P_PPC = 2,					// Pixels per clock
	parameter P_BPC = 8,					// Bits per component
    parameter P_AXIS_DAT = 48,				// AXIS data width
	parameter P_OVL = 0						// Overlay (0 - disable / 1 - Image 1 / 2 - Image 2)
)
(
	// System
	input wire 								SYS_RST_IN,				// Reset
	input wire 								SYS_CLK_IN,				// Clock

	// Local bus interface
	prt_dp_lb_if.lb_in   					LB_IF,

	// Direct I2C Access
	input wire								DIA_RDY_IN,
	output wire [31:0] 						DIA_DAT_OUT,
	output wire								DIA_VLD_OUT,

	// Link
	input wire 								TX_LNK_CLK_IN,			// TX link clock
	input wire 								RX_LNK_CLK_IN,			// RX link clock
	input wire								LNK_SYNC_IN,			// Sync

	// Video
  	input wire 								VID_CKE_IN,				// Clock enable
	input wire 								VID_CLK_IN,				// Clock

	// Video in
   	input wire          					AXIS_SOF_IN,    		// Start of frame
	input wire          					AXIS_EOL_IN,    		// End of line
    input wire [P_AXIS_DAT-1:0]  			AXIS_DAT_IN,    		// Data
    input wire          					AXIS_VLD_IN,    		// Valid

    // Video out
	output wire  							VID_LOCK_OUT,			// Lock
  	output wire 							VID_VS_OUT,				// Vsync
  	output wire 							VID_HS_OUT,				// Hsync
  	output wire [(P_BPC * P_PPC)-1:0]		VID_R_OUT,				// Red
  	output wire [(P_BPC * P_PPC)-1:0]		VID_G_OUT,				// Green
  	output wire [(P_BPC * P_PPC)-1:0]		VID_B_OUT,				// Blue
   	output wire 							VID_DE_OUT				// Data enable out
);

// Localparameters
// Simulation
localparam P_SIM =
// synthesis translate_off
(1) ? 1 :
// synthesis translate_on
0;
localparam P_CTL_IG_PORTS = 9;	// Controller ingress ports 
localparam P_CTL_OG_PORTS = 2;	// Controller outgress ports

localparam P_CTL_LNK_EN 	= 0;
localparam P_CTL_VID_EN 	= 1;
localparam P_CTL_CG_RUN 	= 2;
localparam P_CTL_TG_RUN 	= 3;
localparam P_CTL_TG_MODE 	= 4;
localparam P_CTL_TPG_RUN 	= 5;
localparam P_CTL_TPG_FMT 	= 6;
localparam P_CTL_FIFO_RUN 	= 9;
localparam P_CTL_OVL_RUN 	= 10;
localparam P_CTL_CR_RUN 	= 11;
localparam P_CTL_WIDTH	 	= 12;

// Signals

// Reset
wire 							rst_from_lnk_rst;
wire 							rst_from_vid_rst;

// Control
wire [(P_CTL_IG_PORTS*32)-1:0]	ig_to_ctl_join;
wire [31:0]						ig_to_ctl[0:P_CTL_IG_PORTS-1];
wire [(P_CTL_OG_PORTS*32)-1:0]	og_from_ctl_join;
wire [31:0]						og_from_ctl[0:P_CTL_OG_PORTS-1];

wire [3:0]						vps_idx_from_ctl;
wire [15:0]						vps_dat_from_ctl;
wire 							vps_vld_from_ctl;

// CDC
wire [P_CTL_WIDTH-1:0]			ctl_from_cdc;

// Clock recovery
wire							sync_from_cr;
wire [7:0]						cur_err_from_cr;
wire [7:0]						max_err_from_cr;
wire [7:0]						min_err_from_cr;
wire [15:0]						sum_from_cr;
wire [28:0]						co_from_cr;

// Clock generator
wire 							run_to_cg;

// FIFO
wire							run_to_fifo;
wire							tg_run_from_fifo;
wire [(P_BPC * P_PPC)-1:0] 		vid_r_from_fifo;
wire [(P_BPC * P_PPC)-1:0] 		vid_g_from_fifo;
wire [(P_BPC * P_PPC)-1:0] 		vid_b_from_fifo;
wire 							vid_vs_from_fifo;
wire 							vid_hs_from_fifo;
wire							vid_de_from_fifo;
wire 							lock_from_fifo;
wire [9:0]						max_wrds_from_fifo;
wire [9:0]						min_wrds_from_fifo;

// Timing generator
wire 							run_to_tg;
wire 							mode_to_tg;
wire 							vid_rdy_to_tg;
wire 							vid_vs_from_tg;
wire 							vid_hs_from_tg;
wire 							vid_de_from_tg;
logic 							vclk_tg_run;

// Test pattern
wire 							run_to_tpg;
wire [2:0]						fmt_to_tpg;
wire [(P_BPC * P_PPC)-1:0] 		vid_r_from_tpg;
wire [(P_BPC * P_PPC)-1:0] 		vid_g_from_tpg;
wire [(P_BPC * P_PPC)-1:0] 		vid_b_from_tpg;
wire							vid_vs_from_tpg;
wire							vid_hs_from_tpg;
wire							vid_de_from_tpg;

// Frequency counters
wire [31:0]						freq_from_tx_lnk_clk_freq;
wire [31:0]						freq_from_rx_lnk_clk_freq;
wire [31:0]						freq_from_vid_ref_freq;
wire [31:0]						freq_from_vid_clk_freq;

// Monitor
wire [15:0]						pix_from_mon;
wire [15:0]						lin_from_mon;

// Overlay
wire 							run_to_ovl;
wire [(P_BPC * P_PPC)-1:0] 		vid_r_from_ovl;
wire [(P_BPC * P_PPC)-1:0] 		vid_g_from_ovl;
wire [(P_BPC * P_PPC)-1:0] 		vid_b_from_ovl;
wire							vid_vs_from_ovl;
wire							vid_hs_from_ovl;
wire							vid_de_from_ovl;

genvar i;

// Control 
	prt_vtb_ctl
	#(
		.P_VENDOR	(P_VENDOR),
		.P_IG_PORTS	(P_CTL_IG_PORTS),		// Ingress ports
		.P_OG_PORTS (P_CTL_OG_PORTS)		// Outgress ports
	)
	CTL_INST
	(
		// System
		.SYS_RST_IN				(SYS_RST_IN),				// Reset
		.SYS_CLK_IN				(SYS_CLK_IN),				// Clock

		// Video
		.VID_RST_IN				(rst_from_vid_rst),			// Reset
		.VID_CLK_IN				(VID_CLK_IN),				// Clock

		// Local bus
		.LB_IF					(LB_IF),

		// Ingress 
		.IG_IN					(ig_to_ctl_join),

		// Outgress
		.OG_OUT 				(og_from_ctl_join),

		// Video parameter set
		.VPS_IDX_OUT			(vps_idx_from_ctl),			// Index
		.VPS_DAT_OUT			(vps_dat_from_ctl),			// Data
		.VPS_VLD_OUT			(vps_vld_from_ctl)			// Valid
	);

generate
	for (i = 0; i < P_CTL_IG_PORTS; i++)
	begin : gen_ig
		assign ig_to_ctl_join[(i*32)+:32] = ig_to_ctl[i];
	end
endgenerate

	assign ig_to_ctl[0] = freq_from_tx_lnk_clk_freq;
	assign ig_to_ctl[1] = freq_from_rx_lnk_clk_freq;
	assign ig_to_ctl[2] = freq_from_vid_ref_freq;
	assign ig_to_ctl[3] = freq_from_vid_clk_freq;
	assign ig_to_ctl[4] = {8'h0, min_err_from_cr, max_err_from_cr, cur_err_from_cr};
	assign ig_to_ctl[5] = {16'h0, sum_from_cr};
	assign ig_to_ctl[6] = {3'h0, co_from_cr};

generate
	for (i = 0; i < P_CTL_OG_PORTS; i++)
	begin : gen_og
		assign og_from_ctl[i] = og_from_ctl_join[(i*32)+:32];
	end
endgenerate

// The first outgress are the control signals
// clock domain crossing
	prt_dp_lib_cdc_vec
	#(
		.P_WIDTH 		($size(ctl_from_cdc))
	)
	CTL_CDC_INST
	(
		.SRC_CLK_IN		(SYS_CLK_IN),								// Clock
		.SRC_DAT_IN		(og_from_ctl[0][2+:$size(ctl_from_cdc)]),	// Data
		.DST_CLK_IN		(VID_CLK_IN),								// Clock
		.DST_DAT_OUT	(ctl_from_cdc)								// Data
	);

	assign run_to_cg 	= ctl_from_cdc[P_CTL_CG_RUN-2];
	assign run_to_tg 	= ctl_from_cdc[P_CTL_TG_RUN-2];
	assign mode_to_tg 	= ctl_from_cdc[P_CTL_TG_MODE-2];
	assign run_to_tpg 	= ctl_from_cdc[P_CTL_TPG_RUN-2];
	assign fmt_to_tpg 	= ctl_from_cdc[P_CTL_TPG_FMT-2+:$size(fmt_to_tpg)];
	assign run_to_fifo 	= ctl_from_cdc[P_CTL_FIFO_RUN-2];
	assign run_to_ovl 	= ctl_from_cdc[P_CTL_OVL_RUN-2];

// FIFO words clock domain crossing
	prt_dp_lib_cdc_vec
	#(
		.P_WIDTH 		(32)
	)
	FIFO_CDC_INST
	(
		.SRC_CLK_IN		(VID_CLK_IN),															// Clock
		.SRC_DAT_IN		({11'h0, lock_from_fifo, min_wrds_from_fifo, max_wrds_from_fifo}),		// Data
		.DST_CLK_IN		(SYS_CLK_IN),															// Clock
		.DST_DAT_OUT	(ig_to_ctl[7])															// Data
	);

// Monitor pixel and lines clock domain crossing
	prt_dp_lib_cdc_vec
	#(
		.P_WIDTH 		(32)
	)
	MON_CDC_INST
	(
		.SRC_CLK_IN		(VID_CLK_IN),						// Clock
		.SRC_DAT_IN		({lin_from_mon, pix_from_mon}),		// Data
		.DST_CLK_IN		(SYS_CLK_IN),						// Clock
		.DST_DAT_OUT	(ig_to_ctl[8])						// Data
	);

// Link reset
    prt_dp_lib_rst
    LNK_RST_INST
    (
        .SRC_RST_IN  	(~og_from_ctl[0][P_CTL_LNK_EN]),
        .SRC_CLK_IN		(SYS_CLK_IN),
        .DST_CLK_IN     (RX_LNK_CLK_IN),
        .DST_RST_OUT    (rst_from_lnk_rst)
    );

// Video reset
    prt_dp_lib_rst
    VID_RST_INST
    (
        .SRC_RST_IN     (~og_from_ctl[0][P_CTL_VID_EN]),
        .SRC_CLK_IN		(SYS_CLK_IN),
        .DST_CLK_IN     (VID_CLK_IN),
        .DST_RST_OUT    (rst_from_vid_rst)
    );

// Clock recovery
	prt_vtb_cr
	#(
		.P_SIM				(P_SIM),						// Simulation
		.P_PPC 				(P_PPC)							// Pixels per clock
	)
	CR_INST
	(
		// Reset and clock
		.SYS_RST_IN			(SYS_RST_IN),					// System Reset
		.SYS_CLK_IN			(SYS_CLK_IN),					// System Clock
		.LNK_CLK_IN			(RX_LNK_CLK_IN),				// Link Clock
		.VID_CLK_IN			(VID_CLK_IN),					// Video Clock
		.VID_CKE_IN			(VID_CKE_IN),					// Video Clock enable

		// Control
	 	.CTL_RUN_IN			(og_from_ctl[0][P_CTL_CR_RUN]),	// Run
	 	.CTL_P_GAIN_IN		(og_from_ctl[1][0+:8]),			// P gain
	 	.CTL_I_GAIN_IN		(og_from_ctl[1][8+:16]),		// I gain

	 	// Status
	 	.STA_CUR_ERR_OUT 	(cur_err_from_cr),				// Current error
	 	.STA_MAX_ERR_OUT 	(max_err_from_cr),				// Maximum error
	 	.STA_MIN_ERR_OUT 	(min_err_from_cr),				// Minimum error
	 	.STA_SUM_OUT 		(sum_from_cr),					// Sum
	 	.STA_CO_OUT 		(co_from_cr),					// Controller output

		// Video parameter set
		.VPS_IDX_IN			(vps_idx_from_ctl),				// Index
		.VPS_DAT_IN			(vps_dat_from_ctl),				// Data
		.VPS_VLD_IN			(vps_vld_from_ctl),				// Valid

		// Link
		.LNK_SYNC_IN		(LNK_SYNC_IN),

		// Direct I2C Access
		.DIA_RDY_IN			(DIA_RDY_IN),
		.DIA_DAT_OUT		(DIA_DAT_OUT),
		.DIA_VLD_OUT		(DIA_VLD_OUT),

		// Debug
		.DBG_SYNC_END_OUT	(),								// Sync end out
		.DBG_PIX_END_OUT	()								// Pixel end out
	);

// Clock generator
/*
	prt_vtb_cg
	CG_INST
	(
		// Reset and clock
		.RST_IN				(rst_from_vid_rst),			// Reset
		.CLK_IN				(VID_CLK_IN),				// Clock
		.CKE_IN				(cke_from_cg),				// Clock enable

		// Control
		.CTL_RUN_IN			(run_to_cg),				// Run

		// Video parameter set
		.VPS_IDX_IN			(vps_idx_from_ctl),			// Index
		.VPS_DAT_IN			(vps_dat_from_ctl),			// Data
		.VPS_VLD_IN			(vps_vld_from_ctl),			// Valid
	
		// Clock enable
		.CKE_OUT			(cke_from_cg)
	);
*/

// FIFO
	prt_vtb_fifo
	#(
		.P_VENDOR			(P_VENDOR),					// Vendor
		.P_PPC 				(P_PPC),					// Pixels per clock
		.P_BPC 				(P_BPC),					// Bits per component
	    .P_AXIS_DAT			(P_AXIS_DAT)				// AXIS data width
	)
	FIFO_INST
	(
		// Reset and clocks
		.VID_RST_IN			(rst_from_vid_rst),			// Reset
		.VID_CLK_IN			(VID_CLK_IN),				// Clock
		.VID_CKE_IN			(VID_CKE_IN),				// Clock enable

		// Control
		.CTL_RUN_IN			(run_to_fifo),				// Run

		// Status
		.STA_LOCK_OUT		(lock_from_fifo),			// Lock
		.STA_MAX_WRDS_OUT	(max_wrds_from_fifo),		// Maximum words
		.STA_MIN_WRDS_OUT	(min_wrds_from_fifo),		// Minimum words

		// Timing
		.TG_RUN_OUT			(tg_run_from_fifo),

		// Video in
		.AXIS_SOF_IN		(AXIS_SOF_IN),				// Start of frame
		.AXIS_EOL_IN		(AXIS_EOL_IN),				// End of line
		.AXIS_DAT_IN		(AXIS_DAT_IN),				// Data
		.AXIS_VLD_IN		(AXIS_VLD_IN),				// Valid

		// Video out
		.VID_VS_IN			(vid_vs_from_tg),			// Vsync in
		.VID_HS_IN			(vid_hs_from_tg),			// Hsync in
		.VID_DE_IN			(vid_de_from_tg),			// Data enable in
		.VID_R_OUT			(vid_r_from_fifo),			// Red
		.VID_G_OUT			(vid_g_from_fifo),			// Green
		.VID_B_OUT			(vid_b_from_fifo),			// Blue
		.VID_VS_OUT			(vid_vs_from_fifo),			// Vsync out
		.VID_HS_OUT			(vid_hs_from_fifo),			// Hsync out
		.VID_DE_OUT			(vid_de_from_fifo)			// Data enable out
	);

// Timing generator
	prt_vtb_tg
	#(
		.P_PPC 				(P_PPC)					// Pixels per clock
	)
	TG_INST
	(
		// Reset and clock
		.RST_IN				(rst_from_vid_rst),		// Reset
		.CLK_IN				(VID_CLK_IN),			// Clock
		.CKE_IN				(VID_CKE_IN),			// Clock enable

		// Control
		.CTL_RUN_IN			(vclk_tg_run),			// Run
		.CTL_MODE_IN		(mode_to_tg),			// Mode; 0-free running / 1-sync

		// Video parameter set
		.VPS_IDX_IN			(vps_idx_from_ctl),		// Index
		.VPS_DAT_IN			(vps_dat_from_ctl),		// Data
		.VPS_VLD_IN			(vps_vld_from_ctl),		// Valid

		// Native video
		.VID_VS_OUT			(vid_vs_from_tg),		// Vsync
		.VID_HS_OUT			(vid_hs_from_tg),		// Hsync
		.VID_DE_OUT			(vid_de_from_tg)		// Data enable
	);

// Timing generator run
	always_ff @ (posedge rst_from_vid_rst, posedge VID_CLK_IN)
	begin
		// Reset
		if (rst_from_vid_rst)
			vclk_tg_run <= 0;

		else
		begin
			// Sync mode
			if (mode_to_tg)
				vclk_tg_run <= tg_run_from_fifo && run_to_tg;

			// Free running
			else
				vclk_tg_run <= run_to_tg;
		end
	end 

// Test Pattern Generator
	prt_vtb_tpg
	#(
		.P_PPC 				(P_PPC),				// Pixels per clock
		.P_BPC 				(P_BPC)					// Bits per component
	)
	TPG_INST
	(
		// Reset and clock
		.RST_IN				(rst_from_vid_rst),		// Reset
		.CLK_IN				(VID_CLK_IN),			// Clock
		.CKE_IN				(VID_CKE_IN),			// Clock enable

		// Control
		.CTL_RUN_IN			(run_to_tpg),			// Run
		.CTL_FMT_IN			(fmt_to_tpg), 			// Format. 0 - full, 1 - red, 2 - green, 3 - blue, 4 - ramp

		// Video parameter set
		.VPS_IDX_IN			(vps_idx_from_ctl),		// Index
		.VPS_DAT_IN			(vps_dat_from_ctl),		// Data
		.VPS_VLD_IN			(vps_vld_from_ctl),		// Valid

		// Native video
		.VID_VS_IN			(vid_vs_from_tg),		// Vsync
		.VID_HS_IN			(vid_hs_from_tg),		// Hsync
		.VID_DE_IN			(vid_de_from_tg),		// Data enable in
		.VID_R_OUT			(vid_r_from_tpg),		// Red
		.VID_G_OUT			(vid_g_from_tpg),		// Green
		.VID_B_OUT			(vid_b_from_tpg),		// Blue
		.VID_VS_OUT			(vid_vs_from_tpg),		// Vsync
		.VID_HS_OUT			(vid_hs_from_tpg),		// Hsync
		.VID_DE_OUT			(vid_de_from_tpg)		// Data enable out
	);

// TX Link clock frequency counter 
	prt_vtb_freq
	#(
		.P_SYS_FREQ 		(P_SYS_FREQ)
	)
	TX_LNK_CLK_FREQ_INST
	(
		// System
		.SYS_RST_IN			(SYS_RST_IN),			// Reset
		.SYS_CLK_IN			(SYS_CLK_IN),			// Clock

		// Monitored clock
		.MON_CLK_IN			(TX_LNK_CLK_IN),		// Clock
		.MON_CKE_IN			(1'b1),					// Clock enable

		// Frequency
		.FREQ_OUT			(freq_from_tx_lnk_clk_freq)
	);

// RX Link clock frequency counter 
	prt_vtb_freq
	#(
		.P_SYS_FREQ 		(P_SYS_FREQ)
	)
	RX_LNK_CLK_FREQ_INST
	(
		// System
		.SYS_RST_IN			(SYS_RST_IN),			// Reset
		.SYS_CLK_IN			(SYS_CLK_IN),			// Clock

		// Monitored clock
		.MON_CLK_IN			(RX_LNK_CLK_IN),		// Clock
		.MON_CKE_IN			(1'b1),					// Clock enable

		// Frequency
		.FREQ_OUT			(freq_from_rx_lnk_clk_freq)
	);

// Video reference clock frequency counter 
	prt_vtb_freq
	#(
		.P_SYS_FREQ 		(P_SYS_FREQ)
	)
	VID_REF_FREQ_INST
	(
		// System
		.SYS_RST_IN			(SYS_RST_IN),			// Reset
		.SYS_CLK_IN			(SYS_CLK_IN),			// Clock

		// Monitored clock
		.MON_CLK_IN			(VID_CLK_IN),			// Clock
		.MON_CKE_IN			(1'b1),					// Clock enable

		// Frequency
		.FREQ_OUT			(freq_from_vid_ref_freq)
	);

// Video clock frequency counter 
	prt_vtb_freq
	#(
		.P_SYS_FREQ 		(P_SYS_FREQ)
	)
	VID_CLK_FREQ_INST
	(
		// System
		.SYS_RST_IN			(SYS_RST_IN),			// Reset
		.SYS_CLK_IN			(SYS_CLK_IN),			// Clock

		// Monitored clock
		.MON_CLK_IN			(VID_CLK_IN),			// Clock
		.MON_CKE_IN			(VID_CKE_IN),			// Clock enable

		// Frequency
		.FREQ_OUT			(freq_from_vid_clk_freq)
	);

// Monitor
	prt_vtb_mon
	MON_INST
	(
		// Reset and clock
		.RST_IN			(rst_from_vid_rst),		// Reset
		.CLK_IN			(VID_CLK_IN),			// Clock

		// Video in
		.VID_SOF_IN		(AXIS_SOF_IN),        	// Start of frame
		.VID_EOL_IN		(AXIS_EOL_IN),        	// End of line
		.VID_VLD_IN		(AXIS_VLD_IN),        	// Valid

		// Status
		.STA_PIX_OUT	(pix_from_mon),
		.STA_LIN_OUT	(lin_from_mon)
	);

// Overlay
generate
	if (P_OVL)
	begin : gen_ovl
		prt_vtb_ovl
		#(
			.P_IMG 				(P_OVL),				// Image
			.P_PPC 				(P_PPC),				// Pixels per clock
			.P_BPC 				(P_BPC)					// Bits per component
		)
		OVL_INST
		(
			// Clock
			.CLK_IN				(VID_CLK_IN),			// Clock
			
			// Control
			.CTL_RUN_IN			(run_to_ovl),			// Run

			// Video in
			.VID_R_IN			(vid_r_from_tpg),		// Red
			.VID_G_IN			(vid_g_from_tpg),		// Green
			.VID_B_IN			(vid_b_from_tpg),		// Blue
			.VID_VS_IN			(vid_vs_from_tpg),		// Vsync
			.VID_HS_IN			(vid_hs_from_tpg),		// Hsync
			.VID_DE_IN			(vid_de_from_tpg),		// Data enable out

			// Video out
			.VID_R_OUT			(vid_r_from_ovl),		// Red
			.VID_G_OUT			(vid_g_from_ovl),		// Green
			.VID_B_OUT			(vid_b_from_ovl),		// Blue
			.VID_VS_OUT			(vid_vs_from_ovl),		// Vsync
			.VID_HS_OUT			(vid_hs_from_ovl),		// Hsync
			.VID_DE_OUT			(vid_de_from_ovl)		// Data enable out
		);
	end

	else
	begin : no_ovl	
		assign vid_vs_from_ovl 	= vid_vs_from_tpg;
		assign vid_hs_from_ovl 	= vid_hs_from_tpg;
		assign vid_de_from_ovl 	= vid_de_from_tpg;
		assign vid_r_from_ovl 	= vid_r_from_tpg;
		assign vid_g_from_ovl 	= vid_g_from_tpg;
		assign vid_b_from_ovl 	= vid_b_from_tpg;
	end

endgenerate

// Outputs
	assign VID_LOCK_OUT = (run_to_tpg) ? 1'b1 : lock_from_fifo;
	assign VID_VS_OUT   = (run_to_tpg) ? vid_vs_from_ovl : vid_vs_from_fifo;
	assign VID_HS_OUT   = (run_to_tpg) ? vid_hs_from_ovl : vid_hs_from_fifo;
	assign VID_R_OUT 	= (run_to_tpg) ? vid_r_from_ovl  : vid_r_from_fifo;
	assign VID_G_OUT 	= (run_to_tpg) ? vid_g_from_ovl  : vid_g_from_fifo;
	assign VID_B_OUT 	= (run_to_tpg) ? vid_b_from_ovl  : vid_b_from_fifo;
	assign VID_DE_OUT 	= (run_to_tpg) ? vid_de_from_ovl : vid_de_from_fifo;

endmodule

`default_nettype wire
