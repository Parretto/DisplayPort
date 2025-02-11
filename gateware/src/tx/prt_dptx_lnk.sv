/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP TX Link
    (c) 2021 - 2025 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Restructured modules
    v1.2 - Updated TX interfaces
    v1.3 - Added MST support
    v1.4 - Added 10-bits video support

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

module prt_dptx_lnk
#(
    // System
    parameter           P_VENDOR       = "none",  // Vendor - "AMD", "ALTERA" or "LSC"
    parameter           P_SIM          = 0,       // Simulation
    parameter           P_MST          = 0,       // MST support

    // Link
    parameter           P_LANES        = 4,       // Lanes
    parameter           P_SPL          = 2,       // Symbols per lane

    // Video
    parameter           P_PPC          = 2,       // Pixels per clock
    parameter           P_BPC          = 8,       // Bits per component

    // Message
    parameter           P_MSG_IDX      = 5,       // Message index width
    parameter           P_MSG_DAT      = 16,      // Message data width
    parameter           P_MSG_ID_CTL   = 'h10,    // Message ID control
    parameter           P_MSG_ID_TPS   = 'h11,    // Message ID training pattern sequence
    parameter           P_MSG_ID_MSA0  = 'h12,    // Message ID main stream attribute 0
    parameter           P_MSG_ID_MSA1  = 'h13,    // Message ID main stream attribute 1
    parameter           P_MSG_ID_MST   = 'h14     // Message ID MST
)
(
    // System
    input wire              SYS_RST_IN,             // System reset
    input wire              SYS_CLK_IN,             // System clock

    // Status
    output wire             STA_LNK_CLKDET_OUT,     // Link clock detect
    output wire [1:0]       STA_VID_CLKDET_OUT,     // Video clock detect

    // MSG sink
    prt_dp_msg_if.snk       MSG_SNK_IF,             // Message sink

    // Video stream 0
    input wire              VID0_RST_IN,            // Reset
    input wire              VID0_CLK_IN,            // Clock
    input wire              VID0_CKE_IN,            // Clock enable
    prt_dp_vid_if.snk       VID0_SNK_IF,            // Interface

    // Video stream 1
    input wire              VID1_RST_IN,            // Reset
    input wire              VID1_CLK_IN,            // Clock
    input wire              VID1_CKE_IN,            // Clock enable
    prt_dp_vid_if.snk       VID1_SNK_IF,            // Interface

    // Link source
    input wire              LNK_RST_IN,             // Reset
    input wire              LNK_CLK_IN,             // Clock
    prt_dp_tx_phy_if.src    LNK_SRC_IF              // Interface
);

// Parameters
localparam P_VID_MODS = (P_MST) ? 2 : 1;
localparam P_MSA_MODS = (P_MST) ? 2 : 1;
localparam P_SYS_MSG_IF = (P_MST) ? 3 : 2;
localparam P_LNK_MSG_IF = (P_MST) ? 5 : 4;
localparam P_VID_MSG_IF = 2;

// Signals

// Control
wire [1:0]  lanes_from_ctl;
wire        trn_sel_from_ctl;
wire [1:0]  vid_en_from_ctl;
wire        mst_en_from_ctl;
wire        mst_act_from_ctl;
wire        scrm_en_from_ctl;
wire        tps4_from_ctl;
wire [1:0]  bpc_from_ctl;
wire [5:0]  vc_ts_from_ctl[0:1];

// Message
prt_dp_msg_if
#(
    .P_DAT_WIDTH (P_MSG_DAT)
) sys_msg_if[0:P_SYS_MSG_IF-1]();

prt_dp_msg_if
#(
    .P_DAT_WIDTH (P_MSG_DAT)
) lnk_msg_if[0:P_LNK_MSG_IF-1]();

// Video message interface stream 0
prt_dp_msg_if
#(
    .P_DAT_WIDTH (P_MSG_DAT)
) vid0_msg_if[0:P_VID_MSG_IF-1]();

// Video message interface stream 1
prt_dp_msg_if
#(
    .P_DAT_WIDTH (P_MSG_DAT)
) vid1_msg_if[0:P_VID_MSG_IF-1]();

