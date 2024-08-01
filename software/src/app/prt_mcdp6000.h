/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Kinetic MCDP6000 Header 
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

// Defines

// Prototypes
prt_sta_type prt_mcdp6000_init (prt_i2c_ds_struct *i2c, uint8_t slave);
prt_sta_type prt_mcdp6000_rev (prt_i2c_ds_struct *i2c, uint8_t slave);
prt_sta_type prt_mcdp6000_rst (prt_i2c_ds_struct *i2c, uint8_t slave);
prt_sta_type prt_mcdp6000_dis (prt_i2c_ds_struct *i2c, uint8_t slave);
prt_sta_type prt_mcdp6000_aux (prt_i2c_ds_struct *i2c, uint8_t slave);
prt_sta_type prt_mcdp6000_cfg (prt_i2c_ds_struct *i2c, uint8_t slave);
prt_sta_type prt_mcdp6000_dp_mode (prt_i2c_ds_struct *i2c, uint8_t slave);
prt_sta_type prt_mcdp6000_trans (prt_i2c_ds_struct *i2c, uint8_t slave);
prt_sta_type prt_mcdp6000_tx_force (prt_i2c_ds_struct *i2c, uint8_t slave, uint8_t volt, uint8_t pre);
prt_sta_type prt_mcdp6000_rd (prt_i2c_ds_struct *i2c, uint8_t slave, uint16_t offset, uint32_t *dat);
prt_sta_type prt_mcdp6000_wr (prt_i2c_ds_struct *i2c, uint8_t slave, uint16_t offset, uint32_t dat);
void prt_mcdp6000_dump (prt_i2c_ds_struct *i2c, uint8_t slave, uint16_t offset);
prt_sta_type prt_mcdp6000_rst_cr (prt_i2c_ds_struct *i2c, uint8_t slave);
