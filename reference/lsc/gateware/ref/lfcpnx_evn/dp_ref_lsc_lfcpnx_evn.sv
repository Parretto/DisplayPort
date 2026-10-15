/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    DP reference design running on Lattice LFCPNX-EVN
    (c) 2021 - 2026 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Updated with new scaler
    v1.2 - Added MST feature
    v1.3 - Added 10-bits video 
    v1.4 - Added support for Tentiva DP21TX and DP21RX cards
    v1.5 - Added DPTX secondary packet interface
    v1.6 - Added CDR lock
    v1.7 - Updated PHY reset and MPCS clocking
    

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
module dp_ref_lsc_lfcpnx_evn
(
    // Clock
    input wire              SYS_RSTN_IN,              // Reset input
    input wire              SYS_CLK_IN,               // 125 MHz

    // UART
    input wire              UART_RX_IN,
    output wire             UART_TX_OUT,

    // I2C
    inout wire              I2C_SCL_INOUT,
    inout wire              I2C_SDA_INOUT,

    // Tentiva
    input wire              TENTIVA_VID_CLK_IN,         // Video clock 

    // Serdes
    input wire              SD_REFCLK0_IN_P,
    input wire              SD_REFCLK0_IN_N,
    input wire              SD_REFCLK1_IN_P,
    input wire         	    SD_REFCLK1_IN_N,
    input wire  [3:0]     	SD_REXT_IN,
    input wire  [3:0]      	SD_REFRET_IN,

    // DP TX
    output wire [3:0]       DPTX_ML_OUT_P,          // Main link
    output wire [3:0]       DPTX_ML_OUT_N,          // Main link
    output wire             DPTX_AUX_EN_OUT,        // AUX Enable
    output wire             DPTX_AUX_TX_OUT,        // AUX Transmit
    input wire              DPTX_AUX_RX_IN,         // AUX Receive
    input wire              DPTX_HPD_IN,            // HPD
    output wire             DPTX_I2C_SEL_OUT,       // I2C select (DP21 TX)

    // DP RX
    input wire [3:0]        DPRX_ML_IN_P,            // Main link
    input wire [3:0]        DPRX_ML_IN_N,            // Main link
    output wire             DPRX_AUX_EN_OUT,         // AUX Enable
    output wire             DPRX_AUX_TX_OUT,         // AUX Transmit
    input wire              DPRX_AUX_RX_IN,          // AUX Receive
    output wire             DPRX_HPD_OUT,            // HPD
    output wire             DPRX_I2C_SEL_OUT,        // I2C select (DP21 RX)
    input wire              DPRX_CABDET_IN,          // Cable detect

    // Misc
    output wire [7:0]       LED_OUT
);


/*
    Parameters
*/
localparam P_VENDOR             = "LSC";
localparam P_FAMILY             = "LFCPNX";  // Family (Only used for Lattice)
localparam P_SYS_FREQ           = 50_000_000;      // System frequency 50 MHz
localparam P_BEAT               = P_SYS_FREQ / 1_000_000;   // Beat value. 
localparam P_REF_VER_MAJOR      = 1;     // Reference design version major
localparam P_REF_VER_MINOR      = 0;     // Reference design minor
localparam P_LANES              = 4;
localparam P_SPL                = 4;
localparam P_PPC                = 4;
localparam P_BPC                = 10;    // Bits per component. Valid options - 8, 10
localparam P_AXI_WIDTH          = (P_BPC == 10) ? 120 : 96;

localparam P_SDP                = 1;                        // SDP support

localparam P_MST                = 0;                        // MST support
localparam P_VTB_OVL            = (P_MST) ? 1 : 0;          // VTB Overlay
localparam P_VTB_OSD            = 1;                        // VTB On screen display (scroller)

localparam P_PHY_CTL_LMMI_PORTS = 4;
localparam P_PHY_CTL_PIO_IN     = 5;
localparam P_PHY_CTL_PIO_OUT    = 3;

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
wire                            refclk0_from_diffclkio;
wire                            refclk1_from_diffclkio;
wire                            clk_from_tx_buf;
wire                            clk_from_rx_buf;
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
wire                            hpd_from_dprx;
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
wire [3:0]                      lmmi_req_from_phy_ctl;
wire [3:0]                      lmmi_dir_from_phy_ctl;
wire [(4*9)-1:0]                lmmi_adr_from_phy_ctl;
wire [(4*8)-1:0]                lmmi_dat_from_phy_ctl;
wire [P_PHY_CTL_PIO_IN-1:0]     pio_dat_to_phy_ctl;
wire [P_PHY_CTL_PIO_OUT-1:0]    pio_dat_from_phy_ctl;
wire                            pma_rst_from_phy_ctl;
wire                            tx_pcs_rst_from_phy_ctl;
wire                            rx_pcs_rst_from_phy_ctl;

