###
# Altera Agilex 5 DP reference design project script
# (c) 2026 by Parretto B.V.
#
# Run from reference/altera/gateware/syn/ag5e_065a_mdk with:
# quartus_sh -t ../../ref/ag5e_065a_mdk/build_proj.tcl
###

package require ::quartus::project
package require ::quartus::flow

set PROJECT dp_ref_alt_ag5e_065a_mdk
set REF     ../../ref/ag5e_065a_mdk
set SRC     ../../../../../gateware/src
set QSYS    [file normalize [file join $::quartus(binpath) .. .. qsys bin]]
set PRT_LIB "../../../../../gateware/src/lib"
set IP_PATH "[file normalize ../../ip]/**/*"

# Create project
project_new $PROJECT -overwrite -revision $PROJECT
set_global_assignment -name FAMILY "Agilex 5"
set_global_assignment -name DEVICE A5ED065AB32AE1V
project_close

# Platform Designer system
# qsys-script adds the IP files to the project settings file on disk,
# so it must run while the project is closed.
exec $QSYS/qsys-script --search-path=$IP_PATH,$ --script=$REF/dp_soc_ag5e.tcl --quartus-project=$PROJECT 2>@1
exec $QSYS/qsys-script --script=$REF/gts_ip.tcl --quartus-project=$PROJECT 2>@1
exec $QSYS/qsys-script --script=$REF/vid_pll_ip.tcl --quartus-project=$PROJECT 2>@1

project_open $PROJECT -revision $PROJECT

set_global_assignment -name FAMILY "Agilex 5"
set_global_assignment -name DEVICE A5ED065AB32AE1V
set_global_assignment -name TOP_LEVEL_ENTITY $PROJECT
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files
set_global_assignment -name NUM_PARALLEL_PROCESSORS ALL
set_global_assignment -name IP_SEARCH_PATHS $IP_PATH

###
# Configuration
# The FPGA is configured first, after that the SDM loads the application into the HPS on-chip RAM.
# The other settings follow the board (see the Altera GHRD for the modular development kit).
###
set_global_assignment -name HPS_INITIALIZATION "AFTER INIT_DONE"
set_global_assignment -name HPS_DAP_SPLIT_MODE "SDM PINS"
set_global_assignment -name HPS_DAP_NO_CERTIFICATE ON
set_global_assignment -name QSPI_OWNERSHIP HPS
set_global_assignment -name USE_HPS_COLD_RESET SDM_IO10
set_global_assignment -name USE_CONF_DONE SDM_IO16
set_global_assignment -name DEVICE_INITIALIZATION_CLOCK OSC_CLK_1_125MHZ
set_global_assignment -name USE_CHECKSUM_AS_USERCODE OFF

# Power management (core voltage regulator)
set_global_assignment -name VID_OPERATION_MODE "PMBUS MASTER"
set_global_assignment -name USE_PWRMGT_SCL SDM_IO14
set_global_assignment -name USE_PWRMGT_SDA SDM_IO11
set_global_assignment -name PWRMGT_BUS_SPEED_MODE "400 KHZ"
set_global_assignment -name PWRMGT_PAGE_COMMAND_ENABLE ON
set_global_assignment -name PWRMGT_SLAVE_DEVICE_TYPE OTHER
set_global_assignment -name NUMBER_OF_SLAVE_DEVICE 1
set_global_assignment -name PWRMGT_SLAVE_DEVICE0_ADDRESS 74
set_global_assignment -name PWRMGT_SLAVE_DEVICE1_ADDRESS 00
set_global_assignment -name PWRMGT_SLAVE_DEVICE2_ADDRESS 00
set_global_assignment -name PWRMGT_SLAVE_DEVICE3_ADDRESS 00
set_global_assignment -name PWRMGT_SLAVE_DEVICE4_ADDRESS 00
set_global_assignment -name PWRMGT_SLAVE_DEVICE5_ADDRESS 00
set_global_assignment -name PWRMGT_SLAVE_DEVICE6_ADDRESS 00
set_global_assignment -name PWRMGT_SLAVE_DEVICE7_ADDRESS 00
set_global_assignment -name PWRMGT_TRANSLATED_VOLTAGE_VALUE_UNIT VOLTS
set_global_assignment -name PWRMGT_VOLTAGE_OUTPUT_FORMAT "LINEAR FORMAT"
set_global_assignment -name PWRMGT_LINEAR_FORMAT_N "-12"

