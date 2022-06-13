/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP PM Message
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
module prt_dp_pm_msg
(
	// Reset and clock
	input wire 			RST_IN,		// Reset
	input wire 			CLK_IN,		// Clock

	// Local bus interface
	prt_dp_lb_if.lb_in		LB_IF,

	// Message
	prt_dp_msg_if.src		MSG_SRC_IF, 	// Source
	prt_dp_msg_if.snk		MSG_SNK_IF,	// Sink

	// Interrupt
	output wire   			IRQ_OUT
);

// Localparam
localparam P_RX_FIFO_WRDS	= 32;
localparam P_RX_FIFO_ADR		= $clog2(P_RX_FIFO_WRDS);
localparam P_RX_FIFO_DAT		= 16 + 2;	// Data + start of message + end of message

// Control register bit locations
localparam P_CTL_RUN 		= 0;
localparam P_CTL_IE 		= 1;
localparam P_CTL_WIDTH		= 2;

// Status register bit locations
localparam P_STA_IRQ		= 0;	// Interrupt
localparam P_STA_TO			= 1;	// Time out
localparam P_STA_RX_FIFO_EP 	= 2;
localparam P_STA_RX_FIFO_FL 	= 3;
localparam P_STA_RX_FIFO_WRDS = 4;	// RX FIFO words (6 bits)
localparam P_STA_WIDTH		= 10;

// Structure
typedef struct {
	logic	[2:0]				adr;
	logic						wr;
	logic						rd;
	logic	[31:0]				din;
	logic	[31:0]				dout;
	logic						vld;
} lb_struct;

typedef struct {
	logic	[P_CTL_WIDTH-1:0]		r;			// Register
	logic						sel;			// Select
	logic						run;			// Run
	logic						ie;			// Interrupt enable
} ctl_struct;

typedef struct {
	logic	[P_STA_WIDTH-1:0]		r;			// Register
	logic						sel;			// Select
	logic						irq;			// Interrupt
	logic 	[7:0]				to_cnt;		// Time out counter
	logic 						to_cnt_end;	// Time out counter end
	logic 						to_cnt_end_re;	// Time out counter rising edge
	logic 						to_en;		// Time out enable
	logic 						to;			// Time out
} sta_struct;

typedef struct {
	logic						sel;
	logic						som;
	logic						eom;
	logic	[15:0]				dout;
	logic						vld;
} tx_dat_struct;

typedef struct {
	logic						sel;
	logic						clr;
	logic						wr_en;
	logic						wr;
	logic	[P_RX_FIFO_DAT-1:0]		din;
	logic						rd;
	logic	[P_RX_FIFO_DAT-1:0]		dout;
	logic						de;
	logic	[P_RX_FIFO_ADR:0]		wrds;
	logic						ep;
	logic						fl;
} rx_fifo_struct;

// Signals
lb_struct			clk_lb;		// Local bus
ctl_struct		clk_ctl;		// Control register
sta_struct		clk_sta;		// Status register
tx_dat_struct		clk_tx_dat;	// TX data register
rx_fifo_struct		clk_rx_fifo;	// RX fifo

// Logic

/*
	Registers
*/
// Local bus inputs
	always_ff @ (posedge CLK_IN)
	begin
		clk_lb.adr	<= LB_IF.adr;
		clk_lb.rd		<= LB_IF.rd;
		clk_lb.wr		<= LB_IF.wr;
		clk_lb.din	<= LB_IF.din;
	end

