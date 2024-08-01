/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: I2C Peripheral
    (c) 2021 - 2024 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Implemented clock stretching support for read cycle
    v1.2 - Added support for Tentiva System Controller in DIA mode

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
module prt_i2c
(
	// Reset and clock
	input wire 				RST_IN,
	input wire 				CLK_IN,

    // Local bus interface
    prt_dp_lb_if.lb_in      LB_IF,

    // Direct I2C Access
    output wire             DIA_RDY_OUT,
    input wire [31:0]       DIA_DAT_IN,
    input wire              DIA_VLD_IN,

	// I2C
 	inout wire 			    I2C_SCL_INOUT,		// SCL
 	inout wire 			    I2C_SDA_INOUT		// SDA
);

// Parameters
// Control register bit locations
localparam P_CTL_RUN        = 0;
localparam P_CTL_STR        = 1;
localparam P_CTL_STP        = 2;
localparam P_CTL_WR         = 3;
localparam P_CTL_RD         = 4;
localparam P_CTL_ACK        = 5;
localparam P_CTL_DIA        = 6;
localparam P_CTL_TENTIVA    = 7;
localparam P_CTL_WIDTH      = 8;

// Status register bit locations
localparam P_STA_BUSY       = 0;
localparam P_STA_RDY        = 1;
localparam P_STA_ACK        = 2;
localparam P_STA_BUS        = 3;
localparam P_STA_WIDTH      = 4;

// Typedef
typedef enum {
	i2c_sm_idle,
    i2c_sm_str, i2c_sm_str1, i2c_sm_str2, i2c_sm_str3, i2c_sm_str4,
    i2c_sm_rstr, i2c_sm_rstr1, i2c_sm_rstr2, 
    i2c_sm_wr, i2c_sm_wr1, i2c_sm_wr2, i2c_sm_wr3, i2c_sm_wr4, i2c_sm_wr5, i2c_sm_wr6, i2c_sm_wr7, i2c_sm_wr8,
    i2c_sm_rd, i2c_sm_rd1, i2c_sm_rd2, i2c_sm_rd3, i2c_sm_rd4, i2c_sm_rd5, i2c_sm_rd6, i2c_sm_rd7,
    i2c_sm_stp, i2c_sm_stp1, i2c_sm_stp2, i2c_sm_stp3
} i2c_sm_state;

typedef enum {
    dia_sm_idle, 
    dia_sm_str, dia_sm_str1,
    dia_sm_wr, dia_sm_wr1, dia_sm_wr2, dia_sm_wr3, dia_sm_wr4, dia_sm_wr5, dia_sm_wr6, dia_sm_wr7, 
    dia_sm_wr8, dia_sm_wr9, dia_sm_wr10, dia_sm_wr11, dia_sm_wr12, dia_sm_wr13, dia_sm_wr14,
    dia_sm_stp, dia_sm_stp1
} dia_sm_state;

// Structure
typedef struct {
    logic   [3:0]               adr;
    logic                       wr;
    logic                       rd;
    logic   [31:0]              din;
    logic   [31:0]              dout;
    logic                       vld;
} lb_struct;

typedef struct {
    logic   [P_CTL_WIDTH-1:0]   r;              // Register
    logic                       sel;            // Select
    logic                       run;            // Run
    logic                       str;            // Start condition
    logic                       stp;            // Stop condition
    logic                       wr;             // Write data
    logic                       rd;             // Read data
    logic                       ack;            // ACK
    logic                       dia;            // DIA enable
    logic                       tentiva;        // Tentiva - 0 - Rev. C / 1 - Rev. D
} ctl_struct;

typedef struct {
    logic   [P_STA_WIDTH-1:0]   r;              // Register
    logic                       sel;            // Select
    logic                       busy_set;
    logic                       busy;
    logic                       rdy_set;
    logic                       rdy;
    logic                       ack_set;
    logic                       ack;
    logic                       bus;
} sta_struct;

typedef struct {
    logic   [15:0]              r;              // Register
    logic                       sel;            // Select
} beat_struct;

typedef struct {
    logic   [7:0]               r;              // Register
    logic                       sel;            // Select
} reg_struct;

