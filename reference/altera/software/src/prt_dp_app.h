/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: DP application header for the Altera Agilex 5 E-Series 065A Modular Development Kit
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

// Lightweight HPS to FPGA bridge (see dp_soc_ag5e.tcl)
#define LWH2F_BASE          0x20000000UL
#define PIO_OUT_BASE        (LWH2F_BASE + 0x0040UL)
#define PIO_IN_BASE         (LWH2F_BASE + 0x0050UL)
#define DPTX_BASE           (LWH2F_BASE + 0x1000UL)
#define VTB_BASE            (LWH2F_BASE + 0x2000UL)
#define VID_PLL_BASE        (LWH2F_BASE + 0x3000UL)
#define DPRX_BASE           (LWH2F_BASE + 0x4000UL)
#define I2C_BASE            (LWH2F_BASE + 0x5000UL)

// I2C
// The bus of the DP redrivers (PI2DPX2063) on the carrier board, 100 kHz from the 100 MHz system clock
#define I2C_BEAT            1000U
#define I2C_DPTX_REDRV      0x53U
#define I2C_DPRX_REDRV      0x52U

// DP redriver (PI2DPX2063) equalization, bytes 5 - 8: EQ in bits 6:4, flat gain in bits 3:2 (2 = 0 dB)
// Both redrivers use the default EQ (0, 1.3 dB at 5 GHz).
#define REDRV_EQ_DPTX       0U
#define REDRV_EQ_DPRX       0U

// PIO out
#define PIO_OUT_DPTX_RST    (1U << 0)
#define PIO_OUT_DPRX_RST    (1U << 1)

// PIO in
#define PIO_IN_VID_LOCK     (1U << 2)

// Video PLL
// The reference clock is 100 MHz with N = 10 (PFD 10 MHz). The VCO runs at 2970 MHz (M = 297)
// for the CEA resolutions and at 3060 MHz (M = 306) for video clocks above 200 MHz (8K).
// The output divider sets the video clock (pixel clock / 4).
#define VID_PLL_PFD_KHZ     10000U
#define VID_PLL_M_CEA       297U
#define VID_PLL_M_HIGH      306U
#define VID_PLL_HIGH_KHZ    200000U

// Video clock recovery (pass-through)
// Gains of the VTB clock recovery and the scaling of its output to the clock enable DCO
#define DP_APP_CR_P_GAIN    50U
#define DP_APP_CR_I_GAIN    32000U
#define DP_APP_DCO_SHIFT    8U
#define DP_APP_DCO_INV      0U

// Colorbar
// The largest pixel clock (kHz) the video toolbox generates on this board (8K30 reduced blanking)
#define DP_APP_PCLK_MAX     1019896U

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

// Rough delay. Only used for reset pulses.
static inline void delay_ms(uint32_t ms) {
    for (volatile uint32_t i = 0; i < (ms * 100000U); i++) {
    }
}

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
