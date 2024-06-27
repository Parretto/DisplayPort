/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP Driver header
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

// Includes
#include "prt_types.h"
#include <stdint.h>

// ID
#define PRT_DPTX_ID 							0
#define PRT_DPRX_ID 							1

// Control
#define PRT_DP_CTL_RUN							(1<<0)
#define PRT_DP_CTL_IE							(1<<1)
#define PRT_DP_CTL_MEM_STR						(1<<2)
#define PRT_DP_CTL_MEM_SEL						(1<<3)
#define PRT_DP_CTL_MAIL_OUT_EN					(1<<4)
#define PRT_DP_CTL_MAIL_IN_EN					(1<<5)
#define PRT_DP_CTL_AUX_EN						(1<<6)

// Status
#define PRT_DP_STA_IRQ  		 		  		(1<<0)
#define PRT_DP_STA_MAIL_OUT_EP    				(1<<1)
#define PRT_DP_STA_MAIL_OUT_OF 	  				(1<<2)
#define PRT_DP_STA_MAIL_IN_EP	    			(1<<3)
#define PRT_DP_STA_MAIL_IN_OF	    			(1<<4)
#define PRT_DP_STA_AUX_EP    	    			(1<<5)
#define PRT_DP_STA_AUX_OF    	    			(1<<6)
#define PRT_DP_STA_MAIL_OUT_WRDS_SHIFT 			8
#define PRT_DP_STA_MAIL_IN_WRDS_SHIFT 			16
#define PRT_DP_STA_AUX_WRDS_SHIFT 				24

// Events
#define PRT_DP_EVT_OK							(1<<0)
#define PRT_DP_EVT_ERR							(1<<1)
#define PRT_DP_EVT_HPD							(1<<2)
#define PRT_DP_EVT_STA							(1<<3)
#define PRT_DP_EVT_PHY_RATE						(1<<4)
#define PRT_DP_EVT_PHY_VAP						(1<<5)
#define PRT_DP_EVT_TRN							(1<<6)
#define PRT_DP_EVT_LNK							(1<<7)
#define PRT_DP_EVT_VID							(1<<8)
#define PRT_DP_EVT_MSA							(1<<9)
#define PRT_DP_EVT_DEBUG						(1<<10)
#define PRT_DP_EVT_EDID							(1<<11)

// Line rate
#define PRT_DP_PHY_LINERATE_1620		0x06
#define PRT_DP_PHY_LINERATE_2700		0x0a
#define PRT_DP_PHY_LINERATE_5400		0x14
#define PRT_DP_PHY_LINERATE_8100		0x1e

// Video resolution
#define PRT_DP_VID_RES_RX				0
#define PRT_DP_VID_RES_480P60			1
#define PRT_DP_VID_RES_720P50			2
#define PRT_DP_VID_RES_720P60			3
#define PRT_DP_VID_RES_1080P50			4
#define PRT_DP_VID_RES_1080P60			5
#define PRT_DP_VID_RES_4KP50			6
#define PRT_DP_VID_RES_4KP60			7

// AUX
#define PRT_AUX_REQ_STR        		0x100
#define PRT_AUX_REQ_STP        		0x101
#define PRT_AUX_REPLY_STR      		0x102
#define PRT_AUX_REPLY_STP      		0x103
#define PRT_AUX_CMD_WR  	    	0x8
#define PRT_AUX_CMD_RD  	    	0x9
#define PRT_AUX_REPLY_ACK 	   		0x0
#define PRT_AUX_REPLY_NACK     		0x1
#define PRT_AUX_REPLY_DEFER    		0x2

// Enum HPD
typedef enum {PRT_DP_HPD_UNPLUG, PRT_DP_HPD_PLUG, PRT_DP_HPD_IRQ} prt_dp_hpd_type;

// Typedef callback
typedef void (*prt_dp_cb)(void *CallbackRef);

// Enum callback registration types
typedef enum {
	PRT_DP_CB_HPD, 
	PRT_DP_CB_STA, 
	PRT_DP_CB_TRN, 
	PRT_DP_CB_PHY_RATE, 
	PRT_DP_CB_PHY_VAP, 
	PRT_DP_CB_LNK, 
	PRT_DP_CB_VID, 
	PRT_DP_CB_MSA, 
	PRT_DP_CB_DBG
} prt_dp_cb_type;

// Device structure
typedef struct {
  uint32_t ctl; 			// Control
  uint32_t sta; 			// Status
  uint32_t mail_out;		// Mail out (pm -> host)
  uint32_t mail_in; 		// Mail in (host -> pm)
  uint32_t aux; 			// AUX
  uint32_t mem; 			// Memory update
} prt_dp_dev_struct;

// Status
typedef struct {
	uint8_t hw_ver_major;
	uint8_t hw_ver_minor;
	uint8_t sw_ver_major;
	uint8_t sw_ver_minor;
	uint8_t mst;
	uint8_t pio;
	uint8_t hpd;
	uint8_t lnk_up;
	uint8_t lnk_act_lanes;
	uint8_t lnk_act_rate;
	uint8_t vid_up;
} prt_dp_sta_struct;

