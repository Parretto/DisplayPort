/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: VTB Top with APB interface

    (c) 2021 - 2026 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Added the clock enable DCO (parameter P_DCO, output VID_CKE_OUT)

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

//-----
// Module
//-----
module prt_vtb_apb
#(
     parameter P_VENDOR = "none",                 // Vendor - "AMD", "ALTERA" or "LSC" 
     parameter P_FAMILY = "none",                 // Family (Only used for Lattice)
     parameter P_SYS_FREQ = 'd50_000_000,         // System frequency
     parameter P_PPC = 2,                         // Pixels per clock
     parameter P_BPC = 8,                         // Bits per component
     parameter P_AXIS_DAT = 48,                   // AXIS data width
     parameter P_OVL = 0,                         // Overlay (0 - disable / 1 - Image 1 / 2 - Image 2)
     parameter P_OSD = 0,                         // On screen display, the scroller (0 - disable / 1 - enable)
     parameter P_DCO = 0                          // Clock enable DCO for the video clock recovery (0 - disable / 1 - enable)
)
(
     // System
     input wire                              SYS_RST_IN,                   // Reset
     input wire                              SYS_CLK_IN,                   // Clock

     // Host APB interface
     prt_apb_if.slv                          APB_IF,

     // Direct I2C Access
     input wire                              DIA_RDY_IN,
     output wire [31:0]                      DIA_DAT_OUT,
     output wire                             DIA_VLD_OUT,

     // Link
     input wire                              TX_LNK_CLK_IN,           // TX link clock
     input wire                              RX_LNK_CLK_IN,           // RX link clock
     input wire                              LNK_SYNC_IN,             // Sync

     // Video
     input wire                              VID_CKE_IN,              // Clock enable
     output wire                             VID_CKE_OUT,             // Clock enable (with the DCO)
     input wire                              VID_CLK_IN,              // Clock

     // Video in
     input wire                              AXIS_SOF_IN,             // Start of frame
     input wire                              AXIS_EOL_IN,             // End of line
     input wire [P_AXIS_DAT-1:0]             AXIS_DAT_IN,             // Data
     input wire                              AXIS_VLD_IN,             // Valid

    // Video out
     output wire                             VID_LOCK_OUT,            // Lock
     output wire                             VID_VS_OUT,              // Vsync
     output wire                             VID_HS_OUT,              // Hsync
     output wire [(3 * P_BPC * P_PPC)-1:0]   VID_DAT_OUT,             // Data. Per pixel {R / Cr, B / Cb, G / Y}
     output wire                             VID_DE_OUT               // Data enable out
);


//------
// Interfaces
//------
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

// Currently the VTB uses the DP interface variant of the local bus. 
// The APB bridge uses the common local bus interface. 
// This is the same interface, so map the signals to make it compatible with the DPRX top module.
    assign dp_lb_if.adr = lb_if.adr;
    assign dp_lb_if.wr = lb_if.wr;
    assign dp_lb_if.rd = lb_if.rd;
    assign dp_lb_if.din = lb_if.din;
    assign lb_if.dout = dp_lb_if.dout;
    assign lb_if.vld = dp_lb_if.vld; 


//------
// VTB
//------
    prt_vtb_top
    #(
        .P_VENDOR               (P_VENDOR),
        .P_FAMILY               (P_FAMILY),     // Family
        .P_SYS_FREQ             (P_SYS_FREQ),   // System frequency
        .P_PPC                  (P_PPC),        // Pixels per clock
        .P_BPC                  (P_BPC),        // Bits per component
        .P_AXIS_DAT             (P_AXIS_DAT),
        .P_OVL                  (P_OVL),        // Overlay (0 - disable / 1 - Image 1 / 2 - Image 2)
        .P_OSD                  (P_OSD),        // On screen display (0 - disable / 1 - enable)
        .P_DCO                  (P_DCO)         // Clock enable DCO
    )
    VTB_INST
    (
        // System
        .SYS_RST_IN             (SYS_RST_IN),
        .SYS_CLK_IN             (SYS_CLK_IN),

        // Local bus
        .LB_IF                  (dp_lb_if),

        // Direct I2C Access
        .DIA_RDY_IN             (DIA_RDY_IN),
        .DIA_DAT_OUT            (DIA_DAT_OUT),
        .DIA_VLD_OUT            (DIA_VLD_OUT),

        // Link
        .TX_LNK_CLK_IN          (TX_LNK_CLK_IN),     // TX link clock
        .RX_LNK_CLK_IN          (RX_LNK_CLK_IN),     // RX link clock
        .LNK_SYNC_IN            (LNK_SYNC_IN),

        // Axi-stream Video
        .AXIS_SOF_IN            (AXIS_SOF_IN),      // Start of frame
        .AXIS_EOL_IN            (AXIS_EOL_IN),      // End of line
        .AXIS_DAT_IN            (AXIS_DAT_IN),      // Data
        .AXIS_VLD_IN            (AXIS_VLD_IN),      // Valid       

        // Native video
        .VID_CLK_IN             (VID_CLK_IN),
        .VID_CKE_IN             (VID_CKE_IN),
        .VID_CKE_OUT            (VID_CKE_OUT),
        .VID_LOCK_OUT           (VID_LOCK_OUT),
        .VID_VS_OUT             (VID_VS_OUT),
        .VID_HS_OUT             (VID_HS_OUT),
        .VID_DAT_OUT            (VID_DAT_OUT),
        .VID_DE_OUT             (VID_DE_OUT)
    );


endmodule

`default_nettype wire