// Address selector
// Must be combinatorial
	always_comb
	begin
		// Default
		clk_ctl.sel 	= 0;
		clk_sta.sel 	= 0;
		clk_tx_dat.sel  = 0;
		clk_rx_fifo.sel = 0;

		case (clk_lb.adr)
			'd0 : clk_ctl.sel 		= 1;
			'd1 : clk_sta.sel 		= 1;
			'd2 : clk_tx_dat.sel 	= 1;
			'd3 : clk_rx_fifo.sel 	= 1;
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
			clk_lb.dout[$size(clk_ctl.r)-1:0] = clk_ctl.r;

		// Status
		else if (clk_sta.sel)
			clk_lb.dout[$size(clk_sta.r)-1:0] = clk_sta.r;

		// RX fifo
		else if (clk_rx_fifo.sel && clk_rx_fifo.de)
			clk_lb.dout[$size(clk_rx_fifo.dout)-1:0] = clk_rx_fifo.dout;

		// Default
		else
			clk_lb.dout = 'hdeadcafe;
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
		if (RST_IN)
			clk_ctl.r <= 0;

		else
		begin
			// Write
			if (clk_ctl.sel && clk_lb.wr)
				clk_ctl.r <= clk_lb.din[$size(clk_ctl.r)-1:0];
		end
	end

// Control register bit locations
	assign clk_ctl.run 			= clk_ctl.r[P_CTL_RUN];							// Run
	assign clk_ctl.ie 			= clk_ctl.r[P_CTL_IE];							// Interrupt enable

// Status register
	assign clk_sta.r[P_STA_IRQ]										= clk_sta.irq;			// Interrupt
	assign clk_sta.r[P_STA_TO]										= clk_sta.to;			// Time out
	assign clk_sta.r[P_STA_RX_FIFO_EP] 								= clk_rx_fifo.ep;		// FIFO empty
	assign clk_sta.r[P_STA_RX_FIFO_FL] 								= clk_rx_fifo.fl;		// FIFO full
	assign clk_sta.r[P_STA_RX_FIFO_WRDS+:$size(clk_rx_fifo.wrds)]	= clk_rx_fifo.wrds;		// FIFO words

// Time out
// The time out flag is set when the message doesn't return.
// The counter is started per bit
	always_ff @ (posedge CLK_IN)
	begin
		// Run
		if (clk_ctl.run)
		begin
			// Set
			if (clk_tx_dat.vld)
				clk_sta.to_cnt <= '1;

			// Decrement
			else if (!clk_sta.to_cnt_end)
				clk_sta.to_cnt <= clk_sta.to_cnt - 'd1;
		end

		// Idle
		else 
			clk_sta.to_cnt <= 0;
	end

// Time out counter end
	always_comb
	begin
		if (clk_sta.to_cnt == 0)
			clk_sta.to_cnt_end = 1;
		else
			clk_sta.to_cnt_end = 0;
	end

// Time out enable
	always_ff @ (posedge CLK_IN)
	begin
		// Run
		if (clk_ctl.run)
		begin
			// Set
			if (clk_tx_dat.vld)
				clk_sta.to_en <= 1;

			// Clear
			else if (MSG_SNK_IF.vld)
				clk_sta.to_en <= 0;
		end

		// Idle
		else 
			clk_sta.to_en <= 0;
	end

