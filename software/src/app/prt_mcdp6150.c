/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Kinetic MCDP6150 Driver 
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

// Includes
#include "prt_types.h"
#include "prt_i2c.h"
#include "prt_mcdp6150.h"
#include "prt_printf.h"

// Initialize
prt_sta_type prt_mcdp6150_init (prt_i2c_ds_struct *i2c, prt_u8 slave)
{
	// Variables
	prt_sta_type sta;

	// DisplayPort disable (Clear registers)
	sta = prt_mcdp6150_dp_en (i2c, slave, PRT_FALSE);

	// DisplayPort enable
	sta = prt_mcdp6150_dp_en (i2c, slave, PRT_TRUE);

	// Reset
	sta = prt_mcdp6150_rst (i2c, slave);

	// DPRX init
	sta = prt_mcdp6150_dprx_init (i2c, slave);

	// GC gain
	sta = prt_mcdp6150_gc_gain (i2c, slave);

	// Pseudo transparent mode
	sta = prt_mcdp6150_trans_mode (i2c, slave, PRT_TRUE);
	
	// Adjust request levels
	//sta = prt_mcdp6150_adj_req (i2c, slave);

	// Force TX parameters
	sta = prt_mcdp6150_tx_force (i2c, slave, 1, 1);

	// Disable PHY repeater mode
	sta = prt_mcdp6150_lttpr_mode (i2c, slave, PRT_FALSE);

	return sta;
}

// Enable DP retimer
prt_sta_type prt_mcdp6150_dp_en (prt_i2c_ds_struct *i2c, prt_u8 slave, prt_u8 en)
{
	// Variables
	prt_sta_type sta;
	prt_u32 dat;

	// Read register
	sta = prt_mcdp6150_rd (i2c, slave, PRT_MCDP6150_OPMODE_CONF, &dat);

	// Set DIS_N override to TWI 
	dat |= PRT_MCDP6150_OPMODE_CONF_DIS_N_OVR_EN;

	// Enable
	if (en)
		dat |= PRT_MCDP6150_OPMODE_CONF_DIS_N;

	// Disable
	else
		dat &= ~PRT_MCDP6150_OPMODE_CONF_DIS_N;

	// Write register
	sta = prt_mcdp6150_wr (i2c, slave, PRT_MCDP6150_OPMODE_CONF, dat);
	
	// Return status
	return sta;
}

// Reset
prt_sta_type prt_mcdp6150_rst (prt_i2c_ds_struct *i2c, prt_u8 slave)
{
	// Variables
	prt_sta_type sta;
	prt_u32 dat;

	// Read register
	sta = prt_mcdp6150_rd (i2c, slave, PRT_MCDP6150_OPMODE_CONF, &dat);

	// Set reset DP data path bit 
	dat |= PRT_MCDP6150_OPMODE_CONF_DP_SOFT_RST;

	// Write register
	sta = prt_mcdp6150_wr (i2c, slave, PRT_MCDP6150_OPMODE_CONF, dat);

	// Clear reset DP data path bit 
	dat &= ~PRT_MCDP6150_OPMODE_CONF_DP_SOFT_RST;

	// Write register
	sta = prt_mcdp6150_wr (i2c, slave, PRT_MCDP6150_OPMODE_CONF, dat);

	// Return status
	return sta;
}

// Initialize DPRX
prt_sta_type prt_mcdp6150_dprx_init (prt_i2c_ds_struct *i2c, prt_u8 slave)
{
	// Variables
	prt_sta_type sta;
	prt_u32 dat;

	// Read register
	sta = prt_mcdp6150_rd (i2c, slave, PRT_MCDP6150_DP_RT_CONFIG, &dat);

	// Enable DPRX initialization based on DPCD 100h and 600h
	dat &= ~(1 << 4);

	// Write register
	sta = prt_mcdp6150_wr (i2c, slave, PRT_MCDP6150_DP_RT_CONFIG, dat);
	
	// Return status
	return sta;
}

// GC gain 
// This function sets the jitter filtering.
// This reduces the power of the SSC down-spread
prt_sta_type prt_mcdp6150_gc_gain (prt_i2c_ds_struct *i2c, prt_u8 slave)
{
	// Variables
	prt_sta_type sta;

	sta = prt_mcdp6150_wr (i2c, slave, 0x024c, 0x33331A50);	// Works with AMD GPU

	// Return status
	return sta;
}

