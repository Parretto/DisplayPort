/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP Application Header
    (c) 2021 - 2024 by Parretto B.V.

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

#pragma once

// Defines
#define VENDOR_AMD                  	0
#define VENDOR_LSC                  	1
#define VENDOR_INT                  	2

#define BOARD_AMD_ZCU102           	0
#define BOARD_LSC_LFCPNX                1
#define BOARD_INT_C10GX                 2
#define BOARD_INT_A10GX                 3
#define BOARD_TB_A7_200T_IMG            4

//#define ADVANCED
#define AUTO_COLORBAR

#define SYS_CLK_FREQ                    50000000
#define I2C_FREQ                        400000
#define I2C_BEAT                        SYS_CLK_FREQ / I2C_FREQ

// Interrupt handlers
#define DPTX_IRQ_HANDLER
#define DPRX_IRQ_HANDLER

// Pixels per clock
// Xilinx ZCU102
#if (BOARD == BOARD_AMD_ZCU102)
     #define PPC                        2

// Lattice CertusPro-NX
#elif (BOARD == BOARD_LSC_LFCPNX)
     #define PPC                        4

// Intel Cyclone 10GX
#elif (BOARD == BOARD_INT_C10GX)
     #define PPC                        2

// Intel Arria 10GX
#elif (BOARD == BOARD_INT_A10GX)
     #define PPC                        2

// Inrevium TB-A7-200T-IMG
#elif (BOARD == BOARD_TB_A7_200T_IMG)
     #define PPC                        4
#endif

// The scaler only operates in 4 pixel per clock
/*
#if (PPC == 4)
     #define SCALER
#endif
*/

// MST
//#define MST              

// Base address
#define PRT_DEV_BASE 				0x80000000
#define PRT_PIO_BASE               	PRT_DEV_BASE + (0 << 18)
#define PRT_UART_BASE              	PRT_DEV_BASE + (1 << 18)
#define PRT_TMR_BASE                    PRT_DEV_BASE + (2 << 18)
#define PRT_I2C_BASE               	PRT_DEV_BASE + (3 << 18)
#define PRT_DPTX_BASE              	PRT_DEV_BASE + (4 << 18)
#define PRT_DPRX_BASE              	PRT_DEV_BASE + (5 << 18)
#define PRT_VTB0_BASE               	PRT_DEV_BASE + (6 << 18)
#define PRT_VTB1_BASE               	PRT_DEV_BASE + (7 << 18)
#define PRT_PHY_BASE               	PRT_DEV_BASE + (8 << 18)
#define PRT_SCALER_BASE                 PRT_DEV_BASE + (9 << 18)

// PIO in
// AMD ZCU102
#if (BOARD == BOARD_AMD_ZCU102)
     #define PIO_IN_PHY_REFCLK_LOCK    	     (1 << 0)
     #define PIO_IN_VID_REFCLK_LOCK        	(1 << 1)
     #define PIO_IN_PHY_PWRGD                (1 << 2)
     #define PIO_IN_PHY_CPLL_LOCK            (1 << 3)
     #define PIO_IN_PHY_QPLL_LOCK            (1 << 4)
     #define PIO_IN_PHYTX_PMA_RST_DONE       (1 << 5)
     #define PIO_IN_PHYTX_RST_DONE  		(1 << 6)
     #define PIO_IN_PHYRX_PMA_RST_DONE       (1 << 7)
     #define PIO_IN_PHYRX_RST_DONE  		(1 << 8)
     #define PIO_IN_PHYRX_PRBS_LOCK_SHIFT	9

// Lattice CertusPro-NX
#elif (BOARD == BOARD_LSC_LFCPNX)
     #define PIO_IN_PHY_REFCLK_LOCK          (1 << 0)
     #define PIO_IN_VID_REFCLK_LOCK          (1 << 1)
     #define PIO_IN_PHY_RDY                  (1 << 2)

// Intel Cyclone 10 GX
#elif (BOARD == BOARD_INT_C10GX)
     #define PIO_IN_PHY_REFCLK_LOCK          (1 << 0)
     #define PIO_IN_VID_REFCLK_LOCK          (1 << 1)
     #define PIO_IN_PHY_PLL_CAL_BUSY         (1 << 2)
     #define PIO_IN_PHY_PLL_LOCKED           (1 << 3)
     #define PIO_IN_PHY_TX_CAL_BUSY          (1 << 4)
     #define PIO_IN_PHY_RX_CAL_BUSY          (1 << 5)
     #define PIO_IN_PHY_RX_CDR_LOCK          (1 << 6)

