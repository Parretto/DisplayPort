/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: PHY Lattice CertusPro-NX Driver
    (c) 2021 - 2024 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
	v1.1 - Removed DP application and driver header dependency
    v1.2 - Added PIO

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
#include "prt_tmr.h"
#include "prt_phy_lsc_cpnx.h"
#include "prt_printf.h"

// Initialize
void prt_phy_lsc_init (prt_phy_lsc_ds_struct *phy, prt_tmr_ds_struct *tmr, prt_u32 base)
{
  	// Base address
	phy->dev = (prt_phy_lsc_dev_struct *) base;

	// Timer
	phy->tmr = tmr;

	// Unbond RX channels. 
	// By default all RX channels are bonded and the RX master clock comes from MPCS channel 0. 
	// Depending on the PCB layout the DP lane 0 doesn't have to be connected to MPCS channel 0. 
	// The MPCS channel which has the DP lane 0 is the master clock. 
	// Else the DP link training fails in single lane DP configuration. 
	// By unbonding the RX channels, the signals mpcs_rx_out_clk_o all drive their own recovered clock.
	prt_phy_lsc_unbond (phy);
}

// Read
prt_u8 prt_phy_lsc_rd (prt_phy_lsc_ds_struct *phy, prt_u8 port, prt_u16 adr)
{
	// Variables
	prt_u32 cmd;
	prt_bool exit_loop;

	// Port
	cmd = port;
	
	// Address
	cmd |= (adr << PRT_PHY_LSC_LMMI_ADR_SHIFT);

	// Write command
	phy->dev->lmmi = cmd;

	// Read
	phy->dev->ctl = PRT_PHY_LSC_DEV_CTL_RD;

     // Set alarm 1
     prt_tmr_set_alrm (phy->tmr, 1, 100);

     exit_loop = PRT_FALSE;
     do
     {
          if (phy->dev->sta & PRT_PHY_LSC_DEV_STA_RDY)
          {
               exit_loop = PRT_TRUE;
          }

          else if (prt_tmr_is_alrm (phy->tmr, 1))
          {
               prt_printf ("PHY: LMMI read timeout\n");
          }
     } while (exit_loop == PRT_FALSE);
	
	// Clear ready bit
	phy->dev->sta = PRT_PHY_LSC_DEV_STA_RDY;

	// Return data
	return phy->dev->lmmi;
}

// Write
void prt_phy_lsc_wr (prt_phy_lsc_ds_struct *phy, prt_u8 port, prt_u16 adr, prt_u8 dat)
{
	// Variables
	prt_u32 cmd;
	prt_bool exit_loop;

	// Port
	cmd = port;
	
	// Address
	cmd |= (adr << PRT_PHY_LSC_LMMI_ADR_SHIFT);

	// Data
	cmd |= (dat << PRT_PHY_LSC_LMMI_DAT_SHIFT);

	// Write command 
	phy->dev->lmmi = cmd;

	// Write
	phy->dev->ctl = PRT_PHY_LSC_DEV_CTL_WR;

	// Clear ready bit
	phy->dev->sta = PRT_PHY_LSC_DEV_STA_RDY;
}

// Get TX PLL lock
prt_bool prt_phy_lsc_get_txpll_lock (prt_phy_lsc_ds_struct *phy)
{
	// Variables
	prt_u8 dat;

	for (prt_u8 i = 0; i < 4; i++)
	{
		// Read PMA status register
		dat = prt_phy_lsc_rd (phy, i, 0x7f);

		if ((dat & PRT_PHY_LSC_REG7F_TXCLKSTABLE) == 0)
			return PRT_FALSE;
	}
	return PRT_TRUE;
}

