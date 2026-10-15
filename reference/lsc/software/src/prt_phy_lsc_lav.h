/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: PHY Lattice Avant (MPPHY) Driver
    (c) 2021 - 2026 by Parretto B.V.

    History
    =======
    v1.0 - Initial release

    The device description that goes with prt_phy_lsc_lav.c : the PHY controller
    registers, the PIO map the reference design wires, and the quad and lane register
    addresses. The lane register addresses are word addresses; one covers two of the
    eight bit registers the Lattice documentation names (reg15E is 0x15E / 2 = 0xAF).
    The field positions come from the MPPHY testbench (tb_reglist.sv).

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

// Device structure (prt_phy_ctl_lsc_apb)
typedef struct {
  prt_u32 ctl; 	          // Control
  prt_u32 sta;	          // Status
  prt_u32 lmmi;           // LMMI interface
  prt_u32 pio_din;        // PIO Data in
  prt_u32 pio_dout_set;   // PIO Data out set
  prt_u32 pio_dout_clr;   // PIO Data out clear
  prt_u32 pio_dout;       // PIO Data out
  prt_u32 pio_msk;        // PIO Mask
} prt_phy_lsc_dev_struct;

// Data structure
typedef struct {
  volatile prt_phy_lsc_dev_struct *dev;
  struct timer_instance *timer;
  prt_u8 tx_rate;         // Current transmitter line rate (table index)
  prt_u8 rx_rate;         // Current receiver line rate (table index)
  prt_u8 rx_lanes;        // Active receiver lanes
} prt_phy_lsc_ds_struct;

// Line rate table
typedef struct {
  prt_u16 adr;
  prt_u16 dat;
} prt_phy_lsc_lav_reg_struct;

typedef struct {
  prt_u16 mbps;                                 // Line rate in Mb/s
  prt_u8 tx_lane_n;
  const prt_phy_lsc_lav_reg_struct *tx_lane;    // Offset within a lane, all four get it
  prt_u8 tx_quad_n;
  const prt_phy_lsc_lav_reg_struct *tx_quad;    // Full address, written once
  prt_u8 rx_lane_n;
  const prt_phy_lsc_lav_reg_struct *rx_lane;    // Offset within a lane, all four get it
} prt_phy_lsc_lav_rate_struct;

// Control register
#define PRT_PHY_LSC_DEV_CTL_WR              (1 << 0)
#define PRT_PHY_LSC_DEV_CTL_RD              (1 << 1)

// Status register
#define PRT_PHY_LSC_DEV_STA_BUSY            (1 << 0)
#define PRT_PHY_LSC_DEV_STA_RDY             (1 << 1)

// LMMI command layout. The controller has a single LMMI port, so there is no port
// number in the command.
#define PRT_PHY_LSC_LMMI_ADR_SHIFT          0
#define PRT_PHY_LSC_LMMI_DAT_SHIFT          16

// Timing. The machine timer counts the 50 MHz system clock.
#define PRT_PHY_LSC_TICKS_US                50
#define PRT_PHY_LSC_RST_PULSE               (2 * PRT_PHY_LSC_TICKS_US)
#define PRT_PHY_LSC_LOCK_TIMEOUT            (20000 * PRT_PHY_LSC_TICKS_US)
#define PRT_PHY_LSC_LMMI_TIMEOUT            (100 * PRT_PHY_LSC_TICKS_US)

// Line rates (same values as the CertusPro-NX driver)
#define PRT_PHY_LSC_LINERATE_1620           1
#define PRT_PHY_LSC_LINERATE_1485           2
#define PRT_PHY_LSC_LINERATE_2700           3
#define PRT_PHY_LSC_LINERATE_5400           4
#define PRT_PHY_LSC_LINERATE_8100           5

#define PRT_PHY_LSC_PORTS                   4           // Lanes

// PIO in
#define PRT_PHY_LSC_PIO_IN_TX_PMA_RST_DONE  (1 << 0)
#define PRT_PHY_LSC_PIO_IN_TX_PCS_RST_DONE  (1 << 1)
#define PRT_PHY_LSC_PIO_IN_RX_PMA_RST_DONE  (1 << 2)
#define PRT_PHY_LSC_PIO_IN_RX_PCS_RST_DONE  (1 << 3)
#define PRT_PHY_LSC_PIO_IN_RX_VAL           (0xf << 4)  // One per lane
#define PRT_PHY_LSC_PIO_IN_RX_SIGDET        (0xf << 8)  // Signal detect, one per lane

