/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: PHY Intel Cyclone / Arria 10GX Driver
    (c) 2023 - 2024 by Parretto B.V.

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

// Includes
#include "prt_types.h"
#include "prt_pio.h"
#include "prt_tmr.h"
#include "prt_phy_int_10gx.h"
#include "prt_printf.h"

// PHY TX PLL configuration data
prt_u32 altera_xcvr_atx_pll_a10_ram_array[4][22] = {

  	// Configuration 1.62 Gbps
  	{
		0x102FFB5, /* [25:16]-DPRIO address=0x102; [15:8]-bit mask=0xFF; [7:5]-atx_pll_tank_voltage_fine=vreg_setting5(3'h5); [4:3]-atx_pll_tank_sel=lctank2(2'h2); [2:0]-atx_pll_tank_band=lc_band5(3'h5); */
		0x103BF21, /* [25:16]-DPRIO address=0x103; [15:8]-bit mask=0xBF; [7:7]-atx_pll_vco_bypass_enable=false(1'h0); [5:5]-atx_pll_cp_compensation_enable=true(1'h1); [4:2]-atx_pll_cp_testmode=cp_normal(3'h0); [1:1]-atx_pll_dsm_ecn_test_en=false(1'h0); [0:0]-atx_pll_lc_mode=lccmu_normal(1'h1); */
		0x1047F45, /* [25:16]-DPRIO address=0x104; [15:8]-bit mask=0x7F; [6:4]-atx_pll_cp_current_setting=cp_current_setting33(3'h4); [3:2]-atx_pll_lf_ripplecap=lf_ripple_cap_0(2'h1); [1:0]-atx_pll_lf_resistance=lf_setting1(2'h1); */
		0x1054705, /* [25:16]-DPRIO address=0x105; [15:8]-bit mask=0x47; [6:6]-atx_pll_l_counter_enable=true(1'h0); [2:0]-atx_pll_cp_current_setting=cp_current_setting33(3'h5); */
		0x1063F30, /* [25:16]-DPRIO address=0x106; [15:8]-bit mask=0x3F; [5:4]-atx_pll_lf_cbig_size=lf_cbig_setting4(2'h3); [3:2]-atx_pll_cp_lf_3rd_pole_freq=lf_3rd_pole_setting0(2'h0); [1:1]-atx_pll_cp_lf_order=lf_3rd_order(1'h0); [0:0]-atx_pll_regulator_bypass=reg_enable(1'h0); */
		0x1073C00, /* [25:16]-DPRIO address=0x107; [15:8]-bit mask=0x3C; [5:5]-atx_pll_enable_hclk=hclk_disabled(1'h0); [4:4]-atx_pll_dsm_mode=dsm_mode_integer(1'h0); [3:2]-atx_pll_ref_clk_div=1(2'h0); */
		0x1087F0C, /* [25:16]-DPRIO address=0x108; [15:8]-bit mask=0x7F; [6:5]-atx_pll_lc_to_fpll_l_counter=lcounter_setting0(2'h0); [4:4]-atx_pll_fpll_refclk_selection=select_vco_output(1'h0); [3:3]-atx_pll_d2a_voltage=d2a_setting_4(1'h1); [2:0]-atx_pll_l_counter=16(3'h4); */
		0x109FF30, /* [25:16]-DPRIO address=0x109; [15:8]-bit mask=0xFF; [7:0]-atx_pll_m_counter=48(8'h30); */
		0x10A7F04, /* [25:16]-DPRIO address=0x10A; [15:8]-bit mask=0x7F; [6:6]-atx_pll_cascadeclk_test=cascadetest_off(1'h0); [5:3]-atx_pll_lc_to_fpll_l_counter=lcounter_setting0(3'h0); [2:0]-atx_pll_underrange_voltage=under_setting4(3'h4); */
		0x10BE100, /* [25:16]-DPRIO address=0x10B; [15:8]-bit mask=0xE1; [7:7]-atx_pll_dsm_ecn_bypass=false(1'h0); [6:5]-atx_pll_dsm_out_sel=pll_dsm_disable(2'h0); [0:0]-atx_pll_xcpvco_xchgpmplf_cp_current_boost=normal_setting(1'h0); */
		0x10CFF01, /* [25:16]-DPRIO address=0x10C; [15:8]-bit mask=0xFF; [7:0]-atx_pll_dsm_fractional_division=1(8'h1); */
		0x10DFF00, /* [25:16]-DPRIO address=0x10D; [15:8]-bit mask=0xFF; [7:0]-atx_pll_dsm_fractional_division=1(8'h0); */
		0x10EFF00, /* [25:16]-DPRIO address=0x10E; [15:8]-bit mask=0xFF; [7:0]-atx_pll_dsm_fractional_division=1(8'h0); */
		0x10FFF00, /* [25:16]-DPRIO address=0x10F; [15:8]-bit mask=0xFF; [7:0]-atx_pll_dsm_fractional_division=1(8'h0); */
		0x1103D15, /* [25:16]-DPRIO address=0x110; [15:8]-bit mask=0x3D; [5:3]-atx_pll_iqclk_mux_sel=iqtxrxclk0(3'h2); [2:2]-atx_pll_fb_select=direct_fb(1'h1); [0:0]-atx_pll_dsm_fractional_value_ready=pll_k_ready(1'h1); */
		0x1117000, /* [25:16]-DPRIO address=0x111; [15:8]-bit mask=0x70; [6:4]-atx_pll_overrange_voltage=over_setting0(3'h0); */
		0x118C0C0, /* [25:16]-DPRIO address=0x118; [15:8]-bit mask=0xC0; [7:6]-atx_pll_lf_cbig_size=lf_cbig_setting4(2'h3); */
		0x11AE080, /* [25:16]-DPRIO address=0x11A; [15:8]-bit mask=0xE0; [7:5]-atx_pll_d2a_voltage=d2a_setting_4(3'h4); */
		0x11BC000, /* [25:16]-DPRIO address=0x11B; [15:8]-bit mask=0xC0; [7:6]-atx_pll_pfd_delay_compensation=normal_delay(2'h0); */
		0x11CE000, /* [25:16]-DPRIO address=0x11C; [15:8]-bit mask=0xE0; [7:5]-atx_pll_tank_voltage_coarse=vreg_setting_coarse0(3'h0); */
		0x11DE000, /* [25:16]-DPRIO address=0x11D; [15:8]-bit mask=0xE0; [7:5]-atx_pll_output_regulator_supply=vreg1v_setting0(3'h0); */
		0x11F6000  /* [25:16]-DPRIO address=0x11F; [15:8]-bit mask=0x60; [6:5]-atx_pll_pfd_pulse_width=pulse_width_setting0(2'h0); */
  	},

  	// Configuration 2.7 Gbps
	{
		0x102FFAA, /* [25:16]-DPRIO address=0x102; [15:8]-bit mask=0xFF; [7:5]-atx_pll_tank_voltage_fine=vreg_setting5(3'h5); [4:3]-atx_pll_tank_sel=lctank1(2'h1); [2:0]-atx_pll_tank_band=lc_band2(3'h2); */
		0x103BF21, /* [25:16]-DPRIO address=0x103; [15:8]-bit mask=0xBF; [7:7]-atx_pll_vco_bypass_enable=false(1'h0); [5:5]-atx_pll_cp_compensation_enable=true(1'h1); [4:2]-atx_pll_cp_testmode=cp_normal(3'h0); [1:1]-atx_pll_dsm_ecn_test_en=false(1'h0); [0:0]-atx_pll_lc_mode=lccmu_normal(1'h1); */
		0x1047F35, /* [25:16]-DPRIO address=0x104; [15:8]-bit mask=0x7F; [6:4]-atx_pll_cp_current_setting=cp_current_setting26(3'h3); [3:2]-atx_pll_lf_ripplecap=lf_ripple_cap_0(2'h1); [1:0]-atx_pll_lf_resistance=lf_setting1(2'h1); */
		0x1054705, /* [25:16]-DPRIO address=0x105; [15:8]-bit mask=0x47; [6:6]-atx_pll_l_counter_enable=true(1'h0); [2:0]-atx_pll_cp_current_setting=cp_current_setting26(3'h5); */
		0x1063F34, /* [25:16]-DPRIO address=0x106; [15:8]-bit mask=0x3F; [5:4]-atx_pll_lf_cbig_size=lf_cbig_setting4(2'h3); [3:2]-atx_pll_cp_lf_3rd_pole_freq=lf_3rd_pole_setting1(2'h1); [1:1]-atx_pll_cp_lf_order=lf_3rd_order(1'h0); [0:0]-atx_pll_regulator_bypass=reg_enable(1'h0); */
		0x1073C00, /* [25:16]-DPRIO address=0x107; [15:8]-bit mask=0x3C; [5:5]-atx_pll_enable_hclk=hclk_disabled(1'h0); [4:4]-atx_pll_dsm_mode=dsm_mode_integer(1'h0); [3:2]-atx_pll_ref_clk_div=1(2'h0); */
		0x1087F0B, /* [25:16]-DPRIO address=0x108; [15:8]-bit mask=0x7F; [6:5]-atx_pll_lc_to_fpll_l_counter=lcounter_setting0(2'h0); [4:4]-atx_pll_fpll_refclk_selection=select_vco_output(1'h0); [3:3]-atx_pll_d2a_voltage=d2a_setting_4(1'h1); [2:0]-atx_pll_l_counter=8(3'h3); */
		0x109FF28, /* [25:16]-DPRIO address=0x109; [15:8]-bit mask=0xFF; [7:0]-atx_pll_m_counter=40(8'h28); */
		0x10A7F04, /* [25:16]-DPRIO address=0x10A; [15:8]-bit mask=0x7F; [6:6]-atx_pll_cascadeclk_test=cascadetest_off(1'h0); [5:3]-atx_pll_lc_to_fpll_l_counter=lcounter_setting0(3'h0); [2:0]-atx_pll_underrange_voltage=under_setting4(3'h4); */
		0x10BE100, /* [25:16]-DPRIO address=0x10B; [15:8]-bit mask=0xE1; [7:7]-atx_pll_dsm_ecn_bypass=false(1'h0); [6:5]-atx_pll_dsm_out_sel=pll_dsm_disable(2'h0); [0:0]-atx_pll_xcpvco_xchgpmplf_cp_current_boost=normal_setting(1'h0); */
		0x10CFF01, /* [25:16]-DPRIO address=0x10C; [15:8]-bit mask=0xFF; [7:0]-atx_pll_dsm_fractional_division=1(8'h1); */
		0x10DFF00, /* [25:16]-DPRIO address=0x10D; [15:8]-bit mask=0xFF; [7:0]-atx_pll_dsm_fractional_division=1(8'h0); */
		0x10EFF00, /* [25:16]-DPRIO address=0x10E; [15:8]-bit mask=0xFF; [7:0]-atx_pll_dsm_fractional_division=1(8'h0); */
		0x10FFF00, /* [25:16]-DPRIO address=0x10F; [15:8]-bit mask=0xFF; [7:0]-atx_pll_dsm_fractional_division=1(8'h0); */
		0x1103D15, /* [25:16]-DPRIO address=0x110; [15:8]-bit mask=0x3D; [5:3]-atx_pll_iqclk_mux_sel=iqtxrxclk0(3'h2); [2:2]-atx_pll_fb_select=direct_fb(1'h1); [0:0]-atx_pll_dsm_fractional_value_ready=pll_k_ready(1'h1); */
		0x1117000, /* [25:16]-DPRIO address=0x111; [15:8]-bit mask=0x70; [6:4]-atx_pll_overrange_voltage=over_setting0(3'h0); */
		0x118C0C0, /* [25:16]-DPRIO address=0x118; [15:8]-bit mask=0xC0; [7:6]-atx_pll_lf_cbig_size=lf_cbig_setting4(2'h3); */
		0x11AE080, /* [25:16]-DPRIO address=0x11A; [15:8]-bit mask=0xE0; [7:5]-atx_pll_d2a_voltage=d2a_setting_4(3'h4); */
		0x11BC000, /* [25:16]-DPRIO address=0x11B; [15:8]-bit mask=0xC0; [7:6]-atx_pll_pfd_delay_compensation=normal_delay(2'h0); */
		0x11CE000, /* [25:16]-DPRIO address=0x11C; [15:8]-bit mask=0xE0; [7:5]-atx_pll_tank_voltage_coarse=vreg_setting_coarse0(3'h0); */
		0x11DE000, /* [25:16]-DPRIO address=0x11D; [15:8]-bit mask=0xE0; [7:5]-atx_pll_output_regulator_supply=vreg1v_setting0(3'h0); */
		0x11F6000  /* [25:16]-DPRIO address=0x11F; [15:8]-bit mask=0x60; [6:5]-atx_pll_pfd_pulse_width=pulse_width_setting0(2'h0); */
  	},

 	// Configuration 5.4 Gbps
	{
		0x102FFAA, /* [25:16]-DPRIO address=0x102; [15:8]-bit mask=0xFF; [7:5]-atx_pll_tank_voltage_fine=vreg_setting5(3'h5); [4:3]-atx_pll_tank_sel=lctank1(2'h1); [2:0]-atx_pll_tank_band=lc_band2(3'h2); */
		0x103BF21, /* [25:16]-DPRIO address=0x103; [15:8]-bit mask=0xBF; [7:7]-atx_pll_vco_bypass_enable=false(1'h0); [5:5]-atx_pll_cp_compensation_enable=true(1'h1); [4:2]-atx_pll_cp_testmode=cp_normal(3'h0); [1:1]-atx_pll_dsm_ecn_test_en=false(1'h0); [0:0]-atx_pll_lc_mode=lccmu_normal(1'h1); */
		0x1047F35, /* [25:16]-DPRIO address=0x104; [15:8]-bit mask=0x7F; [6:4]-atx_pll_cp_current_setting=cp_current_setting26(3'h3); [3:2]-atx_pll_lf_ripplecap=lf_ripple_cap_0(2'h1); [1:0]-atx_pll_lf_resistance=lf_setting1(2'h1); */
		0x1054705, /* [25:16]-DPRIO address=0x105; [15:8]-bit mask=0x47; [6:6]-atx_pll_l_counter_enable=true(1'h0); [2:0]-atx_pll_cp_current_setting=cp_current_setting26(3'h5); */
		0x1063F34, /* [25:16]-DPRIO address=0x106; [15:8]-bit mask=0x3F; [5:4]-atx_pll_lf_cbig_size=lf_cbig_setting4(2'h3); [3:2]-atx_pll_cp_lf_3rd_pole_freq=lf_3rd_pole_setting1(2'h1); [1:1]-atx_pll_cp_lf_order=lf_3rd_order(1'h0); [0:0]-atx_pll_regulator_bypass=reg_enable(1'h0); */
		0x1073C00, /* [25:16]-DPRIO address=0x107; [15:8]-bit mask=0x3C; [5:5]-atx_pll_enable_hclk=hclk_disabled(1'h0); [4:4]-atx_pll_dsm_mode=dsm_mode_integer(1'h0); [3:2]-atx_pll_ref_clk_div=1(2'h0); */
		0x1087F0A, /* [25:16]-DPRIO address=0x108; [15:8]-bit mask=0x7F; [6:5]-atx_pll_lc_to_fpll_l_counter=lcounter_setting0(2'h0); [4:4]-atx_pll_fpll_refclk_selection=select_vco_output(1'h0); [3:3]-atx_pll_d2a_voltage=d2a_setting_4(1'h1); [2:0]-atx_pll_l_counter=4(3'h2); */
		0x109FF28, /* [25:16]-DPRIO address=0x109; [15:8]-bit mask=0xFF; [7:0]-atx_pll_m_counter=40(8'h28); */
		0x10A7F04, /* [25:16]-DPRIO address=0x10A; [15:8]-bit mask=0x7F; [6:6]-atx_pll_cascadeclk_test=cascadetest_off(1'h0); [5:3]-atx_pll_lc_to_fpll_l_counter=lcounter_setting0(3'h0); [2:0]-atx_pll_underrange_voltage=under_setting4(3'h4); */
		0x10BE100, /* [25:16]-DPRIO address=0x10B; [15:8]-bit mask=0xE1; [7:7]-atx_pll_dsm_ecn_bypass=false(1'h0); [6:5]-atx_pll_dsm_out_sel=pll_dsm_disable(2'h0); [0:0]-atx_pll_xcpvco_xchgpmplf_cp_current_boost=normal_setting(1'h0); */
		0x10CFF01, /* [25:16]-DPRIO address=0x10C; [15:8]-bit mask=0xFF; [7:0]-atx_pll_dsm_fractional_division=1(8'h1); */
		0x10DFF00, /* [25:16]-DPRIO address=0x10D; [15:8]-bit mask=0xFF; [7:0]-atx_pll_dsm_fractional_division=1(8'h0); */
		0x10EFF00, /* [25:16]-DPRIO address=0x10E; [15:8]-bit mask=0xFF; [7:0]-atx_pll_dsm_fractional_division=1(8'h0); */
		0x10FFF00, /* [25:16]-DPRIO address=0x10F; [15:8]-bit mask=0xFF; [7:0]-atx_pll_dsm_fractional_division=1(8'h0); */
		0x1103D15, /* [25:16]-DPRIO address=0x110; [15:8]-bit mask=0x3D; [5:3]-atx_pll_iqclk_mux_sel=iqtxrxclk0(3'h2); [2:2]-atx_pll_fb_select=direct_fb(1'h1); [0:0]-atx_pll_dsm_fractional_value_ready=pll_k_ready(1'h1); */
		0x1117000, /* [25:16]-DPRIO address=0x111; [15:8]-bit mask=0x70; [6:4]-atx_pll_overrange_voltage=over_setting0(3'h0); */
		0x118C0C0, /* [25:16]-DPRIO address=0x118; [15:8]-bit mask=0xC0; [7:6]-atx_pll_lf_cbig_size=lf_cbig_setting4(2'h3); */
		0x11AE080, /* [25:16]-DPRIO address=0x11A; [15:8]-bit mask=0xE0; [7:5]-atx_pll_d2a_voltage=d2a_setting_4(3'h4); */
		0x11BC000, /* [25:16]-DPRIO address=0x11B; [15:8]-bit mask=0xC0; [7:6]-atx_pll_pfd_delay_compensation=normal_delay(2'h0); */
		0x11CE000, /* [25:16]-DPRIO address=0x11C; [15:8]-bit mask=0xE0; [7:5]-atx_pll_tank_voltage_coarse=vreg_setting_coarse0(3'h0); */
		0x11DE000, /* [25:16]-DPRIO address=0x11D; [15:8]-bit mask=0xE0; [7:5]-atx_pll_output_regulator_supply=vreg1v_setting0(3'h0); */
		0x11F6000  /* [25:16]-DPRIO address=0x11F; [15:8]-bit mask=0x60; [6:5]-atx_pll_pfd_pulse_width=pulse_width_setting0(2'h0); */
	},

 	// Configuration 8.1 Gbps
	{
		0x102FFA3, /* [25:16]-DPRIO address=0x102; [15:8]-bit mask=0xFF; [7:5]-atx_pll_tank_voltage_fine=vreg_setting5(3'h5); [4:3]-atx_pll_tank_sel=lctank0(2'h0); [2:0]-atx_pll_tank_band=lc_band3(3'h3); */
		0x103BF21, /* [25:16]-DPRIO address=0x103; [15:8]-bit mask=0xBF; [7:7]-atx_pll_vco_bypass_enable=false(1'h0); [5:5]-atx_pll_cp_compensation_enable=true(1'h1); [4:2]-atx_pll_cp_testmode=cp_normal(3'h0); [1:1]-atx_pll_dsm_ecn_test_en=false(1'h0); [0:0]-atx_pll_lc_mode=lccmu_normal(1'h1); */
		0x1047F34, /* [25:16]-DPRIO address=0x104; [15:8]-bit mask=0x7F; [6:4]-atx_pll_cp_current_setting=cp_current_setting25(3'h3); [3:2]-atx_pll_lf_ripplecap=lf_ripple_cap_0(2'h1); [1:0]-atx_pll_lf_resistance=lf_setting0(2'h0); */
		0x1054704, /* [25:16]-DPRIO address=0x105; [15:8]-bit mask=0x47; [6:6]-atx_pll_l_counter_enable=true(1'h0); [2:0]-atx_pll_cp_current_setting=cp_current_setting25(3'h4); */
		0x1063F34, /* [25:16]-DPRIO address=0x106; [15:8]-bit mask=0x3F; [5:4]-atx_pll_lf_cbig_size=lf_cbig_setting4(2'h3); [3:2]-atx_pll_cp_lf_3rd_pole_freq=lf_3rd_pole_setting1(2'h1); [1:1]-atx_pll_cp_lf_order=lf_3rd_order(1'h0); [0:0]-atx_pll_regulator_bypass=reg_enable(1'h0); */
		0x1073C00, /* [25:16]-DPRIO address=0x107; [15:8]-bit mask=0x3C; [5:5]-atx_pll_enable_hclk=hclk_disabled(1'h0); [4:4]-atx_pll_dsm_mode=dsm_mode_integer(1'h0); [3:2]-atx_pll_ref_clk_div=1(2'h0); */
		0x1087F09, /* [25:16]-DPRIO address=0x108; [15:8]-bit mask=0x7F; [6:5]-atx_pll_lc_to_fpll_l_counter=lcounter_setting0(2'h0); [4:4]-atx_pll_fpll_refclk_selection=select_vco_output(1'h0); [3:3]-atx_pll_d2a_voltage=d2a_setting_4(1'h1); [2:0]-atx_pll_l_counter=2(3'h1); */
		0x109FF1E, /* [25:16]-DPRIO address=0x109; [15:8]-bit mask=0xFF; [7:0]-atx_pll_m_counter=30(8'h1E); */
		0x10A7F04, /* [25:16]-DPRIO address=0x10A; [15:8]-bit mask=0x7F; [6:6]-atx_pll_cascadeclk_test=cascadetest_off(1'h0); [5:3]-atx_pll_lc_to_fpll_l_counter=lcounter_setting0(3'h0); [2:0]-atx_pll_underrange_voltage=under_setting4(3'h4); */
		0x10BE100, /* [25:16]-DPRIO address=0x10B; [15:8]-bit mask=0xE1; [7:7]-atx_pll_dsm_ecn_bypass=false(1'h0); [6:5]-atx_pll_dsm_out_sel=pll_dsm_disable(2'h0); [0:0]-atx_pll_xcpvco_xchgpmplf_cp_current_boost=normal_setting(1'h0); */
		0x10CFF01, /* [25:16]-DPRIO address=0x10C; [15:8]-bit mask=0xFF; [7:0]-atx_pll_dsm_fractional_division=1(8'h1); */
		0x10DFF00, /* [25:16]-DPRIO address=0x10D; [15:8]-bit mask=0xFF; [7:0]-atx_pll_dsm_fractional_division=1(8'h0); */
		0x10EFF00, /* [25:16]-DPRIO address=0x10E; [15:8]-bit mask=0xFF; [7:0]-atx_pll_dsm_fractional_division=1(8'h0); */
		0x10FFF00, /* [25:16]-DPRIO address=0x10F; [15:8]-bit mask=0xFF; [7:0]-atx_pll_dsm_fractional_division=1(8'h0); */
		0x1103D15, /* [25:16]-DPRIO address=0x110; [15:8]-bit mask=0x3D; [5:3]-atx_pll_iqclk_mux_sel=iqtxrxclk0(3'h2); [2:2]-atx_pll_fb_select=direct_fb(1'h1); [0:0]-atx_pll_dsm_fractional_value_ready=pll_k_ready(1'h1); */
		0x1117000, /* [25:16]-DPRIO address=0x111; [15:8]-bit mask=0x70; [6:4]-atx_pll_overrange_voltage=over_setting0(3'h0); */
		0x118C0C0, /* [25:16]-DPRIO address=0x118; [15:8]-bit mask=0xC0; [7:6]-atx_pll_lf_cbig_size=lf_cbig_setting4(2'h3); */
		0x11AE080, /* [25:16]-DPRIO address=0x11A; [15:8]-bit mask=0xE0; [7:5]-atx_pll_d2a_voltage=d2a_setting_4(3'h4); */
		0x11BC000, /* [25:16]-DPRIO address=0x11B; [15:8]-bit mask=0xC0; [7:6]-atx_pll_pfd_delay_compensation=normal_delay(2'h0); */
		0x11CE000, /* [25:16]-DPRIO address=0x11C; [15:8]-bit mask=0xE0; [7:5]-atx_pll_tank_voltage_coarse=vreg_setting_coarse0(3'h0); */
		0x11DE000, /* [25:16]-DPRIO address=0x11D; [15:8]-bit mask=0xE0; [7:5]-atx_pll_output_regulator_supply=vreg1v_setting0(3'h0); */
		0x11F6000  /* [25:16]-DPRIO address=0x11F; [15:8]-bit mask=0x60; [6:5]-atx_pll_pfd_pulse_width=pulse_width_setting0(2'h0); */
	}
};

