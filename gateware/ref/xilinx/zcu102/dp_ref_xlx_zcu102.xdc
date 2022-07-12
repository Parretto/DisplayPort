###
# Clocks
###
# System clock 125 MHz
create_clock -period 8.000 -name sys_clk -waveform {0.000 4.000} [get_ports CLK_IN_P]

# Link clock 1.62 Gbps @ 2 sublanes = 81 MHz
#create_clock -period 12.345 -name tx_lnk_clk -waveform {0.000 6.1725} [get_pins {GT_INST/gtwiz_userclk_tx_usrclk2_out[0]}]

# Link clock 2.7 Gbps @ 2 sublanes = 135 MHz
#create_clock -period 7.407 -name tx_lnk_clk -waveform {0.000 3.704} [get_pins {GT_INST/gtwiz_userclk_tx_usrclk2_out[0]}]

# Link clock 8.1 Gbps @ 4 sublanes = 270 MHz

# Link clock 8.1 Gbps @ 2 sublanes = 405 MHz
create_clock -period 2.469 -name tx_lnk_clk -waveform {0.000 1.234} [get_pins {phy_2spl.PHY_INST/gtwiz_userclk_tx_usrclk2_out[0]}]
create_clock -period 2.469 -name rx_lnk_clk -waveform {0.000 1.234} [get_pins {phy_2spl.PHY_INST/gtwiz_userclk_rx_usrclk2_out[0]}]

# Video clock 4K60p @ 2 pixel per clock = 297 MHz
create_clock -period 3.367 -name tx_vid_clk -waveform {0.000 1.683} [get_ports TENTIVA_VID_CLK_IN_P]

# This constraint is required, else the drp pll can't be placed.
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_from_sys_ibuf_BUFGCE]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets SYS_IBUFDS_INST/O]

# This constraint must be set, else the video clock can't be routed.
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets VID_IBUFDS_INST/O]

###
# Pins
###

###
# Tentiva baseboard
###
set_property IOSTANDARD LVCMOS18 [get_ports TENTIVA_CLK_SEL_OUT]
set_property PACKAGE_PIN L15 [get_ports TENTIVA_CLK_SEL_OUT]
set_property IOSTANDARD LVCMOS18 [get_ports TENTIVA_GT_CLK_LOCK_IN]
set_property PACKAGE_PIN AB3 [get_ports TENTIVA_GT_CLK_LOCK_IN]
set_property IOSTANDARD LVCMOS18 [get_ports TENTIVA_VID_CLK_LOCK_IN]
set_property PACKAGE_PIN W5 [get_ports TENTIVA_VID_CLK_LOCK_IN]
set_property IOSTANDARD LVDS [get_ports TENTIVA_VID_CLK_IN_P]
set_property PACKAGE_PIN AA7 [get_ports TENTIVA_VID_CLK_IN_P]
set_property PACKAGE_PIN AA6 [get_ports TENTIVA_VID_CLK_IN_N]
set_property DIFF_TERM_ADV TERM_100 [get_ports TENTIVA_VID_CLK_IN_P]

###
# Tentiva DP14 TX card
# Tentiva Mezzanine slot 1
###
set_property IOSTANDARD LVCMOS18 [get_ports DPTX_AUX_EN_OUT]
set_property PACKAGE_PIN L12 [get_ports DPTX_AUX_EN_OUT]

set_property IOSTANDARD LVCMOS18 [get_ports DPTX_AUX_TX_OUT]
set_property PACKAGE_PIN U9 [get_ports DPTX_AUX_TX_OUT]

set_property IOSTANDARD LVCMOS18 [get_ports DPTX_AUX_RX_IN]
set_property PACKAGE_PIN K12 [get_ports DPTX_AUX_RX_IN]

set_property IOSTANDARD LVCMOS18 [get_ports DPTX_HPD_IN]
set_property PACKAGE_PIN V11 [get_ports DPTX_HPD_IN]

###
# Tentiva DP1.4 RX card
# Tentiva Mezzanine slot 0
###
set_property IOSTANDARD LVCMOS18 [get_ports DPRX_AUX_EN_OUT]
set_property PACKAGE_PIN M15 [get_ports DPRX_AUX_EN_OUT]

set_property IOSTANDARD LVCMOS18 [get_ports DPRX_AUX_TX_OUT]
set_property PACKAGE_PIN M14 [get_ports DPRX_AUX_TX_OUT]

set_property IOSTANDARD LVCMOS18 [get_ports DPRX_AUX_RX_IN]
set_property PACKAGE_PIN M13 [get_ports DPRX_AUX_RX_IN]

set_property IOSTANDARD LVCMOS18 [get_ports DPRX_HPD_OUT]
set_property PACKAGE_PIN P12 [get_ports DPRX_HPD_OUT]


