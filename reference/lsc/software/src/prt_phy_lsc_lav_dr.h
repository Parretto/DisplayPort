/*
    PHY Lattice Avant (MPPHY) - DP line rate register table
    GENERATED - do not edit.
    Source : the profile dumps of the PHY generated with dynamic reconfiguration.

    Per line rate the full value of every register that differs between the rates,
    for the transmitter and the receiver apart. A lane block holds the offset within
    a lane and is written to all four lanes; a quad block holds full addresses.
*/

#pragma once

static const prt_phy_lsc_lav_reg_struct prt_phy_lsc_lav_1620_tx_lane[] = {
  {0x00AF,0x1064},
};

static const prt_phy_lsc_lav_reg_struct prt_phy_lsc_lav_1620_tx_quad[] = {
  {0x5800,0x0018}, {0x5801,0x0018}, {0x5802,0x2103}, {0x5803,0x049D},
};

static const prt_phy_lsc_lav_reg_struct prt_phy_lsc_lav_1620_rx_lane[] = {
  {0x00A4,0x6000}, {0x00A5,0x87E0}, {0x00A6,0x1570}, {0x00A7,0x0700}, {0x00A8,0x000F}, {0x00A9,0x002D},
  {0x00AA,0x0008}, {0x00AB,0x0001},
};

static const prt_phy_lsc_lav_reg_struct prt_phy_lsc_lav_2700_tx_lane[] = {
  {0x00AF,0x1064},
};

static const prt_phy_lsc_lav_reg_struct prt_phy_lsc_lav_2700_tx_quad[] = {
  {0x5800,0x0017}, {0x5801,0x0017}, {0x5802,0x2202}, {0x5803,0x049B},
};

static const prt_phy_lsc_lav_reg_struct prt_phy_lsc_lav_2700_rx_lane[] = {
  {0x00A4,0x6000}, {0x00A5,0x8460}, {0x00A6,0x0E6C}, {0x00A7,0x0700}, {0x00A8,0x000F}, {0x00A9,0x002D},
  {0x00AA,0x0008}, {0x00AB,0x0002},
};

static const prt_phy_lsc_lav_reg_struct prt_phy_lsc_lav_5400_tx_lane[] = {
  {0x00AF,0x1060},
};

static const prt_phy_lsc_lav_reg_struct prt_phy_lsc_lav_5400_tx_quad[] = {
  {0x5800,0x0018}, {0x5801,0x0018}, {0x5802,0x2003}, {0x5803,0x088B},
};

static const prt_phy_lsc_lav_reg_struct prt_phy_lsc_lav_5400_rx_lane[] = {
  {0x00A4,0x0000}, {0x00A5,0x0730}, {0x00A6,0x1768}, {0x00A7,0x0600}, {0x00A8,0x000F}, {0x00A9,0x003D},
  {0x00AA,0x0003}, {0x00AB,0x0000},
};

static const prt_phy_lsc_lav_reg_struct prt_phy_lsc_lav_8100_tx_lane[] = {
  {0x00AF,0x1060},
};

static const prt_phy_lsc_lav_reg_struct prt_phy_lsc_lav_8100_tx_quad[] = {
  {0x5800,0x000E}, {0x5801,0x000E}, {0x5802,0x2302}, {0x5803,0x048A},
};

static const prt_phy_lsc_lav_reg_struct prt_phy_lsc_lav_8100_rx_lane[] = {
  {0x00A4,0x5003}, {0x00A5,0x0564}, {0x00A6,0x1764}, {0x00A7,0x4500}, {0x00A8,0x0A0F}, {0x00A9,0x0024},
  {0x00AA,0x0003}, {0x00AB,0x0003},
};

static const prt_phy_lsc_lav_rate_struct prt_phy_lsc_lav_rates[] = {
  {1620, 1, prt_phy_lsc_lav_1620_tx_lane, 4, prt_phy_lsc_lav_1620_tx_quad, 8, prt_phy_lsc_lav_1620_rx_lane},
  {2700, 1, prt_phy_lsc_lav_2700_tx_lane, 4, prt_phy_lsc_lav_2700_tx_quad, 8, prt_phy_lsc_lav_2700_rx_lane},
  {5400, 1, prt_phy_lsc_lav_5400_tx_lane, 4, prt_phy_lsc_lav_5400_tx_quad, 8, prt_phy_lsc_lav_5400_rx_lane},
  {8100, 1, prt_phy_lsc_lav_8100_tx_lane, 4, prt_phy_lsc_lav_8100_tx_quad, 8, prt_phy_lsc_lav_8100_rx_lane},
};

#define PRT_PHY_LSC_LAV_RATES 4
