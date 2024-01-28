/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP RX Video - FIFO
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

module prt_dprx_vid_fifo
#(
    parameter                               P_VENDOR = "none",  // Vendor "amd", "intel" or "lattice"
    parameter                               P_SIM = 0,          // Simulation
    parameter                               P_FIFO_WRDS = 64,   // FIFO words
    parameter                               P_LANES = 4,        // Lanes
    parameter                               P_SEGMENTS = 4,     // Segments
    parameter                               P_STRIPES = 4       // Stripes
)
(
    // Link port
    input wire                              LNK_RST_IN,
    input wire                              LNK_CLK_IN,
    input wire                              LNK_CLR_IN,
    input wire [7:0]                        LNK_DAT_IN[P_LANES][P_SEGMENTS],
    input wire [P_SEGMENTS-1:0]             LNK_WR_IN[P_LANES],

    // Video port
    input wire                              VID_RST_IN,
    input wire                              VID_CLK_IN,
    input wire                              VID_CLR_IN,
    input wire [P_STRIPES-1:0]              VID_RD_IN[P_LANES][P_SEGMENTS],
    output wire [1:0]                       VID_DAT_OUT[P_LANES][P_SEGMENTS][P_STRIPES],
    output wire [P_STRIPES-1:0]             VID_DE_OUT[P_LANES][P_SEGMENTS],
    output wire [5:0]                       VID_LVL_OUT
);

// Parameters
// FIFO optimization. In simulation the optimization is not used.
// This enables the FIFO status (empty, full and words), which is handy for debugging
localparam P_FIFO_OPT = (P_SIM) ? 0 : 1;         
localparam P_FIFO_ADR = $clog2(P_FIFO_WRDS);
localparam P_FIFO_DAT = 2;

// Structures
typedef struct {
    logic                           clr;
    logic	[P_STRIPES-1:0]	        wr[P_LANES][P_SEGMENTS];  
    logic   [P_FIFO_DAT-1:0]        din[P_LANES][P_SEGMENTS][P_STRIPES];
    logic   [5:0]                   head_lane[P_LANES];
    logic   [5:0]                   head_tmp[P_LANES/2];
    logic   [5:0]                   head;
} lnk_fifo_struct;

typedef struct {
    logic                           clr;
    logic	[P_STRIPES-1:0]   	    rd[P_LANES][P_SEGMENTS];
    logic	[P_FIFO_DAT-1:0]        dout[P_LANES][P_SEGMENTS][P_STRIPES];
    logic	[P_STRIPES-1:0]	        de[P_LANES][P_SEGMENTS];
    logic   [P_STRIPES-1:0]         fl[P_LANES][P_SEGMENTS];
    logic   [P_STRIPES-1:0]         ep[P_LANES][P_SEGMENTS];
    logic   [5:0]                   head;
    logic   [5:0]                   tail;
    logic   [5:0]                   lvl;
} vid_fifo_struct;

// Signals
lnk_fifo_struct     lclk_fifo;
vid_fifo_struct     vclk_fifo;

genvar i, j, k;

// Logic

/*
    Link port
*/

// Link Inputs
    assign lclk_fifo.clr = LNK_CLR_IN;

generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_lnk_lanes
        for (j = 0; j < P_SEGMENTS; j++)
        begin : gen_lnk_segments
            for (k = 0; k < P_STRIPES; k++)
            begin : gen_lnk_stripes
                assign lclk_fifo.din[i][j][k] = LNK_DAT_IN[i][j][(((4-k)*2)-1)-:2];
                assign lclk_fifo.wr[i][j][k] = LNK_WR_IN[i][j];
            end
        end
    end
