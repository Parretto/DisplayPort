/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    DP reference design running on the Enclustra Mercury+ XU6 (Zynq UltraScale+ ZU4CG) on the Mercury+ ST1
    base board with the Tentiva FMC
    (c) 2026 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - The transmitters run from QPLL1 and the receivers from the CPLL (as the AMD Video PHY Controller),
           the DRP and free running clock is 40 MHz
    v1.2 - PHY status of the CPLL lock, RX PMA reset done, RX CDR stable and the user clocks

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
module dp_ref_amd_zu4cg_xu6_st1
(
    // UART (PS UART0 over EMIO, Tentiva)
    input wire              UART_RX_IN,
    output wire             UART_TX_OUT,

    // I2C (Tentiva)
    inout wire              I2C_SCL_INOUT,
    inout wire              I2C_SDA_INOUT,

    // Tentiva
    input wire              TENTIVA_VID_CLK_IN_P,       // Video clock
    input wire              TENTIVA_VID_CLK_IN_N,

    // DP TX
    output wire             DPTX_AUX_EN_OUT,            // AUX enable
    output wire             DPTX_AUX_TX_OUT,            // AUX transmit
    input wire              DPTX_AUX_RX_IN,             // AUX receive
    input wire              DPTX_HPD_IN,                // HPD (inverted)
    output wire             DPTX_I2C_SEL_OUT,           // I2C select (DP21 TX)

    // DP RX
    output wire             DPRX_AUX_EN_OUT,            // AUX enable
    output wire             DPRX_AUX_TX_OUT,            // AUX transmit
    input wire              DPRX_AUX_RX_IN,             // AUX receive
    output wire             DPRX_HPD_OUT,               // HPD
    output wire             DPRX_I2C_SEL_OUT,           // I2C select (DP21 RX)

    // GTH transceivers (quad X0Y1)
    input wire              GT_REFCLK_IN_P,             // 270 MHz (Tentiva)
    input wire              GT_REFCLK_IN_N,
    input wire [3:0]        GT_RX_IN_P,                 // DP RX main link
    input wire [3:0]        GT_RX_IN_N,
    output wire [3:0]       GT_TX_OUT_P,                // DP TX main link
    output wire [3:0]       GT_TX_OUT_N,

    // LED (active low)
    output wire [3:0]       LED_OUT
);

// Parameters
localparam P_LANES = 4;                                 // Lanes
localparam P_SPL = 4;                                   // Symbols per lane
localparam P_PPC = 4;                                   // Pixels per clock
localparam P_BPC = 10;                                  // Bits per component
localparam P_VENDOR = "AMD";                            // Vendor. The 8b/10b encoder and decoder are in the transceiver.
localparam P_SYS_FREQ = 100_000_000;                    // System frequency
localparam P_BEAT = P_SYS_FREQ / 1_000_000;             // Beat value
localparam P_MST = 0;                                   // MST support
localparam P_SDP = 0;                                   // SDP support
localparam P_AXIS_DAT = (P_PPC == 2) ? ((P_BPC == 10) ? 64 : 48) : ((P_BPC == 10) ? 120 : 96);
localparam P_VTB_OVL = 0;                               // VTB overlay
localparam P_VTB_OSD = 1;                               // VTB on screen display (scroller)

localparam P_PHY_CTL_DRP_PORTS = 5;                     // Four channels and the common
localparam P_PHY_CTL_PIO_IN = 20;
localparam P_PHY_CTL_PIO_OUT = 16;

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
phy_apb_if();

prt_apb_if
#(
  .P_ADR_WIDTH  (12)
)
i2c_apb_if();

// Signals
wire                                sys_clk_from_soc;
wire                                drp_clk_from_soc;
wire                                sys_rstn_from_soc;
wire [31:0]                         dptx_paddr_from_soc;
wire [31:0]                         dprx_paddr_from_soc;
wire [31:0]                         vtb_paddr_from_soc;
wire [31:0]                         phy_paddr_from_soc;
wire [31:0]                         i2c_paddr_from_soc;

// PIO
wire [31:0]                         pio_dat_from_soc;
wire [31:0]                         pio_dat_to_soc;

// Clocks
wire                                clk_from_vid_ibuf;
wire                                vid_clk_from_bufg;
wire                                clk_from_gt_ibuf;
wire                                odiv2_from_gt_ibuf;
wire                                gt_refclk_from_bufg;