// Get RX PLL lock
prt_bool prt_phy_lsc_get_rxpll_lock (prt_phy_lsc_ds_struct *phy)
{
	// Variables
	prt_u8 dat;

	for (prt_u8 i = 0; i < 4; i++)
	{
		// Read PMA status register
		dat = prt_phy_lsc_rd (phy, i, 0x7f);

		if ((dat & PRT_PHY_LSC_REG7F_RXCLKSTABLE) == 0)
			return PRT_FALSE;
	}
	return PRT_TRUE;
}

// Update settings
void prt_phy_lsc_upd (prt_phy_lsc_ds_struct *phy)
{
	for (prt_u8 i = 0; i < 4; i++)
	{
		// Update settings
		prt_phy_lsc_wr (phy, i, 0x80, 0x01);
	}
}

// Voltage and pre-emphasis
void prt_phy_lsc_tx_vap (prt_phy_lsc_ds_struct *phy, prt_u8 volt, prt_u8 pre)
{
	// Variables
	prt_u8 dat;

	// Voltage level
	switch (volt)	
	{
		case 1 : dat = 64; break;	// 600 mV
		case 2 : dat = 85; break;	// 800 mV
		case 3 : dat = 128; break;	// 1200 mV
		default : dat = 42; break;	// 400 mV
	}

	for (prt_u8 i = 0; i < 4; i++)
	{
		// TX amplitude
		prt_phy_lsc_wr (phy, i, 0x18, dat);
	}

	// Pre-emphasis level
	switch (pre)	
	{
		case 1 : dat = 32; break;	// 3.5 dB
		case 2 : dat = 64; break;	// 6.0 dB
		case 3 : dat = 128; break;	// 9.5 dB
		default : dat = 0; break;	// 0 dB
	}

	for (prt_u8 i = 0; i < 4; i++)
	{
		// TX post cursor
		prt_phy_lsc_wr (phy, i, 0x0a, dat);
	}

	// Update settings
	prt_phy_lsc_upd (phy);
}

// Encode PLL M
prt_u8 prt_phy_lsc_enc_pll_m (prt_u8 m)
{
	prt_u8 dat;

	switch (m)
	{
		case 2 : dat = 1; break;
		case 4 : dat = 2; break;
		case 8 : dat = 3; break;
		default : dat = 0; break;
	}

	return dat;
}

// Encode PLL F
prt_u8 prt_phy_lsc_enc_pll_f (prt_u8 f)
{
	prt_u8 dat;

	switch (f)
	{
		case 2 : dat = 1; break;
		case 3 : dat = 2; break;
		case 4 : dat = 3; break;
		case 5 : dat = 4; break;
		case 6 : dat = 5; break;
		default : dat = 0; break;
	}

	return dat;
}

// Encode PLL N
prt_u8 prt_phy_lsc_enc_pll_n (prt_u8 n)
{
	prt_u8 dat;

	switch (n)
	{
		case 8  : dat = 0x7; break;
		case 10 : dat = 0x9; break;
		case 16 : dat = 0xf; break;
		case 20 : dat = 0x13; break;
		default : dat = 0x4; break;
	}

	return dat;
}

// TX rate 
void prt_phy_lsc_tx_rate (prt_phy_lsc_ds_struct *phy, prt_u8 rate)
{
	prt_phy_lsc_rate (phy, rate, PRT_TRUE);
}

// RX rate 
void prt_phy_lsc_rx_rate (prt_phy_lsc_ds_struct *phy, prt_u8 rate)
{
	prt_phy_lsc_rate (phy, rate, PRT_FALSE);
}

