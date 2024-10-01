/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP Driver
    (c) 2021 - 2024 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
	v1.1 - Added MST support
	v1.2 - Added 10-bits video support
	v1.3 - Increased EDID size to 1024 bytes
	v1.4 - Added training clock recovery signaling

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
#include "prt_printf.h"
#include "prt_dp_tokens.h"
#include "prt_dp_drv.h"

// Set base address
// This function returns true when the DP peripheral is found.
uint8_t prt_dp_set_base (prt_dp_ds_struct *dp, uint32_t base)
{
	// Variables
	uint8_t sta = PRT_FALSE;

	// Set base address
	dp->dev = (prt_dp_dev_struct *) base;

	// Check if we can read the identificaiton register
	if (dp->dev->id == 0x00004d47)
		sta = PRT_TRUE;

	return sta;
}

// Set event callback
void prt_dp_set_cb (prt_dp_ds_struct *dp, prt_dp_cb_type cb_type, void *cb_handler)
{
	switch (cb_type)
	{
		case PRT_DP_CB_HPD 		: dp->cb.hpd = (prt_dp_cb)cb_handler; break;
		case PRT_DP_CB_STA 		: dp->cb.sta = (prt_dp_cb)cb_handler; break; 
		case PRT_DP_CB_TRN 		: dp->cb.trn = (prt_dp_cb)cb_handler; break; 
		case PRT_DP_CB_PHY_RATE : dp->cb.phy_rate = (prt_dp_cb)cb_handler; break; 
		case PRT_DP_CB_PHY_VAP 	: dp->cb.phy_vap = (prt_dp_cb)cb_handler; break; 
		case PRT_DP_CB_LNK 		: dp->cb.lnk = (prt_dp_cb)cb_handler; break; 
		case PRT_DP_CB_VID 		: dp->cb.vid = (prt_dp_cb)cb_handler; break; 
		case PRT_DP_CB_MSA 		: dp->cb.msa = (prt_dp_cb)cb_handler; break;
		case PRT_DP_CB_DBG 		: dp->cb.dbg = (prt_dp_cb)cb_handler; break;
		default : break;
	}
}

// Initialize
void prt_dp_init (prt_dp_ds_struct *dp, uint8_t id)
{
	// Variables
	uint32_t dat;

	// Set ID
	dp->id = id;

	// Clear flags
	dp->evt = 0;
	dp->cb.hpd = 0;
	dp->cb.sta = 0;
	dp->cb.trn = 0;
	dp->cb.phy_rate = 0;
	dp->cb.phy_vap = 0;
	dp->cb.lnk = 0;
	dp->cb.vid = 0;
	dp->cb.msa = 0;
	dp->mail_in.err = PRT_FALSE;
	dp->mail_in.ok = PRT_FALSE;
	dp->mail_in.proc = PRT_FALSE;
	dp->trn.pass = PRT_FALSE;
	dp->trn.fail = PRT_FALSE;
	dp->trn.cr = PRT_FALSE;
	dp->hpd = PRT_DP_HPD_UNPLUG;
	dp->lnk.phy_rate = 0;
	dp->lnk.phy_ssc = 0;
	dp->lnk.up = PRT_FALSE;
	dp->lnk.mst_cap = PRT_FALSE;
	dp->vid[0].up = PRT_FALSE;
	dp->vid[0].evt = PRT_FALSE;
	dp->vid[1].up = PRT_FALSE;
	dp->vid[1].evt = PRT_FALSE;
	dp->debug.head = 0;
	dp->debug.tail = 0;
	
	// Enable mail_out and mail_in boxes
	// Enable interrupt and start policy maker
	dat = PRT_DP_CTL_RUN | PRT_DP_CTL_IE | PRT_DP_CTL_MAIL_IN_EN | PRT_DP_CTL_MAIL_OUT_EN;

	// Simulation
	#ifdef PRT_SIM
    		// Enable aux boxes for dptx
		if (id == PRT_DPTX_ID)
    			dat |= PRT_DP_CTL_AUX_EN; 
    #endif

    	// Write control
	dp->dev->ctl = dat;
}

// Ping
uint8_t prt_dp_ping (prt_dp_ds_struct *dp)
{
	// Variables
	uint8_t sta;

	dp->mail_out.len = 0;
	dp->mail_out.dat[dp->mail_out.len++] = PRT_DP_MAIL_PING;	// Ping token
	prt_dp_mail_send (dp);

	// Wait for response
	sta = prt_dp_mail_resp (dp);
	return sta;
}

// License key
uint8_t prt_dp_lic (prt_dp_ds_struct *dp, char *lic)
{
	// Variables
	uint8_t sta;

	dp->mail_out.len = 0;
	dp->mail_out.dat[dp->mail_out.len++] = PRT_DP_MAIL_LIC;	// License token
	
	// Copy license key
	for (uint8_t i = 0; i < 8; i++)
		dp->mail_out.dat[dp->mail_out.len++] = *(lic+i);
	
	// Send mail
	prt_dp_mail_send (dp);

	// Wait for response
	sta = prt_dp_mail_resp (dp);
	return sta;
}

