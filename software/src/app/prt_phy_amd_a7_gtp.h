/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: PHY AMD Artix-7 GTP Header
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

#pragma once

// Device structure
typedef struct {
    prt_u32 ctl; 	// Control
    prt_u32 sta;	// Status
    prt_u32 itf;    // Interface
} prt_phy_amd_drp_struct;

// Data structure
typedef struct {
    volatile prt_phy_amd_drp_struct *drp;  // DRP
    prt_pio_ds_struct *pio;                // PIO
    prt_tmr_ds_struct *tmr;                // Timer
  
  // PIO bits
    prt_u32 pio_gttx_rst; 
    prt_u32 pio_gtrx_rst;
    prt_u32 pio_gttx_rst_done; 
    prt_u32 pio_gtrx_rst_done;
    prt_u32 pio_gtpll0_lock; 
    prt_u32 pio_gtpll1_lock; 
    prt_u32 pio_txpll_rst;
    prt_u32 pio_txpll_lock;
    prt_u32 pio_rxpll_rst;
    prt_u32 pio_rxpll_lock;
    prt_u32 pio_tx_volt_shift;
    prt_u32 pio_tx_pre_shift;
    prt_u32 pio_tx_rate_shift;
    prt_u32 pio_rx_rate_shift;
} prt_phy_amd_ds_struct;

// Defines
// Control register
#define PRT_PHY_AMD_DRP_CTL_WR          (1 << 0)
#define PRT_PHY_AMD_DRP_CTL_RD          (1 << 1)

// Status register
#define PRT_PHY_AMD_DRP_STA_BUSY        (1 << 0)
#define PRT_PHY_AMD_DRP_STA_RDY         (1 << 1)

#define PRT_PHY_AMD_DRP_ADR_SHIFT		3
#define PRT_PHY_AMD_DRP_DAT_SHIFT		12

#define PRT_PHY_AMD_RST_PULSE           2                // PHY reset pulse in us
#define PRT_PHY_AMD_RST_TIMEOUT         100000           // PHY reset timeout in us

#define PRT_PHY_AMD_LINERATE_1620       1
#define PRT_PHY_AMD_LINERATE_2700       2
#define PRT_PHY_AMD_LINERATE_5400       3

#define PRT_PHY_DRP_PORT_GTP_CH0        0
#define PRT_PHY_DRP_PORT_GTP_COMMON     4
#define PRT_PHY_DRP_PORT_TXPLL          5
#define PRT_PHY_DRP_PORT_RXPLL          6

// Prototype
void prt_phy_amd_init (prt_phy_amd_ds_struct *phy, prt_pio_ds_struct *pio, prt_tmr_ds_struct *tmr, prt_u32 base,
    prt_u32 pio_gttx_rst, prt_u32 pio_gtrx_rst, prt_u32 pio_gttx_rst_done, prt_u32 pio_gtrx_rst_done,
    prt_u32 pio_gtpll0_lock, prt_u32 pio_gtpll1_lock, 
    prt_u32 pio_txpll_rst, prt_u32 pio_txpll_lock, 
    prt_u32 pio_rxpll_rst, prt_u32 pio_rxpll_lock,  
    prt_u32 pio_tx_volt_shift, prt_u32 pio_tx_pre_shift,
    prt_u32 pio_tx_rate_shift, prt_u32 pio_rx_rate_shift);
prt_u16 prt_phy_amd_drp_rd (prt_phy_amd_ds_struct *phy, prt_u8 port, prt_u16 adr);
void prt_phy_amd_drp_wr (prt_phy_amd_ds_struct *phy, prt_u8 port, prt_u16 adr, prt_u16 dat);
prt_sta_type prt_phy_amd_txrst (prt_phy_amd_ds_struct *phy);
prt_sta_type prt_phy_amd_rxrst (prt_phy_amd_ds_struct *phy);
prt_sta_type prt_phy_amd_rst (prt_phy_amd_ds_struct *phy, prt_u32 RST, prt_u32 RST_DONE);
prt_sta_type prt_phy_amd_tx_rate (prt_phy_amd_ds_struct *phy, prt_u8 rate);
prt_sta_type prt_phy_amd_rx_rate (prt_phy_amd_ds_struct *phy, prt_u8 rate);
void prt_phy_amd_tx_vap (prt_phy_amd_ds_struct *phy, prt_u8 volt, prt_u8 pre);
prt_u8 prt_phy_amd_encode_pll_fbdiv (prt_u8 fbdiv);
prt_u8 prt_phy_amd_encode_pll_fbdiv_45 (prt_u8 fbdiv_45);
prt_u8 prt_phy_amd_encode_pll_refclk_div (prt_u8 refclk_div);
prt_u8 prt_phy_amd_encode_txout_div (prt_u8 txout_div);
void prt_phy_amd_pll_cfg (prt_phy_amd_ds_struct *phy, prt_u8 rate, prt_u8 drp_port, prt_u32 rst);
