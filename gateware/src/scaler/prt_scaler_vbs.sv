/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Scaler Vertical Bilineae Scaler
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

module prt_scaler_vbs
#(
     parameter P_PPC = 4,          // Pixels per clock
     parameter P_BPC = 8           // Bits per component
)
(
     // Reset and clock
     input wire                              CLK_IN,
     input wire                              CKE_IN,      

     // Control
     input wire                              CTL_RUN_IN,         // Run

     // Timing
     input wire                              VS_IN,         // Vsync
     input wire                              HS_IN,         // Hsync
     input wire                              DE_IN,         // Data enable

     // Video in
     input wire                              WR_IN,         // Write
     input wire     [(P_PPC * P_BPC)-1:0]    DAT_IN,        // Data

     // Video out
     output wire     [(P_PPC * P_BPC)-1:0]   DAT_OUT,       // Data
     output wire                             WR_OUT         // Data enable
);

// Parameters
localparam P_FIFO_WRDS = 512; // Max resolution is 1920 pixels / 4
localparam P_FIFO_ADR = $clog2(P_FIFO_WRDS);
localparam P_FIFO_DAT = P_PPC * P_BPC;

// State machine
typedef enum {
     sm_idle, sm_s0, sm_s1, sm_s2, sm_s3, sm_s4
} sm_state;

// Structure
typedef struct {
     logic [P_FIFO_DAT-1:0]        din;
     logic                         wr_en;
     logic                         wr;
     logic                         rd_en_set;
     logic                         rd_en_clr;
     logic                         rd_en;
     logic                         rd;
     logic [P_FIFO_DAT-1:0]        dout;
     logic                         de;
     logic [P_FIFO_ADR:0]          wrds;
     logic                         ep;
     logic                         fl;
} fifo_struct;

typedef struct {
     sm_state                      sm_cur;
     sm_state                      sm_nxt;
     logic                         run;
     logic                         vs_re;
     logic                         hs_re;
     logic                         de_re;
     logic                         loop_set;
     logic                         loop_clr;
     logic                         loop;
     logic [P_BPC:0]               din[0:3];
     logic [P_BPC-1:0]             dat[0:P_PPC-1];
     logic                         rd_en;
     logic                         wr_en_clr;
     logic                         wr_en_set;
     logic                         wr_en;
     logic                         wr;
} vbs_struct;

// Signals
fifo_struct    clk_fifo[0:2];
vbs_struct     clk_vbs;

genvar i;

// Logic

// Run
     always_ff @ (posedge CLK_IN)
     begin
          clk_vbs.run <= CTL_RUN_IN;
     end