// Config
uint8_t prt_dp_cfg (prt_dp_ds_struct *dp)
{
	// Variables
	uint8_t sta;

	dp->mail_out.len = 0;
	dp->mail_out.dat[dp->mail_out.len++] = PRT_DP_MAIL_CFG;			// Config
	dp->mail_out.dat[dp->mail_out.len++] = PRT_DP_CFG_MAX_RATE;		// Max line rate
	dp->mail_out.dat[dp->mail_out.len++] = dp->lnk.max_rate;		// Maximum link rate
	prt_dp_mail_send (dp);

	// Wait for response
	sta = prt_dp_mail_resp (dp);

	if (sta != PRT_TRUE)
		return PRT_FALSE;

	dp->mail_out.len = 0;
	dp->mail_out.dat[dp->mail_out.len++] = PRT_DP_MAIL_CFG;			// Config
	dp->mail_out.dat[dp->mail_out.len++] = PRT_DP_CFG_MAX_LANES;	// Max lanes
	dp->mail_out.dat[dp->mail_out.len++] = dp->lnk.max_lanes;		// Maximum lanes
	prt_dp_mail_send (dp);

	// Wait for response
	sta = prt_dp_mail_resp (dp);

	if (sta != PRT_TRUE)
		return PRT_FALSE;

	// DPRX
	if (dp->id == PRT_DPRX_ID)
	{
		// MST capability
		dp->mail_out.len = 0;
		dp->mail_out.dat[dp->mail_out.len++] = PRT_DP_MAIL_CFG;		// Config
		dp->mail_out.dat[dp->mail_out.len++] = PRT_DP_CFG_MST_CAP;	// MST
		dp->mail_out.dat[dp->mail_out.len++] = dp->lnk.mst_cap;		// Data
		prt_dp_mail_send (dp);

		// Wait for response
		sta = prt_dp_mail_resp (dp);

		if (sta != PRT_TRUE)
			return PRT_FALSE;
	}

	// DPTX
	if (dp->id == PRT_DPTX_ID)
	{
		// After setting the config start the policy maker
		sta = prt_dp_run (dp);
	}

	return sta;
}

// Skip training
// Only used in simulation
#ifdef PRT_SIM
uint8_t prt_dprx_skip_trn (prt_dp_ds_struct *dp)
{
	// Variables
	uint8_t sta;

	dp->mail_out.len = 0;
	dp->mail_out.dat[dp->mail_out.len++] = PRT_DP_MAIL_CFG;			// Config
	dp->mail_out.dat[dp->mail_out.len++] = 0xff;		// Skip training
	dp->mail_out.dat[dp->mail_out.len++] = 0x47;	// Magic number
	prt_dp_mail_send (dp);

	// Wait for response
	sta = prt_dp_mail_resp (dp);

	return sta;
}
#endif

// AUX test
uint8_t prt_dptx_aux_test (prt_dp_ds_struct *dp, uint8_t run)
{
	// Variables
	uint8_t sta;

	dp->mail_out.len = 0;
	dp->mail_out.dat[dp->mail_out.len++] = PRT_DP_MAIL_AUX_TST;	// AUX test token
	if (run == PRT_TRUE)
		dp->mail_out.dat[dp->mail_out.len++] = 1;	// Enable test
	else
		dp->mail_out.dat[dp->mail_out.len++] = 0;	// Disable test

	prt_dp_mail_send (dp);

	// Wait for response
	sta = prt_dp_mail_resp (dp);
	return sta;
}

// Status
void prt_dp_sta (prt_dp_ds_struct *dp)
{
	dp->mail_out.len = 0;
	dp->mail_out.dat[dp->mail_out.len++] = PRT_DP_MAIL_STA;
	prt_dp_mail_send (dp);
}

// Run
uint8_t prt_dp_run (prt_dp_ds_struct *dp)
{
	// Variables
	uint8_t sta;

	dp->mail_out.len = 0;
	dp->mail_out.dat[dp->mail_out.len++] = PRT_DP_MAIL_RUN;	// Run
	prt_dp_mail_send (dp);

	// Wait for response
	sta = prt_dp_mail_resp (dp);

	return sta;
}

// Training force
uint8_t prt_dptx_trn (prt_dp_ds_struct *dp)
{
	// Variables
	uint8_t sta;

	dp->mail_out.len = 0;
	dp->mail_out.dat[dp->mail_out.len++] = PRT_DP_MAIL_TRN_STR;	// Token
	dp->mail_out.dat[dp->mail_out.len++] = dp->lnk.max_rate;	// Maximum link rate
	prt_dp_mail_send (dp);

	// Wait for response
	sta = prt_dp_mail_resp (dp);
	return sta;
}

// PHY test
uint8_t prt_dptx_phy_test (prt_dp_ds_struct *dp, uint8_t tps, uint8_t volt, uint8_t pre)
{
	// Variables
	uint8_t sta;

	dp->mail_out.len = 0;
	dp->mail_out.dat[dp->mail_out.len++] = PRT_DP_MAIL_PHY_TST;	// Token
	dp->mail_out.dat[dp->mail_out.len++] = tps;	// Training pattern
	dp->mail_out.dat[dp->mail_out.len++] = volt;	// Voltage
	dp->mail_out.dat[dp->mail_out.len++] = pre;	// Preamble
	prt_dp_mail_send (dp);

	// Wait for response
	sta = prt_dp_mail_resp (dp);
	return sta;
}

// Link request ok
void prt_dp_lnk_req_ok (prt_dp_ds_struct *dp)
{
	dp->mail_out.len = 0;
	dp->mail_out.dat[dp->mail_out.len++] = PRT_DP_MAIL_LNK_REQ_OK;
	prt_dp_mail_send (dp);
}

// Training clock recovery acknowledge
void prt_dprx_trn_cr_ack (prt_dp_ds_struct *dp)
{
	dp->mail_out.len = 0;
	dp->mail_out.dat[dp->mail_out.len++] = PRT_DP_MAIL_TRN_CR_ACK;
	prt_dp_mail_send (dp);
}

// HPD
uint8_t prt_dprx_hpd (prt_dp_ds_struct *dp, uint8_t hpd)
{
	// Variables
	uint8_t dat;
	uint8_t sta;

	switch (hpd)
	{
		case 2 : dat = PRT_DP_MAIL_HPD_PLUG; break;
		case 3 : dat = PRT_DP_MAIL_HPD_IRQ; break;
		default : dat = PRT_DP_MAIL_HPD_UNPLUG; break;
	}

	dp->mail_out.len = 0;
	dp->mail_out.dat[dp->mail_out.len++] = dat;
	prt_dp_mail_send (dp);

	// Wait for response
	sta = prt_dp_mail_resp (dp);

	return sta;
}

