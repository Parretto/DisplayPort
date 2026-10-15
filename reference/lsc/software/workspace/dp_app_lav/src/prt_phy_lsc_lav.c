/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/

    Module: PHY Lattice Avant (MPPHY) Driver
    (c) 2021 - 2026 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - TX voltage swing and pre-emphasis

    The Avant counterpart of prt_phy_lsc_cpnx.c, with the same interface towards the
    application. The PHY is programmed with the rate change procedure of the MPPHY
    user guide, with the line rate registers from a table generated out of the PHY
    profiles (prt_phy_lsc_lav_dr.h).

    Unlike HDMI a DP transmitter and receiver each set their own line rate. The
    transmitter rate lives in the MPLL and one lane register, the receiver rate in the
    lane registers of the CDR, so the two are programmed apart. The transmitter procedure
    resets the quad, which takes the receiver down with it; the receiver procedure only
    touches the receiver.

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

// Includes
#include "prt_types.h"
#include "timer.h"
#include "prt_phy_lsc_lav.h"
#include "prt_phy_lsc_lav_dr.h"
#include <stdio.h>

// The rate the PHY is generated with (profile 1)
#define PRT_PHY_LSC_BASE_MBPS       5400

// Local prototypes
static prt_bool prt_phy_lsc_rmw (prt_phy_lsc_ds_struct *phy, prt_u16 adr, prt_u16 dat, prt_u16 msk);
static prt_bool prt_phy_lsc_poll (prt_phy_lsc_ds_struct *phy, prt_u16 adr, prt_u16 msk, prt_bool assert);
static prt_u16 prt_phy_lsc_lane_adr (prt_u8 lane, prt_u16 adr);
static prt_u8 prt_phy_lsc_find (prt_u16 mbps);
static prt_u16 prt_phy_lsc_mbps (prt_u8 rate);
static void prt_phy_lsc_wr_lanes (prt_phy_lsc_ds_struct *phy, const prt_phy_lsc_lav_reg_struct *reg, prt_u8 n);
static prt_bool prt_phy_lsc_pstate (prt_phy_lsc_ds_struct *phy, prt_u16 reg, prt_u16 pstate);
static prt_bool prt_phy_lsc_rst_assert (prt_phy_lsc_ds_struct *phy);
static prt_bool prt_phy_lsc_rst_deassert (prt_phy_lsc_ds_struct *phy);
static prt_bool prt_phy_lsc_pio_wait (prt_phy_lsc_ds_struct *phy, prt_u32 msk, prt_bool set);
static prt_bool prt_phy_lsc_tx_rst (prt_phy_lsc_ds_struct *phy);
static void prt_phy_lsc_rx_rst (prt_phy_lsc_ds_struct *phy);
static void prt_phy_lsc_rx_lane_cfg (prt_phy_lsc_ds_struct *phy);

// Initialize
void prt_phy_lsc_init (prt_phy_lsc_ds_struct *phy, prt_u32 base, struct timer_instance *timer)
{
	// Base address
	phy->dev = (prt_phy_lsc_dev_struct *) base;

	// Timer
	phy->timer = timer;

	// The PHY comes up on the rate it was generated with
	phy->tx_rate = prt_phy_lsc_find (PRT_PHY_LSC_BASE_MBPS);
	phy->rx_rate = phy->tx_rate;
	phy->rx_lanes = PRT_PHY_LSC_PORTS;

	// Receiver lane settings the IP generator does not offer
	prt_phy_lsc_rx_lane_cfg (phy);
}

// Read
prt_u16 prt_phy_lsc_rd (prt_phy_lsc_ds_struct *phy, prt_u16 adr)
{
	// Variables
	uint64_t time_now;
	uint64_t time_out;
	prt_u16 dat = 0;
	prt_bool rdy = PRT_FALSE;

	// Command
	phy->dev->lmmi = (adr << PRT_PHY_LSC_LMMI_ADR_SHIFT);
	phy->dev->ctl = PRT_PHY_LSC_DEV_CTL_RD;

	// Wait for the data
	timer_get_mtime (phy->timer, &time_now);
	time_out = time_now + PRT_PHY_LSC_LMMI_TIMEOUT;

	do
	{
		if (phy->dev->sta & PRT_PHY_LSC_DEV_STA_RDY)
		{
			dat = phy->dev->lmmi;
			rdy = PRT_TRUE;
		}
		else
			timer_get_mtime (phy->timer, &time_now);
	} while (!rdy && (time_now < time_out));

	if (!rdy)
		printf ("PHY: LMMI read timeout (%x)\n", adr);

	// Clear ready bit
	phy->dev->sta = PRT_PHY_LSC_DEV_STA_RDY;

	return dat;
}

