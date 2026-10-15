/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: Agilex 5 HPS cache coherency unit and NOC firewall setup
    (c) 2026 by Parretto B.V.

    The application runs from the HPS on-chip RAM in place of the first stage boot loader.
    This module configures the cache coherency unit (CCU) address map and the NOC firewalls,
    the same way as the Arm Trusted Firmware BL2 does.
    Without it the CPU can't reach the HPS to FPGA bridges.

    Based on plat/intel/soc/common/drivers/ccu/ncore_ccu.c from the Altera Arm Trusted Firmware.
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

#include <stddef.h>
#include "prt_hps_ccu.h"

// Register setting: offset, value and mask
typedef struct {
    uint32_t ofs;
    uint32_t val;
    uint32_t mask;
} prt_hps_ccu_t;

// Module: base address and register settings
typedef struct {
    uintptr_t base;
    const prt_hps_ccu_t *tbl;
    size_t len;
} prt_hps_ccu_mod_t;

static const prt_hps_ccu_t ccu_caiu0[] = {
    /* CAIUAMIGR */
    {0x000003C0, 0x00000003, 0x0000001F},
    /* CAIUMIFSR */
    {0x000003C4, 0x00000000, 0x07070777},
    /* DII1_MPFEREGS */
    {0x00000414, 0x00018000, 0xFFFFFFFF},
    {0x00000418, 0x00000000, 0x000000FF},
    {0x00000410, 0xC0E00200, 0xC1F03E1F},
    /* DII2_GICREGS */
    {0x00000424, 0x0001D000, 0xFFFFFFFF},
    {0x00000428, 0x00000000, 0x000000FF},
    {0x00000420, 0xC0800400, 0xC1F03E1F},
    /* NCAIU0_LWSOC2FPGA */
    {0x00000444, 0x00020000, 0xFFFFFFFF},
    {0x00000448, 0x00000000, 0x000000FF},
    {0x00000440, 0xC1100006, 0xC1F03E1F},
    /* NCAIU0_SOC2FPGA_1G */
    {0x00000454, 0x00040000, 0xFFFFFFFF},
    {0x00000458, 0x00000000, 0x000000FF},
    {0x00000450, 0xC1200006, 0xC1F03E1F},
    /* DMI_SDRAM_2G */
    {0x00000464, 0x00080000, 0xFFFFFFFF},
    {0x00000468, 0x00000000, 0x000000FF},
    {0x00000460, 0x81300006, 0xC1F03E1F},
    /* NCAIU0_SOC2FPGA_16G */
    {0x00000474, 0x00400000, 0xFFFFFFFF},
    {0x00000478, 0x00000000, 0x000000FF},
    {0x00000470, 0xC1600006, 0xC1F03E1F},
    /* DMI_SDRAM_30G */
    {0x00000484, 0x00800000, 0xFFFFFFFF},
    {0x00000488, 0x00000000, 0x000000FF},
    {0x00000480, 0x81700006, 0xC1F03E1F},
    /* NCAIU0_SOC2FPGA_256G */
    {0x00000494, 0x04000000, 0xFFFFFFFF},
    {0x00000498, 0x00000000, 0x000000FF},
    {0x00000490, 0xC1A00006, 0xC1F03E1F},
    /* DMI_SDRAM_480G */
    {0x000004A4, 0x08000000, 0xFFFFFFFF},
    {0x000004A8, 0x00000000, 0x000000FF},
    {0x000004A0, 0x81B00006, 0xC1F03E1F}
};