// Reset DP path 
prt_sta_type prt_mcdp6150_rst_dp (prt_i2c_ds_struct *i2c, prt_u8 slave)
{
	// Variables
	prt_sta_type sta;
	prt_u32 dat;

	// Read register
	sta = prt_mcdp6150_rd (i2c, slave, PRT_MCDP6150_OPMODE_CONF, &dat);

	// Set reset bit
	dat |= PRT_MCDP6150_OPMODE_CONF_DP_SOFT_RST;

	// Write register
	sta = prt_mcdp6150_wr (i2c, slave, PRT_MCDP6150_OPMODE_CONF, dat);

	// Clear reset bit
	dat &= ~(PRT_MCDP6150_OPMODE_CONF_DP_SOFT_RST);

	// Write register
	sta = prt_mcdp6150_wr (i2c, slave, PRT_MCDP6150_OPMODE_CONF, dat);

	// Return status
	return sta;
}

// Reset CR path 
prt_sta_type prt_mcdp6150_rst_cr (prt_i2c_ds_struct *i2c, prt_u8 slave)
{
	// Variables
	prt_sta_type sta;
	prt_u32 dat;

	// Read register
	sta = prt_mcdp6150_rd (i2c, slave, 0x150, &dat);

	// Set reset bit
	dat |= (1 << 15);

	// Write register
	sta = prt_mcdp6150_wr (i2c, slave, 0x150, dat);

	// Clear reset bit
	dat &= ~(1 << 15);

	// Write register
	sta = prt_mcdp6150_wr (i2c, slave, 0x150, dat);

	// Return status
	return sta;
}

// Set transparent mode
// 0 - Pass-through mode
// 1 - pseudo mode
prt_sta_type prt_mcdp6150_trans_mode (prt_i2c_ds_struct *i2c, prt_u8 slave, prt_u8 pseudo)
{
	// Variables
	prt_sta_type sta;
	prt_u32 dat;

	// Read register
	sta = prt_mcdp6150_rd (i2c, slave, PRT_MCDP6150_LT_CONFIG_2, &dat);

	// Pseudo transparent mode (DPCD 206h/207h snoop)
	// The registers DPCD 206h/207h are updated by the MCDP6150
	// Clear FULL_TRANSPARENT_EN bit
	if (pseudo)
		dat &= ~PRT_MCDP6150_LT_CONFIG_2_FULL_TRANSPARENT_EN;

	// Pass-through mode (DPCD 206h / 207h pass-through mode)
	// Set FULL_TRANSPARENT_EN bit
	else
		dat |= PRT_MCDP6150_LT_CONFIG_2_FULL_TRANSPARENT_EN;

	// Write register
	sta = prt_mcdp6150_wr (i2c, slave, PRT_MCDP6150_LT_CONFIG_2, dat);

	// Return status
	return sta;
}

