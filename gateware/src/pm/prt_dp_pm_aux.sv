/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP PM AUX
    (c) 2021 - 2025 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
	v1.1 - Added RX input filter
	v1.2 - Improved RX stability

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
module prt_dp_pm_aux
#(
     // System
    parameter              	P_VENDOR = "none",  // Vendor - "AMD", "ALTERA" or "LSC"
	parameter 				P_SIM = 0
)
(
	// Reset and clock
	input wire 				RST_IN,
	input wire 				CLK_IN,

    // Local bus interface
    prt_dp_lb_if.lb_in      LB_IF,         

	// Beat
 	input wire 				BEAT_IN,		// Beat 1 MHz

	// AUX
 	output wire 			AUX_EN_OUT,		// Enable
 	output wire 			AUX_TX_OUT,		// Transmit
 	input wire 				AUX_RX_IN,		// Receive

    // Interrupt
    output wire             IRQ_OUT        // Interrupt
);

// Localparam
localparam P_FIFO_WRDS	        = 32;
localparam P_FIFO_ADR	        = $clog2(P_FIFO_WRDS);

// Control register bit locations
localparam P_CTL_RUN 		    = 0;
localparam P_CTL_IE 		    = 1;
localparam P_CTL_MSG_SEND 	    = 2;
localparam P_CTL_MSG_TO 	    = 3;
localparam P_CTL_TST 		    = 4;
localparam P_CTL_WIDTH 	        = 5;

// Status register bit locations
localparam P_STA_IRQ		    = 0;	// Interrupt
localparam P_STA_MSG_DONE		= 1;	// Message done
localparam P_STA_MSG_TO			= 2;	// Message time out
localparam P_STA_MSG_NEW		= 3;
localparam P_STA_MSG_ERR		= 4;
localparam P_STA_TX_FIFO_EP 	= 5;
localparam P_STA_TX_FIFO_FL 	= 6;
localparam P_STA_RX_LOCKED 		= 7;
localparam P_STA_RX_FIFO_EP 	= 8;
localparam P_STA_RX_FIFO_FL 	= 9;
localparam P_STA_RX_FIFO_WRDS 	= 10;
localparam P_STA_WIDTH          = 16;

localparam P_RX_AUX_SMP_CNT		= (P_SIM) ? 'd9 : 'd24;
localparam P_TO_VAL             = 'd400;    // time out 400 us

// Typedef
typedef enum {
	tx_sm_idle, tx_sm_en, tx_sm_run, tx_sm_re, tx_sm_fe, tx_sm_stp1, tx_sm_stp2, tx_sm_stp3, tx_sm_stp4, tx_sm_tst1, tx_sm_tst2
} tx_sm_state;

typedef enum {
	rx_sm_rst, rx_sm_idle, rx_sm_sync, rx_sm_act, rx_sm_wr
} rx_sm_state;

// Structure
typedef struct {
    logic   [1:0]               adr;
    logic                       wr;
    logic                       rd;
    logic   [31:0]              din;
    logic   [31:0]              dout;
    logic                      	vld;
} lb_struct;

typedef struct {
	logic	[P_CTL_WIDTH-1:0]   r;					// Register
	logic					    sel;				// Select
	logic					    run;				// Run
	logic					    ie;					// Interrupt enable
	logic					    msg_send;			// Message send
	logic					    msg_send_clr;		// Message send clear
	logic					    msg_to;				// Message time out
	logic					    msg_to_clr;			// Message time out clear
	logic					    tst;				// AUX test pattern
} ctl_struct;

typedef struct {
	logic	[P_STA_WIDTH-1:0]	r;					// Register
	logic					    sel;				// Select
    logic                       irq;                // Interrupt
	logic					    msg_done;			// Message done
	logic					    msg_done_set;		// Message done set
	logic					    msg_new;			// Message new
	logic					    msg_new_set;		// Message new set
	logic					    msg_err;			// Message corrupted
	logic					    msg_err_set;		// Message corrupted set
	logic					    msg_to;				// Message time out
	logic					    to_en;				// Time out enable
	logic					    to_en_clr;
	logic					    to_en_set;
	logic	[8:0]			    to_cnt;
	logic					    to;					// Time out
	logic					    to_re;				// Time out rising edge
} sta_struct;

typedef struct {
	logic						sel;
	logic						clr;
	logic						wr;
	logic	[8:0]				din;
	logic						rd;
	logic	[8:0]				dout;
	logic						de;
	logic	[P_FIFO_ADR:0]		wrds;
	logic						ep;
	logic						fl;
} tx_fifo_struct;

typedef struct {
	logic						sel;
	logic						clr;
	logic						wr;
	logic	[7:0]				din;
	logic						rd;
	logic	[7:0]				dout;
	logic						de;
	logic	[P_FIFO_ADR:0]		wrds;
	logic						ep;
	logic						fl;
} rx_fifo_struct;

