/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP RX Video - video mapper
    (c) 2021 - 2026 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Updated behaviour


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

//-----
// Module
//-----
module prt_dprx_vid_vmap
#(
    // Video
    parameter                           P_PPC = 2,          // Pixels per clock
    parameter                           P_BPC = 8,          // Bits per component
    parameter                           P_LANES = 4,        // Lanes
    parameter                           P_SEGMENTS = 4,     // Segments
    parameter                           P_STRIPES = 4,      // Stripes
    parameter 			            	P_VID_DAT = 48		// AXIS data width
)
(
    input wire                          RST_IN,                                         // Reset
    input wire                          CLK_IN,                                         // Clock

    // Control
    input wire                          CFG_BPC_IN,                                     // Active bits-per-component

    // Mapper
    input wire                          MAP_STR_IN,                                     // Start
    input wire                          MAP_STP_IN,                                     // Stop
    input wire [15:0]                   MAP_HEAD_IN,                                    // Head
    output wire [P_STRIPES-1:0]         MAP_RD_OUT[P_LANES][P_SEGMENTS],                // Read
    input wire [1:0]                    MAP_DAT_IN[P_LANES][P_SEGMENTS][P_STRIPES],     // Data

    // Video
    output wire [P_VID_DAT-1:0]         VID_DAT_OUT,                                    // Data
    output wire                         VID_EOL_OUT,                                    // End-of-line
    output wire                         VID_VLD_OUT                                     // Valid
);


//-----
// Parameters
//-----
localparam P_LAT = 2;           // Read latency
localparam P_SEL_INIT_8BPC = (P_PPC == 4) ? 4 : 8;
localparam P_SEL_INIT_10BPC = (P_PPC == 4) ? 16 : 32;
localparam P_LVL_THRESHOLD_8BPC = 48;               // Level in bytes
localparam P_LVL_THRESHOLD_10BPC = 240;             // Level in bytes


//-----
// State machine
//-----
typedef enum {
    sm_idle, sm_str, sm_run, sm_wait, sm_flush
} sm_state;


//-----
// Structures
//-----
typedef struct {
    logic                           bpc;
} ctl_struct;

typedef struct {
    sm_state                        sm_cur;
    sm_state                        sm_nxt;
    logic                           str;
    logic                           stp;
    logic                           run_clr;
    logic                           run_set;
    logic                           run;
    logic [15:0]                    head;
    logic [15:0]                    tail;
    logic [15:0]                    lvl;
    logic [15:0]                    lvl_thres;
    logic [5:0]                     gen_sel_init;
    logic [5:0]                     gen_sel;
    logic                           gen_sel_ld;
    logic                           sm_gen_sel_ld;
    logic                           gen_sel_end;
    logic                           gen_sel_end_re;
    logic [5:0]                     asm_sel[P_LAT];
    logic [P_STRIPES-1:0]           rd[P_LANES][P_SEGMENTS];   
    logic [1:0]                     dat[P_LANES][P_SEGMENTS][P_STRIPES];
} map_struct;

typedef struct {
    logic [P_VID_DAT-1:0]           dat;
    logic                           eol;
    logic                           vld;
} vid_struct;

typedef struct {
    logic [5:0]                     sel;
} fn_vmap_gen_in_struct;

typedef struct {
    logic [P_STRIPES-1:0]           rd[P_LANES][P_SEGMENTS];  
} fn_vmap_gen_out_struct;

typedef struct {
    logic [5:0]                     sel;
    logic [1:0]                     dat[P_LANES][P_SEGMENTS][P_STRIPES];
} fn_vmap_asm_in_struct;

typedef struct {
    logic [P_BPC-1:0]               dat[P_PPC*3];
    logic                           vld;
} fn_vmap_asm_out_struct;


//-----
// Signals
//-----
ctl_struct                  clk_ctl;
map_struct                  clk_map;
vid_struct                  clk_vid;

fn_vmap_gen_in_struct       fn_vmap_gen_in;
fn_vmap_gen_out_struct      fn_vmap_gen_out;

fn_vmap_asm_in_struct       fn_vmap_asm_in;
fn_vmap_asm_out_struct      fn_vmap_asm_out;

genvar i, j;


//-----
// Functions
//-----

// VMAP Generator 2PPC 8BPC
// This function generates the fifo reads in 2 pixel-per-clock 8-bits video mode
// This function reads 48 bytes from the fifo.
function fn_vmap_gen_out_struct vmap_gen_2ppc_8bpc (fn_vmap_gen_in_struct vmap_in);

    fn_vmap_gen_out_struct vmap_out;
   
    // Default
    for (int i = 0; i < P_LANES; i++)
    begin
        for (int j = 0; j < P_SEGMENTS; j++)
            vmap_out.rd[i][j] = 0;
    end

    case (vmap_in.sel)
        
        'd8 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                // Red
                vmap_out.rd[i][0][0] = 1;   // R0/1-7:6
                vmap_out.rd[i][0][1] = 1;   // R0/1-5:4
                vmap_out.rd[i][0][2] = 1;   // R0/1-3:2
                vmap_out.rd[i][0][3] = 1;   // R0/1-1:0

                // Green
                vmap_out.rd[i][1][0] = 1;   // G0/1-7:6
                vmap_out.rd[i][1][1] = 1;   // G0/1-5:4
                vmap_out.rd[i][1][2] = 1;   // G0/1-3:2
                vmap_out.rd[i][1][3] = 1;   // G0/1-1:0

                // Blue
                vmap_out.rd[i][2][0] = 1;   // B0/1-7:6
                vmap_out.rd[i][2][1] = 1;   // B0/1-5:4
                vmap_out.rd[i][2][2] = 1;   // B0/1-3:2
                vmap_out.rd[i][2][3] = 1;   // B0/1-31:0
            end
        end

        'd7 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][0][0] = 1;   // R2/3-7:6
                vmap_out.rd[i][0][1] = 1;   // R2/3-5:4
                vmap_out.rd[i][0][2] = 1;   // R2/3-3:2
                vmap_out.rd[i][0][3] = 1;   // R2/3-1:0

                // Green
                vmap_out.rd[i][1][0] = 1;   // G2/3-7:6
                vmap_out.rd[i][1][1] = 1;   // G2/3-5:4
                vmap_out.rd[i][1][2] = 1;   // G2/3-3:2
                vmap_out.rd[i][1][3] = 1;   // G2/3-1:0

                // Blue
                vmap_out.rd[i][2][0] = 1;   // B2/3-7:6
                vmap_out.rd[i][2][1] = 1;   // B2/3-5:4
                vmap_out.rd[i][2][2] = 1;   // B2/3-3:2
                vmap_out.rd[i][2][3] = 1;   // B2/3-1:0
            end
        end

        'd6 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                // Red
                vmap_out.rd[i][3][0] = 1;   // R4/5-7:6
                vmap_out.rd[i][3][1] = 1;   // R4/5-5:4
                vmap_out.rd[i][3][2] = 1;   // R4/5-3:2
                vmap_out.rd[i][3][3] = 1;   // R4/5-1:0

                // Green
                vmap_out.rd[i][0][0] = 1;   // G4/5-7:6
                vmap_out.rd[i][0][1] = 1;   // G4/5-5:4
                vmap_out.rd[i][0][2] = 1;   // G4/5-3:2
                vmap_out.rd[i][0][3] = 1;   // G4/5-1:0

                // Blue
                vmap_out.rd[i][1][0] = 1;   // B4/5-7:6
                vmap_out.rd[i][1][1] = 1;   // B4/5-5:4
                vmap_out.rd[i][1][2] = 1;   // B4/5-3:2
                vmap_out.rd[i][1][3] = 1;   // B4/5-1:0
            end
        end

        'd5 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][3][0] = 1;   // R6/7-7:6
                vmap_out.rd[i][3][1] = 1;   // R6/7-5:4
                vmap_out.rd[i][3][2] = 1;   // R6/7-3:2
                vmap_out.rd[i][3][3] = 1;   // R6/7-1:0

                // Green
                vmap_out.rd[i][0][0] = 1;   // G6/7-7:6
                vmap_out.rd[i][0][1] = 1;   // G6/7-5:4
                vmap_out.rd[i][0][2] = 1;   // G6/7-3:2
                vmap_out.rd[i][0][3] = 1;   // G6/7-1:0

                // Blue
                vmap_out.rd[i][1][0] = 1;   // B6/7-7:6
                vmap_out.rd[i][1][1] = 1;   // B6/7-5:4
                vmap_out.rd[i][1][2] = 1;   // B6/7-3:2
                vmap_out.rd[i][1][3] = 1;   // B6/7-1:0
            end
        end

        'd4 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                // Red
                vmap_out.rd[i][2][0] = 1;   // R8/9-7:6
                vmap_out.rd[i][2][1] = 1;   // R8/9-5:4
                vmap_out.rd[i][2][2] = 1;   // R8/9-3:2
                vmap_out.rd[i][2][3] = 1;   // R8/9-1:0

                // Green
                vmap_out.rd[i][3][0] = 1;   // G8/9-7:6
                vmap_out.rd[i][3][1] = 1;   // G8/9-5:4
                vmap_out.rd[i][3][2] = 1;   // G8/9-3:2
                vmap_out.rd[i][3][3] = 1;   // G8/9-1:0

                // Blue
                vmap_out.rd[i][0][0] = 1;   // B8/9-7:6
                vmap_out.rd[i][0][1] = 1;   // B8/9-5:4
                vmap_out.rd[i][0][2] = 1;   // B8/9-3:2
                vmap_out.rd[i][0][3] = 1;   // B8/9-1:0
            end
        end

        'd3 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][2][0] = 1;   // R10/11-7:6
                vmap_out.rd[i][2][1] = 1;   // R10/11-5:4
                vmap_out.rd[i][2][2] = 1;   // R10/11-3:2
                vmap_out.rd[i][2][3] = 1;   // R10/11-1:0

                // Green
                vmap_out.rd[i][3][0] = 1;   // G10/11-7:6
                vmap_out.rd[i][3][1] = 1;   // G10/11-5:4
                vmap_out.rd[i][3][2] = 1;   // G10/11-3:2
                vmap_out.rd[i][3][3] = 1;   // G10/11-1:0

                // Blue
                vmap_out.rd[i][0][0] = 1;   // B10/11-7:6
                vmap_out.rd[i][0][1] = 1;   // B10/11-5:4
                vmap_out.rd[i][0][2] = 1;   // B10/11-3:2
                vmap_out.rd[i][0][3] = 1;   // B10/11-1:0
            end
        end

        'd2 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                // Red
                vmap_out.rd[i][1][0] = 1;   // R12/13-7:6
                vmap_out.rd[i][1][1] = 1;   // R12/13-5:4
                vmap_out.rd[i][1][2] = 1;   // R12/13-3:2
                vmap_out.rd[i][1][3] = 1;   // R12/13-1:0

                // Green
                vmap_out.rd[i][2][0] = 1;   // G12/13-7:6
                vmap_out.rd[i][2][1] = 1;   // G12/13-5:4
                vmap_out.rd[i][2][2] = 1;   // G12/13-3:2
                vmap_out.rd[i][2][3] = 1;   // G12/13-1:0

                // Blue
                vmap_out.rd[i][3][0] = 1;   // B12/13-7:6
                vmap_out.rd[i][3][1] = 1;   // B12/13-5:4
                vmap_out.rd[i][3][2] = 1;   // B12/13-3:2
                vmap_out.rd[i][3][3] = 1;   // B12/13-1:0
            end
        end

        'd1 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][1][0] = 1;   // R14/15-7:6
                vmap_out.rd[i][1][1] = 1;   // R14/15-5:4
                vmap_out.rd[i][1][2] = 1;   // R14/15-3:2
                vmap_out.rd[i][1][3] = 1;   // R14/15-1:0

                // Green
                vmap_out.rd[i][2][0] = 1;   // G14/15-7:6
                vmap_out.rd[i][2][1] = 1;   // G14/15-5:4
                vmap_out.rd[i][2][2] = 1;   // G14/15-3:2
                vmap_out.rd[i][2][3] = 1;   // G14/15-1:0

                // Blue
                vmap_out.rd[i][3][0] = 1;   // B14/15-7:6
                vmap_out.rd[i][3][1] = 1;   // B14/15-5:4
                vmap_out.rd[i][3][2] = 1;   // B14/15-3:2
                vmap_out.rd[i][3][3] = 1;   // B14/15-1:0
            end
        end
        default : ;
    endcase
    
    return vmap_out;
