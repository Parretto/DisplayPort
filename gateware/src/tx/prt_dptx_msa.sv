/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP TX Main Stream Attribute (msa)
    (c) 2021 - 2024 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Added support for 1 and 2 lanes
    v1.2 - Updated architecture to insert Mvid value in MSA RAM output
    v1.3 - Updated interfaces and added scrambler reset insert function
    v1.4 - Added MST support

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

module prt_dptx_msa
#(
    // System
    parameter               P_VENDOR      = "none", // Vendor "xilinx", "lattice" or "intel"
    parameter               P_SIM         = 0,      // Simulation
    parameter               P_STREAM      = 0,      // Stream ID

    // Link
    parameter               P_LANES       = 4,      // Lanes
    parameter               P_SPL         = 2,      // Symbols per lane

    // Message
    parameter               P_MSG_IDX     = 5,      // Message index width
    parameter               P_MSG_DAT     = 16,     // Message data width
    parameter               P_MSG_ID      = 0       // Message ID main stream attributes
)
(
    // Reset and clock
    input wire              LNK_RST_IN,     // Link reset
    input wire              LNK_CLK_IN,     // Link clock
    input wire              VID_CLK_IN,     // Video clock
    input wire              VID_CKE_IN,     // Video clock enable

    // Control
    input wire [1:0]        CTL_LANES_IN,   // Active lanes (1 - 1 lane / 2 - 2 lanes / 3 - 4 lanes)
    input wire              CTL_VID_EN_IN,  // Video enable
    input wire              CTL_SCRM_EN_IN, // Scrambler enable
    input wire              CTL_MST_IN,     // MST 

    // Message
    prt_dp_msg_if.snk       MSG_SNK_IF,     // Sink
    prt_dp_msg_if.src       MSG_SRC_IF,     // Source

    // Video
    input wire              LNK_VS_IN,      // Vsync 
    input wire              LNK_VBF_IN,     // Vertical blanking flag

    // Link
    prt_dp_tx_lnk_if.snk    LNK_SNK_IF,     // Sink    
    prt_dp_tx_lnk_if.src    LNK_SRC_IF      // Source
);

// Package
import prt_dp_pkg::*;

// Localparam
localparam P_IDLE_CNT_MAX = 8192 - P_SPL;
localparam P_RAM_WRDS = (P_SPL == 4) ? 16 : 32;
localparam P_RAM_ADR = $clog2(P_RAM_WRDS);
localparam P_RAM_DAT = 9;
localparam P_MVID_CNT = P_SIM ? 255 : 32767;
localparam P_BS_CNT_MAX = P_SIM ? 10 : 512;

// States
typedef enum {
    mvid_sm_idle, mvid_sm_clr, mvid_sm_wait, mvid_sm_run, mvid_sm_cap
} mvid_sm_state;

// Structure
typedef struct {
    logic                           vid_en;
    logic                           vid_en_re;
    logic                           scrm_en;
    logic                           scrm_en_re;
    logic   [1:0]                   lanes;
    logic                           mst;
} ctl_struct;

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
    prt_dp_tx_lnk_sym               sym[0:P_LANES-1][0:P_SPL-1];    // Symbol
    logic   [7:0]                   dat[0:P_LANES-1][0:P_SPL-1];    // Data
    logic                           vld;                            // Valid
} snk_struct;

typedef struct {
    logic   [P_RAM_ADR-1:0]         cnt;
    logic   [P_RAM_DAT-1:0]         dat[0:P_LANES*P_SPL-1];    // Read data
} ins_struct;

typedef struct {
    logic   [12:0]                  idle_cnt;
    logic   [2:0]                   bs_det;
    logic                           bs_force;
    logic   [7:0]                   vbid;                           // VB-ID
} msa_struct;

typedef struct {
    logic                           rd;                             // Read
    prt_dp_tx_lnk_sym               sym[0:P_LANES-1][0:P_SPL-1];    // Symbol
    logic   [7:0]                   dat[0:P_LANES-1][0:P_SPL-1];    // Data
    logic                           vld;                            // Valid
} src_struct;