// Training
typedef struct {
	uint8_t pass;
	uint8_t fail;
	uint8_t cr;
} prt_dp_trn_struct;

// Mail structure
typedef struct {
	volatile prt_bool ok;			// Ok flag
	volatile prt_bool err;		// Error flag
	prt_bool proc;		// Process
	uint8_t dat[32]; 	// Data
	uint8_t len;  			// Length
} prt_dp_mail_ds_struct;

// AUX structure
typedef struct {
	uint8_t proc;		// Process
	uint16_t dat[32]; 	// Data
	uint8_t len;  		// Length
} prt_dp_aux_ds_struct;

// EDID structure
typedef struct {
	uint8_t dat[1024]; 	// Data
	uint16_t adr;		// Address
} prt_dp_edid_struct;

// Timing parameters
typedef struct {
	uint32_t mvid;
	uint32_t nvid;
	uint16_t htotal;		// Horizontal total
	uint16_t hwidth;		// Horizontal width
	uint16_t hstart;		// Horizontal start
	uint16_t hsw;			// Horizontal sync width
	uint16_t vtotal;		// Vertical total
	uint16_t vheight;		// Vertical height
	uint16_t vstart;		// Vertical start
	uint16_t vsw;			// Vertical sync width
	uint8_t bpc;			// Bits per component
} prt_dp_tp_struct;

// Link
typedef struct {
	uint8_t up;				// Link up flag
	uint8_t max_lanes;		// Max lanes
	uint8_t max_rate;		// Max rate
	uint8_t act_lanes;		// Active lanes
	uint8_t act_rate;		// Active rate
	uint8_t phy_rate;		// PHY rate
	uint8_t phy_ssc;		// PHY spread spectrum clocking
	uint8_t phy_volt;		// PHY voltage
	uint8_t phy_pre;		// PHY pre-amble
	uint8_t reason;			// Link down reason
	prt_bool mst_cap;		// MST capability
} prt_dp_lnk_struct;

// Video
typedef struct {
	prt_bool 			evt;	// Event
	uint8_t 			up;		// Video up flag
	uint8_t 			reason;	// Video down reason
	prt_dp_tp_struct 	tp;		// Timing parameters
} prt_dp_vid_struct;

// Debug
typedef struct {
	uint8_t 		head;			// Head pointer
	uint8_t 		tail;			// Tail pointer
	uint8_t 		dat[32];	// Data
} prt_dp_debug_struct;

// Call back
typedef struct {
	prt_dp_cb		hpd;		// HPD Callback
	prt_dp_cb		sta;		// Status Callback
	prt_dp_cb		trn;		// Training Callback
	prt_dp_cb		phy_rate;	// PHY rate Callback
	prt_dp_cb		phy_vap;	// PHY voltage and preamble Callback
	prt_dp_cb		lnk;		// Link Callback
	prt_dp_cb		vid;		// Video Callback
	prt_dp_cb		msa;		// MSA Callback
	prt_dp_cb		dbg;		// Debug Callback
} prt_dp_cb_struct;

// Data structure
typedef struct {
	uint8_t 								id;
	volatile prt_dp_dev_struct 				*dev;			// Device
	prt_dp_mail_ds_struct 					mail_in;		// Mail in
	prt_dp_mail_ds_struct 					mail_out;		// Mail out
	volatile prt_dp_debug_struct			debug;			// Debug
	volatile uint32_t 						evt;			// Event
	prt_dp_cb_struct						cb;				// Callback
	prt_dp_sta_struct						sta;			// Status
	prt_dp_trn_struct						trn;			// Training
	prt_dp_hpd_type 						hpd;			// HPD
	prt_dp_lnk_struct						lnk;			// Link
	prt_dp_vid_struct						vid[2];			// Video
	prt_dp_edid_struct						edid;			// EDID
#ifdef PRT_SIM
	prt_dp_aux_ds_struct					aux;			// AUX
#endif
} prt_dp_ds_struct;

// Parameters