// Write
void prt_phy_lsc_wr (prt_phy_lsc_ds_struct *phy, prt_u16 adr, prt_u16 dat)
{
	phy->dev->lmmi = (adr << PRT_PHY_LSC_LMMI_ADR_SHIFT) | (dat << PRT_PHY_LSC_LMMI_DAT_SHIFT);
	phy->dev->ctl = PRT_PHY_LSC_DEV_CTL_WR;
	phy->dev->sta = PRT_PHY_LSC_DEV_STA_RDY;
}

// Read-modify-write
static prt_bool prt_phy_lsc_rmw (prt_phy_lsc_ds_struct *phy, prt_u16 adr, prt_u16 dat, prt_u16 msk)
{
	prt_u16 rd_dat;

	rd_dat = prt_phy_lsc_rd (phy, adr);
	rd_dat &= ~msk;
	rd_dat |= (dat & msk);
	prt_phy_lsc_wr (phy, adr, rd_dat);

	return PRT_TRUE;
}

// Poll a register until the masked bits are set (assert) or clear
static prt_bool prt_phy_lsc_poll (prt_phy_lsc_ds_struct *phy, prt_u16 adr, prt_u16 msk, prt_bool assert)
{
	uint64_t time_now;
	uint64_t time_out;
	prt_u16 dat;

	timer_get_mtime (phy->timer, &time_now);
	time_out = time_now + PRT_PHY_LSC_LOCK_TIMEOUT;

	do
	{
		dat = prt_phy_lsc_rd (phy, adr) & msk;

		if ((assert && (dat != 0)) || (!assert && (dat == 0)))
			return PRT_TRUE;

		timer_get_mtime (phy->timer, &time_now);
	} while (time_now < time_out);

	return PRT_FALSE;
}

// Lane address (LMMI word address of a lane register)
static prt_u16 prt_phy_lsc_lane_adr (prt_u8 lane, prt_u16 adr)
{
	return PRT_PHY_LSC_LANE_BASE + (lane << 8) + adr;
}

// Line rate in Mb/s
static prt_u16 prt_phy_lsc_mbps (prt_u8 rate)
{
	switch (rate)
	{
		case PRT_PHY_LSC_LINERATE_2700 : return 2700;
		case PRT_PHY_LSC_LINERATE_5400 : return 5400;
		case PRT_PHY_LSC_LINERATE_8100 : return 8100;
		default : return 1620;
	}
}

// Table index of a line rate. A rate without an entry gets the base rate.
static prt_u8 prt_phy_lsc_find (prt_u16 mbps)
{
	prt_u8 base = 0;

	for (prt_u8 i = 0; i < PRT_PHY_LSC_LAV_RATES; i++)
	{
		if (prt_phy_lsc_lav_rates[i].mbps == mbps)
			return i;

		if (prt_phy_lsc_lav_rates[i].mbps == PRT_PHY_LSC_BASE_MBPS)
			base = i;
	}

	printf ("PHY: no registers for %d Mb/s\n", mbps);
	return base;
}

