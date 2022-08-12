/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Video Toolbox Clock Recovery
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

module prt_vtb_cr
#(
	parameter				P_SIM = 0,			// Simualtion
	parameter 				P_PPC = 2			// Pixels per clock
)
(
	// Reset and clock
	input wire 				SYS_RST_IN,			// System Reset
	input wire 				SYS_CLK_IN,			// System Clock
	input wire 				LNK_CLK_IN,			// Link Clock
	input wire 				VID_CLK_IN,			// Video Clock
	input wire 				VID_CKE_IN,			// Video Clock enable

	// Control
 	input wire 				CTL_RUN_IN,			// Run
 	input wire [7:0]		CTL_P_GAIN_IN,		// P gain
 	input wire [15:0]		CTL_I_GAIN_IN,		// I gain

 	// Status
 	output wire [7:0]		STA_CUR_ERR_OUT,	// Current error
 	output wire [7:0]		STA_MAX_ERR_OUT,	// Maximum error
 	output wire [7:0]		STA_MIN_ERR_OUT,	// Minimum error
 	output wire [15:0]		STA_SUM_OUT,		// Sum
 	output wire [28:0]		STA_CO_OUT,			// Controller output
 	
	// Video parameter set
	input wire [3:0]		VPS_IDX_IN,			// Index
	input wire [15:0]		VPS_DAT_IN,			// Data
	input wire 				VPS_VLD_IN,			// Valid	

	// Link
	input wire				LNK_SYNC_IN,

	// Direct I2C Access
	input wire				DIA_RDY_IN,
	output wire [31:0] 		DIA_DAT_OUT,
	output wire				DIA_VLD_OUT,

	// Debug
	output wire 			DBG_SYNC_END_OUT,	// Sync out
	output wire 			DBG_PIX_END_OUT		// Pixel out
);

// Parameters
localparam P_LINES = (P_SIM) ? 8 : 256;
localparam P_LINES_LOG = $clog2(P_LINES);
localparam P_ERR_WIDTH = 6;
localparam P_SUM_WIDTH = 15;
localparam P_P_GAIN_WIDTH = 9;
localparam P_I_GAIN_WIDTH = 14;
localparam P_P_WIDTH = P_ERR_WIDTH + P_P_GAIN_WIDTH;
localparam P_I_WIDTH = P_SUM_WIDTH + P_I_GAIN_WIDTH;
localparam P_CO_WIDTH = P_I_WIDTH;

// State machine
typedef enum {
	vid_sm_idle, vid_sm_run, vid_sm_wait
} vid_sm_state;

typedef enum {
	dcl_sm_idle, dcl_sm_set, dcl_sm_busy
} dcl_sm_state;

// Structures
typedef struct {
	logic								run;		// Run
} ctl_struct;

typedef struct {
	logic								run;
	logic								sync;
	logic								sync_re;
	logic								sync_toggle;
} lnk_struct;

typedef struct {
	vid_sm_state						sm_cur;
	vid_sm_state						sm_nxt;
	logic								run;
	logic	[15:0]						htotal;
	logic								sync;
	logic								sync_re;
	logic								sync_fe;
	logic								sync_cnt_ld;
	logic	[15:0]						sync_cnt;
	logic								sync_cnt_end;
	logic								pix_cnt_ld;
	logic	[23:0]						pix_cnt;
	logic								pix_cnt_end;
	logic								err_cnt_clr;
	logic signed [P_ERR_WIDTH-1:0]		err_cnt;
	logic								rdy;
	logic								rdy_set;
	logic								busy;
	logic								busy_re;
	logic								busy_fe;
} vid_struct;

