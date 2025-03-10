/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP Application 
    (c) 2021 - 2025 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    v1.1 - Added 10-bits video support
    v1.2 - Added video resolution 7680x4320P30
    v1.3 - Increased EDID size to 1024 bytes
    v1.4 - Added training clock recovery callback and DPRX spread spectrum option
    v1.5 - Added support for Tentiva board with system controller
    v1.6 - Added PHY reset callback
    
    License
    =======
    This License will apply to the use of the IP-core (as defined in the License). 
    Please read the License carefully so that you know what your rights and obligations are when using the IP-core.
    The acceptance of this License constitutes a valid and binding agreement between Parretto and you for the use of the IP-core. 
    If you download and/or make any use of the IP-core you agree to be bound by this License. 
    The License is available for download and print at www.parretto.com/license
    Parretto grants you, as the Licensee, a free, non-exclusive, non-transferable, limited right to use the IP-core 
    solely for internal business purposes for the term and conditions of the License. 
    You are also allowed to create Modifications for internal business purposes, but explicitly only under the conditions of art. 3.2.
    You are, however, obliged to pay the License Fees to Parretto for the use of the IP-core, or any Modification, in, or embodied in, 
    a physical or non-tangible product or service that has substantial commercial, industrial or non-consumer uses. 
*/

// Includes
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#include "prt_types.h"
#include "prt_printf.h"
#include "prt_log.h"
#include "prt_dp_tokens.h"
#include "prt_pio.h"
#include "prt_uart.h"
#include "prt_tmr.h"
#include "prt_i2c.h"
#include "prt_rc22504a.h"
#include "prt_tentiva.h"
#include "prt_dp_drv.h"
#include "prt_irq.h"
#include "prt_vtb.h"
#include "prt_dp_app.h"
#include "prt_dptx_pm_rom.h"
#include "prt_dptx_pm_ram.h"
#include "prt_dprx_pm_rom.h"
#include "prt_dprx_pm_ram.h"
#include "prt_dp_edid.h"
#include "tentiva_phy_clk.h"
#include "tentiva_vid_clk.h"

// AMD ZCU102 board and Alinx AXAU15 board
#if ((BOARD == BOARD_AMD_ZCU102) || (BOARD == BOARD_ALINX_AXAU15))
     #include "prt_phy_amd_us_gth.h"

// Lattice LFCPNX board
#elif (BOARD == BOARD_LSC_LFCPNX)
     #include "prt_phy_lsc_cpnx.h"

// Intel Cyclone 10GX and Arria 10 GX boards
#elif (BOARD == BOARD_INT_C10GX || BOARD == BOARD_INT_A10GX)
     #include "prt_phy_int_10gx.h"

// Inrevium TB-A7-200T-IMG
#elif (BOARD == BOARD_TB_A7_200T_IMG)
     #include "prt_phy_amd_a7_gtp.h"
#endif

// Data structures
// PIO data structure
prt_pio_ds_struct pio;

// UART data structure
prt_uart_ds_struct uart;

// Timer data structure
prt_tmr_ds_struct tmr;

// I2C data structure
prt_i2c_ds_struct i2c;

// DPTX data structure
prt_dp_ds_struct dptx;

// DPRX data structure
prt_dp_ds_struct dprx;

// PHY structures
// AMD 
#if (VENDOR == VENDOR_AMD)
     // PHY data structure
     prt_phy_amd_ds_struct phy;

// Lattice
#elif (VENDOR == VENDOR_LSC)
     // PHY data structure
     prt_phy_lsc_ds_struct phy;

// Intel 
#elif (VENDOR == VENDOR_INT)
     // PHY data structure
     prt_phy_int_ds_struct phy;
#endif

// VTB data structure
prt_vtb_ds_struct vtb[2];

// Tentiva data structure
prt_tentiva_ds_struct tentiva;

// Log data structure
prt_log_ds_struct log;

// Application data structure
prt_dp_app_struct dp_app;

// License
char *dptx_lic = "12345678";
char *dprx_lic = "12345678";

