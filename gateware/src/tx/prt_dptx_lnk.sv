/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP TX Link
    (c) 2021, 2022 by Parretto B.V.

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

`default_nettype none

module prt_dptx_lnk
#(
    parameter           P_SIM         = 0,       // Simulation

    // Link
    parameter           P_LANES       = 4,       // Lanes
    parameter           P_SPL         = 2,       // Symbols per lane
   
    // Video
    parameter           P_PPC         = 2,       // Pixels per clock
    parameter           P_BPC         = 8,       // Bits per component

    // Message
    parameter           P_MSG_IDX     = 5,       // Message index width
    parameter           P_MSG_DAT     = 16,      // Message data width
    parameter           P_MSG_ID_CTL  = 'h14,    // Message ID control
    parameter           P_MSG_ID_TPS  = 'h12,    // Message ID training pattern sequence
    parameter           P_MSG_ID_MSA  = 'h13     // Message ID main stream attribute
)
(
    // System
    input wire              SYS_RST_IN,             // System reset
    input wire              SYS_CLK_IN,             // System clock

    // Status
    output wire             STA_LNK_CLKDET_OUT,     // Link clock detect
    output wire             STA_VID_CLKDET_OUT,     // Video clock detect

    // MSG sink
    prt_dp_msg_if.snk       MSG_SNK_IF,             // Message sink

    // Video
    input wire              VID_RST_IN,             // Reset
    input wire              VID_CLK_IN,             // Clock
    input wire              VID_CKE_IN,             // Clock enable
    prt_dp_vid_if.snk       VID_SNK_IF,             // Interface

    // Link source
    input wire              LNK_RST_IN,             // Reset
    input wire              LNK_CLK_IN,             // Clock
    prt_dp_tx_lnk_if.src    LNK_SRC_IF              // Interface
);

// Signals

// Control
wire        lanes_from_ctl;
wire        trn_sel_from_ctl;
wire        vid_en_from_ctl;
wire        efm_from_ctl;
wire        scrm_en_from_ctl;

// Message
prt_dp_msg_if
#(
    .P_DAT_WIDTH (P_MSG_DAT)
) sys_msg_if[0:1]();

prt_dp_msg_if
#(
    .P_DAT_WIDTH (P_MSG_DAT)
) lnk_msg_if[0:3]();

prt_dp_msg_if
#(
    .P_DAT_WIDTH (P_MSG_DAT)
) vid_msg_if[0:1]();

// Video
prt_dp_tx_lnk_if
#(
  .P_LANES  (P_LANES),
  .P_SPL    (P_SPL)
)
lnk_from_vid();
wire vs_from_vid;
wire vbf_from_vid;
wire bs_from_vid;

// MSA
prt_dp_tx_lnk_if
#(
  .P_LANES  (P_LANES),
  .P_SPL    (P_SPL)
)
lnk_from_msa();

// Skew
prt_dp_tx_lnk_if
#(
  .P_LANES  (1),
  .P_SPL    (P_SPL)
)
lnk_to_skew_lane[0:P_LANES-1]();

prt_dp_tx_lnk_if
#(
  .P_LANES  (1),
  .P_SPL    (P_SPL)
)
lnk_from_skew_lane[0:P_LANES-1]();

// Scrambler
prt_dp_tx_lnk_if
#(
  .P_LANES  (1),
  .P_SPL    (P_SPL)
)
lnk_from_scrm_lane[0:P_LANES-1]();

prt_dp_tx_lnk_if
#(
  .P_LANES  (P_LANES),
  .P_SPL    (P_SPL)
)
lnk_from_scrm();

genvar i;

// Logic

// Repeat system message 
    assign {sys_msg_if[0].som, sys_msg_if[1].som} = {2{MSG_SNK_IF.som}};
    assign {sys_msg_if[0].eom, sys_msg_if[1].eom} = {2{MSG_SNK_IF.eom}};
    assign {sys_msg_if[0].dat, sys_msg_if[1].dat} = {2{MSG_SNK_IF.dat}};
    assign {sys_msg_if[0].vld, sys_msg_if[1].vld} = {2{MSG_SNK_IF.vld}};

// Link message Clock domain converter
    prt_dp_msg_cdc
    #(
        .P_DAT_WIDTH        (P_MSG_DAT)
    )
    LNK_MSG_CDC_INST
    (
        // Reset and clock
        .A_RST_IN           (SYS_RST_IN),
        .B_RST_IN           (LNK_RST_IN),
        .A_CLK_IN           (SYS_CLK_IN),
        .B_CLK_IN           (LNK_CLK_IN),

        // Port A 
        .A_MSG_SNK_IF       (sys_msg_if[0]),   // Sink

        // Port B
        .B_MSG_SRC_IF       (lnk_msg_if[0])
    );

// Video message Clock domain converter
    prt_dp_msg_cdc
    #(
        .P_DAT_WIDTH        (P_MSG_DAT)
    )
    VID_MSG_CDC_INST
    (
        // Reset and clock
        .A_RST_IN           (SYS_RST_IN),
        .B_RST_IN           (VID_RST_IN),
        .A_CLK_IN           (SYS_CLK_IN),
        .B_CLK_IN           (VID_CLK_IN),

        // Port A
        .A_MSG_SNK_IF       (sys_msg_if[1]),

        // Port B
        .B_MSG_SRC_IF       (vid_msg_if[0])
    );

// Link clock detector
    prt_dp_clkdet
    LNK_CLKDET_INST
    (
        // System reset and clock
        .SYS_RST_IN         (SYS_RST_IN),
        .SYS_CLK_IN         (SYS_CLK_IN),

        // Monitor reset and clock
        .MON_RST_IN         (LNK_RST_IN),
        .MON_CLK_IN         (LNK_CLK_IN),

        // Status
        .STA_ACT_OUT        (STA_LNK_CLKDET_OUT)
    );

// Video clock detector
    prt_dp_clkdet
    VID_CLKDET_INST
    (
        // System reset and clock
        .SYS_RST_IN         (SYS_RST_IN),
        .SYS_CLK_IN         (SYS_CLK_IN),

        // Monitor reset and clock
        .MON_RST_IN         (VID_RST_IN),
        .MON_CLK_IN         (VID_CLK_IN),

        // Status
        .STA_ACT_OUT        (STA_VID_CLKDET_OUT)
    );

// Control
    prt_dptx_ctl
    #(
        // Message
        .P_MSG_IDX          (P_MSG_IDX),        // Index width
        .P_MSG_DAT          (P_MSG_DAT),        // Data width
        .P_MSG_ID           (P_MSG_ID_CTL)      // Message ID control
    )
    CTL_INST
    (
        // Reset and clock
        .RST_IN             (LNK_RST_IN),
        .CLK_IN             (LNK_CLK_IN),

        // Message
        .MSG_SNK_IF         (lnk_msg_if[0]),        // Sink
        .MSG_SRC_IF         (lnk_msg_if[1]),        // Source

        // Control output
        .CTL_LANES_OUT      (lanes_from_ctl),       // Lanes
        .CTL_TRN_SEL_OUT    (trn_sel_from_ctl),     // Training select
        .CTL_VID_EN_OUT     (vid_en_from_ctl),      // Video enable
        .CTL_EFM_OUT        (efm_from_ctl),         // Enhanced framing mode
        .CTL_SCRM_EN_OUT    (scrm_en_from_ctl)      // Scrambler enable
    );

// Video
    prt_dptx_vid
    #(
        // Link
        .P_LANES            (P_LANES),              // Lanes
        .P_SPL              (P_SPL),                // Symbols per lane

        // Video
        .P_PPC              (P_PPC),                // Pixels per clock
        .P_BPC              (P_BPC),                // Bits per component

        // Message
        .P_MSG_IDX          (P_MSG_IDX),            // Index width
        .P_MSG_DAT          (P_MSG_DAT),            // Data width
        .P_MSG_ID_MSA       (P_MSG_ID_MSA)          // Message ID MSA (main stream attribute)
    )
    VID_INST
    (
        // Control
        .CTL_LANES_IN       (lanes_from_ctl),       // Active lanes (0 - 2 lanes / 1 - 4 lanes)
        .CTL_EN_IN          (vid_en_from_ctl),      // Enable
       
        // Video message
        .VID_MSG_SNK_IF     (vid_msg_if[0]),        // Sink
        .VID_MSG_SRC_IF     (vid_msg_if[1]),        // Source

        // Video
        .VID_RST_IN         (VID_RST_IN),           // Reset
        .VID_CLK_IN         (VID_CLK_IN),           // Clock
        .VID_CKE_IN         (VID_CKE_IN),           // Clock enable
        .VID_SNK_IF         (VID_SNK_IF),           // Interface

        // Link 
        .LNK_RST_IN         (LNK_RST_IN),           // Reset
        .LNK_CLK_IN         (LNK_CLK_IN),           // Clock
        .LNK_SRC_IF         (lnk_from_vid),         // Source
        .LNK_VS_OUT         (vs_from_vid),          // Vsync 
        .LNK_VBF_OUT        (vbf_from_vid),         // Vertical blanking flag
        .LNK_BS_OUT         (bs_from_vid)           // Blanking start
    );

// MSA
    prt_dptx_msa
    #(
        // Simulation
        .P_SIM              (P_SIM),                // Simulation
        
        // Link
        .P_LANES            (P_LANES),              // Lanes
        .P_SPL              (P_SPL),                // Symbols per lane

        // Message
        .P_MSG_IDX          (P_MSG_IDX),            // Index width
        .P_MSG_DAT          (P_MSG_DAT),            // Data width
        .P_MSG_ID_MSA       (P_MSG_ID_MSA)          // Message ID MSA (main stream attribute)
    )
    MSA_INST
    (
        // Reset and clocks
        .LNK_RST_IN         (LNK_RST_IN),           // Link reset
        .LNK_CLK_IN         (LNK_CLK_IN),           // Link clock
        .VID_CLK_IN         (VID_CLK_IN),           // Video clock
        .VID_CKE_IN         (VID_CKE_IN),           // Clock enable

        // Control
        .CTL_LANES_IN       (lanes_from_ctl),       // Active lanes (0 - 2 lanes / 1 - 4 lanes)
        .CTL_VID_EN_IN      (vid_en_from_ctl),      // Video Enable
        .CTL_EFM_IN         (efm_from_ctl),         // Enhanced framing mode

        // Message
        .MSG_SNK_IF         (lnk_msg_if[2]),        // Sink
        .MSG_SRC_IF         (lnk_msg_if[3]),        // Source

        // Video
        .LNK_VS_IN          (vs_from_vid),          // Vsync
        .LNK_VBF_IN         (vbf_from_vid),         // Vertical blanking flag
        .LNK_BS_IN          (bs_from_vid),          // Blanking start       

        // Link
        .LNK_SNK_IF         (lnk_from_vid),         // Sink    
        .LNK_SRC_IF         (lnk_from_msa)          // Source
    );

// Skew
generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_skew

        assign lnk_to_skew_lane[i].disp_ctl[0]  = lnk_from_msa.disp_ctl[i];
        assign lnk_to_skew_lane[i].disp_val[0]  = lnk_from_msa.disp_val[i];
        assign lnk_to_skew_lane[i].k[0]         = lnk_from_msa.k[i];
        assign lnk_to_skew_lane[i].dat[0]       = lnk_from_msa.dat[i];
        
        prt_dptx_skew
        #(
            // Link
            .P_SKEW         (i),                      // Skew
            .P_SPL          (P_SPL)                   // Symbols per lane
        )
        SKEW_INST
        (
            .CLK_IN         (LNK_CLK_IN),             // Clock

            // Link
            .LNK_SNK_IF     (lnk_to_skew_lane[i]),    // Sink
            .LNK_SRC_IF     (lnk_from_skew_lane[i])   // Source
        );
    end
endgenerate

// Scrambler
generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_scrm
        prt_dptx_scrm
        #(  
            .P_SIM          (P_SIM),                    // Simulation

            // Link
            .P_SPL          (P_SPL)                     // Symbols per lane
        )
        SCRM_INST
        (
            .RST_IN         (LNK_RST_IN),               // Reset
            .CLK_IN         (LNK_CLK_IN),               // Clock

            // Control
            .CTL_EN_IN      (scrm_en_from_ctl),         // Enable
            .CTL_EFM_IN     (efm_from_ctl),             // Enhanced framing mode

            // Link
            .LNK_SNK_IF     (lnk_from_skew_lane[i]),    // Sink
            .LNK_SRC_IF     (lnk_from_scrm_lane[i])     // Source
        );

        assign lnk_from_scrm.disp_ctl[i]   = lnk_from_scrm_lane[i].disp_ctl[0];
        assign lnk_from_scrm.disp_val[i]   = lnk_from_scrm_lane[i].disp_val[0];
        assign lnk_from_scrm.k[i]          = lnk_from_scrm_lane[i].k[0];
        assign lnk_from_scrm.dat[i]        = lnk_from_scrm_lane[i].dat[0];
    end
endgenerate

// Training
    prt_dptx_trn
    #(
        // Link
        .P_LANES            (P_LANES),              // Lanes
        .P_SPL              (P_SPL),                // Symbols per lane

        // Message
        .P_MSG_IDX          (P_MSG_IDX),            // Index width
        .P_MSG_DAT          (P_MSG_DAT),            // Data width
        .P_MSG_ID_TPS       (P_MSG_ID_TPS)          // Message ID Training Pattern Sequence
    )
    TRN_INST
    (
        // Reset and clock
        .RST_IN             (LNK_RST_IN),           // Reset
        .CLK_IN             (LNK_CLK_IN),           // Clock

        // Control
        .CTL_LANES_IN       (lanes_from_ctl),       // Active lanes (0 - 2 lanes / 1 - 4 lanes)
        .CTL_SEL_IN         (trn_sel_from_ctl),     // Select 0 - main link / 1 - training 

        // Message
        .MSG_SNK_IF         (lnk_msg_if[1]),        // Sink
        .MSG_SRC_IF         (lnk_msg_if[2]),        // Source

        // Link
        .LNK_SNK_IF         (lnk_from_scrm),        // Sink
        .LNK_SRC_IF         (LNK_SRC_IF)            // Source
    );

endmodule

`default_nettype wire
