/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP TX Video - video mapper
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

module prt_dptx_vid_vmap
#(
    // Video
    parameter                           P_PPC = 2,          // Pixels per clock
    parameter                           P_BPC = 8,          // Bits per component

    // Mapper
    parameter                           P_LANES = 4,        // Lanes
    parameter                           P_FIFO_DAT = 9,     // FIFO data
    parameter                           P_FIFO_STRIPES = 4  // FIFO stripes
)
(
    input wire                          RST_IN,             // Reset
    input wire                          CLK_IN,             // Clock
    input wire                          CKE_IN,             // Clock enable

    // Control
    input wire                          CFG_RUN_IN,         // Run
    input wire                          CFG_BPC_IN,         // Active bits-per-component
    input wire                          CFG_MST_IN,         // MST

    // Video
    input wire                          VID_BS_IN,          // Blanking start
    input wire                          VID_BE_IN,          // Blanking end
    input wire                          VID_HS_IN,          // Horizontal sync
    input wire [(P_PPC*P_BPC)-1:0]      VID_DAT_IN[3],      // Video data
    input wire                          VID_DE_IN,          // Video data enable

    // Mapper
    output wire [P_FIFO_DAT-1:0]        MAP_DAT_OUT[P_LANES][P_FIFO_STRIPES],
    output wire [P_FIFO_STRIPES-1:0]    MAP_WR_OUT[P_LANES]
);

// Parameters 
localparam P_MAP_DAT = P_FIFO_DAT-1;    // A FIFO stripe has 1 bit control (msb) and 8 bits data
localparam P_MAP_CTL = 1;

// Structures
typedef struct {
    logic                           run;
    logic                           bpc;
    logic                           mst;
} ctl_struct;

typedef struct {
    logic                           bs;
    logic                           be;
    logic                           hs;
    logic [(P_PPC * P_BPC)-1:0]     dat[3];
    logic                           de;
} vid_struct;

typedef struct {
    logic [4:0]                     sel;
    logic [4:0]                     sel_end;
    logic [P_FIFO_DAT-1:0]          dat[P_LANES][P_FIFO_STRIPES];
    logic [P_FIFO_STRIPES-1:0]      wr[P_LANES];
    logic [P_MAP_DAT-1:0]           tmp[P_LANES];
} map_struct;

typedef struct {
    logic                           ctl_mst;
    logic [4:0]                     map_sel;
    logic [P_MAP_DAT-1:0]           map_tmp[P_LANES];
    logic                           vid_bs;
    logic                           vid_be;
    logic [(P_PPC * P_BPC)-1:0]     vid_dat[3];
} fn_vmap_in_struct;

typedef struct {
    logic [P_FIFO_DAT-1:0]          map_dat[P_LANES][P_FIFO_STRIPES];
    logic [P_FIFO_STRIPES-1:0]      map_wr[P_LANES];
    logic [P_MAP_DAT-1:0]           map_tmp[P_LANES];
} fn_vmap_out_struct;

// Signals
ctl_struct          clk_ctl;
vid_struct          clk_vid;
map_struct          clk_map;

fn_vmap_in_struct   fn_vmap_in;
fn_vmap_out_struct  fn_vmap_out;

genvar i;

// Functions

