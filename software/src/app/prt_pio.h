/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP Application 
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

#pragma once

// Device structure
typedef struct {
  prt_u32 id;         // ID
  prt_u32 ctl;        // Control
  prt_u32 sta;        // Status register
  prt_u32 din;        // Data in
  prt_u32 evt_re;     // Event rising edge
  prt_u32 evt_fe;     // Event falling edge
  prt_u32 dout_set;   // Data out set
  prt_u32 dout_clr;   // Data out clear
  prt_u32 dout_tgl;   // Data out toggle
  prt_u32 dout;       // Data out
  prt_u32 msk;        // Mask
} prt_pio_dev_struct;

// Data structure
typedef struct {
  volatile prt_pio_dev_struct *dev;
} prt_pio_ds_struct;

// Defines
#define PRT_PIO_DEV_CTL_RUN                   (1 << 0)
#define PRT_PIO_DEV_CTL_EVT_RE_SHIFT          (2)
#define PRT_PIO_DEV_CTL_EVT_FE_SHIFT          (2 + 8)

// Prototypes
void prt_pio_init (prt_pio_ds_struct *pio, prt_u32 base);
void prt_pio_dat_set (prt_pio_ds_struct *pio, prt_u32 dat);
void prt_pio_dat_clr (prt_pio_ds_struct *pio, prt_u32 dat);
void prt_pio_dat_tgl (prt_pio_ds_struct *pio, prt_u32 dat);
void prt_pio_dat_msk (prt_pio_ds_struct *pio, prt_u32 dat, prt_u32 msk);
void prt_pio_re_set (prt_pio_ds_struct *pio, prt_u32 re);
prt_u32 prt_pio_re_get (prt_pio_ds_struct *pio, prt_u32 re);
prt_u32 prt_pio_dat_get (prt_pio_ds_struct *pio);
prt_bool pio_tst_bit (prt_pio_ds_struct *pio, prt_u32 dat);