// Main
int main (void)
{
     // Variables
     prt_sta_type sta;
     uint8_t cmd;
     uint32_t dat;
     uint16_t dpcd_adr;
     uint8_t dpcd_dat;
     uint8_t volt;
     uint8_t pre;
     uint8_t mst_sta;

     // Set application variables
     dp_app.tx.colorbar = false;
     dp_app.tx.mst = false;
     dp_app.rx.pass = false;
     dp_app.vtb_cr_p_gain = 50;
     dp_app.vtb_cr_i_gain = 32000;

     // Initialize log
     prt_log_init (&log);
     
     // Initialize pio
     prt_pio_init (&pio, PRT_PIO_BASE);

     // Initialize uart
     prt_uart_init (&uart, PRT_UART_BASE);

     // Print header
     prt_printf ("\n\n");
     prt_printf ("    __        __   __   ___ ___ ___  __  \n");
     prt_printf ("   |__)  /\\  |__) |__) |__   |   |  /  \\ \n");
     prt_printf ("   |    /~~\\ |  \\ |  \\ |___  |   |  \\__/ \n");
     prt_printf ("\n");
     prt_printf ("DisplayPort reference design v1.0\n");
     prt_printf ("(c) 2021 - 2025 by Parretto B.V.\n");
     prt_printf ("www.parretto.com\n");
     prt_printf ("Date: '%s'\n", __DATE__);
     prt_printf ("Time: '%s'\n", __TIME__);
     prt_printf ("\n");
    
     // Initialize timer
     prt_tmr_init (&tmr, PRT_TMR_BASE);

     // Initialize i2c
     prt_i2c_init (&i2c, PRT_I2C_BASE, I2C_BEAT);

     // Assign DP TX base address
     prt_dp_set_base (&dptx, PRT_DPTX_BASE);
    
     // Reset DPTX
     dp_reset (PRT_DPTX_ID);

     // Assign DP RX base address
     prt_dp_set_base (&dprx, PRT_DPRX_BASE);

     // Reset DPRX
     dp_reset (PRT_DPRX_ID);

// AMD ZCU102 board and Alinx AXAU15 board
#if ((BOARD == BOARD_AMD_ZCU102) || (BOARD == BOARD_ALINX_AXAU15))
     // Initialize PHY
     prt_phy_amd_init (&phy, &tmr, PRT_PHY_BASE);

// Lattice LFCPNX board
#elif (BOARD == BOARD_LSC_LFCPNX)
     // Initialize PHY
     prt_phy_lsc_init (&phy, &tmr, PRT_PHY_BASE);

// Intel Cyclone 10GX board and Arria 10 GX board
#elif (BOARD == BOARD_INT_C10GX || BOARD == BOARD_INT_A10GX)
     // Initialize PHY
     prt_phy_int_init (&phy, &tmr, PRT_PHY_BASE); 

// Inrevium TB-A7-200T-IMG
#elif (BOARD == BOARD_TB_A7_200T_IMG)
     // Initialize PHY
     prt_phy_amd_init (&phy, &tmr, PRT_PHY_BASE);
#endif

     // Assign VTB0 base address
     prt_vtb_set_base (&vtb[0], PRT_VTB0_BASE);

     // Assign VTB1 base address
     prt_vtb_set_base (&vtb[1], PRT_VTB1_BASE);

// Show board
// AMD ZCU102 
#if (BOARD == BOARD_AMD_ZCU102)
     prt_printf ("Board: AMD ZCU102\n");

#elif (BOARD == BOARD_ALINX_AXAU15)
     prt_printf ("Board: Alinx AXAU15\n");

// Lattice CertusPro-NX
#elif (BOARD == BOARD_LSC_LFCPNX)
     prt_printf ("Board: Lattice LFCPNX\n");

// Intel Cyclone 10GX
#elif (BOARD == BOARD_INT_C10GX)
     prt_printf ("Board: Intel DK-DEV-10CX220\n");

// Intel Arria 10GX
#elif (BOARD == BOARD_INT_A10GX)
     prt_printf ("Board: Intel DK-DEV-10AX115S\n");

// Inrevium TB-A7-200T-IMG
#elif (BOARD == BOARD_TB_A7_200T_IMG)
     prt_printf ("Board: Inrevium TB-A7-200T-IMG\n");

#endif

// Get application parameters
     dat = prt_pio_dat_get (&pio);

// Pixels per clock
     if (dat & PIO_IN_PPC)
          dp_app.ppc = 4;
     else
          dp_app.ppc = 2;

     prt_printf ("Pixels per clock: %d\n", dp_app.ppc);

// Bits per component
     if (dat & PIO_IN_BPC)
          dp_app.bpc = 10;
     else
          dp_app.bpc = 8;

     prt_printf ("Bits per component: %d\n", dp_app.bpc);

// ZCU102 FMC I2C mux
#if (BOARD == BOARD_AMD_ZCU102)
     prt_printf ("Enable FMC I2C Mux... ");
     sta = amd_zcu102_fmc_i2c_mux ();

     if (sta == PRT_STA_OK)
          prt_printf ("ok\n");
     else
     {
          prt_printf ("error\n");
          return -1;
     }
#endif

     // Initialize Tentiva FMC
     prt_tentiva_init (&tentiva, &pio, &i2c, &tmr,
          PIO_IN_PHY_REFCLK_LOCK, PIO_IN_VID_REFCLK_LOCK, PIO_OUT_TENTIVA_CLK_SEL);

     // Set PHY clock config 0
     prt_tentiva_set_clk_cfg (&tentiva, PRT_TENTIVA_PHY_DEV, 0, &tentiva_phy_clk_cfg0_reg[0], TENTIVA_PHY_CLK_CONFIG_NUM_REGS);

     // Set PHY clock config 1
     prt_tentiva_set_clk_cfg (&tentiva, PRT_TENTIVA_PHY_DEV, 1, &tentiva_phy_clk_cfg1_reg[0], TENTIVA_PHY_CLK_CONFIG_NUM_REGS);

     // Set Video clock config 0
     prt_tentiva_set_clk_cfg (&tentiva, PRT_TENTIVA_VID_DEV, 0, &tentiva_vid_clk_cfg0_reg[0], TENTIVA_VID_CLK_CONFIG_NUM_REGS);

     // Set Video clock config 1
     prt_tentiva_set_clk_cfg (&tentiva, PRT_TENTIVA_VID_DEV, 1, &tentiva_vid_clk_cfg1_reg[0], TENTIVA_VID_CLK_CONFIG_NUM_REGS);

     // Set Video clock config 2
     prt_tentiva_set_clk_cfg (&tentiva, PRT_TENTIVA_VID_DEV, 2, &tentiva_vid_clk_cfg2_reg[0], TENTIVA_VID_CLK_CONFIG_NUM_REGS);

     // Scan Tentiva
     prt_tentiva_scan (&tentiva);

     // Force Tentiva slot ID
     //prt_tentiva_force_slot_id (&tentiva, 0, PRT_TENTIVA_DP14RX_MCDP6000_ID);

     // Config
     prt_printf ("Tentiva config... ");
     sta = prt_tentiva_cfg (&tentiva, true);      // Fail on config error

     if (sta == PRT_STA_OK)
          prt_printf ("ok\n");
     else
     {
          prt_printf ("error\n");
          return -1;
     }

     // Set the TX card select
     if (prt_tentiva_get_slot_id (&tentiva, 1) == PRT_TENTIVA_DP21TX_ID)
     {
          dp_app.tentiva_dp21tx = true;
          prt_pio_dat_set (&pio, PIO_OUT_TX_CARD);
     }

     else
     {
          dp_app.tentiva_dp21tx = false;
          prt_pio_dat_clr (&pio, PIO_OUT_TX_CARD);
     }

     // Set the RX card select
     if (prt_tentiva_get_slot_id (&tentiva, 0) == PRT_TENTIVA_DP21RX_ID)
     {
          dp_app.tentiva_dp21rx = true;
          prt_pio_dat_set (&pio, PIO_OUT_RX_CARD);
     }
     else
     {
          dp_app.tentiva_dp21rx = false;
          prt_pio_dat_clr (&pio, PIO_OUT_RX_CARD);
     }

// Intel Cyclone 10GX
// After the PHY reference clock is running and before starting the DP,
// the transceiver needs to be setup for all supported line rates. 
#if (BOARD == BOARD_INT_C10GX)
     prt_phy_int_setup (&phy, PRT_PHY_INT_LINERATE_1620);
     prt_phy_int_setup (&phy, PRT_PHY_INT_LINERATE_2700);
     prt_phy_int_setup (&phy, PRT_PHY_INT_LINERATE_5400);
#endif

// Intel Arria 10GX
// After the PHY reference clock is running and before starting the DP,
// the transceiver needs to be setup for all supported line rates. 
#if (BOARD == BOARD_INT_A10GX)
     prt_phy_int_setup (&phy, PRT_PHY_INT_LINERATE_1620);
     prt_phy_int_setup (&phy, PRT_PHY_INT_LINERATE_2700);
     prt_phy_int_setup (&phy, PRT_PHY_INT_LINERATE_5400);
     prt_phy_int_setup (&phy, PRT_PHY_INT_LINERATE_8100);
#endif

     /*
          DPTX
     */

     // Initialize DPTX ROM
     prt_printf ("Initialize DPTX ROM...");
     prt_dp_rom_init (&dptx, prt_dptx_pm_rom_len, &prt_dptx_pm_rom[0]);
     prt_printf ("done\n");

     // Initialize DPTX RAM
     prt_printf ("Initialize DPTX RAM...");
     prt_dp_ram_init (&dptx, prt_dptx_pm_ram_len, &prt_dptx_pm_ram[0]);
     prt_printf ("done\n");

     // Initialize DP TX
     prt_dp_init (&dptx, PRT_DPTX_ID);

     
     // Register DPTX callbacks
     
     // HPD
     prt_dp_set_cb (&dptx, PRT_DP_CB_HPD, &dptx_hpd_cb);

     // Status
     prt_dp_set_cb (&dptx, PRT_DP_CB_STA, &dp_sta_cb);

     // PHY rate
     prt_dp_set_cb (&dptx, PRT_DP_CB_PHY_RATE, &dptx_phy_rate_cb);
     
     // PHY vap
     prt_dp_set_cb (&dptx, PRT_DP_CB_PHY_VAP, &dptx_phy_vap_cb);

     // Training
     prt_dp_set_cb (&dptx, PRT_DP_CB_TRN, &dp_trn_cb);
     
     // Link 
     prt_dp_set_cb (&dptx, PRT_DP_CB_LNK, &dp_lnk_cb);
     
     // Video
     prt_dp_set_cb (&dptx, PRT_DP_CB_VID, &dp_vid_cb);

     // Debug
     prt_dp_set_cb (&dptx, PRT_DP_CB_DBG, &dp_debug_cb);

      
     /*
          DPRX
     */

     // Initialize DPRX ROM
     prt_printf ("Initialize DPRX ROM...");
     prt_dp_rom_init (&dprx, prt_dprx_pm_rom_len, &prt_dprx_pm_rom[0]);
     prt_printf ("done\n");

     // Initialize DPRX RAM
     prt_printf ("Initialize DPRX RAM...");
     prt_dp_ram_init (&dprx, prt_dprx_pm_ram_len, &prt_dprx_pm_ram[0]);
     prt_printf ("done\n");

     // Initialize DP RX
     prt_dp_init (&dprx, PRT_DPRX_ID);

     // Register DPRX callbacks

     // Status
     prt_dp_set_cb (&dprx, PRT_DP_CB_STA, &dp_sta_cb);

     // PHY reset
     prt_dp_set_cb (&dprx, PRT_DP_CB_PHY_RST, &dprx_phy_rst_cb);

     // PHY rate
     prt_dp_set_cb (&dprx, PRT_DP_CB_PHY_RATE, &dprx_phy_rate_cb);
     
     // Training
     prt_dp_set_cb (&dprx, PRT_DP_CB_TRN, &dp_trn_cb);
     
     // Link 
     prt_dp_set_cb (&dprx, PRT_DP_CB_LNK, &dp_lnk_cb);
     
     // Video
     prt_dp_set_cb (&dprx, PRT_DP_CB_VID, &dp_vid_cb);

     // MSA
     prt_dp_set_cb (&dprx, PRT_DP_CB_MSA, &dprx_msa_cb);

     // Debug
     prt_dp_set_cb (&dprx, PRT_DP_CB_DBG, &dp_debug_cb);

// Set TX and RX channel polarity
#if (BOARD == BOARD_LSC_LFCPNX)

     // Tentiva DP21TX card
     if (dp_app.tentiva_dp21tx)
     {
          prt_phy_lsc_tx_pol (&phy, 0, false); // TX channel 0 - normal
          prt_phy_lsc_tx_pol (&phy, 1, false); // TX channel 1 - normal
          prt_phy_lsc_tx_pol (&phy, 2, false);  // TX channel 2 - normal
          prt_phy_lsc_tx_pol (&phy, 3, false);  // TX channel 3 - normal
     }

     // Tentiva DP14TX card
     else
     {
          prt_phy_lsc_tx_pol (&phy, 0, false); // TX channel 0 - normal
          prt_phy_lsc_tx_pol (&phy, 1, false); // TX channel 1 - normal
          prt_phy_lsc_tx_pol (&phy, 2, true);  // TX channel 2 - inverted
          prt_phy_lsc_tx_pol (&phy, 3, true);  // TX channel 3 - inverted
     }

     // Tentiva DP21RX card
     if (dp_app.tentiva_dp21rx)
     {
          prt_phy_lsc_rx_pol (&phy, 0, false);  // RX channel 0 - normal
          prt_phy_lsc_rx_pol (&phy, 1, false);  // RX channel 1 - normal
          prt_phy_lsc_rx_pol (&phy, 2, false);  // RX channel 2 - normal
          prt_phy_lsc_rx_pol (&phy, 3, false);  // RX channel 3 - normal
     }

     // Tentiva DP14RX card
     else
     {
          prt_phy_lsc_rx_pol (&phy, 0, true);  // RX channel 0 - inverted
          prt_phy_lsc_rx_pol (&phy, 1, true);  // RX channel 1 - inverted
          prt_phy_lsc_rx_pol (&phy, 2, true);  // RX channel 2 - inverted
          prt_phy_lsc_rx_pol (&phy, 3, true);  // RX channel 3 - inverted
     }

#endif

     // Initialize IRQ
     prt_irq_init ();

     /*
          DPTX
     */

     // Set license key
     prt_dp_lic (&dptx, dptx_lic);

     // Ping
     prt_printf ("\nDPTX: Ping...");
     if (prt_dp_ping (&dptx))
          prt_printf ("ok\n");
     else
          prt_printf ("error\n");

     // Config
     prt_printf ("DPTX: Config...");

     #if ((BOARD == BOARD_AMD_ZCU102) || (BOARD == BOARD_ALINX_AXAU15))
          dat = PRT_DP_PHY_LINERATE_8100;

     // Lattice CertusPro-NX
     #elif (BOARD == BOARD_LSC_LFCPNX)
          dat = PRT_DP_PHY_LINERATE_5400;

     // Intel Cyclone 10GX
     #elif (BOARD == BOARD_INT_C10GX)
          dat = PRT_DP_PHY_LINERATE_5400;

     // Intel Arria 10GX
     #elif (BOARD == BOARD_INT_A10GX)
          dat = PRT_DP_PHY_LINERATE_8100;

     // Inrevium TB-A7-200T-IMG
     #elif (BOARD == BOARD_TB_A7_200T_IMG)
          dat = PRT_DP_PHY_LINERATE_5400;

     #endif

     // Set maximum link rate
     prt_dp_set_lnk_max_rate (&dptx, dat);

     // Set maximum lanes
     prt_dp_set_lnk_max_lanes (&dptx, 4);

     if (prt_dp_cfg (&dptx))
          prt_printf ("ok\n");
     else
          prt_printf ("error\n");

     /*
          DPRX
     */

     // Set license key
     prt_dp_lic (&dprx, dprx_lic);

     // Ping
     prt_printf ("\nDPRX: Ping...");
     if (prt_dp_ping (&dprx))
          prt_printf ("ok\n");
     else
          prt_printf ("error\n");

     // Config
     prt_printf ("DPRX: Config...");

     #if ((BOARD == BOARD_AMD_ZCU102) || (BOARD == BOARD_ALINX_AXAU15))
          dat = PRT_DP_PHY_LINERATE_8100;

     // Lattice CertusPro-NX
     #elif (BOARD == BOARD_LSC_LFCPNX)
          dat = PRT_DP_PHY_LINERATE_5400;

     // Intel Cyclone 10GX
     #elif (BOARD == BOARD_INT_C10GX)
          dat = PRT_DP_PHY_LINERATE_5400;

     // Intel Arria 10GX
     #elif (BOARD == BOARD_INT_A10GX)
          dat = PRT_DP_PHY_LINERATE_8100;

     // Inrevium TB-A7-200T-IMG
     #elif (BOARD == BOARD_TB_A7_200T_IMG)
          dat = PRT_DP_PHY_LINERATE_5400;

     #endif

     // Set maximum link rate
     prt_dp_set_lnk_max_rate (&dprx, dat);

     // Set maximum lanes
     prt_dp_set_lnk_max_lanes (&dprx, 4);

     // MST capability
     #ifdef MST
          prt_dp_set_mst_cap (&dprx, true);
     #endif 

     if (prt_dp_cfg (&dprx))
          prt_printf ("ok\n");
     else
          prt_printf ("error\n");

     // Set edid
     set_edid (false);

     // HPD plug
     prt_printf ("DPRX: HPD...");

     if (prt_dprx_hpd (&dprx, 2))
          prt_printf ("ok\n");
     else
          prt_printf ("error\n");

     // Menu
     show_menu ();

     // Endless loop
     while (1)
     {
          // Print log buffer
          prt_log_print (&log);

          // Check for any UART input
          if (prt_uart_peek ())
          {
               cmd = prt_uart_get_char ();

               switch (cmd)
               {
                    /*
                         DPTX
                    */

                    // Ping
                    case 'q' :
                         prt_printf ("DPTX: Ping...");
                         if (prt_dp_ping (&dptx))
                              prt_printf ("ok\n");
                         else
                              prt_printf ("error\n");
                         break;

                    // Status
                    case 'e' :
                         prt_printf ("DPTX: Status\n");
                         prt_dp_sta (&dptx);
                         break;

                    // Force training
                    case 'r' :
                         prt_printf ("DPTX: Training\n");
                         prt_printf ("Select maximum line rate:\n");
                         prt_printf (" 1 - 1.62 Gbps\n");
                         prt_printf (" 2 - 2.7 Gbps\n");
                         prt_printf (" 3 - 5.4 Gbps\n");
                         #if ((BOARD == BOARD_AMD_ZCU102) || (BOARD == BOARD_INT_A10GX))
                              prt_printf (" 4 - 8.1 Gbps\n");
                         #endif
                         cmd = prt_uart_get_char ();

                         switch (cmd)
                         {
                              case '2' : dat = PRT_DP_PHY_LINERATE_2700; break;
                              case '3' : dat = PRT_DP_PHY_LINERATE_5400; break;
                              case '4' : dat = PRT_DP_PHY_LINERATE_8100; break;
                              default  : dat = PRT_DP_PHY_LINERATE_1620; break;
                         }

                         // Set max rate
                         prt_dp_set_lnk_max_rate (&dptx, dat);

                         // Force training
                         prt_dptx_trn (&dptx);
                         break;

                    // MST enable / disable
                    case 't' :

                         // Disable
                         if (dp_app.tx.mst)
                         {
                              prt_printf ("\nDPTX: MST stop\n");

                              mst_sta = prt_dptx_mst_stp (&dptx);

                              // Clear flag
                              dp_app.tx.mst = false;

                              // Start colorbar
                              dp_app.tx.colorbar = true;
                         }

                         // Enable
                         else
                         {
                              prt_printf ("\nDPTX: MST start\n");
                              
                              // First stop the video
                              prt_dp_vid_stp (&dptx, 0);

                              mst_sta = prt_dptx_mst_str (&dptx);

                              switch (mst_sta)
                              {
                                   case PRT_DP_MST_OK            : prt_printf ("DPTX: MST ok\n"); break;
                                   case PRT_DP_MST_NO_LOGIC      : prt_printf ("DPTX: MST logic not enabled\n"); break;
                                   case PRT_DP_MST_SNK_NO_CAP    : prt_printf ("DPTX: MST not supported by sink\n"); break;
                                   default                       : prt_printf ("DPTX: MST error\n"); break;
                              }

                              // Set flag
                              if (mst_sta == PRT_DP_MST_OK)
                              {
                                   // Set MST flag
                                   dp_app.tx.mst = true;
                                   
                                   // Start colorbar
                                   dp_app.tx.colorbar = true;
                              }

                              else
                              {
                                   // Clear MST flag
                                   dp_app.tx.mst = false;
                              }
                         }
                         break;


                    /*
                         DPRX
                    */

                    // Ping
                    case 'a' :
                         prt_printf ("DPRX: Ping...");

                         if (prt_dp_ping (&dprx))
                              prt_printf ("ok\n");
                         else
                              prt_printf ("error\n");
                         break;

                    // Status
                    case 'd' :
                         prt_printf ("DPRX: Status\n");
                         prt_dp_sta (&dprx);
                         break;

                    // HPD
                    case 'f' :
                         prt_printf ("DPRX: HPD\n");
                         prt_printf (" 1 - unplug\n");
                         prt_printf (" 2 - plug\n");
                         prt_printf (" 3 - pulse\n");

                         // Get command
                         cmd = prt_uart_get_char ();

                         switch (cmd)
                         {
                              case '2' : dat = 2; break;
                              case '3' : dat = 3; break;
                              default  : dat = 1; break;
                         }

                         if (prt_dprx_hpd (&dprx, dat))
                              prt_printf ("DPRX: ok\n");
                         else
                              prt_printf ("DPRX: error\n");
                         break;

                    /* 
                         VTB 
                    */
                    
                    // Status
                    case 'l' :
                         prt_printf ("VTB: Status\n");
                         vtb_status ();
                         break;

                    /* Operation */

                    // Colorbar
                    case 'z' :
                         prt_printf ("\nColorbar\n");
                         vtb_colorbar (false);
                         break;

                    // Pass-Through
                    case 'x' :
                         prt_printf ("\nPass-Through\n");
                         vtb_pass ();
                         break;

                    // Set edid
                    case 'c' :
                         set_edid (true);
                         break;

                    default :
                         prt_printf ("Unknown command\n");
                         show_menu ();
                         break;
               }
          }

          // Start colorbar
          if (dp_app.tx.colorbar == true)
          {
               // Clear flag
               dp_app.tx.colorbar = false;

               // Start colorbar (1080p)
               vtb_colorbar (true);
          }

          // Pass-through
          if (dp_app.rx.pass == true)
          {
               // Clear flag
               dp_app.rx.pass = false;

               // Start pass-through
               vtb_pass ();
          }
     }
}

