/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Video Toolbox header
    (c) 2021 - 2024 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Added video resolution 7680X4320P30
    v1.2 - Added video resolution 5120X2160P60
    v1.3 - Added YCbCr 4:4:4

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
#include "prt_dp_drv.h"

// Defines
#define PRT_VTB_DEV_CTL_IG_SHIFT		0
#define PRT_VTB_DEV_CTL_OG_SHIFT		8
#define PRT_VTB_DEV_CTL_VPS_SHIFT		16
#define PRT_VTB_DEV_CTL_TXT_SHIFT		20

// Ingress
#define PRT_VTB_IG_TX_LNK_CLK_FREQ		0
#define PRT_VTB_IG_RX_LNK_CLK_FREQ		1
#define PRT_VTB_IG_VID_REF_FREQ		2
#define PRT_VTB_IG_VID_CLK_FREQ		3
#define PRT_VTB_IG_CR_ERR			4
#define PRT_VTB_IG_CR_SUM			5
#define PRT_VTB_IG_CR_CO				6
#define PRT_VTB_IG_FIFO				7
#define PRT_VTB_IG_MON				8
#define PRT_VTB_IG_FIFO_LOSS			9
#define PRT_VTB_IG_DCO_INC			10		// Current increment of the clock enable DCO

#define PRT_VTB_IG_CR_ERR_CUR_SHIFT	0
#define PRT_VTB_IG_CR_ERR_MAX_SHIFT	8
#define PRT_VTB_IG_CR_ERR_MIN_SHIFT	16
#define PRT_VTB_IG_FIFO_MAX_WRDS_SHIFT	0
#define PRT_VTB_IG_FIFO_MIN_WRDS_SHIFT	10
#define PRT_VTB_IG_FIFO_LOCK			(1 << 20)
#define PRT_VTB_IG_MON_PIX_SHIFT		0		// Counted two per valid, whatever the pixels per clock
#define PRT_VTB_IG_MON_LIN_SHIFT		16
#define PRT_VTB_IG_FIFO_LOSS_WRDS_SHIFT	0		// Words in the fifo when the lock went
#define PRT_VTB_IG_FIFO_LOSS_LIN_SHIFT	10		// Timing generator line since vsync
#define PRT_VTB_IG_FIFO_LOSS_FL			(1 << 22)	// The fifo was full
#define PRT_VTB_IG_FIFO_LOSS_EP			(1 << 23)	// The fifo was empty
#define PRT_VTB_IG_FIFO_LOSS_CNT_SHIFT	24		// Number of losses

// Outgress
#define PRT_VTB_OG_CTL				0
#define PRT_VTB_OG_CR				1
#define PRT_VTB_OG_OSD_COL			2
#define PRT_VTB_OG_DCO				3		// Clock enable DCO control (gateware with P_DCO)
#define PRT_VTB_OG_DCO_BASE			4		// Clock enable DCO base increment

#define PRT_VTB_OG_DCO_EN				(1 << 0)
#define PRT_VTB_OG_DCO_INV			(1 << 4)
#define PRT_VTB_OG_DCO_SHIFT_SHIFT	8

#define PRT_VTB_OG_CTL_LNK_EN			(1 << 0)
#define PRT_VTB_OG_CTL_VID_EN			(1 << 1) 
#define PRT_VTB_OG_CTL_CG_RUN			(1 << 2)
#define PRT_VTB_OG_CTL_TG_RUN			(1 << 3)
#define PRT_VTB_OG_CTL_TG_MODE		(1 << 4)
#define PRT_VTB_OG_CTL_TPG_RUN		(1 << 5)
#define PRT_VTB_OG_CTL_TPG_FMT_SHIFT	(6)
#define PRT_VTB_OG_CTL_FIFO_RUN		(1 << 9)
#define PRT_VTB_OG_CTL_OVL_RUN		(1 << 10)
#define PRT_VTB_OG_CTL_CR_RUN			(1 << 11)
#define PRT_VTB_OG_CTL_OSD_RUN		(1 << 12)
#define PRT_VTB_OG_CTL_OSD_AMP_SHIFT	(13)
#define PRT_VTB_OG_CTL_OSD_SPD_SHIFT	(16)
#define PRT_VTB_OG_CTL_OSD_MODE_SHIFT	(20)
#define PRT_VTB_OG_CTL_CSF				(1 << 22)		// Color space. 0 - RGB, 1 - YCbCr 4:4:4

