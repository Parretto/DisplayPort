/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: I2C Peripheral Header
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

// Includes
#include <stdbool.h>

// Device structure
typedef struct {
  uint32_t ctl; 			  // Control
  uint32_t sta; 			  // Status
  uint32_t beat; 		  // Beat
  uint32_t wr_dat; 		// Write data
  uint32_t rd_dat; 		// Read data
} prt_i2c_dev_struct;

// Data structure
typedef struct {
  volatile  prt_i2c_dev_struct *dev;
  uint8_t   slave;
  uint8_t   dat[16];
  uint8_t   len;
  bool      no_stop;
} prt_i2c_ds_struct;

// Defines
#define PRT_I2C_CTL_RUN 	    (1<<0)
#define PRT_I2C_CTL_STR 	    (1<<1)
#define PRT_I2C_CTL_STP 	    (1<<2)
#define PRT_I2C_CTL_WR 		    (1<<3)
#define PRT_I2C_CTL_RD 		    (1<<4)
#define PRT_I2C_CTL_ACK 	    (1<<5)
#define PRT_I2C_CTL_DIA       (1<<6)
#define PRT_I2C_CTL_TENTIVA   (1<<7)

#define PRT_I2C_STA_BUSY	    (1<<0)
#define PRT_I2C_STA_RDY 	    (1<<1)
#define PRT_I2C_STA_ACK 	    (1<<2)
#define PRT_I2C_STA_BUS       (1<<3)

// Prototypes
void prt_i2c_init (prt_i2c_ds_struct *i2c, uint32_t base, uint32_t beat);
prt_sta_type prt_i2c_wr (prt_i2c_ds_struct *i2c);
prt_sta_type prt_i2c_rd (prt_i2c_ds_struct *i2c);
prt_sta_type prt_i2c_dia (prt_i2c_ds_struct *i2c, bool dia, bool tentiva);