// Time out rising edge
	prt_dp_lib_edge
	STA_TO_EDGE_INST
	(
		.CLK_IN		(CLK_IN),					// Clock
		.CKE_IN		(1'b1),						// Clock enable
		.A_IN		(clk_sta.to_cnt_end),		// Input
		.RE_OUT		(clk_sta.to_cnt_end_re),	// Rising edge
		.FE_OUT		()							// Falling edge
	);

// Time out
	always_ff @ (posedge CLK_IN)
	begin
		// Run
		if (clk_ctl.run)
		begin
			// Set
			if (clk_sta.to_en && clk_sta.to_cnt_end_re) 
				clk_sta.to <= 1;
		end

		// Idle
		else 
			clk_sta.to <= 0;
	end

// Interrupt
// Not used
	always_comb
	begin
		// Default
		clk_sta.irq = 0;
	end

/*
	TX Data
	The TX output is much faster than the PM can supply the data,
	so no FIFO is needed on the TX output.
*/

// Valid
	always_comb
	begin
		if (clk_tx_dat.sel && clk_lb.wr)
			clk_tx_dat.vld = 1;
		else
			clk_tx_dat.vld = 0;
	end

// Data
	assign clk_tx_dat.dout = (clk_tx_dat.vld) ? clk_lb.din[0+:$size(clk_tx_dat.dout)] : 'h0;

// Start of message
	assign clk_tx_dat.som	= (clk_tx_dat.vld) ? clk_lb.din[17] : 0;

// End of message
	assign clk_tx_dat.eom   = (clk_tx_dat.vld) ? clk_lb.din[16] : 0;


/*
	RX FIFO
*/
	prt_dp_lib_fifo_sc
	#(
		.P_MODE         ("single"),			// "single" or "burst"
		.P_RAM_STYLE	("distributed"),	// "distributed", "block" or "ultra"
		.P_ADR_WIDTH 	(P_RX_FIFO_ADR),
		.P_DAT_WIDTH 	(P_RX_FIFO_DAT)
	)
	FIFO_INST
	(
		// Clocks and reset
		.RST_IN		(RST_IN),				// Reset
		.CLK_IN		(CLK_IN),				// Clock
		.CLR_IN		(~clk_ctl.run),			// Clear

		// Write
		.WR_IN		(clk_rx_fifo.wr),		// Write in
		.DAT_IN		(clk_rx_fifo.din),		// Write data

		// Read
		.RD_EN_IN	(1'b1),					// Read enable in
		.RD_IN		(clk_rx_fifo.rd),		// Read in
		.DAT_OUT	(clk_rx_fifo.dout),		// Data out
		.DE_OUT		(clk_rx_fifo.de),		// Data enable

		// Status
		.WRDS_OUT	(clk_rx_fifo.wrds),		// Used words
		.EP_OUT		(clk_rx_fifo.ep),		// Empty
		.FL_OUT		(clk_rx_fifo.fl)		// Full
	);

// Write enable
	always_ff @ (posedge CLK_IN)
	begin
		// Run
		if (clk_ctl.run)
		begin
			// Wait for start of message
			// We only want to store the get messages.
			// The put messages can be discarded.
			if (MSG_SNK_IF.vld && MSG_SNK_IF.som && !MSG_SNK_IF.dat[15])
				clk_rx_fifo.wr_en <= 1;

			// Clear
			else if (MSG_SNK_IF.vld && MSG_SNK_IF.eom)
				clk_rx_fifo.wr_en <= 0;
		end

		else
			clk_rx_fifo.wr_en <= 0;
	end

// FIFO write
// Only store the message body
	assign clk_rx_fifo.wr = clk_rx_fifo.wr_en && MSG_SNK_IF.vld && !MSG_SNK_IF.som;

// Data in
	assign clk_rx_fifo.din = {MSG_SNK_IF.som, MSG_SNK_IF.eom, MSG_SNK_IF.dat};

// Read
	always_comb
	begin
		if (clk_rx_fifo.sel && clk_lb.rd && clk_rx_fifo.de)
			clk_rx_fifo.rd = 1;
		else
			clk_rx_fifo.rd = 0;
	end

// Outputs
	assign LB_IF.dout 		= clk_lb.dout;
	assign LB_IF.vld		= clk_lb.vld;

	assign MSG_SRC_IF.som	= clk_tx_dat.som;
	assign MSG_SRC_IF.eom   	= clk_tx_dat.eom;
	assign MSG_SRC_IF.dat   	= clk_tx_dat.dout;
	assign MSG_SRC_IF.vld 	= clk_tx_dat.vld;

	assign IRQ_OUT			= clk_sta.irq;


/*
	Assertions
*/

// synthesis translate_off

// RX FIFO full
initial
begin
	forever
	begin
		@(posedge CLK_IN);
	    assert (!clk_rx_fifo.fl) else
			$error ("RX FIFO is full\n");
	end
end
// synthesis translate_on

endmodule

`default_nettype wire