// PHY XCVR configuration data
// The configuration data is generated by the Transceiver Native PHY wizard.
// We are only dynamically changing the line rate. The rest of the PHY features are not changing.
// In the tab 'Dynamic Reconfiguration' select the option 'Generate C header file'. 
prt_u32 altera_xcvr_native_a10_ram_array[4][13] = {
	
	// Configuration 1.62 Gbps
	{
		0x132F7B6, /* [25:16]-DPRIO address=0x132; [15:8]-bit mask=0xF7; [7:6]-cdr_pll_set_cdr_vco_speed_pciegen3=cdr_vco_max_speedbin_pciegen3(2'h2); [5:4]-cdr_pll_reverse_serial_loopback=no_loopback(2'h3); [2:2]-cdr_pll_set_cdr_vco_speed_fix=74(1'h1); [1:1]-cdr_pll_cdr_powerdown_mode=power_up(1'h1); [0:0]-cdr_pll_set_cdr_vco_speed_fix=74(1'h0); */
		0x133E380, /* [25:16]-DPRIO address=0x133; [15:8]-bit mask=0xE3; [7:5]-cdr_pll_chgpmp_current_up_pd=cp_current_pd_up_setting4(3'h4); [1:1]-cdr_pll_cdr_phaselock_mode=no_ignore_lock(1'h0); [0:0]-cdr_pll_gpon_lck2ref_control=gpon_lck2ref_off(1'h0); */
		0x134F782, /* [25:16]-DPRIO address=0x134; [15:8]-bit mask=0xF7; [7:7]-cdr_pll_txpll_hclk_driver_enable=false(1'h1); [6:6]-cdr_pll_set_cdr_vco_speed_fix=74(1'h0); [5:4]-cdr_pll_bbpd_data_pattern_filter_select=bbpd_data_pat_off(2'h0); [2:0]-cdr_pll_lck2ref_delay_control=lck2ref_delay_2(3'h2); */
		0x135FF03, /* [25:16]-DPRIO address=0x135; [15:8]-bit mask=0xFF; [7:7]-cdr_pll_txpll_hclk_driver_enable=false(1'h0); [6:6]-cdr_pll_set_cdr_vco_speed_fix=74(1'h0); [5:5]-cdr_pll_chgpmp_current_up_trim=cp_current_trimming_up_setting0(1'h0); [4:4]-cdr_pll_lf_ripple_cap=lf_no_ripple(1'h0); [3:2]-cdr_pll_lf_resistor_pd=lf_pd_setting0(2'h0); [1:0]-cdr_pll_lf_resistor_pfd=lf_pfd_setting3(2'h3); */
		0x136FF0A, /* [25:16]-DPRIO address=0x136; [15:8]-bit mask=0xFF; [7:6]-cdr_pll_vco_underrange_voltage=vco_underange_off(2'h0); [5:4]-cdr_pll_vco_overrange_voltage=vco_overrange_off(2'h0); [3:0]-cdr_pll_set_cdr_vco_speed_fix=74(4'hA); */
		0x137FF0F, /* [25:16]-DPRIO address=0x137; [15:8]-bit mask=0xFF; [7:7]-cdr_pll_diag_loopback_enable=false(1'h0); [6:2]-cdr_pll_set_cdr_vco_speed=3(5'h3); [1:1]-cdr_pll_set_cdr_v2i_enable=true(1'h1); [0:0]-cdr_pll_set_cdr_vco_reset=false(1'h1); */
		0x138FF82, /* [25:16]-DPRIO address=0x138; [15:8]-bit mask=0xFF; [7:7]-cdr_pll_fb_select=direct_fb(1'h1); [6:6]-cdr_pll_cdr_odi_select=sel_cdr(1'h0); [5:5]-cdr_pll_auto_reset_on=auto_reset_off(1'h0); [4:0]-cdr_pll_set_cdr_vco_speed_pciegen3=cdr_vco_max_speedbin_pciegen3(5'h2); */
		0x139FF21, /* [25:16]-DPRIO address=0x139; [15:8]-bit mask=0xFF; [7:7]-cdr_pll_pd_fastlock_mode=false(1'h0); [6:6]-cdr_pll_chgpmp_replicate=false(1'h0); [5:3]-cdr_pll_chgpmp_current_dn_pd=cp_current_pd_dn_setting4(3'h4); [2:0]-cdr_pll_chgpmp_current_pfd=cp_current_pfd_setting1(3'h1); */
		0x13AFF2B, /* [25:16]-DPRIO address=0x13A; [15:8]-bit mask=0xFF; [7:6]-cdr_pll_fref_clklow_div=1(2'h0); [5:3]-cdr_pll_pd_l_counter=8(3'h5); [2:0]-cdr_pll_pfd_l_counter=2(3'h3); */
		0x13BFF18, /* [25:16]-DPRIO address=0x13B; [15:8]-bit mask=0xFF; [7:0]-cdr_pll_m_counter=24(8'h18); */
		0x13CFD71, /* [25:16]-DPRIO address=0x13C; [15:8]-bit mask=0xFD; [7:7]-cdr_pll_reverse_serial_loopback=no_loopback(1'h0); [6:4]-cdr_pll_set_cdr_vco_speed_pciegen3=cdr_vco_max_speedbin_pciegen3(3'h7); [3:2]-cdr_pll_n_counter=1(2'h0); [0:0]-pma_rx_deser_rst_n_adapt_odi=no_rst_adapt_odi(1'h1); */
		0x13DFF00, /* [25:16]-DPRIO address=0x13D; [15:8]-bit mask=0xFF; [7:6]-cdr_pll_atb_select_control=atb_off(2'h0); [5:3]-cdr_pll_fref_mux_select=fref_mux_cdr_refclk(3'h0); [2:0]-cdr_pll_clklow_mux_select=clklow_mux_cdr_fbclk(3'h0); */
		0x13E7F00  /* [25:16]-DPRIO address=0x13E; [15:8]-bit mask=0x7F; [6:3]-cdr_pll_atb_select_control=atb_off(4'h0); [2:0]-cdr_pll_chgpmp_testmode=cp_test_disable(3'h0); */
	},

  	// Configuration 2.7 Gbps
	{
		0x132F7B2, /* [25:16]-DPRIO address=0x132; [15:8]-bit mask=0xF7; [7:6]-cdr_pll_set_cdr_vco_speed_pciegen3=cdr_vco_max_speedbin_pciegen3(2'h2); [5:4]-cdr_pll_reverse_serial_loopback=no_loopback(2'h3); [2:2]-cdr_pll_set_cdr_vco_speed_fix=60(1'h0); [1:1]-cdr_pll_cdr_powerdown_mode=power_up(1'h1); [0:0]-cdr_pll_set_cdr_vco_speed_fix=60(1'h0); */
		0x133E380, /* [25:16]-DPRIO address=0x133; [15:8]-bit mask=0xE3; [7:5]-cdr_pll_chgpmp_current_up_pd=cp_current_pd_up_setting4(3'h4); [1:1]-cdr_pll_cdr_phaselock_mode=no_ignore_lock(1'h0); [0:0]-cdr_pll_gpon_lck2ref_control=gpon_lck2ref_off(1'h0); */
		0x134F7C2, /* [25:16]-DPRIO address=0x134; [15:8]-bit mask=0xF7; [7:7]-cdr_pll_txpll_hclk_driver_enable=false(1'h1); [6:6]-cdr_pll_set_cdr_vco_speed_fix=60(1'h1); [5:4]-cdr_pll_bbpd_data_pattern_filter_select=bbpd_data_pat_off(2'h0); [2:0]-cdr_pll_lck2ref_delay_control=lck2ref_delay_2(3'h2); */
		0x135FF4E, /* [25:16]-DPRIO address=0x135; [15:8]-bit mask=0xFF; [7:7]-cdr_pll_txpll_hclk_driver_enable=false(1'h0); [6:6]-cdr_pll_set_cdr_vco_speed_fix=60(1'h1); [5:5]-cdr_pll_chgpmp_current_up_trim=cp_current_trimming_up_setting0(1'h0); [4:4]-cdr_pll_lf_ripple_cap=lf_no_ripple(1'h0); [3:2]-cdr_pll_lf_resistor_pd=lf_pd_setting3(2'h3); [1:0]-cdr_pll_lf_resistor_pfd=lf_pfd_setting2(2'h2); */
		0x136FF0C, /* [25:16]-DPRIO address=0x136; [15:8]-bit mask=0xFF; [7:6]-cdr_pll_vco_underrange_voltage=vco_underange_off(2'h0); [5:4]-cdr_pll_vco_overrange_voltage=vco_overrange_off(2'h0); [3:0]-cdr_pll_set_cdr_vco_speed_fix=60(4'hC); */
		0x137FF0F, /* [25:16]-DPRIO address=0x137; [15:8]-bit mask=0xFF; [7:7]-cdr_pll_diag_loopback_enable=false(1'h0); [6:2]-cdr_pll_set_cdr_vco_speed=3(5'h3); [1:1]-cdr_pll_set_cdr_v2i_enable=true(1'h1); [0:0]-cdr_pll_set_cdr_vco_reset=false(1'h1); */
		0x138FF82, /* [25:16]-DPRIO address=0x138; [15:8]-bit mask=0xFF; [7:7]-cdr_pll_fb_select=direct_fb(1'h1); [6:6]-cdr_pll_cdr_odi_select=sel_cdr(1'h0); [5:5]-cdr_pll_auto_reset_on=auto_reset_off(1'h0); [4:0]-cdr_pll_set_cdr_vco_speed_pciegen3=cdr_vco_max_speedbin_pciegen3(5'h2); */
		0x139FF23, /* [25:16]-DPRIO address=0x139; [15:8]-bit mask=0xFF; [7:7]-cdr_pll_pd_fastlock_mode=false(1'h0); [6:6]-cdr_pll_chgpmp_replicate=false(1'h0); [5:3]-cdr_pll_chgpmp_current_dn_pd=cp_current_pd_dn_setting4(3'h4); [2:0]-cdr_pll_chgpmp_current_pfd=cp_current_pfd_setting3(3'h3); */
		0x13AFF23, /* [25:16]-DPRIO address=0x13A; [15:8]-bit mask=0xFF; [7:6]-cdr_pll_fref_clklow_div=1(2'h0); [5:3]-cdr_pll_pd_l_counter=4(3'h4); [2:0]-cdr_pll_pfd_l_counter=2(3'h3); */
		0x13BFF14, /* [25:16]-DPRIO address=0x13B; [15:8]-bit mask=0xFF; [7:0]-cdr_pll_m_counter=20(8'h14); */
		0x13CFD71, /* [25:16]-DPRIO address=0x13C; [15:8]-bit mask=0xFD; [7:7]-cdr_pll_reverse_serial_loopback=no_loopback(1'h0); [6:4]-cdr_pll_set_cdr_vco_speed_pciegen3=cdr_vco_max_speedbin_pciegen3(3'h7); [3:2]-cdr_pll_n_counter=1(2'h0); [0:0]-pma_rx_deser_rst_n_adapt_odi=no_rst_adapt_odi(1'h1); */
		0x13DFF00, /* [25:16]-DPRIO address=0x13D; [15:8]-bit mask=0xFF; [7:6]-cdr_pll_atb_select_control=atb_off(2'h0); [5:3]-cdr_pll_fref_mux_select=fref_mux_cdr_refclk(3'h0); [2:0]-cdr_pll_clklow_mux_select=clklow_mux_cdr_fbclk(3'h0); */
		0x13E7F00  /* [25:16]-DPRIO address=0x13E; [15:8]-bit mask=0x7F; [6:3]-cdr_pll_atb_select_control=atb_off(4'h0); [2:0]-cdr_pll_chgpmp_testmode=cp_test_disable(3'h0); */
	},

 	// Configuration 5.4 Gbps
	{
		0x132F7B2, /* [25:16]-DPRIO address=0x132; [15:8]-bit mask=0xF7; [7:6]-cdr_pll_set_cdr_vco_speed_pciegen3=cdr_vco_max_speedbin_pciegen3(2'h2); [5:4]-cdr_pll_reverse_serial_loopback=no_loopback(2'h3); [2:2]-cdr_pll_set_cdr_vco_speed_fix=60(1'h0); [1:1]-cdr_pll_cdr_powerdown_mode=power_up(1'h1); [0:0]-cdr_pll_set_cdr_vco_speed_fix=60(1'h0); */
		0x133E380, /* [25:16]-DPRIO address=0x133; [15:8]-bit mask=0xE3; [7:5]-cdr_pll_chgpmp_current_up_pd=cp_current_pd_up_setting4(3'h4); [1:1]-cdr_pll_cdr_phaselock_mode=no_ignore_lock(1'h0); [0:0]-cdr_pll_gpon_lck2ref_control=gpon_lck2ref_off(1'h0); */
		0x134F7C2, /* [25:16]-DPRIO address=0x134; [15:8]-bit mask=0xF7; [7:7]-cdr_pll_txpll_hclk_driver_enable=false(1'h1); [6:6]-cdr_pll_set_cdr_vco_speed_fix=60(1'h1); [5:4]-cdr_pll_bbpd_data_pattern_filter_select=bbpd_data_pat_off(2'h0); [2:0]-cdr_pll_lck2ref_delay_control=lck2ref_delay_2(3'h2); */
		0x135FF4E, /* [25:16]-DPRIO address=0x135; [15:8]-bit mask=0xFF; [7:7]-cdr_pll_txpll_hclk_driver_enable=false(1'h0); [6:6]-cdr_pll_set_cdr_vco_speed_fix=60(1'h1); [5:5]-cdr_pll_chgpmp_current_up_trim=cp_current_trimming_up_setting0(1'h0); [4:4]-cdr_pll_lf_ripple_cap=lf_no_ripple(1'h0); [3:2]-cdr_pll_lf_resistor_pd=lf_pd_setting3(2'h3); [1:0]-cdr_pll_lf_resistor_pfd=lf_pfd_setting2(2'h2); */
		0x136FF0C, /* [25:16]-DPRIO address=0x136; [15:8]-bit mask=0xFF; [7:6]-cdr_pll_vco_underrange_voltage=vco_underange_off(2'h0); [5:4]-cdr_pll_vco_overrange_voltage=vco_overrange_off(2'h0); [3:0]-cdr_pll_set_cdr_vco_speed_fix=60(4'hC); */
		0x137FF0F, /* [25:16]-DPRIO address=0x137; [15:8]-bit mask=0xFF; [7:7]-cdr_pll_diag_loopback_enable=false(1'h0); [6:2]-cdr_pll_set_cdr_vco_speed=3(5'h3); [1:1]-cdr_pll_set_cdr_v2i_enable=true(1'h1); [0:0]-cdr_pll_set_cdr_vco_reset=false(1'h1); */
		0x138FF82, /* [25:16]-DPRIO address=0x138; [15:8]-bit mask=0xFF; [7:7]-cdr_pll_fb_select=direct_fb(1'h1); [6:6]-cdr_pll_cdr_odi_select=sel_cdr(1'h0); [5:5]-cdr_pll_auto_reset_on=auto_reset_off(1'h0); [4:0]-cdr_pll_set_cdr_vco_speed_pciegen3=cdr_vco_max_speedbin_pciegen3(5'h2); */
		0x139FF23, /* [25:16]-DPRIO address=0x139; [15:8]-bit mask=0xFF; [7:7]-cdr_pll_pd_fastlock_mode=false(1'h0); [6:6]-cdr_pll_chgpmp_replicate=false(1'h0); [5:3]-cdr_pll_chgpmp_current_dn_pd=cp_current_pd_dn_setting4(3'h4); [2:0]-cdr_pll_chgpmp_current_pfd=cp_current_pfd_setting3(3'h3); */
		0x13AFF1B, /* [25:16]-DPRIO address=0x13A; [15:8]-bit mask=0xFF; [7:6]-cdr_pll_fref_clklow_div=1(2'h0); [5:3]-cdr_pll_pd_l_counter=2(3'h3); [2:0]-cdr_pll_pfd_l_counter=2(3'h3); */
		0x13BFF14, /* [25:16]-DPRIO address=0x13B; [15:8]-bit mask=0xFF; [7:0]-cdr_pll_m_counter=20(8'h14); */
		0x13CFD71, /* [25:16]-DPRIO address=0x13C; [15:8]-bit mask=0xFD; [7:7]-cdr_pll_reverse_serial_loopback=no_loopback(1'h0); [6:4]-cdr_pll_set_cdr_vco_speed_pciegen3=cdr_vco_max_speedbin_pciegen3(3'h7); [3:2]-cdr_pll_n_counter=1(2'h0); [0:0]-pma_rx_deser_rst_n_adapt_odi=no_rst_adapt_odi(1'h1); */
		0x13DFF00, /* [25:16]-DPRIO address=0x13D; [15:8]-bit mask=0xFF; [7:6]-cdr_pll_atb_select_control=atb_off(2'h0); [5:3]-cdr_pll_fref_mux_select=fref_mux_cdr_refclk(3'h0); [2:0]-cdr_pll_clklow_mux_select=clklow_mux_cdr_fbclk(3'h0); */
		0x13E7F00  /* [25:16]-DPRIO address=0x13E; [15:8]-bit mask=0x7F; [6:3]-cdr_pll_atb_select_control=atb_off(4'h0); [2:0]-cdr_pll_chgpmp_testmode=cp_test_disable(3'h0); */
	},

 	// Configuration 5.4 Gbps
	{
		0x132F7B6, /* [25:16]-DPRIO address=0x132; [15:8]-bit mask=0xF7; [7:6]-cdr_pll_set_cdr_vco_speed_pciegen3=cdr_vco_max_speedbin_pciegen3(2'h2); [5:4]-cdr_pll_reverse_serial_loopback=no_loopback(2'h3); [2:2]-cdr_pll_set_cdr_vco_speed_fix=90(1'h1); [1:1]-cdr_pll_cdr_powerdown_mode=power_up(1'h1); [0:0]-cdr_pll_set_cdr_vco_speed_fix=90(1'h0); */
		0x133E380, /* [25:16]-DPRIO address=0x133; [15:8]-bit mask=0xE3; [7:5]-cdr_pll_chgpmp_current_up_pd=cp_current_pd_up_setting4(3'h4); [1:1]-cdr_pll_cdr_phaselock_mode=no_ignore_lock(1'h0); [0:0]-cdr_pll_gpon_lck2ref_control=gpon_lck2ref_off(1'h0); */
		0x134F7C2, /* [25:16]-DPRIO address=0x134; [15:8]-bit mask=0xF7; [7:7]-cdr_pll_txpll_hclk_driver_enable=false(1'h1); [6:6]-cdr_pll_set_cdr_vco_speed_fix=90(1'h1); [5:4]-cdr_pll_bbpd_data_pattern_filter_select=bbpd_data_pat_off(2'h0); [2:0]-cdr_pll_lck2ref_delay_control=lck2ref_delay_2(3'h2); */
		0x135FF0F, /* [25:16]-DPRIO address=0x135; [15:8]-bit mask=0xFF; [7:7]-cdr_pll_txpll_hclk_driver_enable=false(1'h0); [6:6]-cdr_pll_set_cdr_vco_speed_fix=90(1'h0); [5:5]-cdr_pll_chgpmp_current_up_trim=cp_current_trimming_up_setting0(1'h0); [4:4]-cdr_pll_lf_ripple_cap=lf_no_ripple(1'h0); [3:2]-cdr_pll_lf_resistor_pd=lf_pd_setting3(2'h3); [1:0]-cdr_pll_lf_resistor_pfd=lf_pfd_setting3(2'h3); */
		0x136FF0A, /* [25:16]-DPRIO address=0x136; [15:8]-bit mask=0xFF; [7:6]-cdr_pll_vco_underrange_voltage=vco_underange_off(2'h0); [5:4]-cdr_pll_vco_overrange_voltage=vco_overrange_off(2'h0); [3:0]-cdr_pll_set_cdr_vco_speed_fix=90(4'hA); */
		0x137FF0B, /* [25:16]-DPRIO address=0x137; [15:8]-bit mask=0xFF; [7:7]-cdr_pll_diag_loopback_enable=false(1'h0); [6:2]-cdr_pll_set_cdr_vco_speed=2(5'h2); [1:1]-cdr_pll_set_cdr_v2i_enable=true(1'h1); [0:0]-cdr_pll_set_cdr_vco_reset=false(1'h1); */
		0x138FF82, /* [25:16]-DPRIO address=0x138; [15:8]-bit mask=0xFF; [7:7]-cdr_pll_fb_select=direct_fb(1'h1); [6:6]-cdr_pll_cdr_odi_select=sel_cdr(1'h0); [5:5]-cdr_pll_auto_reset_on=auto_reset_off(1'h0); [4:0]-cdr_pll_set_cdr_vco_speed_pciegen3=cdr_vco_max_speedbin_pciegen3(5'h2); */
		0x139FF21, /* [25:16]-DPRIO address=0x139; [15:8]-bit mask=0xFF; [7:7]-cdr_pll_pd_fastlock_mode=false(1'h0); [6:6]-cdr_pll_chgpmp_replicate=false(1'h0); [5:3]-cdr_pll_chgpmp_current_dn_pd=cp_current_pd_dn_setting4(3'h4); [2:0]-cdr_pll_chgpmp_current_pfd=cp_current_pfd_setting1(3'h1); */
		0x13AFF1B, /* [25:16]-DPRIO address=0x13A; [15:8]-bit mask=0xFF; [7:6]-cdr_pll_fref_clklow_div=1(2'h0); [5:3]-cdr_pll_pd_l_counter=2(3'h3); [2:0]-cdr_pll_pfd_l_counter=2(3'h3); */
		0x13BFF1E, /* [25:16]-DPRIO address=0x13B; [15:8]-bit mask=0xFF; [7:0]-cdr_pll_m_counter=30(8'h1E); */
		0x13CFD71, /* [25:16]-DPRIO address=0x13C; [15:8]-bit mask=0xFD; [7:7]-cdr_pll_reverse_serial_loopback=no_loopback(1'h0); [6:4]-cdr_pll_set_cdr_vco_speed_pciegen3=cdr_vco_max_speedbin_pciegen3(3'h7); [3:2]-cdr_pll_n_counter=1(2'h0); [0:0]-pma_rx_deser_rst_n_adapt_odi=no_rst_adapt_odi(1'h1); */
		0x13DFF00, /* [25:16]-DPRIO address=0x13D; [15:8]-bit mask=0xFF; [7:6]-cdr_pll_atb_select_control=atb_off(2'h0); [5:3]-cdr_pll_fref_mux_select=fref_mux_cdr_refclk(3'h0); [2:0]-cdr_pll_clklow_mux_select=clklow_mux_cdr_fbclk(3'h0); */
		0x13E7F00, /* [25:16]-DPRIO address=0x13E; [15:8]-bit mask=0x7F; [6:3]-cdr_pll_atb_select_control=atb_off(4'h0); [2:0]-cdr_pll_chgpmp_testmode=cp_test_disable(3'h0); */
	}
};

