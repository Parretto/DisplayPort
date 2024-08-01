/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: TI TDP2004 Header
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

#pragma once

// Prototypes
prt_sta_type prt_tdp2004_init (prt_i2c_ds_struct *i2c, uint8_t slave);
prt_sta_type prt_tdp2004_id (prt_i2c_ds_struct *i2c, uint8_t slave);
prt_sta_type prt_tdp2004_run (prt_i2c_ds_struct *i2c, uint8_t slave);
prt_sta_type prt_tdp2004_rd (prt_i2c_ds_struct *i2c, uint8_t slave, uint8_t offset, uint8_t *dat);
prt_sta_type prt_tdp2004_wr (prt_i2c_ds_struct *i2c, uint8_t slave, uint8_t offset, uint8_t dat);
