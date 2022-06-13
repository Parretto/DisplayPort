/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP TX Main Stream Attribute (msa)
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

module prt_dptx_msa
#(
    // Simulation
    parameter               P_SIM         = 0,      // Simulation

    // Link
    parameter               P_LANES       = 4,      // Lanes
    parameter               P_SPL         = 2,      // Symbols per lane

    // Message
    parameter               P_MSG_IDX     = 5,      // Message index width
    parameter               P_MSG_DAT     = 16,     // Message data width
    parameter               P_MSG_ID_MSA  = 0       // Message ID main stream attributes
)
(
    // Reset and clock
    input wire              LNK_RST_IN,     // Link reset
    input wire              LNK_CLK_IN,     // Link clock
    input wire              VID_CLK_IN,     // Video clock
    input wire              VID_CKE_IN,     // Video clock enable

    // Control
    input wire              CTL_LANES_IN,   // Active lanes (0 - 2 lanes / 1 - 4 lanes)
    input wire              CTL_VID_EN_IN,  // Video enable
    input wire              CTL_EFM_IN,     // Enhanced framing mode

    // Message
    prt_dp_msg_if.snk       MSG_SNK_IF,     // Sink
    prt_dp_msg_if.src       MSG_SRC_IF,     // Source

    // Video
    input wire              LNK_VS_IN,      // Vsync 
    input wire              LNK_VBF_IN,     // Vertical blanking flag
    input wire              LNK_BS_IN,      // Blanking start 

    // Link
    prt_dp_tx_lnk_if.snk    LNK_SNK_IF,     // Sink    
    prt_dp_tx_lnk_if.src    LNK_SRC_IF      // Source
);

// Package
import prt_dp_pkg::*;

// Localparam
localparam P_IDLE_CNT_MAX = 8192 - P_SPL;
localparam P_RAM_WRDS = (P_SPL == 4) ? 8 : 16;
localparam P_RAM_ADR = $clog2(P_RAM_WRDS);
localparam P_RAM_DAT = 9;
localparam P_MVID_CNT = P_SIM ? 255 : 32767;

// Typedef
typedef enum {
    mvid_sm_idle, mvid_sm_clr, mvid_sm_wait, mvid_sm_run, mvid_sm_cap
} mvid_sm_state;

// Structure
typedef struct {
    logic   [P_MSG_IDX-1:0]         idx;
    logic                           first;
    logic                           last;
    logic   [P_MSG_DAT-1:0]         dat;
    logic                           vld;
} msg_struct;

typedef struct {
    logic   [P_RAM_ADR-1:0]         wp;                         // Write pointer
    logic   [(P_LANES*P_SPL)-1:0]   wr;                         // Write
    logic   [P_RAM_DAT-1:0]         din;                        // Write data
    logic   [P_RAM_ADR-1:0]         rp;                         // Read pointer
    logic   [P_RAM_ADR-1:0]         rd_cnt;                     // Read counter
    logic                           rd_cnt_end;                 // Read counter end
    logic                           rd;                         // Read
    logic   [P_RAM_DAT-1:0]         dout[0:P_LANES*P_SPL-1];    // Read data
    logic   [(P_LANES*P_SPL)-1:0]   de;                         // Data enable
} ram_struct;

typedef struct {
    logic                           lanes;
    logic                           efm;
    logic   [12:0]                  idle_cnt;
    logic   [1:0]                   bs_cnt;
    logic                           bs_cnt_ld;
    logic                           bs_cnt_end;
    logic   [7:0]                   vbid;                           // VB-ID
    logic   [P_SPL-1:0]             k[0:P_LANES-1];                 // k character
    logic   [7:0]                   dat[0:P_LANES-1][0:P_SPL-1];    // Data
} lnk_struct;

typedef struct {
    logic                           en;
    logic                           run;
    logic                           vs;
    logic                           vs_re;
    logic                           vbf;
    logic                           bs;
} vid_struct;

typedef struct {
    logic                           clr;
    logic                           run;
    logic [23:0]                    val;
} vid_mvid_struct;

typedef struct {
    mvid_sm_state                   sm_cur;
    mvid_sm_state                   sm_nxt;
    logic                           clr;
    logic                           run;
    logic                           ld;
    logic [23:0]                    cnt;
    logic [23:0]                    cnt_in;
    logic                           cnt_ld;
    logic                           cnt_end;
    logic [23:0]                    vclk_val;
    logic [23:0]                    val;
} lnk_mvid_struct;

