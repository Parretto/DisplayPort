/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: PHY AMD UltraScale GTH Driver
    (c) 2021 - 2024 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Removed DP application and DP driver header dependency
	v1.2 - Change QPLL dynamic update 
	v1.3 - Added PIO

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
#include "prt_phy_amd_us_gth.h"
#include "prt_printf.h"

// PHY TX PLL configuration data
prt_u32 qpll_cfg_drp_array[4][4] = {

  	// Configuration 1.62 Gbps
  	{
		0x00110fc3, /* DRP address=0x11, data=0xfc3e */
		0x0014005e, /* DRP address=0x14, data=0x5e */
		0x00180020, /* DRP address=0x18, data=0x020 */
		0x0019021f  /* DRP address=0x19, data=0x21f */
	},

  	// Configuration 2.7 Gbps
  	{
		0x00110fc3, /* DRP address=0x11, data=0xfc3 */
		0x0014004e, /* DRP address=0x14, data=0x4e */
		0x00180020, /* DRP address=0x18, data=0x020 */
		0x0019021f  /* DRP address=0x19, data=0x21f */
	},

  	// Configuration 5.4 Gbps
  	{
		0x00110fc3, /* DRP address=0x11, data=0xfc3 */
		0x0014004e, /* DRP address=0x14, data=0x4e */
		0x00180020, /* DRP address=0x18, data=0x020 */
		0x0019021f  /* DRP address=0x19, data=0x21f */
	},

  	// Configuration 8.1 Gbps
  	{
		0x00110fc1, /* DRP address=0x11, data=0xfc1 */
		0x00140076, /* DRP address=0x14, data=0x76 */
		0x00180020, /* DRP address=0x18, data=0x020 */
		0x0019037f  /* DRP address=0x19, data=0x37f */
	}
};

// Initialize
void prt_phy_amd_init (prt_phy_amd_ds_struct *phy, prt_tmr_ds_struct *tmr, prt_u32 base)
{
	// Base address
	phy->dev = (prt_phy_amd_dev_struct *) base;

	// Timer
	phy->tmr = tmr;
}

// DRP read
prt_u16 prt_phy_amd_drp_rd (prt_phy_amd_ds_struct *phy, prt_u8 port, prt_u16 adr)
{
	// Variables
	prt_u32 cmd;
	prt_bool exit_loop;

	// Port
	cmd = port;
	
	// Address
	cmd |= (adr << PRT_PHY_AMD_DRP_ADR_SHIFT);

	// Write command to drp 
	phy->dev->drp = cmd;

	// Read
	phy->dev->ctl = PRT_PHY_AMD_DEV_CTL_RD;
	
     // Set alarm 1 (100 us)
     prt_tmr_set_alrm (phy->tmr, 1, 100);

     exit_loop = PRT_FALSE;
     do
     {
          if (phy->dev->sta & PRT_PHY_AMD_DEV_STA_RDY)
          {
               exit_loop = PRT_TRUE;
          }

          else if (prt_tmr_is_alrm (phy->tmr, 1))
          {
               prt_printf ("PHY: DRP read timeout\n");
               exit_loop = PRT_TRUE;
          }
     } while (exit_loop == PRT_FALSE);

	// Clear ready bit
	phy->dev->sta = PRT_PHY_AMD_DEV_STA_RDY;

	// Return data
	return phy->dev->drp;
}

