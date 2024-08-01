/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Video Toolbox driver
    (c) 2021 - 2024 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Added video resolution 7680x4320P30
    v1.2 - Added video resolution 5120X2160P60

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
#include <stdint.h>
#include "prt_types.h"
#include "prt_vtb.h"
#include "prt_printf.h"

// Set base address
void prt_vtb_set_base (prt_vtb_ds_struct *vtb, uint32_t base)
{
	// Base address
	vtb->dev = (prt_vtb_dev_struct *) base;
}

// Set reference clock
void prt_vtb_set_refclk (prt_vtb_ds_struct *vtb, uint32_t clk)
{
	vtb->refclk = clk;
}

// Set video clock
void prt_vtb_set_vidclk (prt_vtb_ds_struct *vtb, uint32_t clk)
{
	vtb->vidclk = clk;
}

// Set preset timing parameters
void prt_vtb_set_tp (prt_vtb_ds_struct *vtb, prt_vtb_tp_struct *tp, uint8_t preset)
{
	switch (preset)
	{
		case VTB_PRESET_1280X720P50 :
			vtb->tp.htotal  = VTB_1280X720P50_HTOTAL;
			vtb->tp.hwidth  = VTB_1280X720P50_HWIDTH;
			vtb->tp.hstart  = VTB_1280X720P50_HSTART;
			vtb->tp.hsw     = VTB_1280X720P50_HSW;
			vtb->tp.vtotal  = VTB_1280X720P50_VTOTAL;
			vtb->tp.vheight = VTB_1280X720P50_VHEIGHT;
			vtb->tp.vstart  = VTB_1280X720P50_VSTART;
			vtb->tp.vsw     = VTB_1280X720P50_VSW;
			vtb->tp.pclk    = VTB_1280X720P50_PCLK;
		break;

		case VTB_PRESET_1280X720P60 :
			vtb->tp.htotal  = VTB_1280X720P60_HTOTAL;
			vtb->tp.hwidth  = VTB_1280X720P60_HWIDTH;
			vtb->tp.hstart  = VTB_1280X720P60_HSTART;
			vtb->tp.hsw     = VTB_1280X720P60_HSW;
			vtb->tp.vtotal  = VTB_1280X720P60_VTOTAL;
			vtb->tp.vheight = VTB_1280X720P60_VHEIGHT;
			vtb->tp.vstart  = VTB_1280X720P60_VSTART;
			vtb->tp.vsw     = VTB_1280X720P60_VSW;
			vtb->tp.pclk    = VTB_1280X720P60_PCLK;
		break;

		case VTB_PRESET_1920X1080P50 :
			vtb->tp.htotal  = VTB_1920X1080P50_HTOTAL;
			vtb->tp.hwidth  = VTB_1920X1080P50_HWIDTH;
			vtb->tp.hstart  = VTB_1920X1080P50_HSTART;
			vtb->tp.hsw     = VTB_1920X1080P50_HSW;
			vtb->tp.vtotal  = VTB_1920X1080P50_VTOTAL;
			vtb->tp.vheight = VTB_1920X1080P50_VHEIGHT;
			vtb->tp.vstart  = VTB_1920X1080P50_VSTART;
			vtb->tp.vsw     = VTB_1920X1080P50_VSW;
			vtb->tp.pclk    = VTB_1920X1080P50_PCLK;
		break;

		case VTB_PRESET_1920X1080P60 :
			vtb->tp.htotal  = VTB_1920X1080P60_HTOTAL;
			vtb->tp.hwidth  = VTB_1920X1080P60_HWIDTH;
			vtb->tp.hstart  = VTB_1920X1080P60_HSTART;
			vtb->tp.hsw     = VTB_1920X1080P60_HSW;
			vtb->tp.vtotal  = VTB_1920X1080P60_VTOTAL;
			vtb->tp.vheight = VTB_1920X1080P60_VHEIGHT;
			vtb->tp.vstart  = VTB_1920X1080P60_VSTART;
			vtb->tp.vsw     = VTB_1920X1080P60_VSW;
			vtb->tp.pclk    = VTB_1920X1080P60_PCLK;
		break;

		case VTB_PRESET_2560X1440P50 :
			vtb->tp.htotal  = VTB_2560X1440P50_HTOTAL;
			vtb->tp.hwidth  = VTB_2560X1440P50_HWIDTH;
			vtb->tp.hstart  = VTB_2560X1440P50_HSTART;
			vtb->tp.hsw     = VTB_2560X1440P50_HSW;
			vtb->tp.vtotal  = VTB_2560X1440P50_VTOTAL;
			vtb->tp.vheight = VTB_2560X1440P50_VHEIGHT;
			vtb->tp.vstart  = VTB_2560X1440P50_VSTART;
			vtb->tp.vsw     = VTB_2560X1440P50_VSW;
			vtb->tp.pclk    = VTB_2560X1440P50_PCLK;
		break;

		case VTB_PRESET_2560X1440P60 :
			vtb->tp.htotal  = VTB_2560X1440P60_HTOTAL;
			vtb->tp.hwidth  = VTB_2560X1440P60_HWIDTH;
			vtb->tp.hstart  = VTB_2560X1440P60_HSTART;
			vtb->tp.hsw     = VTB_2560X1440P60_HSW;
			vtb->tp.vtotal  = VTB_2560X1440P60_VTOTAL;
			vtb->tp.vheight = VTB_2560X1440P60_VHEIGHT;
			vtb->tp.vstart  = VTB_2560X1440P60_VSTART;
			vtb->tp.vsw     = VTB_2560X1440P60_VSW;
			vtb->tp.pclk    = VTB_2560X1440P60_PCLK;
		break;

		case VTB_PRESET_3840X2160P50 :
			vtb->tp.htotal  = VTB_3840X2160P50_HTOTAL;
			vtb->tp.hwidth  = VTB_3840X2160P50_HWIDTH;
			vtb->tp.hstart  = VTB_3840X2160P50_HSTART;
			vtb->tp.hsw     = VTB_3840X2160P50_HSW;
			vtb->tp.vtotal  = VTB_3840X2160P50_VTOTAL;
			vtb->tp.vheight = VTB_3840X2160P50_VHEIGHT;
			vtb->tp.vstart  = VTB_3840X2160P50_VSTART;
			vtb->tp.vsw     = VTB_3840X2160P50_VSW;
			vtb->tp.pclk    = VTB_3840X2160P50_PCLK;
		break;

		case VTB_PRESET_3840X2160P60 :
			vtb->tp.htotal  = VTB_3840X2160P60_HTOTAL;
			vtb->tp.hwidth  = VTB_3840X2160P60_HWIDTH;
			vtb->tp.hstart  = VTB_3840X2160P60_HSTART;
			vtb->tp.hsw     = VTB_3840X2160P60_HSW;
			vtb->tp.vtotal  = VTB_3840X2160P60_VTOTAL;
			vtb->tp.vheight = VTB_3840X2160P60_VHEIGHT;
			vtb->tp.vstart  = VTB_3840X2160P60_VSTART;
			vtb->tp.vsw     = VTB_3840X2160P60_VSW;
			vtb->tp.pclk    = VTB_3840X2160P60_PCLK;
		break;

		case VTB_PRESET_7680X4320P30 :
			vtb->tp.htotal  = VTB_7680X4320P30_HTOTAL;
			vtb->tp.hwidth  = VTB_7680X4320P30_HWIDTH;
			vtb->tp.hstart  = VTB_7680X4320P30_HSTART;
			vtb->tp.hsw     = VTB_7680X4320P30_HSW;
			vtb->tp.vtotal  = VTB_7680X4320P30_VTOTAL;
			vtb->tp.vheight = VTB_7680X4320P30_VHEIGHT;
			vtb->tp.vstart  = VTB_7680X4320P30_VSTART;
			vtb->tp.vsw     = VTB_7680X4320P30_VSW;
			vtb->tp.pclk    = VTB_7680X4320P30_PCLK;
		break;

		default :
			vtb->tp.htotal = tp->htotal;
			vtb->tp.hwidth = tp->hwidth;
			vtb->tp.hstart = tp->hstart;
			vtb->tp.hsw = tp->hsw;
			vtb->tp.vtotal = tp->vtotal;	
			vtb->tp.vheight = tp->vheight;	
			vtb->tp.vstart = tp->vstart;
			vtb->tp.vsw = tp->vsw;
			vtb->tp.pclk = tp->pclk;
		break;
	}
}

