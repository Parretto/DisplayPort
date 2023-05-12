/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP RX Video
    (c) 2021, 2022 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Added support for 1 and 2 lanes.


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

module prt_dprx_vid
#(
    // System
    parameter               P_VENDOR = "none",  // Vendor "xilinx" or "lattice"

    // Link
    parameter               P_LANES = 4,    	// Lanes
    parameter               P_SPL = 2,      	// Symbols per lane

    // Video
    parameter               P_PPC = 2,      	// Pixels per clock
    parameter               P_BPC = 8,      	// Bits per component
    parameter 				P_VID_DAT = 48		// AXIS data width
)
(
    // Control
    input wire [1:0]        CTL_LANES_IN,       // Active lanes (1 - 1 lane / 2 - 2 lanes / 3 - 4 lanes)

    // Link
    input wire              LNK_RST_IN,         // Reset
    input wire              LNK_CLK_IN,         // Clock 
    prt_dp_rx_lnk_if.snk    LNK_SNK_IF,         // Sink

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
localparam P_FIFO_STRIPES = 4;
localparam P_MAP_CH = (P_PPC == 4) ? 4 : 8; // Mapper input channels

// Structures
typedef struct {
    logic                           lock;                   // Lock
    logic [1:0]                     lanes;                  // Active lanes
    logic [P_SPL-1:0]               sol[0:P_LANES-1];
    logic [P_SPL-1:0]               eol[0:P_LANES-1];
    logic [P_SPL-1:0]               eol_reg[0:P_LANES-1];
    logic [P_SPL-1:0]               eol_reg_del[0:P_LANES-1];
    logic [P_SPL-1:0]               vid[0:P_LANES-1];
    logic [P_SPL-1:0]               vid_reg[0:P_LANES-1];
    logic [P_SPL-1:0]               vid_reg_del[0:P_LANES-1];
    logic                           str;                    // Start
    logic                           str_sticky;             // Start
    logic                           str_toggle;
    logic [P_SPL-1:0]               vbid[0:P_LANES-1];
    logic [P_SPL-1:0]               vbid_reg[0:P_LANES-1];
    logic [P_LANES-1:0]             nvs_lane; // No video stream flag per lane
    logic [P_LANES-1:0]             vbf_lane; // Vertical blanking flag per
    logic                           nvs;      // No video stream flag
    logic                           vbf;      // Vertical blanking flag 
    logic [P_SPL-1:0]               k[0:P_LANES-1];
    logic [7:0]                     dat[0:P_LANES-1][0:P_SPL-1];
    logic [7:0]                     dat_reg[0:P_LANES-1][0:P_SPL-1];
    logic [7:0]                     dat_reg_del[0:P_LANES-1][0:P_SPL-1];
} lnk_struct;

typedef struct {
    logic [1:0]                     lph[0:P_LANES-1];
    logic [1:0]                     fph[0:P_LANES-1];
    logic [1:0]                     sel[0:P_LANES-1];
    logic [P_SPL-1:0]               eol[0:P_LANES-1];
    logic [P_LANES-1:0]             str;
    logic [P_SPL-1:0]               wr[0:P_LANES-1];
    logic [7:0]                     dat[0:P_LANES-1][0:P_SPL-1];
} aln_struct;

typedef struct {
    logic [4:0]                     cnt[0:P_LANES-1][0:P_SPL-1];
    logic [P_FIFO_STRIPES-1:0]      eol[0:P_LANES-1];
    logic [P_FIFO_STRIPES-1:0]      wr[0:P_LANES-1];
    logic [7:0]                     dat[0:P_LANES-1][0:P_FIFO_STRIPES-1];
} lnk_map_struct;

typedef struct {
    logic	[P_FIFO_STRIPES-1:0]	wr[0:P_LANES-1];  
    logic   [P_FIFO_DAT-1:0]        din[0:P_LANES-1][0:P_FIFO_STRIPES-1];
    logic   [1:0]                   head_byte[0:P_LANES-1];
    logic   [5:0]                   head_lane[0:P_LANES-1];
    logic   [5:0]                   head_tmp[0:1];
    logic   [5:0]                   head;
    logic   [P_FIFO_ADR:0]          wrds[0:P_LANES-1][0:P_FIFO_STRIPES-1];
    logic   [P_FIFO_STRIPES-1:0]    fl[0:P_LANES-1];
    logic   [P_FIFO_STRIPES-1:0]    ep[0:P_LANES-1];
} lnk_fifo_struct;

typedef struct {
    logic	[P_FIFO_STRIPES-1:0]   	rd[0:P_LANES-1];
    logic	[P_FIFO_DAT-1:0]        dout[0:P_LANES-1][0:P_FIFO_STRIPES-1];
    logic	[P_FIFO_STRIPES-1:0]	de[0:P_LANES-1];
    logic                           de_all;
    logic   [P_FIFO_ADR:0]          wrds[0:P_LANES-1][0:P_FIFO_STRIPES-1];
    logic   [P_FIFO_STRIPES-1:0]    fl[0:P_LANES-1];
    logic   [P_FIFO_STRIPES-1:0]    ep[0:P_LANES-1];
    logic   [5:0]                   head;
    logic   [5:0]                   head_del;
    logic                           head_new;
    logic   [5:0]                   tail;
    logic   [5:0]                   delta;
    logic                           rd_cnt_ld;
    logic   [7:0]                   rd_cnt_in;
    logic   [7:0]                   rd_cnt;
    logic                           rd_cnt_end;
    logic                           rd_cnt_last;
    logic   [2:0]                   rd_seq;
} vid_fifo_struct;

typedef struct {
    logic   [2:0]                   seq;      // Sequence
	logic 	[2:0]					sel[0:(P_PPC*3)-1];
    logic 	[P_FIFO_DAT-1:0]        din[0:(P_PPC*3)-1][0:P_MAP_CH-1];
    logic 	[P_FIFO_DAT-1:0]        dout[0:(P_PPC*3)-1];
} vid_map_struct;

typedef struct {
    logic                           lock;     // Lock
    logic [1:0]                     lanes;
    logic                           str_toggle;
    logic                           str_re;
    logic                           str_fe;
    logic                           str;      // Start
    logic [7:0]                     msk;      // Mask
    logic                           nvs;      // No video stream flag
    logic                           vbf;      // Vertical blanking flag 
    logic                           vbf_re;   // Vertical blanking flag rising edge
    logic                           vbf_sticky;
    logic                           sof;      // Start of frame
    logic                           eol;      // End of line
    logic [P_VID_DAT-1:0] 			dat;      // Data
    logic                           vld;      // Valid
    logic                           err;
} vid_struct;

// Signals
lnk_struct          lclk_lnk;
aln_struct          lclk_aln;
lnk_map_struct      lclk_map;
lnk_fifo_struct     lclk_fifo;
vid_fifo_struct     vclk_fifo;
vid_map_struct      vclk_map;
vid_struct          vclk_vid;

genvar i, j;

// Logic

// Config
    always_ff @ (posedge LNK_CLK_IN)
    begin
        lclk_lnk.lanes <= CTL_LANES_IN;
    end

// Link input
    always_comb
    begin
        for (int i = 0; i < P_LANES; i++)
        begin
            lclk_lnk.vbid[i] = LNK_SNK_IF.vbid[i];

            lclk_lnk.sol[i] = LNK_SNK_IF.sol[i];

            // For the end of line we are only interested in the last (active) lane

            // Four active lanes
            if ((lclk_lnk.lanes == 'd3) && (i == 3))
                lclk_lnk.eol[i]  = LNK_SNK_IF.eol[i];

            // Two active lanes
            else if ((lclk_lnk.lanes == 'd2) && (i == 1))
                lclk_lnk.eol[i]  = LNK_SNK_IF.eol[i];

            // One active lanes
            else if ((lclk_lnk.lanes == 'd1) && (i == 0))
                lclk_lnk.eol[i]  = LNK_SNK_IF.eol[i];
            
            else
                lclk_lnk.eol[i] = 0;

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
            lclk_lnk.eol_reg[i]     <= lclk_lnk.eol[i];
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
            lclk_lnk.eol_reg_del[i] <= lclk_lnk.eol_reg[i];
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

// VB-ID register per lane
// This will capture the NoVideoStream_flag and vertical blanking flag.
    always_ff @ (posedge LNK_CLK_IN)
    begin
        for (int i = 0; i < P_LANES; i++)
        begin
            // Lock
            if (lclk_lnk.lock)
            begin
                // Four symbols per lane
                if (P_SPL == 4)
                begin
                    // Sublane 0
                    if (lclk_lnk.vbid_reg[i][0])
                    begin
                        lclk_lnk.nvs_lane[i] <= lclk_lnk.dat_reg[i][0][3];
                        lclk_lnk.vbf_lane[i] <= lclk_lnk.dat_reg[i][0][0];
                    end

                    // Sublane 1
                    else if (lclk_lnk.vbid_reg[i][1])
                    begin
                        lclk_lnk.nvs_lane[i] <= lclk_lnk.dat_reg[i][1][3];
                        lclk_lnk.vbf_lane[i] <= lclk_lnk.dat_reg[i][1][0];
                    end

                    // Sublane 2
                    else if (lclk_lnk.vbid_reg[i][2])
                    begin
                        lclk_lnk.nvs_lane[i] <= lclk_lnk.dat_reg[i][2][3];
                        lclk_lnk.vbf_lane[i] <= lclk_lnk.dat_reg[i][2][0];
                    end

                    // Sublane 3
                    else if (lclk_lnk.vbid_reg[i][3])
                    begin
                        lclk_lnk.nvs_lane[i] <= lclk_lnk.dat_reg[i][3][3];
                        lclk_lnk.vbf_lane[i] <= lclk_lnk.dat_reg[i][3][0];
                    end
                end

                // Two symbols per lane
                else
                begin
                    // Sublane 0
                    if (lclk_lnk.vbid_reg[i][0])
                    begin
                        lclk_lnk.nvs_lane[i] <= lclk_lnk.dat_reg[i][0][3];
                        lclk_lnk.vbf_lane[i] <= lclk_lnk.dat_reg[i][0][0];
                    end

                    // Sublane 1
                    else if (lclk_lnk.vbid_reg[i][1])
                    begin
                        lclk_lnk.nvs_lane[i] <= lclk_lnk.dat_reg[i][1][3];
                        lclk_lnk.vbf_lane[i] <= lclk_lnk.dat_reg[i][1][0];
                    end
                end    
            end

            // No lock
            else
            begin
                lclk_lnk.nvs_lane[i] <= 1;
                lclk_lnk.vbf_lane[i] <= 0;
            end
        end
    end

// VB-ID register combined
// As an extra lane integrity check all the lanes should have the same value
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Four active lanes
        if (lclk_lnk.lanes == 'd3)
        begin   
            if (lclk_lnk.nvs_lane == 'b0000)
                lclk_lnk.nvs <= 0;
            else
                lclk_lnk.nvs <= 1;

            if (lclk_lnk.vbf_lane == 'b1111)
                lclk_lnk.vbf <= 1;
            else
                lclk_lnk.vbf <= 0;
        end

        // Two active lanes
        else if (lclk_lnk.lanes == 'd2)
        begin   
            if (lclk_lnk.nvs_lane[1:0] == 'b00)
                lclk_lnk.nvs <= 0;
            else
                lclk_lnk.nvs <= 1;

            if (lclk_lnk.vbf_lane[1:0] == 'b11)
                lclk_lnk.vbf <= 1;
            else
                lclk_lnk.vbf <= 0;
        end

        // One active lane
        else
        begin
            lclk_lnk.nvs <= lclk_lnk.nvs_lane[0];
            lclk_lnk.vbf <= lclk_lnk.vbf_lane[0];
        end
    end

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

                    lclk_aln.eol[i][0] <= lclk_lnk.eol_reg_del[i][1];
                    lclk_aln.eol[i][1] <= lclk_lnk.eol_reg_del[i][2];
                    lclk_aln.eol[i][2] <= lclk_lnk.eol_reg_del[i][3];
                    lclk_aln.eol[i][3] <= lclk_lnk.eol_reg[i][0];
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

                    lclk_aln.eol[i][0] <= lclk_lnk.eol_reg_del[i][2];
                    lclk_aln.eol[i][1] <= lclk_lnk.eol_reg_del[i][3];
                    lclk_aln.eol[i][2] <= lclk_lnk.eol_reg[i][0];
                    lclk_aln.eol[i][3] <= lclk_lnk.eol_reg[i][1];
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

                    lclk_aln.eol[i][0] <= lclk_lnk.eol_reg_del[i][3];
                    lclk_aln.eol[i][1] <= lclk_lnk.eol_reg[i][0];
                    lclk_aln.eol[i][2] <= lclk_lnk.eol_reg[i][1];
                    lclk_aln.eol[i][3] <= lclk_lnk.eol_reg[i][2];
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
                    
                    lclk_aln.eol[i][0] <= lclk_lnk.eol_reg[i][0];
                    lclk_aln.eol[i][1] <= lclk_lnk.eol_reg[i][1];
                    lclk_aln.eol[i][2] <= lclk_lnk.eol_reg[i][2];
                    lclk_aln.eol[i][3] <= lclk_lnk.eol_reg[i][3];
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
                    lclk_aln.eol[i][0] <= lclk_lnk.eol_reg_del[i][1];
                    lclk_aln.eol[i][1] <= lclk_lnk.eol_reg[i][0];
                end

                // Normal
                else
                begin
                    lclk_aln.dat[i][0] <= lclk_lnk.dat_reg[i][0];
                    lclk_aln.dat[i][1] <= lclk_lnk.dat_reg[i][1];
                    lclk_aln.wr[i][0]  <= lclk_lnk.vid_reg[i][0];
                    lclk_aln.wr[i][1]  <= lclk_lnk.vid_reg[i][1];
                    lclk_aln.eol[i][0] <= lclk_lnk.eol_reg[i][0];
                    lclk_aln.eol[i][1] <= lclk_lnk.eol_reg[i][1];
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
                        if ( ((lclk_lnk.lanes == 'd1) && (lclk_map.cnt[i][j] == 'd11)) || ((lclk_lnk.lanes == 'd2) && (lclk_map.cnt[i][j] == 'd5)) ) 
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
                        if ( ((lclk_lnk.lanes == 'd1) && (lclk_map.cnt[i][j] == 'd23)) || ((lclk_lnk.lanes == 'd2) && (lclk_map.cnt[i][j] == 'd11)) || ((lclk_lnk.lanes == 'd3) && (lclk_map.cnt[i][j] == 'd1)) ) 
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
            if (lclk_lnk.lanes == 'd1)
            begin

                // Default
                for (int i = 0; i < P_LANES; i++)
                begin
                    for (int j = 0; j < P_SPL; j++)
                        lclk_map.eol[i][j] <= 0;
                end

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
                    lclk_map.eol[0][0] <= lclk_aln.eol[0][2];
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
                    lclk_map.eol[0][1] <= lclk_aln.eol[0][2];
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
                    lclk_map.eol[0][2] <= lclk_aln.eol[0][2];
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
                    lclk_map.eol[0][3] <= lclk_aln.eol[0][2];
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
                    lclk_map.eol[1][0] <= lclk_aln.eol[0][1];
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
                    lclk_map.eol[1][1] <= lclk_aln.eol[0][1];
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
                    lclk_map.eol[1][2] <= lclk_aln.eol[0][1];
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
                    lclk_map.eol[1][3] <= lclk_aln.eol[0][1];
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
                    lclk_map.eol[2][0] <= lclk_aln.eol[0][0];
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
                    lclk_map.eol[2][1] <= lclk_aln.eol[0][0];
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
                    lclk_map.eol[2][2] <= lclk_aln.eol[0][0];
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
                    lclk_map.eol[2][3] <= lclk_aln.eol[0][0];
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
                    lclk_map.eol[3][0] <= lclk_aln.eol[0][3];
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
                    lclk_map.eol[3][1] <= lclk_aln.eol[0][3];
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
                    lclk_map.eol[3][2] <= lclk_aln.eol[0][3];
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
                    lclk_map.eol[3][3] <= lclk_aln.eol[0][3];
                end

                // Idle
                else
                begin
                    lclk_map.dat[3][3] <= 0;
                    lclk_map.wr[3][3] <= 0;
                end
            end

            // 2 lanes
            else if (lclk_lnk.lanes == 'd2)
            begin

                // Default
                for (int i = 0; i < P_LANES; i++)
                begin
                    for (int j = 0; j < P_SPL; j++)
                        lclk_map.eol[i][j] <= 0;
                end

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
                    lclk_map.eol[0][0] <= lclk_aln.eol[0][2];
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
                    lclk_map.eol[0][1] <= lclk_aln.eol[0][0];
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
                    lclk_map.eol[0][2] <= lclk_aln.eol[0][2];
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
                    lclk_map.eol[0][3] <= lclk_aln.eol[0][0];
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
                    lclk_map.eol[1][0] <= lclk_aln.eol[1][2];
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
                    lclk_map.eol[1][1] <= lclk_aln.eol[1][0];
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
                    lclk_map.eol[1][2] <= lclk_aln.eol[1][2];
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
                    lclk_map.eol[1][3] <= lclk_aln.eol[1][0];
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
                    lclk_map.eol[2][0] <= lclk_aln.eol[0][1];
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
                    lclk_map.eol[2][1] <= lclk_aln.eol[0][3];
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
                    lclk_map.eol[2][2] <= lclk_aln.eol[0][1];
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
                    lclk_map.eol[2][3] <= lclk_aln.eol[0][3];
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
                    lclk_map.eol[3][0] <= lclk_aln.eol[1][1];
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
                    lclk_map.eol[3][1] <= lclk_aln.eol[1][3];
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
                    lclk_map.eol[3][2] <= lclk_aln.eol[1][1];
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
                    lclk_map.eol[3][3] <= lclk_aln.eol[1][3];
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
                        lclk_map.eol[i][j] <= lclk_aln.eol[i][j];
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
                        lclk_map.eol[i][j] <= 0;
                end
            end

            // 1 lane
            if (lclk_lnk.lanes == 'd1)
            begin

                // Default
                for (int i = 0; i < P_LANES; i++)
                begin
                    for (int j = 0; j < P_SPL; j++)
                        lclk_map.eol[i][j] <= 0;
                end

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
                    lclk_map.eol[0][0] <= lclk_aln.eol[0][0];
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
                    lclk_map.eol[0][1] <= lclk_aln.eol[0][0];
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
                    lclk_map.eol[0][2] <= lclk_aln.eol[0][0];
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
                    lclk_map.eol[0][3] <= lclk_aln.eol[0][0];
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
                    lclk_map.eol[1][0] <= lclk_aln.eol[0][1];
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
                    lclk_map.eol[1][1] <= lclk_aln.eol[0][1];
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
                    lclk_map.eol[1][2] <= lclk_aln.eol[0][1];
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
                    lclk_map.eol[1][3] <= lclk_aln.eol[0][1];
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
                    lclk_map.eol[2][0] <= lclk_aln.eol[0][0];
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
                    lclk_map.eol[2][1] <= lclk_aln.eol[0][0];
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
                    lclk_map.eol[2][2] <= lclk_aln.eol[0][0];
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
                    lclk_map.eol[2][3] <= lclk_aln.eol[0][0];
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
                    lclk_map.eol[3][0] <= lclk_aln.eol[0][1];
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
                    lclk_map.eol[3][1] <= lclk_aln.eol[0][1];
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
                    lclk_map.eol[3][2] <= lclk_aln.eol[0][1];
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
                    lclk_map.eol[3][3] <= lclk_aln.eol[0][1];
                end

                // Idle
                else
                begin
                    lclk_map.dat[3][3] <= 0;
                    lclk_map.wr[3][3] <= 0;
                end
            end

            // 2 lanes
            else if (lclk_lnk.lanes == 'd2)
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
                    lclk_map.eol[0][0] <= lclk_aln.eol[0][0];
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
                    lclk_map.eol[0][1] <= lclk_aln.eol[0][0];
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
                    lclk_map.eol[0][2] <= lclk_aln.eol[0][0];
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
                    lclk_map.eol[0][3] <= lclk_aln.eol[0][0];
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
                    lclk_map.eol[1][0] <= lclk_aln.eol[1][0];
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
                    lclk_map.eol[1][1] <= lclk_aln.eol[1][0];
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
                    lclk_map.eol[1][2] <= lclk_aln.eol[1][0];
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
                    lclk_map.eol[1][3] <= lclk_aln.eol[1][0];
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
                    lclk_map.eol[2][0] <= lclk_aln.eol[0][1];
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
                    lclk_map.eol[2][1] <= lclk_aln.eol[0][1];
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
                    lclk_map.eol[2][2] <= lclk_aln.eol[0][1];
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
                    lclk_map.eol[2][3] <= lclk_aln.eol[0][1];
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
                    lclk_map.eol[3][0] <= lclk_aln.eol[1][1];
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
                    lclk_map.eol[3][1] <= lclk_aln.eol[1][1];
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
                    lclk_map.eol[3][2] <= lclk_aln.eol[1][1];
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
                    lclk_map.eol[3][3] <= lclk_aln.eol[1][1];
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
                            lclk_map.eol[i][j] <= lclk_aln.eol[i][j];
                        end

                        // Upper sublane
                        else if ((lclk_map.cnt[i][j] == 'd1) && lclk_aln.wr[i][j])
                        begin
                            lclk_map.dat[i][j+2] <= lclk_aln.dat[i][j];
                            lclk_map.wr[i][j+2] <= 1;
                            lclk_map.eol[i][j+2] <= lclk_aln.eol[i][j];
                        end
                    end
                end
            end
        end
    end 
endgenerate



/*
    FIFO
*/

// Head lane
// This process counts the number of blocks (12 bytes) in the fifo.
// This is used for read logic.
// Only the last stripe of each fifo is used.
// As there might be skew between the lanes, there is one head counter for each lane.
generate
    for (i = 0; i < P_LANES; i++)
    begin
        always_ff @ (posedge LNK_CLK_IN)
        begin
            // Lock
            if (lclk_lnk.lock)
            begin
                // Clear
                if (lclk_lnk.str)
                begin
                    lclk_fifo.head_byte[i] <= 0;
                    lclk_fifo.head_lane[i] <= 0;
                end

                // Increment
                else if (lclk_fifo.wr[i][P_FIFO_STRIPES-1])
                begin
                    // One block consists of three writes
                    if (lclk_fifo.head_byte[i] == 'd2)
                    begin
                        lclk_fifo.head_lane[i] <= lclk_fifo.head_lane[i] + 'd1;
                        lclk_fifo.head_byte[i] <= 0;
                    end

                    else
                        lclk_fifo.head_byte[i] <= lclk_fifo.head_byte[i] + 'd1;
                end
            end

            else
            begin
                lclk_fifo.head_byte[i] <= 0;
                lclk_fifo.head_lane[i] <= 0;
            end    
        end
    end
endgenerate

// Head lowest
// Due to the skew some lanes might lead or lag.
// To prevent under-running of the FIFO we have to find the lowest head.
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // To improve performance this process is split into two levels
        // Lanes 0 and 1
        if (lclk_fifo.head[0] < lclk_fifo.head[1])
            lclk_fifo.head_tmp[0] <= lclk_fifo.head_lane[0];
        else
            lclk_fifo.head_tmp[0] <= lclk_fifo.head_lane[1];

        // Lanes 2 and 3
        if (lclk_fifo.head[2] < lclk_fifo.head[3])
            lclk_fifo.head_tmp[1] <= lclk_fifo.head_lane[2];
        else
            lclk_fifo.head_tmp[1] <= lclk_fifo.head_lane[3];

        // Final result
        if (lclk_fifo.head_tmp[0] < lclk_fifo.head_tmp[1])
            lclk_fifo.head <= lclk_fifo.head_tmp[0];
        else
            lclk_fifo.head <= lclk_fifo.head_tmp[1];
    end

// FIFO
// The incoming video data is stored in a stripe (FIFO). 
generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_fifo       
        for (j = 0; j < P_FIFO_STRIPES; j++)
        begin

            // Data
            assign lclk_fifo.din[i][j] = {lclk_map.eol[i][j], lclk_map.dat[i][j]};
            
            // Write
            assign lclk_fifo.wr[i][j] = lclk_map.wr[i][j];
 
            // FIFO
            prt_dp_lib_fifo_dc
            #(
                .P_VENDOR       (P_VENDOR),             // Vendor
            	.P_MODE         ("burst"),		        // "single" or "burst"
            	.P_RAM_STYLE	("distributed"),	    // "distributed" or "block"
            	.P_ADR_WIDTH	(P_FIFO_ADR),
            	.P_DAT_WIDTH	(P_FIFO_DAT)
            )
            FIFO_INST
            (
                .A_RST_IN      (~lclk_lnk.lock),            // Reset
                .B_RST_IN      (~vclk_vid.lock),
                .A_CLK_IN      (LNK_CLK_IN),                // Clock
                .B_CLK_IN      (VID_CLK_IN),
                .A_CKE_IN      (1'b1),                      // Clock enable
                .B_CKE_IN      (1'b1),

                // Input (A)
                .A_CLR_IN      (lclk_lnk.str),          // Clear
                .A_WR_IN       (lclk_fifo.wr[i][j]),        // Write
                .A_DAT_IN      (lclk_fifo.din[i][j]),       // Write data

                // Output (B)
                .B_CLR_IN      (vclk_vid.str),              // Clear
                .B_RD_IN       (vclk_fifo.rd[i][j]),        // Read
                .B_DAT_OUT     (vclk_fifo.dout[i][j]),      // Read data
                .B_DE_OUT      (vclk_fifo.de[i][j]),        // Data enable

                // Status (A)
                .A_WRDS_OUT    (lclk_fifo.wrds[i][j]),      // Used words
                .A_FL_OUT      (lclk_fifo.fl[i][j]),        // Full
                .A_EP_OUT      (lclk_fifo.ep[i][j]),        // Empty

                // Status (B)
                .B_WRDS_OUT    (vclk_fifo.wrds[i][j]),      // Used words
                .B_FL_OUT      (vclk_fifo.fl[i][j]),        // Full
                .B_EP_OUT      (vclk_fifo.ep[i][j])         // Empty
            );
        end
    end
endgenerate

/*
    Video domain
*/

// Lanes clock domain crossing
    prt_dp_lib_cdc_vec
    #(
        .P_WIDTH        ($size(lclk_lnk.lanes))
    )
    VCLK_LANES_CDC_INST
    (
        .SRC_CLK_IN     (LNK_CLK_IN),         // Clock
        .SRC_DAT_IN     (lclk_lnk.lanes),     // Data
        .DST_CLK_IN     (VID_CLK_IN),         // Clock
        .DST_DAT_OUT    (vclk_vid.lanes)      // Data
    );

// Lock clock domain crossing
    prt_dp_lib_cdc_bit
    VCLK_LOCK_CDC_INST
    (
        .SRC_CLK_IN     (LNK_CLK_IN),       // Clock
        .SRC_DAT_IN     (lclk_lnk.lock),    // Data
        .DST_CLK_IN     (VID_CLK_IN),       // Clock
        .DST_DAT_OUT    (vclk_vid.lock)     // Data
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

// Head clock domain crossing
    prt_dp_lib_cdc_gray
    #(
        .P_VENDOR       (P_VENDOR),
        .P_WIDTH        ($size(lclk_fifo.head))
    )
    VCLK_HEAD_CDC_INST
    (
        .SRC_CLK_IN     (LNK_CLK_IN),         // Clock
        .SRC_DAT_IN     (lclk_fifo.head),     // Data
        .DST_CLK_IN     (VID_CLK_IN),         // Clock
        .DST_DAT_OUT    (vclk_fifo.head)      // Data
    );

// Start of line 
// This signal is captured from the link domain
    always_ff @ (posedge VID_CLK_IN)
    begin
        vclk_vid.str <= vclk_vid.str_re || vclk_vid.str_fe;
    end

// Mask
// At the start of a new line, the head value is cleared to zero. 
// There is a possible race condition between the head, tail and delta values when this condition occurs. 
// To prevent a false read sequence this mask flag is asserted. 
// This flag is simply a delay of the first FIFO empty signal. 
    always_ff @ (posedge VID_CLK_IN)
    begin
        vclk_vid.msk <= {vclk_vid.msk[0+:$size(vclk_vid.msk)-1], vclk_fifo.ep[0][0]};
    end

// Head delayed
// Due to the clock domain crossing latency and possible race condition with the clearing of the tail,
// the captured head is registered. 
// When the two signals are difference, there is new data in the fifo.
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Lock
        if (vclk_vid.lock)
            vclk_fifo.head_del <= vclk_fifo.head;        

        else
            vclk_fifo.head_del <= 0;
    end

// New head
// This flag is asserted when there is a new head pointer
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Lock
        if (vclk_vid.lock)
        begin

            // Clear
            // At the start of a read sequence or when the mask signal is asserted.
            if (vclk_fifo.rd_cnt_ld || (|vclk_vid.msk))
                vclk_fifo.head_new <= 0;

            // Set
            else if (vclk_fifo.head_del != vclk_fifo.head)
                vclk_fifo.head_new <= 1;        
        end

        else
            vclk_fifo.head_new <= 0;
    end

// Tail
// This process keeps track of the read bytes from the fifo.
// As the reading is synchronous only the first fifo is counted.
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Lock
        if (vclk_vid.lock)
        begin
            // Clear
            if (vclk_vid.str)
                vclk_fifo.tail <= 0;

            // Increment
            else if (vclk_fifo.rd_cnt_ld)
                vclk_fifo.tail <= vclk_fifo.tail + vclk_fifo.delta;
        end

        else
            vclk_fifo.tail <= 0;
    end

// Delta
    always_comb
    begin
        if (vclk_fifo.head > vclk_fifo.tail)
            vclk_fifo.delta = vclk_fifo.head - vclk_fifo.tail;
        else
            vclk_fifo.delta = (2**$size(vclk_fifo.tail) - vclk_fifo.tail) + vclk_fifo.head;
    end        

// Data enable all
// This process combines the data enable of all fifos.
    always_comb
    begin
        // Default
        vclk_fifo.de_all = 0;

        // Four lanes
        if (vclk_vid.lanes)
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                for (int j = 0; j < P_FIFO_STRIPES; j++)
                begin
                    if (vclk_fifo.de[i][j])
                        vclk_fifo.de_all = 1;
                end
            end
        end

        else
        begin
            for (int i = 0; i < 2; i++)
            begin
                for (int j = 0; j < P_FIFO_STRIPES; j++)
                begin
                    if (vclk_fifo.de[i][j])
                        vclk_fifo.de_all = 1;
                end
            end
        end    
    end

// Read counter in
generate
    if (P_PPC == 4)
    begin : gen_rd_cnt_in_4ppc
        assign vclk_fifo.rd_cnt_in = {vclk_fifo.delta[0+:6], 2'b00}; // One block is four reads
    end

    else
    begin : gen_rd_cnt_in_2ppc
        assign vclk_fifo.rd_cnt_in = {vclk_fifo.delta[0+:5], 3'b000}; // One block is eight reads
    end
endgenerate

// Read counter load
    always_comb
    begin
        if ((vclk_fifo.rd_cnt_end || vclk_fifo.rd_cnt_last) && vclk_fifo.head_new && (vclk_fifo.delta != 0))
            vclk_fifo.rd_cnt_ld = 1;
        else
            vclk_fifo.rd_cnt_ld = 0;    
    end

// Read counter
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Lock
        if (vclk_vid.lock)
        begin
            // The counter is cleared on every start of a new line 
            if (vclk_vid.str)
                vclk_fifo.rd_cnt <= 0;
            
            else
            begin
                // Load
                if (vclk_fifo.rd_cnt_ld)
                    vclk_fifo.rd_cnt <= vclk_fifo.rd_cnt_in;

                // Decrement
                else if (!vclk_fifo.rd_cnt_end)
                begin
                    // Four lanes
                    if (vclk_vid.lanes)
                        vclk_fifo.rd_cnt <= vclk_fifo.rd_cnt - 'd1;
                    
                    // Two lanes
                    else
                        vclk_fifo.rd_cnt <= vclk_fifo.rd_cnt - 'd2;
                end
            end
        end

        // Idle
        else
            vclk_fifo.rd_cnt <= 0;
    end

// Read counter end
    always_comb
    begin
        if (vclk_fifo.rd_cnt == 0)
            vclk_fifo.rd_cnt_end = 1;
        else
            vclk_fifo.rd_cnt_end = 0;
    end

// Read counter last
    always_comb
    begin
        if (vclk_fifo.rd_cnt == 'd1)
            vclk_fifo.rd_cnt_last = 1;
        else
            vclk_fifo.rd_cnt_last = 0;
    end

// Read sequence
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Lock
        if (vclk_vid.lock)
        begin
            // Clear
            if (vclk_vid.str)
                vclk_fifo.rd_seq <= 0;
            
            // Increment
            else if (!vclk_fifo.rd_cnt_end)
            begin
                // Clear 4 PPC
                if ((vclk_fifo.rd_seq == 'd3) && (P_PPC == 4)) 
                    vclk_fifo.rd_seq <= 0;

                // Clear 2 PPC
                else if ((vclk_fifo.rd_seq == 'd7) && (P_PPC == 2)) 
                    vclk_fifo.rd_seq <= 0;

                // Increment
                else
                    vclk_fifo.rd_seq <= vclk_fifo.rd_seq + 'd1;
            end
        end

        else
            vclk_fifo.rd_seq <= 0;
    end

// Read 
generate
    // Four pixels per clock
    if (P_PPC == 4)
    begin : gen_fifo_rd_4ppc
        always_comb
        begin
            // Default
            for (int i = 0; i < P_LANES; i++)
                vclk_fifo.rd[i] = 0;

            if (!vclk_fifo.rd_cnt_end)
            begin
                case (vclk_fifo.rd_seq)

                    'd0 : 
                    begin
                        vclk_fifo.rd[0][0] = 1;  // R0
                        vclk_fifo.rd[0][1] = 1;  // G0
                        vclk_fifo.rd[0][2] = 1;  // B0
                        vclk_fifo.rd[1][0] = 1;  // R1
                        vclk_fifo.rd[1][1] = 1;  // G1
                        vclk_fifo.rd[1][2] = 1;  // B1
                        vclk_fifo.rd[2][0] = 1;  // R2
                        vclk_fifo.rd[2][1] = 1;  // G2
                        vclk_fifo.rd[2][2] = 1;  // B2
                        vclk_fifo.rd[3][0] = 1;  // R3
                        vclk_fifo.rd[3][1] = 1;  // G3
                        vclk_fifo.rd[3][2] = 1;  // B3
                    end             

                    'd1 : 
                    begin
                        vclk_fifo.rd[0][3] = 1;  // R4
                        vclk_fifo.rd[0][0] = 1;  // G4
                        vclk_fifo.rd[0][1] = 1;  // B4
                        vclk_fifo.rd[1][3] = 1;  // R5
                        vclk_fifo.rd[1][0] = 1;  // G5
                        vclk_fifo.rd[1][1] = 1;  // B5
                        vclk_fifo.rd[2][3] = 1;  // R6
                        vclk_fifo.rd[2][0] = 1;  // G6
                        vclk_fifo.rd[2][1] = 1;  // B6
                        vclk_fifo.rd[3][3] = 1;  // R7
                        vclk_fifo.rd[3][0] = 1;  // G7
                        vclk_fifo.rd[3][1] = 1;  // B7
                    end             

                    'd2 : 
                    begin
                        vclk_fifo.rd[0][2] = 1;  // R8
                        vclk_fifo.rd[0][3] = 1;  // G8
                        vclk_fifo.rd[0][0] = 1;  // B8
                        vclk_fifo.rd[1][2] = 1;  // R9
                        vclk_fifo.rd[1][3] = 1;  // G9
                        vclk_fifo.rd[1][0] = 1;  // B9
                        vclk_fifo.rd[2][2] = 1;  // R10
                        vclk_fifo.rd[2][3] = 1;  // G10
                        vclk_fifo.rd[2][0] = 1;  // B10
                        vclk_fifo.rd[3][2] = 1;  // R11
                        vclk_fifo.rd[3][3] = 1;  // G11
                        vclk_fifo.rd[3][0] = 1;  // B11
                    end             

                    'd3 : 
                    begin
                        vclk_fifo.rd[0][1] = 1;  // R12
                        vclk_fifo.rd[0][2] = 1;  // G12
                        vclk_fifo.rd[0][3] = 1;  // B12
                        vclk_fifo.rd[1][1] = 1;  // R13
                        vclk_fifo.rd[1][2] = 1;  // G13
                        vclk_fifo.rd[1][3] = 1;  // B13
                        vclk_fifo.rd[2][1] = 1;  // R14
                        vclk_fifo.rd[2][2] = 1;  // G14
                        vclk_fifo.rd[2][3] = 1;  // B14
                        vclk_fifo.rd[3][1] = 1;  // R15
                        vclk_fifo.rd[3][2] = 1;  // G15
                        vclk_fifo.rd[3][3] = 1;  // B15
                    end             
                endcase
            end
        end
    end
    
    // Two pixels per clock
    else
    begin
        always_comb
        begin
            // Default
            for (int i = 0; i < P_LANES; i++)
                vclk_fifo.rd[i] = 0;

            if (!vclk_fifo.rd_cnt_end)
            begin
           		case (vclk_fifo.rd_seq)
                    'd0 :
                    begin
                        vclk_fifo.rd[0][0] = 1;  // R0
                        vclk_fifo.rd[0][1] = 1;  // G0
                        vclk_fifo.rd[0][2] = 1;  // B0
                        vclk_fifo.rd[1][0] = 1;  // R1
                        vclk_fifo.rd[1][1] = 1;  // G1
                        vclk_fifo.rd[1][2] = 1;  // R1
                    end             
                			
        			'd1 : 
        			begin
        				vclk_fifo.rd[2][0] = 1;	// R2
        				vclk_fifo.rd[2][1] = 1;	// G2
        				vclk_fifo.rd[2][2] = 1;	// B2
        				vclk_fifo.rd[3][0] = 1;	// R3
        				vclk_fifo.rd[3][1] = 1;	// G3
        				vclk_fifo.rd[3][2] = 1;	// R3
        			end				

        			'd2 : 
        			begin
        				vclk_fifo.rd[0][3] = 1;	// R4
        				vclk_fifo.rd[0][0] = 1;	// G4
        				vclk_fifo.rd[0][1] = 1;	// B4
        				vclk_fifo.rd[1][3] = 1;	// R5
        				vclk_fifo.rd[1][0] = 1;	// G5
        				vclk_fifo.rd[1][1] = 1;	// R5
        			end				

        			'd3 : 
        			begin
        				vclk_fifo.rd[2][3] = 1;	// R6
        				vclk_fifo.rd[2][0] = 1;	// G6
        				vclk_fifo.rd[2][1] = 1;	// B6
        				vclk_fifo.rd[3][3] = 1;	// R7
        				vclk_fifo.rd[3][0] = 1;	// G7
        				vclk_fifo.rd[3][1] = 1;	// R7
        			end				

        			'd4 : 
        			begin
        				vclk_fifo.rd[0][2] = 1;	// R8
        				vclk_fifo.rd[0][3] = 1;	// G8
        				vclk_fifo.rd[0][0] = 1;	// B8
        				vclk_fifo.rd[1][2] = 1;	// R9
        				vclk_fifo.rd[1][3] = 1;	// G9
        				vclk_fifo.rd[1][0] = 1;	// R9
        			end				

        			'd5 : 
        			begin
        				vclk_fifo.rd[2][2] = 1;	// R10
        				vclk_fifo.rd[2][3] = 1;	// G10
        				vclk_fifo.rd[2][0] = 1;	// B10
        				vclk_fifo.rd[3][2] = 1;	// R11
        				vclk_fifo.rd[3][3] = 1;	// G11
        				vclk_fifo.rd[3][0] = 1;	// R11
        			end				

        			'd6 : 
        			begin
        				vclk_fifo.rd[0][1] = 1;	// R12
        				vclk_fifo.rd[0][2] = 1;	// G12
        				vclk_fifo.rd[0][3] = 1;	// B12
        				vclk_fifo.rd[1][1] = 1;	// R13
        				vclk_fifo.rd[1][2] = 1;	// G13
        				vclk_fifo.rd[1][3] = 1;	// R13
        			end				

        			'd7 : 
        			begin
        				vclk_fifo.rd[2][1] = 1;	// R14
        				vclk_fifo.rd[2][2] = 1;	// G14
        				vclk_fifo.rd[2][3] = 1;	// B14
        				vclk_fifo.rd[3][1] = 1;	// R15
        				vclk_fifo.rd[3][2] = 1;	// G15
        				vclk_fifo.rd[3][3] = 1;	// R15
        			end				
        		endcase
            end
        end
    end
endgenerate

/*
    Mapper
*/

// Data in
generate
    // Four pixels per clock
    if (P_PPC == 4)
    begin : gen_map_din_4ppc
        for (j = 0; j < P_SPL; j++)
        begin
            assign vclk_map.din[0][j]  = vclk_fifo.dout[0][j]; 
            assign vclk_map.din[1][j]  = vclk_fifo.dout[0][j]; 
            assign vclk_map.din[2][j]  = vclk_fifo.dout[0][j]; 

            assign vclk_map.din[3][j]  = vclk_fifo.dout[1][j]; 
            assign vclk_map.din[4][j]  = vclk_fifo.dout[1][j]; 
            assign vclk_map.din[5][j]  = vclk_fifo.dout[1][j]; 

            assign vclk_map.din[6][j]  = vclk_fifo.dout[2][j]; 
            assign vclk_map.din[7][j]  = vclk_fifo.dout[2][j]; 
            assign vclk_map.din[8][j]  = vclk_fifo.dout[2][j]; 

            assign vclk_map.din[9][j]  = vclk_fifo.dout[3][j]; 
            assign vclk_map.din[10][j] = vclk_fifo.dout[3][j]; 
            assign vclk_map.din[11][j] = vclk_fifo.dout[3][j];     
        end
    end

    // Two pixels per clock
    else
    begin : gen_map_din_2ppc
        for (i = 0; i < (P_PPC * 3); i++)
        begin : gen_map_din
            // Odd pixels
            if (i < 3)
            begin
            	for (j = 0; j < P_SPL * 4; j++)
            	begin
            		if (j < P_SPL * 2)
        				assign vclk_map.din[i][j] = vclk_fifo.dout[0][j];		// Lane 0
        			else
        				assign vclk_map.din[i][j] = vclk_fifo.dout[2][j-4];	// Lane 2
        		end
            end

            // Even pixels
        	else
            begin
            	for (j = 0; j < P_SPL * 4; j++)
            	begin
            		if (j < P_SPL * 2)
        				assign vclk_map.din[i][j] = vclk_fifo.dout[1][j];		// Lane 1
        			else
        				assign vclk_map.din[i][j] = vclk_fifo.dout[3][j-4];	// Lane 3
        		end
        	end	
        end
    end
endgenerate

// Data out
generate
    for (i = 0; i < (P_PPC * 3); i++)
    begin : gen_map_dout
    	assign vclk_map.dout[i] = vclk_map.din[i][vclk_map.sel[i]];
	end
endgenerate

// Sequence
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Lock
        if (vclk_vid.lock)
        begin
            // The counter is cleared on every start of a new line (lane 0)
            if (vclk_vid.str)
                vclk_map.seq <= 0;

            else
            begin
            	// Enable
            	if (vclk_fifo.de_all)
            	begin
            		// Overflow
            		if ((P_PPC == 4) && (vclk_map.seq == 'd3))
            			vclk_map.seq <= 0;

                    // Overflow
                    else if ((P_PPC == 2) && (vclk_map.seq == 'd7))
                        vclk_map.seq <= 0;

            		// Increment
            		else
                    begin
                        // Four lanes
                        if (vclk_vid.lanes)
            			    vclk_map.seq <= vclk_map.seq + 'd1;
                        else
                            vclk_map.seq <= vclk_map.seq + 'd2;
                    end
            	end
            end
        end

        // Idle
        else
            vclk_map.seq <= 0;
    end

// Select
generate
    // Four pixels per clock
    if (P_PPC == 4)
    begin : gen_map_sel_4ppc
        
        always_comb
        begin
            case (vclk_map.seq)
                
                'd1 : 
                begin
                    vclk_map.sel[0]  = 'd0; // Axis G0 = pixel G4 - FIFO lane 0 stripe 0
                    vclk_map.sel[3]  = 'd0; // Axis G1 = pixel G5 - FIFO lane 1 stripe 0
                    vclk_map.sel[6]  = 'd0; // Axis G2 = pixel G6 - FIFO lane 2 stripe 0
                    vclk_map.sel[9]  = 'd0; // Axis G3 = pixel G7 - FIFO lane 3 stripe 0
                    
                    vclk_map.sel[1]  = 'd3; // Axis R0 = pixel R4 - FIFO lane 0 stripe 3
                    vclk_map.sel[4]  = 'd3; // Axis R1 = pixel R5 - FIFO lane 1 stripe 3
                    vclk_map.sel[7]  = 'd3; // Axis R2 = pixel R6 - FIFO lane 2 stripe 3
                    vclk_map.sel[10] = 'd3; // Axis R3 = pixel R7 - FIFO lane 3 stripe 3
                    
                    vclk_map.sel[2]  = 'd1; // Axis B0 = pixel B4 - FIFO lane 0 stripe 1
                    vclk_map.sel[5]  = 'd1; // Axis B1 = pixel B5 - FIFO lane 1 stripe 1
                    vclk_map.sel[8]  = 'd1; // Axis B2 = pixel B6 - FIFO lane 2 stripe 1
                    vclk_map.sel[11] = 'd1; // Axis B3 = pixel B7 - FIFO lane 3 stripe 1
                end             

                'd2 : 
                begin
                    vclk_map.sel[0]  = 'd3; // Axis G0 = pixel G8  - FIFO lane 0 stripe 3
                    vclk_map.sel[3]  = 'd3; // Axis G1 = pixel G9  - FIFO lane 1 stripe 3
                    vclk_map.sel[6]  = 'd3; // Axis G2 = pixel G10 - FIFO lane 2 stripe 3
                    vclk_map.sel[9]  = 'd3; // Axis G3 = pixel G11 - FIFO lane 3 stripe 3
                    
                    vclk_map.sel[1]  = 'd2; // Axis R0 = pixel R8  - FIFO lane 0 stripe 2
                    vclk_map.sel[4]  = 'd2; // Axis R1 = pixel R9  - FIFO lane 1 stripe 2
                    vclk_map.sel[7]  = 'd2; // Axis R2 = pixel R10 - FIFO lane 2 stripe 2
                    vclk_map.sel[10] = 'd2; // Axis R3 = pixel R11 - FIFO lane 3 stripe 2
                    
                    vclk_map.sel[2]  = 'd0; // Axis B0 = pixel B8  - FIFO lane 0 stripe 0
                    vclk_map.sel[5]  = 'd0; // Axis B1 = pixel B9  - FIFO lane 1 stripe 0
                    vclk_map.sel[8]  = 'd0; // Axis B2 = pixel B10 - FIFO lane 2 stripe 0
                    vclk_map.sel[11] = 'd0; // Axis B3 = pixel B11 - FIFO lane 3 stripe 0
                end             

                'd3 : 
                begin
                    vclk_map.sel[0]  = 'd2; // Axis G0 = pixel G12 - FIFO lane 0 stripe 2
                    vclk_map.sel[3]  = 'd2; // Axis G1 = pixel G13 - FIFO lane 1 stripe 2
                    vclk_map.sel[6]  = 'd2; // Axis G2 = pixel G14 - FIFO lane 2 stripe 2
                    vclk_map.sel[9]  = 'd2; // Axis G3 = pixel G15 - FIFO lane 3 stripe 2
                    
                    vclk_map.sel[1]  = 'd1; // Axis R0 = pixel R12 - FIFO lane 0 stripe 1
                    vclk_map.sel[4]  = 'd1; // Axis R1 = pixel R13 - FIFO lane 1 stripe 1
                    vclk_map.sel[7]  = 'd1; // Axis R2 = pixel R14 - FIFO lane 2 stripe 1
                    vclk_map.sel[10] = 'd1; // Axis R3 = pixel R15 - FIFO lane 3 stripe 1
                    
                    vclk_map.sel[2]  = 'd3; // Axis B0 = pixel B12 - FIFO lane 0 stripe 3
                    vclk_map.sel[5]  = 'd3; // Axis B1 = pixel B13 - FIFO lane 1 stripe 3
                    vclk_map.sel[8]  = 'd3; // Axis B2 = pixel B14 - FIFO lane 2 stripe 3
                    vclk_map.sel[11] = 'd3; // Axis B3 = pixel B15 - FIFO lane 3 stripe 3
                end             

                default : 
                begin
                    vclk_map.sel[0]  = 'd1; // Axis G0 = pixel G0 - FIFO lane 0 stripe 1
                    vclk_map.sel[3]  = 'd1; // Axis G1 = pixel G1 - FIFO lane 1 stripe 1
                    vclk_map.sel[6]  = 'd1; // Axis G2 = pixel G2 - FIFO lane 2 stripe 1
                    vclk_map.sel[9]  = 'd1; // Axis G3 = pixel G3 - FIFO lane 3 stripe 1
                    
                    vclk_map.sel[1]  = 'd0; // Axis R0 = pixel R0 - FIFO lane 0 stripe 0
                    vclk_map.sel[4]  = 'd0; // Axis R1 = pixel R1 - FIFO lane 1 stripe 0
                    vclk_map.sel[7]  = 'd0; // Axis R2 = pixel R2 - FIFO lane 2 stripe 0
                    vclk_map.sel[10] = 'd0; // Axis R3 = pixel R3 - FIFO lane 3 stripe 0
                    
                    vclk_map.sel[2]  = 'd2; // Axis B0 = pixel B0 - FIFO lane 0 stripe 2
                    vclk_map.sel[5]  = 'd2; // Axis B1 = pixel B1 - FIFO lane 1 stripe 2
                    vclk_map.sel[8]  = 'd2; // Axis B2 = pixel B2 - FIFO lane 2 stripe 2
                    vclk_map.sel[11] = 'd2; // Axis B3 = pixel B3 - FIFO lane 3 stripe 2
                end             

            endcase
        end
    end

    // Two pixels per clock
    else
    begin : gen_map_sel_2ppc
    	always_comb
    	begin
    		case (vclk_map.seq)
    			
    			'd1 : 
    			begin
    				vclk_map.sel[0] = 'd5; // Axis G0 = pixel G2 - FIFO lane 2 stripe 1
    				vclk_map.sel[1] = 'd4; // Axis R0 = pixel R2 - FIFO lane 2 stripe 0
    				vclk_map.sel[2] = 'd6; // Axis B0 = pixel B2 - FIFO lane 2 stripe 2
    				vclk_map.sel[3] = 'd5; // Axis G1 = pixel G3 - FIFO lane 3 stripe 1
    				vclk_map.sel[4] = 'd4; // Axis R1 = pixel R3 - FIFO lane 3 stripe 0
    				vclk_map.sel[5] = 'd6; // Axis B1 = pixel B3 - FIFO lane 3 stripe 2
    			end				

    			'd2 : 
    			begin
    				vclk_map.sel[0] = 'd0; // Axis G0 = pixel G4 - FIFO lane 0 stripe 0
    				vclk_map.sel[1] = 'd3; // Axis R0 = pixel R4 - FIFO lane 0 stripe 3
    				vclk_map.sel[2] = 'd1; // Axis B0 = pixel B4 - FIFO lane 0 stripe 1
    				vclk_map.sel[3] = 'd0; // Axis G1 = pixel G5 - FIFO lane 1 stripe 0
    				vclk_map.sel[4] = 'd3; // Axis R1 = pixel R5 - FIFO lane 1 stripe 3
    				vclk_map.sel[5] = 'd1; // Axis B1 = pixel B5 - FIFO lane 1 stripe 1
    			end				

    			'd3 : 
    			begin
    				vclk_map.sel[0] = 'd4; // Axis G0 = pixel G6 - FIFO lane 2 stripe 0
    				vclk_map.sel[1] = 'd7; // Axis R0 = pixel R6 - FIFO lane 2 stripe 3
    				vclk_map.sel[2] = 'd5; // Axis B0 = pixel B6 - FIFO lane 2 stripe 1
    				vclk_map.sel[3] = 'd4; // Axis G1 = pixel G7 - FIFO lane 3 stripe 0
    				vclk_map.sel[4] = 'd7; // Axis R1 = pixel R7 - FIFO lane 3 stripe 3
    				vclk_map.sel[5] = 'd5; // Axis B1 = pixel B7 - FIFO lane 3 stripe 1
    			end				

    			'd4 : 
    			begin
    				vclk_map.sel[0] = 'd3; // Axis G0 = pixel G8 - FIFO lane 0 stripe 3
    				vclk_map.sel[1] = 'd2; // Axis R0 = pixel R8 - FIFO lane 0 stripe 2
    				vclk_map.sel[2] = 'd0; // Axis B0 = pixel B8 - FIFO lane 0 stripe 0
    				vclk_map.sel[3] = 'd3; // Axis G1 = pixel G9 - FIFO lane 1 stripe 3
    				vclk_map.sel[4] = 'd2; // Axis R1 = pixel R9 - FIFO lane 1 stripe 2
    				vclk_map.sel[5] = 'd0; // Axis B1 = pixel B9 - FIFO lane 1 stripe 0
    			end				

    			'd5 : 
    			begin
    				vclk_map.sel[0] = 'd7; // Axis G0 = pixel G10 - FIFO lane 2 stripe 3
    				vclk_map.sel[1] = 'd6; // Axis R0 = pixel R10 - FIFO lane 2 stripe 2
    				vclk_map.sel[2] = 'd4; // Axis B0 = pixel B10 - FIFO lane 2 stripe 0
    				vclk_map.sel[3] = 'd7; // Axis G1 = pixel G11 - FIFO lane 3 stripe 3
    				vclk_map.sel[4] = 'd6; // Axis R1 = pixel R11 - FIFO lane 3 stripe 2
    				vclk_map.sel[5] = 'd4; // Axis B1 = pixel B11 - FIFO lane 3 stripe 0
    			end				

    			'd6 : 
    			begin
    				vclk_map.sel[0] = 'd2; // Axis G0 = pixel G12 - FIFO lane 0 stripe 2
    				vclk_map.sel[1] = 'd1; // Axis R0 = pixel R12 - FIFO lane 0 stripe 1
    				vclk_map.sel[2] = 'd3; // Axis B0 = pixel B12 - FIFO lane 0 stripe 3
    				vclk_map.sel[3] = 'd2; // Axis G1 = pixel G13 - FIFO lane 1 stripe 2
    				vclk_map.sel[4] = 'd1; // Axis R1 = pixel R13 - FIFO lane 1 stripe 1
    				vclk_map.sel[5] = 'd3; // Axis B1 = pixel B13 - FIFO lane 1 stripe 3
    			end				

    			'd7 : 
    			begin
    				vclk_map.sel[0] = 'd6; // Axis G0 = pixel G12 - FIFO lane 2 stripe 2
    				vclk_map.sel[1] = 'd5; // Axis R0 = pixel R12 - FIFO lane 2 stripe 1
    				vclk_map.sel[2] = 'd7; // Axis B0 = pixel B12 - FIFO lane 2 stripe 3
    				vclk_map.sel[3] = 'd6; // Axis G1 = pixel G13 - FIFO lane 3 stripe 2
    				vclk_map.sel[4] = 'd5; // Axis R1 = pixel R13 - FIFO lane 3 stripe 1
    				vclk_map.sel[5] = 'd7; // Axis B1 = pixel B13 - FIFO lane 3 stripe 3
    			end				

    			default : 
    			begin
    				vclk_map.sel[0] = 'd1; // Axis G0 = pixel G0 - FIFO lane 0 stripe 1
    				vclk_map.sel[1] = 'd0; // Axis R0 = pixel R0 - FIFO lane 0 stripe 0
    				vclk_map.sel[2] = 'd2; // Axis B0 = pixel B0 - FIFO lane 0 stripe 2
    				vclk_map.sel[3] = 'd1; // Axis G1 = pixel G1 - FIFO lane 1 stripe 1
    				vclk_map.sel[4] = 'd0; // Axis R1 = pixel R1 - FIFO lane 1 stripe 0
    				vclk_map.sel[5] = 'd2; // Axis B1 = pixel B1 - FIFO lane 1 stripe 2
    			end				

    		endcase
        end
 	end
endgenerate

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
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Lock
        if (vclk_vid.lock)
        begin
            // Clear
            if (vclk_vid.sof)
                vclk_vid.vbf_sticky <= 0;

            // Set 
            else if (vclk_vid.vbf_re)
                vclk_vid.vbf_sticky <= 1;
        end

        else
            vclk_vid.vbf_sticky <= 0;
    end

// Video data
    always_ff @ (posedge VID_CLK_IN)
    begin
    	for (int i = 0; i < (P_PPC * 3); i++)
    	begin
    		vclk_vid.dat[(i*P_BPC)+:P_BPC] <= vclk_map.dout[i];
    	end
    end

// Video valid
    always_ff @ (posedge VID_CLK_IN)
    begin
		if (vclk_fifo.de_all)
			vclk_vid.vld <= 1;
		else
            vclk_vid.vld <= 0;
    end

// Start of frame
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Lock
        if (vclk_vid.lock)
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

        else
            vclk_vid.sof <= 0;
    end

// End of line
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Default
        vclk_vid.eol <= 0;

        // Lock
        if (vclk_vid.lock)
        begin
            if (vclk_fifo.de_all)
            begin
                // Last blue pixel carries the eol flag
                if (vclk_map.dout[(P_PPC * 3)-1][8])
                    vclk_vid.eol <= 1;
            end
        end
    end

// Checker
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Lock
        if (vclk_vid.lock)
        begin
            if (vclk_vid.eol)
                vclk_vid.err <= 0;

            else if (vclk_vid.vld)
            begin
                if (!(vclk_vid.dat == {4{24'h0000ff}}))
                    vclk_vid.err <= 1;
            end
        end

        else
            vclk_vid.err <= 0;
    end

// Outputs
    // Video source
    assign VID_EN_OUT       = ~vclk_vid.nvs;       // Enable
    assign VID_SRC_IF.sof   = vclk_vid.sof;        // Start of frame
    assign VID_SRC_IF.eol   = vclk_vid.eol;        // End of line
    assign VID_SRC_IF.dat   = vclk_vid.dat;        // Data
    assign VID_SRC_IF.vld   = vclk_vid.vld;        // Valid

endmodule

`default_nettype wire
