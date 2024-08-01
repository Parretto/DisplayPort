/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Kinetic MCDP6000 Driver 
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
#include "prt_mcdp6000.h"
#include "prt_printf.h"

// Initialize
prt_sta_type prt_mcdp6000_init (prt_i2c_ds_struct *i2c, uint8_t slave)
{
	// Variables
	prt_sta_type sta;

	// Revision
	sta = prt_mcdp6000_rev (i2c, slave);

	// Disable
	sta = prt_mcdp6000_dis (i2c, slave);

	// Soft reset
	sta = prt_mcdp6000_rst (i2c, slave);

	// AUX
	sta = prt_mcdp6000_aux (i2c, slave);

	// Config
	sta = prt_mcdp6000_cfg (i2c, slave);

	// DP mode
	sta = prt_mcdp6000_dp_mode (i2c, slave);

	return sta;
}

// Disable mode
prt_sta_type prt_mcdp6000_dis (prt_i2c_ds_struct *i2c, uint8_t slave)
{
	// Variables
	prt_sta_type sta;
	
	sta = prt_mcdp6000_wr (i2c, slave, 0x0504, 0x0001700E);

	// Return status
	return sta;
}

// Soft reset
prt_sta_type prt_mcdp6000_rst (prt_i2c_ds_struct *i2c, uint8_t slave)
{
	// Variables
	prt_sta_type sta;
	
	sta = prt_mcdp6000_wr (i2c, slave, 0x0504, 0x0001715E);
	sta = prt_mcdp6000_wr (i2c, slave, 0x0504, 0x0001705E);

	// Return status
	return sta;
}

// AUX
// Enable AUX communication
prt_sta_type prt_mcdp6000_aux (prt_i2c_ds_struct *i2c, uint8_t slave)
{
	// Variables
	prt_sta_type sta;

	sta = prt_mcdp6000_wr (i2c, slave, 0x0350, 0x00000010);
	sta = prt_mcdp6000_wr (i2c, slave, 0x2614, 0x19890F0F);

	// Return status
	return sta;
}

// Configuration
prt_sta_type prt_mcdp6000_cfg (prt_i2c_ds_struct *i2c, uint8_t slave)
{
	// Variables
	prt_sta_type sta;

	sta = prt_mcdp6000_wr (i2c, slave, 0x024c, 0x22221A50);
	sta = prt_mcdp6000_wr (i2c, slave, 0x0908, 0x00000866);
	sta = prt_mcdp6000_wr (i2c, slave, 0x090C, 0x04020000);
	sta = prt_mcdp6000_wr (i2c, slave, 0x2340, 0x00000500);
	sta = prt_mcdp6000_wr (i2c, slave, 0x2540, 0x00000500);
	
	// Return status
	return sta;
}

// DP mode
prt_sta_type prt_mcdp6000_dp_mode (prt_i2c_ds_struct *i2c, uint8_t slave)
{
	// Variables
	prt_sta_type sta;

	sta = prt_mcdp6000_wr (i2c, slave, 0x01D8, 0x00000601);
	sta = prt_mcdp6000_wr (i2c, slave, 0x0660, 0x00005011);
	sta = prt_mcdp6000_wr (i2c, slave, 0x067C, 0x00000001);

	// Return status
	return sta;
}

// Set pseudo transparent mode
prt_sta_type prt_mcdp6000_trans (prt_i2c_ds_struct *i2c, uint8_t slave)
{
	// Variables
	prt_sta_type sta;

	sta = prt_mcdp6000_wr (i2c, slave, 0x0908, 0x00000466);

	// Return status
	return sta;
}

