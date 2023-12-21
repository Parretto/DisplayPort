/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP PHY for AMD Artix-7 GTP
    (c) 2023 by Parretto B.V.

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

// 7 series GTP Transceivers User Guide - UG482
// 7 series GTP TRansceivers Wizard - PG168   

module dp_phy_a7_gtp
(
    input wire                  SYS_CLK_IN,
    input wire                  GT_REFCLK_IN_P,
    input wire                  GT_REFCLK_IN_N,

    // GT
    input wire [3:0]            GT_RX_IN_P,
    input wire [3:0]            GT_RX_IN_N,
    output wire [3:0]           GT_TX_OUT_P,
    output wire [3:0]           GT_TX_OUT_N,

    // TX
    input wire                  TX_RST_IN,
    output wire                 TX_RST_DONE_OUT,
    input wire [127:0]          TX_DAT_IN, 
    input wire [15:0]           TX_DATK_IN,
    input wire [15:0]           TX_DISPMODE_IN,
    input wire [15:0]           TX_DISPVAL_IN,
    input wire [3:0]            TX_DIFFCTRL_IN, 
    input wire [4:0]            TX_POSTCURSOR_IN,
    output wire                 TX_USRCLK_OUT,
    input wire                  TX_PLL_RST_IN,
    output wire                 TX_PLL_LOCK_OUT,
    input wire [2:0]            TX_RATE_IN,

    // RX
    input wire                  RX_RST_IN,
    output wire                 RX_RST_DONE_OUT,
    output wire [127:0]         RX_DAT_OUT,
    output wire [15:0]          RX_DATK_OUT,
    output wire                 RX_USRCLK_OUT,
    input wire                  RX_PLL_RST_IN,
    output wire                 RX_PLL_LOCK_OUT,
    input wire [2:0]            RX_RATE_IN,

    // DRP
    input wire [(7*9)-1:0]      DRP_ADR_IN,
    input wire [(7*16)-1:0]     DRP_DAT_IN,
    input wire [6:0]            DRP_EN_IN,
    input wire [6:0]            DRP_WR_IN,
    output wire [(7*16)-1:0]    DRP_DAT_OUT,
    output wire [6:0]           DRP_RDY_OUT,

    // Status
    output wire                 GT_REFCLK_OUT,
    output wire [1:0]           GT_PLL_LOCK_OUT
);

// Parameters
localparam P_PLL0_FBDIV         = 4;
localparam P_PLL0_FBDIV_45      = 5;
localparam P_PLL0_REFCLK_DIV    = 1;
localparam P_PLL1_FBDIV         = 4;
localparam P_PLL1_FBDIV_45      = 5;
localparam P_PLL1_REFCLK_DIV    = 1;

// Signals
wire    clk_from_refclk_buf;
wire    clk2_from_refclk_buf;

// Common
wire [1:0]  pll_outclk_from_common;
wire [1:0]  pll_outrefclk_from_common;
wire [1:0]  pll_lock_from_common;
wire [1:0]  pll_refclklost_from_common;

// PHY
wire        txpll_rst_from_phy;
wire        rxpll_rst_from_phy;
wire        txoutclk_from_phy;
wire        rxoutclk_from_phy;
wire [3:0]  tx_rst_done_from_phy;
wire [3:0]  rx_rst_done_from_phy;
wire [1:0]  pll_rst_from_phy;

// TXPLL
wire        clkfb_from_txpll;
wire        txusrclk_from_txpll;
wire        txusrclk2_from_txpll;
wire        rst_to_txpll;
wire        lock_from_txpll;

// RXPLL
wire        clkfb_from_rxpll;
wire        rxusrclk_from_rxpll;
wire        rxusrclk2_from_rxpll;
wire        rst_to_rxpll;
wire        lock_from_rxpll;

// Clock buffers
wire        txoutclk_from_buf;
wire        rxoutclk_from_buf;
wire        txusrclk_from_buf;
wire        txusrclk2_from_buf;
wire        rxusrclk_from_buf;
wire        rxusrclk2_from_buf;

