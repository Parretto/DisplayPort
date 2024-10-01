/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP Library Interfaces
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

/*
	ROM interface
*/
interface prt_dp_rom_if
#(
	parameter P_ADR_WIDTH = 16				// Address width
);
	logic	[P_ADR_WIDTH-1:0] 	adr;
	logic	[31:0]				dat;

	modport mst	(output adr, input dat);
	modport slv (input adr, output dat);

endinterface

/*
	RAM interface
*/
interface prt_dp_ram_if
#(
	parameter P_ADR_WIDTH = 16				// Address width
);
	logic	[P_ADR_WIDTH-1:0] 	wr_adr;
	logic	[P_ADR_WIDTH-1:0] 	rd_adr;
	logic						wr;
	logic						rd;
	logic	[31:0]				dout;
	logic	[3:0]				strb;
	logic	[31:0]				din;

	modport mst	(output wr_adr, output rd_adr, output wr, output rd, output dout, output strb, input din);
	modport slv (input wr_adr, input rd_adr, input wr, input rd, input din, input strb, output dout);

endinterface

/*
	Local bus interface
*/
interface prt_dp_lb_if
#(
	parameter P_ADR_WIDTH = 32				// Address width
);
	logic	[P_ADR_WIDTH-1:0] 	adr;
	logic						wr;
	logic						rd;
	logic	[31:0]				dout;
	logic	[31:0]				din;
	logic 						vld;
	
	modport lb_in 	(input adr, input wr, input rd, input din, output dout, output vld);
	modport lb_out	(output adr, output wr, output rd, output din, input dout, input vld);

endinterface

/*
	AXI4-lite interface
*/
interface prt_dp_axil_if
#(
	parameter P_ADR_WIDTH = 32				// Address width
);
	logic 						arst;
	logic	[P_ADR_WIDTH-1:0] 	awadr;
	logic						awvalid;
	logic						awready;
	logic	[31:0]				wdata;
	logic						wvalid;
	logic						wready;
	logic	[1:0]				bresp;
	logic						bvalid;
	logic						bready;
	logic	[P_ADR_WIDTH-1:0] 	aradr;
	logic						arvalid;
	logic						arready;
	logic	[31:0]				rdata;
	logic	[1:0]				rresp;
	logic						rvalid;
	logic						rready;
	
	modport mst (	output arst,
					output awadr, output awvalid, input awready,
					output wdata, output wvalid, input wready,
					input bresp, input bvalid, output bready,
					output aradr, output arvalid, input arready,
					input rdata, input rresp, input rvalid, output rready);
	
	modport slv	(	input arst,
					input awadr, input awvalid, output awready,
					input wdata, input wvalid, output wready,
					output bresp, output bvalid, input bready,
					input aradr, input arvalid, output arready,
					output rdata, output rresp, output rvalid, input rready);
endinterface

/*
	APB interface
*/
interface prt_dp_apb_if
#(
	parameter P_ADR_WIDTH = 32				// Address width
);
	logic 						psel;
	logic	[P_ADR_WIDTH-1:0] 	paddr;
	logic 						pwrite;
	logic	[31:0]				pwdata;
	logic	[31:0]				prdata;
	logic 						pready;
	logic 						penable;

	modport mst (	output psel, output penable, output paddr, output pwrite, 
					output pwdata, input prdata, input pready
					);

	modport slv (	input psel, input penable, input paddr, input pwrite, 
					input pwdata, output prdata, output pready
					);

endinterface

/*
	AXI4-Stream video interface
*/
interface prt_dp_axis_if
#(
	parameter P_DAT_WIDTH = 32		// Data width
);
	logic 						rdy;
	logic 						sof;
	logic 						eol;
	logic	[P_DAT_WIDTH-1:0] 	dat;
	logic						vld;

	modport snk (output rdy, input sof, input eol, input dat, input vld);
	modport src (input rdy, output sof, output eol, output dat, output vld);

endinterface