// Video
prt_dp_tx_lnk_if
#(
  .P_LANES  (P_LANES),
  .P_SPL    (P_SPL)
)
lnk_from_vid[0:P_VID_MODS-1]();
wire [P_VID_MODS-1:0] vs_from_vid;
wire [P_VID_MODS-1:0] vbf_from_vid;

// MSA
prt_dp_tx_lnk_if
#(
  .P_LANES  (P_LANES),
  .P_SPL    (P_SPL)
)
lnk_from_msa[0:P_MSA_MODS-1]();

// MST
prt_dp_tx_lnk_if
#(
    .P_LANES  (P_LANES),
    .P_SPL    (P_SPL)
)
lnk_from_mst();

// Scrambler
prt_dp_tx_lnk_if
#(
  .P_LANES  (1),
  .P_SPL    (P_SPL)
)
lnk_to_scrm_lane[0:P_LANES-1]();

prt_dp_tx_phy_if
#(
  .P_LANES  (1),
  .P_SPL    (P_SPL)
)
lnk_from_scrm_lane[0:P_LANES-1]();

prt_dp_tx_phy_if
#(
  .P_LANES  (P_LANES),
  .P_SPL    (P_SPL)
)
lnk_from_scrm();

// Training
prt_dp_tx_phy_if
#(
  .P_LANES  (P_LANES),
  .P_SPL    (P_SPL)
)
lnk_from_trn();

// Skew
prt_dp_tx_phy_if
#(
  .P_LANES  (1),
  .P_SPL    (P_SPL)
)
lnk_to_skew_lane[0:P_LANES-1]();

prt_dp_tx_phy_if
#(
  .P_LANES  (1),
  .P_SPL    (P_SPL)
)
lnk_from_skew_lane[0:P_LANES-1]();

prt_dp_tx_phy_if
#(
  .P_LANES  (P_LANES),
  .P_SPL    (P_SPL)
)
lnk_from_skew();

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
        .P_VENDOR           (P_VENDOR),
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

// Video stream 0 message Clock domain converter
    prt_dp_msg_cdc
    #(
        .P_VENDOR           (P_VENDOR),
        .P_DAT_WIDTH        (P_MSG_DAT)
    )
    VID0_MSG_CDC_INST
    (
        // Reset and clock
        .A_RST_IN           (SYS_RST_IN),
        .B_RST_IN           (VID0_RST_IN),
        .A_CLK_IN           (SYS_CLK_IN),
        .B_CLK_IN           (VID0_CLK_IN),

        // Port A
        .A_MSG_SNK_IF       (sys_msg_if[1]),

        // Port B
        .B_MSG_SRC_IF       (vid0_msg_if[0])
    );

// Video stream 1 message Clock domain converter
generate
    if (P_MST)
    begin : gen_vid1_msg_cdc

        assign sys_msg_if[2].som = MSG_SNK_IF.som;
        assign sys_msg_if[2].eom = MSG_SNK_IF.eom;
        assign sys_msg_if[2].dat = MSG_SNK_IF.dat;
        assign sys_msg_if[2].vld = MSG_SNK_IF.vld;

        prt_dp_msg_cdc
        #(
            .P_VENDOR           (P_VENDOR),
            .P_DAT_WIDTH        (P_MSG_DAT)
        )
        VID1_MSG_CDC_INST
        (
            // Reset and clock
            .A_RST_IN           (SYS_RST_IN),
            .B_RST_IN           (VID1_RST_IN),
            .A_CLK_IN           (SYS_CLK_IN),
            .B_CLK_IN           (VID1_CLK_IN),

            // Port A
            .A_MSG_SNK_IF       (sys_msg_if[2]),

            // Port B
            .B_MSG_SRC_IF       (vid1_msg_if[0])
        );
    end

    else
    begin
        assign vid1_msg_if[0].som = 0;
        assign vid1_msg_if[0].eom = 0;
        assign vid1_msg_if[0].dat = 0;
        assign vid1_msg_if[0].vld = 0;
    end
endgenerate

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

