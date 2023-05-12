/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP TX Video
    (c) 2021 - 2023 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Added support for 1 and 2 active lanes
    v1.2 - Improved vu size calculation and fifo reset
    v1.3 - Updated link interface
    v1.4 - Added MST support

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
    // System
    parameter               P_VENDOR = "none",  // Vendor "xilinx" or "lattice"
    parameter               P_STREAM = 0,       // Stream ID

    // Link
    parameter               P_LANES = 4,    // Lanes
    parameter               P_SPL = 2,      // Symbols per lane

    // Video
    parameter               P_PPC = 2,      // Pixels per clock
    parameter               P_BPC = 8,      // Bits per component

    // Message
    parameter               P_MSG_IDX     = 5,          // Message index width
    parameter               P_MSG_DAT     = 16,         // Message data width
    parameter               P_MSG_ID      = 0           // Message ID main stream attributes
)
(
    // Control
    input wire [1:0]        CTL_LANES_IN,       // Active lanes (1 - 1 lane / 2 - 2 lanes / 3 - 4 lanes)
    input wire              CTL_EN_IN,          // Enable
    input wire              CTL_MST_IN,         // MST
    input wire [5:0]        CTL_VC_LEN_IN,      // Virtual channel length

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
    output wire             LNK_VBF_OUT         // Vertical blanking flag (required by MSA)
);

// Package
import prt_dp_pkg::*;

// Parameters
localparam P_FIFO_WRDS = 32;
localparam P_FIFO_ADR = $clog2(P_FIFO_WRDS);
localparam P_FIFO_DAT = 9;
localparam P_FIFO_STRIPES = 4;
localparam P_TU_SIZE = 64;
localparam P_TU_CNT_LD = P_TU_SIZE / P_SPL;
localparam P_TU_FE = P_TU_CNT_LD - 4;
localparam P_VC_LEN = (P_SPL == 4) ? 4 : 5;     // VC length
localparam P_HEAD_INC = (P_SPL == 4) ? 1 : 2;   // Head pointer increment. 

// Structures
typedef struct {
    logic [1:0]                     lanes;    // Active lanes (1 - 1 lane / 2 - 2 lanes / 3 - 4 lanes)
    logic                           en;       // Enable
    logic                           mst;      // MST
    logic [P_VC_LEN-1:0]            vc_len;
} ctl_struct;

typedef struct {
    logic                           run;      // Run
    logic                           vs;
    logic                           vs_re;
    logic                           hs;
    logic                           hs_re;
    logic                           hs_fe;
    logic                           de;
    logic                           de_re;
    logic                           de_fe;
    logic [(P_PPC * P_BPC)-1:0]     dat[0:2];
    logic [15:0]                    hstart;         // Horizontal start. The start of the active pixels from the hsync leading edge
    logic [15:0]                    hwidth;         // Horizontal width. Number of active pixels in a line
    logic [15:0]                    vheight;        // Vertical heigth. This is the active number of lines 
    logic [15:0]                    pix_cnt;        // Pixel counter
    logic [15:0]                    pix_cnt_bs;     // Pixel counter BS insert value
    logic [15:0]                    lin_cnt;        // Line counter
    logic                           vbf;            // Vertical blanking flag
    logic                           bs;             // Blanking start
    logic                           be;             // Blanking end
    logic                           vde;            // Virtual data enable
    logic                           vde_re;
    logic                           vde_re_del;
    logic                           vde_fe;
    logic                           act;            // Active line
    logic                           blnk;           // Blanking line
} vid_struct;

typedef struct {
    logic   [2:0]                   sel;
    logic   [P_FIFO_DAT-1:0]        dat[0:P_LANES-1][0:P_FIFO_STRIPES-1];
    logic   [P_FIFO_STRIPES-1:0]    wr[0:P_LANES-1];
} vid_map_struct;

typedef struct {
    logic   [7:0]                   head;
    logic	[P_FIFO_DAT-1:0]        din[0:P_LANES-1][0:P_FIFO_STRIPES-1];
    logic   [P_FIFO_STRIPES-1:0]    wr[0:P_LANES-1];
    logic   [P_FIFO_ADR:0]          wrds[0:P_LANES-1][0:P_FIFO_STRIPES-1];
    logic   [P_FIFO_STRIPES-1:0]    ep[0:P_LANES-1];
    logic   [P_FIFO_STRIPES-1:0]    fl[0:P_LANES-1];
} vid_fifo_struct;

typedef struct {
    logic   [7:0]                   head;
    logic   [7:0]                   tail;
    logic                           tail_inc;
    logic   [7:0]                   delta;
    logic [7:0]                     msk;      // Mask
    logic   [P_FIFO_STRIPES-1:0]    rd[0:P_LANES-1];
    logic   [P_FIFO_DAT-1:0]        dout[0:P_LANES-1][0:P_FIFO_STRIPES-1];
    logic   [P_FIFO_STRIPES-1:0]    de[0:P_LANES-1];
    logic   [P_FIFO_ADR:0]          wrds[0:P_LANES-1][0:P_FIFO_STRIPES-1];
    logic   [P_FIFO_STRIPES-1:0]    ep[0:P_LANES-1];
    logic   [P_FIFO_STRIPES-1:0]    fl[0:P_LANES-1];
} lnk_fifo_struct;

typedef struct {
    logic                           run;
    logic                           vs;
    logic                           hs;
    logic                           hs_fe;
    logic                           vbf;      // Vertical blanking flag
    logic                           act;
    logic                           act_re;
    logic                           act_evt;
    logic                           blnk;
    logic                           blnk_re;
    logic                           blnk_evt;
} lnk_vid_struct;

typedef struct {
    logic                           bs;             // Blanking start 
    logic                           be;             // Blanking end
    logic                           fifo_rdy;       // FIFO ready
    logic [5:0]                     vu_len;         // Video unit length in a TU
    logic                           tu_run;
    logic                           tu_run_re;
    logic [5:0]                     tu_cnt;         // Transfer unit counter
    logic                           tu_cnt_last;
    logic                           tu_cnt_end;
    logic [5:0]                     vu_rd_cnt;      // Video unit read counter
    logic                           vu_rd_cnt_end;
    logic [4:0]                     ins_be;
    logic [P_VC_LEN-1:0]            vc_rd_cnt;
    logic [P_VC_LEN-1:0]            vc_rd_cnt_in;
    logic                           vc_rd_cnt_end;
} lnk_struct;

typedef struct {
    logic [1:0]                     bs;
    logic                           rd;
    logic [4:0]                     rd_sel;
    logic [4:0]                     dat_sel[0:2];
    logic [7:0]                     dat[0:P_LANES-1][0:P_SPL-1];
    logic [2:0]                     de;
    logic                           de_fe;
} lnk_map_struct;

typedef struct {
    logic   [P_MSG_IDX-1:0]         idx;
    logic                           first;
    logic                           last;
    logic   [P_MSG_DAT-1:0]         dat;
    logic                           vld;
} msg_struct;

typedef struct {
    logic                           rd;
    logic                           rd_re;
    prt_dp_tx_lnk_sym               sym[0:P_LANES-1][0:P_SPL-1];
    logic [7:0]                     dat[0:P_LANES-1][0:P_SPL-1];
    logic [4:0]                     vld;
} src_struct;

// Signals
ctl_struct          lclk_ctl;
ctl_struct          vclk_ctl;
msg_struct          vclk_msg;
vid_struct          vclk_vid;
vid_map_struct      vclk_map;
vid_fifo_struct     vclk_fifo;
lnk_fifo_struct     lclk_fifo;
lnk_vid_struct      lclk_vid;
lnk_map_struct      lclk_map;
lnk_struct          lclk_lnk;
src_struct          lclk_src;

genvar i, j;

// Logic

/*
    Video domain
*/

// Control lanes clock domain crossing
    prt_dp_lib_cdc_vec
    #(
        .P_WIDTH        ($size(lclk_ctl.lanes))
    )
    VID_LANES_CDC_INST
    (
        .SRC_CLK_IN     (LNK_CLK_IN),         // Clock
        .SRC_DAT_IN     (lclk_ctl.lanes),     // Data
        .DST_CLK_IN     (VID_CLK_IN),         // Clock
        .DST_DAT_OUT    (vclk_ctl.lanes)      // Data
    );

// Control Enable clock domain crossing
    prt_dp_lib_cdc_bit
    VID_EN_CDC_INST
    (
        .SRC_CLK_IN     (LNK_CLK_IN),       // Clock
        .SRC_DAT_IN     (lclk_ctl.en),      // Data
        .DST_CLK_IN     (VID_CLK_IN),       // Clock
        .DST_DAT_OUT    (vclk_ctl.en)       // Data
    );

