/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: Agilex 5 HPS clock manager setup
    (c) 2026 by Parretto B.V.

    The application runs from the HPS on-chip RAM in place of the first stage boot loader.
    In that case nobody configures the HPS PLLs and the clock manager stays in boot mode.
    This module configures the PLLs with the clock settings from the Quartus handoff data,
    the same way as the Arm Trusted Firmware BL2 does.

    Based on plat/intel/soc/agilex5/soc/agilex5_clock_manager.c and
    plat/intel/soc/common/soc/socfpga_handoff.c from the Altera Arm Trusted Firmware.
    Copyright (c) 2019-2023, Intel Corporation. All rights reserved.
    Copyright (c) 2024, Altera Corporation. All rights reserved.
    SPDX-License-Identifier: BSD-3-Clause

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

#include "prt_hps_clk.h"

// Handoff data
// The SDM places the handoff data (big endian) at the end of the on-chip RAM.
#define HANDOFF_BASE                    0x0007F000UL
#define HANDOFF_MAGIC_HEADER            0x424f4f54U     // BOOT
#define HANDOFF_MAGIC_CLOCK             0x434c4b53U     // CLKS

typedef struct {
    // Header
    uint32_t header_magic;
    uint32_t header_device;
    uint32_t _pad_0x08_0x10[2];

    // Pin muxing
    uint32_t pinmux_sel_magic;
    uint32_t pinmux_sel_length;
    uint32_t _pad_0x18_0x20[2];
    uint32_t pinmux_sel_array[96];
    uint32_t pinmux_io_magic;
    uint32_t pinmux_io_length;
    uint32_t _pad_0x1a8_0x1b0[2];
    uint32_t pinmux_io_array[96];
    uint32_t pinmux_fpga_magic;
    uint32_t pinmux_fpga_length;
    uint32_t _pad_0x338_0x340[2];
    uint32_t pinmux_fpga_array[44];
    uint32_t pinmux_delay_magic;
    uint32_t pinmux_delay_length;
    uint32_t _pad_0x3f8_0x400[2];
    uint32_t pinmux_iodelay_array[96];

    // Clock
    uint32_t clock_magic;
    uint32_t clock_length;
    uint32_t _pad_0x588_0x590[2];

    // Main PLL
    uint32_t main_pll_nocclk;
    uint32_t main_pll_nocdiv;
    uint32_t main_pll_pllglob;
    uint32_t main_pll_fdbck;
    uint32_t main_pll_pllc0;
    uint32_t main_pll_pllc1;
    uint32_t main_pll_pllc2;
    uint32_t main_pll_pllc3;
    uint32_t main_pll_pllm;

    // Peripheral PLL
    uint32_t per_pll_emacctl;
    uint32_t per_pll_gpiodiv;
    uint32_t per_pll_pllglob;
    uint32_t per_pll_fdbck;
    uint32_t per_pll_pllc0;
    uint32_t per_pll_pllc1;
    uint32_t per_pll_pllc2;
    uint32_t per_pll_pllc3;
    uint32_t per_pll_pllm;

    // Control group
    uint32_t alt_emacactr;
    uint32_t alt_emacbctr;
    uint32_t alt_emacptpctr;
    uint32_t alt_gpiodbctr;
    uint32_t alt_s2fuser0ctr;
    uint32_t alt_s2fuser1ctr;
    uint32_t alt_psirefctr;
    uint32_t alt_usb31ctr;
    uint32_t alt_dsuctr;
    uint32_t alt_core01ctr;
    uint32_t alt_core23ctr;
    uint32_t alt_core2ctr;
    uint32_t alt_core3ctr;
    uint32_t hps_osc_clk_hz;
    uint32_t fpga_clk_hz;
} prt_hps_handoff_t;

// Clock manager
#define CLKMGR_BASE                     0x10D10000UL
#define CLKMGR_CTRL                     (CLKMGR_BASE + 0x00UL)
#define CLKMGR_STAT                     (CLKMGR_BASE + 0x04UL)
#define CLKMGR_INTRCLR                  (CLKMGR_BASE + 0x14UL)

