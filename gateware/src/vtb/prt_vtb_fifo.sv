/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Video Toolbox FIFO
    (c) 2021 - 2025 by Parretto B.V.

    History
    =======
    v1.0 - Initial release

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

module prt_vtb_fifo
#(
    parameter P_VENDOR = "none",  				// Vendor - "AMD", "ALTERA" or "LSC" 
	parameter P_PPC = 2,						// Pixels per clock
	parameter P_BPC = 8,						// Bits per component
    parameter P_AXIS_DAT = 48					// AXIS data width
)
(
	// Reset and clocks
	input wire 								VID_RST_IN,			// Reset
	input wire 								VID_CLK_IN,			// Clock
	input wire 								VID_CKE_IN,			// Clock enable

	// Control
	input wire								CTL_RUN_IN,			// Run

	// Status
	output wire 							STA_LOCK_OUT,		// Lock
	output wire [9:0]						STA_MAX_WRDS_OUT,	// Maximum words	
	output wire [9:0]						STA_MIN_WRDS_OUT,	// Minimum words	

	// Timing
	output wire 							TG_RUN_OUT,			// Run
	
	// AXIS
	input wire          					AXIS_SOF_IN,        // Start of frame
	input wire          					AXIS_EOL_IN,        // End of line
	input wire [P_AXIS_DAT-1:0]  			AXIS_DAT_IN,        // Data
	input wire          					AXIS_VLD_IN,        // Valid

	// Video
	input wire								VID_VS_IN,			// Vsync in
	input wire								VID_HS_IN,			// Hsync in
	input wire 								VID_DE_IN,			// Data enable in
	output wire [(P_BPC * P_PPC)-1:0]		VID_R_OUT,			// Red
	output wire [(P_BPC * P_PPC)-1:0]		VID_G_OUT,			// Green
	output wire [(P_BPC * P_PPC)-1:0]		VID_B_OUT,			// Blue
	output wire 							VID_VS_OUT,			// Vsync out
	output wire 							VID_HS_OUT,			// Hsync out
	output wire 							VID_DE_OUT			// Data enable out
);

// Local parameters
localparam P_FIFO_WRDS 		= 1024;
localparam P_FIFO_ADR 		= $clog2(P_FIFO_WRDS);
localparam P_FIFO_DAT 		= P_BPC * P_PPC * 3;
localparam P_FIFO_MID 		= P_FIFO_WRDS / 2; 	// Midpoint

// State machine
typedef enum {
	sm_idle, sm_sof, sm_mid, sm_vs, sm_lock
} sm_state;

// Structures
typedef struct {
	logic 							sof;
	logic							eol;
	logic							vld;
	logic [P_FIFO_DAT-1:0]			dat;
} axis_struct;

typedef struct {
	logic							clr;
	logic [4:0]						clr_cnt;
	logic							clr_cnt_end;
	logic							wr_en;
	logic							wr;
	logic							rd;
	logic [P_FIFO_DAT-1:0]			dout;
	logic 							de;
	logic [P_FIFO_ADR:0]			wrds;
	logic [P_FIFO_ADR:0]			max_wrds;
	logic [P_FIFO_ADR:0]			min_wrds;
	logic 							fl;
	logic 							ep;
	logic							mid;
} fifo_struct;

typedef struct {
	sm_state						sm_cur;
	sm_state						sm_nxt;
	logic							run;
	logic							sof;
	logic							tg_run_set;
	logic							tg_run_clr;
	logic							tg_run;
	logic [2:0]						vs;
	logic							vs_re;
	logic [2:0]						hs;
	logic							de;
	logic							de_re;
	logic							en;
	logic							en_set;
	logic							en_clr;
	logic							lock;
	logic							lock_fe;
} vid_struct;

// Signals
axis_struct 	vclk_axis;
fifo_struct 	vclk_fifo;
vid_struct 		vclk_vid;

genvar i;

// Logic

/*
	Video sink domain
*/

