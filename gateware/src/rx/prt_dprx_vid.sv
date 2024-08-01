/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP RX Video
    (c) 2021- 2024 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Added support for 1 and 2 lanes.
    v1.2 - Added 10-bits video support
    v1.3 - Added VB-ID register output

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

module prt_dprx_vid
#(
    // System
    parameter               P_VENDOR = "none",  // Vendor - "AMD", "ALTERA" or "LSC"
    parameter               P_SIM = 0,          // Simulation

    // Link
    parameter               P_LANES = 4,    	// Lanes
    parameter               P_SPL = 2,      	// Symbols per lane

    // Video
    parameter               P_PPC = 2,      	// Pixels per clock
    parameter               P_BPC = 8,      	// Bits per component
    parameter 				P_VID_DAT = 48,		// AXIS data width

    // Message
    parameter               P_MSG_IDX     = 5,  // Message index width
    parameter               P_MSG_DAT     = 16, // Message data width
    parameter               P_MSG_ID      = 0   // Message ID
)
(
    // Control
    input wire [1:0]        CTL_LANES_IN,       // Active lanes (1 - 1 lane / 2 - 2 lanes / 3 - 4 lanes)
    input wire [1:0]        CTL_BPC_IN,         // Active bits-per-component (0 - 8 bits / 1 - 10 bits / 2 - reserved / 3 - reserved)

    // Message
    prt_dp_msg_if.snk       MSG_SNK_IF,         // Sink
    prt_dp_msg_if.src       MSG_SRC_IF,         // Source

    // Link
    input wire              LNK_RST_IN,         // Reset
    input wire              LNK_CLK_IN,         // Clock 
    prt_dp_rx_lnk_if.snk    LNK_SNK_IF,         // Sink
    output wire [7:0]       LNK_VBID_OUT,       // VB-ID 

    // Video 
    input wire              VID_RST_IN,         // Reset
    input wire              VID_CLK_IN,         // Clock
    output wire             VID_EN_OUT,         // Enable
    prt_dp_axis_if.src      VID_SRC_IF          // Source
);

// Package
import prt_dp_pkg::*;

// Parameters
localparam P_FIFO_WRDS = 64;
localparam P_FIFO_ADR = $clog2(P_FIFO_WRDS);
localparam P_FIFO_DAT = 9;
localparam P_FIFO_SEGMENTS = 4;
localparam P_FIFO_STRIPES = 4;
localparam P_MAP_CH = (P_PPC == 4) ? 4 : 8; // Mapper input channels

// Structures
typedef struct {
    logic [1:0]                     lanes;      // Active lanes
    logic                           bpc;        // Active bits-per-component (0 - 8bits / 1 - 10 bits)
} lnk_ctl_struct;

typedef struct {
    logic   [P_MSG_IDX-1:0]         idx;
    logic                           first;
    logic                           last;
    logic   [P_MSG_DAT-1:0]         dat;
    logic                           vld;
} msg_struct;

typedef struct {
    logic                           lock;                   // Lock
    logic [P_SPL-1:0]               sol[0:P_LANES-1];
    logic [P_SPL-1:0]               eol[0:P_LANES-1];
    logic [P_SPL-1:0]               vid[0:P_LANES-1];
    logic [P_SPL-1:0]               vid_reg[0:P_LANES-1];
    logic [P_SPL-1:0]               vid_reg_del[0:P_LANES-1];
    logic                           str;                    // Start
    logic                           str_sticky;             // Start
    logic                           str_toggle;
    logic [P_LANES-1:0]             stp_lane;
    logic                           stp;
    logic                           stp_re;
    logic [P_SPL-1:0]               vbid[0:P_LANES-1];
    logic [P_SPL-1:0]               vbid_reg[0:P_LANES-1];
    logic [7:0]                     vbid_val;               // VB-ID value
    logic                           nvs;                    // No video stream flag
    logic                           vbf;                    // Vertical blanking flag 
    logic [P_SPL-1:0]               k[0:P_LANES-1];
    logic [7:0]                     dat[0:P_LANES-1][0:P_SPL-1];
    logic [7:0]                     dat_reg[0:P_LANES-1][0:P_SPL-1];
    logic [7:0]                     dat_reg_del[0:P_LANES-1][0:P_SPL-1];
} lnk_struct;

typedef struct {
    logic [1:0]                     lph[0:P_LANES-1];
    logic [1:0]                     fph[0:P_LANES-1];
    logic [1:0]                     sel[0:P_LANES-1];
    logic [P_LANES-1:0]             str;
    logic [P_SPL-1:0]               wr[0:P_LANES-1];
    logic [7:0]                     dat[0:P_LANES-1][0:P_SPL-1];
} aln_struct;

typedef struct {
    logic [4:0]                     cnt[0:P_LANES-1][0:P_SPL-1];
    logic [P_FIFO_STRIPES-1:0]      wr[0:P_LANES-1];
    logic [7:0]                     dat[0:P_LANES-1][P_FIFO_STRIPES];
} lnk_map_struct;

typedef struct {
    logic [3:0]                     last_pipe;
    logic                           last;
    logic                           clr;
} lnk_fifo_struct;

typedef struct {
    logic                           bpc;        // Active bits-per-component (0 - 8bits / 1 - 10 bits)
} vid_ctl_struct;

typedef struct {
    logic                           clr;
    logic	[1:0]                   dout[P_LANES][P_FIFO_SEGMENTS][P_FIFO_STRIPES];
    logic	[P_FIFO_STRIPES-1:0]	de[P_LANES][P_FIFO_SEGMENTS];
    logic   [5:0]                   lvl;
} vid_fifo_struct;

typedef struct {
    logic	[P_FIFO_STRIPES-1:0]    rd[P_LANES][P_FIFO_SEGMENTS];
    logic 	[P_VID_DAT-1:0]         dat;
    logic                           vld;
} vid_map_struct;

typedef struct {
    logic                           bpc;        // Active bits-per-component (0 - 8bits / 1 - 10 bits)
    logic [7:0]                     run_pipe;   
    logic                           run;        // Run
    logic [15:0]                    hwidth;
    logic [15:0]                    hwidth_cnt;
    logic                           str_toggle;
    logic                           str_re;
    logic                           str_fe;
    logic                           str;      // Start
    logic                           nvs;      // No video stream flag
    logic                           vbf;      // Vertical blanking flag 
    logic                           vbf_re;   // Vertical blanking flag rising edge
    logic                           vbf_sticky;
    logic                           sof;      // Start of frame
    logic                           eol;      // End of line
    logic [P_VID_DAT-1:0] 			dat;      // Data
    logic                           vld;      // Valid
} vid_struct;

// Signals
lnk_ctl_struct      lclk_ctl;
lnk_struct          lclk_lnk;
aln_struct          lclk_aln;
lnk_map_struct      lclk_map;
lnk_fifo_struct     lclk_fifo;
vid_ctl_struct      vclk_ctl;
msg_struct          vclk_msg;    
vid_fifo_struct     vclk_fifo;
vid_map_struct      vclk_map;
vid_struct          vclk_vid;

genvar i, j;

// Logic

// Config
    always_ff @ (posedge LNK_CLK_IN)
    begin
        lclk_ctl.lanes <= CTL_LANES_IN;
        
        // Bits-per-component (only lsb is registered)
        lclk_ctl.bpc <= CTL_BPC_IN[0];
    end

// Link input
    always_comb
    begin
        for (int i = 0; i < P_LANES; i++)
        begin
            lclk_lnk.vbid[i] = LNK_SNK_IF.vbid[i];
            lclk_lnk.sol[i]  = LNK_SNK_IF.sol[i];
            lclk_lnk.eol[i]  = LNK_SNK_IF.eol[i];
            lclk_lnk.vid[i]  = LNK_SNK_IF.vid[i];
            lclk_lnk.k[i]    = LNK_SNK_IF.k[i];
            lclk_lnk.dat[i]  = LNK_SNK_IF.dat[i];
        end
    end

// Registered data
// This is needed for the alignment latency 
    always_ff @ (posedge LNK_CLK_IN)
    begin
        for (int i = 0; i < P_LANES; i++)
        begin
            lclk_lnk.vbid_reg[i]    <= lclk_lnk.vbid[i];
            lclk_lnk.vid_reg[i]     <= lclk_lnk.vid[i];
            lclk_lnk.dat_reg[i]     <= lclk_lnk.dat[i];
        end
    end

// Delayed data 
// This is needed for the lane data inversion
    always_ff @ (posedge LNK_CLK_IN)
    begin
        for (int i = 0; i < P_LANES; i++)
        begin
            for (int j = 0; j < P_SPL; j++)
                lclk_lnk.dat_reg_del[i][j] <= lclk_lnk.dat_reg[i][j]; 
            lclk_lnk.vid_reg_del[i] <= lclk_lnk.vid_reg[i];
        end
    end

// Link lock
    always_ff @ (posedge LNK_RST_IN, posedge LNK_CLK_IN)
    begin
        // Reset
        if (LNK_RST_IN)
            lclk_lnk.lock <= 0;

        else
            lclk_lnk.lock <= LNK_SNK_IF.lock;
    end

// Link start
// This signal is asserted at the first occuring sol.
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Lock
        if (lclk_lnk.lock)
        begin
            // Default
            lclk_lnk.str <= 0;

            // Clear 
            if (lclk_lnk.str_sticky)
            begin
                for (int i = 0; i < P_LANES; i++)
                begin
                    if (|lclk_lnk.eol[i])
                        lclk_lnk.str_sticky <= 0;
                end
            end

            // Set
            else if (!lclk_lnk.str_sticky)                           
            begin
                for (int i = 0; i < P_LANES; i++)
                begin
                    if (|lclk_lnk.sol[i])
                    begin
                        lclk_lnk.str <= 1;
                        lclk_lnk.str_sticky <= 1;
                    end
                end
            end
        end

        else
        begin
            lclk_lnk.str <= 0;
            lclk_lnk.str_sticky <= 0;
        end
    end

// Link stop
// This signal is used to generate the fifo last input.
// The individual lanes might be lagging or leading. 
// We want to assert this signal when an end-of-line is seen on all (active) lanes.
generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_lnk_stp_lane
        always_ff @ (posedge LNK_CLK_IN)
        begin
            // Lock
            if (lclk_lnk.lock)
            begin
                // Clear 
                if (lclk_lnk.str)
                    lclk_lnk.stp_lane[i] <= 0;

                // Set
                else if (|lclk_lnk.eol[i])                           
                    lclk_lnk.stp_lane[i] <= 1;      
            end

            else
                lclk_lnk.stp_lane[i] <= 0;
        end
    end
endgenerate

