/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Scaler line store
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

module prt_scaler_lst
#(
     parameter                               P_VENDOR = "none",  // Vendor "xilinx" or "lattice"
     parameter                               P_PPC = 4,          // Pixels per clock
     parameter                               P_BPC = 8           // Bits per component
)
(
     // Reset and clock
     input wire                              RST_IN,             // Reset
     input wire                              CLK_IN,             // Clock

     // Control
     input wire                              CTL_RUN_IN,        // Run
     input wire [15:0]                       CTL_VHEIGHT_IN,    // Source vertical height

     // Video in
     input wire                              VID_CKE_IN,      
     input wire                              VID_VS_IN,         // Vsync
     input wire                              VID_HS_IN,         // Hsync
     input wire     [(P_PPC * P_BPC)-1:0]    VID_DAT_IN,        // Data
     input wire                              VID_DE_IN,         // Data enable

     // Line out
     output wire                             LST_RDY_OUT,        // Ready
     input wire                              LST_LRST_IN,        // Restore line
     input wire                              LST_LNXT_IN,        // Next line
     input wire     [3:0]                    LST_RD0_IN,         // Read line 0
     input wire     [3:0]                    LST_RD1_IN,         // Read line 1
     output wire    [(P_PPC * P_BPC)-1:0]    LST_DAT0_OUT,       // Data line 0
     output wire    [(P_PPC * P_BPC)-1:0]    LST_DAT1_OUT        // Data line 1
);

// Parameters
localparam P_LINES = 5;
localparam P_FIFOS = P_LINES*4;           // One line buffer has 4 pixels per clock
localparam P_FIFO_WRDS = 2048;          // Max resolution is 3840 pixels / 4. 
localparam P_FIFO_ADR = $clog2(P_FIFO_WRDS);
localparam P_FIFO_DAT = P_BPC;

// Structures
typedef struct {
    logic               run;
    logic [15:0]        vheight;
} ctl_struct;

typedef struct {
     logic                         vs;
     logic                         vs_re;
     logic                         hs;
     logic                         hs_re;
     logic [P_BPC-1:0]             dat[0:P_PPC-1];
     logic                         de;
     logic                         de_fe;
     logic [2:0]                   sel;
     logic [15:0]                  vcnt;
} vid_struct;

typedef struct {
     logic [P_FIFO_DAT-1:0]        din;
     logic                         wr_clr;
     logic                         wr;
     logic                         rd_clr;
     logic                         rd;
     logic [P_FIFO_DAT-1:0]        dout;
     logic                         de;
     logic [P_FIFO_ADR:0]          wrds;
     logic                         ep;
     logic                         fl;
} fifo_struct;

typedef struct {
     logic [P_LINES-1:0]           av;
     logic                         rdy;
     logic                         lrst;
     logic                         lnxt;
     logic [2:0]                   sel;
     logic [3:0]                   rd[0:1];
     logic [(P_PPC * P_BPC)-1:0]   dat[0:1];
     logic [3:0]                   de[0:1];
     logic [3:0]                   ep[0:4];
} lst_struct;

// Signals
ctl_struct               clk_ctl;
vid_struct               clk_vid;
fifo_struct              clk_fifo[0:P_FIFOS-1];
lst_struct               clk_lst;

genvar i;

// Logic

// Control
     always_ff @ (posedge RST_IN, posedge CLK_IN)
     begin
          // Reset
          if (RST_IN)
               clk_ctl.run <= 0;
          
          else
               clk_ctl.run <= CTL_RUN_IN;
     end

     always_ff @ (posedge CLK_IN)
     begin
          clk_ctl.vheight <= CTL_VHEIGHT_IN;
     end

// Video inputs
     always_ff @ (posedge CLK_IN)
     begin
          // Enable
          if (VID_CKE_IN)
          begin
               clk_vid.vs <= VID_VS_IN;
               clk_vid.hs <= VID_HS_IN;
               clk_vid.de <= VID_DE_IN;
          end
     end

