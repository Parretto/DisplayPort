/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP TX Scrambler
    (c) 2021, 2022 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Fixed issue with BS detector and scrambler reset. 
           Dropped support for non enhanced framing mode


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
    input wire              CTL_EN_IN,     // Enable
    input wire              CTL_EFM_IN,    // Enhanced framing mode

    // Link 
    prt_dp_tx_lnk_if.snk    LNK_SNK_IF,     // Sink
    prt_dp_tx_lnk_if.src    LNK_SRC_IF      // Source
);

// Package
import prt_dp_pkg::*;

// Localparam
localparam P_BS_CNT_MAX = P_SIM ? 10 : 512;

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

// Signals
logic                  clk_en;
logic                  clk_efm;
logic [P_SPL-1:0]      clk_disp_ctl;
logic [P_SPL-1:0]      clk_disp_val;
logic [8:0]            clk_din[0:P_SPL-1];
logic [8:0]            clk_dat[0:P_SPL-1];
logic [P_SPL-1:0]      clk_bs_det;
logic [P_SPL-1:0]      clk_bs_det_del[0:1];
logic                  clk_bs_cnt_inc;
logic [9:0]            clk_bs_cnt;
logic                  clk_bs_cnt_end;
logic [P_SPL-1:0]      clk_ins_sr;
logic [P_SPL-1:0]      clk_lfsr_rst;
logic [15:0]           clk_lfsr_in[0:P_SPL-1];
logic [15:0]           clk_lfsr[0:P_SPL-1];
logic [15:0]           clk_lfsr_reg;
logic [8:0]            clk_dout[0:P_SPL-1];

genvar i;

// Logic

// Control
    always_ff @ (posedge CLK_IN)
    begin
        clk_en  <= CTL_EN_IN;
        clk_efm <= CTL_EFM_IN;
    end

// Input registers
generate
    for (i = 0; i < P_SPL; i++)
    begin : gen_din
        assign clk_din[i] = {LNK_SNK_IF.k[0][i], LNK_SNK_IF.dat[0][i]};
    end
endgenerate

// Disparity registers
// The scrambler has one clock latency. 
// These registers compensate for the scrambler latency
    always_ff @ (posedge CLK_IN)
    begin
        for (int i = 0; i < P_SPL; i++)
        begin
            clk_disp_ctl[i] <= LNK_SNK_IF.disp_ctl[0][i];
            clk_disp_val[i] <= LNK_SNK_IF.disp_val[0][i];
        end
    end 

// BS detector
    always_comb
    begin
        // Default
        clk_bs_det = 0;

        for (int i = 0; i < P_SPL; i++)
        begin
            if (clk_din[i] == P_SYM_BS)
                clk_bs_det[i] = 1;
        end
    end

// BS detector delayed
    always_ff @ (posedge CLK_IN)
    begin
        clk_bs_det_del[0] <= clk_bs_det;
        clk_bs_det_del[1] <= clk_bs_det_del[0];
    end

generate
    // 4 symbols per lane
    if (P_SPL == 4)
    begin : gen_bs_cnt_inc_4spl
        always_ff @ (posedge CLK_IN)
        begin
            // Default
            clk_bs_cnt_inc <= 0;

            // Phase 0
            if (clk_bs_det[0] && clk_bs_det[3])
                clk_bs_cnt_inc <= 1;

            // Phase 1
            else if (clk_bs_det_del[0][1] && clk_bs_det[0])
                clk_bs_cnt_inc <= 1;

            // Phase 2
            else if (clk_bs_det_del[0][2] && clk_bs_det[1])
                clk_bs_cnt_inc <= 1;

            // Phase 3
            else if (clk_bs_det_del[0][3] && clk_bs_det[2])
                clk_bs_cnt_inc <= 1;
        end
    end

    // 2 symbols per lane
    else
    begin : gen_bs_seq_2spl
        always_ff @ (posedge CLK_IN)
        begin
            // Default
            clk_bs_cnt_inc <= 0;

            // Phase 0
            if (clk_bs_det_del[0][0] && clk_bs_det[1])
                clk_bs_cnt_inc <= 1;

            // Phase 1
            else if (clk_bs_det_del[1][1] && clk_bs_det[0])
                clk_bs_cnt_inc <= 1;
        end
    end
