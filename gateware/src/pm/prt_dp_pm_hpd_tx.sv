/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP PM HPD TX
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

module prt_dp_pm_hpd_tx
#(
    // Simulation
    parameter P_SIM         = 0          // Simulation parameter
)
(
    // Reset and clock
    input wire              RST_IN,
    input wire              CLK_IN,

    // Local bus interface
    prt_dp_lb_if.lb_in      LB_IF,

    // Beat
    input wire              BEAT_IN,    // Beat 1 MHz

    // HPD
    input wire              HPD_IN,     // HPD in

    // IRQ
    output wire             IRQ_OUT     // Interrupt
);

// Local parameters
localparam P_HPD_CNT_VAL        = P_SIM ? 100 : 1;
localparam P_CTL_RUN 		    = 0;
localparam P_CTL_IE 		    = 1;
localparam P_CTL_HPD_FORCE      = 2;
localparam P_CTL_WIDTH 	        = 3;

localparam P_STA_IRQ 	        = 0;
localparam P_STA_HPD_IN         = 1;
localparam P_STA_HPD_UNPLUG 	= 2;
localparam P_STA_HPD_PLUG 	    = 3;
localparam P_STA_HPD_PULSE 	    = 4;
localparam P_STA_WIDTH          = 5;

localparam P_UNPLUG_THRES       = 'd2000;     // 2 ms
localparam P_PLUG_THRES         = 'd250;      // 250 us
localparam P_PULSE_THRES        = 'd500;      // 500 us

// State machine
enum {
	sm_rst, sm_unplug_init, sm_unplug, sm_plug_init, sm_plug, sm_pulse_init, sm_pulse
} clk_sm_cur, clk_sm_nxt;

// Structure
typedef struct {
    logic   [1:0]               adr;
    logic                       wr;
    logic                       rd;
    logic   [31:0]              din;
    logic   [31:0]              dout;
    logic                       vld;
} lb_struct;

typedef struct {
	logic	[P_CTL_WIDTH-1:0]	r;					// Register
	logic					    sel;				// Select
	logic					    run;			    // Run
	logic					    ie;			        // Interrupt enable
    logic                       hpd_force;          // Force HPD
} ctl_struct;

typedef struct {
	logic	[P_STA_WIDTH-1:0]	r;					// Register
	logic					    sel;				// Select
    logic                       irq;                // Interrupt
} sta_struct;

typedef struct {
    logic   [10:0]              cnt;        // The maximum value is 2 ms. The counter runs at 1 us.
    logic                       cnt_clr;
    logic                       cnt_inc;
    logic                       unplug_thres;
    logic                       plug_thres;
    logic                       pulse_thres;
    logic                       unplug;
    logic                       unplug_set;
    logic                       plug;
    logic                       plug_set;
    logic                       pulse;
    logic                       pulse_set;
} hpd_struct;

// Signals
logic               clk_beat_re;
logic               clk_hpd_in;
lb_struct           clk_lb;         // Local bus
ctl_struct          clk_ctl;
sta_struct          clk_sta;
hpd_struct          clk_hpd;

// Logic

/*
    Registers
*/
// Local bus inputs
    always_ff @ (posedge RST_IN, posedge CLK_IN)
    begin
        if (RST_IN)
        begin
            clk_lb.adr      <= 0;
            clk_lb.wr       <= 0;
            clk_lb.rd       <= 0;
            clk_lb.din      <= 0;
        end

        else
        begin
            clk_lb.adr      <= LB_IF.adr;
            clk_lb.rd       <= LB_IF.rd;
            clk_lb.wr       <= LB_IF.wr;
            clk_lb.din      <= LB_IF.din;
        end
    end

// Address selector
// Must be combinatorial
    always_comb
    begin
        // Default
        clk_ctl.sel  = 0;
        clk_sta.sel  = 0;

        case (clk_lb.adr)
            'd0 : clk_ctl.sel = 1;
            'd1 : clk_sta.sel = 1;
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
        // Reset
        if (RST_IN)
            clk_ctl.r <= 0;

        else
        begin
            // Write
            if (clk_ctl.sel && clk_lb.wr)
                clk_ctl.r <= clk_lb.din[$size(clk_ctl.r)-1:0];
        end
    end

    assign clk_ctl.run          = clk_ctl.r[P_CTL_RUN];
    assign clk_ctl.ie           = clk_ctl.r[P_CTL_IE];
    assign clk_ctl.hpd_force    = clk_ctl.r[P_CTL_HPD_FORCE];

