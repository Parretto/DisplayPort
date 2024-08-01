/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: TI TDP2004 Driver 
    (c) 2024 by Parretto B.V.

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
#include "prt_types.h"
#include "prt_i2c.h"
#include "prt_tdp2004.h"

// Initialize
prt_sta_type prt_tdp2004_init (prt_i2c_ds_struct *i2c, uint8_t slave)
{
	// Variables
	prt_sta_type sta;

    // Read ID
	sta = prt_tdp2004_id (i2c, slave);
	
	// Set normal operation
	sta = prt_tdp2004_run (i2c, slave);

	return sta;
}

// Read ID
prt_sta_type prt_tdp2004_id (prt_i2c_ds_struct *i2c, uint8_t slave)
{
	// Variables
	prt_sta_type sta;
	uint8_t dat;

	sta = prt_tdp2004_rd (i2c, slave, 0xf0, &dat);
	sta = prt_tdp2004_rd (i2c, slave, 0xf1, &dat);

	if (dat == 0x29)
		return PRT_STA_OK;
	else
		return PRT_STA_FAIL;
}

// Run (Normal operation)
prt_sta_type prt_tdp2004_run (prt_i2c_ds_struct *i2c, uint8_t slave)
{
	// Variables
	prt_sta_type sta;
	uint8_t dat;

	// Read TI test mode control register
	sta = prt_tdp2004_rd (i2c, slave, 0x84, &dat);
  
	// Disable test mode 
	dat |= (1<<2);
	
	// Write register (broadcast write channels)
	sta = prt_tdp2004_wr (i2c, slave, 0x84, dat);

	return sta;
}

// Read register
prt_sta_type prt_tdp2004_rd (prt_i2c_ds_struct *i2c, uint8_t slave, uint8_t offset, uint8_t *dat)
{
	// Variables
	prt_sta_type sta;

	// Slave
	i2c->slave = slave;
	
	// Offset 
	i2c->dat[0] = offset;

	// Length
	i2c->len = 1;

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
prt_sta_type prt_tdp2004_wr (prt_i2c_ds_struct *i2c, uint8_t slave, uint8_t offset, uint8_t dat)
{
	// Variables
	prt_sta_type sta;

	// Slave
	i2c->slave = slave;

	// Offset
	i2c->dat[0] = offset;

	// Data 
	i2c->dat[1] = dat;

	// Length
	i2c->len = 2;

	// Write
	sta = prt_i2c_wr (i2c);

	// Return
	return sta;
}

