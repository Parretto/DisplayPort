/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP TX Scrambler
    (c) 2021 - 2023 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Fixed issue with BS detector and scrambler reset. 
           Dropped support for non enhanced framing mode
    v1.2 - Updated interfaces
    v1.3 - Added MST support

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
module prt_dptx_scrm
#(
    parameter               P_SIM = 0,      // Simulation
    parameter               P_SPL = 2       // Symbols per lane
)
(
    // Reset and clock
    input wire              RST_IN,
    input wire              CLK_IN,

    // Control
    input wire              CTL_EN_IN,      // Enable
    input wire              CTL_MST_IN,     // MST 

    // Link 
    prt_dp_tx_lnk_if.snk    LNK_SNK_IF,     // Sink (link interface)
    prt_dp_tx_phy_if.src    LNK_SRC_IF      // Source (phy interface)
);

// Package
import prt_dp_pkg::*;

// Function
function logic [15:0] calc_lfsr (logic [15:0] lfsr_in);
	calc_lfsr[0]	= lfsr_in[8];
	calc_lfsr[1]	= lfsr_in[9];
	calc_lfsr[2]	= lfsr_in[10];
	calc_lfsr[3]	= lfsr_in[11] ^ lfsr_in[8];
	calc_lfsr[4]	= lfsr_in[12] ^ lfsr_in[9] ^ lfsr_in[8];
	calc_lfsr[5]	= lfsr_in[13] ^ lfsr_in[10] ^ lfsr_in[9] ^ lfsr_in[8];
	calc_lfsr[6]	= lfsr_in[14] ^ lfsr_in[11] ^ lfsr_in[10] ^ lfsr_in[9];
	calc_lfsr[7]	= lfsr_in[15] ^ lfsr_in[12] ^ lfsr_in[11] ^ lfsr_in[10];
	calc_lfsr[8]	= lfsr_in[0] ^ lfsr_in[13] ^ lfsr_in[12] ^ lfsr_in[11];
	calc_lfsr[9]	= lfsr_in[1] ^ lfsr_in[14] ^ lfsr_in[13] ^ lfsr_in[12];
	calc_lfsr[10]	= lfsr_in[2] ^ lfsr_in[15] ^ lfsr_in[14] ^ lfsr_in[13];
	calc_lfsr[11]	= lfsr_in[3] ^ lfsr_in[15] ^ lfsr_in[14];
	calc_lfsr[12]	= lfsr_in[4] ^ lfsr_in[15];
	calc_lfsr[13]	= lfsr_in[5];
	calc_lfsr[14]	= lfsr_in[6];
	calc_lfsr[15]	= lfsr_in[7];
endfunction

// Structures
typedef struct {
    logic                   en;
    logic                   mst;
} ctl_struct;

typedef struct {
    prt_dp_tx_lnk_sym       sym[0:P_SPL-1];
    logic [7:0]             dat[0:P_SPL-1];
    logic [2:0]             idx[0:P_SPL-1];
} snk_struct;

typedef struct {
    logic [2:0]             idx[0:P_SPL-1];
    logic [P_SPL-1:0]       sr_det;
    logic [P_SPL-1:0]       lfsr_rst;
    logic [15:0]            lfsr_in[0:P_SPL-1];
    logic [15:0]            lfsr[0:P_SPL-1];
    logic [15:0]            lfsr_reg;
    logic [7:0]             dat[0:P_SPL-1];
    } scrm_struct;

typedef struct {
    logic [8:0]             dat[0:P_SPL-1];
} src_struct;

ctl_struct  clk_ctl;
snk_struct  clk_snk;
scrm_struct clk_scrm;
src_struct  clk_src;

genvar i, j;

// Logic

// Control
    always_ff @ (posedge CLK_IN)
    begin
        clk_ctl.en  <= CTL_EN_IN;
        clk_ctl.mst <= CTL_MST_IN;
    end

// Link input
generate
    for (i = 0; i < P_SPL; i++)
    begin : gen_lnk
        assign clk_snk.sym[i] = prt_dp_tx_lnk_sym'(LNK_SNK_IF.sym[0][i]);
        assign clk_snk.dat[i] = LNK_SNK_IF.dat[0][i];
    end
endgenerate

// SR detector
    always_comb
    begin
        // Default
        clk_scrm.sr_det = 0;

        for (int i = 0; i < P_SPL; i++)
        begin
            // MST
            if (clk_ctl.mst)
            begin
                if (clk_snk.sym[i] == TX_LNK_SYM_MTPH_SR)
                    clk_scrm.sr_det[i] = 1;
            end

            // SST
            else
            begin
                if (clk_snk.sym[i] == TX_LNK_SYM_SR) 
                    clk_scrm.sr_det[i] = 1;
            end
        end
    end

// LFSR reset sublane 0
// Must be registered
    always_ff @ (posedge CLK_IN)
    begin
        // Default
        clk_scrm.lfsr_rst[0] <= 0;

        if (clk_scrm.sr_det[P_SPL-1])
            clk_scrm.lfsr_rst[0] <= 1;
    end

