/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Kinetic MCDP6150 Header 
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

// Defines
#define PRT_MCDP6150_TX_GC_CTRL_1                      0x24c
#define PRT_MCDP6150_IC_RT_CONFIG		               0x30c
#define PRT_MCDP6150_DP_RT_CONFIG		               0x350
#define PRT_MCDP6150_OPMODE_CONF		               0x504
#define PRT_MCDP6150_IC_REV			                   0x510
#define PRT_MCDP6150_DP_LT_STATUS		               0x62c
#define PRT_MCDP6150_DPCD_SNOOP_0		               0x700
#define PRT_MCDP6150_DPCD_SNOOP_7		               0x750
#define PRT_MCDP6150_LT_CONFIG_0                       0x900
#define PRT_MCDP6150_LT_CONFIG_1                       0x904
#define PRT_MCDP6150_LT_CONFIG_2                       0x908
#define PRT_MCDP6150_LT_CONFIG_4                       0x910
#define PRT_MCDP6150_LT_CONFIG_5                       0x914
#define PRT_MCDP6150_LT_CONFIG_6                       0x918
#define PRT_MCDP6150_LT_CONFIG_7                       0x91C
#define PRT_MCDP6150_LT_CONFIG_B                       0x92C
#define PRT_MCDP6150_DPCD_LTTPR_CAP_ID_0               0xA00
#define PRT_MCDP6150_DPCD_LTTPR_CAP_ID_1               0xA04
#define PRT_MCDP6150_ADJ_SWING_REG_LN0_SHIFT           0
#define PRT_MCDP6150_ADJ_SWING_REG_LN1_SHIFT           2
#define PRT_MCDP6150_ADJ_SWING_REG_LN2_SHIFT           8
#define PRT_MCDP6150_ADJ_SWING_REG_LN3_SHIFT           10
#define PRT_MCDP6150_ADJ_PRE_EMP_REG_LN0_SHIFT         4
#define PRT_MCDP6150_ADJ_PRE_EMP_REG_LN1_SHIFT         6
#define PRT_MCDP6150_ADJ_PRE_EMP_REG_LN2_SHIFT         12
#define PRT_MCDP6150_ADJ_PRE_EMP_REG_LN3_SHIFT         14
#define PRT_MCDP6150_LT_CONFIG_2_FORCE_TX_PARAM        (1 << 10)
#define PRT_MCDP6150_LT_CONFIG_2_FULL_TRANSPARENT_EN   (1 << 11)
#define PRT_MCDP6150_OPMODE_CONF_DIS_N_OVR_EN          (1 << 3)
#define PRT_MCDP6150_OPMODE_CONF_DIS_N                 (1 << 6)
#define PRT_MCDP6150_OPMODE_CONF_DP_SOFT_RST           (1 << 10)

// Prototypes
prt_sta_type prt_mcdp6150_init (prt_i2c_ds_struct *i2c, prt_u8 slave);
prt_sta_type prt_mcdp6150_dp_en (prt_i2c_ds_struct *i2c, prt_u8 slave, prt_u8 en);
prt_sta_type prt_mcdp6150_rst (prt_i2c_ds_struct *i2c, prt_u8 slave);
prt_sta_type prt_mcdp6150_dprx_init (prt_i2c_ds_struct *i2c, prt_u8 slave);
prt_sta_type prt_mcdp6150_gc_gain (prt_i2c_ds_struct *i2c, prt_u8 slave);
prt_sta_type prt_mcdp6150_trans_mode (prt_i2c_ds_struct *i2c, prt_u8 slave, prt_u8 pseudo);
prt_sta_type prt_mcdp6150_tx_force (prt_i2c_ds_struct *i2c, prt_u8 slave, prt_u8 volt, prt_u8 pre);
prt_sta_type prt_mcdp6150_adj_req (prt_i2c_ds_struct *i2c, prt_u8 slave);
prt_u16 prt_mcdp6150_set_adj_val (prt_u8 volt, prt_u8 pre);
prt_sta_type prt_mcdp6150_refclk_en (prt_i2c_ds_struct *i2c, prt_u8 slave);
prt_sta_type prt_mcdp6150_lttpr_mode (prt_i2c_ds_struct *i2c, prt_u8 slave, prt_u8 en);
prt_sta_type prt_mcdp6150_prbs7 (prt_i2c_ds_struct *i2c, prt_u8 slave);
prt_sta_type prt_mcdp6150_set_rate (prt_i2c_ds_struct *i2c, prt_u8 slave, prt_u8 rate);
prt_sta_type prt_mcdp6150_set_vap (prt_i2c_ds_struct *i2c, prt_u8 slave, prt_u8 volt, prt_u8 pre);
prt_sta_type prt_mcdp6150_rd (prt_i2c_ds_struct *i2c, prt_u8 slave, prt_u16 offset, prt_u32 *dat);
prt_sta_type prt_mcdp6150_wr (prt_i2c_ds_struct *i2c, prt_u8 slave, prt_u16 offset, prt_u32 dat);
void prt_mcdp6150_dump (prt_i2c_ds_struct *i2c, prt_u8 slave, prt_u16 offset);
prt_sta_type prt_mcdp6150_rst_dp (prt_i2c_ds_struct *i2c, prt_u8 slave);
prt_sta_type prt_mcdp6150_rst_cr (prt_i2c_ds_struct *i2c, prt_u8 slave);
