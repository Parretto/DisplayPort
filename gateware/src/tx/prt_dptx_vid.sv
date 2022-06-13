/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP TX Video
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

module prt_dptx_vid
#(
    // Link
    parameter               P_LANES = 4,    // Lanes
    parameter               P_SPL = 2,      // Symbols per lane

    // Video
    parameter               P_PPC = 2,      // Pixels per clock
    parameter               P_BPC = 8,      // Bits per component

    // Message
    parameter               P_MSG_IDX     = 5,          // Message index width
    parameter               P_MSG_DAT     = 16,         // Message data width
    parameter               P_MSG_ID_MSA  = 0           // Message ID main stream attributes
)
(
    // Control
    input wire              CTL_LANES_IN,       // Active lanes (0 - 2 lanes / 1 - 4 lanes)
    input wire              CTL_EN_IN,          // Enable

    // Video message
    prt_dp_msg_if.snk       VID_MSG_SNK_IF,     // Sink
    prt_dp_msg_if.src       VID_MSG_SRC_IF,     // Source

    // Video 
    input wire              VID_RST_IN,         // Video reset
    input wire              VID_CLK_IN,         // Video clock
    input wire              VID_CKE_IN,         // Video clock enable
    prt_dp_vid_if.snk       VID_SNK_IF,         // Sink

    // Link 
    input wire              LNK_RST_IN,         // Link reset
    input wire              LNK_CLK_IN,         // Link clock
    prt_dp_tx_lnk_if.src    LNK_SRC_IF,         // Source
    output wire             LNK_VS_OUT,         // Vsync (required by MSA)
    output wire             LNK_VBF_OUT,        // Vertical blanking flag (required by MSA)
    output wire             LNK_BS_OUT          // Blanking start
);

// Package
import prt_dp_pkg::*;

// Parameters
localparam P_FIFO_WRDS = 64;
localparam P_FIFO_ADR = $clog2(P_FIFO_WRDS);
localparam P_FIFO_DAT = 9;
localparam P_FIFO_STRIPES = 4;
localparam P_TU_SIZE = 64;

// Structures
typedef struct {
    logic                           lanes;    // Active link lanes (0 - 2 lanes / 1 - 4 lanes)
    logic                           en;       // Enable
    logic                           run;      // Run
    logic                           vs;
    logic                           vs_re;
    logic                           hs;
    logic                           hs_re;
    logic                           de;
    logic                           de_re;
    logic                           de_fe;
    logic [(P_PPC * P_BPC)-1:0]     dat[0:2];
    logic [15:0]                    hstart;   // Horizontal start. The start of the active pixels from the hsync leading edge
    logic [15:0]                    hwidth;   // Horizontal width. Number of active pixels in a line
    logic [15:0]                    vheight;  // Vertical heigth. This is the active number of lines 
    logic [15:0]                    pix_cnt;  // Pixel counter
    logic [15:0]                    lin_cnt;  // Line counter
    logic                           vbf;      // Vertical blanking flag
    logic                           bs;       // Blanking start
    logic                           vde;      // Virtual data enable
    logic                           vde_re;
    logic                           vde_re_del;
    logic                           vde_fe;
    logic                           act;           // Active line
    logic                           blnk;          // Blanking line
} vid_struct;

typedef struct {
    logic   [2:0]                   sel;
    logic   [P_FIFO_DAT-1:0]        dat[0:P_LANES-1][0:P_FIFO_STRIPES-1];
    logic   [P_FIFO_STRIPES-1:0]    wr[0:P_LANES-1];
} map_struct;

typedef struct {
    logic	[P_FIFO_DAT-1:0]        din[0:P_LANES-1][0:P_FIFO_STRIPES-1];
    logic   [P_FIFO_STRIPES-1:0]    wr[0:P_LANES-1];
    logic   [P_FIFO_ADR:0]          wrds[0:P_LANES-1][0:P_FIFO_STRIPES-1];
    logic   [P_FIFO_STRIPES-1:0]    ep[0:P_LANES-1];
    logic   [P_FIFO_STRIPES-1:0]    fl[0:P_LANES-1];
} vid_fifo_struct;

typedef struct {
    logic   [P_FIFO_STRIPES-1:0]    rd[0:P_LANES-1];
    logic   [P_FIFO_DAT-1:0]        dout[0:P_LANES-1][0:P_FIFO_STRIPES-1];
    logic   [P_FIFO_STRIPES-1:0]    de[0:P_LANES-1];
    logic   [P_FIFO_ADR:0]          wrds[0:P_LANES-1][0:P_FIFO_STRIPES-1];
    logic   [P_FIFO_STRIPES-1:0]    ep[0:P_LANES-1];
    logic   [P_FIFO_STRIPES-1:0]    fl[0:P_LANES-1];
} lnk_fifo_struct;

typedef struct {
    logic                           vs;
    logic                           hs;
    logic                           hs_re;
    logic                           vbf;      // Vertical blanking flag
    logic                           act;
    logic                           act_re;
    logic                           act_evt;
    logic                           blnk;
    logic                           blnk_re;
    logic                           blnk_evt;
    logic                           blnk_evt_clr;
} lnk_vid_struct;

typedef struct {
    logic                           lanes;          // Active lanes (0 - 2 lanes / 1 - 4 lanes)
    logic                           en;             // Enable
    logic                           bs;             // Blanking start 
    logic                           fifo_de;        // Combined data enable
    logic                           fifo_de_fe;
    logic [P_FIFO_ADR+1:0]          fifo_wrds;      // FIFO words
    logic                           fifo_rdy;       // FIFO ready
    logic [6:0]                     vu_len;         // Video unit length in a TU
    logic                           tu_run;
    logic                           tu_run_re;
    logic [6:0]                     tu_cnt;         // Transfer unit counter
    logic                           tu_cnt_last;
    logic                           tu_cnt_end;
    logic [6:0]                     vu_rd_cnt;      // Video unit read counter
    logic                           vu_rd_cnt_end;
    logic [6:0]                     vu_de_cnt;      // Video unit de counter
    logic                           vu_de_cnt_last;
    logic                           vu_de_cnt_end;
    logic [2:0]                     ins_be;
    logic                           vu_sel;                         // Video unit select
    logic [7:0]                     vu_dat[0:P_LANES-1][0:P_SPL-1]; // Video unit data
    logic [P_SPL-1:0]               k[0:P_LANES-1];
    logic [7:0]                     dat[0:P_LANES-1][0:P_SPL-1];
} lnk_struct;

typedef struct {
    logic   [P_MSG_IDX-1:0]         idx;
    logic                           first;
    logic                           last;
    logic   [P_MSG_DAT-1:0]         dat;
    logic                           vld;
} msg_struct;

// Signals
msg_struct          vclk_msg;
vid_struct          vclk_vid;
map_struct          vclk_map;
vid_fifo_struct     vclk_fifo;
lnk_fifo_struct     lclk_fifo;
lnk_vid_struct      lclk_vid;
lnk_struct          lclk_lnk;