// DPTX
wire                                dptx_rst_from_soc;
wire                                irq_from_dptx;
wire                                hb_from_dptx;
wire [(P_LANES * P_SPL * 11)-1:0]   lnk_dat_from_dptx;

// DPRX
wire                                dprx_rst_from_soc;
wire                                irq_from_dprx;
wire                                hb_from_dprx;
logic [(P_LANES * P_SPL * 9)-1:0]   lnk_dat_to_dprx;
wire                                lnk_sync_from_dprx;
wire                                vid_sof_from_dprx;
wire                                vid_eol_from_dprx;
wire [P_AXIS_DAT-1:0]               vid_dat_from_dprx;
wire                                vid_vld_from_dprx;

// VTB
wire                                lock_from_vtb;
wire                                vs_from_vtb;
wire                                hs_from_vtb;
wire [(3 * P_PPC * P_BPC)-1:0]      dat_from_vtb;
wire                                de_from_vtb;

// PHY controller
wire [(P_PHY_CTL_DRP_PORTS * 10)-1:0]   drp_adr_from_phy_ctl;
wire [(P_PHY_CTL_DRP_PORTS * 16)-1:0]   drp_dat_from_phy_ctl;
wire [P_PHY_CTL_DRP_PORTS-1:0]          drp_en_from_phy_ctl;
wire [P_PHY_CTL_DRP_PORTS-1:0]          drp_wr_from_phy_ctl;
wire [P_PHY_CTL_PIO_IN-1:0]             pio_dat_to_phy_ctl;
wire [P_PHY_CTL_PIO_OUT-1:0]            pio_dat_from_phy_ctl;
wire                                    tx_pll_and_dp_rst_from_phy_ctl;
wire                                    tx_dp_rst_from_phy_ctl;
wire                                    rx_pll_and_dp_rst_from_phy_ctl;
wire                                    rx_dp_rst_from_phy_ctl;
wire [1:0]                              rx_linerate_from_phy_ctl;
wire [4:0]                              tx_diffctrl_from_phy_ctl;
wire [4:0]                              tx_postcursor_from_phy_ctl;

// PHY
wire [(P_PHY_CTL_DRP_PORTS * 16)-1:0]   drp_dat_from_phy;
wire [P_PHY_CTL_DRP_PORTS-1:0]          drp_rdy_from_phy;
wire [3:0]                              pwrgd_from_phy;
wire                                    tx_rst_done_from_phy;
wire                                    rx_rst_done_from_phy;
wire [3:0]                              rx_cdrlock_from_phy;
wire [3:0]                              cplllock_from_phy;
wire [3:0]                              rx_pmarstdone_from_phy;
wire                                    rx_cdr_stable_from_phy;
wire                                    rx_usrclk_act_from_phy;
wire                                    tx_usrclk_act_from_phy;
wire                                    qpll_lock_from_phy;
wire                                    tx_clk_from_phy;
wire                                    rx_clk_from_phy;
logic [(P_LANES * 32)-1:0]              tx_dat_to_phy;
logic [(P_LANES * 16)-1:0]              txctrl0_to_phy;
logic [(P_LANES * 16)-1:0]              txctrl1_to_phy;
logic [(P_LANES * 8)-1:0]               txctrl2_to_phy;
wire [(P_LANES * 32)-1:0]               rx_dat_from_phy;
wire [(P_LANES * 16)-1:0]               rxctrl0_from_phy;
(* ASYNC_REG = "TRUE" *) logic [1:0]    rx_linerate_meta;
logic [1:0]                             rx_linerate_sync;
logic [17:0]                            cpll_cal_period_to_phy;
logic [17:0]                            cpll_cal_tol_to_phy;

// Heartbeat
wire                                led_from_sys_hb;
wire                                led_from_vid_hb;
wire                                led_from_gt_hb;


/*
    Logic
*/

