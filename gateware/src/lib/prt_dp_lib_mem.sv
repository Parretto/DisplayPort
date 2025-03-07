/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP Library Memory
    (c) 2021 - 2025 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Changed memory structures
    v1.2 - Added support for Intel FPGA 
	v1.3 - Added read enable for prt_dp_lib_sdp_ram_sc
	v1.4 - Added optimized mode for prt_dp_lib_fifo_dc
	v1.5 - Updated vendor names

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

/*
	Single clock FIFO
	Output data is not registered
*/
module prt_dp_lib_fifo_sc
#(
	parameter                       P_VENDOR    	= "none",  		// Vendor - "AMD", "ALTERA" or "LSC" 
	parameter						P_MODE         	= "single",		// "single" or "burst"
	parameter 						P_RAM_STYLE		= "distributed",	// "distributed", "block" or "ultra"
	parameter 						P_ADR_WIDTH 	= 7,
	parameter						P_DAT_WIDTH 	= 512
)
(
	// Clocks and reset
	input wire						RST_IN,		// Reset
	input wire						CLK_IN,		// Clock
	input wire						CLR_IN,		// Clear

	// Write
	input wire						WR_IN,		// Write in
	input wire 	[P_DAT_WIDTH-1:0]	DAT_IN,		// Write data

	// Read
	input wire						RD_EN_IN,	// Read enable in
	input wire						RD_IN,		// Read in
	output wire [P_DAT_WIDTH-1:0]	DAT_OUT,	// Data out
	output wire						DE_OUT,		// Data enable

	// Status
	output wire	[P_ADR_WIDTH:0]		WRDS_OUT,	// Used words
	output wire						EP_OUT,		// Empty
	output wire						FL_OUT		// Full
);

// Parameters
localparam P_WRDS = 2**P_ADR_WIDTH;

// Signals

logic	[P_ADR_WIDTH-1:0]	clk_wp;			// Write pointer
logic 	[P_ADR_WIDTH-1:0]	clk_rp;			// Read pointer
logic	[1:0]				clk_da;
logic	[1:0]				clk_de;
logic	[P_ADR_WIDTH-1:0]	clk_wrds;
logic						clk_ep;
logic						clk_fl;

// Logic