endgenerate

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
            // Clear
            if (lclk_fifo.clr)
                lclk_fifo.head_lane[i] <= 0;

            // Increment
            else if (lclk_fifo.wr[i][P_SEGMENTS-1][P_STRIPES-1])
                lclk_fifo.head_lane[i] <= lclk_fifo.head_lane[i] + 'd1;
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
generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_fifo_lanes       
        for (j = 0; j < P_SEGMENTS; j++)
        begin : gen_fifo_segments
            for (k = 0; k < P_STRIPES; k++)
            begin : gen_fifo_stripes
                // FIFO
                prt_dp_lib_fifo_dc
                #(
                    .P_VENDOR       (P_VENDOR),             // Vendor
                    .P_MODE         ("burst"),		        // "single" or "burst"
                    .P_RAM_STYLE	("distributed"),	    // "distributed" or "block"
                    .P_OPT 			(P_FIFO_OPT),			// In optimized mode the status port are not available. This saves some logic.
                    .P_ADR_WIDTH	(P_FIFO_ADR),
                    .P_DAT_WIDTH	(P_FIFO_DAT)
                )
                FIFO_INST
                (
                    .A_RST_IN      (LNK_RST_IN),                    // Reset
                    .B_RST_IN      (VID_RST_IN),
                    .A_CLK_IN      (LNK_CLK_IN),                    // Clock
                    .B_CLK_IN      (VID_CLK_IN),
                    .A_CKE_IN      (1'b1),                          // Clock enable
                    .B_CKE_IN      (1'b1),

                    // Input (A)
                    .A_CLR_IN      (lclk_fifo.clr),                 // Clear
                    .A_WR_IN       (lclk_fifo.wr[i][j][k]),         // Write
                    .A_DAT_IN      (lclk_fifo.din[i][j][k]),        // Write data

                    // Output (B)
                    .B_CLR_IN      (vclk_fifo.clr),                 // Clear
                    .B_RD_IN       (vclk_fifo.rd[i][j][k]),         // Read
                    .B_DAT_OUT     (vclk_fifo.dout[i][j][k]),       // Read data
                    .B_DE_OUT      (vclk_fifo.de[i][j][k]),         // Data enable

                    // Status (A)
                    .A_WRDS_OUT    (),                              // Used words
                    .A_FL_OUT      (),                              // Full
                    .A_EP_OUT      (),                              // Empty

                    // Status (B)
                    .B_WRDS_OUT    (),                              // Used words
                    .B_FL_OUT      (vclk_fifo.fl[i][j][k]),         // Full
                    .B_EP_OUT      (vclk_fifo.ep[i][j][k])          // Empty
                );
            end
        end
    end
endgenerate

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

/*
    Video port
*/

// Video Inputs
    assign vclk_fifo.clr = VID_CLR_IN;

generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_fifo_rd_lanes
        for (j = 0; j < P_SEGMENTS; j++)
        begin : gen_fifo_rd_segments
            for (k = 0; k < P_STRIPES; k++)
            begin : gen_vid_stripes
                assign vclk_fifo.rd[i][j][k] = VID_RD_IN[i][j][k];
            end
        end
    end
endgenerate

// Tail
// This process keeps track of the read bytes from the fifo.
// As the reading is synchronous only the first fifo is counted.
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Clear
        if (vclk_fifo.clr)
            vclk_fifo.tail <= 0;

        // Increment
        else if (vclk_fifo.rd[0][0][0])
            vclk_fifo.tail <= vclk_fifo.tail + 'd1;
    end

// Level
    always_comb
    begin
        if (vclk_fifo.head > vclk_fifo.tail)
            vclk_fifo.lvl = vclk_fifo.head - vclk_fifo.tail;
        else
            vclk_fifo.lvl = (2**$size(vclk_fifo.tail) - vclk_fifo.tail) + vclk_fifo.head;
    end        

// Outputs
generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_fifo_dout_lanes
        for (j = 0; j < P_SEGMENTS; j++)
        begin : gen_fifo_dout_segments
            for (k = 0; k < P_STRIPES; k++)
            begin : gen_fifo_dout_stripes
                assign VID_DAT_OUT[i][j][k] = vclk_fifo.dout[i][j][k];
            end

            assign VID_DE_OUT[i][j] = vclk_fifo.de[i][j];
        end
    end
endgenerate

    assign VID_LVL_OUT = vclk_fifo.lvl;

endmodule

`default_nettype wire
