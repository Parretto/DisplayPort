###
# DP reference design constraints
# AMD ZCU102 (ZU9EG) with the Tentiva FMC on HPC0
# (c) 2026 by Parretto B.V.
###

###
# Clocks
###
# The system clock is PL clock 0 of the processing system (100 MHz, clk_pl_0), the DRP and free
# running clock of the transceivers PL clock 1 (40 MHz, clk_pl_1). Their constraints come with
# the processing system IP.

# GT reference clock (270 MHz)
create_clock -period 3.703 -name gt_refclk [get_ports GT_REFCLK_IN_P]

# Video clock (4K60 at 4 pixels per clock = 148.5 MHz)
create_clock -period 6.734 -name vid_clk [get_ports TENTIVA_VID_CLK_IN_P]

# Link clocks
# The transceiver IP is configured for 5.4 Gbps, so Vivado derives 135 MHz user clocks. The
# application changes the line rate up to 8.1 Gbps, where the link clocks run at 405 MHz
# (two symbols per lane). The TX user clock comes from the TX master channel (X1Y8, instance 0),
# the RX user clock from the RX master channel (X1Y10, instance 2, DP lane 0).
create_clock -period 2.469 -name tx_lnk_clk [get_pins -hier -filter {NAME =~ PHY_INST/*gen_gthe4_channel_inst[0].GTHE4_CHANNEL_PRIM_INST/TXOUTCLK}]
create_clock -period 2.469 -name rx_lnk_clk [get_pins -hier -filter {NAME =~ PHY_INST/*gen_gthe4_channel_inst[2].GTHE4_CHANNEL_PRIM_INST/RXOUTCLK}]

# Clock domain crossings
# The system, video and link clocks are asynchronous. They are not put in asynchronous clock
# groups: that would override the max delay constraints the dual clock FIFOs (XPM distributed RAM)
# bring along, and leave the RAM data paths into the read clock domain unconstrained.
# Every crossing gets a datapath only max delay of the faster clock period instead.
set_max_delay -datapath_only -from [get_clocks clk_pl_0]   -to [get_clocks vid_clk]    6.734
set_max_delay -datapath_only -from [get_clocks clk_pl_0]   -to [get_clocks tx_lnk_clk] 2.469
set_max_delay -datapath_only -from [get_clocks clk_pl_0]   -to [get_clocks rx_lnk_clk] 2.469
set_max_delay -datapath_only -from [get_clocks vid_clk]    -to [get_clocks clk_pl_0]   6.734
set_max_delay -datapath_only -from [get_clocks vid_clk]    -to [get_clocks tx_lnk_clk] 2.469
set_max_delay -datapath_only -from [get_clocks vid_clk]    -to [get_clocks rx_lnk_clk] 2.469
set_max_delay -datapath_only -from [get_clocks tx_lnk_clk] -to [get_clocks clk_pl_0]   2.469
set_max_delay -datapath_only -from [get_clocks tx_lnk_clk] -to [get_clocks vid_clk]    2.469
set_max_delay -datapath_only -from [get_clocks tx_lnk_clk] -to [get_clocks rx_lnk_clk] 2.469
set_max_delay -datapath_only -from [get_clocks rx_lnk_clk] -to [get_clocks clk_pl_0]   2.469
set_max_delay -datapath_only -from [get_clocks rx_lnk_clk] -to [get_clocks vid_clk]    2.469
set_max_delay -datapath_only -from [get_clocks rx_lnk_clk] -to [get_clocks tx_lnk_clk] 2.469
set_max_delay -datapath_only -from [get_clocks clk_pl_1]   -to [get_clocks clk_pl_0]   10.000
set_max_delay -datapath_only -from [get_clocks clk_pl_0]   -to [get_clocks clk_pl_1]   10.000
set_max_delay -datapath_only -from [get_clocks clk_pl_1]   -to [get_clocks tx_lnk_clk] 2.469
set_max_delay -datapath_only -from [get_clocks clk_pl_1]   -to [get_clocks rx_lnk_clk] 2.469
set_max_delay -datapath_only -from [get_clocks tx_lnk_clk] -to [get_clocks clk_pl_1]   2.469
set_max_delay -datapath_only -from [get_clocks rx_lnk_clk] -to [get_clocks clk_pl_1]   2.469

# The GT reference clock (heartbeat) and the clocks of the CPLL calibration are asynchronous to the rest
set_clock_groups -asynchronous \
    -group [get_clocks -include_generated_clocks gt_refclk] \
    -group [get_clocks -of_objects [get_pins -hier -filter {NAME =~ PHY_INST/*outclkmon_inst/O}]] \
    -group [get_clocks {clk_pl_0 clk_pl_1 vid_clk tx_lnk_clk rx_lnk_clk}]

###
# Tentiva (FMC HPC0)
###
# Video clock
set_property IOSTANDARD LVDS [get_ports TENTIVA_VID_CLK_IN_P]
set_property PACKAGE_PIN AA7 [get_ports TENTIVA_VID_CLK_IN_P]
set_property PACKAGE_PIN AA6 [get_ports TENTIVA_VID_CLK_IN_N]
set_property DIFF_TERM_ADV TERM_100 [get_ports TENTIVA_VID_CLK_IN_P]

# UART (PS UART0 over EMIO)
set_property IOSTANDARD LVCMOS18 [get_ports UART_TX_OUT]
set_property PACKAGE_PIN L10 [get_ports UART_TX_OUT]
set_property IOSTANDARD LVCMOS18 [get_ports UART_RX_IN]
set_property PACKAGE_PIN M10 [get_ports UART_RX_IN]

# DPTX card (mezzanine slot 1)
set_property IOSTANDARD LVCMOS18 [get_ports DPTX_AUX_EN_OUT]
set_property PACKAGE_PIN L12 [get_ports DPTX_AUX_EN_OUT]
set_property IOSTANDARD LVCMOS18 [get_ports DPTX_AUX_TX_OUT]
set_property PACKAGE_PIN U9 [get_ports DPTX_AUX_TX_OUT]
set_property IOSTANDARD LVCMOS18 [get_ports DPTX_AUX_RX_IN]
set_property PACKAGE_PIN K12 [get_ports DPTX_AUX_RX_IN]
set_property IOSTANDARD LVCMOS18 [get_ports DPTX_HPD_IN]
set_property PACKAGE_PIN V11 [get_ports DPTX_HPD_IN]
set_property IOSTANDARD LVCMOS18 [get_ports DPTX_I2C_SEL_OUT]
set_property PACKAGE_PIN U8 [get_ports DPTX_I2C_SEL_OUT]

# DPRX card (mezzanine slot 0)
set_property IOSTANDARD LVCMOS18 [get_ports DPRX_AUX_EN_OUT]
set_property PACKAGE_PIN M15 [get_ports DPRX_AUX_EN_OUT]
set_property IOSTANDARD LVCMOS18 [get_ports DPRX_AUX_TX_OUT]
set_property PACKAGE_PIN M14 [get_ports DPRX_AUX_TX_OUT]
set_property IOSTANDARD LVCMOS18 [get_ports DPRX_AUX_RX_IN]
set_property PACKAGE_PIN M13 [get_ports DPRX_AUX_RX_IN]
set_property IOSTANDARD LVCMOS18 [get_ports DPRX_HPD_OUT]
set_property PACKAGE_PIN P12 [get_ports DPRX_HPD_OUT]
set_property IOSTANDARD LVCMOS18 [get_ports DPRX_I2C_SEL_OUT]
set_property PACKAGE_PIN N13 [get_ports DPRX_I2C_SEL_OUT]

# GT reference clock (MGTREFCLK0 of bank 229, FMC HPC0 GBTCLK0)
# The channel locations (X1Y8 - X1Y11) come with the transceiver IP.
set_property PACKAGE_PIN G8 [get_ports GT_REFCLK_IN_P]
set_property PACKAGE_PIN G7 [get_ports GT_REFCLK_IN_N]

###
# ZCU102
###
# I2C (PL I2C1, to the I2C muxes U34 and U135)
set_property IOSTANDARD LVCMOS33 [get_ports I2C_SCL_INOUT]
set_property PACKAGE_PIN K20 [get_ports I2C_SCL_INOUT]
set_property IOSTANDARD LVCMOS33 [get_ports I2C_SDA_INOUT]
set_property PACKAGE_PIN L20 [get_ports I2C_SDA_INOUT]

# LED (GPIO_LED_0 - 7)
set_property IOSTANDARD LVCMOS33 [get_ports {LED_OUT[*]}]
set_property PACKAGE_PIN AG14 [get_ports {LED_OUT[0]}]
set_property PACKAGE_PIN AF13 [get_ports {LED_OUT[1]}]
set_property PACKAGE_PIN AE13 [get_ports {LED_OUT[2]}]
set_property PACKAGE_PIN AJ14 [get_ports {LED_OUT[3]}]
set_property PACKAGE_PIN AJ15 [get_ports {LED_OUT[4]}]
set_property PACKAGE_PIN AH13 [get_ports {LED_OUT[5]}]
set_property PACKAGE_PIN AH14 [get_ports {LED_OUT[6]}]
set_property PACKAGE_PIN AL12 [get_ports {LED_OUT[7]}]

###
# Bitstream
###
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
