/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP PM Exchange
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

// Module
module prt_dp_pm_exch
#(
	parameter                P_VENDOR        = "none"  // Vendor "xilinx" or "lattice"
)
(
	// Reset and clock
 	input wire 			RST_IN,		// System reset
	input wire 			CLK_IN,		// System clock

	// Host local bus interface
	prt_dp_lb_if.lb_in		HOST_IF,
  	output wire			HOST_IRQ_OUT,	// Interrupt

	// Policy maker local bus interface
	prt_dp_lb_if.lb_in		PM_IF,
 	output wire			PM_IRQ_OUT,	// Interrupt
 	output wire 			PM_RST_OUT,	// Reset

	// Memory update
 	output wire 			MEM_STR_OUT,	// Start
	output wire [31:0]		MEM_DAT_OUT,	// Data
 	output wire [1:0]		MEM_VLD_OUT	// Valid; 0 - ROM / 1 - RAM
);

// Parameters
localparam P_RAM_WRDS		= 32;
localparam P_RAM_ADR		= $clog2(P_RAM_WRDS);
localparam P_RAM_DAT		= 9;
localparam P_BOXES			= 3;
localparam P_BOX_WRDS		= P_RAM_WRDS;
localparam P_BOX_ADR 		= P_RAM_ADR;

localparam P_HOST_CTL_RUN	= 0;
localparam P_HOST_CTL_IE		= 1;
localparam P_HOST_CTL_MEM_STR	= 2;
localparam P_HOST_CTL_MEM_SEL	= 3;
localparam P_HOST_CTL_BOX_EN	= 4;
localparam P_HOST_CTL_WIDTH 	= 7;

localparam P_HOST_STA_IRQ	= 0;
localparam P_HOST_STA_WIDTH 	= 32;

localparam P_PM_CTL_IE		= 0;
localparam P_PM_CTL_BOX_EN	= 1;
localparam P_PM_CTL_WIDTH 	= 4;

localparam P_PM_STA_IRQ		= 0;
localparam P_PM_STA_WIDTH 	= 8;

localparam P_ADR_CTL 		= 0;
localparam P_ADR_STA 		= 1;
localparam P_ADR_BOX_MAIL_OUT	= 2;
localparam P_ADR_BOX_MAIL_IN 	= 3;
localparam P_ADR_BOX_AUX 	= 4;
localparam P_ADR_MEM 		= 5;

// Structure
typedef struct {
	logic	[P_RAM_ADR-1:0]		a_adr;
	logic						a_wr;
	logic	[P_RAM_DAT-1:0]		a_din;
	logic	[P_RAM_ADR-1:0]		b_adr;
	logic						b_rd;
	logic	[P_RAM_DAT-1:0]		b_dout;
	logic						b_vld;
} ram_struct;

typedef struct {
	logic	[2:0]				adr;
	logic						wr;
	logic						rd;
	logic	[31:0]				din;
	logic	[31:0]				dout;
	logic						vld;

	logic [P_HOST_CTL_WIDTH-1:0]		ctl_r;
	logic  						ctl_run;
	logic  						ctl_ie;
	logic [P_BOXES-1:0]				ctl_box_en;
	logic  						ctl_mem_str;
	logic 						ctl_mem_sel;

	logic   [P_HOST_STA_WIDTH-1:0] 	sta_r;
	logic						sta_irq;
} host_struct;

typedef struct {
	logic						rst;
	logic	[2:0]				adr;
	logic						wr;
	logic						rd;
	logic	[31:0]				din;
	logic	[31:0]				dout;
	logic						vld;

	logic [P_PM_CTL_WIDTH-1:0]		ctl_r;
	logic  						ctl_ie;
	logic [P_BOXES-1:0]				ctl_box_en;

	logic   [P_PM_STA_WIDTH-1:0] 		sta_r;
	logic						sta_irq;
} pm_struct;

typedef struct {
	logic						wr;
	logic   [P_BOX_ADR-1:0]			wp;
	logic						rd;
	logic						rd_fe;
	logic   [P_BOX_ADR-1:0]			rp;
	logic	[P_BOX_ADR:0]			wrds;
	logic						ep;		// Empty
	logic						of;		// Overflow
} box_struct;

