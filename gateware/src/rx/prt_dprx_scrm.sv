/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP RX Scrambler
    (c) 2021 - 2025 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Initial MST support
    v1.2 - Updated watchdog reset


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

// Module
module prt_dprx_scrm
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
    input wire              CTL_MST_IN,    // MST

    // Link 
    prt_dp_rx_lnk_if.snk    LNK_SNK_IF,     // Sink
    prt_dp_rx_lnk_if.src    LNK_SRC_IF      // Source
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

// Signals
logic                  clk_en;
logic                  clk_mst;
logic                  clk_lock_in;        // Input lock
logic                  clk_lock;          // Locked
logic [8:0]            clk_din[P_SPL];
logic [8:0]            clk_dat[P_SPL];
logic [P_SPL-1:0]      clk_sr_det;
logic [P_SPL-1:0]      clk_bf_det;
logic [P_SPL-1:0]      clk_lfsr_rst;
logic [15:0]           clk_lfsr_in[P_SPL];
logic [15:0]           clk_lfsr[P_SPL];
logic [15:0]           clk_lfsr_reg;
logic [8:0]            clk_dout[P_SPL];

logic [2:0]            clk_scrm_sidx[P_SPL];
logic [7:0]            clk_scrm_idx[P_SPL];

logic [3:0]            clk_sr_state;
logic                  clk_wdg_cnt_ld;
logic [23:0]           clk_wdg_cnt;
logic                  clk_wdg_cnt_end;

genvar i;

// Logic

// Control
    always_ff @ (posedge CLK_IN)
    begin
        clk_en  <= CTL_EN_IN;
        clk_mst  <= CTL_MST_IN;
    end

// Sink lock
    always_ff @ (posedge CLK_IN)
    begin
        clk_lock_in <= LNK_SNK_IF.lock;
    end

// Input registers
generate
    for (i = 0; i < P_SPL; i++)
    begin : gen_din
        assign clk_din[i] = {LNK_SNK_IF.k[0][i], LNK_SNK_IF.dat[0][i]};
    end
endgenerate
   
// SR detector
    always_comb
    begin
        // Default
        clk_sr_det = 0;

        for (int i = 0; i < P_SPL; i++)
        begin
            if (clk_din[i] == ((clk_mst) ? P_SYM_K28_5 : P_SYM_SR))
                clk_sr_det[i] = 1;
        end
    end

// BF detector
    always_comb
    begin
        // Default
        clk_bf_det = 0;

        for (int i = 0; i < P_SPL; i++)
        begin
            if (clk_din[i] == P_SYM_BF)
                clk_bf_det[i] = 1;
        end
    end

// Scrambler index
    always_comb
    begin
        for (int i = 0; i < P_SPL; i++)
        begin
            case (clk_din[i])
                P_SYM_K23_7 : clk_scrm_sidx[i] = 'd0;
                P_SYM_K27_7 : clk_scrm_sidx[i] = 'd1;
                P_SYM_K28_0 : clk_scrm_sidx[i] = 'd2;
                P_SYM_K28_2 : clk_scrm_sidx[i] = 'd3;
                P_SYM_K28_3 : clk_scrm_sidx[i] = 'd4;
                P_SYM_K28_6 : clk_scrm_sidx[i] = 'd5;
                P_SYM_K29_7 : clk_scrm_sidx[i] = 'd6;
                P_SYM_K30_7 : clk_scrm_sidx[i] = 'd7;
                default : clk_scrm_sidx[i] = 'd0;
            endcase
        end
    end

// Scrambler index
    always_comb
    begin
        for (int i = 0; i < P_SPL; i++)
        begin
            clk_scrm_idx[i] = clk_scrm_sidx[i] ^ {clk_lfsr[i][13], clk_lfsr[i][14], clk_lfsr[i][15]}; 
        end
    end

// LFSR data
    always_comb
    begin
        for (int i = 0; i < P_SPL; i++)
        begin
            // Replace SR symbol with BS symbol
            // Only in SST 
            if (!clk_mst && clk_sr_det[i])
                clk_dat[i] = P_SYM_BS;
            else
                clk_dat[i] = clk_din[i];
        end
    end

