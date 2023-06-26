/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Full array local dimming Top
    (c) 2023 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
*/

`default_nettype none

module prt_fald_top
#(
    // System
    parameter               			P_VENDOR = "none",  // Vendor "xilinx" or "lattice"
	parameter 							P_PPC = 4,			// Pixels per clock
	parameter 							P_BPC = 8			// Bits per component
)
(
    // Reset and clock
    input wire              			SYS_RST_IN,     // Reset
    input wire              			SYS_CLK_IN,     // Clock

	// Local bus interface
	prt_dp_lb_if.lb_in   				LB_IF,

    // Video
    input wire              			VID_CLK_IN,     // Clock
    input wire              			VID_VS_IN,      // Vsync
    input wire              			VID_HS_IN,      // Hsync
	input wire [(P_PPC*P_BPC)-1:0] 		VID_R_IN,		// Red
	input wire [(P_PPC*P_BPC)-1:0] 		VID_G_IN,		// Green
	input wire [(P_PPC*P_BPC)-1:0] 		VID_B_IN,		// Blue
	input wire  						VID_DE_IN,		// Data enable

    // LED
    output wire             			LED_CLK_OUT,   // Clock
    output wire             			LED_DAT_OUT    // Data
);

// Localparameters
// Simulation
localparam P_SIM =
// synthesis translate_off
(1) ? 1 :
// synthesis translate_on
0;
localparam P_CTL_IG_PORTS = 0;	// Controller ingress ports 
localparam P_CTL_OG_PORTS = 5;	// Controller outgress ports

localparam P_CTL_RUN 		= 0;
localparam P_CTL_LPB_CLR 	= 1;

// Signals

// Control
wire [(P_CTL_IG_PORTS*32)-1:0]	ig_to_ctl_join;
wire [31:0]						ig_to_ctl[0:P_CTL_IG_PORTS-1];
wire [(P_CTL_OG_PORTS*32)-1:0]	og_from_ctl_join;
wire [31:0]						og_from_ctl[0:P_CTL_OG_PORTS-1];

wire 							run_from_ctl;
wire 							lpb_clr_from_ctl;
wire [3:0]						lpb_dat_from_ctl;
wire 							lpb_vld_from_ctl;

// CSC
wire [P_BPC-1:0]				y_from_csc;
wire  							de_from_csc;

// Dimming
wire 							dds_init_from_dim;
wire [15:0] 					dds_dat_from_dim;
wire 							dds_vld_from_dim;

// Driver
wire 							led_clk_from_drv;
wire 							led_dat_from_drv;

genvar i;

// Control 
	prt_fald_ctl
	#(
		.P_VENDOR	(P_VENDOR),
		.P_IG_PORTS	(P_CTL_IG_PORTS),		// Ingress ports
		.P_OG_PORTS (P_CTL_OG_PORTS)		// Outgress ports
	)
	CTL_INST
	(
		// System
		.RST_IN					(SYS_RST_IN),				// Reset
		.CLK_IN					(SYS_CLK_IN),				// Clock

		// Local bus
		.LB_IF					(LB_IF),

		// Ingress 
		.IG_IN					(ig_to_ctl_join),

		// Outgress
		.OG_OUT 				(og_from_ctl_join),

		// Led pixel buffer
		.LPB_DAT_OUT			(lpb_dat_from_ctl),			// Data
		.LPB_VLD_OUT			(lpb_vld_from_ctl)			// Valid
	);

generate
	for (i = 0; i < P_CTL_IG_PORTS; i++)
	begin : gen_ig
		assign ig_to_ctl_join[(i*32)+:32] = ig_to_ctl[i];
	end
endgenerate

/*
	assign ig_to_ctl[0] = freq_from_tx_lnk_clk_freq;
	assign ig_to_ctl[1] = freq_from_rx_lnk_clk_freq;
	assign ig_to_ctl[2] = freq_from_vid_ref_freq;
	assign ig_to_ctl[3] = freq_from_vid_clk_freq;
	assign ig_to_ctl[4] = {8'h0, min_err_from_cr, max_err_from_cr, cur_err_from_cr};
	assign ig_to_ctl[5] = {16'h0, sum_from_cr};
	assign ig_to_ctl[6] = {3'h0, co_from_cr};
*/

generate
	for (i = 0; i < P_CTL_OG_PORTS; i++)
	begin : gen_og
		assign og_from_ctl[i] = og_from_ctl_join[(i*32)+:32];
	end
endgenerate

	assign run_from_ctl 	= og_from_ctl[0][P_CTL_RUN];
	assign lpb_clr_from_ctl = og_from_ctl[0][P_CTL_LPB_CLR];

// Color space converter
	prt_fald_csc
	#(
		.P_BPC 		(P_BPC)
	)
	CSC_INST
	(
		// Clock
		.CLK_IN		(VID_CLK_IN),     // Clock

		// Video in
		.R_IN		(VID_R_IN[0+:P_BPC]),
		.G_IN		(VID_G_IN[0+:P_BPC]),
		.B_IN		(VID_B_IN[0+:P_BPC]),
		.DE_IN		(VID_DE_IN),

		// Video out
		.Y_OUT		(y_from_csc),
		.DE_OUT  	(de_from_csc) 
	);

// Dimming
	prt_fald_dim
	#(
        .P_VENDOR           (P_VENDOR),  				// Vendor "xilinx" or "lattice"
		.P_BPC				(P_BPC)               		// Bits per component
	)
	DIM_INST
	(
        // Reset and clock
        .SYS_RST_IN         (SYS_RST_IN),         		// Reset
        .SYS_CLK_IN         (SYS_CLK_IN),         		// Clock

        // Control
    	.CTL_RUN_IN			(run_from_ctl),				// Run
		.CTL_GAIN_IN		(og_from_ctl[3][0+:8]),     // Gain
		.CTL_BIAS_IN		(og_from_ctl[3][8+:8]),     // Bias
		.CTL_BLK_W_IN		(og_from_ctl[4][0+:8]),     // Block width
		.CTL_BLK_H_IN		(og_from_ctl[4][8+:8]),     // Block height
		.CTL_ZONE_W_IN		(og_from_ctl[2][16+:8]),    // Zone width
		.CTL_ZONE_H_IN		(og_from_ctl[2][24+:8]),    // Zone height

		// Video in
		.VID_CLK_IN			(VID_CLK_IN),             	// Clock
		.VID_VS_IN			(VID_VS_IN),              	// Vsync
		.VID_HS_IN			(VID_HS_IN),              	// Hsync
		.VID_Y_IN			(y_from_csc),		        // Luma
		.VID_DE_IN			(de_from_csc),              // Data enable

		// Dimming data stream
		.DDS_INIT_OUT 		(dds_init_from_dim),		// Init
		.DDS_DAT_OUT 		(dds_dat_from_dim),			// Data
		.DDS_VLD_OUT 		(dds_vld_from_dim)			// Valid
	);

// Driver
    prt_fald_drv
    #(
        // System
        .P_VENDOR           (P_VENDOR),  	// Vendor "xilinx" or "lattice"
        .P_SIM              (P_SIM)      	// Simulation
    )
    DRV_INST
    (
        // Reset and clock
        .SYS_RST_IN         (SYS_RST_IN),         		// Reset
        .SYS_CLK_IN         (SYS_CLK_IN),         		// Clock

        // Control
    	.CTL_RUN_IN			(run_from_ctl),				// Run
		.CTL_INIT_IN		(og_from_ctl[1][0+:16]),  	// Init period (vclk cycles)
    	.CTL_PERIOD_IN		(og_from_ctl[1][16+:16]), 	// Period (vclk cycles)
    	.CTL_ZONES_IN		(og_from_ctl[2][0+:16]),	// Zones

        // Video
        .VID_CLK_IN         (VID_CLK_IN),      			// Vsync
        .VID_VS_IN          (VID_VS_IN),      			// Vsync

	    // LED pixel buffer
   		.LPB_CLR_IN			(lpb_clr_from_ctl),			// Clear
		.LPB_DAT_IN			(lpb_dat_from_ctl),			// Data
		.LPB_VLD_IN			(lpb_vld_from_ctl),			// Valid

	    // Dimming data stream
   		.DDS_INIT_IN		(dds_init_from_dim),	    // Init
		.DDS_DAT_IN			(dds_dat_from_dim),		    // Data
		.DDS_VLD_IN			(dds_vld_from_dim),			// Valid

        // LED
        .LED_CLK_OUT        (led_clk_from_drv),  		// Clock
        .LED_DAT_OUT        (led_dat_from_drv)   		// Data
    );

// Outputs
    assign LED_CLK_OUT = led_clk_from_drv;
    assign LED_DAT_OUT = led_dat_from_drv;

endmodule

`default_nettype wire