// Initialize
void prt_phy_int_init (prt_phy_int_ds_struct *phy, prt_pio_ds_struct *pio, prt_tmr_ds_struct *tmr, prt_u32 base, 
	prt_u32 pio_phy_pll_pwrdwn, prt_u32 pio_phy_pll_cal_busy, prt_u32 pio_phy_pll_lock,
  	prt_u32 pio_phy_tx_cal_busy, prt_u32 pio_phy_tx_arst,  prt_u32 pio_phy_tx_drst,
  	prt_u32 pio_phy_rx_cal_busy, prt_u32 pio_phy_rx_arst,  prt_u32 pio_phy_rx_drst, prt_u32 pio_phy_rx_cdr_lock
	)
{
  	// Base address
	phy->dev = (prt_phy_int_dev_struct *) base;

	// PIO
	phy->pio = pio;

	// Timer
	phy->tmr = tmr;

	// PIO bits
	
	// PHY PLL
	phy->pio_phy_pll_pwrdwn = pio_phy_pll_pwrdwn;
	phy->pio_phy_pll_cal_busy = pio_phy_pll_cal_busy;
	phy->pio_phy_pll_lock = pio_phy_pll_lock;

	// PHY TX
	phy->pio_phy_tx_cal_busy = pio_phy_tx_cal_busy;
	phy->pio_phy_tx_drst = pio_phy_tx_drst;
	phy->pio_phy_tx_arst = pio_phy_tx_arst;

	// PHY RX
	phy->pio_phy_rx_cal_busy = pio_phy_rx_cal_busy;
	phy->pio_phy_rx_drst = pio_phy_rx_drst;
	phy->pio_phy_rx_arst = pio_phy_rx_arst;
	phy->pio_phy_rx_cdr_lock = pio_phy_rx_cdr_lock;
}

