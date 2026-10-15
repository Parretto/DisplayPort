###
# Altera Agilex 5 DP reference design Platform Designer system
# (c) 2026 by Parretto B.V.
#
# Run with: qsys-script --script=dp_soc_ag5e.tcl --quartus-project=<project>
###

package require qsys

create_system dp_soc_ag5e
set_project_property DEVICE_FAMILY {Agilex 5}
set_project_property DEVICE A5ED065AB32AE1V
set_project_property HIDE_FROM_IP_CATALOG {true}

###
# Clock and reset
###
add_component clk ip/dp_soc_ag5e/dp_soc_ag5e_clk.ip clock_source clk
load_component clk
set_component_parameter_value clockFrequency {100000000.0}
set_component_parameter_value clockFrequencyKnown {1}
set_component_parameter_value resetSynchronousEdges {DEASSERT}
save_component
set_interface_property clk EXPORT_OF clk.clk_in
set_interface_property rst EXPORT_OF clk.clk_in_reset

###
# Reset release
# The fabric must be held in reset until the device has entered user mode.
###
add_component rst_rel ip/dp_soc_ag5e/dp_soc_ag5e_rst_rel.ip altera_s10_user_rst_clkgate rst_rel
load_component rst_rel
set_component_parameter_value outputType {Reset Interface}
save_component
set_interface_property ninit_done EXPORT_OF rst_rel.ninit_done

###
# HPS
###
add_component hps ip/dp_soc_ag5e/dp_soc_ag5e_hps.ip intel_agilex_5_soc hps
load_component hps

# HPS IO pins
# Only the HPS oscillator and UART0 are used.
# The HPS IO numbering follows the Agilex 5 modular development kit schematic (see the Altera GHRD).
set hps_io {}
for {set i 0} {$i < 48} {incr i} {
    switch $i {
        2       {lappend hps_io UART0:TX}
        3       {lappend hps_io UART0:RX}
        11      {lappend hps_io HCLK:HPS_OSC_CLK}
        default {lappend hps_io NONE}
    }
}
set_component_parameter_value HPS_IO_Enable $hps_io
set_component_parameter_value UART0_PinMuxing {IO}
set_component_parameter_value UART0_Mode {No_flow_control}

# External HPS oscillator (25 MHz on the board)
set_component_parameter_value eosc1_clk_mhz {25.0}

# No HPS DDR. The application runs from the HPS on-chip RAM.
set_component_parameter_value EMIF_AXI_Enable {0}
set_component_parameter_value EMIF_Topology {0}

# Bridges
# Only the lightweight HPS to FPGA bridge is used.
set_component_parameter_value H2F_Width {0}
set_component_parameter_value LWH2F_Width {32}
set_component_parameter_value f2s_data_width {0}
set_component_parameter_value f2sdram_data_width {0}

# Interrupts
# The DPTX and DPRX interrupts go to the HPS (FPGA to HPS interrupt 0 and 1).
set_component_parameter_value F2H_IRQ_Enable {1}
set_component_parameter_value MPU_Events_Enable {0}

save_component

# HPS IO
set_interface_property hps_io EXPORT_OF hps.hps_io

###
# PIO
# Same use as in the Lattice reference designs.
###
add_component pio_out ip/dp_soc_ag5e/dp_soc_ag5e_pio_out.ip altera_avalon_pio pio_out
load_component pio_out
set_component_parameter_value direction {Output}
set_component_parameter_value width {32}
set_component_parameter_value resetValue {1}
set_component_parameter_value bitModifyingOutReg {0}
save_component
set_interface_property pio_out EXPORT_OF pio_out.external_connection

add_component pio_in ip/dp_soc_ag5e/dp_soc_ag5e_pio_in.ip altera_avalon_pio pio_in
load_component pio_in
set_component_parameter_value direction {Input}
set_component_parameter_value width {32}
save_component
set_interface_property pio_in EXPORT_OF pio_in.external_connection

###
# DPTX
# APB interface to prt_dptx_apb in the top level (4 KB).
###
add_component dptx ip/dp_soc_ag5e/dp_soc_ag5e_dptx.ip prt_apb_exp dptx
load_component dptx
set_component_parameter_value P_ADR_WIDTH {12}
save_component
set_interface_property dptx EXPORT_OF dptx.m

###
# DPRX
# APB interface to prt_dprx_apb in the top level (4 KB).
###
add_component dprx ip/dp_soc_ag5e/dp_soc_ag5e_dprx.ip prt_apb_exp dprx
load_component dprx
set_component_parameter_value P_ADR_WIDTH {12}
save_component
set_interface_property dprx EXPORT_OF dprx.m

###
# VTB
# APB interface to prt_vtb_apb in the top level (4 KB).
###
add_component vtb ip/dp_soc_ag5e/dp_soc_ag5e_vtb.ip prt_apb_exp vtb
load_component vtb
set_component_parameter_value P_ADR_WIDTH {12}
save_component
set_interface_property vtb EXPORT_OF vtb.m