static const prt_hps_ccu_t ccu_ncaiu0[] = {
    /* NCAIU0AMIGR */
    {0x000003C0, 0x00000003, 0x0000001F},
    /* NCAIU0MIFSR */
    {0x000003C4, 0x00000000, 0x07070777},
    /* PSS */
    {0x00000404, 0x00010000, 0xFFFFFFFF},
    {0x00000408, 0x00000000, 0x000000FF},
    {0x00000400, 0xC0F00000, 0xC1F03E1F},
    /* DII1_MPFEREGS */
    {0x00000414, 0x00018000, 0xFFFFFFFF},
    {0x00000418, 0x00000000, 0x000000FF},
    {0x00000410, 0xC0E00200, 0xC1F03E1F},
    /* NCAIU0_LWSOC2FPGA */
    {0x00000444, 0x00020000, 0xFFFFFFFF},
    {0x00000448, 0x00000000, 0x000000FF},
    {0x00000440, 0xC1100006, 0xC1F03E1F},
    /* NCAIU0_SOC2FPGA_1G */
    {0x00000454, 0x00040000, 0xFFFFFFFF},
    {0x00000458, 0x00000000, 0x000000FF},
    {0x00000450, 0xC1200006, 0xC1F03E1F},
    /* DMI_SDRAM_2G */
    {0x00000464, 0x00080000, 0xFFFFFFFF},
    {0x00000468, 0x00000000, 0x000000FF},
    {0x00000460, 0x81300006, 0xC1F03E1F},
    /* NCAIU0_SOC2FPGA_16G */
    {0x00000474, 0x00400000, 0xFFFFFFFF},
    {0x00000478, 0x00000000, 0x000000FF},
    {0x00000470, 0xC1600006, 0xC1F03E1F},
    /* DMI_SDRAM_30G */
    {0x00000484, 0x00800000, 0xFFFFFFFF},
    {0x00000488, 0x00000000, 0x000000FF},
    {0x00000480, 0x81700006, 0xC1F03E1F},
    /* NCAIU0_SOC2FPGA_256G */
    {0x00000494, 0x04000000, 0xFFFFFFFF},
    {0x00000498, 0x00000000, 0x000000FF},
    {0x00000490, 0xC1A00006, 0xC1F03E1F},
    /* DMI_SDRAM_480G */
    {0x000004A4, 0x08000000, 0xFFFFFFFF},
    {0x000004A8, 0x00000000, 0x000000FF},
    {0x000004A0, 0x81B00006, 0xC1F03E1F}
};

static const prt_hps_ccu_t ccu_ncaiu1[] = {
    /* NCAIU1AMIGR */
    {0x000003C0, 0x00000003, 0x0000001F},
    /* NCAIU1MIFSR */
    {0x000003C4, 0x00000000, 0x07070777},
    /* DMI_SDRAM_2G */
    {0x00000464, 0x00080000, 0xFFFFFFFF},
    {0x00000468, 0x00000000, 0x000000FF},
    {0x00000460, 0x81300006, 0xC1F03E1F},
    /* DMI_SDRAM_30G */
    {0x00000484, 0x00800000, 0xFFFFFFFF},
    {0x00000488, 0x00000000, 0x000000FF},
    {0x00000480, 0x81700006, 0xC1F03E1F},
    /* DMI_SDRAM_480G */
    {0x000004A4, 0x08000000, 0xFFFFFFFF},
    {0x000004A8, 0x00000000, 0x000000FF},
    {0x000004A0, 0x81B00006, 0xC1F03E1F}
};

static const prt_hps_ccu_t ccu_ncaiu2[] = {
    /* NCAIU2AMIGR */
    {0x000003C0, 0x00000003, 0x0000001F},
    /* NCAIU2MIFSR */
    {0x000003C4, 0x00000000, 0x07070777},
    /* DMI_SDRAM_2G */
    {0x00000464, 0x00080000, 0xFFFFFFFF},
    {0x00000468, 0x00000000, 0x000000FF},
    {0x00000460, 0x81300006, 0xC1F03E1F},
    /* DMI_SDRAM_30G */
    {0x00000484, 0x00800000, 0xFFFFFFFF},
    {0x00000488, 0x00000000, 0x000000FF},
    {0x00000480, 0x81700006, 0xC1F03E1F},
    /* DMI_SDRAM_480G */
    {0x000004A4, 0x08000000, 0xFFFFFFFF},
    {0x000004A8, 0x00000000, 0x000000FF},
    {0x000004A0, 0x81B00006, 0xC1F03E1F}
};

