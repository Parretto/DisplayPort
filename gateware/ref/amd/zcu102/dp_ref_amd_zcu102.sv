/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP reference design running on Xilinx ZCU102
    (c) 2021 - 2025 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Added MST feature
    v1.2 - Separated TX and RX reference clocks
    v1.3 - Added 10-bits video 
    v1.4 - Updated DRP peripheral with PIO
    v1.5 - Added support for Tentiva DP21TX and DP21RX cards
    
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

module dp_ref_amd_zcu102
(
    // Clock
    input wire              CLK_IN_P,               // 125 MHz
    input wire              CLK_IN_N,

    // UART
    input wire              UART_RX_IN,
    output wire             UART_TX_OUT,

    // I2C
    inout wire              I2C_SCL_INOUT,
    inout wire              I2C_SDA_INOUT,

    // Tentiva
    output wire             TENTIVA_CLK_SEL_OUT,        // Clock select
    input wire              TENTIVA_GT_CLK_LOCK_IN,     // GT clock lock
    input wire              TENTIVA_VID_CLK_LOCK_IN,    // Video clock lock
    input wire              TENTIVA_VID_CLK_IN_P,       // Video clock 
    input wire              TENTIVA_VID_CLK_IN_N,       // Video clock 

    // DP TX
    output wire             DPTX_AUX_EN_OUT,            // AUX Enable
    output wire             DPTX_AUX_TX_OUT,            // AUX Transmit
    input wire              DPTX_AUX_RX_IN,             // AUX Receive
    input wire              DPTX_HPD_IN,                // HPD
    output wire             DPTX_I2C_SEL_OUT,           // I2C select (DP21 TX)

    // DP RX
    output wire             DPRX_AUX_EN_OUT,            // AUX Enable
    output wire             DPRX_AUX_TX_OUT,            // AUX Transmit
    input wire              DPRX_AUX_RX_IN,             // AUX Receive
    output wire             DPRX_HPD_OUT,               // HPD
    output wire             DPRX_I2C_SEL_OUT,           // I2C select (DP21 RX)
    input wire              DPRX_CABDET_IN,             // Cable detect

    // GT
    input wire [1:0]        GT_REFCLK_IN_P,             // GT reference clock
    input wire [1:0]        GT_REFCLK_IN_N,
    input wire [3:0]        GT_RX_IN_P,                 // GT receive
    input wire [3:0]        GT_RX_IN_N,
    output wire [3:0]       GT_TX_OUT_P,                // GT transmit
    output wire [3:0]       GT_TX_OUT_N,

    // Misc
    output wire [7:0]       LED_OUT,
    output wire [7:0]       DEBUG_OUT   
);

// Parameters
localparam P_VENDOR         = "AMD";
localparam P_SYS_FREQ       = 50_000_000;      // System frequency - 50 MHz
localparam P_BEAT           = P_SYS_FREQ / 1_000_000;   // Beat value. 
localparam P_REF_VER_MAJOR  = 1;     // Reference design version major
localparam P_REF_VER_MINOR  = 0;     // Reference design minor
localparam P_PIO_IN_WIDTH   = 4;
localparam P_PIO_OUT_WIDTH  = 5;

localparam P_LANES          = 4;
localparam P_SPL            = 2;    // Symbols per lane. Valid options - 2, 4. 
localparam P_PPC            = 4;    // Pixels per clock. Valid options - 2, 4.
localparam P_BPC            = 10;   // Bits per component. Valid options - 8, 10
localparam P_AXI_WIDTH      = (P_PPC == 2) ? ((P_BPC == 10) ? 64 : 48) : ((P_BPC == 10) ? 120 : 96);
localparam P_PHY_DAT_WIDTH  = P_LANES * P_SPL * 8;

localparam P_APP_ROM_SIZE   = 64;
localparam P_APP_RAM_SIZE   = 64;
localparam P_APP_ROM_INIT   = "dp_app_amd_zcu102_rom.mem";
localparam P_APP_RAM_INIT   = "dp_app_amd_zcu102_ram.mem";

localparam P_MST            = 0;                        // MST support
localparam P_VTB_OVL        = (P_MST) ? 1 : 0;          // VTB Overlay

localparam P_SDP            = 1;                        // SDP support

localparam P_PHY_CTL_DRP_PORTS  = 5;
localparam P_PHY_CTL_PIO_IN     = 3;
localparam P_PHY_CTL_PIO_OUT    = 16;

// Interfaces

// Local bus
prt_dp_lb_if
#(
  .P_ADR_WIDTH  (16)
)
dptx_if();

prt_dp_lb_if
#(
  .P_ADR_WIDTH  (16)
)
dprx_if();

prt_dp_lb_if
#(
  .P_ADR_WIDTH  (16)
)
vtb_if[2]();

prt_dp_lb_if
#(
  .P_ADR_WIDTH  (16)
)
phy_if();

prt_dp_lb_if
#(
  .P_ADR_WIDTH  (16)
)
scaler_if();

prt_dp_lb_if
#(
  .P_ADR_WIDTH  (16)
)
misc_if();

// Signals
// Clocks
wire                                    clk_from_sys_ibuf;
wire                                    sys_clk_from_pll;
wire                                    drp_clk_from_pll;
wire                                    clk_from_vid_ibuf;
wire                                    clk_from_vid_bufg;
wire [1:0]                              clk_from_phy_ibuf;
wire [1:0]                              odiv2_from_phy_ibuf;
wire [1:0]                              clk_from_phy_bufg;

// Reset
(* dont_touch = "yes" *) logic [7:0]    clk_por_line = 0;
(* dont_touch = "yes" *) wire           clk_por;
(* dont_touch = "yes" *) logic [9:0]    clk_rst_cnt;
(* dont_touch = "yes" *) logic          clk_rst;

// PIO
wire [P_PIO_IN_WIDTH-1:0]               pio_dat_to_app;
wire [P_PIO_OUT_WIDTH-1:0]              pio_dat_from_app;

wire                                    dptx_rst_from_app;
wire                                    dprx_rst_from_app;
wire                                    tx_card_from_app;
wire                                    rx_card_from_app;

// PHY
wire [3:0]                              pwrgd_from_phy;
wire                                    tx_rst_done_from_phy;
wire                                    rx_rst_done_from_phy;
wire                                    txclk_from_phy;
wire                                    rxclk_from_phy;
logic [P_PHY_DAT_WIDTH-1:0]             gtwiz_userdata_tx_to_phy;
logic [63:0]                            txctrl0_to_phy;
logic [63:0]                            txctrl1_to_phy;
logic [31:0]                            txctrl2_to_phy;
logic [3:0]                             txpolarity_to_phy;

wire [P_PHY_DAT_WIDTH-1:0]              gtwiz_userdata_rx_from_phy;
wire [63:0]                             rxctrl0_from_phy;
logic [3:0]                             rxpolarity_to_phy;

logic [1:0]                             dclk_gt_linerate_cap;
logic [1:0]                             dclk_gt_linerate;
logic [17:0]                            cpll_cal_txoutclk_period_to_phy;
logic [17:0]                            cpll_cal_cnt_tol_to_phy;

wire [(P_PHY_CTL_DRP_PORTS * 16)-1:0]   drp_dat_from_phy;
wire [P_PHY_CTL_DRP_PORTS-1:0]          drp_rdy_from_phy;

// DPTX
wire [(P_LANES*P_SPL*11)-1:0]           lnk_dat_from_dptx;
wire                                    irq_from_dptx;
wire                                    hb_from_dptx;

// DPRX
logic [(P_LANES*P_SPL*9)-1:0]           lnk_dat_to_dprx;
wire                                    irq_from_dprx;
wire                                    hb_from_dprx;
wire                                    lnk_sync_from_dprx;
wire                                    vid_sof_from_dprx;   // Start of frame
wire                                    vid_eol_from_dprx;   // End of line
wire [P_AXI_WIDTH-1:0]                  vid_dat_from_dprx;   // Data
wire                                    vid_vld_from_dprx;   // Valid
wire                                    sdp_sop_from_dprx;
wire                                    sdp_eop_from_dprx;
wire [31:0]                             sdp_dat_from_dprx;
wire                                    sdp_vld_from_dprx;

// VTB
wire [1:0]                              lock_from_vtb;
wire [1:0]                              vs_from_vtb;
wire [1:0]                              hs_from_vtb;
wire [(P_PPC*P_BPC)-1:0]                r_from_vtb[0:1];
wire [(P_PPC*P_BPC)-1:0]                g_from_vtb[0:1];
wire [(P_PPC*P_BPC)-1:0]                b_from_vtb[0:1];
wire [1:0]                              de_from_vtb;