/*
     Support functions
*/

     // DP reset
     void dp_reset (uint8_t id)
     {
          uint32_t dat;

          if (id == PRT_DPTX_ID)
               dat = PIO_OUT_DPTX_RST;
          else
               dat = PIO_OUT_DPRX_RST;

          prt_pio_dat_set (&pio, dat);
          prt_pio_dat_clr (&pio, dat);
     }

     // DPTX HPD call back
     void dptx_hpd_cb (prt_dp_ds_struct *dp)
     {
          prt_log_sprintf (&log, "DPTX: ");

          switch (prt_dp_hpd_get (dp))
          {
               case PRT_DP_HPD_PLUG : prt_log_sprintf (&log, "HPD plug\n"); break;
               case PRT_DP_HPD_IRQ : prt_log_sprintf (&log, "HPD pulse\n"); break;
               default : prt_log_sprintf (&log, "HPD unplug\n"); break;
          }
     }

     // Status
     void dp_sta_cb (prt_dp_ds_struct *dp)
     {
          // Variables
          prt_dp_sta_struct sta;

          // Get status
          sta = prt_dp_get_sta (dp);

          // Print prefix
          if (dp->id == PRT_DPTX_ID)
               prt_log_sprintf (&log, "DPTX: ");
          else
               prt_log_sprintf (&log, "DPRX: ");

          prt_log_sprintf (&log, "\thw: %d.%d | ", sta.hw_ver_major, sta.hw_ver_minor);
          prt_log_sprintf (&log, "sw: %d.%d\n", sta.sw_ver_major, sta.sw_ver_minor);
          prt_log_sprintf (&log, "\tmst: %x\n", sta.mst);
          prt_log_sprintf (&log, "\tpio: %x\n", sta.pio);
          prt_log_sprintf (&log, "\thpd: %d\n", sta.hpd);
          prt_log_sprintf (&log, "\tlnk_up: %d | ", sta.lnk_up);
          prt_log_sprintf (&log, "lnk_act_lanes: %d | ", sta.lnk_act_lanes);
          prt_log_sprintf (&log, "lnk_act_rate: %d\n", sta.lnk_act_rate);
          prt_log_sprintf (&log, "\tvid_up: %d\n", sta.vid_up);
     }

     // PHY RX reset
     void dprx_phy_rst_cb (prt_dp_ds_struct *dp)
     {
          #if ((BOARD == BOARD_AMD_ZCU102) || (BOARD == BOARD_ALINX_AXAU15))
          
               // Training pattern 1
               if (prt_dprx_get_trn_tps (&dprx) == 1)
               {
                    // Reset PHY datapath
                    prt_phy_amd_rx_dp_rst (&phy);
               }
          #endif
          
          // Send acknowledge
          prt_dprx_phy_rst_ack (dp);
     }

     // PHY TX rate 
     void dptx_phy_rate_cb (prt_dp_ds_struct *dp)
     {
          // Variables
          uint8_t linerate;

          // Get requested line rate
          linerate = prt_dp_get_phy_rate (dp);
          
          // Set linerate
          phy_set_tx_linerate (linerate);
          
          // For debug only
          //phy_set_rx_linerate (linerate, 0);

          // Send link request ok
          prt_dp_lnk_req_ok (dp);
     }

     // PHY RX rate 
     void dprx_phy_rate_cb (prt_dp_ds_struct *dp)
     {
          // Variables
          uint8_t linerate;
          uint8_t ssc;

          linerate = prt_dp_get_phy_rate (dp);
          ssc = prt_dp_get_phy_ssc (dp);
          
          // Set linerate
          phy_set_rx_linerate (linerate, ssc);

          // Send link request ok
          prt_dp_lnk_req_ok (dp);
     }

     // TX PHY vap 
     void dptx_phy_vap_cb (prt_dp_ds_struct *dp)
     {
          // Variables 
          uint8_t volt;
          uint8_t pre;

          volt = prt_dp_get_phy_volt (dp);
          pre = prt_dp_get_phy_pre (dp);

          // Set voltage and pre-amble
          phy_set_tx_vap (volt, pre);

          // Send link request ok
          prt_dp_lnk_req_ok (dp);
     }

     // Training event
     void dp_trn_cb (prt_dp_ds_struct *dp)
     {
          // Print prefix
          if (dp->id == PRT_DPTX_ID)
               prt_log_sprintf (&log, "DPTX: ");
          else
               prt_log_sprintf (&log, "DPRX: ");

          if (prt_dp_is_trn_pass (dp))
               prt_log_sprintf (&log, "Training pass\n");
          else
               prt_log_sprintf (&log, "Training failed\n");
     }

     // Link event
     void dp_lnk_cb (prt_dp_ds_struct *dp)
     {
          // Print prefix
          if (dp->id == PRT_DPTX_ID)
               prt_log_sprintf (&log, "DPTX: ");
          else
               prt_log_sprintf (&log, "DPRX: ");

          // Link up
          if (prt_dp_is_lnk_up (dp))
          {
               prt_log_sprintf (&log, "Link up | lanes: %d | rate: ", prt_dp_get_lnk_act_lanes (dp));

               switch (prt_dp_get_lnk_act_rate (dp))
               {
                    case PRT_DP_PHY_LINERATE_1620 :
                         prt_log_sprintf (&log, "1.62 Gbps\n");
                         break;

                    case PRT_DP_PHY_LINERATE_2700 :
                         prt_log_sprintf (&log, "2.7 Gbps\n");
                         break;

                    case PRT_DP_PHY_LINERATE_5400 :
                         prt_log_sprintf (&log, "5.4 Gbps\n");
                         break;

                    case PRT_DP_PHY_LINERATE_8100 :
                         prt_log_sprintf (&log, "8.1 Gbps\n");
                         break;

                    default :
                         prt_log_sprintf (&log, "unknown\n");
                         break;
               }

               // After the link is up the colorbar is started
               #ifdef AUTO_COLORBAR
               if (dp->id == PRT_DPTX_ID)
                    dp_app.tx.colorbar = true;
               #endif
          }

          // Link down
          else
          {
               prt_log_sprintf (&log, "Link down | ");

               switch (prt_dp_get_lnk_reason (dp))
               {
                    case PRT_DP_LNK_DOWN_PHY :
                         prt_log_sprintf (&log, "PHY error\n");
                         break;

                    case PRT_DP_LNK_DOWN_CLK :
                         prt_log_sprintf (&log, "Link no clock\n");
                         break;

                    case PRT_DP_LNK_DOWN_CDR :
                         prt_log_sprintf (&log, "CDR loss of lock\n");
                         break;

                    case PRT_DP_LNK_DOWN_SCRM :
                         prt_log_sprintf (&log, "Scrambler loss of lock\n");
                         break;

                    case PRT_DP_LNK_DOWN_TRN :
                         prt_log_sprintf (&log, "Training error\n");
                         break;

                    case PRT_DP_LNK_DOWN_VID :
                         prt_log_sprintf (&log, "Video error\n");
                         break;

                    case PRT_DP_LNK_DOWN_HPD :
                         prt_log_sprintf (&log, "hpd\n");
                         break;

                    case PRT_DP_LNK_DOWN_IDLE :
                         prt_log_sprintf (&log, "Idle\n");
                         break;

                    case PRT_DP_LNK_DOWN_TO :
                         prt_log_sprintf (&log, "Time out (eval expired)\n");
                         break;

                    default :
                         prt_log_sprintf (&log, "Unknown\n");
                         break;
               }
          }
     }

     // Video callback
     void dp_vid_cb (prt_dp_ds_struct *dp)
     {
          // Variables
          uint8_t stream;

          // The DPTX has two streams
          if (dp->id == PRT_DPTX_ID)
               stream = 2;
          
          // Currently the DPRX only supports one stream
          else
               stream = 1;

          // Loop over all streams
          for (uint8_t i = 0; i < stream; i++)
          {
               // Is the event flag asserted?
               if (dp->vid[i].evt)
               {
                    // Clear flag
                    dp->vid[i].evt = false;
                    
                    // Print prefix
                    if (dp->id == PRT_DPTX_ID)
                         prt_log_sprintf (&log, "DPTX: ");
                    else
                         prt_log_sprintf (&log, "DPRX: ");

                    prt_log_sprintf (&log, "Video stream %d ", i);

                    // Video up
                    if (prt_dp_is_vid_up (dp, i))
                    {
                         prt_log_sprintf (&log, "up\n");
                    }

                    // Video down
                    else
                    {
                         prt_log_sprintf (&log, "down | ");

                         switch (prt_dp_get_vid_reason (dp, i))
                         {
                              case PRT_DP_VID_DOWN_CLK :
                                   prt_log_sprintf (&log, "No clock\n");
                                   break;

                              case PRT_DP_VID_DOWN_LNK :
                                   prt_log_sprintf (&log, "video went down\n");
                                   break;

                              case PRT_DP_VID_DOWN_ERR :
                                   prt_log_sprintf (&log, "error\n");
                                   break;

                              case PRT_DP_VID_DOWN_IDLE :
                                   prt_log_sprintf (&log, "idle\n");
                                   break;

                              default :
                                   prt_log_sprintf (&log, "Unknown\n");
                                   break;
                         }

                         // When the RX video is down start the TX colorbar
                         if (dp->id == PRT_DPRX_ID)
                              dp_app.tx.colorbar = true;
                    }
               }
          }
     }

     // MSA callback
     void dprx_msa_cb (prt_dp_ds_struct *dp)
     {
          // Variables
          prt_dp_tp_struct tp;

          prt_log_sprintf (&log, "DPRX: MSA\n");

          // Get DPRX timing parameters
          tp = prt_dprx_tp_get (dp);

          prt_log_sprintf (&log, "\tMvid : %d", tp.mvid);
          prt_log_sprintf (&log, " | Nvid : %d\n", tp.nvid);
          prt_log_sprintf (&log, "\tHtotal : %d", tp.htotal);
          prt_log_sprintf (&log, " | Hstart : %d", tp.hstart);
          prt_log_sprintf (&log, " | Hwidth  : %d", tp.hwidth);
          prt_log_sprintf (&log, " | Hsw : %d\n", tp.hsw);
          prt_log_sprintf (&log, "\tVtotal : %d", tp.vtotal);
          prt_log_sprintf (&log, " | Vstart : %d", tp.vstart);
          prt_log_sprintf (&log, " | Vheight : %d", tp.vheight);
          prt_log_sprintf (&log, " | Vsw : %d\n", tp.vsw);
          prt_log_sprintf (&log, "\tBPC : %d\n", tp.bpc);

          // Start pass-through
          dp_app.rx.pass = true;
     }

     // Debug callback
     void dp_debug_cb (prt_dp_ds_struct *dp)
     {
          // Print prefix
          if (dp->id == PRT_DPTX_ID)
               prt_log_sprintf (&log, "DPTX: ");
          else
               prt_log_sprintf (&log, "DPRX: ");

          prt_log_sprintf (&log, "debug: %x\n", prt_dp_debug_get (dp));
     }

