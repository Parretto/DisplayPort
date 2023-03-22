/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 

    DP application testbench
    Written by Marco Groeneveld
    (c) 2021 - 2023 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
*/

`timescale 1ns / 1ps
`default_nettype none

module dp_tst ();

// Parameters
//localparam P_VENDOR = "xilinx";         // Vendor
localparam P_VENDOR = "lattice";         // Vendor
localparam P_SYS_FREQ = 'd100000000;    // System frequency
localparam P_BEAT = 'd25;               // Beat value
localparam P_LANES = 4;                 // Lanes

localparam P_DATA_MODE  = "quad";                               // Data path mode; dual - 2 pixels per clock / 2 symbols per lane / quad - 4 pixels per clock / 4 symbols per lane
localparam P_SPL        = (P_DATA_MODE == "dual") ? 2 : 4;      // Symbols per lane. Valid options - 2, 4. 
localparam P_PPC        = (P_DATA_MODE == "dual") ? 2 : 4;      // Pixels per clock. Valid options - 2, 4.
localparam P_BPC        = 8;                                    // Bits per component. Valid option - 8
localparam P_AXI_WIDTH  = (P_DATA_MODE == "dual") ? 48 : 96;

//localparam P_VID_CLK_PERIOD = (P_PPC == 2) ? 6.734ns : 13.468ns; // 1080p60
 localparam P_VID_CLK_PERIOD = (P_PPC == 2) ? 1.683ns : 3.367ns; // 4kp60

// PHY
localparam P_PHY_LINERATE = 54;          // PHY bandwidth 27=2.7 Gbps / 54=5.4 Gbps
localparam P_PHY_CLK_PERIOD = (P_PHY_LINERATE == 54) ? ((P_SPL == 2) ? 1.8518ns : 3.7036ns) : ((P_SPL == 2) ? 3.7036ns : 7.4072);
localparam int P_PHY_DLY[0:3] = {1, 1, 1, 1};

localparam P_PIO_IN_WIDTH   = 13;
localparam P_PIO_OUT_WIDTH  = 21;

localparam P_ROM_INIT = (P_VENDOR == "xilinx") ? "../../software/build/sim/bin/dp_sim_rom.mem" : "none";
localparam P_RAM_INIT = (P_VENDOR == "xilinx") ? "../../software/build/sim/bin/dp_sim_ram.mem" : "none";

// Interfaces

// DPTX
prt_dp_lb_if
#(
  .P_ADR_WIDTH  (16)
)
dptx_if();

// DPRX
prt_dp_lb_if
#(
  .P_ADR_WIDTH  (16)
)
dprx_if();

// VTB
prt_dp_lb_if
#(
  .P_ADR_WIDTH  (16)
)
vtb_if[2]();

// Scaler
prt_dp_lb_if
#(
  .P_ADR_WIDTH  (16)
)
scaler_if();

// Misc
prt_dp_lb_if
#(
  .P_ADR_WIDTH  (16)
)
misc_if();

// Signals

// Clock and reset
logic sys_rst;
logic sys_clk;
logic lnk_clk;
logic tx_vid_clk;
logic rx_vid_clk;

// PIO
wire [P_PIO_IN_WIDTH-1:0]       pio_dat_to_app;
wire [P_PIO_OUT_WIDTH-1:0]      pio_dat_from_app;
wire                            dptx_rst_from_app;
wire                            dprx_rst_from_app;

// UART
wire uart;

// I2C
wire i2c_scl;
wire i2c_sda;
pullup (i2c_scl);
pullup (i2c_sda);

// DPTX
wire rst_to_dptx;
wire irq_from_dptx;
wire aux_from_dptx;
wire [(P_LANES * P_SPL * 11)-1:0] lnk_dat_from_dptx;

// DPRX
wire rst_to_dprx;
wire irq_from_dprx;
wire hpd_from_dprx;
wire aux_from_dprx;
wire [(P_LANES * P_SPL * 9)-1:0]  lnk_dat_to_dprx;
wire            vid_sof_from_dprx;  // Start of frame
wire            vid_eol_from_dprx;  // End of line
wire [P_AXI_WIDTH-1:0]     vid_dat_from_dprx; // Data
wire            vid_vld_from_dprx;  // Valid       
wire            sync_from_dprx;

