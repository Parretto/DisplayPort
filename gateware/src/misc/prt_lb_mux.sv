/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Local Bus Mux
    (c) 2021 - 2023 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Added downstream port 8
    v1.2 - Fixed issue with Parretto RISC-V
    v1.3 - Added downstream port 9
    v1.4 - Added downstream port 10

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
module prt_lb_mux
#(
     parameter P_PORTS = 10
)
(
     // Reset and clock
     input wire                    RST_IN,        // Reset
     input wire                    CLK_IN,        // Clock

     // Up stream
     prt_dp_lb_if.lb_in            LB_UP_IF,

     // Down stream
     prt_dp_lb_if.lb_out           LB_DWN_IF0,
     prt_dp_lb_if.lb_out           LB_DWN_IF1,
     prt_dp_lb_if.lb_out           LB_DWN_IF2,
     prt_dp_lb_if.lb_out           LB_DWN_IF3,
     prt_dp_lb_if.lb_out           LB_DWN_IF4,
     prt_dp_lb_if.lb_out           LB_DWN_IF5,
     prt_dp_lb_if.lb_out           LB_DWN_IF6,
     prt_dp_lb_if.lb_out           LB_DWN_IF7,
     prt_dp_lb_if.lb_out           LB_DWN_IF8,
     prt_dp_lb_if.lb_out           LB_DWN_IF9,
     prt_dp_lb_if.lb_out           LB_DWN_IF10
);

// Parameters
typedef struct {
     logic   [21:0]      adr;
     logic               wr;
     logic               rd;
     logic   [31:0]      din;
     logic   [31:0]      dout;
     logic               vld;
} lb_up_struct;

typedef struct {
     logic               sel;     
     logic   [15:0]      adr;
     logic               wr;
     logic               rd;
     logic   [31:0]      din;
     logic   [31:0]      dout;
     logic               vld;
} lb_dwn_struct;

// Signals
lb_up_struct clk_up;
lb_dwn_struct clk_dwn[0:P_PORTS-1];

genvar i;

// Inputs
// The upstream inputs are registered
     always_ff @ (posedge CLK_IN)
     begin
          clk_up.adr <= LB_UP_IF.adr;
          clk_up.wr <= LB_UP_IF.wr;
          clk_up.rd <= LB_UP_IF.rd;
          clk_up.din <= LB_UP_IF.din;
     end

// Select
     always_comb
     begin
          for (int i = 0; i < P_PORTS; i++)
          begin
               if (clk_up.adr[16+:$clog2(P_PORTS)] == i)
                    clk_dwn[i].sel = 1;
               else
                    clk_dwn[i].sel = 0;
          end
     end

// Address
generate
     for (i = 0; i < P_PORTS; i++)
     begin : gen_adr
          assign clk_dwn[i].adr = clk_up.adr[0+:$size(clk_dwn[i].adr)];
     end
endgenerate

// Data out
generate
     for (i = 0; i < P_PORTS; i++)
     begin : gen_dout
          assign clk_dwn[i].dout = clk_up.din;
     end
endgenerate

// Write
     always_comb
     begin
          for (int i = 0; i < P_PORTS; i++)
          begin
               if (clk_dwn[i].sel && clk_up.wr)
                    clk_dwn[i].wr = 1;
               else
                    clk_dwn[i].wr = 0;
          end
     end

// Read
     always_comb
     begin
          for (int i = 0; i < P_PORTS; i++)
          begin
               if (clk_dwn[i].sel && clk_up.rd)
                    clk_dwn[i].rd = 1;
               else
                    clk_dwn[i].rd = 0;
          end
     end

// Upstream data
// The upstream data is registered
     always_ff @ (posedge CLK_IN)
     begin
          // Default
          clk_up.vld <= 0;

          for (int i = 0; i < P_PORTS; i++)
          begin
               if (clk_dwn[i].vld)
               begin
                    clk_up.dout <= clk_dwn[i].din;
                    clk_up.vld <= 1;
               end
          end
     end     