static const prt_hps_ccu_t ccu_ncaiu3[] = {
    /* NCAIU3AMIGR */
    {0x000003C0, 0x00000003, 0x0000001F},
    /* NCAIU3MIFSR */
    {0x000003C4, 0x00000000, 0x07070777},
    /* DII1_MPFEREGS */
    {0x00000414, 0x00018000, 0xFFFFFFFF},
    {0x00000418, 0x00000000, 0x000000FF},
    {0x00000410, 0xC0E00200, 0xC1F03E1F},
    /* DMI_SDRAM_2G */
    {0x00000464, 0x00080000, 0xFFFFFFFF},
    {0x00000468, 0x00000000, 0x000000FF},
    {0x00000460, 0x81300006, 0xC1F03E1F},
    /* DMI_SDRAM_30G */
    {0x00000484, 0x00800000, 0xFFFFFFFF},
    {0x00000488, 0x00000000, 0x000000FF},
    {0x00000480, 0x81700006, 0xC1F03E1F},
    /* DMI_SDRAM_480G */
    {0x000004A4, 0x08000000, 0xFFFFFFFF},
    {0x000004A8, 0x00000000, 0x000000FF},
    {0x000004A0, 0x81B00006, 0xC1F03E1F}
};

static const prt_hps_ccu_t ccu_dce0[] = {
    /* DCEUAMIGR0 */
    {0x000003C0, 0x00000003, 0x0000001F},
    /* DCEUMIFSR0 */
    {0x000003C4, 0x00000000, 0x07070777},
    /* DMI_SDRAM_2G */
    {0x00000464, 0x00080000, 0xFFFFFFFF},
    {0x00000468, 0x00000000, 0x000000FF},
    {0x00000460, 0x81300006, 0xC1F03E1F},
    /* DMI_SDRAM_30G */
    {0x00000484, 0x00800000, 0xFFFFFFFF},
    {0x00000488, 0x00000000, 0x000000FF},
    {0x00000480, 0x81700006, 0xC1F03E1F},
    /* DMI_SDRAM_480G */
    {0x000004A4, 0x08000000, 0xFFFFFFFF},
    {0x000004A8, 0x00000000, 0x000000FF},
    {0x000004A0, 0x81B00006, 0xC1F03E1F}
};

static const prt_hps_ccu_t ccu_dce1[] = {
    /* DCEUAMIGR1 */
    {0x000003C0, 0x00000003, 0x0000001F},
    /* DCEUMIFSR1 */
    {0x000003C4, 0x00000000, 0x07070777},
    /* DMI_SDRAM_2G */
    {0x00000464, 0x00080000, 0xFFFFFFFF},
    {0x00000468, 0x00000000, 0x000000FF},
    {0x00000460, 0x81300006, 0xC1F03E1F},
    /* DMI_SDRAM_30G */
    {0x00000484, 0x00800000, 0xFFFFFFFF},
    {0x00000488, 0x00000000, 0x000000FF},
    {0x00000480, 0x81700006, 0xC1F03E1F},
    /* DMI_SDRAM_480G */
    {0x000004A4, 0x08000000, 0xFFFFFFFF},
    {0x000004A8, 0x00000000, 0x000000FF},
    {0x000004A0, 0x81B00006, 0xC1F03E1F}
};

static const prt_hps_ccu_t ccu_dmi0[] = {
    /* DMIUSMCTCR */
    {0x00000300, 0x00000001, 0x00000003},
    {0x00000300, 0x00000003, 0x00000003}
};

static const prt_hps_ccu_t ccu_dmi1[] = {
    /* DMIUSMCTCR */
    {0x00000300, 0x00000001, 0x00000003},
    {0x00000300, 0x00000003, 0x00000003}
};

