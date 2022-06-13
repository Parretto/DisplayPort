/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP TX Skew
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

module prt_dptx_skew
#(
    // Link
    parameter               P_SKEW = 0,    // Skew
    parameter               P_SPL = 2      // Symbols per lane
)
(
    input wire              CLK_IN,         // Clock

    // Link
    prt_dp_tx_lnk_if.snk    LNK_SNK_IF,     // Sink
    prt_dp_tx_lnk_if.src    LNK_SRC_IF      // Source
);

generate
    // No skew. Just wires
    if (P_SKEW == 0)
    begin : gen_no_skew
        assign LNK_SRC_IF.disp_ctl[0]    = 0; // Not used
        assign LNK_SRC_IF.disp_val[0]    = 0; // Not used
        assign LNK_SRC_IF.k[0]           = LNK_SNK_IF.k[0];
        assign LNK_SRC_IF.dat[0]         = LNK_SNK_IF.dat[0]; 
    end

    else
    begin : gen_skew
        // Signals
        logic   [P_SPL-1:0]     clk_k[0:P_SKEW-1];              // k character
        logic   [7:0]           clk_dat[0:P_SKEW-1][0:P_SPL-1]; // Data

        // Skew
        always_ff @ (posedge CLK_IN) 
        begin
            for (int i = 0; i < P_SKEW; i++)
            begin 
                if (i == 0)
                begin
                    clk_k[0]        <= LNK_SNK_IF.k[0];   
                    clk_dat[0]      <= LNK_SNK_IF.dat[0];  
                end
                else
                begin
                    clk_k[i]        <= clk_k[i-1];
                    clk_dat[i]      <= clk_dat[i-1];
                end
            end
        end

        // Outputs
        assign LNK_SRC_IF.disp_ctl[0]    = 0;   // Not used
        assign LNK_SRC_IF.disp_val[0]    = 0;   // Not used
        assign LNK_SRC_IF.k[0]           = clk_k[P_SKEW-1];
        assign LNK_SRC_IF.dat[0]         = clk_dat[P_SKEW-1]; 
    end
endgenerate

endmodule

`default_nettype wire