// PIO out
#define PRT_PHY_LSC_PIO_OUT_TX_PMA_RST      (1 << 0)
#define PRT_PHY_LSC_PIO_OUT_TX_PCS_RST      (1 << 1)
#define PRT_PHY_LSC_PIO_OUT_RX_PMA_RST      (1 << 2)
#define PRT_PHY_LSC_PIO_OUT_RX_PCS_RST      (1 << 3)
#define PRT_PHY_LSC_PIO_OUT_TX_VLD          (1 << 4)

// Quad registers
#define PRT_PHY_LSC_REG_QUAD_REFCLK         0x5a02
#define PRT_PHY_LSC_REG_QUAD_REFCLK_EN      (1 << 0)
#define PRT_PHY_LSC_REG_QUAD_PHY_RST        0x5bff
#define PRT_PHY_LSC_REG_QUAD_PHY_RST_N      (1 << 0)
#define PRT_PHY_LSC_REG_QUAD_PHY_RST_STA    0x5bfe
#define PRT_PHY_LSC_REG_QUAD_PHY_RST_STA_N  (1 << 0)

// Lane registers (offset within a lane)
#define PRT_PHY_LSC_LANE_BASE               0x5000
#define PRT_PHY_LSC_REG_RX_WA               0x000b      // reg016, RX word aligner configuration
#define PRT_PHY_LSC_REG_RX_WA_2BYTE_DIS     (1 << 4)    // Align the comma to any byte, not only to an even one
#define PRT_PHY_LSC_REG_RX_BOND             0x0083      // RX gearbox bond configuration [5:0]
#define PRT_PHY_LSC_REG_RX_BOND_MSK         0x003f
#define PRT_PHY_LSC_REG_RX_INV              0x00a0      // RX polarity invert [0]
#define PRT_PHY_LSC_REG_RX_PSTATE           0x00a6      // reg14C, RX power state [1:0]
#define PRT_PHY_LSC_REG_RX_RECAL            0x00ab      // reg156, RX recalibration : bank select [1:0], force [2], skip [3]
#define PRT_PHY_LSC_REG_RX_RECAL_FORCE      (1 << 2)
#define PRT_PHY_LSC_REG_TX_INV              0x00ad      // TX polarity invert [0]
#define PRT_PHY_LSC_REG_TX_PSTATE           0x00af      // reg15E, TX power state [1:0]
#define PRT_PHY_LSC_REG_TX_EQ               0x00b0      // TX main cursor [13:8], pre cursor [5:0]
#define PRT_PHY_LSC_REG_TX_EQ_POST          0x00b1      // TX post cursor [5:0]
#define PRT_PHY_LSC_PSTATE_MSK              0x0003
#define PRT_PHY_LSC_PSTATE_P0               0x0000
#define PRT_PHY_LSC_PSTATE_P1               0x0002

// Prototype
void prt_phy_lsc_init (prt_phy_lsc_ds_struct *phy, prt_u32 base, struct timer_instance *timer);
prt_u16 prt_phy_lsc_rd (prt_phy_lsc_ds_struct *phy, prt_u16 adr);
void prt_phy_lsc_wr (prt_phy_lsc_ds_struct *phy, prt_u16 adr, prt_u16 dat);
void prt_phy_lsc_tx_rate (prt_phy_lsc_ds_struct *phy, prt_u8 rate);
void prt_phy_lsc_rx_rate (prt_phy_lsc_ds_struct *phy, prt_u8 rate);
void prt_phy_lsc_rx_lanes (prt_phy_lsc_ds_struct *phy, prt_u8 lanes);
void prt_phy_lsc_tx_vap (prt_phy_lsc_ds_struct *phy, prt_u8 volt, prt_u8 pre);
void prt_phy_lsc_tx_pol (prt_phy_lsc_ds_struct *phy, prt_u8 port, prt_u8 inv);
void prt_phy_lsc_rx_pol (prt_phy_lsc_ds_struct *phy, prt_u8 port, prt_u8 inv);
void prt_phy_lsc_rx_pcs_rst (prt_phy_lsc_ds_struct *phy);
void prt_phy_lsc_pio_dat_set (prt_phy_lsc_ds_struct *phy, prt_u32 dat);
void prt_phy_lsc_pio_dat_clr (prt_phy_lsc_ds_struct *phy, prt_u32 dat);
void prt_phy_lsc_pio_dat_msk (prt_phy_lsc_ds_struct *phy, prt_u32 dat, prt_u32 msk);
prt_u32 prt_phy_lsc_pio_dat_get (prt_phy_lsc_ds_struct *phy);
void prt_phy_lsc_sleep (prt_phy_lsc_ds_struct *phy, uint32_t ticks);
