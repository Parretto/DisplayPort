/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: PHY AMD Zynq UltraScale+ GTH header
    (c) 2026 by Parretto B.V.

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

#include <stdint.h>
#include "prt_types.h"

// PHY controller (prt_phy_ctl_amd_apb)
typedef struct {
    uint32_t ctl;           // Control
    uint32_t sta;           // Status
    uint32_t drp;           // DRP
    uint32_t pio_din;       // PIO data in
    uint32_t pio_dout_set;  // PIO data out set
    uint32_t pio_dout_clr;  // PIO data out clear
    uint32_t pio_dout;      // PIO data out
    uint32_t pio_msk;       // PIO mask
} prt_phy_amd_gth_dev_struct;

typedef struct {
    volatile prt_phy_amd_gth_dev_struct *dev;
} prt_phy_amd_gth_ds_struct;

// DRP write of the line rate table (prt_phy_amd_gth_dr.h)
typedef struct {
    uint8_t port;           // PRT_PHY_AMD_GTH_LANES or PRT_PHY_AMD_GTH_CMN
    uint16_t adr;           // Address
    uint16_t msk;           // Bits to write
    uint16_t dat;           // Data
} prt_phy_amd_gth_drp_struct;

#define PRT_PHY_AMD_GTH_LANES               0xff        // The four channels (DRP ports 0 - 3)
#define PRT_PHY_AMD_GTH_CMN                 4           // The common (DRP port 4)

// Line rates
#define PRT_PHY_AMD_GTH_LINERATE_1620       0
#define PRT_PHY_AMD_GTH_LINERATE_2700       1
#define PRT_PHY_AMD_GTH_LINERATE_5400       2
#define PRT_PHY_AMD_GTH_LINERATE_8100       3

// Controller
#define PRT_PHY_AMD_GTH_CTL_WR              (1U << 0)
#define PRT_PHY_AMD_GTH_CTL_RD              (1U << 1)
#define PRT_PHY_AMD_GTH_STA_BUSY            (1U << 0)
#define PRT_PHY_AMD_GTH_STA_RDY             (1U << 1)
#define PRT_PHY_AMD_GTH_DRP_ADR_SHIFT       3
#define PRT_PHY_AMD_GTH_DRP_DAT_SHIFT       13

// PIO in (see dp_ref_amd_zu4cg_xu6_st1.sv)
#define PRT_PHY_AMD_GTH_PIO_IN_PWRGD        (1U << 0)
#define PRT_PHY_AMD_GTH_PIO_IN_TX_RST_DONE  (1U << 1)
#define PRT_PHY_AMD_GTH_PIO_IN_RX_RST_DONE  (1U << 2)
#define PRT_PHY_AMD_GTH_PIO_IN_CDR_SHIFT    3
#define PRT_PHY_AMD_GTH_PIO_IN_QPLL_LOCK    (1U << 7)
#define PRT_PHY_AMD_GTH_PIO_IN_RX_CDR_STB   (1U << 8)   // RX CDR stable (reset controller)
#define PRT_PHY_AMD_GTH_PIO_IN_RX_CLK_ACT   (1U << 9)   // RX user clock active
#define PRT_PHY_AMD_GTH_PIO_IN_TX_CLK_ACT   (1U << 10)  // TX user clock active
#define PRT_PHY_AMD_GTH_PIO_IN_CPLL_SHIFT   12          // CPLL lock (per GT channel)
#define PRT_PHY_AMD_GTH_PIO_IN_RX_PMA_SHIFT 16          // RX PMA reset done (per GT channel)

// PIO out
#define PRT_PHY_AMD_GTH_PIO_OUT_TX_PLL_RST  (1U << 0)   // TX PLL and datapath reset
#define PRT_PHY_AMD_GTH_PIO_OUT_TX_DP_RST   (1U << 1)   // TX datapath reset
#define PRT_PHY_AMD_GTH_PIO_OUT_RX_PLL_RST  (1U << 2)   // RX PLL and datapath reset
#define PRT_PHY_AMD_GTH_PIO_OUT_RX_DP_RST   (1U << 3)   // RX datapath reset
#define PRT_PHY_AMD_GTH_PIO_OUT_RATE_SHIFT  4           // RX line rate (CPLL calibration)
#define PRT_PHY_AMD_GTH_PIO_OUT_VOLT_SHIFT  6           // TX voltage swing (TXDIFFCTRL)
#define PRT_PHY_AMD_GTH_PIO_OUT_PRE_SHIFT   11          // TX pre-emphasis (TXPOSTCURSOR)

// Timing (us)
#define PRT_PHY_AMD_GTH_DRP_TIMEOUT         100
#define PRT_PHY_AMD_GTH_RST_PULSE           2
#define PRT_PHY_AMD_GTH_RST_TIMEOUT         100000
#define PRT_PHY_AMD_GTH_CDR_LOCK_WAIT       300
#define PRT_PHY_AMD_GTH_CDR_LOCK_TIMEOUT    10000

// Prototypes
void prt_phy_amd_gth_init(prt_phy_amd_gth_ds_struct *phy, uintptr_t base);
uint16_t prt_phy_amd_gth_drp_rd(prt_phy_amd_gth_ds_struct *phy, uint8_t port, uint16_t adr);
void prt_phy_amd_gth_drp_wr(prt_phy_amd_gth_ds_struct *phy, uint8_t port, uint16_t adr, uint16_t dat);
uint32_t prt_phy_amd_gth_pio_get(prt_phy_amd_gth_ds_struct *phy);
prt_sta_type prt_phy_amd_gth_tx_rate(prt_phy_amd_gth_ds_struct *phy, uint8_t rate);
prt_sta_type prt_phy_amd_gth_rx_rate(prt_phy_amd_gth_ds_struct *phy, uint8_t rate);
prt_sta_type prt_phy_amd_gth_rx_dp_rst(prt_phy_amd_gth_ds_struct *phy, uint8_t lanes);
void prt_phy_amd_gth_tx_vap(prt_phy_amd_gth_ds_struct *phy, uint8_t volt, uint8_t pre);