// Set MSA
uint8_t prt_dptx_msa_set (prt_dp_ds_struct *dp, prt_dp_tp_struct *tp, uint8_t stream)
{
	// Variables
	uint8_t sta;
	uint8_t dat;

	// Copy timing parameters to DP structure
	dp->vid[stream].tp.htotal 	= tp->htotal;
	dp->vid[stream].tp.hwidth 	= tp->hwidth;
	dp->vid[stream].tp.hstart 	= tp->hstart;
	dp->vid[stream].tp.hsw 		= tp->hsw;
	dp->vid[stream].tp.vtotal 	= tp->vtotal;
	dp->vid[stream].tp.vheight 	= tp->vheight;
	dp->vid[stream].tp.vstart 	= tp->vstart;
	dp->vid[stream].tp.vsw 		= tp->vsw;
	dp->vid[stream].tp.bpc 		= tp->bpc;

	dp->mail_out.len = 0;
	dp->mail_out.dat[dp->mail_out.len++] = PRT_DP_MAIL_MSA_DAT;					// MSA set
	dp->mail_out.dat[dp->mail_out.len++] = stream;								// Stream
	dp->mail_out.dat[dp->mail_out.len++] = (dp->vid[stream].tp.htotal >> 8);   	// Htotal upper
	dp->mail_out.dat[dp->mail_out.len++] = (dp->vid[stream].tp.htotal & 0xff); 	// Htotal lower
	dp->mail_out.dat[dp->mail_out.len++] = (dp->vid[stream].tp.hstart >> 8);   	// Hstart upper
	dp->mail_out.dat[dp->mail_out.len++] = (dp->vid[stream].tp.hstart & 0xff); 	// Hstart lower
	dp->mail_out.dat[dp->mail_out.len++] = (dp->vid[stream].tp.hwidth >> 8);   	// Hwidth upper
	dp->mail_out.dat[dp->mail_out.len++] = (dp->vid[stream].tp.hwidth & 0xff); 	// Hwidth lower
	dp->mail_out.dat[dp->mail_out.len++] = (dp->vid[stream].tp.hsw >> 8);   	// Hsw upper
	dp->mail_out.dat[dp->mail_out.len++] = (dp->vid[stream].tp.hsw & 0xff); 	// Hsw lower
	dp->mail_out.dat[dp->mail_out.len++] = (dp->vid[stream].tp.vtotal >> 8);   	// Vtotal upper
	dp->mail_out.dat[dp->mail_out.len++] = (dp->vid[stream].tp.vtotal & 0xff);	// Vtotal lower
	dp->mail_out.dat[dp->mail_out.len++] = (dp->vid[stream].tp.vstart >> 8);   	// Vstart upper
	dp->mail_out.dat[dp->mail_out.len++] = (dp->vid[stream].tp.vstart & 0xff); 	// Vstart lower
	dp->mail_out.dat[dp->mail_out.len++] = (dp->vid[stream].tp.vheight >> 8);   // Vheight upper
	dp->mail_out.dat[dp->mail_out.len++] = (dp->vid[stream].tp.vheight & 0xff); // Vheight lower
	dp->mail_out.dat[dp->mail_out.len++] = (dp->vid[stream].tp.vsw >> 8);   	// Vsw upper
	dp->mail_out.dat[dp->mail_out.len++] = (dp->vid[stream].tp.vsw & 0xff); 	// Vsw lower
	
	// Set MISC bits-per-component
	if (dp->vid[stream].tp.bpc == 10)
		dat = 0x40;		// RGB 10-bits
	else
		dat = 0x20;		// RGB 8-bits

	dp->mail_out.dat[dp->mail_out.len++] = dat;  // Misc 0
	dp->mail_out.dat[dp->mail_out.len++] = 0;  	// Misc 1
	prt_dp_mail_send (dp);

	// Wait for response
	sta = prt_dp_mail_resp (dp);

	return sta;
}

// DPCD write 
uint8_t prt_dptx_dpcd_wr (prt_dp_ds_struct *dp, uint32_t adr, uint8_t dat)
{
	// Variables
	uint8_t sta;

	dp->mail_out.len = 0;
	dp->mail_out.dat[dp->mail_out.len++] = PRT_DP_MAIL_DPCD_WR;	// DPCD write
	dp->mail_out.dat[dp->mail_out.len++] = (adr >> 16) & 0xff;	// Address high
	dp->mail_out.dat[dp->mail_out.len++] = (adr >> 8) & 0xff;	// Address mid
	dp->mail_out.dat[dp->mail_out.len++] = adr & 0xff;		// Address low
	dp->mail_out.dat[dp->mail_out.len++] = 1;				// Length
	dp->mail_out.dat[dp->mail_out.len++] = dat;				// Data

	prt_dp_mail_send (dp);

	// Wait for response
	sta = prt_dp_mail_resp (dp);

	return sta;
}

// DPCD read 
uint8_t prt_dptx_dpcd_rd (prt_dp_ds_struct *dp, uint32_t adr, uint8_t *dat)
{
	// Variables
	uint8_t sta;

	dp->mail_out.len = 0;
	dp->mail_out.dat[dp->mail_out.len++] = PRT_DP_MAIL_DPCD_RD;	// DPCD write
	dp->mail_out.dat[dp->mail_out.len++] = (adr >> 16) & 0xff;	// Address high
	dp->mail_out.dat[dp->mail_out.len++] = (adr >> 8) & 0xff;	// Address mid
	dp->mail_out.dat[dp->mail_out.len++] = adr & 0xff;		// Address low
	dp->mail_out.dat[dp->mail_out.len++] = 1;				// Length

	prt_dp_mail_send (dp);

	// Wait for response
	sta = prt_dp_mail_resp (dp);

	// Copy data
	*dat = dp->mail_in.dat[2];

	return sta;
}

