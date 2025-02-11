/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP TX Video - video mapper
    (c) 2021 - 2025 by Parretto B.V.

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

module prt_dptx_vid_vmap
#(
    // Video
    parameter                           P_PPC = 2,          // Pixels per clock
    parameter                           P_BPC = 8,          // Bits per component
    parameter                           P_LANES = 4,        // Lanes
    parameter                           P_SEGMENTS = 4,     // Segments
    parameter                           P_STRIPES = 4       // Stripes
)
(
    input wire                          RST_IN,                                         // Reset
    input wire                          CLK_IN,                                         // Clock
       
    // Control
    input wire                          CFG_BPC_IN,                                     // Active bits-per-component

    // Video
    input wire                          VID_RUN_IN,                                     // Run
    input wire                          VID_CLR_IN,                                     // Clear
    input wire  [(P_PPC * P_BPC)-1:0]   VID_DAT_IN[3],                                  // Data
    input wire                          VID_DE_IN,                                      // Data enable

    // Mapper
    output wire [1:0]                   MAP_DAT_OUT[P_LANES][P_SEGMENTS][P_STRIPES],    // Data
    output wire [P_STRIPES-1:0]         MAP_WR_OUT[P_LANES][P_SEGMENTS]                 // Read
);

// Parameters
localparam P_SEL_END_8BPC = (P_PPC == 4) ? 3 : 7;
localparam P_SEL_END_10BPC = (P_PPC == 4) ? 15 : 31;

// Structures
typedef struct {
    logic                           bpc;
} ctl_struct;

typedef struct {
    logic                           run;
    logic                           clr;
    logic [(P_PPC * P_BPC)-1:0]     dat[3];
    logic                           de;
} vid_struct;

typedef struct {
    logic [5:0]                     sel;
    logic [5:0]                     sel_end;
    logic [1:0]                     dat[P_LANES][P_SEGMENTS][P_STRIPES];
    logic [P_STRIPES-1:0]           wr[P_LANES][P_SEGMENTS];   
} map_struct;

typedef struct {
    logic [5:0]                     sel;
    logic [(P_PPC * P_BPC)-1:0]     dat[3];
} fn_vmap_in_struct;

typedef struct {
    logic [1:0]                     dat[P_LANES][P_SEGMENTS][P_STRIPES];
    logic [P_STRIPES-1:0]           wr[P_LANES][P_SEGMENTS];   
} fn_vmap_out_struct;

// Signals
ctl_struct                  clk_ctl;
vid_struct                  clk_vid;
map_struct                  clk_map;

fn_vmap_in_struct           fn_vmap_in;
fn_vmap_out_struct          fn_vmap_out;

genvar i, j;

// Functions

