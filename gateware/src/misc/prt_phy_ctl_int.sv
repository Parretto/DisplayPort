/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: PHY controller Intel
    (c) 2023 - 2025 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
	v1.1 - Added PIO

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

module prt_phy_ctl_int
#(
	parameter P_RCFG_PORTS = 4,
	parameter P_RCFG_ADR = 10,
	parameter P_RCFG_DAT = 32,
	parameter P_PIO_IN = 8,
	parameter P_PIO_OUT = 8
)
(
	// Reset and clock
	input wire 										RST_IN,		// Reset
	input wire 										CLK_IN,		// Clock

    // Local bus interface
    prt_dp_lb_if.lb_in      						LB_IF,

    // Reconfig
    output wire [(P_RCFG_PORTS * P_RCFG_ADR)-1:0]	RCFG_ADR_OUT,		// Address
    output wire [P_RCFG_PORTS-1:0]					RCFG_WR_OUT,		// Write
    output wire [P_RCFG_PORTS-1:0]					RCFG_RD_OUT,		// Read
    output wire [(P_RCFG_PORTS * P_RCFG_DAT)-1:0] 	RCFG_DAT_OUT,		// Write data
    input wire  [(P_RCFG_PORTS * P_RCFG_DAT)-1:0] 	RCFG_DAT_IN,		// Read data
    input wire	[P_RCFG_PORTS-1:0] 					RCFG_WAIT_IN,		// Wait request

	// PIO
	input wire 	[P_PIO_IN-1:0]						PIO_DAT_IN,
 	output wire [P_PIO_OUT-1:0]						PIO_DAT_OUT
);

// Parameters
localparam P_RCFG_PORT_WIDTH = $clog2(P_RCFG_PORTS);

// Control register bit locations
localparam P_CTL_WR         = 0;
localparam P_CTL_RD         = 1;
localparam P_CTL_WIDTH      = 2;

// Status register bit locations
localparam P_STA_BUSY       = 0;
localparam P_STA_RDY        = 1;
localparam P_STA_WIDTH      = 2;

// Structures
typedef struct {
    logic   [3:0]               	adr;
    logic                       	wr;
    logic                       	rd;
    logic   [31:0]              	din;
    logic   [31:0]              	dout;
    logic                       	vld;
} lb_struct;

typedef struct {
	logic 							sel;
	logic [P_CTL_WIDTH-1:0]			r;
	logic							wr;
	logic							rd;
} ctl_struct;

typedef struct {
    logic                       	sel;            // Select
    logic   [P_STA_WIDTH-1:0]   	r;              // Register
    logic                       	busy;
    logic                       	rdy;
} sta_struct;

typedef struct {
	logic 							sel_adr;
	logic 							sel_dat;
	logic [P_RCFG_PORT_WIDTH-1:0]	port;
	logic [P_RCFG_ADR-1:0]			adr;
	logic [P_RCFG_PORTS-1:0]		wr;
	logic [P_RCFG_PORTS-1:0]		rd;
	logic [P_RCFG_DAT-1:0]			din;
	logic [P_RCFG_DAT-1:0]			dout;
	logic [P_RCFG_PORTS-1:0]		wait_fe;
} rcfg_struct;

typedef struct {
	logic							sel_din;			// Select data in
	logic							sel_dout_set;		// Select data out set
	logic							sel_dout_clr;		// Select data out clear
	logic							sel_dout;			// Select data out
	logic							sel_msk;			// Select mask
	logic	[P_PIO_IN-1:0]			din;				// Data in
	logic	[P_PIO_OUT-1:0]			dout;				// Data out
	logic	[P_PIO_OUT-1:0]			msk;				// Mask
} pio_struct;

// Signals
lb_struct							clk_lb;
ctl_struct 							clk_ctl;
sta_struct 							clk_sta;
rcfg_struct							clk_rcfg;
pio_struct							clk_pio;	

genvar i;

// Logic

/*
    Registers
*/
// Local bus inputs
    always_ff @ (posedge CLK_IN)
    begin
        clk_lb.adr      <= LB_IF.adr;
        clk_lb.rd       <= LB_IF.rd;
        clk_lb.wr       <= LB_IF.wr;
        clk_lb.din      <= LB_IF.din;
    end

