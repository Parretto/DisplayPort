/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP PM PIO
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

module prt_dp_pm_pio
#(
	parameter   					P_HW_VER_MAJOR 	= 1,	// Hardware version
	parameter   					P_HW_VER_MINOR 	= 0,	// Hardware version
	parameter 						P_IN_WIDTH 		= 8,
	parameter 						P_OUT_WIDTH 	= 8
)
(
	// Reset and clock
	input wire             			RST_IN,
	input wire             			CLK_IN,

	// Local bus interface
	prt_dp_lb_if.lb_in   			LB_IF,

	// PIO
	input wire 	[P_IN_WIDTH-1:0]	PIO_DAT_IN,
	output wire [P_OUT_WIDTH-1:0]	PIO_DAT_OUT,

	// Interrupt
	output wire 					IRQ_OUT
);

// Localparam

// Control register bit locations
localparam P_CTL_RUN 		= 0;
localparam P_CTL_IE 		= 1;
localparam P_CTL_RE_STR		= 2;
localparam P_CTL_FE_STR		= P_CTL_RE_STR + 8;
localparam P_CTL_WIDTH 		= 32;

// Status register bit locations
localparam P_STA_IRQ 		= 0;
localparam P_STA_WIDTH      = 1;

// Structure
typedef struct {
	logic	[3:0]				adr;
	logic						wr;
	logic						rd;
	logic	[31:0]				din;
	logic	[31:0]				dout;
	logic						vld;
} lb_struct;

typedef struct {
	logic	[31:0]				r;					// Register
	logic						sel;				// Select
} id_struct;

typedef struct {
	logic	[P_CTL_WIDTH-1:0]	r;					// Register
	logic						sel;				// Select
	logic						run;				// Run
	logic						ie;					// Interrupt enable
} ctl_struct;

typedef struct {
	logic	[P_STA_WIDTH-1:0]	r;					// Register
	logic						sel;				// Select
	logic						irq;				// Interrupt
} sta_struct;

typedef struct {
	logic						sel_din;			// Select data in
	logic						sel_evt_re;			// Select event rising edge
	logic						sel_evt_fe;			// Select event falling edge
	logic						sel_dout_set;		// Select data out set
	logic						sel_dout_clr;		// Select data out clear
	logic						sel_dout_tgl;		// Select data out toggle
	logic						sel_dout;			// Select data out
	logic						sel_msk;			// Select mask
	logic	[P_IN_WIDTH-1:0]	din;				// Data in
	logic	[P_IN_WIDTH-1:0]	din_re;				// Data in rising edge
	logic	[P_IN_WIDTH-1:0]	din_fe;				// Data in falling edge
	logic	[P_IN_WIDTH-1:0]	evt_re;				// Event rising edge
	logic	[P_IN_WIDTH-1:0]	evt_fe;				// Event falling edge
	logic	[P_OUT_WIDTH-1:0]	dout;				// Data out
	logic	[P_OUT_WIDTH-1:0]	msk;				// Mask
} pio_struct;

// Signals
lb_struct			clk_lb;			// Local bus
id_struct			clk_id;			// ID register
ctl_struct			clk_ctl;		// Control register
sta_struct			clk_sta;		// Status register
pio_struct			clk_pio;		// PIO

genvar i;

// Logic

/*
	Registers
*/
// Local bus inputs
	always_ff @ (posedge CLK_IN)
	begin
		clk_lb.adr		<= LB_IF.adr;
		clk_lb.rd		<= LB_IF.rd;
		clk_lb.wr		<= LB_IF.wr;
		clk_lb.din		<= LB_IF.din;
	end

// Address selector
// Must be combinatorial
	always_comb
	begin
		// Default
		clk_id.sel 				= 0;
		clk_ctl.sel 			= 0;
		clk_sta.sel 			= 0;
		clk_pio.sel_din 		= 0;
		clk_pio.sel_evt_re		= 0;
		clk_pio.sel_evt_fe		= 0;
		clk_pio.sel_dout_set 	= 0;
		clk_pio.sel_dout_clr 	= 0;
		clk_pio.sel_dout_tgl 	= 0;
		clk_pio.sel_dout 		= 0;
		clk_pio.sel_msk 		= 0;

		case (clk_lb.adr)
			'd0  : clk_id.sel 			= 1;
			'd1  : clk_ctl.sel 			= 1;
			'd2  : clk_sta.sel 			= 1;
			'd3  : clk_pio.sel_din		= 1;
			'd4  : clk_pio.sel_evt_re	= 1;
			'd5  : clk_pio.sel_evt_fe	= 1;
			'd6  : clk_pio.sel_dout_set	= 1;
			'd7  : clk_pio.sel_dout_clr	= 1;
			'd8  : clk_pio.sel_dout_tgl	= 1;
			'd9  : clk_pio.sel_dout		= 1;
			'd10 : clk_pio.sel_msk		= 1;
			default : ;
		endcase
	end

// Register data out
// Must be combinatorial
	always_comb
	begin
		// Default
		clk_lb.dout = 0;

		// ID
		if (clk_id.sel)
			clk_lb.dout[$size(clk_id.r)-1:0] = clk_id.r;

		// Control register
		else if (clk_ctl.sel)
			clk_lb.dout[$size(clk_ctl.r)-1:0] = clk_ctl.r;

		// Status register
		else if (clk_sta.sel)
			clk_lb.dout[$size(clk_sta.r)-1:0] = clk_sta.r;

		// PIO data in
		else if (clk_pio.sel_din)
			clk_lb.dout[$size(clk_pio.din)-1:0] = clk_pio.din;

		// PIO event rising edge
		else if (clk_pio.sel_evt_re)
			clk_lb.dout[$size(clk_pio.evt_re)-1:0] = clk_pio.evt_re;

		// PIO event falling edge
		else if (clk_pio.sel_evt_fe)
			clk_lb.dout[$size(clk_pio.evt_fe)-1:0] = clk_pio.evt_fe;

		// PIO data out
		else if (clk_pio.sel_dout_set || clk_pio.sel_dout_clr)
			clk_lb.dout[$size(clk_pio.dout)-1:0] = clk_pio.dout;

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

