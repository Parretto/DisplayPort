/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: Zynq UltraScale+ timer
    (c) 2026 by Parretto B.V.

    The Cortex-A53 generic timer, counting the system counter (IOU_SCNTRS). Without a boot loader
    the application starts the system counter itself.

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

#include "prt_zu_tmr.h"

// System counter
#define IOU_SCNTRS_BASE         0xFF260000UL
#define IOU_SCNTRS_CTRL         (*(volatile uint32_t *)(IOU_SCNTRS_BASE + 0x00UL))
#define IOU_SCNTRS_FREQ         (*(volatile uint32_t *)(IOU_SCNTRS_BASE + 0x20UL))
#define IOU_SCNTRS_CTRL_EN      (1U << 0)

// Microseconds to counter ticks and back
#define US_TO_TICKS(us)         (((uint64_t)(us) * PRT_ZU_TMR_FREQ) / 1000000U)

static inline uint64_t cnt_get(void) {
    uint64_t cnt;
    __asm__ volatile("isb\n mrs %0, cntpct_el0" : "=r"(cnt) : : "memory");
    return cnt;
}

void prt_zu_tmr_init(void) {
    IOU_SCNTRS_FREQ = PRT_ZU_TMR_FREQ;
    IOU_SCNTRS_CTRL = IOU_SCNTRS_CTRL_EN;
    __asm__ volatile("msr cntfrq_el0, %0" : : "r"((uint64_t)PRT_ZU_TMR_FREQ));
}

uint64_t prt_zu_tmr_us(void) {
    return (cnt_get() * 1000000U) / PRT_ZU_TMR_FREQ;
}

void prt_zu_tmr_delay_us(uint32_t us) {
    uint64_t end = cnt_get() + US_TO_TICKS(us);
    while (cnt_get() < end) {
    }
}

void prt_zu_tmr_delay_ms(uint32_t ms) {
    prt_zu_tmr_delay_us(ms * 1000U);
}