// Rate 
void prt_phy_lsc_rate (prt_phy_lsc_ds_struct *phy, prt_u8 rate, prt_u8 tx)
{
	// Variables 
	prt_u8 m;
	prt_u8 f;
	prt_u8 n;
	prt_u8 dat;
	prt_bool exit_loop;
	prt_u16 adr;
	prt_bool lock;

	// Disable the frequency comparator for RXPLL
	if (tx == PRT_FALSE)
	{
		// Read register (only channel 0)
		dat = prt_phy_lsc_rd (phy, 0, 0x0e);

		// Set NO_FMCP bit
		dat |= PRT_PHY_LSC_REG0E_NO_FCMP;

		// Write all channels
		for (prt_u8 i = 0; i < 4; i++)
		{
			prt_phy_lsc_wr (phy, i, 0x0e, dat);
		}
	}

	switch (rate)
	{
		// 1.485 Gbps
		case PRT_PHY_LSC_LINERATE_1485 : 
			m = prt_phy_lsc_enc_pll_m (4);
			f = prt_phy_lsc_enc_pll_f (1);
			n = prt_phy_lsc_enc_pll_n (20);
			break;

		// 2.7 Gbps
		case PRT_PHY_LSC_LINERATE_2700 : 
			m = prt_phy_lsc_enc_pll_m (2);
			f = prt_phy_lsc_enc_pll_f (1);
			n = prt_phy_lsc_enc_pll_n (20);
			break;

		// 5.4 Gbps
		case PRT_PHY_LSC_LINERATE_5400 : 
			m = prt_phy_lsc_enc_pll_m (1);
			f = prt_phy_lsc_enc_pll_f (2);
			n = prt_phy_lsc_enc_pll_n (20);
			break;

		// 8.1 Gbps
		case PRT_PHY_LSC_LINERATE_8100 : 
			m = prt_phy_lsc_enc_pll_m (1);
			f = prt_phy_lsc_enc_pll_f (3);
			n = prt_phy_lsc_enc_pll_n (20);
			break;

		// 1.62 Gbps
		default :
			m = prt_phy_lsc_enc_pll_m (4);
			f = prt_phy_lsc_enc_pll_f (1);
			n = prt_phy_lsc_enc_pll_n (20);
			break;
	}

	// PLL reset
	if (tx == PRT_TRUE)
		prt_phy_lsc_txpll_rst (phy, PRT_TRUE);
	else
		prt_phy_lsc_rxpll_rst (phy, PRT_TRUE);

	// F divider register
	if (tx == PRT_TRUE)
		adr = 0x04;
	else
		adr = 0x06;

	// Read register (only channel 0)
	dat = prt_phy_lsc_rd (phy, 0, adr);
	
	// Clear PLL F bits
	dat &= 0xf0;

	// Set PLL F
	dat |= f;

	for (prt_u8 i; i < 4; i++)
	{
		// Update register
		prt_phy_lsc_wr (phy, i, adr, dat);
	}
	
	// M and N dividers register 
	// F divider register
	if (tx == PRT_TRUE)
		adr = 0x05;
	else
		adr = 0x07;

	// Read register (only channel 0)
	dat = prt_phy_lsc_rd (phy, 0, adr);
	
	// Clear PLL M and N bits
	dat &= 0x80;

	// Set PLL M
	dat |= (m << 5);

	// Set PLL N
	dat |= n;

	for (prt_u8 i; i < 4; i++)
	{
		// Update register
		prt_phy_lsc_wr (phy, i, adr, dat);
	}
	
	// Update settings
	prt_phy_lsc_upd (phy);

	// Release PLL reset
	if (tx == PRT_TRUE)
		prt_phy_lsc_txpll_rst (phy, PRT_FALSE);
	else
		prt_phy_lsc_rxpll_rst (phy, PRT_FALSE);

	// Wait for PLL lock
     // Set alarm 0
     prt_tmr_set_alrm (phy->tmr, 0, PRT_PHY_LSC_LOCK_TIMEOUT);

     exit_loop = PRT_FALSE;
     do
     {
     	// Get PLL lock
		if (tx == PRT_TRUE)
     		lock = prt_phy_lsc_get_txpll_lock (phy);
     	else
     		lock = prt_phy_lsc_get_rxpll_lock (phy);

          if (lock == PRT_TRUE)
          {
               exit_loop = PRT_TRUE;
          }

          else if (prt_tmr_is_alrm (phy->tmr, 0))
          {
               prt_printf ("PHY: PLL timeout\n");
               exit_loop = PRT_TRUE;
          }
     } while (exit_loop == PRT_FALSE);
	
	// Assert PHY reset
	if (tx == PRT_TRUE)
		prt_phy_lsc_txrst (phy);
	else
		prt_phy_lsc_rxrst (phy);
}

