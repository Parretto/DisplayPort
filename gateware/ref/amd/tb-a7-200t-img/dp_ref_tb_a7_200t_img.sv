/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP reference design running on Inrevium TB-A7-200T-IMG
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

module dp_ref_tb_a7_200t_img
(
    // Clock
    input wire              CLK_IN_P,               // 200 MHz
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

    // DP RX
    output wire             DPRX_AUX_EN_OUT,            // AUX Enable
    output wire             DPRX_AUX_TX_OUT,            // AUX Transmit
    input wire              DPRX_AUX_RX_IN,             // AUX Receive
    output wire             DPRX_HPD_OUT,               // HPD

    // GT
    input wire [1:0]        GT_REFCLK_IN_P,             // GT reference clock
    input wire [1:0]        GT_REFCLK_IN_N,
    input wire [3:0]        GT_RX_IN_P,                 // GT receive
    input wire [3:0]        GT_RX_IN_N,
    output wire [3:0]       GT_TX_OUT_P,                // GT transmit
    output wire [3:0]       GT_TX_OUT_N,

    // Misc
    output wire [3:0]       LED_OUT
);

// Parameters
localparam P_VENDOR         = "xilinx";
localparam P_SYS_FREQ       = 50_000_000;      // System frequency - 50 MHz
localparam P_BEAT           = P_SYS_FREQ / 1_000_000;   // Beat value. 
localparam P_REF_VER_MAJOR  = 1;     // Reference design version major
localparam P_REF_VER_MINOR  = 0;     // Reference design minor
localparam P_PIO_IN_WIDTH   = 8;
localparam P_PIO_OUT_WIDTH  = 22;

localparam P_LANES          = 4;
localparam P_DATA_MODE      = "quad";                               // Data path mode; dual - 2 pixels per clock / 2 symbols per lane / quad - 4 pixels per clock / 4 symbols per lane
localparam P_SPL            = (P_DATA_MODE == "dual") ? 2 : 4;      // Symbols per lane. Valid options - 2, 4. 
localparam P_PPC            = (P_DATA_MODE == "dual") ? 2 : 4;      // Pixels per clock. Valid options - 2, 4.
localparam P_BPC            = 8;                                    // Bits per component. Valid option - 8
localparam P_AXI_WIDTH      = (P_DATA_MODE == "dual") ? 48 : 96;
localparam P_PHY_DAT_WIDTH  = P_LANES * P_SPL * 8;
localparam P_APP_ROM_INIT   = "dp_app_xlx_rom.mem";
localparam P_APP_RAM_INIT   = "dp_app_xlx_ram.mem";

localparam P_DRP_PORTS      = 7;

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
wire                            clk_from_sys_ibuf;
wire                            sys_clk_from_pll;
wire                            clk_from_vid_ibuf;
wire                            clk_from_vid_bufg;
wire                            clk_from_gt_ibuf;

// Reset
(* dont_touch = "yes" *) logic [7:0]    clk_por_line = 0;
(* dont_touch = "yes" *) wire           clk_por;
(* dont_touch = "yes" *) logic [9:0]    clk_rst_cnt;
(* dont_touch = "yes" *) logic          clk_rst;

// PIO
wire [P_PIO_IN_WIDTH-1:0]       pio_dat_to_app;
wire [P_PIO_OUT_WIDTH-1:0]      pio_dat_from_app;

wire                            dptx_rst_from_app;
wire                            dprx_rst_from_app;
wire                            phy_gttx_rst_from_app;
wire                            phy_gtrx_rst_from_app;
wire                            phy_txpll_rst_from_app;
wire                            phy_rxpll_rst_from_app;
wire [3:0]                      phy_tx_diffctrl_from_app;
wire [4:0]                      phy_tx_postcursor_from_app;
wire [2:0]                      phy_tx_rate_from_app;
wire [2:0]                      phy_rx_rate_from_app;

// PHY
wire                            gt_refclk_from_phy;
wire                            tx_rst_done_from_phy;
wire                            rx_rst_done_from_phy;
wire                            txclk_from_phy;
wire                            rxclk_from_phy;
wire [1:0]                      gtpll_lock_from_phy;
wire                            txpll_lock_from_phy;
wire                            rxpll_lock_from_phy;

wire [P_PHY_DAT_WIDTH-1:0]      txdat_to_phy;
wire [(P_PHY_DAT_WIDTH/8)-1:0]  txdatk_to_phy;
wire [(P_PHY_DAT_WIDTH/8)-1:0]  txdispmode_to_phy;
wire [(P_PHY_DAT_WIDTH/8)-1:0]  txdispval_to_phy;

