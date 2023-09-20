/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP PM HPD RX
    (c) 2021 - 2023 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Changed naming HPD Pulse to HPD IRQ. Fixed issue with HPD IRQ generation.

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

module prt_dp_pm_hpd_rx
#(
    // Simulation
    parameter               P_SIM = 0          // Simulation parameter
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
    output wire             HPD_OUT,    // HPD in

    // IRQ
    output wire             IRQ_OUT     // Interrupt
);

// Local parameters
localparam P_CTL_RUN 		    = 0;
localparam P_CTL_HPD_UNPLUG     = 1;
localparam P_CTL_HPD_PLUG 	    = 2;
localparam P_CTL_HPD_IRQ 	    = 3;
localparam P_CTL_WIDTH 	        = 4;

localparam P_HMS_VAL            = P_SIM ? 'd10 : 'd2000;    // 2 ms
localparam P_IPW_VAL            = P_SIM ? 'd5 : 'd500;      // 500 us

// State machine
typedef enum {
	sm_rst, sm_idle, sm_irq
} state_type; 

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
	logic					    run;				// Run
	logic					    hpd_unplug;	        // Unplug event
	logic					    hpd_unplug_clr;	    // Unplug event clear
	logic					    hpd_plug;			// Plug event
	logic					    hpd_plug_clr;		// Plug event clear
	logic					    hpd_irq;			// IRQ event
	logic					    hpd_irq_clr;		// IRQ event clear
} ctl_struct;

typedef struct {
	logic	[7:0]	            r;					// Register
	logic					    sel;				// Select
} reg_struct;

typedef struct {
    logic                       pin;
    logic                       pin_set;
    logic                       pin_clr;
    logic   [15:0]              cnt;             
    logic   [15:0]              cnt_in;          
    logic                       cnt_ld;
    logic                       cnt_end;
} hpd_struct;

// Signals
state_type          clk_sm_cur, clk_sm_nxt;
wire                clk_beat_re;
lb_struct           clk_lb;         // Local bus
ctl_struct          clk_ctl;        // Control register
hpd_struct          clk_hpd;

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
        clk_ctl.sel  = 0;

        case (clk_lb.adr)
            'd0 : clk_ctl.sel = 1;
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

            else if (clk_ctl.hpd_unplug_clr)
                clk_ctl.r[P_CTL_HPD_UNPLUG] <= 0;

            else if (clk_ctl.hpd_plug_clr)
                clk_ctl.r[P_CTL_HPD_PLUG] <= 0;

            else if (clk_ctl.hpd_irq_clr)
                clk_ctl.r[P_CTL_HPD_IRQ] <= 0;
        end
    end

    assign clk_ctl.run          = clk_ctl.r[P_CTL_RUN];
    assign clk_ctl.hpd_unplug   = clk_ctl.r[P_CTL_HPD_UNPLUG];
    assign clk_ctl.hpd_plug     = clk_ctl.r[P_CTL_HPD_PLUG];
    assign clk_ctl.hpd_irq      = clk_ctl.r[P_CTL_HPD_IRQ];

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
                clk_sm_cur <= clk_sm_nxt;

            else
                clk_sm_cur <= sm_rst;
        end
    end

// State machine decoder
    always_comb
    begin
        // Default
        clk_hpd.cnt_ld          = 0;
        clk_hpd.cnt_in          = 0;
        clk_hpd.pin_clr         = 0;
        clk_hpd.pin_set         = 0;
        clk_ctl.hpd_unplug_clr  = 0;
        clk_ctl.hpd_plug_clr    = 0;
        clk_ctl.hpd_irq_clr     = 0;
        clk_sm_nxt              = sm_rst;

        case (clk_sm_cur)
            sm_rst :
            begin
                clk_hpd.pin_clr             = 1;
                clk_sm_nxt                  = sm_idle;
            end

            sm_idle :
            begin
                // Unplug event
                if (clk_ctl.hpd_unplug && clk_hpd.cnt_end)
                begin
                    clk_ctl.hpd_unplug_clr  = 1;
                    clk_hpd.pin_clr         = 1;
                    clk_sm_nxt              = sm_idle;
                end

                // Plug event
                else if (clk_ctl.hpd_plug)
                begin
                    clk_ctl.hpd_plug_clr    = 1;
                    clk_hpd.pin_set         = 1;
                    clk_hpd.cnt_ld          = 1;
                    clk_hpd.cnt_in          = P_HMS_VAL;    // Load counter with HPD minimum spacing
                    clk_sm_nxt              = sm_idle;
                end

                // IRQ event
                else if (clk_ctl.hpd_irq && clk_hpd.cnt_end)
                begin
                    clk_ctl.hpd_irq_clr     = 1;
                    clk_hpd.pin_clr         = 1;
                    clk_hpd.cnt_ld          = 1;
                    clk_hpd.cnt_in          = P_IPW_VAL;    // Load counter with IRQ pulse width
                    clk_sm_nxt              = sm_irq;
                end

                else
                    clk_sm_nxt              = sm_idle;
            end

            sm_irq :
            begin
                if (clk_hpd.cnt_end)
                begin
                    clk_hpd.pin_set         = 1;
                    clk_hpd.cnt_ld          = 1;
                    clk_hpd.cnt_in          = P_HMS_VAL;    // Load counter with HPD minimum spacing
                    clk_sm_nxt              = sm_idle;
                end

                else
                    clk_sm_nxt              = sm_irq;
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
            // Load
            if (clk_hpd.cnt_ld)
                clk_hpd.cnt <= clk_hpd.cnt_in;

            // Decrement
            else if (!clk_hpd.cnt_end && clk_beat_re)
                clk_hpd.cnt <= clk_hpd.cnt - 'd1;
        end

        // Idle
        else
            clk_hpd.cnt <= 0;
    end

// Counter end
    always_comb
    begin
        if (clk_hpd.cnt == 0)
            clk_hpd.cnt_end = 1;
        else
            clk_hpd.cnt_end = 0;
    end

// HPD pin
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_ctl.run)
        begin
            // Clear
            if (clk_hpd.pin_clr)
                clk_hpd.pin <= 0;

            // Set
            else if (clk_hpd.pin_set)
                clk_hpd.pin <= 1;
        end

        // Idle
        else
            clk_hpd.pin <= 0;
    end

// Outputs
    assign LB_IF.dout   = clk_lb.dout;
    assign LB_IF.vld    = clk_lb.vld;
    assign HPD_OUT      = clk_hpd.pin;
    assign IRQ_OUT      = 0;     // Not used
endmodule

`default_nettype wire