genvar i, j;

// Logic

/*
    Video domain
*/

// Control lanes clock domain crossing
    prt_dp_lib_cdc_bit
    VCLK_LANES_CDC_INST
    (
        .SRC_CLK_IN     (LNK_CLK_IN),       // Clock
        .SRC_DAT_IN     (lclk_lnk.lanes),   // Data
        .DST_CLK_IN     (VID_CLK_IN),       // Clock
        .DST_DAT_OUT    (vclk_vid.lanes)    // Data
    );

// Control Enable clock domain crossing
    prt_dp_lib_cdc_bit
    VCLK_EN_CDC_INST
    (
        .SRC_CLK_IN     (LNK_CLK_IN),       // Clock
        .SRC_DAT_IN     (lclk_lnk.en),      // Data
        .DST_CLK_IN     (VID_CLK_IN),       // Clock
        .DST_DAT_OUT    (vclk_vid.en)       // Data
    );

// Message Slave
    prt_dp_msg_slv_egr
    #(
        .P_ID           (P_MSG_ID_MSA),   // Identifier
        .P_IDX_WIDTH    (P_MSG_IDX),      // Index width
        .P_DAT_WIDTH    (P_MSG_DAT)       // Data width
    )
    VID_MSG_SLV_EGR_INST
    (
        // Reset and clock
        .RST_IN         (VID_RST_IN),
        .CLK_IN         (VID_CLK_IN),

        // MSG sink
        .MSG_SNK_IF     (VID_MSG_SNK_IF),

        // MSG source
        .MSG_SRC_IF     (VID_MSG_SRC_IF),

        // Eggress
        .EGR_IDX_OUT    (vclk_msg.idx),    // Index
        .EGR_FIRST_OUT  (vclk_msg.first),  // First
        .EGR_LAST_OUT   (vclk_msg.last),   // Last
        .EGR_DAT_OUT    (vclk_msg.dat),    // Data
        .EGR_VLD_OUT    (vclk_msg.vld)     // Valid
    );

// Video input registers
// The video inputs are registered to improve the timing.
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Clock enable
        if (VID_CKE_IN)
        begin
            vclk_vid.vs <= VID_SNK_IF.vs;
            vclk_vid.hs <= VID_SNK_IF.hs;
            vclk_vid.de <= VID_SNK_IF.de;

            for (int i = 0; i < 3; i++)
                vclk_vid.dat[i] <= VID_SNK_IF.dat[i];
        end
    end

// Vsync edge detector
// This is used for start of frame
    prt_dp_lib_edge
    VCLK_VS_EDGE_INST
    (
        .CLK_IN    (VID_CLK_IN),        // Clock
        .CKE_IN    (VID_CKE_IN),        // Clock enable
        .A_IN      (vclk_vid.vs),       // Input
        .RE_OUT    (vclk_vid.vs_re),    // Rising edge
        .FE_OUT    ()                   // Falling edge
    );

// Hsync edge detector
// This is used for blanking start
    prt_dp_lib_edge
    VCLK_HS_EDGE_INST
    (
        .CLK_IN    (VID_CLK_IN),        // Clock
        .CKE_IN    (VID_CKE_IN),        // Clock enable
        .A_IN      (vclk_vid.hs),       // Input
        .RE_OUT    (vclk_vid.hs_re),    // Rising edge
        .FE_OUT    ()                   // Falling edge
    );

// Data enable edge detector
// This is used for active line counter
    prt_dp_lib_edge
    VCLK_DE_EDGE_INST
    (
        .CLK_IN    (VID_CLK_IN),        // Clock
        .CKE_IN    (VID_CKE_IN),        // Clock enable
        .A_IN      (vclk_vid.de),       // Input
        .RE_OUT    (vclk_vid.de_re),    // Rising edge
        .FE_OUT    (vclk_vid.de_fe)     // Falling edge
    );

// Run
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Enable
        if (vclk_vid.en)
        begin
            // Wait for start of frame
            if (vclk_vid.vs_re)
                vclk_vid.run <= 1;
        end

        // Idle
        else
            vclk_vid.run <= 0;
    end

// Horizontal start (start of active video from leading edge hsync)
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Valid message
        if (vclk_msg.vld)
        begin
            // Load upper byte
            if ( (vclk_vid.lanes && (vclk_msg.idx == 'd21)) || (!vclk_vid.lanes && (vclk_msg.idx == 'd11)) )
                vclk_vid.hstart[15:8] <= vclk_msg.dat[0+:8];

            // Load lower byte
            else if ( (vclk_vid.lanes && (vclk_msg.idx == 'd25)) || (!vclk_vid.lanes && (vclk_msg.idx == 'd13)) )
                vclk_vid.hstart[7:0] <= vclk_msg.dat[0+:8];
        end
    end

// Horizontal width (active pixels)
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Valid message
        if (vclk_msg.vld)
        begin
            // Load upper byte
            if ( (vclk_vid.lanes && (vclk_msg.idx == 'd22)) || (!vclk_vid.lanes && (vclk_msg.idx == 'd28)) )
                vclk_vid.hwidth[15:8] <= vclk_msg.dat[0+:8];

            // Load lower byte
            else if ( (vclk_vid.lanes && (vclk_msg.idx == 'd26)) || (!vclk_vid.lanes && (vclk_msg.idx == 'd30)) )
                vclk_vid.hwidth[7:0] <= vclk_msg.dat[0+:8];
        end
    end

// Vertical height (active lines)
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Valid message
        if (vclk_msg.vld)
        begin
            // Load upper byte
            if ( (vclk_vid.lanes && (vclk_msg.idx == 'd30)) || (!vclk_vid.lanes && (vclk_msg.idx == 'd32)) )
                vclk_vid.vheight[15:8] <= vclk_msg.dat[0+:8];

            // Load lower byte
            else if ( (vclk_vid.lanes && (vclk_msg.idx == 'd34)) || (!vclk_vid.lanes && (vclk_msg.idx == 'd34)) )
                vclk_vid.vheight[7:0] <= vclk_msg.dat[0+:8];
        end
    end

// Pixel counter
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Run
        if (vclk_vid.run)
        begin
            // Clock enable
            if (VID_CKE_IN)
            begin
                // Clear
                if (vclk_vid.hs_re)
                    vclk_vid.pix_cnt <= 0;

                // Increment (prevent from overflowing)
                else if (!(&vclk_vid.pix_cnt))
                    vclk_vid.pix_cnt <= vclk_vid.pix_cnt + P_PPC;
            end
        end

        // Idle
        else
            vclk_vid.pix_cnt <= 0;
    end

// Line counter
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Run
        if (vclk_vid.run)
        begin
            // Clock enable
            if (VID_CKE_IN)
            begin
                // Clear
                if (vclk_vid.vs_re)
                    vclk_vid.lin_cnt <= 0;

                // Increment 
                else if (vclk_vid.de_fe)
                    vclk_vid.lin_cnt <= vclk_vid.lin_cnt + 'd1;
            end
        end

        // Idle
        else
            vclk_vid.lin_cnt <= 0;
    end

