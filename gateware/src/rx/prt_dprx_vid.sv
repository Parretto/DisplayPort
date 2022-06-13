/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP RX Video
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

module prt_dprx_vid
#(
    // Link
    parameter               P_LANES = 4,    	// Lanes
    parameter               P_SPL = 2,      	// Symbols per lane

    // Video
    parameter               P_PPC = 2,      	// Pixels per clock
    parameter               P_BPC = 8,      	// Bits per component
    parameter 				P_VID_DAT = 48		// AXIS data width
)
(
    // Reset and clock
    input wire              RST_IN,             // Reset
    input wire              CLK_IN,             // Clock

    // Control
    input wire              CTL_LANES_IN,       // Active lanes (0 - 2 lanes / 1 - 4 lanes)

    // Link 
    prt_dp_rx_lnk_if.snk    LNK_SNK_IF,         // Sink

    // Video 
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
    logic                           lanes;                  // Active lanes
    logic [P_SPL-1:0]               sol[0:P_LANES-1];
    logic [P_SPL-1:0]               eol[0:P_LANES-1];
    logic [P_SPL-1:0]               eol_reg[0:P_LANES-1];
    logic [P_SPL-1:0]               eol_reg_del[0:P_LANES-1];
    logic [P_SPL-1:0]               vid[0:P_LANES-1];
    logic [P_SPL-1:0]               vid_reg[0:P_LANES-1];
    logic [P_SPL-1:0]               vid_reg_del[0:P_LANES-1];
    logic [P_SPL-1:0]               vbid;
    logic [P_SPL-1:0]               vbid_reg;
    logic [P_SPL-1:0]               k[0:P_LANES-1];
    logic [7:0]                     dat[0:P_LANES-1][0:P_SPL-1];
    logic [7:0]                     dat_reg[0:P_LANES-1][0:P_SPL-1];
    logic [7:0]                     dat_reg_del[0:P_LANES-1][0:P_SPL-1];
} lnk_struct;

typedef struct {
    logic [P_LANES-1:0]             vid_str;
    logic [1:0]                     lph[0:P_LANES-1];
    logic [1:0]                     fph[0:P_LANES-1];
    logic [1:0]                     sel[0:P_LANES-1];
    logic [P_SPL-1:0]               eol[0:P_LANES-1];
    logic [P_SPL-1:0]               vid[0:P_LANES-1];
    logic [7:0]                     dat[0:P_LANES-1][0:P_SPL-1];
} aln_struct;

typedef struct {
    logic   [P_LANES-1:0]           rst;
    logic   [P_FIFO_STRIPES-1:0]    wr_en[0:P_LANES-1];
    logic	[P_FIFO_STRIPES-1:0]	wr[0:P_LANES-1];  
    logic   [P_FIFO_DAT-1:0]        din[0:P_LANES-1][0:P_FIFO_STRIPES-1];
    logic	[P_FIFO_STRIPES-1:0]   	rd[0:P_LANES-1];
    logic	[P_FIFO_DAT-1:0]        dout[0:P_LANES-1][0:P_FIFO_STRIPES-1];
    logic	[P_FIFO_STRIPES-1:0]	de[0:P_LANES-1];
    logic                           de_all;
    logic   [P_FIFO_ADR:0]          wrds[0:P_LANES-1][0:P_FIFO_STRIPES-1];
    logic   [P_FIFO_STRIPES-1:0]    fl[0:P_LANES-1];
    logic   [P_FIFO_STRIPES-1:0]    ep[0:P_LANES-1];
    logic                           ep_all;
    logic   [1:0]                   head_byte[0:P_LANES-1];
    logic   [7:0]                   head[0:P_LANES-1];
    logic   [7:0]                   head_tmp[0:1];
    logic   [7:0]                   head_low;
    logic   [7:0]                   tail;
    logic   [7:0]                   delta;
    logic                           rdy;
    logic   [7:0]                   rd_cnt;
    logic                           rd_cnt_end;
    logic   [1:0]                   rd_seq;
} fifo_struct;

typedef struct {
    logic   [2:0]                   seq;      // Sequence
	logic 	[2:0]					sel[0:(P_PPC*3)-1];
    logic 	[P_FIFO_DAT-1:0]        din[0:(P_PPC*3)-1][0:P_MAP_CH-1];
    logic 	[P_FIFO_DAT-1:0]        dout[0:(P_PPC*3)-1];
} map_struct;

