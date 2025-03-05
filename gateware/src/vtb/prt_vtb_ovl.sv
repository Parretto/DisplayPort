/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Video Toolbox Overlay
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

module prt_vtb_ovl
#(
    parameter P_IMG = 1,        // Image
	parameter P_PPC = 2,		// Pixels per clock
	parameter P_BPC = 8			// Bits per component
)
(
    // Clock
    input wire                              CLK_IN,
    
   	// Control
	input wire 								CTL_RUN_IN,		// Run

    // Video in
    input wire                              VID_VS_IN,
    input wire                              VID_HS_IN,
    input wire                              VID_DE_IN,
   	input wire [(P_BPC * P_PPC)-1:0]		VID_R_IN,		// Red
	input wire [(P_BPC * P_PPC)-1:0]		VID_G_IN,		// Green
	input wire [(P_BPC * P_PPC)-1:0]		VID_B_IN,		// Blue

    // Video out
    output wire                             VID_VS_OUT,
    output wire                             VID_HS_OUT,
    output wire                             VID_DE_OUT,
   	output wire [(P_BPC * P_PPC)-1:0]		VID_R_OUT,		// Red
	output wire [(P_BPC * P_PPC)-1:0]		VID_G_OUT,		// Green
	output wire [(P_BPC * P_PPC)-1:0]		VID_B_OUT		// Blue
);

// Signals
logic 							clk_run;
logic [1:0]                     clk_vs;
logic [1:0]                     clk_hs;
logic [1:0]                     clk_de;
wire                            clk_de_fe;
logic [(P_BPC * P_PPC)-1:0]     clk_r_in;
logic [(P_BPC * P_PPC)-1:0]     clk_g_in;
logic [(P_BPC * P_PPC)-1:0]     clk_b_in;
logic [(P_BPC * P_PPC)-1:0]     clk_r_out;
logic [(P_BPC * P_PPC)-1:0]     clk_g_out;
logic [(P_BPC * P_PPC)-1:0]     clk_b_out;
logic [15:0]                    clk_pix;
logic [15:0]                    clk_lin;
wire [17:0]                     adr_to_img;
wire                            dat_from_img;

// Config
	always_ff @ (posedge CLK_IN)
	begin
		clk_run <= CTL_RUN_IN;
	end

// Inputs 
    always_ff @ (posedge CLK_IN)
    begin
        clk_vs <= {clk_vs[0], VID_VS_IN};
        clk_hs <= {clk_hs[0], VID_HS_IN};
        clk_de <= {clk_de[0], VID_DE_IN};
    end

    always_ff @ (posedge CLK_IN)
    begin
        clk_r_in <= VID_R_IN;
        clk_g_in <= VID_G_IN;
        clk_b_in <= VID_B_IN;
    end

// Data enable edge detector
// This is used to increment the line counter
    prt_dp_lib_edge
    DE_EDGE_INST
    (
        .CLK_IN    (CLK_IN), 		// Clock
        .CKE_IN    (1'b1),          // Clock enable
        .A_IN      (clk_de[0]), 	// Input
        .RE_OUT    (),  		    // Rising edge
        .FE_OUT    (clk_de_fe)   	// Falling edge
    );

// Pixel counter
    always_ff @ (posedge CLK_IN)
    begin
        // Clear
        if (clk_hs[0])
            clk_pix <= 0;
        
        // Increment
        else if (clk_de[0])
            clk_pix <= clk_pix + 'd1;
    end

// Lines counter
    always_ff @ (posedge CLK_IN)
    begin
        // Clear
        if (clk_vs[0])
            clk_lin <= 0;

        // Increment
        else if (clk_de_fe)
            clk_lin <= clk_lin + 'd1;
    end
 
    assign adr_to_img = (P_PPC == 4) ? {clk_lin[2+:9], clk_pix[0+:9]} : {clk_lin[2+:9], clk_pix[1+:9]};

// Image
generate
    if (P_IMG == 2)
    begin : two
        prt_vtb_ovl_two
        IMG_INST
        (
            .CLK_IN     (CLK_IN),
            .ADR_IN     (adr_to_img),
            .DAT_OUT    (dat_from_img)
        );
    end

    else
    begin : one
        prt_vtb_ovl_one
        IMG_INST
        (
            .CLK_IN     (CLK_IN),
            .ADR_IN     (adr_to_img),
            .DAT_OUT    (dat_from_img)
        );
    end
endgenerate 

// Data out
    always_ff @ (posedge CLK_IN)
    begin
        // Default
        clk_r_out <= clk_r_in;
        clk_g_out <= clk_g_in;
        clk_b_out <= clk_b_in;

        // Run
        if (clk_run)
        begin
            if (dat_from_img)
            begin
                clk_r_out <= {P_PPC{P_BPC'(180)}};
                clk_g_out <= {P_PPC{P_BPC'(180)}};
                clk_b_out <= {P_PPC{P_BPC'(180)}};
            end
        end
    end

// Outputs
    assign VID_VS_OUT = clk_vs[$high(clk_vs)];
    assign VID_HS_OUT = clk_hs[$high(clk_hs)];
    assign VID_DE_OUT = clk_de[$high(clk_de)];
    assign VID_R_OUT = clk_r_out;
    assign VID_G_OUT = clk_g_out;
    assign VID_B_OUT = clk_b_out;

endmodule

`default_nettype wire