// DRP write
void prt_phy_amd_drp_wr (prt_phy_amd_ds_struct *phy, prt_u8 port, prt_u16 adr, prt_u16 dat)
{
	// Variables
	prt_u32 cmd;
	prt_bool exit_loop;
	
	// Port
	cmd = port;
	
	// Address
	cmd |= (adr << PRT_PHY_AMD_DRP_ADR_SHIFT);

	// Data
	cmd |= (dat << PRT_PHY_AMD_DRP_DAT_SHIFT);

	// Write command 
	phy->dev->drp = cmd;

	// Write
	phy->dev->ctl = PRT_PHY_AMD_DEV_CTL_WR;

     // Set alarm 1 (100 us)
     prt_tmr_set_alrm (phy->tmr, 1, 100);

     exit_loop = PRT_FALSE;
     do
     {
          if (phy->dev->sta & PRT_PHY_AMD_DEV_STA_RDY)
          {
               exit_loop = PRT_TRUE;
          }

          else if (prt_tmr_is_alrm (phy->tmr, 1))
          {
			prt_printf ("PHY: DRP write timeout\n");
			exit_loop = PRT_TRUE;
          }
     } while (exit_loop == PRT_FALSE);
	
	// Clear ready bit
	phy->dev->sta = PRT_PHY_AMD_DEV_STA_RDY;
}

// Set TX rate
// The TX uses the CPLL.
// The CPLL in the GTH transceiver has an operating range between 2.0 to 6.26 GHz.
prt_sta_type prt_phy_amd_tx_rate (prt_phy_amd_ds_struct *phy, prt_u8 rate)
{
	// Variables
	prt_u8 cpll_fbdiv;
	prt_u8 cpll_fbdiv_45;
	prt_u8 cpll_refclk_div;
	prt_u8 txout_div;
	prt_u16 dat;
	prt_sta_type sta;

	// Assert PHY TX reset
	sta = prt_phy_amd_txrst_set (phy);

	if (sta != PRT_STA_OK)
		return PRT_STA_FAIL;

	switch (rate)
	{
		// 2.7 Gbps
		// Reference clock is 270 MHz.
		// VCO frequency = 270 * (4 * 5 / 2) = 2.7 GHz
		// Linerate = 2.7 * 2 / 2 = 2.7 Gbps
		case PRT_PHY_AMD_LINERATE_2700 :
			cpll_fbdiv = prt_phy_amd_encode_cpll_fbdiv (4); 
			cpll_fbdiv_45 = prt_phy_amd_encode_cpll_fbdiv_45 (5);
			cpll_refclk_div = prt_phy_amd_encode_cpll_refclk_div (2);
			txout_div = prt_phy_amd_encode_txout_div (2);
			break;

		// 5.4 Gbps
		// Reference clock is 270 MHz.
		// VCO frequency = 270 * (4 * 5 / 2) = 2.7 GHz
		// Linerate = 2.7 * 2 / 1 = 5.4 Gbps
		case PRT_PHY_AMD_LINERATE_5400 :
			cpll_fbdiv = prt_phy_amd_encode_cpll_fbdiv (4);
			cpll_fbdiv_45 = prt_phy_amd_encode_cpll_fbdiv_45 (5);
			cpll_refclk_div = prt_phy_amd_encode_cpll_refclk_div (2);
			txout_div = prt_phy_amd_encode_txout_div (1);
			break;

		// 8.1 Gbps
		// Reference clock is 270 MHz.
		// VCO frequency = 270 * (3 * 5 / 1) = 4.05 GHz
		// Linerate = 4.05 * 2 / 1 = 8.1 Gbps
		case PRT_PHY_AMD_LINERATE_8100 :
			cpll_fbdiv = prt_phy_amd_encode_cpll_fbdiv (3);
			cpll_fbdiv_45 = prt_phy_amd_encode_cpll_fbdiv_45 (5);
			cpll_refclk_div = prt_phy_amd_encode_cpll_refclk_div (1);
			txout_div = prt_phy_amd_encode_txout_div (1);
			break;

		// 1.62 Gbps
		// Reference clock is 270 MHz.
		// VCO frequency = 270 * (3 * 4 / 1) = 3.240 GHz
		// Linerate = 3.240 * 2 / 4 = 1.62 Gbps
		default :
			cpll_fbdiv = prt_phy_amd_encode_cpll_fbdiv (3);
			cpll_fbdiv_45 = prt_phy_amd_encode_cpll_fbdiv_45 (4);
			cpll_refclk_div = prt_phy_amd_encode_cpll_refclk_div (1);
			txout_div = prt_phy_amd_encode_txout_div (4);
			break;
	}

	// FBDIV / FBDIV_45
	for (prt_u8 i = 0; i < 4; i++)
	{
		dat = prt_phy_amd_drp_rd (phy, i, 0x28);
		dat &= 0x007f;	// Mask out FBDIV and FBDIV_45 bits
		dat |= (cpll_fbdiv << 8);
		dat |= (cpll_fbdiv_45 << 7);
		prt_phy_amd_drp_wr (phy, i, 0x28, dat);
	}

	// CPLL_REFCLK_DIV
	for (prt_u8 i = 0; i < 4; i++)
	{
		dat = prt_phy_amd_drp_rd (phy, i, 0x2a);
		dat &= 0x07ff;	// Mask out CPLL_REFCLK_DIV bits
		dat |= (cpll_refclk_div << 11);
		prt_phy_amd_drp_wr (phy, i, 0x2a, dat);
	}

	// TXOUT_DIV
	for (prt_u8 i = 0; i < 4; i++)
	{
		dat = prt_phy_amd_drp_rd (phy, i, 0x7c);
		dat &= 0xf8ff;	// Mask out TXOUT_DIV bits
		dat |= (txout_div << 8);
		prt_phy_amd_drp_wr (phy, i, 0x7c, dat);
	}

	// Set CPLL calibration
	prt_phy_amd_cpll_cal (phy, rate);

	// Release reset
	sta = prt_phy_amd_txrst_clr (phy);

	return sta;              
}

