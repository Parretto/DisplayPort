/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP RX Training - Interlane Aligner
    (c) 2026 by Parretto B.V.

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

//-----
// Module
//-----
module prt_dprx_trn_ila
#(
    // System
    parameter P_VENDOR = "none",       // Vendor - "AMD", "ALTERA" or "LSC"
    parameter P_FAMILY = "none",       // Family (Only used for Lattice)

    // Link
    parameter P_SPL = 2                // Symbols per lane
)
(
    // Reset and clock
    input wire                  RST_IN,
    input wire                  CLK_IN,

    // Config
    input wire  [2:0]           CFG_TPS_IN,         // Training pattern select

    // Trigger
    input wire                  TRG_IN,
    output wire                 TRG_OUT,

    // Link
    prt_dp_rx_lnk_if.snk        LNK_SNK_IF,         // Sink
    prt_dp_rx_lnk_if.src        LNK_SRC_IF          // Source
);


// Parameters
localparam P_RAM_WRDS = 16;
localparam P_RAM_ADR = $clog2(P_RAM_WRDS);
localparam P_RAM_DAT = 9; 
localparam P_RAM_SEL = $clog2(P_SPL);

localparam P_RAM_WP_INIT = P_RAM_WRDS/2;           // RAM write pointer initialization

localparam P_K28_0 = 'b1_000_11100;
localparam P_K28_5 = 'b1_101_11100;
localparam P_D11_6 = 'b0_110_01011;

// Structure
typedef struct {
     logic   [2:0]            tps;
} cfg_struct;

typedef struct {
     logic [P_RAM_ADR-1:0]    wp;
     logic [P_RAM_DAT-1:0]    din[P_SPL];
     logic                    wr;
     logic [P_RAM_ADR-1:0]    rp;
     logic                    rd;
     logic [P_RAM_DAT-1:0]    dout[P_SPL];
} ram_struct;

typedef struct {
     logic [P_RAM_DAT-1:0]    din[P_SPL];
     logic [P_RAM_DAT-1:0]    din_del[P_SPL];
     logic [P_RAM_DAT-1:0]    dout[P_SPL];
     logic                    trg_in;
     logic                    pre_trg;
     logic                    trg_out;
     logic                    trg_out_del;
     logic [4:0]              trg_cnt;
     logic                    trg_cnt_end;
     logic                    lock;
     logic                    slip;
} ila_struct;

// Signals
cfg_struct     clk_cfg;
ram_struct     clk_ram;
ila_struct     clk_ila;

genvar i;

// Logic

// Config
    always_ff @ (posedge CLK_IN)
    begin
        clk_cfg.tps <= CFG_TPS_IN;
    end

// Input data
generate
    for (i = 0; i < P_SPL; i++)
    begin : gen_lab_din
        assign clk_ila.din[i] = {LNK_SNK_IF.k[0][i], LNK_SNK_IF.dat[0][i]};
    end
endgenerate

// Delayed input data
// When the RAM is writting and reading from the same address simultanously, the read data is unknown. 
// The RAM read data has one clock latency. 
// This solve this condition, a bypass path is created (write through) 
// Therefore the input data must be delayed for one clock.
    always_ff @ (posedge CLK_IN)
    begin
        for (int i = 0; i < P_SPL; i++)
            clk_ila.din_del[i] <= clk_ila.din[i];
    end

// RAM write
     always_ff @ (posedge RST_IN, posedge CLK_IN)
     begin
          // Reset
          if (RST_IN)
               clk_ram.wr <= 0;

          else
          begin
               // The RAM is always writing
               clk_ram.wr <= 1;
          end
     end

// FIFO write data 
generate
    for (i = 0; i < P_SPL; i++)
    begin : gen_ram_din
        assign clk_ram.din[i] = clk_ila.din[i];
    end
endgenerate

// RAM write pointer
     always_ff @ (posedge RST_IN, posedge CLK_IN)
     begin
          // Reset
          if (RST_IN)
               clk_ram.wp <= P_RAM_WP_INIT;

          else
          begin
               // Overflow
               if (&clk_ram.wp)
                    clk_ram.wp <= 0;
               else
                    clk_ram.wp <= clk_ram.wp + 'd1;
          end
     end