typedef struct {
	tx_sm_state					sm_cur;
	tx_sm_state					sm_nxt;
	logic						en;			// Enable
	logic						en_clr;		// Enable clear
	logic						en_set;		// Enable set
	logic						tx;			// TX
	logic						tx_clr;		// TX clear
	logic						tx_set;		// TX set
	logic						beat_re;
	logic						beat_fe;
	logic	[7:0]				shft;
	logic						shft_ld;
	logic						shft_nxt;
	logic						shft_out;
	logic	[4:0]				shft_cnt;
	logic						shft_end;
} tx_aux_struct;

typedef struct {
	rx_sm_state					sm_cur;
	rx_sm_state					sm_nxt;
	logic						run;		// Run
	logic 	[1:0]				flt_cnt;
	logic 						flt_shft;
	logic 	[4:0]				flt;
	logic						rx;			// RX
	logic						rx_re;		// RX rising edge
	logic						rx_fe;		// RX falling edge
	logic 	[4:0]				smp_cnt;
	logic 						smp_tick;
	logic 						smp_msk;
	logic 						smp;
	logic	[5:0]				rx_pipe;
	logic						stp;
    logic 	[5:0]             	wd_cnt;
    logic                   	wd_end;
    logic                   	wd_end_re;
	logic						locked;			// Locked
	logic						locked_clr;		// Locked
	logic						locked_set;		// Locked
	logic	[3:0]				bit_cnt;
	logic						bit_cnt_ld;
	logic						bit_cnt_dec;
	logic						bit_cnt_end;
	logic	[7:0]				shft;
} rx_aux_struct;

// Signals
lb_struct           clk_lb;         // Local bus
ctl_struct			clk_ctl;		// Control register
sta_struct			clk_sta;		// Status register
tx_aux_struct		clk_tx_aux;		// AUX
rx_aux_struct		clk_rx_aux;		// AUX
tx_fifo_struct		clk_tx_fifo;	// TX fifo
rx_fifo_struct		clk_rx_fifo;	// RX fifo

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
        clk_ctl.sel  	= 0;
        clk_sta.sel  	= 0;
    	clk_tx_fifo.sel = 0;
        clk_rx_fifo.sel = 0;

        case (clk_lb.adr)
            'd0 : clk_ctl.sel 		= 1;
            'd1 : clk_sta.sel 		= 1;
            'd2 : clk_tx_fifo.sel 	= 1;
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

        // Status register
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

			// Clear message send flag
			else if (clk_ctl.msg_send_clr)
				clk_ctl.r[P_CTL_MSG_SEND] <= 0;

			// Clear message time out flag
			else if (clk_ctl.msg_to_clr)
				clk_ctl.r[P_CTL_MSG_TO] <= 0;
		end
	end

// Control register bit locations
	assign clk_ctl.run 			= clk_ctl.r[P_CTL_RUN];			// Run
	assign clk_ctl.ie 			= clk_ctl.r[P_CTL_IE];			// Interrupt enable
	assign clk_ctl.msg_send 	= clk_ctl.r[P_CTL_MSG_SEND];	// Message send
	assign clk_ctl.msg_to 		= clk_ctl.r[P_CTL_MSG_TO];		// Message time out
	assign clk_ctl.tst 			= clk_ctl.r[P_CTL_TST];			// AUX test pattern

// Status register
	assign clk_sta.r[P_STA_IRQ]	                                  = clk_sta.irq;		// Interrupt
	assign clk_sta.r[P_STA_MSG_DONE]	                          = clk_sta.msg_done;	// Message done
	assign clk_sta.r[P_STA_MSG_TO]		                          = clk_sta.msg_to;		// Message time out
	assign clk_sta.r[P_STA_TX_FIFO_EP] 	                          = clk_tx_fifo.ep;
	assign clk_sta.r[P_STA_TX_FIFO_FL] 	                          = clk_tx_fifo.fl;
	assign clk_sta.r[P_STA_RX_LOCKED]	                          = clk_rx_aux.locked;
	assign clk_sta.r[P_STA_MSG_NEW]		                          = clk_sta.msg_new;	// Message new
	assign clk_sta.r[P_STA_MSG_ERR]	   	                          = clk_sta.msg_err;	// Message error
	assign clk_sta.r[P_STA_RX_FIFO_EP] 	                          = clk_rx_fifo.ep;
	assign clk_sta.r[P_STA_RX_FIFO_FL] 	                          = clk_rx_fifo.fl;
	assign clk_sta.r[P_STA_RX_FIFO_WRDS+:$size(clk_rx_fifo.wrds)] =	clk_rx_fifo.wrds;

// Interrupt
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_ctl.run)
        begin
            // Set
            // A new message, message done and time out can raise an interrupt
            if (clk_ctl.ie && (clk_sta.msg_new_set || clk_sta.msg_done_set || clk_sta.to_re))
                clk_sta.irq <= 1;

            // Clear
            // When the status register is written
            else if (clk_sta.sel && clk_lb.wr && clk_lb.din[P_STA_IRQ])
                clk_sta.irq <= 0;
        end

        else
            clk_sta.irq <= 0;
    end

