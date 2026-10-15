/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: VTB On Screen Display
    (c) 2021 - 2026 by Parretto B.V.

    History
    =======
    v1.0 - Initial release. Taken from the on screen display of the HDMI video pattern generator
    v1.1 - Added YCbCr 4:4:4 colour space


    Description
    ===========
    A scrolling line of text over the picture, in the style of a Commodore 64 demo: the
    text runs horizontally and the whole line bounces up and down on a sine.

    It sits after the output mux of the video toolbox, so it covers the test pattern and
    pass-through alike. The timing signals are delayed along with the colour, so
    passed-through video keeps its timing to the pixel.

    The text is written by the host as plain ASCII, so the application can put in what it
    already knows - resolution, colour space, bit depth, link - without this module having
    to work any of that out. The font is upper case only, which is what makes it look
    right; the host folds the case.

    Only the colour is replaced. Vsync, Hsync and Data enable pass through, so the video
    timing cannot change no matter what this module does. It is off after reset, because
    the test pattern is also used for compliance measurements and those must not get
    moving text in the picture.

    The scroll steps by one clock per frame. That is what keeps a character on a clock
    boundary and makes a barrel shifter unnecessary: every supported value of P_PPC
    divides P_SCALE, so a clock never straddles two font pixels and a single font bit
    decides the colour of every pixel in that clock. At four to eight pixels per frame and
    60 Hz that is 240 to 480 pixels per second, a normal scroll speed.

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

// Module
module prt_vtb_osd
#(
	parameter P_VENDOR = "none",	// Vendor - "AMD", "ALTERA" or "LSC"
	parameter P_FAMILY = "none", // Family (Only used for Lattice)
	parameter P_PPC = 2,			// Pixels per clock. 1, 2, 4 or 8
	parameter P_BPC = 8,			// Bits per component
	parameter P_TXT_ADR = 7			// Text memory address bits. 7 gives 128 characters
)
(
	// Reset and clock - video domain
	input wire 								RST_IN,			// Reset
	input wire 								CLK_IN,			// Clock
	input wire 								CKE_IN,			// Clock enable

	// Control - video domain, crossed by the caller
	input wire 								CTL_RUN_IN,		// Run
	input wire [2:0]						CTL_AMP_IN,		// Bounce amplitude. Shift on the sine, 0 is the largest
	input wire [3:0]						CTL_SPD_IN,		// Bounce speed. Sine phase step per frame
	input wire [23:0]						CTL_COL_IN,		// Colour of the text. Red, green, blue, eight bits each
	input wire [1:0]						CTL_MODE_IN,	// Colour mode. 0 - plain, 1 - bands, 2 - per character
	input wire 								CTL_CSF_IN,		// Color space of the video. 0 - RGB, 1 - YCbCr 4:4:4

	// Text - system domain
	input wire 								SYS_RST_IN,		// Reset
	input wire 								SYS_CLK_IN,		// Clock
	input wire [P_TXT_ADR-1:0]				TXT_ADR_IN,		// Address
	input wire 								TXT_WR_IN,		// Write
	input wire [7:0]						TXT_DAT_IN,		// Data

	// Video parameter set
	input wire [3:0]						VPS_IDX_IN,		// Index
	input wire [15:0]						VPS_DAT_IN,		// Data
	input wire 								VPS_VLD_IN,		// Valid

	// Native video in
	input wire 								VID_VS_IN,		// Vsync
	input wire 								VID_HS_IN,		// Hsync
	input wire [(P_BPC * P_PPC)-1:0]		VID_R_IN,		// Red
	input wire [(P_BPC * P_PPC)-1:0]		VID_G_IN,		// Green
	input wire [(P_BPC * P_PPC)-1:0]		VID_B_IN,		// Blue
	input wire 								VID_DE_IN,		// Data enable

	// Native video out
	output wire 							VID_VS_OUT,		// Vsync
	output wire 							VID_HS_OUT,		// Hsync
	output wire [(P_BPC * P_PPC)-1:0]		VID_R_OUT,		// Red
	output wire [(P_BPC * P_PPC)-1:0]		VID_G_OUT,		// Green
	output wire [(P_BPC * P_PPC)-1:0]		VID_B_OUT,		// Blue
	output wire 							VID_DE_OUT		// Data enable
);