// RAM
generate
     for (i = 0; i < P_SPL; i++)
     begin : gen_ram
          prt_lib_sdp_ram_sc
          #(
               .P_VENDOR           (P_VENDOR),             // Vendor - "AMD", "ALTERA" or "LSC"
               .P_FAMILY           (P_FAMILY),             // Family (Only used for Lattice)
               .P_RAM_STYLE        ("distributed"),        // "distributed", "block" or "ultra"
               .P_ADR_WIDTH        (P_RAM_ADR),
               .P_DAT_WIDTH        (P_RAM_DAT)
          )
          RAM_INST
          (
               // Port A
               .RST_IN             (RST_IN),                // Reset
               .CLK_IN             (CLK_IN),                // Clock

               // Port A
               .A_ADR_IN           (clk_ram.wp),            // Address
               .A_WR_IN            (clk_ram.wr),            // Write in
               .A_DAT_IN           (clk_ram.din[i]),        // Write data

               // Port B
               .B_EN_IN            (1'b1),                  // Enable
               .B_ADR_IN           (clk_ram.rp),            // Address
               .B_RD_IN            (clk_ram.rd),            // Read in
               .B_DAT_OUT          (clk_ram.dout[i]),       // Read data
               .B_VLD_OUT          ()                       // Read data valid
          );
     end
endgenerate

// RAM read
     always_ff @ (posedge RST_IN, posedge CLK_IN)
     begin
          // Reset
          if (RST_IN)
               clk_ram.rd <= 0;

          else
          begin
               // The RAM is always reading
               clk_ram.rd <= 1;
          end
     end

// RAM read pointer
     always_ff @ (posedge RST_IN, posedge CLK_IN)
     begin
          // Reset
          if (RST_IN)
               clk_ram.rp <= 0;
          
          else                    
          begin
               // Slip
               if (!clk_ila.slip)
               begin
                    // Overflow
                    if (&clk_ram.rp)
                         clk_ram.rp <= 0;

                    // Increment
                    else
                         clk_ram.rp <= clk_ram.rp + 'd1;
               end
          end
     end

// Output Data 
generate
     for (i = 0; i < P_SPL; i++)
     begin : gen_lab_dat
          always_comb
          begin
               // If the same address is accessed by both write and read ports, then the read data is unknown. 
               // In this case bypass the RAM. 
               if (clk_ram.wp == clk_ram.rp)
                    clk_ila.dout[i] = clk_ila.din_del[i];

               // RAM output
               else 
                    clk_ila.dout[i] = clk_ram.dout[i];
          end
     end
endgenerate

// Trigger in
     always_ff @ (posedge CLK_IN)
     begin
        clk_ila.trg_in <= TRG_IN;
     end

// Trigger out
// This process will assert the trigger during the first symbols.
// The training data is aligned (the first symbol starts in the first sublane)
generate
     // Four symbols per lane
     if (P_SPL == 4)     
     begin
          always_ff @ (posedge CLK_IN)
          begin
               // Default
               clk_ila.trg_out <= 0;    // Trigger
               clk_ila.pre_trg <= 0;    // Pre-trigger (not used in 4 spl)

               // Only generate a trigger when the trigger idle counter has expired.
               if (clk_ila.trg_cnt_end)
               begin
                    // Training pattern 2
                    if (clk_cfg.tps == 'd2)
                    begin
                         if ((clk_ila.dout[0] == P_K28_5) && (clk_ila.dout[1] == P_D11_6) && (clk_ila.dout[2] == P_K28_5) && (clk_ila.dout[3] == P_D11_6))
                              clk_ila.trg_out <= 1;
                    end

                    // Training pattern 3
                    else if (clk_cfg.tps == 'd3)
                    begin
                         if ((clk_ila.dout[0] == P_K28_5) && (clk_ila.dout[1] == P_K28_5) && (clk_ila.dout[2] == P_K28_5) && (clk_ila.dout[3] == P_K28_5))
                              clk_ila.trg_out <= 1;
                    end

                    // Training pattern 4
                    else if (clk_cfg.tps == 'd4)
                    begin
                         if ((clk_ila.dout[0] == P_K28_0) && (clk_ila.dout[1] == P_K28_5) && (clk_ila.dout[2] == P_K28_5) && (clk_ila.dout[3] == P_K28_0))
                              clk_ila.trg_out <= 1;
                    end
               end
          end
     end

     // Two symbols per lane
     else
     begin
          // This process generates the trigger in two symbols per lane. 
          // To prevent any double triggers (this occurs with TPS3) a pre-trigger is used.
          always_ff @ (posedge CLK_IN)
          begin
               // Default
               clk_ila.trg_out <= 0;    // Trigger
               clk_ila.pre_trg <= 0;    // Pre-trigger

               // Only generate a trigger when the trigger idle counter has expired.
               if (clk_ila.trg_cnt_end)
               begin
                    // Training pattern 2
                    if (clk_cfg.tps == 'd2)
                    begin
                         // Set trigger on last two symbols
                         if (clk_ila.pre_trg && (clk_ila.dout[0] == P_K28_5) && (clk_ila.dout[1] == P_D11_6))
                              clk_ila.trg_out <= 1;

                         // Set pre-trigger on first two symbols
                         else if ((clk_ila.dout[0] == P_K28_5) && (clk_ila.dout[1] == P_D11_6))
                              clk_ila.pre_trg <= 1;
                    end

                    // Training pattern 3
                    else if (clk_cfg.tps == 'd3)
                    begin
                         // Set trigger on last two symbols
                         if (clk_ila.pre_trg && (clk_ila.dout[0] == P_K28_5) && (clk_ila.dout[1] == P_K28_5))
                              clk_ila.trg_out <= 1;

                         // Set pre-trigger on first two symbols
                         else if ((clk_ila.dout[0] == P_K28_5) && (clk_ila.dout[1] == P_K28_5))
                              clk_ila.pre_trg <= 1;
                    end

                    // Training pattern 4
                    else if (clk_cfg.tps == 'd4)
                    begin
                         // Set trigger on last two symbols
                         if (clk_ila.pre_trg && (clk_ila.dout[0] == P_K28_5) && (clk_ila.dout[1] == P_K28_0))
                              clk_ila.trg_out <= 1;

                         // Set pre-trigger on first two symbols
                         else if ((clk_ila.dout[0] == P_K28_0) && (clk_ila.dout[1] == P_K28_5))
                              clk_ila.pre_trg <= 1;
                    end
               end
          end
     end
endgenerate

// Trigger out delayed
// The input and output triggers are compared.
// They must align in order for the lane to be aligned. 
// The input trigger is registered at the input, so for the comparision the internal output trigger must be delayed for one clock as well. 
     always_ff @ (posedge CLK_IN)
     begin
          clk_ila.trg_out_del <= clk_ila.trg_out;
     end

// Trigger idle counter
// The TPS2 sequence length is very short.
// This creates false triggers, because the RAM delayes the symbols. 
// To prevent this condition, this trigger idle counter is started after a trigger has generated. 
// When this counter has not expired, the trigger detector is idle. 
     always_ff @ (posedge RST_IN, posedge CLK_IN)
     begin
          // Reset
          if (RST_IN)
               clk_ila.trg_cnt <= 0;

          else
          begin
               // Load
               if (clk_ila.trg_out)
                    clk_ila.trg_cnt <= '1;

               // Decrement
               else if (!clk_ila.trg_cnt_end)
                    clk_ila.trg_cnt <= clk_ila.trg_cnt - 'd1;
          end
     end

// Trigger counter end
     always_comb
     begin
          if (clk_ila.trg_cnt == 0)
               clk_ila.trg_cnt_end = 1;
          else
               clk_ila.trg_cnt_end = 0;
     end

// Slip
     always_ff @ (posedge CLK_IN)
     begin
          // Default
          clk_ila.slip <= 0;

          // Wait for trigger in
          if (clk_ila.trg_in)
          begin
               // If the triggers are not aligned, then slip the read pointer for one clock. 
               if (!clk_ila.trg_out_del)
                    clk_ila.slip <= 1;   
          end
     end

// Lock
     always_ff @ (posedge RST_IN, posedge CLK_IN)
     begin
          // Reset
          if (RST_IN)
               clk_ila.lock <= 0;

          else
          begin
               // Set, when both triggers are aligned
               if (clk_ila.trg_in && clk_ila.trg_out_del)
                    clk_ila.lock <= 1;
          end
     end

// Outputs
assign LNK_SRC_IF.lock = clk_ila.lock; 
assign TRG_OUT = clk_ila.trg_out;

generate
    for (i = 0; i < P_SPL; i++)
    begin : src_dat
        assign {LNK_SRC_IF.k[0][i], LNK_SRC_IF.dat[0][i]} = clk_ila.dout[i];
    end
endgenerate
    

// Debug
(* syn_noprune = 1 *) wire [8:0] dbg_ila_dat0;
(* syn_noprune = 1 *) wire [8:0] dbg_ila_dat1;
(* syn_noprune = 1 *) wire [8:0] dbg_ila_dat2;
(* syn_noprune = 1 *) wire [8:0] dbg_ila_dat3;
(* syn_noprune = 1 *) wire  dbg_ila_trg_in;
(* syn_noprune = 1 *) wire  dbg_ila_trg_out;
(* syn_noprune = 1 *) wire  dbg_ila_lock;
assign dbg_ila_dat0 = clk_ila.dout[0];
assign dbg_ila_dat1 = clk_ila.dout[1];
assign dbg_ila_dat2 = clk_ila.dout[2];
assign dbg_ila_dat3 = clk_ila.dout[3];
assign dbg_ila_trg_in = clk_ila.trg_in;
assign dbg_ila_trg_out = clk_ila.trg_out;
assign dbg_ila_lock = clk_ila.lock;

endmodule

`default_nettype wire