// Write a lane block to all four lanes.
// The power state is part of the rate registers reg15E (TX) and reg14C (RX); the table
// holds P0 there. The block is written while the lanes are in P1, so the power state
// field is kept at P1 here and set back to P0 by the procedure afterwards.
static void prt_phy_lsc_wr_lanes (prt_phy_lsc_ds_struct *phy, const prt_phy_lsc_lav_reg_struct *reg, prt_u8 n)
{
	prt_u16 dat;

	for (prt_u8 l = 0; l < PRT_PHY_LSC_PORTS; l++)
	{
		for (prt_u8 i = 0; i < n; i++)
		{
			dat = reg[i].dat;

			if ((reg[i].adr == PRT_PHY_LSC_REG_TX_PSTATE) || (reg[i].adr == PRT_PHY_LSC_REG_RX_PSTATE))
				dat = (dat & ~PRT_PHY_LSC_PSTATE_MSK) | PRT_PHY_LSC_PSTATE_P1;

			prt_phy_lsc_wr (phy, prt_phy_lsc_lane_adr (l, reg[i].adr), dat);
		}
	}
}

// Set the power state of all lanes (reg15E for TX, reg14C for RX)
static prt_bool prt_phy_lsc_pstate (prt_phy_lsc_ds_struct *phy, prt_u16 reg, prt_u16 pstate)
{
	for (prt_u8 l = 0; l < PRT_PHY_LSC_PORTS; l++)
		prt_phy_lsc_rmw (phy, prt_phy_lsc_lane_adr (l, reg), pstate, PRT_PHY_LSC_PSTATE_MSK);

	return PRT_TRUE;
}

// Assert PHY reset (low active)
static prt_bool prt_phy_lsc_rst_assert (prt_phy_lsc_ds_struct *phy)
{
	prt_phy_lsc_rmw (phy, PRT_PHY_LSC_REG_QUAD_PHY_RST, 0x0000, PRT_PHY_LSC_REG_QUAD_PHY_RST_N);
	return prt_phy_lsc_poll (phy, PRT_PHY_LSC_REG_QUAD_PHY_RST_STA, PRT_PHY_LSC_REG_QUAD_PHY_RST_STA_N, PRT_FALSE);
}

// Deassert PHY reset (low active)
static prt_bool prt_phy_lsc_rst_deassert (prt_phy_lsc_ds_struct *phy)
{
	prt_phy_lsc_rmw (phy, PRT_PHY_LSC_REG_QUAD_PHY_RST, PRT_PHY_LSC_REG_QUAD_PHY_RST_N, PRT_PHY_LSC_REG_QUAD_PHY_RST_N);
	return prt_phy_lsc_poll (phy, PRT_PHY_LSC_REG_QUAD_PHY_RST_STA, PRT_PHY_LSC_REG_QUAD_PHY_RST_STA_N, PRT_TRUE);
}

// Wait for PIO input bits to be set (set) or clear, bounded by the lock timeout
static prt_bool prt_phy_lsc_pio_wait (prt_phy_lsc_ds_struct *phy, prt_u32 msk, prt_bool set)
{
	uint64_t time_now;
	uint64_t time_out;
	prt_u32 dat;

	timer_get_mtime (phy->timer, &time_now);
	time_out = time_now + PRT_PHY_LSC_LOCK_TIMEOUT;

	do
	{
		dat = prt_phy_lsc_pio_dat_get (phy) & msk;

		if ((set && (dat == msk)) || (!set && (dat == 0)))
			return PRT_TRUE;

		timer_get_mtime (phy->timer, &time_now);
	} while (time_now < time_out);

	return PRT_FALSE;
}

// TX reset
// Takes the transmitter datapath out of reset and enables the transmitter once the
// reset done flags are there.
static prt_bool prt_phy_lsc_tx_rst (prt_phy_lsc_ds_struct *phy)
{
	prt_phy_lsc_pio_dat_set (phy, PRT_PHY_LSC_PIO_OUT_TX_PMA_RST | PRT_PHY_LSC_PIO_OUT_TX_PCS_RST);
	prt_phy_lsc_pio_dat_clr (phy, PRT_PHY_LSC_PIO_OUT_TX_VLD);
	prt_phy_lsc_sleep (phy, PRT_PHY_LSC_RST_PULSE);
	prt_phy_lsc_pio_dat_clr (phy, PRT_PHY_LSC_PIO_OUT_TX_PMA_RST | PRT_PHY_LSC_PIO_OUT_TX_PCS_RST);

	if (!prt_phy_lsc_pio_wait (phy, PRT_PHY_LSC_PIO_IN_TX_PMA_RST_DONE | PRT_PHY_LSC_PIO_IN_TX_PCS_RST_DONE, PRT_TRUE))
		return PRT_FALSE;

	prt_phy_lsc_sleep (phy, PRT_PHY_LSC_RST_PULSE);
	prt_phy_lsc_pio_dat_set (phy, PRT_PHY_LSC_PIO_OUT_TX_VLD);

	return PRT_TRUE;
}