// Test pattern generator
void prt_vtb_tpg (prt_vtb_ds_struct *vtb, prt_vtb_tp_struct *tp, uint8_t preset, uint8_t fmt)
{
	// Variables
	uint32_t dat;

	// Stop video
	prt_vtb_set_og (vtb, PRT_VTB_OG_CTL, 0);

	// Set timing parameters
	prt_vtb_set_tp (vtb, tp, preset);

	// Copy timing parameters to device
	prt_vtb_set_vps (vtb, PRT_VTB_VPS_REFCLK_HI, vtb->refclk >> 16);
	prt_vtb_set_vps (vtb, PRT_VTB_VPS_REFCLK_LO, vtb->refclk);
	prt_vtb_set_vps (vtb, PRT_VTB_VPS_VIDCLK_HI, vtb->vidclk >> 16);
	prt_vtb_set_vps (vtb, PRT_VTB_VPS_VIDCLK_LO, vtb->vidclk);
	prt_vtb_set_vps (vtb, PRT_VTB_VPS_HTOTAL, vtb->tp.htotal);
	prt_vtb_set_vps (vtb, PRT_VTB_VPS_HWIDTH, vtb->tp.hwidth);
	prt_vtb_set_vps (vtb, PRT_VTB_VPS_HSTART, vtb->tp.hstart);
	prt_vtb_set_vps (vtb, PRT_VTB_VPS_HSW, vtb->tp.hsw);
	prt_vtb_set_vps (vtb, PRT_VTB_VPS_VTOTAL, vtb->tp.vtotal);
	prt_vtb_set_vps (vtb, PRT_VTB_VPS_VHEIGHT, vtb->tp.vheight);
	prt_vtb_set_vps (vtb, PRT_VTB_VPS_VSTART, vtb->tp.vstart);
	prt_vtb_set_vps (vtb, PRT_VTB_VPS_VSW, vtb->tp.vsw);

	// PLL timing mode
	dat = PRT_VTB_OG_CTL_VID_EN | PRT_VTB_OG_CTL_TG_RUN | PRT_VTB_OG_CTL_TPG_RUN;

	// Test Pattern Generator Format
	dat |= (fmt & 0x7) << PRT_VTB_OG_CTL_TPG_FMT_SHIFT;
	
	// Clock generator
	//dat |= PRT_VTB_OG_CTL_CG_RUN;

	// Start video
	prt_vtb_set_og (vtb, PRT_VTB_OG_CTL, dat);
}

