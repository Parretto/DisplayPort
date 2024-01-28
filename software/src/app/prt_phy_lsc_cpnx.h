/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: PHY Lattice CertusPro-NX Header
    (c) 2021 - 2024 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
	  v1.1 - Removed DP application and driver header dependency

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
  prt_u32 ctl; 	 // Control
  prt_u32 sta;	 // Status
  prt_u32 lmmi;  // LMMI interface
} prt_phy_lsc_dev_struct;

// Data structure
typedef struct {
  volatile prt_phy_lsc_dev_struct *dev;
  prt_pio_ds_struct *pio;                // PIO
  prt_tmr_ds_struct *tmr;                // Timer
  prt_u32 pio_phytx_rst;
  prt_u32 pio_phyrx_rst;
  prt_u32 pio_phy_rdy;
} prt_phy_lsc_ds_struct;

// Defines
// Control register
#define PRT_PHY_LSC_DEV_CTL_WR              (1 << 0)
#define PRT_PHY_LSC_DEV_CTL_RD              (1 << 1)

// Status register
#define PRT_PHY_LSC_DEV_STA_BUSY            (1 << 0)
#define PRT_PHY_LSC_DEV_STA_RDY             (1 << 1)

#define PRT_PHY_LSC_LMMI_ADR_SHIFT				  2
#define PRT_PHY_LSC_LMMI_DAT_SHIFT				  11

#define PRT_PHY_LSC_REG0E_NO_FCMP           (1 << 3)

#define PRT_PHY_LSC_REG64_PRBS_GEN          (1 << 0)
#define PRT_PHY_LSC_REG64_PRBS_CHK          (1 << 6)
#define PRT_PHY_LSC_REG64_LPBK_EN           (1 << 1)

#define PRT_PHY_LSC_REG66_TXPLL_INIT        (1 << 2)
#define PRT_PHY_LSC_REG66_RXPLL_INIT        (1 << 3)
#define PRT_PHY_LSC_REG66_TXPLL_RST         (1 << 4)
#define PRT_PHY_LSC_REG66_RXPLL_RST         (1 << 5)

#define PRT_PHY_LSC_REG74_TX_POLINV         (1 << 5)
#define PRT_PHY_LSC_REG74_RX_POLINV         (1 << 6)

#define PRT_PHY_LSC_REG7F_TXCLKSTABLE       (1 << 4)
#define PRT_PHY_LSC_REG7F_RXCLKSTABLE       (1 << 5)

#define PRT_PHY_LSC_REG120_RX_BOND_MASK     (1 << 6)

#define PRT_PHY_LSC_RST_PULSE               2         // PHY reset pulse in us 
#define PRT_PHY_LSC_LOCK_TIMEOUT            10000        // PHY PLL lock timeout in us

#define PRT_PHY_LSC_LINERATE_1620           1
#define PRT_PHY_LSC_LINERATE_1485           2
#define PRT_PHY_LSC_LINERATE_2700           3
#define PRT_PHY_LSC_LINERATE_5400           4
#define PRT_PHY_LSC_LINERATE_8100           5

// Prototype
void prt_phy_lsc_init (prt_phy_lsc_ds_struct *phy, prt_pio_ds_struct *pio, prt_tmr_ds_struct *tmr, prt_u32 base, 
  prt_u32 pio_phytx_rst, prt_u32 pio_phyrx_rst, prt_u32 pio_phy_rdy);
prt_u8 prt_phy_lsc_rd (prt_phy_lsc_ds_struct *phy, prt_u8 port, prt_u16 adr);
void prt_phy_lsc_wr (prt_phy_lsc_ds_struct *phy, prt_u8 port, prt_u16 adr, prt_u8 dat);
prt_bool prt_phy_lsc_get_txpll_lock (prt_phy_lsc_ds_struct *phy);
prt_bool prt_phy_lsc_get_rxpll_lock (prt_phy_lsc_ds_struct *phy);
void prt_phy_lsc_tx_vap (prt_phy_lsc_ds_struct *phy, prt_u8 volt, prt_u8 pre);
void prt_phy_lsc_txpll_rst (prt_phy_lsc_ds_struct *phy, prt_u8 rst);
void prt_phy_lsc_rxpll_rst (prt_phy_lsc_ds_struct *phy, prt_u8 rst);
prt_u8 prt_phy_lsc_enc_pll_m (prt_u8 m);
prt_u8 prt_phy_lsc_enc_pll_f (prt_u8 f);
prt_u8 prt_phy_lsc_enc_pll_n (prt_u8 n);
void prt_phy_lsc_tx_rate (prt_phy_lsc_ds_struct *phy, prt_u8 rate);
void prt_phy_lsc_rx_rate (prt_phy_lsc_ds_struct *phy, prt_u8 rate);
void prt_phy_lsc_rate (prt_phy_lsc_ds_struct *phy, prt_u8 rate, prt_u8 tx);
void prt_phy_lsc_upd (prt_phy_lsc_ds_struct *phy);
void prt_phy_lsc_tx_pol (prt_phy_lsc_ds_struct *phy, prt_u8 port, prt_u8 inv);
void prt_phy_lsc_rx_pol (prt_phy_lsc_ds_struct *phy, prt_u8 port, prt_u8 inv);
void prt_phy_lsc_txrst (prt_phy_lsc_ds_struct *phy);
void prt_phy_lsc_rxrst (prt_phy_lsc_ds_struct *phy);
void prt_phy_lsc_prbs_gen (prt_phy_lsc_ds_struct *phy, prt_u8 en);
void prt_phy_lsc_prbs_clr (prt_phy_lsc_ds_struct *phy);
prt_bool prt_phy_lsc_prbs_lock (prt_phy_lsc_ds_struct *phy, prt_u8 lane);
prt_u8 prt_phy_lsc_prbs_cnt (prt_phy_lsc_ds_struct *phy, prt_u8 lane);
void prt_phy_lsc_unbond (prt_phy_lsc_ds_struct *phy);
