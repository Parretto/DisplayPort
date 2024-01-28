/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP PM Timer
    (c) 2021 - 2024 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
	v1.1 - Increase width alarm counter to 32 bits
	v1.2 - Added Alarm enable

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

module prt_dp_pm_tmr
#(
	parameter 				P_SIM 	= 0,
	parameter               P_BEAT 	= 'd125     // Beat value
)
(
	// Reset and clock
	input wire             	RST_IN,
	input wire             	CLK_IN,

	// Local bus interface
	prt_dp_lb_if.lb_in 		LB_IF,

	// Beat
	output wire  			BEAT_OUT,	// 1 MHz output

	// Interrupt
	output wire   			IRQ_OUT
);

// Localparam
localparam P_TMR_HB_BIT		= (P_SIM) ? 10 : 18;	// Heartbeat timer
localparam P_ALRMS 			= 2;					// Number of alarms

// Control register bit locations
localparam P_CTL_RUN 		= 0;
localparam P_CTL_IE 		= 1;
localparam P_CTL_ALRM0		= 2;
localparam P_CTL_ALRM1		= 3;
localparam P_CTL_WIDTH 		= 4;

// Status register bit locations
localparam P_STA_IRQ		= 0;
localparam P_STA_ALRM0		= 1;
localparam P_STA_ALRM1		= 2;
localparam P_STA_HB			= 3;
localparam P_STA_WIDTH 		= 4;

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
	logic	[P_CTL_WIDTH-1:0]	r;					// Register
	logic						sel;				// Select
	logic						run;				// Run
	logic						ie;					// Interrupt enable
	logic [P_ALRMS-1:0]			alrm;				// Alarm
} ctl_struct;

typedef struct {
	logic	[P_STA_WIDTH-1:0]	r;					// Register
	logic						sel;				// Select
	logic						irq;				// Interrupt
	logic						hb;					// Heart beat
	logic [P_ALRMS-1:0]			alrm;				// Alarm
} sta_struct;

typedef struct {
	logic						sel;				// Select
	logic	[9:0]				beat_cnt;			// Beat counter
	logic						beat_cnt_end;		// Beat counter end
	logic						beat_cnt_end_re;	// Beat counter end rising edge
	logic						beat;				// Beat 
	logic						beat_re;			// Beat 
	logic 	[31:0]				ts;					// Time stamp
	logic						hb;					// Heart beat
} tmr_struct;

typedef struct {
	logic						sel;				// Select
	logic	[31:0]				cnt;
	logic						cnt_end;
	logic						cnt_end_re;
} alrm_struct;

// Signals
lb_struct			clk_lb;				// Local bus
ctl_struct			clk_ctl;			// Control register
sta_struct			clk_sta;			// Status register
tmr_struct			clk_tmr;			// Timer
alrm_struct			clk_alrm[P_ALRMS];	// Alarm

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
		clk_sta.sel 		= 0;
		clk_tmr.sel	 		= 0;
		clk_alrm[0].sel 	= 0;
		clk_alrm[1].sel 	= 0;

		case (clk_lb.adr)
			'd0 : clk_ctl.sel 		= 1;
			'd1 : clk_sta.sel 		= 1;
			'd2 : clk_tmr.sel 		= 1;
			'd3 : clk_alrm[0].sel	= 1;
			'd4 : clk_alrm[1].sel	= 1;
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

		// Timer (system counter)
		else if (clk_tmr.sel)
			clk_lb.dout[$size(clk_tmr.ts)-1:0] = clk_tmr.ts;

		// Alarm 0
		else if (clk_alrm[0].sel)
			clk_lb.dout[$size(clk_alrm[0].cnt)-1:0] = clk_alrm[0].cnt;

		// Alarm 1
		else if (clk_alrm[1].sel)
			clk_lb.dout[$size(clk_alrm[1].cnt)-1:0] = clk_alrm[1].cnt;

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

			// The alarm flag 0 is disabled when the alarm counter expires
			else if (clk_alrm[0].cnt_end_re)
				clk_ctl.r[P_CTL_ALRM0] <= 0;

			// The alarm flag 1 is disabled when the alarm counter expires
			else if (clk_alrm[1].cnt_end_re)
				clk_ctl.r[P_CTL_ALRM1] <= 0;
		end
	end

