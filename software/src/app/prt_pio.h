/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP Application 
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

#pragma once

// Device structure
typedef struct {
  uint32_t id;         // ID
  uint32_t ctl;        // Control
  uint32_t sta;        // Status register
  uint32_t din;        // Data in
  uint32_t evt_re;     // Event rising edge
  uint32_t evt_fe;     // Event falling edge
  uint32_t dout_set;   // Data out set
  uint32_t dout_clr;   // Data out clear
  uint32_t dout_tgl;   // Data out toggle
  uint32_t dout;       // Data out
  uint32_t msk;        // Mask
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
void prt_pio_init (prt_pio_ds_struct *pio, uint32_t base);
void prt_pio_dat_set (prt_pio_ds_struct *pio, uint32_t dat);
void prt_pio_dat_clr (prt_pio_ds_struct *pio, uint32_t dat);
void prt_pio_dat_tgl (prt_pio_ds_struct *pio, uint32_t dat);
void prt_pio_dat_msk (prt_pio_ds_struct *pio, uint32_t dat, uint32_t msk);
void prt_pio_re_set (prt_pio_ds_struct *pio, uint32_t re);
uint32_t prt_pio_re_get (prt_pio_ds_struct *pio, uint32_t re);
uint32_t prt_pio_dat_get (prt_pio_ds_struct *pio);
prt_bool prt_pio_tst_bit (prt_pio_ds_struct *pio, uint32_t dat);

