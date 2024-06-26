/*
 * tentiva_vid_clk register file
 * for Renesas RC22504A clock synthesizer
 * (c) 2021 - 2024 by Parretto B.V.
 */

#ifndef __TENTIVA_VID_CLK_H__
#define __TENTIVA_VID_CLK_H__

#define TENTIVA_VID_CLK_CONFIG_NUM_REGS 480

// Configuration 0 - SD and HD video clocks 
prt_rc22504a_reg_struct tentiva_vid_clk_cfg0_reg[TENTIVA_VID_CLK_CONFIG_NUM_REGS] = 
{
	{0x00, 0x33},
	{0x01, 0x10},
	{0x02, 0x4A},
	{0x03, 0x30},
	{0x04, 0x32},
	{0x05, 0x02},
	{0x06, 0x00},
	{0x07, 0x00},
	{0x08, 0x04},
	{0x09, 0x00},
	{0x0A, 0x30},
	{0x0B, 0x00},
	{0x0C, 0x00},
	{0x0D, 0x00},
	{0x0E, 0x00},
	{0x0F, 0x00},
	{0x10, 0x00},
	{0x11, 0x00},
	{0x12, 0x19},
	{0x13, 0x9A},
	{0x14, 0x00},
	{0x15, 0x00},
	{0x16, 0x00},
	{0x17, 0x00},
	{0x18, 0x00},
	{0x19, 0x00},
	{0x1A, 0x00},
	{0x1B, 0xF0},
	{0x1C, 0x00},
	{0x1D, 0x00},
	{0x1E, 0x00},
	{0x1F, 0x00},
	{0x20, 0x00},
	{0x21, 0x00},
	{0x22, 0x00},
	{0x23, 0x00},
	{0x24, 0x00},
	{0x25, 0x00},
	{0x26, 0x00},
	{0x27, 0x00},
	{0x28, 0x00},
	{0x29, 0x00},
	{0x2A, 0x00},
	{0x2B, 0x00},
	{0x2C, 0x00},
	{0x2D, 0x00},
	{0x2E, 0x00},
	{0x2F, 0x00},
	{0x30, 0x03},
	{0x31, 0x01},
	{0x32, 0x00},
	{0x33, 0x00},
	{0x34, 0x01},
	{0x35, 0x00},
	{0x36, 0x00},
	{0x37, 0x00},
	{0x38, 0x00},
	{0x39, 0x00},
	{0x3A, 0x00},
	{0x3B, 0x00},
	{0x3C, 0x00},
	{0x3D, 0x00},
	{0x3E, 0x00},
	{0x3F, 0x00},
	{0x40, 0x03},
	{0x41, 0x01},
	{0x42, 0x00},
	{0x43, 0x00},
	{0x44, 0x01},
	{0x45, 0x00},
	{0x46, 0x00},
	{0x47, 0x00},
	{0x48, 0x00},
	{0x49, 0x00},
	{0x4A, 0x00},
	{0x4B, 0x00},
	{0x4C, 0x00},
	{0x4D, 0x00},
	{0x4E, 0x00},
	{0x4F, 0x00},
	{0x50, 0x03},
	{0x51, 0x01},
	{0x52, 0x00},
	{0x53, 0x00},
	{0x54, 0x01},
	{0x55, 0x00},
	{0x56, 0x00},
	{0x57, 0x00},
	{0x58, 0x00},
	{0x59, 0x00},
	{0x5A, 0x00},
	{0x5B, 0x00},
	{0x5C, 0x00},
	{0x5D, 0x00},
	{0x5E, 0x00},
	{0x5F, 0x00},
	{0x60, 0x01},
	{0x61, 0x01},
	{0x62, 0x00},
	{0x63, 0x00},
	{0x64, 0x00},
	{0x65, 0x00},
	{0x66, 0x10},
	{0x67, 0x00},
	{0x68, 0x00},
	{0x69, 0x00},
	{0x6A, 0x00},
	{0x6B, 0x00},
	{0x6C, 0x00},
	{0x6D, 0x00},
	{0x6E, 0x00},
	{0x6F, 0x00},
	{0x70, 0x00},
	{0x71, 0x00},
	{0x72, 0x00},
	{0x73, 0x00},
	{0x74, 0x00},
	{0x75, 0x00},
	{0x76, 0x00},
	{0x77, 0x00},
	{0x78, 0x00},
	{0x79, 0x00},
	{0x7A, 0x00},
	{0x7B, 0x00},
	{0x7C, 0x00},
	{0x7D, 0x00},
	{0x7E, 0x00},
	{0x7F, 0x00},
	{0x80, 0x01},
	{0x81, 0x01},
	{0x82, 0x00},
	{0x83, 0x00},
	{0x84, 0x00},
	{0x85, 0x00},
	{0x86, 0x10},
	{0x87, 0x00},
	{0x88, 0x00},
	{0x89, 0x00},
	{0x8A, 0x00},
	{0x8B, 0x00},
	{0x8C, 0x00},
	{0x8D, 0x00},
	{0x8E, 0x00},
	{0x8F, 0x00},
	{0x90, 0x00},
	{0x91, 0x00},
	{0x92, 0x00},
	{0x93, 0x00},
	{0x94, 0x00},
	{0x95, 0x00},
	{0x96, 0x00},
	{0x97, 0x00},
	{0x98, 0x00},
	{0x99, 0x00},
	{0x9A, 0x00},
	{0x9B, 0x00},
	{0x9C, 0x00},
	{0x9D, 0x00},
	{0x9E, 0x00},
	{0x9F, 0x00},
	{0xA0, 0x00},
	{0xA1, 0x83},
	{0xA2, 0x36},
	{0xA3, 0x00},
	{0xA4, 0x00},
	{0xA5, 0x38},
	{0xA6, 0x42},
	{0xA7, 0x5B},
	{0xA8, 0x10},
	{0xA9, 0x11},
	{0xAA, 0x00},
	{0xAB, 0x00},
	{0xAC, 0xFF},
	{0xAD, 0xFF},
	{0xAE, 0xFF},
	{0xAF, 0x1F},
	{0xB0, 0x00},
	{0xB1, 0x00},
	{0xB2, 0x00},
	{0xB3, 0x00},
	{0xB4, 0x00},
	{0xB5, 0x00},
	{0xB6, 0x00},
	{0xB7, 0x00},
	{0xB8, 0x00},
	{0xB9, 0x00},
	{0xBA, 0x80},
	{0xBB, 0x00},
	{0xBC, 0x00},
	{0xBD, 0x00},
	{0xBE, 0x00},
	{0xBF, 0x00},
	{0xC0, 0x90},
	{0xC1, 0x01},
	{0xC2, 0x00},
	{0xC3, 0x00},
	{0xC4, 0x00},
	{0xC5, 0x00},
	{0xC6, 0x00},
	{0xC7, 0x00},
	{0xC8, 0x00},
	{0xC9, 0x00},
	{0xCA, 0x00},
	{0xCB, 0x00},
	{0xCC, 0x55},
	{0xCD, 0x01},
	{0xCE, 0xFF},
	{0xCF, 0x00},
	{0xD0, 0x1F},
	{0xD1, 0x00},
	{0xD2, 0x00},
	{0xD3, 0x00},
	{0xD4, 0x00},
	{0xD5, 0x00},
	{0xD6, 0x00},
	{0xD7, 0x00},
	{0xD8, 0x00},
	{0xD9, 0x00},
	{0xDA, 0x00},
	{0xDB, 0x00},
	{0xDC, 0x01},
	{0xDD, 0x00},
	{0xDE, 0x00},
	{0xDF, 0x00},
	{0xE0, 0x4A},
	{0xE1, 0x1E},
	{0xE2, 0x00},
	{0xE3, 0x00},
	{0xE4, 0x20},
	{0xE5, 0x00},
	{0xE6, 0x00},
	{0xE7, 0x00},
	{0xE8, 0x00},
	{0xE9, 0x00},
	{0xEA, 0x04},
	{0xEB, 0x00},
	{0xEC, 0x00},
	{0xED, 0x00},
	{0xEE, 0x00},
	{0xEF, 0x00},
	{0xF0, 0x0B},
	{0xF1, 0x01},
	{0xF2, 0x00},
	{0xF3, 0x00},
	{0xF4, 0x44},
	{0xF5, 0x00},
	{0xF6, 0x00},
	{0xF7, 0x00},
	{0xF8, 0x0D},
	{0xF9, 0x4D},
	{0xFA, 0x01},
	{0xFB, 0x00},
	{0xFC, 0x00},
	{0xFD, 0x00},
	{0xFE, 0x00},
	{0xFF, 0x00},
	{0x100, 0x76},
	{0x101, 0x81},
	{0x102, 0x08},
	{0x103, 0xA7},
	{0x104, 0xB4},
	{0x105, 0x03},
	{0x106, 0x00},
	{0x107, 0x00},
	{0x108, 0x22},
	{0x109, 0x80},
	{0x10A, 0x08},
	{0x10B, 0x66},
	{0x10C, 0xB4},
	{0x10D, 0x03},
	{0x10E, 0x00},
	{0x10F, 0x00},
	{0x110, 0x22},
	{0x111, 0x80},
	{0x112, 0x08},
	{0x113, 0x66},
	{0x114, 0xB4},
	{0x115, 0x03},
	{0x116, 0x00},
	{0x117, 0x00},
	{0x118, 0x69},
	{0x119, 0x00},
	{0x11A, 0x0B},
	{0x11B, 0x6C},
	{0x11C, 0xB4},
	{0x11D, 0x03},
	{0x11E, 0x00},
	{0x11F, 0x00},
	{0x120, 0x00},
	{0x121, 0x00},
	{0x122, 0x50},
	{0x123, 0x00},
	{0x124, 0x00},
	{0x125, 0x00},
	{0x126, 0x70},
	{0x127, 0x00},
	{0x128, 0x00},
	{0x129, 0x00},
	{0x12A, 0x00},
	{0x12B, 0x00},
	{0x12C, 0x00},
	{0x12D, 0x00},
	{0x12E, 0x00},
	{0x12F, 0x00},
	{0x130, 0x10},
	{0x131, 0x2F},
	{0x132, 0x00},
	{0x133, 0x02},
	{0x134, 0x00},
	{0x135, 0x02},
	{0x136, 0x00},
	{0x137, 0x00},
	{0x138, 0x00},
	{0x139, 0x00},
	{0x13A, 0x00},
	{0x13B, 0x00},
	{0x13C, 0x00},
	{0x13D, 0x00},
	{0x13E, 0x00},
	{0x13F, 0x00},
	{0x140, 0x21},
	{0x141, 0x01},
	{0x142, 0x44},
	{0x143, 0x09},
	{0x144, 0x05},
	{0x145, 0x00},
	{0x146, 0x00},
	{0x147, 0x00},
	{0x148, 0x00},
	{0x149, 0x00},
	{0x14A, 0x00},
	{0x14B, 0x00},
	{0x14C, 0x00},
	{0x14D, 0x00},
	{0x14E, 0x00},
	{0x14F, 0x00},
	{0x150, 0x00},
	{0x151, 0x00},
	{0x152, 0x00},
	{0x153, 0x00},
	{0x154, 0xBB},
	{0x155, 0x00},
	{0x156, 0x23},
	{0x157, 0x0D},
	{0x158, 0x44},
	{0x159, 0x3E},
	{0x15A, 0x64},
	{0x15B, 0x27},
	{0x15C, 0x06},
	{0x15D, 0x1F},
	{0x15E, 0x45},
	{0x15F, 0x0F},
	{0x160, 0x04},
	{0x161, 0x00},
	{0x162, 0x00},
	{0x163, 0x7A},
	{0x164, 0x80},
	{0x165, 0x01},
	{0x166, 0x88},
	{0x167, 0x00},
	{0x168, 0x00},
	{0x169, 0x00},
	{0x16A, 0x00},
	{0x16B, 0x25},
	{0x16C, 0x01},
	{0x16D, 0x00},
	{0x16E, 0x01},
	{0x16F, 0x09},
	{0x170, 0x00},
	{0x171, 0x00},
	{0x172, 0x00},
	{0x173, 0x00},
	{0x174, 0x00},
	{0x175, 0x00},
	{0x176, 0x00},
	{0x177, 0x00},
	{0x178, 0x00},
	{0x179, 0x00},
	{0x17A, 0x00},
	{0x17B, 0x00},
	{0x17C, 0x00},
	{0x17D, 0x00},
	{0x17E, 0x00},
	{0x17F, 0x00},
	{0x180, 0x00},
	{0x181, 0x00},
	{0x182, 0x00},
	{0x183, 0x00},
	{0x184, 0x00},
	{0x185, 0x00},
	{0x186, 0x00},
	{0x187, 0x00},
	{0x188, 0x00},
	{0x189, 0x00},
	{0x18A, 0x00},
	{0x18B, 0x00},
	{0x18C, 0x00},
	{0x18D, 0x00},
	{0x18E, 0x00},
	{0x18F, 0x00},
	{0x190, 0x08},
	{0x191, 0x00},
	{0x192, 0x00},
	{0x193, 0x00},
	{0x194, 0x00},
	{0x195, 0x00},
	{0x196, 0x00},
	{0x197, 0x00},
	{0x198, 0x00},
	{0x199, 0x00},
	{0x19A, 0x00},
	{0x19B, 0x00},
	{0x19C, 0x00},
	{0x19D, 0x00},
	{0x19E, 0x00},
	{0x19F, 0x00},
	{0x1A0, 0x2C},
	{0x1A1, 0x3B},
	{0x1A2, 0x00},
	{0x1A3, 0x77},
	{0x1A4, 0x70},
	{0x1A5, 0x80},
	{0x1A6, 0x01},
	{0x1A7, 0x00},
	{0x1A8, 0x00},
	{0x1A9, 0x08},
	{0x1AA, 0x00},
	{0x1AB, 0x00},
	{0x1AC, 0x00},
	{0x1AD, 0x00},
	{0x1AE, 0x00},
	{0x1AF, 0x00},
	{0x1B0, 0x00},
	{0x1B1, 0x00},
	{0x1B2, 0x00},
	{0x1B3, 0x00},
	{0x1B4, 0xF0},
	{0x1B5, 0x00},
	{0x1B6, 0xD0},
	{0x1B7, 0x03},
	{0x1B8, 0x00},
	{0x1B9, 0x00},
	{0x1BA, 0x00},
	{0x1BB, 0x00},
	{0x1BC, 0xBA},
	{0x1BD, 0x00},
	{0x1BE, 0x00},
	{0x1BF, 0x00},
	{0x1C0, 0x1A},
	{0x1C1, 0xA6},
	{0x1C2, 0x0F},
	{0x1C3, 0x47},
	{0x1C4, 0x24},
	{0x1C5, 0x00},
	{0x1C6, 0x24},
	{0x1C7, 0x00},
	{0x1C8, 0x00},
	{0x1C9, 0x11},
	{0x1CA, 0x20},
	{0x1CB, 0x12},
	{0x1CC, 0x0B},
	{0x1CD, 0x10},
	{0x1CE, 0x02},
	{0x1CF, 0x30},
	{0x1D0, 0x00},
	{0x1D1, 0x00},
	{0x1D2, 0x00},
	{0x1D3, 0x00},
	{0x1D4, 0x00},
	{0x1D5, 0x00},
	{0x1D6, 0x00},
	{0x1D7, 0x00},
	{0x1D8, 0x00},
	{0x1D9, 0x00},
	{0x1DA, 0x00},
	{0x1DB, 0x00},
	{0x1DC, 0x00},
	{0x1DD, 0x00},
	{0x1DE, 0x00},
	{0x1DF, 0x00}
};

