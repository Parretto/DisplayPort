/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Scaler multiplier
    (c) 2022, 2023 by Parretto B.V.

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

module prt_scaler_krnl_mux
#(
    parameter                              P_BPC = 8           // Bits per component
)
(
    // Reset and clock
    input wire                              CLK_IN,

    // Select
    input wire [3:0]                        SEL_IN,

    // Data in
    input wire [P_BPC-1:0]                  A_DAT_IN,
    input wire [P_BPC-1:0]                  B_DAT_IN,
    input wire [P_BPC-1:0]                  C_DAT_IN,
    input wire [P_BPC-1:0]                  D_DAT_IN,
    input wire [P_BPC-1:0]                  E_DAT_IN,
    input wire [P_BPC-1:0]                  F_DAT_IN,
    input wire [P_BPC-1:0]                  G_DAT_IN,
    input wire [P_BPC-1:0]                  H_DAT_IN,
    input wire [P_BPC-1:0]                  I_DAT_IN,
    input wire [P_BPC-1:0]                  J_DAT_IN,

    // Data out
    output wire [P_BPC-1:0]                 DAT_OUT
);


// Signals
logic [P_BPC-1:0]   clk_dat;

// Logic

    always_ff @ (posedge CLK_IN)
    begin
        case (SEL_IN)

            'h1 : clk_dat <= B_DAT_IN; // Line 0 - Pixel 1

            'h2 : clk_dat <= C_DAT_IN; // Line 0 - Pixel 2

            'h3 : clk_dat <= D_DAT_IN; // Line 0 - Pixel 3

            'h4 : clk_dat <= E_DAT_IN; // Line 0 - Pixel 4

            'h8 : clk_dat <= F_DAT_IN; // Line 1 - Pixel 0

            'h9 : clk_dat <= G_DAT_IN; // Line 1 - Pixel 1

            'ha : clk_dat <= H_DAT_IN; // Line 1 - Pixel 2

            'hb : clk_dat <= I_DAT_IN; // Line 1 - Pixel 3

            'hc : clk_dat <= J_DAT_IN; // Line 1 - Pixel 4

            default : clk_dat <= A_DAT_IN; // Line 0 - Pixel 0 
        endcase
    end

// Outputs
    assign DAT_OUT = clk_dat;

endmodule

`default_nettype wire
