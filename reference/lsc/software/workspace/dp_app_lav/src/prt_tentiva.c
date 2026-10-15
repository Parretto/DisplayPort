/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Tentiva Driver
    (c) 2021 - 2026 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
	v1.1 - Added set clock configuration function
	v1.2 - Added TDP142 snoop disable function
	v1.3 - Removed DP Application header dependency
	v1.4 - Added multiple clock configurations support
	v1.5 - Added DP21TX card (TDP2004)
	v1.6 - Added TDP1204 and TMDS1204 drivers
	v1.7 - Added support for DP passive RX card
	v1.8 - Code clean up


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
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>

// Tentiva
#include "prt_types.h"
#include "prt_tentiva.h"
#include "prt_mcdp6150.h"
#include "prt_tdp142.h"
#include "prt_tdp2004.h"
#include "prt_tdp1204.h"
#include "prt_tmds1204.h"

// Initialize
void prt_tentiva_init (prt_tentiva_ds_struct *tentiva, void *i2c_wr_cb, void *i2c_rd_cb)
{
	// Set board IDs to empty
	tentiva->fmc_id = 0;
	tentiva->slot_id[0] = 0;
	tentiva->slot_id[1] = 0;

	// Clear variables
	tentiva->phy_freq = 0;
	tentiva->vid_freq = 0;

	// Register I2C callback
	tentiva->i2c_wr_cb = (i2c_cb)i2c_wr_cb;
	tentiva->i2c_rd_cb = (i2c_cb)i2c_rd_cb;
}

// Configuration
// This function configures all the Tentiva components.
prt_sta_type prt_tentiva_cfg (prt_tentiva_ds_struct *tentiva, prt_bool ignore_err)
{
	// Variables
	// The status starts out OK. Both switches below leave it untouched when a slot
	// is empty, so without this a board with no cards fitted returns whatever was
	// on the stack - passing or failing at random. The ignore_err path assigns it
	// at the end, which hid the problem for callers that pass PRT_TRUE.
	prt_sta_type sta = PRT_STA_OK;
	uint32_t dat;

	/*
		Slot 0 - Initialize
	*/
	
	switch (tentiva->slot_id[0])
	{
		// Empty
		case PRT_TENTIVA_EMPTY_ID :
			break;

		// MCDP6150 
		case PRT_TENTIVA_DP14RX_ID : 
			sta = prt_mcdp6150_init (tentiva, PRT_TENTIVA_I2C_MCDP6150_SLOT0_ADR);

			if (sta != PRT_STA_OK)
			{
				if ((sta != PRT_STA_OK) && (ignore_err == PRT_FALSE))
				{
					printf ("-- MCDP6150 config error -- ");
					return sta;
				}
			}	
			break;

		// PS8483
		case PRT_TENTIVA_DP21RX_ID :
			// No initialization is needed
			break;

		// DP Passive RX
		case PRT_TENTIVA_DPPASSRX_ID :
			// No initialization is needed
			break;

		// TMDS1204 
		case PRT_TENTIVA_HDMI21RX_ID :
			sta = prt_tmds1204_init (tentiva, PRT_TENTIVA_I2C_TMDS1204_SLOT0_ADR);

			if (sta != PRT_STA_OK)
			{
				if ((sta != PRT_STA_OK) && (ignore_err == PRT_FALSE))
				{
					printf ("-- TMDS1204 config error -- ");
					return sta;
				}
			}	
			break;
	
		default : 
			printf ("-- Unknow PHY card -- ");
			return PRT_STA_FAIL;
			break;
	}

	/*
		Slot 1 - Initialize
	*/
	
	switch (tentiva->slot_id[1])
	{
		// Empty
		case PRT_TENTIVA_EMPTY_ID :
			break;

		// TDP142 
		case PRT_TENTIVA_DP14TX_ID :
			sta = prt_tdp142_init (tentiva, PRT_TENTIVA_I2C_TDP142_SLOT1_ADR, 1);

			if ((sta != PRT_STA_OK) && (ignore_err == PRT_FALSE))
			{
				printf ("-- TDP142 config error -- ");
				return sta;
			}	
			break;
		
		// TDP2004
		case PRT_TENTIVA_DP21TX_ID :
			sta = prt_tdp2004_init (tentiva, PRT_TENTIVA_I2C_TDP2004_SLOT1_ADR);
	
			if ((sta != PRT_STA_OK) && (ignore_err == PRT_FALSE))
			{
				printf ("-- TDP2004 config error -- ");
				return sta;
			}	
			break;

		// TDP1204
		case PRT_TENTIVA_HDMI21TX_ID :
			sta = prt_tdp1204_init (tentiva, PRT_TENTIVA_I2C_TDP1204_SLOT1_ADR);
			
			if ((sta != PRT_STA_OK) && (ignore_err == PRT_FALSE))
			{
				printf ("-- TDP1204 config error -- ");
				return sta;
			}	
			break;

		default : 
			printf ("-- Unknow PHY card -- ");
			return PRT_STA_FAIL;
	}

	// Force status if ignore error flag is set
	if (ignore_err == PRT_TRUE)
		sta = PRT_STA_OK;

	// Return status
	return sta;
}


