/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: PHY Altera Agilex 5 GTS Driver
    (c) 2026 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Added the receiver (RX rate, RX reset and RX calibration)

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

#include <stddef.h>

#include "prt_phy_alt_gts.h"

// Line rate table
typedef struct {
    uint32_t mbps;      // Line rate in Mb/s
    uint32_t rate;      // PCS rate value (bits 2:0 divider, bits 5:3 profile)
} prt_phy_alt_gts_rate_struct;

static const prt_phy_alt_gts_rate_struct prt_phy_alt_gts_rate_tbl[] = {
    {1620, 0x24},       // Divider 16, profile 4
    {2700, 0x1b},       // Divider 8, profile 3
    {5400, 0x1a},       // Divider 4, profile 3
    {8100, 0x11},       // Divider 2, profile 2
};

#define PRT_PHY_ALT_GTS_REG(adr)    (*(volatile uint32_t *)(adr))

// Wait until the status bits are set or cleared
static int32_t prt_phy_alt_gts_wait(uint32_t mask, uint32_t val) {
    for (uint32_t i = 0; i < PRT_PHY_ALT_GTS_TIMEOUT; i++) {
        if ((PRT_PHY_ALT_GTS_REG(PRT_PHY_ALT_GTS_STS_BASE) & mask) == val) {
            return 0;
        }
    }
    return -1;
}

static void prt_phy_alt_gts_ctl(uint32_t mask, uint32_t val) {
    uint32_t dat = PRT_PHY_ALT_GTS_REG(PRT_PHY_ALT_GTS_CTL_BASE);
    PRT_PHY_ALT_GTS_REG(PRT_PHY_ALT_GTS_CTL_BASE) = (dat & ~mask) | (val & mask);
}

static const prt_phy_alt_gts_rate_struct *prt_phy_alt_gts_rate_find(uint32_t mbps) {
    for (uint32_t i = 0; i < (sizeof(prt_phy_alt_gts_rate_tbl) / sizeof(prt_phy_alt_gts_rate_tbl[0])); i++) {
        if (prt_phy_alt_gts_rate_tbl[i].mbps == mbps) {
            return &prt_phy_alt_gts_rate_tbl[i];
        }
    }
    return NULL;
}

// Read-modify-write of a register of all lanes
static void prt_phy_alt_gts_lanes_wr(uint32_t ofs, uint32_t mask, uint32_t val) {
    for (uint32_t i = 0; i < PRT_PHY_ALT_GTS_LANES; i++) {
        uintptr_t adr = PRT_PHY_ALT_GTS_RCFG_BASE + ofs + (i * PRT_PHY_ALT_GTS_LANE_OFFSET);
        PRT_PHY_ALT_GTS_REG(adr) = (PRT_PHY_ALT_GTS_REG(adr) & ~mask) | (val & mask);
    }
}

int32_t prt_phy_alt_gts_init(uint32_t mbps) {
    int32_t sta = prt_phy_alt_gts_tx_rate(mbps);

    if (sta != 0) {
        return sta;
    }

    // First start of the receiver (the same sequence as the Altera DisplayPort PHY)
    // The duty cycle and the equalizer calibration are enabled while the receiver is in reset,
    // and cleared again after the first rate is set and the reset is released.
    // After that the CTLE is static.
    prt_phy_alt_gts_ctl(PRT_PHY_ALT_GTS_CTL_RX_RST, PRT_PHY_ALT_GTS_CTL_RX_RST);
    if (prt_phy_alt_gts_wait(PRT_PHY_ALT_GTS_STS_RX_RST_ACK, PRT_PHY_ALT_GTS_STS_RX_RST_ACK) != 0) {
        return -12;
    }
    prt_phy_alt_gts_lanes_wr(PRT_PHY_ALT_GTS_RX_DUTY_RECAL, PRT_PHY_ALT_GTS_RX_DUTY_RECAL_MASK, PRT_PHY_ALT_GTS_RX_DUTY_RECAL_MASK);
    prt_phy_alt_gts_lanes_wr(PRT_PHY_ALT_GTS_RX_EQ_CAL, PRT_PHY_ALT_GTS_RX_EQ_CAL_MASK, PRT_PHY_ALT_GTS_RX_EQ_CAL_MASK);

    sta = prt_phy_alt_gts_rx_rate(mbps);
    if (sta != 0) {
        return sta;
    }

    prt_phy_alt_gts_lanes_wr(PRT_PHY_ALT_GTS_RX_DUTY_RECAL, PRT_PHY_ALT_GTS_RX_DUTY_RECAL_MASK, 0);
    prt_phy_alt_gts_lanes_wr(PRT_PHY_ALT_GTS_RX_EQ_CAL, PRT_PHY_ALT_GTS_RX_EQ_CAL_MASK, 0);
    prt_phy_alt_gts_lanes_wr(PRT_PHY_ALT_GTS_RX_CTLE_STATIC, PRT_PHY_ALT_GTS_RX_CTLE_STATIC_EN, PRT_PHY_ALT_GTS_RX_CTLE_STATIC_EN);

    return 0;
}

