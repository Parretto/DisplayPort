###
# Altera Agilex 5 DP reference design constraints
# (c) 2026 by Parretto B.V.
###

set_time_format -unit ns -decimal_places 3

# System clock (100 MHz)
create_clock -name sys_clk -period 10.000 [get_ports SYS_CLK_IN]

# GTS reference clock (150 MHz)
create_clock -name gts_refclk -period 6.667 [get_ports GTS_REFCLK_IN]

# DPTX and DPRX link clocks
# The GTS IP SDC constrains o_tx_clkout and o_rx_clkout at half the word clock (202.5 MHz at HBR3).
# With 2 symbols per lane (20-bit PMA width, no double width transfer) the clock is the word clock
# (405 MHz at HBR3, measured on the board). The clocks are created again with a divider of 1.
foreach_in_collection c [get_clocks -nowarn {PHY_INST|dp_phy|sip_inst|o_tx_clkout[*] PHY_INST|dp_phy|sip_inst|o_rx_clkout[*]}] {
    set name [get_clock_info -name $c]
    set master [get_clock_info -master_clock $c]
    set src [get_clock_info -master_clock_pin $c]
    set tgt [get_clock_info -targets $c]
    remove_clock $name
    create_generated_clock -name $name -source $src -master_clock $master -divide_by 1 -duty_cycle 50 -add $tgt
}

# Video clock
# The video PLL IP constrains the output at its default frequency (148.5 MHz).
# The application reconfigures the PLL up to 255 MHz for 7680 x 4320p30 (M = 306, C0 = 12),
# so the clock is created again at that frequency.
foreach_in_collection c [get_clocks -nowarn {VID_PLL_INST|vid_pll_outclk0}] {
    set name [get_clock_info -name $c]
    set master [get_clock_info -master_clock $c]
    set src [get_clock_info -master_clock_pin $c]
    set tgt [get_clock_info -targets $c]
    remove_clock $name
    create_generated_clock -name $name -source $src -master_clock $master -multiply_by 306 -divide_by 12 -duty_cycle 50 -add $tgt
}

derive_clock_uncertainty

# The system clock, the link clocks and the video clock are asynchronous
# The video PLL IP SDC is read first and creates its own reference clock (vid_pll_refclk) on SYS_CLK_IN,
# so that clock belongs to the system clock group.
set_clock_groups -asynchronous \
    -group [get_clocks -nowarn {sys_clk VID_PLL_INST|vid_pll_refclk VID_PLL_INST|*|ref_clk0}] \
    -group [get_clocks {PHY_INST|dp_phy|sip_inst|o_tx_clkout[*]}] \
    -group [get_clocks -nowarn {PHY_INST|dp_phy|sip_inst|o_rx_clkout[*]}] \
    -group [get_clocks -nowarn {VID_PLL_INST|vid_pll_outclk0 VID_PLL_INST|vid_pll_n_cnt_clk VID_PLL_INST|vid_pll_m_cnt_clk}]

# Synchronizers between the system clock and the link clocks
set_false_path -to [get_registers {phy_sts_meta[*]}]
set_false_path -to [get_registers {vid_lock_sync[0]}]

# Video clock recovery DCO in the VTB: toggle handshake between the system clock and the video clock
# (the increment is held stable while the toggle crosses)
set_false_path -to [get_registers {*|DCO_INST|vclk_sync[0] *|DCO_INST|ack_sync[0]}]
set_false_path -from [get_registers {*|DCO_INST|inc_hold[*]}] -to [get_registers {*|DCO_INST|vclk_inc[*]}]

# Asynchronous inputs and outputs
set_false_path -from [get_ports SYS_RSTN_IN]
set_false_path -from [get_ports {DPTX_HPD_IN DPTX_AUX_RX_IN DPRX_AUX_RX_IN}]
set_false_path -to [get_ports {DPTX_AUX_TX_OUT DPTX_AUX_EN_OUT DPTX_CAD_OUT DPRX_AUX_TX_OUT DPRX_AUX_EN_OUT DPRX_HPD_OUT}]
set_output_delay -clock sys_clk 0 [get_ports LED_OUT]
set_false_path -to [get_ports LED_OUT]
set_false_path -from [get_ports {I2C_SCL_INOUT I2C_SDA_INOUT}]
set_false_path -to [get_ports {I2C_SCL_INOUT I2C_SDA_INOUT}]
