/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Timer Periperhal Header
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

#pragma once

// Device structure
typedef struct {
  prt_u32 ctl;    // Control
  prt_u32 sta;    // Status
  prt_u32 tmr;    // Timer
  prt_u32 alrm0;   // Alarm 0 
  prt_u32 alrm1;   // Alarm 1
} prt_tmr_dev_struct;

// Data structure
typedef struct tmr_ds_struct {
  volatile prt_tmr_dev_struct *dev;
} prt_tmr_ds_struct;

// Control register bits
#define PRT_TMR_DEV_CTL_RUN     (1 << 0)
#define PRT_TMR_DEV_CTL_IE      (1 << 1)
#define PRT_TMR_DEV_CTL_ALRM0   (1 << 2)
#define PRT_TMR_DEV_CTL_ALRM1   (1 << 3)

// Status register bits
#define PRT_TMR_DEV_STA_IRQ     (1 << 0)
#define PRT_TMR_DEV_STA_ALRM0   (1 << 1)
#define PRT_TMR_DEV_STA_ALRM1   (1 << 2)
#define PRT_TMR_DEV_STA_HB      (1 << 3)

// Prototypes
void prt_tmr_init (prt_tmr_ds_struct *tmr, prt_u32 base);
void prt_tmr_sleep (prt_tmr_ds_struct *tmr, prt_u8 alrm, prt_u32 us);
void prt_tmr_set_alrm (prt_tmr_ds_struct *tmr, prt_u8 alrm, prt_u32 us);
prt_bool prt_tmr_is_alrm (prt_tmr_ds_struct *tmr, prt_u8 alrm);
