/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Scaler Top
    (c) 2022 by Parretto B.V.

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
	parameter 						P_VENDOR = "none",  // Vendor "xilinx" or "lattice"

	// Video
     parameter 						P_PPC = 4,          // Pixels per clock
     parameter 						P_BPC = 8           // Bits per component
)
(
     // System
     input wire                              SYS_RST_IN,
     input wire                              SYS_CLK_IN,

	// Local bus interface
	prt_dp_lb_if.lb_in   				LB_IF,

	// Video
     input wire                              VID_CLK_IN,

     // Video in
     input wire						VID_CKE_IN,	 // Clock enable
     input wire						VID_VS_IN,      // Vertical sync
	input wire                              VID_HS_IN,      // Horizontal sync    
     input wire     [(P_PPC * P_BPC)-1:0]    VID_R_IN,       // Red
     input wire     [(P_PPC * P_BPC)-1:0]    VID_G_IN,       // Green
     input wire     [(P_PPC * P_BPC)-1:0]    VID_B_IN,       // Blue
     input wire                              VID_DE_IN,      // Data enable

     // Video out
	output wire 						VID_CKE_OUT,	 // Clock enable
	output wire                             VID_VS_OUT,     // Vertical sync    
	output wire                             VID_HS_OUT,     // Horizontal sync    
	output wire     [(P_PPC * P_BPC)-1:0]  	VID_R_OUT,      // Red
	output wire     [(P_PPC * P_BPC)-1:0]   VID_G_OUT,      // Green
     output wire     [(P_PPC * P_BPC)-1:0]   VID_B_OUT,      // Blue
     output wire                             VID_DE_OUT      // Data enable
);

// Parameters

// Signals

// Clock enable generator
logic [3:0]				vclk_cke_cnt;
logic					vclk_cke;

// Input registers
logic					vclk_vs_in;
logic					vclk_hs_in;
logic [(P_PPC * P_BPC)-1:0]  	vclk_r_in;
logic [(P_PPC * P_BPC)-1:0]  	vclk_g_in;
logic [(P_PPC * P_BPC)-1:0]  	vclk_b_in;
logic					vclk_de_in;
wire						vclk_vs_re;

// Controller
wire						run_from_ctl;
wire	[3:0]				mode_from_ctl;
wire	[3:0]				cr_from_ctl;
wire [3:0]				vps_idx_from_ctl;
wire [15:0]				vps_dat_from_ctl;
wire 					vps_vld_from_ctl;

// Timing generator
wire						vs_int_from_tg;
wire						vs_ext_from_tg;
wire						hs_from_tg;
wire						de_from_tg;

logic [15:0]				clk_ver_len;
logic [15:0]				clk_hor_len;

// Line
wire [(P_PPC * P_BPC)-1:0]	dat_to_line[0:2];
wire [2:0]				rdy_from_line;
wire [(P_PPC * P_BPC)-1:0]	dat_from_line[0:2];
wire [3:0]				vld_from_line[0:2];

// Vertical 
wire [2:0]				rdy_from_ver;
wire [3:0]				rd_from_ver[0:2];
wire [(P_PPC * P_BPC)-1:0]	dat_from_ver[0:2];
wire [3:0]				vld_from_ver[0:2];

// Horizontal
wire [2:0]				rdy_from_hor;
wire [3:0]				rd_from_hor[0:2];
wire [(P_PPC * P_BPC)-1:0]	dat_from_hor[0:2];
wire [2:0]				vld_from_hor;

genvar i;

// Input registers
	always_ff @ (posedge VID_CLK_IN)
	begin
		// Clock enable
		if (VID_CKE_IN)
		begin
			vclk_vs_in <= VID_VS_IN;
			vclk_hs_in <= VID_HS_IN;
			vclk_r_in <= VID_R_IN;
			vclk_g_in <= VID_G_IN;
			vclk_b_in <= VID_B_IN;
			vclk_de_in <= VID_DE_IN;
		end
	end