static const prt_hps_ccu_t ccu_noc_fw_l4_per[] = {
    /* NAND */
    {0x00000000, 0x01010001, 0x01010001},
    /* USB0 */
    {0x0000000C, 0x01010001, 0x01010001},
    /* USB1 */
    {0x00000010, 0x01010001, 0x01010001},
    /* SPI_MAIN0 */
    {0x0000001C, 0x01010301, 0x01010301},
    /* SPI_MAIN1 */
    {0x00000020, 0x01010301, 0x01010301},
    /* SPI_SECONDARY0 */
    {0x00000024, 0x01010301, 0x01010301},
    /* SPI_SECONDARY1 */
    {0x00000028, 0x01010301, 0x01010301},
    /* EMAC0 */
    {0x0000002C, 0x01010001, 0x01010001},
    /* EMAC1 */
    {0x00000030, 0x01010001, 0x01010001},
    /* EMAC2 */
    {0x00000034, 0x01010001, 0x01010001},
    /* SDMMC */
    {0x00000040, 0x01010001, 0x01010001},
    /* GPIO0 */
    {0x00000044, 0x01010301, 0x01010301},
    /* GPIO1 */
    {0x00000048, 0x01010301, 0x01010301},
    /* I2C0 */
    {0x00000050, 0x01010301, 0x01010301},
    /* I2C1 */
    {0x00000054, 0x01010301, 0x01010301},
    /* I2C2 */
    {0x00000058, 0x01010301, 0x01010301},
    /* I2C3 */
    {0x0000005C, 0x01010301, 0x01010301},
    /* I2C4 */
    {0x00000060, 0x01010301, 0x01010301},
    /* SP_TIMER0 */
    {0x00000064, 0x01010301, 0x01010301},
    /* SP_TIMER1 */
    {0x00000068, 0x01010301, 0x01010301},
    /* UART0 */
    {0x0000006C, 0x01010301, 0x01010301},
    /* UART1 */
    {0x00000070, 0x01010301, 0x01010301},
    /* I3C0 */
    {0x00000074, 0x01010301, 0x01010301},
    /* I3C1 */
    {0x00000078, 0x01010301, 0x01010301},
    /* DMA0 */
    {0x0000007C, 0x01010001, 0x01010001},
    /* DMA1 */
    {0x00000080, 0x01010001, 0x01010001},
    /* COMBO_PHY */
    {0x00000084, 0x01010001, 0x01010001},
    /* NAND_SDMA */
    {0x00000088, 0x01010301, 0x01010301}
};

static const prt_hps_ccu_t ccu_noc_fw_l4_sys[] = {
    /* DMA_ECC */
    {0x00000008, 0x01010001, 0x01010001},
    /* EMAC0RX_ECC */
    {0x0000000C, 0x01010001, 0x01010001},
    /* EMAC0TX_ECC */
    {0x00000010, 0x01010001, 0x01010001},
    /* EMAC1RX_ECC */
    {0x00000014, 0x01010001, 0x01010001},
    /* EMAC1TX_ECC */
    {0x00000018, 0x01010001, 0x01010001},
    /* EMAC2RX_ECC */
    {0x0000001C, 0x01010001, 0x01010001},
    /* EMAC2TX_ECC */
    {0x00000020, 0x01010001, 0x01010001},
    /* NAND_ECC */
    {0x0000002C, 0x01010001, 0x01010001},
    /* NAND_READ_ECC */
    {0x00000030, 0x01010001, 0x01010001},
    /* NAND_WRITE_ECC */
    {0x00000034, 0x01010001, 0x01010001},
    /* OCRAM_ECC */
    {0x00000038, 0x01010001, 0x01010001},
    /* SDMMC_ECC */
    {0x00000040, 0x01010001, 0x01010001},
    /* USB0_ECC */
    {0x00000044, 0x01010001, 0x01010001},
    /* USB1_CACHEECC */
    {0x00000048, 0x01010001, 0x01010001},
    /* CLOCK_MANAGER */
    {0x0000004C, 0x01010001, 0x01010001},
    /* IO_MANAGER */
    {0x00000054, 0x01010001, 0x01010001},
    /* RESET_MANAGER */
    {0x00000058, 0x01010001, 0x01010001},
    /* SYSTEM_MANAGER */
    {0x0000005C, 0x01010001, 0x01010001},
    /* OSC0_TIMER */
    {0x00000060, 0x01010301, 0x01010301},
    /* OSC1_TIMER0*/
    {0x00000064, 0x01010301, 0x01010301},
    /* WATCHDOG0 */
    {0x00000068, 0x01010301, 0x01010301},
    /* WATCHDOG1 */
    {0x0000006C, 0x01010301, 0x01010301},
    /* WATCHDOG2 */
    {0x00000070, 0x01010301, 0x01010301},
    /* WATCHDOG3 */
    {0x00000074, 0x01010301, 0x01010301},
    /* DAP */
    {0x00000078, 0x03010001, 0x03010001},
    /* WATCHDOG4 */
    {0x0000007C, 0x01010301, 0x01010301},
    /* POWER_MANAGER */
    {0x00000080, 0x01010001, 0x01010001},
    /* USB1_RXECC */
    {0x00000084, 0x01010001, 0x01010001},
    /* USB1_TXECC */
    {0x00000088, 0x01010001, 0x01010001},
    /* L4_NOC_PROBES */
    {0x00000090, 0x01010001, 0x01010001},
    /* L4_NOC_QOS */
    {0x00000094, 0x01010001, 0x01010001}
};

