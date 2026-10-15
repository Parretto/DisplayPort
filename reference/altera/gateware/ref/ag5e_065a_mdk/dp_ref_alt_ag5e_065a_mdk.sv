/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    DP reference design running on Altera Agilex 5 E-Series 065A Modular Development Kit
    (c) 2026 by Parretto B.V.

    History
    =======
    v1.0 - Initial release (HPS hello world)
    v1.1 - Added the DPTX transceiver (GTS bank 4A) with PCS and test pattern
    v1.2 - Added the DPTX
    v1.3 - Added the VTB and the video PLL
    v1.4 - Removed the PHY test pattern and the DPTX interrupt from the PIO
    v1.5 - The 8b/10b encoder is in the DPTX. Removed the TX link clock frequency meter (the VTB measures it)
           and the scratch PIO
    v1.6 - Added the DPRX. The transceiver is a duplex DP PHY, the DPRX has the 8b/10b decoder
    v1.7 - Added the video clock recovery (clock enable DCO in the VTB)
    v1.8 - Added the I2C master for the DP redrivers

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

// Module
module dp_ref_alt_ag5e_065a_mdk
(
    // Clock and reset
    input wire              SYS_CLK_IN,             // 100 MHz
    input wire              SYS_RSTN_IN,            // Reset (active low)

    // HPS
    input wire              HPS_OSC_CLK_IN,         // 25 MHz
    input wire              HPS_UART0_RX_IN,
    output wire             HPS_UART0_TX_OUT,

    // LED
    output wire             LED_OUT,

    // I2C (DP redrivers)
    inout wire              I2C_SCL_INOUT,
    inout wire              I2C_SDA_INOUT,

    // GTS transceiver bank 4A
    input wire              GTS_REFCLK_IN,          // 150 MHz (Si549)

    // DP TX
    output wire [3:0]       DPTX_ML_OUT_P,          // Main link
    output wire [3:0]       DPTX_ML_OUT_N,          // Main link
    output wire             DPTX_AUX_EN_OUT,        // AUX enable
    output wire             DPTX_AUX_TX_OUT,        // AUX transmit
    input wire              DPTX_AUX_RX_IN,         // AUX receive
    input wire              DPTX_HPD_IN,            // HPD (inverted)
    output wire             DPTX_CAD_OUT,           // Cable adapter detect

    // DP RX
    input wire [3:0]        DPRX_ML_IN_P,           // Main link
    input wire [3:0]        DPRX_ML_IN_N,           // Main link
    output wire             DPRX_AUX_EN_OUT,        // AUX enable
    output wire             DPRX_AUX_TX_OUT,        // AUX transmit
    input wire              DPRX_AUX_RX_IN,         // AUX receive
    output wire             DPRX_HPD_OUT            // HPD
);

// Parameters
localparam P_LANES = 4;                                 // Lanes
localparam P_SPL = 2;                                   // Symbols per lane
localparam P_PPC = 4;                                   // Pixels per clock
localparam P_BPC = 10;                                  // Bits per component
localparam P_VENDOR = "ALTERA";                         // Vendor
localparam P_FAMILY = "AGX";                            // Family (Agilex). The DPTX has the 8b/10b encoder, the DPRX the decoder
localparam P_BEAT = 'd100;                              // Beat value. The system clock is 100 MHz.
localparam P_MST = 0;                                   // MST support
localparam P_SDP = 0;                                   // SDP support
localparam P_AXIS_DAT = (P_PPC == 2) ? ((P_BPC == 10) ? 64 : 48) : ((P_BPC == 10) ? 120 : 96);
localparam P_VTB_OVL = 0;                               // VTB overlay
localparam P_VTB_OSD = 1;                               // VTB on screen display (scroller)

// Interfaces
prt_apb_if
#(
  .P_ADR_WIDTH  (12)
)
dptx_apb_if();

prt_apb_if
#(
  .P_ADR_WIDTH  (12)
)
dprx_apb_if();

prt_apb_if
#(
  .P_ADR_WIDTH  (12)
)
vtb_apb_if();

prt_apb_if
#(
  .P_ADR_WIDTH  (12)
)
vid_pll_apb_if();

