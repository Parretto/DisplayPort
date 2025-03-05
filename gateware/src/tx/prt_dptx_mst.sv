/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP TX Multi-Stream Transport (MST)
    (c) 2021 - 2025 by Parretto B.V.

    History
    =======
    v1.0 - Initial release

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

// Module
module prt_dptx_mst
#(
    // System
    parameter               P_VENDOR      = "none",  // Vendor - "AMD", "ALTERA" or "LSC"

    // Link
    parameter               P_LANES       = 4,      // Lanes
    parameter               P_SPL         = 2       // Symbols per lane
)
(
    // Reset and clock
    input wire              RST_IN,
    input wire              CLK_IN,

    // Control
    input wire              CTL_MST_EN_IN,          // MST enable
    input wire              CTL_MST_ACT_IN,         // MST ACT
    input wire [5:0]        CTL_VC0_TS_IN,          // Virtual channel0 time slots
    input wire [5:0]        CTL_VC1_TS_IN,          // Virtual channel1 time slots

    // Sink stream 0
    prt_dp_tx_lnk_if.snk    LNK0_SNK_IF,            // Sink0

    // Sink stream 1
    prt_dp_tx_lnk_if.snk    LNK1_SNK_IF,            // Sink1

    // Source 
    prt_dp_tx_lnk_if.src    LNK_SRC_IF              // Source
);

// Package
import prt_dp_pkg::*;

// Parameters
localparam P_VC = 2;        // Virtual channels
localparam P_TS_END = (P_SPL == 4) ? 15 : 31;
localparam P_VS_TS = (P_SPL == 4) ? 4 : 5;

// States
typedef enum {
    sm_act_idle, sm_act_init, sm_act_seq0, sm_act_seq1, sm_act_seq2, sm_act_seq3 
} sm_act_state;

// Structure
typedef struct {
    logic                           mst_en;
    logic                           mst_act;
    logic                           mst_act_re;
    logic [P_VS_TS-1:0]             vc_ts[0:P_VC-1];
} ctl_struct;

typedef struct {
    logic                           rd;                             // Read
    prt_dp_tx_lnk_sym               sym[0:P_LANES-1][0:P_SPL-1];    // Symbol
    logic   [7:0]                   dat[0:P_LANES-1][0:P_SPL-1];    // Data
    logic                           vld;                            // Valid
    logic                           rd_cnt_ld;
    logic   [P_VS_TS-1:0]           rd_cnt_in;
    logic   [P_VS_TS-1:0]           rd_cnt;
    logic                           rd_cnt_end;
    logic                           rd_cnt_last;
    logic   [7:0]                   vc_vld;
} snk_struct;

typedef struct {
    logic                           rd;                             // Read
    prt_dp_tx_lnk_sym               sym[0:P_LANES-1][0:P_SPL-1];    // Symbol
    logic   [7:0]                   dat[0:P_LANES-1][0:P_SPL-1];    // Data
    logic                           vld;                            // Valid
} src_struct;

typedef struct {
    sm_act_state                    sm_act_cur;
    sm_act_state                    sm_act_nxt;
    logic [4:0]                     ts_cnt;
    logic                           ts_cnt_end;
    logic                           ts_cnt_end_re;
    logic [9:0]                     mtp_cnt;
    logic                           mtph;
    logic                           sr;
    logic                           vcpf;  
    logic [7:0]                     snk_rd_str_cnt;
    logic                           snk_rd_str_cnt_end;
    logic                           snk_rd_str_cnt_end_re;
    logic                           act_ts;
    logic [1:0]                     act;
    logic                           vc_ts_ld;
} mst_struct;

// Signals
ctl_struct          clk_ctl;
snk_struct          clk_snk[0:P_VC-1];
src_struct          clk_src;
mst_struct          clk_mst;

genvar i, j;

// Control Inputs
    always_ff @ (posedge CLK_IN)
    begin
        clk_ctl.mst_en      <= CTL_MST_EN_IN;
        clk_ctl.mst_act     <= CTL_MST_ACT_IN;
    end

