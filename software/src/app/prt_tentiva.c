/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Tentiva Driver
    (c) 2021 - 2024 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
	v1.1 - Added set clock configuration function
	v1.2 - Added TDP142 snoop disable function
	v1.3 - Removed DP Application header dependency
	v1.4 - Added multiple clock configurations support
	v1.5 - Added DP21TX card (TDP2004)

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
#include "prt_pio.h"
#include "prt_i2c.h"
#include "prt_tmr.h"
#include "prt_rc22504a.h"
#include "prt_mcdp6150.h"
#include "prt_mcdp6000.h"
#include "prt_tdp142.h"
#include "prt_tdp2004.h"
#include "prt_dp_drv.h"
#include "prt_printf.h"
#include "prt_tentiva.h"

// Initialize
void prt_tentiva_init (prt_tentiva_ds_struct *tentiva, prt_pio_ds_struct *pio, prt_i2c_ds_struct *i2c, prt_tmr_ds_struct *tmr,
	prt_u32 pio_phy_refclk_lock, prt_u32 pio_vid_refclk_lock, prt_u32 pio_clk_sel)
{
	// Set board IDs to empty
	tentiva->fmc_id = 0;
	tentiva->slot_id[0] = 0;
	tentiva->slot_id[1] = 0;

	// Devices
	tentiva->pio = pio;
	tentiva->i2c = i2c;
	tentiva->tmr = tmr;

	// PIO bits
	tentiva->pio_phy_refclk_lock = pio_phy_refclk_lock;
	tentiva->pio_vid_refclk_lock = pio_vid_refclk_lock;
	tentiva->pio_clk_sel 		 = pio_clk_sel;

	// Clear variables
	tentiva->phy_freq = 0;
	tentiva->phy_clk_cfg = 0;
	tentiva->vid_clk_cfg = 0;
}

// Set clock configuration
// This function is used by the application to set the pointer to the clock configuation.
void prt_tentiva_set_clk_cfg (prt_tentiva_ds_struct *tentiva, prt_u8 dev, prt_u8 cfg, prt_rc22504a_reg_struct *prt, prt_u16 len) 
{
	// PHY clock driver
	if (dev == PRT_TENTIVA_PHY_DEV)
	{
		tentiva->phy_clk_cfg_prt[cfg] = prt;
		tentiva->phy_clk_cfg_len = len;
	}

	// Video clock driver
	else
	{
		tentiva->vid_clk_cfg_prt[cfg] = prt;
		tentiva->vid_clk_cfg_len = len;
	}
}

// Configuration
// This function configures all the Tentiva components.
prt_sta_type prt_tentiva_cfg (prt_tentiva_ds_struct *tentiva, prt_bool ignore_err)
{
	// Variables
	prt_sta_type sta;
	prt_u32 dat;

	/*
		Clocking
	*/

	// PHY clock
	sta = prt_tentiva_clk_cfg (tentiva, PRT_TENTIVA_PHY_DEV, tentiva->phy_clk_cfg_len, tentiva->phy_clk_cfg_prt[0], tentiva->pio_phy_refclk_lock);

	if ((sta != PRT_STA_OK) && (ignore_err == PRT_FALSE))
	{
		prt_printf ("-- PHY reference clock config error -- ");
		return sta;
	}	

	// VID clock
	sta = prt_tentiva_clk_cfg (tentiva, PRT_TENTIVA_VID_DEV, tentiva->vid_clk_cfg_len, tentiva->vid_clk_cfg_prt[0], tentiva->pio_vid_refclk_lock);

	if ((sta != PRT_STA_OK) && (ignore_err == PRT_FALSE))
	{
		prt_printf ("-- Video reference clock config error -- ");
		return sta;
	}	


	/*
		TDP142 initialize
	*/
	if (tentiva->slot_id[1] == PRT_TENTIVA_DP14TX_ID)
	{
		sta = prt_tdp142_init (tentiva->i2c, PRT_TENTIVA_I2C_TDP142_SLOT1_ADR, 1);

		if ((sta != PRT_STA_OK) && (ignore_err == PRT_FALSE))
		{
			prt_printf ("-- TDP142 config error -- ");
			return sta;
		}	
	}

	/*
		TDP2004 initialize
	*/
	else if (tentiva->slot_id[1] == PRT_TENTIVA_DP21TX_ID)
	{
		sta = prt_tdp2004_init (tentiva->i2c, PRT_TENTIVA_I2C_TDP2004_SLOT1_ADR);
	}

	/*
		MCDP6150 initialize
	*/
	if (tentiva->slot_id[0] == PRT_TENTIVA_DP14RX_ID)
	{
		sta = prt_mcdp6150_init (tentiva->i2c, PRT_TENTIVA_I2C_MCDP6150_SLOT0_ADR);

		if (sta != PRT_STA_OK)
		{
			if ((sta != PRT_STA_OK) && (ignore_err == PRT_FALSE))
			{
				prt_printf ("-- MCDP6150 config error -- ");
				return sta;
			}
		}	
	}

	/*
		MCDP6000 initialize
	*/
	else if (tentiva->slot_id[0] == PRT_TENTIVA_DP14RX_MCDP6000_ID)
	{
		sta = prt_mcdp6000_init (tentiva->i2c, PRT_TENTIVA_I2C_MCDP6000_SLOT0_ADR);

		if (sta != PRT_STA_OK)
		{
			if ((sta != PRT_STA_OK) && (ignore_err == PRT_FALSE))
			{
				prt_printf ("-- MCDP6000 config error -- ");
				return sta;
			}
		}	
	}

	// Return status
	return sta;
}

