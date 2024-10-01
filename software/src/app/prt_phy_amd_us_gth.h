/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: PHY AMD UltraScale GTH Header
    (c) 2021 - 2024 by Parretto B.V.
   
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

// Device structure
typedef struct {
  prt_u32 ctl; 	          // Control
  prt_u32 sta;	          // Status
  prt_u32 drp;            // DRP
  prt_u32 pio_din;        // PIO Data in
  prt_u32 pio_dout_set;   // PIO Data out set
  prt_u32 pio_dout_clr;   // PIO Data out clear
  prt_u32 pio_dout;       // PIO Data out
  prt_u32 pio_msk;        // PIO Mask
} prt_phy_amd_dev_struct;

// Data structure
typedef struct {
  volatile prt_phy_amd_dev_struct *dev;  // Device
  prt_tmr_ds_struct *tmr;                // Timer 
} prt_phy_amd_ds_struct;

// Defines
// Control register
#define PRT_PHY_AMD_DEV_CTL_WR          (1 << 0)
#define PRT_PHY_AMD_DEV_CTL_RD          (1 << 1)

// Status register
#define PRT_PHY_AMD_DEV_STA_BUSY        (1 << 0)
#define PRT_PHY_AMD_DEV_STA_RDY         (1 << 1)

#define PRT_PHY_AMD_DRP_ADR_SHIFT				3
#define PRT_PHY_AMD_DRP_DAT_SHIFT				13

#define PRT_PHY_AMD_RST_PULSE           2                // PHY reset pulse in us
#define PRT_PHY_AMD_RST_TIMEOUT         100000           // PHY reset timeout in us

#define PRT_PHY_AMD_LINERATE_1620       1
#define PRT_PHY_AMD_LINERATE_1485       2
#define PRT_PHY_AMD_LINERATE_2700       3
#define PRT_PHY_AMD_LINERATE_5400       4
#define PRT_PHY_AMD_LINERATE_8100       5

// PIO
#define PRT_PHY_AMD_PIO_IN_PWRGD                    (1 << 0)
#define PRT_PHY_AMD_PIO_IN_CPLL_LOCK                (1 << 1)
#define PRT_PHY_AMD_PIO_IN_QPLL_LOCK                (1 << 2)
#define PRT_PHY_AMD_PIO_IN_TX_PMA_RST_DONE          (1 << 3)
#define PRT_PHY_AMD_PIO_IN_TX_RST_DONE              (1 << 4)
#define PRT_PHY_AMD_PIO_IN_RX_PMA_RST_DONE          (1 << 5)
#define PRT_PHY_AMD_PIO_IN_RX_RST_DONE  		        (1 << 6)

#define PRT_PHY_AMD_PIO_OUT_CPLL_RST                (1 << 0)
#define PRT_PHY_AMD_PIO_OUT_QPLL_RST                (1 << 1)
#define PRT_PHY_AMD_PIO_OUT_TX_RST      		        (1 << 2)
#define PRT_PHY_AMD_PIO_OUT_TX_DIV_RST              (1 << 3)
#define PRT_PHY_AMD_PIO_OUT_TX_USR_RDY              (1 << 4)
#define PRT_PHY_AMD_PIO_OUT_RX_RST                  (1 << 5)
#define PRT_PHY_AMD_PIO_OUT_RX_DIV_RST              (1 << 6)
#define PRT_PHY_AMD_PIO_OUT_RX_USR_RDY              (1 << 7)
#define PRT_PHY_AMD_PIO_OUT_TX_LINERATE_SHIFT       8
#define PRT_PHY_AMD_PIO_OUT_TX_VOLT_SHIFT           10
#define PRT_PHY_AMD_PIO_OUT_TX_PRE_SHIFT            15

//#define PRT_PHY_AMD_PIO_IN_TX_RST_DONE              (1 << 3)
//#define PRT_PHY_AMD_PIO_IN_RX_RST_DONE  		        (1 << 4)

//#define PRT_PHY_AMD_PIO_OUT_TX_PLL_AND_DP_RST       (1 << 0)
//#define PRT_PHY_AMD_PIO_OUT_TX_DP_RST               (1 << 1)
//#define PRT_PHY_AMD_PIO_OUT_RX_PLL_AND_DP_RST       (1 << 2)
//#define PRT_PHY_AMD_PIO_OUT_RX_DP_RST               (1 << 3)

//#define PRT_PHY_AMD_PIO_OUT_TX_LINERATE_SHIFT       4
//#define PRT_PHY_AMD_PIO_OUT_TX_VOLT_SHIFT           6
//#define PRT_PHY_AMD_PIO_OUT_TX_PRE_SHIFT            11

