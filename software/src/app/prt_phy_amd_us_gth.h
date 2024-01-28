/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: PHY AMD UltraScale GTH Header
    (c) 2021 - 2024 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Removed DP application header dependency

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
  prt_u32 ctl; 	// Control
  prt_u32 sta;	// Status
  prt_u32 drp;  // DRP interface
} prt_phy_amd_dev_struct;

// Data structure
typedef struct {
  volatile prt_phy_amd_dev_struct *dev;  // PHY device
  prt_pio_ds_struct *pio;                // PIO
  prt_tmr_ds_struct *tmr;                // Timer
  
  // PIO bits
  prt_u32 pio_pwrgd;
	prt_u32 pio_cpll_rst;
  prt_u32 pio_cpll_lock; 
  prt_u32 pio_qpll_rst;
  prt_u32 pio_qpll_lock;
	prt_u32 pio_tx_rst;
  prt_u32 pio_tx_div_rst; 
  prt_u32 pio_tx_usr_rdy; 
  prt_u32 pio_tx_pma_rst_done;
  prt_u32 pio_tx_rst_done;
	prt_u32 pio_rx_rst;
  prt_u32 pio_rx_div_rst;
  prt_u32 pio_rx_usr_rdy; 
  prt_u32 pio_rx_pma_rst_done;
  prt_u32 pio_rx_rst_done;
  prt_u32 pio_tx_linerate_shift;
  prt_u32 pio_tx_volt_shift; 
  prt_u32 pio_tx_pre_shift;
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

// Prototype
void prt_phy_amd_init (prt_phy_amd_ds_struct *phy, prt_pio_ds_struct *pio, prt_tmr_ds_struct *tmr, prt_u32 base,
  prt_u32 pio_pwrgd, 
	prt_u32 pio_cpll_rst, prt_u32 pio_cpll_lock, prt_u32 pio_qpll_rst, prt_u32 pio_qpll_lock,
	prt_u32 pio_tx_rst, prt_u32 pio_tx_div_rst, prt_u32 pio_tx_usr_rdy, prt_u32 pio_tx_pma_rst_done, prt_u32 pio_tx_rst_done,
	prt_u32 pio_rx_rst, prt_u32 pio_rx_div_rst, prt_u32 pio_rx_usr_rdy, prt_u32 pio_rx_pma_rst_done, prt_u32 pio_rx_rst_done,
  prt_u32 pio_tx_linerate_shift, prt_u32 pio_tx_volt_shift, prt_u32 pio_tx_pre_shift);
prt_u16 prt_phy_amd_rd (prt_phy_amd_ds_struct *phy, prt_u8 port, prt_u16 adr);
void prt_phy_amd_wr (prt_phy_amd_ds_struct *phy, prt_u8 port, prt_u16 adr, prt_u16 dat);
prt_sta_type prt_phy_amd_tx_rate (prt_phy_amd_ds_struct *phy, prt_u8 rate);
prt_sta_type prt_phy_amd_rx_rate (prt_phy_amd_ds_struct *phy, prt_u8 rate);
prt_u8 prt_phy_amd_encode_cpll_fbdiv (prt_u8 fbdiv);
prt_u8 prt_phy_amd_encode_cpll_fbdiv_45 (prt_u8 fbdiv_45);
prt_u8 prt_phy_amd_encode_cpll_refclk_div (prt_u8 cpll_refclk_div);
prt_u8 prt_phy_amd_encode_txout_div (prt_u8 txout_div);
prt_u8 prt_phy_amd_encode_qpll_fbdiv (prt_u8 fbdiv);
prt_u8 prt_phy_amd_encode_qpll_refclk_div (prt_u8 qpll_refclk_div);
prt_u8 prt_phy_amd_encode_rxout_div (prt_u8 rxout_div);
prt_sta_type prt_phy_amd_txrst_set (prt_phy_amd_ds_struct *phy);
prt_sta_type prt_phy_amd_txrst_clr (prt_phy_amd_ds_struct *phy);
prt_sta_type prt_phy_amd_rxrst_set (prt_phy_amd_ds_struct *phy);
prt_sta_type prt_phy_amd_rxrst_clr (prt_phy_amd_ds_struct *phy);
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
