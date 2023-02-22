/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Scaler line buffer
    (c) 2022, 2023 by Parretto B.V.

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

module prt_scaler_lbf
#(
     parameter                               P_VENDOR = "none",  // Vendor "xilinx" or "lattice"
     parameter                               P_PPC = 4,          // Pixels per clock
     parameter                               P_BPC = 8           // Bits per component
)
(
    // Reset and clock
    input wire                              RST_IN,             // Reset
    input wire                              CLK_IN,             // Clock

    // Control
    input wire                              CTL_RUN_IN,         // Run
    input wire                              CTL_FS_IN,          // Frame start

	// Timing generator
    input wire                              TG_VS_IN,           // Vsync
    input wire                              TG_HS_IN,           // Hsync
    input wire                              TG_DE_IN,           // Data enable
	output wire 							TG_RUN_OUT,			// Run

    // Line buffer
    output wire                             LBF_RDY_OUT,        // Ready

    // Video in
    input wire   [(P_PPC * P_BPC)-1:0]      VID_DAT_IN,         // Data
    input wire                              VID_DE_IN,          // Data enable

    // Video out
    output wire                             VID_VS_OUT,         // Vsync
    output wire                             VID_HS_OUT,         // Hsync
    output wire [(P_PPC * P_BPC)-1:0]       VID_DAT_OUT,        // Data 
    output wire                             VID_DE_OUT          // Data enable
);

// Parameters
localparam P_FIFO_WRDS  = 2048;                 
localparam P_FIFO_ADR   = $clog2(P_FIFO_WRDS);
localparam P_FIFO_DAT   = P_PPC * P_BPC;
localparam P_FIFO_LVL   = P_FIFO_WRDS - 960;    // Level. At least a 3840 video line (960 words) needs to fit into the fifo.

// Structures
typedef struct {
    logic                           run;
    logic                           fs;
} ctl_struct;

typedef struct {
    logic [2:0]                     vs;
    logic [2:0]                     hs;
    logic [(P_PPC * P_BPC)-1:0]     dat;
    logic                           de;    
} vid_struct;

typedef struct {
    logic [P_FIFO_DAT-1:0]          din;
    logic                           wr_clr;
    logic                           wr;
    logic                           rd_clr;
    logic                           rd;
    logic [P_FIFO_DAT-1:0]          dout;
    logic                           de;
    logic [P_FIFO_ADR:0]            wrds;
    logic                           ep;
    logic                           fl;
    logic                           rdy;
} fifo_struct;

typedef struct {
    logic de;
    logic run;    
} tg_struct;

// Signals
ctl_struct               clk_ctl;
vid_struct               clk_vid;
fifo_struct              clk_fifo;
tg_struct                clk_tg;

// Logic

// Control
     always_ff @ (posedge RST_IN, posedge CLK_IN)
     begin
        // Reset
        if (RST_IN)
            clk_ctl.run <= 0;

        else
            clk_ctl.run <= CTL_RUN_IN;
     end

     always_ff @ (posedge CLK_IN)
     begin
          clk_ctl.fs <= CTL_FS_IN;
     end

// Video data and data enable
// This can be combinatorial. 
// The FIFO already has input registers
    assign clk_vid.dat = VID_DAT_IN;
    assign clk_vid.de = VID_DE_IN;

// Timing
     always_ff @ (posedge CLK_IN)
     begin
        clk_tg.de <= TG_DE_IN;
     end

// FIFO control
    assign clk_fifo.wr_clr = clk_ctl.fs;
    assign clk_fifo.rd_clr = clk_ctl.fs;
    assign clk_fifo.din = clk_vid.dat;
    assign clk_fifo.wr = clk_vid.de;
    assign clk_fifo.rd = clk_tg.de;

// FIFO
    prt_scaler_lib_fifo_sc
    #(
        .P_VENDOR      (P_VENDOR),
        .P_MODE        ("burst"),          // "single" or "burst"
        .P_RAM_STYLE   ("block"),          // "distributed" or "block"
        .P_ADR_WIDTH   (P_FIFO_ADR),
        .P_DAT_WIDTH   (P_FIFO_DAT)
    )
    FIFO_INST
    (
        // Clocks and reset
        .RST_IN        (~clk_ctl.run),         // Reset
        .CLK_IN        (CLK_IN),               // Clock

        // Write
        .WR_EN_IN      (1'b1),                 // Write enable
        .WR_CLR_IN     (clk_fifo.wr_clr),      // Write clear
        .WR_IN         (clk_fifo.wr),          // Write in
        .DAT_IN        (clk_fifo.din),         // Write data

        // Read
        .RD_EN_IN      (1'b1),                 // Read enable in
        .RD_CLR_IN     (clk_fifo.rd_clr),      // Read clear
        .RD_IN         (clk_fifo.rd),          // Read in
        .DAT_OUT       (clk_fifo.dout),        // Data out
        .DE_OUT        (clk_fifo.de),          // Data enable

        // Status
        .WRDS_OUT      (clk_fifo.wrds),        // Used words
        .EP_OUT        (clk_fifo.ep),          // Empty
        .FL_OUT        (clk_fifo.fl)           // Full
    );

// FIFO ready
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_ctl.run)
        begin
            if (clk_fifo.wrds < P_FIFO_LVL)
                clk_fifo.rdy <= 1;
            else
                clk_fifo.rdy <= 0;
        end

        // Idle
        else
            clk_fifo.rdy <= 0;
    end

// Timing run
     always_ff @ (posedge CLK_IN)
     begin
        // Run
        if (clk_ctl.run)
        begin
            // Set
            if (!clk_fifo.ep)
                clk_tg.run <= 1;
        end

        else
            clk_tg.run <= 0;
     end

// The video data path has three clocks latency.
// The vsync and hsync are delayed to compensate for the delay.
	always_ff @ (posedge CLK_IN)
	begin
        clk_vid.vs <= {clk_vid.vs[0+:$size(clk_vid.vs)-1], TG_VS_IN};
        clk_vid.hs <= {clk_vid.hs[0+:$size(clk_vid.hs)-1], TG_HS_IN};
	end

// Outputs
    assign LBF_RDY_OUT = clk_fifo.rdy;
    assign TG_RUN_OUT = clk_tg.run;
    assign VID_VS_OUT = clk_vid.vs[$high(clk_vid.vs)];
    assign VID_HS_OUT = clk_vid.hs[$high(clk_vid.hs)];
    assign VID_DAT_OUT = clk_fifo.dout;
    assign VID_DE_OUT = clk_fifo.de;

endmodule

`default_nettype wire
