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
    v1.3 - Added YCbCr 4:4:4
    v1.4 - Added the clock enable DCO

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

// On screen display control bits
// The scroller settings as they go into the control word. Used by every function that
// composes that word from scratch, so the scroller keeps running through a format change
// and through the switch between test pattern and pass-through.
static uint32_t prt_vtb_osd_ctl (prt_vtb_ds_struct *vtb)
{
	// Variables
	uint32_t dat = 0;

	if (vtb->osd.en)
		dat |= PRT_VTB_OG_CTL_OSD_RUN;

	dat |= (vtb->osd.amp & 0x7) << PRT_VTB_OG_CTL_OSD_AMP_SHIFT;
	dat |= (vtb->osd.spd & 0xf) << PRT_VTB_OG_CTL_OSD_SPD_SHIFT;
	dat |= (vtb->osd.mode & 0x3) << PRT_VTB_OG_CTL_OSD_MODE_SHIFT;

	// Color space. The test pattern and the scroller follow it.
	if (vtb->csf == PRT_DP_CSF_YCBCR444)
		dat |= PRT_VTB_OG_CTL_CSF;

	return dat;
}

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

		case VTB_PRESET_720X1920P60 :
			vtb->tp.htotal  = VTB_720X1920P60_HTOTAL;
			vtb->tp.hwidth  = VTB_720X1920P60_HWIDTH;
			vtb->tp.hstart  = VTB_720X1920P60_HSTART;
			vtb->tp.hsw     = VTB_720X1920P60_HSW;
			vtb->tp.vtotal  = VTB_720X1920P60_VTOTAL;
			vtb->tp.vheight = VTB_720X1920P60_VHEIGHT;
			vtb->tp.vstart  = VTB_720X1920P60_VSTART;
			vtb->tp.vsw     = VTB_720X1920P60_VSW;
			vtb->tp.pclk    = VTB_720X1920P60_PCLK;
		break;

		case VTB_PRESET_7680X1260P60 :
			vtb->tp.htotal  = VTB_7680X1260P60_HTOTAL;
			vtb->tp.hwidth  = VTB_7680X1260P60_HWIDTH;
			vtb->tp.hstart  = VTB_7680X1260P60_HSTART;
			vtb->tp.hsw     = VTB_7680X1260P60_HSW;
			vtb->tp.vtotal  = VTB_7680X1260P60_VTOTAL;
			vtb->tp.vheight = VTB_7680X1260P60_VHEIGHT;
			vtb->tp.vstart  = VTB_7680X1260P60_VSTART;
			vtb->tp.vsw     = VTB_7680X1260P60_VSW;
			vtb->tp.pclk    = VTB_7680X1260P60_PCLK;
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
	
	// On screen display
	dat |= prt_vtb_osd_ctl (vtb);

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

	// On screen display
	dat |= prt_vtb_osd_ctl (vtb);

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

	if ( (htotal == VTB_7680X1260P60_HTOTAL) && (vtotal == VTB_7680X1260P60_VTOTAL))
	{
		preset = VTB_PRESET_7680X1260P60;
		*pclk = VTB_7680X1260P60_PCLK;
	}

	else if ( (htotal == VTB_1280X720P50_HTOTAL) && (vtotal == VTB_1280X720P50_VTOTAL))
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

	else if ( (htotal == VTB_720X1920P60_HTOTAL) && (vtotal == VTB_720X1920P60_VTOTAL))
	{
		preset = VTB_PRESET_720X1920P60;
		*pclk = VTB_720X1920P60_PCLK;
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
		dat &= ~(PRT_VTB_OG_CTL_OVL_RUN);

	// Update overlay run flag
	prt_vtb_set_og (vtb, PRT_VTB_OG_CTL, dat);
}

// On screen display settings
// Kept in the data structure as well, because prt_vtb_tpg and prt_vtb_cr rebuild the
// control word every time they start and would otherwise drop them.
void prt_vtb_set_osd (prt_vtb_ds_struct *vtb, uint8_t en, uint8_t amp, uint8_t spd)
{
	// Variables
	uint32_t dat;

	vtb->osd.en = en;
	vtb->osd.amp = amp;
	vtb->osd.spd = spd;

	// Apply to the running video
	dat = prt_vtb_get_og (vtb, PRT_VTB_OG_CTL);
	dat &= ~(PRT_VTB_OG_CTL_OSD_RUN
			| (0x7 << PRT_VTB_OG_CTL_OSD_AMP_SHIFT)
			| (0xf << PRT_VTB_OG_CTL_OSD_SPD_SHIFT)
			| (0x3 << PRT_VTB_OG_CTL_OSD_MODE_SHIFT));
	dat |= prt_vtb_osd_ctl (vtb);

	prt_vtb_set_og (vtb, PRT_VTB_OG_CTL, dat);
}