// Control register bit locations
	assign clk_ctl.run 			= clk_ctl.r[P_CTL_RUN];							// Run
	assign clk_ctl.ie 			= clk_ctl.r[P_CTL_IE];							// Interrupt enable
	assign clk_ctl.alrm[0] 		= clk_ctl.r[P_CTL_ALRM0];						// Alarm 0
	assign clk_ctl.alrm[1] 		= clk_ctl.r[P_CTL_ALRM1];						// Alarm 1

// Status register
	assign clk_sta.r[P_STA_IRQ] 	= clk_sta.irq;
	assign clk_sta.r[P_STA_HB] 		= clk_sta.hb;
	assign clk_sta.r[P_STA_ALRM0] 	= clk_sta.alrm[0];
	assign clk_sta.r[P_STA_ALRM1] 	= clk_sta.alrm[1];

// Interrupt
	always_ff @ (posedge CLK_IN)
	begin
		// Enable
		if (clk_ctl.ie)
			clk_sta.irq <= clk_sta.alrm[0] || clk_sta.alrm[1] || clk_sta.hb;
		
		else
			clk_sta.irq <= 0;
	end

// Heart beat 
	always_ff @ (posedge CLK_IN)
	begin
		// Enable
		if (clk_ctl.run)
		begin
			// Clear
			if (clk_sta.sel && clk_lb.wr && clk_lb.din[P_STA_HB])
				clk_sta.hb <= 0;

			// Set
			else if (clk_tmr.hb)
				clk_sta.hb <= 1;
		end

		// Idle
		else
			clk_sta.hb <= 0;
	end

// Status Alarm 
generate
	for (i = 0 ; i < P_ALRMS; i++)
	begin : gen_sta_alrm
		always_ff @ (posedge CLK_IN)
		begin
			// Enable
			if (clk_ctl.run)
			begin
				// Clear
				// When setting the alarm bit in the status register.
				if (clk_sta.sel && clk_lb.wr && clk_lb.din[P_STA_ALRM0+i])
					clk_sta.alrm[i] <= 0;

				// Set
				// When the alarm timer expires and the control bit is set.
				else if (clk_alrm[i].cnt_end_re && clk_ctl.alrm[i])
					clk_sta.alrm[i] <= 1;
			end

			// Idle
			else
				clk_sta.alrm[i] <= 0;
		end
	end
endgenerate

// Beat counter
// This counter expires every full period of the 1 MHz clock cycle.
// The beat value is the value to divide the system clock in 1 MHz. 
	always_ff @ (posedge CLK_IN)
	begin
		// Run
		if (clk_ctl.run)
		begin
			// Load
			if (clk_tmr.beat_cnt_end)
				clk_tmr.beat_cnt <= P_BEAT - 'd1;

			// Decrement
			else
				clk_tmr.beat_cnt <= clk_tmr.beat_cnt - 'd1;
		end

		// Idle
		else
			clk_tmr.beat_cnt <= 0;
	end

// Beat counter end
	always_comb
	begin
		if (clk_tmr.beat_cnt == 0)
			clk_tmr.beat_cnt_end = 1;
		else
			clk_tmr.beat_cnt_end = 0;
	end

