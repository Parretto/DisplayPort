/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP Application 
    (c) 2024 - 2026 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
    
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
#include <stdio.h>

#include "hal.h"
#include "sys_platform.h"
#include <riscv_errors.h>

#include "pic.h"
#include "timer.h"
#include "uart.h"
#include "gpio.h"
#include "gpio_regs.h"
#include "i2c_master.h"

#include "lsc_utils.h"

#include "prt_types.h"
#include "prt_log.h"
#include "prt_tentiva.h"
#include "prt_dp_tokens.h"
#include "prt_dp_edid.h"
#include "prt_dp_drv.h"
#include "prt_vtb.h"
#include "prt_dp_fmt.h"
#include "prt_dptx_pm_rom.h"
#include "prt_dptx_pm_ram.h"
#include "prt_dprx_pm_rom.h"
#include "prt_dprx_pm_ram.h"
#ifdef PRT_LSC_LAV
#include "prt_phy_lsc_lav.h"
#else
#include "prt_phy_lsc_cpnx.h"
#endif

#include "prt_dp_app.h"

// Data structures
// PIO structure
struct gpio_instance pio;

// Timer structure
struct timer_instance timer;

// UART structure
struct uart_instance uart;

// I2C data structure
struct i2cm_instance i2c;

// Tentiva data structure
prt_tentiva_ds_struct tentiva;

// DPTX data structure
prt_dp_ds_struct dptx;

// DPRX data structure
prt_dp_ds_struct dprx;

// VTB data structure
prt_vtb_ds_struct vtb;

// Log data structure
prt_log_ds_struct log_ds;

// PHY data structure
prt_phy_lsc_ds_struct phy;

// License
char *dptx_lic = "0000000000000000";
char *dprx_lic = "0000000000000000";

// License key
// The DP IP-cores run one hour without a license key (eight hours with an eval license key).
// Enter the license key from Parretto (16 characters) in dptx_lic and dprx_lic.
static void dp_lic_set (const char *name, prt_dp_ds_struct *dp, char *lic)
{
     uint8_t sta = prt_dp_lic (dp, lic);

     if (sta == PRT_DP_LIC_FULL)
          printf ("%s: licensed to customer %u\n", name, prt_dp_lic_cust (dp));
     else if (sta == PRT_DP_LIC_EVAL)
          printf ("%s: eval license of customer %u, the core stops after 8 hours\n", name, prt_dp_lic_cust (dp));
     else
          printf ("%s: no license, the core stops after 1 hour\n", name);
}

// Application 
dp_app_struct dp_app;