// Clock configuration
// This function configures the clock generator.
prt_sta_type prt_tentiva_clk_cfg (prt_tentiva_ds_struct *tentiva, prt_u8 dev, prt_u16 clk_cfg_len, prt_rc22504a_reg_struct *clk_cfg_prt, prt_u32 pio_phy_lock)
{
	// Variables
	prt_sta_type sta;

	/*
		Clocking
	*/

	// Select clock device
	prt_tentiva_sel_dev (tentiva, dev);

	// Set two byte addressing mode
	sta = prt_rc22504a_set_adr_mode (tentiva->i2c, PRT_TENTIVA_I2C_RC22504A_ADR);

	if (sta != PRT_STA_OK)
	{
		return sta;
	}	

	// Configure device	
	sta = prt_rc22504a_cfg (tentiva->i2c, PRT_TENTIVA_I2C_RC22504A_ADR, clk_cfg_len, clk_cfg_prt);

	if (sta != PRT_STA_OK)
	{
		return sta;
	}	

	sta = prt_tentiva_get_lock (tentiva, pio_phy_lock);

	if (sta != PRT_STA_OK)
	{
		return sta;
	}	
}

// Select clock device
void prt_tentiva_sel_dev (prt_tentiva_ds_struct *tentiva, prt_u8 dev)
{
	// Select PHY clock device
	if (dev == PRT_TENTIVA_PHY_DEV)
		prt_pio_dat_set (tentiva->pio, tentiva->pio_clk_sel);
	
	// Select video clock device
	else
		prt_pio_dat_clr (tentiva->pio, tentiva->pio_clk_sel);
}

// Config PHY clock
// This can be used by the app to reconfig the PHY clock
prt_sta_type prt_tentiva_phy_cfg (prt_tentiva_ds_struct *tentiva)
{
	// Variables
	prt_sta_type sta;

	// PHY clock
	sta = prt_tentiva_clk_cfg (tentiva, PRT_TENTIVA_PHY_DEV, tentiva->phy_clk_cfg_len, tentiva->phy_clk_cfg_prt[0], tentiva->pio_phy_refclk_lock);

	return sta;
}

