/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP Message Slave Ingress
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
module prt_dp_msg_slv_ing
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

    // Ingress
    output wire [P_IDX_WIDTH-1:0]       ING_IDX_OUT,       // Index
    output wire                         ING_FIRST_OUT,     // First
    output wire                         ING_LAST_OUT,      // Last
    input wire [P_DAT_WIDTH-1:0]        ING_DAT_IN,        // Data
    output wire                         ING_ACK_OUT        // Acknowledge
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
	logic					      ack;
} ing_struct;

// Signals
msg_struct			clk_msg;			// Message
ing_struct			clk_ing;			// Ingress

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
            clk_ing.act <= 0;

        else
        begin
            // CLear
            if (clk_msg.eom && clk_msg.vld)
                clk_ing.act <= 0;

            // Set
            else if (clk_msg.som && clk_msg.vld && !clk_msg.dat[$size(clk_msg.dat)-1] && (clk_msg.dat[8+:7] == P_ID))
                clk_ing.act <= 1;
        end
    end

// Index
    always_ff @ (posedge CLK_IN)
    begin
        // Enable
        if (clk_ing.act)
        begin
            // Increment
            if (clk_msg.vld)
                clk_ing.idx <= clk_ing.idx + 'd1;
        end

        // Idle
        else
            clk_ing.idx <= 0;
    end

// Acknowledge
    always_comb
    begin
        if (clk_ing.act && clk_msg.vld)
            clk_ing.ack = 1;
        else
            clk_ing.ack = 0;
    end

// First
// This flag is asserted at the first message data
// This must be registered
    always_comb
    begin
        if (clk_ing.act && clk_msg.vld && (clk_ing.idx == 0))
            clk_ing.first = 1;
        else
            clk_ing.first = 0;
    end

// Last
// This flag is asserted during the last message data
    always_comb
    begin
        if (clk_ing.act && clk_msg.vld && clk_msg.eom)
            clk_ing.last = 1;
        else
            clk_ing.last = 0;
    end

// Data
    assign clk_ing.dat = ING_DAT_IN;

// Outputs
    assign MSG_SRC_IF.som   = clk_msg.som;
    assign MSG_SRC_IF.eom   = clk_msg.eom;
    assign MSG_SRC_IF.dat   = (clk_ing.act) ? clk_ing.dat : clk_msg.dat;
    assign MSG_SRC_IF.vld   = clk_msg.vld;

    assign ING_IDX_OUT      = clk_ing.idx;
    assign ING_FIRST_OUT    = clk_ing.first;
    assign ING_LAST_OUT     = clk_ing.last;
    assign ING_ACK_OUT      = clk_ing.ack;

endmodule

`default_nettype wire