// Vertical blanking flag
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Run
        if (vclk_vid.run)
        begin
            // Clock enable
            if (VID_CKE_IN)
            begin
                // Clear
                if (vclk_vid.vs_re || (vclk_vid.lin_cnt == vclk_vid.vheight))
                    vclk_vid.vbf <= 1;

                // Set
                else if (vclk_vid.de_re)
                    vclk_vid.vbf <= 0;
            end
        end

        // Idle
        else
            vclk_vid.vbf <= 1;
    end

// Blanking start
// This flag is asserted at the end of an active line.
// It is used to generate the blanking start symbol in the link domain.
// This flag is also generated during horizontal blanking.
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Clock enable
        if (VID_CKE_IN)
        begin
            if (vclk_vid.pix_cnt == (vclk_vid.hstart + vclk_vid.hwidth - (3 * P_PPC)))
                vclk_vid.bs <= 1;
            else
                vclk_vid.bs <= 0;
        end
    end

// Virtual data enable
// In order to have the same latency of the insertion of the blanking end symbol
// from the hsync edge during an active line and blanking line
// video data is always written into the FIFO's.
// This process will generate the virtual data enable,
// which is exactly the same signal as the input video data enable.
// However this virtual signal is always active even during a blanking line.
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Run
        if (vclk_vid.run)
        begin
            // Clock enable
            if (VID_CKE_IN)
            begin
                // Clear
                if (vclk_vid.pix_cnt == (vclk_vid.hstart + vclk_vid.hwidth - (2 * P_PPC)))
                    vclk_vid.vde <= 0;

                // Set
                else if (vclk_vid.pix_cnt == (vclk_vid.hstart  - (2 * P_PPC)))
                    vclk_vid.vde <= 1;
            end
        end

        else
            vclk_vid.vde <= 0;
    end

// Virtual data enable edge detector
// This is used for blanking end
    prt_dp_lib_edge
    VCLK_VDE_EDGE_INST
    (
        .CLK_IN    (VID_CLK_IN),         // Clock
        .CKE_IN    (VID_CKE_IN),         // Clock enable
        .A_IN      (vclk_vid.vde),       // Input
        .RE_OUT    (vclk_vid.vde_re),    // Rising edge
        .FE_OUT    (vclk_vid.vde_fe)     // Falling edge
    );

// Virtual data enable rising edge delayed
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Clock enable
        if (VID_CKE_IN)
            vclk_vid.vde_re_del <= vclk_vid.vde_re;
    end

// Video active & blanking event
// These flags are activated at the start of a video line
// and use by the state machine in the link domain to start reading the FIFO's.
// The active line is asserted when there is an active video line indicated
// by the assertion of the inputs data enable.
// The blanking flag is also asserted at the start of a video line.
// However in this case there is no actual real video data,
// but dummy video data is written in the FIFO's.
// When the active signal is asserted,
// the link state machine will insert a blanking end symbol and
// then start reading the FIFO data.
// If the blanking signal is asserted, then the link state machine
// starts reading the FIFO data immediately.
// Per video line only one of the two signals can be active.
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Run
        if (vclk_vid.run)
        begin
            // Clock enable
            if (VID_CKE_IN)
            begin
                // Clear
                if (vclk_vid.vde_fe)
                begin
                    vclk_vid.act <= 0;
                    vclk_vid.blnk <= 0;
                end

                // Check for when an active line should be beginning
                // The rising edge must be delayed to match the data enable latency
                else if (vclk_vid.vde_re_del)
                begin
                    // Is the data enable asserted?
                    if (vclk_vid.de)
                        vclk_vid.act <= 1;
                    else
                        vclk_vid.blnk <= 1;
                end
            end
        end

        // Idle
        else
        begin
            vclk_vid.act <= 0;
            vclk_vid.blnk <= 0;
        end
    end

/*
    Mapper
*/

// Select
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Run
        if (vclk_vid.run)
        begin
            // Clock enable
            if (VID_CKE_IN)
            begin
                // Clear on hsync
                if (vclk_vid.hs_re)
                    vclk_map.sel <= 0;

                // Increment
                else if (vclk_vid.vde)
                begin
                    // Clear
                    if (((P_PPC == 4) && (vclk_map.sel == 'd3)) || ((P_PPC == 2) && (vclk_map.sel == 'd7)))
                        vclk_map.sel <= 0;
                    else
                        vclk_map.sel <= vclk_map.sel + 'd1;
                end
            end
        end

        else
            vclk_map.sel <= 0;
    end