// VC time slots
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_ctl.mst_en)
        begin
            // The VC time slots are latched by the ACT state machine
            if (clk_mst.vc_ts_ld)
            begin
                // The VC time slot is compensated for the symbols per lane
                clk_ctl.vc_ts[0] <= (P_SPL == 4) ? CTL_VC0_TS_IN[2+:P_VS_TS] : CTL_VC0_TS_IN[1+:P_VS_TS];
                clk_ctl.vc_ts[1] <= (P_SPL == 4) ? CTL_VC1_TS_IN[2+:P_VS_TS] : CTL_VC1_TS_IN[1+:P_VS_TS];
            end
        end

        // Idle
        else
        begin
            clk_ctl.vc_ts[0] <= 0;
            clk_ctl.vc_ts[1] <= 0;
        end
    end

// MST ACT risign edge detector
// This is used to start the ACT state machine
    prt_dp_lib_edge
    MST_ACT_EDGE_INST
    (
        .CLK_IN    (CLK_IN),                // Clock
        .CKE_IN    (1'b1),                  // Clock enable
        .A_IN      (clk_ctl.mst_act),       // Input
        .RE_OUT    (clk_ctl.mst_act_re),    // Rising edge
        .FE_OUT    ()                       // Falling edge
    );

// Link sink inputs
// Must be combinatorial
generate    
    for (i = 0; i < P_LANES; i++)
    begin
        for (j = 0; j < P_SPL; j++)
        begin
            // Sink 0
            assign clk_snk[0].sym[i][j] = prt_dp_tx_lnk_sym'(LNK0_SNK_IF.sym[i][j]);
            assign clk_snk[0].dat[i][j] = LNK0_SNK_IF.dat[i][j];
            
            // Sink 1
            assign clk_snk[1].sym[i][j] = prt_dp_tx_lnk_sym'(LNK1_SNK_IF.sym[i][j]);
            assign clk_snk[1].dat[i][j] = LNK1_SNK_IF.dat[i][j];
        end
    end
endgenerate
    assign clk_snk[0].vld = LNK0_SNK_IF.vld;
    assign clk_snk[1].vld = LNK1_SNK_IF.vld;

// Link sink read 
generate
    for (i = 0; i < P_VC; i++)    
    begin : gen_snk_rd_cnt
    
        // Read counter
        always_ff @ (posedge CLK_IN)
        begin
            // Run
            if (clk_ctl.mst_en)
            begin
                // Load
                if (clk_snk[i].rd_cnt_ld)
                    clk_snk[i].rd_cnt <= clk_snk[i].rd_cnt_in;

                // Decrement
                else if (!clk_snk[i].rd_cnt_end)
                    clk_snk[i].rd_cnt <= clk_snk[i].rd_cnt - 'd1;
            end

            else
                clk_snk[i].rd_cnt <= 0;
        end

        // Read counter end
        always_comb
        begin
            if (clk_snk[i].rd_cnt == 0)
                clk_snk[i].rd_cnt_end = 1;
            else
                clk_snk[i].rd_cnt_end = 0;
        end

        // Read counter last
        always_comb
        begin
            if (clk_snk[i].rd_cnt == 'd1)
                clk_snk[i].rd_cnt_last = 1;
            else
                clk_snk[i].rd_cnt_last = 0;
        end

        always_ff @ (posedge CLK_IN)
        begin
            // MST
            if (clk_ctl.mst_en)
            begin
                // Default
                clk_snk[i].rd <= 0;

                // Active
                if (!clk_snk[i].rd_cnt_end)
                    clk_snk[i].rd <= 1;
            end

            // SST
            else
            begin
                if (i == 0)
                    clk_snk[i].rd <= 1;
                else
                    clk_snk[i].rd <= 0;
            end
        end
    end
endgenerate

// Read counter sink 0
    assign clk_snk[0].rd_cnt_ld = clk_mst.snk_rd_str_cnt_end_re;
    assign clk_snk[0].rd_cnt_in = clk_ctl.vc_ts[0];

// Read counter sink 1
    assign clk_snk[1].rd_cnt_ld = clk_snk[0].rd_cnt_last;
    assign clk_snk[1].rd_cnt_in = clk_ctl.vc_ts[1];

// Sink read start counter 
// The sinks have a (long) read latency. 
// To align the valid data from the sink with the MTP header, the sink read counters are delayed. 
    always_ff @ (posedge CLK_IN)
    begin
        // MST
        if (clk_ctl.mst_en)
        begin
            // Load
            if (clk_mst.mtph)
                clk_mst.snk_rd_str_cnt <= 'd22;

            // Decrement
            else if (!clk_mst.snk_rd_str_cnt_end)
                clk_mst.snk_rd_str_cnt <= clk_mst.snk_rd_str_cnt - 'd1;
        end

        // Idle
        else
            clk_mst.snk_rd_str_cnt <= 0;
    end

// Sink read start counter end
    always_comb
    begin
        if (clk_mst.snk_rd_str_cnt == 0)
            clk_mst.snk_rd_str_cnt_end = 1;
        else
            clk_mst.snk_rd_str_cnt_end = 0;
    end

// Sink read start counter end detector
// This is used to start the sink read counters
    prt_dp_lib_edge
    SNK_RD_STR_CNT_END_EDGE_INST
    (
        .CLK_IN    (CLK_IN),                        // Clock
        .CKE_IN    (1'b1),                          // Clock enable
        .A_IN      (clk_mst.snk_rd_str_cnt_end),    // Input
        .RE_OUT    (clk_mst.snk_rd_str_cnt_end_re), // Rising edge
        .FE_OUT    ()                               // Falling edge
    );

// ACT time slot
// This flag is asserted when the ACT sequence is allowed. 
// The sequence is prohibited in the time slots 36 time slots prior the SR till 34 time slots following SR 
    always_ff @ (posedge CLK_IN)
    begin
        if ((clk_mst.mtp_cnt > 'd34) && (clk_mst.mtp_cnt < 'd983))
            clk_mst.act_ts <= 1;
        else
            clk_mst.act_ts <= 0;
    end

// ACT State machine
// This state machine is responsible for generating the ACT sequence
    always_ff @ (posedge RST_IN, posedge CLK_IN)
    begin
        // Reset
        if (RST_IN)
            clk_mst.sm_act_cur <= sm_act_idle;
        
        else
        begin
            // At start force the state machine to start
            if (clk_ctl.mst_act_re)
                clk_mst.sm_act_cur <= sm_act_init;

            else
                clk_mst.sm_act_cur <= clk_mst.sm_act_nxt;
        end        
    end

// State machine decoder
    always_comb
    begin
        // Default
        clk_mst.act = 0;
        clk_mst.vc_ts_ld = 0;
        
        case (clk_mst.sm_act_cur)
        
            sm_act_idle : 
            begin
                clk_mst.sm_act_nxt = sm_act_idle;
            end

            sm_act_init : 
            begin
                // Wait for valid time slot
                if (clk_mst.act_ts)
                    clk_mst.sm_act_nxt = sm_act_seq0;
                else
                    clk_mst.sm_act_nxt = sm_act_init;
            end

            // ACT0
            sm_act_seq0 :
            begin
                // Insert ACT C0
                clk_mst.act[0] = 1;
                
                // Wait for MTP header
                if (clk_mst.mtph)
                    clk_mst.sm_act_nxt = sm_act_seq1;
                else
                    clk_mst.sm_act_nxt = sm_act_seq0;
            end

            // ACT1
            sm_act_seq1 :
            begin
                // Insert ACT C1
                clk_mst.act[1] = 1;
                
                // Wait for MTP header
                if (clk_mst.mtph)
                    clk_mst.sm_act_nxt = sm_act_seq2;
                else
                    clk_mst.sm_act_nxt = sm_act_seq1;
            end

            // ACT2
            sm_act_seq2 :
            begin
                // Insert ACT C1
                clk_mst.act[1] = 1;
                
                // Wait for MTP header
                if (clk_mst.mtph)
                    clk_mst.sm_act_nxt = sm_act_seq3;
                else
                    clk_mst.sm_act_nxt = sm_act_seq2;
            end

            // ACT1
            sm_act_seq3 :
            begin
                // Insert ACT C0
                clk_mst.act[0] = 1;               

                // Wait for MTP header
                if (clk_mst.mtph)
                begin
                    // Load virtual channel time slots
                    clk_mst.vc_ts_ld = 1;
                    clk_mst.sm_act_nxt = sm_act_idle;
                end

                else
                    clk_mst.sm_act_nxt = sm_act_seq3;
            end

            default : 
            begin
                clk_mst.sm_act_nxt = sm_act_idle;
            end

        endcase
    end

// Time slot counter
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_ctl.mst_en)
        begin
            // Overflow
            if (clk_mst.ts_cnt_end)
                clk_mst.ts_cnt <= 0;

            else
                clk_mst.ts_cnt <= clk_mst.ts_cnt + 'd1;
        end

        // Idle
        // We want to start the MST stream with a SR. 
        // The header appears in the last time slot (see MTP header flag description)
        else
            clk_mst.ts_cnt <= P_TS_END-1;
    end

// Time slot counter end
    always_comb
    begin
        if (clk_mst.ts_cnt == P_TS_END)
            clk_mst.ts_cnt_end = 1;
        else
            clk_mst.ts_cnt_end = 0;
    end

// Time slot counter end detector
// This is used to increment the MTP counter
    prt_dp_lib_edge
    TS_CNT_END_EDGE_INST
    (
        .CLK_IN    (CLK_IN),                // Clock
        .CKE_IN    (1'b1),                  // Clock enable
        .A_IN      (clk_mst.ts_cnt_end),    // Input
        .RE_OUT    (clk_mst.ts_cnt_end_re), // Rising edge
        .FE_OUT    ()                       // Falling edge
    );

// MTP counter
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_ctl.mst_en)
        begin
            // Increment
            if (clk_mst.ts_cnt_end_re)
            begin
                // Overflow
                if (clk_mst.mtp_cnt == 'd1023)
                    clk_mst.mtp_cnt <= 0;

                else
                    clk_mst.mtp_cnt <= clk_mst.mtp_cnt + 'd1;
            end
        end

        // Idle
        // We want to start the MST stream with a SR. 
        // The header appears in the last time slot (see MTP header flag description)
        // The SR appears in the last MTP in the last time slot
        // See MTP header flag description 
        else
            clk_mst.mtp_cnt <= 'd1023;
    end

// VC payload Fill insert
// When there are no stream symbols to transmit while the link is enabled,
// then the VCPF symbol sequence is transmitted.
// Must be combinatotial
    always_comb
    begin
        // Run
        if (clk_ctl.mst_en)
        begin
            // Default
            clk_mst.vcpf = 0;

            for (int i = 0; i < P_VC; i++)
            begin
                // Generate VCPF when there is no sink valid while the virtual valid is asserted
                if (!clk_snk[i].vld && clk_snk[i].vc_vld[$high(clk_snk[i].vc_vld)])
                    clk_mst.vcpf = 1;
            end
        end

        // SST
        else
            clk_mst.vcpf = 0;
    end

// MTP header
// This flag is asserted when the MTP header is active 
// We process 4 time slots per clock and the header is only a single time slot.
// To overcome this issue we re-allocate the header in last sublane of the last time slot, just before the VC data begins.
// The sink device will interpret this as the header is allocated in the first time slot. 
// Must be combinatorial
    always_comb
    begin
        if (clk_mst.ts_cnt == P_TS_END)
            clk_mst.mtph = 1;
        else
            clk_mst.mtph = 0;
    end

// Scrambler reset
// The SR will appear in the last time slot of the last mtp. 
// See MTP header description. 
// Must be combinatorial
    always_comb
    begin
        if (clk_mst.mtph && (clk_mst.mtp_cnt == 'd1023))
            clk_mst.sr = 1;
        else
            clk_mst.sr = 0;
    end
 
// Link source
    always_ff @ (posedge CLK_IN)
    begin
        // MST
        if (clk_ctl.mst_en)
        begin
            // Default
            for (int i = 0; i < P_LANES; i++)
            begin
                for (int j = 0; j < P_SPL; j++)
                begin
                    clk_src.sym[i][j] <= TX_LNK_SYM_NOP;
                    clk_src.dat[i][j] <= 0;
                end
            end

            // MTP header
            if (clk_mst.mtph)
            begin
                // The header is one time slot.
                // In four sublanes four time slots are transmitted in parrallel.
                // Similar two time slots are transmitted in the same clock cycle in two sublanes.
                // Fill time slots 63 (2 spl) / 61-63 (4 spl) with the VC payload fill sequence.
                // Else the time slots will be filled with data 0x00.

                // Scrambler reset
                if (clk_mst.sr)
                begin
                    // Only last sublane
                    for (int i = 0; i < P_LANES; i++)
                        clk_src.sym[i][P_SPL-1] <= TX_LNK_SYM_MTPH_SR;
                end

                // ACT C0
                else if (clk_mst.act[0])
                begin
                    // Only last sublane
                    for (int i = 0; i < P_LANES; i++)
                        clk_src.sym[i][P_SPL-1] <= TX_LNK_SYM_C0; // ACT C0
                end

                // ACT C1
                else if (clk_mst.act[1])
                begin
                    // Only last sublane
                    for (int i = 0; i < P_LANES; i++)
                        clk_src.sym[i][P_SPL-1] <= TX_LNK_SYM_C1; // ACT C1
                end

                // NOP
                else
                begin
                    // Only last sublane
                    for (int i = 0; i < P_LANES; i++)
                        clk_src.sym[i][P_SPL-1] <= TX_LNK_SYM_MTPH_NOP;
                end
            end

            // Stream 0
            if (clk_snk[0].vld)
            begin
                for (int i = 0; i < P_LANES; i++)
                begin
                    for (int j = 0; j < P_SPL; j++)
                    begin
                        clk_src.sym[i][j] <= clk_snk[0].sym[i][j];
                        clk_src.dat[i][j] <= clk_snk[0].dat[i][j];
                    end
                end
            end

            // Stream 1
            else if (clk_snk[1].vld)
            begin
                for (int i = 0; i < P_LANES; i++)
                begin
                    for (int j = 0; j < P_SPL; j++)
                    begin
                        clk_src.sym[i][j] <= clk_snk[1].sym[i][j];
                        clk_src.dat[i][j] <= clk_snk[1].dat[i][j];
                    end
                end
            end

            // VCPF
            // This must be lowest priority
            else if (clk_mst.vcpf)
            begin
                for (int j = 0; j < P_SPL; j++)
                begin
                    clk_src.sym[0][j] <= TX_LNK_SYM_C0;     // VC Payload Fill Control
                    clk_src.sym[1][j] <= TX_LNK_SYM_C1;     // VC Payload Fill Control
                    clk_src.sym[2][j] <= TX_LNK_SYM_C2;     // VC Payload Fill Control
                    clk_src.sym[3][j] <= TX_LNK_SYM_C3;     // VC Payload Fill Control
                end
            end
        end

        // SST
        else
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                for (int j = 0; j < P_SPL; j++)
                begin
                    clk_src.sym[i][j] <= clk_snk[0].sym[i][j];
                    clk_src.dat[i][j] <= clk_snk[0].dat[i][j];
                end
            end
        end
    end

// Source valid
    always_ff @ (posedge CLK_IN)
    begin
        // Enable
        if (clk_ctl.mst_en)
            clk_src.vld <= 1;
        else
            clk_src.vld <= 0;
    end

// Virtual valid
// After the virtual time slots are set and the ACT is triggered and before the video stream is enabled, 
// the active VC time slots are filled with the VCPF symbol.
// This valid signal is the delayed read signal and it used to generate the VCPF in this specific time slots.  
generate
    for (i = 0; i < P_VC; i++)
    begin
        always_ff @ (posedge CLK_IN)
        begin
            // Run
            if (clk_ctl.mst_en)
                clk_snk[i].vc_vld <= {clk_snk[i].vc_vld[$high(clk_snk[i].vc_vld)-1:0], clk_snk[i].rd};

            // Idle
            else
                clk_snk[i].vc_vld <= 0;
        end
    end
endgenerate

// Outputs
    assign LNK0_SNK_IF.rd = clk_snk[0].rd;
    assign LNK1_SNK_IF.rd = clk_snk[1].rd;

generate
    for (i = 0; i < P_LANES; i++)
    begin
        for (j = 0; j < P_SPL; j++)
        begin
            assign LNK_SRC_IF.sym[i][j] = clk_src.sym[i][j];   // Symbol
            assign LNK_SRC_IF.dat[i][j] = clk_src.dat[i][j];   // Data
        end
    end
endgenerate
    assign LNK_SRC_IF.vld = clk_src.vld;

endmodule

`default_nettype wire
