/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Full array local dimming 
    (c) 2023 by Parretto B.V.

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

module prt_fald_dim
#(
	parameter 					P_VENDOR = "none",	// Vendor
    parameter                   P_BPC = 8               // Bits per component
)
(
    // Reset and clock
    input wire                  SYS_RST_IN,             // Reset
    input wire                  SYS_CLK_IN,             // Clock

    // Control
    input wire                  CTL_RUN_IN,             // Run
    input wire  [7:0]           CTL_GAIN_IN,            // Gain
    input wire  [7:0]           CTL_BIAS_IN,            // Bias
    input wire  [7:0]           CTL_BLK_W_IN,       	// Block width
    input wire  [7:0]           CTL_BLK_H_IN,      		// Block height
    input wire  [7:0]           CTL_ZONE_W_IN,      	// Zone width
    input wire  [7:0]           CTL_ZONE_H_IN,     		// Zone height

    // Video in
    input wire                  VID_CLK_IN,             // Clock
    input wire              	VID_VS_IN,              // Vsync
    input wire              	VID_HS_IN,              // Hsync
	input wire [P_BPC-1:0]     	VID_Y_IN,		        // Luma
    input wire                  VID_DE_IN,              // Data enable

    // Dimming data stream
    output wire 				DDS_INIT_OUT,			// Init
    output wire [15:0]          DDS_DAT_OUT,			// Data
    output wire           		DDS_VLD_OUT				// Valid
);

// Parameters
localparam P_RAM_WRDS = 256;
localparam P_RAM_ADR = $clog2(P_RAM_WRDS);
localparam P_RAM_DAT = P_BPC;

// Typedef
typedef enum {
    sm_idle, sm_s0, sm_s1, sm_s2, sm_s3, sm_s4
} sm_state;

// Structures
typedef struct {
    logic                 	run;
    logic [7:0]           	gain;
    logic [7:0]           	bias;
    logic [7:0]           	blk_w;
    logic [7:0]           	blk_h;
    logic [7:0]           	zone_w;
    logic [7:0]           	zone_h;
} ctl_struct;

typedef struct {
	logic 					vs_re;
	logic 					hs_re;
	logic 					de;
	logic 					de_re;
	logic 					de_fe;
    logic [P_BPC-1:0]		y;
} vid_struct;

typedef struct {
    sm_state            	sm_cur;
    sm_state                sm_nxt;
	logic 					blk_x_clr;
	logic 					blk_x_inc;
	logic [7:0]				blk_x;
	logic 					blk_x_end;
	logic 					blk_y_clr;
	logic 					blk_y_inc;
	logic [7:0]				blk_y;
	logic 					blk_y_str;
	logic 					blk_y_end;
	logic 					zone_x_clr;
	logic 					zone_x_inc;
	logic [7:0]				zone_x;
	logic 					zone_x_end;
	logic 					zone_y_clr;
	logic 					zone_y_inc;
	logic [7:0]				zone_y;
	logic 					zone_y_end;
	logic [P_BPC+1:0]		sum;
	logic [P_BPC-1:0]		acc;
} dim_struct;

typedef struct {
    logic [P_RAM_ADR-1:0]	wr_adr;
    logic 					wr;
    logic [P_RAM_DAT-1:0]	din;
    logic [P_RAM_ADR-1:0]	rd_adr;
    logic 					rd;
    logic [P_RAM_DAT-1:0]	dout;
	logic 					vld;
} ram_struct;

typedef struct {
	logic 					init_set;
	logic 					init;
	logic [15:0]			dat;
	logic 					vld_set;
	logic 					vld;
} dds_struct;

// Signals
ctl_struct      vclk_ctl;
vid_struct      vclk_vid;
dim_struct     	vclk_dim;
ram_struct     	vclk_ram;
dds_struct     	vclk_dds;

genvar i;

// Logic

// Run clock domain crossing
    prt_fald_lib_cdc_bit
    RUN_CDC_INST
    (
        .SRC_CLK_IN     (SYS_CLK_IN),       // Clock
        .SRC_DAT_IN     (CTL_RUN_IN), 	    // Data
        .DST_CLK_IN     (VID_CLK_IN),       // Clock
        .DST_DAT_OUT	(vclk_ctl.run)  	// Data
    );