// Audio
wire [23:0]                             ch_from_aud[2];

// DIA
wire                                    dia_rdy_from_app;
wire [31:0]                             dia_dat_from_vtb;
wire                                    dia_vld_from_vtb;

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
wire [1:0]                              tx_linerate_from_phy_ctl;
wire [4:0]                              tx_diffctrl_from_phy_ctl;
wire [4:0]                              tx_postcursor_from_phy_ctl;

// Heartbeat
wire                                    led_from_sys_hb;
wire                                    led_from_vid_hb;
wire                                    led_from_phy_hb;

genvar i;

// Logic

// System clock input buffer
    IBUFDS
    SYS_IBUFDS_INST
    (
       .I   (CLK_IN_P),             // 1-bit input: Diff_p buffer input (connect directly to top-level port)
       .IB  (CLK_IN_N),             // 1-bit input: Diff_n buffer input (connect directly to top-level port)
       .O   (clk_from_sys_ibuf)     // 1-bit output: Buffer output
    );

// PLL
// The system PLL generates the 50 MHz system clock.
// Also it generates the 50 MHz DRP clock.
    sys_pll
    PLL_INST
    (
        .clk_in1    (clk_from_sys_ibuf),
        .clk_out1   (sys_clk_from_pll),
        .clk_out2   (drp_clk_from_pll),
        .locked     ()
    );

// Video clock input buffer
    IBUFDS
    VID_IBUFDS_INST
    (
       .I   (TENTIVA_VID_CLK_IN_P),     // 1-bit input: Diff_p buffer input (connect directly to top-level port)
       .IB  (TENTIVA_VID_CLK_IN_N),     // 1-bit input: Diff_n buffer input (connect directly to top-level port)
       .O   (clk_from_vid_ibuf)         // 1-bit output: Buffer output
    );