// Clock Recovery
void prt_vtb_cr (prt_vtb_ds_struct *vtb, prt_vtb_tp_struct *tp, uint8_t preset)
{
	// Variables
	uint32_t dat;

	// Stop video
	prt_vtb_set_og (vtb, PRT_VTB_OG_CTL, 0);

	// Set timing parameters
	prt_vtb_set_tp (vtb, tp, preset);

	// Copy timing parameters to device
	prt_vtb_set_vps (vtb, PRT_VTB_VPS_REFCLK_HI, vtb->refclk >> 16);
	prt_vtb_set_vps (vtb, PRT_VTB_VPS_REFCLK_LO, vtb->refclk);
	prt_vtb_set_vps (vtb, PRT_VTB_VPS_VIDCLK_HI, vtb->vidclk >> 16);
	prt_vtb_set_vps (vtb, PRT_VTB_VPS_VIDCLK_LO, vtb->vidclk);
	prt_vtb_set_vps (vtb, PRT_VTB_VPS_HTOTAL, vtb->tp.htotal);
	prt_vtb_set_vps (vtb, PRT_VTB_VPS_HWIDTH, vtb->tp.hwidth);
	prt_vtb_set_vps (vtb, PRT_VTB_VPS_HSTART, vtb->tp.hstart);
	prt_vtb_set_vps (vtb, PRT_VTB_VPS_HSW, vtb->tp.hsw);
	prt_vtb_set_vps (vtb, PRT_VTB_VPS_VTOTAL, vtb->tp.vtotal);
	prt_vtb_set_vps (vtb, PRT_VTB_VPS_VHEIGHT, vtb->tp.vheight);
	prt_vtb_set_vps (vtb, PRT_VTB_VPS_VSTART, vtb->tp.vstart);
	prt_vtb_set_vps (vtb, PRT_VTB_VPS_VSW, vtb->tp.vsw);

	// Enable link and video
	dat = PRT_VTB_OG_CTL_LNK_EN | PRT_VTB_OG_CTL_VID_EN;

	// Clock recovery 
	dat |= PRT_VTB_OG_CTL_CR_RUN;

	// FIFO
	dat |= PRT_VTB_OG_CTL_FIFO_RUN;

	// Timing generator
	dat |= PRT_VTB_OG_CTL_TG_RUN | PRT_VTB_OG_CTL_TG_MODE;

	// Start video
	prt_vtb_set_og (vtb, PRT_VTB_OG_CTL, dat);
}

