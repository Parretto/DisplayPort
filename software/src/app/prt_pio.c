/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: PIO Peripheral Driver
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
#include "prt_pio.h"

// Initialize
void prt_pio_init (prt_pio_ds_struct *pio, uint32_t base)
{
	// Base address
	pio->dev = (prt_pio_dev_struct *) base;
	
	// Start device
	pio->dev->ctl = PRT_PIO_DEV_CTL_RUN;
}

//  Data set
void prt_pio_dat_set (prt_pio_ds_struct *pio, uint32_t dat)
{
	pio->dev->dout_set = dat;
}

// Data clear
void prt_pio_dat_clr (prt_pio_ds_struct *pio, uint32_t dat)
{
	pio->dev->dout_clr = dat;
}

// Data toggle
void prt_pio_dat_tgl (prt_pio_ds_struct *pio, uint32_t dat)
{
	pio->dev->dout_tgl = dat;
}

// Data mask
void prt_pio_dat_msk (prt_pio_ds_struct *pio, uint32_t dat, uint32_t msk)
{
	pio->dev->msk = msk;
	pio->dev->dout = dat;
}

void prt_pio_re_set (prt_pio_ds_struct *pio, uint32_t re)
{
	// Variables
	uint32_t dat;

	dat = pio->dev->ctl;
	dat |= (re << PRT_PIO_DEV_CTL_EVT_RE_SHIFT);
	pio->dev->ctl = dat;
}

uint32_t prt_pio_re_get (prt_pio_ds_struct *pio, uint32_t re)
{
	// Variables
	uint32_t sta;

  	// Is the bit set in the rising edge register
  	if (pio->dev->evt_re & re)
  		sta = PRT_TRUE;
  	else
  		sta = PRT_FALSE;

  	return sta;
}

// Get data
uint32_t prt_pio_dat_get (prt_pio_ds_struct *pio)
{
  return pio->dev->din;
}

// Test bit
prt_bool prt_pio_tst_bit (prt_pio_ds_struct *pio, uint32_t dat)
{
	prt_bool sta;

	if (pio->dev->din & dat)
		sta = PRT_TRUE;
	else
		sta = PRT_FALSE;

	return sta;
}
