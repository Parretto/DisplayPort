###
# Clocks
###
# System clock 200 MHz
create_clock -period 5.000 -name sys_clk_in -waveform {0.000 4.000} [get_ports CLK_IN_P]

# GT reference clock - 270 MHz
create_clock -period 3.703 -name gt_ref_clk -waveform {0.000 1.851} [get_ports {PHY_REFCLK_IN_P}]

# Link clock 8.1 Gbps @ 2 sublanes = 405 MHz
#create_clock -period 2.469 -name tx_lnk_clk -waveform {0.000 1.234} [get_pins {phy_2spl.PHY_INST/gtwiz_userclk_tx_usrclk2_out[0]}]
#create_clock -period 2.469 -name rx_lnk_clk -waveform {0.000 1.234} [get_pins {phy_2spl.PHY_INST/gtwiz_userclk_rx_usrclk2_out[0]}]

# Video clock 4K60p @ 2 pixel per clock = 297 MHz
create_clock -period 3.367 -name vid_clk -waveform {0.000 1.683} [get_ports TENTIVA_VID_CLK_IN_P]

# Rename auto generated clocks
create_generated_clock -name sys_clk [get_pins PLL_INST/inst/mmcme4_adv_inst/CLKOUT0]
create_generated_clock -name tx_lnk_clk [get_pins {PHY_INST/inst/gen_gtwizard_gthe4_top.gth_2spl_gtwizard_gthe4_inst/gen_gtwizard_gthe4.gen_channel_container[1].gen_enabled_channel.gthe4_channel_wrapper_inst/channel_inst/gthe4_channel_gen.gen_gthe4_channel_inst[1].GTHE4_CHANNEL_PRIM_INST/TXOUTCLK}]
create_generated_clock -name rx_lnk_clk [get_pins {PHY_INST/inst/gen_gtwizard_gthe4_top.gth_2spl_gtwizard_gthe4_inst/gen_gtwizard_gthe4.gen_channel_container[1].gen_enabled_channel.gthe4_channel_wrapper_inst/channel_inst/gthe4_channel_gen.gen_gthe4_channel_inst[3].GTHE4_CHANNEL_PRIM_INST/RXOUTCLK}]

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
set_property PACKAGE_PIN Y20 [get_ports TENTIVA_CLK_SEL_OUT]
set_property IOSTANDARD LVCMOS18 [get_ports TENTIVA_GT_CLK_LOCK_IN]
set_property PACKAGE_PIN P25 [get_ports TENTIVA_GT_CLK_LOCK_IN]
set_property IOSTANDARD LVCMOS18 [get_ports TENTIVA_VID_CLK_LOCK_IN]
set_property PACKAGE_PIN W25 [get_ports TENTIVA_VID_CLK_LOCK_IN]
set_property IOSTANDARD LVDS [get_ports TENTIVA_VID_CLK_IN_P]
set_property PACKAGE_PIN T25 [get_ports TENTIVA_VID_CLK_IN_P]
set_property PACKAGE_PIN U25 [get_ports TENTIVA_VID_CLK_IN_N]
set_property DIFF_TERM_ADV TERM_100 [get_ports TENTIVA_VID_CLK_IN_P]

###
# Tentiva DP14 TX card
# Tentiva Mezzanine slot 1
###
set_property IOSTANDARD LVCMOS18 [get_ports DPTX_AUX_EN_OUT]
set_property PACKAGE_PIN AC18 [get_ports DPTX_AUX_EN_OUT]

set_property IOSTANDARD LVCMOS18 [get_ports DPTX_AUX_TX_OUT]
set_property PACKAGE_PIN AE25 [get_ports DPTX_AUX_TX_OUT]

set_property IOSTANDARD LVCMOS18 [get_ports DPTX_AUX_RX_IN]
set_property PACKAGE_PIN AD18 [get_ports DPTX_AUX_RX_IN]

set_property IOSTANDARD LVCMOS18 [get_ports DPTX_HPD_IN]
set_property PACKAGE_PIN AB26 [get_ports DPTX_HPD_IN]

set_property IOSTANDARD LVCMOS18 [get_ports DPTX_I2C_SEL_OUT]
set_property PACKAGE_PIN AE26 [get_ports DPTX_I2C_SEL_OUT]

###
# Tentiva DP1.4 RX card
# Tentiva Mezzanine slot 0
###
set_property IOSTANDARD LVCMOS18 [get_ports DPRX_AUX_EN_OUT]
set_property PACKAGE_PIN AB17 [get_ports DPRX_AUX_EN_OUT]

set_property IOSTANDARD LVCMOS18 [get_ports DPRX_AUX_TX_OUT]
set_property PACKAGE_PIN AC17 [get_ports DPRX_AUX_TX_OUT]

