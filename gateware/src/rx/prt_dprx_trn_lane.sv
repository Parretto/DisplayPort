/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP RX Training Lane
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

//`default_nettype none

module prt_dprx_trn_lane
#(
    parameter                   P_SPL = 2           // Symbols per lane
)
(
    // Reset and clock
    input wire                  RST_IN,
    input wire                  CLK_IN,

    // Config
    input wire                  CFG_SET_IN,         // Set
    input wire  [2:0]           CFG_TPS_IN,         // Training pattern select

    // Status
    output wire  [15:0]         STA_MATCH_OUT,      // Match
    output wire  [7:0]          STA_ERR_OUT,        // Error

    // Link
    prt_dp_rx_lnk_if.snk        LNK_SNK_IF,         // Sink
    prt_dp_rx_lnk_if.src        LNK_SRC_IF          // Source
);

// Parameters
localparam P_K28_5 = 'b1_101_11100;
localparam P_D10_2 = 'b0_010_01010;
localparam P_D21_5 = 'b0_101_10101;
localparam P_D11_6 = 'b0_110_01011;
localparam P_D30_3 = 'b0_011_11110;
localparam P_LOCKED_THRES = 'd255;              // Locked threshold
localparam P_TPS2_SYM_WIDTH = (P_SPL == 4) ? 4 : 2;
localparam P_TPS3_SYM_WIDTH = (P_SPL == 4) ? 7 : 3;

// Structures
typedef struct {
    logic                           clr;
    logic   [2:0]                   tps;
} cfg_struct;

typedef struct {
    logic                           lock_in;          // Lock (input)
    logic                           lock;             // Training locked
    logic   [8:0]                   din[0:P_SPL-1];
    logic   [8:0]                   din_del[0:P_SPL-2];
    logic   [8:0]                   dat[0:P_SPL-1];
    logic   [1:0]                   aln_ph;
} lnk_struct;

typedef struct {
    logic                           tps1_sym;
    logic                           tps1_cnt;
    logic                           tps1_det;
    logic                           tps1_err;
    logic [P_TPS2_SYM_WIDTH-1:0]    tps2_sym;
    logic [P_TPS2_SYM_WIDTH-1:0]    tps2_sym_del;
    logic [2:0]                     tps2_cnt;
    logic                           tps2_det;
    logic                           tps2_err;
    logic [P_TPS3_SYM_WIDTH-1:0]    tps3_sym;
    logic [P_TPS3_SYM_WIDTH-1:0]    tps3_sym_del;
    logic [4:0]                     tps3_cnt;
    logic                           tps3_det;
    logic                           tps3_err;
} trn_struct;

typedef struct {
    logic   [15:0]                  match;      // Match
    logic   [7:0]                   err;        // Error
} sta_struct;

cfg_struct  clk_cfg;
sta_struct  clk_sta;
lnk_struct  clk_lnk;
trn_struct  clk_trn;

(* syn_preserve=1 *) logic [8:0] clk_dbg_dat0;
(* syn_preserve=1 *) logic [8:0] clk_dbg_dat1;
(* syn_preserve=1 *) logic [8:0] clk_dbg_dat2;
(* syn_preserve=1 *) logic [8:0] clk_dbg_dat3;

genvar i;

// Logic

/*
    Debug
*/
    always_ff @ (posedge CLK_IN)
    begin
        clk_dbg_dat0 <= clk_lnk.din[0];
        clk_dbg_dat1 <= clk_lnk.din[1];
        clk_dbg_dat2 <= clk_lnk.din[2];
        clk_dbg_dat3 <= clk_lnk.din[3];
    end


// Config
    always_ff @ (posedge CLK_IN)
    begin
        clk_cfg.clr <= CFG_SET_IN;      // A set will clear the state
        if (CFG_SET_IN)
            clk_cfg.tps <= CFG_TPS_IN;
    end

// Link input data
    always_ff @ (posedge CLK_IN)
    begin
        // Lock
        clk_lnk.lock_in <= LNK_SNK_IF.lock;

        // Data
        for (int i = 0; i < P_SPL; i++)
            clk_lnk.din[i] <= {LNK_SNK_IF.k[0][i], LNK_SNK_IF.dat[0][i]};
        
        // Data delayed
        // The data must be delayed for the alignement
        for (int i = 1; i < P_SPL; i++)
            clk_lnk.din_del[i-1] <= clk_lnk.din[i];
    end