// Encode CPLL FBDIV
// This function returns the encoded FBDIV value
prt_u8 prt_phy_amd_encode_cpll_fbdiv (prt_u8 fbdiv)
{
	prt_u8 phy;

	switch (fbdiv)
	{
		case 1 :
			phy = 16;
			break;

		case 2 :
			phy = 0;
			break;

		case 3 :
			phy = 1;
			break;

		case 4 :
			phy = 2;
			break;

		case 5 :
			phy = 3;
			break;

		default :
			phy = 0;
			break;
	}

	return phy;
}

// Encode CPLL FBDIV_45
// This function returns the encoded FBDIV_45 value
prt_u8 prt_phy_amd_encode_cpll_fbdiv_45 (prt_u8 fbdiv_45)
{
	prt_u8 phy;

	if (fbdiv_45 == 5)
		phy = 1;
	else
		phy = 0;

	return phy;
}

// Encode CPLL_REFCLK_DIV
// This function returns the encoded CPLL_REFCLK_DIV value
prt_u8 prt_phy_amd_encode_cpll_refclk_div (prt_u8 cpll_refclk_div)
{
	prt_u8 phy;

	if (cpll_refclk_div == 1)
		phy = 16;
	else
		phy = 0;

	return phy;
}

// Encode TXOUT_DIV
// This function returns the encoded TXOUT_DIV value
prt_u8 prt_phy_amd_encode_txout_div (prt_u8 txout_div)
{
	prt_u8 phy;

	switch (txout_div)
	{
		case 2 :
			phy = 1;
			break;

		case 4 :
			phy = 2;
			break;

		case 8 :
			phy = 3;
			break;

		default :
			phy = 0;
			break;
	}

	return phy;
}