#define CLKMGR_MAINPLL_BASE             0x10D10024UL
#define CLKMGR_PERPLL_BASE              0x10D1007CUL
#define CLKMGR_ALTERA_BASE              0x10D100D0UL

// Main PLL registers
#define MAINPLL_BYPASS                  0x0CUL
#define MAINPLL_NOCCLK                  0x1CUL
#define MAINPLL_NOCDIV                  0x20UL
#define MAINPLL_PLLGLOB                 0x24UL
#define MAINPLL_FDBCK                   0x28UL
#define MAINPLL_MEM                     0x2CUL
#define MAINPLL_MEMSTAT                 0x30UL
#define MAINPLL_VCOCALIB                0x34UL
#define MAINPLL_PLLC0                   0x38UL
#define MAINPLL_PLLC1                   0x3CUL
#define MAINPLL_PLLC2                   0x40UL
#define MAINPLL_PLLC3                   0x44UL
#define MAINPLL_PLLM                    0x48UL
#define MAINPLL_LOSTLOCK                0x54UL

// Peripheral PLL registers
#define PERPLL_BYPASS                   0x0CUL
#define PERPLL_EMACCTL                  0x18UL
#define PERPLL_GPIODIV                  0x1CUL
#define PERPLL_PLLGLOB                  0x20UL
#define PERPLL_FDBCK                    0x24UL
#define PERPLL_MEM                      0x28UL
#define PERPLL_MEMSTAT                  0x2CUL
#define PERPLL_VCOCALIB                 0x30UL
#define PERPLL_PLLC0                    0x34UL
#define PERPLL_PLLC1                    0x38UL
#define PERPLL_PLLC2                    0x3CUL
#define PERPLL_PLLC3                    0x40UL
#define PERPLL_PLLM                     0x44UL
#define PERPLL_LOSTLOCK                 0x50UL

// Altera group registers
#define ALTERA_EMACACTR                 0x04UL
#define ALTERA_EMACBCTR                 0x08UL
#define ALTERA_EMACPTPCTR               0x0CUL
#define ALTERA_GPIODBCTR                0x10UL
#define ALTERA_S2FUSER0CTR              0x18UL
#define ALTERA_S2FUSER1CTR              0x1CUL
#define ALTERA_PSIREFCTR                0x20UL
#define ALTERA_EXTCNTRST                0x24UL
#define ALTERA_USB31CTR                 0x28UL
#define ALTERA_DSUCTR                   0x2CUL
#define ALTERA_CORE01CTR                0x30UL
#define ALTERA_CORE23CTR                0x34UL
#define ALTERA_CORE2CTR                 0x38UL
#define ALTERA_CORE3CTR                 0x3CUL

// Bits
#define CTRL_BOOTMODE                   (1UL << 0)
#define STAT_BUSY                       (1UL << 0)
#define STAT_ALLPLLLOCKED               ((1UL << 8) | (1UL << 16))
#define INTRCLR_LOCKLOST                ((1UL << 2) | (1UL << 3))
#define MAINPLL_BYPASS_ALL              0xF6UL
#define PERPLL_BYPASS_ALL               0xEFUL
#define PLLGLOB_PD_N                    (1UL << 0)
#define PLLGLOB_RST_N                   (1UL << 1)
#define PLLGLOB_CLR_LOSTLOCK_BYPASS     (1UL << 29)
#define PLLCX_EN                        (1UL << 27)
#define LOSTLOCK_BYPASSCLEAR            (1UL << 0)
#define EXTCNTRST_ALLCNTRST             ((1UL << 0) | (1UL << 1) | (1UL << 2) | (1UL << 3) | (1UL << 5) | (1UL << 6) | \
                                         (1UL << 7) | (1UL << 8) | (1UL << 10) | (1UL << 11) | (1UL << 12) | (1UL << 13))

