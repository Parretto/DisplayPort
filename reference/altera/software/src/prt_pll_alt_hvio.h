/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: Agilex 5 HVIO I/O PLL reconfiguration driver
    (c) 2026 by Parretto B.V.

    History
    =======
    v1.0 - Initial release

    The PLL registers are accessed through prt_hvio_pll_rcfg (one 32-bit access per register).
    The register map and the sequence come from the Clocking and PLL User Guide: Agilex 5 FPGAs and SoCs
    (HVIO I/O PLL Reconfiguration).

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

// Registers (byte offset)
#define PRT_PLL_ALT_HVIO_REG_EN         0x10    // [0] enable registers
#define PRT_PLL_ALT_HVIO_REG_MN         0x40    // M and N counters
#define PRT_PLL_ALT_HVIO_REG_CP         0x44    // [15:1] charge pump
#define PRT_PLL_ALT_HVIO_REG_CAL_PERMIT 0x48    // [14] permit recalibration
#define PRT_PLL_ALT_HVIO_REG_CAL_STA    0x58    // [7] and [21] calibration status
#define PRT_PLL_ALT_HVIO_REG_C0         0x5c    // C0 counter
#define PRT_PLL_ALT_HVIO_REG_RST        0x80    // [2] PLL reset
#define PRT_PLL_ALT_HVIO_REG_CAL_REQ    0x88    // [11] request recalibration
#define PRT_PLL_ALT_HVIO_REG_DBG        0x800   // prt_hvio_pll_rcfg debug register

// C counter
#define PRT_PLL_ALT_HVIO_C_HIGH_MASK    0x000000ffUL    // [7:0] high count
#define PRT_PLL_ALT_HVIO_C_BYPASS       (1UL << 8)      // [8] bypass
#define PRT_PLL_ALT_HVIO_C_LOW_SHIFT    23              // [30:23] low count
#define PRT_PLL_ALT_HVIO_C_LOW_MASK     (0xffUL << PRT_PLL_ALT_HVIO_C_LOW_SHIFT)
#define PRT_PLL_ALT_HVIO_C_ODD          (1UL << 31)     // [31] odd division

// M counter
#define PRT_PLL_ALT_HVIO_M_SHIFT        20              // [28:20] M count
#define PRT_PLL_ALT_HVIO_M_MASK         (0x1ffUL << PRT_PLL_ALT_HVIO_M_SHIFT)

#define PRT_PLL_ALT_HVIO_TIMEOUT        10000000

// Lock status callback (returns 1 when the PLL is locked)
typedef uint32_t (*prt_pll_alt_hvio_lock_t)(void);

typedef struct {
    uintptr_t base;
    prt_pll_alt_hvio_lock_t lock;
} prt_pll_alt_hvio_ds_struct;

void prt_pll_alt_hvio_init(prt_pll_alt_hvio_ds_struct *pll, uintptr_t base, prt_pll_alt_hvio_lock_t lock);

// Register access
uint32_t prt_pll_alt_hvio_rd(prt_pll_alt_hvio_ds_struct *pll, uint32_t ofs);
void prt_pll_alt_hvio_wr(prt_pll_alt_hvio_ds_struct *pll, uint32_t ofs, uint32_t dat);

// Set the M feedback counter (VCO = refclk / N * M) and the C0 output divider (2 - 510), then recalibrate the PLL.
// M = 0 leaves the M counter unchanged.
int32_t prt_pll_alt_hvio_set(prt_pll_alt_hvio_ds_struct *pll, uint32_t m, uint32_t div);

// Get the M feedback counter
uint32_t prt_pll_alt_hvio_get_m(prt_pll_alt_hvio_ds_struct *pll);

// Get the C0 output divider
uint32_t prt_pll_alt_hvio_get_c0(prt_pll_alt_hvio_ds_struct *pll);