// Signals
msg_struct          lclk_msg;
ram_struct          lclk_ram;
lnk_struct          lclk_lnk;
vid_struct          lclk_vid;
vid_mvid_struct     vclk_mvid;
lnk_mvid_struct     lclk_mvid;

genvar i;

// Inputs
    always_ff @ (posedge LNK_CLK_IN)
    begin
        lclk_lnk.lanes  <= CTL_LANES_IN;
        lclk_lnk.efm    <= CTL_EFM_IN;
        lclk_vid.en     <= CTL_VID_EN_IN;
        lclk_vid.vs     <= LNK_VS_IN;
        lclk_vid.vbf    <= LNK_VBF_IN;
        lclk_vid.bs     <= LNK_BS_IN;
    end

// Run
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Clear
        if (!lclk_vid.en)
            lclk_vid.run <= 0;

        // Set at vsync
        else if (lclk_vid.vs_re && lclk_vid.en)
            lclk_vid.run <= 1;
    end

// Vsync rising edge
    prt_dp_lib_edge
    VS_EDGE_INST
    (
        .CLK_IN         (LNK_CLK_IN),      // Clock
        .CKE_IN         (1'b1),            // Clock enable
        .A_IN           (lclk_vid.vs),     // Input
        .RE_OUT         (lclk_vid.vs_re),  // Rising edge
        .FE_OUT         ()                 // Falling edge
    );

// Message Slave
    prt_dp_msg_slv_egr
    #(
        .P_ID           (P_MSG_ID_MSA),   // Identifier
        .P_IDX_WIDTH    (P_MSG_IDX),      // Index width
        .P_DAT_WIDTH    (P_MSG_DAT)       // Data width
    )
    MSG_SLV_EGR_INST
    (
        // Reset and clock
        .RST_IN         (LNK_RST_IN),
        .CLK_IN         (LNK_CLK_IN),

        // MSG sink
        .MSG_SNK_IF     (MSG_SNK_IF),

        // MSG source
        .MSG_SRC_IF     (MSG_SRC_IF),

        // Eggress
        .EGR_IDX_OUT    (lclk_msg.idx),    // Index
        .EGR_FIRST_OUT  (lclk_msg.first),  // First
        .EGR_LAST_OUT   (lclk_msg.last),   // Last
        .EGR_DAT_OUT    (lclk_msg.dat),    // Data
        .EGR_VLD_OUT    (lclk_msg.vld)     // Valid
    );

generate
    for (i = 0; i < (P_LANES * P_SPL); i++)
    begin : gen_ram
        prt_dp_lib_sdp_ram_sc
        #(
            .P_RAM_STYLE    ("distributed"),    // "distributed", "block" or "ultra"
            .P_ADR_WIDTH    (P_RAM_ADR),
            .P_DAT_WIDTH    (P_RAM_DAT)
        )
        RAM_INST
        (
            // Clocks and reset
            .RST_IN     (LNK_RST_IN),           // Reset
            .CLK_IN     (LNK_CLK_IN),           // Clock

            // Port A
            .A_ADR_IN   (lclk_ram.wp),       // Write pointer
            .A_WR_IN    (lclk_ram.wr[i]),    // Write in
            .A_DAT_IN   (lclk_ram.din),      // Write data

            // Port B
            .B_ADR_IN   (lclk_ram.rp),       // Read pointer
            .B_RD_IN    (lclk_ram.rd),       // Read in
            .B_DAT_OUT  (lclk_ram.dout[i]),  // Data out
            .B_VLD_OUT  (lclk_ram.de[i])     // Valid
        );
    end
endgenerate

// Write pointer
    always_ff @ (posedge LNK_RST_IN, posedge LNK_CLK_IN)
    begin
        // Reset
        // The write pointer must be cleared at reset.
        // The enable signal can't be used, because the module might not be enabled yet when the msa data gets written. 
        if (LNK_RST_IN)
            lclk_ram.wp <= 0;

        else
        begin
            // Clear already the write pointer at the last message word for the next msa update
            if (lclk_msg.last)
                lclk_ram.wp <= 0;

            // 4 lanes; Increment when the upper ram have been written
            else if (lclk_lnk.lanes && lclk_ram.wr[$size(lclk_ram.wr)-1])
                lclk_ram.wp <= lclk_ram.wp + 'd1;

            // 2 lanes; Increment when the upper ram have been written
            else if (!lclk_lnk.lanes && lclk_ram.wr[($size(lclk_ram.wr)/2)-1])
                lclk_ram.wp <= lclk_ram.wp + 'd1;
        end
    end