typedef struct {
	i2c_sm_state			    sm_cur;
	i2c_sm_state			    sm_nxt;
    logic                       str;
    logic                       stp;
    logic                       wr;
    logic                       rd;
    logic   [15:0]              beat_cnt;
    logic                       beat_cnt_end;
    logic                       beat;
    logic					    scl_in;
    logic                       scl_out;
    logic                       scl_out_set;
    logic                       scl_out_clr;
	logic					    sda_in;
    logic                       sda_out;
    logic                       sda_out_set;
    logic                       sda_out_clr;
	logic	[7:0]			    shft;
	logic					    shft_ld;
	logic					    shft_nxt;
	logic	[4:0]			    bit_cnt;
	logic					    bit_cnt_end;
    logic                       bit_cnt_ld;
    logic                       bit_cnt_dec;
} i2c_struct;

typedef struct {
    dia_sm_state                sm_cur;
    dia_sm_state                sm_nxt;
    logic   [31:0]              dat;
    logic                       vld;
    logic                       rdy;
    logic                       str;
    logic                       stp;
    logic                       wr;
    logic   [7:0]               wr_dat;
} dia_struct;

// Signals

lb_struct           clk_lb;         // Local bus
ctl_struct			clk_ctl;		// Control register
sta_struct			clk_sta;		// Status register
beat_struct         clk_beat;       // Beat register
reg_struct          clk_wr_dat;     // Write data register
reg_struct          clk_rd_dat;     // Read data register
i2c_struct		    clk_i2c;		// I2C
dia_struct          clk_dia;        // Direct I2C Access

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
        clk_beat.sel    = 0;
        clk_wr_dat.sel  = 0;
        clk_rd_dat.sel  = 0;
        
        case (clk_lb.adr)
            'd0  : clk_ctl.sel      = 1;
            'd1  : clk_sta.sel      = 1;
            'd2  : clk_beat.sel     = 1;
            'd3  : clk_wr_dat.sel   = 1;
            'd4  : clk_rd_dat.sel   = 1;
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
            clk_lb.dout[0+:$size(clk_rd_dat.r)] = clk_rd_dat.r;
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
                clk_ctl.r <= clk_lb.din[0+:$size(clk_ctl.r)];

            // The command bits are cleared when the state machine gets busy
            else if (clk_sta.busy_set)
            begin
                clk_ctl.r[P_CTL_STR]    <= 0;
                clk_ctl.r[P_CTL_STP]    <= 0;
                clk_ctl.r[P_CTL_WR]     <= 0;
                clk_ctl.r[P_CTL_RD]     <= 0;
            end
        end
    end

// Control register bit locations
    assign clk_ctl.run          = clk_ctl.r[P_CTL_RUN];     // Run
    assign clk_ctl.str          = clk_ctl.r[P_CTL_STR];     // I2C Start
    assign clk_ctl.stp          = clk_ctl.r[P_CTL_STP];     // I2C Stop
    assign clk_ctl.wr           = clk_ctl.r[P_CTL_WR];      // I2C Write 
    assign clk_ctl.rd           = clk_ctl.r[P_CTL_RD];      // I2C Read
    assign clk_ctl.ack          = clk_ctl.r[P_CTL_ACK];     // I2C Ack
    assign clk_ctl.dia          = clk_ctl.r[P_CTL_DIA];     // DIA enable
    assign clk_ctl.tentiva      = clk_ctl.r[P_CTL_TENTIVA]; // Tentiva - 0 - Rev. C / 1 - Rev. D

// Status register
	assign clk_sta.r[P_STA_BUSY]    = clk_sta.busy;
    assign clk_sta.r[P_STA_RDY]     = clk_sta.rdy;
    assign clk_sta.r[P_STA_ACK]     = clk_sta.ack;
    assign clk_sta.r[P_STA_BUS]     = clk_sta.bus;

// Busy
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_ctl.run)
        begin
            // Clear
            if (clk_sta.rdy_set)
                clk_sta.busy <= 0;
            
            // Set
            else if (clk_sta.busy_set)
                clk_sta.busy <= 1;
        end

        // Idle
        else
            clk_sta.busy <= 0;
    end

// Ready
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_ctl.run && !clk_ctl.dia)
        begin
            // Clear 
            if (clk_sta.sel && clk_lb.wr && clk_lb.din[P_STA_RDY])
                clk_sta.rdy <= 0;

            // Set
            else if (clk_sta.rdy_set)
                clk_sta.rdy <= 1;
        end

        // Idle
        else
            clk_sta.rdy <= 0;
    end

