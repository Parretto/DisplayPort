###
# Lattice DP RPI demo project script
# (c) 2022 by Parretto B.V.
###

# Create project
prj_create -name dp_rpi_lfcpnx -impl impl1 -dev LFCPNX-100-9LFG672C

# Add sources
set SRC "../../src"

# Library
prj_add_source $SRC/lib/prt_dp_pkg.sv
prj_add_source $SRC/lib/prt_dp_lib.sv
prj_add_source $SRC/lib/prt_dp_lib_if.sv
prj_add_source $SRC/lib/prt_dp_lib_mem.sv

# RISC-V
prj_add_source $SRC/risc-v/prt_riscv_lib.sv
prj_add_source $SRC/risc-v/prt_riscv_cpu_reg.sv
prj_add_source $SRC/risc-v/prt_riscv_cpu.sv
prj_add_source $SRC/risc-v/prt_riscv_rom.sv
prj_add_source $SRC/risc-v/prt_riscv_ram.sv

# Application
prj_add_source $SRC/app/dp_app_top.sv

# DPTX
prj_add_source $SRC/tx/prt_dptx_ctl.sv
prj_add_source $SRC/tx/prt_dptx_lnk.sv
prj_add_source $SRC/tx/prt_dptx_msa.sv
prj_add_source $SRC/tx/prt_dptx_scrm.sv
prj_add_source $SRC/tx/prt_dptx_skew.sv
prj_add_source $SRC/tx/prt_dptx_trn.sv
prj_add_source $SRC/tx/prt_dptx_vid.sv
prj_add_source $SRC/tx/prt_dptx_top.sv

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

# Scaler
prj_add_source $SRC/scaler/prt_scaler_lib.sv 
prj_add_source $SRC/scaler/prt_scaler_agnt_lut.sv
prj_add_source $SRC/scaler/prt_scaler_agnt.sv
prj_add_source $SRC/scaler/prt_scaler_coef.sv
prj_add_source $SRC/scaler/prt_scaler_ctl.sv
prj_add_source $SRC/scaler/prt_scaler_krnl_mac.sv
prj_add_source $SRC/scaler/prt_scaler_krnl_mux.sv
prj_add_source $SRC/scaler/prt_scaler_krnl.sv
prj_add_source $SRC/scaler/prt_scaler_lbf.sv 
prj_add_source $SRC/scaler/prt_scaler_lst.sv 
prj_add_source $SRC/scaler/prt_scaler_slw_mux.sv
prj_add_source $SRC/scaler/prt_scaler_slw.sv
prj_add_source $SRC/scaler/prt_scaler_tg.sv 
prj_add_source $SRC/scaler/prt_scaler_top.sv

# FALD
prj_add_source $SRC/fald/prt_fald_lib.sv
prj_add_source $SRC/fald/prt_fald_csc.sv
prj_add_source $SRC/fald/prt_fald_ctl.sv
prj_add_source $SRC/fald/prt_fald_dim.sv
prj_add_source $SRC/fald/prt_fald_drv.sv
prj_add_source $SRC/fald/prt_fald_top.sv

# RPI
prj_add_source $SRC/rpi/rpi_dpi.sv 

# Top
prj_add_source ../../ref/lsc/lfcpnx_rpi/dp_rpi_lfcpnx.sv

# Constraint files
prj_add_source ../../ref/lsc/lfcpnx_rpi/dp_rpi_lfcpnx.sdc
prj_add_source ../../ref/lsc/lfcpnx_rpi/dp_rpi_lfcpnx.pdc

# IP
file mkdir ./phy_tx
file copy -force ../../ref/lsc/lfcpnx_rpi/phy_tx.ipx ./phy_tx/.
file copy -force ../../ref/lsc/lfcpnx_rpi/phy_tx.cfg ./phy_tx/.
prj_add_source ./phy_tx/phy_tx.ipx

file mkdir ./sys_pll
file copy -force ../../ref/lsc/lfcpnx_rpi/sys_pll.ipx ./sys_pll/.
file copy -force ../../ref/lsc/lfcpnx_rpi/sys_pll.cfg ./sys_pll/.
prj_add_source ./sys_pll/sys_pll.ipx

# RISC-V ROM
file mkdir ./prt_riscv_rom_lat
file copy -force ../../ref/lsc/lfcpnx_rpi/prt_riscv_rom_lat.mem ./prt_riscv_rom_lat/.
file copy -force ../../ref/lsc/lfcpnx_rpi/prt_riscv_rom_lat.ipx ./prt_riscv_rom_lat/.
file copy -force ../../ref/lsc/lfcpnx_rpi/prt_riscv_rom_lat.cfg ./prt_riscv_rom_lat/.
prj_add_source ./prt_riscv_rom_lat/prt_riscv_rom_lat.ipx

# RISC-V RAM
file mkdir ./prt_riscv_ram_lat
file copy -force ../../ref/lsc/lfcpnx_rpi/prt_riscv_ram_lat.mem ./prt_riscv_ram_lat/.
file copy -force ../../ref/lsc/lfcpnx_rpi/prt_riscv_ram_lat.ipx ./prt_riscv_ram_lat/.
file copy -force ../../ref/lsc/lfcpnx_rpi/prt_riscv_ram_lat.cfg ./prt_riscv_ram_lat/.
prj_add_source ./prt_riscv_ram_lat/prt_riscv_ram_lat.ipx

# Set top level
prj_set_impl_opt -impl impl1 top dp_rpi_lfcpnx