// Adjust request
// This function sets the adjust request levels
prt_sta_type prt_mcdp6150_adj_req (prt_i2c_ds_struct *i2c, prt_u8 slave)
{
	// Variables
	prt_sta_type sta;
	prt_u32 dat;
	prt_u16 adj;

	// Read register
	sta = prt_mcdp6150_rd (i2c, slave, PRT_MCDP6150_LT_CONFIG_2, &dat);

	// Set FULL_TRANSPARENT_EN bit
	if (0)
		dat |= (1 << 11);

	// Clear FULL_TRANSPARENT_EN bit
	else
		dat &= ~(1 << 11);

	// Write register
	sta = prt_mcdp6150_wr (i2c, slave, PRT_MCDP6150_LT_CONFIG_2, dat);

	// Here the adjust request values for the voltage swing and pre-emphasis are set.
	// Number - Volage 	- Pre-emphasis
	// 1 	- 0		- 0
	// 2 	- 1		- 0
	// 3 	- 1		- 1
	// 4 	- 2		- 0
	// 5 	- 2		- 1
	// 6 	- 2		- 2
	// 7 	- 3		- 1
	// 8 	- 3		- 2
	// 9 	- 3		- 3
	// other 	- 0		- 0

	// 1st adjust request value
	adj = prt_mcdp6150_set_adj_val (0, 0);
	dat = adj << 16;
	
	// Write register
	sta = prt_mcdp6150_wr (i2c, slave, PRT_MCDP6150_LT_CONFIG_B, dat);

	// 2nd adjust request value
	adj = prt_mcdp6150_set_adj_val (1, 0);
	dat = adj;

	// 3rd adjust request value
	adj = prt_mcdp6150_set_adj_val (1, 1);
	dat |= (adj << 16);
	
	// Write register
	sta = prt_mcdp6150_wr (i2c, slave, PRT_MCDP6150_LT_CONFIG_4, dat);

	// 4th adjust request value
	adj = prt_mcdp6150_set_adj_val (2, 0);
	dat = adj;

	// 5th adjust request value
	adj = prt_mcdp6150_set_adj_val (2, 1);
	dat |= (adj << 16);
	
	// Write register
	sta = prt_mcdp6150_wr (i2c, slave, PRT_MCDP6150_LT_CONFIG_5, dat);

	// 6th adjust request value
	adj = prt_mcdp6150_set_adj_val (2, 2);
	dat = adj;

	// 7th adjust request value
	adj = prt_mcdp6150_set_adj_val (3, 1);
	dat |= (adj << 16);
	
	// Write register
	sta = prt_mcdp6150_wr (i2c, slave, PRT_MCDP6150_LT_CONFIG_6, dat);

	// 8th adjust request value
	adj = prt_mcdp6150_set_adj_val (3, 2);
	dat = adj;

	// 9th adjust request value
	adj = prt_mcdp6150_set_adj_val (3, 3);
	dat |= (adj << 16);
	
	// Write register
	sta = prt_mcdp6150_wr (i2c, slave, PRT_MCDP6150_LT_CONFIG_7, dat);

	// Return status
	return sta;
}

// Force TX parameters
// This function sets the TX voltage and pre-emphasis levels
prt_sta_type prt_mcdp6150_tx_force (prt_i2c_ds_struct *i2c, prt_u8 slave, prt_u8 volt, prt_u8 pre)
{
	// Variables
	prt_sta_type sta;
	prt_u32 dat;

	// Read register
	sta = prt_mcdp6150_rd (i2c, slave, PRT_MCDP6150_LT_CONFIG_2, &dat);

	// Force transmitter setting
	dat |= PRT_MCDP6150_LT_CONFIG_2_FORCE_TX_PARAM;

	// Write register
	sta = prt_mcdp6150_wr (i2c, slave, PRT_MCDP6150_LT_CONFIG_2, dat);

	// Read register
	sta = prt_mcdp6150_rd (i2c, slave, PRT_MCDP6150_LT_CONFIG_1, &dat);

	// Mask out bits 
	dat &= 0xff0000ff;

	// TX Voltage swing LN0
	dat |= (volt << 8);

	// TX Voltage swing LN1
	dat |= (volt << 12);

	// TX Voltage swing LN2
	dat |= (volt << 16);

	// TX Voltage swing LN3
	dat |= (volt << 20);

	// TX pre-emphasis LN0
	dat |= (pre << 10);

	// TX pre-emphasis LN1
	dat |= (pre << 14);

	// TX pre-emphasis LN2
	dat |= (pre << 18);

	// TX pre-emphasis LN3
	dat |= (pre << 22);

	// Write register
	sta = prt_mcdp6150_wr (i2c, slave, PRT_MCDP6150_LT_CONFIG_1, dat);

	// Return status
	return sta;
}

// This function calculates the adjust value for the link training config
prt_u16 prt_mcdp6150_set_adj_val (prt_u8 volt, prt_u8 pre)
{
	// Variables
	prt_u16 dat;

	// Adjust swing req LN0
	dat = (volt << PRT_MCDP6150_ADJ_SWING_REG_LN0_SHIFT);

	// Adjust swing req LN1
	dat |= (volt << PRT_MCDP6150_ADJ_SWING_REG_LN1_SHIFT);

	// Adjust swing req LN2
	dat |= (volt << PRT_MCDP6150_ADJ_SWING_REG_LN2_SHIFT);

	// Adjust swing req LN3
	dat |= (volt << PRT_MCDP6150_ADJ_SWING_REG_LN3_SHIFT);

	// Adjust pre-emphasis req LN0
	dat |= (pre << PRT_MCDP6150_ADJ_PRE_EMP_REG_LN0_SHIFT);

	// Adjust pre-emphasis req LN1
	dat |= (pre << PRT_MCDP6150_ADJ_PRE_EMP_REG_LN1_SHIFT);

	// Adjust pre-emphasis req LN2
	dat |= (pre << PRT_MCDP6150_ADJ_PRE_EMP_REG_LN2_SHIFT);

	// Adjust pre-emphasis req LN3
	dat |= (pre  << PRT_MCDP6150_ADJ_PRE_EMP_REG_LN3_SHIFT);

	return dat;
}