// Colour modes of the scroller
#define PRT_VTB_OSD_MODE_PLAIN		0	// The colour set with prt_vtb_set_osd_color
#define PRT_VTB_OSD_MODE_BANDS		1	// A rainbow across the height of the text
#define PRT_VTB_OSD_MODE_CHARS		2	// A rainbow along the characters

// On screen display
// The scroller wraps on the whole memory, so a shorter message is padded with spaces
// rather than ended early - otherwise the tail of the previous one keeps coming round.
// The scroller is only there when the gateware is built with P_OSD; without it the
// writes below go nowhere and do no harm.
#define PRT_VTB_OSD_CHARS				128

// The Parretto mark, as two tiles of the font. Above 'z' on purpose: the upper case fold
// in prt_vtb_set_osd_text stops at 'z', so these come through untouched.
#define PRT_VTB_OSD_LOGO				"\x7b\x7c"

#define PRT_VTB_OG_CR_P_GAIN_SHIFT		0
#define PRT_VTB_OG_CR_I_GAIN_SHIFT		8

// VPS
#define PRT_VTB_VPS_REFCLK_HI			0
#define PRT_VTB_VPS_REFCLK_LO			1
#define PRT_VTB_VPS_VIDCLK_HI			2
#define PRT_VTB_VPS_VIDCLK_LO			3
#define PRT_VTB_VPS_HTOTAL			4
#define PRT_VTB_VPS_HWIDTH			5
#define PRT_VTB_VPS_HSTART			6
#define PRT_VTB_VPS_HSW				7
#define PRT_VTB_VPS_VTOTAL			8
#define PRT_VTB_VPS_VHEIGHT			9   
#define PRT_VTB_VPS_VSTART			10
#define PRT_VTB_VPS_VSW				11

// Video timing
#define VTB_PRESET_1280X720P50          1
#define VTB_PRESET_1280X720P60          2
#define VTB_PRESET_1920X1080P50         3
#define VTB_PRESET_1920X1080P60         4
#define VTB_PRESET_2560X1440P50         5
#define VTB_PRESET_2560X1440P60         6
#define VTB_PRESET_3840X2160P50         7
#define VTB_PRESET_3840X2160P60         8
#define VTB_PRESET_5120X2160P60         9
#define VTB_PRESET_7680X4320P30         10
#define VTB_PRESET_720X1920P60          11
#define VTB_PRESET_7680X1260P60         12

// 1280 x 720p @ 50Hz
#define VTB_1280X720P50_HTOTAL 		1980
#define VTB_1280X720P50_HWIDTH 		1280
#define VTB_1280X720P50_HSTART 		260
#define VTB_1280X720P50_HSW 			40
#define VTB_1280X720P50_VTOTAL 		750
#define VTB_1280X720P50_VHEIGHT 		720
#define VTB_1280X720P50_VSTART 		25
#define VTB_1280X720P50_VSW 			5
#define VTB_1280X720P50_PCLK 			74250

// 1280 x 720p @ 60Hz
#define VTB_1280X720P60_HTOTAL 		1652
#define VTB_1280X720P60_HWIDTH 		1280
#define VTB_1280X720P60_HSTART 		260
#define VTB_1280X720P60_HSW 			40
#define VTB_1280X720P60_VTOTAL 		750
#define VTB_1280X720P60_VHEIGHT 		720
#define VTB_1280X720P60_VSTART 		25
#define VTB_1280X720P60_VSW 			5
#define VTB_1280X720P60_PCLK            74250 			