/*
     Menu
*/
     void show_menu (void)
     {
         prt_printf ("\nCommands\n");
         prt_printf ("--------\n");

         prt_printf ("\n__DPTX__\n");
         prt_printf ("q - Ping\n");
         prt_printf ("e - Status\n");
         prt_printf ("r - Read EDID\n");

         prt_printf ("\n__DPRX__\n");
         prt_printf ("a - Ping\n");
         prt_printf ("d - Status\n");
         prt_printf ("f - HPD\n");

         prt_printf ("\n__VTB__\n");
         prt_printf ("l - Status\n");
     
         prt_printf ("\n__Operation__\n");
         prt_printf ("z - Colorbar\n");
         prt_printf ("x - Pass-Through\n");
         prt_printf ("c - Set RX edid\n");

         prt_printf ("\n");
     }

/*
     PHY
*/

// PHY TX line rate
void phy_set_tx_linerate (uint8_t linerate)
{
#if ((BOARD == BOARD_AMD_ZCU102) || (BOARD == BOARD_ALINX_AXAU15))

     // Variables
     uint8_t phy_linerate;

     // Set reference clock
     // The reference clock is always 270 MHz. 
     // Convert PHY linerate
     switch (linerate)
     {
          case PRT_DP_PHY_LINERATE_2700 : phy_linerate = PRT_PHY_AMD_LINERATE_2700; break;
          case PRT_DP_PHY_LINERATE_5400 : phy_linerate = PRT_PHY_AMD_LINERATE_5400; break;
          case PRT_DP_PHY_LINERATE_8100 : phy_linerate = PRT_PHY_AMD_LINERATE_8100; break;
          default : phy_linerate = PRT_PHY_AMD_LINERATE_1620; break;
     }

     // Set TX reference clock
     // The TX reference clock is driven by the Tentiva PHY clock 0.
     // The tentiva driver will just return when the PHY clock generator already provides the requested clock.  
     prt_tentiva_set_phy_freq (&tentiva, 270000);

     // Set TX line rate 
     prt_phy_amd_tx_rate (&phy, phy_linerate);

// Lattice CertusPro-NX
#elif (BOARD == BOARD_LSC_LFCPNX)

     // Variables
     uint32_t freq;
     uint8_t phy_linerate;

     // Find reference clock and PHY linerate
     switch (linerate)
     {
          case PRT_DP_PHY_LINERATE_2700 : freq = 135000; phy_linerate = PRT_PHY_LSC_LINERATE_2700; break;
          case PRT_DP_PHY_LINERATE_5400 : freq = 135000; phy_linerate = PRT_PHY_LSC_LINERATE_5400; break;
          case PRT_DP_PHY_LINERATE_8100 : freq = 135000; phy_linerate = PRT_PHY_LSC_LINERATE_8100; break;
          default : freq = 81000; phy_linerate = PRT_PHY_LSC_LINERATE_1620; break;
     }

     // Set reference clock
     prt_tentiva_set_phy_freq (&tentiva, freq);

     // Update PHY TX linerate
     prt_phy_lsc_tx_rate (&phy, phy_linerate);

// Intel Cyclone 10 GX
#elif (BOARD == BOARD_INT_C10GX)

     // Variables
     uint8_t phy_linerate;

     // Set reference clock
     // The reference clock is always 135 MHz. 
     // Convert PHY linerate
     switch (linerate)
     {
          case PRT_DP_PHY_LINERATE_2700 : phy_linerate = PRT_PHY_INT_LINERATE_2700; break;
          case PRT_DP_PHY_LINERATE_5400 : phy_linerate = PRT_PHY_INT_LINERATE_5400; break;
          default : phy_linerate = PRT_PHY_INT_LINERATE_1620; break;
     }

     // Set TX reference clock
     // The TX reference clock is driven by the Tentiva PHY clock 0.
     // The tentiva driver will just return when the PHY clock generator already provides the requested clock.  
     prt_tentiva_set_phy_freq (&tentiva, 135000);

     // Update PHY TX linerate
     prt_phy_int_tx_rate (&phy, phy_linerate);

// Intel Arria 10 GX
#elif (BOARD == BOARD_INT_A10GX)

     // Variables
     uint8_t phy_linerate;

     // Set reference clock
     // The reference clock is always 135 MHz. 
     // Convert PHY linerate
     switch (linerate)
     {
          case PRT_DP_PHY_LINERATE_2700 : phy_linerate = PRT_PHY_INT_LINERATE_2700; break;
          case PRT_DP_PHY_LINERATE_5400 : phy_linerate = PRT_PHY_INT_LINERATE_5400; break;
          case PRT_DP_PHY_LINERATE_8100 : phy_linerate = PRT_PHY_INT_LINERATE_8100; break;
          default : phy_linerate = PRT_PHY_INT_LINERATE_1620; break;
     }

     // Set TX reference clock
     // The TX reference clock is driven by the Tentiva PHY clock 0.
     // The tentiva driver will just return when the PHY clock generator already provides the requested clock.  
     prt_tentiva_set_phy_freq (&tentiva, 135000);

     // Update PHY TX linerate
     prt_phy_int_tx_rate (&phy, phy_linerate);

// Inrevium TB-A7-200T-IMG
#elif (BOARD == BOARD_TB_A7_200T_IMG)

     // Variables
     uint8_t freq;
     uint8_t phy_linerate;

     // The reference clock is always 135 MHz. 

     // Convert PHY linerate
     switch (linerate)
     {
          case PRT_DP_PHY_LINERATE_2700 : phy_linerate = PRT_PHY_AMD_LINERATE_2700; break;
          case PRT_DP_PHY_LINERATE_5400 : phy_linerate = PRT_PHY_AMD_LINERATE_5400; break;
          default : phy_linerate = PRT_PHY_AMD_LINERATE_1620; break;
     }

     // Set TX reference clock
     // The TX reference clock is driven by the Tentiva PHY clock 0.
     // The tentiva driver will just return when the PHY clock generator already provides the requested clock.  
     prt_tentiva_set_phy_freq (&tentiva, 135000);

     // Set TX line rate 
     prt_phy_amd_tx_rate (&phy, phy_linerate);
#endif
}

