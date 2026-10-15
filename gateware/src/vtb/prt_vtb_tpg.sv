/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Video Toolbox Test Pattern Generator
    (c) 2021 - 2025 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
	v1.1 - Added control format 
	v1.2 - Added 10-bits video support
	v1.3 - Added YCbCr 4:4:4

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
module prt_vtb_tpg
#(
	parameter P_PPC = 2,		// Pixels per clock
	parameter P_BPC = 8			// Bits per component
)
(
	// Reset and clock
	input wire 								RST_IN,			// Reset
	input wire 								CLK_IN,			// Clock
	input wire 								CKE_IN,			// Clock enable

	// Control
	input wire 								CTL_RUN_IN,		// Run
	input wire [2:0]						CTL_FMT_IN,		// Format. 0 - full, 1 - red, 2 - green, 3 - blue, 4 - ramp
	input wire 								CTL_CSF_IN,		// Color space. 0 - RGB, 1 - YCbCr 4:4:4

	// Video parameter set
	input wire [3:0]						VPS_IDX_IN,		// Index
	input wire [15:0]						VPS_DAT_IN,		// Data
	input wire 								VPS_VLD_IN,		// Valid	

	// Native video
	input wire 								VID_VS_IN,		// Vsync
	input wire 								VID_HS_IN,		// Hsync
	input wire 								VID_DE_IN,		// Data enable in
	output wire [(P_BPC * P_PPC)-1:0]		VID_R_OUT,		// Red
	output wire [(P_BPC * P_PPC)-1:0]		VID_G_OUT,		// Green
	output wire [(P_BPC * P_PPC)-1:0]		VID_B_OUT,		// Blue
	output wire 							VID_VS_OUT,		// Vsync
	output wire 							VID_HS_OUT,		// Hsync
	output wire 							VID_DE_OUT		// Data enable out
);

// Parameters
localparam P_HI_VAL = 'h3ff; //(P_BPC == 10) ? 'd720 : 'd180;
localparam P_LO_VAL = 'd0; //(P_BPC == 10) ? 'd64 : 'd16;

// YCbCr 4:4:4 (BT.709, limited range, 100% bars)
// Ten bits per component, a smaller bit depth is rounded from the top.
// The components take the place of red, green and blue as DisplayPort maps them:
// Cr on red, Y on green and Cb on blue.
typedef enum {black, white, yellow, cyan, green, magenta, red, blue} bar_type;

localparam logic [9:0] P_YUV_Y  [0:7] = '{10'd64,  10'd940, 10'd877, 10'd754, 10'd691, 10'd313, 10'd250, 10'd127};
localparam logic [9:0] P_YUV_CB [0:7] = '{10'd512, 10'd512, 10'd64,  10'd615, 10'd167, 10'd857, 10'd409, 10'd960};
localparam logic [9:0] P_YUV_CR [0:7] = '{10'd512, 10'd512, 10'd553, 10'd64,  10'd105, 10'd919, 10'd960, 10'd471};
localparam logic [9:0] P_YUV_MID = 10'd512;