// Set PHY frequency
prt_sta_type prt_tentiva_set_phy_freq (prt_tentiva_ds_struct *tentiva, uint32_t freq)
{
	// Variables
	prt_sta_type sta;

	// Just return if the requested frequency is already generated.
	if (tentiva->phy_freq == freq)
	{
		return PRT_STA_OK;
	}

	else
	{
		// Store frequency
		tentiva->phy_freq = freq;

		// Program system clock with PHY clock frequency
		prt_tentiva_sc_reg_wr (tentiva, PRT_TENTIVA_I2C_SC_ADR, PRT_TENTIVA_SC_PHY_CLK, freq);
		
		// Wait for lock
		// The system controller turns the clock off while it reconfigures and reports the
		// lock only when it is back (from firmware 2.3 on the Rev. E board). Going on
		// before that starts the PHY on a reference that is about to disappear.
		sta = prt_tentiva_get_lock (tentiva, PRT_TENTIVA_SC_STA_PHY_CLK_LOCK);
		return sta;
	}
}

// Set video frequency
prt_sta_type prt_tentiva_set_vid_freq (prt_tentiva_ds_struct *tentiva, uint32_t freq)
{
	// Variables
	prt_sta_type sta;
	uint16_t div;

	// Store frequency
	tentiva->vid_freq = freq;

	// Program system clock with PHY clock frequency
	prt_tentiva_sc_reg_wr (tentiva, PRT_TENTIVA_I2C_SC_ADR, PRT_TENTIVA_SC_VID_CLK, freq);
	
	// Wait for lock
	sta = prt_tentiva_get_lock (tentiva, PRT_TENTIVA_SC_STA_VID_CLK_LOCK);
	return sta;
}

// Get clock lock
// The driver has no timer, so the timeout is a number of status reads. Every read is an
// I2C transaction with the system controller, which puts PRT_TENTIVA_LOCK_TRIES at one to
// a few seconds, far more than the system controller itself waits for a lock.
// Without a limit a clock that never locks hangs the application; a system controller
// that does not drive the clock, as firmware 2.1 on the Rev. E board did for the video
// clock, is enough for that.
prt_sta_type prt_tentiva_get_lock (prt_tentiva_ds_struct *tentiva, uint32_t lock)
{
	// Variables
	uint32_t dat;

	for (uint16_t i = 0; i < PRT_TENTIVA_LOCK_TRIES; i++)
	{
		// Read status register from system controller
		dat = prt_tentiva_sc_sta (tentiva);

		if (dat & lock)
			return PRT_STA_OK;
	}

	printf ("Tentiva: Lock timeout\n");
	return PRT_STA_FAIL;
}