typedef struct {
	logic						str;
	logic	[31:0]				dat;
	logic	[1:0]				vld;
} mem_struct;

// Signals
host_struct	clk_host;				// Host
pm_struct	clk_pm;					// Policy maker
ram_struct 	clk_ram[0:P_BOXES-1];	// RAM
mem_struct 	clk_mem;				// Memory
box_struct	clk_box[0:P_BOXES-1];	// Box

genvar i;

// Logic

/*
	Host
*/

// Local bus inputs
// The host can handle longer read latency 
// so the inputs can be registered.
	always_ff @ (posedge CLK_IN)
	begin
		clk_host.adr	<= HOST_IF.adr;
		clk_host.rd		<= HOST_IF.rd;
		clk_host.wr		<= HOST_IF.wr;
		clk_host.din	<= HOST_IF.din;
	end

// Read data
// The host can handle longer latency.
// So the read data is registered
	always_ff @ (posedge CLK_IN)
	begin
		// Default
		clk_host.dout <= 0;

		// Control register
		if (clk_host.adr == P_ADR_CTL)
			clk_host.dout[0+:P_HOST_CTL_WIDTH] <= clk_host.ctl_r;

		// Status register
		else if (clk_host.adr == P_ADR_STA)
			clk_host.dout[0+:P_HOST_STA_WIDTH] <= clk_host.sta_r;

		// Mail in - box 1 - mail pm -> host
		else if (clk_host.adr == P_ADR_BOX_MAIL_IN)
			clk_host.dout[0+:P_RAM_DAT] <= clk_ram[1].b_dout;

		// AUX - box 2 
		else if (clk_host.adr == P_ADR_BOX_AUX)
			clk_host.dout[0+:P_RAM_DAT] <= clk_ram[2].b_dout;
	end

// Valid
	always_ff @ (posedge CLK_IN)
	begin
		clk_host.vld <= clk_host.rd;
	end

// Host Control register
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_host.ctl_r <= 0;

		else
		begin
			// Write
			if (clk_host.wr && (clk_host.adr == P_ADR_CTL))
				clk_host.ctl_r <= clk_host.din[0+:P_HOST_CTL_WIDTH];

			// Automatic clear of mem start bit
			else if (clk_host.ctl_mem_str)
				clk_host.ctl_r[P_HOST_CTL_MEM_STR] <= 0;
		end
	end

	assign clk_host.ctl_run 		= clk_host.ctl_r[P_HOST_CTL_RUN];			// Run
	assign clk_host.ctl_ie 			= clk_host.ctl_r[P_HOST_CTL_IE];			// Interrupt enable
	assign clk_host.ctl_mem_str 	= clk_host.ctl_r[P_HOST_CTL_MEM_STR];		// Memory start
	assign clk_host.ctl_mem_sel 	= clk_host.ctl_r[P_HOST_CTL_MEM_SEL];		// Memory select (0-ROM / 1-RAM)
	assign clk_host.ctl_box_en[0] 	= clk_host.ctl_r[P_HOST_CTL_BOX_EN]; 	
	assign clk_host.ctl_box_en[1] 	= clk_host.ctl_r[P_HOST_CTL_BOX_EN+1]; 
	assign clk_host.ctl_box_en[2] 	= clk_host.ctl_r[P_HOST_CTL_BOX_EN+2]; 

// Host Status register
	assign clk_host.sta_r[P_HOST_STA_IRQ] = clk_host.sta_irq;

	// AXI mapping
	// name 		- order 	- box 
	// mail out 	- 0 		- 0
	// mail in 	- 1		- 1
	// aux in 	- 2 		- 2

	assign clk_host.sta_r[1+:2] 			= {clk_box[0].of, clk_box[0].ep};
	assign clk_host.sta_r[3+:2] 			= {clk_box[1].of, clk_box[1].ep};
	assign clk_host.sta_r[5+:2] 			= {clk_box[2].of, clk_box[2].ep};
	assign clk_host.sta_r[7] 				= 0; // Not used
	assign clk_host.sta_r[8+:P_BOX_ADR] 	= clk_box[0].wrds;
	assign clk_host.sta_r[15:13] 			= 0; // Not used
	assign clk_host.sta_r[16+:P_BOX_ADR] 	= clk_box[1].wrds;
	assign clk_host.sta_r[23:21] 			= 0; // Not used
	assign clk_host.sta_r[24+:P_BOX_ADR] 	= clk_box[2].wrds;
	assign clk_host.sta_r[31:29] 			= 0; // Not used