// Prototype
void prt_phy_amd_init (prt_phy_amd_ds_struct *phy, prt_tmr_ds_struct *tmr, prt_u32 base);
prt_u16 prt_phy_amd_drp_rd (prt_phy_amd_ds_struct *phy, prt_u8 port, prt_u16 adr);
void prt_phy_amd_drp_wr (prt_phy_amd_ds_struct *phy, prt_u8 port, prt_u16 adr, prt_u16 dat);
prt_sta_type prt_phy_amd_tx_rate (prt_phy_amd_ds_struct *phy, prt_u8 rate);
prt_sta_type prt_phy_amd_rx_rate (prt_phy_amd_ds_struct *phy, prt_u8 rate, prt_u8 ssc);
prt_sta_type prt_phy_amd_rx_rst (prt_phy_amd_ds_struct *phy);

prt_u8 prt_phy_amd_encode_cpll_fbdiv (prt_u8 fbdiv);
prt_u8 prt_phy_amd_encode_cpll_fbdiv_45 (prt_u8 fbdiv_45);
prt_u8 prt_phy_amd_encode_cpll_refclk_div (prt_u8 cpll_refclk_div);
prt_u8 prt_phy_amd_encode_txout_div (prt_u8 txout_div);
prt_u8 prt_phy_amd_encode_qpll_fbdiv (prt_u8 fbdiv);
prt_u8 prt_phy_amd_encode_qpll_refclk_div (prt_u8 qpll_refclk_div);
prt_u8 prt_phy_amd_encode_rxout_div (prt_u8 rxout_div);

//prt_sta_type prt_phy_amd_tx_pll_and_dp_rst (prt_phy_amd_ds_struct *phy);
//prt_sta_type prt_phy_amd_tx_dp_rst (prt_phy_amd_ds_struct *phy);
prt_sta_type prt_phy_amd_txrst_set (prt_phy_amd_ds_struct *phy);
prt_sta_type prt_phy_amd_txrst_clr (prt_phy_amd_ds_struct *phy);

//prt_sta_type prt_phy_amd_rx_pll_and_dp_rst (prt_phy_amd_ds_struct *phy);
//prt_sta_type prt_phy_amd_rx_dp_rst (prt_phy_amd_ds_struct *phy);
prt_sta_type prt_phy_amd_rxrst_set (prt_phy_amd_ds_struct *phy);
prt_sta_type prt_phy_amd_rxrst_clr (prt_phy_amd_ds_struct *phy);

//prt_sta_type prt_phy_amd_rst (prt_phy_amd_ds_struct *phy, prt_u32 PHY_RST, prt_u32 PHY_RST_DONE);
prt_sta_type prt_phy_amd_rst_set (prt_phy_amd_ds_struct *phy, prt_u32 PLL_RST, prt_u32 PHY_RST, prt_u32 PHY_DIV_RST, prt_u32 PHY_USR_RDY);
prt_sta_type prt_phy_amd_rst_clr (prt_phy_amd_ds_struct *phy, prt_u32 PLL_RST, prt_u32 PLL_LOCK, prt_u32 PHY_RST, prt_u32 PHY_DIV_RST, prt_u32 PMA_RST_DONE, prt_u32 PHY_USR_RDY, prt_u32 PHY_RST_DONE);

void prt_phy_amd_cpll_cal (prt_phy_amd_ds_struct *phy, prt_u8 rate);
void prt_phy_amd_tx_vap (prt_phy_amd_ds_struct *phy, prt_u8 volt, prt_u8 pre);
prt_u8 prt_phy_amd_get_txpll_lock (prt_phy_amd_ds_struct *phy);
prt_u8 prt_phy_amd_get_rxpll_lock (prt_phy_amd_ds_struct *phy);
void prt_phy_amd_prbs_gen (prt_phy_amd_ds_struct *phy, prt_u8 en);
void prt_phy_amd_prbs_clr (prt_phy_amd_ds_struct *phy);
void prt_phy_amd_prbs_err (prt_phy_amd_ds_struct *phy);
prt_bool prt_phy_amd_prbs_lock (prt_phy_amd_ds_struct *phy, prt_u8 lane);
prt_u32 prt_phy_amd_prbs_cnt (prt_phy_amd_ds_struct *phy, prt_u8 lane);
void prt_phy_amd_equ_sel (prt_phy_amd_ds_struct *phy, prt_u8 lpm);
void prt_phy_amd_pio_dat_set (prt_phy_amd_ds_struct *phy, prt_u32 dat);
void prt_phy_amd_pio_dat_clr (prt_phy_amd_ds_struct *phy, prt_u32 dat);
void prt_phy_amd_pio_dat_msk (prt_phy_amd_ds_struct *phy, prt_u32 dat, prt_u32 msk);
prt_u32 prt_phy_amd_pio_dat_get (prt_phy_amd_ds_struct *phy);
void prt_phy_amd_cdr_dump (prt_phy_amd_ds_struct *phy);
void prt_phy_amd_qpll_dump (prt_phy_amd_ds_struct *phy);