// PHY TX voltage and pre-amble
void phy_set_tx_vap (uint8_t volt, uint8_t pre)
{
// AMD 
#if (VENDOR == VENDOR_AMD)
     prt_phy_amd_tx_vap (&phy, volt, pre);

// Lattice 
#elif (VENDOR == VENDOR_LSC)
     prt_phy_lsc_tx_vap (&phy, volt, pre);

// Intel 
#elif (VENDOR == VENDOR_INT)
     prt_phy_int_tx_vap (&phy, volt, pre);
#endif
}

// PHY RX linerate
void phy_set_rx_linerate (uint8_t linerate, uint8_t ssc)
{
// AMD ZCU102
#if ((BOARD == BOARD_AMD_ZCU102) || (BOARD == BOARD_ALINX_AXAU15))

     // Variables
     uint8_t phy_linerate;

     // Set reference clock
     // The RX reference clock is driven by the Tentiva PHY clock 1. 
     // The reference clock is always 270 MHz. 
     // The PHY reference clock is set by the TX linerate function

     // Convert PHY linerate
     switch (linerate)
     {
          case PRT_DP_PHY_LINERATE_2700 : phy_linerate = PRT_PHY_AMD_LINERATE_2700; break;
          case PRT_DP_PHY_LINERATE_5400 : phy_linerate = PRT_PHY_AMD_LINERATE_5400; break;
          case PRT_DP_PHY_LINERATE_8100 : phy_linerate = PRT_PHY_AMD_LINERATE_8100; break;
          default : phy_linerate = PRT_PHY_AMD_LINERATE_1620; break;
     }

     // Set PHY RX line rate 
     prt_phy_amd_rx_rate (&phy, phy_linerate, ssc);

// Lattice CertusPro-NX
#elif (BOARD == BOARD_LSC_LFCPNX)

     // Variables
     uint8_t freq;
     uint8_t phy_linerate;

     // Set reference clock
     // The PHY reference clock is set by the TX linerate function

     // Convert PHY linerate
     switch (linerate)
     {
          case PRT_DP_PHY_LINERATE_2700 : phy_linerate = PRT_PHY_LSC_LINERATE_2700; break;
          case PRT_DP_PHY_LINERATE_5400 : phy_linerate = PRT_PHY_LSC_LINERATE_5400; break;
          case PRT_DP_PHY_LINERATE_8100 : phy_linerate = PRT_PHY_LSC_LINERATE_8100; break;
          default : phy_linerate = PRT_PHY_LSC_LINERATE_1620; break;
     }

     // Set PHY RX linerate
     prt_phy_lsc_rx_rate (&phy, phy_linerate);

// Intel Cyclone 10 GX
#elif (BOARD == BOARD_INT_C10GX)

     // Variables
     uint8_t phy_linerate;

     // Set reference clock
     // The reference clock is always 135 MHz. 
     // The PHY reference clock is set by the TX linerate function

     // Convert PHY linerate
     switch (linerate)
     {
          case PRT_DP_PHY_LINERATE_2700 : phy_linerate = PRT_PHY_INT_LINERATE_2700; break;
          case PRT_DP_PHY_LINERATE_5400 : phy_linerate = PRT_PHY_INT_LINERATE_5400; break;
          case PRT_DP_PHY_LINERATE_8100 : phy_linerate = PRT_PHY_INT_LINERATE_8100; break;
          default : phy_linerate = PRT_PHY_INT_LINERATE_1620; break;
     }

     // Set PHY RX rate
     prt_phy_int_rx_rate (&phy, phy_linerate);

// Intel Arria 10 GX
#elif (BOARD == BOARD_INT_A10GX)

     // Variables
     uint8_t phy_linerate;

     // Set reference clock
     // The reference clock is always 135 MHz. 
     // The PHY reference clock is set by the TX linerate function

     // Convert PHY linerate
     switch (linerate)
     {
          case PRT_DP_PHY_LINERATE_2700 : phy_linerate = PRT_PHY_INT_LINERATE_2700; break;
          case PRT_DP_PHY_LINERATE_5400 : phy_linerate = PRT_PHY_INT_LINERATE_5400; break;
          case PRT_DP_PHY_LINERATE_8100 : phy_linerate = PRT_PHY_INT_LINERATE_8100; break;
          default : phy_linerate = PRT_PHY_INT_LINERATE_1620; break;
     }

     // Set PHY RX rate
     prt_phy_int_rx_rate (&phy, phy_linerate);

// Inrevium TB-A7-200T-IMG
#elif (BOARD == BOARD_TB_A7_200T_IMG)

     // Variables
     uint8_t freq;
     uint8_t phy_linerate;

     // The reference clock is always 135 MHz. 
     // The PHY reference clock is set by the TX linerate function

     // Convert PHY linerate
     switch (linerate)
     {
          case PRT_DP_PHY_LINERATE_2700 : phy_linerate = PRT_PHY_AMD_LINERATE_2700; break;
          case PRT_DP_PHY_LINERATE_5400 : phy_linerate = PRT_PHY_AMD_LINERATE_5400; break;
          default : phy_linerate = PRT_PHY_AMD_LINERATE_1620; break;
     }

     // Set RX line rate 
     prt_phy_amd_rx_rate (&phy, phy_linerate);

#endif
}

