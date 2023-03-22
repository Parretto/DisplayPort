###
# ModelSim simulation script
#
# Written by Marco Groeneveld
###

# Variables
set vendor  			"lattice"
set lanes 				4

# Modules

# Application
set app_top				1
set app_cpu				0
set app_cpu_reg			0
set app_rom				0
set app_ram				0
set app_mux				0
set app_pio				0
set app_uart			0
set app_i2c				0
set app_aqua			0

# TX
set tx_top				1
set tx_pm				0
set tx_hart				0
set tx_rom				0
set tx_ram				0
set tx_pio				0
set tx_tmr				0
set tx_irq				0
set tx_exch				0
set tx_hpd				0
set tx_aux				0
set tx_msg				0
set tx_clkdet			0
set tx_msg_cdc			0
set tx_lnk				0
set tx_ctl				0
set tx_vid				0
set tx_msa				0
set tx_trn				0
set tx_skew				0
set tx_scrm				0

# RX
set rx_top				1
set rx_hart				0
set rx_rom				0
set rx_ram				0
set rx_pio				0
set rx_tmr				0
set rx_msg				0
set rx_exch				0
set rx_irq				0
set rx_aux				0
set rx_hpd				0
set rx_mutex			0
set rx_lnk				0
set rx_msg_cdc			0
set rx_trn				0
set rx_trn_lane			0
set rx_pars				0
set rx_scrm				0
set rx_msa				0  
set rx_vid				0

# TX Video toolbox
set tx_vtb_top			0
set tx_vtb_ctl			0
set tx_vtb_cg			0
set tx_vtb_tg			0
set tx_vtb_tpg			0
set tx_vtb_freq			0

# RX Video toolbox
set rx_vtb_top			0
set rx_vtb_ctl			0
set rx_vtb_tg			0
set rx_vtb_cr			0
set rx_vtb_fifo			0
set rx_vtb_mon			0
set rx_vtb_chk			0

# Colors
set color_signal "Gold"
set color_internal "White"
set color_wave "Turquoise"

# Risc-V
set riscv "/home/marco/SandBox/bitbucket/risc-v/src"

# Tools
set vivado "/home/marco/tools/Xilinx/Vivado/2022.1"

# Functions

proc add2wave {name path level} {
	if {$level > 0} {
		add wave -divider $name
		add wave -noupdate -color "Turquoise" -itemcolor "Gold" -ports $path

		if {$level > 1} {
			add wave -divider __INTERNALS__
			add wave -noupdate -color "Turquoise" -itemcolor "White" -internals $path
		}
	}
}


# Libraries
global env;

if [file exists work] {
	vdel -all
}
vlib work

# Xilinx
if {$vendor eq "xilinx"} {
	vlog -quiet $vivado/data/verilog/src/glbl.v
	vlog -quiet $vivado/data/verilog/src/unisims/IBUFDS.v
	vlog -quiet $vivado/data/verilog/src/unisims/BUFGCE.v
	vlog -quiet $vivado/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv
	vlog -quiet $vivado/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv
}

# Risc-V
vlog -quiet $riscv/prt_riscv_lib.sv
vlog -quiet $riscv/prt_riscv_cpu_reg.sv
vlog -quiet $riscv/prt_riscv_cpu.sv
vlog -quiet $riscv/prt_riscv_rom.sv
vlog -quiet $riscv/prt_riscv_ram.sv

if {$vendor eq "lattice"} {
	vlog -quiet prt_riscv_rom_lat.v
	vlog -quiet prt_riscv_ram_lat.v
}

# Common
vlog -quiet ../src/lib/prt_dp_lib.sv
vlog -quiet ../src/lib/prt_dp_lib_if.sv
vlog -quiet ../src/lib/prt_dp_lib_mem.sv
vlog -quiet ../src/lib/prt_dp_pkg.sv
vlog -quiet ../src/misc/prt_dp_msg_slv_egr.sv
vlog -quiet ../src/misc/prt_dp_msg_slv_ing.sv
vlog -quiet ../src/misc/prt_dp_msg_cdc.sv
vlog -quiet ../src/misc/prt_dp_clkdet.sv

# Application
vlog -quiet ../src/app/dp_app_top.sv

vlog -quiet ../src/misc/prt_lb_mux.sv
vlog -quiet ../src/pm/prt_dp_pm_pio.sv
vlog -quiet ../src/misc/prt_i2c.sv
vlog -quiet ../src/misc/prt_uart.sv
#vlog -quiet ../../aqua/rtl/prt_aqua.sv

# Policy maker
vlog -quiet ../src/pm/prt_dp_pm_hart.sv
vlog -quiet ../src/pm/prt_dp_pm_rom.sv
vlog -quiet ../src/pm/prt_dp_pm_ram.sv
vlog -quiet ../src/pm/prt_dp_pm_tmr.sv
vlog -quiet ../src/pm/prt_dp_pm_irq.sv
vlog -quiet ../src/pm/prt_dp_pm_pio.sv
vlog -quiet ../src/pm/prt_dp_pm_msg.sv
vlog -quiet ../src/pm/prt_dp_pm_exch.sv
vlog -quiet ../src/pm/prt_dp_pm_hpd_tx.sv
vlog -quiet ../src/pm/prt_dp_pm_hpd_rx.sv
vlog -quiet ../src/pm/prt_dp_pm_aux.sv
vlog -quiet ../src/pm/prt_dp_pm_mutex.sv
vlog -quiet ../src/pm/prt_dp_pm_top.sv

# TX
vlog -quiet ../src/tx/prt_dptx_ctl.sv
vlog -quiet ../src/tx/prt_dptx_vid.sv
vlog -quiet ../src/tx/prt_dptx_msa.sv
vlog -quiet ../src/tx/prt_dptx_skew.sv
vlog -quiet ../src/tx/prt_dptx_scrm.sv
vlog -quiet ../src/tx/prt_dptx_trn.sv
vlog -quiet ../src/tx/prt_dptx_lnk.sv
vlog -quiet ../src/tx/prt_dptx_top.sv

