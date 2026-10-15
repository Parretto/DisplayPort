/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: DP reference design running on Lattice Avant G70 Versa board
    (c) 2026 by Parretto B.V.

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

// The nettype overwrite can't be used when using the Reveal analyzer
//`default_nettype none

// Module
module dp_ref_lsc_lav_g70_versa_evn
(
    // Clock
    input wire              SYS_RSTN_IN,                // Reset input
    input wire              SYS_CLK_IN,                 // 100 MHz

    // UART
    input wire              UART_RX_IN,
    output wire             UART_TX_OUT,

    // I2C
    inout wire              I2C_SCL_INOUT,
    inout wire              I2C_SDA_INOUT,

    // Tentiva
    input wire              TENTIVA_VID_CLK_IN,         // Video clock

    // PHY
    input wire              PHY_REFCLK_IN_P,            // PHY reference clock (135 MHz)
    input wire              PHY_REFCLK_IN_N,            // PHY reference clock

    // DP TX
    output wire [3:0]       DPTX_ML_OUT_P,              // Main link
    output wire [3:0]       DPTX_ML_OUT_N,              // Main link
    output wire             DPTX_AUX_EN_OUT,            // AUX Enable
    output wire             DPTX_AUX_TX_OUT,            // AUX Transmit
    input wire              DPTX_AUX_RX_IN,             // AUX Receive
    input wire              DPTX_HPD_IN,                // HPD
    output wire             DPTX_I2C_SEL_OUT,           // I2C select (DP21 TX)

    // DP RX
    input wire [3:0]        DPRX_ML_IN_P,               // Main link
    input wire [3:0]        DPRX_ML_IN_N,               // Main link
    output wire             DPRX_AUX_EN_OUT,            // AUX Enable
    output wire             DPRX_AUX_TX_OUT,            // AUX Transmit
    input wire              DPRX_AUX_RX_IN,             // AUX Receive
    output wire             DPRX_HPD_OUT,               // HPD
    output wire             DPRX_I2C_SEL_OUT,           // I2C select (DP21 RX)
    input wire              DPRX_CABDET_IN,             // Cable detect

    // Misc
    output wire [2:0]       LED_OUT
);


/*
    Parameters
*/
localparam P_VENDOR             = "LSC";
localparam P_FAMILY             = "LAV-AT";                 // Family (Only used for Lattice)
localparam P_SYS_FREQ           = 50_000_000;               // System frequency 50 MHz
localparam P_BEAT               = P_SYS_FREQ / 1_000_000;   // Beat value.
localparam P_REF_VER_MAJOR      = 1;                        // Reference design version major
localparam P_REF_VER_MINOR      = 0;                        // Reference design minor
localparam P_LANES              = 4;
localparam P_SPL                = 4;
localparam P_PPC                = 4;
localparam P_BPC                = 10;                       // Bits per component. Valid options - 8, 10
localparam P_AXI_WIDTH          = (P_BPC == 10) ? 120 : 96;

localparam P_SDP                = 1;                        // SDP support

localparam P_MST                = 0;                        // MST support
localparam P_VTB_OVL            = (P_MST) ? 1 : 0;          // VTB Overlay
localparam P_VTB_OSD            = 1;                        // VTB On screen display (scroller)

// PHY controller
localparam P_PHY_CTL_LMMI_PORTS = 1;
localparam P_PHY_CTL_LMMI_ADR   = 16;
localparam P_PHY_CTL_LMMI_DAT   = 16;
localparam P_PHY_CTL_PIO_IN     = 12;   // bit 0-3 : TX/RX PMA/PCS reset done, bit 4-7 : RX valid per lane, bit 8-11 : RX signal detect per lane
localparam P_PHY_CTL_PIO_OUT    = 6;    // bit 0-3 : TX/RX PMA/PCS reset,      bit 4   : TX valid, bit 5 : RX debug clear

//-----
// Interfaces
//-----

// DPTX
prt_apb_if
#(
  .P_ADR_WIDTH  (10)
)
dptx_apb_if();

// DPRX
prt_apb_if
#(
  .P_ADR_WIDTH  (10)
)
dprx_apb_if();

// VTB
prt_apb_if
#(
  .P_ADR_WIDTH  (10)
)
vtb_apb_if();

// PHY config
prt_apb_if
#(
  .P_ADR_WIDTH  (10)
)
phy_apb_if();


//-----
// Signals
//-----

