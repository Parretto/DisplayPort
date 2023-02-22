/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Scaler kernel multiplier and adder 
    (c) 2022 - 2023 by Parretto B.V.

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

module prt_scaler_krnl_mac
#(
     parameter P_BPC = 8
)
(
     // Clock
     input wire                    CLK_IN,

     // Coefficients
     input wire     [P_BPC-1:0]    C0_IN,  
     input wire     [P_BPC-1:0]    C1_IN,  
     input wire     [P_BPC-1:0]    C2_IN,  
     input wire     [P_BPC-1:0]    C3_IN,  

     // Pixels in
     input wire     [P_BPC-1:0]    P0_IN,  
     input wire     [P_BPC-1:0]    P1_IN,  
     input wire     [P_BPC-1:0]    P2_IN,  
     input wire     [P_BPC-1:0]    P3_IN,  

     // Pixel out
     output wire    [P_BPC-1:0]    P_OUT  
);

// Signals
wire  [P_BPC-1:0]        clk_c[0:3];   // Coefficients
wire  [P_BPC-1:0]        clk_s[0:3];   // Source pixels
logic [(P_BPC*2)-1:0]    clk_m[0:3];   // Multiplier
logic [P_BPC+1:0]        clk_a[0:2];   // Adder
logic [P_BPC-1:0]        clk_p;

// Logic

// Map coefficients
     assign clk_c[0] = C0_IN;
     assign clk_c[1] = C1_IN;
     assign clk_c[2] = C2_IN;
     assign clk_c[3] = C3_IN;

// Map Pixels
     assign clk_s[0] = P0_IN;
     assign clk_s[1] = P1_IN;
     assign clk_s[2] = P2_IN;
     assign clk_s[3] = P3_IN;

// Multiplier
     always_ff @ (posedge CLK_IN)
     begin
          for (int i = 0; i < 4; i++)
               clk_m[i] <= clk_s[i] * clk_c[i];
     end

// Adder
     always_ff @ (posedge CLK_IN)
     begin
          clk_a[0] <= clk_m[0][P_BPC+:P_BPC] + clk_m[1][P_BPC+:P_BPC];
          clk_a[1] <= clk_m[2][P_BPC+:P_BPC] + clk_m[3][P_BPC+:P_BPC];
          clk_a[2] <= clk_a[0] + clk_a[1];
     end

// Pixel out
     always_ff @ (posedge CLK_IN)
     begin
          // Clipping
          if (clk_a[2] > ((2**P_BPC)-1))
               clk_p <= '1;

          else
               clk_p <= clk_a[2][0+:P_BPC];
     end

// Output
     assign P_OUT = clk_p;

endmodule

`default_nettype wire

