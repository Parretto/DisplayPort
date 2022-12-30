/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: RISC-V ROM
    (c) 2022 - 2023 by Parretto B.V.

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

module prt_riscv_rom
#(
    parameter P_VENDOR      = "none",       // Vendor "xilinx", "lattice" or "intel"
    parameter P_ADR         = 16,           // Address bits
    parameter P_INIT_FILE   = "none"        // Initilization file
)
(
    // Reset and Clock
    input wire                 RST_IN,          // Reset
	input wire		           CLK_IN,			// Clock

	// ROM interface
	prt_riscv_rom_if.slv       ROM_IF,

    // Initialization
    input wire                 INIT_STR_IN,    // Start
    input wire [31:0]          INIT_DAT_IN,    // Data
    input wire                 INIT_VLD_IN     // Valid
);

// Parameters
localparam P_ADR_WRDS    = P_ADR - 2;
localparam P_DAT         = 32;                      // Data bits
localparam P_WRDS        = 2**P_ADR_WRDS;           // Words
localparam P_MEMORY_SIZE = P_WRDS * P_DAT; // Memory size in bits

// Signals
wire                    clk_en;
wire [P_ADR_WRDS-1:0]   clk_adr;
wire [31:0]             clk_din;
wire                    clk_wr;
logic [P_ADR_WRDS-1:0]  clk_wp;
logic [1:0]             clk_vld;

// Enable
    assign clk_en = (INIT_VLD_IN) ? 1'b1 : ROM_IF.en;

// Write pointer
    always_ff @ (posedge CLK_IN)
    begin
        // Clear
        if (INIT_STR_IN)
            clk_wp <= 0;

        // Increment
        else if (INIT_VLD_IN)
            clk_wp <= clk_wp + 'd1;
    end

// Port A address
    assign clk_adr = (INIT_VLD_IN) ? clk_wp : ROM_IF.adr[2+:P_ADR_WRDS];

// Port A data
    assign clk_din = INIT_DAT_IN;

// Port A write
    assign clk_wr = INIT_VLD_IN;