// Video clock detector stream 0
    prt_dp_clkdet
    VID_CLKDET0_INST
    (
        // System reset and clock
        .SYS_RST_IN         (SYS_RST_IN),
        .SYS_CLK_IN         (SYS_CLK_IN),

        // Monitor reset and clock
        .MON_RST_IN         (VID0_RST_IN),
        .MON_CLK_IN         (VID0_CLK_IN),

        // Status
        .STA_ACT_OUT        (STA_VID_CLKDET_OUT[0])
    );

// Video clock detector stream 1
generate
    if (P_MST)
    begin : gen_vid_clkdet1
        prt_dp_clkdet
        VID_CLKDET1_INST
        (
            // System reset and clock
            .SYS_RST_IN         (SYS_RST_IN),
            .SYS_CLK_IN         (SYS_CLK_IN),

            // Monitor reset and clock
            .MON_RST_IN         (VID1_RST_IN),
            .MON_CLK_IN         (VID1_CLK_IN),

            // Status
            .STA_ACT_OUT        (STA_VID_CLKDET_OUT[1])
        );
    end

    else
    begin
        assign STA_VID_CLKDET_OUT[1] = 1'b0;
    end
endgenerate

// Control
    prt_dptx_ctl
    #(
        // System
        .P_MST              (P_MST),            // MST
        
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
        .CTL_LANES_OUT      (lanes_from_ctl),       // Active lanes (1 - 1 lane / 2 - 2 lanes / 3 - 4 lanes)
        .CTL_TRN_SEL_OUT    (trn_sel_from_ctl),     // Training select
        .CTL_VID_EN_OUT     (vid_en_from_ctl),      // Video enable
        .CTL_MST_EN_OUT     (mst_en_from_ctl),      // MST enable / disable
        .CTL_MST_ACT_OUT    (mst_act_from_ctl),     // MST allocation change trigger (ACT)
        .CTL_SCRM_EN_OUT    (scrm_en_from_ctl),     // Scrambler enable
        .CTL_TPS4_OUT       (tps4_from_ctl),        // TPS4
        .CTL_BPC_OUT        (bpc_from_ctl),         // Active bits-per-component (0 - 8 bits / 1 - 10 bits / 2 - reserved / 3 - reserved)
        .CTL_VC0_TS_OUT     (vc_ts_from_ctl[0]),    // VC0 time slots
        .CTL_VC1_TS_OUT     (vc_ts_from_ctl[1])     // VC1 time slots
    );

// Video stream 0
    prt_dptx_vid
    #(
        // System
        .P_VENDOR           (P_VENDOR),             // Vendor
        .P_SIM              (P_SIM),                // Simulation
        .P_STREAM           (0),                    // Stream

        // Link
        .P_LANES            (P_LANES),              // Lanes
        .P_SPL              (P_SPL),                // Symbols per lane

        // Video
        .P_PPC              (P_PPC),                // Pixels per clock
        .P_BPC              (P_BPC),                // Bits per component

        // Message
        .P_MSG_IDX          (P_MSG_IDX),            // Index width
        .P_MSG_DAT          (P_MSG_DAT),            // Data width
        .P_MSG_ID           (P_MSG_ID_MSA0)         // Message ID MSA (main stream attribute)
    )
    VID0_INST
    (
        // Control
        .CTL_LANES_IN       (lanes_from_ctl),       // Active lanes (1 - 1 lane / 2 - 2 lanes / 3 - 4 lanes)
        .CTL_EN_IN          (vid_en_from_ctl[0]),   // Video enable
        .CTL_MST_IN         (mst_en_from_ctl),      // MST enable
        .CTL_VC_LEN_IN      (vc_ts_from_ctl[0]),    // VC time slots
        .CTL_BPC_IN         (bpc_from_ctl),         // Active bits-per-component (0 - 8 bits / 1 - 10 bits / 2 - reserved / 3 - reserved)

        // Video message
        .VID_MSG_SNK_IF     (vid0_msg_if[0]),       // Sink
        .VID_MSG_SRC_IF     (vid0_msg_if[1]),       // Source

        // Video
        .VID_RST_IN         (VID0_RST_IN),           // Reset
        .VID_CLK_IN         (VID0_CLK_IN),           // Clock
        .VID_CKE_IN         (VID0_CKE_IN),           // Clock enable
        .VID_SNK_IF         (VID0_SNK_IF),           // Interface

        // Link 
        .LNK_RST_IN         (LNK_RST_IN),            // Reset
        .LNK_CLK_IN         (LNK_CLK_IN),            // Clock
        .LNK_SRC_IF         (lnk_from_vid[0]),       // Source
        .LNK_VS_OUT         (vs_from_vid[0]),        // Vsync 
        .LNK_VBF_OUT        (vbf_from_vid[0])        // Vertical blanking flag
    );

