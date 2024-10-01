/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP RX Training
    (c) 2021 - 2024 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Added training TPS4

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

//`default_nettype none

module prt_dprx_trn
#(
    // PHY
    parameter P_LANES       = 2,           // Lanes
    parameter P_SPL         = 2,           // Symbols per lane

    // Message
    parameter P_MSG_IDX     = 5,          // Message index width
    parameter P_MSG_DAT     = 16,         // Message data width
    parameter P_MSG_ID_TRN  = 0           // Message ID Training
)
(
    // Reset and clock
    input wire              RST_IN,
    input wire              CLK_IN,

    // Message
    prt_dp_msg_if.snk       MSG_SNK_IF,         // Sink
    prt_dp_msg_if.src       MSG_SRC_IF,         // Source

    // Scrambler
    // This is used during TPS4
    prt_dp_rx_lnk_if.snk    SCRM_SNK_IF,        // Sink
    
    // Link
    prt_dp_rx_lnk_if.snk    LNK_SNK_IF,         // Sink
    prt_dp_rx_lnk_if.src    LNK_SRC_IF          // Source
);

// Parameters

// Interface
prt_dp_msg_if
#(
    .P_DAT_WIDTH (P_MSG_DAT)
) msg_from_egr();

// Structures
typedef struct {
    logic	[P_MSG_IDX-1:0]	      idx;
    logic                         first;
    logic                         last;
	logic	[P_MSG_DAT-1:0]	      dat;
	logic				          vld;
} msg_egr_struct;

typedef struct {
    logic	[P_MSG_IDX-1:0]	      idx;
    logic                         first;
    logic                         last;
	logic	[P_MSG_DAT-1:0]	      dat;
	logic				          ack;
} msg_ing_struct;

// Signals
msg_egr_struct      clk_msg_egr;
msg_ing_struct      clk_msg_ing;
wire [P_LANES-1:0]  cfg_set_to_lane;
wire [2:0]          cfg_tps_to_lane[0:P_LANES-1];
wire [15:0]         sta_match_from_lane[0:P_LANES-1];
wire [7:0]          sta_err_from_lane[0:P_LANES-1];
logic [2:0]         clk_act_lanes;             // Active lanes

// Scrambler
prt_dp_rx_lnk_if
#(
  .P_LANES  (1),
  .P_SPL    (P_SPL)
)
scrm_if_to_lane[0:P_LANES-1]();

// Link interface
prt_dp_rx_lnk_if
#(
  .P_LANES  (1),
  .P_SPL    (P_SPL)
)
lnk_if_to_lane[0:P_LANES-1]();

prt_dp_rx_lnk_if
#(
  .P_LANES  (1),
  .P_SPL    (P_SPL)
)
lnk_if_from_lane[0:P_LANES-1]();

genvar i, j;

// Logic

// Message Slave Egress
    prt_dp_msg_slv_egr
    #(
        .P_ID           (P_MSG_ID_TRN),   // Identifier
        .P_IDX_WIDTH    (P_MSG_IDX),      // Index width
        .P_DAT_WIDTH    (P_MSG_DAT)       // Data width
    )
    MSG_SLV_EGR_INST
    (
        // Reset and clock
        .RST_IN         (RST_IN),
        .CLK_IN         (CLK_IN),

        // Message
        .MSG_SNK_IF     (MSG_SNK_IF),
        .MSG_SRC_IF     (msg_from_egr),

        // Eggress
        .EGR_IDX_OUT    (clk_msg_egr.idx),    // Index
        .EGR_FIRST_OUT  (clk_msg_egr.first),  // First
        .EGR_LAST_OUT   (clk_msg_egr.last),   // Last
        .EGR_DAT_OUT    (clk_msg_egr.dat),    // Data
        .EGR_VLD_OUT    (clk_msg_egr.vld)     // Valid
    );

// Message Slave Ingress
	prt_dp_msg_slv_ing
	#(
        .P_ID           (P_MSG_ID_TRN),   	// Identifier
        .P_IDX_WIDTH    (P_MSG_IDX),        // Index width
        .P_DAT_WIDTH    (P_MSG_DAT)         // Data width
	)
	MSG_SLV_ING_INST
	(
	    // Reset and clock
        .RST_IN         (RST_IN),
        .CLK_IN         (CLK_IN),

	    // Message 
	    .MSG_SNK_IF		(msg_from_egr),
	    .MSG_SRC_IF		(MSG_SRC_IF),

	    // Ingress
	    .ING_IDX_OUT	(clk_msg_ing.idx),       // Index
	    .ING_FIRST_OUT	(clk_msg_ing.first),     // First
	    .ING_LAST_OUT	(clk_msg_ing.last),      // Last
	    .ING_DAT_IN		(clk_msg_ing.dat),        // Data
	    .ING_ACK_OUT	(clk_msg_ing.ack)
	);