prt_apb_if
#(
  .P_ADR_WIDTH  (12)
)
i2c_apb_if();

// Signals
wire        ninit_done_from_soc;
wire        rstn_to_soc;
wire        led_from_hb;

// PIO
wire [31:0]                         pio_dat_from_soc;
wire [31:0]                         pio_dat_to_soc;

// DPTX
wire                                dptx_rst_from_soc;
wire                                irq_from_dptx;
wire                                hb_from_dptx;
wire [(P_LANES * P_SPL * 11)-1:0]   lnk_dat_from_dptx;

// DPRX
wire                                dprx_rst_from_soc;
wire                                irq_from_dprx;
wire                                hb_from_dprx;
logic [(P_LANES * P_SPL * 10)-1:0]  lnk_dat_to_dprx;
wire                                lnk_sync_from_dprx;
wire                                vid_sof_from_dprx;
wire                                vid_eol_from_dprx;
wire [P_AXIS_DAT-1:0]               vid_dat_from_dprx;
wire                                vid_vld_from_dprx;

// Video
wire                                vid_clk_from_pll;
wire                                vid_lock_from_pll;
wire [8:0]                          pll_avl_adr_from_rcfg;
wire                                pll_avl_wr_from_rcfg;
wire                                pll_avl_rd_from_rcfg;
wire [7:0]                          pll_avl_dat_from_rcfg;
wire [7:0]                          pll_avl_dat_from_pll;
wire                                lock_from_vtb;
wire                                cke_from_vtb;
wire                                vs_from_vtb;
wire                                hs_from_vtb;
wire [(3 * P_PPC * P_BPC)-1:0]        dat_from_vtb;
wire                                de_from_vtb;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
logic [1:0]                         vid_lock_sync;

// PHY
wire [7:0]                          phy_ctl_from_soc;
wire [15:0]                         phy_sts_to_soc;
wire                                phy_rcfg_waitrequest;
wire [31:0]                         phy_rcfg_readdata;
wire                                phy_rcfg_readdatavalid;
wire [31:0]                         phy_rcfg_writedata;
wire [21:0]                         phy_rcfg_address;
wire                                phy_rcfg_write;
wire                                phy_rcfg_read;
wire [3:0]                          phy_rcfg_byteenable;
wire                                tx_clk_from_phy;
wire                                tx_reset_ack_from_phy;
wire                                tx_ready_from_phy;
wire [3:0]                          tx_pll_locked_from_phy;
wire                                rx_clk_from_phy;
wire                                rx_reset_ack_from_phy;
wire                                rx_ready_from_phy;
wire [3:0]                          rx_lock_from_phy;
wire [319:0]                        rx_dat_from_phy;
wire                                pma_cu_clk_from_rss;
wire [3:0]                          rss_grant_from_rss;
wire [3:0]                          rss_req_from_phy;
logic [319:0]                       tx_dat_to_phy;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
logic [11:0]                        phy_sts_meta;
logic [11:0]                        phy_sts_sync;


/*
    Logic
*/

// Reset
// The fabric reset is released after the device has entered user mode.
    assign rstn_to_soc = SYS_RSTN_IN & ~ninit_done_from_soc;