// Video stream 1
generate
    if (P_MST)
    begin : gen_vid1
        prt_dptx_vid
        #(
            // System
            .P_VENDOR           (P_VENDOR),             // Vendor
            .P_SIM              (P_SIM),                // Simulation
            .P_STREAM           (1),                    // Stream

            // Link
            .P_LANES            (P_LANES),              // Lanes
            .P_SPL              (P_SPL),                // Symbols per lane

            // Video
            .P_PPC              (P_PPC),                // Pixels per clock
            .P_BPC              (P_BPC),                // Bits per component

            // Message
            .P_MSG_IDX          (P_MSG_IDX),            // Index width
            .P_MSG_DAT          (P_MSG_DAT),            // Data width
            .P_MSG_ID           (P_MSG_ID_MSA1)         // Message ID MSA (main stream attribute)
        )
        VID1_INST
        (
            // Control
            .CTL_LANES_IN       (lanes_from_ctl),       // Active lanes (1 - 1 lane / 2 - 2 lanes / 3 - 4 lanes)
            .CTL_EN_IN          (vid_en_from_ctl[1]),   // Video enable
            .CTL_MST_IN         (mst_en_from_ctl),      // MST enable
            .CTL_VC_LEN_IN      (vc_ts_from_ctl[1]),    // VC time slots
            .CTL_BPC_IN         (bpc_from_ctl),         // Active bits-per-component (0 - 8 bits / 1 - 10 bits / 2 - reserved / 3 - reserved)

            // Video message
            .VID_MSG_SNK_IF     (vid1_msg_if[0]),        // Sink
            .VID_MSG_SRC_IF     (vid1_msg_if[1]),        // Source

            // Video
            .VID_RST_IN         (VID1_RST_IN),          // Reset
            .VID_CLK_IN         (VID1_CLK_IN),          // Clock
            .VID_CKE_IN         (VID1_CKE_IN),          // Clock enable
            .VID_SNK_IF         (VID1_SNK_IF),          // Interface

            // Link 
            .LNK_RST_IN         (LNK_RST_IN),           // Reset
            .LNK_CLK_IN         (LNK_CLK_IN),           // Clock
            .LNK_SRC_IF         (lnk_from_vid[1]),      // Source
            .LNK_VS_OUT         (vs_from_vid[1]),       // Vsync 
            .LNK_VBF_OUT        (vbf_from_vid[1])       // Vertical blanking flag
        );
    end
endgenerate

// MSA stream 0
    prt_dptx_msa
    #(
        // System
        .P_VENDOR           (P_VENDOR),
        .P_SIM              (P_SIM),                // Simulation
        .P_STREAM           (0),                    // Stream

        // Link
        .P_LANES            (P_LANES),              // Lanes
        .P_SPL              (P_SPL),                // Symbols per lane

        // Video 
        .P_PPC              (P_PPC),                // Pixels per clock

        // Message
        .P_MSG_IDX          (P_MSG_IDX),            // Index width
        .P_MSG_DAT          (P_MSG_DAT),            // Data width
        .P_MSG_ID           (P_MSG_ID_MSA0)         // Message ID MSA (main stream attribute)
    )
    MSA0_INST
    (
        // Reset and clocks
        .LNK_RST_IN         (LNK_RST_IN),           // Link reset
        .LNK_CLK_IN         (LNK_CLK_IN),           // Link clock
        .VID_CLK_IN         (VID0_CLK_IN),          // Video clock
        .VID_CKE_IN         (VID0_CKE_IN),          // Clock enable

        // Control
        .CTL_LANES_IN       (lanes_from_ctl),       // Active lanes (0 - 2 lanes / 1 - 4 lanes)
        .CTL_VID_EN_IN      (vid_en_from_ctl[0]),   // Video Enable
        .CTL_SCRM_EN_IN     (scrm_en_from_ctl),     // Scrambler Enable
        .CTL_MST_IN         (mst_en_from_ctl),      // MST enable

        // Message
        .MSG_SNK_IF         (lnk_msg_if[2]),        // Sink
        .MSG_SRC_IF         (lnk_msg_if[3]),        // Source

        // Video
        .LNK_VS_IN          (vs_from_vid[0]),       // Vsync
        .LNK_VBF_IN         (vbf_from_vid[0]),      // Vertical blanking flag

        // Link
        .LNK_SNK_IF         (lnk_from_vid[0]),      // Sink    
        .LNK_SRC_IF         (lnk_from_msa[0])       // Source
    );