// Ack
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_ctl.run)
        begin
            // Clear on any command
            if (clk_ctl.str || clk_ctl.stp || clk_ctl.wr || clk_ctl.rd)
                clk_sta.ack <= 0;

            // Set
            else if (clk_sta.ack_set)
                clk_sta.ack <= 1;
        end

        // Idle
        else
            clk_sta.ack <= 0;
    end

// Bus
// This flag is set after a start condition to indicate we have the bus.
// It is cleared after a stop condition.
// It is used to do a repeated start condition
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_ctl.run && !clk_ctl.dia)
        begin
            // Clear on stop
            if (clk_ctl.stp)
                clk_sta.bus <= 0;

            // Set on start
            else if (clk_ctl.str)
                clk_sta.bus <= 1;
        end

        // Idle
        else
            clk_sta.bus <= 0;
    end

// Beat register
    always_ff @ (posedge CLK_IN)
    begin
        // Write
        if (clk_beat.sel && clk_lb.wr)
            clk_beat.r <= clk_lb.din[0+:$size(clk_beat.r)];
    end

// Write data register
    always_ff @ (posedge CLK_IN)
    begin
        // Write
        if (clk_wr_dat.sel && clk_lb.wr)
            clk_wr_dat.r <= clk_lb.din[0+:$size(clk_wr_dat.r)];
    end

// Read data register
    assign clk_rd_dat.r = clk_i2c.shft;


/*
	I2C
*/

// Beat generator
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_ctl.run)
        begin
            // Load
            if (clk_i2c.beat_cnt_end)
                clk_i2c.beat_cnt <= clk_beat.r;

            // Decrement
            else
                clk_i2c.beat_cnt <= clk_i2c.beat_cnt - 'd1;
        end

        // Idle
        else
            clk_i2c.beat_cnt <= 0;
    end

// Beat counter end
    always_comb
    begin
        if (clk_i2c.beat_cnt == 0)
            clk_i2c.beat_cnt_end = 1;
        else
            clk_i2c.beat_cnt_end = 0;
    end