//-----
// Main
//-----
int main (void)
{
    // Variables
    char cmd;
    uint32_t dat;
     prt_sta_type sta;

    // Clear variables
     dp_app.tx.colorbar = false;
     dp_app.tx.edid_rd = false;
     dp_app.tx.edid.valid = false;
     dp_app.tx.fmt = prt_dp_fmt_find (VTB_PRESET_1920X1080P60);
     dp_app.rx.pass = false;
     dp_app.rx.cr = false;

    // Initialize log
    prt_log_init (&log_ds);
     
    // Initialize pio
	pio.instance_name = GPIO_INST_NAME;
	gpio_init (&pio, GPIO_INST_BASE_ADDR, GPIO_INST_LINES_NUM, GPIO_INST_GPIO_DIRS);

	// Clear all output bits
	lsc_gpio_init (&pio);

	// Initialize timer
	timer_init (&timer, CPU0_INST_PICTIMER_START_ADDR, SYS_CLK_FREQ);

    // Initialize uart
	uart_init (&uart, UART_INST_BASE_ADDR, UART_INST_SYS_CLK * 1000000, UART_INST_BAUD_RATE, 1, 8);

	// Register uart callbacks
	lsc_iob_init ();

    // Initialize interrupt controller
    pic_init (CPU0_INST_PICTIMER_START_ADDR);

    // Print header
     printf ("\n\n");
     printf ("    __        __   __   ___ ___ ___  __  \n");
     printf ("   |__)  /\\  |__) |__) |__   |   |  /  \\ \n");
     printf ("   |    /~~\\ |  \\ |  \\ |___  |   |  \\__/ \n");
     printf ("\n");
     printf ("DisplayPort reference design v2.0\n");
     printf ("(c) 2021 - 2026 by Parretto B.V.\n");
     printf ("www.parretto.com\n");
     printf ("Date: '%s'\n", __DATE__);
     printf ("Time: '%s'\n", __TIME__);
     printf ("\n");

    // Initialize the I2C controller
    printf ("Initialize I2C\n");

    // I2C master initialize
    i2c_master_init (&i2c, I2C_INST_BASE_ADDR);

    // Pre-scaler - 100 Hz @ 50 MHz clock
    i2c_master_config (&i2c, I2CM_ADDR_7BIT_MODE, 0, 250);

#ifdef PRT_LSC_LAV
     // The Avant Versa board has an I2C mux in front of the FMC; the Tentiva is on
     // channel 7 (see the HDMI application)
     uint8_t mux = (1 << 7);
     i2c_master_write (&i2c, LSC_LAV_I2C_MUX_ADR, 1, &mux);
#endif

     // Initialize Tentiva FMC
     prt_tentiva_init (&tentiva, &tentiva_i2c_wr_cb, &tentiva_i2c_rd_cb);

     // Scan Tentiva
     prt_tentiva_scan (&tentiva);

     // Config
     printf ("Tentiva config... ");
     sta = prt_tentiva_cfg (&tentiva, false);      // Fail on config error

     if (sta == PRT_STA_OK)
          printf ("ok\n");
     else
     {
          printf ("error\n");
//          return -1;
     }

     // PHY reference clock
     // Set it to the 135 MHz the link rates from HBR up use, now, while the PHY is still held in PMA reset. 
     printf ("PHY reference clock... ");
     if (prt_tentiva_set_phy_freq (&tentiva, 135000) == PRT_STA_OK)
          printf ("ok\n");
     else
          printf ("error\n");

    // Initialize PHY
    prt_phy_lsc_init (&phy, PHY_APB_INST_BASE_ADDR, &timer);

    // Set TX channel polarity
     prt_phy_lsc_tx_pol (&phy, 0, false);  // TX channel 0 - normal
     prt_phy_lsc_tx_pol (&phy, 1, false);  // TX channel 1 - normal
     prt_phy_lsc_tx_pol (&phy, 2, false);  // TX channel 2 - normal
     prt_phy_lsc_tx_pol (&phy, 3, false);  // TX channel 3 - normal

    // Set RX channel polarity
     prt_phy_lsc_rx_pol (&phy, 0, false);  // RX channel 0 - normal
     prt_phy_lsc_rx_pol (&phy, 1, false);  // RX channel 1 - normal
     prt_phy_lsc_rx_pol (&phy, 2, false);  // RX channel 2 - normal
     prt_phy_lsc_rx_pol (&phy, 3, false);  // RX channel 3 - normal


     // Assign DP TX base address
     if (!(prt_dp_set_base (&dptx, DPTX_APB_INST_BASE_ADDR)))
     {
          printf ("DPTX: peripheral not found at base address (%x)!\n", DPTX_APB_INST_BASE_ADDR);
          return 1;
     }

     // Assign DP RX base address
     if (!(prt_dp_set_base (&dprx, DPRX_APB_INST_BASE_ADDR)))
     {
          printf ("DPRX: peripheral not found at base address (%x)!\n", DPRX_APB_INST_BASE_ADDR);
          return 1;
     }

     // Assign VTB base address
     prt_vtb_set_base (&vtb, VTB_APB_INST_BASE_ADDR);

     // Scroller
     prt_vtb_set_osd (&vtb, true, 0, 2);

     // Load colour register
     prt_vtb_set_osd_color (&vtb, 235, 235, 235);

     // A rainbow across the height of the text, travelling with the bounce
     prt_vtb_set_osd_mode (&vtb, PRT_VTB_OSD_MODE_BANDS);

     // Register interrupt
     if (pic_isr_register (DPTX_IRQ, (void *)dptx_irq_handler, (void *)&dptx))
     {
          printf ("DPTX: interrupt registering failed!\n");
          return 1;
     }

     // Register interrupt
     if (pic_isr_register (DPRX_IRQ, (void *)dprx_irq_handler, (void *)&dprx))
     {
          printf ("DPRX: interrupt registering failed!\n");
          return 1;
     }



     /*
          DPTX
     */

     // DPTX reset
     dptx_rst ();

     // Initialize DPTX ROM
     printf ("Initialize DPTX ROM...");
     prt_dp_rom_init (&dptx, prt_dptx_pm_rom_len, &prt_dptx_pm_rom[0]);
     printf ("done\n");

     // Initialize DPTX RAM
     printf ("Initialize DPTX RAM...");
     prt_dp_ram_init (&dptx, prt_dptx_pm_ram_len, &prt_dptx_pm_ram[0]);
     printf ("done\n");

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

     // Set license key
     dp_lic_set ("DPTX", &dptx, dptx_lic);

     // Ping
     printf ("\nDPTX: Ping...");
     if (prt_dp_ping (&dptx))
          printf ("ok\n");
     else
          printf ("error\n");

     // Config
     printf ("DPTX: Config...");

     // Set maximum link rate
#ifdef PRT_LSC_LAV
     // The Avant PHY goes up to HBR3
     prt_dp_set_lnk_max_rate (&dptx, PRT_DP_PHY_LINERATE_8100);
#else
     prt_dp_set_lnk_max_rate (&dptx, PRT_DP_PHY_LINERATE_5400);
#endif

     // Set maximum lanes
     prt_dp_set_lnk_max_lanes (&dptx, 4);

     if (prt_dp_cfg (&dptx))
          printf ("ok\n");
     else
          printf ("error\n");


     /*
          DPRX
     */

     // DPRX reset
     dprx_rst ();

     // Initialize DPRX ROM
     printf ("Initialize DPRX ROM...");
     prt_dp_rom_init (&dprx, prt_dprx_pm_rom_len, &prt_dprx_pm_rom[0]);
     printf ("done\n");

     // Initialize DPRX RAM
     printf ("Initialize DPRX RAM...");
     prt_dp_ram_init (&dprx, prt_dprx_pm_ram_len, &prt_dprx_pm_ram[0]);
     printf ("done\n");

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

     // Set license key
     dp_lic_set ("DPRX", &dprx, dprx_lic);

     // Ping
     printf ("\nDPRX: Ping...");
     if (prt_dp_ping (&dprx))
     {
          printf ("ok\n");
     }
     else
     {
    	 printf ("error\n");
     }

     // Config
     printf ("DPRX: Config...");

     // Set maximum link rate
#ifdef PRT_LSC_LAV
     // The Avant PHY goes up to HBR3
     prt_dp_set_lnk_max_rate (&dprx, PRT_DP_PHY_LINERATE_8100);
#else
     prt_dp_set_lnk_max_rate (&dprx, PRT_DP_PHY_LINERATE_5400);
#endif

     // Set maximum lanes (4)
     prt_dp_set_lnk_max_lanes (&dprx, 4);

     if (prt_dp_cfg (&dprx))
          printf ("ok\n");
     else
          printf ("error\n");

     // Set edid
     set_edid (false);

     // HPD plug
     printf ("DPRX: HPD...");

     if (prt_dprx_hpd (&dprx, 2))
          printf ("ok\n");
     else
          printf ("error\n");

     // Show menu
     show_menu ();

     // Endless loop
     while (1)
     {
          // DP events
          prt_dp_evt_handler (&dptx);
          prt_dp_evt_handler (&dprx);

          // Print log buffer
          prt_log_print (&log_ds, &uart);

          // Check for UART input
          if (lsc_uart_get_char (&uart, &cmd))
          {
              switch (cmd)
			{
                    /*
                         DPTX
                    */

                    // Ping
                    case 'q' :
                         printf ("DPTX: Ping...");
                         if (prt_dp_ping (&dptx))
                              printf ("ok\n");
                         else
                              printf ("error\n");
                         break;


                    // Status
                    case 'e' :
                         printf ("DPTX: Status\n");
                         prt_dp_sta (&dptx);
                         break;


                    /*
                         DPRX
                    */

                    // Ping
                    case 'a' :
                         printf ("DPRX: Ping...");

                         if (prt_dp_ping (&dprx))
                              printf ("ok\n");
                         else
                              printf ("error\n");
                         break;

                    // Status
                    case 'd' :
                         printf ("DPRX: Status\n");
                         prt_dp_sta (&dprx);
                         break;

                    // HPD
                    case 'f' :
                         printf ("DPRX: HPD\n");
                         printf (" 1 - unplug\n");
                         printf (" 2 - plug\n");
                         printf (" 3 - pulse\n");

                         // Get command
                         while (!lsc_uart_get_char (&uart, &cmd));

                         switch (cmd)
                         {
                              case '2' : dat = 2; break;
                              case '3' : dat = 3; break;
                              default  : dat = 1; break;
                         }

                         if (prt_dprx_hpd (&dprx, dat))
                              printf ("DPRX: ok\n");
                         else
                              printf ("DPRX: error\n");
                         break;

                    /* 
                         VTB 
                    */
                    
                    // Status
                    case 'l' :
                         printf ("VTB: Status\n");
                         vtb_status ();
                         break;

                    /* Operation */

                    // Colorbar
                    case 'z' :
                         printf ("\nColorbar\n");
                         vtb_colorbar (false);
                         break;

                    // Pass-Through
                    case 'x' :
                         printf ("\nPass-Through\n");
                         vtb_pass ();
                         break;

                    // Set edid
                    case 'c' :
                         set_edid (true);
                         break;

     	 	 	 default :
     	 	 		 printf ("Unknown command\n\r");
     	 	 		 show_menu ();
     	 	 		 break;
			}
          }

          vtb_task ();
     }
}

