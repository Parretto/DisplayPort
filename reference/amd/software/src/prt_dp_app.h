/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: DP application header for the AMD Zynq UltraScale+ reference designs
            (Enclustra Mercury+ XU6 on the Mercury+ ST1, AMD ZCU102)
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

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include "prt_types.h"
#include "prt_dp_drv.h"
#include "prt_log.h"
#include "prt_dp_fmt.h"

// Register access
#define REG(adr)            (*(volatile uint32_t *)(adr))

// Low power domain master M_AXI_HPM0_LPD (see dp_soc_zu4cg.tcl)
#define LPD_PL_BASE         0x80000000UL
#define PIO_OUT_BASE        (LPD_PL_BASE + 0x0000UL)    // AXI GPIO channel 1 data
#define PIO_IN_BASE         (LPD_PL_BASE + 0x0008UL)    // AXI GPIO channel 2 data
#define DPTX_BASE           (LPD_PL_BASE + 0x1000UL)
#define VTB_BASE            (LPD_PL_BASE + 0x2000UL)
#define PHY_BASE            (LPD_PL_BASE + 0x3000UL)
#define DPRX_BASE           (LPD_PL_BASE + 0x4000UL)
#define I2C_BASE            (LPD_PL_BASE + 0x5000UL)

// Board
#if defined(PRT_BOARD_ZU9EG_ZCU102)
    #define DP_APP_BOARD    "AMD ZCU102"
#else
    #define DP_APP_BOARD    "Enclustra Mercury+ XU6 on the Mercury+ ST1"
#endif

// I2C
// The bus of the Tentiva, 100 kHz from the 100 MHz system clock
#define I2C_BEAT            1000U

// ZCU102: the PL I2C goes through the I2C muxes U34 and U135, FMC HPC0 is channel 0 of U135
#define ZCU102_I2C_MUX_U34  0x74U
#define ZCU102_I2C_MUX_U135 0x75U

// PIO out
#define PIO_OUT_DPTX_RST    (1U << 0)
#define PIO_OUT_DPRX_RST    (1U << 1)

// PHY reference clock (kHz)
// The Tentiva generates 270 MHz for all line rates, the transceiver takes it on MGTREFCLK1
// (QPLL1 for the transmitters, the CPLL for the receivers).
#define PHY_REFCLK_KHZ      270000U

// Video clock recovery (pass-through)
// Gains of the VTB clock recovery, its output steers the DCO of the Tentiva video clock
#define DP_APP_CR_P_GAIN    50U
#define DP_APP_CR_I_GAIN    32000U
#define DP_APP_DCO_PERIOD_US 10000U     // Update period of the DCO

// Colorbar
// The largest pixel clock (kHz) the video toolbox generates on this board (4K60)
#define DP_APP_PCLK_MAX     594000U

// Data structure
typedef struct {
    volatile bool colorbar;         // Start the colorbar (set by the link callback)
    volatile bool edid_rd;          // Read the EDID of the sink (set by the HPD callback)
    prt_dp_fmt_edid_struct edid;    // What the sink's EDID offers
    uint8_t fmt;                    // Colorbar format (prt_dp_fmt)
} prt_dp_app_tx_struct;

typedef struct {
    volatile bool pass;             // Start the pass-through (set by the MSA callback)
    bool cr;                        // The pass-through (video clock recovery) is running
} prt_dp_app_rx_struct;

typedef struct {
    prt_dp_app_tx_struct tx;        // Transmitter
    prt_dp_app_rx_struct rx;        // Receiver
    prt_log_ds_struct log;          // Log (written by the DP callbacks)
} dp_app_struct;

/*
    Helpers
*/

// Frequency in kHz as MHz with three decimals
static inline char *clk_mhz(uint32_t khz, char *buf) {
    sprintf(buf, "%lu.%03lu", (unsigned long)(khz / 1000U), (unsigned long)(khz % 1000U));
    return buf;
}

// Link rate as text
static inline const char *rate_str(uint8_t rate) {
    switch (rate) {
    case PRT_DP_PHY_LINERATE_1620: return "1.62 Gbps";
    case PRT_DP_PHY_LINERATE_2700: return "2.7 Gbps";
    case PRT_DP_PHY_LINERATE_5400: return "5.4 Gbps";
    case PRT_DP_PHY_LINERATE_8100: return "8.1 Gbps";
    default: return "unknown";
    }
}
