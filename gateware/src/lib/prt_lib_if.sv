/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Library Interfaces
    (c) 2024 - 2025 by Parretto B.V.

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
	Local bus interface
*/
interface prt_lb_if
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
interface prt_axil_if
#(
	parameter P_ADR_WIDTH = 32				// Address width
);
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
	
	modport mst (	output awadr, output awvalid, input awready,
					output wdata, output wvalid, input wready,
					input bresp, input bvalid, output bready,
					output aradr, output arvalid, input arready,
					input rdata, input rresp, input rvalid, output rready);
	
	modport slv	(	input awadr, input awvalid, output awready,
					input wdata, input wvalid, output wready,
					output bresp, output bvalid, input bready,
					input aradr, input arvalid, output arready,
					output rdata, output rresp, output rvalid, input rready);
endinterface

/*
	AXI4-Stream video interface
*/
interface prt_axis_if
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
interface prt_msg_if
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
	APB interface
*/
interface prt_apb_if
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
	logic 						pslverr;

	modport mst (	output psel, output penable, output paddr, output pwrite, 
					output pwdata, input prdata, input pready, input pslverr
					);

	modport slv (	input psel, input penable, input paddr, input pwrite, 
					input pwdata, output prdata, output pready, output pslverr
					);

endinterface

/*
	AHB interface
*/
interface prt_ahb_if
#(
	parameter P_ADR_WIDTH = 32				// Address width
);

	logic	[P_ADR_WIDTH-1:0] 	haddr;
	logic 	[2:0]				hburst;
	logic 	[3:0]				hprot;
	logic	[31:0]				hrdata;
	logic 	[2:0]				hsize;
	logic 	[1:0]				htrans;
	logic	[31:0]				hwdata;
	logic 						hmastlock;
	logic 						hready_mst;
	logic 						hready_slv;
	logic 						hresp;
	logic 						hsel;
	logic 						hwrite;

	modport mst (	output haddr, output hburst, output hprot,  
					input hrdata, output hsize,  output htrans, output hwdata,
					output hmastlock, output hready_mst, input hready_slv, 
					input hresp, output hsel, output hwrite
					);

	modport slv (	input haddr, input hburst, input hprot,  
					output hrdata, input hsize,  input htrans, input hwdata,
					input hmastlock, input hready_mst, output hready_slv, 
					output hresp, input hsel, input hwrite
					);

endinterface


`default_nettype wire