// The colour mode of the scroller
void prt_vtb_set_osd_mode (prt_vtb_ds_struct *vtb, uint8_t mode)
{
	// Variables
	uint32_t dat;

	vtb->osd.mode = mode;

	dat = prt_vtb_get_og (vtb, PRT_VTB_OG_CTL);
	dat &= ~(0x3 << PRT_VTB_OG_CTL_OSD_MODE_SHIFT);
	dat |= (mode & 0x3) << PRT_VTB_OG_CTL_OSD_MODE_SHIFT;

	prt_vtb_set_og (vtb, PRT_VTB_OG_CTL, dat);
}

// The colour of the scroller text
// Eight bits per component whatever the core carries; the gateware fills a deeper
// component from the top. Its own outgress register, so it survives the control word
// being rebuilt on every format change and needs no copy in the data structure.
// Write the plain scroller colour in the color space of the video
static void prt_vtb_osd_col_wr (prt_vtb_ds_struct *vtb)
{
	// Variables
	int32_t r = vtb->osd.col[0];
	int32_t g = vtb->osd.col[1];
	int32_t b = vtb->osd.col[2];
	int32_t y, cb, cr;

	if (vtb->csf == PRT_DP_CSF_YCBCR444)
	{
		// ITU-R BT.709, limited range. Coefficients times 1024.
		y  =  16 + ((( 187 * r) + (629 * g) + ( 63 * b) + 512) >> 10);
		cb = 128 + (((-103 * r) - (347 * g) + (450 * b) + 512) >> 10);
		cr = 128 + ((( 450 * r) - (409 * g) - ( 41 * b) + 512) >> 10);

		// Cr, Y and Cb in the place of red, green and blue
		r = cr;
		g = y;
		b = cb;
	}

	prt_vtb_set_og (vtb, PRT_VTB_OG_OSD_COL, ((uint32_t) r << 16) | ((uint32_t) g << 8) | (uint32_t) b);
}

void prt_vtb_set_osd_color (prt_vtb_ds_struct *vtb, uint8_t r, uint8_t g, uint8_t b)
{
	vtb->osd.col[0] = r;
	vtb->osd.col[1] = g;
	vtb->osd.col[2] = b;
	prt_vtb_osd_col_wr (vtb);
}

// Color space of the video (RGB or YCbCr 4:4:4)
// Takes effect at the next start of the test pattern or the clock recovery.
void prt_vtb_set_csf (prt_vtb_ds_struct *vtb, prt_dp_csf_type csf)
{
	vtb->csf = (csf == PRT_DP_CSF_YCBCR444) ? PRT_DP_CSF_YCBCR444 : PRT_DP_CSF_RGB;
	prt_vtb_osd_col_wr (vtb);
}

// Write the on screen display text
// The write pointer in the device moves on by itself, so the pointer is set once and the
// characters are streamed. The whole memory is written: the scroller wraps on its size,
// so anything left of an earlier message would come round again.
void prt_vtb_set_osd_text (prt_vtb_ds_struct *vtb, const char *txt)
{
	// Variables
	uint16_t i;
	char c;
	uint8_t end = 0;

	// Set the write pointer
	vtb->dev->ctl = (0 << PRT_VTB_DEV_CTL_TXT_SHIFT);

	for (i = 0; i < PRT_VTB_OSD_CHARS; i++)
	{
		if (!end && (txt[i] == '\0'))
			end = 1;

		c = end ? ' ' : txt[i];

		// The font is upper case only. This leaves anything above 'z' alone, which is
		// where the logo tiles sit.
		if ((c >= 'a') && (c <= 'z'))
			c = c - 'a' + 'A';

		// Anything the font does not have becomes a space, so an unexpected character
		// leaves a gap instead of a hole in the middle of a word.
		if ((c < 0x20) || (c > 0x7f))
			c = ' ';

		vtb->dev->txt = (uint32_t) c;
	}
}

// FIFO loss of lock capture
// Holds what the fifo looked like at the last loss of lock, and how many there were.
uint32_t prt_vtb_get_fifo_loss (prt_vtb_ds_struct *vtb)
{
	return prt_vtb_get_ig (vtb, PRT_VTB_IG_FIFO_LOSS);
}

// Monitor
// Pixels per line and lines per frame of the incoming video
uint32_t prt_vtb_get_mon (prt_vtb_ds_struct *vtb)
{
	return prt_vtb_get_ig (vtb, PRT_VTB_IG_MON);
}

// On screen display text helpers
// The text is built by hand rather than with snprintf, which pulls in the string
// formatting variant of the library for a few numbers.
// Append, and return where the next piece goes.
static char *prt_vtb_osd_add (char *d, const char *s)
{
	while (*s)
		*d++ = *s++;

	return d;
}

