/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: Agilex 5 HVIO I/O PLL reconfiguration
    (c) 2026 by Parretto B.V.

    APB slave to the reconfiguration interface (core_avl) of an HVIO I/O PLL.
    Each APB access to address (byte offset) of a PLL register is one 32-bit register access.

    The core_avl interface has a fixed cycle protocol with 8-bit transfers
    (Clocking and PLL User Guide: Agilex 5 FPGAs and SoCs, HVIO I/O PLL Reconfiguration):
    - Write: write asserted for 10 cycles, data 5 x 0x00 (preamble), byte 0 - 3 (LSB first),
      byte 3 once more. Then 5 idle cycles.
    - Read: read asserted for 10 cycles, the first 5 cycles of read data are invalid,
      then 0x00 and byte 0 - 3. Then 5 idle cycles.
    The PLL register map has byte offsets, production devices use the word address (byte offset >> 2).

    APB address map:
    0x000 - 0x7fc   PLL registers
    0x800           Debug: read data of the last read, one cycle earlier

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

module prt_hvio_pll_rcfg
(
    input wire          RST_IN,             // Reset
    input wire          CLK_IN,             // Clock (also the core_avl clock)

    // APB
    prt_apb_if.slv      APB_IF,

    // PLL reconfiguration interface
    output wire [8:0]   AVL_ADR_OUT,        // Address
    output wire         AVL_WR_OUT,         // Write
    output wire         AVL_RD_OUT,         // Read
    output wire [7:0]   AVL_DAT_OUT,        // Write data
    input wire [7:0]    AVL_DAT_IN          // Read data
);

// Signals
typedef enum {sm_idle, sm_wr, sm_rd, sm_gap, sm_rdy} sm_state;

sm_state        sm_cur;
logic [3:0]     cnt;
logic [8:0]     adr;
logic [31:0]    wdat;
logic [39:0]    rdat;           // Read data of cycle 6 - 10
logic           dbg;
logic           avl_wr;
logic           avl_rd;
logic [7:0]     avl_dat;
logic [31:0]    prdata;
logic           pready;

/*
    Logic
*/

always_ff @ (posedge CLK_IN)
begin
    if (RST_IN)
    begin
        sm_cur <= sm_idle;
        cnt <= 0;
        avl_wr <= 0;
        avl_rd <= 0;
        avl_dat <= 0;
        pready <= 0;
    end

    else
    begin
        pready <= 0;

        case (sm_cur)
            sm_idle :
            begin
                // APB setup phase
                if (APB_IF.psel && !APB_IF.penable)
                begin
                    adr <= APB_IF.paddr[10:2];
                    wdat <= APB_IF.pwdata;
                    dbg <= APB_IF.paddr[11];
                    cnt <= 0;

                    // Debug register
                    if (APB_IF.paddr[11])
                    begin
                        prdata <= rdat[31:0];
                        sm_cur <= sm_rdy;
                    end

                    else if (APB_IF.pwrite)
                    begin
                        avl_wr <= 1;
                        avl_dat <= 0;
                        sm_cur <= sm_wr;
                    end

                    else
                    begin
                        avl_rd <= 1;
                        sm_cur <= sm_rd;
                    end
                end
            end

            // Write: 5 x 0x00, byte 0, 1, 2, 3, 3
            sm_wr :
            begin
                cnt <= cnt + 'd1;
                case (cnt)
                    'd3 : avl_dat <= 0;
                    'd4 : avl_dat <= wdat[7:0];
                    'd5 : avl_dat <= wdat[15:8];
                    'd6 : avl_dat <= wdat[23:16];
                    'd7 : avl_dat <= wdat[31:24];
                    'd9 :
                    begin
                        avl_wr <= 0;
                        avl_dat <= 0;
                        cnt <= 0;
                        sm_cur <= sm_gap;
                    end
                    default : ;
                endcase
            end

            // Read
            sm_rd :
            begin
                cnt <= cnt + 'd1;

                // Read data of cycle 6 - 10 (cycle 1 is the first cycle with read asserted)
                if (cnt >= 'd5)
                    rdat <= {AVL_DAT_IN, rdat[39:8]};

                if (cnt == 'd9)
                begin
                    avl_rd <= 0;
                    cnt <= 0;
                    sm_cur <= sm_gap;
                end
            end

            // Idle gap of 5 cycles
            sm_gap :
            begin
                cnt <= cnt + 'd1;
                if (cnt == 'd4)
                begin
                    // Cycle 6 is the 0x00 byte, the register is in cycle 7 - 10
                    prdata <= rdat[39:8];
                    sm_cur <= sm_rdy;
                end
            end

            // APB ready
            sm_rdy :
            begin
                if (APB_IF.psel && APB_IF.penable)
                begin
                    pready <= 1;
                    sm_cur <= sm_idle;
                end
            end

            default : sm_cur <= sm_idle;
        endcase
    end
end

// Outputs
assign AVL_ADR_OUT = adr;
assign AVL_WR_OUT = avl_wr;
assign AVL_RD_OUT = avl_rd;
assign AVL_DAT_OUT = avl_dat;

assign APB_IF.prdata = prdata;
assign APB_IF.pready = pready;
assign APB_IF.pslverr = 0;

endmodule

`default_nettype wire
