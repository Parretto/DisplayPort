/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 

    APB to Local bus Adapter

    (c) 2024 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
*/

`default_nettype none

// Module
module prt_apb2lb
(
     // Reset and clock
     input wire                    RST_IN,        // Reset
     input wire                    CLK_IN,        // Clock

     // APB
     prt_apb_if.slv                APB_IF,

     // Local bus interface
     prt_lb_if.lb_out              LB_IF
);

// Parameters

// Structures
typedef struct {
     logic [31:0]   dout;
     logic          rdy;
} apb_struct;

typedef struct {
    logic   [7:0]   adr;
    logic           wr;
    logic           rd;
    logic   [31:0]  din;
    logic   [31:0]  dout;
} lb_struct;

// Signals
apb_struct     clk_apb;
lb_struct      clk_lb;

// Logic

// APB

// Read data
     assign clk_apb.dout = LB_IF.dout;

// Ready
     assign clk_apb.rdy = clk_lb.wr || LB_IF.vld;

// LB

// Address
     always_ff @ (posedge CLK_IN)
     begin
          clk_lb.adr <= APB_IF.paddr[2+:$size(clk_lb.adr)];
     end

// Write 
     always_ff @ (posedge CLK_IN)
     begin
          // Default
          clk_lb.wr <= 0;

          if (APB_IF.psel && APB_IF.pwrite && !APB_IF.penable)
               clk_lb.wr <= 1;
     end

// Read
     always_ff @ (posedge CLK_IN)
     begin
          // Default
          clk_lb.rd <= 0;

          if (APB_IF.psel && !APB_IF.pwrite && !APB_IF.penable)
               clk_lb.rd <= 1;
     end

// Write data
     always_ff @ (posedge CLK_IN)
     begin
          clk_lb.dout <= APB_IF.pwdata;
     end

// Outputs
     assign LB_IF.adr         = clk_lb.adr;
     assign LB_IF.wr          = clk_lb.wr;
     assign LB_IF.rd          = clk_lb.rd;
     assign LB_IF.din         = clk_lb.dout; // For the LB out the dout and din are swapped.

     assign APB_IF.prdata     = clk_apb.dout;
     assign APB_IF.pready     = clk_apb.rdy;
     assign APB_IF.pslverr    = 0;           // Not used

endmodule

`default_nettype wire