// 1920 x 1080 @ 50 Hz
#define VTB_1920X1080P50_HTOTAL         2640
#define VTB_1920X1080P50_HWIDTH         1920
#define VTB_1920X1080P50_HSTART         192
#define VTB_1920X1080P50_HSW            44
#define VTB_1920X1080P50_VTOTAL         1125
#define VTB_1920X1080P50_VHEIGHT        1080
#define VTB_1920X1080P50_VSTART         41
#define VTB_1920X1080P50_VSW            5
#define VTB_1920X1080P50_PCLK           148500

// 1920 x 1080 @ 60 Hz
#define VTB_1920X1080P60_HTOTAL         2200
#define VTB_1920X1080P60_HWIDTH         1920
#define VTB_1920X1080P60_HSTART         192
#define VTB_1920X1080P60_HSW            44
#define VTB_1920X1080P60_VTOTAL         1125
#define VTB_1920X1080P60_VHEIGHT        1080
#define VTB_1920X1080P60_VSTART         41
#define VTB_1920X1080P60_VSW            5
#define VTB_1920X1080P60_PCLK           148500

// 2560 x 1440p @ 50Hz
#define VTB_2560X1440P50_HTOTAL 		3960
#define VTB_2560X1440P50_HWIDTH 		2560
#define VTB_2560X1440P50_HSTART 		520
#define VTB_2560X1440P50_HSW 			80
#define VTB_2560X1440P50_VTOTAL 		1500
#define VTB_2560X1440P50_VHEIGHT 		1440
#define VTB_2560X1440P50_VSTART 		50
#define VTB_2560X1440P50_VSW 			10
#define VTB_2560X1440P50_PCLK 		297000

// 2560 x 1440p @ 60Hz
#define VTB_2560X1440P60_HTOTAL 		3304
#define VTB_2560X1440P60_HWIDTH 		2560
#define VTB_2560X1440P60_HSTART 		520
#define VTB_2560X1440P60_HSW 			80
#define VTB_2560X1440P60_VTOTAL 		1500
#define VTB_2560X1440P60_VHEIGHT 		1440
#define VTB_2560X1440P60_VSTART 		50
#define VTB_2560X1440P60_VSW 			10
#define VTB_2560X1440P60_PCLK 		297000

// 3840 x 2160p @ 50Hz
#define VTB_3840X2160P50_HTOTAL 		5280
#define VTB_3840X2160P50_HWIDTH 		3840
#define VTB_3840X2160P50_HSTART 		384
#define VTB_3840X2160P50_HSW 			88
#define VTB_3840X2160P50_VTOTAL 		2250
#define VTB_3840X2160P50_VHEIGHT 		2160
#define VTB_3840X2160P50_VSTART 		82
#define VTB_3840X2160P50_VSW 			10
#define VTB_3840X2160P50_PCLK 		594000

// 3840 x 2160p @ 60Hz
#define VTB_3840X2160P60_HTOTAL 		4400
#define VTB_3840X2160P60_HWIDTH 		3840
#define VTB_3840X2160P60_HSTART 		384
#define VTB_3840X2160P60_HSW 			88
#define VTB_3840X2160P60_VTOTAL 		2250
#define VTB_3840X2160P60_VHEIGHT 		2160
#define VTB_3840X2160P60_VSTART 		82
#define VTB_3840X2160P60_VSW 			10
#define VTB_3840X2160P60_PCLK           594000

// 7680 x 4320p @ 30Hz (RB2)
#define VTB_7680X4320P30_HTOTAL 		7760
#define VTB_7680X4320P30_HWIDTH 		7680
#define VTB_7680X4320P30_HSTART 		72
#define VTB_7680X4320P30_HSW 			32
#define VTB_7680X4320P30_VTOTAL 		4381
#define VTB_7680X4320P30_VHEIGHT 		4320
#define VTB_7680X4320P30_VSTART 		14
#define VTB_7680X4320P30_VSW 			8
#define VTB_7680X4320P30_PCLK 		1019896