// Host Interrupt
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_host.sta_irq <= 0;

		else
		begin
			// Clear
			if (clk_host.wr && (clk_host.adr == P_ADR_STA) && clk_host.din[P_HOST_STA_IRQ])
				clk_host.sta_irq <= 0;

			// Set
			// When box 1 or box 2 contains data				
			else if ( clk_host.ctl_ie && (clk_host.ctl_box_en[1] && !clk_box[1].ep) || (clk_host.ctl_box_en[2] && !clk_box[2].ep) )
				clk_host.sta_irq <= 1;
		end
	end

/*
	Policy maker
*/

// Local bus
	always_ff @ (posedge CLK_IN)
	begin
		clk_pm.adr <= PM_IF.adr;
		clk_pm.wr <= PM_IF.wr;
		clk_pm.rd <= PM_IF.rd;
		clk_pm.din <= PM_IF.din;
	end

// Data out
	always_comb
	begin
		// Default
		clk_pm.dout = 0;

		// Control register
		if (clk_pm.adr == P_ADR_CTL)
			clk_pm.dout[0+:P_PM_CTL_WIDTH] = clk_pm.ctl_r;

		// Status register
		else if (clk_pm.adr == P_ADR_STA)
			clk_pm.dout[0+:P_PM_STA_WIDTH] = clk_pm.sta_r;

		// Mail in - box 0 (mail host -> pm)
		else if (clk_pm.adr == P_ADR_BOX_MAIL_IN)
			clk_pm.dout[0+:P_RAM_DAT] = clk_ram[0].b_dout;
	end

// Valid
	always_comb
	begin
		clk_pm.vld = clk_pm.rd;
	end

// PM Control register
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_pm.ctl_r <= 0;

		else
		begin
			// LB write
			if (clk_pm.wr && (clk_pm.adr == P_ADR_CTL))
				clk_pm.ctl_r <= clk_pm.din[0+:P_PM_CTL_WIDTH];
		end
	end

	assign clk_pm.ctl_ie 		= clk_pm.ctl_r[P_PM_CTL_IE];			// Interrupt enable
	assign clk_pm.ctl_box_en[0] 	= clk_pm.ctl_r[P_PM_CTL_BOX_EN+1]; 	// The mail boxes are swapped	
	assign clk_pm.ctl_box_en[1] 	= clk_pm.ctl_r[P_PM_CTL_BOX_EN]; 
	assign clk_pm.ctl_box_en[2] 	= clk_pm.ctl_r[P_PM_CTL_BOX_EN+2]; 

// PM Status register
	assign clk_pm.sta_r[P_PM_STA_IRQ] = clk_pm.sta_irq;

	// LB mapping
	// name 		- order 	- box 
	// mail out 	- 0 		- 1
	// mail in 	- 1		- 0
	// aux out 	- 2 		- 2

	assign clk_pm.sta_r[1+2] = {clk_box[1].of, clk_box[1].ep};
	assign clk_pm.sta_r[3+2] = {clk_box[0].of, clk_box[0].ep};
	assign clk_pm.sta_r[5+2] = {clk_box[2].of, clk_box[2].ep};

// PM Interrupt
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_pm.sta_irq <= 0;

		else
		begin
			// Clear
			if (clk_pm.wr && (clk_pm.adr == P_ADR_STA) && clk_pm.din[P_PM_STA_IRQ])
				clk_pm.sta_irq <= 0;

			// Set
			// When box 0 (mail host -> pm) contains data
			else if (clk_pm.ctl_ie && clk_pm.ctl_box_en[0] && !clk_box[0].ep)
				clk_pm.sta_irq <= 1;
		end
	end