// LFSR reset
generate
    for (i = 0; i < P_SPL; i++)
    begin : gen_lfsr_rst
        if (i == 0)
        begin
            // LFSR reset sublane 0
            // Must be registered
            always_ff @ (posedge CLK_IN)
            begin
                // Default
                clk_lfsr_rst[0] <= 0;

                if (clk_sr_det[P_SPL-1])
                    clk_lfsr_rst[0] <= 1;
            end
        end

        else
        begin
            // LFSR reset other sublanes
            // Must be combinatorial
            always_comb
            begin
                // Default
                clk_lfsr_rst[i] = 0;

                if (clk_sr_det[i-1])
                    clk_lfsr_rst[i] = 1;
            end
        end
    end
endgenerate

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
                    begin
                        // MST
                        if (clk_mst)
                            clk_dout[i][j] <= clk_scrm_idx[i][j];

                        // SST    
                        else
                            clk_dout[i][j] <= clk_dat[i][j];
                    end

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

/*
    Watchdog counter
*/

// Watchdog counter 
// The watchdog counter is reloaded when a scrambler reset is detected.
// When it expires the lock is lost. 
// The displayport specification defines that the interval between two SR symbols is 512 BS symbols. 
// The BS period is variable, so a random value is selected.
    
// Scrambler reset event detector
// For the scrambler logic resetting the LFSR, when a single scrambler reset symbol (SR) is detected, is good.
// However, when the link is unstable, the PHY can output random data including SR symbols.
// This corrupted symbol will reload the watchdog, resulting that the lock remains asserted.
// and the DP policy maker will not bring down the link becuase of a scrambler lock lost. 
// To prevent this, we want to detect a complete scrambler resert event (SR + BF + BF + SR) in enhanced framing mode
// Only when a full sequence is detected, this will reload the watchdog.

generate
    if (P_SPL == 4)
    begin : sr_evt_4spl

        always_ff @ (posedge RST_IN, posedge CLK_IN)
        begin
            // Reset
            if (RST_IN)
            begin
                clk_sr_state <= 0;
                clk_wdg_cnt_ld <= 0;
            end

            else
            begin
                // Default
                clk_wdg_cnt_ld <= 0;

                case (clk_sr_state)

                    'd0 : 
                    begin
                        // Phase 0
                        if ((clk_sr_det == 'b1001) && (clk_bf_det == 'b0110))
                            clk_sr_state <= 'd4;

                        // Phase 1a
                        else if ((clk_sr_det == 'b0010) && (clk_bf_det == 'b1100))
                            clk_sr_state <= 'd1;

                        // Phase 2a
                        else if ((clk_sr_det == 'b0100) && (clk_bf_det == 'b1000))
                            clk_sr_state <= 'd2;

                        // Phase 3a
                        else if ((clk_sr_det == 'b1000) && (clk_bf_det == 'b0000))
                            clk_sr_state <= 'd3;

                        else
                            clk_sr_state <= 'd0;
                    end

                    'd1 : 
                    begin
                        // Phase 1b
                        if ((clk_sr_det == 'b0001) && (clk_bf_det == 'b0000))
                            clk_sr_state <= 'd4;
                        else
                            clk_sr_state <= 'd0;
                    end

                    'd2 : 
                    begin
                        // Phase 2b
                        if ((clk_sr_det == 'b0010) && (clk_bf_det == 'b0001))
                            clk_sr_state <= 'd4;
                        else
                            clk_sr_state <= 'd0;
                    end

                    'd3 : 
                    begin
                        // Phase 3b
                        if ((clk_sr_det == 'b0100) && (clk_bf_det == 'b0011))
                            clk_sr_state <= 'd4;
                        else
                            clk_sr_state <= 'd0;
                    end

                    'd4 : 
                    begin
                        clk_wdg_cnt_ld <= 1;
                        clk_sr_state <= 'd0;
                    end

                    default : 
                    begin
                        clk_wdg_cnt_ld <= 0;
                        clk_sr_state <= 'd0;
                    end

                endcase               
            end

        end
    end

    else
    begin : wdg_ld_2spl
        always_ff @ (posedge RST_IN, posedge CLK_IN)
        begin
            // Reset
            if (RST_IN)
            begin
                clk_sr_state <= 0;
                clk_wdg_cnt_ld <= 0;
            end

            else
            begin
                // Default
                clk_wdg_cnt_ld <= 0;

                case (clk_sr_state)

                    'd0 : 
                    begin
                        // Phase 0a
                        if ((clk_sr_det == 'b01) && (clk_bf_det == 'b10))
                            clk_sr_state <= 'd1;

                        // Phase 1a
                        else if ((clk_sr_det == 'b10) && (clk_bf_det == 'b00))
                            clk_sr_state <= 'd2;

                        else
                            clk_sr_state <= 'd0;
                    end

                    'd1 : 
                    begin
                        // Phase 0b
                        if ((clk_sr_det == 'b10) && (clk_bf_det == 'b01))
                            clk_sr_state <= 'd4;
                        else
                            clk_sr_state <= 'd0;
                    end

                    'd2 : 
                    begin
                        // Phase 1b
                        if ((clk_sr_det == 'b00) && (clk_bf_det == 'b11))
                            clk_sr_state <= 'd3;
                        else
                            clk_sr_state <= 'd0;
                    end

                    'd3 : 
                    begin
                        // Phase 1c
                        if ((clk_sr_det == 'b01) && (clk_bf_det == 'b00))
                            clk_sr_state <= 'd4;
                        else
                            clk_sr_state <= 'd0;
                    end

                    'd4 : 
                    begin
                        clk_wdg_cnt_ld <= 1;
                        clk_sr_state <= 'd0;
                    end

                    default : 
                    begin
                        clk_wdg_cnt_ld <= 0;
                        clk_sr_state <= 'd0;
                    end

                endcase               
            end
        end
    end
