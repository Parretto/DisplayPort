/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP TX Video - FIFO
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

module prt_dptx_vid_fifo
#(
    parameter                               P_VENDOR = "none",  // Vendor - "AMD", "ALTERA" or "LSC" 
    parameter                               P_SIM = 0,          // Simulation
    parameter                               P_FIFO_WRDS = 64,   // FIFO words
    parameter                               P_LANES = 4,        // Lanes
    parameter                               P_SEGMENTS = 4,     // Segments
    parameter                               P_STRIPES = 4       // Stripes
)
(
    // Video port
    input wire                              VID_RST_IN,                                     // Reset
    input wire                              VID_CLK_IN,                                     // Clock
    input wire                              VID_HS_IN,                                      // Hsync 
    input wire [1:0]                        VID_DAT_IN[P_LANES][P_SEGMENTS][P_STRIPES],     // Data
    input wire [P_STRIPES-1:0]              VID_WR_IN[P_LANES][P_SEGMENTS],                 // Write
    input wire                              VID_LAST_IN,                                    // Last

    // Link port
    input wire                              LNK_RST_IN,                                     // Reset
    input wire                              LNK_CLK_IN,                                     // Clock
    output wire                             LNK_DP_CLR_OUT,                                 // Datapath Clear
    input wire [P_STRIPES-1:0]              LNK_RD_IN[P_LANES],                             // Read
    output wire [7:0]                       LNK_DAT_OUT[P_LANES][P_SEGMENTS],               // Data
    output wire [P_SEGMENTS-1:0]            LNK_DE_OUT[P_LANES],                            // Data enable
    output wire [7:0]                       LNK_LVL_OUT,                                    // Level
    output wire                             LNK_LAST_OUT                                    // Last
);

// Parameters
// FIFO optimization. In simulation the optimization is not used.
// This enables the FIFO status (empty, full and words), which is handy for debugging
localparam P_FIFO_OPT = (P_SIM) ? 0 : 1;         
localparam P_FIFO_ADR = $clog2(P_FIFO_WRDS);
localparam P_STRP_FIFO_DAT = 2;
localparam P_LAST_FIFO_DAT = 1;

// State machine
typedef enum {
	sm_idle, sm_last1, sm_last2, sm_clr
} sm_state;

// Structures
typedef struct {
    logic                           hs;         // Hsync 
    logic                           hs_re;      // Hsync rising edge
    logic                           hs_fe;      // Hsync falling edge
    logic                           last;
    logic                           last_re;
    logic   [7:0]                   head;
    logic   [7:0]                   head_last;
    logic                           eol;        // End-of-line
} vid_fifo_struct;

typedef struct {
    logic	[P_STRP_FIFO_DAT-1:0]   din[P_LANES][P_SEGMENTS][P_STRIPES];
    logic	[P_STRIPES-1:0]   	    wr[P_LANES][P_SEGMENTS];
} vid_strp_struct;

typedef struct {
    logic	din;
    logic	wr;
} vid_last_struct;

typedef struct {
    logic                           hs;                 // Hsync
    logic                           hs_fe;              // Hsync falling edge
    logic   [7:0]                   head_cdc;           // Head CDC
    logic   [7:0]                   head_last_cdc;      // Head last CDC
    logic                           eol_cdc;            // End-of-line CDC
    logic                           eol_cdc_re;         // End-of-line rising edge
    logic                           vid_eol;            // Video end-of-line
    logic                           vid_eol_re;         // Video end-of-line rising edge 
    logic   [7:0]                   head;               // Head
    logic   [7:0]                   tail;               // Tail
    logic   [7:0]                   lvl;                // Level
    logic                           last;               // Last flag
} lnk_fifo_struct;

