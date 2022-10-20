/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP Application RAM
    (c) 2021, 2022 by Parretto B.V.

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

module dp_app_ram
#(
    parameter P_VENDOR      = "none",       // Vendor "xilinx", "lattice" or "intel"
    parameter P_ADR         = 10,           // Address bits
    parameter P_INIT_FILE   = "none"        // Initilization file
)
(
    // Clock
    input wire		        CLK_IN,			// Clock

	// RAM interface
	prt_dp_app_ram_if.slv	RAM_IF,

    // Initialization
    input wire              INIT_STR_IN,    // Start
    input wire [31:0]       INIT_DAT_IN,    // Data
    input wire              INIT_VLD_IN     // Valid
);

// Parameters
localparam P_ADR_WRDS    = P_ADR - 2;
localparam P_DAT         = 32;                      // Data bits
localparam P_WRDS        = 2**P_ADR_WRDS;           // Words
localparam P_MEMORY_SIZE = P_WRDS * P_DAT; // Memory size in bits

// Signals
wire [P_ADR_WRDS-1:0]       clk_addra;
wire [31:0]                 clk_dina;
wire  [3:0]                 clk_wea;
wire                        clk_ena;
logic [P_ADR_WRDS-1:0]      clk_wp;
logic                       clk_ack;

// Logic

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
    assign clk_addra = (INIT_VLD_IN) ? clk_wp : RAM_IF.adr[2+:P_ADR_WRDS];

// Port A data
    assign clk_dina = (INIT_VLD_IN) ? INIT_DAT_IN : RAM_IF.din;

// Port A enable
    assign clk_ena = (INIT_VLD_IN) ? 'b1 : RAM_IF.wr;

// Port A write
    assign clk_wea = (INIT_VLD_IN) ? 'b1111 : RAM_IF.msk;