// VMAP 2PPC 8BPC
// This function assembles the data in 2 pixel-per-clock 8-bits video mode
function fn_vmap_out_struct vmap_2ppc_8bpc (fn_vmap_in_struct vmap_in);

    fn_vmap_out_struct vmap_out;
   
    // Default
    for (int i = 0; i < P_LANES; i++)
    begin
        for (int j = 0; j < P_SEGMENTS; j++)
        begin
            for (int k = 0; k < P_STRIPES; k++)
            begin
                vmap_out.dat[i][j][k] = 0;
                vmap_out.wr[i][j][k] = 0;
            end
        end
    end

    case (vmap_in.sel)
        
        'd0 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                {vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3]} = vmap_in.dat[0][(((i+1)*P_BPC)-1)-:8]; // R0
                {vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3]} = vmap_in.dat[1][(((i+1)*P_BPC)-1)-:8]; // G0 
                {vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3]} = vmap_in.dat[2][(((i+1)*P_BPC)-1)-:8]; // B0 

                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;

                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;

                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
            end
        end

        'd1 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                {vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3]} = vmap_in.dat[0][(((i-1)*P_BPC)-1)-:8]; // R0
                {vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3]} = vmap_in.dat[1][(((i-1)*P_BPC)-1)-:8]; // G0 
                {vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3]} = vmap_in.dat[2][(((i-1)*P_BPC)-1)-:8]; // B0 

                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;

                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;

                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
            end
        end

        'd2 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                {vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3]} = vmap_in.dat[0][(((i+1)*P_BPC)-1)-:8]; // R0
                {vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3]} = vmap_in.dat[1][(((i+1)*P_BPC)-1)-:8]; // G0 
                {vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3]} = vmap_in.dat[2][(((i+1)*P_BPC)-1)-:8]; // B0 

                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;

                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;

                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
            end
        end

        'd3 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                {vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3]} = vmap_in.dat[0][(((i-1)*P_BPC)-1)-:8]; // R0
                {vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3]} = vmap_in.dat[1][(((i-1)*P_BPC)-1)-:8]; // G0 
                {vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3]} = vmap_in.dat[2][(((i-1)*P_BPC)-1)-:8]; // B0 

                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;

                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;

                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
            end
        end

        'd4 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                {vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3]} = vmap_in.dat[0][(((i+1)*P_BPC)-1)-:8]; // R0
                {vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3]} = vmap_in.dat[1][(((i+1)*P_BPC)-1)-:8]; // G0 
                {vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3]} = vmap_in.dat[2][(((i+1)*P_BPC)-1)-:8]; // B0 

                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;

                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;

                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
            end
        end

        'd5 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                {vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3]} = vmap_in.dat[0][(((i-1)*P_BPC)-1)-:8]; // R0
                {vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3]} = vmap_in.dat[1][(((i-1)*P_BPC)-1)-:8]; // G0 
                {vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3]} = vmap_in.dat[2][(((i-1)*P_BPC)-1)-:8]; // B0 

                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;

                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;

                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
            end
        end

        'd6 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                {vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3]} = vmap_in.dat[0][(((i+1)*P_BPC)-1)-:8]; // R0
                {vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3]} = vmap_in.dat[1][(((i+1)*P_BPC)-1)-:8]; // G0 
                {vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3]} = vmap_in.dat[2][(((i+1)*P_BPC)-1)-:8]; // B0 

                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;

                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;

                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
            end
        end

        'd7 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                {vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3]} = vmap_in.dat[0][(((i-1)*P_BPC)-1)-:8]; // R0
                {vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3]} = vmap_in.dat[1][(((i-1)*P_BPC)-1)-:8]; // G0 
                {vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3]} = vmap_in.dat[2][(((i-1)*P_BPC)-1)-:8]; // B0 

                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;

                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;

                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
            end
        end

        default : ;
    endcase

    return vmap_out;
endfunction 