endfunction

// VMAP Generator 2PPC 10BPC
// This function generates the fifo reads in 2 pixel-per-clock 10-bits video mode
// This function reads 240 bytes from the fifo.
function fn_vmap_gen_out_struct vmap_gen_2ppc_10bpc (fn_vmap_gen_in_struct vmap_in);

    fn_vmap_gen_out_struct vmap_out;
   
    // Default
    for (int i = 0; i < P_LANES; i++)
    begin
        for (int j = 0; j < P_SEGMENTS; j++)
            vmap_out.rd[i][j] = 0;
    end

    case (vmap_in.sel)
        
        // Sequence 0
        'd32 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                // Red
                vmap_out.rd[i][0][0] = 1;   // R0-9:8
                vmap_out.rd[i][0][1] = 1;   // R0-7:6
                vmap_out.rd[i][0][2] = 1;   // R0-5:4
                vmap_out.rd[i][0][3] = 1;   // R0-3:2
                vmap_out.rd[i][1][0] = 1;   // R0-1:0

                // Green
                vmap_out.rd[i][1][1] = 1;   // G0-9:8
                vmap_out.rd[i][1][2] = 1;   // G0-7:6
                vmap_out.rd[i][1][3] = 1;   // G0-5:4
                vmap_out.rd[i][2][0] = 1;   // G0-3:2
                vmap_out.rd[i][2][1] = 1;   // G0-1:0

                // Blue
                vmap_out.rd[i][2][2] = 1;   // B0-9:8
                vmap_out.rd[i][2][3] = 1;   // B0-7:6
                vmap_out.rd[i][3][0] = 1;   // B0-5:4
                vmap_out.rd[i][3][1] = 1;   // B0-3:2
                vmap_out.rd[i][3][2] = 1;   // B0-1:0
            end
        end

        'd31 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][0][0] = 1;   // R0-9:8
                vmap_out.rd[i][0][1] = 1;   // R0-7:6
                vmap_out.rd[i][0][2] = 1;   // R0-5:4
                vmap_out.rd[i][0][3] = 1;   // R0-3:2
                vmap_out.rd[i][1][0] = 1;   // R0-1:0

                // Green
                vmap_out.rd[i][1][1] = 1;   // G0-9:8
                vmap_out.rd[i][1][2] = 1;   // G0-7:6
                vmap_out.rd[i][1][3] = 1;   // G0-5:4
                vmap_out.rd[i][2][0] = 1;   // G0-3:2
                vmap_out.rd[i][2][1] = 1;   // G0-1:0

                // Blue
                vmap_out.rd[i][2][2] = 1;   // B0-9:8
                vmap_out.rd[i][2][3] = 1;   // B0-7:6
                vmap_out.rd[i][3][0] = 1;   // B0-5:4
                vmap_out.rd[i][3][1] = 1;   // B0-3:2
                vmap_out.rd[i][3][2] = 1;   // B0-1:0
            end
        end

        'd30 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                // Red
                vmap_out.rd[i][3][3] = 1;   // R4-9:8
                vmap_out.rd[i][0][0] = 1;   // R4-7:6
                vmap_out.rd[i][0][1] = 1;   // R4-5:4
                vmap_out.rd[i][0][2] = 1;   // R4-3:2
                vmap_out.rd[i][0][3] = 1;   // R4-1:0

                // Green
                vmap_out.rd[i][1][0] = 1;   // G4-9:8
                vmap_out.rd[i][1][1] = 1;   // G4-7:6
                vmap_out.rd[i][1][2] = 1;   // G4-5:4
                vmap_out.rd[i][1][3] = 1;   // G4-3:2
                vmap_out.rd[i][2][0] = 1;   // G4-1:0

                // Blue
                vmap_out.rd[i][2][1] = 1;   // B4-9:8
                vmap_out.rd[i][2][2] = 1;   // B4-7:6
                vmap_out.rd[i][2][3] = 1;   // B4-5:4
                vmap_out.rd[i][3][0] = 1;   // B4-3:2
                vmap_out.rd[i][3][1] = 1;   // B4-1:0
            end
        end

        'd29 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][3][3] = 1;   // R4-9:8
                vmap_out.rd[i][0][0] = 1;   // R4-7:6
                vmap_out.rd[i][0][1] = 1;   // R4-5:4
                vmap_out.rd[i][0][2] = 1;   // R4-3:2
                vmap_out.rd[i][0][3] = 1;   // R4-1:0

                // Green
                vmap_out.rd[i][1][0] = 1;   // G4-9:8
                vmap_out.rd[i][1][1] = 1;   // G4-7:6
                vmap_out.rd[i][1][2] = 1;   // G4-5:4
                vmap_out.rd[i][1][3] = 1;   // G4-3:2
                vmap_out.rd[i][2][0] = 1;   // G4-1:0

                // Blue
                vmap_out.rd[i][2][1] = 1;   // B4-9:8
                vmap_out.rd[i][2][2] = 1;   // B4-7:6
                vmap_out.rd[i][2][3] = 1;   // B4-5:4
                vmap_out.rd[i][3][0] = 1;   // B4-3:2
                vmap_out.rd[i][3][1] = 1;   // B4-1:0
            end
        end

        'd28 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                // Red
                vmap_out.rd[i][3][2] = 1;   // R8-9:8
                vmap_out.rd[i][3][3] = 1;   // R8-7:6
                vmap_out.rd[i][0][0] = 1;   // R8-5:4
                vmap_out.rd[i][0][1] = 1;   // R8-3:2
                vmap_out.rd[i][0][2] = 1;   // R8-1:0

                // Green
                vmap_out.rd[i][0][3] = 1;   // G8-9:8
                vmap_out.rd[i][1][0] = 1;   // G8-7:6
                vmap_out.rd[i][1][1] = 1;   // G8-5:4
                vmap_out.rd[i][1][2] = 1;   // G8-3:2
                vmap_out.rd[i][1][3] = 1;   // G8-1:0

                // Blue
                vmap_out.rd[i][2][0] = 1;   // B8-9:8
                vmap_out.rd[i][2][1] = 1;   // B8-7:6
                vmap_out.rd[i][2][2] = 1;   // B8-5:4
                vmap_out.rd[i][2][3] = 1;   // B8-3:2
                vmap_out.rd[i][3][0] = 1;   // B8-1:0
            end
        end

        'd27 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][3][2] = 1;   // R8-9:8
                vmap_out.rd[i][3][3] = 1;   // R8-7:6
                vmap_out.rd[i][0][0] = 1;   // R8-5:4
                vmap_out.rd[i][0][1] = 1;   // R8-3:2
                vmap_out.rd[i][0][2] = 1;   // R8-1:0

                // Green
                vmap_out.rd[i][0][3] = 1;   // G8-9:8
                vmap_out.rd[i][1][0] = 1;   // G8-7:6
                vmap_out.rd[i][1][1] = 1;   // G8-5:4
                vmap_out.rd[i][1][2] = 1;   // G8-3:2
                vmap_out.rd[i][1][3] = 1;   // G8-1:0

                // Blue
                vmap_out.rd[i][2][0] = 1;   // B8-9:8
                vmap_out.rd[i][2][1] = 1;   // B8-7:6
                vmap_out.rd[i][2][2] = 1;   // B8-5:4
                vmap_out.rd[i][2][3] = 1;   // B8-3:2
                vmap_out.rd[i][3][0] = 1;   // B8-1:0
            end
        end

        'd26 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                // Red
                vmap_out.rd[i][3][1] = 1;   // R12-9:8
                vmap_out.rd[i][3][2] = 1;   // R12-7:6
                vmap_out.rd[i][3][3] = 1;   // R12-5:4
                vmap_out.rd[i][0][0] = 1;   // R12-3:2
                vmap_out.rd[i][0][1] = 1;   // R12-1:0

                // Green
                vmap_out.rd[i][0][2] = 1;   // G12-9:8
                vmap_out.rd[i][0][3] = 1;   // G12-7:6
                vmap_out.rd[i][1][0] = 1;   // G12-5:4
                vmap_out.rd[i][1][1] = 1;   // G12-3:2
                vmap_out.rd[i][1][2] = 1;   // G12-1:0

                // Blue
                vmap_out.rd[i][1][3] = 1;   // B12-9:8
                vmap_out.rd[i][2][0] = 1;   // B12-7:6
                vmap_out.rd[i][2][1] = 1;   // B12-5:4
                vmap_out.rd[i][2][2] = 1;   // B12-3:2
                vmap_out.rd[i][2][3] = 1;   // B12-1:0
            end
        end

        'd25 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][3][1] = 1;   // R12-9:8
                vmap_out.rd[i][3][2] = 1;   // R12-7:6
                vmap_out.rd[i][3][3] = 1;   // R12-5:4
                vmap_out.rd[i][0][0] = 1;   // R12-3:2
                vmap_out.rd[i][0][1] = 1;   // R12-1:0

                // Green
                vmap_out.rd[i][0][2] = 1;   // G12-9:8
                vmap_out.rd[i][0][3] = 1;   // G12-7:6
                vmap_out.rd[i][1][0] = 1;   // G12-5:4
                vmap_out.rd[i][1][1] = 1;   // G12-3:2
                vmap_out.rd[i][1][2] = 1;   // G12-1:0

                // Blue
                vmap_out.rd[i][1][3] = 1;   // B12-9:8
                vmap_out.rd[i][2][0] = 1;   // B12-7:6
                vmap_out.rd[i][2][1] = 1;   // B12-5:4
                vmap_out.rd[i][2][2] = 1;   // B12-3:2
                vmap_out.rd[i][2][3] = 1;   // B12-1:0
            end
        end

        'd24 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                // Red
                vmap_out.rd[i][3][0] = 1;   // R0-9:8
                vmap_out.rd[i][3][1] = 1;   // R0-7:6
                vmap_out.rd[i][3][2] = 1;   // R0-5:4
                vmap_out.rd[i][3][3] = 1;   // R0-3:2
                vmap_out.rd[i][0][0] = 1;   // R0-1:0

                // Green
                vmap_out.rd[i][0][1] = 1;   // G0-9:8
                vmap_out.rd[i][0][2] = 1;   // G0-7:6
                vmap_out.rd[i][0][3] = 1;   // G0-5:4
                vmap_out.rd[i][1][0] = 1;   // G0-3:2
                vmap_out.rd[i][1][1] = 1;   // G0-1:0

                // Blue
                vmap_out.rd[i][1][2] = 1;   // B0-9:8
                vmap_out.rd[i][1][3] = 1;   // B0-7:6
                vmap_out.rd[i][2][0] = 1;   // B0-5:4
                vmap_out.rd[i][2][1] = 1;   // B0-3:2
                vmap_out.rd[i][2][2] = 1;   // B0-1:0
            end
        end

        // Sequence 1
        'd23 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][3][0] = 1;   // R0-9:8
                vmap_out.rd[i][3][1] = 1;   // R0-7:6
                vmap_out.rd[i][3][2] = 1;   // R0-5:4
                vmap_out.rd[i][3][3] = 1;   // R0-3:2
                vmap_out.rd[i][0][0] = 1;   // R0-1:0

                // Green
                vmap_out.rd[i][0][1] = 1;   // G0-9:8
                vmap_out.rd[i][0][2] = 1;   // G0-7:6
                vmap_out.rd[i][0][3] = 1;   // G0-5:4
                vmap_out.rd[i][1][0] = 1;   // G0-3:2
                vmap_out.rd[i][1][1] = 1;   // G0-1:0

                // Blue
                vmap_out.rd[i][1][2] = 1;   // B0-9:8
                vmap_out.rd[i][1][3] = 1;   // B0-7:6
                vmap_out.rd[i][2][0] = 1;   // B0-5:4
                vmap_out.rd[i][2][1] = 1;   // B0-3:2
                vmap_out.rd[i][2][2] = 1;   // B0-1:0
            end
        end

        'd22 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                // Red
                vmap_out.rd[i][2][3] = 1;   // R4-9:8
                vmap_out.rd[i][3][0] = 1;   // R4-7:6
                vmap_out.rd[i][3][1] = 1;   // R4-5:4
                vmap_out.rd[i][3][2] = 1;   // R4-3:2
                vmap_out.rd[i][3][3] = 1;   // R4-1:0

                // Green
                vmap_out.rd[i][0][0] = 1;   // G4-9:8
                vmap_out.rd[i][0][1] = 1;   // G4-7:6
                vmap_out.rd[i][0][2] = 1;   // G4-5:4
                vmap_out.rd[i][0][3] = 1;   // G4-3:2
                vmap_out.rd[i][1][0] = 1;   // G4-1:0

                // Blue
                vmap_out.rd[i][1][1] = 1;   // B4-9:8
                vmap_out.rd[i][1][2] = 1;   // B4-7:6
                vmap_out.rd[i][1][3] = 1;   // B4-5:4
                vmap_out.rd[i][2][0] = 1;   // B4-3:2
                vmap_out.rd[i][2][1] = 1;   // B4-1:0
            end
        end

        'd21 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][2][3] = 1;   // R4-9:8
                vmap_out.rd[i][3][0] = 1;   // R4-7:6
                vmap_out.rd[i][3][1] = 1;   // R4-5:4
                vmap_out.rd[i][3][2] = 1;   // R4-3:2
                vmap_out.rd[i][3][3] = 1;   // R4-1:0

                // Green
                vmap_out.rd[i][0][0] = 1;   // G4-9:8
                vmap_out.rd[i][0][1] = 1;   // G4-7:6
                vmap_out.rd[i][0][2] = 1;   // G4-5:4
                vmap_out.rd[i][0][3] = 1;   // G4-3:2
                vmap_out.rd[i][1][0] = 1;   // G4-1:0

                // Blue
                vmap_out.rd[i][1][1] = 1;   // B4-9:8
                vmap_out.rd[i][1][2] = 1;   // B4-7:6
                vmap_out.rd[i][1][3] = 1;   // B4-5:4
                vmap_out.rd[i][2][0] = 1;   // B4-3:2
                vmap_out.rd[i][2][1] = 1;   // B4-1:0
            end
        end

        'd20 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                // Red
                vmap_out.rd[i][2][2] = 1;   // R8-9:8
                vmap_out.rd[i][2][3] = 1;   // R8-7:6
                vmap_out.rd[i][3][0] = 1;   // R8-5:4
                vmap_out.rd[i][3][1] = 1;   // R8-3:2
                vmap_out.rd[i][3][2] = 1;   // R8-1:0

                // Green
                vmap_out.rd[i][3][3] = 1;   // G8-9:8
                vmap_out.rd[i][0][0] = 1;   // G8-7:6
                vmap_out.rd[i][0][1] = 1;   // G8-5:4
                vmap_out.rd[i][0][2] = 1;   // G8-3:2
                vmap_out.rd[i][0][3] = 1;   // G8-1:0

                // Blue
                vmap_out.rd[i][1][0] = 1;   // B8-9:8
                vmap_out.rd[i][1][1] = 1;   // B8-7:6
                vmap_out.rd[i][1][2] = 1;   // B8-5:4
                vmap_out.rd[i][1][3] = 1;   // B8-3:2
                vmap_out.rd[i][2][0] = 1;   // B8-1:0
            end
        end

        'd19 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][2][2] = 1;   // R8-9:8
                vmap_out.rd[i][2][3] = 1;   // R8-7:6
                vmap_out.rd[i][3][0] = 1;   // R8-5:4
                vmap_out.rd[i][3][1] = 1;   // R8-3:2
                vmap_out.rd[i][3][2] = 1;   // R8-1:0

                // Green
                vmap_out.rd[i][3][3] = 1;   // G8-9:8
                vmap_out.rd[i][0][0] = 1;   // G8-7:6
                vmap_out.rd[i][0][1] = 1;   // G8-5:4
                vmap_out.rd[i][0][2] = 1;   // G8-3:2
                vmap_out.rd[i][0][3] = 1;   // G8-1:0

                // Blue
                vmap_out.rd[i][1][0] = 1;   // B8-9:8
                vmap_out.rd[i][1][1] = 1;   // B8-7:6
                vmap_out.rd[i][1][2] = 1;   // B8-5:4
                vmap_out.rd[i][1][3] = 1;   // B8-3:2
                vmap_out.rd[i][2][0] = 1;   // B8-1:0
            end
        end

        'd18 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                // Red
                vmap_out.rd[i][2][1] = 1;   // R12-9:8
                vmap_out.rd[i][2][2] = 1;   // R12-7:6
                vmap_out.rd[i][2][3] = 1;   // R12-5:4
                vmap_out.rd[i][3][0] = 1;   // R12-3:2
                vmap_out.rd[i][3][1] = 1;   // R12-1:0

                // Green
                vmap_out.rd[i][3][2] = 1;   // G12-9:8
                vmap_out.rd[i][3][3] = 1;   // G12-7:6
                vmap_out.rd[i][0][0] = 1;   // G12-5:4
                vmap_out.rd[i][0][1] = 1;   // G12-3:2
                vmap_out.rd[i][0][2] = 1;   // G12-1:0

                // Blue
                vmap_out.rd[i][0][3] = 1;   // B12-9:8
                vmap_out.rd[i][1][0] = 1;   // B12-7:6
                vmap_out.rd[i][1][1] = 1;   // B12-5:4
                vmap_out.rd[i][1][2] = 1;   // B12-3:2
                vmap_out.rd[i][1][3] = 1;   // B12-1:0
            end
        end

        'd17 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][2][1] = 1;   // R12-9:8
                vmap_out.rd[i][2][2] = 1;   // R12-7:6
                vmap_out.rd[i][2][3] = 1;   // R12-5:4
                vmap_out.rd[i][3][0] = 1;   // R12-3:2
                vmap_out.rd[i][3][1] = 1;   // R12-1:0

                // Green
                vmap_out.rd[i][3][2] = 1;   // G12-9:8
                vmap_out.rd[i][3][3] = 1;   // G12-7:6
                vmap_out.rd[i][0][0] = 1;   // G12-5:4
                vmap_out.rd[i][0][1] = 1;   // G12-3:2
                vmap_out.rd[i][0][2] = 1;   // G12-1:0

                // Blue
                vmap_out.rd[i][0][3] = 1;   // B12-9:8
                vmap_out.rd[i][1][0] = 1;   // B12-7:6
                vmap_out.rd[i][1][1] = 1;   // B12-5:4
                vmap_out.rd[i][1][2] = 1;   // B12-3:2
                vmap_out.rd[i][1][3] = 1;   // B12-1:0
            end
        end

        // Sequence 2
        'd16 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                // Red
                vmap_out.rd[i][2][0] = 1;   // R0-9:8
                vmap_out.rd[i][2][1] = 1;   // R0-7:6
                vmap_out.rd[i][2][2] = 1;   // R0-5:4
                vmap_out.rd[i][2][3] = 1;   // R0-3:2
                vmap_out.rd[i][3][0] = 1;   // R0-1:0

                // Green
                vmap_out.rd[i][3][1] = 1;   // G0-9:8
                vmap_out.rd[i][3][2] = 1;   // G0-7:6
                vmap_out.rd[i][3][3] = 1;   // G0-5:4
                vmap_out.rd[i][0][0] = 1;   // G0-3:2
                vmap_out.rd[i][0][1] = 1;   // G0-1:0

                // Blue
                vmap_out.rd[i][0][2] = 1;   // B0-9:8
                vmap_out.rd[i][0][3] = 1;   // B0-7:6
                vmap_out.rd[i][1][0] = 1;   // B0-5:4
                vmap_out.rd[i][1][1] = 1;   // B0-3:2
                vmap_out.rd[i][1][2] = 1;   // B0-1:0
            end
        end

        'd15 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][2][0] = 1;   // R0-9:8
                vmap_out.rd[i][2][1] = 1;   // R0-7:6
                vmap_out.rd[i][2][2] = 1;   // R0-5:4
                vmap_out.rd[i][2][3] = 1;   // R0-3:2
                vmap_out.rd[i][3][0] = 1;   // R0-1:0

                // Green
                vmap_out.rd[i][3][1] = 1;   // G0-9:8
                vmap_out.rd[i][3][2] = 1;   // G0-7:6
                vmap_out.rd[i][3][3] = 1;   // G0-5:4
                vmap_out.rd[i][0][0] = 1;   // G0-3:2
                vmap_out.rd[i][0][1] = 1;   // G0-1:0

                // Blue
                vmap_out.rd[i][0][2] = 1;   // B0-9:8
                vmap_out.rd[i][0][3] = 1;   // B0-7:6
                vmap_out.rd[i][1][0] = 1;   // B0-5:4
                vmap_out.rd[i][1][1] = 1;   // B0-3:2
                vmap_out.rd[i][1][2] = 1;   // B0-1:0
            end
        end

        'd14 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                // Red
                vmap_out.rd[i][1][3] = 1;   // R4-9:8
                vmap_out.rd[i][2][0] = 1;   // R4-7:6
                vmap_out.rd[i][2][1] = 1;   // R4-5:4
                vmap_out.rd[i][2][2] = 1;   // R4-3:2
                vmap_out.rd[i][2][3] = 1;   // R4-1:0

                // Green
                vmap_out.rd[i][3][0] = 1;   // G4-9:8
                vmap_out.rd[i][3][1] = 1;   // G4-7:6
                vmap_out.rd[i][3][2] = 1;   // G4-5:4
                vmap_out.rd[i][3][3] = 1;   // G4-3:2
                vmap_out.rd[i][0][0] = 1;   // G4-1:0

                // Blue
                vmap_out.rd[i][0][1] = 1;   // B4-9:8
                vmap_out.rd[i][0][2] = 1;   // B4-7:6
                vmap_out.rd[i][0][3] = 1;   // B4-5:4
                vmap_out.rd[i][1][0] = 1;   // B4-3:2
                vmap_out.rd[i][1][1] = 1;   // B4-1:0
            end
        end

        'd13 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][1][3] = 1;   // R4-9:8
                vmap_out.rd[i][2][0] = 1;   // R4-7:6
                vmap_out.rd[i][2][1] = 1;   // R4-5:4
                vmap_out.rd[i][2][2] = 1;   // R4-3:2
                vmap_out.rd[i][2][3] = 1;   // R4-1:0

                // Green
                vmap_out.rd[i][3][0] = 1;   // G4-9:8
                vmap_out.rd[i][3][1] = 1;   // G4-7:6
                vmap_out.rd[i][3][2] = 1;   // G4-5:4
                vmap_out.rd[i][3][3] = 1;   // G4-3:2
                vmap_out.rd[i][0][0] = 1;   // G4-1:0

                // Blue
                vmap_out.rd[i][0][1] = 1;   // B4-9:8
                vmap_out.rd[i][0][2] = 1;   // B4-7:6
                vmap_out.rd[i][0][3] = 1;   // B4-5:4
                vmap_out.rd[i][1][0] = 1;   // B4-3:2
                vmap_out.rd[i][1][1] = 1;   // B4-1:0
            end
        end

        'd12 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                // Red
                vmap_out.rd[i][1][2] = 1;   // R8-9:8
                vmap_out.rd[i][1][3] = 1;   // R8-7:6
                vmap_out.rd[i][2][0] = 1;   // R8-5:4
                vmap_out.rd[i][2][1] = 1;   // R8-3:2
                vmap_out.rd[i][2][2] = 1;   // R8-1:0

                // Green
                vmap_out.rd[i][2][3] = 1;   // G8-9:8
                vmap_out.rd[i][3][0] = 1;   // G8-7:6
                vmap_out.rd[i][3][1] = 1;   // G8-5:4
                vmap_out.rd[i][3][2] = 1;   // G8-3:2
                vmap_out.rd[i][3][3] = 1;   // G8-1:0

                // Blue
                vmap_out.rd[i][0][0] = 1;   // B8-9:8
                vmap_out.rd[i][0][1] = 1;   // B8-7:6
                vmap_out.rd[i][0][2] = 1;   // B8-5:4
                vmap_out.rd[i][0][3] = 1;   // B8-3:2
                vmap_out.rd[i][1][0] = 1;   // B8-1:0
            end
        end

        'd11 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][1][2] = 1;   // R8-9:8
                vmap_out.rd[i][1][3] = 1;   // R8-7:6
                vmap_out.rd[i][2][0] = 1;   // R8-5:4
                vmap_out.rd[i][2][1] = 1;   // R8-3:2
                vmap_out.rd[i][2][2] = 1;   // R8-1:0

                // Green
                vmap_out.rd[i][2][3] = 1;   // G8-9:8
                vmap_out.rd[i][3][0] = 1;   // G8-7:6
                vmap_out.rd[i][3][1] = 1;   // G8-5:4
                vmap_out.rd[i][3][2] = 1;   // G8-3:2
                vmap_out.rd[i][3][3] = 1;   // G8-1:0

                // Blue
                vmap_out.rd[i][0][0] = 1;   // B8-9:8
                vmap_out.rd[i][0][1] = 1;   // B8-7:6
                vmap_out.rd[i][0][2] = 1;   // B8-5:4
                vmap_out.rd[i][0][3] = 1;   // B8-3:2
                vmap_out.rd[i][1][0] = 1;   // B8-1:0
            end
        end

        'd10 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                // Red
                vmap_out.rd[i][1][1] = 1;   // R12-9:8
                vmap_out.rd[i][1][2] = 1;   // R12-7:6
                vmap_out.rd[i][1][3] = 1;   // R12-5:4
                vmap_out.rd[i][2][0] = 1;   // R12-3:2
                vmap_out.rd[i][2][1] = 1;   // R12-1:0

                // Green
                vmap_out.rd[i][2][2] = 1;   // G12-9:8
                vmap_out.rd[i][2][3] = 1;   // G12-7:6
                vmap_out.rd[i][3][0] = 1;   // G12-5:4
                vmap_out.rd[i][3][1] = 1;   // G12-3:2
                vmap_out.rd[i][3][2] = 1;   // G12-1:0

                // Blue
                vmap_out.rd[i][3][3] = 1;   // B12-9:8
                vmap_out.rd[i][0][0] = 1;   // B12-7:6
                vmap_out.rd[i][0][1] = 1;   // B12-5:4
                vmap_out.rd[i][0][2] = 1;   // B12-3:2
                vmap_out.rd[i][0][3] = 1;   // B12-1:0
            end
        end

        'd9 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][1][1] = 1;   // R12-9:8
                vmap_out.rd[i][1][2] = 1;   // R12-7:6
                vmap_out.rd[i][1][3] = 1;   // R12-5:4
                vmap_out.rd[i][2][0] = 1;   // R12-3:2
                vmap_out.rd[i][2][1] = 1;   // R12-1:0

                // Green
                vmap_out.rd[i][2][2] = 1;   // G12-9:8
                vmap_out.rd[i][2][3] = 1;   // G12-7:6
                vmap_out.rd[i][3][0] = 1;   // G12-5:4
                vmap_out.rd[i][3][1] = 1;   // G12-3:2
                vmap_out.rd[i][3][2] = 1;   // G12-1:0

                // Blue
                vmap_out.rd[i][3][3] = 1;   // B12-9:8
                vmap_out.rd[i][0][0] = 1;   // B12-7:6
                vmap_out.rd[i][0][1] = 1;   // B12-5:4
                vmap_out.rd[i][0][2] = 1;   // B12-3:2
                vmap_out.rd[i][0][3] = 1;   // B12-1:0
            end
        end

        'd8 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                // Red
                vmap_out.rd[i][1][0] = 1;   // R0-9:8
                vmap_out.rd[i][1][1] = 1;   // R0-7:6
                vmap_out.rd[i][1][2] = 1;   // R0-5:4
                vmap_out.rd[i][1][3] = 1;   // R0-3:2
                vmap_out.rd[i][2][0] = 1;   // R0-1:0

                // Green
                vmap_out.rd[i][2][1] = 1;   // G0-9:8
                vmap_out.rd[i][2][2] = 1;   // G0-7:6
                vmap_out.rd[i][2][3] = 1;   // G0-5:4
                vmap_out.rd[i][3][0] = 1;   // G0-3:2
                vmap_out.rd[i][3][1] = 1;   // G0-1:0

                // Blue
                vmap_out.rd[i][3][2] = 1;   // B0-9:8
                vmap_out.rd[i][3][3] = 1;   // B0-7:6
                vmap_out.rd[i][0][0] = 1;   // B0-5:4
                vmap_out.rd[i][0][1] = 1;   // B0-3:2
                vmap_out.rd[i][0][2] = 1;   // B0-1:0
            end
        end

        'd7 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][1][0] = 1;   // R0-9:8
                vmap_out.rd[i][1][1] = 1;   // R0-7:6
                vmap_out.rd[i][1][2] = 1;   // R0-5:4
                vmap_out.rd[i][1][3] = 1;   // R0-3:2
                vmap_out.rd[i][2][0] = 1;   // R0-1:0

                // Green
                vmap_out.rd[i][2][1] = 1;   // G0-9:8
                vmap_out.rd[i][2][2] = 1;   // G0-7:6
                vmap_out.rd[i][2][3] = 1;   // G0-5:4
                vmap_out.rd[i][3][0] = 1;   // G0-3:2
                vmap_out.rd[i][3][1] = 1;   // G0-1:0

                // Blue
                vmap_out.rd[i][3][2] = 1;   // B0-9:8
                vmap_out.rd[i][3][3] = 1;   // B0-7:6
                vmap_out.rd[i][0][0] = 1;   // B0-5:4
                vmap_out.rd[i][0][1] = 1;   // B0-3:2
                vmap_out.rd[i][0][2] = 1;   // B0-1:0
            end
        end

        'd6 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                // Red
                vmap_out.rd[i][0][3] = 1;   // R4-9:8
                vmap_out.rd[i][1][0] = 1;   // R4-7:6
                vmap_out.rd[i][1][1] = 1;   // R4-5:4
                vmap_out.rd[i][1][2] = 1;   // R4-3:2
                vmap_out.rd[i][1][3] = 1;   // R4-1:0

                // Green
                vmap_out.rd[i][2][0] = 1;   // G4-9:8
                vmap_out.rd[i][2][1] = 1;   // G4-7:6
                vmap_out.rd[i][2][2] = 1;   // G4-5:4
                vmap_out.rd[i][2][3] = 1;   // G4-3:2
                vmap_out.rd[i][3][0] = 1;   // G4-1:0

                // Blue
                vmap_out.rd[i][3][1] = 1;   // B4-9:8
                vmap_out.rd[i][3][2] = 1;   // B4-7:6
                vmap_out.rd[i][3][3] = 1;   // B4-5:4
                vmap_out.rd[i][0][0] = 1;   // B4-3:2
                vmap_out.rd[i][0][1] = 1;   // B4-1:0
            end
        end

        'd5 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][0][3] = 1;   // R4-9:8
                vmap_out.rd[i][1][0] = 1;   // R4-7:6
                vmap_out.rd[i][1][1] = 1;   // R4-5:4
                vmap_out.rd[i][1][2] = 1;   // R4-3:2
                vmap_out.rd[i][1][3] = 1;   // R4-1:0

                // Green
                vmap_out.rd[i][2][0] = 1;   // G4-9:8
                vmap_out.rd[i][2][1] = 1;   // G4-7:6
                vmap_out.rd[i][2][2] = 1;   // G4-5:4
                vmap_out.rd[i][2][3] = 1;   // G4-3:2
                vmap_out.rd[i][3][0] = 1;   // G4-1:0

                // Blue
                vmap_out.rd[i][3][1] = 1;   // B4-9:8
                vmap_out.rd[i][3][2] = 1;   // B4-7:6
                vmap_out.rd[i][3][3] = 1;   // B4-5:4
                vmap_out.rd[i][0][0] = 1;   // B4-3:2
                vmap_out.rd[i][0][1] = 1;   // B4-1:0
            end
        end

        'd4 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                // Red
                vmap_out.rd[i][0][2] = 1;   // R8-9:8
                vmap_out.rd[i][0][3] = 1;   // R8-7:6
                vmap_out.rd[i][1][0] = 1;   // R8-5:4
                vmap_out.rd[i][1][1] = 1;   // R8-3:2
                vmap_out.rd[i][1][2] = 1;   // R8-1:0

                // Green
                vmap_out.rd[i][1][3] = 1;   // G8-9:8
                vmap_out.rd[i][2][0] = 1;   // G8-7:6
                vmap_out.rd[i][2][1] = 1;   // G8-5:4
                vmap_out.rd[i][2][2] = 1;   // G8-3:2
                vmap_out.rd[i][2][3] = 1;   // G8-1:0

                // Blue
                vmap_out.rd[i][3][0] = 1;   // B8-9:8
                vmap_out.rd[i][3][1] = 1;   // B8-7:6
                vmap_out.rd[i][3][2] = 1;   // B8-5:4
                vmap_out.rd[i][3][3] = 1;   // B8-3:2
                vmap_out.rd[i][0][0] = 1;   // B8-1:0
            end
        end

        'd3 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][0][2] = 1;   // R8-9:8
                vmap_out.rd[i][0][3] = 1;   // R8-7:6
                vmap_out.rd[i][1][0] = 1;   // R8-5:4
                vmap_out.rd[i][1][1] = 1;   // R8-3:2
                vmap_out.rd[i][1][2] = 1;   // R8-1:0

                // Green
                vmap_out.rd[i][1][3] = 1;   // G8-9:8
                vmap_out.rd[i][2][0] = 1;   // G8-7:6
                vmap_out.rd[i][2][1] = 1;   // G8-5:4
                vmap_out.rd[i][2][2] = 1;   // G8-3:2
                vmap_out.rd[i][2][3] = 1;   // G8-1:0

                // Blue
                vmap_out.rd[i][3][0] = 1;   // B8-9:8
                vmap_out.rd[i][3][1] = 1;   // B8-7:6
                vmap_out.rd[i][3][2] = 1;   // B8-5:4
                vmap_out.rd[i][3][3] = 1;   // B8-3:2
                vmap_out.rd[i][0][0] = 1;   // B8-1:0
            end
        end

        'd2 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                // Red
                vmap_out.rd[i][0][1] = 1;   // R12-9:8
                vmap_out.rd[i][0][2] = 1;   // R12-7:6
                vmap_out.rd[i][0][3] = 1;   // R12-5:4
                vmap_out.rd[i][1][0] = 1;   // R12-3:2
                vmap_out.rd[i][1][1] = 1;   // R12-1:0

                // Green
                vmap_out.rd[i][1][2] = 1;   // G12-9:8
                vmap_out.rd[i][1][3] = 1;   // G12-7:6
                vmap_out.rd[i][2][0] = 1;   // G12-5:4
                vmap_out.rd[i][2][1] = 1;   // G12-3:2
                vmap_out.rd[i][2][2] = 1;   // G12-1:0

                // Blue
                vmap_out.rd[i][2][3] = 1;   // B12-9:8
                vmap_out.rd[i][3][0] = 1;   // B12-7:6
                vmap_out.rd[i][3][1] = 1;   // B12-5:4
                vmap_out.rd[i][3][2] = 1;   // B12-3:2
                vmap_out.rd[i][3][3] = 1;   // B12-1:0
            end
        end

        'd1 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][0][1] = 1;   // R12-9:8
                vmap_out.rd[i][0][2] = 1;   // R12-7:6
                vmap_out.rd[i][0][3] = 1;   // R12-5:4
                vmap_out.rd[i][1][0] = 1;   // R12-3:2
                vmap_out.rd[i][1][1] = 1;   // R12-1:0

                // Green
                vmap_out.rd[i][1][2] = 1;   // G12-9:8
                vmap_out.rd[i][1][3] = 1;   // G12-7:6
                vmap_out.rd[i][2][0] = 1;   // G12-5:4
                vmap_out.rd[i][2][1] = 1;   // G12-3:2
                vmap_out.rd[i][2][2] = 1;   // G12-1:0

                // Blue
                vmap_out.rd[i][2][3] = 1;   // B12-9:8
                vmap_out.rd[i][3][0] = 1;   // B12-7:6
                vmap_out.rd[i][3][1] = 1;   // B12-5:4
                vmap_out.rd[i][3][2] = 1;   // B12-3:2
                vmap_out.rd[i][3][3] = 1;   // B12-1:0
            end
        end

        default : ;
    endcase
    
    return vmap_out;