// Read
prt_u32 prt_phy_int_rd (prt_phy_int_ds_struct *phy, prt_u8 port, prt_u16 adr)
{
	// Variables
	prt_u32 cmd;
	prt_bool exit_loop;

	// Port
	cmd = port;
	
	// Address
	cmd |= (adr << PRT_PHY_INT_RCFG_ADR_SHIFT);

	// Write command
	phy->dev->rcfg_adr = cmd;

	// Read
	phy->dev->ctl = PRT_PHY_INT_DEV_CTL_RD;

    // Set alarm 1
    prt_tmr_set_alrm (phy->tmr, 1, 100);

    exit_loop = PRT_FALSE;
    do
    {
		if (phy->dev->sta & PRT_PHY_INT_DEV_STA_RDY)
		{
			exit_loop = PRT_TRUE;
		}

		else if (prt_tmr_is_alrm (phy->tmr, 1))
		{
			prt_printf ("PHY: Reconfig read timeout\n");
		}
	} while (exit_loop == PRT_FALSE);
	
	// Clear ready bit
	phy->dev->sta = PRT_PHY_INT_DEV_STA_RDY;

	// Return data
	return phy->dev->rcfg_dat;
}

// Write
void prt_phy_int_wr (prt_phy_int_ds_struct *phy, prt_u8 port, prt_u16 adr, prt_u32 dat)
{
	// Variables
	prt_u32 cmd;
	prt_bool exit_loop;

	// Port
	cmd = port;
	
	// Address
	cmd |= (adr << PRT_PHY_INT_RCFG_ADR_SHIFT);

	// Write command 
	phy->dev->rcfg_adr = cmd;

	// Write data
	phy->dev->rcfg_dat = dat;

	// Write
	phy->dev->ctl = PRT_PHY_INT_DEV_CTL_WR;

	// Clear ready bit
	phy->dev->sta = PRT_PHY_INT_DEV_STA_RDY;
}

