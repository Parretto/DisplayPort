/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP TX Skew
    (c) 2021 - 2025 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Added support for 4 symbols per lane
    v1.2 - Updated PHY interface
    
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

module prt_dptx_skew
#(
    // Link
    parameter               P_LANE = 0,    // Lane
    parameter               P_SPL = 2      // Symbols per lane
)
(
    input wire              CLK_IN,         // Clock

    // Link
    prt_dp_tx_phy_if.snk    LNK_SNK_IF,     // Sink
    prt_dp_tx_phy_if.src    LNK_SRC_IF      // Source
);

generate
    if (P_LANE == 0)
    begin : gen_no_skew
        assign LNK_SRC_IF.disp_ctl[0]    = LNK_SNK_IF.disp_ctl[0]; 
        assign LNK_SRC_IF.disp_val[0]    = LNK_SNK_IF.disp_val[0];
        assign LNK_SRC_IF.k[0]           = LNK_SNK_IF.k[0];
        assign LNK_SRC_IF.dat[0]         = LNK_SNK_IF.dat[0]; 
    end

    // Four symbols per lane
    else if (P_SPL == 4)
    begin : gen_4_spl
        if (P_LANE == 1)
        begin : gen_lane_1
            // Signals
            logic   [1:0]     clk_disp_ctl_del; // Disparity control
            logic   [1:0]     clk_disp_val_del; // Disparity value
            logic   [1:0]     clk_k_del;        // k character
            logic   [7:0]     clk_dat_del[0:1]; // Data

            // Skew
            always_ff @ (posedge CLK_IN) 
            begin
                clk_disp_ctl_del <= LNK_SNK_IF.disp_ctl[0][3:2];   
                clk_disp_val_del <= LNK_SNK_IF.disp_val[0][3:2];   
                clk_k_del        <= LNK_SNK_IF.k[0][3:2];   
                clk_dat_del      <= LNK_SNK_IF.dat[0][2:3];  
            end

            // Outputs
            assign LNK_SRC_IF.disp_ctl[0]    = {LNK_SNK_IF.disp_ctl[0][1:0], clk_disp_ctl_del};
            assign LNK_SRC_IF.disp_val[0]    = {LNK_SNK_IF.disp_val[0][1:0], clk_disp_val_del};
            assign LNK_SRC_IF.k[0]           = {LNK_SNK_IF.k[0][1:0], clk_k_del};
            assign LNK_SRC_IF.dat[0]         = {clk_dat_del[0], clk_dat_del[1], LNK_SNK_IF.dat[0][0], LNK_SNK_IF.dat[0][1]}; 
        end

        else if (P_LANE == 2)
        begin : gen_lane_2
            // Signals
            logic   [P_SPL-1:0]     clk_disp_ctl_skew;       // Disparity control
            logic   [P_SPL-1:0]     clk_disp_val_skew;       // Disparity value
            logic   [P_SPL-1:0]     clk_k_skew;              // k character
            logic   [7:0]           clk_dat_skew[0:P_SPL-1]; // Data

            // Skew
            always_ff @ (posedge CLK_IN) 
            begin
                clk_disp_ctl_skew <= LNK_SNK_IF.disp_ctl[0];   
                clk_disp_val_skew <= LNK_SNK_IF.disp_val[0];   
                clk_k_skew        <= LNK_SNK_IF.k[0];   
                clk_dat_skew      <= LNK_SNK_IF.dat[0];  
            end

            // Outputs
            assign LNK_SRC_IF.disp_ctl[0]    = clk_disp_ctl_skew;
            assign LNK_SRC_IF.disp_val[0]    = clk_disp_val_skew;
            assign LNK_SRC_IF.k[0]           = clk_k_skew;
            assign LNK_SRC_IF.dat[0]         = clk_dat_skew; 
        end

        else 
        begin : gen_lane_3
            // Signals
            logic   [1:0]           clk_disp_ctl_del;           // Disparity control
            logic   [1:0]           clk_disp_val_del;           // Disparity value
            logic   [1:0]           clk_k_del;                  // k character
            logic   [7:0]           clk_dat_del[0:1];           // Data
            logic   [P_SPL-1:0]     clk_disp_ctl_skew;          // Disparity control
            logic   [P_SPL-1:0]     clk_disp_val_skew;          // Disparity value
            logic   [P_SPL-1:0]     clk_k_skew;                 // k character
            logic   [7:0]           clk_dat_skew[0:P_SPL-1];    // Data

            // Skew
            always_ff @ (posedge CLK_IN) 
            begin
                clk_disp_ctl_skew <= LNK_SNK_IF.disp_ctl[0];   
                clk_disp_val_skew <= LNK_SNK_IF.disp_val[0];   
                clk_k_skew        <= LNK_SNK_IF.k[0];   
                clk_dat_skew      <= LNK_SNK_IF.dat[0];  

                clk_disp_ctl_del <= clk_disp_ctl_skew[3:2];   
                clk_disp_val_del <= clk_disp_val_skew[3:2];   
                clk_k_del        <= clk_k_skew[3:2];   
                clk_dat_del      <= clk_dat_skew[2:3];  
            end

            // Outputs
            assign LNK_SRC_IF.disp_ctl[0]    = {clk_disp_ctl_skew[1:0], clk_disp_ctl_del};
            assign LNK_SRC_IF.disp_val[0]    = {clk_disp_val_skew[1:0], clk_disp_val_del};
            assign LNK_SRC_IF.k[0]           = {clk_k_skew[1:0], clk_k_del};
            assign LNK_SRC_IF.dat[0]         = {clk_dat_del[0], clk_dat_del[1], clk_dat_skew[0], clk_dat_skew[1]}; 
        end
    end

    // Two symbols per lanes
    else
    begin : gen_2_spl

        // Signals
        logic   [P_SPL-1:0]     clk_disp_ctl[0:P_LANE-1];       // Disparity control
        logic   [P_SPL-1:0]     clk_disp_val[0:P_LANE-1];       // Disparity value
        logic   [P_SPL-1:0]     clk_k[0:P_LANE-1];              // k character
        logic   [7:0]           clk_dat[0:P_LANE-1][0:P_SPL-1]; // Data

        // Skew
        always_ff @ (posedge CLK_IN) 
        begin
            for (int i = 0; i < P_LANE; i++)
            begin 
                if (i == 0)
                begin
                    clk_disp_ctl[0] <= LNK_SNK_IF.disp_ctl[0];   
                    clk_disp_val[0] <= LNK_SNK_IF.disp_val[0];   
                    clk_k[0]        <= LNK_SNK_IF.k[0];   
                    clk_dat[0]      <= LNK_SNK_IF.dat[0];  
                end
                else
                begin
                    clk_disp_ctl[i] <= clk_disp_ctl[i-1];
                    clk_disp_val[i] <= clk_disp_val[i-1];
                    clk_k[i]        <= clk_k[i-1];
                    clk_dat[i]      <= clk_dat[i-1];
                end
            end
        end

        // Outputs
        assign LNK_SRC_IF.disp_ctl[0]    = clk_disp_ctl[P_LANE-1];
        assign LNK_SRC_IF.disp_val[0]    = clk_disp_val[P_LANE-1];
        assign LNK_SRC_IF.k[0]           = clk_k[P_LANE-1];
        assign LNK_SRC_IF.dat[0]         = clk_dat[P_LANE-1]; 
    end

endgenerate

endmodule

`default_nettype wire