// 720 x 1920 @ 60 Hz
#define VTB_720X1920P60_HTOTAL         792
#define VTB_720X1920P60_HWIDTH         720
#define VTB_720X1920P60_HSTART         48
#define VTB_720X1920P60_HSW            14
#define VTB_720X1920P60_VTOTAL         1968
#define VTB_720X1920P60_VHEIGHT        1920
#define VTB_720X1920P60_VSTART         16
#define VTB_720X1920P60_VSW            4
#define VTB_720X1920P60_PCLK           93500000

// 7680 x 1260p @ 60Hz (RB2)
#define VTB_7680X1260P60_HTOTAL 		7840
#define VTB_7680X1260P60_HWIDTH 		7680
#define VTB_7680X1260P60_HSTART 		112
#define VTB_7680X1260P60_HSW 			32
#define VTB_7680X1260P60_VTOTAL 		1296
#define VTB_7680X1260P60_VHEIGHT 		1260
#define VTB_7680X1260P60_VSTART 		33
#define VTB_7680X1260P60_VSW 			10
#define VTB_7680X1260P60_PCLK 		609638

// TPG format
#define VTB_TPG_FMT_FULL                0
#define VTB_TPG_FMT_RED                 1
#define VTB_TPG_FMT_GREEN               2
#define VTB_TPG_FMT_BLUE                3
#define VTB_TPG_FMT_RAMP                4

// Device structure
typedef struct {
	uint32_t ctl;
	uint32_t ig;		// Ingress 
	uint32_t og;		// Outgress
	uint32_t vps;		// Video parameters
	uint32_t txt;		// On screen display text
} prt_vtb_dev_struct;

// Timing parameters
typedef struct {
	uint32_t mvid;
	uint32_t nvid;
	uint16_t htotal;
	uint16_t hwidth;
	uint16_t hstart;
	uint16_t hsw;
	uint16_t vtotal;
	uint16_t vheight;
	uint16_t vstart;
	uint16_t vsw;
	uint8_t misc0;
	uint8_t misc1;
    uint32_t pclk;
} prt_vtb_tp_struct;

// On screen display settings
// Kept here because prt_vtb_tpg and prt_vtb_cr compose the whole control word from
// scratch every time they start. Without a copy the scroller would switch itself off on
// every format change and on every switch to pass-through.
typedef struct {
	uint8_t en;			// Scroller on
	uint8_t amp;		// Bounce amplitude. Shift on the sine, 0 is the largest
	uint8_t spd;		// Bounce speed. Sine phase step per frame
	uint8_t mode;		// Colour mode
	uint8_t col[3];		// Plain colour, red, green and blue
} prt_vtb_osd_struct;

// Data structure
typedef struct {
	volatile prt_vtb_dev_struct 	*dev;	// Device
	uint32_t 					refclk;	// Reference clock
	uint32_t 					vidclk;	// Video clock
	prt_vtb_tp_struct 			tp;		// Timing parameters
	prt_vtb_osd_struct 			osd;	// On screen display
	prt_dp_csf_type 			csf;	// Color space of the video (RGB or YCbCr 4:4:4)
} prt_vtb_ds_struct;