// Vsync edge detector
     prt_scaler_lib_edge
     VS_EDGE_INST
     (
          .CLK_IN   (CLK_IN),        // Clock
          .CKE_IN   (1'b1),          // Clock enable
          .A_IN     (VS_IN),         // Input
          .RE_OUT   (clk_vbs.vs_re), // Rising edge
          .FE_OUT   ()               // Falling edge
     );

// Hsync edge detector
     prt_scaler_lib_edge
     HS_EDGE_INST
     (
          .CLK_IN   (CLK_IN),        // Clock
          .CKE_IN   (1'b1),          // Clock enable
          .A_IN     (HS_IN),         // Input
          .RE_OUT   (clk_vbs.hs_re), // Rising edge
          .FE_OUT   ()               // Falling edge
     );

// Data enable edge detector
     prt_scaler_lib_edge
     DE_EDGE_INST
     (
          .CLK_IN   (CLK_IN),        // Clock
          .CKE_IN   (1'b1),          // Clock enable
          .A_IN     (DE_IN),         // Input
          .RE_OUT   (clk_vbs.de_re), // Rising edge
          .FE_OUT   ()               // Falling edge
     );

// FIFO
     assign clk_fifo[0].din = DAT_IN;
     assign clk_fifo[0].wr = WR_IN;
     assign clk_fifo[0].wr_en = CKE_IN;
     assign clk_fifo[0].rd = (clk_vbs.rd_en) ? DE_IN : 0;

     assign clk_fifo[1].din = (clk_vbs.loop) ? clk_fifo[1].dout : clk_fifo[0].dout;
     assign clk_fifo[1].wr = (clk_vbs.loop) ? clk_fifo[1].de : clk_fifo[0].de;
     assign clk_fifo[1].wr_en = 1'b1;
     assign clk_fifo[1].rd = (clk_vbs.rd_en) ? DE_IN : 0;

     assign clk_fifo[2].din = clk_fifo[1].dout;
     assign clk_fifo[2].wr = clk_fifo[1].de;
     assign clk_fifo[2].wr_en = (clk_vbs.loop) ? 0 : 1;
     assign clk_fifo[2].rd = (clk_vbs.rd_en) ? DE_IN : 0;

generate
     for (i = 0; i < 3; i++)
     begin : gen_fifo
          prt_scaler_lib_fifo_sc
          #(
               .P_MODE        ("burst"),          // "single" or "burst"
               .P_RAM_STYLE   ("block"),          // "distributed" or "block"
               .P_WRDS        (P_FIFO_WRDS),
               .P_ADR_WIDTH   (P_FIFO_ADR),
               .P_DAT_WIDTH   (P_FIFO_DAT)
          )
          FIFO_INST
          (
               // Clocks and reset
               .RST_IN        (~clk_vbs.run),          // Reset
               .CLK_IN        (CLK_IN),                // Clock
               .CLR_IN        (clk_vbs.vs_re),         // Clear

               // Write
               .WR_EN_IN      (clk_fifo[i].wr_en),
               .WR_IN         (clk_fifo[i].wr),        // Write in
               .DAT_IN        (clk_fifo[i].din),       // Write data

               // Read
               .RD_EN_IN      (clk_fifo[i].rd_en),     // Read enable in
               .RD_IN         (clk_fifo[i].rd),        // Read in
               .DAT_OUT       (clk_fifo[i].dout),      // Data out
               .DE_OUT        (clk_fifo[i].de),        // Data enable

               // Status
               .WRDS_OUT      (clk_fifo[i].wrds),      // Used words
               .EP_OUT        (clk_fifo[i].ep),        // Empty
               .FL_OUT        (clk_fifo[i].fl)         // Full
          );
     end
endgenerate

// FIFO read enable
generate
     for (i = 0; i < 3; i++)
     begin : gen_fifo_rd_en
          always_ff @ (posedge CLK_IN)
          begin
               // Clear 
               if (clk_fifo[i].rd_en_clr)
                    clk_fifo[i].rd_en <= 0;

               // Set
               else if (clk_fifo[i].rd_en_set)
                    clk_fifo[i].rd_en <= 1;
          end
     end
endgenerate

// Loop Flag
// When this flag is set, the data is looped back into the middle fifo
     always_ff @ (posedge CLK_IN)
     begin
          // Clear 
          if (clk_vbs.loop_clr)
               clk_vbs.loop <= 0;

          // Set
          else if (clk_vbs.loop_set)
               clk_vbs.loop <= 1;
     end

// Read enable flag
     always_ff @ (posedge CLK_IN)
     begin
          // Toggle
          if (DE_IN)
               clk_vbs.rd_en <= ~clk_vbs.rd_en;

          // Clear
          else 
               clk_vbs.rd_en <= 1;
     end

// Write enable flag
     always_ff @ (posedge CLK_IN)
     begin
          // Clear
          if (clk_vbs.wr_en_clr)
               clk_vbs.wr_en <= 0;

          // Set
          else if (clk_vbs.wr_en_set)
               clk_vbs.wr_en <= 1;
     end

// State machine
     always_ff @ (posedge CLK_IN)
     begin
          // Run
          if (clk_vbs.run)
          begin               
               // Reset on every Vsync
               if (clk_vbs.vs_re)
                    clk_vbs.sm_cur <= sm_idle;
               else
                    clk_vbs.sm_cur <= clk_vbs.sm_nxt;
          end

          // Idle
          else
               clk_vbs.sm_cur <= sm_idle;
     end

// State machine decoder
     always_comb
     begin
          // Defaults
          clk_vbs.loop_set = 0;
          clk_vbs.loop_clr = 0;
          clk_fifo[0].rd_en_clr = 0;
          clk_fifo[1].rd_en_clr = 0;
          clk_fifo[2].rd_en_clr = 0;
          clk_fifo[0].rd_en_set = 0;
          clk_fifo[1].rd_en_set = 0;
          clk_fifo[2].rd_en_set = 0;
          clk_vbs.wr_en_clr = 0;
          clk_vbs.wr_en_set = 0;
          
          case (clk_vbs.sm_cur)

               sm_idle :
               begin
                    // Clear loop flag
                    clk_vbs.loop_clr = 1;
                    
                    // Clear fifo read enables
                    clk_fifo[0].rd_en_clr = 1;
                    clk_fifo[1].rd_en_clr = 1;
                    clk_fifo[2].rd_en_clr = 1;

                    // Disable write enable
                    clk_vbs.wr_en_clr = 1;
                    
                    // Wait for first line
                    if (clk_vbs.de_re)
                         clk_vbs.sm_nxt = sm_s0;
                    else
                         clk_vbs.sm_nxt = sm_idle;
               end

               sm_s0 :
               begin
                    // Wait for start new line
                    if (clk_vbs.hs_re)
                         clk_vbs.sm_nxt = sm_s1;
                    else
                         clk_vbs.sm_nxt = sm_s0;
               end

               sm_s1 :
               begin
                    // Wait for start new line
                    if (clk_vbs.hs_re)
                    begin
                         // Enable read on first fifo
                         clk_fifo[0].rd_en_set = 1;
                         clk_vbs.sm_nxt = sm_s2;
                    end 

                    else
                         clk_vbs.sm_nxt = sm_s1;
               end

               sm_s2 :
               begin
                    // Wait for start new line
                    if (clk_vbs.hs_re)
                    begin
                         // Disable read on first fifo
                         clk_fifo[0].rd_en_clr = 1;
                         clk_vbs.sm_nxt = sm_s3;
                    end

                    else
                         clk_vbs.sm_nxt = sm_s2;
               end

               sm_s3 :
               begin
                    // Wait for new line
                    if (clk_vbs.hs_re)
                    begin
                         // Set write enable
                         clk_vbs.wr_en_set = 1;

                         // Clear loop flag
                         clk_vbs.loop_clr = 1;

                         // Disable last fifo read
                         clk_fifo[2].rd_en_clr = 1;

                         // Enable fifo reads
                         clk_fifo[0].rd_en_set = 1;
                         clk_fifo[1].rd_en_set = 1;

                         clk_vbs.sm_nxt = sm_s4;
                    end
                    
                    else
                         clk_vbs.sm_nxt = sm_s3;
               end

               sm_s4 :
               begin
                    // Wait for new line
                    if (clk_vbs.hs_re)
                    begin
                         // Set loop flag
                         clk_vbs.loop_set = 1;

                         // Disable first fifo 
                         clk_fifo[0].rd_en_clr = 1;
                         
                         // Enable middle and last fifo read
                         clk_fifo[1].rd_en_set = 1;
                         clk_fifo[2].rd_en_set = 1;

                         clk_vbs.sm_nxt = sm_s3;
                    end

                    else
                         clk_vbs.sm_nxt = sm_s4;
               end

               default : 
               begin
                    clk_vbs.sm_nxt = sm_idle;
               end
          endcase
     end

// Data in
generate
     for (i = 0; i < 4; i++)
     begin : gen_vbs_din
          assign clk_vbs.din[i] = clk_fifo[1].dout[(i*P_BPC)+:P_BPC] + clk_fifo[2].dout[(i*P_BPC)+:P_BPC];
     end
endgenerate

// Data
     always_ff @ (posedge CLK_IN)
     begin
          if (clk_vbs.loop)
          begin
               for (int i = 0; i < P_PPC; i++)
               begin
                    // For the last line, fifo 1 doesn't have any data.
                    // Then repeat the last line (fifo 2).
                    if (clk_fifo[1].ep)
                         clk_vbs.dat[i] <= clk_fifo[2].dout[(i*P_BPC)+:P_BPC];
                    else
                         clk_vbs.dat[i] <= clk_vbs.din[i][1+:P_BPC];
               end
          end

          else
          begin
               for (int i = 0; i < P_PPC; i++)
                    clk_vbs.dat[i] <= clk_fifo[1].dout[(i*P_BPC)+:P_BPC];
          end
     end

// Write
     always_ff @ (posedge CLK_IN)
     begin
          // Write enable
          if (clk_vbs.wr_en)
               // For the last line fifo 1 is empty. 
               // The data from fifo 2 is repeated.
               clk_vbs.wr <= clk_fifo[1].de || clk_fifo[2].de;
          else
               clk_vbs.wr <= 0;
     end

// Outputs
generate
     assign WR_OUT = clk_vbs.wr;
     for (i = 0; i < P_PPC; i++)
     begin : gen_dout
          assign DAT_OUT[(i*P_BPC)+:P_BPC] = clk_vbs.dat[i];
     end
endgenerate

endmodule

`default_nettype wire