// ID
	assign clk_id.r[16+:16] = 16'h1234; // ID
	assign clk_id.r[8+:8] = P_HW_VER_MAJOR;
	assign clk_id.r[0+:8] = P_HW_VER_MINOR;

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
	assign clk_ctl.run = clk_ctl.r[P_CTL_RUN];	// Run
	assign clk_ctl.ie = clk_ctl.r[P_CTL_IE];	// Interrupt enable

// Status register
	assign clk_sta.r[P_STA_IRQ] = clk_sta.irq;

// Status interrupt
	always_ff @ (posedge CLK_IN)
	begin
		// Run
		if (clk_ctl.run)
		begin
			// Clear when the status register bit is written
			if (clk_sta.sel && clk_lb.wr && clk_lb.din[P_STA_IRQ])
				clk_sta.irq <= 0;

			// Set
			// when any event bit is asserted and the interrupt is enabled
			else if (((|clk_pio.evt_re) || (|clk_pio.evt_fe)) && clk_ctl.ie)
				clk_sta.irq <= 1;
		end

		else
			clk_sta.irq <= 0;
	end

// PIO input
	always_ff @ (posedge CLK_IN)
	begin
		// Run
		if (clk_ctl.run)
			clk_pio.din <= PIO_DAT_IN;

		// Idle
		else
			clk_pio.din <= 0;
	end

// PIO in edge detector
generate
    for (i = 0; i < P_IN_WIDTH; i++)
    begin
        prt_dp_lib_edge
        DIN_EDGE_INST
        (
            .CLK_IN     (CLK_IN),              // Clock
            .CKE_IN     (1'b1),                // Clock enable
            .A_IN       (clk_pio.din[i]), 	   // Input
            .RE_OUT     (clk_pio.din_re[i]),   // Rising edge
            .FE_OUT     (clk_pio.din_fe[i])    // Falling edge
        );
    end
endgenerate

// Event rising edge
	always_ff @ (posedge CLK_IN)
	begin
		for (int i = 0; i < P_IN_WIDTH; i++)
		begin
			// Run
			if (clk_ctl.run)
			begin
				// Set on rising edge
				if (clk_pio.din_re[i] && clk_ctl.r[P_CTL_RE_STR + i])
					clk_pio.evt_re[i] <= 1;

				// Clear
				// when this register is read
				else if (clk_pio.sel_evt_re && clk_lb.rd)
					clk_pio.evt_re[i] <= 0;
			end

			else
				clk_pio.evt_re[i] <= 0;
		end
	end

// Event falling edge
	always_ff @ (posedge CLK_IN)
	begin
		for (int i = 0; i < P_IN_WIDTH; i++)
		begin
			// Run
			if (clk_ctl.run)
			begin
				// Set on falling edge
				if (clk_pio.din_fe[i] && clk_ctl.r[P_CTL_FE_STR + i])
					clk_pio.evt_fe[i] <= 1;

				// Clear
				// when this register is read
				else if (clk_pio.sel_evt_fe && clk_lb.rd)
					clk_pio.evt_fe[i] <= 0;
			end

			else
				clk_pio.evt_fe[i] <= 0;
		end
	end

// PIO mask
	always_ff @ (posedge CLK_IN)
	begin
		// Run
		if (clk_ctl.run)
		begin
			// Load
			if (clk_pio.sel_msk && clk_lb.wr)
				clk_pio.msk <= clk_lb.din[0+:$size(clk_pio.msk)];
			
			// Reset the mask after teh data has been written
			else if (clk_pio.sel_dout && clk_lb.wr)
				clk_pio.msk <= '1;
		end

		// Idle
		else
			clk_pio.msk <= 0;
	end

// PIO output
generate
	for (i=0; i<$size(clk_pio.dout); i++)
	begin : gen_pio_out
		always_ff @ (posedge CLK_IN)
		begin
			// Run
			if (clk_ctl.run)
			begin
				// Set
				if (clk_pio.sel_dout_set && clk_lb.wr && clk_lb.din[i])
					clk_pio.dout[i] <= 1;

				// Clear
				else if (clk_pio.sel_dout_clr && clk_lb.wr && clk_lb.din[i])
					clk_pio.dout[i] <= 0;

				// Toggle
				else if (clk_pio.sel_dout_tgl && clk_lb.wr && clk_lb.din[i])
					clk_pio.dout[i] <= ~clk_pio.dout[i];

				// Data out with mask
				else if (clk_pio.sel_dout && clk_lb.wr && clk_pio.msk[i])
					clk_pio.dout[i] <= clk_lb.din[i];
			end

			// Idle
			else
				clk_pio.dout[i] <= 0;
		end
	end
endgenerate

// Outputs
	assign LB_IF.dout 	= clk_lb.dout;
	assign LB_IF.vld	= clk_lb.vld;
	assign PIO_DAT_OUT	= clk_pio.dout;
	assign IRQ_OUT 		= clk_sta.irq;
endmodule

`default_nettype wire