// Component value in the bit depth of the core
function automatic logic [P_BPC-1:0] yuv_cmp (logic [9:0] val);
	logic [10:0] rnd;
	if (P_BPC >= 10)
		return P_BPC'(val) << (P_BPC - 10);
	else
	begin
		rnd = val + (11'd1 << (10 - P_BPC - 1));
		return (rnd[10]) ? '1 : rnd[9-:P_BPC];
	end
endfunction

// Colour of a bar as {red / Cr, green / Y, blue / Cb}
function automatic logic [(3 * P_BPC)-1:0] bar_col (bar_type bar, logic csf);
	logic r, g, b;
	if (csf)
		return {yuv_cmp(P_YUV_CR[bar]), yuv_cmp(P_YUV_Y[bar]), yuv_cmp(P_YUV_CB[bar])};
	else
	begin
		r = (bar == white) || (bar == yellow) || (bar == magenta) || (bar == red);
		g = (bar == white) || (bar == yellow) || (bar == cyan) || (bar == green);
		b = (bar == white) || (bar == cyan) || (bar == magenta) || (bar == blue);
		return {(r ? P_BPC'(P_HI_VAL) : P_BPC'(P_LO_VAL)), (g ? P_BPC'(P_HI_VAL) : P_BPC'(P_LO_VAL)), (b ? P_BPC'(P_HI_VAL) : P_BPC'(P_LO_VAL))};
	end
endfunction

// Signals
logic 							clk_run;
logic [2:0]						clk_fmt;
logic 							clk_csf;
logic [(3 * P_BPC)-1:0]			clk_col;
logic [15:0]					clk_hwidth;	
logic [15:0]					clk_vheight;
logic [15:0]					clk_vheight_quad;
logic [15:0]					clk_ramp_str;
logic [15:0]					clk_lines_str;
wire  [12:0]					clk_bar_width;
logic [1:0]						clk_vs;
wire 							clk_vs_re;
logic [1:0]						clk_hs;
logic [1:0]						clk_de;
wire 							clk_de_fe;
logic [15:0]					clk_pcnt;
logic [15:0]					clk_lcnt;
logic [(P_PPC * P_BPC)-1:0]		clk_r;
logic [(P_PPC * P_BPC)-1:0]		clk_g;
logic [(P_PPC * P_BPC)-1:0]		clk_b;
bar_type						clk_bar;

// Logic

// Config
	always_ff @ (posedge CLK_IN)
	begin
		clk_run <= CTL_RUN_IN;
		clk_fmt <= CTL_FMT_IN;
		clk_csf <= CTL_CSF_IN;
	end

// Video Inputs
	always_ff @ (posedge CLK_IN)
	begin
		// Clock enable
		if (CKE_IN)
		begin
			clk_vs <= {clk_vs[0], VID_VS_IN};
			clk_hs <= {clk_hs[0], VID_HS_IN};
			clk_de <= {clk_de[0], VID_DE_IN};
		end
	end

// Hwidth register
	always_ff @ (posedge CLK_IN)
	begin
		// Write
		if ((VPS_IDX_IN == 'd5) && VPS_VLD_IN)
		begin
			// Four pixels per clock
			if (P_PPC == 4)
				clk_hwidth <= VPS_DAT_IN[2+:$size(clk_hwidth)-2]; 

			// Two pixels per clock
			else
				clk_hwidth <= VPS_DAT_IN[1+:$size(clk_hwidth)-1]; 
		end
	end

// Vheight register
	always_ff @ (posedge CLK_IN)
	begin
		// Write
		if ((VPS_IDX_IN == 'd9) && VPS_VLD_IN)
			clk_vheight <= VPS_DAT_IN[0+:$size(clk_vheight)];
	end

// Quad height
	assign clk_vheight_quad = clk_vheight[15:2];

	always_ff @ (posedge CLK_IN)
	begin
		clk_ramp_str <= 2 * clk_vheight_quad;
		clk_lines_str <= 3 * clk_vheight_quad;
	end

// Vsync edge detector
    prt_lib_edge
    VS_EDGE_INST
    (
        .CLK_IN    (CLK_IN),        // Clock
        .CKE_IN    (CKE_IN),       	// Clock enable
        .A_IN      (clk_vs[0]),    	// Input
        .RE_OUT    (clk_vs_re),    	// Rising edge
        .FE_OUT    ()               // Falling edge
    );

// DE edge detector
    prt_lib_edge
    DE_EDGE_INST
    (
        .CLK_IN    (CLK_IN),        // Clock
        .CKE_IN    (CKE_IN),       	// Clock enable
        .A_IN      (clk_de[0]),    	// Input
        .RE_OUT    (),    			// Rising edge
        .FE_OUT    (clk_de_fe)      // Falling edge
    );

// Pixel counter
	always_ff @ (posedge CLK_IN)
	begin
		// Run
		if (clk_run)
		begin
			// Clock enable
			if (CKE_IN)
			begin
				if (clk_de[0])
					clk_pcnt <= clk_pcnt + 'd1;
				else
					clk_pcnt <= 0;
			end
		end

		else
			clk_pcnt <= 0;
	end

// Line counter
	always_ff @ (posedge CLK_IN)
	begin
		// Run
		if (clk_run)
		begin
			// Clock enable
			if (CKE_IN)
			begin
				// Clear
				if (clk_vs_re)
					clk_lcnt <= 0;

				// Increment
				else if (clk_de_fe)
					clk_lcnt <= clk_lcnt + 1;
			end
		end

		else
			clk_lcnt <= 0;
	end

// Segment width
	assign clk_bar_width = clk_hwidth[15:3];

// Bar
	always_ff @ (posedge CLK_IN)
	begin
		// Clock enable
		if (CKE_IN)
		begin
			if (clk_pcnt < (clk_bar_width * 1))
				clk_bar <= white;
			
			else if (clk_pcnt < (clk_bar_width * 2))
				clk_bar <= yellow;

			else if (clk_pcnt < (clk_bar_width * 3))
				clk_bar <= cyan;

			else if (clk_pcnt < (clk_bar_width * 4))
				clk_bar <= green;

			else if (clk_pcnt < (clk_bar_width * 5))
				clk_bar <= magenta;

			else if (clk_pcnt < (clk_bar_width * 6))
				clk_bar <= red;

			else if (clk_pcnt < (clk_bar_width * 7))
				clk_bar <= blue;

			else
				clk_bar <= black;
		end
	end

// Colour of the bar or of the single colour format
	always_comb
	begin
		case (clk_fmt)
			'd1 : clk_col = bar_col (red, clk_csf);
			'd2 : clk_col = bar_col (green, clk_csf);
			'd3 : clk_col = bar_col (blue, clk_csf);
			default : clk_col = bar_col (clk_bar, clk_csf);
		endcase
	end

// Video
	always_ff @ (posedge CLK_IN)
	begin
		// Clock enable
		if (CKE_IN)
		begin
			// Red, green or blue only
			if ((clk_fmt == 'd1) || (clk_fmt == 'd2) || (clk_fmt == 'd3))
			begin
				clk_r <= {P_PPC{clk_col[(2*P_BPC)+:P_BPC]}};
				clk_g <= {P_PPC{clk_col[(1*P_BPC)+:P_BPC]}};
				clk_b <= {P_PPC{clk_col[(0*P_BPC)+:P_BPC]}};
			end

			// Ramp
			// In YCbCr the ramp is on the luma, the chroma stays in the middle (grey).
			else if ((clk_fmt == 'd4) || ((clk_lcnt >= clk_ramp_str) && (clk_lcnt < clk_lines_str)))
			begin
				// Four pixels per clock
				if (P_PPC == 4)
				begin
					clk_r <= (clk_csf) ? {P_PPC{yuv_cmp(P_YUV_MID)}} : {clk_pcnt[P_BPC-3:0], 2'b11, clk_pcnt[P_BPC-3:0], 2'b10, clk_pcnt[P_BPC-3:0], 2'b01, clk_pcnt[P_BPC-3:0], 2'b00};
					clk_g <= {clk_pcnt[P_BPC-3:0], 2'b11, clk_pcnt[P_BPC-3:0], 2'b10, clk_pcnt[P_BPC-3:0], 2'b01, clk_pcnt[P_BPC-3:0], 2'b00};
					clk_b <= (clk_csf) ? {P_PPC{yuv_cmp(P_YUV_MID)}} : {clk_pcnt[P_BPC-3:0], 2'b11, clk_pcnt[P_BPC-3:0], 2'b10, clk_pcnt[P_BPC-3:0], 2'b01, clk_pcnt[P_BPC-3:0], 2'b00};
				end

				// Two pixels per clock
				else
				begin
					clk_r <= (clk_csf) ? {P_PPC{yuv_cmp(P_YUV_MID)}} : {clk_pcnt[P_BPC-2:0], 1'b1, clk_pcnt[P_BPC-2:0], 1'b0};
					clk_g <= {clk_pcnt[P_BPC-2:0], 1'b1, clk_pcnt[P_BPC-2:0], 1'b0};
					clk_b <= (clk_csf) ? {P_PPC{yuv_cmp(P_YUV_MID)}} : {clk_pcnt[P_BPC-2:0], 1'b1, clk_pcnt[P_BPC-2:0], 1'b0};
				end
			end

			// Lines
			// In YCbCr the lines are black and white.
			else if (clk_lcnt >= clk_lines_str)
			begin
				if (clk_csf)
				begin
					clk_r <= {P_PPC{yuv_cmp(P_YUV_MID)}};
					clk_g <= {P_PPC{clk_pcnt[0] ? yuv_cmp(P_YUV_Y[white]) : yuv_cmp(P_YUV_Y[black])}};
					clk_b <= {P_PPC{yuv_cmp(P_YUV_MID)}};
				end

				else
				begin
					clk_r <= clk_pcnt[0] ? '1 : 0;
					clk_g <= clk_pcnt[0] ? '1 : 0;
					clk_b <= clk_pcnt[0] ? '1 : 0;
				end
			end

			// Color bar
			else
			begin
				clk_r <= {P_PPC{clk_col[(2*P_BPC)+:P_BPC]}};
				clk_g <= {P_PPC{clk_col[(1*P_BPC)+:P_BPC]}};
				clk_b <= {P_PPC{clk_col[(0*P_BPC)+:P_BPC]}};
			end
		end
	end

// Outputs
	assign VID_VS_OUT = clk_vs[1];
	assign VID_HS_OUT = clk_hs[1];

	assign VID_R_OUT  = clk_r;
	assign VID_G_OUT  = clk_g;
	assign VID_B_OUT  = clk_b;
	assign VID_DE_OUT = clk_de[1];
endmodule

`default_nettype wire
