/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP Package
    (c) 2021 - 2025 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Added TX link identifiers

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

package prt_dp_pkg;

// Parameters

// Symbols                                              SST     - MST
localparam P_SYM_K28_0 = 'h1_1c;	// K28.0        SR      - GP1 index 2
localparam P_SYM_K28_2 = 'h1_5c;	// K28.2        SS      - GP1 index 3
localparam P_SYM_K28_3 = 'h1_7c;	// K28.3        BF      - GP1 index 4
localparam P_SYM_K28_5 = 'h1_bc;	// K28.5        BS      - SR
localparam P_SYM_K28_6 = 'h1_dc;	// K28.6        rsvd    - GP1 index 5
localparam P_SYM_K23_7 = 'h1_f7;	// K23.7        FE      - GP1 index 0
localparam P_SYM_K27_7 = 'h1_fb;	// K27.7        BE      - GP1 index 1
localparam P_SYM_K29_7 = 'h1_fd;	// K29.7        SE      - GP1 index 6
localparam P_SYM_K30_7 = 'h1_fe;	// K30.7        FS      - GP1 index 7

localparam P_SYM_BS = P_SYM_K28_5;	// K28.5
localparam P_SYM_BF = P_SYM_K28_3;	// K28.3
localparam P_SYM_BE = P_SYM_K27_7;	// K27.7
localparam P_SYM_FS = P_SYM_K30_7;	// K30.7
localparam P_SYM_FE = P_SYM_K23_7;	// K23.7
localparam P_SYM_SR = P_SYM_K28_0;	// K28.0
localparam P_SYM_SS = P_SYM_K28_2;	// K28.2
localparam P_SYM_SE = P_SYM_K29_7;	// K29.7

// TX link symbols
// The link symbols are ordered to match the control code sequence index
// See DP1.4 spec page 265
typedef enum logic [5:0] {
        TX_LNK_SYM_BS,       //  0 - Blanking start
        TX_LNK_SYM_BE,       //  1 - Blanking end
        TX_LNK_SYM_UDEF1,    //  2 - Not used
        TX_LNK_SYM_SS,       //  3 - Secondary data start
        TX_LNK_SYM_SF,       //  4 - Stream fill control
        TX_LNK_SYM_UDEF2,    //  5 - Not used
        TX_LNK_SYM_SE,       //  6 - Secondary data end
        TX_LNK_SYM_UDEF3,    //  7 - Not used

        TX_LNK_SYM_C0,       //  8 - Control code sequence C0
        TX_LNK_SYM_C1,       //  9 - Control code sequence C1
        TX_LNK_SYM_C2,       // 10 - Control code sequence C2
        TX_LNK_SYM_C3,       // 11 - Control code sequence C3
        TX_LNK_SYM_FS,       // 12 - Fill start
        TX_LNK_SYM_FE,       // 13 - Fill end
        TX_LNK_SYM_BF,       // 14 - Enhanced framing mode BF
        TX_LNK_SYM_UDEF4,    // 15 - Not used

        TX_LNK_SYM_SR,       // 16 - Scrambler reset
        TX_LNK_SYM_MTPH_SR,  // 17 - MTP header Scrambler reset
        TX_LNK_SYM_MTPH_NOP, // 18 - MTP header nop
        TX_LNK_SYM_DAT,      // 19 - Data
        TX_LNK_SYM_NOP       // 20 - Nop
} prt_dp_tx_lnk_sym;

// This typedef is required to convert the symbol back to a normal wire
typedef logic [5:0] prt_dp_tx_lnk_sym_wire;

endpackage
