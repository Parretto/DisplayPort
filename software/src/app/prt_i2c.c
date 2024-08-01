/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: I2C Peripheral driver
    (c) 2021 - 2024 by Parretto B.V.

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
#include <stdint.h>
#include <stdbool.h>
#include "prt_types.h"
#include "prt_i2c.h"

// Initialize
void prt_i2c_init (prt_i2c_ds_struct *i2c, uint32_t base, uint32_t beat)
{
	// Base address
	i2c->dev = (prt_i2c_dev_struct *) base;
	
	// The i2c peripheral divides the clock/bit into four phases.
	// So divide the beat value by four.
	i2c->dev->beat = (beat >> 2);

	// Clear no stop flag
	i2c->no_stop = PRT_FALSE;

	// Disable device
	i2c->dev->ctl = 0;
}

// I2C write
prt_sta_type prt_i2c_wr (prt_i2c_ds_struct *i2c)
{
	// Variables
	prt_sta_type sta;

	// Start condition
	i2c->dev->ctl = PRT_I2C_CTL_RUN | PRT_I2C_CTL_STR;

	// Wait for completion
	while (!(i2c->dev->sta & PRT_I2C_STA_RDY));

	// Clear ready bit
	i2c->dev->sta = PRT_I2C_STA_RDY;

	// Slave write address
	i2c->dev->wr_dat = i2c->slave << 1;

	// Write
	i2c->dev->ctl = PRT_I2C_CTL_RUN | PRT_I2C_CTL_WR;

	// Wait for completion
	while (!(i2c->dev->sta & PRT_I2C_STA_RDY));

	// Clear ready bit
	i2c->dev->sta = PRT_I2C_STA_RDY;

	// Check for acknowledge
	if (i2c->dev->sta & PRT_I2C_STA_ACK)
	{
		// Write data
		for (int i = 0; i < i2c->len; i++)
		{
			// Data
			i2c->dev->wr_dat = i2c->dat[i];

			// Write
			i2c->dev->ctl = PRT_I2C_CTL_RUN | PRT_I2C_CTL_WR;

			// Wait for completion
			while (!(i2c->dev->sta & PRT_I2C_STA_RDY));

			// Clear ready bit
			i2c->dev->sta = PRT_I2C_STA_RDY;	
		}

		// Status
		sta = PRT_STA_OK;
	}

	// No acknowledge
	else
	{
		// Status
		sta = PRT_STA_FAIL;
	}

	if ((sta == PRT_STA_OK) && (i2c->no_stop == PRT_FALSE))
	{
		// Stop condition
		i2c->dev->ctl = PRT_I2C_CTL_RUN | PRT_I2C_CTL_STP;

		// Wait for completion
		while (!(i2c->dev->sta & PRT_I2C_STA_RDY));

		// Clear ready bit
		i2c->dev->sta = PRT_I2C_STA_RDY;

		// Disable device
		i2c->dev->ctl = 0;
	}

	// Return status
	return sta;
}

// I2C read
prt_sta_type prt_i2c_rd (prt_i2c_ds_struct *i2c)
{
	// Variables
	uint8_t cmd;
	prt_sta_type sta;

	// Start condition
	i2c->dev->ctl = PRT_I2C_CTL_RUN | PRT_I2C_CTL_STR;

	// Wait for completion
	while (!(i2c->dev->sta & PRT_I2C_STA_RDY));

	// Clear ready bit
	i2c->dev->sta = PRT_I2C_STA_RDY;

	// Slave read address
	i2c->dev->wr_dat = (i2c->slave << 1) | 0x01;

	// Write
	i2c->dev->ctl = PRT_I2C_CTL_RUN | PRT_I2C_CTL_WR;

	// Wait for completion
	while (!(i2c->dev->sta & PRT_I2C_STA_RDY));

	// Clear ready bit
	i2c->dev->sta = PRT_I2C_STA_RDY;

	// Check for acknowledge
	if (i2c->dev->sta & PRT_I2C_STA_ACK)
	{
		// Read data
		for (uint8_t i = 0; i < i2c->len; i++)
		{
			cmd = PRT_I2C_CTL_RUN | PRT_I2C_CTL_RD;
			
			// Acknowledge all data, except the last data
			if (i < i2c->len-1)
				cmd |= PRT_I2C_CTL_ACK;

			i2c->dev->ctl = cmd;

			// Wait for completion
			while (!(i2c->dev->sta & PRT_I2C_STA_RDY));

			// Clear ready bit
			i2c->dev->sta = PRT_I2C_STA_RDY;	

			// Data
			i2c->dat[i] = i2c->dev->rd_dat;
		}

		// Status
		sta = PRT_STA_OK;
	}

	// No acknowledge
	else
	{
		// Status
		sta = PRT_STA_FAIL;
	}

	if ((sta == PRT_STA_OK) && (i2c->no_stop == PRT_FALSE))
	{
		// Stop condition
		i2c->dev->ctl = PRT_I2C_CTL_RUN | PRT_I2C_CTL_STP;

		// Wait for completion
		while (!(i2c->dev->sta & PRT_I2C_STA_RDY));

		// Clear ready bit
		i2c->dev->sta = PRT_I2C_STA_RDY;

		// Disable device
		i2c->dev->ctl = 0;
	}

	// Return status
	return sta;
}

// DIA mode
prt_sta_type prt_i2c_dia (prt_i2c_ds_struct *i2c, bool dia, bool tentiva)
{
	// Variables
	uint8_t dat = 0;

	// Enable dia mode 
	if (dia)
		dat = PRT_I2C_CTL_RUN | PRT_I2C_CTL_DIA;

	// This flag controls which Tentiva revision is used (0 - Rev. C / 1 - Rev. D)
	if (tentiva)
		dat |= PRT_I2C_CTL_TENTIVA;

	// Write control register
	i2c->dev->ctl = dat;
}
