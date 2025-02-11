/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP RX Control
    (c) 2021 - 2025 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Added support for single lane
    v1.2 - Added MST support
    v1.3 - Added BPC (bits per pixel) select

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

module prt_dprx_ctl
#(
    // Message
    parameter P_MSG_IDX     = 5,          // Message index width
    parameter P_MSG_DAT     = 16,         // Message data width
    parameter P_MSG_ID      = 0           // Message ID
)
(
    // Reset and clock
    input wire          RST_IN,
    input wire          CLK_IN,

    // Message
    prt_dp_msg_if.snk   MSG_SNK_IF,             // Sink
    prt_dp_msg_if.src   MSG_SRC_IF,             // Source

    // Control output
    output wire         CTL_LNK_EN_OUT,         // Link enable 
    output wire [1:0]   CTL_LANES_OUT,          // Active lanes (1 - 1 lane / 2 - 2 lanes / 3 - 4 lanes)
    output wire         CTL_SCRM_EN_OUT,        // Scrambler enable
    output wire         CTL_MST_EN_OUT,         // MST enable
    output wire [1:0]   CTL_BPC_OUT             // Active bits-per-component (0 - 8 bits / 1 - 10 bits / 2 - reserved / 3 - reserved)
);

// Parameters
localparam P_CTL_WIDTH          = 7;
localparam P_CTL_LNK_EN         = 0;
localparam P_CTL_LANES          = 1;
localparam P_CTL_SCRM_EN        = 3;
localparam P_CTL_MST_EN         = 4;
localparam P_CTL_BPC            = 5;

// Structures
typedef struct {
    logic	[P_MSG_IDX-1:0]	      idx;
    logic                         first;
    logic                         last;
	logic	[P_MSG_DAT-1:0]	      dat;
	logic				          vld;
} msg_struct;

// Signals
msg_struct                  clk_msg;
logic [P_CTL_WIDTH-1:0]     clk_msk;    // Mask
logic [P_CTL_WIDTH-1:0]     clk_ctl;    // Control register

// Message Slave
    prt_dp_msg_slv_egr
    #(
        .P_ID           (P_MSG_ID),     // Identifier
        .P_IDX_WIDTH    (P_MSG_IDX),    // Index width
        .P_DAT_WIDTH    (P_MSG_DAT)     // Data width
    )
    MSG_SLV_EGR_INST
    (
        // Reset and clock
        .RST_IN         (RST_IN),
        .CLK_IN         (CLK_IN),

        // MSG sink
        .MSG_SNK_IF     (MSG_SNK_IF),

        // MSG source
        .MSG_SRC_IF     (MSG_SRC_IF),

        // Eggress
        .EGR_IDX_OUT    (clk_msg.idx),    // Index
        .EGR_FIRST_OUT  (clk_msg.first),  // First
        .EGR_LAST_OUT   (clk_msg.last),   // Last
        .EGR_DAT_OUT    (clk_msg.dat),    // Data
        .EGR_VLD_OUT    (clk_msg.vld)     // Valid
    );

// Mask register
    always_ff @ (posedge RST_IN, posedge CLK_IN)
    begin
        // Reset
        if (RST_IN)
            clk_msk <= 0;

        else
        begin
            // Write
            if (clk_msg.vld && (clk_msg.idx == 'd0))
                clk_msk <= clk_msg.dat[0+:$size(clk_msk)];
        end
    end

// Control register
    always_ff @ (posedge RST_IN, posedge CLK_IN)
    begin
        // Reset
        if (RST_IN)
            clk_ctl <= 0;

        else
        begin
            // Write
            if (clk_msg.vld && (clk_msg.idx == 'd1))
            begin
                for (int i = 0; i < $size(clk_ctl); i++)
                begin
                    // Mask
                    if (clk_msk[i])
                        clk_ctl[i] <= clk_msg.dat[i];
                end
            end
        end
    end

// Outputs
    assign CTL_LNK_EN_OUT       = clk_ctl[P_CTL_LNK_EN];
    assign CTL_LANES_OUT        = clk_ctl[P_CTL_LANES+:2];
    assign CTL_SCRM_EN_OUT      = clk_ctl[P_CTL_SCRM_EN];
    assign CTL_MST_EN_OUT       = clk_ctl[P_CTL_MST_EN];
    assign CTL_BPC_OUT          = clk_ctl[P_CTL_BPC+:$size(CTL_BPC_OUT)];

endmodule

`default_nettype wire