/*
	Menu
*/
// Frequency in kHz printed as MHz with three decimals
void print_mhz (uint32_t khz)
{
     printf ("%d.%03d", (int) (khz / 1000), (int) (khz % 1000));
}

void show_menu (void)
{
     printf ("\nCommands\n");
     printf ("--------\n");

     printf ("\n__DPTX__\n");
     printf ("q - Ping\n");
     printf ("e - Status\n");
    
     printf ("\n__DPRX__\n");
     printf ("a - Ping\n");
     printf ("d - Status\n");
     printf ("f - HPD\n");
     printf ("\n__VTB__\n");
     printf ("l - Status\n");

     printf ("\n__Operation__\n");
     printf ("z - Colorbar\n");
     printf ("x - Pass-Through\n");
     printf ("c - Set RX edid\n");
     printf ("\n\r");
}



//-----
// Reset functions
//-----

// DPRX reset
// This function resets the DPRX IP-core.
// The reset is high active.
void dprx_rst (void)
{
	lsc_gpio_set (&pio, PIO_OUT_DPRX_RST);
     lsc_delay (10);
     lsc_gpio_clr (&pio, PIO_OUT_DPRX_RST);
}

// DPTX reset
// This function resets the DPRX IP-core.
// The reset is high active.
void dptx_rst (void)
{
	lsc_gpio_set (&pio, PIO_OUT_DPTX_RST);
     lsc_delay (10);
     lsc_gpio_clr (&pio, PIO_OUT_DPTX_RST);
}

//-----
// Tentiva Callback
//-----

// Tentiva I2C write call back
prt_sta_type tentiva_i2c_wr_cb (uint8_t slave, uint8_t *dat, uint8_t len)
{
    i2c_master_write (&i2c, slave, len, dat);
    return PRT_STA_OK;
}

// Tentiva I2C write call back
prt_sta_type tentiva_i2c_rd_cb (uint8_t slave, uint8_t *dat, uint8_t len)
{
    i2c_master_read (&i2c, slave, len, dat);
    return PRT_STA_OK;
}


//-----
// DP Interrupt handlers
//-----

// Interrupt Handler
void dptx_irq_handler (void *context)
{
     prt_dp_irq_handler (&dptx);
}

// Interrupt Handler
void dprx_irq_handler (void *context)
{
     prt_dp_irq_handler (&dprx);
}


//-----
// DP Callbacks
//-----

// Status
void dp_sta_cb (prt_dp_ds_struct *dp)
{
     // Variables
     prt_dp_sta_struct sta;

     // Get status
     sta = prt_dp_get_sta (dp);

     // Print prefix
     if (dp->id == PRT_DPTX_ID)
          prt_log_sprintf (&log_ds, "DPTX: ");
     else
          prt_log_sprintf (&log_ds, "DPRX: ");

     prt_log_sprintf (&log_ds, "\thw: %d.%d | ", sta.hw_ver_major, sta.hw_ver_minor);
     prt_log_sprintf (&log_ds, "sw: %d.%d\n\r", sta.sw_ver_major, sta.sw_ver_minor);
     prt_log_sprintf (&log_ds, "\tmst: %x\n\r", sta.mst);
     prt_log_sprintf (&log_ds, "\tpio: %x\n\r", sta.pio);
     prt_log_sprintf (&log_ds, "\thpd: %d\n\r", sta.hpd);
     prt_log_sprintf (&log_ds, "\tlnk_up: %d | ", sta.lnk_up);
     prt_log_sprintf (&log_ds, "lnk_act_lanes: %d | ", sta.lnk_act_lanes);
     prt_log_sprintf (&log_ds, "lnk_act_rate: %d\n\r", sta.lnk_act_rate);
     prt_log_sprintf (&log_ds, "\tvid_up: %d\n\r", sta.vid_up);
}