// Set PHY frequency
prt_sta_type prt_tentiva_set_phy_freq (prt_tentiva_ds_struct *tentiva, prt_u8 ref, prt_u8 freq)
{
	// Variables
	prt_sta_type sta;
	prt_u8 out;
	prt_u16 div;

	// Just return if the requested frequency is already generated.
	if (tentiva->phy_freq == freq)
	{
		return PRT_STA_OK;
	}

	else
	{
		// Store frequency
		tentiva->phy_freq = freq;

		// This frequency uses configuration 1
		if (tentiva->phy_freq == PRT_TENTIVA_PHY_FREQ_270_MHZ)
		{
			// PHY clock
			sta = prt_tentiva_clk_cfg (tentiva, PRT_TENTIVA_PHY_DEV, tentiva->phy_clk_cfg_len, tentiva->phy_clk_cfg_prt[1], tentiva->pio_phy_refclk_lock);
		
			// Store current configuration
			tentiva->phy_clk_cfg = 1;
		}

		else
		{
			// This frequency uses configuration 0
			// If this configuration isn't active, the clock generator needs to be configured.
			if (tentiva->phy_clk_cfg != 0)
			{
				// PHY clock
				sta = prt_tentiva_clk_cfg (tentiva, PRT_TENTIVA_PHY_DEV, tentiva->phy_clk_cfg_len, tentiva->phy_clk_cfg_prt[0], tentiva->pio_phy_refclk_lock);
			
				// Store current configuration
				tentiva->phy_clk_cfg = 0;
			}

			// Select PHY clock device
			prt_tentiva_sel_dev (tentiva, PRT_TENTIVA_PHY_DEV);

			// Select RC22504 output
			if (ref == 0)
				out = 1;
			else
				out = 2;

			// Select divider
			switch (freq)
			{
				case PRT_TENTIVA_PHY_FREQ_81_MHZ 	: div = 125; break;	// 81 MHz
				case PRT_TENTIVA_PHY_FREQ_135_MHZ 	: div = 75; break;	// 135 MHz
				case PRT_TENTIVA_PHY_FREQ_202_5_MHZ : div = 50; break;	// 202.5 MHz
				default : prt_printf ("Tentiva: unsupported PHY reference clock\n"); return PRT_STA_FAIL; break;
			}

			// Set output divider
			sta = prt_rc22504a_out_div (tentiva->i2c, PRT_TENTIVA_I2C_RC22504A_ADR, out, div);

			// Wait for lock
			sta = prt_tentiva_get_lock (tentiva, tentiva->pio_phy_refclk_lock);
		}	
		return sta;
	}
}

// Set video frequency
prt_sta_type prt_tentiva_set_vid_freq (prt_tentiva_ds_struct *tentiva, prt_u8 freq)
{
	// Variables
	prt_sta_type sta;
	prt_u16 div;

	// Clock 231.035 MHz
	if (freq == PRT_TENTIVA_VID_FREQ_231_036_MHZ)
	{	
		// This frequency uses configuration 2. 
		// If this configuration isn't active, the clock generator needs to be configured.
		if (tentiva->vid_clk_cfg != 2)
		{
			// VID clock
			sta = prt_tentiva_clk_cfg (tentiva, PRT_TENTIVA_VID_DEV, tentiva->vid_clk_cfg_len, tentiva->vid_clk_cfg_prt[2], tentiva->pio_vid_refclk_lock);
			
			// Store current configuration
			tentiva->vid_clk_cfg = 2;
		}
	}

	// Clock 254.974 MHz
	else if (freq == PRT_TENTIVA_VID_FREQ_254_974_MHZ)
	{	
		// This frequency uses configuration 1. 
		// If this configuration isn't active, the clock generator needs to be configured.
		if (tentiva->vid_clk_cfg != 1)
		{
			// VID clock
			sta = prt_tentiva_clk_cfg (tentiva, PRT_TENTIVA_VID_DEV, tentiva->vid_clk_cfg_len, tentiva->vid_clk_cfg_prt[1], tentiva->pio_vid_refclk_lock);
			
			// Store current configuration
			tentiva->vid_clk_cfg = 1;
		}
	}

	else
	{
		// This frequency uses configuration 0. 
		// If this configuration isn't active, the clock generator needs to be configured.
		if (tentiva->vid_clk_cfg != 0)
		{
			// VID clock
			sta = prt_tentiva_clk_cfg (tentiva, PRT_TENTIVA_VID_DEV, tentiva->vid_clk_cfg_len, tentiva->vid_clk_cfg_prt[0], tentiva->pio_vid_refclk_lock);
			
			// Store current configuration
			tentiva->vid_clk_cfg = 0;
		}

		// Select video clock device
		prt_tentiva_sel_dev (tentiva, PRT_TENTIVA_VID_DEV);

		// Select divider
		switch (freq)
		{
			case PRT_TENTIVA_VID_FREQ_297_MHZ   : div = 34; break;	// 297 MHz
			case PRT_TENTIVA_VID_FREQ_1485_MHZ  : div = 68; break;	// 148.5 MHz
			case PRT_TENTIVA_VID_FREQ_7425_MHZ  : div = 136; break;	// 74.25 MHz
			case PRT_TENTIVA_VID_FREQ_37125_MHZ : div = 272; break;	// 37.125 MHz
			default : div = 544; break;								// 18.5625 MHz
		}

		// Set output divider
		sta = prt_rc22504a_out_div (tentiva->i2c, PRT_TENTIVA_I2C_RC22504A_ADR, 0, div);
		sta = prt_rc22504a_out_div (tentiva->i2c, PRT_TENTIVA_I2C_RC22504A_ADR, 1, div);
		sta = prt_rc22504a_out_div (tentiva->i2c, PRT_TENTIVA_I2C_RC22504A_ADR, 2, div);

		// Wait for lock
		sta = prt_tentiva_get_lock (tentiva, tentiva->pio_vid_refclk_lock);
	}

	return sta;
}