// Beat
    prt_dp_lib_edge
    BEAT_EDGE_INST
    (
        .CLK_IN     (CLK_IN),                   // Clock
        .CKE_IN     (1'b1),                     // Clock enable
        .A_IN       (clk_i2c.beat_cnt_end),     // Input
        .RE_OUT     (clk_i2c.beat),             // Rising edge
        .FE_OUT     ()                          // Falling edge
    );

// Start
    assign clk_i2c.str = clk_ctl.str || clk_dia.str;

// Stop
    assign clk_i2c.stp = clk_ctl.stp || clk_dia.stp;

// Write
    assign clk_i2c.wr = clk_ctl.wr || clk_dia.wr;

// Read
    assign clk_i2c.rd = clk_ctl.rd;

// State machine
	always_ff @ (posedge RST_IN, posedge CLK_IN)
	begin
        // Reset
        if (RST_IN)
            clk_i2c.sm_cur <= i2c_sm_idle;

        else
        begin
            // Run
    		if (clk_ctl.run)
                clk_i2c.sm_cur <= clk_i2c.sm_nxt;
            else
    			clk_i2c.sm_cur <= i2c_sm_idle;
        end
	end

// State machine decoder
	always_comb
	begin
		// Default
		clk_i2c.sm_nxt = i2c_sm_idle;
        clk_i2c.scl_out_set = 0;
        clk_i2c.scl_out_clr = 0;
        clk_i2c.sda_out_set = 0;
        clk_i2c.sda_out_clr = 0;
        clk_i2c.shft_ld = 0;
        clk_i2c.shft_nxt = 0;
        clk_i2c.bit_cnt_ld = 0;
        clk_i2c.bit_cnt_dec = 0;
        clk_sta.ack_set = 0;
        clk_sta.busy_set = 0;
        clk_sta.rdy_set = 0;

		case (clk_i2c.sm_cur)

			// Idle
			i2c_sm_idle :
			begin
                // Start command
                if (clk_i2c.str)
                begin
                    clk_sta.busy_set = 1;

                    // Do a repeated start if we already have the bus
                    if (clk_sta.bus)
                        clk_i2c.sm_nxt = i2c_sm_rstr;
                    else
                        clk_i2c.sm_nxt = i2c_sm_str;
                end

                // Stop command
                else if (clk_i2c.stp)
                begin
                    clk_sta.busy_set = 1;
                    clk_i2c.sm_nxt = i2c_sm_stp;
                end

                // Write command
                else if (clk_i2c.wr)
                begin
                    clk_sta.busy_set = 1;
                    clk_i2c.shft_ld = 1;            // Load shift register
                    clk_i2c.bit_cnt_ld = 1;         // Load bit counter
                    clk_i2c.sm_nxt = i2c_sm_wr;
                end

                // Read command
                else if (clk_i2c.rd)
                begin
                    clk_sta.busy_set = 1;
                    clk_i2c.bit_cnt_ld = 1;         // Load bit counter
                    clk_i2c.sm_nxt = i2c_sm_rd;
                end

                else
                    clk_i2c.sm_nxt = i2c_sm_idle;
            end

            // Start
            // Setup
            i2c_sm_str :
            begin
                if (clk_i2c.beat)
                    clk_i2c.sm_nxt = i2c_sm_str1;

                else
                    clk_i2c.sm_nxt = i2c_sm_str;
            end

            // Start
            // Check bus
            i2c_sm_str1 :
            begin
                // Both the SCL and SDA lines should be high
                // Wait for beat
                if (clk_i2c.beat)
                begin
                    // Check if the bus is free
                    // Bus is free
                    if (clk_i2c.scl_in && clk_i2c.sda_in)
                    begin
                        clk_i2c.sda_out_clr = 1;
                        clk_i2c.sm_nxt = i2c_sm_str2;
                    end

                    // Bus is not free
                    // Create SCL pulse to free bus
                    else
                    begin
                        clk_i2c.scl_out_set = 1;
                        clk_i2c.sm_nxt = i2c_sm_str3;
                    end
                end

                else
                    clk_i2c.sm_nxt = i2c_sm_str1;
            end

            // Start
            // Drive SCL low
            i2c_sm_str2 :
            begin
                if (clk_i2c.beat)
                begin
                    clk_i2c.scl_out_clr = 1;
                    clk_sta.rdy_set = 1;        // Set ready
                    clk_i2c.sm_nxt = i2c_sm_idle;
                end

                else
                    clk_i2c.sm_nxt = i2c_sm_str2;
            end

            // Start
            // Drive SCL high
            i2c_sm_str3 :
            begin
                if (clk_i2c.beat)
                begin
                    clk_i2c.scl_out_set = 1;
                    clk_i2c.sm_nxt = i2c_sm_str1;
                end

                else
                    clk_i2c.sm_nxt = i2c_sm_str3;
            end

            // Repeated Start
            // Setup
            i2c_sm_rstr :
            begin
                if (clk_i2c.beat)
                    clk_i2c.sm_nxt = i2c_sm_rstr1;

                else
                    clk_i2c.sm_nxt = i2c_sm_rstr;
            end

            // Repeated Start
            // Set SDA high
            i2c_sm_rstr1 :
            begin
                if (clk_i2c.beat)
                begin
                    clk_i2c.sda_out_set = 1;
                    clk_i2c.sm_nxt = i2c_sm_rstr2;
                end

                else
                    clk_i2c.sm_nxt = i2c_sm_rstr1;
            end

            // Repeated Start
            // Set SCL high
            i2c_sm_rstr2 :
            begin
                if (clk_i2c.beat)
                begin
                    clk_i2c.scl_out_set = 1;
                    clk_i2c.sm_nxt = i2c_sm_str1;
                end

                else
                    clk_i2c.sm_nxt = i2c_sm_rstr2;
            end

            // Write
            // Setup
            i2c_sm_wr :
            begin
                // Wait for beat
                if (clk_i2c.beat)
                    clk_i2c.sm_nxt = i2c_sm_wr1;

                else
                    clk_i2c.sm_nxt = i2c_sm_wr;
            end

            // Write
            // Phase 0
            i2c_sm_wr1 :
            begin
                // Wait for beat
                if (clk_i2c.beat)
                begin
                    // Clock low
                    clk_i2c.scl_out_clr = 1;

                    if (clk_i2c.bit_cnt_end)
                    begin
                        // Set SDA so we can read the ACK
                        clk_i2c.sda_out_set = 1;
                        clk_i2c.sm_nxt = i2c_sm_wr5;
                    end

                    else
                    begin
                        // Drive data
                        if (clk_i2c.shft[7])
                            clk_i2c.sda_out_set = 1;
                        else
                            clk_i2c.sda_out_clr = 1;

                        clk_i2c.shft_nxt = 1;
                        clk_i2c.bit_cnt_dec = 1;
                        clk_i2c.sm_nxt = i2c_sm_wr2;
                    end
                end

                else
                    clk_i2c.sm_nxt = i2c_sm_wr1;
            end

            // Write
            // Phase 1
            i2c_sm_wr2 :
            begin
                // Wait for beat
                if (clk_i2c.beat)
                begin
                    clk_i2c.scl_out_set = 1;
                    clk_i2c.sm_nxt = i2c_sm_wr3;
                end

                else
                    clk_i2c.sm_nxt = i2c_sm_wr2;
            end

            // Write
            // Phase 2
            i2c_sm_wr3 :
            begin
                // Wait for beat
                if (clk_i2c.beat)
                    clk_i2c.sm_nxt = i2c_sm_wr4;

                else
                    clk_i2c.sm_nxt = i2c_sm_wr3;
            end

            // Write
            // Phase 3
            i2c_sm_wr4 :
            begin
                // Wait for beat
                if (clk_i2c.beat)
                begin
                    clk_i2c.scl_out_clr = 1;
                    clk_i2c.sm_nxt = i2c_sm_wr1;
                end

                else
                    clk_i2c.sm_nxt = i2c_sm_wr4;
            end

            // Write
            // ACK / NACK - phase 1
            i2c_sm_wr5 :
            begin
                // Wait for beat
                if (clk_i2c.beat)
                begin
                    clk_i2c.scl_out_set = 1;
                    clk_i2c.sm_nxt = i2c_sm_wr6;
                end

                else
                    clk_i2c.sm_nxt = i2c_sm_wr5;
            end                

            // Write
            // ACK / NACK - phase 2
            i2c_sm_wr6 :
            begin
                // Wait for beat
                if (clk_i2c.beat)
                    clk_i2c.sm_nxt = i2c_sm_wr7;

                else
                    clk_i2c.sm_nxt = i2c_sm_wr6;
            end                

            // Write
            // ACK / NACK - phase 3
            i2c_sm_wr7 :
            begin
                // Wait for beat
                if (clk_i2c.beat)
                begin
                    // Clock low
                    clk_i2c.scl_out_clr = 1;

                    // ACK
                    if (!clk_i2c.sda_in)
                        clk_sta.ack_set = 1;                

                    clk_i2c.sm_nxt = i2c_sm_wr8;
                end

                else
                    clk_i2c.sm_nxt = i2c_sm_wr7;
            end

            // Write
            // End
            i2c_sm_wr8 :
            begin
                // Wait for beat
                if (clk_i2c.beat)
                begin
                    clk_i2c.sda_out_clr = 1;
                    clk_sta.rdy_set = 1;        // Set ready
                    clk_i2c.sm_nxt = i2c_sm_idle;
                end

                else
                    clk_i2c.sm_nxt = i2c_sm_wr8;
            end

            // Read
            // Init
            i2c_sm_rd :
            begin
                // Wait for beat
                if (clk_i2c.beat)
                begin
                    // Set SCL and SDA so we can read the SDA input
                    clk_i2c.sda_out_set = 1;
                    clk_i2c.scl_out_set = 1;

                    // Wait if the slave is holding off the transaction (clock stretching)
                    if (clk_i2c.scl_in)
                        clk_i2c.sm_nxt = i2c_sm_rd1;
                    else
                        clk_i2c.sm_nxt = i2c_sm_rd;
                end

                else
                    clk_i2c.sm_nxt = i2c_sm_rd;
            end

            // Read
            // Phase 1
            i2c_sm_rd1 :
            begin
                // Wait for beat
                if (clk_i2c.beat)
                begin
                    clk_i2c.scl_out_set = 1;
                    clk_i2c.sm_nxt = i2c_sm_rd2;
                end

                else
                    clk_i2c.sm_nxt = i2c_sm_rd1;
            end

            // Read
            // Phase 2
            i2c_sm_rd2 :
            begin
                // Wait for beat
                if (clk_i2c.beat)
                    clk_i2c.sm_nxt = i2c_sm_rd3;

                else
                    clk_i2c.sm_nxt = i2c_sm_rd2;
            end

            // Read
            // Phase 3
            i2c_sm_rd3 :
            begin
                // Wait for beat
                if (clk_i2c.beat)
                begin
                    clk_i2c.shft_nxt = 1;
                    clk_i2c.bit_cnt_dec = 1;
                    clk_i2c.scl_out_clr = 1;
                    clk_i2c.sm_nxt = i2c_sm_rd4;
                end

                else
                    clk_i2c.sm_nxt = i2c_sm_rd3;
            end

            // Read
            // Phase 0
            i2c_sm_rd4 :
            begin
                // Wait for beat
                if (clk_i2c.beat)
                begin
                    // Have we shift out all bits?
                    if (clk_i2c.bit_cnt_end)
                    begin
                        if (clk_ctl.ack)
                            clk_i2c.sda_out_clr = 1;
                        else                    
                            clk_i2c.sda_out_set = 1;
    
                        clk_i2c.sm_nxt = i2c_sm_rd5;
                    end

                    else
                        clk_i2c.sm_nxt = i2c_sm_rd1;
                end

                else
                    clk_i2c.sm_nxt = i2c_sm_rd4;
            end

            // Ack / Nack - Phase 1
            i2c_sm_rd5 :
            begin
                // Wait for beat
                if (clk_i2c.beat)
                begin
                    clk_i2c.scl_out_set = 1;
                    clk_i2c.sm_nxt = i2c_sm_rd6;
                end

                else
                    clk_i2c.sm_nxt = i2c_sm_rd5;
            end

            // Ack / Nack - Phase 2
            i2c_sm_rd6 :
            begin
                // Wait for beat
                if (clk_i2c.beat)
                    clk_i2c.sm_nxt = i2c_sm_rd7;

                else
                    clk_i2c.sm_nxt = i2c_sm_rd6;
            end

            // Ack / Nack - Phase 3
            i2c_sm_rd7 :
            begin
                // Wait for beat
                if (clk_i2c.beat)
                begin
                    clk_i2c.scl_out_clr = 1;
                    clk_sta.rdy_set = 1;        // Set ready
                    clk_i2c.sm_nxt = i2c_sm_idle;
                end

                else
                    clk_i2c.sm_nxt = i2c_sm_rd7;
            end

            // Stop
            // Init
            i2c_sm_stp :
            begin
                if (clk_i2c.beat)
                    clk_i2c.sm_nxt = i2c_sm_stp1;

                else
                    clk_i2c.sm_nxt = i2c_sm_stp;
            end

            // Stop
            // SDA low
            i2c_sm_stp1 :
            begin
                if (clk_i2c.beat)
                begin
                    clk_i2c.sda_out_clr = 1;
                    clk_i2c.sm_nxt = i2c_sm_stp2;
                end

                else
                    clk_i2c.sm_nxt = i2c_sm_stp1;
            end

            // Stop
            // SCL high
            i2c_sm_stp2 :
            begin
                if (clk_i2c.beat)
                begin
                    clk_i2c.scl_out_set = 1;
                    clk_i2c.sm_nxt = i2c_sm_stp3;
                end

                else
                    clk_i2c.sm_nxt = i2c_sm_stp2;
            end

            // Stop
            // SDA high
            i2c_sm_stp3 :
            begin
                if (clk_i2c.beat)
                begin
                    clk_i2c.sda_out_set = 1;
                    clk_sta.rdy_set = 1;        // Set ready
                    clk_i2c.sm_nxt = i2c_sm_idle;
                end

                else
                    clk_i2c.sm_nxt = i2c_sm_stp3;
            end

            default :
            begin
                clk_i2c.sm_nxt = i2c_sm_idle;
            end

        endcase
    end

// Bit counter
    always_ff @ (posedge CLK_IN)
    begin
        // Load
        if (clk_i2c.bit_cnt_ld)
            clk_i2c.bit_cnt <= 'd8;

        // Decrement
        else if (clk_i2c.bit_cnt_dec)
            clk_i2c.bit_cnt <= clk_i2c.bit_cnt - 'd1;
    end

// Bit counter end
    always_comb
    begin
        if (clk_i2c.bit_cnt == 0)
            clk_i2c.bit_cnt_end = 1;
        else
            clk_i2c.bit_cnt_end = 0;
    end

// Shift register
    always_ff @ (posedge CLK_IN)
    begin
        // Load
        if (clk_i2c.shft_ld)
        begin
            if (clk_ctl.dia)
                clk_i2c.shft <= clk_dia.wr_dat;
            else
                clk_i2c.shft <= clk_wr_dat.r;
        end

        // Shift
        else if (clk_i2c.shft_nxt)
            clk_i2c.shft <= {clk_i2c.shft[6:0], clk_i2c.sda_in};
    end

// SCL output
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_ctl.run)
        begin
            // Clear
            if (clk_i2c.scl_out_clr)
                clk_i2c.scl_out <= 0;

            // Set
            else if (clk_i2c.scl_out_set)
                clk_i2c.scl_out <= 1;
        end

        else
            clk_i2c.scl_out <= 1;
    end

