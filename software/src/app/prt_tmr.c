/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Timer Peripheral Driver
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
#include "prt_types.h"
#include "prt_tmr.h"
#include "prt_printf.h"

/*
  Init
*/
void prt_tmr_init (prt_tmr_ds_struct *tmr, prt_u32 base)
{
  // Base address
  tmr->dev = (prt_tmr_dev_struct *) base;

  // Start device
  tmr->dev->ctl = PRT_TMR_DEV_CTL_RUN;  
}

/*
  Sleep
  Load the alarm in us
  This function is blocking
*/
void prt_tmr_sleep (prt_tmr_ds_struct *tmr, prt_u8 alrm, prt_u32 us)
{
  // Set alarm 
  prt_tmr_set_alrm (tmr, alrm, us);

  // Wait for alarm 
  while (!prt_tmr_is_alrm (tmr, alrm));
}

/*
  Set alarm
  Load the alarm in us
  This function is not blocking
*/
void prt_tmr_set_alrm (prt_tmr_ds_struct *tmr, prt_u8 alrm, prt_u32 us)
{
  // Variables
  prt_u32 dat;
  prt_u32 ctl;
  prt_u32 sta;

  // Alarm 0
  if (alrm == 0)
  {
    // Set alarm
    tmr->dev->alrm0 = us;
    
    // Set control flag
    ctl = PRT_TMR_DEV_CTL_ALRM0;

    // Set status flag
    sta = PRT_TMR_DEV_STA_ALRM0;
  }

  // Alarm 1
  else
  {
    // Set alarm
    tmr->dev->alrm1 = us;

    // Set control flag
    ctl = PRT_TMR_DEV_CTL_ALRM1;

    // Set status flag
    sta = PRT_TMR_DEV_STA_ALRM1;
  }

  // Enable alarm
  dat = tmr->dev->ctl;
  dat |= ctl; 
  tmr->dev->ctl = dat; 

  // Clear status
  tmr->dev->sta = sta;
}

/*
  This function returns true when the alarm has been triggered
*/
prt_bool prt_tmr_is_alrm (prt_tmr_ds_struct *tmr, prt_u8 alrm)
{
  // Variables
  prt_u32 sta;
  prt_u32 msk;

  // Read status
  sta = tmr->dev->sta;

  // Mask
  if (alrm == 0)
  {
    msk = PRT_TMR_DEV_STA_ALRM0;
  }

  else
  {
    msk = PRT_TMR_DEV_STA_ALRM1;  
  }

  if (sta & msk)
  {
    return PRT_TRUE;
  }

  else
  {
    return PRT_FALSE;
  }
}