// Prototypes
void prt_vtb_set_base (prt_vtb_ds_struct *vtb, uint32_t base);
void prt_vtb_set_refclk (prt_vtb_ds_struct *vtb, uint32_t clk);
void prt_vtb_set_vidclk (prt_vtb_ds_struct *vtb, uint32_t clk);
void prt_vtb_set_tp (prt_vtb_ds_struct *vtb, prt_vtb_tp_struct *tp, uint8_t preset);
uint32_t prt_vtb_get_ig (prt_vtb_ds_struct *vtb, uint8_t ig);
void prt_vtb_set_og (prt_vtb_ds_struct *vtb, uint8_t og, uint32_t dat);
uint32_t prt_vtb_get_og (prt_vtb_ds_struct *vtb, uint8_t og);
void prt_vtb_set_vps (prt_vtb_ds_struct *vtb, uint8_t vps, uint32_t dat);
prt_vtb_tp_struct prt_vtb_get_tp (prt_vtb_ds_struct *vtb);
void prt_vtb_tpg (prt_vtb_ds_struct *vtb, prt_vtb_tp_struct *tp, uint8_t preset, uint8_t fmt);
uint8_t prt_vtb_find_preset (uint16_t htotal, uint16_t vtotal, uint32_t *pclk);

// FIFO
uint8_t prt_vtb_get_fifo_lock (prt_vtb_ds_struct *vtb);
uint16_t prt_vtb_get_fifo_max_wrds (prt_vtb_ds_struct *vtb);
uint16_t prt_vtb_get_fifo_min_wrds (prt_vtb_ds_struct *vtb);
uint32_t prt_vtb_get_fifo_loss (prt_vtb_ds_struct *vtb);
uint32_t prt_vtb_get_mon (prt_vtb_ds_struct *vtb);

// Clock recovery
void prt_vtb_cr (prt_vtb_ds_struct *vtb, prt_vtb_tp_struct *tp, uint8_t preset);
void prt_vtb_cr_set_p_gain (prt_vtb_ds_struct *vtb, uint8_t gain);
void prt_vtb_cr_set_i_gain (prt_vtb_ds_struct *vtb, uint16_t gain);
prt_s8 prt_vtb_get_cr_cur_err (prt_vtb_ds_struct *vtb);
prt_s8 prt_vtb_get_cr_max_err (prt_vtb_ds_struct *vtb);
prt_s8 prt_vtb_get_cr_min_err (prt_vtb_ds_struct *vtb);
prt_s16 prt_vtb_get_cr_sum (prt_vtb_ds_struct *vtb);
prt_s32 prt_vtb_get_cr_co (prt_vtb_ds_struct *vtb);
void prt_vtb_dco (prt_vtb_ds_struct *vtb, uint8_t en, uint8_t inv, uint8_t shift, uint32_t base);
uint32_t prt_vtb_get_dco_inc (prt_vtb_ds_struct *vtb);

// Frequency
uint32_t prt_vtb_get_tx_lnk_clk_freq (prt_vtb_ds_struct *vtb);
uint32_t prt_vtb_get_rx_lnk_clk_freq (prt_vtb_ds_struct *vtb);
uint32_t prt_vtb_get_vid_ref_freq (prt_vtb_ds_struct *vtb);
uint32_t prt_vtb_get_vid_clk_freq (prt_vtb_ds_struct *vtb);

// Overlay
void prt_vtb_ovl_en (prt_vtb_ds_struct *vtb, uint8_t en);

// On screen display
void prt_vtb_set_osd (prt_vtb_ds_struct *vtb, uint8_t en, uint8_t amp, uint8_t spd);
void prt_vtb_set_osd_mode (prt_vtb_ds_struct *vtb, uint8_t mode);
void prt_vtb_set_osd_color (prt_vtb_ds_struct *vtb, uint8_t r, uint8_t g, uint8_t b);
void prt_vtb_set_csf (prt_vtb_ds_struct *vtb, prt_dp_csf_type csf);
void prt_vtb_set_osd_text (prt_vtb_ds_struct *vtb, const char *txt);
uint32_t prt_vtb_osd_hz (uint32_t pclk, uint16_t htotal, uint16_t vtotal);
void prt_vtb_osd_text (prt_vtb_ds_struct *vtb, const char *what, uint16_t hwidth, uint16_t vheight,
	uint32_t hz, prt_dp_csf_type csf, uint8_t bpc, uint8_t lanes, uint8_t rate);
