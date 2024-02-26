/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP PM Top
    (c) 2021 - 2024 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Added MST feature

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

`timescale 1ns/1ns

`default_nettype none

module prt_dp_pm_top
#
(
    parameter                           P_VENDOR        = "none",  // Vendor "xilinx" or "lattice"
    parameter                           P_BEAT          = 'd125,     // Beat value
    parameter                           P_HW_VER_MAJOR  = 1,         // Hardware version major
    parameter                           P_HW_VER_MINOR  = 0,         // Hardware version minor
    parameter                           P_CFG           = "tx",      // Configuration TX / RX
    parameter                           P_SIM           = 0,
    parameter                           P_ROM_INIT_FILE = "none",
    parameter                           P_RAM_INIT_FILE = "none",
    parameter                           P_PIO_IN_WIDTH  = 8,
    parameter                           P_PIO_OUT_WIDTH = 8,
    parameter                           P_SPL = 2,                   // Symbols per lane
    parameter                           P_MST = 0                    // MST
)
(
    // Reset and clock
    input wire                          RST_IN,
    input wire                          CLK_IN,

    // Interrupt
    input wire [1:0]                    IRQ_IN,

    // PIO
    input wire [P_PIO_IN_WIDTH-1:0]     PIO_IN,
    output wire [P_PIO_OUT_WIDTH-1:0]   PIO_OUT,

    // Host
    prt_dp_lb_if.lb_in                  HOST_IF,
    output wire                         HOST_IRQ_OUT, 

    // HPD
    input wire                          HPD_IN,
    output wire                         HPD_OUT,

    // AUX
    output wire                         AUX_EN_OUT,
    output wire                         AUX_TX_OUT,
    input wire                          AUX_RX_IN,

    // Message 
    prt_dp_msg_if.src                   MSG_SRC_IF,
    prt_dp_msg_if.snk                   MSG_SNK_IF
);

// Localparam
localparam P_MAX_DEV        = 8;
localparam P_MAX_DEV_ADR    = $clog2(P_MAX_DEV) + 1;
localparam P_RAM_BASE       = 'h0;      // 0x8000
localparam P_PIO_BASE       = 'h1;      // 0xc100
localparam P_TMR_BASE       = 'h2;      // 0xc200
localparam P_IRQ_BASE       = 'h3;      // 0xc300
localparam P_EXCH_BASE      = 'h4;      // 0xc400
localparam P_HPD_BASE       = 'h5;      // 0xc500
localparam P_AUX_BASE       = 'h6;      // 0xc600
localparam P_MSG_BASE       = 'h7;      // 0xc700
localparam P_MUTEX_BASE     = 'h8;      // 0xc800

localparam P_ROM_SIZE       = (P_MST) ? 32*1024 : 16*1024;  // ROM size : MST - 32KBytes / SST - 16KBytes
localparam P_ROM_ADR        = $clog2(P_ROM_SIZE)-2;         // ROM address in words
localparam P_RAM_SIZE       = 4*1024;                       // RAM size : 4KBytes
localparam P_RAM_ADR        = $clog2(P_RAM_SIZE)-2;         // RAM address in words

localparam P_PIO_IN_WIDTH_INT  = P_PIO_IN_WIDTH + 3;        // Internal PIO in width
localparam P_PIO_OUT_WIDTH_INT = P_PIO_OUT_WIDTH + 3;       // Internal PIO out width

// Signals

// Hart ROM
prt_dp_rom_if
#(
  .P_ADR_WIDTH  (16)
)
hart_rom_if();

// Hart RAM
prt_dp_ram_if
#(
  .P_ADR_WIDTH  (16)
)
hart_ram_if();

wire [3:0]  thread_en_to_hart;

// ROM
prt_dp_rom_if
#(
  .P_ADR_WIDTH  (P_ROM_ADR)
)
rom_if();

// RAM
prt_dp_ram_if
#(
  .P_ADR_WIDTH  (P_RAM_ADR)
)
ram_if();

// PIO
prt_dp_lb_if
#(
  .P_ADR_WIDTH  (4)
)
pio_lb();

wire [P_PIO_OUT_WIDTH_INT-1:0]   dat_from_pio;
wire [P_PIO_IN_WIDTH_INT-1:0]    dat_to_pio;
wire irq_from_pio;

// Timer
prt_dp_lb_if
#(
  .P_ADR_WIDTH  (3)
)
tmr_lb();

wire beat_from_tmr;
wire irq_from_tmr;

// IRQ
prt_dp_lb_if
#(
  .P_ADR_WIDTH  (2)
)
irq_lb();

wire [7:0]  irq_to_irq;