endfunction

// VMAP Generator 4PPC 8BPC
// This function generates the fifo reads in 4 pixel-per-clock 8-bits video mode
// This function reads 48 bytes from the fifo.
function fn_vmap_gen_out_struct vmap_gen_4ppc_8bpc (fn_vmap_gen_in_struct vmap_in);

    fn_vmap_gen_out_struct vmap_out;
   
    // Default
    for (int i = 0; i < P_LANES; i++)
    begin
        for (int j = 0; j < P_SEGMENTS; j++)
            vmap_out.rd[i][j] = 0;
    end

    case (vmap_in.sel)
        
        'd4 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][0][0] = 1;   // R0/3-7:6
                vmap_out.rd[i][0][1] = 1;   // R0/3-5:4
                vmap_out.rd[i][0][2] = 1;   // R0/3-3:2
                vmap_out.rd[i][0][3] = 1;   // R0/3-1:0

                // Green
                vmap_out.rd[i][1][0] = 1;   // G0/3-7:6
                vmap_out.rd[i][1][1] = 1;   // G0/3-5:4
                vmap_out.rd[i][1][2] = 1;   // G0/3-3:2
                vmap_out.rd[i][1][3] = 1;   // G0/3-1:0

                // Blue
                vmap_out.rd[i][2][0] = 1;   // B0/3-7:6
                vmap_out.rd[i][2][1] = 1;   // B0/3-5:4
                vmap_out.rd[i][2][2] = 1;   // B0/3-3:2
                vmap_out.rd[i][2][3] = 1;   // B0/3-1:0
            end
        end

        'd3 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][3][0] = 1;   // R4/7-7:6
                vmap_out.rd[i][3][1] = 1;   // R4/7-5:4
                vmap_out.rd[i][3][2] = 1;   // R4/7-3:2
                vmap_out.rd[i][3][3] = 1;   // R4/7-1:0

                // Green
                vmap_out.rd[i][0][0] = 1;   // G4/7-7:6
                vmap_out.rd[i][0][1] = 1;   // G4/7-5:4
                vmap_out.rd[i][0][2] = 1;   // G4/7-3:2
                vmap_out.rd[i][0][3] = 1;   // G4/7-1:0

                // Blue
                vmap_out.rd[i][1][0] = 1;   // B4/7-7:6
                vmap_out.rd[i][1][1] = 1;   // B4/7-5:4
                vmap_out.rd[i][1][2] = 1;   // B4/7-3:2
                vmap_out.rd[i][1][3] = 1;   // B4/7-1:0
            end
        end

        'd2 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][2][0] = 1;   // R8/11-7:6
                vmap_out.rd[i][2][1] = 1;   // R8/11-5:4
                vmap_out.rd[i][2][2] = 1;   // R8/11-3:2
                vmap_out.rd[i][2][3] = 1;   // R8/11-1:0

                // Green
                vmap_out.rd[i][3][0] = 1;   // G8/11-7:6
                vmap_out.rd[i][3][1] = 1;   // G8/11-5:4
                vmap_out.rd[i][3][2] = 1;   // G8/11-3:2
                vmap_out.rd[i][3][3] = 1;   // G8/11-1:0

                // Blue
                vmap_out.rd[i][0][0] = 1;   // B8/11-7:6
                vmap_out.rd[i][0][1] = 1;   // B8/11-5:4
                vmap_out.rd[i][0][2] = 1;   // B8/11-3:2
                vmap_out.rd[i][0][3] = 1;   // B8/11-1:0
            end
        end

        'd1 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][1][0] = 1;   // R12/15-7:6
                vmap_out.rd[i][1][1] = 1;   // R12/15-5:4
                vmap_out.rd[i][1][2] = 1;   // R12/15-3:2
                vmap_out.rd[i][1][3] = 1;   // R12/15-1:0

                // Green
                vmap_out.rd[i][2][0] = 1;   // G12/15-7:6
                vmap_out.rd[i][2][1] = 1;   // G12/15-5:4
                vmap_out.rd[i][2][2] = 1;   // G12/15-3:2
                vmap_out.rd[i][2][3] = 1;   // G12/15-1:0

                // Blue
                vmap_out.rd[i][3][0] = 1;   // B12/15-7:6
                vmap_out.rd[i][3][1] = 1;   // B12/15-5:4
                vmap_out.rd[i][3][2] = 1;   // B12/15-3:2
                vmap_out.rd[i][3][3] = 1;   // B12/15-1:0
            end
        end

        default : ;
    endcase
    
    return vmap_out;