// Inputs
	always_ff @ (posedge VID_CLK_IN)
	begin
		vclk_axis.sof <= AXIS_SOF_IN;
		vclk_axis.eol <= AXIS_EOL_IN;
		vclk_axis.dat <= AXIS_DAT_IN[0+:P_FIFO_DAT];
		vclk_axis.vld <= AXIS_VLD_IN;
	end

// FIFO write enable
	always_ff @ (posedge VID_CLK_IN)
	begin
		// Run
		if (vclk_vid.run)
		begin
			// Clear
			if (vclk_vid.lock_fe)
				vclk_fifo.wr_en <= 0;

			// Set 
			else if (vclk_axis.sof)
				vclk_fifo.wr_en <= 1;
		end

		// Idle
		else
			vclk_fifo.wr_en <= 0;
	end

// FIFO write
	assign vclk_fifo.wr = (vclk_fifo.wr_en) ? vclk_axis.vld : 1'b0;

// FIFO Clear
	always_ff @ (posedge VID_CLK_IN)
	begin
		// Run
		if (vclk_vid.run)
		begin
			// Default
			vclk_fifo.clr <= 0;
			
			// Clear the fifo at loss of lock and at every vsync.
			if (vclk_vid.lock_fe || vclk_vid.vs_re)
			begin
				vclk_fifo.clr <= 1;
				vclk_fifo.clr_cnt <= '1;
			end

			else if (!vclk_fifo.clr_cnt_end)
			begin
				vclk_fifo.clr <= 1;
				vclk_fifo.clr_cnt <= vclk_fifo.clr_cnt - 'd1;
			end
		end

		// Idle
		else
		begin
			vclk_fifo.clr <= 1;
			vclk_fifo.clr_cnt <= 0;
		end
	end

// FIFO clear counter end
	always_comb
	begin
		if (vclk_fifo.clr_cnt == 0)
			vclk_fifo.clr_cnt_end = 1;
		else
			vclk_fifo.clr_cnt_end = 0;
	end	