// Address selector
// Must be combinatorial
    always_comb
    begin
        // Default
        clk_ctl.sel 			= 0;
        clk_sta.sel 			= 0;
        clk_rcfg.sel_adr		= 0;
        clk_rcfg.sel_dat		= 0;
   		clk_pio.sel_din 		= 0;
		clk_pio.sel_dout_set 	= 0;
		clk_pio.sel_dout_clr 	= 0;
		clk_pio.sel_dout 		= 0;
		clk_pio.sel_msk 		= 0;

        case (clk_lb.adr)
            'd0  	: clk_ctl.sel   		= 1;
            'd1  	: clk_sta.sel			= 1;
            'd2  	: clk_rcfg.sel_adr		= 1;
            'd3  	: clk_rcfg.sel_dat		= 1;
   			'd4 	: clk_pio.sel_din 		= 1;
			'd5		: clk_pio.sel_dout_set 	= 1;
			'd6 	: clk_pio.sel_dout_clr 	= 1;
			'd7 	: clk_pio.sel_dout 		= 1;
			'd8		: clk_pio.sel_msk 		= 1;
            default : ;
        endcase
    end

// Register data out
// Must be combinatorial
    always_comb
    begin
        // Default
        clk_lb.dout = 0;

        // Control register
        if (clk_ctl.sel)
            clk_lb.dout[0+:$size(clk_ctl.r)] = clk_ctl.r;

        // Status register
        else if (clk_sta.sel)
            clk_lb.dout[0+:$size(clk_sta.r)] = clk_sta.r;

		// PIO data in
		else if (clk_pio.sel_din)
			clk_lb.dout[$size(clk_pio.din)-1:0] = clk_pio.din;

        // Reconfig Read data
        else
            clk_lb.dout[0+:$size(clk_rcfg.din)] = clk_rcfg.din;
    end

// Valid
// Must be combinatorial
    always_comb
    begin
        if (clk_lb.rd)
            clk_lb.vld = 1;
        else
            clk_lb.vld = 0;
    end

// Control register
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_ctl.r <= 0;

		else
		begin
			// Load
			if (clk_ctl.sel && clk_lb.wr)
				clk_ctl.r <= clk_lb.din[0+:P_CTL_WIDTH];

			// Automatic clear of write and read flags
			else 
			begin
				clk_ctl.r[P_CTL_WR] <= 0;
				clk_ctl.r[P_CTL_RD] <= 0;
			end		
		end
	end

	assign clk_ctl.wr = clk_ctl.r[P_CTL_WR];
	assign clk_ctl.rd = clk_ctl.r[P_CTL_RD];

// Status
	assign clk_sta.r[P_STA_BUSY] = clk_sta.busy;
	assign clk_sta.r[P_STA_RDY] = clk_sta.rdy;

// Busy
	always_ff @ (posedge CLK_IN)
	begin
		// Set
		if (clk_ctl.wr || clk_ctl.rd)
			clk_sta.busy <= 1;

		// Clear
		else if (!RCFG_WAIT_IN[clk_rcfg.port])
			clk_sta.busy <= 0;
	end

// Read data ready
	always_ff @ (posedge CLK_IN)
	begin
		// Clear
		if (clk_sta.sel && clk_lb.wr && clk_lb.din[P_STA_RDY])
			clk_sta.rdy <= 0;

		// Set
		else if (clk_rcfg.rd[clk_rcfg.port] && clk_rcfg.wait_fe[clk_rcfg.port])
			clk_sta.rdy <= 1;
	end

/*
	Reconfig
*/

