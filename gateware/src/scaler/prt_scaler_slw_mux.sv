/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Scaler sliding window multiplier
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

module prt_scaler_slw_mux
#(
    parameter                              P_BPC = 8           // Bits per component
)
(
    // Reset and clock
    input wire                              CLK_IN,

    // Control
    input wire [2:0]                        SEL_IN,
    input wire                              WR_IN,

    // Data in
    input wire [P_BPC-1:0]                  A_DAT_IN,
    input wire [P_BPC-1:0]                  B_DAT_IN,
    input wire [P_BPC-1:0]                  C_DAT_IN,
    input wire [P_BPC-1:0]                  D_DAT_IN,
    input wire [P_BPC-1:0]                  E_DAT_IN,
    input wire [P_BPC-1:0]                  F_DAT_IN,
    input wire [P_BPC-1:0]                  G_DAT_IN,

    // Data out
    output wire [P_BPC-1:0]                 DAT_OUT
);

// Signals
logic [P_BPC-1:0]   clk_dat;

// Logic

    always_ff @ (posedge CLK_IN)
    begin
        if (WR_IN)
        begin
            case (SEL_IN)
                'd1 : 
                begin   
                    clk_dat <= B_DAT_IN;
                end

                'd2 : 
                begin   
                    clk_dat <= C_DAT_IN;
                end

                'd3 : 
                begin   
                    clk_dat <= D_DAT_IN;
                end

                'd4 : 
                begin   
                    clk_dat <= E_DAT_IN;
                end

                'd5 : 
                begin   
                    clk_dat <= F_DAT_IN;
                end

                'd6 : 
                begin   
                    clk_dat <= G_DAT_IN;
                end

                default : 
                begin   
                    clk_dat <= A_DAT_IN;
                end

            endcase
        end
    end

// Outputs
    assign DAT_OUT = clk_dat;

endmodule

`default_nettype wire