// Read-modify-write
void prt_phy_int_rmw (prt_phy_int_ds_struct *phy, prt_u8 port, prt_u16 adr, prt_u32 msk, prt_u32 dat)
{
	// Variables
	prt_u32 reg_dat;

	// Read register 
	reg_dat = prt_phy_int_rd (phy, port, adr);

	// Clear masked bits
	reg_dat &= ~(msk);

	// Modify
	reg_dat |= dat;

	// Write register
	prt_phy_int_wr (phy, port, adr, reg_dat);
}

// Voltage and pre-emphasis
void prt_phy_int_tx_vap (prt_phy_int_ds_struct *phy, prt_u8 volt, prt_u8 pre)
{
	// Variables
	prt_u32 dat;
	prt_u32 vod;
	prt_u32 tap;

	// Voltage level
	// There are 31 vod settings. The step size is 1/30 of the VCCT power supply level.
	// See chapter 5.1.3.2 of the Cyclone 10 GX transceiver PHY user guide 
	switch (volt)	
	{
		case 1 : vod = 19; break;	// 600 mV
		case 2 : vod = 25; break;	// 800 mV
		case 3 : vod = 31; break;	// 1000 mV (max value)
		default : vod = 13; break;	// 400 mV
	}

	// Read register (only the first transceiver port)
	dat = prt_phy_int_rd (phy, PRT_PHY_INT_XCVR_PORT, 0x109);

	// Mask out bits 4:0
	dat &= ~(0x1f);

	// Set voltage swing
	dat |= vod;

	// Write registers
	for (prt_u8 i = PRT_PHY_INT_XCVR_PORT; i < PRT_PHY_INT_XCVR_PORT + 4; i++)
	{
		prt_phy_int_wr (phy, i, 0x109, dat);
	}

	// Pre-emphasis level
	// For the 1st post-tap values see the Cyclone 10 GX pre-emphasis and output swing settings estimator
	switch (pre)	
	{
		case 1 : tap = 10; break;	// 3.5 dB
		case 2 : tap = 15; break;	// 6.0 dB
		case 3 : tap = 20; break;	// 9.5 dB
		default : tap = 0; break;	// 0 dB
	}

	// Read register (only the first transceiver port)
	dat = prt_phy_int_rd (phy, PRT_PHY_INT_XCVR_PORT, 0x105);

	// Mask out bits 4:0
	dat &= ~(0x1f);

	// Set pre-emphasis 1st post tap
	dat |= tap;

	// Set bit 6 for negative value
	dat |= (1 << 6);

	for (prt_u8 i = PRT_PHY_INT_XCVR_PORT; i < PRT_PHY_INT_XCVR_PORT + 4; i++)
	{
		prt_phy_int_wr (phy, i, 0x105, dat);
	}
}