// Scan
// This function scans the board id's
void prt_tentiva_scan (prt_tentiva_ds_struct *tentiva)
{
 	// Variables
 	prt_sta_type sta;
    uint8_t ver;
 	uint8_t id;

 	// Base board
	printf ("Tentiva FMC board: ");
	sta = prt_tentiva_eeprom_rd (tentiva, PRT_TENTIVA_I2C_BASE_EEPROM_ADR);

	if (sta == PRT_STA_OK)
	{
		// Copy FMC ID
		tentiva->fmc_id = tentiva->i2c_dat[2];

		if (tentiva->fmc_id == PRT_TENTIVA_FMC_REVC_ID) 
			printf ("Rev. C\n");

		else if (tentiva->fmc_id == PRT_TENTIVA_FMC_REVD_ID) 
			printf ("Rev. D\n");

		else if (tentiva->fmc_id == PRT_TENTIVA_FMC_REVE_ID) 
			printf ("Rev. E\n");

		else 
			printf ("Unknown\n");
	}
	else
		printf ("not found!\n");


	// System controller version
	if (prt_tentiva_has_sc (tentiva))
	{
		ver = prt_tentiva_sc_ver (tentiva);

		printf ("Tentiva System Controller version %d.%d\n", ((ver >> 4) & 0xf), (ver & 0xf));
	}

	// Slot
	for (uint8_t i = 0; i < 2; i++)
	{
		printf ("Tentiva slot %d: ", i);

		if (i == 0)
			id = PRT_TENTIVA_I2C_EEPROM_SLOT0_ADR;
		else
			id = PRT_TENTIVA_I2C_EEPROM_SLOT1_ADR;

		sta = prt_tentiva_eeprom_rd (tentiva, id);

		if (sta == PRT_STA_OK)
		{
			// Copy slot ID
			tentiva->slot_id[i] = tentiva->i2c_dat[2];

			switch (tentiva->slot_id[i])
			{
				case PRT_TENTIVA_DP14TX_ID 		: printf ("DP14TX\n"); break;
				case PRT_TENTIVA_DP21TX_ID 		: printf ("DP21TX\n"); break;
				case PRT_TENTIVA_DP14RX_ID 		: printf ("DP14RX\n"); break;
				case PRT_TENTIVA_DP21RX_ID 		: printf ("DP21RX\n"); break;
				case PRT_TENTIVA_DPPASSRX_ID 	: printf ("DPPASSRX\n"); break;
				case PRT_TENTIVA_HDMI21TX_ID 	: printf ("HDMI21TX\n"); break;
				case PRT_TENTIVA_HDMI21RX_ID 	: printf ("HDMI21RX\n"); break;
				case PRT_TENTIVA_EDPTX_ID 		: printf ("EDPTX\n"); break;
				default : printf ("unknown\n"); break;
			}
		}
		else
		{
			printf ("empty\n");
			tentiva->slot_id[i] = PRT_TENTIVA_EMPTY_ID;
		}
	}
}

// Get FMC ID
// This function reads the slot identifier
uint8_t prt_tentiva_get_fmc_id (prt_tentiva_ds_struct *tentiva)
{
	return tentiva->fmc_id;
}

// Has Tentiva System Controller
// This function return true when the Tentiva FMC board has a system controller
bool prt_tentiva_has_sc (prt_tentiva_ds_struct *tentiva)
{
	if ((tentiva->fmc_id == PRT_TENTIVA_FMC_REVD_ID) || (tentiva->fmc_id == PRT_TENTIVA_FMC_REVE_ID))
		return true;
	else
		return false;
}

// Get slot ID
// This function reads the slot identifier
uint8_t prt_tentiva_get_slot_id (prt_tentiva_ds_struct *tentiva, uint8_t slot)
{
	return tentiva->slot_id[slot];
}

// Force ID
// This function forces a slot identifier
void prt_tentiva_force_slot_id (prt_tentiva_ds_struct *tentiva, uint8_t slot, uint8_t id)
{
	tentiva->slot_id[slot] = id;
}

