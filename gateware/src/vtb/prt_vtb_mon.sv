/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Video Toolbox Monitor
    (c) 2021 - 2024 by Parretto B.V.

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

module prt_vtb_mon
(
	// Reset and clock
	input wire					RST_IN,			// Reset
	input wire 					CLK_IN,			// Clock

	// Video in
	input wire 					VID_SOF_IN,        // Start of frame
	input wire         			VID_EOL_IN,        // End of line
	input wire          		VID_VLD_IN,        // Valid

	// Status
	output wire [15:0]			STA_PIX_OUT,
	output wire [15:0]			STA_LIN_OUT
);

// Structures
typedef struct {
	logic 						sof;
	logic						eol;
	logic						vld;
	logic [15:0]				pix_cnt;
	logic [15:0]				pix;
	logic [15:0]				lin_cnt;
	logic [15:0]				lin;
} vid_struct;

// Signals
vid_struct 	clk_vid;

// Input registers
	always_ff @ (posedge CLK_IN)
	begin
		clk_vid.sof <= VID_SOF_IN;
		clk_vid.eol <= VID_EOL_IN;
		clk_vid.vld <= VID_VLD_IN;
	end

// Pixel counter
	always_ff @ (posedge CLK_IN)
	begin
		// Clear
		if (clk_vid.eol && clk_vid.vld)
		begin
			clk_vid.pix_cnt <= 'd2;
			clk_vid.pix <= clk_vid.pix_cnt;
		end

		else if (clk_vid.vld)
			clk_vid.pix_cnt <= clk_vid.pix_cnt + 'd2;
	end

// Line counter
	always_ff @ (posedge CLK_IN)
	begin
		// Clear
		if (clk_vid.sof && clk_vid.vld)
		begin
			clk_vid.lin_cnt <= 'd0;
			clk_vid.lin <= clk_vid.lin_cnt;
		end

		else if (clk_vid.eol && clk_vid.vld)
			clk_vid.lin_cnt <= clk_vid.lin_cnt + 'd1;
	end

// Output
	assign STA_PIX_OUT = clk_vid.pix;
	assign STA_LIN_OUT = clk_vid.lin;

endmodule

`default_nettype wire
