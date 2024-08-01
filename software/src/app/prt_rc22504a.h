/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Renesas RC22504a Header
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

// Structures
typedef struct {
	uint32_t offset;
	uint8_t value;
} prt_rc22504a_reg_struct;

// Defines
#define PRT_RC22504A_PAGE_REG				(0xFD)
#define PRT_RC22504A_DEVICE_ID			    (0x00 + 0x02)
#define PRT_RC22504A_DEV_RESET			    (0x00 + 0x0A)
#define PRT_RC22504A_SSI_GLOBAL_CNFG		(0x140 + 0x04)
#define PRT_RC22504A_MISC_WRITE_FREQ		(0xA0 + 0x28)

#define PRT_RC22504A_DEV_RESET_APLL_REINT	(1 << 0)
#define PRT_RC22504A_ODRV_EN_OUT_DIS		(1 << 1)

// Prototypes
prt_sta_type prt_rc22504a_set_adr_mode (prt_i2c_ds_struct *i2c, uint8_t slave);
prt_sta_type prt_rc22504a_rd (prt_i2c_ds_struct *i2c, uint8_t slave, uint16_t offset, uint8_t *dat);
prt_sta_type prt_rc22504a_wr (prt_i2c_ds_struct *i2c, uint8_t slave, uint16_t offset, uint8_t dat);
prt_sta_type prt_rc22504a_cfg (prt_i2c_ds_struct *i2c, uint8_t slave, uint16_t length, prt_rc22504a_reg_struct *config);
prt_sta_type prt_rc22504a_out_drv (prt_i2c_ds_struct *i2c, uint8_t slave, uint8_t out, uint8_t en);
prt_sta_type prt_rc22504a_out_div (prt_i2c_ds_struct *i2c, uint8_t slave, uint8_t out, uint16_t div);
prt_sta_type prt_rc22504a_dco (prt_i2c_ds_struct *i2c, uint8_t slave, uint32_t val);