endfunction

// VMAP Generator 4PPC 10BPC
// This function generates the fifo reads in 4 pixel-per-clock 10-bits video mode
// This function reads 240 bytes from the fifo.
function fn_vmap_gen_out_struct vmap_gen_4ppc_10bpc (fn_vmap_gen_in_struct vmap_in);

    fn_vmap_gen_out_struct vmap_out;
   
    // Default
    for (int i = 0; i < P_LANES; i++)
    begin
        for (int j = 0; j < P_SEGMENTS; j++)
            vmap_out.rd[i][j] = 0;
    end

    case (vmap_in.sel)
        
        // Sequence 0
        'd16 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][0][0] = 1;   // R0/3-9:8
                vmap_out.rd[i][0][1] = 1;   // R0/3-7:6
                vmap_out.rd[i][0][2] = 1;   // R0/3-5:4
                vmap_out.rd[i][0][3] = 1;   // R0/3-3:2
                vmap_out.rd[i][1][0] = 1;   // R0/3-1:0

                // Green
                vmap_out.rd[i][1][1] = 1;   // G0/3-9:8
                vmap_out.rd[i][1][2] = 1;   // G0/3-7:6
                vmap_out.rd[i][1][3] = 1;   // G0/3-5:4
                vmap_out.rd[i][2][0] = 1;   // G0/3-3:2
                vmap_out.rd[i][2][1] = 1;   // G0/3-1:0

                // Blue
                vmap_out.rd[i][2][2] = 1;   // B0/3-9:8
                vmap_out.rd[i][2][3] = 1;   // B0/3-7:6
                vmap_out.rd[i][3][0] = 1;   // B0/3-5:4
                vmap_out.rd[i][3][1] = 1;   // B0/3-3:2
                vmap_out.rd[i][3][2] = 1;   // B0/3-1:0
            end
        end

        'd15 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][3][3] = 1;   // R4/7-9:8
                vmap_out.rd[i][0][0] = 1;   // R4/7-7:6
                vmap_out.rd[i][0][1] = 1;   // R4/7-5:4
                vmap_out.rd[i][0][2] = 1;   // R4/7-3:2
                vmap_out.rd[i][0][3] = 1;   // R4/7-1:0

                // Green
                vmap_out.rd[i][1][0] = 1;   // G4/7-9:8
                vmap_out.rd[i][1][1] = 1;   // G4/7-7:6
                vmap_out.rd[i][1][2] = 1;   // G4/7-5:4
                vmap_out.rd[i][1][3] = 1;   // G4/7-3:2
                vmap_out.rd[i][2][0] = 1;   // G4/7-1:0

                // Blue
                vmap_out.rd[i][2][1] = 1;   // B4/7-9:8
                vmap_out.rd[i][2][2] = 1;   // B4/7-7:6
                vmap_out.rd[i][2][3] = 1;   // B4/7-5:4
                vmap_out.rd[i][3][0] = 1;   // B4/7-3:2
                vmap_out.rd[i][3][1] = 1;   // B4/7-1:0
            end
        end

        'd14 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][3][2] = 1;   // R8/11-9:8
                vmap_out.rd[i][3][3] = 1;   // R8/11-7:6
                vmap_out.rd[i][0][0] = 1;   // R8/11-5:4
                vmap_out.rd[i][0][1] = 1;   // R8/11-3:2
                vmap_out.rd[i][0][2] = 1;   // R8/11-1:0

                // Green
                vmap_out.rd[i][0][3] = 1;   // G8/11-9:8
                vmap_out.rd[i][1][0] = 1;   // G8/11-7:6
                vmap_out.rd[i][1][1] = 1;   // G8/11-5:4
                vmap_out.rd[i][1][2] = 1;   // G8/11-3:2
                vmap_out.rd[i][1][3] = 1;   // G8/11-1:0

                // Blue
                vmap_out.rd[i][2][0] = 1;   // B8/11-9:8
                vmap_out.rd[i][2][1] = 1;   // B8/11-7:6
                vmap_out.rd[i][2][2] = 1;   // B8/11-5:4
                vmap_out.rd[i][2][3] = 1;   // B8/11-3:2
                vmap_out.rd[i][3][0] = 1;   // B8/11-1:0
            end
        end

        'd13 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][3][1] = 1;   // R12/15-9:8
                vmap_out.rd[i][3][2] = 1;   // R12/15-7:6
                vmap_out.rd[i][3][3] = 1;   // R12/15-5:4
                vmap_out.rd[i][0][0] = 1;   // R12/15-3:2
                vmap_out.rd[i][0][1] = 1;   // R12/15-1:0

                // Green
                vmap_out.rd[i][0][2] = 1;   // G12/15-9:8
                vmap_out.rd[i][0][3] = 1;   // G12/15-7:6
                vmap_out.rd[i][1][0] = 1;   // G12/15-5:4
                vmap_out.rd[i][1][1] = 1;   // G12/15-3:2
                vmap_out.rd[i][1][2] = 1;   // G12/15-1:0

                // Blue
                vmap_out.rd[i][1][3] = 1;   // B12/15-9:8
                vmap_out.rd[i][2][0] = 1;   // B12/15-7:6
                vmap_out.rd[i][2][1] = 1;   // B12/15-5:4
                vmap_out.rd[i][2][2] = 1;   // B12/15-3:2
                vmap_out.rd[i][2][3] = 1;   // B12/15-1:0
            end
        end

        'd12 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][3][0] = 1;   // R0/3-9:8
                vmap_out.rd[i][3][1] = 1;   // R0/3-7:6
                vmap_out.rd[i][3][2] = 1;   // R0/3-5:4
                vmap_out.rd[i][3][3] = 1;   // R0/3-3:2
                vmap_out.rd[i][0][0] = 1;   // R0/3-1:0

                // Green
                vmap_out.rd[i][0][1] = 1;   // G0/3-9:8
                vmap_out.rd[i][0][2] = 1;   // G0/3-7:6
                vmap_out.rd[i][0][3] = 1;   // G0/3-5:4
                vmap_out.rd[i][1][0] = 1;   // G0/3-3:2
                vmap_out.rd[i][1][1] = 1;   // G0/3-1:0

                // Blue
                vmap_out.rd[i][1][2] = 1;   // B0/3-9:8
                vmap_out.rd[i][1][3] = 1;   // B0/3-7:6
                vmap_out.rd[i][2][0] = 1;   // B0/3-5:4
                vmap_out.rd[i][2][1] = 1;   // B0/3-3:2
                vmap_out.rd[i][2][2] = 1;   // B0/3-1:0
            end
        end

        // Sequence 1
        'd11 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][2][3] = 1;   // R4/7-9:8
                vmap_out.rd[i][3][0] = 1;   // R4/7-7:6
                vmap_out.rd[i][3][1] = 1;   // R4/7-5:4
                vmap_out.rd[i][3][2] = 1;   // R4/7-3:2
                vmap_out.rd[i][3][3] = 1;   // R4/7-1:0

                // Green
                vmap_out.rd[i][0][0] = 1;   // G4/7-9:8
                vmap_out.rd[i][0][1] = 1;   // G4/7-7:6
                vmap_out.rd[i][0][2] = 1;   // G4/7-5:4
                vmap_out.rd[i][0][3] = 1;   // G4/7-3:2
                vmap_out.rd[i][1][0] = 1;   // G4/7-1:0

                // Blue
                vmap_out.rd[i][1][1] = 1;   // B4/7-9:8
                vmap_out.rd[i][1][2] = 1;   // B4/7-7:6
                vmap_out.rd[i][1][3] = 1;   // B4/7-5:4
                vmap_out.rd[i][2][0] = 1;   // B4/7-3:2
                vmap_out.rd[i][2][1] = 1;   // B4/7-1:0
            end
        end

        'd10 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][2][2] = 1;   // R8/11-9:8
                vmap_out.rd[i][2][3] = 1;   // R8/11-7:6
                vmap_out.rd[i][3][0] = 1;   // R8/11-5:4
                vmap_out.rd[i][3][1] = 1;   // R8/11-3:2
                vmap_out.rd[i][3][2] = 1;   // R8/11-1:0

                // Green
                vmap_out.rd[i][3][3] = 1;   // G8/11-9:8
                vmap_out.rd[i][0][0] = 1;   // G8/11-7:6
                vmap_out.rd[i][0][1] = 1;   // G8/11-5:4
                vmap_out.rd[i][0][2] = 1;   // G8/11-3:2
                vmap_out.rd[i][0][3] = 1;   // G8/11-1:0

                // Blue
                vmap_out.rd[i][1][0] = 1;   // B8/11-9:8
                vmap_out.rd[i][1][1] = 1;   // B8/11-7:6
                vmap_out.rd[i][1][2] = 1;   // B8/11-5:4
                vmap_out.rd[i][1][3] = 1;   // B8/11-3:2
                vmap_out.rd[i][2][0] = 1;   // B8/11-1:0
            end
        end

        'd9 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][2][1] = 1;   // R12/15-9:8
                vmap_out.rd[i][2][2] = 1;   // R12/15-7:6
                vmap_out.rd[i][2][3] = 1;   // R12/15-5:4
                vmap_out.rd[i][3][0] = 1;   // R12/15-3:2
                vmap_out.rd[i][3][1] = 1;   // R12/15-1:0

                // Green
                vmap_out.rd[i][3][2] = 1;   // G12/15-9:8
                vmap_out.rd[i][3][3] = 1;   // G12/15-7:6
                vmap_out.rd[i][0][0] = 1;   // G12/15-5:4
                vmap_out.rd[i][0][1] = 1;   // G12/15-3:2
                vmap_out.rd[i][0][2] = 1;   // G12/15-1:0

                // Blue
                vmap_out.rd[i][0][3] = 1;   // B12/15-9:8
                vmap_out.rd[i][1][0] = 1;   // B12/15-7:6
                vmap_out.rd[i][1][1] = 1;   // B12/15-5:4
                vmap_out.rd[i][1][2] = 1;   // B12/15-3:2
                vmap_out.rd[i][1][3] = 1;   // B12/15-1:0
            end
        end

        // Sequence 2
        'd8 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][2][0] = 1;   // R0/3-9:8
                vmap_out.rd[i][2][1] = 1;   // R0/3-7:6
                vmap_out.rd[i][2][2] = 1;   // R0/3-5:4
                vmap_out.rd[i][2][3] = 1;   // R0/3-3:2
                vmap_out.rd[i][3][0] = 1;   // R0/3-1:0

                // Green
                vmap_out.rd[i][3][1] = 1;   // G0/3-9:8
                vmap_out.rd[i][3][2] = 1;   // G0/3-7:6
                vmap_out.rd[i][3][3] = 1;   // G0/3-5:4
                vmap_out.rd[i][0][0] = 1;   // G0/3-3:2
                vmap_out.rd[i][0][1] = 1;   // G0/3-1:0

                // Blue
                vmap_out.rd[i][0][2] = 1;   // B0/3-9:8
                vmap_out.rd[i][0][3] = 1;   // B0/3-7:6
                vmap_out.rd[i][1][0] = 1;   // B0/3-5:4
                vmap_out.rd[i][1][1] = 1;   // B0/3-3:2
                vmap_out.rd[i][1][2] = 1;   // B0/3-1:0
            end
        end

        'd7 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][1][3] = 1;   // R4/7-9:8
                vmap_out.rd[i][2][0] = 1;   // R4/7-7:6
                vmap_out.rd[i][2][1] = 1;   // R4/7-5:4
                vmap_out.rd[i][2][2] = 1;   // R4/7-3:2
                vmap_out.rd[i][2][3] = 1;   // R4/7-1:0

                // Green
                vmap_out.rd[i][3][0] = 1;   // G4/7-9:8
                vmap_out.rd[i][3][1] = 1;   // G4/7-7:6
                vmap_out.rd[i][3][2] = 1;   // G4/7-5:4
                vmap_out.rd[i][3][3] = 1;   // G4/7-3:2
                vmap_out.rd[i][0][0] = 1;   // G4/7-1:0

                // Blue
                vmap_out.rd[i][0][1] = 1;   // B4/7-9:8
                vmap_out.rd[i][0][2] = 1;   // B4/7-7:6
                vmap_out.rd[i][0][3] = 1;   // B4/7-5:4
                vmap_out.rd[i][1][0] = 1;   // B4/7-3:2
                vmap_out.rd[i][1][1] = 1;   // B4/7-1:0
            end
        end

        'd6 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][1][2] = 1;   // R8/11-9:8
                vmap_out.rd[i][1][3] = 1;   // R8/11-7:6
                vmap_out.rd[i][2][0] = 1;   // R8/11-5:4
                vmap_out.rd[i][2][1] = 1;   // R8/11-3:2
                vmap_out.rd[i][2][2] = 1;   // R8/11-1:0

                // Green
                vmap_out.rd[i][2][3] = 1;   // G8/11-9:8
                vmap_out.rd[i][3][0] = 1;   // G8/11-7:6
                vmap_out.rd[i][3][1] = 1;   // G8/11-5:4
                vmap_out.rd[i][3][2] = 1;   // G8/11-3:2
                vmap_out.rd[i][3][3] = 1;   // G8/11-1:0

                // Blue
                vmap_out.rd[i][0][0] = 1;   // B8/11-9:8
                vmap_out.rd[i][0][1] = 1;   // B8/11-7:6
                vmap_out.rd[i][0][2] = 1;   // B8/11-5:4
                vmap_out.rd[i][0][3] = 1;   // B8/11-3:2
                vmap_out.rd[i][1][0] = 1;   // B8/11-1:0
            end
        end

        'd5 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][1][1] = 1;   // R12/15-9:8
                vmap_out.rd[i][1][2] = 1;   // R12/15-7:6
                vmap_out.rd[i][1][3] = 1;   // R12/15-5:4
                vmap_out.rd[i][2][0] = 1;   // R12/15-3:2
                vmap_out.rd[i][2][1] = 1;   // R12/15-1:0

                // Green
                vmap_out.rd[i][2][2] = 1;   // G12/15-9:8
                vmap_out.rd[i][2][3] = 1;   // G12/15-7:6
                vmap_out.rd[i][3][0] = 1;   // G12/15-5:4
                vmap_out.rd[i][3][1] = 1;   // G12/15-3:2
                vmap_out.rd[i][3][2] = 1;   // G12/15-1:0

                // Blue
                vmap_out.rd[i][3][3] = 1;   // B12/15-9:8
                vmap_out.rd[i][0][0] = 1;   // B12/15-7:6
                vmap_out.rd[i][0][1] = 1;   // B12/15-5:4
                vmap_out.rd[i][0][2] = 1;   // B12/15-3:2
                vmap_out.rd[i][0][3] = 1;   // B12/15-1:0
            end
        end

        'd4 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][1][0] = 1;   // R0/3-9:8
                vmap_out.rd[i][1][1] = 1;   // R0/3-7:6
                vmap_out.rd[i][1][2] = 1;   // R0/3-5:4
                vmap_out.rd[i][1][3] = 1;   // R0/3-3:2
                vmap_out.rd[i][2][0] = 1;   // R0/3-1:0

                // Green
                vmap_out.rd[i][2][1] = 1;   // G0/3-9:8
                vmap_out.rd[i][2][2] = 1;   // G0/3-7:6
                vmap_out.rd[i][2][3] = 1;   // G0/3-5:4
                vmap_out.rd[i][3][0] = 1;   // G0/3-3:2
                vmap_out.rd[i][3][1] = 1;   // G0/3-1:0

                // Blue
                vmap_out.rd[i][3][2] = 1;   // B0/3-9:8
                vmap_out.rd[i][3][3] = 1;   // B0/3-7:6
                vmap_out.rd[i][0][0] = 1;   // B0/3-5:4
                vmap_out.rd[i][0][1] = 1;   // B0/3-3:2
                vmap_out.rd[i][0][2] = 1;   // B0/3-1:0
            end
        end

        'd3 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][0][3] = 1;   // R4/7-9:8
                vmap_out.rd[i][1][0] = 1;   // R4/7-7:6
                vmap_out.rd[i][1][1] = 1;   // R4/7-5:4
                vmap_out.rd[i][1][2] = 1;   // R4/7-3:2
                vmap_out.rd[i][1][3] = 1;   // R4/7-1:0

                // Green
                vmap_out.rd[i][2][0] = 1;   // G4/7-9:8
                vmap_out.rd[i][2][1] = 1;   // G4/7-7:6
                vmap_out.rd[i][2][2] = 1;   // G4/7-5:4
                vmap_out.rd[i][2][3] = 1;   // G4/7-3:2
                vmap_out.rd[i][3][0] = 1;   // G4/7-1:0

                // Blue
                vmap_out.rd[i][3][1] = 1;   // B4/7-9:8
                vmap_out.rd[i][3][2] = 1;   // B4/7-7:6
                vmap_out.rd[i][3][3] = 1;   // B4/7-5:4
                vmap_out.rd[i][0][0] = 1;   // B4/7-3:2
                vmap_out.rd[i][0][1] = 1;   // B4/7-1:0
            end
        end

        'd2 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][0][2] = 1;   // R8/11-9:8
                vmap_out.rd[i][0][3] = 1;   // R8/11-7:6
                vmap_out.rd[i][1][0] = 1;   // R8/11-5:4
                vmap_out.rd[i][1][1] = 1;   // R8/11-3:2
                vmap_out.rd[i][1][2] = 1;   // R8/11-1:0

                // Green
                vmap_out.rd[i][1][3] = 1;   // G8/11-9:8
                vmap_out.rd[i][2][0] = 1;   // G8/11-7:6
                vmap_out.rd[i][2][1] = 1;   // G8/11-5:4
                vmap_out.rd[i][2][2] = 1;   // G8/11-3:2
                vmap_out.rd[i][2][3] = 1;   // G8/11-1:0

                // Blue
                vmap_out.rd[i][3][0] = 1;   // B8/11-9:8
                vmap_out.rd[i][3][1] = 1;   // B8/11-7:6
                vmap_out.rd[i][3][2] = 1;   // B8/11-5:4
                vmap_out.rd[i][3][3] = 1;   // B8/11-3:2
                vmap_out.rd[i][0][0] = 1;   // B8/11-1:0
            end
        end

        'd1 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][0][1] = 1;   // R12/15-9:8
                vmap_out.rd[i][0][2] = 1;   // R12/15-7:6
                vmap_out.rd[i][0][3] = 1;   // R12/15-5:4
                vmap_out.rd[i][1][0] = 1;   // R12/15-3:2
                vmap_out.rd[i][1][1] = 1;   // R12/15-1:0

                // Green
                vmap_out.rd[i][1][2] = 1;   // G12/15-9:8
                vmap_out.rd[i][1][3] = 1;   // G12/15-7:6
                vmap_out.rd[i][2][0] = 1;   // G12/15-5:4
                vmap_out.rd[i][2][1] = 1;   // G12/15-3:2
                vmap_out.rd[i][2][2] = 1;   // G12/15-1:0

                // Blue
                vmap_out.rd[i][2][3] = 1;   // B12/15-9:8
                vmap_out.rd[i][3][0] = 1;   // B12/15-7:6
                vmap_out.rd[i][3][1] = 1;   // B12/15-5:4
                vmap_out.rd[i][3][2] = 1;   // B12/15-3:2
                vmap_out.rd[i][3][3] = 1;   // B12/15-1:0
            end
        end

        default : ;
    endcase
    
    return vmap_out;