// PHY
wire [(P_LANES * P_SPL * 11)-1:0] lnk_dat_from_phy;

// TX VTB 
wire                        vs_from_vtb;
wire                        hs_from_vtb;
wire [(P_PPC*P_BPC)-1:0]    r_from_vtb;
wire [(P_PPC*P_BPC)-1:0]    g_from_vtb;
wire [(P_PPC*P_BPC)-1:0]    b_from_vtb;
wire                        de_from_vtb;
wire                        lock_from_vtb;

// DIA
wire            dia_rdy_from_app;
wire [31:0]     dia_dat_from_vtb;
wire            dia_vld_from_vtb;

genvar i, j;

// System clock 100 MHz
initial
begin
    sys_clk <= 0;
    forever
        #5ns sys_clk <= ~sys_clk;
end

// Reset
initial
begin
    sys_rst <= 1;
    #500ns
    sys_rst <= 0;
end

// Link clock 
// The PHY is operating in two symbols per clock. 
initial
begin
    lnk_clk <= 0;
    forever
        #P_PHY_CLK_PERIOD lnk_clk <= ~lnk_clk; 
        //#3.7037ns lnk_clk <= ~lnk_clk; #2.7 Gbps
end

// Video reference clock 297 MHz
// The reference clock is used by the RX VTB
//initial
//begin
//    tx_vid_clk <= 0;
//    forever
//        #1.6835ns tx_vid_clk <= ~tx_vid_clk;
//end

// Video 74.25 MHz
// The video clock is used by the TX VTB
initial
begin
    tx_vid_clk <= 0;
    forever
        #P_VID_CLK_PERIOD tx_vid_clk <= ~tx_vid_clk;
end

// Video 74.25 MHz
// The video clock is used by the RX VTB
initial
begin
    rx_vid_clk <= 0;
    forever
        #P_VID_CLK_PERIOD rx_vid_clk <= ~rx_vid_clk;
//        #6.800ns rx_vid_clk <= ~rx_vid_clk;     // Video clock is slower
//        #6.700ns rx_vid_clk <= ~rx_vid_clk;     // Video clock is faster
end


// Global reset module
// This is needed by some of the Lattice memory modules
    GSR
    GSR_INST
    (
        .GSR_N (~sys_rst),  
        .CLK   (sys_clk)  
    );

