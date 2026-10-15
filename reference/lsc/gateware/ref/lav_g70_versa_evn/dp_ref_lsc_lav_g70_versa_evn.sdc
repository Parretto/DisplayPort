# System input clock (100 MHz)
create_clock -name {sys_clk} -period 10 [get_ports SYS_CLK_IN]

# PHY reference clock (135 MHz for every link rate)
create_clock -name {phy_ref_clk} -period 7.407407407 [get_ports PHY_REFCLK_IN_P]

# Video clock
create_clock -name {vid_clk} -period 6.666666667 [get_ports TENTIVA_VID_CLK_IN]