int32_t prt_phy_alt_gts_rx_rate(uint32_t mbps) {
    const prt_phy_alt_gts_rate_struct *rate = prt_phy_alt_gts_rate_find(mbps);

    if (rate == NULL) {
        return -11;
    }

    // Reset the receiver
    prt_phy_alt_gts_ctl(PRT_PHY_ALT_GTS_CTL_RX_RST, PRT_PHY_ALT_GTS_CTL_RX_RST);
    if (prt_phy_alt_gts_wait(PRT_PHY_ALT_GTS_STS_RX_RST_ACK, PRT_PHY_ALT_GTS_STS_RX_RST_ACK) != 0) {
        return -12;
    }

    // PCS rate and PMA width of all lanes
    prt_phy_alt_gts_lanes_wr(PRT_PHY_ALT_GTS_RX_PCS_RATE, PRT_PHY_ALT_GTS_RX_PCS_RATE_MASK,
                             (rate->rate << PRT_PHY_ALT_GTS_RX_PCS_RATE_SHIFT) | (PRT_PHY_ALT_GTS_PCS_WIDTH_20 << PRT_PHY_ALT_GTS_RX_PCS_WIDTH_SHIFT));

    // Static equalizer
    prt_phy_alt_gts_lanes_wr(PRT_PHY_ALT_GTS_RX_EQ_STATIC, PRT_PHY_ALT_GTS_RX_EQ_STATIC_EN, PRT_PHY_ALT_GTS_RX_EQ_STATIC_EN);

    // Release the reset
    // The receiver is ready when the CDR has locked to the incoming data, so this does not wait for it.
    prt_phy_alt_gts_ctl(PRT_PHY_ALT_GTS_CTL_RX_RST, 0);
    if (prt_phy_alt_gts_wait(PRT_PHY_ALT_GTS_STS_RX_RST_ACK, 0) != 0) {
        return -13;
    }

    return 0;
}

int32_t prt_phy_alt_gts_rx_rst(void) {
    prt_phy_alt_gts_ctl(PRT_PHY_ALT_GTS_CTL_RX_RST, PRT_PHY_ALT_GTS_CTL_RX_RST);
    if (prt_phy_alt_gts_wait(PRT_PHY_ALT_GTS_STS_RX_RST_ACK, PRT_PHY_ALT_GTS_STS_RX_RST_ACK) != 0) {
        return -12;
    }
    prt_phy_alt_gts_ctl(PRT_PHY_ALT_GTS_CTL_RX_RST, 0);
    if (prt_phy_alt_gts_wait(PRT_PHY_ALT_GTS_STS_RX_RST_ACK, 0) != 0) {
        return -13;
    }
    return 0;
}

int32_t prt_phy_alt_gts_tx_rate(uint32_t mbps) {
    const prt_phy_alt_gts_rate_struct *rate = prt_phy_alt_gts_rate_find(mbps);

    if (rate == NULL) {
        return -1;
    }

    // Reset the transmitter
    prt_phy_alt_gts_ctl(PRT_PHY_ALT_GTS_CTL_TX_RST, PRT_PHY_ALT_GTS_CTL_TX_RST);
    if (prt_phy_alt_gts_wait(PRT_PHY_ALT_GTS_STS_TX_RST_ACK, PRT_PHY_ALT_GTS_STS_TX_RST_ACK) != 0) {
        return -2;
    }

    // PCS rate and PMA width of all lanes
    for (uint32_t i = 0; i < PRT_PHY_ALT_GTS_LANES; i++) {
        uintptr_t adr = PRT_PHY_ALT_GTS_RCFG_BASE + PRT_PHY_ALT_GTS_PCS_RATE + (i * PRT_PHY_ALT_GTS_LANE_OFFSET);
        uint32_t dat = PRT_PHY_ALT_GTS_REG(adr);
        dat &= ~PRT_PHY_ALT_GTS_PCS_RATE_MASK;
        dat |= (rate->rate << PRT_PHY_ALT_GTS_PCS_RATE_SHIFT) | (PRT_PHY_ALT_GTS_PCS_WIDTH_20 << PRT_PHY_ALT_GTS_PCS_WIDTH_SHIFT);
        PRT_PHY_ALT_GTS_REG(adr) = dat;
    }

    // Release the reset
    prt_phy_alt_gts_ctl(PRT_PHY_ALT_GTS_CTL_TX_RST, 0);
    if (prt_phy_alt_gts_wait(PRT_PHY_ALT_GTS_STS_TX_RST_ACK, 0) != 0) {
        return -3;
    }

    if (prt_phy_alt_gts_wait(PRT_PHY_ALT_GTS_STS_TX_RDY, PRT_PHY_ALT_GTS_STS_TX_RDY) != 0) {
        return -4;
    }

    return 0;
}

