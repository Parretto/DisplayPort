/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP Message Clock Domain Converter
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

// Module
module prt_dp_msg_cdc
#(
    parameter P_VENDOR      = "none",  // Vendor "xilinx" or "lattice"
    parameter P_DAT_WIDTH = 16
)
(
    // Reset and clock
    input wire                          A_RST_IN,
    input wire                          B_RST_IN,
    input wire                          A_CLK_IN,
    input wire                          B_CLK_IN,

    // Port A
    prt_dp_msg_if.snk                   A_MSG_SNK_IF,

    // Port B
    prt_dp_msg_if.src                   B_MSG_SRC_IF
);

// Parameters
localparam P_FIFO_WRDS = 8;
localparam P_FIFO_ADR = $clog2(P_FIFO_WRDS);
localparam P_FIFO_DAT = P_DAT_WIDTH + 2;        // Data + som + eom

// Structure
typedef struct {
    logic                       som;
    logic                       eom;
    logic   [P_DAT_WIDTH-1:0]   dat;
    logic                       vld;
} aclk_msg_struct;

typedef struct {
    logic                        rst;
    logic                        wr;
    logic   [P_FIFO_DAT-1:0]     din;
    logic   [P_FIFO_ADR:0]       wrds;
    logic                        ep;
    logic                        fl;
} aclk_fifo_struct;

typedef struct {
    logic                       som;
    logic                       eom;
    logic   [P_DAT_WIDTH-1:0]   dat;
    logic                       vld;
} bclk_msg_struct;

typedef struct {
    logic                       rd;
    logic   [P_FIFO_DAT-1:0]    dout;
    logic                       de;
    logic   [P_FIFO_ADR:0]      wrds;
    logic                       ep;
    logic                       fl;
} bclk_fifo_struct;

// Signals
aclk_msg_struct     aclk_msg;
aclk_fifo_struct    aclk_fifo;
bclk_msg_struct     bclk_msg;
bclk_fifo_struct    bclk_fifo;

// Logic

// Reset converter
// When the port B is reset the FIFO might overflow.
// To prevent this port A of the FIFO will be forced into reset when port B is in reset.
    prt_dp_lib_rst
    RST_INST
    (
        .SRC_RST_IN    (B_RST_IN),
        .SRC_CLK_IN    (B_CLK_IN),
        .DST_CLK_IN    (A_CLK_IN),
        .DST_RST_OUT   (aclk_fifo.rst)
    );

// Inputs
    assign aclk_msg.som = A_MSG_SNK_IF.som;
    assign aclk_msg.eom = A_MSG_SNK_IF.eom;
    assign aclk_msg.dat = A_MSG_SNK_IF.dat;
    assign aclk_msg.vld = A_MSG_SNK_IF.vld;

// FIFO
    prt_dp_lib_fifo_dc
    #(
        .P_VENDOR           (P_VENDOR),
        .P_MODE             ("burst"),      // "single" or "burst"
        .P_RAM_STYLE        ("distributed"),    // "distributed" or "block"
        .P_ADR_WIDTH        (P_FIFO_ADR),
        .P_DAT_WIDTH        (P_FIFO_DAT)
    )
    FIFO_INST
    (
        .A_RST_IN      (aclk_fifo.rst),        // Reset
        .B_RST_IN      (B_RST_IN),
        .A_CLK_IN      (A_CLK_IN),             // Clock
        .B_CLK_IN      (B_CLK_IN),
        .A_CKE_IN      (1'b1),                 // Clock enable
        .B_CKE_IN      (1'b1),

        // Input (A)
        .A_CLR_IN      (1'b0),                 // Clear
        .A_WR_IN       (aclk_fifo.wr),         // Write
        .A_DAT_IN      (aclk_fifo.din),        // Write data

        // Output (B)
        .B_CLR_IN      (1'b0),                 // Clear
        .B_RD_IN       (bclk_fifo.rd),         // Read
        .B_DAT_OUT     (bclk_fifo.dout),       // Read data
        .B_DE_OUT      (bclk_fifo.de),         // Data enable

        // Status (A)
        .A_WRDS_OUT    (aclk_fifo.wrds),       // Used words
        .A_FL_OUT      (aclk_fifo.fl),         // Full
        .A_EP_OUT      (aclk_fifo.ep),         // Empty

        // Status (B)
        .B_WRDS_OUT    (bclk_fifo.wrds),      // Used words
        .B_FL_OUT      (bclk_fifo.fl),        // Full
        .B_EP_OUT      (bclk_fifo.ep)         // Empty
    );

// Write
    assign aclk_fifo.wr = aclk_msg.vld;

// Write data
    assign aclk_fifo.din = {aclk_msg.som, aclk_msg.eom, aclk_msg.dat};

// Read
    assign bclk_fifo.rd = 1;

// Message source
    assign {bclk_msg.som, bclk_msg.eom, bclk_msg.dat} = bclk_fifo.dout;
    assign bclk_msg.vld = bclk_fifo.de;

// Outputs
    assign B_MSG_SRC_IF.som = bclk_msg.som;
    assign B_MSG_SRC_IF.eom = bclk_msg.eom;
    assign B_MSG_SRC_IF.dat = bclk_msg.dat;
    assign B_MSG_SRC_IF.vld = bclk_msg.vld;

/*
    Assertions
*/

// synthesis translate_off

// FIFO full
initial
begin
    forever
    begin
        @(posedge A_CLK_IN);
        if (!(A_RST_IN || B_RST_IN))
        begin
            assert (!aclk_fifo.fl) else
            $error ("FIFO is full\n");
        end
    end
end
// synthesis translate_on

endmodule

`default_nettype wire
