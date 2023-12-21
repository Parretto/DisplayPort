###
# Clocks
###
# System clock 200 MHz
create_clock -period 5.000 -name sys_clk_in -waveform {0.000 2.500} [get_ports CLK_IN_P]

# GT reference clock
create_clock -period 7.407 -name gt_ref_clk -waveform {0.000 3.703} [get_ports {GT_REFCLK_IN_P[0]}]

# Video clock 4K60p @ 4 pixel per clock = 148.5 MHz
create_clock -period 6.734 -name vid_clk -waveform {0.000 3.367} [get_ports TENTIVA_VID_CLK_IN_P]

# Rename auto generated clocks
create_generated_clock -name sys_clk [get_pins PLL_INST/inst/mmcm_adv_inst/CLKOUT0]
create_generated_clock -name tx_lnk_clk [get_pins PHY_INST/TXPLL_INST/CLKOUT1]
create_generated_clock -name rx_lnk_clk [get_pins PHY_INST/RXPLL_INST/CLKOUT1]

###
# Pins
###

###
# Tentiva baseboard
###
set_property IOSTANDARD LVCMOS18 [get_ports TENTIVA_CLK_SEL_OUT]
set_property PACKAGE_PIN AL34 [get_ports TENTIVA_CLK_SEL_OUT]
set_property IOSTANDARD LVCMOS18 [get_ports TENTIVA_GT_CLK_LOCK_IN]
set_property PACKAGE_PIN AG32 [get_ports TENTIVA_GT_CLK_LOCK_IN]
set_property IOSTANDARD LVCMOS18 [get_ports TENTIVA_VID_CLK_LOCK_IN]
set_property PACKAGE_PIN AE27 [get_ports TENTIVA_VID_CLK_LOCK_IN]
set_property IOSTANDARD DIFF_HSTL_II_18 [get_ports TENTIVA_VID_CLK_IN_P]
set_property PACKAGE_PIN AL28 [get_ports TENTIVA_VID_CLK_IN_P]
set_property PACKAGE_PIN AL29 [get_ports TENTIVA_VID_CLK_IN_N]
#set_property DIFF_TERM_ADV TERM_100 [get_ports TENTIVA_VID_CLK_IN_P]

###
# Tentiva DP14 TX card
# Tentiva Mezzanine slot 1
###
set_property IOSTANDARD LVCMOS18 [get_ports DPTX_AUX_EN_OUT]
set_property PACKAGE_PIN AN31 [get_ports DPTX_AUX_EN_OUT]

set_property IOSTANDARD LVCMOS18 [get_ports DPTX_AUX_TX_OUT]
set_property PACKAGE_PIN AN33 [get_ports DPTX_AUX_TX_OUT]

set_property IOSTANDARD LVCMOS18 [get_ports DPTX_AUX_RX_IN]
set_property PACKAGE_PIN AP31 [get_ports DPTX_AUX_RX_IN]

set_property IOSTANDARD LVCMOS18 [get_ports DPTX_HPD_IN]
set_property PACKAGE_PIN AP28 [get_ports DPTX_HPD_IN]

###
# Tentiva DP1.4 RX card
# Tentiva Mezzanine slot 0
###
set_property IOSTANDARD LVCMOS18 [get_ports DPRX_AUX_EN_OUT]
set_property PACKAGE_PIN AL32 [get_ports DPRX_AUX_EN_OUT]

set_property IOSTANDARD LVCMOS18 [get_ports DPRX_AUX_TX_OUT]
set_property PACKAGE_PIN AM32 [get_ports DPRX_AUX_TX_OUT]

set_property IOSTANDARD LVCMOS18 [get_ports DPRX_AUX_RX_IN]
set_property PACKAGE_PIN AJ34 [get_ports DPRX_AUX_RX_IN]

set_property IOSTANDARD LVCMOS18 [get_ports DPRX_HPD_OUT]
set_property PACKAGE_PIN AJ25 [get_ports DPRX_HPD_OUT]

# LED
set_property IOSTANDARD LVCMOS18 [get_ports {LED_OUT[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {LED_OUT[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {LED_OUT[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {LED_OUT[3]}]
set_property PACKAGE_PIN W28 [get_ports {LED_OUT[0]}]
set_property PACKAGE_PIN W29 [get_ports {LED_OUT[1]}]
set_property PACKAGE_PIN U24 [get_ports {LED_OUT[2]}]
set_property PACKAGE_PIN M26 [get_ports {LED_OUT[3]}]

# Tentiva Rev.C
set_property IOSTANDARD LVCMOS18 [get_ports UART_TX_OUT]
set_property PACKAGE_PIN AL33 [get_ports UART_TX_OUT]
set_property IOSTANDARD LVCMOS18 [get_ports UART_RX_IN]
set_property PACKAGE_PIN AK33 [get_ports UART_RX_IN]

# I2C
set_property IOSTANDARD LVCMOS33 [get_ports I2C_SCL_INOUT]
set_property PACKAGE_PIN T9 [get_ports I2C_SCL_INOUT]

set_property IOSTANDARD LVCMOS33 [get_ports I2C_SDA_INOUT]
set_property PACKAGE_PIN U9 [get_ports I2C_SDA_INOUT]

# 200 MHz clock
set_property IOSTANDARD DIFF_SSTL15 [get_ports CLK_IN_P]
set_property IOSTANDARD DIFF_SSTL15 [get_ports CLK_IN_N]
set_property PACKAGE_PIN AD6 [get_ports CLK_IN_P]

# GT pins
set_property PACKAGE_PIN AG20 [get_ports {GT_REFCLK_IN_P[0]}]
set_property PACKAGE_PIN AH20 [get_ports {GT_REFCLK_IN_N[0]}]
set_property PACKAGE_PIN AG14 [get_ports {GT_REFCLK_IN_P[1]}]
set_property PACKAGE_PIN AH14 [get_ports {GT_REFCLK_IN_N[1]}]

set_property PACKAGE_PIN AL18 [get_ports {GT_RX_IN_P[0]}]
set_property PACKAGE_PIN AN19 [get_ports {GT_TX_OUT_P[0]}]
set_property PACKAGE_PIN AJ19 [get_ports {GT_RX_IN_P[1]}]
set_property PACKAGE_PIN AN21 [get_ports {GT_TX_OUT_P[1]}]
set_property PACKAGE_PIN AL20 [get_ports {GT_RX_IN_P[2]}]
set_property PACKAGE_PIN AL22 [get_ports {GT_TX_OUT_P[2]}]
set_property PACKAGE_PIN AJ21 [get_ports {GT_RX_IN_P[3]}]
set_property PACKAGE_PIN AN23 [get_ports {GT_TX_OUT_P[3]}]

###
# Timing
###

# Set asynchronous clock groups
set_clock_groups -asynchronous -group sys_clk
set_clock_groups -asynchronous -group tx_lnk_clk
set_clock_groups -asynchronous -group rx_lnk_clk
set_clock_groups -asynchronous -group vid_clk