// Get PHY clock lock
prt_sta_type prt_tentiva_get_lock (prt_tentiva_ds_struct *tentiva, prt_u32 lock)
{
	// Variables
	prt_u32 dat;
	prt_bool exit_loop;

    // Set alarm 0
    prt_tmr_set_alrm (tentiva->tmr, 0, PRT_TENTIVA_LOCK_TIMEOUT);

    exit_loop = PRT_FALSE;
    do
    {
    	// Read pio
   		dat = prt_pio_dat_get (tentiva->pio);

		if (dat & lock)
		{
			exit_loop = PRT_TRUE;
		}

		else if (prt_tmr_is_alrm (tentiva->tmr, 0))
		{
			prt_printf ("Tentiva: Lock timeout\n");
			return PRT_STA_FAIL;
		}
	} while (exit_loop == PRT_FALSE);

	return PRT_STA_OK;
}

// MCDP6150 / MCDP6000 datapath reset
// This function resets the datapath path of the MCDP6150 / MCDP6000
void prt_tentiva_mcdp6xx0_rst_dp (prt_tentiva_ds_struct *tentiva)
{
	// Variables
	prt_sta_type sta;

	// MCDP6150
	if (tentiva->slot_id[0] == PRT_TENTIVA_DP14RX_ID)
	{
		sta = prt_mcdp6150_rst_dp (tentiva->i2c, PRT_TENTIVA_I2C_MCDP6150_SLOT0_ADR);

		if (sta != PRT_STA_OK)
			prt_printf ("Tentiva: MCDP6150 reset error\n\r");
	}

	// MCDP6000
	else if (tentiva->slot_id[0] == PRT_TENTIVA_DP14RX_MCDP6000_ID)
	{
		sta = prt_mcdp6000_rst_cr (tentiva->i2c, PRT_TENTIVA_I2C_MCDP6000_SLOT0_ADR);
		
		if (sta != PRT_STA_OK)
			prt_printf ("Tentiva: MCDP6000 reset error\n\r");
	}
}

// TDP142 snoop 
// This function disables the TDP142 snoop mode.
// By default the TDP142 adjusts its TX output levels based on the DPCD values.
// In case there is no AUX communication, eg during PHY test, the snooping must be disabled. 
void prt_tentiva_tdp142_snoop_dis (prt_tentiva_ds_struct *tentiva)
{
	// Disable snooping
	prt_tdp142_aux_snoop (tentiva->i2c, PRT_TENTIVA_I2C_TDP142_SLOT1_ADR, PRT_FALSE);
}

