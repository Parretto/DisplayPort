/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: DP Application Header
    (c) 2021 - 2026 by Parretto B.V.

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

#pragma once

// Defines
#define SYS_CLK_FREQ                    50000000

// Interrupt
#define DPTX_IRQ                        2
#define DPRX_IRQ                        3

// PIO out
#define PIO_OUT_DPTX_RST                (1<<0)
#define PIO_OUT_DPRX_RST                (1<<1)

// I2C mux on the Avant Versa board
#define LSC_LAV_I2C_MUX_ADR             0x70

// Colorbar
// The largest pixel clock (kHz) the video toolbox generates on these boards
#define DP_APP_PCLK_MAX                 594000

// Video clock recovery
// Gains of the VTB clock recovery. The controller output steers the DCO of the Tentiva video clock.
#define DP_APP_CR_P_GAIN                50
#define DP_APP_CR_I_GAIN                32000

// Peripheral base addresses
// The Avant SoC exports the DP peripherals as ports of its interconnect, so its BSP has no
// base address for them. They sit where the CertusPro-NX SoC has them.
#ifndef DPTX_APB_INST_BASE_ADDR
#define DPTX_APB_INST_BASE_ADDR         0x40002000
#endif
#ifndef DPRX_APB_INST_BASE_ADDR
#define DPRX_APB_INST_BASE_ADDR         0x40003000
#endif
#ifndef VTB_APB_INST_BASE_ADDR
#define VTB_APB_INST_BASE_ADDR          0x40004000
#endif
#ifndef PHY_APB_INST_BASE_ADDR
#define PHY_APB_INST_BASE_ADDR          0x40005000
#endif

// Data structure
typedef struct {
     bool colorbar;			// Colorbar
     bool edid_rd;			// Read the EDID of the sink
     prt_dp_fmt_edid_struct edid;	// What the sink's EDID offers
     uint8_t fmt;			// Colorbar format (prt_dp_fmt)
} prt_dp_app_tx_struct;

typedef struct {
     bool pass;				// Pass-through
     bool cr;				// Clock recovery
} prt_dp_app_rx_struct;

typedef struct {
     prt_dp_app_tx_struct tx;
     prt_dp_app_rx_struct rx;
     uint8_t ppc;
     uint8_t bpc;
} dp_app_struct;

// Prototypes
void show_menu (void);
void print_mhz (uint32_t khz);
void dptx_rst (void);
void dprx_rst (void);
void dptx_irq_handler (void *context);
void dprx_irq_handler (void *context);
void set_edid (bool user);
void vtb_status (void);
void edid_read (void);
prt_sta_type vtb_colorbar (prt_bool force);
prt_sta_type vtb_pass (void);

// Tentiva callbacks
prt_sta_type tentiva_i2c_wr_cb (uint8_t slave, uint8_t *dat, uint8_t len);
prt_sta_type tentiva_i2c_rd_cb (uint8_t slave, uint8_t *dat, uint8_t len);

// DP callback functions
void dp_sta_cb (prt_dp_ds_struct *dp);
void dptx_hpd_cb (prt_dp_ds_struct *dp);
void dprx_pwr_ctl_cb (prt_dp_ds_struct *dp);
void dptx_phy_rate_cb (prt_dp_ds_struct *dp);
void dprx_phy_rate_cb (prt_dp_ds_struct *dp);
void dptx_phy_vap_cb (prt_dp_ds_struct *dp);
void dprx_phy_rst_cb (prt_dp_ds_struct *dp);
void dp_trn_cb (prt_dp_ds_struct *dp);
void dp_lnk_cb (prt_dp_ds_struct *dp);
void dp_vid_cb (prt_dp_ds_struct *dp);
void dprx_msa_cb (prt_dp_ds_struct *dp);
void dp_debug_cb (prt_dp_ds_struct *dp);

// Task
void vtb_task (void);