wire [P_PHY_DAT_WIDTH-1:0]      rxdat_from_phy;
wire [(P_PHY_DAT_WIDTH/8)-1:0]  rxdatk_from_phy;

wire [(P_DRP_PORTS * 16)-1:0]   drp_dat_from_phy;
wire [P_DRP_PORTS-1:0]          drp_rdy_from_phy;

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

// DRP
wire [(P_DRP_PORTS * 9)-1:0]    adr_from_drp;
wire [(P_DRP_PORTS * 16)-1:0]   dat_from_drp;
wire [P_DRP_PORTS-1:0]          en_from_drp;
wire [P_DRP_PORTS-1:0]          wr_from_drp;

// Heartbeat
wire                            led_from_sys_hb;
wire                            led_from_vid_hb;
wire                            led_from_gt_hb;

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
    BUFG 
    VID_BUFG_INST 
    (
      .I    (clk_from_vid_ibuf),    // 1-bit input: Clock input.
      .O    (clk_from_vid_bufg)     // 1-bit output: Clock output.
    );

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
    assign pio_dat_to_app[0]            = TENTIVA_GT_CLK_LOCK_IN; 
    assign pio_dat_to_app[1]            = TENTIVA_VID_CLK_LOCK_IN;
    assign pio_dat_to_app[2]            = tx_rst_done_from_phy;
    assign pio_dat_to_app[3]            = rx_rst_done_from_phy;
    assign pio_dat_to_app[4]            = gtpll_lock_from_phy[0];
    assign pio_dat_to_app[5]            = gtpll_lock_from_phy[1];
    assign pio_dat_to_app[6]            = txpll_lock_from_phy;
    assign pio_dat_to_app[7]            = rxpll_lock_from_phy;

    // PIO out mapping
    assign TENTIVA_CLK_SEL_OUT          = pio_dat_from_app[0];
    assign dptx_rst_from_app            = pio_dat_from_app[1];
    assign dprx_rst_from_app            = pio_dat_from_app[2];
    assign phy_gttx_rst_from_app        = pio_dat_from_app[3];
    assign phy_gtrx_rst_from_app        = pio_dat_from_app[4];
    assign phy_txpll_rst_from_app       = pio_dat_from_app[5];
    assign phy_rxpll_rst_from_app       = pio_dat_from_app[6];
    assign phy_tx_diffctrl_from_app      = pio_dat_from_app[7+:4];
    assign phy_tx_postcursor_from_app    = pio_dat_from_app[11+:5];
    assign phy_tx_rate_from_app          = pio_dat_from_app[16+:3];
    assign phy_rx_rate_from_app          = pio_dat_from_app[19+:3];
    