// Logic

    // Reference clock input buffer
    IBUFDS_GTE2 
    REFCLK_INST
    (
        .I               (GT_REFCLK_IN_P),
        .IB              (GT_REFCLK_IN_N),
        .CEB             (1'b0),
        .O               (clk_from_refclk_buf),
        .ODIV2           (clk2_from_refclk_buf)
    );

    // Common
    GTPE2_COMMON 
    #(
        // Simulation attributes
        .SIM_RESET_SPEEDUP   ("TRUE"),
        .SIM_PLL0REFCLK_SEL  (3'b001),
        .SIM_PLL1REFCLK_SEL  (3'b001),
        .SIM_VERSION         ("2.0"),

        .PLL0_FBDIV          (P_PLL0_FBDIV),	
        .PLL0_FBDIV_45       (P_PLL0_FBDIV_45),	
        .PLL0_REFCLK_DIV     (P_PLL0_REFCLK_DIV),	
        .PLL1_FBDIV          (P_PLL1_FBDIV),	
        .PLL1_FBDIV_45       (P_PLL1_FBDIV_45),	
        .PLL1_REFCLK_DIV     (P_PLL1_REFCLK_DIV),	        

        //----------------COMMON BLOCK Attributes---------------
        .BIAS_CFG                               (64'h0000000000050001),
        .COMMON_CFG                             (32'h00000000),

        //--------------------------PLL Attributes----------------------------
        .PLL0_CFG                               (27'h01F03DC),
        .PLL0_DMON_CFG                          (1'b0),
        .PLL0_INIT_CFG                          (24'h00001E),
        .PLL0_LOCK_CFG                          (9'h1E8),
        .PLL1_CFG                               (27'h01F03DC),
        .PLL1_DMON_CFG                          (1'b0),
        .PLL1_INIT_CFG                          (24'h00001E),
        .PLL1_LOCK_CFG                          (9'h1E8),
        .PLL_CLKOUT_CFG                         (8'h00),

        //--------------------------Reserved Attributes----------------------------
        .RSVD_ATTR0                             (16'h0000),
        .RSVD_ATTR1                             (16'h0000)

    )
    COMMON_INST
    (
        .DMONITOROUT                    (),	
        //----------- Common Block  - Dynamic Reconfiguration Port (DRP) -----------
        .DRPADDR                        (DRP_ADR_IN[(4*9)+:8]),
        .DRPCLK                         (SYS_CLK_IN),
        .DRPDI                          (DRP_DAT_IN[(4*16)+:16]),
        .DRPDO                          (DRP_DAT_OUT[(4*16)+:16]),
        .DRPEN                          (DRP_EN_IN[4]),
        .DRPRDY                         (DRP_RDY_OUT[4]),
        .DRPWE                          (DRP_WR_IN[4]),
        //--------------- Common Block - GTPE2_COMMON Clocking Ports ---------------
        .GTEASTREFCLK0                  (1'b0),
        .GTEASTREFCLK1                  (1'b0),
        .GTGREFCLK1                     (1'b0),
        .GTREFCLK0                      (clk_from_refclk_buf),
        .GTREFCLK1                      (1'b0),
        .GTWESTREFCLK0                  (1'b0),
        .GTWESTREFCLK1                  (1'b0),
        .PLL0OUTCLK                     (pll_outclk_from_common[0]),
        .PLL0OUTREFCLK                  (pll_outrefclk_from_common[0]),
        .PLL1OUTCLK                     (pll_outclk_from_common[1]),
        .PLL1OUTREFCLK                  (pll_outrefclk_from_common[1]),
        //------------------------ Common Block - PLL Ports ------------------------
        .PLL0FBCLKLOST                  (),
        .PLL0LOCK                       (pll_lock_from_common[0]),
        .PLL0LOCKDETCLK                 (SYS_CLK_IN),
        .PLL0LOCKEN                     (1'b1),
        .PLL0PD                         (1'b0),
        .PLL0REFCLKLOST                 (pll_refclklost_from_common[0]),
        .PLL0REFCLKSEL                  (3'b001),   // Select GTREFCLK0
        .PLL0RESET                      (pll_rst_from_phy[0]),
        .PLL1FBCLKLOST                  (),
        .PLL1LOCK                       (pll_lock_from_common[1]),
        .PLL1LOCKDETCLK                 (SYS_CLK_IN),
        .PLL1LOCKEN                     (1'b1),
        .PLL1PD                         (1'b0),
        .PLL1REFCLKLOST                 (pll_refclklost_from_common[1]),
        .PLL1REFCLKSEL                  (3'b001),   // Select GTREFCLK0
        .PLL1RESET                      (pll_rst_from_phy[1]),
        //-------------------------- Common Block - Ports --------------------------
        .BGRCALOVRDENB                  (1'b1),
        .GTGREFCLK0                     (1'b0),
        .PLLRSVD1                       (16'b0000000000000000),
        .PLLRSVD2                       (5'b00000),
        .REFCLKOUTMONITOR0              (),
        .REFCLKOUTMONITOR1              (),
        //---------------------- Common Block - RX AFE Ports -----------------------
        .PMARSVDOUT                     (),
        //------------------------------- QPLL Ports -------------------------------
        .BGBYPASSB                      (1'b1),
        .BGMONITORENB                   (1'b1),
        .BGPDB                          (1'b1),
        .BGRCALOVRD                     (5'b11111),
        .PMARSVD                        (8'b00000000),
        .RCALENB                        (1'b1)
    );

    // Channels
    gtp_4spl
    PHY_INST
    (
        .sysclk_in                      (SYS_CLK_IN),
        .soft_reset_tx_in               (TX_RST_IN),
        .soft_reset_rx_in               (RX_RST_IN),
        .dont_reset_on_data_error_in    (1'b0),

        .gt0_tx_fsm_reset_done_out      (tx_rst_done_from_phy[0]),
        .gt0_rx_fsm_reset_done_out      (rx_rst_done_from_phy[0]),
        .gt0_data_valid_in              (1'b1),
        .gt0_tx_mmcm_lock_in            (lock_from_txpll),
        .gt0_tx_mmcm_reset_out          (txpll_rst_from_phy),
        .gt0_rx_mmcm_lock_in            (lock_from_rxpll),
        .gt0_rx_mmcm_reset_out          (rxpll_rst_from_phy),

        .gt1_tx_fsm_reset_done_out      (tx_rst_done_from_phy[1]),
        .gt1_rx_fsm_reset_done_out      (rx_rst_done_from_phy[1]),
        .gt1_data_valid_in              (1'b1),
        .gt1_tx_mmcm_lock_in            (lock_from_txpll),
        .gt1_tx_mmcm_reset_out          (),
        .gt1_rx_mmcm_lock_in            (lock_from_rxpll),
        .gt1_rx_mmcm_reset_out          (),

        .gt2_tx_fsm_reset_done_out      (tx_rst_done_from_phy[2]),
        .gt2_rx_fsm_reset_done_out      (rx_rst_done_from_phy[2]),
        .gt2_data_valid_in              (1'b1),
        .gt2_tx_mmcm_lock_in            (lock_from_txpll),
        .gt2_tx_mmcm_reset_out          (),
        .gt2_rx_mmcm_lock_in            (lock_from_rxpll),
        .gt2_rx_mmcm_reset_out          (),

        .gt3_tx_fsm_reset_done_out      (tx_rst_done_from_phy[3]),
        .gt3_rx_fsm_reset_done_out      (rx_rst_done_from_phy[3]),
        .gt3_data_valid_in              (1'b1),
        .gt3_tx_mmcm_lock_in            (lock_from_txpll),
        .gt3_tx_mmcm_reset_out          (),
        .gt3_rx_mmcm_lock_in            (lock_from_rxpll),
        .gt3_rx_mmcm_reset_out          (),

        //_________________________________________________________________________
        //GT0  (X0Y0)
        //____________________________CHANNEL PORTS________________________________
        //-------------------------- Channel - DRP Ports  --------------------------
        .gt0_drpclk_in                  (SYS_CLK_IN),
        .gt0_drpaddr_in                 (DRP_ADR_IN[(0*9)+:9]),
        .gt0_drpdi_in                   (DRP_DAT_IN[(0*16)+:16]),
        .gt0_drpdo_out                  (DRP_DAT_OUT[(0*16)+:16]),
        .gt0_drpen_in                   (DRP_EN_IN[0]),
        .gt0_drprdy_out                 (DRP_RDY_OUT[0]),
        .gt0_drpwe_in                   (DRP_WR_IN[0]),
        .gt0_drp_busy_out               (),
        //------------------- RX Initialization and Reset Ports --------------------
        .gt0_eyescanreset_in            (1'b1),
        .gt0_rxuserrdy_in               (1'b1),
        //------------------------ RX Margin Analysis Ports ------------------------
        .gt0_eyescandataerror_out       (),
        .gt0_eyescantrigger_in          (1'b0),
        //---------------- Receive Ports - FPGA RX Interface Ports -----------------
        .gt0_rxdata_out                 (RX_DAT_OUT[(0*32)+:32]),
        .gt0_rxusrclk_in                (rxusrclk_from_buf),
        .gt0_rxusrclk2_in               (rxusrclk2_from_buf),
        //--------------------------- PCI Express Ports ----------------------------
        .gt0_rxrate_in                  (RX_RATE_IN),
        //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
        .gt0_rxcharisk_out              (RX_DATK_OUT[(0*4)+:4]),
        .gt0_rxdisperr_out              (),
        .gt0_rxnotintable_out           (),
        //---------------------- Receive Ports - RX AFE Ports ----------------------
        .gt0_gtprxp_in                  (GT_RX_IN_P[0]),
        .gt0_gtprxn_in                  (GT_RX_IN_N[0]),
        //---------- Receive Ports - RX Decision Feedback Equalizer(DFE) -----------
        .gt0_dmonitorout_out            (),
        //------------------ Receive Ports - RX Equailizer Ports -------------------
        .gt0_rxlpmhfhold_in             (1'b0),
        .gt0_rxlpmhfovrden_in           (1'b0),
        .gt0_rxlpmlfhold_in             (1'b0),
        //------------- Receive Ports - RX Fabric Output Control Ports -------------
        .gt0_rxoutclk_out               (rxoutclk_from_phy),    // This is the 2 bytes clock
        .gt0_rxoutclkfabric_out         (),
        //----------- Receive Ports - RX Initialization and Reset Ports ------------
        .gt0_gtrxreset_in               (1'b0),
        .gt0_rxlpmreset_in              (1'b0),
        //--------------- Receive Ports - RX Polarity Control Ports ----------------
        .gt0_rxpolarity_in              (1'b1), // Lane 0 is inverted
        //------------ Receive Ports -RX Initialization and Reset Ports ------------
        .gt0_rxresetdone_out            (),
        //---------------------- TX Configurable Driver Ports ----------------------
        .gt0_txpostcursor_in            (TX_POSTCURSOR_IN),
        //------------------- TX Initialization and Reset Ports --------------------
        .gt0_gttxreset_in               (1'b0),
        .gt0_txuserrdy_in               (1'b1),
        //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
        .gt0_txdata_in                  (TX_DAT_IN[(0*32)+:32]),
        .gt0_txusrclk_in                (txusrclk_from_buf),
        .gt0_txusrclk2_in               (txusrclk2_from_buf),
        //------------------- Transmit Ports - PCI Express Ports -------------------
        .gt0_txrate_in                  (TX_RATE_IN),
        //---------------- Transmit Ports - TX 8B/10B Encoder Ports ----------------
        .gt0_txchardispmode_in          (TX_DISPMODE_IN[(0*4)+:4]),
        .gt0_txchardispval_in           (TX_DISPVAL_IN[(0*4)+:4]),
        .gt0_txcharisk_in               (TX_DATK_IN[(0*4)+:4]),
        //------------- Transmit Ports - TX Configurable Driver Ports --------------
        .gt0_gtptxp_out                 (GT_TX_OUT_P[0]),
        .gt0_gtptxn_out                 (GT_TX_OUT_N[0]),
        .gt0_txdiffctrl_in              (TX_DIFFCTRL_IN),
        //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
        .gt0_txoutclk_out               (txoutclk_from_phy),  // This is the 2 bytes clock
        .gt0_txoutclkfabric_out         (),
        .gt0_txoutclkpcs_out            (),
        //----------- Transmit Ports - TX Initialization and Reset Ports -----------
        .gt0_txresetdone_out            (),
        //--------------- Transmit Ports - TX Polarity Control Ports ---------------
        .gt0_txpolarity_in              (1'b1),  // Channel 0 is inverted

        //_________________________________________________________________________
        //GT1  (X0Y1)
        //____________________________CHANNEL PORTS________________________________
        //-------------------------- Channel - DRP Ports  --------------------------
        .gt1_drpclk_in                  (SYS_CLK_IN),
        .gt1_drpaddr_in                 (DRP_ADR_IN[(1*9)+:9]),
        .gt1_drpdi_in                   (DRP_DAT_IN[(1*16)+:16]),
        .gt1_drpdo_out                  (DRP_DAT_OUT[(1*16)+:16]),
        .gt1_drpen_in                   (DRP_EN_IN[1]),
        .gt1_drprdy_out                 (DRP_RDY_OUT[1]),
        .gt1_drpwe_in                   (DRP_WR_IN[1]),
        .gt1_drp_busy_out               (),
        //------------------- RX Initialization and Reset Ports --------------------
        .gt1_eyescanreset_in            (1'b1),
        .gt1_rxuserrdy_in               (1'b1),
        //------------------------ RX Margin Analysis Ports ------------------------
        .gt1_eyescandataerror_out       (),
        .gt1_eyescantrigger_in          (1'b0),
        //---------------- Receive Ports - FPGA RX Interface Ports -----------------
        .gt1_rxdata_out                 (RX_DAT_OUT[(1*32)+:32]),
        .gt1_rxusrclk_in                (rxusrclk_from_buf),
        .gt1_rxusrclk2_in               (rxusrclk2_from_buf),
        //--------------------------- PCI Express Ports ----------------------------
        .gt1_rxrate_in                  (RX_RATE_IN),
        //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
        .gt1_rxcharisk_out              (RX_DATK_OUT[(1*4)+:4]),
        .gt1_rxdisperr_out              (),
        .gt1_rxnotintable_out           (),
        //---------------------- Receive Ports - RX AFE Ports ----------------------
        .gt1_gtprxp_in                  (GT_RX_IN_P[1]),
        .gt1_gtprxn_in                  (GT_RX_IN_N[1]),
        //---------- Receive Ports - RX Decision Feedback Equalizer(DFE) -----------
        .gt1_dmonitorout_out            (),
        //------------------ Receive Ports - RX Equailizer Ports -------------------
        .gt1_rxlpmhfhold_in             (1'b0),
        .gt1_rxlpmhfovrden_in           (1'b0),
        .gt1_rxlpmlfhold_in             (1'b0),
        //------------- Receive Ports - RX Fabric Output Control Ports -------------
        .gt1_rxoutclk_out               (),
        .gt1_rxoutclkfabric_out         (),
        //----------- Receive Ports - RX Initialization and Reset Ports ------------
        .gt1_gtrxreset_in               (1'b0),
        .gt1_rxlpmreset_in              (1'b0),
        //--------------- Receive Ports - RX Polarity Control Ports ----------------
        .gt1_rxpolarity_in              (1'b1), // Lane 1 is inverted
        //------------ Receive Ports -RX Initialization and Reset Ports ------------
        .gt1_rxresetdone_out            (),
        //---------------------- TX Configurable Driver Ports ----------------------
        .gt1_txpostcursor_in            (TX_POSTCURSOR_IN),
        //------------------- TX Initialization and Reset Ports --------------------
        .gt1_gttxreset_in               (1'b0),
        .gt1_txuserrdy_in               (1'b1),
        //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
        .gt1_txdata_in                  (TX_DAT_IN[(1*32)+:32]),
        .gt1_txusrclk_in                (txusrclk_from_buf),
        .gt1_txusrclk2_in               (txusrclk2_from_buf),
        //------------------- Transmit Ports - PCI Express Ports -------------------
        .gt1_txrate_in                  (TX_RATE_IN),
        //---------------- Transmit Ports - TX 8B/10B Encoder Ports ----------------
        .gt1_txchardispmode_in          (TX_DISPMODE_IN[(1*4)+:4]),
        .gt1_txchardispval_in           (TX_DISPVAL_IN[(1*4)+:4]),
        .gt1_txcharisk_in               (TX_DATK_IN[(1*4)+:4]),
        //------------- Transmit Ports - TX Configurable Driver Ports --------------
        .gt1_gtptxp_out                 (GT_TX_OUT_P[1]),
        .gt1_gtptxn_out                 (GT_TX_OUT_N[1]),
        .gt1_txdiffctrl_in              (TX_DIFFCTRL_IN),
        //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
        .gt1_txoutclk_out               (),
        .gt1_txoutclkfabric_out         (),
        .gt1_txoutclkpcs_out            (),
        //----------- Transmit Ports - TX Initialization and Reset Ports -----------
        .gt1_txresetdone_out            (),
        //--------------- Transmit Ports - TX Polarity Control Ports ---------------
        .gt1_txpolarity_in              (1'b0),  // Channel 1 is normal

        //_________________________________________________________________________
        //GT2  (X0Y2)
        //____________________________CHANNEL PORTS________________________________
        //-------------------------- Channel - DRP Ports  --------------------------
        .gt2_drpclk_in                  (SYS_CLK_IN),
        .gt2_drpaddr_in                 (DRP_ADR_IN[(2*9)+:9]),
        .gt2_drpdi_in                   (DRP_DAT_IN[(2*16)+:16]),
        .gt2_drpdo_out                  (DRP_DAT_OUT[(2*16)+:16]),
        .gt2_drpen_in                   (DRP_EN_IN[2]),
        .gt2_drprdy_out                 (DRP_RDY_OUT[2]),
        .gt2_drpwe_in                   (DRP_WR_IN[2]),
        .gt2_drp_busy_out               (),
        //------------------- RX Initialization and Reset Ports --------------------
        .gt2_eyescanreset_in            (1'b1),
        .gt2_rxuserrdy_in               (1'b1),
        //------------------------ RX Margin Analysis Ports ------------------------
        .gt2_eyescandataerror_out       (),
        .gt2_eyescantrigger_in          (1'b0),
        //---------------- Receive Ports - FPGA RX Interface Ports -----------------
        .gt2_rxdata_out                 (RX_DAT_OUT[(2*32)+:32]),
        .gt2_rxusrclk_in                (rxusrclk_from_buf),
        .gt2_rxusrclk2_in               (rxusrclk2_from_buf),
        //--------------------------- PCI Express Ports ----------------------------
        .gt2_rxrate_in                  (RX_RATE_IN),
        //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
        .gt2_rxcharisk_out              (RX_DATK_OUT[(2*4)+:4]),
        .gt2_rxdisperr_out              (),
        .gt2_rxnotintable_out           (),
        //---------------------- Receive Ports - RX AFE Ports ----------------------
        .gt2_gtprxp_in                  (GT_RX_IN_P[2]),
        .gt2_gtprxn_in                  (GT_RX_IN_N[2]),
        //---------- Receive Ports - RX Decision Feedback Equalizer(DFE) -----------
        .gt2_dmonitorout_out            (),
        //------------------ Receive Ports - RX Equailizer Ports -------------------
        .gt2_rxlpmhfhold_in             (1'b0),
        .gt2_rxlpmhfovrden_in           (1'b0),
        .gt2_rxlpmlfhold_in             (1'b0),
        //------------- Receive Ports - RX Fabric Output Control Ports -------------
        .gt2_rxoutclk_out               (),
        .gt2_rxoutclkfabric_out         (),
        //----------- Receive Ports - RX Initialization and Reset Ports ------------
        .gt2_gtrxreset_in               (1'b0),
        .gt2_rxlpmreset_in              (1'b0),
        //--------------- Receive Ports - RX Polarity Control Ports ----------------
        .gt2_rxpolarity_in              (1'b1), // Lanes 2 is inverted
        //------------ Receive Ports -RX Initialization and Reset Ports ------------
        .gt2_rxresetdone_out            (),
        //---------------------- TX Configurable Driver Ports ----------------------
        .gt2_txpostcursor_in            (TX_POSTCURSOR_IN),
        //------------------- TX Initialization and Reset Ports --------------------
        .gt2_gttxreset_in               (1'b0),
        .gt2_txuserrdy_in               (1'b1),
        //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
        .gt2_txdata_in                  (TX_DAT_IN[(2*32)+:32]),
        .gt2_txusrclk_in                (txusrclk_from_buf),
        .gt2_txusrclk2_in               (txusrclk2_from_buf),
        //------------------- Transmit Ports - PCI Express Ports -------------------
        .gt2_txrate_in                  (TX_RATE_IN),
        //---------------- Transmit Ports - TX 8B/10B Encoder Ports ----------------
        .gt2_txchardispmode_in          (TX_DISPMODE_IN[(2*4)+:4]),
        .gt2_txchardispval_in           (TX_DISPVAL_IN[(2*4)+:4]),
        .gt2_txcharisk_in               (TX_DATK_IN[(2*4)+:4]),
        //------------- Transmit Ports - TX Configurable Driver Ports --------------
        .gt2_gtptxp_out                 (GT_TX_OUT_P[2]),
        .gt2_gtptxn_out                 (GT_TX_OUT_N[2]),
        .gt2_txdiffctrl_in              (TX_DIFFCTRL_IN),
        //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
        .gt2_txoutclk_out               (),
        .gt2_txoutclkfabric_out         (),
        .gt2_txoutclkpcs_out            (),
        //----------- Transmit Ports - TX Initialization and Reset Ports -----------
        .gt2_txresetdone_out            (),
        //--------------- Transmit Ports - TX Polarity Control Ports ---------------
        .gt2_txpolarity_in              (1'b1),  // Channel 2 is inverted

        //_________________________________________________________________________
        //GT3  (X0Y3)
        //____________________________CHANNEL PORTS________________________________
        //-------------------------- Channel - DRP Ports  --------------------------
        .gt3_drpclk_in                  (SYS_CLK_IN),
        .gt3_drpaddr_in                 (DRP_ADR_IN[(3*9)+:9]),
        .gt3_drpdi_in                   (DRP_DAT_IN[(3*16)+:16]),
        .gt3_drpdo_out                  (DRP_DAT_OUT[(3*16)+:16]),
        .gt3_drpen_in                   (DRP_EN_IN[3]),
        .gt3_drprdy_out                 (DRP_RDY_OUT[3]),
        .gt3_drpwe_in                   (DRP_WR_IN[3]),
        .gt3_drp_busy_out               (),
        //------------------- RX Initialization and Reset Ports --------------------
        .gt3_eyescanreset_in            (1'b1),
        .gt3_rxuserrdy_in               (1'b1),
        //------------------------ RX Margin Analysis Ports ------------------------
        .gt3_eyescandataerror_out       (),
        .gt3_eyescantrigger_in          (1'b0),
        //---------------- Receive Ports - FPGA RX Interface Ports -----------------
        .gt3_rxdata_out                 (RX_DAT_OUT[(3*32)+:32]),
        .gt3_rxusrclk_in                (rxusrclk_from_buf),
        .gt3_rxusrclk2_in               (rxusrclk2_from_buf),
        //--------------------------- PCI Express Ports ----------------------------
        .gt3_rxrate_in                  (RX_RATE_IN),
        //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
        .gt3_rxcharisk_out              (RX_DATK_OUT[(3*4)+:4]),
        .gt3_rxdisperr_out              (),
        .gt3_rxnotintable_out           (),
        //---------------------- Receive Ports - RX AFE Ports ----------------------
        .gt3_gtprxp_in                  (GT_RX_IN_P[3]),
        .gt3_gtprxn_in                  (GT_RX_IN_N[3]),
        //---------- Receive Ports - RX Decision Feedback Equalizer(DFE) -----------
        .gt3_dmonitorout_out            (),
        //------------------ Receive Ports - RX Equailizer Ports -------------------
        .gt3_rxlpmhfhold_in             (1'b0),
        .gt3_rxlpmhfovrden_in           (1'b0),
        .gt3_rxlpmlfhold_in             (1'b0),
        //------------- Receive Ports - RX Fabric Output Control Ports -------------
        .gt3_rxoutclk_out               (),
        .gt3_rxoutclkfabric_out         (),
        //----------- Receive Ports - RX Initialization and Reset Ports ------------
        .gt3_gtrxreset_in               (1'b0),
        .gt3_rxlpmreset_in              (1'b0),
        //--------------- Receive Ports - RX Polarity Control Ports ----------------
        .gt3_rxpolarity_in              (1'b1), // Lane 3 is inverted
        //------------ Receive Ports -RX Initialization and Reset Ports ------------
        .gt3_rxresetdone_out            (),
        //---------------------- TX Configurable Driver Ports ----------------------
        .gt3_txpostcursor_in            (TX_POSTCURSOR_IN),
        //------------------- TX Initialization and Reset Ports --------------------
        .gt3_gttxreset_in               (1'b0),
        .gt3_txuserrdy_in               (1'b1),
        //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
        .gt3_txdata_in                  (TX_DAT_IN[(3*32)+:32]),
        .gt3_txusrclk_in                (txusrclk_from_buf),
        .gt3_txusrclk2_in               (txusrclk2_from_buf),
        //------------------- Transmit Ports - PCI Express Ports -------------------
        .gt3_txrate_in                  (TX_RATE_IN),
        //---------------- Transmit Ports - TX 8B/10B Encoder Ports ----------------
        .gt3_txchardispmode_in          (TX_DISPMODE_IN[(3*4)+:4]),
        .gt3_txchardispval_in           (TX_DISPVAL_IN[(3*4)+:4]),
        .gt3_txcharisk_in               (TX_DATK_IN[(3*4)+:4]),
        //------------- Transmit Ports - TX Configurable Driver Ports --------------
        .gt3_gtptxp_out                 (GT_TX_OUT_P[3]),
        .gt3_gtptxn_out                 (GT_TX_OUT_N[3]),
        .gt3_txdiffctrl_in              (TX_DIFFCTRL_IN),
        //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
        .gt3_txoutclk_out               (),
        .gt3_txoutclkfabric_out         (),
        .gt3_txoutclkpcs_out            (),
        //----------- Transmit Ports - TX Initialization and Reset Ports -----------
        .gt3_txresetdone_out            (),
        //--------------- Transmit Ports - TX Polarity Control Ports ---------------
        .gt3_txpolarity_in              (1'b0),  // Channel 3 is normal

        //____________________________COMMON PORTS________________________________
        .gt0_pll0outclk_in              (pll_outclk_from_common[0]),
        .gt0_pll0outrefclk_in           (pll_outrefclk_from_common[0]),
        .gt0_pll0reset_out              (pll_rst_from_phy[0]),
        .gt0_pll0lock_in                (pll_lock_from_common[0]),
        .gt0_pll0refclklost_in          (pll_refclklost_from_common[0]),    

        .gt0_pll1outclk_in              (pll_outclk_from_common[1]),
        .gt0_pll1outrefclk_in           (pll_outrefclk_from_common[1]),
        .gt0_pll1lock_in                (pll_lock_from_common[1]),
        .gt0_pll1reset_out              (pll_rst_from_phy[1]),
        .gt0_pll1refclklost_in          (pll_refclklost_from_common[1])    
    );    

    // TXOUTCLK Buffer
    BUFG 
    TXOUTCLK_BUF_INST 
    (
      .I    (txoutclk_from_phy),    // 1-bit input: Clock input.
      .O    (txoutclk_from_buf)     // 1-bit output: Clock output.
    );

    // RXOUTCLK Buffer
    BUFG 
    RXOUTCLK_BUF_INST 
    (
      .I    (rxoutclk_from_phy),    // 1-bit input: Clock input.
      .O    (rxoutclk_from_buf)     // 1-bit output: Clock output.
    );

    // TX PLL
    // The GT is operated in 4 bytes mode
    // The TXPLL creates the TXUSRCLK and TXUSRCLK2
    // See TXUSRCLK and TXUSRCLK2 generation on page 77 of UG482
    PLLE2_ADV
    #(
        .BANDWIDTH            ("OPTIMIZED"),
        .COMPENSATION         ("ZHOLD"),
        .STARTUP_WAIT         ("FALSE"),
        .DIVCLK_DIVIDE        (1),
        .CLKFBOUT_MULT        (10), // 3
        .CLKFBOUT_PHASE       (0.000),
        .CLKOUT0_DIVIDE       (10), // 3
        .CLKOUT0_PHASE        (0.000),
        .CLKOUT0_DUTY_CYCLE   (0.500),
        .CLKOUT1_DIVIDE       (20), // 6
        .CLKOUT1_PHASE        (0.000),
        .CLKOUT1_DUTY_CYCLE   (0.500),
        .CLKIN1_PERIOD        (12.345) // 3.703
    )
    TXPLL_INST
    (
        // Output clocks
        .CLKFBOUT            (clkfb_from_txpll),
        .CLKOUT0             (txusrclk_from_txpll),
        .CLKOUT1             (txusrclk2_from_txpll),
        .CLKOUT2             (),
        .CLKOUT3             (),
        .CLKOUT4             (),
        .CLKOUT5             (),
        
        // Input clock control
        .CLKFBIN             (clkfb_from_txpll),
        .CLKIN1              (txoutclk_from_buf),
        .CLKIN2              (1'b0),
        
        // Tied to always select the primary input clock
        .CLKINSEL            (1'b1),
        
        // Ports for dynamic reconfiguration
        .DADDR               (DRP_ADR_IN[(5*9)+:7]),
        .DCLK                (SYS_CLK_IN),
        .DEN                 (DRP_EN_IN[5]),
        .DI                  (DRP_DAT_IN[(5*16)+:16]),
        .DO                  (DRP_DAT_OUT[(5*16)+:16]),
        .DRDY                (DRP_RDY_OUT[5]),
        .DWE                 (DRP_WR_IN[5]),
        
        // Other control and status signals
        .LOCKED              (lock_from_txpll),
        .PWRDWN              (1'b0),
        .RST                 (rst_to_txpll)
    );

    // Reset
    assign rst_to_txpll = TX_PLL_RST_IN || txpll_rst_from_phy;

    // TXUSRCLK Buffer
    BUFG 
    TXUSRCLK_BUF_INST 
    (
      .I    (txusrclk_from_txpll),    // 1-bit input: Clock input.
      .O    (txusrclk_from_buf)     // 1-bit output: Clock output.
    );

    // TXUSR2CLK Buffer
    BUFG 
    TXUSRCLK2_BUF_INST 
    (
      .I    (txusrclk2_from_txpll),    // 1-bit input: Clock input.
      .O    (txusrclk2_from_buf)     // 1-bit output: Clock output.
    );

    // RX PLL
    // The GT is operated in 4 bytes mode
    // The RXPLL creates the RXUSRCLK and RXUSRCLK2
    // See RXUSRCLK and RXUSRCLK2 generation on page 214 of UG482
    PLLE2_ADV
    #(
        .BANDWIDTH            ("OPTIMIZED"),
        .COMPENSATION         ("ZHOLD"),
        .STARTUP_WAIT         ("FALSE"),
        .DIVCLK_DIVIDE        (1),
        .CLKFBOUT_MULT        (3),
        .CLKFBOUT_PHASE       (0.000),
        .CLKOUT0_DIVIDE       (3),
        .CLKOUT0_PHASE        (0.000),
        .CLKOUT0_DUTY_CYCLE   (0.500),
        .CLKOUT1_DIVIDE       (6),
        .CLKOUT1_PHASE        (0.000),
        .CLKOUT1_DUTY_CYCLE   (0.500),
        .CLKIN1_PERIOD        (3.703)
    )
    RXPLL_INST
    (
        // Output clocks
        .CLKFBOUT            (clkfb_from_rxpll),
        .CLKOUT0             (rxusrclk_from_rxpll),
        .CLKOUT1             (rxusrclk2_from_rxpll),
        .CLKOUT2             (),
        .CLKOUT3             (),
        .CLKOUT4             (),
        .CLKOUT5             (),
        
        // Input clock control
        .CLKFBIN             (clkfb_from_rxpll),
        .CLKIN1              (rxoutclk_from_buf),
        .CLKIN2              (1'b0),
        
        // Tied to always select the primary input clock
        .CLKINSEL            (1'b1),
        
        // Ports for dynamic reconfiguration
        .DADDR               (DRP_ADR_IN[(6*9)+:7]),
        .DCLK                (SYS_CLK_IN),
        .DEN                 (DRP_EN_IN[6]),
        .DI                  (DRP_DAT_IN[(6*16)+:16]),
        .DO                  (DRP_DAT_OUT[(6*16)+:16]),
        .DRDY                (DRP_RDY_OUT[6]),
        .DWE                 (DRP_WR_IN[6]),
        
        // Other control and status signals
        .LOCKED              (lock_from_rxpll),
        .PWRDWN              (1'b0),
        .RST                 (rst_to_rxpll)
    );

    // Reset
    assign rst_to_rxpll = RX_PLL_RST_IN || rxpll_rst_from_phy;

    // RXUSRCLK Buffer
    BUFG 
    RXUSRCLK_BUF_INST 
    (
      .I    (rxusrclk_from_rxpll),    // 1-bit input: Clock input.
      .O    (rxusrclk_from_buf)     // 1-bit output: Clock output.
    );

    // RXUSR2CLK Buffer
    BUFG 
    RXUSRCLK2_BUF_INST 
    (
      .I    (rxusrclk2_from_rxpll),    // 1-bit input: Clock input.
      .O    (rxusrclk2_from_buf)     // 1-bit output: Clock output.
    );

// Outputs
    assign TX_USRCLK_OUT    = txusrclk2_from_buf;
    assign RX_USRCLK_OUT    = rxusrclk2_from_buf;
    assign TX_RST_DONE_OUT  = &tx_rst_done_from_phy;
    assign RX_RST_DONE_OUT  = &rx_rst_done_from_phy;
    assign GT_REFCLK_OUT    = clk2_from_refclk_buf;
    assign GT_PLL_LOCK_OUT  = pll_lock_from_common;
    assign TX_PLL_LOCK_OUT  = lock_from_txpll;
    assign RX_PLL_LOCK_OUT  = lock_from_rxpll;

endmodule

`default_nettype wire