// MSA stream 1
generate
    if (P_MST)
    begin : gen_msa1
        prt_dptx_msa
        #(
            // System
            .P_VENDOR           (P_VENDOR),
            .P_SIM              (P_SIM),                // Simulation
            .P_STREAM           (1),                    // Stream
            
            // Link
            .P_LANES            (P_LANES),              // Lanes
            .P_SPL              (P_SPL),                // Symbols per lane

            // Video 
            .P_PPC              (P_PPC),                // Pixels per clock

            // Message
            .P_MSG_IDX          (P_MSG_IDX),            // Index width
            .P_MSG_DAT          (P_MSG_DAT),            // Data width
            .P_MSG_ID           (P_MSG_ID_MSA1)         // Message ID MSA (main stream attribute)
        )
        MSA1_INST
        (
            // Reset and clocks
            .LNK_RST_IN         (LNK_RST_IN),           // Link reset
            .LNK_CLK_IN         (LNK_CLK_IN),           // Link clock
            .VID_CLK_IN         (VID1_CLK_IN),          // Video clock
            .VID_CKE_IN         (VID1_CKE_IN),          // Clock enable

            // Control
            .CTL_LANES_IN       (lanes_from_ctl),       // Active lanes (0 - 2 lanes / 1 - 4 lanes)
            .CTL_VID_EN_IN      (vid_en_from_ctl[1]),   // Video Enable
            .CTL_SCRM_EN_IN     (scrm_en_from_ctl),     // Scrambler Enable
            .CTL_MST_IN         (mst_en_from_ctl),      // MST enable

            // Message
            .MSG_SNK_IF         (lnk_msg_if[3]),        // Sink
            .MSG_SRC_IF         (lnk_msg_if[4]),        // Source

            // Video
            .LNK_VS_IN          (vs_from_vid[1]),       // Vsync
            .LNK_VBF_IN         (vbf_from_vid[1]),      // Vertical blanking flag

            // Link
            .LNK_SNK_IF         (lnk_from_vid[1]),      // Sink    
            .LNK_SRC_IF         (lnk_from_msa[1])       // Source
        );
    end
endgenerate

// MST
generate
    if (P_MST)
    begin : gen_mst
        prt_dptx_mst
        #(
            // System
            .P_VENDOR           (P_VENDOR),
            
            // Link
            .P_LANES            (P_LANES),              // Lanes
            .P_SPL              (P_SPL)                 // Symbols per lane
        )
        MST_INST
        (
            // Reset and clock
            .RST_IN             (LNK_RST_IN),
            .CLK_IN             (LNK_CLK_IN),

            // Control
            .CTL_MST_EN_IN      (mst_en_from_ctl),      // MST enable
            .CTL_MST_ACT_IN     (mst_act_from_ctl),     // MST ACT
            .CTL_VC0_TS_IN      (vc_ts_from_ctl[0]),    // VC0 time slots
            .CTL_VC1_TS_IN      (vc_ts_from_ctl[1]),    // VC1 time slots

            // Sink stream 0
            .LNK0_SNK_IF        (lnk_from_msa[0]),      // Sink0

            // Sink stream 1
            .LNK1_SNK_IF        (lnk_from_msa[1]),      // Sink1

            // Source 
            .LNK_SRC_IF         (lnk_from_mst)          // Source
        );
    end

    else
    begin
        assign lnk_from_msa[0].rd = 1'b1;
    end
