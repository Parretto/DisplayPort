/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: Agilex 5 HVIO I/O PLL reconfiguration driver
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

#include "prt_pll_alt_hvio.h"

#define PRT_PLL_ALT_HVIO_REG(adr)   (*(volatile uint32_t *)(adr))

void prt_pll_alt_hvio_init(prt_pll_alt_hvio_ds_struct *pll, uintptr_t base, prt_pll_alt_hvio_lock_t lock) {
    pll->base = base;
    pll->lock = lock;
}

uint32_t prt_pll_alt_hvio_rd(prt_pll_alt_hvio_ds_struct *pll, uint32_t ofs) {
    return PRT_PLL_ALT_HVIO_REG(pll->base + ofs);
}

void prt_pll_alt_hvio_wr(prt_pll_alt_hvio_ds_struct *pll, uint32_t ofs, uint32_t dat) {
    PRT_PLL_ALT_HVIO_REG(pll->base + ofs) = dat;
}

// Read-modify-write. Only the bits of the setting may change.
static void prt_pll_alt_hvio_rmw(prt_pll_alt_hvio_ds_struct *pll, uint32_t ofs, uint32_t mask, uint32_t dat) {
    uint32_t reg = prt_pll_alt_hvio_rd(pll, ofs);
    prt_pll_alt_hvio_wr(pll, ofs, (reg & ~mask) | (dat & mask));
}

int32_t prt_pll_alt_hvio_set(prt_pll_alt_hvio_ds_struct *pll, uint32_t m, uint32_t div) {
    if ((div < 2U) || (div > 510U) || (m > 511U)) {
        return -1;
    }

    uint32_t high = (div + 1U) / 2U;
    uint32_t low = div / 2U;
    uint32_t c0 = high | (low << PRT_PLL_ALT_HVIO_C_LOW_SHIFT) | ((div & 1U) ? PRT_PLL_ALT_HVIO_C_ODD : 0U);

    // Enable the registers
    prt_pll_alt_hvio_rmw(pll, PRT_PLL_ALT_HVIO_REG_EN, (1UL << 0), (1UL << 0));

    // Clear the calibration statuses
    prt_pll_alt_hvio_rmw(pll, PRT_PLL_ALT_HVIO_REG_CAL_STA, (1UL << 7) | (1UL << 21), 0);

    // M counter
    if (m != 0U) {
        prt_pll_alt_hvio_rmw(pll, PRT_PLL_ALT_HVIO_REG_MN, PRT_PLL_ALT_HVIO_M_MASK, m << PRT_PLL_ALT_HVIO_M_SHIFT);
    }

    // C0 counter
    prt_pll_alt_hvio_rmw(pll, PRT_PLL_ALT_HVIO_REG_C0,
                         PRT_PLL_ALT_HVIO_C_HIGH_MASK | PRT_PLL_ALT_HVIO_C_BYPASS | PRT_PLL_ALT_HVIO_C_LOW_MASK | PRT_PLL_ALT_HVIO_C_ODD,
                         c0);

    // Reset pulse (one register access is more than 10 ns)
    prt_pll_alt_hvio_rmw(pll, PRT_PLL_ALT_HVIO_REG_RST, (1UL << 2), (1UL << 2));
    prt_pll_alt_hvio_rmw(pll, PRT_PLL_ALT_HVIO_REG_RST, (1UL << 2), 0);

    // Recalibration
    prt_pll_alt_hvio_rmw(pll, PRT_PLL_ALT_HVIO_REG_CAL_PERMIT, (1UL << 14), (1UL << 14));
    prt_pll_alt_hvio_rmw(pll, PRT_PLL_ALT_HVIO_REG_CAL_REQ, (1UL << 11), (1UL << 11));

    // Wait for lock
    int32_t sta = -2;
    for (uint32_t i = 0; i < PRT_PLL_ALT_HVIO_TIMEOUT; i++) {
        if (pll->lock()) {
            sta = 0;
            break;
        }
    }

    // Clear the recalibration request and permit, so the PLL can be reconfigured again
    prt_pll_alt_hvio_rmw(pll, PRT_PLL_ALT_HVIO_REG_CAL_REQ, (1UL << 11), 0);
    prt_pll_alt_hvio_rmw(pll, PRT_PLL_ALT_HVIO_REG_CAL_PERMIT, (1UL << 14), 0);

    return sta;
}

uint32_t prt_pll_alt_hvio_get_m(prt_pll_alt_hvio_ds_struct *pll) {
    return (prt_pll_alt_hvio_rd(pll, PRT_PLL_ALT_HVIO_REG_MN) & PRT_PLL_ALT_HVIO_M_MASK) >> PRT_PLL_ALT_HVIO_M_SHIFT;
}

uint32_t prt_pll_alt_hvio_get_c0(prt_pll_alt_hvio_ds_struct *pll) {
    uint32_t c0 = prt_pll_alt_hvio_rd(pll, PRT_PLL_ALT_HVIO_REG_C0);
    if (c0 & PRT_PLL_ALT_HVIO_C_BYPASS) {
        return 1;
    }
    return (c0 & PRT_PLL_ALT_HVIO_C_HIGH_MASK) + ((c0 & PRT_PLL_ALT_HVIO_C_LOW_MASK) >> PRT_PLL_ALT_HVIO_C_LOW_SHIFT);
}