// Write data
// MVid insertion
    always_comb
    begin
        // 4 lanes
        if (lclk_lnk.lanes)
        begin
            case (lclk_msg.idx)
                // Mvid 23:16
                'd8  : lclk_ram.din = lclk_mvid.val[23:16];
                'd9  : lclk_ram.din = lclk_mvid.val[23:16];
                'd10 : lclk_ram.din = lclk_mvid.val[23:16];
                'd11 : lclk_ram.din = lclk_mvid.val[23:16];

                // Mvid 15:8
                'd12 : lclk_ram.din = lclk_mvid.val[15:8];
                'd13 : lclk_ram.din = lclk_mvid.val[15:8];
                'd14 : lclk_ram.din = lclk_mvid.val[15:8];
                'd15 : lclk_ram.din = lclk_mvid.val[15:8];

                // Mvid 7:0
                'd16 : lclk_ram.din = lclk_mvid.val[7:0];
                'd17 : lclk_ram.din = lclk_mvid.val[7:0];
                'd18 : lclk_ram.din = lclk_mvid.val[7:0];
                'd19 : lclk_ram.din = lclk_mvid.val[7:0];

                // Data from policy maker
                default : lclk_ram.din = lclk_msg.dat[P_RAM_DAT-1:0];
            endcase
        end

        // 2 lanes
        else
        begin
            case (lclk_msg.idx)
                // Mvid 23:16
                'd4  : lclk_ram.din = lclk_mvid.val[23:16];
                'd5  : lclk_ram.din = lclk_mvid.val[23:16];

                // Mvid 15:8
                'd6  : lclk_ram.din = lclk_mvid.val[15:8];
                'd7  : lclk_ram.din = lclk_mvid.val[15:8];

                // Mvid 7:0
                'd8  : lclk_ram.din = lclk_mvid.val[7:0];
                'd9  : lclk_ram.din = lclk_mvid.val[7:0];

                // Mvid 23:16
                'd22 : lclk_ram.din = lclk_mvid.val[23:16];
                'd23 : lclk_ram.din = lclk_mvid.val[23:16];

                // Mvid 15:8
                'd24 : lclk_ram.din = lclk_mvid.val[15:8];
                'd25 : lclk_ram.din = lclk_mvid.val[15:8];

                // Mvid 7:0
                'd26 : lclk_ram.din = lclk_mvid.val[7:0];
                'd27 : lclk_ram.din = lclk_mvid.val[7:0];

                // Data from policy maker
                default : lclk_ram.din = lclk_msg.dat[P_RAM_DAT-1:0];
            endcase
        end        
    end

// Write
// The policy maker writes the MSA data sequential over the lanes.
// The first message data has the first symbol of lane 0
// The second message data has the first symbol of lane 1
// The third message data has the first symbol of lane 2
// The forth message data has the first symbol of lane 3
// The fifth message data has the second symbol of lane 0
// Etc

generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_wr_4spl
        always_comb
        begin
            lclk_ram.wr = 0;

            // Valid
            if (lclk_msg.vld)
            begin
                // 4 lanes
                if (lclk_lnk.lanes)
                begin
                    case (lclk_msg.idx[3:0])
                        'd1     : lclk_ram.wr[(1*4)]    = 1; // Lane 1 sublane 0
                        'd2     : lclk_ram.wr[(2*4)]    = 1; // Lane 2 sublane 0
                        'd3     : lclk_ram.wr[(3*4)]    = 1; // Lane 3 sublane 0
                        'd4     : lclk_ram.wr[(0*4)+1]  = 1; // Lane 0 sublane 1
                        'd5     : lclk_ram.wr[(1*4)+1]  = 1; // Lane 1 sublane 1
                        'd6     : lclk_ram.wr[(2*4)+1]  = 1; // Lane 2 sublane 1
                        'd7     : lclk_ram.wr[(3*4)+1]  = 1; // Lane 3 sublane 1
                        'd8     : lclk_ram.wr[(0*4)+2]  = 1; // Lane 0 sublane 2
                        'd9     : lclk_ram.wr[(1*4)+2]  = 1; // Lane 1 sublane 2 
                        'd10    : lclk_ram.wr[(2*4)+2]  = 1; // Lane 2 sublane 2
                        'd11    : lclk_ram.wr[(3*4)+2]  = 1; // Lane 3 sublane 2
                        'd12    : lclk_ram.wr[(0*4)+3]  = 1; // Lane 0 sublane 3
                        'd13    : lclk_ram.wr[(1*4)+3]  = 1; // Lane 1 sublane 3
                        'd14    : lclk_ram.wr[(2*4)+3]  = 1; // Lane 2 sublane 3
                        'd15    : lclk_ram.wr[(3*4)+3]  = 1; // Lane 3 sublane 3
                        default : lclk_ram.wr[(0*4)]    = 1; // Lane 0 sublane 0
                    endcase
                end

                // 2 lanes
                else
                begin
                    case (lclk_msg.idx[2:0])
                        'd1     : lclk_ram.wr[(1*4)]    = 1; // Lane 1 sublane 0
                        'd2     : lclk_ram.wr[(0*4)+1]  = 1; // Lane 0 sublane 1
                        'd3     : lclk_ram.wr[(1*4)+1]  = 1; // Lane 1 sublane 1
                        'd4     : lclk_ram.wr[(0*4)+2]  = 1; // Lane 0 sublane 2
                        'd5     : lclk_ram.wr[(1*4)+2]  = 1; // Lane 1 sublane 2
                        'd6     : lclk_ram.wr[(0*4)+2]  = 1; // Lane 0 sublane 3
                        'd7     : lclk_ram.wr[(1*4)+3]  = 1; // Lane 1 sublane 3
                        default : lclk_ram.wr[(0*4)]    = 1; // Lane 0 sublane 0
                    endcase
                end           
            end
        end
    end

    // Two symbols per lane
    else
    begin : gen_wr_2spl
        always_comb
        begin
            lclk_ram.wr = 0;

            // Valid
            if (lclk_msg.vld)
            begin
                // 4 lanes
                if (lclk_lnk.lanes)
                begin
                    case (lclk_msg.idx[2:0])
                        'd1     : lclk_ram.wr[(1*2)]    = 1; // Lane 1 sublane 0
                        'd2     : lclk_ram.wr[(2*2)]    = 1; // Lane 2 sublane 0
                        'd3     : lclk_ram.wr[(3*2)]    = 1; // Lane 3 sublane 0
                        'd4     : lclk_ram.wr[(0*2)+1]  = 1; // Lane 0 sublane 1
                        'd5     : lclk_ram.wr[(1*2)+1]  = 1; // Lane 1 sublane 1
                        'd6     : lclk_ram.wr[(2*2)+1]  = 1; // Lane 2 sublane 1
                        'd7     : lclk_ram.wr[(3*2)+1]  = 1; // Lane 3 sublane 1
                        default : lclk_ram.wr[(0*2)]    = 1; // Lane 0 sublane 0
                    endcase
                end

                // 2 lanes
                else
                begin
                    case (lclk_msg.idx[1:0])
                        'd1     : lclk_ram.wr[(1*2)]    = 1; // Lane 1 sublane 0
                        'd2     : lclk_ram.wr[(0*2)+1]  = 1; // Lane 0 sublane 1
                        'd3     : lclk_ram.wr[(1*2)+1]  = 1; // Lane 1 sublane 1
                        default : lclk_ram.wr[(0*2)]    = 1; // Lane 0 sublane 0
                    endcase
                end           
            end
        end
    end
endgenerate

// Read pointer
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Clear
        if (lclk_vid.vs_re)
            lclk_ram.rp <= 0;

        // Increment
        else if (lclk_ram.rd)
            lclk_ram.rp <= lclk_ram.rp + 'd1;
    end

// Read
    always_comb
    begin
        if (!lclk_ram.rd_cnt_end)
            lclk_ram.rd = 1;
        else
            lclk_ram.rd = 0;
    end

