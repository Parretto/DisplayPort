/*
    RPI_DPI
    This module captures the video data from the Raspberry PI DPI interface.
    Then it converts it from single pixel per clock to quad pixel per clock.

    (c) 2022 by Parretto B.V.
*/

`default_nettype none

module rpi_dpi
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

    // Video output
    output wire                 VID_CKE_OUT,
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
    logic                       vs;
    logic                       hs;
    logic                       den;
    logic                       den_fe;
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
    logic                       run;
    logic   [1:0]               cke_cnt;
    logic                       cke;
    logic                       vs;
    logic                       vs_re;
    logic                       hs;
    logic                       hs_re;
    logic                       hs_fe;
    logic                       de;
    logic                       de_re;
    logic                       de_fe;
    logic   [(4*8)-1:0]         r;
    logic   [(4*8)-1:0]         g;
    logic   [(4*8)-1:0]         b;
    logic   [1:0]               pix_cnt;
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
dpi_struct          vclk_dpi;
mux_struct          vclk_mux;
vid_struct          vclk_vid;
mon_struct          vclk_mon;

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

// Video run
    prt_dp_lib_cdc_bit
    VID_RUN_CDC_INST
    (
       .SRC_CLK_IN      (SYS_CLK_IN),
       .SRC_DAT_IN      (sclk_ctl.run),
       .DST_CLK_IN      (DPI_CLK_IN),
       .DST_DAT_OUT     (vclk_vid.run)
    );

// DPI input Registers
    always_ff @ (posedge DPI_CLK_IN)
    begin
        vclk_dpi.vs  <= DPI_VS_IN;
        vclk_dpi.hs  <= DPI_HS_IN;
        vclk_dpi.den <= DPI_DEN_IN;
        vclk_dpi.r   <= DPI_R_IN;
        vclk_dpi.g   <= DPI_G_IN;
        vclk_dpi.b   <= DPI_B_IN;    
    end

// DEN edge detector
// This used for the clock enable generator
    prt_dp_lib_edge
    DPI_DEN_EDGE_INST
    (
        .CLK_IN         (DPI_CLK_IN),       // Clock
        .CKE_IN         (1'b1),             // Clock enable
        .A_IN           (vclk_dpi.den),     // Input
        .RE_OUT         (),                 // Rising edge
        .FE_OUT         (vclk_dpi.den_fe)   // Falling edge
    );

// Clock enable generator
    always_ff @ (posedge DPI_CLK_IN)
    begin
        // Run
        if (vclk_vid.run)
        begin
            // Default
            vclk_vid.cke <= 0;

            // Set counter on falling edge DEN
            if (vclk_dpi.den_fe)
                vclk_vid.cke_cnt <= 'd1;
            
            else
            begin
                // Overflow
                if (vclk_vid.cke_cnt == 'd3)
                begin
                    vclk_vid.cke <= 1;
                    vclk_vid.cke_cnt <= 0;
                end

                // Increment
                else
                    vclk_vid.cke_cnt <= vclk_vid.cke_cnt + 'd1;
            end
        end

        // Idle
        else
        begin
            vclk_vid.cke <= 0;
            vclk_vid.cke_cnt <= 0;
        end
    end

// Pixel counter
    always_ff @ (posedge DPI_CLK_IN)
    begin
        // Active line
        if (!vclk_dpi.den)
        begin
            // Overflow
            if (vclk_vid.pix_cnt == 'd3)
                vclk_vid.pix_cnt <= 0;
            else
                vclk_vid.pix_cnt <= vclk_vid.pix_cnt + 'd1;
        end

        // Idle
        else
            vclk_vid.pix_cnt <= 0;
    end

    // MUX select CDC
    prt_dp_lib_cdc_vec
    #(
        .P_WIDTH ($size(vclk_mux.sel))
    )
    VID_MUX_SEL_INST
    (
        .SRC_CLK_IN     (SYS_CLK_IN),       // Clock
        .SRC_DAT_IN     (sclk_ctl.order),   // Data
        .DST_CLK_IN     (DPI_CLK_IN),       // Clock
        .DST_DAT_OUT    (vclk_mux.sel)      // Data
    );

// RGB order mux
// This mux allows to change the RGB order
    always_comb
    begin
        case (vclk_mux.sel)

            // BGR
            'd1 : 
            begin
                vclk_mux.r <= vclk_dpi.b;
                vclk_mux.g <= vclk_dpi.g;
                vclk_mux.b <= vclk_dpi.r;
            end                

            // GBR 
            'd2 : 
            begin
                vclk_mux.r <= vclk_dpi.g;
                vclk_mux.g <= vclk_dpi.b;
                vclk_mux.b <= vclk_dpi.r;
            end                

            // BRG
            'd3 : 
            begin
                vclk_mux.r <= vclk_dpi.b;
                vclk_mux.g <= vclk_dpi.r;
                vclk_mux.b <= vclk_dpi.g;
            end                

            // RGB
            default : 
            begin
                vclk_mux.r <= vclk_dpi.r;
                vclk_mux.g <= vclk_dpi.g;
                vclk_mux.b <= vclk_dpi.b;
            end                
        endcase
    end

// Pixel packer
    always_ff @ (posedge DPI_CLK_IN)
    begin
        case (vclk_vid.pix_cnt)
            'd1 : 
            begin
                vclk_vid.r[(1*8)+:8] <= vclk_mux.r;
                vclk_vid.g[(1*8)+:8] <= vclk_mux.g;
                vclk_vid.b[(1*8)+:8] <= vclk_mux.b;
            end

            'd2 : 
            begin
                vclk_vid.r[(2*8)+:8] <= vclk_mux.r;
                vclk_vid.g[(2*8)+:8] <= vclk_mux.g;
                vclk_vid.b[(2*8)+:8] <= vclk_mux.b;
            end

            'd3 : 
            begin
                vclk_vid.r[(3*8)+:8] <= vclk_mux.r;
                vclk_vid.g[(3*8)+:8] <= vclk_mux.g;
                vclk_vid.b[(3*8)+:8] <= vclk_mux.b;
            end

            default : 
            begin
                vclk_vid.r[(0*8)+:8] <= vclk_mux.r;
                vclk_vid.g[(0*8)+:8] <= vclk_mux.g;
                vclk_vid.b[(0*8)+:8] <= vclk_mux.b;
            end
        endcase
    end

// Video output registers
    always_ff @ (posedge DPI_CLK_IN)
    begin
        vclk_vid.vs <= vclk_dpi.vs;
        vclk_vid.hs <= vclk_dpi.hs;
        vclk_vid.de <= ~vclk_dpi.den;
    end

// VS edge detector
    prt_dp_lib_edge
    VID_VS_EDGE_INST
    (
        .CLK_IN         (DPI_CLK_IN),       // Clock
        .CKE_IN         (1'b1),             // Clock enable
        .A_IN           (vclk_vid.vs),      // Input
        .RE_OUT         (vclk_vid.vs_re),   // Rising edge
        .FE_OUT         ()                  // Falling edge
    );

// HS edge detector
    prt_dp_lib_edge
    VID_HS_EDGE_INST
    (
        .CLK_IN         (DPI_CLK_IN),       // Clock
        .CKE_IN         (1'b1),             // Clock enable
        .A_IN           (vclk_vid.hs),      // Input
        .RE_OUT         (vclk_vid.hs_re),   // Rising edge
        .FE_OUT         (vclk_vid.hs_fe)    // Falling edge
    );

// DEN edge detector
    prt_dp_lib_edge
    VID_DE_EDGE_INST
    (
        .CLK_IN         (DPI_CLK_IN),      // Clock
        .CKE_IN         (1'b1),            // Clock enable
        .A_IN           (vclk_vid.de),     // Input
        .RE_OUT         (vclk_vid.de_re),  // Rising edge
        .FE_OUT         (vclk_vid.de_fe)   // Falling edge
    );

// Monitor

// Htotal
    always_ff @ (posedge DPI_CLK_IN)
    begin
        // Run
        if (vclk_vid.run)
        begin
            if (vclk_vid.hs_re)
            begin
                vclk_mon.htotal_cnt <= 'd1;
                vclk_mon.htotal     <= vclk_mon.htotal_cnt;
            end

            else
                vclk_mon.htotal_cnt <= vclk_mon.htotal_cnt + 'd1;
        end

        // Idle
        else
        begin
            vclk_mon.htotal <= 0;
            vclk_mon.htotal_cnt <= 0;
        end
    end

// Hwidth
    always_ff @ (posedge DPI_CLK_IN)
    begin
        // Run
        if (vclk_vid.run)
        begin
            if (vclk_vid.de_fe)
            begin
                vclk_mon.hwidth_cnt <= 'd0;
                vclk_mon.hwidth     <= vclk_mon.hwidth_cnt;
            end

            else if (vclk_vid.de)
                vclk_mon.hwidth_cnt <= vclk_mon.hwidth_cnt + 'd1;
        end

        // Idle
        else
        begin
            vclk_mon.hwidth <= 0;
            vclk_mon.hwidth_cnt <= 0;
        end
    end

// Hstart
    always_ff @ (posedge DPI_CLK_IN)
    begin
        // Run
        if (vclk_vid.run)
        begin
            if (vclk_vid.de_re)
            begin
                vclk_mon.hstart     <= vclk_mon.hstart_cnt;
                vclk_mon.hstart_run <= 0;
                vclk_mon.hstart_arm <= 1;
            end

            else if (vclk_vid.hs_re)
            begin
                if (vclk_mon.hstart_arm)
                begin
                    vclk_mon.hstart_arm <= 0;
                    vclk_mon.hstart_run <= 1;
                end
                vclk_mon.hstart_cnt <= 'd1;
            end

            else if (vclk_mon.hstart_run)
                vclk_mon.hstart_cnt <= vclk_mon.hstart_cnt + 'd1;
        end

        // Idle
        else
        begin
            vclk_mon.hstart_arm <= 0;
            vclk_mon.hstart_run <= 0;
            vclk_mon.hstart <= 0;
            vclk_mon.hstart_cnt <= 0;
        end
    end

// Hsw
    always_ff @ (posedge DPI_CLK_IN)
    begin
        // Run
        if (vclk_vid.run)
        begin
            if (vclk_vid.hs_fe)
            begin
                vclk_mon.hsw_cnt <= 'd0;
                vclk_mon.hsw     <= vclk_mon.hsw_cnt;
            end

            else if (vclk_vid.hs)
                vclk_mon.hsw_cnt <= vclk_mon.hsw_cnt + 'd1;
        end

        // Idle
        else
        begin
            vclk_mon.hsw <= 0;
            vclk_mon.hsw_cnt <= 0;
        end
    end

// Vtotal
    always_ff @ (posedge DPI_CLK_IN)
    begin
        // Run
        if (vclk_vid.run)
        begin
            if (vclk_vid.vs_re)
            begin
                vclk_mon.vtotal_cnt <= 'd1;
                vclk_mon.vtotal     <= vclk_mon.vtotal_cnt;
            end

            else if (vclk_vid.hs_re)
                vclk_mon.vtotal_cnt <= vclk_mon.vtotal_cnt + 'd1;
        end

        // Idle
        else
        begin
            vclk_mon.vtotal <= 0;
            vclk_mon.vtotal_cnt <= 0;
        end
    end

// Vheight
    always_ff @ (posedge DPI_CLK_IN)
    begin
        // Run
        if (vclk_vid.run)
        begin
            if (vclk_vid.vs_re)
            begin
                vclk_mon.vheight_cnt <= 'd0;
                vclk_mon.vheight     <= vclk_mon.vheight_cnt;
            end

            else if (vclk_vid.de_re)
                vclk_mon.vheight_cnt <= vclk_mon.vheight_cnt + 'd1;
        end

        // Idle
        else
        begin
            vclk_mon.vheight <= 0;
            vclk_mon.vheight_cnt <= 0;
        end
    end

// Vstart
    always_ff @ (posedge DPI_CLK_IN)
    begin
        // Run
        if (vclk_vid.run)
        begin
            if (vclk_vid.vs_re)
            begin
                vclk_mon.vstart_cnt <= 'd0;
                vclk_mon.vstart     <= vclk_mon.vstart_cnt;
                vclk_mon.vstart_run <= 1;
            end

            else if (vclk_vid.hs_re && vclk_mon.vstart_run)
                vclk_mon.vstart_cnt <= vclk_mon.vstart_cnt + 'd1;
 
            else if (vclk_vid.de_re)
                vclk_mon.vstart_run <= 0;        
        end

        // Idle
        else
        begin
            vclk_mon.vstart_run <= 0;
            vclk_mon.vstart <= 0;
            vclk_mon.vstart_cnt <= 0;
        end
    end

// Vsw
    always_ff @ (posedge DPI_CLK_IN)
    begin
        // Run
        if (vclk_vid.run)
        begin
            if (vclk_vid.vs_re)
            begin
                vclk_mon.vsw_cnt <= 'd1;
                vclk_mon.vsw     <= vclk_mon.vsw_cnt;
            end

            else if (vclk_vid.vs && vclk_vid.hs_re)
                vclk_mon.vsw_cnt <= vclk_mon.vsw_cnt + 'd1;
        end

        // Idle
        else
        begin
            vclk_mon.vsw <= 0;
            vclk_mon.vsw_cnt <= 0;
        end
    end

// Htotal
    prt_dp_lib_cdc_vec
    #(
        .P_WIDTH ($size(vclk_mon.htotal))
    )
    SCLK_HTOTAL_VEC_INST
    (
        .SRC_CLK_IN     (DPI_CLK_IN),       // Clock
        .SRC_DAT_IN     (vclk_mon.htotal),  // Data
        .DST_CLK_IN     (SYS_CLK_IN),       // Clock
        .DST_DAT_OUT    (sclk_sta.htotal)   // Data
    );

// Hwidth
    prt_dp_lib_cdc_vec
    #(
        .P_WIDTH ($size(vclk_mon.hwidth))
    )
    SCLK_HWIDTH_VEC_INST
    (
        .SRC_CLK_IN     (DPI_CLK_IN),       // Clock
        .SRC_DAT_IN     (vclk_mon.hwidth),  // Data
        .DST_CLK_IN     (SYS_CLK_IN),       // Clock
        .DST_DAT_OUT    (sclk_sta.hwidth)   // Data
    );

// Hsw
    prt_dp_lib_cdc_vec
    #(
        .P_WIDTH ($size(vclk_mon.hsw))
    )
    SCLK_HSW_VEC_INST
    (
        .SRC_CLK_IN     (DPI_CLK_IN),       // Clock
        .SRC_DAT_IN     (vclk_mon.hsw),     // Data
        .DST_CLK_IN     (SYS_CLK_IN),       // Clock
        .DST_DAT_OUT    (sclk_sta.hsw)      // Data
    );

// Hstart
    prt_dp_lib_cdc_vec
    #(
        .P_WIDTH ($size(vclk_mon.hstart))
    )
    SCLK_HSTART_VEC_INST
    (
        .SRC_CLK_IN     (DPI_CLK_IN),       // Clock
        .SRC_DAT_IN     (vclk_mon.hstart),  // Data
        .DST_CLK_IN     (SYS_CLK_IN),       // Clock
        .DST_DAT_OUT    (sclk_sta.hstart)   // Data
    );

// Vtotal
    prt_dp_lib_cdc_vec
    #(
        .P_WIDTH ($size(vclk_mon.vtotal))
    )
    SCLK_VTOTAL_VEC_INST
    (
        .SRC_CLK_IN     (DPI_CLK_IN),       // Clock
        .SRC_DAT_IN     (vclk_mon.vtotal),  // Data
        .DST_CLK_IN     (SYS_CLK_IN),       // Clock
        .DST_DAT_OUT    (sclk_sta.vtotal)   // Data
    );

// Vheight
    prt_dp_lib_cdc_vec
    #(
        .P_WIDTH ($size(vclk_mon.vheight))
    )
    SCLK_Vheight_VEC_INST
    (
        .SRC_CLK_IN     (DPI_CLK_IN),       // Clock
        .SRC_DAT_IN     (vclk_mon.vheight),  // Data
        .DST_CLK_IN     (SYS_CLK_IN),       // Clock
        .DST_DAT_OUT    (sclk_sta.vheight)   // Data
    );

// Vsw
    prt_dp_lib_cdc_vec
    #(
        .P_WIDTH ($size(vclk_mon.vsw))
    )
    SCLK_VSW_VEC_INST
    (
        .SRC_CLK_IN     (DPI_CLK_IN),       // Clock
        .SRC_DAT_IN     (vclk_mon.vsw),     // Data
        .DST_CLK_IN     (SYS_CLK_IN),       // Clock
        .DST_DAT_OUT    (sclk_sta.vsw)      // Data
    );

// Vstart
    prt_dp_lib_cdc_vec
    #(
        .P_WIDTH ($size(vclk_mon.vstart))
    )
    SCLK_VSTART_VEC_INST
    (
        .SRC_CLK_IN     (DPI_CLK_IN),       // Clock
        .SRC_DAT_IN     (vclk_mon.vstart),  // Data
        .DST_CLK_IN     (SYS_CLK_IN),       // Clock
        .DST_DAT_OUT    (sclk_sta.vstart)   // Data
    );

// Outputs
    assign LB_IF.dout       = sclk_lb.dout;
    assign LB_IF.vld        = sclk_lb.vld;
    assign VID_CKE_OUT      = vclk_vid.cke;
    assign VID_VS_OUT       = vclk_vid.vs;
    assign VID_HS_OUT       = vclk_vid.hs;
    assign VID_R_OUT        = vclk_vid.r;
    assign VID_G_OUT        = vclk_vid.g;
    assign VID_B_OUT        = vclk_vid.b;
    assign VID_DE_OUT       = vclk_vid.de;

endmodule

`default_nettype wire