endgenerate

// Counter
    always_ff @ (posedge RST_IN, posedge CLK_IN)
    begin
        // Reset
        if (RST_IN)
            clk_wdg_cnt <= 0;

        else
        begin
            // Input locked
            if (clk_lock_in)
            begin
                // Load
                if (clk_wdg_cnt_ld)
                    clk_wdg_cnt <= '1;

                // Decrement
                else if (!clk_wdg_cnt_end)
                    clk_wdg_cnt <= clk_wdg_cnt - 'd1;
            end

            else
                clk_wdg_cnt <= 0;
        end
    end

// Watchdog counter end
    always_comb
    begin
        if (clk_wdg_cnt == 0)
            clk_wdg_cnt_end = 1;
        else
            clk_wdg_cnt_end = 0;
    end

// Locked
    always_ff @ (posedge RST_IN, posedge CLK_IN)
    begin
        // Reset
        if (RST_IN)
            clk_lock <= 0;
        
        else
        begin
            if (clk_en)
            begin
                if (clk_wdg_cnt_end)
                    clk_lock <= 0;
                else
                    clk_lock <= 1;
            end
            
            else
                clk_lock <= 1;
        end
    end

// Outputs
generate
    for (i = 0; i < P_SPL; i++)
    begin : gen_src
        assign {LNK_SRC_IF.k[0][i], LNK_SRC_IF.dat[0][i]} = clk_dout[i];
    end
endgenerate

    assign LNK_SRC_IF.lock    = clk_lock;
    assign LNK_SRC_IF.sol[0]  = 0;  // Not used
    assign LNK_SRC_IF.eol[0]  = 0;  // Not used
    assign LNK_SRC_IF.vid[0]  = 0;  // Not used
    assign LNK_SRC_IF.sdp[0]  = 0;  // Not used
    assign LNK_SRC_IF.msa[0]  = 0;  // Not used
    assign LNK_SRC_IF.vbid[0] = 0;  // Not used

endmodule

`default_nettype wire
