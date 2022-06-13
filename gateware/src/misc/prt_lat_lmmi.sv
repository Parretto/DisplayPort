/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Lattice LMMI Peripheral 
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

module prt_lat_lmmi
#(
	parameter P_LMMI_PORTS = 4,
	parameter P_LMMI_ADR = 9,
	parameter P_LMMI_DAT = 8
)
(
	// Reset and clock
	input wire 										RST_IN,		// Reset
	input wire 										CLK_IN,		// Clock

    // Local bus interface
    prt_dp_lb_if.lb_in      						LB_IF,

    // LMMI
    output wire [P_LMMI_PORTS-1:0]					LMMI_REQ_OUT,		// Request
    output wire [P_LMMI_PORTS-1:0]					LMMI_DIR_OUT,		// Direction
    output wire [(P_LMMI_PORTS * P_LMMI_ADR)-1:0]	LMMI_ADR_OUT,		// Address
    output wire [(P_LMMI_PORTS * P_LMMI_DAT)-1:0] 	LMMI_DAT_OUT,		// Write data
    input wire  [(P_LMMI_PORTS * P_LMMI_DAT)-1:0] 	LMMI_DAT_IN,		// Read data
    input wire	[P_LMMI_PORTS-1:0] 					LMMI_VLD_IN,		// Valid
    input wire	[P_LMMI_PORTS-1:0] 					LMMI_RDY_IN			// Ready
);

// Parameters
localparam P_LMMI_PORT_WIDTH = $clog2(P_LMMI_PORTS);

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
	logic 							sel;
	logic [P_LMMI_PORT_WIDTH-1:0]	port;
	logic [P_LMMI_ADR-1:0]			adr;
	logic [P_LMMI_PORTS-1:0]		req;
	logic [P_LMMI_PORTS-1:0]		dir;
	logic [P_LMMI_DAT-1:0]			din;
	logic [P_LMMI_DAT-1:0]			dout;
	logic [P_LMMI_PORTS-1:0]		vld_re;
} lmmi_struct;

// Signals
lb_struct							clk_lb;
ctl_struct 							clk_ctl;
sta_struct 							clk_sta;
lmmi_struct							clk_lmmi;

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
        clk_ctl.sel 	= 0;
        clk_sta.sel 	= 0;
        clk_lmmi.sel	= 0;
        
        case (clk_lb.adr)
            'd0  	: clk_ctl.sel   	= 1;
            'd1  	: clk_sta.sel		= 1;
            'd2  	: clk_lmmi.sel		= 1;
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

        // LMMI Read data
        else
            clk_lb.dout[0+:$size(clk_lmmi.din)] = clk_lmmi.din;
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
		else if (|LMMI_RDY_IN)
			clk_sta.busy <= 0;
	end

// Read data ready
	always_ff @ (posedge CLK_IN)
	begin
		// Clear
		if (clk_sta.sel && clk_lb.wr && clk_lb.din[P_STA_RDY])
			clk_sta.rdy <= 0;

		// Set
		else if (|clk_lmmi.vld_re)
			clk_sta.rdy <= 1;
	end

/*
	LMMI
*/

// Port
	always_ff @ (posedge CLK_IN)
	begin
		// Write 
		if (clk_lmmi.sel && clk_lb.wr)
			clk_lmmi.port <= clk_lb.din[0+:$size(clk_lmmi.port)];
	end

// Address
	always_ff @ (posedge CLK_IN)
	begin
		// Write 
		if (clk_lmmi.sel && clk_lb.wr)
			clk_lmmi.adr <= clk_lb.din[P_LMMI_PORT_WIDTH+:$size(clk_lmmi.adr)];
	end

// Data out
	always_ff @ (posedge CLK_IN)
	begin
		// Write 
		if (clk_lmmi.sel && clk_lb.wr)
			clk_lmmi.dout <= clk_lb.din[P_LMMI_PORT_WIDTH+P_LMMI_ADR+:$size(clk_lmmi.dout)];
	end

// Valid edge
generate
	for (i = 0; i < P_LMMI_PORTS; i++)
	begin : gen_lmmi_vld
		prt_dp_lib_edge
		LMMI_RDY_EDGE_INST
		(
			.CLK_IN		(CLK_IN),				// Clock
			.CKE_IN		(1'b1),					// Clock enable
			.A_IN		(LMMI_VLD_IN[i]),		// Input
			.RE_OUT		(clk_lmmi.vld_re[i]),	// Rising edge
			.FE_OUT		()						// Falling edge
		);
	end
endgenerate

// Data in
	always_ff @ (posedge CLK_IN)
	begin
		for (int i = 0; i < P_LMMI_PORTS; i++)
		begin
			if (clk_lmmi.vld_re[i])
				clk_lmmi.din <= LMMI_DAT_IN[(i*P_LMMI_DAT)+:P_LMMI_DAT];
		end
	end

// Request
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_lmmi.req <= 0;

		else
		begin
			for (int i = 0; i < P_LMMI_PORTS; i++)
			begin
				if (clk_lmmi.port == i)
				begin
					// Write or read
					if (clk_ctl.wr || clk_ctl.rd)
						clk_lmmi.req[i] <= 1;

					// Clear
					else if (LMMI_RDY_IN[i])
						clk_lmmi.req[i] <= 0;
				end

				else
					clk_lmmi.req[i] <= 0;
			end
		end	
	end

// Direction 
// 1 - write / 0 - read
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_lmmi.dir <= 0;

		else
		begin
			for (int i = 0; i < P_LMMI_PORTS; i++)
			begin
				if (clk_lmmi.port == i)
				begin
					// Write 
					if (clk_ctl.wr)
						clk_lmmi.dir[i] <= 1;

					// Read
					else if (clk_ctl.rd)
						clk_lmmi.dir[i] <= 0;
				end

				else
					clk_lmmi.dir[i] <= 0;
			end
		end	
	end

// Outputs
    assign LB_IF.dout       = clk_lb.dout;
    assign LB_IF.vld        = clk_lb.vld;

	assign LMMI_REQ_OUT  	= clk_lmmi.req;
	assign LMMI_DIR_OUT  	= clk_lmmi.dir;
	assign LMMI_ADR_OUT 	= {P_LMMI_PORTS{clk_lmmi.adr}};
	assign LMMI_DAT_OUT 	= {P_LMMI_PORTS{clk_lmmi.dout}};

endmodule

`default_nettype wire