typedef struct {
    logic	[P_STRIPES-1:0]	        rd[P_LANES][P_SEGMENTS];  
    logic   [P_STRP_FIFO_DAT-1:0]   dout[P_LANES][P_SEGMENTS][P_STRIPES];
    logic	[P_STRIPES-1:0]	        de[P_LANES][P_SEGMENTS];  
    logic	[P_STRIPES-1:0]	        ep[P_LANES][P_SEGMENTS];  
    logic	[P_STRIPES-1:0]	        fl[P_LANES][P_SEGMENTS];  
} lnk_strp_struct;

typedef struct {
    logic	rd;
    logic   dout;
    logic	de;
} lnk_last_struct;

typedef struct {
    sm_state                        sm_cur;
    sm_state                        sm_nxt;
    logic                           sm_dp_clr;
    logic                           dp_clr;
    logic                           cnt_ld;
    logic [7:0]                     cnt;
    logic                           cnt_end;
    logic                           cnt_end_re;
} lnk_wdg_struct;

// Signals
vid_fifo_struct     vclk_fifo;
vid_strp_struct     vclk_strp;
vid_last_struct     vclk_last;
lnk_fifo_struct     lclk_fifo;
lnk_strp_struct     lclk_strp;
lnk_last_struct     lclk_last;
lnk_wdg_struct      lclk_wdg;

genvar i, j, k;

// Logic

/*
    Video port
*/

// Video Inputs
    assign vclk_fifo.hs = VID_HS_IN;