// LFSR reset other sublanes
// Must be combinatorial
    always_comb
    begin
        for (int i = 1; i < P_SPL; i++)
        begin : gen_lfsr_rst
            // Default
            clk_scrm.lfsr_rst[i] = 0;

            if (clk_scrm.sr_det[i-1])
                clk_scrm.lfsr_rst[i] = 1;
        end
    end

// LFSR in
    assign clk_scrm.lfsr_in[0] = clk_scrm.lfsr_reg;

generate
    for (i = 1; i < P_SPL; i++)
    begin : gen_lfsr_in
        assign clk_scrm.lfsr_in[i] = clk_scrm.lfsr[i-1];
    end
endgenerate

// LFSR
generate
    for (i = 0; i < P_SPL; i++)
    begin : gen_lfsr
        always_comb
        begin
            // Enabled
            if (clk_ctl.en)
            begin
                // Clear
                if (clk_scrm.lfsr_rst[i])
                    clk_scrm.lfsr[i] = 'hffff;
                else
                    clk_scrm.lfsr[i] = calc_lfsr(clk_scrm.lfsr_in[i]);
            end

            // Disabled
            else
                clk_scrm.lfsr[i] = 'h0000;
        end
    end
endgenerate

// LFSR register
    always_ff @ (posedge CLK_IN)
    begin
        clk_scrm.lfsr_reg <= clk_scrm.lfsr[P_SPL-1];
    end

// Scrambled data
generate
    for (i = 0; i < P_SPL; i++)
    begin
        for (j = 0; j < 8; j++)
        begin : gen_scrm_dat
            assign clk_scrm.dat[i][j] = clk_snk.dat[i][j] ^ clk_scrm.lfsr[i][15-j];
        end
    end
endgenerate

// Scrambled index
// Used in MST mode
generate
    for (i = 0; i < P_SPL; i++)
    begin : gen_scrm_idx
        assign clk_snk.idx[i]  = clk_snk.sym[i][2:0];
        assign clk_scrm.idx[i] = clk_snk.idx[i] ^ {clk_scrm.lfsr[i][13], clk_scrm.lfsr[i][14], clk_scrm.lfsr[i][15]};
    end
endgenerate

// Data output
generate
    for (i = 0; i < P_SPL; i++)
    begin : gen_dout
        always_ff @ (posedge CLK_IN)
        begin
            // MST
            if (clk_ctl.mst)
            begin
                // Scrambler reset
                if (clk_snk.sym[i] == TX_LNK_SYM_MTPH_SR)
                    clk_src.dat[i] <= P_SYM_K28_5;

                // Data
                else if ((clk_snk.sym[i] == TX_LNK_SYM_MTPH_NOP) || (clk_snk.sym[i] == TX_LNK_SYM_DAT) || (clk_snk.sym[i] == TX_LNK_SYM_NOP))
                    clk_src.dat[i] <= {1'b0, clk_scrm.dat[i]};
                
                // Control symbols
                else
                begin
                    case (clk_scrm.idx[i])
                        'd0   : clk_src.dat[i] <= P_SYM_K23_7;
                        'd1   : clk_src.dat[i] <= P_SYM_K27_7;
                        'd2   : clk_src.dat[i] <= P_SYM_K28_0;
                        'd3   : clk_src.dat[i] <= P_SYM_K28_2;
                        'd4   : clk_src.dat[i] <= P_SYM_K28_3;
                        'd5   : clk_src.dat[i] <= P_SYM_K28_6;
                        'd6   : clk_src.dat[i] <= P_SYM_K29_7;
                        'd7   : clk_src.dat[i] <= P_SYM_K30_7;
                    endcase
                end
            end

            // SST
            else
            begin
                case (clk_snk.sym[i])
                    TX_LNK_SYM_SR   : clk_src.dat[i] <= P_SYM_K28_0; //P_SYM_SR;
                    TX_LNK_SYM_BS   : clk_src.dat[i] <= P_SYM_K28_5; //P_SYM_BS;
                    TX_LNK_SYM_BE   : clk_src.dat[i] <= P_SYM_K27_7; //P_SYM_BE;
                    TX_LNK_SYM_SS   : clk_src.dat[i] <= P_SYM_K28_2; //P_SYM_SS;
                    TX_LNK_SYM_SE   : clk_src.dat[i] <= P_SYM_K29_7; //P_SYM_SE;
                    TX_LNK_SYM_FS   : clk_src.dat[i] <= P_SYM_K30_7; //P_SYM_FS;
                    TX_LNK_SYM_FE   : clk_src.dat[i] <= P_SYM_K23_7; //P_SYM_FE;
                    TX_LNK_SYM_BF   : clk_src.dat[i] <= P_SYM_K28_3; //P_SYM_BF;
                    default         : clk_src.dat[i] <= {1'b0, clk_scrm.dat[i]};
                endcase
            end
        end
    end
endgenerate

// Outputs
generate
    for (i = 0; i < P_SPL; i++)
    begin : gen_src
        assign LNK_SRC_IF.disp_ctl[0][i] = 0; // Not used
        assign LNK_SRC_IF.disp_val[0][i] = 0; // Not used
        assign {LNK_SRC_IF.k[0][i], LNK_SRC_IF.dat[0][i]} = {clk_src.dat[i]};
    end
endgenerate

    assign LNK_SNK_IF.rd = 1;

endmodule

`default_nettype wire
