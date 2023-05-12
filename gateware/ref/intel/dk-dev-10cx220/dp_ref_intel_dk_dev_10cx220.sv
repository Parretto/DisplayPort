/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP reference design running on Intel Cyclone 10GX
    (c) 2021 - 2023 by Parretto B.V.

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

module dp_ref_intel_dk_dev_10cx220
(
    // Clock
    input wire              CLK_IN,                     // 50 MHz

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
    input wire              TENTIVA_VID_CLK_IN,         // Video clock 

    // DP TX
    output wire             DPTX_AUX_EN_OUT,            // AUX Enable
    output wire             DPTX_AUX_TX_OUT,            // AUX Transmit
    input wire              DPTX_AUX_RX_IN,             // AUX Receive
    input wire              DPTX_HPD_IN,                // HPD

    // DP RX
    output wire             DPRX_AUX_EN_OUT,            // AUX Enable
    output wire             DPRX_AUX_TX_OUT,            // AUX Transmit
    input wire              DPRX_AUX_RX_IN,             // AUX Receive
    output wire             DPRX_HPD_OUT,               // HPD

    // PHY
    input wire              PHY_REFCLK_IN,              // PHY Reference clock
    input wire [3:0]        PHY_RX_IN,                  // PHY Receive
    output wire [3:0]       PHY_TX_OUT,                 // PHY Transmit

    // Misc
    output wire [3:0]       LED_OUT
);

// Parameters
localparam P_VENDOR         = "intel";
localparam P_SYS_FREQ       = 50_000_000;      // System frequency - 50 MHz
localparam P_BEAT           = P_SYS_FREQ / 1_000_000;   // Beat value. 
localparam P_REF_VER_MAJOR  = 1;     // Reference design version major
localparam P_REF_VER_MINOR  = 0;     // Reference design minor
localparam P_PIO_IN_WIDTH   = 7;
localparam P_PIO_OUT_WIDTH  = 8;

localparam P_LANES          = 4;
localparam P_DATA_MODE      = "dual";                               // Data path mode; dual - 2 pixels per clock / 2 symbols per lane / quad - 4 pixels per clock / 4 symbols per lane
localparam P_SPL            = (P_DATA_MODE == "dual") ? 2 : 4;      // Symbols per lane. Valid options - 2, 4. 
localparam P_PPC            = (P_DATA_MODE == "dual") ? 2 : 4;      // Pixels per clock. Valid options - 2, 4.
localparam P_BPC            = 8;                                    // Bits per component. Valid option - 8
localparam P_AXI_WIDTH      = (P_DATA_MODE == "dual") ? 48 : 96;
localparam P_PHY_DAT_WIDTH  = P_LANES * P_SPL * 8;
localparam P_PHY_TX_MST_CLK = 0;    // PHY TX master clock
localparam P_PHY_RX_MST_CLK = 0;    // PHY RX master clock
localparam P_APP_ROM_INIT   = "dp_app_int_rom.mif";
localparam P_APP_RAM_INIT   = "dp_app_int_ram.mif";
localparam P_MST            = 0;
localparam P_RCFG_PORTS     = 5;

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
wire                            clk_from_sys_pll;
wire                            lock_from_sys_pll;
wire                            clk_from_vid_bufg;
//wire                            clk_from_ref_bufg;

// Reset
(* preserve *) logic [7:0]      clk_por_line = 0;
(* preserve *) wire             clk_por;
(* preserve *) logic [9:0]      clk_rst_cnt;
(* preserve *) logic            clk_rst;

// PIO
wire [P_PIO_IN_WIDTH-1:0]       pio_dat_to_app;
wire [P_PIO_OUT_WIDTH-1:0]      pio_dat_from_app;

wire                            dptx_rst_from_app;
wire                            dprx_rst_from_app;

// PHY PLL
wire                            pwrdwn_to_phy_pll;
wire                            tx_clk_from_phy_pll;
wire                            locked_from_phy_pll;
wire                            cal_busy_from_phy_pll;
wire [31:0]                     rcfg_dat_from_phy_pll;
wire                            rcfg_wait_from_phy_pll;