// Dump TDP142 registers
void prt_tentiva_tdp142_dump (prt_tentiva_ds_struct *tentiva)
{
 	// Variables
 	prt_sta_type sta;
 	prt_u8 dat;

 	prt_printf ("TDP142 Register dump\n");

	sta = prt_tdp142_rd (tentiva->i2c, PRT_TENTIVA_I2C_TDP142_SLOT1_ADR, 0x0a, &dat);
 	prt_printf ("0x0a : %x\n");

	sta = prt_tdp142_rd (tentiva->i2c, PRT_TENTIVA_I2C_TDP142_SLOT1_ADR, 0x10, &dat);
 	prt_printf ("0x10 : %x\n");

	sta = prt_tdp142_rd (tentiva->i2c, PRT_TENTIVA_I2C_TDP142_SLOT1_ADR, 0x11, &dat);
 	prt_printf ("0x11 : %x\n");

	sta = prt_tdp142_rd (tentiva->i2c, PRT_TENTIVA_I2C_TDP142_SLOT1_ADR, 0x12, &dat);
 	prt_printf ("0x12 : %x\n");

	sta = prt_tdp142_rd (tentiva->i2c, PRT_TENTIVA_I2C_TDP142_SLOT1_ADR, 0x13, &dat);
 	prt_printf ("0x13 : %x\n");
}

// Scan
// This function scans the board id's
void prt_tentiva_scan (prt_tentiva_ds_struct *tentiva)
{
 	// Variables
 	prt_sta_type sta;
 	prt_u8 id;

 	// Base board
	prt_printf ("Tentiva FMC board: ");
	sta = prt_tentiva_eeprom_rd (tentiva->i2c, PRT_TENTIVA_I2C_BASE_EEPROM_ADR);

	if (sta == PRT_STA_OK)
	{
		// Copy FMC ID
		tentiva->fmc_id = tentiva->i2c->dat[2];

		if (tentiva->fmc_id == PRT_TENTIVA_FMC_REVC_ID) 
			prt_printf ("Rev. C\n");

		else if (tentiva->fmc_id == PRT_TENTIVA_FMC_REVD_ID) 
			prt_printf ("Rev. D\n");

		else 
			prt_printf ("Unknown\n");
	}
	else
		prt_printf ("not found!\n");

	// Slot
	for (prt_u8 i = 0; i < 2; i++)
	{
		prt_printf ("Tentiva slot %d: ", i);

		if (i == 0)
			id = PRT_TENTIVA_I2C_EEPROM_SLOT0_ADR;
		else
			id = PRT_TENTIVA_I2C_EEPROM_SLOT1_ADR;

		sta = prt_tentiva_eeprom_rd (tentiva->i2c, id);

		if (sta == PRT_STA_OK)
		{
			// Copy slot ID
			tentiva->slot_id[i] = tentiva->i2c->dat[2];

			switch (tentiva->slot_id[i])
			{
				case PRT_TENTIVA_DP14TX_ID : prt_printf ("DP14TX\n"); break;
				case PRT_TENTIVA_DP21TX_ID : prt_printf ("DP21TX\n"); break;
				case PRT_TENTIVA_DP14RX_ID : prt_printf ("DP14RX\n"); break;
				case PRT_TENTIVA_DP21RX_ID : prt_printf ("DP21RX\n"); break;
				case PRT_TENTIVA_HDMITX_ID : prt_printf ("HDMITX\n"); break;
				case PRT_TENTIVA_EDPTX_ID : prt_printf ("EDPTX\n"); break;
				default : prt_printf ("unknown\n"); break;
			}
		}
		else
			prt_printf ("empty\n");
	}
}

// Force ID
// This function forces a slot identifier
void prt_tentiva_force_id (prt_tentiva_ds_struct *tentiva, prt_u8 slot, prt_u8 id)
{
	tentiva->slot_id[slot] = id;
}

