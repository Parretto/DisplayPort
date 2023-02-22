/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Scaler kernel
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

module prt_scaler_krnl
#(
    parameter                               P_PPC = 4,          // Pixels per clock
    parameter                               P_BPC = 8           // Bits per component
)
(
    // Reset and clock
    input wire                              RST_IN,             // Reset
    input wire                              CLK_IN,             // Clock

    // Agent
    input wire                              AGNT_DE_IN,         // Data enable

    // Coefficients
    input wire [31:0]                       COEF_P0_IN,         // Pixel 0
    input wire [31:0]                       COEF_P1_IN,         // Pixel 1
    input wire [31:0]                       COEF_P2_IN,         // Pixel 2
    input wire [31:0]                       COEF_P3_IN,         // PIxel 3

    // Mux
    input wire [(16*4)-1:0]                 MUX_SEL_IN,         // Select

    // Sliding window
    input wire    [(5 * P_BPC)-1:0]         SLW_DAT0_IN,        // Data line 0
    input wire    [(5 * P_BPC)-1:0]         SLW_DAT1_IN,        // Data line 1

    // Video out
    output wire   [(P_PPC * P_BPC)-1:0]     VID_DAT_OUT,        // Data
    output wire                             VID_DE_OUT          // Data enable
);

// Structures
typedef struct {
    logic [P_BPC-1:0]       dat[0:1][0:4];
} slw_struct;

typedef struct {
    logic [3:0]             sel;
    logic [P_BPC-1:0]       dat;
} mux_struct;

typedef struct {
    logic [P_BPC-1:0]       c[0:3];
    logic [P_BPC-1:0]       dat;
} mac_struct;

// Signals
slw_struct              clk_slw;
mux_struct              clk_mux[0:15];
mac_struct              clk_mac[0:3];
logic [4:0]             clk_de;

genvar i;

// Logic

// Sliding window
    assign clk_slw.dat[0][0] = SLW_DAT0_IN[(0*P_BPC)+:P_BPC];
    assign clk_slw.dat[0][1] = SLW_DAT0_IN[(1*P_BPC)+:P_BPC];
    assign clk_slw.dat[0][2] = SLW_DAT0_IN[(2*P_BPC)+:P_BPC];
    assign clk_slw.dat[0][3] = SLW_DAT0_IN[(3*P_BPC)+:P_BPC];
    assign clk_slw.dat[0][4] = SLW_DAT0_IN[(4*P_BPC)+:P_BPC];
    assign clk_slw.dat[1][0] = SLW_DAT1_IN[(0*P_BPC)+:P_BPC];
    assign clk_slw.dat[1][1] = SLW_DAT1_IN[(1*P_BPC)+:P_BPC];
    assign clk_slw.dat[1][2] = SLW_DAT1_IN[(2*P_BPC)+:P_BPC];
    assign clk_slw.dat[1][3] = SLW_DAT1_IN[(3*P_BPC)+:P_BPC];
    assign clk_slw.dat[1][4] = SLW_DAT1_IN[(4*P_BPC)+:P_BPC];

// MUX
generate    
    for (i = 0; i < 16; i++)
    begin : gen_mux

        // Select
        assign clk_mux[i].sel = MUX_SEL_IN[(i*4)+:4];

        prt_scaler_krnl_mux
        #(
            // System
            .P_BPC          (P_BPC)           // Bits per component
        )
        MUX_INST
        (
            // Reset and clock
            .CLK_IN         (CLK_IN),

            // Select
            .SEL_IN         (clk_mux[i].sel),

            // Data in
            .A_DAT_IN       (clk_slw.dat[0][0]),
            .B_DAT_IN       (clk_slw.dat[0][1]),
            .C_DAT_IN       (clk_slw.dat[0][2]),
            .D_DAT_IN       (clk_slw.dat[0][3]),
            .E_DAT_IN       (clk_slw.dat[0][4]),
            .F_DAT_IN       (clk_slw.dat[1][0]),
            .G_DAT_IN       (clk_slw.dat[1][1]),
            .H_DAT_IN       (clk_slw.dat[1][2]),
            .I_DAT_IN       (clk_slw.dat[1][3]),
            .J_DAT_IN       (clk_slw.dat[1][4]),

            // Data out
            .DAT_OUT        (clk_mux[i].dat)
        );
    end
endgenerate

// Pixel 0
assign clk_mac[0].c[0] = COEF_P0_IN[(0*8)+:8];
assign clk_mac[0].c[1] = COEF_P0_IN[(1*8)+:8];
assign clk_mac[0].c[2] = COEF_P0_IN[(2*8)+:8];
assign clk_mac[0].c[3] = COEF_P0_IN[(3*8)+:8];

// Pixel 1
assign clk_mac[1].c[0] = COEF_P1_IN[(0*8)+:8];
assign clk_mac[1].c[1] = COEF_P1_IN[(1*8)+:8];
assign clk_mac[1].c[2] = COEF_P1_IN[(2*8)+:8];
assign clk_mac[1].c[3] = COEF_P1_IN[(3*8)+:8];

// Pixel 2
assign clk_mac[2].c[0] = COEF_P2_IN[(0*8)+:8];
assign clk_mac[2].c[1] = COEF_P2_IN[(1*8)+:8];
assign clk_mac[2].c[2] = COEF_P2_IN[(2*8)+:8];
assign clk_mac[2].c[3] = COEF_P2_IN[(3*8)+:8];

// Pixel 3
assign clk_mac[3].c[0] = COEF_P3_IN[(0*8)+:8];
assign clk_mac[3].c[1] = COEF_P3_IN[(1*8)+:8];
assign clk_mac[3].c[2] = COEF_P3_IN[(2*8)+:8];
assign clk_mac[3].c[3] = COEF_P3_IN[(3*8)+:8];

// MAC
generate    
    for (i = 0; i < 4; i++)
    begin : gen_mac
        prt_scaler_krnl_mac
        #(
            .P_BPC          (P_BPC)
        )
        MAC_INST
        (
            // Clock
            .CLK_IN         (CLK_IN),

            // Coefficients
            .C0_IN          (clk_mac[i].c[0]),  
            .C1_IN          (clk_mac[i].c[1]),  
            .C2_IN          (clk_mac[i].c[2]),  
            .C3_IN          (clk_mac[i].c[3]),  

            // Pixels in
            .P0_IN          (clk_mux[(i*4)].dat),  
            .P1_IN          (clk_mux[(i*4)+1].dat),  
            .P2_IN          (clk_mux[(i*4)+2].dat),  
            .P3_IN          (clk_mux[(i*4)+3].dat),  

            // Pixel out
            .P_OUT          (clk_mac[i].dat)  
        );
    end
endgenerate

// Data enable
    always_ff @ (posedge CLK_IN)
    begin
        for (int i = 0; i < $size(clk_de); i++)
        begin   
            if (i == 0)
                clk_de[i] <= AGNT_DE_IN;
            else    
                clk_de[i] <= clk_de[i-1];
        end
    end

// Outputs   
    assign VID_DAT_OUT = {clk_mac[3].dat, clk_mac[2].dat, clk_mac[1].dat, clk_mac[0].dat};
    assign VID_DE_OUT = clk_de[$high(clk_de)];

endmodule

`default_nettype wire