###
# Pins
###
# System clock (100 MHz)
set_location_assignment PIN_BK31 -to SYS_CLK_IN
set_instance_assignment -name IO_STANDARD "3.3-V LVCMOS" -to SYS_CLK_IN
set_instance_assignment -name INPUT_TERMINATION OFF -to SYS_CLK_IN

# Reset
set_location_assignment PIN_BU28 -to SYS_RSTN_IN
set_instance_assignment -name IO_STANDARD "3.3-V LVCMOS" -to SYS_RSTN_IN
set_instance_assignment -name INPUT_TERMINATION OFF -to SYS_RSTN_IN

# LED
set_location_assignment PIN_CF12 -to LED_OUT
set_instance_assignment -name IO_STANDARD "3.3-V LVCMOS" -to LED_OUT
set_instance_assignment -name OUTPUT_TERMINATION "SERIES 40 OHM WITHOUT CALIBRATION" -to LED_OUT

# GTS reference clock (bank 4A)
set_location_assignment PIN_BB16 -to GTS_REFCLK_IN
set_location_assignment PIN_BB21 -to "GTS_REFCLK_IN(n)"
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to GTS_REFCLK_IN
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to "GTS_REFCLK_IN(n)"

# DP TX main link (bank 4A)
set i 0
foreach {p n} {BY7 BY10 BT7 BT10 BL7 BL10 BG7 BG10} {
    set_location_assignment PIN_$p -to DPTX_ML_OUT_P[$i]
    set_location_assignment PIN_$n -to DPTX_ML_OUT_N[$i]
    set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to DPTX_ML_OUT_P[$i]
    set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to DPTX_ML_OUT_N[$i]
    incr i
}

# DP TX AUX and HPD (1.8 V)
set_location_assignment PIN_B30 -to DPTX_HPD_IN
set_location_assignment PIN_B39 -to DPTX_AUX_RX_IN
set_location_assignment PIN_A33 -to DPTX_AUX_TX_OUT
set_location_assignment PIN_B23 -to DPTX_AUX_EN_OUT
set_location_assignment PIN_B35 -to DPTX_CAD_OUT
foreach pin {DPTX_HPD_IN DPTX_AUX_RX_IN DPTX_AUX_TX_OUT DPTX_AUX_EN_OUT DPTX_CAD_OUT} {
    set_instance_assignment -name IO_STANDARD "1.8-V LVCMOS" -to $pin
}
foreach pin {DPTX_HPD_IN DPTX_AUX_RX_IN} {
    set_instance_assignment -name INPUT_TERMINATION OFF -to $pin
}
foreach pin {DPTX_AUX_TX_OUT DPTX_AUX_EN_OUT DPTX_CAD_OUT} {
    set_instance_assignment -name SLEW_RATE 2 -to $pin
    set_instance_assignment -name OUTPUT_TERMINATION "SERIES 30 OHM WITHOUT CALIBRATION" -to $pin
}

# DP RX main link (bank 4A, the receivers of the DP TX channels)
set i 0
foreach {p n} {CB1 CB3 BV1 BV3 BN1 BN3 BJ1 BJ3} {
    set_location_assignment PIN_$p -to DPRX_ML_IN_P[$i]
    set_location_assignment PIN_$n -to DPRX_ML_IN_N[$i]
    set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to DPRX_ML_IN_P[$i]
    set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to DPRX_ML_IN_N[$i]
    incr i
}

# I2C of the DP redrivers (1.8 V, HVIO bank 5A)
set_location_assignment PIN_CK128 -to I2C_SCL_INOUT
set_location_assignment PIN_CK125 -to I2C_SDA_INOUT
foreach pin {I2C_SCL_INOUT I2C_SDA_INOUT} {
    set_instance_assignment -name IO_STANDARD "1.8-V LVCMOS" -to $pin
    set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to $pin
}

# DP RX AUX and HPD (1.8 V)
set_location_assignment PIN_B20 -to DPRX_HPD_OUT
set_location_assignment PIN_A23 -to DPRX_AUX_RX_IN
set_location_assignment PIN_A17 -to DPRX_AUX_TX_OUT
set_location_assignment PIN_B26 -to DPRX_AUX_EN_OUT
foreach pin {DPRX_HPD_OUT DPRX_AUX_RX_IN DPRX_AUX_TX_OUT DPRX_AUX_EN_OUT} {
    set_instance_assignment -name IO_STANDARD "1.8-V LVCMOS" -to $pin
}
set_instance_assignment -name INPUT_TERMINATION OFF -to DPRX_AUX_RX_IN
foreach pin {DPRX_HPD_OUT DPRX_AUX_TX_OUT DPRX_AUX_EN_OUT} {
    set_instance_assignment -name SLEW_RATE 2 -to $pin
    set_instance_assignment -name OUTPUT_TERMINATION "SERIES 30 OHM WITHOUT CALIBRATION" -to $pin
}