// PHY
wire                            tx_arst_to_phy;
wire                            tx_drst_to_phy;
wire                            rx_arst_to_phy;
wire                            rx_drst_to_phy;
wire [3:0]                      tx_clk_from_phy;
wire [3:0]                      rx_clk_from_phy;
wire [63:0]                     tx_dat_to_phy;
wire [7:0]                      tx_datk_to_phy;
wire [7:0]                      tx_disp_ctl_to_phy;
wire [7:0]                      tx_disp_val_to_phy;
wire [3:0]                      tx_cal_busy_from_phy;
wire [3:0]                      rx_cal_busy_from_phy;
wire [3:0]                      rx_cdr_lock_from_phy;

wire [63:0]                     rx_dat_from_phy;
wire [7:0]                      rx_datk_from_phy;

wire [(4 * 32)-1:0]             rcfg_dat_from_phy;
wire [3:0] 	                    rcfg_wait_from_phy;

// DPTX
wire [(P_LANES*P_SPL*11)-1:0]   lnk_dat_from_dptx;
wire                            irq_from_dptx;
wire                            hb_from_dptx;

// DPRX
wire [(P_LANES*P_SPL*9)-1:0]    lnk_dat_to_dprx;
wire                            irq_from_dprx;
wire                            hb_from_dprx;
wire                            lnk_sync_from_dprx;
wire                            vid_sof_from_dprx;   // Start of frame
wire                            vid_eol_from_dprx;   // End of line
wire [P_AXI_WIDTH-1:0]          vid_dat_from_dprx;   // Data
wire                            vid_vld_from_dprx;   // Valid

// VTB
wire                            lock_from_vtb;
wire                            vs_from_vtb;
wire                            hs_from_vtb;
wire [(P_PPC*P_BPC)-1:0]        r_from_vtb;
wire [(P_PPC*P_BPC)-1:0]        g_from_vtb;
wire [(P_PPC*P_BPC)-1:0]        b_from_vtb;
wire                            de_from_vtb;

// DIA
wire                            dia_rdy_from_app;
wire [31:0]                     dia_dat_from_vtb;
wire                            dia_vld_from_vtb;

// Reconfig
wire [(P_RCFG_PORTS * 10)-1:0]	adr_from_rcfg;
wire [P_RCFG_PORTS-1:0]		    wr_from_rcfg;
wire [P_RCFG_PORTS-1:0]		    rd_from_rcfg;
wire [(P_RCFG_PORTS * 32)-1:0]  dat_from_rcfg;
wire [(P_RCFG_PORTS * 32)-1:0]  dat_to_rcfg;
wire [P_RCFG_PORTS-1:0] 	    wait_to_rcfg;

// Heartbeat
wire                            led_from_sys_hb;
wire                            led_from_vid_hb;
wire                            led_from_gt_hb;

genvar i;

// Logic

