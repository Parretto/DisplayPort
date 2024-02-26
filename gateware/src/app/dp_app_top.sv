/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP Application Top
    (c) 2021 - 2024 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Added scaler interface
    v1.2 - Updated RISC-V processor
    v1.3 - Added misc interface
    v1.4 - Added second VTB interface (for MST application)

    License
    =======
    This License will apply to the use of the IP-core (as defined in the License). 
    Please read the License carefully so that you know what your rights and obligations are when using the IP-core.
    The acceptance of this License constitutes a valid and binding agreement between Parretto and you for the use of the IP-core. 
    If you download and/or make any use of the IP-core you agree to be bound by this License. 
    The License is available for download and print at www.parretto.com/license
    Parretto grants you, as the Licensee, a free, non-exclusive, non-transferable, limited right to use the IP-core 
    solely for internal business purposes for the term and conditions of the License. 
    You are also allowed to create Modifications for internal business purposes, but explicitly only under the conditions of art. 3.2.
    You are, however, obliged to pay the License Fees to Parretto for the use of the IP-core, or any Modification, in, or embodied in, 
    a physical or non-tangible product or service that has substantial commercial, industrial or non-consumer uses. 
*/

`default_nettype none

module dp_app_top
#(
    parameter P_VENDOR          = "none",
    parameter P_SYS_FREQ        = 50_000_000,      // System frequency
    parameter P_HW_VER_MAJOR    = 1,   // Reference design version major
    parameter P_HW_VER_MINOR    = 0,   // Reference design minor
    parameter P_PIO_IN_WIDTH    = 32,
    parameter P_PIO_OUT_WIDTH   = 32,
    parameter P_ROM_SIZE        = 64,   // ROM size (in Kbytes)
    parameter P_RAM_SIZE        = 64,   // RAM size (in Kbytes)
    parameter P_ROM_INIT        = "none",
    parameter P_RAM_INIT        = "none",
    parameter P_AQUA            = 0         // Implement Aqua programmer
)
(
     // Reset and clock
    input wire                              RST_IN,
    input wire                              CLK_IN,

    // PIO
    input wire [P_PIO_IN_WIDTH-1:0]         PIO_DAT_IN,
    output wire [P_PIO_OUT_WIDTH-1:0]       PIO_DAT_OUT,
    
    // Uart
    input wire                              UART_RX_IN,
    output wire                             UART_TX_OUT,

    // I2C
    inout wire                              I2C_SCL_INOUT,
    inout wire                              I2C_SDA_INOUT,

    // Direct I2C Access
    output wire                             DIA_RDY_OUT,
    input wire [31:0]                       DIA_DAT_IN,
    input wire                              DIA_VLD_IN,

    // DPTX interface
    prt_dp_lb_if.lb_out                     DPTX_IF,
    input wire                              DPTX_IRQ_IN,

    // DPRX interface
    prt_dp_lb_if.lb_out                     DPRX_IF,
    input wire                              DPRX_IRQ_IN,

    // VTB interface
    prt_dp_lb_if.lb_out                     VTB0_IF,
    prt_dp_lb_if.lb_out                     VTB1_IF,

    // PHY interface
    prt_dp_lb_if.lb_out                     PHY_IF,

    // Scaler interface
    prt_dp_lb_if.lb_out                     SCALER_IF,

    // MISC interface
    prt_dp_lb_if.lb_out                     MISC_IF,

    // Aqua 
    input wire                              AQUA_SEL_IN,
    input wire                              AQUA_CTL_IN,
    input wire                              AQUA_CLK_IN,
    input wire                              AQUA_DAT_IN
);

// Parameters

// Simulation
localparam P_SIM =
// synthesis translate_off
(1) ? 1 :
// synthesis translate_on
0;

localparam P_ROM_SIZE_BYTES = P_ROM_SIZE * 1024;                     // ROM size in bytes
localparam P_ROM_ADR = $clog2(P_ROM_SIZE_BYTES);
localparam P_RAM_SIZE_BYTES = P_RAM_SIZE * 1024;                      // RAM size in bytes
localparam P_RAM_ADR = $clog2(P_RAM_SIZE_BYTES);
localparam P_UART_BEAT = P_SYS_FREQ / 115200; 
localparam P_TMR_BEAT = P_SYS_FREQ / 1_000_000;
localparam P_LB_MUX_PORTS = 11;

// Interfaces
prt_riscv_rom_if 
#(
     .P_ADR_WIDTH (P_ROM_ADR)
) rom_if();

prt_riscv_ram_if 
#(
     .P_ADR_WIDTH (32)
) ram_if_cpu();

prt_riscv_ram_if 
#(
     .P_ADR_WIDTH (P_RAM_ADR)
) ram_if_ram();

// Mux
prt_dp_lb_if
#(
  .P_ADR_WIDTH  (22)
)
lb_to_mux();

prt_dp_lb_if
#(
  .P_ADR_WIDTH  (16)
)
lb_from_mux[P_LB_MUX_PORTS]();

// Signals

// Reset
logic           clk_rst;

// CPU
wire            irq_to_cpu;

// Aqua
wire            rst_from_aqua;
wire            rom_str_from_aqua;
wire            rom_vld_from_aqua;
wire            ram_str_from_aqua;
wire            ram_vld_from_aqua;
wire [31:0]     dat_from_aqua;

// Logic

// Reset
    always_ff @ (posedge CLK_IN)
    begin
        // Simulation
        if (P_SIM)
            clk_rst <= RST_IN;
        
        else
            clk_rst <= (rst_from_aqua || RST_IN);
    end
	
// CPU
    prt_riscv_cpu
    #(
        .P_VENDOR               (P_VENDOR)          // Vendor
    )
    CPU_INST
    (
        // Clocks and reset
        .RST_IN                 (clk_rst),         // Reset
        .CLK_IN                 (CLK_IN),         // Clock

        // ROM interface
        .ROM_IF                 (rom_if),

        // RAM interface
        .RAM_IF                 (ram_if_cpu),

        // Interrupt
        .IRQ_IN                 (irq_to_cpu),
        
        // Status
        .STA_ERR_OUT            ()         // Error
    );

    // Data mapping
    assign ram_if_cpu.rd_vld = lb_to_mux.vld || ram_if_ram.rd_vld;
    assign ram_if_cpu.rd_dat = (lb_to_mux.vld) ? lb_to_mux.dout : ram_if_ram.rd_dat;

    // Interrupt
    assign irq_to_cpu = DPTX_IRQ_IN || DPRX_IRQ_IN;

    prt_riscv_rom
    #(
        .P_VENDOR       (P_VENDOR),    // Vendor "xilinx", "intel" or "lattice"
        .P_ADR          (P_ROM_ADR),   // Address bits
        .P_INIT_FILE    (P_ROM_INIT)   // Initilization file
    )
    ROM_INST
    (
        // Reset and clock
        .RST_IN         (RST_IN),      // Reset
        .CLK_IN         (CLK_IN),      // Clock

        // ROM interface
        .ROM_IF         (rom_if),

        // Initialization
        .INIT_STR_IN    (rom_str_from_aqua),    // Start
        .INIT_DAT_IN    (dat_from_aqua),        // Data
        .INIT_VLD_IN    (rom_vld_from_aqua)     // Valid
    );

// RAM
    prt_riscv_ram
    #(
        .P_VENDOR       (P_VENDOR),     // Vendor "xilinx", "intel" or "lattice"
        .P_ADR          (P_RAM_ADR),    // Address bits
        .P_INIT_FILE    (P_RAM_INIT)    // Initilization file
    )
    RAM_INST
    (
        // Reset and clock
        .RST_IN         (RST_IN),      // Reset
        .CLK_IN         (CLK_IN),   // Clock

        // RAM interface
        .RAM_IF         (ram_if_ram),

        // Initialization
        .INIT_STR_IN    (ram_str_from_aqua),    // Start
        .INIT_DAT_IN    (dat_from_aqua),        // Data
        .INIT_VLD_IN    (ram_vld_from_aqua)     // Valid
    );

    assign ram_if_ram.adr       = ram_if_cpu.adr[0+:$size(ram_if_ram.adr)];
    assign ram_if_ram.wr        = ~ram_if_cpu.adr[31] && ram_if_cpu.wr;
    assign ram_if_ram.rd        = ~ram_if_cpu.adr[31] && ram_if_cpu.rd;
    assign ram_if_ram.wr_dat    = ram_if_cpu.wr_dat;
    assign ram_if_ram.wr_strb   = ram_if_cpu.wr_strb;

// LB MUX
    prt_lb_mux
    #(
        .P_PORTS            (P_LB_MUX_PORTS)
    )
    MUX_INST
    (
        // Reset and clock
        .RST_IN             (clk_rst),
        .CLK_IN             (CLK_IN),

        // Up stream
        .LB_UP_IF           (lb_to_mux),

        // Down stream
        .LB_DWN_IF0         (lb_from_mux[0]),
        .LB_DWN_IF1         (lb_from_mux[1]),
        .LB_DWN_IF2         (lb_from_mux[2]),
        .LB_DWN_IF3         (lb_from_mux[3]),
        .LB_DWN_IF4         (lb_from_mux[4]),
        .LB_DWN_IF5         (lb_from_mux[5]),
        .LB_DWN_IF6         (lb_from_mux[6]),
        .LB_DWN_IF7         (lb_from_mux[7]),
        .LB_DWN_IF8         (lb_from_mux[8]),
        .LB_DWN_IF9         (lb_from_mux[9]),
        .LB_DWN_IF10        (lb_from_mux[10])
    );
   
    // Upstream
    assign lb_to_mux.adr = ram_if_cpu.adr[2+:22];
    assign lb_to_mux.din = ram_if_cpu.wr_dat;
    assign lb_to_mux.wr = ram_if_cpu.adr[31] && ram_if_cpu.wr;
    assign lb_to_mux.rd = ram_if_cpu.adr[31] && ram_if_cpu.rd;

// PIO
    prt_dp_pm_pio
    #(
        .P_HW_VER_MAJOR     (P_HW_VER_MAJOR),   // Reference design version major
        .P_HW_VER_MINOR     (P_HW_VER_MINOR),   // Reference design minor
        .P_IN_WIDTH         (P_PIO_IN_WIDTH),
        .P_OUT_WIDTH        (P_PIO_OUT_WIDTH)
    )
    PIO_INST
    (
        // Clock and reset
        .RST_IN             (clk_rst),
        .CLK_IN             (CLK_IN),

        // Local bus
        .LB_IF              (lb_from_mux[0]),

        // PIO
        .PIO_DAT_IN         (PIO_DAT_IN),
        .PIO_DAT_OUT        (PIO_DAT_OUT),
        
        // Interrupt
        .IRQ_OUT            ()
    );

// UART
    prt_uart
    #(
        .P_VENDOR           (P_VENDOR),
        .P_SIM              (P_SIM),
        .P_BEAT             (P_UART_BEAT)
    )
    UART_INST
    (
        // Reset and clock
        .RST_IN             (clk_rst),
        .CLK_IN             (CLK_IN),

        // Local bus interface
        .LB_IF              (lb_from_mux[1]),

        // UART
        .UART_RX_IN         (UART_RX_IN),      // Receive
        .UART_TX_OUT        (UART_TX_OUT)      // Transmit
    );

// Timer
    prt_dp_pm_tmr
    #(
        .P_SIM             (P_SIM),
        .P_BEAT            (P_TMR_BEAT)     // Beat value
    )
    TMR_INST
    (
        // Clock and reset
        .RST_IN            (clk_rst),
        .CLK_IN            (CLK_IN),

        // Local bus
        .LB_IF             (lb_from_mux[2]),

        // Beat
        .BEAT_OUT          (), 

        // Interrupt
        .IRQ_OUT           ()
    );

// I2C
    prt_i2c
    I2C_INST
    (
        // Reset and clock
        .RST_IN             (clk_rst),
        .CLK_IN             (CLK_IN),

        // Local bus interface
        .LB_IF              (lb_from_mux[3]),

        // Direct I2C Access
        .DIA_RDY_OUT        (DIA_RDY_OUT),
        .DIA_DAT_IN         (DIA_DAT_IN),
        .DIA_VLD_IN         (DIA_VLD_IN),

        // I2C
        .I2C_SCL_INOUT      (I2C_SCL_INOUT),      // SCL
        .I2C_SDA_INOUT      (I2C_SDA_INOUT)       // SDA
    );

// Aqua programmer
generate
    if (P_AQUA == 1)
    begin : gen_aqua
        prt_aqua
        AQUA_INST
        (
            // Reset and clock
            .RST_IN             (RST_IN),
            .CLK_IN             (CLK_IN),

            // Aqua 
            .AQUA_SEL_IN        (AQUA_SEL_IN),
            .AQUA_CTL_IN        (AQUA_CTL_IN),
            .AQUA_CLK_IN        (AQUA_CLK_IN),
            .AQUA_DAT_IN        (AQUA_DAT_IN),

            // Initialization
            .INIT_RST_OUT       (rst_from_aqua),
            .INIT_ROM_STR_OUT   (rom_str_from_aqua),
            .INIT_ROM_VLD_OUT   (rom_vld_from_aqua),
            .INIT_RAM_STR_OUT   (ram_str_from_aqua),
            .INIT_RAM_VLD_OUT   (ram_vld_from_aqua),
            .INIT_DAT_OUT       (dat_from_aqua)
        );
    end

    else
    begin
        assign rst_from_aqua = 1'b0;
        assign rom_str_from_aqua = 1'b0;
        assign rom_vld_from_aqua = 1'b0;
        assign ram_str_from_aqua = 1'b0;
        assign ram_vld_from_aqua = 1'b0;
        assign dat_from_aqua = 32'd0;
    end

endgenerate

// DPTX interface
    assign DPTX_IF.adr          = lb_from_mux[4].adr;
    assign DPTX_IF.wr           = lb_from_mux[4].wr;
    assign DPTX_IF.rd           = lb_from_mux[4].rd;
    assign DPTX_IF.din          = lb_from_mux[4].din;
    assign lb_from_mux[4].dout  = DPTX_IF.dout;
    assign lb_from_mux[4].vld   = DPTX_IF.vld;

// DPRX interface
    assign DPRX_IF.adr          = lb_from_mux[5].adr;
    assign DPRX_IF.wr           = lb_from_mux[5].wr;
    assign DPRX_IF.rd           = lb_from_mux[5].rd;
    assign DPRX_IF.din          = lb_from_mux[5].din;
    assign lb_from_mux[5].dout  = DPRX_IF.dout;
    assign lb_from_mux[5].vld   = DPRX_IF.vld;

// VTB0 interface
    assign VTB0_IF.adr          = lb_from_mux[6].adr;
    assign VTB0_IF.wr           = lb_from_mux[6].wr;
    assign VTB0_IF.rd           = lb_from_mux[6].rd;
    assign VTB0_IF.din          = lb_from_mux[6].din;
    assign lb_from_mux[6].dout  = VTB0_IF.dout;
    assign lb_from_mux[6].vld   = VTB0_IF.vld;

// VTB0 interface
    assign VTB1_IF.adr          = lb_from_mux[7].adr;
    assign VTB1_IF.wr           = lb_from_mux[7].wr;
    assign VTB1_IF.rd           = lb_from_mux[7].rd;
    assign VTB1_IF.din          = lb_from_mux[7].din;
    assign lb_from_mux[7].dout  = VTB1_IF.dout;
    assign lb_from_mux[7].vld   = VTB1_IF.vld;

// PHY interface
    assign PHY_IF.adr           = lb_from_mux[8].adr;
    assign PHY_IF.wr            = lb_from_mux[8].wr;
    assign PHY_IF.rd            = lb_from_mux[8].rd;
    assign PHY_IF.din           = lb_from_mux[8].din;
    assign lb_from_mux[8].dout  = PHY_IF.dout;
    assign lb_from_mux[8].vld   = PHY_IF.vld;

// Scaler interface
    assign SCALER_IF.adr        = lb_from_mux[9].adr;
    assign SCALER_IF.wr         = lb_from_mux[9].wr;
    assign SCALER_IF.rd         = lb_from_mux[9].rd;
    assign SCALER_IF.din        = lb_from_mux[9].din;
    assign lb_from_mux[9].dout  = SCALER_IF.dout;
    assign lb_from_mux[9].vld   = SCALER_IF.vld;

// Misc interface
    assign MISC_IF.adr          = lb_from_mux[10].adr;
    assign MISC_IF.wr           = lb_from_mux[10].wr;
    assign MISC_IF.rd           = lb_from_mux[10].rd;
    assign MISC_IF.din          = lb_from_mux[10].din;
    assign lb_from_mux[10].dout  = MISC_IF.dout;
    assign lb_from_mux[10].vld   = MISC_IF.vld;

endmodule

`default_nettype wire