// Status interrupt
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_ctl.run)
        begin
            // Interrupt enable
            if (clk_ctl.ie)
            begin
                // Set
                // by any HPD event
                // The state machine runs at the beat.
                // To prevent a race condition between the set and the clear
                // the interrupt is only set at the beat rising edge.
                if (clk_beat_re && (clk_sm_cur != sm_rst) && (clk_hpd.unplug_set || clk_hpd.plug_set || clk_hpd.pulse_set))
                    clk_sta.irq <= 1;

                // Clear
                // When the status register is written
                else if (clk_sta.sel && clk_lb.wr && clk_lb.din[P_STA_IRQ])
                    clk_sta.irq <= 0;
            end
        end

        else
            clk_sta.irq <= 0;
    end

// HPD Plug
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_ctl.run)
        begin
            // Set
            if (clk_hpd.plug_set)
                clk_hpd.plug <= 1;

            // Clear
            else if (clk_sta.sel && clk_lb.wr && clk_lb.din[P_STA_HPD_PLUG])
                clk_hpd.plug <= 0;
        end

        // Idle
        else
            clk_hpd.plug <= 0;
    end

// HPD Unplug
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_ctl.run)
        begin
            // Set
            if (clk_hpd.unplug_set)
                clk_hpd.unplug <= 1;

            // Clear
            else if (clk_sta.sel && clk_lb.wr && clk_lb.din[P_STA_HPD_UNPLUG])
                clk_hpd.unplug <= 0;
        end

        // Idle
        else
            clk_hpd.unplug <= 0;
    end

// HPD Pulse
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_ctl.run)
        begin
            // Clear
            // When the status register is written
            if (clk_sta.sel && clk_lb.wr && clk_lb.din[P_STA_HPD_PULSE])
                clk_hpd.pulse <= 0;

            // Set
            else if (clk_hpd.pulse_set)
                clk_hpd.pulse <= 1;
        end

        // Idle
        else
            clk_hpd.pulse <= 0;
    end

// Status register
	assign clk_sta.r[P_STA_IRQ]        = clk_sta.irq;
	assign clk_sta.r[P_STA_HPD_IN]     = clk_hpd_in;
	assign clk_sta.r[P_STA_HPD_UNPLUG] = clk_hpd.unplug;
	assign clk_sta.r[P_STA_HPD_PLUG]   = clk_hpd.plug;
	assign clk_sta.r[P_STA_HPD_PULSE]  = clk_hpd.pulse;

