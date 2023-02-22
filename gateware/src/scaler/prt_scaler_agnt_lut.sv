/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Scaler agent lookup
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
    solely for internal business purstepes for the term and conditions of the License. 
    You are also allowed to create Modifications for internal business purstepes, but explicitly only under the conditions of art. 3.2.
    You are, however, obliged to pay the License Fees to Parretto for the use of the IP-core, or any Modification, in, or embodied in, 
    a physical or non-tangible product or service that has substantial commercial, industrial or non-consumer uses. 
*/

`default_nettype none

module prt_scaler_agnt_lut
#(
    parameter P_ID = 0,             // Index
    parameter P_COEF = 5,           // Coefficient width
    parameter P_MUX = 4,            // MUX width
    parameter P_DAT = 4             // Data width
)
(
   input wire               CLK_IN,
   input wire  [7:0]        SEL_IN,
   output wire [P_DAT-1:0]  DAT_OUT 
);

// Sinals
logic [$size(SEL_IN)-1:0]   clk_sel;    // Ratio [2], row_idx[3], blk_idx[3]
logic [P_DAT-1:0]           clk_dat;   // mux3, mux2, mux1, mux0, coef3, coef2, coef1, coef0

// Logic
    always_ff @ (posedge CLK_IN)
    begin
        clk_sel <= SEL_IN;
    end

generate

    // Pixel 1
    if (P_ID == 1) 
    begin : gen_lut_p1
        always_ff @ (posedge CLK_IN)
        begin
            case (clk_sel)
                // Ratio 3/2
                // Ratio [2], row_idx[3], blk_idx[3] - mux3, mux2, mux1, mux0, coef3, coef2, coef1, coef0
                {2'd0, 3'd0, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(3)), (P_COEF'(2))};
                {2'd0, 3'd0, 3'd1} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(5)), (P_COEF'(4))};
                {2'd0, 3'd0, 3'd2} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(4)), (P_COEF'(5))};
                {2'd0, 3'd0, 3'd3} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(3)), (P_COEF'(2))};

                {2'd0, 3'd1, 3'd0} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(9)), (P_COEF'(8)), (P_COEF'(7)), (P_COEF'(6))};
                {2'd0, 3'd1, 3'd1} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(13)), (P_COEF'(12)), (P_COEF'(11)), (P_COEF'(10))};
                {2'd0, 3'd1, 3'd2} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(12)), (P_COEF'(13)), (P_COEF'(10)), (P_COEF'(11))};
                {2'd0, 3'd1, 3'd3} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(9)), (P_COEF'(8)), (P_COEF'(7)), (P_COEF'(6))};

                {2'd0, 3'd2, 3'd0} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(13)), (P_COEF'(11)), (P_COEF'(12)), (P_COEF'(10))};
                {2'd0, 3'd2, 3'd1} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(17)), (P_COEF'(16)), (P_COEF'(15)), (P_COEF'(14))};
                {2'd0, 3'd2, 3'd2} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(16)), (P_COEF'(17)), (P_COEF'(14)), (P_COEF'(15))};
                {2'd0, 3'd2, 3'd3} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(13)), (P_COEF'(11)), (P_COEF'(12)), (P_COEF'(10))};

                {2'd0, 3'd3, 3'd0} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(12)), (P_COEF'(10)), (P_COEF'(13)), (P_COEF'(11))};
                {2'd0, 3'd3, 3'd1} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(16)), (P_COEF'(14)), (P_COEF'(17)), (P_COEF'(15))};
                {2'd0, 3'd3, 3'd2} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(14)), (P_COEF'(15)), (P_COEF'(16)), (P_COEF'(17))};
                {2'd0, 3'd3, 3'd3} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(12)), (P_COEF'(10)), (P_COEF'(13)), (P_COEF'(11))};

                // Ratio 2/1
                // Ratio [2], row_idx[3], blk_idx[3] - mux3, mux2, mux1, mux0, coef3, coef2, coef1, coef0
                {2'd1, 3'd0, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(2)), (P_COEF'(1))};
                {2'd1, 3'd0, 3'd1} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(2)), (P_COEF'(1))};
                {2'd1, 3'd0, 3'd2} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(2)), (P_COEF'(1))};

                {2'd1, 3'd1, 3'd0} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(3)), (P_COEF'(2)), (P_COEF'(2)), (P_COEF'(1))};
                {2'd1, 3'd1, 3'd1} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(3)), (P_COEF'(2)), (P_COEF'(2)), (P_COEF'(1))};
                {2'd1, 3'd1, 3'd2} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(3)), (P_COEF'(2)), (P_COEF'(2)), (P_COEF'(1))};

                {2'd1, 3'd2, 3'd0} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(2)), (P_COEF'(1)), (P_COEF'(3)), (P_COEF'(2))};
                {2'd1, 3'd2, 3'd1} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(2)), (P_COEF'(1)), (P_COEF'(3)), (P_COEF'(2))};
                {2'd1, 3'd2, 3'd2} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(2)), (P_COEF'(1)), (P_COEF'(3)), (P_COEF'(2))};

                // Ratio 3/1
                // Ratio [2], row_idx[3], blk_idx[3] - mux3, mux2, mux1, mux0, coef3, coef2, coef1, coef0
                {2'd2, 3'd0, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(0)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(1))};
                {2'd2, 3'd0, 3'd1} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(3)), (P_COEF'(2))};
                {2'd2, 3'd0, 3'd2} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(2)), (P_COEF'(3))};
                {2'd2, 3'd0, 3'd3} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(1))};

                {2'd2, 3'd1, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(0)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(1))};
                {2'd2, 3'd1, 3'd1} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(3)), (P_COEF'(2))};
                {2'd2, 3'd1, 3'd2} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(2)), (P_COEF'(3))};
                {2'd2, 3'd1, 3'd3} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(1))};

                {2'd2, 3'd2, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(8)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(7)), (P_COEF'(6))};
                {2'd2, 3'd2, 3'd1} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(11)), (P_COEF'(10)), (P_COEF'(9)), (P_COEF'(8))};
                {2'd2, 3'd2, 3'd2} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(10)), (P_COEF'(11)), (P_COEF'(8)), (P_COEF'(9))};
                {2'd2, 3'd2, 3'd3} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(9)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(7)), (P_COEF'(6))};

                {2'd2, 3'd3, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(8)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(6)), (P_COEF'(7))};
                {2'd2, 3'd3, 3'd1} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(9)), (P_COEF'(8)), (P_COEF'(11)), (P_COEF'(10))};
                {2'd2, 3'd3, 3'd2} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(8)), (P_COEF'(9)), (P_COEF'(10)), (P_COEF'(11))};
                {2'd2, 3'd3, 3'd3} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(9)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(6)), (P_COEF'(7))};

                // Ratio 4/3
                // Ratio [2], row_idx[3], blk_idx[3] - mux3, mux2, mux1, mux0, coef3, coef2, coef1, coef0
                {2'd3, 3'd0, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(3)), (P_COEF'(2))};
                {2'd3, 3'd0, 3'd1} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(3)), (P_COEF'(2))};
                {2'd3, 3'd0, 3'd2} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(3)), (P_COEF'(2))};

                {2'd3, 3'd1, 3'd0} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(10)), (P_COEF'(9)), (P_COEF'(9)), (P_COEF'(8))};
                {2'd3, 3'd1, 3'd1} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(10)), (P_COEF'(9)), (P_COEF'(9)), (P_COEF'(8))};
                {2'd3, 3'd1, 3'd2} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(10)), (P_COEF'(9)), (P_COEF'(9)), (P_COEF'(8))};

                {2'd3, 3'd2, 3'd0} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(28)), (P_COEF'(27)), (P_COEF'(26)), (P_COEF'(25))};
                {2'd3, 3'd2, 3'd1} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(28)), (P_COEF'(27)), (P_COEF'(26)), (P_COEF'(25))};
                {2'd3, 3'd2, 3'd2} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(28)), (P_COEF'(27)), (P_COEF'(26)), (P_COEF'(25))};

                {2'd3, 3'd3, 3'd0} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(46)), (P_COEF'(45)), (P_COEF'(44)), (P_COEF'(43))};
                {2'd3, 3'd3, 3'd1} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(46)), (P_COEF'(45)), (P_COEF'(44)), (P_COEF'(43))};
                {2'd3, 3'd3, 3'd2} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(46)), (P_COEF'(45)), (P_COEF'(44)), (P_COEF'(43))};

                {2'd3, 3'd4, 3'd0} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(64)), (P_COEF'(63)), (P_COEF'(62)), (P_COEF'(61))};
                {2'd3, 3'd4, 3'd1} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(64)), (P_COEF'(63)), (P_COEF'(62)), (P_COEF'(61))};
                {2'd3, 3'd4, 3'd2} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(64)), (P_COEF'(63)), (P_COEF'(62)), (P_COEF'(61))};

                default : clk_dat <= 'd0;
            endcase
        end
    end

    // Pixel 2
    else if (P_ID == 2) 
    begin : gen_lut_p2
        always_ff @ (posedge CLK_IN)
        begin
            case (clk_sel)
                // Ratio 3/2
                // Ratio [2], row_idx[3], blk_idx[3] - mux3, mux2, mux1, mux0, coef3, coef2, coef1, coef0
                {2'd0, 3'd0, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(5)), (P_COEF'(4))};
                {2'd0, 3'd0, 3'd1} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(4)), (P_COEF'(5))};
                {2'd0, 3'd0, 3'd2} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(3)), (P_COEF'(2))};
                {2'd0, 3'd0, 3'd3} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(5)), (P_COEF'(4))};

                {2'd0, 3'd1, 3'd0} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(13)), (P_COEF'(12)), (P_COEF'(11)), (P_COEF'(10))};
                {2'd0, 3'd1, 3'd1} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(12)), (P_COEF'(13)), (P_COEF'(10)), (P_COEF'(11))};
                {2'd0, 3'd1, 3'd2} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(9)), (P_COEF'(8)), (P_COEF'(7)), (P_COEF'(6))};
                {2'd0, 3'd1, 3'd3} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(13)), (P_COEF'(12)), (P_COEF'(11)), (P_COEF'(10))};

                {2'd0, 3'd2, 3'd0} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(17)), (P_COEF'(16)), (P_COEF'(15)), (P_COEF'(14))};
                {2'd0, 3'd2, 3'd1} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(16)), (P_COEF'(17)), (P_COEF'(14)), (P_COEF'(15))};
                {2'd0, 3'd2, 3'd2} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(13)), (P_COEF'(11)), (P_COEF'(12)), (P_COEF'(10))};
                {2'd0, 3'd2, 3'd3} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(17)), (P_COEF'(16)), (P_COEF'(15)), (P_COEF'(14))};

                {2'd0, 3'd3, 3'd0} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(15)), (P_COEF'(14)), (P_COEF'(17)), (P_COEF'(16))};
                {2'd0, 3'd3, 3'd1} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(14)), (P_COEF'(15)), (P_COEF'(16)), (P_COEF'(17))};
                {2'd0, 3'd3, 3'd2} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(12)), (P_COEF'(10)), (P_COEF'(13)), (P_COEF'(11))};
                {2'd0, 3'd3, 3'd3} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(15)), (P_COEF'(14)), (P_COEF'(17)), (P_COEF'(16))};

                // Ratio 2/1
                // Ratio [2], row_idx[3], blk_idx[3] - mux3, mux2, mux1, mux0, coef3, coef2, coef1, coef0
                {2'd1, 3'd0, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(1)), (P_COEF'(2))};
                {2'd1, 3'd0, 3'd1} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(1)), (P_COEF'(2))};
                {2'd1, 3'd0, 3'd2} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(1)), (P_COEF'(2))};

                {2'd1, 3'd1, 3'd0} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(2)), (P_COEF'(3)), (P_COEF'(1)), (P_COEF'(2))};
                {2'd1, 3'd1, 3'd1} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(2)), (P_COEF'(3)), (P_COEF'(1)), (P_COEF'(2))};
                {2'd1, 3'd1, 3'd2} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(2)), (P_COEF'(3)), (P_COEF'(1)), (P_COEF'(2))};

                {2'd1, 3'd2, 3'd0} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(1)), (P_COEF'(2)), (P_COEF'(2)), (P_COEF'(3))};
                {2'd1, 3'd2, 3'd1} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(1)), (P_COEF'(2)), (P_COEF'(2)), (P_COEF'(3))};
                {2'd1, 3'd2, 3'd2} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(1)), (P_COEF'(2)), (P_COEF'(2)), (P_COEF'(3))};

                // Ratio 3/1
                // Ratio [2], row_idx[3], blk_idx[3] - mux3, mux2, mux1, mux0, coef3, coef2, coef1, coef0
                {2'd2, 3'd0, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(3)), (P_COEF'(2))};
                {2'd2, 3'd0, 3'd1} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(2)), (P_COEF'(3))};
                {2'd2, 3'd0, 3'd2} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(1))};
                {2'd2, 3'd0, 3'd3} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(3)), (P_COEF'(2))};

                {2'd2, 3'd1, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(3)), (P_COEF'(2))};
                {2'd2, 3'd1, 3'd1} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(2)), (P_COEF'(3))};
                {2'd2, 3'd1, 3'd2} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(1))};
                {2'd2, 3'd1, 3'd3} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(3)), (P_COEF'(2))};

                {2'd2, 3'd2, 3'd0} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(11)), (P_COEF'(10)), (P_COEF'(9)), (P_COEF'(8))};
                {2'd2, 3'd2, 3'd1} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(10)), (P_COEF'(11)), (P_COEF'(8)), (P_COEF'(9))};
                {2'd2, 3'd2, 3'd2} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(9)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(7)), (P_COEF'(6))};
                {2'd2, 3'd2, 3'd3} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(11)), (P_COEF'(10)), (P_COEF'(9)), (P_COEF'(8))};

                {2'd2, 3'd3, 3'd0} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(10)), (P_COEF'(8)), (P_COEF'(11)), (P_COEF'(9))};
                {2'd2, 3'd3, 3'd1} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(8)), (P_COEF'(9)), (P_COEF'(10)), (P_COEF'(11))};
                {2'd2, 3'd3, 3'd2} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(9)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(6)), (P_COEF'(7))};
                {2'd2, 3'd3, 3'd3} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(9)), (P_COEF'(8)), (P_COEF'(11)), (P_COEF'(10))};

                // Ratio 4/3
                // Ratio [2], row_idx[3], blk_idx[3] - mux3, mux2, mux1, mux0, coef3, coef2, coef1, coef0
                {2'd3, 3'd0, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(4)), (P_COEF'(3))};
                {2'd3, 3'd0, 3'd1} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(4)), (P_COEF'(3))};
                {2'd3, 3'd0, 3'd2} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(4)), (P_COEF'(3))};

                {2'd3, 3'd1, 3'd0} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(14)), (P_COEF'(13)), (P_COEF'(12)), (P_COEF'(11))};
                {2'd3, 3'd1, 3'd1} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(14)), (P_COEF'(13)), (P_COEF'(12)), (P_COEF'(11))};
                {2'd3, 3'd1, 3'd2} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(14)), (P_COEF'(13)), (P_COEF'(12)), (P_COEF'(11))};

                {2'd3, 3'd2, 3'd0} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(32)), (P_COEF'(31)), (P_COEF'(30)), (P_COEF'(29))};
                {2'd3, 3'd2, 3'd1} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(32)), (P_COEF'(31)), (P_COEF'(30)), (P_COEF'(29))};
                {2'd3, 3'd2, 3'd2} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(32)), (P_COEF'(31)), (P_COEF'(30)), (P_COEF'(29))};

                {2'd3, 3'd3, 3'd0} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(50)), (P_COEF'(49)), (P_COEF'(48)), (P_COEF'(47))};
                {2'd3, 3'd3, 3'd1} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(50)), (P_COEF'(49)), (P_COEF'(48)), (P_COEF'(47))};
                {2'd3, 3'd3, 3'd2} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(50)), (P_COEF'(49)), (P_COEF'(48)), (P_COEF'(47))};

                {2'd3, 3'd4, 3'd0} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(68)), (P_COEF'(67)), (P_COEF'(66)), (P_COEF'(65))};
                {2'd3, 3'd4, 3'd1} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(68)), (P_COEF'(67)), (P_COEF'(66)), (P_COEF'(65))};
                {2'd3, 3'd4, 3'd2} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(68)), (P_COEF'(67)), (P_COEF'(66)), (P_COEF'(65))};

                default : clk_dat <= 'd0;
            endcase
        end
    end

    // Pixel 3
    else if (P_ID == 3) 
    begin : gen_lut_p3
        always_ff @ (posedge CLK_IN)
        begin
            case (clk_sel)
                // Ratio 3/2
                // Ratio [2], row_idx[3], blk_idx[3] - mux3, mux2, mux1, mux0, coef3, coef2, coef1, coef0
                {2'd0, 3'd0, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(4)), (P_COEF'(5))};
                {2'd0, 3'd0, 3'd1} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(3)), (P_COEF'(2))};
                {2'd0, 3'd0, 3'd2} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(5)), (P_COEF'(4))};
                {2'd0, 3'd0, 3'd3} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(4)), (P_COEF'(5))};

                {2'd0, 3'd1, 3'd0} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(12)), (P_COEF'(13)), (P_COEF'(10)), (P_COEF'(11))};
                {2'd0, 3'd1, 3'd1} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(9)), (P_COEF'(8)), (P_COEF'(7)), (P_COEF'(6))};
                {2'd0, 3'd1, 3'd2} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(13)), (P_COEF'(12)), (P_COEF'(11)), (P_COEF'(10))};
                {2'd0, 3'd1, 3'd3} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(12)), (P_COEF'(13)), (P_COEF'(10)), (P_COEF'(11))};

                {2'd0, 3'd2, 3'd0} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(16)), (P_COEF'(17)), (P_COEF'(14)), (P_COEF'(15))};
                {2'd0, 3'd2, 3'd1} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(13)), (P_COEF'(11)), (P_COEF'(12)), (P_COEF'(10))};
                {2'd0, 3'd2, 3'd2} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(17)), (P_COEF'(16)), (P_COEF'(15)), (P_COEF'(14))};
                {2'd0, 3'd2, 3'd3} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(16)), (P_COEF'(17)), (P_COEF'(14)), (P_COEF'(15))};

                {2'd0, 3'd3, 3'd0} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(14)), (P_COEF'(15)), (P_COEF'(16)), (P_COEF'(17))};
                {2'd0, 3'd3, 3'd1} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(12)), (P_COEF'(10)), (P_COEF'(13)), (P_COEF'(11))};
                {2'd0, 3'd3, 3'd2} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(15)), (P_COEF'(14)), (P_COEF'(17)), (P_COEF'(16))};
                {2'd0, 3'd3, 3'd3} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(14)), (P_COEF'(15)), (P_COEF'(16)), (P_COEF'(17))};

                // Ratio 2/1
                // Ratio [2], row_idx[3], blk_idx[3] - mux3, mux2, mux1, mux0, coef3, coef2, coef1, coef0
                {2'd1, 3'd0, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(2)), (P_COEF'(1))};
                {2'd1, 3'd0, 3'd1} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(2)), (P_COEF'(1))};
                {2'd1, 3'd0, 3'd2} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(2)), (P_COEF'(1))};

                {2'd1, 3'd1, 3'd0} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(3)), (P_COEF'(2)), (P_COEF'(2)), (P_COEF'(1))};
                {2'd1, 3'd1, 3'd1} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(3)), (P_COEF'(2)), (P_COEF'(2)), (P_COEF'(1))};
                {2'd1, 3'd1, 3'd2} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(3)), (P_COEF'(2)), (P_COEF'(2)), (P_COEF'(1))};

                {2'd1, 3'd2, 3'd0} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(2)), (P_COEF'(1)), (P_COEF'(3)), (P_COEF'(2))};
                {2'd1, 3'd2, 3'd1} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(2)), (P_COEF'(1)), (P_COEF'(3)), (P_COEF'(2))};
                {2'd1, 3'd2, 3'd2} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(2)), (P_COEF'(1)), (P_COEF'(3)), (P_COEF'(2))};

                // Ratio 3/1
                // Ratio [2], row_idx[3], blk_idx[3] - mux3, mux2, mux1, mux0, coef3, coef2, coef1, coef0
                {2'd2, 3'd0, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(2)), (P_COEF'(3))};
                {2'd2, 3'd0, 3'd1} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(1))};
                {2'd2, 3'd0, 3'd2} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(3)), (P_COEF'(2))};
                {2'd2, 3'd0, 3'd3} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(2)), (P_COEF'(3))};

                {2'd2, 3'd1, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(2)), (P_COEF'(3))};
                {2'd2, 3'd1, 3'd1} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(1))};
                {2'd2, 3'd1, 3'd2} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(3)), (P_COEF'(2))};
                {2'd2, 3'd1, 3'd3} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(2)), (P_COEF'(3))};

                {2'd2, 3'd2, 3'd0} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(10)), (P_COEF'(11)), (P_COEF'(8)), (P_COEF'(9))};
                {2'd2, 3'd2, 3'd1} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(9)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(7)), (P_COEF'(6))};
                {2'd2, 3'd2, 3'd2} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(11)), (P_COEF'(10)), (P_COEF'(9)), (P_COEF'(8))};
                {2'd2, 3'd2, 3'd3} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(10)), (P_COEF'(11)), (P_COEF'(8)), (P_COEF'(9))};

                {2'd2, 3'd3, 3'd0} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(8)), (P_COEF'(9)), (P_COEF'(10)), (P_COEF'(11))};
                {2'd2, 3'd3, 3'd1} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(9)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(6)), (P_COEF'(7))};
                {2'd2, 3'd3, 3'd2} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(9)), (P_COEF'(8)), (P_COEF'(11)), (P_COEF'(10))};
                {2'd2, 3'd3, 3'd3} : clk_dat <= {(P_MUX'(10)), (P_MUX'(9)), (P_MUX'(2)), (P_MUX'(1)), (P_COEF'(8)), (P_COEF'(9)), (P_COEF'(10)), (P_COEF'(11))};

                // Ratio 4/3
                // Ratio [2], row_idx[3], blk_idx[3] - mux3, mux2, mux1, mux0, coef3, coef2, coef1, coef0
                {2'd3, 3'd0, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(7)), (P_COEF'(6))};
                {2'd3, 3'd0, 3'd1} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(4)), (P_MUX'(3)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(7)), (P_COEF'(6))};
                {2'd3, 3'd0, 3'd2} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(4)), (P_MUX'(3)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(7)), (P_COEF'(6))};

                {2'd3, 3'd1, 3'd0} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(18)), (P_COEF'(17)), (P_COEF'(16)), (P_COEF'(15))};
                {2'd3, 3'd1, 3'd1} : clk_dat <= {(P_MUX'(12)), (P_MUX'(11)), (P_MUX'(4)), (P_MUX'(3)), (P_COEF'(18)), (P_COEF'(17)), (P_COEF'(16)), (P_COEF'(15))};
                {2'd3, 3'd1, 3'd2} : clk_dat <= {(P_MUX'(12)), (P_MUX'(11)), (P_MUX'(4)), (P_MUX'(3)), (P_COEF'(18)), (P_COEF'(17)), (P_COEF'(16)), (P_COEF'(15))};

                {2'd3, 3'd2, 3'd0} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(36)), (P_COEF'(35)), (P_COEF'(34)), (P_COEF'(33))};
                {2'd3, 3'd2, 3'd1} : clk_dat <= {(P_MUX'(12)), (P_MUX'(11)), (P_MUX'(4)), (P_MUX'(3)), (P_COEF'(36)), (P_COEF'(35)), (P_COEF'(34)), (P_COEF'(33))};
                {2'd3, 3'd2, 3'd2} : clk_dat <= {(P_MUX'(12)), (P_MUX'(11)), (P_MUX'(4)), (P_MUX'(3)), (P_COEF'(36)), (P_COEF'(35)), (P_COEF'(34)), (P_COEF'(33))};

                {2'd3, 3'd3, 3'd0} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(54)), (P_COEF'(53)), (P_COEF'(52)), (P_COEF'(51))};
                {2'd3, 3'd3, 3'd1} : clk_dat <= {(P_MUX'(12)), (P_MUX'(11)), (P_MUX'(4)), (P_MUX'(3)), (P_COEF'(54)), (P_COEF'(53)), (P_COEF'(52)), (P_COEF'(51))};
                {2'd3, 3'd3, 3'd2} : clk_dat <= {(P_MUX'(12)), (P_MUX'(11)), (P_MUX'(4)), (P_MUX'(3)), (P_COEF'(54)), (P_COEF'(53)), (P_COEF'(52)), (P_COEF'(51))};

                {2'd3, 3'd4, 3'd0} : clk_dat <= {(P_MUX'(11)), (P_MUX'(10)), (P_MUX'(3)), (P_MUX'(2)), (P_COEF'(72)), (P_COEF'(71)), (P_COEF'(70)), (P_COEF'(69))};
                {2'd3, 3'd4, 3'd1} : clk_dat <= {(P_MUX'(12)), (P_MUX'(11)), (P_MUX'(4)), (P_MUX'(3)), (P_COEF'(72)), (P_COEF'(71)), (P_COEF'(70)), (P_COEF'(69))};
                {2'd3, 3'd4, 3'd2} : clk_dat <= {(P_MUX'(12)), (P_MUX'(11)), (P_MUX'(4)), (P_MUX'(3)), (P_COEF'(72)), (P_COEF'(71)), (P_COEF'(70)), (P_COEF'(69))};

                default : clk_dat <= 'd0;
            endcase
        end
    end

    // Pixel 0
    else
    begin : gen_lut_p0
        always_ff @ (posedge CLK_IN)
        begin
            case (clk_sel)
                // Ratio 3/2
                // Ratio [2], row_idx[3], blk_idx[3] - mux3, mux2, mux1, mux0, coef3, coef2, coef1, coef0
                {2'd0, 3'd0, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(0)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(1))};
                {2'd0, 3'd0, 3'd1} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(3)), (P_COEF'(2))};
                {2'd0, 3'd0, 3'd2} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(5)), (P_COEF'(4))};
                {2'd0, 3'd0, 3'd3} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(4)), (P_COEF'(5))};

                {2'd0, 3'd1, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(8)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(3)), (P_COEF'(2))};
                {2'd0, 3'd1, 3'd1} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(9)), (P_COEF'(8)), (P_COEF'(7)), (P_COEF'(6))};
                {2'd0, 3'd1, 3'd2} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(13)), (P_COEF'(12)), (P_COEF'(11)), (P_COEF'(10))};
                {2'd0, 3'd1, 3'd3} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(12)), (P_COEF'(13)), (P_COEF'(10)), (P_COEF'(11))};

                {2'd0, 3'd2, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(8)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(5)), (P_COEF'(4))};
                {2'd0, 3'd2, 3'd1} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(13)), (P_COEF'(11)), (P_COEF'(12)), (P_COEF'(10))};
                {2'd0, 3'd2, 3'd2} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(17)), (P_COEF'(16)), (P_COEF'(15)), (P_COEF'(14))};
                {2'd0, 3'd2, 3'd3} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(16)), (P_COEF'(17)), (P_COEF'(14)), (P_COEF'(15))};

                {2'd0, 3'd3, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(8)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(4)), (P_COEF'(5))};
                {2'd0, 3'd3, 3'd1} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(12)), (P_COEF'(10)), (P_COEF'(13)), (P_COEF'(11))};
                {2'd0, 3'd3, 3'd2} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(15)), (P_COEF'(14)), (P_COEF'(17)), (P_COEF'(16))};
                {2'd0, 3'd3, 3'd3} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(14)), (P_COEF'(15)), (P_COEF'(16)), (P_COEF'(17))};

                // Ratio 2/1
                // Ratio [2], row_idx[3], blk_idx[3] - mux3, mux2, mux1, mux0, coef3, coef2, coef1, coef0
                {2'd1, 3'd0, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(0)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(1))};
                {2'd1, 3'd0, 3'd1} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(1)), (P_COEF'(2))};
                {2'd1, 3'd0, 3'd2} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(1)), (P_COEF'(2))};

                {2'd1, 3'd1, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(8)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(2)), (P_COEF'(1))};
                {2'd1, 3'd1, 3'd1} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(2)), (P_COEF'(3)), (P_COEF'(1)), (P_COEF'(2))};
                {2'd1, 3'd1, 3'd2} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(2)), (P_COEF'(3)), (P_COEF'(1)), (P_COEF'(2))};

                {2'd1, 3'd2, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(8)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(1)), (P_COEF'(2))};
                {2'd1, 3'd2, 3'd1} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(1)), (P_COEF'(2)), (P_COEF'(2)), (P_COEF'(3))};
                {2'd1, 3'd2, 3'd2} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(1)), (P_COEF'(2)), (P_COEF'(2)), (P_COEF'(3))};

                // Ratio 3/1
                // Ratio [2], row_idx[3], blk_idx[3] - mux3, mux2, mux1, mux0, coef3, coef2, coef1, coef0
                {2'd2, 3'd0, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(0)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(1))};
                {2'd2, 3'd0, 3'd1} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(0)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(1))};
                {2'd2, 3'd0, 3'd2} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(3)), (P_COEF'(2))};
                {2'd2, 3'd0, 3'd3} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(2)), (P_COEF'(3))};

                {2'd2, 3'd1, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(0)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(1))};
                {2'd2, 3'd1, 3'd1} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(0)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(1))};
                {2'd2, 3'd1, 3'd2} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(3)), (P_COEF'(2))};
                {2'd2, 3'd1, 3'd3} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(2)), (P_COEF'(3))};

                {2'd2, 3'd2, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(8)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(5)), (P_COEF'(4))};
                {2'd2, 3'd2, 3'd1} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(8)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(7)), (P_COEF'(6))};
                {2'd2, 3'd2, 3'd2} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(11)), (P_COEF'(10)), (P_COEF'(9)), (P_COEF'(8))};
                {2'd2, 3'd2, 3'd3} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(10)), (P_COEF'(11)), (P_COEF'(8)), (P_COEF'(9))};

                {2'd2, 3'd3, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(8)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(4)), (P_COEF'(5))};
                {2'd2, 3'd3, 3'd1} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(8)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(6)), (P_COEF'(7))};
                {2'd2, 3'd3, 3'd2} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(9)), (P_COEF'(8)), (P_COEF'(11)), (P_COEF'(10))};
                {2'd2, 3'd3, 3'd3} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(8)), (P_COEF'(9)), (P_COEF'(10)), (P_COEF'(11))};

                // Ratio 4/3
                // Ratio [2], row_idx[3], blk_idx[3] - mux3, mux2, mux1, mux0, coef3, coef2, coef1, coef0
                {2'd3, 3'd0, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(0)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(1))};
                {2'd3, 3'd0, 3'd1} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(1))};
                {2'd3, 3'd0, 3'd2} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(0)), (P_MUX'(1)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(1))};

                {2'd3, 3'd1, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(8)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(3)), (P_COEF'(2))};
                {2'd3, 3'd1, 3'd1} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(22)), (P_COEF'(21)), (P_COEF'(20)), (P_COEF'(19))};
                {2'd3, 3'd1, 3'd2} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(22)), (P_COEF'(21)), (P_COEF'(20)), (P_COEF'(19))};

                {2'd3, 3'd2, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(8)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(24)), (P_COEF'(23))};
                {2'd3, 3'd2, 3'd1} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(40)), (P_COEF'(39)), (P_COEF'(38)), (P_COEF'(37))};
                {2'd3, 3'd2, 3'd2} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(40)), (P_COEF'(39)), (P_COEF'(38)), (P_COEF'(37))};

                {2'd3, 3'd3, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(8)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(42)), (P_COEF'(41))};
                {2'd3, 3'd3, 3'd1} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(58)), (P_COEF'(57)), (P_COEF'(56)), (P_COEF'(55))};
                {2'd3, 3'd3, 3'd2} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(58)), (P_COEF'(57)), (P_COEF'(56)), (P_COEF'(55))};

                {2'd3, 3'd4, 3'd0} : clk_dat <= {(P_MUX'(0)), (P_MUX'(0)), (P_MUX'(8)), (P_MUX'(0)), (P_COEF'(0)), (P_COEF'(0)), (P_COEF'(60)), (P_COEF'(59))};
                {2'd3, 3'd4, 3'd1} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(76)), (P_COEF'(75)), (P_COEF'(74)), (P_COEF'(73))};
                {2'd3, 3'd4, 3'd2} : clk_dat <= {(P_MUX'(9)), (P_MUX'(8)), (P_MUX'(1)), (P_MUX'(0)), (P_COEF'(76)), (P_COEF'(75)), (P_COEF'(74)), (P_COEF'(73))};

                default : clk_dat <= 'd0;
            endcase
        end
    end
endgenerate

assign DAT_OUT = clk_dat;

endmodule

`default_nettype wire