// Append a number in decimal
static char *prt_vtb_osd_num (char *d, uint32_t n)
{
	// Variables
	char tmp[10];
	uint8_t i = 0;

	do
	{
		tmp[i++] = '0' + (n % 10);
		n /= 10;
	} while (n && (i < sizeof (tmp)));

	while (i)
		*d++ = tmp[--i];

	return d;
}

// The colour space in words
static const char *prt_vtb_osd_csf_name (prt_dp_csf_type csf)
{
	switch (csf)
	{
		case PRT_DP_CSF_YCBCR444 : return "YCBCR 4:4:4";
		case PRT_DP_CSF_YCBCR422 : return "YCBCR 4:2:2";
		case PRT_DP_CSF_YCBCR420 : return "YCBCR 4:2:0";
		default                  : return "RGB";
	}
}

// The link rate by its DisplayPort name
static const char *prt_vtb_osd_rate_name (uint8_t rate)
{
	switch (rate)
	{
		case PRT_DP_PHY_LINERATE_1620 : return "RBR";
		case PRT_DP_PHY_LINERATE_2700 : return "HBR";
		case PRT_DP_PHY_LINERATE_5400 : return "HBR2";
		case PRT_DP_PHY_LINERATE_8100 : return "HBR3";
		default                       : return "?";
	}
}

// The refresh rate of a timing, rounded to whole hertz. The pixel clock is in kHz.
uint32_t prt_vtb_osd_hz (uint32_t pclk, uint16_t htotal, uint16_t vtotal)
{
	// Variables
	uint32_t pix = (uint32_t) htotal * vtotal;

	if (pix == 0)
		return 0;

	return ((pclk * 1000) + (pix / 2)) / pix;
}

// On screen display text for DisplayPort video
// Puts the video and the link in the scroller. What goes on the wire is known to the
// application, not to the video toolbox, so all of it is handed in.
// what  : optional first item, for instance the mode; NULL leaves it out
// lanes : link lanes; rate : link rate code (PRT_DP_PHY_LINERATE_*)
void prt_vtb_osd_text (prt_vtb_ds_struct *vtb, const char *what, uint16_t hwidth, uint16_t vheight,
	uint32_t hz, prt_dp_csf_type csf, uint8_t bpc, uint8_t lanes, uint8_t rate)
{
	// Variables
	char txt[PRT_VTB_OSD_CHARS];
	char *p = txt;

	p = prt_vtb_osd_add (p, PRT_VTB_OSD_LOGO " PARRETTO DP *** ");

	if (what)
	{
		p = prt_vtb_osd_add (p, what);
		p = prt_vtb_osd_add (p, " *** ");
	}

	p = prt_vtb_osd_num (p, hwidth);
	*p++ = 'X';
	p = prt_vtb_osd_num (p, vheight);
	*p++ = 'P';
	p = prt_vtb_osd_num (p, hz);
	p = prt_vtb_osd_add (p, " *** ");
	p = prt_vtb_osd_add (p, prt_vtb_osd_csf_name (csf));
	*p++ = ' ';
	p = prt_vtb_osd_num (p, bpc);
	p = prt_vtb_osd_add (p, " BIT *** ");
	p = prt_vtb_osd_add (p, prt_vtb_osd_rate_name (rate));
	*p++ = ' ';
	p = prt_vtb_osd_num (p, lanes);
	p = prt_vtb_osd_add (p, " LANES *** ");
	*p = 0;

	prt_vtb_set_osd_text (vtb, txt);
}

// Clock enable DCO
// The video clock runs faster than the pixel clock, the DCO drops cycles with the clock enable.
// The clock recovery corrects the increment: increment = base + (controller output >> shift).
// The fraction of enabled cycles is increment / 2^32.
void prt_vtb_dco (prt_vtb_ds_struct *vtb, uint8_t en, uint8_t inv, uint8_t shift, uint32_t base)
{
	// Variables
	uint32_t dat;

	// Base increment
	prt_vtb_set_og (vtb, PRT_VTB_OG_DCO_BASE, base);

	// Control
	dat = ((uint32_t) (shift & 0x1f) << PRT_VTB_OG_DCO_SHIFT_SHIFT);
	if (inv)
		dat |= PRT_VTB_OG_DCO_INV;
	if (en)
		dat |= PRT_VTB_OG_DCO_EN;
	prt_vtb_set_og (vtb, PRT_VTB_OG_DCO, dat);
}

// Current increment of the clock enable DCO
uint32_t prt_vtb_get_dco_inc (prt_vtb_ds_struct *vtb)
{
	return prt_vtb_get_ig (vtb, PRT_VTB_IG_DCO_INC);
}
