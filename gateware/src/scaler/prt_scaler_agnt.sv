/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Scaler agent
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

module prt_scaler_agnt
#(
    parameter    P_COEF_MODE = 2,   // Coefficient mode width
    parameter    P_COEF_IDX = 2,    // Coefficient index width
    parameter    P_COEF_SEL = 2,    // Coefficient select width
    parameter    P_MUX_SEL = 2      // Mux select width
)
(
    // Reset and clock
    input wire                              RST_IN,             // Reset
    input wire                              CLK_IN,             // Clock

    // Control
    input wire                              CTL_RUN_IN,         // Run
    input wire                              CTL_FS_IN,          // Frame start
    input wire [3:0]                        CTL_MODE_IN,        // Mode
    input wire [15:0]                       CTL_HWIDTH_IN,      // Destination Horizontal width
    input wire [15:0]                       CTL_VHEIGHT_IN,     // Destination Vertical height

    // Line buffer
    input wire                              LBF_RDY_IN,          // Ready

    // Sliding window
    input wire                              SLW_RDY_IN,          // Ready
    output wire                             SLW_LRST_OUT,        // Restore line
    output wire                             SLW_LNXT_OUT,        // Next line
    output wire   [1:0]                     SLW_STEP_OUT,        // Step

    // Coefficients
    output wire [(16*(P_COEF_SEL))-1:0]     COEF_SEL_OUT,       // Coefficient select

    // Mux
    output wire [(16*P_MUX_SEL)-1:0]        MUX_SEL_OUT,        // MUX select

    // Kernel
    output wire                             KRNL_DE_OUT         // Data enable
);

// Parameters
localparam P_LUT_DAT = 4 * (P_MUX_SEL + P_COEF_IDX);

// State machine
typedef enum {
     sm_idle, sm_s0, sm_s1, sm_s2, sm_s3, sm_s4, sm_s5
} sm_state;

// Structures
typedef struct {
    logic               run;
    logic               fs;
    logic [3:0]         mode;
    logic [15:0]        hwidth;
    logic [15:0]        vheight;
} ctl_struct;

typedef struct {
    sm_state            sm_cur;
    sm_state            sm_nxt;
    logic [1:0]         ratio;
    logic [2:0]         blk_idx;
    logic [2:0]         row_idx;
    logic [15:0]        hcnt;
    logic               hlast;
    logic [15:0]        vcnt;
    logic               vlast;
    logic [3:0]         cnt;
    logic               cnt_ld;
    logic               cnt_end;
} agnt_struct;

typedef struct {
    logic               run;
    logic               run_set;
    logic               run_clr;
    logic [1:0]         run_del;
    logic               rdy;
    logic               lrst;
    logic               lnxt_pre;
    logic               lnxt;
    logic [1:0]         step;
} slw_struct;

typedef struct {
    logic [7:0]                     sel;
    logic [P_LUT_DAT-1:0]           dat[0:3];
} lut_struct;

typedef struct {
    logic [(16*P_COEF_SEL)-1:0]     sel[0:4];
} coef_struct;

typedef struct {
    logic [(16*P_MUX_SEL)-1:0]      sel[0:5];
} mux_struct;

typedef struct {
    logic [6:0]                     de;
} krnl_struct;

typedef struct {
    logic                           rdy;
} lbf_struct;

// Signals
ctl_struct              clk_ctl;
agnt_struct             clk_agnt;
slw_struct              clk_slw;
lut_struct              clk_lut;
coef_struct             clk_coef;
mux_struct              clk_mux;
krnl_struct             clk_krnl;
lbf_struct              clk_lbf;

genvar i;

// Logic

// Control
    always_ff @ (posedge RST_IN, posedge CLK_IN)
    begin
        // Reset
        if (RST_IN)
            clk_ctl.run <= 0;
            
        else
            clk_ctl.run  <= CTL_RUN_IN;
    end

    always_ff @ (posedge CLK_IN)
    begin
        clk_ctl.fs      <= CTL_FS_IN;
        clk_ctl.mode    <= CTL_MODE_IN;
        clk_ctl.hwidth  <= CTL_HWIDTH_IN;
        clk_ctl.vheight <= CTL_VHEIGHT_IN;
    end

// Ratio
    always_ff @ (posedge CLK_IN)
    begin
        case (clk_ctl.mode)
            'd6 : clk_agnt.ratio <= 'd1;        // Ratio 2/1
            'd7 : clk_agnt.ratio <= 'd2;        // Ratio 3/1
            'd8 : clk_agnt.ratio <= 'd3;        // Ratio 4/3
            default : clk_agnt.ratio <= 'd0;    // Ratio 3/2
        endcase
    end

