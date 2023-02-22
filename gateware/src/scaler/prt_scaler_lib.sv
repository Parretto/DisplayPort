/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Scaler Library
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

`timescale 1 ps / 1 ps
`default_nettype none

/*
	Edge Detector
*/
module prt_scaler_lib_edge
(
	input wire	CLK_IN,			// Clock
	input wire	CKE_IN,			// Clock enable
	input wire	A_IN,			// Input
	output wire	RE_OUT,			// Rising edge
	output wire	FE_OUT			// Falling edge
);

// Signals
logic clk_a_del;
logic clk_a_re;
logic clk_a_fe;

// Logic
// Input Registers
	always_ff @ (posedge CLK_IN)
	begin
			// Clock enable
			if (CKE_IN)
				clk_a_del	<= A_IN;
	end

// Rising Edge Detector
	always_comb
	begin
		if (A_IN && !clk_a_del)
			clk_a_re = 1;
		else
			clk_a_re = 0;
	end

// Falling Edge Detector
	always_comb
	begin
		if (!A_IN && clk_a_del)
			clk_a_fe = 1;
		else
			clk_a_fe = 0;
	end

// Outputs
	assign RE_OUT = clk_a_re;
	assign FE_OUT = clk_a_fe;

endmodule

/*
	Clock domain crossing
*/
module prt_scaler_lib_cdc
#(
	parameter P_WIDTH = 1
)
(
	input wire				SRC_CLK_IN,		// Clock
	input wire [P_WIDTH-1:0] 	SRC_DAT_IN,		// Data
	input wire				DST_CLK_IN,		// Clock
	output wire [P_WIDTH-1:0] 	DST_DAT_OUT		// Data
);

// Parameters
localparam P_STAGES = 4;

// Signals
// The signals must have an unique name,
// so they can be found by the set_false_path constraint
(* dont_touch = "yes" *) logic [P_WIDTH-1:0]		prt_scaler_lib_cdc_bit_sclk_dat;
(* dont_touch = "yes" *) logic [P_WIDTH-1:0]		prt_scaler_lib_cdc_bit_dclk_dat[P_STAGES-1:0];

// Logic

// Source register
	always_ff @ (posedge SRC_CLK_IN)
	begin
		prt_scaler_lib_cdc_bit_sclk_dat <= SRC_DAT_IN;
	end

// Destination register
	always_ff @ (posedge DST_CLK_IN)
	begin
		prt_scaler_lib_cdc_bit_dclk_dat <= {prt_scaler_lib_cdc_bit_dclk_dat[0+:P_STAGES-1], prt_scaler_lib_cdc_bit_sclk_dat};
	end

// Output
	assign DST_DAT_OUT = prt_scaler_lib_cdc_bit_dclk_dat[P_STAGES-1];

endmodule