// Read counter
    always_ff @ (posedge LNK_RST_IN, posedge LNK_CLK_IN)
    begin
        // Reset
        if (LNK_RST_IN)
            lclk_ram.rd_cnt <= 0;

        else
        begin
            // Load
            if (lclk_vid.vs_re)
            begin
                // 4 lanes
                if (lclk_lnk.lanes)
                   lclk_ram.rd_cnt <= (P_SPL == 4) ? 'd3 : 'd6; 

                // 2 lanes
                else
                   lclk_ram.rd_cnt <= (P_SPL == 4) ? 'd6 : 'd11; 
            end

            // Decrement
            else if (!lclk_ram.rd_cnt_end)
                lclk_ram.rd_cnt <= lclk_ram.rd_cnt - 'd1;
        end
    end

// Read counter end
    always_comb
    begin
        if (lclk_ram.rd_cnt == 0)
            lclk_ram.rd_cnt_end = 1;
        else
            lclk_ram.rd_cnt_end = 0;
    end

// VB-ID
    assign lclk_lnk.vbid = (lclk_vid.run) ? {7'h0, lclk_vid.vbf} : 'b00001001;

// Idle counter
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Default
        lclk_lnk.bs_cnt_ld <= 0;

        // No video
        if (!lclk_vid.run)
        begin
            // Clear 
            if (lclk_lnk.idle_cnt >= P_IDLE_CNT_MAX)
            begin
                lclk_lnk.idle_cnt <= 0;
                lclk_lnk.bs_cnt_ld <= 1;
            end

            // Increment
            else
                lclk_lnk.idle_cnt <= lclk_lnk.idle_cnt + P_SPL;
        end

        else
            lclk_lnk.idle_cnt <= 0;
    end

// BS counter
    always_ff @ (posedge LNK_RST_IN, posedge LNK_CLK_IN)
    begin
        // Reset
        if (LNK_RST_IN)
            lclk_lnk.bs_cnt <= 0;

        else
        begin
            // Load
            if (lclk_lnk.bs_cnt_ld || lclk_vid.bs)
            begin
                // Enhanced framing
                if (lclk_lnk.efm)
                    lclk_lnk.bs_cnt <= (P_SPL == 4) ? 'd2 : 'd3;
                else
                    lclk_lnk.bs_cnt <= (P_SPL == 4) ? 'd1 : 'd2;
            end

            // Decrement
            else if (!lclk_lnk.bs_cnt_end)
                lclk_lnk.bs_cnt <= lclk_lnk.bs_cnt - 'd1;
        end
    end

// BS counter end
    always_comb
    begin
        if (lclk_lnk.bs_cnt == 0)
            lclk_lnk.bs_cnt_end = 1;
        else
            lclk_lnk.bs_cnt_end = 0;
    end

// Mux
generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_mux_4spl
        always_ff @ (posedge LNK_CLK_IN)
        begin
            // Main stream attribute
            if (lclk_ram.de[0])
            begin
                // Lane 0
                {lclk_lnk.k[0][0], lclk_lnk.dat[0][0]} <= lclk_ram.dout[0]; // Sublane 0
                {lclk_lnk.k[0][1], lclk_lnk.dat[0][1]} <= lclk_ram.dout[1]; // Sublane 1
                {lclk_lnk.k[0][2], lclk_lnk.dat[0][2]} <= lclk_ram.dout[2]; // Sublane 2
                {lclk_lnk.k[0][3], lclk_lnk.dat[0][3]} <= lclk_ram.dout[3]; // Sublane 3

                // Lane 1
                {lclk_lnk.k[1][0], lclk_lnk.dat[1][0]} <= lclk_ram.dout[4]; // Sublane 0
                {lclk_lnk.k[1][1], lclk_lnk.dat[1][1]} <= lclk_ram.dout[5]; // Sublane 1
                {lclk_lnk.k[1][2], lclk_lnk.dat[1][2]} <= lclk_ram.dout[6]; // Sublane 2
                {lclk_lnk.k[1][3], lclk_lnk.dat[1][3]} <= lclk_ram.dout[7]; // Sublane 3

                // Lane 2
                {lclk_lnk.k[2][0], lclk_lnk.dat[2][0]} <= lclk_ram.dout[8];  // Sublane 0
                {lclk_lnk.k[2][1], lclk_lnk.dat[2][1]} <= lclk_ram.dout[9];  // Sublane 1
                {lclk_lnk.k[2][2], lclk_lnk.dat[2][2]} <= lclk_ram.dout[10]; // Sublane 2
                {lclk_lnk.k[2][3], lclk_lnk.dat[2][3]} <= lclk_ram.dout[11]; // Sublane 3

                // Lane 3
                {lclk_lnk.k[3][0], lclk_lnk.dat[3][0]} <= lclk_ram.dout[12]; // Sublane 0
                {lclk_lnk.k[3][1], lclk_lnk.dat[3][1]} <= lclk_ram.dout[13]; // Sublane 1
                {lclk_lnk.k[3][2], lclk_lnk.dat[3][2]} <= lclk_ram.dout[14]; // Sublane 2
                {lclk_lnk.k[3][3], lclk_lnk.dat[3][3]} <= lclk_ram.dout[15]; // Sublane 3
            end

            // BS
            else if (!lclk_lnk.bs_cnt_end)
            begin
                for (int i = 0; i < P_LANES; i++)
                begin
                    // Enhanced framing
                    if (lclk_lnk.efm)
                    begin
                        case (lclk_lnk.bs_cnt)
                            'd2 : 
                            begin
                                {lclk_lnk.k[i][0], lclk_lnk.dat[i][0]} <= P_SYM_BS;
                                {lclk_lnk.k[i][1], lclk_lnk.dat[i][1]} <= P_SYM_BF;
                                {lclk_lnk.k[i][2], lclk_lnk.dat[i][2]} <= P_SYM_BF;
                                {lclk_lnk.k[i][3], lclk_lnk.dat[i][3]} <= P_SYM_BS;
                            end

                            'd1 : 
                            begin
                                {lclk_lnk.k[i][0], lclk_lnk.dat[i][0]} <= {1'b0, lclk_lnk.vbid};
                                {lclk_lnk.k[i][1], lclk_lnk.dat[i][1]} <= (lclk_vid.run) ? {1'b0, lclk_mvid.val[7:0]} : 0;
                                {lclk_lnk.k[i][2], lclk_lnk.dat[i][2]} <= 0;
                                {lclk_lnk.k[i][3], lclk_lnk.dat[i][3]} <= 0;
                            end

                            default : ;
                        endcase
                    end

                    // Normal
                    else 
                    begin
                        case (lclk_lnk.bs_cnt)
                            'd1 : 
                            begin
                                for (int i = 0; i < P_LANES; i++)
                                begin
                                    {lclk_lnk.k[i][0], lclk_lnk.dat[i][0]} <= P_SYM_BS;
                                    {lclk_lnk.k[i][1], lclk_lnk.dat[i][1]} <= {1'b0, lclk_lnk.vbid};
                                    {lclk_lnk.k[i][2], lclk_lnk.dat[i][2]} <= (lclk_vid.run) ? {1'b0, lclk_mvid.val[7:0]} : 0;
                                    {lclk_lnk.k[i][3], lclk_lnk.dat[i][3]} <= 0;
                                end
                            end

                            default : ;
                        endcase
                    end
                end
            end

            // Link sink 
            else
            begin
                for (int i = 0; i < P_LANES; i++)
                begin
                    lclk_lnk.k[i]   <= LNK_SNK_IF.k[i];
                    lclk_lnk.dat[i] <= LNK_SNK_IF.dat[i];
                end
            end
        end
    end

    // Two symbols per lane
    else
    begin : gen_mux_2spl
        always_ff @ (posedge LNK_CLK_IN)
        begin
            // Main stream attribute
            if (lclk_ram.de[0])
            begin
                {lclk_lnk.k[0][0], lclk_lnk.dat[0][0]} <= lclk_ram.dout[0]; // Lane 0 sublane 0
                {lclk_lnk.k[0][1], lclk_lnk.dat[0][1]} <= lclk_ram.dout[1]; // Lane 0 sublane 1
                {lclk_lnk.k[1][0], lclk_lnk.dat[1][0]} <= lclk_ram.dout[2]; // Lane 1 sublane 0
                {lclk_lnk.k[1][1], lclk_lnk.dat[1][1]} <= lclk_ram.dout[3]; // Lane 1 sublane 1
                {lclk_lnk.k[2][0], lclk_lnk.dat[2][0]} <= lclk_ram.dout[4]; // Lane 2 sublane 0
                {lclk_lnk.k[2][1], lclk_lnk.dat[2][1]} <= lclk_ram.dout[5]; // Lane 2 sublane 1
                {lclk_lnk.k[3][0], lclk_lnk.dat[3][0]} <= lclk_ram.dout[6]; // Lane 3 sublane 0
                {lclk_lnk.k[3][1], lclk_lnk.dat[3][1]} <= lclk_ram.dout[7]; // Lane 3 sublane 1
            end

            // BS
            else if (!lclk_lnk.bs_cnt_end)
            begin
                for (int i = 0; i < P_LANES; i++)
                begin
                    // Enhanced framing
                    if (lclk_lnk.efm)
                    begin
                        case (lclk_lnk.bs_cnt)
                            'd3 : 
                            begin
                                {lclk_lnk.k[i][0], lclk_lnk.dat[i][0]} <= P_SYM_BS;
                                {lclk_lnk.k[i][1], lclk_lnk.dat[i][1]} <= P_SYM_BF;
                            end

                            'd2 : 
                            begin
                                {lclk_lnk.k[i][0], lclk_lnk.dat[i][0]} <= P_SYM_BF;
                                {lclk_lnk.k[i][1], lclk_lnk.dat[i][1]} <= P_SYM_BS;
                            end

                            'd1 : 
                            begin
                                {lclk_lnk.k[i][0], lclk_lnk.dat[i][0]} <= {1'b0, lclk_lnk.vbid};
                                {lclk_lnk.k[i][1], lclk_lnk.dat[i][1]} <= (lclk_vid.run) ? {1'b0, lclk_mvid.val[7:0]} : 0;
                            end

                            default : ;
                        endcase
                    end

                    // Normal
                    else 
                    begin
                        case (lclk_lnk.bs_cnt)
                            'd2 : 
                            begin
                                for (int i = 0; i < P_LANES; i++)
                                begin
                                    {lclk_lnk.k[i][0], lclk_lnk.dat[i][0]} <= P_SYM_BS;
                                    {lclk_lnk.k[i][1], lclk_lnk.dat[i][1]} <= {1'b0, lclk_lnk.vbid};
                                end
                            end

                            'd1 : 
                            begin
                                for (int i = 0; i < P_LANES; i++)
                                begin
                                    {lclk_lnk.k[i][0], lclk_lnk.dat[i][0]} <= (lclk_vid.run) ? {1'b0, lclk_mvid.val[7:0]} : 0;
                                    {lclk_lnk.k[i][1], lclk_lnk.dat[i][1]} <= 0;
                                end
                            end

                            default : ;
                        endcase
                    end
                end
            end

            // Link sink 
            else
            begin
                for (int i = 0; i < P_LANES; i++)
                begin
                    lclk_lnk.k[i]   <= LNK_SNK_IF.k[i];
                    lclk_lnk.dat[i] <= LNK_SNK_IF.dat[i];
                end
            end
        end
    end
endgenerate


/*
    Mvid generator
    This process will define the ratio between the link clock and the video clock
*/

// Video MVID clock counter
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Clock enable
        if (VID_CKE_IN)
        begin
            // Clear
            if (vclk_mvid.clr)
                vclk_mvid.val <= 0;

            // Run
            else if (vclk_mvid.run)
                vclk_mvid.val <= vclk_mvid.val + 'd1;
        end
    end

// Clear clock domain crossing
    prt_dp_lib_cdc_bit
    VCLK_MVID_CLR_CDC_INST
    (
        .SRC_CLK_IN     (LNK_CLK_IN),       // Clock
        .SRC_DAT_IN     (lclk_mvid.clr),    // Data
        .DST_CLK_IN     (VID_CLK_IN),       // Clock
        .DST_DAT_OUT    (vclk_mvid.clr)     // Data
    );

// Run clock domain crossing
    prt_dp_lib_cdc_bit
    VCLK_MVID_RUN_CDC_INST
    (
        .SRC_CLK_IN     (LNK_CLK_IN),       // Clock
        .SRC_DAT_IN     (lclk_mvid.run),    // Data
        .DST_CLK_IN     (VID_CLK_IN),       // Clock
        .DST_DAT_OUT    (vclk_mvid.run)     // Data
    );

// Convert mvid value from video clock to link clock domain
    prt_dp_lib_cdc_vec
    #(
        .P_WIDTH      ($size(vclk_mvid.val))
    )
    VCLK_MVID_VAL_CDC_INST
    (
        .SRC_CLK_IN   (VID_CLK_IN),
        .SRC_DAT_IN   (vclk_mvid.val),
        .DST_CLK_IN   (LNK_CLK_IN),
        .DST_DAT_OUT  (lclk_mvid.vclk_val)
    );

// Counter
// Used by state machine
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Load
        if (lclk_mvid.cnt_ld)
            lclk_mvid.cnt <= lclk_mvid.cnt_in;

        // Decrement
        else if (!lclk_mvid.cnt_end)
            lclk_mvid.cnt <= lclk_mvid.cnt - 'd1;
    end

// Counter end
    always_comb
    begin
        if (lclk_mvid.cnt == 0)
            lclk_mvid.cnt_end = 1;
        else
            lclk_mvid.cnt_end = 0;
    end

// State machine
    always_ff @ (posedge LNK_RST_IN, posedge LNK_CLK_IN)
    begin
        // Reset
        if (LNK_RST_IN)
            lclk_mvid.sm_cur <= mvid_sm_idle;

        else
            lclk_mvid.sm_cur <= lclk_mvid.sm_nxt;
    end

// State machine decoder
    always_comb
    begin
        // Default
        lclk_mvid.clr = 0;
        lclk_mvid.run = 0;
        lclk_mvid.ld = 0;
        lclk_mvid.cnt_ld = 0;
        lclk_mvid.cnt_in = 0;

        case (lclk_mvid.sm_cur)

            mvid_sm_idle :
            begin
                lclk_mvid.cnt_in = 'd255;
                lclk_mvid.cnt_ld = 1;
                lclk_mvid.sm_nxt = mvid_sm_clr;
            end

            // Clear 
            mvid_sm_clr : 
            begin
                lclk_mvid.clr = 1;

                // Wait for counter to expire
                if (lclk_mvid.cnt_end)
                begin
                    lclk_mvid.cnt_ld = 1;
                    lclk_mvid.cnt_in = 'd255;  
                    lclk_mvid.sm_nxt = mvid_sm_wait;
                end

                else
                    lclk_mvid.sm_nxt = mvid_sm_clr;
            end

            // Wait
            mvid_sm_wait :
            begin
                // Wait for counter to expire
                if (lclk_mvid.cnt_end)
                begin
                    lclk_mvid.cnt_ld = 1;
                    lclk_mvid.cnt_in = P_MVID_CNT;      // Load counter with Nvid value
                    lclk_mvid.sm_nxt = mvid_sm_run;
                end

                else
                    lclk_mvid.sm_nxt = mvid_sm_wait;
            end

            // Run 
            mvid_sm_run :
            begin
                lclk_mvid.run = 1;

                // Wait for counter to expire
                if (lclk_mvid.cnt_end)
                begin
                    lclk_mvid.cnt_ld = 1;
                    lclk_mvid.cnt_in = 'd255;  
                    lclk_mvid.sm_nxt = mvid_sm_cap;
                end

                else
                    lclk_mvid.sm_nxt = mvid_sm_run;
            end

            // Capture Mvid
            mvid_sm_cap :
            begin
                // Wait for counter to expire
                if (lclk_mvid.cnt_end)
                begin
                    lclk_mvid.ld = 1;
                    lclk_mvid.sm_nxt = mvid_sm_idle;
                end

                else
                    lclk_mvid.sm_nxt = mvid_sm_cap;
            end

            default : 
            begin
                lclk_mvid.sm_nxt = mvid_sm_idle;
            end
        endcase
    end

// Mvid
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Load
        if (lclk_mvid.ld)
            lclk_mvid.val <= lclk_mvid.vclk_val;
    end

// Outputs
generate
    for (i = 0; i < P_LANES; i++)
    begin
        assign LNK_SRC_IF.disp_ctl[i]   = 0; // Not used
        assign LNK_SRC_IF.disp_val[i]   = 0; // Not used
        assign LNK_SRC_IF.k[i]          = lclk_lnk.k[i];
        assign LNK_SRC_IF.dat[i]        = lclk_lnk.dat[i];
    end
endgenerate

endmodule

`default_nettype wire
