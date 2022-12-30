/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    DP reference design running on Lattice LFCPNX-EVN
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

//`default_nettype none

module dp_ref_lat_lfcpnx_evn
(
    // Clock
    input wire              SYS_CLK_IN,               // 125 MHz

    // UART
    input wire              UART_RX_IN,
    output wire             UART_TX_OUT,

    // I2C
    inout wire              I2C_SCL_INOUT,
    inout wire              I2C_SDA_INOUT,

    // Tentiva
    output wire             TENTIVA_CLK_SEL_OUT,        // Clock select
    input wire              TENTIVA_PHY_CLK_LOCK_IN,    // PHY clock lock
    input wire              TENTIVA_VID_CLK_LOCK_IN,    // Video clock lock
    input wire              TENTIVA_VID_CLK_IN,         // Video clock 

    // PHY reference clocks
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

    // DP RX
    input wire [3:0]        DPRX_ML_IN_P,            // Main link
    input wire [3:0]        DPRX_ML_IN_N,            // Main link
    output wire             DPRX_AUX_EN_OUT,         // AUX Enable
    output wire             DPRX_AUX_TX_OUT,         // AUX Transmit
    input wire              DPRX_AUX_RX_IN,          // AUX Receive
    output wire             DPRX_HPD_OUT,            // HPD

    // Misc
    output wire [7:0]       LED_OUT
);


/*
    Parameters
*/
localparam P_VENDOR         = "lattice";
localparam P_SYS_FREQ       = 50_000_000;      // System frequency 50 MHz
localparam P_BEAT           = P_SYS_FREQ / 1_000_000;   // Beat value. 
localparam P_REF_VER_MAJOR  = 1;     // Reference design version major
localparam P_REF_VER_MINOR  = 0;     // Reference design minor
localparam P_PIO_IN_WIDTH   = 6;
localparam P_PIO_OUT_WIDTH  = 8;
localparam P_LANES          = 4;
localparam P_SPL            = 4;
localparam P_PPC            = 4;
localparam P_BPC            = 8;
localparam P_AXI_WIDTH      = 96;
localparam P_SCALER         = 0;

// Interfaces

// DPTX
prt_dp_lb_if
#(
  .P_ADR_WIDTH  (16)
)
dptx_if();

// DPRX
prt_dp_lb_if
#(
  .P_ADR_WIDTH  (16)
)
dprx_if();

// VTB
prt_dp_lb_if
#(
  .P_ADR_WIDTH  (16)
)
vtb_if();

// PHY config 
prt_dp_lb_if
#(
  .P_ADR_WIDTH  (16)
)
phy_if();

// Scaler
prt_dp_lb_if
#(
  .P_ADR_WIDTH  (16)
)
scaler_if();


/*
    Wires
*/

// Reset
(* syn_preserve=1 *) logic [9:0]             sclk_rst_cnt;
(* syn_preserve=1 *) logic                   sclk_rst;

// Clocks
wire    clk_from_sys_pll;
wire    lock_from_sys_pll;
wire    refclk0_from_diffclkio;
wire    refclk1_from_diffclkio;
wire    clk_from_tx_buf;
wire    clk_from_rx_buf;
wire    clk_from_vid_buf;

// APP
wire [P_PIO_IN_WIDTH-1:0]       pio_dat_to_app;
wire [P_PIO_OUT_WIDTH-1:0]      pio_dat_from_app;

wire                            dptx_rst_from_app;
wire                            dprx_rst_from_app;
wire                            phy_all_rst_from_app;
wire                            phy_tx_rst_from_app;
wire                            phy_rx_rst_from_app;

// DPTX
wire                            irq_from_dptx;
wire [(P_LANES*P_SPL*11)-1:0]   lnk_dat_from_dptx;
wire                            hb_from_dptx;

// DPRX
wire                            irq_from_dprx;
wire [(P_LANES*P_SPL*9)-1:0]    lnk_dat_to_dprx;
wire                            hb_from_dprx;
wire                            hpd_from_dprx;
wire                            lnk_sync_from_dprx;

wire                            vid_sof_from_dprx;   // Start of frame
wire                            vid_eol_from_dprx;   // End of line
wire [P_AXI_WIDTH-1:0]          vid_dat_from_dprx;   // Data
wire                            vid_vld_from_dprx;   // Valid