// PLL memory interface
#define MEM_REQ                         (1UL << 24)
#define MEM_WR                          (1UL << 25)
#define MEM_WDAT_OFFSET                 16
#define MEM_ADDR_MASK                   0xFFFFUL
#define MEM_ADDR_START                  0x4000UL

// VCO calibration
#define PLLM_MDIV_MASK                  0x3FFUL
#define PLLGLOB_DREFCLKDIV_MASK         0x3000UL
#define PLLGLOB_DREFCLKDIV_OFFSET       12
#define PLLGLOB_REFCLKDIV_MASK          0x3F00UL
#define PLLGLOB_REFCLKDIV_OFFSET        8
#define VCOCALIB_MSCNT_MASK             0x00FF0000UL
#define VCOCALIB_MSCNT_OFFSET           16
#define VCOCALIB_HSCNT_MASK             0x3FFUL
#define VCOCALIB_MSCNT_CONST            100UL
#define VCOCALIB_HSCNT_CONST            4UL

// System manager boot scratch registers
#define SYSMGR_BOOT_SCRATCH_COLD_1      0x10D12204UL
#define SYSMGR_BOOT_SCRATCH_COLD_2      0x10D12208UL

#define MAX_RETRY_COUNT                 1000U

typedef enum { PLL_MAIN, PLL_PER } prt_hps_pll_t;

// PLL configuration in power down state
typedef struct {
    uint32_t adr;
    uint32_t dat;
    uint32_t mask;
} prt_hps_pll_cfg_t;

static const prt_hps_pll_cfg_t pll_cfg_set[] = {
    {0x27, 0x80, 0x80},     // Source synchronous mode
    {0xB3, 0x01, 0x01},     // Limit the PLL overshoot frequency during lock
    {0xE6, 0x01, 0x01},     // More PLL settle time before lock is asserted
    {0x03, 0x4A, 0x7F},     // Duty cycle clock slice 0
    {0x07, 0x4A, 0x7F},     // Duty cycle clock slice 1
};

static inline uint32_t rd(uintptr_t adr) {
    return *(volatile uint32_t *)adr;
}

static inline void wr(uintptr_t adr, uint32_t dat) {
    *(volatile uint32_t *)adr = dat;
}

static inline void set_bits(uintptr_t adr, uint32_t bits) {
    wr(adr, rd(adr) | bits);
}

static inline void clr_bits(uintptr_t adr, uint32_t bits) {
    wr(adr, rd(adr) & ~bits);
}

static uintptr_t pll_mem_adr(prt_hps_pll_t pll) {
    return (pll == PLL_MAIN) ? (CLKMGR_MAINPLL_BASE + MAINPLL_MEM) : (CLKMGR_PERPLL_BASE + PERPLL_MEM);
}

static uintptr_t pll_memstat_adr(prt_hps_pll_t pll) {
    return (pll == PLL_MAIN) ? (CLKMGR_MAINPLL_BASE + MAINPLL_MEMSTAT) : (CLKMGR_PERPLL_BASE + PERPLL_MEMSTAT);
}

// Wait for the clock manager state machine
static int32_t wait_fsm(void) {
    for (uint32_t i = 0; i < MAX_RETRY_COUNT; i++) {
        if ((rd(CLKMGR_STAT) & STAT_BUSY) == 0U) {
            return 0;
        }
    }
    return -1;
}

// Wait for a stable PLL lock
static int32_t wait_pll_lock(void) {
    uint32_t stable = 0;

    for (uint32_t i = 0; i < MAX_RETRY_COUNT; i++) {
        if ((rd(CLKMGR_STAT) & STAT_ALLPLLLOCKED) == STAT_ALLPLLLOCKED) {
            stable++;
            if (stable >= 5U) {
                return 0;
            }
        } else {
            stable = 0;
        }
    }
    return -1;
}