// SCL input
    always_ff @ (posedge CLK_IN)
    begin
        clk_i2c.scl_in <= I2C_SCL_INOUT;
    end

// SDA output
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_ctl.run)
        begin
            // Clear
            if (clk_i2c.sda_out_clr)
                clk_i2c.sda_out <= 0;

            // Set
            else if (clk_i2c.sda_out_set)
                clk_i2c.sda_out <= 1;
        end

        // Idle
        else
            clk_i2c.sda_out <= 1;
    end

// SDA input
    always_ff @ (posedge CLK_IN)
    begin
        clk_i2c.sda_in <= I2C_SDA_INOUT;
    end

/*
    Direct I2C Access
*/

// Data and valid
    always_ff @ (posedge CLK_IN)
    begin
        clk_dia.dat <= DIA_DAT_IN;
        clk_dia.vld <= DIA_VLD_IN;
    end

// State machine
    always_ff @ (posedge RST_IN, posedge CLK_IN)
    begin
        // Reset
        if (RST_IN)
            clk_dia.sm_cur <= dia_sm_idle;

        else
        begin
            // Run
            if (clk_ctl.dia)
                clk_dia.sm_cur <= clk_dia.sm_nxt;
            else
                clk_dia.sm_cur <= dia_sm_idle;
        end
    end

