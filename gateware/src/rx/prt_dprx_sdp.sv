/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP RX Secondary Data Packet
    (c) 2021 - 2024 by Parretto B.V.

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
module prt_dprx_sdp
#(
    // System
    parameter               P_VENDOR = "none",  // Vendor - "AMD", "ALTERA" or "LSC"

    // Link
    parameter               P_LANES = 4,    	// Lanes
    parameter               P_SPL = 2        	// Symbols per lane
)
(
    // Reset and clock
    input wire              RST_IN,         // Reset
    input wire              CLK_IN,         // Clock  

    // Control
    input wire  [1:0]       CTL_LANES_IN,   // Active lanes (1 - 1 lane / 2 - 2 lanes / 3 - 4 lanes)

    // Link
    prt_dp_rx_lnk_if.snk    LNK_SNK_IF,         // Sink
    prt_dp_rx_lnk_if.src    LNK_SRC_IF,         // Source

    // Secondary data packet
    prt_dp_rx_sdp_if.src    SDP_SRC_IF          // Source
);

// Parameters
localparam P_FIFO_WRDS = 64;
localparam P_FIFO_ADR = $clog2(P_FIFO_WRDS);
localparam P_FIFO_DAT = 8;

// Structure
typedef struct {
    logic   [1:0]               lanes;                  // Active lanes
    logic                       lock;                   // Lock
    logic   [P_SPL-1:0]         sol[P_LANES];           // Start of line
    logic   [P_SPL-1:0]         eol[P_LANES];           // End of line
    logic   [P_SPL-1:0]         vid[P_LANES];           // Video packet
    logic   [P_SPL-1:0]         sdp[P_LANES];           // Secondary data packet
    logic   [P_SPL-1:0]         msa[P_LANES];           // Main stream attributes (msa)
    logic   [P_SPL-1:0]         vbid[P_LANES];          // VB-ID
    logic   [P_SPL-1:0]         k[P_LANES];             // k character
    logic   [7:0]               dat[P_LANES][P_SPL];    // Data
    logic   [P_LANES-1:0]       sop;
} lnk_struct;

typedef struct {
    logic   [8:0]               din[P_LANES][P_SPL];        // Data in
    logic   [8:0]               din_del[P_LANES][P_SPL];    // Data
    logic   [8:0]               dout[P_LANES][P_SPL];       // Data
    logic   [1:0]               sel[P_LANES];
    logic   [P_LANES-1:0]       wr;
    logic   [P_LANES-1:0]       wr_re;
    logic   [P_LANES-1:0]       wr_fe;
    logic   [P_LANES-1:0]       wr_sticky;
} aln_struct;

typedef struct {
    logic                       clr;                    // Clear
    logic   [2:0]               sel[4];
    logic   [3:0]               wr[4];                  // Write
    logic   [P_FIFO_DAT-1:0]    din[4][4];              // Write data
    logic   [3:0]               rd[4];                 // Read
    logic   [P_FIFO_DAT-1:0]    dout[4][4];             // Read data
    logic                       head_inc;
    logic   [3:0]               head;
    logic   [3:0]               tail;
    logic   [3:0]               rd_cnt[2];
    logic                       rd_cnt_ld;
    logic                       rd_cnt_end;
} fifo_struct;

typedef struct {
    logic                       sop;
    logic                       eop;
    logic   [31:0]              dat;
    logic                       vld;
} sdp_struct;

// Signals
lnk_struct          clk_lnk; 
aln_struct          clk_aln; 
fifo_struct         clk_fifo;
sdp_struct          clk_sdp;

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
            clk_lnk.sdp[i]  = LNK_SNK_IF.sdp[i];     // Secondary data packet
            clk_lnk.msa[i]  = LNK_SNK_IF.msa[i];     // MSA
            clk_lnk.vbid[i] = LNK_SNK_IF.vbid[i];    // VB-ID
            clk_lnk.k[i]    = LNK_SNK_IF.k[i];       // k character
            clk_lnk.dat[i]  = LNK_SNK_IF.dat[i];     // Data
        end
    end

/*
    Link Domain
*/

