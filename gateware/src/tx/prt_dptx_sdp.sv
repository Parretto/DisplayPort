/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP TX Secondary Data Packet
    (c) 2021 - 2026 by Parretto B.V.


    Description
    ===========
    This module inserts the Secondary Data Packets (SDP) into the main stream during the horizontal and vertical blanking.
    The packets come from the SDP input or from the host processor (through the policy maker).
    The module calculates the parity bytes of the packets.


    History
    =======
    v1.0 - Initial release
    v1.1 - Fixed the lane mapping for two lanes and four symbols per lane,
           fixed the packet scheduling at the start of the video and around the vertical blanking
    v1.2 - No packet start during the VB-ID, Mvid7:0 and Maud7:0 symbols after the BS (four times in 1 and 2 lanes)
           and during the MSA
    v1.3 - Added the parity calculation
    v1.4 - Added support for 28 byte packets (16-byte payload)
    v1.5 - Added the processor packets (message P_MSG_ID_SDP)
    v1.6 - Processor packet handshake (SDP_PRC_CNT_OUT), FIFO read only when not empty, P_MSG_ID renamed to P_MSG_ID_MSA
    v1.7 - Shorter description, read of the last packet word without modulo
    v1.8 - Registered source data 


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
module prt_dptx_sdp
#(
    // System
    parameter               P_VENDOR = "none",   // Vendor - "AMD", "ALTERA" or "LSC"
    parameter               P_FAMILY = "none",   // Family (Only used for Lattice)
    parameter               P_SIM = 0,           // Simulation

    // Link
    parameter               P_LANES = 4,    	 // Lanes
    parameter               P_SPL = 2,        	 // Symbols per lane

    // Message
    parameter               P_MSG_IDX     = 5,   // Message index width
    parameter               P_MSG_DAT     = 16,  // Message data width
    parameter               P_MSG_ID_MSA  = 0,   // Message ID main stream attributes
    parameter               P_MSG_ID_SDP  = 0    // Message ID secondary data packet (processor packets)
)
(
    // Control
    input wire  [1:0]       CTL_LANES_IN,       // Active lanes (1 - 1 lane / 2 - 2 lanes / 3 - 4 lanes)

    // Message
    prt_dp_msg_if.snk       MSG_SNK_IF,         // Sink
    prt_dp_msg_if.src       MSG_SRC_IF,         // Source

    // Secondary data packet
    input wire              SDP_CLK_IN,         // Clock
    prt_dp_tx_sdp_if.snk    SDP_SNK_IF,         // Sink
    output wire [3:0]       SDP_PRC_CNT_OUT,    // Processor packets taken (SDP clock domain, for the handshake of the policy maker)

    // Link
    input wire              LNK_RST_IN,         // Reset
    input wire              LNK_CLK_IN,         // Clock
    input wire              LNK_VS_IN,          // Vsync 
    input wire              LNK_VBF_IN,         // Vertical blanking flag
    prt_dp_tx_lnk_if.snk    LNK_SNK_IF,         // Sink 
    prt_dp_tx_lnk_if.src    LNK_SRC_IF          // Source
);


//-----
// Package
//-----
import prt_dp_pkg::*;


//-----
// Parameters
//-----
localparam P_DAT_FIFO_OPT   = 0;
localparam P_DAT_FIFO_WRDS  = 32;
localparam P_DAT_FIFO_ADR   = $clog2(P_DAT_FIFO_WRDS);
localparam P_DAT_FIFO_DAT   = 4;
localparam P_LEN_FIFO_OPT   = 0;
localparam P_LEN_FIFO_WRDS  = 8;
localparam P_LEN_FIFO_ADR   = $clog2(P_LEN_FIFO_WRDS);
localparam P_LEN_FIFO_DAT   = 4;
localparam P_PRC_FIFO_WRDS  = 32;                           // Processor packet FIFO (two long packets)
localparam P_PRC_FIFO_ADR   = $clog2(P_PRC_FIFO_WRDS);
localparam P_PRC_FIFO_DAT   = 33;                           // End of packet and data
localparam P_PRC_PKT_WRDS   = 12;                           // Long packet
localparam P_PRC_QUIET      = 16;                           // Clocks without SDP input activity before a processor packet


//-----
// Functions
//-----
// GF(16) multiplication by alpha (g0)
function logic [3:0] gf_mul_g0 (logic [3:0] a);
    gf_mul_g0[0] = a[3];
    gf_mul_g0[1] = a[0] ^ a[3];
    gf_mul_g0[2] = a[1];
    gf_mul_g0[3] = a[2];
endfunction

// GF(16) multiplication by alpha^4 (g1)
function logic [3:0] gf_mul_g1 (logic [3:0] a);
    gf_mul_g1[0] = a[0] ^ a[3];
    gf_mul_g1[1] = a[0] ^ a[1] ^ a[3];
    gf_mul_g1[2] = a[1] ^ a[2];
    gf_mul_g1[3] = a[2] ^ a[3];
endfunction

// RS(15,13) parity register step for one data nibble
// Register: [7:4] - x1, [3:0] - x0
function logic [7:0] rs_step (logic [7:0] x, logic [3:0] nib);
    rs_step[7:4] = x[3:0] ^ gf_mul_g1(nib ^ x[7:4]);
    rs_step[3:0] = gf_mul_g0(nib ^ x[7:4]);
endfunction


//-----
// State Machine
//-----
typedef enum {
    sm_idle, sm_vb, sm_hb
} sm_state;


//-----
// Structures
//-----
typedef struct {
    logic   [1:0]                   lanes;
} ctl_struct;

typedef struct {
    logic   [P_MSG_IDX-1:0]         idx;
    logic                           first;
    logic                           last;
    logic   [P_MSG_DAT-1:0]         dat;
    logic                           vld;
} msg_struct;

typedef struct {
    logic                           rst;
    logic                           sop;
    logic                           eop;
    logic                           eop_del;
    logic   [31:0]                  dat;
    logic   [31:0]                  dat_del;
    logic                           vld;
    logic                           vld_del;
    logic                           rdy;
    logic   [4:0]                   len;
    logic   [3:0]                   wr_sel;
    logic   [31:0]                  din;                    // FIFO write data (with parity)
} sclk_sdp_struct;

typedef struct {
    logic   [7:0]                   hb_reg[4][0:2];         // Header parity register (per header byte)
    logic   [7:0]                   db_reg[0:8];            // Data parity register
    logic   [31:0]                  pb;                     // Parity word
} sclk_par_struct;

typedef struct {
    logic   [P_MSG_IDX-1:0]         idx;
    logic                           first;
    logic                           last;
    logic   [P_MSG_DAT-1:0]         dat;
    logic                           vld;
    logic   [15:0]                  lo;                     // Lower half of the packet word
    logic                           drop_reg;               // Drop the message (registered)
    logic                           drop;                   // Drop the message
    logic                           wr;                     // FIFO write
    logic   [P_PRC_FIFO_DAT-1:0]    din;                    // FIFO write data
    logic   [P_PRC_FIFO_ADR:0]      wrds;                   // FIFO words
    logic   [3:0]                   pkt_cnt;                // Packet counter
} lclk_prc_struct;

typedef struct {
    logic                           rst;
    logic   [3:0]                   pkt_wr;                 // Written packets (from the link domain)
    logic   [3:0]                   pkt_rd;                 // Read packets
    logic                           pend;                   // Packet pending
    logic                           ext_run;                // SDP input packet running
    logic   [4:0]                   quiet;                  // Clocks without SDP input activity
    logic                           req;                    // Request (the ready of the SDP input is cleared)
    logic                           sel;                    // Processor packet selected
    logic                           first;                  // First word
    logic                           rd_pend;                // Read pending
    logic                           rd;                     // FIFO read
    logic   [P_PRC_FIFO_DAT-1:0]    dout;                   // FIFO read data
    logic                           de;                     // FIFO data enable
    logic                           ep;                     // FIFO empty
    logic                           sop;
    logic                           eop;
    logic   [31:0]                  dat;
    logic                           vld;
} sclk_prc_struct;

typedef struct {
    logic   [1:0]                   wr[4][4];               // Write
    logic   [P_DAT_FIFO_DAT-1:0]    din[4][4][2];           // Write data (LANE - SUBLANE - NIBBLE)
    logic   [P_DAT_FIFO_ADR:0]      wrds[4][4][2];
    logic   [1:0]                   ep[4][4];  
    logic   [1:0]                   fl[4][4];  
} dat_fifo_wr_struct;

typedef struct {
    logic   [1:0]                   rd[4][4];              // Read
    logic   [P_DAT_FIFO_DAT-1:0]    dout[4][4][2];         // Read data (LANE - SUBLANE - NIBBLE)
    logic   [1:0]                   de[4][4];  
} dat_fifo_rd_struct;

typedef struct {
    logic                           wr;                     // Write
    logic   [P_LEN_FIFO_DAT-1:0]    din;                    // Write data 
    logic                           fl;                     // Full
} len_fifo_wr_struct;

typedef struct {
    logic                           rd;                     // Read
    logic   [P_LEN_FIFO_DAT-1:0]    dout;                   // Read data 
    logic                           de;  
} len_fifo_rd_struct;

typedef struct {
    prt_dp_tx_lnk_sym               sym[P_LANES][P_SPL];
    logic [7:0]                     dat[P_LANES][P_SPL];
    logic                           vld;
    logic                           vs;
    logic                           vs_re;
    logic                           vbf;
    logic                           vbf_re;
    logic                           vbf_fe;    
    logic [15:0]                    vstart;
    logic [15:0]                    lin_cnt;
    logic                           bs_det;
    logic                           be_det;
} snk_struct;

typedef struct {
    sm_state                        sm_cur;
    sm_state                        sm_nxt;
    logic                           rst;
    logic                           hb;
    logic                           act;
    logic                           hb_re;
    logic                           hb_fe;
    logic   [15:0]                  hbi_cnt;
    logic   [15:0]                  hbi;
    logic                           vb_set;
    logic                           vb;
    logic                           vb_re;
    logic                           vb_fe;
    logic   [15:0]                  vbi_cnt;
    logic   [15:0]                  vbi;
    logic                           cyc_ld;
    logic   [15:0]                  cyc_in;
    logic   [15:0]                  cyc;
    logic                           cyc_end;
    logic   [7:0]                   pkt_cyc;
    logic   [7:0]                   pkt_cyc_tot;
    logic                           pkt_new;
    logic   [2:0]                   bs_hold;            // BS hold (VB-ID, Mvid and Maud symbols after the BS)
    logic                           msa;                // MSA in the link input
    logic                           rd_cnt_ld;
    logic   [4:0]                   rd_cnt_in;
    logic   [4:0]                   rd_cnt;
    logic                           rd_cnt_end;
    logic   [1:0]                   rd_cnt_end_del;
    logic   [1:0]                   rd_rem_in;          // Symbols in the last read cycle (0 - all symbols)
    logic   [1:0]                   rd_rem;
    logic                           rd_last;            // Last read cycle
    logic   [1:0]                   rem_del[0:2];       // Symbols in the last cycle of a packet that ends within the cycle (delayed)
    logic                           se_edge;
    logic   [2:0]                   rd_sel;
    logic   [2:0]                   rd_sel_last;
    logic   [2:0]                   dat_sel[2];
    logic                           ss_ins;
    logic                           se_ins;
    prt_dp_tx_lnk_sym               sym[P_LANES][P_SPL];
    logic   [7:0]                   dat[P_LANES][P_SPL];
    logic                           vld;    
} lclk_sdp_struct;

typedef struct {
    prt_dp_tx_lnk_sym               sym[P_LANES][P_SPL];
    logic   [7:0]                   dat[P_LANES][P_SPL];
    logic                           vld;
} src_struct;


//-----
// Signals
//-----
ctl_struct              sclk_ctl;
sclk_sdp_struct         sclk_sdp;
sclk_par_struct         sclk_par;
sclk_prc_struct         sclk_prc;
lclk_prc_struct         lclk_prc;
dat_fifo_wr_struct      sclk_dat_fifo;
len_fifo_wr_struct      sclk_len_fifo;
dat_fifo_rd_struct      lclk_dat_fifo;
len_fifo_rd_struct      lclk_len_fifo;
ctl_struct              lclk_ctl;
msg_struct              lclk_msg;
lclk_sdp_struct         lclk_sdp; 
snk_struct              lclk_snk;
src_struct              lclk_src;

genvar i, j, n;

// Message interface between the message slaves
prt_dp_msg_if
#(
    .P_DAT_WIDTH (P_MSG_DAT)
) msg_if_prc();

/*
    SDP Domain
*/

//-----
// Reset
//-----
    prt_lib_rst
    #(
        .P_VENDOR           (P_VENDOR)
    )
SCLK_SDP_RST_INST
    (
        .SRC_RST_IN     (lclk_sdp.rst),
        .SRC_CLK_IN     (LNK_CLK_IN),
        .DST_CLK_IN     (SDP_CLK_IN),
        .DST_RST_OUT    (sclk_sdp.rst)
    );


//-----
// Lanes CDC
//-----
    prt_lib_cdc_vec
    #(
	    .P_VENDOR           (P_VENDOR),
	    .P_WIDTH        ($size(lclk_ctl.lanes))
    )
    SCLK_LANES_CDC_INST
    (
        .SRC_RST_IN     (1'b0),        // No reset, as before
        .SRC_CLK_IN     (LNK_CLK_IN),		// Clock
        .SRC_DAT_IN     (lclk_ctl.lanes),	// Data
        .DST_RST_IN     (1'b0),           // No reset, as before
        .DST_CLK_IN     (SDP_CLK_IN),		// Clock
        .DST_DAT_OUT    (sclk_ctl.lanes)	// Data
    );


//-----
// Processor packets (SDP domain)
//-----
// Reset
    prt_lib_rst
    #(
        .P_VENDOR           (P_VENDOR)
    )
    SCLK_PRC_RST_INST
    (
        .SRC_RST_IN     (LNK_RST_IN),
        .SRC_CLK_IN     (LNK_CLK_IN),
        .DST_CLK_IN     (SDP_CLK_IN),
        .DST_RST_OUT    (sclk_prc.rst)
    );

// Packet counter CDC
    prt_lib_cdc_gray
    #(
        .P_VENDOR       (P_VENDOR),
        .P_WIDTH        ($size(lclk_prc.pkt_cnt))
    )
    SCLK_PRC_CNT_CDC_INST
    (
        .SRC_RST_IN     (LNK_RST_IN),
        .SRC_CLK_IN     (LNK_CLK_IN),
        .SRC_DAT_IN     (lclk_prc.pkt_cnt),
        .DST_RST_IN     (sclk_prc.rst),
        .DST_CLK_IN     (SDP_CLK_IN),
        .DST_DAT_OUT    (sclk_prc.pkt_wr)
    );

// Packet pending
    assign sclk_prc.pend = (sclk_prc.pkt_wr != sclk_prc.pkt_rd) ? 1 : 0;

// SDP input packet running
    always_ff @ (posedge sclk_prc.rst, posedge SDP_CLK_IN)
    begin
        if (sclk_prc.rst)
            sclk_prc.ext_run <= 0;

        else
        begin
            // Clear at the end of packet
            if (SDP_SNK_IF.vld && SDP_SNK_IF.eop)
                sclk_prc.ext_run <= 0;

            // Set at the start of packet
            else if (SDP_SNK_IF.vld && SDP_SNK_IF.sop)
                sclk_prc.ext_run <= 1;
        end
    end

// Request
    always_ff @ (posedge sclk_prc.rst, posedge SDP_CLK_IN)
    begin
        if (sclk_prc.rst)
            sclk_prc.req <= 0;

        else
        begin
            // Clear at the end of the processor packet
            if (sclk_prc.vld && sclk_prc.eop)
                sclk_prc.req <= 0;

            // Set
            else if (sclk_prc.pend)
                sclk_prc.req <= 1;
        end
    end

// Quiet counter
// Clocks without SDP input activity after the request
    always_ff @ (posedge SDP_CLK_IN)
    begin
        if (!sclk_prc.req || sclk_prc.ext_run || SDP_SNK_IF.vld)
            sclk_prc.quiet <= 0;

        else if (sclk_prc.quiet != P_PRC_QUIET)
            sclk_prc.quiet <= sclk_prc.quiet + 'd1;
    end

// Select
// The processor packet is selected when the SDP input is quiet and the FIFOs are ready.
    always_ff @ (posedge sclk_prc.rst, posedge SDP_CLK_IN)
    begin
        if (sclk_prc.rst)
        begin
            sclk_prc.sel <= 0;
            sclk_prc.pkt_rd <= 0;
        end

        else
        begin
            // Clear at the end of the processor packet
            if (sclk_prc.vld && sclk_prc.eop)
            begin
                sclk_prc.sel <= 0;
                sclk_prc.pkt_rd <= sclk_prc.pkt_rd + 'd1;
            end

            // Set
            else if (sclk_prc.req && !sclk_prc.sel && (sclk_prc.quiet == P_PRC_QUIET) && sclk_sdp.rdy)
                sclk_prc.sel <= 1;
        end
    end

// Read
// One word is read at a time, so no word of the next packet is read.
// The packet counter can arrive before the FIFO write pointer, so a word is only read when the FIFO is not empty.
    assign sclk_prc.rd = sclk_prc.sel && !sclk_prc.rd_pend && !sclk_prc.de && !sclk_prc.ep;

    always_ff @ (posedge sclk_prc.rst, posedge SDP_CLK_IN)
    begin
        if (sclk_prc.rst)
            sclk_prc.rd_pend <= 0;

        else
        begin
            if (sclk_prc.rd)
                sclk_prc.rd_pend <= 1;

            else if (sclk_prc.de)
                sclk_prc.rd_pend <= 0;
        end
    end

// First word
    always_ff @ (posedge SDP_CLK_IN)
    begin
        if (!sclk_prc.sel)
            sclk_prc.first <= 1;

        else if (sclk_prc.de)
            sclk_prc.first <= 0;
    end

// Processor packet words
// The start and end of packet are only asserted with the valid (the length FIFO is written with the end of packet).
    assign sclk_prc.vld = sclk_prc.sel && sclk_prc.de;
    assign sclk_prc.sop = sclk_prc.vld && sclk_prc.first;
    assign sclk_prc.eop = sclk_prc.vld && sclk_prc.dout[32];
    assign sclk_prc.dat = sclk_prc.dout[31:0];

