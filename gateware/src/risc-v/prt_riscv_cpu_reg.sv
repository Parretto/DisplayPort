/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: RISC-V CPU registers
    (c) 2022 - 2024 by Parretto B.V.

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

module prt_riscv_cpu_reg
#(
    parameter P_VENDOR 	= "none",       // Vendor - "AMD", "ALTERA" or "LSC"
	parameter P_REGS 	= 16,				// Number of registers
	parameter P_IDX 	= 4
)
(
	// Clock
	input wire 					CLK_IN,			// Clock

	// Destination register
	input wire [P_IDX-1:0]		RD_IDX_IN,		// IDX
	input wire [31:0]			RD_DAT_IN,		// Data
	input wire 					RD_WR_IN,		// Write

	// Source register 1
	input wire [P_IDX-1:0]		RS1_IDX_IN,
	output wire [31:0]			RS1_DAT_OUT,

	// Source register 2
	input wire [P_IDX-1:0]		RS2_IDX_IN,
	output wire [31:0]			RS2_DAT_OUT
);

// Parameters
localparam P_ADR         = P_IDX;               // Data bits
localparam P_DAT         = 32;                  // Data bits
localparam P_WRDS        = P_REGS;   	        // Words
localparam P_MEMORY_SIZE = P_WRDS * P_DAT;      // Memory size in bits

// Signals
wire [P_IDX-1:0]	clk_rs_idx[0:1];
wire [31:0]			clk_rs_dat[0:1];

genvar i;

// Map addresses
	assign clk_rs_idx[0] = RS1_IDX_IN;
	assign clk_rs_idx[1] = RS2_IDX_IN;