set_property IOSTANDARD LVCMOS18 [get_ports DPRX_AUX_RX_IN]
set_property PACKAGE_PIN AF17 [get_ports DPRX_AUX_RX_IN]

set_property IOSTANDARD LVCMOS18 [get_ports DPRX_HPD_OUT]
set_property PACKAGE_PIN Y17 [get_ports DPRX_HPD_OUT]

set_property IOSTANDARD LVCMOS18 [get_ports DPRX_I2C_SEL_OUT]
set_property PACKAGE_PIN AE17 [get_ports DPRX_I2C_SEL_OUT]

set_property IOSTANDARD LVCMOS18 [get_ports DPRX_CABDET_IN]
set_property PACKAGE_PIN AA17 [get_ports DPRX_CABDET_IN]

# LED
set_property IOSTANDARD LVCMOS18 [get_ports {LED_OUT[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {LED_OUT[1]}]
set_property PACKAGE_PIN W21 [get_ports {LED_OUT[0]}]
set_property PACKAGE_PIN AC16 [get_ports {LED_OUT[1]}]

# UART
set_property IOSTANDARD LVCMOS33 [get_ports UART_TX_OUT]
set_property PACKAGE_PIN A13 [get_ports UART_TX_OUT]
set_property IOSTANDARD LVCMOS33 [get_ports UART_RX_IN]
set_property PACKAGE_PIN A12 [get_ports UART_RX_IN]

# Tentiva Rev.C
#set_property IOSTANDARD LVCMOS18 [get_ports UART_TX_OUT]
#set_property PACKAGE_PIN  [get_ports UART_TX_OUT]
#set_property IOSTANDARD LVCMOS18 [get_ports UART_RX_IN]
#set_property PACKAGE_PIN  [get_ports UART_RX_IN]

# I2C
set_property IOSTANDARD LVCMOS18 [get_ports I2C_SCL_INOUT]
set_property PACKAGE_PIN V26 [get_ports I2C_SCL_INOUT]

set_property IOSTANDARD LVCMOS18 [get_ports I2C_SDA_INOUT]
set_property PACKAGE_PIN U26 [get_ports I2C_SDA_INOUT]

# 200 MHz clock
set_property IOSTANDARD LVDS [get_ports CLK_IN_P]
set_property IOSTANDARD LVDS [get_ports CLK_IN_N]
set_property PACKAGE_PIN T24 [get_ports CLK_IN_P]
# The clock input has an external termination resistor on the board
#set_property DIFF_TERM_ADV TERM_100 [get_ports CLK_IN_P]

# PHY reference clock
set_property PACKAGE_PIN V6 [get_ports {PHY_REFCLK_IN_N}]
set_property PACKAGE_PIN V7 [get_ports {PHY_REFCLK_IN_P}]

# Aqua

# Tentiva Rev. C
set_property IOSTANDARD LVCMOS18 [get_ports AQUA_SEL_IN]
set_property PACKAGE_PIN N23 [get_ports AQUA_SEL_IN]
set_property IOSTANDARD LVCMOS18 [get_ports AQUA_CTL_IN]
set_property PACKAGE_PIN R26 [get_ports AQUA_CTL_IN]
set_property IOSTANDARD LVCMOS18 [get_ports AQUA_CLK_IN]
set_property PACKAGE_PIN P19 [get_ports AQUA_CLK_IN]
set_property IOSTANDARD LVCMOS18 [get_ports AQUA_DAT_IN]
set_property PACKAGE_PIN P23 [get_ports AQUA_DAT_IN]

# Tentiva Rev. D
#set_property IOSTANDARD LVCMOS18 [get_ports AQUA_SEL_IN]
#set_property PACKAGE_PIN  [get_ports AQUA_SEL_IN]
#set_property IOSTANDARD LVCMOS18 [get_ports AQUA_CTL_IN]
#set_property PACKAGE_PIN  [get_ports AQUA_CTL_IN]
#set_property IOSTANDARD LVCMOS18 [get_ports AQUA_CLK_IN]
#set_property PACKAGE_PIN  [get_ports AQUA_CLK_IN]
#set_property IOSTANDARD LVCMOS18 [get_ports AQUA_DAT_IN]
#set_property PACKAGE_PIN  [get_ports AQUA_DAT_IN]

###
# Timing
###

# Set asynchronous clock groups
set_clock_groups -asynchronous -group sys_clk
set_clock_groups -asynchronous -group tx_lnk_clk
set_clock_groups -asynchronous -group rx_lnk_clk
set_clock_groups -asynchronous -group vid_clk