generate
    if (P_VENDOR == "xilinx")
    begin : gen_xilinx
        // XPM memory
        xpm_memory_sdpram
        #(
            .ADDR_WIDTH_A               (P_ADR_WRDS),       // DECIMAL
            .ADDR_WIDTH_B               (P_ADR_WRDS),       // DECIMAL
            .AUTO_SLEEP_TIME            (0),                // DECIMAL
            .BYTE_WRITE_WIDTH_A         (P_DAT/4),          // DECIMAL
            .CASCADE_HEIGHT             (0),                // DECIMAL
            .CLOCKING_MODE              ("common_clock"),   // String
            .ECC_MODE                   ("no_ecc"),         // String
            .MEMORY_INIT_FILE           (P_INIT_FILE),      // String
            .MEMORY_INIT_PARAM          ("0"),              // String
            .MEMORY_OPTIMIZATION        ("false"),          // String
            .MEMORY_PRIMITIVE           ("block"),          // String
            .MEMORY_SIZE                (P_MEMORY_SIZE),    // DECIMAL
            .MESSAGE_CONTROL            (0),                // DECIMAL
            .READ_DATA_WIDTH_B          (P_DAT),            // DECIMAL
            .READ_LATENCY_B             (1),                // DECIMAL
            .READ_RESET_VALUE_B         ("0"),              // String
            .RST_MODE_A                 ("SYNC"),           // String
            .RST_MODE_B                 ("SYNC"),           // String
            .SIM_ASSERT_CHK             (0),                // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
            .USE_EMBEDDED_CONSTRAINT    (0),                // DECIMAL
            .USE_MEM_INIT               (1),                // DECIMAL
            .WAKEUP_TIME                ("disable_sleep"),  // String
            .WRITE_DATA_WIDTH_A         (P_DAT),            // DECIMAL
            .WRITE_MODE_B               ("read_first")      // String
        )
        RAM_INST
        (
            .doutb            (RAM_IF.dout),          // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
            .addra            (clk_addra),            // ADDR_WIDTH_A-bit input: Address for port A write operations.
            .addrb            (RAM_IF.adr[2+:P_ADR_WRDS]), // ADDR_WIDTH_B-bit input: Address for port B read operations.
            .clka             (CLK_IN),               // 1-bit input: Clock signal for port A. Also clocks port B when parameter CLOCKING_MODE is "common_clock".
            .clkb             (CLK_IN),               // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is "independent_clock". Unused when parameter CLOCKING_MODE is "common_clock".
            .dina             (clk_dina),             // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
            .ena              (clk_ena),              // 1-bit input: Memory enable signal for port A. Must be high on clock cycles when write operations are initiated. Pipelined internally.
            .enb              (1'b1),                 // 1-bit input: Memory enable signal for port B. Must be high on clock cycles when read operations are initiated. Pipelined internally.
            .injectdbiterra   (1'b0),                 // 1-bit input: Controls double bit error injection on input data when
            .injectsbiterra   (1'b0),                 // 1-bit input: Controls single bit error injection on input data when
            .regceb           (1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output data path.
            .rstb             (1'b0),                 // 1-bit input: Reset signal for the final port B output register stage.
            .sleep            (1'b0),                 // 1-bit input: sleep signal to enable the dynamic power saving feature.
            .wea              (clk_wea),              // WRITE_DATA_WIDTH_A-bit input: Write enable vector for port A input
            .sbiterrb         (),                     // 1-bit output: Status signal to indicate single bit error occurrenceon the data output of port B.
            .dbiterrb         ()                      // 1-bit output: Status signal to indicate double bit error occurrence on the data output of port B.
        );
    end

    else if (P_VENDOR == "lattice")
    begin : gen_lattice

    
        dp_app_ram_lat
        RAM_INST
        (
            .rst_i          (1'b0), 
            .wr_clk_i       (CLK_IN), 
            .rd_clk_i       (CLK_IN), 
            .wr_clk_en_i    (1'b1), 
            .rd_clk_en_i    (1'b1), 
            .rd_en_i        (1'b1), 
            .wr_en_i        (clk_ena), 
            .ben_i          (clk_wea), 
            .wr_addr_i      (clk_addra), 
            .wr_data_i      (clk_dina), 
            .rd_addr_i      (RAM_IF.adr[2+:P_ADR_WRDS]), 
            .rd_data_o      (RAM_IF.dout)
        );

/*
        pmi_ram_dp_be
        #(
            .pmi_wr_addr_depth    (P_WRDS),         // integer
            .pmi_wr_addr_width    (P_ADR_WRDS),     // integer
            .pmi_wr_data_width    (P_DAT),          // integer
            .pmi_rd_addr_depth    (P_WRDS),         // integer
            .pmi_rd_addr_width    (P_ADR_WRDS),     // integer
            .pmi_rd_data_width    (P_DAT),          // integer
            .pmi_regmode          ("noreg"),        // "reg"|"noreg"
            .pmi_resetmode        ("async"),        // "async"|"sync"
            .pmi_init_file        (P_INIT_FILE),    // string
            .pmi_init_file_format ("binary"),       // "binary"|"hex"
            .pmi_family           ("LFCPNX"),       // "LIFCL"|"LFD2NX"|"LFCPNX"|"LFMXO5"|"UT24C"|"UT24CP"|"common"
            .pmi_byte_size        (8),              // integer
            .pmi_gsr              ("disable")
        ) 
        RAM_INST
        (
            .Reset     (1'b0),  

            .WrClock   (CLK_IN),  
            .WrClockEn (1'b1),
            .WrAddress (clk_addra),  
            .WE        (clk_ena),  
            .Data      (clk_dina), 
            .ByteEn    (clk_wea),  

            .RdClock   (CLK_IN), 
            .RdClockEn (1'b1),
            .RdAddress (RAM_IF.adr[2+:P_ADR_WRDS]),  

            .Q         (RAM_IF.dout)  
        );
*/
    end

    else if (P_VENDOR == "intel")
    begin : gen_int
        altera_syncram
        #( 
            .address_aclr_b                     ("NONE"),
            .address_reg_b                      ("CLOCK0"),
            .outdata_reg_b                      ("UNREGISTERED"),
            .clock_enable_input_a               ("BYPASS"),
            .clock_enable_input_b               ("BYPASS"),
            .enable_force_to_zero               ("FALSE"),
            .intended_device_family             ("Cyclone 10 GX"),
            .lpm_type                           ("altera_syncram"),
            .numwords_a                         (P_WRDS),
            .numwords_b                         (P_WRDS),
            .operation_mode                     ("DUAL_PORT"),
            .outdata_aclr_b                     ("NONE"),
            .outdata_sclr_b                     ("NONE"),
            .power_up_uninitialized             ("FALSE"),
            .read_during_write_mode_mixed_ports ("DONT_CARE"),
            .widthad_a                          (P_ADR_WRDS),
            .widthad_b                          (P_ADR_WRDS),
            .width_a                            (P_DAT),
            .width_b                            (P_DAT),
            .width_byteena_a                    (4),
            .byte_size                          (8)
        )
        RAM_INST
        (
            .address_a                          (clk_addra),
            .address_b                          (RAM_IF.adr[2+:P_ADR_WRDS]),
            .clock0                             (CLK_IN),
            .data_a                             (clk_dina),
            .wren_a                             (clk_ena),
            .q_b                                (RAM_IF.dout),
            .aclr0                              (1'b0),
            .aclr1                              (1'b0),
            .address2_a                         (1'b1),
            .address2_b                         (1'b1),
            .addressstall_a                     (1'b0),
            .addressstall_b                     (1'b0),
            .byteena_a                          (clk_wea),
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
            .q_a                                (),
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

// The memory has one clock latency
    always_ff @ (posedge CLK_IN)
    begin
        clk_ack <= RAM_IF.req;
    end

// Outputs
    assign RAM_IF.ack = clk_ack;

endmodule

`default_nettype wire
