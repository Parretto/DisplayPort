/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP RX Secondary Data Packet
    (c) 2021 - 2025 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Split clock domains
    v1.2 - Added support for shorter audio samples

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
    parameter               P_SIM = 0,          // Simulation

    // Link
    parameter               P_LANES = 4,    	// Lanes
    parameter               P_SPL = 2        	// Symbols per lane
)
(
    // Control
    input wire  [1:0]       CTL_LANES_IN,       // Active lanes (1 - 1 lane / 2 - 2 lanes / 3 - 4 lanes)

    // Link
    input wire              LNK_RST_IN,         // Reset
    input wire              LNK_CLK_IN,         // Clock
    prt_dp_rx_lnk_if.snk    LNK_SNK_IF,         // Sink
    prt_dp_rx_lnk_if.src    LNK_SRC_IF,         // Source

    // Secondary data packet
    input wire              SDP_CLK_IN,         // Clock
    prt_dp_rx_sdp_if.src    SDP_SRC_IF          // Source
);

// Parameters
localparam P_DAT_FIFO_OPT = (P_SIM) ? 0 : 1;
localparam P_DAT_FIFO_WRDS = 32;
localparam P_DAT_FIFO_ADR = $clog2(P_DAT_FIFO_WRDS);
localparam P_DAT_FIFO_DAT = 4;
localparam P_LEN_FIFO_WRDS = 8;
localparam P_LEN_FIFO_ADR = $clog2(P_LEN_FIFO_WRDS);
localparam P_LEN_FIFO_DAT = 6;

// Structure
typedef struct {
    logic   [1:0]                   lanes;                  // Active lanes
    logic                           lock;                   // Lock
    logic                           run;
    logic   [6:0]                   run_clr_cnt;
    logic                           run_clr_cnt_end;
    logic                           run_clr;
    logic   [4:0]                   run_set_cnt;
    logic                           run_set_cnt_end;
    logic                           run_set;
    logic   [P_SPL-1:0]             sol[P_LANES];           // Start of line
    logic   [P_SPL-1:0]             eol[P_LANES];           // End of line
    logic   [P_SPL-1:0]             vid[P_LANES];           // Video packet
    logic   [P_SPL-1:0]             sdp[P_LANES];           // Secondary data packet
    logic   [P_SPL-1:0]             msa[P_LANES];           // Main stream attributes (msa)
    logic   [P_SPL-1:0]             vbid[P_LANES];          // VB-ID
    logic   [P_SPL-1:0]             k[P_LANES];             // k character
    logic   [7:0]                   dat[P_LANES][P_SPL];    // Data
    logic   [P_LANES-1:0]           sop;
} lnk_struct;

typedef struct {
    logic   [8:0]                   din[P_LANES][P_SPL];        // Data in
    logic   [8:0]                   din_del[P_LANES][P_SPL];    // Data
    logic   [8:0]                   dout[P_LANES][P_SPL];       // Data
    logic   [1:0]                   sel[P_LANES];
    logic   [3:0]                   wr[P_LANES];
    logic   [P_LANES-1:0]           wr_fe;
    logic   [5:0]                   len_cnt[P_LANES];           // Length counter - the maximum length of a packet is 44 bytes
} aln_struct;

typedef struct {
    logic                           clr;                    // Clear
    logic   [2:0]                   sel[4];
    logic   [1:0]                   wr[4][4];               // Write
    logic   [P_DAT_FIFO_DAT-1:0]    din[4][4][2];           // Write data (LANE - SUBLANE - NIBBLE)
} dat_fifo_wr_struct;

typedef struct {
    logic                           clr;                  // Clear
    logic   [3:0]                   wr;                  // Write
    logic   [P_LEN_FIFO_DAT-1:0]    din[4];              // Write data
} len_fifo_wr_struct;

typedef struct {
    logic                           clr;                    // Clear
    logic   [1:0]                   rd[4][4];              // Read
    logic   [P_DAT_FIFO_DAT-1:0]    dout[4][4][2];         // Read data (LANE - SUBLANE - NIBBLE)
    logic   [1:0]                   de[4][4];  
    logic   [P_DAT_FIFO_ADR:0]      wrds[4][4][2];
    logic   [1:0]                   ep[4][4];  
} dat_fifo_rd_struct;

typedef struct {
    logic                           clr;                    // Clear
    logic                           rd;                 // Read
    logic   [P_LEN_FIFO_DAT-1:0]    dout[4];             // Read data
    logic   [3:0]                   de;  
} len_fifo_rd_struct;

typedef struct {
    logic                           rst;
    logic                           run;                    // Run
    logic   [1:0]                   lanes;                  // Active lanes
    logic                           rd_len_vld;
    logic   [3:0]                   rd_cnt_in;
    logic   [3:0]                   rd_cnt;
    logic                           rd_cnt_ld;
    logic                           rd_cnt_end;
    logic   [1:0]                   rd_cnt_end_del;
    logic                           rd_cnt_str;
    logic   [1:0]                   rd_cnt_str_del;
    logic                           rd_cnt_stp;
    logic                           rd_cnt_stp_del;
    logic   [3:0]                   rd_sel;
    logic   [3:0]                   dat_sel[2];
    logic                           sop;
    logic                           eop;
    logic   [31:0]                  dat;
    logic                           vld;
} sdp_struct;

// Signals
lnk_struct          lclk_lnk; 
aln_struct          lclk_aln; 
dat_fifo_wr_struct  lclk_dat_fifo;
len_fifo_wr_struct  lclk_len_fifo;
dat_fifo_rd_struct  sclk_dat_fifo;
len_fifo_rd_struct  sclk_len_fifo;
sdp_struct          sclk_sdp;

genvar i, j, n;

// Config
    always_ff @ (posedge LNK_CLK_IN)
    begin
        lclk_lnk.lanes <= CTL_LANES_IN;
    end

// Inputs
// Combinatorial
    always_comb
    begin
        lclk_lnk.lock = LNK_SNK_IF.lock;             // Lock
        
        for (int i = 0; i < P_LANES; i++)
        begin
            lclk_lnk.sol[i]  = LNK_SNK_IF.sol[i];     // Start of line
            lclk_lnk.eol[i]  = LNK_SNK_IF.eol[i];     // End of line
            lclk_lnk.vid[i]  = LNK_SNK_IF.vid[i];     // Video
            lclk_lnk.sdp[i]  = LNK_SNK_IF.sdp[i];     // Secondary data packet
            lclk_lnk.msa[i]  = LNK_SNK_IF.msa[i];     // MSA
            lclk_lnk.vbid[i] = LNK_SNK_IF.vbid[i];    // VB-ID
            lclk_lnk.k[i]    = LNK_SNK_IF.k[i];       // k character
            lclk_lnk.dat[i]  = LNK_SNK_IF.dat[i];     // Data
        end
    end

/*
    Link Domain
*/

// Run
// When the run flag is asserted, the FIFO and the data path are operational. 
// To assure stable operation, the FIFO and data path are cleared during a video line, when there are no data packets
    always_ff @ (posedge LNK_RST_IN, posedge LNK_CLK_IN)
    begin
        // Reset
        if (LNK_RST_IN)
            lclk_lnk.run <= 0;

        else
        begin
            // Lock
            if (lclk_lnk.lock)
            begin
                // Clear
                if (lclk_lnk.run_clr)
                    lclk_lnk.run <= 0;
                
                // Set
                else if (lclk_lnk.run_set)
                    lclk_lnk.run <= 1;
            end

            else
                lclk_lnk.run <= 0;
        end
    end

// Run clear counter
// At the start of a line this run clear counter is started.
// The SDP domain could still be processing some data, which was received just befor the start of a new video line. 
// To allow some extra time for the data to be shifted out, the run flag is cleared only after the clear counter has expired. 
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Lock
        if (lclk_lnk.lock)
        begin
            // Load at start of video line
            if (|lclk_lnk.sol[0])
                lclk_lnk.run_clr_cnt <= '1;

            // Decrement
            else if (!lclk_lnk.run_clr_cnt_end)
                lclk_lnk.run_clr_cnt <= lclk_lnk.run_clr_cnt - 'd1;
        end
    
        else
            lclk_lnk.run_clr_cnt <= 0;
    end

// Run clear counter end
    always_comb
    begin
        if (lclk_lnk.run_clr_cnt == 0)
            lclk_lnk.run_clr_cnt_end = 1;
        else            
            lclk_lnk.run_clr_cnt_end = 0;
    end