// TX rate 
void prt_phy_int_tx_rate (prt_phy_int_ds_struct *phy, prt_u8 rate)
{
	// Configure TX PLL
	prt_phy_int_tx_pll_cfg (phy, rate);

	// Recalibrate TX PLL
	prt_phy_int_tx_pll_recal (phy);

	// Reset TX PLL and PHY
	prt_phy_int_tx_rst (phy);
}

// TX PLL configuration
void prt_phy_int_tx_pll_cfg (prt_phy_int_ds_struct *phy, prt_u8 rate)
{
	// Variables
	prt_u8 cfg_idx;
	prt_u32 cfg_val;
	prt_u16 cfg_adr;
	prt_u32 cfg_dat;
	prt_u32 cfg_msk;

	// Select configuration 
	switch (rate)
	{
		case PRT_PHY_INT_LINERATE_2700 : cfg_idx = 1; break;
		case PRT_PHY_INT_LINERATE_5400 : cfg_idx = 2; break;
		case PRT_PHY_INT_LINERATE_8100 : cfg_idx = 3; break;
		default : cfg_idx = 0; break;
	}

	for (prt_u8 i = 0; i < 22; i++)
	{
		cfg_val = altera_xcvr_atx_pll_a10_ram_array[cfg_idx][i];
		cfg_adr = cfg_val >> 16;
		cfg_msk = (cfg_val >> 8) & 0xff;
		cfg_dat = cfg_val & 0xff;

		// Read-Modify-Write
		prt_phy_int_rmw (phy, PRT_PHY_INT_TX_PLL_PORT, cfg_adr, cfg_msk, cfg_dat);
	}
}