// Set RX rate
// The RX uses the QPLL.
// The GTH transceiver has two QPLLs
// QPLL0 has an operating band from 9.8 - 16.375 GHz
// QPLL1 has an operating band from 8.0 - 13.0 GHz
// When switching line rates, besides changing the QPLL FBDIV and QPLL REFCLK DIV parameters,
// also the transceivers wizard sets other QPLL configuration registers.
// So for the QPLL,  instead of looking up the divider values, we just write the QPLL DRP registers that are updated by the wizard.
prt_sta_type prt_phy_amd_rx_rate (prt_phy_amd_ds_struct *phy, prt_u8 rate)
{
	// Variables
	prt_u8 rxout_div;
	prt_u8 cfg_idx;
	prt_u32 cfg_val;
	prt_u16 drp_adr;
	prt_u16 drp_dat;
	prt_sta_type sta;

	// Assert PHY RX reset
	sta = prt_phy_amd_rxrst_set (phy);

	if (sta != PRT_STA_OK)
		return PRT_STA_FAIL;

	switch (rate)
	{
		// 2.7 Gbps
		// Reference clock is 135 MHz.
		// VCO frequency = 135 MHz * 80 * 1 = 10.8 GHz
		// PLL clock out = VCO / 2 = 5.4 GHz
		// Linerate = PLL out * 2 / 4 = 2.7 Gbps
		case PRT_PHY_AMD_LINERATE_2700 :
			/*
			qpll_fbdiv = prt_phy_amd_encode_qpll_fbdiv (80); 
			qpll_refclk_div = prt_phy_amd_encode_qpll_refclk_div (1);
			*/

			cfg_idx = 1;
			rxout_div = prt_phy_amd_encode_rxout_div (4);
			break;

		// 5.4 Gbps
		// Reference clock is 135 MHz.
		// VCO frequency = 135 MHz * 80 * 1 = 10.8 GHz
		// PLL clock out = VCO / 2 = 5.4 GHz
		// Linerate = PLL out * 2 / 2 = 5.4 Gbps
		case PRT_PHY_AMD_LINERATE_5400 :
			/*
			qpll_fbdiv = prt_phy_amd_encode_qpll_fbdiv (80); 
			qpll_refclk_div = prt_phy_amd_encode_qpll_refclk_div (1);
			*/

			cfg_idx = 2;
			rxout_div = prt_phy_amd_encode_rxout_div (2);
			break;

		// 8.1 Gbps
		// Reference clock is 135 MHz.
		// VCO frequency = 135 MHz * 120 * 1 = 16.2 GHz
		// PLL clock out = VCO / 2 = 8.1 GHz
		// Linerate = PLL out * 2 / 2 = 8.1 Gbps
		case PRT_PHY_AMD_LINERATE_8100 :
			/*
			qpll_fbdiv = prt_phy_amd_encode_qpll_fbdiv (120);
			qpll_refclk_div = prt_phy_amd_encode_qpll_refclk_div (1);
			*/

			cfg_idx = 3;
			rxout_div = prt_phy_amd_encode_rxout_div (2);
			break;

		// 1.62 Gbps
		// Reference clock is 135 MHz.
		// VCO frequency = 135 MHz * 96 * 1 = 12.960 GHz
		// PLL clock out = VCO / 2 = 6.48 GHz
		// Linerate = PLL out * 2 / 8 = 1.62 Gbps
		default :
			/*
			qpll_fbdiv = prt_phy_amd_encode_qpll_fbdiv (96); 
			qpll_refclk_div = prt_phy_amd_encode_qpll_refclk_div (1);
			*/

			cfg_idx = 0;
			rxout_div = prt_phy_amd_encode_rxout_div (8);
			break;
	}

	/*
	// QPLL FBDIV
	dat = prt_phy_amd_drp_rd (phy, 4, 0x14);
	dat &= 0xff00;	// Mask out FBDIV
	dat |= qpll_fbdiv;
	prt_phy_amd_drp_wr (phy, 4, 0x14, dat);

	// QPLL REFCLK DIV
	dat = prt_phy_amd_drp_rd (phy, 4, 0x18);
	dat &= 0xf07f;	// Mask out REFCLK DIV
	dat |= (qpll_refclk_div << 7);
	prt_phy_amd_drp_wr (phy, 4, 0x18, dat);
	*/

	// Update QPLL DRP registers
	for (prt_u8 i = 0; i < 4; i++)
	{
		cfg_val = qpll_cfg_drp_array[cfg_idx][i];
		drp_adr = cfg_val >> 16;
		drp_dat = cfg_val & 0xffff;
		prt_phy_amd_drp_wr (phy, 4, drp_adr, drp_dat);
	}

	// RXOUT_DIV
	for (prt_u8 i = 0; i < 4; i++)
	{
		drp_adr = 0x63;
		drp_dat = prt_phy_amd_drp_rd (phy, i, drp_adr);
		drp_dat &= 0xfff8;	// Mask out RXOUT_DIV bits
		drp_dat |= rxout_div;
		prt_phy_amd_drp_wr (phy, i, drp_adr, drp_dat);
	}

	// Release reset
	sta = prt_phy_amd_rxrst_clr (phy);

	return sta;
}

