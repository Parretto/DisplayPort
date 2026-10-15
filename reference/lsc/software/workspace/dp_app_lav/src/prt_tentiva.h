/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Tentiva Header
    (c) 2021 - 2025 by Parretto B.V.

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

// Includes 
#include <stdbool.h>
#include "prt_types.h"

// Typedef callback
typedef prt_sta_type (*i2c_cb)(uint8_t slave, uint8_t *dat, uint8_t len);

// Data structure
typedef struct {
    // Hardware identification
    uint8_t fmc_id;         // FMC board ID
    uint8_t slot_id[2];     // PHY slot ID
   
    // Frequency
	uint32_t phy_freq;		// PHY clock frequency (in kHz)
	uint32_t vid_freq;		// Video clock frequency (in kHz)

    // I2C
    uint8_t i2c_slave;
    uint8_t i2c_dat[16];
    uint8_t i2c_len;

    // Callbacks
    i2c_cb i2c_wr_cb;
    i2c_cb i2c_rd_cb;
} prt_tentiva_ds_struct;

// Defines
#define PRT_TENTIVA_I2C_SC_ADR		          	0x4d
#define PRT_TENTIVA_I2C_RC22504A_ADR			0x09
#define PRT_TENTIVA_I2C_BASE_EEPROM_ADR			0x50
#define PRT_TENTIVA_I2C_MCDP6150_SLOT0_ADR		0x15
#define PRT_TENTIVA_I2C_MCDP6150_SLOT1_ADR		0x14
#define PRT_TENTIVA_I2C_MCDP6000_SLOT0_ADR		0x14
#define PRT_TENTIVA_I2C_MCDP6000_SLOT1_ADR		0x14
#define PRT_TENTIVA_I2C_TDP142_SLOT0_ADR		0x44
#define PRT_TENTIVA_I2C_TDP142_SLOT1_ADR		0x47
#define PRT_TENTIVA_I2C_EEPROM_SLOT0_ADR		0x53
#define PRT_TENTIVA_I2C_EEPROM_SLOT1_ADR		0x57
#define PRT_TENTIVA_I2C_TDP2004_SLOT0_ADR		0x1a
#define PRT_TENTIVA_I2C_TDP2004_SLOT1_ADR		0x18
#define PRT_TENTIVA_I2C_TDP1204_SLOT0_ADR		0x5d
#define PRT_TENTIVA_I2C_TDP1204_SLOT1_ADR		0x5e
#define PRT_TENTIVA_I2C_TMDS1204_SLOT0_ADR		0x5b
#define PRT_TENTIVA_I2C_TMDS1204_SLOT1_ADR		0x5c
#define PRT_TENTIVA_I2C_PS8483_SLOT0_ADR		0x10
#define PRT_TENTIVA_I2C_PS8483_SLOT1_ADR		0x20

#define PRT_TENTIVA_EMPTY_ID					0x00
#define PRT_TENTIVA_FMC_REVC_ID				    0x22
#define PRT_TENTIVA_FMC_REVD_ID				    0x23
#define PRT_TENTIVA_FMC_REVE_ID                 0x24
#define PRT_TENTIVA_DP14TX_ID				    0x78
#define PRT_TENTIVA_DP14RX_ID				    0x45
#define PRT_TENTIVA_EDPTX_ID					0x94
#define PRT_TENTIVA_DP21TX_ID				    0x79
#define PRT_TENTIVA_DP21RX_ID				    0x46
#define PRT_TENTIVA_DPPASSRX_ID				    0x54
#define PRT_TENTIVA_HDMI21TX_ID					0x63
#define PRT_TENTIVA_HDMI21RX_ID					0x51

#define PRT_TENTIVA_LOCK_TIMEOUT				10000 	// 10 ms
#define PRT_TENTIVA_LOCK_TRIES					5000	// Status reads before a lock times out

