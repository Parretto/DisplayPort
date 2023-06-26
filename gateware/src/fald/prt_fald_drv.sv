/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Full array local dimming Driver
    (c) 2023 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
*/

`default_nettype none

module prt_fald_drv
#(
    // System
    parameter               P_VENDOR      = "none",  // Vendor "xilinx" or "lattice"
    parameter               P_SIM         = 0      // Simulation
)
(
    // Reset and clock
    input wire              SYS_RST_IN,         // Reset
    input wire              SYS_CLK_IN,         // Clock

    // Control
    input wire              CTL_RUN_IN,         // Run
    input wire [15:0]       CTL_INIT_IN,        // Init period (video clock cycles)
    input wire [15:0]       CTL_PERIOD_IN,      // Period (video clock cycles)
    input wire [15:0]       CTL_ZONES_IN,       // Zones

    // Video
    input wire              VID_CLK_IN,         // Clock
    input wire              VID_VS_IN,          // Vsync

    // LED pixel buffer
   	input wire 		        LPB_CLR_IN,		    // Clear
	input wire [3:0]		LPB_DAT_IN,		    // Data
	input wire 				LPB_VLD_IN,			// Write

    // Dimming data stream
   	input wire 		        DDS_INIT_IN,	    // Init
	input wire [15:0]		DDS_DAT_IN,		    // Data
	input wire 				DDS_VLD_IN,			// Write

    // Led
    output wire             LED_CLK_OUT,        // Clock
    output wire             LED_DAT_OUT         // Data
);

// Localparam
localparam P_MSK_RAM_WRDS = 2048;
localparam P_MSK_RAM_ADR = $clog2(P_MSK_RAM_WRDS);
localparam P_MSK_RAM_DAT = $size(LPB_DAT_IN);

localparam P_DIM_RAM_WRDS = 2048;
localparam P_DIM_RAM_ADR = $clog2(P_MSK_RAM_WRDS);
localparam P_DIM_RAM_DAT = $size(DDS_DAT_IN);

// Typedef
typedef enum {
    sm_idle, sm_s0, sm_s1, sm_s2, sm_s3
} sm_state;

// Structure
typedef struct {
    logic                           run;
} sys_ctl_struct;

typedef struct {
    logic [P_MSK_RAM_ADR-1:0]       adr;
    logic [P_MSK_RAM_DAT-1:0]       din;
    logic                           wr;
} sys_msk_struct;

typedef struct {
    logic                           run;
    logic [15:0]                    init;
    logic [15:0]                    period;
    logic [15:0]                    zones;
} vid_ctl_struct;

typedef struct {
    sm_state                        sm_cur;
    sm_state                        sm_nxt;
    logic                           vid_vs_re;
    logic [15:0]                    beat_cnt_in;
    logic [15:0]                    beat_cnt;
    logic                           beat_cnt_ld;
    logic                           beat_cnt_end;
    logic [15:0]                    shft_in;
    logic [15:0]                    shft;
    logic                           shft_ld;
    logic                           shft_nxt;
    logic [4:0]                     shft_cnt;
    logic                           shft_cnt_end;
    logic [15:0]                    zone_cnt;
    logic                           zone_cnt_clr;
    logic                           zone_cnt_inc;
    logic                           zone_cnt_end;
    logic                           led_clk_set;
    logic                           led_clk_clr;
    logic                           led_clk;
    logic                           led_clk_reg /* synthesis syn_useioff = 1 */;
    logic                           led_dat;
    logic                           led_dat_reg /* synthesis syn_useioff = 1 */;
} drv_struct;

typedef struct {
    logic [P_MSK_RAM_ADR-1:0]       adr;
    logic [P_MSK_RAM_DAT-1:0]       dout;
    logic                           rd;
    logic                           vld;
} vid_msk_struct;

typedef struct {
    logic [P_DIM_RAM_ADR-1:0]       wr_adr;
    logic                           wr;
    logic [P_DIM_RAM_DAT-1:0]       din;
    logic [P_DIM_RAM_ADR-1:0]       rd_adr;
    logic                           rd;
    logic [P_DIM_RAM_DAT-1:0]       dout;
    logic                           vld;
} vid_dim_struct;

// Signals
sys_ctl_struct      sclk_ctl;
sys_msk_struct      sclk_msk_ram;
vid_ctl_struct      vclk_ctl;
drv_struct          vclk_drv;
vid_msk_struct      vclk_msk_ram;
vid_dim_struct      vclk_dim_ram;

// Debug
(* syn_preserve=1 *) logic           vclk_dbg_shft_ld;    
(* syn_preserve=1 *) logic [15:0]    vclk_dbg_shft_in;
(* syn_preserve=1 *) logic [3:0]     vclk_dbg_msk_ram_dout;
(* syn_preserve=1 *) logic [15:0]    vclk_dbg_dim_ram_dout;
(* syn_preserve=1 *) logic [15:0]    vclk_dbg_zone;


    always_ff @ (posedge VID_CLK_IN)
    begin
        vclk_dbg_shft_ld <= vclk_drv.shft_ld;
        vclk_dbg_shft_in <= vclk_drv.shft_in;
        vclk_dbg_msk_ram_dout <= vclk_msk_ram.dout;
        vclk_dbg_dim_ram_dout <= vclk_dim_ram.dout;
        vclk_dbg_zone <= vclk_drv.zone_cnt;
    end


// Logic

// Control
    always_ff @ (posedge SYS_CLK_IN)
    begin
        sclk_ctl.run <= CTL_RUN_IN;
    end

// Led pixel buffer

// Run clock domain crossing
    prt_fald_lib_cdc_bit
    RUN_CDC_INST
    (
        .SRC_CLK_IN     (SYS_CLK_IN),       // Clock
        .SRC_DAT_IN     (sclk_ctl.run), 	// Data
        .DST_CLK_IN     (VID_CLK_IN),       // Clock
        .DST_DAT_OUT	(vclk_ctl.run)  	// Data
    );

// Init clock domain crossing
	prt_fald_lib_cdc_vec
	#(
		.P_WIDTH 		($size(CTL_INIT_IN))
	)
	INIT_CDC_INST
	(
		.SRC_CLK_IN		(SYS_CLK_IN),		    // Clock
		.SRC_DAT_IN		(CTL_INIT_IN),		    // Data
		.DST_CLK_IN		(VID_CLK_IN),		    // Clock
		.DST_DAT_OUT	(vclk_ctl.init)		    // Data
	);

// Period clock domain crossing
	prt_fald_lib_cdc_vec
	#(
		.P_WIDTH 		($size(CTL_PERIOD_IN))
	)
	PERIOD_CDC_INST
	(
		.SRC_CLK_IN		(SYS_CLK_IN),		    // Clock
		.SRC_DAT_IN		(CTL_PERIOD_IN),		// Data
		.DST_CLK_IN		(VID_CLK_IN),		    // Clock
		.DST_DAT_OUT	(vclk_ctl.period)		// Data
	);

// Zones clock domain crossing
	prt_fald_lib_cdc_vec
	#(
		.P_WIDTH 		($size(CTL_ZONES_IN))
	)
	ZONES_CDC_INST
	(
		.SRC_CLK_IN		(SYS_CLK_IN),			// Clock
		.SRC_DAT_IN		(CTL_ZONES_IN),		    // Data
		.DST_CLK_IN		(VID_CLK_IN),			// Clock
		.DST_DAT_OUT	(vclk_ctl.zones)		// Data
	);

// Vsync rising edge
    prt_fald_lib_edge
    VS_EDGE_INST
    (
        .CLK_IN         (VID_CLK_IN),           // Clock
        .CKE_IN         (1'b1),                 // Clock enable
        .A_IN           (VID_VS_IN),            // Input
        .RE_OUT         (vclk_drv.vid_vs_re),   // Rising edge
        .FE_OUT         ()                      // Falling edge
    );

// Beat Counter
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Run
        if (vclk_ctl.run)
        begin
            // Load
            if (vclk_drv.beat_cnt_ld)
                vclk_drv.beat_cnt <= vclk_drv.beat_cnt_in;

            // Decrement
            else if (!vclk_drv.beat_cnt_end)
                vclk_drv.beat_cnt <= vclk_drv.beat_cnt - 'd1;
        end

        else
            vclk_drv.beat_cnt <= 0;
    end

// Counter end
    always_comb
    begin   
        if (vclk_drv.beat_cnt == 0)
            vclk_drv.beat_cnt_end = 1;
        else
            vclk_drv.beat_cnt_end = 0;
    end

// State machine
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Run
        if (vclk_ctl.run)
        begin
            if (vclk_drv.vid_vs_re)
                vclk_drv.sm_cur <= sm_s0;
            else
                vclk_drv.sm_cur <= vclk_drv.sm_nxt;
        end

        else
            vclk_drv.sm_cur <= sm_idle;
    end

// State machine decoder
    always_comb
    begin
        // Defaults
        vclk_drv.led_clk_set = 0;
        vclk_drv.led_clk_clr = 0;
        vclk_drv.beat_cnt_ld = 0;
        vclk_drv.beat_cnt_in = 0;
        vclk_drv.shft_ld = 0;
        vclk_drv.shft_nxt = 0;
        vclk_drv.zone_cnt_clr = 0;
        vclk_drv.zone_cnt_inc = 0;

        case (vclk_drv.sm_cur)

            sm_idle :
            begin
                vclk_drv.sm_nxt = sm_idle;
            end

            sm_s0 :
            begin
                vclk_drv.led_clk_clr = 1;
                vclk_drv.beat_cnt_in = vclk_ctl.init;
                vclk_drv.beat_cnt_ld = 1;
                vclk_drv.zone_cnt_clr = 1;
                vclk_drv.sm_nxt = sm_s1;
            end

            sm_s1 :
            begin
                if (vclk_drv.beat_cnt_end)
                begin
                    vclk_drv.shft_ld = 1;
                    vclk_drv.beat_cnt_in = vclk_ctl.period;
                    vclk_drv.beat_cnt_ld = 1;
                    vclk_drv.zone_cnt_inc = 1;
                    vclk_drv.sm_nxt = sm_s2;
                end

                else
                    vclk_drv.sm_nxt = sm_s1;
            end

            sm_s2 :
            begin
                if (vclk_drv.beat_cnt_end)
                begin
                    vclk_drv.led_clk_set = 1;
                    vclk_drv.beat_cnt_in = vclk_ctl.period;
                    vclk_drv.beat_cnt_ld = 1;
                    vclk_drv.sm_nxt = sm_s3;
                end

                else
                    vclk_drv.sm_nxt = sm_s2;
            end

            sm_s3 :
            begin
                if (vclk_drv.beat_cnt_end)
                begin
                    vclk_drv.led_clk_clr = 1;

                    if (vclk_drv.shft_cnt_end)
                    begin
                        if (vclk_drv.zone_cnt_end)
                            vclk_drv.sm_nxt = sm_idle;
                        else
                            vclk_drv.sm_nxt = sm_s1;
                    end

                    else
                    begin
                        vclk_drv.shft_nxt = 1;
                        vclk_drv.beat_cnt_in = vclk_ctl.period;
                        vclk_drv.beat_cnt_ld = 1;
                        vclk_drv.sm_nxt = sm_s2;
                    end
                end

                else
                    vclk_drv.sm_nxt = sm_s3;
            end

            default : 
            begin
                vclk_drv.sm_nxt = sm_idle;
            end
        endcase
    end

// Shift in
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Dimming data
        if (vclk_msk_ram.dout[$high(vclk_msk_ram.dout)])
            vclk_drv.shft_in <= vclk_dim_ram.dout;
        
        // Static look up
        else
        begin
            case (vclk_msk_ram.dout[0+:$size(vclk_msk_ram.dout)-1])
                'd1 :  vclk_drv.shft_in <= 'h10;
                'd2 :  vclk_drv.shft_in <= 'h100;
                'd3 :  vclk_drv.shft_in <= 'h1000;
                'd4 :  vclk_drv.shft_in <= 'h2000;
                'd5 :  vclk_drv.shft_in <= 'h4000;
                'd6 :  vclk_drv.shft_in <= 'h8000;
                'd7 :  vclk_drv.shft_in <= 'hf000;
                default : vclk_drv.shft_in <= 0;
            endcase
        end
    end

// Shift register
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Run
        if (vclk_ctl.run)
        begin
            // Load
            if (vclk_drv.shft_ld)
                vclk_drv.shft <= vclk_drv.shft_in;

            // Next
            else if (vclk_drv.shft_nxt)
                vclk_drv.shft <= {vclk_drv.shft[$high(vclk_drv.shft)-1:0], 1'b0};
        end

        else
            vclk_drv.shft <= 0;

    end

// Shift counter
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Load
        if (vclk_drv.shft_ld)
            vclk_drv.shft_cnt <= 'd15;

        // Decrement
        else if (vclk_drv.shft_nxt)
            vclk_drv.shft_cnt <= vclk_drv.shft_cnt - 'd1;
    end

// Shift counter end
    always_comb
    begin   
        if (vclk_drv.shft_cnt == 0)
            vclk_drv.shft_cnt_end = 1;
        else
            vclk_drv.shft_cnt_end = 0;
    end

// Zone counter
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Clear
        if (vclk_drv.zone_cnt_clr)
            vclk_drv.zone_cnt <= 0;

        // Increment
        else if (vclk_drv.zone_cnt_inc)
            vclk_drv.zone_cnt <= vclk_drv.zone_cnt + 'd1;
    end

// Zone counter end
    always_comb
    begin   
        if (vclk_drv.zone_cnt == vclk_ctl.zones)
            vclk_drv.zone_cnt_end = 1;
        else
            vclk_drv.zone_cnt_end = 0;
    end

// LED clock
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Run
        if (vclk_ctl.run)
        begin
            // Set
            if (vclk_drv.led_clk_set)
                vclk_drv.led_clk <= 1;

            // Clear
            else if (vclk_drv.led_clk_clr)
                vclk_drv.led_clk <= 0;
        end

        else
            vclk_drv.led_clk <= 0;

    end

// LED clock register
    always_ff @ (posedge VID_CLK_IN)
    begin
        vclk_drv.led_clk_reg <= vclk_drv.led_clk;
    end

// LED data
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Run
        if (vclk_ctl.run)
        begin
            vclk_drv.led_dat <= vclk_drv.shft[$high(vclk_drv.shft)];
        end

        else
            vclk_drv.led_dat <= 0;
    end

// LED data register
    always_ff @ (posedge VID_CLK_IN)
    begin
        vclk_drv.led_dat_reg <= vclk_drv.led_dat;
    end

// MASK RAM

// Address
// The address will auto increment
    always_ff @ (posedge SYS_CLK_IN)
    begin
        // Clear
        if (LPB_CLR_IN)
            sclk_msk_ram.adr <= 0;

        // Increment
        else if (LPB_VLD_IN)
            sclk_msk_ram.adr <= sclk_msk_ram.adr + 'd1;
    end

// Data
    assign sclk_msk_ram.din = LPB_DAT_IN[0+:$size(sclk_msk_ram.din)];
    assign sclk_msk_ram.wr  = LPB_VLD_IN;

	prt_fald_lib_sdp_ram_dc
	#(
		.P_VENDOR		(P_VENDOR),
		.P_RAM_STYLE	("block"),	            // "distributed", "block" or "ultra"
		.P_ADR_WIDTH 	(P_MSK_RAM_ADR),
		.P_DAT_WIDTH 	(P_MSK_RAM_DAT)
	)
	MSK_RAM_INST
	(
		// Port A
		.A_RST_IN		(~sclk_ctl.run),	    // Reset
		.A_CLK_IN		(SYS_CLK_IN),		    // Clock
		.A_ADR_IN		(sclk_msk_ram.adr),	    // Address
		.A_WR_IN		(sclk_msk_ram.wr),		// Write in
		.A_DAT_IN		(sclk_msk_ram.din),	    // Write data

		// Port B
		.B_RST_IN		(~vclk_ctl.run),	    // Reset
		.B_CLK_IN		(VID_CLK_IN),		    // Clock
		.B_ADR_IN		(vclk_msk_ram.adr),	    // Address
		.B_RD_IN		(vclk_msk_ram.rd),		// Read in
		.B_DAT_OUT		(vclk_msk_ram.dout),    // Read data
		.B_VLD_OUT		(vclk_msk_ram.vld)		// Read data valid
	);

    assign vclk_msk_ram.adr = vclk_drv.zone_cnt[0+:$size(vclk_msk_ram.adr)];

// DIM RAM

// Write address
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Clear
        if (DDS_INIT_IN)
            vclk_dim_ram.wr_adr <= 0;
        
        // Increment
        else if (DDS_VLD_IN)
            vclk_dim_ram.wr_adr <= vclk_dim_ram.wr_adr + 'd1;
    end

    assign vclk_dim_ram.din = DDS_DAT_IN;
    assign vclk_dim_ram.wr = DDS_VLD_IN;

	prt_fald_lib_sdp_ram_dc
	#(
		.P_VENDOR		(P_VENDOR),
		.P_RAM_STYLE	("block"),	        // "distributed", "block" or "ultra"
		.P_ADR_WIDTH 	(P_DIM_RAM_ADR),
		.P_DAT_WIDTH 	(P_DIM_RAM_DAT)
	)
	DIM_RAM_INST
	(
		// Port A
		.A_RST_IN		(~vclk_ctl.run),	    // Reset
		.A_CLK_IN		(VID_CLK_IN),		    // Clock
		.A_ADR_IN		(vclk_dim_ram.wr_adr),  // Address
		.A_WR_IN		(vclk_dim_ram.wr),		// Write in
		.A_DAT_IN		(vclk_dim_ram.din),	    // Write data

		// Port B
		.B_RST_IN		(~vclk_ctl.run),	    // Reset
		.B_CLK_IN		(VID_CLK_IN),		    // Clock
		.B_ADR_IN		(vclk_dim_ram.rd_adr),	// Address
		.B_RD_IN		(vclk_dim_ram.rd),		// Read in
		.B_DAT_OUT		(vclk_dim_ram.dout),	// Read data
		.B_VLD_OUT		(vclk_dim_ram.vld)		// Read data valid
	);

    assign vclk_dim_ram.rd_adr = vclk_drv.zone_cnt[0+:$size(vclk_dim_ram.rd_adr)];

// Outputs
    assign LED_CLK_OUT = vclk_drv.led_clk_reg;
    assign LED_DAT_OUT = vclk_drv.led_dat_reg;

endmodule

`default_nettype wire
