/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: Agilex 5 HPS interrupts
    (c) 2026 by Parretto B.V.

    The HPS has an Arm GIC-600 (GICv3). The application runs in secure EL3,
    the interrupts are configured as group 0 and are signaled as FIQ.

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
#include "prt_hps_irq.h"

// GIC
#define GICD_BASE               0x1D000000UL
#define GICR_BASE               0x1D060000UL
#define GICR_FRAME_SIZE         0x20000UL

// Distributor
#define GICD_CTLR               0x0000UL
#define GICD_IGROUPR            0x0080UL
#define GICD_ISENABLER          0x0100UL
#define GICD_ICENABLER          0x0180UL
#define GICD_ISPENDR            0x0200UL
#define GICD_IPRIORITYR         0x0400UL
#define GICD_ICFGR              0x0C00UL
#define GICD_IGRPMODR           0x0D00UL
#define GICD_IROUTER            0x6000UL

#define GICD_CTLR_ENABLE_GRP0   (1U << 0)
#define GICD_CTLR_ARE_S         (1U << 4)
#define GICD_CTLR_RWP           (1U << 31)

// Redistributor
#define GICR_TYPER              0x0008UL
#define GICR_WAKER              0x0014UL
#define GICR_PWRR               0x0024UL    // GIC-600 power register
#define GICR_TYPER_LAST         (1U << 4)
#define GICR_WAKER_SLEEP        (1U << 1)
#define GICR_WAKER_ASLEEP       (1U << 2)
#define GICR_PWRR_RDPD          (1U << 0)   // Redistributor powered down
#define GICR_PWRR_RDGPD         (1U << 2)   // Group power down
#define GICR_PWRR_RDGPO         (1U << 3)   // Group powered off

#define IRQ_MAX                 256U        // Covers all SPIs that are used (the FPGA interrupts are 49-112)
#define IRQ_SPURIOUS            1020U
#define IRQ_PRIORITY            0x80U
#define TIMEOUT                 1000000U

#define REG32(adr)              (*(volatile uint32_t *)(adr))
#define REG64(adr)              (*(volatile uint64_t *)(adr))
#define REG8(adr)               (*(volatile uint8_t *)(adr))

// CPU interface system registers
#define ICC_SRE_EL3             "S3_6_C12_C12_5"
#define ICC_PMR_EL1             "S3_0_C4_C6_0"
#define ICC_BPR0_EL1            "S3_0_C12_C8_3"
#define ICC_IGRPEN0_EL1         "S3_0_C12_C12_6"
#define ICC_IAR0_EL1            "S3_0_C12_C8_0"
#define ICC_EOIR0_EL1           "S3_0_C12_C8_1"

#define SYSREG_WR(reg, val)     __asm__ volatile("msr " reg ", %0" : : "r"((uint64_t)(val)) : "memory")
#define SYSREG_RD(reg, val)     __asm__ volatile("mrs %0, " reg : "=r"(val) : : "memory")

typedef struct {
    prt_hps_irq_handler_t handler;
    void *ctx;
} prt_hps_irq_entry_t;

static prt_hps_irq_entry_t irq_tbl[IRQ_MAX];

extern char prt_hps_vec_tbl[];

static int32_t gicd_wait_rwp(void) {
    for (uint32_t i = 0; i < TIMEOUT; i++) {
        if ((REG32(GICD_BASE + GICD_CTLR) & GICD_CTLR_RWP) == 0U) {
            return 0;
        }
    }
    return -1;
}

// Power on the redistributor (GIC-600, same sequence as the Arm Trusted Firmware)
static int32_t gicr_pwr_on(uintptr_t rd) {
    for (uint32_t i = 0; i < TIMEOUT; i++) {
        // Wait until the group is not in transition (RDGPD == RDGPO)
        uint32_t pwrr = REG32(rd + GICR_PWRR);
        if (((pwrr & GICR_PWRR_RDGPD) != 0U) != ((pwrr & GICR_PWRR_RDGPO) != 0U)) {
            continue;
        }

        REG32(rd + GICR_PWRR) = 0;

        if ((REG32(rd + GICR_PWRR) & GICR_PWRR_RDPD) == 0U) {
            return 0;
        }
    }
    return -1;
}

// Find the redistributor of this core
static uintptr_t gicr_find(void) {
    uint64_t mpidr;
    __asm__ volatile("mrs %0, mpidr_el1" : "=r"(mpidr));
    uint32_t aff = (uint32_t)(((mpidr >> 8) & 0xff000000UL) | (mpidr & 0x00ffffffUL));

    for (uintptr_t rd = GICR_BASE; rd < (GICR_BASE + (8U * GICR_FRAME_SIZE)); rd += GICR_FRAME_SIZE) {
        uint64_t typer = REG64(rd + GICR_TYPER);
        if ((uint32_t)(typer >> 32) == aff) {
            return rd;
        }
        if (typer & GICR_TYPER_LAST) {
            break;
        }
    }
    return 0;
}