// PHY
wire                            tx_clk_from_phy;
wire                            rx_clk_from_phy;
logic  [79:0]                   tx_dat_to_phy[4];
wire [79:0]                     rx_dat_from_phy[4];
wire [3:0]                      rdy_from_phy;
wire [3:0]                      rx_val_from_phy;
wire                            pma_rstn_to_phy;
wire [3:0]                      tx_pcs_rstn_to_phy;
wire [3:0]                      rx_pcs_rstn_to_phy;

wire [(4*8)-1:0]                lmmi_dat_from_phy;
wire [3:0]                      lmmi_vld_from_phy;
wire [3:0]                      lmmi_rdy_from_phy;

// Heartbeat
wire                            led_from_sys_hb;
wire                            led_from_sdtx_hb;
wire                            led_from_sdrx_hb;
wire                            led_from_vid_hb;

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
    GSR
    GSR_INST
    (
        .GSR_N (1'b1),  
        .CLK   (clk_from_sys_buf)  
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
// Serdes reference clock buffer
//-----
    DIFFCLKIO
    DIFFCLKIO_INST 
    (
        .CLKIN0_P   (SD_REFCLK0_IN_P),  
        .CLKIN0_N   (SD_REFCLK0_IN_N),  
        .CLKIN1_P   (SD_REFCLK1_IN_P),  
        .CLKIN1_N   (SD_REFCLK1_IN_N),       
        .CLKOUT0    (refclk0_from_diffclkio),
        .CLKOUT1    (refclk1_from_diffclkio) 
    );


//-----
// Video clock input buffer
//-----
    IB
    VID_BUF_INST
    (
        .I (TENTIVA_VID_CLK_IN),  // I
        .O (clk_from_vid_buf)   // O
    );


//-----
// SOC
//-----

    // Reset
    assign rst_to_soc = sclk_rst;

    dp_soc_lfcpnx
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
        .DPTX_IF_apb_paddr_mstr_o_portbus           (dptx_apb_if.paddr), 
        .DPTX_IF_apb_prdata_mstr_i_portbus          (dptx_apb_if.prdata), 
        .DPTX_IF_apb_pwdata_mstr_o_portbus          (dptx_apb_if.pwdata), 
        .DPTX_IF_apb_penable_mstr_o_port            (dptx_apb_if.penable), 
        .DPTX_IF_apb_pready_mstr_i_port             (dptx_apb_if.pready), 
        .DPTX_IF_apb_psel_mstr_o_port               (dptx_apb_if.psel), 
        .DPTX_IF_apb_pslverr_mstr_i_port            (1'b0), 
        .DPTX_IF_apb_pwrite_mstr_o_port             (dptx_apb_if.pwrite),
        .DPTX_IRQ_IN_irq2_i_port                    (irq_from_dptx),      

        // DPRX
        .DPRX_IF_apb_paddr_mstr_o_portbus           (dprx_apb_if.paddr), 
        .DPRX_IF_apb_prdata_mstr_i_portbus          (dprx_apb_if.prdata), 
        .DPRX_IF_apb_pwdata_mstr_o_portbus          (dprx_apb_if.pwdata), 
        .DPRX_IF_apb_penable_mstr_o_port            (dprx_apb_if.penable), 
        .DPRX_IF_apb_pready_mstr_i_port             (dprx_apb_if.pready), 
        .DPRX_IF_apb_psel_mstr_o_port               (dprx_apb_if.psel), 
        .DPRX_IF_apb_pslverr_mstr_i_port            (1'b0), 
        .DPRX_IF_apb_pwrite_mstr_o_port             (dprx_apb_if.pwrite),
        .DPRX_IRQ_IN_irq3_i_port                    (irq_from_dprx),      

        // VTB
        .VTB_IF_apb_paddr_mstr_o_portbus            (vtb_apb_if.paddr), 
        .VTB_IF_apb_prdata_mstr_i_portbus           (vtb_apb_if.prdata), 
        .VTB_IF_apb_pwdata_mstr_o_portbus           (vtb_apb_if.pwdata), 
        .VTB_IF_apb_penable_mstr_o_port             (vtb_apb_if.penable), 
        .VTB_IF_apb_pready_mstr_i_port              (vtb_apb_if.pready), 
        .VTB_IF_apb_psel_mstr_o_port                (vtb_apb_if.psel), 
        .VTB_IF_apb_pslverr_mstr_i_port             (1'b0), 
        .VTB_IF_apb_pwrite_mstr_o_port              (vtb_apb_if.pwrite),

        // PHY
        .PHY_IF_apb_paddr_mstr_o_portbus            (phy_apb_if.paddr), 
        .PHY_IF_apb_prdata_mstr_i_portbus           (phy_apb_if.prdata), 
        .PHY_IF_apb_pwdata_mstr_o_portbus           (phy_apb_if.pwdata), 
        .PHY_IF_apb_penable_mstr_o_port             (phy_apb_if.penable), 
        .PHY_IF_apb_pready_mstr_i_port              (phy_apb_if.pready), 
        .PHY_IF_apb_psel_mstr_o_port                (phy_apb_if.psel), 
        .PHY_IF_apb_pslverr_mstr_i_port             (1'b0), 
        .PHY_IF_apb_pwrite_mstr_o_port              (phy_apb_if.pwrite)
    );

    // PIO in mapping
    assign pio_dat_to_soc[0]    = (P_PPC == 4) ? 1 : 0;             // Pixels per clock
    assign pio_dat_to_soc[1]    = (P_BPC == 10) ? 1 : 0;            // Bits per component

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
        .LNK_CLK_IN         (clk_from_tx_buf),
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
        .LNK_CLK_IN             (clk_from_rx_buf),      // Clock
        .LNK_LOCK_IN            (1'b1), //rx_val_from_phy[0]),   // Lock
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
        .TX_LNK_CLK_IN          (clk_from_tx_buf),     // TX link clock
        .RX_LNK_CLK_IN          (clk_from_rx_buf),     // RX link clock
        .LNK_SYNC_IN            (lnk_sync_from_dprx),

        // Axi-stream Video
        .AXIS_SOF_IN            (vid_sof_from_dprx),      // Start of frame
        .AXIS_EOL_IN            (vid_eol_from_dprx),      // End of line
        .AXIS_DAT_IN            (vid_dat_from_dprx),      // Data
        .AXIS_VLD_IN            (vid_vld_from_dprx),      // Valid       

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
        .P_LMMI_ADR         (9),
        .P_LMMI_DAT         (8),
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
    assign pio_dat_to_phy_ctl[0]        = &rdy_from_phy;
    assign pio_dat_to_phy_ctl[1+:4]     = rx_val_from_phy;

    // PIO out mapping
    assign pma_rst_from_phy_ctl         = pio_dat_from_phy_ctl[0];
    assign tx_pcs_rst_from_phy_ctl      = pio_dat_from_phy_ctl[1];
    assign rx_pcs_rst_from_phy_ctl      = pio_dat_from_phy_ctl[2];


//-----
// PHY TX clock buffer
//-----
    BUF
    BUF_TX_INST
    (
        .A (tx_clk_from_phy),   // I
        .Z (clk_from_tx_buf)    // O
    );


//-----
// PHY RX clock buffer
//-----
    BUF
    BUF_RX_INST
    (
        .A (rx_clk_from_phy),   // I
        .Z (clk_from_rx_buf)    // O
    );


//-----
// PHY
//-----
    phy
    PHY_INST
    (
        // PMA serial
        .sdq_refclkp_q0_i           (1'b0), 
        .sdq_refclkn_q0_i           (1'b0), 
        .sdq_refclkp_q1_i           (1'b0), 
        .sdq_refclkn_q1_i           (1'b0), 
        .sd0rxp_i                   (DPRX_ML_IN_P[0]), 
        .sd0rxn_i                   (DPRX_ML_IN_N[0]), 
        .sd0txp_o                   (DPTX_ML_OUT_P[0]), 
        .sd0txn_o                   (DPTX_ML_OUT_N[0]), 
        .sd0_rext_i                 (SD_REXT_IN[0]), 
        .sd0_refret_i               (SD_REFRET_IN[0]), 
        .sd1rxp_i                   (DPRX_ML_IN_P[1]), 
        .sd1rxn_i                   (DPRX_ML_IN_N[1]), 
        .sd1txp_o                   (DPTX_ML_OUT_P[1]), 
        .sd1txn_o                   (DPTX_ML_OUT_N[1]), 
        .sd1_rext_i                 (SD_REXT_IN[1]), 
        .sd1_refret_i               (SD_REFRET_IN[1]), 
        .sd2rxp_i                   (DPRX_ML_IN_P[2]), 
        .sd2rxn_i                   (DPRX_ML_IN_N[2]), 
        .sd2txp_o                   (DPTX_ML_OUT_P[2]), 
        .sd2txn_o                   (DPTX_ML_OUT_N[2]), 
        .sd2_rext_i                 (SD_REXT_IN[2]), 
        .sd2_refret_i               (SD_REFRET_IN[2]), 
        .sd3rxp_i                   (DPRX_ML_IN_P[3]), 
        .sd3rxn_i                   (DPRX_ML_IN_N[3]), 
        .sd3txp_o                   (DPTX_ML_OUT_P[3]), 
        .sd3txn_o                   (DPTX_ML_OUT_N[3]), 
        .sd3_rext_i                 (SD_REXT_IN[3]), 
        .sd3_refret_i               (SD_REFRET_IN[3]), 

        // Reference clock
        .use_refmux_i               (1'b1),     // 0 - clock from quad source / 1 - clock from PCSREFMUX 
        .diffioclksel_i             (1'b0),     // Differential clock select; 0 - sd_ext_0_refclk / 1 - sd_ext_1_refclk 
        .clksel_i                   (2'b10),    // Clock source; 00 - pll_0_refclk / 01 - pll_1_refclk / 10 - sd_ext_refclk / 11 - sd_pll_refclk
        .sd_ext_0_refclk_i          (refclk0_from_diffclkio),
        .sd_ext_1_refclk_i          (refclk1_from_diffclkio), 
        .pll_0_refclk_i             (1'b0), 
        .pll_1_refclk_i             (1'b0), 
        .sd_pll_refclk_i            (1'b0), 
        
        // JTAG interface 
        .acjtag_mode_i              (1'b0), 
        .acjtag_enable_i_3          (1'b0), 
        .acjtag_enable_i_2          (1'b0), 
        .acjtag_enable_i_1          (1'b0), 
        .acjtag_enable_i_0          (1'b0), 
        .acjtag_acmode_i_3          (1'b0), 
        .acjtag_acmode_i_2          (1'b0), 
        .acjtag_acmode_i_1          (1'b0), 
        .acjtag_acmode_i_0          (1'b0), 
        .acjtag_drive1_i_3          (1'b0), 
        .acjtag_drive1_i_2          (1'b0), 
        .acjtag_drive1_i_1          (1'b0), 
        .acjtag_drive1_i_0          (1'b0), 
        .acjtag_highz_i_3           (1'b0), 
        .acjtag_highz_i_2           (1'b0), 
        .acjtag_highz_i_1           (1'b0), 
        .acjtag_highz_i_0           (1'b0), 
        .acjtagpout_o_3             (), 
        .acjtagpout_o_2             (), 
        .acjtagpout_o_1             (), 
        .acjtagpout_o_0             (), 
        .acjtagnout_o_3             (), 
        .acjtagnout_o_2             (), 
        .acjtagnout_o_1             (), 
        .acjtagnout_o_0             (), 

        // LMMI interface
        .lmmi_clk_i_0               (clk_from_sys_pll), 
        .lmmi_resetn_i_0            (~sclk_rst), 
        .lmmi_request_i_0           (lmmi_req_from_phy_ctl[0]), 
        .lmmi_wr_rdn_i_0            (lmmi_dir_from_phy_ctl[0]), 
        .lmmi_offset_i_0            (lmmi_adr_from_phy_ctl[(0*9)+:9]), 
        .lmmi_wdata_i_0             (lmmi_dat_from_phy_ctl[(0*8)+:8]), 
        .lmmi_rdata_valid_o_0       (lmmi_vld_from_phy[0]), 
        .lmmi_ready_o_0             (lmmi_rdy_from_phy[0]), 
        .lmmi_rdata_o_0             (lmmi_dat_from_phy[(0*8)+:8]), 

        .lmmi_clk_i_1               (clk_from_sys_pll), 
        .lmmi_resetn_i_1            (~sclk_rst), 
        .lmmi_request_i_1           (lmmi_req_from_phy_ctl[1]), 
        .lmmi_wr_rdn_i_1            (lmmi_dir_from_phy_ctl[1]), 
        .lmmi_offset_i_1            (lmmi_adr_from_phy_ctl[(1*9)+:9]), 
        .lmmi_wdata_i_1             (lmmi_dat_from_phy_ctl[(1*8)+:8]), 
        .lmmi_rdata_valid_o_1       (lmmi_vld_from_phy[1]), 
        .lmmi_ready_o_1             (lmmi_rdy_from_phy[1]), 
        .lmmi_rdata_o_1             (lmmi_dat_from_phy[(1*8)+:8]), 

        .lmmi_clk_i_2               (clk_from_sys_pll), 
        .lmmi_resetn_i_2            (~sclk_rst), 
        .lmmi_request_i_2           (lmmi_req_from_phy_ctl[2]), 
        .lmmi_wr_rdn_i_2            (lmmi_dir_from_phy_ctl[2]), 
        .lmmi_offset_i_2            (lmmi_adr_from_phy_ctl[(2*9)+:9]), 
        .lmmi_wdata_i_2             (lmmi_dat_from_phy_ctl[(2*8)+:8]), 
        .lmmi_rdata_valid_o_2       (lmmi_vld_from_phy[2]), 
        .lmmi_ready_o_2             (lmmi_rdy_from_phy[2]), 
        .lmmi_rdata_o_2             (lmmi_dat_from_phy[(2*8)+:8]), 

        .lmmi_clk_i_3               (clk_from_sys_pll), 
        .lmmi_resetn_i_3            (~sclk_rst), 
        .lmmi_request_i_3           (lmmi_req_from_phy_ctl[3]), 
        .lmmi_wr_rdn_i_3            (lmmi_dir_from_phy_ctl[3]), 
        .lmmi_offset_i_3            (lmmi_adr_from_phy_ctl[(3*9)+:9]), 
        .lmmi_wdata_i_3             (lmmi_dat_from_phy_ctl[(3*8)+:8]), 
        .lmmi_rdata_valid_o_3       (lmmi_vld_from_phy[3]), 
        .lmmi_ready_o_3             (lmmi_rdy_from_phy[3]), 
        .lmmi_rdata_o_3             (lmmi_dat_from_phy[(3*8)+:8]), 

        // Reset 
        .mpcs_perstn_i_3            (pma_rstn_to_phy), 
        .mpcs_perstn_i_2            (pma_rstn_to_phy), 
        .mpcs_perstn_i_1            (pma_rstn_to_phy), 
        .mpcs_perstn_i_0            (pma_rstn_to_phy), 
        .mpcs_tx_pcs_rstn_i_3       (tx_pcs_rstn_to_phy[3]), 
        .mpcs_tx_pcs_rstn_i_2       (tx_pcs_rstn_to_phy[2]), 
        .mpcs_tx_pcs_rstn_i_1       (tx_pcs_rstn_to_phy[1]), 
        .mpcs_tx_pcs_rstn_i_0       (tx_pcs_rstn_to_phy[0]), 
        .mpcs_rx_pcs_rstn_i_3       (rx_pcs_rstn_to_phy[3]), 
        .mpcs_rx_pcs_rstn_i_2       (rx_pcs_rstn_to_phy[2]), 
        .mpcs_rx_pcs_rstn_i_1       (rx_pcs_rstn_to_phy[1]), 
        .mpcs_rx_pcs_rstn_i_0       (rx_pcs_rstn_to_phy[0]), 

        // MPCS Clocks
        .mpcs_clkin_i_3             (clk_from_sys_buf),     // 125 MHz clock
        .mpcs_clkin_i_2             (clk_from_sys_buf),     // 125 MHz clock
        .mpcs_clkin_i_1             (clk_from_sys_buf),     // 125 MHz clock
        .mpcs_clkin_i_0             (clk_from_sys_buf),     // 125 MHz clock
        .mpcs_rx_usr_clk_i_3        (clk_from_rx_buf), 
        .mpcs_rx_usr_clk_i_2        (clk_from_rx_buf), 
        .mpcs_rx_usr_clk_i_1        (clk_from_rx_buf), 
        .mpcs_rx_usr_clk_i_0        (clk_from_rx_buf), 
        .mpcs_tx_usr_clk_i_3        (clk_from_tx_buf), 
        .mpcs_tx_usr_clk_i_2        (clk_from_tx_buf), 
        .mpcs_tx_usr_clk_i_1        (clk_from_tx_buf), 
        .mpcs_tx_usr_clk_i_0        (clk_from_tx_buf), 
        .mpcs_rx_out_clk_o_3        (), 
        .mpcs_rx_out_clk_o_2        (), 
        .mpcs_rx_out_clk_o_1        (), 
        .mpcs_rx_out_clk_o_0        (rx_clk_from_phy), // Tentiva DP21RX - This is the master clock
        .mpcs_tx_out_clk_o_3        (), 
        .mpcs_tx_out_clk_o_2        (), 
        .mpcs_tx_out_clk_o_1        (), 
        .mpcs_tx_out_clk_o_0        (tx_clk_from_phy), 

        // PMA control and status
        .mpcs_pwrdn_i_3             (2'b00),    // Normal operation 
        .mpcs_pwrdn_i_2             (2'b00),    // Normal operation 
        .mpcs_pwrdn_i_1             (2'b00),    // Normal operation 
        .mpcs_pwrdn_i_0             (2'b00),    // Normal operation 
        .mpcs_txhiz_i_3             (1'b0), 
        .mpcs_txhiz_i_2             (1'b0), 
        .mpcs_txhiz_i_1             (1'b0), 
        .mpcs_txhiz_i_0             (1'b0), 
        .mpcs_rxidle_o_3            (), 
        .mpcs_rxidle_o_2            (), 
        .mpcs_rxidle_o_1            (), 
        .mpcs_rxidle_o_0            (), 
        .mpcs_fomreq_i_3            (1'b0), 
        .mpcs_fomreq_i_2            (1'b0), 
        .mpcs_fomreq_i_1            (1'b0), 
        .mpcs_fomreq_i_0            (1'b0), 
        .mpcs_fomack_o_3            (), 
        .mpcs_fomack_o_2            (), 
        .mpcs_fomack_o_1            (), 
        .mpcs_fomack_o_0            (), 
        .mpcs_fomrslt_o_3           (), 
        .mpcs_fomrslt_o_2           (), 
        .mpcs_fomrslt_o_1           (), 
        .mpcs_fomrslt_o_0           (), 
        .mpcs_rxerr_i_3             (1'b0), 
        .mpcs_rxerr_i_2             (1'b0), 
        .mpcs_rxerr_i_1             (1'b0), 
        .mpcs_rxerr_i_0             (1'b0), 
        .mpcs_txval_i_3             (&rdy_from_phy), 
        .mpcs_txval_i_2             (&rdy_from_phy), 
        .mpcs_txval_i_1             (&rdy_from_phy), 
        .mpcs_txval_i_0             (&rdy_from_phy), 
        .mpcs_rxval_o_3             (rx_val_from_phy[3]), 
        .mpcs_rxval_o_2             (rx_val_from_phy[2]), 
        .mpcs_rxval_o_1             (rx_val_from_phy[1]), 
        .mpcs_rxval_o_0             (rx_val_from_phy[0]),
        .mpcs_phyrdy_o_3            (), 
        .mpcs_phyrdy_o_2            (), 
        .mpcs_phyrdy_o_1            (), 
        .mpcs_phyrdy_o_0            (), 
        .mpcs_ready_o_3             (rdy_from_phy[3]), 
        .mpcs_ready_o_2             (rdy_from_phy[2]), 
        .mpcs_ready_o_1             (rdy_from_phy[1]), 
        .mpcs_ready_o_0             (rdy_from_phy[0]), 
        .mpcs_rxoob_i_3             (1'b0), 
        .mpcs_rxoob_i_2             (1'b0), 
        .mpcs_rxoob_i_1             (1'b0), 
        .mpcs_rxoob_i_0             (1'b0), 
        .mpcs_txdeemp_i_3           (1'b0), 
        .mpcs_txdeemp_i_2           (1'b0), 
        .mpcs_txdeemp_i_1           (1'b0), 
        .mpcs_txdeemp_i_0           (1'b0), 
        .mpcs_pwrst_o_3             (), 
        .mpcs_pwrst_o_2             (), 
        .mpcs_pwrst_o_1             (), 
        .mpcs_pwrst_o_0             (), 
        .mpcs_skipbit_i_3           (1'b0), 
        .mpcs_skipbit_i_2           (1'b0), 
        .mpcs_skipbit_i_1           (1'b0), 
        .mpcs_skipbit_i_0           (1'b0), 
        
        // TX
        .mpcs_tx_ch_din_i_3         (tx_dat_to_phy[3]), 
        .mpcs_tx_ch_din_i_2         (tx_dat_to_phy[2]), 
        .mpcs_tx_ch_din_i_1         (tx_dat_to_phy[1]), 
        .mpcs_tx_ch_din_i_0         (tx_dat_to_phy[0]), 
        .mpcs_tx_fifo_st_o_3        (), 
        .mpcs_tx_fifo_st_o_2        (), 
        .mpcs_tx_fifo_st_o_1        (), 
        .mpcs_tx_fifo_st_o_0        (), 
        
        // RX
        .mpcs_rx_ch_dout_o_3        (rx_dat_from_phy[3]), 
        .mpcs_rx_ch_dout_o_2        (rx_dat_from_phy[2]), 
        .mpcs_rx_ch_dout_o_1        (rx_dat_from_phy[1]), 
        .mpcs_rx_ch_dout_o_0        (rx_dat_from_phy[0]), 
        .mpcs_rx_fifo_st_o_3        (), 
        .mpcs_rx_fifo_st_o_2        (), 
        .mpcs_rx_fifo_st_o_1        (), 
        .mpcs_rx_fifo_st_o_0        (), 
        
        // Elastic buffer
        .mpcs_ebuf_empty_o_3        (), 
        .mpcs_ebuf_empty_o_2        (), 
        .mpcs_ebuf_empty_o_1        (), 
        .mpcs_ebuf_empty_o_0        (), 
        .mpcs_ebuf_full_o_3         (), 
        .mpcs_ebuf_full_o_2         (), 
        .mpcs_ebuf_full_o_1         (), 
        .mpcs_ebuf_full_o_0         (), 
        
        // Word aligner
        .mpcs_walign_en_i_3         (1'b0), 
        .mpcs_walign_en_i_2         (1'b0), 
        .mpcs_walign_en_i_1         (1'b0), 
        .mpcs_walign_en_i_0         (1'b0), 
        .mpcs_get_lsync_o_3         (), 
        .mpcs_get_lsync_o_2         (), 
        .mpcs_get_lsync_o_1         (), 
        .mpcs_get_lsync_o_0         (), 
        
        // Lane-to-lane deskew
        .mpcs_rx_get_lalign_o_3     (), 
        .mpcs_rx_get_lalign_o_2     (), 
        .mpcs_rx_get_lalign_o_1     (), 
        .mpcs_rx_get_lalign_o_0     (), 
        .mpcs_rx_deskew_en_i_3      (1'b0), 
        .mpcs_rx_deskew_en_i_2      (1'b0), 
        .mpcs_rx_deskew_en_i_1      (1'b0), 
        .mpcs_rx_deskew_en_i_0      (1'b0) 
    );

// PHY reset
    assign pma_rstn_to_phy = (sclk_rst) ? 0 : ~pma_rst_from_phy_ctl;
generate
    for (i = 0; i < 4; i++)
    begin : gen_pcs_rstn
        assign rx_pcs_rstn_to_phy[i] = (rx_pcs_rst_from_phy_ctl) ? 0 : 1; //rx_val_from_phy[i];
        assign tx_pcs_rstn_to_phy[i] = ~tx_pcs_rst_from_phy_ctl;
    end
endgenerate


//-----
// TX mapping
//-----
    always_ff @ (posedge clk_from_tx_buf)
    begin
    // DP lane 0 
        tx_dat_to_phy[0][0+:9]  <= {lnk_dat_from_dptx[(0*11)+8], lnk_dat_from_dptx[(0*11)+:8]};            // TX symbol 0
        tx_dat_to_phy[0][10+:9] <= {lnk_dat_from_dptx[(1*11)+8], lnk_dat_from_dptx[(1*11)+:8]};            // TX symbol 1
        tx_dat_to_phy[0][20+:9] <= {lnk_dat_from_dptx[(2*11)+8], lnk_dat_from_dptx[(2*11)+:8]};            // TX symbol 2
        tx_dat_to_phy[0][30+:9] <= {lnk_dat_from_dptx[(3*11)+8], lnk_dat_from_dptx[(3*11)+:8]};            // TX symbol 3
        tx_dat_to_phy[0][47:44] <= {lnk_dat_from_dptx[(3*11)+9], lnk_dat_from_dptx[(2*11)+9], lnk_dat_from_dptx[(1*11)+9], lnk_dat_from_dptx[(0*11)+9]};       // Disparity value (0-negative / 1-positive)
        tx_dat_to_phy[0][43:40] <= {lnk_dat_from_dptx[(3*11)+10], lnk_dat_from_dptx[(2*11)+10], lnk_dat_from_dptx[(1*11)+10], lnk_dat_from_dptx[(0*11)+10]};     // Disparity control (0-automatic / 1-force)
        tx_dat_to_phy[0][79:48] <= 0;

    // DP lane 1 
        tx_dat_to_phy[1][0+:9]  <= {lnk_dat_from_dptx[(4*11)+8], lnk_dat_from_dptx[(4*11)+:8]};            // TX symbol 0
        tx_dat_to_phy[1][10+:9] <= {lnk_dat_from_dptx[(5*11)+8], lnk_dat_from_dptx[(5*11)+:8]};            // TX symbol 1
        tx_dat_to_phy[1][20+:9] <= {lnk_dat_from_dptx[(6*11)+8], lnk_dat_from_dptx[(6*11)+:8]};            // TX symbol 0
        tx_dat_to_phy[1][30+:9] <= {lnk_dat_from_dptx[(7*11)+8], lnk_dat_from_dptx[(7*11)+:8]};            // TX symbol 1
        tx_dat_to_phy[1][47:44] <= {lnk_dat_from_dptx[(7*11)+9], lnk_dat_from_dptx[(6*11)+9], lnk_dat_from_dptx[(5*11)+9], lnk_dat_from_dptx[(4*11)+9]};       // Disparity value (0-negative / 1-positive)
        tx_dat_to_phy[1][43:40] <= {lnk_dat_from_dptx[(7*11)+10], lnk_dat_from_dptx[(6*11)+10], lnk_dat_from_dptx[(5*11)+10], lnk_dat_from_dptx[(4*11)+10]};     // Disparity control (0-automatic / 1-force)
        tx_dat_to_phy[1][79:48] <= 0;

    // DP lane 2 
        tx_dat_to_phy[2][0+:9]  <= {lnk_dat_from_dptx[(8*11)+8], lnk_dat_from_dptx[(8*11)+:8]};            // TX symbol 0
        tx_dat_to_phy[2][10+:9] <= {lnk_dat_from_dptx[(9*11)+8], lnk_dat_from_dptx[(9*11)+:8]};            // TX symbol 1
        tx_dat_to_phy[2][20+:9] <= {lnk_dat_from_dptx[(10*11)+8], lnk_dat_from_dptx[(10*11)+:8]};          // TX symbol 2
        tx_dat_to_phy[2][30+:9] <= {lnk_dat_from_dptx[(11*11)+8], lnk_dat_from_dptx[(11*11)+:8]};          // TX symbol 3
        tx_dat_to_phy[2][47:44] <= {lnk_dat_from_dptx[(11*11)+9], lnk_dat_from_dptx[(10*11)+9], lnk_dat_from_dptx[(9*11)+9], lnk_dat_from_dptx[(8*11)+9]};       // Disparity value (0-negative / 1-positive)
        tx_dat_to_phy[2][43:40] <= {lnk_dat_from_dptx[(11*11)+10], lnk_dat_from_dptx[(10*11)+10], lnk_dat_from_dptx[(9*11)+10], lnk_dat_from_dptx[(8*11)+10]};     // Disparity control (0-automatic / 1-force)
        tx_dat_to_phy[2][79:48] <= 0;

    // DP lane 3 
        tx_dat_to_phy[3][0+:9]  <= {lnk_dat_from_dptx[(12*11)+8], lnk_dat_from_dptx[(12*11)+:8]};          // TX symbol 0
        tx_dat_to_phy[3][10+:9] <= {lnk_dat_from_dptx[(13*11)+8], lnk_dat_from_dptx[(13*11)+:8]};          // TX symbol 1
        tx_dat_to_phy[3][20+:9] <= {lnk_dat_from_dptx[(14*11)+8], lnk_dat_from_dptx[(14*11)+:8]};          // TX symbol 2
        tx_dat_to_phy[3][30+:9] <= {lnk_dat_from_dptx[(15*11)+8], lnk_dat_from_dptx[(15*11)+:8]};          // TX symbol 3
        tx_dat_to_phy[3][47:44] <= {lnk_dat_from_dptx[(15*11)+9], lnk_dat_from_dptx[(14*11)+9], lnk_dat_from_dptx[(13*11)+9], lnk_dat_from_dptx[(12*11)+9]};       // Disparity value (0-negative / 1-positive)
        tx_dat_to_phy[3][43:40] <= {lnk_dat_from_dptx[(15*11)+10], lnk_dat_from_dptx[(14*11)+10], lnk_dat_from_dptx[(13*11)+10], lnk_dat_from_dptx[(12*11)+10]};     // Disparity control (0-automatic / 1-force)
        tx_dat_to_phy[3][79:48] <= 0;
    end


//-----
// RX mapping
//-----
    always_ff @ (posedge clk_from_rx_buf)
    begin
        // Lane 0
        {lnk_dat_to_dprx[(3*9)+:9], lnk_dat_to_dprx[(2*9)+:9], lnk_dat_to_dprx[(1*9)+:9], lnk_dat_to_dprx[(0*9)+:9]} <= {rx_dat_from_phy[0][(3*10)+:9], rx_dat_from_phy[0][(2*10)+:9], rx_dat_from_phy[0][(1*10)+:9], rx_dat_from_phy[0][(0*10)+:9]}; 

        // Lane 1
        {lnk_dat_to_dprx[(7*9)+:9], lnk_dat_to_dprx[(6*9)+:9], lnk_dat_to_dprx[(5*9)+:9], lnk_dat_to_dprx[(4*9)+:9]} <= {rx_dat_from_phy[1][(3*10)+:9], rx_dat_from_phy[1][(2*10)+:9], rx_dat_from_phy[1][(1*10)+:9], rx_dat_from_phy[1][(0*10)+:9]}; 

        // Lane 2
        {lnk_dat_to_dprx[(11*9)+:9], lnk_dat_to_dprx[(10*9)+:9], lnk_dat_to_dprx[(9*9)+:9], lnk_dat_to_dprx[(8*9)+:9]} <= {rx_dat_from_phy[2][(3*10)+:9], rx_dat_from_phy[2][(2*10)+:9], rx_dat_from_phy[2][(1*10)+:9], rx_dat_from_phy[2][(0*10)+:9]}; 

        // Lane 3
        {lnk_dat_to_dprx[(15*9)+:9], lnk_dat_to_dprx[(14*9)+:9], lnk_dat_to_dprx[(13*9)+:9], lnk_dat_to_dprx[(12*9)+:9]} <= {rx_dat_from_phy[3][(3*10)+:9], rx_dat_from_phy[3][(2*10)+:9], rx_dat_from_phy[3][(1*10)+:9], rx_dat_from_phy[3][(0*10)+:9]}; 
    end


// System clock heartbeat
    prt_hb
    #(
        .P_BEAT ('d25_000_000)
    )
    SYS_HB_INST
    (
        .CLK_IN     (clk_from_sys_pll),
        .LED_OUT    (led_from_sys_hb)
    );

// Serdes TX clock heartbeat
    prt_hb
    #(
        .P_BEAT ('d67_500_000)
    )
    SDTX_HB_INST
    (
        .CLK_IN     (clk_from_tx_buf),
        .LED_OUT    (led_from_sdtx_hb)
    );

// Serdes RX clock heartbeat
    prt_hb
    #(
        .P_BEAT ('d67_500_000)
    )
    SDRX_HB_INST
    (
        .CLK_IN     (clk_from_rx_buf),
        .LED_OUT    (led_from_sdrx_hb)
    );

// Video clock heartbeat
    prt_hb
    #(
        .P_BEAT ('d67_500_000)
    )
    VID_HB_INST
    (
        .CLK_IN     (clk_from_vid_buf),
        .LED_OUT    (led_from_vid_hb)
    );

// Outputs

    // LED
    assign LED_OUT[0]   = led_from_sys_hb;
    assign LED_OUT[1]   = hb_from_dptx;
    assign LED_OUT[2]   = hb_from_dprx;
    assign LED_OUT[3]   = led_from_sdtx_hb; 
    assign LED_OUT[4]   = led_from_sdrx_hb;
    assign LED_OUT[5]   = led_from_vid_hb;
    assign LED_OUT[6]   = 0; 
    assign LED_OUT[7]   = 0;

    assign DPTX_I2C_SEL_OUT = 1;    // Only for DP21 TX card. Select FMC I2C interface
    assign DPRX_I2C_SEL_OUT = 1;    // Only for DP21 RX card. Select FMC I2C interface

endmodule

`default_nettype wire