// TX PLL and PHY reset
void prt_phy_int_tx_rst (prt_phy_int_ds_struct *phy)
{
	// Variables
	prt_bool exit_loop;

	// Assert PHY PLL power down
	prt_pio_dat_set (phy->pio, phy->pio_phy_pll_pwrdwn);

	// Assert PHY TX analog reset
	prt_pio_dat_set (phy->pio, phy->pio_phy_tx_arst);

	// Assert PHY TX digital reset
	prt_pio_dat_set (phy->pio, phy->pio_phy_tx_drst);

	// Sleep alarm 0
	prt_tmr_sleep (phy->tmr, 0, PRT_PHY_INT_RST_PULSE);

	// Release PHY PLL power down
	prt_pio_dat_clr (phy->pio, phy->pio_phy_pll_pwrdwn);

	// Release PHY TX analog reset
	prt_pio_dat_clr (phy->pio, phy->pio_phy_tx_arst);

	// Wait for PHY PLL lock
    // Set alarm 0
    prt_tmr_set_alrm (phy->tmr, 0, PRT_PHY_INT_LOCK_TIMEOUT);

	exit_loop = PRT_FALSE;
	do
	{
		if (pio_tst_bit (phy->pio, phy->pio_phy_pll_lock))
		{
			exit_loop = PRT_TRUE;
		}

		else if (prt_tmr_is_alrm (phy->tmr, 0))
		{
			prt_printf ("PHY: PHY PLL lock timeout\n");
			exit_loop = PRT_TRUE;
		}
	} while (exit_loop == PRT_FALSE);

	// Sleep alarm 0
	prt_tmr_sleep (phy->tmr, 0, PRT_PHY_INT_RST_PULSE);

	// Release PHY TX digital reset
	prt_pio_dat_clr (phy->pio, phy->pio_phy_tx_drst);
}

// TX PLL recalibration
void prt_phy_int_tx_pll_recal (prt_phy_int_ds_struct *phy)
{
	// Variables
	prt_bool exit_loop;

	// Request user access to internal configuration bus
	prt_phy_int_rmw (phy, PRT_PHY_INT_TX_PLL_PORT, 0x00, 0xff, 0x02);

	// Calibrate ATX PLL
	prt_phy_int_rmw (phy, PRT_PHY_INT_TX_PLL_PORT, 0x100, 0x01, 0x01);

	// Release internal bus 
	prt_phy_int_rmw (phy, PRT_PHY_INT_TX_PLL_PORT, 0x00, 0xff, 0x01);

	// Wait for PHY PLL cal_busy to go low
    // Set alarm 0
    prt_tmr_set_alrm (phy->tmr, 0, PRT_PHY_INT_RECAL_TIMEOUT);

	exit_loop = PRT_FALSE;
	do
	{
		if (!pio_tst_bit (phy->pio, phy->pio_phy_pll_cal_busy))
		{
			exit_loop = PRT_TRUE;
		}

		else if (prt_tmr_is_alrm (phy->tmr, 0))
		{
			prt_printf ("PHY: TX RECAL timeout\n");
			exit_loop = PRT_TRUE;
		}
	} while (exit_loop == PRT_FALSE);
}