// Identification write
void prt_tentiva_id_wr (prt_tentiva_ds_struct *tentiva, uint8_t id)
{
	// Variables
	prt_sta_type sta;

	printf ("Tentiva write ID\n");

	switch (id)
	{
		// DP14RX
		case PRT_TENTIVA_DP14RX_ID :
			printf ("DP14RX...");
			sta = prt_tentiva_eeprom_wr (tentiva, PRT_TENTIVA_I2C_EEPROM_SLOT0_ADR, PRT_TENTIVA_DP14RX_ID);
			break;

		// DP21RX
		case PRT_TENTIVA_DP21RX_ID :
			printf ("DP21RX...");
			sta = prt_tentiva_eeprom_wr (tentiva, PRT_TENTIVA_I2C_EEPROM_SLOT0_ADR, PRT_TENTIVA_DP21RX_ID);
			break;

		// DPPASSRX
		case PRT_TENTIVA_DPPASSRX_ID :
			printf ("DPPASSRX...");
			sta = prt_tentiva_eeprom_wr (tentiva, PRT_TENTIVA_I2C_EEPROM_SLOT0_ADR, PRT_TENTIVA_DPPASSRX_ID);
			break;

		// DP14TX
		case PRT_TENTIVA_DP14TX_ID : 
			printf ("DP14TX...");
			sta = prt_tentiva_eeprom_wr (tentiva, PRT_TENTIVA_I2C_EEPROM_SLOT1_ADR, PRT_TENTIVA_DP14TX_ID);
			break;

		// DP21TX
		case PRT_TENTIVA_DP21TX_ID : 
			printf ("DP21TX...");
			sta = prt_tentiva_eeprom_wr (tentiva, PRT_TENTIVA_I2C_EEPROM_SLOT1_ADR, PRT_TENTIVA_DP21TX_ID);
			break;

		// EPTX
		case PRT_TENTIVA_EDPTX_ID : 
			printf ("EDPTX...");
			sta = prt_tentiva_eeprom_wr (tentiva, PRT_TENTIVA_I2C_EEPROM_SLOT1_ADR, PRT_TENTIVA_EDPTX_ID);
			break;

		// HDMI21TX
		case PRT_TENTIVA_HDMI21TX_ID : 
			printf ("HDMI21TX...");
			sta = prt_tentiva_eeprom_wr (tentiva, PRT_TENTIVA_I2C_EEPROM_SLOT1_ADR, PRT_TENTIVA_HDMI21TX_ID);
			break;

		// HDMI21RX
		case PRT_TENTIVA_HDMI21RX_ID : 
			printf ("HDMI21RX...");
			sta = prt_tentiva_eeprom_wr (tentiva, PRT_TENTIVA_I2C_EEPROM_SLOT0_ADR, PRT_TENTIVA_HDMI21RX_ID);
			break;

		// FMC board Rev. C
		case PRT_TENTIVA_FMC_REVC_ID : 
			printf ("FMC Rev. C board...");
			sta = prt_tentiva_eeprom_wr (tentiva, PRT_TENTIVA_I2C_BASE_EEPROM_ADR, PRT_TENTIVA_FMC_REVC_ID);
			break;

		// FMC board Rev. D
		case PRT_TENTIVA_FMC_REVD_ID : 
			printf ("FMC Rev. D board...");
			sta = prt_tentiva_eeprom_wr (tentiva, PRT_TENTIVA_I2C_BASE_EEPROM_ADR, PRT_TENTIVA_FMC_REVD_ID);
			break;

		// FMC board Rev. E
		case PRT_TENTIVA_FMC_REVE_ID : 
			printf ("FMC Rev. E board...");
			sta = prt_tentiva_eeprom_wr (tentiva, PRT_TENTIVA_I2C_BASE_EEPROM_ADR, PRT_TENTIVA_FMC_REVE_ID);
			break;

		// Unknown
		default : 
			printf ("Unknown option");
			break;

	}

	if (sta == PRT_STA_OK)
		printf ("ok\n");
	else
		printf ("error\n");
}

// EEPROM write
prt_sta_type prt_tentiva_eeprom_wr (prt_tentiva_ds_struct *tentiva, uint8_t slave, uint8_t id)
{
	// Variables
	prt_sta_type sta;

	// Slave
	tentiva->i2c_slave = slave;

	// Address high byte
	tentiva->i2c_dat[0] = 0;
	
	// Address low byte
	tentiva->i2c_dat[1] = 0;

	// Magic high byte
	tentiva->i2c_dat[2] = 0x4d;

	// Magic low byte
	tentiva->i2c_dat[3] = 0x47;

	// ID
	tentiva->i2c_dat[4] = id;

	// Length
	tentiva->i2c_len = 5;

	// Write
	sta = prt_tentiva_i2c_wr (tentiva);

	// Return
	return sta;
}