// Gain clock domain crossing
	prt_fald_lib_cdc_vec
	#(
		.P_WIDTH 		($size(CTL_GAIN_IN))
	)
	GAIN_CDC_INST
	(
		.SRC_CLK_IN		(SYS_CLK_IN),		    // Clock
		.SRC_DAT_IN		(CTL_GAIN_IN),		    // Data
		.DST_CLK_IN		(VID_CLK_IN),		    // Clock
		.DST_DAT_OUT	(vclk_ctl.gain)		    // Data
	);

// Bias clock domain crossing
	prt_fald_lib_cdc_vec
	#(
		.P_WIDTH 		($size(CTL_BIAS_IN))
	)
	BIAS_CDC_INST
	(
		.SRC_CLK_IN		(SYS_CLK_IN),		    // Clock
		.SRC_DAT_IN		(CTL_BIAS_IN),		    // Data
		.DST_CLK_IN		(VID_CLK_IN),		    // Clock
		.DST_DAT_OUT	(vclk_ctl.bias)		    // Data
	);

// Block width clock domain crossing
	prt_fald_lib_cdc_vec
	#(
		.P_WIDTH 		($size(CTL_BLK_W_IN))
	)
	BLK_W_CDC_INST
	(
		.SRC_CLK_IN		(SYS_CLK_IN),		    // Clock
		.SRC_DAT_IN		(CTL_BLK_W_IN),			// Data
		.DST_CLK_IN		(VID_CLK_IN),		    // Clock
		.DST_DAT_OUT	(vclk_ctl.blk_w)		// Data
	);

// Block height clock domain crossing
	prt_fald_lib_cdc_vec
	#(
		.P_WIDTH 		($size(CTL_BLK_H_IN))
	)
	BLK_H_CDC_INST
	(
		.SRC_CLK_IN		(SYS_CLK_IN),		    // Clock
		.SRC_DAT_IN		(CTL_BLK_H_IN),    		// Data
		.DST_CLK_IN		(VID_CLK_IN),		    // Clock
		.DST_DAT_OUT	(vclk_ctl.blk_h)		// Data
	);

// Zone width clock domain crossing
	prt_fald_lib_cdc_vec
	#(
		.P_WIDTH 		($size(CTL_ZONE_W_IN))
	)
	ZONE_W_CDC_INST
	(
		.SRC_CLK_IN		(SYS_CLK_IN),		    // Clock
		.SRC_DAT_IN		(CTL_ZONE_W_IN),		// Data
		.DST_CLK_IN		(VID_CLK_IN),		    // Clock
		.DST_DAT_OUT	(vclk_ctl.zone_w)		// Data
	);

// Zone height clock domain crossing
	prt_fald_lib_cdc_vec
	#(
		.P_WIDTH 		($size(CTL_ZONE_H_IN))
	)
	ZONE_H_CDC_INST
	(
		.SRC_CLK_IN		(SYS_CLK_IN),		    // Clock
		.SRC_DAT_IN		(CTL_ZONE_H_IN),    	// Data
		.DST_CLK_IN		(VID_CLK_IN),		    // Clock
		.DST_DAT_OUT	(vclk_ctl.zone_h)	 	// Data
	);