# RX
vlog -quiet ../src/rx/prt_dprx_ctl.sv
vlog -quiet ../src/rx/prt_dprx_trn_lane.sv
vlog -quiet ../src/rx/prt_dprx_trn.sv
vlog -quiet ../src/rx/prt_dprx_pars.sv
vlog -quiet ../src/rx/prt_dprx_scrm.sv
vlog -quiet ../src/rx/prt_dprx_msa.sv
vlog -quiet ../src/rx/prt_dprx_vid.sv
vlog -quiet ../src/rx/prt_dprx_lnk.sv
vlog -quiet ../src/rx/prt_dprx_top.sv

# PHY
vlog -quiet dp_phy.sv

# Video toolbox
#vlog -quiet pll.sv
vlog -quiet ../src/vtb/prt_vtb_chk.sv
vlog -quiet ../src/vtb/prt_vtb_mon.sv
vlog -quiet ../src/vtb/prt_vtb_freq.sv
vlog -quiet ../src/vtb/prt_vtb_fifo.sv
vlog -quiet ../src/vtb/prt_vtb_tpg.sv
vlog -quiet ../src/vtb/prt_vtb_tg.sv
vlog -quiet ../src/vtb/prt_vtb_cg.sv
vlog -quiet ../src/vtb/prt_vtb_cr.sv
vlog -quiet ../src/vtb/prt_vtb_ctl.sv
vlog -quiet ../src/vtb/prt_vtb_top.sv

# Testbench
vlog -quiet dp_tst.sv 

if {$vendor eq "xilinx"} {
	vsim -voptargs=+acc -t ps dp_tst glbl
}

if {$vendor eq "lattice"} {
	vsim -voptargs=+acc -t ps -L lfcpnx -L lifcl -L pmi_work dp_tst
}

view wave
set wavecolor "Gold"

# simulation

###
# App
###
if {$app_top > 0} {
	set path "sim:/APP_INST/"

	set object [concat $path "*"]
	add2wave "__APP__" $object 1

	if {$app_top > 1} {
		add wave -divider __INTERNALS__
		set object [concat $path "*"]
		add wave -noupdate -color $color_wave -itemcolor $color_internal -internals $object
	}
}

###
# CPU
###
if {$app_cpu > 0} {
	set path "sim:/APP_INST/CPU_INST"

	set object [concat $path "*"]
	add2wave "__CPU_INST__" $object 1

	if {$app_cpu > 1} {
		add wave -divider __INTERNALS__
		set object [concat $path "*"]
		add wave -noupdate -color $color_wave -itemcolor $color_internal -internals $object
	}

	if {$app_cpu_reg > 0} {
		add wave -divider __REG__
		set object [concat $path "/REG_INST/*"]
		add wave -noupdate -color $color_wave -itemcolor $color_internal -internals $object
		set object [concat $path "/REG_INST/clk_reg"]
		add wave -noupdate -color $color_wave -itemcolor $color_internal -internals $object
	}
}

###
# ROM
###
if {$app_rom > 0} {
	set path "sim:/APP_INST/ROM_INST"

	set object [concat $path "*"]
	add2wave "__ROM_INST__" $object 1

	set object [concat $path "ROM_IF/*"]
	add wave -divider __ROM_IF__
	add wave -noupdate -itemcolor $color_signal $object

	if {$app_rom > 1} {
		add wave -divider __INTERNALS__
		set object [concat $path "*"]
		add wave -noupdate -color $color_wave -itemcolor $color_internal -internals $object
	}
}

###
# RAM
###
if {$app_ram > 0} {
	set path "sim:/APP_INST/RAM_INST"

	set object [concat $path "*"]
	add2wave "__RAM_INST__" $object 1

	set object [concat $path "RAM_IF/*"]
	add wave -divider __RAM_IF__
	add wave -noupdate -itemcolor $color_signal $object

	if {$app_ram > 1} {
		add wave -divider __INTERNALS__
		set object [concat $path "*"]
		add wave -noupdate -color $color_wave -itemcolor $color_internal -internals $object
	}
}

###
# Mux
###
if {$app_mux > 0} {
	set path "sim:/APP_INST/MUX_INST"

	set object [concat $path "*"]
	add2wave "__MUX_INST__" $object 1

	set object [concat $path "LB_UP_IF/*"]
	add wave -divider __LB_UP_IF__
	add wave -noupdate -itemcolor $color_signal $object

	set object [concat $path "LB_DWN_IF0/*"]
	add wave -divider __LB_DWN_IF0__
	add wave -noupdate -itemcolor $color_signal $object

	set object [concat $path "LB_DWN_IF4/*"]
	add wave -divider __LB_DWN_IF4__
	add wave -noupdate -itemcolor $color_signal $object

	if {$app_mux > 1} {
		add wave -divider __INTERNALS__
		set object [concat $path "*"]
		add wave -noupdate -color $color_wave -itemcolor $color_internal -internals $object
		set object [concat $path "clk_dwn"]
		add wave -noupdate -color $color_wave -itemcolor $color_internal -internals $object
	}
}

###
# PIO
###
if {$app_pio > 0} {
	set path "sim:/APP_INST/PIO_INST"

	set object [concat $path "*"]
	add2wave "__PIO_INST__" $object 1

	set object [concat $path "LB_IF/*"]
	add wave -divider __LB_IF__
	add wave -noupdate -itemcolor $color_signal $object

	if {$app_pio > 1} {
		add wave -divider __INTERNALS__
		set object [concat $path "*"]
		add wave -noupdate -color $color_wave -itemcolor $color_internal -internals $object
	}
}

###
# UART
###
if {$app_uart > 0} {
	set path "sim:/APP_INST/UART_INST"

	set object [concat $path "*"]
	add2wave "__UART_INST__" $object 1

	set object [concat $path "LB_IF/*"]
	add wave -divider __LB_IF__
	add wave -noupdate -itemcolor $color_signal $object

	if {$app_uart > 1} {
		add wave -divider __INTERNALS__
		set object [concat $path "*"]
		add wave -noupdate -color $color_wave -itemcolor $color_internal -internals $object
	}
}

