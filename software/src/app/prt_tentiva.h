/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Tentiva Header
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

// Data structure
typedef struct {
	prt_pio_ds_struct *pio;		                    // PIO
	prt_i2c_ds_struct *i2c;		                    // I2C
	prt_tmr_ds_struct *tmr;                         // Timer
	prt_u8 phy_freq;			                    // PHY frequency
    prt_rc22504a_reg_struct *phy_clk_cfg_prt[2];    // PHY clock configuration pointer
    prt_u16 phy_clk_cfg_len;                        // PHY clock configuration length
    prt_rc22504a_reg_struct *vid_clk_cfg_prt[2];    // Video clock configuration pointer
    prt_u16 vid_clk_cfg_len;                        // Video clock configuration length
    prt_u32 pio_phy_refclk_lock;                    // PIO PHY reference clock lock
    prt_u32 pio_vid_refclk_lock;                    // PIO VID reference clock lock
    prt_u32 pio_clk_sel;                            // PIO clock select
    prt_u8 phy_clk_cfg;                             // Active phy clock configuration
    prt_u8 vid_clk_cfg;                             // Active video clock configuration
} prt_tentiva_ds_struct;

// Defines
#define PRT_TENTIVA_PHY_DEV					    0
#define PRT_TENTIVA_VID_DEV					    1

#define PRT_TENTIVA_PHY_FREQ_81_MHZ			    0
#define PRT_TENTIVA_PHY_FREQ_135_MHZ			1
#define PRT_TENTIVA_PHY_FREQ_202_5_MHZ			2
#define PRT_TENTIVA_PHY_FREQ_270_MHZ			3

#define PRT_TENTIVA_VID_FREQ_185625_MHZ			0
#define PRT_TENTIVA_VID_FREQ_37125_MHZ			1
#define PRT_TENTIVA_VID_FREQ_7425_MHZ			2
#define PRT_TENTIVA_VID_FREQ_1485_MHZ			3
#define PRT_TENTIVA_VID_FREQ_297_MHZ			4
#define PRT_TENTIVA_VID_FREQ_254974_MHZ         5

#define PRT_TENTIVA_I2C_RC22504A_ADR			0x09
#define PRT_TENTIVA_I2C_BASE_EEPROM_ADR			0x50
#define PRT_TENTIVA_I2C_MC6150_SLOT0_ADR		0x15
#define PRT_TENTIVA_I2C_MC6150_SLOT1_ADR		0x14
#define PRT_TENTIVA_I2C_TDP142_SLOT0_ADR		0x44
#define PRT_TENTIVA_I2C_TDP142_SLOT1_ADR		0x47
#define PRT_TENTIVA_I2C_EEPROM_SLOT0_ADR		0x53
#define PRT_TENTIVA_I2C_EEPROM_SLOT1_ADR		0x57

#define PRT_TENTIVA_BASE_ID					    0x22
#define PRT_TENTIVA_DPTX_ID					    0x78
#define PRT_TENTIVA_DPRX_ID					    0x45
#define PRT_TENTIVA_EDPTX_ID					0x94
#define PRT_TENTIVA_HDMITX_ID					0x34

#define PRT_TENTIVA_LOCK_TIMEOUT				10000 	// 10 ms

// Prototypes
void prt_tentiva_init (prt_tentiva_ds_struct *tentiva, prt_pio_ds_struct *pio, prt_i2c_ds_struct *i2c, prt_tmr_ds_struct *tmr, 
    prt_u32 pio_phy_refclk_lock, prt_u32 pio_vid_refclk_lock, prt_u32 pio_clk_sel);
void prt_tentiva_set_clk_cfg (prt_tentiva_ds_struct *tentiva, prt_u8 dev, prt_u8 cfg, prt_rc22504a_reg_struct *prt, prt_u16 len);
void prt_tentiva_scan (prt_tentiva_ds_struct *tentiva);
prt_sta_type prt_tentiva_cfg (prt_tentiva_ds_struct *tentiva, prt_bool ingore_err);
prt_sta_type prt_tentiva_clk_cfg (prt_tentiva_ds_struct *tentiva, prt_u8 dev, prt_u16 clk_cfg_len, prt_rc22504a_reg_struct *clk_cfg_prt, prt_u32 pio_phy_lock);
void prt_tentiva_sel_dev (prt_tentiva_ds_struct *tentiva, prt_u8 dev);
prt_sta_type prt_tentiva_phy_cfg (prt_tentiva_ds_struct *tentiva);
prt_sta_type prt_tentiva_set_phy_freq (prt_tentiva_ds_struct *tentiva, prt_u8 ref, prt_u8 freq);
prt_sta_type prt_tentiva_set_vid_freq (prt_tentiva_ds_struct *tentiva, prt_u8 freq);
prt_sta_type prt_tentiva_get_lock (prt_tentiva_ds_struct *tentiva, prt_u32 lock);
void prt_tentiva_id_wr (prt_tentiva_ds_struct *tentiva, prt_u8 id);
void prt_tentiva_id_rd (prt_tentiva_ds_struct *tentiva);
prt_sta_type prt_tentiva_eeprom_wr (prt_i2c_ds_struct *i2c, prt_u8 slave, prt_u8 id);
prt_sta_type prt_tentiva_eeprom_rd (prt_i2c_ds_struct *i2c, prt_u8 slave);
void prt_tentiva_tst (prt_tentiva_ds_struct *tentiva);

// TDP142
void prt_tentiva_tdp142_snoop_dis (prt_tentiva_ds_struct *tentiva);
void prt_tentiva_tdp142_dump (prt_tentiva_ds_struct *tentiva);

// MCDP6150
