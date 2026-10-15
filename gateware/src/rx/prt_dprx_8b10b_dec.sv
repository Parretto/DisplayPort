/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: DPRX 8b/10b decoder
    (c) 2026 by Parretto B.V.

    The Altera Agilex GTS transceiver has no word aligner and no hard 8b/10b decoder in
    DisplayPort mode. This module aligns the received bits to the code group boundaries and
    decodes the code groups into the DPRX link symbols.
    It is part of the DPRX (prt_dprx_top) for vendor "ALTERA" and family "AGX".

    Code groups (10 bits) from the PMA:
    LSB first (bit 0 is 'a', the first received bit). Code group 0 is the first in time.
    The lanes are at index (lane * P_SPL) + code group.

    Link symbol (9 bits):
    [7:0]   Data
    [8]     K character

    Alignment (per lane):
    The aligner searches the comma of the K28.5 symbol (BS in TPS2, TPS3, TPS4 and the normal
    link). A comma at a new bit position is taken over after P_ALIGN_CNT detections in a row,
    so a bit error does not move the alignment.
    The clock recovery pattern TPS1 (D10.2) has no comma. As long as no comma has been seen,
    the aligner moves one bit when it receives D21.5 (D10.2 one bit off), so the DPRX sees
    D10.2. The link has a BS at least every 8192 symbols; without a comma at the alignment
    position for 2^14 clocks the alignment is cleared, so a new training starts over.

    The decoder has three pipeline stages:
    1. Comma detection over all bit positions
    2. Alignment of the code groups
    3. Decoding

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

module prt_dprx_8b10b_dec
#(
    parameter P_LANES = 4,      // Lanes
    parameter P_SPL = 2         // Symbols per lane
)
(
    input wire                                  CLK_IN,         // Link clock
    input wire [(P_LANES * P_SPL * 10)-1:0]     PHY_DAT_IN,     // Code groups
    output wire [(P_LANES * P_SPL * 9)-1:0]     LNK_DAT_OUT,    // Link symbols
    output wire [P_LANES-1:0]                   LNK_ALIGN_OUT   // Comma alignment (per lane)
);

/*
    Parameters
*/

localparam P_BITS = P_SPL * 10;     // Bits per lane per clock
localparam P_ALIGN_CNT = 3;         // Comma detections at a new position before the alignment moves
localparam P_ALIGN_TO = 14;         // Alignment time out (2^14 clocks without a comma at the position)

// Comma (bits a to g, LSB first) of K28.1, K28.5 and K28.7
localparam [6:0] P_COMMA_N = 7'b1111100;    // RD-: 0011111
localparam [6:0] P_COMMA_P = 7'b0000011;    // RD+: 1100000

// D21.5 (LSB first). D10.2 is received as this code group when the alignment is one bit off.
localparam [9:0] P_D21_5 = 10'b0101010101;

/*
    Functions
*/