// SoC
    dp_soc_ag5e
    SOC_INST
    (
        .clk_clk                (SYS_CLK_IN),
        .rst_reset_n            (rstn_to_soc),
        .hps_io_hps_osc_clk     (HPS_OSC_CLK_IN),
        .hps_io_uart0_tx        (HPS_UART0_TX_OUT),
        .hps_io_uart0_rx        (HPS_UART0_RX_IN),
        .pio_out_export         (pio_dat_from_soc),
        .pio_in_export          (pio_dat_to_soc),
        .dptx_paddr             (dptx_apb_if.paddr),
        .dptx_psel              (dptx_apb_if.psel),
        .dptx_penable           (dptx_apb_if.penable),
        .dptx_pwrite            (dptx_apb_if.pwrite),
        .dptx_pwdata            (dptx_apb_if.pwdata),
        .dptx_prdata            (dptx_apb_if.prdata),
        .dptx_pready            (dptx_apb_if.pready),
        .dptx_pslverr           (dptx_apb_if.pslverr),
        .dptx_irq               (irq_from_dptx),
        .dprx_paddr             (dprx_apb_if.paddr),
        .dprx_psel              (dprx_apb_if.psel),
        .dprx_penable           (dprx_apb_if.penable),
        .dprx_pwrite            (dprx_apb_if.pwrite),
        .dprx_pwdata            (dprx_apb_if.pwdata),
        .dprx_prdata            (dprx_apb_if.prdata),
        .dprx_pready            (dprx_apb_if.pready),
        .dprx_pslverr           (dprx_apb_if.pslverr),
        .dprx_irq               (irq_from_dprx),
        .vtb_paddr              (vtb_apb_if.paddr),
        .vtb_psel               (vtb_apb_if.psel),
        .vtb_penable            (vtb_apb_if.penable),
        .vtb_pwrite             (vtb_apb_if.pwrite),
        .vtb_pwdata             (vtb_apb_if.pwdata),
        .vtb_prdata             (vtb_apb_if.prdata),
        .vtb_pready             (vtb_apb_if.pready),
        .vtb_pslverr            (vtb_apb_if.pslverr),
        .vtb_irq                (1'b0),
        .vid_pll_paddr          (vid_pll_apb_if.paddr),
        .vid_pll_psel           (vid_pll_apb_if.psel),
        .vid_pll_penable        (vid_pll_apb_if.penable),
        .vid_pll_pwrite         (vid_pll_apb_if.pwrite),
        .vid_pll_pwdata         (vid_pll_apb_if.pwdata),
        .vid_pll_prdata         (vid_pll_apb_if.prdata),
        .vid_pll_pready         (vid_pll_apb_if.pready),
        .vid_pll_pslverr        (vid_pll_apb_if.pslverr),
        .vid_pll_irq            (1'b0),
        .i2c_paddr              (i2c_apb_if.paddr),
        .i2c_psel               (i2c_apb_if.psel),
        .i2c_penable            (i2c_apb_if.penable),
        .i2c_pwrite             (i2c_apb_if.pwrite),
        .i2c_pwdata             (i2c_apb_if.pwdata),
        .i2c_prdata             (i2c_apb_if.prdata),
        .i2c_pready             (i2c_apb_if.pready),
        .i2c_pslverr            (i2c_apb_if.pslverr),
        .i2c_irq                (1'b0),
        .phy_ctl_export         (phy_ctl_from_soc),
        .phy_sts_export         (phy_sts_to_soc),
        .phy_rcfg_waitrequest   (phy_rcfg_waitrequest),
        .phy_rcfg_readdata      (phy_rcfg_readdata),
        .phy_rcfg_readdatavalid (phy_rcfg_readdatavalid),
        .phy_rcfg_burstcount    (),
        .phy_rcfg_writedata     (phy_rcfg_writedata),
        .phy_rcfg_address       (phy_rcfg_address),
        .phy_rcfg_write         (phy_rcfg_write),
        .phy_rcfg_read          (phy_rcfg_read),
        .phy_rcfg_byteenable    (phy_rcfg_byteenable),
        .phy_rcfg_debugaccess   (),
        .ninit_done_reset       (ninit_done_from_soc)
    );

/*
    PIO

    PIO out:
    [0]     DPTX reset (1 - reset)
    [1]     DPRX reset (1 - reset)

    PIO in:
    [0]     Pixels per clock (0 - 2 / 1 - 4)
    [1]     Bits per component (0 - 8 / 1 - 10)
    [2]     Video PLL locked
*/
    assign dptx_rst_from_soc = pio_dat_from_soc[0];
    assign dprx_rst_from_soc = pio_dat_from_soc[1];

    assign pio_dat_to_soc[0]    = (P_PPC == 4) ? 1 : 0;
    assign pio_dat_to_soc[1]    = (P_BPC == 10) ? 1 : 0;
    assign pio_dat_to_soc[2]    = vid_lock_sync[1];
    assign pio_dat_to_soc[31:3] = 0;

    always_ff @ (posedge SYS_CLK_IN)
        vid_lock_sync <= {vid_lock_sync[0], vid_lock_from_pll};

/*
    DPTX
*/
    prt_dptx_apb
    #(
        // System
        .P_VENDOR           (P_VENDOR),     // Vendor
        .P_FAMILY           (P_FAMILY),     // Family
        .P_BEAT             (P_BEAT),       // Beat value
        .P_MST              (P_MST),        // MST support
        .P_SDP              (P_SDP),        // SDP support

        // Link
        .P_LANES            (P_LANES),      // Lanes
        .P_SPL              (P_SPL),        // Symbols per lane

        // Video
        .P_PPC              (P_PPC),        // Pixels per clock
        .P_BPC              (P_BPC)         // Bits per component
    )
    DPTX_INST
    (
        // Reset and Clock
        .SYS_RST_IN         (dptx_rst_from_soc),
        .SYS_CLK_IN         (SYS_CLK_IN),

        // Host interface
        .APB_IF             (dptx_apb_if),
        .HOST_IRQ_OUT       (irq_from_dptx),

        // AUX
        .AUX_EN_OUT         (DPTX_AUX_EN_OUT),
        .AUX_TX_OUT         (DPTX_AUX_TX_OUT),
        .AUX_RX_IN          (DPTX_AUX_RX_IN),

        // Misc
        .HPD_IN             (~DPTX_HPD_IN),             // Hot plug polarity is inverted
        .HB_OUT             (hb_from_dptx),

        // Video stream 0
        .VID0_CLK_IN        (vid_clk_from_pll),
        .VID0_CKE_IN        (cke_from_vtb),
        .VID0_VS_IN         (vs_from_vtb),
        .VID0_HS_IN         (hs_from_vtb),
        .VID0_DAT_IN        (dat_from_vtb),            // Data
        .VID0_DE_IN         (de_from_vtb),

        // Secondary data packet
        .SDP_CLK_IN         (SYS_CLK_IN),
        .SDP_RDY_OUT        (),
        .SDP_SOP_IN         (1'b0),
        .SDP_EOP_IN         (1'b0),
        .SDP_DAT_IN         (32'd0),
        .SDP_VLD_IN         (1'b0),

        // Video stream 1
        .VID1_CLK_IN        (vid_clk_from_pll),
        .VID1_CKE_IN        (1'b1),
        .VID1_VS_IN         (1'b0),
        .VID1_HS_IN         (1'b0),
        .VID1_DAT_IN        ('0),                      // Data
        .VID1_DE_IN         (1'b0),

        // Link
        .LNK_CLK_IN         (tx_clk_from_phy),
        .LNK_DAT_OUT        (lnk_dat_from_dptx)
    );

    // Cable adapter detect is not used
    assign DPTX_CAD_OUT = 1'b0;

/*
    DPRX
*/
    prt_dprx_apb
    #(
        // System
        .P_VENDOR               (P_VENDOR),     // Vendor
        .P_FAMILY               (P_FAMILY),     // Family
        .P_BEAT                 (P_BEAT),       // Beat value
        .P_MST                  (P_MST),        // MST support
        .P_SDP                  (P_SDP),        // SDP support

        // Link
        .P_LANES                (P_LANES),      // Lanes
        .P_SPL                  (P_SPL),        // Symbols per lane

        // Video
        .P_PPC                  (P_PPC),        // Pixels per clock
        .P_BPC                  (P_BPC),        // Bits per component
        .P_VID_DAT              (P_AXIS_DAT)
    )
    DPRX_INST
    (
        // Reset and Clock
        .SYS_RST_IN             (dprx_rst_from_soc),
        .SYS_CLK_IN             (SYS_CLK_IN),

        // Host interface
        .APB_IF                 (dprx_apb_if),
        .HOST_IRQ_OUT           (irq_from_dprx),

        // AUX
        .AUX_EN_OUT             (DPRX_AUX_EN_OUT),
        .AUX_TX_OUT             (DPRX_AUX_TX_OUT),
        .AUX_RX_IN              (DPRX_AUX_RX_IN),

        // Misc
        .HPD_OUT                (DPRX_HPD_OUT),
        .HB_OUT                 (hb_from_dprx),

        // Link
        .LNK_CLK_IN             (rx_clk_from_phy),      // Clock
        .LNK_LOCK_IN            (1'b1),                 // Lock
        .LNK_DAT_IN             (lnk_dat_to_dprx),      // Data (10-bit code groups)
        .LNK_SYNC_OUT           (lnk_sync_from_dprx),   // Sync
        .LNK_VBID_OUT           (),
        .LNK_TRN_TPS_CR_OUT     (),                     // Link training TPS clock recovery sequence
        .LNK_TRN_TPS_EQ_OUT     (),                     // Link training TPS equalization sequence
        .LNK_TRN_TPS_PASS_OUT   (),                     // Link training TPS passed
        .LNK_TRN_TPS_FAIL_OUT   (),                     // Link training TPS failed

        // Video
        .VID_CLK_IN             (vid_clk_from_pll),     // Clock
        .VID_RDY_IN             (1'b1),                 // Ready
        .VID_SOF_OUT            (vid_sof_from_dprx),    // Start of frame
        .VID_EOL_OUT            (vid_eol_from_dprx),    // End of line
        .VID_DAT_OUT            (vid_dat_from_dprx),    // Data
        .VID_VLD_OUT            (vid_vld_from_dprx),    // Valid

        // Secondary data packet
        .SDP_CLK_IN             (SYS_CLK_IN),
        .SDP_SOP_OUT            (),
        .SDP_EOP_OUT            (),
        .SDP_DAT_OUT            (),
        .SDP_VLD_OUT            (),
        .SDP_ERR_OUT            ()
    );

/*
    Video
*/

// Video PLL
// The video clock is the pixel clock / 4. The application sets the output divider.
    vid_pll
    VID_PLL_INST
    (
        .refclk                 (SYS_CLK_IN),
        .rst                    (~rstn_to_soc),
        .locked                 (vid_lock_from_pll),
        .outclk_0               (vid_clk_from_pll),
        .core_avl_clk           (SYS_CLK_IN),
        .core_avl_address       (pll_avl_adr_from_rcfg),
        .core_avl_write         (pll_avl_wr_from_rcfg),
        .core_avl_read          (pll_avl_rd_from_rcfg),
        .core_avl_writedata     (pll_avl_dat_from_rcfg),
        .core_avl_readdata      (pll_avl_dat_from_pll)
    );

// Video PLL reconfiguration
    prt_hvio_pll_rcfg
    VID_PLL_RCFG_INST
    (
        .RST_IN                 (~rstn_to_soc),
        .CLK_IN                 (SYS_CLK_IN),
        .APB_IF                 (vid_pll_apb_if),
        .AVL_ADR_OUT            (pll_avl_adr_from_rcfg),
        .AVL_WR_OUT             (pll_avl_wr_from_rcfg),
        .AVL_RD_OUT             (pll_avl_rd_from_rcfg),
        .AVL_DAT_OUT            (pll_avl_dat_from_rcfg),
        .AVL_DAT_IN             (pll_avl_dat_from_pll)
    );

// I2C
// The I2C bus of the DP TX and DP RX redrivers (PI2DPX2063, addresses 0x53 and 0x52)
    prt_i2c_apb
    I2C_INST
    (
        .RST_IN                 (~rstn_to_soc),
        .CLK_IN                 (SYS_CLK_IN),
        .APB_IF                 (i2c_apb_if),
        .I2C_SCL_INOUT          (I2C_SCL_INOUT),
        .I2C_SDA_INOUT          (I2C_SDA_INOUT)
    );

// Video toolbox
    prt_vtb_apb
    #(
        .P_VENDOR               (P_VENDOR),
        .P_SYS_FREQ             (100_000_000),  // System frequency
        .P_PPC                  (P_PPC),        // Pixels per clock
        .P_BPC                  (P_BPC),        // Bits per component
        .P_AXIS_DAT             (P_AXIS_DAT),
        .P_OVL                  (P_VTB_OVL),    // Overlay
        .P_OSD                  (P_VTB_OSD),    // On screen display
        .P_DCO                  (1)             // Video clock recovery with the clock enable DCO
    )
    VTB_INST
    (
        // System
        .SYS_RST_IN             (dptx_rst_from_soc),
        .SYS_CLK_IN             (SYS_CLK_IN),

        // APB Interface
        .APB_IF                 (vtb_apb_if),

        // Direct I2C Access (not used, the clock recovery drives the DCO in the VTB)
        .DIA_RDY_IN             (1'b1),
        .DIA_DAT_OUT            (),
        .DIA_VLD_OUT            (),

        // Link
        .TX_LNK_CLK_IN          (tx_clk_from_phy),
        .RX_LNK_CLK_IN          (rx_clk_from_phy),      // RX link clock
        .LNK_SYNC_IN            (lnk_sync_from_dprx),

        // Axi-stream Video (pass-through)
        .AXIS_SOF_IN            (vid_sof_from_dprx),    // Start of frame
        .AXIS_EOL_IN            (vid_eol_from_dprx),    // End of line
        .AXIS_DAT_IN            (vid_dat_from_dprx),    // Data
        .AXIS_VLD_IN            (vid_vld_from_dprx),    // Valid

        // Native video
        .VID_CLK_IN             (vid_clk_from_pll),
        .VID_CKE_IN             (1'b1),
        .VID_CKE_OUT            (cke_from_vtb),         // Clock enable of the DCO
        .VID_LOCK_OUT           (lock_from_vtb),
        .VID_VS_OUT             (vs_from_vtb),
        .VID_HS_OUT             (hs_from_vtb),
        .VID_DAT_OUT            (dat_from_vtb),
        .VID_DE_OUT             (de_from_vtb)
    );

/*
    DP PHY
    Duplex: the DPTX transmitters and the DPRX receivers are in the same channels of bank 4A.

    PHY control (phy_ctl):
    [0]     TX reset (1 - reset)
    [1]     RX reset (1 - reset)

    PHY status (phy_sts):
    [0]     TX reset acknowledge
    [1]     TX ready
    [5:2]   TX PLL locked (per lane)
    [6]     RX reset acknowledge
    [7]     RX ready
    [11:8]  RX CDR locked to data (per lane)
*/

// GTS reset sequencer
    gts_rss
    RSS_INST
    (
        .o_src_rs_grant                 (rss_grant_from_rss),
        .i_src_rs_priority              (4'b0000),
        .i_src_rs_req                   (rss_req_from_phy),
        .o_pma_cu_clk                   (pma_cu_clk_from_rss),
        .i_src_rs_refclk_status_bus     (10'd0),
        .o_refclk_fail_status           (),
        .o_refclk_on_ack                (),
        .i_refclk_on                    (10'd0),
        .o_src_rs_refclk_cmd_bus        ()
    );

// Transceiver
// All lanes are clocked by the word clock of lane 0, for the transmitters and for the receivers.
// The received lanes come from the same source and have the same frequency; the RX FIFO of
// each lane takes the data over to the word clock of lane 0. The interlane aligner of the DPRX
// removes the skew between the lanes.
    dp_phy
    PHY_INST
    (
        .i_tx_pll_refclk_p              (GTS_REFCLK_IN),
        .i_rx_cdr_refclk_p              (GTS_REFCLK_IN),
        .i_pma_cu_clk                   (pma_cu_clk_from_rss),
        .i_tx_reset                     (phy_ctl_from_soc[0]),
        .i_rx_reset                     (phy_ctl_from_soc[1]),
        .o_tx_reset_ack                 (tx_reset_ack_from_phy),
        .o_rx_reset_ack                 (rx_reset_ack_from_phy),
        .o_tx_ready                     (tx_ready_from_phy),
        .o_rx_ready                     (rx_ready_from_phy),
        .i_tx_coreclkin_xcvr0           (tx_clk_from_phy),
        .i_tx_coreclkin_xcvr1           (tx_clk_from_phy),
        .i_tx_coreclkin_xcvr2           (tx_clk_from_phy),
        .i_tx_coreclkin_xcvr3           (tx_clk_from_phy),
        .o_tx_clkout_xcvr0              (tx_clk_from_phy),
        .o_tx_clkout_xcvr1              (),
        .o_tx_clkout_xcvr2              (),
        .o_tx_clkout_xcvr3              (),
        .i_rx_coreclkin_xcvr0           (rx_clk_from_phy),
        .i_rx_coreclkin_xcvr1           (rx_clk_from_phy),
        .i_rx_coreclkin_xcvr2           (rx_clk_from_phy),
        .i_rx_coreclkin_xcvr3           (rx_clk_from_phy),
        .o_rx_clkout_xcvr0              (rx_clk_from_phy),
        .o_rx_clkout_xcvr1              (),
        .o_rx_clkout_xcvr2              (),
        .o_rx_clkout_xcvr3              (),
        .i_src_rs_grant                 (rss_grant_from_rss),
        .o_src_rs_req                   (rss_req_from_phy),
        .o_tx_serial_data               (DPTX_ML_OUT_P),
        .o_tx_serial_data_n             (DPTX_ML_OUT_N),
        .i_rx_serial_data               (DPRX_ML_IN_P),
        .i_rx_serial_data_n             (DPRX_ML_IN_N),
        .o_tx_pll_locked                (tx_pll_locked_from_phy),
        .o_rx_is_lockedtodata           (rx_lock_from_phy),
        .o_rx_is_lockedtoref            (),
        .i_tx_parallel_data             (tx_dat_to_phy),
        .o_rx_parallel_data             (rx_dat_from_phy),
        .i_reconfig_clk                 (SYS_CLK_IN),
        .i_reconfig_reset               (~rstn_to_soc),
        .i_reconfig_write               (phy_rcfg_write),
        .i_reconfig_read                (phy_rcfg_read),
        .i_reconfig_address             (phy_rcfg_address[21:2]),    // Word address
        .i_reconfig_byteenable          (phy_rcfg_byteenable),
        .i_reconfig_writedata           (phy_rcfg_writedata),
        .o_reconfig_readdata            (phy_rcfg_readdata),
        .o_reconfig_waitrequest         (phy_rcfg_waitrequest),
        .o_reconfig_readdatavalid       (phy_rcfg_readdatavalid)
    );

// PHY data
// Each lane has 80 bits. With a 20-bit PMA width the code groups are in bits [19:0] and bit 38 is the data valid.
    always_ff @ (posedge tx_clk_from_phy)
    begin
        tx_dat_to_phy <= '0;
        for (int i = 0; i < P_LANES; i++)
        begin
            // The DPTX link data has a 10-bit code group in bits [9:0] of each 11-bit symbol slot
            for (int j = 0; j < P_SPL; j++)
                tx_dat_to_phy[(i * 80) + (j * 10) +: 10] <= lnk_dat_from_dptx[(((i * P_SPL) + j) * 11) +: 10];
            tx_dat_to_phy[(i * 80) + 38] <= 1'b1;
        end
    end

// RX data
// The code groups of a lane are in bits [19:0] (20-bit PMA width), the first received in bits [9:0].
    always_ff @ (posedge rx_clk_from_phy)
    begin
        for (int i = 0; i < P_LANES; i++)
            for (int j = 0; j < P_SPL; j++)
                lnk_dat_to_dprx[(((i * P_SPL) + j) * 10) +: 10] <= rx_dat_from_phy[(i * 80) + (j * 10) +: 10];
    end

// PHY status
    always_ff @ (posedge SYS_CLK_IN)
    begin
        phy_sts_meta <= {rx_lock_from_phy, rx_ready_from_phy, rx_reset_ack_from_phy, tx_pll_locked_from_phy, tx_ready_from_phy, tx_reset_ack_from_phy};
        phy_sts_sync <= phy_sts_meta;
    end

    assign phy_sts_to_soc = {4'h0, phy_sts_sync};

// System clock heartbeat
    prt_hb
    #(
        .P_BEAT ('d50_000_000)
    )
    SYS_HB_INST
    (
        .CLK_IN     (SYS_CLK_IN),
        .LED_OUT    (led_from_hb)
    );

// LED
// The LED only blinks when the fabric is out of reset.
    assign LED_OUT = led_from_hb & rstn_to_soc;

endmodule

`default_nettype wire
