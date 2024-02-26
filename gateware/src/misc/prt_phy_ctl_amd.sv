/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: PHY controller AMD
    (c) 2021 - 2024 by Parretto B.V.

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

module prt_phy_ctl_amd
#(
	parameter P_DRP_PORTS = 5,
	parameter P_DRP_ADR = 10,
	parameter P_DRP_DAT = 10,
	parameter P_PIO_IN = 8,
	parameter P_PIO_OUT = 8
)
(
	// Reset and clock
	input wire 										SYS_RST_IN,		// Reset
	input wire 										SYS_CLK_IN,		// Clock

    // Local bus interface
    prt_dp_lb_if.lb_in      						LB_IF,

    // DRP
    input wire										DRP_CLK_IN,
    output wire [(P_DRP_PORTS * P_DRP_ADR)-1:0]		DRP_ADR_OUT,
    output wire [(P_DRP_PORTS * P_DRP_DAT)-1:0] 	DRP_DAT_OUT,
	output wire	[P_DRP_PORTS-1:0] 					DRP_EN_OUT,
	output wire	[P_DRP_PORTS-1:0] 					DRP_WR_OUT,
	input wire  [(P_DRP_PORTS * P_DRP_DAT)-1:0] 	DRP_DAT_IN,
	input wire	[P_DRP_PORTS-1:0] 					DRP_RDY_IN,

	// PIO
	input wire 	[P_PIO_IN-1:0]						PIO_DAT_IN,
 	output wire [P_PIO_OUT-1:0]						PIO_DAT_OUT
);

// Parameters
localparam P_DRP_PORT_WIDTH	= $clog2(P_DRP_PORTS);
localparam P_DRP_CMD_WIDTH = 2 + P_DRP_PORT_WIDTH + P_DRP_ADR + P_DRP_DAT;
localparam P_DRP_FB_WIDTH = 3 + P_DRP_DAT;

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
	logic							sel;
	logic							cmd_wr;
	logic							cmd_rd;
	logic [P_DRP_CMD_WIDTH-1:0]		cmd;
	logic [P_DRP_FB_WIDTH-1:0]		fb;
	logic							fb_wr;
	logic							fb_wr_re;
	logic							fb_rd;
	logic							fb_rd_re;
	logic							fb_rdy;
	logic							fb_rdy_re;
	logic [P_DRP_PORT_WIDTH-1:0]	port;
	logic [P_DRP_ADR-1:0]			adr;
	logic [P_DRP_DAT-1:0]			dout;
	logic [P_DRP_DAT-1:0]			din;
} sdrp_struct;

typedef struct {
	logic [P_DRP_CMD_WIDTH-1:0]		cmd;
	logic							cmd_wr;
	logic							cmd_wr_re;
	logic							cmd_rd;
	logic							cmd_rd_re;
	logic [P_DRP_PORT_WIDTH-1:0]	port;
	logic [P_DRP_ADR-1:0]			adr;
	logic [P_DRP_PORTS-1:0]			en;
	logic [P_DRP_PORTS-1:0]			wr;
	logic [P_DRP_PORTS-1:0]			rdy_re;
	logic [P_DRP_DAT-1:0]			din;
	logic [P_DRP_DAT-1:0]			dout;
	logic [P_DRP_FB_WIDTH-1:0]		fb;
	logic							fb_rdy;
} ddrp_struct;

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
lb_struct							sclk_lb;
ctl_struct 							sclk_ctl;
sta_struct 							sclk_sta;
sdrp_struct							sclk_drp;
ddrp_struct							dclk_drp;
pio_struct							sclk_pio;	

genvar i;

// Logic

/*
    Registers
*/
// Local bus inputs
    always_ff @ (posedge SYS_CLK_IN)
    begin
        sclk_lb.adr	<= LB_IF.adr;
        sclk_lb.rd  <= LB_IF.rd;
        sclk_lb.wr  <= LB_IF.wr;
        sclk_lb.din <= LB_IF.din;
    end

