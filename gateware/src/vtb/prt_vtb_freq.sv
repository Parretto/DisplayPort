/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Video Toolbox Frequency Counter
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

module prt_vtb_freq
#(
	parameter P_SYS_FREQ = 'd125000000
)
(
	// System
	input wire 				SYS_RST_IN,			// Reset
	input wire 				SYS_CLK_IN,			// Clock

	// Monitored clock
	input wire 				MON_CLK_IN,			// Clock
	input wire 				MON_CKE_IN,			// Clock enable

	// Frequency
	output wire [31:0]		FREQ_OUT
);

// State machine
typedef enum {
	sm_idle, sm_rst, sm_setup, sm_run, sm_cap
} sm_state;

// Structure
typedef struct {
	sm_state			sm_cur;
	sm_state			sm_nxt;
	logic				rst;
	logic				rst_set;
	logic				rst_clr;
	logic				run;
	logic				run_set;
	logic				run_clr;
	logic				cnt_ld;
	logic	[31:0]		cnt_in;
	logic	[31:0]		cnt;
	logic				cnt_end;
	logic	[31:0]		freq_cdc;
	logic				freq_ld;
	logic	[31:0]		freq;
} sys_struct;

typedef struct {
	logic				rst;
	logic				run;
	logic	[31:0]		cnt;
} mon_struct;


// Signals
sys_struct	sclk_sys;
mon_struct	mclk_mon;


// Logic

// State machine
	always_ff @ (posedge SYS_RST_IN, posedge SYS_CLK_IN)
	begin
		// Reset
		if (SYS_RST_IN)
			sclk_sys.sm_cur <= sm_idle;

		else
			sclk_sys.sm_cur <= sclk_sys.sm_nxt;
	end

// State machine decoder
	always_comb
	begin
		// Defaults
		sclk_sys.cnt_ld = 0;
		sclk_sys.cnt_in = 0;
		sclk_sys.rst_clr = 0;
		sclk_sys.rst_set = 0;
		sclk_sys.run_clr = 0;
		sclk_sys.run_set = 0;
		sclk_sys.freq_ld = 0;

		case (sclk_sys.sm_cur)

			sm_idle : 
			begin
				// Reset monitor counter
				sclk_sys.rst_set = 1;
				sclk_sys.cnt_ld = 1;
				sclk_sys.cnt_in = 'd255;
				sclk_sys.sm_nxt = sm_rst;
			end

			sm_rst : 
			begin
				if (sclk_sys.cnt_end)
				begin
					sclk_sys.cnt_in = 'd255;
					sclk_sys.cnt_ld = 1;
					sclk_sys.rst_clr = 1;
					sclk_sys.run_clr = 1;
					sclk_sys.sm_nxt = sm_setup;
				end

				else
					sclk_sys.sm_nxt = sm_rst;
			end

			sm_setup : 
			begin
				if (sclk_sys.cnt_end)
				begin
					sclk_sys.cnt_in = P_SYS_FREQ;
					sclk_sys.cnt_ld = 1;
					sclk_sys.run_set = 1;
					sclk_sys.sm_nxt = sm_run;
				end

				else
					sclk_sys.sm_nxt = sm_setup;
			end

			sm_run : 
			begin
				if (sclk_sys.cnt_end)
				begin
					sclk_sys.cnt_in = 'd255;
					sclk_sys.cnt_ld = 1;
					sclk_sys.run_clr = 1;
					sclk_sys.sm_nxt = sm_cap;
				end

				else
					sclk_sys.sm_nxt = sm_run;
			end

			sm_cap : 
			begin
				if (sclk_sys.cnt_end)
				begin
					sclk_sys.freq_ld = 1;
					sclk_sys.sm_nxt = sm_idle;
				end

				else
					sclk_sys.sm_nxt = sm_cap;
			end

			default : 
				sclk_sys.sm_nxt = sm_idle;
		endcase
	end

// Counter 
	always_ff @ (posedge SYS_CLK_IN)
	begin
		// Load
		if (sclk_sys.cnt_ld)
			sclk_sys.cnt <= sclk_sys.cnt_in;

		// Decrement
		else if (!sclk_sys.cnt_end)
			sclk_sys.cnt <= sclk_sys.cnt - 'd1;
	end

// Counter end
	always_comb
	begin
		if (sclk_sys.cnt == 0)
			sclk_sys.cnt_end = 1;
		else			
			sclk_sys.cnt_end = 0;
	end

// Reset flag
	always_ff @ (posedge SYS_RST_IN, posedge SYS_CLK_IN)
	begin
		if (SYS_RST_IN)
			sclk_sys.rst <= 0;

		else
		begin
			// Set
			if (sclk_sys.rst_set)
				sclk_sys.rst <= 1;

			// Clear
			else if (sclk_sys.rst_clr)
				sclk_sys.rst <= 0;
		end
	end

// Run flag
	always_ff @ (posedge SYS_RST_IN, posedge SYS_CLK_IN)
	begin
		if (SYS_RST_IN)
			sclk_sys.run <= 0;

		else
		begin
			// Set
			if (sclk_sys.run_set)
				sclk_sys.run <= 1;

			// Clear
			else if (sclk_sys.run_clr)
				sclk_sys.run <= 0;
		end
	end

// Frequency
	always_ff @ (posedge SYS_RST_IN, posedge SYS_CLK_IN)
	begin
		if (SYS_RST_IN)
			sclk_sys.freq <= 0;

		else
		begin
			// Load
			if (sclk_sys.freq_ld)
				sclk_sys.freq <= sclk_sys.freq_cdc; 
		end
	end


/*
	Monitor domain
*/

// Reset
    prt_dp_lib_rst
    MON_RST_INST
    (
        .SRC_RST_IN     (sclk_sys.rst),
        .SRC_CLK_IN     (SYS_CLK_IN),
        .DST_CLK_IN     (MON_CLK_IN),
        .DST_RST_OUT    (mclk_mon.rst)
    );

// Run clock domain crossing
    prt_dp_lib_cdc_bit
    MON_RUN_CDC_INST
    (
        .SRC_CLK_IN     (SYS_CLK_IN),       // Clock
        .SRC_DAT_IN     (sclk_sys.run), 	// Data
        .DST_CLK_IN     (MON_CLK_IN),       // Clock
        .DST_DAT_OUT	(mclk_mon.run)  	// Data
    );

// Counter
	always_ff @ (posedge mclk_mon.rst, posedge MON_CLK_IN)
	begin
		// Reset
		if (mclk_mon.rst)
			mclk_mon.cnt <= 0;

		else 
		begin
			// Clock enable
			if (MON_CKE_IN)
			begin
				// Run
				if (mclk_mon.run)
					mclk_mon.cnt <= mclk_mon.cnt + 'd1;
			end
		end
	end

// Cross counter value
	prt_dp_lib_cdc_vec
	#(
		.P_WIDTH		($size(mclk_mon.cnt))
	)
	MON_CNT_CDC_INST
	(
		.SRC_CLK_IN		(MON_CLK_IN),		// Clock
		.SRC_DAT_IN		(mclk_mon.cnt),	// Data
		.DST_CLK_IN		(SYS_CLK_IN),		// Clock
		.DST_DAT_OUT	(sclk_sys.freq_cdc)	// Data
	);

// Outputs
	assign FREQ_OUT = sclk_sys.freq;

endmodule

`default_nettype wire
