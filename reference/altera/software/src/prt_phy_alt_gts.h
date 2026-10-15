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

    The GTS transceiver runs in DisplayPort mode. It starts at 10 Gbps (32-bit PMA width).
    The 8b/10b link rates are set with the reconfiguration interface (20-bit PMA width).
    The register sequence comes from the Altera DisplayPort PHY (dp_ag5_sip_txcfg.sv).

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

// Base addresses (lightweight HPS to FPGA bridge, see dp_soc_ag5e.tcl)
#define PRT_PHY_ALT_GTS_CTL_BASE        0x20000010UL    // PHY control PIO
#define PRT_PHY_ALT_GTS_STS_BASE        0x20000020UL    // PHY status PIO
#define PRT_PHY_ALT_GTS_RCFG_BASE       0x20400000UL    // Reconfiguration interface (byte address)

// PHY control
#define PRT_PHY_ALT_GTS_CTL_TX_RST      (1 << 0)
#define PRT_PHY_ALT_GTS_CTL_RX_RST      (1 << 1)

// PHY status
#define PRT_PHY_ALT_GTS_STS_TX_RST_ACK  (1 << 0)
#define PRT_PHY_ALT_GTS_STS_TX_RDY      (1 << 1)
#define PRT_PHY_ALT_GTS_STS_TX_PLL_SHIFT 2
#define PRT_PHY_ALT_GTS_STS_TX_PLL_MASK (0xf << PRT_PHY_ALT_GTS_STS_TX_PLL_SHIFT)
#define PRT_PHY_ALT_GTS_STS_RX_RST_ACK  (1 << 6)
#define PRT_PHY_ALT_GTS_STS_RX_RDY      (1 << 7)
#define PRT_PHY_ALT_GTS_STS_RX_LOCK_SHIFT 8
#define PRT_PHY_ALT_GTS_STS_RX_LOCK_MASK (0xf << PRT_PHY_ALT_GTS_STS_RX_LOCK_SHIFT)

// Reconfiguration registers (byte address)
#define PRT_PHY_ALT_GTS_PCS_RATE        0x097808UL      // PCS rate of lane 0
#define PRT_PHY_ALT_GTS_LANE_OFFSET     0x100000UL      // Offset between lanes
#define PRT_PHY_ALT_GTS_PCS_RATE_MASK   0x03f000e0UL    // Bits 25:20 (rate), bits 7:5 (PMA width)
#define PRT_PHY_ALT_GTS_PCS_RATE_SHIFT  20
#define PRT_PHY_ALT_GTS_PCS_WIDTH_SHIFT 5
#define PRT_PHY_ALT_GTS_PCS_WIDTH_20    3

// RX rate (byte address of lane 0)
// The receiver has its own PCS rate register, so the TX and the RX link rate are independent.
#define PRT_PHY_ALT_GTS_RX_PCS_RATE     0x097810UL      // PCS rate of lane 0
#define PRT_PHY_ALT_GTS_RX_PCS_RATE_MASK 0x7e000070UL   // Bits 30:25 (rate), bits 6:4 (PMA width)
#define PRT_PHY_ALT_GTS_RX_PCS_RATE_SHIFT 25
#define PRT_PHY_ALT_GTS_RX_PCS_WIDTH_SHIFT 4

// RX calibration (byte address of lane 0)
// Set while the receiver is in reset for its first start, cleared after the reset is released.
#define PRT_PHY_ALT_GTS_RX_DUTY_RECAL   0x091584UL
#define PRT_PHY_ALT_GTS_RX_DUTY_RECAL_MASK 0x03e00000UL // Bits 25:21
#define PRT_PHY_ALT_GTS_RX_EQ_CAL       0x091aa4UL
#define PRT_PHY_ALT_GTS_RX_EQ_CAL_MASK  0x3fc00000UL    // Bits 29:22

// RX equalizer (byte address of lane 0)
// The receiver equalizer is static (no adaptation), the same as the Altera DisplayPort PHY.
#define PRT_PHY_ALT_GTS_RX_EQ_STATIC    0x097828UL      // [12] static equalizer, set with every rate
#define PRT_PHY_ALT_GTS_RX_EQ_STATIC_EN (1UL << 12)
#define PRT_PHY_ALT_GTS_RX_CTLE_STATIC  0x0919a8UL      // [27] static CTLE, set once after the first start
#define PRT_PHY_ALT_GTS_RX_CTLE_STATIC_EN (1UL << 27)

// TX equalizer (byte address of lane 0)
#define PRT_PHY_ALT_GTS_TXEQ0           0x09174cUL      // [29:27] pre tap 2, [23:19] post tap 1, [13:8] main tap
#define PRT_PHY_ALT_GTS_TXEQ1           0x091750UL      // [9:5] pre tap 1
#define PRT_PHY_ALT_GTS_TXEQ_PRE2_MASK  (0x7UL << 27)
#define PRT_PHY_ALT_GTS_TXEQ_POST_SHIFT 19
#define PRT_PHY_ALT_GTS_TXEQ_POST_MASK  (0x1fUL << PRT_PHY_ALT_GTS_TXEQ_POST_SHIFT)
#define PRT_PHY_ALT_GTS_TXEQ_MAIN_SHIFT 8
#define PRT_PHY_ALT_GTS_TXEQ_MAIN_MASK  (0x3fUL << PRT_PHY_ALT_GTS_TXEQ_MAIN_SHIFT)
#define PRT_PHY_ALT_GTS_TXEQ_PRE1_MASK  (0x1fUL << 5)

#define PRT_PHY_ALT_GTS_LANES           4
#define PRT_PHY_ALT_GTS_TIMEOUT         10000000

// Initialize the PHY (TX and RX at the given line rate in Mb/s)
int32_t prt_phy_alt_gts_init(uint32_t mbps);

// Set the TX line rate (1620, 2700, 5400 or 8100 Mb/s)
int32_t prt_phy_alt_gts_tx_rate(uint32_t mbps);

// Set the RX line rate (1620, 2700, 5400 or 8100 Mb/s)
int32_t prt_phy_alt_gts_rx_rate(uint32_t mbps);

// Reset the receiver (the CDR locks again to the incoming data)
int32_t prt_phy_alt_gts_rx_rst(void);


// Read the PHY status
uint32_t prt_phy_alt_gts_sts(void);

// Set the TX voltage swing (0 - 3) and pre-emphasis (0 - 3) levels of all lanes
int32_t prt_phy_alt_gts_tx_vap(uint8_t volt, uint8_t pre);

// Get the TX equalizer main tap and post tap 1 of a lane
void prt_phy_alt_gts_tx_eq_get(uint32_t lane, uint32_t *main_tap, uint32_t *post_tap);