// Data
generate
    // Four pixels per clock
    if (P_PPC == 4)
    begin : gen_map_dat_4ppc
        always_comb
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                for (int j = 0; j < P_FIFO_STRIPES; j++)
                begin
                    vclk_map.wr[i][j] = 0;
                    vclk_map.dat[i][j] = 0;
                end
            end

            case (vclk_map.sel)
                'd1 : 
                begin
                    vclk_map.dat[0][3] = {1'b0, vclk_vid.dat[0][(0*P_BPC)+:P_BPC]};   // R4
                    vclk_map.dat[0][0] = {1'b0, vclk_vid.dat[1][(0*P_BPC)+:P_BPC]};   // G4
                    vclk_map.dat[0][1] = {1'b0, vclk_vid.dat[2][(0*P_BPC)+:P_BPC]};   // B4
                    vclk_map.dat[1][3] = {1'b0, vclk_vid.dat[0][(1*P_BPC)+:P_BPC]};   // R5
                    vclk_map.dat[1][0] = {1'b0, vclk_vid.dat[1][(1*P_BPC)+:P_BPC]};   // G5
                    vclk_map.dat[1][1] = {1'b0, vclk_vid.dat[2][(1*P_BPC)+:P_BPC]};   // B5
                    vclk_map.dat[2][3] = {1'b0, vclk_vid.dat[0][(2*P_BPC)+:P_BPC]};   // R6
                    vclk_map.dat[2][0] = {1'b0, vclk_vid.dat[1][(2*P_BPC)+:P_BPC]};   // G6
                    vclk_map.dat[2][1] = {1'b0, vclk_vid.dat[2][(2*P_BPC)+:P_BPC]};   // B6
                    vclk_map.dat[3][3] = {1'b0, vclk_vid.dat[0][(3*P_BPC)+:P_BPC]};   // R7
                    vclk_map.dat[3][0] = {1'b0, vclk_vid.dat[1][(3*P_BPC)+:P_BPC]};   // G7
                    vclk_map.dat[3][1] = {1'b0, vclk_vid.dat[2][(3*P_BPC)+:P_BPC]};   // B7

                    vclk_map.wr[0][3] = 1;
                    vclk_map.wr[0][0] = 1;
                    vclk_map.wr[0][1] = 1;
                    vclk_map.wr[1][3] = 1;
                    vclk_map.wr[1][0] = 1;                
                    vclk_map.wr[1][1] = 1;                
                    vclk_map.wr[2][3] = 1;
                    vclk_map.wr[2][0] = 1;
                    vclk_map.wr[2][1] = 1;
                    vclk_map.wr[3][3] = 1;
                    vclk_map.wr[3][0] = 1;                
                    vclk_map.wr[3][1] = 1;                
                end

                'd2 : 
                begin
                    vclk_map.dat[0][2] = {1'b0, vclk_vid.dat[0][(0*P_BPC)+:P_BPC]};   // R8
                    vclk_map.dat[0][3] = {1'b0, vclk_vid.dat[1][(0*P_BPC)+:P_BPC]};   // G8
                    vclk_map.dat[0][0] = {1'b0, vclk_vid.dat[2][(0*P_BPC)+:P_BPC]};   // B8
                    vclk_map.dat[1][2] = {1'b0, vclk_vid.dat[0][(1*P_BPC)+:P_BPC]};   // R9
                    vclk_map.dat[1][3] = {1'b0, vclk_vid.dat[1][(1*P_BPC)+:P_BPC]};   // G9
                    vclk_map.dat[1][0] = {1'b0, vclk_vid.dat[2][(1*P_BPC)+:P_BPC]};   // B9
                    vclk_map.dat[2][2] = {1'b0, vclk_vid.dat[0][(2*P_BPC)+:P_BPC]};   // R10
                    vclk_map.dat[2][3] = {1'b0, vclk_vid.dat[1][(2*P_BPC)+:P_BPC]};   // G10
                    vclk_map.dat[2][0] = {1'b0, vclk_vid.dat[2][(2*P_BPC)+:P_BPC]};   // B10
                    vclk_map.dat[3][2] = {1'b0, vclk_vid.dat[0][(3*P_BPC)+:P_BPC]};   // R11
                    vclk_map.dat[3][3] = {1'b0, vclk_vid.dat[1][(3*P_BPC)+:P_BPC]};   // G11
                    vclk_map.dat[3][0] = {1'b0, vclk_vid.dat[2][(3*P_BPC)+:P_BPC]};   // B11

                    vclk_map.wr[0][2] = 1;
                    vclk_map.wr[0][3] = 1;
                    vclk_map.wr[0][0] = 1;
                    vclk_map.wr[1][2] = 1;
                    vclk_map.wr[1][3] = 1;                
                    vclk_map.wr[1][0] = 1;                
                    vclk_map.wr[2][2] = 1;
                    vclk_map.wr[2][3] = 1;
                    vclk_map.wr[2][0] = 1;
                    vclk_map.wr[3][2] = 1;
                    vclk_map.wr[3][3] = 1;                
                    vclk_map.wr[3][0] = 1;                
                end

                'd3 : 
                begin
                    vclk_map.dat[0][1] = {1'b0, vclk_vid.dat[0][(0*P_BPC)+:P_BPC]};   // R12
                    vclk_map.dat[0][2] = {1'b0, vclk_vid.dat[1][(0*P_BPC)+:P_BPC]};   // G12
                    vclk_map.dat[0][3] = {1'b0, vclk_vid.dat[2][(0*P_BPC)+:P_BPC]};   // B12
                    vclk_map.dat[1][1] = {1'b0, vclk_vid.dat[0][(1*P_BPC)+:P_BPC]};   // R13
                    vclk_map.dat[1][2] = {1'b0, vclk_vid.dat[1][(1*P_BPC)+:P_BPC]};   // G13
                    vclk_map.dat[1][3] = {1'b0, vclk_vid.dat[2][(1*P_BPC)+:P_BPC]};   // B13
                    vclk_map.dat[2][1] = {1'b0, vclk_vid.dat[0][(2*P_BPC)+:P_BPC]};   // R14
                    vclk_map.dat[2][2] = {1'b0, vclk_vid.dat[1][(2*P_BPC)+:P_BPC]};   // G14
                    vclk_map.dat[2][3] = {1'b0, vclk_vid.dat[2][(2*P_BPC)+:P_BPC]};   // B14
                    vclk_map.dat[3][1] = {1'b0, vclk_vid.dat[0][(3*P_BPC)+:P_BPC]};   // R15
                    vclk_map.dat[3][2] = {1'b0, vclk_vid.dat[1][(3*P_BPC)+:P_BPC]};   // G15
                    vclk_map.dat[3][3] = {vclk_vid.bs, vclk_vid.dat[2][(3*P_BPC)+:P_BPC]};   // B15
                    
                    vclk_map.wr[0][1] = 1;
                    vclk_map.wr[0][2] = 1;
                    vclk_map.wr[0][3] = 1;
                    vclk_map.wr[1][1] = 1;
                    vclk_map.wr[1][2] = 1;                
                    vclk_map.wr[1][3] = 1;                
                    vclk_map.wr[2][1] = 1;
                    vclk_map.wr[2][2] = 1;
                    vclk_map.wr[2][3] = 1;
                    vclk_map.wr[3][1] = 1;
                    vclk_map.wr[3][2] = 1;                
                    vclk_map.wr[3][3] = 1;                
                end

                default : 
                begin
                    vclk_map.dat[0][0] = {1'b0, vclk_vid.dat[0][(0*P_BPC)+:P_BPC]};   // R0
                    vclk_map.dat[0][1] = {1'b0, vclk_vid.dat[1][(0*P_BPC)+:P_BPC]};   // G0
                    vclk_map.dat[0][2] = {1'b0, vclk_vid.dat[2][(0*P_BPC)+:P_BPC]};   // B0
                    vclk_map.dat[1][0] = {1'b0, vclk_vid.dat[0][(1*P_BPC)+:P_BPC]};   // R1
                    vclk_map.dat[1][1] = {1'b0, vclk_vid.dat[1][(1*P_BPC)+:P_BPC]};   // G1
                    vclk_map.dat[1][2] = {1'b0, vclk_vid.dat[2][(1*P_BPC)+:P_BPC]};   // B1
                    vclk_map.dat[2][0] = {1'b0, vclk_vid.dat[0][(2*P_BPC)+:P_BPC]};   // R2
                    vclk_map.dat[2][1] = {1'b0, vclk_vid.dat[1][(2*P_BPC)+:P_BPC]};   // G2
                    vclk_map.dat[2][2] = {1'b0, vclk_vid.dat[2][(2*P_BPC)+:P_BPC]};   // B2
                    vclk_map.dat[3][0] = {1'b0, vclk_vid.dat[0][(3*P_BPC)+:P_BPC]};   // R3
                    vclk_map.dat[3][1] = {1'b0, vclk_vid.dat[1][(3*P_BPC)+:P_BPC]};   // G3
                    vclk_map.dat[3][2] = {1'b0, vclk_vid.dat[2][(3*P_BPC)+:P_BPC]};   // B3

                    vclk_map.wr[0][0] = 1;
                    vclk_map.wr[0][1] = 1;
                    vclk_map.wr[0][2] = 1;
                    vclk_map.wr[1][0] = 1;
                    vclk_map.wr[1][1] = 1;                
                    vclk_map.wr[1][2] = 1;                
                    vclk_map.wr[2][0] = 1;
                    vclk_map.wr[2][1] = 1;
                    vclk_map.wr[2][2] = 1;
                    vclk_map.wr[3][0] = 1;
                    vclk_map.wr[3][1] = 1;                
                    vclk_map.wr[3][2] = 1;                
                end
            endcase
        end
    end

    // Two pixels per clock
    else
    begin
        always_comb
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                for (int j = 0; j < P_FIFO_STRIPES; j++)
                begin
                    vclk_map.wr[i][j] = 0;
                    vclk_map.dat[i][j] = 0;
                end
            end

            case (vclk_map.sel)
                'd1 : 
                begin
                    vclk_map.dat[2][0] = {1'b0, vclk_vid.dat[0][(0*P_BPC)+:P_BPC]};   // R2
                    vclk_map.dat[2][1] = {1'b0, vclk_vid.dat[1][(0*P_BPC)+:P_BPC]};   // G2
                    vclk_map.dat[2][2] = {1'b0, vclk_vid.dat[2][(0*P_BPC)+:P_BPC]};   // B2
                    vclk_map.dat[3][0] = {1'b0, vclk_vid.dat[0][(1*P_BPC)+:P_BPC]};   // R3
                    vclk_map.dat[3][1] = {1'b0, vclk_vid.dat[1][(1*P_BPC)+:P_BPC]};   // G3
                    vclk_map.dat[3][2] = {1'b0, vclk_vid.dat[2][(1*P_BPC)+:P_BPC]};   // B3
                    
                    vclk_map.wr[2][0] = 1;
                    vclk_map.wr[2][1] = 1;
                    vclk_map.wr[2][2] = 1;
                    vclk_map.wr[3][0] = 1;
                    vclk_map.wr[3][1] = 1;                
                    vclk_map.wr[3][2] = 1;                
                end

                'd2 : 
                begin
                    vclk_map.dat[0][3] = {1'b0, vclk_vid.dat[0][(0*P_BPC)+:P_BPC]};   // R4
                    vclk_map.dat[0][0] = {1'b0, vclk_vid.dat[1][(0*P_BPC)+:P_BPC]};   // G4
                    vclk_map.dat[0][1] = {1'b0, vclk_vid.dat[2][(0*P_BPC)+:P_BPC]};   // B4
                    vclk_map.dat[1][3] = {1'b0, vclk_vid.dat[0][(1*P_BPC)+:P_BPC]};   // R5
                    vclk_map.dat[1][0] = {1'b0, vclk_vid.dat[1][(1*P_BPC)+:P_BPC]};   // G5
                    vclk_map.dat[1][1] = {1'b0, vclk_vid.dat[2][(1*P_BPC)+:P_BPC]};   // B5
                    
                    vclk_map.wr[0][3] = 1;
                    vclk_map.wr[0][0] = 1;
                    vclk_map.wr[0][1] = 1;
                    vclk_map.wr[1][3] = 1;
                    vclk_map.wr[1][0] = 1;                
                    vclk_map.wr[1][1] = 1;                
                end

                'd3 : 
                begin
                    vclk_map.dat[2][3] = {1'b0, vclk_vid.dat[0][(0*P_BPC)+:P_BPC]};   // R6
                    vclk_map.dat[2][0] = {1'b0, vclk_vid.dat[1][(0*P_BPC)+:P_BPC]};   // G6
                    vclk_map.dat[2][1] = {1'b0, vclk_vid.dat[2][(0*P_BPC)+:P_BPC]};   // B6
                    vclk_map.dat[3][3] = {1'b0, vclk_vid.dat[0][(1*P_BPC)+:P_BPC]};   // R7
                    vclk_map.dat[3][0] = {1'b0, vclk_vid.dat[1][(1*P_BPC)+:P_BPC]};   // G7
                    vclk_map.dat[3][1] = {1'b0, vclk_vid.dat[2][(1*P_BPC)+:P_BPC]};   // B7
                    
                    vclk_map.wr[2][3] = 1;
                    vclk_map.wr[2][0] = 1;
                    vclk_map.wr[2][1] = 1;
                    vclk_map.wr[3][3] = 1;
                    vclk_map.wr[3][0] = 1;                
                    vclk_map.wr[3][1] = 1;                
                end

                'd4 : 
                begin
                    vclk_map.dat[0][2] = {1'b0, vclk_vid.dat[0][(0*P_BPC)+:P_BPC]};   // R8
                    vclk_map.dat[0][3] = {1'b0, vclk_vid.dat[1][(0*P_BPC)+:P_BPC]};   // G8
                    vclk_map.dat[0][0] = {1'b0, vclk_vid.dat[2][(0*P_BPC)+:P_BPC]};   // B8
                    vclk_map.dat[1][2] = {1'b0, vclk_vid.dat[0][(1*P_BPC)+:P_BPC]};   // R9
                    vclk_map.dat[1][3] = {1'b0, vclk_vid.dat[1][(1*P_BPC)+:P_BPC]};   // G9
                    vclk_map.dat[1][0] = {1'b0, vclk_vid.dat[2][(1*P_BPC)+:P_BPC]};   // B9
                    
                    vclk_map.wr[0][2] = 1;
                    vclk_map.wr[0][3] = 1;
                    vclk_map.wr[0][0] = 1;
                    vclk_map.wr[1][2] = 1;
                    vclk_map.wr[1][3] = 1;                
                    vclk_map.wr[1][0] = 1;                
                end

                'd5 : 
                begin
                    vclk_map.dat[2][2] = {1'b0, vclk_vid.dat[0][(0*P_BPC)+:P_BPC]};   // R10
                    vclk_map.dat[2][3] = {1'b0, vclk_vid.dat[1][(0*P_BPC)+:P_BPC]};   // G10
                    vclk_map.dat[2][0] = {1'b0, vclk_vid.dat[2][(0*P_BPC)+:P_BPC]};   // B10
                    vclk_map.dat[3][2] = {1'b0, vclk_vid.dat[0][(1*P_BPC)+:P_BPC]};   // R11
                    vclk_map.dat[3][3] = {1'b0, vclk_vid.dat[1][(1*P_BPC)+:P_BPC]};   // G11
                    vclk_map.dat[3][0] = {1'b0, vclk_vid.dat[2][(1*P_BPC)+:P_BPC]};   // B11
                    
                    vclk_map.wr[2][2] = 1;
                    vclk_map.wr[2][3] = 1;
                    vclk_map.wr[2][0] = 1;
                    vclk_map.wr[3][2] = 1;
                    vclk_map.wr[3][3] = 1;                
                    vclk_map.wr[3][0] = 1;                
                end

                'd6 : 
                begin
                    vclk_map.dat[0][1] = {1'b0, vclk_vid.dat[0][(0*P_BPC)+:P_BPC]};   // R12
                    vclk_map.dat[0][2] = {1'b0, vclk_vid.dat[1][(0*P_BPC)+:P_BPC]};   // G12
                    vclk_map.dat[0][3] = {1'b0, vclk_vid.dat[2][(0*P_BPC)+:P_BPC]};   // B12
                    vclk_map.dat[1][1] = {1'b0, vclk_vid.dat[0][(1*P_BPC)+:P_BPC]};   // R13
                    vclk_map.dat[1][2] = {1'b0, vclk_vid.dat[1][(1*P_BPC)+:P_BPC]};   // G13
                    vclk_map.dat[1][3] = {1'b0, vclk_vid.dat[2][(1*P_BPC)+:P_BPC]};   // B13
                    
                    vclk_map.wr[0][1] = 1;
                    vclk_map.wr[0][2] = 1;
                    vclk_map.wr[0][3] = 1;
                    vclk_map.wr[1][1] = 1;
                    vclk_map.wr[1][2] = 1;                
                    vclk_map.wr[1][3] = 1;                
                end

                'd7 : 
                begin
                    vclk_map.dat[2][1] = {1'b0, vclk_vid.dat[0][(0*P_BPC)+:P_BPC]};   // R14
                    vclk_map.dat[2][2] = {1'b0, vclk_vid.dat[1][(0*P_BPC)+:P_BPC]};   // G14
                    vclk_map.dat[2][3] = {1'b0, vclk_vid.dat[2][(0*P_BPC)+:P_BPC]};   // B14
                    vclk_map.dat[3][1] = {1'b0, vclk_vid.dat[0][(1*P_BPC)+:P_BPC]};   // R15
                    vclk_map.dat[3][2] = {1'b0, vclk_vid.dat[1][(1*P_BPC)+:P_BPC]};   // G15
                    vclk_map.dat[3][3] = {vclk_vid.bs, vclk_vid.dat[2][(1*P_BPC)+:P_BPC]};   // B15
                    
                    vclk_map.wr[2][1] = 1;
                    vclk_map.wr[2][2] = 1;
                    vclk_map.wr[2][3] = 1;
                    vclk_map.wr[3][1] = 1;
                    vclk_map.wr[3][2] = 1;                
                    vclk_map.wr[3][3] = 1;                
                end

                default : 
                begin
                    vclk_map.dat[0][0] = {1'b0, vclk_vid.dat[0][(0*P_BPC)+:P_BPC]};   // R0
                    vclk_map.dat[0][1] = {1'b0, vclk_vid.dat[1][(0*P_BPC)+:P_BPC]};   // G0
                    vclk_map.dat[0][2] = {1'b0, vclk_vid.dat[2][(0*P_BPC)+:P_BPC]};   // B0
                    vclk_map.dat[1][0] = {1'b0, vclk_vid.dat[0][(1*P_BPC)+:P_BPC]};   // R1
                    vclk_map.dat[1][1] = {1'b0, vclk_vid.dat[1][(1*P_BPC)+:P_BPC]};   // G1
                    vclk_map.dat[1][2] = {1'b0, vclk_vid.dat[2][(1*P_BPC)+:P_BPC]};   // B1
                    
                    vclk_map.wr[0][0] = 1;
                    vclk_map.wr[0][1] = 1;
                    vclk_map.wr[0][2] = 1;
                    vclk_map.wr[1][0] = 1;
                    vclk_map.wr[1][1] = 1;                
                    vclk_map.wr[1][2] = 1;                
                end
            endcase
        end
    end
endgenerate

/*
    FIFO
*/
generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_fifo       
        for (j = 0; j < P_FIFO_STRIPES; j++)
        begin
            // Write data
            assign vclk_fifo.din[i][j] = vclk_map.dat[i][j];

            // Write
            assign vclk_fifo.wr[i][j] = (vclk_vid.vde) ? vclk_map.wr[i][j] : 0;

            prt_dp_lib_fifo_dc
            #(
            	.P_MODE         ("burst"),		       // "single" or "burst"
            	.P_RAM_STYLE	("distributed"),	   // "distributed" or "block"
            	.P_ADR_WIDTH	(P_FIFO_ADR),
            	.P_DAT_WIDTH	(P_FIFO_DAT)
            )
            FIFO_INST
            (
            	.A_RST_IN      (vclk_vid.hs_re),	    // Reset
            	.B_RST_IN      (lclk_vid.hs_re),
            	.A_CLK_IN      (VID_CLK_IN),		    // Clock
            	.B_CLK_IN      (LNK_CLK_IN),
            	.A_CKE_IN      (VID_CKE_IN),		    // Clock enable
            	.B_CKE_IN      (lclk_lnk.en),

            	// Input (A)
            	.A_WR_IN       (vclk_fifo.wr[i][j]),	    // Write
            	.A_DAT_IN      (vclk_fifo.din[i][j]),		// Write data

            	// Output (B)
            	.B_RD_IN       (lclk_fifo.rd[i][j]),	    // Read
            	.B_DAT_OUT     (lclk_fifo.dout[i][j]),		// Read data
            	.B_DE_OUT      (lclk_fifo.de[i][j]),		// Data enable

            	// Status (A)
            	.A_WRDS_OUT    (vclk_fifo.wrds[i][j]),		// Used words
            	.A_FL_OUT      (vclk_fifo.fl[i][j]),		// Full
            	.A_EP_OUT      (vclk_fifo.ep[i][j]),		// Empty

            	// Status (B)
            	.B_WRDS_OUT    (lclk_fifo.wrds[i][j]),		// Used words
            	.B_FL_OUT      (lclk_fifo.fl[i][j]),		// Full
            	.B_EP_OUT      (lclk_fifo.ep[i][j])		    // Empty
            );
        end
    end
endgenerate


/*
    Link domain
*/

// Control
    always_ff @ (posedge LNK_CLK_IN)
    begin
        lclk_lnk.lanes  <= CTL_LANES_IN;
        lclk_lnk.en     <= CTL_EN_IN;
    end

// Combine all FIFO de into a single signal
    always_comb
    begin
        // Default
        lclk_lnk.fifo_de = 0;

        for (int i = 0; i < P_LANES; i++)
        begin
            for (int j = 0; j < P_FIFO_STRIPES; j++)
            begin
                if (lclk_fifo.de[i][j])
                    lclk_lnk.fifo_de = 1;
            end
        end
    end

// FIFO words
// This process calculates the totals number of words in the fifo. 
// This is used for the fifo ready signal
// Only the last fifo of the last lane is used.
    always_ff @ (posedge LNK_CLK_IN)
    begin
        lclk_lnk.fifo_wrds <= {lclk_fifo.wrds[P_LANES-1][P_FIFO_STRIPES-1], 2'b00};
    end

// FIFO ready
// This signal is asserted when the FIFO has enough words to start the initial TU.
    always_ff @ (posedge LNK_CLK_IN)
    begin
        if (lclk_lnk.fifo_wrds >= 'd12)
            lclk_lnk.fifo_rdy <= 1;
        else
            lclk_lnk.fifo_rdy <= 0;
    end

// FIFO read
// To-do : add support for two sublanes
generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_fifo_rd
        for (j = 0; j < P_FIFO_STRIPES; j++)
            assign lclk_fifo.rd[i][j] = (lclk_lnk.vu_rd_cnt_end) ? 0 : 1;
    end
endgenerate

// FIFO de edge detector
    prt_dp_lib_edge
    LNK_FIFO_DE_EDGE_INST
    (
        .CLK_IN    (LNK_CLK_IN),        // Clock
        .CKE_IN    (1'b1),              // Clock enable
        .A_IN      (lclk_lnk.fifo_de),  // Input
        .RE_OUT    (),                  // Rising edge
        .FE_OUT    (lclk_lnk.fifo_de_fe) // Falling edge
    );

// Vsync clock domain crossing
    prt_dp_lib_cdc_bit
    LCLK_VS_CDC_INST
    (
        .SRC_CLK_IN     (VID_CLK_IN),       // Clock
        .SRC_DAT_IN     (vclk_vid.vs),      // Data
        .DST_CLK_IN     (LNK_CLK_IN),       // Clock
        .DST_DAT_OUT    (lclk_vid.vs)       // Data
    );

// Hsync clock domain crossing
    prt_dp_lib_cdc_bit
    LCLK_HS_CDC_INST
    (
        .SRC_CLK_IN     (VID_CLK_IN),       // Clock
        .SRC_DAT_IN     (vclk_vid.hs),      // Data
        .DST_CLK_IN     (LNK_CLK_IN),       // Clock
        .DST_DAT_OUT    (lclk_vid.hs)       // Data
    );

// Hsync rising edge
    prt_dp_lib_edge
    LNK_HS_EDGE_INST
    (
        .CLK_IN         (LNK_CLK_IN),        // Clock
        .CKE_IN         (1'b1),              // Clock enable
        .A_IN           (lclk_vid.hs),       // Input
        .RE_OUT         (lclk_vid.hs_re),    // Rising edge
        .FE_OUT         ()                   // Falling edge
    );

// Vertical blanking flag clock domain crossing
    prt_dp_lib_cdc_bit
    LCLK_VBF_CDC_INST
    (
        .SRC_CLK_IN     (VID_CLK_IN),       // Clock
        .SRC_DAT_IN     (vclk_vid.vbf),     // Data
        .DST_CLK_IN     (LNK_CLK_IN),       // Clock
        .DST_DAT_OUT    (lclk_vid.vbf)      // Data
    );

// Video active clock domain crossing
    prt_dp_lib_cdc_bit
    LCLK_VID_ACT_CDC_INST
    (
        .SRC_CLK_IN     (VID_CLK_IN),        // Clock
        .SRC_DAT_IN     (vclk_vid.act),      // Data
        .DST_CLK_IN     (LNK_CLK_IN),        // Clock
        .DST_DAT_OUT    (lclk_vid.act)       // Data
    );

// Video active rising edge
    prt_dp_lib_edge
    LNK_VID_ACT_EDGE_INST
    (
        .CLK_IN         (LNK_CLK_IN),         // Clock
        .CKE_IN         (1'b1),               // Clock enable
        .A_IN           (lclk_vid.act),       // Input
        .RE_OUT         (lclk_vid.act_re),    // Rising edge
        .FE_OUT         ()                    // Falling edge
    );

// Video blanking clock domain crossing
    prt_dp_lib_cdc_bit
    LCLK_VID_BLNK_CDC_INST
    (
        .SRC_CLK_IN     (VID_CLK_IN),       // Clock
        .SRC_DAT_IN     (vclk_vid.blnk),    // Data
        .DST_CLK_IN     (LNK_CLK_IN),       // Clock
        .DST_DAT_OUT    (lclk_vid.blnk)     // Data
    );

// Video blanking rising edge
    prt_dp_lib_edge
    LNK_VID_BLNK_EDGE_INST
    (
        .CLK_IN         (LNK_CLK_IN),        // Clock
        .CKE_IN         (1'b1),              // Clock enable
        .A_IN           (lclk_vid.blnk),     // Input
        .RE_OUT         (lclk_vid.blnk_re),  // Rising edge
        .FE_OUT         ()                   // Falling edge
    );

// Video active event
// This flag is asserted when there is an active video line.
// The flag is sticky.
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Enable
        if (lclk_lnk.en)
        begin
            // Clear
            if (lclk_lnk.bs)
                lclk_vid.act_evt <= 0;

            // Set
            else if (lclk_vid.act_re)
                lclk_vid.act_evt <= 1;
        end

        // Idle
        else
            lclk_vid.act_evt <= 0;
    end

// Video blanking event
// This flag is asserted when there is an blanking video line.
// The flag is sticky.
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Enable
        if (lclk_lnk.en)
        begin
            // Clear
            if (lclk_lnk.bs)
                lclk_vid.blnk_evt <= 0;

            // Set
            else if (lclk_vid.blnk_re)
                lclk_vid.blnk_evt <= 1;
        end

        // Idle
        else
            lclk_vid.blnk_evt <= 0;
    end

// Blanking start 
// This flag is asserted when the blanking start bit is set in the last stripe of the last fifo
    always_comb
    begin
        if (lclk_fifo.de[P_LANES-1][P_FIFO_STRIPES-1] && lclk_fifo.dout[P_LANES-1][P_FIFO_STRIPES-1][P_FIFO_DAT-1])
            lclk_lnk.bs = 1;
        else
            lclk_lnk.bs = 0;
    end

// Transfer unit run
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Enable
        if (lclk_lnk.en)
        begin
            // Clear 
            if (lclk_vid.hs_re || lclk_lnk.bs)
                lclk_lnk.tu_run <= 0;
            
            // Set
            else if (lclk_lnk.fifo_rdy && (lclk_vid.act_evt || lclk_vid.blnk_evt))
                lclk_lnk.tu_run <= 1;
        end

        else
            lclk_lnk.tu_run <= 0;
    end

// TU run edge
    prt_dp_lib_edge
    LNK_TU_RUN_EDGE_INST
    (
        .CLK_IN         (LNK_CLK_IN),         // Clock
        .CKE_IN         (1'b1),               // Clock enable
        .A_IN           (lclk_lnk.tu_run),    // Input
        .RE_OUT         (lclk_lnk.tu_run_re), // Rising edge
        .FE_OUT         ()                    // Falling edge
    );

// Transfer unit counter
// This counter counts all the symbols in a transfer unit (per lane)
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // run
        if (lclk_lnk.tu_run)
        begin

            // Load
            if (lclk_lnk.tu_cnt_end || lclk_lnk.tu_cnt_last)
                lclk_lnk.tu_cnt <= P_TU_SIZE / P_SPL;

            // Decrement
            else if (!lclk_lnk.tu_cnt_end)
                lclk_lnk.tu_cnt <= lclk_lnk.tu_cnt - 'd1;
        end

        else
            lclk_lnk.tu_cnt <= 0;
    end

// Transfer unit counter last
    always_comb
    begin
        if (lclk_lnk.tu_cnt == 'd1)
            lclk_lnk.tu_cnt_last = 1;
        else
            lclk_lnk.tu_cnt_last = 0;
    end

// Transfer unit counter end
    always_comb
    begin
        if (lclk_lnk.tu_cnt == 0)
            lclk_lnk.tu_cnt_end = 1;
        else
            lclk_lnk.tu_cnt_end = 0;
    end

// Video unit length
// This process determines the length of the video unit 
    always_comb
    begin
        // Maximum transfer size is 64 symbols
        if (lclk_lnk.fifo_wrds >= 'd64)
            lclk_lnk.vu_len = 'd64;
        
        else
            lclk_lnk.vu_len = lclk_lnk.fifo_wrds[$size(lclk_lnk.vu_len)-1:0];
    end

// Video data read counter
// This counter counts video symbols in a transfer unit during read
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Run
        if (lclk_lnk.tu_run)
        begin    
            // Load
            if (lclk_lnk.tu_cnt == 'd16)
                lclk_lnk.vu_rd_cnt <= lclk_lnk.vu_len;

            // Decrement
            else if (!lclk_lnk.vu_rd_cnt_end)
                lclk_lnk.vu_rd_cnt <= lclk_lnk.vu_rd_cnt - P_SPL;
        end

        // Idle
        else
            lclk_lnk.vu_rd_cnt <= 0;
    end

// Video data read counter end
    always_comb
    begin
        if (lclk_lnk.vu_rd_cnt == 0)
            lclk_lnk.vu_rd_cnt_end = 1;
        else
            lclk_lnk.vu_rd_cnt_end = 0;
    end

// Video data de counter
// This counter counts video symbols in a transfer unit during de
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Run
        if (lclk_lnk.tu_run)
        begin
            // Load
            if (lclk_lnk.tu_cnt == 'd14)
                lclk_lnk.vu_de_cnt <= lclk_lnk.vu_rd_cnt + P_SPL;

            // Decrement
            else if (lclk_lnk.fifo_de) 
                lclk_lnk.vu_de_cnt <= lclk_lnk.vu_de_cnt - P_SPL;
        end

        // Idle
        else
            lclk_lnk.vu_de_cnt <= 0;
    end

// Video data de counter last
// This flag is asserted when the last data in a Video unit is read from the fifo
    always_comb
    begin
        if (lclk_lnk.vu_de_cnt == P_SPL)
            lclk_lnk.vu_de_cnt_last = 1;
        else
            lclk_lnk.vu_de_cnt_last = 0;
    end

// Video data de counter end
    always_comb
    begin
        if (lclk_lnk.vu_de_cnt == 0)
            lclk_lnk.vu_de_cnt_end = 1;
        else
            lclk_lnk.vu_de_cnt_end = 0;
    end

// Video data select
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Clear
        if (lclk_vid.hs)
            lclk_lnk.vu_sel <= 0;

        // Video data
        else if (lclk_lnk.fifo_de)
            lclk_lnk.vu_sel <= ~lclk_lnk.vu_sel;
    end

// Video data 
generate 
    // Four symbols per lane
    if (P_SPL == 4)
    begin : vu_dat_4spl
        for (i = 0; i < P_LANES; i++)
        begin
            for (j = 0; j < P_SPL; j++)
                assign lclk_lnk.vu_dat[i][j] = lclk_fifo.dout[i][j]; 
        end
    end

    // Two symbols per lane
    else
    begin : vu_dat_2spl
        for (i = 0; i < P_LANES; i++)
        begin
            for (j = 0; j < P_SPL; j++)
                assign lclk_lnk.vu_dat[i][j] = (lclk_lnk.vu_sel) ? lclk_fifo.dout[i][j+2] : lclk_fifo.dout[i][j]; 
        end
    end
endgenerate

// Insert blanking end delay line
// The FIFO has a two clock cycle read latency
// This register delay compensates for the FIFO read latency
    always_ff @ (posedge LNK_CLK_IN)
    begin
        lclk_lnk.ins_be <= {lclk_lnk.ins_be[0+:$left(lclk_lnk.ins_be)], lclk_lnk.tu_run_re};
    end

// Link output
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Default
        for (int i = 0; i < P_LANES; i++)
        begin
            for (int j = 0; j < P_SPL; j++)
            begin
                lclk_lnk.k[i][j] <= 0;
                lclk_lnk.dat[i][j] <= 0;
            end
        end

        // Blanking end
        if (lclk_lnk.ins_be[$size(lclk_lnk.ins_be)-1] && lclk_vid.act_evt)
        begin
            for (int i = 0; i < P_LANES; i++)
                {lclk_lnk.k[i][P_SPL-1], lclk_lnk.dat[i][P_SPL-1]} <= P_SYM_BE;
        end

        // Video data
        else if (lclk_lnk.fifo_de && lclk_vid.act_evt)
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                for (int j = 0; j < P_SPL; j++)
                    lclk_lnk.dat[i][j] <= lclk_lnk.vu_dat[i][j]; 
            end
        end

        // Single fill word
        else if ((lclk_lnk.tu_cnt == 'd14) && lclk_lnk.fifo_de_fe && lclk_vid.act_evt)
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                {lclk_lnk.k[i][0], lclk_lnk.dat[i][0]} <= P_SYM_FS;             // First Sublane 
                {lclk_lnk.k[i][P_SPL-1], lclk_lnk.dat[i][P_SPL-1]} <= P_SYM_FE; // Last Sublane 
            end
        end

        // Fill start
        else if (lclk_lnk.fifo_de_fe && lclk_vid.act_evt)
        begin
            for (int i = 0; i < P_LANES; i++)
                {lclk_lnk.k[i][0], lclk_lnk.dat[i][0]} <= P_SYM_FS;     // Sublane 0
        end


        // Fill end
        else if ((lclk_lnk.tu_cnt == 'd14) && lclk_vid.act_evt)
        begin
            for (int i = 0; i < P_LANES; i++)
                {lclk_lnk.k[i][P_SPL-1], lclk_lnk.dat[i][P_SPL-1]} <= P_SYM_FE;     // Sublane 1
        end
    end

// Outputs
generate
    for (i = 0; i < P_LANES; i++)
    begin
        assign LNK_SRC_IF.disp_ctl[i]    = 0;                 // Disparity control (not used)
        assign LNK_SRC_IF.disp_val[i]    = 0;                 // Disparity value (not used)
        assign LNK_SRC_IF.k[i]           = lclk_lnk.k[i];     // K character
        assign LNK_SRC_IF.dat[i]         = lclk_lnk.dat[i];   // Data
    end
endgenerate

    assign LNK_VS_OUT  = (lclk_lnk.en) ? lclk_vid.vs : 0;   // Vsync
    assign LNK_VBF_OUT = (lclk_lnk.en) ? lclk_vid.vbf : 0;  // Video blanking flag
    assign LNK_BS_OUT  = lclk_lnk.bs;                     // Blanking start
    
endmodule

`default_nettype wire
