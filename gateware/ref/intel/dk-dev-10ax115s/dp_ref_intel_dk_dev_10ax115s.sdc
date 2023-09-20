
set sys_clk {SYS_PLL_INST|iopll_0|sys_clk}
set rx_clk {PHY_INST|xcvr_native_a10_0|g_xcvr_native_insts[0]|rx_pma_clk}
set tx_clk {PHY_INST|xcvr_native_a10_0|g_xcvr_native_insts[0]|tx_pma_clk}
set_time_format -unit ns -decimal_places 3

#**************************************************************
# Create Clock
#**************************************************************
create_clock -name {clk_50} -period 20.000 [get_ports {CLK_IN}]
create_clock -name {vid_clk} -period 3.367 [get_ports {TENTIVA_VID_CLK_IN}]
create_clock -name {phy_ref_clk} -period 7.407 [get_ports {PHY_REFCLK_IN}]

derive_pll_clocks
derive_clock_uncertainty

# Clock groups
set_clock_groups -asynchronous -group [get_clocks $sys_clk] \
	-group [get_clocks {vid_clk}] \
	-group [get_clocks $tx_clk] \
	-group [get_clocks $rx_clk]

