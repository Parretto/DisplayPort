/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: Zynq UltraScale+ interrupts
    (c) 2026 by Parretto B.V.

    The APU has an Arm GIC-400 (GICv2). The application runs in secure EL3, the interrupts are
    secure group 0 interrupts and are signaled as IRQ.

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

#include <stddef.h>
#include "prt_zu_irq.h"

// GIC
#define GICD_BASE               0xF9010000UL
#define GICC_BASE               0xF9020000UL

// Distributor
#define GICD_CTLR               0x0000UL
#define GICD_IGROUPR            0x0080UL
#define GICD_ISENABLER          0x0100UL
#define GICD_ICENABLER          0x0180UL
#define GICD_ISPENDR            0x0200UL
#define GICD_ICPENDR            0x0280UL
#define GICD_IPRIORITYR         0x0400UL
#define GICD_ITARGETSR          0x0800UL
#define GICD_ICFGR              0x0C00UL

#define GICD_CTLR_ENABLE_GRP0   (1U << 0)

// CPU interface
#define GICC_CTLR               0x0000UL
#define GICC_PMR                0x0004UL
#define GICC_BPR                0x0008UL
#define GICC_IAR                0x000CUL
#define GICC_EOIR               0x0010UL

#define GICC_CTLR_ENABLE_GRP0   (1U << 0)

#define IRQ_MAX                 192U        // Covers all interrupts of the Zynq UltraScale+ (the PL interrupts are 121-128 and 136-143)
#define IRQ_SPURIOUS            1020U
#define IRQ_PRIORITY            0x80U

#define REG32(adr)              (*(volatile uint32_t *)(adr))
#define REG8(adr)               (*(volatile uint8_t *)(adr))

typedef struct {
    prt_zu_irq_handler_t handler;
    void *ctx;
} prt_zu_irq_entry_t;

static prt_zu_irq_entry_t irq_tbl[IRQ_MAX];

int32_t prt_zu_irq_init(void) {
    for (uint32_t i = 0; i < IRQ_MAX; i++) {
        irq_tbl[i].handler = NULL;
        irq_tbl[i].ctx = NULL;
    }

    // Distributor off while it is configured
    REG32(GICD_BASE + GICD_CTLR) = 0;

    // All shared peripheral interrupts disabled, not pending and in group 0
    for (uint32_t i = 32; i < IRQ_MAX; i += 32) {
        REG32(GICD_BASE + GICD_ICENABLER + ((i / 32) * 4)) = 0xffffffffU;
        REG32(GICD_BASE + GICD_ICPENDR + ((i / 32) * 4)) = 0xffffffffU;
        REG32(GICD_BASE + GICD_IGROUPR + ((i / 32) * 4)) = 0;
    }

    REG32(GICD_BASE + GICD_CTLR) = GICD_CTLR_ENABLE_GRP0;

    // CPU interface: all priorities pass, group 0 as IRQ
    REG32(GICC_BASE + GICC_PMR) = 0xf0;
    REG32(GICC_BASE + GICC_BPR) = 0;
    REG32(GICC_BASE + GICC_CTLR) = GICC_CTLR_ENABLE_GRP0;

    __asm__ volatile("dsb sy\n isb\n msr daifclr, #2" : : : "memory");
    return 0;
}

int32_t prt_zu_irq_register(uint32_t intid, prt_zu_irq_handler_t handler, void *ctx) {
    if ((intid < 32U) || (intid >= IRQ_MAX) || (handler == NULL)) {
        return -1;
    }

    irq_tbl[intid].handler = handler;
    irq_tbl[intid].ctx = ctx;

    // Level sensitive
    uint32_t cfg = REG32(GICD_BASE + GICD_ICFGR + ((intid / 16) * 4));
    cfg &= ~(3U << ((intid % 16) * 2));
    REG32(GICD_BASE + GICD_ICFGR + ((intid / 16) * 4)) = cfg;

    // Priority and target (core 0)
    REG8(GICD_BASE + GICD_IPRIORITYR + intid) = IRQ_PRIORITY;
    REG8(GICD_BASE + GICD_ITARGETSR + intid) = 0x01;

    // Enable
    REG32(GICD_BASE + GICD_ISENABLER + ((intid / 32) * 4)) = 1U << (intid % 32);
    return 0;
}

uint32_t prt_zu_irq_pending(uint32_t intid) {
    return (REG32(GICD_BASE + GICD_ISPENDR + ((intid / 32) * 4)) >> (intid % 32)) & 1U;
}

// Called from the IRQ vector (prt_zu_vec.S)
void prt_zu_irq_dispatch(void) {
    while (1) {
        uint32_t iar = REG32(GICC_BASE + GICC_IAR);
        uint32_t intid = iar & 0x3ffU;

        if (intid >= IRQ_SPURIOUS) {
            return;
        }

        if ((intid < IRQ_MAX) && (irq_tbl[intid].handler != NULL)) {
            irq_tbl[intid].handler(irq_tbl[intid].ctx);
        }

        REG32(GICC_BASE + GICC_EOIR) = iar;
    }
}
