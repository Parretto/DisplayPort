/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: PHY Intel Cyclone / Arria 10GX Header
    (c) 2023 - 2024 by Parretto B.V.

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

// Device structure
typedef struct {
  prt_u32 ctl; 	      // Control
  prt_u32 sta;	      // Status
  prt_u32 rcfg_adr;   // Reconfig address
  prt_u32 rcfg_dat;   // Reconfig data
} prt_phy_int_dev_struct;

// Transceiver pre-calibrated configuration data
typedef struct {
  prt_u8 dat [4][4][13];       // line rate [4], channel [4], registers [13]
} prt_phy_int_cfg_struct;

// Data structure
typedef struct {
  volatile prt_phy_int_dev_struct *dev;
  prt_pio_ds_struct *pio;                // PIO
  prt_tmr_ds_struct *tmr;                // Timer
  prt_u32 pio_phy_pll_pwrdwn;
  prt_u32 pio_phy_pll_cal_busy;
  prt_u32 pio_phy_pll_lock;
  prt_u32 pio_phy_tx_drst;
  prt_u32 pio_phy_tx_arst;
  prt_u32 pio_phy_tx_cal_busy;
  prt_u32 pio_phy_rx_drst;
  prt_u32 pio_phy_rx_arst;
  prt_u32 pio_phy_rx_cal_busy;
  prt_u32 pio_phy_rx_cdr_lock;
  prt_phy_int_cfg_struct cfg;        // Configuration data 
} prt_phy_int_ds_struct;

// Defines
// Control register
#define PRT_PHY_INT_DEV_CTL_WR              (1 << 0)
#define PRT_PHY_INT_DEV_CTL_RD              (1 << 1)

// Status register
#define PRT_PHY_INT_DEV_STA_BUSY            (1 << 0)
#define PRT_PHY_INT_DEV_STA_RDY             (1 << 1)

#define PRT_PHY_INT_RCFG_PORTS    				  5
#define PRT_PHY_INT_RCFG_ADR_SHIFT				  3

#define PRT_PHY_INT_RST_PULSE               70         // PHY reset pulse in us 
#define PRT_PHY_INT_RECAL_TIMEOUT           100000     // PHY PLL recalibration timeout in us
#define PRT_PHY_INT_LOCK_TIMEOUT            10000      // PHY PLL lock timeout in us

#define PRT_PHY_INT_LINERATE_1620           1
#define PRT_PHY_INT_LINERATE_1485           2
#define PRT_PHY_INT_LINERATE_2700           3
#define PRT_PHY_INT_LINERATE_5400           4
#define PRT_PHY_INT_LINERATE_8100           5

#define PRT_PHY_INT_TX_PLL_PORT             0
#define PRT_PHY_INT_XCVR_PORT               1

// Prototype
void prt_phy_int_init (prt_phy_int_ds_struct *phy, prt_pio_ds_struct *pio, prt_tmr_ds_struct *tmr, prt_u32 base, 
prt_u32 pio_phy_pll_pwrdwn, prt_u32 pio_phy_pll_cal_busy, prt_u32 pio_phy_pll_lock,
prt_u32 pio_phy_tx_cal_busy, prt_u32 pio_phy_tx_drst,  prt_u32 pio_phy_tx_arst,
prt_u32 pio_phy_rx_cal_busy, prt_u32 pio_phy_rx_arst,  prt_u32 pio_phy_rx_drst, prt_u32 pio_phy_rx_cdr_lock);
prt_u32 prt_phy_int_rd (prt_phy_int_ds_struct *phy, prt_u8 port, prt_u16 adr);
void prt_phy_int_wr (prt_phy_int_ds_struct *phy, prt_u8 port, prt_u16 adr, prt_u32 dat);
void prt_phy_int_rmw (prt_phy_int_ds_struct *phy, prt_u8 port, prt_u16 adr, prt_u32 msk, prt_u32 dat);
void prt_phy_int_tx_vap (prt_phy_int_ds_struct *phy, prt_u8 volt, prt_u8 pre);
void prt_phy_int_tx_rate (prt_phy_int_ds_struct *phy, prt_u8 rate);
void prt_phy_int_tx_pll_cfg (prt_phy_int_ds_struct *phy, prt_u8 rate);
void prt_phy_int_tx_pll_recal (prt_phy_int_ds_struct *phy);
void prt_phy_int_tx_rst (prt_phy_int_ds_struct *phy);
void prt_phy_int_rx_rate (prt_phy_int_ds_struct *phy, prt_u8 rate);
void prt_phy_int_rx_cfg_init (prt_phy_int_ds_struct *phy, prt_u8 rate);
void prt_phy_int_rx_cfg_cal (prt_phy_int_ds_struct *phy, prt_u8 rate);
void prt_phy_int_rx_recal (prt_phy_int_ds_struct *phy);
void prt_phy_int_rx_rst (prt_phy_int_ds_struct *phy);
void prt_phy_int_setup (prt_phy_int_ds_struct *phy, prt_u8 rate);