// SDP edge detector
// The rising edge is used to detect the incoming phase
generate
    for (i = 0; i < P_LANES; i++)
    begin
        prt_dp_lib_edge
        LCLK_SDP_EDGE_INST
        (
            .CLK_IN     (CLK_IN),        // Clock
            .CKE_IN     (1'b1),              // Clock enable
            .A_IN       (|clk_lnk.sdp[i]),  // Input
            .RE_OUT     (clk_lnk.sop[i]),   // Rising edge
            .FE_OUT     ()                   // Falling edge
        );
    end
endgenerate

// Aligner
generate 
    for (i = 0; i < P_LANES; i++)
    begin
        for (j = 0; j < P_SPL; j++)
        begin
            assign clk_aln.din[i][j] = {clk_lnk.sdp[i][j], clk_lnk.dat[i][j]}; 

            always_ff @ (posedge CLK_IN)
            begin
                clk_aln.din_del[i][j]  <= clk_aln.din[i][j];
            end
        end
    end
endgenerate            

// Aligner Select
generate
    // Two symbols per lane
    if (P_SPL == 2)
    begin : gen_aln_sel_2spl
        for (i = 0; i < P_LANES; i++)
        begin
            always_ff @ (posedge CLK_IN)
            begin
                // Lock
                if (clk_lnk.lock)
                begin
                    if (clk_lnk.sop[i])
                    begin
                        case (clk_lnk.sdp[i])
                            'b10    : clk_aln.sel[i] <= 'd1;
                            default : clk_aln.sel[i] <= 'd0;
                        endcase
                    end
                end

                else
                    clk_aln.sel[i] <= 0;
            end
        end
    end

    // Four symbols per lane
    else
    begin : gen_aln_sel_4spl
        for (i = 0; i < P_LANES; i++)
        begin
            always_ff @ (posedge CLK_IN)
            begin
                // Lock
                if (clk_lnk.lock)
                begin
                    if (clk_lnk.sop[i])
                    begin
                        case (clk_lnk.sdp[i])
                            'b1110  : clk_aln.sel[i] <= 'd1;
                            'b1100  : clk_aln.sel[i] <= 'd2;
                            'b1000  : clk_aln.sel[i] <= 'd3;
                            default : clk_aln.sel[i] <= 'd0;
                        endcase
                    end
                end

                else
                    clk_aln.sel[i] <= 0;
            end
        end
    end
endgenerate

// Aligner data
generate
    // Two symbols per lane
    if (P_SPL == 2)
    begin : gen_aln_dat_2spl
        for (i = 0; i < P_LANES; i++)
        begin
            always_comb
            begin
                case (clk_aln.sel[i])

                    // Phase 1
                    'd1 : 
                    begin
                        clk_aln.dout[i][0] = clk_aln.din_del[i][1];
                        clk_aln.dout[i][1] = clk_aln.din[i][0];
                    end

                    // Phase 0
                    default : 
                    begin
                        clk_aln.dout[i][0] = clk_aln.din_del[i][0];
                        clk_aln.dout[i][1] = clk_aln.din_del[i][1];
                    end
                endcase
            end
        end
    end

    // Four symbols per lane
    else
    begin : gen_aln_dat_4spl
        for (i = 0; i < P_LANES; i++)
        begin
            always_comb
            begin
                case (clk_aln.sel[i])

                    // Phase 1
                    'd1 : 
                    begin
                        clk_aln.dout[i][0] = clk_aln.din_del[i][1];
                        clk_aln.dout[i][1] = clk_aln.din_del[i][2];
                        clk_aln.dout[i][2] = clk_aln.din_del[i][3];
                        clk_aln.dout[i][3] = clk_aln.din[i][0];
                    end

                    // Phase 2
                    'd2 : 
                    begin
                        clk_aln.dout[i][0] = clk_aln.din_del[i][2];
                        clk_aln.dout[i][1] = clk_aln.din_del[i][3];
                        clk_aln.dout[i][2] = clk_aln.din[i][0];
                        clk_aln.dout[i][3] = clk_aln.din[i][1];
                    end

                    // Phase 3
                    'd3 : 
                    begin
                        clk_aln.dout[i][0] = clk_aln.din_del[i][3];
                        clk_aln.dout[i][1] = clk_aln.din[i][0];
                        clk_aln.dout[i][2] = clk_aln.din[i][1];
                        clk_aln.dout[i][3] = clk_aln.din[i][2];
                    end

                    // Phase 0
                    default : 
                    begin
                        clk_aln.dout[i][0] = clk_aln.din_del[i][0];
                        clk_aln.dout[i][1] = clk_aln.din_del[i][1];
                        clk_aln.dout[i][2] = clk_aln.din_del[i][2];
                        clk_aln.dout[i][3] = clk_aln.din_del[i][3];
                    end
                endcase
            end
        end
    end
endgenerate

// Aligner write
generate
    // Two symbols
    if (P_SPL == 2)
    begin : gen_aln_wr_2spl
        for (i = 0; i < P_LANES; i++)
        begin
            always_comb
            begin
                if (clk_aln.dout[i][0][8] && clk_aln.dout[i][1][8])
                    clk_aln.wr[i] = 1;
                else
                    clk_aln.wr[i] = 0;
            end
        end
    end

    // Four symbols
    else
    begin
        for (i = 0; i < P_LANES; i++)
        begin
            always_comb
            begin
                if (clk_aln.dout[i][0][8] && clk_aln.dout[i][1][8] && clk_aln.dout[i][2][8] && clk_aln.dout[i][3][8])
                    clk_aln.wr[i] = 1;
                else
                    clk_aln.wr[i] = 0;
            end
        end
    end
endgenerate

// Alignment write edge
// The rising edge is used to increment the head counter
// The falling edge is used to clear the fifo select
generate
    for (i = 0; i < P_LANES; i++)
    begin
        prt_dp_lib_edge
        LCLK_ALN_WR_EDGE_INST
        (
            .CLK_IN     (CLK_IN),               // Clock
            .CKE_IN     (1'b1),                 // Clock enable
            .A_IN       (clk_aln.wr[i]),        // Input
            .RE_OUT     (clk_aln.wr_re[i]),     // Rising edge
            .FE_OUT     (clk_aln.wr_fe[i])      // Falling edge
        );
    end
endgenerate

// Alignment write sticky
// The lanes have skew.
// The write rising edge is used to increment the head counter
generate
    for (i = 0; i < P_LANES; i++)
    begin
        always_ff @ (posedge CLK_IN)
        begin
            // Lock
            if (clk_lnk.lock)
            begin
                // Clear
                if (clk_fifo.head_inc)
                    clk_aln.wr_sticky[i] <= 0;

                // Set
                if (clk_aln.wr_re[i])
                    clk_aln.wr_sticky[i] <= 1;
            end

            else
                clk_aln.wr_sticky[i] <= 0;
        end
    end
endgenerate

// Head increment
    always_comb
    begin
        // Default
        clk_fifo.head_inc = 0;

        // One lane
        if (clk_lnk.lanes == 'd1)
        begin
            // In single lane configuration the write fifo bandwidth is lower than the read fifo bandwidth. 
            // Therefore we wait untill the full packet has been stored in the fifo, before incrementing the head. 
            if (clk_aln.wr_fe[0])
                clk_fifo.head_inc = 1;
        end

        // Two lanes
        else if (clk_lnk.lanes == 'd2)
        begin
            if (&clk_aln.wr_sticky[0+:2])
                clk_fifo.head_inc = 1;
        end

        // Four lanes
        else
        begin
            if (&clk_aln.wr_sticky[0+:4])
                clk_fifo.head_inc = 1;
        end
    end

// Head counter 
    always_ff @ (posedge CLK_IN)
    begin
        // Lock
        if (clk_lnk.lock)
        begin
            // Increment
            if (clk_fifo.head_inc)
                clk_fifo.head <= clk_fifo.head + 'd1;
        end

        else
            clk_fifo.head <= 0;
    end

//  FIFO lock
    always_ff @ (posedge CLK_IN)
    begin
        if (clk_lnk.lock)
            clk_fifo.clr <= 0;
        else
            clk_fifo.clr <= 1;
    end
  
//  FIFO Select
    always_ff @ (posedge CLK_IN)
    begin
        if (clk_lnk.lock)
        begin
            // One lane
            if (clk_lnk.lanes == 'd1)
            begin
                // Clear 
                if (clk_aln.wr_fe[0])
                        clk_fifo.sel[0] <= 'd0;

                // Increment
                else if (|clk_aln.wr[0])
                begin
                    if (((P_SPL == 4) && (clk_fifo.sel[0] == 'd3)) || ((P_SPL == 2) && (clk_fifo.sel[0] == 'd7)))
                        clk_fifo.sel[0] <= 'd0;
                    else
                        clk_fifo.sel[0] <= clk_fifo.sel[0] + 'd1;
                end

                // Not used
                for (int i = 1; i < 4; i++)
                    clk_fifo.sel[i] <= 0;
            end

            // Two lanes
            else if (clk_lnk.lanes == 'd2)
            begin
                for (int i = 0; i < 2; i++)
                begin
                    // Clear 
                    if (clk_aln.wr_fe[i])
                        clk_fifo.sel[i] <= 'd0;

                    // Increment
                    else if (|clk_aln.wr[i])
                    begin
                        if (((P_SPL == 4) && (clk_fifo.sel[i] == 'd1)) || ((P_SPL == 2) && (clk_fifo.sel[i] == 'd3)))
                            clk_fifo.sel[i] <= 'd0;
                        else
                            clk_fifo.sel[i] <= clk_fifo.sel[i] + 'd1;
                    end
                end

                // Not used
                for (int i = 2; i < 4; i++)
                    clk_fifo.sel[i] <= 0;
            end

            // Four lanes
            else
            begin
                for (int i = 0; i < 4; i++)
                begin                    
                    // Four lanes
                    if (P_SPL == 4)
                        clk_fifo.sel[i] <= 0;
                    
                    // Two lanes
                    else
                    begin
                        // Clear 
                        if (clk_aln.wr_fe[i])
                            clk_fifo.sel[i] <= 'd0;

                        // Increment
                        else if (|clk_aln.wr[i])
                        begin
                            if (clk_fifo.sel[i] == 'd1)
                                clk_fifo.sel[i] <= 0;
                            else
                                clk_fifo.sel[i] <= clk_fifo.sel[i] + 'd1;
                        end
                    end
                end
            end
        end

        // Idle
        else
        begin
            for (int i = 0; i < 4; i++)
                clk_fifo.sel[i] <= 0;
        end
    end

// FIFO Write and write data
generate
    // Two symbols per lane
    if (P_SPL == 2)
    begin : gen_fifo_wr_2spl
        always_comb
        begin
            // Default
            for (int i = 0; i < 4; i++)
            begin
                for (int j = 0; j < 4; j++)
                begin
                    clk_fifo.wr[i][j] = 0;
                    clk_fifo.din[i][j] = 0;
                end
            end

            // One lane
            if (clk_lnk.lanes == 'd1)
            begin
                case (clk_fifo.sel[0])

                    'd1 :  
                    begin
                        for (int j = 0; j < 2; j++)
                        begin
                            clk_fifo.wr[0][j+2] = clk_aln.wr[0];
                            clk_fifo.din[0][j+2] = clk_aln.dout[0][j][0+:8];
                        end
                    end

                    'd2 :  
                    begin
                        for (int j = 0; j < 2; j++)
                        begin
                            clk_fifo.wr[1][j] = clk_aln.wr[0];
                            clk_fifo.din[1][j] = clk_aln.dout[0][j][0+:8];
                        end
                    end

                    'd3 :  
                    begin
                        for (int j = 0; j < 2; j++)
                        begin
                            clk_fifo.wr[1][j+2] = clk_aln.wr[0];
                            clk_fifo.din[1][j+2] = clk_aln.dout[0][j][0+:8];
                        end
                    end

                    'd4 :  
                    begin
                        for (int j = 0; j < 2; j++)
                        begin
                            clk_fifo.wr[2][j] = clk_aln.wr[0];
                            clk_fifo.din[2][j] = clk_aln.dout[0][j][0+:8];
                        end
                    end

                    'd5 :  
                    begin
                        for (int j = 0; j < 2; j++)
                        begin
                            clk_fifo.wr[2][j+2] = clk_aln.wr[0];
                            clk_fifo.din[2][j+2] = clk_aln.dout[0][j][0+:8];
                        end
                    end

                    'd6 :  
                    begin
                        for (int j = 0; j < 2; j++)
                        begin
                            clk_fifo.wr[3][j] = clk_aln.wr[0];
                            clk_fifo.din[3][j] = clk_aln.dout[0][j][0+:8];
                        end
                    end

                    'd7 :  
                    begin
                        for (int j = 0; j < 2; j++)
                        begin
                            clk_fifo.wr[3][j+2] = clk_aln.wr[0];
                            clk_fifo.din[3][j+2] = clk_aln.dout[0][j][0+:8];
                        end
                    end

                    default :  
                    begin
                        for (int j = 0; j < 2; j++)
                        begin
                            clk_fifo.wr[0][j] = clk_aln.wr[0];
                            clk_fifo.din[0][j] = clk_aln.dout[0][j][0+:8];
                        end
                    end
                endcase
            end

            // Two lanes
            else if (clk_lnk.lanes == 'd2)
            begin
                for (int i = 0; i < 2; i++)
                begin
                    case (clk_fifo.sel[i])
                        'd1 :
                        begin
                            for (int j = 0; j < 2; j++)
                            begin
                                clk_fifo.wr[i*2][j+2] = clk_aln.wr[i];
                                clk_fifo.din[i*2][j+2] = clk_aln.dout[i][j][0+:8];
                            end
                        end

                        'd2 :
                        begin
                            for (int j = 0; j < 2; j++)
                            begin
                                clk_fifo.wr[(i*2)+1][j] = clk_aln.wr[i];
                                clk_fifo.din[(i*2)+1][j] = clk_aln.dout[i][j][0+:8];
                            end
                        end

                        'd3 :
                        begin
                            for (int j = 0; j < 2; j++)
                            begin
                                clk_fifo.wr[(i*2)+1][j+2] = clk_aln.wr[i];
                                clk_fifo.din[(i*2)+1][j+2] = clk_aln.dout[i][j][0+:8];
                            end
                        end

                        default : 
                        begin
                            for (int j = 0; j < 2; j++)
                            begin
                                clk_fifo.wr[i*2][j] = clk_aln.wr[i];
                                clk_fifo.din[i*2][j] = clk_aln.dout[i][j][0+:8];
                            end
                        end
                    endcase
                end
            end

            // Four lanes
            else
            begin
                for (int i = 0; i < 4; i++)
                begin
                    for (int j = 0; j < 2; j++)
                    begin
                        if (clk_fifo.sel[i] == 'd1)
                        begin
                            clk_fifo.wr[i][j+2] = clk_aln.wr[i];
                            clk_fifo.din[i][j+2] = clk_aln.dout[i][j][0+:8];
                        end

                        else
                        begin
                            clk_fifo.wr[i][j] = clk_aln.wr[i];
                            clk_fifo.din[i][j] = clk_aln.dout[i][j][0+:8];
                        end
                    end
                end
            end
        end
    end

    // Four symbols per lane
    else
    begin : gen_fifo_wr_4spl
        always_comb
        begin
            // Default
            for (int i = 0; i < 4; i++)
            begin
                for (int j = 0; j < 4; j++)
                begin
                    clk_fifo.wr[i][j] = 0;
                    clk_fifo.din[i][j] = 0;
                end
            end

            // One lane
            if (clk_lnk.lanes == 'd1)
            begin
                case (clk_fifo.sel[0])

                    'd1 :  
                    begin
                        for (int j = 0; j < 4; j++)
                        begin
                            clk_fifo.wr[1][j] = clk_aln.wr[0];
                            clk_fifo.din[1][j] = clk_aln.dout[0][j][0+:8];
                        end
                    end

                    'd2 :  
                    begin
                        for (int j = 0; j < 4; j++)
                        begin
                            clk_fifo.wr[2][j] = clk_aln.wr[0];
                            clk_fifo.din[2][j] = clk_aln.dout[0][j][0+:8];
                        end
                    end

                    'd3 :  
                    begin
                        for (int j = 0; j < 4; j++)
                        begin
                            clk_fifo.wr[3][j] = clk_aln.wr[0];
                            clk_fifo.din[3][j] = clk_aln.dout[0][j][0+:8];
                        end
                    end

                    default :  
                    begin
                        for (int j = 0; j < 4; j++)
                        begin
                            clk_fifo.wr[0][j] = clk_aln.wr[0];
                            clk_fifo.din[0][j] = clk_aln.dout[0][j][0+:8];
                        end
                    end
                endcase
            end

            // Two lanes
            else if (clk_lnk.lanes == 'd2)
            begin
                for (int i = 0; i < 2; i++)
                begin
                    if (clk_fifo.sel[i] == 'd1)
                    begin
                        for (int j = 0; j < 4; j++)
                        begin
                            clk_fifo.wr[(i*2)+1][j] = clk_aln.wr[i];
                            clk_fifo.din[(i*2)+1][j] = clk_aln.dout[i][j][0+:8];
                        end
                    end

                    else
                    begin
                        for (int j = 0; j < 4; j++)
                        begin
                            clk_fifo.wr[i*2][j] = clk_aln.wr[i];
                            clk_fifo.din[i*2][j] = clk_aln.dout[i][j][0+:8];
                        end
                    end
                end
            end

            // Four lanes
            else
            begin
                for (int i = 0; i < 4; i++)
                begin
                    for (int j = 0; j < 4; j++)
                    begin
                        clk_fifo.wr[i][j] = clk_aln.wr[i];
                        clk_fifo.din[i][j] = clk_aln.dout[i][j][0+:8];
                    end
                end
            end
        end
    end

endgenerate

generate
    for (i = 0; i < 4; i++)
    begin : gen_fifo
        for (j = 0; j < 4; j++)
        begin

            // FIFO
            prt_dp_lib_fifo_sc
            #(
                .P_VENDOR       (P_VENDOR),             // Vendor
                .P_MODE         ("burst"),		        // "single" or "burst"
                .P_RAM_STYLE	("distributed"),	    // "distributed" or "block"
                .P_ADR_WIDTH	(P_FIFO_ADR),
                .P_DAT_WIDTH	(P_FIFO_DAT)
            )
            FIFO_INST
            (
                	// Clocks and reset
	                .RST_IN     (RST_IN),		            // Reset
	                .CLK_IN     (CLK_IN),		            // Clock
	                .CLR_IN     (1'b0),		                // Clear


                    // Input 
                    .WR_IN      (clk_fifo.wr[i][j]),         // Write
                    .DAT_IN     (clk_fifo.din[i][j]),        // Write data

                    // Output 
                    .RD_EN_IN   (1'b1),                      // Read enable
                    .RD_IN      (clk_fifo.rd[i][j]),         // Read
                    .DAT_OUT    (clk_fifo.dout[i][j]),       // Read data
                    .DE_OUT     (),                          // Data enable

                    // Status 
                    .WRDS_OUT   (),                          // Used words
                    .FL_OUT     (),                          // Full
                    .EP_OUT     ()                           // Empty
            );
        end
    end
endgenerate

// Tail
    always_ff @ (posedge CLK_IN)
    begin
        if (clk_lnk.lock)
        begin
           // Increment
           if (clk_fifo.rd_cnt_ld)
            clk_fifo.tail <= clk_fifo.tail + 'd1; 
        end   

        else
            clk_fifo.tail <= 0;
    end

// FIFO load
    always_comb
    begin
        if (clk_fifo.head != clk_fifo.tail)
            clk_fifo.rd_cnt_ld = 1;
        else
            clk_fifo.rd_cnt_ld = 0;
    end

// Read counter
    always_ff @ (posedge CLK_IN)
    begin
        if (clk_lnk.lock)
        begin
            // Load
            if (clk_fifo.rd_cnt_end && clk_fifo.rd_cnt_ld)
                clk_fifo.rd_cnt[0] <= 'd12;

            // Decrement
            else if (!clk_fifo.rd_cnt_end)
                clk_fifo.rd_cnt[0] <= clk_fifo.rd_cnt[0] - 'd1;

            // The delayed read counter is used for the read mux, start of packet and end of packet
            // The FIFO has one clock latency.
            for (int i = 1; i < $size(clk_fifo.rd_cnt); i++)
                clk_fifo.rd_cnt[i] <= clk_fifo.rd_cnt[i-1];
        end

        else
        begin
            for (int i = 0; i < $size(clk_fifo.rd_cnt); i++)
                clk_fifo.rd_cnt[0] <= 0;
        end
    end

// Read counter end
    always_comb
    begin
        if (clk_fifo.rd_cnt[0] == 0)
            clk_fifo.rd_cnt_end = 1;
        else
            clk_fifo.rd_cnt_end = 0;
    end

// FIFO read
    always_comb
    begin
        // Default
        for (int i = 0; i < 4; i++)
        begin 
            for (int j = 0; j < 4; j++)
                clk_fifo.rd[i][j] = 0;
        end

        if (!clk_fifo.rd_cnt_end)
        begin
            // One lane
            if (clk_lnk.lanes == 'd1)
            begin
                case (clk_fifo.rd_cnt[0])
                    'd11 : 
                    begin
                        clk_fifo.rd[0][1] = 1;  // PB0
                        clk_fifo.rd[0][3] = 1;  // PB1
                        clk_fifo.rd[1][1] = 1;  // PB2
                        clk_fifo.rd[1][3] = 1;  // PB3
                    end

                    'd10 : 
                    begin
                        clk_fifo.rd[2][0] = 1;  // DB0
                        clk_fifo.rd[2][1] = 1;  // DB1
                        clk_fifo.rd[2][2] = 1;  // DB2
                        clk_fifo.rd[2][3] = 1;  // DB4
                    end

                    'd9 :
                    begin
                        clk_fifo.rd[3][1] = 1;  // DB4
                        clk_fifo.rd[3][2] = 1;  // DB5
                        clk_fifo.rd[3][3] = 1;  // DB6
                        clk_fifo.rd[0][0] = 1;  // DB7
                    end

                    'd8 :
                    begin
                        clk_fifo.rd[0][2] = 1;  // DB8
                        clk_fifo.rd[0][3] = 1;  // DB9
                        clk_fifo.rd[1][0] = 1;  // DB10
                        clk_fifo.rd[1][1] = 1;  // DB11
                    end

                    'd7 :
                    begin
                        clk_fifo.rd[1][3] = 1;  // DB12
                        clk_fifo.rd[2][0] = 1;  // DB13
                        clk_fifo.rd[2][1] = 1;  // DB14
                        clk_fifo.rd[2][2] = 1;  // DB15
                    end

                    'd6 : 
                    begin
                        clk_fifo.rd[3][0] = 1;  // PB4
                        clk_fifo.rd[0][1] = 1;  // PB5
                        clk_fifo.rd[1][2] = 1;  // PB6
                        clk_fifo.rd[2][3] = 1;  // PB7
                    end

                    'd5 :
                    begin
                        clk_fifo.rd[3][0] = 1;  // DB16
                        clk_fifo.rd[3][1] = 1;  // DB17
                        clk_fifo.rd[3][2] = 1;  // DB18
                        clk_fifo.rd[3][3] = 1;  // DB19
                    end

                    'd4 :
                    begin
                        clk_fifo.rd[0][1] = 1;  // DB20
                        clk_fifo.rd[0][2] = 1;  // DB21
                        clk_fifo.rd[0][3] = 1;  // DB22
                        clk_fifo.rd[1][0] = 1;  // DB23
                    end

                    'd3 :
                    begin
                        clk_fifo.rd[1][2] = 1;  // DB24
                        clk_fifo.rd[1][3] = 1;  // DB25
                        clk_fifo.rd[2][0] = 1;  // DB26
                        clk_fifo.rd[2][1] = 1;  // DB27
                    end

                    'd2 :
                    begin
                        clk_fifo.rd[2][3] = 1;  // DB28
                        clk_fifo.rd[3][0] = 1;  // DB29
                        clk_fifo.rd[3][1] = 1;  // 0
                        clk_fifo.rd[3][2] = 1;  // 0
                    end

                    'd1 : 
                    begin
                        clk_fifo.rd[0][0] = 1;  // PB8
                        clk_fifo.rd[1][1] = 1;  // PB9
                        clk_fifo.rd[2][2] = 1;  // PB10
                        clk_fifo.rd[3][3] = 1;  // PB11
                    end

                    default : 
                    begin
                        clk_fifo.rd[0][0] = 1;  // HB0
                        clk_fifo.rd[0][2] = 1;  // HB1
                        clk_fifo.rd[1][0] = 1;  // HB2
                        clk_fifo.rd[1][2] = 1;  // HB3
                    end
                endcase
            end

            // Two lanes
            else if (clk_lnk.lanes == 'd2)
            begin
                case (clk_fifo.rd_cnt[0])
                    'd11 : 
                    begin
                        clk_fifo.rd[0][1] = 1;  // PB0
                        clk_fifo.rd[0][3] = 1;  // PB1
                        clk_fifo.rd[2][1] = 1;  // PB2
                        clk_fifo.rd[2][3] = 1;  // PB3
                    end

                    'd10 : 
                    begin
                        clk_fifo.rd[1][0] = 1;  // DB0
                        clk_fifo.rd[1][1] = 1;  // DB1
                        clk_fifo.rd[1][2] = 1;  // DB2
                        clk_fifo.rd[1][3] = 1;  // DB4
                    end

                    'd9 :
                    begin
                        clk_fifo.rd[3][0] = 1;  // DB4
                        clk_fifo.rd[3][1] = 1;  // DB5
                        clk_fifo.rd[3][2] = 1;  // DB6
                        clk_fifo.rd[3][3] = 1;  // DB7
                    end

                    'd8 :
                    begin
                        clk_fifo.rd[0][1] = 1;  // DB8
                        clk_fifo.rd[0][2] = 1;  // DB9
                        clk_fifo.rd[0][3] = 1;  // DB10
                        clk_fifo.rd[1][0] = 1;  // DB11
                    end

                    'd7 :
                    begin
                        clk_fifo.rd[2][1] = 1;  // DB12
                        clk_fifo.rd[2][2] = 1;  // DB13
                        clk_fifo.rd[2][3] = 1;  // DB14
                        clk_fifo.rd[3][0] = 1;  // DB15
                    end

                    'd6 : 
                    begin
                        clk_fifo.rd[0][0] = 1;  // PB4
                        clk_fifo.rd[2][0] = 1;  // PB5
                        clk_fifo.rd[1][1] = 1;  // PB6
                        clk_fifo.rd[3][1] = 1;  // PB7
                    end

                    'd5 :
                    begin
                        clk_fifo.rd[1][2] = 1;  // DB16
                        clk_fifo.rd[1][3] = 1;  // DB17
                        clk_fifo.rd[0][0] = 1;  // DB18
                        clk_fifo.rd[0][1] = 1;  // DB19
                    end

                    'd4 :
                    begin
                        clk_fifo.rd[3][2] = 1;  // DB20
                        clk_fifo.rd[3][3] = 1;  // DB21
                        clk_fifo.rd[2][0] = 1;  // DB22
                        clk_fifo.rd[2][1] = 1;  // DB23
                    end

                    'd3 :
                    begin
                        clk_fifo.rd[0][3] = 1;  // DB24
                        clk_fifo.rd[1][0] = 1;  // DB25
                        clk_fifo.rd[1][1] = 1;  // DB26
                        clk_fifo.rd[1][2] = 1;  // DB27
                    end

                    'd2 :
                    begin
                        clk_fifo.rd[2][3] = 1;  // DB28
                        clk_fifo.rd[3][0] = 1;  // DB29
                        clk_fifo.rd[3][1] = 1;  // 0
                        clk_fifo.rd[3][2] = 1;  // 0
                    end

                    'd1 : 
                    begin
                        clk_fifo.rd[0][2] = 1;  // PB8
                        clk_fifo.rd[2][2] = 1;  // PB9
                        clk_fifo.rd[1][3] = 1;  // PB10
                        clk_fifo.rd[3][3] = 1;  // PB11
                    end

                    default : 
                    begin
                        clk_fifo.rd[0][0] = 1;  // HB0
                        clk_fifo.rd[0][2] = 1;  // HB1
                        clk_fifo.rd[2][0] = 1;  // HB2
                        clk_fifo.rd[2][2] = 1;  // HB3
                    end
                endcase
            end

            // Four lanes
            else
            begin
                case (clk_fifo.rd_cnt[0])
                    'd11 : 
                    begin
                        clk_fifo.rd[0][1] = 1;  // PB0
                        clk_fifo.rd[1][1] = 1;  // PB1
                        clk_fifo.rd[2][1] = 1;  // PB2
                        clk_fifo.rd[3][1] = 1;  // PB3
                    end

                    'd10 :
                    begin
                        clk_fifo.rd[0][2] = 1;  // DB0
                        clk_fifo.rd[0][3] = 1;  // DB1
                        clk_fifo.rd[0][0] = 1;  // DB2
                        clk_fifo.rd[0][1] = 1;  // DB3
                    end

                    'd9 :
                    begin
                        clk_fifo.rd[1][2] = 1;  // DB4
                        clk_fifo.rd[1][3] = 1;  // DB5
                        clk_fifo.rd[1][0] = 1;  // DB6
                        clk_fifo.rd[1][1] = 1;  // DB7
                    end

                    'd8 :
                    begin
                        clk_fifo.rd[2][2] = 1;  // DB8
                        clk_fifo.rd[2][3] = 1;  // DB9
                        clk_fifo.rd[2][0] = 1;  // DB10
                        clk_fifo.rd[2][1] = 1;  // DB11
                    end

                    'd7 :
                    begin
                        clk_fifo.rd[3][2] = 1;  // DB12
                        clk_fifo.rd[3][3] = 1;  // DB13
                        clk_fifo.rd[3][0] = 1;  // DB14
                        clk_fifo.rd[3][1] = 1;  // DB15
                    end

                    'd6 : 
                    begin
                        clk_fifo.rd[0][2] = 1;  // PB4
                        clk_fifo.rd[1][2] = 1;  // PB5
                        clk_fifo.rd[2][2] = 1;  // PB6
                        clk_fifo.rd[3][2] = 1;  // PB7
                    end

                    'd5 :
                    begin
                        clk_fifo.rd[0][3] = 1;  // DB16
                        clk_fifo.rd[0][0] = 1;  // DB17
                        clk_fifo.rd[0][1] = 1;  // DB18
                        clk_fifo.rd[0][2] = 1;  // DB19
                    end

                    'd4 :
                    begin
                        clk_fifo.rd[1][3] = 1;  // DB20
                        clk_fifo.rd[1][0] = 1;  // DB21
                        clk_fifo.rd[1][1] = 1;  // DB22
                        clk_fifo.rd[1][2] = 1;  // DB23
                    end

                    'd3 :
                    begin
                        clk_fifo.rd[2][3] = 1;  // DB24
                        clk_fifo.rd[2][0] = 1;  // DB25
                        clk_fifo.rd[2][1] = 1;  // DB26
                        clk_fifo.rd[2][2] = 1;  // DB27
                    end

                    'd2 :
                    begin
                        clk_fifo.rd[3][3] = 1;  // DB28
                        clk_fifo.rd[3][0] = 1;  // DB29
                        clk_fifo.rd[3][1] = 1;  // 0
                        clk_fifo.rd[3][2] = 1;  // 0
                    end

                    'd1 : 
                    begin
                        clk_fifo.rd[0][3] = 1;  // PB8
                        clk_fifo.rd[1][3] = 1;  // PB9
                        clk_fifo.rd[2][3] = 1;  // PB10
                        clk_fifo.rd[3][3] = 1;  // PB11
                    end

                    default : 
                    begin
                        clk_fifo.rd[0][0] = 1;  // HB0
                        clk_fifo.rd[1][0] = 1;  // HB1
                        clk_fifo.rd[2][0] = 1;  // HB2
                        clk_fifo.rd[3][0] = 1;  // HB3
                    end
                endcase
            end
        end
    end

// SDP Data
    always_ff @ (posedge CLK_IN)
    begin
        // One lane
        if (clk_lnk.lanes == 'd1)
        begin
            case (clk_fifo.rd_cnt[$high(clk_fifo.rd_cnt)])
                'd11 : 
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[0][1];  // PB0
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[0][3];  // PB1
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[1][1];  // PB2
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[1][3];  // PB3
                end

                'd10 : 
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[2][0];  // DB0
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[2][1];  // DB1
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[2][2];  // DB2
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[2][3];  // DB4
                end

                'd9 :
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[3][1];  // DB4
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[3][2];  // DB5
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[3][3];  // DB6
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[0][0];  // DB7
                end

                'd8 :
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[0][2];  // DB8
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[0][3];  // DB9
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[1][0];  // DB10
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[1][1];  // DB11
                end

                'd7 :
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[1][3];  // DB12
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[2][0];  // DB13
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[2][1];  // DB14
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[2][2];  // DB15
                end

                'd6 : 
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[3][0];  // PB4
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[0][1];  // PB5
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[1][2];  // PB6
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[2][3];  // PB7
                end

                'd5 :
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[3][0];  // DB16
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[3][1];  // DB17
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[3][2];  // DB18
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[3][3];  // DB19
                end

                'd4 :
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[0][1];  // DB20
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[0][2];  // DB21
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[0][3];  // DB22
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[1][0];  // DB23
                end

                'd3 :
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[1][2];  // DB24
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[1][3];  // DB25
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[2][0];  // DB26
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[2][1];  // DB27
                end

                'd2 :
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[2][3];  // DB28
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[3][0];  // DB29
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[3][1];  // 0
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[3][2];  // 0
                end

                'd1 : 
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[0][0];  // PB8
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[1][1];  // PB9
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[2][2];  // PB10
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[3][3];  // PB11
                end

                default : 
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[0][0];  // HB0
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[0][2];  // HB1
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[1][0];  // HB2
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[1][2];  // HB3
                end
            endcase
        end

        // Two lanes
        else if (clk_lnk.lanes == 'd2)
        begin
            case (clk_fifo.rd_cnt[$high(clk_fifo.rd_cnt)])
                'd11 : 
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[0][1];  // PB0
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[0][3];  // PB1
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[2][1];  // PB2
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[2][3];  // PB3
                end

                'd10 : 
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[1][0];  // DB0
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[1][1];  // DB1
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[1][2];  // DB2
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[1][3];  // DB4
                end

                'd9 :
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[3][0];  // DB4
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[3][1];  // DB5
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[3][2];  // DB6
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[3][3];  // DB7
                end

                'd8 :
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[0][1];  // DB8
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[0][2];  // DB9
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[0][3];  // DB10
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[1][0];  // DB11
                end

                'd7 :
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[2][1];  // DB12
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[2][2];  // DB13
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[2][3];  // DB14
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[3][0];  // DB15
                end

                'd6 : 
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[0][0];  // PB4
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[2][0];  // PB5
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[1][1];  // PB6
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[3][1];  // PB7
                end

                'd5 :
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[1][2];  // DB16
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[1][3];  // DB17
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[0][0];  // DB18
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[0][1];  // DB19
                end

                'd4 :
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[3][2];  // DB20
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[3][3];  // DB21
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[2][0];  // DB22
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[2][1];  // DB23
                end

                'd3 :
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[0][3];  // DB24
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[1][0];  // DB25
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[1][1];  // DB26
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[1][2];  // DB27
                end

                'd2 :
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[2][3];  // DB28
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[3][0];  // DB29
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[3][1];  // 0
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[3][2];  // 0
                end

                'd1 : 
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[0][2];  // PB8
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[2][2];  // PB9
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[1][3];  // PB10
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[3][3];  // PB11
                end

                default : 
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[0][0];  // HB0
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[0][2];  // HB1
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[2][0];  // HB2
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[2][2];  // HB3
                end
            endcase
        end

        // Four lanes
        else
        begin
            case (clk_fifo.rd_cnt[$high(clk_fifo.rd_cnt)])
                'd11 : 
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[0][1];  // PB0
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[1][1];  // PB1
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[2][1];  // PB2
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[3][1];  // PB3
                end

                'd10 :
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[0][2];  // DB0
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[0][3];  // DB1
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[0][0];  // DB2
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[0][1];  // DB3
                end

                'd9 :
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[1][2];  // DB4
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[1][3];  // DB5
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[1][0];  // DB6
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[1][1];  // DB7
                end

                'd8 :
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[2][2];  // DB8
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[2][3];  // DB9
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[2][0];  // DB10
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[2][1];  // DB11
                end

                'd7 :
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[3][2];  // DB12
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[3][3];  // DB13
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[3][0];  // DB14
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[3][1];  // DB15
                end

                'd6 : 
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[0][2];  // PB4
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[1][2];  // PB5
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[2][2];  // PB6
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[3][2];  // PB7
                end

                'd5 :
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[0][3];  // DB16
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[0][0];  // DB17
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[0][1];  // DB18
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[0][2];  // DB19
                end

                'd4 :
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[1][3];  // DB20
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[1][0];  // DB21
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[1][1];  // DB22
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[1][2];  // DB23
                end

                'd3 :
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[2][3];  // DB24
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[2][0];  // DB25
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[2][1];  // DB26
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[2][2];  // DB27
                end

                'd2 :
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[3][3];  // DB28
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[3][0];  // DB29
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[3][1];  // 0
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[3][2];  // 0
                end

                'd1 : 
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[0][3];  // PB8
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[1][3];  // PB9
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[2][3];  // PB10
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[3][3];  // PB11
                end

                default : 
                begin
                    clk_sdp.dat[(0*8)+:8] <= clk_fifo.dout[0][0];  // HB0
                    clk_sdp.dat[(1*8)+:8] <= clk_fifo.dout[1][0];  // HB1
                    clk_sdp.dat[(2*8)+:8] <= clk_fifo.dout[2][0];  // HB2
                    clk_sdp.dat[(3*8)+:8] <= clk_fifo.dout[3][0];  // HB3
                end
            endcase
        end
    end

// SDP Start of packet
    always_ff @ (posedge CLK_IN)
    begin
        if (clk_fifo.rd_cnt[$high(clk_fifo.rd_cnt)] == 'd12)
            clk_sdp.sop <= 1;
        else
            clk_sdp.sop <= 0;
    end

// SDP End of packet
    always_ff @ (posedge CLK_IN)
    begin
        if (clk_fifo.rd_cnt[$high(clk_fifo.rd_cnt)] == 'd1)
            clk_sdp.eop <= 1;
        else
            clk_sdp.eop <= 0;
    end

// SDP Valid
    always_ff @ (posedge CLK_IN)
    begin
        if (clk_fifo.rd_cnt[$high(clk_fifo.rd_cnt)] != 'd0)
            clk_sdp.vld <= 1;
        else
            clk_sdp.vld <= 0;
    end

// Outputs
generate
    for (i = 0; i < P_LANES; i++)
    begin
        assign LNK_SRC_IF.sol[i]   = clk_lnk.sol[i]; 
        assign LNK_SRC_IF.eol[i]   = clk_lnk.eol[i]; 
        assign LNK_SRC_IF.vid[i]   = clk_lnk.vid[i]; 
        assign LNK_SRC_IF.sdp[i]   = 0;                  // The SDP is not passed
        assign LNK_SRC_IF.msa[i]   = 0;                  // The MSA is not passed 
        assign LNK_SRC_IF.vbid[i]  = clk_lnk.vbid[i]; 
        assign LNK_SRC_IF.k[i]     = clk_lnk.k[i];
        assign LNK_SRC_IF.dat[i]   = clk_lnk.dat[i];
    end
endgenerate

    assign LNK_SRC_IF.lock  = clk_lnk.lock;

    assign SDP_SRC_IF.sop = clk_sdp.sop;
    assign SDP_SRC_IF.eop = clk_sdp.eop;
    assign SDP_SRC_IF.dat = clk_sdp.dat;
    assign SDP_SRC_IF.vld = clk_sdp.vld;

endmodule

`default_nettype wire