// RX reset
// The PCS reset is released after the PMA reports its reset done, not together with it,
// so the word aligner does not fix a boundary while the CDR is still settling (see the
// HDMI driver). A timeout is not fatal : with no source connected nothing reports back.
static void prt_phy_lsc_rx_rst (prt_phy_lsc_ds_struct *phy)
{
	prt_phy_lsc_pio_dat_set (phy, PRT_PHY_LSC_PIO_OUT_RX_PMA_RST | PRT_PHY_LSC_PIO_OUT_RX_PCS_RST);
	prt_phy_lsc_sleep (phy, PRT_PHY_LSC_RST_PULSE);

	// Release the PMA first and give the CDR the chance to relock
	prt_phy_lsc_pio_dat_clr (phy, PRT_PHY_LSC_PIO_OUT_RX_PMA_RST);
	(void) prt_phy_lsc_pio_wait (phy, PRT_PHY_LSC_PIO_IN_RX_PMA_RST_DONE, PRT_TRUE);

	// Only now fix the word boundary
	prt_phy_lsc_pio_dat_clr (phy, PRT_PHY_LSC_PIO_OUT_RX_PCS_RST);
	(void) prt_phy_lsc_pio_wait (phy, PRT_PHY_LSC_PIO_IN_RX_PCS_RST_DONE, PRT_TRUE);
}

// Receiver lane settings the IP generator does not offer. A PHY reset loads the
// generated values again, so this runs after every PHY reset.
//  - Word alignment on any byte. The DP_eDP mode aligns the comma (K28.5) to an even
//    byte. The comma is also the blanking start symbol, which lands on odd bytes as well,
//    and each one moved the lane by a symbol : the DPRX video kept dropping to idle.
//    The DPRX finds the symbol phase itself.
//  - Forced recalibration. The receiver keeps its calibration per rate bank and reuses it
//    when it comes back into P0. After the cable was out the stored one no longer locks,
//    so the receiver calibrates again on every return to P0.
//  - Gearbox bonding. All lanes are read with the lane 0 recovered clock (rx_in_clk) and
//    there is no elastic buffer in DP mode, so the active lanes are bonded, as generated
//    for four lanes. A bonded group is only valid with a signal on every lane in it : the
//    lanes the source leaves off are taken out, each bonded to itself only.
static void prt_phy_lsc_rx_lane_cfg (prt_phy_lsc_ds_struct *phy)
{
	prt_u16 act = (1 << phy->rx_lanes) - 1;

	for (prt_u8 l = 0; l < PRT_PHY_LSC_PORTS; l++)
	{
		prt_phy_lsc_rmw (phy, prt_phy_lsc_lane_adr (l, PRT_PHY_LSC_REG_RX_BOND), (l < phy->rx_lanes) ? act : (1 << l), PRT_PHY_LSC_REG_RX_BOND_MSK);
		prt_phy_lsc_rmw (phy, prt_phy_lsc_lane_adr (l, PRT_PHY_LSC_REG_RX_WA), PRT_PHY_LSC_REG_RX_WA_2BYTE_DIS, PRT_PHY_LSC_REG_RX_WA_2BYTE_DIS);
		prt_phy_lsc_rmw (phy, prt_phy_lsc_lane_adr (l, PRT_PHY_LSC_REG_RX_RECAL), PRT_PHY_LSC_REG_RX_RECAL_FORCE, PRT_PHY_LSC_REG_RX_RECAL_FORCE);
	}
}

