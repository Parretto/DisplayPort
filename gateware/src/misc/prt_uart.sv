/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: UART Peripheral
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

// Module
module prt_uart
#(
    parameter   P_VENDOR = "none",  // Vendor "xilinx" or "lattice"
    parameter   P_SIM = 0,                  // Simulation
    parameter   P_BEAT = 'd1085
)
(
	// Reset and clock
	input wire 				RST_IN,
	input wire 				CLK_IN,

    // Local bus interface
    prt_dp_lb_if.lb_in      LB_IF,

	// UART
 	input wire 			    UART_RX_IN,		// Receive
 	output wire 			UART_TX_OUT		// Transmit
);

// Parameters
localparam P_FIFO_WRDS      = 32;
localparam P_FIFO_ADR       = $clog2(P_FIFO_WRDS);

// Control register bit locations
localparam P_CTL_RUN        = 0;
localparam P_CTL_WIDTH      = 1;

// Status register bit locations
localparam P_STA_TX_EP      = 0;
localparam P_STA_TX_FL      = 1;
localparam P_STA_TX_WRDS    = 2;
localparam P_STA_RX_EP      = 8;
localparam P_STA_RX_FL      = 9;
localparam P_STA_RX_WRDS    = 10;
localparam P_STA_WIDTH      = 16;

// State machine
typedef enum {
     sm_idle, sm_shft
} sm_state;

// Structure
typedef struct {
    logic   [3:0]               adr;
    logic                       wr;
    logic                       rd;
    logic   [31:0]              din;
    logic   [31:0]              dout;
    logic                       vld;
    logic                       vld_re;
} lb_struct;

typedef struct {
    logic   [P_CTL_WIDTH-1:0]   r;              // Register
    logic                       sel;            // Select
    logic                       run;            // Run
} ctl_struct;

typedef struct {
    logic   [P_STA_WIDTH-1:0]   r;              // Register
    logic                       sel;            // Select
} sta_struct;

typedef struct {
    logic   [7:0]               din;
    logic                       wr;
    logic                       rd;
    logic   [7:0]               dout;
    logic                       de;
    logic                       ep;
    logic                       fl;
    logic  [P_FIFO_ADR:0]       wrds;
} fifo_struct;

typedef struct {
	sm_state				    sm_cur;
	sm_state				    sm_nxt;
    logic                       dat_sel;
    logic   [15:0]              beat_cnt;
    logic                       beat_cnt_end;
    logic                       beat;
    logic   [8:0]               shft;
    logic                       shft_ld;
    logic                       shft_nxt;
	logic	[4:0]			    bit_cnt;
	logic					    bit_cnt_end;
    logic                       bit_cnt_ld;
    logic                       bit_cnt_dec;
    logic                       tx;
} tx_struct;

typedef struct {
    sm_state                    sm_cur;
    sm_state                    sm_nxt;
    logic                       dat_sel;
    logic                       beat_ld;
    logic   [15:0]              beat_cnt;
    logic                       beat_cnt_end;
    logic                       beat;
    logic                       str;
    logic   [7:0]               shft;
    logic                       shft_nxt;
    logic   [4:0]               bit_cnt;
    logic                       bit_cnt_end;
    logic                       bit_cnt_ld;
    logic                       bit_cnt_dec;
    logic                       rx;
} rx_struct;

// Signals

lb_struct           clk_lb;         // Local bus
ctl_struct			clk_ctl;		// Control register
sta_struct			clk_sta;		// Status register
tx_struct		    clk_tx;	
fifo_struct         clk_tx_fifo; 
rx_struct           clk_rx; 
fifo_struct         clk_rx_fifo; 

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
        clk_ctl.sel     = 0;
        clk_sta.sel     = 0;
        clk_tx.dat_sel  = 0;
        clk_rx.dat_sel  = 0;
        
        case (clk_lb.adr)
            'd0  : clk_ctl.sel      = 1;
            'd1  : clk_sta.sel      = 1;
            'd2  : clk_tx.dat_sel   = 1;
            'd3  : clk_rx.dat_sel   = 1;
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
            clk_lb.dout[0+:$size(clk_ctl.r)] = clk_ctl.r;

        // Status register
        else if (clk_sta.sel)
            clk_lb.dout[0+:$size(clk_sta.r)] = clk_sta.r;

        // Read data
        else
            clk_lb.dout[0+:$size(clk_rx_fifo.dout)] = clk_rx_fifo.dout;
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