// Parameters
localparam P_TXT_WRDS = 2**P_TXT_ADR;
localparam P_FONT_CNT = 96;					// Characters in the font. ASCII 0x20 up to 0x7F
localparam P_FONT_FIRST = 8'h20;			// First character in the font
localparam P_SCALE = 8;						// Screen pixels per font pixel
localparam P_SCALE_BITS = $clog2(P_SCALE);
localparam P_CHR_PIX = 8 * P_SCALE;			// Screen pixels of one character. 64
localparam P_ROW_PIX = 8 * P_SCALE;			// Screen lines of one character. 64

// The sine peaks at 127, so a shift of nine leaves about a quarter of the picture height
// either way. See the note at the top line of the text.
localparam P_AMP_SHIFT = 9;

// The colour comes in as eight bits per component, whatever the core carries, so the
// host does not have to know the bit depth. A deeper component is filled from the top.
localparam P_COL_SHIFT = P_BPC - 8;

// The rainbow. Eight hues, indexed by the row inside the character or by the character
// itself, plus a phase that moves on with the bounce - so the colours travel through the
// text the way a Commodore 64 demo does it. Saturated on purpose: the scroller sits over
// a colour bar pattern and has to stay readable.
localparam P_PAL_CNT = 8;
localparam logic [23:0] P_PAL [0:P_PAL_CNT-1] = '{
	24'hFF2020,		// red
	24'hFF8000,		// orange
	24'hFFE000,		// yellow
	24'h40E040,		// green
	24'h20E0E0,		// cyan
	24'h4080FF,		// blue
	24'h8040E0,		// violet
	24'hE040C0		// magenta
};

// The same rainbow in YCbCr 4:4:4 (BT.709, limited range), as {Cr, Y, Cb} in the place of
// red, green and blue. The plain colour (CTL_COL_IN) comes from the host in the colour space
// of the video.
localparam logic [23:0] P_PAL_YUV [0:P_PAL_CNT-1] = '{
	24'hE2546A,		// red
	24'hBD8D3B,		// orange
	24'h97C81A,		// yellow
	24'h40A94A,		// green
	24'h2CAD93,		// cyan
	24'h5F7ABE,		// blue
	24'h965DC0,		// violet
	24'hC16CA8		// magenta
};

// Which colour mode
localparam P_MODE_PLAIN = 2'd0;
localparam P_MODE_BANDS = 2'd1;
localparam P_MODE_CHARS = 2'd2;