// Power on reset
    always_ff @ (posedge CLK_IN)
    begin
        clk_por_line <= {clk_por_line[$size(clk_por_line)-2:0], 1'b1};            
    end

    assign clk_por = ~clk_por_line[$size(clk_por_line)-1];

// System PLL
// This PLL generates the 50 MHz system clock
    sys_pll 
    SYS_PLL_INST
    (
        .rst        (clk_por),
        .refclk     (CLK_IN),  
        .locked     (lock_from_sys_pll),  
        .outclk_0   (clk_from_sys_pll)
    );

// Reset generator
    always_ff @ (negedge lock_from_sys_pll, posedge clk_from_sys_pll)
    begin
        if (!lock_from_sys_pll)
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

// Video buffer
    global 
    VID_BUFG
    (
        .in     (TENTIVA_VID_CLK_IN), 
        .out    (clk_from_vid_bufg)
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
        .P_ROM_INIT         (P_APP_ROM_INIT),
        .P_RAM_INIT         (P_APP_RAM_INIT),
        .P_AQUA             (0)
    )
    APP_INST
    (
         // Reset and clock
        .RST_IN             (clk_rst),    
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
    assign pio_dat_to_app[0]            = TENTIVA_GT_CLK_LOCK_IN; 
    assign pio_dat_to_app[1]            = TENTIVA_VID_CLK_LOCK_IN;
    assign pio_dat_to_app[2]            = cal_busy_from_phy_pll;
    assign pio_dat_to_app[3]            = locked_from_phy_pll;
    assign pio_dat_to_app[4]            = |tx_cal_busy_from_phy;
    assign pio_dat_to_app[5]            = |rx_cal_busy_from_phy;
    assign pio_dat_to_app[6]            = &rx_cdr_lock_from_phy;

    // PIO out mapping
    assign TENTIVA_CLK_SEL_OUT          = pio_dat_from_app[0];
    assign dptx_rst_from_app            = pio_dat_from_app[1];
    assign dprx_rst_from_app            = pio_dat_from_app[2];
    assign pwrdwn_to_phy_pll            = pio_dat_from_app[3];
    assign tx_arst_to_phy               = pio_dat_from_app[4];
    assign tx_drst_to_phy               = pio_dat_from_app[5];
    assign rx_arst_to_phy               = pio_dat_from_app[6];
    assign rx_drst_to_phy               = pio_dat_from_app[7];

// Displayport TX
    prt_dptx_top
    #(
        // System
        .P_VENDOR           (P_VENDOR),     // Vendor
        .P_BEAT             (P_BEAT),       // Beat value. The system clock is 100 MHz
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
        .SYS_CLK_IN         (clk_from_sys_pll),

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

        // Video
        // Video stream 0
        .VID0_CLK_IN        (clk_from_vid_bufg),
        .VID0_CKE_IN        (1'b1),
        .VID0_VS_IN         (vs_from_vtb),              // Vsync
        .VID0_HS_IN         (hs_from_vtb),              // Hsync
        .VID0_R_IN          (r_from_vtb),               // Red
        .VID0_G_IN          (g_from_vtb),               // Green
        .VID0_B_IN          (b_from_vtb),               // Blue
        .VID0_DE_IN         (de_from_vtb),              // Data enable

        // Video stream 1
        .VID1_CLK_IN        (clk_from_vid_bufg),
        .VID1_CKE_IN        (1'b1),
        .VID1_VS_IN         (1'b0),                     // Vsync
        .VID1_HS_IN         (1'b0),                     // Hsync
        .VID1_R_IN          (0),                        // Red
        .VID1_G_IN          (0),                        // Green
        .VID1_B_IN          (0),                        // Blue
        .VID1_DE_IN         (1'b0),                     // Data enable

        // Link
        .LNK_CLK_IN         (tx_clk_from_phy[P_PHY_TX_MST_CLK]),
        .LNK_DAT_OUT        (lnk_dat_from_dptx)
    );

// TX mapping
// PHY lane 0 -> DP lane 1
    assign tx_dat_to_phy[(0*16)+:16]    = {lnk_dat_from_dptx[(3*11)+:8], lnk_dat_from_dptx[(2*11)+:8]};     // TX data
    assign tx_datk_to_phy[(0*2)+:2]     = {lnk_dat_from_dptx[(3*11)+8], lnk_dat_from_dptx[(2*11)+8]};       // K character
    assign tx_disp_val_to_phy[(0*2)+:2] = {lnk_dat_from_dptx[(3*11)+9], lnk_dat_from_dptx[(2*11)+9]};       // Disparity value (0-negative / 1-positive)
    assign tx_disp_ctl_to_phy[(0*2)+:2] = {lnk_dat_from_dptx[(3*11)+10], lnk_dat_from_dptx[(2*11)+10]};     // Disparity control (0-automatic / 1-force)

// PHY lane 1 -> DP lane 0
    assign tx_dat_to_phy[(1*16)+:16]    = {lnk_dat_from_dptx[(1*11)+:8], lnk_dat_from_dptx[(0*11)+:8]};     // TX data
    assign tx_datk_to_phy[(1*2)+:2]     = {lnk_dat_from_dptx[(1*11)+8], lnk_dat_from_dptx[(0*11)+8]};       // K character
    assign tx_disp_val_to_phy[(1*2)+:2] = {lnk_dat_from_dptx[(1*11)+9], lnk_dat_from_dptx[(0*11)+9]};       // Disparity value (0-negative / 1-positive)
    assign tx_disp_ctl_to_phy[(1*2)+:2] = {lnk_dat_from_dptx[(1*11)+10], lnk_dat_from_dptx[(0*11)+10]};     // Disparity control (0-automatic / 1-force)

// PHY lane 2 -> DP lane 2
    assign tx_dat_to_phy[(2*16)+:16]    = {lnk_dat_from_dptx[(5*11)+:8], lnk_dat_from_dptx[(4*11)+:8]};     // TX data
    assign tx_datk_to_phy[(2*2)+:2]     = {lnk_dat_from_dptx[(5*11)+8], lnk_dat_from_dptx[(4*11)+8]};       // K character
    assign tx_disp_val_to_phy[(2*2)+:2] = {lnk_dat_from_dptx[(5*11)+9], lnk_dat_from_dptx[(4*11)+9]};       // Disparity value (0-negative / 1-positive)
    assign tx_disp_ctl_to_phy[(2*2)+:2] = {lnk_dat_from_dptx[(5*11)+10], lnk_dat_from_dptx[(4*11)+10]};     // Disparity control (0-automatic / 1-force)

// PHY lane 3 -> DP lane 3
    assign tx_dat_to_phy[(3*16)+:16]    = {lnk_dat_from_dptx[(7*11)+:8], lnk_dat_from_dptx[(6*11)+:8]};     // TX data
    assign tx_datk_to_phy[(3*2)+:2]     = {lnk_dat_from_dptx[(7*11)+8], lnk_dat_from_dptx[(6*11)+8]};       // K character
    assign tx_disp_val_to_phy[(3*2)+:2] = {lnk_dat_from_dptx[(7*11)+9], lnk_dat_from_dptx[(6*11)+9]};       // Disparity value (0-negative / 1-positive)
    assign tx_disp_ctl_to_phy[(3*2)+:2] = {lnk_dat_from_dptx[(7*11)+10], lnk_dat_from_dptx[(6*11)+10]};     // Disparity control (0-automatic / 1-force)

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
        .LNK_CLK_IN         (rx_clk_from_phy[P_PHY_RX_MST_CLK]),        // Clock
        .LNK_DAT_IN         (lnk_dat_to_dprx),      // Data
        .LNK_SYNC_OUT       (lnk_sync_from_dprx),   // Sync

        // Video
        .VID_CLK_IN         (clk_from_vid_bufg),    // Clock
        .VID_RDY_IN         (1'b1),                 // Ready
        .VID_SOF_OUT        (vid_sof_from_dprx),    // Start of frame
        .VID_EOL_OUT        (vid_eol_from_dprx),    // End of line
        .VID_DAT_OUT        (vid_dat_from_dprx),    // Data
        .VID_VLD_OUT        (vid_vld_from_dprx)     // Valid
    );

    // Map data

    // PHY lane 0 -> DP lane 2 
    assign {lnk_dat_to_dprx[(5*9)+:8], lnk_dat_to_dprx[(4*9)+:8]} = rx_dat_from_phy[(0*16)+:16]; 
    assign lnk_dat_to_dprx[(4*9)+8] = rx_datk_from_phy[(0*2)+0];
    assign lnk_dat_to_dprx[(5*9)+8] = rx_datk_from_phy[(0*2)+1];

    // PHY lane 1 -> DP lane 3 
    assign {lnk_dat_to_dprx[(7*9)+:8], lnk_dat_to_dprx[(6*9)+:8]} = rx_dat_from_phy[(1*16)+:16]; 
    assign lnk_dat_to_dprx[(6*9)+8] = rx_datk_from_phy[(1*2)+0];
    assign lnk_dat_to_dprx[(7*9)+8] = rx_datk_from_phy[(1*2)+1];

    // PHY lane 2 -> DP lane 1 
    assign {lnk_dat_to_dprx[(3*9)+:8], lnk_dat_to_dprx[(2*9)+:8]} = rx_dat_from_phy[(2*16)+:16];  
    assign lnk_dat_to_dprx[(2*9)+8] = rx_datk_from_phy[(2*2)+0];
    assign lnk_dat_to_dprx[(3*9)+8] = rx_datk_from_phy[(2*2)+1];

    // PHY lane 3 -> DP lane 0 
    assign {lnk_dat_to_dprx[(1*9)+:8], lnk_dat_to_dprx[(0*9)+:8]} = rx_dat_from_phy[(3*16)+:16]; 
    assign lnk_dat_to_dprx[(0*9)+8] = rx_datk_from_phy[(3*2)+0];
    assign lnk_dat_to_dprx[(1*9)+8] = rx_datk_from_phy[(3*2)+1];

// Video toolbox
    prt_vtb_top
    #(
        .P_VENDOR               (P_VENDOR),     // Vendor
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
        .LB_IF                  (vtb_if[0]),

        // Direct I2C Access
        .DIA_RDY_IN             (dia_rdy_from_app),
        .DIA_DAT_OUT            (dia_dat_from_vtb),
        .DIA_VLD_OUT            (dia_vld_from_vtb),

        // Link
        .TX_LNK_CLK_IN          (tx_clk_from_phy[P_PHY_TX_MST_CLK]),        // TX link clock
        .RX_LNK_CLK_IN          (rx_clk_from_phy[P_PHY_TX_MST_CLK]),        // RX link clock
        .LNK_SYNC_IN            (lnk_sync_from_dprx),
        
        // Axi-stream Video
        .AXIS_SOF_IN            (vid_sof_from_dprx),      // Start of frame
        .AXIS_EOL_IN            (vid_eol_from_dprx),      // End of line
        .AXIS_DAT_IN            (vid_dat_from_dprx),      // Data
        .AXIS_VLD_IN            (vid_vld_from_dprx),      // Valid       

        // Native video
        .VID_CLK_IN             (clk_from_vid_bufg),
        .VID_CKE_IN             (1'b1),
        .VID_LOCK_OUT           (lock_from_vtb),
        .VID_VS_OUT             (vs_from_vtb),
        .VID_HS_OUT             (hs_from_vtb),
        .VID_R_OUT              (r_from_vtb),
        .VID_G_OUT              (g_from_vtb),
        .VID_B_OUT              (b_from_vtb),
        .VID_DE_OUT             (de_from_vtb)
    );

// Reconfig Bridge
    prt_int_rcfg
    #(
        .P_RCFG_PORTS       (P_RCFG_PORTS),
        .P_RCFG_ADR         (10),
        .P_RCFG_DAT         (32)
    )
    RCFG_INST
    (
        // Reset and clock
        .RST_IN             (clk_rst),		        // Reset
        .CLK_IN             (clk_from_sys_pll),		// Clock

        // Local bus interface
       	.LB_IF              (phy_if),

        // Reconfig
        .RCFG_ADR_OUT       (adr_from_rcfg),	// Address
        .RCFG_WR_OUT        (wr_from_rcfg),		// Write
        .RCFG_RD_OUT        (rd_from_rcfg),		// Read
        .RCFG_DAT_OUT       (dat_from_rcfg),	// Write data
        .RCFG_DAT_IN        (dat_to_rcfg),	    // Read data
        .RCFG_WAIT_IN	    (wait_to_rcfg)	    // Wait request
    );

    assign dat_to_rcfg = {rcfg_dat_from_phy, rcfg_dat_from_phy_pll};
    assign wait_to_rcfg = {rcfg_wait_from_phy, rcfg_wait_from_phy_pll};

/*
    PHY TX data
*/

/*
    PHY PLL
    This PLL generates the TX PHY clock
*/
    phy_pll 
    PHY_PLL_INST
    (
        .pll_powerdown              (pwrdwn_to_phy_pll), 
        .pll_refclk0                (PHY_REFCLK_IN),   // clk_from_ref_bufg
        .tx_serial_clk              (tx_clk_from_phy_pll),
        .pll_locked                 (locked_from_phy_pll),    
        .pll_cal_busy               (cal_busy_from_phy_pll),

        // Reconfig
		.reconfig_reset0            (clk_rst),             
		.reconfig_clk0              (clk_from_sys_pll),    
		.reconfig_write0            (wr_from_rcfg[0]),      
		.reconfig_read0             (rd_from_rcfg[0]),       
		.reconfig_address0          (adr_from_rcfg[0 +: 10]), 
		.reconfig_writedata0        (dat_from_rcfg[0 +: 32]), 
		.reconfig_readdata0         (rcfg_dat_from_phy_pll),  
		.reconfig_waitrequest0      (rcfg_wait_from_phy_pll)  
    );

    phy 
    PHY_INST
    (
        // TX
        .tx_analogreset             ({4{tx_arst_to_phy}}), 
        .tx_digitalreset            ({4{tx_drst_to_phy}}), 
        .tx_cal_busy                (tx_cal_busy_from_phy),
        .tx_serial_clk0             ({4{tx_clk_from_phy_pll}}),   
        .tx_serial_data             (PHY_TX_OUT),
        .tx_coreclkin               ({4{tx_clk_from_phy[P_PHY_TX_MST_CLK]}}), 
        .tx_clkout                  (tx_clk_from_phy),     
        .tx_parallel_data           (tx_dat_to_phy), 
        .tx_datak                   (tx_datk_to_phy),     
        .tx_forcedisp               (tx_disp_ctl_to_phy),
        .tx_dispval                 (tx_disp_val_to_phy), 
        .unused_tx_parallel_data    (424'h0), 
        .tx_polinv                  (4'b1100),                  // DP lanes 2 and 3 are inverted

        // RX
        .rx_analogreset             ({4{rx_arst_to_phy}}), 
        .rx_digitalreset            ({4{rx_drst_to_phy}}),
        .rx_cal_busy                (rx_cal_busy_from_phy),
        .rx_is_lockedtodata         (rx_cdr_lock_from_phy),
        .rx_cdr_refclk0             (PHY_REFCLK_IN),
        .rx_serial_data             (PHY_RX_IN), 
        .rx_coreclkin               ({4{rx_clk_from_phy[P_PHY_RX_MST_CLK]}}), 
        .rx_clkout                  (rx_clk_from_phy),     
        .rx_parallel_data           (rx_dat_from_phy),
        .rx_datak                   (rx_datk_from_phy),
        .rx_errdetect               (),
        .rx_disperr                 (),
        .rx_runningdisp             (),
        .unused_rx_parallel_data    (),
        .rx_polinv                  (4'b1111),              // All DP lanes are inverted

        // Reconfig
		.reconfig_reset             ({4{clk_rst}}),    
		.reconfig_clk               ({4{clk_from_sys_pll}}), 
		.reconfig_write             (wr_from_rcfg[4:1]),     
		.reconfig_read              (rd_from_rcfg[4:1]),     
		.reconfig_address           (adr_from_rcfg[1*10 +: 4*10]),  
		.reconfig_writedata         (dat_from_rcfg[1*32 +: 4*32]),  
		.reconfig_readdata          (rcfg_dat_from_phy),      
		.reconfig_waitrequest       (rcfg_wait_from_phy)      
    );

// System clock heartbeat
    prt_hb
    #(
        .P_BEAT ('d75_000_000)
    )
    SYS_HB_INST
    (
        .CLK_IN     (clk_from_sys_pll),
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

// Outputs
    assign LED_OUT[0]   = led_from_sys_hb;
    assign LED_OUT[1]   = led_from_vid_hb;
    assign LED_OUT[2]   = hb_from_dptx;
    assign LED_OUT[3]   = hb_from_dprx;
  
endmodule

`default_nettype wire
