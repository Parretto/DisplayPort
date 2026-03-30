/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP RX Video - link mapper
    (c) 2021 - 2026 by Parretto B.V.

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
module prt_dprx_vid_lmap
#(
    // Video
    parameter                           P_LANES = 4,                    // Lanes
    parameter                           P_SPL = 2,      	            // Symbols per lane
    parameter                           P_STRIPES = 4                   // Stripes
)
(
    input wire                          RST_IN,                         // Reset
    input wire                          CLK_IN,                         // Clock

    // Input
    input wire [1:0]                    LANES_IN,                       // Active lanes
    input wire                          STR_IN,                         // Start
    input wire [7:0]                    DAT_IN[P_LANES][P_SPL],         // Data in
    input wire [P_SPL-1:0]              VLD_IN[P_LANES],                // Valid in

    // Output
    output wire [7:0]                   DAT_OUT[P_LANES][P_STRIPES],    // Data out
    output wire [P_STRIPES-1:0]         VLD_OUT[P_LANES]                // Valid out
);

//-----
// Structure
//-----
typedef struct {
    logic [4:0]                     cnt[P_LANES][P_SPL];
    logic [P_STRIPES-1:0]           wr[P_LANES];
    logic [7:0]                     dat[P_LANES][P_STRIPES];
} map_struct;

//-----
// Signals
//-----
map_struct      clk_map;


// Counters 
// The counters are used to map the link data into the stripe.
generate
    if (P_SPL == 4)
    begin : gen_map_cnt_4spl

        always_ff @ (posedge CLK_IN)
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                for (int j = 0; j < P_SPL; j++)
                begin
                    // Clear 
                    if (STR_IN)
                        clk_map.cnt[i][j] <= 0;

                    // Increment
                    else if (VLD_IN[i][j])
                    begin
                        // Overflow
                        if ( ((LANES_IN == 'd1) && (clk_map.cnt[i][j] == 'd11)) || ((LANES_IN == 'd2) && (clk_map.cnt[i][j] == 'd5)) ) 
                            clk_map.cnt[i][j] <= 0;

                        else
                            clk_map.cnt[i][j] <= clk_map.cnt[i][j] + 'd1;
                    end
                end
            end
        end

    end

    else
    begin : gen_map_cnt_2spl

        always_ff @ (posedge CLK_IN)
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                for (int j = 0; j < P_SPL; j++)
                begin
                    // Clear 
                    if (STR_IN)
                        clk_map.cnt[i][j] <= 0;

                    // Increment
                    else if (VLD_IN[i][j])
                    begin
                        // Overflow
                        if ( ((LANES_IN == 'd1) && (clk_map.cnt[i][j] == 'd23)) || ((LANES_IN == 'd2) && (clk_map.cnt[i][j] == 'd11)) || ((LANES_IN == 'd3) && (clk_map.cnt[i][j] == 'd1)) ) 
                            clk_map.cnt[i][j] <= 0;

                        else
                            clk_map.cnt[i][j] <= clk_map.cnt[i][j] + 'd1;
                    end
                end
            end
        end

    end
endgenerate

