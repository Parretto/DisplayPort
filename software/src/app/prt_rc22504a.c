/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Renesas RC22504a Driver 
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
    The License is available for download and print at www.parretto.com/license
    Parretto grants you, as the Licensee, a free, non-exclusive, non-transferable, limited right to use the IP-core 
    solely for internal business purposes for the term and conditions of the License. 
    You are also allowed to create Modifications for internal business purposes, but explicitly only under the conditions of art. 3.2.
    You are, however, obliged to pay the License Fees to Parretto for the use of the IP-core, or any Modification, in, or embodied in, 
    a physical or non-tangible product or service that has substantial commercial, industrial or non-consumer uses. 
*/

// Includes
#include <stdint.h>
#include "prt_types.h"
#include "prt_i2c.h"
#include "prt_rc22504a.h"
#include "prt_printf.h"

// Set two byte addressing mode
// At power-up the device is operating in page  mode with single byte addressing. 
// This function sets the device in two byte addressing. 
prt_sta_type prt_rc22504a_set_adr_mode (prt_i2c_ds_struct *i2c, uint8_t slave)
{
	// Variables
	prt_sta_type sta;

	// Slave
	i2c->slave = slave;

	// Page register
	i2c->dat[0] = PRT_RC22504A_PAGE_REG;
	i2c->dat[1] = PRT_RC22504A_SSI_GLOBAL_CNFG >> 8;
	i2c->len = 2;

	// Write
	sta = prt_i2c_wr (i2c);

	//  SSI_GLOBAL_CNFG register
	i2c->dat[0] = PRT_RC22504A_SSI_GLOBAL_CNFG & 0xff;

	// Select I2C mode
	i2c->dat[1] = 0x1;

	// Select 2 byte address
	i2c->dat[1] |= (1<<2);
	i2c->len = 2;

	// Write
	sta = prt_i2c_wr (i2c);

	// Return status
	return sta;
}

// Read register
prt_sta_type prt_rc22504a_rd (prt_i2c_ds_struct *i2c, uint8_t slave, uint16_t offset, uint8_t *dat)
{
	// Variables
	prt_sta_type sta;

	// Slave
	i2c->slave = slave;

	// Offset MSB
	i2c->dat[0] = offset >> 8;
	
	// Offset LSB
	i2c->dat[1] = offset & 0xff;

	// Length
	i2c->len = 2;

	// Set no stop flag
	i2c->no_stop = PRT_TRUE;

	// Write
	sta = prt_i2c_wr (i2c);

	if (sta != PRT_STA_OK)
	{
		return sta;
	}

	// Length
	i2c->len = 1;

	// Clear no stop flag
	i2c->no_stop = PRT_FALSE;

	// Read
	sta = prt_i2c_rd (i2c);

	// Copy data
	*dat = i2c->dat[0];

	// Return status
	return sta;
}

// Write register
prt_sta_type prt_rc22504a_wr (prt_i2c_ds_struct *i2c, uint8_t slave, uint16_t offset, uint8_t dat)
{
	// Variables
	prt_sta_type sta;

	// Slave
	i2c->slave = slave;

	// Offset MSB
	i2c->dat[0] = offset >> 8;
	
	// Offset LSB
	i2c->dat[1] = offset & 0xff;

	// Data
	i2c->dat[2] = dat;

	// Length
	i2c->len = 3;

	// Write
	sta = prt_i2c_wr (i2c);

	// Return
	return sta;
}

// Config
prt_sta_type prt_rc22504a_cfg (prt_i2c_ds_struct *i2c, uint8_t slave, uint16_t length, prt_rc22504a_reg_struct *config)
{
	// Variables
	prt_sta_type sta;
	uint8_t dat;
	
	// Load configuration
	for (uint32_t i = 0; i < length; i++)
	{
		sta = prt_rc22504a_wr (i2c, slave, config->offset, config->value);

		if (sta != PRT_STA_OK)
		{
			break;
		}
		config++;
	}

	// Read Device reset register
	sta = prt_rc22504a_rd (i2c, slave, PRT_RC22504A_DEV_RESET, &dat);

	// Set apll_reinit bit
	dat |= PRT_RC22504A_DEV_RESET_APLL_REINT;
	sta = prt_rc22504a_wr (i2c, slave, PRT_RC22504A_DEV_RESET, dat);

	// Clear apll_reinit bit
	dat &= ~(PRT_RC22504A_DEV_RESET_APLL_REINT);
	sta = prt_rc22504a_wr (i2c, slave, PRT_RC22504A_DEV_RESET, dat);

	return sta;
}

// Enable / Disable output driver
prt_sta_type prt_rc22504a_out_drv (prt_i2c_ds_struct *i2c, uint8_t slave, uint8_t out, uint8_t en)
{
	// Variables 
	prt_sta_type sta;
	uint8_t dat;
	uint16_t reg;

	switch (out)
	{
		case 1 : reg = 0x10a; break;
		case 2 : reg = 0x112; break;
		case 3 : reg = 0x11a; break;
		default : reg = 0x102; break;
	}

	// read register
	sta = prt_rc22504a_rd (i2c, slave, reg, &dat);

	// Enable
	if (en)
		dat &= ~(PRT_RC22504A_ODRV_EN_OUT_DIS);

	// Disable
	else
		dat |= PRT_RC22504A_ODRV_EN_OUT_DIS;

	// Update register
	sta = prt_rc22504a_wr (i2c, slave, reg, dat);

	return sta;
}

// Set output divider
prt_sta_type prt_rc22504a_out_div (prt_i2c_ds_struct *i2c, uint8_t slave, uint8_t out, uint16_t div)
{
	// Variables 
	prt_sta_type sta;
	uint8_t dat;
	uint16_t reg;

	// Disable output driver
	prt_rc22504a_out_drv (i2c, slave, out, 0);

	switch (out)
	{
		case 1 : reg = 0x108; break;
		case 2 : reg = 0x110; break;
		case 3 : reg = 0x118; break;
		default : reg = 0x100; break;
	}

	// Load lower byte
	dat = div;

	// Write lower byte
	sta = prt_rc22504a_wr (i2c, slave, reg, dat);

	// Load upper byte
	dat = div >> 8;

	// Enable LDO
	dat |= (1 << 7);

	// Write upper byte
	sta = prt_rc22504a_wr (i2c, slave, reg + 1, dat);

	// Enable output driver
	prt_rc22504a_out_drv (i2c, slave, out, 1);

	return sta;
}

// Set dco
prt_sta_type prt_rc22504a_dco (prt_i2c_ds_struct *i2c, uint8_t slave, uint32_t val)
{
	// Variables 
	prt_sta_type sta;
	uint8_t dat;

	// Load first byte
	dat = val & 0xff;

	// Write byte
	sta = prt_rc22504a_wr (i2c, slave, PRT_RC22504A_MISC_WRITE_FREQ, dat);

	// Load second byte
	dat = (val >> 8) & 0xff;

	// Write upper byte
	sta = prt_rc22504a_wr (i2c, slave, PRT_RC22504A_MISC_WRITE_FREQ + 1, dat);

	// Load third byte
	dat = (val >> 16) & 0xff;

	// Write upper byte
	sta = prt_rc22504a_wr (i2c, slave, PRT_RC22504A_MISC_WRITE_FREQ + 2, dat);

	// Load forth byte
	dat = (val >> 24) & 0xff;

	// Write upper byte
	sta = prt_rc22504a_wr (i2c, slave, PRT_RC22504A_MISC_WRITE_FREQ + 3, dat);

	return sta;
}

