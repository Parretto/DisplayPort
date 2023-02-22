/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    RPI_DPI
    This module captures the video data from the Raspberry PI DPI interface.
    Then it converts it from single pixel per clock to quad pixel per clock.

    (c) 2022 - 2023 by Parretto B.V.
*/

`default_nettype none

module rpi_dpi
#(
    // System
    parameter                   P_VENDOR    = "none"  // Vendor "xilinx", "lattice" or "intel"
)
(
    // Reset and clock
    input wire                  SYS_RST_IN,
    input wire                  SYS_CLK_IN,

    // Local bus interface
    prt_dp_lb_if.lb_in          LB_IF,

    // DPI input
    input wire                  DPI_CLK_IN,   
    input wire                  DPI_VS_IN,
    input wire                  DPI_HS_IN,
    input wire                  DPI_DEN_IN,

    input wire [7:0]            DPI_R_IN,
    input wire [7:0]            DPI_G_IN,
    input wire [7:0]            DPI_B_IN,

    output wire                 DPI_REF_CLK_OUT,

    // Video output
    input wire                  VID_CLK_IN,
    input wire                  VID_CKE_IN,
    output wire                 VID_LOCK_OUT,
    output wire                 VID_VS_OUT,
    output wire                 VID_HS_OUT,
    output wire [(4*8)-1:0]     VID_R_OUT,
    output wire [(4*8)-1:0]     VID_G_OUT,
    output wire [(4*8)-1:0]     VID_B_OUT,
    output wire                 VID_DE_OUT
) /* synthesis syn_useioff = 1 */;

// Parameters
// Control register bit locations
localparam P_CTL_RUN        = 0;
localparam P_CTL_ORDER      = 1;
localparam P_CTL_WIDTH      = 3;

// FIFO
localparam P_FIFO_WRDS = 16;
localparam P_FIFO_ADR = $clog2(P_FIFO_WRDS);
localparam P_FIFO_DAT = 24 + 1; 

// Structure
typedef struct {
    logic   [3:0]               adr;
    logic                       wr;
    logic                       rd;
    logic   [31:0]              din;
    logic   [31:0]              dout;
    logic                       vld;
    logic                       vld_re;
} lb_struct;

typedef struct {
    logic   [P_CTL_WIDTH-1:0]   r;              // Register
    logic                       sel;            // Select
    logic                       run;            // Run
    logic [1:0]                 order;
} ctl_struct;

typedef struct {
    logic                       sel;
    logic                       htotal_sel;
    logic                       hwidth_sel;
    logic                       hstart_sel;
    logic                       hsw_sel;
    logic                       vtotal_sel;
    logic                       vheight_sel;
    logic                       vstart_sel;
    logic                       vsw_sel;
    logic   [15:0]              htotal;
    logic   [15:0]              hwidth;
    logic   [15:0]              hstart;
    logic   [15:0]              hsw;
    logic   [15:0]              vtotal;
    logic   [15:0]              vheight;
    logic   [15:0]              vstart;
    logic   [15:0]              vsw;
} sta_struct;

typedef struct {
    logic                       ref_clk;
    logic                       run;
    logic [3:0]                 lock;
    logic [1:0]                 cnt;
    logic                       vs;
    logic                       vs_re;
    logic                       hs;
    logic                       hs_re;
    logic                       hs_fe;
    logic                       den;
    logic                       de;
    logic                       de_re;
    logic                       de_fe;
    logic   [7:0]               r;
    logic   [7:0]               g;
    logic   [7:0]               b;
} dpi_struct;

typedef struct {
    logic   [1:0]               sel;
    logic   [7:0]               r;
    logic   [7:0]               g;
    logic   [7:0]               b;
} mux_struct;

typedef struct {
    logic [P_FIFO_DAT-1:0]      din;
    logic [3:0]                 wr;
} dpi_fifo_struct;

typedef struct {
    logic                       rd;
    logic [P_FIFO_DAT-1:0]      dout[0:3];
    logic [3:0]                 de;
    logic [P_FIFO_ADR:0]        wrds[0:3];
    logic [3:0]                 ep;
    logic                       rdy;
} vid_fifo_struct;

typedef struct {
    logic                       run;
    logic                       lock;
    logic                       vs;
    logic                       hs;
} vid_struct;

typedef struct {
    logic   [15:0]              htotal_cnt;
    logic   [15:0]              htotal;
    logic   [15:0]              hwidth_cnt;
    logic   [15:0]              hwidth;
    logic                       hstart_arm;
    logic                       hstart_run;
    logic   [15:0]              hstart_cnt;
    logic   [15:0]              hstart;
    logic   [15:0]              hsw_cnt;
    logic   [15:0]              hsw;
    logic   [15:0]              vtotal_cnt;
    logic   [15:0]              vtotal;
    logic   [15:0]              vheight_cnt;
    logic   [15:0]              vheight;
    logic                       vstart_run;
    logic   [15:0]              vstart_cnt;
    logic   [15:0]              vstart;
    logic   [15:0]              vsw_cnt;
    logic   [15:0]              vsw;
} mon_struct;

// Signals
lb_struct           sclk_lb;         // Local bus
ctl_struct          sclk_ctl;        // Control register
sta_struct          sclk_sta;        // Control register
dpi_struct          dclk_dpi;
mux_struct          dclk_mux;
dpi_fifo_struct     dclk_fifo;
mon_struct          dclk_mon;
vid_fifo_struct     vclk_fifo;
vid_struct          vclk_vid;

genvar i;

// Logic

// Local bus inputs
    always_ff @ (posedge SYS_CLK_IN)
    begin
        sclk_lb.adr      <= LB_IF.adr;
        sclk_lb.rd       <= LB_IF.rd;
        sclk_lb.wr       <= LB_IF.wr;
        sclk_lb.din      <= LB_IF.din;
    end

// Address selector
// Must be combinatorial
    always_comb
    begin
        // Default
        sclk_ctl.sel            = 0;
        sclk_sta.sel            = 0;
        sclk_sta.htotal_sel     = 0;
        sclk_sta.hwidth_sel     = 0;
        sclk_sta.hstart_sel     = 0;
        sclk_sta.hsw_sel        = 0;
        sclk_sta.vtotal_sel     = 0;
        sclk_sta.vheight_sel    = 0;
        sclk_sta.vstart_sel     = 0;
        sclk_sta.vsw_sel        = 0;

        case (sclk_lb.adr)
            'd0  : sclk_ctl.sel            = 1;
            'd1  : sclk_sta.sel            = 1;
            'd2  : sclk_sta.htotal_sel     = 1;
            'd3  : sclk_sta.hwidth_sel     = 1;
            'd4  : sclk_sta.hstart_sel     = 1;
            'd5  : sclk_sta.hsw_sel        = 1;
            'd6  : sclk_sta.vtotal_sel     = 1;
            'd7  : sclk_sta.vheight_sel    = 1;
            'd8  : sclk_sta.vstart_sel     = 1;
            'd9  : sclk_sta.vsw_sel        = 1;
            default : ;
        endcase
    end

// Register data out
// Must be combinatorial
    always_comb
    begin
        // Default
        sclk_lb.dout = 0;

        // Control register
        if (sclk_ctl.sel)
            sclk_lb.dout[0+:$size(sclk_ctl.r)] = sclk_ctl.r;

        // Htotal
        else if (sclk_sta.htotal_sel)
            sclk_lb.dout[0+:$size(sclk_sta.htotal)] = sclk_sta.htotal;

        // Hwidth
        else if (sclk_sta.hwidth_sel)
            sclk_lb.dout[0+:$size(sclk_sta.hwidth)] = sclk_sta.hwidth;

        // Hstart
        else if (sclk_sta.hstart_sel)
            sclk_lb.dout[0+:$size(sclk_sta.hstart)] = sclk_sta.hstart;

        // Hsw
        else if (sclk_sta.hsw_sel)
            sclk_lb.dout[0+:$size(sclk_sta.hsw)] = sclk_sta.hsw;

        // Vtotal
        else if (sclk_sta.vtotal_sel)
            sclk_lb.dout[0+:$size(sclk_sta.vtotal)] = sclk_sta.vtotal;

        // Vheight
        else if (sclk_sta.vheight_sel)
            sclk_lb.dout[0+:$size(sclk_sta.vheight)] = sclk_sta.vheight;

        // Vstart
        else if (sclk_sta.vstart_sel)
            sclk_lb.dout[0+:$size(sclk_sta.vstart)] = sclk_sta.vstart;

        // Vsw
        else if (sclk_sta.vsw_sel)
            sclk_lb.dout[0+:$size(sclk_sta.vsw)] = sclk_sta.vsw;
    end

// Valid
// Must be combinatorial
    always_comb
    begin
        if (sclk_lb.rd)
            sclk_lb.vld = 1;
        else
            sclk_lb.vld = 0;
    end

// Control register
    always_ff @ (posedge SYS_RST_IN, posedge SYS_CLK_IN)
    begin
        if (SYS_RST_IN)
            sclk_ctl.r <= 0;

        else
        begin
            // Write
            if (sclk_ctl.sel && sclk_lb.wr)
                sclk_ctl.r <= sclk_lb.din[0+:$size(sclk_ctl.r)];
        end
    end

// Control register bit locations
    assign sclk_ctl.run     = sclk_ctl.r[P_CTL_RUN];                               // Run
    assign sclk_ctl.order   = sclk_ctl.r[P_CTL_ORDER+:$size(sclk_ctl.order)];    // RGB order

// DPI run
    prt_dp_lib_cdc_bit
    DPI_RUN_CDC_INST
    (
       .SRC_CLK_IN      (SYS_CLK_IN),
       .SRC_DAT_IN      (sclk_ctl.run),
       .DST_CLK_IN      (DPI_CLK_IN),
       .DST_DAT_OUT     (dclk_dpi.run)
    );

// DPI input Registers
    always_ff @ (posedge DPI_CLK_IN)
    begin
        dclk_dpi.vs  <= DPI_VS_IN;
        dclk_dpi.hs  <= DPI_HS_IN;
        dclk_dpi.den <= DPI_DEN_IN;
        dclk_dpi.r   <= DPI_R_IN;
        dclk_dpi.g   <= DPI_G_IN;
        dclk_dpi.b   <= DPI_B_IN;    
    end

// Invert DE
    assign dclk_dpi.de = ~dclk_dpi.den;

// DPI reference clock out
// This is used as a reference clock for the external video clock generator
    always_ff @ (posedge DPI_CLK_IN)
    begin
        dclk_dpi.ref_clk <= ~dclk_dpi.ref_clk;
    end

    // MUX select CDC
    prt_dp_lib_cdc_vec
    #(
        .P_WIDTH ($size(dclk_mux.sel))
    )
    VID_MUX_SEL_INST
    (
        .SRC_CLK_IN     (SYS_CLK_IN),       // Clock
        .SRC_DAT_IN     (sclk_ctl.order),   // Data
        .DST_CLK_IN     (DPI_CLK_IN),       // Clock
        .DST_DAT_OUT    (dclk_mux.sel)      // Data
    );

// RGB order mux
// This mux allows to change the RGB order
    always_comb
    begin
        case (dclk_mux.sel)

            // BGR
            'd1 : 
            begin
                dclk_mux.r <= dclk_dpi.b;
                dclk_mux.g <= dclk_dpi.g;
                dclk_mux.b <= dclk_dpi.r;
            end                

            // GBR 
            'd2 : 
            begin
                dclk_mux.r <= dclk_dpi.g;
                dclk_mux.g <= dclk_dpi.b;
                dclk_mux.b <= dclk_dpi.r;
            end                

            // BRG
            'd3 : 
            begin
                dclk_mux.r <= dclk_dpi.b;
                dclk_mux.g <= dclk_dpi.r;
                dclk_mux.b <= dclk_dpi.g;
            end                

            // RGB
            default : 
            begin
                dclk_mux.r <= dclk_dpi.r;
                dclk_mux.g <= dclk_dpi.g;
                dclk_mux.b <= dclk_dpi.b;
            end                
        endcase
    end

// VS edge detector
    prt_dp_lib_edge
    DPI_VS_EDGE_INST
    (
        .CLK_IN         (DPI_CLK_IN),       // Clock
        .CKE_IN         (1'b1),             // Clock enable
        .A_IN           (dclk_dpi.vs),      // Input
        .RE_OUT         (dclk_dpi.vs_re),   // Rising edge
        .FE_OUT         ()                  // Falling edge
    );

// HS edge detector
    prt_dp_lib_edge
    DPI_HS_EDGE_INST
    (
        .CLK_IN         (DPI_CLK_IN),       // Clock
        .CKE_IN         (1'b1),             // Clock enable
        .A_IN           (dclk_dpi.hs),      // Input
        .RE_OUT         (dclk_dpi.hs_re),   // Rising edge
        .FE_OUT         (dclk_dpi.hs_fe)    // Falling edge
    );

// VS edge detector
    prt_dp_lib_edge
    DPI_DE_EDGE_INST
    (
        .CLK_IN         (DPI_CLK_IN),       // Clock
        .CKE_IN         (1'b1),             // Clock enable
        .A_IN           (dclk_dpi.de),    // Input
        .RE_OUT         (dclk_dpi.de_re),   // Rising edge
        .FE_OUT         (dclk_dpi.de_fe)    // Falling edge
    );

// Lock
    always_ff @ (posedge DPI_CLK_IN)
    begin
        // Run
        if (dclk_dpi.run)
        begin
            if (dclk_dpi.vs_re)       
                dclk_dpi.lock[0] <= 1;

            // The lock must be delayed for three cycles to align the fifo write with the counter.
            dclk_dpi.lock[$high(dclk_dpi.lock):1] <= dclk_dpi.lock[$high(dclk_dpi.lock)-1:0];
        end

        // Idle
        else
            dclk_dpi.lock <= 0;
    end
    
// Counter
    always_ff @ (posedge DPI_CLK_IN)
    begin
        // Run
        if (dclk_dpi.run)
        begin
            // Clear
            if (dclk_dpi.vs_re)
                dclk_dpi.cnt <= 'd1;
           
            // Increment
            else
                dclk_dpi.cnt <= dclk_dpi.cnt + 'd1;
        end

        // Idle
        else
            dclk_dpi.cnt <= 0;
    end

// FIFO data in
    assign dclk_fifo.din = {dclk_dpi.de, dclk_mux.b, dclk_mux.g, dclk_mux.r};

// FIFO write
    assign dclk_fifo.wr[0] = (dclk_dpi.lock[$high(dclk_dpi.lock)] && (dclk_dpi.cnt == 'd0)) ? 1 : 0;
    assign dclk_fifo.wr[1] = (dclk_dpi.lock[$high(dclk_dpi.lock)] && (dclk_dpi.cnt == 'd1)) ? 1 : 0;
    assign dclk_fifo.wr[2] = (dclk_dpi.lock[$high(dclk_dpi.lock)] && (dclk_dpi.cnt == 'd2)) ? 1 : 0;
    assign dclk_fifo.wr[3] = (dclk_dpi.lock[$high(dclk_dpi.lock)] && (dclk_dpi.cnt == 'd3)) ? 1 : 0;

// FIFO
generate
    for (i = 0; i < 4; i++)
    begin : gen_fifo
        prt_dp_lib_fifo_dc
        #(
            .P_VENDOR       (P_VENDOR),  		// Vendor "xilinx" or "lattice"
            .P_MODE         ("burst"),		    // "single" or "burst"
            .P_RAM_STYLE	("distributed"),	// "distributed" or "block"
            .P_ADR_WIDTH	(P_FIFO_ADR),
            .P_DAT_WIDTH	(P_FIFO_DAT)
        )
        FIFO_INST
        (
            .A_RST_IN       (~dclk_dpi.run),		// Reset
            .B_RST_IN       (~vclk_vid.run),
            .A_CLK_IN       (DPI_CLK_IN),		    // Clock
            .B_CLK_IN       (VID_CLK_IN),
            .A_CKE_IN       (1'b1),		            // Clock enable
            .B_CKE_IN       (VID_CKE_IN),

            // Input (A)
            .A_CLR_IN       (1'b0),		            // Clear
            .A_WR_IN        (dclk_fifo.wr[i]),		// Write
            .A_DAT_IN       (dclk_fifo.din),		// Write data

            // Output (B)
            .B_CLR_IN       (1'b0),		            // Clear
            .B_RD_IN        (vclk_fifo.rd),		    // Read
            .B_DAT_OUT      (vclk_fifo.dout[i]),	// Read data
            .B_DE_OUT       (vclk_fifo.de[i]),		// Data enable

            // Status (A)
            .A_WRDS_OUT     (),	    // Used words
            .A_FL_OUT       (),		// Full
            .A_EP_OUT       (),		// Empty

            // Status (B)
            .B_WRDS_OUT     (vclk_fifo.wrds[i]),	    // Used words
            .B_FL_OUT       (),		// Full
            .B_EP_OUT	    (vclk_fifo.ep[i])	    // Empty
        );
    end
endgenerate

// Video

// Video run
    prt_dp_lib_cdc_bit
    VID_RUN_CDC_INST
    (
       .SRC_CLK_IN      (SYS_CLK_IN),
       .SRC_DAT_IN      (sclk_ctl.run),
       .DST_CLK_IN      (VID_CLK_IN),
       .DST_DAT_OUT     (vclk_vid.run)
    );

// Vsync
    prt_dp_lib_cdc_bit
    VID_VS_CDC_INST
    (
       .SRC_CLK_IN      (DPI_CLK_IN),
       .SRC_DAT_IN      (dclk_dpi.vs),
       .DST_CLK_IN      (VID_CLK_IN),
       .DST_DAT_OUT     (vclk_vid.vs)
    );

// Hsync
    prt_dp_lib_cdc_bit
    VID_HS_CDC_INST
    (
       .SRC_CLK_IN      (DPI_CLK_IN),
       .SRC_DAT_IN      (dclk_dpi.hs),
       .DST_CLK_IN      (VID_CLK_IN),
       .DST_DAT_OUT     (vclk_vid.hs)
    );

// FIFO ready
    always_ff @ (posedge VID_CLK_IN)
    begin
        vclk_fifo.rdy <= 1;
        for (int i = 0; i < 4; i++)
        begin
            if (vclk_fifo.wrds[i] < (P_FIFO_WRDS/2))
                vclk_fifo.rdy <= 0;
        end
    end


// FIFO read
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Run
        if (vclk_vid.run)
        begin
            if (vclk_fifo.rdy)
                vclk_fifo.rd <= 1;
            else
                vclk_fifo.rd <= 0;
        end

        else
            vclk_fifo.rd <= 0;
    end

// Lock
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Run
        if (vclk_vid.run)
        begin
            if (&vclk_fifo.de)
                vclk_vid.lock <= 1;
            else
                vclk_vid.lock <= 0;
        end

        else
            vclk_vid.lock <= 0;
    end

// Monitor

// Htotal
    always_ff @ (posedge DPI_CLK_IN)
    begin
        // Run
        if (dclk_dpi.run)
        begin
            if (dclk_dpi.hs_re)
            begin
                dclk_mon.htotal_cnt <= 'd1;
                dclk_mon.htotal     <= dclk_mon.htotal_cnt;
            end

            else
                dclk_mon.htotal_cnt <= dclk_mon.htotal_cnt + 'd1;
        end

        // Idle
        else
        begin
            dclk_mon.htotal <= 0;
            dclk_mon.htotal_cnt <= 0;
        end
    end

// Hwidth
    always_ff @ (posedge DPI_CLK_IN)
    begin
        // Run
        if (dclk_dpi.run)
        begin
            if (dclk_dpi.de_fe)
            begin
                dclk_mon.hwidth_cnt <= 'd0;
                dclk_mon.hwidth     <= dclk_mon.hwidth_cnt;
            end

            else if (dclk_dpi.de)
                dclk_mon.hwidth_cnt <= dclk_mon.hwidth_cnt + 'd1;
        end

        // Idle
        else
        begin
            dclk_mon.hwidth <= 0;
            dclk_mon.hwidth_cnt <= 0;
        end
    end

// Hstart
    always_ff @ (posedge DPI_CLK_IN)
    begin
        // Run
        if (dclk_dpi.run)
        begin
            if (dclk_dpi.de_re)
            begin
                dclk_mon.hstart     <= dclk_mon.hstart_cnt;
                dclk_mon.hstart_run <= 0;
                dclk_mon.hstart_arm <= 1;
            end

            else if (dclk_dpi.hs_re)
            begin
                if (dclk_mon.hstart_arm)
                begin
                    dclk_mon.hstart_arm <= 0;
                    dclk_mon.hstart_run <= 1;
                end
                dclk_mon.hstart_cnt <= 'd1;
            end

            else if (dclk_mon.hstart_run)
                dclk_mon.hstart_cnt <= dclk_mon.hstart_cnt + 'd1;
        end

        // Idle
        else
        begin
            dclk_mon.hstart_arm <= 0;
            dclk_mon.hstart_run <= 0;
            dclk_mon.hstart <= 0;
            dclk_mon.hstart_cnt <= 0;
        end
    end

// Hsw
    always_ff @ (posedge DPI_CLK_IN)
    begin
        // Run
        if (dclk_dpi.run)
        begin
            if (dclk_dpi.hs_fe)
            begin
                dclk_mon.hsw_cnt <= 'd0;
                dclk_mon.hsw     <= dclk_mon.hsw_cnt;
            end

            else if (dclk_dpi.hs)
                dclk_mon.hsw_cnt <= dclk_mon.hsw_cnt + 'd1;
        end

        // Idle
        else
        begin
            dclk_mon.hsw <= 0;
            dclk_mon.hsw_cnt <= 0;
        end
    end

// Vtotal
    always_ff @ (posedge DPI_CLK_IN)
    begin
        // Run
        if (dclk_dpi.run)
        begin
            if (dclk_dpi.vs_re)
            begin
                dclk_mon.vtotal_cnt <= 'd1;
                dclk_mon.vtotal     <= dclk_mon.vtotal_cnt;
            end

            else if (dclk_dpi.hs_re)
                dclk_mon.vtotal_cnt <= dclk_mon.vtotal_cnt + 'd1;
        end

        // Idle
        else
        begin
            dclk_mon.vtotal <= 0;
            dclk_mon.vtotal_cnt <= 0;
        end
    end

// Vheight
    always_ff @ (posedge DPI_CLK_IN)
    begin
        // Run
        if (dclk_dpi.run)
        begin
            if (dclk_dpi.vs_re)
            begin
                dclk_mon.vheight_cnt <= 'd0;
                dclk_mon.vheight     <= dclk_mon.vheight_cnt;
            end

            else if (dclk_dpi.de_re)
                dclk_mon.vheight_cnt <= dclk_mon.vheight_cnt + 'd1;
        end

        // Idle
        else
        begin
            dclk_mon.vheight <= 0;
            dclk_mon.vheight_cnt <= 0;
        end
    end

// Vstart
    always_ff @ (posedge DPI_CLK_IN)
    begin
        // Run
        if (dclk_dpi.run)
        begin
            if (dclk_dpi.vs_re)
            begin
                dclk_mon.vstart_cnt <= 'd0;
                dclk_mon.vstart     <= dclk_mon.vstart_cnt;
                dclk_mon.vstart_run <= 1;
            end

            else if (dclk_dpi.hs_re && dclk_mon.vstart_run)
                dclk_mon.vstart_cnt <= dclk_mon.vstart_cnt + 'd1;
 
            else if (dclk_dpi.de_re)
                dclk_mon.vstart_run <= 0;        
        end

        // Idle
        else
        begin
            dclk_mon.vstart_run <= 0;
            dclk_mon.vstart <= 0;
            dclk_mon.vstart_cnt <= 0;
        end
    end

// Vsw
    always_ff @ (posedge DPI_CLK_IN)
    begin
        // Run
        if (dclk_dpi.run)
        begin
            if (dclk_dpi.vs_re)
            begin
                dclk_mon.vsw_cnt <= 'd1;
                dclk_mon.vsw     <= dclk_mon.vsw_cnt;
            end

            else if (dclk_dpi.vs && dclk_dpi.hs_re)
                dclk_mon.vsw_cnt <= dclk_mon.vsw_cnt + 'd1;
        end

        // Idle
        else
        begin
            dclk_mon.vsw <= 0;
            dclk_mon.vsw_cnt <= 0;
        end
    end

// Htotal
    prt_dp_lib_cdc_vec
    #(
        .P_WIDTH ($size(dclk_mon.htotal))
    )
    SCLK_HTOTAL_VEC_INST
    (
        .SRC_CLK_IN     (DPI_CLK_IN),       // Clock
        .SRC_DAT_IN     (dclk_mon.htotal),  // Data
        .DST_CLK_IN     (SYS_CLK_IN),       // Clock
        .DST_DAT_OUT    (sclk_sta.htotal)   // Data
    );

// Hwidth
    prt_dp_lib_cdc_vec
    #(
        .P_WIDTH ($size(dclk_mon.hwidth))
    )
    SCLK_HWIDTH_VEC_INST
    (
        .SRC_CLK_IN     (DPI_CLK_IN),       // Clock
        .SRC_DAT_IN     (dclk_mon.hwidth),  // Data
        .DST_CLK_IN     (SYS_CLK_IN),       // Clock
        .DST_DAT_OUT    (sclk_sta.hwidth)   // Data
    );

// Hsw
    prt_dp_lib_cdc_vec
    #(
        .P_WIDTH ($size(dclk_mon.hsw))
    )
    SCLK_HSW_VEC_INST
    (
        .SRC_CLK_IN     (DPI_CLK_IN),       // Clock
        .SRC_DAT_IN     (dclk_mon.hsw),     // Data
        .DST_CLK_IN     (SYS_CLK_IN),       // Clock
        .DST_DAT_OUT    (sclk_sta.hsw)      // Data
    );

// Hstart
    prt_dp_lib_cdc_vec
    #(
        .P_WIDTH ($size(dclk_mon.hstart))
    )
    SCLK_HSTART_VEC_INST
    (
        .SRC_CLK_IN     (DPI_CLK_IN),       // Clock
        .SRC_DAT_IN     (dclk_mon.hstart),  // Data
        .DST_CLK_IN     (SYS_CLK_IN),       // Clock
        .DST_DAT_OUT    (sclk_sta.hstart)   // Data
    );

// Vtotal
    prt_dp_lib_cdc_vec
    #(
        .P_WIDTH ($size(dclk_mon.vtotal))
    )
    SCLK_VTOTAL_VEC_INST
    (
        .SRC_CLK_IN     (DPI_CLK_IN),       // Clock
        .SRC_DAT_IN     (dclk_mon.vtotal),  // Data
        .DST_CLK_IN     (SYS_CLK_IN),       // Clock
        .DST_DAT_OUT    (sclk_sta.vtotal)   // Data
    );

// Vheight
    prt_dp_lib_cdc_vec
    #(
        .P_WIDTH ($size(dclk_mon.vheight))
    )
    SCLK_Vheight_VEC_INST
    (
        .SRC_CLK_IN     (DPI_CLK_IN),       // Clock
        .SRC_DAT_IN     (dclk_mon.vheight),  // Data
        .DST_CLK_IN     (SYS_CLK_IN),       // Clock
        .DST_DAT_OUT    (sclk_sta.vheight)   // Data
    );

// Vsw
    prt_dp_lib_cdc_vec
    #(
        .P_WIDTH ($size(dclk_mon.vsw))
    )
    SCLK_VSW_VEC_INST
    (
        .SRC_CLK_IN     (DPI_CLK_IN),       // Clock
        .SRC_DAT_IN     (dclk_mon.vsw),     // Data
        .DST_CLK_IN     (SYS_CLK_IN),       // Clock
        .DST_DAT_OUT    (sclk_sta.vsw)      // Data
    );

// Vstart
    prt_dp_lib_cdc_vec
    #(
        .P_WIDTH ($size(dclk_mon.vstart))
    )
    SCLK_VSTART_VEC_INST
    (
        .SRC_CLK_IN     (DPI_CLK_IN),       // Clock
        .SRC_DAT_IN     (dclk_mon.vstart),  // Data
        .DST_CLK_IN     (SYS_CLK_IN),       // Clock
        .DST_DAT_OUT    (sclk_sta.vstart)   // Data
    );

// Outputs
    assign DPI_REF_CLK_OUT  = dclk_dpi.ref_clk;
    assign LB_IF.dout       = sclk_lb.dout;
    assign LB_IF.vld        = sclk_lb.vld;

    assign VID_LOCK_OUT     = vclk_vid.lock;
    assign VID_VS_OUT       = (vclk_vid.run) ? vclk_vid.vs : 0;
    assign VID_HS_OUT       = (vclk_vid.run) ? vclk_vid.hs : 0;
    assign VID_R_OUT        = (vclk_fifo.de[0]) ? {vclk_fifo.dout[3][(0*8)+:8], vclk_fifo.dout[2][(0*8)+:8], vclk_fifo.dout[1][(0*8)+:8], vclk_fifo.dout[0][(0*8)+:8]} : 0;
    assign VID_G_OUT        = (vclk_fifo.de[0]) ? {vclk_fifo.dout[3][(1*8)+:8], vclk_fifo.dout[2][(1*8)+:8], vclk_fifo.dout[1][(1*8)+:8], vclk_fifo.dout[0][(1*8)+:8]} : 0;
    assign VID_B_OUT        = (vclk_fifo.de[0]) ? {vclk_fifo.dout[3][(2*8)+:8], vclk_fifo.dout[2][(2*8)+:8], vclk_fifo.dout[1][(2*8)+:8], vclk_fifo.dout[0][(2*8)+:8]} : 0;
    assign VID_DE_OUT       = (vclk_fifo.de[0]) ? vclk_fifo.dout[0][24] : 0;

endmodule

`default_nettype wire
