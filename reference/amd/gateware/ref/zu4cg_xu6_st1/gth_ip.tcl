###
# DP PHY (GTH transceiver wizard)
# (c) 2026 by Parretto B.V.
#
# Sourced by build_proj.tcl.
#
# Four duplex channels in quad X0Y1 (X0Y4 - X0Y7), reference clock MGTREFCLK1 (270 MHz from the
# Tentiva). As in the AMD Video PHY Controller for DisplayPort, the transmitters run from QPLL1
# and the receivers from the CPLL, so that the TX and RX line rates are independent. The QPLL1
# VCO stays within 8.1 - 12.96 GHz and the CPLL VCO within 2.7 - 4.05 GHz for all line rates.
# The application changes the line rate through the DRP (prt_phy_amd_gth.c), with the attribute
# values of this IP per line rate (prt_phy_amd_gth_dr_zu4cg_xu6_st1.h).
# The free running and DRP clock is 40 MHz: the IP allows at most the user clock of the lowest
# line rate (40.5 MHz at 1.62 Gbps).
# The 8b/10b encoder and decoder are in the transceiver. The user data width is 32 bits
# (four symbols per lane), so the link clock is 202.5 MHz at 8.1 Gbps.
###

create_ip -name gtwizard_ultrascale -vendor xilinx.com -library ip -module_name dp_phy

set_property -dict [list \
    CONFIG.preset                       {GTH-DisplayPort_5_4G} \
    CONFIG.CHANNEL_ENABLE               {X0Y7 X0Y6 X0Y5 X0Y4} \
    CONFIG.TX_MASTER_CHANNEL            {X0Y4} \
    CONFIG.RX_MASTER_CHANNEL            {X0Y4} \
    CONFIG.TX_LINE_RATE                 {5.4} \
    CONFIG.TX_REFCLK_FREQUENCY          {270} \
    CONFIG.TX_PLL_TYPE                  {QPLL1} \
    CONFIG.TX_DATA_ENCODING             {8B10B} \
    CONFIG.TX_USER_DATA_WIDTH           {32} \
    CONFIG.TX_INT_DATA_WIDTH            {40} \
    CONFIG.TX_BUFFER_MODE               {1} \
    CONFIG.TX_OUTCLK_SOURCE             {TXOUTCLKPMA} \
    CONFIG.RX_LINE_RATE                 {5.4} \
    CONFIG.RX_REFCLK_FREQUENCY          {270} \
    CONFIG.RX_PLL_TYPE                  {CPLL} \
    CONFIG.RX_DATA_DECODING             {8B10B} \
    CONFIG.RX_USER_DATA_WIDTH           {32} \
    CONFIG.RX_INT_DATA_WIDTH            {40} \
    CONFIG.RX_BUFFER_MODE               {1} \
    CONFIG.RX_OUTCLK_SOURCE             {RXOUTCLKPMA} \
    CONFIG.RX_EQ_MODE                   {AUTO} \
    CONFIG.RX_SSC_PPM                   {5000} \
    CONFIG.RX_COMMA_PRESET              {K28.5} \
    CONFIG.RX_COMMA_ALIGN_WORD          {1} \
    CONFIG.RX_COMMA_SHOW_REALIGN_ENABLE {true} \
    CONFIG.RX_COMMA_P_ENABLE            {true} \
    CONFIG.RX_COMMA_M_ENABLE            {true} \
    CONFIG.RX_COMMA_DOUBLE_ENABLE       {false} \
    CONFIG.TX_REFCLK_SOURCE             {X0Y7 clk1 X0Y6 clk1 X0Y5 clk1 X0Y4 clk1} \
    CONFIG.RX_REFCLK_SOURCE             {X0Y7 clk1 X0Y6 clk1 X0Y5 clk1 X0Y4 clk1} \
    CONFIG.FREERUN_FREQUENCY            {40} \
    CONFIG.INCLUDE_CPLL_CAL             {1} \
    CONFIG.LOCATE_TX_USER_CLOCKING      {CORE} \
    CONFIG.LOCATE_RX_USER_CLOCKING      {CORE} \
    CONFIG.LOCATE_RESET_CONTROLLER      {CORE} \
    CONFIG.LOCATE_COMMON                {CORE} \
    CONFIG.ENABLE_OPTIONAL_PORTS        {drpaddr_common_in drpaddr_in drpclk_common_in drpclk_in drpdi_common_in drpdi_in drpen_common_in drpen_in drpwe_common_in drpwe_in rxpolarity_in txdiffctrl_in txpolarity_in txpostcursor_in drpdo_common_out drpdo_out drprdy_common_out drprdy_out qpll1lock_out rxcdrlock_out cplllock_out} \
] [get_ips dp_phy]
