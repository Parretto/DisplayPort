/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP RX Link
    (c) 2021 - 2025 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Initial MST support
    v1.2 - Added training TPS4
    v1.3 - Added 10-bits video support
    v1.4 - Added secondary data packet 

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

module prt_dprx_lnk
#(
    // System
    parameter               P_VENDOR      = "none",  // Vendor - "AMD", "ALTERA" or "LSC"
    parameter               P_SIM         = 0,       // Simulation
    parameter               P_MST         = 0,       // MST support
    parameter               P_SDP         = 0,       // SDP support

    // Link
    parameter               P_LANES       = 2,       // Lanes
    parameter               P_SPL         = 2,       // Symbols per lane

    // Video
    parameter               P_PPC         = 2,       // Pixels per clock
    parameter               P_BPC         = 8,       // Bits per component
    parameter               P_VID_DAT     = 48,      // AXIS data width

    // Message
    parameter               P_MSG_IDX     = 5,       // Message index width
    parameter               P_MSG_DAT     = 16,      // Message data width
    parameter               P_MSG_ID_CTL  = 'h14,    // Message ID control
    parameter               P_MSG_ID_TRN  = 'h10,    // Message ID training
    parameter               P_MSG_ID_MSA  = 'h12,    // Message ID msa
    parameter               P_MSG_ID_VID  = 'h13     // Message ID video
)
(
    // System
    input wire              SYS_RST_IN,         // System reset
    input wire              SYS_CLK_IN,         // System clock

    // Status
    output wire             STA_LNK_CLKDET_OUT, // Link clock detect
    output wire             STA_CDR_LOCK_OUT,   // CDR lock
    output wire             STA_SCRM_LOCK_OUT,  // Scrambler lock
    output wire             STA_VID_EN_OUT,     // Video enable

    // Interrupts
    output wire             MSA_IRQ_OUT,        // MSA

    // Message
    prt_dp_msg_if.snk       MSG_SNK_IF,         // Sink
    prt_dp_msg_if.src       MSG_SRC_IF,         // Source

    // Link sink
    input wire              LNK_RST_IN,         // Reset
    input wire              LNK_CLK_IN,         // Clock
    prt_dp_rx_lnk_if.snk    LNK_SNK_IF,         // Interface
    output wire             LNK_SYNC_OUT,       // Sync
    output wire [7:0]       LNK_VBID_OUT,       // VB-ID 
    
    // Video source
    input wire              VID_RST_IN,         // Reset
    input wire              VID_CLK_IN,         // Clock
    prt_dp_axis_if.src      VID_SRC_IF,         // Interface

    // Secondary data packet
    input wire              SDP_CLK_IN,         // Clock
    prt_dp_rx_sdp_if.src    SDP_SRC_IF          // Source
);

// Localparam

// Signals

// Control
wire        lnk_en_from_ctl;
wire [1:0]  lanes_from_ctl;
wire        scrm_en_from_ctl;
wire        mst_en_from_ctl;
wire [1:0]  bpc_from_ctl;

// Link Message
prt_dp_msg_if
#(
    .P_DAT_WIDTH (P_MSG_DAT)
) lnk_msg_if[6]();

// Video message
prt_dp_msg_if
#(
    .P_DAT_WIDTH (P_MSG_DAT)
) vid_msg_if[2]();

// Training
prt_dp_rx_lnk_if
#(
  .P_LANES  (P_LANES),
  .P_SPL    (P_SPL)
)
lnk_from_trn();

// Parser
prt_dp_rx_lnk_if
#(
  .P_LANES  (1),
  .P_SPL    (P_SPL)
)
lnk_to_pars_lane[0:P_LANES-1]();

prt_dp_rx_lnk_if
#(
  .P_LANES  (1),
  .P_SPL    (P_SPL)
)
lnk_from_pars_lane[0:P_LANES-1]();

// Scrambler
prt_dp_rx_lnk_if
#(
  .P_LANES  (1),
  .P_SPL    (P_SPL)
)
lnk_from_scrm_lane[0:P_LANES-1]();

prt_dp_rx_lnk_if
#(
  .P_LANES  (P_LANES),
  .P_SPL    (P_SPL)
)
lnk_from_scrm();

// MSA
prt_dp_rx_lnk_if
#(
  .P_LANES  (P_LANES),
  .P_SPL    (P_SPL)
)
lnk_from_msa();

wire irq_from_msa;