// Ingress data in
    always_comb
    begin
        // Default
        clk_msg_ing.dat = 0;

        case (clk_msg_ing.idx)
            // Match lane 0
            'd0 :
            begin
                clk_msg_ing.dat = sta_match_from_lane[0];
            end

            // Match lane 1
            'd1 :
            begin
                if ((P_LANES == 2) || (P_LANES == 4))
                    clk_msg_ing.dat = sta_match_from_lane[1];
            end

            // Match lane 2
            'd2 :
            begin
                if (P_LANES == 4)
                    clk_msg_ing.dat = sta_match_from_lane[2];
            end

            // Match lane 3
            'd3 :
            begin
                if (P_LANES == 4)
                    clk_msg_ing.dat = sta_match_from_lane[3];
            end

            // Error lane 0
            'd4 :
            begin
                clk_msg_ing.dat[0+:$size(sta_err_from_lane[0])] = sta_err_from_lane[0];
            end

            // Error lane 1
            'd5 :
            begin
                if ((P_LANES == 2) || (P_LANES == 4))
                    clk_msg_ing.dat[0+:$size(sta_err_from_lane[1])] = sta_err_from_lane[1];
            end

            // Error lane 2
            'd6 :
            begin
                if (P_LANES == 4)
                    clk_msg_ing.dat[0+:$size(sta_err_from_lane[2])] = sta_err_from_lane[2];
            end

            // Error lane 3
            'd7 :
            begin
                if (P_LANES == 4)
                    clk_msg_ing.dat[0+:$size(sta_err_from_lane[3])] = sta_err_from_lane[3];
            end

            default : ;
        endcase
    end

// Lanes
generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_lanes
        prt_dprx_trn_lane
        #(
            // PHY
            .P_SPL          (P_SPL)            // Symbols per lane
        )
        LANE_INST
        (
            // Reset and clock
            .RST_IN             (RST_IN),
            .CLK_IN             (CLK_IN),

            // Config
            .CFG_SET_IN         (cfg_set_to_lane[i]),
            .CFG_TPS_IN         (cfg_tps_to_lane[i]),

            // Status
            .STA_MATCH_OUT      (sta_match_from_lane[i]),   // Match
            .STA_ERR_OUT        (sta_err_from_lane[i]),     // Error

            // Scrambler
            .SCRM_SNK_IF        (scrm_if_to_lane[i]),       // Sink

            // Link
            .LNK_SNK_IF         (lnk_if_to_lane[i]),        // Sink
            .LNK_SRC_IF         (lnk_if_from_lane[i])       // Source
        );

        // Map scrambler interface to individual lanes
        assign scrm_if_to_lane[i].k[0]   = SCRM_SNK_IF.k[i];
        assign scrm_if_to_lane[i].dat[0] = SCRM_SNK_IF.dat[i];

        // Map link interface to individual lanes
        assign lnk_if_to_lane[i].lock   = LNK_SNK_IF.lock;
        assign lnk_if_to_lane[i].k[0]   = LNK_SNK_IF.k[i];
        assign lnk_if_to_lane[i].dat[0] = LNK_SNK_IF.dat[i];
        assign cfg_tps_to_lane[i]       = clk_msg_egr.dat[(i*4)+:$size(cfg_tps_to_lane[i])];
    end
endgenerate

// Config set
    assign cfg_set_to_lane[0] = (clk_msg_egr.idx == 'd1) && clk_msg_egr.vld;

generate
    if ((P_LANES == 2) || (P_LANES == 4))
    begin : gen_cfg_set_lane1
        assign cfg_set_to_lane[1] = ((clk_act_lanes == 'd2) || (clk_act_lanes == 'd4)) ? (clk_msg_egr.idx == 'd1) && clk_msg_egr.vld : 0;
    end
endgenerate

generate
    if (P_LANES == 4)
    begin : gen_cfg_set_lane23
        assign cfg_set_to_lane[2] = (clk_act_lanes == 'd4) ? (clk_msg_egr.idx == 'd1) && clk_msg_egr.vld : 0;
        assign cfg_set_to_lane[3] = (clk_act_lanes == 'd4) ? (clk_msg_egr.idx == 'd1) && clk_msg_egr.vld : 0;
    end
endgenerate

// Active lanes
    always_ff @ (posedge RST_IN, posedge CLK_IN)
    begin
        if (RST_IN)
            clk_act_lanes <= 0;

        else
        begin
            // Load
            if ((clk_msg_egr.idx == 'd0) && clk_msg_egr.vld)
                clk_act_lanes <= clk_msg_egr.dat[0+:$size(clk_act_lanes)];
        end
    end

// Outputs
    assign LNK_SRC_IF.lock = 0; // Not used

    generate
        for (i = 0; i < P_LANES; i++)
        begin : gen_lnk_src
            for (j = 0; j < P_SPL; j++)
            begin
                assign LNK_SRC_IF.vid[i][j] = 0; // Not used
                assign LNK_SRC_IF.sdp[i][j] = 0; // Not used
                assign LNK_SRC_IF.msa[i][j] = 0; // Not used
                assign LNK_SRC_IF.k[i][j] = lnk_if_from_lane[i].k[0][j];
                assign LNK_SRC_IF.dat[i][j] = lnk_if_from_lane[i].dat[0][j];
            end       
        end
    endgenerate

endmodule

`default_nettype wire
