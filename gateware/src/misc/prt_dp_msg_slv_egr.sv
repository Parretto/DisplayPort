/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP Message Slave Egress
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

// Module
module prt_dp_msg_slv_egr
#(
    parameter P_ID = 0,             // Identifier
    parameter P_IDX_WIDTH = 6,      // Index width
    parameter P_DAT_WIDTH = 16      // Data width
)
(
    // Reset and clock
    input wire                          RST_IN,
    input wire                          CLK_IN,

    // MSG sink
    prt_dp_msg_if.snk                   MSG_SNK_IF,

    // MSG source
    prt_dp_msg_if.src                   MSG_SRC_IF,

    // Eggress
    output wire [P_IDX_WIDTH-1:0]       EGR_IDX_OUT,       // Index
    output wire                         EGR_FIRST_OUT,     // First
    output wire                         EGR_LAST_OUT,      // Last
    output wire [P_DAT_WIDTH-1:0]       EGR_DAT_OUT,       // Data
    output wire                         EGR_VLD_OUT        // Valid
);

// Structure
typedef struct {
    logic					      som;
    logic					      eom;
	logic	[P_DAT_WIDTH-1:0]	  dat;
	logic					      vld;
} msg_struct;

typedef struct {
    logic                         act;
    logic	[P_IDX_WIDTH-1:0]	  idx;
    logic                         first;
    logic                         last;
	logic	[P_DAT_WIDTH-1:0]	  dat;
	logic					      vld;
} egr_struct;

// Signals
msg_struct			clk_msg;			// Message
egr_struct			clk_egr;			// Egress

// Logic
// Message
    always_ff @ (posedge CLK_IN)
    begin
        clk_msg.som <= MSG_SNK_IF.som;
        clk_msg.eom <= MSG_SNK_IF.eom;
        clk_msg.dat <= MSG_SNK_IF.dat;
        clk_msg.vld <= MSG_SNK_IF.vld;
    end

// Active
// This flag is set the ID-tag matches the header
// and the put bit is asserted.
    always_ff @ (posedge RST_IN, posedge CLK_IN)
    begin
        // Reset
        if (RST_IN)
            clk_egr.act <= 0;

        else
        begin
            // CLear
            if (clk_msg.eom && clk_msg.vld)
                clk_egr.act <= 0;

            // Set
            else if (clk_msg.som && clk_msg.vld && clk_msg.dat[$size(clk_msg.dat)-1] && (clk_msg.dat[8+:7] == P_ID))
                clk_egr.act <= 1;
        end
    end

// Index
    always_ff @ (posedge CLK_IN)
    begin
        // Enable
        if (clk_egr.act)
        begin
            // Increment
            if (clk_egr.vld)
                clk_egr.idx <= clk_egr.idx + 'd1;
        end

        // Idle
        else
            clk_egr.idx <= 0;
    end

// Valid
    always_comb
    begin
        if (clk_egr.act && clk_msg.vld)
            clk_egr.vld = 1;
        else
            clk_egr.vld = 0;
    end

// Data
    assign clk_egr.dat = clk_msg.dat;

// First
// This flag is asserted at the first message data
// This must be registered
    always_comb
    begin
        if (clk_egr.act && clk_msg.vld && (clk_egr.idx == 0))
            clk_egr.first = 1;
        else
            clk_egr.first = 0;
    end

// Last
// This flag is asserted during the last message data
    always_comb
    begin
        if (clk_egr.act && clk_msg.vld && clk_msg.eom)
            clk_egr.last = 1;
        else
            clk_egr.last = 0;
    end

// Outputs
    assign MSG_SRC_IF.som   = clk_msg.som;
    assign MSG_SRC_IF.eom   = clk_msg.eom;
    assign MSG_SRC_IF.dat   = clk_msg.dat;
    assign MSG_SRC_IF.vld   = clk_msg.vld;

    assign EGR_IDX_OUT      = clk_egr.idx;
    assign EGR_FIRST_OUT    = clk_egr.first;
    assign EGR_LAST_OUT     = clk_egr.last;
    assign EGR_DAT_OUT      = clk_egr.dat;
    assign EGR_VLD_OUT      = clk_egr.vld;

endmodule

`default_nettype wire
