/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP RX Top with APB interface

    (c) 2021 - 2026 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Added parameter P_FAMILY
    v1.2 - Added link training TPS status
    v1.3 - Added parameter P_LNK_SYM (10-bit code groups for Altera Agilex)
    v1.4 - Added SDP parity error output
    

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

`default_nettype none

// Module
module prt_dprx_apb
#(
    // System
    parameter                                   P_VENDOR    = "none",       // Vendor - "AMD", "ALTERA" or "LSC"
    parameter                                   P_FAMILY    = "none",       // Family. Lattice: "LFCPNX", Altera: "AGX" (Agilex)
    parameter                                   P_BEAT      = 'd125,        // Beat value
    parameter                                   P_MST       = 0,            // MST support
    parameter                                   P_SDP       = 0,            // SDP support

    // Link
    parameter                                   P_LANES     = 4,            // Lanes
    parameter                                   P_SPL       = 2,            // Symbols per lane

    // Video
    parameter                                   P_PPC       = 2,            // Pixels per clock
    parameter                                   P_BPC       = 8,            // Bits per component
    parameter                                   P_VID_DAT   = 48,

    // Link data bits per symbol (see prt_dprx_top)
    parameter                                   P_LNK_SYM   = ((P_VENDOR == "ALTERA") && (P_FAMILY == "AGX")) ? 10 : 9
)
(
    // Reset and clock
    input wire                                  SYS_RST_IN,
    input wire                                  SYS_CLK_IN,

    // Host APB interface
    prt_apb_if.slv                              APB_IF,
    output wire                                 HOST_IRQ_OUT, 

    // Misc
    output wire                                 HPD_OUT,            // Hot Plug Detect
    output wire                                 HB_OUT,             // Heart beat
    
    // AUX
    output wire                                 AUX_EN_OUT,
    output wire                                 AUX_TX_OUT,
    input wire                                  AUX_RX_IN,

    // Link
    input wire                                  LNK_CLK_IN,         // Clock
    input wire                                  LNK_LOCK_IN,        // Lock
    input wire [(P_LANES * P_SPL * P_LNK_SYM)-1:0] LNK_DAT_IN,      // Data
    output wire                                 LNK_SYNC_OUT,       // Sync
    output wire [7:0]                           LNK_VBID_OUT,       // VB-ID 

    // Status
    output wire                                 LNK_TRN_TPS_CR_OUT,     // Link training TPS clock recovery sequence
    output wire                                 LNK_TRN_TPS_EQ_OUT,     // Link training TPS equalization sequence
    output wire                                 LNK_TRN_TPS_PASS_OUT,   // Link training TPS passed
    output wire                                 LNK_TRN_TPS_FAIL_OUT,   // Link training TPS failed

    // Video
    input wire                                  VID_CLK_IN,         // Clock
    input wire                                  VID_RDY_IN,         // Ready
    output wire                                 VID_SOF_OUT,        // Start of frame
    output wire                                 VID_EOL_OUT,        // End of line
    output wire [P_VID_DAT-1:0]                 VID_DAT_OUT,        // Data
    output wire                                 VID_VLD_OUT,        // Valid

    // Secondary data packet
    input wire                                  SDP_CLK_IN,         // Clock
    output wire                                 SDP_SOP_OUT,        // Start of packet
    output wire                                 SDP_EOP_OUT,        // End of packet
    output wire [31:0]                          SDP_DAT_OUT,        // Data
    output wire                                 SDP_VLD_OUT,        // Valid
    output wire                                 SDP_ERR_OUT         // Parity error (valid with eop)
);


// Interfaces
prt_lb_if
#(
  .P_ADR_WIDTH  (8)
)
lb_if();

prt_dp_lb_if
#(
  .P_ADR_WIDTH  (8)
)
dp_lb_if();


//------
// APB bridge 
//------
    prt_apb2lb
    APB_INST
    (
        // Reset and clock
        .RST_IN     (SYS_RST_IN),              // Reset (from host)  
        .CLK_IN     (SYS_CLK_IN),              // Clock

        // APB
        .APB_IF     (APB_IF),

        // Local bus interface
        .LB_IF      (lb_if)
    );

// Currently the DPRX uses the DP interface variant of the local bus. 
// The APB bridge uses the common local bus interface. 
// This is the same interface, so map the signals to make it compatible with the DPRX top module.
    assign dp_lb_if.adr = lb_if.adr;
    assign dp_lb_if.wr = lb_if.wr;
    assign dp_lb_if.rd = lb_if.rd;
    assign dp_lb_if.din = lb_if.din;
    assign lb_if.dout = dp_lb_if.dout;
    assign lb_if.vld = dp_lb_if.vld; 


//------
// DPRX
//------
    prt_dprx_top
    #(
        // System
        .P_VENDOR               (P_VENDOR),      // Vendor - "AMD", "ALTERA" or "LSC"
        .P_FAMILY               (P_FAMILY),      // Family

        .P_BEAT                 (P_BEAT),        // Beat value
        .P_MST                  (P_MST),         // MST support
        .P_SDP                  (P_SDP),         // SDP support

        // Link
        .P_LANES                (P_LANES),       // Lanes
        .P_SPL                  (P_SPL),         // Symbols per lane

        // Video
        .P_PPC                  (P_PPC),         // Pixels per clock
        .P_BPC                  (P_BPC),         // Bits per component
        .P_VID_DAT              (P_VID_DAT),

        // Link data bits per symbol
        .P_LNK_SYM              (P_LNK_SYM)
    )
    DPRX_INST
    (
        // Reset and clock
        .SYS_RST_IN             (SYS_RST_IN),
        .SYS_CLK_IN             (SYS_CLK_IN),

        // Host Local bus interface
        .HOST_IF                (dp_lb_if),
        .HOST_IRQ_OUT           (HOST_IRQ_OUT), 

        // Misc
        .HPD_OUT                (HPD_OUT),            // Hot Plug Detect
        .HB_OUT                 (HB_OUT),             // Heart beat
        
        // AUX
        .AUX_EN_OUT             (AUX_EN_OUT),
        .AUX_TX_OUT             (AUX_TX_OUT),
        .AUX_RX_IN              (AUX_RX_IN),

        // Link
        .LNK_CLK_IN             (LNK_CLK_IN),               // Clock
        .LNK_LOCK_IN            (LNK_LOCK_IN),              // Lock
        .LNK_DAT_IN             (LNK_DAT_IN),               // Data
        .LNK_SYNC_OUT           (LNK_SYNC_OUT),             // Sync
        .LNK_VBID_OUT           (LNK_VBID_OUT),             // VB-ID 

        // Status
        .LNK_TRN_TPS_CR_OUT     (LNK_TRN_TPS_CR_OUT),       // Link training TPS clock recovery sequence
        .LNK_TRN_TPS_EQ_OUT     (LNK_TRN_TPS_EQ_OUT),       // Link training TPS equalization sequence
        .LNK_TRN_TPS_PASS_OUT   (LNK_TRN_TPS_PASS_OUT),     // Link training TPS passed
        .LNK_TRN_TPS_FAIL_OUT   (LNK_TRN_TPS_FAIL_OUT),     // Link training TPS failed

        // Video
        .VID_CLK_IN             (VID_CLK_IN),               // Clock
        .VID_RDY_IN             (VID_RDY_IN),               // Ready
        .VID_SOF_OUT            (VID_SOF_OUT),              // Start of frame
        .VID_EOL_OUT            (VID_EOL_OUT),              // End of line
        .VID_DAT_OUT            (VID_DAT_OUT),              // Data
        .VID_VLD_OUT            (VID_VLD_OUT),              // Valid

        // Secondary data packet
        .SDP_CLK_IN             (SDP_CLK_IN),               // Clock
        .SDP_SOP_OUT            (SDP_SOP_OUT),              // Start of packet
        .SDP_EOP_OUT            (SDP_EOP_OUT),              // End of packet
        .SDP_DAT_OUT            (SDP_DAT_OUT),              // Data
        .SDP_VLD_OUT            (SDP_VLD_OUT),              // Valid
        .SDP_ERR_OUT            (SDP_ERR_OUT)               // Parity error (valid with eop)
    );

endmodule

`default_nettype wire
