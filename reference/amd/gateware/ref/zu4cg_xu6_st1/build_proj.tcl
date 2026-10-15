###
# AMD Zynq UltraScale+ DP reference design project script
# (c) 2026 by Parretto B.V.
#
# Run from reference/amd/gateware/syn/zu4cg_xu6_st1 with:
# vivado -mode batch -source ../../ref/zu4cg_xu6_st1/build_proj.tcl
#
# Output:
#   dp_ref_amd_zu4cg_xu6_st1.bit    bitstream
#   dp_ref_amd_zu4cg_xu6_st1.xsa    hardware platform (psu_init for the application)
###

set PROJECT dp_ref_amd_zu4cg_xu6_st1
set PART    xczu4cg-sfvc784-1-e
set REF     ../../ref/zu4cg_xu6_st1
set SRC     ../../../../../gateware/src
set PM      ../../../../../software/pm
set PRT_LIB "../../../../../gateware/src/lib"

# Create project
create_project -force $PROJECT . -part $PART
set_property target_language Verilog [current_project]

###
# Processing system and IP
###
source $REF/dp_soc_zu4cg.tcl
make_wrapper -files [get_files $BD.bd] -top
add_files -norecurse [file normalize [glob ./$PROJECT.gen/sources_1/bd/$BD/hdl/${BD}_wrapper.v]]

source $REF/gth_ip.tcl

###
# Sources
###

# Library
add_files -norecurse $PRT_LIB/prt_lib_if.sv
add_files -norecurse $PRT_LIB/prt_lib_cmp.sv
add_files -norecurse $PRT_LIB/prt_lib_mem.sv
add_files -norecurse $SRC/lib/prt_dp_pkg.sv
add_files -norecurse $SRC/lib/prt_dp_lib_if.sv

# DPTX
foreach f {ctl lnk msa scrm skew sdp trn vid_vmap vid_fifo vid top apb} {
    add_files -norecurse $SRC/tx/prt_dptx_$f.sv
}

# DPRX
foreach f {ctl lnk msa pars scrm sdp trn trn_chk trn_ila vid_lmap vid_vmap vid_fifo vid top apb} {
    add_files -norecurse $SRC/rx/prt_dprx_$f.sv
}

# VTB
foreach f {cr dco ctl fifo tg tpg freq mon osd top apb} {
    add_files -norecurse $SRC/vtb/prt_vtb_$f.sv
}

# Policy maker
foreach f {aux exch hart hpd_rx hpd_tx irq msg mutex pio ram rom tmr top} {
    add_files -norecurse $SRC/pm/prt_dp_pm_$f.sv
}

# Policy maker memory initialization (the application loads the policy makers at start up)
foreach f {prt_dptx_pm_rom prt_dptx_pm_ram prt_dprx_pm_rom prt_dprx_pm_ram} {
    add_files -norecurse $PM/$f.mem
}

# Misc
add_files -norecurse $SRC/misc/prt_hb.sv
add_files -norecurse $SRC/misc/prt_dp_clkdet.sv
add_files -norecurse $SRC/misc/prt_dp_msg_slv_egr.sv
add_files -norecurse $SRC/misc/prt_dp_msg_slv_ing.sv
add_files -norecurse $SRC/misc/prt_dp_msg_cdc.sv
add_files -norecurse $SRC/misc/prt_apb2lb.sv
add_files -norecurse $SRC/misc/prt_i2c_apb.sv
add_files -norecurse $SRC/misc/prt_phy_ctl_amd_apb.sv

# Top
add_files -norecurse $REF/$PROJECT.sv
set_property top $PROJECT [current_fileset]

# Constraints
add_files -fileset constrs_1 -norecurse $REF/$PROJECT.xdc

###
# Build
###
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "Implementation failed"
}

file copy -force ./$PROJECT.runs/impl_1/$PROJECT.bit ./$PROJECT.bit

# Hardware platform (psu_init for the application)
write_hw_platform -fixed -force -include_bit -file ./$PROJECT.xsa

open_run impl_1
report_timing_summary -file ./timing_summary.rpt
report_utilization -file ./utilization.rpt
