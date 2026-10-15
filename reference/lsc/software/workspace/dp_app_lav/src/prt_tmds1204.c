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
#include <stdbool.h>
#include "prt_types.h"
#include "prt_tentiva.h"
#include "prt_tmds1204.h"

// Initialize
prt_sta_type prt_tmds1204_init (prt_tentiva_ds_struct *tentiva, uint8_t slave)
{
	// Variables
	prt_sta_type sta;

    // Read ID
	sta = prt_tmds1204_id (tentiva, slave);
	
	if (sta != PRT_STA_OK)
		return PRT_STA_FAIL;
	
	// Set normal operation
	// Limited redriver (TX and RX voltage swing and pre-emphasis are decoupled)
	sta = prt_tmds1204_cfg (tentiva, slave, false, 0, 3);

	return sta;
}

// Read ID
prt_sta_type prt_tmds1204_id (prt_tentiva_ds_struct *tentiva, uint8_t slave)
{
	// Variables
	prt_sta_type sta;
	uint8_t dat;

	sta = prt_tmds1204_rd (tentiva, slave, 0x08, &dat);

	if (dat == 0x03)
		return PRT_STA_OK;
	else
		return PRT_STA_FAIL;
}

// Configuration
// Redriver Mode - set linear redriver or limited redriver; 0 - limited / 1 - linear
// In linear mode the output voltage levels are directly coupled with the input voltage levels.
// In limited mode, the output voltage levels are independent of the input voltage levels. 
// VOD - Voltage swing
// EQ - Equalization control; 0 - min EQ / 15 - max EQ
prt_sta_type prt_tmds1204_cfg (prt_tentiva_ds_struct *tentiva, uint8_t slave, bool mode, uint8_t vod, uint8_t eq)
{
	// Variables
	prt_sta_type sta;
	uint8_t dat;
	uint8_t i;

    	// Reset
	sta = prt_tmds1204_wr (tentiva, slave, 0x09, 0xc1);

	// Wait for the reset to finish before configuring.
	// Everything below is lost if the device is still resetting, and the loss is silent: the last
	// write takes it out of power down and is acknowledged, so the caller sees a successful
	// configuration while none of it landed. The clock output then stays dead.
	//
	// Reading the identification back is the wait: it takes exactly as long as the device needs and
	// it proves it is answering, where a fixed delay would be a guess in both directions.
	for (i = 0; i < PRT_TMDS1204_RST_RETRY; i++)
	{
		if ((prt_tmds1204_rd (tentiva, slave, 0x08, &dat) == PRT_STA_OK) && (dat == 0x03))
			break;
	}

	if (i == PRT_TMDS1204_RST_RETRY)
		return PRT_STA_FAIL;

    	// Disable all four lanes.
	sta &= prt_tmds1204_wr (tentiva, slave, 0x11, 0x00);

    	// FANOUT enabled, Rate snoop and TXFFE snoop enabled.
	sta &= prt_tmds1204_wr (tentiva, slave, 0x0a, 0x40);

    	// 3G and 6G tx slew rate control   
	sta &= prt_tmds1204_wr (tentiva, slave, 0x0b, 0x23);

	// HDMI clock tx slew rate control
	sta &= prt_tmds1204_wr (tentiva, slave, 0x0c, 0x00);

	// Redriver mode, AC-coupled TX, 0dB DCG, Term 100R, disable CTLE bypass
	dat = 0x63;

	// Redriver mode (linear)
	if (mode)
		dat |= 0x80;
    	sta &= prt_tmds1204_wr (tentiva, slave, 0x0d, dat);
 
    	// HDMI 1.4, 2.0 and 2.1 CTLE selection
	sta &= prt_tmds1204_wr (tentiva, slave, 0x0e, 0x87);
    
    	// Clock lane VOD and TXFFE
    	dat = vod & 0x07;
    	sta &= prt_tmds1204_wr (tentiva, slave, 0x12, dat);

    	// Clock lane EQ
    	sta &= prt_tmds1204_wr (tentiva, slave, 0x13, 0x00);

    	// D0 lane VOD and TXFFE
    	dat = vod & 0x07;
    	sta &= prt_tmds1204_wr (tentiva, slave, 0x14, dat);

    	// D0 lane EQ
    	dat = eq & 0x0f;
    	sta &= prt_tmds1204_wr (tentiva, slave, 0x15, dat);

    	// D1 lane VOD and TXFFE
    	dat = vod & 0x07;
    	sta &= prt_tmds1204_wr (tentiva, slave, 0x16, dat);

    	// D1 lane EQ
    	dat = eq & 0x0f;
    	sta &= prt_tmds1204_wr (tentiva, slave, 0x17, dat);

    	// D2 lane VOD and TXFFE
    	dat = vod & 0x07;
    	sta &= prt_tmds1204_wr (tentiva, slave, 0x18, vod);

    	// D2 lane EQ
   	dat = eq & 0x0f;
    	sta &= prt_tmds1204_wr (tentiva, slave, 0x19, dat);
    
    	// Clear TMDS_CLK_RATIO
    	sta &= prt_tmds1204_wr (tentiva, slave, 0x20, 0x00);
    
    	// Disable FRL
    	sta &= prt_tmds1204_wr (tentiva, slave, 0x31, 0x00);

    	// Enable AEQ
    	sta &= prt_tmds1204_wr (tentiva, slave, 0x1e, 0x40);

    	// Enable all four lanes
    	// HDMI14_VOD = use values in VOD registers
    	// HDMI20_VOD = use values in VOD registers
    	sta &= prt_tmds1204_wr (tentiva, slave, 0x11, 0x0f);

    	// Take out of PD state. Should be done after initialization is complete.
	sta &= prt_tmds1204_wr (tentiva, slave, 0x09, 0x00);

	// Read one register back. An acknowledged write says the device answered, not that it kept the
	// value; a lane enable that reads back as written is the cheapest evidence that the sequence
	// took hold.
	sta &= prt_tmds1204_rd (tentiva, slave, 0x11, &dat);

	if (dat != 0x0f)
		return PRT_STA_FAIL;

/*
	PRBS mode

	// FANOUT disabled, Rate snoop disabled and TXFFE controlled by 35h, 41h, and 42h
	sta &= prt_tmds1204_wr (tentiva, slave, 0x0a, 0x0e);

	// Linear mode, AC-coupled TX, 0dB DCG, Term fixed at 100Ω, CTLE bypass enable
	sta &= prt_tmds1204_wr (tentiva, slave, 0x0d, 0xe4);

	// Disable all four lanes.
	sta &= prt_tmds1204_wr (tentiva, slave, 0x11, 0x00);

	// Take out of PD state. Should be done after initialization is complete.
	sta &= prt_tmds1204_wr (tentiva, slave, 0x09, 0x00);
	
	// Disable FRL
	sta &= prt_tmds1204_wr (tentiva, slave, 0x31, 0x00);

	// Enable all four lanes
	sta &= prt_tmds1204_wr (tentiva, slave, 0x11, 0x0f);
*/	

	return sta;
}

// Read register
prt_sta_type prt_tmds1204_rd (prt_tentiva_ds_struct *tentiva, uint8_t slave, uint8_t offset, uint8_t *dat)
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
	//tentiva->no_stop = PRT_TRUE;

	// Write
	sta = prt_tentiva_i2c_wr (tentiva);

	if (sta != PRT_STA_OK)
	{
		return sta;
	}

	// Length
	tentiva->i2c_len = 1;

	// Clear no stop flag
	//tentiva->no_stop = PRT_FALSE;

	// Read
	sta = prt_tentiva_i2c_rd (tentiva);

	// Copy data
	*dat = tentiva->i2c_dat[0];

	// Return status
	return sta;
}

// Write register
prt_sta_type prt_tmds1204_wr (prt_tentiva_ds_struct *tentiva, uint8_t slave, uint8_t offset, uint8_t dat)
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