/*
// Encode QPLL FBDIV
// This function returns the encoded FBDIV value
prt_u8 prt_phy_amd_encode_qpll_fbdiv (prt_u8 fbdiv)
{
	prt_u8 phy;

	switch (fbdiv)
	{
		case 40 :
			phy = 38;
			break;

		case 60 :
			phy = 58;
			break;

		case 48 :
			phy = 46;
			break;

		case 80 :
			phy = 78;
			break;

		case 120 :
			phy = 118;
			break;

		case 96 :
			phy = 94;
			break;

		default :
			phy = 0;
			break;
	}

	return phy;
}

// Encode QPLL_REFCLK_DIV
// This function returns the encoded QPLL_REFCLK_DIV value
prt_u8 prt_phy_amd_encode_qpll_refclk_div (prt_u8 qpll_refclk_div)
{
	prt_u8 phy;

	if (qpll_refclk_div == 1)
		phy = 16;
	else
		phy = 0;

	return phy;
}
*/

// Encode RXOUT_DIV
// This function returns the encoded RXOUT_DIV value
prt_u8 prt_phy_amd_encode_rxout_div (prt_u8 rxout_div)
{
	prt_u8 phy;

	switch (rxout_div)
	{
		case 2 :
			phy = 1;
			break;

		case 4 :
			phy = 2;
			break;

		case 8 :
			phy = 3;
			break;

		default :
			phy = 0;
			break;
	}

	return phy;
}

// PHY TX assert reset
prt_sta_type prt_phy_amd_txrst_set (prt_phy_amd_ds_struct *phy)
{
	return prt_phy_amd_rst_set (phy, 
		PRT_PHY_AMD_PIO_OUT_CPLL_RST, PRT_PHY_AMD_PIO_OUT_TX_RST, PRT_PHY_AMD_PIO_OUT_TX_DIV_RST, PRT_PHY_AMD_PIO_OUT_TX_USR_RDY);
	//phy->pio_cpll_rst, phy->pio_tx_rst, phy->pio_tx_div_rst, phy->pio_tx_usr_rdy);
}

// PHY TX release reset
prt_sta_type prt_phy_amd_txrst_clr (prt_phy_amd_ds_struct *phy)
{
	return prt_phy_amd_rst_clr (phy,
		PRT_PHY_AMD_PIO_OUT_CPLL_RST, PRT_PHY_AMD_PIO_IN_CPLL_LOCK, PRT_PHY_AMD_PIO_OUT_TX_RST, PRT_PHY_AMD_PIO_OUT_TX_DIV_RST,
		PRT_PHY_AMD_PIO_IN_TX_PMA_RST_DONE, PRT_PHY_AMD_PIO_OUT_TX_USR_RDY, PRT_PHY_AMD_PIO_IN_TX_RST_DONE);
}

// PHY RX assert reset
prt_sta_type prt_phy_amd_rxrst_set (prt_phy_amd_ds_struct *phy)
{
	return prt_phy_amd_rst_set (phy, 
		PRT_PHY_AMD_PIO_OUT_QPLL_RST, PRT_PHY_AMD_PIO_OUT_RX_RST, PRT_PHY_AMD_PIO_OUT_RX_DIV_RST, PRT_PHY_AMD_PIO_OUT_RX_USR_RDY);
}

