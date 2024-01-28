/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP RX Top
    (c) 2021 - 2024 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Initial MST support
    v1.2 - Added training TPS4 
    
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

module prt_dprx_top
#(
    // System
    parameter                                   P_VENDOR    = "none",       // Vendor "xilinx", "lattice" or "intel"
    parameter                                   P_BEAT      = 'd125,        // Beat value
    parameter                                   P_MST       = 0,            // MST support

    // Link
    parameter                                   P_LANES     = 4,            // Lanes
    parameter                                   P_SPL       = 2,            // Symbols per lane

    // Video
    parameter                                   P_PPC       = 2,            // Pixels per clock
    parameter                                   P_BPC       = 8,            // Bits per component
    parameter                                   P_VID_DAT   = 48
)
(
    // Reset and clock
    input wire                                  SYS_RST_IN,
    input wire                                  SYS_CLK_IN,

    // Host Local bus interface
    prt_dp_lb_if.lb_in                          HOST_IF,
    output wire                                 HOST_IRQ_OUT, 

    // Misc
    output wire                                 HPD_OUT,
    output wire                                 HB_OUT,

    // AUX
    output wire                                 AUX_EN_OUT,
    output wire                                 AUX_TX_OUT,
    input wire                                  AUX_RX_IN,

    // Link
    input wire                                  LNK_CLK_IN,         // Clock
    input wire [(P_LANES * P_SPL * 9)-1:0]      LNK_DAT_IN,         // Data
    output wire                                 LNK_SYNC_OUT,       // Sync

    // Video
    input wire                                  VID_CLK_IN,         // Clock
    input wire                                  VID_RDY_IN,         // Ready
    output wire                                 VID_SOF_OUT,        // Start of frame
    output wire                                 VID_EOL_OUT,        // End of line
    output wire [P_VID_DAT-1:0]                 VID_DAT_OUT,        // Data
    output wire                                 VID_VLD_OUT         // Valid
);

// Parameters
localparam P_SIM =
// synthesis translate_off
(1) ? 1 :
// synthesis translate_on
0;

// Debug
localparam P_DEBUG = 0;             // Set this parameter to 1 to enable the debug pin (pio)

// Memory init
localparam P_ROM_INIT = (P_SIM) ? (P_VENDOR == "xilinx") ? "prt_dprx_pm_rom.mem" : (P_VENDOR == "intel") ? "prt_dprx_pm_rom.hex" : "none" : "none";
localparam P_RAM_INIT = (P_SIM) ? (P_VENDOR == "xilinx") ? "prt_dprx_pm_ram.mem" : (P_VENDOR == "intel") ? "prt_dprx_pm_ram.hex" : "none" : "none";

// Hardware version
localparam P_HW_VER_MAJOR = 1;
localparam P_HW_VER_MINOR = 0;

// PIO
localparam P_PIO_IN_WIDTH = 4;
localparam P_PIO_OUT_WIDTH = 4;

// Message
localparam P_MSG_IDX    = 5;        // Index width
localparam P_MSG_DAT    = 16;       // Data width
localparam P_MSG_ID_CTL = 'h10;     // Message ID control
localparam P_MSG_ID_TRN = 'h11;     // Message ID training 
localparam P_MSG_ID_MSA = 'h12;     // Message ID main stream attributes
localparam P_MSG_ID_VID = 'h13;     // Message ID video

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

// Link interface
prt_dp_rx_lnk_if
#(
    .P_LANES  (P_LANES),
    .P_SPL    (P_SPL)
)
lnk_if();

prt_dp_axis_if
#(
    .P_DAT_WIDTH (P_VID_DAT)
)
vid_if();

wire lnk_clkdet_from_lnk;
wire cdr_lock_from_lnk;
wire scrm_lock_from_lnk;
wire vid_en_from_lnk;
wire msa_irq_from_lnk;

genvar i, j;


/*
    System domain
*/

// Reset
    prt_dp_lib_rst
    RST_INST
    (
        .SRC_RST_IN     (SYS_RST_IN),
        .SRC_CLK_IN     (SYS_CLK_IN),
        .DST_CLK_IN     (SYS_CLK_IN),
        .DST_RST_OUT    (rst_from_sys_rst)
    );

    prt_dp_lib_rst
    LNK_RST_INST
    (
        .SRC_RST_IN     (~pio_from_pm[2]),
        .SRC_CLK_IN     (SYS_CLK_IN),
        .DST_CLK_IN     (LNK_CLK_IN),
        .DST_RST_OUT    (rst_from_lnk_rst)
    );

    prt_dp_lib_rst
    VID_RST_INST
    (
        .SRC_RST_IN     (~pio_from_pm[3]),
        .SRC_CLK_IN     (SYS_CLK_IN),
        .DST_CLK_IN     (VID_CLK_IN),
        .DST_RST_OUT    (rst_from_vid_rst)
    );