// RAM instantiation
generate
	if (P_VENDOR == "AMD")
	begin : gen_ram_amd

		xpm_memory_sdpram 
		#(
			.ADDR_WIDTH_A				(P_ADR_WIDTH),  
			.ADDR_WIDTH_B				(P_ADR_WIDTH),  
			.AUTO_SLEEP_TIME			(0),   
			.BYTE_WRITE_WIDTH_A			(P_DAT_WIDTH),  
			.CASCADE_HEIGHT				(0),            
			.CLOCKING_MODE				("common_clock"), 
			.ECC_MODE					("no_ecc"), 
			.MEMORY_INIT_FILE			("none"),   
			.MEMORY_INIT_PARAM			("0"),      
			.MEMORY_OPTIMIZATION		("true"),   
			.MEMORY_PRIMITIVE			(P_RAM_STYLE),     
			.MEMORY_SIZE				(P_WRDS * P_DAT_WIDTH),        
			.MESSAGE_CONTROL			(0),           
			.READ_DATA_WIDTH_B			(P_DAT_WIDTH), 
			.READ_LATENCY_B				(1),      
			.READ_RESET_VALUE_B			("0"),    
			.RST_MODE_A					("SYNC"), 
			.RST_MODE_B					("SYNC"), 
			.SIM_ASSERT_CHK				(0),             
			.USE_EMBEDDED_CONSTRAINT	(0),    
			.USE_MEM_INIT				(0),              
			.WAKEUP_TIME				("disable_sleep"),
			.WRITE_DATA_WIDTH_A			(P_DAT_WIDTH),
			.WRITE_MODE_B				("read_first") 
		)
		RAM_INST 
		(
			.clka				(CLK_IN),       
			.addra				(clk_wp), 
			.dina				(DAT_IN),
			.ena				(1'b1), 
			.wea				(WR_IN),

			.clkb				(CLK_IN),  
			.addrb				(clk_rp),  
			.enb				(RD_EN_IN),    
			.doutb				(DAT_OUT), 

			.injectdbiterra		(1'b0),
			.injectsbiterra		(1'b0),
			.regceb				(RD_EN_IN),             
			.rstb				(1'b0),        
			.sleep				(1'b0),             
			.dbiterrb			(), 
			.sbiterrb			()    
		);
	end

	else if (P_VENDOR == "LSC")
	begin : gen_ram_lsc

		// One single clock read latency is assumed.
		// The distributed read path is asynchronous.
		// Therefore the output register is enabled.
		pmi_distributed_dpram
		#(
			.pmi_addr_depth       	(P_WRDS), 		// integer       
			.pmi_addr_width       	(P_ADR_WIDTH), 	// integer       
			.pmi_data_width       	(P_DAT_WIDTH), 	// integer       
			.pmi_regmode          	("reg"), 			// "reg"|"noreg"     
			.pmi_init_file        	("none"), 		// string        
			.pmi_init_file_format 	("hex"), 			// "binary"|"hex"    
			.pmi_family           	("common")  		// "LIFCL"|"LFD2NX"|"LFCPNX"|"LFMXO5"|"UT24C"|"UT24CP"|"common"
		) 
		RAM_INST
		(
			.Reset     			(1'b0),  
			
			.WrClock   			(CLK_IN),  
			.WrClockEn 			(1'b1),  
			.WrAddress 			(clk_wp),  
			.WE        			(WR_IN),  
			.Data      			(DAT_IN),  

			.RdClock   			(CLK_IN),  
			.RdClockEn 			(RD_EN_IN),  
			.RdAddress 			(clk_rp),  
			.Q         			(DAT_OUT)   
		);	
	end

	else if (P_VENDOR == "ALTERA")
	begin : gen_ram_altera

		localparam P_RAM_TYPE = (P_RAM_STYLE == "distributed") ? "MLAB" : "AUTO";
		
		altera_syncram
		#( 
			.ram_block_type 					(P_RAM_TYPE),
			.address_aclr_b 					("NONE"),
			.address_reg_b  					("CLOCK0"),
			.clock_enable_input_a 				("BYPASS"),
			.clock_enable_input_b 				("BYPASS"),
			.clock_enable_output_b 				("BYPASS"),
			.enable_force_to_zero 				("FALSE"),
			.intended_device_family 			("Cyclone 10 GX"),
			.lpm_type 							("altera_syncram"),
			.numwords_a 						(P_WRDS),
			.numwords_b 						(P_WRDS),
			.operation_mode 					("DUAL_PORT"),
			.outdata_aclr_b 					("NONE"),
			.outdata_sclr_b 					("NONE"),
			.outdata_reg_b 						("CLOCK0"),
			.power_up_uninitialized  			("FALSE"),
			.rdcontrol_reg_b  					("CLOCK0"),
			.widthad_a 							(P_ADR_WIDTH),
			.widthad_b 							(P_ADR_WIDTH),
			.width_a 							(P_DAT_WIDTH),
			.width_b 							(P_DAT_WIDTH)
		)
		RAM_INST
		(
			.address_a 			(clk_wp),
			.address_b 			(clk_rp),
			.clock0 			(CLK_IN),
			.data_a 			(DAT_IN),
			.wren_a 			(WR_IN),
			.q_b 				(DAT_OUT),
			.aclr0 				(1'b0),
			.aclr1 				(1'b0),
			.address2_a 		(1'b1),
			.address2_b 		(1'b1),
			.addressstall_a 	(1'b0),
			.addressstall_b 	(1'b0),
			.byteena_a 			(1'b1),
			.byteena_b 			(1'b1),
			.clock1 			(1'b1),
			.clocken0 			(1'b1),
			.clocken1 			(1'b1),
			.clocken2 			(1'b1),
			.clocken3 			(1'b1),
			.data_b 			({P_DAT_WIDTH{1'b1}}),
			.eccencbypass 		(1'b0),
			.eccencparity 		(8'b0),
			.eccstatus 			(),
			.q_a 				(),
			.rden_a 			(1'b1),
			.rden_b 			(RD_EN_IN),
			.sclr 				(1'b0),
			.wren_b 			(1'b0)
		);
	end

	else
	begin
		$error ("No Vendor specified!");
	end
endgenerate

// Write pointer
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		if (RST_IN)
			clk_wp <= 0;

		else
		begin
			// Clear
			if (CLR_IN)
				clk_wp <= 0;

			// Write
			else if (WR_IN)
			begin
				// Check for overflow
				if (&clk_wp)
					clk_wp <= 0;
				else
					clk_wp <= clk_wp + 'd1;
			end
		end
	end

// Read pointer
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		if (RST_IN)
			clk_rp <= 0;

		else
		begin
			// Clear
			if (CLR_IN)
				clk_rp <= 0;

			// Read enable
			else if (RD_EN_IN)
			begin
				// Read
				if (RD_IN && !clk_ep)
				begin
					// Check for overflow
					if (&clk_rp)
						clk_rp <= 0;
					else
						clk_rp <= clk_rp + 'd1;
				end
			end
		end
	end

// Data available
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		if (RST_IN)
			clk_da <= 0;

		else
		begin
			// Enable
			if (RD_EN_IN)
			begin
				if (clk_ep || RD_IN)
					clk_da <= 0;
				else
				begin
					clk_da[0] <= 1;
					clk_da[1] <= clk_da[0];
				end
			end
		end
	end

// Data enable
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		if (RST_IN)
			clk_de <= 0;

		else
		begin
			// Enable
			if (RD_EN_IN)
			begin
				if (!clk_ep)
					clk_de[0] <= RD_IN;
				else
					clk_de[0] <= 0;
				clk_de[1] <= clk_de[0];
			end
		end
	end

// Empty
// Must be combinatorial
	always_comb
	begin
		if (clk_wp == clk_rp)
			clk_ep = 1;
		else
			clk_ep = 0;
	end

// Full
// Must be combinatorial
	always_comb
	begin
		if (clk_wrds > (P_WRDS - 'd2))
			clk_fl = 1;
		else
			clk_fl = 0;
	end

// Words
// To improve timing performance the output words are registered
	always_ff @ (posedge CLK_IN)
	begin
		if (clk_wp > clk_rp)
			clk_wrds <= clk_wp - clk_rp;

		else if (clk_wp < clk_rp)
			clk_wrds <= (P_WRDS - clk_rp) + clk_wp;

		else
			clk_wrds <= 0;
	end
	
// Outputs
	assign DE_OUT 		= (P_MODE == "burst") ? ((P_RAM_STYLE == "ultra") ? clk_de[$size(clk_de)-1] : clk_de[0]) : ((P_RAM_STYLE == "ultra") ? clk_da[$size(clk_da)-1] : clk_da[0]);
	assign WRDS_OUT 	= clk_wrds;
	assign EP_OUT 		= clk_ep;
	assign FL_OUT 		= clk_fl;

endmodule

/*
	Dual Clock FIFO
	Output data is registered
*/
module prt_dp_lib_fifo_dc
#(
	parameter                       P_VENDOR    	= "none",  			// Vendor - "AMD", "ALTERA" or "LSC" 
	parameter						P_MODE         	= "single",			// "single" or "burst"
	parameter 						P_RAM_STYLE		= "distributed",	// "distributed" or "block"
	parameter 						P_OPT 			= 0,				// In optimized mode some logic is saved. The status port are not available. 
	parameter						P_ADR_WIDTH		= 5,
	parameter						P_DAT_WIDTH		= 32
)
(
	input wire						A_RST_IN,		// Reset
	input wire						B_RST_IN,
	input wire						A_CLK_IN,		// Clock
	input wire						B_CLK_IN,
	input wire						A_CKE_IN,		// Clock enable
	input wire						B_CKE_IN,

	// Input (A)
	input wire						A_CLR_IN,		// Clear
	input wire						A_WR_IN,		// Write
	input wire	[P_DAT_WIDTH-1:0]	A_DAT_IN,		// Write data

	// Output (B)
	input wire						B_CLR_IN,		// Clear
	input wire						B_RD_IN,		// Read
	output wire	[P_DAT_WIDTH-1:0]	B_DAT_OUT,	// Read data
	output wire						B_DE_OUT,		// Data enable

	// Status (A)
	output wire	[P_ADR_WIDTH:0]		A_WRDS_OUT,	// Used words
	output wire						A_FL_OUT,		// Full
	output wire						A_EP_OUT,		// Empty

	// Status (B)
	output wire	[P_ADR_WIDTH:0]		B_WRDS_OUT,	// Used words
	output wire						B_FL_OUT,		// Full
	output wire						B_EP_OUT		// Empty
);

/*
	Parameters
*/
localparam P_WRDS = 2**P_ADR_WIDTH;

/*
	Signals
*/
logic 	[P_ADR_WIDTH-1:0]	aclk_wp;
wire 	[P_ADR_WIDTH-1:0]	aclk_rp;
logic	[P_ADR_WIDTH:0]		aclk_wrds;
logic						aclk_fl;
logic						aclk_ep;

logic 	[P_ADR_WIDTH-1:0]	bclk_rp;
wire 	[P_ADR_WIDTH-1:0]	bclk_wp;
logic	[P_ADR_WIDTH:0]		bclk_wrds;
logic						bclk_fl;
logic						bclk_ep;
logic	[1:0]				bclk_da;
logic	[1:0]				bclk_de;

/*
	Logic
*/

// RAM instantiation
generate
	if (P_VENDOR == "AMD")
	begin : gen_ram_amd

		// The parameter USE_EMBEDDED_CONSTRAINT must be used for distributed memory with independent clocks
		// to set automatically timing constraints.
		localparam P_USE_CONSTRAINT = (P_RAM_STYLE == "distributed") ? 1 : 0;

		xpm_memory_sdpram 
		#(
			.ADDR_WIDTH_A				(P_ADR_WIDTH),  
			.ADDR_WIDTH_B				(P_ADR_WIDTH),  
			.AUTO_SLEEP_TIME			(0),   
			.BYTE_WRITE_WIDTH_A			(P_DAT_WIDTH),  
			.CASCADE_HEIGHT				(0),            
			.CLOCKING_MODE				("independent_clock"), 
			.ECC_MODE					("no_ecc"), 
			.MEMORY_INIT_FILE			("none"),   
			.MEMORY_INIT_PARAM			("0"),      
			.MEMORY_OPTIMIZATION		("true"),   
			.MEMORY_PRIMITIVE			(P_RAM_STYLE),     
			.MEMORY_SIZE				(P_WRDS * P_DAT_WIDTH),        
			.MESSAGE_CONTROL			(0),           
			.READ_DATA_WIDTH_B			(P_DAT_WIDTH), 
			.READ_LATENCY_B				(2),      
			.READ_RESET_VALUE_B			("0"),    
			.RST_MODE_A					("SYNC"), 
			.RST_MODE_B					("SYNC"), 
			.SIM_ASSERT_CHK				(0),             
			.USE_EMBEDDED_CONSTRAINT	(P_USE_CONSTRAINT),    
			.USE_MEM_INIT				(1),              
			.WAKEUP_TIME				("disable_sleep"),
			.WRITE_DATA_WIDTH_A			(P_DAT_WIDTH),
			.WRITE_MODE_B				("read_first") 
		)
		RAM_INST 
		(
			.clka				(A_CLK_IN),       
			.addra				(aclk_wp), 
			.dina				(A_DAT_IN),
			.ena				(A_CKE_IN), 
			.wea				(A_WR_IN),

			.clkb				(B_CLK_IN),  
			.addrb				(bclk_rp),  
			.enb				(B_CKE_IN),    
			.doutb				(B_DAT_OUT), 

			.injectdbiterra		(1'b0),
			.injectsbiterra		(1'b0),
			.regceb				(B_CKE_IN),             
			.rstb				(1'b0),        
			.sleep				(1'b0),             
			.dbiterrb			(), 
			.sbiterrb			()    
		);
	end

	else if (P_VENDOR == "LSC")
	begin : gen_ram_lsc
		
		// Block ram
		if (P_RAM_STYLE == "block")
		begin
			pmi_ram_dp
			#(
				.pmi_wr_addr_depth    	(P_WRDS), 		// integer
				.pmi_wr_addr_width    	(P_ADR_WIDTH), 	// integer
				.pmi_wr_data_width    	(P_DAT_WIDTH), 	// integer
				.pmi_rd_addr_depth    	(P_WRDS), 		// integer
				.pmi_rd_addr_width    	(P_ADR_WIDTH), 	// integer
				.pmi_rd_data_width    	(P_DAT_WIDTH), 	// integer
				.pmi_regmode          	("reg"), 		// "reg"|"noreg"
				.pmi_resetmode        	("async"), 		// "async"|"sync"
				.pmi_init_file        	("none"), 		// string
				.pmi_init_file_format 	("hex"), 		// "binary"|"hex"
				.pmi_family           	("common")  	// "LIFCL"|"LFD2NX"|"LFCPNX"|"LFMXO5"|"UT24C"|"UT24CP"|"common"
			) 
			RAM_INST
			(
				.Reset     			(1'b0),  

				.WrClock   			(A_CLK_IN),  
				.WrClockEn 			(A_CKE_IN),
				.WrAddress 			(aclk_wp),  
				.WE        			(A_WR_IN),  
				.Data      			(A_DAT_IN), 

				.RdClock   			(B_CLK_IN), 
				.RdClockEn 			(B_CKE_IN),
				.RdAddress 			(bclk_rp),  

				.Q         			(B_DAT_OUT)  
			);
		end

		// Distributed ram
		else
		begin
			// Signals
			wire  [P_DAT_WIDTH-1:0] dout_from_ram;
			logic [P_DAT_WIDTH-1:0] clk_dout;

			pmi_distributed_dpram
			#(
				.pmi_addr_depth       	(P_WRDS), // integer       
				.pmi_addr_width       	(P_ADR_WIDTH), // integer       
				.pmi_data_width       	(P_DAT_WIDTH), // integer       
				.pmi_regmode          	("reg"), // "reg"|"noreg"     
				.pmi_init_file        	("none"), // string        
				.pmi_init_file_format 	("hex"), // "binary"|"hex"    
				.pmi_family           	("common")  // "LIFCL"|"LFD2NX"|"LFCPNX"|"LFMXO5"|"UT24C"|"UT24CP"|"common"
			) 
			RAM_INST
			(
				.Reset     			(1'b0),  
				
				.WrClock   			(A_CLK_IN),  
				.WrClockEn 			(A_CKE_IN),  
				.WrAddress 			(aclk_wp),  
				.WE        			(A_WR_IN),  
				.Data      			(A_DAT_IN),  

				.RdClock   			(B_CLK_IN),  
				.RdClockEn 			(B_CKE_IN),  
				.RdAddress 			(bclk_rp),  
				.Q         			(dout_from_ram)   
			);

			// The distributed memory read path is asynchronous.
			// The read addres is not registered. 
			// The read output register is enabled. 
			// However a block ram has a read latency of two cycles. 
			// To have the same behaviour an additional output register is added. 
			always_ff @ (posedge B_CLK_IN)
			begin
				if (B_CKE_IN)
					clk_dout <= dout_from_ram;
			end	

			// Outputs 
			assign B_DAT_OUT = clk_dout;
		end
	end

	else if (P_VENDOR == "ALTERA")
	begin : gen_ram_altera
		
		localparam P_RAM_TYPE = (P_RAM_STYLE == "distributed") ? "MLAB" : "AUTO";
		
		altera_syncram
		#( 
			.ram_block_type 					(P_RAM_TYPE),
			.address_aclr_b 					("NONE"),
			.address_reg_b  					("CLOCK1"),
			.clock_enable_input_a 				("BYPASS"),
			.clock_enable_input_b 				("BYPASS"),
			.clock_enable_output_b 				("BYPASS"),
			.enable_force_to_zero 				("FALSE"),
			.intended_device_family 			("Cyclone 10 GX"),
			.lpm_type 							("altera_syncram"),
			.numwords_a 						(P_WRDS),
			.numwords_b 						(P_WRDS),
			.operation_mode 					("DUAL_PORT"),
			.outdata_aclr_b 					("NONE"),
			.outdata_sclr_b 					("NONE"),
			.outdata_reg_b 						("CLOCK1"),
			.power_up_uninitialized  			("FALSE"),
			.widthad_a 							(P_ADR_WIDTH),
			.widthad_b 							(P_ADR_WIDTH),
			.width_a 							(P_DAT_WIDTH),
			.width_b 							(P_DAT_WIDTH)
		)
		RAM_INST
		(
			.address_a 			(aclk_wp),
			.address_b 			(bclk_rp),
			.clock0 			(A_CLK_IN),
			.data_a 			(A_DAT_IN),
			.wren_a 			(A_WR_IN),
			.q_b 				(B_DAT_OUT),
			.aclr0 				(1'b0),
			.aclr1 				(1'b0),
			.address2_a 		(1'b1),
			.address2_b 		(1'b1),
			.addressstall_a 	(1'b0),
			.addressstall_b 	(1'b0),
			.byteena_a 			(1'b1),
			.byteena_b 			(1'b1),
			.clock1 			(B_CLK_IN),
			.clocken0 			(A_CKE_IN),
			.clocken1 			(B_CKE_IN),
			.clocken2 			(1'b1),
			.clocken3 			(1'b1),
			.data_b 			({P_DAT_WIDTH{1'b1}}),
			.eccencbypass 		(1'b0),
			.eccencparity 		(8'b0),
			.eccstatus 			(),
			.q_a 				(),
			.rden_a 			(1'b1),
			.rden_b 			(1'b1),
			.sclr 				(1'b0),
			.wren_b 			(1'b0)
		);
	end

endgenerate

// Port A
// Write Pointer
	always_ff @ (posedge A_RST_IN, posedge A_CLK_IN)
	begin
		if (A_RST_IN)
			aclk_wp <= 0;

		else
		begin
			// Clock enable
			if (A_CKE_IN)
			begin
				// Clear
				if (A_CLR_IN)
					aclk_wp <= 0;

				// Increment 
				else if (A_WR_IN)
				begin
					if (aclk_wp == P_WRDS-1)
						aclk_wp <= 0;
					else
						aclk_wp <= aclk_wp + 'd1;
				end
			end
		end
	end

generate
	// Normal mode
	if (P_OPT == 0)
	begin : gen_aclk_sta

		// Clock Domain Crossing
		// This adapter crosses the (original size) read pointer to the write pointer domain.
		prt_dp_lib_cdc_gray
		#(
			.P_VENDOR 		(P_VENDOR),
			.P_WIDTH		(P_ADR_WIDTH)
		)
		RP_CDC_INST
		(
			.SRC_CLK_IN		(B_CLK_IN),
			.SRC_DAT_IN		(bclk_rp),
			.DST_CLK_IN		(A_CLK_IN),
			.DST_DAT_OUT	(aclk_rp)
		);

		// Words
		// To improve timing performance the words are registered
		always_ff @ (posedge A_CLK_IN)
		begin
			if (aclk_wp > aclk_rp)
				aclk_wrds <= aclk_wp - aclk_rp;

			else if (aclk_wp < aclk_rp)
				aclk_wrds <= (P_WRDS - aclk_rp) + aclk_wp;

			else
				aclk_wrds <= 0;
		end

		// Full Flag
		// Must be combinatorial
		always_comb
		begin
			if (aclk_wrds > (P_WRDS - 'd4))
				aclk_fl = 1;
			else
				aclk_fl = 0;
		end

		// Empty Flag
		// Must be combinatorial
		always_comb
		begin
			// Set
			if (aclk_wp == aclk_rp)
				aclk_ep = 1;

			// Clear
			else
				aclk_ep = 0;
		end
	end

	// Reduced mode
	else
	begin
		assign aclk_ep = 0;
		assign aclk_fl = 0;
		assign aclk_wrds = 0;
		assign aclk_rp = 0;
	end
endgenerate

// Port B
// Read Pointer
	always_ff @ (posedge B_RST_IN, posedge B_CLK_IN)
	begin
		if (B_RST_IN)
			bclk_rp <= 0;

		else
		begin
			// Clock enable
			if (B_CKE_IN)
			begin
				// Clear
				if (B_CLR_IN)
					bclk_rp <= 0;
				
				// Increment
				else if (B_RD_IN && !bclk_ep)
				begin
					if (bclk_rp == P_WRDS-1)
						bclk_rp <= 0;
					else
						bclk_rp <= bclk_rp + 'd1;
				end
			end
		end
	end

generate
	// Normal mode
	if (P_OPT == 0)
	begin : gen_bclk_sta

		// Clock Domain Crossing
		// This adapter crosses the (original size) write pointer to the read pointer domain.
		prt_dp_lib_cdc_gray
		#(
			.P_VENDOR 		(P_VENDOR),
			.P_WIDTH		(P_ADR_WIDTH)
		)
		WP_CDC_INST
		(
			.SRC_CLK_IN		(A_CLK_IN),
			.SRC_DAT_IN		(aclk_wp),
			.DST_CLK_IN		(B_CLK_IN),
			.DST_DAT_OUT	(bclk_wp)
		);

		// Words
		// To improve timing performance the words are registered
		always_ff @ (posedge B_CLK_IN)
		begin
			if (bclk_wp > bclk_rp)
				bclk_wrds <= bclk_wp - bclk_rp;

			else if (bclk_wp < bclk_rp)
				bclk_wrds <= (P_WRDS - bclk_rp) + bclk_wp;

			else
				bclk_wrds <= 0;
		end

	// Full Flag
	// Must be combinatorial
		always_comb
		begin
			if (bclk_wrds > (P_WRDS - 'd4))
				bclk_fl = 1;
			else
				bclk_fl = 0;
		end

	// Empty Flag
	// Must be combinatorial
		always_comb
		begin
			// Set
			if (bclk_wp == bclk_rp)
				bclk_ep = 1;

			// Clear
			else
				bclk_ep = 0;
		end
	end

	// Reduced mode
	else
	begin
		assign bclk_ep = 0;
		assign bclk_fl = 0;
		assign bclk_wrds = 0;
		assign bclk_wp = 0;
	end
endgenerate

// Data available
	always_ff @ (posedge B_RST_IN, posedge B_CLK_IN)
	begin
		if (B_RST_IN)
			bclk_da <= 0;

		else
		begin
			// Enable
			if (B_CKE_IN)
			begin
				if (bclk_ep || B_RD_IN)
					bclk_da <= 0;
				else
				begin
					bclk_da[0] <= 1;
					bclk_da[1] <= bclk_da[0];
				end
			end
		end
	end

// Data enable
	always_ff @ (posedge B_RST_IN, posedge B_CLK_IN)
	begin
		if (B_RST_IN)
			bclk_de <= 0;

		else
		begin
			// Enable
			if (B_CKE_IN)
			begin
				if (!bclk_ep)
					bclk_de[0] <= B_RD_IN;
				else
					bclk_de[0] <= 0;
				bclk_de[1] <= bclk_de[0];
			end
		end
	end

// Outputs
	assign A_FL_OUT 	= aclk_fl;
	assign A_EP_OUT 	= aclk_ep;
	assign A_WRDS_OUT 	= aclk_wrds;
	assign B_DE_OUT 	= (P_MODE == "burst") ? bclk_de[$size(bclk_de)-1] : bclk_da[$size(bclk_da)-1];
	assign B_FL_OUT 	= bclk_fl;
	assign B_EP_OUT 	= bclk_ep;
	assign B_WRDS_OUT 	= bclk_wrds;

endmodule


/*
	Simple dual port RAM single clock
*/
module prt_dp_lib_sdp_ram_sc
#(
	parameter                   	P_VENDOR    	= "none",  			// Vendor - "AMD", "ALTERA" or "LSC"	
	parameter 						P_RAM_STYLE		= "distributed",	// "distributed", "block" or "ultra"
	parameter 						P_ADR_WIDTH 	= 7,
	parameter						P_DAT_WIDTH 	= 512
)
(
	// Clocks and reset
	input wire						RST_IN,			// Reset
	input wire						CLK_IN,			// Clock

	// Port A
	input wire [P_ADR_WIDTH-1:0]	A_ADR_IN,		// Address
	input wire						A_WR_IN,		// Write in
	input wire [P_DAT_WIDTH-1:0]	A_DAT_IN,		// Write data

	// Port B
	input wire 						B_EN_IN,		// Enable
	input wire [P_ADR_WIDTH-1:0]	B_ADR_IN,		// Address
	input wire						B_RD_IN,		// Read in
	output wire [P_DAT_WIDTH-1:0]	B_DAT_OUT,		// Read data
	output wire						B_VLD_OUT		// Read data valid
);

// Parameters
localparam P_WRDS = 2**P_ADR_WIDTH;

// Signals
logic  clk_b_vld;

// Logic

// RAM instantiation
generate
	if (P_VENDOR == "AMD")
	begin : gen_ram_amd
		xpm_memory_sdpram 
		#(
			.ADDR_WIDTH_A				(P_ADR_WIDTH),  
			.ADDR_WIDTH_B				(P_ADR_WIDTH),  
			.AUTO_SLEEP_TIME			(0),   
			.BYTE_WRITE_WIDTH_A			(P_DAT_WIDTH),  
			.CASCADE_HEIGHT				(0),            
			.CLOCKING_MODE				("common_clock"), 
			.ECC_MODE					("no_ecc"), 
			.MEMORY_INIT_FILE			("none"),   
			.MEMORY_INIT_PARAM			("0"),      
			.MEMORY_OPTIMIZATION		("true"),   
			.MEMORY_PRIMITIVE			(P_RAM_STYLE),     
			.MEMORY_SIZE				(P_WRDS * P_DAT_WIDTH),        
			.MESSAGE_CONTROL			(0),           
			.READ_DATA_WIDTH_B			(P_DAT_WIDTH), 
			.READ_LATENCY_B				(1),      
			.READ_RESET_VALUE_B			("0"),    
			.RST_MODE_A					("SYNC"), 
			.RST_MODE_B					("SYNC"), 
			.SIM_ASSERT_CHK				(0),             
			.USE_EMBEDDED_CONSTRAINT	(0),    
			.USE_MEM_INIT				(1),              
			.WAKEUP_TIME				("disable_sleep"),
			.WRITE_DATA_WIDTH_A			(P_DAT_WIDTH),
			.WRITE_MODE_B				("read_first") 
		)
		RAM_INST 
		(
			.clka					(CLK_IN),       
			.addra					(A_ADR_IN), 
			.dina					(A_DAT_IN),
			.ena					(1'b1), 
			.wea					(A_WR_IN),

			.clkb					(CLK_IN),  
			.addrb					(B_ADR_IN),  
			.enb					(B_EN_IN),    
			.doutb					(B_DAT_OUT), 

			.injectdbiterra			(1'b0),
			.injectsbiterra			(1'b0),
			.regceb					(1'b1),             
			.rstb					(1'b0),        
			.sleep					(1'b0),             
			.dbiterrb				(), 
			.sbiterrb				()    
		);
	end

	else if (P_VENDOR == "LSC")
	begin : gen_ram_lsc

		// One single clock read latency is assumed.
		// The distributed read path is asynchronous.
		// Therefore the output register is enabled.
		pmi_distributed_dpram
		#(
		  .pmi_addr_depth       	(P_WRDS), 		// integer      
		  .pmi_addr_width       	(P_ADR_WIDTH), 	// integer      
		  .pmi_data_width       	(P_DAT_WIDTH), 	// integer      
		  .pmi_regmode          	("reg"), 		// "reg"|"noreg"    
		  .pmi_init_file        	("none"), 		// string       
		  .pmi_init_file_format 	("hex"), 		// "binary"|"hex"     
		  .pmi_family           	("common")  	// "LIFCL"|"LFD2NX"|"LFCPNX"|"LFMXO5"|"UT24C"|"UT24CP"|"common"    
		) 
		RAM_INST
		(        
		  .Reset     			(1'b0),  		
		  .WrClock   			(CLK_IN),  	
		  .WrClockEn 			(1'b1),  		
		  .WrAddress 			(A_ADR_IN),  
		  .WE        			(A_WR_IN),  
		  .Data      			(A_DAT_IN), 

		  .RdClock   			(CLK_IN), 
		  .RdClockEn 			(B_EN_IN),  
		  .RdAddress 			(B_ADR_IN), 
		  .Q         			(B_DAT_OUT) 
		);
	end

	else if (P_VENDOR == "ALTERA")
	begin : gen_ram_altera

		localparam P_RAM_TYPE = (P_RAM_STYLE == "distributed") ? "MLAB" : "AUTO";
		
		altera_syncram
		#( 
			.ram_block_type 					(P_RAM_TYPE),
			.address_aclr_b 					("NONE"),
			.address_reg_b  					("CLOCK0"),
			.clock_enable_input_a 				("BYPASS"),
			.clock_enable_input_b 				("NORMAL"),
			.clock_enable_output_b 				("BYPASS"),
			.enable_force_to_zero 				("FALSE"),
			.intended_device_family 			("Cyclone 10 GX"),
			.lpm_type 							("altera_syncram"),
			.numwords_a 						(P_WRDS),
			.numwords_b 						(P_WRDS),
			.operation_mode 					("DUAL_PORT"),
			.outdata_aclr_b 					("NONE"),
			.outdata_sclr_b 					("NONE"),
			.outdata_reg_b 						("UNREGISTERED"),
			.power_up_uninitialized  			("FALSE"),
			.widthad_a 							(P_ADR_WIDTH),
			.widthad_b 							(P_ADR_WIDTH),
			.width_a 							(P_DAT_WIDTH),
			.width_b 							(P_DAT_WIDTH)
		)
		RAM_INST
		(
			.address_a 			(A_ADR_IN),
			.address_b 			(B_ADR_IN),
			.clock0 			(CLK_IN),
			.data_a 			(A_DAT_IN),
			.wren_a 			(A_WR_IN),
			.q_b 				(B_DAT_OUT),
			.aclr0 				(1'b0),
			.aclr1 				(1'b0),
			.address2_a 		(1'b1),
			.address2_b 		(1'b1),
			.addressstall_a 	(1'b0),
			.addressstall_b 	(~B_EN_IN),
			.byteena_a 			(1'b1),
			.byteena_b 			(1'b1),
			.clock1 			(1'b1),
			.clocken0 			(1'b1),
			.clocken1 			(1'b1),
			.clocken2 			(1'b1),
			.clocken3 			(1'b1),
			.data_b 			({P_DAT_WIDTH{1'b1}}),
			.eccencbypass 		(1'b0),
			.eccencparity 		(8'b0),
			.eccstatus 			(),
			.q_a 				(),
			.rden_a 			(1'b1),
			.rden_b 			(1'b1),
			.sclr 				(1'b0),
			.wren_b 			(1'b0)
		);
	end

endgenerate

	// Valid
	// The memory has one clock read latency
   	always_ff @ (posedge CLK_IN)
   	begin
		// Enable
		if (B_EN_IN)
   			clk_b_vld <= B_RD_IN;
	end

	// Outputs
   	assign B_VLD_OUT = clk_b_vld;

endmodule

/*
	Simple dual port RAM dual clock
*/
module prt_dp_lib_sdp_ram_dc
#(
	parameter                   	P_VENDOR    	= "none",  		// Vendor - "AMD", "ALTERA" or "LSC"
	parameter 						P_RAM_STYLE		= "distributed",	// "distributed", "block" or "ultra"
	parameter 						P_ADR_WIDTH 	= 7,
	parameter						P_DAT_WIDTH 	= 512
)
(
	// Port A
	input wire						A_RST_IN,		// Reset
	input wire						A_CLK_IN,		// Clock
	input wire [P_ADR_WIDTH-1:0]	A_ADR_IN,		// Address
	input wire						A_WR_IN,		// Write in
	input wire [P_DAT_WIDTH-1:0]	A_DAT_IN,		// Write data

	// Port B
	input wire						B_RST_IN,		// Reset
	input wire						B_CLK_IN,		// Clock
	input wire [P_ADR_WIDTH-1:0]	B_ADR_IN,		// Address
	input wire						B_RD_IN,		// Read in
	output wire [P_DAT_WIDTH-1:0]	B_DAT_OUT,		// Read data
	output wire						B_VLD_OUT		// Read data valid
);

// Local parameters
localparam P_WRDS = 2**P_ADR_WIDTH;

// Signals
logic bclk_vld;

// Logic

// RAM instantiation
generate
	if (P_VENDOR == "AMD")
	begin : gen_ram_amd
		
		// The parameter USE_EMBEDDED_CONSTRAINT must be used for distributed memory with independent clocks
		// to set automatically timing constraints.
		localparam P_USE_CONSTRAINT = (P_RAM_STYLE == "distributed") ? 1 : 0;

		xpm_memory_sdpram 
		#(
			.ADDR_WIDTH_A				(P_ADR_WIDTH),  
			.ADDR_WIDTH_B				(P_ADR_WIDTH),  
			.AUTO_SLEEP_TIME			(0),   
			.BYTE_WRITE_WIDTH_A			(P_DAT_WIDTH),  
			.CASCADE_HEIGHT				(0),            
			.CLOCKING_MODE				("independent_clock"), 
			.ECC_MODE					("no_ecc"), 
			.MEMORY_INIT_FILE			("none"),   
			.MEMORY_INIT_PARAM			("0"),      
			.MEMORY_OPTIMIZATION		("true"),   
			.MEMORY_PRIMITIVE			(P_RAM_STYLE),     
			.MEMORY_SIZE				(P_WRDS * P_DAT_WIDTH),        
			.MESSAGE_CONTROL			(0),           
			.READ_DATA_WIDTH_B			(P_DAT_WIDTH), 
			.READ_LATENCY_B				(1),      
			.READ_RESET_VALUE_B			("0"),    
			.RST_MODE_A					("SYNC"), 
			.RST_MODE_B					("SYNC"), 
			.SIM_ASSERT_CHK				(0),             
			.USE_EMBEDDED_CONSTRAINT	(P_USE_CONSTRAINT),    
			.USE_MEM_INIT				(1),              
			.WAKEUP_TIME				("disable_sleep"),
			.WRITE_DATA_WIDTH_A			(P_DAT_WIDTH),
			.WRITE_MODE_B				("read_first") 
		)
		RAM_INST 
		(
			.clka				(A_CLK_IN),       
			.addra				(A_ADR_IN), 
			.dina				(A_DAT_IN),
			.ena				(1'b1), 
			.wea				(A_WR_IN),

			.clkb				(B_CLK_IN),  
			.addrb				(B_ADR_IN),  
			.enb				(1'b1),    
			.doutb				(B_DAT_OUT), 

			.injectdbiterra		(1'b0),
			.injectsbiterra		(1'b0),
			.regceb				(1'b1),             
			.rstb				(1'b0),        
			.sleep				(1'b0),             
			.dbiterrb			(), 
			.sbiterrb			()    
		);
	end

	else if (P_VENDOR == "LSC")
	begin : gen_ram_lsc

		// One single clock read latency is assumed.
		// The distributed read path is asynchronous.
		// Therefore the output register is enabled.
		pmi_distributed_dpram
		#(
		  .pmi_addr_depth       (P_WRDS), 		// integer      
		  .pmi_addr_width       (P_ADR_WIDTH), 	// integer      
		  .pmi_data_width       (P_DAT_WIDTH), 	// integer      
		  .pmi_regmode          ("reg"), 		// "reg"|"noreg"    
		  .pmi_init_file        ("none"), 		// string       
		  .pmi_init_file_format ("hex"), 		// "binary"|"hex"     
		  .pmi_family           ("common")  	// "LIFCL"|"LFD2NX"|"LFCPNX"|"LFMXO5"|"UT24C"|"UT24CP"|"common"    
		) 
		RAM_INST
		(        
		  .Reset     			(1'b0),  		
		  
		  .WrClock   			(A_CLK_IN),  	
		  .WrClockEn 			(1'b1),  		
		  .WrAddress 			(A_ADR_IN),  
		  .WE        			(A_WR_IN),  
		  .Data      			(A_DAT_IN), 

		  .RdClock   			(B_CLK_IN), 
		  .RdClockEn 			(1'b1),  
		  .RdAddress 			(B_ADR_IN), 
		  .Q         			(B_DAT_OUT) 
		);
	end

	else if (P_VENDOR == "ALTERA")
	begin : gen_ram_altera

		localparam P_RAM_TYPE = (P_RAM_STYLE == "distributed") ? "MLAB" : "AUTO";
		
		altera_syncram
		#( 
			.ram_block_type 				(P_RAM_TYPE),
			.address_aclr_b 				("NONE"),
			.address_reg_b  				("CLOCK1"),
			.clock_enable_input_a 			("BYPASS"),
			.clock_enable_input_b 			("BYPASS"),
			.clock_enable_output_b 			("BYPASS"),
			.enable_force_to_zero 			("FALSE"),
			.intended_device_family 		("Cyclone 10 GX"),
			.lpm_type 						("altera_syncram"),
			.numwords_a 					(P_WRDS),
			.numwords_b 					(P_WRDS),
			.operation_mode 				("DUAL_PORT"),
			.outdata_aclr_b 				("NONE"),
			.outdata_sclr_b 				("NONE"),
			.outdata_reg_b 					("UNREGISTERED"),
			.power_up_uninitialized  		("FALSE"),
			.widthad_a 						(P_ADR_WIDTH),
			.widthad_b 						(P_ADR_WIDTH),
			.width_a 						(P_DAT_WIDTH),
			.width_b 						(P_DAT_WIDTH)
		)
		RAM_INST
		(
			.address_a 			(A_ADR_IN),
			.address_b 			(B_ADR_IN),
			.clock0 			(A_CLK_IN),
			.data_a 			(A_DAT_IN),
			.wren_a 			(A_WR_IN),
			.q_b 				(B_DAT_OUT),
			.aclr0 				(1'b0),
			.aclr1 				(1'b0),
			.address2_a 		(1'b1),
			.address2_b 		(1'b1),
			.addressstall_a 	(1'b0),
			.addressstall_b 	(1'b0),
			.byteena_a 			(1'b1),
			.byteena_b 			(1'b1),
			.clock1 			(B_CLK_IN),
			.clocken0 			(1'b1),
			.clocken1 			(1'b1),
			.clocken2 			(1'b1),
			.clocken3 			(1'b1),
			.data_b 			({P_DAT_WIDTH{1'b1}}),
			.eccencbypass 		(1'b0),
			.eccencparity 		(8'b0),
			.eccstatus 			(),
			.q_a 				(),
			.rden_a 			(1'b1),
			.rden_b 			(1'b1),
			.sclr 				(1'b0),
			.wren_b 			(1'b0)
		);
	end

endgenerate

	// Valid
   	always_ff @ (posedge B_CLK_IN)
   	begin
   		bclk_vld <= B_RD_IN;
	end

   	// Outputs
   	assign B_VLD_OUT = bclk_vld;

endmodule

`default_nettype wire
