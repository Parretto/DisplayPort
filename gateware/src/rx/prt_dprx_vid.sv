/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP RX Video
    (c) 2021 - 2026 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Added support for 1 and 2 lanes.
    v1.2 - Added 10-bits video support
    v1.3 - Added VB-ID register output
    v1.4 - Added support for YCrCb colorspace 
    v1.5 - Added video interrupt
    v1.6 - Removed interlane dependency
    v1.7 - Updated end-of-line generation


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
module prt_dprx_vid
#(
    // System
    parameter               P_VENDOR = "none",  // Vendor - "AMD", "ALTERA" or "LSC"
    parameter               P_FAMILY = "none",  // Family (Only used for Lattice)
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
    output wire             LNK_IRQ_OUT,        // Interrupt. This signal toggles at every end of the vertical blanking period (VerticalBlanking_Flag). It is used by the policy maker to detect a stable video stream.

    // Video 
    input wire              VID_RST_IN,         // Reset
    input wire              VID_CLK_IN,         // Clock
    output wire             VID_EN_OUT,         // Enable
    prt_dp_axis_if.src      VID_SRC_IF          // Source
);


//-----
// Package
//-----
import prt_dp_pkg::*;


//-----
// Parameters
//-----
localparam P_FIFO_WRDS = 64;
localparam P_FIFO_ADR = $clog2(P_FIFO_WRDS);
localparam P_FIFO_DAT = 9;
localparam P_FIFO_SEGMENTS = 4;
localparam P_FIFO_STRIPES = 4;
localparam P_MAP_CH = (P_PPC == 4) ? 4 : 8; // Mapper input channels


//-----
// Function
//-----
// This function calculates the head counter in four symbols
function logic [15:0] calc_head_4spl (logic [15:0] head_in, logic [P_SPL-1:0] wr_in);
    logic [15:0] head_out;
        case (wr_in)
            'b0001 : head_out = head_in + 'd1;
            'b0010 : head_out = head_in + 'd1;
            'b0100 : head_out = head_in + 'd1;
            'b1000 : head_out = head_in + 'd1;
            'b0011 : head_out = head_in + 'd2;
            'b0110 : head_out = head_in + 'd2;
            'b1100 : head_out = head_in + 'd2;
            'b0111 : head_out = head_in + 'd3;
            'b1110 : head_out = head_in + 'd3;
            'b1111 : head_out = head_in + 'd4;
            default : head_out = head_in;
        endcase
    return head_out;
endfunction

// This function calculates the head counter in two symbols
function logic [15:0] calc_head_2spl (logic [15:0] head_in, logic [P_SPL-1:0] wr_in);
    logic [15:0] head_out;
        case (wr_in)
            'b01 : head_out = head_in + 'd1;
            'b10 : head_out = head_in + 'd1;
            'b11 : head_out = head_in + 'd2;
            default : head_out = head_in;
        endcase
    return head_out;
endfunction


//-----
// Structures
//-----
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
    logic [P_SPL-1:0]               sol;
    logic [P_SPL-1:0]               eol;
    logic [P_SPL-1:0]               vid;
    logic [P_SPL-1:0]               vid_reg;
    logic [P_SPL-1:0]               vid_reg_del;
    logic                           str;                    // Start
    logic                           str_toggle;
    logic                           stp;                    // Stop
    logic                           stp_toggle;
    logic [P_SPL-1:0]               vbid;
    logic [P_SPL-1:0]               vbid_reg;
    logic [7:0]                     vbid_val;               // VB-ID value
    logic                           nvs;                    // No video stream flag
    logic                           vbf;                    // Vertical blanking flag 
    logic                           vbf_fe;                 // Vertical blanking flag falling edge 
    logic [P_SPL-1:0]               k[P_LANES];
    logic [7:0]                     dat[P_LANES][P_SPL];
    logic [7:0]                     dat_reg[P_LANES][P_SPL];
    logic [7:0]                     dat_reg_del[P_LANES][P_SPL];
    logic                           irq;
    logic [15:0]                    head_lane;
    logic [15:0]                    head;
} lnk_struct;

typedef struct {
    logic [1:0]                     lph;
    logic [1:0]                     fph;
    logic [1:0]                     sel;
    logic                           str;
    logic [P_SPL-1:0]               wr[P_LANES];
    logic [7:0]                     dat[P_LANES][P_SPL];
} aln_struct;