// Video start
uint8_t prt_dp_vid_str (prt_dp_ds_struct *dp, uint8_t stream)
{
	// Variables
	uint8_t tries = 0;
	uint8_t sta = PRT_FALSE;

	// If the video is already running, then stop the video
	if (prt_dp_is_vid_up (dp, stream))
		prt_dp_vid_stp (dp, stream);

	// Before we start the video, we need to check if a sink is connected
	if (prt_dp_is_hpd (dp))
	{
		// When there is a sink, we need to check if the link is up
		// The policy maker might be busy training the link, so we need to try a couple of times
		do
		{
			if (prt_dp_is_lnk_up (dp))
			{
				dp->mail_out.len = 0;
				dp->mail_out.dat[dp->mail_out.len++] = PRT_DP_MAIL_VID_STR;	// Video start

				// Currently only DPTX supports MST
				if (dp->id == PRT_DPTX_ID)
				{
					dp->mail_out.dat[dp->mail_out.len++] = stream;	// Stream
				}
				prt_dp_mail_send (dp);

				// Wait for response
				sta = prt_dp_mail_resp (dp);
			}

			else
				tries++;

		} while ((sta == PRT_FALSE) && (tries < 10));
	}

	return sta;
}

// Video stop
uint8_t prt_dp_vid_stp (prt_dp_ds_struct *dp, uint8_t stream)
{
	uint8_t sta;

	dp->mail_out.len = 0;
	dp->mail_out.dat[dp->mail_out.len++] = PRT_DP_MAIL_VID_STP;	// Video stop
	
	// Currently only DPTX supports MST
	if (dp->id == PRT_DPTX_ID)
	{
		dp->mail_out.dat[dp->mail_out.len++] = stream;	// Stream
	}

	prt_dp_mail_send (dp);

	// Wait for response
	sta = prt_dp_mail_resp (dp);

	return sta;
}

// Get HPD status
uint8_t prt_dp_hpd_get (prt_dp_ds_struct *dp)
{
	return dp->hpd;
}

// Check HPD
// This function returns PRT_TRUE when the hpd is asserted
uint8_t prt_dp_is_hpd (prt_dp_ds_struct *dp)
{
	if (prt_dp_hpd_get (dp) != PRT_DP_HPD_UNPLUG) 
		return PRT_TRUE;
	else
		return PRT_FALSE;
}

// Check link
// This function returns PRT_TRUE when the link is up and running
uint8_t prt_dp_is_lnk_up (prt_dp_ds_struct *dp)
{
	if (dp->lnk.up)
		return PRT_TRUE;
	else
		return PRT_FALSE;
}

// Get active lanes
uint8_t prt_dp_get_lnk_act_lanes (prt_dp_ds_struct *dp)
{
	return dp->lnk.act_lanes;
}

// Get active rate
uint8_t prt_dp_get_lnk_act_rate (prt_dp_ds_struct *dp)
{
	return dp->lnk.act_rate;
}

// Get link down reason
uint8_t prt_dp_get_lnk_reason (prt_dp_ds_struct *dp)
{
	return dp->lnk.reason;
}

// Set max lanes
void prt_dp_set_lnk_max_lanes (prt_dp_ds_struct *dp, uint8_t lanes)
{
	dp->lnk.max_lanes = lanes;
}

// Set max rate
void prt_dp_set_lnk_max_rate (prt_dp_ds_struct *dp, uint8_t rate)
{
	dp->lnk.max_rate = rate;
}

// Set MST capability
void prt_dp_set_mst_cap (prt_dp_ds_struct *dp, uint8_t cap)
{
	dp->lnk.mst_cap = cap;
}

// Check video
// This function returns PRT_TRUE when the video is up and running
uint8_t prt_dp_is_vid_up (prt_dp_ds_struct *dp, uint8_t stream)
{
	if (dp->vid[stream].up)
		return PRT_TRUE;
	else
		return PRT_FALSE;
}

// Get video down reason
uint8_t prt_dp_get_vid_reason (prt_dp_ds_struct *dp, uint8_t stream)
{
	return dp->vid[stream].reason;
}

// Training pass
// This function returns PRT_TRUE when the training passed
uint8_t prt_dp_is_trn_pass (prt_dp_ds_struct *dp)
{
	if (dp->trn.pass)
		return PRT_TRUE;
	else
		return PRT_FALSE;
}

// Training clock recovery
// This function returns PRT_TRUE when the training starts the clock recovery (RX Only)
uint8_t prt_dp_is_trn_cr (prt_dp_ds_struct *dp)
{
	if (dp->trn.cr)
		return PRT_TRUE;
	else
		return PRT_FALSE;
}

// Send message
void prt_dp_mail_send (prt_dp_ds_struct *dp)
{
	// Start of mail token
	dp->dev->mail_out = PRT_DP_MAIL_SOM;

	for (uint32_t i = 0; i < dp->mail_out.len; i++)
		dp->dev->mail_out = dp->mail_out.dat[i];

	// End of mail token
	dp->dev->mail_out = PRT_DP_MAIL_EOM;
}

// Check mail
// Called from interrupt handler
uint8_t prt_dp_mail_chk (prt_dp_ds_struct *dp)
{
	// Variables
	uint32_t dat;

	// Read status register
	dat = dp->dev->sta;

	// Extract mail word words
	dat >>= PRT_DP_STA_MAIL_IN_WRDS_SHIFT;
	dat &= 0x1f;

	return dat;
}

// Get message
// Called from interrupt handler
void prt_dp_mail_get (prt_dp_ds_struct *dp, uint8_t len)
{
	// Variables
	uint32_t dat;
	uint8_t idx;

	// Clear index
	idx = 0;

	do
	{
		// Get data
		dat = dp->dev->mail_in;

		// Start of message
		if ((dat & 0x1ff) == PRT_DP_MAIL_SOM)
		{
			dp->mail_in.len = 0;
		}

		// End of message
		else if ((dat & 0x1ff) == PRT_DP_MAIL_EOM)
		{
			// Set process mail flag
			dp->mail_in.proc = PRT_TRUE;
		}

		else
		{
			// Copy data
			dp->mail_in.dat[dp->mail_in.len++] = dat;

			// Clear process mail flag
			dp->mail_in.proc = PRT_FALSE;
		}

		// Increment index
		idx++;

	} while ((idx < len) && (dp->mail_in.proc == PRT_FALSE));
}