// PHY RX release reset
prt_sta_type prt_phy_amd_rxrst_clr (prt_phy_amd_ds_struct *phy)
{
	return prt_phy_amd_rst_clr (phy,
		PRT_PHY_AMD_PIO_OUT_QPLL_RST, PRT_PHY_AMD_PIO_IN_QPLL_LOCK, PRT_PHY_AMD_PIO_OUT_RX_RST, PRT_PHY_AMD_PIO_OUT_RX_DIV_RST, 
		PRT_PHY_AMD_PIO_IN_RX_PMA_RST_DONE, PRT_PHY_AMD_PIO_OUT_RX_USR_RDY, PRT_PHY_AMD_PIO_IN_RX_RST_DONE);
}

// PHY assert reset 
prt_sta_type prt_phy_amd_rst_set (prt_phy_amd_ds_struct *phy, 
	prt_u32 PLL_RST, prt_u32 PHY_RST, prt_u32 PHY_DIV_RST, prt_u32 PHY_USR_RDY)
{
	// Variables
	prt_u32 dat;

	// Powergood
	// Read PIO
	dat = prt_phy_amd_pio_dat_get (phy);

	// Check if powergood signal is asserted
	if (dat & PRT_PHY_AMD_PIO_IN_PWRGD)
	{
		// Assert PLL reset
	    prt_phy_amd_pio_dat_set (phy, PLL_RST);

		// De-assert PHY TX reset
	    prt_phy_amd_pio_dat_clr (phy, PHY_RST);

	     // De-assert TXUSR ready
		prt_phy_amd_pio_dat_clr (phy, PHY_USR_RDY);

	     // De-assert divider reset
		prt_phy_amd_pio_dat_clr (phy, PHY_DIV_RST);

		return PRT_STA_OK;
	}

	else
	{
		prt_printf ("PHYTX: power good is not asserted\n");
		return PRT_STA_FAIL;
	}
}

// PHY release reset
prt_sta_type prt_phy_amd_rst_clr (prt_phy_amd_ds_struct *phy, 
	prt_u32 PLL_RST, prt_u32 PLL_LOCK, prt_u32 PHY_RST, prt_u32 PHY_DIV_RST, prt_u32 PMA_RST_DONE, prt_u32 PHY_USR_RDY, prt_u32 PHY_RST_DONE)
{
	// Variables
	prt_u32 dat;
    prt_bool exit_loop;

	// Release PLL reset
    prt_phy_amd_pio_dat_clr (phy, PLL_RST);
   
    // Wait for PLL lock

    // Set alarm 0
    prt_tmr_set_alrm (phy->tmr, 0, PRT_PHY_AMD_RST_TIMEOUT);
     
    exit_loop = PRT_FALSE;
    do
    {
		// Read PIO
		dat = prt_phy_amd_pio_dat_get (phy);

		if (dat & PLL_LOCK)
		{
			exit_loop = PRT_TRUE;
		}

		else if (prt_tmr_is_alrm (phy->tmr, 0))
		{
			prt_printf ("PHY: PLL lock timeout\n");
			return PRT_STA_FAIL;
		}
     } while (exit_loop == PRT_FALSE);

    // Assert PHY divider reset
    prt_phy_amd_pio_dat_set (phy, PHY_DIV_RST);

    // De-assert PHY divider reset
    prt_phy_amd_pio_dat_clr (phy, PHY_DIV_RST);

     // Assert PHY reset
	prt_phy_amd_pio_dat_set (phy, PHY_RST);

	// Sleep alarm 0
	prt_tmr_sleep (phy->tmr, 0, PRT_PHY_AMD_RST_PULSE);
     
     // Release PHY reset
	prt_phy_amd_pio_dat_clr (phy, PHY_RST);

    // Wait for PMA reset done

    // Set alarm 0
    prt_tmr_set_alrm (phy->tmr, 0, PRT_PHY_AMD_RST_TIMEOUT);
     
    exit_loop = PRT_FALSE;
    do
    {
		// Read PIO
		dat = prt_phy_amd_pio_dat_get (phy);

		if (dat & PMA_RST_DONE)
		{
			exit_loop = PRT_TRUE;
		}

		else if (prt_tmr_is_alrm (phy->tmr, 0))
		{
			prt_printf ("PHY: PMA reset done timeout\n");
			return PRT_STA_FAIL;
		}
    } while (exit_loop == PRT_FALSE);

    // Set TXUSR ready
	prt_phy_amd_pio_dat_set (phy, PHY_USR_RDY);

    // Wait for reset done

    // Set alarm 0
    prt_tmr_set_alrm (phy->tmr, 0, PRT_PHY_AMD_RST_TIMEOUT);
     
    exit_loop = PRT_FALSE;
    do
    {
		// Read PIO
		dat = prt_phy_amd_pio_dat_get (phy);

		if (dat & PHY_RST_DONE)
		{
			exit_loop = PRT_TRUE;
		}

		else if (prt_tmr_is_alrm (phy->tmr, 0))
		{
			prt_printf ("PHY: Reset done timeout\n");
			return PRT_STA_FAIL;
		}
    } while (exit_loop == PRT_FALSE);

    return PRT_STA_OK;
}

