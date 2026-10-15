/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: PHY AMD Zynq UltraScale+ GTH
    (c) 2026 by Parretto B.V.

    The DP transceivers of the AMD reference design (gth_ip.tcl). As in the AMD Video PHY
    Controller, the transmitters run from QPLL1 and the receivers from the CPLL.
    A line rate is set by writing the attribute values the transceiver IP has at that rate
    (prt_phy_amd_gth_dr_<board>.h) through the DRP, followed
    by a PLL and datapath reset. The transmitter and the receiver change their rate apart.

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

#include <stdio.h>
#include "prt_zu_tmr.h"
#include "prt_phy_amd_gth.h"
#if defined(PRT_BOARD_ZU9EG_ZCU102)
    #include "prt_phy_amd_gth_dr_zu9eg_zcu102.h"
#else
    #include "prt_phy_amd_gth_dr_zu4cg_xu6_st1.h"
#endif

#define TBL(t)      {t, sizeof(t) / sizeof(t[0])}

typedef struct {
    const prt_phy_amd_gth_drp_struct *tbl;
    uint32_t len;
} tbl_struct;

static const tbl_struct tx_tbl[] = {
    TBL(prt_phy_amd_gth_tx_1620), TBL(prt_phy_amd_gth_tx_2700), TBL(prt_phy_amd_gth_tx_5400), TBL(prt_phy_amd_gth_tx_8100)
};

static const tbl_struct rx_tbl[] = {
    TBL(prt_phy_amd_gth_rx_1620), TBL(prt_phy_amd_gth_rx_2700), TBL(prt_phy_amd_gth_rx_5400), TBL(prt_phy_amd_gth_rx_8100)
};

void prt_phy_amd_gth_init(prt_phy_amd_gth_ds_struct *phy, uintptr_t base) {
    phy->dev = (volatile prt_phy_amd_gth_dev_struct *)base;
}

// Wait for the DRP access
static void drp_wait(prt_phy_amd_gth_ds_struct *phy) {
    uint64_t end = prt_zu_tmr_us() + PRT_PHY_AMD_GTH_DRP_TIMEOUT;

    while (!(phy->dev->sta & PRT_PHY_AMD_GTH_STA_RDY)) {
        if (prt_zu_tmr_us() > end) {
            printf("PHY: DRP timeout\n");
            break;
        }
    }

    // Clear ready
    phy->dev->sta = PRT_PHY_AMD_GTH_STA_RDY;
}

uint16_t prt_phy_amd_gth_drp_rd(prt_phy_amd_gth_ds_struct *phy, uint8_t port, uint16_t adr) {
    phy->dev->drp = port | ((uint32_t)adr << PRT_PHY_AMD_GTH_DRP_ADR_SHIFT);
    phy->dev->ctl = PRT_PHY_AMD_GTH_CTL_RD;
    drp_wait(phy);
    return (uint16_t)phy->dev->drp;
}

void prt_phy_amd_gth_drp_wr(prt_phy_amd_gth_ds_struct *phy, uint8_t port, uint16_t adr, uint16_t dat) {
    phy->dev->drp = port | ((uint32_t)adr << PRT_PHY_AMD_GTH_DRP_ADR_SHIFT) | ((uint32_t)dat << PRT_PHY_AMD_GTH_DRP_DAT_SHIFT);
    phy->dev->ctl = PRT_PHY_AMD_GTH_CTL_WR;
    drp_wait(phy);
}

uint32_t prt_phy_amd_gth_pio_get(prt_phy_amd_gth_ds_struct *phy) {
    return phy->dev->pio_din;
}

// Read-modify-write of the bits in the mask
static void drp_msk(prt_phy_amd_gth_ds_struct *phy, uint8_t port, uint16_t adr, uint16_t msk, uint16_t dat) {
    uint16_t val = prt_phy_amd_gth_drp_rd(phy, port, adr);
    prt_phy_amd_gth_drp_wr(phy, port, adr, (val & ~msk) | (dat & msk));
}

// Line rate table
static void tbl_wr(prt_phy_amd_gth_ds_struct *phy, const tbl_struct *t) {
    for (uint32_t i = 0; i < t->len; i++) {
        const prt_phy_amd_gth_drp_struct *w = &t->tbl[i];

        if (w->port == PRT_PHY_AMD_GTH_LANES) {
            for (uint8_t ch = 0; ch < 4; ch++)
                drp_msk(phy, ch, w->adr, w->msk, w->dat);
        } else {
            drp_msk(phy, w->port, w->adr, w->msk, w->dat);
        }
    }
}

// PIO out
static void pio_msk(prt_phy_amd_gth_ds_struct *phy, uint32_t msk, uint32_t dat) {
    phy->dev->pio_msk = msk;
    phy->dev->pio_dout = dat;
}

