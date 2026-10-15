/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Heartbeat
    (c) 2021 - 2025 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Breathing PWM heartbeat (gamma corrected)

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

module prt_hb
#(
	parameter 		P_BEAT = 100
)
(
	input wire 		CLK_IN,
	output wire		LED_OUT
);

// Breathing heartbeat.
// A free-running PWM whose brightness ramps slowly up and down (triangle), gamma
// corrected (duty = ramp^2) so the fade looks even to the eye. P_BEAT sets the ramp
// step interval; a full breathe cycle (up + down) takes about 2 * P_BEAT clocks.

// Parameters
localparam P_STEP = (P_BEAT >> 8) > 0 ? (P_BEAT >> 8) : 1;   // Clocks per brightness step

// Signals
logic [7:0]		pwm_cnt;		// Free-running PWM sub-counter
logic [7:0]		ramp;			// Triangle ramp 0..255..0
logic 			dir;			// Ramp direction (0 - up / 1 - down)
logic [31:0]	step_cnt;		// Ramp step timer
logic [15:0]	ramp_sq;		// ramp^2 (full 16-bit product)
logic [7:0]		duty;			// Gamma corrected duty

// PWM sub-counter (fast, free running). PWM frequency = CLK_IN / 256.
	always_ff @ (posedge CLK_IN)
		pwm_cnt <= pwm_cnt + 'd1;

// Ramp step timer and triangle ramp
	always_ff @ (posedge CLK_IN)
	begin
		// Step
		if (step_cnt >= P_STEP)
		begin
			step_cnt <= 0;

			// Up
			if (!dir)
			begin
				if (ramp == 8'hff)
					dir <= 1;
				else
					ramp <= ramp + 'd1;
			end

			// Down
			else
			begin
				if (ramp == 8'h00)
					dir <= 0;
				else
					ramp <= ramp - 'd1;
			end
		end

		// Increment
		else
			step_cnt <= step_cnt + 'd1;
	end

// Gamma correction (duty = ramp^2, upper 8 bits).
// The product is computed into a 16-bit signal so the full ramp^2 is kept; taking the
// upper 8 bits (ramp_sq[15:8]) then gives ramp^2 >> 8. Doing (ramp * ramp) >> 8 inline
// would evaluate the multiply in the 8-bit context of duty, truncate the product to 8 bits,
// and shift it away to 0.
	assign ramp_sq = ramp * ramp;

	always_ff @ (posedge CLK_IN)
		duty <= ramp_sq[15:8];

// Outputs
// The board LEDs are active-low, so invert: the LED is physically on (LED_OUT = 0) while
// pwm_cnt < duty, giving an on-fraction of duty/256 and a smooth dark-to-bright breathe.
	assign LED_OUT = (pwm_cnt >= duty);

endmodule

`default_nettype wire
