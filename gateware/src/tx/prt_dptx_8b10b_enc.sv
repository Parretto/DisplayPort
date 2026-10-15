/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: DPTX 8b/10b encoder
    (c) 2026 by Parretto B.V.

    The Altera Agilex GTS transceiver has no hard 8b/10b encoder in DisplayPort mode.
    This module encodes the DPTX link symbols into 10-bit code groups for the PMA.
    It is part of the DPTX (prt_dptx_top) for vendor "ALTERA" and family "AGX".

    Link symbol (11 bits):
    [7:0]   Data
    [8]     K character
    [9]     Disparity value (0 - negative / 1 - positive)
    [10]    Disparity control (0 - automatic / 1 - force)

    The symbols of a lane are at index (lane * P_SPL) + symbol.
    Symbol 0 is the first in time.
    The code groups are LSB first (bit 0 is 'a', the first transmitted bit).

    The encoder has two pipeline stages:
    1. Lookup of the code groups for both running disparities. No feedback.
    2. Running disparity chain over the symbols of a lane and selection of the code groups.

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

module prt_dptx_8b10b_enc
#(
    parameter P_LANES = 4,      // Lanes
    parameter P_SPL = 2         // Symbols per lane
)
(
    input wire                                  CLK_IN,         // Link clock
    input wire [(P_LANES * P_SPL * 11)-1:0]     LNK_DAT_IN,     // Link symbols
    output wire [(P_LANES * P_SPL * 10)-1:0]    PHY_DAT_OUT     // Code groups
);

/*
    Functions
*/