typedef struct {
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
lnk_struct          clk_lnk;
aln_struct          clk_aln;
fifo_struct         clk_fifo;
map_struct          clk_map;
vid_struct          clk_vid;

genvar i, j;

// Logic

// Config
    always_ff @ (posedge CLK_IN)
    begin
        clk_lnk.lanes <= CTL_LANES_IN;
    end

// Link input
    always_comb
    begin
        // Only capture lane 0
        clk_lnk.vbid = LNK_SNK_IF.vbid[0];

        for (int i = 0; i < P_LANES; i++)
        begin
            clk_lnk.sol[i]  = LNK_SNK_IF.sol[i];

            // For the end of line we are only interested in the last (active) lane

            // Four active lanes
            if (clk_lnk.lanes && (i == 3))
                clk_lnk.eol[i]  = LNK_SNK_IF.eol[i];

            // Two active lanes
            else if (!clk_lnk.lanes && (i == 1))
                clk_lnk.eol[i]  = LNK_SNK_IF.eol[i];
            
            else
                clk_lnk.eol[i] = 0;

            clk_lnk.vid[i]  = LNK_SNK_IF.vid[i];
            clk_lnk.k[i]    = LNK_SNK_IF.k[i];
            clk_lnk.dat[i]  = LNK_SNK_IF.dat[i];
        end
    end

// Registered data
// This is needed for the alignment latency 
    always_ff @ (posedge CLK_IN)
    begin
        for (int i = 0; i < P_LANES; i++)
        begin
            clk_lnk.vid_reg[i] <= clk_lnk.vid[i];
            clk_lnk.dat_reg[i] <= clk_lnk.dat[i];
            clk_lnk.eol_reg[i] <= clk_lnk.eol[i];
        end

        // Only lane 0
        clk_lnk.vbid_reg <= clk_lnk.vbid;
    end

// Delayed data 
// This is needed for the lane data inversion
    always_ff @ (posedge CLK_IN)
    begin
        for (int i = 0; i < P_LANES; i++)
        begin
            for (int j = 0; j < P_SPL; j++)
                clk_lnk.dat_reg_del[i][j] <= clk_lnk.dat_reg[i][j]; 
            clk_lnk.vid_reg_del[i] <= clk_lnk.vid_reg[i];
            clk_lnk.eol_reg_del[i] <= clk_lnk.eol_reg[i];
        end
    end

// Link lock
    always_ff @ (posedge RST_IN, posedge CLK_IN)
    begin
        // Reset
        if (RST_IN)
            clk_lnk.lock <= 0;

        else
            clk_lnk.lock <= LNK_SNK_IF.lock;
    end

// VB-ID register
// This will capture the NoVideoStream_flag and vertical blanking flag.
// Only lane 0 is used
    always_ff @ (posedge CLK_IN)
    begin
        // Lock
        if (clk_lnk.lock)
        begin
            // Four symbols per lane
            if (P_SPL == 4)
            begin
                // Sublane 0
                if (clk_lnk.vbid_reg[0])
                begin
                    clk_vid.nvs <= clk_lnk.dat_reg[0][0][3];
                    clk_vid.vbf <= clk_lnk.dat_reg[0][0][0];
                end

                // Sublane 1
                else if (clk_lnk.vbid_reg[1])
                begin
                    clk_vid.nvs <= clk_lnk.dat_reg[0][1][3];
                    clk_vid.vbf <= clk_lnk.dat_reg[0][1][0];
                end

                // Sublane 2
                else if (clk_lnk.vbid_reg[2])
                begin
                    clk_vid.nvs <= clk_lnk.dat_reg[0][2][3];
                    clk_vid.vbf <= clk_lnk.dat_reg[0][2][0];
                end

                // Sublane 3
                else if (clk_lnk.vbid_reg[3])
                begin
                    clk_vid.nvs <= clk_lnk.dat_reg[0][3][3];
                    clk_vid.vbf <= clk_lnk.dat_reg[0][3][0];
                end
            end

            // Two symbols per lane
            else
            begin
                // Sublane 0
                if (clk_lnk.vbid_reg[0])
                begin
                    clk_vid.nvs <= clk_lnk.dat_reg[0][0][3];
                    clk_vid.vbf <= clk_lnk.dat_reg[0][0][0];
                end

                // Sublane 1
                else if (clk_lnk.vbid_reg[1])
                begin
                    clk_vid.nvs <= clk_lnk.dat_reg[0][1][3];
                    clk_vid.vbf <= clk_lnk.dat_reg[0][1][0];
                end
            end    
        end

        // No lock
        else
        begin
            clk_vid.nvs <= 1;
            clk_vid.vbf <= 0;
        end
    end

// Vertical blanking flag detector
    prt_dp_lib_edge
    VBF_EDGE_INST
    (
        .CLK_IN    (CLK_IN),            // Clock
        .CKE_IN    (1'b1),              // Clock enable
        .A_IN      (clk_vid.vbf),       // Input
        .RE_OUT    (clk_vid.vbf_re),    // Rising edge
        .FE_OUT    ()                   // Falling edge
    );

// Vertical blanking flag sticky
// A source device may clear this flag immediately after the first active line or prior the first active line.
// The vbf flag is used to generate the sof signal.
// This flag remains asserted till the sof signal has been generated.
// See VB-ID definition on page 50 of the DisplayPort 1.2 spec.
    always_ff @ (posedge CLK_IN)
    begin
        // Lock
        if (clk_lnk.lock)
        begin
            // Clear
            if (clk_vid.sof)
                clk_vid.vbf_sticky <= 0;

            // Set 
            else if (clk_vid.vbf_re)
                clk_vid.vbf_sticky <= 1;
        end

        else
            clk_vid.vbf_sticky <= 0;
    end

/*
    Aligment
    The alignment will steer the data input, 
    so that even data will be written into the first and third FIFO stripe
    and the odd data goes into the second and fourth FIFO stripe. 
*/

// Last phase
// This register captures the phase of the last data
generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_lph_4spl
        always_ff @ (posedge CLK_IN)
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                // Clear at start of line
                if (|clk_lnk.sol[i])
                    clk_aln.lph[i] <= 0;

                // Phase 0
                else if (clk_aln.vid[i] == 'b1111)
                    clk_aln.lph[i] <= 'd0;

                // Phase 1
                else if (clk_aln.vid[i] == 'b0001)
                    clk_aln.lph[i] <= 'd1;    

                // Phase 2
                else if (clk_aln.vid[i] == 'b0011)
                    clk_aln.lph[i] <= 'd2;    

                // Phase 3
                else if (clk_aln.vid[i] == 'b0111)
                    clk_aln.lph[i] <= 'd3;    
            end
        end
    end

    // Two symbols per lane
    else
    begin : gen_lph_2spl
        always_ff @ (posedge CLK_IN)
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                // Clear at start of line
                if (|clk_lnk.sol[i])
                    clk_aln.lph[i] <= 0;

                // Phase 0
                else if (clk_aln.vid[i] == 'b11)
                    clk_aln.lph[i] <= 'd0;

                // Phase 1
                else if (clk_aln.vid[i] == 'b01)
                    clk_aln.lph[i] <= 'd1;    
            end
        end
    end
endgenerate

// First phase
// This process indicates the first phase of the incoming data
// Must be combinatorial
generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_fph_4spl
        always_comb
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                // Phase 1
                if (clk_lnk.vid[i] == 'b1110)
                    clk_aln.fph[i] = 'd1;

                // Phase 2
                else if (clk_lnk.vid[i] == 'b1100)
                    clk_aln.fph[i] = 'd2;

                // Phase 3
                else if (clk_lnk.vid[i] == 'b1000)
                    clk_aln.fph[i] = 'd3;
                
                // Phase 0
                else
                    clk_aln.fph[i] = 'd0;
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
                if (clk_lnk.vid[i] == 'b10)
                    clk_aln.fph[i] = 'd1;
                else
                    clk_aln.fph[i] = 'd0;
            end
        end        
    end
endgenerate

// Start data
generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_aln_vid
        prt_dp_lib_edge
        ALN_VID_EDGE_INST
        (
            .CLK_IN    (CLK_IN),                // Clock
            .CKE_IN    (1'b1),                  // Clock enable
            .A_IN      (|clk_lnk.vid[i]),       // Input
            .RE_OUT    (clk_aln.vid_str[i]),    // Rising edge
            .FE_OUT    ()                       // Falling edge
        );
    end
endgenerate

// Select
// This process drives the data mux.
// Select 0 - Lane data normal
// Select 1 - Lane data inverted
generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_aln_sel_4spl
        always_ff @ (posedge CLK_IN)
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                // Clear at start of line
                if (|clk_lnk.sol[i])
                    clk_aln.sel[i] <= 0;

                else
                begin
                    // Set at start of video data
                    if (clk_aln.vid_str[i])    
                    begin
                        case ({clk_aln.lph[i], clk_aln.fph[i]})
                            {2'd0, 2'd0} : clk_aln.sel[i] <= 'd0;    
                            {2'd0, 2'd1} : clk_aln.sel[i] <= 'd1;    
                            {2'd0, 2'd2} : clk_aln.sel[i] <= 'd2;    
                            {2'd0, 2'd3} : clk_aln.sel[i] <= 'd3;    

                            {2'd1, 2'd0} : clk_aln.sel[i] <= 'd3;    
                            {2'd1, 2'd1} : clk_aln.sel[i] <= 'd0;    
                            {2'd1, 2'd2} : clk_aln.sel[i] <= 'd1;    
                            {2'd1, 2'd3} : clk_aln.sel[i] <= 'd2;    

                            {2'd2, 2'd0} : clk_aln.sel[i] <= 'd2;    
                            {2'd2, 2'd1} : clk_aln.sel[i] <= 'd3;    
                            {2'd2, 2'd2} : clk_aln.sel[i] <= 'd0;    
                            {2'd2, 2'd3} : clk_aln.sel[i] <= 'd1;    

                            {2'd3, 2'd0} : clk_aln.sel[i] <= 'd1;    
                            {2'd3, 2'd1} : clk_aln.sel[i] <= 'd2;    
                            {2'd3, 2'd2} : clk_aln.sel[i] <= 'd3;    
                            {2'd3, 2'd3} : clk_aln.sel[i] <= 'd0;    
                                                    
                            default      : clk_aln.sel[i] <= 'd0;
                        endcase
                    end
                end
            end
        end
    end

    // Two symbols per lane
    else
    begin : gen_aln_sel_2spl
        always_ff @ (posedge CLK_IN)
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                // Clear at start of line
                if (|clk_lnk.sol[i])
                    clk_aln.sel[i] <= 0;

                else
                begin
                    // Set at start of video data
                    if (clk_aln.vid_str[i])    
                    begin
                        case ({clk_aln.lph[i], clk_aln.fph[i]})
                            {2'd0, 2'd0} : clk_aln.sel[i] <= 'd0;    
                            {2'd0, 2'd1} : clk_aln.sel[i] <= 'd1;    
                        
                            {2'd1, 2'd0} : clk_aln.sel[i] <= 'd1;    
                            {2'd1, 2'd1} : clk_aln.sel[i] <= 'd0;    
                        
                            default      : clk_aln.sel[i] <= 'd0;
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
        always_comb
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                // Phase 1
                if (clk_aln.sel[i] == 'd1)
                begin
                    clk_aln.dat[i][0] = clk_lnk.dat_reg_del[i][1];
                    clk_aln.dat[i][1] = clk_lnk.dat_reg_del[i][2];
                    clk_aln.dat[i][2] = clk_lnk.dat_reg_del[i][3];
                    clk_aln.dat[i][3] = clk_lnk.dat_reg[i][0];

                    clk_aln.vid[i][0] = clk_lnk.vid_reg_del[i][1];
                    clk_aln.vid[i][1] = clk_lnk.vid_reg_del[i][2];
                    clk_aln.vid[i][2] = clk_lnk.vid_reg_del[i][3];
                    clk_aln.vid[i][3] = clk_lnk.vid_reg[i][0];

                    clk_aln.eol[i][0] = clk_lnk.eol_reg_del[i][1];
                    clk_aln.eol[i][1] = clk_lnk.eol_reg_del[i][2];
                    clk_aln.eol[i][2] = clk_lnk.eol_reg_del[i][3];
                    clk_aln.eol[i][3] = clk_lnk.eol_reg[i][0];
                end

                // Phase 2
                else if (clk_aln.sel[i] == 'd2)
                begin
                    clk_aln.dat[i][0] = clk_lnk.dat_reg_del[i][2];
                    clk_aln.dat[i][1] = clk_lnk.dat_reg_del[i][3];
                    clk_aln.dat[i][2] = clk_lnk.dat_reg[i][0];
                    clk_aln.dat[i][3] = clk_lnk.dat_reg[i][1];

                    clk_aln.vid[i][0] = clk_lnk.vid_reg_del[i][2];
                    clk_aln.vid[i][1] = clk_lnk.vid_reg_del[i][3];
                    clk_aln.vid[i][2] = clk_lnk.vid_reg[i][0];
                    clk_aln.vid[i][3] = clk_lnk.vid_reg[i][1];

                    clk_aln.eol[i][0] = clk_lnk.eol_reg_del[i][2];
                    clk_aln.eol[i][1] = clk_lnk.eol_reg_del[i][3];
                    clk_aln.eol[i][2] = clk_lnk.eol_reg[i][0];
                    clk_aln.eol[i][3] = clk_lnk.eol_reg[i][1];
                end

                // Phase 3
                else if (clk_aln.sel[i] == 'd3)
                begin
                    clk_aln.dat[i][0] = clk_lnk.dat_reg_del[i][3];
                    clk_aln.dat[i][1] = clk_lnk.dat_reg[i][0];
                    clk_aln.dat[i][2] = clk_lnk.dat_reg[i][1];
                    clk_aln.dat[i][3] = clk_lnk.dat_reg[i][2];

                    clk_aln.vid[i][0] = clk_lnk.vid_reg_del[i][3];
                    clk_aln.vid[i][1] = clk_lnk.vid_reg[i][0];
                    clk_aln.vid[i][2] = clk_lnk.vid_reg[i][1];
                    clk_aln.vid[i][3] = clk_lnk.vid_reg[i][2];

                    clk_aln.eol[i][0] = clk_lnk.eol_reg_del[i][3];
                    clk_aln.eol[i][1] = clk_lnk.eol_reg[i][0];
                    clk_aln.eol[i][2] = clk_lnk.eol_reg[i][1];
                    clk_aln.eol[i][3] = clk_lnk.eol_reg[i][2];
                end

                // Normal
                else
                begin
                    clk_aln.dat[i][0] = clk_lnk.dat_reg[i][0];
                    clk_aln.dat[i][1] = clk_lnk.dat_reg[i][1];
                    clk_aln.dat[i][2] = clk_lnk.dat_reg[i][2];
                    clk_aln.dat[i][3] = clk_lnk.dat_reg[i][3];
                    
                    clk_aln.vid[i][0] = clk_lnk.vid_reg[i][0];
                    clk_aln.vid[i][1] = clk_lnk.vid_reg[i][1];
                    clk_aln.vid[i][2] = clk_lnk.vid_reg[i][2];
                    clk_aln.vid[i][3] = clk_lnk.vid_reg[i][3];
                    
                    clk_aln.eol[i][0] = clk_lnk.eol_reg[i][0];
                    clk_aln.eol[i][1] = clk_lnk.eol_reg[i][1];
                    clk_aln.eol[i][2] = clk_lnk.eol_reg[i][2];
                    clk_aln.eol[i][3] = clk_lnk.eol_reg[i][3];
                end
            end
        end
    end

    // Two symbols per lane
    else
    begin : gen_aln_dat_2spl
        always_comb
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                // Inverted
                if (clk_aln.sel[i] == 'd1)
                begin
                    clk_aln.dat[i][0] = clk_lnk.dat_reg_del[i][1];
                    clk_aln.dat[i][1] = clk_lnk.dat_reg[i][0];
                    clk_aln.vid[i][0] = clk_lnk.vid_reg_del[i][1];
                    clk_aln.vid[i][1] = clk_lnk.vid_reg[i][0];
                    clk_aln.eol[i][0] = clk_lnk.eol_reg_del[i][1];
                    clk_aln.eol[i][1] = clk_lnk.eol_reg[i][0];
                end

                // Normal
                else
                begin
                    clk_aln.dat[i][0] = clk_lnk.dat_reg[i][0];
                    clk_aln.dat[i][1] = clk_lnk.dat_reg[i][1];
                    clk_aln.vid[i][0] = clk_lnk.vid_reg[i][0];
                    clk_aln.vid[i][1] = clk_lnk.vid_reg[i][1];
                    clk_aln.eol[i][0] = clk_lnk.eol_reg[i][0];
                    clk_aln.eol[i][1] = clk_lnk.eol_reg[i][1];
                end
            end
        end
    end
endgenerate

/*
    FIFO
*/
// FIFO reset
generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_fifo_rst
        assign clk_fifo.rst[i] = (~clk_lnk.lock || (|clk_lnk.sol[i]) ) ? 1 : 0;
    end
endgenerate

// Write enable
// In two symbols per lane the link data is written in the FIFO interleaved.
// The write enable logic selects the fifo stripe.
// This is not needed in four symbols per lane
generate
    if (P_SPL == 2)
    begin : gen_fifo_wr_en_2spl
        always_ff @ (posedge CLK_IN)
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                // Lock
                if (clk_lnk.lock)
                begin
                    // Set
                    if (|clk_lnk.sol[i])
                        clk_fifo.wr_en[i] <= 'b0011;

                    else
                    begin
                        // Even data
                        if (clk_aln.vid[i][0])
                        begin
                            clk_fifo.wr_en[i][0] <= clk_fifo.wr_en[i][2];
                            clk_fifo.wr_en[i][2] <= clk_fifo.wr_en[i][0];
                        end

                        // Odd data
                        if (clk_aln.vid[i][1])
                        begin
                            clk_fifo.wr_en[i][1] <= clk_fifo.wr_en[i][3];
                            clk_fifo.wr_en[i][3] <= clk_fifo.wr_en[i][1];
                        end
                    end
                end

                else
                    clk_fifo.wr_en[i] <= 0;
            end
        end
    end
endgenerate

// FIFO
// The incoming video data is stored in a stripe (FIFO). 
generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_fifo       
        for (j = 0; j < P_FIFO_STRIPES; j++)
        begin

            if (P_SPL == 4)
            begin : gen_fifo_wr_4spl
                // Data
                assign clk_fifo.din[i][j] = {clk_aln.eol[i][j], clk_aln.dat[i][j]};
                
                // Write
                assign clk_fifo.wr[i][j] = clk_aln.vid[i][j];
            end

            // Two symbols per lane
            else
            begin : gen_fifo_wr_2spl
                // Write data
                if (j < P_SPL)
                    assign clk_fifo.din[i][j] = {clk_aln.eol[i][j], clk_aln.dat[i][j]};
                else
                    assign clk_fifo.din[i][j] = {clk_aln.eol[i][j-2], clk_aln.dat[i][j-2]};

                // Write
                if (j < P_SPL)
                	assign clk_fifo.wr[i][j] = (clk_fifo.wr_en[i][j]) ? clk_aln.vid[i][j] : 0;

                else
    				assign clk_fifo.wr[i][j] = (clk_fifo.wr_en[i][j]) ? clk_aln.vid[i][j-2] : 0;
            end

            // FIFO
            prt_dp_lib_fifo_sc
            #(
            	.P_MODE         ("burst"),		       // "single" or "burst"
            	.P_RAM_STYLE	("distributed"),	   // "distributed" or "block"
            	.P_ADR_WIDTH	(P_FIFO_ADR),
            	.P_DAT_WIDTH	(P_FIFO_DAT)
            )
            FIFO_INST
            (
                .RST_IN         (RST_IN),                   // Reset
                .CLK_IN         (CLK_IN),                   // Clock
                .CLR_IN         (clk_fifo.rst[i]),          // Clear

                // Write port 
            	.WR_IN          (clk_fifo.wr[i][j]),	    // Write
            	.DAT_IN         (clk_fifo.din[i][j]),		// Write data

            	// Read port 
                .RD_EN_IN       (VID_SRC_IF.rdy),           // Clock enable
            	.RD_IN          (clk_fifo.rd[i][j]),        // Read
            	.DAT_OUT        (clk_fifo.dout[i][j]),	    // Read data
            	.DE_OUT         (clk_fifo.de[i][j]),		// Data enable 

            	// Status 
            	.WRDS_OUT       (clk_fifo.wrds[i][j]),		// Used words
            	.FL_OUT         (clk_fifo.fl[i][j]),	    // Full
            	.EP_OUT         (clk_fifo.ep[i][j])		    // Empty
            );
        end
    end
endgenerate

// Head
// This process counts the number of blocks (12 bytes) in the fifo.
// This is used for read logic.
// Only the last stripe of each fifo is used.
// As there might be skew between the lanes, there is one head counter for each lane.
generate
    for (i = 0; i < P_LANES; i++)
    begin
        always_ff @ (posedge RST_IN, posedge CLK_IN)
        begin
            // Reset
            if (RST_IN)
            begin
                clk_fifo.head_byte[i] <= 0;
                clk_fifo.head[i] <= 0;
            end

            else
            begin
                // Clear
                if (|clk_lnk.sol[i])
                begin
                    clk_fifo.head_byte[i] <= 0;
                    clk_fifo.head[i] <= 0;
                end

                // Increment
                else if (clk_fifo.wr[i][P_FIFO_STRIPES-1])
                begin
                    // One block consists of three writes
                    if (clk_fifo.head_byte[i] == 'd2)
                    begin
                        clk_fifo.head[i] <= clk_fifo.head[i] + 'd1;
                        clk_fifo.head_byte[i] <= 0;
                    end

                    else
                        clk_fifo.head_byte[i] <= clk_fifo.head_byte[i] + 'd1;
                end
            end
        end
    end
endgenerate

// Head low
// Due to the skew some lanes might lead or lag.
// To prevent underruning of the FIFO we have to find the lowest head.
    always_ff @ (posedge CLK_IN)
    begin
        // To improve performance this process is split into two levels
        // Lanes 0 and 1
        if (clk_fifo.head[0] < clk_fifo.head[1])
            clk_fifo.head_tmp[0] <= clk_fifo.head[0];
        else
            clk_fifo.head_tmp[0] <= clk_fifo.head[1];

        // Lanes 2 and 3
        if (clk_fifo.head[2] < clk_fifo.head[3])
            clk_fifo.head_tmp[1] <= clk_fifo.head[2];
        else
            clk_fifo.head_tmp[1] <= clk_fifo.head[3];

        // Final result
        if (clk_fifo.head_tmp[0] < clk_fifo.head_tmp[1])
            clk_fifo.head_low <= clk_fifo.head_tmp[0];
        else
            clk_fifo.head_low <= clk_fifo.head_tmp[1];
    end

// Tail
// This process keeps track of the read bytes from the fifo.
// As the reading is synchronous only the first fifo is counted.
    always_ff @ (posedge RST_IN, posedge CLK_IN)
    begin
        // Reset
        if (RST_IN)
            clk_fifo.tail <= 0;

        else
        begin
            // Clear
            if (|clk_lnk.sol[0])
                clk_fifo.tail <= 0;

            // Increment
            else if (clk_fifo.rdy && clk_fifo.rd_cnt_end)
                clk_fifo.tail <= clk_fifo.tail + clk_fifo.delta;
        end
    end

// Delta
    assign clk_fifo.delta = clk_fifo.head_low - clk_fifo.tail;

// FIFO ready
// This flag is asserted when at least one block of 12 bytes is stored in the fifo
    always_ff @ (posedge CLK_IN)
    begin
        if ((clk_fifo.delta > 0) && !clk_fifo.ep_all)
            clk_fifo.rdy <= 1;
        else
            clk_fifo.rdy <= 0;
    end

// Empty all
// This process combines the empty of all fifos.
    always_comb
    begin
        // Default
        clk_fifo.ep_all = 0;

        // Four lanes
        if (clk_lnk.lanes)
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                for (int j = 0; j < P_SPL * 2; j++)
                begin
                   if (clk_fifo.ep[i][j])
                    clk_fifo.ep_all = 1;
                end
            end
        end

        else
        begin
            for (int i = 0; i < 2; i++)
            begin
                for (int j = 0; j < P_SPL * 2; j++)
                begin
                   if (clk_fifo.ep[i][j])
                    clk_fifo.ep_all = 1;
                end
            end
        end    
    end

// Data enable all
// This process combines the data enable of all fifos.
    always_comb
    begin
        // Default
        clk_fifo.de_all = 0;

        // Four lanes
        if (clk_lnk.lanes)
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                for (int j = 0; j < P_SPL * 2; j++)
                begin
                   if (clk_fifo.de[i][j])
                    clk_fifo.de_all = 1;
                end
            end
        end

        else
        begin
            for (int i = 0; i < 2; i++)
            begin
                for (int j = 0; j < P_SPL * 2; j++)
                begin
                   if (clk_fifo.de[i][j])
                    clk_fifo.de_all = 1;
                end
            end
        end    
    end

// Read counter
    always_ff @ (posedge CLK_IN)
    begin
        // Lock
        if (clk_lnk.lock)
        begin
            // The counter is cleared on every start of a new line (lane 0)
            if (|clk_lnk.sol[0])
                clk_fifo.rd_cnt <= 0;
            
            else
            begin
                // Load
                if (clk_fifo.rdy && clk_fifo.rd_cnt_end)
                begin
                    if (P_PPC == 4)
                        clk_fifo.rd_cnt <= {clk_fifo.delta[0+:$left(clk_fifo.rd_cnt)], 2'b00}; // One block is four reads
                    else
                        clk_fifo.rd_cnt <= clk_fifo.delta[3+:$left(clk_fifo.rd_cnt)]; // Should be multiple of eight            
                end

                // Decrement
                else if (!clk_fifo.rd_cnt_end)
                begin
                    // Four lanes
                    if (clk_lnk.lanes)
                        clk_fifo.rd_cnt <= clk_fifo.rd_cnt - 'd1;
                    
                    // Two lanes
                    else
                        clk_fifo.rd_cnt <= clk_fifo.rd_cnt - 'd2;
                end
            end
        end

        // Idle
        else
            clk_fifo.rd_cnt <= 0;
    end

// Read counter end
    always_comb
    begin
        if (clk_fifo.rd_cnt == 0)
            clk_fifo.rd_cnt_end = 1;
        else
            clk_fifo.rd_cnt_end = 0;
    end

// Read sequence
    always_ff @ (posedge CLK_IN)
    begin
        // Lock
        if (clk_lnk.lock)
        begin
            // Clear
            if (|clk_lnk.sol[0])
                clk_fifo.rd_seq <= 0;
            
            // Increment
            else if (|clk_fifo.rd[0])
            begin
                if (clk_fifo.rd_seq == 'd3)
                    clk_fifo.rd_seq <= 0;
                else
                    clk_fifo.rd_seq <= clk_fifo.rd_seq + 'd1;
            end
        end

        else
            clk_fifo.rd_seq <= 0;
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
                clk_fifo.rd[i] = 0;

            if (!clk_fifo.rd_cnt_end)
            begin
                case (clk_fifo.rd_seq)

                    'd0 : 
                    begin
                        clk_fifo.rd[0][0] = 1;  // R0
                        clk_fifo.rd[0][1] = 1;  // G0
                        clk_fifo.rd[0][2] = 1;  // B0
                        clk_fifo.rd[1][0] = 1;  // R1
                        clk_fifo.rd[1][1] = 1;  // G1
                        clk_fifo.rd[1][2] = 1;  // B1
                        clk_fifo.rd[2][0] = 1;  // R2
                        clk_fifo.rd[2][1] = 1;  // G2
                        clk_fifo.rd[2][2] = 1;  // B2
                        clk_fifo.rd[3][0] = 1;  // R3
                        clk_fifo.rd[3][1] = 1;  // G3
                        clk_fifo.rd[3][2] = 1;  // B3
                    end             

                    'd1 : 
                    begin
                        clk_fifo.rd[0][3] = 1;  // R4
                        clk_fifo.rd[0][0] = 1;  // G4
                        clk_fifo.rd[0][1] = 1;  // B4
                        clk_fifo.rd[1][3] = 1;  // R5
                        clk_fifo.rd[1][0] = 1;  // G5
                        clk_fifo.rd[1][1] = 1;  // B5
                        clk_fifo.rd[2][3] = 1;  // R6
                        clk_fifo.rd[2][0] = 1;  // G6
                        clk_fifo.rd[2][1] = 1;  // B6
                        clk_fifo.rd[3][3] = 1;  // R7
                        clk_fifo.rd[3][0] = 1;  // G7
                        clk_fifo.rd[3][1] = 1;  // B7
                    end             

                    'd2 : 
                    begin
                        clk_fifo.rd[0][2] = 1;  // R8
                        clk_fifo.rd[0][3] = 1;  // G8
                        clk_fifo.rd[0][0] = 1;  // B8
                        clk_fifo.rd[1][2] = 1;  // R9
                        clk_fifo.rd[1][3] = 1;  // G9
                        clk_fifo.rd[1][0] = 1;  // B9
                        clk_fifo.rd[2][2] = 1;  // R10
                        clk_fifo.rd[2][3] = 1;  // G10
                        clk_fifo.rd[2][0] = 1;  // B10
                        clk_fifo.rd[3][2] = 1;  // R11
                        clk_fifo.rd[3][3] = 1;  // G11
                        clk_fifo.rd[3][0] = 1;  // B11
                    end             

                    'd3 : 
                    begin
                        clk_fifo.rd[0][1] = 1;  // R12
                        clk_fifo.rd[0][2] = 1;  // G12
                        clk_fifo.rd[0][3] = 1;  // B12
                        clk_fifo.rd[1][1] = 1;  // R13
                        clk_fifo.rd[1][2] = 1;  // G13
                        clk_fifo.rd[1][3] = 1;  // B13
                        clk_fifo.rd[2][1] = 1;  // R14
                        clk_fifo.rd[2][2] = 1;  // G14
                        clk_fifo.rd[2][3] = 1;  // B14
                        clk_fifo.rd[3][1] = 1;  // R15
                        clk_fifo.rd[3][2] = 1;  // G15
                        clk_fifo.rd[3][3] = 1;  // B15
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
                clk_fifo.rd[i] = 0;

            if (!clk_fifo.rd_cnt_end)
            begin
           		case (clk_fifo.rd_seq)
                    'd0 :
                    begin
                        clk_fifo.rd[0][0] = 1;  // R0
                        clk_fifo.rd[0][1] = 1;  // G0
                        clk_fifo.rd[0][2] = 1;  // B0
                        clk_fifo.rd[1][0] = 1;  // R1
                        clk_fifo.rd[1][1] = 1;  // G1
                        clk_fifo.rd[1][2] = 1;  // R1
                    end             
                			
        			'd1 : 
        			begin
        				clk_fifo.rd[2][0] = 1;	// R2
        				clk_fifo.rd[2][1] = 1;	// G2
        				clk_fifo.rd[2][2] = 1;	// B2
        				clk_fifo.rd[3][0] = 1;	// R3
        				clk_fifo.rd[3][1] = 1;	// G3
        				clk_fifo.rd[3][2] = 1;	// R3
        			end				

        			'd2 : 
        			begin
        				clk_fifo.rd[0][3] = 1;	// R4
        				clk_fifo.rd[0][0] = 1;	// G4
        				clk_fifo.rd[0][1] = 1;	// B4
        				clk_fifo.rd[1][3] = 1;	// R5
        				clk_fifo.rd[1][0] = 1;	// G5
        				clk_fifo.rd[1][1] = 1;	// R5
        			end				

        			'd3 : 
        			begin
        				clk_fifo.rd[2][3] = 1;	// R6
        				clk_fifo.rd[2][0] = 1;	// G6
        				clk_fifo.rd[2][1] = 1;	// B6
        				clk_fifo.rd[3][3] = 1;	// R7
        				clk_fifo.rd[3][0] = 1;	// G7
        				clk_fifo.rd[3][1] = 1;	// R7
        			end				

        			'd4 : 
        			begin
        				clk_fifo.rd[0][2] = 1;	// R8
        				clk_fifo.rd[0][3] = 1;	// G8
        				clk_fifo.rd[0][0] = 1;	// B8
        				clk_fifo.rd[1][2] = 1;	// R9
        				clk_fifo.rd[1][3] = 1;	// G9
        				clk_fifo.rd[1][0] = 1;	// R9
        			end				

        			'd5 : 
        			begin
        				clk_fifo.rd[2][2] = 1;	// R10
        				clk_fifo.rd[2][3] = 1;	// G10
        				clk_fifo.rd[2][0] = 1;	// B10
        				clk_fifo.rd[3][2] = 1;	// R11
        				clk_fifo.rd[3][3] = 1;	// G11
        				clk_fifo.rd[3][0] = 1;	// R11
        			end				

        			'd6 : 
        			begin
        				clk_fifo.rd[0][1] = 1;	// R12
        				clk_fifo.rd[0][2] = 1;	// G12
        				clk_fifo.rd[0][3] = 1;	// B12
        				clk_fifo.rd[1][1] = 1;	// R13
        				clk_fifo.rd[1][2] = 1;	// G13
        				clk_fifo.rd[1][3] = 1;	// R13
        			end				

        			'd7 : 
        			begin
        				clk_fifo.rd[2][1] = 1;	// R14
        				clk_fifo.rd[2][2] = 1;	// G14
        				clk_fifo.rd[2][3] = 1;	// B14
        				clk_fifo.rd[3][1] = 1;	// R15
        				clk_fifo.rd[3][2] = 1;	// G15
        				clk_fifo.rd[3][3] = 1;	// R15
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
            assign clk_map.din[0][j]  = clk_fifo.dout[0][j]; 
            assign clk_map.din[1][j]  = clk_fifo.dout[0][j]; 
            assign clk_map.din[2][j]  = clk_fifo.dout[0][j]; 

            assign clk_map.din[3][j]  = clk_fifo.dout[1][j]; 
            assign clk_map.din[4][j]  = clk_fifo.dout[1][j]; 
            assign clk_map.din[5][j]  = clk_fifo.dout[1][j]; 

            assign clk_map.din[6][j]  = clk_fifo.dout[2][j]; 
            assign clk_map.din[7][j]  = clk_fifo.dout[2][j]; 
            assign clk_map.din[8][j]  = clk_fifo.dout[2][j]; 

            assign clk_map.din[9][j]  = clk_fifo.dout[3][j]; 
            assign clk_map.din[10][j] = clk_fifo.dout[3][j]; 
            assign clk_map.din[11][j] = clk_fifo.dout[3][j];     
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
        				assign clk_map.din[i][j] = clk_fifo.dout[0][j];		// Lane 0
        			else
        				assign clk_map.din[i][j] = clk_fifo.dout[2][j-4];	// Lane 2
        		end
            end

            // Even pixels
        	else
            begin
            	for (j = 0; j < P_SPL * 4; j++)
            	begin
            		if (j < P_SPL * 2)
        				assign clk_map.din[i][j] = clk_fifo.dout[1][j];		// Lane 1
        			else
        				assign clk_map.din[i][j] = clk_fifo.dout[3][j-4];	// Lane 3
        		end
        	end	
        end
    end
endgenerate

// Data out
generate
    for (i = 0; i < (P_PPC * 3); i++)
    begin : gen_map_dout
    	assign clk_map.dout[i] = clk_map.din[i][clk_map.sel[i]];
	end
endgenerate

// Sequence
    always_ff @ (posedge CLK_IN)
    begin
        // Lock
        if (clk_lnk.lock)
        begin
            // The counter is cleared on every start of a new line (lane 0)
            if (|clk_lnk.sol[0])
                clk_map.seq <= 0;

            else
            begin
            	// Enable
            	if (VID_SRC_IF.rdy && clk_fifo.de_all)
            	begin
            		// Overflow
            		if ((P_PPC == 4) && (clk_map.seq == 'd3))
            			clk_map.seq <= 0;

                    // Overflow
                    else if ((P_PPC == 2) && (clk_map.seq == 'd7))
                        clk_map.seq <= 0;

            		// Increment
            		else
                    begin
                        // Four lanes
                        if (clk_lnk.lanes)
            			    clk_map.seq <= clk_map.seq + 'd1;
                        else
                            clk_map.seq <= clk_map.seq + 'd2;
                    end
            	end
            end
        end

        // Idle
        else
            clk_map.seq <= 0;
    end

// Select
generate
    // Four pixels per clock
    if (P_PPC == 4)
    begin : gen_map_sel_4ppc
        
        always_comb
        begin
            case (clk_map.seq)
                
                'd1 : 
                begin
                    clk_map.sel[0]  = 'd0; // Axis G0 = pixel G4 - FIFO lane 0 stripe 0
                    clk_map.sel[3]  = 'd0; // Axis G1 = pixel G5 - FIFO lane 1 stripe 0
                    clk_map.sel[6]  = 'd0; // Axis G2 = pixel G6 - FIFO lane 2 stripe 0
                    clk_map.sel[9]  = 'd0; // Axis G3 = pixel G7 - FIFO lane 3 stripe 0
                    
                    clk_map.sel[1]  = 'd3; // Axis R0 = pixel R4 - FIFO lane 0 stripe 3
                    clk_map.sel[4]  = 'd3; // Axis R1 = pixel R5 - FIFO lane 1 stripe 3
                    clk_map.sel[7]  = 'd3; // Axis R2 = pixel R6 - FIFO lane 2 stripe 3
                    clk_map.sel[10] = 'd3; // Axis R3 = pixel R7 - FIFO lane 3 stripe 3
                    
                    clk_map.sel[2]  = 'd1; // Axis B0 = pixel B4 - FIFO lane 0 stripe 1
                    clk_map.sel[5]  = 'd1; // Axis B1 = pixel B5 - FIFO lane 1 stripe 1
                    clk_map.sel[8]  = 'd1; // Axis B2 = pixel B6 - FIFO lane 2 stripe 1
                    clk_map.sel[11] = 'd1; // Axis B3 = pixel B7 - FIFO lane 3 stripe 1
                end             

                'd2 : 
                begin
                    clk_map.sel[0]  = 'd3; // Axis G0 = pixel G8  - FIFO lane 0 stripe 3
                    clk_map.sel[3]  = 'd3; // Axis G1 = pixel G9  - FIFO lane 1 stripe 3
                    clk_map.sel[6]  = 'd3; // Axis G2 = pixel G10 - FIFO lane 2 stripe 3
                    clk_map.sel[9]  = 'd3; // Axis G3 = pixel G11 - FIFO lane 3 stripe 3
                    
                    clk_map.sel[1]  = 'd2; // Axis R0 = pixel R8  - FIFO lane 0 stripe 2
                    clk_map.sel[4]  = 'd2; // Axis R1 = pixel R9  - FIFO lane 1 stripe 2
                    clk_map.sel[7]  = 'd2; // Axis R2 = pixel R10 - FIFO lane 2 stripe 2
                    clk_map.sel[10] = 'd2; // Axis R3 = pixel R11 - FIFO lane 3 stripe 2
                    
                    clk_map.sel[2]  = 'd0; // Axis B0 = pixel B8  - FIFO lane 0 stripe 0
                    clk_map.sel[5]  = 'd0; // Axis B1 = pixel B9  - FIFO lane 1 stripe 0
                    clk_map.sel[8]  = 'd0; // Axis B2 = pixel B10 - FIFO lane 2 stripe 0
                    clk_map.sel[11] = 'd0; // Axis B3 = pixel B11 - FIFO lane 3 stripe 0
                end             

                'd3 : 
                begin
                    clk_map.sel[0]  = 'd2; // Axis G0 = pixel G12 - FIFO lane 0 stripe 2
                    clk_map.sel[3]  = 'd2; // Axis G1 = pixel G13 - FIFO lane 1 stripe 2
                    clk_map.sel[6]  = 'd2; // Axis G2 = pixel G14 - FIFO lane 2 stripe 2
                    clk_map.sel[9]  = 'd2; // Axis G3 = pixel G15 - FIFO lane 3 stripe 2
                    
                    clk_map.sel[1]  = 'd1; // Axis R0 = pixel R12 - FIFO lane 0 stripe 1
                    clk_map.sel[4]  = 'd1; // Axis R1 = pixel R13 - FIFO lane 1 stripe 1
                    clk_map.sel[7]  = 'd1; // Axis R2 = pixel R14 - FIFO lane 2 stripe 1
                    clk_map.sel[10] = 'd1; // Axis R3 = pixel R15 - FIFO lane 3 stripe 1
                    
                    clk_map.sel[2]  = 'd3; // Axis B0 = pixel B12 - FIFO lane 0 stripe 3
                    clk_map.sel[5]  = 'd3; // Axis B1 = pixel B13 - FIFO lane 1 stripe 3
                    clk_map.sel[8]  = 'd3; // Axis B2 = pixel B14 - FIFO lane 2 stripe 3
                    clk_map.sel[11] = 'd3; // Axis B3 = pixel B15 - FIFO lane 3 stripe 3
                end             

                default : 
                begin
                    clk_map.sel[0]  = 'd1; // Axis G0 = pixel G0 - FIFO lane 0 stripe 1
                    clk_map.sel[3]  = 'd1; // Axis G1 = pixel G1 - FIFO lane 1 stripe 1
                    clk_map.sel[6]  = 'd1; // Axis G2 = pixel G2 - FIFO lane 2 stripe 1
                    clk_map.sel[9]  = 'd1; // Axis G3 = pixel G3 - FIFO lane 3 stripe 1
                    
                    clk_map.sel[1]  = 'd0; // Axis R0 = pixel R0 - FIFO lane 0 stripe 0
                    clk_map.sel[4]  = 'd0; // Axis R1 = pixel R1 - FIFO lane 1 stripe 0
                    clk_map.sel[7]  = 'd0; // Axis R2 = pixel R2 - FIFO lane 2 stripe 0
                    clk_map.sel[10] = 'd0; // Axis R3 = pixel R3 - FIFO lane 3 stripe 0
                    
                    clk_map.sel[2]  = 'd2; // Axis B0 = pixel B0 - FIFO lane 0 stripe 2
                    clk_map.sel[5]  = 'd2; // Axis B1 = pixel B1 - FIFO lane 1 stripe 2
                    clk_map.sel[8]  = 'd2; // Axis B2 = pixel B2 - FIFO lane 2 stripe 2
                    clk_map.sel[11] = 'd2; // Axis B3 = pixel B3 - FIFO lane 3 stripe 2
                end             

            endcase
        end
    end

    // Two pixels per clock
    else
    begin : gen_map_sel_2ppc
    	always_comb
    	begin
    		case (clk_map.seq)
    			
    			'd1 : 
    			begin
    				clk_map.sel[0] = 'd5; // Axis G0 = pixel G2 - FIFO lane 2 stripe 1
    				clk_map.sel[1] = 'd4; // Axis R0 = pixel R2 - FIFO lane 2 stripe 0
    				clk_map.sel[2] = 'd6; // Axis B0 = pixel B2 - FIFO lane 2 stripe 2
    				clk_map.sel[3] = 'd5; // Axis G1 = pixel G3 - FIFO lane 3 stripe 1
    				clk_map.sel[4] = 'd4; // Axis R1 = pixel R3 - FIFO lane 3 stripe 0
    				clk_map.sel[5] = 'd6; // Axis B1 = pixel B3 - FIFO lane 3 stripe 2
    			end				

    			'd2 : 
    			begin
    				clk_map.sel[0] = 'd0; // Axis G0 = pixel G4 - FIFO lane 0 stripe 0
    				clk_map.sel[1] = 'd3; // Axis R0 = pixel R4 - FIFO lane 0 stripe 3
    				clk_map.sel[2] = 'd1; // Axis B0 = pixel B4 - FIFO lane 0 stripe 1
    				clk_map.sel[3] = 'd0; // Axis G1 = pixel G5 - FIFO lane 1 stripe 0
    				clk_map.sel[4] = 'd3; // Axis R1 = pixel R5 - FIFO lane 1 stripe 3
    				clk_map.sel[5] = 'd1; // Axis B1 = pixel B5 - FIFO lane 1 stripe 1
    			end				

    			'd3 : 
    			begin
    				clk_map.sel[0] = 'd4; // Axis G0 = pixel G6 - FIFO lane 2 stripe 0
    				clk_map.sel[1] = 'd7; // Axis R0 = pixel R6 - FIFO lane 2 stripe 3
    				clk_map.sel[2] = 'd5; // Axis B0 = pixel B6 - FIFO lane 2 stripe 1
    				clk_map.sel[3] = 'd4; // Axis G1 = pixel G7 - FIFO lane 3 stripe 0
    				clk_map.sel[4] = 'd7; // Axis R1 = pixel R7 - FIFO lane 3 stripe 3
    				clk_map.sel[5] = 'd5; // Axis B1 = pixel B7 - FIFO lane 3 stripe 1
    			end				

    			'd4 : 
    			begin
    				clk_map.sel[0] = 'd3; // Axis G0 = pixel G8 - FIFO lane 0 stripe 3
    				clk_map.sel[1] = 'd2; // Axis R0 = pixel R8 - FIFO lane 0 stripe 2
    				clk_map.sel[2] = 'd0; // Axis B0 = pixel B8 - FIFO lane 0 stripe 0
    				clk_map.sel[3] = 'd3; // Axis G1 = pixel G9 - FIFO lane 1 stripe 3
    				clk_map.sel[4] = 'd2; // Axis R1 = pixel R9 - FIFO lane 1 stripe 2
    				clk_map.sel[5] = 'd0; // Axis B1 = pixel B9 - FIFO lane 1 stripe 0
    			end				

    			'd5 : 
    			begin
    				clk_map.sel[0] = 'd7; // Axis G0 = pixel G10 - FIFO lane 2 stripe 3
    				clk_map.sel[1] = 'd6; // Axis R0 = pixel R10 - FIFO lane 2 stripe 2
    				clk_map.sel[2] = 'd4; // Axis B0 = pixel B10 - FIFO lane 2 stripe 0
    				clk_map.sel[3] = 'd7; // Axis G1 = pixel G11 - FIFO lane 3 stripe 3
    				clk_map.sel[4] = 'd6; // Axis R1 = pixel R11 - FIFO lane 3 stripe 2
    				clk_map.sel[5] = 'd4; // Axis B1 = pixel B11 - FIFO lane 3 stripe 0
    			end				

    			'd6 : 
    			begin
    				clk_map.sel[0] = 'd2; // Axis G0 = pixel G12 - FIFO lane 0 stripe 2
    				clk_map.sel[1] = 'd1; // Axis R0 = pixel R12 - FIFO lane 0 stripe 1
    				clk_map.sel[2] = 'd3; // Axis B0 = pixel B12 - FIFO lane 0 stripe 3
    				clk_map.sel[3] = 'd2; // Axis G1 = pixel G13 - FIFO lane 1 stripe 2
    				clk_map.sel[4] = 'd1; // Axis R1 = pixel R13 - FIFO lane 1 stripe 1
    				clk_map.sel[5] = 'd3; // Axis B1 = pixel B13 - FIFO lane 1 stripe 3
    			end				

    			'd7 : 
    			begin
    				clk_map.sel[0] = 'd6; // Axis G0 = pixel G12 - FIFO lane 2 stripe 2
    				clk_map.sel[1] = 'd5; // Axis R0 = pixel R12 - FIFO lane 2 stripe 1
    				clk_map.sel[2] = 'd7; // Axis B0 = pixel B12 - FIFO lane 2 stripe 3
    				clk_map.sel[3] = 'd6; // Axis G1 = pixel G13 - FIFO lane 3 stripe 2
    				clk_map.sel[4] = 'd5; // Axis R1 = pixel R13 - FIFO lane 3 stripe 1
    				clk_map.sel[5] = 'd7; // Axis B1 = pixel B13 - FIFO lane 3 stripe 3
    			end				

    			default : 
    			begin
    				clk_map.sel[0] = 'd1; // Axis G0 = pixel G0 - FIFO lane 0 stripe 1
    				clk_map.sel[1] = 'd0; // Axis R0 = pixel R0 - FIFO lane 0 stripe 0
    				clk_map.sel[2] = 'd2; // Axis B0 = pixel B0 - FIFO lane 0 stripe 2
    				clk_map.sel[3] = 'd1; // Axis G1 = pixel G1 - FIFO lane 1 stripe 1
    				clk_map.sel[4] = 'd0; // Axis R1 = pixel R1 - FIFO lane 1 stripe 0
    				clk_map.sel[5] = 'd2; // Axis B1 = pixel B1 - FIFO lane 1 stripe 2
    			end				

    		endcase
        end
 	end
endgenerate

/*
    Video
*/

// Video data
    always_ff @ (posedge CLK_IN)
    begin
    	for (int i = 0; i < (P_PPC * 3); i++)
    	begin
	    	// Enable
	    	if (VID_SRC_IF.rdy)
	    		clk_vid.dat[(i*P_BPC)+:P_BPC] <= clk_map.dout[i];
    	end
    end

// Video valid
    always_ff @ (posedge CLK_IN)
    begin
    	// Enable
    	if (VID_SRC_IF.rdy)
    	begin
    		if (clk_fifo.de_all)
    			clk_vid.vld <= 1;
    		else
	            clk_vid.vld <= 0;
    	end
    end

// Start of frame
    always_ff @ (posedge CLK_IN)
    begin
        // Lock
        if (clk_lnk.lock)
        begin
            // Clear
            // When the first video data is transmitted
            if (clk_vid.vld)
                clk_vid.sof <= 0;
        
            // Set
            // When at the start of line when the vertical blanking flag is asserted
            else if (|clk_lnk.sol[0] && clk_vid.vbf_sticky)
                clk_vid.sof <= 1;
        end

        else
            clk_vid.sof <= 0;
    end

// End of line
    always_ff @ (posedge CLK_IN)
    begin
        // Default
        clk_vid.eol <= 0;

        // Lock
        if (clk_lnk.lock)
        begin
            if (clk_fifo.de_all)
            begin
                // Last blue pixel carries the eol flag
                if (clk_map.dout[(P_PPC * 3)-1][8])
                    clk_vid.eol <= 1;
            end
        end
    end

// Outputs
    // Video source
    assign VID_EN_OUT       = ~clk_vid.nvs;       // Enable
    assign VID_SRC_IF.sof   = clk_vid.sof;        // Start of frame
    assign VID_SRC_IF.eol   = clk_vid.eol;        // End of line
    assign VID_SRC_IF.dat   = clk_vid.dat;        // Data
    assign VID_SRC_IF.vld   = clk_vid.vld;        // Valid

endmodule

`default_nettype wire