// Application
     dp_app_top
     #(
        .P_VENDOR (P_VENDOR),
        .P_SYS_FREQ (P_SYS_FREQ),
        .P_ROM_INIT (P_ROM_INIT),
        .P_RAM_INIT (P_RAM_INIT)
     )
     APP_INST
     (
        // Reset and clock
        .RST_IN        (sys_rst),
        .CLK_IN        (sys_clk),

        // PIO
        .PIO_DAT_IN     (pio_dat_to_app),
        .PIO_DAT_OUT    (pio_dat_from_app),

        // Uart
        .UART_RX_IN    (uart),
        .UART_TX_OUT   (uart),

        // I2C
        .I2C_SCL_INOUT  (i2c_scl),
        .I2C_SDA_INOUT  (i2c_sda),

        // Direct I2C Access
        .DIA_RDY_OUT    (dia_rdy_from_app),
        .DIA_DAT_IN     (dia_dat_from_vtb),
        .DIA_VLD_IN     (dia_vld_from_vtb),

        // DPTX interface
        .DPTX_IF        (dptx_if),
        .DPTX_IRQ_IN    (irq_from_dptx),

        // DPRX interface
        .DPRX_IF        (dprx_if),
        .DPRX_IRQ_IN    (irq_from_dprx),

        // VTB interface (VTB TX)
        .VTB_IF         (vtb_if[0]),

        // PHY interface
        // In simulation the PHY interface is used for the VTB RX
        .PHY_IF         (vtb_if[1]),

        // Scaler interface
        // Not used
        .SCALER_IF      (scaler_if),

        // Misc interface
        // Not used
        .MISC_IF        (misc_if),

        // Aqua
        .AQUA_SEL_IN   (1'b0),
        .AQUA_CTL_IN   (1'b0),
        .AQUA_CLK_IN   (1'b0),
        .AQUA_DAT_IN   (1'b0)
     );

    // PIO in mapping
    assign pio_dat_to_app = 0;

    // PIO out mapping
    assign dptx_rst_from_app        = pio_dat_from_app[1];
    assign dprx_rst_from_app        = pio_dat_from_app[2];

// TX Video toolbox
    prt_vtb_top
    #(
        .P_VENDOR           (P_VENDOR),
        .P_SYS_FREQ         (P_SYS_FREQ),
        .P_PPC              (P_PPC),        // Pixels per clock
        .P_BPC              (P_BPC),        // Bits per component
        .P_AXIS_DAT         (48)
    )
    TX_VTB_INST
    (
        // System
        .SYS_RST_IN         (rst_to_dptx),
        .SYS_CLK_IN         (sys_clk),

        // Local bus
        .LB_IF              (vtb_if[0]),

        // Direct I2C Access
        .DIA_RDY_IN         (1'b0),
        .DIA_DAT_OUT        (),
        .DIA_VLD_OUT        (),

        // Link
        .TX_LNK_CLK_IN      (lnk_clk),           // TX link clock
        .RX_LNK_CLK_IN      (lnk_clk),           // RX link clock
        .LNK_SYNC_IN        (1'b0),
        
        // Axi-stream Video
        .AXIS_SOF_IN        (1'b0),  // Start of frame
        .AXIS_EOL_IN        (1'b0),  // End of line
        .AXIS_DAT_IN        (48'd0),  // Data
        .AXIS_VLD_IN        (1'b0),  // Valid       

        // Native video
        .VID_CLK_IN         (tx_vid_clk),
        .VID_CKE_IN         (1'b1),
        .VID_LOCK_OUT       (lock_from_vtb),
        .VID_VS_OUT         (vs_from_vtb),
        .VID_HS_OUT         (hs_from_vtb),
        .VID_R_OUT          (r_from_vtb),
        .VID_G_OUT          (g_from_vtb),
        .VID_B_OUT          (b_from_vtb),
        .VID_DE_OUT         (de_from_vtb)
    );

// DPTX
    prt_dptx_top
    #(
        // System
        .P_VENDOR           (P_VENDOR),     // Vendor
        .P_BEAT             (P_BEAT),       // Beat value

        // Link
        .P_LANES            (P_LANES),      // Lanes
        .P_SPL              (P_SPL),        // Symbols per lane

        // Video
        .P_PPC              (P_PPC),        // Pixels per clock
        .P_BPC              (P_BPC)         // Bits per component
    )
    DPTX_INST
    (
        // Reset and Clock
        .SYS_RST_IN         (rst_to_dptx),
        .SYS_CLK_IN         (sys_clk),

        // Host
        .HOST_IF            (dptx_if),
        .HOST_IRQ_OUT       (irq_from_dptx),

        // AUX
        .AUX_EN_OUT         (),
        .AUX_TX_OUT         (aux_from_dptx),
        .AUX_RX_IN          (aux_from_dprx),

        // Misc
        .HPD_IN             (hpd_from_dprx),
        .HB_OUT             (),

        // Video
        .VID_CLK_IN         (tx_vid_clk),       // Clock
        .VID_CKE_IN         (1'b1),             // Clock enable
        .VID_VS_IN          (vs_from_vtb),      // Vsync
        .VID_HS_IN          (hs_from_vtb),      // Hsync
        .VID_R_IN           (r_from_vtb),       // Red
        .VID_G_IN           (g_from_vtb),       // Green
        .VID_B_IN           (b_from_vtb),       // Blue
        .VID_DE_IN          (de_from_vtb),      // Data enable

        // Link
        .LNK_CLK_IN         (lnk_clk),          // Clock
        .LNK_DAT_OUT        (lnk_dat_from_dptx)   // Data
    );

    // Reset
    assign rst_to_dptx = sys_rst || dptx_rst_from_app;

// PHY
generate
    for (i = 0; i < P_LANES; i++)
    begin
        dp_phy
        #(
            .P_LANE (i),                // Lane index
            .P_DLY  (P_PHY_DLY[i]),     // Delay in words; The minimum delay is 2
            .P_SPL  (P_SPL)             // Sublanes per lane
        )
        DP_PHY_INST
        (
            .CLK_IN     (lnk_clk),
            .DAT_IN     (lnk_dat_from_dptx[(i*P_SPL*11) +: P_SPL*11]),
            .DAT_OUT    (lnk_dat_from_phy[(i*P_SPL*11) +: P_SPL*11])
        );
    end
endgenerate

// DPRX
    prt_dprx_top
    #(
        // System
        .P_VENDOR           (P_VENDOR),     // Vendor
        .P_BEAT             (P_BEAT),       // Beat value

        // Link
        .P_LANES            (P_LANES),      // Lanes
        .P_SPL              (P_SPL),        // Symbols per lane

        // Video
        .P_PPC              (P_PPC),        // Pixels per clock
        .P_BPC              (P_BPC),        // Bits per component
        .P_VID_DAT          (P_AXI_WIDTH)
    )
    DPRX_INST
    (
        // Reset and Clock
        .SYS_RST_IN         (rst_to_dprx),
        .SYS_CLK_IN         (sys_clk),

        // Host
        .HOST_IF            (dprx_if),
        .HOST_IRQ_OUT       (irq_from_dprx),

        // AUX
        .AUX_EN_OUT         (),
        .AUX_TX_OUT         (aux_from_dprx),
        .AUX_RX_IN          (aux_from_dptx),

        // Misc
        .HPD_OUT            (hpd_from_dprx),
        .HB_OUT             (),

        // Link
        .LNK_CLK_IN         (lnk_clk),            // Clock
        .LNK_DAT_IN         (lnk_dat_to_dprx),    // Data
        .LNK_SYNC_OUT       (sync_from_dprx),     // Sync

        // Video
        .VID_CLK_IN         (rx_vid_clk),         // Clock
        .VID_RDY_IN         (1'b1),               // Ready
        .VID_SOF_OUT        (vid_sof_from_dprx),  // Start of frame
        .VID_EOL_OUT        (vid_eol_from_dprx),  // End of line
        .VID_DAT_OUT        (vid_dat_from_dprx),  // Data
        .VID_VLD_OUT        (vid_vld_from_dprx)   // Valid
    );

    // Reset
    assign rst_to_dprx = sys_rst || dprx_rst_from_app;

// RX Video toolbox
    prt_vtb_top
    #(
        .P_VENDOR           (P_VENDOR),
        .P_SYS_FREQ         (P_SYS_FREQ),
        .P_PPC              (P_PPC),        // Pixels per clock
        .P_BPC              (P_BPC),        // Bits per component
        .P_AXIS_DAT         (P_AXI_WIDTH)
    )
    RX_VTB_INST
    (
        // System
        .SYS_RST_IN         (rst_to_dprx),
        .SYS_CLK_IN         (sys_clk),

        // Local bus
        .LB_IF              (vtb_if[1]),

        // Direct I2C Access
        .DIA_RDY_IN         (dia_rdy_from_app),
        .DIA_DAT_OUT        (dia_dat_from_vtb),
        .DIA_VLD_OUT        (dia_vld_from_vtb),

        // Link
        .TX_LNK_CLK_IN      (lnk_clk),           // TX link clock
        .RX_LNK_CLK_IN      (lnk_clk),           // RX link clock

        .LNK_SYNC_IN        (sync_from_dprx),

        // Axi-stream Video
        .AXIS_SOF_IN        (vid_sof_from_dprx),  // Start of frame
        .AXIS_EOL_IN        (vid_eol_from_dprx),  // End of line
        .AXIS_DAT_IN        (vid_dat_from_dprx),  // Data
        .AXIS_VLD_IN        (vid_vld_from_dprx),  // Valid       

        // Native video
        .VID_CLK_IN         (rx_vid_clk),
        .VID_CKE_IN         (1'b1),
        .VID_LOCK_OUT       (),
        .VID_VS_OUT         (),
        .VID_HS_OUT         (),
        .VID_R_OUT          (),
        .VID_G_OUT          (),
        .VID_B_OUT          (),
        .VID_DE_OUT         ()
    );

// PHY
generate
    for (i = 0; i < P_LANES; i++)
    begin
        for (j = 0; j < P_SPL; j++)
            assign lnk_dat_to_dprx[((i*P_SPL*9)+(j*9))+:9] = {lnk_dat_from_phy[((i*P_SPL*11)+(j*11))+:9]};
    end
endgenerate

endmodule

`default_nettype wire