// Outputs
     assign LB_DWN_IF0.adr = clk_dwn[0].adr;
     assign LB_DWN_IF0.din = clk_dwn[0].dout; // For the out port the data directions are swapped
     assign LB_DWN_IF0.wr = clk_dwn[0].wr;
     assign LB_DWN_IF0.rd = clk_dwn[0].rd;
     assign clk_dwn[0].din = LB_DWN_IF0.dout; // For the outport the data directions are swapped
     assign clk_dwn[0].vld = LB_DWN_IF0.vld; 

     assign LB_DWN_IF1.adr = clk_dwn[1].adr;
     assign LB_DWN_IF1.din = clk_dwn[1].dout; // For the out port the data directions are swapped
     assign LB_DWN_IF1.wr = clk_dwn[1].wr;
     assign LB_DWN_IF1.rd = clk_dwn[1].rd;
     assign clk_dwn[1].din = LB_DWN_IF1.dout; // For the outport the data directions are swapped
     assign clk_dwn[1].vld = LB_DWN_IF1.vld; 

     assign LB_DWN_IF2.adr = clk_dwn[2].adr;
     assign LB_DWN_IF2.din = clk_dwn[2].dout; // For the out port the data directions are swapped
     assign LB_DWN_IF2.wr = clk_dwn[2].wr;
     assign LB_DWN_IF2.rd = clk_dwn[2].rd;
     assign clk_dwn[2].din = LB_DWN_IF2.dout; // For the outport the data directions are swapped
     assign clk_dwn[2].vld = LB_DWN_IF2.vld; 

     assign LB_DWN_IF3.adr = clk_dwn[3].adr;
     assign LB_DWN_IF3.din = clk_dwn[3].dout; // For the out port the data directions are swapped
     assign LB_DWN_IF3.wr = clk_dwn[3].wr;
     assign LB_DWN_IF3.rd = clk_dwn[3].rd;
     assign clk_dwn[3].din = LB_DWN_IF3.dout; // For the outport the data directions are swapped
     assign clk_dwn[3].vld = LB_DWN_IF3.vld; 

     assign LB_DWN_IF4.adr = clk_dwn[4].adr;
     assign LB_DWN_IF4.din = clk_dwn[4].dout; // For the out port the data directions are swapped
     assign LB_DWN_IF4.wr = clk_dwn[4].wr;
     assign LB_DWN_IF4.rd = clk_dwn[4].rd;
     assign clk_dwn[4].din = LB_DWN_IF4.dout; // For the outport the data directions are swapped
     assign clk_dwn[4].vld = LB_DWN_IF4.vld; 

     assign LB_DWN_IF5.adr = clk_dwn[5].adr;
     assign LB_DWN_IF5.din = clk_dwn[5].dout; // For the out port the data directions are swapped
     assign LB_DWN_IF5.wr = clk_dwn[5].wr;
     assign LB_DWN_IF5.rd = clk_dwn[5].rd;
     assign clk_dwn[5].din = LB_DWN_IF5.dout; // For the outport the data directions are swapped
     assign clk_dwn[5].vld = LB_DWN_IF5.vld; 

     assign LB_DWN_IF6.adr = clk_dwn[6].adr;
     assign LB_DWN_IF6.din = clk_dwn[6].dout; // For the out port the data directions are swapped
     assign LB_DWN_IF6.wr = clk_dwn[6].wr;
     assign LB_DWN_IF6.rd = clk_dwn[6].rd;
     assign clk_dwn[6].din = LB_DWN_IF6.dout; // For the outport the data directions are swapped
     assign clk_dwn[6].vld = LB_DWN_IF6.vld; 

     assign LB_DWN_IF7.adr = clk_dwn[7].adr;
     assign LB_DWN_IF7.din = clk_dwn[7].dout; // For the out port the data directions are swapped
     assign LB_DWN_IF7.wr = clk_dwn[7].wr;
     assign LB_DWN_IF7.rd = clk_dwn[7].rd;
     assign clk_dwn[7].din = LB_DWN_IF7.dout; // For the outport the data directions are swapped
     assign clk_dwn[7].vld = LB_DWN_IF7.vld; 

     assign LB_DWN_IF8.adr = clk_dwn[8].adr;
     assign LB_DWN_IF8.din = clk_dwn[8].dout; // For the out port the data directions are swapped
     assign LB_DWN_IF8.wr = clk_dwn[8].wr;
     assign LB_DWN_IF8.rd = clk_dwn[8].rd;
     assign clk_dwn[8].din = LB_DWN_IF8.dout; // For the outport the data directions are swapped
     assign clk_dwn[8].vld = LB_DWN_IF8.vld; 

     assign LB_DWN_IF9.adr = clk_dwn[9].adr;
     assign LB_DWN_IF9.din = clk_dwn[9].dout; // For the out port the data directions are swapped
     assign LB_DWN_IF9.wr = clk_dwn[9].wr;
     assign LB_DWN_IF9.rd = clk_dwn[9].rd;
     assign clk_dwn[9].din = LB_DWN_IF9.dout; // For the outport the data directions are swapped
     assign clk_dwn[9].vld = LB_DWN_IF9.vld; 

     assign LB_DWN_IF10.adr = clk_dwn[10].adr;
     assign LB_DWN_IF10.din = clk_dwn[10].dout; // For the out port the data directions are swapped
     assign LB_DWN_IF10.wr = clk_dwn[10].wr;
     assign LB_DWN_IF10.rd = clk_dwn[10].rd;
     assign clk_dwn[10].din = LB_DWN_IF10.dout; // For the outport the data directions are swapped
     assign clk_dwn[10].vld = LB_DWN_IF10.vld; 

     assign LB_UP_IF.dout = clk_up.dout;
     assign LB_UP_IF.vld = clk_up.vld;

endmodule

`default_nettype wire