// Beat counter end rising edge
	prt_dp_lib_edge
	BEAT_CNT_END_EDGE_INST
	(
		.CLK_IN		(CLK_IN),					// Clock
		.CKE_IN		(1'b1),						// Clock enable
		.A_IN		(clk_tmr.beat_cnt_end),		// Input
		.RE_OUT		(clk_tmr.beat_cnt_end_re),	// Rising edge
		.FE_OUT		()							// Falling edge
	);

// Beat 
	always_ff @ (posedge CLK_IN)
	begin
		// Enable
		if (clk_ctl.run)
		begin
			// Set
			// When the timer is loaded
			if (clk_tmr.beat_cnt_end_re)
				clk_tmr.beat <= 1;
			
			// Clear
			// When the counter is half way
			else if (clk_tmr.beat_cnt == (P_BEAT/2))
				clk_tmr.beat <= 0; 
		end

		// Idle
		else
			clk_tmr.beat <= 0;
	end

// Beat 2 MHz edge
	prt_dp_lib_edge
	BEAT_EDGE_INST
	(
		.CLK_IN		(CLK_IN),				// Clock
		.CKE_IN		(1'b1),					// Clock enable
		.A_IN		(clk_tmr.beat),			// Input
		.RE_OUT		(clk_tmr.beat_re),		// Rising edge
		.FE_OUT		()						// Falling edge
	);

// Time stamp
// This counter runs at 1 MHz (1us) beat.
// It can be used for time stamping debug messages.
	always_ff @ (posedge CLK_IN)
	begin
		// Enable
		if (clk_ctl.run)
		begin
			// Increment
			if (clk_tmr.beat_re)
			begin
				// Overflow
				if (&clk_tmr.ts)
					clk_tmr.ts <= 0;

				// Increment
				else
					clk_tmr.ts <= clk_tmr.ts + 'd1;
			end
		end

		// Idle
		else
			clk_tmr.ts <= 0;
	end

// Heart beat
// The timer interrupt is set every ~ 500 ms
// This can used as a heart beat indicator
	prt_dp_lib_edge
	HEART_BEAT_EDGE_INST
	(
		.CLK_IN		(CLK_IN),					// Clock
		.CKE_IN		(1'b1),						// Clock enable
		.A_IN		(clk_tmr.ts[P_TMR_HB_BIT]),	// Input
		.RE_OUT		(clk_tmr.hb),				// Rising edge
		.FE_OUT		()							// Falling edge
	);

/*
	Alarm
*/
generate
	for (i = 0 ; i < P_ALRMS; i++)
	begin : gen_alrm
	// Alarm Counter
	// This counter runs at 1 MHz (1us) beat.
		always_ff @ (posedge CLK_IN)
		begin
			// Enable
			if (clk_ctl.run)
			begin
				// Load
				if (clk_alrm[i].sel && clk_lb.wr)
					clk_alrm[i].cnt <= clk_lb.din[0+:$size(clk_alrm[i].cnt)];

				// Increment
				else if (!clk_alrm[i].cnt_end && clk_tmr.beat_re)
					clk_alrm[i].cnt <= clk_alrm[i].cnt - 'd1;
			end

			// Idle
			else
				clk_alrm[i].cnt <= 0;
		end

	// Counter end
	 	always_comb
		begin
			if (clk_alrm[i].cnt == 0)
				clk_alrm[i].cnt_end = 1;
			else
				clk_alrm[i].cnt_end = 0;
		end

	// Counter end edge
		prt_dp_lib_edge
		ALRM_CNT_END_EDGE_INST
		(
			.CLK_IN		(CLK_IN),					// Clock
			.CKE_IN		(1'b1),						// Clock enable
			.A_IN		(clk_alrm[i].cnt_end),		// Input
			.RE_OUT		(clk_alrm[i].cnt_end_re),	// Rising edge
			.FE_OUT		()							// Falling edge
		);
	end
endgenerate

// Outputs
	assign LB_IF.dout 		= clk_lb.dout;
	assign LB_IF.vld		= clk_lb.vld;
	assign BEAT_OUT 		= clk_tmr.beat;		// 1 MHz output
	assign IRQ_OUT 			= clk_sta.irq;

endmodule

`default_nettype wire