// FIFO
    prt_dp_lib_fifo_dc
    #(
    	.P_VENDOR		(P_VENDOR),				// Vendor
    	.P_MODE         ("burst"),		        // "single" or "burst"
    	.P_RAM_STYLE	("block"),	   			// "distributed" or "block"
    	.P_ADR_WIDTH	(P_FIFO_ADR),
    	.P_DAT_WIDTH	(P_FIFO_DAT)
    )
    FIFO_INST
    (
    	.A_RST_IN      (VID_RST_IN),  			// Reset
    	.B_RST_IN      (VID_RST_IN),
    	.A_CLK_IN      (VID_CLK_IN),		    // Clock
    	.B_CLK_IN      (VID_CLK_IN),
    	.A_CKE_IN      (1'b1),		    		// Clock enable
    	.B_CKE_IN      (VID_CKE_IN),

    	// Input (A)
    	.A_CLR_IN	   (vclk_fifo.clr),			// Clear
    	.A_WR_IN       (vclk_fifo.wr),	    	// Write
    	.A_DAT_IN      (vclk_axis.dat),			// Write data

    	// Output (B)
    	.B_CLR_IN	   (vclk_fifo.clr),			// Clear
    	.B_RD_IN       (vclk_fifo.rd),		    // Read
    	.B_DAT_OUT     (vclk_fifo.dout),		// Read data
    	.B_DE_OUT      (vclk_fifo.de),			// Data enable

    	// Status (A)
    	.A_WRDS_OUT    (),						// Used words
    	.A_FL_OUT      (),						// Full
    	.A_EP_OUT      (),						// Empty

    	// Status (B)
    	.B_WRDS_OUT    (vclk_fifo.wrds),		// Used words
    	.B_FL_OUT      (vclk_fifo.fl),			// Full
    	.B_EP_OUT      (vclk_fifo.ep)			// Empty
    );

/*
	Video source domain
*/

// Run
	always_ff @ (posedge VID_CLK_IN)
	begin
		vclk_vid.run <= CTL_RUN_IN;
	end

// SOF
	always_ff @ (posedge VID_CLK_IN)
	begin
		// Enable
		if (VID_CKE_IN)
			vclk_vid.sof <= vclk_axis.sof;
	end

// Data enable
	always_ff @ (posedge VID_CLK_IN)
	begin
		// Enable
		if (VID_CKE_IN)
			vclk_vid.de <= VID_DE_IN;
	end

// DE edge detector
// This is used for the fifo words storage
    prt_dp_lib_edge
    VID_DE_EDGE_INST
    (
        .CLK_IN    (VID_CLK_IN),      	// Clock
        .CKE_IN    (VID_CKE_IN),       	// Clock enable
        .A_IN      (vclk_vid.de),		// Input
        .RE_OUT    (vclk_vid.de_re),    // Rising edge
        .FE_OUT    () 				  	// Falling edge
    );

// FIFO read
	assign vclk_fifo.rd = vclk_vid.de;

// Midpoint
	always_ff @ (posedge VID_CLK_IN)
	begin
		if (vclk_fifo.wrds >= P_FIFO_MID)
			vclk_fifo.mid <= 1;
		else
			vclk_fifo.mid <= 0;
	end

// Maximum words
// Used for statistics
	always_ff @ (posedge VID_CLK_IN)
	begin
		// Locked
		if (vclk_vid.lock)
		begin
			// The words are captured at the start of a line
			if (vclk_vid.de_re)
			begin
				if (vclk_fifo.wrds > vclk_fifo.max_wrds)
					vclk_fifo.max_wrds <= vclk_fifo.wrds;
			end
		end

		else
			vclk_fifo.max_wrds <= P_FIFO_MID;
	end

// Minimum words
// Used for statistics
	always_ff @ (posedge VID_CLK_IN)
	begin
		// Locked
		if (vclk_vid.lock)
		begin
			// The words are captured at the start of a line
			if (vclk_vid.de_re)
			begin
				if (vclk_fifo.wrds < vclk_fifo.min_wrds)
					vclk_fifo.min_wrds <= vclk_fifo.wrds;
			end
		end

		else
			vclk_fifo.min_wrds <= P_FIFO_MID;
	end

// State machine
	always_ff @ (posedge VID_RST_IN, posedge VID_CLK_IN)
	begin
		// Reset
		if (VID_RST_IN)
			vclk_vid.sm_cur <= sm_idle;
		
		else
		begin
			// Enable
			if (VID_CKE_IN)
			begin		
				// Run
				if (vclk_vid.run)
				begin
					if (vclk_vid.sof)
						vclk_vid.sm_cur <= sm_sof;
					else
						vclk_vid.sm_cur <= vclk_vid.sm_nxt;
				end

				else
					vclk_vid.sm_cur <= sm_idle;
			end
		end
	end

// State machine decoder
	always_comb
	begin
		// Default
		vclk_vid.tg_run_set = 0;
		vclk_vid.tg_run_clr = 0;
		vclk_vid.en_set = 0;
		vclk_vid.en_clr = 0;

		case (vclk_vid.sm_cur)

			sm_idle :
			begin
				vclk_vid.tg_run_clr = 1;
				vclk_vid.sm_nxt = sm_idle;
			end

			// Start of frame
			sm_sof :
			begin
				// Are we locked?
				if (vclk_vid.lock)
					vclk_vid.sm_nxt = sm_lock;

				else
				begin
					vclk_vid.tg_run_clr = 1;
					vclk_vid.sm_nxt = sm_mid;
				end
			end

			// Midpoint
			sm_mid :
			begin
				// Wait till the FIFO has reached the midpoint
				if (vclk_fifo.mid)
				begin
					vclk_vid.tg_run_set = 1;
					vclk_vid.sm_nxt = sm_vs;
				end

				else
					vclk_vid.sm_nxt = sm_mid;
			end

			// Vsync
			sm_vs :
			begin
				// Wait for new frame
				if (vclk_vid.vs_re)
				begin
					// Enable video
					vclk_vid.en_set = 1;
					vclk_vid.sm_nxt = sm_lock;
				end

				else
					vclk_vid.sm_nxt = sm_vs;
			end 

			// Lock
			sm_lock :
			begin
				if (vclk_vid.lock)
					vclk_vid.sm_nxt = sm_lock;
				else
					vclk_vid.sm_nxt = sm_idle;
			end

			default :
				vclk_vid.sm_nxt = sm_idle;
		endcase
	end

// Timing generator run
	always_ff @ (posedge VID_CLK_IN)
	begin
		// Clear
		if (vclk_vid.tg_run_clr || vclk_vid.lock_fe)
			vclk_vid.tg_run <= 0;
		
		// Set
		else if (vclk_vid.tg_run_set)
			vclk_vid.tg_run <= 1;
	end

// The video data path has three clocks latency.
// The vsync and hsync are delayed to compensate for the delay.
	always_ff @ (posedge VID_CLK_IN)
	begin
		// Clock enable
		if (VID_CKE_IN)
		begin
			vclk_vid.vs <= {vclk_vid.vs[0+:$size(vclk_vid.vs)-1], VID_VS_IN};
			vclk_vid.hs <= {vclk_vid.hs[0+:$size(vclk_vid.hs)-1], VID_HS_IN};
		end
	end

// VS edge detector
    prt_dp_lib_edge
    VID_VS_EDGE_INST
    (
        .CLK_IN    (VID_CLK_IN),      	// Clock
        .CKE_IN    (VID_CKE_IN),       	// Clock enable
        .A_IN      (vclk_vid.vs[0]),	// Input
        .RE_OUT    (vclk_vid.vs_re),    // Rising edge
        .FE_OUT    () 				  	// Falling edge
    );

// Enable
	always_ff @ (posedge VID_CLK_IN)
	begin
		// Enable
		if (VID_CKE_IN)
		begin
			// Run
			if (vclk_vid.run)
			begin		
				// Clear
				if (vclk_vid.en_clr)
					vclk_vid.en <= 0;

				// Set
				else if (vclk_vid.en_set)
					vclk_vid.en <= 1;
			end

			else
				vclk_vid.en <= 0;
		end
	end

// Lock
	always_ff @ (posedge VID_CLK_IN)
	begin
		// Enable
		if (VID_CKE_IN)
		begin
			// Run
			if (vclk_vid.run)
			begin
				// Set
				if (vclk_vid.en_set) 
					vclk_vid.lock <= 1;

				// Clear
				else if (vclk_fifo.rd && (vclk_fifo.ep || vclk_fifo.fl))
					vclk_vid.lock <= 0;
			end

			else
				vclk_vid.lock <= 0;
		end
	end

// Lock edge detector
    prt_dp_lib_edge
    VID_LOCK_EDGE_INST
    (
        .CLK_IN    (VID_CLK_IN),      	// Clock
        .CKE_IN    (1'b1),       		// Clock enable
        .A_IN      (vclk_vid.lock),		// Input
        .RE_OUT    (),    				// Rising edge
        .FE_OUT    (vclk_vid.lock_fe) 	// Falling edge
    );

// Outputs
	assign TG_RUN_OUT 	= vclk_vid.tg_run;

	generate
		for (i = 0; i < P_PPC; i++)
		begin : gen_vid_out
			assign {VID_B_OUT[(i*P_BPC)+:P_BPC], VID_R_OUT[(i*P_BPC)+:P_BPC], VID_G_OUT[(i*P_BPC)+:P_BPC]} = vclk_fifo.dout[(i*3*P_BPC)+:(3*P_BPC)];
		end
	endgenerate

	assign VID_VS_OUT 		= (vclk_vid.en) ? vclk_vid.vs[$size(vclk_vid.vs)-1] : 0;
	assign VID_HS_OUT 		= (vclk_vid.en) ? vclk_vid.hs[$size(vclk_vid.hs)-1] : 0;
	assign VID_DE_OUT 		= (vclk_vid.en) ? vclk_fifo.de : 0;
	assign STA_LOCK_OUT 	= vclk_vid.lock;
	assign STA_MAX_WRDS_OUT	= vclk_fifo.max_wrds;
	assign STA_MIN_WRDS_OUT	= vclk_fifo.min_wrds;

endmodule