// Map video data
     always_ff @ (posedge CLK_IN)
     begin
          // Enable
          if (VID_CKE_IN)
          begin
               for (int i = 0; i < 4; i++)
                    clk_vid.dat[i] <= VID_DAT_IN[(i*P_BPC)+:P_BPC];
          end
     end

// Vsync edge detector
     prt_scaler_lib_edge
     VID_VS_EDGE_INST
     (
          .CLK_IN   (CLK_IN),           // Clock
          .CKE_IN   (VID_CKE_IN),       // Clock enable
          .A_IN     (clk_vid.vs),       // Input
          .RE_OUT   (clk_vid.vs_re),    // Rising edge
          .FE_OUT   ()                  // Falling edge
     );

// Hsync edge detector
     prt_scaler_lib_edge
     VID_HS_EDGE_INST
     (
          .CLK_IN   (CLK_IN),           // Clock
          .CKE_IN   (VID_CKE_IN),       // Clock enable
          .A_IN     (clk_vid.hs),       // Input
          .RE_OUT   (clk_vid.hs_re),    // Rising edge
          .FE_OUT   ()                  // Falling edge
     );

// Data enable edge detector
     prt_scaler_lib_edge
     VID_DE_EDGE_INST
     (
          .CLK_IN   (CLK_IN),           // Clock
          .CKE_IN   (VID_CKE_IN),       // Clock enable
          .A_IN     (clk_vid.de),       // Input
          .RE_OUT   (),                 // Rising edge
          .FE_OUT   (clk_vid.de_fe)     // Falling edge
     );

// Vertical line counter
// This is used to detect the end of the video frame data
     always_ff @ (posedge CLK_IN)
     begin
          // Run
          if (clk_ctl.run)
          begin
               // Enable
               if (VID_CKE_IN)
               begin
                    // Clear
                    if (clk_vid.vs_re)
                         clk_vid.vcnt <= 0;

                    // Increment
                    else if (clk_vid.de_fe)
                         clk_vid.vcnt <= clk_vid.vcnt + 'd1;
               end
          end

          else
               clk_vid.vcnt <= 0;
     end

// Video select
     always_ff @ (posedge CLK_IN)
     begin
          // Run
          if (clk_ctl.run)
          begin
               // Enable
               if (VID_CKE_IN)
               begin
                    // Clear
                    if (clk_vid.vs_re)
                         clk_vid.sel <= 0;

                    // Next line
                    else if (clk_vid.de_fe)
                    begin
                         if (clk_vid.sel == P_LINES-1)
                              clk_vid.sel <= 0;
                         else
                              clk_vid.sel <= clk_vid.sel + 'd1;
                    end
               end
          end

          else
               clk_vid.sel <= 0;
     end