// DPTX HPD call back
void dptx_hpd_cb (prt_dp_ds_struct *dp)
{
     prt_log_sprintf (&log_ds, "DPTX: ");

     switch (prt_dp_hpd_get (dp))
     {
          case PRT_DP_HPD_PLUG :
               prt_log_sprintf (&log_ds, "HPD plug\n");
               // A new sink, read its EDID before the colorbar starts
               dp_app.tx.edid_rd = true;
               break;
          case PRT_DP_HPD_IRQ : prt_log_sprintf (&log_ds, "HPD pulse\n"); break;
          default : prt_log_sprintf (&log_ds, "HPD unplug\n"); break;
     }
}

// PHY RX reset
void dprx_phy_rst_cb (prt_dp_ds_struct *dp)
{    
	// Reset PHY
    prt_phy_lsc_rx_pcs_rst (&phy);

    // Send acknowledge
    prt_dprx_phy_rst_ack (dp);
}

// PHY TX rate 
void dptx_phy_rate_cb (prt_dp_ds_struct *dp)
{
     // Variables
     uint8_t linerate;
     uint32_t freq;
     uint8_t phy_linerate;

     // Get requested line rate
     linerate = prt_dp_get_lnk_rate (dp);

     // Find reference clock and PHY linerate
     switch (linerate)
     {
          case PRT_DP_PHY_LINERATE_2700 : freq = 135000; phy_linerate = PRT_PHY_LSC_LINERATE_2700; break;
          case PRT_DP_PHY_LINERATE_5400 : freq = 135000; phy_linerate = PRT_PHY_LSC_LINERATE_5400; break;
          case PRT_DP_PHY_LINERATE_8100 : freq = 135000; phy_linerate = PRT_PHY_LSC_LINERATE_8100; break;
          default : freq = 81000; phy_linerate = PRT_PHY_LSC_LINERATE_1620; break;
     }

#ifdef PRT_LSC_LAV
     // The Avant PHY runs every line rate from the 135 MHz reference
     (void) freq;
#else
     // Set reference clock
     prt_tentiva_set_phy_freq (&tentiva, freq);
#endif

     // Update PHY TX linerate
     prt_phy_lsc_tx_rate (&phy, phy_linerate);

     // Send link request ok
     prt_dp_lnk_req_ok (dp);
}

// PHY RX rate 
void dprx_phy_rate_cb (prt_dp_ds_struct *dp)
{
     // Variables
     uint8_t linerate;
     uint8_t phy_linerate;
     uint8_t supported_flag;

     // Get requested linerate
     linerate = prt_dp_get_lnk_rate (dp);

     // Find reference clock and PHY linerate
     switch (linerate)
     {
          case PRT_DP_PHY_LINERATE_2700 : phy_linerate = PRT_PHY_LSC_LINERATE_2700; supported_flag = true; break;
          case PRT_DP_PHY_LINERATE_5400 : phy_linerate = PRT_PHY_LSC_LINERATE_5400; supported_flag = true; break;
#ifdef PRT_LSC_LAV
          // The Avant PHY has its own profile for every rate; the CertusPro-NX shares its
          // reference clock with the transmitter, which RBR would take to 81 MHz.
          case PRT_DP_PHY_LINERATE_8100 : phy_linerate = PRT_PHY_LSC_LINERATE_8100; supported_flag = true; break;
          default : phy_linerate = PRT_PHY_LSC_LINERATE_1620; supported_flag = true; break;
#else
          default : phy_linerate = PRT_PHY_LSC_LINERATE_1620; supported_flag = false; break;
#endif
     }

     if (supported_flag)
     {
#ifdef PRT_LSC_LAV
          // The Avant PHY bonds the active lanes
          prt_phy_lsc_rx_lanes (&phy, prt_dp_get_lnk_lanes (dp));
#endif
          // Set PHY RX linerate
          prt_phy_lsc_rx_rate (&phy, phy_linerate);
     }
     
     else
          printf ("DPRX: line rate not supported (%d)\n", phy_linerate);

     // Send link request ok
     prt_dp_lnk_req_ok (dp);
}

// TX PHY vap 
void dptx_phy_vap_cb (prt_dp_ds_struct *dp)
{
     // Variables 
     uint8_t volt;
     uint8_t pre;

     volt = prt_dp_get_lnk_volt (dp);
     pre = prt_dp_get_lnk_pre (dp);

     // Set voltage and pre-amble
     prt_phy_lsc_tx_vap (&phy, volt, pre);

     // Send link request ok
     prt_dp_lnk_req_ok (dp);
}