// Write video parameter set
void prt_vtb_set_vps (prt_vtb_ds_struct *vtb, uint8_t vps, uint32_t dat)
{
	vtb->dev->ctl = (vps << PRT_VTB_DEV_CTL_VPS_SHIFT);
	vtb->dev->vps = dat;
}

// Write outgress
void prt_vtb_set_og (prt_vtb_ds_struct *vtb, uint8_t og, uint32_t dat)
{
	vtb->dev->ctl = (og << PRT_VTB_DEV_CTL_OG_SHIFT);
	vtb->dev->og = dat;
}

// Read outgress
uint32_t prt_vtb_get_og (prt_vtb_ds_struct *vtb, uint8_t og)
{
	vtb->dev->ctl = (og << PRT_VTB_DEV_CTL_OG_SHIFT);
	return vtb->dev->og;
}

// Read ingress
uint32_t prt_vtb_get_ig (prt_vtb_ds_struct *vtb, uint8_t ig)
{
	vtb->dev->ctl = (ig << PRT_VTB_DEV_CTL_IG_SHIFT);
	return vtb->dev->ig;
}

// Set P gain
void prt_vtb_cr_set_p_gain (prt_vtb_ds_struct *vtb, uint8_t gain)
{
	// Variables
	uint32_t dat;

	// Read outgress
	dat = prt_vtb_get_og (vtb, PRT_VTB_OG_CR);

	// Mask out P gain bits
	dat &= ~(0xff << PRT_VTB_OG_CR_P_GAIN_SHIFT);

	// Set P gain
	dat |= (gain << PRT_VTB_OG_CR_P_GAIN_SHIFT);

	// Write outgress
	prt_vtb_set_og (vtb, PRT_VTB_OG_CR, dat);
}

// Set I gain
void prt_vtb_cr_set_i_gain (prt_vtb_ds_struct *vtb, prt_u16 gain)
{
	// Variables
	uint32_t dat;

	// Read outgress
	dat = prt_vtb_get_og (vtb, PRT_VTB_OG_CR);

	// Mask out I gain bits
	dat &= ~(0xffff << PRT_VTB_OG_CR_I_GAIN_SHIFT);

	// Set I gain
	dat |= (gain << PRT_VTB_OG_CR_I_GAIN_SHIFT);

	// Write outgress
	prt_vtb_set_og (vtb, PRT_VTB_OG_CR, dat);
}

// FIFO lock
uint8_t prt_vtb_get_fifo_lock (prt_vtb_ds_struct *vtb)
{
	// Variables
	uint32_t dat;

	// Read fifo status
	dat = prt_vtb_get_ig (vtb, PRT_VTB_IG_FIFO);

	if (dat & PRT_VTB_IG_FIFO_LOCK)
		return PRT_TRUE;
	else
		return PRT_FALSE;
}

// FIFO maximum words
prt_u16 prt_vtb_get_fifo_max_wrds (prt_vtb_ds_struct *vtb)
{
	// Variables
	uint32_t dat;

	// Read fifo status
	dat = prt_vtb_get_ig (vtb, PRT_VTB_IG_FIFO);

	// Shift
	dat >>= PRT_VTB_IG_FIFO_MAX_WRDS_SHIFT;

	// Mask 10 bits
	dat &= 0x3ff;

	return dat;
}

// FIFO minimum words
prt_u16 prt_vtb_get_fifo_min_wrds (prt_vtb_ds_struct *vtb)
{
	// Variables
	uint32_t dat;

	// Read fifo status
	dat = prt_vtb_get_ig (vtb, PRT_VTB_IG_FIFO);

	// Shift
	dat >>= PRT_VTB_IG_FIFO_MIN_WRDS_SHIFT;

	// Mask 10 bits
	dat &= 0x3ff;
	
	return dat;
}