// VMAP 2PPC 10BPC
// This function assembles the data in 2 pixel-per-clock 10-bits video mode
function fn_vmap_out_struct vmap_2ppc_10bpc (fn_vmap_in_struct vmap_in);

    fn_vmap_out_struct vmap_out;
   
    // Default
    for (int i = 0; i < P_LANES; i++)
    begin
        for (int j = 0; j < P_SEGMENTS; j++)
        begin
            for (int k = 0; k < P_STRIPES; k++)
            begin
                vmap_out.dat[i][j][k] = 0;
                vmap_out.wr[i][j][k] = 0;
            end
        end
    end

    case (vmap_in.sel)
        
        'd0 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                {vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;

                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;

                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
            end
        end

        'd1 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                {vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0]} = vmap_in.dat[0][((i-2)*P_BPC)+:10]; // R0
                {vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1]} = vmap_in.dat[1][((i-2)*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2]} = vmap_in.dat[2][((i-2)*P_BPC)+:10]; // B0 

                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;

                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;

                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
            end
        end

        'd2 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                {vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;

                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;

                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
            end
        end

        'd3 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                {vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3]} = vmap_in.dat[0][((i-2)*P_BPC)+:10]; // R0
                {vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0]} = vmap_in.dat[1][((i-2)*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1]} = vmap_in.dat[2][((i-2)*P_BPC)+:10]; // B0 

                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;

                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;

                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
            end
        end

        'd4 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                {vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;

                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;

                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
            end
        end

        'd5 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                {vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2]} = vmap_in.dat[0][((i-2)*P_BPC)+:10]; // R0
                {vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3]} = vmap_in.dat[1][((i-2)*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0]} = vmap_in.dat[2][((i-2)*P_BPC)+:10]; // B0 

                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;

                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;

                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
            end
        end

        'd6 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                {vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;

                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;

                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
            end
        end

        'd7 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                {vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1]} = vmap_in.dat[0][((i-2)*P_BPC)+:10]; // R0
                {vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2]} = vmap_in.dat[1][((i-2)*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3]} = vmap_in.dat[2][((i-2)*P_BPC)+:10]; // B0 

                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;

                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;

                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
            end
        end

        'd8 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                {vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;

                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;

                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
            end
        end

        'd9 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                {vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0]} = vmap_in.dat[0][((i-2)*P_BPC)+:10]; // R0
                {vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1]} = vmap_in.dat[1][((i-2)*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2]} = vmap_in.dat[2][((i-2)*P_BPC)+:10]; // B0 

                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;

                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;

                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
            end
        end

        'd10 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                {vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;

                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;

                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
            end
        end

        'd11 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                {vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3]} = vmap_in.dat[0][((i-2)*P_BPC)+:10]; // R0
                {vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0]} = vmap_in.dat[1][((i-2)*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1]} = vmap_in.dat[2][((i-2)*P_BPC)+:10]; // B0 

                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;

                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;

                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
            end
        end

        'd12 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                {vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;

                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;

                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
            end
        end

        'd13 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                {vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2]} = vmap_in.dat[0][((i-2)*P_BPC)+:10]; // R0
                {vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3]} = vmap_in.dat[1][((i-2)*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0]} = vmap_in.dat[2][((i-2)*P_BPC)+:10]; // B0 

                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;

                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;

                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
            end
        end

        'd14 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                {vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;

                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;

                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
            end
        end

        'd15 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                {vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1]} = vmap_in.dat[0][((i-2)*P_BPC)+:10]; // R0
                {vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2]} = vmap_in.dat[1][((i-2)*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3]} = vmap_in.dat[2][((i-2)*P_BPC)+:10]; // B0 

                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;

                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;

                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
            end
        end

        'd16 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                {vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;

                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;

                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
            end
        end

        'd17 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                {vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0]} = vmap_in.dat[0][((i-2)*P_BPC)+:10]; // R0
                {vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1]} = vmap_in.dat[1][((i-2)*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2]} = vmap_in.dat[2][((i-2)*P_BPC)+:10]; // B0 

                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;

                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;

                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
            end
        end

        'd18 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                {vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;

                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;

                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
            end
        end

        'd19 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                {vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3]} = vmap_in.dat[0][((i-2)*P_BPC)+:10]; // R0
                {vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0]} = vmap_in.dat[1][((i-2)*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1]} = vmap_in.dat[2][((i-2)*P_BPC)+:10]; // B0 

                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;

                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;

                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
            end
        end

        'd20 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                {vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;

                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;

                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
            end
        end

        'd21 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                {vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2]} = vmap_in.dat[0][((i-2)*P_BPC)+:10]; // R0
                {vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3]} = vmap_in.dat[1][((i-2)*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0]} = vmap_in.dat[2][((i-2)*P_BPC)+:10]; // B0 

                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;

                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;

                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
            end
        end

        'd22 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                {vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;

                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;

                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
            end
        end

        'd23 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                {vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1]} = vmap_in.dat[0][((i-2)*P_BPC)+:10]; // R0
                {vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2]} = vmap_in.dat[1][((i-2)*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3]} = vmap_in.dat[2][((i-2)*P_BPC)+:10]; // B0 

                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;

                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;

                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
            end
        end

        'd24 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                {vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;

                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;

                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
            end
        end

        'd25 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                {vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0]} = vmap_in.dat[0][((i-2)*P_BPC)+:10]; // R0
                {vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1]} = vmap_in.dat[1][((i-2)*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2]} = vmap_in.dat[2][((i-2)*P_BPC)+:10]; // B0 

                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;

                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;

                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
            end
        end

        'd26 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                {vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;

                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;

                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
            end
        end

        'd27 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                {vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3]} = vmap_in.dat[0][((i-2)*P_BPC)+:10]; // R0
                {vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0]} = vmap_in.dat[1][((i-2)*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1]} = vmap_in.dat[2][((i-2)*P_BPC)+:10]; // B0 

                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;

                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;

                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
            end
        end

        'd28 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                {vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;

                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;

                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
            end
        end

        'd29 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                {vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2]} = vmap_in.dat[0][((i-2)*P_BPC)+:10]; // R0
                {vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3]} = vmap_in.dat[1][((i-2)*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0]} = vmap_in.dat[2][((i-2)*P_BPC)+:10]; // B0 

                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;

                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;

                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
            end
        end

        'd30 : 
        begin
            for (int i = 0; i < 2; i++)
            begin
                {vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;

                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;

                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
            end
        end

        'd31 : 
        begin
            for (int i = 2; i < 4; i++)
            begin
                {vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1]} = vmap_in.dat[0][((i-2)*P_BPC)+:10]; // R0
                {vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2]} = vmap_in.dat[1][((i-2)*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3]} = vmap_in.dat[2][((i-2)*P_BPC)+:10]; // B0 

                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;

                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;

                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
            end
        end

        default : ;

    endcase

    return vmap_out;
endfunction 