// Global buffer
// A global buffer is required to route the clock to the system
    BUFGCE 
    VID_BUFGCE_INST 
    (
      .CE   (1'b1),                 // 1-bit input: Clock buffer active-High enable.
      .I    (clk_from_vid_ibuf),    // 1-bit input: Clock input.
      .O    (clk_from_vid_bufg)     // 1-bit output: Clock output.
    );

// GT Reference clock buffers
generate
    for (i = 0; i < 2; i++)
    begin : gen_gt_refclk_buf
        IBUFDS_GTE4
        #(
            .REFCLK_EN_TX_PATH  (1'b0),
            .REFCLK_HROW_CK_SEL (2'b00),
            .REFCLK_ICNTL_RX    (2'b00)
        )
        GT_IBUFDS_INST
        (
            .I      (GT_REFCLK_IN_P[i]),
            .IB     (GT_REFCLK_IN_N[i]),
            .CEB    (1'b0),
            .O      (clk_from_phy_ibuf[i]),
            .ODIV2  (odiv2_from_phy_ibuf[i])
        );

        BUFG_GT
        BUFG_GT_INST
        (
            .CE       (1'b1),
            .CEMASK   (1'b0),
            .CLR      (1'b0),
            .CLRMASK  (1'b0),
            .DIV      (3'd0),
            .I        (odiv2_from_phy_ibuf[i]),
            .O        (clk_from_phy_bufg[i])
        );
    end
endgenerate

// Power on reset
    always_ff @ (posedge sys_clk_from_pll)
    begin
        clk_por_line <= {clk_por_line[$size(clk_por_line)-2:0], 1'b1};            
    end

    assign clk_por = ~clk_por_line[$size(clk_por_line)-1];

// Reset generator
    always_ff @ (posedge clk_por, posedge sys_clk_from_pll)
    begin
        if (clk_por)
        begin
            clk_rst <= 1;
            clk_rst_cnt <= 0;
        end

        else
        begin
            // Increment
            if (!(&clk_rst_cnt))
                clk_rst_cnt <= clk_rst_cnt + 'd1;

            // Counter expired
            else
                clk_rst <= 0;
        end
    end

// Application
    dp_app_top
    #(
        .P_VENDOR           (P_VENDOR),
        .P_SYS_FREQ         (P_SYS_FREQ),       // System frequency
        .P_HW_VER_MAJOR     (P_REF_VER_MAJOR),   // Reference design version major
        .P_HW_VER_MINOR     (P_REF_VER_MINOR),   // Reference design minor
        .P_PIO_IN_WIDTH     (P_PIO_IN_WIDTH),
        .P_PIO_OUT_WIDTH    (P_PIO_OUT_WIDTH),
        .P_ROM_SIZE         (P_APP_ROM_SIZE),       // ROM size (in Kbytes)
        .P_RAM_SIZE         (P_APP_RAM_SIZE),       // RAM size (in Kbytes)
        .P_ROM_INIT         (P_APP_ROM_INIT),
        .P_RAM_INIT         (P_APP_RAM_INIT),
        .P_AQUA             (0)
    )
    APP_INST
    (
         // Reset and clock
        .RST_IN             (clk_rst),    
        .CLK_IN             (sys_clk_from_pll),

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
        .VTB0_IF            (vtb_if[0]),
        .VTB1_IF            (vtb_if[1]),

        // PHY interface
        .PHY_IF             (phy_if),

        // Scaler interface
        .SCALER_IF          (scaler_if),

        // Scaler interface
        .MISC_IF            (misc_if),

        // Aqua 
        .AQUA_SEL_IN        (1'b0),
        .AQUA_CTL_IN        (1'b0),
        .AQUA_CLK_IN        (1'b0),
        .AQUA_DAT_IN        (1'b0)
    );


    // PIO in mapping
    assign pio_dat_to_app[0]            = (P_PPC == 4) ? 1 : 0;             // Pixels per clock
    assign pio_dat_to_app[1]            = (P_BPC == 10) ? 1 : 0;            // Bits per component
    assign pio_dat_to_app[2]            = TENTIVA_GT_CLK_LOCK_IN; 
    assign pio_dat_to_app[3]            = TENTIVA_VID_CLK_LOCK_IN;

    // PIO out mapping
    assign TENTIVA_CLK_SEL_OUT          = pio_dat_from_app[0];
    assign dptx_rst_from_app            = pio_dat_from_app[1];
    assign dprx_rst_from_app            = pio_dat_from_app[2];
    assign tx_card_from_app             = pio_dat_from_app[3];      // Tentiva TX card 0 - DP1.4 / 1 - DP2.1
    assign rx_card_from_app             = pio_dat_from_app[4];      // Tentiva RX card 0 - DP1.4 / 1 - DP2.1

// Displayport TX
    prt_dptx_top
    #(
        // System
        .P_VENDOR           (P_VENDOR),     // Vendor
        .P_BEAT             (P_BEAT),       // Beat value. The system clock is 50 MHz
        .P_MST              (P_MST),        // MST support

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
        .SYS_RST_IN         (dptx_rst_from_app),
        .SYS_CLK_IN         (sys_clk_from_pll),

        // Host
        .HOST_IF            (dptx_if),
        .HOST_IRQ_OUT       (irq_from_dptx),

        // AUX
        .AUX_EN_OUT         (DPTX_AUX_EN_OUT),
        .AUX_TX_OUT         (DPTX_AUX_TX_OUT),
        .AUX_RX_IN          (DPTX_AUX_RX_IN),

        // Misc
        .HPD_IN             (~DPTX_HPD_IN),             // Hot plug polarity is inverted
        .HB_OUT             (hb_from_dptx),

        // Video stream 0
        .VID0_CLK_IN         (clk_from_vid_bufg),
        .VID0_CKE_IN         (1'b1),
        .VID0_VS_IN          (vs_from_vtb[0]),           // Vsync
        .VID0_HS_IN          (hs_from_vtb[0]),           // Hsync
        .VID0_R_IN           (r_from_vtb[0]),            // Red
        .VID0_G_IN           (g_from_vtb[0]),            // Green
        .VID0_B_IN           (b_from_vtb[0]),            // Blue
        .VID0_DE_IN          (de_from_vtb[0]),           // Data enable

        // Video stream 1
        .VID1_CLK_IN         (clk_from_vid_bufg),
        .VID1_CKE_IN         (1'b1),
        .VID1_VS_IN          (vs_from_vtb[1]),           // Vsync
        .VID1_HS_IN          (hs_from_vtb[1]),           // Hsync
        .VID1_R_IN           (r_from_vtb[1]),            // Red
        .VID1_G_IN           (g_from_vtb[1]),            // Green
        .VID1_B_IN           (b_from_vtb[1]),            // Blue
        .VID1_DE_IN          (de_from_vtb[1]),           // Data enable

        // Link
        .LNK_CLK_IN         (txclk_from_phy),
        .LNK_DAT_OUT        (lnk_dat_from_dptx)
    );

// Displayport RX
    prt_dprx_top
    #(
        // System
        .P_VENDOR           (P_VENDOR),   // Vendor
        .P_BEAT             (P_BEAT),     // Beat value. The system clock is 50 MHz
        .P_SDP              (P_SDP),      // SDP support

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
        .SYS_CLK_IN         (sys_clk_from_pll),

        // Host
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
        .LNK_CLK_IN         (rxclk_from_phy),        // Clock
        .LNK_DAT_IN         (lnk_dat_to_dprx),      // Data
        .LNK_SYNC_OUT       (lnk_sync_from_dprx),   // Sync
        .LNK_VBID_OUT       (),
        
        // Video
        .VID_CLK_IN         (clk_from_vid_bufg),    // Clock
        .VID_RDY_IN         (1'b1),                 // Ready
        .VID_SOF_OUT        (vid_sof_from_dprx),    // Start of frame
        .VID_EOL_OUT        (vid_eol_from_dprx),    // End of line
        .VID_DAT_OUT        (vid_dat_from_dprx),    // Data
        .VID_VLD_OUT        (vid_vld_from_dprx),    // Valid

        // Secondary Data Packet
        .SDP_CLK_IN         (sys_clk_from_pll),    // Clock
        .SDP_SOP_OUT        (sdp_sop_from_dprx),    // Start of packet
        .SDP_EOP_OUT        (sdp_eop_from_dprx),    // End of packet
        .SDP_DAT_OUT        (sdp_dat_from_dprx),    // Data
        .SDP_VLD_OUT        (sdp_vld_from_dprx)     // Valid
    );

    // Map data

generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_dprx_lnk_dat_4spl

        always_ff @ (posedge rxclk_from_phy)
        begin
            // Tentiva DP2.1 RX card
            if (rx_card_from_app)
            begin
                //  GT lane 2 -> DP lane 0
                {lnk_dat_to_dprx[(3*9)+:8], lnk_dat_to_dprx[(2*9)+:8], lnk_dat_to_dprx[(1*9)+:8], lnk_dat_to_dprx[(0*9)+:8]} <= gtwiz_userdata_rx_from_phy[(2*32)+:32]; 
                lnk_dat_to_dprx[(0*9)+8] <= rxctrl0_from_phy[(2*16)+0];
                lnk_dat_to_dprx[(1*9)+8] <= rxctrl0_from_phy[(2*16)+1];
                lnk_dat_to_dprx[(2*9)+8] <= rxctrl0_from_phy[(2*16)+2];
                lnk_dat_to_dprx[(3*9)+8] <= rxctrl0_from_phy[(2*16)+3];

                // GT lane 1 -> DP lane 1
                {lnk_dat_to_dprx[(7*9)+:8], lnk_dat_to_dprx[(6*9)+:8], lnk_dat_to_dprx[(5*9)+:8], lnk_dat_to_dprx[(4*9)+:8]} <= gtwiz_userdata_rx_from_phy[(1*32)+:32]; 
                lnk_dat_to_dprx[(4*9)+8] <= rxctrl0_from_phy[(1*16)+0];
                lnk_dat_to_dprx[(5*9)+8] <= rxctrl0_from_phy[(1*16)+1];
                lnk_dat_to_dprx[(6*9)+8] <= rxctrl0_from_phy[(1*16)+2];
                lnk_dat_to_dprx[(7*9)+8] <= rxctrl0_from_phy[(1*16)+3];

                // GT lane 3 -> DP lane 2
                {lnk_dat_to_dprx[(11*9)+:8], lnk_dat_to_dprx[(10*9)+:8], lnk_dat_to_dprx[(9*9)+:8], lnk_dat_to_dprx[(8*9)+:8]} <= gtwiz_userdata_rx_from_phy[(3*32)+:32];  
                lnk_dat_to_dprx[(8*9)+8]  <= rxctrl0_from_phy[(3*16)+0];
                lnk_dat_to_dprx[(9*9)+8]  <= rxctrl0_from_phy[(3*16)+1];
                lnk_dat_to_dprx[(10*9)+8] <= rxctrl0_from_phy[(3*16)+2];
                lnk_dat_to_dprx[(11*9)+8] <= rxctrl0_from_phy[(3*16)+3];

                // GT lane 0 -> DP lane 3
                {lnk_dat_to_dprx[(15*9)+:8], lnk_dat_to_dprx[(14*9)+:8], lnk_dat_to_dprx[(13*9)+:8], lnk_dat_to_dprx[(12*9)+:8]} <= gtwiz_userdata_rx_from_phy[(0*32)+:32]; 
                lnk_dat_to_dprx[(12*9)+8] <= rxctrl0_from_phy[(0*16)+0];
                lnk_dat_to_dprx[(13*9)+8] <= rxctrl0_from_phy[(0*16)+1];
                lnk_dat_to_dprx[(14*9)+8] <= rxctrl0_from_phy[(0*16)+2];
                lnk_dat_to_dprx[(15*9)+8] <= rxctrl0_from_phy[(0*16)+3];
            end

            // Tentiva DP1.4 RX card
            else
            begin
                // GT lane 0 -> DP lane 0
                {lnk_dat_to_dprx[(3*9)+:8], lnk_dat_to_dprx[(2*9)+:8], lnk_dat_to_dprx[(1*9)+:8], lnk_dat_to_dprx[(0*9)+:8]} <= gtwiz_userdata_rx_from_phy[(0*32)+:32]; 
                lnk_dat_to_dprx[(0*9)+8] <= rxctrl0_from_phy[(0*16)+0];
                lnk_dat_to_dprx[(1*9)+8] <= rxctrl0_from_phy[(0*16)+1];
                lnk_dat_to_dprx[(2*9)+8] <= rxctrl0_from_phy[(0*16)+2];
                lnk_dat_to_dprx[(3*9)+8] <= rxctrl0_from_phy[(0*16)+3];

                // GT lane 3 -> DP lane 1
                {lnk_dat_to_dprx[(7*9)+:8], lnk_dat_to_dprx[(6*9)+:8], lnk_dat_to_dprx[(5*9)+:8], lnk_dat_to_dprx[(4*9)+:8]} <= gtwiz_userdata_rx_from_phy[(3*32)+:32]; 
                lnk_dat_to_dprx[(4*9)+8] <= rxctrl0_from_phy[(3*16)+0];
                lnk_dat_to_dprx[(5*9)+8] <= rxctrl0_from_phy[(3*16)+1];
                lnk_dat_to_dprx[(6*9)+8] <= rxctrl0_from_phy[(3*16)+2];
                lnk_dat_to_dprx[(7*9)+8] <= rxctrl0_from_phy[(3*16)+3];

                // GT lane 2 -> DP lane 2
                {lnk_dat_to_dprx[(11*9)+:8], lnk_dat_to_dprx[(10*9)+:8], lnk_dat_to_dprx[(9*9)+:8], lnk_dat_to_dprx[(8*9)+:8]} <= gtwiz_userdata_rx_from_phy[(2*32)+:32];  
                lnk_dat_to_dprx[(8*9)+8]  <= rxctrl0_from_phy[(2*16)+0];
                lnk_dat_to_dprx[(9*9)+8]  <= rxctrl0_from_phy[(2*16)+1];
                lnk_dat_to_dprx[(10*9)+8] <= rxctrl0_from_phy[(2*16)+2];
                lnk_dat_to_dprx[(11*9)+8] <= rxctrl0_from_phy[(2*16)+3];

                // GT lane 1 -> DP lane 3 
                {lnk_dat_to_dprx[(15*9)+:8], lnk_dat_to_dprx[(14*9)+:8], lnk_dat_to_dprx[(13*9)+:8], lnk_dat_to_dprx[(12*9)+:8]} <= gtwiz_userdata_rx_from_phy[(1*32)+:32]; 
                lnk_dat_to_dprx[(12*9)+8] <= rxctrl0_from_phy[(1*16)+0];
                lnk_dat_to_dprx[(13*9)+8] <= rxctrl0_from_phy[(1*16)+1];
                lnk_dat_to_dprx[(14*9)+8] <= rxctrl0_from_phy[(1*16)+2];
                lnk_dat_to_dprx[(15*9)+8] <= rxctrl0_from_phy[(1*16)+3];
            end
        end
    end

    // Two symbols per lane
    else
    begin : gen_dprx_lnk_dat_2spl

        always_ff @ (posedge rxclk_from_phy)
        begin
            // Tentiva DP2.1 RX card
            if (rx_card_from_app)
            begin
                // GT lane 2 -> DP lane 0    
                {lnk_dat_to_dprx[(1*9)+:8], lnk_dat_to_dprx[(0*9)+:8]} <= gtwiz_userdata_rx_from_phy[(2*16)+:16]; 
                lnk_dat_to_dprx[(0*9)+8] <= rxctrl0_from_phy[(2*16)+0];
                lnk_dat_to_dprx[(1*9)+8] <= rxctrl0_from_phy[(2*16)+1];

                // GT lane 1 -> DP lane 1 
                {lnk_dat_to_dprx[(3*9)+:8], lnk_dat_to_dprx[(2*9)+:8]} <= gtwiz_userdata_rx_from_phy[(1*16)+:16]; 
                lnk_dat_to_dprx[(2*9)+8] <= rxctrl0_from_phy[(1*16)+0];
                lnk_dat_to_dprx[(3*9)+8] <= rxctrl0_from_phy[(1*16)+1];

                // GT lane 3 -> DP lane 2 
                {lnk_dat_to_dprx[(5*9)+:8], lnk_dat_to_dprx[(4*9)+:8]} <= gtwiz_userdata_rx_from_phy[(3*16)+:16];  
                lnk_dat_to_dprx[(4*9)+8] <= rxctrl0_from_phy[(3*16)+0];
                lnk_dat_to_dprx[(5*9)+8] <= rxctrl0_from_phy[(3*16)+1];

                // GT lane 0 -> DP lane 3
                {lnk_dat_to_dprx[(7*9)+:8], lnk_dat_to_dprx[(6*9)+:8]} <= gtwiz_userdata_rx_from_phy[(0*16)+:16]; 
                lnk_dat_to_dprx[(6*9)+8] <= rxctrl0_from_phy[(0*16)+0];
                lnk_dat_to_dprx[(7*9)+8] <= rxctrl0_from_phy[(0*16)+1];
            end

            else
            begin
                // Tentiva DPRX 1.4 board (MCDP6150) 
                // GT lane 0 -> DP lane 0    
                {lnk_dat_to_dprx[(1*9)+:8], lnk_dat_to_dprx[(0*9)+:8]} <= gtwiz_userdata_rx_from_phy[(0*16)+:16]; 
                lnk_dat_to_dprx[(0*9)+8] <= rxctrl0_from_phy[(0*16)+0];
                lnk_dat_to_dprx[(1*9)+8] <= rxctrl0_from_phy[(0*16)+1];

                // GT lane 3 -> DP lane 1 
                {lnk_dat_to_dprx[(3*9)+:8], lnk_dat_to_dprx[(2*9)+:8]} <= gtwiz_userdata_rx_from_phy[(3*16)+:16]; 
                lnk_dat_to_dprx[(2*9)+8] <= rxctrl0_from_phy[(3*16)+0];
                lnk_dat_to_dprx[(3*9)+8] <= rxctrl0_from_phy[(3*16)+1];

                // GT lane 2 -> DP lane 2 
                {lnk_dat_to_dprx[(5*9)+:8], lnk_dat_to_dprx[(4*9)+:8]} <= gtwiz_userdata_rx_from_phy[(2*16)+:16];  
                lnk_dat_to_dprx[(4*9)+8] <= rxctrl0_from_phy[(2*16)+0];
                lnk_dat_to_dprx[(5*9)+8] <= rxctrl0_from_phy[(2*16)+1];

                // GT lane 1 -> DP lane 3
                {lnk_dat_to_dprx[(7*9)+:8], lnk_dat_to_dprx[(6*9)+:8]} <= gtwiz_userdata_rx_from_phy[(1*16)+:16]; 
                lnk_dat_to_dprx[(6*9)+8] <= rxctrl0_from_phy[(1*16)+0];
                lnk_dat_to_dprx[(7*9)+8] <= rxctrl0_from_phy[(1*16)+1];
            end
        end
    end
endgenerate

// Video toolbox (stream 0)
    prt_vtb_top
    #(
        .P_VENDOR               (P_VENDOR),     // Vendor
        .P_SYS_FREQ             (P_SYS_FREQ),   // System frequency
        .P_PPC                  (P_PPC),        // Pixels per clock
        .P_BPC                  (P_BPC),        // Bits per component
        .P_AXIS_DAT             (P_AXI_WIDTH),  // AXIS data width
        .P_OVL                  (P_VTB_OVL)     // Overlay (0 - disable / 1 - Image 1 / 2 - Image 2)
    )
    VTB_INST
    (
        // System
        .SYS_RST_IN             (dptx_rst_from_app),
        .SYS_CLK_IN             (sys_clk_from_pll),

        // Local bus
        .LB_IF                  (vtb_if[0]),

        // Direct I2C Access
        .DIA_RDY_IN             (dia_rdy_from_app),
        .DIA_DAT_OUT            (dia_dat_from_vtb),
        .DIA_VLD_OUT            (dia_vld_from_vtb),

        // Link
        .TX_LNK_CLK_IN          (txclk_from_phy),        // TX link clock
        .RX_LNK_CLK_IN          (rxclk_from_phy),        // RX link clock
        .LNK_SYNC_IN            (lnk_sync_from_dprx),
        
        // Axi-stream Video
        .AXIS_SOF_IN            (vid_sof_from_dprx),      // Start of frame
        .AXIS_EOL_IN            (vid_eol_from_dprx),      // End of line
        .AXIS_DAT_IN            (vid_dat_from_dprx),      // Data
        .AXIS_VLD_IN            (vid_vld_from_dprx),      // Valid       

        // Native video
        .VID_CLK_IN             (clk_from_vid_bufg),
        .VID_CKE_IN             (1'b1),
        .VID_LOCK_OUT           (lock_from_vtb[0]),
        .VID_VS_OUT             (vs_from_vtb[0]),
        .VID_HS_OUT             (hs_from_vtb[0]),
        .VID_R_OUT              (r_from_vtb[0]),
        .VID_G_OUT              (g_from_vtb[0]),
        .VID_B_OUT              (b_from_vtb[0]),
        .VID_DE_OUT             (de_from_vtb[0])
    );

// Video toolbox (stream 1)
generate
    if (P_MST)
    begin : gen_vtb1
        prt_vtb_top
        #(
            .P_VENDOR               (P_VENDOR),     // Vendor
            .P_SYS_FREQ             (P_SYS_FREQ),   // System frequency
            .P_PPC                  (P_PPC),        // Pixels per clock
            .P_BPC                  (P_BPC),        // Bits per component
            .P_AXIS_DAT             (P_AXI_WIDTH),  // AXIS data width
            .P_OVL                  (2)             // Overlay (0 - disable / 1 - Image 1 / 2 - Image 2)
        )
        VTB1_INST
        (
            // System
            .SYS_RST_IN             (dptx_rst_from_app),
            .SYS_CLK_IN             (sys_clk_from_pll),

            // Local bus
            .LB_IF                  (vtb_if[1]),

            // Direct I2C Access
            .DIA_RDY_IN             (),
            .DIA_DAT_OUT            (),
            .DIA_VLD_OUT            (),

            // Link
            .TX_LNK_CLK_IN          (txclk_from_phy),     // TX link clock
            .RX_LNK_CLK_IN          (rxclk_from_phy),     // RX link clock
            .LNK_SYNC_IN            (1'b0),

            // Axi-stream Video
            .AXIS_SOF_IN            (1'b0),      // Start of frame
            .AXIS_EOL_IN            (1'b0),      // End of line
            .AXIS_DAT_IN            (96'h0),      // Data
            .AXIS_VLD_IN            (1'b0),      // Valid       

            // Native video
            .VID_CLK_IN             (clk_from_vid_bufg),
            .VID_CKE_IN             (1'b1),
            .VID_LOCK_OUT           (lock_from_vtb[1]),
            .VID_VS_OUT             (vs_from_vtb[1]),
            .VID_HS_OUT             (hs_from_vtb[1]),
            .VID_R_OUT              (r_from_vtb[1]),
            .VID_G_OUT              (g_from_vtb[1]),
            .VID_B_OUT              (b_from_vtb[1]),
            .VID_DE_OUT             (de_from_vtb[1])
        );
    end

    else
    begin : gen_no_vtb1
        assign lock_from_vtb[1] = 0;
        assign vs_from_vtb[1] = 0;
        assign hs_from_vtb[1] = 0;
        assign r_from_vtb[1] = 0;
        assign g_from_vtb[1] = 0;
        assign b_from_vtb[1] = 0;
        assign de_from_vtb[1] = 0;
    end
endgenerate

// PHY controller
    prt_phy_ctl_amd
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
        .SYS_RST_IN         (clk_rst),              // Reset
        .SYS_CLK_IN         (sys_clk_from_pll),    // Clock 

        // Local bus interface
        .LB_IF              (phy_if),

        // DRP
        .DRP_CLK_IN         (drp_clk_from_pll),
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

    // PIO in mapping
    assign pio_dat_to_phy_ctl[0]            = &pwrgd_from_phy;
    assign pio_dat_to_phy_ctl[1]            = tx_rst_done_from_phy;
    assign pio_dat_to_phy_ctl[2]            = rx_rst_done_from_phy;

    // PIO out mapping
    assign tx_pll_and_dp_rst_from_phy_ctl   = pio_dat_from_phy_ctl[0];
    assign tx_dp_rst_from_phy_ctl           = pio_dat_from_phy_ctl[1];
    assign rx_pll_and_dp_rst_from_phy_ctl   = pio_dat_from_phy_ctl[2];
    assign rx_dp_rst_from_phy_ctl           = pio_dat_from_phy_ctl[3];
    assign tx_linerate_from_phy_ctl         = pio_dat_from_phy_ctl[4+:2];
    assign tx_diffctrl_from_phy_ctl         = pio_dat_from_phy_ctl[6+:5];
    assign tx_postcursor_from_phy_ctl       = pio_dat_from_phy_ctl[11+:5];

// PHY
generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : phy_4spl
        zcu102_gth_4spl
        PHY_INST
        (
            // High speed serial
            .gthrxp_in                                  (GT_RX_IN_P),
            .gthrxn_in                                  (GT_RX_IN_N),
            .gthtxp_out                                 (GT_TX_OUT_P),
            .gthtxn_out                                 (GT_TX_OUT_N),

            // Free running clock
            // Xilinx Ultrascale transceiver wizard PG182 tells on page 10,
            // that for the GTHE4 Ultrascale+, when the CPLL is used, 
            // the free running clock and the DRP clock are coupled. 
            .gtwiz_reset_clk_freerun_in                 (drp_clk_from_pll), 

            // Resets
            .gtpowergood_out                            (pwrgd_from_phy),
            .gtwiz_reset_all_in                         (1'b0),
            .gtwiz_reset_tx_pll_and_datapath_in         (tx_pll_and_dp_rst_from_phy_ctl),
            .gtwiz_reset_tx_datapath_in                 (tx_dp_rst_from_phy_ctl),
            .gtwiz_reset_rx_pll_and_datapath_in         (rx_pll_and_dp_rst_from_phy_ctl),
            .gtwiz_reset_rx_datapath_in                 (rx_dp_rst_from_phy_ctl),
            .gtwiz_reset_rx_cdr_stable_out              (),
            .gtwiz_reset_tx_done_out                    (tx_rst_done_from_phy),
            .gtwiz_reset_rx_done_out                    (rx_rst_done_from_phy),
 
            .rxpmaresetdone_out                         (),
            .txpmaresetdone_out                         (),

            // CPLL
            .gtrefclk0_in                               ({4{clk_from_phy_ibuf[0]}}),     // GT reference clock 0

            // CPLL calibration
            // See Xilinx PG182 - Enabling CPLL calibration block for UltraScale+ Devices
            // To enable the CPLL calibration ports type the following command in the TCL console
            // set_property -dict [list CONFIG.INCLUDE_CPLL_CAL {1} ] [get_ips zcu102_gth_2spl]
            .gtwiz_gthe4_cpll_cal_txoutclk_period_in    ({4{cpll_cal_txoutclk_period_to_phy}}),
            .gtwiz_gthe4_cpll_cal_cnt_tol_in            ({4{cpll_cal_cnt_tol_to_phy}}),
            .gtwiz_gthe4_cpll_cal_bufg_ce_in            (4'b1111),

            // QPLL
            .gtrefclk00_in                              (clk_from_phy_ibuf[1]),          // GT reference clock 1
            .qpll0outclk_out                            (),
            .qpll0outrefclk_out                         (),

            // User clocks       
            .gtwiz_userclk_tx_reset_in                  (1'b0),
            .gtwiz_userclk_tx_srcclk_out                (),
            .gtwiz_userclk_tx_usrclk_out                (),
            .gtwiz_userclk_tx_usrclk2_out               (txclk_from_phy),
            .gtwiz_userclk_tx_active_out                (),
  
            .gtwiz_userclk_rx_reset_in                  (1'b0),
            .gtwiz_userclk_rx_srcclk_out                (),
            .gtwiz_userclk_rx_usrclk_out                (),
            .gtwiz_userclk_rx_usrclk2_out               (rxclk_from_phy),
            .gtwiz_userclk_rx_active_out                (),

            // TX control
            .txdiffctrl_in                              ({4{tx_diffctrl_from_phy_ctl}}),
            .txpostcursor_in                            ({4{tx_postcursor_from_phy_ctl}}),

            // TX datapath
            .gtwiz_userdata_tx_in                       (gtwiz_userdata_tx_to_phy), // 64 bits
            .txctrl0_in                                 (txctrl0_to_phy),
            .txctrl1_in                                 (txctrl1_to_phy),
            .txctrl2_in                                 (txctrl2_to_phy),
            .tx8b10ben_in                               (4'b1111),
            .txpolarity_in                              (txpolarity_to_phy),  
          
            // RX control
            .rxpolarity_in                              (rxpolarity_to_phy),     

            // RX datapath
            .gtwiz_userdata_rx_out                      (gtwiz_userdata_rx_from_phy), // 64 bits
            .rxctrl0_out                                (rxctrl0_from_phy), // 64 bits
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

            // DRP
            .drpclk_in                                  ({4{drp_clk_from_pll}}),
            .drpaddr_in                                 (drp_adr_from_phy_ctl[0+:(4*10)]),
            .drpdi_in                                   (drp_dat_from_phy_ctl[0+:(4*16)]),
            .drpen_in                                   (drp_en_from_phy_ctl[3:0]),
            .drpwe_in                                   (drp_wr_from_phy_ctl[3:0]),
            .drpdo_out                                  (drp_dat_from_phy[0+:(4*16)]),
            .drprdy_out                                 (drp_rdy_from_phy[3:0]),

            .drpclk_common_in                           (drp_clk_from_pll),
            .drpaddr_common_in                          ({6'h0, drp_adr_from_phy_ctl[(4*10)+:10]}),
            .drpdi_common_in                            (drp_dat_from_phy_ctl[(4*16)+:16]),
            .drpen_common_in                            (drp_en_from_phy_ctl[4]),
            .drpwe_common_in                            (drp_wr_from_phy_ctl[4]),
            .drpdo_common_out                           (drp_dat_from_phy[(4*16)+:16]),
            .drprdy_common_out                          (drp_rdy_from_phy[4])
        );
    end

    // Two symbols per lane
    else 
    begin : phy_2spl

        zcu102_gth_2spl
        PHY_INST
        (
            // High speed serial
            .gthrxp_in                                  (GT_RX_IN_P),
            .gthrxn_in                                  (GT_RX_IN_N),
            .gthtxp_out                                 (GT_TX_OUT_P),
            .gthtxn_out                                 (GT_TX_OUT_N),

            // Free running clock
            // Xilinx Ultrascale transceiver wizard PG182 tells on page 10,
            // that for the GTHE4 Ultrascale+, when the CPLL is used, 
            // the free running clock and the DRP clock are coupled. 
            .gtwiz_reset_clk_freerun_in                 (drp_clk_from_pll), 

            // Resets
            .gtpowergood_out                            (pwrgd_from_phy),
            .gtwiz_reset_all_in                         (1'b0),
            .gtwiz_reset_tx_pll_and_datapath_in         (tx_pll_and_dp_rst_from_phy_ctl),
            .gtwiz_reset_tx_datapath_in                 (tx_dp_rst_from_phy_ctl),
            .gtwiz_reset_rx_pll_and_datapath_in         (rx_pll_and_dp_rst_from_phy_ctl),
            .gtwiz_reset_rx_datapath_in                 (rx_dp_rst_from_phy_ctl),
            .gtwiz_reset_rx_cdr_stable_out              (),
            .gtwiz_reset_tx_done_out                    (tx_rst_done_from_phy),
            .gtwiz_reset_rx_done_out                    (rx_rst_done_from_phy),
 
            .rxpmaresetdone_out                         (),
            .txpmaresetdone_out                         (),

            // CPLL
            .gtrefclk0_in                               ({4{clk_from_phy_ibuf[0]}}),     // GT reference clock 0

            // CPLL calibration
            // See Xilinx PG182 - Enabling CPLL calibration block for UltraScale+ Devices
            // To enable the CPLL calibration ports type the following command in the TCL console
            // set_property -dict [list CONFIG.INCLUDE_CPLL_CAL {1} ] [get_ips zcu102_gth_2spl]
            .gtwiz_gthe4_cpll_cal_txoutclk_period_in    ({4{cpll_cal_txoutclk_period_to_phy}}),
            .gtwiz_gthe4_cpll_cal_cnt_tol_in            ({4{cpll_cal_cnt_tol_to_phy}}),
            .gtwiz_gthe4_cpll_cal_bufg_ce_in            (4'b1111),

            // QPLL
            .gtrefclk00_in                              (clk_from_phy_ibuf[1]),          // GT reference clock 1
            .qpll0outclk_out                            (),
            .qpll0outrefclk_out                         (),

            // User clocks       
            .gtwiz_userclk_tx_reset_in                  (1'b0),
            .gtwiz_userclk_tx_srcclk_out                (),
            .gtwiz_userclk_tx_usrclk_out                (),
            .gtwiz_userclk_tx_usrclk2_out               (txclk_from_phy),
            .gtwiz_userclk_tx_active_out                (),
  
            .gtwiz_userclk_rx_reset_in                  (1'b0),
            .gtwiz_userclk_rx_srcclk_out                (),
            .gtwiz_userclk_rx_usrclk_out                (),
            .gtwiz_userclk_rx_usrclk2_out               (rxclk_from_phy),
            .gtwiz_userclk_rx_active_out                (),

            // TX control
            .txdiffctrl_in                              ({4{tx_diffctrl_from_phy_ctl}}),
            .txpostcursor_in                            ({4{tx_postcursor_from_phy_ctl}}),

            // TX datapath
            .gtwiz_userdata_tx_in                       (gtwiz_userdata_tx_to_phy), // 64 bits
            .txctrl0_in                                 (txctrl0_to_phy),
            .txctrl1_in                                 (txctrl1_to_phy),
            .txctrl2_in                                 (txctrl2_to_phy),
            .tx8b10ben_in                               (4'b1111),
            .txpolarity_in                              (txpolarity_to_phy),  
          
            // RX control
            .rxpolarity_in                              (rxpolarity_to_phy),     

            // RX datapath
            .gtwiz_userdata_rx_out                      (gtwiz_userdata_rx_from_phy), // 64 bits
            .rxctrl0_out                                (rxctrl0_from_phy), // 64 bits
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

            // DRP
            .drpclk_in                                  ({4{drp_clk_from_pll}}),
            .drpaddr_in                                 (drp_adr_from_phy_ctl[0+:(4*10)]),
            .drpdi_in                                   (drp_dat_from_phy_ctl[0+:(4*16)]),
            .drpen_in                                   (drp_en_from_phy_ctl[3:0]),
            .drpwe_in                                   (drp_wr_from_phy_ctl[3:0]),
            .drpdo_out                                  (drp_dat_from_phy[0+:(4*16)]),
            .drprdy_out                                 (drp_rdy_from_phy[3:0]),

            .drpclk_common_in                           (drp_clk_from_pll),
            .drpaddr_common_in                          ({6'h0, drp_adr_from_phy_ctl[(4*10)+:10]}),
            .drpdi_common_in                            (drp_dat_from_phy_ctl[(4*16)+:16]),
            .drpen_common_in                            (drp_en_from_phy_ctl[4]),
            .drpwe_common_in                            (drp_wr_from_phy_ctl[4]),
            .drpdo_common_out                           (drp_dat_from_phy[(4*16)+:16]),
            .drprdy_common_out                          (drp_rdy_from_phy[4])
        );
    end
endgenerate

// TX polarity select
    always_ff @ (posedge txclk_from_phy)
    begin
        // Tentiva DP2.1 TX card
        if (tx_card_from_app)
            txpolarity_to_phy <= 4'b0000; // All lanes have possitive polarity
        
        // Tentiva DP1.4 TX card
        else
            txpolarity_to_phy <= 4'b1001; // Lanes 0 & 3 are inverted,
    end

// RX polarity select
    always_ff @ (posedge rxclk_from_phy)
    begin
        // Tentiva DP2.1 RX card
        if (rx_card_from_app)
            rxpolarity_to_phy <= 4'b0000; // All lanes have possitive polarity
        
        // Tentiva DP1.4 RX card
        else
            rxpolarity_to_phy <= 4'b1111; // All lanes are inverted,
    end


/*
    CPLL calibration block
    See Xilinx PG182 
    Enabling CPLL calibration block for UltraScale+ Devices
    Refere to AMD answer record AR# 70485 for information how to enable the CPLL calibration signals
*/
    always_ff @ (posedge drp_clk_from_pll)
    begin
        dclk_gt_linerate_cap    <= tx_linerate_from_phy_ctl;
        dclk_gt_linerate        <= dclk_gt_linerate_cap;
        
        case (dclk_gt_linerate)

            // 2.7 Gbps
            'd1 : 
            begin
                cpll_cal_txoutclk_period_to_phy = 'd10800;
                cpll_cal_cnt_tol_to_phy = 'd108;
            end

            // 5.4 Gbps
            'd2 : 
            begin
                cpll_cal_txoutclk_period_to_phy = 'd10800;
                cpll_cal_cnt_tol_to_phy = 'd108;
            end

            // 8.1 Gbps
            'd3 : 
            begin
                cpll_cal_txoutclk_period_to_phy = 'd16200;
                cpll_cal_cnt_tol_to_phy = 'd162;
            end

            // 1.62 Gbps
            default : 
            begin
                cpll_cal_txoutclk_period_to_phy = 'd12960;
                cpll_cal_cnt_tol_to_phy = 'd130;
            end
        endcase
    end

/*
    PHY TX data
*/

generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_phy_tx_dat_4spl
        always_ff @ (posedge txclk_from_phy)
        begin
            // Tentiva DP2.1 TX card
            if (tx_card_from_app)
            begin
                // GT lane 0 -> DP lane 3
                gtwiz_userdata_tx_to_phy[(0*32)+:32]  <= {lnk_dat_from_dptx[(15*11)+:8], lnk_dat_from_dptx[(14*11)+:8], lnk_dat_from_dptx[(13*11)+:8], lnk_dat_from_dptx[(12*11)+:8]};         // TX data
                txctrl2_to_phy[(0*8)+:8]              <= {4'h0,  lnk_dat_from_dptx[(15*11)+8],  lnk_dat_from_dptx[(14*11)+8],  lnk_dat_from_dptx[(13*11)+8],  lnk_dat_from_dptx[(12*11)+8]};     // K character
                txctrl0_to_phy[(0*16)+:16]            <= {12'h0, lnk_dat_from_dptx[(15*11)+9],  lnk_dat_from_dptx[(14*11)+9],  lnk_dat_from_dptx[(13*11)+9],  lnk_dat_from_dptx[(12*11)+9]};    // Disparity value (0-negative / 1-positive)
                txctrl1_to_phy[(0*16)+:16]            <= {12'h0, lnk_dat_from_dptx[(15*11)+10], lnk_dat_from_dptx[(14*11)+10], lnk_dat_from_dptx[(13*11)+10], lnk_dat_from_dptx[(12*11)+10]};  // Disparity control (0-automatic / 1-force)

                // GT lane 1 -> DP lane 1
                gtwiz_userdata_tx_to_phy[(1*32)+:32]  <= {lnk_dat_from_dptx[(7*11)+:8], lnk_dat_from_dptx[(6*11)+:8], lnk_dat_from_dptx[(5*11)+:8], lnk_dat_from_dptx[(4*11)+:8]};         // TX data
                txctrl2_to_phy[(1*8)+:8]              <= {4'h0,  lnk_dat_from_dptx[(7*11)+8],  lnk_dat_from_dptx[(6*11)+8],  lnk_dat_from_dptx[(5*11)+8],  lnk_dat_from_dptx[(4*11)+8]};     // K character
                txctrl0_to_phy[(1*16)+:16]            <= {12'h0, lnk_dat_from_dptx[(7*11)+9],  lnk_dat_from_dptx[(6*11)+9],  lnk_dat_from_dptx[(5*11)+9],  lnk_dat_from_dptx[(4*11)+9]};    // Disparity value (0-negative / 1-positive)
                txctrl1_to_phy[(1*16)+:16]            <= {12'h0, lnk_dat_from_dptx[(7*11)+10], lnk_dat_from_dptx[(6*11)+10], lnk_dat_from_dptx[(5*11)+10], lnk_dat_from_dptx[(4*11)+10]};  // Disparity control (0-automatic / 1-force)

                // GT lane 2 -> DP lane 0 
                gtwiz_userdata_tx_to_phy[(2*32)+:32]  <= {lnk_dat_from_dptx[(3*11)+:8], lnk_dat_from_dptx[(2*11)+:8], lnk_dat_from_dptx[(1*11)+:8], lnk_dat_from_dptx[(0*11)+:8]};         // TX data
                txctrl2_to_phy[(2*8)+:8]              <= {4'h0,  lnk_dat_from_dptx[(3*11)+8],  lnk_dat_from_dptx[(2*11)+8],  lnk_dat_from_dptx[(1*11)+8],  lnk_dat_from_dptx[(0*11)+8]};     // K character
                txctrl0_to_phy[(2*16)+:16]            <= {12'h0, lnk_dat_from_dptx[(3*11)+9],  lnk_dat_from_dptx[(2*11)+9],  lnk_dat_from_dptx[(1*11)+9],  lnk_dat_from_dptx[(0*11)+9]};    // Disparity value (0-negative / 1-positive)
                txctrl1_to_phy[(2*16)+:16]            <= {12'h0, lnk_dat_from_dptx[(3*11)+10], lnk_dat_from_dptx[(2*11)+10], lnk_dat_from_dptx[(1*11)+10], lnk_dat_from_dptx[(0*11)+10]};  // Disparity control (0-automatic / 1-force)

                // GT lane 3 -> DP lane 2
                gtwiz_userdata_tx_to_phy[(3*32)+:32]  <= {lnk_dat_from_dptx[(11*11)+:8], lnk_dat_from_dptx[(10*11)+:8], lnk_dat_from_dptx[(9*11)+:8], lnk_dat_from_dptx[(8*11)+:8]};         // TX data
                txctrl2_to_phy[(3*8)+:8]              <= {4'h0,  lnk_dat_from_dptx[(11*11)+8],  lnk_dat_from_dptx[(10*11)+8],  lnk_dat_from_dptx[(9*11)+8],  lnk_dat_from_dptx[(8*11)+8]};     // K character
                txctrl0_to_phy[(3*16)+:16]            <= {12'h0, lnk_dat_from_dptx[(11*11)+9],  lnk_dat_from_dptx[(10*11)+9],  lnk_dat_from_dptx[(9*11)+9],  lnk_dat_from_dptx[(8*11)+9]};    // Disparity value (0-negative / 1-positive)
                txctrl1_to_phy[(3*16)+:16]            <= {12'h0, lnk_dat_from_dptx[(11*11)+10], lnk_dat_from_dptx[(10*11)+10], lnk_dat_from_dptx[(9*11)+10], lnk_dat_from_dptx[(8*11)+10]};  // Disparity control (0-automatic / 1-force)
            end

            // Tentiva DP1.4 TX card
            else
            begin
                // GT lane 0 -> DP lane 3
                gtwiz_userdata_tx_to_phy[(0*32)+:32]  <= {lnk_dat_from_dptx[(15*11)+:8], lnk_dat_from_dptx[(14*11)+:8], lnk_dat_from_dptx[(13*11)+:8], lnk_dat_from_dptx[(12*11)+:8]};         // TX data
                txctrl2_to_phy[(0*8)+:8]              <= {4'h0,  lnk_dat_from_dptx[(15*11)+8],  lnk_dat_from_dptx[(14*11)+8],  lnk_dat_from_dptx[(13*11)+8],  lnk_dat_from_dptx[(12*11)+8]};     // K character
                txctrl0_to_phy[(0*16)+:16]            <= {12'h0, lnk_dat_from_dptx[(15*11)+9],  lnk_dat_from_dptx[(14*11)+9],  lnk_dat_from_dptx[(13*11)+9],  lnk_dat_from_dptx[(12*11)+9]};    // Disparity value (0-negative / 1-positive)
                txctrl1_to_phy[(0*16)+:16]            <= {12'h0, lnk_dat_from_dptx[(15*11)+10], lnk_dat_from_dptx[(14*11)+10], lnk_dat_from_dptx[(13*11)+10], lnk_dat_from_dptx[(12*11)+10]};  // Disparity control (0-automatic / 1-force)

                // GT lane 1 -> DP lane 0 
                gtwiz_userdata_tx_to_phy[(1*32)+:32]  <= {lnk_dat_from_dptx[(3*11)+:8], lnk_dat_from_dptx[(2*11)+:8], lnk_dat_from_dptx[(1*11)+:8], lnk_dat_from_dptx[(0*11)+:8]};         // TX data
                txctrl2_to_phy[(1*8)+:8]              <= {4'h0,  lnk_dat_from_dptx[(3*11)+8],  lnk_dat_from_dptx[(2*11)+8],  lnk_dat_from_dptx[(1*11)+8],  lnk_dat_from_dptx[(0*11)+8]};     // K character
                txctrl0_to_phy[(1*16)+:16]            <= {12'h0, lnk_dat_from_dptx[(3*11)+9],  lnk_dat_from_dptx[(2*11)+9],  lnk_dat_from_dptx[(1*11)+9],  lnk_dat_from_dptx[(0*11)+9]};    // Disparity value (0-negative / 1-positive)
                txctrl1_to_phy[(1*16)+:16]            <= {12'h0, lnk_dat_from_dptx[(3*11)+10], lnk_dat_from_dptx[(2*11)+10], lnk_dat_from_dptx[(1*11)+10], lnk_dat_from_dptx[(0*11)+10]};  // Disparity control (0-automatic / 1-force)

                // GT lane 2 -> DP lane 1
                gtwiz_userdata_tx_to_phy[(2*32)+:32]  <= {lnk_dat_from_dptx[(7*11)+:8], lnk_dat_from_dptx[(6*11)+:8], lnk_dat_from_dptx[(5*11)+:8], lnk_dat_from_dptx[(4*11)+:8]};         // TX data
                txctrl2_to_phy[(2*8)+:8]              <= {4'h0,  lnk_dat_from_dptx[(7*11)+8],  lnk_dat_from_dptx[(6*11)+8],  lnk_dat_from_dptx[(5*11)+8],  lnk_dat_from_dptx[(4*11)+8]};     // K character
                txctrl0_to_phy[(2*16)+:16]            <= {12'h0, lnk_dat_from_dptx[(7*11)+9],  lnk_dat_from_dptx[(6*11)+9],  lnk_dat_from_dptx[(5*11)+9],  lnk_dat_from_dptx[(4*11)+9]};    // Disparity value (0-negative / 1-positive)
                txctrl1_to_phy[(2*16)+:16]            <= {12'h0, lnk_dat_from_dptx[(7*11)+10], lnk_dat_from_dptx[(6*11)+10], lnk_dat_from_dptx[(5*11)+10], lnk_dat_from_dptx[(4*11)+10]};  // Disparity control (0-automatic / 1-force)

                // GT lane 3 -> DP lane 2
                gtwiz_userdata_tx_to_phy[(3*32)+:32]  <= {lnk_dat_from_dptx[(11*11)+:8], lnk_dat_from_dptx[(10*11)+:8], lnk_dat_from_dptx[(9*11)+:8], lnk_dat_from_dptx[(8*11)+:8]};         // TX data
                txctrl2_to_phy[(3*8)+:8]              <= {4'h0,  lnk_dat_from_dptx[(11*11)+8],  lnk_dat_from_dptx[(10*11)+8],  lnk_dat_from_dptx[(9*11)+8],  lnk_dat_from_dptx[(8*11)+8]};     // K character
                txctrl0_to_phy[(3*16)+:16]            <= {12'h0, lnk_dat_from_dptx[(11*11)+9],  lnk_dat_from_dptx[(10*11)+9],  lnk_dat_from_dptx[(9*11)+9],  lnk_dat_from_dptx[(8*11)+9]};    // Disparity value (0-negative / 1-positive)
                txctrl1_to_phy[(3*16)+:16]            <= {12'h0, lnk_dat_from_dptx[(11*11)+10], lnk_dat_from_dptx[(10*11)+10], lnk_dat_from_dptx[(9*11)+10], lnk_dat_from_dptx[(8*11)+10]};  // Disparity control (0-automatic / 1-force)
            end
        end
    end

    // Two symbols per lane
    else
    begin : gen_phy_tx_dat_2spl
        always_ff @ (posedge txclk_from_phy)
        begin
            // Tentiva DP2.1 TX card
            if (tx_card_from_app)
            begin
                // GT lane 0 -> DP lane 3
                gtwiz_userdata_tx_to_phy[(0*16)+:16]  <= {lnk_dat_from_dptx[(7*11)+:8], lnk_dat_from_dptx[(6*11)+:8]};         // TX data
                txctrl2_to_phy[(0*8)+:8]              <= {6'h0, lnk_dat_from_dptx[(7*11)+8], lnk_dat_from_dptx[(6*11)+8]};     // K character
                txctrl0_to_phy[(0*16)+:16]            <= {14'h0, lnk_dat_from_dptx[(7*11)+9], lnk_dat_from_dptx[(6*11)+9]};    // Disparity value (0-negative / 1-positive)
                txctrl1_to_phy[(0*16)+:16]            <= {14'h0, lnk_dat_from_dptx[(7*11)+10], lnk_dat_from_dptx[(6*11)+10]};  // Disparity control (0-automatic / 1-force)

                // GT lane 1 -> DP lane 1
                gtwiz_userdata_tx_to_phy[(1*16)+:16]  <= {lnk_dat_from_dptx[(3*11)+:8], lnk_dat_from_dptx[(2*11)+:8]};         // TX data
                txctrl2_to_phy[(1*8)+:8]              <= {6'h0, lnk_dat_from_dptx[(3*11)+8], lnk_dat_from_dptx[(2*11)+8]};     // K character
                txctrl0_to_phy[(1*16)+:16]            <= {14'h0, lnk_dat_from_dptx[(3*11)+9], lnk_dat_from_dptx[(2*11)+9]};    // Disparity value (0-negative / 1-positive)
                txctrl1_to_phy[(1*16)+:16]            <= {14'h0, lnk_dat_from_dptx[(3*11)+10], lnk_dat_from_dptx[(2*11)+10]};  // Disparity control (0-automatic / 1-force)

                // GT lane 2 -> DP lane 0 
                gtwiz_userdata_tx_to_phy[(2*16)+:16]  <= {lnk_dat_from_dptx[(1*11)+:8], lnk_dat_from_dptx[(0*11)+:8]};         // TX data
                txctrl2_to_phy[(2*8)+:8]              <= {6'h0, lnk_dat_from_dptx[(1*11)+8], lnk_dat_from_dptx[(0*11)+8]};     // K character
                txctrl0_to_phy[(2*16)+:16]            <= {14'h0, lnk_dat_from_dptx[(1*11)+9], lnk_dat_from_dptx[(0*11)+9]};    // Disparity value (0-negative / 1-positive)
                txctrl1_to_phy[(2*16)+:16]            <= {14'h0, lnk_dat_from_dptx[(1*11)+10], lnk_dat_from_dptx[(0*11)+10]};  // Disparity control (0-automatic / 1-force)

                // GT lane 3 -> DP lane 2
                gtwiz_userdata_tx_to_phy[(3*16)+:16]  <= {lnk_dat_from_dptx[(5*11)+:8], lnk_dat_from_dptx[(4*11)+:8]};         // TX data
                txctrl2_to_phy[(3*8)+:8]              <= {6'h0, lnk_dat_from_dptx[(5*11)+8], lnk_dat_from_dptx[(4*11)+8]};     // K character
                txctrl0_to_phy[(3*16)+:16]            <= {14'h0, lnk_dat_from_dptx[(5*11)+9], lnk_dat_from_dptx[(4*11)+9]};    // Disparity value (0-negative / 1-positive)
                txctrl1_to_phy[(3*16)+:16]            <= {14'h0, lnk_dat_from_dptx[(5*11)+10], lnk_dat_from_dptx[(4*11)+10]};  // Disparity control (0-automatic / 1-force)
            end

            // Tentiva DP1.4 TX card
            else
            begin
                // GT lane 0 -> DP lane 3
                gtwiz_userdata_tx_to_phy[(0*16)+:16]  <= {lnk_dat_from_dptx[(7*11)+:8], lnk_dat_from_dptx[(6*11)+:8]};         // TX data
                txctrl2_to_phy[(0*8)+:8]              <= {6'h0, lnk_dat_from_dptx[(7*11)+8], lnk_dat_from_dptx[(6*11)+8]};     // K character
                txctrl0_to_phy[(0*16)+:16]            <= {14'h0, lnk_dat_from_dptx[(7*11)+9], lnk_dat_from_dptx[(6*11)+9]};    // Disparity value (0-negative / 1-positive)
                txctrl1_to_phy[(0*16)+:16]            <= {14'h0, lnk_dat_from_dptx[(7*11)+10], lnk_dat_from_dptx[(6*11)+10]};  // Disparity control (0-automatic / 1-force)

                // GT lane 1 -> DP lane 0 
                gtwiz_userdata_tx_to_phy[(1*16)+:16]  <= {lnk_dat_from_dptx[(1*11)+:8], lnk_dat_from_dptx[(0*11)+:8]};         // TX data
                txctrl2_to_phy[(1*8)+:8]              <= {6'h0, lnk_dat_from_dptx[(1*11)+8], lnk_dat_from_dptx[(0*11)+8]};     // K character
                txctrl0_to_phy[(1*16)+:16]            <= {14'h0, lnk_dat_from_dptx[(1*11)+9], lnk_dat_from_dptx[(0*11)+9]};    // Disparity value (0-negative / 1-positive)
                txctrl1_to_phy[(1*16)+:16]            <= {14'h0, lnk_dat_from_dptx[(1*11)+10], lnk_dat_from_dptx[(0*11)+10]};  // Disparity control (0-automatic / 1-force)

                // GT lane 2 -> DP lane 1
                gtwiz_userdata_tx_to_phy[(2*16)+:16]  <= {lnk_dat_from_dptx[(3*11)+:8], lnk_dat_from_dptx[(2*11)+:8]};         // TX data
                txctrl2_to_phy[(2*8)+:8]              <= {6'h0, lnk_dat_from_dptx[(3*11)+8], lnk_dat_from_dptx[(2*11)+8]};     // K character
                txctrl0_to_phy[(2*16)+:16]            <= {14'h0, lnk_dat_from_dptx[(3*11)+9], lnk_dat_from_dptx[(2*11)+9]};    // Disparity value (0-negative / 1-positive)
                txctrl1_to_phy[(2*16)+:16]            <= {14'h0, lnk_dat_from_dptx[(3*11)+10], lnk_dat_from_dptx[(2*11)+10]};  // Disparity control (0-automatic / 1-force)

                // GT lane 3 -> DP lane 2
                gtwiz_userdata_tx_to_phy[(3*16)+:16]  <= {lnk_dat_from_dptx[(5*11)+:8], lnk_dat_from_dptx[(4*11)+:8]};         // TX data
                txctrl2_to_phy[(3*8)+:8]              <= {6'h0, lnk_dat_from_dptx[(5*11)+8], lnk_dat_from_dptx[(4*11)+8]};     // K character
                txctrl0_to_phy[(3*16)+:16]            <= {14'h0, lnk_dat_from_dptx[(5*11)+9], lnk_dat_from_dptx[(4*11)+9]};    // Disparity value (0-negative / 1-positive)
                txctrl1_to_phy[(3*16)+:16]            <= {14'h0, lnk_dat_from_dptx[(5*11)+10], lnk_dat_from_dptx[(4*11)+10]};  // Disparity control (0-automatic / 1-force)
            end
        end
    end
endgenerate

// System clock heartbeat
    prt_hb
    #(
        .P_BEAT ('d75_000_000)
    )
    SYS_HB_INST
    (
        .CLK_IN     (sys_clk_from_pll),
        .LED_OUT    (led_from_sys_hb)
    );

// Video clock heartbeat
    prt_hb
    #(
        .P_BEAT ('d150_000_000)
    )
    VID_HB_INST
    (
        .CLK_IN     (clk_from_vid_bufg),
        .LED_OUT    (led_from_vid_hb)
    );

// GT clock heartbeat
    prt_hb
    #(
        .P_BEAT ('d67_500_000)
    )
    GTTX_HB_INST
    (
        .CLK_IN     (clk_from_phy_bufg[0]),
        .LED_OUT    (led_from_phy_hb)
    );

// Outputs
    assign LED_OUT[0]   = led_from_sys_hb;
    assign LED_OUT[1]   = led_from_vid_hb;
    assign LED_OUT[2]   = led_from_phy_hb;
    assign LED_OUT[3]   = hb_from_dptx;
    assign LED_OUT[4]   = hb_from_dprx;
    assign LED_OUT[5]   = tx_card_from_app; 
    assign LED_OUT[6]   = rx_card_from_app; 
    assign LED_OUT[7]   = DPRX_CABDET_IN; 
    assign DPTX_I2C_SEL_OUT = 1;    // Only for DP21 TX card. Select FMC I2C interface
    assign DPRX_I2C_SEL_OUT = 1;    // Only for DP21 RX card. Select FMC I2C interface
   
endmodule

`default_nettype wire