endfunction

// VMAP Assembler 2PPC 8BPC
// This function assembles the data in 2 pixel-per-clock 8-bits video mode
function fn_vmap_asm_out_struct vmap_asm_2ppc_8bpc (fn_vmap_asm_in_struct vmap_in);

    fn_vmap_asm_out_struct vmap_out;
   
    // Default
    for (int i = 0; i < P_PPC*3; i++)
        vmap_out.dat[i] = 0;

    vmap_out.vld = 0;

    case (vmap_in.sel)
        
        'd8 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                vmap_out.dat[(i*3)+1][(P_BPC-1)-:8] = {vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3]}; // Axis R0 
                vmap_out.dat[(i*3)+0][(P_BPC-1)-:8] = {vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3]}; // Axis G0 
                vmap_out.dat[(i*3)+2][(P_BPC-1)-:8] = {vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd7 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                vmap_out.dat[((i-2)*3)+1][(P_BPC-1)-:8] = {vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3]}; // Axis R0 
                vmap_out.dat[((i-2)*3)+0][(P_BPC-1)-:8] = {vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3]}; // Axis G0 
                vmap_out.dat[((i-2)*3)+2][(P_BPC-1)-:8] = {vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd6 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                vmap_out.dat[(i*3)+1][(P_BPC-1)-:8] = {vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3]}; // Axis R4 
                vmap_out.dat[(i*3)+0][(P_BPC-1)-:8] = {vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3]}; // Axis G4 
                vmap_out.dat[(i*3)+2][(P_BPC-1)-:8] = {vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3]}; // Axis B4 
            end

            vmap_out.vld = 1;
        end

        'd5 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                vmap_out.dat[((i-2)*3)+1][(P_BPC-1)-:8] = {vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3]}; // Axis R4 
                vmap_out.dat[((i-2)*3)+0][(P_BPC-1)-:8] = {vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3]}; // Axis G4 
                vmap_out.dat[((i-2)*3)+2][(P_BPC-1)-:8] = {vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3]}; // Axis B4 
            end

            vmap_out.vld = 1;
        end

        'd4 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                vmap_out.dat[(i*3)+1][(P_BPC-1)-:8] = {vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3]}; // Axis R8 
                vmap_out.dat[(i*3)+0][(P_BPC-1)-:8] = {vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3]}; // Axis G8 
                vmap_out.dat[(i*3)+2][(P_BPC-1)-:8] = {vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3]}; // Axis B8 
            end

            vmap_out.vld = 1;
        end

        'd3 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                vmap_out.dat[((i-2)*3)+1][(P_BPC-1)-:8] = {vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3]}; // Axis R8 
                vmap_out.dat[((i-2)*3)+0][(P_BPC-1)-:8] = {vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3]}; // Axis G8 
                vmap_out.dat[((i-2)*3)+2][(P_BPC-1)-:8] = {vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3]}; // Axis B8 
            end

            vmap_out.vld = 1;
        end

        'd2 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                vmap_out.dat[(i*3)+1][(P_BPC-1)-:8] = {vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3]}; // Axis R12 
                vmap_out.dat[(i*3)+0][(P_BPC-1)-:8] = {vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3]}; // Axis G12 
                vmap_out.dat[(i*3)+2][(P_BPC-1)-:8] = {vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3]}; // Axis B12 
            end

            vmap_out.vld = 1;
        end

        'd1 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                vmap_out.dat[((i-2)*3)+1][(P_BPC-1)-:8] = {vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3]}; // Axis R12 
                vmap_out.dat[((i-2)*3)+0][(P_BPC-1)-:8] = {vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3]}; // Axis G12 
                vmap_out.dat[((i-2)*3)+2][(P_BPC-1)-:8] = {vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3]}; // Axis B12 
            end

            vmap_out.vld = 1;
        end

        default : ;
    endcase

    return vmap_out;