// Control MST clock domain crossing
    prt_dp_lib_cdc_bit
    VID_MST_CDC_INST
    (
        .SRC_CLK_IN     (LNK_CLK_IN),       // Clock
        .SRC_DAT_IN     (lclk_ctl.mst),     // Data
        .DST_CLK_IN     (VID_CLK_IN),       // Clock
        .DST_DAT_OUT    (vclk_ctl.mst)      // Data
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
    VID_VS_EDGE_INST
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
    VID_HS_EDGE_INST
    (
        .CLK_IN    (VID_CLK_IN),        // Clock
        .CKE_IN    (VID_CKE_IN),        // Clock enable
        .A_IN      (vclk_vid.hs),       // Input
        .RE_OUT    (vclk_vid.hs_re),    // Rising edge
        .FE_OUT    (vclk_vid.hs_fe)     // Falling edge
    );

// Data enable edge detector
// This is used for active line counter
    prt_dp_lib_edge
    VID_DE_EDGE_INST
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
        if (vclk_ctl.en)
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
            if ( ((vclk_ctl.lanes == 'd3) && (vclk_msg.idx == 'd21)) || ((vclk_ctl.lanes == 'd2) && (vclk_msg.idx == 'd11)) || ((vclk_ctl.lanes == 'd1) && (vclk_msg.idx == 'd14)))
                vclk_vid.hstart[15:8] <= vclk_msg.dat[0+:8];

            // Load lower byte
            else if ( ((vclk_ctl.lanes == 'd3) && (vclk_msg.idx == 'd25)) || ((vclk_ctl.lanes == 'd2) && (vclk_msg.idx == 'd13)) || ((vclk_ctl.lanes == 'd1) && (vclk_msg.idx == 'd15)) )
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
            if ( ((vclk_ctl.lanes == 'd3) && (vclk_msg.idx == 'd22)) || ((vclk_ctl.lanes == 'd2) && (vclk_msg.idx == 'd28)) || ((vclk_ctl.lanes == 'd1) && (vclk_msg.idx == 'd23)) )
                vclk_vid.hwidth[15:8] <= vclk_msg.dat[0+:8];

            // Load lower byte
            else if ( ((vclk_ctl.lanes == 'd3) && (vclk_msg.idx == 'd26)) || ((vclk_ctl.lanes == 'd2) && (vclk_msg.idx == 'd30)) || ((vclk_ctl.lanes == 'd1) && (vclk_msg.idx == 'd24)) )
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
            if ( ((vclk_ctl.lanes == 'd3) && (vclk_msg.idx == 'd30)) || ((vclk_ctl.lanes == 'd2) && (vclk_msg.idx == 'd32)) || ((vclk_ctl.lanes == 'd1) && (vclk_msg.idx == 'd25)) )
                vclk_vid.vheight[15:8] <= vclk_msg.dat[0+:8];

            // Load lower byte
            else if ( ((vclk_ctl.lanes == 'd3) && (vclk_msg.idx == 'd34)) || ((vclk_ctl.lanes == 'd2) && (vclk_msg.idx == 'd34)) || ((vclk_ctl.lanes == 'd1) && (vclk_msg.idx == 'd26)) )
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
                // Set
                if (vclk_vid.vs_re || (vclk_vid.lin_cnt == vclk_vid.vheight))
                    vclk_vid.vbf <= 1;

                // Clear
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

// In SST the BS flag needs to be aligned with the last data.
// This assures that the link domain will always insert the BS symbol right after the last data independant of the read bust length.
// In MST the BS flag is inserted after the last data.
// the VC payload has a fixed length.
// When generating the VC payload the BS symbol might not fit in the current payload and therefore it can be a seperate symbol.
    assign vclk_vid.pix_cnt_bs = vclk_ctl.mst ? vclk_vid.hstart + vclk_vid.hwidth - (2 * P_PPC) : vclk_vid.hstart + vclk_vid.hwidth - (3 * P_PPC);
    
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Clock enable
        if (VID_CKE_IN)
        begin
            if (vclk_vid.pix_cnt == vclk_vid.pix_cnt_bs)
                vclk_vid.bs <= 1;
            else
                vclk_vid.bs <= 0;
        end 
    end

// Blanking end
// This flag is asserted at the start of every line.
// It is used to generate the blanking end symbol in the link domain.
// This flag is also generated during horizontal blanking.
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Clock enable
        if (VID_CKE_IN)
        begin
            if (vclk_vid.pix_cnt == (vclk_vid.hstart - (3 * P_PPC)))
                vclk_vid.be <= 1;
            else
                vclk_vid.be <= 0;
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
    VID_VDE_EDGE_INST
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

                    // SST
                    // The BS symbol is aligned with the last data.
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
                    // MST
                    // The BE symbol is inserted in the first fifo stripe, just before the active video.
                    vclk_map.dat[0][0] = (vclk_vid.be) ? {1'b1, {P_BPC{1'b0}}} : {1'b0, vclk_vid.dat[0][(0*P_BPC)+:P_BPC]};   // R0
                    
                    // MST
                    // The BS symbol is inserted in the second fifo stripe, just after the active video.                  
                    vclk_map.dat[0][1] = (vclk_vid.bs) ? {1'b1, {P_BPC{1'b0}}} : {1'b0, vclk_vid.dat[1][(0*P_BPC)+:P_BPC]};   // G0
                    
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

// Head counter
// The head counter is used count the active words in the fifo. 
// Only the last stripe of the last lane is used. 
// The head value is used by the link domain to determine the size of the read packet.
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Run
        if (vclk_vid.run)
        begin
            // Clock enable
            if (VID_CKE_IN)
            begin
                // Clear on falling edge hsync
                if (vclk_vid.hs_fe)
                    vclk_fifo.head <= 0;

                // Increment
                else if (vclk_fifo.wr[P_LANES-1][P_FIFO_STRIPES-1])
                    vclk_fifo.head <= vclk_fifo.head + P_HEAD_INC;
            end
        end

        // Idle
        else
            vclk_fifo.head <= 0;
    end

generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_fifo       
        for (j = 0; j < P_FIFO_STRIPES; j++)
        begin
            // Write data
            assign vclk_fifo.din[i][j] = vclk_map.dat[i][j];

            // Write
            always_comb
            begin
                // MST
                if (vclk_ctl.mst)
                begin
                    // Write on BE symbol
                    if (vclk_vid.be)
                        vclk_fifo.wr[i][j] = 1;

                    // Write on BS symbol
                    else if (vclk_vid.bs)
                        vclk_fifo.wr[i][j] = 1;

                    // Video data
                    else if (vclk_vid.de)
                        vclk_fifo.wr[i][j] = vclk_map.wr[i][j];
                    
                    // Idle
                    else
                        vclk_fifo.wr[i][j] = 0; 
                end

                // SST
                else
                begin
                    // (Virtual video data
                    if (vclk_vid.vde)
                        vclk_fifo.wr[i][j] = vclk_map.wr[i][j];
                    
                    // Idle
                    else
                        vclk_fifo.wr[i][j] = 0; 
                end
            end

            //assign vclk_fifo.wr[i][j] = (vclk_ctl.mst) ? (vclk_vid.be || (vclk_vid.de) ? (vclk_map.wr[i][j] : 0) : ((vclk_vid.vde) ? vclk_map.wr[i][j] : 0);

            prt_dp_lib_fifo_dc
            #(
                .P_VENDOR       (P_VENDOR),            // Vendor
            	.P_MODE         ("burst"),		       // "single" or "burst"
            	.P_RAM_STYLE	("distributed"),	   // "distributed" or "block"
            	.P_ADR_WIDTH	(P_FIFO_ADR),
            	.P_DAT_WIDTH	(P_FIFO_DAT)
            )
            FIFO_INST
            (
            	.A_RST_IN      (~vclk_vid.run),	        // Reset
            	.B_RST_IN      (~lclk_vid.run),
            	.A_CLK_IN      (VID_CLK_IN),		    // Clock
            	.B_CLK_IN      (LNK_CLK_IN),
            	.A_CKE_IN      (VID_CKE_IN),		    // Clock enable
            	.B_CKE_IN      (1'b1),

            	// Input (A)
                .A_CLR_IN      (vclk_vid.hs_fe),            // Clear
            	.A_WR_IN       (vclk_fifo.wr[i][j]),	    // Write
            	.A_DAT_IN      (vclk_fifo.din[i][j]),		// Write data

            	// Output (B)
            	.B_CLR_IN      (lclk_vid.hs_fe),            // Clear
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
        lclk_ctl.lanes  <= CTL_LANES_IN;
        lclk_ctl.en     <= CTL_EN_IN;
        lclk_ctl.mst    <= CTL_MST_IN;
        
        // The VC length is compensated for the symbols per lane
        lclk_ctl.vc_len <= (P_SPL == 4) ? CTL_VC_LEN_IN[2+:P_VC_LEN] : CTL_VC_LEN_IN[1+:P_VC_LEN];
    end

// Link source 
// To improve the performance, this signal is registered. 
    always_ff @ (posedge LNK_CLK_IN)
    begin
        lclk_src.rd <= LNK_SRC_IF.rd;
    end

// Link source read edge
// This is used to start the burst
    prt_dp_lib_edge
    LNK_SRC_RD_EDGE_INST
    (
        .CLK_IN    (LNK_CLK_IN),        // Clock
        .CKE_IN    (1'b1),              // Clock enable
        .A_IN      (lclk_src.rd),       // Input
        .RE_OUT    (lclk_src.rd_re),    // Rising edge
        .FE_OUT    ()                   // Falling edge
    );

// Run clock domain crossing
    prt_dp_lib_cdc_bit
    LNK_RUN_CDC_INST
    (
        .SRC_CLK_IN     (VID_CLK_IN),       // Clock
        .SRC_DAT_IN     (vclk_vid.run),      // Data
        .DST_CLK_IN     (LNK_CLK_IN),       // Clock
        .DST_DAT_OUT    (lclk_vid.run)       // Data
    );

// Head clock domain crossing
    prt_dp_lib_cdc_gray
    #(
        .P_VENDOR       (P_VENDOR),
        .P_WIDTH        ($size(lclk_fifo.head))
    )
    LNK_HEAD_CDC_INST
    (
        .SRC_CLK_IN     (VID_CLK_IN),         // Clock
        .SRC_DAT_IN     (vclk_fifo.head),     // Data
        .DST_CLK_IN     (LNK_CLK_IN),         // Clock
        .DST_DAT_OUT    (lclk_fifo.head)      // Data
    );

// Mask
// At the start of a new line, the head value is cleared to zero. 
// There is a possible race condition between the head, tail and delta values when this condition occurs. 
// To prevent a false read sequence this mask flag is asserted. 
// This flag is simply a delay of the first FIFO empty signal. 
    always_ff @ (posedge LNK_CLK_IN)
    begin
        lclk_fifo.msk <= {lclk_fifo.msk[0+:$size(lclk_fifo.msk)-1], lclk_fifo.ep[0][0]};
    end

// Tail pointer 
// This logic is only needed in SST 
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Run
        if (lclk_vid.run)
        begin
            // Clear
            if (lclk_vid.hs_fe)
                lclk_fifo.tail <= 0;
            
            // Increment
            else if (lclk_fifo.tail_inc)
                lclk_fifo.tail <= lclk_fifo.tail + 'd1;
        end

        // Idle
        else
            lclk_fifo.tail <= 0;
    end

// Tail increment
    assign lclk_fifo.tail_inc = (lclk_ctl.mst) ? !lclk_lnk.vc_rd_cnt_end : !lclk_lnk.vu_rd_cnt_end;

// Delta
    always_comb
    begin
        if (lclk_fifo.head > lclk_fifo.tail)
            lclk_fifo.delta = lclk_fifo.head - lclk_fifo.tail;
        else
            lclk_fifo.delta = (2**$size(lclk_fifo.tail) - lclk_fifo.tail) + lclk_fifo.head;
    end   

// FIFO ready
// This signal is asserted when the FIFO has enough words to start the initial TU.
// This logic is only needed in SST 
generate
    if (P_STREAM == 0)
    begin : gen_fifo_rdy
        always_ff @ (posedge LNK_CLK_IN)
        begin
            if ((lclk_lnk.vu_len >= 'd1) && (lclk_vid.blnk_evt || lclk_vid.act_evt))
                lclk_lnk.fifo_rdy <= 1;
            else
                lclk_lnk.fifo_rdy <= 0;
        end
    end

    else
        assign lclk_lnk.fifo_rdy = 0;
endgenerate

// VC read counter
// This counter counts the length in a read burst.
// It is used to generate the FIFO read.
// Only used in MST
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // MST
        if (lclk_vid.run && lclk_ctl.mst && lclk_vid.act_evt)
        begin
            // Load
            if (lclk_src.rd_re)
                lclk_lnk.vc_rd_cnt <= lclk_lnk.vc_rd_cnt_in; 

            // Decrement
            else if (!lclk_lnk.vc_rd_cnt_end)
                lclk_lnk.vc_rd_cnt <= lclk_lnk.vc_rd_cnt - 'd1;
        end

        else
            lclk_lnk.vc_rd_cnt <= 0;
    end

// VC read counter end
    always_comb
    begin
        if (lclk_lnk.vc_rd_cnt == 0)
            lclk_lnk.vc_rd_cnt_end = 1;
        else
            lclk_lnk.vc_rd_cnt_end = 0;
    end

// VC read counter in
    always_comb
    begin
        if (lclk_fifo.delta > lclk_ctl.vc_len)
            lclk_lnk.vc_rd_cnt_in = lclk_ctl.vc_len;
        else
            lclk_lnk.vc_rd_cnt_in = lclk_fifo.delta[0+:P_VC_LEN];
    end

// FIFO read
generate
    if (P_SPL == 4)
    begin : gen_fifo_rd_4spl

        always_ff @ (posedge LNK_CLK_IN)
        begin
            // Default
            for (int i = 0; i < P_LANES; i++)
            begin 
                for (int j = 0; j < P_FIFO_STRIPES; j++)
                    lclk_fifo.rd[i][j] <= 0;
            end

            lclk_map.rd <= 0;

            // MST
            if (lclk_ctl.mst)
            begin
                if (!lclk_lnk.vc_rd_cnt_end)
                begin
                    for (int i = 0; i < P_LANES; i++)
                    begin 
                        for (int j = 0; j < P_FIFO_STRIPES; j++)
                            lclk_fifo.rd[i][j] <= 1;
                    end
                end
            end
            
            // SST
            else
            begin

                lclk_map.rd <= 0;

                if (!lclk_lnk.vu_rd_cnt_end)
                begin
                    lclk_map.rd <= 1;

                    // 2 lanes
                    if (lclk_ctl.lanes == 'd2)
                    begin
                        case (lclk_map.rd_sel)
                            'd1 : 
                            begin
                                // Lane 0
                                lclk_fifo.rd[2][1] <= 1;    // G2
                                lclk_fifo.rd[2][2] <= 1;    // B2
                                lclk_fifo.rd[0][3] <= 1;    // R4
                                lclk_fifo.rd[0][0] <= 1;    // G4

                                // Lane 1
                                lclk_fifo.rd[3][1] <= 1;    // G3
                                lclk_fifo.rd[3][2] <= 1;    // B3
                                lclk_fifo.rd[1][3] <= 1;    // R5
                                lclk_fifo.rd[1][0] <= 1;    // G5
                            end

                            'd2 : 
                            begin
                                // Lane 0
                                lclk_fifo.rd[0][1] <= 1;    // B4
                                lclk_fifo.rd[2][3] <= 1;    // R6
                                lclk_fifo.rd[2][0] <= 1;    // G6
                                lclk_fifo.rd[2][1] <= 1;    // B6

                                // Lane 1
                                lclk_fifo.rd[1][1] <= 1;    // B5
                                lclk_fifo.rd[3][3] <= 1;    // R7
                                lclk_fifo.rd[3][0] <= 1;    // G7
                                lclk_fifo.rd[3][1] <= 1;    // B7
                            end

                            'd3 : 
                            begin
                                // Lane 0
                                lclk_fifo.rd[0][2] <= 1;    // R8
                                lclk_fifo.rd[0][3] <= 1;    // G8
                                lclk_fifo.rd[0][0] <= 1;    // B8
                                lclk_fifo.rd[2][2] <= 1;    // R10

                                // Lane 1
                                lclk_fifo.rd[1][2] <= 1;    // R9
                                lclk_fifo.rd[1][3] <= 1;    // G9
                                lclk_fifo.rd[1][0] <= 1;    // B9
                                lclk_fifo.rd[3][2] <= 1;    // R11
                            end

                            'd4 : 
                            begin
                                // Lane 0
                                lclk_fifo.rd[2][3] <= 1;    // G10
                                lclk_fifo.rd[2][0] <= 1;    // B10
                                lclk_fifo.rd[0][1] <= 1;    // R12
                                lclk_fifo.rd[0][2] <= 1;    // G12

                                // Lane 1
                                lclk_fifo.rd[3][3] <= 1;    // G11
                                lclk_fifo.rd[3][0] <= 1;    // B11
                                lclk_fifo.rd[1][1] <= 1;    // R13
                                lclk_fifo.rd[1][2] <= 1;    // G13
                            end

                            'd5 : 
                            begin
                                // Lane 0
                                lclk_fifo.rd[0][3] <= 1;    // B12
                                lclk_fifo.rd[2][1] <= 1;    // R14
                                lclk_fifo.rd[2][2] <= 1;    // G14
                                lclk_fifo.rd[2][3] <= 1;    // B14

                                // Lane 1
                                lclk_fifo.rd[1][3] <= 1;    // B13
                                lclk_fifo.rd[3][1] <= 1;    // R15
                                lclk_fifo.rd[3][2] <= 1;    // G15
                                lclk_fifo.rd[3][3] <= 1;    // B15
                            end

                            default : 
                            begin
                                // Lane 0
                                lclk_fifo.rd[0][0] <= 1;    // R0
                                lclk_fifo.rd[0][1] <= 1;    // G0
                                lclk_fifo.rd[0][2] <= 1;    // B0
                                lclk_fifo.rd[2][0] <= 1;    // R2

                                // Lane 1
                                lclk_fifo.rd[1][0] <= 1;    // R1
                                lclk_fifo.rd[1][1] <= 1;    // G1
                                lclk_fifo.rd[1][2] <= 1;    // B1
                                lclk_fifo.rd[3][0] <= 1;    // R3
                            end
                        endcase
                    end

                    // 1 lane
                    else if (lclk_ctl.lanes == 'd1)
                    begin
                        case (lclk_map.rd_sel)
                            'd1 : 
                            begin
                                lclk_fifo.rd[1][1] <= 1;    // G1
                                lclk_fifo.rd[1][2] <= 1;    // B1
                                lclk_fifo.rd[2][0] <= 1;    // R2
                                lclk_fifo.rd[2][1] <= 1;    // G2
                            end

                            'd2 : 
                            begin
                                lclk_fifo.rd[2][2] <= 1;    // B2
                                lclk_fifo.rd[3][0] <= 1;    // R3
                                lclk_fifo.rd[3][1] <= 1;    // G3
                                lclk_fifo.rd[3][2] <= 1;    // B3
                            end

                            'd3 : 
                            begin
                                lclk_fifo.rd[0][3] <= 1;    // R4
                                lclk_fifo.rd[0][0] <= 1;    // G4
                                lclk_fifo.rd[0][1] <= 1;    // B4
                                lclk_fifo.rd[1][3] <= 1;    // R5
                            end

                            'd4 : 
                            begin
                                lclk_fifo.rd[1][0] <= 1;    // G5
                                lclk_fifo.rd[1][1] <= 1;    // B5
                                lclk_fifo.rd[2][3] <= 1;    // R6
                                lclk_fifo.rd[2][0] <= 1;    // G6
                            end

                            'd5 : 
                            begin
                                lclk_fifo.rd[2][1] <= 1;    // B6
                                lclk_fifo.rd[3][3] <= 1;    // R7
                                lclk_fifo.rd[3][0] <= 1;    // G7
                                lclk_fifo.rd[3][1] <= 1;    // B7
                            end

                            'd6 : 
                            begin
                                lclk_fifo.rd[0][2] <= 1;    // R8
                                lclk_fifo.rd[0][3] <= 1;    // G8
                                lclk_fifo.rd[0][0] <= 1;    // B8
                                lclk_fifo.rd[1][2] <= 1;    // R9
                            end

                            'd7 : 
                            begin
                                lclk_fifo.rd[1][3] <= 1;    // G9
                                lclk_fifo.rd[1][0] <= 1;    // B9
                                lclk_fifo.rd[2][2] <= 1;    // R10
                                lclk_fifo.rd[2][3] <= 1;    // G10
                            end

                            'd8 : 
                            begin
                                lclk_fifo.rd[2][0] <= 1;    // B10
                                lclk_fifo.rd[3][2] <= 1;    // R11
                                lclk_fifo.rd[3][3] <= 1;    // G11
                                lclk_fifo.rd[3][0] <= 1;    // B11
                            end

                            'd9 : 
                            begin
                                lclk_fifo.rd[0][1] <= 1;    // R12
                                lclk_fifo.rd[0][2] <= 1;    // G12
                                lclk_fifo.rd[0][3] <= 1;    // B12
                                lclk_fifo.rd[1][1] <= 1;    // R13
                            end

                            'd10 : 
                            begin
                                lclk_fifo.rd[1][2] <= 1;    // G13
                                lclk_fifo.rd[1][3] <= 1;    // B13
                                lclk_fifo.rd[2][1] <= 1;    // R14
                                lclk_fifo.rd[2][2] <= 1;    // G14
                            end

                            'd11 : 
                            begin
                                lclk_fifo.rd[2][3] <= 1;    // B14
                                lclk_fifo.rd[3][1] <= 1;    // R15
                                lclk_fifo.rd[3][2] <= 1;    // G15
                                lclk_fifo.rd[3][3] <= 1;    // B15
                            end

                            default : 
                            begin
                                lclk_fifo.rd[0][0] <= 1;    // R0
                                lclk_fifo.rd[0][1] <= 1;    // G0
                                lclk_fifo.rd[0][2] <= 1;    // B0
                                lclk_fifo.rd[1][0] <= 1;    // R1
                            end
                        endcase
                    end

                    // 4 lanes
                    else
                    begin
                        for (int i = 0; i < P_LANES; i++)
                        begin 
                            for (int j = 0; j < P_FIFO_STRIPES; j++)
                                lclk_fifo.rd[i][j] <= 1;
                        end
                    end
                end
            end
        end
    end

    else
    begin : gen_fifo_rd_2spl
        always_ff @ (posedge LNK_CLK_IN)
        begin
            // Default
            for (int i = 0; i < P_LANES; i++)
            begin 
                for (int j = 0; j < P_FIFO_STRIPES; j++)
                    lclk_fifo.rd[i][j] <= 0;
            end

            lclk_map.rd <= 0;

            if (!lclk_lnk.vu_rd_cnt_end)
            begin
                lclk_map.rd <= 1;

                // 2 lanes
                if (lclk_ctl.lanes == 'd2)
                begin
                    case (lclk_map.rd_sel)
                        'd1 : 
                        begin
                            // Lane 0
                            lclk_fifo.rd[0][2] <= 1;    // B0
                            lclk_fifo.rd[2][0] <= 1;    // R2

                            // Lane 1
                            lclk_fifo.rd[1][2] <= 1;    // B1
                            lclk_fifo.rd[3][0] <= 1;    // R3
                        end

                        'd2 : 
                        begin
                            // Lane 0
                            lclk_fifo.rd[2][1] <= 1;    // G2
                            lclk_fifo.rd[2][2] <= 1;    // B2

                            // Lane 1
                            lclk_fifo.rd[3][1] <= 1;    // G3
                            lclk_fifo.rd[3][2] <= 1;    // B3
                        end

                        'd3 : 
                        begin
                            // Lane 0
                            lclk_fifo.rd[0][3] <= 1;    // R4
                            lclk_fifo.rd[0][0] <= 1;    // G4

                            // Lane 1
                            lclk_fifo.rd[1][3] <= 1;    // R5
                            lclk_fifo.rd[1][0] <= 1;    // G5
                        end

                        'd4 : 
                        begin
                            // Lane 0
                            lclk_fifo.rd[0][1] <= 1;    // B4
                            lclk_fifo.rd[2][3] <= 1;    // R6

                            // Lane 1
                            lclk_fifo.rd[1][1] <= 1;    // B5
                            lclk_fifo.rd[3][3] <= 1;    // R7
                        end

                        'd5 : 
                        begin
                            // Lane 0
                            lclk_fifo.rd[2][0] <= 1;    // G6
                            lclk_fifo.rd[2][1] <= 1;    // B6

                            // Lane 1
                            lclk_fifo.rd[3][0] <= 1;    // G7
                            lclk_fifo.rd[3][1] <= 1;    // B7
                        end

                        'd6 : 
                        begin
                            // Lane 0
                            lclk_fifo.rd[0][2] <= 1;    // R8
                            lclk_fifo.rd[0][3] <= 1;    // G8

                            // Lane 1
                            lclk_fifo.rd[1][2] <= 1;    // R9
                            lclk_fifo.rd[1][3] <= 1;    // G9
                        end

                        'd7 : 
                        begin
                            // Lane 0
                            lclk_fifo.rd[0][0] <= 1;    // B8
                            lclk_fifo.rd[2][2] <= 1;    // R10

                            // Lane 1
                            lclk_fifo.rd[1][0] <= 1;    // B9
                            lclk_fifo.rd[3][2] <= 1;    // R11
                        end

                        'd8 : 
                        begin
                            // Lane 0
                            lclk_fifo.rd[2][3] <= 1;    // G10
                            lclk_fifo.rd[2][0] <= 1;    // B10

                            // Lane 1
                            lclk_fifo.rd[3][3] <= 1;    // G11
                            lclk_fifo.rd[3][0] <= 1;    // B11
                        end

                        'd9 : 
                        begin
                            // Lane 0
                            lclk_fifo.rd[0][1] <= 1;    // R12
                            lclk_fifo.rd[0][2] <= 1;    // G12

                            // Lane 1
                            lclk_fifo.rd[1][1] <= 1;    // R13
                            lclk_fifo.rd[1][2] <= 1;    // G13
                        end

                        'd10 : 
                        begin
                            // Lane 0
                            lclk_fifo.rd[0][3] <= 1;    // B12
                            lclk_fifo.rd[2][1] <= 1;    // R14

                            // Lane 1
                            lclk_fifo.rd[1][3] <= 1;    // B13
                            lclk_fifo.rd[3][1] <= 1;    // R15
                        end

                        'd11 : 
                        begin
                            // Lane 0
                            lclk_fifo.rd[2][2] <= 1;    // G14
                            lclk_fifo.rd[2][3] <= 1;    // B14

                            // Lane 1
                            lclk_fifo.rd[3][2] <= 1;    // G15
                            lclk_fifo.rd[3][3] <= 1;    // B15
                        end

                        default : 
                        begin
                            // Lane 0
                            lclk_fifo.rd[0][0] <= 1;    // R0
                            lclk_fifo.rd[0][1] <= 1;    // G0

                            // Lane 1
                            lclk_fifo.rd[1][0] <= 1;    // R1
                            lclk_fifo.rd[1][1] <= 1;    // G1
                        end
                    endcase
                end

                // 1 lane
                else if (lclk_ctl.lanes == 'd1)
                begin
                    case (lclk_map.rd_sel)
                        'd1 : 
                        begin
                            lclk_fifo.rd[0][2] <= 1;    // B0
                            lclk_fifo.rd[1][0] <= 1;    // R1
                        end

                        'd2 : 
                        begin
                            lclk_fifo.rd[1][1] <= 1;    // G1
                            lclk_fifo.rd[1][2] <= 1;    // B1
                        end

                        'd3 : 
                        begin
                            lclk_fifo.rd[2][0] <= 1;    // R2
                            lclk_fifo.rd[2][1] <= 1;    // G2
                        end

                        'd4 : 
                        begin
                            lclk_fifo.rd[2][2] <= 1;    // B2
                            lclk_fifo.rd[3][0] <= 1;    // R3
                        end

                        'd5 : 
                        begin
                            lclk_fifo.rd[3][1] <= 1;    // G3
                            lclk_fifo.rd[3][2] <= 1;    // B3
                        end

                        'd6 : 
                        begin
                            lclk_fifo.rd[0][3] <= 1;    // R4
                            lclk_fifo.rd[0][0] <= 1;    // G4
                        end

                        'd7 : 
                        begin
                            lclk_fifo.rd[0][1] <= 1;    // B4
                            lclk_fifo.rd[1][3] <= 1;    // R5
                        end

                        'd8 : 
                        begin
                            lclk_fifo.rd[1][0] <= 1;    // G5
                            lclk_fifo.rd[1][1] <= 1;    // B5
                        end

                        'd9 : 
                        begin
                            lclk_fifo.rd[2][3] <= 1;    // R6
                            lclk_fifo.rd[2][0] <= 1;    // G6
                        end

                        'd10 : 
                        begin
                            lclk_fifo.rd[2][1] <= 1;    // B6
                            lclk_fifo.rd[3][3] <= 1;    // R7
                        end

                        'd11 : 
                        begin
                            lclk_fifo.rd[3][0] <= 1;    // G7
                            lclk_fifo.rd[3][1] <= 1;    // B7
                        end

                        'd12 : 
                        begin
                            lclk_fifo.rd[0][2] <= 1;    // R8
                            lclk_fifo.rd[0][3] <= 1;    // G8
                        end

                        'd13 : 
                        begin
                            lclk_fifo.rd[0][0] <= 1;    // B8
                            lclk_fifo.rd[1][2] <= 1;    // R9
                        end

                        'd14 : 
                        begin
                            lclk_fifo.rd[1][3] <= 1;    // G9
                            lclk_fifo.rd[1][0] <= 1;    // B9
                        end

                        'd15 : 
                        begin
                            lclk_fifo.rd[2][2] <= 1;    // R10
                            lclk_fifo.rd[2][3] <= 1;    // G10
                        end

                        'd16 : 
                        begin
                            lclk_fifo.rd[2][0] <= 1;    // B10
                            lclk_fifo.rd[3][2] <= 1;    // R11
                        end

                        'd17 : 
                        begin
                            lclk_fifo.rd[3][3] <= 1;    // G11
                            lclk_fifo.rd[3][0] <= 1;    // B11
                        end

                        'd18 : 
                        begin
                            lclk_fifo.rd[0][1] <= 1;    // R12
                            lclk_fifo.rd[0][2] <= 1;    // G12
                        end

                        'd19 : 
                        begin
                            lclk_fifo.rd[0][3] <= 1;    // B12
                            lclk_fifo.rd[1][1] <= 1;    // R13
                        end

                        'd20 : 
                        begin
                            lclk_fifo.rd[1][2] <= 1;    // G13
                            lclk_fifo.rd[1][3] <= 1;    // B13
                        end

                        'd21 : 
                        begin
                            lclk_fifo.rd[2][1] <= 1;    // R14
                            lclk_fifo.rd[2][2] <= 1;    // G14
                        end

                        'd22 : 
                        begin
                            lclk_fifo.rd[2][3] <= 1;    // B14
                            lclk_fifo.rd[3][1] <= 1;    // R15
                        end

                        'd23 : 
                        begin
                            lclk_fifo.rd[3][2] <= 1;    // G15
                            lclk_fifo.rd[3][3] <= 1;    // B15
                        end

                        default : 
                        begin
                            lclk_fifo.rd[0][0] <= 1;    // R0
                            lclk_fifo.rd[0][1] <= 1;    // G0
                        end
                    endcase
                end

                // 4 lanes
                else
                begin
                    if (lclk_map.rd_sel == 'd1)
                    begin
                        for (int i = 0; i < P_LANES; i++)
                        begin 
                            lclk_fifo.rd[i][2] <= 1;
                            lclk_fifo.rd[i][3] <= 1;
                        end
                    end

                    else
                    begin
                        for (int i = 0; i < P_LANES; i++)
                        begin 
                            lclk_fifo.rd[i][0] <= 1;
                            lclk_fifo.rd[i][1] <= 1;
                        end
                    end
                end
            end
        end
    end
endgenerate

// Vsync clock domain crossing
    prt_dp_lib_cdc_bit
    LNK_VS_CDC_INST
    (
        .SRC_CLK_IN     (VID_CLK_IN),       // Clock
        .SRC_DAT_IN     (vclk_vid.vs),      // Data
        .DST_CLK_IN     (LNK_CLK_IN),       // Clock
        .DST_DAT_OUT    (lclk_vid.vs)       // Data
    );

// Vsync clock domain crossing
    prt_dp_lib_cdc_bit
    LNK_HS_CDC_INST
    (
        .SRC_CLK_IN     (VID_CLK_IN),       // Clock
        .SRC_DAT_IN     (vclk_vid.hs),      // Data
        .DST_CLK_IN     (LNK_CLK_IN),       // Clock
        .DST_DAT_OUT    (lclk_vid.hs)       // Data
    );

// Vertical blanking flag clock domain crossing
    prt_dp_lib_cdc_bit
    LNK_VBF_CDC_INST
    (
        .SRC_CLK_IN     (VID_CLK_IN),       // Clock
        .SRC_DAT_IN     (vclk_vid.vbf),     // Data
        .DST_CLK_IN     (LNK_CLK_IN),       // Clock
        .DST_DAT_OUT    (lclk_vid.vbf)      // Data
    );

// Video active clock domain crossing
    prt_dp_lib_cdc_bit
    LNK_VID_ACT_CDC_INST
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
    LNK_VID_BLNK_CDC_INST
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

// Hsync edge
    prt_dp_lib_edge
    LNK_HS_EDGE_INST
    (
        .CLK_IN         (LNK_CLK_IN),       // Clock
        .CKE_IN         (1'b1),             // Clock enable
        .A_IN           (lclk_vid.hs),      // Input
        .RE_OUT         (),                // Rising edge
        .FE_OUT         (lclk_vid.hs_fe)    // Falling edge
    );

// Video active event
// This flag is asserted when there is an active video line.
// The flag is sticky.
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Run
        if (lclk_vid.run)
        begin
            // Clear
            if (lclk_map.bs[1] || lclk_vid.hs_fe)
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
        // Run
        if (lclk_vid.run)
        begin
            // Clear
            if (lclk_map.bs[1] || lclk_vid.hs_fe)
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
// This flag is asserted when the blanking start bit is set in the fifo.
    always_comb
    begin
        // MST
        if (lclk_ctl.mst)
        begin
            if (lclk_fifo.de[0][1] && lclk_fifo.dout[0][1][P_FIFO_DAT-1])
                lclk_lnk.bs = 1;
            else
                lclk_lnk.bs = 0;
        end

        // SST
        else
        begin
            if (lclk_fifo.de[P_LANES-1][P_FIFO_STRIPES-1] && lclk_fifo.dout[P_LANES-1][P_FIFO_STRIPES-1][P_FIFO_DAT-1])
                lclk_lnk.bs = 1;
            else
                lclk_lnk.bs = 0;
        end
    end

// Blanking end
// This flag is asserted when the blanking start bit is set in the first stripe of the first fifo
    always_comb
    begin
        if (lclk_fifo.de[0][0] && lclk_fifo.dout[0][0][P_FIFO_DAT-1])
            lclk_lnk.be = 1;
        else
            lclk_lnk.be = 0;
    end

// Transfer unit run
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Run (only in SST)
        if (lclk_vid.run && !lclk_ctl.mst)
        begin
            // Clear 
            if (lclk_map.bs[1] || lclk_vid.hs_fe)
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
        // Run
        if (lclk_lnk.tu_run)
        begin

            // Load
            if (lclk_lnk.tu_cnt_end || lclk_lnk.tu_cnt_last)
                lclk_lnk.tu_cnt <= P_TU_CNT_LD;

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
// Todo: check all modes
// This logic is only needed in SST
generate
    if (P_STREAM == 0)
    begin : gen_vu_len
        if (P_SPL == 4)
        begin : gen_vu_len_4spl
            always_ff @ (posedge LNK_CLK_IN)
            begin
                lclk_lnk.vu_len <= lclk_fifo.delta[0+:$size(lclk_lnk.vu_len)];
            end
        end

        else
        begin : gen_vu_len_2spl
            always_ff @ (posedge LNK_CLK_IN)
            begin
                lclk_lnk.vu_len <= lclk_fifo.delta[0+:$size(lclk_lnk.vu_len)];
            end
        end
    end

    else
        assign lclk_lnk.vu_len = 0;
endgenerate

// Video data read counter
// This counter counts video symbols in a transfer unit during read
// This logic is only needed in SST
generate
    if (P_STREAM == 0)
    begin : gen_vu_rd_cnt
        always_ff @ (posedge LNK_CLK_IN)
        begin
            // Run
            if (lclk_lnk.tu_run)
            begin    
                // Load
                if (lclk_lnk.tu_cnt == P_TU_CNT_LD)
                    lclk_lnk.vu_rd_cnt <= lclk_lnk.vu_len;

                // Decrement
                else if (!lclk_lnk.vu_rd_cnt_end)
                    lclk_lnk.vu_rd_cnt <= lclk_lnk.vu_rd_cnt - 1;
            end

            // Idle
            else
                lclk_lnk.vu_rd_cnt <= 0;
        end
    end

    else
        assign lclk_lnk.vu_rd_cnt = 0;
endgenerate

// Video data read counter end
    always_comb
    begin
        if (lclk_lnk.vu_rd_cnt == 0)
            lclk_lnk.vu_rd_cnt_end = 1;
        else
            lclk_lnk.vu_rd_cnt_end = 0;
    end


/*
    Mapper
*/

// Read select
// This counter drives the FIFO read signals
generate
    if (P_STREAM == 0)
    begin : gen_map_rd_sel
        if (P_SPL == 4)
        begin : gen_map_rd_sel_4spl

            always_ff @ (posedge LNK_CLK_IN)
            begin
                // Run
                if (lclk_lnk.tu_run)
                begin   
                    // 1 lane or 2 lanes
                    if ((lclk_ctl.lanes == 'd1) || (lclk_ctl.lanes == 'd2))
                    begin
                        // Increment 
                        if (!lclk_lnk.vu_rd_cnt_end)
                        begin
                            // Overflow
                            if ( ((lclk_ctl.lanes == 'd1) && (lclk_map.rd_sel >= 'd11)) || ((lclk_ctl.lanes == 'd2) && (lclk_map.rd_sel >= 'd5)) )
                                lclk_map.rd_sel <= 0;
                            else
                                lclk_map.rd_sel <= lclk_map.rd_sel + 'd1;
                        end
                    end

                    // 4 lanes
                    else
                        lclk_map.rd_sel <= 0;
                end

                // Idle
                else
                    lclk_map.rd_sel <= 0;
            end
        end

        else
        begin : gen_map_rd_sel_2spl
            always_ff @ (posedge LNK_CLK_IN)
            begin
                // Run
                if (lclk_lnk.tu_run)
                begin   
                    // Increment 
                    if (!lclk_lnk.vu_rd_cnt_end)
                    begin
                        // Overflow
                        if ( ((lclk_ctl.lanes == 'd1) && (lclk_map.rd_sel >= 'd23)) || ((lclk_ctl.lanes == 'd2) && (lclk_map.rd_sel >= 'd11)) || ((lclk_ctl.lanes == 'd3) && (lclk_map.rd_sel >= 'd1)))
                            lclk_map.rd_sel <= 0;
                        else
                            lclk_map.rd_sel <= lclk_map.rd_sel + 'd1;
                    end
                end

                // Idle
                else
                    lclk_map.rd_sel <= 0;
            end

        end
    end

    else
        assign lclk_map.rd_sel = 0;
endgenerate

// Data select
// The FIFO has a two clock latency
// This logic is only needed in SST
generate
    if (P_STREAM == 0)
    begin : gen_map_dat_sel
        always_ff @ (posedge LNK_CLK_IN)
        begin
            for (int i = 0; i < $size(lclk_map.dat_sel); i++)
            begin
                if (i == 0)
                    lclk_map.dat_sel[i] <= lclk_map.rd_sel;
                else
                    lclk_map.dat_sel[i] <= lclk_map.dat_sel[i-1];
            end
        end
    end

    else
    begin
        for (i = 0; i < $size(lclk_map.dat_sel); i++)
        begin
            assign lclk_map.dat_sel[i] = 0;
        end
    end
endgenerate

// Data
generate
    if (P_STREAM == 0)
    begin : gen_map_dat

        if (P_SPL == 4)
        begin : gen_map_dat_4spl

            always_ff @ (posedge LNK_CLK_IN)
            begin
                // 2 lane
                if (lclk_ctl.lanes == 'd2)
                begin
                    // Inactive lanes
                    for (int i = 2; i < P_LANES; i++)
                    begin 
                        for (int j = 0; j < P_SPL; j++)
                            lclk_map.dat[i][j] <= 0;
                    end

                    case (lclk_map.dat_sel[$size(lclk_map.dat_sel)-1])
                        'd1 : 
                        begin
                            // Lane 0
                            lclk_map.dat[0][0] <= lclk_fifo.dout[2][1];    // G2
                            lclk_map.dat[0][1] <= lclk_fifo.dout[2][2];    // B2
                            lclk_map.dat[0][2] <= lclk_fifo.dout[0][3];    // R4
                            lclk_map.dat[0][3] <= lclk_fifo.dout[0][0];    // G4

                            // Lane 1
                            lclk_map.dat[1][0] <= lclk_fifo.dout[3][1];    // G3
                            lclk_map.dat[1][1] <= lclk_fifo.dout[3][2];    // B3
                            lclk_map.dat[1][2] <= lclk_fifo.dout[1][3];    // R5
                            lclk_map.dat[1][3] <= lclk_fifo.dout[1][0];    // G5
                        end

                        'd2 : 
                        begin
                            // Lane 0
                            lclk_map.dat[0][0] <= lclk_fifo.dout[0][1];    // B4
                            lclk_map.dat[0][1] <= lclk_fifo.dout[2][3];    // R6
                            lclk_map.dat[0][2] <= lclk_fifo.dout[2][0];    // G6
                            lclk_map.dat[0][3] <= lclk_fifo.dout[2][1];    // B6

                            // Lane 1
                            lclk_map.dat[1][0] <= lclk_fifo.dout[1][1];    // B5
                            lclk_map.dat[1][1] <= lclk_fifo.dout[3][3];    // R7
                            lclk_map.dat[1][2] <= lclk_fifo.dout[3][0];    // G7
                            lclk_map.dat[1][3] <= lclk_fifo.dout[3][1];    // B7
                        end

                        'd3 : 
                        begin
                            // Lane 0
                            lclk_map.dat[0][0] <= lclk_fifo.dout[0][2];    // R8
                            lclk_map.dat[0][1] <= lclk_fifo.dout[0][3];    // G8
                            lclk_map.dat[0][2] <= lclk_fifo.dout[0][0];    // B8
                            lclk_map.dat[0][3] <= lclk_fifo.dout[2][2];    // R10

                            // Lane 1
                            lclk_map.dat[1][0] <= lclk_fifo.dout[1][2];    // R9
                            lclk_map.dat[1][1] <= lclk_fifo.dout[1][3];    // G9
                            lclk_map.dat[1][2] <= lclk_fifo.dout[1][0];    // B9
                            lclk_map.dat[1][3] <= lclk_fifo.dout[3][2];    // R11
                        end

                        'd4 : 
                        begin
                            // Lane 0
                            lclk_map.dat[0][0] <= lclk_fifo.dout[2][3];    // G10
                            lclk_map.dat[0][1] <= lclk_fifo.dout[2][0];    // B10
                            lclk_map.dat[0][2] <= lclk_fifo.dout[0][1];    // R12
                            lclk_map.dat[0][3] <= lclk_fifo.dout[0][2];    // G12

                            // Lane 1
                            lclk_map.dat[1][0] <= lclk_fifo.dout[3][3];    // G11
                            lclk_map.dat[1][1] <= lclk_fifo.dout[3][0];    // B11
                            lclk_map.dat[1][2] <= lclk_fifo.dout[1][1];    // R13
                            lclk_map.dat[1][3] <= lclk_fifo.dout[1][2];    // G13
                        end

                        'd5 : 
                        begin
                            // Lane 0
                            lclk_map.dat[0][0] <= lclk_fifo.dout[0][3];    // B12
                            lclk_map.dat[0][1] <= lclk_fifo.dout[2][1];    // R14
                            lclk_map.dat[0][2] <= lclk_fifo.dout[2][2];    // G14
                            lclk_map.dat[0][3] <= lclk_fifo.dout[2][3];    // B14

                            // Lane 1
                            lclk_map.dat[1][0] <= lclk_fifo.dout[1][3];    // B13
                            lclk_map.dat[1][1] <= lclk_fifo.dout[3][1];    // R15
                            lclk_map.dat[1][2] <= lclk_fifo.dout[3][2];    // G15
                            lclk_map.dat[1][3] <= lclk_fifo.dout[3][3];    // B15
                        end

                        default : 
                        begin
                            // Lane 0
                            lclk_map.dat[0][0] <= lclk_fifo.dout[0][0];    // R0
                            lclk_map.dat[0][1] <= lclk_fifo.dout[0][1];    // G0
                            lclk_map.dat[0][2] <= lclk_fifo.dout[0][2];    // B0
                            lclk_map.dat[0][3] <= lclk_fifo.dout[2][0];    // R2

                            // Lane 1
                            lclk_map.dat[1][0] <= lclk_fifo.dout[1][0];    // R1
                            lclk_map.dat[1][1] <= lclk_fifo.dout[1][1];    // G1
                            lclk_map.dat[1][2] <= lclk_fifo.dout[1][2];    // B1
                            lclk_map.dat[1][3] <= lclk_fifo.dout[3][0];    // R3
                        end
                    endcase
                end

                // 1 lane
                else if (lclk_ctl.lanes == 'd1)
                begin
                    // Inactive lanes
                    for (int i = 1; i < P_LANES; i++)
                    begin 
                        for (int j = 0; j < P_SPL; j++)
                            lclk_map.dat[i][j] <= 0;
                    end

                    case (lclk_map.dat_sel[$size(lclk_map.dat_sel)-1])
                        'd1 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[1][1];    // G1
                            lclk_map.dat[0][1] <= lclk_fifo.dout[1][2];    // B1
                            lclk_map.dat[0][2] <= lclk_fifo.dout[2][0];    // R2
                            lclk_map.dat[0][3] <= lclk_fifo.dout[2][1];    // G2
                        end

                        'd2 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[2][2];    // B2
                            lclk_map.dat[0][1] <= lclk_fifo.dout[3][0];    // R3
                            lclk_map.dat[0][2] <= lclk_fifo.dout[3][1];    // G3
                            lclk_map.dat[0][3] <= lclk_fifo.dout[3][2];    // B3
                        end

                        'd3 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[0][3];    // R4
                            lclk_map.dat[0][1] <= lclk_fifo.dout[0][0];    // G4
                            lclk_map.dat[0][2] <= lclk_fifo.dout[0][1];    // B4
                            lclk_map.dat[0][3] <= lclk_fifo.dout[1][3];    // R5
                        end

                        'd4 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[1][0];    // G5
                            lclk_map.dat[0][1] <= lclk_fifo.dout[1][1];    // B5
                            lclk_map.dat[0][2] <= lclk_fifo.dout[2][3];    // R6
                            lclk_map.dat[0][3] <= lclk_fifo.dout[2][0];    // G6
                        end

                        'd5 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[2][1];    // B6
                            lclk_map.dat[0][1] <= lclk_fifo.dout[3][3];    // R7
                            lclk_map.dat[0][2] <= lclk_fifo.dout[3][0];    // G7
                            lclk_map.dat[0][3] <= lclk_fifo.dout[3][1];    // B7
                        end

                        'd6 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[0][2];    // R8
                            lclk_map.dat[0][1] <= lclk_fifo.dout[0][3];    // G8
                            lclk_map.dat[0][2] <= lclk_fifo.dout[0][0];    // B8
                            lclk_map.dat[0][3] <= lclk_fifo.dout[1][2];    // R9
                        end

                        'd7 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[1][3];    // G9
                            lclk_map.dat[0][1] <= lclk_fifo.dout[1][0];    // B9
                            lclk_map.dat[0][2] <= lclk_fifo.dout[2][2];    // R10
                            lclk_map.dat[0][3] <= lclk_fifo.dout[2][3];    // G10
                        end

                        'd8 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[2][0];    // B10
                            lclk_map.dat[0][1] <= lclk_fifo.dout[3][2];    // R11
                            lclk_map.dat[0][2] <= lclk_fifo.dout[3][3];    // G11
                            lclk_map.dat[0][3] <= lclk_fifo.dout[3][0];    // B11
                        end

                        'd9 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[0][1];    // R12
                            lclk_map.dat[0][1] <= lclk_fifo.dout[0][2];    // G12
                            lclk_map.dat[0][2] <= lclk_fifo.dout[0][3];    // B12
                            lclk_map.dat[0][3] <= lclk_fifo.dout[1][1];    // R13
                        end

                        'd10 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[1][2];    // G13
                            lclk_map.dat[0][1] <= lclk_fifo.dout[1][3];    // B13
                            lclk_map.dat[0][2] <= lclk_fifo.dout[2][1];    // R14
                            lclk_map.dat[0][3] <= lclk_fifo.dout[2][2];    // G14
                        end

                        'd11 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[2][3];    // B14
                            lclk_map.dat[0][1] <= lclk_fifo.dout[3][1];    // R15
                            lclk_map.dat[0][2] <= lclk_fifo.dout[3][2];    // G15
                            lclk_map.dat[0][3] <= lclk_fifo.dout[3][3];    // B15
                        end

                        default : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[0][0];    // R0
                            lclk_map.dat[0][1] <= lclk_fifo.dout[0][1];    // G0
                            lclk_map.dat[0][2] <= lclk_fifo.dout[0][2];    // B0
                            lclk_map.dat[0][3] <= lclk_fifo.dout[1][0];    // R1
                        end
                    endcase
                end

                // 4 lanes
                else
                begin
                    for (int i = 0; i < P_LANES; i++)
                    begin 
                        for (int j = 0; j < P_SPL; j++)
                            lclk_map.dat[i][j] <= lclk_fifo.dout[i][j];
                    end
                end
            end
        end

        else
        begin : gen_map_dat_2spl

            always_ff @ (posedge LNK_CLK_IN)
            begin
                // 2 lane
                if (lclk_ctl.lanes == 'd2)
                begin
                    // Inactive lanes
                    for (int i = 2; i < P_LANES; i++)
                    begin 
                        for (int j = 0; j < P_SPL; j++)
                            lclk_map.dat[i][j] <= 0;
                    end

                    case (lclk_map.dat_sel[$size(lclk_map.dat_sel)-1])

                        'd1 : 
                        begin
                            // Lane 0
                            lclk_map.dat[0][0] <= lclk_fifo.dout[0][2];    // B0
                            lclk_map.dat[0][1] <= lclk_fifo.dout[2][0];    // R2

                            // Lane 1
                            lclk_map.dat[1][0] <= lclk_fifo.dout[1][2];    // B1
                            lclk_map.dat[1][1] <= lclk_fifo.dout[3][0];    // R3
                        end

                        'd2 : 
                        begin
                            // Lane 0
                            lclk_map.dat[0][0] <= lclk_fifo.dout[2][1];    // G2
                            lclk_map.dat[0][1] <= lclk_fifo.dout[2][2];    // B2

                            // Lane 1
                            lclk_map.dat[1][0] <= lclk_fifo.dout[3][1];    // G3
                            lclk_map.dat[1][1] <= lclk_fifo.dout[3][2];    // B3
                        end

                        'd3 : 
                        begin
                            // Lane 0
                            lclk_map.dat[0][0] <= lclk_fifo.dout[0][3];    // R4
                            lclk_map.dat[0][1] <= lclk_fifo.dout[0][0];    // G4

                            // Lane 1
                            lclk_map.dat[1][0] <= lclk_fifo.dout[1][3];    // R5
                            lclk_map.dat[1][1] <= lclk_fifo.dout[1][0];    // G5
                        end

                        'd4 : 
                        begin
                            // Lane 0
                            lclk_map.dat[0][0] <= lclk_fifo.dout[0][1];    // B4
                            lclk_map.dat[0][1] <= lclk_fifo.dout[2][3];    // R6

                            // Lane 1
                            lclk_map.dat[1][0] <= lclk_fifo.dout[1][1];    // B5
                            lclk_map.dat[1][1] <= lclk_fifo.dout[3][3];    // R7
                        end

                        'd5 : 
                        begin
                            // Lane 0
                            lclk_map.dat[0][0] <= lclk_fifo.dout[2][0];    // G6
                            lclk_map.dat[0][1] <= lclk_fifo.dout[2][1];    // B6

                            // Lane 1
                            lclk_map.dat[1][0] <= lclk_fifo.dout[3][0];    // G7
                            lclk_map.dat[1][1] <= lclk_fifo.dout[3][1];    // B7
                        end

                        'd6 : 
                        begin
                            // Lane 0
                            lclk_map.dat[0][0] <= lclk_fifo.dout[0][2];    // R8
                            lclk_map.dat[0][1] <= lclk_fifo.dout[0][3];    // G8

                            // Lane 1
                            lclk_map.dat[1][0] <= lclk_fifo.dout[1][2];    // R9
                            lclk_map.dat[1][1] <= lclk_fifo.dout[1][3];    // G9
                        end

                        'd7 : 
                        begin
                            // Lane 0
                            lclk_map.dat[0][0] <= lclk_fifo.dout[0][0];    // B8
                            lclk_map.dat[0][1] <= lclk_fifo.dout[2][2];    // R10

                            // Lane 1
                            lclk_map.dat[1][0] <= lclk_fifo.dout[1][0];    // B9
                            lclk_map.dat[1][1] <= lclk_fifo.dout[3][2];    // R11
                        end

                        'd8 : 
                        begin
                            // Lane 0
                            lclk_map.dat[0][0] <= lclk_fifo.dout[2][3];    // G10
                            lclk_map.dat[0][1] <= lclk_fifo.dout[2][0];    // B10

                            // Lane 1
                            lclk_map.dat[1][0] <= lclk_fifo.dout[3][3];    // G11
                            lclk_map.dat[1][1] <= lclk_fifo.dout[3][0];    // B11
                        end

                        'd9 : 
                        begin
                            // Lane 0
                            lclk_map.dat[0][0] <= lclk_fifo.dout[0][1];    // R12
                            lclk_map.dat[0][1] <= lclk_fifo.dout[0][2];    // G12

                            // Lane 1
                            lclk_map.dat[1][0] <= lclk_fifo.dout[1][1];    // R13
                            lclk_map.dat[1][1] <= lclk_fifo.dout[1][2];    // G13
                        end

                        'd10 : 
                        begin
                            // Lane 0
                            lclk_map.dat[0][0] <= lclk_fifo.dout[0][3];    // B12
                            lclk_map.dat[0][1] <= lclk_fifo.dout[2][1];    // R14

                            // Lane 1
                            lclk_map.dat[1][0] <= lclk_fifo.dout[1][3];    // B13
                            lclk_map.dat[1][1] <= lclk_fifo.dout[3][1];    // R15
                        end

                        'd11 : 
                        begin
                            // Lane 0
                            lclk_map.dat[0][0] <= lclk_fifo.dout[2][2];    // G14
                            lclk_map.dat[0][1] <= lclk_fifo.dout[2][3];    // B14

                            // Lane 1
                            lclk_map.dat[1][0] <= lclk_fifo.dout[3][2];    // G15
                            lclk_map.dat[1][1] <= lclk_fifo.dout[3][3];    // B15
                        end

                        default : 
                        begin
                            // Lane 0
                            lclk_map.dat[0][0] <= lclk_fifo.dout[0][0];    // R0
                            lclk_map.dat[0][1] <= lclk_fifo.dout[0][1];    // G0

                            // Lane 1
                            lclk_map.dat[1][0] <= lclk_fifo.dout[1][0];    // R1
                            lclk_map.dat[1][1] <= lclk_fifo.dout[1][1];    // G1
                        end
                    endcase
                end

                // 1 lane
                else if (lclk_ctl.lanes == 'd1)
                begin
                    // Inactive lanes
                    for (int i = 1; i < P_LANES; i++)
                    begin 
                        for (int j = 0; j < P_SPL; j++)
                            lclk_map.dat[i][j] <= 0;
                    end

                    case (lclk_map.dat_sel[$size(lclk_map.dat_sel)-1])
                        'd1 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[0][2];    // B0
                            lclk_map.dat[0][1] <= lclk_fifo.dout[1][0];    // R1
                        end

                        'd2 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[1][1];    // G1
                            lclk_map.dat[0][1] <= lclk_fifo.dout[1][2];    // B1
                        end

                        'd3 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[2][0];    // R2
                            lclk_map.dat[0][1] <= lclk_fifo.dout[2][1];    // G2
                        end

                        'd4 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[2][2];    // B2
                            lclk_map.dat[0][1] <= lclk_fifo.dout[3][0];    // R3
                        end

                        'd5 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[3][1];    // G3
                            lclk_map.dat[0][1] <= lclk_fifo.dout[3][2];    // B3
                        end

                        'd6 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[0][3];    // R4
                            lclk_map.dat[0][1] <= lclk_fifo.dout[0][0];    // G4
                        end

                        'd7 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[0][1];    // B4
                            lclk_map.dat[0][1] <= lclk_fifo.dout[1][3];    // R5
                        end

                        'd8 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[1][0];    // G5
                            lclk_map.dat[0][1] <= lclk_fifo.dout[1][1];    // B5
                        end

                        'd9 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[2][3];    // R6
                            lclk_map.dat[0][1] <= lclk_fifo.dout[2][0];    // G6
                        end

                        'd10 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[2][1];    // B6
                            lclk_map.dat[0][1] <= lclk_fifo.dout[3][3];    // R7
                        end

                        'd11 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[3][0];    // G7
                            lclk_map.dat[0][1] <= lclk_fifo.dout[3][1];    // B7
                        end

                        'd12 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[0][2];    // R8
                            lclk_map.dat[0][1] <= lclk_fifo.dout[0][3];    // G8
                        end

                        'd13 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[0][0];    // B8
                            lclk_map.dat[0][1] <= lclk_fifo.dout[1][2];    // R9
                        end

                        'd14 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[1][3];    // G9
                            lclk_map.dat[0][1] <= lclk_fifo.dout[1][0];    // B9
                        end

                        'd15 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[2][2];    // R10
                            lclk_map.dat[0][1] <= lclk_fifo.dout[2][3];    // G10
                        end

                        'd16 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[2][0];    // B10
                            lclk_map.dat[0][1] <= lclk_fifo.dout[3][2];    // R11
                        end

                        'd17 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[3][3];    // G11
                            lclk_map.dat[0][1] <= lclk_fifo.dout[3][0];    // B11
                        end

                        'd18 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[0][1];    // R12
                            lclk_map.dat[0][1] <= lclk_fifo.dout[0][2];    // G12
                        end

                        'd19 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[0][3];    // B12
                            lclk_map.dat[0][1] <= lclk_fifo.dout[1][1];    // R13
                        end

                        'd20 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[1][2];    // G13
                            lclk_map.dat[0][1] <= lclk_fifo.dout[1][3];    // B13
                        end

                        'd21 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[2][1];    // R14
                            lclk_map.dat[0][1] <= lclk_fifo.dout[2][2];    // G14
                        end

                        'd22 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[2][3];    // B14
                            lclk_map.dat[0][1] <= lclk_fifo.dout[3][1];    // R15
                        end

                        'd23 : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[3][2];    // G15
                            lclk_map.dat[0][1] <= lclk_fifo.dout[3][3];    // B15
                        end

                        default : 
                        begin
                            lclk_map.dat[0][0] <= lclk_fifo.dout[0][0];    // R0
                            lclk_map.dat[0][1] <= lclk_fifo.dout[0][1];    // G0
                        end
                    endcase
                end

                // 4 lanes
                else
                begin
                    if (lclk_map.dat_sel[$size(lclk_map.dat_sel)-1] == 'd1)
                    begin
                        for (int i = 0; i < P_LANES; i++)
                        begin 
                            for (int j = 0; j < 2; j++)
                                lclk_map.dat[i][j] <= lclk_fifo.dout[i][j+2];
                        end
                    end

                    else
                    begin
                        for (int i = 0; i < P_LANES; i++)
                        begin 
                            for (int j = 0; j < 2; j++)
                                lclk_map.dat[i][j] <= lclk_fifo.dout[i][j];
                        end
                    end

                end
            end
        end
    end

    // MST
    else
    begin
        for (i = 0; i < P_LANES; i++)
        begin 
            for (j = 0; j < P_SPL; j++)
                assign lclk_map.dat[i][j] = 0;
        end
    end
endgenerate

// Data enable
// This logic is only needed in SST
generate
    if (P_STREAM == 0)
    begin : gen_map_de
        always_ff @ (posedge LNK_CLK_IN)
        begin
            lclk_map.de <= {lclk_map.de[0+:$size(lclk_map.de)-1], lclk_map.rd};
        end
    end

    else
        assign lclk_map.de = 0;
endgenerate

// Blanking start
    always_ff @ (posedge LNK_CLK_IN)
    begin
        lclk_map.bs <= {lclk_map.bs[0], lclk_lnk.bs};
    end

// Data enable edge detector
generate
    if (P_STREAM == 0)
    begin : gen_map_de_edge
        prt_dp_lib_edge
        LNK_MAP_DE_EDGE_INST
        (
            .CLK_IN    (LNK_CLK_IN),        // Clock
            .CKE_IN    (1'b1),              // Clock enable
            .A_IN      (lclk_map.de[$size(lclk_map.de)-1]),    // Input
            .RE_OUT    (),                  // Rising edge
            .FE_OUT    (lclk_map.de_fe)     // Falling edge
        );
    end

    else
        assign lclk_map.de_fe = 0;
endgenerate

// Insert blanking end delay line
// The FIFO has a two clock cycle read latency
// This register delay compensates for the FIFO read latency
    always_ff @ (posedge LNK_CLK_IN)
    begin
        lclk_lnk.ins_be <= {lclk_lnk.ins_be[0+:$left(lclk_lnk.ins_be)], lclk_lnk.tu_run_re};
    end

// Link symbol output
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // MST
        if (lclk_ctl.mst)
        begin
            // Blanking end
            if (lclk_lnk.be)
            begin
                for (int i = 0; i < P_LANES; i++)
                begin
                    for (int j = 0; j < P_SPL-1; j++)
                        lclk_src.sym[i][j] <= TX_LNK_SYM_SF;

                    lclk_src.sym[i][P_SPL-1] <= TX_LNK_SYM_BE; // The BE appears in the last sublane
                end
            end

            // Blanking start
            else if (lclk_lnk.bs)
            begin
                for (int i = 0; i < P_LANES; i++)
                begin
                    lclk_src.sym[i][0] <= TX_LNK_SYM_BS;        // The BS appears in the first sublane

                    for (int j = 1; j < P_SPL; j++)
                        lclk_src.sym[i][j] <= TX_LNK_SYM_SF;
                end
            end

            // Data
            else
            begin
                for (int i = 0; i < P_LANES; i++)
                begin
                    for (int j = 0; j < P_SPL; j++)
                    begin
                        // Symbol fill 
                        if (lclk_fifo.de[i][j])
                            lclk_src.sym[i][j] <= TX_LNK_SYM_NOP;
                        else
                            lclk_src.sym[i][j] <= TX_LNK_SYM_SF;
                    end
                end
            end
        end
        
        // SST
        else
        begin        
            // Default
            for (int i = 0; i < P_LANES; i++)
            begin
                for (int j = 0; j < P_SPL; j++)
                    lclk_src.sym[i][j] <= TX_LNK_SYM_NOP;
            end

            // Blanking start
            if (lclk_map.bs[1])
            begin
                for (int i = 0; i < P_LANES; i++)
                    lclk_src.sym[i][0] <= TX_LNK_SYM_BS; // First Sublane 
            end

            // Blanking end
            else if (lclk_lnk.ins_be[$size(lclk_lnk.ins_be)-1] && lclk_vid.act_evt)
            begin
                for (int i = 0; i < P_LANES; i++)
                    lclk_src.sym[i][P_SPL-1] <= TX_LNK_SYM_BE;
            end

            // Single fill word
            else if ((lclk_lnk.tu_cnt == P_TU_FE) && lclk_map.de_fe && lclk_vid.act_evt)
            begin
                for (int i = 0; i < P_LANES; i++)
                begin
                    lclk_src.sym[i][0]        <= TX_LNK_SYM_FS; // First Sublane 
                    lclk_src.sym[i][P_SPL-1]  <= TX_LNK_SYM_FE; // Last Sublane 
                end
            end

            // Fill start
            else if (lclk_map.de_fe && lclk_vid.act_evt)
            begin
                for (int i = 0; i < P_LANES; i++)
                    lclk_src.sym[i][0] <= TX_LNK_SYM_FS;     // Sublane 0
            end

            // Fill end
            else if ((lclk_lnk.tu_cnt == P_TU_FE) && lclk_vid.act_evt)
            begin
                for (int i = 0; i < P_LANES; i++)
                    lclk_src.sym[i][P_SPL-1] <= TX_LNK_SYM_FE;     // Sublane 1
            end
        end
    end

// Link data output
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Run
        if (lclk_vid.run)
        begin
            // MST
            if (lclk_ctl.mst)
            begin           
                for (int i = 0; i < P_LANES; i++)
                begin
                    for (int j = 0; j < P_SPL; j++)
                    begin
                        // Video data
                        if (lclk_fifo.de[i][j] && !lclk_lnk.be && !lclk_lnk.bs)
                            lclk_src.dat[i][j] <= lclk_fifo.dout[i][j]; 
                        else
                            lclk_src.dat[i][j] <= 0; 
                    end
                end
            end
            
            // SST
            else
            begin
                // Video data
                begin
                    for (int i = 0; i < P_LANES; i++)
                    begin
                        for (int j = 0; j < P_SPL; j++)
                        begin
                            if (lclk_map.de[$size(lclk_map.de)-1] && lclk_vid.act_evt)
                                lclk_src.dat[i][j] <= lclk_map.dat[i][j]; 
                            else
                                lclk_src.dat[i][j] <= 0;
                        end 
                    end
                end
            end
        end

        // Idle
        else
        begin
            // Default
            for (int i = 0; i < P_LANES; i++)
            begin
                for (int j = 0; j < P_SPL; j++)
                    lclk_src.dat[i][j] <= 0;
            end
        end
    end

// Link valid output
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Run
        if (lclk_vid.run)
        begin
            // MST
            if (lclk_ctl.mst)
                lclk_src.vld <= {lclk_src.vld[$high(lclk_src.vld)-1:0], lclk_src.rd};

            // SST
            else
                lclk_src.vld <= '1;
        end

        // Idle
        else
            lclk_src.vld <= 0;
    end

// Outputs
generate
    for (i = 0; i < P_LANES; i++)
    begin
        for (j = 0; j < P_SPL; j++)
        begin
            assign LNK_SRC_IF.sym[i][j] = lclk_src.sym[i][j];   // Symbol
            assign LNK_SRC_IF.dat[i][j] = lclk_src.dat[i][j];   // Data
        end
    end
endgenerate
    assign LNK_SRC_IF.vld = lclk_src.vld[$high(lclk_src.vld)];

    assign LNK_VS_OUT  = (lclk_ctl.en) ? lclk_vid.vs : 0;   // Vsync
    assign LNK_VBF_OUT = (lclk_ctl.en) ? lclk_vid.vbf : 0;  // Video blanking flag
    
endmodule

`default_nettype wire