// Beat rising edge
	prt_dp_lib_edge
	BEAT_EDGE_INST
	(
		.CLK_IN		(CLK_IN),			// Clock
		.CKE_IN		(1'b1),				// Clock enable
		.A_IN		(BEAT_IN),			// Input
		.RE_OUT		(clk_beat_re),		// Rising edge
		.FE_OUT		()					// Falling edge
	);

// HPD register
    always_ff @ (posedge CLK_IN)
    begin
        // Force HPD
        if (clk_ctl.hpd_force)
            clk_hpd_in <= 1;
        
        else
            clk_hpd_in <= HPD_IN;
    end

// State machine
    always_ff @ (posedge RST_IN, posedge CLK_IN)
    begin
        // Reset
        if (RST_IN)
            clk_sm_cur <= sm_rst;

        else
        begin
            // Run
            if (clk_ctl.run)
            begin
                if (clk_beat_re)
                    clk_sm_cur <= clk_sm_nxt;
            end

            else
                clk_sm_cur <= sm_rst;
        end
    end

// State machine decoder
    always_comb
    begin
        // Default
        clk_hpd.cnt_clr         = 0;
        clk_hpd.cnt_inc         = 0;
        clk_hpd.unplug_set      = 0;
        clk_hpd.plug_set        = 0;
        clk_hpd.pulse_set       = 0;
        clk_sm_nxt              = sm_rst;

        case (clk_sm_cur)
            sm_rst :
            begin
                clk_hpd.cnt_clr                 = 1;
                clk_hpd.unplug_set              = 1;
                clk_sm_nxt                      = sm_unplug_init;
            end

            // One extra cycle is needed to clear the counter
            sm_unplug_init :
            begin
                clk_sm_nxt                      = sm_unplug;
            end

            sm_unplug :
            begin
                // HPD is high
                if (clk_hpd_in)
                begin
                    if (clk_hpd.plug_thres)
                    begin
                        clk_hpd.plug_set        = 1;    // Plug event
                        clk_hpd.cnt_clr         = 1;
                        clk_sm_nxt              = sm_plug_init;
                    end

                    else
                    begin
                        clk_hpd.cnt_inc         = 1;
                        clk_sm_nxt              = sm_unplug;
                    end
                end

                // HPD is low
                else
                begin
                    clk_hpd.cnt_clr             = 1;
                    clk_sm_nxt                  = sm_unplug_init;
                end
            end

            // One extra cycle is needed to clear the counter
            sm_plug_init :
            begin
                clk_sm_nxt                      = sm_plug;
            end

            sm_plug :
            begin
                // HPD is low
                if (!clk_hpd_in)
                begin
                    // When the HPD is asserted for minimal 0.5 ms,
                    // then this could be a pulse or a unplug event.
                    if (clk_hpd.pulse_thres)    // 0.5 ms
                    begin
                        clk_hpd.cnt_clr         = 1;
                        clk_sm_nxt              = sm_pulse_init;
                    end

                    else
                    begin
                        clk_hpd.cnt_inc         = 1;
                        clk_sm_nxt              = sm_plug;
                    end
                end

                // HPD is high
                else
                begin
                    clk_hpd.cnt_clr             = 1;
                    clk_sm_nxt                  = sm_plug_init;
                end
            end

            // One extra cycle is needed to clear the counter
            sm_pulse_init :
            begin
                clk_sm_nxt                      = sm_pulse;
            end

            sm_pulse :
            begin
                // HPD is low
                if (!clk_hpd_in)
                begin
                    // When the HPD is de-asserted for 2 ms,
                    // then this is an unplug event.
                    if (clk_hpd.unplug_thres) // 2 ms
                    begin
                        clk_hpd.cnt_clr         = 1;
                        clk_hpd.unplug_set      = 1;
                        clk_sm_nxt              = sm_unplug_init;
                    end

                    else
                    begin
                        clk_hpd.cnt_inc         = 1;
                        clk_sm_nxt              = sm_pulse;
                    end
                end

                // HPD is high
                // When the HPD goes high before the time out,
                // then this is a pulse event.
                else
                begin
                    clk_hpd.pulse_set           = 1;
                    clk_hpd.cnt_clr             = 1;
                    clk_sm_nxt                  = sm_plug_init;
                end
            end

            default : ;
        endcase
    end

// Counter
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_ctl.run)
        begin
            // Enable
            if (clk_beat_re)
            begin
                // Clear
                if (clk_hpd.cnt_clr)
                    clk_hpd.cnt <= 0;

                // Increment
                else if (clk_hpd.cnt_inc)
                    clk_hpd.cnt <= clk_hpd.cnt + P_HPD_CNT_VAL;
            end
        end

        // Idle
        else
            clk_hpd.cnt <= 0;
    end

// Plug threshold
// This flag is asserted when the counter value is 0.25 ms or higher
    always_ff @ (posedge CLK_IN)
    begin
        // The beat clock is 1 us
        if (clk_hpd.cnt >= P_PLUG_THRES)
            clk_hpd.plug_thres <= 1;
        else
            clk_hpd.plug_thres <= 0;
    end

// Unplug threshold
// This flag is asserted when the counter value is 2 ms or higher
    always_ff @ (posedge CLK_IN)
    begin
        // The beat clock is 1 us
        if (clk_hpd.cnt >= P_UNPLUG_THRES)
            clk_hpd.unplug_thres <= 1;
        else
            clk_hpd.unplug_thres <= 0;
    end

// Pulse threshold
// This flag is asserted when the counter value is 0.5 ms or higher
    always_ff @ (posedge CLK_IN)
    begin
        // The beat clock is 1 us
        if (clk_hpd.cnt >= P_PULSE_THRES)
            clk_hpd.pulse_thres <= 1;
        else
            clk_hpd.pulse_thres <= 0;
    end

// Outputs
    assign LB_IF.dout   = clk_lb.dout;
    assign LB_IF.vld    = clk_lb.vld;
    assign IRQ_OUT      = clk_sta.irq;

endmodule

`default_nettype wire
