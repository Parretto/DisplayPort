create_clock -name {sys_clk} -period 8 [get_ports SYS_CLK_IN]
create_clock -name {tx_lnk_clk} -period 7.407407407 [get_nets clk_from_tx_buf]
create_clock -name {rx_lnk_clk} -period 7.407407407 [get_nets clk_from_rx_buf]
create_clock -name {vid_clk} -period 6.666666667 [get_ports TENTIVA_VID_CLK_IN]
