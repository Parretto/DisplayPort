/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP RX Main Stream Attribute (msa)
    (c) 2021 - 2024 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Added support for single lane

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

module prt_dprx_msa
#(
    // System
    parameter               P_VENDOR      = "none",  // Vendor "xilinx" or "lattice"

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
    input wire              RST_IN,         // Reset
    input wire              CLK_IN,         // Clock

    // Control
    input wire  [1:0]       CTL_LANES_IN,   // Active lanes (1 - 1 lane / 2 - 2 lanes / 3 - 4 lanes)

    // Message
    prt_dp_msg_if.snk       MSG_SNK_IF,     // Sink
    prt_dp_msg_if.src       MSG_SRC_IF,     // Source

    // Link
    prt_dp_rx_lnk_if.snk    LNK_SNK_IF,     // Sink    
    prt_dp_rx_lnk_if.src    LNK_SRC_IF,     // Source

    // Interrupt
    output wire             IRQ_OUT         
);

// Package
import prt_dp_pkg::*;

// Localparam
localparam P_RAM_WRDS = (P_SPL == 4) ? 16 : 32;
localparam P_RAM_ADR = $clog2(P_RAM_WRDS);
localparam P_RAM_DAT = 8;
localparam P_LOG_LANES = $clog2(P_LANES * P_SPL);

// Structure
typedef struct {
    logic   [P_MSG_IDX-1:0]         idx;
    logic                           first;
    logic                           last;
    logic   [P_MSG_DAT-1:0]         dat;
    logic                           ack;
} msg_struct;

typedef struct {
    logic   [P_RAM_ADR-1:0]     wp[0:P_LANES-1][0:P_SPL-1];     // Write pointer
    logic   [P_SPL-1:0]         wr[0:P_LANES-1];                // Write
    logic   [P_RAM_DAT-1:0]     din[0:P_LANES-1][0:P_SPL-1];    // Write data
    logic   [P_RAM_ADR-1:0]     rp[0:P_LANES-1][0:P_SPL-1];     // Read pointer
    logic   [P_SPL-1:0]         rd[0:P_LANES-1];                // Read
    logic   [P_RAM_DAT-1:0]     dout[0:P_LANES-1][0:P_SPL-1];   // Read data
} ram_struct;

typedef struct {
    logic   [1:0]               lanes;                          // Active lanes
    logic                       lock;                           // Lock
    logic   [P_SPL-1:0]         sol[0:P_LANES-1];               // Start of line
    logic   [P_SPL-1:0]         eol[0:P_LANES-1];               // End of line
    logic   [P_SPL-1:0]         vid[0:P_LANES-1];               // Video packet
    logic   [P_SPL-1:0]         sec[0:P_LANES-1];               // Secondary packet
    logic   [P_SPL-1:0]         msa[0:P_LANES-1];               // Main stream attributes (msa)
    logic   [P_SPL-1:0]         vbid[0:P_LANES-1];              // VB-ID
    logic   [P_SPL-1:0]         k[0:P_LANES-1];                 // k character
    logic   [7:0]               dat[0:P_LANES-1][0:P_SPL-1];    // Data
} lnk_struct;

typedef struct {
    logic   [P_LANES-1:0]       sop;
    logic   [P_LANES-1:0]       eop;
    logic   [1:0]               ph[P_LANES-1:0];
    logic   [P_SPL-1:0]         rd[0:P_LANES-1];                // Read
    logic   [7:0]               dat[0:P_LANES-1][0:P_SPL-1];
    logic   [P_LANES-1:0]       irq_lane;
    logic                       irq_all;
} msa_struct;

// Signals
msg_struct          clk_msg;    // Message
ram_struct          clk_ram;    // RAM
lnk_struct          clk_lnk;    // Link
msa_struct          clk_msa;    // MSA

genvar i, j;

// Config
    always_ff @ (posedge CLK_IN)
    begin
        clk_lnk.lanes <= CTL_LANES_IN;
    end