// TX rate
// The rate change procedure of the MPPHY user guide, as the HDMI driver runs it. The
// MPLL only calibrates again through the quad reset of step 7, and that reset takes the
// receiver down as well, so the receiver is taken out of reset again at the end on the
// rate it had.
void prt_phy_lsc_tx_rate (prt_phy_lsc_ds_struct *phy, prt_u8 rate)
{
	const prt_phy_lsc_lav_rate_struct *tgt;
	prt_bool sta;

	phy->tx_rate = prt_phy_lsc_find (prt_phy_lsc_mbps (rate));
	tgt = &prt_phy_lsc_lav_rates[phy->tx_rate];

	// Step 1 and 2 - Assert TX and RX PCS reset and wait for the reset done to drop.
	// A timeout is not fatal, see the HDMI driver.
	prt_phy_lsc_pio_dat_set (phy, PRT_PHY_LSC_PIO_OUT_TX_PCS_RST | PRT_PHY_LSC_PIO_OUT_RX_PCS_RST);
	(void) prt_phy_lsc_pio_wait (phy, PRT_PHY_LSC_PIO_IN_TX_PCS_RST_DONE | PRT_PHY_LSC_PIO_IN_RX_PCS_RST_DONE, PRT_FALSE);

	// Step 3 and 4 - Assert TX and RX PMA reset and wait for the reset done to drop
	prt_phy_lsc_pio_dat_set (phy, PRT_PHY_LSC_PIO_OUT_TX_PMA_RST | PRT_PHY_LSC_PIO_OUT_RX_PMA_RST);
	(void) prt_phy_lsc_pio_wait (phy, PRT_PHY_LSC_PIO_IN_TX_PMA_RST_DONE | PRT_PHY_LSC_PIO_IN_RX_PMA_RST_DONE, PRT_FALSE);

	// Step 5 - Disable the reference clock (whole quad)
	prt_phy_lsc_rmw (phy, PRT_PHY_LSC_REG_QUAD_REFCLK, 0x0000, PRT_PHY_LSC_REG_QUAD_REFCLK_EN);

	// Step 6 - All lanes into the P1 power state
	prt_phy_lsc_pstate (phy, PRT_PHY_LSC_REG_TX_PSTATE, PRT_PHY_LSC_PSTATE_P1);
	prt_phy_lsc_pstate (phy, PRT_PHY_LSC_REG_RX_PSTATE, PRT_PHY_LSC_PSTATE_P1);

	// Step 7 - Assert PHY reset for at least 500 ns
	if (!prt_phy_lsc_rst_assert (phy))
		printf ("PHY: reset assert timeout\n");
	prt_phy_lsc_sleep (phy, PRT_PHY_LSC_TICKS_US);

	// Step 8 - The reference clock is 135 MHz for every rate, nothing to change

	// Step 9 - MPLL and transmitter lane registers of the new rate
	prt_phy_lsc_wr_lanes (phy, tgt->tx_lane, tgt->tx_lane_n);

	for (prt_u8 i = 0; i < tgt->tx_quad_n; i++)
		prt_phy_lsc_wr (phy, tgt->tx_quad[i].adr, tgt->tx_quad[i].dat);

	// Step 10 - Wait for 15 us
	prt_phy_lsc_sleep (phy, 15 * PRT_PHY_LSC_TICKS_US);

	// Step 11 - Enable the reference clock
	prt_phy_lsc_rmw (phy, PRT_PHY_LSC_REG_QUAD_REFCLK, PRT_PHY_LSC_REG_QUAD_REFCLK_EN, PRT_PHY_LSC_REG_QUAD_REFCLK_EN);

	// Step 12 - Wait for 1 us
	prt_phy_lsc_sleep (phy, PRT_PHY_LSC_TICKS_US);

	// Step 13 - All lanes back into P0
	prt_phy_lsc_pstate (phy, PRT_PHY_LSC_REG_TX_PSTATE, PRT_PHY_LSC_PSTATE_P0);
	prt_phy_lsc_pstate (phy, PRT_PHY_LSC_REG_RX_PSTATE, PRT_PHY_LSC_PSTATE_P0);

	// Step 14 - Wait for 1 us
	prt_phy_lsc_sleep (phy, PRT_PHY_LSC_TICKS_US);

	// Step 15 and 16 - Deassert PHY reset and wait 500 ns
	if (!prt_phy_lsc_rst_deassert (phy))
		printf ("PHY: reset deassert timeout\n");
	prt_phy_lsc_sleep (phy, PRT_PHY_LSC_TICKS_US);

	prt_phy_lsc_rx_lane_cfg (phy);

	// Steps 17 to 20 - Transmitter first, so it comes up without a source on the receiver
	sta = prt_phy_lsc_tx_rst (phy);

	prt_phy_lsc_rx_rst (phy);

	// The HDMI design measured the transmitter reset done flags arriving only after the
	// receiver was released as well; ask once more before giving up.
	if (!sta)
	{
		sta = prt_phy_lsc_pio_wait (phy, PRT_PHY_LSC_PIO_IN_TX_PMA_RST_DONE | PRT_PHY_LSC_PIO_IN_TX_PCS_RST_DONE, PRT_TRUE);

		if (sta)
		{
			prt_phy_lsc_sleep (phy, PRT_PHY_LSC_RST_PULSE);
			prt_phy_lsc_pio_dat_set (phy, PRT_PHY_LSC_PIO_OUT_TX_VLD);
		}
		else
			printf ("PHY: TX reset done timeout (pio %x)\n", prt_phy_lsc_pio_dat_get (phy));
	}
}