// FONT TABLE BEGIN - generated by gateware/util/gen_vpg_font.py of the HDMI design, do not edit by hand
localparam logic [7:0] P_FONT [0:(P_FONT_CNT * 8)-1] = '{
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x20 space
    8'h18, 8'h18, 8'h18, 8'h18, 8'h18, 8'h00, 8'h18, 8'h00,    // 0x21 !
    8'h36, 8'h36, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x22 "
    8'h36, 8'h36, 8'h7F, 8'h36, 8'h7F, 8'h36, 8'h36, 8'h00,    // 0x23 #
    8'h18, 8'h3E, 8'h60, 8'h3C, 8'h06, 8'h7C, 8'h18, 8'h00,    // 0x24 $
    8'h63, 8'h66, 8'h0C, 8'h18, 8'h30, 8'h66, 8'hC6, 8'h00,    // 0x25 %
    8'h3C, 8'h66, 8'h3C, 8'h76, 8'h67, 8'h66, 8'h3D, 8'h00,    // 0x26 &
    8'h18, 8'h18, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x27 '
    8'h0C, 8'h18, 8'h30, 8'h30, 8'h30, 8'h18, 8'h0C, 8'h00,    // 0x28 (
    8'h30, 8'h18, 8'h0C, 8'h0C, 8'h0C, 8'h18, 8'h30, 8'h00,    // 0x29 )
    8'h00, 8'h6C, 8'h38, 8'h7C, 8'h38, 8'h6C, 8'h00, 8'h00,    // 0x2A *
    8'h00, 8'h18, 8'h18, 8'h7E, 8'h18, 8'h18, 8'h00, 8'h00,    // 0x2B +
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h18, 8'h18, 8'h30,    // 0x2C ,
    8'h00, 8'h00, 8'h00, 8'h7E, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x2D -
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h18, 8'h18, 8'h00,    // 0x2E .
    8'h03, 8'h06, 8'h0C, 8'h18, 8'h30, 8'h60, 8'hC0, 8'h00,    // 0x2F /
    8'h3C, 8'h66, 8'h6E, 8'h7D, 8'h73, 8'h66, 8'h3C, 8'h00,    // 0x30 0
    8'h18, 8'h38, 8'h78, 8'h18, 8'h18, 8'h18, 8'h7E, 8'h00,    // 0x31 1
    8'h3C, 8'h66, 8'h06, 8'h0C, 8'h18, 8'h30, 8'h7E, 8'h00,    // 0x32 2
    8'h7E, 8'h0C, 8'h18, 8'h0C, 8'h06, 8'h66, 8'h3C, 8'h00,    // 0x33 3
    8'h0E, 8'h1E, 8'h36, 8'h66, 8'h7F, 8'h06, 8'h0F, 8'h00,    // 0x34 4
    8'h7E, 8'h60, 8'h7C, 8'h06, 8'h06, 8'h66, 8'h3C, 8'h00,    // 0x35 5
    8'h1C, 8'h30, 8'h60, 8'h7C, 8'h66, 8'h66, 8'h3C, 8'h00,    // 0x36 6
    8'h7E, 8'h66, 8'h0C, 8'h18, 8'h30, 8'h30, 8'h30, 8'h00,    // 0x37 7
    8'h3C, 8'h66, 8'h66, 8'h3C, 8'h66, 8'h66, 8'h3C, 8'h00,    // 0x38 8
    8'h3C, 8'h66, 8'h66, 8'h3E, 8'h06, 8'h0C, 8'h38, 8'h00,    // 0x39 9
    8'h00, 8'h18, 8'h18, 8'h00, 8'h00, 8'h18, 8'h18, 8'h00,    // 0x3A :
    8'h00, 8'h18, 8'h18, 8'h00, 8'h00, 8'h18, 8'h18, 8'h30,    // 0x3B ;
    8'h0E, 8'h18, 8'h30, 8'h60, 8'h30, 8'h18, 8'h0E, 8'h00,    // 0x3C <
    8'h00, 8'h00, 8'h7E, 8'h00, 8'h7E, 8'h00, 8'h00, 8'h00,    // 0x3D =
    8'h70, 8'h18, 8'h0C, 8'h06, 8'h0C, 8'h18, 8'h70, 8'h00,    // 0x3E >
    8'h3C, 8'h66, 8'h06, 8'h0C, 8'h18, 8'h00, 8'h18, 8'h00,    // 0x3F ?
    8'h3C, 8'h66, 8'h6E, 8'h6E, 8'h60, 8'h66, 8'h3C, 8'h00,    // 0x40 @
    8'h3C, 8'h66, 8'h66, 8'h7E, 8'h66, 8'h66, 8'h66, 8'h00,    // 0x41 A
    8'h7C, 8'h66, 8'h66, 8'h7C, 8'h66, 8'h66, 8'h7C, 8'h00,    // 0x42 B
    8'h3C, 8'h66, 8'h60, 8'h60, 8'h60, 8'h66, 8'h3C, 8'h00,    // 0x43 C
    8'h7C, 8'h66, 8'h66, 8'h66, 8'h66, 8'h66, 8'h7C, 8'h00,    // 0x44 D
    8'h7E, 8'h60, 8'h60, 8'h7C, 8'h60, 8'h60, 8'h7E, 8'h00,    // 0x45 E
    8'h7E, 8'h60, 8'h60, 8'h7C, 8'h60, 8'h60, 8'h60, 8'h00,    // 0x46 F
    8'h3C, 8'h66, 8'h60, 8'h6E, 8'h66, 8'h66, 8'h3C, 8'h00,    // 0x47 G
    8'h66, 8'h66, 8'h66, 8'h7E, 8'h66, 8'h66, 8'h66, 8'h00,    // 0x48 H
    8'h3C, 8'h18, 8'h18, 8'h18, 8'h18, 8'h18, 8'h3C, 8'h00,    // 0x49 I
    8'h1F, 8'h06, 8'h06, 8'h06, 8'h66, 8'h66, 8'h3C, 8'h00,    // 0x4A J
    8'h66, 8'h6C, 8'h78, 8'h70, 8'h78, 8'h6C, 8'h66, 8'h00,    // 0x4B K
    8'h60, 8'h60, 8'h60, 8'h60, 8'h60, 8'h60, 8'h7E, 8'h00,    // 0x4C L
    8'h63, 8'h77, 8'h7F, 8'h6B, 8'h63, 8'h63, 8'h63, 8'h00,    // 0x4D M
    8'h66, 8'h76, 8'h7E, 8'h7E, 8'h6E, 8'h66, 8'h66, 8'h00,    // 0x4E N
    8'h3C, 8'h66, 8'h66, 8'h66, 8'h66, 8'h66, 8'h3C, 8'h00,    // 0x4F O
    8'h7C, 8'h66, 8'h66, 8'h7C, 8'h60, 8'h60, 8'h60, 8'h00,    // 0x50 P
    8'h3C, 8'h66, 8'h66, 8'h66, 8'h6E, 8'h6C, 8'h3B, 8'h00,    // 0x51 Q
    8'h7C, 8'h66, 8'h66, 8'h7C, 8'h6C, 8'h66, 8'h66, 8'h00,    // 0x52 R
    8'h3C, 8'h66, 8'h60, 8'h3C, 8'h06, 8'h66, 8'h3C, 8'h00,    // 0x53 S
    8'h7E, 8'h18, 8'h18, 8'h18, 8'h18, 8'h18, 8'h18, 8'h00,    // 0x54 T
    8'h66, 8'h66, 8'h66, 8'h66, 8'h66, 8'h66, 8'h3C, 8'h00,    // 0x55 U
    8'h66, 8'h66, 8'h66, 8'h66, 8'h66, 8'h3C, 8'h18, 8'h00,    // 0x56 V
    8'h63, 8'h63, 8'h63, 8'h6B, 8'h7F, 8'h77, 8'h63, 8'h00,    // 0x57 W
    8'h66, 8'h66, 8'h3C, 8'h18, 8'h3C, 8'h66, 8'h66, 8'h00,    // 0x58 X
    8'h66, 8'h66, 8'h66, 8'h3C, 8'h18, 8'h18, 8'h18, 8'h00,    // 0x59 Y
    8'h7E, 8'h06, 8'h0C, 8'h18, 8'h30, 8'h60, 8'h7E, 8'h00,    // 0x5A Z
    8'h3C, 8'h30, 8'h30, 8'h30, 8'h30, 8'h30, 8'h3C, 8'h00,    // 0x5B [
    8'hC0, 8'h60, 8'h30, 8'h18, 8'h0C, 8'h06, 8'h03, 8'h00,    // 0x5C \
    8'h3C, 8'h0C, 8'h0C, 8'h0C, 8'h0C, 8'h0C, 8'h3C, 8'h00,    // 0x5D ]
    8'h18, 8'h3C, 8'h66, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x5E ^
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h7F,    // 0x5F _
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x60 `
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x61 a
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x62 b
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x63 c
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x64 d
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x65 e
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x66 f
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x67 g
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x68 h
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x69 i
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x6A j
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x6B k
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x6C l
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x6D m
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x6E n
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x6F o
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x70 p
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x71 q
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x72 r
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x73 s
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x74 t
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x75 u
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x76 v
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x77 w
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x78 x
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x79 y
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x7A z
    8'h78, 8'h78, 8'h0C, 8'h7F, 8'h7F, 8'h0C, 8'h78, 8'h78,    // 0x7B {
    8'h1E, 8'h1E, 8'h30, 8'hFE, 8'hFE, 8'h30, 8'h1E, 8'h1E,    // 0x7C |
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x7D }
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,    // 0x7E ~
    8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00    // 0x7F 
};
// FONT TABLE END

// SINE TABLE BEGIN - generated by gateware/util/gen_vpg_font.py of the HDMI design, do not edit by hand
localparam logic signed [7:0] P_SINE [0:255] = '{
    8'sd0, 8'sd3, 8'sd6, 8'sd9, 8'sd12, 8'sd16, 8'sd19, 8'sd22,
    8'sd25, 8'sd28, 8'sd31, 8'sd34, 8'sd37, 8'sd40, 8'sd43, 8'sd46,
    8'sd49, 8'sd51, 8'sd54, 8'sd57, 8'sd60, 8'sd63, 8'sd65, 8'sd68,
    8'sd71, 8'sd73, 8'sd76, 8'sd78, 8'sd81, 8'sd83, 8'sd85, 8'sd88,
    8'sd90, 8'sd92, 8'sd94, 8'sd96, 8'sd98, 8'sd100, 8'sd102, 8'sd104,
    8'sd106, 8'sd107, 8'sd109, 8'sd111, 8'sd112, 8'sd113, 8'sd115, 8'sd116,
    8'sd117, 8'sd118, 8'sd120, 8'sd121, 8'sd122, 8'sd122, 8'sd123, 8'sd124,
    8'sd125, 8'sd125, 8'sd126, 8'sd126, 8'sd126, 8'sd127, 8'sd127, 8'sd127,
    8'sd127, 8'sd127, 8'sd127, 8'sd127, 8'sd126, 8'sd126, 8'sd126, 8'sd125,
    8'sd125, 8'sd124, 8'sd123, 8'sd122, 8'sd122, 8'sd121, 8'sd120, 8'sd118,
    8'sd117, 8'sd116, 8'sd115, 8'sd113, 8'sd112, 8'sd111, 8'sd109, 8'sd107,
    8'sd106, 8'sd104, 8'sd102, 8'sd100, 8'sd98, 8'sd96, 8'sd94, 8'sd92,
    8'sd90, 8'sd88, 8'sd85, 8'sd83, 8'sd81, 8'sd78, 8'sd76, 8'sd73,
    8'sd71, 8'sd68, 8'sd65, 8'sd63, 8'sd60, 8'sd57, 8'sd54, 8'sd51,
    8'sd49, 8'sd46, 8'sd43, 8'sd40, 8'sd37, 8'sd34, 8'sd31, 8'sd28,
    8'sd25, 8'sd22, 8'sd19, 8'sd16, 8'sd12, 8'sd9, 8'sd6, 8'sd3,
    8'sd0, -8'sd3, -8'sd6, -8'sd9, -8'sd12, -8'sd16, -8'sd19, -8'sd22,
    -8'sd25, -8'sd28, -8'sd31, -8'sd34, -8'sd37, -8'sd40, -8'sd43, -8'sd46,
    -8'sd49, -8'sd51, -8'sd54, -8'sd57, -8'sd60, -8'sd63, -8'sd65, -8'sd68,
    -8'sd71, -8'sd73, -8'sd76, -8'sd78, -8'sd81, -8'sd83, -8'sd85, -8'sd88,
    -8'sd90, -8'sd92, -8'sd94, -8'sd96, -8'sd98, -8'sd100, -8'sd102, -8'sd104,
    -8'sd106, -8'sd107, -8'sd109, -8'sd111, -8'sd112, -8'sd113, -8'sd115, -8'sd116,
    -8'sd117, -8'sd118, -8'sd120, -8'sd121, -8'sd122, -8'sd122, -8'sd123, -8'sd124,
    -8'sd125, -8'sd125, -8'sd126, -8'sd126, -8'sd126, -8'sd127, -8'sd127, -8'sd127,
    -8'sd127, -8'sd127, -8'sd127, -8'sd127, -8'sd126, -8'sd126, -8'sd126, -8'sd125,
    -8'sd125, -8'sd124, -8'sd123, -8'sd122, -8'sd122, -8'sd121, -8'sd120, -8'sd118,
    -8'sd117, -8'sd116, -8'sd115, -8'sd113, -8'sd112, -8'sd111, -8'sd109, -8'sd107,
    -8'sd106, -8'sd104, -8'sd102, -8'sd100, -8'sd98, -8'sd96, -8'sd94, -8'sd92,
    -8'sd90, -8'sd88, -8'sd85, -8'sd83, -8'sd81, -8'sd78, -8'sd76, -8'sd73,
    -8'sd71, -8'sd68, -8'sd65, -8'sd63, -8'sd60, -8'sd57, -8'sd54, -8'sd51,
    -8'sd49, -8'sd46, -8'sd43, -8'sd40, -8'sd37, -8'sd34, -8'sd31, -8'sd28,
    -8'sd25, -8'sd22, -8'sd19, -8'sd16, -8'sd12, -8'sd9, -8'sd6, -8'sd3
};
// SINE TABLE END

// Structures
typedef struct {
	logic [1:0]				vs;
	logic [1:0]				de;
	logic [15:0]			px;			// Pixel counter, in screen pixels
	logic [15:0]			lcnt;		// Line counter
	logic [15:0]			hwidth;		// Active pixels
	logic [15:0]			vheight;	// Active lines
} vid_struct;

typedef struct {
	logic [15:0]			scroll;		// Horizontal offset, in screen pixels
	logic [7:0]				phase;		// Sine phase
	logic signed [7:0]		sin;		// Sine value
	logic signed [7:0]		sin_reg;	// Sine value, registered
	logic signed [24:0]		mul;		// Sine times the picture height
	logic signed [16:0]		off;		// Vertical offset
	logic signed [16:0]		top;		// First line of the text
} scr_struct;

typedef struct {
	logic [2:0]				col[0:1];	// Column in the character
	logic [2:0]				row;		// Row in the character
	logic [2:0]				chr[0:1];	// Character, low bits, for the colour
	logic [1:0]				band;		// Inside the text band
	logic [7:0]				bits;		// Font row
	logic 					fg;			// Foreground pixel
	logic [23:0]			col_out;	// Colour of this pixel
} ren_struct;

// Signals
vid_struct	clk_vid;
scr_struct	clk_scr;
ren_struct	clk_ren;

logic [(P_BPC * P_PPC)-1:0]	clk_r[0:2];
logic [(P_BPC * P_PPC)-1:0]	clk_g[0:2];
logic [(P_BPC * P_PPC)-1:0]	clk_b[0:2];
logic [2:0]					clk_vs_dly;
logic [2:0]					clk_hs_dly;
logic [2:0]					clk_de_dly;
logic 						clk_txt_rd;
wire  [7:0]					txt_dout;

wire  [16:0]				sx;
wire  [14:0]				fx;
wire  [P_TXT_ADR-1:0]		txt_adr;
wire  signed [16:0]			lcnt_sgn;
wire  [15:0]				scroll_step;
wire 						fg_sel;

// Logic

// Video pipeline
// Three clocks, which is what the lookup below costs: one for the character, one for the
// font row, one to pick the bit.
	always_ff @ (posedge CLK_IN)
	begin
		if (CKE_IN)
		begin
			clk_r[0] <= VID_R_IN;
			clk_g[0] <= VID_G_IN;
			clk_b[0] <= VID_B_IN;
			clk_vs_dly <= {clk_vs_dly[1:0], VID_VS_IN};
			clk_hs_dly <= {clk_hs_dly[1:0], VID_HS_IN};
			clk_de_dly <= {clk_de_dly[1:0], VID_DE_IN};

			for (int i = 1; i < 3; i++)
			begin
				clk_r[i] <= clk_r[i-1];
				clk_g[i] <= clk_g[i-1];
				clk_b[i] <= clk_b[i-1];
			end
		end
	end

// Vsync and data enable history, for the edges below
	always_ff @ (posedge CLK_IN)
	begin
		if (CKE_IN)
		begin
			clk_vid.vs <= {clk_vid.vs[0], VID_VS_IN};
			clk_vid.de <= {clk_vid.de[0], VID_DE_IN};
		end
	end

// Pixel counter
// Counts in screen pixels, so it steps by the number of pixels a clock carries.
	always_ff @ (posedge CLK_IN)
	begin
		if (CKE_IN)
		begin
			if (VID_DE_IN)
				clk_vid.px <= clk_vid.px + P_PPC;
			else
				clk_vid.px <= 0;
		end
	end

// Line counter
	always_ff @ (posedge CLK_IN)
	begin
		if (CKE_IN)
		begin
			// A new frame
			if (clk_vid.vs == 'b01)
				clk_vid.lcnt <= 0;

			// End of a line
			else if (clk_vid.de == 'b10)
				clk_vid.lcnt <= clk_vid.lcnt + 'd1;
		end
	end

// Picture size
// Taken from the video parameter set, so the text sits in the middle of the picture and
// travels at the same apparent speed at every resolution, instead of on a fixed line and
// at a fixed number of pixels. The application writes the set for the test pattern and
// for the clock recovery of pass-through alike, so it always holds what is on the screen.
	always_ff @ (posedge CLK_IN)
	begin
		if ((VPS_IDX_IN == 'd5) && VPS_VLD_IN)
			clk_vid.hwidth <= VPS_DAT_IN;

		if ((VPS_IDX_IN == 'd9) && VPS_VLD_IN)
			clk_vid.vheight <= VPS_DAT_IN;
	end

// Scroll step
// A fixed number of pixels per frame crosses a 3840 wide picture in twice the time it
// needs for 1920, which reads as the text slowing down at 4K. So step further when the
// picture is wider. Bit 11 of the width is set from 2048 pixels up, which is the line
// between the two, and shifting keeps the step a whole number of clocks - that is what
// holds every character on a clock boundary and keeps a barrel shifter out of the design.
	assign scroll_step = 16'(P_PPC) << clk_vid.hwidth[11];

// Scroll
	always_ff @ (posedge CLK_IN)
	begin
		if (RST_IN)
			clk_scr.scroll <= 0;

		else if (CKE_IN && (clk_vid.vs == 'b01))
		begin
			// Wrap on the length of the text
			if ((clk_scr.scroll + scroll_step) >= 16'(P_TXT_WRDS * P_CHR_PIX))
				clk_scr.scroll <= 0;
			else
				clk_scr.scroll <= clk_scr.scroll + scroll_step;
		end
	end

// Sine phase
	always_ff @ (posedge CLK_IN)
	begin
		if (RST_IN)
			clk_scr.phase <= 0;

		else if (CKE_IN && (clk_vid.vs == 'b01))
			clk_scr.phase <= clk_scr.phase + 8'(CTL_SPD_IN);
	end

// Top line of the text
// The middle of the picture plus the sine.
//
// The height of the bounce is a fraction of the picture rather than a fixed number of
// lines, so it looks the same at every resolution.
//
// The sine reaches 127, so multiplying by the height and shifting by P_AMP_SHIFT gives
// about a quarter of the picture either way at amplitude zero, and each step of
// CTL_AMP_IN halves it. A quarter is the most that fits: the text itself is P_ROW_PIX
// tall and has to stay in the picture at the extremes.
//
// Split over five clocks, because in one hop this is the longest path in the core. The
// latency costs nothing: the phase only moves on Vsync and the result is not looked at
// until the active area, thousands of clocks later.
//
// The table is mapped into a block RAM. Its output is registered before the multiplier,
// as the clock to out of the block RAM followed by the DSP does not make 150 MHz in the
// slower speed grades (Lattice CertusPro-NX -7).
	always_ff @ (posedge CLK_IN)
	begin
		if (CKE_IN)
		begin
			// Table
			clk_scr.sin <= P_SINE[clk_scr.phase];
			clk_scr.sin_reg <= clk_scr.sin;

			// Scale to the picture height
			clk_scr.mul <= clk_scr.sin_reg * $signed({1'b0, clk_vid.vheight});

			// Amplitude
			clk_scr.off <= 17'(clk_scr.mul >>> (P_AMP_SHIFT + CTL_AMP_IN));

			// Middle of the picture
			clk_scr.top <= $signed({2'b0, clk_vid.vheight[15:1]})
							- $signed(17'(P_ROW_PIX / 2))
							+ clk_scr.off;
		end
	end

// Text position
	assign sx = {1'b0, clk_vid.px} + {1'b0, clk_scr.scroll};
	assign fx = sx[16:P_SCALE_BITS];					// Font pixel column
	assign txt_adr = fx[(P_TXT_ADR + 3)-1:3];			// Eight font pixels to a character
	assign lcnt_sgn = $signed({1'b0, clk_vid.lcnt});

// Stage 0 - the character comes out of the memory one clock after the address, so the
// address is combinatorial and everything that goes with it is registered here.
	always_ff @ (posedge CLK_IN)
	begin
		if (CKE_IN)
		begin
			clk_ren.col[0] <= fx[2:0];
			clk_ren.chr[0] <= txt_adr[2:0];
			clk_ren.row <= 3'((lcnt_sgn - clk_scr.top) >>> P_SCALE_BITS);
			clk_ren.band[0] <= ((lcnt_sgn >= clk_scr.top)
								&& (lcnt_sgn < (clk_scr.top + 17'(P_ROW_PIX)))) ? 1 : 0;
		end
	end

// Stage 1 - read the font row
	always_ff @ (posedge CLK_IN)
	begin
		if (CKE_IN)
		begin
			clk_ren.col[1] <= clk_ren.col[0];
			clk_ren.chr[1] <= clk_ren.chr[0];
			clk_ren.band[1] <= clk_ren.band[0];

			// Anything outside the font comes out blank, so an unexpected character
			// leaves a hole in the text instead of garbage on the screen.
			if ((txt_dout >= P_FONT_FIRST) && (txt_dout < 8'(P_FONT_FIRST + P_FONT_CNT)))
				clk_ren.bits <= P_FONT[{7'(txt_dout - P_FONT_FIRST), clk_ren.row}];
			else
				clk_ren.bits <= 0;
		end
	end

// Stage 2 - pick the bit
	always_ff @ (posedge CLK_IN)
	begin
		if (CKE_IN)
		begin
			// Only inside the data enable. In the blanking the pixel counter stands at zero
			// while the line is still inside the text band, so without this the character at
			// the scroll position would be drawn into the whole of the horizontal blanking.
			// The data enable is taken one stage back, as it moves on to the output on this
			// same edge.
			clk_ren.fg <= (clk_ren.band[1] && clk_ren.bits[3'd7 - clk_ren.col[1]] && clk_de_dly[1]) ? 1 : 0;

			// The colour is decided here rather than at the output, so the output stays a
			// plain mux and the palette lookup gets a clock of its own.
			case (CTL_MODE_IN)
				P_MODE_BANDS : clk_ren.col_out <= (CTL_CSF_IN) ? P_PAL_YUV[3'(clk_ren.row + clk_scr.phase[7:5])] : P_PAL[3'(clk_ren.row + clk_scr.phase[7:5])];
				P_MODE_CHARS : clk_ren.col_out <= (CTL_CSF_IN) ? P_PAL_YUV[3'(clk_ren.chr[1] + clk_scr.phase[7:5])] : P_PAL[3'(clk_ren.chr[1] + clk_scr.phase[7:5])];
				default      : clk_ren.col_out <= CTL_COL_IN;
			endcase
		end
	end

// Text memory
// Same construction as the video parameter memory in the controller: written from the
// system clock, read in the video clock.
	prt_lib_sdp_ram_dc
	#(
		.P_VENDOR		(P_VENDOR),
		.P_FAMILY  (P_FAMILY),        // Family
		.P_RAM_STYLE	("distributed"),	// "distributed", "block" or "ultra"
		.P_ADR_WIDTH 	(P_TXT_ADR),
		.P_DAT_WIDTH 	(8)
	)
	TXT_RAM_INST
	(
		// Port A
		.A_RST_IN		(SYS_RST_IN),		// Reset
		.A_CLK_IN		(SYS_CLK_IN),		// Clock
		.A_ADR_IN		(TXT_ADR_IN),		// Address
		.A_WR_IN		(TXT_WR_IN),		// Write in
		.A_DAT_IN		(TXT_DAT_IN),		// Write data

		// Port B
		.B_RST_IN		(RST_IN),			// Reset
		.B_CLK_IN		(CLK_IN),			// Clock
		.B_ADR_IN		(txt_adr),			// Address
		.B_RD_IN		(clk_txt_rd),		// Read in
		.B_DAT_OUT		(txt_dout),			// Read data
		.B_VLD_OUT		()					// Read data valid, not used - always reading
	);

// The memory is always reading
	always_ff @ (posedge CLK_IN)
	begin
		if (RST_IN)
			clk_txt_rd <= 0;
		else
			clk_txt_rd <= 1;
	end

// Outputs
// Only the colour is replaced, and only when the scroller runs. The timing signals are
// the delayed inputs, so they are the same signals that came in.
	assign fg_sel = CTL_RUN_IN && clk_ren.fg;

generate
	genvar i;
	for (i = 0; i < P_PPC; i++)
	begin : gen_pix
		assign VID_R_OUT[(i*P_BPC)+:P_BPC] = fg_sel ? (P_BPC'(clk_ren.col_out[16+:8]) << P_COL_SHIFT) : clk_r[2][(i*P_BPC)+:P_BPC];
		assign VID_G_OUT[(i*P_BPC)+:P_BPC] = fg_sel ? (P_BPC'(clk_ren.col_out[8+:8])  << P_COL_SHIFT) : clk_g[2][(i*P_BPC)+:P_BPC];
		assign VID_B_OUT[(i*P_BPC)+:P_BPC] = fg_sel ? (P_BPC'(clk_ren.col_out[0+:8])  << P_COL_SHIFT) : clk_b[2][(i*P_BPC)+:P_BPC];
	end
endgenerate

	assign VID_VS_OUT = clk_vs_dly[2];
	assign VID_HS_OUT = clk_hs_dly[2];
	assign VID_DE_OUT = clk_de_dly[2];

endmodule

`default_nettype wire
