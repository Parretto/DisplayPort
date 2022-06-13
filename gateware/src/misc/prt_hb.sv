/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Heartbeat
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

module prt_hb
#(
	parameter 		P_BEAT = 100
)
(
	input wire 		CLK_IN,
	output wire		LED_OUT
);

logic 			clk_led;
logic [31:0]	clk_cnt;

	always_ff @ (posedge CLK_IN)
	begin
		if (clk_cnt > P_BEAT)
		begin
			clk_led <= ~clk_led;
			clk_cnt <= 0;
		end
		
		else
			clk_cnt <= clk_cnt + 'd1;
	end

// Outputs
	assign LED_OUT = clk_led;

endmodule

`default_nettype wire