// Mail response
// To do: add time out
uint8_t prt_dp_mail_resp (prt_dp_ds_struct *dp)
{
	// Variables
	uint8_t sta;
	uint8_t exit_loop = PRT_FALSE;

	// Clear flags
	dp->mail_in.ok = PRT_FALSE;
	dp->mail_in.err = PRT_FALSE;

	do
	{
		if (dp->mail_in.ok)
		{
			// Set status
			sta = PRT_TRUE;
			exit_loop = PRT_TRUE;
		}

		else if (dp->mail_in.err)
		{
			// Set status
			sta = PRT_FALSE;
			exit_loop = PRT_TRUE;
		}
	} while (!exit_loop);

	return sta;
}

#ifdef PRT_SIM
// Check aux
uint8_t prt_dp_check_aux (prt_dp_ds_struct *dp)
{
	// Variables
	uint32_t dat;

	// Read status register
	dat = dp->dev->sta;

	// Extract aux word words
	dat >>= PRT_DP_STA_AUX_WRDS_SHIFT;
	dat &= 0x1f;

	return dat;
}

// Get aux
// Called from interrupt handler
void prt_dp_get_aux (prt_dp_ds_struct *dp, uint8_t len)
{
	// Variables
	uint32_t dat;
	uint8_t idx;

	// Clear index
	idx = 0;

	do
	{
		// Get data
		dat = dp->dev->aux;

		// Mask
		dat &= 0x1ff;
		
		// Clear length at start 
		if ((dat == PRT_AUX_REQ_STR) || (dat == PRT_AUX_REPLY_STR))
		{
			dp->aux.len = 0;
		}

		// Set process flag at end
		if ((dat == PRT_AUX_REQ_STP) || (dat == PRT_AUX_REPLY_STP))
		{
			// Set process aux flag
			dp->aux.proc = PRT_TRUE;
		}

		else
		{
			// Copy data
			dp->aux.dat[dp->aux.len++] = dat;
		
			// Clear process aux flag
			dp->aux.proc = PRT_FALSE;
		}

		// Increment index
		idx++;

	} while ((idx < len) && (dp->aux.proc == PRT_FALSE));
}

// Decode aux
// Called from interrupt handler
void prt_dp_decode_aux (prt_dp_ds_struct *dp)
{
	// Variables
	uint32_t dat;
	uint32_t adr;
	uint8_t cmd;
	uint8_t len;
	uint8_t reply;

	// Clear process mail flag
	dp->aux.proc = PRT_FALSE;

	switch (dp->aux.dat[0])
	{
		case PRT_AUX_REQ_STR :
			prt_printf ("AUX request | ");

			cmd = dp->aux.dat[1];
			cmd >>= 4;
		
			switch (cmd)
			{
				case PRT_AUX_CMD_WR :
					prt_printf ("Write | ");
					break;

				case PRT_AUX_CMD_RD :
					prt_printf ("Read | ");
					break;

				default :
					prt_printf ("Unknown | ");
					break;
			}
			// Address high
			adr = dp->aux.dat[1];
			adr &= 0x0f;
			adr <<= 4;

			// Address mid
			adr |= dp->aux.dat[2];
			adr <<= 8;

			// Address low
			adr |= dp->aux.dat[3];

			prt_printf ("Address: %x | ", adr);

			// Length
			len = dp->aux.dat[4];
			len += 1;
			prt_printf ("Length: %d | ", len);

			// Data
			if (cmd == PRT_AUX_CMD_WR)
			{
				prt_printf ("Data: ");
			
				for (uint8_t i = 0; i < len; i++)
					prt_printf ("%x | ", dp->aux.dat[5 + i]);
			}

			prt_printf ("\n");

			break;

		case PRT_AUX_REPLY_STR :
			prt_printf ("AUX reply | ");
			reply = dp->aux.dat[1];
			reply &= 0x3;

			switch (reply)
			{
				case PRT_AUX_REPLY_ACK :
					prt_printf ("ACK | ");
					break;
				
				case PRT_AUX_REPLY_NACK :
					prt_printf ("NACK | ");
					break;

				case PRT_AUX_REPLY_DEFER :
					prt_printf ("DEFER | ");
					break;

				default :
					prt_printf ("UNKNOWN | ");
					break;
			}

			len = dp->aux.len;
			
			if ( (reply == PRT_AUX_REPLY_ACK) && (len > 2) )
			{
				prt_printf ("Data: ");

				// Do not include start and stop characters
				len -= 2;

				// Data
				for (uint8_t i = 0; i < len; i++)
					prt_printf ("%x | ", dp->aux.dat[2 + i]);
			}

			prt_printf ("\n");
			break;

		default : 
			prt_printf ("AUX unknown\n");
			break;
	}

	// Clear length
	dp->aux.len = 0;
}

#endif

