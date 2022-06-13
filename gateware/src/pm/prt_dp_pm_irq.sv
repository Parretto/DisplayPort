/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP PM Interrupt Controller
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

module prt_dp_pm_irq
(
	// Reset and clock
	input wire             	RST_IN,
	input wire             	CLK_IN,

	// Local bus interface
	prt_dp_lb_if.lb_in 		LB_IF,

	// Interrupt
	input wire [7:0]		IRQ_REQ_IN
);

// Parameters
localparam P_IRQ = 8;

// Control register bit locations
localparam P_CTL_RUN 		= 0;
localparam P_CTL_IE_0 		= 1;
localparam P_CTL_IE_1 		= 2;
localparam P_CTL_IE_2 		= 3;
localparam P_CTL_IE_3 		= 4;
localparam P_CTL_IE_4 		= 5;
localparam P_CTL_IE_5 		= 6;
localparam P_CTL_IE_6 		= 7;
localparam P_CTL_IE_7 		= 8;
localparam P_CTL_MODE_0 	= 9;
localparam P_CTL_MODE_1 	= 10;
localparam P_CTL_MODE_2 	= 11;
localparam P_CTL_MODE_3 	= 12;
localparam P_CTL_MODE_4 	= 13;
localparam P_CTL_MODE_5 	= 14;
localparam P_CTL_MODE_6 	= 15;
localparam P_CTL_MODE_7 	= 16;
localparam P_CTL_WIDTH 		= 17;

// Status register bit locations
localparam P_STA_IRQ_ALL 	= 0;
localparam P_STA_IRQ_0 		= 1;
localparam P_STA_IRQ_1 		= 2;
localparam P_STA_IRQ_2 		= 3;
localparam P_STA_IRQ_3 		= 4;
localparam P_STA_IRQ_4 		= 5;
localparam P_STA_IRQ_5 		= 6;
localparam P_STA_IRQ_6 		= 7;
localparam P_STA_IRQ_7 		= 8;
localparam P_STA_WIDTH 		= 9;

// Structure
typedef struct {
	logic	[1:0]				adr;
	logic						wr;
	logic						rd;
	logic	[31:0]				din;
	logic	[31:0]				dout;
	logic						vld;
} lb_struct;

typedef struct {
	logic	[P_CTL_WIDTH-1:0]		r;				// Register
	logic						sel_set;			// Select set
	logic						sel_clr;			// Select clear
	logic						run;				// Run
	logic	[P_IRQ-1:0]			ie;				// Interrupt enable
	logic	[P_IRQ-1:0]			mode;			// Interrupt mode; 0-level / 1-edge

} ctl_struct;

typedef struct {
	logic	[P_STA_WIDTH-1:0]		r;				// Register
	logic						sel;				// Select
} sta_struct;

typedef struct {
	logic	[P_IRQ-1:0]			req_re;			// Request falling edge
	logic	[P_IRQ-1:0]			evt;				// Event
	logic						all;				// All
} irq_struct;

// Signals
lb_struct		clk_lb;		// Local bus
ctl_struct		clk_ctl;		// Control register
sta_struct		clk_sta;		// Status register
irq_struct		clk_irq;		// Interrupt

genvar i;

// Logic

/*
	Registers
*/
// Local bus inputs
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		if (RST_IN)
		begin
			clk_lb.adr	<= 0;
			clk_lb.wr		<= 0;
			clk_lb.rd		<= 0;
			clk_lb.din	<= 0;
		end

		else
		begin
			clk_lb.adr	<= LB_IF.adr;
			clk_lb.rd		<= LB_IF.rd;
			clk_lb.wr		<= LB_IF.wr;
			clk_lb.din	<= LB_IF.din;
		end
	end

// Address selector
// Must be combinatorial
	always_comb
	begin
		// Default
		clk_ctl.sel_set 	= 0;
		clk_ctl.sel_clr 	= 0;
		clk_sta.sel 		= 0;

		case (clk_lb.adr)
			'd0 : clk_ctl.sel_set	= 1;
			'd1 : clk_ctl.sel_clr	= 1;
			'd2 : clk_sta.sel 		= 1;
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
		if (clk_ctl.sel_set || clk_ctl.sel_clr)
			clk_lb.dout[$size(clk_ctl.r)-1:0] = clk_ctl.r;

		// Status
		else if (clk_sta.sel)
			clk_lb.dout[$size(clk_sta.r)-1:0] = clk_sta.r;

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
			// Write set
			if (clk_lb.wr)
			begin
				// Set
				if (clk_ctl.sel_set)
					clk_ctl.r <= (clk_ctl.r | clk_lb.din[$size(clk_ctl.r)-1:0]);

				// Clear
				else if (clk_ctl.sel_clr)
					clk_ctl.r <= (clk_ctl.r & (~clk_lb.din[$size(clk_ctl.r)-1:0]));
			end
		end
	end

// Control register bit locations
	assign clk_ctl.run   = clk_ctl.r[P_CTL_RUN];			// Run
	assign clk_ctl.ie    = clk_ctl.r[P_CTL_IE_0+:P_IRQ];	// Interrupt enable
	assign clk_ctl.mode  = clk_ctl.r[P_CTL_MODE_0+:P_IRQ];	// Interrupt mode

// Status register
	assign clk_sta.r[P_STA_IRQ_ALL]		= clk_irq.all;
	assign clk_sta.r[P_STA_IRQ_0+:P_IRQ] 	= clk_irq.evt;

// IRQ request edge detector
generate
    for (i = 0; i < P_IRQ; i++)
    begin
        prt_dp_lib_edge
        IRQ_REQ_EDGE_INST
        (
            .CLK_IN     (CLK_IN),             	// Clock
            .CKE_IN     (1'b1),                	// Clock enable
            .A_IN       (IRQ_REQ_IN[i]), 	  	// Input
            .RE_OUT     (clk_irq.req_re[i]),		// Rising edge
            .FE_OUT     ()    				// Falling edge
        );
    end
endgenerate

// Interrupt Event
	always_ff @ (posedge CLK_IN)
	begin
		for (int i = 0; i < P_IRQ; i++)
		begin
			// Run
			if (clk_ctl.run)
			begin
				// Clear
				// when the bit in status register is written
				if (clk_sta.sel && clk_lb.wr && clk_lb.din[i+1])
					clk_irq.evt[i] <= 0;

				// Set
				// When the interrupt request input is high and the interrupt is currently not being acknowledged
				// The interrupt request is level based
				else if (clk_ctl.ie[i] && ( (!clk_ctl.mode[i] && IRQ_REQ_IN[i]) || (clk_ctl.mode[i] && clk_irq.req_re[i]) ) )
					clk_irq.evt[i] <= 1;
			end

			// Idle
			else
				clk_irq.evt[i] <= 0;
		end
	end

// Interrupt all
	always_comb
	begin
		// Assert interrupt when any masked interrupt is active
		if (|clk_irq.evt)
			clk_irq.all = 1;
		else
			clk_irq.all = 0;
	end

// Outputs
	assign LB_IF.dout 	= clk_lb.dout;
	assign LB_IF.vld	= clk_lb.vld;

endmodule

`default_nettype wire