// Wait request edge
generate
	for (i = 0; i < P_RCFG_PORTS; i++)
	begin : gen_rcfg_wait_edge
		prt_dp_lib_edge
		RCFG_WAIT_EDGE_INST
		(
			.CLK_IN		(CLK_IN),				// Clock
			.CKE_IN		(1'b1),					// Clock enable
			.A_IN		(RCFG_WAIT_IN[i]),		// Input
			.RE_OUT		(),						// Rising edge
			.FE_OUT		(clk_rcfg.wait_fe[i])	// Falling edge
		);
	end
endgenerate

// Port
	always_ff @ (posedge CLK_IN)
	begin
		// Write 
		if (clk_rcfg.sel_adr && clk_lb.wr)
			clk_rcfg.port <= clk_lb.din[0+:$size(clk_rcfg.port)];
	end

// Address
	always_ff @ (posedge CLK_IN)
	begin
		// Write 
		if (clk_rcfg.sel_adr && clk_lb.wr)
			clk_rcfg.adr <= clk_lb.din[P_RCFG_PORT_WIDTH+:$size(clk_rcfg.adr)];
	end

// Data out
	always_ff @ (posedge CLK_IN)
	begin
		// Write 
		if (clk_rcfg.sel_dat && clk_lb.wr)
			clk_rcfg.dout <= clk_lb.din[0+:$size(clk_rcfg.dout)];
	end

// Data in
	always_ff @ (posedge CLK_IN)
	begin
		for (int i = 0; i < P_RCFG_PORTS; i++)
		begin
			if (clk_rcfg.rd[i] && clk_rcfg.wait_fe[i])
				clk_rcfg.din <= RCFG_DAT_IN[(i*P_RCFG_DAT)+:P_RCFG_DAT];
		end
	end

// Write
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_rcfg.wr <= 0;

		else
		begin
			for (int i = 0; i < P_RCFG_PORTS; i++)
			begin
				if (clk_rcfg.port == i)
				begin
					// Write
					if (clk_ctl.wr)
						clk_rcfg.wr[i] <= 1;

					// Clear
					else if (!(RCFG_WAIT_IN[i]))
						clk_rcfg.wr[i] <= 0;
				end

				else
					clk_rcfg.wr[i] <= 0;
			end
		end	
	end

// Read
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_rcfg.rd <= 0;

		else
		begin
			for (int i = 0; i < P_RCFG_PORTS; i++)
			begin
				if (clk_rcfg.port == i)
				begin
					// Write
					if (clk_ctl.rd)
						clk_rcfg.rd[i] <= 1;

					// Clear
					else if (!(RCFG_WAIT_IN[i]))
						clk_rcfg.rd[i] <= 0;
				end

				else
					clk_rcfg.rd[i] <= 0;
			end
		end	
	end

/*
	 PIO
*/

// PIO input
	always_ff @ (posedge CLK_IN)
	begin
		clk_pio.din <= PIO_DAT_IN;
	end

// PIO mask
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_pio.msk <= 0;
		
		else
		begin
			// Load
			if (clk_pio.sel_msk && clk_lb.wr)
				clk_pio.msk <= clk_lb.din[0+:$size(clk_pio.msk)];
			
			// Reset the mask after the data has been written
			else if (clk_pio.sel_dout && clk_lb.wr)
				clk_pio.msk <= '1;
		end
	end

// PIO output
generate
	for (i = 0; i < $size(clk_pio.dout); i++)
	begin : gen_pio_out
		always_ff @ (posedge RST_IN, posedge CLK_IN)
		begin
			// Reset
			if (RST_IN)
				clk_pio.dout[i] <= 0;
			
			else
			begin
				// Set
				if (clk_pio.sel_dout_set && clk_lb.wr && clk_lb.din[i])
					clk_pio.dout[i] <= 1;

				// Clear
				else if (clk_pio.sel_dout_clr && clk_lb.wr && clk_lb.din[i])
					clk_pio.dout[i] <= 0;

				// Data out with mask
				else if (clk_pio.sel_dout && clk_lb.wr && clk_pio.msk[i])
					clk_pio.dout[i] <= clk_lb.din[i];
			end
		end
	end
endgenerate

// Outputs
    assign LB_IF.dout       = clk_lb.dout;
    assign LB_IF.vld        = clk_lb.vld;

	assign RCFG_WR_OUT  	= clk_rcfg.wr;
	assign RCFG_RD_OUT  	= clk_rcfg.rd;
	assign RCFG_ADR_OUT 	= {P_RCFG_PORTS{clk_rcfg.adr}};
	assign RCFG_DAT_OUT 	= {P_RCFG_PORTS{clk_rcfg.dout}};

	assign PIO_DAT_OUT		= clk_pio.dout;

endmodule

`default_nettype wire
