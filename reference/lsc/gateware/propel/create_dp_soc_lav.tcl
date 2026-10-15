###
# Create the Propel SoC of the Lattice Avant DP reference design
# (c) 2026 by Parretto B.V.
#
# Run from reference/lsc/gateware/propel:
#   propelbldc < create_dp_soc_lav.tcl
#
# The SoC follows hdmi_soc_lav: a RISC-V MC with the system memory on its instruction
# port and a unified interconnect (UIC) on its data port. The UIC serves the memory, the
# GPIO, UART and I2C, and four APB feedthroughs that are exported to the top level for the
# DP transmitter, the DP receiver, the video toolbox and the PHY controller. The DP
# IP-cores have APB interfaces, so they connect without a bridge. The address map is the
# one of dp_soc_lfcpnx, so the application uses the same base addresses on both devices.
###

set name dp_soc_lav
set dir  [file normalize ./$name]

# The memory image the system memory starts with. Propel wants an existing file. Before
# the application has been built (the BSP comes from this SoC) an empty image is created;
# the SoC is generated again after the application is built (see reference/lsc/README.md).
set mem  [file normalize $dir/../../../software/workspace/dp_app_lav/Debug/dp_app_lav.mem]
if {![file exists $mem]} {
    file mkdir [file dirname $mem]
    close [open $mem w]
}

proc run {what cmd} {
    if {[catch {uplevel 1 $cmd} r]} {
        puts "FAILED $what: $r"
        exit 1
    }
    return $r
}

file mkdir $dir/$name
run new {sbp_design new -name $name -path $dir/$name/$name.sbx -device LAV-AT-X70-1LFG1156C -speed 1 -language verilog}
run save {sbp_design save}

# Components
run cpu0 {sbp_config_ip -vlnv {latticesemi.com:ip:cpu0:2.9.0} -meta_vlnv {latticesemi.com:ip:riscv_mc:2.9.0} \
    -cfg_value {DEBUG_ENABLE:true,IRQ_NUM:4,TIMER_ENABLE:true}}
run system0 {sbp_config_ip -vlnv {latticesemi.com:ip:system0:2.6.0} -meta_vlnv {latticesemi.com:ip:system_memory:2.6.0} \
    -cfg_value "INTERFACE:AHBL,ADDR_DEPTH:32768,PORT_COUNT:2,DATA_STREAMER_EN:false,INIT_MEM:true,INIT_FILE_IN:$mem,REGMODE_S0:true,REGMODE_S1:true"}
run gpio0 {sbp_config_ip -vlnv {latticesemi.com:ip:gpio0:1.8.0} -meta_vlnv {latticesemi.com:ip:gpio:1.8.0} \
    -cfg_value {IO_LINES_COUNT:32,EXTERNAL_BUF:true,OUT_RESET_VAL_INPUT:0,DIRECTION_DEF_VAL_INPUT:FF,IF_USER_INTF:APB}}
run uart0 {sbp_config_ip -vlnv {latticesemi.com:ip:uart0:1.6.0} -meta_vlnv {latticesemi.com:ip:uart:1.6.0} \
    -cfg_value {SYS_CLOCK_FREQ:50.0}}
run i2c {sbp_config_ip -vlnv {latticesemi.com:ip:i2c:2.3.0} -meta_vlnv {latticesemi.com:ip:i2c_controller:2.3.0} \
    -cfg_value {}}
run uic {sbp_config_ip -vlnv {latticesemi.com:ip:uic:2.0.0} -meta_vlnv {latticesemi.com:ip:unified_interconnect:2.0.0} \
    -cfg_value {TOTAL_EXTMAS_CNT:1,TOTAL_EXTSLV_CNT:8,ext_mas_protocol_0:AHB-Lite,ext_slv_protocol_0:AHB-Lite,ext_slv_protocol_1:APB,ext_slv_protocol_2:APB,ext_slv_protocol_3:APB,ext_slv_protocol_4:APB,ext_slv_protocol_5:APB,ext_slv_protocol_6:APB,ext_slv_protocol_7:APB}}