// SDP
prt_dp_rx_lnk_if
#(
  .P_LANES  (P_LANES),
  .P_SPL    (P_SPL)
)
lnk_from_sdp();

// video
wire vid_en_from_vid;

genvar i;

// Logic

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
        .A_MSG_SNK_IF       (MSG_SNK_IF),   // Sink

        // Port B
        .B_MSG_SRC_IF       (lnk_msg_if[0])
    );

// The message interface is daising chained.
// The policy maker doesn't have to read back from the video module.
// To save an extra video CDC back to the system clock domain, the link message is split into two interfaces.  
// One interface is connected to the system CDC and the other is routed to the video CDC.

    assign {lnk_msg_if[5].som, lnk_msg_if[4].som} = {2{lnk_msg_if[3].som}};
    assign {lnk_msg_if[5].eom, lnk_msg_if[4].eom} = {2{lnk_msg_if[3].eom}};
    assign {lnk_msg_if[5].dat, lnk_msg_if[4].dat} = {2{lnk_msg_if[3].dat}};
    assign {lnk_msg_if[5].vld, lnk_msg_if[4].vld} = {2{lnk_msg_if[3].vld}};

// System message Clock domain converter
    prt_dp_msg_cdc
    #(
        .P_VENDOR           (P_VENDOR),                                                                                                                                                                 
        .P_DAT_WIDTH        (P_MSG_DAT)
    )
    SYS_MSG_CDC_INST
    (
        // Reset and clock
        .A_RST_IN           (LNK_RST_IN),
        .B_RST_IN           (SYS_RST_IN),
        .A_CLK_IN           (LNK_CLK_IN),
        .B_CLK_IN           (SYS_CLK_IN),

        // Port A 
        .A_MSG_SNK_IF       (lnk_msg_if[4]),   // Sink

        // Port B
        .B_MSG_SRC_IF       (MSG_SRC_IF)
    );

// Video message Clock domain converter
// The video module needs the horizontal width to generate the EOL. 
    prt_dp_msg_cdc
    #(
        .P_VENDOR           (P_VENDOR),                                                                                                                                                                 
        .P_DAT_WIDTH        (P_MSG_DAT)
    )
    VID_MSG_CDC_INST
    (
        // Reset and clock
        .A_RST_IN           (LNK_RST_IN),
        .B_RST_IN           (VID_RST_IN),
        .A_CLK_IN           (LNK_CLK_IN),
        .B_CLK_IN           (VID_CLK_IN),

        // Port A 
        .A_MSG_SNK_IF       (lnk_msg_if[5]),   // Sink

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

// Control
    prt_dprx_ctl
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
        .CTL_LNK_EN_OUT     (lnk_en_from_ctl),      // Link enable
        .CTL_LANES_OUT      (lanes_from_ctl),       // Active lanes (1 - 1 lane / 2 - 2 lanes / 3 - 4 lanes)
        .CTL_SCRM_EN_OUT    (scrm_en_from_ctl),     // Scrambler enable
        .CTL_MST_EN_OUT     (mst_en_from_ctl),      // MST enable
        .CTL_BPC_OUT        (bpc_from_ctl)          // Active bits-per-component (0 - 8 bits / 1 - 10 bits / 2 - reserved / 3 - reserved)
    );

// Training
    prt_dprx_trn
    #(
        // Link
        .P_LANES            (P_LANES),          // Lanes
        .P_SPL              (P_SPL),            // Symbols per lane

        // Message
        .P_MSG_IDX          (P_MSG_IDX),        // Index width
        .P_MSG_DAT          (P_MSG_DAT),        // Data width
        .P_MSG_ID_TRN       (P_MSG_ID_TRN)      // Message ID Training
    )
    TRN_INST
    (
        // Reset and clock
        .RST_IN             (LNK_RST_IN),       // Reset
        .CLK_IN             (LNK_CLK_IN),       // Clock

        // Message
        .MSG_SNK_IF         (lnk_msg_if[1]),    // Sink
        .MSG_SRC_IF         (lnk_msg_if[2]),    // Source

        // Scrambler data 
        // This is used during TPS4
        .SCRM_SNK_IF        (lnk_from_scrm),    // Sink

        // Link
        .LNK_SNK_IF         (LNK_SNK_IF),       // Sink
        .LNK_SRC_IF         (lnk_from_trn)      // Source
    );