// Force TX parameters
// This function sets the TX voltage and pre-emphasis levels
prt_sta_type prt_mcdp6000_tx_force (prt_i2c_ds_struct *i2c, uint8_t slave, uint8_t volt, uint8_t pre)
{
	// Variables
	prt_sta_type sta;
	uint32_t dat;

	// Read register
	sta = prt_mcdp6000_rd (i2c, slave, 0x0904, &dat);

	// Mask out bits 
	dat &= 0xff0000ff;

	// TX Voltage swing LN0
	dat |= (volt << 8);

	// TX Voltage swing LN1
	dat |= (volt << 12);

	// TX Voltage swing LN2
	dat |= (volt << 16);

	// TX Voltage swing LN3
	dat |= (volt << 20);

	// TX pre-emphasis LN0
	dat |= (pre << 10);

	// TX pre-emphasis LN1
	dat |= (pre << 14);

	// TX pre-emphasis LN2
	dat |= (pre << 18);

	// TX pre-emphasis LN3
	dat |= (pre << 22);

	// Write register
	sta = prt_mcdp6000_wr (i2c, slave, 0x0904, dat);

	// Return status
	return sta;
}

// Revision
prt_sta_type prt_mcdp6000_rev (prt_i2c_ds_struct *i2c, uint8_t slave)
{
	// Variables
	prt_sta_type sta;
	uint32_t dat;
	uint8_t rev;
	uint8_t cfg;

	// Read register
	sta = prt_mcdp6000_rd (i2c, slave, 0x510, &dat);

	rev = (dat >> 8) & 0xff;
	cfg = dat & 0x1c;

	prt_printf ("MCDP6000 | Revision: ");
	if (rev == 0x32)
		prt_printf ("C1");
	else
		prt_printf ("Unknown (%x)", rev);

	prt_printf (" | Config: %x\n", cfg);

	// Return status
	return sta;
}

// Reset CR path 
// This function resets the CR path. 
// It is called at the start of the clock recovery training
prt_sta_type prt_mcdp6000_rst_cr (prt_i2c_ds_struct *i2c, uint8_t slave)
{
	// Variables
	prt_sta_type sta;
	uint32_t dat;

	// Read register
	sta = prt_mcdp6000_rd (i2c, slave, 0x150, &dat);

	// Set reset bit
	dat |= (1 << 15);

	// Write register
	sta = prt_mcdp6000_wr (i2c, slave, 0x150, dat);

	// Clear reset bit
	dat &= ~(1 << 15);

	// Write register
	sta = prt_mcdp6000_wr (i2c, slave, 0x150, dat);

	// Return status
	return sta;
}

// Read register
prt_sta_type prt_mcdp6000_rd (prt_i2c_ds_struct *i2c, uint8_t slave, uint16_t offset, uint32_t *dat)
{
	// Variables
	prt_sta_type sta;

	// Slave
	i2c->slave = slave;
	
	// Offset LSB
	i2c->dat[0] = offset & 0xff;

	// Offset MSB
	i2c->dat[1] = offset >> 8;

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
	i2c->len = 4;

	// Clear no stop flag
	i2c->no_stop = PRT_FALSE;

	// Read
	sta = prt_i2c_rd (i2c);

	// Copy data
	*dat = i2c->dat[0];
	*dat |= (i2c->dat[1] << 8);
	*dat |= (i2c->dat[2] << 16);
	*dat |= (i2c->dat[3] << 24);

	// Return status
	return sta;
}

// Write register
prt_sta_type prt_mcdp6000_wr (prt_i2c_ds_struct *i2c, uint8_t slave, uint16_t offset, uint32_t dat)
{
	// Variables
	prt_sta_type sta;

	// Slave
	i2c->slave = slave;

	// Offset LSB
	i2c->dat[0] = offset & 0xff;

	// Offset MSB
	i2c->dat[1] = offset >> 8;
	
	// Data 1
	i2c->dat[2] = dat & 0xff;

	// Data 2
	i2c->dat[3] = (dat >> 8) & 0xff;

	// Data 3
	i2c->dat[4] = (dat >> 16) & 0xff;

	// Data 4
	i2c->dat[5] = (dat >> 24) & 0xff;

	// Length
	i2c->len = 6;

	// Write
	sta = prt_i2c_wr (i2c);

	// Return
	return sta;
}

// Dump register
void prt_mcdp6000_dump (prt_i2c_ds_struct *i2c, uint8_t slave, uint16_t offset)
{
	// Variables
	prt_sta_type sta;
	uint32_t dat;

	// Read register
	sta = prt_mcdp6000_rd (i2c, slave, offset, &dat);

	prt_printf ("MCDP6000: offset: %x - data: %x\n", offset, dat);
}