// State machine decoder
    always_comb
    begin
        // Defaults
        clk_dia.str = 0;
        clk_dia.stp = 0;
        clk_dia.wr = 0;
        clk_dia.wr_dat = 0;

        case (clk_dia.sm_cur)
            dia_sm_idle :
            begin
                if (clk_dia.vld)
                    clk_dia.sm_nxt = dia_sm_str;

                else
                    clk_dia.sm_nxt = dia_sm_idle;
            end

            dia_sm_str : 
            begin
                clk_dia.str = 1;
                
                // Wait for busy
                if (clk_sta.busy)
                    clk_dia.sm_nxt = dia_sm_str1;
                else
                    clk_dia.sm_nxt = dia_sm_str;            
            end

            dia_sm_str1 : 
            begin
                // Wait for busy release
                if (!clk_sta.busy)
                    clk_dia.sm_nxt = dia_sm_wr;
                else
                    clk_dia.sm_nxt = dia_sm_str1;                        
            end

            // Slave
            dia_sm_wr :
            begin
                if (clk_ctl.tentiva)
                    clk_dia.wr_dat = 8'h9a; // Tentiva SC slave address
                else
                    clk_dia.wr_dat = 8'h12; // RC22504a slave address
                clk_dia.wr = 1;

                // Wait for busy
                if (clk_sta.busy)
                    clk_dia.sm_nxt = dia_sm_wr1;
                else
                    clk_dia.sm_nxt = dia_sm_wr;            
            end

            dia_sm_wr1 : 
            begin
                // Wait for busy release
                if (!clk_sta.busy)
                    clk_dia.sm_nxt = dia_sm_wr2;
                else
                    clk_dia.sm_nxt = dia_sm_wr1;                        
            end

            // Address high
            dia_sm_wr2 :
            begin
                if (clk_ctl.tentiva)
                    clk_dia.wr_dat = 8'h05;     // Register 5
                else
                    clk_dia.wr_dat = 8'h00;
                clk_dia.wr = 1;

                // Wait for busy
                if (clk_sta.busy)
                    clk_dia.sm_nxt = dia_sm_wr3;
                else
                    clk_dia.sm_nxt = dia_sm_wr2;            
            end

            dia_sm_wr3 : 
            begin
                // Wait for busy release
                if (!clk_sta.busy)
                begin
                    // Skip the address low byte for Tentiva SC
                    if (clk_ctl.tentiva)
                        clk_dia.sm_nxt = dia_sm_wr6;
                    else
                        clk_dia.sm_nxt = dia_sm_wr4;
                end
                else
                    clk_dia.sm_nxt = dia_sm_wr3;                        
            end

            // Address low
            dia_sm_wr4 :
            begin
                clk_dia.wr_dat = 8'hc8;
                clk_dia.wr = 1;

                // Wait for busy
                if (clk_sta.busy)
                    clk_dia.sm_nxt = dia_sm_wr5;
                else
                    clk_dia.sm_nxt = dia_sm_wr4;            
            end

            dia_sm_wr5 : 
            begin
                // Wait for busy release
                if (!clk_sta.busy)
                    clk_dia.sm_nxt = dia_sm_wr6;
                else
                    clk_dia.sm_nxt = dia_sm_wr5;
            end

            // First byte
            dia_sm_wr6 :
            begin
                clk_dia.wr_dat = clk_dia.dat[(0*8)+:8];
                clk_dia.wr = 1;

                // Wait for busy
                if (clk_sta.busy)
                    clk_dia.sm_nxt = dia_sm_wr7;
                else
                    clk_dia.sm_nxt = dia_sm_wr6;            
            end

            dia_sm_wr7 : 
            begin
                // Wait for busy release
                if (!clk_sta.busy)
                    clk_dia.sm_nxt = dia_sm_wr8;
                else
                    clk_dia.sm_nxt = dia_sm_wr7;
            end

            // Second byte
            dia_sm_wr8 :
            begin
                clk_dia.wr_dat = clk_dia.dat[(1*8)+:8];
                clk_dia.wr = 1;

                // Wait for busy
                if (clk_sta.busy)
                    clk_dia.sm_nxt = dia_sm_wr9;
                else
                    clk_dia.sm_nxt = dia_sm_wr8;            
            end

            dia_sm_wr9 : 
            begin
                // Wait for busy release
                if (!clk_sta.busy)
                    clk_dia.sm_nxt = dia_sm_wr10;
                else
                    clk_dia.sm_nxt = dia_sm_wr9;
            end

            // Third byte
            dia_sm_wr10 :
            begin
                clk_dia.wr_dat = clk_dia.dat[(2*8)+:8];
                clk_dia.wr = 1;

                // Wait for busy
                if (clk_sta.busy)
                    clk_dia.sm_nxt = dia_sm_wr11;
                else
                    clk_dia.sm_nxt = dia_sm_wr10;            
            end

            dia_sm_wr11 : 
            begin
                // Wait for busy release
                if (!clk_sta.busy)
                    clk_dia.sm_nxt = dia_sm_wr12;
                else
                    clk_dia.sm_nxt = dia_sm_wr11;
            end

            // Fourth byte
            dia_sm_wr12 :
            begin
                clk_dia.wr_dat = clk_dia.dat[(3*8)+:8];
                clk_dia.wr = 1;

                // Wait for busy
                if (clk_sta.busy)
                    clk_dia.sm_nxt = dia_sm_wr13;
                else
                    clk_dia.sm_nxt = dia_sm_wr12;            
            end

            dia_sm_wr13 : 
            begin
                // Wait for busy release
                if (!clk_sta.busy)
                    clk_dia.sm_nxt = dia_sm_stp;
                else
                    clk_dia.sm_nxt = dia_sm_wr13;
            end

            dia_sm_stp : 
            begin
                clk_dia.stp = 1;
                
                // Wait for busy
                if (clk_sta.busy)
                    clk_dia.sm_nxt = dia_sm_stp1;
                else
                    clk_dia.sm_nxt = dia_sm_stp;            
            end

            dia_sm_stp1 : 
            begin
                // Wait for busy release
                if (!clk_sta.busy)
                    clk_dia.sm_nxt = dia_sm_idle;
                else
                    clk_dia.sm_nxt = dia_sm_stp1;                        
            end

            default : 
            begin
                clk_dia.sm_nxt = dia_sm_idle;
            end
        endcase
    end

// Ready
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_ctl.dia && (clk_dia.sm_cur == dia_sm_idle))
            clk_dia.rdy <= 1;
        else
            clk_dia.rdy <= 0;
    end

// Outputs
    assign LB_IF.dout       = clk_lb.dout;
    assign LB_IF.vld        = clk_lb.vld;
    assign DIA_RDY_OUT      = clk_dia.rdy;
    assign I2C_SCL_INOUT    = (clk_i2c.scl_out) ? 1'bz : 0;
    assign I2C_SDA_INOUT    = (clk_i2c.sda_out) ? 1'bz : 0;

endmodule

`default_nettype wire