// Input data phase detector
// The link data is word aligned by the PHY.
// However the first training pattern symbol (K28.5-) may not appear on the first sublane. 
// This process checks the input phase
generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_aln_ph_4spl    
        always_ff @ (posedge CLK_IN)
        begin
            // Clear
            // A normal phase is assumed when the training is started
            if (clk_cfg.clr && (clk_cfg.tps != 0))
                clk_lnk.aln_ph <= 0;

            // Training pattern 2
            else if ((clk_cfg.tps == 'd2) && (clk_trn.tps2_cnt == 0))
            begin
                // Phase 1
                // Training start in sublane 1
                if ((clk_lnk.din[0] == P_D10_2) && (clk_lnk.din[1] == P_K28_5) && (clk_lnk.din[2] == P_D11_6) && (clk_lnk.din[3] == P_K28_5))
                    clk_lnk.aln_ph <= 'd1;

                // Phase 2
                // Training start in sublane 2
                else if ((clk_lnk.din[0] == P_D10_2) && (clk_lnk.din[1] == P_D10_2) && (clk_lnk.din[2] == P_K28_5) && (clk_lnk.din[3] == P_D11_6))
                    clk_lnk.aln_ph <= 'd2;

                // Phase 3
                // Training start in sublane 3
                else if ((clk_lnk.din[0] == P_D10_2) && (clk_lnk.din[1] == P_D10_2) && (clk_lnk.din[2] == P_D10_2) && (clk_lnk.din[3] == P_K28_5))
                    clk_lnk.aln_ph <= 'd3;
            end

            // Training pattern 3
            else if ((clk_cfg.tps == 'd3) && (clk_trn.tps3_cnt == 0))
            begin
                // Phase 1
                // Training start in sublane 1
                if ((clk_lnk.din[0] == P_D30_3) && (clk_lnk.din[1] == P_K28_5) && (clk_lnk.din[2] == P_K28_5) && (clk_lnk.din[3] == P_K28_5))
                    clk_lnk.aln_ph <= 'd1;

                // Phase 2
                // Training start in sublane 2
                else if ((clk_lnk.din[0] == P_D30_3) && (clk_lnk.din[1] == P_D30_3) && (clk_lnk.din[2] == P_K28_5) && (clk_lnk.din[3] == P_K28_5))
                    clk_lnk.aln_ph <= 'd2;

                // Phase 3
                // Training start in sublane 3
                else if ((clk_lnk.din[0] == P_D30_3) && (clk_lnk.din[1] == P_D30_3) && (clk_lnk.din[2] == P_D30_3) && (clk_lnk.din[3] == P_K28_5))
                    clk_lnk.aln_ph <= 'd3;
            end
        end
    end

    // Two symbols per lane
    else
    begin : gen_aln_ph_2spl
        always_ff @ (posedge CLK_IN)
        begin
            // Clear
            // A normal phase is assumed when the training is started
            if (clk_cfg.clr && (clk_cfg.tps != 0))
                clk_lnk.aln_ph <= 0;

            // Training pattern 2
            else if ((clk_cfg.tps == 'd2) && (clk_trn.tps2_cnt == 0))
            begin
                // Phase 1
                // Training starts in sublane 1
                if ((clk_lnk.din[0] == P_D10_2) && (clk_lnk.din[1] == P_K28_5))
                    clk_lnk.aln_ph <= 'd1;
            end

            // Training pattern 3
            else if ((clk_cfg.tps == 'd3) && (clk_trn.tps3_cnt == 0))
            begin
                // Phase 1
                // Training starts in sublane 1
                if ((clk_lnk.din[0] == P_D30_3) && (clk_lnk.din[1] == P_K28_5))
                    clk_lnk.aln_ph <= 'd1;
            end
        end
    end
endgenerate

// Aligner
generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_aln_4spl    
        always_comb
        begin
            case (clk_lnk.aln_ph)
                
                // Phase 1
                'd1 :
                begin
                    clk_lnk.dat[0] = clk_lnk.din_del[0]; 
                    clk_lnk.dat[1] = clk_lnk.din_del[1]; 
                    clk_lnk.dat[2] = clk_lnk.din_del[2]; 
                    clk_lnk.dat[3] = clk_lnk.din[0]; 
                end

                // Phase 2
                'd2 :
                begin
                    clk_lnk.dat[0] = clk_lnk.din_del[1]; 
                    clk_lnk.dat[1] = clk_lnk.din_del[2]; 
                    clk_lnk.dat[2] = clk_lnk.din[0]; 
                    clk_lnk.dat[3] = clk_lnk.din[1]; 
                end

                // Phase 3
                'd3 :
                begin
                    clk_lnk.dat[0] = clk_lnk.din_del[2]; 
                    clk_lnk.dat[1] = clk_lnk.din[0]; 
                    clk_lnk.dat[2] = clk_lnk.din[1]; 
                    clk_lnk.dat[3] = clk_lnk.din[2]; 
                end

                // Phase 0
                default : 
                begin
                    clk_lnk.dat[0] = clk_lnk.din[0]; 
                    clk_lnk.dat[1] = clk_lnk.din[1]; 
                    clk_lnk.dat[2] = clk_lnk.din[2]; 
                    clk_lnk.dat[3] = clk_lnk.din[3]; 
                end
            endcase
        end
    end

    // Two symbols per lane
    else
    begin : gen_aln_2spl
        always_comb
        begin
            // Phase 1
            if (clk_lnk.aln_ph == 'd1)
            begin
                clk_lnk.dat[0] = clk_lnk.din_del[0]; 
                clk_lnk.dat[1] = clk_lnk.din[0]; 
            end

            // Phase 0
            else
            begin
                clk_lnk.dat[0] = clk_lnk.din[0]; 
                clk_lnk.dat[1] = clk_lnk.din[1]; 
            end
        end
    end
endgenerate

// TPS1 symbol
// This signal is asserted when the TPS1 symbols (D10.2 & D10.2) are detected
generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_ts1_sym_4spl    
        always_comb
        begin
            if ((clk_lnk.dat[0] == P_D10_2) && (clk_lnk.dat[1] == P_D10_2) && (clk_lnk.dat[2] == P_D10_2) && (clk_lnk.dat[3] == P_D10_2))
                clk_trn.tps1_sym = 1;
            
            // During the first training the incoming data might not be aligned to a word boundary.
            // Therefore we need to check for the shifted pattern as well.
            else if ((clk_lnk.dat[0] == P_D21_5) && (clk_lnk.dat[1] == P_D21_5) && (clk_lnk.dat[2] == P_D21_5) && (clk_lnk.dat[3] == P_D21_5))
                clk_trn.tps1_sym = 1;

            else
                clk_trn.tps1_sym = 0;
        end
    end

    // Two symbols per lane
    else
    begin : gen_ts1_sym_2spl
        always_comb
        begin
            if ((clk_lnk.dat[0] == P_D10_2) && (clk_lnk.dat[1] == P_D10_2))
                clk_trn.tps1_sym = 1;
            
            // During the first training the incoming data might not be aligned to a word boundary.
            // Therefore we need to check for the shifted pattern as well.
            else if ((clk_lnk.dat[0] == P_D21_5) && (clk_lnk.dat[1] == P_D21_5))
                clk_trn.tps1_sym = 1;

            else
                clk_trn.tps1_sym = 0;
        end    
    end
endgenerate

// TPS1 detector
    always_ff @ (posedge CLK_IN)
    begin
        // Lock
        if (clk_lnk.lock_in)
        begin
            // Clear
            if (clk_cfg.clr)
                clk_trn.tps1_cnt <= 0;

            else
            begin
                // Default
                clk_trn.tps1_det <= 0;
                clk_trn.tps1_err <= 0;
                clk_trn.tps1_cnt <= 'd0;

                // TPS1 selected
                if (clk_cfg.tps == 'd1)
                begin
                    case (clk_trn.tps1_cnt)
                        'd1 :
                        begin
                            if (clk_trn.tps1_sym)
                            begin
                                clk_trn.tps1_det <= 1;
                                clk_trn.tps1_cnt <= 'd1;
                            end

                            else
                            begin
                                clk_trn.tps1_err <= 1;
                                clk_trn.tps1_cnt <= 'd0;
                            end
                        end

                        default :
                        begin
                            if (clk_trn.tps1_sym)
                                clk_trn.tps1_cnt <= 'd1;
                            else
                                clk_trn.tps1_cnt <= 'd0;
                        end
                    endcase
                end
            end
        end

        // Not locked
        else
            clk_trn.tps1_cnt <= 0;
    end

// TPS2 detector
generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_tps2_4spl
    
    // TPS2 symbol 0
    // This signal is asserted when the TPS2 this group of symbols (K28.5, D11.6, K28.5, D11.6) are detected
        always_comb
        begin
            if ((clk_lnk.dat[0] == P_K28_5) && (clk_lnk.dat[1] == P_D11_6) && (clk_lnk.dat[2] == P_K28_5) && (clk_lnk.dat[3] == P_D11_6))
                clk_trn.tps2_sym[0] = 1;
            else
                clk_trn.tps2_sym[0] = 0;
        end

    // TPS2 symbol 1
    // This signal is asserted when the TPS2 this group of symbols (D10.2, D10.2, D10.2, D10.2) are detected
        always_comb
        begin
            if ((clk_lnk.dat[0] == P_D10_2) && (clk_lnk.dat[1] == P_D10_2) && (clk_lnk.dat[2] == P_D10_2) && (clk_lnk.dat[3] == P_D10_2))
                clk_trn.tps2_sym[1] = 1;
            else
                clk_trn.tps2_sym[1] = 0;
        end

    // TPS2 symbol 2
    // This signal is asserted when the TPS2 this group of symbols (D10.2, D10.2, K28.5, D11.6) are detected
        always_comb
        begin
            if ((clk_lnk.dat[0] == P_D10_2) && (clk_lnk.dat[1] == P_D10_2) && (clk_lnk.dat[2] == P_K28_5) && (clk_lnk.dat[3] == P_D11_6))
                clk_trn.tps2_sym[2] = 1;
            else
                clk_trn.tps2_sym[2] = 0;
        end

    // TPS2 symbol 3
    // This signal is asserted when the TPS2 this group of symbols (K28.5, D11.6, D10.2, D10.2) are detected
        always_comb
        begin
            if ((clk_lnk.dat[0] == P_K28_5) && (clk_lnk.dat[1] == P_D11_6) && (clk_lnk.dat[2] == P_D10_2) && (clk_lnk.dat[3] == P_D10_2))
                clk_trn.tps2_sym[3] = 1;
            else
                clk_trn.tps2_sym[3] = 0;
        end

    // TPS2 detector
        always_ff @ (posedge CLK_IN)
        begin
            // Lock
            if (clk_lnk.lock_in)
            begin
                // Clear
                if (clk_cfg.clr)
                    clk_trn.tps2_cnt <= 0;

                else
                begin
                    // Default
                    clk_trn.tps2_det <= 0;
                    clk_trn.tps2_err <= 0;
                    clk_trn.tps2_cnt <= 'd0;

                    // TPS2 selected
                    if (clk_cfg.tps == 'd2)
                    begin
                        case (clk_trn.tps2_cnt)
                            'd0 :
                            begin
                                if (clk_trn.tps2_sym[0])
                                    clk_trn.tps2_cnt <= 'd1;
                                else
                                    clk_trn.tps2_cnt <= 'd0;
                            end

                            'd1 :
                            begin
                                if (clk_trn.tps2_sym[1])
                                    clk_trn.tps2_cnt <= 'd2;
                                else
                                begin
                                    clk_trn.tps2_err <= 1;
                                    clk_trn.tps2_cnt <= 'd0;
                                end
                            end

                            'd2 :
                            begin
                                if (clk_trn.tps2_sym[2])
                                    clk_trn.tps2_cnt <= 'd3;
                                else
                                begin
                                    clk_trn.tps2_err <= 1;
                                    clk_trn.tps2_cnt <= 'd0;
                                end
                            end

                            'd3 :
                            begin
                                if (clk_trn.tps2_sym[3])
                                    clk_trn.tps2_cnt <= 'd4;
                                else
                                begin
                                    clk_trn.tps2_err <= 1;
                                    clk_trn.tps2_cnt <= 'd0;
                                end
                            end

                            'd4 :
                            begin
                                if (clk_trn.tps2_sym[1])
                                    clk_trn.tps2_det <= 1;
                                else
                                    clk_trn.tps2_err <= 1;

                                clk_trn.tps2_cnt <= 'd0;
                            end

                            default : ;
                        endcase
                    end
                end
            end

            // Not locked
            else
            begin
                clk_trn.tps2_det <= 0;
                clk_trn.tps2_err <= 0;
                clk_trn.tps2_cnt <= 'd0;
            end
        end
    end

    // Two symbols per lane
    else
    begin : gen_tps2_2spl
    
    // TPS2 symbol 0
    // This signal is asserted when the TPS2 this group of symbols (K28.5 & D11.6) are detected
        always_comb
        begin
            if ((clk_lnk.dat[0] == P_K28_5) && (clk_lnk.dat[1] == P_D11_6))
                clk_trn.tps2_sym[0] = 1;
            else
                clk_trn.tps2_sym[0] = 0;
        end

    // TPS2 symbol 1
    // This signal is asserted when the TPS2 this group of symbols (D10.2 & D10.2) are detected
        always_comb
        begin
            if ((clk_lnk.dat[0] == P_D10_2) && (clk_lnk.dat[1] == P_D10_2))
                clk_trn.tps2_sym[1] = 1;
            else
                clk_trn.tps2_sym[1] = 0;
        end

    // TPS2 symbol delayed
        always_ff @ (posedge CLK_IN)
        begin
            clk_trn.tps2_sym_del <= clk_trn.tps2_sym;
        end

    // TPS2 detector
        always_ff @ (posedge CLK_IN)
        begin
            // Lock
            if (clk_lnk.lock_in)
            begin
                // Clear
                if (clk_cfg.clr)
                    clk_trn.tps2_cnt <= 0;

                else
                begin
                    // Default
                    clk_trn.tps2_det <= 0;
                    clk_trn.tps2_err <= 0;
                    clk_trn.tps2_cnt <= 'd0;

                    // TPS2 selected
                    if (clk_cfg.tps == 'd2)
                    begin
                        case (clk_trn.tps2_cnt)
                            'd0 :
                            begin
                                if (clk_trn.tps2_sym[0] && clk_trn.tps2_sym_del[1])
                                    clk_trn.tps2_cnt <= 'd1;
                                else
                                    clk_trn.tps2_cnt <= 'd0;
                            end

                            'd1 :
                            begin
                                if (clk_trn.tps2_sym[0])
                                    clk_trn.tps2_cnt <= 'd2;
                                else
                                begin
                                    clk_trn.tps2_err <= 1;
                                    clk_trn.tps2_cnt <= 'd0;
                                end
                            end

                            'd2 :
                            begin
                                if (clk_trn.tps2_sym[1])
                                    clk_trn.tps2_cnt <= 'd3;
                                else
                                begin
                                    clk_trn.tps2_err <= 1;
                                    clk_trn.tps2_cnt <= 'd0;
                                end
                            end

                            'd3 :
                            begin
                                if (clk_trn.tps2_sym[1])
                                    clk_trn.tps2_cnt <= 'd4;
                                else
                                begin
                                    clk_trn.tps2_err <= 1;
                                    clk_trn.tps2_cnt <= 'd0;
                                end
                            end

                            'd4 :
                            begin
                                if (clk_trn.tps2_sym[1])
                                    clk_trn.tps2_det <= 1;
                                else
                                    clk_trn.tps2_err <= 1;

                                clk_trn.tps2_cnt <= 'd0;
                            end

                            default : ;
                        endcase
                    end
                end
            end

            // Not locked
            else
            begin
                clk_trn.tps2_det <= 0;
                clk_trn.tps2_err <= 0;
                clk_trn.tps2_cnt <= 'd0;
            end
        end
    end    
endgenerate

// TPS3 detector
generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_tps3_4spl

    // TPS3 symbol 0
    // This signal is asserted when the TPS3 this group of symbols (K28.5, K28.5, K28.5, K28.5) are detected
        always_comb
        begin
            if ((clk_lnk.dat[0] == P_K28_5) && (clk_lnk.dat[1] == P_K28_5) && (clk_lnk.dat[2] == P_K28_5) && (clk_lnk.dat[3] == P_K28_5))
                clk_trn.tps3_sym[0] = 1;
            else
                clk_trn.tps3_sym[0] = 0;
        end

    // TPS3 symbol 1
    // This signal is asserted when the TPS3 this group of symbols (D10.2, D10.2, D10.2, D10.2) are detected
        always_comb
        begin
            if ((clk_lnk.dat[0] == P_D10_2) && (clk_lnk.dat[1] == P_D10_2) && (clk_lnk.dat[2] == P_D10_2) && (clk_lnk.dat[3] == P_D10_2))
                clk_trn.tps3_sym[1] = 1;
            else
                clk_trn.tps3_sym[1] = 0;
        end

    // TPS3 symbol 2
    // This signal is asserted when the TPS3 this group of symbols (K28.5, K28.5, D30.3, D30.3) are detected
        always_comb
        begin
            if ((clk_lnk.dat[0] == P_K28_5) && (clk_lnk.dat[1] == P_K28_5) && (clk_lnk.dat[2] == P_D30_3) && (clk_lnk.dat[3] == P_D30_3))
                clk_trn.tps3_sym[2] = 1;
            else
                clk_trn.tps3_sym[2] = 0;
        end

    // TPS3 symbol 3
    // This signal is asserted when the TPS3 this group of symbols (D30.3, D30.3, D30.3, D30.3) are detected
        always_comb
        begin
            if ((clk_lnk.dat[0] == P_D30_3) && (clk_lnk.dat[1] == P_D30_3) && (clk_lnk.dat[2] == P_D30_3) && (clk_lnk.dat[3] == P_D30_3))
                clk_trn.tps3_sym[3] = 1;
            else
                clk_trn.tps3_sym[3] = 0;
        end

    // TPS3 symbol 4
    // This signal is asserted when the TPS3 this group of symbols (D30.3, D30.3, K28.5, K28.5) are detected
        always_comb
        begin
            if ((clk_lnk.dat[0] == P_D30_3) && (clk_lnk.dat[1] == P_D30_3) && (clk_lnk.dat[2] == P_K28_5) && (clk_lnk.dat[3] == P_K28_5))
                clk_trn.tps3_sym[4] = 1;
            else
                clk_trn.tps3_sym[4] = 0;
        end

    // TPS3 symbol 5
    // This signal is asserted when the TPS3 this group of symbols (K28.5, K28.5, D10_2, D10_2) are detected
        always_comb
        begin
            if ((clk_lnk.dat[0] == P_K28_5) && (clk_lnk.dat[1] == P_K28_5) && (clk_lnk.dat[2] == P_D10_2) && (clk_lnk.dat[3] == P_D10_2))
                clk_trn.tps3_sym[5] = 1;
            else
                clk_trn.tps3_sym[5] = 0;
        end

    // TPS3 symbol 6
    // This signal is asserted when the TPS3 this group of symbols (D10_2, D10_2, K28.5, K28.5) are detected
        always_comb
        begin
            if ((clk_lnk.dat[0] == P_D10_2) && (clk_lnk.dat[1] == P_D10_2) && (clk_lnk.dat[2] == P_K28_5) && (clk_lnk.dat[3] == P_K28_5))
                clk_trn.tps3_sym[6] = 1;
            else
                clk_trn.tps3_sym[6] = 0;
        end

    // TPS3 detector
        always_ff @ (posedge CLK_IN)
        begin
            // Locked
            if (clk_lnk.lock_in)
            begin
                // Clear
                if (clk_cfg.clr)
                    clk_trn.tps3_cnt <= 0;

                else
                begin
                    // Default
                    clk_trn.tps3_det <= 0;
                    clk_trn.tps3_err <= 0;
                    clk_trn.tps3_cnt <= 'd0;

                    // TPS3 selected
                    if (clk_cfg.tps == 'd3)
                    begin
                        case (clk_trn.tps3_cnt)
                            'd0 :
                            begin
                                if (clk_trn.tps3_sym[0])
                                    clk_trn.tps3_cnt <= 'd1;
                                else
                                    clk_trn.tps3_cnt <= 'd0;
                            end

                            'd1 :
                            begin
                                if (clk_trn.tps3_sym[1])
                                    clk_trn.tps3_cnt <= 'd2;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd2 :
                            begin
                                if (clk_trn.tps3_sym[1])
                                    clk_trn.tps3_cnt <= 'd3;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd3 :
                            begin
                                if (clk_trn.tps3_sym[2])
                                    clk_trn.tps3_cnt <= 'd4;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd4 :
                            begin
                                if (clk_trn.tps3_sym[3])
                                    clk_trn.tps3_cnt <= 'd5;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd5 :
                            begin
                                if (clk_trn.tps3_sym[3])
                                    clk_trn.tps3_cnt <= 'd6;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd6 :
                            begin
                                if (clk_trn.tps3_sym[3])
                                    clk_trn.tps3_cnt <= 'd7;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd7 :
                            begin
                                if (clk_trn.tps3_sym[3])
                                    clk_trn.tps3_cnt <= 'd8;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd8 :
                            begin
                                if (clk_trn.tps3_sym[4])
                                    clk_trn.tps3_cnt <= 'd9;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd9 :
                            begin
                                if (clk_trn.tps3_sym[5])
                                    clk_trn.tps3_cnt <= 'd10;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd10 :
                            begin
                                if (clk_trn.tps3_sym[1])
                                    clk_trn.tps3_cnt <= 'd11;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd11 :
                            begin
                                if (clk_trn.tps3_sym[6])
                                    clk_trn.tps3_cnt <= 'd12;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd12 :
                            begin
                                if (clk_trn.tps3_sym[3])
                                    clk_trn.tps3_cnt <= 'd13;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd13 :
                            begin
                                if (clk_trn.tps3_sym[3])
                                    clk_trn.tps3_cnt <= 'd14;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd14 :
                            begin
                                if (clk_trn.tps3_sym[3])
                                    clk_trn.tps3_cnt <= 'd15;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd15 :
                            begin
                                if (clk_trn.tps3_sym[3])
                                    clk_trn.tps3_cnt <= 'd16;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd16 :
                            begin
                                if (clk_trn.tps3_sym[3])
                                    clk_trn.tps3_det <= 1;
                                else
                                    clk_trn.tps3_err <= 1;
                                clk_trn.tps3_cnt <= 'd0;
                            end

                            default : ;
                        endcase
                    end
                end
            end

            // Not locked
            else
            begin
                clk_trn.tps3_det <= 0;
                clk_trn.tps3_err <= 0;
                clk_trn.tps3_cnt <= 'd0;
            end
        end
    end

    // Two symbols per lane
    else
    begin : gen_tps3_2spl
    // TPS3 symbol 0
    // This signal is asserted when the TPS3 this group of symbols (K28.5 & K28.5) are detected
        always_comb
        begin
            if ((clk_lnk.dat[0] == P_K28_5) && (clk_lnk.dat[1] == P_K28_5))
                clk_trn.tps3_sym[0] = 1;
            else
                clk_trn.tps3_sym[0] = 0;
        end

    // TPS3 symbol 1
    // This signal is asserted when the TPS3 this group of symbols (D10.2 & D10.2) are detected
        always_comb
        begin
            if ((clk_lnk.dat[0] == P_D10_2) && (clk_lnk.dat[1] == P_D10_2))
                clk_trn.tps3_sym[1] = 1;
            else
                clk_trn.tps3_sym[1] = 0;
        end

    // TPS3 symbol 2
    // This signal is asserted when the TPS3 this group of symbols (D30.3 & D30.3) are detected
        always_comb
        begin
            if ((clk_lnk.dat[0] == P_D30_3) && (clk_lnk.dat[1] == P_D30_3))
                clk_trn.tps3_sym[2] = 1;
            else
                clk_trn.tps3_sym[2] = 0;
        end

    // TPS3 symbol delayed
        always_ff @ (posedge CLK_IN)
        begin
            clk_trn.tps3_sym_del <= clk_trn.tps3_sym;
        end

    // TPS3 detector
        always_ff @ (posedge CLK_IN)
        begin
            // Locked
            if (clk_lnk.lock_in)
            begin
                // Clear
                if (clk_cfg.clr)
                    clk_trn.tps3_cnt <= 0;

                else
                begin
                    // Default
                    clk_trn.tps3_det <= 0;
                    clk_trn.tps3_err <= 0;
                    clk_trn.tps3_cnt <= 'd0;

                    // TPS3 selected
                    if (clk_cfg.tps == 'd3)
                    begin
                        case (clk_trn.tps3_cnt)
                            'd0 :
                            begin
                                if (clk_trn.tps3_sym[0] && clk_trn.tps3_sym_del[2])
                                    clk_trn.tps3_cnt <= 'd1;
                                else
                                    clk_trn.tps3_cnt <= 'd0;
                            end

                            'd1 :
                            begin
                                if (clk_trn.tps3_sym[0])
                                    clk_trn.tps3_cnt <= 'd2;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd2 :
                            begin
                                if (clk_trn.tps3_sym[1])
                                    clk_trn.tps3_cnt <= 'd3;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd3 :
                            begin
                                if (clk_trn.tps3_sym[1])
                                    clk_trn.tps3_cnt <= 'd4;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd4 :
                            begin
                                if (clk_trn.tps3_sym[1])
                                    clk_trn.tps3_cnt <= 'd5;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd5 :
                            begin
                                if (clk_trn.tps3_sym[1])
                                    clk_trn.tps3_cnt <= 'd6;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd6 :
                            begin
                                if (clk_trn.tps3_sym[0])
                                    clk_trn.tps3_cnt <= 'd7;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd7 :
                            begin
                                if (clk_trn.tps3_sym[2])
                                    clk_trn.tps3_cnt <= 'd8;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd8 :
                            begin
                                if (clk_trn.tps3_sym[2])
                                    clk_trn.tps3_cnt <= 'd9;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd9 :
                            begin
                                if (clk_trn.tps3_sym[2])
                                    clk_trn.tps3_cnt <= 'd10;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd10 :
                            begin
                                if (clk_trn.tps3_sym[2])
                                    clk_trn.tps3_cnt <= 'd11;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd11 :
                            begin
                                if (clk_trn.tps3_sym[2])
                                    clk_trn.tps3_cnt <= 'd12;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd12 :
                            begin
                                if (clk_trn.tps3_sym[2])
                                    clk_trn.tps3_cnt <= 'd13;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd13 :
                            begin
                                if (clk_trn.tps3_sym[2])
                                    clk_trn.tps3_cnt <= 'd14;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd14 :
                            begin
                                if (clk_trn.tps3_sym[2])
                                    clk_trn.tps3_cnt <= 'd15;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd15 :
                            begin
                                if (clk_trn.tps3_sym[2])
                                    clk_trn.tps3_cnt <= 'd16;
                                else
                                begin
                                    clk_trn.tps3_err <= 1;
                                    clk_trn.tps3_cnt <= 'd0;
                                end
                            end

                            'd16 :
                            begin
                                if (clk_trn.tps3_sym[2])
                                    clk_trn.tps3_det <= 1;
                                else
                                    clk_trn.tps3_err <= 1;
                                clk_trn.tps3_cnt <= 'd0;
                            end

                            default : ;
                        endcase
                    end
                end
            end

            // Not locked
            else
            begin
                clk_trn.tps3_det <= 0;
                clk_trn.tps3_err <= 0;
                clk_trn.tps3_cnt <= 'd0;
            end
        end
    end
endgenerate

// Matches
    always_ff @ (posedge RST_IN, posedge CLK_IN)
    begin
        // Reset
        if (RST_IN)
            clk_sta.match <= 0;

        else
        begin
            // Lock
            if (clk_lnk.lock_in)
            begin
                // Clear
                // When any training pattern is selected
                if (clk_cfg.clr && (clk_cfg.tps != 0))
                    clk_sta.match <= 0;

                // Increment
                else if (clk_trn.tps1_det || clk_trn.tps2_det || clk_trn.tps3_det)
                begin
                    // Don't roll over when the maximum value is reached
                    if (!(&clk_sta.match))
                        clk_sta.match <= clk_sta.match + 'd1;
                end
            end

            // Not locked
            else
                clk_sta.match <= 0;
        end
    end

// Errors
    always_ff @ (posedge RST_IN, posedge CLK_IN)
    begin
        // Reset
        if (RST_IN)
            clk_sta.err <= 0;

        else
        begin
            // Lock
            if (clk_lnk.lock_in)
            begin
                // Clear
                // When any training pattern is selected
                if (clk_cfg.clr && (clk_cfg.tps != 0))
                    clk_sta.err <= 0;

                // Increment
                else if (clk_trn.tps1_err || clk_trn.tps2_err || clk_trn.tps3_err)
                begin
                    // Don't roll over when the maximum value is reached
                    if (!(&clk_sta.err))
                        clk_sta.err <= clk_sta.err + 'd1;
                end
            end

            // Not locked
            else
                clk_sta.err <= 0;
        end
    end

// Locked
    always_ff @ (posedge RST_IN, posedge CLK_IN)
    begin
        // Reset
        if (RST_IN)
            clk_lnk.lock <= 0;

        else
        begin
            // Lock
            if (clk_lnk.lock_in)
            begin
                // Clear
                // When any training pattern is selected
                if (clk_cfg.clr && (clk_cfg.tps != 0))
                    clk_lnk.lock <= 0;

                // Set
                else if (((clk_cfg.tps == 'd2) || (clk_cfg.tps == 'd3)) && (clk_sta.match > P_LOCKED_THRES))
                    clk_lnk.lock <= 1;
            end

            // Not locked
            else
                clk_lnk.lock <= 0;
        end
    end

// Outputs
    generate
        for (i = 0; i < P_SPL; i++)
        begin : gen_lnk_src
            // Passtrough data
            assign {LNK_SRC_IF.k[0][i], LNK_SRC_IF.dat[0][i]} = clk_lnk.din[i];
        end
    endgenerate
    assign LNK_SRC_IF.lock    = clk_lnk.lock;
    assign LNK_SRC_IF.sol[0]  = 0;  // Not used
    assign LNK_SRC_IF.eol[0]  = 0;  // Not used
    assign LNK_SRC_IF.vid[0]  = 0;  // Not used
    assign LNK_SRC_IF.sec[0]  = 0;  // Not used
    assign LNK_SRC_IF.msa[0]  = 0;  // Not used
    assign LNK_SRC_IF.vbid[0] = 0;  // Not used
    assign STA_MATCH_OUT      = clk_sta.match;
    assign STA_ERR_OUT        = clk_sta.err;

endmodule

`default_nettype wire
