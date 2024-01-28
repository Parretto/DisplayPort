/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: PHY AMD Artix 7 GTP Driver
    (c) 2021 - 2023 by Parretto B.V.

    History
    =======
    v1.0 - Initial release

    License
    =======
    This License will apply to the use of the IP-core (as defined in the License). 
    Please read the License carefully so that you know what your rights and obligations are when using the IP-core.
    The acceptance of this License constitutes a valid and binding agreement between Parretto and you for the use of the IP-core. 
    If you download and/or make any use of the IP-core you agree to be bound by this License. 
    The License is available for download and print at www.parretto.com/license.html
    Parretto grants you, as the Licensee, a free, non-exclusive, non-transferable, limited right to use the IP-core 
    solely for internal business purposes for the term and conditions of the License. 
    You are also allowed to create Modifications for internal business purposes, but explicitly only under the conditions of art. 3.2.
    You are, however, obliged to pay the License Fees to Parretto for the use of the IP-core, or any Modification, in, or embodied in, 
    a physical or non-tangible product or service that has substantial commercial, industrial or non-consumer uses. 
*/

// Includes
#include "prt_types.h"
#include "prt_pio.h"
#include "prt_tmr.h"
#include "prt_phy_amd_a7_gtp.h"
#include "prt_printf.h"