// Exchange
prt_dp_lb_if
#(
  .P_ADR_WIDTH  (3)
)
exch_lb();

wire            rst_from_exch;
wire            irq_from_exch;
wire            mem_str_from_exch;
wire [31:0]     mem_dat_from_exch;
wire [1:0]      mem_vld_from_exch;

// HPD
prt_dp_lb_if
#(
  .P_ADR_WIDTH  (2)
)
hpd_lb();

wire irq_from_hpd;

// AUX
prt_dp_lb_if
#(
  .P_ADR_WIDTH  (2)
)
aux_lb();

wire irq_from_aux;

// MSG
prt_dp_lb_if
#(
  .P_ADR_WIDTH  (3)
)
msg_lb();

wire    irq_from_msg;

// Mutex
prt_dp_lb_if
#(
  .P_ADR_WIDTH  (2)
)
mutex_lb();

// HART
    prt_dp_pm_hart
    #(
        .P_VENDOR              (P_VENDOR)
    )
    HART_INST
    (
    	// Clocks and reset
    	.RST_IN                (rst_from_exch),	// Reset
    	.CLK_IN                (CLK_IN),		// Clock

    	// ROM interface
    	.ROM_IF                (hart_rom_if),

    	// RAM interface
    	.RAM_IF                (hart_ram_if),

        // Config
        .CFG_THREAD_EN_IN      (thread_en_to_hart),    // Thread enable

    	// Status
    	.STA_ERR_OUT           ()		// Error
    );

    // Thread enable
    // Thread 0 is always running
    assign thread_en_to_hart = {dat_from_pio[0+:3], 1'b1};

    // ROM
    assign hart_rom_if.dat = rom_if.dat;

// ROM
    prt_dp_pm_rom
    #(
        .P_VENDOR       (P_VENDOR),         // Vendor
        .P_ADR          (P_ROM_ADR),        // Address bits
        .P_INIT_FILE    (P_ROM_INIT_FILE)   // Init file
    )
    ROM_INST
    (
        // Clock
    	.CLK_IN        (CLK_IN),			// Clock

    	// ROM interface
    	.ROM_IF        (rom_if),

        // Initialization
        .INIT_STR_IN   (mem_str_from_exch),    // Start
        .INIT_DAT_IN   (mem_dat_from_exch),    // Data
        .INIT_VLD_IN   (mem_vld_from_exch[0])  // Valid
    );

    assign rom_if.adr = hart_rom_if.adr[2+:P_ROM_ADR];

