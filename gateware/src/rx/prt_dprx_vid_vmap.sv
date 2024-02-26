/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP RX Video - video mapper
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
    input wire                          RST_IN,             // Reset
    input wire                          CLK_IN,             // Clock

    // Control
    input wire                          CFG_BPC_IN,         // Active bits-per-component

    // Mapper
    input wire                          MAP_RUN_IN,             // Run
    input wire [5:0]                    MAP_LVL_IN,             // Level
    output wire [P_STRIPES-1:0]         MAP_RD_OUT[P_LANES][P_SEGMENTS],       // Read
    input wire [1:0]                    MAP_DAT_IN[P_LANES][P_SEGMENTS][P_STRIPES],    // Data
    input wire [P_STRIPES-1:0]          MAP_DE_IN[P_LANES][P_SEGMENTS],                 // Data enable

    // Video
    output wire [P_VID_DAT-1:0]         VID_DAT_OUT,            // Video data
    output wire                         VID_VLD_OUT             // Video valid
);

// Parameters
localparam P_LAT = 2;           // Read latency
localparam P_SEL_INIT_8BPC = (P_PPC == 4) ? 4 : 8;
localparam P_SEL_INIT_10BPC = (P_PPC == 4) ? 16 : 32;
localparam P_LVL_THRESHOLD_8BPC = 3;
localparam P_LVL_THRESHOLD_10BPC = 15;

// Structures
typedef struct {
    logic                           bpc;
} ctl_struct;

typedef struct {
    logic                           run;
    logic [5:0]                     lvl;
    logic [5:0]                     lvl_thres;
    logic [5:0]                     gen_sel_init;
    logic [5:0]                     gen_sel;
    logic                           gen_sel_ld;
    logic                           gen_sel_end;
    logic [5:0]                     asm_sel[P_LAT];
    logic [P_STRIPES-1:0]           rd[P_LANES][P_SEGMENTS];   
    logic [1:0]                     dat[P_LANES][P_SEGMENTS][P_STRIPES];
} map_struct;