// Reset
(* syn_preserve=1 *) logic [15:0]   sclk_rst_cnt;
(* syn_preserve=1 *) logic          sclk_rst;

// Clocks
wire                            clk_from_sys_buf;
wire                            clk_from_sys_pll;
wire                            lock_from_sys_pll;
wire                            clk_from_vid_buf;

// SOC
wire                            rst_to_soc;
wire [31:0]                     pio_dat_to_soc;
wire [31:0]                     pio_dat_from_soc;
wire                            dptx_rst_from_soc;
wire                            dprx_rst_from_soc;

// DPTX
wire                            irq_from_dptx;
wire  [(P_LANES*P_SPL*11)-1:0]  lnk_dat_from_dptx;
wire                            hb_from_dptx;

// DPRX
wire                            irq_from_dprx;
logic [(P_LANES*P_SPL*9)-1:0]   lnk_dat_to_dprx;
wire                            hb_from_dprx;
wire                            lnk_sync_from_dprx;

wire                            vid_sof_from_dprx;   // Start of frame
wire                            vid_eol_from_dprx;   // End of line
wire [P_AXI_WIDTH-1:0]          vid_dat_from_dprx;   // Data
wire                            vid_vld_from_dprx;   // Valid

wire                            sdp_sop_from_dprx;
wire                            sdp_eop_from_dprx;
wire [31:0]                     sdp_dat_from_dprx;
wire                            sdp_vld_from_dprx;

// VTB
wire                            lock_from_vtb;
wire                            vs_from_vtb;
wire                            hs_from_vtb;
wire [(3*P_PPC*P_BPC)-1:0]      dat_from_vtb;
wire                            de_from_vtb;

// PHY Controller
wire                            lmmi_req_from_phy_ctl;
wire                            lmmi_dir_from_phy_ctl;
wire [P_PHY_CTL_LMMI_ADR-1:0]   lmmi_adr_from_phy_ctl;
wire [P_PHY_CTL_LMMI_DAT-1:0]   lmmi_dat_from_phy_ctl;
wire [P_PHY_CTL_PIO_IN-1:0]     pio_dat_to_phy_ctl;
wire [P_PHY_CTL_PIO_OUT-1:0]    pio_dat_from_phy_ctl;
wire                            tx_pma_rst_n_from_phy_ctl;
wire                            tx_pcs_rst_n_from_phy_ctl;
wire                            rx_pma_rst_n_from_phy_ctl;
wire                            rx_pcs_rst_n_from_phy_ctl;
wire                            tx_vld_from_phy_ctl;

// PHY
wire                            tx_clk_from_phy;
wire                            rx_clk_from_phy;
logic [159:0]                   tx_dat_to_phy[4];
wire [159:0]                    rx_dat_from_phy[4];
wire [3:0]                      rx_vld_from_phy;
wire [3:0]                      rx_sigdet_from_phy;
wire [3:0]                      tx_pma_rst_done_from_phy;
wire [3:0]                      tx_pcs_rst_done_from_phy;
wire [3:0]                      rx_pma_rst_done_from_phy;
wire [3:0]                      rx_pcs_rst_done_from_phy;

wire [P_PHY_CTL_LMMI_DAT-1:0]   lmmi_dat_from_phy;
wire                            lmmi_vld_from_phy;
wire                            lmmi_rdy_from_phy;

// Heartbeat
wire                            led_from_sys_hb;

genvar i;



//-----
// Logic
//-----

//-----
// System clock input buffer
//-----
    IB
    SYS_CLK_BUF_INST
    (
        .I (SYS_CLK_IN),        // I
        .O (clk_from_sys_buf)   // O
    );


//-----
// Reset generator
//-----
    always_ff @ (negedge SYS_RSTN_IN, posedge clk_from_sys_buf)
    begin
        if (!SYS_RSTN_IN)
        begin
            sclk_rst_cnt <= '1;
            sclk_rst <= 1;
        end

        // Decrement
        else if (sclk_rst_cnt != 0)
            sclk_rst_cnt <= sclk_rst_cnt - 'd1;

        // Release
        else
            sclk_rst <= 0;
    end


