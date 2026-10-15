###
# APB export - Platform Designer component
# (c) 2026 by Parretto B.V.
#
# APB slave interface and interrupt sender, with the signals exported as a conduit.
###

package require -exact qsys 18.0

set_module_property NAME prt_apb_exp
set_module_property VERSION 1.0
set_module_property DISPLAY_NAME "Parretto APB export"
set_module_property DESCRIPTION "APB slave interface with the APB signals exported to the top level"
set_module_property GROUP "Parretto"
set_module_property AUTHOR "Parretto B.V."
set_module_property INTERNAL false
set_module_property EDITABLE false
set_module_property ELABORATION_CALLBACK elaborate

add_fileset synth QUARTUS_SYNTH "" ""
set_fileset_property synth TOP_LEVEL prt_apb_exp
add_fileset_file prt_apb_exp.sv SYSTEM_VERILOG PATH prt_apb_exp.sv TOP_LEVEL_FILE

add_fileset sim SIM_VERILOG "" ""
set_fileset_property sim TOP_LEVEL prt_apb_exp
add_fileset_file prt_apb_exp.sv SYSTEM_VERILOG PATH prt_apb_exp.sv

add_parameter P_ADR_WIDTH INTEGER 12
set_parameter_property P_ADR_WIDTH DISPLAY_NAME "Address width (bytes)"
set_parameter_property P_ADR_WIDTH ALLOWED_RANGES 3:31
set_parameter_property P_ADR_WIDTH HDL_PARAMETER true

# Clock and reset
add_interface clk clock end
add_interface_port clk clk clk Input 1

add_interface reset reset end
set_interface_property reset associatedClock clk
set_interface_property reset synchronousEdges DEASSERT
add_interface_port reset reset reset Input 1

proc elaborate {} {
    set aw [get_parameter_value P_ADR_WIDTH]

    # APB slave
    add_interface s apb end
    set_interface_property s associatedClock clk
    set_interface_property s associatedReset reset
    add_interface_port s s_paddr paddr Input $aw
    add_interface_port s s_psel psel Input 1
    add_interface_port s s_penable penable Input 1
    add_interface_port s s_pwrite pwrite Input 1
    add_interface_port s s_pwdata pwdata Input 32
    add_interface_port s s_prdata prdata Output 32
    add_interface_port s s_pready pready Output 1
    add_interface_port s s_pslverr pslverr Output 1

    # Interrupt sender
    add_interface irq interrupt end
    set_interface_property irq associatedAddressablePoint s
    set_interface_property irq associatedClock clk
    set_interface_property irq associatedReset reset
    add_interface_port irq irq irq Output 1

    # Exported APB master
    add_interface m conduit end
    set_interface_property m associatedClock clk
    set_interface_property m associatedReset reset
    add_interface_port m m_paddr paddr Output $aw
    add_interface_port m m_psel psel Output 1
    add_interface_port m m_penable penable Output 1
    add_interface_port m m_pwrite pwrite Output 1
    add_interface_port m m_pwdata pwdata Output 32
    add_interface_port m m_prdata prdata Input 32
    add_interface_port m m_pready pready Input 1
    add_interface_port m m_pslverr pslverr Input 1
    add_interface_port m m_irq irq Input 1
}