/*
	Message interface
*/
interface prt_dp_msg_if
#(
	parameter P_DAT_WIDTH = 16
);
	logic						som;	// Start of message
	logic						eom;	// End of message
	logic	[P_DAT_WIDTH-1:0]	dat;
	logic 						vld;
	
	modport snk	(input som, input eom, input dat, input vld);
	modport src	(output som, output eom, output dat, output vld);

endinterface

/*
	Video interface
*/
interface prt_dp_vid_if
#(
	parameter P_PPC = 2,			// Pixels per clock
	parameter P_BPC = 8				// Bits per component
);
	logic   							vs;			// Vsync
	logic   							hs;			// Hsync
	logic	[(P_PPC * P_BPC)-1:0]		dat[0:2];	// Data
	logic   							de;			// Data enable

	modport snk	(input vs, input hs, input dat, input de);
	modport src	(output vs, output hs, output dat, output de);

endinterface


/*
	TX Link interface
*/
interface prt_dp_tx_lnk_if
#(
	parameter P_LANES = 2,			// Lanes
	parameter P_SPL = 2				// Symbols per lane
);
	logic	[5:0]			sym[0:P_LANES-1][0:P_SPL-1];	// Symbol
	logic 	[7:0]			dat[0:P_LANES-1][0:P_SPL-1];	// Data
	logic 					vld;							// Valid
	logic 					rd;								// Read
	modport snk	(input sym, input dat, input vld, output rd);
	modport src	(output sym, output dat, output vld, input rd);

endinterface

/*
	TX PHY interface
*/
interface prt_dp_tx_phy_if
#(
	parameter P_LANES = 2,			// Lanes
	parameter P_SPL = 2				// Symbols per lane
);
	logic	[P_SPL-1:0]		disp_ctl[0:P_LANES-1];			// Disparity control (0-automatic / 1-force)
	logic	[P_SPL-1:0]		disp_val[0:P_LANES-1];			// Disparity value (0-negative / 1-postive) 
	logic	[P_SPL-1:0]		k[0:P_LANES-1];					// k character
	logic 	[7:0]			dat[0:P_LANES-1][0:P_SPL-1];	// Data

	modport snk	(input disp_ctl, input disp_val, input k, input dat);
	modport src	(output disp_ctl, output disp_val, output k, output dat);

endinterface

/*
	RX Link interface
*/
interface prt_dp_rx_lnk_if
#(
	parameter P_LANES = 2,			// Lanes
	parameter P_SPL = 2				// Symbols per lane
);
	logic 					lock;							// Lock
	logic 	[P_SPL-1:0]		sol[0:P_LANES-1];				// Start of line
	logic 	[P_SPL-1:0]		eol[0:P_LANES-1];				// End of line
	logic 	[P_SPL-1:0] 	vid[0:P_LANES-1];				// Video packet
	logic 	[P_SPL-1:0] 	sdp[0:P_LANES-1];				// Secondary data packet
	logic 	[P_SPL-1:0] 	msa[0:P_LANES-1];				// Main stream attributes (msa)
	logic 	[P_SPL-1:0] 	vbid[0:P_LANES-1];				// VB-ID
	logic	[P_SPL-1:0]		k[0:P_LANES-1];					// k character
	logic 	[7:0]			dat[0:P_LANES-1][0:P_SPL-1];	// Data

	modport snk	(input lock, input sol, input eol, input vid, input sdp, input msa, input vbid, input k, input dat);
	modport src	(output lock, output sol, output eol, output vid, output sdp, output msa, output vbid, output k, output dat);

endinterface

/*
	RX SDP interface
*/
interface prt_dp_rx_sdp_if
#();
	logic   			sop;		// Start of packet
	logic   			eop;		// End of packet
	logic	[31:0]		dat;		// Data
	logic   			vld;		// Valid

	modport snk	(input sop, input eop, input dat, input vld);
	modport src	(output sop, output eop, output dat, output vld);

endinterface

`default_nettype wire