static uint32_t calc_vcocalib(uint32_t pllm, uint32_t pllglob) {
    uint32_t mdiv = pllm & PLLM_MDIV_MASK;
    uint32_t drefclkdiv = (pllglob & PLLGLOB_DREFCLKDIV_MASK) >> PLLGLOB_DREFCLKDIV_OFFSET;
    uint32_t refclkdiv = (pllglob & PLLGLOB_REFCLKDIV_MASK) >> PLLGLOB_REFCLKDIV_OFFSET;
    uint32_t mscnt = VCOCALIB_MSCNT_CONST / (mdiv * (1UL << drefclkdiv));
    uint32_t hscnt;

    if (mscnt == 0U) {
        mscnt = 1;
    }
    hscnt = (mdiv * mscnt * (1UL << drefclkdiv) / refclkdiv) - VCOCALIB_HSCNT_CONST;

    return (hscnt & VCOCALIB_HSCNT_MASK) | ((mscnt << VCOCALIB_MSCNT_OFFSET) & VCOCALIB_MSCNT_MASK);
}

// PLL memory interface access
static int32_t pll_mem_wait(prt_hps_pll_t pll) {
    for (uint32_t i = 0; i < MAX_RETRY_COUNT; i++) {
        if ((rd(pll_mem_adr(pll)) & MEM_REQ) == 0U) {
            return 0;
        }
    }
    return -1;
}

static int32_t pll_mem_rd(prt_hps_pll_t pll, uint32_t adr, uint32_t *dat) {
    wr(pll_mem_adr(pll), MEM_REQ | ((adr | MEM_ADDR_START) & MEM_ADDR_MASK));
    if (pll_mem_wait(pll) != 0) {
        *dat = 0;
        return -1;
    }
    *dat = rd(pll_memstat_adr(pll));
    return 0;
}

static int32_t pll_mem_wr(prt_hps_pll_t pll, uint32_t adr, uint32_t dat) {
    wr(pll_mem_adr(pll), MEM_REQ | MEM_WR | (dat << MEM_WDAT_OFFSET) | ((adr | MEM_ADDR_START) & MEM_ADDR_MASK));
    return pll_mem_wait(pll);
}

static void pll_pd_cfg(prt_hps_pll_t pll) {
    for (uint32_t i = 0; i < (sizeof(pll_cfg_set) / sizeof(pll_cfg_set[0])); i++) {
        uint32_t dat;
        (void)pll_mem_rd(pll, pll_cfg_set[i].adr, &dat);
        (void)pll_mem_wr(pll, pll_cfg_set[i].adr, (dat & ~pll_cfg_set[i].mask) | pll_cfg_set[i].dat);
    }
}