// VTB
wire                            vs_from_vtb;
wire                            hs_from_vtb;
wire [(P_PPC*P_BPC)-1:0]        r_from_vtb;
wire [(P_PPC*P_BPC)-1:0]        g_from_vtb;
wire [(P_PPC*P_BPC)-1:0]        b_from_vtb;
wire                            de_from_vtb;

// Scaler
wire                            cke_from_scaler;
wire                            vs_from_scaler;
wire                            hs_from_scaler;
wire [(P_PPC*P_BPC)-1:0]        r_from_scaler;
wire [(P_PPC*P_BPC)-1:0]        g_from_scaler;
wire [(P_PPC*P_BPC)-1:0]        b_from_scaler;
wire                            de_from_scaler;

// DIA
wire                            dia_rdy_from_app;
wire [31:0]                     dia_dat_from_vtb;
wire                            dia_vld_from_vtb;

// LMMI
wire [3:0]                      req_from_lmmi;
wire [3:0]                      dir_from_lmmi;
wire [(4*9)-1:0]                adr_from_lmmi;
wire [(4*8)-1:0]                dat_from_lmmi;

// PHY
wire                            tx_clk_from_phy;
wire                            rx_clk_from_phy;
wire [79:0]                     tx_dat_to_phy[0:3];
wire [79:0]                     rx_dat_from_phy[0:3];
wire [3:0]                      rdy_from_phy;

wire [(4*8)-1:0]                lmmi_dat_from_phy;
wire [3:0]                      lmmi_vld_from_phy;
wire [3:0]                      lmmi_rdy_from_phy;

// Heartbeat
wire                            led_from_sys_hb;
wire                            led_from_phytx_hb;
wire                            led_from_phyrx_hb;
wire                            led_from_vid_hb;


/*
    Logic
*/

// System PLL
// This PLL generates the 100 MHz clock for the application.    
    sys_pll
    SYS_PLL_INST
    (
        .clki_i     (SYS_CLK_IN), 
        .clkop_o    (clk_from_sys_pll), 
        .lock_o     (lock_from_sys_pll)
    );

// Reset generator
    always_ff @ (negedge lock_from_sys_pll, posedge clk_from_sys_pll)
    begin
        if (!lock_from_sys_pll)
        begin
            sclk_rst <= 1;
            sclk_rst_cnt <= 0;
        end

        else
        begin
            // Increment
            if (!(&sclk_rst_cnt))
                sclk_rst_cnt <= sclk_rst_cnt + 'd1;

            // Counter expired
            else
                sclk_rst <= 0;
        end
    end

// Global reset 
// This is needed to insert manually.
// Else Radiant might select one of the internal DP reset signals.
    GSR
    GSR_INST
    (
        .GSR_N (lock_from_sys_pll),  
        .CLK   (clk_from_sys_pll)  
    );

// Serdes reference clock buffer
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

// Video clock input buffer
    IB
    VID_BUF_INST
    (
        .I (TENTIVA_VID_CLK_IN),  // I
        .O (clk_from_vid_buf)   // O
    );