// Vsync edge detector
     prt_scaler_lib_edge
     VCLK_VS_EDGE_INST
     (
          .CLK_IN   (VID_CLK_IN),       // Clock
          .CKE_IN   (1'b1),          	// Clock enable
          .A_IN     (vclk_vs_in),       // Input
          .RE_OUT   (vclk_vs_re), 		// Rising edge
          .FE_OUT   ()               	// Falling edge
     );

// Control 
	prt_scaler_ctl
	#(
		.P_VENDOR				(P_VENDOR)
	)
	CTL_INST
	(
		// System
		.SYS_RST_IN			(SYS_RST_IN),				// Reset
		.SYS_CLK_IN			(SYS_CLK_IN),				// Clock

		// Video
		.VID_CLK_IN			(VID_CLK_IN),				// Clock

		// Local bus
		.LB_IF				(LB_IF),

		// Control
		.CTL_RUN_OUT			(run_from_ctl),			// Run
		.CTL_MODE_OUT			(mode_from_ctl),			// Mode
		.CTL_CR_OUT			(cr_from_ctl),				// Clock ratio

		// Video parameter set
		.VPS_IDX_OUT			(vps_idx_from_ctl),			// Index
		.VPS_DAT_OUT			(vps_dat_from_ctl),			// Data
		.VPS_VLD_OUT			(vps_vld_from_ctl)			// Valid
	);