// Hsync edge detector
    prt_dp_lib_edge
    VCLK_HS_EDGE_INST
    (
        .CLK_IN    (VID_CLK_IN),         // Clock
        .CKE_IN    (1'b1),               // Clock enable
        .A_IN      (vclk_fifo.hs),       // Input
        .RE_OUT    (vclk_fifo.hs_re),    // Rising edge
        .FE_OUT    (vclk_fifo.hs_fe)     // Falling edge
    );

// Last registered
// The last needs to be registered to be in sync with the head counter. 
    always_ff @ (posedge VID_CLK_IN)
    begin
        vclk_fifo.last <= VID_LAST_IN;
    end

// Last edge
    prt_dp_lib_edge
    VCLK_LAST_EDGE_INST
    (
        .CLK_IN    (VID_CLK_IN),            // Clock
        .CKE_IN    (1'b1),                  // Clock enable
        .A_IN      (vclk_fifo.last),        // Input
        .RE_OUT    (vclk_fifo.last_re),     // Rising edge
        .FE_OUT    ()                       // Falling edge
    );
// Stripe fifo
generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_vid_lanes
        for (j = 0; j < P_SEGMENTS; j++)
        begin : gen_vid_segments
            for (k = 0; k < P_STRIPES; k++)
            begin : gen_vid_stripes
                assign vclk_strp.din[i][j][k] = VID_DAT_IN[i][j][k];
                assign vclk_strp.wr[i][j][k] = VID_WR_IN[i][j][k];
            end
        end
    end
endgenerate

// Last fifo
    assign vclk_last.din = VID_LAST_IN;
    assign vclk_last.wr = vclk_strp.wr[3][3][3];

// Head 
// The head counter is used count the active words in the fifo. 
// Only the last stripe of the last lane is used. 
// The head value is used by the link domain to determine the size of the read packet.
    always_ff @ (posedge VID_RST_IN, posedge VID_CLK_IN)
    begin
        // Reset
        if (VID_RST_IN)
            vclk_fifo.head <= 0;
        
        else
        begin
            // Clear on Hsync rising edge
            if (vclk_fifo.hs_re)
                vclk_fifo.head <= 0;

            // Increment
            else if (vclk_strp.wr[P_LANES-1][P_SEGMENTS-1][P_STRIPES-1])
                vclk_fifo.head <= vclk_fifo.head + 'd1;
        end
    end

// Head Last 
// This register captures the last head value.
// This extra register is introduced to present a race condition between the head value and head last active flag
    always_ff @ (posedge VID_RST_IN, posedge VID_CLK_IN)
    begin
        // Reset
        if (VID_RST_IN)
            vclk_fifo.head_last <= 0;
        
        else
        begin
            // Load
            if (vclk_fifo.last_re)
                vclk_fifo.head_last <= vclk_fifo.head;
        end
    end

// End-of-line flag
// This flag indicates that video domain has reached the end-of-line and the last head count is valid.
    always_ff @ (posedge VID_RST_IN, posedge VID_CLK_IN)
    begin
        // Reset
        if (VID_RST_IN)
            vclk_fifo.eol <= 0;

        else
        begin
            // Clear on Hsync falling edge
            if (vclk_fifo.hs_fe)
                vclk_fifo.eol <= 0;

            // Set on last
            else if (vclk_fifo.last_re)
                vclk_fifo.eol <= 1;
        end
    end

// Stripe FIFOs
// These FIFO store the data
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
                    .P_DAT_WIDTH	(P_STRP_FIFO_DAT)
                )
                STRP_FIFO_INST
                (
                    .A_RST_IN      (VID_RST_IN),                    // Reset
                    .B_RST_IN      (LNK_RST_IN),
                    .A_CLK_IN      (VID_CLK_IN),                   // Clock
                    .B_CLK_IN      (LNK_CLK_IN),
                    .A_CKE_IN      (1'b1),                         // Clock enable
                    .B_CKE_IN      (1'b1),

                    // Input (A)
                    .A_CLR_IN      (vclk_fifo.hs_fe),              // Clear
                    .A_WR_IN       (vclk_strp.wr[i][j][k]),        // Write
                    .A_DAT_IN      (vclk_strp.din[i][j][k]),       // Write data

                    // Output (B)
                    .B_CLR_IN      (lclk_wdg.dp_clr),              // Clear
                    .B_RD_IN       (lclk_strp.rd[i][j][k]),        // Read
                    .B_DAT_OUT     (lclk_strp.dout[i][j][k]),      // Read data
                    .B_DE_OUT      (lclk_strp.de[i][j][k]),        // Data enable

                    // Status (A)
                    .A_WRDS_OUT    (),                             // Used words
                    .A_FL_OUT      (),                             // Full
                    .A_EP_OUT      (),                             // Empty

                    // Status (B)
                    .B_WRDS_OUT    (),                             // Used words
                    .B_FL_OUT      (lclk_strp.fl[i][j][k]),        // Full
                    .B_EP_OUT      (lclk_strp.ep[i][j][k])         // Empty
                );
            end
        end
    end
endgenerate

// Last FIFO
// This fifo is used to store the last flag
    prt_dp_lib_fifo_dc
    #(
        .P_VENDOR       (P_VENDOR),             // Vendor
        .P_MODE         ("burst"),		        // "single" or "burst"
        .P_RAM_STYLE	("distributed"),	    // "distributed" or "block"
        .P_OPT 			(P_FIFO_OPT),			// In optimized mode the status port are not available. This saves some logic.
        .P_ADR_WIDTH	(P_FIFO_ADR),
        .P_DAT_WIDTH	(P_LAST_FIFO_DAT)
    )
    FIFO_LAST_INST
    (
        .A_RST_IN      (VID_RST_IN),           // Reset
        .B_RST_IN      (LNK_RST_IN),
        .A_CLK_IN      (VID_CLK_IN),           // Clock
        .B_CLK_IN      (LNK_CLK_IN),
        .A_CKE_IN      (1'b1),                 // Clock enable
        .B_CKE_IN      (1'b1),

        // Input (A)
        .A_CLR_IN      (vclk_fifo.hs_fe),      // Clear
        .A_WR_IN       (vclk_last.wr),         // Write
        .A_DAT_IN      (vclk_last.din),        // Write data

        // Output (B)
        .B_CLR_IN      (lclk_wdg.dp_clr),      // Clear
        .B_RD_IN       (lclk_last.rd),         // Read
        .B_DAT_OUT     (lclk_last.dout),       // Read data
        .B_DE_OUT      (lclk_last.de),         // Data enable

        // Status (A)
        .A_WRDS_OUT    (),                      // Used words
        .A_FL_OUT      (),                      // Full
        .A_EP_OUT      (),                      // Empty

        // Status (B)
        .B_WRDS_OUT    (),                      // Used words
        .B_FL_OUT      (),                      // Full
        .B_EP_OUT      ()                       // Empty
    );

// Head clock domain crossing
    prt_dp_lib_cdc_gray
    #(
        .P_VENDOR       (P_VENDOR),
        .P_WIDTH        ($size(lclk_fifo.head_cdc))
    )
    LCLK_HEAD_CDC_INST
    (
        .SRC_CLK_IN     (VID_CLK_IN),           // Clock
        .SRC_DAT_IN     (vclk_fifo.head),       // Data
        .DST_CLK_IN     (LNK_CLK_IN),           // Clock
        .DST_DAT_OUT    (lclk_fifo.head_cdc)    // Data
    );

// Head last clock domain crossing
    prt_dp_lib_cdc_gray
    #(
        .P_VENDOR       (P_VENDOR),
        .P_WIDTH        ($size(lclk_fifo.head_last_cdc))
    )
    LCLK_HEAD_LAST_CDC_INST
    (
        .SRC_CLK_IN     (VID_CLK_IN),               // Clock
        .SRC_DAT_IN     (vclk_fifo.head_last),      // Data
        .DST_CLK_IN     (LNK_CLK_IN),               // Clock
        .DST_DAT_OUT    (lclk_fifo.head_last_cdc)   // Data
    );

// End-of-line clock domain crossing
    prt_dp_lib_cdc_bit
    LCLK_EOL_CDC_INST
    (
        .SRC_CLK_IN     (VID_CLK_IN),           // Clock
        .SRC_DAT_IN     (vclk_fifo.eol),        // Data
        .DST_CLK_IN     (LNK_CLK_IN),           // Clock
        .DST_DAT_OUT    (lclk_fifo.eol_cdc)     // Data
    );

// End-of-line edge detector
    prt_dp_lib_edge
    LCLK_EOL_CDC_EDGE_INST
    (
        .CLK_IN    (LNK_CLK_IN),                // Clock
        .CKE_IN    (1'b1),                      // Clock enable
        .A_IN      (lclk_fifo.eol_cdc),         // Input
        .RE_OUT    (lclk_fifo.eol_cdc_re),      // Rising edge
        .FE_OUT    ()                           // Falling edge
    );

// Hsync clock domain crossing
    prt_dp_lib_cdc_bit
    LCLK_HS_CDC_INST
    (
        .SRC_CLK_IN     (VID_CLK_IN),       // Clock
        .SRC_DAT_IN     (vclk_fifo.hs),     // Data
        .DST_CLK_IN     (LNK_CLK_IN),       // Clock
        .DST_DAT_OUT    (lclk_fifo.hs)      // Data
    );

// Hsync edge detector
    prt_dp_lib_edge
    LCLK_HS_EDGE_INST
    (
        .CLK_IN    (LNK_CLK_IN),         // Clock
        .CKE_IN    (1'b1),               // Clock enable
        .A_IN      (lclk_fifo.hs),       // Input
        .RE_OUT    (),                   // Rising edge
        .FE_OUT    (lclk_fifo.hs_fe)     // Falling edge
    );

/*
    Link port
*/

// Link Inputs

// Stripe fifo
generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_fifo_rd_lanes
        for (j = 0; j < P_SEGMENTS; j++)
        begin : gen_fifo_rd_segments
            for (k = 0; k < P_STRIPES; k++)
            begin : gen_fifo_rd_stripes
                assign lclk_strp.rd[i][j][k] = LNK_RD_IN[i][j];
            end
        end
    end
endgenerate

// Last FIFO
    assign lclk_last.rd = lclk_strp.rd[0][3][3];

// Video End-of-line
// This flag is asserted to indicate the video domain has reached the end-of-line. 
// Then the head last value is active
    always_ff @ (posedge LNK_RST_IN, posedge LNK_CLK_IN)
    begin
        // Reset
        if (LNK_RST_IN)
            lclk_fifo.vid_eol <= 0;

        else
        begin
            // Clear
            if (lclk_wdg.dp_clr)
                lclk_fifo.vid_eol <= 0;

            // Set
            else if (lclk_fifo.eol_cdc_re)
                lclk_fifo.vid_eol <= 1;
        end
    end

// Video end-of-line edge detector
// This is used by the state machine
    prt_dp_lib_edge
    LCLK_HEAD_LAST_EDGE_INST
    (
        .CLK_IN    (LNK_CLK_IN),                // Clock
        .CKE_IN    (1'b1),                      // Clock enable
        .A_IN      (lclk_fifo.vid_eol),         // Input
        .RE_OUT    (lclk_fifo.vid_eol_re),      // Rising edge
        .FE_OUT    ()                           // Falling edge
    );

// Head
    always_ff @ (posedge LNK_RST_IN, posedge LNK_CLK_IN)
    begin
        // Reset
        if (LNK_RST_IN)
            lclk_fifo.head <= 0;

        else

        // Clear
        if (lclk_wdg.dp_clr)
            lclk_fifo.head <= 0;

        // End-of-line
        else if (lclk_fifo.vid_eol)
            lclk_fifo.head <= lclk_fifo.head_last_cdc;
        
        // Pass
        else
            lclk_fifo.head <= lclk_fifo.head_cdc;
    end

// Tail
// This process keeps track of the read bytes from the fifo.
// As the reading is synchronous only the first fifo is counted.
    always_ff @ (posedge LNK_RST_IN, posedge LNK_CLK_IN)
    begin
        // Reset
        if (LNK_RST_IN)
            lclk_fifo.tail <= 0;

        else
        begin
            // Clear
            if (lclk_wdg.dp_clr)
                lclk_fifo.tail <= 0;

            // Increment
            else if (lclk_strp.rd[0][0][0]) 
                lclk_fifo.tail <= lclk_fifo.tail + 'd1;
        end
    end

// Level
    always_comb
    begin
        if (lclk_fifo.head > lclk_fifo.tail)
            lclk_fifo.lvl = lclk_fifo.head - lclk_fifo.tail;
        else
            lclk_fifo.lvl = (2**$size(lclk_fifo.tail) - lclk_fifo.tail) + lclk_fifo.head;
    end        

// Last
    always_comb
    begin
        if (lclk_last.de && lclk_last.dout)
            lclk_fifo.last = 1;
        else
            lclk_fifo.last = 0;
    end

// Watchdog state machine
// We can't use the hsync or vsync signal from the video domain to reset the link domain. 
// This is because of the latency introduced by the head counter value clock domain crossing. 
// Because of the lagging the sync event might happing during the last data burst.
// This state machine keeps track of the last signal. If the last signal doesn't occur after a time out, 
// then something is wrong and the state machine resets the link domain. 
// The video domain is reset by the hsync signal. 
    always_ff @ (posedge LNK_RST_IN, posedge LNK_CLK_IN)
    begin   
        // Reset
        if (LNK_RST_IN)
            lclk_wdg.sm_cur <= sm_idle;

        else
        begin
            lclk_wdg.sm_cur <= lclk_wdg.sm_nxt;
        end
    end

// State machine decoder
    always_comb
    begin
        // Defaults
        lclk_wdg.sm_dp_clr = 0;
        lclk_wdg.cnt_ld = 0;

        case (lclk_wdg.sm_cur)
            
            // Idle
            sm_idle :
            begin
                // Wait for video end-of-line
                if (lclk_fifo.vid_eol_re)
                begin
                    lclk_wdg.cnt_ld = 1;
                    lclk_wdg.sm_nxt = sm_last1;
                end

                else
                    lclk_wdg.sm_nxt = sm_idle;
            end

            // Last wait
            sm_last1 :
            begin
                // Did we see the last data?
                if (lclk_fifo.last)
                    lclk_wdg.sm_nxt = sm_last2;

                // Watchdog kicking in
                else if (lclk_wdg.cnt_end_re)
                    lclk_wdg.sm_nxt = sm_clr;

                else
                    lclk_wdg.sm_nxt = sm_last1;
            end

            // Last clear
            sm_last2 : 
            begin
                // We need to wait until the video domain has cleared the end-of-line flag
                if (!lclk_fifo.eol_cdc)
                begin
                    // Reset datapath
                    lclk_wdg.sm_dp_clr = 1;

                    // Return to idle
                    lclk_wdg.sm_nxt = sm_idle;
                end

                else
                    lclk_wdg.sm_nxt = sm_last2;
            end

            // Clear
            // We didn't see the last data within the watchdog time out. 
            // We reset the datapath and wait for the hsync falling edge to de-assert the reset.
            // In this case we are sure that the link domain keeps reseting untill the video comes out of reset.  
            sm_clr :
            begin
                // Keep reseting
                lclk_wdg.sm_dp_clr = 1;

                // Wait for hsync falling edge
                if (lclk_fifo.hs_fe)
                    lclk_wdg.sm_nxt = sm_idle;
                else
                    lclk_wdg.sm_nxt = sm_clr;
            end

            default : 
                lclk_wdg.sm_nxt = sm_idle;

        endcase
    end

// Watchdog datapath clear
// This signal is used to clear the datapath in the link domain.
    always_ff @ (posedge LNK_RST_IN, posedge LNK_CLK_IN)
    begin   
        // Reset
        if (LNK_RST_IN)
            lclk_wdg.dp_clr <= 1;

        else
        begin
            lclk_wdg.dp_clr <= lclk_wdg.sm_dp_clr;
        end
    end

// Watchdog counter
// This signal is used to clear the datapath in the link domain.
    always_ff @ (posedge LNK_RST_IN, posedge LNK_CLK_IN)
    begin   
        // Reset
        if (LNK_RST_IN)
            lclk_wdg.cnt <= 0;

        else
        begin
            // Load
            if (lclk_wdg.cnt_ld)
                lclk_wdg.cnt <= '1; 
            
            // Decrement
            else if (!lclk_wdg.cnt_end)    
                lclk_wdg.cnt <= lclk_wdg.cnt - 'd1;
        end
    end

// Watchdog counter
    always_comb
    begin
        if (lclk_wdg.cnt == 0)
            lclk_wdg.cnt_end = 1;
        else
            lclk_wdg.cnt_end = 0;
    end

// Watchdog counter end
    prt_dp_lib_edge
    LNK_CNT_END_EDGE_INST
    (
        .CLK_IN    (LNK_CLK_IN),                // Clock
        .CKE_IN    (1'b1),                      // Clock enable
        .A_IN      (lclk_wdg.cnt_end),          // Input
        .RE_OUT    (lclk_wdg.cnt_end_re),       // Rising edge
        .FE_OUT    ()                           // Falling edge
    );    

// Outputs
generate
    for (i = 0; i < P_LANES; i++)
    begin : gen_fifo_dout_lanes
        for (j = 0; j < P_SEGMENTS; j++)
        begin : gen_fifo_dout_segments
            for (k = 0; k < P_STRIPES; k++)
            begin : gen_fifo_dout_stripes
                assign LNK_DAT_OUT[i][j][(((4-k)*2)-1)-:2] = lclk_strp.dout[i][j][k];
            end

            assign LNK_DE_OUT[i][j] = |lclk_strp.de[i][j];
        end
    end
endgenerate

    assign LNK_LVL_OUT = lclk_fifo.lvl;
    assign LNK_LAST_OUT = lclk_fifo.last;
    assign LNK_DP_CLR_OUT = lclk_wdg.dp_clr;

endmodule

`default_nettype wire