// Identification write
void prt_tentiva_id_wr (prt_tentiva_ds_struct *tentiva, prt_u8 id)
{
	// Variables
	prt_sta_type sta;

	prt_printf ("Tentiva write ID\n");

	switch (id)
	{
		// DP14RX
		case PRT_TENTIVA_DP14RX_ID :
			prt_printf ("DP14RX...");
			sta = prt_tentiva_eeprom_wr (tentiva->i2c, PRT_TENTIVA_I2C_EEPROM_SLOT0_ADR, PRT_TENTIVA_DP14RX_ID);
			break;

		// DP21RX
		case PRT_TENTIVA_DP21RX_ID :
			prt_printf ("DP21RX...");
			sta = prt_tentiva_eeprom_wr (tentiva->i2c, PRT_TENTIVA_I2C_EEPROM_SLOT0_ADR, PRT_TENTIVA_DP21RX_ID);
			break;

		// DP14TX
		case PRT_TENTIVA_DP14TX_ID : 
			prt_printf ("DP14TX...");
			sta = prt_tentiva_eeprom_wr (tentiva->i2c, PRT_TENTIVA_I2C_EEPROM_SLOT1_ADR, PRT_TENTIVA_DP14TX_ID);
			break;

		// DP21TX
		case PRT_TENTIVA_DP21TX_ID : 
			prt_printf ("DP21TX...");
			sta = prt_tentiva_eeprom_wr (tentiva->i2c, PRT_TENTIVA_I2C_EEPROM_SLOT1_ADR, PRT_TENTIVA_DP21TX_ID);
			break;

		// EPTX
		case PRT_TENTIVA_EDPTX_ID : 
			prt_printf ("EDPTX...");
			sta = prt_tentiva_eeprom_wr (tentiva->i2c, PRT_TENTIVA_I2C_EEPROM_SLOT1_ADR, PRT_TENTIVA_EDPTX_ID);
			break;

		// HDMITX
		case PRT_TENTIVA_HDMITX_ID : 
			prt_printf ("HDMITX...");
			sta = prt_tentiva_eeprom_wr (tentiva->i2c, PRT_TENTIVA_I2C_EEPROM_SLOT1_ADR, PRT_TENTIVA_HDMITX_ID);
			break;

		// FMC board Rev. C
		case PRT_TENTIVA_FMC_REVC_ID : 
			prt_printf ("FMC Rev. C board...");
			sta = prt_tentiva_eeprom_wr (tentiva->i2c, PRT_TENTIVA_I2C_BASE_EEPROM_ADR, PRT_TENTIVA_FMC_REVC_ID);
			break;

		// FMC board Rev. D
		case PRT_TENTIVA_FMC_REVD_ID : 
			prt_printf ("FMC Rev. D board...");
			sta = prt_tentiva_eeprom_wr (tentiva->i2c, PRT_TENTIVA_I2C_BASE_EEPROM_ADR, PRT_TENTIVA_FMC_REVD_ID);
			break;

		// Unknown
		default : 
			prt_printf ("Unknown option");
			break;

	}

	if (sta == PRT_STA_OK)
		prt_printf ("ok\n");
	else
		prt_printf ("error\n");
}

// EEPROM write
prt_sta_type prt_tentiva_eeprom_wr (prt_i2c_ds_struct *i2c, prt_u8 slave, prt_u8 id)
{
	// Variables
	prt_sta_type sta;

	// Slave
	i2c->slave = slave;

	// Address high byte
	i2c->dat[0] = 0;
	
	// Address low byte
	i2c->dat[1] = 0;

	// Magic high byte
	i2c->dat[2] = 0x4d;

	// Magic low byte
	i2c->dat[3] = 0x47;

	// ID
	i2c->dat[4] = id;

	// Length
	i2c->len = 5;

	// Write
	sta = prt_i2c_wr (i2c);

	// Return
	return sta;
}

// EEPROM read
prt_sta_type prt_tentiva_eeprom_rd (prt_i2c_ds_struct *i2c, prt_u8 slave)
{
	// Variables
	prt_sta_type sta;

	// Slave
	i2c->slave = slave;

	// Address high byte
	i2c->dat[0] = 0;
	
	// Address low byte
	i2c->dat[1] = 0;

	// Length
	i2c->len = 2;
	
	// Set no stop flag
	i2c->no_stop = PRT_FALSE;

	// Write
	sta = prt_i2c_wr (i2c);

	// Length
	i2c->len = 3;

	// Clear no stop flag
	i2c->no_stop = PRT_FALSE;

	// Read
	sta = prt_i2c_rd (i2c);

	if (sta == PRT_STA_OK)
	{
		// Check magic
		if ((i2c->dat[0] == 0x4d) && (i2c->dat[1] == 0x47))
			return PRT_STA_OK;
		else
			return PRT_STA_FAIL;
	}

	// Return
	return sta;
}