/*
    TX voltage swing and pre-emphasis
    The peak amplitude of the transmitter is main tap + 1 (56 at main tap 55, taken as 1200 mV).
    Post tap 1 is taken from the cursor, the de-emphasised level is main tap + 1 - 2 x post tap 1.
    The DP swing level (400, 600, 800, 1200 mV) is the de-emphasised level, the pre-emphasis
    (0, 3.5, 6, 9.5 dB) the ratio between the peak and that level. Swing + pre-emphasis is 3 at most.
    Table entries are {main tap, post tap 1}.
*/
static const uint8_t prt_phy_alt_gts_vap_tbl[4][4][2] = {
    {{18, 0}, {27, 4}, {36, 9}, {55, 18}},  // 400 mV:  0, 2.9, 5.8, 8.9 dB
    {{27, 0}, {41, 7}, {55, 14}, {55, 14}}, // 600 mV:  0, 3.5, 6.0 dB
    {{36, 0}, {55, 10}, {55, 10}, {55, 10}},// 800 mV:  0, 3.8 dB
    {{55, 0}, {55, 0}, {55, 0}, {55, 0}},   // 1200 mV: 0 dB
};

int32_t prt_phy_alt_gts_tx_vap(uint8_t volt, uint8_t pre) {
    if ((volt > 3U) || (pre > 3U)) {
        return -1;
    }

    uint32_t main_tap = prt_phy_alt_gts_vap_tbl[volt][pre][0];
    uint32_t post_tap = prt_phy_alt_gts_vap_tbl[volt][pre][1];

    for (uint32_t i = 0; i < PRT_PHY_ALT_GTS_LANES; i++) {
        uintptr_t adr = PRT_PHY_ALT_GTS_RCFG_BASE + (i * PRT_PHY_ALT_GTS_LANE_OFFSET);

        // Pre tap 1 off
        uint32_t dat = PRT_PHY_ALT_GTS_REG(adr + PRT_PHY_ALT_GTS_TXEQ1);
        PRT_PHY_ALT_GTS_REG(adr + PRT_PHY_ALT_GTS_TXEQ1) = dat & ~PRT_PHY_ALT_GTS_TXEQ_PRE1_MASK;

        // Main tap and post tap 1, pre tap 2 off
        dat = PRT_PHY_ALT_GTS_REG(adr + PRT_PHY_ALT_GTS_TXEQ0);
        dat &= ~(PRT_PHY_ALT_GTS_TXEQ_PRE2_MASK | PRT_PHY_ALT_GTS_TXEQ_POST_MASK | PRT_PHY_ALT_GTS_TXEQ_MAIN_MASK);
        dat |= (post_tap << PRT_PHY_ALT_GTS_TXEQ_POST_SHIFT) | (main_tap << PRT_PHY_ALT_GTS_TXEQ_MAIN_SHIFT);
        PRT_PHY_ALT_GTS_REG(adr + PRT_PHY_ALT_GTS_TXEQ0) = dat;
    }
    return 0;
}

void prt_phy_alt_gts_tx_eq_get(uint32_t lane, uint32_t *main_tap, uint32_t *post_tap) {
    uint32_t dat = PRT_PHY_ALT_GTS_REG(PRT_PHY_ALT_GTS_RCFG_BASE + (lane * PRT_PHY_ALT_GTS_LANE_OFFSET) + PRT_PHY_ALT_GTS_TXEQ0);
    *main_tap = (dat & PRT_PHY_ALT_GTS_TXEQ_MAIN_MASK) >> PRT_PHY_ALT_GTS_TXEQ_MAIN_SHIFT;
    *post_tap = (dat & PRT_PHY_ALT_GTS_TXEQ_POST_MASK) >> PRT_PHY_ALT_GTS_TXEQ_POST_SHIFT;
}

uint32_t prt_phy_alt_gts_sts(void) {
    return PRT_PHY_ALT_GTS_REG(PRT_PHY_ALT_GTS_STS_BASE);
}