/*
     VTB
*/

// Status
void vtb_status (void)
{
     // Variables
     int32_t signed_dat;
     uint32_t unsigned_dat;

     prt_printf ("\tFIFO\n"); 
     prt_printf ("\t\tlock: %d\n", prt_vtb_get_fifo_lock (&vtb[0]));
     prt_printf ("\t\tmax words: %d\n", prt_vtb_get_fifo_max_wrds (&vtb[0]));
     prt_printf ("\t\tmin words: %d\n", prt_vtb_get_fifo_min_wrds (&vtb[0]));

     prt_printf ("\tClock recovery\n"); 
     prt_printf ("\t\terror: ");
     signed_dat = prt_vtb_get_cr_cur_err (&vtb[0]);

     // Negative number
     if (signed_dat < 0)
     {
          prt_printf ("-");
          unsigned_dat = (uint32_t)(-signed_dat);
     }

     // Positive number
     else
          unsigned_dat = (uint32_t)signed_dat;
     prt_printf ("%d\n", unsigned_dat);

     prt_printf ("\t\tmax error: ");
     signed_dat = prt_vtb_get_cr_max_err (&vtb[0]);

     // Negative number
     if (signed_dat < 0)
     {
          prt_printf ("-");
          unsigned_dat = (uint32_t)(-signed_dat);
     }

     // Positive number
     else
          unsigned_dat = (uint32_t)signed_dat;
     prt_printf ("%d\n", unsigned_dat);

     prt_printf ("\t\tmin error: ");
     signed_dat = prt_vtb_get_cr_min_err (&vtb[0]);

     // Negative number
     if (signed_dat < 0)
     {
          prt_printf ("-");
          unsigned_dat = (uint32_t)(-signed_dat);
     }

     // Positive number
     else
          unsigned_dat = (uint32_t)signed_dat;
     prt_printf ("%d\n", unsigned_dat);

     prt_printf ("\t\tsum: ");
     signed_dat = prt_vtb_get_cr_sum (&vtb[0]);

     // Negative number
     if (signed_dat < 0)
     {
          prt_printf ("-");
          unsigned_dat = (uint32_t)(-signed_dat);
     }

     // Positive number
     else
          unsigned_dat = (uint32_t)signed_dat;
     prt_printf ("%d\n", unsigned_dat);

     prt_printf ("\t\tco: ");
     signed_dat = prt_vtb_get_cr_co (&vtb[0]);

     // Negative number
     if (signed_dat < 0)
     {
          prt_printf ("-");
          unsigned_dat = (uint32_t)(-signed_dat);
     }

     // Positive number
     else
          unsigned_dat = (uint32_t)signed_dat;
     prt_printf ("%d\n", unsigned_dat);

     prt_printf ("\tFrequency\n"); 
     prt_printf ("\t\tTX link clock frequency: %d\n", prt_vtb_get_tx_lnk_clk_freq (&vtb[0]));
     prt_printf ("\t\tRX link clock frequency: %d\n", prt_vtb_get_rx_lnk_clk_freq (&vtb[0]));
     prt_printf ("\t\tvideo clock frequency: %d\n", prt_vtb_get_vid_ref_freq (&vtb[0]));
}

