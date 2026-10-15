/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP video formats
    (c) 2026 by Parretto B.V.

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

#include <stdint.h>
#include <stdbool.h>

// Video formats
// The colorbar formats of the video toolbox, with what the sink's EDID says about them.
// The application reads the EDID with prt_dptx_edid_rd, parses it with prt_dp_fmt_edid_parse
// and uses the checks below for its colorbar menu and the format after a hot plug.

// Formats
#define PRT_DP_FMT_CNT                  9

// Sink support
#define PRT_DP_FMT_SINK_NO              0       // Not in the EDID
#define PRT_DP_FMT_SINK_YES             1       // Listed
#define PRT_DP_FMT_SINK_PREF            2       // The preferred timing of the sink

// EDID
#define PRT_DP_FMT_EDID_BLOCK_SIZE      128
#define PRT_DP_FMT_EDID_MAX_VIC         32
#define PRT_DP_FMT_EDID_MAX_DTD         8

// Format
typedef struct {
     const char *name;                  // Name in the menu
     uint8_t preset;                    // VTB preset
     uint16_t h;                        // Active pixels
     uint16_t v;                        // Active lines
     uint8_t hz;                        // Refresh rate
     uint8_t vic;                       // CTA-861 video identification code, 0 for none
     uint32_t pclk;                     // Pixel clock (kHz)
} prt_dp_fmt_struct;

// Detailed timing from the EDID
typedef struct {
     uint16_t h;                        // Active pixels
     uint16_t v;                        // Active lines
     uint8_t hz;                        // Refresh rate (rounded)
} prt_dp_fmt_dtd_struct;

// What the sink's EDID offers
typedef struct {
     bool valid;                                        // Base block header and checksum are good
     uint8_t extensions;                                // Extension blocks the sink claims to have
     uint8_t vic_cnt;                                   // Short video descriptors found
     uint8_t vic[PRT_DP_FMT_EDID_MAX_VIC];              // Their video identification codes
     uint8_t native_vic;                                // The one flagged native, or 0 for none
     uint8_t dtd_cnt;                                   // Detailed timings found
     prt_dp_fmt_dtd_struct dtd[PRT_DP_FMT_EDID_MAX_DTD]; // The first one is the preferred timing
} prt_dp_fmt_edid_struct;

// Format table
extern const prt_dp_fmt_struct prt_dp_fmt[PRT_DP_FMT_CNT];

// Prototypes

// Parse an EDID that was read from the sink.
// Returns true when the base block is intact.
bool prt_dp_fmt_edid_parse (const uint8_t *dat, uint16_t len, prt_dp_fmt_edid_struct *edid);

// Does the sink support format fmt? Returns PRT_DP_FMT_SINK_NO, _YES or _PREF.
uint8_t prt_dp_fmt_sink (const prt_dp_fmt_edid_struct *edid, uint8_t fmt);

// Does format fmt fit the link (rate as the DPCD link rate code)?
bool prt_dp_fmt_link (uint8_t fmt, uint8_t rate, uint8_t lanes, uint8_t bpc);

// Pick the format for the colorbar.
// The preferred timing of the sink when the board (pclk_max in kHz) and the link carry it at 8 bpc,
// else the largest format the sink supports and the link carries, else format dflt.
uint8_t prt_dp_fmt_pick (const prt_dp_fmt_edid_struct *edid, uint8_t rate, uint8_t lanes, uint32_t pclk_max, uint8_t dflt);

// Find the format of a VTB preset. Returns PRT_DP_FMT_CNT when there is none.
uint8_t prt_dp_fmt_find (uint8_t preset);