// Address selector
// Must be combinatorial
    always_comb
    begin
        // Default
        sclk_ctl.sel 			= 0;
        sclk_sta.sel 			= 0;
        sclk_drp.sel 			= 0;
   		sclk_pio.sel_din 		= 0;
		sclk_pio.sel_dout_set 	= 0;
		sclk_pio.sel_dout_clr 	= 0;
		sclk_pio.sel_dout 		= 0;
		sclk_pio.sel_msk 		= 0;

        case (sclk_lb.adr)
            'd0 : sclk_ctl.sel 			= 1;
            'd1 : sclk_sta.sel			= 1;
            'd2 : sclk_drp.sel			= 1;
			'd3 : sclk_pio.sel_din		= 1;
			'd4 : sclk_pio.sel_dout_set	= 1;
			'd5 : sclk_pio.sel_dout_clr	= 1;
			'd6 : sclk_pio.sel_dout		= 1;
			'd7 : sclk_pio.sel_msk		= 1;
            default : ;
        endcase
    end

// Register data out
// Must be combinatorial
    always_comb
    begin
        // Default
        sclk_lb.dout = 0;

        // Control register
        if (sclk_ctl.sel)
            sclk_lb.dout[0+:$size(sclk_ctl.r)] = sclk_ctl.r;

        // Status register
        else if (sclk_sta.sel)
            sclk_lb.dout[0+:$size(sclk_sta.r)] = sclk_sta.r;

		// PIO data in
		else if (sclk_pio.sel_din)
			sclk_lb.dout[$size(sclk_pio.din)-1:0] = sclk_pio.din;

        // DRP Read data
        else
            sclk_lb.dout[0+:$size(sclk_drp.din)] = sclk_drp.din;
    end

// Valid
// Must be combinatorial
    always_comb
    begin
        if (sclk_lb.rd)
            sclk_lb.vld = 1;
        else
            sclk_lb.vld = 0;
    end

// Control register
	always_ff @ (posedge SYS_RST_IN, posedge SYS_CLK_IN)
	begin
		// Reset
		if (SYS_RST_IN)
			sclk_ctl.r <= 0;

		else
		begin
			// Load
			if (sclk_ctl.sel && sclk_lb.wr)
				sclk_ctl.r <= sclk_lb.din[0+:P_CTL_WIDTH];

			// Automatic clear of write and read flags
			else
			begin
				sclk_ctl.r[P_CTL_WR] <= 0;
				sclk_ctl.r[P_CTL_RD] <= 0;
			end		
		end
	end

	assign sclk_ctl.wr = sclk_ctl.r[P_CTL_WR];
	assign sclk_ctl.rd = sclk_ctl.r[P_CTL_RD];

// Status
	assign sclk_sta.r[P_STA_BUSY] = sclk_sta.busy;
	assign sclk_sta.r[P_STA_RDY] = sclk_sta.rdy;

// Busy
	always_ff @ (posedge SYS_CLK_IN)
	begin
		if (sclk_drp.cmd_wr || sclk_drp.cmd_rd)
			sclk_sta.busy <= 1;
		else
			sclk_sta.busy <= 0;
	end

// Read data ready
	always_ff @ (posedge SYS_CLK_IN)
	begin
		// Clear
		if (sclk_ctl.rd || (sclk_sta.sel && sclk_lb.wr && sclk_lb.din[P_STA_RDY]))
			sclk_sta.rdy <= 0;

		// Set
		else if (sclk_drp.fb_rdy_re)
			sclk_sta.rdy <= 1;
	end

// Port
	always_ff @ (posedge SYS_CLK_IN)
	begin
		// Write 
		if (sclk_drp.sel && sclk_lb.wr)
			sclk_drp.port <= sclk_lb.din[0+:$size(sclk_drp.port)];
	end

// Address
	always_ff @ (posedge SYS_CLK_IN)
	begin
		// Write 
		if (sclk_drp.sel && sclk_lb.wr)
			sclk_drp.adr <= sclk_lb.din[P_DRP_PORT_WIDTH+:$size(sclk_drp.adr)];
	end

// Data out
	always_ff @ (posedge SYS_CLK_IN)
	begin
		// Write 
		if (sclk_drp.sel && sclk_lb.wr)
			sclk_drp.dout <= sclk_lb.din[P_DRP_PORT_WIDTH+P_DRP_ADR+:$size(sclk_drp.dout)];
	end

// DRP write command
	always_ff @ (posedge SYS_RST_IN, posedge SYS_CLK_IN)
	begin
		// Reset
		if (SYS_RST_IN)
			sclk_drp.cmd_wr <= 0;

		else
		begin
			// Set
			if (sclk_ctl.wr)
				sclk_drp.cmd_wr <= 1;

			// Clear
			else if (sclk_drp.fb_wr_re)
				sclk_drp.cmd_wr <= 0;		
		end
	end