run add_cpu0    {sbp_add_component -vlnv {latticesemi.com:ip:cpu0:2.9.0} -name cpu0_inst}
run add_system0 {sbp_add_component -vlnv {latticesemi.com:ip:system0:2.6.0} -name system0_inst}
run add_gpio0   {sbp_add_component -vlnv {latticesemi.com:ip:gpio0:1.8.0} -name gpio0_inst}
run add_uart0   {sbp_add_component -vlnv {latticesemi.com:ip:uart0:1.6.0} -name uart0_inst}
run add_i2c     {sbp_add_component -vlnv {latticesemi.com:ip:i2c:2.3.0} -name i2c_inst}
run add_uic     {sbp_add_component -vlnv {latticesemi.com:ip:uic:2.0.0} -name uic_inst}
run add_inv     {sbp_add_gluelogic -name invert_module_inst -logicinfo [sbp_create_glue_logic invert invert_module {}]}

# Ports
run p_clk  {sbp_add_port -direction in CLK_IN}
run p_rst  {sbp_add_port -direction in RST_IN}
run p_rx   {sbp_add_port -direction in UART_RX_IN}
run p_tx   {sbp_add_port -direction out UART_TX_OUT}
run p_scl  {sbp_add_port -direction inout I2C_SCL_INOUT}
run p_sda  {sbp_add_port -direction inout I2C_SDA_INOUT}
run p_pi   {sbp_add_port -from 31 -to 0 -direction in PIO_IN}
run p_po   {sbp_add_port -from 31 -to 0 -direction out PIO_OUT}

# Clock and reset
run n_clk {sbp_connect_net "$name/CLK_IN" "$name/cpu0_inst/clk_i" "$name/system0_inst/ahbl_hclk_i" \
    "$name/uic_inst/clk_i" "$name/gpio0_inst/clk_i" "$name/uart0_inst/clk_i" "$name/i2c_inst/clk_i"}
run n_rst {sbp_connect_net "$name/RST_IN" "$name/invert_module_inst/I"}
run n_rsn {sbp_connect_net "$name/invert_module_inst/O" "$name/cpu0_inst/rst_n_i"}
run n_srs {sbp_connect_net "$name/cpu0_inst/system_resetn_o" "$name/system0_inst/ahbl_hresetn_i" \
    "$name/uic_inst/resetn_i" "$name/gpio0_inst/resetn_i" "$name/uart0_inst/rst_n_i" "$name/i2c_inst/rst_n_i"}

# Pins
run n_urx  {sbp_connect_net "$name/UART_RX_IN" "$name/uart0_inst/rxd_i"}
run n_utx  {sbp_connect_net "$name/uart0_inst/txd_o" "$name/UART_TX_OUT"}
run n_scl  {sbp_connect_net "$name/i2c_inst/scl_io" "$name/I2C_SCL_INOUT"}
run n_sda  {sbp_connect_net "$name/i2c_inst/sda_io" "$name/I2C_SDA_INOUT"}
run n_pi   {sbp_connect_net "$name/PIO_IN" "$name/gpio0_inst/gpio_i"}
run n_po   {sbp_connect_net "$name/gpio0_inst/gpio_o" "$name/PIO_OUT"}

# Buses
run i_instr {sbp_connect_interface_net "$name/cpu0_inst/AHBL_M0_INSTR" "$name/system0_inst/AHBL_S0"}
run i_data  {sbp_connect_interface_net "$name/cpu0_inst/AHBL_M1_DATA" "$name/uic_inst/AHBL_S00"}
run i_mem   {sbp_connect_interface_net "$name/uic_inst/AHBL_M00" "$name/system0_inst/AHBL_S1"}
run i_gpio  {sbp_connect_interface_net "$name/uic_inst/APB_M01" "$name/gpio0_inst/APB_S0"}
run i_uart  {sbp_connect_interface_net "$name/uic_inst/APB_M02" "$name/uart0_inst/APB_S0"}
run i_i2c   {sbp_connect_interface_net "$name/uic_inst/APB_M03" "$name/i2c_inst/APB_S0"}

# Interrupts: GPIO and UART inside, the DPTX and the DPRX from the top level
run q_gpio {sbp_connect_interface_net "$name/gpio0_inst/INTR" "$name/cpu0_inst/IRQ_S0"}
run q_uart {sbp_connect_interface_net "$name/uart0_inst/INT_M0" "$name/cpu0_inst/IRQ_S1"}
run q_tx   {sbp_export_interfaces "$name/cpu0_inst/IRQ_S2"}
run q_rx   {sbp_export_interfaces "$name/cpu0_inst/IRQ_S3"}