// Colorbar
prt_sta_type vtb_colorbar (prt_bool force)
{
     // Variables
     uint8_t cmd;
     prt_vtb_tp_struct vtb_tp;
     prt_dp_tp_struct dp_tp;
     uint8_t vtb_preset;
     uint32_t tentiva_clk;
     uint8_t bpc; 

     prt_printf ("\nStart colorbar\n");

     // Check if DP sink is connected
     if (!prt_dp_is_hpd (&dptx))
     {
          prt_printf ("No DP sink device is connected\n");
          return PRT_STA_FAIL;
     }

     // Disable direct I2C access mode (in case it was running)
     prt_i2c_dia (&i2c, false, false);

     // MST
     if (dp_app.tx.mst)
     {
          // In MST two 1080p60 streams are displayed
          vtb_preset = VTB_PRESET_1920X1080P60;
          
          // Look up video clock
          vtb_tp = prt_vtb_get_tp (&vtb[0]);

          // Modify pixel clock based on pixels per clock
          if (dp_app.ppc == 4)
               tentiva_clk = vtb_tp.pclk >> 2;
          else
               tentiva_clk = vtb_tp.pclk >> 1;

          // Set Tentiva video clock
          prt_printf ("Set video clock frequency: %d kHz\n", tentiva_clk);
          prt_tentiva_set_vid_freq (&tentiva, tentiva_clk);

          for (uint8_t i = 0; i < 2; i++)
          {
               // Start test pattern
               prt_printf ("VTB: Start test pattern\n");

               // Stream 0
               if (i == 0)
                    prt_vtb_tpg (&vtb[i], NULL, vtb_preset, VTB_TPG_FMT_RED);

               // Stream 1
               else
                    prt_vtb_tpg (&vtb[i], NULL, vtb_preset, VTB_TPG_FMT_GREEN);

               // Enable overlay
               prt_vtb_ovl_en (&vtb[i], true);

               // Get video timing parameters
               vtb_tp = prt_vtb_get_tp (&vtb[i]);
               
               // Copy VTB timing parameters to DP   
               dp_tp.htotal = vtb_tp.htotal;
               dp_tp.hwidth = vtb_tp.hwidth;
               dp_tp.hstart = vtb_tp.hstart;
               dp_tp.hsw = vtb_tp.hsw;
               dp_tp.vtotal = vtb_tp.vtotal;
               dp_tp.vheight = vtb_tp.vheight;
               dp_tp.vstart = vtb_tp.vstart;
               dp_tp.vsw = vtb_tp.vsw;

               // Set DPTX MSA
               prt_printf ("DPTX: Set MSA stream %d\n", i);
               prt_dptx_msa_set (&dptx, &dp_tp, i);

               prt_printf ("DPTX: Start video stream %d... ", i);
               if (prt_dp_vid_str (&dptx, i))
                    prt_printf ("ok\n");
               else
               {
                    prt_printf ("error\n");
                    return PRT_STA_FAIL;
               }
          }
          return PRT_STA_OK;
     }

     // SST
     else
     {
          // Disable overlay
          prt_vtb_ovl_en (&vtb[0], false);

          if (force == false)
          {
               // Video resolution
               prt_printf ("Select video resolution:\n");
               prt_printf (" 1 - 1280 x 720p50\n");
               prt_printf (" 2 - 1280 x 720p60\n");
               prt_printf (" 3 - 1920 x 1080p50\n");
               prt_printf (" 4 - 1920 x 1080p60\n");
               prt_printf (" 5 - 2560 x 1440p50\n");
               prt_printf (" 6 - 2560 x 1440p60\n");
               prt_printf (" 7 - 3840 x 2160p50\n");
               prt_printf (" 8 - 3840 x 2160p60\n");
               
               if (dp_app.ppc == 4)
               {
                    prt_printf (" 9 - 5120 x 2880p60\n");
                    prt_printf (" a - 7680 x 4320p30\n");
               }

               cmd = prt_uart_get_char ();

               switch (cmd)
               {
                    // 1280 x 720p @ 50Hz
                    case '1' :
                         vtb_preset  = VTB_PRESET_1280X720P50;
                         break;

                    // 1280 x 720p @ 60Hz
                    case '2' :
                         vtb_preset  = VTB_PRESET_1280X720P60;
                         break;

                    // 1920 x 1080p @ 50Hz
                    case '3' :
                         vtb_preset  = VTB_PRESET_1920X1080P50;
                         break;

                    // 2560 x 1440p @ 50Hz
                    case '5' :
                         vtb_preset  = VTB_PRESET_2560X1440P50;
                         break;

                    // 2560 x 1440p @ 60Hz
                    case '6' :
                         vtb_preset  = VTB_PRESET_2560X1440P60;
                         break;

                    // 3840 x 2160p @ 50Hz
                    case '7' :
                         vtb_preset  = VTB_PRESET_3840X2160P50;
                         break;

                    // 3840 x 2160p @ 60Hz
                    case '8' :
                         vtb_preset  = VTB_PRESET_3840X2160P60;
                         break;

                    // 7680 x 4320p @ 30Hz
                    case 'a' :
                         vtb_preset = VTB_PRESET_7680X4320P30;
                         break;

                    // 1920 x 1080p @ 60Hz
                    default : 
                         vtb_preset = VTB_PRESET_1920X1080P60;
                         break;
               }

               if ((dp_app.bpc == 10) && (vtb_preset != VTB_PRESET_7680X4320P30))
               {
                    prt_printf ("Select color depth:\n");
                    prt_printf (" 1 - 8 bpc\n");
                    prt_printf (" 2 - 10 bpc\n");

                    cmd = prt_uart_get_char ();

                    switch (cmd)
                    {
                         // 10 bpc
                         case '2' :
                              bpc = 10;
                              break;

                         // 8 bpc
                         default :
                              bpc = 8;
                              break;
                    }
               }

               else
                    bpc = 8;
          }

          // Force colorbar at 1920 x 1080p60
          else
          {
               vtb_preset = VTB_PRESET_1920X1080P60;
               bpc = 8;
          }          

          // Start test pattern
          prt_printf ("VTB: Start test pattern\n");
          prt_vtb_tpg (&vtb[0], NULL, vtb_preset, VTB_TPG_FMT_FULL);

          // Get video timing parameters
          vtb_tp = prt_vtb_get_tp (&vtb[0]);
          
          // Modify pixel clock based on pixels per clock
          if (dp_app.ppc == 4)
               tentiva_clk = vtb_tp.pclk >> 2;
          else
               tentiva_clk = vtb_tp.pclk >> 1;

          // Set Tentiva video clock
          prt_printf ("Set video clock frequency: %d kHz\n", tentiva_clk);
          prt_tentiva_set_vid_freq (&tentiva, tentiva_clk);

          // Copy VTB timing parameters to DP   
          dp_tp.htotal = vtb_tp.htotal;
          dp_tp.hwidth = vtb_tp.hwidth;
          dp_tp.hstart = vtb_tp.hstart;
          dp_tp.hsw = vtb_tp.hsw;
          dp_tp.vtotal = vtb_tp.vtotal;
          dp_tp.vheight = vtb_tp.vheight;
          dp_tp.vstart = vtb_tp.vstart;
          dp_tp.vsw = vtb_tp.vsw;

          // Set color depth
          dp_tp.bpc = bpc;           // Bits per component
          prt_printf ("DPTX: Color depth: %d\n", dp_tp.bpc);

          prt_printf ("DPTX: Set MSA\n");
          prt_dptx_msa_set (&dptx, &dp_tp, 0);

          prt_printf ("DPTX: Start video...");
          if (prt_dp_vid_str (&dptx, 0))
               prt_printf ("ok\n");
          else
          {
               prt_printf ("error\n");
               return PRT_STA_FAIL;
          }

          return PRT_STA_OK;
     }
}