// DRP read command
	always_ff @ (posedge SYS_RST_IN, posedge SYS_CLK_IN)
	begin
		// Reset
		if (SYS_RST_IN)
			sclk_drp.cmd_rd <= 0;

		else
		begin
			// Set
			if (sclk_ctl.rd)
				sclk_drp.cmd_rd <= 1;

			// Clear
			else if (sclk_drp.fb_rd_re)
				sclk_drp.cmd_rd <= 0;		
		end
	end

// Command
	assign sclk_drp.cmd = {sclk_drp.dout, sclk_drp.adr, sclk_drp.port, sclk_drp.cmd_rd, sclk_drp.cmd_wr};

// Feedback clock domain converter
	prt_dp_lib_cdc_vec
	#(
		.P_WIDTH		(P_DRP_FB_WIDTH)
	)
	DRP_FB_CDC_INST
	(
		.SRC_CLK_IN		(DRP_CLK_IN),	// Clock
		.SRC_DAT_IN		(dclk_drp.fb),	// Data
		.DST_CLK_IN		(SYS_CLK_IN),	// Clock
		.DST_DAT_OUT	(sclk_drp.fb)	// Data
	);

	assign {sclk_drp.din, sclk_drp.fb_rdy, sclk_drp.fb_rd, sclk_drp.fb_wr} = sclk_drp.fb;

	prt_dp_lib_edge
	SYS_FB_WR_EDGE_INST
	(
		.CLK_IN		(SYS_CLK_IN),			// Clock
		.CKE_IN		(1'b1),					// Clock enable
		.A_IN		(sclk_drp.fb_wr),		// Input
		.RE_OUT		(sclk_drp.fb_wr_re),	// Rising edge
		.FE_OUT		()						// Falling edge
	);

	prt_dp_lib_edge
	SYS_FB_RD_EDGE_INST
	(
		.CLK_IN		(SYS_CLK_IN),			// Clock
		.CKE_IN		(1'b1),					// Clock enable
		.A_IN		(sclk_drp.fb_rd),		// Input
		.RE_OUT		(sclk_drp.fb_rd_re),	// Rising edge
		.FE_OUT		()						// Falling edge
	);

	prt_dp_lib_edge
	SYS_FB_RDY_EDGE_INST
	(
		.CLK_IN		(SYS_CLK_IN),			// Clock
		.CKE_IN		(1'b1),					// Clock enable
		.A_IN		(sclk_drp.fb_rdy),		// Input
		.RE_OUT		(sclk_drp.fb_rdy_re),	// Rising edge
		.FE_OUT		()						// Falling edge
	);


/*
	DRP
*/

// Command clock domain converter
	prt_dp_lib_cdc_vec
	#(
		.P_WIDTH		(P_DRP_CMD_WIDTH)
	)
	DRP_CMD_CDC_INST
	(
		.SRC_CLK_IN		(SYS_CLK_IN),	// Clock
		.SRC_DAT_IN		(sclk_drp.cmd),	// Data
		.DST_CLK_IN		(DRP_CLK_IN),	// Clock
		.DST_DAT_OUT	(dclk_drp.cmd)	// Data
	);


	assign {dclk_drp.dout, dclk_drp.adr, dclk_drp.port, dclk_drp.cmd_rd, dclk_drp.cmd_wr} = dclk_drp.cmd;
	
	prt_dp_lib_edge
	DRP_WR_EDGE_INST
	(
		.CLK_IN		(DRP_CLK_IN),			// Clock
		.CKE_IN		(1'b1),					// Clock enable
		.A_IN		(dclk_drp.cmd_wr),		// Input
		.RE_OUT		(dclk_drp.cmd_wr_re),	// Rising edge
		.FE_OUT		()						// Falling edge
	);

	prt_dp_lib_edge
	DRP_RD_EDGE_INST
	(
		.CLK_IN		(DRP_CLK_IN),			// Clock
		.CKE_IN		(1'b1),					// Clock enable
		.A_IN		(dclk_drp.cmd_rd),		// Input
		.RE_OUT		(dclk_drp.cmd_rd_re),	// Rising edge
		.FE_OUT		()						// Falling edge
	);

// Ready edge
generate
	for (i = 0; i < P_DRP_PORTS; i++)
	begin : gen_drp_rdy
		prt_dp_lib_edge
		DRP_RDY_EDGE_INST
		(
			.CLK_IN		(DRP_CLK_IN),			// Clock
			.CKE_IN		(1'b1),					// Clock enable
			.A_IN		(DRP_RDY_IN[i]),		// Input
			.RE_OUT		(dclk_drp.rdy_re[i]),	// Rising edge
			.FE_OUT		()						// Falling edge
		);
	end
endgenerate

// Data in
	always_ff @ (posedge DRP_CLK_IN)
	begin
		for (int i = 0; i < P_DRP_PORTS; i++)
		begin
			if (dclk_drp.rdy_re[i])
				dclk_drp.din <= DRP_DAT_IN[(i*P_DRP_DAT)+:P_DRP_DAT];
		end
	end

// Enable
	always_ff @ (posedge DRP_CLK_IN)
	begin
		for (int i = 0; i < P_DRP_PORTS; i++)
		begin
			// Default
			dclk_drp.en[i] <= 0;

			if (dclk_drp.port == i)
			begin
				// Write or read
				if (dclk_drp.cmd_wr_re || dclk_drp.cmd_rd_re)
					dclk_drp.en[i] <= 1;
			end
		end
	end

// Write
	always_ff @ (posedge DRP_CLK_IN)
	begin
		for (int i = 0; i < P_DRP_PORTS; i++)
		begin
			// Default
			dclk_drp.wr[i] <= 0;

			if (dclk_drp.port == i)
			begin
				if (dclk_drp.cmd_wr_re)
					dclk_drp.wr[i] <= 1;
			end
		end
	end

// Feedback ready
	always_ff @ (posedge DRP_CLK_IN)
	begin
		// Clear
		if (dclk_drp.cmd_wr_re || dclk_drp.cmd_rd_re)
			dclk_drp.fb_rdy <= 0;

		// Set
		else if (|dclk_drp.rdy_re)
			dclk_drp.fb_rdy <= 1;
	end

// Feedback
	assign dclk_drp.fb = {dclk_drp.din, dclk_drp.fb_rdy, dclk_drp.cmd_rd, dclk_drp.cmd_wr};

/*
	 PIO
*/

// PIO input
	always_ff @ (posedge SYS_CLK_IN)
	begin
		sclk_pio.din <= PIO_DAT_IN;
	end

// PIO mask
	always_ff @ (posedge SYS_RST_IN, posedge SYS_CLK_IN)
	begin
		// Reset
		if (SYS_RST_IN)
			sclk_pio.msk <= 0;
		
		else
		begin
			// Load
			if (sclk_pio.sel_msk && sclk_lb.wr)
				sclk_pio.msk <= sclk_lb.din[0+:$size(sclk_pio.msk)];
			
			// Reset the mask after the data has been written
			else if (sclk_pio.sel_dout && sclk_lb.wr)
				sclk_pio.msk <= '1;
		end
	end

// PIO output
generate
	for (i = 0; i < $size(sclk_pio.dout); i++)
	begin : gen_pio_out
		always_ff @ (posedge SYS_RST_IN, posedge SYS_CLK_IN)
		begin
			// Reset
			if (SYS_RST_IN)
				sclk_pio.dout[i] <= 0;
			
			else
			begin
				// Set
				if (sclk_pio.sel_dout_set && sclk_lb.wr && sclk_lb.din[i])
					sclk_pio.dout[i] <= 1;

				// Clear
				else if (sclk_pio.sel_dout_clr && sclk_lb.wr && sclk_lb.din[i])
					sclk_pio.dout[i] <= 0;

				// Data out with mask
				else if (sclk_pio.sel_dout && sclk_lb.wr && sclk_pio.msk[i])
					sclk_pio.dout[i] <= sclk_lb.din[i];
			end
		end
	end
endgenerate

// Outputs
    assign LB_IF.dout       = sclk_lb.dout;
    assign LB_IF.vld        = sclk_lb.vld;

	assign DRP_ADR_OUT 		= {P_DRP_PORTS{dclk_drp.adr}};
	assign DRP_DAT_OUT 		= {P_DRP_PORTS{dclk_drp.dout}};
	assign DRP_EN_OUT  		= dclk_drp.en;
	assign DRP_WR_OUT  		= dclk_drp.wr;

	assign PIO_DAT_OUT		= sclk_pio.dout;

endmodule

`default_nettype wire