endfunction 

// VMAP Assembler 2PPC 10BPC
// This function assembles the data in 2 pixel-per-clock 10-bits video mode
function fn_vmap_asm_out_struct vmap_asm_2ppc_10bpc (fn_vmap_asm_in_struct vmap_in);

    fn_vmap_asm_out_struct vmap_out;

    // Default
    for (int i = 0; i < P_PPC*3; i++)
        vmap_out.dat[i] = 0;

    vmap_out.vld = 0;

    case (vmap_in.sel)
        
        'd32 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2]}; // Axis B0 
            end
            
            vmap_out.vld = 1;
        end

        'd31 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                vmap_out.dat[((i-2)*3)+1] = {vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0]}; // Axis R0 
                vmap_out.dat[((i-2)*3)+0] = {vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1]}; // Axis G0 
                vmap_out.dat[((i-2)*3)+2] = {vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd30 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd29 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                vmap_out.dat[((i-2)*3)+1] = {vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3]}; // Axis R0 
                vmap_out.dat[((i-2)*3)+0] = {vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0]}; // Axis G0 
                vmap_out.dat[((i-2)*3)+2] = {vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd28 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd27 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                vmap_out.dat[((i-2)*3)+1] = {vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2]}; // Axis R0 
                vmap_out.dat[((i-2)*3)+0] = {vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3]}; // Axis G0 
                vmap_out.dat[((i-2)*3)+2] = {vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd26 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd25 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                vmap_out.dat[((i-2)*3)+1] = {vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1]}; // Axis R0 
                vmap_out.dat[((i-2)*3)+0] = {vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2]}; // Axis G0 
                vmap_out.dat[((i-2)*3)+2] = {vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd24 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd23 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                vmap_out.dat[((i-2)*3)+1] = {vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0]}; // Axis R0 
                vmap_out.dat[((i-2)*3)+0] = {vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1]}; // Axis G0 
                vmap_out.dat[((i-2)*3)+2] = {vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd22 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd21 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                vmap_out.dat[((i-2)*3)+1] = {vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3]}; // Axis R0 
                vmap_out.dat[((i-2)*3)+0] = {vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0]}; // Axis G0 
                vmap_out.dat[((i-2)*3)+2] = {vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd20 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd19 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                vmap_out.dat[((i-2)*3)+1] = {vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2]}; // Axis R0 
                vmap_out.dat[((i-2)*3)+0] = {vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3]}; // Axis G0 
                vmap_out.dat[((i-2)*3)+2] = {vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd18 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd17 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                vmap_out.dat[((i-2)*3)+1] = {vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1]}; // Axis R0 
                vmap_out.dat[((i-2)*3)+0] = {vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2]}; // Axis G0 
                vmap_out.dat[((i-2)*3)+2] = {vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd16 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd15 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                vmap_out.dat[((i-2)*3)+1] = {vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0]}; // Axis R0 
                vmap_out.dat[((i-2)*3)+0] = {vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1]}; // Axis G0 
                vmap_out.dat[((i-2)*3)+2] = {vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd14 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd13 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                vmap_out.dat[((i-2)*3)+1] = {vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3]}; // Axis R0 
                vmap_out.dat[((i-2)*3)+0] = {vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0]}; // Axis G0 
                vmap_out.dat[((i-2)*3)+2] = {vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd12 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd11 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                vmap_out.dat[((i-2)*3)+1] = {vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2]}; // Axis R0 
                vmap_out.dat[((i-2)*3)+0] = {vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3]}; // Axis G0 
                vmap_out.dat[((i-2)*3)+2] = {vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd10 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd9 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                vmap_out.dat[((i-2)*3)+1] = {vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1]}; // Axis R0 
                vmap_out.dat[((i-2)*3)+0] = {vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2]}; // Axis G0 
                vmap_out.dat[((i-2)*3)+2] = {vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd8 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd7 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                vmap_out.dat[((i-2)*3)+1] = {vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0]}; // Axis R0 
                vmap_out.dat[((i-2)*3)+0] = {vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1]}; // Axis G0 
                vmap_out.dat[((i-2)*3)+2] = {vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd6 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd5 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                vmap_out.dat[((i-2)*3)+1] = {vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3]}; // Axis R0 
                vmap_out.dat[((i-2)*3)+0] = {vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0]}; // Axis G0 
                vmap_out.dat[((i-2)*3)+2] = {vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd4 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd3 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                vmap_out.dat[((i-2)*3)+1] = {vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2]}; // Axis R0 
                vmap_out.dat[((i-2)*3)+0] = {vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3]}; // Axis G0 
                vmap_out.dat[((i-2)*3)+2] = {vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd2 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd1 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                vmap_out.dat[((i-2)*3)+1] = {vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1]}; // Axis R0 
                vmap_out.dat[((i-2)*3)+0] = {vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2]}; // Axis G0 
                vmap_out.dat[((i-2)*3)+2] = {vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        default : ;
    endcase

    return vmap_out;
endfunction 

// VMAP Assembler 4PPC 8BPC
// This function assembles the data in 4 pixel-per-clock 8-bits video mode
function fn_vmap_asm_out_struct vmap_asm_4ppc_8bpc (fn_vmap_asm_in_struct vmap_in);

    fn_vmap_asm_out_struct vmap_out;
   
    // Default
    for (int i = 0; i < P_PPC*3; i++)
        vmap_out.dat[i] = 0;

    vmap_out.vld = 0;

    case (vmap_in.sel)
        
        'd4 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                vmap_out.dat[(i*3)+1][(P_BPC-1)-:8] = {vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3]}; // Axis R0 
                vmap_out.dat[(i*3)+0][(P_BPC-1)-:8] = {vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3]}; // Axis G0 
                vmap_out.dat[(i*3)+2][(P_BPC-1)-:8] = {vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd3 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                vmap_out.dat[(i*3)+1][(P_BPC-1)-:8] = {vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3]}; // Axis R4 
                vmap_out.dat[(i*3)+0][(P_BPC-1)-:8] = {vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3]}; // Axis G4 
                vmap_out.dat[(i*3)+2][(P_BPC-1)-:8] = {vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3]}; // Axis B4 
            end

            vmap_out.vld = 1;
        end

        'd2 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                vmap_out.dat[(i*3)+1][(P_BPC-1)-:8] = {vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3]}; // Axis R8 
                vmap_out.dat[(i*3)+0][(P_BPC-1)-:8] = {vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3]}; // Axis G8 
                vmap_out.dat[(i*3)+2][(P_BPC-1)-:8] = {vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3]}; // Axis B8 
            end

            vmap_out.vld = 1;
        end

        'd1 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                vmap_out.dat[(i*3)+1][(P_BPC-1)-:8] = {vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3]}; // Axis R12 
                vmap_out.dat[(i*3)+0][(P_BPC-1)-:8] = {vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3]}; // Axis G12 
                vmap_out.dat[(i*3)+2][(P_BPC-1)-:8] = {vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3]}; // Axis B12 
            end

            vmap_out.vld = 1;
        end

        default : ;
    endcase

    return vmap_out;
