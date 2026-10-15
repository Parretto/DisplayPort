/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: TI TDP142 Driver 
    (c) 2021, 2022 by Parretto B.V.

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
#include "prt_tentiva.h"
#include "prt_tdp142.h"

// Initialize
prt_sta_type prt_tdp142_init (prt_tentiva_ds_struct *tentiva, uint8_t slave, uint8_t eq)
{
	// Variables
	prt_sta_type sta;

	// Enable DP
	sta = prt_tdp142_dp_en (tentiva, slave);

	// AUX snooping
	sta = prt_tdp142_aux_snoop (tentiva, slave, PRT_TRUE);

	// Set EQ value
	sta = prt_tdp142_eq (tentiva, slave, eq);

	return sta;
}

// Enable DP
prt_sta_type prt_tdp142_dp_en (prt_tentiva_ds_struct *tentiva, uint8_t slave)
{
	// Variables
	prt_sta_type sta;
	uint8_t dat;

	// Generate register
	// Read 
	sta = prt_tdp142_rd (tentiva, slave, 0x0a, &dat);

	if (sta != PRT_STA_OK)
		return PRT_STA_FAIL;

	// Enable DP
	dat &= ~(0x03);
	dat |= 0x02;

	// HPDIN override
	dat |= (1 << 3);

	// ERQ settings override
	dat |= (1 << 4);

	// Write 
	sta = prt_tdp142_wr (tentiva, slave, 0x0a, dat);

	if (sta != PRT_STA_OK)
		return PRT_STA_FAIL;

	return PRT_STA_OK;
}

// AUX snoop
prt_sta_type prt_tdp142_aux_snoop (prt_tentiva_ds_struct *tentiva, uint8_t slave, prt_bool en)
{
	// Variables
	prt_sta_type sta;
	uint8_t dat;

	// Control register
	// Read 
	sta = prt_tdp142_rd (tentiva, slave, 0x13, &dat);

	if (sta != PRT_STA_OK)
		return PRT_STA_FAIL;

	// Enable
	if (en)
		dat &= ~(1 << 7);

	// Disable AUX snoop
	else
		dat |= (1 << 7);

	// Write 
	sta = prt_tdp142_wr (tentiva, slave, 0x13, dat);

	if (sta != PRT_STA_OK)
		return PRT_STA_FAIL;

	return PRT_STA_OK;
}

// Set EQ value
prt_sta_type prt_tdp142_eq (prt_tentiva_ds_struct *tentiva, uint8_t slave, uint8_t eq)
{
	// Variables
	prt_sta_type sta;
	uint8_t dat;

	// Lane 0
	dat = eq;

	// Lane 1
	dat |= (eq << 4);

	// Write (lanes 0 & 1)
	sta = prt_tdp142_wr (tentiva, slave, 0x10, dat);

	if (sta != PRT_STA_OK)
		return PRT_STA_FAIL;

	// Write (lanes 2 & 3)
	sta = prt_tdp142_wr (tentiva, slave, 0x11, dat);

	if (sta != PRT_STA_OK)
		return PRT_STA_FAIL;

	return PRT_STA_OK;
}

// Read register
prt_sta_type prt_tdp142_rd (prt_tentiva_ds_struct *tentiva, uint8_t slave, uint8_t offset, uint8_t *dat)
{
	// Variables
	prt_sta_type sta;

	// Slave
	tentiva->i2c_slave = slave;
	
	// Offset 
	tentiva->i2c_dat[0] = offset;

	// Length
	tentiva->i2c_len = 1;

	// Set no stop flag
	//i2c->no_stop = PRT_TRUE;

	// Write
	sta = prt_tentiva_i2c_wr (tentiva);

	if (sta != PRT_STA_OK)
	{
		return sta;
	}

	// Length
	tentiva->i2c_len = 1;

	// Clear no stop flag
	//i2c->no_stop = PRT_FALSE;

	// Read
	sta = prt_tentiva_i2c_rd (tentiva);

	// Copy data
	*dat = tentiva->i2c_dat[0];

	// Return status
	return sta;
}

// Write register
prt_sta_type prt_tdp142_wr (prt_tentiva_ds_struct *tentiva, uint8_t slave, uint8_t offset, uint8_t dat)
{
	// Variables
	prt_sta_type sta;

	// Slave
	tentiva->i2c_slave = slave;

	// Offset
	tentiva->i2c_dat[0] = offset;

	// Data 
	tentiva->i2c_dat[1] = dat;

	// Length
	tentiva->i2c_len = 2;

	// Write
	sta = prt_tentiva_i2c_wr (tentiva);

	// Return
	return sta;
}