// EEPROM read
prt_sta_type prt_tentiva_eeprom_rd (prt_tentiva_ds_struct *tentiva, uint8_t slave)
{
	// Variables
	prt_sta_type sta;

	// Slave
	tentiva->i2c_slave = slave;

	// Address high byte
	tentiva->i2c_dat[0] = 0;
	
	// Address low byte
	tentiva->i2c_dat[1] = 0;

	// Length
	tentiva->i2c_len = 2;
	
	// Set no stop flag
//	tentiva->i2c_no_stop = PRT_FALSE;

	// Write
	sta = prt_tentiva_i2c_wr (tentiva);

	// Length
	tentiva->i2c_len = 3;

	// Clear no stop flag
//	tentiva->i2c_no_stop = PRT_FALSE;

	// Read
	sta = prt_tentiva_i2c_rd (tentiva);

	if (sta == PRT_STA_OK)
	{
		// Check magic
		if ((tentiva->i2c_dat[0] == 0x4d) && (tentiva->i2c_dat[1] == 0x47))
			return PRT_STA_OK;
		else
			return PRT_STA_FAIL;
	}

	// Return
	return sta;
}

// System controller register write
prt_sta_type prt_tentiva_sc_reg_wr (prt_tentiva_ds_struct *tentiva, uint8_t slave, uint8_t adr, uint32_t dat)
{
	// Variables
	prt_sta_type sta;

	// Slave
	tentiva->i2c_slave = slave;

	// Address 
	tentiva->i2c_dat[0] = adr;
	
	// Data
	tentiva->i2c_dat[1] = dat & 0xff;

	// Data
	tentiva->i2c_dat[2] = (dat >> 8) & 0xff;

	// Data
	tentiva->i2c_dat[3] = (dat >> 16) & 0xff;

	// Data
	tentiva->i2c_dat[4] = (dat >> 24) & 0xff;

	// Length
	tentiva->i2c_len = 5;

	// Write
	sta = prt_tentiva_i2c_wr (tentiva);

	// Return
	return sta;
}

// System controller register read
prt_sta_type prt_tentiva_sc_reg_rd (prt_tentiva_ds_struct *tentiva, uint8_t slave, uint8_t adr, uint8_t *dat)
{
	// Variables
	prt_sta_type sta;

	// Slave
	tentiva->i2c_slave = slave;

	// Address 
	tentiva->i2c_dat[0] = adr;

	// Length
	tentiva->i2c_len = 1;
	
	// Set no stop flag
	//tentiva->i2c_no_stop = PRT_TRUE;

	// Write
	sta = prt_tentiva_i2c_wr (tentiva);

	// Length
	tentiva->i2c_len = 1;

	// Clear no stop flag
	//tentiva->i2c_no_stop = PRT_FALSE;

	// Read
	sta = prt_tentiva_i2c_rd (tentiva);

	// Copy data
	*dat = tentiva->i2c_dat[0];

	// Return
	return sta;
}

// Tentiva I2C write
prt_sta_type prt_tentiva_i2c_wr (prt_tentiva_ds_struct *tentiva)
{
	if (tentiva->i2c_wr_cb)
	{
		return tentiva->i2c_wr_cb (tentiva->i2c_slave, tentiva->i2c_dat, tentiva->i2c_len);
	}

	else 
		return PRT_STA_FAIL;
}

// Tentiva I2C read
prt_sta_type prt_tentiva_i2c_rd (prt_tentiva_ds_struct *tentiva)
{
	if (tentiva->i2c_rd_cb)
	{
		return tentiva->i2c_rd_cb (tentiva->i2c_slave, tentiva->i2c_dat, tentiva->i2c_len);
	}

	else 
		return PRT_STA_FAIL;
}