int32_t prt_hps_irq_init(void) {
    for (uint32_t i = 0; i < IRQ_MAX; i++) {
        irq_tbl[i].handler = NULL;
        irq_tbl[i].ctx = NULL;
    }

    // Distributor: affinity routing and group 0
    REG32(GICD_BASE + GICD_CTLR) |= GICD_CTLR_ARE_S;
    if (gicd_wait_rwp() != 0) {
        return -1;
    }
    REG32(GICD_BASE + GICD_CTLR) |= GICD_CTLR_ENABLE_GRP0;
    if (gicd_wait_rwp() != 0) {
        return -1;
    }

    // Redistributor: power on and wake up
    uintptr_t rd = gicr_find();
    if (rd == 0) {
        return -2;
    }
    if (gicr_pwr_on(rd) != 0) {
        return -4;
    }
    REG32(rd + GICR_WAKER) &= ~GICR_WAKER_SLEEP;
    uint32_t i;
    for (i = 0; i < TIMEOUT; i++) {
        if ((REG32(rd + GICR_WAKER) & GICR_WAKER_ASLEEP) == 0U) {
            break;
        }
    }
    if (i == TIMEOUT) {
        return -3;
    }

    // CPU interface
    SYSREG_WR(ICC_SRE_EL3, 0xf);    // System register interface, disable FIQ and IRQ bypass, enable lower ELs
    __asm__ volatile("isb");
    SYSREG_WR(ICC_PMR_EL1, 0xff);   // Lowest priority mask
    SYSREG_WR(ICC_BPR0_EL1, 0);
    SYSREG_WR(ICC_IGRPEN0_EL1, 1);  // Group 0
    __asm__ volatile("isb");

    // Exception vectors and FIQ routing to EL3
    SYSREG_WR("vbar_el3", (uintptr_t)prt_hps_vec_tbl);
    uint64_t scr;
    SYSREG_RD("scr_el3", scr);
    scr |= (1U << 2);               // FIQ
    SYSREG_WR("scr_el3", scr);
    __asm__ volatile("isb");

    // Enable FIQ
    __asm__ volatile("msr daifclr, #1" : : : "memory");

    return 0;
}

int32_t prt_hps_irq_register(uint32_t intid, prt_hps_irq_handler_t handler, void *ctx) {
    if ((intid < 32U) || (intid >= IRQ_MAX)) {
        return -1;
    }

    irq_tbl[intid].handler = handler;
    irq_tbl[intid].ctx = ctx;

    uint32_t reg = (intid / 32U) * 4U;
    uint32_t bit = 1U << (intid % 32U);

    // Group 0
    REG32(GICD_BASE + GICD_IGROUPR + reg) &= ~bit;
    REG32(GICD_BASE + GICD_IGRPMODR + reg) &= ~bit;

    // Priority
    REG8(GICD_BASE + GICD_IPRIORITYR + intid) = IRQ_PRIORITY;

    // Level sensitive
    uint32_t cfg_reg = (intid / 16U) * 4U;
    uint32_t cfg_shift = (intid % 16U) * 2U;
    REG32(GICD_BASE + GICD_ICFGR + cfg_reg) &= ~(3U << cfg_shift);

    // Route to this core (affinity Aff3 bits 39:32, Aff2-0 bits 23:0)
    uint64_t mpidr;
    __asm__ volatile("mrs %0, mpidr_el1" : "=r"(mpidr));
    REG64(GICD_BASE + GICD_IROUTER + (intid * 8U)) = mpidr & 0xff00ffffffUL;

    // Enable
    REG32(GICD_BASE + GICD_ISENABLER + reg) = bit;

    return gicd_wait_rwp();
}

uint32_t prt_hps_irq_pending(uint32_t intid) {
    return (REG32(GICD_BASE + GICD_ISPENDR + ((intid / 32U) * 4U)) >> (intid % 32U)) & 1U;
}

// Called from the FIQ vector
void prt_hps_irq_dispatch(void);
void prt_hps_irq_dispatch(void) {
    uint64_t iar;
    SYSREG_RD(ICC_IAR0_EL1, iar);
    uint32_t intid = (uint32_t)(iar & 0xffffffU);

    if (intid >= IRQ_SPURIOUS) {
        return;
    }

    if ((intid < IRQ_MAX) && (irq_tbl[intid].handler != NULL)) {
        irq_tbl[intid].handler(irq_tbl[intid].ctx);
    }

    SYSREG_WR(ICC_EOIR0_EL1, iar);
}