// Message done
// This bit is set after the message was transmitted
// It is cleared by writing to this bit in the status register
	always_ff @ (posedge CLK_IN)
	begin
		// Run
		if (clk_ctl.run)
		begin
			// Set
            // By the state machine
			if (clk_sta.msg_done_set)
				clk_sta.msg_done <= 1;

			// Clear
 			// When the status register is written
            else if (clk_sta.sel && clk_lb.wr && clk_lb.din[P_STA_MSG_DONE])				
            	clk_sta.msg_done <= 0;
		end

		// Idle
		else
			clk_sta.msg_done <= 0;
	end

// Message new
// This bit is set when a new message is available
// It is cleared by writing to this bit in the status register
	always_ff @ (posedge CLK_IN)
	begin
		// Run
		if (clk_ctl.run)
		begin
			// Set
            // By the state machine
			if (clk_sta.msg_new_set)
				clk_sta.msg_new <= 1;

			// Clear
            // When the status register is written
			else if (clk_sta.sel && clk_lb.wr && clk_lb.din[P_STA_MSG_NEW])
				clk_sta.msg_new <= 0;
		end

		// Idle
		else
			clk_sta.msg_new <= 0;
	end

// Message error
// This bit is set when the RX starts to write a new message in the fifo
// and the RX fifo still contains data.
// It is cleared by writing to this bit in the status register
	always_ff @ (posedge CLK_IN)
	begin
		// Run
		if (clk_ctl.run)
		begin
			// Set
            // By the state machine
			if (clk_sta.msg_err_set)
				clk_sta.msg_err <= 1;

			// Clear
            // When the status register is written
			else if (clk_sta.sel && clk_lb.wr && clk_lb.din[P_STA_MSG_ERR])
				clk_sta.msg_err <= 0;
		end

		// Idle
		else
			clk_sta.msg_err <= 0;
	end

// Message time out
// This process check if the TX receives a message within the time out period.
// If not, then this flag is set.
	always_ff @ (posedge CLK_IN)
	begin
		// Run
		if (clk_ctl.run)
		begin
			// Set
			if (clk_sta.to_re)
				clk_sta.msg_to <= 1;

			// Clear
            // When the status register is written
			else if (clk_sta.sel && clk_lb.wr && clk_lb.din[P_STA_MSG_TO])
				clk_sta.msg_to <= 0;
		end

		// Idle
		else
			clk_sta.msg_to <= 0;
	end

// Time out enable
	always_ff @ (posedge CLK_IN)
	begin
		// Run
		if (clk_ctl.run)
		begin
			// Set
			// by TX state machine
			if (clk_sta.to_en_set)
				clk_sta.to_en <= 1;

			// Clear
			// by RX state machine or when the time out occured
			else if (clk_sta.to_en_clr || clk_sta.to_re)
				clk_sta.to_en <= 0;
		end

		// Idle
		else
			clk_sta.to_en <= 0;
	end

// Time out counter
	always_ff @ (posedge CLK_IN)
	begin
		// Enable
		if (clk_sta.to_en)
		begin
			// Clear
			if (clk_sta.to_en_set)
				clk_sta.to_cnt <= 0;

			// Increment
			else if (clk_tx_aux.beat_re && !clk_sta.to)
				clk_sta.to_cnt <= clk_sta.to_cnt + 'd1;
		end

		else
			clk_sta.to_cnt <= 0;
	end

// Time out
// The time out counter is incremented at the beat rate, which equals to 1 us.
// The DP spec says the time out is 400 us.
	always_comb
	begin
		if (clk_sta.to_cnt == P_TO_VAL)
			clk_sta.to = 1;
		else
			clk_sta.to = 0;
	end

// Time out rising edge
	prt_dp_lib_edge
	STA_TO_EDGE_INST
	(
		.CLK_IN		(CLK_IN),			// Clock
		.CKE_IN		(clk_ctl.run),		// Clock enable
		.A_IN		(clk_sta.to),		// Input
		.RE_OUT		(clk_sta.to_re),	// Rising edge
		.FE_OUT		()					// Falling edge
	);