// Timing generator
	prt_scaler_tg
	#(
	    .P_PPC 				(P_PPC)         		// Pixels per clock
	)
	TG_INST
	(
		// Reset and clock
		.CLK_IN				(VID_CLK_IN),			// Clock
		.CKE_IN				(1'b1),				// Clock enable

		// Control
		.CTL_RUN_IN			(run_from_ctl),		// Run

		// Video parameter set
		.VPS_IDX_IN			(vps_idx_from_ctl),		// Index
		.VPS_DAT_IN			(vps_dat_from_ctl),		// Data
		.VPS_VLD_IN			(vps_vld_from_ctl),		// Valid

		// Video in
		.VID_VS_IN			(vclk_vs_in),			// Vsync

		// Video in
		.VID_VS_INT_OUT		(vs_int_from_tg),		// Vsync (internal)
		.VID_VS_EXT_OUT		(vs_ext_from_tg),		// Vsync (external)
		.VID_HS_OUT			(hs_from_tg),			// Hsync
		.VID_DE_OUT			(de_from_tg)			// Data enable
	);

// Map line input
	assign dat_to_line[0] = vclk_r_in;
	assign dat_to_line[1] = vclk_g_in;
	assign dat_to_line[2] = vclk_b_in;

// Vertical length
     always_ff @ (posedge VID_CLK_IN)
     begin
          // Video parameter Hwidth
          if ((vps_idx_from_ctl == 'd8) && vps_vld_from_ctl)
               clk_ver_len <= vps_dat_from_ctl[0+:$size(clk_ver_len)]; 
     end

// Horizontal length
     always_ff @ (posedge VID_CLK_IN)
     begin
          // Video parameter Hwidth
          if ((vps_idx_from_ctl == 'd9) && vps_vld_from_ctl)
               clk_hor_len <= vps_dat_from_ctl[0+:$size(clk_hor_len)]; 
     end

// Line buffer
generate
	for (i = 0; i < 3; i++)
	begin : gen_line
		prt_scaler_line
		#(
		    .P_VENDOR			(P_VENDOR),
		    .P_PPC 			(P_PPC),          	// Pixels per clock
		    .P_BPC 			(P_BPC)           	// Bits per component
		)
		LINE_INST
		(
			// Reset and clock
		    	.CLK_IN			(VID_CLK_IN),
		    	.CLR_IN			(vclk_vs_re),
		    	.CKE_IN			(VID_CKE_IN),

			// Control
			.CTL_RUN_IN		(run_from_ctl),		// Run
	    
			// Video
			.VID_HS_IN		(vclk_hs_in),
			.VID_DE_IN		(vclk_de_in),
			.VID_DAT_IN		(dat_to_line[i]),

		    	// Source
		    	.SRC_RDY_OUT		(rdy_from_line[i]),		// Ready
		    	.SRC_RD_IN		(rd_from_ver[i]),		// Read
		    	.SRC_DAT_OUT		(dat_from_line[i]),    	// Data
		    	.SRC_VLD_OUT   	(vld_from_line[i])		// Valid
		);
	end
endgenerate

// Vertical scaler unit
generate
	for (i = 0; i < 3; i++)
	begin : gen_ver
		prt_scaler_ver
		#(
		    .P_VENDOR			(P_VENDOR),
		    .P_PPC 			(P_PPC),          	// Pixels per clock
		    .P_BPC 			(P_BPC)           	// Bits per component
		)
		VER_INST
		(
			// Reset and clock
		    	.CLK_IN			(VID_CLK_IN),
		    	.CLR_IN			(vclk_vs_re),

			// Control
			.CTL_RUN_IN		(run_from_ctl),		// Run
			.CTL_MODE_IN		(mode_from_ctl),		// Mode
	    		.CTL_LEN_IN		(clk_ver_len),			// Line length
		    	
		    	// Sink
		    	.SNK_RDY_IN		(rdy_from_line[i]),		// Ready
		    	.SNK_RD_OUT		(rd_from_ver[i]),		// Read
		    	.SNK_DAT_IN		(dat_from_line[i]),    	// Data
		    	.SNK_VLD_IN		(vld_from_line[i]),     	// Valid

		    	// Source
		    	.SRC_RDY_OUT		(rdy_from_ver[i]),		// Ready
		    	.SRC_RD_IN		(rd_from_hor[i]),		// Read
		    	.SRC_DAT_OUT		(dat_from_ver[i]),    	// Data
		    	.SRC_VLD_OUT   	(vld_from_ver[i])		// Valid
		);
	end
endgenerate

// Horizontal scaler 
generate
	for (i = 0; i < 3; i++)
	begin : gen_hor
		prt_scaler_hor
		#(
		    .P_VENDOR			(P_VENDOR),
		    .P_PPC 			(P_PPC),          	// Pixels per clock
		    .P_BPC 			(P_BPC)           	// Bits per component
		)
		HOR_INST
		(
			// Reset and clock
		    	.CLK_IN			(VID_CLK_IN),
		    	.CLR_IN			(vclk_vs_re),

			// Control
			.CTL_RUN_IN		(run_from_ctl),		// Run
			.CTL_MODE_IN		(mode_from_ctl),		// Mode
    	    		.CTL_LEN_IN		(clk_hor_len),			// Line length

		    	// Sink
		    	.SNK_RDY_IN		(rdy_from_ver[i]),		// Ready
		    	.SNK_RD_OUT		(rd_from_hor[i]),		// Read
		    	.SNK_DAT_IN		(dat_from_ver[i]),    	// Data
		    	.SNK_VLD_IN		(vld_from_ver[i]),     	// Write

		    	// Source
		    	.SRC_RDY_OUT		(rdy_from_hor[i]),		// Ready
		    	.SRC_RD_IN		(de_from_tg),			// Read
		    	.SRC_DAT_OUT		(dat_from_hor[i]),    	// Data
		    	.SRC_VLD_OUT   	(vld_from_hor[i])		// Valid
		);
	end
endgenerate

// Clock enable generator
	always_ff @ (posedge VID_CLK_IN)
	begin
		// Run
		if (run_from_ctl)
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
	assign VID_VS_OUT = (run_from_ctl) ? vs_ext_from_tg : vclk_vs_in;
	assign VID_HS_OUT = (run_from_ctl) ? hs_from_tg : vclk_hs_in;
	assign VID_R_OUT = (run_from_ctl) ? dat_from_hor[0] : vclk_r_in;
	assign VID_G_OUT = (run_from_ctl) ? dat_from_hor[1] : vclk_g_in;
	assign VID_B_OUT = (run_from_ctl) ? dat_from_hor[2] : vclk_b_in;
	assign VID_DE_OUT = (run_from_ctl) ? vld_from_hor[0] : vclk_de_in;

endmodule

`default_nettype wire