// Decode mail
// Called from interrupt handler
void prt_dp_mail_dec (prt_dp_ds_struct *dp)
{
	// Variables
	uint32_t dat;
	uint8_t stream;

	// Clear mail flags
	dp->mail_in.proc = PRT_FALSE;

	switch (dp->mail_in.dat[0])
	{
		case PRT_DP_MAIL_ERR:
			// Set error flag
			dp->mail_in.err = PRT_TRUE;
			break;

		case PRT_DP_MAIL_OK:
			// Set ok flag
			dp->mail_in.ok = PRT_TRUE;
			break;

		case PRT_DP_MAIL_DEBUG:
			prt_dp_debug_put (dp, dp->mail_in.dat[1]);
			
			// Set event
			dp->evt |= PRT_DP_EVT_DEBUG;
			break;

		case PRT_DP_MAIL_STA:
			dp->sta.hw_ver_major = dp->mail_in.dat[1];
			dp->sta.hw_ver_minor = dp->mail_in.dat[2];
			dp->sta.sw_ver_major = dp->mail_in.dat[3];
			dp->sta.sw_ver_minor = dp->mail_in.dat[4];
			dp->sta.mst = dp->mail_in.dat[5];
			dp->sta.pio = dp->mail_in.dat[6];
			dp->sta.hpd = dp->mail_in.dat[7];
			dp->sta.lnk_up = dp->mail_in.dat[8];
			dp->sta.lnk_act_lanes = dp->mail_in.dat[9];
			dp->sta.lnk_act_rate = dp->mail_in.dat[10];
			dp->sta.vid_up = dp->mail_in.dat[11];

			// Set event
			dp->evt |= PRT_DP_EVT_STA;
			break;

		case PRT_DP_MAIL_HPD_UNPLUG:
			dp->hpd = PRT_DP_HPD_UNPLUG;

			// Set event flag
			dp->evt |= PRT_DP_EVT_HPD;
			break;

		case PRT_DP_MAIL_HPD_PLUG:
			dp->hpd = PRT_DP_HPD_PLUG;

			// Set event flag
			dp->evt |= PRT_DP_EVT_HPD;
			break;

		case PRT_DP_MAIL_HPD_IRQ:
			dp->hpd = PRT_DP_HPD_IRQ;

			// Set event flag
			dp->evt |= PRT_DP_EVT_HPD;
			break;

		case PRT_DP_MAIL_TRN_PASS:
			// Set training pass flag
			dp->trn.pass = PRT_TRUE;

			// Clear training fail flag
			dp->trn.fail = PRT_FALSE;

			// Clear training cr flag
			dp->trn.cr = PRT_FALSE;

			// Set event flag
			dp->evt |= PRT_DP_EVT_TRN;
			break;

		case PRT_DP_MAIL_TRN_ERR:
			// Set training fail flag
			dp->trn.fail = PRT_TRUE;

			// Clear training pass flag
			dp->trn.pass = PRT_FALSE;

			// Clear training cr flag
			dp->trn.cr = PRT_FALSE;

			// Set event flag
			dp->evt |= PRT_DP_EVT_TRN;
			break;

		case PRT_DP_MAIL_TRN_CR_STR:		
			// Clear training pass flag
			dp->trn.pass = PRT_FALSE;

			// Clear training fail flag
			dp->trn.fail = PRT_FALSE;

			// Set training clock recovery flag
			dp->trn.cr = PRT_TRUE;

			// Set event flag
			dp->evt |= PRT_DP_EVT_TRN;
			break;

		case PRT_DP_MAIL_LNK_RATE_REQ:
			// Set link rate request
			dp->lnk.phy_rate = dp->mail_in.dat[1];

			if (dp->id == PRT_DPRX_ID)
			{
				// Set spread spectrum clocking
				dp->lnk.phy_ssc = dp->mail_in.dat[2];
			}

			// Set event flag
			dp->evt |= PRT_DP_EVT_PHY_RATE;
			break;

		case PRT_DP_MAIL_LNK_VAP_REQ:
			// Set link voltage and pre-amble request
			dp->lnk.phy_volt = dp->mail_in.dat[1];
			dp->lnk.phy_pre = dp->mail_in.dat[2];

			// Set event flag
			dp->evt |= PRT_DP_EVT_PHY_VAP;
			break;

		case PRT_DP_MAIL_LNK_UP:
			// Set link up flag
			dp->lnk.up = PRT_TRUE;

			// Lanes
			dp->lnk.act_lanes = dp->mail_in.dat[1];

			// Rate
			dp->lnk.act_rate = dp->mail_in.dat[2];

			// Set event flag
			dp->evt |= PRT_DP_EVT_LNK;
			break;

		case PRT_DP_MAIL_LNK_DOWN:
			// Clear link up flag
			dp->lnk.up = PRT_FALSE;

			// Reason
			dp->lnk.reason = dp->mail_in.dat[1];

			// Set event flag
			dp->evt |= PRT_DP_EVT_LNK;
			break;

		case PRT_DP_MAIL_VID_STR:
			break;

		case PRT_DP_MAIL_VID_UP:
			// DPTX
			if (dp->id == PRT_DPTX_ID)
			{
				// Get stream
				stream = dp->mail_in.dat[1];
			}

			// DPRX
			else
			{
				stream = 0;
			}
			
			// Set video up flag
			dp->vid[stream].up = PRT_TRUE;

			// Set the video event flag
			// To prevent race conditions, besides the dp video event flag,
			// each video stream has its own event flag.
			dp->vid[stream].evt = PRT_TRUE;

			// Set dp event flag
			dp->evt |= PRT_DP_EVT_VID;
			break;

		case PRT_DP_MAIL_VID_DOWN:
			// DPTX
			if (dp->id == PRT_DPTX_ID)
			{
				// Get stream
				stream = dp->mail_in.dat[1];

				// Reason
				dp->vid[stream].reason = dp->mail_in.dat[2];
			}

			// DPRX
			else
			{
				stream = 0;

				// Reason
				dp->vid[stream].reason = dp->mail_in.dat[1];
			}		

			// Clear video up flag
			dp->vid[stream].up = PRT_FALSE;

			// Set the video event flag
			// To prevent race conditions, besides the dp video event flag,
			// each video stream has its own event flag.
			dp->vid[stream].evt = PRT_TRUE;

			// Set event flag
			dp->evt |= PRT_DP_EVT_VID;
			break;

		case PRT_DP_MAIL_MSA_DAT:

			// DPRX
			stream = 0;

			// Mvid
			dat = dp->mail_in.dat[1] << 16;
			dat |= dp->mail_in.dat[2] << 8;
			dat |= dp->mail_in.dat[3];
			dp->vid[stream].tp.mvid = dat;

			// Nvid
			dat = dp->mail_in.dat[4] << 16;
			dat |= dp->mail_in.dat[5] << 8;
			dat |= dp->mail_in.dat[6];
			dp->vid[stream].tp.nvid = dat;

			// Htotal
			dat = dp->mail_in.dat[7] << 8;
			dat |= dp->mail_in.dat[8];
			dp->vid[stream].tp.htotal = dat;

			// Hstart
			dat = dp->mail_in.dat[9] << 8;
			dat |= dp->mail_in.dat[10];
			dp->vid[stream].tp.hstart = dat;

			// Hwidth
			dat = dp->mail_in.dat[11] << 8;
			dat |= dp->mail_in.dat[12];
			dp->vid[stream].tp.hwidth = dat;

			// Hsw
			dat = dp->mail_in.dat[13] << 8;
			dat |= dp->mail_in.dat[14];
			dp->vid[stream].tp.hsw = dat;

			// Vtotal
			dat = dp->mail_in.dat[15] << 8;
			dat |= dp->mail_in.dat[16];
			dp->vid[stream].tp.vtotal = dat;

			// Vstart
			dat = dp->mail_in.dat[17] << 8;
			dat |= dp->mail_in.dat[18];
			dp->vid[stream].tp.vstart = dat;

			// Vheight
			dat = dp->mail_in.dat[19] << 8;
			dat |= dp->mail_in.dat[20];
			dp->vid[stream].tp.vheight = dat;

			// Vsw
			dat = dp->mail_in.dat[21] << 8;
			dat |= dp->mail_in.dat[22];
			dp->vid[stream].tp.vsw = dat;

			// Misc 0
			dat = dp->mail_in.dat[24];

			// Video 10 bpc
			if (dat & 0x40)
				dp->vid[stream].tp.bpc = 10;
			
			// Video 8 bpc
			else
				dp->vid[stream].tp.bpc = 8;

			// Misc 1
			dat = dp->mail_in.dat[23];
			//dp->vid[stream].tp.misc1 = dat;

			// Set event flag
			dp->evt |= PRT_DP_EVT_MSA;

			break;

		case PRT_DP_MAIL_EDID_DAT:

			// Copy data
			for (uint8_t i = 0; i < 16; i++)
			{
				dp->edid.dat[dp->edid.adr++] = dp->mail_in.dat[i+1];
			}

			// Set event flag
			dp->evt |= PRT_DP_EVT_EDID;

			break;

		default:
			//prt_printf ("Unknown token (%x)\n", dp->mail_in.dat[0]);
			break;	
	}

	// Callbacks
	if (dp->evt)
	{
		// HPD
		if (prt_dp_is_evt (dp, PRT_DP_EVT_HPD) && (dp->cb.hpd != 0))
		{
			// Jump callback
			dp->cb.hpd (dp);
		}

		// Status
		if (prt_dp_is_evt (dp, PRT_DP_EVT_STA) && (dp->cb.sta != 0))
		{
			// Jump callback
			dp->cb.sta (dp);
		}

		// PHY rate
		if (prt_dp_is_evt (dp, PRT_DP_EVT_PHY_RATE) && (dp->cb.phy_rate != 0))
		{
			// Jump callback
			dp->cb.phy_rate (dp);
		}

		// PHY vap
		if (prt_dp_is_evt (dp, PRT_DP_EVT_PHY_VAP) && (dp->cb.phy_vap != 0))
		{
			// Jump callback
			dp->cb.phy_vap (dp);
		}

		// Training
		if (prt_dp_is_evt (dp, PRT_DP_EVT_TRN) && (dp->cb.trn != 0))
		{
			// Jump callback
			dp->cb.trn (dp);
		}

		// Link
		if (prt_dp_is_evt (dp, PRT_DP_EVT_LNK) && (dp->cb.lnk != 0))
		{
			// Jump callback
			dp->cb.lnk (dp);
		}

		// Video
		if (prt_dp_is_evt (dp, PRT_DP_EVT_VID) && (dp->cb.vid != 0))
		{
			// Jump callback
			dp->cb.vid (dp);
		}

		// MSA
		if (prt_dp_is_evt (dp, PRT_DP_EVT_MSA) && (dp->cb.msa != 0))
		{
			// Jump callback
			dp->cb.msa (dp);
		}

		// Debug
		if (prt_dp_is_evt (dp, PRT_DP_EVT_DEBUG) && (dp->cb.dbg != 0))
		{
			// Jump callback
			dp->cb.dbg (dp);
		}

		// Clear all events
		dp->evt = 0;
	}
}