/*
	Single clock FIFO
*/
module prt_scaler_lib_fifo_sc
#(
	parameter                       P_VENDOR    	= "none",  // Vendor "xilinx" or "lattice"
	parameter						P_MODE         	= "single",		// "single" or "burst"
	parameter 						P_RAM_STYLE		= "distributed",	// "distributed" or "block"
	parameter 						P_ADR_WIDTH 	= 7,
	parameter						P_DAT_WIDTH 	= 512
)
(
	// Clocks and reset
	input wire						RST_IN,		// Reset
	input wire						CLK_IN,		// Clock

	// Write
	input wire						WR_EN_IN,	// Write enable
	input wire						WR_CLR_IN,	// Write clear
	input wire						WR_IN,		// Write in
	input wire 	[P_DAT_WIDTH-1:0]	DAT_IN,		// Write data

	// Read
	input wire						RD_EN_IN,	// Read enable in
	input wire						RD_CLR_IN,	// Read clear in
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
logic	[1:0]				clk_de;
logic	[P_ADR_WIDTH-1:0]	clk_wrds;
logic						clk_ep;
logic						clk_fl;

// Logic

// RAM instantiation
generate
	if (P_VENDOR == "xilinx")
	begin : gen_ram_xlx
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
			.READ_LATENCY_B				(2),      
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
			.clka				(CLK_IN),       
			.addra				(clk_wp), 
			.dina				(DAT_IN),
			.ena				(WR_EN_IN), 
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

	else if (P_VENDOR == "lattice")
	begin : gen_ram_lat
		pmi_ram_dp
		#(
			.pmi_wr_addr_depth    (P_WRDS), 		// integer
			.pmi_wr_addr_width    (P_ADR_WIDTH), 	// integer
			.pmi_wr_data_width    (P_DAT_WIDTH), 	// integer
			.pmi_rd_addr_depth    (P_WRDS), 		// integer
			.pmi_rd_addr_width    (P_ADR_WIDTH), 	// integer
			.pmi_rd_data_width    (P_DAT_WIDTH), 	// integer
			.pmi_regmode          ("reg"), 		// "reg"|"noreg"
			.pmi_resetmode        ("async"), 		// "async"|"sync"
			.pmi_init_file        ("none"), 		// string
			.pmi_init_file_format ("hex"), 		// "binary"|"hex"
			.pmi_family           ("common")  		// "LIFCL"|"LFD2NX"|"LFCPNX"|"LFMXO5"|"UT24C"|"UT24CP"|"common"
		) 
		RAM_INST
		(
			.Reset     	(RST_IN),  

			.WrClock   	(CLK_IN),  
			.WrClockEn 	(WR_EN_IN),
			.WrAddress 	(clk_wp),  
			.WE        	(WR_IN),  
			.Data      	(DAT_IN), 

			.RdClock   	(CLK_IN), 
			.RdClockEn 	(RD_EN_IN),
			.RdAddress 	(clk_rp),  

			.Q         	(DAT_OUT)  
		);
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
			if (WR_CLR_IN)
				clk_wp <= 0;

			// Write enable
			else if (WR_EN_IN)
			begin
				// Write
				if (WR_IN)
				begin
					// Check for overflow
					if (&clk_wp)
						clk_wp <= 0;
					else
						clk_wp <= clk_wp + 'd1;
				end
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
			if (RD_CLR_IN)
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
	always_comb
	begin
		if (clk_wp > clk_rp)
			clk_wrds = clk_wp - clk_rp;

		else if (clk_wp < clk_rp)
			clk_wrds = (P_WRDS - clk_rp) + clk_wp;

		else
			clk_wrds = 0;
	end

// Outputs
	assign DE_OUT 		= clk_de[$size(clk_de)-1];
	assign WRDS_OUT 	= clk_wrds;
	assign EP_OUT 		= clk_ep;
	assign FL_OUT 		= clk_fl;

endmodule

/*
	Simple dual port RAM dual clock
*/
module prt_scaler_lib_sdp_ram_dc
#(
     // System
	parameter                       P_VENDOR    	= "none",  // Vendor "xilinx" or "lattice"

	parameter 						P_RAM_STYLE	= "distributed",	// "distributed", "block" or "ultra"
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
	output wire [P_DAT_WIDTH-1:0]	B_DAT_OUT,	// Read data
	output wire						B_VLD_OUT		// Read data valid
);

// Local parameters
localparam P_WRDS = 2**P_ADR_WIDTH;

// Signals
logic	bclk_vld;

// Logic

// RAM instantiation
generate
	if (P_VENDOR == "xilinx")
	begin : gen_ram_xlx

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

	else if (P_VENDOR == "lattice")
	begin : gen_ram_lat

		// One single clock read latency is assumed.
		// The distributed read path is asynchronous.
		// Therefore the output register is enabled.
		pmi_distributed_dpram
		#(
		  .pmi_addr_depth       	(P_WRDS), 	// integer      
		  .pmi_addr_width       	(P_ADR_WIDTH), // integer      
		  .pmi_data_width       	(P_DAT_WIDTH), // integer      
		  .pmi_regmode          	("reg"), 	// "reg"|"noreg"    
		  .pmi_init_file        	("none"), 	// string       
		  .pmi_init_file_format 	("hex"), 		// "binary"|"hex"     
		  .pmi_family           	("common")  	// "LIFCL"|"LFD2NX"|"LFCPNX"|"LFMXO5"|"UT24C"|"UT24CP"|"common"    
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
