/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP TX Top
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

module prt_dptx_top
#(
    // System
    parameter                                   P_VENDOR    = "none",  // Vendor "xilinx", "lattice" or "intel"
    parameter                                   P_BEAT      = 'd125,     // Beat value

    // Link
    parameter                                   P_LANES     = 4,        // Lanes
    parameter                                   P_SPL       = 2,        // Symbols per lane

    // Video
    parameter                                   P_PPC       = 2,        // Pixels per clock
    parameter                                   P_BPC       = 8         // Bits per component
)
(
    // Reset and Clock
    input wire                                  SYS_RST_IN,     // System reset
    input wire                                  SYS_CLK_IN,     // System clock

    // Host Local bus interface
    prt_dp_lb_if.lb_in                          HOST_IF,
    output wire                                 HOST_IRQ_OUT, 

    // AUX
    output wire                                 AUX_EN_OUT,
    output wire                                 AUX_TX_OUT,
    input wire                                  AUX_RX_IN,

    // Misc
    input wire                                  HPD_IN,
    output wire                                 HB_OUT,

    // Video
    input wire                                  VID_CLK_IN,    // Clock
    input wire                                  VID_CKE_IN,    // Clock enable
    input wire                                  VID_VS_IN,     // Vsync
    input wire                                  VID_HS_IN,     // Hsync
    input wire [(P_PPC * P_BPC)-1:0]            VID_R_IN,      // Red
    input wire [(P_PPC * P_BPC)-1:0]            VID_G_IN,      // Green
    input wire [(P_PPC * P_BPC)-1:0]            VID_B_IN,      // Blue
    input wire                                  VID_DE_IN,     // Data enable

    // Link
    input wire                                  LNK_CLK_IN,
    output wire [(P_LANES * P_SPL * 11)-1:0]    LNK_DAT_OUT
);

// Parameters

// Simulation
localparam P_SIM =
// synthesis translate_off
(1) ? 1 :
// synthesis translate_on
0;

// Debug
localparam P_DEBUG = 0;             // Set this parameter to 1 to enable the debug pin (pio)

// Memory init
localparam P_ROM_INIT = (P_SIM) ? ((P_VENDOR == "xilinx") ? "/home/marco/SandBox/bitbucket/displayport/software/prt_dptx_rom.mem" : "/home/marco/SandBox/bitbucket/displayport/software/prt_dptx_rom.hex") : "none";
localparam P_RAM_INIT = (P_SIM) ? ((P_VENDOR == "xilinx") ? "/home/marco/SandBox/bitbucket/displayport/software/prt_dptx_ram.mem" : "/home/marco/SandBox/bitbucket/displayport/software/prt_dptx_ram.hex") : "none";

// Hardware version
localparam P_HW_VER_MAJOR = 1;
localparam P_HW_VER_MINOR = 0;

// PIO
localparam P_PIO_IN_WIDTH = 2;
localparam P_PIO_OUT_WIDTH = 4;

// Message
localparam P_MSG_IDX    = 7;        // Index width
localparam P_MSG_DAT    = 16;       // Data width
localparam P_MSG_ID_CTL = 'h10;     // Message ID control
localparam P_MSG_ID_TPS = 'h11;     // Message ID training pattern sequence
localparam P_MSG_ID_MSA = 'h12;     // Message ID main stream attributes

// Interfaces

// Message
prt_dp_msg_if
#(
    .P_DAT_WIDTH (P_MSG_DAT)
) msg_if_from_pm();

prt_dp_msg_if
#(
    .P_DAT_WIDTH (P_MSG_DAT)
) msg_if_to_pm();

// Video
prt_dp_vid_if
#(
  .P_PPC    (P_PPC),
  .P_BPC    (P_BPC)
)
vid_if();

// Link interface
prt_dp_tx_lnk_if
#(
  .P_LANES  (P_LANES),
  .P_SPL    (P_SPL)
)
lnk_if();

// Signals
// Reset
wire                            rst_from_sys_rst;
wire                            rst_from_lnk_rst;
wire                            rst_from_vid_rst;

// Policy maker
wire [1:0]                      irq_to_pm;
wire [P_PIO_IN_WIDTH-1:0]       pio_to_pm;
wire [P_PIO_OUT_WIDTH-1:0]      pio_from_pm;

// Link
wire                            lnk_clkdet_from_lnk;
wire                            vid_clkdet_from_lnk;

genvar i, j;

/*
    System domain
*/

// Reset
    prt_dp_lib_rst
    SYS_RST_INST
    (
        .SRC_RST_IN         (SYS_RST_IN),
        .SRC_CLK_IN         (SYS_CLK_IN),
        .DST_CLK_IN         (SYS_CLK_IN),
        .DST_RST_OUT        (rst_from_sys_rst)
    );

    prt_dp_lib_rst
    LNK_RST_INST
    (
        .SRC_RST_IN         (~pio_from_pm[2]),
        .SRC_CLK_IN         (SYS_CLK_IN),
        .DST_CLK_IN         (LNK_CLK_IN),
        .DST_RST_OUT        (rst_from_lnk_rst)
    );

    prt_dp_lib_rst
    VID_RST_INST
    (
        .SRC_RST_IN         (~pio_from_pm[3]),
        .SRC_CLK_IN         (SYS_CLK_IN),
        .DST_CLK_IN         (VID_CLK_IN),
        .DST_RST_OUT        (rst_from_vid_rst)
    );