// Set the CPLL calibration parameters (through the pio)
void prt_phy_amd_cpll_cal (prt_phy_amd_ds_struct *phy, prt_u8 rate)
{
     // Variables
     prt_u32 msk;
     prt_u32 dat;

     switch (rate)
     {
          // 2.7 Gbps
          case PRT_PHY_AMD_LINERATE_2700 : dat = 1; break;

          // 5.4 Gbps
          case PRT_PHY_AMD_LINERATE_5400 : dat = 2; break;

          // 8.1 Gbps
          case PRT_PHY_AMD_LINERATE_8100 : dat = 3; break;

          // 1.62 Gbps
          default : dat = 0; break;
     }

    msk = (0x03 << PRT_PHY_AMD_PIO_OUT_TX_LINERATE_SHIFT);
    dat <<= PRT_PHY_AMD_PIO_OUT_TX_LINERATE_SHIFT;
    prt_phy_amd_pio_dat_msk (phy, dat, msk);
}

// Set PHY TX voltage and pre-emphasis
void prt_phy_amd_tx_vap (prt_phy_amd_ds_struct *phy, prt_u8 volt, prt_u8 pre)
{
     // Variables
     prt_u32 msk;
     prt_u32 dat;

     switch (volt)
     {
          case 1  : dat = 0x0e; break;  // 600 mV
          case 2  : dat = 0x16; break;  // 800 mV
          case 3  : dat = 0x1e; break;  // 1200 mV
          default : dat = 0x08; break;  // 400 mV
     }

     msk = (0x1f << PRT_PHY_AMD_PIO_OUT_TX_VOLT_SHIFT);
     dat <<= PRT_PHY_AMD_PIO_OUT_TX_VOLT_SHIFT;
     prt_phy_amd_pio_dat_msk (phy, dat, msk);

     switch (pre)
     {
          case 1  : dat = 0x0d; break;  // 3.5 dB
          case 2  : dat = 0x14; break;  // 6.0 dB
          case 3  : dat = 0x1b; break;  // 9.5 dB
          default : dat = 0; break;     // 0 dB
     }

     msk = (0x1f << PRT_PHY_AMD_PIO_OUT_TX_PRE_SHIFT);
     dat <<= PRT_PHY_AMD_PIO_OUT_TX_PRE_SHIFT;
     prt_phy_amd_pio_dat_msk (phy, dat, msk);
}

// TX PLL lock
// The TX is using the CPLL
prt_u8 prt_phy_amd_get_txpll_lock (prt_phy_amd_ds_struct *phy)
{     
	// Variables
	prt_u32 dat;

     // Read PIO
     dat = prt_phy_amd_pio_dat_get (phy);

     if (dat & PRT_PHY_AMD_PIO_IN_CPLL_LOCK)
     	return PRT_TRUE;
   	else
   		return PRT_FALSE;
}