// RAM
generate
	for (i = 0; i < P_BOXES; i++)
	begin : gen_ram
		prt_dp_lib_sdp_ram_sc
		#(
			.P_VENDOR		(P_VENDOR),
			.P_RAM_STYLE	("distributed"),	// "distributed", "block" or "ultra"
			.P_ADR_WIDTH 	(P_RAM_ADR),
			.P_DAT_WIDTH 	(P_RAM_DAT)
		)
		RAM_INST
		(
			// Clocks and reset
			.RST_IN		(RST_IN),			// Reset
			.CLK_IN 		(CLK_IN),			// Clock

			// Port A
			.A_ADR_IN 	(clk_ram[i].a_adr),		// Address
			.A_WR_IN		(clk_ram[i].a_wr),		// Write in
			.A_DAT_IN		(clk_ram[i].a_din),		// Write data

			// Port B
			.B_ADR_IN 	(clk_ram[i].b_adr),		// Address
			.B_RD_IN 		(clk_ram[i].b_rd),		// Read in
			.B_DAT_OUT 	(clk_ram[i].b_dout),	// Read data
			.B_VLD_OUT 	(clk_ram[i].b_vld)		// Read data valid
		);

		// Mapping
	end
endgenerate

// Mapping
// RAM 0 / Box 0 - mail host -> pm
	assign clk_ram[0].a_adr = clk_box[0].wp;
	assign clk_ram[0].b_adr = clk_box[0].rp;
	assign clk_ram[0].a_wr = clk_box[0].wr;
	assign clk_ram[0].b_rd = clk_box[0].rd;
	assign clk_ram[0].a_din = clk_host.din[0+:P_RAM_DAT];

// RAM 1 / Box 1 - mail pm -> host
	assign clk_ram[1].a_adr = clk_box[1].wp;
	assign clk_ram[1].b_adr = clk_box[1].rp;
	assign clk_ram[1].a_wr = clk_box[1].wr;
	assign clk_ram[1].b_rd = clk_box[1].rd;
	assign clk_ram[1].a_din = clk_pm.din[0+:P_RAM_DAT];

// RAM 2 / Box 2 - aux pm -> host
	assign clk_ram[2].a_adr = clk_box[2].wp;
	assign clk_ram[2].b_adr = clk_box[2].rp;
	assign clk_ram[2].a_wr = clk_box[2].wr;
	assign clk_ram[2].b_rd = clk_box[2].rd;
	assign clk_ram[2].a_din = clk_pm.din[0+:P_RAM_DAT];

/*
	Memory Initialization
*/

// Start
	always_ff @ (posedge CLK_IN)
	begin
		clk_mem.str <= clk_host.ctl_mem_str;
	end

// Data
	always_ff @ (posedge CLK_IN)
	begin
		clk_mem.dat <= clk_host.din;
	end

// Valid ROM
	always_ff @ (posedge CLK_IN)
	begin
		if (clk_host.wr && (clk_host.adr == P_ADR_MEM) && !clk_host.ctl_mem_sel)
			clk_mem.vld[0] <= 1;
		else
			clk_mem.vld[0] <= 0;
	end

// Valid RAM
	always_ff @ (posedge CLK_IN)
	begin
		if (clk_host.wr && (clk_host.adr == P_ADR_MEM) && clk_host.ctl_mem_sel)
			clk_mem.vld[1] <= 1;
		else
			clk_mem.vld[1] <= 0;
	end

/*
 	Boxes
	A box is a fifo structure which transfers data from the policy maker to the host or visa versa.
	There are 3 boxes
	0 - mail host->pm
	1 - mail pm->host
	2 - aux
*/

	// Write
	always_comb
	begin
		// Mail host->pm
		if ((clk_host.adr == P_ADR_BOX_MAIL_OUT) && clk_host.wr)
			clk_box[0].wr = 1;
		else
			clk_box[0].wr = 0;

		// Mail pm->host
		if ((clk_pm.adr == P_ADR_BOX_MAIL_OUT) && clk_pm.wr)
			clk_box[1].wr = 1;
		else
			clk_box[1].wr = 0;

		// AUX
		if ((clk_pm.adr == P_ADR_BOX_AUX) && clk_pm.wr)
			clk_box[2].wr = 1;
		else
			clk_box[2].wr = 0;
	end

	// Read
	always_comb
	begin
		// Mail host->pm
		if ((clk_pm.adr == P_ADR_BOX_MAIL_IN) && clk_pm.rd)
			clk_box[0].rd = 1;
		else
			clk_box[0].rd = 0;

		// Mail pm->host
		if ((clk_host.adr == P_ADR_BOX_MAIL_IN) && clk_host.rd)
			clk_box[1].rd = 1;
		else
			clk_box[1].rd = 0;

		// AUX
		if ((clk_host.adr == P_ADR_BOX_AUX) && clk_host.rd)
			clk_box[2].rd = 1;
		else
			clk_box[2].rd = 0;
	end

