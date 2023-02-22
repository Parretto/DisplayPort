/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Scaler sliding window 
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
    solely for internal business purstepes for the term and conditions of the License. 
    You are also allowed to create Modifications for internal business purstepes, but explicitly only under the conditions of art. 3.2.
    You are, however, obliged to pay the License Fees to Parretto for the use of the IP-core, or any Modification, in, or embodied in, 
    a physical or non-tangible product or service that has substantial commercial, industrial or non-consumer uses. 
*/

`default_nettype none

module prt_scaler_slw
#(
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

    // Line store
    input wire                              LST_RDY_IN,         // Ready
    input wire [(P_PPC * P_BPC)-1:0]        LST_DAT0_IN,        // Data line 0
    input wire [(P_PPC * P_BPC)-1:0]        LST_DAT1_IN,        // Data line 1
    output wire [3:0]                       LST_RD0_OUT,        // Read line 0
    output wire [3:0]                       LST_RD1_OUT,        // Read line 1
    output wire                             LST_LRST_OUT,       // Restore line
    output wire                             LST_LNXT_OUT,       // Next line

    // Sliding window
    input wire                              SLW_LRST_IN,        // Restore line
    input wire                              SLW_LNXT_IN,        // Next line
    input wire [1:0]                        SLW_STEP_IN,        // Step
    output wire [(5*P_BPC)-1:0]             SLW_DAT0_OUT,       // Data line 0
    output wire [(5*P_BPC)-1:0]             SLW_DAT1_OUT,       // Data line 1
    output wire                             SLW_RDY_OUT         // Ready
);

// Parameters
localparam P_LST_LAT = 5;   // Line store read latency

// Structures
typedef struct {
    logic                       run;
    logic                       fs;
} ctl_struct;

typedef struct {
    logic                       rdy;
    logic                       lrst;
    logic                       lnxt;
    logic [P_BPC-1:0]           dat[0:1][0:3];
    logic [3:0]                 rd[0:1];
} lst_struct;

typedef struct {
    logic [2:0]                 sel;
    logic                       wr;
    logic [P_BPC-1:0]           din[0:6];
    logic [P_BPC-1:0]           dout;
} mux_struct;

typedef struct {
    logic [P_LST_LAT:0]         rdy;
    logic [1:0]                 step;
    logic [P_BPC-1:0]           dat[0:1];
    logic [2:0]                 state;
    logic [23:0]                lut;
    logic [23:0]                lut_del[0:P_LST_LAT-1];
} slw_struct;

// Signals
ctl_struct              clk_ctl;
lst_struct              clk_lst;
mux_struct              clk_mux[0:1][0:4];
slw_struct              clk_slw;

genvar i, j;

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

// Inputs
    always_ff @ (posedge CLK_IN)
    begin
        clk_lst.rdy <= LST_RDY_IN;
        clk_lst.lrst <= SLW_LRST_IN;
        clk_lst.lnxt <= SLW_LNXT_IN;
        clk_slw.step <= SLW_STEP_IN;
    end

generate    
    for (i = 0; i < 4; i++)
    begin : gen_lst_dat
        assign clk_lst.dat[0][i] = LST_DAT0_IN[(i*P_BPC)+:P_BPC];
        assign clk_lst.dat[1][i] = LST_DAT1_IN[(i*P_BPC)+:P_BPC];
    end
endgenerate

// Muxes

generate
    for (j = 0; j < 2; j++)
    begin : gen_mux_j
    // Mux 0
        assign clk_mux[j][0].din[0] = clk_lst.dat[j][0];
        assign clk_mux[j][0].din[1] = clk_lst.dat[j][1];
        assign clk_mux[j][0].din[2] = clk_lst.dat[j][2];
        assign clk_mux[j][0].din[3] = clk_lst.dat[j][3];
        assign clk_mux[j][0].din[4] = clk_mux[j][1].dout;
        assign clk_mux[j][0].din[5] = clk_mux[j][2].dout;
        assign clk_mux[j][0].din[6] = clk_mux[j][3].dout;

    // Mux 1
        assign clk_mux[j][1].din[0] = clk_lst.dat[j][0];
        assign clk_mux[j][1].din[1] = clk_lst.dat[j][1];
        assign clk_mux[j][1].din[2] = clk_lst.dat[j][2];
        assign clk_mux[j][1].din[3] = clk_lst.dat[j][3];
        assign clk_mux[j][1].din[4] = clk_mux[j][2].dout;
        assign clk_mux[j][1].din[5] = clk_mux[j][3].dout;
        assign clk_mux[j][1].din[6] = clk_mux[j][4].dout;

    // Mux 2
        assign clk_mux[j][2].din[0] = clk_lst.dat[j][0];
        assign clk_mux[j][2].din[1] = clk_lst.dat[j][1];
        assign clk_mux[j][2].din[2] = clk_lst.dat[j][2];
        assign clk_mux[j][2].din[3] = clk_lst.dat[j][3];
        assign clk_mux[j][2].din[4] = clk_mux[j][3].dout;
        assign clk_mux[j][2].din[5] = clk_mux[j][4].dout;
        assign clk_mux[j][2].din[6] = 0;

    // Mux 3
        assign clk_mux[j][3].din[0] = clk_lst.dat[j][0];
        assign clk_mux[j][3].din[1] = clk_lst.dat[j][1];
        assign clk_mux[j][3].din[2] = clk_lst.dat[j][2];
        assign clk_mux[j][3].din[3] = clk_lst.dat[j][3];
        assign clk_mux[j][3].din[4] = clk_mux[j][4].dout;
        assign clk_mux[j][3].din[5] = 0;
        assign clk_mux[j][3].din[6] = 0;

    // Mux 4
        assign clk_mux[j][4].din[0] = clk_lst.dat[j][0];
        assign clk_mux[j][4].din[1] = clk_lst.dat[j][1];
        assign clk_mux[j][4].din[2] = clk_lst.dat[j][2];
        assign clk_mux[j][4].din[3] = clk_lst.dat[j][3];
        assign clk_mux[j][4].din[4] = 0;
        assign clk_mux[j][4].din[5] = 0;
        assign clk_mux[j][4].din[6] = 0;

        for (i = 0; i < 5; i++)
        begin : gen_mux_i
            prt_scaler_slw_mux
            #(
                .P_BPC (P_BPC)
            )
            MUX_INST
            (
                // Reset and clock
                .CLK_IN     (CLK_IN),

                // Control
                .SEL_IN     (clk_mux[j][i].sel),
                .WR_IN      (clk_mux[j][i].wr),
                
                // Data in
                .A_DAT_IN   (clk_mux[j][i].din[0]),
                .B_DAT_IN   (clk_mux[j][i].din[1]),
                .C_DAT_IN   (clk_mux[j][i].din[2]),
                .D_DAT_IN   (clk_mux[j][i].din[3]),
                .E_DAT_IN   (clk_mux[j][i].din[4]),
                .F_DAT_IN   (clk_mux[j][i].din[5]),
                .G_DAT_IN   (clk_mux[j][i].din[6]),

                // Data out
                .DAT_OUT    (clk_mux[j][i].dout)
            );
        end
    end
endgenerate

// Ready
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_ctl.run)
        begin
            // Clear
            if (clk_ctl.fs || clk_lst.lrst || clk_lst.lnxt)
                clk_slw.rdy <= 0;
            
            // Set
            else if (clk_slw.state == 'd2)
                clk_slw.rdy[0] <= 1;

            // Compensate for the list store read latency
            for (int i = 1; i < $size (clk_slw.rdy); i++)
                clk_slw.rdy[i] <= clk_slw.rdy[i-1];
        end

        // Idle
        else
            clk_slw.rdy <= 0;
    end

// State and lookup
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_ctl.run)
        begin
            // Default
            clk_slw.lut <= 0;

            // Clear
            if (clk_ctl.fs || clk_lst.lrst || clk_lst.lnxt)
                clk_slw.state <= 'd0;

            // Ready
            else if (clk_lst.rdy)
            begin
                case ({clk_slw.state, clk_slw.step})

                    // State 0
                    {3'd0, 2'd0} :  
                    begin
                        clk_slw.lut <= {3'd0, 3'd1, 3'd2, 3'd3, 3'd0, 5'b11110, 4'b1111};
                        clk_slw.state <= 'd1;
                    end

                    // State 1
                    {3'd1, 2'd0} :
                    begin
                        clk_slw.lut <= {3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 5'b00001, 4'b1000};
                        clk_slw.state <= 'd2;
                    end

                    // State 2 - step 1
                    {3'd2, 2'd1} :
                    begin
                        clk_slw.lut <= {3'd4, 3'd4, 3'd4, 3'd4, 3'd1, 5'b11111, 4'b0100};
                        clk_slw.state <= 'd3;
                    end

                    // State 2 - step 2
                    {3'd2, 2'd2} :
                    begin
                        clk_slw.lut <= {3'd5, 3'd5, 3'd5, 3'd1, 3'd2, 5'b11111, 4'b0110};
                        clk_slw.state <= 'd4;
                    end

                    // State 2 - step 3
                    {3'd2, 2'd3} :
                    begin
                        clk_slw.lut <= {3'd6, 3'd6, 3'd1, 3'd2, 3'd3, 5'b11111, 4'b0111};
                        clk_slw.state <= 'd5;
                    end

                    // State 3 - step 1
                    {3'd3, 2'd1} :
                    begin
                        clk_slw.lut <= {3'd4, 3'd4, 3'd4, 3'd4, 3'd2, 5'b11111, 4'b0010};
                        clk_slw.state <= 'd4;
                    end

                    // State 3 - step 2
                    {3'd3, 2'd2} :
                    begin
                        clk_slw.lut <= {3'd5, 3'd5, 3'd5, 3'd2, 3'd3, 5'b11111, 4'b0011};
                        clk_slw.state <= 'd5;
                    end

                    // State 3 - step 3
                    {3'd3, 2'd3} :
                    begin
                        clk_slw.lut <= {3'd6, 3'd6, 3'd2, 3'd3, 3'd0, 5'b11111, 4'b1011};
                        clk_slw.state <= 'd2;
                    end

                    // State 4 - step 1
                    {3'd4, 2'd1} :
                    begin
                        clk_slw.lut <= {3'd4, 3'd4, 3'd4, 3'd4, 3'd3, 5'b11111, 4'b0001};
                        clk_slw.state <= 'd5;
                    end

                    // State 4 - step 2
                    {3'd4, 2'd2} :
                    begin
                        clk_slw.lut <= {3'd5, 3'd5, 3'd5, 3'd3, 3'd0, 5'b11111, 4'b1001};
                        clk_slw.state <= 'd2;
                    end

                    // State 4 - step 3
                    {3'd4, 2'd3} :
                    begin
                        clk_slw.lut <= {3'd6, 3'd6, 3'd3, 3'd0, 3'd1, 5'b11111, 4'b1101};
                        clk_slw.state <= 'd3;
                    end

                    // State 5 - step 1
                    {3'd5, 2'd1} :
                    begin
                        clk_slw.lut <= {3'd4, 3'd4, 3'd4, 3'd4, 3'd0, 5'b11111, 4'b1000};
                        clk_slw.state <= 'd2;
                    end

                    // State 5 - step 2
                    {3'd5, 2'd2} :
                    begin
                        clk_slw.lut <= {3'd5, 3'd5, 3'd5, 3'd0, 3'd1, 5'b11111, 4'b1100};
                        clk_slw.state <= 'd3;
                    end

                    // State 5 - step 3
                    {3'd5, 2'd3} :
                    begin
                        clk_slw.lut <= {3'd6, 3'd6, 3'd0, 3'd1, 3'd2, 5'b11111, 4'b1110};
                        clk_slw.state <= 'd4;
                    end

                    default : ;
                endcase
            end
        end 

        // Idle
        else
        begin
            clk_slw.state <= 'd0;
            clk_slw.lut <= 0;
        end
    end

// The MUX write and select signals needs to be delayed to match the line store read latency.
    always_ff @ (posedge CLK_IN)
    begin
        for (int i = 0; i < $size(clk_slw.lut_del); i++)
        begin   
            if (i == 0)
                clk_slw.lut_del[i] <= clk_slw.lut;
            else
                 clk_slw.lut_del[i] <= clk_slw.lut_del[i-1];
        end
    end

generate
    for (j = 0; j < 2; j++)
    begin : gen_decode
        assign {clk_mux[j][0].sel, clk_mux[j][1].sel, clk_mux[j][2].sel, clk_mux[j][3].sel, clk_mux[j][4].sel} = clk_slw.lut_del[$high(clk_slw.lut_del)][9+:15];
        assign {clk_mux[j][0].wr, clk_mux[j][1].wr, clk_mux[j][2].wr, clk_mux[j][3].wr, clk_mux[j][4].wr} = clk_slw.lut_del[$high(clk_slw.lut_del)][4+:5]; 
        assign {clk_lst.rd[j][0], clk_lst.rd[j][1] ,clk_lst.rd[j][2], clk_lst.rd[j][3]} = clk_slw.lut[0+:4];
    end
endgenerate

// Outputs
    assign SLW_RDY_OUT = clk_slw.rdy[$high(clk_slw.rdy)];
    assign LST_RD0_OUT = clk_lst.rd[0];
    assign LST_RD1_OUT = clk_lst.rd[1];
    assign LST_LRST_OUT = clk_lst.lrst;
    assign LST_LNXT_OUT = clk_lst.lnxt;

generate
    for (i = 0; i < 5; i++)
    begin : gen_slw_dat
        assign SLW_DAT0_OUT[(i*P_BPC)+:P_BPC] = clk_mux[0][i].dout;
        assign SLW_DAT1_OUT[(i*P_BPC)+:P_BPC] = clk_mux[1][i].dout;
    end
endgenerate

endmodule

`default_nettype wire