// SoC
    dp_soc_zu4cg_wrapper
    SOC_INST
    (
        .sys_clk                (sys_clk_from_soc),
        .drp_clk                (drp_clk_from_soc),
        .sys_rstn               (sys_rstn_from_soc),
        .uart_txd               (UART_TX_OUT),
        .uart_rxd               (UART_RX_IN),
        .pio_out                (pio_dat_from_soc),
        .pio_in                 (pio_dat_to_soc),
        .irq                    ({irq_from_dprx, irq_from_dptx}),
        .dptx_paddr             (dptx_paddr_from_soc),
        .dptx_psel              (dptx_apb_if.psel),
        .dptx_penable           (dptx_apb_if.penable),
        .dptx_pwrite            (dptx_apb_if.pwrite),
        .dptx_pwdata            (dptx_apb_if.pwdata),
        .dptx_prdata            (dptx_apb_if.prdata),
        .dptx_pready            (dptx_apb_if.pready),
        .dptx_pslverr           (dptx_apb_if.pslverr),
        .dprx_paddr             (dprx_paddr_from_soc),
        .dprx_psel              (dprx_apb_if.psel),
        .dprx_penable           (dprx_apb_if.penable),
        .dprx_pwrite            (dprx_apb_if.pwrite),
        .dprx_pwdata            (dprx_apb_if.pwdata),
        .dprx_prdata            (dprx_apb_if.prdata),
        .dprx_pready            (dprx_apb_if.pready),
        .dprx_pslverr           (dprx_apb_if.pslverr),
        .vtb_paddr              (vtb_paddr_from_soc),
        .vtb_psel               (vtb_apb_if.psel),
        .vtb_penable            (vtb_apb_if.penable),
        .vtb_pwrite             (vtb_apb_if.pwrite),
        .vtb_pwdata             (vtb_apb_if.pwdata),
        .vtb_prdata             (vtb_apb_if.prdata),
        .vtb_pready             (vtb_apb_if.pready),
        .vtb_pslverr            (vtb_apb_if.pslverr),
        .phy_paddr              (phy_paddr_from_soc),
        .phy_psel               (phy_apb_if.psel),
        .phy_penable            (phy_apb_if.penable),
        .phy_pwrite             (phy_apb_if.pwrite),
        .phy_pwdata             (phy_apb_if.pwdata),
        .phy_prdata             (phy_apb_if.prdata),
        .phy_pready             (phy_apb_if.pready),
        .phy_pslverr            (phy_apb_if.pslverr),
        .i2c_paddr              (i2c_paddr_from_soc),
        .i2c_psel               (i2c_apb_if.psel),
        .i2c_penable            (i2c_apb_if.penable),
        .i2c_pwrite             (i2c_apb_if.pwrite),
        .i2c_pwdata             (i2c_apb_if.pwdata),
        .i2c_prdata             (i2c_apb_if.prdata),
        .i2c_pready             (i2c_apb_if.pready),
        .i2c_pslverr            (i2c_apb_if.pslverr)
    );

    // The APB bridge drives the full address, each peripheral decodes 4 KB
    assign dptx_apb_if.paddr = dptx_paddr_from_soc[11:0];
    assign dprx_apb_if.paddr = dprx_paddr_from_soc[11:0];
    assign vtb_apb_if.paddr  = vtb_paddr_from_soc[11:0];
    assign phy_apb_if.paddr  = phy_paddr_from_soc[11:0];
    assign i2c_apb_if.paddr  = i2c_paddr_from_soc[11:0];

/*
    PIO

    PIO out:
    [0]     DPTX reset (1 - reset)
    [1]     DPRX reset (1 - reset)

    PIO in:
    [0]     Pixels per clock (0 - 2 / 1 - 4)
    [1]     Bits per component (0 - 8 / 1 - 10)
*/
    assign dptx_rst_from_soc = pio_dat_from_soc[0];
    assign dprx_rst_from_soc = pio_dat_from_soc[1];

    assign pio_dat_to_soc[0]    = (P_PPC == 4) ? 1 : 0;
    assign pio_dat_to_soc[1]    = (P_BPC == 10) ? 1 : 0;
    assign pio_dat_to_soc[31:2] = 0;

/*
    Clocks
*/

// Video clock (Tentiva)
// The Tentiva generates the video clock (pixel clock / 4). In the pass-through the application
// steers it with the clock recovery of the VTB.
    IBUFDS
    VID_IBUFDS_INST
    (
        .I      (TENTIVA_VID_CLK_IN_P),
        .IB     (TENTIVA_VID_CLK_IN_N),
        .O      (clk_from_vid_ibuf)
    );

    BUFG
    VID_BUFG_INST
    (
        .I      (clk_from_vid_ibuf),
        .O      (vid_clk_from_bufg)
    );