int32_t prt_hps_clk_init(void) {
    prt_hps_handoff_t hoff;
    uint32_t *dst = (uint32_t *)&hoff;
    volatile uint32_t *src = (volatile uint32_t *)HANDOFF_BASE;

    // Copy the handoff data and convert it to little endian
    for (uint32_t i = 0; i < (sizeof(hoff) / sizeof(uint32_t)); i++) {
        dst[i] = __builtin_bswap32(src[i]);
    }

    if ((hoff.header_magic != HANDOFF_MAGIC_HEADER) || (hoff.clock_magic != HANDOFF_MAGIC_CLOCK)) {
        return -1;
    }

    // Enter boot mode before any configuration
    set_bits(CLKMGR_CTRL, CTRL_BOOTMODE);

    // Bypass all clocks to the input reference clock
    set_bits(CLKMGR_MAINPLL_BASE + MAINPLL_BYPASS, MAINPLL_BYPASS_ALL);
    if (wait_fsm() != 0) {
        return -2;
    }
    set_bits(CLKMGR_PERPLL_BASE + PERPLL_BYPASS, PERPLL_BYPASS_ALL);
    if (wait_fsm() != 0) {
        return -2;
    }

    // Put both PLLs in reset and power down
    clr_bits(CLKMGR_MAINPLL_BASE + MAINPLL_PLLGLOB, PLLGLOB_PD_N | PLLGLOB_RST_N);
    clr_bits(CLKMGR_PERPLL_BASE + PERPLL_PLLGLOB, PLLGLOB_PD_N | PLLGLOB_RST_N);

    // Main PLL dividers
    wr(CLKMGR_MAINPLL_BASE + MAINPLL_PLLGLOB, hoff.main_pll_pllglob & ~PLLGLOB_RST_N);
    wr(CLKMGR_MAINPLL_BASE + MAINPLL_FDBCK, hoff.main_pll_fdbck);
    wr(CLKMGR_MAINPLL_BASE + MAINPLL_VCOCALIB, calc_vcocalib(hoff.main_pll_pllm, hoff.main_pll_pllglob));
    wr(CLKMGR_MAINPLL_BASE + MAINPLL_PLLC0, hoff.main_pll_pllc0);
    wr(CLKMGR_MAINPLL_BASE + MAINPLL_PLLC1, hoff.main_pll_pllc1);
    wr(CLKMGR_MAINPLL_BASE + MAINPLL_PLLC2, hoff.main_pll_pllc2);
    wr(CLKMGR_MAINPLL_BASE + MAINPLL_PLLC3, hoff.main_pll_pllc3);
    wr(CLKMGR_MAINPLL_BASE + MAINPLL_PLLM, hoff.main_pll_pllm);
    wr(CLKMGR_MAINPLL_BASE + MAINPLL_NOCCLK, hoff.main_pll_nocclk);
    wr(CLKMGR_MAINPLL_BASE + MAINPLL_NOCDIV, hoff.main_pll_nocdiv);

    // Peripheral PLL dividers
    wr(CLKMGR_PERPLL_BASE + PERPLL_PLLGLOB, hoff.per_pll_pllglob & ~PLLGLOB_RST_N);
    wr(CLKMGR_PERPLL_BASE + PERPLL_FDBCK, hoff.per_pll_fdbck);
    wr(CLKMGR_PERPLL_BASE + PERPLL_VCOCALIB, calc_vcocalib(hoff.per_pll_pllm, hoff.per_pll_pllglob));
    wr(CLKMGR_PERPLL_BASE + PERPLL_PLLC0, hoff.per_pll_pllc0);
    wr(CLKMGR_PERPLL_BASE + PERPLL_PLLC1, hoff.per_pll_pllc1);
    wr(CLKMGR_PERPLL_BASE + PERPLL_PLLC2, hoff.per_pll_pllc2);
    wr(CLKMGR_PERPLL_BASE + PERPLL_PLLC3, hoff.per_pll_pllc3);
    wr(CLKMGR_PERPLL_BASE + PERPLL_PLLM, hoff.per_pll_pllm);
    wr(CLKMGR_PERPLL_BASE + PERPLL_EMACCTL, hoff.per_pll_emacctl);
    wr(CLKMGR_PERPLL_BASE + PERPLL_GPIODIV, hoff.per_pll_gpiodiv);

    // Ping pong counters
    wr(CLKMGR_ALTERA_BASE + ALTERA_EMACACTR, hoff.alt_emacactr);
    wr(CLKMGR_ALTERA_BASE + ALTERA_EMACBCTR, hoff.alt_emacbctr);
    wr(CLKMGR_ALTERA_BASE + ALTERA_EMACPTPCTR, hoff.alt_emacptpctr);
    wr(CLKMGR_ALTERA_BASE + ALTERA_GPIODBCTR, hoff.alt_gpiodbctr);
    wr(CLKMGR_ALTERA_BASE + ALTERA_S2FUSER0CTR, hoff.alt_s2fuser0ctr);
    wr(CLKMGR_ALTERA_BASE + ALTERA_S2FUSER1CTR, hoff.alt_s2fuser1ctr);
    wr(CLKMGR_ALTERA_BASE + ALTERA_PSIREFCTR, hoff.alt_psirefctr);
    wr(CLKMGR_ALTERA_BASE + ALTERA_USB31CTR, hoff.alt_usb31ctr);
    wr(CLKMGR_ALTERA_BASE + ALTERA_DSUCTR, hoff.alt_dsuctr);
    wr(CLKMGR_ALTERA_BASE + ALTERA_CORE01CTR, hoff.alt_core01ctr);
    wr(CLKMGR_ALTERA_BASE + ALTERA_CORE23CTR, hoff.alt_core23ctr);
    wr(CLKMGR_ALTERA_BASE + ALTERA_CORE2CTR, hoff.alt_core2ctr);
    wr(CLKMGR_ALTERA_BASE + ALTERA_CORE3CTR, hoff.alt_core3ctr);

    // Take both PLLs out of reset and power up
    set_bits(CLKMGR_MAINPLL_BASE + MAINPLL_PLLGLOB, PLLGLOB_PD_N | PLLGLOB_RST_N);
    set_bits(CLKMGR_PERPLL_BASE + PERPLL_PLLGLOB, PLLGLOB_PD_N | PLLGLOB_RST_N);

    // PLL configuration in power down state
    pll_pd_cfg(PLL_MAIN);
    pll_pd_cfg(PLL_PER);

    // Enable the clock slices
    set_bits(CLKMGR_MAINPLL_BASE + MAINPLL_PLLC0, PLLCX_EN);
    set_bits(CLKMGR_MAINPLL_BASE + MAINPLL_PLLC1, PLLCX_EN);
    set_bits(CLKMGR_MAINPLL_BASE + MAINPLL_PLLC2, PLLCX_EN);
    set_bits(CLKMGR_MAINPLL_BASE + MAINPLL_PLLC3, PLLCX_EN);
    set_bits(CLKMGR_PERPLL_BASE + PERPLL_PLLC0, PLLCX_EN);
    set_bits(CLKMGR_PERPLL_BASE + PERPLL_PLLC1, PLLCX_EN);
    set_bits(CLKMGR_PERPLL_BASE + PERPLL_PLLC2, PLLCX_EN);
    set_bits(CLKMGR_PERPLL_BASE + PERPLL_PLLC3, PLLCX_EN);

    // Wait for lock
    if (wait_pll_lock() != 0) {
        return -3;
    }

    // Clear the lost lock bypass
    set_bits(CLKMGR_MAINPLL_BASE + MAINPLL_LOSTLOCK, LOSTLOCK_BYPASSCLEAR);
    set_bits(CLKMGR_PERPLL_BASE + PERPLL_LOSTLOCK, LOSTLOCK_BYPASSCLEAR);
    set_bits(CLKMGR_MAINPLL_BASE + MAINPLL_PLLGLOB, PLLGLOB_CLR_LOSTLOCK_BYPASS);
    set_bits(CLKMGR_PERPLL_BASE + PERPLL_PLLGLOB, PLLGLOB_CLR_LOSTLOCK_BYPASS);

    // Pass the clock source frequencies to the next stages
    wr(SYSMGR_BOOT_SCRATCH_COLD_1, hoff.hps_osc_clk_hz);
    wr(SYSMGR_BOOT_SCRATCH_COLD_2, hoff.fpga_clk_hz);

    // Take all PLLs out of bypass
    clr_bits(CLKMGR_MAINPLL_BASE + MAINPLL_BYPASS, MAINPLL_BYPASS_ALL);
    if (wait_fsm() != 0) {
        return -2;
    }
    clr_bits(CLKMGR_PERPLL_BASE + PERPLL_BYPASS, PERPLL_BYPASS_ALL);
    if (wait_fsm() != 0) {
        return -2;
    }

    // Clear the loss of lock bits
    wr(CLKMGR_INTRCLR, INTRCLR_LOCKLOST);

    // Take all ping pong counters out of reset
    clr_bits(CLKMGR_ALTERA_BASE + ALTERA_EXTCNTRST, EXTCNTRST_ALLCNTRST);

    // Exit boot mode
    clr_bits(CLKMGR_CTRL, CTRL_BOOTMODE);

    return 0;
}