// VMAP 4PPC 8BPC
// This function assembles the data in 4 pixel-per-clock 8-bits video mode
function fn_vmap_out_struct vmap_4ppc_8bpc (fn_vmap_in_struct vmap_in);

    fn_vmap_out_struct vmap_out;
   
    // Default
    for (int i = 0; i < P_LANES; i++)
    begin
        for (int j = 0; j < P_SEGMENTS; j++)
        begin
            for (int k = 0; k < P_STRIPES; k++)
            begin
                vmap_out.dat[i][j][k] = 0;
                vmap_out.wr[i][j][k] = 0;
            end
        end
    end

    case (vmap_in.sel)
        
        'd0 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                {vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3]} = vmap_in.dat[0][(((i+1)*P_BPC)-1)-:8]; // R0
                {vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3]} = vmap_in.dat[1][(((i+1)*P_BPC)-1)-:8]; // G0 
                {vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3]} = vmap_in.dat[2][(((i+1)*P_BPC)-1)-:8]; // B0 

                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;

                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;

                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
            end
        end

        'd1 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                {vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3]} = vmap_in.dat[0][(((i+1)*P_BPC)-1)-:8]; // R0
                {vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3]} = vmap_in.dat[1][(((i+1)*P_BPC)-1)-:8]; // G0 
                {vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3]} = vmap_in.dat[2][(((i+1)*P_BPC)-1)-:8]; // B0 

                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;

                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;

                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
            end
        end

        'd2 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                {vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3]} = vmap_in.dat[0][(((i+1)*P_BPC)-1)-:8]; // R0
                {vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3]} = vmap_in.dat[1][(((i+1)*P_BPC)-1)-:8]; // G0 
                {vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3]} = vmap_in.dat[2][(((i+1)*P_BPC)-1)-:8]; // B0 

                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;

                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;

                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
            end
        end

        'd3 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                {vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3]} = vmap_in.dat[0][(((i+1)*P_BPC)-1)-:8]; // R0
                {vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3]} = vmap_in.dat[1][(((i+1)*P_BPC)-1)-:8]; // G0 
                {vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3]} = vmap_in.dat[2][(((i+1)*P_BPC)-1)-:8]; // B0 

                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;

                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;

                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
            end
        end

        default : ;
    endcase

    return vmap_out;
endfunction 

// VMAP 2PPC 10BPC
// This function assembles the data in 4 pixel-per-clock 10-bits video mode
function fn_vmap_out_struct vmap_4ppc_10bpc (fn_vmap_in_struct vmap_in);

    fn_vmap_out_struct vmap_out;
   
    // Default
    for (int i = 0; i < P_LANES; i++)
    begin
        for (int j = 0; j < P_SEGMENTS; j++)
        begin
            for (int k = 0; k < P_STRIPES; k++)
            begin
                vmap_out.dat[i][j][k] = 0;
                vmap_out.wr[i][j][k] = 0;
            end
        end
    end

    case (vmap_in.sel)
        
        'd0 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                {vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;

                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;

                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
            end
        end

        'd1 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                {vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;

                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;

                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
            end
        end

        'd2 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                {vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;

                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;

                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
            end
        end

        'd3 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                {vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;

                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;

                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
            end
        end

        'd4 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                {vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;

                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;

                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
            end
        end

        'd5 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                {vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;

                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;

                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
            end
        end

        'd6 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                {vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;

                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;

                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
            end
        end

        'd7 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                {vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;

                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;

                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
            end
        end

        'd8 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                {vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;

                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;

                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
            end
        end

        'd9 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                {vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;

                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;

                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
            end
        end

        'd10 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                {vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;

                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;

                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
            end
        end

        'd11 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                {vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;

                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;

                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
            end
        end

        'd12 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                {vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1], vmap_out.dat[i][0][2]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;

                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;

                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
            end
        end

        'd13 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                {vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2], vmap_out.dat[i][1][3]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3], vmap_out.dat[i][3][0]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0], vmap_out.dat[i][0][1]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;

                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;

                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
                vmap_out.wr[i][0][1] = 1;
            end
        end

        'd14 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                {vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1], vmap_out.dat[i][1][2]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2], vmap_out.dat[i][2][3]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3], vmap_out.dat[i][0][0]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;
                vmap_out.wr[i][1][2] = 1;

                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;
                vmap_out.wr[i][2][3] = 1;

                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
                vmap_out.wr[i][0][0] = 1;
            end
        end

        'd15 : 
        begin
            for (int i = 0; i < 4; i++)
            begin
                {vmap_out.dat[i][0][1], vmap_out.dat[i][0][2], vmap_out.dat[i][0][3], vmap_out.dat[i][1][0], vmap_out.dat[i][1][1]} = vmap_in.dat[0][(i*P_BPC)+:10]; // R0
                {vmap_out.dat[i][1][2], vmap_out.dat[i][1][3], vmap_out.dat[i][2][0], vmap_out.dat[i][2][1], vmap_out.dat[i][2][2]} = vmap_in.dat[1][(i*P_BPC)+:10]; // G0 
                {vmap_out.dat[i][2][3], vmap_out.dat[i][3][0], vmap_out.dat[i][3][1], vmap_out.dat[i][3][2], vmap_out.dat[i][3][3]} = vmap_in.dat[2][(i*P_BPC)+:10]; // B0 

                vmap_out.wr[i][0][1] = 1;
                vmap_out.wr[i][0][2] = 1;
                vmap_out.wr[i][0][3] = 1;
                vmap_out.wr[i][1][0] = 1;
                vmap_out.wr[i][1][1] = 1;

                vmap_out.wr[i][1][2] = 1;
                vmap_out.wr[i][1][3] = 1;
                vmap_out.wr[i][2][0] = 1;
                vmap_out.wr[i][2][1] = 1;
                vmap_out.wr[i][2][2] = 1;

                vmap_out.wr[i][2][3] = 1;
                vmap_out.wr[i][3][0] = 1;
                vmap_out.wr[i][3][1] = 1;
                vmap_out.wr[i][3][2] = 1;
                vmap_out.wr[i][3][3] = 1;
            end
        end

        default : ;

    endcase

    return vmap_out;