// Line buffer
    always_ff @ (posedge CLK_IN)
    begin   
        clk_lbf.rdy <= LBF_RDY_IN;
    end

// Sliding window
    always_ff @ (posedge CLK_IN)
    begin   
        clk_slw.rdy <= SLW_RDY_IN;
    end

// Run flag
    always_ff @ (posedge CLK_IN)
    begin   
        // Run
        if (clk_ctl.run)
        begin
            // Clear
            if (clk_ctl.fs || clk_agnt.hlast)        
                clk_slw.run <= 0;
            
            // Set
            else if (clk_slw.run_set)
                clk_slw.run <= 1;
        
            // Run delayed
            // The look-up memory has two clock cycles latency
            clk_slw.run_del <= {clk_slw.run_del[0], clk_slw.run};
        end

        else    
            clk_slw.run <= 0;
    end

// Horizontal counter
    always_ff @ (posedge CLK_IN)
    begin   
        // Run
        if (clk_slw.run)
            clk_agnt.hcnt <= clk_agnt.hcnt + 'd1;

        else    
            clk_agnt.hcnt <= 0;
    end

// Vertical counter
    always_ff @ (posedge CLK_IN)
    begin   
        // Run
        if (clk_ctl.run)
        begin
            // Clear
            if (clk_ctl.fs)
                clk_agnt.vcnt <= 0;

            // Increment
            else if (clk_slw.lrst)
                clk_agnt.vcnt <= clk_agnt.vcnt + 'd1;
        end

        else    
            clk_agnt.vcnt <= 0;
    end