endgenerate

// Scrambler
generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_scrm

        assign lnk_to_scrm_lane[i].sym[0]   = (P_MST) ? lnk_from_mst.sym[i] : lnk_from_msa[0].sym[i];
        assign lnk_to_scrm_lane[i].dat[0]   = (P_MST) ? lnk_from_mst.dat[i] : lnk_from_msa[0].dat[i];
        assign lnk_to_scrm_lane[i].vld      = (P_MST) ? lnk_from_mst.vld : lnk_from_msa[0].vld;

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
            .CTL_MST_IN     (mst_en_from_ctl),          // MST enable
            .CTL_TPS4_IN    (tps4_from_ctl),            // TPS4

            // Link
            .LNK_SNK_IF     (lnk_to_scrm_lane[i]),      // Sink
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
        // System
        .P_VENDOR           (P_VENDOR),

        // Link
        .P_LANES            (P_LANES),              // Lanes
        .P_SPL              (P_SPL),                // Symbols per lane

        // Message
        .P_MSG_IDX          (P_MSG_IDX),            // Index width
        .P_MSG_DAT          (P_MSG_DAT),            // Data width
        .P_MSG_ID           (P_MSG_ID_TPS)          // Message ID Training Pattern Sequence
    )
    TRN_INST
    (
        // Reset and clock
        .RST_IN             (LNK_RST_IN),           // Reset
        .CLK_IN             (LNK_CLK_IN),           // Clock

        // Control
        .CTL_LANES_IN       (lanes_from_ctl),       // Active lanes (1 - 1 lane / 2 - 2 lanes / 3 - 4 lanes)
        .CTL_SEL_IN         (trn_sel_from_ctl),     // Select 0 - main link / 1 - training 

        // Message
        .MSG_SNK_IF         (lnk_msg_if[1]),        // Sink
        .MSG_SRC_IF         (lnk_msg_if[2]),        // Source

        // Link
        .LNK_SNK_IF         (lnk_from_scrm),        // Sink
        .LNK_SRC_IF         (lnk_from_trn)          // Source
    );

// Skew
generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_skew

        assign lnk_to_skew_lane[i].disp_ctl[0]  = lnk_from_trn.disp_ctl[i];
        assign lnk_to_skew_lane[i].disp_val[0]  = lnk_from_trn.disp_val[i];
        assign lnk_to_skew_lane[i].k[0]         = lnk_from_trn.k[i];
        assign lnk_to_skew_lane[i].dat[0]       = lnk_from_trn.dat[i];
        
        prt_dptx_skew
        #(
            // Link
            .P_LANE         (i),                      // Lane
            .P_SPL          (P_SPL)                   // Symbols per lane
        )
        SKEW_INST
        (
            .CLK_IN         (LNK_CLK_IN),             // Clock

            // Link
            .LNK_SNK_IF     (lnk_to_skew_lane[i]),    // Sink
            .LNK_SRC_IF     (lnk_from_skew_lane[i])   // Source
        );

        assign lnk_from_skew.disp_ctl[i]   = lnk_from_skew_lane[i].disp_ctl[0];
        assign lnk_from_skew.disp_val[i]   = lnk_from_skew_lane[i].disp_val[0];
        assign lnk_from_skew.k[i]          = lnk_from_skew_lane[i].k[0];
        assign lnk_from_skew.dat[i]        = lnk_from_skew_lane[i].dat[0];

    end
endgenerate

// Output
generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_lnk_src
        assign LNK_SRC_IF.disp_ctl[i]   = lnk_from_skew.disp_ctl[i];
        assign LNK_SRC_IF.disp_val[i]   = lnk_from_skew.disp_val[i];
        assign LNK_SRC_IF.k[i]          = lnk_from_skew.k[i];
        assign LNK_SRC_IF.dat[i]        = lnk_from_skew.dat[i];
    end
endgenerate

endmodule

`default_nettype wire