// RX rate 
// Change RX line rate
void prt_phy_int_rx_rate (prt_phy_int_ds_struct *phy, prt_u8 rate)
{
	// Assert PHY RX analog reset
	prt_pio_dat_set (phy->pio, phy->pio_phy_rx_arst);

	// Assert PHY RX digital reset
	prt_pio_dat_set (phy->pio, phy->pio_phy_rx_drst);

	// Configure PHY RX (with pre-calibrated data)
	prt_phy_int_rx_cfg_cal (phy, rate);

	// Reset PHY RX
	prt_phy_int_rx_rst (phy);
}

// PHY RX configuration (init)
// This function configures the PHY with the initial data
// This is used during when calibrating the transceiver.
void prt_phy_int_rx_cfg_init (prt_phy_int_ds_struct *phy, prt_u8 rate)
{
	// Variables
	prt_u8 cfg_idx;
	prt_u32 cfg_val;
	prt_u16 cfg_adr;
	prt_u32 cfg_dat;
	prt_u32 cfg_msk;

	// Select configuration 
	switch (rate)
	{
		case PRT_PHY_INT_LINERATE_2700 : cfg_idx = 1; break;
		case PRT_PHY_INT_LINERATE_5400 : cfg_idx = 2; break;
		case PRT_PHY_INT_LINERATE_8100 : cfg_idx = 3; break;
		default : cfg_idx = 0; break;
	}

	// Loop through the configuration array
	for (prt_u8 i = 0; i < 13; i++)
	{
		cfg_val = altera_xcvr_native_a10_ram_array[cfg_idx][i];
		cfg_adr = cfg_val >> 16;
		cfg_msk = (cfg_val >> 8) & 0xff;
		cfg_dat = cfg_val & 0xff;

		// Read-Modify-Write
		for (prt_u8 j = 0; j < 4; j++)
			prt_phy_int_rmw (phy, PRT_PHY_INT_XCVR_PORT + j, cfg_adr, cfg_msk, cfg_dat);
	}
}

// PHY RX configuration (cal)
// This function configures the PHY with the calibrated data
// This is used during the displayport training. 
// Because this data is pre-calibrated, no recalibration is required. 
void prt_phy_int_rx_cfg_cal (prt_phy_int_ds_struct *phy, prt_u8 rate)
{
	// Variables
	prt_u8 cfg_idx;
	prt_u32 cfg_val;
	prt_u16 cfg_adr;
	prt_u32 cfg_dat;
	prt_u32 cfg_msk;

	// Select configuration 
	switch (rate)
	{
		case PRT_PHY_INT_LINERATE_2700 : cfg_idx = 1; break;
		case PRT_PHY_INT_LINERATE_5400 : cfg_idx = 2; break;
		case PRT_PHY_INT_LINERATE_8100 : cfg_idx = 3; break;
		default : cfg_idx = 0; break;
	}

	// Loop through all configuration registers
	for (prt_u8 i = 0; i < 13; i++)
	{
		// Use the initial configuration array to look up the address.
		cfg_val = altera_xcvr_native_a10_ram_array[cfg_idx][i];
		cfg_adr = cfg_val >> 16;
		cfg_msk = (cfg_val >> 8) & 0xff;

		// Four channels	
		for (prt_u8 j = 0; j < 4; j++)
		{
			// Get data
			cfg_dat = phy->cfg.dat[cfg_idx][j][i]; 

			// Read-modify-write
			prt_phy_int_rmw (phy, PRT_PHY_INT_XCVR_PORT + j, cfg_adr, cfg_msk, cfg_dat);
		}
	}
}

// PHY RX recalibration
void prt_phy_int_rx_recal (prt_phy_int_ds_struct *phy)
{
	// Variables
	prt_bool exit_loop;

	// Request user access to internal configuration bus
	for (prt_u8 i = 0; i < 4; i++)
	{
		// Request user access to internal configuration bus
		prt_phy_int_rmw (phy, PRT_PHY_INT_XCVR_PORT + i, 0x00, 0xff, 0x02);

		// Calibrate PMA RX
		prt_phy_int_rmw (phy, PRT_PHY_INT_XCVR_PORT + i, 0x100, (1<<1), (1<<1));

		// Set rate switch flag register
		// The CDR charge pump settings (0x139 and 0x133) are reconfigured.
		prt_phy_int_rmw (phy, PRT_PHY_INT_XCVR_PORT + i, 0x166, (1<<7), (1<<7));

		// Enable RX cal_busy output
		prt_phy_int_rmw (phy, PRT_PHY_INT_XCVR_PORT + i, 0x281, (1<<5), (1<<5));

		// Release internal bus 
		prt_phy_int_rmw (phy, PRT_PHY_INT_XCVR_PORT + i, 0x00, 0xff, 0x01);
	}

	// Wait for PHY RX cal_busy to go low
    // Set alarm 0
    prt_tmr_set_alrm (phy->tmr, 0, PRT_PHY_INT_RECAL_TIMEOUT);

	exit_loop = PRT_FALSE;
	do
	{
		if (!pio_tst_bit (phy->pio, phy->pio_phy_rx_cal_busy))
		{
			exit_loop = PRT_TRUE;
		}

		else if (prt_tmr_is_alrm (phy->tmr, 0))
		{
			prt_printf ("PHY: RX RECAL timeout\n");
			exit_loop = PRT_TRUE;
		}
	} while (exit_loop == PRT_FALSE);
}

// PHY RX reset
void prt_phy_int_rx_rst (prt_phy_int_ds_struct *phy)
{
	// Variables
	prt_bool exit_loop;

	// Assert PHY RX analog reset
	prt_pio_dat_set (phy->pio, phy->pio_phy_rx_arst);

	// Assert PHY RX digital reset
	prt_pio_dat_set (phy->pio, phy->pio_phy_rx_drst);

	// Sleep alarm 0
	prt_tmr_sleep (phy->tmr, 0, PRT_PHY_INT_RST_PULSE);

	// Release PHY RX analog reset
	prt_pio_dat_clr (phy->pio, phy->pio_phy_rx_arst);

	// Wait for PHY CDR lock
    // Set alarm 0
    prt_tmr_set_alrm (phy->tmr, 0, PRT_PHY_INT_LOCK_TIMEOUT);

	exit_loop = PRT_FALSE;
	do
	{
		if (pio_tst_bit (phy->pio, phy->pio_phy_rx_cdr_lock))
		{
			exit_loop = PRT_TRUE;
		}

		else if (prt_tmr_is_alrm (phy->tmr, 0))
		{
			prt_printf ("PHY: RX CDR lock timeout\n");
			exit_loop = PRT_TRUE;
		}
	} while (exit_loop == PRT_FALSE);

	// Sleep alarm 0
	prt_tmr_sleep (phy->tmr, 0, PRT_PHY_INT_RST_PULSE);

	// Release PHY RX digital reset
	prt_pio_dat_clr (phy->pio, phy->pio_phy_rx_drst);
}

// Setup
// When changing the line rate, the transceiver (RX) needs to be recalibrated. 
// This process takes 10 ms, which is too long when executed during the DP link training. 
// To hide this long calibration time, the transceiver is recalibrated at startup of the application. 
// The calibrated data is stored.
// During DP link training the stored pre-calibrated data is used and no recalibrated is needed.
void prt_phy_int_setup (prt_phy_int_ds_struct *phy, prt_u8 rate)
{
	// Variables
	prt_u8 cfg_idx;
	prt_u32 cfg_val;
	prt_u16 cfg_adr;
	prt_u8 cfg_dat;

	// First the transciver is configured with the initial data
	prt_phy_int_rx_cfg_init (phy, rate);

	// Then the transceiver is recalibrated
	prt_phy_int_rx_recal (phy);

	// After the calibration the calibrated data is stored
	// Select configuration 
	switch (rate)
	{
		case PRT_PHY_INT_LINERATE_2700 : cfg_idx = 1; break;
		case PRT_PHY_INT_LINERATE_5400 : cfg_idx = 2; break;
		case PRT_PHY_INT_LINERATE_8100 : cfg_idx = 3; break;
		default : cfg_idx = 0; break;
	}

	// Loop through all configuration registers
	for (prt_u8 i = 0; i < 13; i++)
	{
		// Use the initial configuration array to look up the address.
		cfg_val = altera_xcvr_native_a10_ram_array[cfg_idx][i];
		cfg_adr = cfg_val >> 16;
		
		// Four channels
		for (prt_u8 j = 0; j < 4; j++)
		{
			// Read data from PHY
			cfg_dat = prt_phy_int_rd (phy, PRT_PHY_INT_XCVR_PORT + j, cfg_adr);
		
			// Store data in configuration registers
			phy->cfg.dat[cfg_idx][j][i] = cfg_dat;
		}
	}
}