// Prototypes
// Shared
void prt_dp_set_base (prt_dp_ds_struct *dp, uint32_t base);
void prt_dp_set_cb (prt_dp_ds_struct *dp, prt_dp_cb_type cb_type, void *cb_handler);
void prt_dp_rom_init (prt_dp_ds_struct *dp, uint32_t len, uint8_t *rom);
void prt_dp_ram_init (prt_dp_ds_struct *dp, uint32_t len, uint8_t *ram);
void prt_dp_init (prt_dp_ds_struct *dp, uint8_t id);
uint8_t prt_dp_ping (prt_dp_ds_struct *dp);
uint8_t prt_dp_lic (prt_dp_ds_struct *dp, char *lic);
void prt_dp_set_lnk_max_lanes (prt_dp_ds_struct *dp, uint8_t lanes);
void prt_dp_set_lnk_max_rate (prt_dp_ds_struct *dp, uint8_t rate);
uint8_t prt_dp_cfg (prt_dp_ds_struct *dp);
void prt_dp_sta (prt_dp_ds_struct *dp);
uint8_t prt_dp_run (prt_dp_ds_struct *dp);
void prt_dp_lnk_req_ok (prt_dp_ds_struct *dp);
uint8_t prt_dp_vid_str (prt_dp_ds_struct *dp, uint8_t stream);
uint8_t prt_dp_vid_stp (prt_dp_ds_struct *dp, uint8_t stream);
uint8_t prt_dp_get_phy_rate (prt_dp_ds_struct *dp);
uint8_t prt_dp_get_phy_ssc (prt_dp_ds_struct *dp);
uint8_t prt_dp_get_phy_volt (prt_dp_ds_struct *dp);
uint8_t prt_dp_get_phy_pre (prt_dp_ds_struct *dp);

// DPTX
uint8_t prt_dptx_msa_set (prt_dp_ds_struct *dp, prt_dp_tp_struct *tp, uint8_t stream);
uint8_t prt_dptx_dpcd_wr (prt_dp_ds_struct *dp, uint32_t adr, uint8_t dat);
uint8_t prt_dptx_dpcd_rd (prt_dp_ds_struct *dp, uint32_t adr, uint8_t *dat);
uint8_t prt_dptx_mst_str (prt_dp_ds_struct *dp);
uint8_t prt_dptx_mst_stp (prt_dp_ds_struct *dp);
uint8_t prt_dptx_trn (prt_dp_ds_struct *dp);

// DPRX
prt_dp_tp_struct prt_dprx_tp_get (prt_dp_ds_struct *dp);
uint8_t prt_dprx_edid_wr (prt_dp_ds_struct *dp, uint16_t len);
void prt_dprx_trn_cr_ack (prt_dp_ds_struct *dp);

// Internal
void prt_dp_irq_handler (prt_dp_ds_struct *dp);
uint8_t prt_dptx_aux_test (prt_dp_ds_struct *dp, uint8_t run);
uint8_t prt_dptx_phy_test (prt_dp_ds_struct *dp, uint8_t tps, uint8_t volt, uint8_t pre);
void prt_dp_mail_send (prt_dp_ds_struct *dp);
uint8_t prt_dp_mail_chk (prt_dp_ds_struct *dp);
void prt_dp_get_mail (prt_dp_ds_struct *dp, uint8_t len);
void prt_dp_mail_dec (prt_dp_ds_struct *dp);
uint8_t prt_dp_mail_resp (prt_dp_ds_struct *dp);
uint8_t prt_dp_hpd_get (prt_dp_ds_struct *dp);
uint8_t prt_dp_is_hpd (prt_dp_ds_struct *dp);
uint8_t prt_dp_is_lnk_up (prt_dp_ds_struct *dp);
uint8_t prt_dp_get_lnk_act_lanes (prt_dp_ds_struct *dp);
uint8_t prt_dp_get_lnk_act_rate (prt_dp_ds_struct *dp);
uint8_t prt_dp_get_lnk_reason (prt_dp_ds_struct *dp);
void prt_dp_set_mst_cap (prt_dp_ds_struct *dp, uint8_t cap);
uint8_t prt_dp_is_vid_up (prt_dp_ds_struct *dp, uint8_t stream);
uint8_t prt_dp_get_vid_reason (prt_dp_ds_struct *dp, uint8_t stream);
uint8_t prt_dp_is_trn_pass (prt_dp_ds_struct *dp);
uint8_t prt_dp_is_trn_cr (prt_dp_ds_struct *dp);
uint8_t prt_dptx_edid_rd (prt_dp_ds_struct *dp);
uint8_t prt_dp_log (prt_dp_ds_struct *dp, char *log);
uint8_t prt_dp_is_evt (prt_dp_ds_struct *dp, uint32_t evt);
uint8_t prt_dprx_hpd (prt_dp_ds_struct *dp, uint8_t hpd);
prt_dp_sta_struct prt_dp_get_sta (prt_dp_ds_struct *dp);
uint8_t prt_dp_get_id (prt_dp_ds_struct *dp);
uint8_t prt_dp_get_edid_dat (prt_dp_ds_struct *dp, uint8_t index);
void prt_dp_set_edid_dat (prt_dp_ds_struct *dp, uint16_t adr, uint8_t dat);
void prt_dp_debug_put (prt_dp_ds_struct *dp, uint8_t dat);
uint8_t prt_dp_debug_get (prt_dp_ds_struct *dp);

// Simulation
#ifdef PRT_SIM
uint8_t prt_dp_check_aux (prt_dp_ds_struct *dp);
void prt_dp_get_aux (prt_dp_ds_struct *dp, uint8_t len);
void prt_dp_decode_aux (prt_dp_ds_struct *dp);
uint8_t prt_dprx_skip_trn (prt_dp_ds_struct *dp);
#endif