// Training event
void dp_trn_cb (prt_dp_ds_struct *dp)
{
     // Variables
     bool pass;
     uint8_t lanes = 0;

     // Print prefix
     if (dp->id == PRT_DPTX_ID)
          prt_log_sprintf (&log_ds, "DPTX: ");
     else
          prt_log_sprintf (&log_ds, "DPRX: ");


     // Check if the training passed.
     pass = prt_dp_is_trn_pass (dp);

     // Lanes
     lanes = prt_dp_get_lnk_lanes (dp);

     prt_log_sprintf (&log_ds, "Training ");

     if (pass)
     {
          prt_log_sprintf (&log_ds, "passed\n\r");
     }

     else
     {
          prt_log_sprintf (&log_ds, "failed\n\r");
     }

     prt_log_sprintf (&log_ds, "\tRate: ");

     switch (prt_dp_get_lnk_rate (dp))
     {
          case PRT_DP_PHY_LINERATE_1620 :
               prt_log_sprintf (&log_ds, "1.62 Gbps");
               break;

          case PRT_DP_PHY_LINERATE_2700 :
               prt_log_sprintf (&log_ds, "2.7 Gbps");
               break;

          case PRT_DP_PHY_LINERATE_5400 :
               prt_log_sprintf (&log_ds, "5.4 Gbps");
               break;

          case PRT_DP_PHY_LINERATE_8100 :
               prt_log_sprintf (&log_ds, "8.1 Gbps");
               break;

          default :
               prt_log_sprintf (&log_ds, "unknown");
               break;
     }

     prt_log_sprintf (&log_ds, " | Lanes: %d\n\r", lanes);

     if (pass)
     {
          prt_log_sprintf (&log_ds, "\tVoltage swing level: %d", prt_dp_get_lnk_volt (dp));
          prt_log_sprintf (&log_ds, " | Pre-emphasis level: %d\n\r", prt_dp_get_lnk_pre (dp));
     }
}

// Link event
void dp_lnk_cb (prt_dp_ds_struct *dp)
{
	// Variables

	// Print prefix
     if (dp->id == PRT_DPTX_ID)
          prt_log_sprintf (&log_ds, "DPTX: ");
     else
          prt_log_sprintf (&log_ds, "DPRX: ");

     // Link up
     if (prt_dp_is_lnk_up (dp))
     {
          prt_log_sprintf (&log_ds, "Link up\n\r");

          // After the link is up the colorbar is started
          if (dp->id == PRT_DPTX_ID)
               dp_app.tx.colorbar = true;
     }

     // Link down
     else
     {
          prt_log_sprintf (&log_ds, "Link down | ");

          switch (prt_dp_get_lnk_reason (dp))
          {
               case PRT_DP_LNK_DOWN_PHY :
                    prt_log_sprintf (&log_ds, "PHY error");
                    break;

               case PRT_DP_LNK_DOWN_CLK :
                    prt_log_sprintf (&log_ds, "Link no clock");
                    break;

               case PRT_DP_LNK_DOWN_CDR :
                    prt_log_sprintf (&log_ds, "CDR loss of lock");
                    break;

               case PRT_DP_LNK_DOWN_SCRM :
                    prt_log_sprintf (&log_ds, "Scrambler loss of lock");
                    break;

               case PRT_DP_LNK_DOWN_TRN :
                    prt_log_sprintf (&log_ds, "Training error");
                    break;

               case PRT_DP_LNK_DOWN_VID :
                    prt_log_sprintf (&log_ds, "Video error");
                    break;

               case PRT_DP_LNK_DOWN_HPD :
                    prt_log_sprintf (&log_ds, "hpd");
                    break;

               case PRT_DP_LNK_DOWN_IDLE :
                    prt_log_sprintf (&log_ds, "Idle");
                    break;

               case PRT_DP_LNK_DOWN_TO :
                    prt_log_sprintf (&log_ds, "Time out (eval expired)");
                    break;

               default :
                    prt_log_sprintf (&log_ds, "Unknown");
                    break;
          }
          prt_log_sprintf (&log_ds, "\n\r");
     }
}