// Displayport TX
    prt_dptx_top
    #(
        // System
        .P_VENDOR           (P_VENDOR),     // Vendor
        .P_BEAT             (P_BEAT),       // Beat value. The system clock is 50 MHz
        .P_MST              (1'b0),         // MST support

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
        .VID0_VS_IN          (vs_from_vtb),                 // Vsync
        .VID0_HS_IN          (hs_from_vtb),                 // Hsync
        .VID0_R_IN           (r_from_vtb),                  // Red
        .VID0_G_IN           (g_from_vtb),                  // Green
        .VID0_B_IN           (b_from_vtb),                  // Blue
        .VID0_DE_IN          (de_from_vtb),                 // Data enable

        // Video stream 1
        .VID1_CLK_IN         (clk_from_vid_bufg),
        .VID1_CKE_IN         (1'b1),
        .VID1_VS_IN          (1'b0),                        // Vsync
        .VID1_HS_IN          (1'b0),                        // Hsync
        .VID1_R_IN           ({(P_PPC*P_BPC*3){1'b0}}),     // Red
        .VID1_G_IN           ({(P_PPC*P_BPC*3){1'b0}}),     // Green
        .VID1_B_IN           ({(P_PPC*P_BPC*3){1'b0}}),     // Blue
        .VID1_DE_IN          (1'b0),                        // Data enable

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

        // Video
        .VID_CLK_IN         (clk_from_vid_bufg),    // Clock
        .VID_RDY_IN         (1'b1),                 // Ready
        .VID_SOF_OUT        (vid_sof_from_dprx),    // Start of frame
        .VID_EOL_OUT        (vid_eol_from_dprx),    // End of line
        .VID_DAT_OUT        (vid_dat_from_dprx),    // Data
        .VID_VLD_OUT        (vid_vld_from_dprx)     // Valid
    );

    // Map data
    // DP lane 0 -> GT channel 0   
    assign {lnk_dat_to_dprx[(3*9)+:8], lnk_dat_to_dprx[(2*9)+:8], lnk_dat_to_dprx[(1*9)+:8], lnk_dat_to_dprx[(0*9)+:8]} = rxdat_from_phy[(0*32)+:32]; 
    assign lnk_dat_to_dprx[(0*9)+8]  = rxdatk_from_phy[(0*4)+0];
    assign lnk_dat_to_dprx[(1*9)+8]  = rxdatk_from_phy[(0*4)+1];
    assign lnk_dat_to_dprx[(2*9)+8]  = rxdatk_from_phy[(0*4)+2];
    assign lnk_dat_to_dprx[(3*9)+8]  = rxdatk_from_phy[(0*4)+3];

    // DP lane 1 -> GT channel 2
    assign {lnk_dat_to_dprx[(7*9)+:8], lnk_dat_to_dprx[(6*9)+:8], lnk_dat_to_dprx[(5*9)+:8], lnk_dat_to_dprx[(4*9)+:8]} = rxdat_from_phy[(2*32)+:32]; 
    assign lnk_dat_to_dprx[(4*9)+8]  = rxdatk_from_phy[(2*4)+0];
    assign lnk_dat_to_dprx[(5*9)+8]  = rxdatk_from_phy[(2*4)+1];
    assign lnk_dat_to_dprx[(6*9)+8]  = rxdatk_from_phy[(2*4)+2];
    assign lnk_dat_to_dprx[(7*9)+8]  = rxdatk_from_phy[(2*4)+3];

    // DP lane 2 -> GT channel 1
    assign {lnk_dat_to_dprx[(11*9)+:8], lnk_dat_to_dprx[(10*9)+:8], lnk_dat_to_dprx[(9*9)+:8], lnk_dat_to_dprx[(8*9)+:8]} = rxdat_from_phy[(1*32)+:32];  
    assign lnk_dat_to_dprx[(8*9)+8]  = rxdatk_from_phy[(1*4)+0];
    assign lnk_dat_to_dprx[(9*9)+8]  = rxdatk_from_phy[(1*4)+1];
    assign lnk_dat_to_dprx[(10*9)+8] = rxdatk_from_phy[(1*4)+2];
    assign lnk_dat_to_dprx[(11*9)+8] = rxdatk_from_phy[(1*4)+3];

    // DP lane 3 -> GT channel 3
    assign {lnk_dat_to_dprx[(15*9)+:8], lnk_dat_to_dprx[(14*9)+:8], lnk_dat_to_dprx[(13*9)+:8], lnk_dat_to_dprx[(12*9)+:8]} = rxdat_from_phy[(3*32)+:32]; 
    assign lnk_dat_to_dprx[(12*9)+8] = rxdatk_from_phy[(3*4)+0];
    assign lnk_dat_to_dprx[(13*9)+8] = rxdatk_from_phy[(3*4)+1];
    assign lnk_dat_to_dprx[(14*9)+8] = rxdatk_from_phy[(3*4)+2];
    assign lnk_dat_to_dprx[(15*9)+8] = rxdatk_from_phy[(3*4)+3];

// Video toolbox (stream 0)
    prt_vtb_top
    #(
        .P_VENDOR               (P_VENDOR),     // Vendor
        .P_SYS_FREQ             (P_SYS_FREQ),   // System frequency
        .P_PPC                  (P_PPC),        // Pixels per clock
        .P_BPC                  (P_BPC),        // Bits per component
        .P_AXIS_DAT             (P_AXI_WIDTH),  // AXIS data width
        .P_OVL                  (0)             // Overlay (0 - disable / 1 - Image 1 / 2 - Image 2)
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
        .VID_LOCK_OUT           (lock_from_vtb),
        .VID_VS_OUT             (vs_from_vtb),
        .VID_HS_OUT             (hs_from_vtb),
        .VID_R_OUT              (r_from_vtb),
        .VID_G_OUT              (g_from_vtb),
        .VID_B_OUT              (b_from_vtb),
        .VID_DE_OUT             (de_from_vtb)
    );

// DRP bridge
    prt_xil_drp
    #(
        .P_DRP_PORTS        (P_DRP_PORTS),
        .P_DRP_ADR          (9),
        .P_DRP_DAT          (16)
    )
    DRP_INST
    (
        // Reset and clock
        .SYS_RST_IN         (clk_rst),              // Reset
        .SYS_CLK_IN         (sys_clk_from_pll),    // Clock 

        // Local bus interface
        .LB_IF              (phy_if),

        // DRP
        .DRP_CLK_IN         (sys_clk_from_pll),
        .DRP_ADR_OUT        (adr_from_drp),
        .DRP_DAT_OUT        (dat_from_drp),
        .DRP_EN_OUT         (en_from_drp),
        .DRP_WR_OUT         (wr_from_drp),
        .DRP_DAT_IN         (drp_dat_from_phy),
        .DRP_RDY_IN         (drp_rdy_from_phy)
    );

// PHY - GTP
    dp_phy_a7_gtp
    PHY_INST
    (
        .SYS_CLK_IN         (sys_clk_from_pll),
        .GT_REFCLK_IN_P     (GT_REFCLK_IN_P[0]),
        .GT_REFCLK_IN_N     (GT_REFCLK_IN_N[0]),

        // GT
        .GT_RX_IN_P         (GT_RX_IN_P),
        .GT_RX_IN_N         (GT_RX_IN_N),
        .GT_TX_OUT_P        (GT_TX_OUT_P),
        .GT_TX_OUT_N        (GT_TX_OUT_N),

        // TX
        .TX_RST_IN          (phy_gttx_rst_from_app),
        .TX_RST_DONE_OUT    (tx_rst_done_from_phy),
        .TX_DAT_IN          (txdat_to_phy), 
        .TX_DATK_IN         (txdatk_to_phy),
        .TX_DISPMODE_IN     (txdispmode_to_phy),
        .TX_DISPVAL_IN      (txdispval_to_phy),
        .TX_DIFFCTRL_IN     (phy_tx_diffctrl_from_app), 
        .TX_POSTCURSOR_IN   (phy_tx_postcursor_from_app),
        .TX_USRCLK_OUT      (txclk_from_phy),
        .TX_PLL_RST_IN      (phy_txpll_rst_from_app),
        .TX_PLL_LOCK_OUT    (txpll_lock_from_phy),
        .TX_RATE_IN         (phy_tx_rate_from_app),

        // RX
        .RX_RST_IN          (phy_gtrx_rst_from_app),
        .RX_RST_DONE_OUT    (rx_rst_done_from_phy),
        .RX_DAT_OUT         (rxdat_from_phy),
        .RX_DATK_OUT        (rxdatk_from_phy),
        .RX_USRCLK_OUT      (rxclk_from_phy),
        .RX_PLL_RST_IN      (phy_rxpll_rst_from_app),
        .RX_PLL_LOCK_OUT    (rxpll_lock_from_phy),
        .RX_RATE_IN         (phy_rx_rate_from_app),

        // DRP
        .DRP_ADR_IN         (adr_from_drp),
        .DRP_DAT_IN         (dat_from_drp),
        .DRP_EN_IN          (en_from_drp),
        .DRP_WR_IN          (wr_from_drp),
        .DRP_DAT_OUT        (drp_dat_from_phy),
        .DRP_RDY_OUT        (drp_rdy_from_phy),

        // Status
        .GT_REFCLK_OUT      (gt_refclk_from_phy),
        .GT_PLL_LOCK_OUT    (gtpll_lock_from_phy)
    );
          
/*
    PHY TX data
*/

    // GT lane 0 -> DP lane 3
    assign txdat_to_phy[(0*32)+:32]     = {lnk_dat_from_dptx[(15*11)+:8], lnk_dat_from_dptx[(14*11)+:8], lnk_dat_from_dptx[(13*11)+:8], lnk_dat_from_dptx[(12*11)+:8]};         // TX data
    assign txdatk_to_phy[(0*4)+:4]      = {lnk_dat_from_dptx[(15*11)+8],  lnk_dat_from_dptx[(14*11)+8],  lnk_dat_from_dptx[(13*11)+8],  lnk_dat_from_dptx[(12*11)+8]};     // K character
    assign txdispval_to_phy[(0*4)+:4]   = {lnk_dat_from_dptx[(15*11)+9],  lnk_dat_from_dptx[(14*11)+9],  lnk_dat_from_dptx[(13*11)+9],  lnk_dat_from_dptx[(12*11)+9]};    // Disparity value (0-negative / 1-positive)
    assign txdispmode_to_phy[(0*4)+:4]  = {lnk_dat_from_dptx[(15*11)+10], lnk_dat_from_dptx[(14*11)+10], lnk_dat_from_dptx[(13*11)+10], lnk_dat_from_dptx[(12*11)+10]};  // Disparity control (0-automatic / 1-force)

    // GT lane 1 -> DP lane 1 
    assign txdat_to_phy[(1*32)+:32]     = {lnk_dat_from_dptx[(7*11)+:8], lnk_dat_from_dptx[(6*11)+:8], lnk_dat_from_dptx[(5*11)+:8], lnk_dat_from_dptx[(4*11)+:8]};         // TX data
    assign txdatk_to_phy[(1*4)+:4]      = {lnk_dat_from_dptx[(7*11)+8],  lnk_dat_from_dptx[(6*11)+8],  lnk_dat_from_dptx[(5*11)+8],  lnk_dat_from_dptx[(4*11)+8]};     // K character
    assign txdispval_to_phy[(1*4)+:4]   = {lnk_dat_from_dptx[(7*11)+9],  lnk_dat_from_dptx[(6*11)+9],  lnk_dat_from_dptx[(5*11)+9],  lnk_dat_from_dptx[(4*11)+9]};    // Disparity value (0-negative / 1-positive)
    assign txdispmode_to_phy[(1*4)+:4]  = {lnk_dat_from_dptx[(7*11)+10], lnk_dat_from_dptx[(6*11)+10], lnk_dat_from_dptx[(5*11)+10], lnk_dat_from_dptx[(4*11)+10]};  // Disparity control (0-automatic / 1-force)

    // GT lane 2 -> DP lane 2
    assign txdat_to_phy[(2*32)+:32]     = {lnk_dat_from_dptx[(11*11)+:8], lnk_dat_from_dptx[(10*11)+:8], lnk_dat_from_dptx[(9*11)+:8], lnk_dat_from_dptx[(8*11)+:8]};         // TX data
    assign txdatk_to_phy[(2*4)+:4]      = {lnk_dat_from_dptx[(11*11)+8],  lnk_dat_from_dptx[(10*11)+8],  lnk_dat_from_dptx[(9*11)+8],  lnk_dat_from_dptx[(8*11)+8]};     // K character
    assign txdispval_to_phy[(2*4)+:4]   = {lnk_dat_from_dptx[(11*11)+9],  lnk_dat_from_dptx[(10*11)+9],  lnk_dat_from_dptx[(9*11)+9],  lnk_dat_from_dptx[(8*11)+9]};    // Disparity value (0-negative / 1-positive)
    assign txdispmode_to_phy[(2*4)+:4]  = {lnk_dat_from_dptx[(11*11)+10], lnk_dat_from_dptx[(10*11)+10], lnk_dat_from_dptx[(9*11)+10], lnk_dat_from_dptx[(8*11)+10]};  // Disparity control (0-automatic / 1-force)

    // GT lane 3 -> DP lane 0
    assign txdat_to_phy[(3*32)+:32]     = {lnk_dat_from_dptx[(3*11)+:8], lnk_dat_from_dptx[(2*11)+:8], lnk_dat_from_dptx[(1*11)+:8], lnk_dat_from_dptx[(0*11)+:8]};         // TX data
    assign txdatk_to_phy[(3*4)+:4]      = {lnk_dat_from_dptx[(3*11)+8],  lnk_dat_from_dptx[(2*11)+8],  lnk_dat_from_dptx[(1*11)+8],  lnk_dat_from_dptx[(0*11)+8]};     // K character
    assign txdispval_to_phy[(3*4)+:4]   = {lnk_dat_from_dptx[(3*11)+9],  lnk_dat_from_dptx[(2*11)+9],  lnk_dat_from_dptx[(1*11)+9],  lnk_dat_from_dptx[(0*11)+9]};    // Disparity value (0-negative / 1-positive)
    assign txdispmode_to_phy[(3*4)+:4]  = {lnk_dat_from_dptx[(3*11)+10], lnk_dat_from_dptx[(2*11)+10], lnk_dat_from_dptx[(1*11)+10], lnk_dat_from_dptx[(0*11)+10]};  // Disparity control (0-automatic / 1-force)

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
    GT_HB_INST
    (
        .CLK_IN     (gt_refclk_from_phy),
        .LED_OUT    (led_from_gt_hb)
    );

// Outputs
    assign LED_OUT[0]   = led_from_sys_hb; //led_from_vid_hb;
    assign LED_OUT[1]   = led_from_gt_hb;
    assign LED_OUT[2]   = hb_from_dptx;
    assign LED_OUT[3]   = hb_from_dprx;

endmodule

`default_nettype wire