generate
	for (i = 0; i < P_BOXES; i++)
	begin : gen_box

		// Write pointer
		always_ff @ (posedge CLK_IN)
		begin
			// Enable
			if (clk_host.ctl_box_en[i])
			begin
				// Increment
				if (clk_box[i].wr)
				begin
					// Overflow
					if (&clk_box[i].wp)
						clk_box[i].wp <= 0;

					else
						clk_box[i].wp <= clk_box[i].wp + 'd1;
				end
			end

			// Disable
			else
				clk_box[i].wp <= 0;
		end

		// Read edge detector
		// The box read signal is used to select the ram address
		// After the data has been read the read pointer can be incremented.
		prt_dp_lib_edge
		BOX_RD_EDGE_INST
		(
			.CLK_IN		(CLK_IN),			// Clock
			.CKE_IN		(1'b1),			// Clock enable
			.A_IN		(clk_box[i].rd),	// Input
			.RE_OUT		(),				// Rising edge
			.FE_OUT		(clk_box[i].rd_fe)	// Falling edge
		);

		// Read pointer
		always_ff @ (posedge CLK_IN)
		begin
			// Enable
			if (clk_host.ctl_box_en[i])
			begin
				// Increment
				if (clk_box[i].rd_fe && !clk_box[i].ep)
				begin
					// Overflow
					if (&clk_box[i].rp)
						clk_box[i].rp <= 0;

					else
						clk_box[i].rp <= clk_box[i].rp + 'd1;
				end
			end

			// Disable
			else
				clk_box[i].rp <= 0;
		end

		// Words
		always_comb
		begin
			if (clk_box[i].wp > clk_box[i].rp)
				clk_box[i].wrds = clk_box[i].wp - clk_box[i].rp;

			else if (clk_box[i].wp < clk_box[i].rp)
				clk_box[i].wrds = P_BOX_WRDS - clk_box[i].rp + clk_box[i].wp;

			else
				clk_box[i].wrds = 0;
		end

		// Empty
		always_comb
		begin
			if (clk_box[i].wrds == 0)
				clk_box[i].ep = 1;
			else
				clk_box[i].ep = 0;
		end

		// Overflow
		// This flag is sticky
		always_ff @ (posedge CLK_IN)
		begin
			// Enable
			if (clk_host.ctl_box_en[i] && clk_pm.ctl_box_en[i])
			begin
				// Set
				if ((clk_box[i].wrds == P_BOX_WRDS - 1) && clk_box[i].wr)
					clk_box[i].of <= 1;
			end

			// Disable
			else
				clk_box[i].of <= 0;
		end

	end
endgenerate

// PM reset
	always_ff @ (posedge CLK_IN)
	begin
		clk_pm.rst <= ~clk_host.ctl_run;
	end

// Outputs
	assign HOST_IF.dout 	= clk_host.dout;
	assign HOST_IF.vld		= clk_host.vld;
	assign HOST_IRQ_OUT		= clk_host.sta_irq;
	assign PM_IF.dout 		= clk_pm.dout;
	assign PM_IF.vld		= clk_pm.vld;
	assign PM_IRQ_OUT		= clk_pm.sta_irq;
	assign MEM_STR_OUT 		= clk_mem.str;
	assign MEM_DAT_OUT 		= clk_mem.dat;
	assign MEM_VLD_OUT 		= clk_mem.vld;
	assign PM_RST_OUT 		= clk_pm.rst;

endmodule

`default_nettype wire