generate
    if (P_SPL == 4)
    begin : gen_map_4spl
        
        always_ff @ (posedge CLK_IN)
        begin
            // 1 lane
            if (LANES_IN == 'd1)
            begin

            // Stripe 0

                // R0
                if ((clk_map.cnt[0][0] == 'd0) && VLD_IN[0][0])
                begin
                    clk_map.dat[0][0] <= DAT_IN[0][0];
                    clk_map.wr[0][0] <= 1;
                end

                // G4
                else if ((clk_map.cnt[0][1] == 'd3) && VLD_IN[0][1])
                begin
                    clk_map.dat[0][0] <= DAT_IN[0][1];
                    clk_map.wr[0][0] <= 1;
                end

                // B8
                else if ((clk_map.cnt[0][2] == 'd6) && VLD_IN[0][2])
                begin
                    clk_map.dat[0][0] <= DAT_IN[0][2];
                    clk_map.wr[0][0] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[0][0] <= 0;
                    clk_map.wr[0][0] <= 0;
                end

            // Stripe 1

                // G0
                if ((clk_map.cnt[0][1] == 'd0) && VLD_IN[0][1])
                begin
                    clk_map.dat[0][1] <= DAT_IN[0][1];
                    clk_map.wr[0][1] <= 1;
                end

                // B4
                else if ((clk_map.cnt[0][2] == 'd3) && VLD_IN[0][2])
                begin
                    clk_map.dat[0][1] <= DAT_IN[0][2];
                    clk_map.wr[0][1] <= 1;
                end

                // R12
                else if ((clk_map.cnt[0][0] == 'd9) && VLD_IN[0][0])
                begin
                    clk_map.dat[0][1] <= DAT_IN[0][0];
                    clk_map.wr[0][1] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[0][1] <= 0;
                    clk_map.wr[0][1] <= 0;
                end

            // Stripe 2

                // B0
                if ((clk_map.cnt[0][2] == 'd0) && VLD_IN[0][2])
                begin
                    clk_map.dat[0][2] <= DAT_IN[0][2];
                    clk_map.wr[0][2] <= 1;
                end

                // R8
                else if ((clk_map.cnt[0][0] == 'd6) && VLD_IN[0][0])
                begin
                    clk_map.dat[0][2] <= DAT_IN[0][0];
                    clk_map.wr[0][2] <= 1;
                end

                // G12
                else if ((clk_map.cnt[0][1] == 'd9) && VLD_IN[0][1])
                begin
                    clk_map.dat[0][2] <= DAT_IN[0][1];
                    clk_map.wr[0][2] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[0][2] <= 0;
                    clk_map.wr[0][2] <= 0;
                end

            // Stripe 3

                // R4
                if ((clk_map.cnt[0][0] == 'd3) && VLD_IN[0][0])
                begin
                    clk_map.dat[0][3] <= DAT_IN[0][0];
                    clk_map.wr[0][3] <= 1;
                end

                // G8
                else if ((clk_map.cnt[0][1] == 'd6) && VLD_IN[0][1])
                begin
                    clk_map.dat[0][3] <= DAT_IN[0][1];
                    clk_map.wr[0][3] <= 1;
                end

                // B12
                else if ((clk_map.cnt[0][2] == 'd9) && VLD_IN[0][2])
                begin
                    clk_map.dat[0][3] <= DAT_IN[0][2];
                    clk_map.wr[0][3] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[0][3] <= 0;
                    clk_map.wr[0][3] <= 0;
                end

            // Stripe 4

                // R1
                if ((clk_map.cnt[0][3] == 'd0) && VLD_IN[0][3])
                begin
                    clk_map.dat[1][0] <= DAT_IN[0][3];
                    clk_map.wr[1][0] <= 1;
                end

                // G5
                else if ((clk_map.cnt[0][0] == 'd4) && VLD_IN[0][0])
                begin
                    clk_map.dat[1][0] <= DAT_IN[0][0];
                    clk_map.wr[1][0] <= 1;
                end

                // B9
                else if ((clk_map.cnt[0][1] == 'd7) && VLD_IN[0][1])
                begin
                    clk_map.dat[1][0] <= DAT_IN[0][1];
                    clk_map.wr[1][0] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[1][0] <= 0;
                    clk_map.wr[1][0] <= 0;
                end

            // Stripe 5

                // G1
                if ((clk_map.cnt[0][0] == 'd1) && VLD_IN[0][0])
                begin
                    clk_map.dat[1][1] <= DAT_IN[0][0];
                    clk_map.wr[1][1] <= 1;
                end

                // B5
                else if ((clk_map.cnt[0][1] == 'd4) && VLD_IN[0][1])
                begin
                    clk_map.dat[1][1] <= DAT_IN[0][1];
                    clk_map.wr[1][1] <= 1;
                end

                // R13
                else if ((clk_map.cnt[0][3] == 'd9) && VLD_IN[0][3])
                begin
                    clk_map.dat[1][1] <= DAT_IN[0][3];
                    clk_map.wr[1][1] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[1][1] <= 0;
                    clk_map.wr[1][1] <= 0;
                end

            // Stripe 6

                // B1
                if ((clk_map.cnt[0][1] == 'd1) && VLD_IN[0][1])
                begin
                    clk_map.dat[1][2] <= DAT_IN[0][1];
                    clk_map.wr[1][2] <= 1;
                end

                // R9
                else if ((clk_map.cnt[0][3] == 'd6) && VLD_IN[0][3])
                begin
                    clk_map.dat[1][2] <= DAT_IN[0][3];
                    clk_map.wr[1][2] <= 1;
                end

                // G13
                else if ((clk_map.cnt[0][0] == 'd10) && VLD_IN[0][0])
                begin
                    clk_map.dat[1][2] <= DAT_IN[0][0];
                    clk_map.wr[1][2] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[1][2] <= 0;
                    clk_map.wr[1][2] <= 0;
                end

            // Stripe 7

                // R5
                if ((clk_map.cnt[0][3] == 'd3) && VLD_IN[0][3])
                begin
                    clk_map.dat[1][3] <= DAT_IN[0][3];
                    clk_map.wr[1][3] <= 1;
                end

                // G9
                else if ((clk_map.cnt[0][0] == 'd7) && VLD_IN[0][0])
                begin
                    clk_map.dat[1][3] <= DAT_IN[0][0];
                    clk_map.wr[1][3] <= 1;
                end

                // B13
                else if ((clk_map.cnt[0][1] == 'd10) && VLD_IN[0][1])
                begin
                    clk_map.dat[1][3] <= DAT_IN[0][1];
                    clk_map.wr[1][3] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[1][3] <= 0;
                    clk_map.wr[1][3] <= 0;
                end

            // Stripe 8

                // R2
                if ((clk_map.cnt[0][2] == 'd1) && VLD_IN[0][2])
                begin
                    clk_map.dat[2][0] <= DAT_IN[0][2];
                    clk_map.wr[2][0] <= 1;
                end

                // G6
                else if ((clk_map.cnt[0][3] == 'd4) && VLD_IN[0][3])
                begin
                    clk_map.dat[2][0] <= DAT_IN[0][3];
                    clk_map.wr[2][0] <= 1;
                end

                // B10
                else if ((clk_map.cnt[0][0] == 'd8) && VLD_IN[0][0])
                begin
                    clk_map.dat[2][0] <= DAT_IN[0][0];
                    clk_map.wr[2][0] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[2][0] <= 0;
                    clk_map.wr[2][0] <= 0;
                end

            // Stripe 9

                // G2
                if ((clk_map.cnt[0][3] == 'd1) && VLD_IN[0][3])
                begin
                    clk_map.dat[2][1] <= DAT_IN[0][3];
                    clk_map.wr[2][1] <= 1;
                end

                // B6
                else if ((clk_map.cnt[0][0] == 'd5) && VLD_IN[0][0])
                begin
                    clk_map.dat[2][1] <= DAT_IN[0][0];
                    clk_map.wr[2][1] <= 1;
                end

                // R14
                else if ((clk_map.cnt[0][2] == 'd10) && VLD_IN[0][2])
                begin
                    clk_map.dat[2][1] <= DAT_IN[0][2];
                    clk_map.wr[2][1] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[2][1] <= 0;
                    clk_map.wr[2][1] <= 0;
                end

            // Stripe 10

                // B2
                if ((clk_map.cnt[0][0] == 'd2) && VLD_IN[0][0])
                begin
                    clk_map.dat[2][2] <= DAT_IN[0][0];
                    clk_map.wr[2][2] <= 1;
                end

                // R10
                else if ((clk_map.cnt[0][2] == 'd7) && VLD_IN[0][2])
                begin
                    clk_map.dat[2][2] <= DAT_IN[0][2];
                    clk_map.wr[2][2] <= 1;
                end

                // G14
                else if ((clk_map.cnt[0][3] == 'd10) && VLD_IN[0][3])
                begin
                    clk_map.dat[2][2] <= DAT_IN[0][3];
                    clk_map.wr[2][2] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[2][2] <= 0;
                    clk_map.wr[2][2] <= 0;
                end

            // Stripe 11

                // R6
                if ((clk_map.cnt[0][2] == 'd4) && VLD_IN[0][2])
                begin
                    clk_map.dat[2][3] <= DAT_IN[0][2];
                    clk_map.wr[2][3] <= 1;
                end

                // G10
                else if ((clk_map.cnt[0][3] == 'd7) && VLD_IN[0][3])
                begin
                    clk_map.dat[2][3] <= DAT_IN[0][3];
                    clk_map.wr[2][3] <= 1;
                end

                // B14
                else if ((clk_map.cnt[0][0] == 'd11) && VLD_IN[0][0])
                begin
                    clk_map.dat[2][3] <= DAT_IN[0][0];
                    clk_map.wr[2][3] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[2][3] <= 0;
                    clk_map.wr[2][3] <= 0;
                end

            // Stripe 12

                // R3
                if ((clk_map.cnt[0][1] == 'd2) && VLD_IN[0][1])
                begin
                    clk_map.dat[3][0] <= DAT_IN[0][1];
                    clk_map.wr[3][0] <= 1;
                end

                // G7
                else if ((clk_map.cnt[0][2] == 'd5) && VLD_IN[0][2])
                begin
                    clk_map.dat[3][0] <= DAT_IN[0][2];
                    clk_map.wr[3][0] <= 1;
                end

                // B11
                else if ((clk_map.cnt[0][3] == 'd8) && VLD_IN[0][3])
                begin
                    clk_map.dat[3][0] <= DAT_IN[0][3];
                    clk_map.wr[3][0] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[3][0] <= 0;
                    clk_map.wr[3][0] <= 0;
                end

            // Stripe 13

                // G3
                if ((clk_map.cnt[0][2] == 'd2) && VLD_IN[0][2])
                begin
                    clk_map.dat[3][1] <= DAT_IN[0][2];
                    clk_map.wr[3][1] <= 1;
                end

                // B7
                else if ((clk_map.cnt[0][3] == 'd5) && VLD_IN[0][3])
                begin
                    clk_map.dat[3][1] <= DAT_IN[0][3];
                    clk_map.wr[3][1] <= 1;
                end

                // R15
                else if ((clk_map.cnt[0][1] == 'd11) && VLD_IN[0][1])
                begin
                    clk_map.dat[3][1] <= DAT_IN[0][1];
                    clk_map.wr[3][1] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[3][1] <= 0;
                    clk_map.wr[3][1] <= 0;
                end

            // Stripe 14

                // B3
                if ((clk_map.cnt[0][3] == 'd2) && VLD_IN[0][3])
                begin
                    clk_map.dat[3][2] <= DAT_IN[0][3];
                    clk_map.wr[3][2] <= 1;
                end

                // R11
                else if ((clk_map.cnt[0][1] == 'd8) && VLD_IN[0][1])
                begin
                    clk_map.dat[3][2] <= DAT_IN[0][1];
                    clk_map.wr[3][2] <= 1;
                end

                // G15
                else if ((clk_map.cnt[0][2] == 'd11) && VLD_IN[0][2])
                begin
                    clk_map.dat[3][2] <= DAT_IN[0][2];
                    clk_map.wr[3][2] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[3][2] <= 0;
                    clk_map.wr[3][2] <= 0;
                end

            // Stripe 15

                // R7
                if ((clk_map.cnt[0][1] == 'd5) && VLD_IN[0][1])
                begin
                    clk_map.dat[3][3] <= DAT_IN[0][1];
                    clk_map.wr[3][3] <= 1;
                end

                // G11
                else if ((clk_map.cnt[0][2] == 'd8) && VLD_IN[0][2])
                begin
                    clk_map.dat[3][3] <= DAT_IN[0][2];
                    clk_map.wr[3][3] <= 1;
                end

                // B15
                else if ((clk_map.cnt[0][3] == 'd11) && VLD_IN[0][3])
                begin
                    clk_map.dat[3][3] <= DAT_IN[0][3];
                    clk_map.wr[3][3] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[3][3] <= 0;
                    clk_map.wr[3][3] <= 0;
                end
            end

            // 2 lanes
            else if (LANES_IN == 'd2)
            begin

            // Stripe 0

                // R0
                if ((clk_map.cnt[0][0] == 'd0) && VLD_IN[0][0])
                begin
                    clk_map.dat[0][0] <= DAT_IN[0][0];
                    clk_map.wr[0][0] <= 1;
                end

                // G4
                else if ((clk_map.cnt[0][3] == 'd1) && VLD_IN[0][3])
                begin
                    clk_map.dat[0][0] <= DAT_IN[0][3];
                    clk_map.wr[0][0] <= 1;
                end

                // B8
                else if ((clk_map.cnt[0][2] == 'd3) && VLD_IN[0][2])
                begin
                    clk_map.dat[0][0] <= DAT_IN[0][2];
                    clk_map.wr[0][0] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[0][0] <= 0;
                    clk_map.wr[0][0] <= 0;
                end

            // Stripe 1

                // G0
                if ((clk_map.cnt[0][1] == 'd0) && VLD_IN[0][1])
                begin
                    clk_map.dat[0][1] <= DAT_IN[0][1];
                    clk_map.wr[0][1] <= 1;
                end

                // B4
                else if ((clk_map.cnt[0][0] == 'd2) && VLD_IN[0][0])
                begin
                    clk_map.dat[0][1] <= DAT_IN[0][0];
                    clk_map.wr[0][1] <= 1;
                end

                // R12
                else if ((clk_map.cnt[0][2] == 'd4) && VLD_IN[0][2])
                begin
                    clk_map.dat[0][1] <= DAT_IN[0][2];
                    clk_map.wr[0][1] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[0][1] <= 0;
                    clk_map.wr[0][1] <= 0;
                end

            // Stripe 2

                // B0
                if ((clk_map.cnt[0][2] == 'd0) && VLD_IN[0][2])
                begin
                    clk_map.dat[0][2] <= DAT_IN[0][2];
                    clk_map.wr[0][2] <= 1;
                end

                // R8
                else if ((clk_map.cnt[0][0] == 'd3) && VLD_IN[0][0])
                begin
                    clk_map.dat[0][2] <= DAT_IN[0][0];
                    clk_map.wr[0][2] <= 1;
                end

                // G12
                else if ((clk_map.cnt[0][3] == 'd4) && VLD_IN[0][3])
                begin
                    clk_map.dat[0][2] <= DAT_IN[0][3];
                    clk_map.wr[0][2] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[0][2] <= 0;
                    clk_map.wr[0][2] <= 0;
                end

            // Stripe 3

                // R4
                if ((clk_map.cnt[0][2] == 'd1) && VLD_IN[0][2])
                begin
                    clk_map.dat[0][3] <= DAT_IN[0][2];
                    clk_map.wr[0][3] <= 1;
                end

                // G8
                else if ((clk_map.cnt[0][1] == 'd3) && VLD_IN[0][1])
                begin
                    clk_map.dat[0][3] <= DAT_IN[0][1];
                    clk_map.wr[0][3] <= 1;
                end

                // B12
                else if ((clk_map.cnt[0][0] == 'd5) && VLD_IN[0][0])
                begin
                    clk_map.dat[0][3] <= DAT_IN[0][0];
                    clk_map.wr[0][3] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[0][3] <= 0;
                    clk_map.wr[0][3] <= 0;
                end

            // Stripe 4

                // R1
                if ((clk_map.cnt[1][0] == 'd0) && VLD_IN[1][0])
                begin
                    clk_map.dat[1][0] <= DAT_IN[1][0];
                    clk_map.wr[1][0] <= 1;
                end

                // G5
                else if ((clk_map.cnt[1][3] == 'd1) && VLD_IN[1][3])
                begin
                    clk_map.dat[1][0] <= DAT_IN[1][3];
                    clk_map.wr[1][0] <= 1;
                end

                // B9
                else if ((clk_map.cnt[1][2] == 'd3) && VLD_IN[1][2])
                begin
                    clk_map.dat[1][0] <= DAT_IN[1][2];
                    clk_map.wr[1][0] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[1][0] <= 0;
                    clk_map.wr[1][0] <= 0;
                end

            // Stripe 5

                // G1
                if ((clk_map.cnt[1][1] == 'd0) && VLD_IN[1][1])
                begin
                    clk_map.dat[1][1] <= DAT_IN[1][1];
                    clk_map.wr[1][1] <= 1;
                end

                // B5
                else if ((clk_map.cnt[1][0] == 'd2) && VLD_IN[1][0])
                begin
                    clk_map.dat[1][1] <= DAT_IN[1][0];
                    clk_map.wr[1][1] <= 1;
                end

                // R13
                else if ((clk_map.cnt[1][2] == 'd4) && VLD_IN[1][2])
                begin
                    clk_map.dat[1][1] <= DAT_IN[1][2];
                    clk_map.wr[1][1] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[1][1] <= 0;
                    clk_map.wr[1][1] <= 0;
                end

            // Stripe 6

                // B1
                if ((clk_map.cnt[1][2] == 'd0) && VLD_IN[1][2])
                begin
                    clk_map.dat[1][2] <= DAT_IN[1][2];
                    clk_map.wr[1][2] <= 1;
                end

                // R9
                else if ((clk_map.cnt[1][0] == 'd3) && VLD_IN[1][0])
                begin
                    clk_map.dat[1][2] <= DAT_IN[1][0];
                    clk_map.wr[1][2] <= 1;
                end

                // G13
                else if ((clk_map.cnt[1][3] == 'd4) && VLD_IN[1][3])
                begin
                    clk_map.dat[1][2] <= DAT_IN[1][3];
                    clk_map.wr[1][2] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[1][2] <= 0;
                    clk_map.wr[1][2] <= 0;
                end

            // Stripe 7

                // R5
                if ((clk_map.cnt[1][2] == 'd1) && VLD_IN[1][2])
                begin
                    clk_map.dat[1][3] <= DAT_IN[1][2];
                    clk_map.wr[1][3] <= 1;
                end

                // G9
                else if ((clk_map.cnt[1][1] == 'd3) && VLD_IN[1][1])
                begin
                    clk_map.dat[1][3] <= DAT_IN[1][1];
                    clk_map.wr[1][3] <= 1;
                end

                // B13
                else if ((clk_map.cnt[1][0] == 'd5) && VLD_IN[1][0])
                begin
                    clk_map.dat[1][3] <= DAT_IN[1][0];
                    clk_map.wr[1][3] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[1][3] <= 0;
                    clk_map.wr[1][3] <= 0;
                end

            // Stripe 8

                // R2
                if ((clk_map.cnt[0][3] == 'd0) && VLD_IN[0][3])
                begin
                    clk_map.dat[2][0] <= DAT_IN[0][3];
                    clk_map.wr[2][0] <= 1;
                end

                // G6
                else if ((clk_map.cnt[0][2] == 'd2) && VLD_IN[0][2])
                begin
                    clk_map.dat[2][0] <= DAT_IN[0][2];
                    clk_map.wr[2][0] <= 1;
                end

                // B10
                else if ((clk_map.cnt[0][1] == 'd4) && VLD_IN[0][1])
                begin
                    clk_map.dat[2][0] <= DAT_IN[0][1];
                    clk_map.wr[2][0] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[2][0] <= 0;
                    clk_map.wr[2][0] <= 0;
                end

            // Stripe 9

                // G2
                if ((clk_map.cnt[0][0] == 'd1) && VLD_IN[0][0])
                begin
                    clk_map.dat[2][1] <= DAT_IN[0][0];
                    clk_map.wr[2][1] <= 1;
                end

                // B6
                else if ((clk_map.cnt[0][3] == 'd2) && VLD_IN[0][3])
                begin
                    clk_map.dat[2][1] <= DAT_IN[0][3];
                    clk_map.wr[2][1] <= 1;
                end

                // R14
                else if ((clk_map.cnt[0][1] == 'd5) && VLD_IN[0][1])
                begin
                    clk_map.dat[2][1] <= DAT_IN[0][1];
                    clk_map.wr[2][1] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[2][1] <= 0;
                    clk_map.wr[2][1] <= 0;
                end

            // Stripe 10

                // B2
                if ((clk_map.cnt[0][1] == 'd1) && VLD_IN[0][1])
                begin
                    clk_map.dat[2][2] <= DAT_IN[0][1];
                    clk_map.wr[2][2] <= 1;
                end

                // R10
                else if ((clk_map.cnt[0][3] == 'd3) && VLD_IN[0][3])
                begin
                    clk_map.dat[2][2] <= DAT_IN[0][3];
                    clk_map.wr[2][2] <= 1;
                end

                // G14
                else if ((clk_map.cnt[0][2] == 'd5) && VLD_IN[0][2])
                begin
                    clk_map.dat[2][2] <= DAT_IN[0][2];
                    clk_map.wr[2][2] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[2][2] <= 0;
                    clk_map.wr[2][2] <= 0;
                end

            // Stripe 11

                // R6
                if ((clk_map.cnt[0][1] == 'd2) && VLD_IN[0][1])
                begin
                    clk_map.dat[2][3] <= DAT_IN[0][1];
                    clk_map.wr[2][3] <= 1;
                end

                // G10
                else if ((clk_map.cnt[0][0] == 'd4) && VLD_IN[0][0])
                begin
                    clk_map.dat[2][3] <= DAT_IN[0][0];
                    clk_map.wr[2][3] <= 1;
                end

                // B14
                else if ((clk_map.cnt[0][3] == 'd5) && VLD_IN[0][3])
                begin
                    clk_map.dat[2][3] <= DAT_IN[0][3];
                    clk_map.wr[2][3] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[2][3] <= 0;
                    clk_map.wr[2][3] <= 0;
                end

            // Stripe 12

                // R3
                if ((clk_map.cnt[1][3] == 'd0) && VLD_IN[1][3])
                begin
                    clk_map.dat[3][0] <= DAT_IN[1][3];
                    clk_map.wr[3][0] <= 1;
                end

                // G7
                else if ((clk_map.cnt[1][2] == 'd2) && VLD_IN[1][2])
                begin
                    clk_map.dat[3][0] <= DAT_IN[1][2];
                    clk_map.wr[3][0] <= 1;
                end

                // B11
                else if ((clk_map.cnt[1][1] == 'd4) && VLD_IN[1][1])
                begin
                    clk_map.dat[3][0] <= DAT_IN[1][1];
                    clk_map.wr[3][0] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[3][0] <= 0;
                    clk_map.wr[3][0] <= 0;
                end

            // Stripe 13

                // G3
                if ((clk_map.cnt[1][0] == 'd1) && VLD_IN[1][0])
                begin
                    clk_map.dat[3][1] <= DAT_IN[1][0];
                    clk_map.wr[3][1] <= 1;
                end

                // B7
                else if ((clk_map.cnt[1][3] == 'd2) && VLD_IN[1][3])
                begin
                    clk_map.dat[3][1] <= DAT_IN[1][3];
                    clk_map.wr[3][1] <= 1;
                end

                // R15
                else if ((clk_map.cnt[1][1] == 'd5) && VLD_IN[1][1])
                begin
                    clk_map.dat[3][1] <= DAT_IN[1][1];
                    clk_map.wr[3][1] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[3][1] <= 0;
                    clk_map.wr[3][1] <= 0;
                end

            // Stripe 14

                // B3
                if ((clk_map.cnt[1][1] == 'd1) && VLD_IN[1][1])
                begin
                    clk_map.dat[3][2] <= DAT_IN[1][1];
                    clk_map.wr[3][2] <= 1;
                end

                // R11
                else if ((clk_map.cnt[1][3] == 'd3) && VLD_IN[1][3])
                begin
                    clk_map.dat[3][2] <= DAT_IN[1][3];
                    clk_map.wr[3][2] <= 1;
                end

                // G15
                else if ((clk_map.cnt[1][2] == 'd5) && VLD_IN[1][2])
                begin
                    clk_map.dat[3][2] <= DAT_IN[1][2];
                    clk_map.wr[3][2] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[3][2] <= 0;
                    clk_map.wr[3][2] <= 0;
                end

            // Stripe 15

                // R7
                if ((clk_map.cnt[1][1] == 'd2) && VLD_IN[1][1])
                begin
                    clk_map.dat[3][3] <= DAT_IN[1][1];
                    clk_map.wr[3][3] <= 1;
                end

                // G11
                else if ((clk_map.cnt[1][0] == 'd4) && VLD_IN[1][0])
                begin
                    clk_map.dat[3][3] <= DAT_IN[1][0];
                    clk_map.wr[3][3] <= 1;
                end

                // B15
                else if ((clk_map.cnt[1][3] == 'd5) && VLD_IN[1][3])
                begin
                    clk_map.dat[3][3] <= DAT_IN[1][3];
                    clk_map.wr[3][3] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[3][3] <= 0;
                    clk_map.wr[3][3] <= 0;
                end
            end

            // 4 lanes
            else
            begin
                for (int i = 0; i < P_LANES; i++)
                begin
                    for (int j = 0; j < P_SPL; j++)
                    begin
                        clk_map.wr[i][j] <= VLD_IN[i][j];
                        clk_map.dat[i][j] <= DAT_IN[i][j];
                    end
                end
            end
        end
    end 

    else
    begin : gen_map_dat_2spl

        always_ff @ (posedge CLK_IN)
        begin
            // Default
            for (int i = 0; i < P_LANES; i++)
            begin
                for (int j = 0; j < P_STRIPES; j++)
                begin
                        clk_map.dat[i][j] <= 0;
                        clk_map.wr[i][j] <= 0;
                end
            end

            // 1 lane
            if (LANES_IN == 'd1)
            begin

            // Stripe 0

                // R0
                if ((clk_map.cnt[0][0] == 'd0) && VLD_IN[0][0])
                begin
                    clk_map.dat[0][0] <= DAT_IN[0][0];
                    clk_map.wr[0][0] <= 1;
                end

                // G4
                else if ((clk_map.cnt[0][1] == 'd6) && VLD_IN[0][1])
                begin
                    clk_map.dat[0][0] <= DAT_IN[0][1];
                    clk_map.wr[0][0] <= 1;
                end

                // B8
                else if ((clk_map.cnt[0][0] == 'd13) && VLD_IN[0][0])
                begin
                    clk_map.dat[0][0] <= DAT_IN[0][0];
                    clk_map.wr[0][0] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[0][0] <= 0;
                    clk_map.wr[0][0] <= 0;
                end

            // Stripe 1

                // G0
                if ((clk_map.cnt[0][1] == 'd0) && VLD_IN[0][1])
                begin
                    clk_map.dat[0][1] <= DAT_IN[0][1];
                    clk_map.wr[0][1] <= 1;
                end

                // B4
                else if ((clk_map.cnt[0][0] == 'd7) && VLD_IN[0][0])
                begin
                    clk_map.dat[0][1] <= DAT_IN[0][0];
                    clk_map.wr[0][1] <= 1;
                end

                // R12
                else if ((clk_map.cnt[0][0] == 'd18) && VLD_IN[0][0])
                begin
                    clk_map.dat[0][1] <= DAT_IN[0][0];
                    clk_map.wr[0][1] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[0][1] <= 0;
                    clk_map.wr[0][1] <= 0;
                end

            // Stripe 2

                // B0
                if ((clk_map.cnt[0][0] == 'd1) && VLD_IN[0][0])
                begin
                    clk_map.dat[0][2] <= DAT_IN[0][0];
                    clk_map.wr[0][2] <= 1;
                end

                // R8
                else if ((clk_map.cnt[0][0] == 'd12) && VLD_IN[0][0])
                begin
                    clk_map.dat[0][2] <= DAT_IN[0][0];
                    clk_map.wr[0][2] <= 1;
                end

                // G12
                else if ((clk_map.cnt[0][1] == 'd18) && VLD_IN[0][1])
                begin
                    clk_map.dat[0][2] <= DAT_IN[0][1];
                    clk_map.wr[0][2] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[0][2] <= 0;
                    clk_map.wr[0][2] <= 0;
                end

            // Stripe 3

                // R4
                if ((clk_map.cnt[0][0] == 'd6) && VLD_IN[0][0])
                begin
                    clk_map.dat[0][3] <= DAT_IN[0][0];
                    clk_map.wr[0][3] <= 1;
                end

                // G8
                else if ((clk_map.cnt[0][1] == 'd12) && VLD_IN[0][1])
                begin
                    clk_map.dat[0][3] <= DAT_IN[0][1];
                    clk_map.wr[0][3] <= 1;
                end

                // B12
                else if ((clk_map.cnt[0][0] == 'd19) && VLD_IN[0][0])
                begin
                    clk_map.dat[0][3] <= DAT_IN[0][0];
                    clk_map.wr[0][3] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[0][3] <= 0;
                    clk_map.wr[0][3] <= 0;
                end

            // Stripe 4

                // R1
                if ((clk_map.cnt[0][1] == 'd1) && VLD_IN[0][1])
                begin
                    clk_map.dat[1][0] <= DAT_IN[0][1];
                    clk_map.wr[1][0] <= 1;
                end

                // G5
                else if ((clk_map.cnt[0][0] == 'd8) && VLD_IN[0][0])
                begin
                    clk_map.dat[1][0] <= DAT_IN[0][0];
                    clk_map.wr[1][0] <= 1;
                end

                // B9
                else if ((clk_map.cnt[0][1] == 'd14) && VLD_IN[0][1])
                begin
                    clk_map.dat[1][0] <= DAT_IN[0][1];
                    clk_map.wr[1][0] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[1][0] <= 0;
                    clk_map.wr[1][0] <= 0;
                end

            // Stripe 5

                // G1
                if ((clk_map.cnt[0][0] == 'd2) && VLD_IN[0][0])
                begin
                    clk_map.dat[1][1] <= DAT_IN[0][0];
                    clk_map.wr[1][1] <= 1;
                end

                // B5
                else if ((clk_map.cnt[0][1] == 'd8) && VLD_IN[0][1])
                begin
                    clk_map.dat[1][1] <= DAT_IN[0][1];
                    clk_map.wr[1][1] <= 1;
                end

                // R13
                else if ((clk_map.cnt[0][1] == 'd19) && VLD_IN[0][1])
                begin
                    clk_map.dat[1][1] <= DAT_IN[0][1];
                    clk_map.wr[1][1] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[1][1] <= 0;
                    clk_map.wr[1][1] <= 0;
                end

            // Stripe 6

                // B1
                if ((clk_map.cnt[0][1] == 'd2) && VLD_IN[0][1])
                begin
                    clk_map.dat[1][2] <= DAT_IN[0][1];
                    clk_map.wr[1][2] <= 1;
                end

                // R9
                else if ((clk_map.cnt[0][1] == 'd13) && VLD_IN[0][1])
                begin
                    clk_map.dat[1][2] <= DAT_IN[0][1];
                    clk_map.wr[1][2] <= 1;
                end

                // G13
                else if ((clk_map.cnt[0][0] == 'd20) && VLD_IN[0][0])
                begin
                    clk_map.dat[1][2] <= DAT_IN[0][0];
                    clk_map.wr[1][2] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[1][2] <= 0;
                    clk_map.wr[1][2] <= 0;
                end

            // Stripe 7

                // R5
                if ((clk_map.cnt[0][1] == 'd7) && VLD_IN[0][1])
                begin
                    clk_map.dat[1][3] <= DAT_IN[0][1];
                    clk_map.wr[1][3] <= 1;
                end

                // G9
                else if ((clk_map.cnt[0][0] == 'd14) && VLD_IN[0][0])
                begin
                    clk_map.dat[1][3] <= DAT_IN[0][0];
                    clk_map.wr[1][3] <= 1;
                end

                // B13
                else if ((clk_map.cnt[0][1] == 'd20) && VLD_IN[0][1])
                begin
                    clk_map.dat[1][3] <= DAT_IN[0][1];
                    clk_map.wr[1][3] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[1][3] <= 0;
                    clk_map.wr[1][3] <= 0;
                end

            // Stripe 8

                // R2
                if ((clk_map.cnt[0][0] == 'd3) && VLD_IN[0][0])
                begin
                    clk_map.dat[2][0] <= DAT_IN[0][0];
                    clk_map.wr[2][0] <= 1;
                end

                // G6
                else if ((clk_map.cnt[0][1] == 'd9) && VLD_IN[0][1])
                begin
                    clk_map.dat[2][0] <= DAT_IN[0][1];
                    clk_map.wr[2][0] <= 1;
                end

                // B10
                else if ((clk_map.cnt[0][0] == 'd16) && VLD_IN[0][0])
                begin
                    clk_map.dat[2][0] <= DAT_IN[0][0];
                    clk_map.wr[2][0] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[2][0] <= 0;
                    clk_map.wr[2][0] <= 0;
                end

            // Stripe 9

                // G2
                if ((clk_map.cnt[0][1] == 'd3) && VLD_IN[0][1])
                begin
                    clk_map.dat[2][1] <= DAT_IN[0][1];
                    clk_map.wr[2][1] <= 1;
                end

                // B6
                else if ((clk_map.cnt[0][0] == 'd10) && VLD_IN[0][0])
                begin
                    clk_map.dat[2][1] <= DAT_IN[0][0];
                    clk_map.wr[2][1] <= 1;
                end

                // R14
                else if ((clk_map.cnt[0][0] == 'd21) && VLD_IN[0][0])
                begin
                    clk_map.dat[2][1] <= DAT_IN[0][0];
                    clk_map.wr[2][1] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[2][1] <= 0;
                    clk_map.wr[2][1] <= 0;
                end

            // Stripe 10

                // B2
                if ((clk_map.cnt[0][0] == 'd4) && VLD_IN[0][0])
                begin
                    clk_map.dat[2][2] <= DAT_IN[0][0];
                    clk_map.wr[2][2] <= 1;
                end

                // R10
                else if ((clk_map.cnt[0][0] == 'd15) && VLD_IN[0][0])
                begin
                    clk_map.dat[2][2] <= DAT_IN[0][0];
                    clk_map.wr[2][2] <= 1;
                end

                // G14
                else if ((clk_map.cnt[0][1] == 'd21) && VLD_IN[0][1])
                begin
                    clk_map.dat[2][2] <= DAT_IN[0][1];
                    clk_map.wr[2][2] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[2][2] <= 0;
                    clk_map.wr[2][2] <= 0;
                end

            // Stripe 11

                // R6
                if ((clk_map.cnt[0][0] == 'd9) && VLD_IN[0][0])
                begin
                    clk_map.dat[2][3] <= DAT_IN[0][0];
                    clk_map.wr[2][3] <= 1;
                end

                // G10
                else if ((clk_map.cnt[0][1] == 'd15) && VLD_IN[0][1])
                begin
                    clk_map.dat[2][3] <= DAT_IN[0][1];
                    clk_map.wr[2][3] <= 1;
                end

                // B14
                else if ((clk_map.cnt[0][0] == 'd22) && VLD_IN[0][0])
                begin
                    clk_map.dat[2][3] <= DAT_IN[0][0];
                    clk_map.wr[2][3] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[2][3] <= 0;
                    clk_map.wr[2][3] <= 0;
                end

            // Stripe 12

                // R3
                if ((clk_map.cnt[0][1] == 'd4) && VLD_IN[0][1])
                begin
                    clk_map.dat[3][0] <= DAT_IN[0][1];
                    clk_map.wr[3][0] <= 1;
                end

                // G7
                else if ((clk_map.cnt[0][0] == 'd11) && VLD_IN[0][0])
                begin
                    clk_map.dat[3][0] <= DAT_IN[0][0];
                    clk_map.wr[3][0] <= 1;
                end

                // B11
                else if ((clk_map.cnt[0][1] == 'd17) && VLD_IN[0][1])
                begin
                    clk_map.dat[3][0] <= DAT_IN[0][1];
                    clk_map.wr[3][0] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[3][0] <= 0;
                    clk_map.wr[3][0] <= 0;
                end

            // Stripe 13

                // G3
                if ((clk_map.cnt[0][0] == 'd5) && VLD_IN[0][0])
                begin
                    clk_map.dat[3][1] <= DAT_IN[0][0];
                    clk_map.wr[3][1] <= 1;
                end

                // B7
                else if ((clk_map.cnt[0][1] == 'd11) && VLD_IN[0][1])
                begin
                    clk_map.dat[3][1] <= DAT_IN[0][1];
                    clk_map.wr[3][1] <= 1;
                end

                // R15
                else if ((clk_map.cnt[0][1] == 'd22) && VLD_IN[0][1])
                begin
                    clk_map.dat[3][1] <= DAT_IN[0][1];
                    clk_map.wr[3][1] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[3][1] <= 0;
                    clk_map.wr[3][1] <= 0;
                end

            // Stripe 14

                // B3
                if ((clk_map.cnt[0][1] == 'd5) && VLD_IN[0][1])
                begin
                    clk_map.dat[3][2] <= DAT_IN[0][1];
                    clk_map.wr[3][2] <= 1;
                end

                // R11
                else if ((clk_map.cnt[0][1] == 'd16) && VLD_IN[0][1])
                begin
                    clk_map.dat[3][2] <= DAT_IN[0][1];
                    clk_map.wr[3][2] <= 1;
                end

                // G15
                else if ((clk_map.cnt[0][0] == 'd23) && VLD_IN[0][0])
                begin
                    clk_map.dat[3][2] <= DAT_IN[0][0];
                    clk_map.wr[3][2] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[3][2] <= 0;
                    clk_map.wr[3][2] <= 0;
                end

            // Stripe 15

                // R7
                if ((clk_map.cnt[0][1] == 'd10) && VLD_IN[0][1])
                begin
                    clk_map.dat[3][3] <= DAT_IN[0][1];
                    clk_map.wr[3][3] <= 1;
                end

                // G11
                else if ((clk_map.cnt[0][0] == 'd17) && VLD_IN[0][0])
                begin
                    clk_map.dat[3][3] <= DAT_IN[0][0];
                    clk_map.wr[3][3] <= 1;
                end

                // B15
                else if ((clk_map.cnt[0][1] == 'd23) && VLD_IN[0][1])
                begin
                    clk_map.dat[3][3] <= DAT_IN[0][1];
                    clk_map.wr[3][3] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[3][3] <= 0;
                    clk_map.wr[3][3] <= 0;
                end
            end

            // 2 lanes
            else if (LANES_IN == 'd2)
            begin
            
            // Stripe 0

                // R0
                if ((clk_map.cnt[0][0] == 'd0) && VLD_IN[0][0])
                begin
                    clk_map.dat[0][0] <= DAT_IN[0][0];
                    clk_map.wr[0][0] <= 1;
                end

                // G4
                else if ((clk_map.cnt[0][1] == 'd3) && VLD_IN[0][1])
                begin
                    clk_map.dat[0][0] <= DAT_IN[0][1];
                    clk_map.wr[0][0] <= 1;
                end

                // B8
                else if ((clk_map.cnt[0][0] == 'd7) && VLD_IN[0][0])
                begin
                    clk_map.dat[0][0] <= DAT_IN[0][0];
                    clk_map.wr[0][0] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[0][0] <= 0;
                    clk_map.wr[0][0] <= 0;
                end

            // Stripe 1

                // G0
                if ((clk_map.cnt[0][1] == 'd0) && VLD_IN[0][1])
                begin
                    clk_map.dat[0][1] <= DAT_IN[0][1];
                    clk_map.wr[0][1] <= 1;
                end

                // B4
                else if ((clk_map.cnt[0][0] == 'd4) && VLD_IN[0][0])
                begin
                    clk_map.dat[0][1] <= DAT_IN[0][0];
                    clk_map.wr[0][1] <= 1;
                end

                // R12
                else if ((clk_map.cnt[0][0] == 'd9) && VLD_IN[0][0])
                begin
                    clk_map.dat[0][1] <= DAT_IN[0][0];
                    clk_map.wr[0][1] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[0][1] <= 0;
                    clk_map.wr[0][1] <= 0;
                end

            // Stripe 2

                // B0
                if ((clk_map.cnt[0][0] == 'd1) && VLD_IN[0][0])
                begin
                    clk_map.dat[0][2] <= DAT_IN[0][0];
                    clk_map.wr[0][2] <= 1;
                end

                // R8
                else if ((clk_map.cnt[0][0] == 'd6) && VLD_IN[0][0])
                begin
                    clk_map.dat[0][2] <= DAT_IN[0][0];
                    clk_map.wr[0][2] <= 1;
                end

                // G12
                else if ((clk_map.cnt[0][1] == 'd9) && VLD_IN[0][1])
                begin
                    clk_map.dat[0][2] <= DAT_IN[0][1];
                    clk_map.wr[0][2] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[0][2] <= 0;
                    clk_map.wr[0][2] <= 0;
                end

            // Stripe 3

                // R4
                if ((clk_map.cnt[0][0] == 'd3) && VLD_IN[0][0])
                begin
                    clk_map.dat[0][3] <= DAT_IN[0][0];
                    clk_map.wr[0][3] <= 1;
                end

                // G8
                else if ((clk_map.cnt[0][1] == 'd6) && VLD_IN[0][1])
                begin
                    clk_map.dat[0][3] <= DAT_IN[0][1];
                    clk_map.wr[0][3] <= 1;
                end

                // B12
                else if ((clk_map.cnt[0][0] == 'd10) && VLD_IN[0][0])
                begin
                    clk_map.dat[0][3] <= DAT_IN[0][0];
                    clk_map.wr[0][3] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[0][3] <= 0;
                    clk_map.wr[0][3] <= 0;
                end

            // Stripe 4

                // R1
                if ((clk_map.cnt[1][0] == 'd0) && VLD_IN[1][0])
                begin
                    clk_map.dat[1][0] <= DAT_IN[1][0];
                    clk_map.wr[1][0] <= 1;
                end

                // G5
                else if ((clk_map.cnt[1][1] == 'd3) && VLD_IN[1][1])
                begin
                    clk_map.dat[1][0] <= DAT_IN[1][1];
                    clk_map.wr[1][0] <= 1;
                end

                // B9
                else if ((clk_map.cnt[1][0] == 'd7) && VLD_IN[1][0])
                begin
                    clk_map.dat[1][0] <= DAT_IN[1][0];
                    clk_map.wr[1][0] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[1][0] <= 0;
                    clk_map.wr[1][0] <= 0;
                end

            // Stripe 5

                // G1
                if ((clk_map.cnt[1][1] == 'd0) && VLD_IN[1][1])
                begin
                    clk_map.dat[1][1] <= DAT_IN[1][1];
                    clk_map.wr[1][1] <= 1;
                end

                // B5
                else if ((clk_map.cnt[1][0] == 'd4) && VLD_IN[1][0])
                begin
                    clk_map.dat[1][1] <= DAT_IN[1][0];
                    clk_map.wr[1][1] <= 1;
                end

                // R13
                else if ((clk_map.cnt[1][0] == 'd9) && VLD_IN[1][0])
                begin
                    clk_map.dat[1][1] <= DAT_IN[1][0];
                    clk_map.wr[1][1] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[1][1] <= 0;
                    clk_map.wr[1][1] <= 0;
                end

            // Stripe 6

                // B1
                if ((clk_map.cnt[1][0] == 'd1) && VLD_IN[1][0])
                begin
                    clk_map.dat[1][2] <= DAT_IN[1][0];
                    clk_map.wr[1][2] <= 1;
                end

                // R9
                else if ((clk_map.cnt[1][0] == 'd6) && VLD_IN[1][0])
                begin
                    clk_map.dat[1][2] <= DAT_IN[1][0];
                    clk_map.wr[1][2] <= 1;
                end

                // G13
                else if ((clk_map.cnt[1][1] == 'd9) && VLD_IN[1][1])
                begin
                    clk_map.dat[1][2] <= DAT_IN[1][1];
                    clk_map.wr[1][2] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[1][2] <= 0;
                    clk_map.wr[1][2] <= 0;
                end

            // Stripe 7

                // R5
                if ((clk_map.cnt[1][0] == 'd3) && VLD_IN[1][0])
                begin
                    clk_map.dat[1][3] <= DAT_IN[1][0];
                    clk_map.wr[1][3] <= 1;
                end

                // G9
                else if ((clk_map.cnt[1][1] == 'd6) && VLD_IN[1][1])
                begin
                    clk_map.dat[1][3] <= DAT_IN[1][1];
                    clk_map.wr[1][3] <= 1;
                end

                // B13
                else if ((clk_map.cnt[1][0] == 'd10) && VLD_IN[1][0])
                begin
                    clk_map.dat[1][3] <= DAT_IN[1][0];
                    clk_map.wr[1][3] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[1][3] <= 0;
                    clk_map.wr[1][3] <= 0;
                end

            // Stripe 8

                // R2
                if ((clk_map.cnt[0][1] == 'd1) && VLD_IN[0][1])
                begin
                    clk_map.dat[2][0] <= DAT_IN[0][1];
                    clk_map.wr[2][0] <= 1;
                end

                // G6
                else if ((clk_map.cnt[0][0] == 'd5) && VLD_IN[0][0])
                begin
                    clk_map.dat[2][0] <= DAT_IN[0][0];
                    clk_map.wr[2][0] <= 1;
                end

                // B10
                else if ((clk_map.cnt[0][1] == 'd8) && VLD_IN[0][1])
                begin
                    clk_map.dat[2][0] <= DAT_IN[0][1];
                    clk_map.wr[2][0] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[2][0] <= 0;
                    clk_map.wr[2][0] <= 0;
                end

            // Stripe 9

                // G2
                if ((clk_map.cnt[0][0] == 'd2) && VLD_IN[0][0])
                begin
                    clk_map.dat[2][1] <= DAT_IN[0][0];
                    clk_map.wr[2][1] <= 1;
                end

                // B6
                else if ((clk_map.cnt[0][1] == 'd5) && VLD_IN[0][1])
                begin
                    clk_map.dat[2][1] <= DAT_IN[0][1];
                    clk_map.wr[2][1] <= 1;
                end

                // R14
                else if ((clk_map.cnt[0][1] == 'd10) && VLD_IN[0][1])
                begin
                    clk_map.dat[2][1] <= DAT_IN[0][1];
                    clk_map.wr[2][1] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[2][1] <= 0;
                    clk_map.wr[2][1] <= 0;
                end

            // Stripe 10

                // B2
                if ((clk_map.cnt[0][1] == 'd2) && VLD_IN[0][1])
                begin
                    clk_map.dat[2][2] <= DAT_IN[0][1];
                    clk_map.wr[2][2] <= 1;
                end

                // R10
                else if ((clk_map.cnt[0][1] == 'd7) && VLD_IN[0][1])
                begin
                    clk_map.dat[2][2] <= DAT_IN[0][1];
                    clk_map.wr[2][2] <= 1;
                end

                // G14
                else if ((clk_map.cnt[0][0] == 'd11) && VLD_IN[0][0])
                begin
                    clk_map.dat[2][2] <= DAT_IN[0][0];
                    clk_map.wr[2][2] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[2][2] <= 0;
                    clk_map.wr[2][2] <= 0;
                end

            // Stripe 11

                // R6
                if ((clk_map.cnt[0][1] == 'd4) && VLD_IN[0][1])
                begin
                    clk_map.dat[2][3] <= DAT_IN[0][1];
                    clk_map.wr[2][3] <= 1;
                end

                // G10
                else if ((clk_map.cnt[0][0] == 'd8) && VLD_IN[0][0])
                begin
                    clk_map.dat[2][3] <= DAT_IN[0][0];
                    clk_map.wr[2][3] <= 1;
                end

                // B14
                else if ((clk_map.cnt[0][1] == 'd11) && VLD_IN[0][1])
                begin
                    clk_map.dat[2][3] <= DAT_IN[0][1];
                    clk_map.wr[2][3] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[2][3] <= 0;
                    clk_map.wr[2][3] <= 0;
                end

            // Stripe 12

                // R3
                if ((clk_map.cnt[1][1] == 'd1) && VLD_IN[1][1])
                begin
                    clk_map.dat[3][0] <= DAT_IN[1][1];
                    clk_map.wr[3][0] <= 1;
                end

                // G7
                else if ((clk_map.cnt[1][0] == 'd5) && VLD_IN[1][0])
                begin
                    clk_map.dat[3][0] <= DAT_IN[1][0];
                    clk_map.wr[3][0] <= 1;
                end

                // B11
                else if ((clk_map.cnt[1][1] == 'd8) && VLD_IN[1][1])
                begin
                    clk_map.dat[3][0] <= DAT_IN[1][1];
                    clk_map.wr[3][0] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[3][0] <= 0;
                    clk_map.wr[3][0] <= 0;
                end

            // Stripe 13

                // G3
                if ((clk_map.cnt[1][0] == 'd2) && VLD_IN[1][0])
                begin
                    clk_map.dat[3][1] <= DAT_IN[1][0];
                    clk_map.wr[3][1] <= 1;
                end

                // B7
                else if ((clk_map.cnt[1][1] == 'd5) && VLD_IN[1][1])
                begin
                    clk_map.dat[3][1] <= DAT_IN[1][1];
                    clk_map.wr[3][1] <= 1;
                end

                // R15
                else if ((clk_map.cnt[1][1] == 'd10) && VLD_IN[1][1])
                begin
                    clk_map.dat[3][1] <= DAT_IN[1][1];
                    clk_map.wr[3][1] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[3][1] <= 0;
                    clk_map.wr[3][1] <= 0;
                end

            // Stripe 14

                // B3
                if ((clk_map.cnt[1][1] == 'd2) && VLD_IN[1][1])
                begin
                    clk_map.dat[3][2] <= DAT_IN[1][1];
                    clk_map.wr[3][2] <= 1;
                end

                // R11
                else if ((clk_map.cnt[1][1] == 'd7) && VLD_IN[1][1])
                begin
                    clk_map.dat[3][2] <= DAT_IN[1][1];
                    clk_map.wr[3][2] <= 1;
                end

                // G15
                else if ((clk_map.cnt[1][0] == 'd11) && VLD_IN[1][0])
                begin
                    clk_map.dat[3][2] <= DAT_IN[1][0];
                    clk_map.wr[3][2] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[3][2] <= 0;
                    clk_map.wr[3][2] <= 0;
                end

            // Stripe 15

                // R7
                if ((clk_map.cnt[1][1] == 'd4) && VLD_IN[1][1])
                begin
                    clk_map.dat[3][3] <= DAT_IN[1][1];
                    clk_map.wr[3][3] <= 1;
                end

                // G11
                else if ((clk_map.cnt[1][0] == 'd8) && VLD_IN[1][0])
                begin
                    clk_map.dat[3][3] <= DAT_IN[1][0];
                    clk_map.wr[3][3] <= 1;
                end

                // B15
                else if ((clk_map.cnt[1][1] == 'd11) && VLD_IN[1][1])
                begin
                    clk_map.dat[3][3] <= DAT_IN[1][1];
                    clk_map.wr[3][3] <= 1;
                end

                // Idle
                else
                begin
                    clk_map.dat[3][3] <= 0;
                    clk_map.wr[3][3] <= 0;
                end
            end

            // 4 lanes
            else
            begin
                for (int i = 0; i < P_LANES; i++)
                begin
                    for (int j = 0; j < P_SPL; j++)
                    begin
                        // lower sublane
                        if ((clk_map.cnt[i][j] == 'd0) && VLD_IN[i][j])
                        begin
                            clk_map.dat[i][j] <= DAT_IN[i][j];
                            clk_map.wr[i][j] <= 1;
                        end

                        // Upper sublane
                        else if ((clk_map.cnt[i][j] == 'd1) && VLD_IN[i][j])
                        begin
                            clk_map.dat[i][j+2] <= DAT_IN[i][j];
                            clk_map.wr[i][j+2] <= 1;
                        end
                    end
                end
            end
        end
    end 
endgenerate

// Outputs
    assign DAT_OUT = clk_map.dat;
    assign VLD_OUT = clk_map.wr;

endmodule

`default_nettype wire