static const prt_hps_ccu_t ccu_noc_fw_lwsoc2fpga[] = {
    /* LWSOC2FPGA_CSR */
    {0x00000000, 0x0FFE0301, 0x0FFE0301}
};

static const prt_hps_ccu_t ccu_noc_fw_soc2fpga[] = {
    /* SOC2FPGA_CSR */
    {0x00000000, 0x0FFE0301, 0x0FFE0301}
};

static const prt_hps_ccu_t ccu_noc_fw_tcu[] = {
    /* TCU_CSR */
    {0x00000000, 0x01010001, 0x01010001}
};

static const prt_hps_ccu_mod_t ccu_modules[] = {
    {0x1C000000UL, ccu_caiu0, sizeof(ccu_caiu0) / sizeof(ccu_caiu0[0])},
    {0x1C001000UL, ccu_ncaiu0, sizeof(ccu_ncaiu0) / sizeof(ccu_ncaiu0[0])},
    {0x1C002000UL, ccu_ncaiu1, sizeof(ccu_ncaiu1) / sizeof(ccu_ncaiu1[0])},
    {0x1C003000UL, ccu_ncaiu2, sizeof(ccu_ncaiu2) / sizeof(ccu_ncaiu2[0])},
    {0x1C004000UL, ccu_ncaiu3, sizeof(ccu_ncaiu3) / sizeof(ccu_ncaiu3[0])},
    {0x1C005000UL, ccu_dce0, sizeof(ccu_dce0) / sizeof(ccu_dce0[0])},
    {0x1C006000UL, ccu_dce1, sizeof(ccu_dce1) / sizeof(ccu_dce1[0])},
    {0x1C007000UL, ccu_dmi0, sizeof(ccu_dmi0) / sizeof(ccu_dmi0[0])},
    {0x1C008000UL, ccu_dmi1, sizeof(ccu_dmi1) / sizeof(ccu_dmi1[0])},
    {0x10D21000UL, ccu_noc_fw_l4_per, sizeof(ccu_noc_fw_l4_per) / sizeof(ccu_noc_fw_l4_per[0])},
    {0x10D21100UL, ccu_noc_fw_l4_sys, sizeof(ccu_noc_fw_l4_sys) / sizeof(ccu_noc_fw_l4_sys[0])},
    {0x10D21300UL, ccu_noc_fw_lwsoc2fpga, sizeof(ccu_noc_fw_lwsoc2fpga) / sizeof(ccu_noc_fw_lwsoc2fpga[0])},
    {0x10D21200UL, ccu_noc_fw_soc2fpga, sizeof(ccu_noc_fw_soc2fpga) / sizeof(ccu_noc_fw_soc2fpga[0])},
    {0x10D21400UL, ccu_noc_fw_tcu, sizeof(ccu_noc_fw_tcu) / sizeof(ccu_noc_fw_tcu[0])},
};

void prt_hps_ccu_init(void) {
    for (size_t m = 0; m < (sizeof(ccu_modules) / sizeof(ccu_modules[0])); m++) {
        for (size_t i = 0; i < ccu_modules[m].len; i++) {
            const prt_hps_ccu_t *r = &ccu_modules[m].tbl[i];
            volatile uint32_t *reg = (volatile uint32_t *)(ccu_modules[m].base + r->ofs);

            if (r->mask == 0xFFFFFFFFU) {
                *reg = r->val;
            } else if (r->mask != 0U) {
                *reg = (*reg & ~r->mask) | (r->val & r->mask);
            }
        }
    }
}