typedef struct {
	dcl_sm_state						sm_cur;
	dcl_sm_state						sm_nxt;
	logic								rdy;
	logic								busy;
	logic								busy_set;
	logic								cnt_ld;
	logic [7:0]							cnt;
	logic								cnt_end;
	logic signed [P_ERR_WIDTH-1:0]		err;
	logic								ld;
	logic signed [P_SUM_WIDTH-1:0]		sum_in;
	logic								sum_of;
	logic								sum_uf;
	logic signed [P_SUM_WIDTH-1:0]		sum;
	logic signed [P_P_WIDTH-1:0] 		p;
	logic signed [P_P_GAIN_WIDTH-1:0] 	p_gain;
	logic signed [P_I_WIDTH-1:0] 		i;
	logic signed [P_I_GAIN_WIDTH-1:0] 	i_gain;
	logic signed [P_CO_WIDTH-1:0] 		co;
	logic signed [P_ERR_WIDTH-1:0]		cur_err;
	logic signed [P_ERR_WIDTH-1:0]		max_err;
	logic signed [P_ERR_WIDTH-1:0]		min_err;
} dcl_struct;

typedef struct {
	logic [31:0]						dat;
	logic								vld;
	logic								vld_set;
	logic								rdy;
	logic								rdy_re;
	logic								rdy_fe;
} dia_struct;

// Signals
ctl_struct 		sclk_ctl;
lnk_struct 		lclk_lnk;
vid_struct 		vclk_vid;
dcl_struct 		sclk_dcl;
dia_struct 		sclk_dia;

// Logic

// Inputs
	always_ff @ (posedge SYS_CLK_IN)
	begin
		sclk_ctl.run  <= CTL_RUN_IN;
	end

/*
	Link domain
*/

// Run capture
    prt_dp_lib_cdc_bit
    LCLK_RUN_CDC_INST
    (
        .SRC_CLK_IN   	(SYS_CLK_IN),       // Clock
        .SRC_DAT_IN    	(sclk_ctl.run),  	// Data
        .DST_CLK_IN    	(LNK_CLK_IN),       // Clock
        .DST_DAT_OUT   	(lclk_lnk.run)     // Data
    );

// Sync capture
	always_ff @ (posedge LNK_CLK_IN)
	begin
		lclk_lnk.sync <= LNK_SYNC_IN;
	end