endgenerate

// BS counter 
    always_ff @ (posedge RST_IN, posedge CLK_IN)
    begin
        // Reset
        if (RST_IN)
            clk_bs_cnt <= 0;

        else
        begin
            // Enable
            if (clk_en)
            begin
                // Clear
                if (clk_bs_cnt == P_BS_CNT_MAX)
                    clk_bs_cnt <= 0;

                // Increment
                else if (clk_bs_cnt_inc)
                    clk_bs_cnt <= clk_bs_cnt + 'd1;
            end

            else
                clk_bs_cnt <= 0;
        end            
    end

// BS counter end
    always_comb
    begin
        if (clk_bs_cnt == 0)
            clk_bs_cnt_end = 1;
        else
            clk_bs_cnt_end = 0;
    end

// Insert SR
    always_comb
    begin
        // Default 
        clk_ins_sr = 0;

        for (int i = 0; i < P_SPL; i++)
        begin
            if (clk_en && clk_bs_cnt_end && clk_bs_det[i])
                clk_ins_sr[i] = 1;
        end
    end

// LFSR data
    always_comb
    begin
        for (int i = 0; i < P_SPL; i++)
        begin
            // Insert scrambler reset     
            if (clk_ins_sr[i])
                clk_dat[i] = P_SYM_SR;
            else
                clk_dat[i] = clk_din[i];
        end
    end

// LFSR reset sublane 0
// Must be registered
    always_ff @ (posedge CLK_IN)
    begin
        // Default
        clk_lfsr_rst[0] <= 0;

        if (clk_ins_sr[P_SPL-1])
            clk_lfsr_rst[0] <= 1;
    end

// LFSR reset other sublanes
// Must be combinatorial
    always_comb
    begin
        for (int i = 1; i < P_SPL; i++)
        begin : gen_lfsr_rst
            // Default
            clk_lfsr_rst[i] = 0;

            if (clk_ins_sr[i-1])
                clk_lfsr_rst[i] = 1;
        end
    end


// LFSR in
    assign clk_lfsr_in[0] = clk_lfsr_reg;

generate
    for (i = 1; i < P_SPL; i++)
    begin : gen_lfsr_in
        assign clk_lfsr_in[i] = clk_lfsr[i-1];
    end
endgenerate

// LFSR
generate
    for (i = 0; i < P_SPL; i++)
    begin : gen_lfsr
        always_comb
        begin
            // Clear
            if (clk_lfsr_rst[i])
                clk_lfsr[i] = 'hffff;
            else
                clk_lfsr[i] = calc_lfsr(clk_lfsr_in[i]);
        end
    end
endgenerate

// LFSR register
    always_ff @ (posedge CLK_IN)
    begin
        clk_lfsr_reg <= clk_lfsr[P_SPL-1];
    end

// Data output
generate
    for (i = 0; i < P_SPL; i++)
    begin : gen_dout
        always_ff @ (posedge CLK_IN)
        begin
            // Pass k character
            clk_dout[i][8] <= clk_din[i][8]; 

            for (int j = 0; j < 8; j++)
            begin
                // Enabled
                if (clk_en)
                begin

                    // Don't scramble k symbols
                    if (clk_din[i][8])
                        clk_dout[i][j] <= clk_dat[i][j];

                    // Scramble
                    else
                        clk_dout[i][j] <= clk_dat[i][j] ^ clk_lfsr[i][15-j];
                end

                // Disabled
                else
                    clk_dout[i] <= clk_dat[i];
            end
        end
    end
endgenerate

// Outputs
generate
    for (i = 0; i < P_SPL; i++)
    begin : gen_src
        assign {LNK_SRC_IF.disp_ctl[0][i], LNK_SRC_IF.disp_val[0][i], LNK_SRC_IF.k[0][i], LNK_SRC_IF.dat[0][i]} = {clk_disp_ctl[i], clk_disp_val[i], clk_dout[i]};
    end
endgenerate

endmodule

`default_nettype wire
