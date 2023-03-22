/*
	DP PHY
	This module emulates the latency in the RX PHY

	(c) 2021 by Parretto
	Written by Marco Groeneveld
*/

module dp_phy
#(
	parameter P_LANE = 0,		// Lane index
	parameter P_DLY = 2,		// Word delay
	parameter P_SPL = 2			// Sublanes per lane
)
(
	input wire 							CLK_IN,
	input wire [(P_SPL * 11)-1:0] 		DAT_IN,
	output wire [(P_SPL * 11)-1:0]		DAT_OUT
);

// Signals
logic [10:0] 	buffer[0:P_SPL-1][0:1];

genvar j;

// Buffer
generate
	for (j = 0; j < P_SPL; j++)
	begin
		always_ff @ (posedge CLK_IN)
		begin
			for (int i = 0; i < 2; i++)
			begin
				if (i == 0)
					buffer[j][i] <= DAT_IN[(j*11)+:11];
				else
					buffer[j][i] <= buffer[j][i-1];
			end
		end
	end
endgenerate

// Outputs
generate

	// Four symbols per lane
	if (P_SPL == 4)
	begin : gen_4spl
	
		// Lane 0
		// For lane 0 all sublanes are aligned (phase 0)
		if (P_LANE == 0)
		begin
			assign DAT_OUT[(0*11)+:11] = buffer[0][0];
			assign DAT_OUT[(1*11)+:11] = buffer[1][0];
			assign DAT_OUT[(2*11)+:11] = buffer[2][0];
			assign DAT_OUT[(3*11)+:11] = buffer[3][0];
		end

		// Lane 1
		// For lane 1 the data appears one sublane shifted (phase 1)
		else if (P_LANE == 1)
		begin
			assign DAT_OUT[(0*11)+:11] = buffer[3][1];
			assign DAT_OUT[(1*11)+:11] = buffer[0][0];
			assign DAT_OUT[(2*11)+:11] = buffer[1][0];
			assign DAT_OUT[(3*11)+:11] = buffer[2][0];

		end

		// Lane 2
		// For lane 2 the data appears two sublanes shifted (phase 2)
		else if (P_LANE == 2)
		begin
			assign DAT_OUT[(0*11)+:11] = buffer[2][1];
			assign DAT_OUT[(1*11)+:11] = buffer[3][1];
			assign DAT_OUT[(2*11)+:11] = buffer[0][0];
			assign DAT_OUT[(3*11)+:11] = buffer[1][0];
		end

		// Lane 3
		// For lane 3 the data appears three sublanes shifted (phase 2)
		else 
		begin
			assign DAT_OUT[(0*11)+:11] = buffer[1][1];
			assign DAT_OUT[(1*11)+:11] = buffer[2][1];
			assign DAT_OUT[(2*11)+:11] = buffer[3][1];
			assign DAT_OUT[(3*11)+:11] = buffer[0][0];
		end
	end

	// Two symbols per lane
	else
	begin : gen_2spl
	
		// Lane 0 and 2
		// For lane 0 and 2 all sublanes are aligned (phase 0)
		if ((P_LANE == 0) || (P_LANE == 2))
		begin
			assign DAT_OUT[(0*11)+:11] = buffer[0][0];
			assign DAT_OUT[(1*11)+:11] = buffer[1][0];
		end

		// Lane 1 and 3
		// For lane 1 and 3 the data appears one sublane shifted (phase 1)
		else 
		begin
			assign DAT_OUT[(0*11)+:11] = buffer[1][1];
			assign DAT_OUT[(1*11)+:11] = buffer[0][0];
		end
	end

endgenerate

endmodule


