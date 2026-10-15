###
# Altera Agilex 5 DP reference design GTS transceiver IP
# (c) 2026 by Parretto B.V.
#
# Creates the IP variants for the DisplayPort transceiver in bank 4A.
# Run with: qsys-script --script=gts_ip.tcl --quartus-project=<project>
###

package require qsys

create_system gts_ip
set_project_property DEVICE_FAMILY {Agilex 5}
set_project_property DEVICE A5ED065AB32AE1V

###
# DP PHY
# GTS PMA Direct PHY in DisplayPort mode, 4 lanes duplex: the DPTX transmitters and the DPRX
# receivers in the same channels. The DP RX connector is on the receivers of bank 4A.
# The GTS has no dual simplex mode for the Direct PHY; the transmitters and the receivers have
# their own reset and their own link rate (PCS rate register), so they run independently.
# The DisplayPort mode starts at 10 Gbps with a 32-bit PMA width and requires a 150 MHz reference clock.
# The application switches to the 8b/10b link rates (20-bit PMA width) with the reconfiguration interface.
# 2 symbols per lane: the link clocks are the PMA word clocks (405 MHz at HBR3).
###
add_component dp_phy ip/dp_phy/dp_phy.ip intel_directphy_gts dp_phy
load_component dp_phy
set_component_parameter_value protocol_mode {DISPLAY_PORT}
set_component_parameter_value dp_protocol_mode {1}

# Timing constraints for the highest link rate (HBR3)
set_component_parameter_value dp_sec_pma_data_rate_enable {1}
set_component_parameter_value dp_sec_pma_data_rate {8100}

set_component_parameter_value duplex_mode {duplex}
set_component_parameter_value num_xcvr_per_sys {4}
set_component_parameter_value pma_data_rate {10000}
set_component_parameter_value pma_width {32}

# Clocking
set_component_parameter_value tx_pll_refclk_freq_itxt {150.000000}
set_component_parameter_value tx_pll_refclk_freq_mhz {150.000000}
set_component_parameter_value rx_pll_refclk_freq_mhz {150.000000}
set_component_parameter_value clocking_mode {xcvr}
set_component_parameter_value pmaif_tx_fifo_mode_s {register}
set_component_parameter_value pldif_tx_clkout_sel {TX_WORD_CLK}
set_component_parameter_value pldif_tx_double_width_transfer_enable {0}
set_component_parameter_value pldif_tx_clkout_div {1}
set_component_parameter_value pmaif_rx_fifo_mode_s {register}
set_component_parameter_value pldif_rx_clkout_sel {RX_WORD_CLK}
set_component_parameter_value pldif_rx_double_width_transfer_enable {0}
set_component_parameter_value pldif_rx_clkout_div {1}
set_component_parameter_value rx_adaptation_mode {native}

# The DisplayPort mode requires spread spectrum support on the TX PLL
set_component_parameter_value tx_spread_spectrum_en {ENABLE}

# TX equalization (same as the Altera DisplayPort design example)
set_component_parameter_value ux_txeq_main_tap {47}

# Reconfiguration interface
set_component_parameter_value l_av1_enable {1}
set_component_parameter_value avmm1_soft_csr_enable {1}
set_component_parameter_value avmm1_readdv_enable {1}
save_component

###
# GTS reset sequencer
# One per transceiver bank.
###
add_component gts_rss ip/gts_rss/gts_rss.ip intel_srcss_gts gts_rss
load_component gts_rss
set_component_parameter_value NUM_BANKS_SHORELINE {1}
set_component_parameter_value NUM_LANES_SHORELINE {4}
set_component_parameter_value SRC_RS_DISABLE {0}
save_component