// Configuration 1 - 254.974 MHz - 7680x4320p30 / 4ppc / CVT-RBv2
prt_rc22504a_reg_struct tentiva_vid_clk_cfg1_reg[TENTIVA_VID_CLK_CONFIG_NUM_REGS] = 
{
	{0x00, 0x33},
	{0x01, 0x10},
	{0x02, 0x4A},
	{0x03, 0x20},
	{0x04, 0x32},
	{0x05, 0x02},
	{0x06, 0x00},
	{0x07, 0x00},
	{0x08, 0x04},
	{0x09, 0x00},
	{0x0A, 0x30},
	{0x0B, 0x00},
	{0x0C, 0x00},
	{0x0D, 0x00},
	{0x0E, 0x00},
	{0x0F, 0x00},
	{0x10, 0x00},
	{0x11, 0x00},
	{0x12, 0x19},
	{0x13, 0x9A},
	{0x14, 0x00},
	{0x15, 0x00},
	{0x16, 0x00},
	{0x17, 0x00},
	{0x18, 0x00},
	{0x19, 0x00},
	{0x1A, 0x00},
	{0x1B, 0xF0},
	{0x1C, 0x00},
	{0x1D, 0x00},
	{0x1E, 0x00},
	{0x1F, 0x00},
	{0x20, 0x00},
	{0x21, 0x00},
	{0x22, 0x00},
	{0x23, 0x00},
	{0x24, 0x00},
	{0x25, 0x00},
	{0x26, 0x00},
	{0x27, 0x00},
	{0x28, 0x00},
	{0x29, 0x00},
	{0x2A, 0x00},
	{0x2B, 0x00},
	{0x2C, 0x00},
	{0x2D, 0x00},
	{0x2E, 0x00},
	{0x2F, 0x00},
	{0x30, 0x03},
	{0x31, 0x01},
	{0x32, 0x00},
	{0x33, 0x00},
	{0x34, 0x01},
	{0x35, 0x00},
	{0x36, 0x00},
	{0x37, 0x00},
	{0x38, 0x00},
	{0x39, 0x00},
	{0x3A, 0x00},
	{0x3B, 0x00},
	{0x3C, 0x00},
	{0x3D, 0x00},
	{0x3E, 0x00},
	{0x3F, 0x00},
	{0x40, 0x03},
	{0x41, 0x01},
	{0x42, 0x00},
	{0x43, 0x00},
	{0x44, 0x01},
	{0x45, 0x00},
	{0x46, 0x00},
	{0x47, 0x00},
	{0x48, 0x00},
	{0x49, 0x00},
	{0x4A, 0x00},
	{0x4B, 0x00},
	{0x4C, 0x00},
	{0x4D, 0x00},
	{0x4E, 0x00},
	{0x4F, 0x00},
	{0x50, 0x03},
	{0x51, 0x01},
	{0x52, 0x00},
	{0x53, 0x00},
	{0x54, 0x01},
	{0x55, 0x00},
	{0x56, 0x00},
	{0x57, 0x00},
	{0x58, 0x00},
	{0x59, 0x00},
	{0x5A, 0x00},
	{0x5B, 0x00},
	{0x5C, 0x00},
	{0x5D, 0x00},
	{0x5E, 0x00},
	{0x5F, 0x00},
	{0x60, 0x01},
	{0x61, 0x01},
	{0x62, 0x00},
	{0x63, 0x00},
	{0x64, 0x00},
	{0x65, 0x00},
	{0x66, 0x10},
	{0x67, 0x00},
	{0x68, 0x00},
	{0x69, 0x00},
	{0x6A, 0x00},
	{0x6B, 0x00},
	{0x6C, 0x00},
	{0x6D, 0x00},
	{0x6E, 0x00},
	{0x6F, 0x00},
	{0x70, 0x00},
	{0x71, 0x00},
	{0x72, 0x00},
	{0x73, 0x00},
	{0x74, 0x00},
	{0x75, 0x00},
	{0x76, 0x00},
	{0x77, 0x00},
	{0x78, 0x00},
	{0x79, 0x00},
	{0x7A, 0x00},
	{0x7B, 0x00},
	{0x7C, 0x00},
	{0x7D, 0x00},
	{0x7E, 0x00},
	{0x7F, 0x00},
	{0x80, 0x01},
	{0x81, 0x01},
	{0x82, 0x00},
	{0x83, 0x00},
	{0x84, 0x00},
	{0x85, 0x00},
	{0x86, 0x10},
	{0x87, 0x00},
	{0x88, 0x00},
	{0x89, 0x00},
	{0x8A, 0x00},
	{0x8B, 0x00},
	{0x8C, 0x00},
	{0x8D, 0x00},
	{0x8E, 0x00},
	{0x8F, 0x00},
	{0x90, 0x00},
	{0x91, 0x00},
	{0x92, 0x00},
	{0x93, 0x00},
	{0x94, 0x00},
	{0x95, 0x00},
	{0x96, 0x00},
	{0x97, 0x00},
	{0x98, 0x00},
	{0x99, 0x00},
	{0x9A, 0x00},
	{0x9B, 0x00},
	{0x9C, 0x00},
	{0x9D, 0x00},
	{0x9E, 0x00},
	{0x9F, 0x00},
	{0xA0, 0x82},
	{0xA1, 0x83},
	{0xA2, 0x36},
	{0xA3, 0x00},
	{0xA4, 0x00},
	{0xA5, 0x38},
	{0xA6, 0x42},
	{0xA7, 0x5B},
	{0xA8, 0x10},
	{0xA9, 0x11},
	{0xAA, 0x00},
	{0xAB, 0x00},
	{0xAC, 0xFF},
	{0xAD, 0xFF},
	{0xAE, 0xFF},
	{0xAF, 0x1F},
	{0xB0, 0x00},
	{0xB1, 0x00},
	{0xB2, 0x00},
	{0xB3, 0x00},
	{0xB4, 0x00},
	{0xB5, 0x00},
	{0xB6, 0x00},
	{0xB7, 0x00},
	{0xB8, 0x00},
	{0xB9, 0x00},
	{0xBA, 0x80},
	{0xBB, 0x00},
	{0xBC, 0x00},
	{0xBD, 0x00},
	{0xBE, 0x00},
	{0xBF, 0x00},
	{0xC0, 0x90},
	{0xC1, 0x01},
	{0xC2, 0x00},
	{0xC3, 0x00},
	{0xC4, 0x00},
	{0xC5, 0x00},
	{0xC6, 0x00},
	{0xC7, 0x00},
	{0xC8, 0x00},
	{0xC9, 0x00},
	{0xCA, 0x00},
	{0xCB, 0x00},
	{0xCC, 0x55},
	{0xCD, 0x01},
	{0xCE, 0xFF},
	{0xCF, 0x00},
	{0xD0, 0x1F},
	{0xD1, 0x00},
	{0xD2, 0x00},
	{0xD3, 0x00},
	{0xD4, 0x00},
	{0xD5, 0x00},
	{0xD6, 0x00},
	{0xD7, 0x00},
	{0xD8, 0x00},
	{0xD9, 0x00},
	{0xDA, 0x00},
	{0xDB, 0x00},
	{0xDC, 0x01},
	{0xDD, 0x00},
	{0xDE, 0x00},
	{0xDF, 0x00},
	{0xE0, 0x4A},
	{0xE1, 0x1E},
	{0xE2, 0x00},
	{0xE3, 0x00},
	{0xE4, 0x20},
	{0xE5, 0x00},
	{0xE6, 0x00},
	{0xE7, 0x00},
	{0xE8, 0x00},
	{0xE9, 0x00},
	{0xEA, 0x04},
	{0xEB, 0x00},
	{0xEC, 0x00},
	{0xED, 0x00},
	{0xEE, 0x00},
	{0xEF, 0x00},
	{0xF0, 0x0B},
	{0xF1, 0x01},
	{0xF2, 0x00},
	{0xF3, 0x00},
	{0xF4, 0x44},
	{0xF5, 0x00},
	{0xF6, 0x00},
	{0xF7, 0x00},
	{0xF8, 0x0D},
	{0xF9, 0x4D},
	{0xFA, 0x01},
	{0xFB, 0x00},
	{0xFC, 0x00},
	{0xFD, 0x00},
	{0xFE, 0x00},
	{0xFF, 0x00},
	{0x100, 0x69},
	{0x101, 0x00},
	{0x102, 0x0B},
	{0x103, 0xA7},
	{0x104, 0xB4},
	{0x105, 0x03},
	{0x106, 0x00},
	{0x107, 0x00},
	{0x108, 0x28},
	{0x109, 0x80},
	{0x10A, 0x08},
	{0x10B, 0x66},
	{0x10C, 0xB4},
	{0x10D, 0x03},
	{0x10E, 0x00},
	{0x10F, 0x00},
	{0x110, 0x28},
	{0x111, 0x80},
	{0x112, 0x08},
	{0x113, 0x66},
	{0x114, 0xB4},
	{0x115, 0x03},
	{0x116, 0x00},
	{0x117, 0x00},
	{0x118, 0x69},
	{0x119, 0x00},
	{0x11A, 0x0B},
	{0x11B, 0x6C},
	{0x11C, 0xB4},
	{0x11D, 0x03},
	{0x11E, 0x00},
	{0x11F, 0x00},
	{0x120, 0x00},
	{0x121, 0x00},
	{0x122, 0x70},
	{0x123, 0x00},
	{0x124, 0x00},
	{0x125, 0x00},
	{0x126, 0x70},
	{0x127, 0x00},
	{0x128, 0x00},
	{0x129, 0x00},
	{0x12A, 0x00},
	{0x12B, 0x00},
	{0x12C, 0x00},
	{0x12D, 0x00},
	{0x12E, 0x00},
	{0x12F, 0x00},
	{0x130, 0x10},
	{0x131, 0x2F},
	{0x132, 0x00},
	{0x133, 0x02},
	{0x134, 0x00},
	{0x135, 0x02},
	{0x136, 0x00},
	{0x137, 0x00},
	{0x138, 0x00},
	{0x139, 0x00},
	{0x13A, 0x00},
	{0x13B, 0x00},
	{0x13C, 0x00},
	{0x13D, 0x00},
	{0x13E, 0x00},
	{0x13F, 0x00},
	{0x140, 0x21},
	{0x141, 0x06},
	{0x142, 0x44},
	{0x143, 0x09},
	{0x144, 0x05},
	{0x145, 0x00},
	{0x146, 0x00},
	{0x147, 0x00},
	{0x148, 0x00},
	{0x149, 0x00},
	{0x14A, 0x00},
	{0x14B, 0x00},
	{0x14C, 0x00},
	{0x14D, 0x00},
	{0x14E, 0x00},
	{0x14F, 0x00},
	{0x150, 0x61},
	{0x151, 0x00},
	{0x152, 0xF5},
	{0x153, 0x06},
	{0x154, 0xBC},
	{0x155, 0x00},
	{0x156, 0x23},
	{0x157, 0x0D},
	{0x158, 0x44},
	{0x159, 0x3E},
	{0x15A, 0x64},
	{0x15B, 0x27},
	{0x15C, 0x06},
	{0x15D, 0x1F},
	{0x15E, 0x45},
	{0x15F, 0x0F},
	{0x160, 0x04},
	{0x161, 0x00},
	{0x162, 0x00},
	{0x163, 0x7A},
	{0x164, 0x80},
	{0x165, 0x01},
	{0x166, 0x88},
	{0x167, 0x00},
	{0x168, 0x00},
	{0x169, 0x00},
	{0x16A, 0x00},
	{0x16B, 0x25},
	{0x16C, 0x01},
	{0x16D, 0x00},
	{0x16E, 0x01},
	{0x16F, 0x09},
	{0x170, 0x00},
	{0x171, 0x00},
	{0x172, 0x00},
	{0x173, 0x00},
	{0x174, 0x00},
	{0x175, 0x00},
	{0x176, 0x00},
	{0x177, 0x00},
	{0x178, 0x00},
	{0x179, 0x00},
	{0x17A, 0x00},
	{0x17B, 0x00},
	{0x17C, 0x00},
	{0x17D, 0x00},
	{0x17E, 0x00},
	{0x17F, 0x00},
	{0x180, 0x00},
	{0x181, 0x00},
	{0x182, 0x00},
	{0x183, 0x00},
	{0x184, 0x00},
	{0x185, 0x00},
	{0x186, 0x00},
	{0x187, 0x00},
	{0x188, 0x00},
	{0x189, 0x00},
	{0x18A, 0x00},
	{0x18B, 0x00},
	{0x18C, 0x00},
	{0x18D, 0x00},
	{0x18E, 0x00},
	{0x18F, 0x00},
	{0x190, 0x00},
	{0x191, 0x00},
	{0x192, 0x00},
	{0x193, 0x00},
	{0x194, 0x00},
	{0x195, 0x00},
	{0x196, 0x00},
	{0x197, 0x00},
	{0x198, 0x00},
	{0x199, 0x00},
	{0x19A, 0x00},
	{0x19B, 0x00},
	{0x19C, 0x00},
	{0x19D, 0x00},
	{0x19E, 0x00},
	{0x19F, 0x00},
	{0x1A0, 0x2C},
	{0x1A1, 0x3B},
	{0x1A2, 0x00},
	{0x1A3, 0x77},
	{0x1A4, 0x70},
	{0x1A5, 0x80},
	{0x1A6, 0x01},
	{0x1A7, 0x00},
	{0x1A8, 0x00},
	{0x1A9, 0x08},
	{0x1AA, 0x00},
	{0x1AB, 0x00},
	{0x1AC, 0x00},
	{0x1AD, 0x00},
	{0x1AE, 0x00},
	{0x1AF, 0x00},
	{0x1B0, 0x00},
	{0x1B1, 0x00},
	{0x1B2, 0x00},
	{0x1B3, 0x00},
	{0x1B4, 0xF0},
	{0x1B5, 0x00},
	{0x1B6, 0xD0},
	{0x1B7, 0x03},
	{0x1B8, 0x00},
	{0x1B9, 0x00},
	{0x1BA, 0x00},
	{0x1BB, 0x00},
	{0x1BC, 0xBA},
	{0x1BD, 0x00},
	{0x1BE, 0x00},
	{0x1BF, 0x00},
	{0x1C0, 0x1A},
	{0x1C1, 0xA6},
	{0x1C2, 0x0F},
	{0x1C3, 0x47},
	{0x1C4, 0x24},
	{0x1C5, 0x00},
	{0x1C6, 0x24},
	{0x1C7, 0x00},
	{0x1C8, 0x00},
	{0x1C9, 0x11},
	{0x1CA, 0x20},
	{0x1CB, 0x12},
	{0x1CC, 0x0B},
	{0x1CD, 0x10},
	{0x1CE, 0x02},
	{0x1CF, 0x30},
	{0x1D0, 0x00},
	{0x1D1, 0x00},
	{0x1D2, 0x00},
	{0x1D3, 0x00},
	{0x1D4, 0x00},
	{0x1D5, 0x00},
	{0x1D6, 0x00},
	{0x1D7, 0x00},
	{0x1D8, 0x00},
	{0x1D9, 0x00},
	{0x1DA, 0x00},
	{0x1DB, 0x00},
	{0x1DC, 0x00},
	{0x1DD, 0x00},
	{0x1DE, 0x00},
	{0x1DF, 0x00}
};