// DP Initialize rom
void prt_dp_rom_init (prt_dp_ds_struct *dp, uint32_t len, uint8_t *rom)
{
	uint32_t dat = 0;

	// Start initialization
	dp->dev->ctl = PRT_DP_CTL_MEM_STR;

	for (int word = 0; word < (len/4)+1; word++)
	{
		for (int byte = 3; byte >= 0; byte--)
		{
			dat <<= 8;
			dat |= rom[(word * 4) + byte];
		}
		dp->dev->mem = dat;
	}
}

// DP Initialize ram
void prt_dp_ram_init (prt_dp_ds_struct *dp, uint32_t len, uint8_t *ram)
{
	uint32_t dat = 0;

	// Start initialization and select ram
	dp->dev->ctl = PRT_DP_CTL_MEM_STR | PRT_DP_CTL_MEM_SEL;

	// Copy data
	for (int word = 0; word < (len/4)+1; word++)
	{
		for (int byte = 3; byte >= 0; byte--)
		{
			dat <<= 8;
			dat |= ram[(word * 4) + byte];
		}
		dp->dev->mem = dat;
	}
}

// Read edid
// todo: Check function
uint8_t prt_dptx_edid_rd (prt_dp_ds_struct *dp)
{
	// Variables
	uint8_t sta;
	uint8_t done;

	// Reset address
	dp->edid.adr = 0;
	done = PRT_FALSE;

	do
	{
		dp->mail_out.len = 0;
		dp->mail_out.dat[dp->mail_out.len++] = PRT_DP_MAIL_EDID_RD;	// Token
		dp->mail_out.dat[dp->mail_out.len++] = dp->edid.adr;	// Base address
		prt_dp_mail_send (dp);

		// Wait for response
		sta = prt_dp_mail_resp (dp);

		if (sta)
		{
			// Wait for edid event
			while (prt_dp_is_evt (dp, PRT_DP_EVT_EDID));

			// Last block
			if (dp->edid.adr == (15 * 16))
			{
				sta = PRT_TRUE;
				done = PRT_TRUE;
			}

			else
				dp->edid.adr += 16;
		}

		else
		{
			sta = PRT_FALSE;
			done = PRT_TRUE;
		}
	} while (!done);

	return sta;
}