endfunction 

// VMAP Assembler 4PPC 10BPC
// This function assembles the data in 4 pixel-per-clock 10-bits video mode
function fn_vmap_asm_out_struct vmap_asm_4ppc_10bpc (fn_vmap_asm_in_struct vmap_in);

    fn_vmap_asm_out_struct vmap_out;

    // Default
    for (int i = 0; i < P_PPC*3; i++)
        vmap_out.dat[i] = 0;

    vmap_out.vld = 0;

    case (vmap_in.sel)
        
        'd16 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2]}; // Axis B0 
            end
            
            vmap_out.vld = 1;
        end

        'd15 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd14 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd13 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd12 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd11 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd10 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd9 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd8 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd7 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd6 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd5 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd4 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1], vmap_in.dat[i][0][2]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd3 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2], vmap_in.dat[i][1][3]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3], vmap_in.dat[i][3][0]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0], vmap_in.dat[i][0][1]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd2 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1], vmap_in.dat[i][1][2]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2], vmap_in.dat[i][2][3]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3], vmap_in.dat[i][0][0]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        'd1 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                vmap_out.dat[(i*3)+1] = {vmap_in.dat[i][0][1], vmap_in.dat[i][0][2], vmap_in.dat[i][0][3], vmap_in.dat[i][1][0], vmap_in.dat[i][1][1]}; // Axis R0 
                vmap_out.dat[(i*3)+0] = {vmap_in.dat[i][1][2], vmap_in.dat[i][1][3], vmap_in.dat[i][2][0], vmap_in.dat[i][2][1], vmap_in.dat[i][2][2]}; // Axis G0 
                vmap_out.dat[(i*3)+2] = {vmap_in.dat[i][2][3], vmap_in.dat[i][3][0], vmap_in.dat[i][3][1], vmap_in.dat[i][3][2], vmap_in.dat[i][3][3]}; // Axis B0 
            end

            vmap_out.vld = 1;
        end

        default : ;
    endcase

    return vmap_out;