// 8b/10b decoder
// The code group is LSB first: {j, h, g, f, i, e, d, c, b, a}
// Returns {K character, data}
function automatic [8:0] dec (input [9:0] cg);
    logic [5:0] c6;     // abcdei, 'a' is the MSB
    logic [3:0] c4;     // fghj, 'f' is the MSB
    logic [4:0] x;
    logic [2:0] y;
    logic       k;
    begin
        c6 = {cg[0], cg[1], cg[2], cg[3], cg[4], cg[5]};
        c4 = {cg[6], cg[7], cg[8], cg[9]};

        // 6b/5b
        case (c6)
            6'b100111, 6'b011000 : x = 5'd0;
            6'b011101, 6'b100010 : x = 5'd1;
            6'b101101, 6'b010010 : x = 5'd2;
            6'b110001            : x = 5'd3;
            6'b110101, 6'b001010 : x = 5'd4;
            6'b101001            : x = 5'd5;
            6'b011001            : x = 5'd6;
            6'b111000, 6'b000111 : x = 5'd7;
            6'b111001, 6'b000110 : x = 5'd8;
            6'b100101            : x = 5'd9;
            6'b010101            : x = 5'd10;
            6'b110100            : x = 5'd11;
            6'b001101            : x = 5'd12;
            6'b101100            : x = 5'd13;
            6'b011100            : x = 5'd14;
            6'b010111, 6'b101000 : x = 5'd15;
            6'b011011, 6'b100100 : x = 5'd16;
            6'b100011            : x = 5'd17;
            6'b010011            : x = 5'd18;
            6'b110010            : x = 5'd19;
            6'b001011            : x = 5'd20;
            6'b101010            : x = 5'd21;
            6'b011010            : x = 5'd22;
            6'b111010, 6'b000101 : x = 5'd23;
            6'b110011, 6'b001100 : x = 5'd24;
            6'b100110            : x = 5'd25;
            6'b010110            : x = 5'd26;
            6'b110110, 6'b001001 : x = 5'd27;
            6'b001110            : x = 5'd28;
            6'b101110, 6'b010001 : x = 5'd29;
            6'b011110, 6'b100001 : x = 5'd30;
            6'b101011, 6'b010100 : x = 5'd31;
            6'b001111, 6'b110000 : x = 5'd28;   // K28
            default              : x = 5'd0;
        endcase

        // K28.y
        if ((c6 == 6'b001111) || (c6 == 6'b110000))
        begin
            k = 1;

            // After the RD- 6b sub-block the 4b sub-block is the RD+ (complemented) code
            case ((c6 == 6'b001111) ? ~c4 : c4)
                4'b1011 : y = 3'd0;
                4'b0110 : y = 3'd1;
                4'b1010 : y = 3'd2;
                4'b1100 : y = 3'd3;
                4'b1101 : y = 3'd4;
                4'b0101 : y = 3'd5;
                4'b1001 : y = 3'd6;
                default : y = 3'd7;
            endcase
        end

        // K23.7, K27.7, K29.7 and K30.7
        // The alternate code 0111 / 1000 after these 6b sub-blocks is only used for K characters.
        else if (((x == 5'd23) || (x == 5'd27) || (x == 5'd29) || (x == 5'd30)) && ((c4 == 4'b0111) || (c4 == 4'b1000)))
        begin
            k = 1;
            y = 3'd7;
        end

        // Data
        else
        begin
            k = 0;
            case (c4)
                4'b1011, 4'b0100 : y = 3'd0;
                4'b1001          : y = 3'd1;
                4'b0101          : y = 3'd2;
                4'b1100, 4'b0011 : y = 3'd3;
                4'b1101, 4'b0010 : y = 3'd4;
                4'b1010          : y = 3'd5;
                4'b0110          : y = 3'd6;
                default          : y = 3'd7;   // 1110, 0001, 0111 and 1000
            endcase
        end

        dec = {k, y, x};
    end
endfunction

/*
    Logic
*/

genvar i, j;

generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_lane

        // The bits of this lane in the previous and the current clock.
        // A code group at bit position p starts at bit p of the previous word.
        logic [P_BITS-1:0]      dat_reg = '0;           // Current word
        logic [P_BITS-1:0]      dat_del_reg = '0;       // Previous word
        logic [(2*P_BITS)-1:0]  win;                    // {current, previous}

        // Stage 1
        logic [(2*P_BITS)-1:0]  win_reg = '0;
        logic [P_BITS-1:0]      comma_reg = '0;         // Comma at bit position p

        // Alignment
        logic [4:0]             pos_reg = '0;           // Bit position of the code groups (0 - 9)
        logic [4:0]             cand_reg = '0;          // New comma position
        logic [1:0]             cand_cnt_reg = '0;
        logic                   align_reg = 0;          // A comma has been seen at the current position
        logic [P_ALIGN_TO:0]    to_cnt_reg = '0;        // Time out
        logic [4:0]             comma_pos;

        // Stage 2
        logic [9:0]             cg_reg[0:P_SPL-1];

        // Stage 3
        logic [8:0]             sym_reg[0:P_SPL-1];

        assign win = {dat_reg, dat_del_reg};

        always_ff @ (posedge CLK_IN)
        begin
            dat_reg <= PHY_DAT_IN[(i * P_BITS) +: P_BITS];
            dat_del_reg <= dat_reg;
        end

        // Stage 1
        // Comma detection at every bit position of the previous word
        always_ff @ (posedge CLK_IN)
        begin
            win_reg <= win;
            for (int p = 0; p < P_BITS; p++)
                comma_reg[p] <= (win[p +: 7] == P_COMMA_N) || (win[p +: 7] == P_COMMA_P);
        end

        // The comma position modulo 10 (the lowest bit position with a comma)
        always_comb
        begin
            comma_pos = '0;
            for (int p = P_BITS-1; p >= 0; p--)
                if (comma_reg[p])
                    comma_pos = p % 10;
        end

        // Alignment
        always_ff @ (posedge CLK_IN)
        begin
            // Comma
            if (|comma_reg)
            begin
                // At the current position
                if (comma_pos == pos_reg)
                begin
                    align_reg <= 1;
                    cand_cnt_reg <= '0;
                    to_cnt_reg <= '0;
                end

                // At a new position
                else
                begin
                    if ((comma_pos == cand_reg) && (cand_cnt_reg == (P_ALIGN_CNT - 1)))
                    begin
                        pos_reg <= comma_pos;
                        align_reg <= 1;
                        cand_cnt_reg <= '0;
                        to_cnt_reg <= '0;
                    end

                    else
                    begin
                        if (comma_pos == cand_reg)
                            cand_cnt_reg <= cand_cnt_reg + 'd1;
                        else
                            cand_cnt_reg <= 'd1;
                        cand_reg <= comma_pos;
                    end
                end
            end

            // TPS1
            // Without a comma the aligner moves one bit when it receives D21.5.
            else if (!align_reg && (win_reg[pos_reg +: 10] == P_D21_5))
            begin
                if (pos_reg == 'd9)
                    pos_reg <= '0;
                else
                    pos_reg <= pos_reg + 'd1;
            end

            // Time out
            if (align_reg && !(|comma_reg && (comma_pos == pos_reg)))
            begin
                if (to_cnt_reg[P_ALIGN_TO])
                begin
                    align_reg <= 0;
                    to_cnt_reg <= '0;
                end

                else
                    to_cnt_reg <= to_cnt_reg + 'd1;
            end
        end

        // Stage 2
        // Code groups at the alignment position
        always_ff @ (posedge CLK_IN)
        begin
            for (int s = 0; s < P_SPL; s++)
                cg_reg[s] <= win_reg[(pos_reg + (s * 10)) +: 10];
        end

        // Stage 3
        always_ff @ (posedge CLK_IN)
        begin
            for (int s = 0; s < P_SPL; s++)
                sym_reg[s] <= dec (cg_reg[s]);
        end

        for (j = 0; j < P_SPL; j++)
        begin : gen_out
            assign LNK_DAT_OUT[((i * P_SPL) + j) * 9 +: 9] = sym_reg[j];
        end

        assign LNK_ALIGN_OUT[i] = align_reg;
    end
endgenerate

endmodule

`default_nettype wire