// Video callback
void dp_vid_cb (prt_dp_ds_struct *dp)
{
     // Variables
     uint8_t stream = 1;
     uint8_t reason = 0;

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
                    prt_log_sprintf (&log_ds, "DPTX: ");
               else
                    prt_log_sprintf (&log_ds, "DPRX: ");

               prt_log_sprintf (&log_ds, "Video stream %d ", i);

               // Video up
               if (prt_dp_is_vid_up (dp, i))
               {
                    prt_log_sprintf (&log_ds, "up\n\r");
               }

               // Video down
               else
               {
                    prt_log_sprintf (&log_ds, "down | ");

                    switch (prt_dp_get_vid_reason (dp, i))
                    {
                         case PRT_DP_VID_DOWN_CLK :
                              prt_log_sprintf (&log_ds, "No clock");
                              reason = 1;
                              break;

                         case PRT_DP_VID_DOWN_LNK :
                              prt_log_sprintf (&log_ds, "video went down");
                              reason = 3;
                              break;

                         case PRT_DP_VID_DOWN_ERR :
                              prt_log_sprintf (&log_ds, "error");
                              reason = 4;
                              break;

                         case PRT_DP_VID_DOWN_IDLE :
                              prt_log_sprintf (&log_ds, "idle");
                              reason = 2;
                              break;

                         default :
                              prt_log_sprintf (&log_ds, "Unknown");
                              break;
                    }
                    prt_log_sprintf (&log_ds, "\n\r");

                    // When the RX video of the pass-through is down start the TX colorbar.
                    // Without a pass-through the colorbar is still running.
                    if ((dp->id == PRT_DPRX_ID) && dp_app.rx.cr)
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

     // Get DPRX timing parameters
     tp = prt_dprx_tp_get (dp);

     // The policy maker also reports a change of the colour parameters alone (VSC), which may
     // come before the first MSA. Without a timing there is nothing to pass through yet.
     if ((tp.htotal == 0) || (tp.vtotal == 0))
          return;

     prt_log_sprintf (&log_ds, "DPRX: MSA\n\r");

     prt_log_sprintf (&log_ds, "\tMvid : %d", tp.mvid);
     prt_log_sprintf (&log_ds, " | Nvid : %d\n\r", tp.nvid);
     prt_log_sprintf (&log_ds, "\tHtotal : %d", tp.htotal);
     prt_log_sprintf (&log_ds, " | Hstart : %d", tp.hstart);
     prt_log_sprintf (&log_ds, " | Hwidth : %d", tp.hwidth);
     // The sync width fields carry the sync polarity in bit 15
     prt_log_sprintf (&log_ds, " | Hsw : %d", tp.hsw & 0x7fff);
     prt_log_sprintf (&log_ds, " | Hsp : %d\n\r", (tp.hsw >> 15) & 1);
     prt_log_sprintf (&log_ds, "\tVtotal : %d", tp.vtotal);
     prt_log_sprintf (&log_ds, " | Vstart : %d", tp.vstart);
     prt_log_sprintf (&log_ds, " | Vheight : %d", tp.vheight);
     prt_log_sprintf (&log_ds, " | Vsw : %d", tp.vsw & 0x7fff);
     prt_log_sprintf (&log_ds, " | Vsp : %d\n\r", (tp.vsw >> 15) & 1);
     prt_log_sprintf (&log_ds, "\tBPC : %d", tp.bpc);
     prt_log_sprintf (&log_ds, " | Colorspace : ");

     switch (tp.csf)
     {
          case PRT_DP_CSF_RGB :
               prt_log_sprintf (&log_ds, "RGB\n");
               break;

          case PRT_DP_CSF_YCBCR444 :
               prt_log_sprintf (&log_ds, "YCbCr 444\n");
               break;

          case PRT_DP_CSF_YCBCR422 :
               prt_log_sprintf (&log_ds, "YCbCr 422\n");
               break;

          case PRT_DP_CSF_YCBCR420 :
               prt_log_sprintf (&log_ds, "YCbCr 420\n");
               break;

          default :
               prt_log_sprintf (&log_ds, "Unknown\n");
               break;
     }

     // Start pass-through
     dp_app.rx.pass = true;
}

// Debug callback
void dp_debug_cb (prt_dp_ds_struct *dp)
{
     // Print prefix
     if (dp->id == PRT_DPTX_ID)
          prt_log_sprintf (&log_ds, "DPTX: ");
     else
          prt_log_sprintf (&log_ds, "DPRX: ");

     // The debug event is a single flag, so take everything that is waiting. Reading one
     // value per event left the rest behind until a later event, or for good.
     prt_log_sprintf (&log_ds, "debug:");

     while (prt_dp_is_debug (dp))
          prt_log_sprintf (&log_ds, " %x", prt_dp_debug_get (dp));

     prt_log_sprintf (&log_ds, "\n\r");
}


/*
     EDID
*/

// Set edid
void set_edid (bool user)
{
     // Variables
     uint32_t i;
     uint8_t cmd;
     uint8_t edid;

     // Let the user choose the video resolution
     if (user == true)
     {
          printf ("Select RX EDID video resolution:\n");
          printf (" 1 - 1280 x 720p @ 50Hz\n");
          printf (" 2 - 1920 x 1080p @ 50Hz\n");
          printf (" 3 - 2560 x 1440p @ 50Hz\n");
          printf (" 4 - 3840 x 2160p @ 50Hz\n");
          printf (" 0 - All\n");

          // Read command
          while (!lsc_uart_get_char (&uart, &cmd));

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

     // Write edid to RX policy maker
     printf ("DPRX: Write EDID...");
     if (prt_dprx_edid_wr (&dprx, sizeof(edid_dat), edid_dat))
          printf ("ok\n");
     else
          printf ("error\n");

     if (user == true)
     {
          printf ("Toggle HPD\n");
          prt_dprx_hpd (&dprx, 3);
     }
}


/*
     VTB
*/

// Status
void vtb_status (void)
{
     // Variables
     int32_t signed_dat;
     uint32_t dat;

     printf ("\tFIFO\n"); 
     printf ("\t\tlock: %d\n", prt_vtb_get_fifo_lock (&vtb));
     printf ("\t\tmax words: %d\n", prt_vtb_get_fifo_max_wrds (&vtb));
     printf ("\t\tmin words: %d\n", prt_vtb_get_fifo_min_wrds (&vtb));

     // Last loss of lock
     dat = prt_vtb_get_fifo_loss (&vtb);
     printf ("\t\tlosses: %d | last: %s%s at line %d with %d words\n",
             dat >> PRT_VTB_IG_FIFO_LOSS_CNT_SHIFT,
             (dat & PRT_VTB_IG_FIFO_LOSS_EP) ? "empty" : "",
             (dat & PRT_VTB_IG_FIFO_LOSS_FL) ? "full" : "",
             (dat >> PRT_VTB_IG_FIFO_LOSS_LIN_SHIFT) & 0xfff,
             (dat >> PRT_VTB_IG_FIFO_LOSS_WRDS_SHIFT) & 0x3ff);

     // Incoming video. The monitor counts two pixels per valid.
     dat = prt_vtb_get_mon (&vtb);
     printf ("\tMonitor\n");
     printf ("\t\tpixels: %d | lines: %d\n",
             (dat >> PRT_VTB_IG_MON_PIX_SHIFT) & 0xffff, (dat >> PRT_VTB_IG_MON_LIN_SHIFT) & 0xffff);

     printf ("\tClock recovery\n"); 
     printf ("\t\terror: ");
     signed_dat = prt_vtb_get_cr_cur_err (&vtb);

     printf ("%d\n", signed_dat);

     printf ("\t\tmax error: ");
     signed_dat = prt_vtb_get_cr_max_err (&vtb);
     printf ("%d\n", signed_dat);

     printf ("\t\tmin error: ");
     signed_dat = prt_vtb_get_cr_min_err (&vtb);
     printf ("%d\n", signed_dat);

     printf ("\t\tsum: ");
     signed_dat = prt_vtb_get_cr_sum (&vtb);
     printf ("%d\n", signed_dat);

     printf ("\t\tco: ");
     signed_dat = prt_vtb_get_cr_co (&vtb);
     printf ("%d\n", signed_dat);

     printf ("\tClock\n");
     printf ("\t\tTX link clock frequency: ");
     print_mhz ((prt_vtb_get_tx_lnk_clk_freq (&vtb) + 500) / 1000);
     printf (" MHz\n");
     printf ("\t\tRX link clock frequency: ");
     print_mhz ((prt_vtb_get_rx_lnk_clk_freq (&vtb) + 500) / 1000);
     printf (" MHz\n");
     printf ("\t\tvideo clock frequency: ");
     print_mhz ((prt_vtb_get_vid_ref_freq (&vtb) + 500) / 1000);
     printf (" MHz\n");
}

// Set the video clock (kHz)
// The Tentiva generates the video clock. In the pass-through the clock recovery of the VTB
// steers its DCO (vtb_task).
static void vid_clk_set (uint32_t vid_clk)
{
     printf ("Set video clock frequency: ");
     print_mhz (vid_clk);
     printf (" MHz\n");
     if (prt_tentiva_set_vid_freq (&tentiva, vid_clk) != PRT_STA_OK)
          printf ("Tentiva: video clock error\n");
}

// Colorbar
prt_sta_type vtb_colorbar (prt_bool force)
{
     // Variables
     uint8_t cmd;
     prt_vtb_tp_struct vtb_tp;
     prt_dp_tp_struct dp_tp;
     uint8_t vtb_preset;
     uint8_t bpc; 
     prt_dp_csf_type csf;

     printf ("\nStart colorbar\n");

     // Clear clock recovery flag
     dp_app.rx.cr = false;

     // Check if DP sink is connected
     if (!prt_dp_is_hpd (&dptx))
     {
          printf ("No DP sink device is connected\n");
          return PRT_STA_FAIL;
     }


     if (force == false)
     {
          // Video resolution
          // The formats this board generates, with what the sink and the link say about them
          printf ("Select video resolution:\n");

          for (uint8_t i = 0; i < PRT_DP_FMT_CNT; i++)
          {
               if (prt_dp_fmt[i].pclk > DP_APP_PCLK_MAX)
                    continue;

               printf (" %d - %-16s", i + 1, prt_dp_fmt[i].name);

               switch (prt_dp_fmt_sink (&dp_app.tx.edid, i))
               {
                    case PRT_DP_FMT_SINK_PREF : printf ("  (sink: preferred)"); break;
                    case PRT_DP_FMT_SINK_YES : printf ("  (sink: yes)"); break;
                    default : break;
               }

               if (!prt_dp_fmt_link (i, prt_dp_get_lnk_rate (&dptx), prt_dp_get_lnk_lanes (&dptx), 8))
                    printf ("  (link: no)");

               printf ("\n");
          }

          printf (" other key - %s\n", prt_dp_fmt[dp_app.tx.fmt].name);

          while (!lsc_uart_get_char (&uart, &cmd));

          if ((cmd >= '1') && (cmd < ('1' + PRT_DP_FMT_CNT)) && (prt_dp_fmt[cmd - '1'].pclk <= DP_APP_PCLK_MAX))
               dp_app.tx.fmt = cmd - '1';

          vtb_preset = prt_dp_fmt[dp_app.tx.fmt].preset;

          printf ("Select color depth:\n");
          printf (" 1 - 8 bpc\n");
          printf (" 2 - 10 bpc\n");

          while (!lsc_uart_get_char (&uart, &cmd));

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

          printf ("Select color space:\n");
          printf (" 1 - RGB\n");
          printf (" 2 - YCbCr 4:4:4\n");

          while (!lsc_uart_get_char (&uart, &cmd));

          csf = (cmd == '2') ? PRT_DP_CSF_YCBCR444 : PRT_DP_CSF_RGB;
     }

     // Force colorbar in the format of the sink
     else
     {
          dp_app.tx.fmt = prt_dp_fmt_pick (&dp_app.tx.edid, prt_dp_get_lnk_rate (&dptx), prt_dp_get_lnk_lanes (&dptx),
                                           DP_APP_PCLK_MAX, prt_dp_fmt_find (VTB_PRESET_1920X1080P60));
          vtb_preset = prt_dp_fmt[dp_app.tx.fmt].preset;
          bpc = 8;
          csf = PRT_DP_CSF_RGB;
          printf ("Format: %s\n", prt_dp_fmt[dp_app.tx.fmt].name);
     }          

     // If the video is already running, then stop the video
     // (before the test pattern, the video clock and the MSA change)
     if (prt_dp_is_vid_up (&dptx, 0))
     {
          printf ("DPTX: Stop video...");
          if (prt_dptx_vid_stp (&dptx, 0))
               printf ("ok\n");
          else
          {
               printf ("error\n");
               return PRT_STA_FAIL;
          }
     }

     // Start test pattern
     printf ("VTB: Start test pattern\n");
     prt_vtb_set_csf (&vtb, csf);

     prt_vtb_tpg (&vtb, NULL, vtb_preset, VTB_TPG_FMT_FULL);

     // Get video timing parameters
     vtb_tp = prt_vtb_get_tp (&vtb);

     // Put what goes out on the wire into the scroller. 
     prt_vtb_osd_text (&vtb, NULL, vtb_tp.hwidth, vtb_tp.vheight,
                       prt_vtb_osd_hz (vtb_tp.pclk, vtb_tp.htotal, vtb_tp.vtotal), csf, bpc,
                       prt_dp_get_lnk_lanes (&dptx), prt_dp_get_lnk_rate (&dptx));

     // Video clock (pixel clock / 4)
     vid_clk_set (vtb_tp.pclk >> 2);

     // Copy VTB timing parameters to DP   
     dp_tp.htotal = vtb_tp.htotal;
     dp_tp.hwidth = vtb_tp.hwidth;
     dp_tp.hstart = vtb_tp.hstart;
     dp_tp.hsw = vtb_tp.hsw;
     dp_tp.vtotal = vtb_tp.vtotal;
     dp_tp.vheight = vtb_tp.vheight;
     dp_tp.vstart = vtb_tp.vstart;
     dp_tp.vsw = vtb_tp.vsw;
     dp_tp.csf = csf;

     // Set color depth
     dp_tp.bpc = bpc;           // Bits per component
     printf ("DPTX: Color depth: %d\n", dp_tp.bpc);
     printf ("DPTX: Color space: %s\n", (csf == PRT_DP_CSF_YCBCR444) ? "YCbCr 4:4:4" : "RGB");

     printf ("DPTX: Set MSA\n");
     prt_dptx_msa_set (&dptx, &dp_tp, 0);

     printf ("DPTX: Start video...");
     if (prt_dptx_vid_str (&dptx, 0))
          printf ("ok\n");
     else
     {
          printf ("error\n");
          return PRT_STA_FAIL;
     }

     return PRT_STA_OK;
}


// Read EDID
// Read the EDID of the sink and keep what it offers for the colorbar.
void edid_read (void)
{
     // Variables
     uint8_t dat[256];
     prt_dp_fmt_edid_struct *edid = &dp_app.tx.edid;

     printf ("DPTX: Read EDID...");

     // Base block and the first extension
     if (!prt_dptx_edid_rd (&dptx, 0, sizeof (dat), dat) || !prt_dp_fmt_edid_parse (dat, sizeof (dat), edid))
     {
          edid->valid = false;
          printf ("error\n");
          return;
     }

     printf ("ok\n");

     if (edid->dtd_cnt)
          printf ("\tPreferred: %d x %dp%d\n", edid->dtd[0].h, edid->dtd[0].v, edid->dtd[0].hz);

     printf ("\tVIC:");
     for (uint8_t i = 0; i < edid->vic_cnt; i++)
          printf (" %d", edid->vic[i]);
     printf ("\n");
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
          printf ("No DP sink device is connected.\n");
          return PRT_STA_FAIL;
     }

     // Check if a DP TX is up and running
     if (!prt_dp_is_lnk_up (&dptx))
     {
          printf ("DPTX link is not up.\n");
          return PRT_STA_FAIL;
     }

     // Check if a DP RX is up and running
     if (!prt_dp_is_lnk_up (&dprx))
     {
          printf ("DPRX link is not up.\n");
          return PRT_STA_FAIL;
     }

     printf ("\nStart pass-through\n");

     // Get DPRX timing parameters
     dp_tp = prt_dprx_tp_get (&dprx);

     // The scroller follows the color space of the received video
     prt_vtb_set_csf (&vtb, dp_tp.csf);

     // Find preset
     vtb_preset = prt_vtb_find_preset (dp_tp.htotal, dp_tp.vtotal, &tentiva_clk);

     if (vtb_preset == 0)
     {
          printf ("VTB: video preset not supported\n");
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

     // The scroller stays on in pass-through
     prt_vtb_osd_text (&vtb, "PASS-THROUGH", dp_tp.hwidth, dp_tp.vheight,
                       prt_vtb_osd_hz (tentiva_clk, dp_tp.htotal, dp_tp.vtotal), dp_tp.csf, dp_tp.bpc,
                       prt_dp_get_lnk_lanes (&dptx), prt_dp_get_lnk_rate (&dptx));

     // Video clock (pixel clock / 4)
     vid_clk_set (tentiva_clk >> 2);

     // Recovery
     printf ("VTB: start clock recovery\n");
     prt_vtb_cr_set_p_gain (&vtb, DP_APP_CR_P_GAIN);
     prt_vtb_cr_set_i_gain (&vtb, DP_APP_CR_I_GAIN);
     prt_vtb_cr (&vtb, NULL, vtb_preset);

     // Set video clock recovery flag
     dp_app.rx.cr = true;

     // If the video is already running, then stop the video
     if (prt_dp_is_vid_up (&dptx, 0))
     {
          printf ("DPTX: Stop video... ");
          if (prt_dptx_vid_stp (&dptx, 0))
               printf ("ok\n");
          else
          {
               printf ("error\n");
               return PRT_STA_FAIL;
          }
     }

     printf ("DPTX: Set MSA\n");
     prt_dptx_msa_set (&dptx, &dp_tp, 0);

     printf ("DPTX: Start video... ");
     if (prt_dptx_vid_str (&dptx, 0))
          printf ("ok\n");

     else
     {
          printf ("error\n");
          return PRT_STA_FAIL;
     }

     return PRT_STA_OK;
}


//-----
// Tasks
//-----

void vtb_task (void)
{
	// Variables
	prt_sta_type sta;
	uint32_t dco;

    // Colorbar event
    if (dp_app.tx.colorbar == true)
    {
         // Clear flag
         dp_app.tx.colorbar = false;

         // Read the EDID of a new sink
         if (dp_app.tx.edid_rd)
         {
              dp_app.tx.edid_rd = false;
              edid_read ();
         }

         // Start colorbar in the format of the sink
         vtb_colorbar (true);
    }

    // Pass-through event
    if (dp_app.rx.pass == true)
    {
         // Clear flag
         dp_app.rx.pass = false;

         // Start pass-through
         vtb_pass ();
    }

    // Video clock recovery
    if (dp_app.rx.cr)
    {
    	// Read dco value from clock recovery
    	dco = prt_vtb_get_cr_co (&vtb);

    	sta = prt_tentiva_sc_dco (&tentiva, dco);
    	if (sta != PRT_STA_OK)
    		printf ("VTB: DCO write error\n");
    }
}
