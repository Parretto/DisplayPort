/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP Tokens Header
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

// Tokens
  #define PRT_DP_MAIL_ERR              0x00
  #define PRT_DP_MAIL_OK               0x01
  #define PRT_DP_MAIL_DEBUG            0x02    // Debug
  #define PRT_DP_MAIL_PING             0x03    // Ping
  #define PRT_DP_MAIL_CFG              0x04    // Config
  #define PRT_DP_MAIL_STA              0x05    // Status
  #define PRT_DP_MAIL_RUN              0x06    // Run
  #define PRT_DP_MAIL_LIC              0x07    // License key

  #define PRT_DP_MAIL_HPD_UNPLUG       0x10    // HPD unplug event
  #define PRT_DP_MAIL_HPD_PLUG         0x11    // HPD plug event
  #define PRT_DP_MAIL_HPD_IRQ          0x12    // HPD irq event
  #define PRT_DP_MAIL_HPD_FORCE        0x13    // HPD force / TX only

  #define PRT_DP_MAIL_PHY_TST          0x21    // PHY test
  #define PRT_DP_MAIL_AUX_TST          0x22    // AUX test
  
  #define PRT_DP_MAIL_TRN_STR          0x30    // Training start / TX only
  #define PRT_DP_MAIL_TRN_PASS         0x31    // Training pass
  #define PRT_DP_MAIL_TRN_ERR          0x32    // Training error
  #define PRT_DP_MAIL_TRN_CR           0x33    // Training clock recovery / RX Only 

  #define PRT_DP_MAIL_LNK_RATE_REQ     0x40    // Link rate request
  #define PRT_DP_MAIL_LNK_VAP_REQ      0x41    // Link voltage and pre-amble request
  #define PRT_DP_MAIL_LNK_REQ_OK       0x42    // Link request ok
  #define PRT_DP_MAIL_LNK_UP           0x44    // Link up
  #define PRT_DP_MAIL_LNK_DOWN         0x45    // Link down

  #define PRT_DP_MAIL_VID_STR          0x60    // Video start / TX only
  #define PRT_DP_MAIL_VID_STP          0x61    // Video stop / TX only
  #define PRT_DP_MAIL_VID_UP           0x62    // Video up / RX only
  #define PRT_DP_MAIL_VID_DOWN         0x63    // Video down / RX only
  #define PRT_DP_MAIL_MSA_DAT          0x66    // Main stream attributes data block (MSA)

  #define PRT_DP_MAIL_DPCD_WR          0x70    // DPCD write
  #define PRT_DP_MAIL_DPCD_RD          0x71    // DPCD read
  #define PRT_DP_MAIL_DPCD_ACK         0x72    // DPCD ack
  #define PRT_DP_MAIL_DPCD_NACK        0x73    // DPCD nack
  #define PRT_DP_MAIL_DPCD_DEFER       0x74    // DPCD defer
  
  #define PRT_DP_MAIL_EDID_RD          0x80    // EDID read
  #define PRT_DP_MAIL_EDID_DAT         0x81    // EDID data

  #define PRT_DP_MAIL_MST_STR          0x90    // MST start
  #define PRT_DP_MAIL_MST_STP          0x91    // MST stop

  #define PRT_DP_MAIL_SOM              0x100   // Start of mail token
  #define PRT_DP_MAIL_EOM              0x1ff   // End of mail token

// Link down
  #define PRT_DP_LNK_DOWN_PHY          1       // PHY error
  #define PRT_DP_LNK_DOWN_CLK          2       // Link no clock / clock lost
  #define PRT_DP_LNK_DOWN_CDR          3       // CDR loss of lock
  #define PRT_DP_LNK_DOWN_SCRM         4       // Scrambler loss of lock
  #define PRT_DP_LNK_DOWN_TRN          5       // Training failed
  #define PRT_DP_LNK_DOWN_HPD          6       // HPD 
  #define PRT_DP_LNK_DOWN_VID          7       // Video error
  #define PRT_DP_LNK_DOWN_IDLE         8       // Idle
  #define PRT_DP_LNK_DOWN_TO           9       // Time out

// Video down
  #define PRT_DP_VID_DOWN_CLK          1       // No clock
  #define PRT_DP_VID_DOWN_IDLE         2       // Idle
  #define PRT_DP_VID_DOWN_LNK          3       // Link went down
  #define PRT_DP_VID_DOWN_ERR          4       // Error

// MST status
  #define PRT_DP_MST_OK                1       // MST ok
  #define PRT_DP_MST_ERR               2       // MST error
  #define PRT_DP_MST_NO_LOGIC          3       // No MST logic
  #define PRT_DP_MST_SNK_NO_CAP        4       // Sink doesn't support MST

// Config
  #define PRT_DP_CFG_MAX_RATE          0
  #define PRT_DP_CFG_MAX_LANES         1
  #define PRT_DP_CFG_MST_CAP           2