#define PRT_TENTIVA_SC_VER                      0
#define PRT_TENTIVA_SC_CTL                      1
#define PRT_TENTIVA_SC_STA                      2
#define PRT_TENTIVA_SC_PHY_CLK                  3
#define PRT_TENTIVA_SC_VID_CLK                  4
#define PRT_TENTIVA_SC_DCO                      5
#define PRT_TENTIVA_SC_CTL_MZ_CLK_SEL           (1 << 0)
#define PRT_TENTIVA_SC_CTL_GT_REF_CLK_SEL       (1 << 1)
#define PRT_TENTIVA_SC_STA_PHY_CLK_LOCK         (1 << 0)
#define PRT_TENTIVA_SC_STA_VID_CLK_LOCK         (1 << 1)

// Prototypes
void prt_tentiva_init (prt_tentiva_ds_struct *tentiva, void *i2c_wr_cb, void *i2c_rd_cb);
void prt_tentiva_scan (prt_tentiva_ds_struct *tentiva);
uint8_t prt_tentiva_get_fmc_id (prt_tentiva_ds_struct *tentiva);
bool prt_tentiva_has_sc (prt_tentiva_ds_struct *tentiva);
uint8_t prt_tentiva_get_slot_id (prt_tentiva_ds_struct *tentiva, uint8_t slot);
void prt_tentiva_force_slot_id (prt_tentiva_ds_struct *tentiva, uint8_t slot, uint8_t id);
prt_sta_type prt_tentiva_cfg (prt_tentiva_ds_struct *tentiva, prt_bool ingore_err);
prt_sta_type prt_tentiva_set_phy_freq (prt_tentiva_ds_struct *tentiva, uint32_t freq);
prt_sta_type prt_tentiva_set_vid_freq (prt_tentiva_ds_struct *tentiva, uint32_t freq);
prt_sta_type prt_tentiva_get_lock (prt_tentiva_ds_struct *tentiva, uint32_t lock);
void prt_tentiva_id_wr (prt_tentiva_ds_struct *tentiva, uint8_t id);
void prt_tentiva_id_rd (prt_tentiva_ds_struct *tentiva);
prt_sta_type prt_tentiva_eeprom_wr (prt_tentiva_ds_struct *tentiva, uint8_t slave, uint8_t id);
prt_sta_type prt_tentiva_eeprom_rd (prt_tentiva_ds_struct *tentiva, uint8_t slave);
prt_sta_type prt_tentiva_i2c_wr (prt_tentiva_ds_struct *tentiva);
prt_sta_type prt_tentiva_i2c_rd (prt_tentiva_ds_struct *tentiva);

// System controller
uint8_t prt_tentiva_sc_ver (prt_tentiva_ds_struct *tentiva);
uint8_t prt_tentiva_sc_sta (prt_tentiva_ds_struct *tentiva);
prt_sta_type prt_tentiva_sc_sta_rd (prt_tentiva_ds_struct *tentiva, uint8_t dat);
prt_sta_type prt_tentiva_sc_reg_wr (prt_tentiva_ds_struct *tentiva, uint8_t slave, uint8_t adr, uint32_t dat);
prt_sta_type prt_tentiva_sc_reg_rd (prt_tentiva_ds_struct *tentiva, uint8_t slave, uint8_t adr, uint8_t *dat);
prt_sta_type prt_tentiva_sc_mz_clk_sel (prt_tentiva_ds_struct *tentiva, uint8_t mz);
prt_sta_type prt_tentiva_sc_gt_clk_mode (prt_tentiva_ds_struct *tentiva, bool pass);
prt_sta_type prt_tentiva_sc_dco (prt_tentiva_ds_struct *tentiva, uint32_t dat);

// TMDS1204
void prt_tentiva_tmds1204_cfg (prt_tentiva_ds_struct *tentiva, bool mode, uint8_t vod, uint8_t eq);

// TDP1204
void prt_tentiva_tdp1204_dump (prt_tentiva_ds_struct *tentiva);
void prt_tentiva_tdp1204_wr (prt_tentiva_ds_struct *tentiva, uint8_t offset, uint8_t dat);

