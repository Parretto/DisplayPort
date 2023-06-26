/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Full array local dimming Color space converter
    (c) 2023 by Parretto B.V.

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

module prt_fald_csc
#(
    parameter                   P_BPC = 8   // Bits per component
)
(
    // Reset and clock
    input wire                  CLK_IN,     // Clock

    // Video in
    input wire [P_BPC-1:0]      R_IN,
    input wire [P_BPC-1:0]      G_IN,
    input wire [P_BPC-1:0]      B_IN,
    input wire                  DE_IN,

    // Video out
    output wire [P_BPC-1:0]     Y_OUT,
    output wire                 DE_OUT   
);

// Parameters
localparam P_COEF_R = 76;
localparam P_COEF_G = 150;
localparam P_COEF_B = 29;
localparam P_MAX_Y = (2**P_BPC)-1;

// Signals
logic [P_BPC-1:0]       clk_r;
logic [P_BPC-1:0]       clk_g;
logic [P_BPC-1:0]       clk_b;
logic [(P_BPC*2)-1:0]   clk_r_mult;
logic [(P_BPC*2)-1:0]   clk_g_mult;
logic [(P_BPC*2)-1:0]   clk_b_mult;
logic [P_BPC-1:0]       clk_y;
logic [2:0]             clk_de;

// Logic

// Input registers
    always_ff @ (posedge CLK_IN)
    begin
        clk_r <= R_IN;
        clk_g <= G_IN;
        clk_b <= B_IN;
    end

// Multiply
    always_ff @ (posedge CLK_IN)
    begin
        clk_r_mult <= clk_r * P_COEF_R;
        clk_g_mult <= clk_g * P_COEF_G;
        clk_b_mult <= clk_b * P_COEF_B;
    end

// Luma
    always_ff @ (posedge CLK_IN)
    begin
        clk_y <= clk_r_mult[P_BPC+:P_BPC] + clk_g_mult[P_BPC+:P_BPC] + clk_b_mult[P_BPC+:P_BPC];
    end

// Data enable
    always_ff @ (posedge CLK_IN)
    begin
        clk_de <= {clk_de[$high(clk_de)-1:0], DE_IN};
    end

// Outputs
    assign Y_OUT = clk_y;
    assign DE_OUT = clk_de[$high(clk_de)];

endmodule

`default_nettype wire