// PHY repeater mode
prt_sta_type prt_mcdp6150_lttpr_mode (prt_i2c_ds_struct *i2c, prt_u8 slave, prt_u8 en)
{
	// Variables
	prt_sta_type sta;
	prt_u32 dat;

	// Set DPCD values related to LTTPR to zero
	dat = 0;

	// Write all zeros in LTTPR capability register
	if (en == PRT_FALSE)
		sta = prt_mcdp6150_wr (i2c, slave, PRT_MCDP6150_DPCD_LTTPR_CAP_ID_0, dat);

	// Read register
	sta = prt_mcdp6150_rd (i2c, slave, PRT_MCDP6150_LT_CONFIG_0, &dat);

	// PRT_MCDP6150_DPCD_LTTPR_CAP_ID_0 update
	// Enable
	if (en == PRT_TRUE)
		dat &= ~(1 << 15);

	// Disable 
	else
		dat |= (1 << 15);

	// Write register
	sta = prt_mcdp6150_wr (i2c, slave, PRT_MCDP6150_LT_CONFIG_0, dat);
	
	// Return status
	return sta;
}

// Enable reference clock output
prt_sta_type prt_mcdp6150_refclk_en (prt_i2c_ds_struct *i2c, prt_u8 slave)
{
	// Variables
	prt_sta_type sta;
	prt_u32 dat;

	// Read register
	sta = prt_mcdp6150_rd (i2c, slave, PRT_MCDP6150_IC_RT_CONFIG, &dat);

	// Set reference clock output
	dat |= (1 << 31);

	// Write register
	sta = prt_mcdp6150_wr (i2c, slave, PRT_MCDP6150_IC_RT_CONFIG, dat);
	
	// Return status
	return sta;
}

// PRBS7 generator
// This function enables the PRBS7 generator
prt_sta_type prt_mcdp6150_prbs7 (prt_i2c_ds_struct *i2c, prt_u8 slave)
{
	// Variables
	prt_sta_type sta;
	prt_u32 dat;

	// Modify register 0x150
	sta = prt_mcdp6150_rd (i2c, slave, 0x150, &dat);
	dat |= (1 << 20);	// Disable initial reset for DPTX
	sta = prt_mcdp6150_wr (i2c, slave, 0x150, dat);

	// Modify register 0x668
	sta = prt_mcdp6150_rd (i2c, slave, 0x668, &dat);
	dat |= (1 << 0);	// Disable normal operation
	sta = prt_mcdp6150_wr (i2c, slave, 0x668, dat);

	// Modify register 0x674
	sta = prt_mcdp6150_rd (i2c, slave, 0x674, &dat);
	dat |= (1 << 0);	// Select pattern generator as data out
	sta = prt_mcdp6150_wr (i2c, slave, 0x674, dat);

	// Modify register 0x680
	sta = prt_mcdp6150_rd (i2c, slave, 0x680, &dat);
	// Mask out bits 19:16
	dat &= ~(0xf << 16);

	// Select PRBS7
	dat |= (0x7 << 16);
	sta = prt_mcdp6150_wr (i2c, slave, 0x680, dat);

	// Modify register 0x604
	sta = prt_mcdp6150_rd (i2c, slave, 0x604, &dat);
	dat |= (1 << 2);	// Disable AUX access and refer to 0x630
	sta = prt_mcdp6150_wr (i2c, slave, 0x604, dat);

	// Modify register 0x684
	sta = prt_mcdp6150_rd (i2c, slave, 0x684, &dat);
	dat &= ~(1 << 6);
	//dat |= (1 << 6);	// PRBS7 bit reverse
	sta = prt_mcdp6150_wr (i2c, slave, 0x684, dat);

	// Return status
	return sta;
}