// Reset pulse and wait for reset done
static prt_sta_type rst(prt_phy_amd_gth_ds_struct *phy, uint32_t rst, uint32_t done, const char *name) {
    if (!(phy->dev->pio_din & PRT_PHY_AMD_GTH_PIO_IN_PWRGD)) {
        printf("PHY %s: power good is not asserted\n", name);
        return PRT_STA_FAIL;
    }

    phy->dev->pio_dout_set = rst;
    prt_zu_tmr_delay_us(PRT_PHY_AMD_GTH_RST_PULSE);
    phy->dev->pio_dout_clr = rst;

    uint64_t end = prt_zu_tmr_us() + PRT_PHY_AMD_GTH_RST_TIMEOUT;
    while (!(phy->dev->pio_din & done)) {
        if (prt_zu_tmr_us() > end) {
            printf("PHY %s: reset done timeout\n", name);
            return PRT_STA_FAIL;
        }
    }
    return PRT_STA_OK;
}

prt_sta_type prt_phy_amd_gth_tx_rate(prt_phy_amd_gth_ds_struct *phy, uint8_t rate) {
    if (rate > PRT_PHY_AMD_GTH_LINERATE_8100)
        return PRT_STA_FAIL;

    // QPLL1 and the TX attributes, then reset QPLL1 and the TX datapath
    tbl_wr(phy, &tx_tbl[rate]);
    return rst(phy, PRT_PHY_AMD_GTH_PIO_OUT_TX_PLL_RST, PRT_PHY_AMD_GTH_PIO_IN_TX_RST_DONE, "TX");
}

prt_sta_type prt_phy_amd_gth_rx_rate(prt_phy_amd_gth_ds_struct *phy, uint8_t rate) {
    if (rate > PRT_PHY_AMD_GTH_LINERATE_8100)
        return PRT_STA_FAIL;

    // The CPLL calibration in the fabric takes the expected CPLL frequency from the line rate
    pio_msk(phy, 3U << PRT_PHY_AMD_GTH_PIO_OUT_RATE_SHIFT, (uint32_t)rate << PRT_PHY_AMD_GTH_PIO_OUT_RATE_SHIFT);

    // CPLL and the RX attributes, then reset the CPLL and the RX datapath
    tbl_wr(phy, &rx_tbl[rate]);
    return rst(phy, PRT_PHY_AMD_GTH_PIO_OUT_RX_PLL_RST, PRT_PHY_AMD_GTH_PIO_IN_RX_RST_DONE, "RX");
}

// RX datapath reset
// Waits for the CDR lock of the active lanes.
prt_sta_type prt_phy_amd_gth_rx_dp_rst(prt_phy_amd_gth_ds_struct *phy, uint8_t lanes) {
    uint32_t msk = (lanes == 1) ? 0x1 : (lanes == 2) ? 0x3 : 0xf;

    if (rst(phy, PRT_PHY_AMD_GTH_PIO_OUT_RX_DP_RST, PRT_PHY_AMD_GTH_PIO_IN_RX_RST_DONE, "RX") != PRT_STA_OK)
        return PRT_STA_FAIL;

    // The CDR lock is not stable right after the reset
    prt_zu_tmr_delay_us(PRT_PHY_AMD_GTH_CDR_LOCK_WAIT);

    uint64_t end = prt_zu_tmr_us() + PRT_PHY_AMD_GTH_CDR_LOCK_TIMEOUT;
    while (((phy->dev->pio_din >> PRT_PHY_AMD_GTH_PIO_IN_CDR_SHIFT) & msk) != msk) {
        if (prt_zu_tmr_us() > end) {
            printf("PHY RX: CDR lock timeout\n");
            return PRT_STA_FAIL;
        }
    }
    return PRT_STA_OK;
}

// TX voltage swing and pre-emphasis
void prt_phy_amd_gth_tx_vap(prt_phy_amd_gth_ds_struct *phy, uint8_t volt, uint8_t pre) {
    static const uint8_t diffctrl[] = {0x08, 0x0e, 0x16, 0x1e};     // 400 / 600 / 800 / 1200 mV
    static const uint8_t postcursor[] = {0x00, 0x0d, 0x14, 0x1b};   // 0 / 3.5 / 6.0 / 9.5 dB

    pio_msk(phy, (0x1fU << PRT_PHY_AMD_GTH_PIO_OUT_VOLT_SHIFT) | (0x1fU << PRT_PHY_AMD_GTH_PIO_OUT_PRE_SHIFT),
            ((uint32_t)diffctrl[volt & 3] << PRT_PHY_AMD_GTH_PIO_OUT_VOLT_SHIFT) |
            ((uint32_t)postcursor[pre & 3] << PRT_PHY_AMD_GTH_PIO_OUT_PRE_SHIFT));
}
