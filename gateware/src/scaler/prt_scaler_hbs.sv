/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Scaler Horizontal Bilinear Scaler
    (c) 2022 by Parretto B.V.

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

module prt_scaler_hbs
#(
     parameter P_PPC = 4,          // Pixels per clock
     parameter P_BPC = 8           // Bits per component
)
(
     // Reset and clock
     input wire                              CLK_IN,

     // Control
     input wire                              CTL_RUN_IN,         // Run

     // Timing
     input wire                              HS_IN,    // HSync

     // Video in
     input wire     [(P_PPC * P_BPC)-1:0]    DAT_IN,   // Data
     input wire                              WR_IN,    // Write

     // Video out
     output wire                             HS_OUT,   // Hsync
     output wire     [(P_PPC * P_BPC)-1:0]   DAT_OUT,  // Data
     output wire                             DE_OUT    // Data enable
);

// Structures
typedef struct {
     logic                         run;
     logic [6:0]                   hs;
     logic [4:0]                   de;
     logic [P_BPC-1:0]             din_a[0:P_PPC-1];
     logic [P_BPC-1:0]             din_b[0:P_PPC-1];
     logic [P_BPC:0]               tmp[0:P_PPC-1];
     logic [P_BPC-1:0]             dout[0:P_PPC-1];
} hbs_struct;

// Signals
hbs_struct          clk_hbs;

genvar i;

// Logic

// HSync delay
     always_ff @ (posedge CLK_IN)
     begin
          clk_hbs.hs <= {clk_hbs.hs[0+:$left(clk_hbs.hs)], HS_IN};
     end

// Data enable
     always_ff @ (posedge CLK_IN)
     begin
          clk_hbs.de <= {clk_hbs.de[0+:$left(clk_hbs.de)], WR_IN};
     end

// Data in
     always_ff @ (posedge CLK_IN)
     begin
          // Data a
          if (WR_IN)
          begin
               for (int i = 0; i < P_PPC; i++)
                    clk_hbs.din_a[i] <= DAT_IN[(i*P_BPC)+:P_BPC];
          end

          // Data b
          if (clk_hbs.de[1])
          begin
               for (int i = 0; i < P_PPC; i++)
                    clk_hbs.din_b[i] <= clk_hbs.din_a[i];
          end
     end

// Scaled data
     assign clk_hbs.tmp[0] = clk_hbs.din_b[0] + clk_hbs.din_b[1];
     assign clk_hbs.tmp[1] = clk_hbs.din_b[1] + clk_hbs.din_b[2];
     assign clk_hbs.tmp[2] = clk_hbs.din_b[2] + clk_hbs.din_b[3];
     assign clk_hbs.tmp[3] = clk_hbs.din_b[3] + clk_hbs.din_a[0];

// Output data
     always_ff @ (posedge CLK_IN)
     begin     
          if (clk_hbs.de[3])
          begin
               clk_hbs.dout[0] <= clk_hbs.din_b[2];
               clk_hbs.dout[1] <= clk_hbs.tmp[2][1+:P_BPC];
               clk_hbs.dout[2] <= clk_hbs.din_b[3];
               clk_hbs.dout[3] <= clk_hbs.tmp[3][1+:P_BPC];
          end
          
          else
          begin
               clk_hbs.dout[0] <= clk_hbs.din_b[0];
               clk_hbs.dout[1] <= clk_hbs.tmp[0][1+:P_BPC];
               clk_hbs.dout[2] <= clk_hbs.din_b[1];
               clk_hbs.dout[3] <= clk_hbs.tmp[1][1+:P_BPC];
          end
     end     


// Outputs
     assign HS_OUT = clk_hbs.hs[$left(clk_hbs.hs)];
     assign DE_OUT = clk_hbs.de[$left(clk_hbs.de)] || clk_hbs.de[$left(clk_hbs.de)-1];

generate
     for (i = 0; i < P_PPC; i++)
     begin : gen_dat_out
          assign DAT_OUT[(i*P_BPC)+:P_BPC] = clk_hbs.dout[i];
     end
endgenerate
     
endmodule

`default_nettype wire