// Configuration 2 - 231.036 MHz / 5120x2880p60 / 4ppc / CVT-RBv2
prt_rc22504a_reg_struct tentiva_vid_clk_cfg2_reg[TENTIVA_VID_CLK_CONFIG_NUM_REGS] = 
{
	{0x00, 0x33},
	{0x01, 0x10},
	{0x02, 0x4A},
	{0x03, 0x20},
	{0x04, 0x32},
	{0x05, 0x02},
	{0x06, 0x00},
	{0x07, 0x00},
	{0x08, 0x04},
	{0x09, 0x00},
	{0x0A, 0x30},
	{0x0B, 0x00},
	{0x0C, 0x00},
	{0x0D, 0x00},
	{0x0E, 0x00},
	{0x0F, 0x00},
	{0x10, 0x00},
	{0x11, 0x00},
	{0x12, 0x19},
	{0x13, 0x9A},
	{0x14, 0x00},
	{0x15, 0x00},
	{0x16, 0x00},
	{0x17, 0x00},
	{0x18, 0x00},
	{0x19, 0x00},
	{0x1A, 0x00},
	{0x1B, 0xF0},
	{0x1C, 0x00},
	{0x1D, 0x00},
	{0x1E, 0x00},
	{0x1F, 0x00},
	{0x20, 0x00},
	{0x21, 0x00},
	{0x22, 0x00},
	{0x23, 0x00},
	{0x24, 0x00},
	{0x25, 0x00},
	{0x26, 0x00},
	{0x27, 0x00},
	{0x28, 0x00},
	{0x29, 0x00},
	{0x2A, 0x00},
	{0x2B, 0x00},
	{0x2C, 0x00},
	{0x2D, 0x00},
	{0x2E, 0x00},
	{0x2F, 0x00},
	{0x30, 0x03},
	{0x31, 0x01},
	{0x32, 0x00},
	{0x33, 0x00},
	{0x34, 0x01},
	{0x35, 0x00},
	{0x36, 0x00},
	{0x37, 0x00},
	{0x38, 0x00},
	{0x39, 0x00},
	{0x3A, 0x00},
	{0x3B, 0x00},
	{0x3C, 0x00},
	{0x3D, 0x00},
	{0x3E, 0x00},
	{0x3F, 0x00},
	{0x40, 0x03},
	{0x41, 0x01},
	{0x42, 0x00},
	{0x43, 0x00},
	{0x44, 0x01},
	{0x45, 0x00},
	{0x46, 0x00},
	{0x47, 0x00},
	{0x48, 0x00},
	{0x49, 0x00},
	{0x4A, 0x00},
	{0x4B, 0x00},
	{0x4C, 0x00},
	{0x4D, 0x00},
	{0x4E, 0x00},
	{0x4F, 0x00},
	{0x50, 0x03},
	{0x51, 0x01},
	{0x52, 0x00},
	{0x53, 0x00},
	{0x54, 0x01},
	{0x55, 0x00},
	{0x56, 0x00},
	{0x57, 0x00},
	{0x58, 0x00},
	{0x59, 0x00},
	{0x5A, 0x00},
	{0x5B, 0x00},
	{0x5C, 0x00},
	{0x5D, 0x00},
	{0x5E, 0x00},
	{0x5F, 0x00},
	{0x60, 0x01},
	{0x61, 0x01},
	{0x62, 0x00},
	{0x63, 0x00},
	{0x64, 0x00},
	{0x65, 0x00},
	{0x66, 0x10},
	{0x67, 0x00},
	{0x68, 0x00},
	{0x69, 0x00},
	{0x6A, 0x00},
	{0x6B, 0x00},
	{0x6C, 0x00},
	{0x6D, 0x00},
	{0x6E, 0x00},
	{0x6F, 0x00},
	{0x70, 0x00},
	{0x71, 0x00},
	{0x72, 0x00},
	{0x73, 0x00},
	{0x74, 0x00},
	{0x75, 0x00},
	{0x76, 0x00},
	{0x77, 0x00},
	{0x78, 0x00},
	{0x79, 0x00},
	{0x7A, 0x00},
	{0x7B, 0x00},
	{0x7C, 0x00},
	{0x7D, 0x00},
	{0x7E, 0x00},
	{0x7F, 0x00},
	{0x80, 0x01},
	{0x81, 0x01},
	{0x82, 0x00},
	{0x83, 0x00},
	{0x84, 0x00},
	{0x85, 0x00},
	{0x86, 0x10},
	{0x87, 0x00},
	{0x88, 0x00},
	{0x89, 0x00},
	{0x8A, 0x00},
	{0x8B, 0x00},
	{0x8C, 0x00},
	{0x8D, 0x00},
	{0x8E, 0x00},
	{0x8F, 0x00},
	{0x90, 0x00},
	{0x91, 0x00},
	{0x92, 0x00},
	{0x93, 0x00},
	{0x94, 0x00},
	{0x95, 0x00},
	{0x96, 0x00},
	{0x97, 0x00},
	{0x98, 0x00},
	{0x99, 0x00},
	{0x9A, 0x00},
	{0x9B, 0x00},
	{0x9C, 0x00},
	{0x9D, 0x00},
	{0x9E, 0x00},
	{0x9F, 0x00},
	{0xA0, 0x82},
	{0xA1, 0x83},
	{0xA2, 0x36},
	{0xA3, 0x00},
	{0xA4, 0x00},
	{0xA5, 0x38},
	{0xA6, 0x42},
	{0xA7, 0x5B},
	{0xA8, 0x10},
	{0xA9, 0x11},
	{0xAA, 0x00},
	{0xAB, 0x00},
	{0xAC, 0xFF},
	{0xAD, 0xFF},
	{0xAE, 0xFF},
	{0xAF, 0x1F},
	{0xB0, 0x00},
	{0xB1, 0x00},
	{0xB2, 0x00},
	{0xB3, 0x00},
	{0xB4, 0x00},
	{0xB5, 0x00},
	{0xB6, 0x00},
	{0xB7, 0x00},
	{0xB8, 0x00},
	{0xB9, 0x00},
	{0xBA, 0x80},
	{0xBB, 0x00},
	{0xBC, 0x00},
	{0xBD, 0x00},
	{0xBE, 0x00},
	{0xBF, 0x00},
	{0xC0, 0x90},
	{0xC1, 0x01},
	{0xC2, 0x00},
	{0xC3, 0x00},
	{0xC4, 0x00},
	{0xC5, 0x00},
	{0xC6, 0x00},
	{0xC7, 0x00},
	{0xC8, 0x00},
	{0xC9, 0x00},
	{0xCA, 0x00},
	{0xCB, 0x00},
	{0xCC, 0x55},
	{0xCD, 0x01},
	{0xCE, 0xFF},
	{0xCF, 0x00},
	{0xD0, 0x1F},
	{0xD1, 0x00},
	{0xD2, 0x00},
	{0xD3, 0x00},
	{0xD4, 0x00},
	{0xD5, 0x00},
	{0xD6, 0x00},
	{0xD7, 0x00},
	{0xD8, 0x00},
	{0xD9, 0x00},
	{0xDA, 0x00},
	{0xDB, 0x00},
	{0xDC, 0x01},
	{0xDD, 0x00},
	{0xDE, 0x00},
	{0xDF, 0x00},
	{0xE0, 0x4A},
	{0xE1, 0x1E},
	{0xE2, 0x00},
	{0xE3, 0x00},
	{0xE4, 0x20},
	{0xE5, 0x00},
	{0xE6, 0x00},
	{0xE7, 0x00},
	{0xE8, 0x00},
	{0xE9, 0x00},
	{0xEA, 0x04},
	{0xEB, 0x00},
	{0xEC, 0x00},
	{0xED, 0x00},
	{0xEE, 0x00},
	{0xEF, 0x00},
	{0xF0, 0x0B},
	{0xF1, 0x01},
	{0xF2, 0x00},
	{0xF3, 0x00},
	{0xF4, 0x44},
	{0xF5, 0x00},
	{0xF6, 0x00},
	{0xF7, 0x00},
	{0xF8, 0x0D},
	{0xF9, 0x4D},
	{0xFA, 0x01},
	{0xFB, 0x00},
	{0xFC, 0x00},
	{0xFD, 0x00},
	{0xFE, 0x00},
	{0xFF, 0x00},
	{0x100, 0x69},
	{0x101, 0x00},
	{0x102, 0x0B},
	{0x103, 0xA7},
	{0x104, 0xB4},
	{0x105, 0x03},
	{0x106, 0x00},
	{0x107, 0x00},
	{0x108, 0x2C},
	{0x109, 0x80},
	{0x10A, 0x08},
	{0x10B, 0x66},
	{0x10C, 0xB4},
	{0x10D, 0x03},
	{0x10E, 0x00},
	{0x10F, 0x00},
	{0x110, 0x2C},
	{0x111, 0x80},
	{0x112, 0x08},
	{0x113, 0x66},
	{0x114, 0xB4},
	{0x115, 0x03},
	{0x116, 0x00},
	{0x117, 0x00},
	{0x118, 0x69},
	{0x119, 0x00},
	{0x11A, 0x0B},
	{0x11B, 0x6C},
	{0x11C, 0xB4},
	{0x11D, 0x03},
	{0x11E, 0x00},
	{0x11F, 0x00},
	{0x120, 0x00},
	{0x121, 0x00},
	{0x122, 0x70},
	{0x123, 0x00},
	{0x124, 0x00},
	{0x125, 0x00},
	{0x126, 0x70},
	{0x127, 0x00},
	{0x128, 0x00},
	{0x129, 0x00},
	{0x12A, 0x00},
	{0x12B, 0x00},
	{0x12C, 0x00},
	{0x12D, 0x00},
	{0x12E, 0x00},
	{0x12F, 0x00},
	{0x130, 0x10},
	{0x131, 0x2F},
	{0x132, 0x00},
	{0x133, 0x02},
	{0x134, 0x00},
	{0x135, 0x02},
	{0x136, 0x00},
	{0x137, 0x00},
	{0x138, 0x00},
	{0x139, 0x00},
	{0x13A, 0x00},
	{0x13B, 0x00},
	{0x13C, 0x00},
	{0x13D, 0x00},
	{0x13E, 0x00},
	{0x13F, 0x00},
	{0x140, 0x21},
	{0x141, 0x06},
	{0x142, 0x44},
	{0x143, 0x09},
	{0x144, 0x05},
	{0x145, 0x00},
	{0x146, 0x00},
	{0x147, 0x00},
	{0x148, 0x00},
	{0x149, 0x00},
	{0x14A, 0x00},
	{0x14B, 0x00},
	{0x14C, 0x00},
	{0x14D, 0x00},
	{0x14E, 0x00},
	{0x14F, 0x00},
	{0x150, 0x8F},
	{0x151, 0x2F},
	{0x152, 0x03},
	{0x153, 0x02},
	{0x154, 0xBC},
	{0x155, 0x00},
	{0x156, 0x23},
	{0x157, 0x0D},
	{0x158, 0x44},
	{0x159, 0x3E},
	{0x15A, 0x64},
	{0x15B, 0x27},
	{0x15C, 0x06},
	{0x15D, 0x1F},
	{0x15E, 0x45},
	{0x15F, 0x0F},
	{0x160, 0x04},
	{0x161, 0x00},
	{0x162, 0x00},
	{0x163, 0x7A},
	{0x164, 0x80},
	{0x165, 0x01},
	{0x166, 0x88},
	{0x167, 0x00},
	{0x168, 0x00},
	{0x169, 0x00},
	{0x16A, 0x00},
	{0x16B, 0x25},
	{0x16C, 0x01},
	{0x16D, 0x00},
	{0x16E, 0x01},
	{0x16F, 0x09},
	{0x170, 0x00},
	{0x171, 0x00},
	{0x172, 0x00},
	{0x173, 0x00},
	{0x174, 0x00},
	{0x175, 0x00},
	{0x176, 0x00},
	{0x177, 0x00},
	{0x178, 0x00},
	{0x179, 0x00},
	{0x17A, 0x00},
	{0x17B, 0x00},
	{0x17C, 0x00},
	{0x17D, 0x00},
	{0x17E, 0x00},
	{0x17F, 0x00},
	{0x180, 0x00},
	{0x181, 0x00},
	{0x182, 0x00},
	{0x183, 0x00},
	{0x184, 0x00},
	{0x185, 0x00},
	{0x186, 0x00},
	{0x187, 0x00},
	{0x188, 0x00},
	{0x189, 0x00},
	{0x18A, 0x00},
	{0x18B, 0x00},
	{0x18C, 0x00},
	{0x18D, 0x00},
	{0x18E, 0x00},
	{0x18F, 0x00},
	{0x190, 0x00},
	{0x191, 0x00},
	{0x192, 0x00},
	{0x193, 0x00},
	{0x194, 0x00},
	{0x195, 0x00},
	{0x196, 0x00},
	{0x197, 0x00},
	{0x198, 0x00},
	{0x199, 0x00},
	{0x19A, 0x00},
	{0x19B, 0x00},
	{0x19C, 0x00},
	{0x19D, 0x00},
	{0x19E, 0x00},
	{0x19F, 0x00},
	{0x1A0, 0x2C},
	{0x1A1, 0x3B},
	{0x1A2, 0x00},
	{0x1A3, 0x77},
	{0x1A4, 0x70},
	{0x1A5, 0x80},
	{0x1A6, 0x01},
	{0x1A7, 0x00},
	{0x1A8, 0x00},
	{0x1A9, 0x08},
	{0x1AA, 0x00},
	{0x1AB, 0x00},
	{0x1AC, 0x00},
	{0x1AD, 0x00},
	{0x1AE, 0x00},
	{0x1AF, 0x00},
	{0x1B0, 0x00},
	{0x1B1, 0x00},
	{0x1B2, 0x00},
	{0x1B3, 0x00},
	{0x1B4, 0xF0},
	{0x1B5, 0x00},
	{0x1B6, 0xD0},
	{0x1B7, 0x03},
	{0x1B8, 0x00},
	{0x1B9, 0x00},
	{0x1BA, 0x00},
	{0x1BB, 0x00},
	{0x1BC, 0xBA},
	{0x1BD, 0x00},
	{0x1BE, 0x00},
	{0x1BF, 0x00},
	{0x1C0, 0x1A},
	{0x1C1, 0xA6},
	{0x1C2, 0x0F},
	{0x1C3, 0x47},
	{0x1C4, 0x24},
	{0x1C5, 0x00},
	{0x1C6, 0x24},
	{0x1C7, 0x00},
	{0x1C8, 0x00},
	{0x1C9, 0x11},
	{0x1CA, 0x20},
	{0x1CB, 0x12},
	{0x1CC, 0x0B},
	{0x1CD, 0x10},
	{0x1CE, 0x02},
	{0x1CF, 0x30},
	{0x1D0, 0x00},
	{0x1D1, 0x00},
	{0x1D2, 0x00},
	{0x1D3, 0x00},
	{0x1D4, 0x00},
	{0x1D5, 0x00},
	{0x1D6, 0x00},
	{0x1D7, 0x00},
	{0x1D8, 0x00},
	{0x1D9, 0x00},
	{0x1DA, 0x00},
	{0x1DB, 0x00},
	{0x1DC, 0x00},
	{0x1DD, 0x00},
	{0x1DE, 0x00},
	{0x1DF, 0x00}
};

#endif
