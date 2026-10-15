###
# Altera Agilex 5 DP reference design video PLL
# (c) 2026 by Parretto B.V.
#
# Creates the IOPLL for the video clock.
# Run with: qsys-script --script=vid_pll_ip.tcl --quartus-project=<project>
###

package require qsys

create_system vid_pll_ip
set_project_property DEVICE_FAMILY {Agilex 5}
set_project_property DEVICE A5ED065AB32AE1V

###
# Video PLL
# HVIO I/O PLL from the 100 MHz system clock with dynamic reconfiguration.
# The VCO is fixed at 2970 MHz (N = 10, M = 297), the application sets the output divider C0
# for the video clock (pixel clock / 4):
# C0 = 20 - 148.5 MHz (2160p), 40 - 74.25 MHz (1440p), 80 - 37.125 MHz (1080p), 160 - 18.5625 MHz (720p)
# For 7680 x 4320p30 the application sets M = 306 (VCO 3060 MHz) and C0 = 12 (255 MHz).
# The project SDC constrains the video clock at 255 MHz.
###
add_component vid_pll ip/vid_pll/vid_pll.ip altera_iopll vid_pll
load_component vid_pll
set_component_parameter_value gui_reference_clock_frequency {100.0}
set_component_parameter_value gui_operation_mode {direct}
set_component_parameter_value gui_number_of_clocks {1}
set_component_parameter_value gui_fix_vco_frequency {1}
set_component_parameter_value gui_fixed_vco_frequency {2970.0}
set_component_parameter_value gui_output_clock_frequency0 {148.5}
set_component_parameter_value gui_en_hvio_reconf {1}
save_component
