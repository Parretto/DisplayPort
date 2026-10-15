###
# Lattice DP reference design project script - Lattice Avant G70 Versa board
# (c) 2022 - 2026 by Parretto B.V.
###

###
# Helper functions
###

# Recursively find all .ipx files under ./propel and add them with pro_add_source
proc add_ipx_from_dir {dir} {
    # Skip sim_model directories
    if {[file tail $dir] eq "sim_model"} {
        return
    }

    #puts "Scanning directory: $dir"
    set files [glob -nocomplain [file join $dir *]]
    foreach f $files {
        if {[file isdirectory $f]} {
            #puts "Descending into subdirectory: $f"
            add_ipx_from_dir $f
        } elseif {[string match *.ipx $f]} {
            #puts "Found .ipx file: $f"
            catch {
                prj_add_source "$f"
                puts "✅ Added IPX: $f"
            } err
            if {$err ne ""} {
                puts "❌ Error adding $f: $err"
            }
        }
    }
}

# Create project
prj_create -name dp_ref_lsc_lav_g70_versa_evn -impl impl1 -dev LAV-AT-X70-1LFG1156C

# Add sources
set PRT_LIB "../../../../../gateware/src/lib"
set SRC "../../../../../gateware/src"

# Lattice common IP (from the running Radiant installation)
set LSCC_IP "[file dirname $::env(FOUNDRY)]/ip/common"
prj_add_source $LSCC_IP/lscc_reset/rtl/lscc_reset_async.sv
prj_add_source $LSCC_IP/lscc_reset/rtl/lscc_reset.sv
prj_add_source $LSCC_IP/lscc_reset/rtl/lscc_reset_sync.sv
prj_add_source $LSCC_IP/lscc_cdc/rtl/lscc_cdc_multibit.sv
prj_add_source $LSCC_IP/lscc_cdc/rtl/lscc_cdc_hs_bus.sv
prj_add_source $LSCC_IP/lscc_cdc/rtl/lscc_sync.sv

# Library
prj_add_source $PRT_LIB/prt_lib_if.sv
prj_add_source $PRT_LIB/prt_lib_cmp.sv
prj_add_source $PRT_LIB/prt_lib_mem.sv
prj_add_source $SRC/lib/prt_dp_pkg.sv
prj_add_source $SRC/lib/prt_dp_lib_if.sv

# DPTX
prj_add_source $SRC/tx/prt_dptx_ctl.sv
prj_add_source $SRC/tx/prt_dptx_lnk.sv
prj_add_source $SRC/tx/prt_dptx_msa.sv
prj_add_source $SRC/tx/prt_dptx_scrm.sv
prj_add_source $SRC/tx/prt_dptx_skew.sv
prj_add_source $SRC/tx/prt_dptx_sdp.sv
prj_add_source $SRC/tx/prt_dptx_trn.sv
prj_add_source $SRC/tx/prt_dptx_vid_vmap.sv
prj_add_source $SRC/tx/prt_dptx_vid_fifo.sv
prj_add_source $SRC/tx/prt_dptx_vid.sv
prj_add_source $SRC/tx/prt_dptx_top.sv
prj_add_source $SRC/tx/prt_dptx_apb.sv

# DPRX
prj_add_source $SRC/rx/prt_dprx_ctl.sv
prj_add_source $SRC/rx/prt_dprx_lnk.sv
prj_add_source $SRC/rx/prt_dprx_msa.sv
prj_add_source $SRC/rx/prt_dprx_pars.sv
prj_add_source $SRC/rx/prt_dprx_scrm.sv
prj_add_source $SRC/rx/prt_dprx_trn_chk.sv
prj_add_source $SRC/rx/prt_dprx_trn_ila.sv
prj_add_source $SRC/rx/prt_dprx_trn.sv
prj_add_source $SRC/rx/prt_dprx_vid_vmap.sv
prj_add_source $SRC/rx/prt_dprx_vid_lmap.sv
prj_add_source $SRC/rx/prt_dprx_vid_fifo.sv
prj_add_source $SRC/rx/prt_dprx_vid.sv
prj_add_source $SRC/rx/prt_dprx_sdp.sv
prj_add_source $SRC/rx/prt_dprx_top.sv
prj_add_source $SRC/rx/prt_dprx_apb.sv