# The DP peripherals, as APB ports on the top level, through an APB feedthrough each like
# in dp_soc_lfcpnx. The feedthrough carries the memory map of the port : an interconnect
# port exported directly gets none, whatever address width it is given, and the
# interconnect then answers every access to it with a bus error. The feedthrough also
# puts the base address of each peripheral in the BSP.
foreach {inst port} {DPTX_APB APB_M04 DPRX_APB APB_M05 VTB_APB APB_M06 PHY_APB APB_M07} {
    run cfg_$inst {sbp_config_ip -vlnv "latticesemi.com:module:$inst:1.2.0" -meta_vlnv {latticesemi.com:module:apb_feedthrough:1.2.0} \
        -cfg_value {INTERFACE_TYPE:Completer}}
    run add_$inst {sbp_add_component -vlnv "latticesemi.com:module:$inst:1.2.0" -name ${inst}_inst}
    run bus_$inst {sbp_connect_interface_net "$name/uic_inst/$port" "$name/${inst}_inst/APB_S0"}
    run exp_$inst {sbp_export_interfaces "$name/${inst}_inst/APB_M0"}
}

run save2 {sbp_design save}

# Address map of dp_soc_lfcpnx
run a_gpio {sbp_assign_addr_seg -offset 'h40000000 "$name/uic_inst/APB_M01" "$name/gpio0_inst/APB_S0"}
run a_uart {sbp_assign_addr_seg -offset 'h40001000 "$name/uic_inst/APB_M02" "$name/uart0_inst/APB_S0"}
run a_tx   {sbp_assign_addr_seg -offset 'h40002000 "$name/uic_inst/APB_M04" "$name/DPTX_APB_inst/APB_S0"}
run a_rx   {sbp_assign_addr_seg -offset 'h40003000 "$name/uic_inst/APB_M05" "$name/DPRX_APB_inst/APB_S0"}
run a_vtb  {sbp_assign_addr_seg -offset 'h40004000 "$name/uic_inst/APB_M06" "$name/VTB_APB_inst/APB_S0"}
run a_phy  {sbp_assign_addr_seg -offset 'h40005000 "$name/uic_inst/APB_M07" "$name/PHY_APB_inst/APB_S0"}
run a_i2c  {sbp_assign_addr_seg -offset 'h40006000 "$name/uic_inst/APB_M03" "$name/i2c_inst/APB_S0"}

# The names of dp_soc_lfcpnx, so both tops connect the SoC the same way
puts "INTERFACES: [sbp_get_interfaces -from $name *]"
run r_tx   {sbp_rename -name {DPTX_IF} "$name/DPTX_APB_inst_APB_M0_interface"}
run r_rx   {sbp_rename -name {DPRX_IF} "$name/DPRX_APB_inst_APB_M0_interface"}
run r_vtb  {sbp_rename -name {VTB_IF} "$name/VTB_APB_inst_APB_M0_interface"}
run r_phy  {sbp_rename -name {PHY_IF} "$name/PHY_APB_inst_APB_M0_interface"}
run r_qtx  {sbp_rename -name {DPTX_IRQ_IN} "$name/cpu0_inst_IRQ_S2_interface"}
run r_qrx  {sbp_rename -name {DPRX_IRQ_IN} "$name/cpu0_inst_IRQ_S3_interface"}

run save3 {sbp_design save}
run drc   {sbp_design drc}
run gen   {sbp_design generate}
run save4 {sbp_design save}
# The project file that Propel writes when it creates a project from the GUI. The BSP
# generator reads the Builder version from it and refuses a project without one.
set f [open $dir/.socproject w]
puts $f {<?xml version="1.0" encoding="UTF-8" ?>}
puts $f {<propelProject>}
puts $f {    <builder-resource>}
puts $f "        <socProject sbxfile=\"./$name/$name.sbx\" />"
puts $f {    </builder-resource>}
puts $f {    <builderInfo version="2026.1.0.2606162255" />}
puts $f {</propelProject>}
close $f

run sge   {sbp_design pge sge -i $dir/$name/$name.sbx -o $dir}
run close {sbp_design close}
exit