// TXPLL reset
void prt_phy_lsc_txpll_rst (prt_phy_lsc_ds_struct *phy, prt_u8 rst)
{
	// Variables 
	prt_u8 dat;

	// Read register (only channel 0)
	dat = prt_phy_lsc_rd (phy, 0, 0x66);

	// Set reset bit
	if (rst)
		dat |= PRT_PHY_LSC_REG66_TXPLL_RST;

	// Clear reset bit
	else
		dat &= ~(PRT_PHY_LSC_REG66_TXPLL_RST);

	for (prt_u8 i; i < 4; i++)
	{
		// Update register
		prt_phy_lsc_wr (phy, i, 0x66, dat);
	}
}

// RXPLL reset
void prt_phy_lsc_rxpll_rst (prt_phy_lsc_ds_struct *phy, prt_u8 rst)
{
	// Variables 
	prt_u8 dat;

	// Read register (only channel 0)
	dat = prt_phy_lsc_rd (phy, 0, 0x66);

	// Set reset bit
	if (rst)
		dat |= PRT_PHY_LSC_REG66_RXPLL_RST;

	// Clear reset bit
	else
		dat &= ~(PRT_PHY_LSC_REG66_RXPLL_RST);

	for (prt_u8 i; i < 4; i++)
	{
		// Update register
		prt_phy_lsc_wr (phy, i, 0x66, dat);
	}
}

// TX polarity 
void prt_phy_lsc_tx_pol (prt_phy_lsc_ds_struct *phy, prt_u8 port, prt_u8 inv)
{
	// Variables 
	prt_u8 dat;

	// Read register 
	dat = prt_phy_lsc_rd (phy, port, 0x74);

	// Set polarity
	if (inv == PRT_TRUE)
		dat |= PRT_PHY_LSC_REG74_TX_POLINV;

	// Clear polarity
	else
		dat &= ~(PRT_PHY_LSC_REG74_TX_POLINV);

	// Write register
	prt_phy_lsc_wr (phy, port, 0x74, dat);
}

// RX polarity 
void prt_phy_lsc_rx_pol (prt_phy_lsc_ds_struct *phy, prt_u8 port, prt_u8 inv)
{
	// Variables 
	prt_u8 dat;

	// Read register 
	dat = prt_phy_lsc_rd (phy, port, 0x74);

	// Set polarity
	if (inv == PRT_TRUE)
		dat |= PRT_PHY_LSC_REG74_RX_POLINV;

	// Clear polarity
	else
		dat &= ~(PRT_PHY_LSC_REG74_RX_POLINV);

	// Write register
	prt_phy_lsc_wr (phy, port, 0x74, dat);
}

// PHY TX reset
void prt_phy_lsc_txrst (prt_phy_lsc_ds_struct *phy)
{
    // Assert PHY TX reset
    prt_phy_lsc_pio_dat_set (phy, PRT_PHY_LSC_PIO_OUT_TX_RST);

	// Sleep alarm 0
	prt_tmr_sleep (phy->tmr, 0, PRT_PHY_LSC_RST_PULSE);
     
     // Release PHY TX reset
	prt_phy_lsc_pio_dat_clr (phy, PRT_PHY_LSC_PIO_OUT_TX_RST);
}