// GT reference clock
    IBUFDS_GTE4
    #(
        .REFCLK_EN_TX_PATH  (1'b0),
        .REFCLK_HROW_CK_SEL (2'b00),
        .REFCLK_ICNTL_RX    (2'b00)
    )
    GT_IBUFDS_INST
    (
        .I      (GT_REFCLK_IN_P),
        .IB     (GT_REFCLK_IN_N),
        .CEB    (1'b0),
        .O      (clk_from_gt_ibuf),
        .ODIV2  (odiv2_from_gt_ibuf)
    );

    // Only for the heartbeat
    BUFG_GT
    GT_BUFG_INST
    (
        .CE       (1'b1),
        .CEMASK   (1'b0),
        .CLR      (1'b0),
        .CLRMASK  (1'b0),
        .DIV      (3'd0),
        .I        (odiv2_from_gt_ibuf),
        .O        (gt_refclk_from_bufg)
    );

/*
    DPTX
*/
    prt_dptx_apb
    #(
        // System
        .P_VENDOR           (P_VENDOR),     // Vendor
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
        .SYS_CLK_IN         (sys_clk_from_soc),

        // Host interface
        .APB_IF             (dptx_apb_if),
        .HOST_IRQ_OUT       (irq_from_dptx),

        // AUX
        .AUX_EN_OUT         (DPTX_AUX_EN_OUT),
        .AUX_TX_OUT         (DPTX_AUX_TX_OUT),
        .AUX_RX_IN          (DPTX_AUX_RX_IN),

        // Misc
        .HPD_IN             (~DPTX_HPD_IN),         // Hot plug polarity is inverted
        .HB_OUT             (hb_from_dptx),

        // Video stream 0
        .VID0_CLK_IN        (vid_clk_from_bufg),
        .VID0_CKE_IN        (1'b1),
        .VID0_VS_IN         (vs_from_vtb),
        .VID0_HS_IN         (hs_from_vtb),
        .VID0_DAT_IN        (dat_from_vtb),
        .VID0_DE_IN         (de_from_vtb),

        // Secondary data packet
        .SDP_CLK_IN         (sys_clk_from_soc),
        .SDP_RDY_OUT        (),
        .SDP_SOP_IN         (1'b0),
        .SDP_EOP_IN         (1'b0),
        .SDP_DAT_IN         (32'd0),
        .SDP_VLD_IN         (1'b0),

        // Video stream 1
        .VID1_CLK_IN        (vid_clk_from_bufg),
        .VID1_CKE_IN        (1'b1),
        .VID1_VS_IN         (1'b0),
        .VID1_HS_IN         (1'b0),
        .VID1_DAT_IN        ('0),
        .VID1_DE_IN         (1'b0),

        // Link
        .LNK_CLK_IN         (tx_clk_from_phy),
        .LNK_DAT_OUT        (lnk_dat_from_dptx)
    );

    // Only for the DP21 TX card. Selects the FMC I2C interface.
    assign DPTX_I2C_SEL_OUT = 1'b1;

/*
    DPRX
*/
    prt_dprx_apb
    #(
        // System
        .P_VENDOR               (P_VENDOR),     // Vendor
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
        .SYS_CLK_IN             (sys_clk_from_soc),

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
        .LNK_DAT_IN             (lnk_dat_to_dprx),      // Data (decoded symbols with the K bit)
        .LNK_SYNC_OUT           (lnk_sync_from_dprx),   // Sync
        .LNK_VBID_OUT           (),
        .LNK_TRN_TPS_CR_OUT     (),                     // Link training TPS clock recovery sequence
        .LNK_TRN_TPS_EQ_OUT     (),                     // Link training TPS equalization sequence
        .LNK_TRN_TPS_PASS_OUT   (),                     // Link training TPS passed
        .LNK_TRN_TPS_FAIL_OUT   (),                     // Link training TPS failed

        // Video
        .VID_CLK_IN             (vid_clk_from_bufg),    // Clock
        .VID_RDY_IN             (1'b1),                 // Ready
        .VID_SOF_OUT            (vid_sof_from_dprx),    // Start of frame
        .VID_EOL_OUT            (vid_eol_from_dprx),    // End of line
        .VID_DAT_OUT            (vid_dat_from_dprx),    // Data
        .VID_VLD_OUT            (vid_vld_from_dprx),    // Valid

        // Secondary data packet
        .SDP_CLK_IN             (sys_clk_from_soc),
        .SDP_SOP_OUT            (),
        .SDP_EOP_OUT            (),
        .SDP_DAT_OUT            (),
        .SDP_VLD_OUT            (),
        .SDP_ERR_OUT            ()
    );

    // Only for the DP21 RX card. Selects the FMC I2C interface.
    assign DPRX_I2C_SEL_OUT = 1'b1;

/*
    Video
*/

// I2C
// The I2C bus of the Tentiva (clock generators, cards and system controller)
    prt_i2c_apb
    I2C_INST
    (
        .RST_IN                 (~sys_rstn_from_soc),
        .CLK_IN                 (sys_clk_from_soc),
        .APB_IF                 (i2c_apb_if),
        .I2C_SCL_INOUT          (I2C_SCL_INOUT),
        .I2C_SDA_INOUT          (I2C_SDA_INOUT)
    );

// Video toolbox
    prt_vtb_apb
    #(
        .P_VENDOR               (P_VENDOR),
        .P_SYS_FREQ             (P_SYS_FREQ),   // System frequency
        .P_PPC                  (P_PPC),        // Pixels per clock
        .P_BPC                  (P_BPC),        // Bits per component
        .P_AXIS_DAT             (P_AXIS_DAT),
        .P_OVL                  (P_VTB_OVL),    // Overlay
        .P_OSD                  (P_VTB_OSD)     // On screen display
    )
    VTB_INST
    (
        // System
        .SYS_RST_IN             (dptx_rst_from_soc),
        .SYS_CLK_IN             (sys_clk_from_soc),

        // APB Interface
        .APB_IF                 (vtb_apb_if),

        // Direct I2C Access (not used)
        .DIA_RDY_IN             (1'b1),
        .DIA_DAT_OUT            (),
        .DIA_VLD_OUT            (),

        // Link
        .TX_LNK_CLK_IN          (tx_clk_from_phy),
        .RX_LNK_CLK_IN          (rx_clk_from_phy),
        .LNK_SYNC_IN            (lnk_sync_from_dprx),

        // Axi-stream Video (pass-through)
        .AXIS_SOF_IN            (vid_sof_from_dprx),    // Start of frame
        .AXIS_EOL_IN            (vid_eol_from_dprx),    // End of line
        .AXIS_DAT_IN            (vid_dat_from_dprx),    // Data
        .AXIS_VLD_IN            (vid_vld_from_dprx),    // Valid

        // Native video
        .VID_CLK_IN             (vid_clk_from_bufg),
        .VID_CKE_IN             (1'b1),
        .VID_CKE_OUT            (),
        .VID_LOCK_OUT           (lock_from_vtb),
        .VID_VS_OUT             (vs_from_vtb),
        .VID_HS_OUT             (hs_from_vtb),
        .VID_DAT_OUT            (dat_from_vtb),
        .VID_DE_OUT             (de_from_vtb)
    );

/*
    DP PHY
    Duplex: the DPTX transmitters and the DPRX receivers are in the same four channels.
    As in the AMD Video PHY Controller, the transmitters run from QPLL1 and the receivers from the CPLL.

    PHY controller PIO out:
    [0]     TX PLL and datapath reset
    [1]     TX datapath reset
    [2]     RX PLL and datapath reset
    [3]     RX datapath reset
    [5:4]   RX line rate (0 - 1.62 / 1 - 2.7 / 2 - 5.4 / 3 - 8.1 Gbps), for the CPLL calibration
    [10:6]  TX voltage swing (TXDIFFCTRL)
    [15:11] TX pre-emphasis (TXPOSTCURSOR)

    PHY controller PIO in:
    [0]     Power good (all channels)
    [1]     TX reset done
    [2]     RX reset done
    [6:3]   RX CDR lock (per lane)
    [7]     QPLL1 lock
    [8]     RX CDR stable (reset controller)
    [9]     RX user clock active
    [10]    TX user clock active
    [11]    Not used
    [15:12] CPLL lock (per GT channel)
    [19:16] RX PMA reset done (per GT channel)
*/

// PHY controller
    prt_phy_ctl_amd_apb
    #(
        .P_DRP_PORTS        (P_PHY_CTL_DRP_PORTS),
        .P_DRP_ADR          (10),
        .P_DRP_DAT          (16),
        .P_PIO_IN           (P_PHY_CTL_PIO_IN),
        .P_PIO_OUT          (P_PHY_CTL_PIO_OUT)
    )
    PHY_CTL_INST
    (
        // Reset and clock
        .SYS_RST_IN         (~sys_rstn_from_soc),
        .SYS_CLK_IN         (sys_clk_from_soc),

        // APB interface
        .APB_IF             (phy_apb_if),

        // DRP
        .DRP_CLK_IN         (drp_clk_from_soc),
        .DRP_ADR_OUT        (drp_adr_from_phy_ctl),
        .DRP_DAT_OUT        (drp_dat_from_phy_ctl),
        .DRP_EN_OUT         (drp_en_from_phy_ctl),
        .DRP_WR_OUT         (drp_wr_from_phy_ctl),
        .DRP_DAT_IN         (drp_dat_from_phy),
        .DRP_RDY_IN         (drp_rdy_from_phy),

        // PIO
        .PIO_DAT_IN         (pio_dat_to_phy_ctl),
        .PIO_DAT_OUT        (pio_dat_from_phy_ctl)
    );

    assign pio_dat_to_phy_ctl[0]            = &pwrgd_from_phy;
    assign pio_dat_to_phy_ctl[1]            = tx_rst_done_from_phy;
    assign pio_dat_to_phy_ctl[2]            = rx_rst_done_from_phy;
    assign pio_dat_to_phy_ctl[3+:4]         = rx_cdrlock_from_phy;
    assign pio_dat_to_phy_ctl[7]            = qpll_lock_from_phy;
    assign pio_dat_to_phy_ctl[8]            = rx_cdr_stable_from_phy;
    assign pio_dat_to_phy_ctl[9]            = rx_usrclk_act_from_phy;
    assign pio_dat_to_phy_ctl[10]           = tx_usrclk_act_from_phy;
    assign pio_dat_to_phy_ctl[11]           = 1'b0;
    assign pio_dat_to_phy_ctl[12+:4]        = cplllock_from_phy;
    assign pio_dat_to_phy_ctl[16+:4]        = rx_pmarstdone_from_phy;

    assign tx_pll_and_dp_rst_from_phy_ctl   = pio_dat_from_phy_ctl[0];
    assign tx_dp_rst_from_phy_ctl           = pio_dat_from_phy_ctl[1];
    assign rx_pll_and_dp_rst_from_phy_ctl   = pio_dat_from_phy_ctl[2];
    assign rx_dp_rst_from_phy_ctl           = pio_dat_from_phy_ctl[3];
    assign rx_linerate_from_phy_ctl         = pio_dat_from_phy_ctl[4+:2];
    assign tx_diffctrl_from_phy_ctl         = pio_dat_from_phy_ctl[6+:5];
    assign tx_postcursor_from_phy_ctl       = pio_dat_from_phy_ctl[11+:5];

// CPLL calibration (PG182)
// The receivers use the CPLL. The calibration block counts the CPLL clock divided by 20 during
// 16000 / 4 cycles of the free running clock (40 MHz): period = (VCO / 20) * 100, tolerance 1%.
    always_ff @ (posedge drp_clk_from_soc)
    begin
        rx_linerate_meta <= rx_linerate_from_phy_ctl;
        rx_linerate_sync <= rx_linerate_meta;

        case (rx_linerate_sync)
            // 2.7 and 5.4 Gbps (VCO 2.7 GHz)
            'd1, 'd2 :
            begin
                cpll_cal_period_to_phy <= 'd13500;
                cpll_cal_tol_to_phy <= 'd135;
            end

            // 8.1 Gbps (VCO 4.05 GHz)
            'd3 :
            begin
                cpll_cal_period_to_phy <= 'd20250;
                cpll_cal_tol_to_phy <= 'd202;
            end

            // 1.62 Gbps (VCO 3.24 GHz)
            default :
            begin
                cpll_cal_period_to_phy <= 'd16200;
                cpll_cal_tol_to_phy <= 'd162;
            end
        endcase
    end

// Transceiver
    dp_phy
    PHY_INST
    (
        // Serial
        .gthrxp_in                                  (GT_RX_IN_P),
        .gthrxn_in                                  (GT_RX_IN_N),
        .gthtxp_out                                 (GT_TX_OUT_P),
        .gthtxn_out                                 (GT_TX_OUT_N),

        // Free running clock
        // With the CPLL the free running clock is also the DRP clock (PG182).
        .gtwiz_reset_clk_freerun_in                 (drp_clk_from_soc),

        // Resets
        .gtpowergood_out                            (pwrgd_from_phy),
        .gtwiz_reset_all_in                         (~sys_rstn_from_soc),
        .gtwiz_reset_tx_pll_and_datapath_in         (tx_pll_and_dp_rst_from_phy_ctl),
        .gtwiz_reset_tx_datapath_in                 (tx_dp_rst_from_phy_ctl),
        .gtwiz_reset_rx_pll_and_datapath_in         (rx_pll_and_dp_rst_from_phy_ctl),
        .gtwiz_reset_rx_datapath_in                 (rx_dp_rst_from_phy_ctl),
        .gtwiz_reset_rx_cdr_stable_out              (rx_cdr_stable_from_phy),
        .gtwiz_reset_tx_done_out                    (tx_rst_done_from_phy),
        .gtwiz_reset_rx_done_out                    (rx_rst_done_from_phy),
        .rxpmaresetdone_out                         (rx_pmarstdone_from_phy),
        .cplllock_out                               (cplllock_from_phy),
        .txpmaresetdone_out                         (),

        // CPLL
        .gtrefclk0_in                               ({4{clk_from_gt_ibuf}}),
        .gtwiz_gthe4_cpll_cal_txoutclk_period_in    ({4{cpll_cal_period_to_phy}}),
        .gtwiz_gthe4_cpll_cal_cnt_tol_in            ({4{cpll_cal_tol_to_phy}}),
        .gtwiz_gthe4_cpll_cal_bufg_ce_in            (4'b1111),

        // QPLL1
        .gtrefclk01_in                              (clk_from_gt_ibuf),
        .qpll1outclk_out                            (),
        .qpll1outrefclk_out                         (),
        .qpll1lock_out                              (qpll_lock_from_phy),

        // User clocks
        .gtwiz_userclk_tx_reset_in                  (1'b0),
        .gtwiz_userclk_tx_srcclk_out                (),
        .gtwiz_userclk_tx_usrclk_out                (),
        .gtwiz_userclk_tx_usrclk2_out               (tx_clk_from_phy),
        .gtwiz_userclk_tx_active_out                (tx_usrclk_act_from_phy),
        .gtwiz_userclk_rx_reset_in                  (1'b0),
        .gtwiz_userclk_rx_srcclk_out                (),
        .gtwiz_userclk_rx_usrclk_out                (),
        .gtwiz_userclk_rx_usrclk2_out               (rx_clk_from_phy),
        .gtwiz_userclk_rx_active_out                (rx_usrclk_act_from_phy),

        // TX
        .txdiffctrl_in                              ({4{tx_diffctrl_from_phy_ctl}}),
        .txpostcursor_in                            ({4{tx_postcursor_from_phy_ctl}}),
        .txpolarity_in                              (4'b0000),
        .gtwiz_userdata_tx_in                       (tx_dat_to_phy),
        .txctrl0_in                                 (txctrl0_to_phy),
        .txctrl1_in                                 (txctrl1_to_phy),
        .txctrl2_in                                 (txctrl2_to_phy),
        .tx8b10ben_in                               (4'b1111),

        // RX
        .rxpolarity_in                              (4'b0000),
        .gtwiz_userdata_rx_out                      (rx_dat_from_phy),
        .rxctrl0_out                                (rxctrl0_from_phy),
        .rxctrl1_out                                (),
        .rxctrl2_out                                (),
        .rxctrl3_out                                (),
        .rx8b10ben_in                               (4'b1111),
        .rxcommadeten_in                            (4'b1111),
        .rxmcommaalignen_in                         (4'b1111),
        .rxpcommaalignen_in                         (4'b1111),
        .rxbyteisaligned_out                        (),
        .rxbyterealign_out                          (),
        .rxcommadet_out                             (),
        .rxcdrlock_out                              (rx_cdrlock_from_phy),

        // DRP channels
        .drpclk_in                                  ({4{drp_clk_from_soc}}),
        .drpaddr_in                                 (drp_adr_from_phy_ctl[0+:(4*10)]),
        .drpdi_in                                   (drp_dat_from_phy_ctl[0+:(4*16)]),
        .drpen_in                                   (drp_en_from_phy_ctl[3:0]),
        .drpwe_in                                   (drp_wr_from_phy_ctl[3:0]),
        .drpdo_out                                  (drp_dat_from_phy[0+:(4*16)]),
        .drprdy_out                                 (drp_rdy_from_phy[3:0]),

        // DRP common
        .drpclk_common_in                           (drp_clk_from_soc),
        .drpaddr_common_in                          ({6'h0, drp_adr_from_phy_ctl[(4*10)+:10]}),
        .drpdi_common_in                            (drp_dat_from_phy_ctl[(4*16)+:16]),
        .drpen_common_in                            (drp_en_from_phy_ctl[4]),
        .drpwe_common_in                            (drp_wr_from_phy_ctl[4]),
        .drpdo_common_out                           (drp_dat_from_phy[(4*16)+:16]),
        .drprdy_common_out                          (drp_rdy_from_phy[4])
    );

// TX data
// The DPTX link data has per symbol the data in bits [7:0], the K flag in bit 8, the disparity
// value in bit 9 and the disparity control in bit 10. A lane has four symbols, the first in bits [7:0].
    always_ff @ (posedge tx_clk_from_phy)
    begin
        for (int i = 0; i < P_LANES; i++)
        begin
            for (int j = 0; j < P_SPL; j++)
            begin
                tx_dat_to_phy[(i * 32) + (j * 8) +: 8]  <= lnk_dat_from_dptx[(((i * P_SPL) + j) * 11) +: 8];
                txctrl2_to_phy[(i * 8) + j]             <= lnk_dat_from_dptx[(((i * P_SPL) + j) * 11) + 8];     // K character
                txctrl0_to_phy[(i * 16) + j]            <= lnk_dat_from_dptx[(((i * P_SPL) + j) * 11) + 9];     // Disparity value
                txctrl1_to_phy[(i * 16) + j]            <= lnk_dat_from_dptx[(((i * P_SPL) + j) * 11) + 10];    // Disparity control
            end

            txctrl2_to_phy[(i * 8) + 4 +: 4]  <= '0;
            txctrl0_to_phy[(i * 16) + 4 +: 12] <= '0;
            txctrl1_to_phy[(i * 16) + 4 +: 12] <= '0;
        end
    end

// RX data
// The DPRX takes per symbol the data in bits [7:0] and the K flag in bit 8.
    always_ff @ (posedge rx_clk_from_phy)
    begin
        for (int i = 0; i < P_LANES; i++)
        begin
            for (int j = 0; j < P_SPL; j++)
            begin
                lnk_dat_to_dprx[(((i * P_SPL) + j) * 9) +: 8] <= rx_dat_from_phy[(i * 32) + (j * 8) +: 8];
                lnk_dat_to_dprx[(((i * P_SPL) + j) * 9) + 8]  <= rxctrl0_from_phy[(i * 16) + j];
            end
        end
    end

/*
    Heartbeats
*/
    prt_hb
    #(
        .P_BEAT ('d50_000_000)
    )
    SYS_HB_INST
    (
        .CLK_IN     (sys_clk_from_soc),
        .LED_OUT    (led_from_sys_hb)
    );

    prt_hb
    #(
        .P_BEAT ('d74_250_000)
    )
    VID_HB_INST
    (
        .CLK_IN     (vid_clk_from_bufg),
        .LED_OUT    (led_from_vid_hb)
    );

    prt_hb
    #(
        .P_BEAT ('d67_500_000)
    )
    GT_HB_INST
    (
        .CLK_IN     (gt_refclk_from_bufg),
        .LED_OUT    (led_from_gt_hb)
    );

// LED (active low)
// [0] System clock heartbeat (only when the fabric is out of reset)
// [1] Video clock heartbeat
// [2] GT reference clock heartbeat
// [3] QPLL1 lock (transmitters)
    assign LED_OUT[0] = ~(led_from_sys_hb & sys_rstn_from_soc);
    assign LED_OUT[1] = ~led_from_vid_hb;
    assign LED_OUT[2] = ~led_from_gt_hb;
    assign LED_OUT[3] = ~qpll_lock_from_phy;

endmodule

`default_nettype wire