# ZCU102
# LED
set_property IOSTANDARD LVCMOS33 [get_ports {LED_OUT[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED_OUT[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED_OUT[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED_OUT[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED_OUT[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED_OUT[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED_OUT[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED_OUT[0]}]
set_property PACKAGE_PIN AG14 [get_ports {LED_OUT[0]}]
set_property PACKAGE_PIN AF13 [get_ports {LED_OUT[1]}]
set_property PACKAGE_PIN AE13 [get_ports {LED_OUT[2]}]
set_property PACKAGE_PIN AJ14 [get_ports {LED_OUT[3]}]
set_property PACKAGE_PIN AJ15 [get_ports {LED_OUT[4]}]
set_property PACKAGE_PIN AH13 [get_ports {LED_OUT[5]}]
set_property PACKAGE_PIN AH14 [get_ports {LED_OUT[6]}]
set_property PACKAGE_PIN AL12 [get_ports {LED_OUT[7]}]

# DEBUG
set_property IOSTANDARD LVCMOS33 [get_ports {DEBUG_OUT[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {DEBUG_OUT[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {DEBUG_OUT[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {DEBUG_OUT[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {DEBUG_OUT[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {DEBUG_OUT[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {DEBUG_OUT[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {DEBUG_OUT[7]}]
set_property PACKAGE_PIN H14 [get_ports {DEBUG_OUT[0]}]
set_property PACKAGE_PIN J14 [get_ports {DEBUG_OUT[1]}]
set_property PACKAGE_PIN G14 [get_ports {DEBUG_OUT[2]}]
set_property PACKAGE_PIN G15 [get_ports {DEBUG_OUT[3]}]
set_property PACKAGE_PIN J15 [get_ports {DEBUG_OUT[4]}]
set_property PACKAGE_PIN J16 [get_ports {DEBUG_OUT[5]}]
set_property PACKAGE_PIN G16 [get_ports {DEBUG_OUT[6]}]
set_property PACKAGE_PIN H16 [get_ports {DEBUG_OUT[7]}]

#set_property IOSTANDARD LVCMOS33 [get_ports DEBUG_REF_CLK_OUT]
#set_property PACKAGE_PIN H13 [get_ports DEBUG_REF_CLK_OUT]
#set_property IOSTANDARD LVCMOS33 [get_ports DEBUG_LNK_CLK_OUT]
#set_property PACKAGE_PIN G13 [get_ports DEBUG_LNK_CLK_OUT]

# Reset

# UART
set_property IOSTANDARD LVCMOS33 [get_ports UART_TX_OUT]
set_property PACKAGE_PIN F13 [get_ports UART_TX_OUT]

set_property IOSTANDARD LVCMOS33 [get_ports UART_RX_IN]
set_property PACKAGE_PIN E13 [get_ports UART_RX_IN]

# I2C
set_property IOSTANDARD LVCMOS33 [get_ports I2C_SCL_INOUT]
set_property PACKAGE_PIN K20 [get_ports I2C_SCL_INOUT]

set_property IOSTANDARD LVCMOS33 [get_ports I2C_SDA_INOUT]
set_property PACKAGE_PIN L20 [get_ports I2C_SDA_INOUT]

# 125 MHz clock
set_property IOSTANDARD LVDS_25 [get_ports CLK_IN_P]
set_property IOSTANDARD LVDS_25 [get_ports CLK_IN_N]
set_property PACKAGE_PIN G21 [get_ports CLK_IN_P]
# The clock input has an external termination resistor on the board
#set_property DIFF_TERM_ADV TERM_100 [get_ports CLK_IN_P]

# GT reference clock
set_property PACKAGE_PIN G7 [get_ports GT_REFCLK_IN_N]
set_property PACKAGE_PIN G8 [get_ports GT_REFCLK_IN_P]

# Aqua
set_property IOSTANDARD LVCMOS33 [get_ports AQUA_SEL_IN]
set_property PACKAGE_PIN A20 [get_ports AQUA_SEL_IN]
set_property IOSTANDARD LVCMOS33 [get_ports AQUA_CTL_IN]
set_property PACKAGE_PIN B20 [get_ports AQUA_CTL_IN]
set_property IOSTANDARD LVCMOS33 [get_ports AQUA_CLK_IN]
set_property PACKAGE_PIN A22 [get_ports AQUA_CLK_IN]
set_property IOSTANDARD LVCMOS33 [get_ports AQUA_DAT_IN]
set_property PACKAGE_PIN A21 [get_ports AQUA_DAT_IN]

###
# Timing
###

# PRT_DP_LIB_RST
set _xlnx_shared_i0 [get_cells -hierarchical -filter {NAME =~ */prt_dp_lib_dclk_rst_reg*}]
set_false_path -through [get_cells -hierarchical -filter {NAME =~ */prt_dp_lib_sclk_rst_reg*}] -to $_xlnx_shared_i0

# PRT_DP_LIB_MEM_RAM_DC / PRT_DP_LIB_MEM_FIFO
set _xlnx_shared_i1 [get_cells -hierarchical -filter {NAME =~ */prt_dp_lib_mem_bclk_dout_reg*}]
set _xlnx_shared_i2 [get_cells -hierarchical -filter {NAME =~ */prt_dp_lib_mem_aclk_ram_reg*}]
set_false_path -through $_xlnx_shared_i2 -to $_xlnx_shared_i1

# PRT_DP_LIB_CDC_GRAY
set _xlnx_shared_i3 [get_cells -hierarchical -filter {NAME =~ */prt_dp_lib_cdc_gray_dclk_cap_reg[0]*}]
set_false_path -to $_xlnx_shared_i3

# PRT_DP_LIB_CDC_VEC
set _xlnx_shared_i4 [get_cells -hierarchical -filter {NAME =~ */prt_dp_lib_cdc_vec_dclk_cap_reg[0]*}]
set_false_path -to $_xlnx_shared_i4
set_false_path -to [get_cells -hierarchical -filter {NAME =~ */prt_dp_lib_cdc_vec_dclk_hs_reg[0]*}]
set_false_path -to [get_cells -hierarchical -filter {NAME =~ */prt_dp_lib_cdc_vec_sclk_hs_reg[0]*}]

# PRT_DP_LIB_CDC_BIT
set_false_path -to [get_cells -hierarchical -filter {NAME =~ */prt_dp_lib_cdc_bit_dclk_dat_reg[0]*}]


