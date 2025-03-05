/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: TI TMDS1204 Driver 
    (c) 2025 by Parretto B.V.

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
#include "prt_printf.h"
#include "prt_i2c.h"
#include "prt_tmds1204.h"

// Initialize
prt_sta_type prt_tmds1204_init (prt_i2c_ds_struct *i2c, uint8_t slave)
{
	// Variables
	prt_sta_type sta;

    // Read ID
	sta = prt_tmds1204_id (i2c, slave);
	
	if (sta != PRT_STA_OK)
		return PRT_STA_FAIL;
	
	// Set normal operation
	sta = prt_tmds1204_run (i2c, slave);

	return sta;
}

// Read ID
prt_sta_type prt_tmds1204_id (prt_i2c_ds_struct *i2c, uint8_t slave)
{
	// Variables
	prt_sta_type sta;
	uint8_t dat;

	sta = prt_tmds1204_rd (i2c, slave, 0x08, &dat);

	if (dat == 0x03)
		return PRT_STA_OK;
	else
		return PRT_STA_FAIL;
}

// Run (Normal operation)
prt_sta_type prt_tmds1204_run (prt_i2c_ds_struct *i2c, uint8_t slave)
{
	// Variables
	prt_sta_type sta;
	uint8_t dat;

    // FANOUT enabled, Rate snoop disabled and TXFFE controlled by 35h, 41h, and 42h
	sta = prt_tmds1204_wr (i2c, slave, 0x0a, 0x45);

    // 3G and 6G tx slew rate control   
	sta = prt_tmds1204_wr (i2c, slave, 0x0b, 0x23);

	// HDMI clock tx slew rate control
	sta = prt_tmds1204_wr (i2c, slave, 0x0c, 0x00);
 
    // Linear mode, DC-coupled TX, 0dB DCG, Term fixed at 100Ω, disable CTLE bypass
	sta = prt_tmds1204_wr (i2c, slave, 0x0d, 0x97);

    // HDMI 1.4, 2.0 and 2.1 CTLE selection
	sta = prt_tmds1204_wr (i2c, slave, 0x0e, 0x97);
    
    // Disable all four lanes.
	sta = prt_tmds1204_wr (i2c, slave, 0x11, 0x00);

    // Take out of PD state. Should be done after initialization is complete.
	sta = prt_tmds1204_wr (i2c, slave, 0x09, 0x00);

    // Limited mode, AC-coupled TX, 0dB DCG, Term open, disable CTLE bypass
    sta = prt_tmds1204_wr (i2c, slave, 0x0d, 0x60);

    // Clock lane VOD and TXFFE
    sta = prt_tmds1204_wr (i2c, slave, 0x12, 0x03);

    // Clock lane EQ.
    sta = prt_tmds1204_wr (i2c, slave, 0x13, 0x00);

    // D0 lane VOD and TXFFE.
    sta = prt_tmds1204_wr (i2c, slave, 0x14, 0x03);

    // D0 lane EQ
    sta = prt_tmds1204_wr (i2c, slave, 0x15, 0x03);

    // D1 lane VOD and TXFFE.
    sta = prt_tmds1204_wr (i2c, slave, 0x16, 0x03);

    // D1 lane EQ
    sta = prt_tmds1204_wr (i2c, slave, 0x17, 0x03);

    // D2 lane VOD and TXFFE.
    sta = prt_tmds1204_wr (i2c, slave, 0x18, 0x03);

    // D2 lane EQ
    sta = prt_tmds1204_wr (i2c, slave, 0x19, 0x03);
    
    // Clear TMDS_CLK_RATIO
    sta = prt_tmds1204_wr (i2c, slave, 0x20, 0x00);
    
    // Disable FRL
    sta = prt_tmds1204_wr (i2c, slave, 0x31, 0x00);

    // Enable all four lanes
    sta = prt_tmds1204_wr (i2c, slave, 0x11, 0x0f);

	return sta;
}

// Read register
prt_sta_type prt_tmds1204_rd (prt_i2c_ds_struct *i2c, uint8_t slave, uint8_t offset, uint8_t *dat)
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
prt_sta_type prt_tmds1204_wr (prt_i2c_ds_struct *i2c, uint8_t slave, uint8_t offset, uint8_t dat)
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