// RX PLL lock
// The RX is using the QPLL
prt_u8 prt_phy_amd_get_rxpll_lock (prt_phy_amd_ds_struct *phy)
{     
	// Variables
	prt_u32 dat;

     // Read PIO
     dat = prt_phy_amd_pio_dat_get (phy);

     if (dat & PRT_PHY_AMD_PIO_IN_QPLL_LOCK)
     	return PRT_TRUE;
   	else
   		return PRT_FALSE;
}

/*
// PRBS generator
void prt_phy_amd_prbs_gen (prt_phy_amd_ds_struct *phy, prt_u8 en)
{
	// Enable
	if (en)
	     prt_pio_dat_set (phy->pio, PIO_OUT_PHY_PRBS_EN);

	// Disable
	else 
	     prt_pio_dat_clr (phy->pio, PIO_OUT_PHY_PRBS_EN);
}

// PRBS clear counter
void prt_phy_amd_prbs_clr (prt_phy_amd_ds_struct *phy)
{
     prt_pio_dat_set (phy->pio, PIO_OUT_PHYRX_PRBS_CLR);
     prt_pio_dat_clr (phy->pio, PIO_OUT_PHYRX_PRBS_CLR);
}

// PRBS insert error 
void prt_phy_amd_prbs_err (prt_phy_amd_ds_struct *phy)
{
     prt_pio_dat_set (phy->pio, PIO_OUT_PHYRX_PRBS_ERR);
     prt_pio_dat_clr (phy->pio, PIO_OUT_PHYRX_PRBS_ERR);
}

// PRBS lock
prt_bool prt_phy_amd_prbs_lock (prt_phy_amd_ds_struct *phy, prt_u8 lane)
{
	// Variable 
	prt_u32 dat;

     dat = prt_pio_dat_get (phy->pio);
     dat >>= PIO_IN_PHYRX_PRBS_LOCK_SHIFT;

	if ((dat >> lane) & 1)
		return PRT_TRUE;
	else
		return PRT_FALSE;
}

// PRBS read counter
prt_u32 prt_phy_amd_prbs_cnt (prt_phy_amd_ds_struct *phy, prt_u8 lane)
{
	// Variables
	prt_u32 dat;
	prt_u32 cnt;

	// Read lower 16 bits
	dat = prt_phy_amd_drp_rd (phy, lane, 0x25e);
	cnt = dat;

	// Read upper 16 bits
	dat = prt_phy_amd_drp_rd (phy, lane, 0x25f);
	dat <<= 16;

	cnt += dat;

	return cnt;
}

// Equalizer select
void prt_phy_amd_equ_sel (prt_phy_amd_ds_struct *phy, prt_u8 lpm)
{
	// LPM
	if (lpm)
	     prt_pio_dat_set (phy->pio, PIO_OUT_PHYRX_EQU_SEL);

	// DFE
	else 
	     prt_pio_dat_clr (phy->pio, PIO_OUT_PHYRX_EQU_SEL);
}
*/

//  PIO Data set
void prt_phy_amd_pio_dat_set (prt_phy_amd_ds_struct *phy, prt_u32 dat)
{
	phy->dev->pio_dout_set = dat;
}

// PIO Data clear
void prt_phy_amd_pio_dat_clr (prt_phy_amd_ds_struct *phy, prt_u32 dat)
{
	phy->dev->pio_dout_clr = dat;
}

// PIO Data mask
void prt_phy_amd_pio_dat_msk (prt_phy_amd_ds_struct *phy, prt_u32 dat, prt_u32 msk)
{
	phy->dev->pio_msk = msk;
	phy->dev->pio_dout = dat;
}

// PIO Get data
prt_u32 prt_phy_amd_pio_dat_get (prt_phy_amd_ds_struct *phy)
{
  return phy->dev->pio_din;
}