// Vsync rising edge
    prt_fald_lib_edge
    VS_EDGE_INST
    (
        .CLK_IN         (VID_CLK_IN),           // Clock
        .CKE_IN         (1'b1),                 // Clock enable
        .A_IN           (VID_VS_IN),            // Input
        .RE_OUT         (vclk_vid.vs_re),   	// Rising edge
        .FE_OUT         ()                      // Falling edge
    );

// Hsync rising edge
    prt_fald_lib_edge
    HS_EDGE_INST
    (
        .CLK_IN         (VID_CLK_IN),           // Clock
        .CKE_IN         (1'b1),                 // Clock enable
        .A_IN           (VID_HS_IN),            // Input
        .RE_OUT         (vclk_vid.hs_re),   	// Rising edge
        .FE_OUT         ()                      // Falling edge
    );

// DE rising edge
    prt_fald_lib_edge
    DE_EDGE_INST
    (
        .CLK_IN         (VID_CLK_IN),           // Clock
        .CKE_IN         (1'b1),                 // Clock enable
        .A_IN           (VID_DE_IN),            // Input
        .RE_OUT         (vclk_vid.de_re),   	// Rising edge
        .FE_OUT         (vclk_vid.de_fe)        // Falling edge
    );

// Video inputs
    always_ff @ (posedge VID_CLK_IN)
    begin
		vclk_vid.y <= VID_Y_IN;
		vclk_vid.de <= VID_DE_IN;
	end

// Sum
	assign vclk_dim.sum = vclk_dim.acc + vclk_vid.y + 'd1;

// Accu
	always_ff @ (posedge VID_CLK_IN)
	begin
		// Load at start block
		if ((vclk_dim.blk_x == 0) && vclk_vid.de && vclk_dim.blk_y_str)
			vclk_dim.acc <= vclk_vid.y;
		
		// Load next block
		else if (vclk_ram.vld)
			vclk_dim.acc <= vclk_ram.dout;
		
		// Increment
		else if (vclk_vid.de)
			vclk_dim.acc <= vclk_dim.sum[1+:$size(vclk_dim.acc)];
	end

// Block x
    always_ff @ (posedge VID_CLK_IN)
    begin
		// Clear
		if (vclk_dim.blk_x_clr)
			vclk_dim.blk_x <= 0;
		
		// Increment
		else if (vclk_vid.de)
			vclk_dim.blk_x <= vclk_dim.blk_x + 'd1;
    end

// Block x end
    always_ff @ (posedge VID_CLK_IN)
	begin
		if (vclk_dim.blk_x == (vclk_ctl.blk_w[$high(vclk_ctl.blk_w):2] - 'd2))	// Divide by four
			vclk_dim.blk_x_end <= 1;
		else
			vclk_dim.blk_x_end <= 0;
	end

// Block y
    always_ff @ (posedge VID_CLK_IN)
    begin
		// Clear
		if (vclk_dim.blk_y_clr)
			vclk_dim.blk_y <= 0;
		
		// Increment
		else if (vclk_vid.de_fe)
			vclk_dim.blk_y <= vclk_dim.blk_y + 'd1;
    end

// Block y start
    always_ff @ (posedge VID_CLK_IN)
	begin
		if (vclk_dim.blk_y == 0)
			vclk_dim.blk_y_str <= 1;
		else
			vclk_dim.blk_y_str <= 0;
	end

// Block y end
    always_ff @ (posedge VID_CLK_IN)
	begin
		if (vclk_dim.blk_y == (vclk_ctl.blk_h - 'd1))
			vclk_dim.blk_y_end <= 1;
		else
			vclk_dim.blk_y_end <= 0;
	end

// Zone x 
    always_ff @ (posedge VID_CLK_IN)
    begin
		// Clear
		if (vclk_dim.zone_x_clr)
			vclk_dim.zone_x <= 0;
		
		// Increment
		else if (vclk_dim.zone_x_inc)
			vclk_dim.zone_x <= vclk_dim.zone_x + 'd1;
    end

// Zone x end
    always_ff @ (posedge VID_CLK_IN)
	begin
		if (vclk_dim.zone_x == (vclk_ctl.zone_w - 'd1))
			vclk_dim.zone_x_end <= 1;
		else
			vclk_dim.zone_x_end <= 0;
	end

// Zone y 
    always_ff @ (posedge VID_CLK_IN)
    begin
		// Clear
		if (vclk_dim.zone_y_clr)
			vclk_dim.zone_y <= 0;
		
		// Increment
		else if (vclk_dim.zone_y_inc)
			vclk_dim.zone_y <= vclk_dim.zone_y + 'd1;
    end

// Zone y end
    always_ff @ (posedge VID_CLK_IN)
	begin
		if (vclk_dim.zone_y == vclk_ctl.zone_h)
			vclk_dim.zone_y_end <= 1;
		else
			vclk_dim.zone_y_end <= 0;
	end

// State machine
    always_ff @ (posedge VID_CLK_IN)
    begin
        // Run
        if (vclk_ctl.run)
        begin
            if (vclk_vid.vs_re)
                vclk_dim.sm_cur <= sm_s0;
            else
                vclk_dim.sm_cur <= vclk_dim.sm_nxt;
        end

        else
            vclk_dim.sm_cur <= sm_idle;
    end

// State machine decoder
    always_comb
    begin
        // Defaults
		vclk_dim.blk_x_clr = 0;
		vclk_dim.blk_y_clr = 0;
		vclk_dim.zone_x_clr = 0;
		vclk_dim.zone_x_inc = 0;
		vclk_dim.zone_y_clr = 0;
		vclk_dim.zone_y_inc = 0;
		vclk_ram.wr = 0;
		vclk_ram.rd = 0;
		vclk_dds.init_set = 0;
		vclk_dds.vld_set = 0;

        case (vclk_dim.sm_cur)

            sm_idle :
            begin
                vclk_dim.sm_nxt = sm_idle;
            end

			sm_s0 : 
			begin
				vclk_dim.blk_x_clr = 1;
				vclk_dim.blk_y_clr = 1;
				vclk_dim.zone_x_clr = 1;
				vclk_dim.zone_y_clr = 1;
				vclk_dds.init_set = 1;
                vclk_dim.sm_nxt = sm_s1;
			end

			sm_s1 : 
			begin
				if (vclk_dim.blk_x_end)
				begin				
					vclk_dim.blk_x_clr = 1;

					if (!vclk_dim.blk_y_str)
						vclk_ram.rd = 1;
	                vclk_dim.sm_nxt = sm_s2;
				end

				else
	                vclk_dim.sm_nxt = sm_s1;
			end

			sm_s2 : 
			begin
				if (vclk_dim.blk_y_end)
					vclk_dds.vld_set = 1;
				else
					vclk_ram.wr = 1;

				if (vclk_dim.zone_x_end)
				begin
					vclk_dim.zone_x_clr = 1;

					if (vclk_dim.blk_y_end)
	                begin
						vclk_dim.blk_y_clr = 1;
						vclk_dim.sm_nxt = sm_s1;
					end

					else	
						vclk_dim.sm_nxt = sm_s3;
				end

				else
				begin
					vclk_dim.zone_x_inc = 1;
	                vclk_dim.sm_nxt = sm_s1;
				end
			end

			sm_s3 : 
			begin
				vclk_ram.rd = 1;
                vclk_dim.sm_nxt = sm_s1;
			end

			default : 
			begin
	        	vclk_dim.sm_nxt = sm_idle;
			end

		endcase
	end


// RAM
// This is where the temporary values are stored

	// Write and read address
	always_ff @ (posedge VID_CLK_IN)
	begin
		vclk_ram.wr_adr <= vclk_dim.zone_x[0+:$size(vclk_ram.wr_adr)];
		if (vclk_dim.zone_x_end)
			vclk_ram.rd_adr <= 0;
		else
			vclk_ram.rd_adr <= vclk_dim.zone_x[0+:$size(vclk_ram.rd_adr)] + 'd1;
	end

	assign vclk_ram.din = vclk_dim.acc;

	prt_fald_lib_sdp_ram_dc
	#(
		.P_VENDOR		(P_VENDOR),
		.P_RAM_STYLE	("block"),	        // "distributed", "block" or "ultra"
		.P_ADR_WIDTH 	(P_RAM_ADR),
		.P_DAT_WIDTH 	(P_RAM_DAT)
	)
	RAM_INST
	(
		// Port A
		.A_RST_IN		(~vclk_ctl.run),		// Reset
		.A_CLK_IN		(VID_CLK_IN),			// Clock
		.A_ADR_IN		(vclk_ram.wr_adr),	   	// Address
		.A_WR_IN		(vclk_ram.wr),			// Write in
		.A_DAT_IN		(vclk_ram.din),	    	// Write data

		// Port B
		.B_RST_IN		(~vclk_ctl.run),		// Reset
		.B_CLK_IN		(VID_CLK_IN),			// Clock
		.B_ADR_IN		(vclk_ram.rd_adr),	    // Address
		.B_RD_IN		(vclk_ram.rd),			// Read in
		.B_DAT_OUT		(vclk_ram.dout),	   	// Read data
		.B_VLD_OUT		(vclk_ram.vld)			// Read data valid
	);

// Dimming data stream
// Data
	always_ff @ (posedge VID_CLK_IN)
	begin
		vclk_dds.dat <= (vclk_dim.acc * vclk_ctl.gain) + vclk_ctl.bias;
	end

// Init
	always_ff @ (posedge VID_CLK_IN)
	begin
		// Set
		if (vclk_dds.init_set)
			vclk_dds.init <= 1;
		else
			vclk_dds.init <= 0;
	end

// Valid
	always_ff @ (posedge VID_CLK_IN)
	begin
		// Set
		if (vclk_dds.vld_set)
			vclk_dds.vld <= 1;
		else
			vclk_dds.vld <= 0;
	end

// Outputs
	assign DDS_INIT_OUT = vclk_dds.init;
	assign DDS_DAT_OUT = vclk_dds.dat;
	assign DDS_VLD_OUT = vclk_dds.vld;


endmodule

`default_nettype wire