// RX lanes
// Takes effect with the next receiver rate setting.
void prt_phy_lsc_rx_lanes (prt_phy_lsc_ds_struct *phy, prt_u8 lanes)
{
	phy->rx_lanes = ((lanes == 1) || (lanes == 2)) ? lanes : PRT_PHY_LSC_PORTS;
}

// RX rate
// Only the receiver : its rate lives in the lane registers of the CDR, which calibrates
// per lane when it comes out of reset, so the quad and the transmitter are left alone.
// RX configuration for the current rate
// Receiver into reset, lanes into P1, rate registers, back into P0, staged release.
static void prt_phy_lsc_rx_cfg (prt_phy_lsc_ds_struct *phy)
{
	const prt_phy_lsc_lav_rate_struct *tgt = &prt_phy_lsc_lav_rates[phy->rx_rate];

	// Receiver into reset
	prt_phy_lsc_pio_dat_set (phy, PRT_PHY_LSC_PIO_OUT_RX_PCS_RST);
	(void) prt_phy_lsc_pio_wait (phy, PRT_PHY_LSC_PIO_IN_RX_PCS_RST_DONE, PRT_FALSE);
	prt_phy_lsc_pio_dat_set (phy, PRT_PHY_LSC_PIO_OUT_RX_PMA_RST);
	(void) prt_phy_lsc_pio_wait (phy, PRT_PHY_LSC_PIO_IN_RX_PMA_RST_DONE, PRT_FALSE);

	// Receiver lanes into P1, rate registers, back into P0. The rate registers include the
	// power state register with P0 in it, so the lanes go into P1 once more after them :
	// the return to P0 is what starts the calibration.
	prt_phy_lsc_pstate (phy, PRT_PHY_LSC_REG_RX_PSTATE, PRT_PHY_LSC_PSTATE_P1);
	prt_phy_lsc_wr_lanes (phy, tgt->rx_lane, tgt->rx_lane_n);
	prt_phy_lsc_rx_lane_cfg (phy);
	prt_phy_lsc_pstate (phy, PRT_PHY_LSC_REG_RX_PSTATE, PRT_PHY_LSC_PSTATE_P1);
	prt_phy_lsc_sleep (phy, PRT_PHY_LSC_TICKS_US);
	prt_phy_lsc_pstate (phy, PRT_PHY_LSC_REG_RX_PSTATE, PRT_PHY_LSC_PSTATE_P0);
	prt_phy_lsc_sleep (phy, PRT_PHY_LSC_TICKS_US);

	// Staged release
	prt_phy_lsc_rx_rst (phy);
}

void prt_phy_lsc_rx_rate (prt_phy_lsc_ds_struct *phy, prt_u8 rate)
{
	phy->rx_rate = prt_phy_lsc_find (prt_phy_lsc_mbps (rate));
	prt_phy_lsc_rx_cfg (phy);
}

// RX PCS reset
void prt_phy_lsc_rx_pcs_rst (prt_phy_lsc_ds_struct *phy)
{
	prt_phy_lsc_rx_rst (phy);
}