// Set rate
// This function sets the linerate (only in PRBS7 mode)
prt_sta_type prt_mcdp6150_set_rate (prt_i2c_ds_struct *i2c, prt_u8 slave, prt_u8 rate)
{
	// Variables
	prt_sta_type sta;
	prt_u32 dat;

	// Read register 0x630
	sta = prt_mcdp6150_rd (i2c, slave, 0x630, &dat);

	// Mask out bits
	dat &= ~(0x73f);

	// Lane count (4 lanes)
	dat |= (4 << 8);

	// Rate
	dat |= (rate);

	// Write register
	sta = prt_mcdp6150_wr (i2c, slave, 0x630, dat);
}

// Set voltage and pre-emphasis
// This function sets the voltage and pre-emphasis levels (only in PRBS7 mode)
prt_sta_type prt_mcdp6150_set_vap (prt_i2c_ds_struct *i2c, prt_u8 slave, prt_u8 volt, prt_u8 pre)
{
	// Variables
	prt_sta_type sta;
	prt_u32 dat;

	// Read register 0x720
	sta = prt_mcdp6150_rd (i2c, slave, 0x720, &dat);

	// Mask out bits
	dat &= ~(0xff << 24);

	// Voltage swing lane 0
	dat |= (volt << 24);

	// Voltage swing lane 1
	dat |= (volt << 26);

	// Voltage swing lane 2
	dat |= (volt << 28);

	// Voltage swing lane 3
	dat |= (volt << 30);

	// Write register
	sta = prt_mcdp6150_wr (i2c, slave, 0x720, dat);

	// Read register 0x724
	sta = prt_mcdp6150_rd (i2c, slave, 0x724, &dat);

	// Mask out bits
	dat &= ~(0xff << 0);

	// Pre-emphasis lane 0
	dat |= (pre << 0);

	// Pre-emphasis lane 1
	dat |= (pre << 2);

	// Pre-emphasis lane 2
	dat |= (pre << 4);

	// Pre-emphasis lane 3
	dat |= (pre << 6);

	// Write register
	sta = prt_mcdp6150_wr (i2c, slave, 0x724, dat);

	return sta;
}

// Read register
prt_sta_type prt_mcdp6150_rd (prt_i2c_ds_struct *i2c, prt_u8 slave, prt_u16 offset, prt_u32 *dat)
{
	// Variables
	prt_sta_type sta;

	// Slave
	i2c->slave = slave;
	
	// Offset LSB
	i2c->dat[0] = offset & 0xff;

	// Offset MSB
	i2c->dat[1] = offset >> 8;

	// Length
	i2c->len = 2;

	// Set no stop flag
	i2c->no_stop = PRT_TRUE;

	// Write
	sta = prt_i2c_wr (i2c);

	if (sta != PRT_STA_OK)
	{
		return sta;
	}

	// Length
	i2c->len = 4;

	// Clear no stop flag
	i2c->no_stop = PRT_FALSE;

	// Read
	sta = prt_i2c_rd (i2c);

	// Copy data
	*dat = i2c->dat[0];
	*dat |= (i2c->dat[1] << 8);
	*dat |= (i2c->dat[2] << 16);
	*dat |= (i2c->dat[3] << 24);

	// Return status
	return sta;
}

// Write register
prt_sta_type prt_mcdp6150_wr (prt_i2c_ds_struct *i2c, prt_u8 slave, prt_u16 offset, prt_u32 dat)
{
	// Variables
	prt_sta_type sta;

	// Slave
	i2c->slave = slave;

	// Offset LSB
	i2c->dat[0] = offset & 0xff;

	// Offset MSB
	i2c->dat[1] = offset >> 8;
	
	// Data 1
	i2c->dat[2] = dat & 0xff;

	// Data 2
	i2c->dat[3] = (dat >> 8) & 0xff;

	// Data 3
	i2c->dat[4] = (dat >> 16) & 0xff;

	// Data 4
	i2c->dat[5] = (dat >> 24) & 0xff;

	// Length
	i2c->len = 6;

	// Write
	sta = prt_i2c_wr (i2c);

	// Return
	return sta;
}

// Dump register
void prt_mcdp6150_dump (prt_i2c_ds_struct *i2c, prt_u8 slave, prt_u16 offset)
{
	// Variables
	prt_sta_type sta;
	prt_u32 dat;

	// Read register
	sta = prt_mcdp6150_rd (i2c, slave, offset, &dat);

	prt_printf ("MCDP6150: offset: %x - data: %x\n", offset, dat);
}
