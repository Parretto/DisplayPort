/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: Zynq UltraScale+ Cortex-A53 MMU (EL3)
    (c) 2026 by Parretto B.V.

    Flat map of the lower 4 GB (32-bit address space, 4 KB granule, translation starts at level 1).
    Only the last 2 MB (RPU TCM and the on-chip memory at 0xFFFC0000) is normal cacheable memory,
    everything else is device memory: the DDR is not used, the PL peripherals are at 0x80000000
    (M_AXI_HPM0_LPD) and the PS peripherals are below 0xFFE00000.

    Called from the start up before the C library is used, so it must not call library functions.

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

#include <stdint.h>

// Memory attributes (MAIR_EL3)
#define MAIR_DEVICE         0x00ULL     // Attribute 0: Device-nGnRnE
#define MAIR_NORMAL         0xFFULL     // Attribute 1: Normal, inner and outer write-back, read and write allocate
#define ATTR_DEVICE         (0ULL << 2)
#define ATTR_NORMAL         (1ULL << 2)

// Block descriptor
#define DESC_BLOCK          0x1ULL
#define DESC_TABLE          0x3ULL
#define DESC_AF             (1ULL << 10)    // Access flag
#define DESC_SH_INNER       (3ULL << 8)     // Inner shareable
#define DESC_XN             (1ULL << 54)    // Execute never

#define DEVICE_BLOCK        (DESC_BLOCK | ATTR_DEVICE | DESC_AF | DESC_XN)
#define NORMAL_BLOCK        (DESC_BLOCK | ATTR_NORMAL | DESC_AF | DESC_SH_INNER)

// TCR_EL3: T0SZ 32 (4 GB), inner and outer write-back walks, inner shareable, 4 KB granule, 32-bit PA
#define TCR_EL3_VAL         ((1ULL << 31) | (1ULL << 23) | (0ULL << 16) | (0ULL << 14) | (3ULL << 12) | (1ULL << 10) | (1ULL << 8) | 32ULL)

// SCTLR_EL3
#define SCTLR_M             (1ULL << 0)     // MMU
#define SCTLR_C             (1ULL << 2)     // Data cache
#define SCTLR_I             (1ULL << 12)    // Instruction cache

// Level 1: four 1 GB entries, level 2: 512 2 MB entries for the upper 1 GB
static uint64_t mmu_l1[4] __attribute__((aligned(64)));
static uint64_t mmu_l2[512] __attribute__((aligned(4096)));

void prt_zu_mmu_init(void) {
    // Lower 3 GB: device
    for (uint32_t i = 0; i < 3; i++) {
        mmu_l1[i] = ((uint64_t)i << 30) | DEVICE_BLOCK;
    }

    // Upper 1 GB in 2 MB blocks, the last one (TCM and OCM) is normal memory
    for (uint32_t i = 0; i < 512; i++) {
        uint64_t adr = 0xC0000000ULL + ((uint64_t)i << 21);
        mmu_l2[i] = adr | ((i == 511) ? NORMAL_BLOCK : DEVICE_BLOCK);
    }
    mmu_l1[3] = (uint64_t)(uintptr_t)mmu_l2 | DESC_TABLE;

    __asm__ volatile(
        "dsb    sy\n"
        "msr    mair_el3, %0\n"
        "msr    tcr_el3, %1\n"
        "msr    ttbr0_el3, %2\n"
        "tlbi   alle3\n"
        "ic     iallu\n"
        "dsb    sy\n"
        "isb\n"
        :
        : "r"((MAIR_NORMAL << 8) | MAIR_DEVICE), "r"(TCR_EL3_VAL), "r"((uint64_t)(uintptr_t)mmu_l1)
        : "memory");

    // The caches are invalidated by the core reset; the tables are written with the data cache off,
    // so they are in memory.
    uint64_t sctlr;
    __asm__ volatile("mrs %0, sctlr_el3" : "=r"(sctlr));
    sctlr |= SCTLR_M | SCTLR_C | SCTLR_I;
    __asm__ volatile(
        "msr    sctlr_el3, %0\n"
        "isb\n"
        :
        : "r"(sctlr)
        : "memory");
}