// Combine into a single signal
    always_comb
    begin
        // Two active lanes
        if (lclk_ctl.lanes == 'd2)
            lclk_lnk.stp = &lclk_lnk.stp_lane[0+:2];

        // One active lanes
        else if (lclk_ctl.lanes == 'd1)
            lclk_lnk.stp = &lclk_lnk.stp_lane[0];

        // Four active lanes
        else
            lclk_lnk.stp = &lclk_lnk.stp_lane[0+:4];
    end

// Link stop edge
// This is used to generate the fifo last signal.
    prt_dp_lib_edge
    LNK_STP_EDGE_INST
    (
        .CLK_IN    (LNK_CLK_IN),            // Clock
        .CKE_IN    (1'b1),                  // Clock enable
        .A_IN      (lclk_lnk.stp),          // Input
        .RE_OUT    (lclk_lnk.stp_re),       // Rising edge
        .FE_OUT    ()                       // Falling edge
    );


// Start toggle
// The start of line is used to reset some processes in both the link and video clock domains.
// In the link clock domain this signal is only one clock.
// To detect this in the video clock domain this toggle signal is inverted every time a sol is detected.
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Lock
        if (lclk_lnk.lock)
        begin
            // Only first lane is used
            if (lclk_lnk.str)
                lclk_lnk.str_toggle <= ~lclk_lnk.str_toggle;
        end

        else
            lclk_lnk.str_toggle <= 0;
    end

// VB-ID value
// This will capture the VB-ID 
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Lock
        if (lclk_lnk.lock)
        begin
            // Four symbols per lane
            if (P_SPL == 4)
            begin
                // Sublane 0
                if (lclk_lnk.vbid_reg[0][0])
                    lclk_lnk.vbid_val <= lclk_lnk.dat_reg[0][0];

                // Sublane 1
                else if (lclk_lnk.vbid_reg[0][1])
                    lclk_lnk.vbid_val <= lclk_lnk.dat_reg[0][1];

                // Sublane 2
                else if (lclk_lnk.vbid_reg[0][2])
                    lclk_lnk.vbid_val <= lclk_lnk.dat_reg[0][2];

                // Sublane 3
                else if (lclk_lnk.vbid_reg[0][3])
                    lclk_lnk.vbid_val <= lclk_lnk.dat_reg[0][3];
            end

            // Two symbols per lane
            else
            begin
                // Sublane 0
                if (lclk_lnk.vbid_reg[0][0])
                    lclk_lnk.vbid_val <= lclk_lnk.dat_reg[0][0];

                // Sublane 1
                else if (lclk_lnk.vbid_reg[0][1])
                    lclk_lnk.vbid_val <= lclk_lnk.dat_reg[0][1];
            end    
        end

        // No lock
        else
            lclk_lnk.vbid_val <= 0;
    end

    assign lclk_lnk.vbf = lclk_lnk.vbid_val[0];
    assign lclk_lnk.nvs = lclk_lnk.vbid_val[3];

/*
    Alignment
    The alignment will steer the data input, 
    so that even data will be written into the first and third FIFO stripe
    and the odd data goes into the second and fourth FIFO stripe. 
*/

// Start of data packet
// This signal is asserted at the start of a new data packet
generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_aln_vid
        prt_dp_lib_edge
        LNK_ALN_STR_EDGE_INST
        (
            .CLK_IN    (LNK_CLK_IN),            // Clock
            .CKE_IN    (1'b1),                  // Clock enable
            .A_IN      (|lclk_lnk.vid[i]),      // Input
            .RE_OUT    (lclk_aln.str[i]),       // Rising edge
            .FE_OUT    ()                       // Falling edge
        );
    end
endgenerate

// First phase
// This process indicates the first phase of the incoming data
// Must be combinatorial
generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_fph_4spl

        // This table shows the phase definition. 
        // Sublane  PH0 PH1 PH2 PH3
        //  3        1   1   1   1
        //  2        1   1   1   0
        //  1        1   1   0   0 
        //  0        1   0   0   0
        //
        // There is a possibility that a data packet only consists of a single byte.
        // Therefore only the individual link video bits must be checked. 
    
        always_comb
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                // Phase 0
                // Highest priority 
                if (lclk_lnk.vid[i][0] == 1)
                    lclk_aln.fph[i] = 'd0;

                // Phase 1
                else if (lclk_lnk.vid[i][1] == 1)
                    lclk_aln.fph[i] = 'd1;

                // Phase 2
                else if (lclk_lnk.vid[i][2] == 1)
                    lclk_aln.fph[i] = 'd2;

                // Phase 3
                // Lowest priority
                else
                    lclk_aln.fph[i] = 'd3;
            end
        end        
    end

    // Two symbols per lane
    else
    begin : gen_fph_2spl
        always_comb
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                // Phase 0
                // Highest priority
                if (lclk_lnk.vid[i][0] == 1)
                    lclk_aln.fph[i] = 'd0;

                // Phase 1
                else
                    lclk_aln.fph[i] = 'd1;
            end
        end        
    end
endgenerate

// Last phase
// This register captures the phase of the last data
// The easiest way is to look at the last alignment write.
/// However using this approach when idle time between the video packets is small, 
// the last phase is updated after the first phase has been set. 
// This results in an incorrect alignment select. 
// To solve this issue, the last phase is derived from the last phase of the (unaligned) incoming data 
// and the current alignment select. 

generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_lph_4spl

        // This table shows the phase definition. 
        // Sublane  PH0 PH1 PH2 PH3
        //  3        1   0   0   0
        //  2        1   0   0   1
        //  1        1   0   1   1 
        //  0        1   1   1   1
        //
        // There is a possibility that a data packet only consists of a single byte.
        // Therefore only the individual link video bits must be checked. 

        always_ff @ (posedge LNK_CLK_IN)
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                // Clear at start of line
                if (|lclk_lnk.sol[i])
                    lclk_aln.lph[i] <= 0;

                else 
                begin
                    // Alignment select 1
                    if (lclk_aln.sel[i] == 'd1)
                    begin 
                        // Phase 0
                        // Highest priority
                        if (lclk_lnk.vid[i][3] == 1)
                            lclk_aln.lph[i] <= 'd3;

                        // Phase 3
                        else if (lclk_lnk.vid[i][2] == 1)
                            lclk_aln.lph[i] <= 'd2;

                        // Phase 2
                        else if (lclk_lnk.vid[i][1] == 1)
                            lclk_aln.lph[i] <= 'd1;
                        
                        // Phase 1
                        else if (lclk_lnk.vid[i][0] == 1)
                            lclk_aln.lph[i] <= 'd0;
                    end

                    // Alignment select 2
                    else if (lclk_aln.sel[i] == 'd2)
                    begin 
                        // Phase 0
                        if (lclk_lnk.vid[i][3] == 1)
                            lclk_aln.lph[i] <= 'd2;

                        // Phase 3
                        else if (lclk_lnk.vid[i][2] == 1)
                            lclk_aln.lph[i] <= 'd1;

                        // Phase 2
                        else if (lclk_lnk.vid[i][1] == 1)
                            lclk_aln.lph[i] <= 'd0;
                        
                        // Phase 1
                        else if (lclk_lnk.vid[i][0] == 1)
                            lclk_aln.lph[i] <= 'd3;
                    end

                    // Alignment select 3
                    else if (lclk_aln.sel[i] == 'd3)
                    begin 
                        // Phase 0
                        if (lclk_lnk.vid[i][3] == 1)
                            lclk_aln.lph[i] <= 'd1;

                        // Phase 3
                        else if (lclk_lnk.vid[i][2] == 1)
                            lclk_aln.lph[i] <= 'd0;

                        // Phase 2
                        else if (lclk_lnk.vid[i][1] == 1)
                            lclk_aln.lph[i] <= 'd3;
                        
                        // Phase 1
                        else if (lclk_lnk.vid[i][0] == 1)
                            lclk_aln.lph[i] <= 'd2;
                    end

                    // Alignment select 0
                    else
                    begin 
                        // Phase 0
                        if (lclk_lnk.vid[i][3] == 1)
                            lclk_aln.lph[i] <= 'd0;

                        // Phase 3
                        else if (lclk_lnk.vid[i][2] == 1)
                            lclk_aln.lph[i] <= 'd3;

                        // Phase 2
                        else if (lclk_lnk.vid[i][1] == 1)
                            lclk_aln.lph[i] <= 'd2;
                        
                        // Phase 1
                        else if (lclk_lnk.vid[i][0] == 1)
                            lclk_aln.lph[i] <= 'd1;
                    end
                end
            end
        end
    end

    // Two symbols per lane
    else
    begin : gen_lph_2spl
        always_ff @ (posedge LNK_CLK_IN)
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                // Clear at start of line
                if (|lclk_lnk.sol[i])
                    lclk_aln.lph[i] <= 0;

                else
                begin
                    // Alignment select 1
                    if (lclk_aln.sel[i] == 'd1)
                    begin 
                        // Phase 0
                        if (lclk_lnk.vid[i][1] == 1)
                            lclk_aln.lph[i] <= 'd1;
                    
                        // Phase 1
                        else if (lclk_lnk.vid[i][0] == 1)
                            lclk_aln.lph[i] <= 'd0;
                    end

                    // Alignment select 0
                    else
                    begin 
                        // Phase 0
                        if (lclk_lnk.vid[i][1] == 1)
                            lclk_aln.lph[i] <= 'd0;
                    
                        // Phase 1
                        else if (lclk_lnk.vid[i][0] == 1)
                            lclk_aln.lph[i] <= 'd1;
                    end
                end                                         
            end
        end
    end
endgenerate

// Select
// This process drives the data mux.
generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_aln_sel_4spl
        always_ff @ (posedge LNK_CLK_IN)
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                // Clear at start of line
                if (|lclk_lnk.sol[i])
                    lclk_aln.sel[i] <= 0;

                else
                begin
                    // Set at start of video data
                    if (lclk_aln.str[i])    
                    begin
                        case ({lclk_aln.lph[i], lclk_aln.fph[i]})
                            {2'd0, 2'd0} : lclk_aln.sel[i] <= 'd0;    
                            {2'd0, 2'd1} : lclk_aln.sel[i] <= 'd1;    
                            {2'd0, 2'd2} : lclk_aln.sel[i] <= 'd2;    
                            {2'd0, 2'd3} : lclk_aln.sel[i] <= 'd3;    

                            {2'd1, 2'd0} : lclk_aln.sel[i] <= 'd3;    
                            {2'd1, 2'd1} : lclk_aln.sel[i] <= 'd0;    
                            {2'd1, 2'd2} : lclk_aln.sel[i] <= 'd1;    
                            {2'd1, 2'd3} : lclk_aln.sel[i] <= 'd2;    

                            {2'd2, 2'd0} : lclk_aln.sel[i] <= 'd2;    
                            {2'd2, 2'd1} : lclk_aln.sel[i] <= 'd3;    
                            {2'd2, 2'd2} : lclk_aln.sel[i] <= 'd0;    
                            {2'd2, 2'd3} : lclk_aln.sel[i] <= 'd1;    

                            {2'd3, 2'd0} : lclk_aln.sel[i] <= 'd1;    
                            {2'd3, 2'd1} : lclk_aln.sel[i] <= 'd2;    
                            {2'd3, 2'd2} : lclk_aln.sel[i] <= 'd3;    
                            {2'd3, 2'd3} : lclk_aln.sel[i] <= 'd0;    
                                                    
                            default      : lclk_aln.sel[i] <= 'd0;
                        endcase
                    end
                end
            end
        end
    end

    // Two symbols per lane
    else
    begin : gen_aln_sel_2spl
        always_ff @ (posedge LNK_CLK_IN)
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                // Clear at start of line
                if (|lclk_lnk.sol[i])
                    lclk_aln.sel[i] <= 0;

                else
                begin
                    // Set at start of video data
                    if (lclk_aln.str[i])    
                    begin
                        case ({lclk_aln.lph[i], lclk_aln.fph[i]})
                            {2'd0, 2'd0} : lclk_aln.sel[i] <= 'd0;    
                            {2'd0, 2'd1} : lclk_aln.sel[i] <= 'd1;    
                        
                            {2'd1, 2'd0} : lclk_aln.sel[i] <= 'd1;    
                            {2'd1, 2'd1} : lclk_aln.sel[i] <= 'd0;    
                        
                            default      : lclk_aln.sel[i] <= 'd0;
                        endcase
                    end
                end
            end
        end
    end
endgenerate

// Data
generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_aln_dat_4spl
        always_ff @ (posedge LNK_CLK_IN)
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                // Phase 1
                if (lclk_aln.sel[i] == 'd1)
                begin
                    lclk_aln.dat[i][0] <= lclk_lnk.dat_reg_del[i][1];
                    lclk_aln.dat[i][1] <= lclk_lnk.dat_reg_del[i][2];
                    lclk_aln.dat[i][2] <= lclk_lnk.dat_reg_del[i][3];
                    lclk_aln.dat[i][3] <= lclk_lnk.dat_reg[i][0];

                    lclk_aln.wr[i][0] <= lclk_lnk.vid_reg_del[i][1];
                    lclk_aln.wr[i][1] <= lclk_lnk.vid_reg_del[i][2];
                    lclk_aln.wr[i][2] <= lclk_lnk.vid_reg_del[i][3];
                    lclk_aln.wr[i][3] <= lclk_lnk.vid_reg[i][0];
                end

                // Phase 2
                else if (lclk_aln.sel[i] == 'd2)
                begin
                    lclk_aln.dat[i][0] <= lclk_lnk.dat_reg_del[i][2];
                    lclk_aln.dat[i][1] <= lclk_lnk.dat_reg_del[i][3];
                    lclk_aln.dat[i][2] <= lclk_lnk.dat_reg[i][0];
                    lclk_aln.dat[i][3] <= lclk_lnk.dat_reg[i][1];

                    lclk_aln.wr[i][0] <= lclk_lnk.vid_reg_del[i][2];
                    lclk_aln.wr[i][1] <= lclk_lnk.vid_reg_del[i][3];
                    lclk_aln.wr[i][2] <= lclk_lnk.vid_reg[i][0];
                    lclk_aln.wr[i][3] <= lclk_lnk.vid_reg[i][1];
                end

                // Phase 3
                else if (lclk_aln.sel[i] == 'd3)
                begin
                    lclk_aln.dat[i][0] <= lclk_lnk.dat_reg_del[i][3];
                    lclk_aln.dat[i][1] <= lclk_lnk.dat_reg[i][0];
                    lclk_aln.dat[i][2] <= lclk_lnk.dat_reg[i][1];
                    lclk_aln.dat[i][3] <= lclk_lnk.dat_reg[i][2];

                    lclk_aln.wr[i][0] <= lclk_lnk.vid_reg_del[i][3];
                    lclk_aln.wr[i][1] <= lclk_lnk.vid_reg[i][0];
                    lclk_aln.wr[i][2] <= lclk_lnk.vid_reg[i][1];
                    lclk_aln.wr[i][3] <= lclk_lnk.vid_reg[i][2];
                end

                // Normal
                else
                begin
                    lclk_aln.dat[i][0] <= lclk_lnk.dat_reg[i][0];
                    lclk_aln.dat[i][1] <= lclk_lnk.dat_reg[i][1];
                    lclk_aln.dat[i][2] <= lclk_lnk.dat_reg[i][2];
                    lclk_aln.dat[i][3] <= lclk_lnk.dat_reg[i][3];
                    
                    lclk_aln.wr[i][0] <= lclk_lnk.vid_reg[i][0];
                    lclk_aln.wr[i][1] <= lclk_lnk.vid_reg[i][1];
                    lclk_aln.wr[i][2] <= lclk_lnk.vid_reg[i][2];
                    lclk_aln.wr[i][3] <= lclk_lnk.vid_reg[i][3];
                end
            end
        end
    end

    // Two symbols per lane
    else
    begin : gen_aln_dat_2spl
        always_ff @ (posedge LNK_CLK_IN)
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                // Inverted
                if (lclk_aln.sel[i] == 'd1)
                begin
                    lclk_aln.dat[i][0] <= lclk_lnk.dat_reg_del[i][1];
                    lclk_aln.dat[i][1] <= lclk_lnk.dat_reg[i][0];
                    lclk_aln.wr[i][0]  <= lclk_lnk.vid_reg_del[i][1];
                    lclk_aln.wr[i][1]  <= lclk_lnk.vid_reg[i][0];
                end

                // Normal
                else
                begin
                    lclk_aln.dat[i][0] <= lclk_lnk.dat_reg[i][0];
                    lclk_aln.dat[i][1] <= lclk_lnk.dat_reg[i][1];
                    lclk_aln.wr[i][0]  <= lclk_lnk.vid_reg[i][0];
                    lclk_aln.wr[i][1]  <= lclk_lnk.vid_reg[i][1];
                end
            end
        end
    end
endgenerate

/*
    Mapper

    The FIFO's are arranged for 4 lanes.
    In case of 1 or 2 active lanes, the mapper will re-map the incoming data as it is a 4 lanes link.
*/

// Counters 
// The counters are used to map the link data into the stripe.
generate
    if (P_SPL == 4)
    begin : gen_map_cnt_4spl

        always_ff @ (posedge LNK_CLK_IN)
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                for (int j = 0; j < P_SPL; j++)
                begin
                    // Clear 
                    if (lclk_lnk.str)
                        lclk_map.cnt[i][j] <= 0;

                    // Increment
                    else if (lclk_aln.wr[i][j])
                    begin
                        // Overflow
                        if ( ((lclk_ctl.lanes == 'd1) && (lclk_map.cnt[i][j] == 'd11)) || ((lclk_ctl.lanes == 'd2) && (lclk_map.cnt[i][j] == 'd5)) ) 
                            lclk_map.cnt[i][j] <= 0;

                        else
                            lclk_map.cnt[i][j] <= lclk_map.cnt[i][j] + 'd1;
                    end
                end
            end
        end

    end

    else
    begin : gen_map_cnt_2spl

        always_ff @ (posedge LNK_CLK_IN)
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                for (int j = 0; j < P_SPL; j++)
                begin
                    // Clear 
                    if (lclk_lnk.str)
                        lclk_map.cnt[i][j] <= 0;

                    // Increment
                    else if (lclk_aln.wr[i][j])
                    begin
                        // Overflow
                        if ( ((lclk_ctl.lanes == 'd1) && (lclk_map.cnt[i][j] == 'd23)) || ((lclk_ctl.lanes == 'd2) && (lclk_map.cnt[i][j] == 'd11)) || ((lclk_ctl.lanes == 'd3) && (lclk_map.cnt[i][j] == 'd1)) ) 
                            lclk_map.cnt[i][j] <= 0;

                        else
                            lclk_map.cnt[i][j] <= lclk_map.cnt[i][j] + 'd1;
                    end
                end
            end
        end

    end
endgenerate

generate
    if (P_SPL == 4)
    begin : gen_map_4spl
        
        always_ff @ (posedge LNK_CLK_IN)
        begin
            // 1 lane
            if (lclk_ctl.lanes == 'd1)
            begin

            // Stripe 0

                // R0
                if ((lclk_map.cnt[0][0] == 'd0) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[0][0] <= lclk_aln.dat[0][0];
                    lclk_map.wr[0][0] <= 1;
                end

                // G4
                else if ((lclk_map.cnt[0][1] == 'd3) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[0][0] <= lclk_aln.dat[0][1];
                    lclk_map.wr[0][0] <= 1;
                end

                // B8
                else if ((lclk_map.cnt[0][2] == 'd6) && lclk_aln.wr[0][2])
                begin
                    lclk_map.dat[0][0] <= lclk_aln.dat[0][2];
                    lclk_map.wr[0][0] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[0][0] <= 0;
                    lclk_map.wr[0][0] <= 0;
                end

            // Stripe 1

                // G0
                if ((lclk_map.cnt[0][1] == 'd0) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[0][1] <= lclk_aln.dat[0][1];
                    lclk_map.wr[0][1] <= 1;
                end

                // B4
                else if ((lclk_map.cnt[0][2] == 'd3) && lclk_aln.wr[0][2])
                begin
                    lclk_map.dat[0][1] <= lclk_aln.dat[0][2];
                    lclk_map.wr[0][1] <= 1;
                end

                // R12
                else if ((lclk_map.cnt[0][0] == 'd9) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[0][1] <= lclk_aln.dat[0][0];
                    lclk_map.wr[0][1] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[0][1] <= 0;
                    lclk_map.wr[0][1] <= 0;
                end

            // Stripe 2

                // B0
                if ((lclk_map.cnt[0][2] == 'd0) && lclk_aln.wr[0][2])
                begin
                    lclk_map.dat[0][2] <= lclk_aln.dat[0][2];
                    lclk_map.wr[0][2] <= 1;
                end

                // R8
                else if ((lclk_map.cnt[0][0] == 'd6) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[0][2] <= lclk_aln.dat[0][0];
                    lclk_map.wr[0][2] <= 1;
                end

                // G12
                else if ((lclk_map.cnt[0][1] == 'd9) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[0][2] <= lclk_aln.dat[0][1];
                    lclk_map.wr[0][2] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[0][2] <= 0;
                    lclk_map.wr[0][2] <= 0;
                end

            // Stripe 3

                // R4
                if ((lclk_map.cnt[0][0] == 'd3) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[0][3] <= lclk_aln.dat[0][0];
                    lclk_map.wr[0][3] <= 1;
                end

                // G8
                else if ((lclk_map.cnt[0][1] == 'd6) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[0][3] <= lclk_aln.dat[0][1];
                    lclk_map.wr[0][3] <= 1;
                end

                // B12
                else if ((lclk_map.cnt[0][2] == 'd9) && lclk_aln.wr[0][2])
                begin
                    lclk_map.dat[0][3] <= lclk_aln.dat[0][2];
                    lclk_map.wr[0][3] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[0][3] <= 0;
                    lclk_map.wr[0][3] <= 0;
                end

            // Stripe 4

                // R1
                if ((lclk_map.cnt[0][3] == 'd0) && lclk_aln.wr[0][3])
                begin
                    lclk_map.dat[1][0] <= lclk_aln.dat[0][3];
                    lclk_map.wr[1][0] <= 1;
                end

                // G5
                else if ((lclk_map.cnt[0][0] == 'd4) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[1][0] <= lclk_aln.dat[0][0];
                    lclk_map.wr[1][0] <= 1;
                end

                // B9
                else if ((lclk_map.cnt[0][1] == 'd7) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[1][0] <= lclk_aln.dat[0][1];
                    lclk_map.wr[1][0] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[1][0] <= 0;
                    lclk_map.wr[1][0] <= 0;
                end

            // Stripe 5

                // G1
                if ((lclk_map.cnt[0][0] == 'd1) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[1][1] <= lclk_aln.dat[0][0];
                    lclk_map.wr[1][1] <= 1;
                end

                // B5
                else if ((lclk_map.cnt[0][1] == 'd4) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[1][1] <= lclk_aln.dat[0][1];
                    lclk_map.wr[1][1] <= 1;
                end

                // R13
                else if ((lclk_map.cnt[0][3] == 'd9) && lclk_aln.wr[0][3])
                begin
                    lclk_map.dat[1][1] <= lclk_aln.dat[0][3];
                    lclk_map.wr[1][1] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[1][1] <= 0;
                    lclk_map.wr[1][1] <= 0;
                end

            // Stripe 6

                // B1
                if ((lclk_map.cnt[0][1] == 'd1) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[1][2] <= lclk_aln.dat[0][1];
                    lclk_map.wr[1][2] <= 1;
                end

                // R9
                else if ((lclk_map.cnt[0][3] == 'd6) && lclk_aln.wr[0][3])
                begin
                    lclk_map.dat[1][2] <= lclk_aln.dat[0][3];
                    lclk_map.wr[1][2] <= 1;
                end

                // G13
                else if ((lclk_map.cnt[0][0] == 'd10) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[1][2] <= lclk_aln.dat[0][0];
                    lclk_map.wr[1][2] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[1][2] <= 0;
                    lclk_map.wr[1][2] <= 0;
                end

            // Stripe 7

                // R5
                if ((lclk_map.cnt[0][3] == 'd3) && lclk_aln.wr[0][3])
                begin
                    lclk_map.dat[1][3] <= lclk_aln.dat[0][3];
                    lclk_map.wr[1][3] <= 1;
                end

                // G9
                else if ((lclk_map.cnt[0][0] == 'd7) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[1][3] <= lclk_aln.dat[0][0];
                    lclk_map.wr[1][3] <= 1;
                end

                // B13
                else if ((lclk_map.cnt[0][1] == 'd10) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[1][3] <= lclk_aln.dat[0][1];
                    lclk_map.wr[1][3] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[1][3] <= 0;
                    lclk_map.wr[1][3] <= 0;
                end

            // Stripe 8

                // R2
                if ((lclk_map.cnt[0][2] == 'd1) && lclk_aln.wr[0][2])
                begin
                    lclk_map.dat[2][0] <= lclk_aln.dat[0][2];
                    lclk_map.wr[2][0] <= 1;
                end

                // G6
                else if ((lclk_map.cnt[0][3] == 'd4) && lclk_aln.wr[0][3])
                begin
                    lclk_map.dat[2][0] <= lclk_aln.dat[0][3];
                    lclk_map.wr[2][0] <= 1;
                end

                // B10
                else if ((lclk_map.cnt[0][0] == 'd8) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[2][0] <= lclk_aln.dat[0][0];
                    lclk_map.wr[2][0] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[2][0] <= 0;
                    lclk_map.wr[2][0] <= 0;
                end

            // Stripe 9

                // G2
                if ((lclk_map.cnt[0][3] == 'd1) && lclk_aln.wr[0][3])
                begin
                    lclk_map.dat[2][1] <= lclk_aln.dat[0][3];
                    lclk_map.wr[2][1] <= 1;
                end

                // B6
                else if ((lclk_map.cnt[0][0] == 'd5) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[2][1] <= lclk_aln.dat[0][0];
                    lclk_map.wr[2][1] <= 1;
                end

                // R14
                else if ((lclk_map.cnt[0][2] == 'd10) && lclk_aln.wr[0][2])
                begin
                    lclk_map.dat[2][1] <= lclk_aln.dat[0][2];
                    lclk_map.wr[2][1] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[2][1] <= 0;
                    lclk_map.wr[2][1] <= 0;
                end

            // Stripe 10

                // B2
                if ((lclk_map.cnt[0][0] == 'd2) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[2][2] <= lclk_aln.dat[0][0];
                    lclk_map.wr[2][2] <= 1;
                end

                // R10
                else if ((lclk_map.cnt[0][2] == 'd7) && lclk_aln.wr[0][2])
                begin
                    lclk_map.dat[2][2] <= lclk_aln.dat[0][2];
                    lclk_map.wr[2][2] <= 1;
                end

                // G14
                else if ((lclk_map.cnt[0][3] == 'd10) && lclk_aln.wr[0][3])
                begin
                    lclk_map.dat[2][2] <= lclk_aln.dat[0][3];
                    lclk_map.wr[2][2] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[2][2] <= 0;
                    lclk_map.wr[2][2] <= 0;
                end

            // Stripe 11

                // R6
                if ((lclk_map.cnt[0][2] == 'd4) && lclk_aln.wr[0][2])
                begin
                    lclk_map.dat[2][3] <= lclk_aln.dat[0][2];
                    lclk_map.wr[2][3] <= 1;
                end

                // G10
                else if ((lclk_map.cnt[0][3] == 'd7) && lclk_aln.wr[0][3])
                begin
                    lclk_map.dat[2][3] <= lclk_aln.dat[0][3];
                    lclk_map.wr[2][3] <= 1;
                end

                // B14
                else if ((lclk_map.cnt[0][0] == 'd11) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[2][3] <= lclk_aln.dat[0][0];
                    lclk_map.wr[2][3] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[2][3] <= 0;
                    lclk_map.wr[2][3] <= 0;
                end

            // Stripe 12

                // R3
                if ((lclk_map.cnt[0][1] == 'd2) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[3][0] <= lclk_aln.dat[0][1];
                    lclk_map.wr[3][0] <= 1;
                end

                // G7
                else if ((lclk_map.cnt[0][2] == 'd5) && lclk_aln.wr[0][2])
                begin
                    lclk_map.dat[3][0] <= lclk_aln.dat[0][2];
                    lclk_map.wr[3][0] <= 1;
                end

                // B11
                else if ((lclk_map.cnt[0][3] == 'd8) && lclk_aln.wr[0][3])
                begin
                    lclk_map.dat[3][0] <= lclk_aln.dat[0][3];
                    lclk_map.wr[3][0] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[3][0] <= 0;
                    lclk_map.wr[3][0] <= 0;
                end

            // Stripe 13

                // G3
                if ((lclk_map.cnt[0][2] == 'd2) && lclk_aln.wr[0][2])
                begin
                    lclk_map.dat[3][1] <= lclk_aln.dat[0][2];
                    lclk_map.wr[3][1] <= 1;
                end

                // B7
                else if ((lclk_map.cnt[0][3] == 'd5) && lclk_aln.wr[0][3])
                begin
                    lclk_map.dat[3][1] <= lclk_aln.dat[0][3];
                    lclk_map.wr[3][1] <= 1;
                end

                // R15
                else if ((lclk_map.cnt[0][1] == 'd11) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[3][1] <= lclk_aln.dat[0][1];
                    lclk_map.wr[3][1] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[3][1] <= 0;
                    lclk_map.wr[3][1] <= 0;
                end

            // Stripe 14

                // B3
                if ((lclk_map.cnt[0][3] == 'd2) && lclk_aln.wr[0][3])
                begin
                    lclk_map.dat[3][2] <= lclk_aln.dat[0][3];
                    lclk_map.wr[3][2] <= 1;
                end

                // R11
                else if ((lclk_map.cnt[0][1] == 'd8) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[3][2] <= lclk_aln.dat[0][1];
                    lclk_map.wr[3][2] <= 1;
                end

                // G15
                else if ((lclk_map.cnt[0][2] == 'd11) && lclk_aln.wr[0][2])
                begin
                    lclk_map.dat[3][2] <= lclk_aln.dat[0][2];
                    lclk_map.wr[3][2] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[3][2] <= 0;
                    lclk_map.wr[3][2] <= 0;
                end

            // Stripe 15

                // R7
                if ((lclk_map.cnt[0][1] == 'd5) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[3][3] <= lclk_aln.dat[0][1];
                    lclk_map.wr[3][3] <= 1;
                end

                // G11
                else if ((lclk_map.cnt[0][2] == 'd8) && lclk_aln.wr[0][2])
                begin
                    lclk_map.dat[3][3] <= lclk_aln.dat[0][2];
                    lclk_map.wr[3][3] <= 1;
                end

                // B15
                else if ((lclk_map.cnt[0][3] == 'd11) && lclk_aln.wr[0][3])
                begin
                    lclk_map.dat[3][3] <= lclk_aln.dat[0][3];
                    lclk_map.wr[3][3] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[3][3] <= 0;
                    lclk_map.wr[3][3] <= 0;
                end
            end

            // 2 lanes
            else if (lclk_ctl.lanes == 'd2)
            begin

            // Stripe 0

                // R0
                if ((lclk_map.cnt[0][0] == 'd0) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[0][0] <= lclk_aln.dat[0][0];
                    lclk_map.wr[0][0] <= 1;
                end

                // G4
                else if ((lclk_map.cnt[0][3] == 'd1) && lclk_aln.wr[0][3])
                begin
                    lclk_map.dat[0][0] <= lclk_aln.dat[0][3];
                    lclk_map.wr[0][0] <= 1;
                end

                // B8
                else if ((lclk_map.cnt[0][2] == 'd3) && lclk_aln.wr[0][2])
                begin
                    lclk_map.dat[0][0] <= lclk_aln.dat[0][2];
                    lclk_map.wr[0][0] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[0][0] <= 0;
                    lclk_map.wr[0][0] <= 0;
                end

            // Stripe 1

                // G0
                if ((lclk_map.cnt[0][1] == 'd0) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[0][1] <= lclk_aln.dat[0][1];
                    lclk_map.wr[0][1] <= 1;
                end

                // B4
                else if ((lclk_map.cnt[0][0] == 'd2) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[0][1] <= lclk_aln.dat[0][0];
                    lclk_map.wr[0][1] <= 1;
                end

                // R12
                else if ((lclk_map.cnt[0][2] == 'd4) && lclk_aln.wr[0][2])
                begin
                    lclk_map.dat[0][1] <= lclk_aln.dat[0][2];
                    lclk_map.wr[0][1] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[0][1] <= 0;
                    lclk_map.wr[0][1] <= 0;
                end

            // Stripe 2

                // B0
                if ((lclk_map.cnt[0][2] == 'd0) && lclk_aln.wr[0][2])
                begin
                    lclk_map.dat[0][2] <= lclk_aln.dat[0][2];
                    lclk_map.wr[0][2] <= 1;
                end

                // R8
                else if ((lclk_map.cnt[0][0] == 'd3) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[0][2] <= lclk_aln.dat[0][0];
                    lclk_map.wr[0][2] <= 1;
                end

                // G12
                else if ((lclk_map.cnt[0][3] == 'd4) && lclk_aln.wr[0][3])
                begin
                    lclk_map.dat[0][2] <= lclk_aln.dat[0][3];
                    lclk_map.wr[0][2] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[0][2] <= 0;
                    lclk_map.wr[0][2] <= 0;
                end

            // Stripe 3

                // R4
                if ((lclk_map.cnt[0][2] == 'd1) && lclk_aln.wr[0][2])
                begin
                    lclk_map.dat[0][3] <= lclk_aln.dat[0][2];
                    lclk_map.wr[0][3] <= 1;
                end

                // G8
                else if ((lclk_map.cnt[0][1] == 'd3) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[0][3] <= lclk_aln.dat[0][1];
                    lclk_map.wr[0][3] <= 1;
                end

                // B12
                else if ((lclk_map.cnt[0][0] == 'd5) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[0][3] <= lclk_aln.dat[0][0];
                    lclk_map.wr[0][3] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[0][3] <= 0;
                    lclk_map.wr[0][3] <= 0;
                end

            // Stripe 4

                // R1
                if ((lclk_map.cnt[1][0] == 'd0) && lclk_aln.wr[1][0])
                begin
                    lclk_map.dat[1][0] <= lclk_aln.dat[1][0];
                    lclk_map.wr[1][0] <= 1;
                end

                // G5
                else if ((lclk_map.cnt[1][3] == 'd1) && lclk_aln.wr[1][3])
                begin
                    lclk_map.dat[1][0] <= lclk_aln.dat[1][3];
                    lclk_map.wr[1][0] <= 1;
                end

                // B9
                else if ((lclk_map.cnt[1][2] == 'd3) && lclk_aln.wr[1][2])
                begin
                    lclk_map.dat[1][0] <= lclk_aln.dat[1][2];
                    lclk_map.wr[1][0] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[1][0] <= 0;
                    lclk_map.wr[1][0] <= 0;
                end

            // Stripe 5

                // G1
                if ((lclk_map.cnt[1][1] == 'd0) && lclk_aln.wr[1][1])
                begin
                    lclk_map.dat[1][1] <= lclk_aln.dat[1][1];
                    lclk_map.wr[1][1] <= 1;
                end

                // B5
                else if ((lclk_map.cnt[1][0] == 'd2) && lclk_aln.wr[1][0])
                begin
                    lclk_map.dat[1][1] <= lclk_aln.dat[1][0];
                    lclk_map.wr[1][1] <= 1;
                end

                // R13
                else if ((lclk_map.cnt[1][2] == 'd4) && lclk_aln.wr[1][2])
                begin
                    lclk_map.dat[1][1] <= lclk_aln.dat[1][2];
                    lclk_map.wr[1][1] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[1][1] <= 0;
                    lclk_map.wr[1][1] <= 0;
                end

            // Stripe 6

                // B1
                if ((lclk_map.cnt[1][2] == 'd0) && lclk_aln.wr[1][2])
                begin
                    lclk_map.dat[1][2] <= lclk_aln.dat[1][2];
                    lclk_map.wr[1][2] <= 1;
                end

                // R9
                else if ((lclk_map.cnt[1][0] == 'd3) && lclk_aln.wr[1][0])
                begin
                    lclk_map.dat[1][2] <= lclk_aln.dat[1][0];
                    lclk_map.wr[1][2] <= 1;
                end

                // G13
                else if ((lclk_map.cnt[1][3] == 'd4) && lclk_aln.wr[1][3])
                begin
                    lclk_map.dat[1][2] <= lclk_aln.dat[1][3];
                    lclk_map.wr[1][2] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[1][2] <= 0;
                    lclk_map.wr[1][2] <= 0;
                end

            // Stripe 7

                // R5
                if ((lclk_map.cnt[1][2] == 'd1) && lclk_aln.wr[1][2])
                begin
                    lclk_map.dat[1][3] <= lclk_aln.dat[1][2];
                    lclk_map.wr[1][3] <= 1;
                end

                // G9
                else if ((lclk_map.cnt[1][1] == 'd3) && lclk_aln.wr[1][1])
                begin
                    lclk_map.dat[1][3] <= lclk_aln.dat[1][1];
                    lclk_map.wr[1][3] <= 1;
                end

                // B13
                else if ((lclk_map.cnt[1][0] == 'd5) && lclk_aln.wr[1][0])
                begin
                    lclk_map.dat[1][3] <= lclk_aln.dat[1][0];
                    lclk_map.wr[1][3] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[1][3] <= 0;
                    lclk_map.wr[1][3] <= 0;
                end

            // Stripe 8

                // R2
                if ((lclk_map.cnt[0][3] == 'd0) && lclk_aln.wr[0][3])
                begin
                    lclk_map.dat[2][0] <= lclk_aln.dat[0][3];
                    lclk_map.wr[2][0] <= 1;
                end

                // G6
                else if ((lclk_map.cnt[0][2] == 'd2) && lclk_aln.wr[0][2])
                begin
                    lclk_map.dat[2][0] <= lclk_aln.dat[0][2];
                    lclk_map.wr[2][0] <= 1;
                end

                // B10
                else if ((lclk_map.cnt[0][1] == 'd4) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[2][0] <= lclk_aln.dat[0][1];
                    lclk_map.wr[2][0] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[2][0] <= 0;
                    lclk_map.wr[2][0] <= 0;
                end

            // Stripe 9

                // G2
                if ((lclk_map.cnt[0][0] == 'd1) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[2][1] <= lclk_aln.dat[0][0];
                    lclk_map.wr[2][1] <= 1;
                end

                // B6
                else if ((lclk_map.cnt[0][3] == 'd2) && lclk_aln.wr[0][3])
                begin
                    lclk_map.dat[2][1] <= lclk_aln.dat[0][3];
                    lclk_map.wr[2][1] <= 1;
                end

                // R14
                else if ((lclk_map.cnt[0][1] == 'd5) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[2][1] <= lclk_aln.dat[0][1];
                    lclk_map.wr[2][1] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[2][1] <= 0;
                    lclk_map.wr[2][1] <= 0;
                end

            // Stripe 10

                // B2
                if ((lclk_map.cnt[0][1] == 'd1) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[2][2] <= lclk_aln.dat[0][1];
                    lclk_map.wr[2][2] <= 1;
                end

                // R10
                else if ((lclk_map.cnt[0][3] == 'd3) && lclk_aln.wr[0][3])
                begin
                    lclk_map.dat[2][2] <= lclk_aln.dat[0][3];
                    lclk_map.wr[2][2] <= 1;
                end

                // G14
                else if ((lclk_map.cnt[0][2] == 'd5) && lclk_aln.wr[0][2])
                begin
                    lclk_map.dat[2][2] <= lclk_aln.dat[0][2];
                    lclk_map.wr[2][2] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[2][2] <= 0;
                    lclk_map.wr[2][2] <= 0;
                end

            // Stripe 11

                // R6
                if ((lclk_map.cnt[0][1] == 'd2) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[2][3] <= lclk_aln.dat[0][1];
                    lclk_map.wr[2][3] <= 1;
                end

                // G10
                else if ((lclk_map.cnt[0][0] == 'd4) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[2][3] <= lclk_aln.dat[0][0];
                    lclk_map.wr[2][3] <= 1;
                end

                // B14
                else if ((lclk_map.cnt[0][3] == 'd5) && lclk_aln.wr[0][3])
                begin
                    lclk_map.dat[2][3] <= lclk_aln.dat[0][3];
                    lclk_map.wr[2][3] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[2][3] <= 0;
                    lclk_map.wr[2][3] <= 0;
                end

            // Stripe 12

                // R3
                if ((lclk_map.cnt[1][3] == 'd0) && lclk_aln.wr[1][3])
                begin
                    lclk_map.dat[3][0] <= lclk_aln.dat[1][3];
                    lclk_map.wr[3][0] <= 1;
                end

                // G7
                else if ((lclk_map.cnt[1][2] == 'd2) && lclk_aln.wr[1][2])
                begin
                    lclk_map.dat[3][0] <= lclk_aln.dat[1][2];
                    lclk_map.wr[3][0] <= 1;
                end

                // B11
                else if ((lclk_map.cnt[1][1] == 'd4) && lclk_aln.wr[1][1])
                begin
                    lclk_map.dat[3][0] <= lclk_aln.dat[1][1];
                    lclk_map.wr[3][0] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[3][0] <= 0;
                    lclk_map.wr[3][0] <= 0;
                end

            // Stripe 13

                // G3
                if ((lclk_map.cnt[1][0] == 'd1) && lclk_aln.wr[1][0])
                begin
                    lclk_map.dat[3][1] <= lclk_aln.dat[1][0];
                    lclk_map.wr[3][1] <= 1;
                end

                // B7
                else if ((lclk_map.cnt[1][3] == 'd2) && lclk_aln.wr[1][3])
                begin
                    lclk_map.dat[3][1] <= lclk_aln.dat[1][3];
                    lclk_map.wr[3][1] <= 1;
                end

                // R15
                else if ((lclk_map.cnt[1][1] == 'd5) && lclk_aln.wr[1][1])
                begin
                    lclk_map.dat[3][1] <= lclk_aln.dat[1][1];
                    lclk_map.wr[3][1] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[3][1] <= 0;
                    lclk_map.wr[3][1] <= 0;
                end

            // Stripe 14

                // B3
                if ((lclk_map.cnt[1][1] == 'd1) && lclk_aln.wr[1][1])
                begin
                    lclk_map.dat[3][2] <= lclk_aln.dat[1][1];
                    lclk_map.wr[3][2] <= 1;
                end

                // R11
                else if ((lclk_map.cnt[1][3] == 'd3) && lclk_aln.wr[1][3])
                begin
                    lclk_map.dat[3][2] <= lclk_aln.dat[1][3];
                    lclk_map.wr[3][2] <= 1;
                end

                // G15
                else if ((lclk_map.cnt[1][2] == 'd5) && lclk_aln.wr[1][2])
                begin
                    lclk_map.dat[3][2] <= lclk_aln.dat[1][2];
                    lclk_map.wr[3][2] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[3][2] <= 0;
                    lclk_map.wr[3][2] <= 0;
                end

            // Stripe 15

                // R7
                if ((lclk_map.cnt[1][1] == 'd2) && lclk_aln.wr[1][1])
                begin
                    lclk_map.dat[3][3] <= lclk_aln.dat[1][1];
                    lclk_map.wr[3][3] <= 1;
                end

                // G11
                else if ((lclk_map.cnt[1][0] == 'd4) && lclk_aln.wr[1][0])
                begin
                    lclk_map.dat[3][3] <= lclk_aln.dat[1][0];
                    lclk_map.wr[3][3] <= 1;
                end

                // B15
                else if ((lclk_map.cnt[1][3] == 'd5) && lclk_aln.wr[1][3])
                begin
                    lclk_map.dat[3][3] <= lclk_aln.dat[1][3];
                    lclk_map.wr[3][3] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[3][3] <= 0;
                    lclk_map.wr[3][3] <= 0;
                end
            end

            // 4 lanes
            else
            begin
                for (int i = 0; i < P_LANES; i++)
                begin
                    for (int j = 0; j < P_SPL; j++)
                    begin
                        lclk_map.wr[i][j] <= lclk_aln.wr[i][j];
                        lclk_map.dat[i][j] <= lclk_aln.dat[i][j];
                    end
                end
            end
        end
    end 

    else
    begin : gen_map_dat_2spl

        always_ff @ (posedge LNK_CLK_IN)
        begin
            // Default
            for (int i = 0; i < P_LANES; i++)
            begin
                for (int j = 0; j < P_FIFO_STRIPES; j++)
                begin
                        lclk_map.dat[i][j] <= 0;
                        lclk_map.wr[i][j] <= 0;
                end
            end

            // 1 lane
            if (lclk_ctl.lanes == 'd1)
            begin

            // Stripe 0

                // R0
                if ((lclk_map.cnt[0][0] == 'd0) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[0][0] <= lclk_aln.dat[0][0];
                    lclk_map.wr[0][0] <= 1;
                end

                // G4
                else if ((lclk_map.cnt[0][1] == 'd6) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[0][0] <= lclk_aln.dat[0][1];
                    lclk_map.wr[0][0] <= 1;
                end

                // B8
                else if ((lclk_map.cnt[0][0] == 'd13) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[0][0] <= lclk_aln.dat[0][0];
                    lclk_map.wr[0][0] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[0][0] <= 0;
                    lclk_map.wr[0][0] <= 0;
                end

            // Stripe 1

                // G0
                if ((lclk_map.cnt[0][1] == 'd0) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[0][1] <= lclk_aln.dat[0][1];
                    lclk_map.wr[0][1] <= 1;
                end

                // B4
                else if ((lclk_map.cnt[0][0] == 'd7) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[0][1] <= lclk_aln.dat[0][0];
                    lclk_map.wr[0][1] <= 1;
                end

                // R12
                else if ((lclk_map.cnt[0][0] == 'd18) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[0][1] <= lclk_aln.dat[0][0];
                    lclk_map.wr[0][1] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[0][1] <= 0;
                    lclk_map.wr[0][1] <= 0;
                end

            // Stripe 2

                // B0
                if ((lclk_map.cnt[0][0] == 'd1) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[0][2] <= lclk_aln.dat[0][0];
                    lclk_map.wr[0][2] <= 1;
                end

                // R8
                else if ((lclk_map.cnt[0][0] == 'd12) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[0][2] <= lclk_aln.dat[0][0];
                    lclk_map.wr[0][2] <= 1;
                end

                // G12
                else if ((lclk_map.cnt[0][1] == 'd18) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[0][2] <= lclk_aln.dat[0][1];
                    lclk_map.wr[0][2] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[0][2] <= 0;
                    lclk_map.wr[0][2] <= 0;
                end

            // Stripe 3

                // R4
                if ((lclk_map.cnt[0][0] == 'd6) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[0][3] <= lclk_aln.dat[0][0];
                    lclk_map.wr[0][3] <= 1;
                end

                // G8
                else if ((lclk_map.cnt[0][1] == 'd12) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[0][3] <= lclk_aln.dat[0][1];
                    lclk_map.wr[0][3] <= 1;
                end

                // B12
                else if ((lclk_map.cnt[0][0] == 'd19) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[0][3] <= lclk_aln.dat[0][0];
                    lclk_map.wr[0][3] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[0][3] <= 0;
                    lclk_map.wr[0][3] <= 0;
                end

            // Stripe 4

                // R1
                if ((lclk_map.cnt[0][1] == 'd1) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[1][0] <= lclk_aln.dat[0][1];
                    lclk_map.wr[1][0] <= 1;
                end

                // G5
                else if ((lclk_map.cnt[0][0] == 'd8) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[1][0] <= lclk_aln.dat[0][0];
                    lclk_map.wr[1][0] <= 1;
                end

                // B9
                else if ((lclk_map.cnt[0][1] == 'd14) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[1][0] <= lclk_aln.dat[0][1];
                    lclk_map.wr[1][0] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[1][0] <= 0;
                    lclk_map.wr[1][0] <= 0;
                end

            // Stripe 5

                // G1
                if ((lclk_map.cnt[0][0] == 'd2) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[1][1] <= lclk_aln.dat[0][0];
                    lclk_map.wr[1][1] <= 1;
                end

                // B5
                else if ((lclk_map.cnt[0][1] == 'd8) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[1][1] <= lclk_aln.dat[0][1];
                    lclk_map.wr[1][1] <= 1;
                end

                // R13
                else if ((lclk_map.cnt[0][1] == 'd19) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[1][1] <= lclk_aln.dat[0][1];
                    lclk_map.wr[1][1] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[1][1] <= 0;
                    lclk_map.wr[1][1] <= 0;
                end

            // Stripe 6

                // B1
                if ((lclk_map.cnt[0][1] == 'd2) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[1][2] <= lclk_aln.dat[0][1];
                    lclk_map.wr[1][2] <= 1;
                end

                // R9
                else if ((lclk_map.cnt[0][1] == 'd13) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[1][2] <= lclk_aln.dat[0][1];
                    lclk_map.wr[1][2] <= 1;
                end

                // G13
                else if ((lclk_map.cnt[0][0] == 'd20) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[1][2] <= lclk_aln.dat[0][0];
                    lclk_map.wr[1][2] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[1][2] <= 0;
                    lclk_map.wr[1][2] <= 0;
                end

            // Stripe 7

                // R5
                if ((lclk_map.cnt[0][1] == 'd7) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[1][3] <= lclk_aln.dat[0][1];
                    lclk_map.wr[1][3] <= 1;
                end

                // G9
                else if ((lclk_map.cnt[0][0] == 'd14) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[1][3] <= lclk_aln.dat[0][0];
                    lclk_map.wr[1][3] <= 1;
                end

                // B13
                else if ((lclk_map.cnt[0][1] == 'd20) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[1][3] <= lclk_aln.dat[0][1];
                    lclk_map.wr[1][3] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[1][3] <= 0;
                    lclk_map.wr[1][3] <= 0;
                end

            // Stripe 8

                // R2
                if ((lclk_map.cnt[0][0] == 'd3) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[2][0] <= lclk_aln.dat[0][0];
                    lclk_map.wr[2][0] <= 1;
                end

                // G6
                else if ((lclk_map.cnt[0][1] == 'd9) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[2][0] <= lclk_aln.dat[0][1];
                    lclk_map.wr[2][0] <= 1;
                end

                // B10
                else if ((lclk_map.cnt[0][0] == 'd16) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[2][0] <= lclk_aln.dat[0][0];
                    lclk_map.wr[2][0] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[2][0] <= 0;
                    lclk_map.wr[2][0] <= 0;
                end

            // Stripe 9

                // G2
                if ((lclk_map.cnt[0][1] == 'd3) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[2][1] <= lclk_aln.dat[0][1];
                    lclk_map.wr[2][1] <= 1;
                end

                // B6
                else if ((lclk_map.cnt[0][0] == 'd10) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[2][1] <= lclk_aln.dat[0][0];
                    lclk_map.wr[2][1] <= 1;
                end

                // R14
                else if ((lclk_map.cnt[0][0] == 'd21) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[2][1] <= lclk_aln.dat[0][0];
                    lclk_map.wr[2][1] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[2][1] <= 0;
                    lclk_map.wr[2][1] <= 0;
                end

            // Stripe 10

                // B2
                if ((lclk_map.cnt[0][0] == 'd4) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[2][2] <= lclk_aln.dat[0][0];
                    lclk_map.wr[2][2] <= 1;
                end

                // R10
                else if ((lclk_map.cnt[0][0] == 'd15) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[2][2] <= lclk_aln.dat[0][0];
                    lclk_map.wr[2][2] <= 1;
                end

                // G14
                else if ((lclk_map.cnt[0][1] == 'd21) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[2][2] <= lclk_aln.dat[0][1];
                    lclk_map.wr[2][2] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[2][2] <= 0;
                    lclk_map.wr[2][2] <= 0;
                end

            // Stripe 11

                // R6
                if ((lclk_map.cnt[0][0] == 'd9) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[2][3] <= lclk_aln.dat[0][0];
                    lclk_map.wr[2][3] <= 1;
                end

                // G10
                else if ((lclk_map.cnt[0][1] == 'd15) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[2][3] <= lclk_aln.dat[0][1];
                    lclk_map.wr[2][3] <= 1;
                end

                // B14
                else if ((lclk_map.cnt[0][0] == 'd22) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[2][3] <= lclk_aln.dat[0][0];
                    lclk_map.wr[2][3] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[2][3] <= 0;
                    lclk_map.wr[2][3] <= 0;
                end

            // Stripe 12

                // R3
                if ((lclk_map.cnt[0][1] == 'd4) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[3][0] <= lclk_aln.dat[0][1];
                    lclk_map.wr[3][0] <= 1;
                end

                // G7
                else if ((lclk_map.cnt[0][0] == 'd11) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[3][0] <= lclk_aln.dat[0][0];
                    lclk_map.wr[3][0] <= 1;
                end

                // B11
                else if ((lclk_map.cnt[0][1] == 'd17) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[3][0] <= lclk_aln.dat[0][1];
                    lclk_map.wr[3][0] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[3][0] <= 0;
                    lclk_map.wr[3][0] <= 0;
                end

            // Stripe 13

                // G3
                if ((lclk_map.cnt[0][0] == 'd5) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[3][1] <= lclk_aln.dat[0][0];
                    lclk_map.wr[3][1] <= 1;
                end

                // B7
                else if ((lclk_map.cnt[0][1] == 'd11) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[3][1] <= lclk_aln.dat[0][1];
                    lclk_map.wr[3][1] <= 1;
                end

                // R15
                else if ((lclk_map.cnt[0][1] == 'd22) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[3][1] <= lclk_aln.dat[0][1];
                    lclk_map.wr[3][1] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[3][1] <= 0;
                    lclk_map.wr[3][1] <= 0;
                end

            // Stripe 14

                // B3
                if ((lclk_map.cnt[0][1] == 'd5) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[3][2] <= lclk_aln.dat[0][1];
                    lclk_map.wr[3][2] <= 1;
                end

                // R11
                else if ((lclk_map.cnt[0][1] == 'd16) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[3][2] <= lclk_aln.dat[0][1];
                    lclk_map.wr[3][2] <= 1;
                end

                // G15
                else if ((lclk_map.cnt[0][0] == 'd23) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[3][2] <= lclk_aln.dat[0][0];
                    lclk_map.wr[3][2] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[3][2] <= 0;
                    lclk_map.wr[3][2] <= 0;
                end

            // Stripe 15

                // R7
                if ((lclk_map.cnt[0][1] == 'd10) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[3][3] <= lclk_aln.dat[0][1];
                    lclk_map.wr[3][3] <= 1;
                end

                // G11
                else if ((lclk_map.cnt[0][0] == 'd17) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[3][3] <= lclk_aln.dat[0][0];
                    lclk_map.wr[3][3] <= 1;
                end

                // B15
                else if ((lclk_map.cnt[0][1] == 'd23) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[3][3] <= lclk_aln.dat[0][1];
                    lclk_map.wr[3][3] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[3][3] <= 0;
                    lclk_map.wr[3][3] <= 0;
                end
            end

            // 2 lanes
            else if (lclk_ctl.lanes == 'd2)
            begin
            
            // Stripe 0

                // R0
                if ((lclk_map.cnt[0][0] == 'd0) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[0][0] <= lclk_aln.dat[0][0];
                    lclk_map.wr[0][0] <= 1;
                end

                // G4
                else if ((lclk_map.cnt[0][1] == 'd3) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[0][0] <= lclk_aln.dat[0][1];
                    lclk_map.wr[0][0] <= 1;
                end

                // B8
                else if ((lclk_map.cnt[0][0] == 'd7) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[0][0] <= lclk_aln.dat[0][0];
                    lclk_map.wr[0][0] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[0][0] <= 0;
                    lclk_map.wr[0][0] <= 0;
                end

            // Stripe 1

                // G0
                if ((lclk_map.cnt[0][1] == 'd0) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[0][1] <= lclk_aln.dat[0][1];
                    lclk_map.wr[0][1] <= 1;
                end

                // B4
                else if ((lclk_map.cnt[0][0] == 'd4) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[0][1] <= lclk_aln.dat[0][0];
                    lclk_map.wr[0][1] <= 1;
                end

                // R12
                else if ((lclk_map.cnt[0][0] == 'd9) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[0][1] <= lclk_aln.dat[0][0];
                    lclk_map.wr[0][1] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[0][1] <= 0;
                    lclk_map.wr[0][1] <= 0;
                end

            // Stripe 2

                // B0
                if ((lclk_map.cnt[0][0] == 'd1) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[0][2] <= lclk_aln.dat[0][0];
                    lclk_map.wr[0][2] <= 1;
                end

                // R8
                else if ((lclk_map.cnt[0][0] == 'd6) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[0][2] <= lclk_aln.dat[0][0];
                    lclk_map.wr[0][2] <= 1;
                end

                // G12
                else if ((lclk_map.cnt[0][1] == 'd9) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[0][2] <= lclk_aln.dat[0][1];
                    lclk_map.wr[0][2] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[0][2] <= 0;
                    lclk_map.wr[0][2] <= 0;
                end

            // Stripe 3

                // R4
                if ((lclk_map.cnt[0][0] == 'd3) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[0][3] <= lclk_aln.dat[0][0];
                    lclk_map.wr[0][3] <= 1;
                end

                // G8
                else if ((lclk_map.cnt[0][1] == 'd6) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[0][3] <= lclk_aln.dat[0][1];
                    lclk_map.wr[0][3] <= 1;
                end

                // B12
                else if ((lclk_map.cnt[0][0] == 'd10) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[0][3] <= lclk_aln.dat[0][0];
                    lclk_map.wr[0][3] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[0][3] <= 0;
                    lclk_map.wr[0][3] <= 0;
                end

            // Stripe 4

                // R1
                if ((lclk_map.cnt[1][0] == 'd0) && lclk_aln.wr[1][0])
                begin
                    lclk_map.dat[1][0] <= lclk_aln.dat[1][0];
                    lclk_map.wr[1][0] <= 1;
                end

                // G5
                else if ((lclk_map.cnt[1][1] == 'd3) && lclk_aln.wr[1][1])
                begin
                    lclk_map.dat[1][0] <= lclk_aln.dat[1][1];
                    lclk_map.wr[1][0] <= 1;
                end

                // B9
                else if ((lclk_map.cnt[1][0] == 'd7) && lclk_aln.wr[1][0])
                begin
                    lclk_map.dat[1][0] <= lclk_aln.dat[1][0];
                    lclk_map.wr[1][0] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[1][0] <= 0;
                    lclk_map.wr[1][0] <= 0;
                end

            // Stripe 5

                // G1
                if ((lclk_map.cnt[1][1] == 'd0) && lclk_aln.wr[1][1])
                begin
                    lclk_map.dat[1][1] <= lclk_aln.dat[1][1];
                    lclk_map.wr[1][1] <= 1;
                end

                // B5
                else if ((lclk_map.cnt[1][0] == 'd4) && lclk_aln.wr[1][0])
                begin
                    lclk_map.dat[1][1] <= lclk_aln.dat[1][0];
                    lclk_map.wr[1][1] <= 1;
                end

                // R13
                else if ((lclk_map.cnt[1][0] == 'd9) && lclk_aln.wr[1][0])
                begin
                    lclk_map.dat[1][1] <= lclk_aln.dat[1][0];
                    lclk_map.wr[1][1] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[1][1] <= 0;
                    lclk_map.wr[1][1] <= 0;
                end

            // Stripe 6

                // B1
                if ((lclk_map.cnt[1][0] == 'd1) && lclk_aln.wr[1][0])
                begin
                    lclk_map.dat[1][2] <= lclk_aln.dat[1][0];
                    lclk_map.wr[1][2] <= 1;
                end

                // R9
                else if ((lclk_map.cnt[1][0] == 'd6) && lclk_aln.wr[1][0])
                begin
                    lclk_map.dat[1][2] <= lclk_aln.dat[1][0];
                    lclk_map.wr[1][2] <= 1;
                end

                // G13
                else if ((lclk_map.cnt[1][1] == 'd9) && lclk_aln.wr[1][1])
                begin
                    lclk_map.dat[1][2] <= lclk_aln.dat[1][1];
                    lclk_map.wr[1][2] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[1][2] <= 0;
                    lclk_map.wr[1][2] <= 0;
                end

            // Stripe 7

                // R5
                if ((lclk_map.cnt[1][0] == 'd3) && lclk_aln.wr[1][0])
                begin
                    lclk_map.dat[1][3] <= lclk_aln.dat[1][0];
                    lclk_map.wr[1][3] <= 1;
                end

                // G9
                else if ((lclk_map.cnt[1][1] == 'd6) && lclk_aln.wr[1][1])
                begin
                    lclk_map.dat[1][3] <= lclk_aln.dat[1][1];
                    lclk_map.wr[1][3] <= 1;
                end

                // B13
                else if ((lclk_map.cnt[1][0] == 'd10) && lclk_aln.wr[1][0])
                begin
                    lclk_map.dat[1][3] <= lclk_aln.dat[1][0];
                    lclk_map.wr[1][3] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[1][3] <= 0;
                    lclk_map.wr[1][3] <= 0;
                end

            // Stripe 8

                // R2
                if ((lclk_map.cnt[0][1] == 'd1) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[2][0] <= lclk_aln.dat[0][1];
                    lclk_map.wr[2][0] <= 1;
                end

                // G6
                else if ((lclk_map.cnt[0][0] == 'd5) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[2][0] <= lclk_aln.dat[0][0];
                    lclk_map.wr[2][0] <= 1;
                end

                // B10
                else if ((lclk_map.cnt[0][1] == 'd8) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[2][0] <= lclk_aln.dat[0][1];
                    lclk_map.wr[2][0] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[2][0] <= 0;
                    lclk_map.wr[2][0] <= 0;
                end

            // Stripe 9

                // G2
                if ((lclk_map.cnt[0][0] == 'd2) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[2][1] <= lclk_aln.dat[0][0];
                    lclk_map.wr[2][1] <= 1;
                end

                // B6
                else if ((lclk_map.cnt[0][1] == 'd5) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[2][1] <= lclk_aln.dat[0][1];
                    lclk_map.wr[2][1] <= 1;
                end

                // R14
                else if ((lclk_map.cnt[0][1] == 'd10) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[2][1] <= lclk_aln.dat[0][1];
                    lclk_map.wr[2][1] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[2][1] <= 0;
                    lclk_map.wr[2][1] <= 0;
                end

            // Stripe 10

                // B2
                if ((lclk_map.cnt[0][1] == 'd2) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[2][2] <= lclk_aln.dat[0][1];
                    lclk_map.wr[2][2] <= 1;
                end

                // R10
                else if ((lclk_map.cnt[0][1] == 'd7) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[2][2] <= lclk_aln.dat[0][1];
                    lclk_map.wr[2][2] <= 1;
                end

                // G14
                else if ((lclk_map.cnt[0][0] == 'd11) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[2][2] <= lclk_aln.dat[0][0];
                    lclk_map.wr[2][2] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[2][2] <= 0;
                    lclk_map.wr[2][2] <= 0;
                end

            // Stripe 11

                // R6
                if ((lclk_map.cnt[0][1] == 'd4) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[2][3] <= lclk_aln.dat[0][1];
                    lclk_map.wr[2][3] <= 1;
                end

                // G10
                else if ((lclk_map.cnt[0][0] == 'd8) && lclk_aln.wr[0][0])
                begin
                    lclk_map.dat[2][3] <= lclk_aln.dat[0][0];
                    lclk_map.wr[2][3] <= 1;
                end

                // B14
                else if ((lclk_map.cnt[0][1] == 'd11) && lclk_aln.wr[0][1])
                begin
                    lclk_map.dat[2][3] <= lclk_aln.dat[0][1];
                    lclk_map.wr[2][3] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[2][3] <= 0;
                    lclk_map.wr[2][3] <= 0;
                end

            // Stripe 12

                // R3
                if ((lclk_map.cnt[1][1] == 'd1) && lclk_aln.wr[1][1])
                begin
                    lclk_map.dat[3][0] <= lclk_aln.dat[1][1];
                    lclk_map.wr[3][0] <= 1;
                end

                // G7
                else if ((lclk_map.cnt[1][0] == 'd5) && lclk_aln.wr[1][0])
                begin
                    lclk_map.dat[3][0] <= lclk_aln.dat[1][0];
                    lclk_map.wr[3][0] <= 1;
                end

                // B11
                else if ((lclk_map.cnt[1][1] == 'd8) && lclk_aln.wr[1][1])
                begin
                    lclk_map.dat[3][0] <= lclk_aln.dat[1][1];
                    lclk_map.wr[3][0] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[3][0] <= 0;
                    lclk_map.wr[3][0] <= 0;
                end

            // Stripe 13

                // G3
                if ((lclk_map.cnt[1][0] == 'd2) && lclk_aln.wr[1][0])
                begin
                    lclk_map.dat[3][1] <= lclk_aln.dat[1][0];
                    lclk_map.wr[3][1] <= 1;
                end

                // B7
                else if ((lclk_map.cnt[1][1] == 'd5) && lclk_aln.wr[1][1])
                begin
                    lclk_map.dat[3][1] <= lclk_aln.dat[1][1];
                    lclk_map.wr[3][1] <= 1;
                end

                // R15
                else if ((lclk_map.cnt[1][1] == 'd10) && lclk_aln.wr[1][1])
                begin
                    lclk_map.dat[3][1] <= lclk_aln.dat[1][1];
                    lclk_map.wr[3][1] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[3][1] <= 0;
                    lclk_map.wr[3][1] <= 0;
                end

            // Stripe 14

                // B3
                if ((lclk_map.cnt[1][1] == 'd2) && lclk_aln.wr[1][1])
                begin
                    lclk_map.dat[3][2] <= lclk_aln.dat[1][1];
                    lclk_map.wr[3][2] <= 1;
                end

                // R11
                else if ((lclk_map.cnt[1][1] == 'd7) && lclk_aln.wr[1][1])
                begin
                    lclk_map.dat[3][2] <= lclk_aln.dat[1][1];
                    lclk_map.wr[3][2] <= 1;
                end

                // G15
                else if ((lclk_map.cnt[1][0] == 'd11) && lclk_aln.wr[1][0])
                begin
                    lclk_map.dat[3][2] <= lclk_aln.dat[1][0];
                    lclk_map.wr[3][2] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[3][2] <= 0;
                    lclk_map.wr[3][2] <= 0;
                end

            // Stripe 15

                // R7
                if ((lclk_map.cnt[1][1] == 'd4) && lclk_aln.wr[1][1])
                begin
                    lclk_map.dat[3][3] <= lclk_aln.dat[1][1];
                    lclk_map.wr[3][3] <= 1;
                end

                // G11
                else if ((lclk_map.cnt[1][0] == 'd8) && lclk_aln.wr[1][0])
                begin
                    lclk_map.dat[3][3] <= lclk_aln.dat[1][0];
                    lclk_map.wr[3][3] <= 1;
                end

                // B15
                else if ((lclk_map.cnt[1][1] == 'd11) && lclk_aln.wr[1][1])
                begin
                    lclk_map.dat[3][3] <= lclk_aln.dat[1][1];
                    lclk_map.wr[3][3] <= 1;
                end

                // Idle
                else
                begin
                    lclk_map.dat[3][3] <= 0;
                    lclk_map.wr[3][3] <= 0;
                end
            end

            // 4 lanes
            else
            begin
                for (int i = 0; i < P_LANES; i++)
                begin
                    for (int j = 0; j < P_SPL; j++)
                    begin
                        // lower sublane
                        if ((lclk_map.cnt[i][j] == 'd0) && lclk_aln.wr[i][j])
                        begin
                            lclk_map.dat[i][j] <= lclk_aln.dat[i][j];
                            lclk_map.wr[i][j] <= 1;
                        end

                        // Upper sublane
                        else if ((lclk_map.cnt[i][j] == 'd1) && lclk_aln.wr[i][j])
                        begin
                            lclk_map.dat[i][j+2] <= lclk_aln.dat[i][j];
                            lclk_map.wr[i][j+2] <= 1;
                        end
                    end
                end
            end
        end
    end 
endgenerate

// FIFO last
// The FIFO last signal indicates that the last data has been written in the FIFO.
// This information is used by the FIFO module to store the last head counter.
// Preventing invalid level information during clearing at the begin of a new line. 
// To compensate for the alignment and mapping latency, the last signal must be delayed.
    always_ff @ (posedge LNK_CLK_IN)
    begin
        lclk_fifo.last_pipe <= {lclk_fifo.last_pipe[0+:$high(lclk_fifo.last_pipe)], lclk_lnk.stp_re};
    end
    assign  lclk_fifo.last = lclk_fifo.last_pipe[$high(lclk_fifo.last_pipe)];

/*
    FIFO
*/

    prt_dprx_vid_fifo
    #(
        .P_VENDOR           (P_VENDOR),             // Vendor
        .P_SIM              (P_SIM),                // Simulation
        .P_FIFO_WRDS        (P_FIFO_WRDS),          // FIFO words
        .P_LANES            (P_LANES),              // Lanes
        .P_SEGMENTS         (P_FIFO_SEGMENTS),      // Segments
        .P_STRIPES          (P_FIFO_STRIPES)        // Stripes
    )
    FIFO_INST
    (
        // Link port
        .LNK_RST_IN     (LNK_RST_IN),               // Reset
        .LNK_CLK_IN     (LNK_CLK_IN),               // Clock
        .LNK_CLR_IN     (lclk_fifo.clr),            // Clear
        .LNK_DAT_IN     (lclk_map.dat),             // Data
        .LNK_WR_IN      (lclk_map.wr),              // Write
        .LNK_LAST_IN    (lclk_fifo.last),           // Last

        // Video port
        .VID_RST_IN     (VID_RST_IN),               // Reset
        .VID_CLK_IN     (VID_CLK_IN),               // Clock
        .VID_CLR_IN     (vclk_fifo.clr),            // Clear
        .VID_RD_IN      (vclk_map.rd),              // Read
        .VID_DAT_OUT    (vclk_fifo.dout),           // Data
        .VID_DE_OUT     (vclk_fifo.de),             // Data enable
        .VID_LVL_OUT    (vclk_fifo.lvl)             // Level
    );

    assign lclk_fifo.clr = lclk_lnk.str;
    assign vclk_fifo.clr = vclk_vid.str;

/*
    Video domain
*/

// BPC clock domain crossing
    prt_dp_lib_cdc_bit
    VCLK_BPC_CDC_INST
    (
        .SRC_CLK_IN     (LNK_CLK_IN),       // Clock
        .SRC_DAT_IN     (lclk_ctl.bpc),    // Data
        .DST_CLK_IN     (VID_CLK_IN),       // Clock
        .DST_DAT_OUT    (vclk_ctl.bpc)     // Data
    );

// Start clock domain crossing
    prt_dp_lib_cdc_bit
    VCLK_STR_CDC_INST
    (
        .SRC_CLK_IN     (LNK_CLK_IN),           // Clock
        .SRC_DAT_IN     (lclk_lnk.str_toggle),  // Data
        .DST_CLK_IN     (VID_CLK_IN),           // Clock
        .DST_DAT_OUT    (vclk_vid.str_toggle)   // Data
    );

// Start of line edge detector
    prt_dp_lib_edge
    VCLK_STR_EDGE_INST
    (
        .CLK_IN    (VID_CLK_IN),            // Clock
        .CKE_IN    (1'b1),                  // Clock enable
        .A_IN      (vclk_vid.str_toggle),   // Input
        .RE_OUT    (vclk_vid.str_re),       // Rising edge
        .FE_OUT    (vclk_vid.str_fe)        // Falling edge
    );

// NVS clock domain crossing
    prt_dp_lib_cdc_bit
    VCLK_NVS_CDC_INST
    (
        .SRC_CLK_IN     (LNK_CLK_IN),      // Clock
        .SRC_DAT_IN     (lclk_lnk.nvs),    // Data
        .DST_CLK_IN     (VID_CLK_IN),      // Clock
        .DST_DAT_OUT    (vclk_vid.nvs)     // Data
    );

// VBF clock domain crossing
    prt_dp_lib_cdc_bit
    VCLK_VBF_CDC_INST
    (
        .SRC_CLK_IN     (LNK_CLK_IN),      // Clock
        .SRC_DAT_IN     (lclk_lnk.vbf),    // Data
        .DST_CLK_IN     (VID_CLK_IN),      // Clock
        .DST_DAT_OUT    (vclk_vid.vbf)     // Data
    );

// Message Slave
    prt_dp_msg_slv_egr
    #(
        .P_ID           (P_MSG_ID),       // Identifier
        .P_IDX_WIDTH    (P_MSG_IDX),      // Index width
        .P_DAT_WIDTH    (P_MSG_DAT)       // Data width
    )
    VID_MSG_SLV_EGR_INST
    (
        // Reset and clock
        .RST_IN         (VID_RST_IN),
        .CLK_IN         (VID_CLK_IN),

        // MSG sink
        .MSG_SNK_IF     (MSG_SNK_IF),

        // MSG source
        .MSG_SRC_IF     (MSG_SRC_IF),

        // Eggress
        .EGR_IDX_OUT    (vclk_msg.idx),    // Index
        .EGR_FIRST_OUT  (vclk_msg.first),  // First
        .EGR_LAST_OUT   (vclk_msg.last),   // Last
        .EGR_DAT_OUT    (vclk_msg.dat),    // Data
        .EGR_VLD_OUT    (vclk_msg.vld)     // Valid
    );

// Horizontal width (active pixels)
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Valid message
        if (vclk_msg.vld)
        begin
            // Load 
            if (vclk_msg.idx == 'd0)
                vclk_vid.hwidth <= vclk_msg.dat;
        end
    end

// Start of line 
// This signal is captured from the link domain
    always_ff @ (posedge VID_CLK_IN)
    begin
        vclk_vid.str <= vclk_vid.str_re || vclk_vid.str_fe;
    end

// Run
// At the start of a new line, the head value in the FIFO module is cleared. 
// There is a possible race condition between the head, tail and level values when this condition occurs. 
// To prevent a false reading of the level signal  
    always_ff @ (posedge VID_RST_IN, posedge VID_CLK_IN)
    begin
        // Reset
        if (VID_RST_IN)
        begin
            vclk_vid.run_pipe <= 0;
            vclk_vid.run <= 0;
        end

        else
        begin
            // Clear at end-of-line
            if (vclk_vid.eol)
            begin
                vclk_vid.run_pipe <= 0;
                vclk_vid.run <= 0;
            end

            // Set
            else if (vclk_vid.str)
            begin
                vclk_vid.run_pipe <= 8'h1;
                vclk_vid.run <= 0;
            end

            else
            begin
                vclk_vid.run_pipe[$high(vclk_vid.run_pipe):1] <= vclk_vid.run_pipe[$high(vclk_vid.run_pipe)-1:0];
                vclk_vid.run <= vclk_vid.run_pipe[$high(vclk_vid.run_pipe)];
            end
        end
    end

/*
    Mapper
*/
    prt_dprx_vid_vmap
    #(
        // Video
        .P_PPC          (P_PPC),                // Pixels per clock
        .P_BPC          (P_BPC),                // Bits per component
        .P_LANES        (P_LANES),              // Lanes
        .P_SEGMENTS     (P_FIFO_SEGMENTS),      // Segments
        .P_STRIPES      (P_FIFO_STRIPES),       // Stripes
        .P_VID_DAT      (P_VID_DAT)		        // AXIS data width
    )
    VMAP_INST
    (
        .RST_IN         (VID_RST_IN),           // Reset
        .CLK_IN         (VID_CLK_IN),           // Clock

        // Control
        .CFG_BPC_IN     (vclk_ctl.bpc),         // Active bits-per-component

        // Mapper
        .MAP_RUN_IN     (vclk_vid.run),         // Run
        .MAP_LVL_IN     (vclk_fifo.lvl),        // Level
        .MAP_RD_OUT     (vclk_map.rd),          // Read
        .MAP_DAT_IN     (vclk_fifo.dout),       // Data
        .MAP_DE_IN      (vclk_fifo.de),         // Data enable

        // Video
        .VID_DAT_OUT    (vclk_map.dat),         // Video data
        .VID_VLD_OUT    (vclk_map.vld)          // Video valid
    );


/*
    Video
*/

// Vertical blanking flag detector
    prt_dp_lib_edge
    VBF_EDGE_INST
    (
        .CLK_IN    (VID_CLK_IN),        // Clock
        .CKE_IN    (1'b1),              // Clock enable
        .A_IN      (vclk_vid.vbf),      // Input
        .RE_OUT    (vclk_vid.vbf_re),   // Rising edge
        .FE_OUT    ()                   // Falling edge
    );

// Vertical blanking flag sticky
// A source device may clear this flag immediately after the first active line or prior the first active line.
// The vbf flag is used to generate the sof signal.
// This flag remains asserted till the sof signal has been generated.
// See VB-ID definition on page 50 of the DisplayPort 1.2 spec.
// The vertical blanking flag rising edge occurs during the blanking 
// and for the first frame the video reset might be still active. 
// Therefore don't reset this flag. 
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Clear
        if (vclk_vid.sof)
            vclk_vid.vbf_sticky <= 0;

        // Set 
        else if (vclk_vid.vbf_re)
            vclk_vid.vbf_sticky <= 1;
    end

// Horizontal counter
// This is used to generate the end-of-line signal
    always_ff @ (posedge VID_RST_IN, posedge VID_CLK_IN)
    begin
        // Reset
        if (VID_RST_IN)
            vclk_vid.hwidth_cnt <= 0;

        else
        begin
            // Clear at start of line
            if (vclk_vid.str)
                vclk_vid.hwidth_cnt <= 0;

            // Increment
            else if (vclk_map.vld)
                vclk_vid.hwidth_cnt <= vclk_vid.hwidth_cnt + P_PPC;
        end
    end

// Video data
    always_ff @ (posedge VID_CLK_IN)
    begin
  		vclk_vid.dat <= vclk_map.dat;
    end

// Video valid
    always_ff @ (posedge VID_CLK_IN)
    begin
        vclk_vid.vld <= vclk_map.vld;
    end

// Start of frame
    always_ff @ (posedge VID_RST_IN, posedge VID_CLK_IN)
    begin
        // Reset
        if (VID_RST_IN)
            vclk_vid.sof <= 0;
        
        else
        begin
            // Clear
            // When the first video data is transmitted
            if (vclk_vid.vld)
                vclk_vid.sof <= 0;
        
            // Set
            // When at the start of line when the vertical blanking flag is asserted
            else if (vclk_vid.str && vclk_vid.vbf_sticky)
                vclk_vid.sof <= 1;
        end
    end

// End of line
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Default
        vclk_vid.eol <= 0;

        // Run
        if (vclk_vid.run)
        begin
            if (vclk_vid.hwidth_cnt == vclk_vid.hwidth - P_PPC)
                vclk_vid.eol <= 1;
        end
    end

// Outputs
    // Link
    assign LNK_VBID_OUT     = lclk_lnk.vbid_val;   // VB-ID

    // Video source
    assign VID_EN_OUT       = ~vclk_vid.nvs;       // Enable
    assign VID_SRC_IF.sof   = vclk_vid.sof;        // Start of frame
    assign VID_SRC_IF.eol   = vclk_vid.eol;        // End of line
    assign VID_SRC_IF.dat   = vclk_vid.dat;        // Data
    assign VID_SRC_IF.vld   = vclk_vid.vld;        // Valid

endmodule

`default_nettype wire