generate
	for (i = 0; i < 2; i++)
	begin : gen_reg
		if (P_VENDOR == "AMD")
		begin : gen_amd
			// XPM memory
			xpm_memory_sdpram
			#(
				.ADDR_WIDTH_A               (P_ADR),            // DECIMAL
				.ADDR_WIDTH_B               (P_ADR),            // DECIMAL
				.AUTO_SLEEP_TIME            (0),                // DECIMAL
				.BYTE_WRITE_WIDTH_A         (P_DAT), 	        // DECIMAL
				.CASCADE_HEIGHT             (0),                // DECIMAL
				.CLOCKING_MODE              ("common_clock"),   // String
				.ECC_MODE                   ("no_ecc"),         // String
				.MEMORY_INIT_FILE           ("none"), 		    // String
				.MEMORY_INIT_PARAM          ("0"),              // String
				.MEMORY_OPTIMIZATION        ("false"),          // String
				.MEMORY_PRIMITIVE           ("distributed"),    // String
				.MEMORY_SIZE                (P_MEMORY_SIZE),    // DECIMAL
				.MESSAGE_CONTROL            (0),                // DECIMAL
				.READ_DATA_WIDTH_B          (P_DAT),            // DECIMAL
				.READ_LATENCY_B             (0),                // DECIMAL
				.READ_RESET_VALUE_B         ("0"),              // String
				.RST_MODE_A                 ("SYNC"),           // String
				.RST_MODE_B                 ("SYNC"),           // String
				.SIM_ASSERT_CHK             (0),                // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
				.USE_EMBEDDED_CONSTRAINT    (0),                // DECIMAL
				.USE_MEM_INIT               (0),                // DECIMAL
				.WAKEUP_TIME                ("disable_sleep"),  // String
				.WRITE_DATA_WIDTH_A         (P_DAT),            // DECIMAL
				.WRITE_MODE_B               ("read_first")      // String
			)
			REG_INST
			(
				.doutb            (clk_rs_dat[i]),        // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
				.addra            (RD_IDX_IN),            // ADDR_WIDTH_A-bit input: Address for port A write operations.
				.addrb            (clk_rs_idx[i]),        // ADDR_WIDTH_B-bit input: Address for port B read operations.
				.clka             (CLK_IN),               // 1-bit input: Clock signal for port A. Also clocks port B when parameter CLOCKING_MODE is "common_clock".
				.clkb             (CLK_IN),               // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is "independent_clock". Unused when parameter CLOCKING_MODE is "common_clock".
				.dina             (RD_DAT_IN),            // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
				.ena              (1'b1),   	          // 1-bit input: Memory enable signal for port A. Must be high on clock cycles when write operations are initiated. Pipelined internally.
				.enb              (1'b1),                 // 1-bit input: Memory enable signal for port B. Must be high on clock cycles when read operations are initiated. Pipelined internally.
				.injectdbiterra   (1'b0),                 // 1-bit input: Controls double bit error injection on input data when
				.injectsbiterra   (1'b0),                 // 1-bit input: Controls single bit error injection on input data when
				.regceb           (1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output data path.
				.rstb             (1'b0),                 // 1-bit input: Reset signal for the final port B output register stage.
				.sleep            (1'b0),                 // 1-bit input: sleep signal to enable the dynamic power saving feature.
				.wea              (RD_WR_IN),             // WRITE_DATA_WIDTH_A-bit input: Write enable vector for port A input
				.sbiterrb         (),                     // 1-bit output: Status signal to indicate single bit error occurrenceon the data output of port B.
				.dbiterrb         ()                      // 1-bit output: Status signal to indicate double bit error occurrence on the data output of port B.
			);
		end

		else if (P_VENDOR == "LSC")
		begin : gen_lsc
			pmi_distributed_dpram
			#(
				.pmi_addr_depth       	(P_WRDS), 		// integer       
				.pmi_addr_width       	(P_ADR), 		// integer       
				.pmi_data_width       	(P_DAT), 		// integer       
				.pmi_regmode          	("noreg"), 		// "reg"|"noreg"     
				.pmi_init_file        	("none"), 		// string        
				.pmi_init_file_format 	("hex"), 		// "binary"|"hex"    
				.pmi_family           	("common")  	// "LIFCL"|"LFD2NX"|"LFCPNX"|"LFMXO5"|"UT24C"|"UT24CP"|"common"
			) 
			REG_INST
			(
				.Reset     			(1'b0),  
				
				.WrClock   			(CLK_IN),  
				.WrClockEn 			(1'b1),  
				.WrAddress 			(RD_IDX_IN),  
				.WE        			(RD_WR_IN),  
				.Data      			(RD_DAT_IN),  

				.RdClock   			(CLK_IN),  
				.RdClockEn 			(1'b1),  
				.RdAddress 			(clk_rs_idx[i]),  
				.Q         			(clk_rs_dat[i])   
			);
		end

		else if (P_VENDOR == "ALTERA")
		begin : gen_altera
			altdpram
			#(
				.indata_aclr 						("OFF"),
				.indata_reg  						("INCLOCK"),
				.intended_device_family  			("Cyclone 10 GX"),
				.lpm_type  							("altdpram"),
				.ram_block_type  					("MLAB"),
				.outdata_aclr  						("OFF"),
				.outdata_sclr  						("OFF"),
				.outdata_reg   						("UNREGISTERED"),
				.rdaddress_aclr  					("OFF"),
				.rdaddress_reg  					("UNREGISTERED"),
				.rdcontrol_aclr  					("OFF"),
				.rdcontrol_reg  					("UNREGISTERED"),
				.read_during_write_mode_mixed_ports	("DONT_CARE"),
				.width 								(P_DAT),
				.widthad  							(P_ADR),
				.width_byteena 						(1),
				.wraddress_aclr  					("OFF"),
				.wraddress_reg  					("INCLOCK"),
				.wrcontrol_aclr  					("OFF"),
				.wrcontrol_reg  					("INCLOCK")
			)
			REG_INST				
			(
				.inclock 			(CLK_IN),
				.outclock 			(CLK_IN),
				.wraddress 			(RD_IDX_IN),
				.data 				(RD_DAT_IN),
				.wren 				(RD_WR_IN),
				.rdaddress 			(clk_rs_idx[i]),
				.q 					(clk_rs_dat[i]),
				.aclr 				(1'b0),
				.sclr 				(1'b0),
				.byteena 			(1'b1),
				.inclocken 			(1'b1),
				.outclocken 		(1'b1),
				.rdaddressstall 	(1'b0),
				.rden 				(1'b1),
				.wraddressstall 	(1'b0)
			);
		end

		else
		begin
			$error ("No Vendor specified!");
		end
	end
endgenerate

// Outputs
	assign RS1_DAT_OUT = (RS1_IDX_IN == 0) ? 0 : clk_rs_dat[0]; // First register is hardwired to zero
	assign RS2_DAT_OUT = (RS2_IDX_IN == 0) ? 0 : clk_rs_dat[1]; // First register is hardwired to zero

endmodule

`default_nettype wire