// Policy maker
    prt_dp_pm_top
    #(
        .P_VENDOR           (P_VENDOR),         // Vendor
        .P_BEAT             (P_BEAT),           // Beat value
        .P_HW_VER_MAJOR     (P_HW_VER_MAJOR),   // Hardware version major
        .P_HW_VER_MINOR     (P_HW_VER_MINOR),   // Hardware version minor
        .P_CFG              ("rx"),             // Configuration TX / RX
        .P_SIM              (P_SIM),            // Simulation
        .P_ROM_INIT_FILE    (P_ROM_INIT),
        .P_RAM_INIT_FILE    (P_RAM_INIT),
        .P_PIO_IN_WIDTH     (P_PIO_IN_WIDTH),
        .P_PIO_OUT_WIDTH    (P_PIO_OUT_WIDTH),
        .P_SPL              (P_SPL)             // Symbols per lane
    )
    PM_INST
    (
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
        .HPD_IN             (1'b0),             // Not used
        .HPD_OUT            (HPD_OUT),

        // AUX
        .AUX_EN_OUT         (AUX_EN_OUT),       // Enable
        .AUX_TX_OUT         (AUX_TX_OUT),       // Transmit
        .AUX_RX_IN          (AUX_RX_IN),        // Receive

        // Message 
        .MSG_SRC_IF         (msg_if_from_pm),   // Sink
        .MSG_SNK_IF         (msg_if_to_pm)      // Source
    );

// PIO
    assign pio_to_pm[0]     = lnk_clkdet_from_lnk;
    assign pio_to_pm[1]     = cdr_lock_from_lnk;
    assign pio_to_pm[2]     = scrm_lock_from_lnk;
    assign pio_to_pm[3]     = vid_en_from_lnk;
    assign irq_to_pm[0]     = msa_irq_from_lnk;
    assign irq_to_pm[1]     = 0;

/*
    Link domain
*/

// Link
    prt_dprx_lnk
    #(
        // System
        .P_VENDOR           (P_VENDOR),         // Vendor
        .P_SIM              (P_SIM),            // Simulation
        .P_MST              (P_MST),            // MST support

        // Link
        .P_LANES            (P_LANES),          // Lanes
        .P_SPL              (P_SPL),            // Symbols per lane

        // Video
        .P_PPC              (P_PPC),            // Pixels per clock
        .P_BPC              (P_BPC),            // Bits per component
        .P_VID_DAT          (P_VID_DAT),        // AXIS data width

        // Message
        .P_MSG_IDX          (P_MSG_IDX),        // Index width
        .P_MSG_DAT          (P_MSG_DAT),        // Data width
        .P_MSG_ID_CTL       (P_MSG_ID_CTL),     // Message ID control
        .P_MSG_ID_TRN       (P_MSG_ID_TRN),     // Message ID training
        .P_MSG_ID_MSA       (P_MSG_ID_MSA),     // Message ID msa
        .P_MSG_ID_VID       (P_MSG_ID_VID)      // Message ID video
    )
    LNK_INST
    (
        // System
        .SYS_RST_IN         (rst_from_sys_rst),     // Reset
        .SYS_CLK_IN         (SYS_CLK_IN),           // Clock

        // Status
        .STA_LNK_CLKDET_OUT (lnk_clkdet_from_lnk),  // Link clock detect
        .STA_CDR_LOCK_OUT   (cdr_lock_from_lnk),    // CDR lock
        .STA_SCRM_LOCK_OUT  (scrm_lock_from_lnk),   // Scrambler lock
        .STA_VID_EN_OUT     (vid_en_from_lnk),      // Video enable

        // Interrupts
        .MSA_IRQ_OUT        (msa_irq_from_lnk),     

        // Message
        .MSG_SNK_IF         (msg_if_from_pm),       // Sink
        .MSG_SRC_IF         (msg_if_to_pm),         // Source

        // Link sink
        .LNK_RST_IN         (rst_from_lnk_rst),     // Reset
        .LNK_CLK_IN         (LNK_CLK_IN),           // Clock
        .LNK_SNK_IF         (lnk_if),               // Interface
        .LNK_SYNC_OUT       (LNK_SYNC_OUT),
        
        // Video source
        .VID_RST_IN         (rst_from_vid_rst),     // Reset
        .VID_CLK_IN         (VID_CLK_IN),           // Clock
        .VID_SRC_IF         (vid_if)                // Interface
    );

    // Video ready
    assign vid_if.rdy = VID_RDY_IN;

// Map link interface
    generate
        for (i = 0; i < P_LANES; i++)
        begin : gen_lnk_if
            for (j = 0; j < P_SPL; j++)
            begin
                assign lnk_if.vid[i][j] = 0;        // Not used
                assign lnk_if.sec[i][j] = 0;        // Not used
                assign lnk_if.msa[i][j] = 0;        // Not used              
                assign lnk_if.k[i][j]   = LNK_DAT_IN[(i*P_SPL*9)+(j*9)+8];
                assign lnk_if.dat[i][j] = LNK_DAT_IN[((i*P_SPL*9)+(j*9))+:8];
            end
        end
    endgenerate

    // Lock
    assign lnk_if.lock = 1'b1;

// Outputs
assign HB_OUT = pio_from_pm[0];

assign VID_SOF_OUT = vid_if.sof;
assign VID_EOL_OUT = vid_if.eol;
assign VID_DAT_OUT = vid_if.dat;
assign VID_VLD_OUT = vid_if.vld;

// Debug tap
generate 
    if (P_DEBUG == 1)
    begin : gen_debug
//        (* mark_debug = "true" *)       logic sclk_dbg;
  //      (* mark_debug = "true" *)       wire lclk_dbg;
        
        (* preserve *) logic sclk_dbg;
        (* preserve *) wire lclk_dbg;

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