typedef struct {
    logic [P_VID_DAT-1:0]           dat;
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

// Signals
ctl_struct                  clk_ctl;
map_struct                  clk_map;
vid_struct                  clk_vid;

fn_vmap_gen_in_struct       fn_vmap_gen_in;
fn_vmap_gen_out_struct      fn_vmap_gen_out;

fn_vmap_asm_in_struct       fn_vmap_asm_in;
fn_vmap_asm_out_struct      fn_vmap_asm_out;

genvar i, j;

// Functions

// VMAP Generator 2PPC 8BPC
// This function generates the fifo reads in 2 pixel-per-clock 8-bits video mode
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
                vmap_out.rd[i][0][0] = 1;   // R0-7:6
                vmap_out.rd[i][0][1] = 1;   // R0-5:4
                vmap_out.rd[i][0][2] = 1;   // R0-3:2
                vmap_out.rd[i][0][3] = 1;   // R0-1:0

                // Green
                vmap_out.rd[i][1][0] = 1;   // G0-7:6
                vmap_out.rd[i][1][1] = 1;   // G0-5:4
                vmap_out.rd[i][1][2] = 1;   // G0-3:2
                vmap_out.rd[i][1][3] = 1;   // G0-1:0

                // Blue
                vmap_out.rd[i][2][0] = 1;   // B0-7:6
                vmap_out.rd[i][2][1] = 1;   // B0-5:4
                vmap_out.rd[i][2][2] = 1;   // B0-3:2
                vmap_out.rd[i][2][3] = 1;   // B0-1:0
            end
        end

        'd7 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][0][0] = 1;   // R0-7:6
                vmap_out.rd[i][0][1] = 1;   // R0-5:4
                vmap_out.rd[i][0][2] = 1;   // R0-3:2
                vmap_out.rd[i][0][3] = 1;   // R0-1:0

                // Green
                vmap_out.rd[i][1][0] = 1;   // G0-7:6
                vmap_out.rd[i][1][1] = 1;   // G0-5:4
                vmap_out.rd[i][1][2] = 1;   // G0-3:2
                vmap_out.rd[i][1][3] = 1;   // G0-1:0

                // Blue
                vmap_out.rd[i][2][0] = 1;   // B0-7:6
                vmap_out.rd[i][2][1] = 1;   // B0-5:4
                vmap_out.rd[i][2][2] = 1;   // B0-3:2
                vmap_out.rd[i][2][3] = 1;   // B0-1:0
            end
        end

        'd6 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                // Red
                vmap_out.rd[i][3][0] = 1;   // R4-7:6
                vmap_out.rd[i][3][1] = 1;   // R4-5:4
                vmap_out.rd[i][3][2] = 1;   // R4-3:2
                vmap_out.rd[i][3][3] = 1;   // R4-1:0

                // Green
                vmap_out.rd[i][0][0] = 1;   // G4-7:6
                vmap_out.rd[i][0][1] = 1;   // G4-5:4
                vmap_out.rd[i][0][2] = 1;   // G4-3:2
                vmap_out.rd[i][0][3] = 1;   // G4-1:0

                // Blue
                vmap_out.rd[i][1][0] = 1;   // B4-7:6
                vmap_out.rd[i][1][1] = 1;   // B4-5:4
                vmap_out.rd[i][1][2] = 1;   // B4-3:2
                vmap_out.rd[i][1][3] = 1;   // B4-1:0
            end
        end

        'd5 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][3][0] = 1;   // R4-7:6
                vmap_out.rd[i][3][1] = 1;   // R4-5:4
                vmap_out.rd[i][3][2] = 1;   // R4-3:2
                vmap_out.rd[i][3][3] = 1;   // R4-1:0

                // Green
                vmap_out.rd[i][0][0] = 1;   // G4-7:6
                vmap_out.rd[i][0][1] = 1;   // G4-5:4
                vmap_out.rd[i][0][2] = 1;   // G4-3:2
                vmap_out.rd[i][0][3] = 1;   // G4-1:0

                // Blue
                vmap_out.rd[i][1][0] = 1;   // B4-7:6
                vmap_out.rd[i][1][1] = 1;   // B4-5:4
                vmap_out.rd[i][1][2] = 1;   // B4-3:2
                vmap_out.rd[i][1][3] = 1;   // B4-1:0
            end
        end

        'd4 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                // Red
                vmap_out.rd[i][2][0] = 1;   // R8-7:6
                vmap_out.rd[i][2][1] = 1;   // R8-5:4
                vmap_out.rd[i][2][2] = 1;   // R8-3:2
                vmap_out.rd[i][2][3] = 1;   // R8-1:0

                // Green
                vmap_out.rd[i][3][0] = 1;   // G8-7:6
                vmap_out.rd[i][3][1] = 1;   // G8-5:4
                vmap_out.rd[i][3][2] = 1;   // G8-3:2
                vmap_out.rd[i][3][3] = 1;   // G8-1:0

                // Blue
                vmap_out.rd[i][0][0] = 1;   // B8-7:6
                vmap_out.rd[i][0][1] = 1;   // B8-5:4
                vmap_out.rd[i][0][2] = 1;   // B8-3:2
                vmap_out.rd[i][0][3] = 1;   // B8-1:0
            end
        end

        'd3 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][2][0] = 1;   // R8-7:6
                vmap_out.rd[i][2][1] = 1;   // R8-5:4
                vmap_out.rd[i][2][2] = 1;   // R8-3:2
                vmap_out.rd[i][2][3] = 1;   // R8-1:0

                // Green
                vmap_out.rd[i][3][0] = 1;   // G8-7:6
                vmap_out.rd[i][3][1] = 1;   // G8-5:4
                vmap_out.rd[i][3][2] = 1;   // G8-3:2
                vmap_out.rd[i][3][3] = 1;   // G8-1:0

                // Blue
                vmap_out.rd[i][0][0] = 1;   // B8-7:6
                vmap_out.rd[i][0][1] = 1;   // B8-5:4
                vmap_out.rd[i][0][2] = 1;   // B8-3:2
                vmap_out.rd[i][0][3] = 1;   // B8-1:0
            end
        end

        'd2 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                // Red
                vmap_out.rd[i][1][0] = 1;   // R12-7:6
                vmap_out.rd[i][1][1] = 1;   // R12-5:4
                vmap_out.rd[i][1][2] = 1;   // R12-3:2
                vmap_out.rd[i][1][3] = 1;   // R12-1:0

                // Green
                vmap_out.rd[i][2][0] = 1;   // G12-7:6
                vmap_out.rd[i][2][1] = 1;   // G12-5:4
                vmap_out.rd[i][2][2] = 1;   // G12-3:2
                vmap_out.rd[i][2][3] = 1;   // G12-1:0

                // Blue
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
                vmap_out.rd[i][1][0] = 1;   // R12-7:6
                vmap_out.rd[i][1][1] = 1;   // R12-5:4
                vmap_out.rd[i][1][2] = 1;   // R12-3:2
                vmap_out.rd[i][1][3] = 1;   // R12-1:0

                // Green
                vmap_out.rd[i][2][0] = 1;   // G12-7:6
                vmap_out.rd[i][2][1] = 1;   // G12-5:4
                vmap_out.rd[i][2][2] = 1;   // G12-3:2
                vmap_out.rd[i][2][3] = 1;   // G12-1:0

                // Blue
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

// VMAP Generator 2PPC 10BPC
// This function generates the fifo reads in 2 pixel-per-clock 10-bits video mode
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
                vmap_out.rd[i][0][0] = 1;   // R0-7:6
                vmap_out.rd[i][0][1] = 1;   // R0-5:4
                vmap_out.rd[i][0][2] = 1;   // R0-3:2
                vmap_out.rd[i][0][3] = 1;   // R0-1:0

                // Green
                vmap_out.rd[i][1][0] = 1;   // G0-7:6
                vmap_out.rd[i][1][1] = 1;   // G0-5:4
                vmap_out.rd[i][1][2] = 1;   // G0-3:2
                vmap_out.rd[i][1][3] = 1;   // G0-1:0

                // Blue
                vmap_out.rd[i][2][0] = 1;   // B0-7:6
                vmap_out.rd[i][2][1] = 1;   // B0-5:4
                vmap_out.rd[i][2][2] = 1;   // B0-3:2
                vmap_out.rd[i][2][3] = 1;   // B0-1:0
            end
        end

        'd3 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][3][0] = 1;   // R4-7:6
                vmap_out.rd[i][3][1] = 1;   // R4-5:4
                vmap_out.rd[i][3][2] = 1;   // R4-3:2
                vmap_out.rd[i][3][3] = 1;   // R4-1:0

                // Green
                vmap_out.rd[i][0][0] = 1;   // G4-7:6
                vmap_out.rd[i][0][1] = 1;   // G4-5:4
                vmap_out.rd[i][0][2] = 1;   // G4-3:2
                vmap_out.rd[i][0][3] = 1;   // G4-1:0

                // Blue
                vmap_out.rd[i][1][0] = 1;   // B4-7:6
                vmap_out.rd[i][1][1] = 1;   // B4-5:4
                vmap_out.rd[i][1][2] = 1;   // B4-3:2
                vmap_out.rd[i][1][3] = 1;   // B4-1:0
            end
        end

        'd2 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][2][0] = 1;   // R8-7:6
                vmap_out.rd[i][2][1] = 1;   // R8-5:4
                vmap_out.rd[i][2][2] = 1;   // R8-3:2
                vmap_out.rd[i][2][3] = 1;   // R8-1:0

                // Green
                vmap_out.rd[i][3][0] = 1;   // G8-7:6
                vmap_out.rd[i][3][1] = 1;   // G8-5:4
                vmap_out.rd[i][3][2] = 1;   // G8-3:2
                vmap_out.rd[i][3][3] = 1;   // G8-1:0

                // Blue
                vmap_out.rd[i][0][0] = 1;   // B8-7:6
                vmap_out.rd[i][0][1] = 1;   // B8-5:4
                vmap_out.rd[i][0][2] = 1;   // B8-3:2
                vmap_out.rd[i][0][3] = 1;   // B8-1:0
            end
        end

        'd1 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                // Red
                vmap_out.rd[i][1][0] = 1;   // R12-7:6
                vmap_out.rd[i][1][1] = 1;   // R12-5:4
                vmap_out.rd[i][1][2] = 1;   // R12-3:2
                vmap_out.rd[i][1][3] = 1;   // R12-1:0

                // Green
                vmap_out.rd[i][2][0] = 1;   // G12-7:6
                vmap_out.rd[i][2][1] = 1;   // G12-5:4
                vmap_out.rd[i][2][2] = 1;   // G12-3:2
                vmap_out.rd[i][2][3] = 1;   // G12-1:0

                // Blue
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

// VMAP Generator 4PPC 10BPC
// This function generates the fifo reads in 4 pixel-per-clock 10-bits video mode
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

        'd15 : 
        begin
            for (int i = 0; i < 4; i++)
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

        'd14 : 
        begin
            for (int i = 0; i < 4; i++)
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

        'd13 : 
        begin
            for (int i = 0; i < 4; i++)
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

        'd12 : 
        begin
            for (int i = 0; i < 4; i++)
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
        'd11 : 
        begin
            for (int i = 0; i < 4; i++)
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

        'd10 : 
        begin
            for (int i = 0; i < 4; i++)
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

        'd9 : 
        begin
            for (int i = 0; i < 4; i++)
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
        'd8 : 
        begin
            for (int i = 0; i < 4; i++)
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

        'd7 : 
        begin
            for (int i = 0; i < 4; i++)
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

        'd6 : 
        begin
            for (int i = 0; i < 4; i++)
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

        'd5 : 
        begin
            for (int i = 0; i < 4; i++)
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

        'd4 : 
        begin
            for (int i = 0; i < 4; i++)
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

        'd3 : 
        begin
            for (int i = 0; i < 4; i++)
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

        'd2 : 
        begin
            for (int i = 0; i < 4; i++)
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

        'd1 : 
        begin
            for (int i = 0; i < 4; i++)
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
    assign clk_map.run = MAP_RUN_IN;
    assign clk_map.lvl = MAP_LVL_IN;

generate    
    for (i = 0; i < P_LANES; i++)
    begin : gen_vid_dat
        for (j = 0; j < P_SEGMENTS; j++)
        begin : gen_vid_dat
            assign clk_map.dat[i][j] = MAP_DAT_IN[i][j];
        end
    end
endgenerate

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
        end

        // Video data
        for (i = 0; i < (P_PPC * 3); i++)
            assign clk_vid.dat[(i*P_BPC)+:P_BPC] = fn_vmap_asm_out.dat[i];
    
        assign clk_vid.dat[$high(clk_vid.dat):(P_PPC * P_BPC * 3)] = 0;
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

// Select load
    always_comb
    begin
        if ((clk_map.gen_sel_end || (clk_map.gen_sel == 'd1)) && (clk_map.lvl >= clk_map.lvl_thres))
            clk_map.gen_sel_ld = 1;
        else
            clk_map.gen_sel_ld = 0;
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

// Outputs
    assign MAP_RD_OUT = clk_map.rd;
    assign VID_DAT_OUT = clk_vid.dat;
    assign VID_VLD_OUT = clk_vid.vld;

endmodule

`default_nettype wire