// Pass-through
prt_sta_type vtb_pass (void)
{
     // Variables
     uint8_t cmd;
     prt_dp_tp_struct dp_tp;
     prt_vtb_tp_struct vtb_tp;
     uint32_t tentiva_clk;
     uint8_t vtb_preset;

     // Check if DP sink is connected
     if (!prt_dp_is_hpd (&dptx))
     {
          prt_printf ("No DP sink device is connected.\n");
          return PRT_STA_FAIL;
     }

     // Check if a DP TX is up and running
     if (!prt_dp_is_lnk_up (&dptx))
     {
          prt_printf ("DPTX link is not up.\n");
          return PRT_STA_FAIL;
     }

     // Check if a DP RX is up and running
     if (!prt_dp_is_lnk_up (&dprx))
     {
          prt_printf ("DPRX link is not up.\n");
          return PRT_STA_FAIL;
     }
     
     // MST
     if (dp_app.tx.mst)
     {
          prt_printf ("Pass-through not supported in MST.\n");
          return PRT_STA_FAIL;
     }

     prt_printf ("\nStart pass-through\n");

     // Disable overlay
     prt_vtb_ovl_en (&vtb[0], false);

     // Disable direct I2C access mode
     prt_i2c_dia (&i2c, false, false);

     // Get DPRX timing parameters
     dp_tp = prt_dprx_tp_get (&dprx);

     // Find preset
     vtb_preset = prt_vtb_find_preset (dp_tp.htotal, dp_tp.vtotal, &tentiva_clk);

     if (vtb_preset == 0)
     {
          prt_printf ("VTB: video preset not supported\n");
          return PRT_STA_FAIL;
     } 
     
     // Copy DP timing parameters to VTB
     vtb_tp.htotal = dp_tp.htotal;
     vtb_tp.hwidth = dp_tp.hwidth;
     vtb_tp.hstart = dp_tp.hstart;
     vtb_tp.hsw = dp_tp.hsw;
     vtb_tp.vtotal = dp_tp.vtotal;
     vtb_tp.vheight = dp_tp.vheight;
     vtb_tp.vstart = dp_tp.vstart;
     vtb_tp.vsw = dp_tp.vsw;

     // Modify pixel clock based on pixels per clock
     if (dp_app.ppc == 4)
          tentiva_clk = tentiva_clk >> 2;
     else
          tentiva_clk = tentiva_clk >> 1;

     // Update tentiva video clock
     prt_printf ("Set video clock frequency: %d kHz\n", tentiva_clk);
     prt_tentiva_set_vid_freq (&tentiva, tentiva_clk);

     // Enable direct I2C access mode
     prt_printf ("I2C: enable direct access mode\n");
     prt_i2c_dia (&i2c, true, prt_tentiva_has_sc(&tentiva));

     // Select video clock device
     prt_tentiva_sel_dev (&tentiva, PRT_TENTIVA_VID_DEV);

     // Recovery
     prt_printf ("VTB: start clock recovery\n");
     prt_vtb_cr_set_p_gain (&vtb[0], dp_app.vtb_cr_p_gain);
     prt_vtb_cr_set_i_gain (&vtb[0], dp_app.vtb_cr_i_gain);
     prt_vtb_cr (&vtb[0], NULL, vtb_preset);

     // If the video is already running, then stop the video
     if (prt_dp_is_vid_up (&dptx, 0))
     {
          prt_printf ("DPTX: Stop video... ");
          if (prt_dp_vid_stp (&dptx, 0))
               prt_printf ("ok\n");
          else
          {
               prt_printf ("error\n");
               return PRT_STA_FAIL;
          }
     }

     prt_printf ("DPTX: Set MSA\n");
     prt_dptx_msa_set (&dptx, &dp_tp, 0);

     prt_printf ("DPTX: Start video... ");
     if (prt_dp_vid_str (&dptx, 0))
          prt_printf ("ok\n");

     else
     {
          prt_printf ("error\n");
          return PRT_STA_FAIL;
     }

     return PRT_STA_OK;
}


/*
     EDID
*/

// Set edid
void set_edid (prt_bool user)
{
     // Variables
     uint32_t i;
     uint8_t cmd;
     uint8_t edid;

     // Let the user choose the video resolution
     if (user == true)
     {
          prt_printf ("Select RX EDID video resolution:\n");
          prt_printf (" 1 - 1280 x 720p @ 50Hz\n");
          prt_printf (" 2 - 1920 x 1080p @ 50Hz\n");
          prt_printf (" 3 - 2560 x 1440p @ 50Hz\n");
          prt_printf (" 4 - 3840 x 2160p @ 50Hz\n");
          prt_printf (" 0 - All\n");

          // Read command
          cmd = prt_uart_get_char ();

          switch (cmd)
          {
               case '1' : edid = PRT_EDID_1280X720P50; break; 
               case '2' : edid = PRT_EDID_1920X1080P50; break;
               case '3' : edid = PRT_EDID_2560X1440P50; break; 
               case '4' : edid = PRT_EDID_3840X2160P50; break; 
               default  : edid = PRT_EDID_ALL; break;
          }
          
          // Update EDID data
          prt_dp_edid_set (edid);
     }

     // Copy edid to DP driver
     for (i = 0; i < sizeof(edid_dat); i++)
     {
          prt_dp_set_edid_dat (&dprx, i, edid_dat[i]);
     }

     // Write edid to RX policy maker
     prt_printf ("DPRX: Write EDID...");
     if (prt_dprx_edid_wr (&dprx, sizeof(edid_dat)))
          prt_printf ("ok\n");
     else
          prt_printf ("error\n");
     
     if (user == true)
     {
          prt_printf ("Toggle HPD\n");
          prt_dprx_hpd (&dprx, 3);
     }
}

/*
     ZCU102 functions
*/
// AMD ZCU102 board 
#if (BOARD == BOARD_AMD_ZCU102)

     // Set FMC I2C mux
     prt_sta_type amd_zcu102_fmc_i2c_mux (void)
     {
          // Variables
          prt_sta_type sta;

          // Disable all channels on MUX34
          i2c.slave = ZCU102_I2C_MUX_U34_ADR;
          i2c.dat[0] = 0;
          i2c.len = 1;
          sta = prt_i2c_wr (&i2c);

          if (sta != PRT_STA_OK)
          {
               return sta;
          }

          // Enable FMC HPC0 I2C channel on MUX135
          i2c.slave = ZCU102_I2C_MUX_U135_ADR;
          i2c.dat[0] = 1<<0;
          i2c.len = 1;
          sta = prt_i2c_wr (&i2c);

          return sta;
     }

#endif