# VTB
prj_add_source $SRC/vtb/prt_vtb_cr.sv
prj_add_source $SRC/vtb/prt_vtb_ctl.sv
prj_add_source $SRC/vtb/prt_vtb_fifo.sv
prj_add_source $SRC/vtb/prt_vtb_tg.sv
prj_add_source $SRC/vtb/prt_vtb_tpg.sv
prj_add_source $SRC/vtb/prt_vtb_freq.sv
prj_add_source $SRC/vtb/prt_vtb_mon.sv
prj_add_source $SRC/vtb/prt_vtb_osd.sv
prj_add_source $SRC/vtb/prt_vtb_top.sv
prj_add_source $SRC/vtb/prt_vtb_apb.sv

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
prj_add_source $SRC/misc/prt_phy_ctl_lsc_apb.sv
prj_add_source $SRC/misc/prt_dp_clkdet.sv
prj_add_source $SRC/misc/prt_dp_msg_slv_egr.sv
prj_add_source $SRC/misc/prt_dp_msg_slv_ing.sv
prj_add_source $SRC/misc/prt_dp_msg_cdc.sv
prj_add_source $SRC/misc/prt_hb.sv
prj_add_source $SRC/misc/prt_apb2lb.sv

# Top
prj_add_source ../../ref/lav_g70_versa_evn/dp_ref_lsc_lav_g70_versa_evn.sv

# Constraint files
prj_add_source ../../ref/lav_g70_versa_evn/dp_ref_lsc_lav_g70_versa_evn.sdc
prj_add_source ../../ref/lav_g70_versa_evn/dp_ref_lsc_lav_g70_versa_evn.pdc

# IP
# Generated from their configuration with the IP of the running Radiant installation.
# ip_upgrade only generates an IP that has a newer version available, so an .ipx that is
# already at the installed version would be added without any RTL.
proc gen_ip {name ip_dir} {
    file mkdir ./$name
    file copy -force ../../ref/lav_g70_versa_evn/$name.cfg ./$name/.
    exec [file dirname $::env(FOUNDRY)]/bin/lin64/ipgenwrap -o ./$name -proj_dir . \
        -ip [file dirname $::env(FOUNDRY)]/ip/$ip_dir -cfg ./$name/$name.cfg -name $name \
        -a LAV-AT -p LAV-AT-X70 -t LFG1156 -sp 1 -op Commercial 2>@1
    prj_add_source ./$name/$name.ipx
}

gen_ip phy avant/mpphyc
gen_ip sys_pll avant/pll_avant

# Set top level
prj_set_impl_opt -impl impl1 top dp_ref_lsc_lav_g70_versa_evn

# Propel
add_ipx_from_dir ../../propel/dp_soc_lav
prj_add_source ../../propel/dp_soc_lav/dp_soc_lav/dp_soc_lav.v

# Set Bitstream IP eval
prj_set_strategy_value -strategy Strategy1 bit_ip_eval=True

# Synthesis options
prj_set_strategy_value -strategy Strategy1 syn_default_enum_encode=Onehot
prj_set_strategy_value -strategy Strategy1 {syn_pipelining_retiming=Pipelining and Retiming}

# Don't stop the flow on timing errors (Radiant 2026.1 default in batch mode)
prj_set_strategy_value -strategy Strategy1 tmchk_enable_check=False

# Make place and route correct hold time violations. Without it the hold fix phase does
# nothing and the SoC is left with hundreds of hold violations at the fast corner.
prj_set_strategy_value -strategy Strategy1 par_impose_hldtiming_correction=True

# Save project
prj_save

# Run synthesis
prj_run_synthesis

# Run mapper
prj_run_map                      

# Run partition
prj_run_par

# Run bitstream
prj_run_bitstream                