// Parser

    // Lock
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Currently in MST force lock low
        if (mst_en_from_ctl)
        begin
                lnk_to_pars_lane[0].lock <= 0;
                lnk_to_pars_lane[1].lock <= 0;
                lnk_to_pars_lane[2].lock <= 0;
                lnk_to_pars_lane[3].lock <= 0;
        end

        // SST
        else
        begin
            // 4 lanes
            if (lanes_from_ctl == 'd3)
            begin
                lnk_to_pars_lane[0].lock <= lnk_en_from_ctl;
                lnk_to_pars_lane[1].lock <= lnk_en_from_ctl;
                lnk_to_pars_lane[2].lock <= lnk_en_from_ctl;
                lnk_to_pars_lane[3].lock <= lnk_en_from_ctl;
            end

            // 2 lanes
            else if (lanes_from_ctl == 'd2)
            begin
                lnk_to_pars_lane[0].lock <= lnk_en_from_ctl;
                lnk_to_pars_lane[1].lock <= lnk_en_from_ctl;
                lnk_to_pars_lane[2].lock <= 0;
                lnk_to_pars_lane[3].lock <= 0;
            end

            // 1 lanes
            else 
            begin
                lnk_to_pars_lane[0].lock <= lnk_en_from_ctl;
                lnk_to_pars_lane[1].lock <= 0;
                lnk_to_pars_lane[2].lock <= 0;
                lnk_to_pars_lane[3].lock <= 0;
            end
        end
    end

generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_pars

        // Map interface
        assign lnk_to_pars_lane[i].k[0]     = lnk_from_trn.k[i];
        assign lnk_to_pars_lane[i].dat[0]   = lnk_from_trn.dat[i];
        assign lnk_to_pars_lane[i].sol[0]   = 0;
        assign lnk_to_pars_lane[i].eol[0]   = 0;
        assign lnk_to_pars_lane[i].vid[0]   = 0;
        assign lnk_to_pars_lane[i].msa[0]   = 0;
        assign lnk_to_pars_lane[i].sdp[0]   = 0;
        assign lnk_to_pars_lane[i].vbid[0]  = 0;

        prt_dprx_pars
        #(
            // Link
            .P_SPL              (P_SPL)                     // Symbols per lane
        )
        PARS_INST
        (
            // Reset and clock
            .RST_IN             (LNK_RST_IN),
            .CLK_IN             (LNK_CLK_IN),               // Clock

            // Control
            .CTL_EFM_IN         (1'b1),                     // Enhanced framing mode

            // Link
            .LNK_SNK_IF         (lnk_to_pars_lane[i]),      // Sink
            .LNK_SRC_IF         (lnk_from_pars_lane[i])     // Source
        );
    end
endgenerate

// Scrambler
generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_scrm
        prt_dprx_scrm
        #(  
            .P_SIM              (P_SIM),                    // Simulation

            // Link
            .P_SPL              (P_SPL)                     // Symbols per lane
        )
        SCRM_INST
        (
            .RST_IN             (LNK_RST_IN),               // Reset
            .CLK_IN             (LNK_CLK_IN),               // Clock

            // Control
            .CTL_EN_IN          (1'b1),                     // Enable
            .CTL_MST_IN         (mst_en_from_ctl),          // MST

            // Link
            .LNK_SNK_IF         (lnk_from_pars_lane[i]),    // Sink
            .LNK_SRC_IF         (lnk_from_scrm_lane[i])     // Source
        );

        // Remap individual lanes to single interface
        assign lnk_from_scrm.k[i]   = lnk_from_scrm_lane[i].k[0];
        assign lnk_from_scrm.dat[i] = lnk_from_scrm_lane[i].dat[0];

        // Insert parser signals
        assign lnk_from_scrm.sol[i]  = lnk_from_pars_lane[i].sol[0];
        assign lnk_from_scrm.eol[i]  = lnk_from_pars_lane[i].eol[0];
        assign lnk_from_scrm.vid[i]  = lnk_from_pars_lane[i].vid[0];
        assign lnk_from_scrm.msa[i]  = lnk_from_pars_lane[i].msa[0];
        assign lnk_from_scrm.sdp[i]  = lnk_from_pars_lane[i].sdp[0];
        assign lnk_from_scrm.vbid[i] = lnk_from_pars_lane[i].vbid[0];
    end

    // Lock
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // 4 lanes
        if (lanes_from_ctl == 'd3)
            lnk_from_scrm.lock <= lnk_from_scrm_lane[0].lock && lnk_from_scrm_lane[1].lock && lnk_from_scrm_lane[2].lock && lnk_from_scrm_lane[3].lock;

        // 2 lanes
        else if (lanes_from_ctl == 'd2)
            lnk_from_scrm.lock <= lnk_from_scrm_lane[0].lock && lnk_from_scrm_lane[1].lock;

        // 1 lanes
        else if (lanes_from_ctl == 'd1)
            lnk_from_scrm.lock <= lnk_from_scrm_lane[0].lock;
        
        else
            lnk_from_scrm.lock <= 0;
    end

endgenerate

// MST
generate
    if (P_MST)
    begin : gen_mst

        // Interface
        prt_dp_rx_lnk_if
        #(
            .P_LANES  (1),
            .P_SPL    (P_SPL)
        )
        lnk_to_mst_lane[0:P_LANES-1]();

        prt_dprx_mst
        #(
            // Link
            .P_SPL              (P_SPL)               // Symbols per lane
        )
        MST_INST
        (
            // Reset and clock
            .RST_IN             (LNK_RST_IN),         // Reset
            .CLK_IN             (LNK_CLK_IN),         // Clock

            // Control
            .CTL_MST_IN         (mst_en_from_ctl),      // MST

            // Link 
            .LNK_SNK_IF         (lnk_to_mst_lane[0])   // Sink
        );

        assign lnk_to_mst_lane[0].k[0]   = lnk_from_scrm_lane[0].k[0];
        assign lnk_to_mst_lane[0].dat[0] = lnk_from_scrm_lane[0].dat[0];

    end
endgenerate

// MSA
    prt_dprx_msa
    #(
        // System
        .P_VENDOR           (P_VENDOR),         // Vendor
        
        // Link
        .P_LANES            (P_LANES),          // Lanes
        .P_SPL              (P_SPL),            // Symbols per lane

        // Message
        .P_MSG_IDX          (P_MSG_IDX),        // Index width
        .P_MSG_DAT          (P_MSG_DAT),        // Data width
        .P_MSG_ID_MSA       (P_MSG_ID_MSA)      // Message ID Training
    )
    MSA_INST
    (
        // Reset and clocks
        .RST_IN             (LNK_RST_IN),        // Reset
        .CLK_IN             (LNK_CLK_IN),        // Clock

        // Control
        .CTL_LANES_IN       (lanes_from_ctl),    // Active lanes (1 - 1 lane / 2 - 2 lanes / 3 - 4 lanes)

        // Message
        .MSG_SNK_IF         (lnk_msg_if[2]),     // Sink
        .MSG_SRC_IF         (lnk_msg_if[3]),     // Source

        // Link
        .LNK_SNK_IF         (lnk_from_scrm),     // Sink    
        .LNK_SRC_IF         (lnk_from_msa),      // Source
     
        // Interrupt
        .IRQ_OUT            (irq_from_msa)
    );

// SDP
generate
    if (P_SDP)
    begin : gen_sdp
        prt_dprx_sdp
        #(
                // System
                .P_SIM              (P_SIM),            // Simulation
                .P_VENDOR           (P_VENDOR),         // Vendor
                
                // Link
                .P_LANES            (P_LANES),          // Lanes
                .P_SPL              (P_SPL)             // Symbols per lane
        )
        SDP_INST
        (
            // Control
            .CTL_LANES_IN           (lanes_from_ctl),   // Active lanes (1 - 1 lane / 2 - 2 lanes / 3 - 4 lanes)

            // Link
            .LNK_RST_IN             (LNK_RST_IN),       // Reset
            .LNK_CLK_IN             (LNK_CLK_IN),       // Clock  
            .LNK_SNK_IF             (lnk_from_msa),     // Sink
            .LNK_SRC_IF             (lnk_from_sdp),     // Source

            // Secondary data packet
            .SDP_CLK_IN             (SDP_CLK_IN),       // Clock
            .SDP_SRC_IF             (SDP_SRC_IF)        // Source
        );
    end

    else
    begin : gen_no_sdp
        assign lnk_from_sdp.lock = lnk_from_msa.lock;
        
        for (i = 0; i < P_LANES; i++)
        begin
            assign lnk_from_sdp.sol[i]      = lnk_from_msa.sol[i];
            assign lnk_from_sdp.eol[i]      = lnk_from_msa.eol[i];
            assign lnk_from_sdp.vid[i]      = lnk_from_msa.vid[i];
            assign lnk_from_sdp.sdp[i]      = 0;
            assign lnk_from_sdp.msa[i]      = lnk_from_msa.msa[i];
            assign lnk_from_sdp.vbid[i]     = lnk_from_msa.vbid[i];
            assign lnk_from_sdp.k[i]        = lnk_from_msa.k[i];
            assign lnk_from_sdp.dat[i]      = lnk_from_msa.dat[i];
        end

        assign SDP_SRC_IF.sop = 0;
        assign SDP_SRC_IF.eop = 0;
        assign SDP_SRC_IF.dat = 0;
        assign SDP_SRC_IF.vld = 0;
    end
endgenerate

// Video
    prt_dprx_vid
    #(
        // System
        .P_VENDOR           (P_VENDOR),             // Vendor
        .P_SIM              (P_SIM),                // Simulation
        
        // Link
        .P_LANES            (P_LANES),              // Lanes
        .P_SPL              (P_SPL),                // Symbols per lane

        // Video
        .P_PPC              (P_PPC),                // Pixels per clock
        .P_BPC              (P_BPC),                // Bits per component
        .P_VID_DAT          (P_VID_DAT),            // AXIS data width

        // Message
        .P_MSG_IDX          (P_MSG_IDX),            // Index width
        .P_MSG_DAT          (P_MSG_DAT),            // Data width
        .P_MSG_ID           (P_MSG_ID_VID)          // Message ID 
    )
    VID_INST
    (
        // Control
        .CTL_LANES_IN       (lanes_from_ctl),       // Active lanes (1 - 1 lane / 2 - 2 lanes / 3 - 4 lanes)
        .CTL_BPC_IN         (bpc_from_ctl),         // Active bits-per-component (0 - 8 bits / 1 - 10 bits / 2 - reserved / 3 - reserved)

        // Message
        .MSG_SNK_IF         (vid_msg_if[0]),        // Sink
        .MSG_SRC_IF         (vid_msg_if[1]),        // Source

        // Link sink
        .LNK_RST_IN         (LNK_RST_IN),           // Reset
        .LNK_CLK_IN         (LNK_CLK_IN),           // Clock
        .LNK_SNK_IF         (lnk_from_sdp),         // Interface
        .LNK_VBID_OUT       (LNK_VBID_OUT),         // VB-ID 
        
        // Video source
        .VID_RST_IN         (VID_RST_IN),           // Reset
        .VID_CLK_IN         (VID_CLK_IN),           // Clock
        .VID_EN_OUT         (vid_en_from_vid),      // Enable
        .VID_SRC_IF         (VID_SRC_IF)            // Interface
    );

