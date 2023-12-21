###
# Clocks
###

# System clock 125 MHz
create_clock -period 8.000 -name sys_clk_in -waveform {0.000 4.000} [get_ports CLK_IN_P]

# GT reference clock
create_clock -period 7.407 -name gt_ref_clk -waveform {0.000 3.703} [get_ports {GT_REFCLK_IN_P[0]}]

# Link clock 8.1 Gbps @ 2 sublanes = 405 MHz
create_clock -period 2.469 -name tx_lnk_clk -waveform {0.000 1.234} [get_pins {phy_2spl.PHY_INST/gtwiz_userclk_tx_usrclk2_out[0]}]
create_clock -period 2.469 -name rx_lnk_clk -waveform {0.000 1.234} [get_pins {phy_2spl.PHY_INST/gtwiz_userclk_rx_usrclk2_out[0]}]

# Video clock 4K60p @ 2 pixel per clock = 297 MHz
create_clock -period 3.367 -name vid_clk -waveform {0.000 1.683} [get_ports TENTIVA_VID_CLK_IN_P]

# Rename auto generated clocks
create_generated_clock -name sys_clk [get_pins PLL_INST/inst/mmcme4_adv_inst/CLKOUT0]

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

# UART
# ZCU102
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
set_property PACKAGE_PIN G8 [get_ports GT_REFCLK_IN_P[0]]
set_property PACKAGE_PIN G7 [get_ports GT_REFCLK_IN_N[0]]
set_property PACKAGE_PIN L8 [get_ports GT_REFCLK_IN_P[1]]
set_property PACKAGE_PIN L7 [get_ports GT_REFCLK_IN_N[1]]

###
# Timing
###

# Set asynchronous clock groups
set_clock_groups -asynchronous -group sys_clk
set_clock_groups -asynchronous -group tx_lnk_clk
set_clock_groups -asynchronous -group rx_lnk_clk
set_clock_groups -asynchronous -group vid_clk
