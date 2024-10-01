###
# AMD DP reference design project script
# (c) 2023-2024 by Parretto B.V.
###

# Create project
create_project dp_ref_alinx_axau15 -part xcau15p-ffvb676-2-i -force

# Add sources
set SRC "../../src"

# Library
add_files $SRC/lib/prt_dp_pkg.sv
add_files $SRC/lib/prt_dp_lib.sv
add_files $SRC/lib/prt_dp_lib_if.sv
add_files $SRC/lib/prt_dp_lib_mem.sv

# RISC-V
add_files $SRC/risc-v/prt_riscv_lib.sv
add_files $SRC/risc-v/prt_riscv_cpu_reg.sv
add_files $SRC/risc-v/prt_riscv_cpu.sv
add_files $SRC/risc-v/prt_riscv_rom.sv
add_files $SRC/risc-v/prt_riscv_ram.sv

# Application
add_files $SRC/app/dp_app_top.sv

# DPTX
add_files $SRC/tx/prt_dptx_ctl.sv
add_files $SRC/tx/prt_dptx_lnk.sv
add_files $SRC/tx/prt_dptx_msa.sv
add_files $SRC/tx/prt_dptx_scrm.sv
add_files $SRC/tx/prt_dptx_skew.sv
add_files $SRC/tx/prt_dptx_trn.sv
add_files $SRC/tx/prt_dptx_vid_vmap.sv
add_files $SRC/tx/prt_dptx_vid_fifo.sv
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
add_files $SRC/rx/prt_dprx_vid_vmap.sv
add_files $SRC/rx/prt_dprx_vid_fifo.sv
add_files $SRC/rx/prt_dprx_vid.sv
add_files $SRC/rx/prt_dprx_sdp.sv
add_files $SRC/rx/prt_dprx_top.sv

# VTB
add_files $SRC/vtb/prt_vtb_cr.sv
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
add_files $SRC/misc/prt_phy_ctl_amd.sv
add_files $SRC/misc/prt_i2c.sv
add_files $SRC/misc/prt_lb_mux.sv
add_files $SRC/misc/prt_dp_clkdet.sv
add_files $SRC/misc/prt_dp_msg_slv_egr.sv
add_files $SRC/misc/prt_dp_msg_slv_ing.sv
add_files $SRC/misc/prt_dp_msg_cdc.sv
add_files $SRC/misc/prt_hb.sv
add_files $SRC/misc/prt_uart.sv

# Top
add_files ../../ref/amd/axau15/dp_ref_alinx_axau15.sv

# Constraint
add_files ../../ref/amd/axau15/dp_ref_alinx_axau15.xdc

# Memory
add_files ../../../software/build/bin/dp_app_alinx_axau15_rom.mem
add_files ../../../software/build/bin/dp_app_alinx_axau15_ram.mem

# IPs
import_ip ../../ref/amd/axau15/sys_pll/sys_pll.xci 
import_ip ../../ref/amd/axau15/gth_2spl/gth_2spl.xci 

# Update IPs 
upgrade_ip [get_ips]

# Create IP design files
# We need to execute the command per individual IPs. 
create_ip_run -force [get_ips gth_2spl]
create_ip_run -force [get_ips sys_pll]

# Launch synthesis
launch_runs synth_1
wait_on_run synth_1

# Launch implementation
launch_runs impl_1
wait_on_run impl_1