// Intel Arria 10 GX
#elif (BOARD == BOARD_INT_A10GX)
     #define PIO_IN_PHY_REFCLK_LOCK          (1 << 0)
     #define PIO_IN_VID_REFCLK_LOCK          (1 << 1)
     #define PIO_IN_PHY_PLL_CAL_BUSY         (1 << 2)
     #define PIO_IN_PHY_PLL_LOCKED           (1 << 3)
     #define PIO_IN_PHY_TX_CAL_BUSY          (1 << 4)
     #define PIO_IN_PHY_RX_CAL_BUSY          (1 << 5)
     #define PIO_IN_PHY_RX_CDR_LOCK          (1 << 6)

// Inrevium TB-A7-200T-IMG
#elif (BOARD == BOARD_TB_A7_200T_IMG)
     #define PIO_IN_PHY_REFCLK_LOCK    	     (1 << 0)
     #define PIO_IN_VID_REFCLK_LOCK        	(1 << 1)
     #define PIO_IN_PHY_GTTX_RST_DONE  		(1 << 2)
     #define PIO_IN_PHY_GTRX_RST_DONE  		(1 << 3)
     #define PIO_IN_PHY_GTPLL0_LOCK  		(1 << 4)
     #define PIO_IN_PHY_GTPLL1_LOCK  		(1 << 5)
     #define PIO_IN_PHY_TXPLL_LOCK  		(1 << 6)
     #define PIO_IN_PHY_RXPLL_LOCK  		(1 << 7)
#endif

// PIO out
// AMD ZCU102
#if (BOARD == BOARD_AMD_ZCU102)
     #define PIO_OUT_TENTIVA_CLK_SEL  	     (1 << 0)
     #define PIO_OUT_DPTX_RST      		(1 << 1)
     #define PIO_OUT_DPRX_RST      		(1 << 2)
     #define PIO_OUT_PHY_CPLL_RST            (1 << 3)
     #define PIO_OUT_PHY_QPLL_RST            (1 << 4)
     #define PIO_OUT_PHYTX_RST      		(1 << 5)
     #define PIO_OUT_PHYTX_DIV_RST           (1 << 6)
     #define PIO_OUT_PHYTX_USR_RDY           (1 << 7)
     #define PIO_OUT_PHYRX_RST               (1 << 8)
     #define PIO_OUT_PHYRX_DIV_RST           (1 << 9)
     #define PIO_OUT_PHYRX_USR_RDY           (1 << 10)
     #define PIO_OUT_PHYTX_LINERATE_SHIFT    11
     #define PIO_OUT_PHYTX_VOLT_SHIFT        13
     #define PIO_OUT_PHYTX_PRE_SHIFT         18
     #define PIO_OUT_PHY_PRBS_EN  		     (1 << 23)
     #define PIO_OUT_PHYRX_PRBS_CLR 		(1 << 24)
     #define PIO_OUT_PHYRX_PRBS_ERR		(1 << 25)
     #define PIO_OUT_PHYRX_EQU_SEL           (1 << 26)
     #define PIO_OUT_DEBUG_0                 (1 << 27)
     #define PIO_OUT_DEBUG_1                 (1 << 28)
     #define PIO_OUT_DEBUG_2                 (1 << 29)
     #define PIO_OUT_DEBUG_3                 (1 << 30)

// Lattice CertusPro-NX
#elif (BOARD == BOARD_LSC_LFCPNX)
     #define PIO_OUT_TENTIVA_CLK_SEL         (1 << 0)
     #define PIO_OUT_DPTX_RST                (1 << 1)
     #define PIO_OUT_DPRX_RST                (1 << 2)
     #define PIO_OUT_PHYTX_RST               (1 << 4)
     #define PIO_OUT_PHYRX_RST               (1 << 5)
     #define PIO_OUT_DEBUG_0                 (1 << 26)
     #define PIO_OUT_DEBUG_1                 (1 << 27)
     #define PIO_OUT_DEBUG_2                 (1 << 28)
     #define PIO_OUT_DEBUG_3                 (1 << 29)