// Initialize
void prt_phy_amd_init (prt_phy_amd_ds_struct *phy, prt_pio_ds_struct *pio, prt_tmr_ds_struct *tmr, prt_u32 base,
    prt_u32 pio_gttx_rst, prt_u32 pio_gtrx_rst, prt_u32 pio_gttx_rst_done, prt_u32 pio_gtrx_rst_done,
    prt_u32 pio_gtpll0_lock, prt_u32 pio_gtpll1_lock, 
    prt_u32 pio_txpll_rst, prt_u32 pio_txpll_lock, 
    prt_u32 pio_rxpll_rst, prt_u32 pio_rxpll_lock,  
    prt_u32 pio_tx_volt_shift, prt_u32 pio_tx_pre_shift, 
    prt_u32 pio_tx_rate_shift, prt_u32 pio_rx_rate_shift
    )
{
	// Base address
	phy->drp = (prt_phy_amd_drp_struct *) base;

	// PIO
	phy->pio = pio;

	// Timer
	phy->tmr = tmr;

    // PIO bits
    phy->pio_gttx_rst = pio_gttx_rst; 
    phy->pio_gtrx_rst = pio_gtrx_rst;
    phy->pio_gttx_rst_done = pio_gttx_rst_done; 
    phy->pio_gtrx_rst_done = pio_gtrx_rst_done;
    phy->pio_gtpll0_lock = pio_gtpll0_lock; 
    phy->pio_gtpll1_lock = pio_gtpll1_lock; 
    phy->pio_txpll_rst = pio_txpll_rst; 
    phy->pio_txpll_lock = pio_txpll_lock; 
    phy->pio_rxpll_rst = pio_rxpll_rst; 
    phy->pio_rxpll_lock = pio_rxpll_lock; 
    phy->pio_tx_volt_shift = pio_tx_volt_shift;
    phy->pio_tx_pre_shift = pio_tx_pre_shift;
    phy->pio_tx_rate_shift = pio_tx_rate_shift;
    phy->pio_rx_rate_shift = pio_rx_rate_shift;
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
	phy->drp->itf = cmd;

	// Read
	phy->drp->ctl = PRT_PHY_AMD_DRP_CTL_RD;
	
     // Set alarm 1 (100 us)
     prt_tmr_set_alrm (phy->tmr, 1, 100);

     exit_loop = PRT_FALSE;
     do
     {
          if (phy->drp->sta & PRT_PHY_AMD_DRP_STA_RDY)
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
	phy->drp->sta = PRT_PHY_AMD_DRP_STA_RDY;

	// Return data
	return phy->drp->itf;
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
	phy->drp->itf = cmd;

	// Write
	phy->drp->ctl = PRT_PHY_AMD_DRP_CTL_WR;

     // Set alarm 1 (100 us)
     prt_tmr_set_alrm (phy->tmr, 1, 100);

     exit_loop = PRT_FALSE;
     do
     {
          if (phy->drp->sta & PRT_PHY_AMD_DRP_STA_RDY)
          {
               exit_loop = PRT_TRUE;
          }

          else if (prt_tmr_is_alrm (phy->tmr, 1))
          {
               prt_printf ("PHY: DRP write timeout\n");
          }
     } while (exit_loop == PRT_FALSE);
	
	// Clear ready bit
	phy->drp->sta = PRT_PHY_AMD_DRP_STA_RDY;
}

// PHY TX reset
prt_sta_type prt_phy_amd_txrst (prt_phy_amd_ds_struct *phy)
{
	return prt_phy_amd_rst (phy, phy->pio_gttx_rst, phy->pio_gttx_rst_done);
}

// PHY RX reset
prt_sta_type prt_phy_amd_rxrst (prt_phy_amd_ds_struct *phy)
{
	return prt_phy_amd_rst (phy, phy->pio_gtrx_rst, phy->pio_gtrx_rst_done);
}

// PHY reset 
prt_sta_type prt_phy_amd_rst (prt_phy_amd_ds_struct *phy, 
	prt_u32 RST, prt_u32 RST_DONE)
{
	// Variables
	prt_u32 dat;
    prt_bool exit_loop;

    // Assert reset
    prt_pio_dat_set (phy->pio, RST);

	// Sleep alarm 0
	prt_tmr_sleep (phy->tmr, 0, PRT_PHY_AMD_RST_PULSE);

    // De-assert reset
    prt_pio_dat_clr (phy->pio, RST);

    // Set alarm 0
    prt_tmr_set_alrm (phy->tmr, 0, PRT_PHY_AMD_RST_TIMEOUT);
    
    exit_loop = PRT_FALSE;
    do
    {
        // Read PIO
        dat = prt_pio_dat_get (phy->pio);

        if (dat & RST_DONE)
        {
            exit_loop = PRT_TRUE;
        }

        else if (prt_tmr_is_alrm (phy->tmr, 0))
        {
            prt_printf ("PHY: reset timeout\n");
            return PRT_STA_FAIL;
        }
    } while (exit_loop == PRT_FALSE);

    return PRT_STA_OK;
}

// Set TX rate
// The TX uses the PLL0.
// The PLL in the GTP transceiver has an operating range between 1.6 to 3.3 GHz.
prt_sta_type prt_phy_amd_tx_rate (prt_phy_amd_ds_struct *phy, prt_u8 rate)
{
   	// Variables
	prt_u8 pll_fbdiv;
	prt_u8 pll_fbdiv_45;
	prt_u8 pll_refclk_div;
	prt_u8 txout_div;
	prt_u16 drp_dat;
     prt_u32 pio_msk;
     prt_u32 pio_dat;
	prt_sta_type sta;

	switch (rate)
	{
		// 2.7 Gbps
		// Reference clock is 135 MHz.
		// VCO frequency = 135 * (4 * 5 / 1) = 2.7 GHz
		// Linerate = 2.7 * 2 / 2 = 2.7 Gbps
		case PRT_PHY_AMD_LINERATE_2700 :
			pll_fbdiv = prt_phy_amd_encode_pll_fbdiv (4); 
			pll_fbdiv_45 = prt_phy_amd_encode_pll_fbdiv_45 (5);
			pll_refclk_div = prt_phy_amd_encode_pll_refclk_div (1);
			txout_div = 0x2;
			break;

		// 5.4 Gbps
		// Reference clock is 135 MHz.
		// VCO frequency = 135 * (4 * 5 / 1) = 2.7 GHz
		// Linerate = 2.7 * 2 / 1 = 5.4 Gbps
		case PRT_PHY_AMD_LINERATE_5400 :
			pll_fbdiv = prt_phy_amd_encode_pll_fbdiv (4);
			pll_fbdiv_45 = prt_phy_amd_encode_pll_fbdiv_45 (5);
			pll_refclk_div = prt_phy_amd_encode_pll_refclk_div (1);
			txout_div = 0x1;
			break;

		// 1.62 Gbps
		// Reference clock is 135 MHz.
		// VCO frequency = 135 * (3 * 4 / 1) = 1.62 GHz
		// Linerate = 1.62 * 2 / 2 = 1.62 Gbps
		default :
			pll_fbdiv = prt_phy_amd_encode_pll_fbdiv (3);
			pll_fbdiv_45 = prt_phy_amd_encode_pll_fbdiv_45 (4);
			pll_refclk_div = prt_phy_amd_encode_pll_refclk_div (1);
			txout_div = 0x2;
			break;
	}

	// PLL0_REFCLK_DIV, PLL0_FBDIV & PLL0_FBDIV_45
     drp_dat = prt_phy_amd_drp_rd (phy, PRT_PHY_DRP_PORT_GTP_COMMON, 0x4);

     drp_dat &= 0xc140;	// Mask out PLL0_REFCLK_DIV, PLL0_FBDIV & PLL0_FBDIV_45 bits
     drp_dat |= pll_fbdiv;
     drp_dat |= (pll_fbdiv_45 << 7);
     drp_dat |= (pll_refclk_div << 9);

     prt_phy_amd_drp_wr (phy, PRT_PHY_DRP_PORT_GTP_COMMON, 0x4, drp_dat);

     // The TXOUT_DIV register can be accessed through the DRP interface. 
     // In the GTP wrapper there is a RX state machine, which has access to the GTP DRP channel. 
     // All DRP communication goes through this state machine. 
     // The DPTX and DPRX can work independently and the DPRX might not be running. 
     // In this case the RX state machine keeps the GTRX in reset and blocks all DRP communcation to the GT channel.  
     // Therefore we use the TXRATE port to the GT to dynamically control the TXOUT_DIV.
     // The TXRATE is controlled by the PIO.
     // For more info see Serial Clock Divider on page 109 of UG482

     pio_msk = (0x7 << phy->pio_tx_rate_shift);
     pio_dat = txout_div << phy->pio_tx_rate_shift;
     prt_pio_dat_msk (phy->pio, pio_dat, pio_msk);

     // Configure TXPLL
     prt_phy_amd_pll_cfg (phy, rate, PRT_PHY_DRP_PORT_TXPLL, phy->pio_txpll_rst);

     // Reset PHY
     prt_phy_amd_txrst (phy);
}

// Set RX rate
// The RX uses the PLL1.
// The PLL in the GTP transceiver has an operating range between 1.6 to 3.3 GHz.
prt_sta_type prt_phy_amd_rx_rate (prt_phy_amd_ds_struct *phy, prt_u8 rate)
{
   	// Variables
	prt_u8 pll_fbdiv;
	prt_u8 pll_fbdiv_45;
	prt_u8 pll_refclk_div;
	prt_u8 txout_div;
	prt_u16 drp_dat;
     prt_u32 pio_msk;
     prt_u32 pio_dat;
	prt_sta_type sta;

	switch (rate)
	{
		// 2.7 Gbps
		// Reference clock is 135 MHz.
		// VCO frequency = 135 * (4 * 5 / 1) = 2.7 GHz
		// Linerate = 2.7 * 2 / 2 = 2.7 Gbps
		case PRT_PHY_AMD_LINERATE_2700 :
			pll_fbdiv = prt_phy_amd_encode_pll_fbdiv (4); 
			pll_fbdiv_45 = prt_phy_amd_encode_pll_fbdiv_45 (5);
			pll_refclk_div = prt_phy_amd_encode_pll_refclk_div (1);
			txout_div = 0x2;
			break;

		// 5.4 Gbps
		// Reference clock is 135 MHz.
		// VCO frequency = 135 * (4 * 5 / 1) = 2.7 GHz
		// Linerate = 2.7 * 2 / 1 = 5.4 Gbps
		case PRT_PHY_AMD_LINERATE_5400 :
			pll_fbdiv = prt_phy_amd_encode_pll_fbdiv (4);
			pll_fbdiv_45 = prt_phy_amd_encode_pll_fbdiv_45 (5);
			pll_refclk_div = prt_phy_amd_encode_pll_refclk_div (1);
			txout_div = 0x1;
			break;

		// 1.62 Gbps
		// Reference clock is 135 MHz.
		// VCO frequency = 135 * (3 * 4 / 1) = 1.62 GHz
		// Linerate = 1.62 * 2 / 2 = 1.62 Gbps
		default :
			pll_fbdiv = prt_phy_amd_encode_pll_fbdiv (3);
			pll_fbdiv_45 = prt_phy_amd_encode_pll_fbdiv_45 (4);
			pll_refclk_div = prt_phy_amd_encode_pll_refclk_div (1);
			txout_div = 0x2;
			break;
	}

	// PLL0_REFCLK_DIV, PLL0_FBDIV & PLL0_FBDIV_45
     drp_dat = prt_phy_amd_drp_rd (phy, PRT_PHY_DRP_PORT_GTP_COMMON, 0x2b);

     drp_dat &= 0xc140;	// Mask out PLL0_REFCLK_DIV, PLL0_FBDIV & PLL0_FBDIV_45 bits
     drp_dat |= pll_fbdiv;
     drp_dat |= (pll_fbdiv_45 << 7);
     drp_dat |= (pll_refclk_div << 9);

     prt_phy_amd_drp_wr (phy, PRT_PHY_DRP_PORT_GTP_COMMON, 0x2b, drp_dat);

     // The RXOUT_DIV register can be accessed through the DRP interface. 
     // In the GTP wrapper there is a RX state machine, which has access to the GTP DRP channel. 
     // All DRP communication goes through this state machine. 
     // The DPTX and DPRX can work independently and the DPRX might not be running. 
     // In this case the RX state machine keeps the GTRX in reset and blocks all DRP communcation to the GT channel.  
     // Therefore we use the RXRATE port to the GT to dynamically control the RXOUT_DIV.
     // The RXRATE is controlled by the PIO.
     // For more info see Serial Clock Divider on page 109 of UG482

     pio_msk = (0x7 << phy->pio_rx_rate_shift);
     pio_dat = txout_div << phy->pio_rx_rate_shift;
     prt_pio_dat_msk (phy->pio, pio_dat, pio_msk);

     // Configure RXPLL
     prt_phy_amd_pll_cfg (phy, rate, PRT_PHY_DRP_PORT_RXPLL, phy->pio_rxpll_rst);

     // Reset PHY
     prt_phy_amd_rxrst (phy);
}

// Encode PLL FBDIV
// This function returns the DRP encoded FBDIV value
prt_u8 prt_phy_amd_encode_pll_fbdiv (prt_u8 fbdiv)
{
     // Variables
	prt_u8 drp;

	switch (fbdiv)
	{
		case 1 :
			drp = 16;
			break;

		case 2 :
			drp = 0;
			break;

		case 3 :
			drp = 1;
			break;

		case 4 :
			drp = 2;
			break;

		case 5 :
			drp = 3;
			break;

		default :
			drp = 0;
			break;
	}

	return drp;
}

// Encode PLL_FBDIV_45
// This function returns the DRP encoded FBDIV_45 value
prt_u8 prt_phy_amd_encode_pll_fbdiv_45 (prt_u8 fbdiv_45)
{
     // Variables
	prt_u8 drp;

	if (fbdiv_45 == 5)
		drp = 1;
	else
		drp = 0;

	return drp;
}

// Encode PLL_REFCLK_DIV
// This function returns the DRP encoded PLL_REFCLK_DIV value
prt_u8 prt_phy_amd_encode_pll_refclk_div (prt_u8 refclk_div)
{
	// Variables
     prt_u8 drp;

	if (refclk_div == 1)
		drp = 16;
	else
		drp = 0;

	return drp;
}

// Encode TXOUT_DIV
// This function returns the DRP encoded TXOUT_DIV value
prt_u8 prt_phy_amd_encode_txout_div (prt_u8 txout_div)
{
	// Variables
     prt_u8 drp;

	switch (txout_div)
	{
		case 2 :
			drp = 1;
			break;

		case 4 :
			drp = 2;
			break;

		case 8 :
			drp = 3;
			break;

		default :
			drp = 0;
			break;
	}

	return drp;
}

// Set PHY TX voltage and pre-emphasis
void prt_phy_amd_tx_vap (prt_phy_amd_ds_struct *phy, prt_u8 volt, prt_u8 pre)
{
     // Variables
     prt_u32 msk;
     prt_u32 dat;

     switch (volt)
     {
          case 1  : dat = 0x6; break;  // 600 mV
          case 2  : dat = 0x9; break;  // 800 mV
          case 3  : dat = 0xf; break;  // 1200 mV
          default : dat = 0x3; break;  // 400 mV
     }

     msk = (0xf << phy->pio_tx_volt_shift);
     dat <<= phy->pio_tx_volt_shift;
     prt_pio_dat_msk (phy->pio, dat, msk);

     switch (pre)
     {
          case 1  : dat = 0x0d; break;  // 3.5 dB
          case 2  : dat = 0x14; break;  // 6.0 dB
          case 3  : dat = 0x1b; break;  // 9.5 dB
          default : dat = 0; break;     // 0 dB
     }

     msk = (0x1f << phy->pio_tx_pre_shift);
     dat <<= phy->pio_tx_pre_shift;
     prt_pio_dat_msk (phy->pio, dat, msk);
}

// PLL config
// This function configures the TXPLL or RXPLL
// The TXPLL and RXPLL generates the USRCLK and USRCLK2 
void prt_phy_amd_pll_cfg (prt_phy_amd_ds_struct *phy, prt_u8 rate, prt_u8 drp_port, prt_u32 RST)
{
     // Variables
     prt_u16 drp_adr_array[]       = {0x28,   0x8,    0x9,    0xa,    0xb,    0x14,   0x15,   0x16,   0x18,   0x19,   0x1a,   0x4e,   0x4f,   0x28};
     prt_u16 drp_msk_array[]       = {0x0,    0x1000, 0xfc00, 0x1000, 0xfc00, 0x1000, 0xfc00, 0xc000, 0xfc00, 0x8000, 0x8000, 0x66ff, 0x66ff, 0x0};
     prt_u16 drp_dat_5400_array[]  = {0xffff, 0x1042, 0x80,   0x10c3, 0x0,    0x1042, 0x80,   0x1041, 0x3e8,  0x2001, 0xa3e9, 0x1108, 0x9900, 0x0};
     prt_u16 drp_dat_2700_array[]  = {0xffff, 0x10c3, 0x0,    0x1186, 0x0,    0x10c3, 0x0,    0x1041, 0x3e8,  0x4401, 0xc7e9, 0x9108, 0x1900, 0x0};
     prt_u16 drp_dat_1620_array[]  = {0xffff, 0x1145, 0x0,    0x128a, 0x0,    0x1145, 0x0,    0x1041, 0x3e8,  0x7001, 0xf3e9, 0x9908, 0x1900, 0x0};
     prt_u16 *drp_adr;
     prt_u16 *drp_msk;
     prt_u16 *drp_dat;
     prt_u16 dat;

     // Assert reset
     prt_pio_dat_set (phy->pio, RST);

     switch (rate)
     {        
          case PRT_PHY_AMD_LINERATE_5400 :
               drp_adr = &drp_adr_array[0];
               drp_msk = &drp_msk_array[0];
               drp_dat = &drp_dat_5400_array[0];
               break;

          case PRT_PHY_AMD_LINERATE_2700 :
               drp_adr = &drp_adr_array[0];
               drp_msk = &drp_msk_array[0];
               drp_dat = &drp_dat_2700_array[0];
               break;

          default : 
               drp_adr = &drp_adr_array[0];
               drp_msk = &drp_msk_array[0];
               drp_dat = &drp_dat_1620_array[0];
               break;
     }

     for (prt_u16 i = 0; i < 14; i++)
     {
          // Read
          dat = prt_phy_amd_drp_rd (phy, drp_port, *(drp_adr + i));         
          
          // Mask out 
          dat &= *(drp_msk + i);

          // Set bits
          dat |= *(drp_dat+i);

          // Write
          prt_phy_amd_drp_wr (phy, drp_port, *(drp_adr + i), dat);
     }

     // De-assert reset
     prt_pio_dat_clr (phy->pio, RST);
}