// TX voltage swing and pre-emphasis
// The transmitter cursors are PIPE coefficients with a full scale of 24: the peak amplitude is
// main + post cursor (24 = full swing, taken as 1200 mV), the de-emphasised level is
// main - post cursor. The DP swing level (400, 600, 800, 1200 mV) is the de-emphasised level, the
// pre-emphasis (0, 3.5, 6, 9.5 dB) the ratio between the peak and that level. Swing + pre-emphasis
// is 3 at most; a higher pre-emphasis gets the highest one that fits. The pre cursor stays 0.
// Table entries are {main cursor, post cursor}.
static const prt_u8 prt_phy_lsc_vap_tbl[4][4][2] = {
	{{8, 0}, {10, 2}, {12, 4}, {16, 8}},	// 400 mV : 0, 3.5, 6.0, 9.5 dB
	{{12, 0}, {15, 3}, {18, 6}, {18, 6}},	// 600 mV : 0, 3.5, 6.0 dB
	{{16, 0}, {20, 4}, {20, 4}, {20, 4}},	// 800 mV : 0, 3.5 dB
	{{24, 0}, {24, 0}, {24, 0}, {24, 0}}	// 1200 mV : 0 dB
};

void prt_phy_lsc_tx_vap (prt_phy_lsc_ds_struct *phy, prt_u8 volt, prt_u8 pre)
{
	prt_u8 main_cur;
	prt_u8 post_cur;

	if ((volt > 3) || (pre > 3))
		return;

	main_cur = prt_phy_lsc_vap_tbl[volt][pre][0];
	post_cur = prt_phy_lsc_vap_tbl[volt][pre][1];

	for (prt_u8 i = 0; i < 4; i++)
	{
		// Main cursor, pre cursor off
		prt_phy_lsc_rmw (phy, prt_phy_lsc_lane_adr (i, PRT_PHY_LSC_REG_TX_EQ), (prt_u16) main_cur << 8, 0x3f3f);

		// Post cursor
		prt_phy_lsc_rmw (phy, prt_phy_lsc_lane_adr (i, PRT_PHY_LSC_REG_TX_EQ_POST), post_cur, 0x003f);
	}
}

// TX polarity
void prt_phy_lsc_tx_pol (prt_phy_lsc_ds_struct *phy, prt_u8 port, prt_u8 inv)
{
	prt_phy_lsc_rmw (phy, prt_phy_lsc_lane_adr (port, PRT_PHY_LSC_REG_TX_INV), (inv) ? 1 : 0, 0x0001);
}

// RX polarity
void prt_phy_lsc_rx_pol (prt_phy_lsc_ds_struct *phy, prt_u8 port, prt_u8 inv)
{
	prt_phy_lsc_rmw (phy, prt_phy_lsc_lane_adr (port, PRT_PHY_LSC_REG_RX_INV), (inv) ? 1 : 0, 0x0001);
}

// PIO Data set
void prt_phy_lsc_pio_dat_set (prt_phy_lsc_ds_struct *phy, prt_u32 dat)
{
	phy->dev->pio_dout_set = dat;
}

// PIO Data clear
void prt_phy_lsc_pio_dat_clr (prt_phy_lsc_ds_struct *phy, prt_u32 dat)
{
	phy->dev->pio_dout_clr = dat;
}

// PIO Data mask
void prt_phy_lsc_pio_dat_msk (prt_phy_lsc_ds_struct *phy, prt_u32 dat, prt_u32 msk)
{
	phy->dev->pio_msk = msk;
	phy->dev->pio_dout = dat;
}

// PIO Get data
prt_u32 prt_phy_lsc_pio_dat_get (prt_phy_lsc_ds_struct *phy)
{
	return phy->dev->pio_din;
}

// Sleep
void prt_phy_lsc_sleep (prt_phy_lsc_ds_struct *phy, uint32_t ticks)
{
	uint64_t time_now;
	uint64_t time_out;

	timer_get_mtime (phy->timer, &time_now);
	time_out = time_now + ticks;

	while (time_now < time_out)
		timer_get_mtime (phy->timer, &time_now);
}