// PHY RX reset
void prt_phy_lsc_rxrst (prt_phy_lsc_ds_struct *phy)
{
	// Variables
	prt_u32 dat;
	prt_bool exit_loop;

    // Assert PHY RX reset
    prt_phy_lsc_pio_dat_set (phy, PRT_PHY_LSC_PIO_OUT_RX_RST);

	// Wait for PLL lock
    // Set alarm 0
    prt_tmr_set_alrm (phy->tmr, 0, PRT_PHY_LSC_LOCK_TIMEOUT);

    exit_loop = PRT_FALSE;
    do
    {
    	// Get PHY ready
  		dat = prt_phy_lsc_pio_dat_get (phy);

		if (dat & PRT_PHY_LSC_PIO_IN_PHY_RDY)
		{
			exit_loop = PRT_TRUE;
		}

		else if (prt_tmr_is_alrm (phy->tmr, 0))
		{
			prt_printf ("PHY: RX RST timeout\n");
			exit_loop = PRT_TRUE;
		}
    } while (exit_loop == PRT_FALSE);
    
    // Release PHY RX reset
	prt_phy_lsc_pio_dat_clr (phy, PRT_PHY_LSC_PIO_OUT_RX_RST);
}

// PRBS generator
void prt_phy_lsc_prbs_gen (prt_phy_lsc_ds_struct *phy, prt_u8 en)
{
	// Variables
	prt_u8 dat;

	// Read register 
	dat = prt_phy_lsc_rd (phy, 0, 0x64);

	// Enable
	if (en)
	{
		dat |= PRT_PHY_LSC_REG64_PRBS_GEN;		// Enable generator
		dat |= PRT_PHY_LSC_REG64_PRBS_CHK;		// Enable checker
	//	dat |= PRT_PHY_LSC_REG64_LPBK_EN;		// Enable local loopback
	}

	// Disable
	else 
	{
		dat &= ~(PRT_PHY_LSC_REG64_PRBS_GEN);
		dat &= ~(PRT_PHY_LSC_REG64_PRBS_CHK);
	}

	// Update register
	for (prt_u8 i = 0; i < 4; i++)
		prt_phy_lsc_wr (phy, i, 0x64, dat);
}

// PRBS clear
void prt_phy_lsc_prbs_clr (prt_phy_lsc_ds_struct *phy)
{
	// Variables
	prt_u8 dat;

	// Read register 
	dat = prt_phy_lsc_rd (phy, 0, 0x64);

	// Disable checker
	dat &= ~(PRT_PHY_LSC_REG64_PRBS_CHK);	

	// Update register
	for (prt_u8 i = 0; i < 4; i++)
		prt_phy_lsc_wr (phy, i, 0x64, dat);

	// Enable checker
	dat |= PRT_PHY_LSC_REG64_PRBS_CHK;	

	// Update register
	for (prt_u8 i = 0; i < 4; i++)
		prt_phy_lsc_wr (phy, i, 0x64, dat);
}

// PRBS lock
prt_bool prt_phy_lsc_prbs_lock (prt_phy_lsc_ds_struct *phy, prt_u8 lane)
{
	// Variables
	prt_u8 dat;

	// Read register 
	dat = prt_phy_lsc_rd (phy, lane, 0x65);

	// If the counter value is 255, then the CDR PLL is not locked
	if (dat == 255)
		return PRT_FALSE;
	else
		return PRT_TRUE;
}

// PRBS counter
prt_u8 prt_phy_lsc_prbs_cnt (prt_phy_lsc_ds_struct *phy, prt_u8 lane)
{
	// Variables
	prt_u8 dat;

	// Read register 
	dat = prt_phy_lsc_rd (phy, lane, 0x65);

	return dat;	
}

// Disable bonded mode
void prt_phy_lsc_unbond (prt_phy_lsc_ds_struct *phy)
{
	// Variables
	prt_u8 dat;

	// Read register 
	dat = prt_phy_lsc_rd (phy, 0, 0x120);

	// Exclude channel from bonded channel group
	dat |= PRT_PHY_LSC_REG120_RX_BOND_MASK;

	for (prt_u8 i = 0; i < 4; i++)
	{
		// Update settings
		prt_phy_lsc_wr (phy, i, 0x120, dat);
	}
}

//  PIO Data set
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