endfunction 

// Logic

// Map control
    assign clk_ctl.bpc = CFG_BPC_IN;

// Video inputs
    assign clk_vid.clr = VID_CLR_IN;
    assign clk_vid.run = VID_RUN_IN;
    assign clk_vid.dat = VID_DAT_IN;
    assign clk_vid.de = VID_DE_IN;

// Select end
    always_comb
    begin
        // 10-bits video
        if (clk_ctl.bpc)
            clk_map.sel_end = P_SEL_END_10BPC;
        
        // 8-bits video
        else
            clk_map.sel_end = P_SEL_END_8BPC; 
    end

// Select
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_vid.run)
        begin
            // Clear 
            if (clk_vid.clr)
                clk_map.sel <= 0;

            // Increment
            else if (clk_vid.de)
            begin
                // Clear
                if (clk_map.sel == clk_map.sel_end)
                    clk_map.sel <= 0;
                else
                    clk_map.sel <= clk_map.sel + 'd1;
            end
        end

        else
            clk_map.sel <= 0;
    end

// VMAP 
generate
    if (P_BPC == 10)
    begin : gen_vmap_10bpc      
        // Assign function inputs
        assign fn_vmap_in.sel = clk_map.sel;
        assign fn_vmap_in.dat = clk_vid.dat;

        // 4 pixels per clock
        if (P_PPC == 4)
        begin : gen_vmap_4ppc
            always_comb
            begin
                // 10-bits video
                if (clk_ctl.bpc)
                    fn_vmap_out = vmap_4ppc_10bpc (fn_vmap_in);
                
                // 8-bits video
                else
                    fn_vmap_out = vmap_4ppc_8bpc (fn_vmap_in);
            end
        end

        // 2 pixels per clock
        else
        begin : gen_vmap_2ppc
            always_comb
            begin
                // 10-bits video
                if (clk_ctl.bpc)
                    fn_vmap_out = vmap_2ppc_10bpc (fn_vmap_in);
                
                // 8-bits video
                else
                    fn_vmap_out = vmap_2ppc_8bpc (fn_vmap_in);
            end
        end

        // Assign function outputs
        assign clk_map.dat = fn_vmap_out.dat;
        assign clk_map.wr = fn_vmap_out.wr;
    end

    // 8-bits
    else
    begin : gen_vmap_8bpc
        // Assign function inputs
        assign fn_vmap_in.sel = clk_map.sel;
        assign fn_vmap_in.dat = clk_vid.dat;

        // 4 pixels per clock
        if (P_PPC == 4)
        begin : gen_vmap_4ppc
            assign fn_vmap_out = vmap_4ppc_8bpc (fn_vmap_in);
        end

        // 2 pixels per clock
        else
        begin : gen_vmap_2ppc
            assign fn_vmap_out = vmap_2ppc_8bpc (fn_vmap_in);
        end

        // Assign function outputs
        assign clk_map.dat = fn_vmap_out.dat;
        assign clk_map.wr = fn_vmap_out.wr;
   end
endgenerate

// Outputs
    assign MAP_DAT_OUT = clk_map.dat;
    assign MAP_WR_OUT = clk_map.wr;

endmodule

`default_nettype wire