// Application
    dp_app_top
    #(
        .P_VENDOR           (P_VENDOR),
        .P_SYS_FREQ         (P_SYS_FREQ),
        .P_HW_VER_MAJOR     (P_REF_VER_MAJOR),   // Reference design version major
        .P_HW_VER_MINOR     (P_REF_VER_MINOR),   // Reference design minor
        .P_PIO_IN_WIDTH     (P_PIO_IN_WIDTH),
        .P_PIO_OUT_WIDTH    (P_PIO_OUT_WIDTH),
        .P_AQUA             (0)
    )
    APP_INST
    (
         // Reset and clock
        .RST_IN             (sclk_rst),    
        .CLK_IN             (clk_from_sys_pll),

        // PIO
        .PIO_DAT_IN         (pio_dat_to_app),
        .PIO_DAT_OUT        (pio_dat_from_app),

        // Uart
        .UART_RX_IN         (UART_RX_IN),
        .UART_TX_OUT        (UART_TX_OUT),

        // I2C
        .I2C_SCL_INOUT      (I2C_SCL_INOUT),
        .I2C_SDA_INOUT      (I2C_SDA_INOUT),

        // Direct I2C Access
        .DIA_RDY_OUT        (dia_rdy_from_app),
        .DIA_DAT_IN         (dia_dat_from_vtb),
        .DIA_VLD_IN         (dia_vld_from_vtb),

        // DPTX interface
        .DPTX_IF            (dptx_if),
        .DPTX_IRQ_IN        (irq_from_dptx),

        // DPRX interface
        .DPRX_IF            (dprx_if),
        .DPRX_IRQ_IN        (irq_from_dprx),

        // VTB interface
        .VTB_IF             (vtb_if),

        // PHY interface
        .PHY_IF             (phy_if),

        // Scaler interface
        .SCALER_IF          (scaler_if),

        // Aqua 
        .AQUA_SEL_IN        (1'b0),
        .AQUA_CTL_IN        (1'b0),
        .AQUA_CLK_IN        (1'b0),
        .AQUA_DAT_IN        (1'b0)
    );

    // PIO in mapping
    assign pio_dat_to_app[0]        = TENTIVA_PHY_CLK_LOCK_IN; 
    assign pio_dat_to_app[1]        = TENTIVA_VID_CLK_LOCK_IN;
    assign pio_dat_to_app[2]        = &rdy_from_phy;

    // PIO out mapping
    assign TENTIVA_CLK_SEL_OUT      = pio_dat_from_app[0];
    assign dptx_rst_from_app        = pio_dat_from_app[1];
    assign dprx_rst_from_app        = pio_dat_from_app[2];
    assign phy_all_rst_from_app     = pio_dat_from_app[3];
    assign phy_tx_rst_from_app      = pio_dat_from_app[4];
    assign phy_rx_rst_from_app      = pio_dat_from_app[5];

// Displayport TX
    prt_dptx_top
    #(
        // System
        .P_VENDOR           (P_VENDOR),   // Vendor
        .P_BEAT             (P_BEAT),     // Beat value. The system clock is 125 MHz

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
        .SYS_RST_IN         (dptx_rst_from_app),
        .SYS_CLK_IN         (clk_from_sys_pll),

        // Host interface
        .HOST_IF            (dptx_if),
        .HOST_IRQ_OUT       (irq_from_dptx),

        // AUX
        .AUX_EN_OUT         (DPTX_AUX_EN_OUT),
        .AUX_TX_OUT         (DPTX_AUX_TX_OUT),
        .AUX_RX_IN          (DPTX_AUX_RX_IN),

        // Misc
        .HPD_IN             (~DPTX_HPD_IN),             // Hot plug polarity is inverted
        .HB_OUT             (hb_from_dptx),

        // Video
        .VID_CLK_IN         (clk_from_vid_buf),
        .VID_CKE_IN         (1'b1),
        .VID_VS_IN          (vs_from_scaler),           // Vsync
        .VID_HS_IN          (hs_from_scaler),           // Hsync
        .VID_R_IN           (r_from_scaler),            // Red
        .VID_G_IN           (g_from_scaler),            // Green
        .VID_B_IN           (b_from_scaler),            // Blue
        .VID_DE_IN          (de_from_scaler),           // Data enable

        // Link
        .LNK_CLK_IN         (clk_from_tx_buf),
        .LNK_DAT_OUT        (lnk_dat_from_dptx)
    );

// Displayport RX
    prt_dprx_top
    #(
        // System
        .P_VENDOR           (P_VENDOR),   // Vendor
        .P_BEAT             (P_BEAT),     // Beat value. The system clock is 125 MHz

        // Link
        .P_LANES            (P_LANES),    // Lanes
        .P_SPL              (P_SPL),      // Symbols per lane

        // Video
        .P_PPC              (P_PPC),      // Pixels per clock
        .P_BPC              (P_BPC),      // Bits per component
        .P_VID_DAT          (P_AXI_WIDTH)
    )
    DPRX_INST
    (
        // Reset and Clock
        .SYS_RST_IN         (dprx_rst_from_app),
        .SYS_CLK_IN         (clk_from_sys_pll),

        // Host interface
        .HOST_IF            (dprx_if),
        .HOST_IRQ_OUT       (irq_from_dprx),

        // AUX
        .AUX_EN_OUT         (DPRX_AUX_EN_OUT),
        .AUX_TX_OUT         (DPRX_AUX_TX_OUT),
        .AUX_RX_IN          (DPRX_AUX_RX_IN),

        // Misc
        .HPD_OUT            (DPRX_HPD_OUT),
        .HB_OUT             (hb_from_dprx),

        // Link
        .LNK_CLK_IN         (clk_from_rx_buf),      // Clock
        .LNK_DAT_IN         (lnk_dat_to_dprx),      // Data
        .LNK_SYNC_OUT       (lnk_sync_from_dprx),   // Sync

        // Video
        .VID_CLK_IN         (clk_from_vid_buf),     // Clock
        .VID_RDY_IN         (1'b1),                 // Ready
        .VID_SOF_OUT        (vid_sof_from_dprx),    // Start of frame
        .VID_EOL_OUT        (vid_eol_from_dprx),    // End of line
        .VID_DAT_OUT        (vid_dat_from_dprx),    // Data
        .VID_VLD_OUT        (vid_vld_from_dprx)     // Valid
    );

// Video toolbox
    prt_vtb_top
    #(
        .P_SYS_FREQ             (P_SYS_FREQ),   // System frequency
        .P_PPC                  (P_PPC),        // Pixels per clock
        .P_BPC                  (P_BPC),        // Bits per component
        .P_AXIS_DAT             (P_AXI_WIDTH)
    )
    VTB_INST
    (
        // System
        .SYS_RST_IN             (dptx_rst_from_app),
        .SYS_CLK_IN             (clk_from_sys_pll),

        // Local bus
        .LB_IF                  (vtb_if),

        // Direct I2C Access
        .DIA_RDY_IN             (dia_rdy_from_app),
        .DIA_DAT_OUT            (dia_dat_from_vtb),
        .DIA_VLD_OUT            (dia_vld_from_vtb),

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
        .VID_CKE_IN             (cke_from_scaler),
        .VID_VS_OUT             (vs_from_vtb),
        .VID_HS_OUT             (hs_from_vtb),
        .VID_R_OUT              (r_from_vtb),
        .VID_G_OUT              (g_from_vtb),
        .VID_B_OUT              (b_from_vtb),
        .VID_DE_OUT             (de_from_vtb),

        // Debug
        .DBG_CR_SYNC_END_OUT    (),                         // Sync end out
        .DBG_CR_PIX_END_OUT     ()                          // Pixel end out
    );

// Scaler
generate
    if (P_SCALER == 1)
    begin : gen_scaler
        prt_scaler_top
        #(
            .P_PPC (4),          // Pixels per clock
            .P_BPC (8)           // Bits per component
        )
        SCALER_INST
        (
             // System
            .SYS_RST_IN             (dptx_rst_from_app),
            .SYS_CLK_IN             (clk_from_sys_pll),

            // Local bus interface
            .LB_IF                  (scaler_if),

            // Video
            .VID_CLK_IN             (clk_from_vid_buf),

            // Video in
            .VID_CKE_IN             (cke_from_scaler),      // Clock enable
            .VID_VS_IN              (vs_from_vtb),          // Vertical sync
            .VID_HS_IN              (hs_from_vtb),          // Horizontal sync    
            .VID_R_IN               (r_from_vtb),           // Red
            .VID_G_IN               (g_from_vtb),           // Green
            .VID_B_IN               (b_from_vtb),           // Blue
            .VID_DE_IN              (de_from_vtb),          // Data enable

             // Video out
            .VID_CKE_OUT            (cke_from_scaler),      // Clock enable
            .VID_VS_OUT             (vs_from_scaler),       // Vertical sync    
            .VID_HS_OUT             (hs_from_scaler),       // Horizontal sync    
            .VID_R_OUT              (r_from_scaler),        // Red
            .VID_G_OUT              (g_from_scaler),        // Green
            .VID_B_OUT              (b_from_scaler),        // Blue
            .VID_DE_OUT             (de_from_scaler)        // Data enable
        );
    end

    else
    begin : gen_no_scaler
        assign cke_from_scaler = 1;
        assign vs_from_scaler = vs_from_vtb;
        assign hs_from_scaler = hs_from_vtb;
        assign r_from_scaler = r_from_vtb;
        assign g_from_scaler = g_from_vtb;
        assign b_from_scaler = b_from_vtb;
        assign de_from_scaler = de_from_vtb;
    end
endgenerate

// LMMI bridge
    prt_lat_lmmi
    #(
        .P_LMMI_PORTS       (4),
        .P_LMMI_ADR         (9),
        .P_LMMI_DAT         (8)
    )
    LMMI_INST
    (
        // Reset and clock
        .RST_IN             (sclk_rst),                 // Reset
        .CLK_IN             (clk_from_sys_pll),         // Clock 

        // Local bus interface
        .LB_IF              (phy_if),

        // LMMI
        .LMMI_REQ_OUT       (req_from_lmmi),            // Request
        .LMMI_DIR_OUT       (dir_from_lmmi),            // Direction
        .LMMI_ADR_OUT       (adr_from_lmmi),            // Address
        .LMMI_DAT_OUT       (dat_from_lmmi),            // Write data
        .LMMI_DAT_IN        (lmmi_dat_from_phy),     // Read data
        .LMMI_VLD_IN        (lmmi_vld_from_phy),     // Valid
        .LMMI_RDY_IN        (lmmi_rdy_from_phy)      // Ready
    );

// PHY TX clock buffer
    BUF
    BUF_TX_INST
    (
        .A (tx_clk_from_phy),   // I
        .Z (clk_from_tx_buf)    // O
    );

// PHY RX clock buffer
    BUF
    BUF_RX_INST
    (
        .A (rx_clk_from_phy),   // I
        .Z (clk_from_rx_buf)    // O
    );

// PHY
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
        .diffioclksel_i             (1'b1),     // Differential clock select; 0 - sd_ext_0_refclk / 1 - sd_ext_1_refclk 
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
        .lmmi_request_i_0           (req_from_lmmi[0]), 
        .lmmi_wr_rdn_i_0            (dir_from_lmmi[0]), 
        .lmmi_offset_i_0            (adr_from_lmmi[(0*9)+:9]), 
        .lmmi_wdata_i_0             (dat_from_lmmi[(0*8)+:8]), 
        .lmmi_rdata_valid_o_0       (lmmi_vld_from_phy[0]), 
        .lmmi_ready_o_0             (lmmi_rdy_from_phy[0]), 
        .lmmi_rdata_o_0             (lmmi_dat_from_phy[(0*8)+:8]), 

        .lmmi_clk_i_1               (clk_from_sys_pll), 
        .lmmi_resetn_i_1            (~sclk_rst), 
        .lmmi_request_i_1           (req_from_lmmi[1]), 
        .lmmi_wr_rdn_i_1            (dir_from_lmmi[1]), 
        .lmmi_offset_i_1            (adr_from_lmmi[(1*9)+:9]), 
        .lmmi_wdata_i_1             (dat_from_lmmi[(1*8)+:8]), 
        .lmmi_rdata_valid_o_1       (lmmi_vld_from_phy[1]), 
        .lmmi_ready_o_1             (lmmi_rdy_from_phy[1]), 
        .lmmi_rdata_o_1             (lmmi_dat_from_phy[(1*8)+:8]), 

        .lmmi_clk_i_2               (clk_from_sys_pll), 
        .lmmi_resetn_i_2            (~sclk_rst), 
        .lmmi_request_i_2           (req_from_lmmi[2]), 
        .lmmi_wr_rdn_i_2            (dir_from_lmmi[2]), 
        .lmmi_offset_i_2            (adr_from_lmmi[(2*9)+:9]), 
        .lmmi_wdata_i_2             (dat_from_lmmi[(2*8)+:8]), 
        .lmmi_rdata_valid_o_2       (lmmi_vld_from_phy[2]), 
        .lmmi_ready_o_2             (lmmi_rdy_from_phy[2]), 
        .lmmi_rdata_o_2             (lmmi_dat_from_phy[(2*8)+:8]), 

        .lmmi_clk_i_3               (clk_from_sys_pll), 
        .lmmi_resetn_i_3            (~sclk_rst), 
        .lmmi_request_i_3           (req_from_lmmi[3]), 
        .lmmi_wr_rdn_i_3            (dir_from_lmmi[3]), 
        .lmmi_offset_i_3            (adr_from_lmmi[(3*9)+:9]), 
        .lmmi_wdata_i_3             (dat_from_lmmi[(3*8)+:8]), 
        .lmmi_rdata_valid_o_3       (lmmi_vld_from_phy[3]), 
        .lmmi_ready_o_3             (lmmi_rdy_from_phy[3]), 
        .lmmi_rdata_o_3             (lmmi_dat_from_phy[(3*8)+:8]), 

        // Reset 
        .mpcs_perstn_i_3            (~phy_all_rst_from_app), 
        .mpcs_perstn_i_2            (~phy_all_rst_from_app), 
        .mpcs_perstn_i_1            (~phy_all_rst_from_app), 
        .mpcs_perstn_i_0            (~phy_all_rst_from_app), 
        .mpcs_tx_pcs_rstn_i_3       (~phy_tx_rst_from_app), 
        .mpcs_tx_pcs_rstn_i_2       (~phy_tx_rst_from_app), 
        .mpcs_tx_pcs_rstn_i_1       (~phy_tx_rst_from_app), 
        .mpcs_tx_pcs_rstn_i_0       (~phy_tx_rst_from_app), 
        .mpcs_rx_pcs_rstn_i_3       (~phy_rx_rst_from_app), 
        .mpcs_rx_pcs_rstn_i_2       (~phy_rx_rst_from_app), 
        .mpcs_rx_pcs_rstn_i_1       (~phy_rx_rst_from_app), 
        .mpcs_rx_pcs_rstn_i_0       (~phy_rx_rst_from_app), 

        // MPCS Clocks
        .mpcs_clkin_i_3             (clk_from_sys_pll), 
        .mpcs_clkin_i_2             (clk_from_sys_pll), 
        .mpcs_clkin_i_1             (clk_from_sys_pll), 
        .mpcs_clkin_i_0             (clk_from_sys_pll), 
        .mpcs_rx_usr_clk_i_3        (clk_from_rx_buf), 
        .mpcs_rx_usr_clk_i_2        (clk_from_rx_buf), 
        .mpcs_rx_usr_clk_i_1        (clk_from_rx_buf), 
        .mpcs_rx_usr_clk_i_0        (clk_from_rx_buf), 
        .mpcs_tx_usr_clk_i_3        (clk_from_tx_buf), 
        .mpcs_tx_usr_clk_i_2        (clk_from_tx_buf), 
        .mpcs_tx_usr_clk_i_1        (clk_from_tx_buf), 
        .mpcs_tx_usr_clk_i_0        (clk_from_tx_buf), 
        .mpcs_rx_out_clk_o_3        (rx_clk_from_phy),  // The first DP lane is mapped on the last PHY channel. This is the master lane.
        .mpcs_rx_out_clk_o_2        (), 
        .mpcs_rx_out_clk_o_1        (), 
        .mpcs_rx_out_clk_o_0        (), 
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
        .mpcs_rate_i_3              (2'b00), 
        .mpcs_rate_i_2              (2'b00), 
        .mpcs_rate_i_1              (2'b00), 
        .mpcs_rate_i_0              (2'b00), 
        .mpcs_speed_o_3             (), 
        .mpcs_speed_o_2             (), 
        .mpcs_speed_o_1             (), 
        .mpcs_speed_o_0             (), 
        .mpcs_txval_i_3             (1'b1), 
        .mpcs_txval_i_2             (1'b1), 
        .mpcs_txval_i_1             (1'b1), 
        .mpcs_txval_i_0             (1'b1), 
        .mpcs_rxval_o_3             (), 
        .mpcs_rxval_o_2             (), 
        .mpcs_rxval_o_1             (), 
        .mpcs_rxval_o_0             (),
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
        .mpcs_anxmit_i_3            (1'b0), 
        .mpcs_anxmit_i_2            (1'b0), 
        .mpcs_anxmit_i_1            (1'b0), 
        .mpcs_anxmit_i_0            (1'b0), 
        
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


// TX mapping
// DP lane 0 
    assign tx_dat_to_phy[1][0+:9]  = {lnk_dat_from_dptx[(0*11)+8], lnk_dat_from_dptx[(0*11)+:8]};            // TX symbol 0
    assign tx_dat_to_phy[1][10+:9] = {lnk_dat_from_dptx[(1*11)+8], lnk_dat_from_dptx[(1*11)+:8]};            // TX symbol 1
    assign tx_dat_to_phy[1][20+:9] = {lnk_dat_from_dptx[(2*11)+8], lnk_dat_from_dptx[(2*11)+:8]};            // TX symbol 2
    assign tx_dat_to_phy[1][30+:9] = {lnk_dat_from_dptx[(3*11)+8], lnk_dat_from_dptx[(3*11)+:8]};            // TX symbol 3
    assign tx_dat_to_phy[1][47:44] = {lnk_dat_from_dptx[(3*11)+9], lnk_dat_from_dptx[(2*11)+9], lnk_dat_from_dptx[(1*11)+9], lnk_dat_from_dptx[(0*11)+9]};       // Disparity value (0-negative / 1-positive)
    assign tx_dat_to_phy[1][43:40] = {lnk_dat_from_dptx[(3*11)+10], lnk_dat_from_dptx[(2*11)+10], lnk_dat_from_dptx[(1*11)+10], lnk_dat_from_dptx[(0*11)+10]};     // Disparity control (0-automatic / 1-force)
    assign tx_dat_to_phy[1][79:48] = 0;

// DP lane 1 
    assign tx_dat_to_phy[0][0+:9]  = {lnk_dat_from_dptx[(4*11)+8], lnk_dat_from_dptx[(4*11)+:8]};            // TX symbol 0
    assign tx_dat_to_phy[0][10+:9] = {lnk_dat_from_dptx[(5*11)+8], lnk_dat_from_dptx[(5*11)+:8]};            // TX symbol 1
    assign tx_dat_to_phy[0][20+:9] = {lnk_dat_from_dptx[(6*11)+8], lnk_dat_from_dptx[(6*11)+:8]};            // TX symbol 0
    assign tx_dat_to_phy[0][30+:9] = {lnk_dat_from_dptx[(7*11)+8], lnk_dat_from_dptx[(7*11)+:8]};            // TX symbol 1
    assign tx_dat_to_phy[0][47:44] = {lnk_dat_from_dptx[(7*11)+9], lnk_dat_from_dptx[(6*11)+9], lnk_dat_from_dptx[(5*11)+9], lnk_dat_from_dptx[(4*11)+9]};       // Disparity value (0-negative / 1-positive)
    assign tx_dat_to_phy[0][43:40] = {lnk_dat_from_dptx[(7*11)+10], lnk_dat_from_dptx[(6*11)+10], lnk_dat_from_dptx[(5*11)+10], lnk_dat_from_dptx[(4*11)+10]};     // Disparity control (0-automatic / 1-force)
    assign tx_dat_to_phy[0][79:48] = 0;

// DP lane 2 
    assign tx_dat_to_phy[2][0+:9]  = {lnk_dat_from_dptx[(8*11)+8], lnk_dat_from_dptx[(8*11)+:8]};            // TX symbol 0
    assign tx_dat_to_phy[2][10+:9] = {lnk_dat_from_dptx[(9*11)+8], lnk_dat_from_dptx[(9*11)+:8]};            // TX symbol 1
    assign tx_dat_to_phy[2][20+:9] = {lnk_dat_from_dptx[(10*11)+8], lnk_dat_from_dptx[(10*11)+:8]};          // TX symbol 2
    assign tx_dat_to_phy[2][30+:9] = {lnk_dat_from_dptx[(11*11)+8], lnk_dat_from_dptx[(11*11)+:8]};          // TX symbol 3
    assign tx_dat_to_phy[2][47:44] = {lnk_dat_from_dptx[(11*11)+9], lnk_dat_from_dptx[(10*11)+9], lnk_dat_from_dptx[(9*11)+9], lnk_dat_from_dptx[(8*11)+9]};       // Disparity value (0-negative / 1-positive)
    assign tx_dat_to_phy[2][43:40] = {lnk_dat_from_dptx[(11*11)+10], lnk_dat_from_dptx[(10*11)+10], lnk_dat_from_dptx[(9*11)+10], lnk_dat_from_dptx[(8*11)+10]};     // Disparity control (0-automatic / 1-force)
    assign tx_dat_to_phy[2][79:48] = 0;

// DP lane 3 
    assign tx_dat_to_phy[3][0+:9]  = {lnk_dat_from_dptx[(12*11)+8], lnk_dat_from_dptx[(12*11)+:8]};          // TX symbol 0
    assign tx_dat_to_phy[3][10+:9] = {lnk_dat_from_dptx[(13*11)+8], lnk_dat_from_dptx[(13*11)+:8]};          // TX symbol 1
    assign tx_dat_to_phy[3][20+:9] = {lnk_dat_from_dptx[(14*11)+8], lnk_dat_from_dptx[(14*11)+:8]};          // TX symbol 2
    assign tx_dat_to_phy[3][30+:9] = {lnk_dat_from_dptx[(15*11)+8], lnk_dat_from_dptx[(15*11)+:8]};          // TX symbol 3
    assign tx_dat_to_phy[3][47:44] = {lnk_dat_from_dptx[(15*11)+9], lnk_dat_from_dptx[(14*11)+9], lnk_dat_from_dptx[(13*11)+9], lnk_dat_from_dptx[(12*11)+9]};       // Disparity value (0-negative / 1-positive)
    assign tx_dat_to_phy[3][43:40] = {lnk_dat_from_dptx[(15*11)+10], lnk_dat_from_dptx[(14*11)+10], lnk_dat_from_dptx[(13*11)+10], lnk_dat_from_dptx[(12*11)+10]};     // Disparity control (0-automatic / 1-force)
    assign tx_dat_to_phy[3][79:48] = 0;

// RX mapping
    // Lane 0
    assign {lnk_dat_to_dprx[(3*9)+:9], lnk_dat_to_dprx[(2*9)+:9], lnk_dat_to_dprx[(1*9)+:9], lnk_dat_to_dprx[(0*9)+:9]} = {rx_dat_from_phy[3][(3*10)+:9], rx_dat_from_phy[3][(2*10)+:9], rx_dat_from_phy[3][(1*10)+:9], rx_dat_from_phy[3][(0*10)+:9]}; 

    // Lane 1
    assign {lnk_dat_to_dprx[(7*9)+:9], lnk_dat_to_dprx[(6*9)+:9], lnk_dat_to_dprx[(5*9)+:9], lnk_dat_to_dprx[(4*9)+:9]} = {rx_dat_from_phy[2][(3*10)+:9], rx_dat_from_phy[2][(2*10)+:9], rx_dat_from_phy[2][(1*10)+:9], rx_dat_from_phy[2][(0*10)+:9]}; 

    // Lane 2
    assign {lnk_dat_to_dprx[(11*9)+:9], lnk_dat_to_dprx[(10*9)+:9], lnk_dat_to_dprx[(9*9)+:9], lnk_dat_to_dprx[(8*9)+:9]} = {rx_dat_from_phy[0][(3*10)+:9], rx_dat_from_phy[0][(2*10)+:9], rx_dat_from_phy[0][(1*10)+:9], rx_dat_from_phy[0][(0*10)+:9]}; 

    // Lane 3
    assign {lnk_dat_to_dprx[(15*9)+:9], lnk_dat_to_dprx[(14*9)+:9], lnk_dat_to_dprx[(13*9)+:9], lnk_dat_to_dprx[(12*9)+:9]} = {rx_dat_from_phy[1][(3*10)+:9], rx_dat_from_phy[1][(2*10)+:9], rx_dat_from_phy[1][(1*10)+:9], rx_dat_from_phy[1][(0*10)+:9]}; 

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

// PHY TX clock heartbeat
    prt_hb
    #(
        .P_BEAT ('d67_500_000)
    )
    PHYTX_HB_INST
    (
        .CLK_IN     (clk_from_tx_buf),
        .LED_OUT    (led_from_phytx_hb)
    );

// PHY RX clock heartbeat
    prt_hb
    #(
        .P_BEAT ('d67_500_000)
    )
    PHYRX_HB_INST
    (
        .CLK_IN     (clk_from_rx_buf),
        .LED_OUT    (led_from_phyrx_hb)
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
    assign LED_OUT[3]   = led_from_phytx_hb; 
    assign LED_OUT[4]   = led_from_phyrx_hb;
    assign LED_OUT[5]   = led_from_vid_hb;
    assign LED_OUT[6]   = 0; 
    assign LED_OUT[7]   = 0;

endmodule

//`default_nettype wire