// Edge detector
    prt_dp_lib_edge
    LCLK_SYNC_EDGE_INST
    (
        .CLK_IN    (LNK_CLK_IN), 		   	// Clock
        .CKE_IN    (1'b1),           	 	// Clock enable
        .A_IN      (lclk_lnk.sync),      	// Input
        .RE_OUT    (lclk_lnk.sync_re), 		// Rising edge
        .FE_OUT    ()   					// Falling edge
    );

// Link toggle
	always_ff @ (posedge LNK_CLK_IN)
	begin
		// Run
		if (lclk_lnk.run)
		begin
			if (lclk_lnk.sync_re)
				lclk_lnk.sync_toggle <= ~lclk_lnk.sync_toggle;
		end

		else
			lclk_lnk.sync_toggle <= 0;
	end

/*
	Video domain
*/

// Run capture
    prt_dp_lib_cdc_bit
    VCLK_RUN_CDC_INST
    (
        .SRC_CLK_IN   	(SYS_CLK_IN),       // Clock
        .SRC_DAT_IN    	(sclk_ctl.run),  	// Data
        .DST_CLK_IN    	(VID_CLK_IN),       // Clock
        .DST_DAT_OUT   	(vclk_vid.run)     // Data
    );

// Htotal register
	always_ff @ (posedge VID_CLK_IN)
	begin
		// Write
		if ((VPS_IDX_IN == 'd4) && VPS_VLD_IN)
			vclk_vid.htotal <= VPS_DAT_IN[0+:$size(vclk_vid.htotal)];
	end

// Sync capture
    prt_dp_lib_cdc_bit
    VCLK_SYNC_CDC_INST
    (
        .SRC_CLK_IN   	(LNK_CLK_IN),           // Clock
        .SRC_DAT_IN    	(lclk_lnk.sync_toggle), // Data
        .DST_CLK_IN    	(VID_CLK_IN),           // Clock
        .DST_DAT_OUT   	(vclk_vid.sync)      	// Data
    );

    prt_dp_lib_edge
    VCLK_SYNC_EDGE_INST
    (
        .CLK_IN    (VID_CLK_IN), 		   	// Clock
        .CKE_IN    (VID_CKE_IN),      	 	// Clock enable
        .A_IN      (vclk_vid.sync),      	// Input
        .RE_OUT    (vclk_vid.sync_re), 		// Rising edge
        .FE_OUT    (vclk_vid.sync_fe) 		// Falling edge
    );

// Sync Counter
	always_ff @ (posedge VID_CLK_IN)
	begin
		// Enable
		if (VID_CKE_IN)
		begin
			// Load
			if (vclk_vid.sync_cnt_ld)
				vclk_vid.sync_cnt <= P_LINES;

			// Decrement on every sync pulse
			else if (!vclk_vid.sync_cnt_end && (vclk_vid.sync_re || vclk_vid.sync_fe))
				vclk_vid.sync_cnt <= vclk_vid.sync_cnt - 'd1;
		end
	end

// Sync counter end
	always_comb
	begin
		if (vclk_vid.sync_cnt == 0)
			vclk_vid.sync_cnt_end = 1;
		else
			vclk_vid.sync_cnt_end = 0;
	end

// Pixel Counter
	always_ff @ (posedge VID_CLK_IN)
	begin
		// Enable
		if (VID_CKE_IN)
		begin
			// Load
			if (vclk_vid.pix_cnt_ld)
				vclk_vid.pix_cnt <= {vclk_vid.htotal, {P_LINES_LOG{1'b0}}};

			// Decrement
			else if (!vclk_vid.pix_cnt_end)
				vclk_vid.pix_cnt <= vclk_vid.pix_cnt - P_PPC;
		end
	end

// Pixel Counter end
	always_comb
	begin
		if (vclk_vid.pix_cnt == 0)
			vclk_vid.pix_cnt_end = 1;
		else
			vclk_vid.pix_cnt_end = 0;
	end

// State machine
	always_ff @ (posedge VID_CLK_IN)
	begin
		// Enable
		if (VID_CKE_IN)
		begin
			// Run
			if (vclk_vid.run)
				vclk_vid.sm_cur <= vclk_vid.sm_nxt;

			else
				vclk_vid.sm_cur <= vid_sm_idle;
		end
	end

// State machine decoder
	always_comb
	begin
		// Default
		vclk_vid.sync_cnt_ld = 0;
		vclk_vid.pix_cnt_ld = 0;
		vclk_vid.err_cnt_clr = 0;
		vclk_vid.rdy_set = 0;

		case (vclk_vid.sm_cur)
	
			vid_sm_idle : 
			begin
				// Wait for sync pulse
				if (vclk_vid.sync_re)
				begin
					// Load counters
					vclk_vid.sync_cnt_ld = 1;
					vclk_vid.pix_cnt_ld = 1;
					vclk_vid.err_cnt_clr = 1;
					vclk_vid.sm_nxt = vid_sm_run;
				end

				else
					vclk_vid.sm_nxt = vid_sm_idle;
			end

			vid_sm_run : 
			begin
				// Wait for both counters to end
				if (vclk_vid.sync_cnt_end && vclk_vid.pix_cnt_end)
				begin
					vclk_vid.rdy_set = 1;
					vclk_vid.sm_nxt = vid_sm_wait;
				end

				else
					vclk_vid.sm_nxt = vid_sm_run;
			end

			vid_sm_wait :
			begin
				if (vclk_vid.busy_fe)
					vclk_vid.sm_nxt = vid_sm_idle;

				else
					vclk_vid.sm_nxt = vid_sm_wait;
			end			

			default : 
			begin
				vclk_vid.sm_nxt = vid_sm_idle;
			end
		endcase
	end

// Error
// The error is positive in case of a faster video clock
// The error becomes negative is case of a slower video clock
	always_ff @ (posedge VID_CLK_IN)
	begin
		// Enable
		if (VID_CKE_IN)
		begin
			// Clear
			if (vclk_vid.err_cnt_clr)
				vclk_vid.err_cnt <= 0;

			// Video clock is too slow
			else if (vclk_vid.sync_cnt_end && !vclk_vid.pix_cnt_end)
			begin
				// Prevent overflow
				if (vclk_vid.err_cnt != {1'b0, {$size(vclk_vid.err_cnt)-1{1'b1}}})
					vclk_vid.err_cnt <= vclk_vid.err_cnt + 'd1;
			end

			// Video clock is too fast
			else if (!vclk_vid.sync_cnt_end && vclk_vid.pix_cnt_end)
			begin
				// Prevent undeflow
				if (vclk_vid.err_cnt != {1'b1, {$size(vclk_vid.err_cnt)-1{1'b0}}})	
					vclk_vid.err_cnt <= vclk_vid.err_cnt - 'd1;
			end
		end
	end

// Ready flag
// This flag is asserted when the new error value is ready 
	always_ff @ (posedge VID_CLK_IN)
	begin
		// Enable
		if (VID_CKE_IN)
		begin
			// Run
			if (vclk_vid.run)
			begin
				// Clear
				if (vclk_vid.busy_re)
					vclk_vid.rdy <= 0;

				// Set
				else if (vclk_vid.rdy_set)
					vclk_vid.rdy <= 1;
			end

			else
				vclk_vid.rdy <= 0;
		end
	end

    prt_dp_lib_cdc_bit
    VCLK_BUSY_CDC_INST
    (
    	.SRC_CLK_IN   	(SYS_CLK_IN),          	// Clock
       	.SRC_DAT_IN   	(sclk_dcl.busy), 	 	// Data
       	.DST_CLK_IN   	(VID_CLK_IN),          	// Clock
       	.DST_DAT_OUT  	(vclk_vid.busy)      	// Data
	);

    prt_dp_lib_edge
    VCLK_BUSY_EDGE_INST
    (
        .CLK_IN    	(VID_CLK_IN), 		   	// Clock
        .CKE_IN    	(VID_CKE_IN),      	 	// Clock enable
        .A_IN      	(vclk_vid.busy),      	// Input
        .RE_OUT    	(vclk_vid.busy_re), 	// Rising edge
        .FE_OUT 	(vclk_vid.busy_fe) 		// Falling edge
    );

/*
	Digital controlled loop
	System domain
*/

// Error clock domain crossing
	prt_dp_lib_cdc_vec
	#(
		.P_WIDTH 		($size(sclk_dcl.err))
	)
	SCLK_ERR_CDC_INST
	(
		.SRC_CLK_IN		(VID_CLK_IN),			// Clock
		.SRC_DAT_IN		(vclk_vid.err_cnt),		// Data
		.DST_CLK_IN		(SYS_CLK_IN),			// Clock
		.DST_DAT_OUT	(sclk_dcl.err)			// Data
	);

// Sync capture
	prt_dp_lib_cdc_bit
	SCLK_RDY_CDC_INST
	(
 		.SRC_CLK_IN   	(VID_CLK_IN),      	// Clock
    	.SRC_DAT_IN   	(vclk_vid.rdy),  	// Data
    	.DST_CLK_IN   	(SYS_CLK_IN),     	// Clock
    	.DST_DAT_OUT  	(sclk_dcl.rdy)    	// Data
	);

// Sum in
	always_ff @ (posedge SYS_CLK_IN)
	begin
		sclk_dcl.sum_in <= sclk_dcl.sum + sclk_dcl.err;
	end

// Sum overflow
	always_comb
	begin
		if (!sclk_dcl.err[$left(sclk_dcl.err)] && !sclk_dcl.sum[$left(sclk_dcl.sum)] && sclk_dcl.sum_in[$left(sclk_dcl.sum_in)])
			sclk_dcl.sum_of = 1;
		else
			sclk_dcl.sum_of = 0;
	end 

// Sum underflow
	always_comb
	begin
		if (sclk_dcl.err[$left(sclk_dcl.err)] && sclk_dcl.sum[$left(sclk_dcl.sum)] && !sclk_dcl.sum_in[$left(sclk_dcl.sum_in)])
			sclk_dcl.sum_uf = 1;
		else
			sclk_dcl.sum_uf = 0;
	end 

// Sum error
// Integrator
	always_ff @ (posedge SYS_CLK_IN)
	begin
		// Run
		if (sclk_ctl.run)
		begin
			// Load
			if (sclk_dcl.ld)
			begin
				// Overflow
				if (sclk_dcl.sum_of)
					sclk_dcl.sum <= {1'b0, {$size(sclk_dcl.sum)-1{1'b1}}};	// Maximum positive value

				// Underflow
				else if (sclk_dcl.sum_uf)
					sclk_dcl.sum <= {1'b1, {$size(sclk_dcl.sum)-1{1'b0}}};	// Maximum minimal value

				else
					sclk_dcl.sum <= sclk_dcl.sum_in; 
			end
		end

		else
			sclk_dcl.sum <= 0;
	end