// Intel Cyclone 10GX
#elif (BOARD == BOARD_INT_C10GX)
     #define PIO_OUT_TENTIVA_CLK_SEL         (1 << 0)
     #define PIO_OUT_DPTX_RST                (1 << 1)
     #define PIO_OUT_DPRX_RST                (1 << 2)
     #define PIO_OUT_PHY_PLL_PWRDWN          (1 << 3)
     #define PIO_OUT_PHY_TX_ARST             (1 << 4)
     #define PIO_OUT_PHY_TX_DRST             (1 << 5)
     #define PIO_OUT_PHY_RX_ARST             (1 << 6)
     #define PIO_OUT_PHY_RX_DRST             (1 << 7)
     #define PIO_OUT_DEBUG_0                 (1 << 26)
     #define PIO_OUT_DEBUG_1                 (1 << 27)
     #define PIO_OUT_DEBUG_2                 (1 << 28)
     #define PIO_OUT_DEBUG_3                 (1 << 29)

// Intel Arria 10GX
#elif (BOARD == BOARD_INT_A10GX)
     #define PIO_OUT_TENTIVA_CLK_SEL         (1 << 0)
     #define PIO_OUT_DPTX_RST                (1 << 1)
     #define PIO_OUT_DPRX_RST                (1 << 2)
     #define PIO_OUT_PHY_PLL_PWRDWN          (1 << 3)
     #define PIO_OUT_PHY_TX_ARST             (1 << 4)
     #define PIO_OUT_PHY_TX_DRST             (1 << 5)
     #define PIO_OUT_PHY_RX_ARST             (1 << 6)
     #define PIO_OUT_PHY_RX_DRST             (1 << 7)
     #define PIO_OUT_DEBUG_0                 (1 << 26)
     #define PIO_OUT_DEBUG_1                 (1 << 27)
     #define PIO_OUT_DEBUG_2                 (1 << 28)
     #define PIO_OUT_DEBUG_3                 (1 << 29)

// Inrevium TB-A7-200T-IMG
#elif (BOARD == BOARD_TB_A7_200T_IMG)
     #define PIO_OUT_TENTIVA_CLK_SEL  	     (1 << 0)
     #define PIO_OUT_DPTX_RST      		(1 << 1)
     #define PIO_OUT_DPRX_RST      		(1 << 2)
     #define PIO_OUT_PHY_GTTX_RST            (1 << 3)
     #define PIO_OUT_PHY_GTRX_RST            (1 << 4)
     #define PIO_OUT_PHY_TXPLL_RST           (1 << 5)
     #define PIO_OUT_PHY_RXPLL_RST           (1 << 6)
     #define PIO_OUT_PHY_TX_VOLT_SHIFT       7
     #define PIO_OUT_PHY_TX_PRE_SHIFT        11
     #define PIO_OUT_PHY_TX_RATE_SHIFT       16
     #define PIO_OUT_PHY_RX_RATE_SHIFT       19
#endif

// ZCU102
#define ZCU102_I2C_MUX_U34_ADR          0x74
#define ZCU102_I2C_MUX_U135_ADR         0x75

// Data structure
typedef struct {
     bool colorbar;
     bool mst;
} prt_dp_app_tx_struct;

typedef struct {
     bool pass;
} prt_dp_app_rx_struct;

typedef struct {
     prt_dp_app_tx_struct tx;
     prt_dp_app_rx_struct rx;
     uint8_t vtb_cr_p_gain;
     uint16_t vtb_cr_i_gain;
} prt_dp_app_struct;

// Prototypes
void debug_pin (uint8_t pin);
void dp_reset (uint8_t id);
void show_menu (void);

// Callback functions
void dptx_hpd_cb (prt_dp_ds_struct *dp);
void dp_sta_cb (prt_dp_ds_struct *dp);
void dptx_phy_rate_cb (prt_dp_ds_struct *dp);
void dprx_phy_rate_cb (prt_dp_ds_struct *dp);
void dptx_phy_vap_cb (prt_dp_ds_struct *dp);
void dp_trn_cb (prt_dp_ds_struct *dp);
void dp_lnk_cb (prt_dp_ds_struct *dp);
void dp_vid_cb (prt_dp_ds_struct *dp);
void dprx_msa_cb (prt_dp_ds_struct *dp);
void dp_debug_cb (prt_dp_ds_struct *dp);

// PHY
void phy_set_tx_linerate (uint8_t linerate);
void phy_set_tx_vap (uint8_t volt, uint8_t pre);
void phy_set_rx_linerate (uint8_t linerate);

// VTB
void vtb_status (void);

// Operation
prt_sta_type vtb_colorbar (prt_bool force);
prt_sta_type vtb_pass (void);
prt_sta_type scale (void);

// EDID
void set_edid (prt_bool user);

// PRBS
void prbs (void);
void prbs_menu (void);

// Log

// ZCU102
prt_sta_type xlx_zcu102_fmc_i2c_mux (void);