###
# I2C
# APB interface to prt_i2c_apb in the top level (4 KB).
# The I2C bus of the DP redrivers (PI2DPX2063) on the carrier board.
###
add_component i2c ip/dp_soc_ag5e/dp_soc_ag5e_i2c.ip prt_apb_exp i2c
load_component i2c
set_component_parameter_value P_ADR_WIDTH {12}
save_component
set_interface_property i2c EXPORT_OF i2c.m

###
# Video PLL reconfiguration
# APB interface to prt_hvio_pll_rcfg in the top level (4 KB).
###
add_component vid_pll ip/dp_soc_ag5e/dp_soc_ag5e_vid_pll.ip prt_apb_exp vid_pll
load_component vid_pll
set_component_parameter_value P_ADR_WIDTH {12}
save_component
set_interface_property vid_pll EXPORT_OF vid_pll.m

###
# PHY control and status
###
add_component phy_ctl ip/dp_soc_ag5e/dp_soc_ag5e_phy_ctl.ip altera_avalon_pio phy_ctl
load_component phy_ctl
set_component_parameter_value direction {Output}
set_component_parameter_value width {8}
set_component_parameter_value resetValue {3}
set_component_parameter_value bitModifyingOutReg {0}
save_component
set_interface_property phy_ctl EXPORT_OF phy_ctl.external_connection

add_component phy_sts ip/dp_soc_ag5e/dp_soc_ag5e_phy_sts.ip altera_avalon_pio phy_sts
load_component phy_sts
set_component_parameter_value direction {Input}
set_component_parameter_value width {16}
save_component
set_interface_property phy_sts EXPORT_OF phy_sts.external_connection


###
# PHY reconfiguration
# Avalon-MM bridge to the reconfiguration interface of the GTS transceiver (4 MB, byte address).
###
add_component phy_rcfg ip/dp_soc_ag5e/dp_soc_ag5e_phy_rcfg.ip altera_avalon_mm_bridge phy_rcfg
load_component phy_rcfg
set_component_parameter_value DATA_WIDTH {32}
set_component_parameter_value SYMBOL_WIDTH {8}
set_component_parameter_value ADDRESS_WIDTH {22}
set_component_parameter_value ADDRESS_UNITS {SYMBOLS}
set_component_parameter_value MAX_BURST_SIZE {1}
set_component_parameter_value MAX_PENDING_RESPONSES {4}
set_component_parameter_value PIPELINE_COMMAND {0}
set_component_parameter_value PIPELINE_RESPONSE {0}
save_component
set_interface_property phy_rcfg EXPORT_OF phy_rcfg.m0

###
# JTAG to Avalon master
# Debug access to the fabric with System Console, independent of the HPS.
###
add_component jtag_mst ip/dp_soc_ag5e/dp_soc_ag5e_jtag_mst.ip altera_jtag_avalon_master jtag_mst
load_component jtag_mst
save_component

###
# Connections
###
add_connection clk.clk hps.lwhps2fpga_axi_clock
add_connection clk.clk_reset hps.lwhps2fpga_axi_reset
foreach c {dptx dprx vtb vid_pll i2c} {
    add_connection clk.clk $c.clk
    add_connection clk.clk_reset $c.reset
}
add_connection hps.fpga2hps_interrupt_irq0 dptx.irq
set_connection_parameter_value hps.fpga2hps_interrupt_irq0/dptx.irq irqNumber {0}
add_connection hps.fpga2hps_interrupt_irq0 dprx.irq
set_connection_parameter_value hps.fpga2hps_interrupt_irq0/dprx.irq irqNumber {1}

foreach c {pio_out pio_in phy_ctl phy_sts phy_rcfg} {
    add_connection clk.clk $c.clk
    add_connection clk.clk_reset $c.reset
}

foreach m {hps.lwhps2fpga jtag_mst.master} {
    add_connection $m phy_ctl.s1
    set_connection_parameter_value $m/phy_ctl.s1 baseAddress {0x0010}
    add_connection $m phy_sts.s1
    set_connection_parameter_value $m/phy_sts.s1 baseAddress {0x0020}
    add_connection $m pio_out.s1
    set_connection_parameter_value $m/pio_out.s1 baseAddress {0x0040}
    add_connection $m pio_in.s1
    set_connection_parameter_value $m/pio_in.s1 baseAddress {0x0050}
    add_connection $m dptx.s
    set_connection_parameter_value $m/dptx.s baseAddress {0x1000}
    add_connection $m dprx.s
    set_connection_parameter_value $m/dprx.s baseAddress {0x4000}
    add_connection $m vtb.s
    set_connection_parameter_value $m/vtb.s baseAddress {0x2000}
    add_connection $m vid_pll.s
    set_connection_parameter_value $m/vid_pll.s baseAddress {0x3000}
    add_connection $m i2c.s
    set_connection_parameter_value $m/i2c.s baseAddress {0x5000}
    add_connection $m phy_rcfg.s0
    set_connection_parameter_value $m/phy_rcfg.s0 baseAddress {0x00400000}
}

add_connection clk.clk jtag_mst.clk
add_connection clk.clk_reset jtag_mst.clk_reset

save_system dp_soc_ag5e.qsys
