/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP PM ROM
    (c) 2021 - 2025 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Added support for Intel FPGA

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

module prt_dp_pm_rom
#(
    parameter P_VENDOR      = "none",       // Vendor - "AMD", "ALTERA" or "LSC" 
    parameter P_ADR         = 10,           // Address bits
    parameter P_INIT_FILE   = "none"        // Initilization file
)
(
    // Clock
	input wire		    CLK_IN,			// Clock

	// ROM interface
	prt_dp_rom_if.slv   ROM_IF,

    // Initialization
    input wire          INIT_STR_IN,    // Start
    input wire [31:0]   INIT_DAT_IN,    // Data
    input wire          INIT_VLD_IN     // Valid
);

// Parameters
localparam P_DAT         = 32;                  // Data bits
localparam P_WRDS        = 2**P_ADR;            // Words
localparam P_MEMORY_SIZE = P_WRDS * P_DAT;      // Memory size in bits

// Signals
wire [P_ADR-1:0]    clk_addra;
wire [31:0]         clk_dina;
wire                clk_wea;
logic [P_ADR-1:0]   clk_wp;

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
    assign clk_addra = (INIT_VLD_IN) ? clk_wp : ROM_IF.adr;

// Port A data
    assign clk_dina = INIT_DAT_IN;

// Port A write
    assign clk_wea = INIT_VLD_IN;

generate
    if (P_VENDOR == "AMD")
    begin : gen_rom_amd

        // XPM memory
        xpm_memory_spram
        #(
            .READ_LATENCY_A             (1),                // DECIMAL
            .ADDR_WIDTH_A               (P_ADR),            // DECIMAL
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
          .rsta             (1'b0),                 // 1-bit input: Reset signal for the final port B output register stage.
          .sleep            (1'b0),                 // 1-bit input: sleep signal to enable the dynamic power saving feature.
          .wea              (clk_wea),              // WRITE_DATA_WIDTH_A-bit input: Write enable vector for port A input
          .sbiterra         (),
          .dbiterra         ()
        );
    end

    else if (P_VENDOR == "LSC")
    begin : gen_rom_lsc
        pmi_ram_dq
        #(
            .pmi_addr_depth       (P_WRDS),         // integer
            .pmi_addr_width       (P_ADR),          // integer
            .pmi_data_width       (P_DAT),          // integer
            .pmi_regmode          ("noreg"),        // "reg"|"noreg"
            .pmi_resetmode        ("async"),        // "async"|"sync"
            .pmi_init_file        (P_INIT_FILE),    // string
            .pmi_init_file_format ("hex"),          // "binary"|"hex"
            .pmi_family           ("LFCPNX")        // "LIFCL"|"LFD2NX"|"LFCPNX"|"LFMXO5"|"UT24C"|"UT24CP"|"common"
        ) 
        ROM_INST
        (
            .Reset      (1'b0),  
            .Clock      (CLK_IN),  
            .ClockEn    (1'b1),
            .Address    (clk_addra),  
            .WE         (clk_wea),  
            .Data       (clk_dina), 
            .Q          (ROM_IF.dat)  
        );
    end

    else if (P_VENDOR == "ALTERA")
    begin : gen_rom_altera
        altera_syncram
        #( 
            .init_file                          (P_INIT_FILE),
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
            .widthad_a                          (P_ADR),
            .widthad_b                          (P_ADR),
            .width_a                            (P_DAT),
            .width_b                            (P_DAT),
            .width_byteena_a                    (1)
        )
        ROM_INST
        (
            .address_a                          (clk_addra),
            .clock0                             (CLK_IN),
            .data_a                             (clk_dina),
            .wren_a                             (clk_wea),
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

endmodule

`default_nettype wire