typedef struct {
    logic                           run;
    logic                           vs;
    logic                           vs_re;
    logic                           vbf;
    logic                           bs;
} vid_struct;

typedef struct {
    logic [9:0]                     bs_cnt;
    logic                           sr_ins;
} sr_struct;

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
ctl_struct          lclk_ctl;
msg_struct          lclk_msg;
ram_struct          lclk_ram;
snk_struct          lclk_snk;
ins_struct          lclk_ins;
msa_struct          lclk_msa;
src_struct          lclk_src;
vid_struct          lclk_vid;
sr_struct           lclk_sr;
vid_mvid_struct     vclk_mvid;
lnk_mvid_struct     lclk_mvid;

genvar i, j;

// Control Inputs
    always_ff @ (posedge LNK_CLK_IN)
    begin
        lclk_ctl.lanes   <= CTL_LANES_IN;
        lclk_ctl.vid_en  <= CTL_VID_EN_IN;
        lclk_ctl.scrm_en <= CTL_SCRM_EN_IN;
        lclk_ctl.mst     <= CTL_MST_IN;
    end

// Video enable edge detector
    prt_dp_lib_edge
    VID_EN_EDGE_INST
    (
        .CLK_IN    (LNK_CLK_IN),            // Clock
        .CKE_IN    (1'b1),                  // Clock enable
        .A_IN      (lclk_ctl.vid_en),       // Input
        .RE_OUT    (lclk_ctl.vid_en_re),    // Rising edge
        .FE_OUT    ()                       // Falling edge
    );

// Scrambler enable edge detector
    prt_dp_lib_edge
    SCRM_EN_EDGE_INST
    (
        .CLK_IN    (LNK_CLK_IN),            // Clock
        .CKE_IN    (1'b1),                  // Clock enable
        .A_IN      (lclk_ctl.scrm_en),      // Input
        .RE_OUT    (lclk_ctl.scrm_en_re),   // Rising edge
        .FE_OUT    ()                       // Falling edge
    );

// Link sink inputs
// Must be combinatorial
generate    
    for (i = 0; i < P_LANES; i++)
    begin
        for (j = 0; j < P_SPL; j++)
        begin
            assign lclk_snk.sym[i][j] = prt_dp_tx_lnk_sym'(LNK_SNK_IF.sym[i][j]);
            assign lclk_snk.dat[i][j] = LNK_SNK_IF.dat[i][j];
        end
    end
endgenerate
    assign lclk_snk.vld = LNK_SNK_IF.vld;

// Link source inputs
// To increase performance this signal is registered.
    always_ff @ (posedge LNK_CLK_IN)
    begin
        lclk_src.rd <= LNK_SRC_IF.rd;
    end

// Video Inputs
    always_ff @ (posedge LNK_CLK_IN)
    begin
        lclk_vid.vs     <= LNK_VS_IN;
        lclk_vid.vbf    <= LNK_VBF_IN;
    end

// Run
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Clear
        if (!lclk_ctl.vid_en)
            lclk_vid.run <= 0;

        // Set at vsync
        else if (lclk_vid.vs_re && lclk_ctl.vid_en)
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
        .P_ID           (P_MSG_ID),       // Identifier
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
            .P_VENDOR       (P_VENDOR),
            .P_RAM_STYLE    ("distributed"),    // "distributed", "block" or "ultra"
            .P_ADR_WIDTH    (P_RAM_ADR),
            .P_DAT_WIDTH    (P_RAM_DAT)
        )
        RAM_INST
        (
            // Clocks and reset
            .RST_IN     (LNK_RST_IN),        // Reset
            .CLK_IN     (LNK_CLK_IN),        // Clock

            // Port A
            .A_ADR_IN   (lclk_ram.wp),       // Write pointer
            .A_WR_IN    (lclk_ram.wr[i]),    // Write in
            .A_DAT_IN   (lclk_ram.din),      // Write data

            // Port B
            .B_EN_IN    (lclk_snk.vld),      // Enable
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
            else if ((lclk_ctl.lanes == 'd3) && lclk_ram.wr[$size(lclk_ram.wr)-1])
                lclk_ram.wp <= lclk_ram.wp + 'd1;

            // 2 lanes; Increment when the upper ram have been written
            else if ((lclk_ctl.lanes == 'd2) && lclk_ram.wr[($size(lclk_ram.wr)/2)-1])
                lclk_ram.wp <= lclk_ram.wp + 'd1;

            // 1 lanes; Increment when the upper ram have been written
            else if ((lclk_ctl.lanes == 'd1) && lclk_ram.wr[($size(lclk_ram.wr)/4)-1])
                lclk_ram.wp <= lclk_ram.wp + 'd1;
        end
    end

// Write data
    assign lclk_ram.din = lclk_msg.dat[P_RAM_DAT-1:0];

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
                if (lclk_ctl.lanes == 'd3)
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
                else if (lclk_ctl.lanes == 'd2)
                begin
                    case (lclk_msg.idx[2:0])
                        'd1     : lclk_ram.wr[(1*4)]    = 1; // Lane 1 sublane 0
                        'd2     : lclk_ram.wr[(0*4)+1]  = 1; // Lane 0 sublane 1
                        'd3     : lclk_ram.wr[(1*4)+1]  = 1; // Lane 1 sublane 1
                        'd4     : lclk_ram.wr[(0*4)+2]  = 1; // Lane 0 sublane 2
                        'd5     : lclk_ram.wr[(1*4)+2]  = 1; // Lane 1 sublane 2
                        'd6     : lclk_ram.wr[(0*4)+3]  = 1; // Lane 0 sublane 3
                        'd7     : lclk_ram.wr[(1*4)+3]  = 1; // Lane 1 sublane 3
                        default : lclk_ram.wr[(0*4)]    = 1; // Lane 0 sublane 0
                    endcase
                end           

                // 1 lane
                else 
                begin
                    case (lclk_msg.idx[1:0])
                        'd1     : lclk_ram.wr[(0*4)+1]  = 1; // Lane 0 sublane 1
                        'd2     : lclk_ram.wr[(0*4)+2]  = 1; // Lane 0 sublane 2
                        'd3     : lclk_ram.wr[(0*4)+3]  = 1; // Lane 0 sublane 3
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
                if (lclk_ctl.lanes == 'd3)
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
                else if (lclk_ctl.lanes == 'd2)
                begin
                    case (lclk_msg.idx[1:0])
                        'd1     : lclk_ram.wr[(1*2)]    = 1; // Lane 1 sublane 0
                        'd2     : lclk_ram.wr[(0*2)+1]  = 1; // Lane 0 sublane 1
                        'd3     : lclk_ram.wr[(1*2)+1]  = 1; // Lane 1 sublane 1
                        default : lclk_ram.wr[(0*2)]    = 1; // Lane 0 sublane 0
                    endcase
                end           

                // 1 lane
                else 
                begin
                    if (lclk_msg.idx[0])
                        lclk_ram.wr[(0*2)+1]  = 1; // Lane 0 sublane 1
                    else
                        lclk_ram.wr[(0*2)]    = 1; // Lane 0 sublane 0
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
        else if (lclk_ram.rd && lclk_snk.vld)
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
                if (lclk_ctl.lanes == 'd3)
                   lclk_ram.rd_cnt <= (P_SPL == 4) ? 'd3 : 'd6; 

                // 2 lanes
                else if (lclk_ctl.lanes == 'd2)
                   lclk_ram.rd_cnt <= (P_SPL == 4) ? 'd6 : 'd11; 

                // 1 lane
                else 
                   lclk_ram.rd_cnt <= (P_SPL == 4) ? 'd10 : 'd20; 
            end

            // Decrement
            else if (!lclk_ram.rd_cnt_end && lclk_snk.vld)
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
    assign lclk_msa.vbid = (lclk_vid.run) ? {7'h0, lclk_vid.vbf} : 'b00001001;

// BS detector phase 1
// This is used to insert the first data of the BS sequence
// Must be combinatorial
    always_comb
    begin
        // Only check lane 0
        // The BS is aligned in sublane 0
        if ((lclk_snk.sym[0][0] == TX_LNK_SYM_BS) || lclk_msa.bs_force)
            lclk_msa.bs_det[0] = 1;
        else
            lclk_msa.bs_det[0] = 0;
    end

// BS detector phase 2
// This is used to insert the second data and third data of the BS sequence
// Must be registered
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Run
        if (lclk_vid.run)
        begin
            // Valid
            if (lclk_snk.vld)
                lclk_msa.bs_det[2:1] <= lclk_msa.bs_det[1:0];
        end

        // Idle
        else
            lclk_msa.bs_det[2:1] <= 0;
    end

// Idle counter
// This logic is only needed in SST 
generate
    if (P_STREAM == 0)
    begin : gen_idle_cnt
        always_ff @ (posedge LNK_CLK_IN)
        begin
            // Default
            lclk_msa.bs_force <= 0;

            // Run when no video and not in mst mode
            if (!lclk_vid.run && !lclk_ctl.mst)
            begin
                // Clear 
                if (lclk_ctl.scrm_en_re || (lclk_msa.idle_cnt >= P_IDLE_CNT_MAX))
                begin
                    lclk_msa.idle_cnt <= 0;
                    lclk_msa.bs_force <= 1;
                end

                // Increment
                else
                    lclk_msa.idle_cnt <= lclk_msa.idle_cnt + P_SPL;
            end

            else
                lclk_msa.idle_cnt <= 0;
        end
    end

    // MST
    else
    begin
        assign lclk_msa.idle_cnt = 0;
        assign lclk_msa.bs_force = 0;
    end
endgenerate

// Inserter
// This process inserts the Mvid value in the MSA data from the RAM.
// todo: Add all lanes modes

// Counter
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Run
        if (lclk_vid.run)
        begin
            // Enable
            if (lclk_snk.vld)
            begin
                // Increment
                if (lclk_ram.de[0])
                    lclk_ins.cnt <= lclk_ins.cnt + 'd1;
                
                // Clear
                else
                    lclk_ins.cnt <= 0;
            end
        end

        // Idle
        else
            lclk_ins.cnt <= 0;
    end

// Data inserter
generate
    if (P_SPL == 4) 
    begin : gen_ins_dat_4spl
        always_comb
        begin
            // Default
            for (int i = 0; i < P_LANES * P_SPL; i++)
                lclk_ins.dat[i] = lclk_ram.dout[i];

            case (lclk_ins.cnt)
                'd0 : 
                begin
                    lclk_ins.dat[(0*4)+2] = {1'b0, lclk_mvid.val[23:16]};
                    lclk_ins.dat[(0*4)+3] = {1'b0, lclk_mvid.val[15:8]};
                    lclk_ins.dat[(1*4)+2] = {1'b0, lclk_mvid.val[23:16]};
                    lclk_ins.dat[(1*4)+3] = {1'b0, lclk_mvid.val[15:8]};
                    lclk_ins.dat[(2*4)+2] = {1'b0, lclk_mvid.val[23:16]};
                    lclk_ins.dat[(2*4)+3] = {1'b0, lclk_mvid.val[15:8]};
                    lclk_ins.dat[(3*4)+2] = {1'b0, lclk_mvid.val[23:16]};
                    lclk_ins.dat[(3*4)+3] = {1'b0, lclk_mvid.val[15:8]};
                end

                'd1 : 
                begin
                    lclk_ins.dat[(0*4)+0] = {1'b0, lclk_mvid.val[7:0]};
                    lclk_ins.dat[(1*4)+0] = {1'b0, lclk_mvid.val[7:0]};
                    lclk_ins.dat[(2*4)+0] = {1'b0, lclk_mvid.val[7:0]};
                    lclk_ins.dat[(3*4)+0] = {1'b0, lclk_mvid.val[7:0]};
                end

                default : ;
            endcase
        end
    end

    else
    begin : gen_ins_dat_2spl
        always_comb
        begin
            // Default
            for (int i = 0; i < P_LANES * P_SPL; i++)
                lclk_ins.dat[i] = lclk_ram.dout[i];

            case (lclk_ins.cnt)
                'd1 : 
                begin
                    lclk_ins.dat[(0*2)+0] = {1'b0, lclk_mvid.val[23:16]};   // Lane 0 - Sublane 0
                    lclk_ins.dat[(0*2)+1] = {1'b0, lclk_mvid.val[15:8]};    // Lane 0 - Sublane 1
                    lclk_ins.dat[(1*2)+0] = {1'b0, lclk_mvid.val[23:16]};   // Lane 1 - Sublane 0
                    lclk_ins.dat[(1*2)+1] = {1'b0, lclk_mvid.val[15:8]};    // Lane 1 - Sublane 1
                    lclk_ins.dat[(2*2)+0] = {1'b0, lclk_mvid.val[23:16]};   // Lane 2 - Sublane 0
                    lclk_ins.dat[(2*2)+1] = {1'b0, lclk_mvid.val[15:8]};    // Lane 2 - Sublane 1
                    lclk_ins.dat[(3*2)+0] = {1'b0, lclk_mvid.val[23:16]};   // Lane 3 - Sublane 0
                    lclk_ins.dat[(3*2)+1] = {1'b0, lclk_mvid.val[15:8]};    // Lane 3 - Sublane 1
                end

                'd2 : 
                begin
                    lclk_ins.dat[(0*2)+0] = {1'b0, lclk_mvid.val[7:0]};     // Lane 0 - Sublane 0
                    lclk_ins.dat[(1*2)+0] = {1'b0, lclk_mvid.val[7:0]};     // Lane 1 - Sublane 0
                    lclk_ins.dat[(2*2)+0] = {1'b0, lclk_mvid.val[7:0]};     // Lane 2 - Sublane 0
                    lclk_ins.dat[(3*2)+0] = {1'b0, lclk_mvid.val[7:0]};     // Lane 3 - Sublane 0
                end

                default : ;
            endcase
        end
    end
endgenerate

// Source output
generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_mux_4spl
        always_ff @ (posedge LNK_RST_IN, posedge LNK_CLK_IN)
        begin
            // Reset
            if (LNK_RST_IN)
            begin
                for (int i = 0; i < P_LANES; i++)
                begin
                    for (int j = 0; j < P_SPL; j++)
                    begin
                        lclk_src.sym[i][j] <= TX_LNK_SYM_NOP;               
                        lclk_src.dat[i][j] <= 0; 
                    end
                end
            end
            
            else
            begin
                // Valid
                if (lclk_snk.vld)
                begin
                    // MSA data
                    if (lclk_ram.de[0])
                    begin
                        for (int i = 0; i < P_LANES; i++)
                        begin
                            for (int j = 0; j < P_SPL; j++)
                            begin
                                // SS symbol
                                if (lclk_ins.dat[(i*P_SPL)+j] == P_SYM_SS)
                                begin
                                    lclk_src.sym[i][j] <= TX_LNK_SYM_SS;               
                                    lclk_src.dat[i][j] <= 0; 
                                end

                                // SE symbol
                                else if (lclk_ins.dat[(i*P_SPL)+j] == P_SYM_SE)
                                begin
                                    lclk_src.sym[i][j] <= TX_LNK_SYM_SE;               
                                    lclk_src.dat[i][j] <= 0; 
                                end

                                // Data
                                else
                                begin
                                    lclk_src.sym[i][j] <= TX_LNK_SYM_DAT;
                                    lclk_src.dat[i][j] <= lclk_ins.dat[(i*P_SPL)+j][7:0];
                                end
                            end
                        end

                        // Valid
                        lclk_src.vld <= 1;
                    end

                    // BS sequence phase 1 (SST)
                    else if (!lclk_ctl.mst && lclk_msa.bs_det[0])
                    begin
                        for (int i = 0; i < P_LANES; i++)
                        begin
                            // Sublane 0
                            lclk_src.sym[i][0] <= lclk_sr.sr_ins ? TX_LNK_SYM_SR : TX_LNK_SYM_BS;
                            lclk_src.dat[i][0] <= 0;
                            
                            // Sublane 1
                            lclk_src.sym[i][1] <= TX_LNK_SYM_BF;
                            lclk_src.dat[i][1] <= 0;
                            
                            // Sublane 2
                            lclk_src.sym[i][2] <= TX_LNK_SYM_BF;
                            lclk_src.dat[i][2] <= 0;
                            
                            // Sublane 3
                            lclk_src.sym[i][3] <= lclk_sr.sr_ins ? TX_LNK_SYM_SR : TX_LNK_SYM_BS;
                            lclk_src.dat[i][3] <= 0;
                        end

                        // Valid
                        lclk_src.vld <= 1;
                    end

                    // BS sequence phase 2 (SST)
                    else if (!lclk_ctl.mst && lclk_msa.bs_det[1])
                    begin
                        for (int i = 0; i < P_LANES; i++)
                        begin
                            // Sublane 0
                            lclk_src.sym[i][0] <= TX_LNK_SYM_DAT;
                            lclk_src.dat[i][0] <= lclk_msa.vbid;
                            
                            // Sublane 1
                            lclk_src.sym[i][1] <= TX_LNK_SYM_DAT;
                            lclk_src.dat[i][1] <= (lclk_vid.run) ? {1'b0, lclk_mvid.val[7:0]} : 0;
                            
                            // Sublane 2
                            lclk_src.sym[i][2] <= TX_LNK_SYM_DAT;
                            lclk_src.dat[i][2] <= 0;
                            
                            // Sublane 3
                            lclk_src.sym[i][3] <= TX_LNK_SYM_DAT;
                            lclk_src.dat[i][3] <= 0;
                        end

                        // Valid
                        lclk_src.vld <= 1;
                    end

                    // BS sequence phase 0 (MST)
                    else if (lclk_ctl.mst && lclk_msa.bs_det[0])
                    begin
                        for (int i = 0; i < P_LANES; i++)
                        begin
                            // Sublane 0
                            lclk_src.sym[i][0] <= TX_LNK_SYM_BS;
                            lclk_src.dat[i][0] <= 0;
                            
                            // Sublane 1
                            lclk_src.sym[i][1] <= TX_LNK_SYM_DAT;
                            lclk_src.dat[i][1] <= lclk_msa.vbid;
                            
                            // Sublane 2
                            lclk_src.sym[i][2] <= TX_LNK_SYM_DAT;
                            lclk_src.dat[i][2] <= (lclk_vid.run) ? {1'b0, lclk_mvid.val[7:0]} : 0; // Mvid [7:0]
                            
                            // Sublane 3
                            lclk_src.sym[i][3] <= TX_LNK_SYM_DAT;
                            lclk_src.dat[i][3] <= 0;    // Maud [7:0]
                        end

                        // Valid
                        lclk_src.vld <= 1;
                    end

                    // Video data
                    else
                    begin
                        for (int i = 0; i < P_LANES; i++)
                        begin
                            for (int j = 0; j < P_SPL; j++)
                            begin
                                lclk_src.sym[i][j]  <= lclk_snk.sym[i][j]; 
                                lclk_src.dat[i][j]  <= lclk_snk.dat[i][j];
                                lclk_src.vld        <= 1;
                            end
                        end
                    end
                end

                // Idle
                else
                    lclk_src.vld <= 0;
            end
        end
    end

    // Two symbols per lane
    else
    begin : gen_mux_2spl
        always_ff @ (posedge LNK_RST_IN, posedge LNK_CLK_IN)
        begin
            // Reset
            if (LNK_RST_IN)
            begin
                for (int i = 0; i < P_LANES; i++)
                begin
                    for (int j = 0; j < P_SPL; j++)
                    begin
                        lclk_src.sym[i][j] <= TX_LNK_SYM_NOP;               
                        lclk_src.dat[i][j] <= 0; 
                    end
                end
            end
            
            else
            begin
                // Valid
                if (lclk_snk.vld)
                begin
                    // Main stream attribute
                    if (lclk_ram.de[0])
                    begin
                        for (int i = 0; i < P_LANES; i++)
                        begin
                            for (int j = 0; j < P_SPL; j++)
                            begin
                                // SS symbol
                                if (lclk_ins.dat[(i*P_SPL)+j] == P_SYM_SS)
                                begin
                                    lclk_src.sym[i][j] <= TX_LNK_SYM_SS;               
                                    lclk_src.dat[i][j] <= 0; 
                                end

                                // SE symbol
                                else if (lclk_ins.dat[(i*P_SPL)+j] == P_SYM_SE)
                                begin
                                    lclk_src.sym[i][j] <= TX_LNK_SYM_SE;               
                                    lclk_src.dat[i][j] <= 0; 
                                end

                                // Data
                                else
                                begin
                                    lclk_src.sym[i][j] <= TX_LNK_SYM_DAT;
                                    lclk_src.dat[i][j] <= lclk_ins.dat[(i*P_SPL)+j][7:0];
                                end
                            end
                        end

                        // Valid
                        lclk_src.vld <= 1;
                    end
                    
                    // BS phase 0 (SST)
                    else if (!lclk_ctl.mst && lclk_msa.bs_det[0])
                    begin
                        for (int i = 0; i < P_LANES; i++)
                        begin
                            // Sublane 0
                            lclk_src.sym[i][0] <= lclk_sr.sr_ins ? TX_LNK_SYM_SR : TX_LNK_SYM_BS;
                            lclk_src.dat[i][0] <= 0;
                            
                            // Sublane 1
                            lclk_src.sym[i][1] <= TX_LNK_SYM_BF;
                            lclk_src.dat[i][1] <= 0;                           
                        end

                        // Valid
                        lclk_src.vld <= 1;
                    end

                    // BS phase 1 (SST)
                    else if (!lclk_ctl.mst && lclk_msa.bs_det[1])
                    begin
                        for (int i = 0; i < P_LANES; i++)
                        begin
                            // Sublane 0
                            lclk_src.sym[i][0] <= TX_LNK_SYM_BF;
                            lclk_src.dat[i][0] <= 0;
                            
                            // Sublane 3
                            lclk_src.sym[i][1] <= lclk_sr.sr_ins ? TX_LNK_SYM_SR : TX_LNK_SYM_BS;
                            lclk_src.dat[i][1] <= 0;
                        end

                        // Valid
                        lclk_src.vld <= 1;
                    end

                    // BS phase 2 (SST)
                    else if (!lclk_ctl.mst && lclk_msa.bs_det[2])
                    begin
                        for (int i = 0; i < P_LANES; i++)
                        begin
                            // Sublane 0
                            lclk_src.sym[i][0] <= TX_LNK_SYM_DAT;
                            lclk_src.dat[i][0] <= lclk_msa.vbid;
                            
                            // Sublane 1
                            lclk_src.sym[i][1] <= TX_LNK_SYM_DAT;
                            lclk_src.dat[i][1] <= (lclk_vid.run) ? {1'b0, lclk_mvid.val[7:0]} : 0;
                        end

                        // Valid
                        lclk_src.vld <= 1;
                    end

                    // BS phase 0 (MST)
                    else if (lclk_ctl.mst && lclk_msa.bs_det[0])
                    begin
                        for (int i = 0; i < P_LANES; i++)
                        begin
                            // Sublane 0
                            lclk_src.sym[i][0] <= TX_LNK_SYM_BS;
                            lclk_src.dat[i][0] <= 0;
                            
                            // Sublane 1
                            lclk_src.sym[i][1] <= TX_LNK_SYM_DAT;
                            lclk_src.dat[i][1] <= lclk_msa.vbid;
                        end

                        // Valid
                        lclk_src.vld <= 1;
                    end

                    // BS phase 1 (MST)
                    else if (lclk_ctl.mst && lclk_msa.bs_det[1])
                    begin
                        for (int i = 0; i < P_LANES; i++)
                        begin
                            // Sublane 0
                            lclk_src.sym[i][0] <= TX_LNK_SYM_DAT;
                            lclk_src.dat[i][0] <= (lclk_vid.run) ? {1'b0, lclk_mvid.val[7:0]} : 0;  // Mvid[7:0]
                            
                            // Sublane 1
                            lclk_src.sym[i][1] <= TX_LNK_SYM_DAT;
                            lclk_src.dat[i][1] <= 0;    // Maud[7:0]
                        end

                        // Valid
                        lclk_src.vld <= 1;
                    end

                    // Link sink 
                    else
                    begin
                        for (int i = 0; i < P_LANES; i++)
                        begin
                            for (int j = 0; j < P_SPL; j++)
                            begin
                                lclk_src.sym[i][j]  <= lclk_snk.sym[i][j];    
                                lclk_src.dat[i][j]  <= lclk_snk.dat[i][j];
                                lclk_src.vld        <= 1;
                            end
                        end
                    end
                end

                // Idle
                else
                    lclk_src.vld <= 0;
            end
        end
    end
endgenerate

// Scrambler reset
// Every 512th BS symbol is replaced with a SR symbol
// BS counter
// This logic is only needed in SST 
generate
    if (P_STREAM == 0)
    begin : gen_sr_bs_cnt
        always_ff @ (posedge LNK_RST_IN, posedge LNK_CLK_IN)
        begin
            // Reset
            if (LNK_RST_IN)
                lclk_sr.bs_cnt <= 0;

            else
            begin
                // Only in SST mode
                if (!lclk_ctl.mst)
                begin
                    // Clear
                    if (lclk_sr.bs_cnt == P_BS_CNT_MAX)
                        lclk_sr.bs_cnt <= 0;
                    
                    // Increment
                    else if (lclk_msa.bs_det[0])
                        lclk_sr.bs_cnt <= lclk_sr.bs_cnt + 'd1;
                end

                // MST
                else
                    lclk_sr.bs_cnt <= 0;
            end            
        end
    end

    else
        assign lclk_sr.bs_cnt = 0;
endgenerate

// SR insert flag
// This flag is asserted when the BS must be replaced by the SR
// This logic is only needed in SST 
generate
    if (P_STREAM == 0)
    begin : gen_sr_ins
        always_ff @ (posedge LNK_RST_IN, posedge LNK_CLK_IN)
        begin
            if (LNK_RST_IN)
                lclk_sr.sr_ins <= 0;
            
            else
            begin
                // Only in SST mode
                if (!lclk_ctl.mst)
                begin
                    // Clear
                    if (lclk_msa.bs_det[2])
                        lclk_sr.sr_ins <= 0;

                    // Set at 512 BS symbols
                    else if (lclk_sr.bs_cnt == (P_BS_CNT_MAX - 1))
                        lclk_sr.sr_ins <= 1;

                    // Set after video is enabled
                    else if (lclk_ctl.vid_en_re)
                        lclk_sr.sr_ins <= 1;

                    // Set after scrambler is enabled
                    else if (lclk_ctl.scrm_en_re)
                        lclk_sr.sr_ins <= 1;
                end

                // MST
                else
                    lclk_sr.sr_ins <= 0;
            end
        end
    end

    else
        assign lclk_sr.sr_ins = 0;
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
        for (j = 0; j < P_SPL; j++)
        begin
            assign LNK_SRC_IF.sym[i][j] = lclk_src.sym[i][j];
            assign LNK_SRC_IF.dat[i][j] = lclk_src.dat[i][j];
        end
    end
endgenerate
    assign LNK_SRC_IF.vld = lclk_src.vld;
    assign LNK_SNK_IF.rd  = lclk_src.rd;

endmodule

`default_nettype wire
