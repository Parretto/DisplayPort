/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP RX Parser
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

`default_nettype none

module prt_dprx_pars
#(
    parameter                   P_SPL = 2       // Symbols per lane
)
(
    // Reset and clock
    input wire                  RST_IN,         // Reset
    input wire                  CLK_IN,         // Clock

    // Control
    input wire                  CTL_EFM_IN,     // Enhanced framing mode

    // Link
    prt_dp_rx_lnk_if.snk        LNK_SNK_IF,     // Sink    
    prt_dp_rx_lnk_if.src        LNK_SRC_IF      // Source
);

// Package
import prt_dp_pkg::*;

// Structures
typedef struct {
    logic                   efm;
    logic                   lock;
    logic   [8:0]           dat[0:P_SPL-1];    // Data
} lnk_struct;

// Structures
typedef struct {
    logic   [P_SPL-1:0]     be_det;
    logic   [P_SPL-1:0]     be_det_reg;
    logic   [P_SPL-1:0]     bs_det;
    logic   [P_SPL-1:0]     bs_det_reg[0:1];
    logic   [P_SPL-1:0]     bf_det;
    logic   [P_SPL-1:0]     bf_det_reg[0:1];
    logic   [P_SPL-1:0]     fs_det;
    logic   [P_SPL-1:0]     fs_det_reg;
    logic   [P_SPL-1:0]     fe_det;
    logic   [P_SPL-1:0]     fe_det_reg;
    logic   [P_SPL-1:0]     ss_det;
    logic   [P_SPL-1:0]     ss_det_reg[0:1];
    logic   [P_SPL-1:0]     se_det;
    logic   [P_SPL-1:0]     se_det_reg;
    logic   [P_SPL-1:0]     vid;
    logic   [P_SPL-1:0]     sec;
    logic   [P_SPL-1:0]     msa;
    logic   [P_SPL-1:0]     vbid;
    logic   [P_SPL-1:0]     sol;
    logic   [P_SPL-1:0]     eol;
} pars_struct;

// Signals
lnk_struct   clk_lnk;
pars_struct  clk_pars;

genvar i;

// Control
    always_ff @ (posedge CLK_IN)
    begin
        clk_lnk.efm <= CTL_EFM_IN;
    end

// Inputs 
// Must be combinatorial
    always_comb
    begin
        for (int i = 0; i < P_SPL; i++)
            clk_lnk.dat[i] = {LNK_SNK_IF.k[0][i], LNK_SNK_IF.dat[0][i]};
    end

// Locked 
// Registered
    always_ff @ (posedge RST_IN, posedge CLK_IN)
    begin
        // Reset
        if (RST_IN)
            clk_lnk.lock <= 0;

        else
            clk_lnk.lock <= LNK_SNK_IF.lock;
    end

// BE symbol detector
// Must be combinatorial
    always_comb
    begin
        for (int i = 0; i < P_SPL; i++)
        begin 
            if (clk_lnk.dat[i] == P_SYM_BE)
                clk_pars.be_det[i] = 1;
            else
                clk_pars.be_det[i] = 0;
        end
    end

// BE symbol detector delayed
// Must be registered
    always_ff @ (posedge CLK_IN)
    begin
        clk_pars.be_det_reg <= clk_pars.be_det;
    end

// BS symbol detector
// Must be cobinatorial
    always_comb
    begin
        for (int i = 0; i < P_SPL; i++)
        begin 
            if ((clk_lnk.dat[i] == P_SYM_BS) || (clk_lnk.dat[i] == P_SYM_SR))
                clk_pars.bs_det[i] = 1;
            else
                clk_pars.bs_det[i] = 0;
        end
    end

// BS symbol detector delayed
// Must be registered
    always_ff @ (posedge CLK_IN)
    begin
        for (int i = 0; i < 2; i++)        
        begin
            if (i == 0)
                clk_pars.bs_det_reg[i] <= clk_pars.bs_det;
            else
                clk_pars.bs_det_reg[i] <= clk_pars.bs_det_reg[i-1];
        end            
    end

// BF symbol detector
// Must be cobinatorial
    always_comb
    begin
        for (int i = 0; i < P_SPL; i++)
        begin 
            if (clk_lnk.dat[i] == P_SYM_BF)
                clk_pars.bf_det[i] = 1;
            else
                clk_pars.bf_det[i] = 0;
        end
    end

// BF symbol detector delayed
// Must be registered
    always_ff @ (posedge CLK_IN)
    begin
        for (int i = 0; i < 2; i++)        
        begin
            if (i == 0)
                clk_pars.bf_det_reg[i] <= clk_pars.bf_det;
            else 
                clk_pars.bf_det_reg[i] <= clk_pars.bf_det_reg[i-1];
        end
    end

// FS symbol detector
// Must be cobinatorial
    always_comb
    begin
        for (int i = 0; i < P_SPL; i++)
        begin 
            if (clk_lnk.dat[i] == P_SYM_FS)
                clk_pars.fs_det[i] = 1;
            else
                clk_pars.fs_det[i] = 0;
        end
    end

// FS symbol detector delayed
// Must be registered
    always_ff @ (posedge CLK_IN)
    begin
        clk_pars.fs_det_reg <= clk_pars.fs_det;
    end

// FE symbol detector
// Must be cobinatorial
    always_comb
    begin
        for (int i = 0; i < P_SPL; i++)
        begin 
            if (clk_lnk.dat[i] == P_SYM_FE)
                clk_pars.fe_det[i] = 1;
            else
                clk_pars.fe_det[i] = 0;
        end
    end

// FE symbol detector delayed
// Must be registered
    always_ff @ (posedge CLK_IN)
    begin
        clk_pars.fe_det_reg <= clk_pars.fe_det;
    end

// SS symbol detector
// Must be cobinatorial
    always_comb
    begin
        for (int i = 0; i < P_SPL; i++)
        begin 
            if (clk_lnk.dat[i] == P_SYM_SS)
                clk_pars.ss_det[i] = 1;
            else
                clk_pars.ss_det[i] = 0;
        end
    end

// SS symbol detector delayed
// Must be registered
    always_ff @ (posedge CLK_IN)
    begin
        for (int i = 0; i < 2; i++)        
        begin
            if (i == 0)
                clk_pars.ss_det_reg[i] <= clk_pars.ss_det;
            else
                clk_pars.ss_det_reg[i] <= clk_pars.ss_det_reg[i-1];
        end
    end

// SE symbol detector
// Must be cobinatorial
    always_comb
    begin
        for (int i = 0; i < P_SPL; i++)
        begin 
            if (clk_lnk.dat[i] == P_SYM_SE)
                clk_pars.se_det[i] = 1;
            else
                clk_pars.se_det[i] = 0;
        end
    end

// SE symbol detector delayed
// Must be registered
    always_ff @ (posedge CLK_IN)
    begin
        clk_pars.se_det_reg <= clk_pars.se_det;
    end

// Video 
// This signal is active during the video data
generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_vid_4spl

    // Sublane 0
        always_ff @ (posedge CLK_IN)
        begin
            // Locked
            if (clk_lnk.lock)
            begin
                // Clear blanking start in sublane 0
                if (clk_pars.bs_det[0] || clk_pars.fs_det[0])
                    clk_pars.vid[0] <= 0;

                // Clear blanking start in sublane 1
                else if (clk_pars.bs_det_reg[0][1] || clk_pars.fs_det_reg[1])
                    clk_pars.vid[0] <= 0;

                // Clear blanking start in sublane 2
                else if (clk_pars.bs_det_reg[0][2] || clk_pars.fs_det_reg[2])
                    clk_pars.vid[0] <= 0;

                // Clear blanking start in sublane 3
                else if (clk_pars.bs_det_reg[0][3] || clk_pars.fs_det_reg[3])
                    clk_pars.vid[0] <= 0;

                // Set video starts in sublane 0
                else if (clk_pars.be_det_reg[3] || clk_pars.fe_det_reg[3])
                    clk_pars.vid[0] <= 1;
                
                // Set video starts in sublane 1
                else if (clk_pars.be_det_reg[0] || clk_pars.fe_det_reg[0])
                    clk_pars.vid[0] <= 1;

                // Set video starts in sublane 2
                else if (clk_pars.be_det_reg[1] || clk_pars.fe_det_reg[1])
                    clk_pars.vid[0] <= 1;

                // Set video starts in sublane 3
                else if (clk_pars.be_det_reg[2] || clk_pars.fe_det_reg[2])
                    clk_pars.vid[0] <= 1;
            end

            // Not locked
            else
                clk_pars.vid[0] <= 0;
        end

    // Sublane 1
        always_ff @ (posedge CLK_IN)
        begin
            // Locked
            if (clk_lnk.lock)
            begin
                // Clear blanking start in sublane 0
                if (clk_pars.bs_det[0] || clk_pars.fs_det[0])
                    clk_pars.vid[1] <= 0;

                // Clear blanking start in sublane 1
                else if (clk_pars.bs_det[1] || clk_pars.fs_det[1])
                    clk_pars.vid[1] <= 0;

                // Clear blanking start in sublane 2
                else if (clk_pars.bs_det_reg[0][2] || clk_pars.fs_det_reg[2])
                    clk_pars.vid[1] <= 0;

                // Clear blanking start in sublane 3
                else if (clk_pars.bs_det_reg[0][3] || clk_pars.fs_det_reg[3])
                    clk_pars.vid[1] <= 0;

                // Set video starts in sublane 0
                else if (clk_pars.be_det_reg[3] || clk_pars.fe_det_reg[3])
                    clk_pars.vid[1] <= 1;
                
                // Set video starts in sublane 1
                else if (clk_pars.be_det[0] || clk_pars.fe_det[0])
                    clk_pars.vid[1] <= 1;

                // Set video starts in sublane 2
                else if (clk_pars.be_det_reg[1] || clk_pars.fe_det_reg[1])
                    clk_pars.vid[1] <= 1;

                // Set video starts in sublane 3
                else if (clk_pars.be_det_reg[2] || clk_pars.fe_det_reg[2])
                    clk_pars.vid[1] <= 1;
            end

            // Not locked
            else
                clk_pars.vid[1] <= 0;
        end

    // Sublane 2
        always_ff @ (posedge CLK_IN)
        begin
            // Locked
            if (clk_lnk.lock)
            begin
                // Clear blanking start in sublane 0
                if (clk_pars.bs_det[0] || clk_pars.fs_det[0])
                    clk_pars.vid[2] <= 0;

                // Clear blanking start in sublane 1
                else if (clk_pars.bs_det[1] || clk_pars.fs_det[1])
                    clk_pars.vid[2] <= 0;

                // Clear blanking start in sublane 2
                else if (clk_pars.bs_det[2] || clk_pars.fs_det[2])
                    clk_pars.vid[2] <= 0;

                // Clear blanking start in sublane 3
                else if (clk_pars.bs_det_reg[0][3] || clk_pars.fs_det_reg[3])
                    clk_pars.vid[2] <= 0;

                // Set video starts in sublane 0
                else if (clk_pars.be_det_reg[3] || clk_pars.fe_det_reg[3])
                    clk_pars.vid[2] <= 1;
                
                // Set video starts in sublane 1
                else if (clk_pars.be_det[0] || clk_pars.fe_det[0])
                    clk_pars.vid[2] <= 1;

                // Set video starts in sublane 2
                else if (clk_pars.be_det[1] || clk_pars.fe_det[1])
                    clk_pars.vid[2] <= 1;

                // Set video starts in sublane 3
                else if (clk_pars.be_det_reg[2] || clk_pars.fe_det_reg[2])
                    clk_pars.vid[2] <= 1;
            end

            // Not locked
            else
                clk_pars.vid[2] <= 0;
        end

    // Sublane 3
        always_ff @ (posedge CLK_IN)
        begin
            // Locked
            if (clk_lnk.lock)
            begin
                // Clear blanking start in sublane 0
                if (clk_pars.bs_det[0] || clk_pars.fs_det[0])
                    clk_pars.vid[3] <= 0;

                // Clear blanking start in sublane 1
                else if (clk_pars.bs_det[1] || clk_pars.fs_det[1])
                    clk_pars.vid[3] <= 0;

                // Clear blanking start in sublane 2
                else if (clk_pars.bs_det[2] || clk_pars.fs_det[2])
                    clk_pars.vid[3] <= 0;

                // Clear blanking start in sublane 3
                else if (clk_pars.bs_det[3] || clk_pars.fs_det[3])
                    clk_pars.vid[3] <= 0;

                // Set video starts in sublane 0
                else if (clk_pars.be_det_reg[3] || clk_pars.fe_det_reg[3])
                    clk_pars.vid[3] <= 1;
                
                // Set video starts in sublane 1
                else if (clk_pars.be_det[0] || clk_pars.fe_det[0])
                    clk_pars.vid[3] <= 1;

                // Set video starts in sublane 2
                else if (clk_pars.be_det[1] || clk_pars.fe_det[1])
                    clk_pars.vid[3] <= 1;

                // Set video starts in sublane 3
                else if (clk_pars.be_det[2] || clk_pars.fe_det[2])
                    clk_pars.vid[3] <= 1;
            end

            // Not locked
            else
                clk_pars.vid[3] <= 0;
        end
    end 

    // Two symbols per lane
    else
    begin : gen_vid_2spl

    // Sublane 0
        always_ff @ (posedge CLK_IN)
        begin
            // Locked
            if (clk_lnk.lock)
            begin
                // Clear phase 0
                if (clk_pars.bs_det[0] || clk_pars.fs_det[0])
                    clk_pars.vid[0] <= 0;

                // Clear phase 1
                else if (clk_pars.bs_det_reg[0][1] || clk_pars.fs_det_reg[1])
                    clk_pars.vid[0] <= 0;

                // Set phase 0
                else if (clk_pars.be_det_reg[0] || clk_pars.fe_det_reg[0])
                    clk_pars.vid[0] <= 1;
                
                // Set phase 1
                else if (clk_pars.be_det_reg[1] || clk_pars.fe_det_reg[1])
                    clk_pars.vid[0] <= 1;
            end

            // Not locked
            else
                clk_pars.vid[0] <= 0;
        end

    // Sublane 1
        always_ff @ (posedge CLK_IN)
        begin
            // Locked
            if (clk_lnk.lock)
            begin
                // Clear phase 0
                if (clk_pars.bs_det[0] || clk_pars.fs_det[0])
                    clk_pars.vid[1] <= 0;

                // Clear phase 1
                else if (clk_pars.bs_det[1] || clk_pars.fs_det[1])
                    clk_pars.vid[1] <= 0;

                // Set phase 0
                else if (clk_pars.be_det[0] || clk_pars.fe_det[0])
                    clk_pars.vid[1] <= 1;
                
                // Set phase 1
                else if (clk_pars.be_det_reg[1] || clk_pars.fe_det_reg[1])
                    clk_pars.vid[1] <= 1;
            end

            // Not locked
            else
                clk_pars.vid[1] <= 0;
        end
    end
endgenerate

// MSA
// This signal is active during the MSA packet
generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_msa_4spl

    // Sublane 0
        always_ff @ (posedge CLK_IN)
        begin
            // Locked
            if (clk_lnk.lock)
            begin
                // Clear MSA ends in sublane 0
                if (clk_pars.se_det[0])
                    clk_pars.msa[0] <= 0;

                // Clear MSA ends in sublane 1
                else if (clk_pars.se_det_reg[1])
                    clk_pars.msa[0] <= 0;

                // Clear MSA ends in sublane 2
                else if (clk_pars.se_det_reg[2])
                    clk_pars.msa[0] <= 0;

                // Clear MSA ends in sublane 3
                else if (clk_pars.se_det_reg[3])
                    clk_pars.msa[0] <= 0;

                // Set MSA starts in sublane 0
                else if (clk_pars.ss_det_reg[0] == 'b0011)
                    clk_pars.msa[0] <= 1;
                
                // Set MSA starts in sublane 1
                else if (clk_pars.ss_det_reg[0] == 'b0110)
                    clk_pars.msa[0] <= 1;

                // Set MSA starts in sublane 2
                else if (clk_pars.ss_det_reg[0] == 'b1100)
                    clk_pars.msa[0] <= 1;

                // Set MSA starts in sublane 3
                else if ((clk_pars.ss_det_reg[0] == 'b0001) && (clk_pars.ss_det_reg[1] == 'b1000))
                    clk_pars.msa[0] <= 1;
            end

            // Not locked
            else
                clk_pars.msa[0] <= 0;
        end

    // Sublane 1
        always_ff @ (posedge CLK_IN)
        begin
            // Locked
            if (clk_lnk.lock)
            begin
                // Clear MSA ends in sublane 0
                if (clk_pars.se_det[0])
                    clk_pars.msa[1] <= 0;

                // Clear MSA ends in sublane 1
                else if (clk_pars.se_det[1])
                    clk_pars.msa[1] <= 0;

                // Clear MSA ends in sublane 2
                else if (clk_pars.se_det_reg[2])
                    clk_pars.msa[1] <= 0;

                // Clear MSA ends in sublane 3
                else if (clk_pars.se_det_reg[3])
                    clk_pars.msa[1] <= 0;

                // Set MSA starts in sublane 0
                else if (clk_pars.ss_det_reg[0] == 'b0011)
                    clk_pars.msa[1] <= 1;
                
                // Set MSA starts in sublane 1
                else if (clk_pars.ss_det_reg[0] == 'b0110)
                    clk_pars.msa[1] <= 1;

                // Set MSA starts in sublane 2
                else if (clk_pars.ss_det_reg[0] == 'b1100)
                    clk_pars.msa[1] <= 1;

                // Set MSA starts in sublane 3
                else if ((clk_pars.ss_det == 'b0001) && (clk_pars.ss_det_reg[0] == 'b1000))
                    clk_pars.msa[1] <= 1;
            end

            // Not locked
            else
                clk_pars.msa[1] <= 0;
        end

    // Sublane 2
        always_ff @ (posedge CLK_IN)
        begin
            // Locked
            if (clk_lnk.lock)
            begin
                // Clear MSA ends in sublane 0
                if (clk_pars.se_det[0])
                    clk_pars.msa[2] <= 0;

                // Clear MSA ends in sublane 1
                else if (clk_pars.se_det[1])
                    clk_pars.msa[2] <= 0;

                // Clear MSA ends in sublane 2
                else if (clk_pars.se_det[2])
                    clk_pars.msa[2] <= 0;

                // Clear MSA ends in sublane 3
                else if (clk_pars.se_det_reg[3])
                    clk_pars.msa[2] <= 0;

                // Set MSA starts in sublane 0
                else if (clk_pars.ss_det == 'b0011)
                    clk_pars.msa[2] <= 1;
                
                // Set MSA starts in sublane 1
                else if (clk_pars.ss_det_reg[0] == 'b0110)
                    clk_pars.msa[2] <= 1;

                // Set MSA starts in sublane 2
                else if (clk_pars.ss_det_reg[0] == 'b1100)
                    clk_pars.msa[2] <= 1;

                // Set MSA starts in sublane 3
                else if ((clk_pars.ss_det == 'b0001) && (clk_pars.ss_det_reg[0] == 'b1000))
                    clk_pars.msa[2] <= 1;
            end

            // Not locked
            else
                clk_pars.msa[2] <= 0;
        end

    // Sublane 3
        always_ff @ (posedge CLK_IN)
        begin
            // Locked
            if (clk_lnk.lock)
            begin
                // Clear MSA ends in sublane 0
                if (clk_pars.se_det[0])
                    clk_pars.msa[3] <= 0;

                // Clear MSA ends in sublane 1
                else if (clk_pars.se_det[1])
                    clk_pars.msa[3] <= 0;

                // Clear MSA ends in sublane 2
                else if (clk_pars.se_det[2])
                    clk_pars.msa[3] <= 0;

                // Clear MSA ends in sublane 3
                else if (clk_pars.se_det[3])
                    clk_pars.msa[3] <= 0;

                // Set MSA starts in sublane 0
                else if (clk_pars.ss_det == 'b0011)
                    clk_pars.msa[3] <= 1;
                
                // Set MSA starts in sublane 1
                else if (clk_pars.ss_det == 'b0110)
                    clk_pars.msa[3] <= 1;

                // Set MSA starts in sublane 2
                else if (clk_pars.ss_det_reg[0] == 'b1100)
                    clk_pars.msa[3] <= 1;

                // Set MSA starts in sublane 3
                else if ((clk_pars.ss_det == 'b0001) && (clk_pars.ss_det_reg[0] == 'b1000))
                    clk_pars.msa[3] <= 1;
            end

            // Not locked
            else
                clk_pars.msa[3] <= 0;
        end

    end

    // Two symbosl per lane
    else
    begin : gen_msa_2spl
    
    // Sublane 0
        always_ff @ (posedge CLK_IN)
        begin
            // Locked
            if (clk_lnk.lock)
            begin
                // Clear phase 0
                if (clk_pars.se_det[0])
                    clk_pars.msa[0] <= 0;

                // Clear phase 1
                else if (clk_pars.se_det_reg[1])
                    clk_pars.msa[0] <= 0;

                // Set phase 0
                else if ((clk_pars.ss_det == 'b00) && (clk_pars.ss_det_reg[0] == 'b11) && (clk_pars.ss_det_reg[1] == 'b00))
                    clk_pars.msa[0] <= 1;
                
                // Set phase 1
                else if ((clk_pars.ss_det == 'b00) && (clk_pars.ss_det_reg[0] == 'b01) && (clk_pars.ss_det_reg[1] == 'b10))
                    clk_pars.msa[0] <= 1;
            end

            // Not locked
            else
                clk_pars.msa[0] <= 0;
        end

    // MSA
    // Sublane 1
        always_ff @ (posedge CLK_IN)
        begin
            // Locked
            if (clk_lnk.lock)
            begin
                // Clear phase 0
                if (clk_pars.se_det[0])
                    clk_pars.msa[1] <= 0;

                // Clear phase 1
                else if (clk_pars.se_det[1])
                    clk_pars.msa[1] <= 0;

                // Set phase 0
                else if ((clk_pars.ss_det == 'b00) && (clk_pars.ss_det_reg[0] == 'b11) && (clk_pars.ss_det_reg[1] == 'b00))
                    clk_pars.msa[1] <= 1;
                
                // Set phase 1
                else if ((clk_pars.ss_det == 'b01) && (clk_pars.ss_det_reg[0] == 'b10) && (clk_pars.ss_det_reg[1] == 'b00))
                    clk_pars.msa[1] <= 1;
            end

            // Not locked
            else
                clk_pars.msa[1] <= 0;
        end
    end
endgenerate

// Secondary
generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_sec_4spl
        // Not implemented yet in four symbols per lane
        for (i = 0; i < P_SPL; i++)
            assign clk_pars.sec[i] =  0;
    end

    // Two symbols per lane
    else
    begin : gen_sec_2spl

    // Sublane 0
        always_ff @ (posedge CLK_IN)
        begin
            // Locked
            if (clk_lnk.lock)
            begin
                // Clear phase 0
                if (clk_pars.se_det[0])
                    clk_pars.sec[0] <= 0;

                // Clear phase 1
                else if (clk_pars.se_det_reg[1])
                    clk_pars.sec[0] <= 0;

                // Set phase 0
                else if ((clk_pars.ss_det == 'b00) && (clk_pars.ss_det_reg[0] == 'b01) && (clk_pars.ss_det_reg[1] == 'b00))
                    clk_pars.sec[0] <= 1;
                
                // Set phase 1
                else if ((clk_pars.ss_det == 'b00) && (clk_pars.ss_det_reg[0] == 'b10) && (clk_pars.ss_det_reg[1] == 'b00))
                    clk_pars.sec[0] <= 1;
            end

            // Not locked
            else
                clk_pars.sec[0] <= 0;
        end

    // Secondary 
    // Sublane 1
        always_ff @ (posedge CLK_IN)
        begin
            // Locked
            if (clk_lnk.lock)
            begin
                // Clear phase 0
                if (clk_pars.se_det[0])
                    clk_pars.sec[1] <= 0;

                // Clear phase 1
                else if (clk_pars.se_det[1])
                    clk_pars.sec[1] <= 0;

                // Set phase 0
                else if ((clk_pars.ss_det == 'b01) && (clk_pars.ss_det_reg[0] == 'b00) && (clk_pars.ss_det_reg[1] == 'b00))
                    clk_pars.sec[1] <= 1;
                
                // Set phase 1
                else if ((clk_pars.ss_det == 'b00) && (clk_pars.ss_det_reg[0] == 'b10) && (clk_pars.ss_det_reg[1] == 'b00))
                    clk_pars.sec[1] <= 1;
            end

            // Not locked
            else
                clk_pars.sec[1] <= 0;
        end
    end
endgenerate

// VB-ID
// This signal is active during the VB-ID symbol
generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_vbid_4spl

    // Sublane 0
        always_ff @ (posedge CLK_IN)
        begin
            // Default
            clk_pars.vbid[0] <= 0;

            // Locked
            if (clk_lnk.lock)
            begin
                // Enhanced framing mode
                if (clk_lnk.efm)
                begin
                    if ((clk_pars.bs_det_reg[0] == 'b1001) && (clk_pars.bf_det_reg[0] == 'b0110))
                        clk_pars.vbid[0] <= 1;
                end

                // Normal framing mode
                else
                begin
                    if (clk_pars.bs_det_reg[1] == 'b1000)
                        clk_pars.vbid[0] <= 1;
                end
            end
        end

    // Sublane 1
        always_ff @ (posedge CLK_IN)
        begin
            // Default
            clk_pars.vbid[1] <= 0;

            // Locked
            if (clk_lnk.lock)
            begin
                // Enhanced framing mode
                if (clk_lnk.efm)
                begin
                    if ((clk_pars.bs_det == 'b0001) && (clk_pars.bs_det_reg[0] == 'b0010) && (clk_pars.bf_det_reg[0] == 'b1100))
                        clk_pars.vbid[1] <= 1;
                end

                // Normal framing mode
                else
                begin
                    if (clk_pars.bs_det_reg[0] == 'b0001)
                        clk_pars.vbid[1] <= 1;
                end
            end
        end

    // Sublane 2
        always_ff @ (posedge CLK_IN)
        begin
            // Default
            clk_pars.vbid[2] <= 0;

            // Locked
            if (clk_lnk.lock)
            begin
                // Enhanced framing mode
                if (clk_lnk.efm)
                begin
                    if ((clk_pars.bs_det == 'b0010) && (clk_pars.bs_det_reg[0] == 'b0100) && (clk_pars.bf_det == 'b0001) && (clk_pars.bf_det_reg[0] == 'b1000))
                        clk_pars.vbid[2] <= 1;
                end

                // Normal framing mode
                else
                begin
                    if (clk_pars.bs_det_reg[0] == 'b0010)
                        clk_pars.vbid[2] <= 1;
                end
            end
        end

    // Sublane 3
        always_ff @ (posedge CLK_IN)
        begin
            // Default
            clk_pars.vbid[3] <= 0;

            // Locked
            if (clk_lnk.lock)
            begin
                // Enhanced framing mode
                if (clk_lnk.efm)
                begin
                    if ((clk_pars.bs_det == 'b0100) && (clk_pars.bs_det_reg[0] == 'b1000) && (clk_pars.bf_det == 'b0011))
                        clk_pars.vbid[3] <= 1;
                end

                // Normal framing mode
                else
                begin
                    if (clk_pars.bs_det_reg[0] == 'b0100)
                        clk_pars.vbid[3] <= 1;
                end
            end
        end

    end

    // Two symbols per lane
    else
    begin : gen_vbid_2spl

    // Sublane 0
        always_ff @ (posedge CLK_IN)
        begin
            // Default
            clk_pars.vbid[0] <= 0;

            // Locked
            if (clk_lnk.lock)
            begin
                // Enhanced framing mode
                if (clk_lnk.efm)
                begin
                    if ((clk_pars.bs_det_reg[1] == 'b01) && (clk_pars.bf_det_reg[1] == 'b10) && (clk_pars.bs_det_reg[0] == 'b10) && (clk_pars.bf_det_reg[0] == 'b01))
                        clk_pars.vbid[0] <= 1;
                end

                // Normal framing mode
                else
                begin
                    if (clk_pars.bs_det_reg[0] == 'b10)
                        clk_pars.vbid[0] <= 1;
                end
            end
        end

    // Sublane 1
        always_ff @ (posedge CLK_IN)
        begin
            // Default
            clk_pars.vbid[1] <= 0;

            // Locked
            if (clk_lnk.lock)
            begin
                // Enhanced framing mode
                if (clk_lnk.efm)
                begin
                    if ((clk_pars.bs_det_reg[1] == 'b10) && (clk_pars.bf_det_reg[0] == 'b11) && (clk_pars.bs_det == 'b01))
                        clk_pars.vbid[1] <= 1;
                end

                // Normal framing mode
                else
                begin
                    if (clk_pars.bs_det == 'b01)
                        clk_pars.vbid[1] <= 1;
                end
            end
        end
    end
endgenerate

// Start of line
// Must be combinatorial
    assign clk_pars.sol = (clk_lnk.lock) ? clk_pars.be_det : 1'b0;

// End of line
// This bit is asserted during the last active pixel
// Must be combinatorial
generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_eol_4spl
    
    // Sublane 0
        always_comb
        begin
            // Default
            clk_pars.eol[0] = 0;

            // Enhanced framing mode
            if (clk_lnk.efm)
            begin
                if ((clk_pars.bs_det == 'b0001) && (clk_pars.bs_det_reg[0] == 'b0010) && (clk_pars.bf_det == 'b0000) && (clk_pars.bf_det_reg[0] == 'b1100))
                    clk_pars.eol[0] = 1;
            end

            // Normal mode
            else 
            begin
                if (clk_pars.bs_det == 'b0010) 
                    clk_pars.eol[0] = 1;
            end
        end

    // Sublane 1
        always_comb
        begin
            // Default
            clk_pars.eol[1] = 0;

            // Enhanced framing mode
            if (clk_lnk.efm)
            begin
                if ((clk_pars.bs_det == 'b0010) && (clk_pars.bs_det_reg[0] == 'b0100) && (clk_pars.bf_det == 'b0001) && (clk_pars.bf_det_reg[0] == 'b1000))
                    clk_pars.eol[1] = 1;
            end

            // Normal mode
            else 
            begin
                if (clk_pars.bs_det == 'b0100) 
                    clk_pars.eol[1] = 1;
            end
        end

    // Sublane 2
        always_comb
        begin
            // Default
            clk_pars.eol[2] = 0;

            // Enhanced framing mode
            if (clk_lnk.efm)
            begin
                if ((clk_pars.bs_det == 'b0100) && (clk_pars.bs_det_reg[0] == 'b1000) && (clk_pars.bf_det == 'b0011))
                    clk_pars.eol[2] = 1;
            end

            // Normal mode
            else 
            begin
                if (clk_pars.bs_det == 'b1000) 
                    clk_pars.eol[2] = 1;
            end
        end

    // Sublane 3
        always_comb
        begin
            // Default
            clk_pars.eol[3] = 0;

            // Enhanced framing mode
            if (clk_lnk.efm)
            begin
                if ((clk_pars.bs_det == 'b1001) && (clk_pars.bf_det == 'b0110))
                    clk_pars.eol[3] = 1;
            end

            // Normal mode
            else 
            begin
                if (clk_pars.bs_det == 'b0001) 
                    clk_pars.eol[3] = 1;
            end
        end

    end

    // Two symbols per lane
    else
    begin : gen_eol_2spl
    // Sublane 0
        always_comb
        begin
            // Default
            clk_pars.eol[0] = 0;

            // Enhanced framing mode
            if (clk_lnk.efm)
            begin
                if ((clk_pars.bs_det_reg[0] == 'b10) && (clk_pars.bf_det_reg[0] == 'b00))
                    clk_pars.eol[0] = 1;
            end

            // Normal mode
            else 
            begin
                if (clk_pars.bs_det_reg[0] == 'b10) 
                    clk_pars.eol[0] = 1;
            end
        end

    // End of line
    // Must be combinatorial
    // Sublane 1
        always_comb
        begin
        // Default
            clk_pars.eol[1] = 0;

            // Enhanced framing mode
            if (clk_lnk.efm)
            begin
                if ((clk_pars.bs_det == 'b01) && (clk_pars.bf_det == 'b10))
                    clk_pars.eol[1] = 1;
            end

            // Normal mode
            else
            begin
                if (clk_pars.bs_det == 'b01) 
                    clk_pars.eol[1] = 1;
            end
        end
    end
endgenerate

// Outputs

generate
    for (i = 0; i < P_SPL; i++)
        assign {LNK_SRC_IF.k[0][i], LNK_SRC_IF.dat[0][i]} = clk_lnk.dat[i];
endgenerate

    // Lock
    assign LNK_SRC_IF.lock = clk_lnk.lock;

    // Parser
    // Note: these signals have one clock latency related to the passed link data. 
    // These signals will be inserted after the scrambler to the main link data.
    assign LNK_SRC_IF.sol[0]    = clk_pars.sol;         // Start of line (the start of line is leading the first pixel)
    assign LNK_SRC_IF.eol[0]    = clk_pars.eol;         // End of line (the end of line is aligned with the last pixel. This output is also active during the blanking)
    assign LNK_SRC_IF.vid[0]    = clk_pars.vid;         // Video packet
    assign LNK_SRC_IF.sec[0]    = clk_pars.sec;         // Secondary packet
    assign LNK_SRC_IF.msa[0]    = clk_pars.msa;         // Main stream attribute packet
    assign LNK_SRC_IF.vbid[0]   = clk_pars.vbid;        // VB-ID

endmodule

`default_nettype wire