// Write edid to policy maker
uint8_t prt_dprx_edid_wr (prt_dp_ds_struct *dp, uint16_t len)
{
	// Variables
	uint8_t sta;
	uint8_t done;

	// Reset base address
	dp->edid.adr = 0;
	done = PRT_FALSE;

	do
	{
		dp->mail_out.len = 0;
		dp->mail_out.dat[dp->mail_out.len++] = PRT_DP_MAIL_EDID_DAT;	// Token
		dp->mail_out.dat[dp->mail_out.len++] = dp->edid.adr >> 8;		// Base address high
		dp->mail_out.dat[dp->mail_out.len++] = dp->edid.adr & 0xff;		// Base address low

		for (uint8_t i = 0; i < 16; i++)
			dp->mail_out.dat[dp->mail_out.len++] = dp->edid.dat[dp->edid.adr++];	// Data

		prt_dp_mail_send (dp);

		// Wait for response
		sta = prt_dp_mail_resp (dp);

		if (sta)
		{
			// Last block
			if (dp->edid.adr >= len)
			{
				sta = PRT_TRUE;
				done = PRT_TRUE;
			}
		}

		else
		{
			sta = PRT_FALSE;
			done = PRT_TRUE;
		}
	} while (!done);

	return sta;
}

// Interrupt handler
void prt_dp_irq_handler (prt_dp_ds_struct *dp)
{
	// Variables
	uint8_t len;
	uint32_t sta;

	// Read status register
	sta = dp->dev->sta;

	// Is there an interrupt?
	if (sta & PRT_DP_STA_IRQ)
	{
		// Is there any mail
		if (!(sta & PRT_DP_STA_MAIL_IN_EP))
		{
			// Get mail length
			len = prt_dp_mail_chk (dp);

			// Get mail
			prt_dp_mail_get (dp, len);

			// Clear interrupt flag
			dp->dev->sta = PRT_DP_STA_IRQ;

			// Decode mail
			if (dp->mail_in.proc)
			{
				prt_dp_mail_dec (dp);
			}
		}

		// AUX
		#ifdef PRT_SIM
		// Is there any aux
		if (!(sta & PRT_DP_STA_AUX_EP))
		{
			// Get AUX length
			len = prt_dp_check_aux (dp);
			
			// Get aux
			prt_dp_get_aux (dp, len);

			// Clear interrupt flag
			dp->dev->sta = PRT_DP_STA_IRQ;

			// Decode mail
			if (dp->aux.proc)
			{
				prt_dp_decode_aux (dp);
		    }
		}
		#endif
	}
}

// Event
uint8_t prt_dp_is_evt (prt_dp_ds_struct *dp, uint32_t evt)
{
	if (dp->evt & evt)
	{
		// Clear flag
		dp->evt &= ~evt;
		return PRT_TRUE;
	}
	else
		return PRT_FALSE;
}

// Debug put
void prt_dp_debug_put (prt_dp_ds_struct *dp, uint8_t dat)
{
	// Put data in buffer
  	dp->debug.dat[dp->debug.head] = dat;

 	// Increment head pointer
	if (dp->debug.head > 31)
		dp->debug.head = 0;
	else
		dp->debug.head++;
}

// Debug get
uint8_t prt_dp_debug_get (prt_dp_ds_struct *dp)
{
	// Variables
	uint8_t dat;

	// Read data
  	dat = dp->debug.dat[dp->debug.tail];

 	// Increment tail pointer
	if (dp->debug.tail > 31)
		dp->debug.tail = 0;
	else
		dp->debug.tail++;

	return dat;
}

// Get timing parameters
prt_dp_tp_struct prt_dprx_tp_get (prt_dp_ds_struct *dp)
{
	// Currently DPRX doesn't support multiple streams
	return dp->vid[0].tp;
}

// Get status
prt_dp_sta_struct prt_dp_get_sta (prt_dp_ds_struct *dp)
{
	return dp->sta;
}

// Get ID
uint8_t prt_dp_get_id (prt_dp_ds_struct *dp)
{
	return dp->id;
}

// Get EDID data
uint8_t prt_dp_get_edid_dat (prt_dp_ds_struct *dp, uint8_t index)
{
	return dp->edid.dat[index];
}

// Set EDID data
void prt_dp_set_edid_dat (prt_dp_ds_struct *dp, uint16_t adr, uint8_t dat)
{
	dp->edid.dat[adr] = dat;
}

// Get PHY rate
uint8_t prt_dp_get_phy_rate (prt_dp_ds_struct *dp)
{
	return dp->lnk.phy_rate;
}

// Get PHY spread spectrum clocking
uint8_t prt_dp_get_phy_ssc (prt_dp_ds_struct *dp)
{
	return dp->lnk.phy_ssc;
}

// Get PHY voltage
uint8_t prt_dp_get_phy_volt (prt_dp_ds_struct *dp)
{
	return dp->lnk.phy_volt;
}

// Get PHY pre-amble
uint8_t prt_dp_get_phy_pre (prt_dp_ds_struct *dp)
{
	return dp->lnk.phy_pre;
}

// MST start
uint8_t prt_dptx_mst_str (prt_dp_ds_struct *dp)
{
	// Variables
	uint8_t sta;

	dp->mail_out.len = 0;
	dp->mail_out.dat[dp->mail_out.len++] = PRT_DP_MAIL_MST_STR;	// MST 
	prt_dp_mail_send (dp);

	// Wait for response
	sta = prt_dp_mail_resp (dp);

	if (sta == PRT_TRUE)
		sta = dp->mail_in.dat[1];
	else
		sta = PRT_DP_MST_ERR;
		
	return sta;
}

// MST stop
uint8_t prt_dptx_mst_stp (prt_dp_ds_struct *dp)
{
	// Variables
	uint8_t sta;

	dp->mail_out.len = 0;
	dp->mail_out.dat[dp->mail_out.len++] = PRT_DP_MAIL_MST_STP;	// MST 
	prt_dp_mail_send (dp);

	// Wait for response
	sta = prt_dp_mail_resp (dp);

	if (sta == PRT_TRUE)
		sta = dp->mail_in.dat[1];
	else
		sta = PRT_DP_MST_ERR;
		
	return sta;
}
