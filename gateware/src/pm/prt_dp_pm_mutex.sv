/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP PM Mutex
    (c) 2021 - 2024 by Parretto B.V.

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

module prt_dp_pm_mutex
(
	// Reset and clock
	input wire             	RST_IN,
	input wire             	CLK_IN,

	// Local bus interface
	prt_dp_lb_if.lb_in  	LB_IF
);

// Control register bit locations
localparam P_CTL_RUN 		= 0;
localparam P_CTL_WIDTH 		= 1;

localparam P_MUTEX_WIDTH 	= 4;

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
	logic	[P_CTL_WIDTH-1:0]		r;		// Register
	logic						sel;		// Select
	logic						run;		// Run
} ctl_struct;

typedef struct {
	logic	[P_MUTEX_WIDTH-1:0]		r;		// Register
	logic						sel_set;	// Select set
	logic						sel_clr;	// Select clear
} mutex_struct;

// Signals
lb_struct			clk_lb;		// Local bus
ctl_struct		clk_ctl;		// Control register
mutex_struct		clk_mutex;	// Mutex

genvar i;

// Logic

/*
	Registers
*/
// Local bus inputs
	always_ff @ (posedge CLK_IN)
	begin
		clk_lb.adr	<= LB_IF.adr;
		clk_lb.rd	<= LB_IF.rd;
		clk_lb.wr	<= LB_IF.wr;
		clk_lb.din	<= LB_IF.din;
	end

// Address selector
// Must be combinatorial
	always_comb
	begin
		// Default
		clk_ctl.sel 		= 0;
		clk_mutex.sel_set 	= 0;
		clk_mutex.sel_clr 	= 0;

		case (clk_lb.adr)
			'd0 : clk_ctl.sel		= 1;
			'd1 : clk_mutex.sel_set	= 1;
			'd2 : clk_mutex.sel_clr	= 1;
			default : ;
		endcase
	end

// Register data out
// Must be combinatorial
	assign clk_lb.dout = clk_mutex.r;

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
			if (clk_lb.wr & clk_ctl.sel)
				clk_ctl.r <= clk_lb.din[$size(clk_ctl.r)-1:0];
		end
	end

// Control register bit locations
	assign clk_ctl.run = clk_ctl.r[P_CTL_RUN];		// Run

// Mutex
	always_ff @ (posedge CLK_IN)
	begin
		for (int i = 0; i < P_MUTEX_WIDTH; i++)
		begin
			// Run
			if (clk_ctl.run)
			begin
				// Write
				if (clk_lb.wr)
				begin
					// Clear
					if (clk_mutex.sel_clr && clk_lb.din[i])
						clk_mutex.r[i] <= 0;
					
					// Set
					// The bit can only be set when no other bits are set
					else if (clk_mutex.sel_set && clk_lb.din[i] && !(|clk_mutex.r))
						clk_mutex.r[i] <= 1;
				end
			end

			// Idle
			else
				clk_mutex.r[i] <= 0;
		end
	end

// Outputs
	assign LB_IF.dout 		= clk_lb.dout;
	assign LB_IF.vld		= clk_lb.vld;

endmodule

`default_nettype wire