// Run clear counter end rising edge
    prt_dp_lib_edge
    LCLK_RUN_CLR_EDGE_INST
    (
        .CLK_IN     (LNK_CLK_IN),                   // Clock
        .CKE_IN     (1'b1),                         // Clock enable
        .A_IN       (lclk_lnk.run_clr_cnt_end),     // Input
        .RE_OUT     (lclk_lnk.run_clr),             // Rising edge
        .FE_OUT     ()                              // Falling edge
    );

// Run set counter
// After the run flag has been cleared,
// this counter delays the assertion of the run flag,
// to ensure enough time for the run flag to pass to the SDP clock domain. 
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Lock
        if (lclk_lnk.lock)
        begin
            // Load at run clear
            if (lclk_lnk.run_clr)
                lclk_lnk.run_set_cnt <= '1;

            // Decrement
            else if (!lclk_lnk.run_set_cnt_end)
                lclk_lnk.run_set_cnt <= lclk_lnk.run_set_cnt - 'd1;
        end
    
        else
            lclk_lnk.run_set_cnt <= 0;
    end

// Run clear counter end
    always_comb
    begin
        if (lclk_lnk.run_set_cnt == 0)
            lclk_lnk.run_set_cnt_end = 1;
        else            
            lclk_lnk.run_set_cnt_end = 0;
    end

// Run clear counter end rising edge
    prt_dp_lib_edge
    LCLK_RUN_SET_EDGE_INST
    (
        .CLK_IN     (LNK_CLK_IN),                   // Clock
        .CKE_IN     (1'b1),                         // Clock enable
        .A_IN       (lclk_lnk.run_set_cnt_end),     // Input
        .RE_OUT     (lclk_lnk.run_set),             // Rising edge
        .FE_OUT     ()                              // Falling edge
    );

// SDP edge detector
// The rising edge is used to detect the incoming phase
generate
    for (i = 0; i < P_LANES; i++)
    begin
        prt_dp_lib_edge
        LCLK_SDP_EDGE_INST
        (
            .CLK_IN     (LNK_CLK_IN),        // Clock
            .CKE_IN     (1'b1),              // Clock enable
            .A_IN       (|lclk_lnk.sdp[i]),  // Input
            .RE_OUT     (lclk_lnk.sop[i]),   // Rising edge
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
            assign lclk_aln.din[i][j] = {lclk_lnk.sdp[i][j], lclk_lnk.dat[i][j]}; 

            always_ff @ (posedge LNK_CLK_IN)
            begin
                lclk_aln.din_del[i][j]  <= lclk_aln.din[i][j];
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
            always_ff @ (posedge LNK_CLK_IN)
            begin
                // Run
                if (lclk_lnk.run)
                begin
                    if (lclk_lnk.sop[i])
                    begin
                        case (lclk_lnk.sdp[i])
                            'b10    : lclk_aln.sel[i] <= 'd1;
                            default : lclk_aln.sel[i] <= 'd0;
                        endcase
                    end
                end

                else
                    lclk_aln.sel[i] <= 0;
            end
        end
    end

    // Four symbols per lane
    else
    begin : gen_aln_sel_4spl
        for (i = 0; i < P_LANES; i++)
        begin
            always_ff @ (posedge LNK_CLK_IN)
            begin
                // Run
                if (lclk_lnk.run)
                begin
                    if (lclk_lnk.sop[i])
                    begin
                        case (lclk_lnk.sdp[i])
                            'b1110  : lclk_aln.sel[i] <= 'd1;
                            'b1100  : lclk_aln.sel[i] <= 'd2;
                            'b1000  : lclk_aln.sel[i] <= 'd3;
                            default : lclk_aln.sel[i] <= 'd0;
                        endcase
                    end
                end

                else
                    lclk_aln.sel[i] <= 0;
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
                case (lclk_aln.sel[i])

                    // Phase 1
                    'd1 : 
                    begin
                        lclk_aln.dout[i][0] = lclk_aln.din_del[i][1];
                        lclk_aln.dout[i][1] = lclk_aln.din[i][0];
                    end

                    // Phase 0
                    default : 
                    begin
                        lclk_aln.dout[i][0] = lclk_aln.din_del[i][0];
                        lclk_aln.dout[i][1] = lclk_aln.din_del[i][1];
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
                case (lclk_aln.sel[i])

                    // Phase 1
                    'd1 : 
                    begin
                        lclk_aln.dout[i][0] = lclk_aln.din_del[i][1];
                        lclk_aln.dout[i][1] = lclk_aln.din_del[i][2];
                        lclk_aln.dout[i][2] = lclk_aln.din_del[i][3];
                        lclk_aln.dout[i][3] = lclk_aln.din[i][0];
                    end

                    // Phase 2
                    'd2 : 
                    begin
                        lclk_aln.dout[i][0] = lclk_aln.din_del[i][2];
                        lclk_aln.dout[i][1] = lclk_aln.din_del[i][3];
                        lclk_aln.dout[i][2] = lclk_aln.din[i][0];
                        lclk_aln.dout[i][3] = lclk_aln.din[i][1];
                    end

                    // Phase 3
                    'd3 : 
                    begin
                        lclk_aln.dout[i][0] = lclk_aln.din_del[i][3];
                        lclk_aln.dout[i][1] = lclk_aln.din[i][0];
                        lclk_aln.dout[i][2] = lclk_aln.din[i][1];
                        lclk_aln.dout[i][3] = lclk_aln.din[i][2];
                    end

                    // Phase 0
                    default : 
                    begin
                        lclk_aln.dout[i][0] = lclk_aln.din_del[i][0];
                        lclk_aln.dout[i][1] = lclk_aln.din_del[i][1];
                        lclk_aln.dout[i][2] = lclk_aln.din_del[i][2];
                        lclk_aln.dout[i][3] = lclk_aln.din_del[i][3];
                    end
                endcase
            end
        end
    end
endgenerate

// Aligner write
always_comb
begin
    for (int i = 0; i < P_LANES; i++)
    begin
        for (int j = 0; j < P_SPL; j++)
        begin
            // The msb of the aligner data is the SDP
            // During the SOP, the aligner select is updated.
            if (!lclk_lnk.sop[i] && lclk_aln.dout[i][j][8])
                lclk_aln.wr[i][j] = 1;
            else
                lclk_aln.wr[i][j] = 0;
        end
    end
end

// Alignment write edge
// The falling edge is used to clear the fifo select.
generate
    for (i = 0; i < P_LANES; i++)
    begin
        prt_dp_lib_edge
        LCLK_ALN_WR_EDGE_INST
        (
            .CLK_IN     (LNK_CLK_IN),            // Clock
            .CKE_IN     (1'b1),                  // Clock enable
            .A_IN       (|lclk_aln.wr[i]),        // Input
            .RE_OUT     (),                      // Rising edge
            .FE_OUT     (lclk_aln.wr_fe[i])      // Falling edge
        );
    end
endgenerate

// Length counter
// The length counter is used to count the length of a packet. 
// At the end of the packet, the length is written into the length FIFO.
// As the lanes are unaligned, each lane has it's own length FIFO and counter.
generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_aln_len_cnt
        
        always_ff @ (posedge LNK_CLK_IN)
        begin
            // Run
            if (lclk_lnk.run)
            begin
                // Clear
                if (lclk_aln.wr_fe[i])
                    lclk_aln.len_cnt[i] <= 0;

                // Increment
                // Here the data is aligned, so there are only four combinations.
                else if (|lclk_aln.wr[i])
                begin
                    if (lclk_aln.wr[i] == 'b1111)
                        lclk_aln.len_cnt[i] <= lclk_aln.len_cnt[i] + 'd4;

                    else if (lclk_aln.wr[i] == 'b0001)
                        lclk_aln.len_cnt[i] <= lclk_aln.len_cnt[i] + 'd1;

                    else if (lclk_aln.wr[i] == 'b0011)
                        lclk_aln.len_cnt[i] <= lclk_aln.len_cnt[i] + 'd2;

                    else if (lclk_aln.wr[i] == 'b0111)
                        lclk_aln.len_cnt[i] <= lclk_aln.len_cnt[i] + 'd3;
                end
            end

            // Idle
            else
                lclk_aln.len_cnt[i] <= 0;
        end
    end
endgenerate

//  FIFO clear
    always_ff @ (posedge LNK_CLK_IN)
    begin
        if (lclk_lnk.run)
            lclk_dat_fifo.clr <= 0;
        else
            lclk_dat_fifo.clr <= 1;
    end
  
// Data FIFO Select
    always_ff @ (posedge LNK_CLK_IN)
    begin
        if (lclk_lnk.run)
        begin
            // One lane
            if (lclk_lnk.lanes == 'd1)
            begin
                // Clear 
                if (lclk_aln.wr_fe[0])
                        lclk_dat_fifo.sel[0] <= 'd0;

                // Increment
                else if (|lclk_aln.wr[0])
                begin
                    if (((P_SPL == 4) && (lclk_dat_fifo.sel[0] == 'd3)) || ((P_SPL == 2) && (lclk_dat_fifo.sel[0] == 'd7)))
                        lclk_dat_fifo.sel[0] <= 'd0;
                    else
                        lclk_dat_fifo.sel[0] <= lclk_dat_fifo.sel[0] + 'd1;
                end

                // Not used
                for (int i = 1; i < 4; i++)
                    lclk_dat_fifo.sel[i] <= 0;
            end

            // Two lanes
            else if (lclk_lnk.lanes == 'd2)
            begin
                for (int i = 0; i < 2; i++)
                begin
                    // Clear 
                    if (lclk_aln.wr_fe[i])
                        lclk_dat_fifo.sel[i] <= 'd0;

                    // Increment
                    else if (|lclk_aln.wr[i])
                    begin
                        if (((P_SPL == 4) && (lclk_dat_fifo.sel[i] == 'd1)) || ((P_SPL == 2) && (lclk_dat_fifo.sel[i] == 'd3)))
                            lclk_dat_fifo.sel[i] <= 'd0;
                        else
                            lclk_dat_fifo.sel[i] <= lclk_dat_fifo.sel[i] + 'd1;
                    end
                end

                // Not used
                for (int i = 2; i < 4; i++)
                    lclk_dat_fifo.sel[i] <= 0;
            end

            // Four lanes
            else
            begin
                for (int i = 0; i < 4; i++)
                begin                    
                    // Four lanes
                    if (P_SPL == 4)
                        lclk_dat_fifo.sel[i] <= 0;
                    
                    // Two lanes
                    else
                    begin
                        // Clear 
                        if (lclk_aln.wr_fe[i])
                            lclk_dat_fifo.sel[i] <= 'd0;

                        // Increment
                        else if (|lclk_aln.wr[i])
                        begin
                            if (lclk_dat_fifo.sel[i] == 'd1)
                                lclk_dat_fifo.sel[i] <= 0;
                            else
                                lclk_dat_fifo.sel[i] <= lclk_dat_fifo.sel[i] + 'd1;
                        end
                    end
                end
            end
        end

        // Idle
        else
        begin
            for (int i = 0; i < 4; i++)
                lclk_dat_fifo.sel[i] <= 0;
        end
    end

// Data FIFO Write and write data
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
                    for (int n = 0; n < 2; n++)
                    begin
                        lclk_dat_fifo.wr[i][j][n] = 0;
                        lclk_dat_fifo.din[i][j][n] = 0;
                    end
                end
            end

            // One lane
            if (lclk_lnk.lanes == 'd1)
            begin
                case (lclk_dat_fifo.sel[0])

                    'd1 :  
                    begin
                        for (int j = 0; j < 2; j++)
                        begin
                            for (int n = 0; n < 2; n++)
                            begin
                                lclk_dat_fifo.wr[0][j+2][n] = lclk_aln.wr[0][j];
                                lclk_dat_fifo.din[0][j+2][n] = lclk_aln.dout[0][j][(n*4)+:4];
                            end
                        end
                    end

                    'd2 :  
                    begin
                        for (int j = 0; j < 2; j++)
                        begin
                            for (int n = 0; n < 2; n++)
                            begin
                                lclk_dat_fifo.wr[1][j][n] = lclk_aln.wr[0][j];
                                lclk_dat_fifo.din[1][j][n] = lclk_aln.dout[0][j][(n*4)+:4];
                            end
                        end
                    end

                    'd3 :  
                    begin
                        for (int j = 0; j < 2; j++)
                        begin
                            for (int n = 0; n < 2; n++)
                            begin
                                lclk_dat_fifo.wr[1][j+2][n] = lclk_aln.wr[0][j];
                                lclk_dat_fifo.din[1][j+2][n] = lclk_aln.dout[0][j][(n*4)+:4];
                            end
                        end
                    end

                    'd4 :  
                    begin
                        for (int j = 0; j < 2; j++)
                        begin
                            for (int n = 0; n < 2; n++)
                            begin
                                lclk_dat_fifo.wr[2][j][n] = lclk_aln.wr[0][j];
                                lclk_dat_fifo.din[2][j][n] = lclk_aln.dout[0][j][(n*4)+:4];
                            end
                        end
                    end

                    'd5 :  
                    begin
                        for (int j = 0; j < 2; j++)
                        begin
                            for (int n = 0; n < 2; n++)
                            begin
                                lclk_dat_fifo.wr[2][j+2][n] = lclk_aln.wr[0][j];
                                lclk_dat_fifo.din[2][j+2][n] = lclk_aln.dout[0][j][(n*4)+:4];
                            end
                        end
                    end

                    'd6 :  
                    begin
                        for (int j = 0; j < 2; j++)
                        begin
                            for (int n = 0; n < 2; n++)
                            begin
                                lclk_dat_fifo.wr[3][j][n] = lclk_aln.wr[0][j];
                                lclk_dat_fifo.din[3][j][n] = lclk_aln.dout[0][j][(n*4)+:4];
                            end
                        end
                    end

                    'd7 :  
                    begin
                        for (int j = 0; j < 2; j++)
                        begin
                            for (int n = 0; n < 2; n++)
                            begin
                                lclk_dat_fifo.wr[3][j+2][n] = lclk_aln.wr[0][j];
                                lclk_dat_fifo.din[3][j+2][n] = lclk_aln.dout[0][j][(n*4)+:4];
                            end
                        end
                    end

                    default :  
                    begin
                        for (int j = 0; j < 2; j++)
                        begin
                            for (int n = 0; n < 2; n++)
                            begin
                                lclk_dat_fifo.wr[0][j][n] = lclk_aln.wr[0][j];
                                lclk_dat_fifo.din[0][j][n] = lclk_aln.dout[0][j][(n*4)+:4];
                            end
                        end
                    end
                endcase
            end

            // Two lanes
            else if (lclk_lnk.lanes == 'd2)
            begin
                for (int i = 0; i < 2; i++)
                begin
                    case (lclk_dat_fifo.sel[i])
                        'd1 :
                        begin
                            for (int j = 0; j < 2; j++)
                            begin
                                for (int n = 0; n < 2; n++)
                                begin
                                    lclk_dat_fifo.wr[i*2][j+2][n] = lclk_aln.wr[i][j];
                                    lclk_dat_fifo.din[i*2][j+2][n] = lclk_aln.dout[i][j][(n*4)+:4];
                                end
                            end
                        end

                        'd2 :
                        begin
                            for (int j = 0; j < 2; j++)
                            begin
                                for (int n = 0; n < 2; n++)
                                begin
                                    lclk_dat_fifo.wr[(i*2)+1][j][n] = lclk_aln.wr[i][j];
                                    lclk_dat_fifo.din[(i*2)+1][j][n] = lclk_aln.dout[i][j][(n*4)+:4];
                                end
                            end
                        end

                        'd3 :
                        begin
                            for (int j = 0; j < 2; j++)
                            begin
                                for (int n = 0; n < 2; n++)
                                begin
                                    lclk_dat_fifo.wr[(i*2)+1][j+2][n] = lclk_aln.wr[i][j];
                                    lclk_dat_fifo.din[(i*2)+1][j+2][n] = lclk_aln.dout[i][j][(n*4)+:4];
                                end
                            end
                        end

                        default : 
                        begin
                            for (int j = 0; j < 2; j++)
                            begin
                                for (int n = 0; n < 2; n++)
                                begin
                                    lclk_dat_fifo.wr[i*2][j][n] = lclk_aln.wr[i][j];
                                    lclk_dat_fifo.din[i*2][j][n] = lclk_aln.dout[i][j][(n*4)+:4];
                                end
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
                        for (int n = 0; n < 2; n++)
                        begin
                            if (lclk_dat_fifo.sel[i] == 'd1)
                            begin
                                lclk_dat_fifo.wr[i][j+2][n] = lclk_aln.wr[i][j];
                                lclk_dat_fifo.din[i][j+2][n] = lclk_aln.dout[i][j][(n*4)+:4];
                            end

                            else
                            begin
                                lclk_dat_fifo.wr[i][j][n] = lclk_aln.wr[i][j];
                                lclk_dat_fifo.din[i][j][n] = lclk_aln.dout[i][j][(n*4)+:4];
                            end
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
                    for (int n = 0; n < 2; n++)
                    begin
                        lclk_dat_fifo.wr[i][j][n] = 0;
                        lclk_dat_fifo.din[i][j][n] = 0;
                    end
                end
            end

            // One lane
            if (lclk_lnk.lanes == 'd1)
            begin
                case (lclk_dat_fifo.sel[0])

                    'd1 :  
                    begin
                        for (int j = 0; j < 4; j++)
                        begin
                            for (int n = 0; n < 2; n++)
                            begin
                                lclk_dat_fifo.wr[1][j][n] = lclk_aln.wr[0][j];
                                lclk_dat_fifo.din[1][j][n] = lclk_aln.dout[0][j][(n*4)+:4];
                            end
                        end
                    end

                    'd2 :  
                    begin
                        for (int j = 0; j < 4; j++)
                        begin
                            for (int n = 0; n < 2; n++)
                            begin
                                lclk_dat_fifo.wr[2][j][n] = lclk_aln.wr[0][j];
                                lclk_dat_fifo.din[2][j][n] = lclk_aln.dout[0][j][(n*4)+:8];
                            end
                        end
                    end

                    'd3 :  
                    begin
                        for (int j = 0; j < 4; j++)
                        begin
                            for (int n = 0; n < 2; n++)
                            begin
                                lclk_dat_fifo.wr[3][j][n] = lclk_aln.wr[0][j];
                                lclk_dat_fifo.din[3][j][n] = lclk_aln.dout[0][j][(n*4)+:4];
                            end
                        end
                    end

                    default :  
                    begin
                        for (int j = 0; j < 4; j++)
                        begin
                            for (int n = 0; n < 2; n++)
                            begin
                                lclk_dat_fifo.wr[0][j][n] = lclk_aln.wr[0][j];
                                lclk_dat_fifo.din[0][j][n] = lclk_aln.dout[0][j][(n*4)+:4];
                            end
                        end
                    end
                endcase
            end

            // Two lanes
            else if (lclk_lnk.lanes == 'd2)
            begin
                for (int i = 0; i < 2; i++)
                begin
                    if (lclk_dat_fifo.sel[i] == 'd1)
                    begin
                        for (int j = 0; j < 4; j++)
                        begin
                            for (int n = 0; n < 2; n++)
                            begin
                                lclk_dat_fifo.wr[(i*2)+1][j][n] = lclk_aln.wr[i][j];
                                lclk_dat_fifo.din[(i*2)+1][j][n] = lclk_aln.dout[i][j][(n*4)+:4]; 
                            end
                        end
                    end

                    else
                    begin
                        for (int j = 0; j < 4; j++)
                        begin
                            for (int n = 0; n < 2; n++)
                            begin
                                lclk_dat_fifo.wr[i*2][j][n] = lclk_aln.wr[i][j];
                                lclk_dat_fifo.din[i*2][j][n] = lclk_aln.dout[i][j][(n*4)+:4]; 
                            end
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
                        for (int n = 0; n < 2; n++)
                        begin
                            lclk_dat_fifo.wr[i][j][n] = lclk_aln.wr[i][j];
                            lclk_dat_fifo.din[i][j][n] = lclk_aln.dout[i][j][(n*4)+:4]; 
                        end
                    end
                end
            end
        end
    end
endgenerate

// Data FIFO
// The DATA FIFO stores the actual data.
generate
    // Lanes
    for (i = 0; i < 4; i++)
    begin : gen_dat_fifo_l
        
        // Sublanes
        for (j = 0; j < 4; j++)
        begin : gen_dat_fifo_s
            
            // Nibbles
            for (n = 0; n < 2; n++)
            begin : gen_dat_fifo_n
                
                prt_dp_lib_fifo_dc
                #(
                    .P_VENDOR       (P_VENDOR),             // Vendor
                    .P_MODE         ("burst"),		        // "single" or "burst"
                    .P_RAM_STYLE	("distributed"),	    // "distributed" or "block"
                    .P_OPT 			(P_DAT_FIFO_OPT),		// In optimized mode the status port are not available. This saves some logic.
                    .P_ADR_WIDTH	(P_DAT_FIFO_ADR),
                    .P_DAT_WIDTH	(P_DAT_FIFO_DAT)
                )
                DAT_FIFO_INST
                (
                    .A_RST_IN      (LNK_RST_IN),                    // Reset
                    .B_RST_IN      (sclk_sdp.rst),
                    .A_CLK_IN      (LNK_CLK_IN),                    // Clock
                    .B_CLK_IN      (SDP_CLK_IN),
                    .A_CKE_IN      (1'b1),                          // Clock enable
                    .B_CKE_IN      (1'b1),

                    // Input (A)
                    .A_CLR_IN      (lclk_dat_fifo.clr),             // Clear
                    .A_WR_IN       (lclk_dat_fifo.wr[i][j][n]),     // Write
                    .A_DAT_IN      (lclk_dat_fifo.din[i][j][n]),    // Write data

                    // Output (B)
                    .B_CLR_IN      (sclk_dat_fifo.clr),             // Clear
                    .B_RD_IN       (sclk_dat_fifo.rd[i][j][n]),     // Read
                    .B_DAT_OUT     (sclk_dat_fifo.dout[i][j][n]),   // Read data
                    .B_DE_OUT      (sclk_dat_fifo.de[i][j][n]),     // Data enable

                    // Status (A)
                    .A_WRDS_OUT    (),                              // Used words
                    .A_FL_OUT      (),                              // Full
                    .A_EP_OUT      (),                              // Empty

                    // Status (B)
                    .B_WRDS_OUT    (sclk_dat_fifo.wrds[i][j][n]),   // Used words
                    .B_FL_OUT      (),                              // Full
                    .B_EP_OUT      (sclk_dat_fifo.ep[i][j][n])      // Empty
                );
            end
        end
    end
endgenerate


//  Length FIFO clear
    always_ff @ (posedge LNK_CLK_IN)
    begin
        if (lclk_lnk.run)
            lclk_len_fifo.clr <= 0;
        else
            lclk_len_fifo.clr <= 1;
    end

// Write and data
generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_len_fifo_wr
        assign lclk_len_fifo.wr[i] = lclk_aln.wr_fe[i];
        assign lclk_len_fifo.din[i] = lclk_aln.len_cnt[i];
    end
endgenerate

// Length FIFO
// The length FIFO stores the length of a packet. 
// Because the lanes are unaligned, each lane has it's own FIFO. 
generate
    for (i = 0; i < 4; i++)
    begin : gen_len_fifo
        prt_dp_lib_fifo_dc
        #(
            .P_VENDOR       (P_VENDOR),             // Vendor
            .P_MODE         ("single"),		        // "single" or "burst"
            .P_RAM_STYLE	("distributed"),	    // "distributed" or "block"
            .P_OPT 			(0),			        // In optimized mode the status port are not available. This saves some logic.
            .P_ADR_WIDTH	(P_LEN_FIFO_ADR),
            .P_DAT_WIDTH	(P_LEN_FIFO_DAT)
        )
        LEN_FIFO_INST
        (
            .A_RST_IN      (LNK_RST_IN),                    // Reset
            .B_RST_IN      (sclk_sdp.rst),
            .A_CLK_IN      (LNK_CLK_IN),                    // Clock
            .B_CLK_IN      (SDP_CLK_IN),
            .A_CKE_IN      (1'b1),                          // Clock enable
            .B_CKE_IN      (1'b1),

            // Input (A)
            .A_CLR_IN      (lclk_len_fifo.clr),             // Clear
            .A_WR_IN       (lclk_len_fifo.wr[i]),           // Write
            .A_DAT_IN      (lclk_len_fifo.din[i]),          // Write data

            // Output (B)
            .B_CLR_IN      (sclk_len_fifo.clr),             // Clear
            .B_RD_IN       (sclk_len_fifo.rd),              // Read
            .B_DAT_OUT     (sclk_len_fifo.dout[i]),         // Read data
            .B_DE_OUT      (sclk_len_fifo.de[i]),           // Data enable

            // Status (A)
            .A_WRDS_OUT    (),                              // Used words
            .A_FL_OUT      (),                              // Full
            .A_EP_OUT      (),                              // Empty

            // Status (B)
            .B_WRDS_OUT    (),                              // Used words
            .B_FL_OUT      (),                              // Full
            .B_EP_OUT      ()                               // Empty
        );
    end
endgenerate

// Reset
    prt_dp_lib_rst
    SCLK_SDP_RST_INST
    (
        .SRC_RST_IN     (LNK_RST_IN),
        .SRC_CLK_IN     (LNK_CLK_IN),
        .DST_CLK_IN     (SDP_CLK_IN),
        .DST_RST_OUT    (sclk_sdp.rst)
    );

    // Run CDC
    prt_dp_lib_cdc_bit
    SCLK_RUN_CSC_INST
    (       
        .SRC_CLK_IN     (LNK_CLK_IN),		// Clock
        .SRC_DAT_IN     (lclk_lnk.run),	    // Data
        .DST_CLK_IN     (SDP_CLK_IN),		// Clock
        .DST_DAT_OUT	(sclk_sdp.run)	    // Data
    );

    // Lanes CDC
    prt_dp_lib_cdc_vec
    #(
	    .P_WIDTH        ($size(lclk_lnk.lanes))
    )
    SCLK_LANES_CDC_INST
    (
        .SRC_CLK_IN     (LNK_CLK_IN),		// Clock
        .SRC_DAT_IN     (lclk_lnk.lanes),	// Data
        .DST_CLK_IN     (SDP_CLK_IN),		// Clock
        .DST_DAT_OUT    (sclk_sdp.lanes)	// Data
    );
    
/*
    SDP Domain
*/

// Data FIFO clear
    always_ff @ (posedge SDP_CLK_IN)
    begin
        if (sclk_sdp.run)
            sclk_dat_fifo.clr <= 0;
        else
            sclk_dat_fifo.clr <= 1;
    end

// Length FIFO clear
    always_ff @ (posedge SDP_CLK_IN)
    begin
        if (sclk_sdp.run)
            sclk_len_fifo.clr <= 0;
        else
            sclk_len_fifo.clr <= 1;
    end

// Read counter length 
    always_ff @ (posedge SDP_CLK_IN)
    begin
        // Default
        sclk_sdp.rd_cnt_in <= 'd0;
        sclk_sdp.rd_len_vld <= 0;

        // One lane
        if (sclk_sdp.lanes == 'd1)
        begin
            if (sclk_len_fifo.de[0])
            begin    
                // Short audio sample packet
                if (sclk_len_fifo.dout[0] == 'd28)
                    sclk_sdp.rd_cnt_in <= 'd7;
                
                // 'Normal' packet
                else
                    sclk_sdp.rd_cnt_in <= 'd12;

                sclk_sdp.rd_len_vld <= 1;
            end
        end

        // Two Lanes
        else if (sclk_sdp.lanes == 'd2)
        begin
            if (&sclk_len_fifo.de[1:0])
            begin    
                // Short audio sample packet
                if (sclk_len_fifo.dout[0] == 'd14)
                    sclk_sdp.rd_cnt_in <= 'd7;
                
                // 'Normal' packet
                else
                    sclk_sdp.rd_cnt_in <= 'd12;

                sclk_sdp.rd_len_vld <= 1;
            end
        end

        // Four lanes
        else 
        begin
            if (&sclk_len_fifo.de)
            begin    
                // Short audio sample packet
                if (sclk_len_fifo.dout[0] == 'd7)
                    sclk_sdp.rd_cnt_in <= 'd7;
                
                // 'Normal' packet
                else
                    sclk_sdp.rd_cnt_in <= 'd12;

                sclk_sdp.rd_len_vld <= 1;
            end
        end
    end

// Read counter load
    always_comb
    begin
        // Wait for read counter to be completed and new read counter length
        if (sclk_sdp.rd_cnt_end && sclk_sdp.rd_len_vld)
            sclk_sdp.rd_cnt_ld = 1;
        else
            sclk_sdp.rd_cnt_ld = 0;
    end

// Read counter
    always_ff @ (posedge SDP_CLK_IN)
    begin
        // Run
        if (sclk_sdp.run)
        begin
            // Load
            if (sclk_sdp.rd_cnt_ld)
                sclk_sdp.rd_cnt <= sclk_sdp.rd_cnt_in; 

            // Decrement
            else if (!sclk_sdp.rd_cnt_end)
                sclk_sdp.rd_cnt <= sclk_sdp.rd_cnt - 'd1;
        end

        // Idle
        else
            sclk_sdp.rd_cnt <= 0;
    end

// Read counter end
    always_comb
    begin
        if (sclk_sdp.rd_cnt == 0)
            sclk_sdp.rd_cnt_end = 1;
        else
            sclk_sdp.rd_cnt_end = 0;
    end

// Read counter end edge
// This is used for the packet SOP and EOP
    prt_dp_lib_edge
    SCLK_CNT_END_EDGE_INST
    (
        .CLK_IN     (SDP_CLK_IN),                   // Clock
        .CKE_IN     (1'b1),                         // Clock enable
        .A_IN       (sclk_sdp.rd_cnt_end),          // Input
        .RE_OUT     (sclk_sdp.rd_cnt_stp),          // Rising edge
        .FE_OUT     (sclk_sdp.rd_cnt_str)           // Falling edge
    );

// Read counter end, start and stop must be delayed to match the DATA FIFO latency
    always_ff @ (posedge SDP_CLK_IN)
    begin
        sclk_sdp.rd_cnt_end_del <= {sclk_sdp.rd_cnt_end_del[0], sclk_sdp.rd_cnt_end};
        sclk_sdp.rd_cnt_str_del <= {sclk_sdp.rd_cnt_str_del[0], sclk_sdp.rd_cnt_str};
        sclk_sdp.rd_cnt_stp_del <= sclk_sdp.rd_cnt_stp;
    end

// Length FIFO read
    always_comb
    begin
        if (sclk_sdp.rd_cnt_ld)
            sclk_len_fifo.rd = 1;
        else
            sclk_len_fifo.rd = 0;
    end

// Read select
    always_ff @ (posedge SDP_CLK_IN)
    begin
        if (!sclk_sdp.rd_cnt_end)
            sclk_sdp.rd_sel <= sclk_sdp.rd_sel + 'd1;
        else
            sclk_sdp.rd_sel <= 0;
    end

// Data select 
    always_ff @ (posedge SDP_CLK_IN)
    begin
        for (int i = 0; i < $size(sclk_sdp.dat_sel); i++)
        begin
            if (i == 0)
                sclk_sdp.dat_sel[i] <= sclk_sdp.rd_sel;
            else
                sclk_sdp.dat_sel[i] <= sclk_sdp.dat_sel[i-1];
        end
    end

// Data FIFO read
    always_comb
    begin
        // Default
        for (int i = 0; i < 4; i++)
        begin 
            for (int j = 0; j < 4; j++)
            begin
                for (int n = 0; n < 2; n++)
                    sclk_dat_fifo.rd[i][j][n] = 0;
            end
        end

        if (!sclk_sdp.rd_cnt_end)
        begin
            // One lane
            if (sclk_sdp.lanes == 'd1)
            begin
                case (sclk_sdp.rd_sel)
                    'd1 : 
                    begin
                        sclk_dat_fifo.rd[0][1][0] = 1;  // PB0[3:0]
                        sclk_dat_fifo.rd[0][3][1] = 1;  // PB0[7:4]
                        sclk_dat_fifo.rd[0][1][1] = 1;  // PB1[3:0]
                        sclk_dat_fifo.rd[0][3][0] = 1;  // PB1[7:4]
                        sclk_dat_fifo.rd[1][1][0] = 1;  // PB2[3:0]
                        sclk_dat_fifo.rd[1][3][1] = 1;  // PB2[7:4]
                        sclk_dat_fifo.rd[1][1][1] = 1;  // PB3[3:0]
                        sclk_dat_fifo.rd[1][3][0] = 1;  // PB3[7:4]
                    end

                    'd2 : 
                    begin
                        sclk_dat_fifo.rd[2][0][0] = 1;  // DB0[3:0]
                        sclk_dat_fifo.rd[3][1][1] = 1;  // DB0[7:4]
                        sclk_dat_fifo.rd[2][1][0] = 1;  // DB1[3:0]
                        sclk_dat_fifo.rd[3][2][1] = 1;  // DB1[7:4]
                        sclk_dat_fifo.rd[2][2][0] = 1;  // DB2[3:0]
                        sclk_dat_fifo.rd[3][3][1] = 1;  // DB2[7:4]
                        sclk_dat_fifo.rd[2][3][0] = 1;  // DB3[3:0]
                        sclk_dat_fifo.rd[0][0][1] = 1;  // DB3[7:4]
                    end

                    'd3 :
                    begin
                        sclk_dat_fifo.rd[2][0][1] = 1;  // DB4[3:0]
                        sclk_dat_fifo.rd[3][1][0] = 1;  // DB4[7:4]
                        sclk_dat_fifo.rd[2][1][1] = 1;  // DB5[3:0]
                        sclk_dat_fifo.rd[3][2][0] = 1;  // DB5[7:4]
                        sclk_dat_fifo.rd[2][2][1] = 1;  // DB6[3:0]
                        sclk_dat_fifo.rd[3][3][0] = 1;  // DB6[7:4]
                        sclk_dat_fifo.rd[2][3][1] = 1;  // DB7[3:0]
                        sclk_dat_fifo.rd[0][0][0] = 1;  // DB7[7:4]
                    end

                    'd4 :
                    begin
                        sclk_dat_fifo.rd[0][2][0] = 1;  // DB8[3:0]
                        sclk_dat_fifo.rd[1][3][1] = 1;  // DB8[7:4]
                        sclk_dat_fifo.rd[0][3][0] = 1;  // DB9[3:0]
                        sclk_dat_fifo.rd[2][0][1] = 1;  // DB9[7:4]
                        sclk_dat_fifo.rd[1][0][0] = 1;  // DB10[3:0]
                        sclk_dat_fifo.rd[2][1][1] = 1;  // DB10[7:4]
                        sclk_dat_fifo.rd[1][1][0] = 1;  // DB11[3:0]
                        sclk_dat_fifo.rd[2][2][1] = 1;  // DB11[7:4]
                    end

                    'd5 :
                    begin
                        sclk_dat_fifo.rd[0][2][1] = 1;  // DB12[3:0]
                        sclk_dat_fifo.rd[1][3][0] = 1;  // DB12[7:4]
                        sclk_dat_fifo.rd[0][3][1] = 1;  // DB13[3:0]
                        sclk_dat_fifo.rd[2][0][0] = 1;  // DB13[7:4]
                        sclk_dat_fifo.rd[1][0][1] = 1;  // DB14[3:0]
                        sclk_dat_fifo.rd[2][1][0] = 1;  // DB14[7:4]
                        sclk_dat_fifo.rd[1][1][1] = 1;  // DB15[3:0]
                        sclk_dat_fifo.rd[2][2][0] = 1;  // DB15[7:4]
                    end

                    'd6 : 
                    begin
                        sclk_dat_fifo.rd[3][0][0] = 1;  // PB4[3:0]
                        sclk_dat_fifo.rd[0][1][1] = 1;  // PB4[7:4]
                        sclk_dat_fifo.rd[3][0][1] = 1;  // PB5[3:0]
                        sclk_dat_fifo.rd[0][1][0] = 1;  // PB5[7:4]
                        sclk_dat_fifo.rd[1][2][0] = 1;  // PB6[3:0]
                        sclk_dat_fifo.rd[2][3][1] = 1;  // PB6[7:4]
                        sclk_dat_fifo.rd[1][2][1] = 1;  // PB7[3:0]
                        sclk_dat_fifo.rd[2][3][0] = 1;  // PB7[7:4]
                    end

                    'd7 :
                    begin
                        sclk_dat_fifo.rd[3][0][0] = 1;  // DB16[3:0]
                        sclk_dat_fifo.rd[0][1][1] = 1;  // DB16[7:4]
                        sclk_dat_fifo.rd[3][1][0] = 1;  // DB17[3:0]
                        sclk_dat_fifo.rd[0][2][1] = 1;  // DB17[7:4]
                        sclk_dat_fifo.rd[3][2][0] = 1;  // DB18[3:0]
                        sclk_dat_fifo.rd[0][3][1] = 1;  // DB18[7:4]
                        sclk_dat_fifo.rd[3][3][0] = 1;  // DB19[3:0]
                        sclk_dat_fifo.rd[1][0][1] = 1;  // DB19[7:4]
                    end

                    'd8 :
                    begin
                        sclk_dat_fifo.rd[3][0][1] = 1;  // DB20[3:0]
                        sclk_dat_fifo.rd[0][1][0] = 1;  // DB20[7:4]
                        sclk_dat_fifo.rd[3][1][1] = 1;  // DB21[3:0]
                        sclk_dat_fifo.rd[0][2][0] = 1;  // DB21[7:4]
                        sclk_dat_fifo.rd[3][2][1] = 1;  // DB22[3:0]
                        sclk_dat_fifo.rd[0][3][0] = 1;  // DB22[7:4]
                        sclk_dat_fifo.rd[3][3][1] = 1;  // DB23[3:0]
                        sclk_dat_fifo.rd[1][0][0] = 1;  // DB23[7:4]
                    end

                    'd9 :
                    begin
                        sclk_dat_fifo.rd[1][2][0] = 1;  // DB24[3:0]
                        sclk_dat_fifo.rd[2][3][1] = 1;  // DB24[7:4]
                        sclk_dat_fifo.rd[1][3][0] = 1;  // DB25[3:0]
                        sclk_dat_fifo.rd[3][0][1] = 1;  // DB25[7:4]
                        sclk_dat_fifo.rd[2][0][0] = 1;  // DB26[3:0]
                        sclk_dat_fifo.rd[3][1][1] = 1;  // DB26[7:4]
                        sclk_dat_fifo.rd[2][1][0] = 1;  // DB27[3:0]
                        sclk_dat_fifo.rd[3][2][1] = 1;  // DB27[7:4]
                    end

                    'd10 :
                    begin
                        sclk_dat_fifo.rd[1][2][1] = 1;  // DB28[3:0]
                        sclk_dat_fifo.rd[2][3][0] = 1;  // DB28[7:4]
                        sclk_dat_fifo.rd[1][3][1] = 1;  // DB29[3:0]
                        sclk_dat_fifo.rd[3][0][0] = 1;  // DB29[7:4]
                        sclk_dat_fifo.rd[2][0][1] = 1;  // DB30[3:0]
                        sclk_dat_fifo.rd[3][1][0] = 1;  // DB30[7:4]
                        sclk_dat_fifo.rd[2][1][1] = 1;  // DB31[3:0]
                        sclk_dat_fifo.rd[3][2][0] = 1;  // DB31[7:4]
                    end

                    'd11 : 
                    begin
                        sclk_dat_fifo.rd[0][0][0] = 1;  // PB8[3:0]
                        sclk_dat_fifo.rd[1][1][1] = 1;  // PB8[7:4]
                        sclk_dat_fifo.rd[0][0][1] = 1;  // PB9[3:0]
                        sclk_dat_fifo.rd[1][1][0] = 1;  // PB9[7:4]
                        sclk_dat_fifo.rd[2][2][0] = 1;  // PB10[3:0]
                        sclk_dat_fifo.rd[3][3][1] = 1;  // PB10[7:4]
                        sclk_dat_fifo.rd[2][2][1] = 1;  // PB11[3:0]
                        sclk_dat_fifo.rd[3][3][0] = 1;  // PB11[7:4]
                    end

                    default : 
                    begin
                        sclk_dat_fifo.rd[0][0][0] = 1;  // HB0[3:0]
                        sclk_dat_fifo.rd[0][2][1] = 1;  // HB0[7:4]
                        sclk_dat_fifo.rd[0][0][1] = 1;  // HB1[3:0]
                        sclk_dat_fifo.rd[0][2][0] = 1;  // HB1[7:4]
                        sclk_dat_fifo.rd[1][0][0] = 1;  // HB2[3:0]
                        sclk_dat_fifo.rd[1][2][1] = 1;  // HB2[7:4]
                        sclk_dat_fifo.rd[1][0][1] = 1;  // HB3[3:0]
                        sclk_dat_fifo.rd[1][2][0] = 1;  // HB3[7:4]
                    end
                endcase
            end

            // Two lanes
            else if (sclk_sdp.lanes == 'd2)
            begin
                case (sclk_sdp.rd_sel)
                    'd1 : 
                    begin
                        sclk_dat_fifo.rd[0][1][0] = 1;  // PB0[3:0]
                        sclk_dat_fifo.rd[2][1][1] = 1;  // PB0[7:4]
                        sclk_dat_fifo.rd[2][1][0] = 1;  // PB1[3:0]
                        sclk_dat_fifo.rd[0][1][1] = 1;  // PB1[7:4]
                        sclk_dat_fifo.rd[0][3][0] = 1;  // PB2[3:0]
                        sclk_dat_fifo.rd[2][3][1] = 1;  // PB2[7:4]
                        sclk_dat_fifo.rd[2][3][0] = 1;  // PB3[3:0]
                        sclk_dat_fifo.rd[0][3][1] = 1;  // PB3[7:4]
                    end

                    'd2 : 
                    begin
                        sclk_dat_fifo.rd[1][0][0] = 1;  // DB0[3:0]
                        sclk_dat_fifo.rd[3][0][1] = 1;  // DB0[7:4]
                        sclk_dat_fifo.rd[1][1][0] = 1;  // DB1[3:0]
                        sclk_dat_fifo.rd[3][1][1] = 1;  // DB1[7:4]
                        sclk_dat_fifo.rd[1][2][0] = 1;  // DB2[3:0]
                        sclk_dat_fifo.rd[3][2][1] = 1;  // DB2[7:4]
                        sclk_dat_fifo.rd[1][3][0] = 1;  // DB3[3:0]
                        sclk_dat_fifo.rd[3][3][1] = 1;  // DB3[7:4]
                    end

                    'd3 :
                    begin
                        sclk_dat_fifo.rd[3][0][0] = 1;  // DB4[3:0]
                        sclk_dat_fifo.rd[1][0][1] = 1;  // DB4[7:4]
                        sclk_dat_fifo.rd[3][1][0] = 1;  // DB5[3:0]
                        sclk_dat_fifo.rd[1][1][1] = 1;  // DB5[7:4]
                        sclk_dat_fifo.rd[3][2][0] = 1;  // DB6[3:0]
                        sclk_dat_fifo.rd[1][2][1] = 1;  // DB6[7:4]
                        sclk_dat_fifo.rd[3][3][0] = 1;  // DB7[3:0]
                        sclk_dat_fifo.rd[1][3][1] = 1;  // DB7[7:4]
                    end

                    'd4 :
                    begin
                        sclk_dat_fifo.rd[0][1][0] = 1;  // DB8[3:0]
                        sclk_dat_fifo.rd[2][1][1] = 1;  // DB8[7:4]
                        sclk_dat_fifo.rd[0][2][0] = 1;  // DB9[3:0]
                        sclk_dat_fifo.rd[2][2][1] = 1;  // DB9[7:4]
                        sclk_dat_fifo.rd[0][3][0] = 1;  // DB10[3:0]
                        sclk_dat_fifo.rd[2][3][1] = 1;  // DB10[7:4]
                        sclk_dat_fifo.rd[1][0][0] = 1;  // DB11[3:0]
                        sclk_dat_fifo.rd[3][0][1] = 1;  // DB11[7:4]
                    end

                    'd5 :
                    begin
                        sclk_dat_fifo.rd[2][1][0] = 1;  // DB12[3:0]
                        sclk_dat_fifo.rd[0][1][1] = 1;  // DB12[7:4]
                        sclk_dat_fifo.rd[2][2][0] = 1;  // DB13[3:0]
                        sclk_dat_fifo.rd[0][2][1] = 1;  // DB13[7:4]
                        sclk_dat_fifo.rd[2][3][0] = 1;  // DB14[3:0]
                        sclk_dat_fifo.rd[0][3][1] = 1;  // DB14[7:4]
                        sclk_dat_fifo.rd[3][0][0] = 1;  // DB15[3:0]
                        sclk_dat_fifo.rd[1][0][1] = 1;  // DB15[7:4]
                    end

                    'd6 : 
                    begin
                        sclk_dat_fifo.rd[0][0][0] = 1;  // PB4[3:0]
                        sclk_dat_fifo.rd[2][0][1] = 1;  // PB4[7:4]
                        sclk_dat_fifo.rd[2][0][0] = 1;  // PB5[3:0]
                        sclk_dat_fifo.rd[0][0][1] = 1;  // PB5[7:4]
                        sclk_dat_fifo.rd[1][1][0] = 1;  // PB6[3:0]
                        sclk_dat_fifo.rd[3][1][1] = 1;  // PB6[7:4]
                        sclk_dat_fifo.rd[3][1][0] = 1;  // PB7[3:0]
                        sclk_dat_fifo.rd[1][1][1] = 1;  // PB7[7:4]
                    end

                    'd7 :
                    begin
                        sclk_dat_fifo.rd[1][2][0] = 1;  // DB16[3:0]
                        sclk_dat_fifo.rd[3][2][1] = 1;  // DB16[7:4]
                        sclk_dat_fifo.rd[1][3][0] = 1;  // DB17[3:0]
                        sclk_dat_fifo.rd[3][3][1] = 1;  // DB17[7:4]
                        sclk_dat_fifo.rd[0][0][0] = 1;  // DB18[3:0]
                        sclk_dat_fifo.rd[2][0][1] = 1;  // DB18[7:4]
                        sclk_dat_fifo.rd[0][1][0] = 1;  // DB19[3:0]
                        sclk_dat_fifo.rd[2][1][1] = 1;  // DB19[7:4]
                    end

                    'd8 :
                    begin
                        sclk_dat_fifo.rd[3][2][0] = 1;  // DB20[3:0]
                        sclk_dat_fifo.rd[1][2][1] = 1;  // DB20[7:4]
                        sclk_dat_fifo.rd[3][3][0] = 1;  // DB21[3:0]
                        sclk_dat_fifo.rd[1][3][1] = 1;  // DB21[7:4]
                        sclk_dat_fifo.rd[2][0][0] = 1;  // DB22[3:0]
                        sclk_dat_fifo.rd[0][0][1] = 1;  // DB22[7:4]
                        sclk_dat_fifo.rd[2][1][0] = 1;  // DB23[3:0]
                        sclk_dat_fifo.rd[0][1][1] = 1;  // DB23[7:4]
                    end

                    'd9 :
                    begin
                        sclk_dat_fifo.rd[0][3][0] = 1;  // DB24[3:0]
                        sclk_dat_fifo.rd[2][3][1] = 1;  // DB24[7:4]
                        sclk_dat_fifo.rd[1][0][0] = 1;  // DB25[3:0]
                        sclk_dat_fifo.rd[3][0][1] = 1;  // DB25[7:4]
                        sclk_dat_fifo.rd[1][1][0] = 1;  // DB26[3:0]
                        sclk_dat_fifo.rd[3][1][1] = 1;  // DB26[7:4]
                        sclk_dat_fifo.rd[1][2][0] = 1;  // DB27[3:0]
                        sclk_dat_fifo.rd[3][2][1] = 1;  // DB27[7:4]
                    end

                    'd10 :
                    begin
                        sclk_dat_fifo.rd[2][3][0] = 1;  // DB28[3:0]
                        sclk_dat_fifo.rd[0][3][1] = 1;  // DB28[7:4]
                        sclk_dat_fifo.rd[3][0][0] = 1;  // DB29[3:0]
                        sclk_dat_fifo.rd[1][0][1] = 1;  // DB29[7:4]
                        sclk_dat_fifo.rd[3][1][0] = 1;  // DB30[3:0]
                        sclk_dat_fifo.rd[1][1][1] = 1;  // DB30[7:4]
                        sclk_dat_fifo.rd[3][2][0] = 1;  // DB31[3:0]
                        sclk_dat_fifo.rd[1][2][1] = 1;  // DB31[7:4]
                    end

                    'd11 : 
                    begin
                        sclk_dat_fifo.rd[0][2][0] = 1;  // PB8[3:0]
                        sclk_dat_fifo.rd[2][2][1] = 1;  // PB8[7:4]
                        sclk_dat_fifo.rd[2][2][0] = 1;  // PB9[3:0]
                        sclk_dat_fifo.rd[0][2][1] = 1;  // PB9[7:4]
                        sclk_dat_fifo.rd[1][3][0] = 1;  // PB10[3:0]
                        sclk_dat_fifo.rd[3][3][1] = 1;  // PB10[7:4]
                        sclk_dat_fifo.rd[3][3][0] = 1;  // PB11[3:0]
                        sclk_dat_fifo.rd[1][3][1] = 1;  // PB11[7:4]
                    end

                    default : 
                    begin
                        sclk_dat_fifo.rd[0][0][0] = 1;  // HB0[3:0]
                        sclk_dat_fifo.rd[2][0][1] = 1;  // HB0[7:4]
                        sclk_dat_fifo.rd[2][0][0] = 1;  // HB1[3:0]
                        sclk_dat_fifo.rd[0][0][1] = 1;  // HB1[7:4]
                        sclk_dat_fifo.rd[0][2][0] = 1;  // HB2[3:0]
                        sclk_dat_fifo.rd[2][2][1] = 1;  // HB2[7:4]
                        sclk_dat_fifo.rd[2][2][0] = 1;  // HB3[3:0]
                        sclk_dat_fifo.rd[0][2][1] = 1;  // HB3[7:4]
                    end
                endcase
            end

            // Four lanes
            else
            begin
                case (sclk_sdp.rd_sel)
                    'd1 : 
                    begin
                        sclk_dat_fifo.rd[0][1][0] = 1;  // PB0[3:0]
                        sclk_dat_fifo.rd[1][1][1] = 1;  // PB0[7:4]
                        sclk_dat_fifo.rd[1][1][0] = 1;  // PB1[3:0]
                        sclk_dat_fifo.rd[0][1][1] = 1;  // PB1[7:4]
                        sclk_dat_fifo.rd[2][1][0] = 1;  // PB2[3:0]
                        sclk_dat_fifo.rd[3][1][1] = 1;  // PB2[7:4]
                        sclk_dat_fifo.rd[3][1][0] = 1;  // PB3[3:0]
                        sclk_dat_fifo.rd[2][1][1] = 1;  // PB3[7:4]
                    end

                    'd2 :
                    begin
                        sclk_dat_fifo.rd[0][2][0] = 1;  // DB0[3:0]
                        sclk_dat_fifo.rd[1][2][1] = 1;  // DB0[7:4]
                        sclk_dat_fifo.rd[0][3][0] = 1;  // DB1[3:0]
                        sclk_dat_fifo.rd[1][3][1] = 1;  // DB1[7:4]
                        sclk_dat_fifo.rd[0][0][0] = 1;  // DB2[3:0]
                        sclk_dat_fifo.rd[1][0][1] = 1;  // DB2[7:4]
                        sclk_dat_fifo.rd[0][1][0] = 1;  // DB3[3:0]
                        sclk_dat_fifo.rd[1][1][1] = 1;  // DB3[7:4]
                    end

                    'd3 :
                    begin
                        sclk_dat_fifo.rd[1][2][0] = 1;  // DB4[3:0]
                        sclk_dat_fifo.rd[0][2][1] = 1;  // DB4[7:4]
                        sclk_dat_fifo.rd[1][3][0] = 1;  // DB5[3:0]
                        sclk_dat_fifo.rd[0][3][1] = 1;  // DB5[7:4]
                        sclk_dat_fifo.rd[1][0][0] = 1;  // DB6[3:0]
                        sclk_dat_fifo.rd[0][0][1] = 1;  // DB6[7:4]
                        sclk_dat_fifo.rd[1][1][0] = 1;  // DB7[3:0]
                        sclk_dat_fifo.rd[0][1][1] = 1;  // DB7[7:4]
                    end

                    'd4 :
                    begin
                        sclk_dat_fifo.rd[2][2][0] = 1;  // DB8[3:0]
                        sclk_dat_fifo.rd[3][2][1] = 1;  // DB8[7:4]
                        sclk_dat_fifo.rd[2][3][0] = 1;  // DB9[3:0]
                        sclk_dat_fifo.rd[3][3][1] = 1;  // DB9[7:4]
                        sclk_dat_fifo.rd[2][0][0] = 1;  // DB10[3:0]
                        sclk_dat_fifo.rd[3][0][1] = 1;  // DB10[7:4]
                        sclk_dat_fifo.rd[2][1][0] = 1;  // DB11[3:0]
                        sclk_dat_fifo.rd[3][1][1] = 1;  // DB11[7:4]
                    end

                    'd5 :
                    begin
                        sclk_dat_fifo.rd[3][2][0] = 1;  // DB12[3:0]
                        sclk_dat_fifo.rd[2][2][1] = 1;  // DB12[7:4]
                        sclk_dat_fifo.rd[3][3][0] = 1;  // DB13[3:0]
                        sclk_dat_fifo.rd[2][3][1] = 1;  // DB13[7:4]
                        sclk_dat_fifo.rd[3][0][0] = 1;  // DB14[3:0]
                        sclk_dat_fifo.rd[2][0][1] = 1;  // DB14[7:4]
                        sclk_dat_fifo.rd[3][1][0] = 1;  // DB15[3:0]
                        sclk_dat_fifo.rd[2][1][1] = 1;  // DB15[7:4]
                    end

                    'd6 : 
                    begin
                        sclk_dat_fifo.rd[0][2][0] = 1;  // PB4[3:0]
                        sclk_dat_fifo.rd[1][2][1] = 1;  // PB4[7:4]
                        sclk_dat_fifo.rd[1][2][0] = 1;  // PB5[3:0]
                        sclk_dat_fifo.rd[0][2][1] = 1;  // PB5[7:4]
                        sclk_dat_fifo.rd[2][2][0] = 1;  // PB6[3:0]
                        sclk_dat_fifo.rd[3][2][1] = 1;  // PB6[7:4]
                        sclk_dat_fifo.rd[3][2][0] = 1;  // PB7[3:0]
                        sclk_dat_fifo.rd[2][2][1] = 1;  // PB7[7:4]
                    end

                    'd7 :
                    begin
                        sclk_dat_fifo.rd[0][3][0] = 1;  // DB16[3:0]
                        sclk_dat_fifo.rd[1][3][1] = 1;  // DB16[7:4]
                        sclk_dat_fifo.rd[0][0][0] = 1;  // DB17[3:0]
                        sclk_dat_fifo.rd[1][0][1] = 1;  // DB17[7:4]
                        sclk_dat_fifo.rd[0][1][0] = 1;  // DB18[3:0]
                        sclk_dat_fifo.rd[1][1][1] = 1;  // DB18[7:4]
                        sclk_dat_fifo.rd[0][2][0] = 1;  // DB19[3:0]
                        sclk_dat_fifo.rd[1][2][1] = 1;  // DB19[7:4]
                    end

                    'd8 :
                    begin
                        sclk_dat_fifo.rd[1][3][0] = 1;  // DB20[3:0]
                        sclk_dat_fifo.rd[0][3][1] = 1;  // DB20[7:4]
                        sclk_dat_fifo.rd[1][0][0] = 1;  // DB21[3:0]
                        sclk_dat_fifo.rd[0][0][1] = 1;  // DB21[7:4]
                        sclk_dat_fifo.rd[1][1][0] = 1;  // DB22[3:0]
                        sclk_dat_fifo.rd[0][1][1] = 1;  // DB22[7:4]
                        sclk_dat_fifo.rd[1][2][0] = 1;  // DB23[3:0]
                        sclk_dat_fifo.rd[0][2][1] = 1;  // DB23[7:4]
                    end

                    'd9 :
                    begin
                        sclk_dat_fifo.rd[2][3][0] = 1;  // DB24[3:0]
                        sclk_dat_fifo.rd[3][3][1] = 1;  // DB24[7:4]
                        sclk_dat_fifo.rd[2][0][0] = 1;  // DB25[3:0]
                        sclk_dat_fifo.rd[3][0][1] = 1;  // DB25[7:4]
                        sclk_dat_fifo.rd[2][1][0] = 1;  // DB26[3:0]
                        sclk_dat_fifo.rd[3][1][1] = 1;  // DB26[7:4]
                        sclk_dat_fifo.rd[2][2][0] = 1;  // DB27[3:0]
                        sclk_dat_fifo.rd[3][2][1] = 1;  // DB27[7:4]
                    end

                    'd10 :
                    begin
                        sclk_dat_fifo.rd[3][3][0] = 1;  // DB28[3:0]
                        sclk_dat_fifo.rd[2][3][1] = 1;  // DB28[7:4]
                        sclk_dat_fifo.rd[3][0][0] = 1;  // DB29[3:0]
                        sclk_dat_fifo.rd[2][0][1] = 1;  // DB29[7:4]
                        sclk_dat_fifo.rd[3][1][0] = 1;  // DB30[3:0]
                        sclk_dat_fifo.rd[2][1][1] = 1;  // DB30[7:4]
                        sclk_dat_fifo.rd[3][2][0] = 1;  // DB31[3:0]
                        sclk_dat_fifo.rd[2][2][1] = 1;  // DB31[7:4]
                    end

                    'd11 : 
                    begin
                        sclk_dat_fifo.rd[0][3][0] = 1;  // PB8[3:0]
                        sclk_dat_fifo.rd[1][3][1] = 1;  // PB8[7:4]
                        sclk_dat_fifo.rd[1][3][0] = 1;  // PB9[3:0]
                        sclk_dat_fifo.rd[0][3][1] = 1;  // PB9[7:4]
                        sclk_dat_fifo.rd[2][3][0] = 1;  // PB10[3:0]
                        sclk_dat_fifo.rd[3][3][1] = 1;  // PB10[7:4]
                        sclk_dat_fifo.rd[3][3][0] = 1;  // PB11[3:0]
                        sclk_dat_fifo.rd[2][3][1] = 1;  // PB11[7:4]
                    end

                    default : 
                    begin
                        sclk_dat_fifo.rd[0][0][0] = 1;  // HB0[3:0]
                        sclk_dat_fifo.rd[1][0][1] = 1;  // HB0[7:4]
                        sclk_dat_fifo.rd[1][0][0] = 1;  // HB1[3:0]
                        sclk_dat_fifo.rd[0][0][1] = 1;  // HB1[7:4]
                        sclk_dat_fifo.rd[2][0][0] = 1;  // HB2[3:0]
                        sclk_dat_fifo.rd[3][0][1] = 1;  // HB2[7:4]
                        sclk_dat_fifo.rd[3][0][0] = 1;  // HB3[3:0]
                        sclk_dat_fifo.rd[2][0][1] = 1;  // HB3[7:4]
                    end
                endcase
            end
        end
    end

// SDP Data
    always_ff @ (posedge SDP_CLK_IN)
    begin
        // One lane
        if (sclk_sdp.lanes == 'd1)
        begin
            case (sclk_sdp.dat_sel[$high(sclk_sdp.dat_sel)])
                'd1 : 
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[0][1][0];  // PB0[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[0][3][1];  // PB0[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[0][1][1];  // PB1[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[0][3][0];  // PB1[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[1][1][0];  // PB2[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[1][3][1];  // PB2[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[1][1][1];  // PB3[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[1][3][0];  // PB3[7:4]
                end

                'd2 : 
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[2][0][0];  // DB0[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[3][1][1];  // DB0[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[2][1][0];  // DB1[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[3][2][1];  // DB1[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[2][2][0];  // DB2[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[3][3][1];  // DB2[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[2][3][0];  // DB3[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[0][0][1];  // DB3[7:4]
                end

                'd3 :
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[2][0][1];  // DB4[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[3][1][0];  // DB4[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[2][1][1];  // DB5[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[3][2][0];  // DB5[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[2][2][1];  // DB6[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[3][3][0];  // DB6[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[2][3][1];  // DB7[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[0][0][0];  // DB7[7:4]
                end

                'd4 :
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[0][2][0];  // DB8[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[1][3][1];  // DB8[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[0][3][0];  // DB9[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[2][0][1];  // DB9[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[1][0][0];  // DB10[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[2][1][1];  // DB10[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[1][1][0];  // DB11[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[2][2][1];  // DB11[7:4]
                end

                'd5 :
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[0][2][1];  // DB12[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[1][3][0];  // DB12[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[0][3][1];  // DB13[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[2][0][0];  // DB13[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[1][0][1];  // DB14[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[2][1][0];  // DB14[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[1][1][1];  // DB15[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[2][2][0];  // DB15[7:4]
                end

                'd6 : 
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[3][0][0];  // PB4[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[0][1][1];  // PB4[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[3][0][1];  // PB5[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[0][1][0];  // PB5[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[1][2][0];  // PB6[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[2][3][1];  // PB6[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[1][2][1];  // PB7[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[2][3][0];  // PB7[7:4]
                end

                'd7 :
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[3][0][0];  // DB16[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[0][1][1];  // DB16[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[3][1][0];  // DB17[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[0][2][1];  // DB17[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[3][2][0];  // DB18[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[0][3][1];  // DB18[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[3][3][0];  // DB19[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[1][0][1];  // DB19[7:4]
                end

                'd8 :
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[3][0][1];  // DB20[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[0][1][0];  // DB20[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[3][1][1];  // DB21[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[0][2][0];  // DB21[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[3][2][1];  // DB22[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[0][3][0];  // DB22[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[3][3][1];  // DB23[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[1][0][0];  // DB23[7:4]
                end

                'd9 :
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[1][2][0];  // DB24[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[2][3][1];  // DB24[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[1][3][0];  // DB25[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[3][0][1];  // DB25[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[2][0][0];  // DB26[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[3][1][1];  // DB26[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[2][1][0];  // DB27[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[3][2][1];  // DB27[7:4]
                end

                'd10 :
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[1][2][1];  // DB28[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[2][3][0];  // DB28[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[1][3][1];  // DB29[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[3][0][0];  // DB29[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[2][0][1];  // DB30[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[3][1][0];  // DB30[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[2][1][1];  // DB31[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[3][2][0];  // DB31[7:4]
                end

                'd11 : 
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[0][0][0];  // PB8[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[1][1][1];  // PB8[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[0][0][1];  // PB9[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[1][1][0];  // PB9[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[2][2][0];  // PB10[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[3][3][1];  // PB10[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[2][2][1];  // PB11[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[3][3][0];  // PB11[7:4]
                end

                default : 
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[0][0][0];  // HB0[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[0][2][1];  // HB0[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[0][0][1];  // HB1[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[0][2][0];  // HB1[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[1][0][0];  // HB2[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[1][2][1];  // HB2[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[1][0][1];  // HB3[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[1][2][0];  // HB3[7:4]
                end
            endcase
        end

        // Two lanes
        else if (sclk_sdp.lanes == 'd2)
        begin
            case (sclk_sdp.dat_sel[$high(sclk_sdp.dat_sel)])
                'd1 : 
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[0][1][0];  // PB0[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[2][1][1];  // PB0[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[2][1][0];  // PB1[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[0][1][1];  // PB1[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[0][3][0];  // PB2[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[2][3][1];  // PB2[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[2][3][0];  // PB3[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[0][3][1];  // PB3[7:4]
                end

                'd2 : 
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[1][0][0];  // DB0[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[3][0][1];  // DB0[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[1][1][0];  // DB1[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[3][1][1];  // DB1[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[1][2][0];  // DB2[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[3][2][1];  // DB2[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[1][3][0];  // DB3[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[3][3][1];  // DB3[7:4]
                end

                'd3 :
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[3][0][0];  // DB4[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[1][0][1];  // DB4[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[3][1][0];  // DB5[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[1][1][1];  // DB5[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[3][2][0];  // DB6[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[1][2][1];  // DB6[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[3][3][0];  // DB7[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[1][3][1];  // DB7[7:4]
                end

                'd4 :
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[0][1][0];  // DB8[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[2][1][1];  // DB8[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[0][2][0];  // DB9[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[2][2][1];  // DB9[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[0][3][0];  // DB10[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[2][3][1];  // DB10[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[1][0][0];  // DB11[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[3][0][1];  // DB11[7:4]
                end

                'd5 :
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[2][1][0];  // DB12[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[0][1][1];  // DB12[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[2][2][0];  // DB13[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[0][2][1];  // DB13[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[2][3][0];  // DB14[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[0][3][1];  // DB14[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[3][0][0];  // DB15[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[1][0][1];  // DB15[7:4]
                end

                'd6 : 
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[0][0][0];  // PB4[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[2][0][1];  // PB4[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[2][0][0];  // PB5[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[0][0][1];  // PB5[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[1][1][0];  // PB6[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[3][1][1];  // PB6[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[3][1][0];  // PB7[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[1][1][1];  // PB7[7:4]
                end

                'd7 :
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[1][2][0];  // DB16[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[3][2][1];  // DB16[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[1][3][0];  // DB17[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[3][3][1];  // DB17[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[0][0][0];  // DB18[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[2][0][1];  // DB18[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[0][1][0];  // DB19[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[2][1][1];  // DB19[7:4]
                end

                'd8 :
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[3][2][0];  // DB20[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[1][2][1];  // DB20[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[3][3][0];  // DB21[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[1][3][1];  // DB21[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[2][0][0];  // DB22[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[0][0][1];  // DB22[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[2][1][0];  // DB23[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[0][1][1];  // DB23[7:4]
                end

                'd9 :
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[0][3][0];  // DB24[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[2][3][1];  // DB24[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[1][0][0];  // DB25[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[3][0][1];  // DB25[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[1][1][0];  // DB26[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[3][1][1];  // DB26[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[1][2][0];  // DB27[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[3][2][1];  // DB27[7:4]
                end

                'd10 :
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[2][3][0];  // DB28[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[0][3][1];  // DB28[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[3][0][0];  // DB29[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[1][0][1];  // DB29[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[3][1][0];  // DB30[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[1][1][1];  // DB30[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[3][2][0];  // DB31[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[1][2][1];  // DB31[7:4]
                end

                'd11 : 
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[0][2][0];  // PB8[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[2][2][1];  // PB8[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[2][2][0];  // PB9[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[0][2][1];  // PB9[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[1][3][0];  // PB10[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[3][3][1];  // PB10[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[3][3][0];  // PB11[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[1][3][1];  // PB11[7:4]
                end

                default : 
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[0][0][0];  // HB0[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[2][0][1];  // HB0[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[2][0][0];  // HB1[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[0][0][1];  // HB1[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[0][2][0];  // HB2[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[2][2][1];  // HB2[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[2][2][0];  // HB3[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[0][2][1];  // HB3[7:4]
                end
            endcase
        end

        // Four lanes
        else
        begin
            case (sclk_sdp.dat_sel[$high(sclk_sdp.dat_sel)])
                'd1 : 
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[0][1][0];  // PB0[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[1][1][1];  // PB0[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[1][1][0];  // PB1[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[0][1][1];  // PB1[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[2][1][0];  // PB2[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[3][1][1];  // PB2[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[3][1][0];  // PB3[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[2][1][1];  // PB3[7:4]
                end

                'd2 : 
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[0][2][0];  // DB0[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[1][2][1];  // DB0[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[0][3][0];  // DB1[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[1][3][1];  // DB1[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[0][0][0];  // DB2[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[1][0][1];  // DB2[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[0][1][0];  // DB3[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[1][1][1];  // DB3[7:4]
                end

                'd3 :
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[1][2][0];  // DB4[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[0][2][1];  // DB4[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[1][3][0];  // DB5[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[0][3][1];  // DB5[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[1][0][0];  // DB6[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[0][0][1];  // DB6[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[1][1][0];  // DB7[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[0][1][1];  // DB7[7:4]
                end

                'd4 :
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[2][2][0];  // DB8[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[3][2][1];  // DB8[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[2][3][0];  // DB9[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[3][3][1];  // DB9[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[2][0][0];  // DB10[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[3][0][1];  // DB10[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[2][1][0];  // DB11[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[3][1][1];  // DB11[7:4]
                end

                'd5 :
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[3][2][0];  // DB12[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[2][2][1];  // DB12[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[3][3][0];  // DB13[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[2][3][1];  // DB13[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[3][0][0];  // DB14[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[2][0][1];  // DB14[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[3][1][0];  // DB15[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[2][1][1];  // DB15[7:4]
                end

                'd6 : 
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[0][2][0];  // PB4[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[1][2][1];  // PB4[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[1][2][0];  // PB5[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[0][2][1];  // PB5[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[2][2][0];  // PB6[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[3][2][1];  // PB6[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[3][2][0];  // PB7[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[2][2][1];  // PB7[7:4]
                end

                'd7 :
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[0][3][0];  // DB16[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[1][3][1];  // DB16[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[0][0][0];  // DB17[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[1][0][1];  // DB17[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[0][1][0];  // DB18[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[1][1][1];  // DB18[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[0][2][0];  // DB19[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[1][2][1];  // DB19[7:4]
                end

                'd8 :
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[1][3][0];  // DB20[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[0][3][1];  // DB20[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[1][0][0];  // DB21[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[0][0][1];  // DB21[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[1][1][0];  // DB22[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[0][1][1];  // DB22[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[1][2][0];  // DB23[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[0][2][1];  // DB23[7:4]
                end

                'd9 :
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[2][3][0];  // DB24[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[3][3][1];  // DB24[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[2][0][0];  // DB25[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[3][0][1];  // DB25[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[2][1][0];  // DB26[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[3][1][1];  // DB26[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[2][2][0];  // DB27[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[3][2][1];  // DB27[7:4]
                end

                'd10 :
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[3][3][0];  // DB28[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[2][3][1];  // DB28[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[3][0][0];  // DB29[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[2][0][1];  // DB29[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[3][1][0];  // DB30[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[2][1][1];  // DB30[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[3][2][0];  // DB31[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[2][2][1];  // DB31[7:4]
                end

                'd11 : 
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[0][3][0];  // PB8[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[1][3][1];  // PB8[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[1][3][0];  // PB9[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[0][3][1];  // PB9[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[2][3][0];  // PB10[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[3][3][1];  // PB10[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[3][3][0];  // PB11[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[2][3][1];  // PB11[7:4]
                end

                default : 
                begin
                    sclk_sdp.dat[(0*8)+:4]      <= sclk_dat_fifo.dout[0][0][0];  // HB0[3:0]
                    sclk_sdp.dat[((0*8)+4)+:4]  <= sclk_dat_fifo.dout[1][0][1];  // HB0[7:4]
                    sclk_sdp.dat[(1*8)+:4]      <= sclk_dat_fifo.dout[1][0][0];  // HB1[3:0]
                    sclk_sdp.dat[((1*8)+4)+:4]  <= sclk_dat_fifo.dout[0][0][1];  // HB1[7:4]
                    sclk_sdp.dat[(2*8)+:4]      <= sclk_dat_fifo.dout[2][0][0];  // HB2[3:0]
                    sclk_sdp.dat[((2*8)+4)+:4]  <= sclk_dat_fifo.dout[3][0][1];  // HB2[7:4]
                    sclk_sdp.dat[(3*8)+:4]      <= sclk_dat_fifo.dout[3][0][0];  // HB3[3:0]
                    sclk_sdp.dat[((3*8)+4)+:4]  <= sclk_dat_fifo.dout[2][0][1];  // HB3[7:4]
                end
            endcase
        end
    end

// SDP Start of packet
    always_ff @ (posedge SDP_CLK_IN)
    begin
        if (sclk_sdp.rd_cnt_str_del[$high(sclk_sdp.rd_cnt_str_del)])
            sclk_sdp.sop <= 1;
        else
            sclk_sdp.sop <= 0;
    end

// SDP End of packet
    always_ff @ (posedge SDP_CLK_IN)
    begin
        if (sclk_sdp.rd_cnt_stp_del)
            sclk_sdp.eop <= 1;
        else
            sclk_sdp.eop <= 0;
    end

// SDP Valid
    always_ff @ (posedge SDP_CLK_IN)
    begin
        if (!sclk_sdp.rd_cnt_end_del[$high(sclk_sdp.rd_cnt_end_del)])
            sclk_sdp.vld <= 1;
        else
            sclk_sdp.vld <= 0;
    end

// Outputs
generate
    for (i = 0; i < P_LANES; i++)
    begin
        assign LNK_SRC_IF.sol[i]   = lclk_lnk.sol[i]; 
        assign LNK_SRC_IF.eol[i]   = lclk_lnk.eol[i]; 
        assign LNK_SRC_IF.vid[i]   = lclk_lnk.vid[i]; 
        assign LNK_SRC_IF.sdp[i]   = 0;                  // The SDP is not passed
        assign LNK_SRC_IF.msa[i]   = 0;                  // The MSA is not passed 
        assign LNK_SRC_IF.vbid[i]  = lclk_lnk.vbid[i]; 
        assign LNK_SRC_IF.k[i]     = lclk_lnk.k[i];
        assign LNK_SRC_IF.dat[i]   = lclk_lnk.dat[i];
    end
endgenerate

    assign LNK_SRC_IF.lock  = lclk_lnk.lock;

    assign SDP_SRC_IF.sop = sclk_sdp.sop;
    assign SDP_SRC_IF.eop = sclk_sdp.eop;
    assign SDP_SRC_IF.dat = sclk_sdp.dat;
    assign SDP_SRC_IF.vld = sclk_sdp.vld;

endmodule

`default_nettype wire