typedef struct {
    logic [P_FIFO_STRIPES-1:0]      wr[P_LANES];
    logic [7:0]                     dat[P_LANES][P_FIFO_STRIPES];
} lnk_map_struct;

typedef struct {
    logic                           clr;
} lnk_fifo_struct;

typedef struct {
    logic                           bpc;        // Active bits-per-component (0 - 8bits / 1 - 10 bits)
} vid_ctl_struct;

typedef struct {
    logic                           clr;
    logic [1:0]                     dout[P_LANES][P_FIFO_SEGMENTS][P_FIFO_STRIPES];
    logic [P_FIFO_STRIPES-1:0]	    de[P_LANES][P_FIFO_SEGMENTS];
} vid_fifo_struct;

typedef struct {
    logic [15:0]                    head;
    logic [P_FIFO_STRIPES-1:0]      rd[P_LANES][P_FIFO_SEGMENTS];
    logic  [P_VID_DAT-1:0]          dat;
    logic                           eol;
    logic                           vld;
} vid_map_struct;

typedef struct {
    logic                           run;
    logic                           str_toggle;
    logic                           str_re;
    logic                           str_fe;
    logic                           str;        // Start
    logic                           stp_toggle;
    logic                           stp_re;
    logic                           stp_fe;
    logic                           stp;        // Stop
    logic                           nvs;        // No video stream flag
    logic                           vbf;        // Vertical blanking flag 
    logic                           vbf_re;     // Vertical blanking flag rising edge
    logic                           vbf_sticky;
    logic [15:0]                    hwidth;     // Horizontal width
    logic [15:0]                    hcnt;       // Horizontal counter
    logic                           sof;        // Start of frame
    logic                           eol;        // End of line
    logic [P_VID_DAT-1:0] 			dat;        // Data
    logic                           vld;        // Valid
} vid_struct;


//-----
// Signals
//-----
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
        // All the lanes are aligned, so only the first lane is used. 
        lclk_lnk.vbid = LNK_SNK_IF.vbid[0];
        lclk_lnk.sol  = LNK_SNK_IF.sol[0];
        lclk_lnk.eol  = LNK_SNK_IF.eol[0];
        lclk_lnk.vid  = LNK_SNK_IF.vid[0];

        // Data
        for (int i = 0; i < P_LANES; i++)
        begin
            lclk_lnk.k[i]    = LNK_SNK_IF.k[i];
            lclk_lnk.dat[i]  = LNK_SNK_IF.dat[i];
        end
    end

// Registered data
// This is needed for the alignment latency 
    always_ff @ (posedge LNK_CLK_IN)
    begin
        lclk_lnk.vbid_reg    <= lclk_lnk.vbid;
        lclk_lnk.vid_reg     <= lclk_lnk.vid;

        for (int i = 0; i < P_LANES; i++)
        begin
            lclk_lnk.dat_reg[i] <= lclk_lnk.dat[i];
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
        end

        lclk_lnk.vid_reg_del <= lclk_lnk.vid_reg;
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

            // Set
            // The lanes are aligned, so only the first lane is used.
            if (|lclk_lnk.sol)
                lclk_lnk.str <= 1;
        end

        // Idle
        else
            lclk_lnk.str <= 0;
    end

// Link stop
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Lock
        if (lclk_lnk.lock)
        begin
            // Default
            lclk_lnk.stp <= 0;

            // Set
            // The lanes are aligned, so only the first lane is used.
            if (|lclk_lnk.eol)
                lclk_lnk.stp <= 1;
        end

        // Idle
        else
            lclk_lnk.stp <= 0;
    end

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

// Stop toggle
// The stop of line is used to flush the video mapper
// In the link clock domain this signal is only one clock.
// To detect this in the video clock domain this toggle signal is inverted every time an eol is detected.
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Lock
        if (lclk_lnk.lock)
        begin
            // Only first lane is used
            if (lclk_lnk.stp)
                lclk_lnk.stp_toggle <= ~lclk_lnk.stp_toggle;
        end

        else
            lclk_lnk.stp_toggle <= 0;
    end

// VB-ID value
// This will capture the VB-ID 
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Lock
        if (lclk_lnk.lock)
        begin
            // The VB-ID byte can appear on any sublane
            for (int i = 0; i < P_SPL; i++)
            begin
                if (lclk_lnk.vbid_reg[i])
                    lclk_lnk.vbid_val <= lclk_lnk.dat_reg[0][i];
            end
        end

        // No lock
        else
            lclk_lnk.vbid_val <= 0;
    end

    assign lclk_lnk.vbf = lclk_lnk.vbid_val[0];
    assign lclk_lnk.nvs = lclk_lnk.vbid_val[3];