// RAM
    prt_dp_pm_ram
    #(
        .P_VENDOR       (P_VENDOR),         // Vendor
        .P_ADR          (P_RAM_ADR),        // Address bits
        .P_INIT_FILE    (P_RAM_INIT_FILE)   // Init file
    )
    RAM_INST
    (
        // Clock
    	.CLK_IN        (CLK_IN),			// Clock

    	// ROM interface
    	.RAM_IF        (ram_if),

        // Initialization
        .INIT_STR_IN   (mem_str_from_exch),    // Start
        .INIT_DAT_IN   (mem_dat_from_exch),    // Data
        .INIT_VLD_IN   (mem_vld_from_exch[1])  // Valid
    );

    assign ram_if.wr_adr    = hart_ram_if.wr_adr[2+:P_RAM_ADR];
    assign ram_if.rd_adr    = hart_ram_if.rd_adr[2+:P_RAM_ADR];
    assign ram_if.din       = hart_ram_if.dout;
    assign ram_if.wr        = ((hart_ram_if.wr_adr[15:14] == 'b10) && hart_ram_if.wr) ? 1 : 0;
    assign ram_if.rd        = ((hart_ram_if.rd_adr[15:14] == 'b10) && hart_ram_if.rd) ? 1 : 0;
    assign ram_if.strb      = hart_ram_if.strb;

// Data in mux
    always_comb
    begin
        // PIO
        if (pio_lb.vld)
            hart_ram_if.din = pio_lb.dout;

        // Timer
        else if (tmr_lb.vld)
            hart_ram_if.din = tmr_lb.dout;

        // Interrupt
        else if (irq_lb.vld)
            hart_ram_if.din = irq_lb.dout;

        // Exchange
        else if (exch_lb.vld)
            hart_ram_if.din = exch_lb.dout;

        // HPD
        else if (hpd_lb.vld)
            hart_ram_if.din = hpd_lb.dout;

        // AUX
        else if (aux_lb.vld)
            hart_ram_if.din = aux_lb.dout;

        // Message
        else if (msg_lb.vld)
            hart_ram_if.din = msg_lb.dout;

        // Mutex
        else if (mutex_lb.vld)
            hart_ram_if.din = mutex_lb.dout;

        // RAM
        else
            hart_ram_if.din = ram_if.dout;
    end

// PIO
    prt_dp_pm_pio
    #(
        .P_HW_VER_MAJOR    (P_HW_VER_MAJOR),   // Hardware version major
        .P_HW_VER_MINOR    (P_HW_VER_MINOR),   // Hardware version minor
        .P_IN_WIDTH        (P_PIO_IN_WIDTH_INT),
        .P_OUT_WIDTH       (P_PIO_OUT_WIDTH_INT)
    )
    PIO_INST
    (
        // Clock and reset
        .RST_IN            (rst_from_exch),
        .CLK_IN            (CLK_IN),

        // Local bus
        .LB_IF             (pio_lb),

        // PIO
        .PIO_DAT_IN        (dat_to_pio),
        .PIO_DAT_OUT       (dat_from_pio),
        
        // Interrupt
        .IRQ_OUT           (irq_from_pio)
    );

  // Local bus mapping
    assign pio_lb.adr   = (pio_lb.wr) ? hart_ram_if.wr_adr[2+:$size(pio_lb.adr)] : hart_ram_if.rd_adr[2+:$size(pio_lb.adr)];
    assign pio_lb.din   = hart_ram_if.dout;
    assign pio_lb.wr    = ((hart_ram_if.wr_adr[15:14] == 'b11) && (hart_ram_if.wr_adr[8+:P_MAX_DEV_ADR] == P_PIO_BASE) && hart_ram_if.wr) ? 1 : 0;
    assign pio_lb.rd    = ((hart_ram_if.rd_adr[15:14] == 'b11) && (hart_ram_if.rd_adr[8+:P_MAX_DEV_ADR] == P_PIO_BASE) && hart_ram_if.rd) ? 1 : 0;

// PIO bit 0 is set when the system is run in simulation
    assign dat_to_pio[0] = (P_SIM) ? 1 : 0;

// PIO bit 1 is set according to the symbols per lane
    assign dat_to_pio[1] = (P_SPL == 4) ? 1 : 0;

// PIO bit 2 is set according when the MST feature is enable
    assign dat_to_pio[2] = (P_MST) ? 1 : 0;

// External PIO inputs
    assign dat_to_pio[3+:P_PIO_IN_WIDTH] = PIO_IN[0+:P_PIO_IN_WIDTH];

// Timer
    prt_dp_pm_tmr
    #(
        .P_SIM             (P_SIM),
        .P_BEAT            (P_BEAT)     // Beat value
    )
    TMR_INST
    (
        // Clock and reset
        .RST_IN            (rst_from_exch),
        .CLK_IN            (CLK_IN),

        // Local bus
        .LB_IF             (tmr_lb),

    	// Beat
    	.BEAT_OUT          (beat_from_tmr),	// 1 MHz output

        // Interrupt
        .IRQ_OUT           (irq_from_tmr)
    );

  // Local bus mapping
    assign tmr_lb.adr   = (tmr_lb.wr) ? hart_ram_if.wr_adr[2+:$size(tmr_lb.adr)] : hart_ram_if.rd_adr[2+:$size(tmr_lb.adr)];
    assign tmr_lb.din   = hart_ram_if.dout;
    assign tmr_lb.wr    = ((hart_ram_if.wr_adr[15:14] == 'b11) && (hart_ram_if.wr_adr[8+:P_MAX_DEV_ADR] == P_TMR_BASE) && hart_ram_if.wr) ? 1 : 0;
    assign tmr_lb.rd    = ((hart_ram_if.rd_adr[15:14] == 'b11) && (hart_ram_if.rd_adr[8+:P_MAX_DEV_ADR] == P_TMR_BASE) && hart_ram_if.rd) ? 1 : 0;

// IRQ
    prt_dp_pm_irq
    IRQ_INST
    (
        // Clock and reset
        .RST_IN            (rst_from_exch),
        .CLK_IN            (CLK_IN),

        // Local bus
        .LB_IF             (irq_lb),

        // Interrupt
        .IRQ_REQ_IN        (irq_to_irq)
    );

  // Local bus mapping
    assign irq_lb.adr   = (irq_lb.wr) ? hart_ram_if.wr_adr[2+:$size(irq_lb.adr)] : hart_ram_if.rd_adr[2+:$size(irq_lb.adr)];
    assign irq_lb.din   = hart_ram_if.dout;
    assign irq_lb.wr    = ((hart_ram_if.wr_adr[15:14] == 'b11) && (hart_ram_if.wr_adr[8+:P_MAX_DEV_ADR] == P_IRQ_BASE) && hart_ram_if.wr) ? 1 : 0;
    assign irq_lb.rd    = ((hart_ram_if.rd_adr[15:14] == 'b11) && (hart_ram_if.rd_adr[8+:P_MAX_DEV_ADR] == P_IRQ_BASE) && hart_ram_if.rd) ? 1 : 0;

 // Interrupt
    assign irq_to_irq[0]    = irq_from_pio;
    assign irq_to_irq[1]    = irq_from_tmr;
    assign irq_to_irq[2]    = irq_from_msg;
    assign irq_to_irq[3]    = irq_from_hpd;
    assign irq_to_irq[4]    = irq_from_aux;
    assign irq_to_irq[5]    = irq_from_exch;
    assign irq_to_irq[7:6]  = IRQ_IN;

// Exchange
    prt_dp_pm_exch
    #(
        .P_VENDOR           (P_VENDOR)         // Vendor
    )
    EXCH_INST
    (
    	// Reset and clock
        .RST_IN             (RST_IN),              // Reset (from host)  
        .CLK_IN             (CLK_IN),              // Clock

        // Host local bus interface
        .HOST_IF            (HOST_IF),
        .HOST_IRQ_OUT       (HOST_IRQ_OUT),

    	// Policy maker local bus interface
    	.PM_IF              (exch_lb),
        .PM_IRQ_OUT         (irq_from_exch),
        .PM_RST_OUT         (rst_from_exch),

    	// Memory update
    	.MEM_STR_OUT       (mem_str_from_exch),	   // Start
    	.MEM_DAT_OUT       (mem_dat_from_exch),	   // Data
    	.MEM_VLD_OUT	   (mem_vld_from_exch)     // Valid 0 - ROM / 1 - RAM
    );

  // Local bus mapping
    assign exch_lb.adr   = (exch_lb.wr) ? hart_ram_if.wr_adr[2+:$size(exch_lb.adr)] : hart_ram_if.rd_adr[2+:$size(exch_lb.adr)];
    assign exch_lb.din   = hart_ram_if.dout;
    assign exch_lb.wr    = ((hart_ram_if.wr_adr[15:14] == 'b11) && (hart_ram_if.wr_adr[8+:P_MAX_DEV_ADR] == P_EXCH_BASE) && hart_ram_if.wr) ? 1 : 0;
    assign exch_lb.rd    = ((hart_ram_if.rd_adr[15:14] == 'b11) && (hart_ram_if.rd_adr[8+:P_MAX_DEV_ADR] == P_EXCH_BASE) && hart_ram_if.rd) ? 1 : 0;

// HPD
generate
    if (P_CFG == "tx")
    begin : gen_hpd_tx
        prt_dp_pm_hpd_tx
        #(
            // Simulation
            .P_SIM              (P_SIM)          // Simulation parameter
        )
        HPD_INST
        (
            // Reset and clock
            .RST_IN             (rst_from_exch),
            .CLK_IN             (CLK_IN),

            // Local bus interface
            .LB_IF              (hpd_lb),

            // Beat
            .BEAT_IN            (beat_from_tmr),    // Beat 1 MHz

            // HPD
            .HPD_IN             (HPD_IN),           // HPD in

            // IRQ
            .IRQ_OUT            (irq_from_hpd)      // Interrupt
        );

        assign HPD_OUT = 0; // Not used
    end

    else
    begin : gen_hpd_rx
        prt_dp_pm_hpd_rx
        #(
            // Simulation
            .P_SIM              (P_SIM)             // Simulation parameter
        )
        HPD_INST
        (
            // Reset and clock
            .RST_IN             (rst_from_exch),
            .CLK_IN             (CLK_IN),

            // Local bus interface
            .LB_IF              (hpd_lb),

            // Beat
            .BEAT_IN            (beat_from_tmr),    // Beat 1 MHz

            // HPD
            .HPD_OUT            (HPD_OUT),          // HPD out

            // IRQ
            .IRQ_OUT            (irq_from_hpd)      // Interrupt
        );
    end

endgenerate

  // Local bus mapping
    assign hpd_lb.adr   = (hpd_lb.wr) ? hart_ram_if.wr_adr[2+:$size(hpd_lb.adr)] : hart_ram_if.rd_adr[2+:$size(hpd_lb.adr)];
    assign hpd_lb.din   = hart_ram_if.dout;
    assign hpd_lb.wr    = ((hart_ram_if.wr_adr[15:14] == 'b11) && (hart_ram_if.wr_adr[8+:P_MAX_DEV_ADR] == P_HPD_BASE) && hart_ram_if.wr) ? 1 : 0;
    assign hpd_lb.rd    = ((hart_ram_if.rd_adr[15:14] == 'b11) && (hart_ram_if.rd_adr[8+:P_MAX_DEV_ADR] == P_HPD_BASE) && hart_ram_if.rd) ? 1 : 0;

// AUX
    prt_dp_pm_aux
    #(
        .P_VENDOR               (P_VENDOR)         // Vendor
    )
    AUX_INST
    (
        // Reset and clock
        .RST_IN                 (rst_from_exch),
        .CLK_IN                 (CLK_IN),

        // Local bus interface
        .LB_IF                  (aux_lb),

        // Beat
        .BEAT_IN                (beat_from_tmr), // Beat 1 MHz

        // AUX
        .AUX_EN_OUT             (AUX_EN_OUT),   // Enable
        .AUX_TX_OUT             (AUX_TX_OUT),   // Transmit
        .AUX_RX_IN              (AUX_RX_IN),    // Receive

        // IRQ
        .IRQ_OUT                (irq_from_aux)   // Interrupt
    );

  // Local bus mapping
    assign aux_lb.adr   = (aux_lb.wr) ? hart_ram_if.wr_adr[2+:$size(aux_lb.adr)] : hart_ram_if.rd_adr[2+:$size(aux_lb.adr)];
    assign aux_lb.din   = hart_ram_if.dout;
    assign aux_lb.wr    = ((hart_ram_if.wr_adr[15:14] == 'b11) && (hart_ram_if.wr_adr[8+:P_MAX_DEV_ADR] == P_AUX_BASE) && hart_ram_if.wr) ? 1 : 0;
    assign aux_lb.rd    = ((hart_ram_if.rd_adr[15:14] == 'b11) && (hart_ram_if.rd_adr[8+:P_MAX_DEV_ADR] == P_AUX_BASE) && hart_ram_if.rd) ? 1 : 0;

// Message
    prt_dp_pm_msg
    #(
        .P_VENDOR          (P_VENDOR)         // Vendor
    )
    MSG_INST
    (
        // Clock and reset
        .RST_IN            (rst_from_exch),
        .CLK_IN            (CLK_IN),

        // Local bus
        .LB_IF             (msg_lb),

        // Message source
        .MSG_SRC_IF        (MSG_SRC_IF),

        // Message sink
        .MSG_SNK_IF        (MSG_SNK_IF),

        // Interrupt
        .IRQ_OUT           (irq_from_msg)
    );

  // Local bus mapping
    assign msg_lb.adr   = (msg_lb.wr) ? hart_ram_if.wr_adr[2+:$size(msg_lb.adr)] : hart_ram_if.rd_adr[2+:$size(msg_lb.adr)];
    assign msg_lb.din   = hart_ram_if.dout;
    assign msg_lb.wr    = ((hart_ram_if.wr_adr[15:14] == 'b11) && (hart_ram_if.wr_adr[8+:P_MAX_DEV_ADR] == P_MSG_BASE) && hart_ram_if.wr) ? 1 : 0;
    assign msg_lb.rd    = ((hart_ram_if.rd_adr[15:14] == 'b11) && (hart_ram_if.rd_adr[8+:P_MAX_DEV_ADR] == P_MSG_BASE) && hart_ram_if.rd) ? 1 : 0;

// Mutex
    prt_dp_pm_mutex
    MUTEX_INST
    (
        // Clock and reset
        .RST_IN            (rst_from_exch),
        .CLK_IN            (CLK_IN),

        // Local bus
        .LB_IF             (mutex_lb)
    );

  // Local bus mapping
    assign mutex_lb.adr   = (mutex_lb.wr) ? hart_ram_if.wr_adr[2+:$size(mutex_lb.adr)] : hart_ram_if.rd_adr[2+:$size(mutex_lb.adr)];
    assign mutex_lb.din   = hart_ram_if.dout;
    assign mutex_lb.wr    = ((hart_ram_if.wr_adr[15:14] == 'b11) && (hart_ram_if.wr_adr[8+:P_MAX_DEV_ADR] == P_MUTEX_BASE) && hart_ram_if.wr) ? 1 : 0;
    assign mutex_lb.rd    = ((hart_ram_if.rd_adr[15:14] == 'b11) && (hart_ram_if.rd_adr[8+:P_MAX_DEV_ADR] == P_MUTEX_BASE) && hart_ram_if.rd) ? 1 : 0;

// Outputs
    assign PIO_OUT = dat_from_pio[3+:P_PIO_OUT_WIDTH];

endmodule

`default_nettype wire