// Processor packet FIFO
    prt_lib_fifo_dc
    #(
        .P_VENDOR       (P_VENDOR),                 // Vendor
        .P_FAMILY       (P_FAMILY),                 // Family
        .P_MODE         ("burst"),                  // "single" or "burst"
        .P_RAM_STYLE    ("distributed"),            // "distributed" or "block"
        .P_OPT          (0),                        // In optimized mode the status port are not available. This saves some logic.
        .P_ADR_WIDTH    (P_PRC_FIFO_ADR),
        .P_DAT_WIDTH    (P_PRC_FIFO_DAT)
    )
    PRC_FIFO_INST
    (
        .A_RST_IN       (LNK_RST_IN),               // Reset
        .B_RST_IN       (sclk_prc.rst),
        .A_CLK_IN       (LNK_CLK_IN),               // Clock
        .B_CLK_IN       (SDP_CLK_IN),
        .A_CKE_IN       (1'b1),                     // Clock enable
        .B_CKE_IN       (1'b1),

        // Input (A)
        .A_CLR_IN       (1'b0),                     // Clear
        .A_WR_IN        (lclk_prc.wr),              // Write
        .A_DAT_IN       (lclk_prc.din),             // Write data

        // Output (B)
        .B_CLR_IN       (1'b0),                     // Clear
        .B_RD_IN        (sclk_prc.rd),              // Read
        .B_DAT_OUT      (sclk_prc.dout),            // Read data
        .B_DE_OUT       (sclk_prc.de),              // Data enable

        // Status (A)
        .A_WRDS_OUT     (lclk_prc.wrds),            // Used words
        .A_FL_OUT       (),                         // Full
        .A_EP_OUT       (),                         // Empty

        // Status (B)
        .B_WRDS_OUT     (),                         // Used words
        .B_FL_OUT       (),                         // Full
        .B_EP_OUT       (sclk_prc.ep)               // Empty
    );

// Inputs
// The processor packet takes the SDP input when it is selected.
    always_ff @ (posedge SDP_CLK_IN)
    begin
        if (sclk_prc.sel)
        begin
            sclk_sdp.sop <= sclk_prc.sop;
            sclk_sdp.eop <= sclk_prc.eop;
            sclk_sdp.dat <= sclk_prc.dat;
            sclk_sdp.vld <= sclk_prc.vld;
        end

        else
        begin
            sclk_sdp.sop <= SDP_SNK_IF.sop;
            sclk_sdp.eop <= SDP_SNK_IF.eop;
            sclk_sdp.dat <= SDP_SNK_IF.dat;
            sclk_sdp.vld <= SDP_SNK_IF.vld;
        end
    end

// Data Delayed
// The data must be delayed for the write select clear latency.
    always_ff @ (posedge SDP_CLK_IN)
    begin
        sclk_sdp.dat_del <= sclk_sdp.dat;
        sclk_sdp.vld_del <= sclk_sdp.vld;
    end

// Parity
// Each header byte has its own code word (HB0 - PB0, ..., HB3 - PB3).
// Each data word has its own code word (DB0-3 - PB4, ..., DB28-31 - PB11).
// The nibble order is Data(3:0), Data(7:4) of each byte, starting with the first byte.
    always_comb
    begin
        // Header
        for (int i = 0; i < 4; i++)
        begin
            sclk_par.hb_reg[i][0] = 0;
            sclk_par.hb_reg[i][1] = rs_step(sclk_par.hb_reg[i][0], sclk_sdp.dat_del[(i*8)+:4]);
            sclk_par.hb_reg[i][2] = rs_step(sclk_par.hb_reg[i][1], sclk_sdp.dat_del[((i*8)+4)+:4]);
        end

        // Data
        sclk_par.db_reg[0] = 0;
        for (int i = 0; i < 8; i++)
            sclk_par.db_reg[i+1] = rs_step(sclk_par.db_reg[i], sclk_sdp.dat_del[(i*4)+:4]);
    end

// Parity word
// The parity byte is {x0, x1}, the parity nibbles are sent in the order x1, x0.
    always_ff @ (posedge SDP_CLK_IN)
    begin
        if (sclk_sdp.vld_del)
        begin
            case (sclk_sdp.wr_sel)
                // Header
                'd0 :
                begin
                    for (int i = 0; i < 4; i++)
                        sclk_par.pb[(i*8)+:8] <= {sclk_par.hb_reg[i][2][3:0], sclk_par.hb_reg[i][2][7:4]};
                end

                // DB0-3 to DB12-15
                'd2, 'd3, 'd4, 'd5 :
                    sclk_par.pb[((sclk_sdp.wr_sel-'d2)*8)+:8] <= {sclk_par.db_reg[8][3:0], sclk_par.db_reg[8][7:4]};

                // DB16-19 to DB28-31
                'd7, 'd8, 'd9, 'd10 :
                    sclk_par.pb[((sclk_sdp.wr_sel-'d7)*8)+:8] <= {sclk_par.db_reg[8][3:0], sclk_par.db_reg[8][7:4]};

                default : ;
            endcase
        end
    end

// FIFO write data
// The parity words are replaced by the calculated parity.
    always_comb
    begin
        if ((sclk_sdp.wr_sel == 'd1) || (sclk_sdp.wr_sel == 'd6) || (sclk_sdp.wr_sel == 'd11))
            sclk_sdp.din = sclk_par.pb;
        else
            sclk_sdp.din = sclk_sdp.dat_del;
    end

// EOP Delayed
// This is used for the length fifo write
    always_ff @ (posedge SDP_CLK_IN)
    begin
        sclk_sdp.eop_del <= sclk_sdp.eop;
    end

// Ready
    always_ff @ (posedge SDP_CLK_IN)
    begin
        // Reset
        if (sclk_sdp.rst)
            sclk_sdp.rdy <= 0;

        // FIFOs full
        else if (sclk_dat_fifo.fl[0][0][0] || sclk_len_fifo.fl)
            sclk_sdp.rdy <= 0;

        else
            sclk_sdp.rdy <= 1;
    end

// Length
// This process counter the length of a packet.
    always_ff @ (posedge SDP_CLK_IN)
    begin
        // Clear
        if (sclk_sdp.sop)
            sclk_sdp.len <= 0;
        
        // Increment
        else if (sclk_sdp.vld)
            sclk_sdp.len <= sclk_sdp.len + 'd1;
    end

// Write select
    always_ff @ (posedge SDP_CLK_IN)
    begin
        // Clear
        if (sclk_sdp.sop)
            sclk_sdp.wr_sel <= 0;

        // Increment
        else if (sclk_sdp.vld)
            sclk_sdp.wr_sel <= sclk_sdp.wr_sel + 'd1;
    end

// FIFO write
    always_comb
    begin
        // Default
        for (int i = 0; i < 4; i++)
        begin 
            for (int j = 0; j < 4; j++)
            begin
                for (int n = 0; n < 2; n++)
                    sclk_dat_fifo.wr[i][j][n] = 0;
            end
        end

        if (sclk_sdp.vld_del)
        begin
            // One lane
            if (sclk_ctl.lanes == 'd1)
            begin
                case (sclk_sdp.wr_sel)
                    'd1 : 
                    begin
                        sclk_dat_fifo.wr[0][1][0] = 1;  // PB0[3:0]
                        sclk_dat_fifo.wr[0][3][1] = 1;  // PB0[7:4]
                        sclk_dat_fifo.wr[0][1][1] = 1;  // PB1[3:0]
                        sclk_dat_fifo.wr[0][3][0] = 1;  // PB1[7:4]
                        sclk_dat_fifo.wr[1][1][0] = 1;  // PB2[3:0]
                        sclk_dat_fifo.wr[1][3][1] = 1;  // PB2[7:4]
                        sclk_dat_fifo.wr[1][1][1] = 1;  // PB3[3:0]
                        sclk_dat_fifo.wr[1][3][0] = 1;  // PB3[7:4]
                    end

                    'd2 : 
                    begin
                        sclk_dat_fifo.wr[2][0][0] = 1;  // DB0[3:0]
                        sclk_dat_fifo.wr[3][1][1] = 1;  // DB0[7:4]
                        sclk_dat_fifo.wr[2][1][0] = 1;  // DB1[3:0]
                        sclk_dat_fifo.wr[3][2][1] = 1;  // DB1[7:4]
                        sclk_dat_fifo.wr[2][2][0] = 1;  // DB2[3:0]
                        sclk_dat_fifo.wr[3][3][1] = 1;  // DB2[7:4]
                        sclk_dat_fifo.wr[2][3][0] = 1;  // DB3[3:0]
                        sclk_dat_fifo.wr[0][0][1] = 1;  // DB3[7:4]
                    end

                    'd3 :
                    begin
                        sclk_dat_fifo.wr[2][0][1] = 1;  // DB4[3:0]
                        sclk_dat_fifo.wr[3][1][0] = 1;  // DB4[7:4]
                        sclk_dat_fifo.wr[2][1][1] = 1;  // DB5[3:0]
                        sclk_dat_fifo.wr[3][2][0] = 1;  // DB5[7:4]
                        sclk_dat_fifo.wr[2][2][1] = 1;  // DB6[3:0]
                        sclk_dat_fifo.wr[3][3][0] = 1;  // DB6[7:4]
                        sclk_dat_fifo.wr[2][3][1] = 1;  // DB7[3:0]
                        sclk_dat_fifo.wr[0][0][0] = 1;  // DB7[7:4]
                    end

                    'd4 :
                    begin
                        sclk_dat_fifo.wr[0][2][0] = 1;  // DB8[3:0]
                        sclk_dat_fifo.wr[1][3][1] = 1;  // DB8[7:4]
                        sclk_dat_fifo.wr[0][3][0] = 1;  // DB9[3:0]
                        sclk_dat_fifo.wr[2][0][1] = 1;  // DB9[7:4]
                        sclk_dat_fifo.wr[1][0][0] = 1;  // DB10[3:0]
                        sclk_dat_fifo.wr[2][1][1] = 1;  // DB10[7:4]
                        sclk_dat_fifo.wr[1][1][0] = 1;  // DB11[3:0]
                        sclk_dat_fifo.wr[2][2][1] = 1;  // DB11[7:4]
                    end

                    'd5 :
                    begin
                        sclk_dat_fifo.wr[0][2][1] = 1;  // DB12[3:0]
                        sclk_dat_fifo.wr[1][3][0] = 1;  // DB12[7:4]
                        sclk_dat_fifo.wr[0][3][1] = 1;  // DB13[3:0]
                        sclk_dat_fifo.wr[2][0][0] = 1;  // DB13[7:4]
                        sclk_dat_fifo.wr[1][0][1] = 1;  // DB14[3:0]
                        sclk_dat_fifo.wr[2][1][0] = 1;  // DB14[7:4]
                        sclk_dat_fifo.wr[1][1][1] = 1;  // DB15[3:0]
                        sclk_dat_fifo.wr[2][2][0] = 1;  // DB15[7:4]
                    end

                    'd6 : 
                    begin
                        sclk_dat_fifo.wr[3][0][0] = 1;  // PB4[3:0]
                        sclk_dat_fifo.wr[0][1][1] = 1;  // PB4[7:4]
                        sclk_dat_fifo.wr[3][0][1] = 1;  // PB5[3:0]
                        sclk_dat_fifo.wr[0][1][0] = 1;  // PB5[7:4]
                        sclk_dat_fifo.wr[1][2][0] = 1;  // PB6[3:0]
                        sclk_dat_fifo.wr[2][3][1] = 1;  // PB6[7:4]
                        sclk_dat_fifo.wr[1][2][1] = 1;  // PB7[3:0]
                        sclk_dat_fifo.wr[2][3][0] = 1;  // PB7[7:4]
                    end

                    'd7 :
                    begin
                        sclk_dat_fifo.wr[3][0][0] = 1;  // DB16[3:0]
                        sclk_dat_fifo.wr[0][1][1] = 1;  // DB16[7:4]
                        sclk_dat_fifo.wr[3][1][0] = 1;  // DB17[3:0]
                        sclk_dat_fifo.wr[0][2][1] = 1;  // DB17[7:4]
                        sclk_dat_fifo.wr[3][2][0] = 1;  // DB18[3:0]
                        sclk_dat_fifo.wr[0][3][1] = 1;  // DB18[7:4]
                        sclk_dat_fifo.wr[3][3][0] = 1;  // DB19[3:0]
                        sclk_dat_fifo.wr[1][0][1] = 1;  // DB19[7:4]
                    end

                    'd8 :
                    begin
                        sclk_dat_fifo.wr[3][0][1] = 1;  // DB20[3:0]
                        sclk_dat_fifo.wr[0][1][0] = 1;  // DB20[7:4]
                        sclk_dat_fifo.wr[3][1][1] = 1;  // DB21[3:0]
                        sclk_dat_fifo.wr[0][2][0] = 1;  // DB21[7:4]
                        sclk_dat_fifo.wr[3][2][1] = 1;  // DB22[3:0]
                        sclk_dat_fifo.wr[0][3][0] = 1;  // DB22[7:4]
                        sclk_dat_fifo.wr[3][3][1] = 1;  // DB23[3:0]
                        sclk_dat_fifo.wr[1][0][0] = 1;  // DB23[7:4]
                    end

                    'd9 :
                    begin
                        sclk_dat_fifo.wr[1][2][0] = 1;  // DB24[3:0]
                        sclk_dat_fifo.wr[2][3][1] = 1;  // DB24[7:4]
                        sclk_dat_fifo.wr[1][3][0] = 1;  // DB25[3:0]
                        sclk_dat_fifo.wr[3][0][1] = 1;  // DB25[7:4]
                        sclk_dat_fifo.wr[2][0][0] = 1;  // DB26[3:0]
                        sclk_dat_fifo.wr[3][1][1] = 1;  // DB26[7:4]
                        sclk_dat_fifo.wr[2][1][0] = 1;  // DB27[3:0]
                        sclk_dat_fifo.wr[3][2][1] = 1;  // DB27[7:4]
                    end

                    'd10 :
                    begin
                        sclk_dat_fifo.wr[1][2][1] = 1;  // DB28[3:0]
                        sclk_dat_fifo.wr[2][3][0] = 1;  // DB28[7:4]
                        sclk_dat_fifo.wr[1][3][1] = 1;  // DB29[3:0]
                        sclk_dat_fifo.wr[3][0][0] = 1;  // DB29[7:4]
                        sclk_dat_fifo.wr[2][0][1] = 1;  // DB30[3:0]
                        sclk_dat_fifo.wr[3][1][0] = 1;  // DB30[7:4]
                        sclk_dat_fifo.wr[2][1][1] = 1;  // DB31[3:0]
                        sclk_dat_fifo.wr[3][2][0] = 1;  // DB31[7:4]
                    end

                    'd11 : 
                    begin
                        sclk_dat_fifo.wr[0][0][0] = 1;  // PB8[3:0]
                        sclk_dat_fifo.wr[1][1][1] = 1;  // PB8[7:4]
                        sclk_dat_fifo.wr[0][0][1] = 1;  // PB9[3:0]
                        sclk_dat_fifo.wr[1][1][0] = 1;  // PB9[7:4]
                        sclk_dat_fifo.wr[2][2][0] = 1;  // PB10[3:0]
                        sclk_dat_fifo.wr[3][3][1] = 1;  // PB10[7:4]
                        sclk_dat_fifo.wr[2][2][1] = 1;  // PB11[3:0]
                        sclk_dat_fifo.wr[3][3][0] = 1;  // PB11[7:4]
                    end

                    default : 
                    begin
                        sclk_dat_fifo.wr[0][0][0] = 1;  // HB0[3:0]
                        sclk_dat_fifo.wr[0][2][1] = 1;  // HB0[7:4]
                        sclk_dat_fifo.wr[0][0][1] = 1;  // HB1[3:0]
                        sclk_dat_fifo.wr[0][2][0] = 1;  // HB1[7:4]
                        sclk_dat_fifo.wr[1][0][0] = 1;  // HB2[3:0]
                        sclk_dat_fifo.wr[1][2][1] = 1;  // HB2[7:4]
                        sclk_dat_fifo.wr[1][0][1] = 1;  // HB3[3:0]
                        sclk_dat_fifo.wr[1][2][0] = 1;  // HB3[7:4]
                    end
                endcase
            end

            // Two lanes
            else if (sclk_ctl.lanes == 'd2)
            begin
                case (sclk_sdp.wr_sel)
                    'd1 : 
                    begin
                        sclk_dat_fifo.wr[0][1][0] = 1;  // PB0[3:0]
                        sclk_dat_fifo.wr[2][1][1] = 1;  // PB0[7:4]
                        sclk_dat_fifo.wr[2][1][0] = 1;  // PB1[3:0]
                        sclk_dat_fifo.wr[0][1][1] = 1;  // PB1[7:4]
                        sclk_dat_fifo.wr[0][3][0] = 1;  // PB2[3:0]
                        sclk_dat_fifo.wr[2][3][1] = 1;  // PB2[7:4]
                        sclk_dat_fifo.wr[2][3][0] = 1;  // PB3[3:0]
                        sclk_dat_fifo.wr[0][3][1] = 1;  // PB3[7:4]
                    end

                    'd2 : 
                    begin
                        sclk_dat_fifo.wr[1][0][0] = 1;  // DB0[3:0]
                        sclk_dat_fifo.wr[3][0][1] = 1;  // DB0[7:4]
                        sclk_dat_fifo.wr[1][1][0] = 1;  // DB1[3:0]
                        sclk_dat_fifo.wr[3][1][1] = 1;  // DB1[7:4]
                        sclk_dat_fifo.wr[1][2][0] = 1;  // DB2[3:0]
                        sclk_dat_fifo.wr[3][2][1] = 1;  // DB2[7:4]
                        sclk_dat_fifo.wr[1][3][0] = 1;  // DB3[3:0]
                        sclk_dat_fifo.wr[3][3][1] = 1;  // DB3[7:4]
                    end

                    'd3 :
                    begin
                        sclk_dat_fifo.wr[3][0][0] = 1;  // DB4[3:0]
                        sclk_dat_fifo.wr[1][0][1] = 1;  // DB4[7:4]
                        sclk_dat_fifo.wr[3][1][0] = 1;  // DB5[3:0]
                        sclk_dat_fifo.wr[1][1][1] = 1;  // DB5[7:4]
                        sclk_dat_fifo.wr[3][2][0] = 1;  // DB6[3:0]
                        sclk_dat_fifo.wr[1][2][1] = 1;  // DB6[7:4]
                        sclk_dat_fifo.wr[3][3][0] = 1;  // DB7[3:0]
                        sclk_dat_fifo.wr[1][3][1] = 1;  // DB7[7:4]
                    end

                    'd4 :
                    begin
                        sclk_dat_fifo.wr[0][1][0] = 1;  // DB8[3:0]
                        sclk_dat_fifo.wr[2][1][1] = 1;  // DB8[7:4]
                        sclk_dat_fifo.wr[0][2][0] = 1;  // DB9[3:0]
                        sclk_dat_fifo.wr[2][2][1] = 1;  // DB9[7:4]
                        sclk_dat_fifo.wr[0][3][0] = 1;  // DB10[3:0]
                        sclk_dat_fifo.wr[2][3][1] = 1;  // DB10[7:4]
                        sclk_dat_fifo.wr[1][0][0] = 1;  // DB11[3:0]
                        sclk_dat_fifo.wr[3][0][1] = 1;  // DB11[7:4]
                    end

                    'd5 :
                    begin
                        sclk_dat_fifo.wr[2][1][0] = 1;  // DB12[3:0]
                        sclk_dat_fifo.wr[0][1][1] = 1;  // DB12[7:4]
                        sclk_dat_fifo.wr[2][2][0] = 1;  // DB13[3:0]
                        sclk_dat_fifo.wr[0][2][1] = 1;  // DB13[7:4]
                        sclk_dat_fifo.wr[2][3][0] = 1;  // DB14[3:0]
                        sclk_dat_fifo.wr[0][3][1] = 1;  // DB14[7:4]
                        sclk_dat_fifo.wr[3][0][0] = 1;  // DB15[3:0]
                        sclk_dat_fifo.wr[1][0][1] = 1;  // DB15[7:4]
                    end

                    'd6 : 
                    begin
                        sclk_dat_fifo.wr[0][0][0] = 1;  // PB4[3:0]
                        sclk_dat_fifo.wr[2][0][1] = 1;  // PB4[7:4]
                        sclk_dat_fifo.wr[2][0][0] = 1;  // PB5[3:0]
                        sclk_dat_fifo.wr[0][0][1] = 1;  // PB5[7:4]
                        sclk_dat_fifo.wr[1][1][0] = 1;  // PB6[3:0]
                        sclk_dat_fifo.wr[3][1][1] = 1;  // PB6[7:4]
                        sclk_dat_fifo.wr[3][1][0] = 1;  // PB7[3:0]
                        sclk_dat_fifo.wr[1][1][1] = 1;  // PB7[7:4]
                    end

                    'd7 :
                    begin
                        sclk_dat_fifo.wr[1][2][0] = 1;  // DB16[3:0]
                        sclk_dat_fifo.wr[3][2][1] = 1;  // DB16[7:4]
                        sclk_dat_fifo.wr[1][3][0] = 1;  // DB17[3:0]
                        sclk_dat_fifo.wr[3][3][1] = 1;  // DB17[7:4]
                        sclk_dat_fifo.wr[0][0][0] = 1;  // DB18[3:0]
                        sclk_dat_fifo.wr[2][0][1] = 1;  // DB18[7:4]
                        sclk_dat_fifo.wr[0][1][0] = 1;  // DB19[3:0]
                        sclk_dat_fifo.wr[2][1][1] = 1;  // DB19[7:4]
                    end

                    'd8 :
                    begin
                        sclk_dat_fifo.wr[3][2][0] = 1;  // DB20[3:0]
                        sclk_dat_fifo.wr[1][2][1] = 1;  // DB20[7:4]
                        sclk_dat_fifo.wr[3][3][0] = 1;  // DB21[3:0]
                        sclk_dat_fifo.wr[1][3][1] = 1;  // DB21[7:4]
                        sclk_dat_fifo.wr[2][0][0] = 1;  // DB22[3:0]
                        sclk_dat_fifo.wr[0][0][1] = 1;  // DB22[7:4]
                        sclk_dat_fifo.wr[2][1][0] = 1;  // DB23[3:0]
                        sclk_dat_fifo.wr[0][1][1] = 1;  // DB23[7:4]
                    end

                    'd9 :
                    begin
                        sclk_dat_fifo.wr[0][3][0] = 1;  // DB24[3:0]
                        sclk_dat_fifo.wr[2][3][1] = 1;  // DB24[7:4]
                        sclk_dat_fifo.wr[1][0][0] = 1;  // DB25[3:0]
                        sclk_dat_fifo.wr[3][0][1] = 1;  // DB25[7:4]
                        sclk_dat_fifo.wr[1][1][0] = 1;  // DB26[3:0]
                        sclk_dat_fifo.wr[3][1][1] = 1;  // DB26[7:4]
                        sclk_dat_fifo.wr[1][2][0] = 1;  // DB27[3:0]
                        sclk_dat_fifo.wr[3][2][1] = 1;  // DB27[7:4]
                    end

                    'd10 :
                    begin
                        sclk_dat_fifo.wr[2][3][0] = 1;  // DB28[3:0]
                        sclk_dat_fifo.wr[0][3][1] = 1;  // DB28[7:4]
                        sclk_dat_fifo.wr[3][0][0] = 1;  // DB29[3:0]
                        sclk_dat_fifo.wr[1][0][1] = 1;  // DB29[7:4]
                        sclk_dat_fifo.wr[3][1][0] = 1;  // DB30[3:0]
                        sclk_dat_fifo.wr[1][1][1] = 1;  // DB30[7:4]
                        sclk_dat_fifo.wr[3][2][0] = 1;  // DB31[3:0]
                        sclk_dat_fifo.wr[1][2][1] = 1;  // DB31[7:4]
                    end

                    'd11 : 
                    begin
                        sclk_dat_fifo.wr[0][2][0] = 1;  // PB8[3:0]
                        sclk_dat_fifo.wr[2][2][1] = 1;  // PB8[7:4]
                        sclk_dat_fifo.wr[2][2][0] = 1;  // PB9[3:0]
                        sclk_dat_fifo.wr[0][2][1] = 1;  // PB9[7:4]
                        sclk_dat_fifo.wr[1][3][0] = 1;  // PB10[3:0]
                        sclk_dat_fifo.wr[3][3][1] = 1;  // PB10[7:4]
                        sclk_dat_fifo.wr[3][3][0] = 1;  // PB11[3:0]
                        sclk_dat_fifo.wr[1][3][1] = 1;  // PB11[7:4]
                    end

                    default : 
                    begin
                        sclk_dat_fifo.wr[0][0][0] = 1;  // HB0[3:0]
                        sclk_dat_fifo.wr[2][0][1] = 1;  // HB0[7:4]
                        sclk_dat_fifo.wr[2][0][0] = 1;  // HB1[3:0]
                        sclk_dat_fifo.wr[0][0][1] = 1;  // HB1[7:4]
                        sclk_dat_fifo.wr[0][2][0] = 1;  // HB2[3:0]
                        sclk_dat_fifo.wr[2][2][1] = 1;  // HB2[7:4]
                        sclk_dat_fifo.wr[2][2][0] = 1;  // HB3[3:0]
                        sclk_dat_fifo.wr[0][2][1] = 1;  // HB3[7:4]
                    end
                endcase
            end

            // Four lanes
            else
            begin
                case (sclk_sdp.wr_sel)
                    'd1 : 
                    begin
                        sclk_dat_fifo.wr[0][1][0] = 1;  // PB0[3:0]
                        sclk_dat_fifo.wr[1][1][1] = 1;  // PB0[7:4]
                        sclk_dat_fifo.wr[1][1][0] = 1;  // PB1[3:0]
                        sclk_dat_fifo.wr[0][1][1] = 1;  // PB1[7:4]
                        sclk_dat_fifo.wr[2][1][0] = 1;  // PB2[3:0]
                        sclk_dat_fifo.wr[3][1][1] = 1;  // PB2[7:4]
                        sclk_dat_fifo.wr[3][1][0] = 1;  // PB3[3:0]
                        sclk_dat_fifo.wr[2][1][1] = 1;  // PB3[7:4]
                    end

                    'd2 :
                    begin
                        sclk_dat_fifo.wr[0][2][0] = 1;  // DB0[3:0]
                        sclk_dat_fifo.wr[1][2][1] = 1;  // DB0[7:4]
                        sclk_dat_fifo.wr[0][3][0] = 1;  // DB1[3:0]
                        sclk_dat_fifo.wr[1][3][1] = 1;  // DB1[7:4]
                        sclk_dat_fifo.wr[0][0][0] = 1;  // DB2[3:0]
                        sclk_dat_fifo.wr[1][0][1] = 1;  // DB2[7:4]
                        sclk_dat_fifo.wr[0][1][0] = 1;  // DB3[3:0]
                        sclk_dat_fifo.wr[1][1][1] = 1;  // DB3[7:4]
                    end

                    'd3 :
                    begin
                        sclk_dat_fifo.wr[1][2][0] = 1;  // DB4[3:0]
                        sclk_dat_fifo.wr[0][2][1] = 1;  // DB4[7:4]
                        sclk_dat_fifo.wr[1][3][0] = 1;  // DB5[3:0]
                        sclk_dat_fifo.wr[0][3][1] = 1;  // DB5[7:4]
                        sclk_dat_fifo.wr[1][0][0] = 1;  // DB6[3:0]
                        sclk_dat_fifo.wr[0][0][1] = 1;  // DB6[7:4]
                        sclk_dat_fifo.wr[1][1][0] = 1;  // DB7[3:0]
                        sclk_dat_fifo.wr[0][1][1] = 1;  // DB7[7:4]
                    end

                    'd4 :
                    begin
                        sclk_dat_fifo.wr[2][2][0] = 1;  // DB8[3:0]
                        sclk_dat_fifo.wr[3][2][1] = 1;  // DB8[7:4]
                        sclk_dat_fifo.wr[2][3][0] = 1;  // DB9[3:0]
                        sclk_dat_fifo.wr[3][3][1] = 1;  // DB9[7:4]
                        sclk_dat_fifo.wr[2][0][0] = 1;  // DB10[3:0]
                        sclk_dat_fifo.wr[3][0][1] = 1;  // DB10[7:4]
                        sclk_dat_fifo.wr[2][1][0] = 1;  // DB11[3:0]
                        sclk_dat_fifo.wr[3][1][1] = 1;  // DB11[7:4]
                    end

                    'd5 :
                    begin
                        sclk_dat_fifo.wr[3][2][0] = 1;  // DB12[3:0]
                        sclk_dat_fifo.wr[2][2][1] = 1;  // DB12[7:4]
                        sclk_dat_fifo.wr[3][3][0] = 1;  // DB13[3:0]
                        sclk_dat_fifo.wr[2][3][1] = 1;  // DB13[7:4]
                        sclk_dat_fifo.wr[3][0][0] = 1;  // DB14[3:0]
                        sclk_dat_fifo.wr[2][0][1] = 1;  // DB14[7:4]
                        sclk_dat_fifo.wr[3][1][0] = 1;  // DB15[3:0]
                        sclk_dat_fifo.wr[2][1][1] = 1;  // DB15[7:4]
                    end

                    'd6 : 
                    begin
                        sclk_dat_fifo.wr[0][2][0] = 1;  // PB4[3:0]
                        sclk_dat_fifo.wr[1][2][1] = 1;  // PB4[7:4]
                        sclk_dat_fifo.wr[1][2][0] = 1;  // PB5[3:0]
                        sclk_dat_fifo.wr[0][2][1] = 1;  // PB5[7:4]
                        sclk_dat_fifo.wr[2][2][0] = 1;  // PB6[3:0]
                        sclk_dat_fifo.wr[3][2][1] = 1;  // PB6[7:4]
                        sclk_dat_fifo.wr[3][2][0] = 1;  // PB7[3:0]
                        sclk_dat_fifo.wr[2][2][1] = 1;  // PB7[7:4]
                    end

                    'd7 :
                    begin
                        sclk_dat_fifo.wr[0][3][0] = 1;  // DB16[3:0]
                        sclk_dat_fifo.wr[1][3][1] = 1;  // DB16[7:4]
                        sclk_dat_fifo.wr[0][0][0] = 1;  // DB17[3:0]
                        sclk_dat_fifo.wr[1][0][1] = 1;  // DB17[7:4]
                        sclk_dat_fifo.wr[0][1][0] = 1;  // DB18[3:0]
                        sclk_dat_fifo.wr[1][1][1] = 1;  // DB18[7:4]
                        sclk_dat_fifo.wr[0][2][0] = 1;  // DB19[3:0]
                        sclk_dat_fifo.wr[1][2][1] = 1;  // DB19[7:4]
                    end

                    'd8 :
                    begin
                        sclk_dat_fifo.wr[1][3][0] = 1;  // DB20[3:0]
                        sclk_dat_fifo.wr[0][3][1] = 1;  // DB20[7:4]
                        sclk_dat_fifo.wr[1][0][0] = 1;  // DB21[3:0]
                        sclk_dat_fifo.wr[0][0][1] = 1;  // DB21[7:4]
                        sclk_dat_fifo.wr[1][1][0] = 1;  // DB22[3:0]
                        sclk_dat_fifo.wr[0][1][1] = 1;  // DB22[7:4]
                        sclk_dat_fifo.wr[1][2][0] = 1;  // DB23[3:0]
                        sclk_dat_fifo.wr[0][2][1] = 1;  // DB23[7:4]
                    end

                    'd9 :
                    begin
                        sclk_dat_fifo.wr[2][3][0] = 1;  // DB24[3:0]
                        sclk_dat_fifo.wr[3][3][1] = 1;  // DB24[7:4]
                        sclk_dat_fifo.wr[2][0][0] = 1;  // DB25[3:0]
                        sclk_dat_fifo.wr[3][0][1] = 1;  // DB25[7:4]
                        sclk_dat_fifo.wr[2][1][0] = 1;  // DB26[3:0]
                        sclk_dat_fifo.wr[3][1][1] = 1;  // DB26[7:4]
                        sclk_dat_fifo.wr[2][2][0] = 1;  // DB27[3:0]
                        sclk_dat_fifo.wr[3][2][1] = 1;  // DB27[7:4]
                    end

                    'd10 :
                    begin
                        sclk_dat_fifo.wr[3][3][0] = 1;  // DB28[3:0]
                        sclk_dat_fifo.wr[2][3][1] = 1;  // DB28[7:4]
                        sclk_dat_fifo.wr[3][0][0] = 1;  // DB29[3:0]
                        sclk_dat_fifo.wr[2][0][1] = 1;  // DB29[7:4]
                        sclk_dat_fifo.wr[3][1][0] = 1;  // DB30[3:0]
                        sclk_dat_fifo.wr[2][1][1] = 1;  // DB30[7:4]
                        sclk_dat_fifo.wr[3][2][0] = 1;  // DB31[3:0]
                        sclk_dat_fifo.wr[2][2][1] = 1;  // DB31[7:4]
                    end

                    'd11 : 
                    begin
                        sclk_dat_fifo.wr[0][3][0] = 1;  // PB8[3:0]
                        sclk_dat_fifo.wr[1][3][1] = 1;  // PB8[7:4]
                        sclk_dat_fifo.wr[1][3][0] = 1;  // PB9[3:0]
                        sclk_dat_fifo.wr[0][3][1] = 1;  // PB9[7:4]
                        sclk_dat_fifo.wr[2][3][0] = 1;  // PB10[3:0]
                        sclk_dat_fifo.wr[3][3][1] = 1;  // PB10[7:4]
                        sclk_dat_fifo.wr[3][3][0] = 1;  // PB11[3:0]
                        sclk_dat_fifo.wr[2][3][1] = 1;  // PB11[7:4]
                    end

                    default : 
                    begin
                        sclk_dat_fifo.wr[0][0][0] = 1;  // HB0[3:0]
                        sclk_dat_fifo.wr[1][0][1] = 1;  // HB0[7:4]
                        sclk_dat_fifo.wr[1][0][0] = 1;  // HB1[3:0]
                        sclk_dat_fifo.wr[0][0][1] = 1;  // HB1[7:4]
                        sclk_dat_fifo.wr[2][0][0] = 1;  // HB2[3:0]
                        sclk_dat_fifo.wr[3][0][1] = 1;  // HB2[7:4]
                        sclk_dat_fifo.wr[3][0][0] = 1;  // HB3[3:0]
                        sclk_dat_fifo.wr[2][0][1] = 1;  // HB3[7:4]
                    end
                endcase
            end
        end
    end

// FIFO write data
    always_comb
    begin
        // Default
        for (int i = 0; i < 4; i++)
        begin 
            for (int j = 0; j < 4; j++)
            begin
                for (int n = 0; n < 2; n++)
                    sclk_dat_fifo.din[i][j][n] = 0;
            end
        end

        // One lane
        if (sclk_ctl.lanes == 'd1)
        begin
            case (sclk_sdp.wr_sel)
                'd1 : 
                begin
                    sclk_dat_fifo.din[0][1][0] = sclk_sdp.din[(0*8)+:4]    ;  // PB0[3:0]
                    sclk_dat_fifo.din[0][3][1] = sclk_sdp.din[((0*8)+4)+:4];  // PB0[7:4]
                    sclk_dat_fifo.din[0][1][1] = sclk_sdp.din[(1*8)+:4]    ;  // PB1[3:0]
                    sclk_dat_fifo.din[0][3][0] = sclk_sdp.din[((1*8)+4)+:4];  // PB1[7:4]
                    sclk_dat_fifo.din[1][1][0] = sclk_sdp.din[(2*8)+:4]    ;  // PB2[3:0]
                    sclk_dat_fifo.din[1][3][1] = sclk_sdp.din[((2*8)+4)+:4];  // PB2[7:4]
                    sclk_dat_fifo.din[1][1][1] = sclk_sdp.din[(3*8)+:4]    ;  // PB3[3:0]
                    sclk_dat_fifo.din[1][3][0] = sclk_sdp.din[((3*8)+4)+:4];  // PB3[7:4]
                end

                'd2 : 
                begin
                     sclk_dat_fifo.din[2][0][0] = sclk_sdp.din[(0*8)+:4]    ;  // DB0[3:0]
                     sclk_dat_fifo.din[3][1][1] = sclk_sdp.din[((0*8)+4)+:4];  // DB0[7:4]
                     sclk_dat_fifo.din[2][1][0] = sclk_sdp.din[(1*8)+:4]    ;  // DB1[3:0]
                     sclk_dat_fifo.din[3][2][1] = sclk_sdp.din[((1*8)+4)+:4];  // DB1[7:4]
                     sclk_dat_fifo.din[2][2][0] = sclk_sdp.din[(2*8)+:4]    ;  // DB2[3:0]
                     sclk_dat_fifo.din[3][3][1] = sclk_sdp.din[((2*8)+4)+:4];  // DB2[7:4]
                     sclk_dat_fifo.din[2][3][0] = sclk_sdp.din[(3*8)+:4]    ;  // DB3[3:0]
                     sclk_dat_fifo.din[0][0][1] = sclk_sdp.din[((3*8)+4)+:4];  // DB3[7:4]
                end

                'd3 :
                begin
                    sclk_dat_fifo.din[2][0][1] = sclk_sdp.din[(0*8)+:4]    ;  // DB4[3:0]
                    sclk_dat_fifo.din[3][1][0] = sclk_sdp.din[((0*8)+4)+:4];  // DB4[7:4]
                    sclk_dat_fifo.din[2][1][1] = sclk_sdp.din[(1*8)+:4]    ;  // DB5[3:0]
                    sclk_dat_fifo.din[3][2][0] = sclk_sdp.din[((1*8)+4)+:4];  // DB5[7:4]
                    sclk_dat_fifo.din[2][2][1] = sclk_sdp.din[(2*8)+:4]    ;  // DB6[3:0]
                    sclk_dat_fifo.din[3][3][0] = sclk_sdp.din[((2*8)+4)+:4];  // DB6[7:4]
                    sclk_dat_fifo.din[2][3][1] = sclk_sdp.din[(3*8)+:4]    ;  // DB7[3:0]
                    sclk_dat_fifo.din[0][0][0] = sclk_sdp.din[((3*8)+4)+:4];  // DB7[7:4]
                end

                'd4 :
                begin
                    sclk_dat_fifo.din[0][2][0] = sclk_sdp.din[(0*8)+:4]    ;  // DB8[3:0]
                    sclk_dat_fifo.din[1][3][1] = sclk_sdp.din[((0*8)+4)+:4];  // DB8[7:4]
                    sclk_dat_fifo.din[0][3][0] = sclk_sdp.din[(1*8)+:4]    ;  // DB9[3:0]
                    sclk_dat_fifo.din[2][0][1] = sclk_sdp.din[((1*8)+4)+:4];  // DB9[7:4]
                    sclk_dat_fifo.din[1][0][0] = sclk_sdp.din[(2*8)+:4]    ;  // DB10[3:0]
                    sclk_dat_fifo.din[2][1][1] = sclk_sdp.din[((2*8)+4)+:4];  // DB10[7:4]
                    sclk_dat_fifo.din[1][1][0] = sclk_sdp.din[(3*8)+:4]    ;  // DB11[3:0]
                    sclk_dat_fifo.din[2][2][1] = sclk_sdp.din[((3*8)+4)+:4];  // DB11[7:4]
                end

                'd5 :
                begin
                   sclk_dat_fifo.din[0][2][1] = sclk_sdp.din[(0*8)+:4]    ;  // DB12[3:0]
                   sclk_dat_fifo.din[1][3][0] = sclk_sdp.din[((0*8)+4)+:4];  // DB12[7:4]
                   sclk_dat_fifo.din[0][3][1] = sclk_sdp.din[(1*8)+:4]    ;  // DB13[3:0]
                   sclk_dat_fifo.din[2][0][0] = sclk_sdp.din[((1*8)+4)+:4];  // DB13[7:4]
                   sclk_dat_fifo.din[1][0][1] = sclk_sdp.din[(2*8)+:4]    ;  // DB14[3:0]
                   sclk_dat_fifo.din[2][1][0] = sclk_sdp.din[((2*8)+4)+:4];  // DB14[7:4]
                   sclk_dat_fifo.din[1][1][1] = sclk_sdp.din[(3*8)+:4]    ;  // DB15[3:0]
                   sclk_dat_fifo.din[2][2][0] = sclk_sdp.din[((3*8)+4)+:4];  // DB15[7:4]
                end

                'd6 : 
                begin
                    sclk_dat_fifo.din[3][0][0] = sclk_sdp.din[(0*8)+:4]    ;  // PB4[3:0]
                    sclk_dat_fifo.din[0][1][1] = sclk_sdp.din[((0*8)+4)+:4];  // PB4[7:4]
                    sclk_dat_fifo.din[3][0][1] = sclk_sdp.din[(1*8)+:4]    ;  // PB5[3:0]
                    sclk_dat_fifo.din[0][1][0] = sclk_sdp.din[((1*8)+4)+:4];  // PB5[7:4]
                    sclk_dat_fifo.din[1][2][0] = sclk_sdp.din[(2*8)+:4]    ;  // PB6[3:0]
                    sclk_dat_fifo.din[2][3][1] = sclk_sdp.din[((2*8)+4)+:4];  // PB6[7:4]
                    sclk_dat_fifo.din[1][2][1] = sclk_sdp.din[(3*8)+:4]    ;  // PB7[3:0]
                    sclk_dat_fifo.din[2][3][0] = sclk_sdp.din[((3*8)+4)+:4];  // PB7[7:4]
                end

                'd7 :
                begin
                    sclk_dat_fifo.din[3][0][0] = sclk_sdp.din[(0*8)+:4]    ;  // DB16[3:0]
                    sclk_dat_fifo.din[0][1][1] = sclk_sdp.din[((0*8)+4)+:4];  // DB16[7:4]
                    sclk_dat_fifo.din[3][1][0] = sclk_sdp.din[(1*8)+:4]    ;  // DB17[3:0]
                    sclk_dat_fifo.din[0][2][1] = sclk_sdp.din[((1*8)+4)+:4];  // DB17[7:4]
                    sclk_dat_fifo.din[3][2][0] = sclk_sdp.din[(2*8)+:4]    ;  // DB18[3:0]
                    sclk_dat_fifo.din[0][3][1] = sclk_sdp.din[((2*8)+4)+:4];  // DB18[7:4]
                    sclk_dat_fifo.din[3][3][0] = sclk_sdp.din[(3*8)+:4]    ;  // DB19[3:0]
                    sclk_dat_fifo.din[1][0][1] = sclk_sdp.din[((3*8)+4)+:4];  // DB19[7:4]
                end

                'd8 :
                begin
                    sclk_dat_fifo.din[3][0][1] = sclk_sdp.din[(0*8)+:4]    ;  // DB20[3:0]
                    sclk_dat_fifo.din[0][1][0] = sclk_sdp.din[((0*8)+4)+:4];  // DB20[7:4]
                    sclk_dat_fifo.din[3][1][1] = sclk_sdp.din[(1*8)+:4]    ;  // DB21[3:0]
                    sclk_dat_fifo.din[0][2][0] = sclk_sdp.din[((1*8)+4)+:4];  // DB21[7:4]
                    sclk_dat_fifo.din[3][2][1] = sclk_sdp.din[(2*8)+:4]    ;  // DB22[3:0]
                    sclk_dat_fifo.din[0][3][0] = sclk_sdp.din[((2*8)+4)+:4];  // DB22[7:4]
                    sclk_dat_fifo.din[3][3][1] = sclk_sdp.din[(3*8)+:4]    ;  // DB23[3:0]
                    sclk_dat_fifo.din[1][0][0] = sclk_sdp.din[((3*8)+4)+:4];  // DB23[7:4]
                end

                'd9 :
                begin
                    sclk_dat_fifo.din[1][2][0] = sclk_sdp.din[(0*8)+:4]    ;  // DB24[3:0]
                    sclk_dat_fifo.din[2][3][1] = sclk_sdp.din[((0*8)+4)+:4];  // DB24[7:4]
                    sclk_dat_fifo.din[1][3][0] = sclk_sdp.din[(1*8)+:4]    ;  // DB25[3:0]
                    sclk_dat_fifo.din[3][0][1] = sclk_sdp.din[((1*8)+4)+:4];  // DB25[7:4]
                    sclk_dat_fifo.din[2][0][0] = sclk_sdp.din[(2*8)+:4]    ;  // DB26[3:0]
                    sclk_dat_fifo.din[3][1][1] = sclk_sdp.din[((2*8)+4)+:4];  // DB26[7:4]
                    sclk_dat_fifo.din[2][1][0] = sclk_sdp.din[(3*8)+:4]    ;  // DB27[3:0]
                    sclk_dat_fifo.din[3][2][1] = sclk_sdp.din[((3*8)+4)+:4];  // DB27[7:4]
                end

                'd10 :
                begin
                    sclk_dat_fifo.din[1][2][1] = sclk_sdp.din[(0*8)+:4]    ;  // DB28[3:0]
                    sclk_dat_fifo.din[2][3][0] = sclk_sdp.din[((0*8)+4)+:4];  // DB28[7:4]
                    sclk_dat_fifo.din[1][3][1] = sclk_sdp.din[(1*8)+:4]    ;  // DB29[3:0]
                    sclk_dat_fifo.din[3][0][0] = sclk_sdp.din[((1*8)+4)+:4];  // DB29[7:4]
                    sclk_dat_fifo.din[2][0][1] = sclk_sdp.din[(2*8)+:4]    ;  // DB30[3:0]
                    sclk_dat_fifo.din[3][1][0] = sclk_sdp.din[((2*8)+4)+:4];  // DB30[7:4]
                    sclk_dat_fifo.din[2][1][1] = sclk_sdp.din[(3*8)+:4]    ;  // DB31[3:0]
                    sclk_dat_fifo.din[3][2][0] = sclk_sdp.din[((3*8)+4)+:4];  // DB31[7:4]
                end

                'd11 : 
                begin
                    sclk_dat_fifo.din[0][0][0] = sclk_sdp.din[(0*8)+:4]    ;  // PB8[3:0]
                    sclk_dat_fifo.din[1][1][1] = sclk_sdp.din[((0*8)+4)+:4];  // PB8[7:4]
                    sclk_dat_fifo.din[0][0][1] = sclk_sdp.din[(1*8)+:4]    ;  // PB9[3:0]
                    sclk_dat_fifo.din[1][1][0] = sclk_sdp.din[((1*8)+4)+:4];  // PB9[7:4]
                    sclk_dat_fifo.din[2][2][0] = sclk_sdp.din[(2*8)+:4]    ;  // PB10[3:0]
                    sclk_dat_fifo.din[3][3][1] = sclk_sdp.din[((2*8)+4)+:4];  // PB10[7:4]
                    sclk_dat_fifo.din[2][2][1] = sclk_sdp.din[(3*8)+:4]    ;  // PB11[3:0]
                    sclk_dat_fifo.din[3][3][0] = sclk_sdp.din[((3*8)+4)+:4];  // PB11[7:4]
                end

                default : 
                begin
                    sclk_dat_fifo.din[0][0][0] = sclk_sdp.din[(0*8)+:4]    ;  // HB0[3:0]
                    sclk_dat_fifo.din[0][2][1] = sclk_sdp.din[((0*8)+4)+:4];  // HB0[7:4]
                    sclk_dat_fifo.din[0][0][1] = sclk_sdp.din[(1*8)+:4]    ;  // HB1[3:0]
                    sclk_dat_fifo.din[0][2][0] = sclk_sdp.din[((1*8)+4)+:4];  // HB1[7:4]
                    sclk_dat_fifo.din[1][0][0] = sclk_sdp.din[(2*8)+:4]    ;  // HB2[3:0]
                    sclk_dat_fifo.din[1][2][1] = sclk_sdp.din[((2*8)+4)+:4];  // HB2[7:4]
                    sclk_dat_fifo.din[1][0][1] = sclk_sdp.din[(3*8)+:4]    ;  // HB3[3:0]
                    sclk_dat_fifo.din[1][2][0] = sclk_sdp.din[((3*8)+4)+:4];  // HB3[7:4]
                end
            endcase
        end

        // Two lanes
        else if (sclk_ctl.lanes == 'd2)
        begin
            case (sclk_sdp.wr_sel)
                'd1 : 
                begin
                    sclk_dat_fifo.din[0][1][0] = sclk_sdp.din[(0*8)+:4]    ;  // PB0[3:0]
                    sclk_dat_fifo.din[2][1][1] = sclk_sdp.din[((0*8)+4)+:4];  // PB0[7:4]
                    sclk_dat_fifo.din[2][1][0] = sclk_sdp.din[(1*8)+:4]    ;  // PB1[3:0]
                    sclk_dat_fifo.din[0][1][1] = sclk_sdp.din[((1*8)+4)+:4];  // PB1[7:4]
                    sclk_dat_fifo.din[0][3][0] = sclk_sdp.din[(2*8)+:4]    ;  // PB2[3:0]
                    sclk_dat_fifo.din[2][3][1] = sclk_sdp.din[((2*8)+4)+:4];  // PB2[7:4]
                    sclk_dat_fifo.din[2][3][0] = sclk_sdp.din[(3*8)+:4]    ;  // PB3[3:0]
                    sclk_dat_fifo.din[0][3][1] = sclk_sdp.din[((3*8)+4)+:4];  // PB3[7:4]
                end

                'd2 : 
                begin
                    sclk_dat_fifo.din[1][0][0] = sclk_sdp.din[(0*8)+:4]    ;  // DB0[3:0]
                    sclk_dat_fifo.din[3][0][1] = sclk_sdp.din[((0*8)+4)+:4];  // DB0[7:4]
                    sclk_dat_fifo.din[1][1][0] = sclk_sdp.din[(1*8)+:4]    ;  // DB1[3:0]
                    sclk_dat_fifo.din[3][1][1] = sclk_sdp.din[((1*8)+4)+:4];  // DB1[7:4]
                    sclk_dat_fifo.din[1][2][0] = sclk_sdp.din[(2*8)+:4]    ;  // DB2[3:0]
                    sclk_dat_fifo.din[3][2][1] = sclk_sdp.din[((2*8)+4)+:4];  // DB2[7:4]
                    sclk_dat_fifo.din[1][3][0] = sclk_sdp.din[(3*8)+:4]    ;  // DB3[3:0]
                    sclk_dat_fifo.din[3][3][1] = sclk_sdp.din[((3*8)+4)+:4];  // DB3[7:4]
                end

                'd3 :
                begin
                    sclk_dat_fifo.din[3][0][0] = sclk_sdp.din[(0*8)+:4]    ;  // DB4[3:0]
                    sclk_dat_fifo.din[1][0][1] = sclk_sdp.din[((0*8)+4)+:4];  // DB4[7:4]
                    sclk_dat_fifo.din[3][1][0] = sclk_sdp.din[(1*8)+:4]    ;  // DB5[3:0]
                    sclk_dat_fifo.din[1][1][1] = sclk_sdp.din[((1*8)+4)+:4];  // DB5[7:4]
                    sclk_dat_fifo.din[3][2][0] = sclk_sdp.din[(2*8)+:4]    ;  // DB6[3:0]
                    sclk_dat_fifo.din[1][2][1] = sclk_sdp.din[((2*8)+4)+:4];  // DB6[7:4]
                    sclk_dat_fifo.din[3][3][0] = sclk_sdp.din[(3*8)+:4]    ;  // DB7[3:0]
                    sclk_dat_fifo.din[1][3][1] = sclk_sdp.din[((3*8)+4)+:4];  // DB7[7:4]
                end

                'd4 :
                begin
                    sclk_dat_fifo.din[0][1][0] = sclk_sdp.din[(0*8)+:4]    ;  // DB8[3:0]
                    sclk_dat_fifo.din[2][1][1] = sclk_sdp.din[((0*8)+4)+:4];  // DB8[7:4]
                    sclk_dat_fifo.din[0][2][0] = sclk_sdp.din[(1*8)+:4]    ;  // DB9[3:0]
                    sclk_dat_fifo.din[2][2][1] = sclk_sdp.din[((1*8)+4)+:4];  // DB9[7:4]
                    sclk_dat_fifo.din[0][3][0] = sclk_sdp.din[(2*8)+:4]    ;  // DB10[3:0]
                    sclk_dat_fifo.din[2][3][1] = sclk_sdp.din[((2*8)+4)+:4];  // DB10[7:4]
                    sclk_dat_fifo.din[1][0][0] = sclk_sdp.din[(3*8)+:4]    ;  // DB11[3:0]
                    sclk_dat_fifo.din[3][0][1] = sclk_sdp.din[((3*8)+4)+:4];  // DB11[7:4]
                end

                'd5 :
                begin
                    sclk_dat_fifo.din[2][1][0] = sclk_sdp.din[(0*8)+:4]    ;  // DB12[3:0]
                    sclk_dat_fifo.din[0][1][1] = sclk_sdp.din[((0*8)+4)+:4];  // DB12[7:4]
                    sclk_dat_fifo.din[2][2][0] = sclk_sdp.din[(1*8)+:4]    ;  // DB13[3:0]
                    sclk_dat_fifo.din[0][2][1] = sclk_sdp.din[((1*8)+4)+:4];  // DB13[7:4]
                    sclk_dat_fifo.din[2][3][0] = sclk_sdp.din[(2*8)+:4]    ;  // DB14[3:0]
                    sclk_dat_fifo.din[0][3][1] = sclk_sdp.din[((2*8)+4)+:4];  // DB14[7:4]
                    sclk_dat_fifo.din[3][0][0] = sclk_sdp.din[(3*8)+:4]    ;  // DB15[3:0]
                    sclk_dat_fifo.din[1][0][1] = sclk_sdp.din[((3*8)+4)+:4];  // DB15[7:4]
                end

                'd6 : 
                begin
                    sclk_dat_fifo.din[0][0][0] = sclk_sdp.din[(0*8)+:4]    ;  // PB4[3:0]
                    sclk_dat_fifo.din[2][0][1] = sclk_sdp.din[((0*8)+4)+:4];  // PB4[7:4]
                    sclk_dat_fifo.din[2][0][0] = sclk_sdp.din[(1*8)+:4]    ;  // PB5[3:0]
                    sclk_dat_fifo.din[0][0][1] = sclk_sdp.din[((1*8)+4)+:4];  // PB5[7:4]
                    sclk_dat_fifo.din[1][1][0] = sclk_sdp.din[(2*8)+:4]    ;  // PB6[3:0]
                    sclk_dat_fifo.din[3][1][1] = sclk_sdp.din[((2*8)+4)+:4];  // PB6[7:4]
                    sclk_dat_fifo.din[3][1][0] = sclk_sdp.din[(3*8)+:4]    ;  // PB7[3:0]
                    sclk_dat_fifo.din[1][1][1] = sclk_sdp.din[((3*8)+4)+:4];  // PB7[7:4]
                end

                'd7 :
                begin
                    sclk_dat_fifo.din[1][2][0] = sclk_sdp.din[(0*8)+:4]    ;  // DB16[3:0]
                    sclk_dat_fifo.din[3][2][1] = sclk_sdp.din[((0*8)+4)+:4];  // DB16[7:4]
                    sclk_dat_fifo.din[1][3][0] = sclk_sdp.din[(1*8)+:4]    ;  // DB17[3:0]
                    sclk_dat_fifo.din[3][3][1] = sclk_sdp.din[((1*8)+4)+:4];  // DB17[7:4]
                    sclk_dat_fifo.din[0][0][0] = sclk_sdp.din[(2*8)+:4]    ;  // DB18[3:0]
                    sclk_dat_fifo.din[2][0][1] = sclk_sdp.din[((2*8)+4)+:4];  // DB18[7:4]
                    sclk_dat_fifo.din[0][1][0] = sclk_sdp.din[(3*8)+:4]    ;  // DB19[3:0]
                    sclk_dat_fifo.din[2][1][1] = sclk_sdp.din[((3*8)+4)+:4];  // DB19[7:4]
                end

                'd8 :
                begin
                    sclk_dat_fifo.din[3][2][0] = sclk_sdp.din[(0*8)+:4]    ;  // DB20[3:0]
                    sclk_dat_fifo.din[1][2][1] = sclk_sdp.din[((0*8)+4)+:4];  // DB20[7:4]
                    sclk_dat_fifo.din[3][3][0] = sclk_sdp.din[(1*8)+:4]    ;  // DB21[3:0]
                    sclk_dat_fifo.din[1][3][1] = sclk_sdp.din[((1*8)+4)+:4];  // DB21[7:4]
                    sclk_dat_fifo.din[2][0][0] = sclk_sdp.din[(2*8)+:4]    ;  // DB22[3:0]
                    sclk_dat_fifo.din[0][0][1] = sclk_sdp.din[((2*8)+4)+:4];  // DB22[7:4]
                    sclk_dat_fifo.din[2][1][0] = sclk_sdp.din[(3*8)+:4]    ;  // DB23[3:0]
                    sclk_dat_fifo.din[0][1][1] = sclk_sdp.din[((3*8)+4)+:4];  // DB23[7:4]
                end

                'd9 :
                begin
                    sclk_dat_fifo.din[0][3][0] = sclk_sdp.din[(0*8)+:4]    ;  // DB24[3:0]
                    sclk_dat_fifo.din[2][3][1] = sclk_sdp.din[((0*8)+4)+:4];  // DB24[7:4]
                    sclk_dat_fifo.din[1][0][0] = sclk_sdp.din[(1*8)+:4]    ;  // DB25[3:0]
                    sclk_dat_fifo.din[3][0][1] = sclk_sdp.din[((1*8)+4)+:4];  // DB25[7:4]
                    sclk_dat_fifo.din[1][1][0] = sclk_sdp.din[(2*8)+:4]    ;  // DB26[3:0]
                    sclk_dat_fifo.din[3][1][1] = sclk_sdp.din[((2*8)+4)+:4];  // DB26[7:4]
                    sclk_dat_fifo.din[1][2][0] = sclk_sdp.din[(3*8)+:4]    ;  // DB27[3:0]
                    sclk_dat_fifo.din[3][2][1] = sclk_sdp.din[((3*8)+4)+:4];  // DB27[7:4]
                end

                'd10 :
                begin
                    sclk_dat_fifo.din[2][3][0] = sclk_sdp.din[(0*8)+:4]    ;  // DB28[3:0]
                    sclk_dat_fifo.din[0][3][1] = sclk_sdp.din[((0*8)+4)+:4];  // DB28[7:4]
                    sclk_dat_fifo.din[3][0][0] = sclk_sdp.din[(1*8)+:4]    ;  // DB29[3:0]
                    sclk_dat_fifo.din[1][0][1] = sclk_sdp.din[((1*8)+4)+:4];  // DB29[7:4]
                    sclk_dat_fifo.din[3][1][0] = sclk_sdp.din[(2*8)+:4]    ;  // DB30[3:0]
                    sclk_dat_fifo.din[1][1][1] = sclk_sdp.din[((2*8)+4)+:4];  // DB30[7:4]
                    sclk_dat_fifo.din[3][2][0] = sclk_sdp.din[(3*8)+:4]    ;  // DB31[3:0]
                    sclk_dat_fifo.din[1][2][1] = sclk_sdp.din[((3*8)+4)+:4];  // DB31[7:4]
                end

                'd11 : 
                begin
                    sclk_dat_fifo.din[0][2][0] = sclk_sdp.din[(0*8)+:4]    ;  // PB8[3:0]
                    sclk_dat_fifo.din[2][2][1] = sclk_sdp.din[((0*8)+4)+:4];  // PB8[7:4]
                    sclk_dat_fifo.din[2][2][0] = sclk_sdp.din[(1*8)+:4]    ;  // PB9[3:0]
                    sclk_dat_fifo.din[0][2][1] = sclk_sdp.din[((1*8)+4)+:4];  // PB9[7:4]
                    sclk_dat_fifo.din[1][3][0] = sclk_sdp.din[(2*8)+:4]    ;  // PB10[3:0]
                    sclk_dat_fifo.din[3][3][1] = sclk_sdp.din[((2*8)+4)+:4];  // PB10[7:4]
                    sclk_dat_fifo.din[3][3][0] = sclk_sdp.din[(3*8)+:4]    ;  // PB11[3:0]
                    sclk_dat_fifo.din[1][3][1] = sclk_sdp.din[((3*8)+4)+:4];  // PB11[7:4]
                end

                default : 
                begin
                    sclk_dat_fifo.din[0][0][0] = sclk_sdp.din[(0*8)+:4]    ;  // HB0[3:0]
                    sclk_dat_fifo.din[2][0][1] = sclk_sdp.din[((0*8)+4)+:4];  // HB0[7:4]
                    sclk_dat_fifo.din[2][0][0] = sclk_sdp.din[(1*8)+:4]    ;  // HB1[3:0]
                    sclk_dat_fifo.din[0][0][1] = sclk_sdp.din[((1*8)+4)+:4];  // HB1[7:4]
                    sclk_dat_fifo.din[0][2][0] = sclk_sdp.din[(2*8)+:4]    ;  // HB2[3:0]
                    sclk_dat_fifo.din[2][2][1] = sclk_sdp.din[((2*8)+4)+:4];  // HB2[7:4]
                    sclk_dat_fifo.din[2][2][0] = sclk_sdp.din[(3*8)+:4]    ;  // HB3[3:0]
                    sclk_dat_fifo.din[0][2][1] = sclk_sdp.din[((3*8)+4)+:4];  // HB3[7:4]
                end
            endcase
        end

        // Four lanes
        else
        begin
            case (sclk_sdp.wr_sel)
                'd1 : 
                begin
                    sclk_dat_fifo.din[0][1][0] = sclk_sdp.din[(0*8)+:4]    ;  // PB0[3:0]
                    sclk_dat_fifo.din[1][1][1] = sclk_sdp.din[((0*8)+4)+:4];  // PB0[7:4]
                    sclk_dat_fifo.din[1][1][0] = sclk_sdp.din[(1*8)+:4]    ;  // PB1[3:0]
                    sclk_dat_fifo.din[0][1][1] = sclk_sdp.din[((1*8)+4)+:4];  // PB1[7:4]
                    sclk_dat_fifo.din[2][1][0] = sclk_sdp.din[(2*8)+:4]    ;  // PB2[3:0]
                    sclk_dat_fifo.din[3][1][1] = sclk_sdp.din[((2*8)+4)+:4];  // PB2[7:4]
                    sclk_dat_fifo.din[3][1][0] = sclk_sdp.din[(3*8)+:4]    ;  // PB3[3:0]
                    sclk_dat_fifo.din[2][1][1] = sclk_sdp.din[((3*8)+4)+:4];  // PB3[7:4]
                end

                'd2 : 
                begin
                    sclk_dat_fifo.din[0][2][0] = sclk_sdp.din[(0*8)+:4]    ;  // DB0[3:0]
                    sclk_dat_fifo.din[1][2][1] = sclk_sdp.din[((0*8)+4)+:4];  // DB0[7:4]
                    sclk_dat_fifo.din[0][3][0] = sclk_sdp.din[(1*8)+:4]    ;  // DB1[3:0]
                    sclk_dat_fifo.din[1][3][1] = sclk_sdp.din[((1*8)+4)+:4];  // DB1[7:4]
                    sclk_dat_fifo.din[0][0][0] = sclk_sdp.din[(2*8)+:4]    ;  // DB2[3:0]
                    sclk_dat_fifo.din[1][0][1] = sclk_sdp.din[((2*8)+4)+:4];  // DB2[7:4]
                    sclk_dat_fifo.din[0][1][0] = sclk_sdp.din[(3*8)+:4]    ;  // DB3[3:0]
                    sclk_dat_fifo.din[1][1][1] = sclk_sdp.din[((3*8)+4)+:4];  // DB3[7:4]
                end

                'd3 :
                begin
                    sclk_dat_fifo.din[1][2][0] = sclk_sdp.din[(0*8)+:4]    ;  // DB4[3:0]
                    sclk_dat_fifo.din[0][2][1] = sclk_sdp.din[((0*8)+4)+:4];  // DB4[7:4]
                    sclk_dat_fifo.din[1][3][0] = sclk_sdp.din[(1*8)+:4]    ;  // DB5[3:0]
                    sclk_dat_fifo.din[0][3][1] = sclk_sdp.din[((1*8)+4)+:4];  // DB5[7:4]
                    sclk_dat_fifo.din[1][0][0] = sclk_sdp.din[(2*8)+:4]    ;  // DB6[3:0]
                    sclk_dat_fifo.din[0][0][1] = sclk_sdp.din[((2*8)+4)+:4];  // DB6[7:4]
                    sclk_dat_fifo.din[1][1][0] = sclk_sdp.din[(3*8)+:4]    ;  // DB7[3:0]
                    sclk_dat_fifo.din[0][1][1] = sclk_sdp.din[((3*8)+4)+:4];  // DB7[7:4]
                end

                'd4 :
                begin
                    sclk_dat_fifo.din[2][2][0] = sclk_sdp.din[(0*8)+:4]    ;  // DB8[3:0]
                    sclk_dat_fifo.din[3][2][1] = sclk_sdp.din[((0*8)+4)+:4];  // DB8[7:4]
                    sclk_dat_fifo.din[2][3][0] = sclk_sdp.din[(1*8)+:4]    ;  // DB9[3:0]
                    sclk_dat_fifo.din[3][3][1] = sclk_sdp.din[((1*8)+4)+:4];  // DB9[7:4]
                    sclk_dat_fifo.din[2][0][0] = sclk_sdp.din[(2*8)+:4]    ;  // DB10[3:0]
                    sclk_dat_fifo.din[3][0][1] = sclk_sdp.din[((2*8)+4)+:4];  // DB10[7:4]
                    sclk_dat_fifo.din[2][1][0] = sclk_sdp.din[(3*8)+:4]    ;  // DB11[3:0]
                    sclk_dat_fifo.din[3][1][1] = sclk_sdp.din[((3*8)+4)+:4];  // DB11[7:4]
                end

                'd5 :
                begin
                    sclk_dat_fifo.din[3][2][0] = sclk_sdp.din[(0*8)+:4]    ;  // DB12[3:0]
                    sclk_dat_fifo.din[2][2][1] = sclk_sdp.din[((0*8)+4)+:4];  // DB12[7:4]
                    sclk_dat_fifo.din[3][3][0] = sclk_sdp.din[(1*8)+:4]    ;  // DB13[3:0]
                    sclk_dat_fifo.din[2][3][1] = sclk_sdp.din[((1*8)+4)+:4];  // DB13[7:4]
                    sclk_dat_fifo.din[3][0][0] = sclk_sdp.din[(2*8)+:4]    ;  // DB14[3:0]
                    sclk_dat_fifo.din[2][0][1] = sclk_sdp.din[((2*8)+4)+:4];  // DB14[7:4]
                    sclk_dat_fifo.din[3][1][0] = sclk_sdp.din[(3*8)+:4]    ;  // DB15[3:0]
                    sclk_dat_fifo.din[2][1][1] = sclk_sdp.din[((3*8)+4)+:4];  // DB15[7:4]
                end

                'd6 : 
                begin
                    sclk_dat_fifo.din[0][2][0] = sclk_sdp.din[(0*8)+:4]    ;  // PB4[3:0]
                    sclk_dat_fifo.din[1][2][1] = sclk_sdp.din[((0*8)+4)+:4];  // PB4[7:4]
                    sclk_dat_fifo.din[1][2][0] = sclk_sdp.din[(1*8)+:4]    ;  // PB5[3:0]
                    sclk_dat_fifo.din[0][2][1] = sclk_sdp.din[((1*8)+4)+:4];  // PB5[7:4]
                    sclk_dat_fifo.din[2][2][0] = sclk_sdp.din[(2*8)+:4]    ;  // PB6[3:0]
                    sclk_dat_fifo.din[3][2][1] = sclk_sdp.din[((2*8)+4)+:4];  // PB6[7:4]
                    sclk_dat_fifo.din[3][2][0] = sclk_sdp.din[(3*8)+:4]    ;  // PB7[3:0]
                    sclk_dat_fifo.din[2][2][1] = sclk_sdp.din[((3*8)+4)+:4];  // PB7[7:4]
                end

                'd7 :
                begin
                    sclk_dat_fifo.din[0][3][0] = sclk_sdp.din[(0*8)+:4]    ;  // DB16[3:0]
                    sclk_dat_fifo.din[1][3][1] = sclk_sdp.din[((0*8)+4)+:4];  // DB16[7:4]
                    sclk_dat_fifo.din[0][0][0] = sclk_sdp.din[(1*8)+:4]    ;  // DB17[3:0]
                    sclk_dat_fifo.din[1][0][1] = sclk_sdp.din[((1*8)+4)+:4];  // DB17[7:4]
                    sclk_dat_fifo.din[0][1][0] = sclk_sdp.din[(2*8)+:4]    ;  // DB18[3:0]
                    sclk_dat_fifo.din[1][1][1] = sclk_sdp.din[((2*8)+4)+:4];  // DB18[7:4]
                    sclk_dat_fifo.din[0][2][0] = sclk_sdp.din[(3*8)+:4]    ;  // DB19[3:0]
                    sclk_dat_fifo.din[1][2][1] = sclk_sdp.din[((3*8)+4)+:4];  // DB19[7:4]
                end

                'd8 :
                begin
                    sclk_dat_fifo.din[1][3][0] = sclk_sdp.din[(0*8)+:4]    ;  // DB20[3:0]
                    sclk_dat_fifo.din[0][3][1] = sclk_sdp.din[((0*8)+4)+:4];  // DB20[7:4]
                    sclk_dat_fifo.din[1][0][0] = sclk_sdp.din[(1*8)+:4]    ;  // DB21[3:0]
                    sclk_dat_fifo.din[0][0][1] = sclk_sdp.din[((1*8)+4)+:4];  // DB21[7:4]
                    sclk_dat_fifo.din[1][1][0] = sclk_sdp.din[(2*8)+:4]    ;  // DB22[3:0]
                    sclk_dat_fifo.din[0][1][1] = sclk_sdp.din[((2*8)+4)+:4];  // DB22[7:4]
                    sclk_dat_fifo.din[1][2][0] = sclk_sdp.din[(3*8)+:4]    ;  // DB23[3:0]
                    sclk_dat_fifo.din[0][2][1] = sclk_sdp.din[((3*8)+4)+:4];  // DB23[7:4]
                end

                'd9 :
                begin
                    sclk_dat_fifo.din[2][3][0] = sclk_sdp.din[(0*8)+:4]    ;  // DB24[3:0]
                    sclk_dat_fifo.din[3][3][1] = sclk_sdp.din[((0*8)+4)+:4];  // DB24[7:4]
                    sclk_dat_fifo.din[2][0][0] = sclk_sdp.din[(1*8)+:4]    ;  // DB25[3:0]
                    sclk_dat_fifo.din[3][0][1] = sclk_sdp.din[((1*8)+4)+:4];  // DB25[7:4]
                    sclk_dat_fifo.din[2][1][0] = sclk_sdp.din[(2*8)+:4]    ;  // DB26[3:0]
                    sclk_dat_fifo.din[3][1][1] = sclk_sdp.din[((2*8)+4)+:4];  // DB26[7:4]
                    sclk_dat_fifo.din[2][2][0] = sclk_sdp.din[(3*8)+:4]    ;  // DB27[3:0]
                    sclk_dat_fifo.din[3][2][1] = sclk_sdp.din[((3*8)+4)+:4];  // DB27[7:4]
                end

                'd10 :
                begin
                    sclk_dat_fifo.din[3][3][0] = sclk_sdp.din[(0*8)+:4]    ;  // DB28[3:0]
                    sclk_dat_fifo.din[2][3][1] = sclk_sdp.din[((0*8)+4)+:4];  // DB28[7:4]
                    sclk_dat_fifo.din[3][0][0] = sclk_sdp.din[(1*8)+:4]    ;  // DB29[3:0]
                    sclk_dat_fifo.din[2][0][1] = sclk_sdp.din[((1*8)+4)+:4];  // DB29[7:4]
                    sclk_dat_fifo.din[3][1][0] = sclk_sdp.din[(2*8)+:4]    ;  // DB30[3:0]
                    sclk_dat_fifo.din[2][1][1] = sclk_sdp.din[((2*8)+4)+:4];  // DB30[7:4]
                    sclk_dat_fifo.din[3][2][0] = sclk_sdp.din[(3*8)+:4]    ;  // DB31[3:0]
                    sclk_dat_fifo.din[2][2][1] = sclk_sdp.din[((3*8)+4)+:4];  // DB31[7:4]
                end

                'd11 : 
                begin
                    sclk_dat_fifo.din[0][3][0] = sclk_sdp.din[(0*8)+:4]    ;  // PB8[3:0]
                    sclk_dat_fifo.din[1][3][1] = sclk_sdp.din[((0*8)+4)+:4];  // PB8[7:4]
                    sclk_dat_fifo.din[1][3][0] = sclk_sdp.din[(1*8)+:4]    ;  // PB9[3:0]
                    sclk_dat_fifo.din[0][3][1] = sclk_sdp.din[((1*8)+4)+:4];  // PB9[7:4]
                    sclk_dat_fifo.din[2][3][0] = sclk_sdp.din[(2*8)+:4]    ;  // PB10[3:0]
                    sclk_dat_fifo.din[3][3][1] = sclk_sdp.din[((2*8)+4)+:4];  // PB10[7:4]
                    sclk_dat_fifo.din[3][3][0] = sclk_sdp.din[(3*8)+:4]    ;  // PB11[3:0]
                    sclk_dat_fifo.din[2][3][1] = sclk_sdp.din[((3*8)+4)+:4];  // PB11[7:4]
                end

                default : 
                begin
                    sclk_dat_fifo.din[0][0][0] = sclk_sdp.din[(0*8)+:4]    ;  // HB0[3:0]
                    sclk_dat_fifo.din[1][0][1] = sclk_sdp.din[((0*8)+4)+:4];  // HB0[7:4]
                    sclk_dat_fifo.din[1][0][0] = sclk_sdp.din[(1*8)+:4]    ;  // HB1[3:0]
                    sclk_dat_fifo.din[0][0][1] = sclk_sdp.din[((1*8)+4)+:4];  // HB1[7:4]
                    sclk_dat_fifo.din[2][0][0] = sclk_sdp.din[(2*8)+:4]    ;  // HB2[3:0]
                    sclk_dat_fifo.din[3][0][1] = sclk_sdp.din[((2*8)+4)+:4];  // HB2[7:4]
                    sclk_dat_fifo.din[3][0][0] = sclk_sdp.din[(3*8)+:4]    ;  // HB3[3:0]
                    sclk_dat_fifo.din[2][0][1] = sclk_sdp.din[((3*8)+4)+:4];  // HB3[7:4]
                end
            endcase
        end
    end


//-----
// Data FIFO
//-----
generate
    // Lanes
    for (i = 0; i < 4; i++)
    begin : gen_fifo_l
        
        // Sublanes
        for (j = 0; j < 4; j++)
        begin : gen_fifo_s
            
            // Nibbles
            for (n = 0; n < 2; n++)
            begin : gen_fifo_n
                
                prt_lib_fifo_dc
                #(
                    .P_VENDOR       (P_VENDOR),                 // Vendor
                    .P_FAMILY       (P_FAMILY),                 // Family
                    .P_MODE         ("burst"),		            // "single" or "burst"
                    .P_RAM_STYLE	("distributed"),	        // "distributed" or "block"
                    .P_OPT 			(P_DAT_FIFO_OPT),		    // In optimized mode the status port are not available. This saves some logic.
                    .P_ADR_WIDTH	(P_DAT_FIFO_ADR),
                    .P_DAT_WIDTH	(P_DAT_FIFO_DAT)
                )
                DAT_FIFO_INST
                (
                    .A_RST_IN       (sclk_sdp.rst),                 // Reset
                    .B_RST_IN       (LNK_RST_IN),
                    .A_CLK_IN       (SDP_CLK_IN),                   // Clock
                    .B_CLK_IN       (LNK_CLK_IN),
                    .A_CKE_IN       (1'b1),                         // Clock enable
                    .B_CKE_IN       (1'b1),

                    // Input (A)
                    .A_CLR_IN       (1'b0),                         // Clear
                    .A_WR_IN        (sclk_dat_fifo.wr[i][j][n]),    // Write
                    .A_DAT_IN       (sclk_dat_fifo.din[i][j][n]),   // Write data

                    // Output (B)
                    .B_CLR_IN       (1'b0),                         // Clear
                    .B_RD_IN        (lclk_dat_fifo.rd[i][j][n]),    // Read
                    .B_DAT_OUT      (lclk_dat_fifo.dout[i][j][n]),  // Read data
                    .B_DE_OUT       (lclk_dat_fifo.de[i][j][n]),    // Data enable

                    // Status (A)
                    .A_WRDS_OUT     (sclk_dat_fifo.wrds[i][j][n]),  // Used words
                    .A_FL_OUT       (sclk_dat_fifo.fl[i][j][n]),    // Full
                    .A_EP_OUT       (sclk_dat_fifo.ep[i][j][n]),    // Empty

                    // Status (B)
                    .B_WRDS_OUT     (),                             // Used words
                    .B_FL_OUT       (),                             // Full
                    .B_EP_OUT       ()                              // Empty
                );
            end
        end
    end
endgenerate

// Length FIFO write
    assign sclk_len_fifo.wr = sclk_sdp.eop_del;

// Length FIFO write data
    assign sclk_len_fifo.din = sclk_sdp.len + 'd1;

//-----
// Length FIFO
//-----
    prt_lib_fifo_dc
    #(
        .P_VENDOR       (P_VENDOR),                 // Vendor
        .P_FAMILY       (P_FAMILY),                 // Family
        .P_MODE         ("single"),		            // "single" or "burst"
        .P_RAM_STYLE	("distributed"),	        // "distributed" or "block"
        .P_OPT 			(P_LEN_FIFO_OPT),		    // In optimized mode the status port are not available. This saves some logic.
        .P_ADR_WIDTH	(P_LEN_FIFO_ADR),
        .P_DAT_WIDTH	(P_LEN_FIFO_DAT)
    )
    LEN_FIFO_INST
    (
        .A_RST_IN       (sclk_sdp.rst),             // Reset
        .B_RST_IN       (LNK_RST_IN),
        .A_CLK_IN       (SDP_CLK_IN),               // Clock
        .B_CLK_IN       (LNK_CLK_IN),
        .A_CKE_IN       (1'b1),                     // Clock enable
        .B_CKE_IN       (1'b1),

        // Input (A)
        .A_CLR_IN       (1'b0),                     // Clear
        .A_WR_IN        (sclk_len_fifo.wr),         // Write
        .A_DAT_IN       (sclk_len_fifo.din),        // Write data

        // Output (B)
        .B_CLR_IN       (1'b0),                     // Clear
        .B_RD_IN        (lclk_len_fifo.rd),         // Read
        .B_DAT_OUT      (lclk_len_fifo.dout),       // Read data
        .B_DE_OUT       (lclk_len_fifo.de),         // Data enable

        // Status (A)
        .A_WRDS_OUT     (),                         // Used words
        .A_FL_OUT       (sclk_len_fifo.fl),         // Full
        .A_EP_OUT       (),                         // Empty

        // Status (B)
        .B_WRDS_OUT     (),                          // Used words
        .B_FL_OUT       (),                          // Full
        .B_EP_OUT       ()                           // Empty
    );

/*
    Link Domain
*/

// Reset flag
    always_ff @ (posedge LNK_RST_IN, posedge LNK_CLK_IN)
    begin
        if (LNK_RST_IN)
            lclk_sdp.rst <= 1;

        else
        begin
            // Clear at start of vertical blanking
            if (lclk_snk.vbf_re)
                lclk_sdp.rst <= 0;
        end
    end

//-----
// Message Slave
//-----
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
        .MSG_SRC_IF     (msg_if_prc),

        // Eggress
        .EGR_IDX_OUT    (lclk_msg.idx),    // Index
        .EGR_FIRST_OUT  (lclk_msg.first),  // First
        .EGR_LAST_OUT   (lclk_msg.last),   // Last
        .EGR_DAT_OUT    (lclk_msg.dat),    // Data
        .EGR_VLD_OUT    (lclk_msg.vld)     // Valid
    );

// Processor packets
    prt_dp_msg_slv_egr
    #(
        .P_ID           (P_MSG_ID_SDP),   // Identifier
        .P_IDX_WIDTH    (P_MSG_IDX),      // Index width
        .P_DAT_WIDTH    (P_MSG_DAT)       // Data width
    )
    MSG_SLV_EGR_PRC_INST
    (
        // Reset and clock
        .RST_IN         (LNK_RST_IN),
        .CLK_IN         (LNK_CLK_IN),

        // MSG sink
        .MSG_SNK_IF     (msg_if_prc),

        // MSG source
        .MSG_SRC_IF     (MSG_SRC_IF),

        // Eggress
        .EGR_IDX_OUT    (lclk_prc.idx),    // Index
        .EGR_FIRST_OUT  (lclk_prc.first),  // First
        .EGR_LAST_OUT   (lclk_prc.last),   // Last
        .EGR_DAT_OUT    (lclk_prc.dat),    // Data
        .EGR_VLD_OUT    (lclk_prc.vld)     // Valid
    );

//-----
// Processor packets (link domain)
//-----
// Drop
// A message is dropped when the FIFO has no room for a long packet.
    assign lclk_prc.drop = lclk_prc.first ? ((lclk_prc.wrds > (P_PRC_FIFO_WRDS - P_PRC_PKT_WRDS)) ? 1 : 0) : lclk_prc.drop_reg;

    always_ff @ (posedge LNK_CLK_IN)
    begin
        if (lclk_prc.vld && lclk_prc.first)
            lclk_prc.drop_reg <= lclk_prc.drop;
    end

// Lower half word
    always_ff @ (posedge LNK_CLK_IN)
    begin
        if (lclk_prc.vld && !lclk_prc.idx[0])
            lclk_prc.lo <= lclk_prc.dat[15:0];
    end

// FIFO write
// The packet word is written with the upper half word.
    assign lclk_prc.wr = lclk_prc.vld && lclk_prc.idx[0] && !lclk_prc.drop;
    assign lclk_prc.din = {lclk_prc.last, lclk_prc.dat[15:0], lclk_prc.lo};

// Packet counter
    always_ff @ (posedge LNK_RST_IN, posedge LNK_CLK_IN)
    begin
        if (LNK_RST_IN)
            lclk_prc.pkt_cnt <= 0;

        else
        begin
            if (lclk_prc.wr && lclk_prc.last)
                lclk_prc.pkt_cnt <= lclk_prc.pkt_cnt + 'd1;
        end
    end

// Config
    always_ff @ (posedge LNK_CLK_IN)
    begin
       lclk_ctl.lanes <= CTL_LANES_IN;
    end

// Sink inputs
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

// Vsync and blanking
    always_ff @ (posedge LNK_CLK_IN)
    begin
        lclk_snk.vs <= LNK_VS_IN;
        lclk_snk.vbf <= LNK_VBF_IN;
    end

//-----
// Vertical blanking edge
//-----
    prt_lib_edge
    LCLK_VBF_EDGE_INST
    (
        .CLK_IN         (LNK_CLK_IN),       // Clock
        .CKE_IN         (1'b1),             // Clock enable
        .A_IN           (lclk_snk.vbf),     // Input
        .RE_OUT         (lclk_snk.vbf_re),  // Rising edge
        .FE_OUT         (lclk_snk.vbf_fe)   // Falling edge
    );

//-----
// Vertical sync edge
//-----
    prt_lib_edge
    LCLK_VS_EDGE_INST
    (
        .CLK_IN         (LNK_CLK_IN),       // Clock
        .CKE_IN         (1'b1),             // Clock enable
        .A_IN           (lclk_snk.vs),      // Input
        .RE_OUT         (lclk_snk.vs_re),   // Rising edge
        .FE_OUT         ()                  // Falling edge
    );

// Vertical start
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Valid message
        if (lclk_msg.vld)
        begin
            // Load upper byte
            if ( ((lclk_ctl.lanes == 'd3) && (lclk_msg.idx == 'd29)) || ((lclk_ctl.lanes == 'd2) && (lclk_msg.idx == 'd15)) || ((lclk_ctl.lanes == 'd1) && (lclk_msg.idx == 'd16)) )
                lclk_snk.vstart[15:8] <= lclk_msg.dat[0+:8];

            // Load lower byte
            else if ( ((lclk_ctl.lanes == 'd3) && (lclk_msg.idx == 'd33)) || ((lclk_ctl.lanes == 'd2) && (lclk_msg.idx == 'd17)) || ((lclk_ctl.lanes == 'd1) && (lclk_msg.idx == 'd17)) )
                lclk_snk.vstart[7:0] <= lclk_msg.dat[0+:8];
        end
    end

// Blanking start
    always_comb
    begin
        if ((lclk_snk.sym[0][P_SPL-1] == TX_LNK_SYM_BS) || (lclk_snk.sym[0][P_SPL-1] == TX_LNK_SYM_SR))
            lclk_snk.bs_det = 1;
        else
            lclk_snk.bs_det = 0;
    end

// Blanking end
    always_comb
    begin
        if (lclk_snk.sym[0][P_SPL-1] == TX_LNK_SYM_BE)
            lclk_snk.be_det = 1;
        else
            lclk_snk.be_det = 0;
    end

// Line counter
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Reset
        if (lclk_sdp.rst)
            lclk_snk.lin_cnt <= 0;
        
        else
        begin
            if (lclk_snk.vs_re)
                lclk_snk.lin_cnt <= 0;
            
            // Increment
            else if (lclk_snk.bs_det)
                lclk_snk.lin_cnt <= lclk_snk.lin_cnt + 'd1;
        end
    end

// Horizontal blanking flag
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Reset
        if (lclk_sdp.rst)
            lclk_sdp.hb <= 0;
        
        else
        begin
            // Clear at the start of the vertical blanking.
            // The blanking start of the last active line sets the flag before the vertical blanking flag is set.
            if (lclk_snk.vbf_re)
                lclk_sdp.hb <= 0;

            // Clear
            else if (!lclk_snk.vbf && lclk_snk.be_det)
                lclk_sdp.hb <= 0;

            // Set
            else if (!lclk_snk.vbf && lclk_snk.bs_det)
                lclk_sdp.hb <= 1;
        end
    end

// Active data flag
// This flag is set from the blanking end to the blanking start.
// No new packet is started in this period.
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Reset
        if (lclk_sdp.rst)
            lclk_sdp.act <= 0;

        else
        begin
            // Clear
            if (lclk_snk.bs_det)
                lclk_sdp.act <= 0;

            // Set
            else if (lclk_snk.be_det)
                lclk_sdp.act <= 1;
        end
    end

// BS hold
// After the BS sequence the VB-ID, Mvid7:0 and Maud7:0 symbols are transported four times over the lanes.
// 4 lanes: 3 symbols, 2 lanes: 6 symbols and 1 lane: 12 symbols per lane.
// No new packet is started during these symbols.
// Once per frame the MSA follows these symbols (prt_dptx_msa, two clock cycles later).
// The hold includes these two clock cycles, then the MSA flag takes over.
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Reset
        if (lclk_sdp.rst)
            lclk_sdp.bs_hold <= 0;

        else
        begin
            // Load
            if (lclk_snk.bs_det)
            begin
                // 4 lanes
                if (lclk_ctl.lanes == 'd3)
                    lclk_sdp.bs_hold <= (P_SPL == 4) ? 'd4 : 'd5;

                // 2 lanes
                else if (lclk_ctl.lanes == 'd2)
                    lclk_sdp.bs_hold <= (P_SPL == 4) ? 'd5 : 'd6;

                // 1 lane
                else
                    lclk_sdp.bs_hold <= (P_SPL == 4) ? 'd6 : 'd7;
            end

            // Decrement
            else if (lclk_sdp.bs_hold != 0)
                lclk_sdp.bs_hold <= lclk_sdp.bs_hold - 'd1;
        end
    end

// MSA
// The MSA starts with SS and ends with SE (lane 0).
// The link input only has the MSA, the packets are inserted by this module.
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Reset
        if (lclk_sdp.rst)
            lclk_sdp.msa <= 0;

        else
        begin
            // Set
            if (lclk_snk.sym[0][0] == TX_LNK_SYM_SS)
                lclk_sdp.msa <= 1;

            // Clear
            else
            begin
                for (int j = 0; j < P_SPL; j++)
                begin
                    if (lclk_snk.sym[0][j] == TX_LNK_SYM_SE)
                        lclk_sdp.msa <= 0;
                end
            end
        end
    end

//-----
// Horizontal blanking edge
//-----
    prt_lib_edge
    LCLK_HB_EDGE_INST
    (
        .CLK_IN         (LNK_CLK_IN),       // Clock
        .CKE_IN         (1'b1),             // Clock enable
        .A_IN           (lclk_sdp.hb),      // Input
        .RE_OUT         (lclk_sdp.hb_re),   // Rising edge
        .FE_OUT         (lclk_sdp.hb_fe)    // Falling edge
    );

// Horizontal blanking interval counter
// This process measures the horizontal blanking interval between two lines.
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Reset
        if (lclk_sdp.rst)
        begin
            lclk_sdp.hbi <= 0;
            lclk_sdp.hbi_cnt <= 0;
        end

        // Load
        // Only when the flag is cleared by the blanking end (and not by the vertical blanking)
        if (lclk_sdp.hb_fe)
        begin
            if (!lclk_snk.vbf)
                lclk_sdp.hbi <= lclk_sdp.hbi_cnt;
            lclk_sdp.hbi_cnt <= 0;
        end

        // Increment
        else if (lclk_sdp.hb)
            lclk_sdp.hbi_cnt <= lclk_sdp.hbi_cnt + 'd1;
    end

// Vertical blanking set flag
// We only measure the first blanking line after the last video line. 
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Reset
        if (lclk_sdp.rst)
            lclk_sdp.vb_set <= 0;
        
        else
        begin
            // 
            if (lclk_sdp.vb)
                lclk_sdp.vb_set <= 0;

            // Set
            else if (lclk_snk.vbf_re)
                lclk_sdp.vb_set <= 1;
        end
    end

// Vertical blanking flag
// We only measure the first blanking line after the last video line. 
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Reset
        if (lclk_sdp.rst)
            lclk_sdp.vb <= 0;
        
        else
        begin
            // Set - Must have highest priority
            if (lclk_sdp.vb_set && lclk_snk.bs_det)
                lclk_sdp.vb <= 1;

            // Clear
            else if (lclk_snk.bs_det)
                lclk_sdp.vb <= 0;
        end
    end

//-----
// Vertical blanking edge
//-----
    prt_lib_edge
    LCLK_VB_EDGE_INST
    (
        .CLK_IN         (LNK_CLK_IN),       // Clock
        .CKE_IN         (1'b1),             // Clock enable
        .A_IN           (lclk_sdp.vb),      // Input
        .RE_OUT         (lclk_sdp.vb_re),   // Rising edge
        .FE_OUT         (lclk_sdp.vb_fe)    // Falling edge
    );

// Vertical blanking interval counter
// This process measures the vertical blanking between two lines
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Reset
        if (lclk_sdp.rst)
        begin
            lclk_sdp.vbi <= 0;
            lclk_sdp.vbi_cnt <= 0;
        end

        // Load 
        else if (lclk_sdp.vb_fe)
        begin
            lclk_sdp.vbi <= lclk_sdp.vbi_cnt;
            lclk_sdp.vbi_cnt <= 0;
        end

        // Increment
        else if (lclk_sdp.vb)
            lclk_sdp.vbi_cnt <= lclk_sdp.vbi_cnt + 'd1;
    end

// Cycles 
// This process counts the remaining cycles in the current blanking period.
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Reset
        if (lclk_sdp.rst)
            lclk_sdp.cyc <= 0;

        // Load
        // Add some extra margin. 
        // When the interval is not measured yet (zero) or too short, there is no room for a packet.
        else if (lclk_sdp.cyc_ld)
        begin
            if (lclk_sdp.cyc_in > 'd16)
                lclk_sdp.cyc <= lclk_sdp.cyc_in - 'd16;
            else
                lclk_sdp.cyc <= 0;
        end
        
        // Decrement
        else if (!lclk_sdp.cyc_end)
            lclk_sdp.cyc <= lclk_sdp.cyc - 'd1;
    end

// Cycles end
    always_comb
    begin
        if (lclk_sdp.cyc == 0)
            lclk_sdp.cyc_end = 1;
        else
            lclk_sdp.cyc_end = 0;
    end

// Packet cycles
// This process shows the number of cycles needs to send one packet.
// The maximum length of a packet is 34 symbols (32 data bytes + SS + SE)
// The table below shows the packet length (in cycles) for each combination.
// Lanes    | 4  | 2  | 1  |
// Cycles   | 14 | 26 | 34 |
// SPL 2    | 7  | 13 | 17 |
// SPL 4    | 4  | 7  | 9  |

generate 
    // 4 symbols
    if (P_SPL == 4)
    begin : gen_pkts_4spl
        always_comb
        begin
            case (lclk_ctl.lanes)
                'd1     : lclk_sdp.pkt_cyc = 'd9;  // Single lane
                'd2     : lclk_sdp.pkt_cyc = 'd7;  // Two lanes
                default : lclk_sdp.pkt_cyc = 'd4;  // Four lanes
            endcase
        end
    end
    
    // 2 symbols per lane
    else
    begin : gen_pkts_2spl
        always_comb
        begin
            case (lclk_ctl.lanes)
                'd1     : lclk_sdp.pkt_cyc = 'd17;  // Single lane
                'd2     : lclk_sdp.pkt_cyc = 'd13;  // Two lanes 
                default : lclk_sdp.pkt_cyc = 'd7;   // Four lanes
            endcase
        end
    end
endgenerate

// Packet cycles total
// This shows the total cycles for a single packet.
// Here the data path latency is added (FIFO)
    assign lclk_sdp.pkt_cyc_tot = lclk_sdp.pkt_cyc + 'd3;

// Packet new
// This flag is set when there is enough room in the blanking to send a packet
// and when there are unread packets in the fifo
    always_comb
    begin
        if (lclk_len_fifo.de && (lclk_sdp.cyc > lclk_sdp.pkt_cyc_tot) && lclk_sdp.rd_cnt_end && lclk_sdp.rd_cnt_end_del[0] && !lclk_sdp.act && (lclk_sdp.bs_hold == 0) && !lclk_sdp.msa && (lclk_snk.sym[0][0] != TX_LNK_SYM_SS))
            lclk_sdp.pkt_new = 1;
        else
            lclk_sdp.pkt_new = 0;
    end

// State machine
    always_ff @ (posedge LNK_RST_IN, posedge LNK_CLK_IN)
    begin
        // Reset
        if (LNK_RST_IN)
            lclk_sdp.sm_cur <= sm_idle;
        
        else
        begin
            // Reset at vsync
            if (lclk_snk.vs_re)
                lclk_sdp.sm_cur <= sm_vb;
            
            else
                lclk_sdp.sm_cur <= lclk_sdp.sm_nxt;
        end
    end

// State machine decoder
    always_comb
    begin
        // Default
        lclk_sdp.cyc_ld = 0;
        lclk_sdp.cyc_in = 0;
        lclk_sdp.rd_cnt_ld = 0;
        lclk_len_fifo.rd = 0;

        case (lclk_sdp.sm_cur)

            // Idle
            sm_idle :
            begin
                lclk_sdp.sm_nxt = sm_idle;
            end

            // Vertical blanking 
            sm_vb :
            begin
                // New line
                if (lclk_snk.bs_det)
                begin
                    // Horizontal line
                    // The line counter counts the blanking starts after the vsync.
                    // The next line is the first active line, the blanking has the horizontal blanking length.
                    if ((lclk_snk.lin_cnt + 'd1) == lclk_snk.vstart)
                    begin
                        lclk_sdp.cyc_ld = 1;
                        lclk_sdp.cyc_in = lclk_sdp.hbi;
                        lclk_sdp.sm_nxt = sm_hb;
                    end

                    else
                    begin
                        lclk_sdp.cyc_ld = 1;
                        lclk_sdp.cyc_in = lclk_sdp.vbi;
                        lclk_sdp.sm_nxt = sm_vb;
                    end
                end

                else
                begin
                    // Can we send out a new packet?
                    if (lclk_sdp.pkt_new)
                    begin
                        lclk_sdp.rd_cnt_ld = 1;
                        lclk_len_fifo.rd = 1;
                    end

                    lclk_sdp.sm_nxt = sm_vb;
                end
            end

            // Horizontal blanking
            sm_hb :
            begin
                // Vertical front porch
                // The vertical blanking flag is still set during the blanking before the first active line,
                // therefore the rising edge is used.
                if (lclk_snk.vbf_re)
                    lclk_sdp.sm_nxt = sm_vb;
                
                // Start horizontal blanking
                else if (lclk_sdp.hb_re)
                begin
                    lclk_sdp.cyc_ld = 1;
                    lclk_sdp.cyc_in = lclk_sdp.hbi;
                    lclk_sdp.sm_nxt = sm_hb;
                end

                else
                begin
                    // Can we send out a new packet?
                    if (lclk_sdp.pkt_new)
                    begin
                        lclk_sdp.rd_cnt_ld = 1;
                        lclk_len_fifo.rd = 1;
                    end

                    lclk_sdp.sm_nxt = sm_hb;
                end
            end

            default : 
            begin
                lclk_sdp.sm_nxt = sm_idle;
            end
        endcase
    end

// Read counter in
generate
    // 4 symbols
    if (P_SPL == 4)
    begin : gen_rd_cnt_in_4spl
        always_comb
        begin
            case (lclk_ctl.lanes)
                'd1     : lclk_sdp.rd_cnt_in = {1'h0, lclk_len_fifo.dout[0+:4]};              // 1 lane
                'd2     : lclk_sdp.rd_cnt_in = ({1'h0, lclk_len_fifo.dout[0+:4]} + 'd1) >> 1;  // 2 lanes - divide by 2 (rounded up)
                default : lclk_sdp.rd_cnt_in = ({1'h0, lclk_len_fifo.dout[0+:4]} + 'd3) >> 2;  // 4 lanes - divide by 4 (rounded up)
            endcase
        end

        // Symbols in the last read cycle
        // 2 lanes: odd length - 2 symbols, 4 lanes: length modulo 4
        always_comb
        begin
            case (lclk_ctl.lanes)
                'd1     : lclk_sdp.rd_rem_in = 0;                                       // 1 lane
                'd2     : lclk_sdp.rd_rem_in = (lclk_len_fifo.dout[0]) ? 'd2 : 'd0;    // 2 lanes
                default : lclk_sdp.rd_rem_in = lclk_len_fifo.dout[0+:2];                // 4 lanes
            endcase
        end
    end

    // 2 symbols
    else
    begin : gen_rd_cnt_in_2spl
        always_comb
        begin
            case (lclk_ctl.lanes)
                'd1     : lclk_sdp.rd_cnt_in = {lclk_len_fifo.dout[0+:4], 1'b0};              // 1 lane - multiply by 2
                'd2     : lclk_sdp.rd_cnt_in = {1'h0, lclk_len_fifo.dout[0+:4]};              // 2 lanes 
                default : lclk_sdp.rd_cnt_in = ({1'h0, lclk_len_fifo.dout[0+:4]} + 'd1) >> 1;  // 4 lanes - divide by 2 (rounded up)
            endcase
        end

        // Symbols in the last read cycle
        // 4 lanes: odd length - 1 symbol
        always_comb
        begin
            case (lclk_ctl.lanes)
                'd1     : lclk_sdp.rd_rem_in = 0;                                       // 1 lane
                'd2     : lclk_sdp.rd_rem_in = 0;                                       // 2 lanes
                default : lclk_sdp.rd_rem_in = (lclk_len_fifo.dout[0]) ? 'd1 : 'd0;    // 4 lanes
            endcase
        end
    end
endgenerate

// Read counter
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Reset
        if (lclk_sdp.rst)
            lclk_sdp.rd_cnt <= 0;
        
        else
        begin
            // Load
            if (lclk_sdp.rd_cnt_ld)
                lclk_sdp.rd_cnt <= lclk_sdp.rd_cnt_in;

            // Decrement
            else if (!lclk_sdp.rd_cnt_end)
                lclk_sdp.rd_cnt <= lclk_sdp.rd_cnt - 'd1;
        end
    end

// Read counter end
    always_comb
    begin
        if (lclk_sdp.rd_cnt == 0)
            lclk_sdp.rd_cnt_end = 1;
        else
            lclk_sdp.rd_cnt_end = 0;
    end

// Read counter end delayed
    always_ff @ (posedge LNK_CLK_IN)
    begin
        lclk_sdp.rd_cnt_end_del <= {lclk_sdp.rd_cnt_end_del[0+:$high(lclk_sdp.rd_cnt_end_del)], lclk_sdp.rd_cnt_end};
    end

// Read remainder
// Number of symbols in the last read cycle of the packet (0 - all symbols)
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Reset
        if (lclk_sdp.rst)
            lclk_sdp.rd_rem <= 0;

        // Load
        else if (lclk_sdp.rd_cnt_ld)
            lclk_sdp.rd_rem <= lclk_sdp.rd_rem_in;
    end

// Read last
    assign lclk_sdp.rd_last = (lclk_sdp.rd_cnt == 'd1) ? 1 : 0;

// Remainder delayed
// The packet ends within the last cycle. 
// Index 1 is aligned with the SDP data, index 2 with the SE insert.
    always_ff @ (posedge LNK_CLK_IN)
    begin
        for (int i = 0; i < $size(lclk_sdp.rem_del); i++)
        begin
            if (i == 0)
                lclk_sdp.rem_del[i] <= (lclk_sdp.rd_last) ? lclk_sdp.rd_rem : 0;
            else
                lclk_sdp.rem_del[i] <= lclk_sdp.rem_del[i-1];
        end
    end

// Read select last
generate
    if (P_SPL == 4)
    begin : gen_rd_sel_last_4spl
        always_comb
        begin
            case (lclk_ctl.lanes)
                'd1 : lclk_sdp.rd_sel_last = 'd3;       // 1 lane
                'd2 : lclk_sdp.rd_sel_last = 'd1;       // 2 lanes
                default : lclk_sdp.rd_sel_last = 'd0;   // 4 lanes
            endcase
        end
    end

    else
    begin : gen_rd_sel_last_2spl
        always_comb
        begin
            case (lclk_ctl.lanes)
                'd1 : lclk_sdp.rd_sel_last = 'd7;       // 1 lane
                'd2 : lclk_sdp.rd_sel_last = 'd3;       // 2 lanes
                default : lclk_sdp.rd_sel_last = 'd1;   // 4 lanes
            endcase
        end
    end
endgenerate

// Read select
// This process selects the FIFO read
    always_ff @ (posedge LNK_CLK_IN)
    begin
        // Clear
        if (lclk_sdp.rd_cnt_end || (lclk_sdp.rd_sel == lclk_sdp.rd_sel_last))
            lclk_sdp.rd_sel <= 0;
        
        // Increment
        else
            lclk_sdp.rd_sel <= lclk_sdp.rd_sel + 'd1;
    end

// Data select
// This process selects the FIFO outptu data to be routed to the SDP data.
    always_ff @ (posedge LNK_CLK_IN)
    begin
        for (int i = 0; i < $size(lclk_sdp.dat_sel); i++)
        begin
            if (i == 0)
                lclk_sdp.dat_sel[i] <= lclk_sdp.rd_sel;
            else
                lclk_sdp.dat_sel[i] <= lclk_sdp.dat_sel[i-1];
        end
    end


//-----
// SDP symbol SS
// At the falling edge of the first read counter end delayed, just before the data starts, insert the SS symbol.
//-----
    prt_lib_edge
    LCLK_SS_INS_INST
    (
        .CLK_IN         (LNK_CLK_IN),                   // Clock
        .CKE_IN         (1'b1),                         // Clock enable
        .A_IN           (lclk_sdp.rd_cnt_end_del[0]),   // Input
        .RE_OUT         (),                             // Rising edge
        .FE_OUT         (lclk_sdp.ss_ins)               // Falling edge
    );


//-----
// SDP symbol SE
// At the rising edge of the last read counter end delayed, after the data ends, insert the SE symbol.
//-----
    prt_lib_edge
    LCLK_SE_INS_INST
    (
        .CLK_IN         (LNK_CLK_IN),                   // Clock
        .CKE_IN         (1'b1),                         // Clock enable
        .A_IN           (lclk_sdp.rd_cnt_end_del[1]),   // Input
        .RE_OUT         (lclk_sdp.se_edge),             // Rising edge
        .FE_OUT         ()                              // Falling edge
    );

// When the packet ends within the last cycle, the SE symbol is inserted in that cycle
    assign lclk_sdp.se_ins = lclk_sdp.se_edge && (lclk_sdp.rem_del[2] == 0);


// FIFO read
generate
    if (P_SPL == 4)
    begin : gen_fifo_rd_4spl
        always_comb
        begin
            // Default
            lclk_dat_fifo.rd = '{default: '0};

            if (!lclk_sdp.rd_cnt_end)
            begin
                // 1 lane
                if (lclk_ctl.lanes == 'd1)
                begin
                    case (lclk_sdp.rd_sel)
                        'd1 : 
                        begin
                            lclk_dat_fifo.rd[1][0][0] = 1;
                            lclk_dat_fifo.rd[1][0][1] = 1;
                            lclk_dat_fifo.rd[1][1][0] = 1;
                            lclk_dat_fifo.rd[1][1][1] = 1;
                            lclk_dat_fifo.rd[1][2][0] = 1;
                            lclk_dat_fifo.rd[1][2][1] = 1;
                            lclk_dat_fifo.rd[1][3][0] = 1;
                            lclk_dat_fifo.rd[1][3][1] = 1;
                        end

                        'd2 : 
                        begin
                            lclk_dat_fifo.rd[2][0][0] = 1;
                            lclk_dat_fifo.rd[2][0][1] = 1;
                            lclk_dat_fifo.rd[2][1][0] = 1;
                            lclk_dat_fifo.rd[2][1][1] = 1;
                            lclk_dat_fifo.rd[2][2][0] = 1;
                            lclk_dat_fifo.rd[2][2][1] = 1;
                            lclk_dat_fifo.rd[2][3][0] = 1;
                            lclk_dat_fifo.rd[2][3][1] = 1;
                        end

                        'd3 : 
                        begin
                            lclk_dat_fifo.rd[3][0][0] = 1;
                            lclk_dat_fifo.rd[3][0][1] = 1;
                            lclk_dat_fifo.rd[3][1][0] = 1;
                            lclk_dat_fifo.rd[3][1][1] = 1;
                            lclk_dat_fifo.rd[3][2][0] = 1;
                            lclk_dat_fifo.rd[3][2][1] = 1;
                            lclk_dat_fifo.rd[3][3][0] = 1;
                            lclk_dat_fifo.rd[3][3][1] = 1;
                        end

                        default : 
                        begin
                            lclk_dat_fifo.rd[0][0][0] = 1;
                            lclk_dat_fifo.rd[0][0][1] = 1;
                            lclk_dat_fifo.rd[0][1][0] = 1;
                            lclk_dat_fifo.rd[0][1][1] = 1;
                            lclk_dat_fifo.rd[0][2][0] = 1;
                            lclk_dat_fifo.rd[0][2][1] = 1;
                            lclk_dat_fifo.rd[0][3][0] = 1;
                            lclk_dat_fifo.rd[0][3][1] = 1;
                        end
                    endcase
                end

                // 2 lanes
                // The FIFO groups 0 and 1 hold the data of lane 0, the groups 2 and 3 the data of lane 1
                else if (lclk_ctl.lanes == 'd2)
                begin
                    case (lclk_sdp.rd_sel)
                        'd1 : 
                        begin
                            lclk_dat_fifo.rd[1][0][0] = 1;
                            lclk_dat_fifo.rd[1][0][1] = 1;
                            lclk_dat_fifo.rd[1][1][0] = 1;
                            lclk_dat_fifo.rd[1][1][1] = 1;
                            lclk_dat_fifo.rd[1][2][0] = 1;
                            lclk_dat_fifo.rd[1][2][1] = 1;
                            lclk_dat_fifo.rd[1][3][0] = 1;
                            lclk_dat_fifo.rd[1][3][1] = 1;

                            lclk_dat_fifo.rd[3][0][0] = 1;
                            lclk_dat_fifo.rd[3][0][1] = 1;
                            lclk_dat_fifo.rd[3][1][0] = 1;
                            lclk_dat_fifo.rd[3][1][1] = 1;
                            lclk_dat_fifo.rd[3][2][0] = 1;
                            lclk_dat_fifo.rd[3][2][1] = 1;
                            lclk_dat_fifo.rd[3][3][0] = 1;
                            lclk_dat_fifo.rd[3][3][1] = 1;
                        end

                        default : 
                        begin
                            lclk_dat_fifo.rd[0][0][0] = 1;
                            lclk_dat_fifo.rd[0][0][1] = 1;
                            lclk_dat_fifo.rd[0][1][0] = 1;
                            lclk_dat_fifo.rd[0][1][1] = 1;
                            lclk_dat_fifo.rd[0][2][0] = 1;
                            lclk_dat_fifo.rd[0][2][1] = 1;
                            lclk_dat_fifo.rd[0][3][0] = 1;
                            lclk_dat_fifo.rd[0][3][1] = 1;

                            lclk_dat_fifo.rd[2][0][0] = 1;
                            lclk_dat_fifo.rd[2][0][1] = 1;
                            lclk_dat_fifo.rd[2][1][0] = 1;
                            lclk_dat_fifo.rd[2][1][1] = 1;
                            lclk_dat_fifo.rd[2][2][0] = 1;
                            lclk_dat_fifo.rd[2][2][1] = 1;
                            lclk_dat_fifo.rd[2][3][0] = 1;
                            lclk_dat_fifo.rd[2][3][1] = 1;
                        end
                    endcase
                end

                // 4 lanes
                else
                    lclk_dat_fifo.rd = '{default: '1};
            end

            // Last read cycle of a packet that ends within the cycle
            // Only the symbols of the packet are read.
            if (lclk_sdp.rd_last && (lclk_sdp.rd_rem != 0))
            begin
                for (int i = 0; i < 4; i++)
                begin
                    for (int j = 0; j < 4; j++)
                    begin
                        if (j >= lclk_sdp.rd_rem)
                            lclk_dat_fifo.rd[i][j] = 0;
                    end
                end
            end
        end
    end

    // 2 symbols
    else
    begin : gen_fifo_rd_2spl
        always_comb
        begin
            // Default
            lclk_dat_fifo.rd = '{default: '0};

            if (!lclk_sdp.rd_cnt_end)
            begin
                // 1 lane
                if (lclk_ctl.lanes == 'd1)
                begin
                    case (lclk_sdp.rd_sel)

                        'd1 : 
                        begin
                            lclk_dat_fifo.rd[0][2][0] = 1;
                            lclk_dat_fifo.rd[0][2][1] = 1;
                            lclk_dat_fifo.rd[0][3][0] = 1;
                            lclk_dat_fifo.rd[0][3][1] = 1;
                        end

                        'd2 : 
                        begin
                            lclk_dat_fifo.rd[1][0][0] = 1;
                            lclk_dat_fifo.rd[1][0][1] = 1;
                            lclk_dat_fifo.rd[1][1][0] = 1;
                            lclk_dat_fifo.rd[1][1][1] = 1;
                        end

                        'd3 : 
                        begin                           
                            lclk_dat_fifo.rd[1][2][0] = 1;
                            lclk_dat_fifo.rd[1][2][1] = 1;
                            lclk_dat_fifo.rd[1][3][0] = 1;
                            lclk_dat_fifo.rd[1][3][1] = 1;
                        end

                        'd4 : 
                        begin
                            lclk_dat_fifo.rd[2][0][0] = 1;
                            lclk_dat_fifo.rd[2][0][1] = 1;
                            lclk_dat_fifo.rd[2][1][0] = 1;
                            lclk_dat_fifo.rd[2][1][1] = 1;
                        end

                        'd5 : 
                        begin                           
                            lclk_dat_fifo.rd[2][2][0] = 1;
                            lclk_dat_fifo.rd[2][2][1] = 1;
                            lclk_dat_fifo.rd[2][3][0] = 1;
                            lclk_dat_fifo.rd[2][3][1] = 1;
                        end

                        'd6 : 
                        begin
                            lclk_dat_fifo.rd[3][0][0] = 1;
                            lclk_dat_fifo.rd[3][0][1] = 1;
                            lclk_dat_fifo.rd[3][1][0] = 1;
                            lclk_dat_fifo.rd[3][1][1] = 1;
                        end

                        'd7 : 
                        begin                           
                            lclk_dat_fifo.rd[3][2][0] = 1;
                            lclk_dat_fifo.rd[3][2][1] = 1;
                            lclk_dat_fifo.rd[3][3][0] = 1;
                            lclk_dat_fifo.rd[3][3][1] = 1;
                        end

                        default : 
                        begin
                            lclk_dat_fifo.rd[0][0][0] = 1;
                            lclk_dat_fifo.rd[0][0][1] = 1;
                            lclk_dat_fifo.rd[0][1][0] = 1;
                            lclk_dat_fifo.rd[0][1][1] = 1;
                        end
                    endcase
                end

                // 2 lanes
                else if (lclk_ctl.lanes == 'd2)
                begin
                    case (lclk_sdp.rd_sel)
                        'd1 : 
                        begin
                            lclk_dat_fifo.rd[0][2][0] = 1;
                            lclk_dat_fifo.rd[0][2][1] = 1;
                            lclk_dat_fifo.rd[0][3][0] = 1;
                            lclk_dat_fifo.rd[0][3][1] = 1;

                            lclk_dat_fifo.rd[2][2][0] = 1;
                            lclk_dat_fifo.rd[2][2][1] = 1;
                            lclk_dat_fifo.rd[2][3][0] = 1;
                            lclk_dat_fifo.rd[2][3][1] = 1;
                        end

                        'd2 : 
                        begin
                            lclk_dat_fifo.rd[1][0][0] = 1;
                            lclk_dat_fifo.rd[1][0][1] = 1;
                            lclk_dat_fifo.rd[1][1][0] = 1;
                            lclk_dat_fifo.rd[1][1][1] = 1;

                            lclk_dat_fifo.rd[3][0][0] = 1;
                            lclk_dat_fifo.rd[3][0][1] = 1;
                            lclk_dat_fifo.rd[3][1][0] = 1;
                            lclk_dat_fifo.rd[3][1][1] = 1;
                        end

                        'd3 : 
                        begin
                            lclk_dat_fifo.rd[1][2][0] = 1;
                            lclk_dat_fifo.rd[1][2][1] = 1;
                            lclk_dat_fifo.rd[1][3][0] = 1;
                            lclk_dat_fifo.rd[1][3][1] = 1;

                            lclk_dat_fifo.rd[3][2][0] = 1;
                            lclk_dat_fifo.rd[3][2][1] = 1;
                            lclk_dat_fifo.rd[3][3][0] = 1;
                            lclk_dat_fifo.rd[3][3][1] = 1;
                        end

                        default : 
                        begin
                            lclk_dat_fifo.rd[0][0][0] = 1;
                            lclk_dat_fifo.rd[0][0][1] = 1;
                            lclk_dat_fifo.rd[0][1][0] = 1;
                            lclk_dat_fifo.rd[0][1][1] = 1;

                            lclk_dat_fifo.rd[2][0][0] = 1;
                            lclk_dat_fifo.rd[2][0][1] = 1;
                            lclk_dat_fifo.rd[2][1][0] = 1;
                            lclk_dat_fifo.rd[2][1][1] = 1;
                        end
                    endcase
                end

                // 4 lanes
                else
                begin
                    if (lclk_sdp.rd_sel == 'd1)
                    begin
                        lclk_dat_fifo.rd[0][2][0] = 1;
                        lclk_dat_fifo.rd[0][2][1] = 1;
                        lclk_dat_fifo.rd[0][3][0] = 1;
                        lclk_dat_fifo.rd[0][3][1] = 1;
                        lclk_dat_fifo.rd[1][2][0] = 1;
                        lclk_dat_fifo.rd[1][2][1] = 1;
                        lclk_dat_fifo.rd[1][3][0] = 1;
                        lclk_dat_fifo.rd[1][3][1] = 1;
                        
                        lclk_dat_fifo.rd[2][2][0] = 1;
                        lclk_dat_fifo.rd[2][2][1] = 1;
                        lclk_dat_fifo.rd[2][3][0] = 1;
                        lclk_dat_fifo.rd[2][3][1] = 1;
                        lclk_dat_fifo.rd[3][2][0] = 1;
                        lclk_dat_fifo.rd[3][2][1] = 1;
                        lclk_dat_fifo.rd[3][3][0] = 1;
                        lclk_dat_fifo.rd[3][3][1] = 1;                    
                    end
                    
                    else
                    begin
                        lclk_dat_fifo.rd[0][0][0] = 1;
                        lclk_dat_fifo.rd[0][0][1] = 1;
                        lclk_dat_fifo.rd[0][1][0] = 1;
                        lclk_dat_fifo.rd[0][1][1] = 1;
                        lclk_dat_fifo.rd[1][0][0] = 1;
                        lclk_dat_fifo.rd[1][0][1] = 1;
                        lclk_dat_fifo.rd[1][1][0] = 1;
                        lclk_dat_fifo.rd[1][1][1] = 1;
                        
                        lclk_dat_fifo.rd[2][0][0] = 1;
                        lclk_dat_fifo.rd[2][0][1] = 1;
                        lclk_dat_fifo.rd[2][1][0] = 1;
                        lclk_dat_fifo.rd[2][1][1] = 1;
                        lclk_dat_fifo.rd[3][0][0] = 1;
                        lclk_dat_fifo.rd[3][0][1] = 1;
                        lclk_dat_fifo.rd[3][1][0] = 1;
                        lclk_dat_fifo.rd[3][1][1] = 1;
                    end
                end
            end

            // Last read cycle of a packet that ends within the cycle
            // Only the first symbol is read (4 lanes, odd length).
            // The sublanes 1 and 3 hold the second symbol of a cycle.
            if (lclk_sdp.rd_last && (lclk_sdp.rd_rem != 0))
            begin
                for (int i = 0; i < 4; i++)
                begin
                    lclk_dat_fifo.rd[i][1] = 0;
                    lclk_dat_fifo.rd[i][3] = 0;
                end
            end
        end
    end
endgenerate

// SDP data
generate
    if (P_SPL == 4)
    begin : gen_sdp_dat_4spl
        always_comb
        begin
            // Default
            lclk_sdp.dat = '{default: '0};

            if (!lclk_sdp.rd_cnt_end_del[$high(lclk_sdp.rd_cnt_end_del)])
            begin
                // 1 lane
                if (lclk_ctl.lanes == 'd1)
                begin
                    case (lclk_sdp.dat_sel[$high(lclk_sdp.dat_sel)])
                        'd1 : 
                        begin
                            lclk_sdp.dat[0][0][0+:4] = lclk_dat_fifo.dout[1][0][0];
                            lclk_sdp.dat[0][0][4+:4] = lclk_dat_fifo.dout[1][0][1];
                            lclk_sdp.dat[0][1][0+:4] = lclk_dat_fifo.dout[1][1][0];
                            lclk_sdp.dat[0][1][4+:4] = lclk_dat_fifo.dout[1][1][1];
                            lclk_sdp.dat[0][2][0+:4] = lclk_dat_fifo.dout[1][2][0];
                            lclk_sdp.dat[0][2][4+:4] = lclk_dat_fifo.dout[1][2][1];
                            lclk_sdp.dat[0][3][0+:4] = lclk_dat_fifo.dout[1][3][0];
                            lclk_sdp.dat[0][3][4+:4] = lclk_dat_fifo.dout[1][3][1];
                        end

                        'd2 : 
                        begin
                            lclk_sdp.dat[0][0][0+:4] = lclk_dat_fifo.dout[2][0][0];
                            lclk_sdp.dat[0][0][4+:4] = lclk_dat_fifo.dout[2][0][1];
                            lclk_sdp.dat[0][1][0+:4] = lclk_dat_fifo.dout[2][1][0];
                            lclk_sdp.dat[0][1][4+:4] = lclk_dat_fifo.dout[2][1][1];
                            lclk_sdp.dat[0][2][0+:4] = lclk_dat_fifo.dout[2][2][0];
                            lclk_sdp.dat[0][2][4+:4] = lclk_dat_fifo.dout[2][2][1];
                            lclk_sdp.dat[0][3][0+:4] = lclk_dat_fifo.dout[2][3][0];
                            lclk_sdp.dat[0][3][4+:4] = lclk_dat_fifo.dout[2][3][1];
                        end

                        'd3 : 
                        begin
                            lclk_sdp.dat[0][0][0+:4] = lclk_dat_fifo.dout[3][0][0];
                            lclk_sdp.dat[0][0][4+:4] = lclk_dat_fifo.dout[3][0][1];
                            lclk_sdp.dat[0][1][0+:4] = lclk_dat_fifo.dout[3][1][0];
                            lclk_sdp.dat[0][1][4+:4] = lclk_dat_fifo.dout[3][1][1];
                            lclk_sdp.dat[0][2][0+:4] = lclk_dat_fifo.dout[3][2][0];
                            lclk_sdp.dat[0][2][4+:4] = lclk_dat_fifo.dout[3][2][1];
                            lclk_sdp.dat[0][3][0+:4] = lclk_dat_fifo.dout[3][3][0];
                            lclk_sdp.dat[0][3][4+:4] = lclk_dat_fifo.dout[3][3][1];
                        end

                        default : 
                        begin
                            lclk_sdp.dat[0][0][0+:4] = lclk_dat_fifo.dout[0][0][0];
                            lclk_sdp.dat[0][0][4+:4] = lclk_dat_fifo.dout[0][0][1];
                            lclk_sdp.dat[0][1][0+:4] = lclk_dat_fifo.dout[0][1][0];
                            lclk_sdp.dat[0][1][4+:4] = lclk_dat_fifo.dout[0][1][1];
                            lclk_sdp.dat[0][2][0+:4] = lclk_dat_fifo.dout[0][2][0];
                            lclk_sdp.dat[0][2][4+:4] = lclk_dat_fifo.dout[0][2][1];
                            lclk_sdp.dat[0][3][0+:4] = lclk_dat_fifo.dout[0][3][0];
                            lclk_sdp.dat[0][3][4+:4] = lclk_dat_fifo.dout[0][3][1];
                        end
                    endcase
                end

                // 2 lanes
                else if (lclk_ctl.lanes == 'd2)
                begin
                    case (lclk_sdp.dat_sel[$high(lclk_sdp.dat_sel)])
                        'd1 : 
                        begin
                            lclk_sdp.dat[0][0][0+:4] = lclk_dat_fifo.dout[1][0][0];
                            lclk_sdp.dat[0][0][4+:4] = lclk_dat_fifo.dout[1][0][1];
                            lclk_sdp.dat[0][1][0+:4] = lclk_dat_fifo.dout[1][1][0];
                            lclk_sdp.dat[0][1][4+:4] = lclk_dat_fifo.dout[1][1][1];
                            lclk_sdp.dat[0][2][0+:4] = lclk_dat_fifo.dout[1][2][0];
                            lclk_sdp.dat[0][2][4+:4] = lclk_dat_fifo.dout[1][2][1];
                            lclk_sdp.dat[0][3][0+:4] = lclk_dat_fifo.dout[1][3][0];
                            lclk_sdp.dat[0][3][4+:4] = lclk_dat_fifo.dout[1][3][1];

                            lclk_sdp.dat[1][0][0+:4] = lclk_dat_fifo.dout[3][0][0];
                            lclk_sdp.dat[1][0][4+:4] = lclk_dat_fifo.dout[3][0][1];
                            lclk_sdp.dat[1][1][0+:4] = lclk_dat_fifo.dout[3][1][0];
                            lclk_sdp.dat[1][1][4+:4] = lclk_dat_fifo.dout[3][1][1];
                            lclk_sdp.dat[1][2][0+:4] = lclk_dat_fifo.dout[3][2][0];
                            lclk_sdp.dat[1][2][4+:4] = lclk_dat_fifo.dout[3][2][1];
                            lclk_sdp.dat[1][3][0+:4] = lclk_dat_fifo.dout[3][3][0];
                            lclk_sdp.dat[1][3][4+:4] = lclk_dat_fifo.dout[3][3][1];
                        end

                        default : 
                        begin
                            lclk_sdp.dat[0][0][0+:4] = lclk_dat_fifo.dout[0][0][0];
                            lclk_sdp.dat[0][0][4+:4] = lclk_dat_fifo.dout[0][0][1];
                            lclk_sdp.dat[0][1][0+:4] = lclk_dat_fifo.dout[0][1][0];
                            lclk_sdp.dat[0][1][4+:4] = lclk_dat_fifo.dout[0][1][1];
                            lclk_sdp.dat[0][2][0+:4] = lclk_dat_fifo.dout[0][2][0];
                            lclk_sdp.dat[0][2][4+:4] = lclk_dat_fifo.dout[0][2][1];
                            lclk_sdp.dat[0][3][0+:4] = lclk_dat_fifo.dout[0][3][0];
                            lclk_sdp.dat[0][3][4+:4] = lclk_dat_fifo.dout[0][3][1];

                            lclk_sdp.dat[1][0][0+:4] = lclk_dat_fifo.dout[2][0][0];
                            lclk_sdp.dat[1][0][4+:4] = lclk_dat_fifo.dout[2][0][1];
                            lclk_sdp.dat[1][1][0+:4] = lclk_dat_fifo.dout[2][1][0];
                            lclk_sdp.dat[1][1][4+:4] = lclk_dat_fifo.dout[2][1][1];
                            lclk_sdp.dat[1][2][0+:4] = lclk_dat_fifo.dout[2][2][0];
                            lclk_sdp.dat[1][2][4+:4] = lclk_dat_fifo.dout[2][2][1];
                            lclk_sdp.dat[1][3][0+:4] = lclk_dat_fifo.dout[2][3][0];
                            lclk_sdp.dat[1][3][4+:4] = lclk_dat_fifo.dout[2][3][1];
                        end
                    endcase
                end

                // 4 lanes
                else
                begin
                    for (int i = 0; i < P_LANES; i++)
                    begin 
                        for (int j = 0; j < P_SPL; j++)
                        begin
                            lclk_sdp.dat[i][j][0+:4] = lclk_dat_fifo.dout[i][j][0]; 
                            lclk_sdp.dat[i][j][4+:4] = lclk_dat_fifo.dout[i][j][1]; 
                        end
                    end
                end
            end
        end
    end

    // 2 symbols
    else
    begin : gen_sdp_dat_2spl
        always_comb
        begin
            // Default
            lclk_sdp.dat = '{default: '0};

            if (!lclk_sdp.rd_cnt_end_del[$high(lclk_sdp.rd_cnt_end_del)])
            begin
                // 1 lane
                if (lclk_ctl.lanes == 'd1)
                begin
                    case (lclk_sdp.dat_sel[$high(lclk_sdp.dat_sel)])

                        'd1 : 
                        begin
                            lclk_sdp.dat[0][0][0+:4] = lclk_dat_fifo.dout[0][2][0];
                            lclk_sdp.dat[0][0][4+:4] = lclk_dat_fifo.dout[0][2][1];
                            lclk_sdp.dat[0][1][0+:4] = lclk_dat_fifo.dout[0][3][0];
                            lclk_sdp.dat[0][1][4+:4] = lclk_dat_fifo.dout[0][3][1];
                        end

                        'd2 : 
                        begin
                            lclk_sdp.dat[0][0][0+:4] = lclk_dat_fifo.dout[1][0][0];
                            lclk_sdp.dat[0][0][4+:4] = lclk_dat_fifo.dout[1][0][1];
                            lclk_sdp.dat[0][1][0+:4] = lclk_dat_fifo.dout[1][1][0];
                            lclk_sdp.dat[0][1][4+:4] = lclk_dat_fifo.dout[1][1][1];
                        end

                        'd3 : 
                        begin                           
                            lclk_sdp.dat[0][0][0+:4] = lclk_dat_fifo.dout[1][2][0];
                            lclk_sdp.dat[0][0][4+:4] = lclk_dat_fifo.dout[1][2][1];
                            lclk_sdp.dat[0][1][0+:4] = lclk_dat_fifo.dout[1][3][0];
                            lclk_sdp.dat[0][1][4+:4] = lclk_dat_fifo.dout[1][3][1];
                        end

                        'd4 : 
                        begin
                            lclk_sdp.dat[0][0][0+:4] = lclk_dat_fifo.dout[2][0][0];
                            lclk_sdp.dat[0][0][4+:4] = lclk_dat_fifo.dout[2][0][1];
                            lclk_sdp.dat[0][1][0+:4] = lclk_dat_fifo.dout[2][1][0];
                            lclk_sdp.dat[0][1][4+:4] = lclk_dat_fifo.dout[2][1][1];
                        end

                        'd5 : 
                        begin                           
                            lclk_sdp.dat[0][0][0+:4] = lclk_dat_fifo.dout[2][2][0];
                            lclk_sdp.dat[0][0][4+:4] = lclk_dat_fifo.dout[2][2][1];
                            lclk_sdp.dat[0][1][0+:4] = lclk_dat_fifo.dout[2][3][0];
                            lclk_sdp.dat[0][1][4+:4] = lclk_dat_fifo.dout[2][3][1];
                        end

                        'd6 : 
                        begin
                            lclk_sdp.dat[0][0][0+:4] = lclk_dat_fifo.dout[3][0][0];
                            lclk_sdp.dat[0][0][4+:4] = lclk_dat_fifo.dout[3][0][1];
                            lclk_sdp.dat[0][1][0+:4] = lclk_dat_fifo.dout[3][1][0];
                            lclk_sdp.dat[0][1][4+:4] = lclk_dat_fifo.dout[3][1][1];
                        end

                        'd7 : 
                        begin                           
                            lclk_sdp.dat[0][0][0+:4] = lclk_dat_fifo.dout[3][2][0];
                            lclk_sdp.dat[0][0][4+:4] = lclk_dat_fifo.dout[3][2][1];
                            lclk_sdp.dat[0][1][0+:4] = lclk_dat_fifo.dout[3][3][0];
                            lclk_sdp.dat[0][1][4+:4] = lclk_dat_fifo.dout[3][3][1];
                        end

                        default : 
                        begin
                            lclk_sdp.dat[0][0][0+:4] = lclk_dat_fifo.dout[0][0][0];
                            lclk_sdp.dat[0][0][4+:4] = lclk_dat_fifo.dout[0][0][1];
                            lclk_sdp.dat[0][1][0+:4] = lclk_dat_fifo.dout[0][1][0];
                            lclk_sdp.dat[0][1][4+:4] = lclk_dat_fifo.dout[0][1][1];
                        end
                    endcase
                end

                // 2 lanes
                else if (lclk_ctl.lanes == 'd2)
                begin
                    case (lclk_sdp.dat_sel[$high(lclk_sdp.dat_sel)])
                        'd1 : 
                        begin
                            lclk_sdp.dat[0][0][0+:4] = lclk_dat_fifo.dout[0][2][0];
                            lclk_sdp.dat[0][0][4+:4] = lclk_dat_fifo.dout[0][2][1];
                            lclk_sdp.dat[0][1][0+:4] = lclk_dat_fifo.dout[0][3][0];
                            lclk_sdp.dat[0][1][4+:4] = lclk_dat_fifo.dout[0][3][1];

                            lclk_sdp.dat[1][0][0+:4] = lclk_dat_fifo.dout[2][2][0];
                            lclk_sdp.dat[1][0][4+:4] = lclk_dat_fifo.dout[2][2][1];
                            lclk_sdp.dat[1][1][0+:4] = lclk_dat_fifo.dout[2][3][0];
                            lclk_sdp.dat[1][1][4+:4] = lclk_dat_fifo.dout[2][3][1];
                        end

                        'd2 : 
                        begin
                            lclk_sdp.dat[0][0][0+:4] = lclk_dat_fifo.dout[1][0][0];
                            lclk_sdp.dat[0][0][4+:4] = lclk_dat_fifo.dout[1][0][1];
                            lclk_sdp.dat[0][1][0+:4] = lclk_dat_fifo.dout[1][1][0];
                            lclk_sdp.dat[0][1][4+:4] = lclk_dat_fifo.dout[1][1][1];

                            lclk_sdp.dat[1][0][0+:4] = lclk_dat_fifo.dout[3][0][0];
                            lclk_sdp.dat[1][0][4+:4] = lclk_dat_fifo.dout[3][0][1];
                            lclk_sdp.dat[1][1][0+:4] = lclk_dat_fifo.dout[3][1][0];
                            lclk_sdp.dat[1][1][4+:4] = lclk_dat_fifo.dout[3][1][1];
                        end

                        'd3 : 
                        begin
                            lclk_sdp.dat[0][0][0+:4] = lclk_dat_fifo.dout[1][2][0];
                            lclk_sdp.dat[0][0][4+:4] = lclk_dat_fifo.dout[1][2][1];
                            lclk_sdp.dat[0][1][0+:4] = lclk_dat_fifo.dout[1][3][0];
                            lclk_sdp.dat[0][1][4+:4] = lclk_dat_fifo.dout[1][3][1];

                            lclk_sdp.dat[1][0][0+:4] = lclk_dat_fifo.dout[3][2][0];
                            lclk_sdp.dat[1][0][4+:4] = lclk_dat_fifo.dout[3][2][1];
                            lclk_sdp.dat[1][1][0+:4] = lclk_dat_fifo.dout[3][3][0];
                            lclk_sdp.dat[1][1][4+:4] = lclk_dat_fifo.dout[3][3][1];
                        end

                        default : 
                        begin
                            lclk_sdp.dat[0][0][0+:4] = lclk_dat_fifo.dout[0][0][0];
                            lclk_sdp.dat[0][0][4+:4] = lclk_dat_fifo.dout[0][0][1];
                            lclk_sdp.dat[0][1][0+:4] = lclk_dat_fifo.dout[0][1][0];
                            lclk_sdp.dat[0][1][4+:4] = lclk_dat_fifo.dout[0][1][1];

                            lclk_sdp.dat[1][0][0+:4] = lclk_dat_fifo.dout[2][0][0];
                            lclk_sdp.dat[1][0][4+:4] = lclk_dat_fifo.dout[2][0][1];
                            lclk_sdp.dat[1][1][0+:4] = lclk_dat_fifo.dout[2][1][0];
                            lclk_sdp.dat[1][1][4+:4] = lclk_dat_fifo.dout[2][1][1];
                        end
                    endcase
                end

                // 4 lanes
                else
                begin
                    if (lclk_sdp.dat_sel[$high(lclk_sdp.dat_sel)] == 'd1)
                    begin
                        lclk_sdp.dat[0][0][0+:4] = lclk_dat_fifo.dout[0][2][0];
                        lclk_sdp.dat[0][0][4+:4] = lclk_dat_fifo.dout[0][2][1];
                        lclk_sdp.dat[0][1][0+:4] = lclk_dat_fifo.dout[0][3][0];
                        lclk_sdp.dat[0][1][4+:4] = lclk_dat_fifo.dout[0][3][1];
                        lclk_sdp.dat[1][0][0+:4] = lclk_dat_fifo.dout[1][2][0];
                        lclk_sdp.dat[1][0][4+:4] = lclk_dat_fifo.dout[1][2][1];
                        lclk_sdp.dat[1][1][0+:4] = lclk_dat_fifo.dout[1][3][0];
                        lclk_sdp.dat[1][1][4+:4] = lclk_dat_fifo.dout[1][3][1];
                        
                        lclk_sdp.dat[2][0][0+:4] = lclk_dat_fifo.dout[2][2][0];
                        lclk_sdp.dat[2][0][4+:4] = lclk_dat_fifo.dout[2][2][1];
                        lclk_sdp.dat[2][1][0+:4] = lclk_dat_fifo.dout[2][3][0];
                        lclk_sdp.dat[2][1][4+:4] = lclk_dat_fifo.dout[2][3][1];
                        lclk_sdp.dat[3][0][0+:4] = lclk_dat_fifo.dout[3][2][0];
                        lclk_sdp.dat[3][0][4+:4] = lclk_dat_fifo.dout[3][2][1];
                        lclk_sdp.dat[3][1][0+:4] = lclk_dat_fifo.dout[3][3][0];
                        lclk_sdp.dat[3][1][4+:4] = lclk_dat_fifo.dout[3][3][1];                    
                    end
                    
                    else
                    begin
                        lclk_sdp.dat[0][0][0+:4] = lclk_dat_fifo.dout[0][0][0];
                        lclk_sdp.dat[0][0][4+:4] = lclk_dat_fifo.dout[0][0][1];
                        lclk_sdp.dat[0][1][0+:4] = lclk_dat_fifo.dout[0][1][0];
                        lclk_sdp.dat[0][1][4+:4] = lclk_dat_fifo.dout[0][1][1];
                        lclk_sdp.dat[1][0][0+:4] = lclk_dat_fifo.dout[1][0][0];
                        lclk_sdp.dat[1][0][4+:4] = lclk_dat_fifo.dout[1][0][1];
                        lclk_sdp.dat[1][1][0+:4] = lclk_dat_fifo.dout[1][1][0];
                        lclk_sdp.dat[1][1][4+:4] = lclk_dat_fifo.dout[1][1][1];
                        
                        lclk_sdp.dat[2][0][0+:4] = lclk_dat_fifo.dout[2][0][0];
                        lclk_sdp.dat[2][0][4+:4] = lclk_dat_fifo.dout[2][0][1];
                        lclk_sdp.dat[2][1][0+:4] = lclk_dat_fifo.dout[2][1][0];
                        lclk_sdp.dat[2][1][4+:4] = lclk_dat_fifo.dout[2][1][1];
                        lclk_sdp.dat[3][0][0+:4] = lclk_dat_fifo.dout[3][0][0];
                        lclk_sdp.dat[3][0][4+:4] = lclk_dat_fifo.dout[3][0][1];
                        lclk_sdp.dat[3][1][0+:4] = lclk_dat_fifo.dout[3][1][0];
                        lclk_sdp.dat[3][1][4+:4] = lclk_dat_fifo.dout[3][1][1];
                    end
                end
            end
        end
    end
endgenerate

// SDP symbols
    always_comb
    begin
        // Default
        for (int i = 0; i < P_LANES; i++)
        begin
            for (int j = 0; j < P_SPL; j++)
                lclk_sdp.sym[i][j] = TX_LNK_SYM_DAT;

            // Start SS
            if (lclk_sdp.ss_ins)
                lclk_sdp.sym[i][P_SPL-1] = TX_LNK_SYM_SS;

            // End SE
            else if (lclk_sdp.se_ins)
                lclk_sdp.sym[i][0] = TX_LNK_SYM_SE;

            // End SE within the last cycle
            else if (lclk_sdp.rem_del[1] != 0)
                lclk_sdp.sym[i][lclk_sdp.rem_del[1]] = TX_LNK_SYM_SE;
        end
    end

// SDP valid
    always_comb
    begin
        if (lclk_sdp.ss_ins || lclk_sdp.se_ins || !lclk_sdp.rd_cnt_end_del[$high(lclk_sdp.rd_cnt_end_del)])
            lclk_sdp.vld = 1;
        else
            lclk_sdp.vld = 0;
    end

// Source data
// The source data is registered (same as the MSA module).
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

            lclk_src.vld <= 0;
        end

        else
        begin
            // SDP
            if (lclk_sdp.vld)
            begin
                for (int i = 0; i < P_LANES; i++)
                begin
                    for (int j = 0; j < P_SPL; j++)
                    begin
                        lclk_src.sym[i][j] <= lclk_sdp.sym[i][j];

                        // The symbols after the packet end are dummy symbols
                        if ((lclk_sdp.rem_del[1] != 0) && (j >= lclk_sdp.rem_del[1]))
                            lclk_src.dat[i][j] <= 0;
                        else
                            lclk_src.dat[i][j] <= lclk_sdp.dat[i][j];
                    end
                end

                lclk_src.vld <= 1;
            end

            // Sink data
            else
            begin
                for (int i = 0; i < P_LANES; i++)
                begin
                    for (int j = 0; j < P_SPL; j++)
                    begin
                        lclk_src.sym[i][j] <= lclk_snk.sym[i][j];
                        lclk_src.dat[i][j] <= lclk_snk.dat[i][j];
                    end
                end

                lclk_src.vld <= lclk_snk.vld;
            end
        end
    end

//-----
// Outputs
//-----
// Processor packets taken
    assign SDP_PRC_CNT_OUT = sclk_prc.pkt_rd;

// The ready is cleared for a processor packet between the packets of the SDP input.
    assign SDP_SNK_IF.rdy = sclk_sdp.rdy && !(sclk_prc.req && !sclk_prc.ext_run);

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
    assign LNK_SRC_IF.vld = lclk_src.vld;

endmodule

`default_nettype wire