// Valid rising edge
// This is used for the RX fifo read
    prt_dp_lib_edge
    LB_VLD_EDGE_INST
    (
        .CLK_IN     (CLK_IN),           // Clock
        .CKE_IN     (1'b1),             // Clock enable
        .A_IN       (clk_lb.vld),       // Input
        .RE_OUT     (clk_lb.vld_re),    // Rising edge
        .FE_OUT     ()                  // Falling edge
    );

// Control register
    always_ff @ (posedge RST_IN, posedge CLK_IN)
    begin
        if (RST_IN)
            clk_ctl.r <= 0;

        else
        begin
            // Write
            if (clk_ctl.sel && clk_lb.wr)
                clk_ctl.r <= clk_lb.din[0+:$size(clk_ctl.r)];
        end
    end

// Control register bit locations
    assign clk_ctl.run  = clk_ctl.r[P_CTL_RUN];     // Run

// Status register
	assign clk_sta.r[P_STA_TX_EP]                               = clk_tx_fifo.ep;
    assign clk_sta.r[P_STA_TX_FL]                               = clk_tx_fifo.fl;
    assign clk_sta.r[P_STA_TX_WRDS+:$size(clk_tx_fifo.wrds)]    = clk_tx_fifo.wrds;
    assign clk_sta.r[P_STA_RX_EP]                               = clk_rx_fifo.ep;
    assign clk_sta.r[P_STA_RX_FL]                               = clk_rx_fifo.fl;
    assign clk_sta.r[P_STA_RX_WRDS+:$size(clk_rx_fifo.wrds)]    = clk_rx_fifo.wrds;
    
/*
	TX UART
*/

    always_comb
    begin
        if (clk_lb.wr && clk_tx.dat_sel)
            clk_tx_fifo.wr = 1;
        else
            clk_tx_fifo.wr = 0;
    end

    assign clk_tx_fifo.din = clk_lb.din[0+:$size(clk_tx_fifo.din)];

    // FIFO
    prt_dp_lib_fifo_sc
    #(
        .P_VENDOR       (P_VENDOR),         // Vendor
        .P_MODE         ("single"),         // "single" or "burst"
        .P_RAM_STYLE    ("distributed"),    // "distributed", "block" or "ultra"
        .P_ADR_WIDTH    (P_FIFO_ADR),
        .P_DAT_WIDTH    (8)
    )
    TX_FIFO_INST
    (
        // Clocks and reset
        .RST_IN     (RST_IN),               // Reset
        .CLK_IN     (CLK_IN),               // Clock
        .CLR_IN     (~clk_ctl.run),         // Clear

        // Write
        .WR_IN      (clk_tx_fifo.wr),       // Write in
        .DAT_IN     (clk_tx_fifo.din),      // Write data

        // Read
        .RD_EN_IN   (1'b1),                 // Read enable in
        .RD_IN      (clk_tx_fifo.rd),       // Read in
        .DAT_OUT    (clk_tx_fifo.dout),     // Data out
        .DE_OUT     (clk_tx_fifo.de),       // Data enable

        // Status
        .WRDS_OUT   (clk_tx_fifo.wrds),     // Used words
        .EP_OUT     (clk_tx_fifo.ep),       // Empty
        .FL_OUT     (clk_tx_fifo.fl)        // Full
    );

// Beat generator
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_ctl.run)
        begin
            // Load
            if (clk_tx.beat_cnt_end)
                clk_tx.beat_cnt <= P_BEAT;

            // Decrement
            else
                clk_tx.beat_cnt <= clk_tx.beat_cnt - 'd1;
        end

        // Idle
        else
            clk_tx.beat_cnt <= 0;
    end

// Beat counter end
    always_comb
    begin
        if (clk_tx.beat_cnt == 0)
            clk_tx.beat_cnt_end = 1;
        else
            clk_tx.beat_cnt_end = 0;
    end

