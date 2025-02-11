/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Local Bus Mux
    (c) 2021 - 2025 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Added downstream port 8
    v1.2 - Fixed issue with Parretto RISC-V
    v1.3 - Added downstream port 9
    v1.4 - Added downstream port 10
    v1.5 - Introduced configurable downstream ports

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
     prt_dp_lb_if.lb_out           LB_DWN_IF[P_PORTS]
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
lb_dwn_struct clk_dwn[P_PORTS];

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

// Loop over all ports
generate 
     for (i = 0; i < P_PORTS; i++)
     begin : gen_dwn

          // Select
          always_comb
          begin
               if (clk_up.adr[16+:$clog2(P_PORTS)] == i)
                    clk_dwn[i].sel = 1;
               else
                    clk_dwn[i].sel = 0;
          end

          // Address
          assign clk_dwn[i].adr = clk_up.adr[0+:$size(clk_dwn[i].adr)];

          // Data out
          assign clk_dwn[i].dout = clk_up.din;

          // Write
          always_comb
          begin
               if (clk_dwn[i].sel && clk_up.wr)
                    clk_dwn[i].wr = 1;
               else
                    clk_dwn[i].wr = 0;
          end

          // Read
          always_comb
          begin
               if (clk_dwn[i].sel && clk_up.rd)
                    clk_dwn[i].rd = 1;
               else
                    clk_dwn[i].rd = 0;
          end
     end
endgenerate

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
generate
     for (i = 0; i < P_PORTS; i++)
     begin : gen_lb_dwn_if
          assign LB_DWN_IF[i].adr = clk_dwn[i].adr;
          assign LB_DWN_IF[i].din = clk_dwn[i].dout; // For the out port the data directions are swapped
          assign LB_DWN_IF[i].wr = clk_dwn[i].wr;
          assign LB_DWN_IF[i].rd = clk_dwn[i].rd;
          assign clk_dwn[i].din = LB_DWN_IF[i].dout; // For the outport the data directions are swapped
          assign clk_dwn[i].vld = LB_DWN_IF[i].vld; 
     end
endgenerate

     assign LB_UP_IF.dout = clk_up.dout;
     assign LB_UP_IF.vld = clk_up.vld;

endmodule

`default_nettype wire

