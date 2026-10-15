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

// Includes
#include <stddef.h>
#include "prt_dp_fmt.h"
#include "prt_vtb.h"

// Format table
// The VTB presets. A format the CTA-861 has no code for (1440p, the reduced blanking 8K) is only
// found through a detailed timing in the EDID.
const prt_dp_fmt_struct prt_dp_fmt[PRT_DP_FMT_CNT] = {
     {"1280 x 720p50",   VTB_PRESET_1280X720P50,   1280,  720, 50, 19, VTB_1280X720P50_PCLK},
     {"1280 x 720p60",   VTB_PRESET_1280X720P60,   1280,  720, 60,  4, VTB_1280X720P60_PCLK},
     {"1920 x 1080p50",  VTB_PRESET_1920X1080P50,  1920, 1080, 50, 31, VTB_1920X1080P50_PCLK},
     {"1920 x 1080p60",  VTB_PRESET_1920X1080P60,  1920, 1080, 60, 16, VTB_1920X1080P60_PCLK},
     {"2560 x 1440p50",  VTB_PRESET_2560X1440P50,  2560, 1440, 50,  0, VTB_2560X1440P50_PCLK},
     {"2560 x 1440p60",  VTB_PRESET_2560X1440P60,  2560, 1440, 60,  0, VTB_2560X1440P60_PCLK},
     {"3840 x 2160p50",  VTB_PRESET_3840X2160P50,  3840, 2160, 50, 96, VTB_3840X2160P50_PCLK},
     {"3840 x 2160p60",  VTB_PRESET_3840X2160P60,  3840, 2160, 60, 97, VTB_3840X2160P60_PCLK},
     {"7680 x 4320p30",  VTB_PRESET_7680X4320P30,  7680, 4320, 30,  0, VTB_7680X4320P30_PCLK},
};

// EDID
static const uint8_t prt_dp_fmt_edid_header[8] = {0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00};

#define EDID_EXT_CNT_OFFSET             126     // In the base block
#define EDID_DTD_OFFSET                 54      // First of the four descriptors in the base block
#define EDID_DTD_SIZE                   18
#define EDID_EXT_TAG_CTA                0x02
#define CTA_DTD_OFFSET                  2       // Where the descriptors start
#define CTA_COLLECTION_START            4       // Where the data blocks start
#define CTA_TAG_VIDEO                   2       // Video data block, holds the SVDs

// Every 128 byte block carries a checksum byte, so the whole block sums to zero.
static bool prt_dp_fmt_edid_checksum_ok (const uint8_t *block)
{
     uint8_t sum = 0;

     for (uint16_t i = 0; i < PRT_DP_FMT_EDID_BLOCK_SIZE; i++)
          sum += block[i];

     return (sum == 0) ? true : false;
}

// Detailed timing descriptor
// A descriptor with a zero pixel clock is a display descriptor (name, range limits), not a timing.
static void prt_dp_fmt_edid_dtd (const uint8_t *d, prt_dp_fmt_edid_struct *edid)
{
     uint32_t pclk;
     uint32_t htotal;
     uint32_t vtotal;
     prt_dp_fmt_dtd_struct *dtd;

     pclk = ((uint32_t) d[1] << 8) | d[0];           // 10 kHz units

     if ((pclk == 0) || (edid->dtd_cnt >= PRT_DP_FMT_EDID_MAX_DTD))
          return;

     // Interlaced formats are not generated
     if (d[17] & 0x80)
          return;

     dtd = &edid->dtd[edid->dtd_cnt];
     dtd->h = d[2] | ((uint16_t) (d[4] & 0xf0) << 4);
     dtd->v = d[5] | ((uint16_t) (d[7] & 0xf0) << 4);
     htotal = dtd->h + (d[3] | ((uint16_t) (d[4] & 0x0f) << 8));
     vtotal = dtd->v + (d[6] | ((uint16_t) (d[7] & 0x0f) << 8));

     if ((htotal == 0) || (vtotal == 0))
          return;

     dtd->hz = (uint8_t) (((pclk * 10000) + ((htotal * vtotal) / 2)) / (htotal * vtotal));
     edid->dtd_cnt++;
}

// Walk the data block collection of one CTA-861 extension, collect the video identification
// codes and the detailed timings behind the collection.
static void prt_dp_fmt_edid_cta (const uint8_t *ext, prt_dp_fmt_edid_struct *edid)
{
     uint8_t dtd = ext[CTA_DTD_OFFSET];
     uint8_t i;

     // A zero offset means there are no descriptors and no collection.
     if ((dtd < CTA_COLLECTION_START) || (dtd >= PRT_DP_FMT_EDID_BLOCK_SIZE))
          return;

     i = CTA_COLLECTION_START;

     while (i < dtd)
     {
          uint8_t tag = ext[i] >> 5;            // Top three bits
          uint8_t len = ext[i] & 0x1f;          // Bottom five bits, payload only

          // A zero length block cannot be stepped over, and a block may not run into the descriptors.
          if ((len == 0) || ((i + 1 + len) > dtd))
               break;

          if (tag == CTA_TAG_VIDEO)
          {
               for (uint8_t j = 0; j < len; j++)
               {
                    uint8_t svd = ext[i + 1 + j];

                    if (edid->vic_cnt >= PRT_DP_FMT_EDID_MAX_VIC)
                         break;

                    // A short video descriptor of 129 to 192 is code 1 to 64 flagged native,
                    // the other values are the code itself.
                    if ((svd >= 129) && (svd <= 192))
                    {
                         svd &= 0x7f;
                         edid->native_vic = svd;
                    }

                    if (svd)
                         edid->vic[edid->vic_cnt++] = svd;
               }
          }

          i += 1 + len;
     }

     // Detailed timings, up to the padding before the checksum
     for (i = dtd; (i + EDID_DTD_SIZE) < PRT_DP_FMT_EDID_BLOCK_SIZE; i += EDID_DTD_SIZE)
     {
          if ((ext[i] == 0) && (ext[i + 1] == 0))
               break;
          prt_dp_fmt_edid_dtd (&ext[i], edid);
     }
}