// Tentiva mezzanine clock buffer select
// This function drives the clock buffer select
prt_sta_type prt_tentiva_sc_mz_clk_sel (prt_tentiva_ds_struct *tentiva, uint8_t mz)
{
	// Variables
	uint8_t dat;
	prt_sta_type sta;

	// Read control register
	sta = prt_tentiva_sc_reg_rd (tentiva, PRT_TENTIVA_I2C_SC_ADR, PRT_TENTIVA_SC_CTL, &dat);

	if (sta != PRT_STA_OK)
		return PRT_STA_FAIL;

	// Clear mezzanine clock select bit
	dat |= (~PRT_TENTIVA_SC_CTL_MZ_CLK_SEL);

	// Set bit
	if (mz == 1)
		dat |= PRT_TENTIVA_SC_CTL_MZ_CLK_SEL;
		
	// Write control register
	sta = prt_tentiva_sc_reg_wr (tentiva, PRT_TENTIVA_I2C_SC_ADR, PRT_TENTIVA_SC_CTL, dat);

	return sta;
}

// Tentiva GT reference clock mode
// This function select between the two clock modes. 
// - Pass-through mode (route the mezzanine clock to the GT reference clock input)
// - Synthesizer mode (route the PLL synthesizer clock to the GT reference clock input)
prt_sta_type prt_tentiva_sc_gt_clk_mode (prt_tentiva_ds_struct *tentiva, bool pass)
{
	// Variables
	uint8_t dat;
	prt_sta_type sta;

	// Read control register
	sta = prt_tentiva_sc_reg_rd (tentiva, PRT_TENTIVA_I2C_SC_ADR, PRT_TENTIVA_SC_CTL, &dat);

	if (sta != PRT_STA_OK)
		return PRT_STA_FAIL;

	// Clear bit
	dat &= (~PRT_TENTIVA_SC_CTL_GT_REF_CLK_SEL);

	// Pass-through mode
	if (pass)
		dat |= PRT_TENTIVA_SC_CTL_GT_REF_CLK_SEL;
		
	// Write control register
	sta = prt_tentiva_sc_reg_wr (tentiva, PRT_TENTIVA_I2C_SC_ADR, PRT_TENTIVA_SC_CTL, dat);

	return sta;
}

// Tentiva system controller version
// This function reads the system controller version
uint8_t prt_tentiva_sc_ver (prt_tentiva_ds_struct *tentiva)
{
	// Variables
	uint8_t dat;
	prt_sta_type sta;

	// Read version register
	sta = prt_tentiva_sc_reg_rd (tentiva, PRT_TENTIVA_I2C_SC_ADR, PRT_TENTIVA_SC_VER, &dat);

	if (sta != PRT_STA_OK)
		return 0;

	else 
		return dat;
}

// Tentiva system controller status register
// This function reads the system controller status register
uint8_t prt_tentiva_sc_sta (prt_tentiva_ds_struct *tentiva)
{
	// Variables
	uint8_t dat;
	prt_sta_type sta;

	// Read version register
	sta = prt_tentiva_sc_reg_rd (tentiva, PRT_TENTIVA_I2C_SC_ADR, PRT_TENTIVA_SC_STA, &dat);

	if (sta != PRT_STA_OK)
		return 0;

	else 
		return dat;
}


// Tentiva 
// This function writes the DCO register. 
// This is used during clock recovery. 
prt_sta_type prt_tentiva_sc_dco (prt_tentiva_ds_struct *tentiva, uint32_t dat)
{	
	// Variables
	prt_sta_type sta;

	// Write control register
	sta = prt_tentiva_sc_reg_wr (tentiva, PRT_TENTIVA_I2C_SC_ADR, PRT_TENTIVA_SC_DCO, dat);

	return sta;
}


// TMDS1204 config function
void prt_tentiva_tmds1204_cfg (prt_tentiva_ds_struct *tentiva, bool mode, uint8_t vod, uint8_t eq)
{
	prt_tmds1204_cfg (tentiva, PRT_TENTIVA_I2C_TMDS1204_SLOT0_ADR, mode, vod, eq);
}


// TDP1204 dump
void prt_tentiva_tdp1204_dump (prt_tentiva_ds_struct *tentiva)
{
	prt_tdp1204_dump (tentiva, PRT_TENTIVA_I2C_TDP1204_SLOT1_ADR);
}

// TDP1204 write
void prt_tentiva_tdp1204_wr (prt_tentiva_ds_struct *tentiva, uint8_t offset, uint8_t dat)
{
	prt_tdp1204_wr (tentiva, PRT_TENTIVA_I2C_TDP1204_SLOT1_ADR, offset, dat);
}
