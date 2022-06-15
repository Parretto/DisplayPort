/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP Application Interfaces
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

/*
	ROM interface
*/
interface prt_dp_app_rom_if
#(
	parameter P_ADR_WIDTH = 16				// Address width
);
	logic	[P_ADR_WIDTH-1:0] 	adr;
	logic	[31:0]			dat;
	logic					req;
	logic					ack;
	modport mst (output adr, input dat, output req, input ack);
	modport slv (input adr, output dat, input req, output ack);

endinterface

/*
	RAM interface
*/
interface prt_dp_app_ram_if
#(
	parameter P_ADR_WIDTH = 16				// Address width
);
	logic	[P_ADR_WIDTH-1:0] 	adr;
	logic					wr;
	logic	[3:0]			msk;
	logic	[31:0]			din;
	logic	[31:0]			dout;
	logic					req;
	logic					ack;

	modport mst (output adr, output wr, output msk, output dout, input din, output req, input ack);
	modport slv (input adr, input wr, input din, input msk, output dout, input req, output ack);

endinterface

`default_nettype wire