// VMAP 2PPC 8BPC
// This function maps 2 pixel-per-clock 8-bits video into the fifo stripes
function fn_vmap_out_struct vmap_2ppc_8bpc (fn_vmap_in_struct vmap_in);

    fn_vmap_out_struct vmap_out;

    // Default
    for (int i = 0; i < P_LANES; i++)
    begin
        for (int j = 0; j < P_FIFO_STRIPES; j++)
        begin
            vmap_out.map_wr[i][j] = 0;
            vmap_out.map_dat[i][j] = 0;
        end

        vmap_out.map_tmp[i] = vmap_in.map_tmp[i];
    end

    case (vmap_in.map_sel)
        
        'd0 : 
        begin
            // Blanking end
            if (vmap_in.ctl_mst && vmap_in.vid_be)
            begin                      
                // MST
                // The BE symbol is inserted in the third fifo stripe, just before the active video.
                // This symbol must be placed in the upper stripe. 
                vmap_out.map_dat[0][2] = {1'b1, {P_MAP_DAT{1'b0}}};

                vmap_out.map_wr[0][2] = 1;
                vmap_out.map_wr[0][3] = 1;
                vmap_out.map_wr[1][2] = 1;                
                vmap_out.map_wr[1][3] = 1;                

                vmap_out.map_wr[2][2] = 1;
                vmap_out.map_wr[2][3] = 1;
                vmap_out.map_wr[3][2] = 1;                
                vmap_out.map_wr[3][3] = 1;                
            end

            else
            begin
                vmap_out.map_dat[0][0] = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)-1)-:P_MAP_DAT]};   // R0
                
                // MST
                // The BS symbol is inserted in the second fifo stripe, just after the active video.                  
                vmap_out.map_dat[0][1] = (vmap_in.vid_bs) ? {1'b1, {P_MAP_DAT{1'b0}}} : {1'b0, vmap_in.vid_dat[1][((1*P_BPC)-1)-:P_MAP_DAT]};   // G0
                vmap_out.map_dat[0][2] = {1'b0, vmap_in.vid_dat[2][((1*P_BPC)-1)-:P_MAP_DAT]};   // B0
                vmap_out.map_dat[1][0] = {1'b0, vmap_in.vid_dat[0][((2*P_BPC)-1)-:P_MAP_DAT]};   // R1
                vmap_out.map_dat[1][1] = {1'b0, vmap_in.vid_dat[1][((2*P_BPC)-1)-:P_MAP_DAT]};   // G1
                vmap_out.map_dat[1][2] = {1'b0, vmap_in.vid_dat[2][((2*P_BPC)-1)-:P_MAP_DAT]};   // B1
                
                vmap_out.map_wr[0][0] = 1;
                vmap_out.map_wr[0][1] = 1;
                vmap_out.map_wr[0][2] = 1;
                vmap_out.map_wr[1][0] = 1;
                vmap_out.map_wr[1][1] = 1;                
                vmap_out.map_wr[1][2] = 1;                
            end
        end

        'd1 : 
        begin
            vmap_out.map_dat[2][0] = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)-1)-:P_MAP_DAT]};   // R2
            vmap_out.map_dat[2][1] = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)-1)-:P_MAP_DAT]};   // G2
            vmap_out.map_dat[2][2] = {1'b0, vmap_in.vid_dat[2][((1*P_BPC)-1)-:P_MAP_DAT]};   // B2
            vmap_out.map_dat[3][0] = {1'b0, vmap_in.vid_dat[0][((2*P_BPC)-1)-:P_MAP_DAT]};   // R3
            vmap_out.map_dat[3][1] = {1'b0, vmap_in.vid_dat[1][((2*P_BPC)-1)-:P_MAP_DAT]};   // G3
            vmap_out.map_dat[3][2] = {1'b0, vmap_in.vid_dat[2][((2*P_BPC)-1)-:P_MAP_DAT]};   // B3
            
            vmap_out.map_wr[2][0] = 1;
            vmap_out.map_wr[2][1] = 1;
            vmap_out.map_wr[2][2] = 1;
            vmap_out.map_wr[3][0] = 1;
            vmap_out.map_wr[3][1] = 1;                
            vmap_out.map_wr[3][2] = 1;                
        end

        'd2 : 
        begin
            vmap_out.map_dat[0][3] = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)-1)-:P_MAP_DAT]};   // R4
            vmap_out.map_dat[0][0] = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)-1)-:P_MAP_DAT]};   // G4
            vmap_out.map_dat[0][1] = {1'b0, vmap_in.vid_dat[2][((1*P_BPC)-1)-:P_MAP_DAT]};   // B4
            vmap_out.map_dat[1][3] = {1'b0, vmap_in.vid_dat[0][((2*P_BPC)-1)-:P_MAP_DAT]};   // R5
            vmap_out.map_dat[1][0] = {1'b0, vmap_in.vid_dat[1][((2*P_BPC)-1)-:P_MAP_DAT]};   // G5
            vmap_out.map_dat[1][1] = {1'b0, vmap_in.vid_dat[2][((2*P_BPC)-1)-:P_MAP_DAT]};   // B5
            
            vmap_out.map_wr[0][3] = 1;
            vmap_out.map_wr[0][0] = 1;
            vmap_out.map_wr[0][1] = 1;
            vmap_out.map_wr[1][3] = 1;
            vmap_out.map_wr[1][0] = 1;                
            vmap_out.map_wr[1][1] = 1;                
        end

        'd3 : 
        begin
            vmap_out.map_dat[2][3] = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)-1)-:P_MAP_DAT]};   // R6
            vmap_out.map_dat[2][0] = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)-1)-:P_MAP_DAT]};   // G6
            vmap_out.map_dat[2][1] = {1'b0, vmap_in.vid_dat[2][((1*P_BPC)-1)-:P_MAP_DAT]};   // B6
            vmap_out.map_dat[3][3] = {1'b0, vmap_in.vid_dat[0][((2*P_BPC)-1)-:P_MAP_DAT]};   // R7
            vmap_out.map_dat[3][0] = {1'b0, vmap_in.vid_dat[1][((2*P_BPC)-1)-:P_MAP_DAT]};   // G7
            vmap_out.map_dat[3][1] = {1'b0, vmap_in.vid_dat[2][((2*P_BPC)-1)-:P_MAP_DAT]};   // B7
            
            vmap_out.map_wr[2][3] = 1;
            vmap_out.map_wr[2][0] = 1;
            vmap_out.map_wr[2][1] = 1;
            vmap_out.map_wr[3][3] = 1;
            vmap_out.map_wr[3][0] = 1;                
            vmap_out.map_wr[3][1] = 1;                
        end

        'd4 : 
        begin
            vmap_out.map_dat[0][2] = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)-1)-:P_MAP_DAT]};   // R8
            vmap_out.map_dat[0][3] = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)-1)-:P_MAP_DAT]};   // G8
            vmap_out.map_dat[0][0] = {1'b0, vmap_in.vid_dat[2][((1*P_BPC)-1)-:P_MAP_DAT]};   // B8
            vmap_out.map_dat[1][2] = {1'b0, vmap_in.vid_dat[0][((2*P_BPC)-1)-:P_MAP_DAT]};   // R9
            vmap_out.map_dat[1][3] = {1'b0, vmap_in.vid_dat[1][((2*P_BPC)-1)-:P_MAP_DAT]};   // G9
            vmap_out.map_dat[1][0] = {1'b0, vmap_in.vid_dat[2][((2*P_BPC)-1)-:P_MAP_DAT]};   // B9
            
            vmap_out.map_wr[0][2] = 1;
            vmap_out.map_wr[0][3] = 1;
            vmap_out.map_wr[0][0] = 1;
            vmap_out.map_wr[1][2] = 1;
            vmap_out.map_wr[1][3] = 1;                
            vmap_out.map_wr[1][0] = 1;                
        end

        'd5 : 
        begin
            vmap_out.map_dat[2][2] = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)-1)-:P_MAP_DAT]};   // R10
            vmap_out.map_dat[2][3] = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)-1)-:P_MAP_DAT]};   // G10
            vmap_out.map_dat[2][0] = {1'b0, vmap_in.vid_dat[2][((1*P_BPC)-1)-:P_MAP_DAT]};   // B10
            vmap_out.map_dat[3][2] = {1'b0, vmap_in.vid_dat[0][((2*P_BPC)-1)-:P_MAP_DAT]};   // R11
            vmap_out.map_dat[3][3] = {1'b0, vmap_in.vid_dat[1][((2*P_BPC)-1)-:P_MAP_DAT]};   // G11
            vmap_out.map_dat[3][0] = {1'b0, vmap_in.vid_dat[2][((2*P_BPC)-1)-:P_MAP_DAT]};   // B11
            
            vmap_out.map_wr[2][2] = 1;
            vmap_out.map_wr[2][3] = 1;
            vmap_out.map_wr[2][0] = 1;
            vmap_out.map_wr[3][2] = 1;
            vmap_out.map_wr[3][3] = 1;                
            vmap_out.map_wr[3][0] = 1;                
        end

        'd6 : 
        begin
            vmap_out.map_dat[0][1] = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)-1)-:P_MAP_DAT]};   // R12
            vmap_out.map_dat[0][2] = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)-1)-:P_MAP_DAT]};   // G12
            vmap_out.map_dat[0][3] = {1'b0, vmap_in.vid_dat[2][((1*P_BPC)-1)-:P_MAP_DAT]};   // B12
            vmap_out.map_dat[1][1] = {1'b0, vmap_in.vid_dat[0][((2*P_BPC)-1)-:P_MAP_DAT]};   // R13
            vmap_out.map_dat[1][2] = {1'b0, vmap_in.vid_dat[1][((2*P_BPC)-1)-:P_MAP_DAT]};   // G13
            vmap_out.map_dat[1][3] = {1'b0, vmap_in.vid_dat[2][((2*P_BPC)-1)-:P_MAP_DAT]};   // B13
            
            vmap_out.map_wr[0][1] = 1;
            vmap_out.map_wr[0][2] = 1;
            vmap_out.map_wr[0][3] = 1;
            vmap_out.map_wr[1][1] = 1;
            vmap_out.map_wr[1][2] = 1;                
            vmap_out.map_wr[1][3] = 1;                
        end

        'd7 : 
        begin
            vmap_out.map_dat[2][1] = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)-1)-:P_MAP_DAT]};   // R14
            vmap_out.map_dat[2][2] = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)-1)-:P_MAP_DAT]};   // G14
            vmap_out.map_dat[2][3] = {1'b0, vmap_in.vid_dat[2][((1*P_BPC)-1)-:P_MAP_DAT]};   // B14
            vmap_out.map_dat[3][1] = {1'b0, vmap_in.vid_dat[0][((2*P_BPC)-1)-:P_MAP_DAT]};   // R15
            vmap_out.map_dat[3][2] = {1'b0, vmap_in.vid_dat[1][((2*P_BPC)-1)-:P_MAP_DAT]};   // G15

            // SST
            // The BS symbol is aligned with the last data.
            vmap_out.map_dat[3][3] = {vmap_in.vid_bs, vmap_in.vid_dat[2][((2*P_BPC)-1)-:P_MAP_DAT]};   // B15
            
            vmap_out.map_wr[2][1] = 1;
            vmap_out.map_wr[2][2] = 1;
            vmap_out.map_wr[2][3] = 1;
            vmap_out.map_wr[3][1] = 1;
            vmap_out.map_wr[3][2] = 1;                
            vmap_out.map_wr[3][3] = 1;                
        end

        default : ;
    endcase

    return vmap_out;

endfunction 

// VMAP 2PPC 10BPC
// This function maps 2 pixel-per-clock 10-bits video into the fifo stripes
function fn_vmap_out_struct vmap_2ppc_10bpc (fn_vmap_in_struct vmap_in);

    fn_vmap_out_struct vmap_out;

    // Default
    for (int i = 0; i < P_LANES; i++)
    begin
        for (int j = 0; j < P_FIFO_STRIPES; j++)
        begin
            vmap_out.map_wr[i][j] = 0;
            vmap_out.map_dat[i][j] = 0;
        end

        vmap_out.map_tmp[i] = vmap_in.map_tmp[i];
    end

    case (vmap_in.map_sel)

        // The 10-bits mapping is divided into 4 sequences.
        // Per sequence 15 bytes are written in the FIFO. 
        // However the FIFO requires cycles of 4 words. 
        // After 4 sequences in total 60 words are stored in the FIFO.
        // See Table 2-14 on page 89 of DisplayPort 1.4 specification

        // Sequence 0
        'd0 : 
        begin
            vmap_out.map_dat[0][0]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+2)+:8]};                                         // R0-9:2               
            vmap_out.map_dat[0][1]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:2], vmap_in.vid_dat[1][((0*P_BPC)+4)+:6]};   // R0-1:0 | G0-9:4
            vmap_out.map_dat[0][2]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:4], vmap_in.vid_dat[2][((0*P_BPC)+6)+:4]};   // G0-3:0 | B0-9:6
            vmap_out.map_tmp[0]     = {2'h0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:6]};                                         // B0-5:0

            vmap_out.map_dat[1][0]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+2)+:8]};                                         // R1-9:2               
            vmap_out.map_dat[1][1]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:2], vmap_in.vid_dat[1][((1*P_BPC)+4)+:6]};   // R1-1:0 | G1-9:4
            vmap_out.map_dat[1][2]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:4], vmap_in.vid_dat[2][((1*P_BPC)+6)+:4]};   // G1-3:0 | B1-9:6
            vmap_out.map_tmp[1]     = {2'h0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:6]};                                         // B1-5:0

            vmap_out.map_wr[0][0] = 1;
            vmap_out.map_wr[0][1] = 1;
            vmap_out.map_wr[0][2] = 1;
            vmap_out.map_wr[1][0] = 1;
            vmap_out.map_wr[1][1] = 1;                
            vmap_out.map_wr[1][2] = 1;                
        end

        'd1 : 
        begin
            vmap_out.map_dat[2][0]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+2)+:8]};                                         // R2-9:2
            vmap_out.map_dat[2][1]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:2], vmap_in.vid_dat[1][((0*P_BPC)+4)+:6]};   // R2-1:0 | G2-9:4
            vmap_out.map_dat[2][2]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:4], vmap_in.vid_dat[2][((0*P_BPC)+6)+:4]};   // G2-3:0 | B2-9:6
            vmap_out.map_tmp[2]     = {2'h0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:6]};                                         // B2-5:0

            vmap_out.map_dat[3][0]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+2)+:8]};                                         // R3-9:2
            vmap_out.map_dat[3][1]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:2], vmap_in.vid_dat[1][((1*P_BPC)+4)+:6]};   // R3-1:0 | G3-9:4
            vmap_out.map_dat[3][2]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:4], vmap_in.vid_dat[2][((1*P_BPC)+6)+:4]};   // G3-3:0 | B3-9:6
            vmap_out.map_tmp[3]     = {2'h0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:6]};                                         // B3-5:0

            vmap_out.map_wr[2][0] = 1;
            vmap_out.map_wr[2][1] = 1;
            vmap_out.map_wr[2][2] = 1;
            vmap_out.map_wr[3][0] = 1;
            vmap_out.map_wr[3][1] = 1;                
            vmap_out.map_wr[3][2] = 1;                
        end

        'd2 : 
        begin
            vmap_out.map_dat[0][3]  = {1'b0, vmap_in.map_tmp[0][0+:6], vmap_in.vid_dat[0][((0*P_BPC)+8)+:2]};               // TMP0-5:0 | R4-9:8
            vmap_out.map_dat[0][0]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:8]};                                         // R4-7:0
            vmap_out.map_dat[0][1]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+2)+:8]};                                         // G4-9:2
            vmap_out.map_dat[0][2]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:2], vmap_in.vid_dat[2][((0*P_BPC)+4)+:6]};   // G4-1:0 | B4-9:4
            vmap_out.map_tmp[0]     = {4'h0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:4]};                                         // B4-3:0

            vmap_out.map_dat[1][3]  = {1'b0, vmap_in.map_tmp[1][0+:6], vmap_in.vid_dat[0][((1*P_BPC)+8)+:2]};               // TMP1-5:0 | R5-9:8
            vmap_out.map_dat[1][0]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:8]};                                         // R5-7:0
            vmap_out.map_dat[1][1]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+2)+:8]};                                         // G5-9:2
            vmap_out.map_dat[1][2]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:2], vmap_in.vid_dat[2][((1*P_BPC)+4)+:6]};   // G5-1:0 | B5-9:4
            vmap_out.map_tmp[1]     = {4'h0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:4]};                                         // B5-3:0

            vmap_out.map_wr[0][3] = 1;
            vmap_out.map_wr[0][0] = 1;
            vmap_out.map_wr[0][1] = 1;
            vmap_out.map_wr[0][2] = 1;
            vmap_out.map_wr[1][3] = 1;
            vmap_out.map_wr[1][0] = 1;                
            vmap_out.map_wr[1][1] = 1;                
            vmap_out.map_wr[1][2] = 1;
        end

        'd3 : 
        begin
            vmap_out.map_dat[2][3]  = {1'b0, vmap_in.map_tmp[2][0+:6], vmap_in.vid_dat[0][((0*P_BPC)+8)+:2]};               // TMP2-5:0 | R6-9:8
            vmap_out.map_dat[2][0]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:8]};                                         // R6-7:0
            vmap_out.map_dat[2][1]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+2)+:8]};                                         // G6-9:2
            vmap_out.map_dat[2][2]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:2], vmap_in.vid_dat[2][((0*P_BPC)+4)+:6]};   // G6-1:0 | B6-9:4
            vmap_out.map_tmp[2]     = {4'h0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:4]};                                         // B6-3:0

            vmap_out.map_dat[3][3]  = {1'b0, vmap_in.map_tmp[3][0+:6], vmap_in.vid_dat[0][((1*P_BPC)+8)+:2]};               // TMP3-5:0 | R7-9:8               
            vmap_out.map_dat[3][0]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:8]};                                         // R7-7:0
            vmap_out.map_dat[3][1]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+2)+:8]};                                         // G7-9:2 
            vmap_out.map_dat[3][2]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:2], vmap_in.vid_dat[2][((1*P_BPC)+4)+:6]};   // G7-1:0 | B7-9:4
            vmap_out.map_tmp[3]     = {4'h0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:4]};                                         // B7-3:0

            vmap_out.map_wr[2][3] = 1;
            vmap_out.map_wr[2][0] = 1;
            vmap_out.map_wr[2][1] = 1;
            vmap_out.map_wr[2][2] = 1;
            vmap_out.map_wr[3][3] = 1;
            vmap_out.map_wr[3][0] = 1;                
            vmap_out.map_wr[3][1] = 1;                
            vmap_out.map_wr[3][2] = 1;
        end

        'd4 : 
        begin
            vmap_out.map_dat[0][3]  = {1'b0, vmap_in.map_tmp[0][0+:4], vmap_in.vid_dat[0][((0*P_BPC)+6)+:4]};               // TMP0-3:0 | R8-9:6
            vmap_out.map_dat[0][0]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:6], vmap_in.vid_dat[1][((0*P_BPC)+8)+:2]};   // R8-5:0 | G8-9:8
            vmap_out.map_dat[0][1]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:8]};                                         // G8-7:0 
            vmap_out.map_dat[0][2]  = {1'b0, vmap_in.vid_dat[2][((0*P_BPC)+2)+:8]};                                         // B8-9:2
            vmap_out.map_tmp[0]     = {6'h0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:2]};                                         // B8-1:0

            vmap_out.map_dat[1][3]  = {1'b0, vmap_in.map_tmp[1][0+:4], vmap_in.vid_dat[0][((1*P_BPC)+6)+:4]};               // TMP1-3:0 | R9-9:6
            vmap_out.map_dat[1][0]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:6], vmap_in.vid_dat[1][((1*P_BPC)+8)+:2]};   // R9-5:0 | G9-9:8
            vmap_out.map_dat[1][1]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:8]};                                         // G9-7:0 
            vmap_out.map_dat[1][2]  = {1'b0, vmap_in.vid_dat[2][((1*P_BPC)+2)+:8]};                                         // B9-9:2
            vmap_out.map_tmp[1]     = {6'h0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:2]};                                         // B9-1:0

            vmap_out.map_wr[0][3] = 1;
            vmap_out.map_wr[0][0] = 1;
            vmap_out.map_wr[0][1] = 1;
            vmap_out.map_wr[0][2] = 1;
            vmap_out.map_wr[1][3] = 1;
            vmap_out.map_wr[1][0] = 1;                
            vmap_out.map_wr[1][1] = 1;                
            vmap_out.map_wr[1][2] = 1;
        end

        'd5 : 
        begin
            vmap_out.map_dat[2][3]  = {1'b0, vmap_in.map_tmp[2][0+:4], vmap_in.vid_dat[0][((0*P_BPC)+6)+:4]};               // TMP2-3:0 | R10-9:6
            vmap_out.map_dat[2][0]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:6], vmap_in.vid_dat[1][((0*P_BPC)+8)+:2]};   // R10-5:0 | G10-9:8
            vmap_out.map_dat[2][1]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:8]};                                         // G10-7:0 
            vmap_out.map_dat[2][2]  = {1'b0, vmap_in.vid_dat[2][((0*P_BPC)+2)+:8]};                                         // B10-9:2
            vmap_out.map_tmp[2]     = {6'h0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:2]};                                         // B10-1:0

            vmap_out.map_dat[3][3]  = {1'b0, vmap_in.map_tmp[3][0+:4], vmap_in.vid_dat[0][((1*P_BPC)+6)+:4]};               // TMP3-3:0 | R11-9:6
            vmap_out.map_dat[3][0]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:6], vmap_in.vid_dat[1][((1*P_BPC)+8)+:2]};   // R11-5:0 | G11-9:8
            vmap_out.map_dat[3][1]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:8]};                                         // G11-7:0 
            vmap_out.map_dat[3][2]  = {1'b0, vmap_in.vid_dat[2][((1*P_BPC)+2)+:8]};                                         // B11-9:2
            vmap_out.map_tmp[3]     = {6'h0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:2]};                                         // B11-1:0

            vmap_out.map_wr[2][3] = 1;
            vmap_out.map_wr[2][0] = 1;
            vmap_out.map_wr[2][1] = 1;
            vmap_out.map_wr[2][2] = 1;
            vmap_out.map_wr[3][3] = 1;
            vmap_out.map_wr[3][0] = 1;                
            vmap_out.map_wr[3][1] = 1;                
            vmap_out.map_wr[3][2] = 1;
        end

        'd6 : 
        begin
            vmap_out.map_dat[0][3]  = {1'b0, vmap_in.map_tmp[0][0+:2], vmap_in.vid_dat[0][((0*P_BPC)+4)+:6]};               // TMP0-1:0 | R12-9:4
            vmap_out.map_dat[0][0]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:4], vmap_in.vid_dat[1][((0*P_BPC)+6)+:4]};   // R12-3:0 | G12-9:6
            vmap_out.map_dat[0][1]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:6], vmap_in.vid_dat[2][((0*P_BPC)+8)+:2]};   // G12-5:0 | B12-9:8
            vmap_out.map_dat[0][2]  = {1'b0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:8]};                                         // B12-7:0

            vmap_out.map_dat[1][3]  = {1'b0, vmap_in.map_tmp[1][0+:2], vmap_in.vid_dat[0][((1*P_BPC)+4)+:6]};               // TMP1-1:0 | R13-9:4
            vmap_out.map_dat[1][0]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:4], vmap_in.vid_dat[1][((1*P_BPC)+6)+:4]};   // R13-3:0 | G13-9:6
            vmap_out.map_dat[1][1]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:6], vmap_in.vid_dat[2][((1*P_BPC)+8)+:2]};   // G13-5:0 | B13-9:8
            vmap_out.map_dat[1][2]  = {1'b0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:8]};                                         // B13-7:0

            vmap_out.map_wr[0][3] = 1;
            vmap_out.map_wr[0][0] = 1;
            vmap_out.map_wr[0][1] = 1;
            vmap_out.map_wr[0][2] = 1;
            vmap_out.map_wr[1][3] = 1;
            vmap_out.map_wr[1][0] = 1;                
            vmap_out.map_wr[1][1] = 1;                
            vmap_out.map_wr[1][2] = 1;
        end

        'd7 : 
        begin
            vmap_out.map_dat[2][3]  = {1'b0, vmap_in.map_tmp[2][0+:2], vmap_in.vid_dat[0][((0*P_BPC)+4)+:6]};               // TMP2-1:0 | R14-9:4
            vmap_out.map_dat[2][0]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:4], vmap_in.vid_dat[1][((0*P_BPC)+6)+:4]};   // R14-3:0 | G14-9:6
            vmap_out.map_dat[2][1]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:6], vmap_in.vid_dat[2][((0*P_BPC)+8)+:2]};   // G14-5:0 | B14-9:8
            vmap_out.map_dat[2][2]  = {1'b0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:8]};                                         // B14-7:0

            vmap_out.map_dat[3][3]  = {1'b0, vmap_in.map_tmp[3][0+:2], vmap_in.vid_dat[0][((1*P_BPC)+4)+:6]};               // TMP3-1:0 | R15-9:4
            vmap_out.map_dat[3][0]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:4], vmap_in.vid_dat[1][((1*P_BPC)+6)+:4]};   // R15-3:0 | G15-9:6
            vmap_out.map_dat[3][1]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:6], vmap_in.vid_dat[2][((1*P_BPC)+8)+:2]};   // G15-5:0 | B15-9:8

            // The BS symbol is aligned with the last data.
            vmap_out.map_dat[3][2]  = {vmap_in.vid_bs, vmap_in.vid_dat[2][((1*P_BPC)+0)+:8]};                               // B15-7:0

            vmap_out.map_wr[2][3] = 1;
            vmap_out.map_wr[2][0] = 1;
            vmap_out.map_wr[2][1] = 1;
            vmap_out.map_wr[2][2] = 1;
            vmap_out.map_wr[3][3] = 1;
            vmap_out.map_wr[3][0] = 1;                
            vmap_out.map_wr[3][1] = 1;                
            vmap_out.map_wr[3][2] = 1;          
        end

        // Sequence 2
        'd8 : 
        begin
            vmap_out.map_dat[0][3]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+2)+:8]};                                         // R0-9:2               
            vmap_out.map_dat[0][0]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:2], vmap_in.vid_dat[1][((0*P_BPC)+4)+:6]};   // R0-1:0 | G0-9:4
            vmap_out.map_dat[0][1]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:4], vmap_in.vid_dat[2][((0*P_BPC)+6)+:4]};   // G0-3:0 | B0-9:6
            vmap_out.map_tmp[0]     = {2'h0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:6]};                                         // B0-5:0

            vmap_out.map_dat[1][3]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+2)+:8]};                                         // R1-9:2               
            vmap_out.map_dat[1][0]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:2], vmap_in.vid_dat[1][((1*P_BPC)+4)+:6]};   // R1-1:0 | G1-9:4
            vmap_out.map_dat[1][1]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:4], vmap_in.vid_dat[2][((1*P_BPC)+6)+:4]};   // G1-3:0 | B1-9:6
            vmap_out.map_tmp[1]     = {2'h0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:6]};                                         // B1-5:0

            vmap_out.map_wr[0][3] = 1;
            vmap_out.map_wr[0][0] = 1;
            vmap_out.map_wr[0][1] = 1;
            vmap_out.map_wr[1][3] = 1;
            vmap_out.map_wr[1][0] = 1;                
            vmap_out.map_wr[1][1] = 1;                
        end

        'd9 : 
        begin
            vmap_out.map_dat[2][3]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+2)+:8]};                                         // R2-9:2
            vmap_out.map_dat[2][0]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:2], vmap_in.vid_dat[1][((0*P_BPC)+4)+:6]};   // R2-1:0 | G2-9:4
            vmap_out.map_dat[2][1]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:4], vmap_in.vid_dat[2][((0*P_BPC)+6)+:4]};   // G2-3:0 | B2-9:6
            vmap_out.map_tmp[2]     = {2'h0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:6]};                                         // B2-5:0

            vmap_out.map_dat[3][3]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+2)+:8]};                                         // R3-9:2
            vmap_out.map_dat[3][0]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:2], vmap_in.vid_dat[1][((1*P_BPC)+4)+:6]};   // R3-1:0 | G3-9:4
            vmap_out.map_dat[3][1]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:4], vmap_in.vid_dat[2][((1*P_BPC)+6)+:4]};   // G3-3:0 | B3-9:6
            vmap_out.map_tmp[3]     = {2'h0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:6]};                                         // B3-5:0

            vmap_out.map_wr[2][3] = 1;
            vmap_out.map_wr[2][0] = 1;
            vmap_out.map_wr[2][1] = 1;
            vmap_out.map_wr[3][3] = 1;
            vmap_out.map_wr[3][0] = 1;                
            vmap_out.map_wr[3][1] = 1;                
        end

        'd10 : 
        begin
            vmap_out.map_dat[0][2]  = {1'b0, vmap_in.map_tmp[0][0+:6], vmap_in.vid_dat[0][((0*P_BPC)+8)+:2]};               // TMP0-5:0 | R4-9:8
            vmap_out.map_dat[0][3]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:8]};                                         // R4-7:0
            vmap_out.map_dat[0][0]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+2)+:8]};                                         // G4-9:2
            vmap_out.map_dat[0][1]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:2], vmap_in.vid_dat[2][((0*P_BPC)+4)+:6]};   // G4-1:0 | B4-9:4
            vmap_out.map_tmp[0]     = {4'h0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:4]};                                         // B4-3:0

            vmap_out.map_dat[1][2]  = {1'b0, vmap_in.map_tmp[1][0+:6], vmap_in.vid_dat[0][((1*P_BPC)+8)+:2]};               // TMP1-5:0 | R5-9:8
            vmap_out.map_dat[1][3]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:8]};                                         // R5-7:0
            vmap_out.map_dat[1][0]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+2)+:8]};                                         // G5-9:2
            vmap_out.map_dat[1][1]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:2], vmap_in.vid_dat[2][((1*P_BPC)+4)+:6]};   // G5-1:0 | B5-9:4
            vmap_out.map_tmp[1]     = {4'h0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:4]};                                         // B5-3:0

            vmap_out.map_wr[0][2] = 1;
            vmap_out.map_wr[0][3] = 1;
            vmap_out.map_wr[0][0] = 1;
            vmap_out.map_wr[0][1] = 1;
            vmap_out.map_wr[1][2] = 1;
            vmap_out.map_wr[1][3] = 1;                
            vmap_out.map_wr[1][0] = 1;                
            vmap_out.map_wr[1][1] = 1;
        end

        'd11 : 
        begin
            vmap_out.map_dat[2][2]  = {1'b0, vmap_in.map_tmp[2][0+:6], vmap_in.vid_dat[0][((0*P_BPC)+8)+:2]};               // TMP2-5:0 | R6-9:8
            vmap_out.map_dat[2][3]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:8]};                                         // R6-7:0
            vmap_out.map_dat[2][0]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+2)+:8]};                                         // G6-9:2
            vmap_out.map_dat[2][1]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:2], vmap_in.vid_dat[2][((0*P_BPC)+4)+:6]};   // G6-1:0 | B6-9:4
            vmap_out.map_tmp[2]     = {4'h0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:4]};                                         // B6-3:0

            vmap_out.map_dat[3][2]  = {1'b0, vmap_in.map_tmp[3][0+:6], vmap_in.vid_dat[0][((1*P_BPC)+8)+:2]};               // TMP3-5:0 | R7-9:8               
            vmap_out.map_dat[3][3]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:8]};                                         // R7-7:0
            vmap_out.map_dat[3][0]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+2)+:8]};                                         // G7-9:2 
            vmap_out.map_dat[3][1]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:2], vmap_in.vid_dat[2][((1*P_BPC)+4)+:6]};   // G7-1:0 | B7-9:4
            vmap_out.map_tmp[3]     = {4'h0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:4]};                                         // B7-3:0

            vmap_out.map_wr[2][2] = 1;
            vmap_out.map_wr[2][3] = 1;
            vmap_out.map_wr[2][0] = 1;
            vmap_out.map_wr[2][1] = 1;
            vmap_out.map_wr[3][2] = 1;
            vmap_out.map_wr[3][3] = 1;                
            vmap_out.map_wr[3][0] = 1;                
            vmap_out.map_wr[3][1] = 1;
        end

        'd12 : 
        begin
            vmap_out.map_dat[0][2]  = {1'b0, vmap_in.map_tmp[0][0+:4], vmap_in.vid_dat[0][((0*P_BPC)+6)+:4]};               // TMP0-3:0 | R8-9:6
            vmap_out.map_dat[0][3]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:6], vmap_in.vid_dat[1][((0*P_BPC)+8)+:2]};   // R8-5:0 | G8-9:8
            vmap_out.map_dat[0][0]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:8]};                                         // G8-7:0 
            vmap_out.map_dat[0][1]  = {1'b0, vmap_in.vid_dat[2][((0*P_BPC)+2)+:8]};                                         // B8-9:2
            vmap_out.map_tmp[0]     = {6'h0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:2]};                                         // B8-1:0

            vmap_out.map_dat[1][2]  = {1'b0, vmap_in.map_tmp[1][0+:4], vmap_in.vid_dat[0][((1*P_BPC)+6)+:4]};               // TMP1-3:0 | R9-9:6
            vmap_out.map_dat[1][3]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:6], vmap_in.vid_dat[1][((1*P_BPC)+8)+:2]};   // R9-5:0 | G9-9:8
            vmap_out.map_dat[1][0]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:8]};                                         // G9-7:0 
            vmap_out.map_dat[1][1]  = {1'b0, vmap_in.vid_dat[2][((1*P_BPC)+2)+:8]};                                         // B9-9:2
            vmap_out.map_tmp[1]     = {6'h0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:2]};                                         // B9-1:0

            vmap_out.map_wr[0][2] = 1;
            vmap_out.map_wr[0][3] = 1;
            vmap_out.map_wr[0][0] = 1;
            vmap_out.map_wr[0][1] = 1;
            vmap_out.map_wr[1][2] = 1;
            vmap_out.map_wr[1][3] = 1;                
            vmap_out.map_wr[1][0] = 1;                
            vmap_out.map_wr[1][1] = 1;
        end

        'd13 : 
        begin
            vmap_out.map_dat[2][2]  = {1'b0, vmap_in.map_tmp[2][0+:4], vmap_in.vid_dat[0][((0*P_BPC)+6)+:4]};               // TMP2-3:0 | R10-9:6
            vmap_out.map_dat[2][3]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:6], vmap_in.vid_dat[1][((0*P_BPC)+8)+:2]};   // R10-5:0 | G10-9:8
            vmap_out.map_dat[2][0]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:8]};                                         // G10-7:0 
            vmap_out.map_dat[2][1]  = {1'b0, vmap_in.vid_dat[2][((0*P_BPC)+2)+:8]};                                         // B10-9:2
            vmap_out.map_tmp[2]     = {6'h0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:2]};                                         // B10-1:0

            vmap_out.map_dat[3][2]  = {1'b0, vmap_in.map_tmp[3][0+:4], vmap_in.vid_dat[0][((1*P_BPC)+6)+:4]};               // TMP3-3:0 | R11-9:6
            vmap_out.map_dat[3][3]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:6], vmap_in.vid_dat[1][((1*P_BPC)+8)+:2]};   // R11-5:0 | G11-9:8
            vmap_out.map_dat[3][0]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:8]};                                         // G11-7:0 
            vmap_out.map_dat[3][1]  = {1'b0, vmap_in.vid_dat[2][((1*P_BPC)+2)+:8]};                                         // B11-9:2
            vmap_out.map_tmp[3]     = {6'h0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:2]};                                         // B11-1:0

            vmap_out.map_wr[2][2] = 1;
            vmap_out.map_wr[2][3] = 1;
            vmap_out.map_wr[2][0] = 1;
            vmap_out.map_wr[2][1] = 1;
            vmap_out.map_wr[3][2] = 1;
            vmap_out.map_wr[3][3] = 1;                
            vmap_out.map_wr[3][0] = 1;                
            vmap_out.map_wr[3][1] = 1;
        end

        'd14 : 
        begin
            vmap_out.map_dat[0][2]  = {1'b0, vmap_in.map_tmp[0][0+:2], vmap_in.vid_dat[0][((0*P_BPC)+4)+:6]};               // TMP0-1:0 | R12-9:4
            vmap_out.map_dat[0][3]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:4], vmap_in.vid_dat[1][((0*P_BPC)+6)+:4]};   // R12-3:0 | G12-9:6
            vmap_out.map_dat[0][0]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:6], vmap_in.vid_dat[2][((0*P_BPC)+8)+:2]};   // G12-5:0 | B12-9:8
            vmap_out.map_dat[0][1]  = {1'b0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:8]};                                         // B12-7:0

            vmap_out.map_dat[1][2]  = {1'b0, vmap_in.map_tmp[1][0+:2], vmap_in.vid_dat[0][((1*P_BPC)+4)+:6]};               // TMP1-1:0 | R13-9:4
            vmap_out.map_dat[1][3]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:4], vmap_in.vid_dat[1][((1*P_BPC)+6)+:4]};   // R13-3:0 | G13-9:6
            vmap_out.map_dat[1][0]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:6], vmap_in.vid_dat[2][((1*P_BPC)+8)+:2]};   // G13-5:0 | B13-9:8
            vmap_out.map_dat[1][1]  = {1'b0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:8]};                                         // B13-7:0

            vmap_out.map_wr[0][2] = 1;
            vmap_out.map_wr[0][3] = 1;
            vmap_out.map_wr[0][0] = 1;
            vmap_out.map_wr[0][1] = 1;
            vmap_out.map_wr[1][2] = 1;
            vmap_out.map_wr[1][3] = 1;                
            vmap_out.map_wr[1][0] = 1;                
            vmap_out.map_wr[1][1] = 1;
        end

        'd15 : 
        begin
            vmap_out.map_dat[2][2]  = {1'b0, vmap_in.map_tmp[2][0+:2], vmap_in.vid_dat[0][((0*P_BPC)+4)+:6]};               // TMP2-1:0 | R14-9:4
            vmap_out.map_dat[2][3]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:4], vmap_in.vid_dat[1][((0*P_BPC)+6)+:4]};   // R14-3:0 | G14-9:6
            vmap_out.map_dat[2][0]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:6], vmap_in.vid_dat[2][((0*P_BPC)+8)+:2]};   // G14-5:0 | B14-9:8
            vmap_out.map_dat[2][1]  = {1'b0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:8]};                                         // B14-7:0

            vmap_out.map_dat[3][2]  = {1'b0, vmap_in.map_tmp[3][0+:2], vmap_in.vid_dat[0][((1*P_BPC)+4)+:6]};               // TMP3-1:0 | R15-9:4
            vmap_out.map_dat[3][3]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:4], vmap_in.vid_dat[1][((1*P_BPC)+6)+:4]};   // R15-3:0 | G15-9:6
            vmap_out.map_dat[3][0]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:6], vmap_in.vid_dat[2][((1*P_BPC)+8)+:2]};   // G15-5:0 | B15-9:8

            // The BS symbol is aligned with the last data.
            vmap_out.map_dat[3][1]  = {vmap_in.vid_bs, vmap_in.vid_dat[2][((1*P_BPC)+0)+:8]};                               // B15-7:0

            vmap_out.map_wr[2][2] = 1;
            vmap_out.map_wr[2][3] = 1;
            vmap_out.map_wr[2][0] = 1;
            vmap_out.map_wr[2][1] = 1;
            vmap_out.map_wr[3][2] = 1;
            vmap_out.map_wr[3][3] = 1;                
            vmap_out.map_wr[3][0] = 1;                
            vmap_out.map_wr[3][1] = 1;          
        end

        // Sequence 2
        'd16 : 
        begin
            vmap_out.map_dat[0][2]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+2)+:8]};                                         // R0-9:2               
            vmap_out.map_dat[0][3]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:2], vmap_in.vid_dat[1][((0*P_BPC)+4)+:6]};   // R0-1:0 | G0-9:4
            vmap_out.map_dat[0][0]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:4], vmap_in.vid_dat[2][((0*P_BPC)+6)+:4]};   // G0-3:0 | B0-9:6
            vmap_out.map_tmp[0]     = {2'h0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:6]};                                         // B0-5:0

            vmap_out.map_dat[1][2]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+2)+:8]};                                         // R1-9:2               
            vmap_out.map_dat[1][3]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:2], vmap_in.vid_dat[1][((1*P_BPC)+4)+:6]};   // R1-1:0 | G1-9:4
            vmap_out.map_dat[1][0]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:4], vmap_in.vid_dat[2][((1*P_BPC)+6)+:4]};   // G1-3:0 | B1-9:6
            vmap_out.map_tmp[1]     = {2'h0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:6]};                                         // B1-5:0

            vmap_out.map_wr[0][2] = 1;
            vmap_out.map_wr[0][3] = 1;
            vmap_out.map_wr[0][0] = 1;
            vmap_out.map_wr[1][2] = 1;
            vmap_out.map_wr[1][3] = 1;                
            vmap_out.map_wr[1][0] = 1;                
        end

        'd17 : 
        begin
            vmap_out.map_dat[2][2]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+2)+:8]};                                         // R2-9:2
            vmap_out.map_dat[2][3]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:2], vmap_in.vid_dat[1][((0*P_BPC)+4)+:6]};   // R2-1:0 | G2-9:4
            vmap_out.map_dat[2][0]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:4], vmap_in.vid_dat[2][((0*P_BPC)+6)+:4]};   // G2-3:0 | B2-9:6
            vmap_out.map_tmp[2]     = {2'h0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:6]};                                         // B2-5:0

            vmap_out.map_dat[3][2]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+2)+:8]};                                         // R3-9:2
            vmap_out.map_dat[3][3]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:2], vmap_in.vid_dat[1][((1*P_BPC)+4)+:6]};   // R3-1:0 | G3-9:4
            vmap_out.map_dat[3][0]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:4], vmap_in.vid_dat[2][((1*P_BPC)+6)+:4]};   // G3-3:0 | B3-9:6
            vmap_out.map_tmp[3]     = {2'h0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:6]};                                         // B3-5:0

            vmap_out.map_wr[2][2] = 1;
            vmap_out.map_wr[2][3] = 1;
            vmap_out.map_wr[2][0] = 1;
            vmap_out.map_wr[3][2] = 1;
            vmap_out.map_wr[3][3] = 1;                
            vmap_out.map_wr[3][0] = 1;                
        end

        'd18 : 
        begin
            vmap_out.map_dat[0][1]  = {1'b0, vmap_in.map_tmp[0][0+:6], vmap_in.vid_dat[0][((0*P_BPC)+8)+:2]};               // TMP0-5:0 | R4-9:8
            vmap_out.map_dat[0][2]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:8]};                                         // R4-7:0
            vmap_out.map_dat[0][3]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+2)+:8]};                                         // G4-9:2
            vmap_out.map_dat[0][0]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:2], vmap_in.vid_dat[2][((0*P_BPC)+4)+:6]};   // G4-1:0 | B4-9:4
            vmap_out.map_tmp[0]     = {4'h0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:4]};                                         // B4-3:0

            vmap_out.map_dat[1][1]  = {1'b0, vmap_in.map_tmp[1][0+:6], vmap_in.vid_dat[0][((1*P_BPC)+8)+:2]};               // TMP1-5:0 | R5-9:8
            vmap_out.map_dat[1][2]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:8]};                                         // R5-7:0
            vmap_out.map_dat[1][3]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+2)+:8]};                                         // G5-9:2
            vmap_out.map_dat[1][0]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:2], vmap_in.vid_dat[2][((1*P_BPC)+4)+:6]};   // G5-1:0 | B5-9:4
            vmap_out.map_tmp[1]     = {4'h0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:4]};                                         // B5-3:0

            vmap_out.map_wr[0][1] = 1;
            vmap_out.map_wr[0][2] = 1;
            vmap_out.map_wr[0][3] = 1;
            vmap_out.map_wr[0][0] = 1;
            vmap_out.map_wr[1][1] = 1;
            vmap_out.map_wr[1][2] = 1;                
            vmap_out.map_wr[1][3] = 1;                
            vmap_out.map_wr[1][0] = 1;
        end

        'd19 : 
        begin
            vmap_out.map_dat[2][1]  = {1'b0, vmap_in.map_tmp[2][0+:6], vmap_in.vid_dat[0][((0*P_BPC)+8)+:2]};               // TMP2-5:0 | R6-9:8
            vmap_out.map_dat[2][2]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:8]};                                         // R6-7:0
            vmap_out.map_dat[2][3]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+2)+:8]};                                         // G6-9:2
            vmap_out.map_dat[2][0]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:2], vmap_in.vid_dat[2][((0*P_BPC)+4)+:6]};   // G6-1:0 | B6-9:4
            vmap_out.map_tmp[2]     = {4'h0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:4]};                                         // B6-3:0

            vmap_out.map_dat[3][1]  = {1'b0, vmap_in.map_tmp[3][0+:6], vmap_in.vid_dat[0][((1*P_BPC)+8)+:2]};               // TMP3-5:0 | R7-9:8               
            vmap_out.map_dat[3][2]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:8]};                                         // R7-7:0
            vmap_out.map_dat[3][3]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+2)+:8]};                                         // G7-9:2 
            vmap_out.map_dat[3][0]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:2], vmap_in.vid_dat[2][((1*P_BPC)+4)+:6]};   // G7-1:0 | B7-9:4
            vmap_out.map_tmp[3]     = {4'h0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:4]};                                         // B7-3:0

            vmap_out.map_wr[2][1] = 1;
            vmap_out.map_wr[2][2] = 1;
            vmap_out.map_wr[2][3] = 1;
            vmap_out.map_wr[2][0] = 1;
            vmap_out.map_wr[3][1] = 1;
            vmap_out.map_wr[3][2] = 1;                
            vmap_out.map_wr[3][3] = 1;                
            vmap_out.map_wr[3][0] = 1;
        end

        'd20 : 
        begin
            vmap_out.map_dat[0][1]  = {1'b0, vmap_in.map_tmp[0][0+:4], vmap_in.vid_dat[0][((0*P_BPC)+6)+:4]};               // TMP0-3:0 | R8-9:6
            vmap_out.map_dat[0][2]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:6], vmap_in.vid_dat[1][((0*P_BPC)+8)+:2]};   // R8-5:0 | G8-9:8
            vmap_out.map_dat[0][3]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:8]};                                         // G8-7:0 
            vmap_out.map_dat[0][0]  = {1'b0, vmap_in.vid_dat[2][((0*P_BPC)+2)+:8]};                                         // B8-9:2
            vmap_out.map_tmp[0]     = {4'h0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:2]};                                         // B8-1:0

            vmap_out.map_dat[1][1]  = {1'b0, vmap_in.map_tmp[1][0+:4], vmap_in.vid_dat[0][((1*P_BPC)+6)+:4]};               // TMP1-3:0 | R9-9:6
            vmap_out.map_dat[1][2]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:6], vmap_in.vid_dat[1][((1*P_BPC)+8)+:2]};   // R9-5:0 | G9-9:8
            vmap_out.map_dat[1][3]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:8]};                                         // G9-7:0 
            vmap_out.map_dat[1][0]  = {1'b0, vmap_in.vid_dat[2][((1*P_BPC)+2)+:8]};                                         // B9-9:2
            vmap_out.map_tmp[1]     = {4'h0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:2]};                                         // B9-1:0

            vmap_out.map_wr[0][1] = 1;
            vmap_out.map_wr[0][2] = 1;
            vmap_out.map_wr[0][3] = 1;
            vmap_out.map_wr[0][0] = 1;
            vmap_out.map_wr[1][1] = 1;
            vmap_out.map_wr[1][2] = 1;                
            vmap_out.map_wr[1][3] = 1;                
            vmap_out.map_wr[1][0] = 1;
        end

        'd21 : 
        begin
            vmap_out.map_dat[2][1]  = {1'b0, vmap_in.map_tmp[2][0+:4], vmap_in.vid_dat[0][((0*P_BPC)+6)+:4]};               // TMP2-3:0 | R10-9:6
            vmap_out.map_dat[2][2]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:6], vmap_in.vid_dat[1][((0*P_BPC)+8)+:2]};   // R10-5:0 | G10-9:8
            vmap_out.map_dat[2][3]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:8]};                                         // G10-7:0 
            vmap_out.map_dat[2][0]  = {1'b0, vmap_in.vid_dat[2][((0*P_BPC)+2)+:8]};                                         // B10-9:2
            vmap_out.map_tmp[2]     = {6'h0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:2]};                                         // B10-1:0

            vmap_out.map_dat[3][1]  = {1'b0, vmap_in.map_tmp[3][0+:4], vmap_in.vid_dat[0][((1*P_BPC)+6)+:4]};               // TMP3-3:0 | R11-9:6
            vmap_out.map_dat[3][2]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:6], vmap_in.vid_dat[1][((1*P_BPC)+8)+:2]};   // R11-5:0 | G11-9:8
            vmap_out.map_dat[3][3]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:8]};                                         // G11-7:0 
            vmap_out.map_dat[3][0]  = {1'b0, vmap_in.vid_dat[2][((1*P_BPC)+2)+:8]};                                         // B11-9:2
            vmap_out.map_tmp[3]     = {6'h0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:2]};                                         // B11-1:0

            vmap_out.map_wr[2][1] = 1;
            vmap_out.map_wr[2][2] = 1;
            vmap_out.map_wr[2][3] = 1;
            vmap_out.map_wr[2][0] = 1;
            vmap_out.map_wr[3][1] = 1;
            vmap_out.map_wr[3][2] = 1;                
            vmap_out.map_wr[3][3] = 1;                
            vmap_out.map_wr[3][0] = 1;
        end

        'd22 : 
        begin
            vmap_out.map_dat[0][1]  = {1'b0, vmap_in.map_tmp[0][0+:2], vmap_in.vid_dat[0][((0*P_BPC)+4)+:6]};               // TMP0-1:0 | R12-9:4
            vmap_out.map_dat[0][2]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:4], vmap_in.vid_dat[1][((0*P_BPC)+6)+:4]};   // R12-3:0 | G12-9:6
            vmap_out.map_dat[0][3]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:6], vmap_in.vid_dat[2][((0*P_BPC)+8)+:2]};   // G12-5:0 | B12-9:8
            vmap_out.map_dat[0][0]  = {1'b0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:8]};                                         // B12-7:0

            vmap_out.map_dat[1][1]  = {1'b0, vmap_in.map_tmp[1][0+:2], vmap_in.vid_dat[0][((1*P_BPC)+4)+:6]};               // TMP1-1:0 | R13-9:4
            vmap_out.map_dat[1][2]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:4], vmap_in.vid_dat[1][((1*P_BPC)+6)+:4]};   // R13-3:0 | G13-9:6
            vmap_out.map_dat[1][3]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:6], vmap_in.vid_dat[2][((1*P_BPC)+8)+:2]};   // G13-5:0 | B13-9:8
            vmap_out.map_dat[1][0]  = {1'b0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:8]};                                         // B13-7:0

            vmap_out.map_wr[0][1] = 1;
            vmap_out.map_wr[0][2] = 1;
            vmap_out.map_wr[0][3] = 1;
            vmap_out.map_wr[0][0] = 1;
            vmap_out.map_wr[1][1] = 1;
            vmap_out.map_wr[1][2] = 1;                
            vmap_out.map_wr[1][3] = 1;                
            vmap_out.map_wr[1][0] = 1;
        end

        'd23 : 
        begin
            vmap_out.map_dat[2][1]  = {1'b0, vmap_in.map_tmp[2][0+:2], vmap_in.vid_dat[0][((0*P_BPC)+4)+:6]};               // TMP2-1:0 | R14-9:4
            vmap_out.map_dat[2][2]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:4], vmap_in.vid_dat[1][((0*P_BPC)+6)+:4]};   // R14-3:0 | G14-9:6
            vmap_out.map_dat[2][3]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:6], vmap_in.vid_dat[2][((0*P_BPC)+8)+:2]};   // G14-5:0 | B14-9:8
            vmap_out.map_dat[2][0]  = {1'b0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:8]};                                         // B14-7:0

            vmap_out.map_dat[3][1]  = {1'b0, vmap_in.map_tmp[3][0+:2], vmap_in.vid_dat[0][((1*P_BPC)+4)+:6]};               // TMP3-1:0 | R15-9:4
            vmap_out.map_dat[3][2]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:4], vmap_in.vid_dat[1][((1*P_BPC)+6)+:4]};   // R15-3:0 | G15-9:6
            vmap_out.map_dat[3][3]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:6], vmap_in.vid_dat[2][((1*P_BPC)+8)+:2]};   // G15-5:0 | B15-9:8

            // The BS symbol is aligned with the last data.
            vmap_out.map_dat[3][0]  = {vmap_in.vid_bs, vmap_in.vid_dat[2][((1*P_BPC)+0)+:8]};                               // B15-7:0

            vmap_out.map_wr[2][1] = 1;
            vmap_out.map_wr[2][2] = 1;
            vmap_out.map_wr[2][3] = 1;
            vmap_out.map_wr[2][0] = 1;
            vmap_out.map_wr[3][1] = 1;
            vmap_out.map_wr[3][2] = 1;                
            vmap_out.map_wr[3][3] = 1;                
            vmap_out.map_wr[3][0] = 1;          
        end

        // Sequence 3
        'd24 : 
        begin
            vmap_out.map_dat[0][1]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+2)+:8]};                                         // R0-9:2               
            vmap_out.map_dat[0][2]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:2], vmap_in.vid_dat[1][((0*P_BPC)+4)+:6]};   // R0-1:0 | G0-9:4
            vmap_out.map_dat[0][3]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:4], vmap_in.vid_dat[2][((0*P_BPC)+6)+:4]};   // G0-3:0 | B0-9:6
            vmap_out.map_tmp[0]     = {2'h0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:6]};                                         // B0-5:0

            vmap_out.map_dat[1][1]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+2)+:8]};                                         // R1-9:2               
            vmap_out.map_dat[1][2]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:2], vmap_in.vid_dat[1][((1*P_BPC)+4)+:6]};   // R1-1:0 | G1-9:4
            vmap_out.map_dat[1][3]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:4], vmap_in.vid_dat[2][((1*P_BPC)+6)+:4]};   // G1-3:0 | B1-9:6
            vmap_out.map_tmp[1]     = {2'h0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:6]};                                         // B1-5:0

            vmap_out.map_wr[0][1] = 1;
            vmap_out.map_wr[0][2] = 1;
            vmap_out.map_wr[0][3] = 1;
            vmap_out.map_wr[1][1] = 1;
            vmap_out.map_wr[1][2] = 1;                
            vmap_out.map_wr[1][3] = 1;                
        end

        'd25 : 
        begin
            vmap_out.map_dat[2][1]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+2)+:8]};                                         // R2-9:2
            vmap_out.map_dat[2][2]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:2], vmap_in.vid_dat[1][((0*P_BPC)+4)+:6]};   // R2-1:0 | G2-9:4
            vmap_out.map_dat[2][3]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:4], vmap_in.vid_dat[2][((0*P_BPC)+6)+:4]};   // G2-3:0 | B2-9:6
            vmap_out.map_tmp[2]     = {2'h0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:6]};                                         // B2-5:0

            vmap_out.map_dat[3][1]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+2)+:8]};                                         // R3-9:2
            vmap_out.map_dat[3][2]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:2], vmap_in.vid_dat[1][((1*P_BPC)+4)+:6]};   // R3-1:0 | G3-9:4
            vmap_out.map_dat[3][3]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:4], vmap_in.vid_dat[2][((1*P_BPC)+6)+:4]};   // G3-3:0 | B3-9:6
            vmap_out.map_tmp[3]     = {2'h0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:6]};                                         // B3-5:0

            vmap_out.map_wr[2][1] = 1;
            vmap_out.map_wr[2][2] = 1;
            vmap_out.map_wr[2][3] = 1;
            vmap_out.map_wr[3][1] = 1;
            vmap_out.map_wr[3][2] = 1;                
            vmap_out.map_wr[3][3] = 1;                
        end

        'd26 : 
        begin
            vmap_out.map_dat[0][0]  = {1'b0, vmap_in.map_tmp[0][0+:6], vmap_in.vid_dat[0][((0*P_BPC)+8)+:2]};               // TMP0-5:0 | R4-9:8
            vmap_out.map_dat[0][1]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:8]};                                         // R4-7:0
            vmap_out.map_dat[0][2]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+2)+:8]};                                         // G4-9:2
            vmap_out.map_dat[0][3]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:2], vmap_in.vid_dat[2][((0*P_BPC)+4)+:6]};   // G4-1:0 | B4-9:4
            vmap_out.map_tmp[0]     = {4'h0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:4]};                                         // B4-3:0

            vmap_out.map_dat[1][0]  = {1'b0, vmap_in.map_tmp[1][0+:6], vmap_in.vid_dat[0][((1*P_BPC)+8)+:2]};               // TMP1-5:0 | R5-9:8
            vmap_out.map_dat[1][1]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:8]};                                         // R5-7:0
            vmap_out.map_dat[1][2]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+2)+:8]};                                         // G5-9:2
            vmap_out.map_dat[1][3]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:2], vmap_in.vid_dat[2][((1*P_BPC)+4)+:6]};   // G5-1:0 | B5-9:4
            vmap_out.map_tmp[1]     = {4'h0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:4]};                                         // B5-3:0

            vmap_out.map_wr[0][0] = 1;
            vmap_out.map_wr[0][1] = 1;
            vmap_out.map_wr[0][2] = 1;
            vmap_out.map_wr[0][3] = 1;
            vmap_out.map_wr[1][0] = 1;
            vmap_out.map_wr[1][1] = 1;                
            vmap_out.map_wr[1][2] = 1;                
            vmap_out.map_wr[1][3] = 1;
        end

        'd27 : 
        begin
            vmap_out.map_dat[2][0]  = {1'b0, vmap_in.map_tmp[2][0+:6], vmap_in.vid_dat[0][((0*P_BPC)+8)+:2]};               // TMP2-5:0 | R6-9:8
            vmap_out.map_dat[2][1]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:8]};                                         // R6-7:0
            vmap_out.map_dat[2][2]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+2)+:8]};                                         // G6-9:2
            vmap_out.map_dat[2][3]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:2], vmap_in.vid_dat[2][((0*P_BPC)+4)+:6]};   // G6-1:0 | B6-9:4
            vmap_out.map_tmp[2]     = {4'h0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:4]};                                         // B6-3:0

            vmap_out.map_dat[3][0]  = {1'b0, vmap_in.map_tmp[3][0+:6], vmap_in.vid_dat[0][((1*P_BPC)+8)+:2]};               // TMP3-5:0 | R7-9:8               
            vmap_out.map_dat[3][1]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:8]};                                         // R7-7:0
            vmap_out.map_dat[3][2]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+2)+:8]};                                         // G7-9:2 
            vmap_out.map_dat[3][3]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:2], vmap_in.vid_dat[2][((1*P_BPC)+4)+:6]};   // G7-1:0 | B7-9:4
            vmap_out.map_tmp[3]     = {4'h0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:4]};                                         // B7-3:0

            vmap_out.map_wr[2][0] = 1;
            vmap_out.map_wr[2][1] = 1;
            vmap_out.map_wr[2][2] = 1;
            vmap_out.map_wr[2][3] = 1;
            vmap_out.map_wr[3][0] = 1;
            vmap_out.map_wr[3][1] = 1;                
            vmap_out.map_wr[3][2] = 1;                
            vmap_out.map_wr[3][3] = 1;
        end

        'd28 : 
        begin
            vmap_out.map_dat[0][0]  = {1'b0, vmap_in.map_tmp[0][0+:4], vmap_in.vid_dat[0][((0*P_BPC)+6)+:4]};               // TMP0-3:0 | R8-9:6
            vmap_out.map_dat[0][1]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:6], vmap_in.vid_dat[1][((0*P_BPC)+8)+:2]};   // R8-5:0 | G8-9:8
            vmap_out.map_dat[0][2]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:8]};                                         // G8-7:0 
            vmap_out.map_dat[0][3]  = {1'b0, vmap_in.vid_dat[2][((0*P_BPC)+2)+:8]};                                         // B8-9:2
            vmap_out.map_tmp[0]     = {6'h0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:2]};                                         // B8-1:0

            vmap_out.map_dat[1][0]  = {1'b0, vmap_in.map_tmp[1][0+:4], vmap_in.vid_dat[0][((1*P_BPC)+6)+:4]};               // TMP1-3:0 | R9-9:6
            vmap_out.map_dat[1][1]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:6], vmap_in.vid_dat[1][((1*P_BPC)+8)+:2]};   // R9-5:0 | G9-9:8
            vmap_out.map_dat[1][2]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:8]};                                         // G9-7:0 
            vmap_out.map_dat[1][3]  = {1'b0, vmap_in.vid_dat[2][((1*P_BPC)+2)+:8]};                                         // B9-9:2
            vmap_out.map_tmp[1]     = {6'h0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:2]};                                         // B9-1:0

            vmap_out.map_wr[0][0] = 1;
            vmap_out.map_wr[0][1] = 1;
            vmap_out.map_wr[0][2] = 1;
            vmap_out.map_wr[0][3] = 1;
            vmap_out.map_wr[1][0] = 1;
            vmap_out.map_wr[1][1] = 1;                
            vmap_out.map_wr[1][2] = 1;                
            vmap_out.map_wr[1][3] = 1;
        end

        'd29 : 
        begin
            vmap_out.map_dat[2][0]  = {1'b0, vmap_in.map_tmp[2][0+:4], vmap_in.vid_dat[0][((0*P_BPC)+6)+:4]};               // TMP2-3:0 | R10-9:6
            vmap_out.map_dat[2][1]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:6], vmap_in.vid_dat[1][((0*P_BPC)+8)+:2]};   // R10-5:0 | G10-9:8
            vmap_out.map_dat[2][2]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:8]};                                         // G10-7:0 
            vmap_out.map_dat[2][3]  = {1'b0, vmap_in.vid_dat[2][((0*P_BPC)+2)+:8]};                                         // B10-9:2
            vmap_out.map_tmp[2]     = {6'h0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:2]};                                         // B10-1:0

            vmap_out.map_dat[3][0]  = {1'b0, vmap_in.map_tmp[3][0+:4], vmap_in.vid_dat[0][((0*P_BPC)+6)+:4]};               // TMP3-3:0 | R11-9:6
            vmap_out.map_dat[3][1]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:6], vmap_in.vid_dat[1][((1*P_BPC)+8)+:2]};   // R11-5:0 | G11-9:8
            vmap_out.map_dat[3][2]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:8]};                                         // G11-7:0 
            vmap_out.map_dat[3][3]  = {1'b0, vmap_in.vid_dat[2][((1*P_BPC)+2)+:8]};                                         // B11-9:2
            vmap_out.map_tmp[3]     = {6'h0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:2]};                                         // B11-1:0

            vmap_out.map_wr[2][0] = 1;
            vmap_out.map_wr[2][1] = 1;
            vmap_out.map_wr[2][2] = 1;
            vmap_out.map_wr[2][3] = 1;
            vmap_out.map_wr[3][0] = 1;
            vmap_out.map_wr[3][1] = 1;                
            vmap_out.map_wr[3][2] = 1;                
            vmap_out.map_wr[3][3] = 1;
        end

        'd30 : 
        begin
            vmap_out.map_dat[0][0]  = {1'b0, vmap_in.map_tmp[0][0+:2], vmap_in.vid_dat[0][((0*P_BPC)+4)+:6]};               // TMP0-1:0 | R12-9:4
            vmap_out.map_dat[0][1]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:4], vmap_in.vid_dat[1][((0*P_BPC)+6)+:4]};   // R12-3:0 | G12-9:6
            vmap_out.map_dat[0][2]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:6], vmap_in.vid_dat[2][((0*P_BPC)+8)+:2]};   // G12-5:0 | B12-9:8
            vmap_out.map_dat[0][3]  = {1'b0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:8]};                                         // B12-7:0

            vmap_out.map_dat[1][0]  = {1'b0, vmap_in.map_tmp[1][0+:2], vmap_in.vid_dat[0][((1*P_BPC)+4)+:6]};               // TMP1-1:0 | R13-9:4
            vmap_out.map_dat[1][1]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:4], vmap_in.vid_dat[1][((1*P_BPC)+6)+:4]};   // R13-3:0 | G13-9:6
            vmap_out.map_dat[1][2]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:6], vmap_in.vid_dat[2][((1*P_BPC)+8)+:2]};   // G13-5:0 | B13-9:8
            vmap_out.map_dat[1][3]  = {1'b0, vmap_in.vid_dat[2][((1*P_BPC)+0)+:8]};                                         // B13-7:0

            vmap_out.map_wr[0][0] = 1;
            vmap_out.map_wr[0][1] = 1;
            vmap_out.map_wr[0][2] = 1;
            vmap_out.map_wr[0][3] = 1;
            vmap_out.map_wr[1][0] = 1;
            vmap_out.map_wr[1][1] = 1;                
            vmap_out.map_wr[1][2] = 1;                
            vmap_out.map_wr[1][3] = 1;
        end

        'd31 : 
        begin
            vmap_out.map_dat[2][0]  = {1'b0, vmap_in.map_tmp[2][0+:2], vmap_in.vid_dat[0][((0*P_BPC)+4)+:6]};               // TMP2-1:0 | R14-9:4
            vmap_out.map_dat[2][1]  = {1'b0, vmap_in.vid_dat[0][((0*P_BPC)+0)+:4], vmap_in.vid_dat[1][((0*P_BPC)+6)+:4]};   // R14-3:0 | G14-9:6
            vmap_out.map_dat[2][2]  = {1'b0, vmap_in.vid_dat[1][((0*P_BPC)+0)+:6], vmap_in.vid_dat[2][((0*P_BPC)+8)+:2]};   // G14-5:0 | B14-9:8
            vmap_out.map_dat[2][3]  = {1'b0, vmap_in.vid_dat[2][((0*P_BPC)+0)+:8]};                                         // B14-7:0

            vmap_out.map_dat[3][0]  = {1'b0, vmap_in.map_tmp[3][0+:2], vmap_in.vid_dat[0][((1*P_BPC)+4)+:6]};               // TMP3-1:0 | R15-9:4
            vmap_out.map_dat[3][1]  = {1'b0, vmap_in.vid_dat[0][((1*P_BPC)+0)+:4], vmap_in.vid_dat[1][((1*P_BPC)+6)+:4]};   // R15-3:0 | G15-9:6
            vmap_out.map_dat[3][2]  = {1'b0, vmap_in.vid_dat[1][((1*P_BPC)+0)+:6], vmap_in.vid_dat[2][((1*P_BPC)+8)+:2]};   // G15-5:0 | B15-9:8

            // The BS symbol is aligned with the last data.
            vmap_out.map_dat[3][3]  = {vmap_in.vid_bs, vmap_in.vid_dat[2][((1*P_BPC)+0)+:8]};                               // B15-7:0

            vmap_out.map_wr[2][0] = 1;
            vmap_out.map_wr[2][1] = 1;
            vmap_out.map_wr[2][2] = 1;
            vmap_out.map_wr[2][3] = 1;
            vmap_out.map_wr[3][0] = 1;
            vmap_out.map_wr[3][1] = 1;                
            vmap_out.map_wr[3][2] = 1;                
            vmap_out.map_wr[3][3] = 1;          
        end

        default : ;

    endcase

    return vmap_out;

endfunction 

// Logic

// Map control
    assign clk_ctl.run = CFG_RUN_IN;
    assign clk_ctl.bpc = CFG_BPC_IN;
    assign clk_ctl.mst = CFG_MST_IN;

// Map video
    assign clk_vid.bs = VID_BS_IN;
    assign clk_vid.be = VID_BE_IN;
    assign clk_vid.hs = VID_HS_IN;

generate    
    for (i = 0; i < 3; i++)
    begin : gen_vid_dat
        assign clk_vid.dat[i] = VID_DAT_IN[i];
    end
endgenerate

    assign clk_vid.de = VID_DE_IN;

// Select end
generate
    // 4 pixels per clock
    if (P_PPC == 4)
    begin : gen_map_sel_4ppc
        always_comb
        begin
            // 10-bits video
            if (clk_ctl.bpc)
                clk_map.sel_end = 'd3;
            
            // 8-bits video
            else
                clk_map.sel_end = 'd3;
        end
    end

    // 2 pixels per clock
    else
    begin : gen_map_sel_4ppc
        always_comb
        begin
            // 10-bits video
            if (clk_ctl.bpc)
                clk_map.sel_end = 'd31;
            
            // 8-bits video
            else
                clk_map.sel_end = 'd7;
        end
    end
endgenerate

// Select
    always_ff @ (posedge CLK_IN)
    begin
        // Run
        if (clk_ctl.run)
        begin
            // Clock enable
            if (CKE_IN)
            begin
                // Clear on hsync
                if (clk_vid.hs)
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
        end

        else
            clk_map.sel <= 0;
    end

/*
// Data
generate
    // Four pixels per clock
    if (P_PPC == 4)
    begin : gen_map_dat_4ppc
        always_comb
        begin
            for (int i = 0; i < P_LANES; i++)
            begin
                for (int j = 0; j < P_FIFO_STRIPES; j++)
                begin
                    map_wr[i][j] = 0;
                    map_dat[i][j] = 0;
                end
            end

            case (clk_map.sel)
                'd1 : 
                begin
                    map_dat[0][3] = {1'b0, vid_dat_in[0][((1*P_BPC)-1)-:P_MAP_DAT]};   // R4
                    map_dat[0][0] = {1'b0, vid_dat_in[1][((1*P_BPC)-1)-:P_MAP_DAT]};   // G4
                    map_dat[0][1] = {1'b0, vid_dat_in[2][((1*P_BPC)-1)-:P_MAP_DAT]};   // B4
                    map_dat[1][3] = {1'b0, vid_dat_in[0][((2*P_BPC)-1)-:P_MAP_DAT]};   // R5
                    map_dat[1][0] = {1'b0, vid_dat_in[1][((2*P_BPC)-1)-:P_MAP_DAT]};   // G5
                    map_dat[1][1] = {1'b0, vid_dat_in[2][((2*P_BPC)-1)-:P_MAP_DAT]};   // B5
                    map_dat[2][3] = {1'b0, vid_dat_in[0][((3*P_BPC)-1)-:P_MAP_DAT]};   // R6
                    map_dat[2][0] = {1'b0, vid_dat_in[1][((3*P_BPC)-1)-:P_MAP_DAT]};   // G6
                    map_dat[2][1] = {1'b0, vid_dat_in[2][((3*P_BPC)-1)-:P_MAP_DAT]};   // B6
                    map_dat[3][3] = {1'b0, vid_dat_in[0][((4*P_BPC)-1)-:P_MAP_DAT]};   // R7
                    map_dat[3][0] = {1'b0, vid_dat_in[1][((4*P_BPC)-1)-:P_MAP_DAT]};   // G7
                    map_dat[3][1] = {1'b0, vid_dat_in[2][((4*P_BPC)-1)-:P_MAP_DAT]};   // B7

                    map_wr[0][3] = 1;
                    map_wr[0][0] = 1;
                    map_wr[0][1] = 1;
                    map_wr[1][3] = 1;
                    map_wr[1][0] = 1;                
                    map_wr[1][1] = 1;                
                    map_wr[2][3] = 1;
                    map_wr[2][0] = 1;
                    map_wr[2][1] = 1;
                    map_wr[3][3] = 1;
                    map_wr[3][0] = 1;                
                    map_wr[3][1] = 1;                
                end

                'd2 : 
                begin
                    map_dat[0][2] = {1'b0, vid_dat_in[0][((1*P_BPC)-1)-:P_MAP_DAT]};   // R8
                    map_dat[0][3] = {1'b0, vid_dat_in[1][((1*P_BPC)-1)-:P_MAP_DAT]};   // G8
                    map_dat[0][0] = {1'b0, vid_dat_in[2][((1*P_BPC)-1)-:P_MAP_DAT]};   // B8
                    map_dat[1][2] = {1'b0, vid_dat_in[0][((2*P_BPC)-1)-:P_MAP_DAT]};   // R9
                    map_dat[1][3] = {1'b0, vid_dat_in[1][((2*P_BPC)-1)-:P_MAP_DAT]};   // G9
                    map_dat[1][0] = {1'b0, vid_dat_in[2][((2*P_BPC)-1)-:P_MAP_DAT]};   // B9
                    map_dat[2][2] = {1'b0, vid_dat_in[0][((3*P_BPC)-1)-:P_MAP_DAT]};   // R10
                    map_dat[2][3] = {1'b0, vid_dat_in[1][((3*P_BPC)-1)-:P_MAP_DAT]};   // G10
                    map_dat[2][0] = {1'b0, vid_dat_in[2][((3*P_BPC)-1)-:P_MAP_DAT]};   // B10
                    map_dat[3][2] = {1'b0, vid_dat_in[0][((4*P_BPC)-1)-:P_MAP_DAT]};   // R11
                    map_dat[3][3] = {1'b0, vid_dat_in[1][((4*P_BPC)-1)-:P_MAP_DAT]};   // G11
                    map_dat[3][0] = {1'b0, vid_dat_in[2][((4*P_BPC)-1)-:P_MAP_DAT]};   // B11

                    map_wr[0][2] = 1;
                    map_wr[0][3] = 1;
                    map_wr[0][0] = 1;
                    map_wr[1][2] = 1;
                    map_wr[1][3] = 1;                
                    map_wr[1][0] = 1;                
                    map_wr[2][2] = 1;
                    map_wr[2][3] = 1;
                    map_wr[2][0] = 1;
                    map_wr[3][2] = 1;
                    map_wr[3][3] = 1;                
                    map_wr[3][0] = 1;                
                end

                'd3 : 
                begin
                    map_dat[0][1] = {1'b0, vid_dat_in[0][((1*P_BPC)-1)-:P_MAP_DAT]};   // R12
                    map_dat[0][2] = {1'b0, vid_dat_in[1][((1*P_BPC)-1)-:P_MAP_DAT]};   // G12
                    map_dat[0][3] = {1'b0, vid_dat_in[2][((1*P_BPC)-1)-:P_MAP_DAT]};   // B12
                    map_dat[1][1] = {1'b0, vid_dat_in[0][((2*P_BPC)-1)-:P_MAP_DAT]};   // R13
                    map_dat[1][2] = {1'b0, vid_dat_in[1][((2*P_BPC)-1)-:P_MAP_DAT]};   // G13
                    map_dat[1][3] = {1'b0, vid_dat_in[2][((2*P_BPC)-1)-:P_MAP_DAT]};   // B13
                    map_dat[2][1] = {1'b0, vid_dat_in[0][((3*P_BPC)-1)-:P_MAP_DAT]};   // R14
                    map_dat[2][2] = {1'b0, vid_dat_in[1][((3*P_BPC)-1)-:P_MAP_DAT]};   // G14
                    map_dat[2][3] = {1'b0, vid_dat_in[2][((3*P_BPC)-1)-:P_MAP_DAT]};   // B14
                    map_dat[3][1] = {1'b0, vid_dat_in[0][((4*P_BPC)-1)-:P_MAP_DAT]};   // R15
                    map_dat[3][2] = {1'b0, vid_dat_in[1][((4*P_BPC)-1)-:P_MAP_DAT]};   // G15

                    // SST
                    // The BS symbol is aligned with the last data.
                    map_dat[3][3] = {clk_vid.bs, vid_dat_in[2][((4*P_BPC)-1)-:P_MAP_DAT]};   // B15 
                    
                    map_wr[0][1] = 1;
                    map_wr[0][2] = 1;
                    map_wr[0][3] = 1;
                    map_wr[1][1] = 1;
                    map_wr[1][2] = 1;                
                    map_wr[1][3] = 1;                
                    map_wr[2][1] = 1;
                    map_wr[2][2] = 1;
                    map_wr[2][3] = 1;
                    map_wr[3][1] = 1;
                    map_wr[3][2] = 1;                
                    map_wr[3][3] = 1;                
                end

                default : 
                begin
                    map_dat[0][0] = {1'b0, vid_dat_in[0][((1*P_BPC)-1)-:P_MAP_DAT]};   // R0
                    
                    // MST
                    // The BS symbol is inserted in the second fifo stripe, just after the active video.                  
                    map_dat[0][1] = (clk_vid.bs) ? {1'b1, {P_MAP_DAT{1'b0}}} : {1'b0, vid_dat_in[1][((1*P_BPC)-1)-:P_MAP_DAT]};   // G0
                    
                    // MST
                    // The BE symbol is inserted in the third fifo stripe, just before the active video.
                    map_dat[0][2] = (clk_vid.be) ? {1'b1, {P_MAP_DAT{1'b0}}} : {1'b0, vid_dat_in[2][((1*P_BPC)-1)-:P_MAP_DAT]};   // B0

                    map_dat[1][0] = {1'b0, vid_dat_in[0][((2*P_BPC)-1)-:P_MAP_DAT]};   // R1
                    map_dat[1][1] = {1'b0, vid_dat_in[1][((2*P_BPC)-1)-:P_MAP_DAT]};   // G1
                    map_dat[1][2] = {1'b0, vid_dat_in[2][((2*P_BPC)-1)-:P_MAP_DAT]};   // B1
                    map_dat[2][0] = {1'b0, vid_dat_in[0][((3*P_BPC)-1)-:P_MAP_DAT]};   // R2
                    map_dat[2][1] = {1'b0, vid_dat_in[1][((3*P_BPC)-1)-:P_MAP_DAT]};   // G2
                    map_dat[2][2] = {1'b0, vid_dat_in[2][((3*P_BPC)-1)-:P_MAP_DAT]};   // B2
                    map_dat[3][0] = {1'b0, vid_dat_in[0][((4*P_BPC)-1)-:P_MAP_DAT]};   // R3
                    map_dat[3][1] = {1'b0, vid_dat_in[1][((4*P_BPC)-1)-:P_MAP_DAT]};   // G3
                    map_dat[3][2] = {1'b0, vid_dat_in[2][((4*P_BPC)-1)-:P_MAP_DAT]};   // B3

                    map_wr[0][0] = 1;
                    map_wr[0][1] = 1;
                    map_wr[0][2] = 1;
                    map_wr[1][0] = 1;
                    map_wr[1][1] = 1;                
                    map_wr[1][2] = 1;                
                    map_wr[2][0] = 1;
                    map_wr[2][1] = 1;
                    map_wr[2][2] = 1;
                    map_wr[3][0] = 1;
                    map_wr[3][1] = 1;                
                    map_wr[3][2] = 1;                
                end
            endcase
        end
    end

    // Two pixels per clock
    else
    begin
        always_comb
        begin
        end
    end
endgenerate
*/

generate
    // 10-bits
    if (P_BPC == 10)
    begin : gen_vmap_10bpc
        // Assign function vmap inputs
        assign fn_vmap_in.ctl_mst = clk_ctl.mst;
        assign fn_vmap_in.map_sel = clk_map.sel;
        assign fn_vmap_in.map_tmp = clk_map.tmp;
        assign fn_vmap_in.vid_bs = clk_vid.bs;
        assign fn_vmap_in.vid_be = clk_vid.be;
        assign fn_vmap_in.vid_dat = clk_vid.dat;

        always_comb
        begin
            // 10-bits video
            if (clk_ctl.bpc)
                fn_vmap_out = vmap_2ppc_10bpc (fn_vmap_in);
            
            // 8-bits video
            else
                fn_vmap_out = vmap_2ppc_8bpc (fn_vmap_in);
        end

        assign clk_map.dat = fn_vmap_out.map_dat;
        assign clk_map.wr = fn_vmap_out.map_wr;

        always_ff @ (posedge CLK_IN)
        begin
            clk_map.tmp <= fn_vmap_out.map_tmp;
        end

    end

    // 8-bits
    else
    begin : gen_vmap_8bpc
        // Assign function vmap inputs
        assign fn_vmap_in.ctl_mst = clk_ctl.mst;
        assign fn_vmap_in.map_sel = clk_map.sel;
        assign fn_vmap_in.map_tmp = '{0, 0, 0, 0};
        assign fn_vmap_in.vid_bs = clk_vid.bs;
        assign fn_vmap_in.vid_be = clk_vid.be;
        assign fn_vmap_in.vid_dat = clk_vid.dat;

        assign fn_vmap_out = vmap_2ppc_8bpc (fn_vmap_in);

        assign clk_map.dat = fn_vmap_out.map_dat;
        assign clk_map.wr = fn_vmap_out.map_wr;
    end
endgenerate


// Outputs
    assign MAP_DAT_OUT = clk_map.dat;
    assign MAP_WR_OUT = clk_map.wr;

endmodule

`default_nettype wire
