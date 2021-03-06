###
# Lattice DP reference design project script
# (c) 2022 by Parretto B.V.
###

# Create project
prj_create -name dp_ref_lat_lfcpnx_evn -impl impl1 -dev LFCPNX-100-9LFG672C

# Add sources
set SRC "../../src"

# Library
prj_add_source $SRC/lib/prt_dp_pkg.sv
prj_add_source $SRC/lib/prt_dp_lib.sv
prj_add_source $SRC/lib/prt_dp_lib_if.sv
prj_add_source $SRC/lib/prt_dp_lib_mem.sv

# Application
prj_add_source $SRC/app/dp_app_if.sv
prj_add_source $SRC/app/dp_app_ram.sv
prj_add_source $SRC/app/dp_app_rom.sv
prj_add_source $SRC/app/dp_app_top.sv

# Kronos
set KRONOS "../../ref/kronos/rtl/core"
prj_add_source $KRONOS/kronos_types.sv
prj_add_source $KRONOS/kronos_csr.sv
prj_add_source $KRONOS/kronos_EX.sv
prj_add_source $KRONOS/kronos_agu.sv
prj_add_source $KRONOS/kronos_branch.sv
prj_add_source $KRONOS/kronos_hcu.sv
prj_add_source $KRONOS/kronos_alu.sv
prj_add_source $KRONOS/kronos_ID.sv
prj_add_source $KRONOS/kronos_IF.sv
prj_add_source $KRONOS/kronos_counter64.sv
prj_add_source $KRONOS/kronos_lsu.sv
prj_add_source $KRONOS/kronos_RF.sv
prj_add_source $KRONOS/kronos_core.sv

# DPTX
prj_add_source $SRC/tx/prt_dptx_ctl.sv
prj_add_source $SRC/tx/prt_dptx_lnk.sv
prj_add_source $SRC/tx/prt_dptx_msa.sv
prj_add_source $SRC/tx/prt_dptx_scrm.sv
prj_add_source $SRC/tx/prt_dptx_skew.sv
prj_add_source $SRC/tx/prt_dptx_trn.sv
prj_add_source $SRC/tx/prt_dptx_vid.sv
prj_add_source $SRC/tx/prt_dptx_top.sv

# DPRX
prj_add_source $SRC/rx/prt_dprx_ctl.sv
prj_add_source $SRC/rx/prt_dprx_lnk.sv
prj_add_source $SRC/rx/prt_dprx_msa.sv
prj_add_source $SRC/rx/prt_dprx_pars.sv
prj_add_source $SRC/rx/prt_dprx_scrm.sv
prj_add_source $SRC/rx/prt_dprx_trn_lane.sv
prj_add_source $SRC/rx/prt_dprx_trn.sv
prj_add_source $SRC/rx/prt_dprx_vid.sv
prj_add_source $SRC/rx/prt_dprx_top.sv

# VTB
prj_add_source $SRC/vtb/prt_vtb_cr.sv
prj_add_source $SRC/vtb/prt_vtb_cg.sv
prj_add_source $SRC/vtb/prt_vtb_ctl.sv
prj_add_source $SRC/vtb/prt_vtb_fifo.sv
prj_add_source $SRC/vtb/prt_vtb_tg.sv
prj_add_source $SRC/vtb/prt_vtb_tpg.sv
prj_add_source $SRC/vtb/prt_vtb_freq.sv
prj_add_source $SRC/vtb/prt_vtb_mon.sv
prj_add_source $SRC/vtb/prt_vtb_top.sv

# PM
prj_add_source $SRC/pm/prt_dp_pm_aux.sv
prj_add_source $SRC/pm/prt_dp_pm_exch.sv
prj_add_source $SRC/pm/prt_dp_pm_hart.sv
prj_add_source $SRC/pm/prt_dp_pm_hpd_rx.sv
prj_add_source $SRC/pm/prt_dp_pm_hpd_tx.sv
prj_add_source $SRC/pm/prt_dp_pm_irq.sv
prj_add_source $SRC/pm/prt_dp_pm_msg.sv
prj_add_source $SRC/pm/prt_dp_pm_mutex.sv
prj_add_source $SRC/pm/prt_dp_pm_pio.sv
prj_add_source $SRC/pm/prt_dp_pm_ram_lat.v
prj_add_source $SRC/pm/prt_dp_pm_rom_lat.v
prj_add_source $SRC/pm/prt_dp_pm_ram.sv
prj_add_source $SRC/pm/prt_dp_pm_rom.sv
prj_add_source $SRC/pm/prt_dp_pm_tmr.sv
prj_add_source $SRC/pm/prt_dp_pm_top.sv

# Misc
prj_add_source $SRC/misc/prt_lat_lmmi.sv
prj_add_source $SRC/misc/prt_i2c.sv
prj_add_source $SRC/misc/prt_lb_mux.sv
prj_add_source $SRC/misc/prt_dp_clkdet.sv
prj_add_source $SRC/misc/prt_dp_msg_slv_egr.sv
prj_add_source $SRC/misc/prt_dp_msg_slv_ing.sv
prj_add_source $SRC/misc/prt_dp_msg_cdc.sv
prj_add_source $SRC/misc/prt_hb.sv
prj_add_source $SRC/misc/prt_uart.sv

# Top
prj_add_source ../../ref/lattice/lfcpnx_evn/dp_ref_lat_lfcpnx_evn.sv

# Constraint files
prj_add_source ../../ref/lattice/lfcpnx_evn/dp_ref_lat_lfcpnx_evn.sdc
prj_add_source ../../ref/lattice/lfcpnx_evn/dp_ref_lat_lfcpnx_evn.pdc

# IP
file mkdir ./phy
file copy -force ../../ref/lattice/lfcpnx_evn/phy.ipx ./phy/.
file copy -force ../../ref/lattice/lfcpnx_evn/phy.cfg ./phy/.
prj_add_source ./phy/phy.ipx

file mkdir ./sys_pll
file copy -force ../../ref/lattice/lfcpnx_evn/sys_pll.ipx ./sys_pll/.
file copy -force ../../ref/lattice/lfcpnx_evn/sys_pll.cfg ./sys_pll/.
prj_add_source ./sys_pll/sys_pll.ipx

# Application ROM
file mkdir ./dp_app_rom_lat
file copy -force ../../ref/lattice/lfcpnx_evn/dp_app_rom_lat.mem ./dp_app_rom_lat/.
file copy -force ../../ref/lattice/lfcpnx_evn/dp_app_rom_lat.ipx ./dp_app_rom_lat/.
file copy -force ../../ref/lattice/lfcpnx_evn/dp_app_rom_lat.cfg ./dp_app_rom_lat/.
prj_add_source ./dp_app_rom_lat/dp_app_rom_lat.ipx

# Application RAM
file mkdir ./dp_app_ram_lat
file copy -force ../../ref/lattice/lfcpnx_evn/dp_app_ram_lat.mem ./dp_app_ram_lat/.
file copy -force ../../ref/lattice/lfcpnx_evn/dp_app_ram_lat.ipx ./dp_app_ram_lat/.
file copy -force ../../ref/lattice/lfcpnx_evn/dp_app_ram_lat.cfg ./dp_app_ram_lat/.
prj_add_source ./dp_app_ram_lat/dp_app_ram_lat.ipx

# Set top level
prj_set_impl_opt -impl impl1 top dp_ref_lat_lfcpnx_evn
