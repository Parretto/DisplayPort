/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: EDID
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
    The License is available for download and print at www.parretto.com/license.html
    Parretto grants you, as the Licensee, a free, non-exclusive, non-transferable, limited right to use the IP-core 
    solely for internal business purposes for the term and conditions of the License. 
    You are also allowed to create Modifications for internal business purposes, but explicitly only under the conditions of art. 3.2.
    You are, however, obliged to pay the License Fees to Parretto for the use of the IP-core, or any Modification, in, or embodied in, 
    a physical or non-tangible product or service that has substantial commercial, industrial or non-consumer uses. 
*/

// Includes
#include "prt_types.h"
#include "prt_dp_edid_dat.h"
#include "prt_dp_edid.h"

// This function updates the first 18 byte descriptor
void prt_dp_edid_set (prt_u8 edid)
{
     // Variables
     prt_u8 i;

     switch (edid)
     {
          // 720p50
          case PRT_EDID_1280X720P50 : 

               // Standard Timing 1
               edid_dat[38] = 0x01;
               edid_dat[39] = 0x01;
               
               // First 18 byte descriptor
               edid_dat[54] = 0x01;
               edid_dat[55] = 0x1d;
               edid_dat[56] = 0x00;
               edid_dat[57] = 0xbc;
               edid_dat[58] = 0x52;
               edid_dat[59] = 0xd0;
               edid_dat[60] = 0x1e;
               edid_dat[61] = 0x20;
               edid_dat[62] = 0xb8;
               edid_dat[63] = 0x28;
               edid_dat[64] = 0x55;
               edid_dat[65] = 0x40;
               edid_dat[66] = 0x00;
               edid_dat[67] = 0x00;
               edid_dat[68] = 0x00;
               edid_dat[69] = 0x00;
               edid_dat[70] = 0x00;
               edid_dat[71] = 0x1e;

               // Second 18 byte descriptor
               for (i = 0; i < 18 ; i++)
                    edid_dat[72+i] = 0x00;
               
               // Dummy descriptor
               edid_dat[72+3] = 0x10;

               // Third 18 byte descriptor
               for (i = 0; i < 18 ; i++)
                    edid_dat[90+i] = 0x00;
               
               // Dummy descriptor
               edid_dat[90+3] = 0x10;

               // Checksum
               edid_dat[127] = 0x03;
          break;

          // 1080p50
          case PRT_EDID_1920X1080P50 : 

               // Standard Timing 1
               edid_dat[38] = 0x01;
               edid_dat[39] = 0x01;

               // First 18 byte descriptor
               edid_dat[54] = 0x02;
               edid_dat[55] = 0x3a;
               edid_dat[56] = 0x80;
               edid_dat[57] = 0xd0;
               edid_dat[58] = 0x72;
               edid_dat[59] = 0x38;
               edid_dat[60] = 0x2d;
               edid_dat[61] = 0x40;
               edid_dat[62] = 0x10;
               edid_dat[63] = 0x2c;
               edid_dat[64] = 0x45;
               edid_dat[65] = 0x80;
               edid_dat[66] = 0x00;
               edid_dat[67] = 0x00;
               edid_dat[68] = 0x00;
               edid_dat[69] = 0x00;
               edid_dat[70] = 0x00;
               edid_dat[71] = 0x1e;

               // Second 18 byte descriptor
               for (i = 0; i < 18 ; i++)
                    edid_dat[72+i] = 0x00;
               
               // Dummy descriptor
               edid_dat[72+3] = 0x10;

               // Third 18 byte descriptor
               for (i = 0; i < 18 ; i++)
                    edid_dat[90+i] = 0x00;
               
               // Dummy descriptor
               edid_dat[90+3] = 0x10;

               // Checksum
               edid_dat[127] = 0x0e;
          break;

          // 1440p50
          case PRT_EDID_2560X1440P50 : 

               // Standard Timing 1
               edid_dat[38] = 0x01;
               edid_dat[39] = 0x01;

               // First 18 byte descriptor
               edid_dat[54] = 0x04;
               edid_dat[55] = 0x74;
               edid_dat[56] = 0x00;
               edid_dat[57] = 0x78;
               edid_dat[58] = 0xa5;
               edid_dat[59] = 0xa0;
               edid_dat[60] = 0x3c;
               edid_dat[61] = 0x50;
               edid_dat[62] = 0xb8;
               edid_dat[63] = 0x50;
               edid_dat[64] = 0x8a;
               edid_dat[65] = 0x48;
               edid_dat[66] = 0x00;
               edid_dat[67] = 0x00;
               edid_dat[68] = 0x00;
               edid_dat[69] = 0x00;
               edid_dat[70] = 0x00;
               edid_dat[71] = 0x1e;

               // Second 18 byte descriptor
               for (i = 0; i < 18 ; i++)
                    edid_dat[72+i] = 0x00;
               
               // Dummy descriptor
               edid_dat[72+3] = 0x10;

               // Third 18 byte descriptor
               for (i = 0; i < 18 ; i++)
                    edid_dat[90+i] = 0x00;
               
               // Dummy descriptor
               edid_dat[90+3] = 0x10;

               // Checksum
               edid_dat[127] = 0x17;
          break;

          // 4kp50
          case PRT_EDID_3840X2160P50 : 

               // Standard Timing 1
               edid_dat[38] = 0x01;
               edid_dat[39] = 0x01;

               // First 18 byte descriptor
               edid_dat[54] = 0x08;
               edid_dat[55] = 0xe8;
               edid_dat[56] = 0x00;
               edid_dat[57] = 0x30;
               edid_dat[58] = 0xf2;
               edid_dat[59] = 0x70;
               edid_dat[60] = 0x5a;
               edid_dat[61] = 0x80;
               edid_dat[62] = 0xb0;
               edid_dat[63] = 0x58;
               edid_dat[64] = 0x8a;
               edid_dat[65] = 0x00;
               edid_dat[66] = 0x00;
               edid_dat[67] = 0x00;
               edid_dat[68] = 0x00;
               edid_dat[69] = 0x00;
               edid_dat[70] = 0x00;
               edid_dat[71] = 0x1e;

               // Second 18 byte descriptor
               for (i = 0; i < 18 ; i++)
                    edid_dat[72+i] = 0x00;
               
               // Dummy descriptor
               edid_dat[72+3] = 0x10;

               // Third 18 byte descriptor
               for (i = 0; i < 18 ; i++)
                    edid_dat[90+i] = 0x00;
               
               // Dummy descriptor
               edid_dat[90+3] = 0x10;

               // Checksum
               edid_dat[127] = 0xc4;
          break;

          // All 
          default : 
               // Standard Timing 1
               edid_dat[38] = 0xd1;
               edid_dat[39] = 0xc0;

               // First 18 byte descriptor
               edid_dat[54] = 0x08;
               edid_dat[55] = 0xe8;
               edid_dat[56] = 0x00;
               edid_dat[57] = 0x30;
               edid_dat[58] = 0xf2;
               edid_dat[59] = 0x70;
               edid_dat[60] = 0x5a;
               edid_dat[61] = 0x80;
               edid_dat[62] = 0xb0;
               edid_dat[63] = 0x58;
               edid_dat[64] = 0x8a;
               edid_dat[65] = 0x00;
               edid_dat[66] = 0x00;
               edid_dat[67] = 0x00;
               edid_dat[68] = 0x00;
               edid_dat[69] = 0x00;
               edid_dat[70] = 0x00;
               edid_dat[71] = 0x1e;

               // Second 18 byte descriptor
               edid_dat[72] = 0x04;
               edid_dat[73] = 0x74;
               edid_dat[74] = 0x00;
               edid_dat[75] = 0x78;
               edid_dat[76] = 0xa5;
               edid_dat[77] = 0xa0;
               edid_dat[78] = 0x3c;
               edid_dat[79] = 0x50;
               edid_dat[80] = 0xb8;
               edid_dat[81] = 0x50;
               edid_dat[82] = 0x8a;
               edid_dat[83] = 0x48;
               edid_dat[84] = 0x00;
               edid_dat[85] = 0x00;
               edid_dat[86] = 0x00;
               edid_dat[87] = 0x00;
               edid_dat[88] = 0x00;
               edid_dat[89] = 0x1e;
               
               // Third 18 byte descriptor
               edid_dat[90] = 0x01;
               edid_dat[91] = 0x1d;
               edid_dat[92] = 0x00;
               edid_dat[93] = 0xbc;
               edid_dat[94] = 0x52;
               edid_dat[95] = 0xd0;
               edid_dat[96] = 0x1e;
               edid_dat[97] = 0x20;
               edid_dat[98] = 0xb8;
               edid_dat[99] = 0x28;
               edid_dat[100] = 0x55;
               edid_dat[101] = 0x40;
               edid_dat[102] = 0x00;
               edid_dat[103] = 0x00;
               edid_dat[104] = 0x00;
               edid_dat[105] = 0x00;
               edid_dat[106] = 0x00;
               edid_dat[107] = 0x1e;

               // Checksum
               edid_dat[127] = 0xcf;
          break;
     }
}