//-----
// Global reset
// This is needed to insert manually.
// Else Radiant might select one of the internal DP reset signals.
// In combination with SynplifyPro the GSR input must be disabled.
//-----
    GSRA
    GSR_INST
    (
        .GSR_N (1'b1)
    );


//-----
// System PLL
// This PLL generates the 50 MHz clock for the application.
//-----
    sys_pll
    SYS_PLL_INST
    (
        .clki_i     (clk_from_sys_buf),
        .clkop_o    (clk_from_sys_pll),
        .lock_o     (lock_from_sys_pll)
    );


//-----
// Video clock input buffer
//-----
    IB
    VID_BUF_INST
    (
        .I (TENTIVA_VID_CLK_IN),    // I
        .O (clk_from_vid_buf)       // O
    );


//-----
// SOC
//-----

    // Reset
    assign rst_to_soc = sclk_rst;

    dp_soc_lav
    SOC_INST
    (
        .RST_IN                                     (rst_to_soc),
        .CLK_IN                                     (clk_from_sys_pll),

        // PIO
        .PIO_IN                                     (pio_dat_to_soc),
        .PIO_OUT                                    (pio_dat_from_soc),

        // UART
        .UART_RX_IN                                 (UART_RX_IN),
        .UART_TX_OUT                                (UART_TX_OUT),

        // I2C
        .I2C_SCL_INOUT                              (I2C_SCL_INOUT),
        .I2C_SDA_INOUT                              (I2C_SDA_INOUT),

        // DPTX
        .DPTX_IF_apb_paddr_mstr_o_portbus            (dptx_apb_if.paddr),
        .DPTX_IF_apb_prdata_mstr_i_portbus           (dptx_apb_if.prdata),
        .DPTX_IF_apb_pwdata_mstr_o_portbus           (dptx_apb_if.pwdata),
        .DPTX_IF_apb_penable_mstr_o_port             (dptx_apb_if.penable),
        .DPTX_IF_apb_pready_mstr_i_port              (dptx_apb_if.pready),
        .DPTX_IF_apb_psel_mstr_o_port                (dptx_apb_if.psel),
        .DPTX_IF_apb_pslverr_mstr_i_port             (1'b0),
        .DPTX_IF_apb_pwrite_mstr_o_port              (dptx_apb_if.pwrite),
        .DPTX_IRQ_IN_irq2_i_port                    (irq_from_dptx),

        // DPRX
        .DPRX_IF_apb_paddr_mstr_o_portbus            (dprx_apb_if.paddr),
        .DPRX_IF_apb_prdata_mstr_i_portbus           (dprx_apb_if.prdata),
        .DPRX_IF_apb_pwdata_mstr_o_portbus           (dprx_apb_if.pwdata),
        .DPRX_IF_apb_penable_mstr_o_port             (dprx_apb_if.penable),
        .DPRX_IF_apb_pready_mstr_i_port              (dprx_apb_if.pready),
        .DPRX_IF_apb_psel_mstr_o_port                (dprx_apb_if.psel),
        .DPRX_IF_apb_pslverr_mstr_i_port             (1'b0),
        .DPRX_IF_apb_pwrite_mstr_o_port              (dprx_apb_if.pwrite),
        .DPRX_IRQ_IN_irq3_i_port                    (irq_from_dprx),

        // VTB
        .VTB_IF_apb_paddr_mstr_o_portbus             (vtb_apb_if.paddr),
        .VTB_IF_apb_prdata_mstr_i_portbus            (vtb_apb_if.prdata),
        .VTB_IF_apb_pwdata_mstr_o_portbus            (vtb_apb_if.pwdata),
        .VTB_IF_apb_penable_mstr_o_port              (vtb_apb_if.penable),
        .VTB_IF_apb_pready_mstr_i_port               (vtb_apb_if.pready),
        .VTB_IF_apb_psel_mstr_o_port                 (vtb_apb_if.psel),
        .VTB_IF_apb_pslverr_mstr_i_port              (1'b0),
        .VTB_IF_apb_pwrite_mstr_o_port               (vtb_apb_if.pwrite),

        // PHY
        .PHY_IF_apb_paddr_mstr_o_portbus             (phy_apb_if.paddr),
        .PHY_IF_apb_prdata_mstr_i_portbus            (phy_apb_if.prdata),
        .PHY_IF_apb_pwdata_mstr_o_portbus            (phy_apb_if.pwdata),
        .PHY_IF_apb_penable_mstr_o_port              (phy_apb_if.penable),
        .PHY_IF_apb_pready_mstr_i_port               (phy_apb_if.pready),
        .PHY_IF_apb_psel_mstr_o_port                 (phy_apb_if.psel),
        .PHY_IF_apb_pslverr_mstr_i_port              (1'b0),
        .PHY_IF_apb_pwrite_mstr_o_port               (phy_apb_if.pwrite)
    );

    // PIO in mapping
    assign pio_dat_to_soc[0]    = (P_PPC == 4) ? 1 : 0;             // Pixels per clock
    assign pio_dat_to_soc[1]    = (P_BPC == 10) ? 1 : 0;            // Bits per component
    assign pio_dat_to_soc[31:2] = 0;                                // Not used

    // PIO out mapping
    assign dptx_rst_from_soc    = pio_dat_from_soc[0];
    assign dprx_rst_from_soc    = pio_dat_from_soc[1];


//-----
// DisplayPort TX
//-----
    prt_dptx_apb
    #(
        // System
        .P_VENDOR           (P_VENDOR),   // Vendor
        .P_FAMILY           (P_FAMILY),   // Family
        .P_BEAT             (P_BEAT),     // Beat value. The system clock is 50 MHz
        .P_MST              (P_MST),      // MST support
        .P_SDP              (P_SDP),      // SDP support

        // Link
        .P_LANES            (P_LANES),    // Lanes
        .P_SPL              (P_SPL),      // Symbols per lane

        // Video
        .P_PPC              (P_PPC),      // Pixels per clock
        .P_BPC              (P_BPC)       // Bits per component
    )
    DPTX_INST
    (
        // Reset and Clock
        .SYS_RST_IN         (dptx_rst_from_soc),
        .SYS_CLK_IN         (clk_from_sys_pll),

        // Host interface
        .APB_IF             (dptx_apb_if),
        .HOST_IRQ_OUT       (irq_from_dptx),

        // AUX
        .AUX_EN_OUT         (DPTX_AUX_EN_OUT),
        .AUX_TX_OUT         (DPTX_AUX_TX_OUT),
        .AUX_RX_IN          (DPTX_AUX_RX_IN),

        // Misc
        .HPD_IN             (~DPTX_HPD_IN),              // Hot plug polarity is inverted
        .HB_OUT             (hb_from_dptx),

        // Video stream 0
        .VID0_CLK_IN         (clk_from_vid_buf),
        .VID0_CKE_IN         (1'b1),
        .VID0_VS_IN          (vs_from_vtb),           // Vsync
        .VID0_HS_IN          (hs_from_vtb),           // Hsync
        .VID0_DAT_IN         (dat_from_vtb),            // Data
        .VID0_DE_IN          (de_from_vtb),           // Data enable

        // Secondary data packet
        .SDP_CLK_IN          (clk_from_sys_pll),         // Clock
        .SDP_RDY_OUT         (),                         // Ready
        .SDP_SOP_IN          (1'b0),                     // Start of packet
        .SDP_EOP_IN          (1'b0),                     // End of packet
        .SDP_DAT_IN          (32'd0),                    // Data
        .SDP_VLD_IN          (1'b0),                     // Valid

        // Video stream 1
        .VID1_CLK_IN         (clk_from_vid_buf),
        .VID1_CKE_IN         (1'b1),
        .VID1_VS_IN          (1'b0),                     // Vsync
        .VID1_HS_IN          (1'b0),                     // Hsync
        .VID1_DAT_IN         (0),                       // Data
        .VID1_DE_IN          (1'b0),                     // Data enable

        // Link
        .LNK_CLK_IN         (tx_clk_from_phy),
        .LNK_DAT_OUT        (lnk_dat_from_dptx)
    );


//-----
// DisplayPort RX
//-----
    prt_dprx_apb
    #(
        // System
        .P_VENDOR               (P_VENDOR),   // Vendor
        .P_FAMILY               (P_FAMILY),   // Family
        .P_BEAT                 (P_BEAT),     // Beat value.
        .P_SDP                  (P_SDP),      // SDP support

        // Link
        .P_LANES                (P_LANES),    // Lanes
        .P_SPL                  (P_SPL),      // Symbols per lane

        // Video
        .P_PPC                  (P_PPC),      // Pixels per clock
        .P_BPC                  (P_BPC),      // Bits per component
        .P_VID_DAT              (P_AXI_WIDTH)
    )
    DPRX_INST
    (
        // Reset and Clock
        .SYS_RST_IN             (dprx_rst_from_soc),
        .SYS_CLK_IN             (clk_from_sys_pll),

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
        .LNK_DAT_IN             (lnk_dat_to_dprx),      // Data
        .LNK_SYNC_OUT           (lnk_sync_from_dprx),   // Sync
        .LNK_VBID_OUT           (),
        .LNK_TRN_TPS_CR_OUT     (),                     // Link training TPS clock recovery sequence
        .LNK_TRN_TPS_EQ_OUT     (),                     // Link training TPS equalization sequence
        .LNK_TRN_TPS_PASS_OUT   (),                     // Link training TPS passed
        .LNK_TRN_TPS_FAIL_OUT   (),                     // Link training TPS failed

        // Video
        .VID_CLK_IN             (clk_from_vid_buf),     // Clock
        .VID_RDY_IN             (1'b1),                 // Ready
        .VID_SOF_OUT            (vid_sof_from_dprx),    // Start of frame
        .VID_EOL_OUT            (vid_eol_from_dprx),    // End of line
        .VID_DAT_OUT            (vid_dat_from_dprx),    // Data
        .VID_VLD_OUT            (vid_vld_from_dprx),    // Valid

        // Secondary Data Packet
        .SDP_CLK_IN             (clk_from_sys_pll),     // Clock
        .SDP_SOP_OUT            (sdp_sop_from_dprx),    // Start of packet
        .SDP_EOP_OUT            (sdp_eop_from_dprx),    // End of packet
        .SDP_DAT_OUT            (sdp_dat_from_dprx),    // Data
        .SDP_VLD_OUT            (sdp_vld_from_dprx),    // Valid
        .SDP_ERR_OUT            ()                      // Parity error (not used)
    );


//-----
// Video toolbox
//-----
    prt_vtb_apb
    #(
        .P_VENDOR               (P_VENDOR),
        .P_FAMILY               (P_FAMILY),
        .P_SYS_FREQ             (P_SYS_FREQ),   // System frequency
        .P_PPC                  (P_PPC),        // Pixels per clock
        .P_BPC                  (P_BPC),        // Bits per component
        .P_AXIS_DAT             (P_AXI_WIDTH),
        .P_OVL                  (P_VTB_OVL),    // Overlay (0 - disable / 1 - Image 1 / 2 - Image 2)
        .P_OSD                  (P_VTB_OSD)     // On screen display (0 - disable / 1 - enable)
    )
    VTB_INST
    (
        // System
        .SYS_RST_IN             (dptx_rst_from_soc),
        .SYS_CLK_IN             (clk_from_sys_pll),

        // APB Interface
        .APB_IF                 (vtb_apb_if),

        // Direct I2C Access
        .DIA_RDY_IN             (1'b1),
        .DIA_DAT_OUT            (),
        .DIA_VLD_OUT            (),

        // Link
        .TX_LNK_CLK_IN          (tx_clk_from_phy),      // TX link clock
        .RX_LNK_CLK_IN          (rx_clk_from_phy),      // RX link clock
        .LNK_SYNC_IN            (lnk_sync_from_dprx),

        // Axi-stream Video
        .AXIS_SOF_IN            (vid_sof_from_dprx),    // Start of frame
        .AXIS_EOL_IN            (vid_eol_from_dprx),    // End of line
        .AXIS_DAT_IN            (vid_dat_from_dprx),    // Data
        .AXIS_VLD_IN            (vid_vld_from_dprx),    // Valid

        // Native video
        .VID_CLK_IN             (clk_from_vid_buf),
        .VID_CKE_IN             (1'b1),
        .VID_LOCK_OUT           (lock_from_vtb),
        .VID_VS_OUT             (vs_from_vtb),
        .VID_HS_OUT             (hs_from_vtb),
        .VID_DAT_OUT            (dat_from_vtb),
        .VID_DE_OUT             (de_from_vtb)
    );


//-----
// PHY controller
//-----
    prt_phy_ctl_lsc_apb
    #(
        .P_LMMI_PORTS       (P_PHY_CTL_LMMI_PORTS),
        .P_LMMI_ADR         (P_PHY_CTL_LMMI_ADR),
        .P_LMMI_DAT         (P_PHY_CTL_LMMI_DAT),
        .P_PIO_IN           (P_PHY_CTL_PIO_IN),
        .P_PIO_OUT          (P_PHY_CTL_PIO_OUT)
    )
    PHY_CTL_INST
    (
        // Reset and clock
        .RST_IN             (sclk_rst),                 // Reset
        .CLK_IN             (clk_from_sys_pll),         // Clock

        // APB interface
        .APB_IF             (phy_apb_if),

        // LMMI
        .LMMI_REQ_OUT       (lmmi_req_from_phy_ctl),    // Request
        .LMMI_DIR_OUT       (lmmi_dir_from_phy_ctl),    // Direction
        .LMMI_ADR_OUT       (lmmi_adr_from_phy_ctl),    // Address
        .LMMI_DAT_OUT       (lmmi_dat_from_phy_ctl),    // Write data
        .LMMI_DAT_IN        (lmmi_dat_from_phy),        // Read data
        .LMMI_VLD_IN        (lmmi_vld_from_phy),        // Valid
        .LMMI_RDY_IN        (lmmi_rdy_from_phy),        // Ready

        // PIO
        .PIO_DAT_IN         (pio_dat_to_phy_ctl),
        .PIO_DAT_OUT        (pio_dat_from_phy_ctl)
    );

    // PIO in mapping
    assign pio_dat_to_phy_ctl[0]        = &tx_pma_rst_done_from_phy;
    assign pio_dat_to_phy_ctl[1]        = &tx_pcs_rst_done_from_phy;
    assign pio_dat_to_phy_ctl[2]        = &rx_pma_rst_done_from_phy;
    assign pio_dat_to_phy_ctl[3]        = &rx_pcs_rst_done_from_phy;
    assign pio_dat_to_phy_ctl[4+:4]     = rx_vld_from_phy;
    assign pio_dat_to_phy_ctl[8+:4]     = rx_sigdet_from_phy;

    // PIO out mapping
    assign tx_pma_rst_n_from_phy_ctl    = ~pio_dat_from_phy_ctl[0];
    assign tx_pcs_rst_n_from_phy_ctl    = ~pio_dat_from_phy_ctl[1];
    assign rx_pma_rst_n_from_phy_ctl    = ~pio_dat_from_phy_ctl[2];
    assign rx_pcs_rst_n_from_phy_ctl    = ~pio_dat_from_phy_ctl[3];
    assign tx_vld_from_phy_ctl          = pio_dat_from_phy_ctl[4];


//-----
// PHY
// The multi-protocol PHY in DP mode
//-----
    phy
    PHY_INST
    (
        // Reset / Config
        .soft_core_rst_n_q0_i               (4'b1111),          // PCIe soft core reset (not used)
        .core_reset_done_q0_o               (),
        .pin_perst_n_q0_i                   (4'b1111),          // PCIe reset signal (not used)
        .mppcs_rx_rst_n_q0_i                (4'b1111),
        .mppcs_rx_rst_req_q0_i              (4'b0000),
        .soft_phy_rst_n_q0_i                (~sclk_rst),

        .tx_pcie_pma_rst_n_q0_i             ({4{tx_pma_rst_n_from_phy_ctl}}),  // TX PMA reset - low active
        .tx_pcie_pma_reset_done_q0_o        (tx_pma_rst_done_from_phy),         // TX PMA reset done - high active
        .tx_pcs_rst_n_q0_i                  ({4{tx_pcs_rst_n_from_phy_ctl}}),  // TX PCS reset - low active
        .tx_pcs_reset_done_q0_o             (tx_pcs_rst_done_from_phy),         // TX PCS reset done - high active
        .phy_tx_ack_q0_o                    (),                                 // Transmitter acknowledge

        .rx_pma_rst_n_q0_i                  ({4{rx_pma_rst_n_from_phy_ctl}}),  // RX PMA reset - low active
        .rx_pma_reset_done_q0_o             (rx_pma_rst_done_from_phy),         // RX PMA reset done - high active
        .rx_pcs_rst_n_q0_i                  ({4{rx_pcs_rst_n_from_phy_ctl}}),  // RX PCS reset - low active
        .rx_pcs_reset_done_q0_o             (rx_pcs_rst_done_from_phy),         // RX PCS reset done - high active
        .rx_pma_ctrl_dr_ready_q0_o          (),
        .phy_rx_ack_q0_o                    (),                                 // Receiver acknowledge

        // LMMI
        .lmmireset_n_q0_i                   (~sclk_rst),
        .lmmiclk_q0_i                       (clk_from_sys_pll),
        .lmmioffset_q0_i                    (lmmi_adr_from_phy_ctl),
        .lmmirequest_q0_i                   (lmmi_req_from_phy_ctl),
        .lmmiwdata_q0_i                     (lmmi_dat_from_phy_ctl),
        .lmmiwrrd_n_q0_i                    (lmmi_dir_from_phy_ctl),
        .lmmierror_interrupt_q0_o           (),
        .lmmirdata_q0_o                     (lmmi_dat_from_phy),
        .lmmirdatavalid_q0_o                (lmmi_vld_from_phy),
        .lmmiready_q0_o                     (lmmi_rdy_from_phy),

        // MPPCS Mode
        .phy_sram_bypass_dyn_q0_o           (),
        .phy_sram_init_done_q0_o            (),
        .phy_sram_ext_ld_done_dyn_q0_i      (1'b0),
        .phy_mplla_state_q0_o               (),
        .phy_mpllb_state_q0_o               (),

        // Serial I/O
        .refclk_p_q0_i                      (PHY_REFCLK_IN_P),
        .refclk_n_q0_i                      (PHY_REFCLK_IN_N),

        .tx_l0_p_o                          (DPTX_ML_OUT_P[0]),
        .tx_l0_n_o                          (DPTX_ML_OUT_N[0]),
        .tx_l1_p_o                          (DPTX_ML_OUT_P[1]),
        .tx_l1_n_o                          (DPTX_ML_OUT_N[1]),
        .tx_l2_p_o                          (DPTX_ML_OUT_P[2]),
        .tx_l2_n_o                          (DPTX_ML_OUT_N[2]),
        .tx_l3_p_o                          (DPTX_ML_OUT_P[3]),
        .tx_l3_n_o                          (DPTX_ML_OUT_N[3]),

        .rx_l0_p_i                          (DPRX_ML_IN_P[0]),
        .rx_l0_n_i                          (DPRX_ML_IN_N[0]),
        .rx_l1_p_i                          (DPRX_ML_IN_P[1]),
        .rx_l1_n_i                          (DPRX_ML_IN_N[1]),
        .rx_l2_p_i                          (DPRX_ML_IN_P[2]),
        .rx_l2_n_i                          (DPRX_ML_IN_N[2]),
        .rx_l3_p_i                          (DPRX_ML_IN_P[3]),
        .rx_l3_n_i                          (DPRX_ML_IN_N[3]),

        // Clocking
        .tx_in_clk_q0_i                     ({4{tx_clk_from_phy}}),     // Transmitter input clock

        .txoutclk_l3_o                      (),
        .txoutclk_l2_o                      (),
        .txoutclk_l1_o                      (),
        .txoutclk_l0_o                      (),                         // Transmitter output clock from PMA

        .txoutgclk_pll1_q0_o                (),
        .txoutgclk_pll0_q0_o                (tx_clk_from_phy),          // TX link clock

        .rx_in_clk_q0_i                     ({4{rx_clk_from_phy}}),     // Receiver input clock

        .rxoutclk_l3_o                      (),
        .rxoutclk_l2_o                      (),
        .rxoutclk_l1_o                      (),
        .rxoutclk_l0_o                      (),                         // Receiver output clock from PMA

        .rxoutgclk_l3_o                     (),
        .rxoutgclk_l2_o                     (),
        .rxoutgclk_l1_o                     (),
        .rxoutgclk_l0_o                     (rx_clk_from_phy),          // RX link clock (recovered from lane 0)

        // TX
        .tx0_am_i                           (4'b0000),
        .tx1_am_i                           (4'b0000),
        .tx2_am_i                           (4'b0000),
        .tx3_am_i                           (4'b0000),
        .tx0_en_i                           (4'b0000),
        .tx1_en_i                           (4'b0000),
        .tx2_en_i                           (4'b0000),
        .tx3_en_i                           (4'b0000),
        .pma_tx0_data_i                     (tx_dat_to_phy[0]),
        .pma_tx0_valid_i                    (tx_vld_from_phy_ctl),
        .pma_tx1_data_i                     (tx_dat_to_phy[1]),
        .pma_tx1_valid_i                    (tx_vld_from_phy_ctl),
        .pma_tx2_data_i                     (tx_dat_to_phy[2]),
        .pma_tx2_valid_i                    (tx_vld_from_phy_ctl),
        .pma_tx3_data_i                     (tx_dat_to_phy[3]),
        .pma_tx3_valid_i                    (tx_vld_from_phy_ctl),

        .rx_data_en_q0_i                    (rx_sigdet_from_phy),         // the receiver data may only be enabled when the signal detect is high.
        .pm_rx0_walign_en_i                 (1'b1),
        .pm_rx0_deskew_en_i                 (1'b0),
        .pm_rx1_walign_en_i                 (1'b1),
        .pm_rx1_deskew_en_i                 (1'b0),
        .pm_rx2_walign_en_i                 (1'b1),
        .pm_rx2_deskew_en_i                 (1'b0),
        .pm_rx3_walign_en_i                 (1'b1),
        .pm_rx3_deskew_en_i                 (1'b0),
        .pma_rx0_data_o                     (rx_dat_from_phy[0]),
        .pma_rx0_ebuf_empty_o               (),
        .pma_rx0_ebuf_full_o                (),
        .pma_rx0_get_lalign_o               (),
        .pma_rx0_get_lsync_o                (),
        .pma_rx0_sigdet_hf_o                (),
        .pma_rx0_sigdet_lf_o                (rx_sigdet_from_phy[0]),     // Signal detect (low frequency)
        .pma_rx0_valid_o                    (rx_vld_from_phy[0]),

        .pma_rx1_data_o                     (rx_dat_from_phy[1]),
        .pma_rx1_ebuf_empty_o               (),
        .pma_rx1_ebuf_full_o                (),
        .pma_rx1_get_lalign_o               (),
        .pma_rx1_get_lsync_o                (),
        .pma_rx1_sigdet_hf_o                (),
        .pma_rx1_sigdet_lf_o                (rx_sigdet_from_phy[1]),     // Signal detect (low frequency)
        .pma_rx1_valid_o                    (rx_vld_from_phy[1]),

        .pma_rx2_data_o                     (rx_dat_from_phy[2]),
        .pma_rx2_ebuf_empty_o               (),
        .pma_rx2_ebuf_full_o                (),
        .pma_rx2_get_lalign_o               (),
        .pma_rx2_get_lsync_o                (),
        .pma_rx2_sigdet_hf_o                (),
        .pma_rx2_sigdet_lf_o                (rx_sigdet_from_phy[2]),     // Signal detect (low frequency)
        .pma_rx2_valid_o                    (rx_vld_from_phy[2]),

        .pma_rx3_data_o                     (rx_dat_from_phy[3]),
        .pma_rx3_ebuf_empty_o               (),
        .pma_rx3_ebuf_full_o                (),
        .pma_rx3_get_lalign_o               (),
        .pma_rx3_get_lsync_o                (),
        .pma_rx3_sigdet_hf_o                (),
        .pma_rx3_sigdet_lf_o                (rx_sigdet_from_phy[3]),     // Signal detect (low frequency)
        .pma_rx3_valid_o                    (rx_vld_from_phy[3]),

        .rx0_am_o                           (),
        .rx1_am_o                           (),
        .rx2_am_o                           (),
        .rx3_am_o                           (),
        .rx_cdr_valid_q0_o                  ()
    );


//-----
// TX mapping
//-----
    always_ff @ (posedge tx_clk_from_phy)
    begin
        for (int l = 0; l < P_LANES; l++)
        begin
            tx_dat_to_phy[l] <= 0;

            for (int s = 0; s < P_SPL; s++)
            begin
                tx_dat_to_phy[l][(s*20)+:9]  <= lnk_dat_from_dptx[(((l*P_SPL)+s)*11)+:9];   // K and data
                tx_dat_to_phy[l][(s*20)+10]  <= lnk_dat_from_dptx[(((l*P_SPL)+s)*11)+10];   // Force disparity
                tx_dat_to_phy[l][(s*20)+11]  <= lnk_dat_from_dptx[(((l*P_SPL)+s)*11)+9];    // Disparity value
            end
        end
    end


//-----
// RX mapping
//-----
    always_ff @ (posedge rx_clk_from_phy)
    begin
        for (int l = 0; l < P_LANES; l++)
        begin
            for (int s = 0; s < P_SPL; s++)
                lnk_dat_to_dprx[(((l*P_SPL)+s)*9)+:9] <= rx_dat_from_phy[l][(s*20)+:9];   // K and data
        end
    end


//-----
// System clock heartbeat
//-----
    prt_hb
    #(
        .P_BEAT ('d25_000_000)
    )
    SYS_HB_INST
    (
        .CLK_IN     (clk_from_sys_pll),
        .LED_OUT    (led_from_sys_hb)
    );


//-----
// Outputs
//-----

    // LED
    assign LED_OUT[0]   = led_from_sys_hb;
    assign LED_OUT[1]   = hb_from_dptx;
    assign LED_OUT[2]   = hb_from_dprx;

    assign DPTX_I2C_SEL_OUT = 1;    // Only for DP21 TX card. Select FMC I2C interface
    assign DPRX_I2C_SEL_OUT = 1;    // Only for DP21 RX card. Select FMC I2C interface

endmodule

`default_nettype wire
