/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: APB export
    (c) 2026 by Parretto B.V.

    Platform Designer component with an APB slave interface and an interrupt sender.
    The APB signals and the interrupt are exported, so an APB slave in the top level
    (for example prt_dptx_apb) can be connected to the Platform Designer system.

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

module prt_apb_exp
#(
    parameter P_ADR_WIDTH = 12          // Address width (bytes)
)
(
    // Clock and reset (not used, the interface is synchronous to the system clock)
    input wire                      clk,
    input wire                      reset,

    // APB slave (Platform Designer)
    input wire [P_ADR_WIDTH-1:0]    s_paddr,
    input wire                      s_psel,
    input wire                      s_penable,
    input wire                      s_pwrite,
    input wire [31:0]               s_pwdata,
    output wire [31:0]              s_prdata,
    output wire                     s_pready,
    output wire                     s_pslverr,

    // Interrupt sender (Platform Designer)
    output wire                     irq,

    // APB master (exported)
    output wire [P_ADR_WIDTH-1:0]   m_paddr,
    output wire                     m_psel,
    output wire                     m_penable,
    output wire                     m_pwrite,
    output wire [31:0]              m_pwdata,
    input wire [31:0]               m_prdata,
    input wire                      m_pready,
    input wire                      m_pslverr,
    input wire                      m_irq
);

    assign m_paddr = s_paddr;
    assign m_psel = s_psel;
    assign m_penable = s_penable;
    assign m_pwrite = s_pwrite;
    assign m_pwdata = s_pwdata;
    assign s_prdata = m_prdata;
    assign s_pready = m_pready;
    assign s_pslverr = m_pslverr;
    assign irq = m_irq;

endmodule

`default_nettype wire