// Parse EDID
bool prt_dp_fmt_edid_parse (const uint8_t *dat, uint16_t len, prt_dp_fmt_edid_struct *edid)
{
     uint16_t blocks;

     // Clear first, so a caller that ignores the return value sees an empty list.
     edid->valid = false;
     edid->extensions = 0;
     edid->vic_cnt = 0;
     edid->native_vic = 0;
     edid->dtd_cnt = 0;

     if ((dat == NULL) || (len < PRT_DP_FMT_EDID_BLOCK_SIZE))
          return false;

     for (uint8_t i = 0; i < 8; i++)
     {
          if (dat[i] != prt_dp_fmt_edid_header[i])
               return false;
     }

     if (!prt_dp_fmt_edid_checksum_ok (&dat[0]))
          return false;

     edid->valid = true;
     edid->extensions = dat[EDID_EXT_CNT_OFFSET];

     // Base block descriptors. The first one is the preferred timing.
     for (uint8_t i = 0; i < 4; i++)
          prt_dp_fmt_edid_dtd (&dat[EDID_DTD_OFFSET + (i * EDID_DTD_SIZE)], edid);

     // Trust the extension count, not the size of the buffer.
     blocks = (uint16_t) edid->extensions + 1;

     if (blocks > (len / PRT_DP_FMT_EDID_BLOCK_SIZE))
          blocks = len / PRT_DP_FMT_EDID_BLOCK_SIZE;

     for (uint16_t b = 1; b < blocks; b++)
     {
          const uint8_t *ext = &dat[b * PRT_DP_FMT_EDID_BLOCK_SIZE];

          // A bad extension is skipped, another one may be fine.
          if (!prt_dp_fmt_edid_checksum_ok (ext))
               continue;

          if (ext[0] == EDID_EXT_TAG_CTA)
               prt_dp_fmt_edid_cta (ext, edid);
     }

     return true;
}

// Sink support
uint8_t prt_dp_fmt_sink (const prt_dp_fmt_edid_struct *edid, uint8_t fmt)
{
     const prt_dp_fmt_struct *f;

     if ((edid == NULL) || !edid->valid || (fmt >= PRT_DP_FMT_CNT))
          return PRT_DP_FMT_SINK_NO;

     f = &prt_dp_fmt[fmt];

     // Detailed timings
     for (uint8_t i = 0; i < edid->dtd_cnt; i++)
     {
          if ((edid->dtd[i].h == f->h) && (edid->dtd[i].v == f->v) && (edid->dtd[i].hz == f->hz))
               return (i == 0) ? PRT_DP_FMT_SINK_PREF : PRT_DP_FMT_SINK_YES;
     }

     // Video identification codes
     if (f->vic)
     {
          for (uint8_t i = 0; i < edid->vic_cnt; i++)
          {
               if (edid->vic[i] == f->vic)
                    return PRT_DP_FMT_SINK_YES;
          }
     }

     return PRT_DP_FMT_SINK_NO;
}

// Link bandwidth
// The link rate code is in units of 270 Mbps, and 8b/10b leaves 80 % for the data.
// The pixel clock (kHz) x 3 components x bpc must fit in rate x 270000 kbps x lanes x 0.8.
bool prt_dp_fmt_link (uint8_t fmt, uint8_t rate, uint8_t lanes, uint8_t bpc)
{
     if (fmt >= PRT_DP_FMT_CNT)
          return false;

     return ((prt_dp_fmt[fmt].pclk * 3 * bpc) <= ((uint32_t) rate * lanes * 216000)) ? true : false;
}

// Pick format
uint8_t prt_dp_fmt_pick (const prt_dp_fmt_edid_struct *edid, uint8_t rate, uint8_t lanes, uint32_t pclk_max, uint8_t dflt)
{
     uint8_t best = PRT_DP_FMT_CNT;
     uint8_t sink;

     for (uint8_t i = 0; i < PRT_DP_FMT_CNT; i++)
     {
          if ((prt_dp_fmt[i].pclk > pclk_max) || !prt_dp_fmt_link (i, rate, lanes, 8))
               continue;

          sink = prt_dp_fmt_sink (edid, i);

          if (sink == PRT_DP_FMT_SINK_PREF)
               return i;

          if ((sink == PRT_DP_FMT_SINK_YES)
               && ((best == PRT_DP_FMT_CNT) || (prt_dp_fmt[i].pclk >= prt_dp_fmt[best].pclk)))
               best = i;
     }

     return (best < PRT_DP_FMT_CNT) ? best : dflt;
}

// Find the format of a VTB preset
uint8_t prt_dp_fmt_find (uint8_t preset)
{
     for (uint8_t i = 0; i < PRT_DP_FMT_CNT; i++)
     {
          if (prt_dp_fmt[i].preset == preset)
               return i;
     }

     return PRT_DP_FMT_CNT;
}