endfunction 

// Logic

// Map control
    assign clk_ctl.bpc = CFG_BPC_IN;

// Map video
    assign clk_map.str = MAP_STR_IN;
    assign clk_map.stp = MAP_STP_IN;
    assign clk_map.head = MAP_HEAD_IN;

generate    
    for (i = 0; i < P_LANES; i++)
    begin : gen_vid_dat
        for (j = 0; j < P_SEGMENTS; j++)
        begin : gen_vid_dat
            assign clk_map.dat[i][j] = MAP_DAT_IN[i][j];
        end
    end
endgenerate

// State machine
    always_ff @ (posedge RST_IN, posedge CLK_IN)
    begin
        // Reset
        if (RST_IN)
            clk_map.sm_cur <= sm_idle;

        else
        begin
            // Force on start
            if (clk_map.str)
                clk_map.sm_cur <= sm_str;

            else
                clk_map.sm_cur <= clk_map.sm_nxt;
        end
    end

// State machine decoder
    always_comb
    begin
        // Default
        clk_map.run_set = 0;
        clk_map.run_clr = 0;
        clk_map.sm_gen_sel_ld = 0;

        case (clk_map.sm_cur)

            sm_idle : 
            begin
                // Clear run
                clk_map.run_clr = 1;
                clk_map.sm_nxt = sm_idle;
            end

            sm_str :
            begin
                // Set run
                clk_map.run_set = 1;
                clk_map.sm_nxt = sm_run;
            end

            sm_run :
            begin
                // Wait for stop signal 
                if (clk_map.stp)
                    clk_map.sm_nxt = sm_wait;

                else
                    clk_map.sm_nxt = sm_run;
            end

            sm_wait : 
            begin
                // Wait for current cycle to finish
                if (clk_map.gen_sel_end)
                begin
                    // All pixels haven been processed
                    if (clk_map.lvl == 0)
                        clk_map.sm_nxt = sm_idle;

                    // Flush
                    else
                    begin
                        // Force start generator sequence
                        clk_map.sm_gen_sel_ld = 1;
                        clk_map.sm_nxt = sm_flush;
                    end
                end

                else
                    clk_map.sm_nxt = sm_wait;
            end

            sm_flush : 
            begin
                // Wait for cycle to finish
                if (clk_map.gen_sel_end)
                    clk_map.sm_nxt = sm_idle;

                else
                    clk_map.sm_nxt = sm_flush;
            end

            default : 
            begin
                clk_map.sm_nxt = sm_idle;
            end

        endcase
    end

// Run
    always_ff @ (posedge RST_IN, posedge CLK_IN)
    begin
        // Reset
        if (RST_IN)
            clk_map.run <= 0;
        
        else
        begin
            // Clear
            if (clk_map.run_clr)
                clk_map.run <= 0;

            // Set
            else if (clk_map.run_set)
                clk_map.run <= 1;
        end
    end            

// Tail
// The tail counts the number of bytes read from the fifo.
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_map.run)
        begin
            // Increment
            if (clk_map.gen_sel_ld)
                clk_map.tail <= clk_map.tail + clk_map.lvl_thres;
        end

        // Idle
        else
            clk_map.tail <= 0;
    end

// Level
// The level shows how many unread bytes are stored in the fifo.
    always_ff @ (posedge CLK_IN)
    begin
        // During flushing the tail may become larger than than the head,
        // so force the level to zero when the tail is larger than the head. 
        if (clk_map.tail > clk_map.head)
            clk_map.lvl <= 0;
        else    
            clk_map.lvl <= clk_map.head - clk_map.tail;
    end

// VMAP generator
generate
    if (P_BPC == 10)
    begin : gen_vmap_gen_10bpc      
        // Assign function inputs
        assign fn_vmap_gen_in.sel = clk_map.gen_sel;

        // 4 pixels per clock
        if (P_PPC == 4)
        begin : gen_vmap_gen_4ppc
            always_comb
            begin
                // 10-bits video
                if (clk_ctl.bpc)
                    fn_vmap_gen_out = vmap_gen_4ppc_10bpc (fn_vmap_gen_in);
                
                // 8-bits video
                else
                    fn_vmap_gen_out = vmap_gen_4ppc_8bpc (fn_vmap_gen_in);
            end
        end

        else 
        begin : gen_vmap_gen_2ppc
            always_comb
            begin
                // 10-bits video
                if (clk_ctl.bpc)
                    fn_vmap_gen_out = vmap_gen_2ppc_10bpc (fn_vmap_gen_in);
                
                // 8-bits video
                else
                    fn_vmap_gen_out = vmap_gen_2ppc_8bpc (fn_vmap_gen_in);
            end
        end

        // Assign function outputs
        assign clk_map.rd = fn_vmap_gen_out.rd;
    end

    // 8-bits
    else
    begin : gen_vmap_gen_8bpc
        // Assign function inputs
        assign fn_vmap_gen_in.sel = clk_map.gen_sel;

        // 4 pixels per clock
        if (P_PPC == 4)
        begin : gen_vmap_asm_4ppc
            assign fn_vmap_gen_out = vmap_gen_4ppc_8bpc (fn_vmap_gen_in);
        end

        // 2 pixels per clock
        else
        begin : gen_vmap_asm_4ppc
            assign fn_vmap_gen_out = vmap_gen_2ppc_8bpc (fn_vmap_gen_in);
        end

        // Assign function outputs
        assign clk_map.rd = fn_vmap_gen_out.rd;
   end
endgenerate

// VMAP assembler
generate
    if (P_BPC == 10)
    begin : gen_vmap_asm_10bpc
        
        // Assign function inputs
        assign fn_vmap_asm_in.sel = clk_map.asm_sel[P_LAT-1];
        assign fn_vmap_asm_in.dat = clk_map.dat;

        // 4 pixels per clock
        if (P_PPC == 4)
        begin : gen_vmap_asm_4ppc
            always_comb
            begin
                // 10-bits video
                if (clk_ctl.bpc)
                    fn_vmap_asm_out = vmap_asm_4ppc_10bpc (fn_vmap_asm_in);
                
                // 8-bits video
                else
                    fn_vmap_asm_out = vmap_asm_4ppc_8bpc (fn_vmap_asm_in);
            end

            // Video data
            for (i = 0; i < (P_PPC * 3); i++)
                assign clk_vid.dat[(i*P_BPC)+:P_BPC] = fn_vmap_asm_out.dat[i];
        end

        // 2 pixels per clock
        else
        begin : gen_vmap_asm_2ppc
            always_comb
            begin
                // 10-bits video
                if (clk_ctl.bpc)
                    fn_vmap_asm_out = vmap_asm_2ppc_10bpc (fn_vmap_asm_in);
                
                // 8-bits video
                else
                    fn_vmap_asm_out = vmap_asm_2ppc_8bpc (fn_vmap_asm_in);
            end

            // Video data
            for (i = 0; i < (P_PPC * 3); i++)
                assign clk_vid.dat[(i*P_BPC)+:P_BPC] = fn_vmap_asm_out.dat[i];
            
            // In this configuration the video pixel bus is 60 bits wide.
            // The AXI data width is 64 bits.
            // To prevent any floating bits, the upper unused bits are wired to zero.
            assign clk_vid.dat[$high(clk_vid.dat):3*P_PPC*P_BPC] = 0;
        end

        assign clk_vid.vld = fn_vmap_asm_out.vld;
    end

    // 8-bits
    else
    begin : gen_vmap_asm_8bpc

        // Assign function inputs
        assign fn_vmap_asm_in.sel = clk_map.asm_sel[P_LAT-1];
        assign fn_vmap_asm_in.dat = clk_map.dat;

        // 4 pixels per clock
        if (P_PPC == 4)
        begin : gen_vmap_asm_4ppc
            assign fn_vmap_asm_out = vmap_asm_4ppc_8bpc (fn_vmap_asm_in);
        end

        // 2 pixels per clock
        else
        begin : gen_vmap_asm_4ppc
            assign fn_vmap_asm_out = vmap_asm_2ppc_8bpc (fn_vmap_asm_in);
        end

        // Video data
        for (i = 0; i < (P_PPC * 3); i++)
            assign clk_vid.dat[(i*P_BPC)+:P_BPC] = fn_vmap_asm_out.dat[i];
        assign clk_vid.vld = fn_vmap_asm_out.vld;
   end

endgenerate

// Select init value
    always_comb
    begin
        // 10-bits video
        if (clk_ctl.bpc)
            clk_map.gen_sel_init = P_SEL_INIT_10BPC;
        
        // 8-bits video
        else
            clk_map.gen_sel_init = P_SEL_INIT_8BPC;
    end

// Level threshold
    always_comb
    begin
        // 10-bits video
        if (clk_ctl.bpc)
            clk_map.lvl_thres = P_LVL_THRESHOLD_10BPC; 
        
        // 8-bits video
        else
            clk_map.lvl_thres = P_LVL_THRESHOLD_8BPC; 
    end

// Generator Select
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_map.run)
        begin
            // Load
            if (clk_map.gen_sel_ld)
                clk_map.gen_sel <= clk_map.gen_sel_init;
            
            // Decrement
            else if (!clk_map.gen_sel_end)
                clk_map.gen_sel <= clk_map.gen_sel - 'd1;
        end

        // Idle
        else
            clk_map.gen_sel <= 0;
    end

// Select end
    always_comb
    begin
        if (clk_map.gen_sel == 0)
            clk_map.gen_sel_end = 1;
        else
            clk_map.gen_sel_end = 0;
    end

//-----
// Select end edge detector
// This is used to generate the eol
//-----
    prt_lib_edge
    SEL_END_EDGE_INST
    (
        .CLK_IN    (CLK_IN),                    // Clock
        .CKE_IN    (1'b1),                      // Clock enable
        .A_IN      (clk_map.gen_sel_end),       // Input
        .RE_OUT    (clk_map.gen_sel_end_re),    // Rising edge
        .FE_OUT    ()                           // Falling edge
    );

// Select load
// The generator sequence can be started, when the fifo has enough data and the current sequence has been (almost) completed. 
// Or it can be forced by the state machine when flushing. 
    always_comb
    begin
        // Default 
        clk_map.gen_sel_ld = 0;

        // Force by state machine
        if (clk_map.sm_gen_sel_ld)
            clk_map.gen_sel_ld = 1;
            
        // Is there enough data in the fifo?
        else if (clk_map.lvl >= clk_map.lvl_thres)
        begin
            // Load when the sequence has been completed or almost completed. 
            if (clk_map.gen_sel_end || (clk_map.gen_sel == 'd1))
                clk_map.gen_sel_ld = 1;
        end
    end

// Assembler Select
    always_ff @ (posedge CLK_IN)
    begin
        for (int i = 0; i < P_LAT; i++)
        begin
            // Run 
            if (clk_map.run)
            begin
                if (i == 0)
                    clk_map.asm_sel[i] <= clk_map.gen_sel;
                else
                    clk_map.asm_sel[i] <= clk_map.asm_sel[i-1];
            end

            // Idle
            else
                clk_map.asm_sel[i] <= 0;
        end
    end


// End-of-line
    always_ff @ (posedge CLK_IN)
    begin
        if (clk_map.gen_sel_end_re && clk_map.stp && (clk_map.lvl == 0))
            clk_vid.eol <= 1;
        else
            clk_vid.eol <= 0;
    end


//-----
// Outputs
//-----
    assign MAP_RD_OUT = clk_map.rd;
    assign VID_DAT_OUT = clk_vid.dat;
    assign VID_EOL_OUT = clk_vid.eol;
    assign VID_VLD_OUT = clk_vid.vld;

endmodule

`default_nettype wire