// Inputs
// Combinatorial
    always_comb
    begin
        clk_lnk.lock = LNK_SNK_IF.lock;             // Lock
        
        for (int i = 0; i < P_LANES; i++)
        begin
            clk_lnk.sol[i]  = LNK_SNK_IF.sol[i];     // Start of line
            clk_lnk.eol[i]  = LNK_SNK_IF.eol[i];     // End of line
            clk_lnk.vid[i]  = LNK_SNK_IF.vid[i];     // Video
            clk_lnk.sec[i]  = LNK_SNK_IF.sec[i];     // Secondary
            clk_lnk.msa[i]  = LNK_SNK_IF.msa[i];     // MSA
            clk_lnk.vbid[i] = LNK_SNK_IF.vbid[i];    // VB-ID
            clk_lnk.k[i]    = LNK_SNK_IF.k[i];       // k character
            clk_lnk.dat[i]  = LNK_SNK_IF.dat[i];     // Data
        end
    end

// Message Slave Ingress
    prt_dp_msg_slv_ing
    #(
        .P_ID           (P_MSG_ID_MSA),   // Identifier
        .P_IDX_WIDTH    (P_MSG_IDX),      // Index width
        .P_DAT_WIDTH    (P_MSG_DAT)       // Data width
    )
    MSG_SLV_ING_INST
    (
        // Reset and clock
        .RST_IN         (RST_IN),
        .CLK_IN         (CLK_IN),

        // MSG sink
        .MSG_SNK_IF     (MSG_SNK_IF),

        // MSG source
        .MSG_SRC_IF     (MSG_SRC_IF),

        // Inggress
        .ING_IDX_OUT    (clk_msg.idx),       // Index
        .ING_FIRST_OUT  (clk_msg.first),     // First
        .ING_LAST_OUT   (clk_msg.last),      // Last
        .ING_DAT_IN     (clk_msg.dat),       // Data
        .ING_ACK_OUT    (clk_msg.ack)
    );

generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_ram
        for (j = 0; j < P_SPL; j++)
        begin
            prt_dp_lib_sdp_ram_sc
            #(
                .P_VENDOR       (P_VENDOR),         // Vendor
                .P_RAM_STYLE    ("distributed"),    // "distributed", "block" or "ultra"
                .P_ADR_WIDTH    (P_RAM_ADR),
                .P_DAT_WIDTH    (P_RAM_DAT)
            )
            RAM_INST
            (
                // Clocks and reset
                .RST_IN     (RST_IN),              // Reset
                .CLK_IN     (CLK_IN),              // Clock

                // Port A
                .A_ADR_IN   (clk_ram.wp[i][j]),    // Write pointer
                .A_WR_IN    (clk_ram.wr[i][j]),    // Write in
                .A_DAT_IN   (clk_ram.din[i][j]),   // Write data

                // Port B
                .B_EN_IN    (1'b1),                // Enable
                .B_ADR_IN   (clk_ram.rp[i][j]),    // Read pointer
                .B_RD_IN    (clk_ram.rd[i][j]),    // Read in
                .B_DAT_OUT  (clk_ram.dout[i][j]),  // Data out
                .B_VLD_OUT  ()                     // Valid
            );
        end
    end
endgenerate

// Ingress data
// Must be combinatorial
generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_msg_dat_4spl
        always_comb
        begin
            // 4 lanes
            if (clk_lnk.lanes == 'd3)
            begin
                case (clk_msg.idx[2:0])
                    'd1     : clk_msg.dat = {clk_msa.dat[2][0], clk_msa.dat[3][0]}; // Lane 2 Sublane 0 / Lane 3 Sublane 0
                    'd2     : clk_msg.dat = {clk_msa.dat[0][1], clk_msa.dat[1][1]}; // Lane 0 Sublane 1 / Lane 1 Sublane 1
                    'd3     : clk_msg.dat = {clk_msa.dat[2][1], clk_msa.dat[3][1]}; // Lane 2 Sublane 1 / Lane 3 Sublane 1
                    'd4     : clk_msg.dat = {clk_msa.dat[0][2], clk_msa.dat[1][2]}; // Lane 0 Sublane 2 / Lane 1 Sublane 2
                    'd5     : clk_msg.dat = {clk_msa.dat[2][2], clk_msa.dat[3][2]}; // Lane 2 Sublane 2 / Lane 3 Sublane 2
                    'd6     : clk_msg.dat = {clk_msa.dat[0][3], clk_msa.dat[1][3]}; // Lane 0 Sublane 3 / Lane 1 Sublane 3
                    'd7     : clk_msg.dat = {clk_msa.dat[2][3], clk_msa.dat[3][3]}; // Lane 2 Sublane 3 / Lane 3 Sublane 3
                    default : clk_msg.dat = {clk_msa.dat[0][0], clk_msa.dat[1][0]}; // Lane 0 Sublane 0 / Lane 1 Sublane 0
                endcase
            end

            // 2 lanes
            else if (clk_lnk.lanes == 'd2)
            begin
                case (clk_msg.idx[1:0])
                    'd1     : clk_msg.dat = {clk_msa.dat[0][1], clk_msa.dat[1][1]}; // Lane 0 Sublane 1 / Lane 1 Sublane 1
                    'd2     : clk_msg.dat = {clk_msa.dat[0][2], clk_msa.dat[1][2]}; // Lane 0 Sublane 2 / Lane 1 Sublane 2
                    'd3     : clk_msg.dat = {clk_msa.dat[0][3], clk_msa.dat[1][3]}; // Lane 0 Sublane 3 / Lane 1 Sublane 3
                    default : clk_msg.dat = {clk_msa.dat[0][0], clk_msa.dat[1][0]}; // Lane 0 Sublane 0 / Lane 1 Sublane 0
                endcase
            end

            // 1 lane
            else
            begin
                if (clk_msg.idx[0])
                    clk_msg.dat = {clk_msa.dat[0][2], clk_msa.dat[0][3]}; // Lane 0 Sublane 2 / Lane 0 Sublane 3
                else
                    clk_msg.dat = {clk_msa.dat[0][0], clk_msa.dat[0][1]}; // Lane 0 Sublane 0 / Lane 0 Sublane 1
            end
        end
    end

    // Two symbols per lane
    else
    begin : gen_msg_dat_2spl
        always_comb
        begin
            // 4 lanes
            if (clk_lnk.lanes == 'd3)
            begin
                case (clk_msg.idx[1:0])
                    'd1     : clk_msg.dat = {clk_msa.dat[2][0], clk_msa.dat[3][0]}; // Lane 2 Sublane 0 / Lane 3 Sublane 0
                    'd2     : clk_msg.dat = {clk_msa.dat[0][1], clk_msa.dat[1][1]}; // Lane 0 Sublane 1 / Lane 1 Sublane 1
                    'd3     : clk_msg.dat = {clk_msa.dat[2][1], clk_msa.dat[3][1]}; // Lane 2 Sublane 1 / Lane 3 Sublane 1
                    default : clk_msg.dat = {clk_msa.dat[0][0], clk_msa.dat[1][0]}; // Lane 0 Sublane 0 / Lane 1 Sublane 0
                endcase
            end

            // 2 lanes
            else if (clk_lnk.lanes == 'd2)
            begin
                if (clk_msg.idx[0])
                    clk_msg.dat = {clk_msa.dat[0][1], clk_msa.dat[1][1]}; // Lane 0 Sublane 1 / Lane 1 Sublane 1
                else
                    clk_msg.dat = {clk_msa.dat[0][0], clk_msa.dat[1][0]}; // Lane 0 Sublane 0 / Lane 1 Sublane 0
            end

            // 1 lane
            else
            begin
                clk_msg.dat = {clk_msa.dat[0][0], clk_msa.dat[0][1]}; // Lane 0 Sublane 0 / Lane 0 Sublane 1
            end
        end
    end
endgenerate

// MSA read 
generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_msa_rd_4spl
        always_ff @ (posedge CLK_IN)
        begin
            // Default
            for (int i = 0; i < P_LANES; i++)
            begin
                for (int j = 0; j < P_SPL; j++)
                    clk_msa.rd[i][j] <= 0;
            end

            // Wait for acknowledge
            if (clk_msg.ack)
            begin
                // 4 lanes
                if (clk_lnk.lanes == 'd3)
                begin

                    case (clk_msg.idx[2:0])

                        'd1 : 
                        begin
                            clk_msa.rd[2][0] <= 1; // Lane 2 Sublane 0
                            clk_msa.rd[3][0] <= 1; // Lane 3 Sublane 0
                        end

                        'd2 : 
                        begin
                            clk_msa.rd[0][1] <= 1; // Lane 0 Sublane 1 
                            clk_msa.rd[1][1] <= 1; // Lane 1 Sublane 1
                        end

                        'd3 : 
                        begin
                            clk_msa.rd[2][1] <= 1; // Lane 2 Sublane 1
                            clk_msa.rd[3][1] <= 1; // Lane 3 Sublane 1
                        end

                        'd4 :
                        begin
                            clk_msa.rd[0][2] <= 1; // Lane 0 Sublane 2 
                            clk_msa.rd[1][2] <= 1; // Lane 1 Sublane 2
                        end

                        'd5 :
                        begin
                            clk_msa.rd[2][2] <= 1; // Lane 2 Sublane 2
                            clk_msa.rd[3][2] <= 1; // Lane 3 Sublane 2
                        end

                        'd6 : 
                        begin
                            clk_msa.rd[0][3] <= 1; // Lane 0 Sublane 3 
                            clk_msa.rd[1][3] <= 1; // Lane 1 Sublane 3 
                        end

                        'd7 :
                        begin
                            clk_msa.rd[2][3] <= 1; // Lane 2 Sublane 3 
                            clk_msa.rd[3][3] <= 1; // Lane 3 Sublane 3 
                        end

                        default : 
                        begin
                            clk_msa.rd[0][0] <= 1; // Lane 0 Sublane 0 
                            clk_msa.rd[1][0] <= 1; // Lane 1 Sublane 0 
                        end
                    endcase
                end

                // 2 lanes
                else if (clk_lnk.lanes == 'd2)
                begin

                    case (clk_msg.idx[1:0])

                        'd1 : 
                        begin
                            clk_msa.rd[0][1] <= 1; // Lane 0 Sublane 1 
                            clk_msa.rd[1][1] <= 1; // Lane 1 Sublane 1
                        end

                        'd2 :
                        begin
                            clk_msa.rd[0][2] <= 1; // Lane 0 Sublane 2 
                            clk_msa.rd[1][2] <= 1; // Lane 1 Sublane 2
                        end

                        'd3 : 
                        begin
                            clk_msa.rd[0][3] <= 1; // Lane 0 Sublane 3 
                            clk_msa.rd[1][3] <= 1; // Lane 1 Sublane 3 
                        end

                        default : 
                        begin
                            clk_msa.rd[0][0] <= 1; // Lane 0 Sublane 0 
                            clk_msa.rd[1][0] <= 1; // Lane 1 Sublane 0 
                        end
                    endcase
                end

                // 1 lane
                else
                begin
                    if (clk_msg.idx[0])
                    begin
                        clk_msa.rd[0][2] <= 1; // Lane 0 Sublane 2 
                        clk_msa.rd[0][3] <= 1; // Lane 0 Sublane 3
                    end
                    else
                    begin
                        clk_msa.rd[0][0] <= 1; // Lane 0 Sublane 0 
                        clk_msa.rd[0][1] <= 1; // Lane 0 Sublane 1
                    end
                end
            end
        end
    end

    // Two symbols per lane
    else
    begin : gen_msa_rd_2spl
        always_ff @ (posedge CLK_IN)
        begin
            // Default
            for (int i = 0; i < P_LANES; i++)
            begin
                for (int j = 0; j < P_SPL; j++)
                    clk_msa.rd[i][j] <= 0;
            end

            if (clk_msg.ack)
            begin
                // 4 lanes
                if (clk_lnk.lanes == 'd3)
                begin
                    case (clk_msg.idx[1:0])
                        'd1 : 
                        begin
                            clk_msa.rd[2][0] <= 1; // Lane 2 Sublane 0
                            clk_msa.rd[3][0] <= 1; // Lane 3 Sublane 0
                        end

                        'd2 : 
                        begin
                            clk_msa.rd[0][1] <= 1; // Lane 0 Sublane 1 
                            clk_msa.rd[1][1] <= 1; // Lane 1 Sublane 1
                        end

                        'd3 : 
                        begin
                            clk_msa.rd[2][1] <= 1; // Lane 2 Sublane 1
                            clk_msa.rd[3][1] <= 1; // Lane 3 Sublane 1
                        end

                        default : 
                        begin
                            clk_msa.rd[0][0] <= 1; // Lane 0 Sublane 0 
                            clk_msa.rd[1][0] <= 1; // Lane 1 Sublane 0 
                        end
                    endcase
                end

                // 2 lanes
                else if (clk_lnk.lanes == 'd2)
                begin
                    if (clk_msg.idx[0])
                    begin
                        clk_msa.rd[0][1] <= 1; // Lane 0 Sublane 1 
                        clk_msa.rd[1][1] <= 1; // Lane 1 Sublane 1
                    end

                    else
                    begin
                        clk_msa.rd[0][0] <= 1; // Lane 0 Sublane 0 
                        clk_msa.rd[1][0] <= 1; // Lane 1 Sublane 0
                    end
                end

                // 1 lane
                else
                begin
                    clk_msa.rd[0][0] <= 1; // Lane 0 Sublane 0 
                    clk_msa.rd[0][1] <= 1; // Lane 0 Sublane 1
                end
            end
        end
    end
endgenerate

// Write pointer
    always_ff @ (posedge CLK_IN)
    begin
        for (int i = 0; i < P_LANES; i++)
        begin
            for (int j = 0; j < P_SPL; j++)
            begin
                // Increment 
                if (clk_ram.wr[i][j])
                    clk_ram.wp[i][j] <= clk_ram.wp[i][j] + 'd1;

                // Clear
                else
                    clk_ram.wp[i][j] <= 0;
            end
        end
    end

// Write data
generate
    for (i = 0; i < P_LANES; i++)
    begin
        for (j = 0; j < P_SPL; j++)
            assign clk_ram.din[i][j] = clk_lnk.dat[i][j];   // Only data. The k symbols are not required
    end
endgenerate

// Write
    always_comb
    begin
        for (int i = 0; i < P_LANES; i++)
        begin 
            for (int j = 0; j < P_SPL; j++)
            begin
                if (clk_lnk.msa[i][j])
                    clk_ram.wr[i][j] = 1;
                else
                    clk_ram.wr[i][j] = 0;
            end
        end                
    end

// Read pointer
    always_ff @ (posedge CLK_IN)
    begin
        for (int i = 0; i < P_LANES; i++)
        begin
            for (int j = 0; j < P_SPL; j++)
            begin
                // Clear
                // At the end of a packet
                if (clk_msa.eop[i])
                    clk_ram.rp[i][j] <= 0;

                // Increment
                else if (clk_ram.rd[i][j])
                    clk_ram.rp[i][j] <= clk_ram.rp[i][j] + 'd1;
            end
        end
    end

// MSA edge detector
// The rising edge is used to detect the incoming phase
// The failing edge of the msa is used to generate an end of packet
generate
    for (i = 0; i < P_LANES; i++)
    begin
        prt_dp_lib_edge
        MSA_EDGE_INST
        (
            .CLK_IN     (CLK_IN),           // Clock
            .CKE_IN     (1'b1),             // Clock enable
            .A_IN       (|clk_lnk.msa[i]),  // Input
            .RE_OUT     (clk_msa.sop[i]),   // Rising edge
            .FE_OUT     (clk_msa.eop[i])    // Falling edge
        );
    end
endgenerate

// Phase
generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_phase_4spl
    
        always_ff @ (posedge CLK_IN)
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                if (clk_msa.sop[i])
                begin
                    if (clk_lnk.msa[i] == 'b1110)
                        clk_msa.ph[i] <= 'd1;     // Phase 1

                    else if (clk_lnk.msa[i] == 'b1100)
                        clk_msa.ph[i] <= 'd2;     // Phase 2

                    else if (clk_lnk.msa[i] == 'b1000)
                        clk_msa.ph[i] <= 'd3;     // Phase 3

                    else
                        clk_msa.ph[i] <= 'd0;     // Phase 0
                end                
            end
        end
    end

    // Two symbols per lane
    else
    begin : gen_phase_2spl
        always_ff @ (posedge CLK_IN)
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                if (clk_msa.sop[i])
                begin
                    if (clk_lnk.msa[i] == 'b10)
                        clk_msa.ph[i] <= 'd1;     // Phase 1

                    else
                        clk_msa.ph[i] <= 'd0;     // Phase 0
                end                
            end
        end
    end
endgenerate

// MSA data
// Based on the phase the MSA data in the RAM will be swapped
generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_msa_dat_4spl
        always_comb
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                // Phase 1
                if (clk_msa.ph[i] == 'd1)
                begin
                    clk_msa.dat[i][0] = clk_ram.dout[i][1];
                    clk_msa.dat[i][1] = clk_ram.dout[i][2];
                    clk_msa.dat[i][2] = clk_ram.dout[i][3];
                    clk_msa.dat[i][3] = clk_ram.dout[i][0];
                end

                // Phase 2
                else if (clk_msa.ph[i] == 'd2)
                begin
                    clk_msa.dat[i][0] = clk_ram.dout[i][2];
                    clk_msa.dat[i][1] = clk_ram.dout[i][3];
                    clk_msa.dat[i][2] = clk_ram.dout[i][0];
                    clk_msa.dat[i][3] = clk_ram.dout[i][1];
                end

                // Phase 3
                else if (clk_msa.ph[i] == 'd3)
                begin
                    clk_msa.dat[i][0] = clk_ram.dout[i][3];
                    clk_msa.dat[i][1] = clk_ram.dout[i][0];
                    clk_msa.dat[i][2] = clk_ram.dout[i][1];
                    clk_msa.dat[i][3] = clk_ram.dout[i][2];
                end

                // Phase 0
                else 
                begin
                    clk_msa.dat[i][0] = clk_ram.dout[i][0];
                    clk_msa.dat[i][1] = clk_ram.dout[i][1];
                    clk_msa.dat[i][2] = clk_ram.dout[i][2];
                    clk_msa.dat[i][3] = clk_ram.dout[i][3];
                end
            end
        end
    end

    // Two symbols per lane
    else
    begin : gen_msa_dat_2spl
        always_comb
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                // Phase 1
                if (clk_msa.ph[i] == 'd1)
                begin
                    clk_msa.dat[i][0] = clk_ram.dout[i][1];
                    clk_msa.dat[i][1] = clk_ram.dout[i][0];
                end

                // Phase 0
                else
                begin
                    clk_msa.dat[i][0] = clk_ram.dout[i][0];
                    clk_msa.dat[i][1] = clk_ram.dout[i][1];
                end
            end
        end
    end
endgenerate

// RAM read
// The MSA read logic assumes the read data is aligned stored in the ram (like phase 0)
// However the MSA read data is adjusted for the phase alignment.
// To correct this the read to the ram must be adjusted as well.
generate
    // Four symbols per lane
    if (P_SPL == 4)
    begin : gen_ram_rd_4spl
        always_comb
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                // Phase 1
                if (clk_msa.ph[i] == 'd1)
                begin
                    clk_ram.rd[i][1] = clk_msa.rd[i][0];
                    clk_ram.rd[i][2] = clk_msa.rd[i][1];
                    clk_ram.rd[i][3] = clk_msa.rd[i][2];
                    clk_ram.rd[i][0] = clk_msa.rd[i][3];
                end

                // Phase 2
                else if (clk_msa.ph[i] == 'd2)
                begin
                    clk_ram.rd[i][2] = clk_msa.rd[i][0];
                    clk_ram.rd[i][3] = clk_msa.rd[i][1];
                    clk_ram.rd[i][0] = clk_msa.rd[i][2];
                    clk_ram.rd[i][1] = clk_msa.rd[i][3];
                end

                // Phase 3
                else if (clk_msa.ph[i] == 'd3)
                begin
                    clk_ram.rd[i][3] = clk_msa.rd[i][0];
                    clk_ram.rd[i][0] = clk_msa.rd[i][1];
                    clk_ram.rd[i][1] = clk_msa.rd[i][2];
                    clk_ram.rd[i][2] = clk_msa.rd[i][3];
                end

                // Phase 0
                else 
                begin
                    clk_ram.rd[i][0] = clk_msa.rd[i][0];
                    clk_ram.rd[i][1] = clk_msa.rd[i][1];
                    clk_ram.rd[i][2] = clk_msa.rd[i][2];
                    clk_ram.rd[i][3] = clk_msa.rd[i][3];
                end
            end
        end
    end

    // Two symbols per lane
    else
    begin : gen_ram_rd_2spl
        always_comb
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                // Phase 1
                if (clk_msa.ph[i] == 'd1)
                begin
                    clk_ram.rd[i][0] = clk_msa.rd[i][1];
                    clk_ram.rd[i][1] = clk_msa.rd[i][0];
                end

                // Phase 0
                else
                begin
                    clk_ram.rd[i][0] = clk_msa.rd[i][0];
                    clk_ram.rd[i][1] = clk_msa.rd[i][1];
                end
            end
        end
    end
endgenerate

// Interrupt lane
// Each lanes has its own interrupt, which will be asserted at the end of a msa packet
    always_ff @ (posedge CLK_IN)
    begin
        for (int i = 0; i < P_LANES; i++)
        begin
            // Locked
            if (clk_lnk.lock)
            begin
                // Clear
                if (clk_msa.irq_all)
                    clk_msa.irq_lane[i] <= 0;

                // Set
                else if (clk_msa.eop[i])
                    clk_msa.irq_lane[i] <= 1;
            end

            else
                clk_msa.irq_lane[i] <= 0;
        end
    end

// Interrupt
    always_ff @ (posedge CLK_IN)
    begin
        // Locked
        if (clk_lnk.lock)
        begin
            // Clear
            // When message is received
            if (clk_msg.first)
                clk_msa.irq_all <= 0;

            // Set
            // When all lanes have their interrupt asserted

            // 4 lanes
            else if ( (clk_lnk.lanes == 'd3) && (&clk_msa.irq_lane)) 
                clk_msa.irq_all <= 1;

            // 2 lanes
            else if ( (clk_lnk.lanes == 'd2) && (&clk_msa.irq_lane[1:0])) 
                clk_msa.irq_all <= 1;

            // 1 lane
            else if ( (clk_lnk.lanes == 'd1) && (clk_msa.irq_lane[0])) 
                clk_msa.irq_all <= 1;
        end

        else
            clk_msa.irq_all <= 0;
    end

// Outputs
generate
    for (i = 0; i < P_LANES; i++)
    begin
        for (j = 0; j < P_SPL; j++)
        begin
            assign LNK_SRC_IF.sol[i][j]   = clk_lnk.sol[i][j]; 
            assign LNK_SRC_IF.eol[i][j]   = clk_lnk.eol[i][j]; 
            assign LNK_SRC_IF.vid[i][j]   = clk_lnk.vid[i][j]; 
            assign LNK_SRC_IF.sec[i][j]   = 0;                  // Not used 
            assign LNK_SRC_IF.msa[i][j]   = 0;                  // The MSA is not passed 
            assign LNK_SRC_IF.vbid[i][j]  = clk_lnk.vbid[i][j]; 
            assign LNK_SRC_IF.k[i][j]     = clk_lnk.k[i][j];
            assign LNK_SRC_IF.dat[i][j]   = clk_lnk.dat[i][j];
        end
    end
endgenerate

    assign LNK_SRC_IF.lock  = clk_lnk.lock;
    assign IRQ_OUT          = clk_msa.irq_all;  // Interrupt

endmodule

`default_nettype wire