// P gain
	always_ff @ (posedge SYS_CLK_IN)
	begin
		sclk_dcl.p_gain <= {1'b0, CTL_P_GAIN_IN[0+:P_P_GAIN_WIDTH-1]};
	end

// P 
	always_ff @ (posedge SYS_CLK_IN)
	begin
		sclk_dcl.p <= sclk_dcl.p_gain * sclk_dcl.err;
	end

// I gain
	always_ff @ (posedge SYS_CLK_IN)
	begin
		sclk_dcl.i_gain <= {1'b0, CTL_I_GAIN_IN[0+:P_I_GAIN_WIDTH-1]};
	end

// I 
	always_ff @ (posedge SYS_CLK_IN)
	begin
		sclk_dcl.i <= sclk_dcl.i_gain * sclk_dcl.sum;
	end

// Controller output
	always_ff @ (posedge SYS_CLK_IN)
	begin
		sclk_dcl.co <= sclk_dcl.p + sclk_dcl.i;
	end

// State machine
	always_ff @ (posedge SYS_CLK_IN)
	begin
		// Run
		if (sclk_ctl.run)
			sclk_dcl.sm_cur <= sclk_dcl.sm_nxt;
		else
			sclk_dcl.sm_cur <= dcl_sm_idle;
	end

// State machine decoder
	always_comb
	begin
		// Default
		sclk_dcl.busy_set = 0;
		sclk_dcl.cnt_ld = 0;
		sclk_dcl.ld = 0;
		sclk_dia.vld_set = 0;

		case (sclk_dcl.sm_cur)
	
			dcl_sm_idle : 
			begin
				// Wait for ready flag
				if (sclk_dcl.rdy && sclk_dia.rdy)
				begin
					// Set busy flag
					sclk_dcl.busy_set = 1;
					
					// Load counter
					// This will give the error value some time to cross to the system domain
					sclk_dcl.cnt_ld = 1;
					sclk_dcl.sm_nxt = dcl_sm_set;
				end

				else
					sclk_dcl.sm_nxt = dcl_sm_idle;
			end

			// Setup
			dcl_sm_set :
			begin
				if (sclk_dcl.cnt_end)
				begin
					// Load 
					sclk_dcl.ld = 1;

					// Start I2C 
					sclk_dia.vld_set = 1;
					sclk_dcl.sm_nxt = dcl_sm_busy;
				end

				else
					sclk_dcl.sm_nxt = dcl_sm_set;
			end

			// Busy
			dcl_sm_busy :
			begin
				if (!sclk_dcl.busy)
					sclk_dcl.sm_nxt = dcl_sm_idle;

				else
					sclk_dcl.sm_nxt = dcl_sm_busy;
			end

			default : 
			begin
				sclk_dcl.sm_nxt = dcl_sm_idle;
			end
		endcase
	end

// Busy
	always_ff @ (posedge SYS_CLK_IN)
	begin
		// Run
		if (sclk_ctl.run)
		begin
			// Clear
			if (sclk_dia.rdy_re)
				sclk_dcl.busy <= 0;

			// Set
			else if (sclk_dcl.busy_set)
				sclk_dcl.busy <= 1;
		end
	
		else
			sclk_dcl.busy <= 0;
	end

// Counter
	always_ff @ (posedge SYS_CLK_IN)
	begin
		// Load
		if (sclk_dcl.cnt_ld)
			sclk_dcl.cnt <= '1;

		// Decrement
		else if (!sclk_dcl.cnt_end)
			sclk_dcl.cnt <= sclk_dcl.cnt - 'd1;
	end

// Counter end
	always_comb
	begin
		if (sclk_dcl.cnt == 0)
			sclk_dcl.cnt_end = 1;
		else
			sclk_dcl.cnt_end = 0;
	end

// Current error
// For statistics
	always_ff @ (posedge SYS_CLK_IN)
	begin
		// Run
		if (sclk_ctl.run)
		begin
			// Set
			if (sclk_dcl.ld)
				sclk_dcl.cur_err <= sclk_dcl.err;
		end

		else
			sclk_dcl.cur_err <= 0;
	end

// Maximum error
// For statistics
	always_ff @ (posedge SYS_CLK_IN)
	begin
		// Run
		if (sclk_ctl.run)
		begin
			// Set
			if (sclk_dcl.ld)
			begin
				if (sclk_dcl.err > sclk_dcl.max_err)
					sclk_dcl.max_err <= sclk_dcl.err;
			end
		end

		else
			sclk_dcl.max_err <= 0;
	end

// Minimum error
// For statistics
	always_ff @ (posedge SYS_CLK_IN)
	begin
		// Run
		if (sclk_ctl.run)
		begin
			// Set
			if (sclk_dcl.ld)
			begin
				if (sclk_dcl.err < sclk_dcl.min_err)
					sclk_dcl.min_err <= sclk_dcl.err;
			end
		end

		else
			sclk_dcl.min_err <= 0;
	end

/*
	Direct I2C access
*/

// Data
	always_ff @ (posedge SYS_CLK_IN)
	begin
		// Set
		if (sclk_dia.vld_set)
			sclk_dia.dat <= {3'h0, sclk_dcl.co};	
	end

// Valid
	always_ff @ (posedge SYS_CLK_IN)
	begin
		// Run
		if (sclk_ctl.run)
		begin
			// Set
			if (sclk_dia.vld_set)
				sclk_dia.vld <= 1;

			// Clear
			else if (sclk_dia.rdy_fe)
				sclk_dia.vld <= 0;
		end

		else
			sclk_dia.vld <= 0;
	end

// Ready
	always_ff @ (posedge SYS_CLK_IN)
	begin
		sclk_dia.rdy <= DIA_RDY_IN;
	end

    prt_dp_lib_edge
    SCLK_dia_RDY_EDGE_INST
    (
        .CLK_IN    	(SYS_CLK_IN), 		// Clock
        .CKE_IN    	(1'b1),           	// Clock enable
        .A_IN      	(sclk_dia.rdy),     // Input
        .RE_OUT    	(sclk_dia.rdy_re), 	// Rising edge
        .FE_OUT 	(sclk_dia.rdy_fe) 	// Falling edge
    );

// Outputs
	assign STA_CUR_ERR_OUT 	= sclk_dcl.cur_err;
	assign STA_MAX_ERR_OUT 	= sclk_dcl.max_err;
	assign STA_MIN_ERR_OUT 	= sclk_dcl.min_err;
	assign STA_SUM_OUT 		= sclk_dcl.sum;
	assign STA_CO_OUT 		= sclk_dcl.co;
	assign DIA_DAT_OUT 		= sclk_dia.dat;
	assign DIA_VLD_OUT 		= sclk_dia.vld;
	assign DBG_SYNC_END_OUT = vclk_vid.sync_cnt_end; // Debug Sync end out
	assign DBG_PIX_END_OUT 	= vclk_vid.pix_cnt_end;	 // Debug Pixel end out

endmodule

`default_nettype wire