// Beat
    prt_dp_lib_edge
    TX_BEAT_EDGE_INST
    (
        .CLK_IN     (CLK_IN),                   // Clock
        .CKE_IN     (1'b1),                     // Clock enable
        .A_IN       (clk_tx.beat_cnt_end),      // Input
        .RE_OUT     (clk_tx.beat),              // Rising edge
        .FE_OUT     ()                          // Falling edge
    );

generate
    if (P_SIM)
    begin : gen_tx_sim
        always_ff @ (posedge CLK_IN)
        begin
            clk_tx_fifo.rd <= 0;

            if (clk_tx_fifo.de && !clk_tx_fifo.rd)
            begin
                clk_tx_fifo.rd <= 1;
                $write ("%c", clk_tx_fifo.dout[0+:8]);
            end
        end
    end

    else 
    begin : gen_tx_sm
    
    // State machine
    	always_ff @ (posedge RST_IN, posedge CLK_IN)
    	begin
            // Reset
            if (RST_IN)
                clk_tx.sm_cur <= sm_idle;

            else
            begin
                // Run
        		if (clk_ctl.run)
                    clk_tx.sm_cur <= clk_tx.sm_nxt;
                else
        			clk_tx.sm_cur <= sm_idle;
            end
    	end

    // State machine decoder
    	always_comb
    	begin
    		// Default
    		clk_tx.sm_nxt = sm_idle;
            clk_tx_fifo.rd = 0;
            clk_tx.shft_ld = 0;
            clk_tx.shft_nxt = 0;
            clk_tx.bit_cnt_ld = 0;
            clk_tx.bit_cnt_dec = 0;

    		case (clk_tx.sm_cur)

    			// Idle
    			sm_idle :
    			begin
                    // Does the fifo has any data
                    if (clk_tx_fifo.de && clk_tx.beat)
                    begin
                        clk_tx_fifo.rd = 1;
                        clk_tx.shft_ld = 1;
                        clk_tx.bit_cnt_ld = 1;
                        clk_tx.sm_nxt = sm_shft;
                    end

                    else
                        clk_tx.sm_nxt = sm_idle;
                end

                sm_shft :
                begin
                    if (clk_tx.beat)
                    begin
                        if (clk_tx.bit_cnt_end)
                            clk_tx.sm_nxt = sm_idle;

                        else
                        begin
                            clk_tx.shft_nxt = 1;
                            clk_tx.bit_cnt_dec = 1;
                            clk_tx.sm_nxt = sm_shft;
                        end
                    end

                    else
                        clk_tx.sm_nxt = sm_shft;
                end

                default :
                begin
                    clk_tx.sm_nxt = sm_idle;
                end

            endcase
        end
    end
endgenerate

// Bit counter
    always_ff @ (posedge CLK_IN)
    begin
        // Load
        if (clk_tx.bit_cnt_ld)
            clk_tx.bit_cnt <= 'd9;

        // Decrement
        else if (clk_tx.bit_cnt_dec)
            clk_tx.bit_cnt <= clk_tx.bit_cnt - 'd1;
    end

// Bit counter end
    always_comb
    begin
        if (clk_tx.bit_cnt == 0)
            clk_tx.bit_cnt_end = 1;
        else
            clk_tx.bit_cnt_end = 0;
    end

// Shift register
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_ctl.run)
        begin
            // Load
            if (clk_tx.shft_ld)
                clk_tx.shft <= {clk_tx_fifo.dout, 1'b0};

            // Shift
            else if (clk_tx.shft_nxt)
                clk_tx.shft <= {1'b1, clk_tx.shft[8:1]};
        end

        // Idle
        else
           clk_tx.shft <= '1; 
    end

// TX register
    always_ff @ (posedge CLK_IN)
    begin
        clk_tx.tx <= clk_tx.shft[0];
    end


/*
    RX UART
*/

    // Write data
    assign clk_rx_fifo.din = clk_rx.shft;

    // Read
    always_comb
    begin
        if (clk_lb.vld_re && clk_rx.dat_sel)
            clk_rx_fifo.rd = 1;
        else
            clk_rx_fifo.rd = 0;
    end

    // FIFO
    prt_dp_lib_fifo_sc
    #(
        .P_VENDOR       (P_VENDOR),         // Vendor
        .P_MODE         ("single"),         // "single" or "burst"
        .P_RAM_STYLE    ("distributed"),    // "distributed", "block" or "ultra"
        .P_ADR_WIDTH    (P_FIFO_ADR),
        .P_DAT_WIDTH    (8)
    )
    RX_FIFO_INST
    (
        // Clocks and reset
        .RST_IN     (RST_IN),               // Reset
        .CLK_IN     (CLK_IN),               // Clock
        .CLR_IN     (~clk_ctl.run),         // Clear

        // Write
        .WR_IN      (clk_rx_fifo.wr),       // Write in
        .DAT_IN     (clk_rx_fifo.din),      // Write data

        // Read
        .RD_EN_IN   (1'b1),                 // Read enable in
        .RD_IN      (clk_rx_fifo.rd),       // Read in
        .DAT_OUT    (clk_rx_fifo.dout),     // Data out
        .DE_OUT     (clk_rx_fifo.de),       // Data enable

        // Status
        .WRDS_OUT   (clk_rx_fifo.wrds),     // Used words
        .EP_OUT     (clk_rx_fifo.ep),       // Empty
        .FL_OUT     (clk_rx_fifo.fl)        // Full
    );

// Beat generator
    always_ff @ (posedge CLK_IN)
    begin
        // Only run when the state machine is active
        if (clk_rx.sm_nxt == sm_shft)
        begin
            // Init
            if (clk_rx.beat_ld)
                clk_rx.beat_cnt <= P_BEAT / 2;

            // Load
            else if (clk_rx.beat_cnt_end)
                clk_rx.beat_cnt <= P_BEAT;

            // Decrement
            else
                clk_rx.beat_cnt <= clk_rx.beat_cnt - 'd1;
        end

        // Idle
        else
            clk_rx.beat_cnt <= 0;
    end

// Beat counter end
    always_comb
    begin
        if (clk_rx.beat_cnt == 0)
            clk_rx.beat_cnt_end = 1;
        else
            clk_rx.beat_cnt_end = 0;
    end

// Beat
    prt_dp_lib_edge
    RX_BEAT_EDGE_INST
    (
        .CLK_IN     (CLK_IN),                   // Clock
        .CKE_IN     (1'b1),                     // Clock enable
        .A_IN       (clk_rx.beat_cnt_end),      // Input
        .RE_OUT     (clk_rx.beat),              // Rising edge
        .FE_OUT     ()                          // Falling edge
    );

// RX register
    always_ff @ (posedge CLK_IN)
    begin
        clk_rx.rx <= UART_RX_IN;
    end

// Start detector
    prt_dp_lib_edge
    RX_STR_EDGE_INST
    (
        .CLK_IN     (CLK_IN),           // Clock
        .CKE_IN     (1'b1),             // Clock enable
        .A_IN       (clk_rx.rx),       // Input
        .RE_OUT     (),                 // Rising edge
        .FE_OUT     (clk_rx.str)        // Falling edge
    );

// State machine
    always_ff @ (posedge RST_IN, posedge CLK_IN)
    begin
        // Reset
        if (RST_IN)
            clk_rx.sm_cur <= sm_idle;

        else
        begin
            // Run
            if (clk_ctl.run)
                clk_rx.sm_cur <= clk_rx.sm_nxt;
            else
                clk_rx.sm_cur <= sm_idle;
        end
    end

// State machine decoder
    always_comb
    begin
        // Default
        clk_rx.sm_nxt = sm_idle;
        clk_rx.beat_ld = 0;
        clk_rx_fifo.wr = 0;
        clk_rx.shft_nxt = 0;
        clk_rx.bit_cnt_ld = 0;
        clk_rx.bit_cnt_dec = 0;

        case (clk_rx.sm_cur)

            // Idle
            sm_idle :
            begin
                // Do we have a start?
                if (clk_rx.str)
                begin
                    clk_rx.beat_ld = 1;
                    clk_rx.bit_cnt_ld = 1;
                    clk_rx.sm_nxt = sm_shft;
                end

                else
                    clk_rx.sm_nxt = sm_idle;
            end

            sm_shft :
            begin
                if (clk_rx.beat)
                begin
                    if (clk_rx.bit_cnt_end)
                    begin
                        clk_rx_fifo.wr = 1;
                        clk_rx.sm_nxt = sm_idle;
                    end

                    else
                    begin
                        clk_rx.shft_nxt = 1;
                        clk_rx.bit_cnt_dec = 1;
                        clk_rx.sm_nxt = sm_shft;
                    end
                end

                else
                    clk_rx.sm_nxt = sm_shft;
            end

            default :
            begin
                clk_rx.sm_nxt = sm_idle;
            end

        endcase
    end

// Bit counter
    always_ff @ (posedge CLK_IN)
    begin
        // Load
        if (clk_rx.bit_cnt_ld)
            clk_rx.bit_cnt <= 'd9;

        // Decrement
        else if (clk_rx.bit_cnt_dec)
            clk_rx.bit_cnt <= clk_rx.bit_cnt - 'd1;
    end

// Bit counter end
    always_comb
    begin
        if (clk_rx.bit_cnt == 0)
            clk_rx.bit_cnt_end = 1;
        else
            clk_rx.bit_cnt_end = 0;
    end

// Shift register
    always_ff @ (posedge CLK_IN)
    begin
        // Shift
        if (clk_rx.shft_nxt)
            clk_rx.shft <= {clk_rx.rx, clk_rx.shft[7:1]};
    end

// Outputs
    assign LB_IF.dout       = clk_lb.dout;
    assign LB_IF.vld        = clk_lb.vld;
    assign UART_TX_OUT      = clk_tx.tx;

endmodule

`default_nettype wire