generate
    if (P_VENDOR == "xilinx")
    begin : gen_xilinx
        xpm_memory_spram
        #(
            .READ_LATENCY_A             (2),                // DECIMAL
            .ADDR_WIDTH_A               (P_ADR_WRDS),       // DECIMAL
            .AUTO_SLEEP_TIME            (0),                // DECIMAL
            .BYTE_WRITE_WIDTH_A         (P_DAT),            // DECIMAL
            .CASCADE_HEIGHT             (0),                // DECIMAL
            .ECC_MODE                   ("no_ecc"),         // String
            .MEMORY_INIT_FILE           (P_INIT_FILE),      // String
            .MEMORY_INIT_PARAM          ("0"),              // String
            .MEMORY_OPTIMIZATION        ("false"),          // String
            .MEMORY_PRIMITIVE           ("block"),          // String
            .MEMORY_SIZE                (P_MEMORY_SIZE),    // DECIMAL
            .MESSAGE_CONTROL            (0),                // DECIMAL
            .RST_MODE_A                 ("SYNC"),           // String
            .SIM_ASSERT_CHK             (0),                // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
            .USE_MEM_INIT               (1),                // DECIMAL
            .WAKEUP_TIME                ("disable_sleep"),  // String
            .WRITE_DATA_WIDTH_A         (P_DAT),            // DECIMAL
            .WRITE_MODE_A               ("read_first")      // String
        )
        ROM_INST
        (
          .douta            (ROM_IF.dat),           // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
          .addra            (clk_adr),              // ADDR_WIDTH_A-bit input: Address for port A write operations.
          .clka             (CLK_IN),               // 1-bit input: Clock signal for port A. Also clocks port B when parameter CLOCKING_MODE is "common_clock".
          .dina             (clk_din),              // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
          .ena              (clk_en),               // 1-bit input: Memory enable signal for port A. Must be high on clock cycles when write operations are initiated. Pipelined internally.
          .injectdbiterra   (1'b0),                 // 1-bit input: Controls double bit error injection on input data when
          .injectsbiterra   (1'b0),                 // 1-bit input: Controls single bit error injection on input data when
          .regcea           (clk_en),               // 1-bit input: Clock Enable for the last register stage on the output data path.
          .rsta             (RST_IN),               // 1-bit input: Reset signal for the final port B output register stage.
          .sleep            (1'b0),                 // 1-bit input: sleep signal to enable the dynamic power saving feature.
          .wea              (clk_wr),               // WRITE_DATA_WIDTH_A-bit input: Write enable vector for port A input
          .sbiterra         (),
          .dbiterra         ()
        );
    end

    else if (P_VENDOR == "lattice")
    begin : gen_lattice
        prt_riscv_rom_lat
        ROM_INST
        (
            .rst_i              (1'b0), 
            .dps_i              (1'b0),
            .clk_i              (CLK_IN), 
            .clk_en_i           (clk_en), 
            .wr_en_i            (clk_wr), 
            .addr_i             (clk_adr), 
            .wr_data_i          (clk_din),
            .rdout_clken_i      (clk_en),  
            .rd_data_o          (ROM_IF.dat),
            .lramready_o        (), 
            .rd_datavalid_o     ()
        );
    end

    else if (P_VENDOR == "intel")
    begin : gen_int
        altera_syncram
        #( 
            .outdata_reg_a                      ("UNREGISTERED"),
            .clock_enable_input_a               ("BYPASS"),
            .clock_enable_input_b               ("BYPASS"),
            .enable_force_to_zero               ("FALSE"),
            .intended_device_family             ("Cyclone 10 GX"),
            .lpm_type                           ("altera_syncram"),
            .numwords_a                         (P_WRDS),
            .operation_mode                     ("SINGLE_PORT"),
            .outdata_aclr_a                     ("NONE"),
            .outdata_sclr_a                     ("NONE"),
            .power_up_uninitialized             ("FALSE"),
            .read_during_write_mode_port_a      ("DONT_CARE"),
            .widthad_a                          (P_ADR_WRDS),
            .widthad_b                          (P_ADR_WRDS),
            .width_a                            (P_DAT),
            .width_b                            (P_DAT),
            .width_byteena_a                    (1)
        )
        ROM_INST
        (
            .address_a                          (clk_adr),
            .clock0                             (CLK_IN),
            .data_a                             (clk_din),
            .wren_a                             (clk_wr),
            .q_b                                (),
            .aclr0                              (1'b0),
            .aclr1                              (1'b0),
            .address2_a                         (1'b1),
            .address2_b                         (1'b1),
            .addressstall_a                     (1'b0),
            .addressstall_b                     (1'b0),
            .byteena_a                          (1'b1),
            .byteena_b                          (1'b1),
            .clock1                             (1'b1),
            .clocken0                           (1'b1),
            .clocken1                           (1'b1),
            .clocken2                           (1'b1),
            .clocken3                           (1'b1),
            .data_b                             ({P_DAT{1'b1}}),
            .eccencbypass                       (1'b0),
            .eccencparity                       (8'b0),
            .eccstatus                          (),
            .q_a                                (ROM_IF.dat),
            .rden_a                             (1'b1),
            .rden_b                             (1'b1),
            .sclr                               (1'b0),
            .wren_b                             (1'b0)
        );
    end

    else
    begin
        $error ("No Vendor specified!");
    end

endgenerate

// The memory has two clock cycles latency
    always_ff @ (posedge RST_IN, posedge CLK_IN)
    begin
        // Reset
        if (RST_IN)
            clk_vld <= 0;

        else
        begin
            clk_vld <= {clk_vld[0], ROM_IF.rd};  
        end     
    end

// Outputs
    assign ROM_IF.vld = clk_vld[$left(clk_vld)];

endmodule

`default_nettype wire
