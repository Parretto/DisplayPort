###
# AMD Zynq UltraScale+ DP reference design SoC (block design)
# (c) 2026 by Parretto B.V.
#
# Sourced by build_proj.tcl.
#
# The processing system runs the DP application bare metal on Cortex-A53 #0 from the on-chip
# memory (OCM). The DDR controller is not used.
# The PL peripherals are on the low power domain master (M_AXI_HPM0_LPD), behind an AXI to APB
# bridge. The APB ports go to the top level, where the DP cores are instantiated.
#
# Clocks
#   pl_clk0     100 MHz     system clock
#   pl_clk1      40 MHz     DRP and free running clock of the transceivers
# Both come from the IOPLL (1000 MHz). Left to Vivado they may come from the RPLL, which on the
# ZU9EG gives 96.97 and 39.51 MHz; the CPLL calibration of the receivers then fails (it allows 1%).
#
# Address map (M_AXI_HPM0_LPD, see prt_dp_app.h)
#   0x8000_0000   PIO (AXI GPIO, channel 1 out / channel 2 in)
#   0x8000_1000   DPTX
#   0x8000_2000   VTB
#   0x8000_3000   PHY
#   0x8000_4000   DPRX
#   0x8000_5000   I2C
#
# Interrupts (pl_ps_irq0)
#   [0]  DPTX    (GIC SPI 89, ID 121)
#   [1]  DPRX    (GIC SPI 90, ID 122)
###

set BD dp_soc_zu9eg

create_bd_design $BD

###
# Processing system
###
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e ps]

set_property -dict [list \
    CONFIG.PSU__PSS_REF_CLK__FREQMHZ                {33.333} \
    CONFIG.PSU_BANK_0_IO_STANDARD                   {LVCMOS18} \
    CONFIG.PSU_BANK_1_IO_STANDARD                   {LVCMOS18} \
    CONFIG.PSU_BANK_2_IO_STANDARD                   {LVCMOS18} \
    CONFIG.PSU_BANK_3_IO_STANDARD                   {LVCMOS18} \
    CONFIG.PSU__DDRC__ENABLE                        {0} \
    CONFIG.PSU__UART0__PERIPHERAL__ENABLE           {1} \
    CONFIG.PSU__UART0__PERIPHERAL__IO               {EMIO} \
    CONFIG.PSU__UART0__BAUD_RATE                    {115200} \
    CONFIG.PSU__CRL_APB__UART0_REF_CTRL__FREQMHZ    {100} \
    CONFIG.PSU__TTC0__PERIPHERAL__ENABLE            {1} \
    CONFIG.PSU__USE__M_AXI_GP0                      {0} \
    CONFIG.PSU__USE__M_AXI_GP1                      {0} \
    CONFIG.PSU__USE__M_AXI_GP2                      {1} \
    CONFIG.PSU__MAXIGP2__DATA_WIDTH                 {32} \
    CONFIG.PSU__USE__IRQ0                           {1} \
    CONFIG.PSU__FPGA_PL0_ENABLE                     {1} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__SRCSEL       {IOPLL} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ      {100} \
    CONFIG.PSU__FPGA_PL1_ENABLE                     {1} \
    CONFIG.PSU__CRL_APB__PL1_REF_CTRL__SRCSEL       {IOPLL} \
    CONFIG.PSU__CRL_APB__PL1_REF_CTRL__FREQMHZ      {40} \
] $ps

###
# Reset
###
set rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst]
connect_bd_net [get_bd_pins ps/pl_clk0] [get_bd_pins rst/slowest_sync_clk]
connect_bd_net [get_bd_pins ps/pl_resetn0] [get_bd_pins rst/ext_reset_in]

###
# Interconnect
###
set sc [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect sc]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {2}] $sc

connect_bd_net [get_bd_pins ps/pl_clk0] [get_bd_pins ps/maxihpm0_lpd_aclk] [get_bd_pins sc/aclk]
connect_bd_net [get_bd_pins rst/interconnect_aresetn] [get_bd_pins sc/aresetn]
connect_bd_intf_net [get_bd_intf_pins ps/M_AXI_HPM0_LPD] [get_bd_intf_pins sc/S00_AXI]

# PIO
set pio [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio pio]
set_property -dict [list \
    CONFIG.C_GPIO_WIDTH         {32} \
    CONFIG.C_ALL_OUTPUTS        {1} \
    CONFIG.C_IS_DUAL            {1} \
    CONFIG.C_GPIO2_WIDTH        {32} \
    CONFIG.C_ALL_INPUTS_2       {1} \
] $pio
connect_bd_net [get_bd_pins ps/pl_clk0] [get_bd_pins pio/s_axi_aclk]
connect_bd_net [get_bd_pins rst/peripheral_aresetn] [get_bd_pins pio/s_axi_aresetn]
connect_bd_intf_net [get_bd_intf_pins sc/M00_AXI] [get_bd_intf_pins pio/S_AXI]

# APB bridge
set APB_PORTS {dptx vtb phy dprx i2c}
set apb [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_apb_bridge apb]
set_property -dict [list CONFIG.C_APB_NUM_SLAVES [llength $APB_PORTS]] $apb
connect_bd_net [get_bd_pins ps/pl_clk0] [get_bd_pins apb/s_axi_aclk]
connect_bd_net [get_bd_pins rst/peripheral_aresetn] [get_bd_pins apb/s_axi_aresetn]
connect_bd_intf_net [get_bd_intf_pins sc/M01_AXI] [get_bd_intf_pins apb/AXI4_LITE]

###
# Ports
###

# Clock and reset
create_bd_port -dir O -type clk sys_clk
connect_bd_net [get_bd_pins ps/pl_clk0] [get_bd_ports sys_clk]
create_bd_port -dir O -type clk drp_clk
connect_bd_net [get_bd_pins ps/pl_clk1] [get_bd_ports drp_clk]
create_bd_port -dir O -type rst sys_rstn
connect_bd_net [get_bd_pins rst/peripheral_aresetn] [get_bd_ports sys_rstn]

# UART
create_bd_port -dir O uart_txd
create_bd_port -dir I uart_rxd
connect_bd_net [get_bd_pins ps/emio_uart0_txd] [get_bd_ports uart_txd]
connect_bd_net [get_bd_pins ps/emio_uart0_rxd] [get_bd_ports uart_rxd]

# PIO
create_bd_port -dir O -from 31 -to 0 pio_out
create_bd_port -dir I -from 31 -to 0 pio_in
connect_bd_net [get_bd_pins pio/gpio_io_o] [get_bd_ports pio_out]
connect_bd_net [get_bd_pins pio/gpio2_io_i] [get_bd_ports pio_in]

# Interrupts
create_bd_port -dir I -from 1 -to 0 -type intr irq
connect_bd_net [get_bd_ports irq] [get_bd_pins ps/pl_ps_irq0]

# APB
set i 0
foreach p $APB_PORTS {
    set port [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:apb_rtl:1.0 $p]
    connect_bd_intf_net [get_bd_intf_pins apb/APB_M[expr {$i ? $i + 1 : ""}]] $port
    incr i
}

###
# Address map
###
assign_bd_address -target_address_space /ps/Data -offset 0x80000000 -range 4K [get_bd_addr_segs pio/S_AXI/Reg]
set i 1
foreach p $APB_PORTS {
    assign_bd_address -target_address_space /ps/Data -offset [expr {0x80000000 + ($i * 0x1000)}] -range 4K [get_bd_addr_segs $p/Reg]
    incr i
}

validate_bd_design
save_bd_design