// CR current error
prt_s8 prt_vtb_get_cr_cur_err (prt_vtb_ds_struct *vtb)
{
	// Variables
	uint32_t dat;
	prt_s8 signed_dat;

	// Read fifo status
	dat = prt_vtb_get_ig (vtb, PRT_VTB_IG_CR_ERR);

	// Shift
	dat >>= PRT_VTB_IG_CR_ERR_CUR_SHIFT;

	// Mask 6 bits
	dat &= 0x3f;

	// Maximum minimal value
	if (dat == 0x20)
		signed_dat = -32;

	// Negative value
	else if (dat & 0x20)
	{
		signed_dat = ~(dat) + 1;
		signed_dat &= 0x1f;
		signed_dat = -signed_dat;
	}
	else
		signed_dat = (prt_s8)dat;

	return signed_dat;
}

// CR maximum error
prt_s8 prt_vtb_get_cr_max_err (prt_vtb_ds_struct *vtb)
{
	// Variables
	uint32_t dat;
	prt_s8 signed_dat;

	// Read fifo status
	dat = prt_vtb_get_ig (vtb, PRT_VTB_IG_CR_ERR);

	// Shift
	dat >>= PRT_VTB_IG_CR_ERR_MAX_SHIFT;

	// Mask 6 bits
	dat &= 0x3f;
	
	// Maximum minimal value
	if (dat == 0x20)
		signed_dat = -32;

	// Negative value
	else if (dat & 0x20)
	{
		signed_dat = ~(dat) + 1;
		signed_dat &= 0x1f;
		signed_dat = -signed_dat;
	}
	else
		signed_dat = (prt_s8)dat;
	return signed_dat;
}

// CR minimum error
prt_s8 prt_vtb_get_cr_min_err (prt_vtb_ds_struct *vtb)
{
	// Variables
	uint32_t dat;
	prt_s8 signed_dat;

	// Read fifo status
	dat = prt_vtb_get_ig (vtb, PRT_VTB_IG_CR_ERR);

	// Shift
	dat >>= PRT_VTB_IG_CR_ERR_MIN_SHIFT;

	// Mask 6 bits
	dat &= 0x3f;
	
	// Maximum minimal value
	if (dat == 0x20)
		signed_dat = -32;

	// Negative value
	else if (dat & 0x20)
	{
		signed_dat = (~dat) + 1;
		signed_dat &= 0x1;
		signed_dat = -signed_dat;
	}
	else
		signed_dat = (prt_s8)dat;
	return signed_dat;
}

// CR sum
prt_s16 prt_vtb_get_cr_sum (prt_vtb_ds_struct *vtb)
{
	// Variables
	uint32_t dat;
	prt_s16 signed_dat;

	// Read fifo status
	dat = prt_vtb_get_ig (vtb, PRT_VTB_IG_CR_SUM);

	// Mask 15 bits
	dat &= 0x7fff;

	// Maximum minimal value
	if (dat == 0x4000)
		signed_dat = -16384;

	// Negative value
	else if (dat & 0x4000)
	{
		signed_dat = (~dat) + 1;
		signed_dat &= 0x7fff;
		signed_dat = -signed_dat;
	}
	else
		signed_dat = (prt_s16)dat;
	return signed_dat;
}

// CR controller output
prt_s32 prt_vtb_get_cr_co (prt_vtb_ds_struct *vtb)
{
	// Variables
	uint32_t dat;
	prt_s32 signed_dat;

	// Read fifo status
	dat = prt_vtb_get_ig (vtb, PRT_VTB_IG_CR_CO);

	// Mask 29 bits
	dat &= 0x1fffffff;

	// Negative value
	if (dat & 0x10000000)
	{
		signed_dat = (~dat) + 1;
		signed_dat &= 0xfffffff;
		signed_dat = -signed_dat;
	}
	else
		signed_dat = (prt_s32)dat;
	return signed_dat;
}

// Get timing parameters
prt_vtb_tp_struct prt_vtb_get_tp (prt_vtb_ds_struct *vtb)
{
	return vtb->tp;
}