// Policy maker
    prt_dp_pm_top
    #(
        .P_VENDOR           (P_VENDOR),         // Vendor
        .P_BEAT             (P_BEAT),           // Beat value
        .P_HW_VER_MAJOR     (P_HW_VER_MAJOR),   // Hardware version major
        .P_HW_VER_MINOR     (P_HW_VER_MINOR),   // Hardware version minor
        .P_CFG              ("tx"),             // Configuration TX / RX
        .P_SIM              (P_SIM),            // Simulation
        .P_ROM_INIT_FILE    (P_ROM_INIT),
        .P_RAM_INIT_FILE    (P_RAM_INIT),
        .P_PIO_IN_WIDTH     (P_PIO_IN_WIDTH),
        .P_PIO_OUT_WIDTH    (P_PIO_OUT_WIDTH),
        .P_SPL              (P_SPL)             // Symbols per lane
    )
    PM_INST
    (
        // Reset and clock
        .RST_IN             (rst_from_sys_rst),
        .CLK_IN             (SYS_CLK_IN),

        // Interrupt
        .IRQ_IN             (irq_to_pm),

        // PIO
        .PIO_IN             (pio_to_pm),
        .PIO_OUT            (pio_from_pm),

        // Host
        .HOST_IF            (HOST_IF),
        .HOST_IRQ_OUT       (HOST_IRQ_OUT),
        
        // HPD
        .HPD_IN             (HPD_IN),
        .HPD_OUT            (),             // Not used

        // AUX
        .AUX_EN_OUT         (AUX_EN_OUT),   // Enable
        .AUX_TX_OUT         (AUX_TX_OUT),   // Transmit
        .AUX_RX_IN          (AUX_RX_IN),    // Receive

        // Message 
        .MSG_SRC_IF         (msg_if_from_pm),
        .MSG_SNK_IF         (msg_if_to_pm)
    );

// Interrupt
    assign irq_to_pm = 0;

// PIO
    assign pio_to_pm[0]     = lnk_clkdet_from_lnk;
    assign pio_to_pm[1]     = vid_clkdet_from_lnk;

// Message to PM
// A return message from the link is not used,
// However an interface must always have a source.
// Therefore the message interface must be wired with idle values
    assign msg_if_to_pm.som   = 0;
    assign msg_if_to_pm.eom   = 0;
    assign msg_if_to_pm.dat   = 0;
    assign msg_if_to_pm.vld   = 0;

// Link
    prt_dptx_lnk
    #(
        // System
        .P_VENDOR               (P_VENDOR),         // Vendor
        .P_SIM                  (P_SIM),            // Simulation

        // Link
        .P_LANES                (P_LANES),          // Lanes
        .P_SPL                  (P_SPL),            // Symbols per lane

        // Video
        .P_PPC                  (P_PPC),            // Pixels per clock
        .P_BPC                  (P_BPC),            // Bits per component

        // Message
        .P_MSG_IDX              (P_MSG_IDX),        // Index width
        .P_MSG_DAT              (P_MSG_DAT),        // Data width
        .P_MSG_ID_CTL           (P_MSG_ID_CTL),     // Message ID control
        .P_MSG_ID_TPS           (P_MSG_ID_TPS),     // Message ID training pattern sequence
        .P_MSG_ID_MSA           (P_MSG_ID_MSA)      // Message ID main stream attributes
    )
    LNK_INST
    (
        // System
        .SYS_RST_IN             (rst_from_sys_rst),     // System reset
        .SYS_CLK_IN             (SYS_CLK_IN),           // System clock

        // Status
        .STA_LNK_CLKDET_OUT     (lnk_clkdet_from_lnk),  // Link clock detect
        .STA_VID_CLKDET_OUT     (vid_clkdet_from_lnk),  // Video clock detect

        // MSG sink
        .MSG_SNK_IF             (msg_if_from_pm),       

        // Video
        .VID_RST_IN             (rst_from_vid_rst),     // Reset
        .VID_CLK_IN             (VID_CLK_IN),           // Clock
        .VID_CKE_IN             (VID_CKE_IN),           // Clock enable
        .VID_SNK_IF             (vid_if),               // Interface

        // Link
        .LNK_RST_IN             (rst_from_lnk_rst),     // Reset
        .LNK_CLK_IN             (LNK_CLK_IN),           // Clock
        .LNK_SRC_IF             (lnk_if)                // Interface
    );

// Map video interface
    assign vid_if.vs        = VID_VS_IN;
    assign vid_if.hs        = VID_HS_IN;
    assign vid_if.dat[0]    = VID_R_IN;
    assign vid_if.dat[1]    = VID_G_IN;
    assign vid_if.dat[2]    = VID_B_IN;
    assign vid_if.de        = VID_DE_IN;

// Outputs
    assign HB_OUT  = pio_from_pm[0];

    generate
        for (i = 0; i < P_LANES; i++)
        begin : gen_lnk_dat
            for (j = 0; j < P_SPL; j++)
            begin
                assign LNK_DAT_OUT[(i*P_SPL*11)+(j*11)+:11] = {lnk_if.disp_ctl[i][j], lnk_if.disp_val[i][j], lnk_if.k[i][j], lnk_if.dat[i][j]};
            end
        end
    endgenerate

// Debug tap
generate 
    if (P_DEBUG == 1)
    begin : gen_debug
        (* mark_debug = "true" *)       logic sclk_dbg;
        (* mark_debug = "true" *)       wire lclk_dbg;

    // Debug (system clock)
        always_ff @ (SYS_CLK_IN)
        begin
            sclk_dbg <= pio_from_pm[1];
        end

    // Debug (link clock)
        prt_dp_lib_cdc_bit
        LCLK_DBG_CDC_INST
        (
            .SRC_CLK_IN         (SYS_CLK_IN),    // Clock
            .SRC_DAT_IN         (sclk_dbg),      // Data
            .DST_CLK_IN         (LNK_CLK_IN),    // Clock
            .DST_DAT_OUT        (lclk_dbg)       // Data
        );
    end
endgenerate

endmodule

`default_nettype wire