/*
	TX FIFO
*/
	prt_dp_lib_fifo_sc
	#(
		.P_VENDOR		(P_VENDOR),			// Vendor
		.P_MODE         ("single"),			// "single" or "burst"
		.P_RAM_STYLE	("distributed"),	// "distributed", "block" or "ultra"
		.P_ADR_WIDTH 	(P_FIFO_ADR),
		.P_DAT_WIDTH 	(9)
	)
	TX_FIFO_INST
	(
		// Clocks and reset
		.RST_IN		(RST_IN),				// Reset
		.CLK_IN		(CLK_IN),				// Clock
		.CLR_IN		(clk_tx_fifo.clr),		// Clear

		// Write
		.WR_IN		(clk_tx_fifo.wr),		// Write in
		.DAT_IN		(clk_tx_fifo.din),		// Write data

		// Read
		.RD_EN_IN	(1'b1),					// Read enable in
		.RD_IN		(clk_tx_fifo.rd),		// Read in
		.DAT_OUT	(clk_tx_fifo.dout),		// Data out
		.DE_OUT		(clk_tx_fifo.de),		// Data enable

		// Status
		.WRDS_OUT	(clk_tx_fifo.wrds),		// Used words
		.EP_OUT		(clk_tx_fifo.ep),		// Empty
		.FL_OUT		(clk_tx_fifo.fl)		// Full
	);

// Clear
    always_ff @ (posedge CLK_IN)
    begin
        if (clk_ctl.run)
            clk_tx_fifo.clr <= 0;
        else
            clk_tx_fifo.clr <= 1;
    end

// Write
	always_comb
	begin
		if (clk_tx_fifo.sel && clk_lb.wr)
			clk_tx_fifo.wr = 1;
		else
			clk_tx_fifo.wr = 0;
	end

// Write data
	assign clk_tx_fifo.din = clk_lb.din[$size(clk_tx_fifo.din)-1:0];


/*
	AUX TX
*/

// State machine
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
			clk_tx_aux.sm_cur <= tx_sm_idle;
	
		else
		begin			
	        // Run
	        if (clk_ctl.run)
				clk_tx_aux.sm_cur <= clk_tx_aux.sm_nxt;
	        else
				clk_tx_aux.sm_cur <= tx_sm_idle;
		end
	end

// State machine decoder
	always_comb
	begin
		// Default
		clk_tx_aux.sm_nxt 			= tx_sm_idle;
		clk_tx_aux.en_set 			= 0;
		clk_tx_aux.en_clr 			= 0;
		clk_tx_aux.tx_set 			= 0;
		clk_tx_aux.tx_clr 			= 0;
		clk_tx_aux.shft_ld 			= 0;
		clk_tx_aux.shft_nxt			= 0;
		clk_tx_fifo.rd 				= 0;
		clk_ctl.msg_send_clr 		= 0;
		clk_ctl.msg_to_clr 			= 0;
		clk_sta.msg_done_set		= 0;
		clk_sta.to_en_set			= 0;

		case (clk_tx_aux.sm_cur)

			// Idle
			tx_sm_idle :
			begin
				// Enable TX test output?
				if (clk_ctl.tst)
				begin
					clk_tx_aux.en_set 		= 1;		// Enable output
					clk_tx_aux.sm_nxt 		= tx_sm_tst1;
				end

				// Is there a message ready to send?
				else if (clk_ctl.msg_send)
				begin
					clk_ctl.msg_send_clr	= 1;			// Clear message send flag in control register
					clk_tx_aux.sm_nxt 		= tx_sm_en;
				end

				else
					clk_tx_aux.sm_nxt 		= tx_sm_idle;
			end

			// Enable
			tx_sm_en :
			begin
				// Wait for falling edge
				if (clk_tx_aux.beat_fe)
				begin
					clk_tx_aux.en_set = 1;		// Enable output
					clk_tx_aux.sm_nxt = tx_sm_run;
				end

				else
					clk_tx_aux.sm_nxt = tx_sm_en;
			end

			// Run
			tx_sm_run :
			begin
				// FIFO data
				if (clk_tx_fifo.de)
				begin
					clk_tx_fifo.rd = 1;			// Read next data

					// Stop token
					if (clk_tx_fifo.dout[8])
						clk_tx_aux.sm_nxt = tx_sm_stp1;

					// Other data
					else
					begin
						clk_tx_aux.shft_ld = 1;
						clk_tx_aux.sm_nxt = tx_sm_re;
					end
				end

				// FIFO empty
				else if (clk_tx_fifo.ep && clk_tx_aux.beat_re)
				begin
					clk_tx_aux.en_clr 		= 1;			// Clear output
					clk_sta.msg_done_set 	= 1;			// Set message done bit

					// Is the message time out flag set?
					if (clk_ctl.msg_to)
					begin
						clk_sta.to_en_set	= 1;			// Start time out
						clk_ctl.msg_to_clr	= 1;			// Clear message time out flag
					end
					clk_tx_aux.sm_nxt 		= tx_sm_idle;
				end

				else
					clk_tx_aux.sm_nxt = tx_sm_run;
			end

			// Beat Rising edge
			tx_sm_re :
			begin
				// Wait for rising edge
				if (clk_tx_aux.beat_re)
				begin
					// On a rising edge a 1 will set the output
					// and a 0 will clear the output
					if (clk_tx_aux.shft_out)
						clk_tx_aux.tx_set = 1;
					else
						clk_tx_aux.tx_clr = 1;

					clk_tx_aux.sm_nxt = tx_sm_fe;
				end

				else
					clk_tx_aux.sm_nxt = tx_sm_re;
			end

			// Beat Falling edge
			tx_sm_fe :
			begin
				// Wait for falling edge
				if (clk_tx_aux.beat_fe)
				begin
					// On a falling edge a 1 will clear the output
					// and a 0 will set the output
					if (clk_tx_aux.shft_out)
						clk_tx_aux.tx_clr = 1;
					else
						clk_tx_aux.tx_set = 1;

					if (clk_tx_aux.shft_end)
						clk_tx_aux.sm_nxt = tx_sm_run;
					else
					begin
						clk_tx_aux.shft_nxt = 1;
						clk_tx_aux.sm_nxt = tx_sm_re;
					end
				end
				else
					clk_tx_aux.sm_nxt = tx_sm_fe;
			end

			tx_sm_stp1 :
			begin
				// Wait for rising edge
				if (clk_tx_aux.beat_re)
				begin
					clk_tx_aux.tx_set = 1;
					clk_tx_aux.sm_nxt = tx_sm_stp2;
				end
				else
					clk_tx_aux.sm_nxt = tx_sm_stp1;
			end

			tx_sm_stp2 :
			begin
				// Wait for rising edge
				if (clk_tx_aux.beat_re)
					clk_tx_aux.sm_nxt = tx_sm_stp3;
				else
					clk_tx_aux.sm_nxt = tx_sm_stp2;
			end

			tx_sm_stp3 :
			begin
				// Wait for rising edge
				if (clk_tx_aux.beat_re)
				begin
					clk_tx_aux.tx_clr = 1;
					clk_tx_aux.sm_nxt = tx_sm_stp4;
				end
				else
					clk_tx_aux.sm_nxt = tx_sm_stp3;
			end

			tx_sm_stp4 :
			begin
				// Wait for rising edge
				if (clk_tx_aux.beat_re)
					clk_tx_aux.sm_nxt = tx_sm_run;
				else
					clk_tx_aux.sm_nxt = tx_sm_stp4;
			end

			tx_sm_tst1 :
			begin
				// Wait for rising edge
				if (clk_tx_aux.beat_re)
				begin
					clk_tx_aux.tx_set = 1;
					clk_tx_aux.sm_nxt = tx_sm_tst2;
				end
				else
					clk_tx_aux.sm_nxt = tx_sm_tst1;
			end

			tx_sm_tst2 :
			begin
				// Wait for rising edge
				if (clk_tx_aux.beat_fe)
				begin
					clk_tx_aux.tx_clr = 1;
					clk_tx_aux.sm_nxt = tx_sm_tst1;
				end
				else
					clk_tx_aux.sm_nxt = tx_sm_tst2;
			end

			default :
				clk_tx_aux.sm_nxt = tx_sm_idle;

		endcase
	end

// Enable Output register
	always_ff @ (posedge CLK_IN)
	begin
		// Run
		if (clk_ctl.run)
		begin
			// Set
			if (clk_tx_aux.en_set)
				clk_tx_aux.en <= 1;

			// Clear
			else if (clk_tx_aux.en_clr)
				clk_tx_aux.en <= 0;
		end

		// Idle
		else
			clk_tx_aux.en <= 0;
	end

// TX Output register
	always_ff @ (posedge CLK_IN)
	begin
		// Run
		if (clk_ctl.run)
		begin
			// Set
			if (clk_tx_aux.tx_set)
				clk_tx_aux.tx <= 1;

			// Clear
			else if (clk_tx_aux.tx_clr)
				clk_tx_aux.tx <= 0;
		end

		// Idle
		else
			clk_tx_aux.tx <= 0;
	end

// Beat edge
	prt_dp_lib_edge
	AUX_BEAT_EDGE_INST
	(
		.CLK_IN		(CLK_IN),				// Clock
		.CKE_IN		(clk_ctl.run),			// Clock enable
		.A_IN		(BEAT_IN),				// Input
		.RE_OUT		(clk_tx_aux.beat_re),	// Rising edge
		.FE_OUT		(clk_tx_aux.beat_fe)	// Falling edge
	);

// Shift register
	always_ff @ (posedge CLK_IN)
	begin
		// Load
		if (clk_tx_aux.shft_ld)
			clk_tx_aux.shft <= clk_tx_fifo.dout[7:0];

		// Shift
		else if (clk_tx_aux.shft_nxt)
			clk_tx_aux.shft <= {clk_tx_aux.shft[6:0], 1'b0};
	end

assign clk_tx_aux.shft_out = clk_tx_aux.shft[7];

// Shift counter
	always_ff @ (posedge CLK_IN)
	begin
		// Load
		if (clk_tx_aux.shft_ld)
			clk_tx_aux.shft_cnt <= 'd7;

		// Decrememt
		else if (clk_tx_aux.shft_nxt)
			clk_tx_aux.shft_cnt <= clk_tx_aux.shft_cnt - 'd1;
	end

// Shift counter end
	always_comb
	begin
		if (clk_tx_aux.shft_cnt == 0)
			clk_tx_aux.shft_end = 1;
		else
			clk_tx_aux.shft_end = 0;
	end


/*
	RX FIFO
*/
	prt_dp_lib_fifo_sc
	#(
		.P_VENDOR		(P_VENDOR),			// Vendor
		.P_MODE         ("single"),			// "single" or "burst"
		.P_RAM_STYLE	("distributed"),	// "distributed", "block" or "ultra"
		.P_ADR_WIDTH 	(P_FIFO_ADR),
		.P_DAT_WIDTH 	(8)
	)
	RX_FIFO_INST
	(
		// Clocks and reset
		.RST_IN		(RST_IN),				// Reset
		.CLK_IN		(CLK_IN),				// Clock
		.CLR_IN		(clk_rx_fifo.clr),		// Clear

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

// Data in
	assign clk_rx_fifo.din = clk_rx_aux.shft;

// Read
	always_comb
	begin
		if (clk_rx_fifo.sel && clk_lb.rd)
			clk_rx_fifo.rd = 1;
		else
			clk_rx_fifo.rd = 0;
	end


/*
	AUX RX
*/

// State machine
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
		// Reset
		if (RST_IN)
				clk_rx_aux.sm_cur <= rx_sm_rst;
		else
		begin			
			// Run
			if (clk_ctl.run)
	        begin
				// Reset RX state machine when TX is active
				if (clk_tx_aux.en || clk_rx_aux.wd_end_re)
					clk_rx_aux.sm_cur <= rx_sm_rst;
	            else
				    clk_rx_aux.sm_cur <= clk_rx_aux.sm_nxt;
	        end

			else
				clk_rx_aux.sm_cur <= rx_sm_rst;
		end
	end

// State machine decoder
	always_comb
	begin
		// Default
		clk_rx_aux.sm_nxt 			= rx_sm_idle;
		clk_rx_aux.bit_cnt_ld		= 0;
		clk_rx_aux.bit_cnt_dec		= 0;
		clk_rx_fifo.wr 				= 0;
		clk_rx_aux.locked_clr		= 0;
		clk_rx_aux.locked_set		= 0;
		clk_sta.msg_new_set			= 0;
		clk_sta.msg_err_set			= 0;
		clk_rx_fifo.clr				= 0;
		clk_sta.to_en_clr			= 0;

		case (clk_rx_aux.sm_cur)

			// Reset
			rx_sm_rst :
			begin
				clk_rx_aux.locked_clr		= 1;		// Clear lock
				clk_rx_aux.sm_nxt 			= rx_sm_idle;
			end

			// Idle
			rx_sm_idle :
			begin
				// Wait for rising edge
				if (clk_rx_aux.rx_re)
				begin
					clk_sta.to_en_clr = 1;				// Clear time out
					clk_rx_aux.sm_nxt = rx_sm_sync;
				end
				else
					clk_rx_aux.sm_nxt = rx_sm_idle;
			end

			// Sync
			rx_sm_sync :
			begin
				// Wait for stop condition
				if (clk_rx_aux.stp)
				begin
					// If the RX fifo is not empty at the start of the new message,
					// then set the message corrupted flag.
					if (!clk_rx_fifo.ep)
						clk_sta.msg_err_set = 1;
					clk_rx_fifo.clr		= 1;		// Clear RX fifo
					clk_rx_aux.locked_set = 1;		// Set locked
					clk_rx_aux.bit_cnt_ld = 1;
					clk_rx_aux.sm_nxt = rx_sm_act;
				end

				else
					clk_rx_aux.sm_nxt = rx_sm_sync;
			end

			// Active
			rx_sm_act :
			begin
				// Stop condition
				if (clk_rx_aux.stp)
				begin
					clk_rx_aux.sm_nxt = rx_sm_idle;
					clk_sta.msg_new_set = 1;			// Set new message flag
				end

				// Sample
				else if (clk_rx_aux.smp)
				begin				
					// Have we shifted in all bits?
					// It takes one extra clock for the shift register to update.
					// Therefore we jump to the write state. 
					if (clk_rx_aux.bit_cnt_end)
						clk_rx_aux.sm_nxt = rx_sm_wr;

					else
					begin
						clk_rx_aux.bit_cnt_dec = 1;
						clk_rx_aux.sm_nxt = rx_sm_act;
					end
				end

				else
					clk_rx_aux.sm_nxt = rx_sm_act;
			end

			// Write
			// Write RX data info FIFO
			rx_sm_wr :
			begin
				clk_rx_aux.bit_cnt_ld = 1;
				clk_rx_fifo.wr = 1;
				clk_rx_aux.sm_nxt = rx_sm_act;
			end

			default :
				clk_rx_aux.sm_nxt = rx_sm_idle;

        endcase
	end

// RX filter counter
	always_ff @ (posedge CLK_IN)
	begin
		// Default
		clk_rx_aux.flt_shft <= 0;

		// Run
		if (clk_ctl.run)
		begin
			if (&clk_rx_aux.flt_cnt)
			begin
				clk_rx_aux.flt_shft <= 1;
				clk_rx_aux.flt_cnt <= 0;
			end

			else
				clk_rx_aux.flt_cnt <= clk_rx_aux.flt_cnt + 'd1;
		end

		// Idle
		else
			clk_rx_aux.flt_cnt <= 0;
	end

// RX Input filter
	always_ff @ (posedge CLK_IN)
	begin
		// Shift
		if (clk_rx_aux.flt_shft)
			clk_rx_aux.flt <= {clk_rx_aux.flt[$high(clk_rx_aux.flt)-1:0], AUX_RX_IN};
	end

// RX
generate 
	// In simulation the AUX transactions are running much faster.
	// The filter will break the AUX transaction. 
	// Therefore in simulation, just pass the RX input.
	if (P_SIM)
	begin : gen_sim_rx
		assign clk_rx_aux.rx = AUX_RX_IN;
	end

	// In synthesis use majority voting to filter the RX signal.
	else
	begin
		// Majority voting (LUT)
		always_ff @ (posedge CLK_IN)
		begin
			case (clk_rx_aux.flt)
				'b00000 : clk_rx_aux.rx <= 0;
				'b00001 : clk_rx_aux.rx <= 0;
				'b00010 : clk_rx_aux.rx <= 0;
				'b00011 : clk_rx_aux.rx <= 0;
				'b00100 : clk_rx_aux.rx <= 0;
				'b00101 : clk_rx_aux.rx <= 0;
				'b00110 : clk_rx_aux.rx <= 0;
				'b00111 : clk_rx_aux.rx <= 1;
				'b01000 : clk_rx_aux.rx <= 0;
				'b01001 : clk_rx_aux.rx <= 0;
				'b01010 : clk_rx_aux.rx <= 0;
				'b01011 : clk_rx_aux.rx <= 1;
				'b01100 : clk_rx_aux.rx <= 0;
				'b01101 : clk_rx_aux.rx <= 1;
				'b01110 : clk_rx_aux.rx <= 1;
				'b01111 : clk_rx_aux.rx <= 1;
				'b10000 : clk_rx_aux.rx <= 0;
				'b10001 : clk_rx_aux.rx <= 0;
				'b10010 : clk_rx_aux.rx <= 0;
				'b10011 : clk_rx_aux.rx <= 1;
				'b10100 : clk_rx_aux.rx <= 0;
				'b10101 : clk_rx_aux.rx <= 1;
				'b10110 : clk_rx_aux.rx <= 1;
				'b10111 : clk_rx_aux.rx <= 1;
				'b11000 : clk_rx_aux.rx <= 0;
				'b11001 : clk_rx_aux.rx <= 1;
				'b11010 : clk_rx_aux.rx <= 1;
				'b11011 : clk_rx_aux.rx <= 1;
				'b11100 : clk_rx_aux.rx <= 1;
				'b11101 : clk_rx_aux.rx <= 1;
				'b11110 : clk_rx_aux.rx <= 1;
				'b11111 : clk_rx_aux.rx <= 1;
			endcase
		end
	end
endgenerate

// RX edge
	prt_dp_lib_edge
	RX_AUX_RX_EDGE_INST
	(
		.CLK_IN		(CLK_IN),				// Clock
		.CKE_IN		(clk_rx_aux.run),		// Clock enable
		.A_IN		(clk_rx_aux.rx),		// Input
		.RE_OUT		(clk_rx_aux.rx_re),		// Rising edge
		.FE_OUT		(clk_rx_aux.rx_fe)		// Falling edge
	);

// Run
	always_ff @ (posedge CLK_IN)
	begin
		if (clk_ctl.run && (clk_tx_aux.sm_cur == tx_sm_idle))
			clk_rx_aux.run <= 1;
		else
			clk_rx_aux.run <= 0;
	end

// Sample counter
// This counter is synchronized with the incoming RX signal
    always_ff @ (posedge CLK_IN)
    begin
		// Run
		if (clk_rx_aux.run)
		begin
			// Load
			if ((clk_rx_aux.rx_re || clk_rx_aux.rx_fe) || (clk_rx_aux.smp_cnt == 0))
				clk_rx_aux.smp_cnt <= P_RX_AUX_SMP_CNT;

			// Decrement
			else
				clk_rx_aux.smp_cnt <= clk_rx_aux.smp_cnt - 'd1;
		end

		// Idle
		else
			clk_rx_aux.smp_cnt <= 0;
	end

// Sample Tick
// This signal is asserted in the middle of the eye.
// It's used to sample the RX signal.
    always_ff @ (posedge CLK_IN)
    begin
		if (clk_rx_aux.smp_cnt == P_RX_AUX_SMP_CNT/2)
			clk_rx_aux.smp_tick <= 1;
		else
			clk_rx_aux.smp_tick <= 0;
	end

// Sample mask
// Because the sample clock is trigged at every edge, the clock runs at double the speed of the RX signal.
// The mask blocks the second sample (of the invertered signal)
    always_ff @ (posedge CLK_IN)
    begin
		// Run
		if (clk_rx_aux.run)
		begin
			// The stop condition is used to synchronize the mask.
			if (clk_rx_aux.stp)
				clk_rx_aux.smp_msk <= 0;

			// In the active period the mask signal is toggled at every sample. 
			else if (clk_rx_aux.smp_tick)
				clk_rx_aux.smp_msk <= ~clk_rx_aux.smp_msk;
		end

		// Idle
		else
			clk_rx_aux.smp_msk <= 0;
	end

// Sample
// This signal is asserted when the RX value is sampled
	assign clk_rx_aux.smp = clk_rx_aux.smp_tick && !clk_rx_aux.smp_msk;

// Watchdog
// The RX state machine is reset, when this watchdog counter expires.
// The AUX channel runs at 1 Mbps.
// The beat input frequency is 2 Mhz.
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_rx_aux.run)
        begin
            // Load
            if (clk_rx_aux.rx_re || clk_rx_aux.rx_fe)
                clk_rx_aux.wd_cnt <= '1;

            // Decrement
            // On every incoming beat pulse the watchdog counter is decremented
            else if (clk_tx_aux.beat_re && !clk_rx_aux.wd_end)
                clk_rx_aux.wd_cnt <= clk_rx_aux.wd_cnt - 'd1;
        end

		// Idle
        else
            clk_rx_aux.wd_cnt <= 0;
    end

// Watchdog end
    always_comb
    begin
        if (clk_rx_aux.wd_cnt == 0)
            clk_rx_aux.wd_end = 1;
        else
            clk_rx_aux.wd_end = 0;
    end

// Watchdog end rising end
	prt_dp_lib_edge
	RX_AUX_WD_END_EDGE_INST
	(
		.CLK_IN		(CLK_IN),					 // Clock
		.CKE_IN		(1'b1),						 // Clock enable
		.A_IN		(clk_rx_aux.wd_end),		 // Input
		.RE_OUT		(clk_rx_aux.wd_end_re),	     // Rising edge
		.FE_OUT		()							 // Falling edge
	);

// Bit counter
	always_ff @ (posedge CLK_IN)
	begin
		// Load
		if (clk_rx_aux.bit_cnt_ld)
			clk_rx_aux.bit_cnt <= 'd7;

		// Decrement
		else if (clk_rx_aux.bit_cnt_dec)
			clk_rx_aux.bit_cnt <= clk_rx_aux.bit_cnt - 'd1;
	end

// Bit counter end
	always_comb
	begin
		if (clk_rx_aux.bit_cnt == 0)
			clk_rx_aux.bit_cnt_end = 1;
		else
			clk_rx_aux.bit_cnt_end = 0;
	end

// RX pipe
// To detect a stop condition the sampled RX is shifted into this pipe
    always_ff @ (posedge CLK_IN)
    begin
		// Run
		if (clk_rx_aux.run)
		begin
			// Wait for sample tick
			if (clk_rx_aux.smp_tick)
				clk_rx_aux.rx_pipe <= {clk_rx_aux.rx_pipe[0+:$high(clk_rx_aux.rx_pipe)], clk_rx_aux.rx};
		end

		else
			clk_rx_aux.rx_pipe <= 0;
	end

// Stop condition
	always_ff @ (posedge CLK_IN)
	begin
		// Default
		clk_rx_aux.stp <= 0;

		// Wait for sample tick
		if (clk_rx_aux.smp_tick)
		begin
			// A stop condition consists of four ones, followed by four zeros.
			// However, in case of a misaligned sample clock, there might be a bit missing. 
			// Therefore we check for three bits each. 
			if (clk_rx_aux.rx_pipe == 'b111000)
				clk_rx_aux.stp <= 1;
		end
	end

// Shift register
	always_ff @ (posedge CLK_IN)
	begin
		// Shift
		if (clk_rx_aux.smp)
			clk_rx_aux.shft <= {clk_rx_aux.shft[6:0], clk_rx_aux.rx};
	end

// Locked
// This flag is set when a stop condition is detected after the sync period.
	always_ff @ (posedge CLK_IN)
	begin
		// Clear
		if (clk_rx_aux.locked_clr)
			clk_rx_aux.locked <= 0;

		// Set
		else if (clk_rx_aux.locked_set)
			clk_rx_aux.locked <= 1;
	end

// Outputs
    assign LB_IF.dout   = clk_lb.dout;
    assign LB_IF.vld    = clk_lb.vld;
	assign AUX_EN_OUT 	= clk_tx_aux.en;
	assign AUX_TX_OUT 	= clk_tx_aux.tx;
    assign IRQ_OUT      = clk_sta.irq;

endmodule

`default_nettype wire
