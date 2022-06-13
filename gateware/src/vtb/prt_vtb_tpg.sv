/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Video Toolbox Test Pattern Generator
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


// Signals
logic 							clk_run;
logic [15:0]					clk_hwidth;	
logic [15:0]					clk_vheight;
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
enum {black, white, yellow, cyan, green, magenta, red, blue} clk_bar;

// Logic

// Run
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_run <= 0;
		else
			clk_run <= CTL_RUN_IN;
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

// Vsync edge detector
    prt_dp_lib_edge
    VS_EDGE_INST
    (
        .CLK_IN    (CLK_IN),        // Clock
        .CKE_IN    (CKE_IN),       	// Clock enable
        .A_IN      (clk_vs[0]),    	// Input
        .RE_OUT    (clk_vs_re),    	// Rising edge
        .FE_OUT    ()               // Falling edge
    );

// DE edge detector
    prt_dp_lib_edge
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

// Video
	always_ff @ (posedge CLK_IN)
	begin
		// Clock enable
		if (CKE_IN)
		begin
			// Ramp
			if (clk_lcnt > clk_vheight[15:1])
			begin
				// Four pixels per clock
				if (P_PPC == 4)
				begin
					clk_r <= {clk_pcnt[5:0], 2'b11, clk_pcnt[5:0], 2'b10, clk_pcnt[5:0], 2'b01, clk_pcnt[5:0], 2'b00};
					clk_g <= {clk_pcnt[5:0], 2'b11, clk_pcnt[5:0], 2'b10, clk_pcnt[5:0], 2'b01, clk_pcnt[5:0], 2'b00};
					clk_b <= {clk_pcnt[5:0], 2'b11, clk_pcnt[5:0], 2'b10, clk_pcnt[5:0], 2'b01, clk_pcnt[5:0], 2'b00};
				end

				// Two pixels per clock
				else
				begin
					clk_r <= {clk_pcnt[6:0], 1'b1, clk_pcnt[6:0], 1'b0};
					clk_g <= {clk_pcnt[6:0], 1'b1, clk_pcnt[6:0], 1'b0};
					clk_b <= {clk_pcnt[6:0], 1'b1, clk_pcnt[6:0], 1'b0};
				end
			end

			// Color bar
			else
			begin
				case (clk_bar)
					white : 
					begin
						clk_r <= {P_PPC{P_BPC'(180)}};
						clk_g <= {P_PPC{P_BPC'(180)}};
						clk_b <= {P_PPC{P_BPC'(180)}};
					end					

					yellow : 
					begin
						clk_r <= {P_PPC{P_BPC'(180)}};
						clk_g <= {P_PPC{P_BPC'(180)}};
						clk_b <= {P_PPC{P_BPC'(16)}};
					end					

					cyan : 
					begin
						clk_r <= {P_PPC{P_BPC'(16)}};
						clk_g <= {P_PPC{P_BPC'(180)}};
						clk_b <= {P_PPC{P_BPC'(180)}};
					end					

					green : 
					begin
						clk_r <= {P_PPC{P_BPC'(16)}};
						clk_g <= {P_PPC{P_BPC'(180)}};
						clk_b <= {P_PPC{P_BPC'(16)}};
					end					

					magenta : 
					begin
						clk_r <= {P_PPC{P_BPC'(180)}};
						clk_g <= {P_PPC{P_BPC'(16)}};
						clk_b <= {P_PPC{P_BPC'(180)}};
					end					

					red : 
					begin
						clk_r <= {P_PPC{P_BPC'(180)}};
						clk_g <= {P_PPC{P_BPC'(16)}};
						clk_b <= {P_PPC{P_BPC'(16)}};
					end					

					blue : 
					begin
						clk_r <= {P_PPC{P_BPC'(16)}};
						clk_g <= {P_PPC{P_BPC'(16)}};
						clk_b <= {P_PPC{P_BPC'(180)}};
					end					

					default : 
					begin
						clk_r <= {P_PPC{P_BPC'(16)}};
						clk_g <= {P_PPC{P_BPC'(16)}};
						clk_b <= {P_PPC{P_BPC'(16)}};
					end					
				endcase 
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