###
# I2C
###
if {$app_i2c > 0} {
	set path "sim:/APP_INST/I2C_INST"

	set object [concat $path "*"]
	add2wave "__I2C_INST__" $object 1

	set object [concat $path "LB_IF/*"]
	add wave -divider __LB_IF__
	add wave -noupdate -itemcolor $color_signal $object

	if {$app_i2c > 1} {
		add wave -divider __INTERNALS__
		set object [concat $path "*"]
		add wave -noupdate -color $color_wave -itemcolor $color_internal -internals $object
	}

}

###
# TX VTB
###
add wave -divider "**********"
add wave -divider "* TX_VTB *"
add wave -divider "**********"

###
# TX Video toolbox
###
if {$tx_vtb_top > 0} {
	add2wave "__TOP__" "sim:/TX_VTB_INST/*" $tx_vtb_top
}

###
# TX Control
###
if {$tx_vtb_ctl > 0} {
	set path "sim:/TX_VTB_INST/CTL_INST/"

	set object [concat $path "*"]
	add2wave "__CTL__" $object 1

	set object [concat $path "LB_IF/*"]
	add wave -divider __LB_IF__
	add wave -noupdate -itemcolor $color_signal $object

	if {$tx_vtb_ctl > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# Clock generator
###
if {$tx_vtb_cg > 0} {
	set path "sim:/TX_VTB_INST/CG_INST/"

	set object [concat $path "*"]
	add2wave "__CG__" $object 1

	if {$tx_vtb_cg > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# Timing generator
###
if {$tx_vtb_tg > 0} {
	set path "sim:/TX_VTB_INST/TG_INST/"

	set object [concat $path "*"]
	add2wave "__TG__" $object 1

	if {$tx_vtb_tg > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# Test pattern generator
###
if {$tx_vtb_tpg > 0} {
	set path "sim:/TX_VTB_INST/TPG_INST/"

	set object [concat $path "*"]
	add2wave "__TPG__" $object 1

	if {$tx_vtb_tpg > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# Frequency counter
###
if {$tx_vtb_freq > 0} {
	set path "sim:/TX_VTB_INST/LNK_CLK_FREQ_INST/"

	set object [concat $path "*"]
	add2wave "__LNK_FREQ__" $object 1

	if {$tx_vtb_freq > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# TX
###
add wave -divider "*********"
add wave -divider "* TX DP *"
add wave -divider "*********"

###
# Top
###
if {$tx_top > 0} {
	set path "sim:/DPTX_INST/"

	add2wave "__TX_TOP__" "sim:/DPTX_INST/*" 1

	set object [concat $path "HOST_IF/*"]
	add wave -divider __HOST_IF__
	add wave -noupdate -itemcolor $color_signal $object
}

###
# Policy maker
###
if {$tx_pm > 0} {
	add2wave "__TX_PM__" "sim:/DPTX_INST/PM_INST/*" 1
}

###
# Hart
###
if {$tx_hart > 0} {
	set path "sim:/DPTX_INST/PM_INST/HART_INST/"

	set object [concat $path "*"]
	add2wave "__TX_HART_INST__" $object 1

	set object [concat $path "ROM_IF/*"]
	add wave -divider __ROM_IF__
	add wave -noupdate -color $color_wave -itemcolor $color_signal $object

	set object [concat $path "RAM_IF/*"]
	add wave -divider __RAM_IF__
	add wave -noupdate -color $color_wave -itemcolor $color_signal $object

	if {$tx_hart > 1} {
		add wave -divider __INTERNALS__
		set object [concat $path "*"]
		add wave -noupdate -color $color_wave -itemcolor $color_internal -internals $object

		for {set i 0} {$i < 4} {incr i} {
			set object [concat $path "/gen_reg\[$i\]/REG_INST/*"]
			add2wave "__REG__" $object 2
			set object [concat $path "/gen_reg\[$i\]/REG_INST/clk_reg"]
			add wave -noupdate -color $color_wave -itemcolor $color_internal -internals $object
		}
	}
}

###
# ROM
###
if {$tx_rom > 0} {
	set path "sim:/DPTX_INST/PM_INST/ROM_INST/"

	set object [concat $path "*"]
	add2wave "__ROM_INST__" $object 1

	set object [concat $path "ROM_IF/*"]
	add wave -divider __ROM_IF__
	add wave -noupdate -color $color_wave -itemcolor $color_signal $object

	if {$tx_rom > 1} {
		add wave -divider __INTERNALS__
		set object [concat $path "*"]
		add wave -noupdate -color $color_wave -itemcolor $color_internal -internals $object
	}
}

###
# RAM
###
if {$tx_ram > 0} {
	set path "sim:/DPTX_INST/PM_INST/RAM_INST/"

	set object [concat $path "*"]
	add2wave "__RAM_INST__" $object 1

	set object [concat $path "RAM_IF/*"]
	add wave -divider __RAM_IF__
	add wave -noupdate -color $color_wave -itemcolor $color_signal $object

	if {$tx_ram > 1} {
		add wave -divider __INTERNALS__
		set object [concat $path "*"]
		add wave -noupdate -color $color_wave -itemcolor $color_internal -internals $object
	}
}

###
# PIO
###
if {$tx_pio > 0} {
	add2wave "__TX_PIO__" "sim:/DPTX_INST/PM_INST/PIO_INST/*" 1
	add wave -divider __LB_IF__
	add wave -noupdate -itemcolor "Gold" "sim:/DPTX_INST/PM_INST/PIO_INST/LB_IF/*"

	if {$tx_pio > 1} {
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor "White" -internals "sim:/DPTX_INST/PM_INST/PIO_INST/*"
	}
}

###
# Timer
###
if {$tx_tmr > 0} {
	set path "sim:/DPTX_INST/PM_INST/TMR_INST/"

	set object [concat $path "*"]
	add2wave "__TX_TMR_INST__" $object 1

	set object [concat $path "LB_IF/*"]
	add wave -divider __LB_IF__
	add wave -noupdate -itemcolor $color_signal $object

	if {$tx_tmr > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
		
		set alrm [concat $path "clk_alrm"]
		add wave -noupdate -itemcolor $color_internal $alrm
	}
}

###
# IRQ
###
if {$tx_irq > 0} {
	set path "sim:/DPTX_INST/PM_INST/IRQ_INST/"

	set object [concat $path "*"]
	add2wave "__TX_IRQ_INST__" $object 1

	set object [concat $path "LB_IF/*"]
	add wave -divider __LB_IF__
	add wave -noupdate -itemcolor $color_signal $object

	if {$tx_irq > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# Exchange
###
if {$tx_exch > 0} {
	set path "sim:/DPTX_INST/PM_INST/EXCH_INST/"

	set object [concat $path "*"]
	add2wave "__TX_EXCH_INST__" $object 1

	set object [concat $path "HOST_IF/*"]
	add wave -divider __HOST_IF__
	add wave -noupdate -itemcolor $color_signal $object

	set object [concat $path "PM_IF/*"]
	add wave -divider __PM_IF__
	add wave -noupdate -itemcolor $color_signal $object

	if {$tx_exch > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
		set object [concat $path "/clk_ram"]
		add wave -noupdate -itemcolor $color_internal -internals $object
		set object [concat $path "/clk_box"]
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# HPD
###
if {$tx_hpd > 0} {
	set path "sim:/DPTX_INST/PM_INST/gen_hpd_tx/HPD_INST/"

	set object [concat $path "*"]
	add2wave "__TX_HPD_INST__" $object 1

	set object [concat $path "LB_IF/*"]
	add wave -divider __LB_IF__
	add wave -noupdate -itemcolor $color_signal $object

	if {$tx_hpd > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}


###
# AUX
###
if {$tx_aux > 0} {
	set path "sim:/DPTX_INST/PM_INST/AUX_INST/"

	set object [concat $path "*"]
	add2wave "__TX_AUX_INST__" $object 1

	set object [concat $path "LB_IF/*"]
	add wave -divider __LB_IF__
	add wave -noupdate -itemcolor $color_signal $object

	if {$tx_aux > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# MSG
###
if {$tx_msg > 0} {
	set path "sim:/DPTX_INST/PM_INST/MSG_INST/"

	set object [concat $path "*"]
	add2wave "__TX_MSG_INST__" $object 1

	set object [concat $path "LB_IF/*"]
	add wave -divider __LB_IF__
	add wave -noupdate -itemcolor $color_signal $object

	set object [concat $path "MSG_SRC_IF/*"]
	add wave -divider __MSG_SRC_IF__
	add wave -noupdate -itemcolor $color_signal $object

	set object [concat $path "MSG_SNK_IF/*"]
	add wave -divider __MSG_SNK_IF__
	add wave -noupdate -itemcolor $color_signal $object

	if {$tx_msg > 1} {
	set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}


###
# Link
###
if {$tx_lnk > 0} {
	set path "sim:/DPTX_INST/LNK_INST/"

	set object [concat $path "*"]
	add2wave "__TX_LNK_INST__" $object 1
}

###
# CLKDET
###
if {$tx_clkdet > 0} {
	set path "sim:/DPTX_INST/LNK_INST/LNK_CLKDET_INST/"

	set object [concat $path "*"]
	add2wave "__TX_LNK_CLKDET_INST__" $object $tx_clkdet

	set path "sim:/DPTX_INST/LNK_INST/VID_CLKDET_INST/"

	set object [concat $path "*"]
	add2wave "__TX_VID_CLKDET_INST__" $object $tx_clkdet
}

###
# MSG_CDC
###
if {$tx_msg_cdc > 0} {
	set path "sim:/DPTX_INST/LNK_INST/LNK_MSG_CDC_INST/"

	set object [concat $path "*"]
	add2wave "__TX_LNK_MSG_CDC_INST__" $object 1

	set object [concat $path "A_MSG_SNK_IF/*"]
	add wave -divider __A_MSG_SNK_IF__
	add wave -noupdate -itemcolor $color_signal $object

	set object [concat $path "A_MSG_SRC_IF/*"]
	add wave -divider __A_MSG_SRC_IF__
	add wave -noupdate -itemcolor $color_signal $object

	set object [concat $path "B_MSG_SRC_IF/*"]
	add wave -divider __B_MSG_SRC_IF__
	add wave -noupdate -itemcolor $color_signal $object

	if {$tx_msg_cdc > 1} {
	set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# Controller
###
if {$tx_ctl > 0} {
	set path "sim:/DPTX_INST/LNK_INST/CTL_INST/"

	set object [concat $path "*"]
	add2wave "__TX_CTL_INST__" $object 1

	set object [concat $path "MSG_SRC_IF/*"]
	add wave -divider __MSG_SRC_IF__
	add wave -noupdate -itemcolor $color_signal $object

	set object [concat $path "MSG_SNK_IF/*"]
	add wave -divider __MSG_SNK_IF__
	add wave -noupdate -itemcolor $color_signal $object

	if {$tx_ctl > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# Video
###
if {$tx_vid > 0} {
	set path "sim:/DPTX_INST/LNK_INST/VID_INST/"

	set object [concat $path "*"]
	add2wave "__TX_VID_INST__" $object 1

	set object [concat $path "VID_MSG_SRC_IF/*"]
	add wave -divider __VID_MSG_SRC_IF__
	add wave -noupdate -itemcolor $color_signal $object

	set object [concat $path "VID_MSG_SNK_IF/*"]
	add wave -divider __VID_MSG_SNK_IF__
	add wave -noupdate -itemcolor $color_signal $object

	set object [concat $path "VID_SNK_IF/*"]
	add wave -divider __VID_SNK_IF__
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "VID_SNK_IF/dat"]
	add wave -noupdate -itemcolor $color_signal $object

	# For some reason Questa can't find the link source interface
	# When the signals are inserted individual, this is working fine
	add wave -divider __LNK_SRC_IF__
	set object [concat $path "LNK_SRC_IF/k"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SRC_IF/dat"]
	add wave -noupdate -itemcolor $color_signal $object

	if {$tx_vid > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}

	if {$tx_vid > 2} {
		for {set i 0} {$i < 3} {incr i} {
			set object [concat $path "/gen_fifo\[$i\]/FIFO_INST/*"]
			add2wave "__FIFO__" $object 2
		}
	}
}

###
# MSA
###
if {$tx_msa > 0} {
	set path "sim:/DPTX_INST/LNK_INST/MSA_INST/"

	set object [concat $path "*"]
	add2wave "__TX_MSA_INST__" $object 1

	set object [concat $path "MSG_SRC_IF/*"]
	add wave -divider __MSG_SRC_IF__
	add wave -noupdate -itemcolor $color_signal $object

	set object [concat $path "MSG_SNK_IF/*"]
	add wave -divider __MSG_SNK_IF__
	add wave -noupdate -itemcolor $color_signal $object

	add wave -divider __LNK_SNK_IF__
	set object [concat $path "LNK_SNK_IF/k"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SNK_IF/dat"]
	add wave -noupdate -itemcolor $color_signal $object

	add wave -divider __LNK_SRC_IF__
	set object [concat $path "LNK_SRC_IF/k"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SRC_IF/dat"]
	add wave -noupdate -itemcolor $color_signal $object

	if {$tx_msa > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# TRN
###
if {$tx_trn > 0} {
	set path "sim:/DPTX_INST/LNK_INST/TRN_INST/"

	set object [concat $path "*"]
	add2wave "__TX_TRN_INST__" $object 1

	set object [concat $path "MSG_SNK_IF/*"]
	add wave -divider __MSG_SNK_IF__
	add wave -noupdate -itemcolor $color_signal $object

	set object [concat $path "MSG_SRC_IF/*"]
	add wave -divider __MSG_SRC_IF__
	add wave -noupdate -itemcolor $color_signal $object

	# For some reason Questa can't find the link source interface
	# When the signals are inserted individual, this is working fine
	add wave -divider __LNK_SNK_IF__
	set object [concat $path "LNK_SNK_IF/k"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SNK_IF/dat"]
	add wave -noupdate -itemcolor $color_signal $object

	# For some reason Questa can't find the link source interface
	# When the signals are inserted individual, this is working fine
	add wave -divider __LNK_SRC_IF__
	set object [concat $path "LNK_SRC_IF/disp_ctl"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SRC_IF/disp_val"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SRC_IF/k"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SRC_IF/dat"]
	add wave -noupdate -itemcolor $color_signal $object

	if {$tx_trn > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# Skew
###
if {$tx_skew > 0} {
	for {set i 0} {$i < $lanes} {incr i} {
		set path "sim:/DPTX_INST/LNK_INST/gen_skew\[$i\]/SKEW_INST/"

		set object [concat $path "*"]
		add2wave "__TX_SKEW_LANE{$i}_INST__" $object 1

		add wave -divider __LNK_SNK_IF__
		set object [concat $path "LNK_SNK_IF/disp_ctl"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SNK_IF/disp_val"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SNK_IF/k"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SNK_IF/dat"]
		add wave -noupdate -itemcolor $color_signal $object

		add wave -divider __SRC_IF__
		set object [concat $path "LNK_SRC_IF/disp_ctl"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SRC_IF/disp_val"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SRC_IF/k"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SRC_IF/dat"]
		add wave -noupdate -itemcolor $color_signal $object

		if {$tx_skew > 1} {
			set object [concat $path "*"]
			add wave -divider __INTERNALS__
			add wave -noupdate -itemcolor $color_internal -internals $object
		}
	}
}

###
# Scrambler
###
if {$tx_scrm > 0} {
	for {set i 0} {$i < $lanes} {incr i} {
		set path "sim:/DPTX_INST/LNK_INST/gen_scrm\[$i\]/SCRM_INST/"

		set object [concat $path "*"]
		add2wave "__TX_SCRM_LANE{$i}_INST__" $object 1

		add wave -divider __LNK_SNK_IF__
		set object [concat $path "LNK_SNK_IF/disp_ctl"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SNK_IF/disp_val"]
		add wave -noupdate -itemcolor $color_signal $object	
		set object [concat $path "LNK_SNK_IF/k"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SNK_IF/dat"]
		add wave -noupdate -itemcolor $color_signal $object

		add wave -divider __SRC_IF__
		set object [concat $path "LNK_SRC_IF/disp_ctl"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SRC_IF/disp_val"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SRC_IF/k"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SRC_IF/dat"]
		add wave -noupdate -itemcolor $color_signal $object

		if {$tx_scrm > 1} {
			set object [concat $path "*"]
			add wave -divider __INTERNALS__
			add wave -noupdate -itemcolor $color_internal -internals $object

			set object [concat $path "clk_lfsr_in"]
			add wave -noupdate -itemcolor $color_internal -internals $object
			set object [concat $path "clk_lfsr"]
			add wave -noupdate -itemcolor $color_internal -internals $object
		}
	}
}


###
# RX
###
add wave -divider "*********"
add wave -divider "* RX DP *"
add wave -divider "*********"

###
# Top
###
if {$rx_top > 0} {
	add2wave "__RX__" "sim:/DPRX_INST/*" $rx_top
}

###
# Hart
###
if {$rx_hart > 0} {
	set path "sim:/DPRX_INST/PM_INST/HART_INST/"

	set object [concat $path "*"]
	add2wave "__RX_HART_INST__" $object 1

	set object [concat $path "ROM_IF/*"]
	add wave -divider __ROM_IF__
	add wave -noupdate -color $color_wave -itemcolor $color_signal $object

	set object [concat $path "RAM_IF/*"]
	add wave -divider __RAM_IF__
	add wave -noupdate -color $color_wave -itemcolor $color_signal $object

	if {$rx_hart > 1} {
		add wave -divider __INTERNALS__
		set object [concat $path "*"]
		add wave -noupdate -color $color_wave -itemcolor $color_internal -internals $object

		for {set i 0} {$i < 4} {incr i} {
			set object [concat $path "/gen_reg\[$i\]/REG_INST/*"]
			add2wave "__REG__" $object 2
			set object [concat $path "/gen_reg\[$i\]/REG_INST/clk_reg"]
			add wave -noupdate -color $color_wave -itemcolor $color_internal -internals $object
		}
	}
}

###
# ROM
###
if {$rx_rom > 0} {
	set path "sim:/DPRX_INST/PM_INST/ROM_INST/"

	set object [concat $path "*"]
	add2wave "__ROM_INST__" $object 1

	set object [concat $path "ROM_IF/*"]
	add wave -divider __ROM_IF__
	add wave -noupdate -color $color_wave -itemcolor $color_signal $object

	if {$rx_rom > 1} {
		add wave -divider __INTERNALS__
		set object [concat $path "*"]
		add wave -noupdate -color $color_wave -itemcolor $color_internal -internals $object
	}
}

###
# RAM
###
if {$rx_ram > 0} {
	set path "sim:/DPRX_INST/PM_INST/RAM_INST/"

	set object [concat $path "*"]
	add2wave "__RAM_INST__" $object 1

	set object [concat $path "RAM_IF/*"]
	add wave -divider __RAM_IF__
	add wave -noupdate -color $color_wave -itemcolor $color_signal $object

	if {$rx_ram > 1} {
		add wave -divider __INTERNALS__
		set object [concat $path "*"]
		add wave -noupdate -color $color_wave -itemcolor $color_internal -internals $object
	}
}

###
# PIO
###
if {$rx_pio > 0} {
	add2wave "__RX_PIO__" "sim:/DPRX_INST/PM_INST/PIO_INST/*" 1
	add wave -divider __LB_IF__
	add wave -noupdate -itemcolor "Gold" "sim:/DPRX_INST/PM_INST/PIO_INST/LB_IF/*"

	if {$rx_pio > 1} {
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor "White" -internals "sim:/DPRX_INST/PM_INST/PIO_INST/*"
	}
}

###
# MSG
###
if {$rx_msg > 0} {
	set path "sim:/DPRX_INST/PM_INST/MSG_INST/"

	set object [concat $path "*"]
	add2wave "__RX_MSG_INST__" $object 1

	set object [concat $path "LB_IF/*"]
	add wave -divider __LB_IF__
	add wave -noupdate -itemcolor $color_signal $object

	set object [concat $path "MSG_SRC_IF/*"]
	add wave -divider __MSG_SRC_IF__
	add wave -noupdate -itemcolor $color_signal $object

	set object [concat $path "MSG_SNK_IF/*"]
	add wave -divider __MSG_SNK_IF__
	add wave -noupdate -itemcolor $color_signal $object

	if {$rx_msg > 1} {
	set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# IRQ
###
if {$rx_irq > 0} {
	set path "sim:/DPRX_INST/PM_INST/IRQ_INST/"

	set object [concat $path "*"]
	add2wave "__RX_IRQ_INST__" $object 1

	set object [concat $path "LB_IF/*"]
	add wave -divider __LB_IF__
	add wave -noupdate -itemcolor $color_signal $object

	if {$rx_irq > 1} {
	set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# Exchange
###
if {$rx_exch > 0} {
	set path "sim:/DPRX_INST/PM_INST/EXCH_INST/"

	set object [concat $path "*"]
	add2wave "__RX_EXCH_INST__" $object 1

	set object [concat $path "HOST_IF/*"]
	add wave -divider __HOST_IF__
	add wave -noupdate -itemcolor $color_signal $object

	set object [concat $path "PM_IF/*"]
	add wave -divider __PM_IF__
	add wave -noupdate -itemcolor $color_signal $object

	if {$rx_exch > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
		set object [concat $path "/clk_ram"]
		add wave -noupdate -itemcolor $color_internal -internals $object
		set object [concat $path "/clk_box"]
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# AUX
###
if {$rx_aux > 0} {
	set path "sim:/DPRX_INST/PM_INST/AUX_INST/"

	set object [concat $path "*"]
	add2wave "__RX_AUX_INST__" $object 1

	set object [concat $path "LB_IF/*"]
	add wave -divider __LB_IF__
	add wave -noupdate -itemcolor $color_signal $object

	if {$rx_aux > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# HPD
###
if {$rx_hpd > 0} {
	set path "sim:/DPRX_INST/PM_INST/gen_hpd_rx/HPD_INST/"

	set object [concat $path "*"]
	add2wave "__RX_HPD_INST__" $object 1

	set object [concat $path "LB_IF/*"]
	add wave -divider __LB_IF__
	add wave -noupdate -itemcolor $color_signal $object

	if {$rx_hpd > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# Mutex
###
if {$rx_mutex > 0} {
	set path "sim:/DPRX_INST/PM_INST/MUTEX_INST/"

	set object [concat $path "*"]
	add2wave "__MUTEX_INST__" $object 1

	set object [concat $path "LB_IF/*"]
	add wave -divider __LB_IF__
	add wave -noupdate -itemcolor $color_signal $object

	if {$rx_mutex > 1} {
	set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# MSG_CDC
###
if {$rx_msg_cdc > 0} {
	set path "sim:/DPRX_INST/MSG_CDC_INST/"

	set object [concat $path "*"]
	add2wave "__RX_MSG_CDC_INST__" $object 1

	set object [concat $path "SYS_MSG_SNK_IF/*"]
	add wave -divider __SYS_MSG_SNK_IF__
	add wave -noupdate -itemcolor $color_signal $object

	set object [concat $path "SYS_MSG_SRC_IF/*"]
	add wave -divider __SYS_MSG_SRC_IF__
	add wave -noupdate -itemcolor $color_signal $object

	set object [concat $path "LNK_MSG_SNK_IF/*"]
	add wave -divider __LNK_MSG_SNK_IF__
	add wave -noupdate -itemcolor $color_signal $object

	set object [concat $path "LNK_MSG_SRC_IF/*"]
	add wave -divider __LNK_MSG_SRC_IF__
	add wave -noupdate -itemcolor $color_signal $object

	if {$rx_msg_cdc > 1} {
	set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# Link
###
if {$rx_lnk > 0} {
	set path "sim:/DPRX_INST/LNK_INST/"

	set object [concat $path "*"]
	add2wave "__RX_LNK_INST__" $object 1

	set object [concat $path "MSG_SNK_IF/*"]
	add wave -divider __MSG_SNK_IF__
	add wave -noupdate -itemcolor $color_signal $object

	set object [concat $path "MSG_SRC_IF/*"]
	add wave -divider __MSG_SRC_IF__
	add wave -noupdate -itemcolor $color_signal $object

	# For some reason Questa can't find the link source interface
	# When the signals are inserted individual, this is working fine
	add wave -divider __LNK_SNK_IF__
	set object [concat $path "LNK_SNK_IF/k"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SNK_IF/dat"]
	add wave -noupdate -itemcolor $color_signal $object

	if {$rx_lnk > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# Training
###
if {$rx_trn > 0} {
	set path "sim:/DPRX_INST/LNK_INST/TRN_INST/"

	set object [concat $path "*"]
	add2wave "__RX_TRN_INST__" $object 1

	set object [concat $path "MSG_SNK_IF/*"]
	add wave -divider __MSG_SNK_IF__
	add wave -noupdate -itemcolor $color_signal $object

	set object [concat $path "MSG_SRC_IF/*"]
	add wave -divider __MSG_SRC_IF__
	add wave -noupdate -itemcolor $color_signal $object

	# For some reason Questa can't find the link source interface
	# When the signals are inserted individual, this is working fine
	add wave -divider __LNK_SNK_IF__
	set object [concat $path "LNK_SNK_IF/lock"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SNK_IF/k"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SNK_IF/dat"]
	add wave -noupdate -itemcolor $color_signal $object

	add wave -divider __LNK_SRC_IF__
	set object [concat $path "LNK_SRC_IF/lock"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SRC_IF/k"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SRC_IF/dat"]
	add wave -noupdate -itemcolor $color_signal $object

	if {$rx_trn > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# Training lane
###
if {$rx_trn_lane > 0} {
	for {set i 0} {$i < $lanes} {incr i} {

		set path "sim:/DPRX_INST/LNK_INST/TRN_INST/gen_lanes\[$i\]/LANE_INST/"

		set object [concat $path "*"]
		add2wave "__RX_TRN_INST_[$i]__" $object 1

		# For some reason Questa can't find the link source interface
		# When the signals are inserted individual, this is working fine
		add wave -divider __LNK_SNK_IF__
		set object [concat $path "LNK_SNK_IF/lock"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SNK_IF/k"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SNK_IF/dat"]
		add wave -noupdate -itemcolor $color_signal $object

		add wave -divider __LNK_SRC_IF__
		set object [concat $path "LNK_SRC_IF/lock"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SRC_IF/k"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SRC_IF/dat"]
		add wave -noupdate -itemcolor $color_signal $object


		if {$rx_trn_lane > 1} {
			set object [concat $path "*"]
			add wave -divider __INTERNALS__
			add wave -noupdate -itemcolor $color_internal -internals $object
		}
	}
}

###
# Parser
###
if {$rx_pars > 0} {
	for {set i 0} {$i < $lanes} {incr i} {
		set path "sim:/DPRX_INST/LNK_INST/gen_pars\[$i\]/PARS_INST/"

		set object [concat $path "*"]
		add2wave "__RX_PARS_LANE{$i}_INST__" $object 1

		# For some reason Questa can't find the link source interface
		# When the signals are inserted individual, this is working fine
		add wave -divider __LNK_SNK_IF__
		set object [concat $path "LNK_SNK_IF/lock"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SNK_IF/k"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SNK_IF/dat"]
		add wave -noupdate -itemcolor $color_signal $object

		add wave -divider __LNK_SRC_IF__
		set object [concat $path "LNK_SRC_IF/lock"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SRC_IF/sol"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SRC_IF/eol"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SRC_IF/vid"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SRC_IF/sec"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SRC_IF/msa"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SRC_IF/vbid"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SRC_IF/k"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SRC_IF/dat"]
		add wave -noupdate -itemcolor $color_signal $object

		if {$rx_pars > 1} {
			set object [concat $path "*"]
			add wave -divider __INTERNALS__
			add wave -noupdate -itemcolor $color_internal -internals $object
		}
	}
}

###
# Scrambler
###
if {$rx_scrm > 0} {
	for {set i 0} {$i < $lanes} {incr i} {
		set path "sim:/DPRX_INST/LNK_INST/gen_scrm\[$i\]/SCRM_INST/"

		set object [concat $path "*"]
		add2wave "__RX_SCRM_LANE{$i}_INST__" $object 1

		add wave -divider __LNK_SNK_IF__
		set object [concat $path "LNK_SNK_IF/lock"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SNK_IF/k"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SNK_IF/dat"]
		add wave -noupdate -itemcolor $color_signal $object

		add wave -divider __LNK_SRC_IF__
		set object [concat $path "LNK_SRC_IF/lock"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SRC_IF/k"]
		add wave -noupdate -itemcolor $color_signal $object
		set object [concat $path "LNK_SRC_IF/dat"]
		add wave -noupdate -itemcolor $color_signal $object

		if {$rx_scrm > 1} {
			set object [concat $path "*"]
			add wave -divider __INTERNALS__
			add wave -noupdate -itemcolor $color_internal -internals $object

			set object [concat $path "clk_lfsr_in"]
			add wave -noupdate -itemcolor $color_internal -internals $object
			set object [concat $path "clk_lfsr"]
			add wave -noupdate -itemcolor $color_internal -internals $object
		}
	}
}

###
# Deskew
###
#if {$rx_deskew > 0} {
#	for {set i 0} {$i < $lanes} {incr i} {
#		set path "sim:/DPRX_INST/LNK_INST/gen_deskew\[$i\]/DESKEW_INST/"
#
#		set object [concat $path "*"]
#		add2wave "__RX_DESKEW_LANE{$i}_INST__" $object 1
#
#		add wave -divider __LNK_SNK_IF__
#		set object [concat $path "LNK_SNK_IF/lock"]
#		add wave -noupdate -itemcolor $color_signal $object
#		set object [concat $path "LNK_SNK_IF/vid"]
#		add wave -noupdate -itemcolor $color_signal $object
#		set object [concat $path "LNK_SNK_IF/sec"]
#		add wave -noupdate -itemcolor $color_signal $object
#		set object [concat $path "LNK_SNK_IF/msa"]
#		add wave -noupdate -itemcolor $color_signal $object
#		set object [concat $path "LNK_SNK_IF/k"]
#		add wave -noupdate -itemcolor $color_signal $object
#		set object [concat $path "LNK_SNK_IF/dat"]
#		add wave -noupdate -itemcolor $color_signal $object
#
#		add wave -divider __LNK_SRC_IF__
#		set object [concat $path "LNK_SRC_IF/lock"]
#		add wave -noupdate -itemcolor $color_signal $object
#		set object [concat $path "LNK_SRC_IF/vid"]
#		add wave -noupdate -itemcolor $color_signal $object
#		set object [concat $path "LNK_SRC_IF/sec"]
#		add wave -noupdate -itemcolor $color_signal $object
#		set object [concat $path "LNK_SRC_IF/msa"]
#		add wave -noupdate -itemcolor $color_signal $object
#		set object [concat $path "LNK_SRC_IF/k"]
#		add wave -noupdate -itemcolor $color_signal $object
#		set object [concat $path "LNK_SRC_IF/dat"]
#		add wave -noupdate -itemcolor $color_signal $object
#
#		if {$rx_deskew > 1} {
#			set object [concat $path "*"]
#			add wave -divider __INTERNALS__
#			add wave -noupdate -itemcolor $color_internal -internals $object
#		}
#	}
#}

###
# Main stream attributes
###
if {$rx_msa > 0} {
	set path "sim:/DPRX_INST/LNK_INST/MSA_INST/"

	set object [concat $path "*"]
	add2wave "__RX_MSA_INST__" $object 1

	set object [concat $path "MSG_SNK_IF/*"]
	add wave -divider __MSG_SNK_IF__
	add wave -noupdate -itemcolor $color_signal $object

	set object [concat $path "MSG_SRC_IF/*"]
	add wave -divider __MSG_SRC_IF__
	add wave -noupdate -itemcolor $color_signal $object

	# For some reason Questa can't find the link source interface
	# When the signals are inserted individual, this is working fine
	add wave -divider __LNK_SNK_IF__
	set object [concat $path "LNK_SNK_IF/lock"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SNK_IF/sol"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SNK_IF/eol"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SNK_IF/vid"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SNK_IF/sec"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SNK_IF/msa"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SNK_IF/vbid"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SNK_IF/k"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SNK_IF/dat"]
	add wave -noupdate -itemcolor $color_signal $object

	add wave -divider __LNK_SRC_IF__
	set object [concat $path "LNK_SRC_IF/lock"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SRC_IF/sol"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SRC_IF/eol"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SRC_IF/vid"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SRC_IF/sec"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SRC_IF/msa"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SRC_IF/vbid"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SRC_IF/k"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SRC_IF/dat"]
	add wave -noupdate -itemcolor $color_signal $object

	if {$rx_msa > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# Video
###
if {$rx_vid > 0} {
	set path "sim:/DPRX_INST/LNK_INST/VID_INST/"

	set object [concat $path "*"]
	add2wave "__RX_VID_INST__" $object 1

	# For some reason Questa can't find the link source interface
	# When the signals are inserted individual, this is working fine
	add wave -divider __LNK_SNK_IF__
	set object [concat $path "LNK_SNK_IF/lock"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SNK_IF/sol"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SNK_IF/eol"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SNK_IF/vid"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SNK_IF/sec"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SNK_IF/msa"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SNK_IF/vbid"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SNK_IF/k"]
	add wave -noupdate -itemcolor $color_signal $object
	set object [concat $path "LNK_SNK_IF/dat"]
	add wave -noupdate -itemcolor $color_signal $object

	set object [concat $path "VID_SRC_IF/*"]
	add wave -divider __VID_SRC_IF__
	add wave -noupdate -itemcolor $color_signal $object

	if {$rx_vid > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# RX VTB
###
add wave -divider "**********"
add wave -divider "* RX_VTB *"
add wave -divider "**********"

###
# RX Video toolbox
###
if {$rx_vtb_top > 0} {
	add2wave "__TOP__" "sim:/RX_VTB_INST/*" $rx_vtb_top
}

###
# RX Control
###
if {$rx_vtb_ctl > 0} {
	set path "sim:/RX_VTB_INST/CTL_INST/"

	set object [concat $path "*"]
	add2wave "__CTL__" $object 1

	set object [concat $path "LB_IF/*"]
	add wave -divider __LB_IF__
	add wave -noupdate -itemcolor $color_signal $object

	if {$rx_vtb_ctl > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# RX Clock recoery
###
if {$rx_vtb_cr > 0} {
	set path "sim:/RX_VTB_INST/CR_INST/"

	set object [concat $path "*"]
	add2wave "__CR__" $object 1

	if {$rx_vtb_cr > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# Timing generator
###
if {$rx_vtb_tg > 0} {
	set path "sim:/RX_VTB_INST/TG_INST/"

	set object [concat $path "*"]
	add2wave "__TG__" $object 1

	if {$rx_vtb_tg > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# RX FIFO
###
if {$rx_vtb_fifo > 0} {
	set path "sim:/RX_VTB_INST/FIFO_INST/"

	set object [concat $path "*"]
	add2wave "__FIFO__" $object 1

	if {$rx_vtb_fifo > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# RX Monitor
###
if {$rx_vtb_mon > 0} {
	set path "sim:/RX_VTB_INST/MON_INST/"

	set object [concat $path "*"]
	add2wave "__MON__" $object 1

	if {$rx_vtb_mon > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

###
# RX Checker
###
if {$rx_vtb_chk > 0} {
	set path "sim:/RX_VTB_INST/CHK_INST/"

	set object [concat $path "*"]
	add2wave "__CHK__" $object 1

	if {$rx_vtb_chk > 1} {
		set object [concat $path "*"]
		add wave -divider __INTERNALS__
		add wave -noupdate -itemcolor $color_internal -internals $object
	}
}

configure wave -signalnamewidth 1
configure wave -timelineunits us
configure wave -namecolwidth 250
configure wave -valuecolwidth 200
configure wave -waveselectenable 1
configure wave -vectorcolor "Yellow"
set DefaultRadix hexadecimal
update