// 8b/10b encoder
// Returns {disparity flip, code group}
// The code group is in transmission order: {a, b, c, d, e, i, f, g, h, j}, 'a' is the MSB.
// RD: 0 - negative / 1 - positive
function automatic [10:0] enc (input [7:0] dat, input k, input rd);
    logic [4:0] x;
    logic [2:0] y;
    logic [5:0] c6;
    logic       unbal6;
    logic       alt6;
    logic       rd6;
    logic [3:0] c4;
    logic       unbal4;
    logic       alt4;
    begin
        x = dat[4:0];
        y = dat[7:5];

        // 5b/6b (RD- code)
        unbal6 = 1;
        alt6 = 0;
        case (x)
            5'd0  : c6 = 6'b100111;
            5'd1  : c6 = 6'b011101;
            5'd2  : c6 = 6'b101101;
            5'd3  : begin c6 = 6'b110001; unbal6 = 0; end
            5'd4  : c6 = 6'b110101;
            5'd5  : begin c6 = 6'b101001; unbal6 = 0; end
            5'd6  : begin c6 = 6'b011001; unbal6 = 0; end
            5'd7  : begin c6 = 6'b111000; unbal6 = 0; alt6 = 1; end
            5'd8  : c6 = 6'b111001;
            5'd9  : begin c6 = 6'b100101; unbal6 = 0; end
            5'd10 : begin c6 = 6'b010101; unbal6 = 0; end
            5'd11 : begin c6 = 6'b110100; unbal6 = 0; end
            5'd12 : begin c6 = 6'b001101; unbal6 = 0; end
            5'd13 : begin c6 = 6'b101100; unbal6 = 0; end
            5'd14 : begin c6 = 6'b011100; unbal6 = 0; end
            5'd15 : c6 = 6'b010111;
            5'd16 : c6 = 6'b011011;
            5'd17 : begin c6 = 6'b100011; unbal6 = 0; end
            5'd18 : begin c6 = 6'b010011; unbal6 = 0; end
            5'd19 : begin c6 = 6'b110010; unbal6 = 0; end
            5'd20 : begin c6 = 6'b001011; unbal6 = 0; end
            5'd21 : begin c6 = 6'b101010; unbal6 = 0; end
            5'd22 : begin c6 = 6'b011010; unbal6 = 0; end
            5'd23 : c6 = 6'b111010;
            5'd24 : c6 = 6'b110011;
            5'd25 : begin c6 = 6'b100110; unbal6 = 0; end
            5'd26 : begin c6 = 6'b010110; unbal6 = 0; end
            5'd27 : c6 = 6'b110110;
            5'd28 : begin c6 = 6'b001110; unbal6 = 0; end
            5'd29 : c6 = 6'b101110;
            5'd30 : c6 = 6'b011110;
            default : c6 = 6'b101011;
        endcase

        // K28
        if (k && (x == 5'd28))
        begin
            c6 = 6'b001111;
            unbal6 = 1;
        end

        // RD+ code
        if (rd && (unbal6 || alt6))
            c6 = ~c6;

        // Running disparity after the 6b sub-block
        rd6 = rd ^ unbal6;

        // 3b/4b (RD- code)
        if (k)
        begin
            alt4 = 1;
            unbal4 = 0;
            case (y)
                3'd0 : begin c4 = 4'b1011; unbal4 = 1; end
                3'd1 : c4 = 4'b0110;
                3'd2 : c4 = 4'b1010;
                3'd3 : c4 = 4'b1100;
                3'd4 : begin c4 = 4'b1101; unbal4 = 1; end
                3'd5 : c4 = 4'b0101;
                3'd6 : c4 = 4'b1001;
                default : begin c4 = 4'b0111; unbal4 = 1; end
            endcase
        end

        else
        begin
            alt4 = 0;
            unbal4 = 0;
            case (y)
                3'd0 : begin c4 = 4'b1011; unbal4 = 1; alt4 = 1; end
                3'd1 : c4 = 4'b1001;
                3'd2 : c4 = 4'b0101;
                3'd3 : begin c4 = 4'b1100; alt4 = 1; end
                3'd4 : begin c4 = 4'b1101; unbal4 = 1; alt4 = 1; end
                3'd5 : c4 = 4'b1010;
                3'd6 : c4 = 4'b0110;
                default :
                begin
                    // Alternate D.x.A7 to prevent a run length of five
                    if ((!rd6 && ((x == 5'd17) || (x == 5'd18) || (x == 5'd20))) || (rd6 && ((x == 5'd11) || (x == 5'd13) || (x == 5'd14))))
                        c4 = 4'b0111;
                    else
                        c4 = 4'b1110;
                    unbal4 = 1;
                    alt4 = 1;
                end
            endcase
        end

        // RD+ code
        if (rd6 && alt4)
            c4 = ~c4;

        enc = {unbal6 ^ unbal4, c6, c4};
    end
endfunction

// Bit reverse of a code group (transmission order to LSB first)
function automatic [9:0] rev (input [9:0] din);
    for (int i = 0; i < 10; i++)
        rev[i] = din[9-i];
endfunction

/*
    Logic
*/

genvar i, j;

generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_lane

        // Stage 1
        // The registers have a power-up value, so the running disparity is defined from the start.
        logic [9:0]         code_n_reg[0:P_SPL-1];      // Code group for RD-
        logic [9:0]         code_p_reg[0:P_SPL-1];      // Code group for RD+
        logic [P_SPL-1:0]   flip_reg = '0;              // Disparity flip
        logic [P_SPL-1:0]   disp_ctl_reg = '0;          // Disparity control
        logic [P_SPL-1:0]   disp_val_reg = '0;          // Disparity value

        // Stage 2
        logic               rd_reg = 1'b0;              // Running disparity (starts negative)
        logic [P_SPL-1:0]   rd;                         // Running disparity before each symbol
        logic [9:0]         dat_reg[0:P_SPL-1];

        always_ff @ (posedge CLK_IN)
        begin
            for (int s = 0; s < P_SPL; s++)
            begin
                logic [10:0] sym;
                logic [10:0] enc_n;
                logic [10:0] enc_p;
                sym = LNK_DAT_IN[((i * P_SPL) + s) * 11 +: 11];
                enc_n = enc (sym[7:0], sym[8], 1'b0);
                enc_p = enc (sym[7:0], sym[8], 1'b1);
                code_n_reg[s] <= rev(enc_n[9:0]);
                code_p_reg[s] <= rev(enc_p[9:0]);
                flip_reg[s] <= enc_n[10];
                disp_ctl_reg[s] <= sym[10];
                disp_val_reg[s] <= sym[9];
            end
        end

        // Running disparity chain
        always_comb
        begin
            for (int s = 0; s < P_SPL; s++)
            begin
                if (disp_ctl_reg[s])
                    rd[s] = disp_val_reg[s];
                else if (s == 0)
                    rd[s] = rd_reg;
                else
                    rd[s] = rd[s-1] ^ flip_reg[s-1];
            end
        end

        always_ff @ (posedge CLK_IN)
        begin
            rd_reg <= rd[P_SPL-1] ^ flip_reg[P_SPL-1];

            for (int s = 0; s < P_SPL; s++)
                dat_reg[s] <= (rd[s]) ? code_p_reg[s] : code_n_reg[s];
        end

        for (j = 0; j < P_SPL; j++)
        begin : gen_out
            assign PHY_DAT_OUT[((i * P_SPL) + j) * 10 +: 10] = dat_reg[j];
        end
    end
endgenerate

endmodule

`default_nettype wire