// Vertical Blanking Flag egde detector
// This is used for the interrupt 
    prt_lib_edge
    LNK_VBF_EDGE_INST
    (
        .CLK_IN    (LNK_CLK_IN),        // Clock
        .CKE_IN    (1'b1),              // Clock enable
        .A_IN      (lclk_lnk.vbf),      // Input
        .RE_OUT    (),                  // Rising edge
        .FE_OUT    (lclk_lnk.vbf_fe)    // Falling edge
    );

// Interrupt
// This signal toggles at every end of the vertical blanking period (VerticalBlanking_Flag). 
// The toggling makes it safe to cross to the system clock domain. 
// It is used by the policy maker to detect a stable video stream.
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Lock
        if (lclk_lnk.lock)
        begin
            // Toggle
            if (lclk_lnk.vbf_fe)
                lclk_lnk.irq <= ~lclk_lnk.irq;
        end

        // Idle
        else
            lclk_lnk.irq <= 0;
    end


/*
    Alignment
    The alignment will steer the data input, 
    so that even data will be written into the first and third FIFO stripe
    and the odd data goes into the second and fourth FIFO stripe. 
*/

// Start of data packet
// This signal is asserted at the start of a new data packet
    prt_lib_edge
    LNK_ALN_STR_EDGE_INST
    (
        .CLK_IN    (LNK_CLK_IN),            // Clock
        .CKE_IN    (1'b1),                  // Clock enable
        .A_IN      (|lclk_lnk.vid),        // Input
        .RE_OUT    (lclk_aln.str),          // Rising edge
        .FE_OUT    ()                       // Falling edge
    );

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
            // Phase 0
            // Highest priority 
            if (lclk_lnk.vid[0])
                lclk_aln.fph = 'd0;

            // Phase 1
            else if (lclk_lnk.vid[1])
                lclk_aln.fph = 'd1;

            // Phase 2
            else if (lclk_lnk.vid[2])
                lclk_aln.fph = 'd2;

            // Phase 3
            // Lowest priority
            else
                lclk_aln.fph = 'd3;
        end        
    end

    // Two symbols per lane
    else
    begin : gen_fph_2spl
        always_comb
        begin
            // Phase 0
            // Highest priority
            if (lclk_lnk.vid[0])
                lclk_aln.fph = 'd0;

            // Phase 1
            else
                lclk_aln.fph = 'd1;
        end        
    end
endgenerate

// Last phase
// This register captures the phase of the last data
// The easiest way is to look at the last alignment write.
// However using this approach when idle time between the video packets is small, 
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
            // Clear at start of line
            if (|lclk_lnk.sol)
                lclk_aln.lph <= 0;

            else 
            begin
                // Phase 0 - Video ends in sublane 3
                if (lclk_lnk.vid[3])
                    lclk_aln.lph <= 'd0;

                // Phase 3 - Video ends in sublane 2
                else if (lclk_lnk.vid[2])
                    lclk_aln.lph <= 'd3;

                // Phase 2 - Video ends in sublane 1
                else if (lclk_lnk.vid[1])
                    lclk_aln.lph <= 'd2;
                
                // Phase 1 - Video ends in sublane 0
                else if (lclk_lnk.vid[0])
                    lclk_aln.lph <= 'd1;
            end
        end
    end

    // Two symbols per lane
    else
    begin : gen_lph_2spl
        always_ff @ (posedge LNK_CLK_IN)
        begin
            // Clear at start of line
            if (|lclk_lnk.sol)
                lclk_aln.lph <= 0;

            else
            begin
                // Phase 0 - Video ends in sublane 1
                if (lclk_lnk.vid[1])
                    lclk_aln.lph <= 'd0;
            
                // Phase 1 - Video ends in sublane 0
                else if (lclk_lnk.vid[0])
                    lclk_aln.lph <= 'd1;
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
            // Clear at start of line
            if (|lclk_lnk.sol)
                lclk_aln.sel <= 0;

            else
            begin
                // Set at start of video data
                if (lclk_aln.str)    
                begin
                    case ({lclk_aln.sel, lclk_aln.lph, lclk_aln.fph})
                        {2'd0, 2'd0, 2'd1} : lclk_aln.sel <= 2'd1;
                        {2'd0, 2'd0, 2'd2} : lclk_aln.sel <= 2'd2;
                        {2'd0, 2'd0, 2'd3} : lclk_aln.sel <= 2'd3;
                        {2'd0, 2'd1, 2'd0} : lclk_aln.sel <= 2'd3;
                        {2'd0, 2'd1, 2'd2} : lclk_aln.sel <= 2'd1;
                        {2'd0, 2'd1, 2'd3} : lclk_aln.sel <= 2'd2;
                        {2'd0, 2'd2, 2'd0} : lclk_aln.sel <= 2'd2;
                        {2'd0, 2'd2, 2'd1} : lclk_aln.sel <= 2'd3;
                        {2'd0, 2'd2, 2'd3} : lclk_aln.sel <= 2'd1;
                        {2'd0, 2'd3, 2'd0} : lclk_aln.sel <= 2'd1;
                        {2'd0, 2'd3, 2'd1} : lclk_aln.sel <= 2'd2;
                        {2'd0, 2'd3, 2'd2} : lclk_aln.sel <= 2'd3;

                        {2'd1, 2'd0, 2'd1} : lclk_aln.sel <= 2'd2;
                        {2'd1, 2'd0, 2'd2} : lclk_aln.sel <= 2'd3;
                        {2'd1, 2'd0, 2'd3} : lclk_aln.sel <= 2'd0;
                        {2'd1, 2'd1, 2'd0} : lclk_aln.sel <= 2'd0;
                        {2'd1, 2'd1, 2'd2} : lclk_aln.sel <= 2'd2;
                        {2'd1, 2'd1, 2'd3} : lclk_aln.sel <= 2'd3;
                        {2'd1, 2'd2, 2'd0} : lclk_aln.sel <= 2'd3;
                        {2'd1, 2'd2, 2'd1} : lclk_aln.sel <= 2'd0;
                        {2'd1, 2'd2, 2'd3} : lclk_aln.sel <= 2'd2;
                        {2'd1, 2'd3, 2'd0} : lclk_aln.sel <= 2'd2;
                        {2'd1, 2'd3, 2'd1} : lclk_aln.sel <= 2'd3;
                        {2'd1, 2'd3, 2'd2} : lclk_aln.sel <= 2'd0;

                        {2'd2, 2'd0, 2'd1} : lclk_aln.sel <= 2'd3;
                        {2'd2, 2'd0, 2'd2} : lclk_aln.sel <= 2'd0;
                        {2'd2, 2'd0, 2'd3} : lclk_aln.sel <= 2'd1;
                        {2'd2, 2'd1, 2'd0} : lclk_aln.sel <= 2'd1;
                        {2'd2, 2'd1, 2'd2} : lclk_aln.sel <= 2'd3;
                        {2'd2, 2'd1, 2'd3} : lclk_aln.sel <= 2'd0;
                        {2'd2, 2'd2, 2'd0} : lclk_aln.sel <= 2'd0;
                        {2'd2, 2'd2, 2'd1} : lclk_aln.sel <= 2'd1;
                        {2'd2, 2'd2, 2'd3} : lclk_aln.sel <= 2'd3;
                        {2'd2, 2'd3, 2'd0} : lclk_aln.sel <= 2'd3;
                        {2'd2, 2'd3, 2'd1} : lclk_aln.sel <= 2'd0;
                        {2'd2, 2'd3, 2'd2} : lclk_aln.sel <= 2'd1;

                        {2'd3, 2'd0, 2'd1} : lclk_aln.sel <= 2'd0;
                        {2'd3, 2'd0, 2'd2} : lclk_aln.sel <= 2'd1;
                        {2'd3, 2'd0, 2'd3} : lclk_aln.sel <= 2'd2;
                        {2'd3, 2'd1, 2'd0} : lclk_aln.sel <= 2'd2;
                        {2'd3, 2'd1, 2'd2} : lclk_aln.sel <= 2'd0;
                        {2'd3, 2'd1, 2'd3} : lclk_aln.sel <= 2'd1;
                        {2'd3, 2'd2, 2'd0} : lclk_aln.sel <= 2'd1;
                        {2'd3, 2'd2, 2'd1} : lclk_aln.sel <= 2'd2;
                        {2'd3, 2'd2, 2'd3} : lclk_aln.sel <= 2'd0;
                        {2'd3, 2'd3, 2'd0} : lclk_aln.sel <= 2'd0;
                        {2'd3, 2'd3, 2'd1} : lclk_aln.sel <= 2'd1;
                        {2'd3, 2'd3, 2'd2} : lclk_aln.sel <= 2'd2;
                        default            : ;
                    endcase
                end
            end
        end
    end

    // Two symbols per lane
    else
    begin : gen_aln_sel_2spl
        always_ff @ (posedge LNK_CLK_IN)
        begin
            // Clear at start of line
            if (|lclk_lnk.sol)
                lclk_aln.sel <= 0;

            else
            begin
                // Set at start of video data
                if (lclk_aln.str)    
                begin
                    case ({lclk_aln.sel, lclk_aln.lph, lclk_aln.fph})
                        {2'd0, 2'd0, 2'd1} : lclk_aln.sel <= 'd1;                   
                        {2'd0, 2'd1, 2'd0} : lclk_aln.sel <= 'd1;
                        {2'd1, 2'd0, 2'd1} : lclk_aln.sel <= 'd0;                   
                        {2'd1, 2'd1, 2'd0} : lclk_aln.sel <= 'd0;                
                        default      : ; // keep current alignment
                    endcase
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
                if (lclk_aln.sel == 'd1)
                begin
                    lclk_aln.dat[i][0] <= lclk_lnk.dat_reg_del[i][1];
                    lclk_aln.dat[i][1] <= lclk_lnk.dat_reg_del[i][2];
                    lclk_aln.dat[i][2] <= lclk_lnk.dat_reg_del[i][3];
                    lclk_aln.dat[i][3] <= lclk_lnk.dat_reg[i][0];

                    lclk_aln.wr[i][0] <= lclk_lnk.vid_reg_del[1];
                    lclk_aln.wr[i][1] <= lclk_lnk.vid_reg_del[2];
                    lclk_aln.wr[i][2] <= lclk_lnk.vid_reg_del[3];
                    lclk_aln.wr[i][3] <= lclk_lnk.vid_reg[0];
                end

                // Phase 2
                else if (lclk_aln.sel == 'd2)
                begin
                    lclk_aln.dat[i][0] <= lclk_lnk.dat_reg_del[i][2];
                    lclk_aln.dat[i][1] <= lclk_lnk.dat_reg_del[i][3];
                    lclk_aln.dat[i][2] <= lclk_lnk.dat_reg[i][0];
                    lclk_aln.dat[i][3] <= lclk_lnk.dat_reg[i][1];

                    lclk_aln.wr[i][0] <= lclk_lnk.vid_reg_del[2];
                    lclk_aln.wr[i][1] <= lclk_lnk.vid_reg_del[3];
                    lclk_aln.wr[i][2] <= lclk_lnk.vid_reg[0];
                    lclk_aln.wr[i][3] <= lclk_lnk.vid_reg[1];
                end

                // Phase 3
                else if (lclk_aln.sel == 'd3)
                begin
                    lclk_aln.dat[i][0] <= lclk_lnk.dat_reg_del[i][3];
                    lclk_aln.dat[i][1] <= lclk_lnk.dat_reg[i][0];
                    lclk_aln.dat[i][2] <= lclk_lnk.dat_reg[i][1];
                    lclk_aln.dat[i][3] <= lclk_lnk.dat_reg[i][2];

                    lclk_aln.wr[i][0] <= lclk_lnk.vid_reg_del[3];
                    lclk_aln.wr[i][1] <= lclk_lnk.vid_reg[0];
                    lclk_aln.wr[i][2] <= lclk_lnk.vid_reg[1];
                    lclk_aln.wr[i][3] <= lclk_lnk.vid_reg[2];
                end

                // Normal
                else
                begin
                    lclk_aln.dat[i][0] <= lclk_lnk.dat_reg[i][0];
                    lclk_aln.dat[i][1] <= lclk_lnk.dat_reg[i][1];
                    lclk_aln.dat[i][2] <= lclk_lnk.dat_reg[i][2];
                    lclk_aln.dat[i][3] <= lclk_lnk.dat_reg[i][3];
                    
                    lclk_aln.wr[i][0] <= lclk_lnk.vid_reg[0];
                    lclk_aln.wr[i][1] <= lclk_lnk.vid_reg[1];
                    lclk_aln.wr[i][2] <= lclk_lnk.vid_reg[2];
                    lclk_aln.wr[i][3] <= lclk_lnk.vid_reg[3];
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
                if (lclk_aln.sel == 'd1)
                begin
                    lclk_aln.dat[i][0] <= lclk_lnk.dat_reg_del[i][1];
                    lclk_aln.dat[i][1] <= lclk_lnk.dat_reg[i][0];
                    lclk_aln.wr[i][0]  <= lclk_lnk.vid_reg_del[1];
                    lclk_aln.wr[i][1]  <= lclk_lnk.vid_reg[0];
                end

                // Normal
                else
                begin
                    lclk_aln.dat[i][0] <= lclk_lnk.dat_reg[i][0];
                    lclk_aln.dat[i][1] <= lclk_lnk.dat_reg[i][1];
                    lclk_aln.wr[i][0]  <= lclk_lnk.vid_reg[0];
                    lclk_aln.wr[i][1]  <= lclk_lnk.vid_reg[1];
                end
            end
        end
    end
endgenerate

/*
    Link Mapper

    The FIFO's are arranged for 4 lanes.
    In case of 1 or 2 active lanes, the mapper will re-map the incoming data as it is a 4 lanes link.
*/

    prt_dprx_vid_lmap
    #(
        // Video
        .P_LANES        (P_LANES),          // Lanes
        .P_SPL          (P_SPL),            // Symbols per lane
        .P_STRIPES      (P_FIFO_STRIPES)    // Stripes
    )
    LMAP_INST
    (
        .RST_IN         (LNK_RST_IN),       // Reset
        .CLK_IN         (LNK_CLK_IN),       // Clock

        // Input
        .LANES_IN       (lclk_ctl.lanes),   // Active lanes
        .STR_IN         (lclk_lnk.str),     // Start
        .DAT_IN         (lclk_aln.dat),     // Data in
        .VLD_IN         (lclk_aln.wr),      // Valid in

        // Output
        .DAT_OUT        (lclk_map.dat),     // Data out
        .VLD_OUT        (lclk_map.wr)       // Valid out
    );


//-----
// FIFO
//-----
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
        .LNK_RST_IN         (LNK_RST_IN),           // Reset
        .LNK_CLK_IN         (LNK_CLK_IN),           // Clock
        .LNK_CLR_IN         (lclk_fifo.clr),        // Clear
        .LNK_DAT_IN         (lclk_map.dat),         // Data
        .LNK_WR_IN          (lclk_map.wr),          // Write

        // Video port
        .VID_RST_IN         (VID_RST_IN),           // Reset
        .VID_CLK_IN         (VID_CLK_IN),           // Clock
        .VID_CLR_IN         (vclk_fifo.clr),        // Clear
        .VID_RD_IN          (vclk_map.rd),          // Read
        .VID_DAT_OUT        (vclk_fifo.dout),       // Data
        .VID_DE_OUT         (vclk_fifo.de)          // Data enable
    );

    assign lclk_fifo.clr = lclk_lnk.str;
    assign vclk_fifo.clr = vclk_vid.str;


// Head lanes
// This process counts the received bytes for lane 0. 
// The head counter is used to determine the unread bytes (level) in the FIFO. 
// The valid data packets on all lanes have the same size. 
// In case a video line is not an integer number of bytes, the last packet will be zero-padded. 
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Lock
        if (lclk_lnk.lock)
        begin
            // Clear
            if (lclk_lnk.str)
                lclk_lnk.head_lane <= 0;

            // Increment
            else
            begin
                // Four symbols
                if (P_SPL == 4)
                    lclk_lnk.head_lane <= calc_head_4spl (lclk_lnk.head_lane, lclk_aln.wr[0]);

                // Two symbols
                else
                    lclk_lnk.head_lane <= calc_head_2spl (lclk_lnk.head_lane, lclk_aln.wr[0]);
            end
        end

        // Idle
        else
            lclk_lnk.head_lane <= 0;
    end

// Head
// This process counts the total received bytes. 
// All the lanes are aligned, so the received byte for lane 0 can be multiplied by the number of active lanes. 
    always_comb
    begin
        // Single lane
        if (lclk_ctl.lanes == 'd1)
            lclk_lnk.head = lclk_lnk.head_lane;

        // Two lanes
        else if (lclk_ctl.lanes == 'd2)
            lclk_lnk.head = {lclk_lnk.head_lane[0+:$size(lclk_lnk.head)-1], 1'b0};      // Multiply by two

        // Four lanes
        else 
            lclk_lnk.head = {lclk_lnk.head_lane[0+:$size(lclk_lnk.head)-2], 2'b00};     // Multiply by four
    end


/*
    Video domain
*/

//-----
// BPC clock domain crossing
//-----
    prt_lib_cdc_bit
    #(
        .P_VENDOR       (P_VENDOR)
    )
    VCLK_BPC_CDC_INST
    (
        .SRC_CLK_IN     (LNK_CLK_IN),       // Clock
        .SRC_DAT_IN     (lclk_ctl.bpc),    // Data
        .DST_CLK_IN     (VID_CLK_IN),       // Clock
        .DST_DAT_OUT    (vclk_ctl.bpc)     // Data
    );


//-----
// Start of  line clock domain crossing
//-----
    prt_lib_cdc_bit
    #(
        .P_VENDOR       (P_VENDOR)
    )
    VCLK_STR_CDC_INST
    (
        .SRC_CLK_IN     (LNK_CLK_IN),           // Clock
        .SRC_DAT_IN     (lclk_lnk.str_toggle),  // Data
        .DST_CLK_IN     (VID_CLK_IN),           // Clock
        .DST_DAT_OUT    (vclk_vid.str_toggle)   // Data
    );


//-----
// Start of line edge detector
//-----
    prt_lib_edge
    VCLK_STR_EDGE_INST
    (
        .CLK_IN    (VID_CLK_IN),            // Clock
        .CKE_IN    (1'b1),                  // Clock enable
        .A_IN      (vclk_vid.str_toggle),   // Input
        .RE_OUT    (vclk_vid.str_re),       // Rising edge
        .FE_OUT    (vclk_vid.str_fe)        // Falling edge
    );


//-----
// Stop of line clock domain crossing
//-----
    prt_lib_cdc_bit
    #(
        .P_VENDOR       (P_VENDOR)
    )
    VCLK_STP_CDC_INST
    (
        .SRC_CLK_IN     (LNK_CLK_IN),           // Clock
        .SRC_DAT_IN     (lclk_lnk.stp_toggle),  // Data
        .DST_CLK_IN     (VID_CLK_IN),           // Clock
        .DST_DAT_OUT    (vclk_vid.stp_toggle)   // Data
    );

//-----
// Stop of line edge detector
//-----
    prt_lib_edge
    VCLK_STP_EDGE_INST
    (
        .CLK_IN    (VID_CLK_IN),            // Clock
        .CKE_IN    (1'b1),                  // Clock enable
        .A_IN      (vclk_vid.stp_toggle),   // Input
        .RE_OUT    (vclk_vid.stp_re),       // Rising edge
        .FE_OUT    (vclk_vid.stp_fe)        // Falling edge
    );


//-----
// NVS clock domain crossing
//-----
    prt_lib_cdc_bit
    #(
        .P_VENDOR       (P_VENDOR)
    )
    VCLK_NVS_CDC_INST
    (
        .SRC_CLK_IN     (LNK_CLK_IN),      // Clock
        .SRC_DAT_IN     (lclk_lnk.nvs),    // Data
        .DST_CLK_IN     (VID_CLK_IN),      // Clock
        .DST_DAT_OUT    (vclk_vid.nvs)     // Data
    );


//-----
// VBF clock domain crossing
//-----
    prt_lib_cdc_bit
    #(
        .P_VENDOR       (P_VENDOR)
    )
    VCLK_VBF_CDC_INST
    (
        .SRC_CLK_IN     (LNK_CLK_IN),      // Clock
        .SRC_DAT_IN     (lclk_lnk.vbf),    // Data
        .DST_CLK_IN     (VID_CLK_IN),      // Clock
        .DST_DAT_OUT    (vclk_vid.vbf)     // Data
    );


//-----
// Head clock domain crossing
//-----
    prt_lib_cdc_vec
    #(
        .P_VENDOR       (P_VENDOR),
        .P_WIDTH        ($size(lclk_lnk.head))
    )
    HEAD_CDC_INST
    (
        .SRC_RST_IN     (LNK_RST_IN),        // Reset
        .SRC_CLK_IN     (LNK_CLK_IN),        // Clock
        .SRC_DAT_IN     (lclk_lnk.head),     // Data
        .DST_RST_IN     (VID_RST_IN),        // Reset
        .DST_CLK_IN     (VID_CLK_IN),        // Clock
        .DST_DAT_OUT    (vclk_map.head)      // Data
    );


//-----
// Message Slave
//-----
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

// Horizontal width
    always_ff @ (posedge VID_CLK_IN)
    begin
        if (vclk_msg.first && vclk_msg.vld)
            vclk_vid.hwidth <= vclk_msg.dat >> (P_PPC/2);   // Adjust to pixels-per-clock
    end

// Run flag
// This synchronizes to start the reading of the video line at the start of a frame.
    always_ff @ (posedge VID_RST_IN, posedge VID_CLK_IN)
    begin
        // Reset
        if (VID_RST_IN)
            vclk_vid.run <= 0;

        else
        begin
            // Set during blanking
            if (vclk_vid.vbf_re)
                vclk_vid.run <= 1;
        end
    end

// Start of line 
// This signal is captured from the link domain
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Run
        if (vclk_vid.run)
            vclk_vid.str <= vclk_vid.str_re || vclk_vid.str_fe;

        else
            vclk_vid.str <= 0;
    end

// Stop of line 
// This signal is captured from the link domain
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Run
        if (vclk_vid.run)
        begin            
            // Clear
            if (vclk_vid.str)
                vclk_vid.stp <= 0;

            // Set
            else if (vclk_vid.stp_re || vclk_vid.stp_fe)
                vclk_vid.stp <= 1;
        end

        // Idle
        else
            vclk_vid.stp <= 0;
    end


//-----
// Video Mapper
//-----
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
        .MAP_STR_IN     (vclk_vid.str),         // Start
        .MAP_STP_IN     (vclk_vid.stp),         // Stop
        .MAP_HEAD_IN    (vclk_map.head),        // Head
        .MAP_RD_OUT     (vclk_map.rd),          // Read
        .MAP_DAT_IN     (vclk_fifo.dout),       // Data

        // Video
        .VID_DAT_OUT    (vclk_map.dat),         // Data
        .VID_EOL_OUT    (vclk_map.eol),         // End-of-line
        .VID_VLD_OUT    (vclk_map.vld)          // Valid
    );


/*
    Video
*/

//-----
// Vertical blanking flag detector
//-----
    prt_lib_edge
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
    always_ff @ (posedge VID_RST_IN, posedge VID_CLK_IN)
    begin
        // Reset
        if (VID_RST_IN)
            vclk_vid.vbf_sticky <= 0;

        else
        begin
            // Clear
            if (vclk_vid.sof)
                vclk_vid.vbf_sticky <= 0;

            // Set 
            else if (vclk_vid.vbf_re)
                vclk_vid.vbf_sticky <= 1;
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
        if (vclk_vid.hcnt < vclk_vid.hwidth)
            vclk_vid.vld <= vclk_map.vld;
        else
            vclk_vid.vld <= 0;
    end

// Start of frame
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Run
        if (vclk_vid.run)
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

        // Idle
        else
            vclk_vid.sof <= 0;
    end

// Horizontal counter
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Run
        if (vclk_vid.run)
        begin
            // Clear at start
            if (vclk_vid.str)
                vclk_vid.hcnt <= 0;

            // Increment
            else if (vclk_map.vld)
                vclk_vid.hcnt <= vclk_vid.hcnt + 'd1;
        end

        // Idle
        else
            vclk_vid.hcnt <= 0;
    end

// End of line
    always_ff @ (posedge VID_CLK_IN)
    begin
        if (vclk_vid.hcnt == (vclk_vid.hwidth - 'd1))
            vclk_vid.eol <= 1;
        else
            vclk_vid.eol <= 0;
    end


//-----
// Outputs
//-----
    // Link
    assign LNK_VBID_OUT     = lclk_lnk.vbid_val;   // VB-ID
    assign LNK_IRQ_OUT      = lclk_lnk.irq;        // Interrupt

    // Video source
    assign VID_EN_OUT       = ~vclk_vid.nvs;       // Enable
    assign VID_SRC_IF.sof   = vclk_vid.sof;        // Start of frame
    assign VID_SRC_IF.eol   = vclk_vid.eol;        // End of line
    assign VID_SRC_IF.dat   = vclk_vid.dat;        // Data
    assign VID_SRC_IF.vld   = vclk_vid.vld;        // Valid

endmodule

`default_nettype wire