// CDR lock clock domain crossing
    prt_dp_lib_cdc_bit
    CDR_LOCK_CDC_INST
    (
        .SRC_CLK_IN         (LNK_CLK_IN),           // Clock
        .SRC_DAT_IN         (LNK_SNK_IF.lock),      // Data
        .DST_CLK_IN         (SYS_CLK_IN),           // Clock
        .DST_DAT_OUT        (STA_CDR_LOCK_OUT)      // Data
    );

// Scrambler lock clock domain crossing
    prt_dp_lib_cdc_bit
    SCRM_LOCK_CDC_INST
    (
        .SRC_CLK_IN         (LNK_CLK_IN),           // Clock
        .SRC_DAT_IN         (lnk_from_scrm.lock),   // Data
        .DST_CLK_IN         (SYS_CLK_IN),           // Clock
        .DST_DAT_OUT        (STA_SCRM_LOCK_OUT)     // Data
    );

// Video enable clock domain crossing
    prt_dp_lib_cdc_bit
    VID_EN_CDC_INST
    (
        .SRC_CLK_IN         (VID_CLK_IN),           // Clock
        .SRC_DAT_IN         (vid_en_from_vid),      // Data
        .DST_CLK_IN         (SYS_CLK_IN),           // Clock
        .DST_DAT_OUT        (STA_VID_EN_OUT)        // Data
    );

// MSA IRQ clock domain crossing
    prt_dp_lib_cdc_bit
    MSA_IRQ_CDC_INST
    (
        .SRC_CLK_IN         (LNK_CLK_IN),       // Clock
        .SRC_DAT_IN         (irq_from_msa),     // Data
        .DST_CLK_IN         (SYS_CLK_IN),       // Clock
        .DST_DAT_OUT        (MSA_IRQ_OUT)       // Data
    );

// Outputs
    assign LNK_SYNC_OUT = |lnk_from_pars_lane[0].eol[0];

endmodule
    
`default_nettype wire