// TX link clock frequency
uint32_t prt_vtb_get_tx_lnk_clk_freq (prt_vtb_ds_struct *vtb)
{
	return prt_vtb_get_ig (vtb, PRT_VTB_IG_TX_LNK_CLK_FREQ);
}

// RX link clock frequency
uint32_t prt_vtb_get_rx_lnk_clk_freq (prt_vtb_ds_struct *vtb)
{
	return prt_vtb_get_ig (vtb, PRT_VTB_IG_RX_LNK_CLK_FREQ);
}

// Video reference clock frequency
uint32_t prt_vtb_get_vid_ref_freq (prt_vtb_ds_struct *vtb)
{
	return prt_vtb_get_ig (vtb, PRT_VTB_IG_VID_REF_FREQ);
}

// Video clock frequency
uint32_t prt_vtb_get_vid_clk_freq (prt_vtb_ds_struct *vtb)
{
	return prt_vtb_get_ig (vtb, PRT_VTB_IG_VID_CLK_FREQ);
}

// Find preset
uint8_t prt_vtb_find_preset (prt_u16 htotal, prt_u16 vtotal, uint32_t *pclk)
{
	uint8_t preset = 0;

	if ( (htotal == VTB_1280X720P50_HTOTAL) && (vtotal == VTB_1280X720P50_VTOTAL))
	{
		preset = VTB_PRESET_1280X720P50;
		*pclk = VTB_1280X720P50_PCLK;
	}

	else if ( (htotal == VTB_1280X720P60_HTOTAL) && (vtotal == VTB_1280X720P60_VTOTAL))
	{
		preset = VTB_PRESET_1280X720P60;
		*pclk = VTB_1280X720P60_PCLK;
	}

	else if ( (htotal == VTB_1920X1080P50_HTOTAL) && (vtotal == VTB_1920X1080P50_VTOTAL))
	{
		preset = VTB_PRESET_1920X1080P50;
		*pclk = VTB_1920X1080P50_PCLK;
	}

	else if ( (htotal == VTB_1920X1080P60_HTOTAL) && (vtotal == VTB_1920X1080P60_VTOTAL))
	{
		preset = VTB_PRESET_1920X1080P60;
		*pclk = VTB_1920X1080P60_PCLK;
	}

	else if ( (htotal == VTB_2560X1440P50_HTOTAL) && (vtotal == VTB_2560X1440P50_VTOTAL))
	{
		preset = VTB_PRESET_2560X1440P50;
		*pclk = VTB_2560X1440P50_PCLK;
	}

	else if ( (htotal == VTB_2560X1440P60_HTOTAL) && (vtotal == VTB_2560X1440P60_VTOTAL))
	{
		preset = VTB_PRESET_2560X1440P60;
		*pclk = VTB_2560X1440P60_PCLK;
	}

	else if ( (htotal == VTB_3840X2160P50_HTOTAL) && (vtotal == VTB_3840X2160P50_VTOTAL))
	{
		preset = VTB_PRESET_3840X2160P50;
		*pclk = VTB_3840X2160P50_PCLK;
	}

	else if ( (htotal == VTB_3840X2160P60_HTOTAL) && (vtotal == VTB_3840X2160P60_VTOTAL))
	{
		preset = VTB_PRESET_3840X2160P60;
		*pclk = VTB_3840X2160P60_PCLK;
	}

	else if ( (htotal == VTB_7680X4320P30_HTOTAL) && (vtotal == VTB_7680X4320P30_VTOTAL))
	{
		preset = VTB_PRESET_7680X4320P30;
		*pclk = VTB_7680X4320P30_PCLK;
	}

	return preset;
}

// Overlay enable / disable
void prt_vtb_ovl_en (prt_vtb_ds_struct *vtb, uint8_t en)
{
	// Variables
	uint32_t dat;

	// Read current control bits
	dat = prt_vtb_get_og (vtb, PRT_VTB_OG_CTL);

	// Enable
	if (en)
		dat |= PRT_VTB_OG_CTL_OVL_RUN;
	
	// Disable
	else 
		dat |= ~(PRT_VTB_OG_CTL_OVL_RUN);

	// Update overlay run flag
	prt_vtb_set_og (vtb, PRT_VTB_OG_CTL, dat);
}
