###
# Xilinx DP reference design project script
# (c) 2022 by Parretto B.V.
###

# Create project
create_project dp_ref_xlx_zcu102 -part xczu9eg-ffvb1156-2-e -force

# Add sources
set SRC "../../src"

# Library
add_files $SRC/lib/prt_dp_pkg.sv
add_files $SRC/lib/prt_dp_lib.sv
add_files $SRC/lib/prt_dp_lib_if.sv
add_files $SRC/lib/prt_dp_lib_mem.sv

# Application
add_files $SRC/app/dp_app_if.sv
add_files $SRC/app/dp_app_ram.sv
add_files $SRC/app/dp_app_rom.sv
add_files $SRC/app/dp_app_top.sv

# Kronos
set KRONOS "../../ref/kronos/rtl/core"
add_files $KRONOS/kronos_types.sv
add_files $KRONOS/kronos_csr.sv
add_files $KRONOS/kronos_EX.sv
add_files $KRONOS/kronos_agu.sv
add_files $KRONOS/kronos_branch.sv
add_files $KRONOS/kronos_hcu.sv
add_files $KRONOS/kronos_alu.sv
add_files $KRONOS/kronos_ID.sv
add_files $KRONOS/kronos_IF.sv
add_files $KRONOS/kronos_counter64.sv
add_files $KRONOS/kronos_lsu.sv
add_files $KRONOS/kronos_RF.sv
add_files $KRONOS/kronos_core.sv

# DPTX
add_files $SRC/tx/prt_dptx_ctl.sv
add_files $SRC/tx/prt_dptx_lnk.sv
add_files $SRC/tx/prt_dptx_msa.sv
add_files $SRC/tx/prt_dptx_scrm.sv
add_files $SRC/tx/prt_dptx_skew.sv
add_files $SRC/tx/prt_dptx_trn.sv
add_files $SRC/tx/prt_dptx_vid.sv
add_files $SRC/tx/prt_dptx_top.sv

# DPRX
add_files $SRC/rx/prt_dprx_ctl.sv
add_files $SRC/rx/prt_dprx_lnk.sv
add_files $SRC/rx/prt_dprx_msa.sv
add_files $SRC/rx/prt_dprx_pars.sv
add_files $SRC/rx/prt_dprx_scrm.sv
add_files $SRC/rx/prt_dprx_trn_lane.sv
add_files $SRC/rx/prt_dprx_trn.sv
add_files $SRC/rx/prt_dprx_vid.sv
add_files $SRC/rx/prt_dprx_top.sv

# VTB
add_files $SRC/vtb/prt_vtb_cr.sv
add_files $SRC/vtb/prt_vtb_cg.sv
add_files $SRC/vtb/prt_vtb_ctl.sv
add_files $SRC/vtb/prt_vtb_fifo.sv
add_files $SRC/vtb/prt_vtb_tg.sv
add_files $SRC/vtb/prt_vtb_tpg.sv
add_files $SRC/vtb/prt_vtb_freq.sv
add_files $SRC/vtb/prt_vtb_mon.sv
add_files $SRC/vtb/prt_vtb_top.sv

# PM
add_files $SRC/pm/prt_dp_pm_aux.sv
add_files $SRC/pm/prt_dp_pm_exch.sv
add_files $SRC/pm/prt_dp_pm_hart.sv
add_files $SRC/pm/prt_dp_pm_hpd_rx.sv
add_files $SRC/pm/prt_dp_pm_hpd_tx.sv
add_files $SRC/pm/prt_dp_pm_irq.sv
add_files $SRC/pm/prt_dp_pm_msg.sv
add_files $SRC/pm/prt_dp_pm_mutex.sv
add_files $SRC/pm/prt_dp_pm_pio.sv
add_files $SRC/pm/prt_dp_pm_ram.sv
add_files $SRC/pm/prt_dp_pm_rom.sv
add_files $SRC/pm/prt_dp_pm_tmr.sv
add_files $SRC/pm/prt_dp_pm_top.sv

# Misc
add_files $SRC/misc/prt_xil_drp.sv
add_files $SRC/misc/prt_i2c.sv
add_files $SRC/misc/prt_lb_mux.sv
add_files $SRC/misc/prt_dp_clkdet.sv
add_files $SRC/misc/prt_dp_msg_slv_egr.sv
add_files $SRC/misc/prt_dp_msg_slv_ing.sv
add_files $SRC/misc/prt_dp_msg_cdc.sv
add_files $SRC/misc/prt_hb.sv
add_files $SRC/misc/prt_uart.sv

# Top
add_files ../../ref/xilinx/zcu102/dp_ref_xlx_zcu102.sv

# Constraint
add_files ../../ref/xilinx/zcu102/dp_ref_xlx_zcu102.xdc

# IPs
import_ip ../../ref/xilinx/zcu102/sys_pll.xci 
import_ip ../../ref/xilinx/zcu102/zcu102_gth.xci 

# Update IPs 
upgrade_ip [get_ips]