// Last horizontal block flag
// todo: make registered
/*
    always_comb 
    begin
        if (clk_agnt.hcnt == (clk_ctl.hwidth[$left(clk_ctl.hwidth):2] - 'd1))
            clk_agnt.hlast = 1;
        else
            clk_agnt.hlast = 0;       
    end
*/
    always_ff @ (posedge CLK_IN)
    begin
        if (clk_agnt.hcnt == (clk_ctl.hwidth[$left(clk_ctl.hwidth):2] - 'd2))
            clk_agnt.hlast <= 1;
        else
            clk_agnt.hlast <= 0;       
    end

// Last line flag
// todo: make registered
/*
    always_comb 
    begin
        if (clk_agnt.vcnt == (clk_ctl.vheight - 'd1))
            clk_agnt.vlast = 1;
        else
            clk_agnt.vlast = 0;       
    end
*/
    always_ff @ (posedge CLK_IN)
    begin
        if (clk_agnt.vcnt == (clk_ctl.vheight - 'd1))
            clk_agnt.vlast <= 1;
        else
            clk_agnt.vlast <= 0;       
    end

// Block index
    always_ff @ (posedge CLK_IN)
    begin   
        // Run
        if (clk_slw.run)
        begin
            // Clear
            if (clk_ctl.fs || clk_slw.lrst)
                clk_agnt.blk_idx <= 0;

            // Ratio 3/2
            else if ((clk_ctl.mode == 'd5) && (clk_agnt.blk_idx == 'd3))
                clk_agnt.blk_idx <= 'd1;

            // Ratio 2/1
            else if ((clk_ctl.mode == 'd6) && (clk_agnt.blk_idx == 'd2))
                clk_agnt.blk_idx <= 'd1;

            // Ratio 3/1
            else if ((clk_ctl.mode == 'd7) && (clk_agnt.blk_idx == 'd3))
                clk_agnt.blk_idx <= 'd1;

            // Ratio 4/3
            else if ((clk_ctl.mode == 'd8) && (clk_agnt.blk_idx == 'd2))
                clk_agnt.blk_idx <= 'd1;

            else
                clk_agnt.blk_idx <= clk_agnt.blk_idx + 'd1;
        end

        else    
            clk_agnt.blk_idx <= 0;
    end

// Row index
    always_ff @ (posedge CLK_IN)
    begin   
        // Run
        if (clk_ctl.run)
        begin
            // Clear
            if (clk_ctl.fs)
                clk_agnt.row_idx <= 0;

            // Increment
            else if (clk_slw.lrst)
            begin
                // Ratio 3/2
                if ((clk_ctl.mode == 'd5) && (clk_agnt.row_idx == 'd3))
                    clk_agnt.row_idx <= 'd1;

                // Ratio 2/1
                else if ((clk_ctl.mode == 'd6) && (clk_agnt.row_idx == 'd2))
                    clk_agnt.row_idx <= 'd1;

                // Ratio 3/1
                else if ((clk_ctl.mode == 'd7) && (clk_agnt.row_idx == 'd3))
                    clk_agnt.row_idx <= 'd1;

                // Ratio 4/3
                else if ((clk_ctl.mode == 'd8) && (clk_agnt.row_idx == 'd4))
                    clk_agnt.row_idx <= 'd1;
                
                else
                    clk_agnt.row_idx <= clk_agnt.row_idx + 'd1;
            end
        end

        else    
            clk_agnt.row_idx <= 0;
    end

// Sliding window next preset
    always_ff @ (posedge CLK_IN)
    begin
        // Default
        clk_slw.lnxt_pre <= 0;
        
        // Ratio 3/2
        if (clk_ctl.mode == 'd5)
        begin
            case (clk_agnt.row_idx)
                'd1 : clk_slw.lnxt_pre <= 1;
                'd3 : clk_slw.lnxt_pre <= 1;
                default : ;
            endcase
        end

        // Ratio 2/1
        else if (clk_ctl.mode == 'd6)
        begin
            case (clk_agnt.row_idx)
                'd2 : clk_slw.lnxt_pre <= 1;
                default : ;
            endcase
        end

        // Ratio 3/1
        else if (clk_ctl.mode == 'd7)
        begin
            case (clk_agnt.row_idx)
                'd3 : clk_slw.lnxt_pre <= 1;
                default : ;
            endcase
        end

        // Ratio 4/3
        else if (clk_ctl.mode == 'd8) 
        begin
            case (clk_agnt.row_idx)
                'd1 : clk_slw.lnxt_pre <= 1;
                'd2 : clk_slw.lnxt_pre <= 1;
                'd4 : clk_slw.lnxt_pre <= 1;
                default : ;
            endcase
        end   
    end

// Counter
    always_ff @ (posedge CLK_IN)
    begin
        // Load
        if (clk_agnt.cnt_ld)
            clk_agnt.cnt <= '1;
        
        // Decrement
        else if (!clk_agnt.cnt_end)
            clk_agnt.cnt <= clk_agnt.cnt - 'd1;
    end

// Counter end
// todo: make registered
    always_ff @ (posedge CLK_IN)
    begin
        if (clk_agnt.cnt == 0)
            clk_agnt.cnt_end <= 1;
        else
            clk_agnt.cnt_end <= 0;
    end

// State machine
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_ctl.run)
        begin               
            // Clear
            if (clk_ctl.fs)
                clk_agnt.sm_cur <= sm_idle;
            else
                clk_agnt.sm_cur <= clk_agnt.sm_nxt;
        end

        // Idle
        else
            clk_agnt.sm_cur <= sm_idle;
    end

// State machine decoder
    always_comb
    begin
        
        // Default
        clk_slw.run_set = 0;
        clk_slw.run_clr = 0;
        clk_slw.lrst = 0;
        clk_slw.lnxt = 0;
        clk_agnt.cnt_ld = 0;

        case (clk_agnt.sm_cur)

            sm_idle : 
            begin
                if (clk_lbf.rdy && clk_slw.rdy)
                begin
                    clk_slw.run_set = 1;
                    clk_agnt.sm_nxt = sm_s0;
                end

                else
                    clk_agnt.sm_nxt = sm_idle;
            end

            sm_s0 : 
            begin
                if (clk_agnt.hlast)
                begin
                    clk_slw.run_clr = 1;
                    
                    if (clk_agnt.vlast)
                        clk_agnt.sm_nxt = sm_s5;
                    else
                    begin                
                        clk_agnt.cnt_ld = 1;
                        clk_agnt.sm_nxt = sm_s1;
                    end
                end

                else
                    clk_agnt.sm_nxt = sm_s0;
            end

            // Next line
            sm_s1 : 
            begin
                if (clk_agnt.cnt_end)
                begin
                    clk_slw.lnxt = clk_slw.lnxt_pre;
                    clk_agnt.cnt_ld = 1;
                    clk_agnt.sm_nxt = sm_s2;
                end

                else
                    clk_agnt.sm_nxt = sm_s1;
            end

            sm_s2 :
            begin
                if (clk_agnt.cnt_end)
                begin
                    clk_agnt.cnt_ld = 1;
                    clk_agnt.sm_nxt = sm_s3;
                end
                else
                    clk_agnt.sm_nxt = sm_s2;
            end

            // Restore line
            sm_s3 : 
            begin
                if (clk_agnt.cnt_end)
                begin
                    clk_slw.lrst = 1;
                    clk_agnt.cnt_ld = 1;
                    clk_agnt.sm_nxt = sm_s4;
                end

                else
                    clk_agnt.sm_nxt = sm_s3;
            end

            sm_s4 :
            begin
                if (clk_agnt.cnt_end)
                    clk_agnt.sm_nxt = sm_idle;
                else
                    clk_agnt.sm_nxt = sm_s4;
            end

            sm_s5 :
            begin
                clk_agnt.sm_nxt = sm_s5;
            end

            default : 
            begin
                clk_agnt.sm_nxt = sm_idle;
            end
        endcase
     end

// Sliding window step
// This process selects the steps for the sliding window to slide.
    always_ff @ (posedge CLK_IN)
    begin
        // Default
        clk_slw.step <= 0;
        
        // Ratio 3/2
        if (clk_ctl.mode == 'd5)
        begin
            case (clk_agnt.blk_idx)
                'd0 : clk_slw.step <= 'd2;
                'd1 : clk_slw.step <= 'd3;
                'd2 : clk_slw.step <= 'd2;
                'd3 : clk_slw.step <= 'd3;
                default : ;
            endcase
        end

        // Ratio 2/1
        else if (clk_ctl.mode == 'd6)
        begin
            case (clk_agnt.blk_idx)
                'd0 : clk_slw.step <= 'd1;
                'd1 : clk_slw.step <= 'd2;
                'd2 : clk_slw.step <= 'd2;
                default : ;
            endcase
        end

        // Ratio 3/1
        else if (clk_ctl.mode == 'd7)
        begin
            case (clk_agnt.blk_idx)
                'd0 : clk_slw.step <= 'd1;
                'd1 : clk_slw.step <= 'd1;
                'd2 : clk_slw.step <= 'd1;
                'd3 : clk_slw.step <= 'd2;
                default : ;
            endcase
        end

        // Ratio 4/3
        else if (clk_ctl.mode == 'd8) 
        begin
            case (clk_agnt.blk_idx)
                'd0 : clk_slw.step <= 'd2;
                'd1 : clk_slw.step <= 'd3;
                'd2 : clk_slw.step <= 'd3;
                default : ;
            endcase
        end   
    end

// Lookup

// Select
    assign clk_lut.sel = {clk_agnt.ratio, clk_agnt.row_idx, clk_agnt.blk_idx};

generate
    for (i = 0; i < 4; i++)
    begin : gen_lut
        prt_scaler_agnt_lut
        #(
            .P_ID       (i),            // Index
            .P_COEF     (P_COEF_IDX),   // Coefficient width
            .P_MUX      (P_MUX_SEL),    // MUX width
            .P_DAT      (P_LUT_DAT)     // Data width
        )
        LUT_INST
        (
            .CLK_IN     (CLK_IN),
            .SEL_IN     (clk_lut.sel),
            .DAT_OUT    (clk_lut.dat[i])
        );
    end
endgenerate

// Coef select
    always_ff @ (posedge CLK_IN)
    begin
        for (int i = 0; i < 4; i++)
            clk_coef.sel[0][(i*4*P_COEF_SEL)+:(4*P_COEF_SEL)] <= {clk_agnt.ratio, clk_lut.dat[i][(3*P_COEF_IDX)+:P_COEF_IDX], clk_agnt.ratio, clk_lut.dat[i][(2*P_COEF_IDX)+:P_COEF_IDX], clk_agnt.ratio, clk_lut.dat[i][(1*P_COEF_IDX)+:P_COEF_IDX], clk_agnt.ratio, clk_lut.dat[i][(0*P_COEF_IDX)+:P_COEF_IDX]};

        for (int i = 1; i < $size(clk_coef.sel); i++)
            clk_coef.sel[i] <= clk_coef.sel[i-1];
    end

// Mux select
    always_ff @ (posedge CLK_IN)
    begin
        for (int i = 0; i < 4; i++)
            clk_mux.sel[0][(i*P_MUX_SEL*4)+:P_MUX_SEL*4] <= clk_lut.dat[i][(P_COEF_IDX*4)+:P_MUX_SEL*4];

        for (int i = 1; i < $size(clk_mux.sel); i++)
            clk_mux.sel[i] <= clk_mux.sel[i-1];
    end

// Kernel data enable
// This flag is asserted when the kernel has valid pixel data, coefficients and mux selects.
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_ctl.run)
        begin
            clk_krnl.de <= {clk_krnl.de[$high(clk_krnl.de)-1:0], clk_slw.run};
        end

        // Idle
        else
            clk_krnl.de <= 0;
    end

// Outputs   
    assign SLW_LRST_OUT = clk_slw.lrst;
    assign SLW_LNXT_OUT = clk_slw.lnxt;
    assign SLW_STEP_OUT = (clk_slw.run_del[0]) ? clk_slw.step : 0;
    assign COEF_SEL_OUT = clk_coef.sel[$high(clk_coef.sel)];
    assign MUX_SEL_OUT = clk_mux.sel[$high(clk_mux.sel)];
    assign KRNL_DE_OUT = clk_krnl.de[$high(clk_krnl.de)];

endmodule

`default_nettype wire