# HPS
# The HPS pins are dedicated, the location follows from the HPS pin muxing.
set_instance_assignment -name CURRENT_STRENGTH_NEW 4MA -to HPS_UART0_TX_OUT
set_instance_assignment -name WEAK_PULL_UP_DN_SEL PULL_UP_20 -to HPS_UART0_RX_IN

###
# Sources
###
# Platform Designer system
set_global_assignment -name QSYS_FILE dp_soc_ag5e.qsys

# GTS transceiver
set_global_assignment -name IP_FILE ip/dp_phy/dp_phy.ip
set_global_assignment -name IP_FILE ip/gts_rss/gts_rss.ip

# Video PLL
set_global_assignment -name IP_FILE ip/vid_pll/vid_pll.ip

# Library
set_global_assignment -name SYSTEMVERILOG_FILE $PRT_LIB/prt_lib_if.sv
set_global_assignment -name SYSTEMVERILOG_FILE $PRT_LIB/prt_lib_cmp.sv
set_global_assignment -name SYSTEMVERILOG_FILE $PRT_LIB/prt_lib_mem.sv
set_global_assignment -name SYSTEMVERILOG_FILE $SRC/lib/prt_dp_pkg.sv
set_global_assignment -name SYSTEMVERILOG_FILE $SRC/lib/prt_dp_lib_if.sv

# DPTX
foreach f {ctl lnk msa scrm skew sdp trn vid_vmap vid_fifo vid 8b10b_enc top apb} {
    set_global_assignment -name SYSTEMVERILOG_FILE $SRC/tx/prt_dptx_$f.sv
}

# DPRX
foreach f {ctl lnk msa pars scrm sdp trn trn_chk trn_ila vid_lmap vid_vmap vid_fifo vid 8b10b_dec top apb} {
    set_global_assignment -name SYSTEMVERILOG_FILE $SRC/rx/prt_dprx_$f.sv
}

# VTB
foreach f {cr dco ctl fifo tg tpg freq mon osd top apb} {
    set_global_assignment -name SYSTEMVERILOG_FILE $SRC/vtb/prt_vtb_$f.sv
}

# Policy maker
foreach f {aux exch hart hpd_rx hpd_tx irq msg mutex pio ram rom tmr top} {
    set_global_assignment -name SYSTEMVERILOG_FILE $SRC/pm/prt_dp_pm_$f.sv
}

# Misc
set_global_assignment -name SYSTEMVERILOG_FILE $SRC/misc/prt_hb.sv
set_global_assignment -name SYSTEMVERILOG_FILE $SRC/misc/prt_dp_clkdet.sv
set_global_assignment -name SYSTEMVERILOG_FILE $SRC/misc/prt_dp_msg_slv_egr.sv
set_global_assignment -name SYSTEMVERILOG_FILE $SRC/misc/prt_dp_msg_slv_ing.sv
set_global_assignment -name SYSTEMVERILOG_FILE $SRC/misc/prt_dp_msg_cdc.sv
set_global_assignment -name SYSTEMVERILOG_FILE $SRC/misc/prt_apb2lb.sv
set_global_assignment -name SYSTEMVERILOG_FILE $SRC/misc/prt_i2c_apb.sv

# Altera
set_global_assignment -name SYSTEMVERILOG_FILE ../../src/prt_hvio_pll_rcfg.sv

# Top
set_global_assignment -name SYSTEMVERILOG_FILE $REF/$PROJECT.sv

# Constraints
set_global_assignment -name SDC_FILE $REF/$PROJECT.sdc

project_close

###
# Generate the Platform Designer system
###
exec $QSYS/qsys-generate --search-path=$IP_PATH,$ dp_soc_ag5e.qsys --synthesis=VERILOG --quartus-project=$PROJECT --rev=$PROJECT 2>@1
foreach ip {dp_phy gts_rss vid_pll} {
    exec $QSYS/qsys-generate ip/$ip/$ip.ip --synthesis=VERILOG --quartus-project=$PROJECT --rev=$PROJECT 2>@1
}

###
# Compile
###
project_open $PROJECT -revision $PROJECT
execute_flow -compile
project_close