// FIFO Write
// Must be combinatorial
generate  
     for (i = 0; i < 4; i++)
     begin : gen_fifo_wr
          assign clk_fifo[i].wr = (clk_vid.sel == 'd0) ? clk_vid.de : 0;
          assign clk_fifo[i+4].wr = (clk_vid.sel == 'd1) ? clk_vid.de : 0;
          assign clk_fifo[i+8].wr = (clk_vid.sel == 'd2) ? clk_vid.de : 0;
          assign clk_fifo[i+12].wr = (clk_vid.sel == 'd3) ? clk_vid.de : 0;
          assign clk_fifo[i+16].wr = (clk_vid.sel == 'd4) ? clk_vid.de : 0;
     end
endgenerate

// FIFO write data
generate  
     for (i = 0; i < P_FIFOS; i+=4)
     begin : gen_fifo_din
          assign clk_fifo[i+0].din = clk_vid.dat[0];
          assign clk_fifo[i+1].din = clk_vid.dat[1];
          assign clk_fifo[i+2].din = clk_vid.dat[2];
          assign clk_fifo[i+3].din = clk_vid.dat[3];
     end
endgenerate

// FIFO write clear
     always_ff @ (posedge CLK_IN)
     begin
          // Enable
          if (VID_CKE_IN)
          begin

               // Default
               for (int i = 0; i < P_FIFOS; i++)
                    clk_fifo[i].wr_clr <= 0;

               // Start of frame
               if (clk_vid.vs_re)
               begin
                    for (int i = 0; i < P_FIFOS; i++)
                         clk_fifo[i].wr_clr <= 1;
               end

               // Next line
               else if (clk_vid.hs_re)
               begin                 
                    case (clk_vid.sel)
                         'd1 :
                         begin
                              for (int i = 0; i < 4; i++)
                                   clk_fifo[(1*4)+i].wr_clr <= 1;
                         end

                         'd2 :
                         begin
                              for (int i = 0; i < 4; i++)
                                   clk_fifo[(2*4)+i].wr_clr <= 1;
                         end

                         'd3 :
                         begin
                              for (int i = 0; i < 4; i++)
                                   clk_fifo[(3*4)+i].wr_clr <= 1;
                         end

                         'd4 :
                         begin
                              for (int i = 0; i < 4; i++)
                                   clk_fifo[(4*4)+i].wr_clr <= 1;
                         end

                         default :
                         begin
                              for (int i = 0; i < 4; i++)
                                   clk_fifo[(0*4)+i].wr_clr <= 1;
                         end
                    endcase
               end
          end
     end

// FIFO
generate
     for (i = 0; i < P_FIFOS; i++)
     begin : gen_fifo

          prt_scaler_lib_fifo_sc
          #(
               .P_VENDOR      (P_VENDOR),
               .P_MODE        ("burst"),          // "single" or "burst"
               .P_RAM_STYLE   ("block"),          // "distributed" or "block"
               .P_ADR_WIDTH   (P_FIFO_ADR),
               .P_DAT_WIDTH   (P_FIFO_DAT)
          )
          FIFO_INST
          (
               // Clocks and reset
               .RST_IN        (~clk_ctl.run),             // Reset
               .CLK_IN        (CLK_IN),               // Clock

               // Write
               .WR_EN_IN      (VID_CKE_IN),           // Write enable
               .WR_CLR_IN     (clk_fifo[i].wr_clr),   // Write clear
               .WR_IN         (clk_fifo[i].wr),       // Write in
               .DAT_IN        (clk_fifo[i].din),      // Write data

               // Read
               .RD_EN_IN      (1'b1),                 // Read enable in
               .RD_CLR_IN     (clk_fifo[i].rd_clr),   // Read clear
               .RD_IN         (clk_fifo[i].rd),       // Read in
               .DAT_OUT       (clk_fifo[i].dout),     // Data out
               .DE_OUT        (clk_fifo[i].de),       // Data enable

               // Status
               .WRDS_OUT      (clk_fifo[i].wrds),     // Used words
               .EP_OUT        (clk_fifo[i].ep),       // Empty
               .FL_OUT        (clk_fifo[i].fl)        // Full
          );
     end
endgenerate

// FIFO read clear
     always_ff @ (posedge CLK_IN)
     begin
          // Default
          for (int i = 0; i < P_FIFOS; i++)
               clk_fifo[i].rd_clr <= 0;

          // Start of frame
          if (clk_vid.vs_re)
          begin
               for (int i = 0; i < P_FIFOS; i++)
                    clk_fifo[i].rd_clr <= 1;
          end

          // Restore line
          else if (clk_lst.lrst)
          begin
               case (clk_lst.sel)
                    'd1 :
                    begin
                         for (int i = 0; i < 4; i++)
                         begin
                              clk_fifo[(1*4)+i].rd_clr <= 1;
                              clk_fifo[(2*4)+i].rd_clr <= 1;
                         end
                    end

                    'd2 :
                    begin
                         for (int i = 0; i < 4; i++)
                         begin
                              clk_fifo[(2*4)+i].rd_clr <= 1;
                              clk_fifo[(3*4)+i].rd_clr <= 1;
                         end
                    end

                    'd3 :
                    begin
                         for (int i = 0; i < 4; i++)
                         begin
                              clk_fifo[(3*4)+i].rd_clr <= 1;
                              clk_fifo[(4*4)+i].rd_clr <= 1;
                         end
                    end

                    'd4 :
                    begin
                         for (int i = 0; i < 4; i++)
                         begin
                              clk_fifo[(4*4)+i].rd_clr <= 1;
                              clk_fifo[(0*4)+i].rd_clr <= 1;
                         end
                    end

                    default :
                    begin
                         for (int i = 0; i < 4; i++)
                         begin
                              clk_fifo[(0*4)+i].rd_clr <= 1;
                              clk_fifo[(1*4)+i].rd_clr <= 1;
                         end
                    end
               endcase
          end
     end

// FIFO read
     always_ff @ (posedge CLK_IN)
     begin
          // Default
          for (int i = 0; i < P_FIFOS; i++)
               clk_fifo[i].rd <= 0;

          case (clk_lst.sel)

               'd1 : 
               begin 
                    for (int i = 0; i < 4; i++)
                    begin
                         clk_fifo[i+4].rd    <= clk_lst.rd[0][i];
                         clk_fifo[i+8].rd    <= clk_lst.rd[1][i];
                    end
               end                    

               'd2 : 
               begin 
                    for (int i = 0; i < 4; i++)
                    begin
                         clk_fifo[i+8].rd    <= clk_lst.rd[0][i];
                         clk_fifo[i+12].rd   <= clk_lst.rd[1][i];
                    end
               end                    

               'd3 : 
               begin 
                    for (int i = 0; i < 4; i++)
                    begin
                         clk_fifo[i+12].rd   <= clk_lst.rd[0][i];
                         clk_fifo[i+16].rd   <= clk_lst.rd[1][i];
                    end
               end                    

               'd4 : 
               begin 
                    for (int i = 0; i < 4; i++)
                    begin
                         clk_fifo[i+16].rd   <= clk_lst.rd[0][i];
                         clk_fifo[i+0].rd    <= clk_lst.rd[1][i];
                    end
               end                    

               default : 
               begin 
                    for (int i = 0; i < 4; i++)
                    begin
                         clk_fifo[i].rd      <= clk_lst.rd[0][i];
                         clk_fifo[i+4].rd    <= clk_lst.rd[1][i];
                    end
               end                    

          endcase
     end

// Line inputs
     always_ff @ (posedge CLK_IN)
     begin
          clk_lst.lrst   <= LST_LRST_IN;   // Restore
          clk_lst.lnxt   <= LST_LNXT_IN;   // Next
          clk_lst.rd[0]  <= LST_RD0_IN;   // Read 0
          clk_lst.rd[1]  <= LST_RD1_IN;   // Read 1
     end

// Line select
     always_ff @ (posedge CLK_IN)
     begin
          // Run
          if (clk_ctl.run)
          begin

               // Clear
               if (clk_vid.vs_re)
                    clk_lst.sel <= 0;
               
               // Next
               else if (clk_lst.lnxt)
               begin     
                    if (clk_lst.sel == P_LINES-1)
                         clk_lst.sel <= 0;
                    else 
                         clk_lst.sel <= clk_lst.sel + 'd1;
               end
          end

          else 
               clk_lst.sel <= 0;
     end

// Line data
     always_ff @ (posedge CLK_IN)
     begin
          case (clk_lst.sel)

               'd1 : 
               begin     
                    clk_lst.dat[0] <= {clk_fifo[(1*4)+3].dout, clk_fifo[(1*4)+2].dout, clk_fifo[(1*4)+1].dout, clk_fifo[(1*4)+0].dout};
                    clk_lst.dat[1] <= {clk_fifo[(2*4)+3].dout, clk_fifo[(2*4)+2].dout, clk_fifo[(2*4)+1].dout, clk_fifo[(2*4)+0].dout};
               end

               'd2 : 
               begin     
                    clk_lst.dat[0] <= {clk_fifo[(2*4)+3].dout, clk_fifo[(2*4)+2].dout, clk_fifo[(2*4)+1].dout, clk_fifo[(2*4)+0].dout};
                    clk_lst.dat[1] <= {clk_fifo[(3*4)+3].dout, clk_fifo[(3*4)+2].dout, clk_fifo[(3*4)+1].dout, clk_fifo[(3*4)+0].dout};
               end

               'd3 : 
               begin     
                    clk_lst.dat[0] <= {clk_fifo[(3*4)+3].dout, clk_fifo[(3*4)+2].dout, clk_fifo[(3*4)+1].dout, clk_fifo[(3*4)+0].dout};
                    clk_lst.dat[1] <= {clk_fifo[(4*4)+3].dout, clk_fifo[(4*4)+2].dout, clk_fifo[(4*4)+1].dout, clk_fifo[(4*4)+0].dout};
               end

               'd4 : 
               begin     
                    clk_lst.dat[0] <= {clk_fifo[(4*4)+3].dout, clk_fifo[(4*4)+2].dout, clk_fifo[(4*4)+1].dout, clk_fifo[(4*4)+0].dout};
                    clk_lst.dat[1] <= {clk_fifo[(0*4)+3].dout, clk_fifo[(0*4)+2].dout, clk_fifo[(0*4)+1].dout, clk_fifo[(0*4)+0].dout};
               end
               
               default : 
               begin     
                    clk_lst.dat[0] <= {clk_fifo[(0*4)+3].dout, clk_fifo[(0*4)+2].dout, clk_fifo[(0*4)+1].dout, clk_fifo[(0*4)+0].dout};
                    clk_lst.dat[1] <= {clk_fifo[(1*4)+3].dout, clk_fifo[(1*4)+2].dout, clk_fifo[(1*4)+1].dout, clk_fifo[(1*4)+0].dout};
               end
          endcase
     end

// Line data enable
/*
     always_ff @ (posedge CLK_IN)
     begin
          case (clk_lst.sel)

               'd1 : 
               begin
                    clk_lst.de[0] <= {clk_fifo[(1*4)+3].de, clk_fifo[(1*4)+2].de, clk_fifo[(1*4)+1].de, clk_fifo[(1*4)+0].de};
                    clk_lst.de[1] <= {clk_fifo[(2*4)+3].de, clk_fifo[(2*4)+2].de, clk_fifo[(2*4)+1].de, clk_fifo[(2*4)+0].de};
               end

               'd2 : 
               begin
                    clk_lst.de[0] <= {clk_fifo[(2*4)+3].de, clk_fifo[(2*4)+2].de, clk_fifo[(2*4)+1].de, clk_fifo[(2*4)+0].de};
                    clk_lst.de[1] <= {clk_fifo[(3*4)+3].de, clk_fifo[(3*4)+2].de, clk_fifo[(3*4)+1].de, clk_fifo[(3*4)+0].de};
               end

               'd3 : 
               begin
                    clk_lst.de[0] <= {clk_fifo[(3*4)+3].de, clk_fifo[(3*4)+2].de, clk_fifo[(3*4)+1].de, clk_fifo[(3*4)+0].de};
                    clk_lst.de[1] <= {clk_fifo[(4*4)+3].de, clk_fifo[(4*4)+2].de, clk_fifo[(4*4)+1].de, clk_fifo[(4*4)+0].de};
               end

               'd4 : 
               begin
                    clk_lst.de[0] <= {clk_fifo[(4*4)+3].de, clk_fifo[(4*4)+2].de, clk_fifo[(4*4)+1].de, clk_fifo[(4*4)+0].de};
                    clk_lst.de[1] <= {clk_fifo[(0*4)+3].de, clk_fifo[(0*4)+2].de, clk_fifo[(0*4)+1].de, clk_fifo[(0*4)+0].de};
               end

               default : 
               begin
                    clk_lst.de[0] <= {clk_fifo[(0*4)+3].de, clk_fifo[(0*4)+2].de, clk_fifo[(0*4)+1].de, clk_fifo[(0*4)+0].de};
                    clk_lst.de[1] <= {clk_fifo[(1*4)+3].de, clk_fifo[(1*4)+2].de, clk_fifo[(1*4)+1].de, clk_fifo[(1*4)+0].de};
               end
          endcase
     end
*/

// Line empty
     always_ff @ (posedge CLK_IN)
     begin
          case (clk_lst.sel)

               'd1 : 
               begin
                    clk_lst.ep[0] <= {clk_fifo[(1*4)+3].ep, clk_fifo[(1*4)+2].ep, clk_fifo[(1*4)+1].ep, clk_fifo[(1*4)+0].ep};
                    clk_lst.ep[1] <= {clk_fifo[(2*4)+3].ep, clk_fifo[(2*4)+2].ep, clk_fifo[(2*4)+1].ep, clk_fifo[(2*4)+0].ep};
                    clk_lst.ep[2] <= {clk_fifo[(3*4)+3].ep, clk_fifo[(3*4)+2].ep, clk_fifo[(3*4)+1].ep, clk_fifo[(3*4)+0].ep};
                    clk_lst.ep[3] <= {clk_fifo[(4*4)+3].ep, clk_fifo[(4*4)+2].ep, clk_fifo[(4*4)+1].ep, clk_fifo[(4*4)+0].ep};
                    clk_lst.ep[4] <= {clk_fifo[(0*4)+3].ep, clk_fifo[(0*4)+2].ep, clk_fifo[(0*4)+1].ep, clk_fifo[(0*4)+0].ep};
               end

               'd2 : 
               begin
                    clk_lst.ep[0] <= {clk_fifo[(2*4)+3].ep, clk_fifo[(2*4)+2].ep, clk_fifo[(2*4)+1].ep, clk_fifo[(2*4)+0].ep};
                    clk_lst.ep[1] <= {clk_fifo[(3*4)+3].ep, clk_fifo[(3*4)+2].ep, clk_fifo[(3*4)+1].ep, clk_fifo[(3*4)+0].ep};
                    clk_lst.ep[2] <= {clk_fifo[(4*4)+3].ep, clk_fifo[(4*4)+2].ep, clk_fifo[(4*4)+1].ep, clk_fifo[(4*4)+0].ep};
                    clk_lst.ep[3] <= {clk_fifo[(0*4)+3].ep, clk_fifo[(0*4)+2].ep, clk_fifo[(0*4)+1].ep, clk_fifo[(0*4)+0].ep};
                    clk_lst.ep[4] <= {clk_fifo[(1*4)+3].ep, clk_fifo[(1*4)+2].ep, clk_fifo[(1*4)+1].ep, clk_fifo[(1*4)+0].ep};
               end

               'd3 : 
               begin
                    clk_lst.ep[0] <= {clk_fifo[(3*4)+3].ep, clk_fifo[(3*4)+2].ep, clk_fifo[(3*4)+1].ep, clk_fifo[(3*4)+0].ep};
                    clk_lst.ep[1] <= {clk_fifo[(4*4)+3].ep, clk_fifo[(4*4)+2].ep, clk_fifo[(4*4)+1].ep, clk_fifo[(4*4)+0].ep};
                    clk_lst.ep[2] <= {clk_fifo[(0*4)+3].ep, clk_fifo[(0*4)+2].ep, clk_fifo[(0*4)+1].ep, clk_fifo[(0*4)+0].ep};
                    clk_lst.ep[3] <= {clk_fifo[(1*4)+3].ep, clk_fifo[(1*4)+2].ep, clk_fifo[(1*4)+1].ep, clk_fifo[(1*4)+0].ep};
                    clk_lst.ep[4] <= {clk_fifo[(2*4)+3].ep, clk_fifo[(2*4)+2].ep, clk_fifo[(2*4)+1].ep, clk_fifo[(2*4)+0].ep};
               end

               'd4 : 
               begin
                    clk_lst.ep[0] <= {clk_fifo[(4*4)+3].ep, clk_fifo[(4*4)+2].ep, clk_fifo[(4*4)+1].ep, clk_fifo[(4*4)+0].ep};
                    clk_lst.ep[1] <= {clk_fifo[(0*4)+3].ep, clk_fifo[(0*4)+2].ep, clk_fifo[(0*4)+1].ep, clk_fifo[(0*4)+0].ep};
                    clk_lst.ep[2] <= {clk_fifo[(1*4)+3].ep, clk_fifo[(1*4)+2].ep, clk_fifo[(1*4)+1].ep, clk_fifo[(1*4)+0].ep};
                    clk_lst.ep[3] <= {clk_fifo[(2*4)+3].ep, clk_fifo[(2*4)+2].ep, clk_fifo[(2*4)+1].ep, clk_fifo[(2*4)+0].ep};
                    clk_lst.ep[4] <= {clk_fifo[(3*4)+3].ep, clk_fifo[(3*4)+2].ep, clk_fifo[(3*4)+1].ep, clk_fifo[(3*4)+0].ep};
               end

               default : 
               begin
                    clk_lst.ep[0] <= {clk_fifo[(0*4)+3].ep, clk_fifo[(0*4)+2].ep, clk_fifo[(0*4)+1].ep, clk_fifo[(0*4)+0].ep};
                    clk_lst.ep[1] <= {clk_fifo[(1*4)+3].ep, clk_fifo[(1*4)+2].ep, clk_fifo[(1*4)+1].ep, clk_fifo[(1*4)+0].ep};
                    clk_lst.ep[2] <= {clk_fifo[(2*4)+3].ep, clk_fifo[(2*4)+2].ep, clk_fifo[(2*4)+1].ep, clk_fifo[(2*4)+0].ep};
                    clk_lst.ep[3] <= {clk_fifo[(3*4)+3].ep, clk_fifo[(3*4)+2].ep, clk_fifo[(3*4)+1].ep, clk_fifo[(3*4)+0].ep};
                    clk_lst.ep[4] <= {clk_fifo[(4*4)+3].ep, clk_fifo[(4*4)+2].ep, clk_fifo[(4*4)+1].ep, clk_fifo[(4*4)+0].ep};
               end
          endcase
     end

// Available
// These flags are set when the fifo has valid data
generate
     for (i = 0; i < P_LINES; i++)
     begin : gen_lst_av
          always_ff @ (posedge CLK_IN)
          begin
               // Run
               if (clk_ctl.run)
               begin
                    // Clear
                    if (clk_vid.vs)
                         clk_lst.av[i] <= 0;

                    // Clear
                    else if (clk_lst.lnxt && (clk_lst.sel == i))
                         clk_lst.av[i] <= 0;

                    // Set
                    else if (clk_lst.lrst && (clk_lst.sel == i))
                         clk_lst.av[i] <= 1;

                    // Set
                    else if (VID_CKE_IN && clk_vid.de_fe && (clk_vid.sel == i))
                         clk_lst.av[i] <= 1;
               end

               else
                    clk_lst.av[i] <= 0;
          end
     end
endgenerate

// Line ready
     always_ff @ (posedge CLK_IN)
     begin
          // After the last line has been received, then assert the ready
          if (clk_vid.vcnt == clk_ctl.vheight)
               clk_lst.rdy <= 1;
          
          else
          begin
               case (clk_lst.sel)
                    'd1 : clk_lst.rdy <= clk_lst.av[1] && clk_lst.av[2];
                    'd2 : clk_lst.rdy <= clk_lst.av[2] && clk_lst.av[3];
                    'd3 : clk_lst.rdy <= clk_lst.av[3] && clk_lst.av[4];
                    'd4 : clk_lst.rdy <= clk_lst.av[4] && clk_lst.av[0];
                    default : clk_lst.rdy <= clk_lst.av[0] && clk_lst.av[1];
               endcase
          end
     end

// Outputs
     assign LST_RDY_OUT   = clk_lst.rdy;
     assign LST_DAT0_OUT  = clk_lst.dat[0];
     assign LST_DAT1_OUT  = clk_lst.dat[1];

endmodule

`default_nettype wire
