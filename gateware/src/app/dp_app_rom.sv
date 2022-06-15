/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP Application ROM
    (c) 2021, 2022 by Parretto B.V.

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

module dp_app_rom
#(
    parameter P_VENDOR      = "xilinx",     // Vendor "xilinx" or "lattice"
    parameter P_ADR         = 16,           // Address bits
    parameter P_INIT_FILE   = "none"        // Initilization file
)
(
    // Reset and Clock
    input wire                 RST_IN,          // Reset
	input wire		           CLK_IN,			// Clock

	// ROM interface
	prt_dp_app_rom_if.slv      ROM_IF,

    // Initialization
    input wire                 INIT_STR_IN,    // Start
    input wire [31:0]          INIT_DAT_IN,    // Data
    input wire                 INIT_VLD_IN     // Valid
);

// Parameters
localparam P_ADR_WRDS    = P_ADR - 2;
localparam P_DAT         = 32;                      // Data bits
localparam P_MEMORY_SIZE = (2**P_ADR_WRDS) * P_DAT;      // Memory size in bits

// Signals
wire [P_ADR_WRDS-1:0]   clk_addra;
wire [31:0]             clk_dina;
wire                    clk_wea;
logic [P_ADR_WRDS-1:0]  clk_wp;
logic                   clk_ack;

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
    assign clk_addra = (INIT_VLD_IN) ? clk_wp : ROM_IF.adr[2+:P_ADR_WRDS];

// Port A data
    assign clk_dina = INIT_DAT_IN;

// Port A write
    assign clk_wea = INIT_VLD_IN;

generate
    if (P_VENDOR == "xilinx")
    begin : gen_xilinx

        // XPM memory
        xpm_memory_spram
        #(
            .READ_LATENCY_A             (1),                // DECIMAL
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
          .addra            (clk_addra),            // ADDR_WIDTH_A-bit input: Address for port A write operations.
          .clka             (CLK_IN),               // 1-bit input: Clock signal for port A. Also clocks port B when parameter CLOCKING_MODE is "common_clock".
          .dina             (clk_dina),             // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
          .ena              (1'b1),                 // 1-bit input: Memory enable signal for port A. Must be high on clock cycles when write operations are initiated. Pipelined internally.
          .injectdbiterra   (1'b0),                 // 1-bit input: Controls double bit error injection on input data when
          .injectsbiterra   (1'b0),                 // 1-bit input: Controls single bit error injection on input data when
          .regcea           (1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output data path.
          .rsta             (RST_IN),               // 1-bit input: Reset signal for the final port B output register stage.
          .sleep            (1'b0),                 // 1-bit input: sleep signal to enable the dynamic power saving feature.
          .wea              (clk_wea),              // WRITE_DATA_WIDTH_A-bit input: Write enable vector for port A input
          .sbiterra         (),
          .dbiterra         ()
        );
    end

    else
    begin : gen_lattice
        dp_app_rom_lat
        ROM_INST
        (
            .rst_i          (1'b0),           // Reset - This signal must be wired to zero. The ROM is updated through the Aqua interface while in reset
            .clk_i          (CLK_IN),         // Clock
            .clk_en_i       (1'b1),           // Clock enable
            .addr_i         (clk_addra),      // Address
            .wr_en_i        (clk_wea),        // Write enable
            .wr_data_i      (clk_dina),       // Write data
            .rd_data_o      (ROM_IF.dat)      // Read data
        );
    end
endgenerate

// The memory has one clock cycle latency
    always_ff @ (posedge RST_IN, posedge CLK_IN)
    begin
        // Reset
        if (RST_IN)
            clk_ack <= 0;

        else
            clk_ack <= ROM_IF.req;
    end

// Outputs
    assign ROM_IF.ack = clk_ack;

endmodule

//`default_nettype wire
