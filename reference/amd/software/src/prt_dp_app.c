/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/

    DP application for the AMD Zynq UltraScale+ reference designs with the Tentiva FMC:
    the Enclustra Mercury+ XU6 (ZU4CG) on the Mercury+ ST1 and the AMD ZCU102 (ZU9EG)
    (c) 2026 by Parretto B.V.

    The application runs bare metal on Cortex-A53 #0 from the on-chip memory.
    The debugger loads it after psu_init (see reference/amd/README.md).

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

#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "prt_zu_irq.h"
#include "prt_zu_tmr.h"
#include "prt_log.h"
#include "prt_uart.h"

#include "prt_types.h"
#include "prt_dp_tokens.h"
#include "prt_dp_drv.h"
#include "prt_dptx_pm_rom.h"
#include "prt_dptx_pm_ram.h"
#include "prt_dprx_pm_rom.h"
#include "prt_dprx_pm_ram.h"
#include "prt_dp_edid.h"
#include "prt_vtb.h"
#include "prt_dp_fmt.h"
#include "prt_i2c.h"
#include "prt_tentiva.h"
#include "prt_phy_amd_gth.h"

#include "prt_dp_app.h"

// DPTX
static prt_dp_ds_struct dptx;
static char *dptx_lic = "0000000000000000";
static prt_dp_ds_struct dprx;
static char *dprx_lic = "0000000000000000";

// License key
// The DP IP-cores run one hour without a license key (eight hours with an eval license key).
// Enter the license key from Parretto (16 characters) in dptx_lic and dprx_lic.
static void dp_lic_set (const char *name, prt_dp_ds_struct *dp, char *lic)
{
    uint8_t sta = prt_dp_lic(dp, lic);

    if (sta == PRT_DP_LIC_FULL)
        printf("%s: licensed to customer %u\n", name, prt_dp_lic_cust(dp));
    else if (sta == PRT_DP_LIC_EVAL)
        printf("%s: eval license of customer %u, the core stops after 8 hours\n", name, prt_dp_lic_cust(dp));
    else
        printf("%s: no license, the core stops after 1 hour\n", name);
}

// VTB
static prt_vtb_ds_struct vtb;

// I2C
static prt_i2c_ds_struct i2c;

// Tentiva
static prt_tentiva_ds_struct tentiva;

// PHY
static prt_phy_amd_gth_ds_struct phy;

// Application
static dp_app_struct dp_app;

/*
    Helpers
*/

// DPTX reset
static void dptx_rst(void) {
    REG(PIO_OUT_BASE) |= PIO_OUT_DPTX_RST;
    prt_zu_tmr_delay_ms(10);
    REG(PIO_OUT_BASE) &= ~PIO_OUT_DPTX_RST;
}

// DPRX reset
static void dprx_rst(void) {
    REG(PIO_OUT_BASE) |= PIO_OUT_DPRX_RST;
    prt_zu_tmr_delay_ms(10);
    REG(PIO_OUT_BASE) &= ~PIO_OUT_DPRX_RST;
}

// Prefix of the log messages
static const char *dp_name(prt_dp_ds_struct *dp) {
    return (dp->id == PRT_DPTX_ID) ? "DPTX" : "DPRX";
}

// Line rate of the PHY driver
static uint8_t phy_rate(uint8_t rate) {
    switch (rate) {
    case PRT_DP_PHY_LINERATE_2700: return PRT_PHY_AMD_GTH_LINERATE_2700;
    case PRT_DP_PHY_LINERATE_5400: return PRT_PHY_AMD_GTH_LINERATE_5400;
    case PRT_DP_PHY_LINERATE_8100: return PRT_PHY_AMD_GTH_LINERATE_8100;
    default: return PRT_PHY_AMD_GTH_LINERATE_1620;
    }
}


/*
    Tentiva I2C callbacks
    The console runs through the Tentiva, and characters get lost while the system controller
    handles an I2C transaction. So the console output is sent completely before each transaction.
*/

static void tentiva_i2c_prep(void) {
    fflush(stdout);
    prt_uart_drain();
}

static prt_sta_type tentiva_i2c_wr_cb(uint8_t slave, uint8_t *dat, uint8_t len) {
    tentiva_i2c_prep();
    i2c.slave = slave;
    i2c.len = (len > sizeof(i2c.dat)) ? sizeof(i2c.dat) : len;
    memcpy(i2c.dat, dat, i2c.len);
    i2c.no_stop = false;
    return prt_i2c_wr(&i2c);
}

static prt_sta_type tentiva_i2c_rd_cb(uint8_t slave, uint8_t *dat, uint8_t len) {
    prt_sta_type sta;

    tentiva_i2c_prep();
    i2c.slave = slave;
    i2c.len = (len > sizeof(i2c.dat)) ? sizeof(i2c.dat) : len;
    i2c.no_stop = false;
    sta = prt_i2c_rd(&i2c);
    memcpy(dat, i2c.dat, i2c.len);
    return sta;
}

/*
    DP callbacks
    The PHY callbacks run in the interrupt handler, the others in the event handler of the main loop.
    They print to the log buffer.
*/

// Status
static void dp_sta_cb(prt_dp_ds_struct *dp) {
    prt_dp_sta_struct sta = prt_dp_get_sta(dp);

    prt_log_sprintf(&dp_app.log, "%s:\thw: %d.%d | sw: %d.%d\n", dp_name(dp), sta.hw_ver_major, sta.hw_ver_minor, sta.sw_ver_major, sta.sw_ver_minor);
    prt_log_sprintf(&dp_app.log, "\tmst: %x\n", sta.mst);
    prt_log_sprintf(&dp_app.log, "\tpio: %x\n", sta.pio);
    prt_log_sprintf(&dp_app.log, "\thpd: %d\n", sta.hpd);
    prt_log_sprintf(&dp_app.log, "\tlnk_up: %d | lnk_act_lanes: %d | lnk_act_rate: %d\n", sta.lnk_up, sta.lnk_act_lanes, sta.lnk_act_rate);
    prt_log_sprintf(&dp_app.log, "\tvid_up: %d\n", sta.vid_up);
}

// HPD
static void dptx_hpd_cb(prt_dp_ds_struct *dp) {
    switch (prt_dp_hpd_get(dp)) {
    case PRT_DP_HPD_PLUG:
        prt_log_sprintf(&dp_app.log, "DPTX: HPD plug\n");
        // A new sink, read its EDID before the colorbar starts
        dp_app.tx.edid_rd = true;
        break;
    case PRT_DP_HPD_IRQ: prt_log_sprintf(&dp_app.log, "DPTX: HPD pulse\n"); break;
    default: prt_log_sprintf(&dp_app.log, "DPTX: HPD unplug\n"); break;
    }
}

// PHY TX rate
static void dptx_phy_rate_cb(prt_dp_ds_struct *dp) {
    uint8_t rate = prt_dp_get_lnk_rate(dp);

    if (prt_phy_amd_gth_tx_rate(&phy, phy_rate(rate)) != PRT_STA_OK) {
        prt_log_sprintf(&dp_app.log, "DPTX: PHY line rate %s failed\n", rate_str(rate));
    }

    // Send link request ok
    prt_dp_lnk_req_ok(dp);
}

// PHY RX rate
static void dprx_phy_rate_cb(prt_dp_ds_struct *dp) {
    uint8_t rate = prt_dp_get_lnk_rate(dp);

    if (prt_phy_amd_gth_rx_rate(&phy, phy_rate(rate)) != PRT_STA_OK) {
        prt_log_sprintf(&dp_app.log, "DPRX: PHY line rate %s failed\n", rate_str(rate));
    }

    // Send link request ok
    prt_dp_lnk_req_ok(dp);
}

// PHY RX reset
// At the start of the clock recovery (TPS1) the datapath of the active lanes is reset.
static void dprx_phy_rst_cb(prt_dp_ds_struct *dp) {
    if (prt_dprx_get_trn_tps(dp) == 1) {
        prt_phy_amd_gth_rx_dp_rst(&phy, prt_dp_get_lnk_lanes(dp));
    }

    prt_dprx_phy_rst_ack(dp);
}

// PHY TX voltage swing and pre-emphasis
static void dptx_phy_vap_cb(prt_dp_ds_struct *dp) {
    prt_phy_amd_gth_tx_vap(&phy, prt_dp_get_lnk_volt(dp), prt_dp_get_lnk_pre(dp));
    prt_dp_lnk_req_ok(dp);
}

// Training
static void dp_trn_cb(prt_dp_ds_struct *dp) {
    bool pass = prt_dp_is_trn_pass(dp);

    prt_log_sprintf(&dp_app.log, "%s: Training %s\n", dp_name(dp), (pass) ? "passed" : "failed");
    prt_log_sprintf(&dp_app.log, "\tRate: %s | Lanes: %d\n", rate_str(prt_dp_get_lnk_rate(dp)), prt_dp_get_lnk_lanes(dp));

    if (pass) {
        prt_log_sprintf(&dp_app.log, "\tVoltage swing level: %d | Pre-emphasis level: %d\n", prt_dp_get_lnk_volt(dp), prt_dp_get_lnk_pre(dp));
    }
}

// Link
static void dp_lnk_cb(prt_dp_ds_struct *dp) {
    if (prt_dp_is_lnk_up(dp)) {
        prt_log_sprintf(&dp_app.log, "%s: Link up\n", dp_name(dp));

        // After the link is up the colorbar is started
        if (dp->id == PRT_DPTX_ID) {
            dp_app.tx.colorbar = true;
        }
        return;
    }

    prt_log_sprintf(&dp_app.log, "%s: Link down | ", dp_name(dp));
    switch (prt_dp_get_lnk_reason(dp)) {
    case PRT_DP_LNK_DOWN_PHY: prt_log_sprintf(&dp_app.log, "PHY error\n"); break;
    case PRT_DP_LNK_DOWN_CLK: prt_log_sprintf(&dp_app.log, "Link no clock\n"); break;
    case PRT_DP_LNK_DOWN_CDR: prt_log_sprintf(&dp_app.log, "CDR loss of lock\n"); break;
    case PRT_DP_LNK_DOWN_SCRM: prt_log_sprintf(&dp_app.log, "Scrambler loss of lock\n"); break;
    case PRT_DP_LNK_DOWN_TRN: prt_log_sprintf(&dp_app.log, "Training error\n"); break;
    case PRT_DP_LNK_DOWN_VID: prt_log_sprintf(&dp_app.log, "Video error\n"); break;
    case PRT_DP_LNK_DOWN_HPD: prt_log_sprintf(&dp_app.log, "hpd\n"); break;
    case PRT_DP_LNK_DOWN_IDLE: prt_log_sprintf(&dp_app.log, "Idle\n"); break;
    case PRT_DP_LNK_DOWN_TO: prt_log_sprintf(&dp_app.log, "Time out (eval expired)\n"); break;
    default: prt_log_sprintf(&dp_app.log, "Unknown\n"); break;
    }
}

// Video
static void dp_vid_cb(prt_dp_ds_struct *dp) {
    if (prt_dp_is_vid_up(dp, 0)) {
        prt_log_sprintf(&dp_app.log, "%s: Video stream 0 up\n", dp_name(dp));
    } else {
        prt_log_sprintf(&dp_app.log, "%s: Video stream 0 down\n", dp_name(dp));

        // When the RX video of the pass-through is down start the TX colorbar.
        // Without a pass-through the colorbar is still running.
        if ((dp->id == PRT_DPRX_ID) && dp_app.rx.cr) {
            dp_app.tx.colorbar = true;
        }
    }
}

// Colorspace name
static const char *csf_name(prt_dp_csf_type csf) {
    switch (csf) {
        case PRT_DP_CSF_RGB:      return "RGB";
        case PRT_DP_CSF_YCBCR444: return "YCbCr 444";
        case PRT_DP_CSF_YCBCR422: return "YCbCr 422";
        case PRT_DP_CSF_YCBCR420: return "YCbCr 420";
        default:                  return "Unknown";
    }
}

// DPRX MSA
static void dprx_msa_cb(prt_dp_ds_struct *dp) {
    prt_dp_tp_struct tp = prt_dprx_tp_get(dp);

    // The policy maker also reports a change of the colour parameters alone (VSC), which may
    // come before the first MSA. Without a timing there is nothing to show yet.
    if ((tp.htotal == 0) || (tp.vtotal == 0)) {
        return;
    }

    prt_log_sprintf(&dp_app.log, "DPRX: MSA\n");
    prt_log_sprintf(&dp_app.log, "\tMvid : %d | Nvid : %d\n", tp.mvid, tp.nvid);
    prt_log_sprintf(&dp_app.log, "\tHtotal : %d | Hstart : %d | Hwidth : %d | Hsw : %d | Hsp : %d\n", tp.htotal, tp.hstart, tp.hwidth, tp.hsw & 0x7fff, (tp.hsw >> 15) & 1);
    prt_log_sprintf(&dp_app.log, "\tVtotal : %d | Vstart : %d | Vheight : %d | Vsw : %d | Vsp : %d\n", tp.vtotal, tp.vstart, tp.vheight, tp.vsw & 0x7fff, (tp.vsw >> 15) & 1);
    prt_log_sprintf(&dp_app.log, "\tBPC : %d | Colorspace : %s\n", tp.bpc, csf_name(tp.csf));

    // Start pass-through
    dp_app.rx.pass = true;
}

/*
    DPTX
*/

// DPTX interrupt handler
static void dptx_irq_handler(void *ctx) {
    prt_dp_irq_handler((prt_dp_ds_struct *)ctx);
}

static int32_t dptx_init(void) {
    if (!prt_dp_set_base(&dptx, DPTX_BASE)) {
        printf("DPTX: peripheral not found at base address (%x)!\n", (unsigned int)DPTX_BASE);
        return -1;
    }

    // The driver waits for responses that the interrupt handler receives,
    // so the interrupt is registered before the DPTX is started.
    if (prt_zu_irq_register(PRT_ZU_IRQ_PL(0), dptx_irq_handler, &dptx) != 0) {
        printf("DPTX: interrupt registering failed!\n");
        return -1;
    }

    dptx_rst();

    printf("Initialize DPTX ROM...");
    prt_dp_rom_init(&dptx, prt_dptx_pm_rom_len, &prt_dptx_pm_rom[0]);
    printf("done\n");

    printf("Initialize DPTX RAM...");
    prt_dp_ram_init(&dptx, prt_dptx_pm_ram_len, &prt_dptx_pm_ram[0]);
    printf("done\n");

    prt_dp_init(&dptx, PRT_DPTX_ID);

    prt_dp_set_cb(&dptx, PRT_DP_CB_HPD, &dptx_hpd_cb);
    prt_dp_set_cb(&dptx, PRT_DP_CB_STA, &dp_sta_cb);
    prt_dp_set_cb(&dptx, PRT_DP_CB_PHY_RATE, &dptx_phy_rate_cb);
    prt_dp_set_cb(&dptx, PRT_DP_CB_PHY_VAP, &dptx_phy_vap_cb);
    prt_dp_set_cb(&dptx, PRT_DP_CB_TRN, &dp_trn_cb);
    prt_dp_set_cb(&dptx, PRT_DP_CB_LNK, &dp_lnk_cb);

    dp_lic_set("DPTX", &dptx, dptx_lic);

    printf("DPTX: Ping...");
    printf((prt_dp_ping(&dptx)) ? "ok\n" : "error\n");

    printf("DPTX: Config...");
    prt_dp_set_lnk_max_rate(&dptx, PRT_DP_PHY_LINERATE_8100);
    prt_dp_set_lnk_max_lanes(&dptx, 4);
    printf((prt_dp_cfg(&dptx)) ? "ok\n" : "error\n");

    return 0;
}

/*
    DPRX
*/

// DPRX interrupt handler
static void dprx_irq_handler(void *ctx) {
    prt_dp_irq_handler((prt_dp_ds_struct *)ctx);
}

static int32_t dprx_init(void) {
    if (!prt_dp_set_base(&dprx, DPRX_BASE)) {
        printf("DPRX: peripheral not found at base address (%x)!\n", (unsigned int)DPRX_BASE);
        return -1;
    }

    if (prt_zu_irq_register(PRT_ZU_IRQ_PL(1), dprx_irq_handler, &dprx) != 0) {
        printf("DPRX: interrupt registering failed!\n");
        return -1;
    }

    dprx_rst();

    printf("Initialize DPRX ROM...");
    prt_dp_rom_init(&dprx, prt_dprx_pm_rom_len, &prt_dprx_pm_rom[0]);
    printf("done\n");

    printf("Initialize DPRX RAM...");
    prt_dp_ram_init(&dprx, prt_dprx_pm_ram_len, &prt_dprx_pm_ram[0]);
    printf("done\n");

    prt_dp_init(&dprx, PRT_DPRX_ID);

    prt_dp_set_cb(&dprx, PRT_DP_CB_STA, &dp_sta_cb);
    prt_dp_set_cb(&dprx, PRT_DP_CB_PHY_RST, &dprx_phy_rst_cb);
    prt_dp_set_cb(&dprx, PRT_DP_CB_PHY_RATE, &dprx_phy_rate_cb);
    prt_dp_set_cb(&dprx, PRT_DP_CB_TRN, &dp_trn_cb);
    prt_dp_set_cb(&dprx, PRT_DP_CB_LNK, &dp_lnk_cb);
    prt_dp_set_cb(&dprx, PRT_DP_CB_VID, &dp_vid_cb);
    prt_dp_set_cb(&dprx, PRT_DP_CB_MSA, &dprx_msa_cb);

    dp_lic_set("DPRX", &dprx, dprx_lic);

    printf("DPRX: Ping...");
    printf((prt_dp_ping(&dprx)) ? "ok\n" : "error\n");

    printf("DPRX: Config...");
    prt_dp_set_lnk_max_rate(&dprx, PRT_DP_PHY_LINERATE_8100);
    prt_dp_set_lnk_max_lanes(&dprx, 4);
    printf((prt_dp_cfg(&dprx)) ? "ok\n" : "error\n");

    printf("DPRX: Write EDID...");
    printf((prt_dprx_edid_wr(&dprx, sizeof(edid_dat), edid_dat)) ? "ok\n" : "error\n");

    printf("DPRX: HPD...");
    printf((prt_dprx_hpd(&dprx, 2)) ? "ok\n" : "error\n");

    return 0;
}

/*
    Tentiva
*/

static int32_t tentiva_init(void) {
    prt_sta_type sta;

#if defined(PRT_BOARD_ZU9EG_ZCU102)
    // FMC HPC0 on the I2C mux U135 channel 0, all channels of U34 off
    i2c.len = 1;
    i2c.no_stop = false;
    i2c.slave = ZCU102_I2C_MUX_U34;
    i2c.dat[0] = 0;
    sta = prt_i2c_wr(&i2c);
    i2c.slave = ZCU102_I2C_MUX_U135;
    i2c.dat[0] = 1U << 0;
    if ((prt_i2c_wr(&i2c) != PRT_STA_OK) || (sta != PRT_STA_OK))
        printf("FMC I2C mux: error\n");
#endif

    prt_tentiva_init(&tentiva, &tentiva_i2c_wr_cb, &tentiva_i2c_rd_cb);

    // Scan Tentiva
    prt_tentiva_scan(&tentiva);

    printf("Tentiva config... ");
    sta = prt_tentiva_cfg(&tentiva, false);
    printf((sta == PRT_STA_OK) ? "ok\n" : "error\n");

    // PHY reference clock
    // Set before the transceiver PLLs are reset by the first line rate.
    printf("PHY reference clock... ");
    sta = prt_tentiva_set_phy_freq(&tentiva, PHY_REFCLK_KHZ);
    printf((sta == PRT_STA_OK) ? "ok\n" : "error\n");

    return (sta == PRT_STA_OK) ? 0 : -1;
}

/*
    VTB
*/

static void vtb_init(void) {
    prt_vtb_set_base(&vtb, VTB_BASE);

    // Scroller
    prt_vtb_set_osd(&vtb, true, 0, 2);

    // Load colour register
    prt_vtb_set_osd_color(&vtb, 235, 235, 235);

    // A rainbow across the height of the text, travelling with the bounce
    prt_vtb_set_osd_mode(&vtb, PRT_VTB_OSD_MODE_BANDS);
}

// Read the EDID of the sink and keep what it offers for the colorbar
static void edid_read(void) {
    uint8_t dat[256];
    prt_dp_fmt_edid_struct *edid = &dp_app.tx.edid;

    printf("DPTX: Read EDID...");

    // Base block and the first extension
    if (!prt_dptx_edid_rd(&dptx, 0, sizeof(dat), dat) || !prt_dp_fmt_edid_parse(dat, sizeof(dat), edid)) {
        edid->valid = false;
        printf("error\n");
        return;
    }

    printf("ok\n");

    if (edid->dtd_cnt)
        printf("\tPreferred: %u x %up%u\n", edid->dtd[0].h, edid->dtd[0].v, edid->dtd[0].hz);

    printf("\tVIC:");
    for (uint8_t i = 0; i < edid->vic_cnt; i++)
        printf(" %u", edid->vic[i]);
    printf("\n");
}

static void vtb_status(void) {
    char clk_buf[16];

    printf("VTB: Status\n");
    printf("\tFIFO\n");
    printf("\t\tlock: %d\n", prt_vtb_get_fifo_lock(&vtb));
    printf("\t\tmax words: %d\n", prt_vtb_get_fifo_max_wrds(&vtb));
    printf("\t\tmin words: %d\n", prt_vtb_get_fifo_min_wrds(&vtb));
    printf("\t\tloss: %u\n", (unsigned int)prt_vtb_get_fifo_loss(&vtb));
    printf("\tMonitor: %x\n", (unsigned int)prt_vtb_get_mon(&vtb));
    printf("\tClock recovery\n");
    printf("\t\terror: %d / %d / %d (cur / min / max)\n", prt_vtb_get_cr_cur_err(&vtb), prt_vtb_get_cr_min_err(&vtb), prt_vtb_get_cr_max_err(&vtb));
    printf("\t\tsum: %d | co: %ld\n", prt_vtb_get_cr_sum(&vtb), (long)prt_vtb_get_cr_co(&vtb));
    printf("\tClock\n");
    printf("\t\tTX link clock frequency: %s MHz\n", clk_mhz((prt_vtb_get_tx_lnk_clk_freq(&vtb) + 500U) / 1000U, clk_buf));
    printf("\t\tRX link clock frequency: %s MHz\n", clk_mhz((prt_vtb_get_rx_lnk_clk_freq(&vtb) + 500U) / 1000U, clk_buf));
    printf("\t\tvideo clock frequency: %s MHz\n", clk_mhz((prt_vtb_get_vid_ref_freq(&vtb) + 500U) / 1000U, clk_buf));
}

// Set the video clock (kHz)
// The Tentiva generates the video clock. In the pass-through the clock recovery of the VTB
// steers its DCO (main loop).
static void vid_clk_set(uint32_t vid_clk) {
    char clk_buf[16];

    printf("Set video clock frequency: %s MHz...", clk_mhz(vid_clk, clk_buf));
    printf((prt_tentiva_set_vid_freq(&tentiva, vid_clk) == PRT_STA_OK) ? "ok\n" : "error\n");
}

// Colorbar
static prt_sta_type vtb_colorbar(bool force) {
    prt_vtb_tp_struct vtb_tp;
    prt_dp_tp_struct dp_tp;
    uint8_t vtb_preset;
    uint8_t bpc;
    prt_dp_csf_type csf;

    printf("\nStart colorbar\n");

    // The colorbar replaces the pass-through
    dp_app.rx.cr = false;

    // Check if DP sink is connected
    if (!prt_dp_is_hpd(&dptx)) {
        printf("No DP sink device is connected\n");
        return PRT_STA_FAIL;
    }

    if (!force) {
        uint8_t rate = prt_dp_get_lnk_rate(&dptx);
        uint8_t lanes = prt_dp_get_lnk_lanes(&dptx);

        // Video resolution
        // The formats this board generates, with what the sink and the link say about them
        printf("Select video resolution:\n");

        for (uint8_t i = 0; i < PRT_DP_FMT_CNT; i++) {
            if (prt_dp_fmt[i].pclk > DP_APP_PCLK_MAX)
                continue;

            printf(" %u - %-16s", i + 1, prt_dp_fmt[i].name);

            switch (prt_dp_fmt_sink(&dp_app.tx.edid, i)) {
            case PRT_DP_FMT_SINK_PREF: printf("  (sink: preferred)"); break;
            case PRT_DP_FMT_SINK_YES: printf("  (sink: yes)"); break;
            default: break;
            }

            if (!prt_dp_fmt_link(i, rate, lanes, 8))
                printf("  (link: no)");

            printf("\n");
        }

        printf(" other key - %s\n", prt_dp_fmt[dp_app.tx.fmt].name);

        char c = prt_uart_get_key();

        if ((c >= '1') && (c < ('1' + PRT_DP_FMT_CNT)) && (prt_dp_fmt[c - '1'].pclk <= DP_APP_PCLK_MAX))
            dp_app.tx.fmt = c - '1';

        vtb_preset = prt_dp_fmt[dp_app.tx.fmt].preset;

        // 10 bpc only when the link carries it, and only with 4 lanes (the DPTX does not map 10 bpc to 1 and 2 lanes yet)
        if ((lanes < 4) || !prt_dp_fmt_link(dp_app.tx.fmt, rate, lanes, 10)) {
            bpc = 8;
        } else {
            printf("Select color depth:\n");
            printf(" 1 - 8 bpc\n");
            printf(" 2 - 10 bpc\n");
            bpc = (prt_uart_get_key() == '2') ? 10 : 8;
        }

        printf("Select color space:\n");
        printf(" 1 - RGB\n");
        printf(" 2 - YCbCr 4:4:4\n");
        csf = (prt_uart_get_key() == '2') ? PRT_DP_CSF_YCBCR444 : PRT_DP_CSF_RGB;
    }

    // Force colorbar in the format of the sink
    else {
        dp_app.tx.fmt = prt_dp_fmt_pick(&dp_app.tx.edid, prt_dp_get_lnk_rate(&dptx), prt_dp_get_lnk_lanes(&dptx),
                                        DP_APP_PCLK_MAX, prt_dp_fmt_find(VTB_PRESET_1920X1080P60));
        vtb_preset = prt_dp_fmt[dp_app.tx.fmt].preset;
        bpc = 8;
        printf("Format: %s\n", prt_dp_fmt[dp_app.tx.fmt].name);
        csf = PRT_DP_CSF_RGB;
    }

    // If the video is already running, then stop the video
    // (before the test pattern, the video clock and the MSA change)
    if (prt_dp_is_vid_up(&dptx, 0)) {
        printf("DPTX: Stop video...");
        if (prt_dptx_vid_stp(&dptx, 0)) {
            printf("ok\n");
        } else {
            printf("error\n");
            return PRT_STA_FAIL;
        }
    }

    // Start test pattern
    printf("VTB: Start test pattern\n");
    prt_vtb_set_csf(&vtb, csf);
    prt_vtb_tpg(&vtb, NULL, vtb_preset, VTB_TPG_FMT_FULL);

    // Get video timing parameters
    vtb_tp = prt_vtb_get_tp(&vtb);

    // Put what goes out on the wire into the scroller
    prt_vtb_osd_text(&vtb, NULL, vtb_tp.hwidth, vtb_tp.vheight,
                     prt_vtb_osd_hz(vtb_tp.pclk, vtb_tp.htotal, vtb_tp.vtotal), csf, bpc,
                     prt_dp_get_lnk_lanes(&dptx), prt_dp_get_lnk_rate(&dptx));

    // Video clock (pixel clock / 4)
    vid_clk_set(vtb_tp.pclk >> 2);

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
    dp_tp.bpc = bpc;
    printf("DPTX: Color depth: %d\n", dp_tp.bpc);

    // Set color space
    dp_tp.csf = csf;
    printf("DPTX: Color space: %s\n", (csf == PRT_DP_CSF_YCBCR444) ? "YCbCr 4:4:4" : "RGB");

    printf("DPTX: Set MSA...");
    printf((prt_dptx_msa_set(&dptx, &dp_tp, 0)) ? "ok\n" : "error\n");

    printf("DPTX: Start video...");
    if (prt_dptx_vid_str(&dptx, 0)) {
        printf("ok\n");
    } else {
        printf("error\n");
        return PRT_STA_FAIL;
    }

    return PRT_STA_OK;
}

// Pass-through
// The received video goes through the video toolbox to the DPTX. The VTB regenerates the timing
// from the MSA of the DPRX with the preset of the same totals.
static prt_sta_type vtb_pass(void) {
    prt_dp_tp_struct dp_tp;
    prt_vtb_tp_struct vtb_tp;
    uint32_t pclk;
    uint8_t vtb_preset;

    if (!prt_dp_is_hpd(&dptx)) {
        printf("No DP sink device is connected\n");
        return PRT_STA_FAIL;
    }

    if (!prt_dp_is_lnk_up(&dptx)) {
        printf("DPTX link is not up\n");
        return PRT_STA_FAIL;
    }

    if (!prt_dp_is_lnk_up(&dprx)) {
        printf("DPRX link is not up\n");
        return PRT_STA_FAIL;
    }

    printf("\nStart pass-through\n");

    // Get DPRX timing parameters
    dp_tp = prt_dprx_tp_get(&dprx);

    // The scroller follows the color space of the received video
    prt_vtb_set_csf(&vtb, dp_tp.csf);

    // Find preset
    vtb_preset = prt_vtb_find_preset(dp_tp.htotal, dp_tp.vtotal, &pclk);

    if (vtb_preset == 0) {
        printf("VTB: video preset not supported\n");
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
    prt_vtb_osd_text(&vtb, "PASS-THROUGH", dp_tp.hwidth, dp_tp.vheight,
                     prt_vtb_osd_hz(pclk, dp_tp.htotal, dp_tp.vtotal), dp_tp.csf, dp_tp.bpc,
                     prt_dp_get_lnk_lanes(&dptx), prt_dp_get_lnk_rate(&dptx));

    // If the video is already running, then stop the video
    if (prt_dp_is_vid_up(&dptx, 0)) {
        printf("DPTX: Stop video...");
        if (prt_dptx_vid_stp(&dptx, 0)) {
            printf("ok\n");
        } else {
            printf("error\n");
            return PRT_STA_FAIL;
        }
    }

    // Video clock (pixel clock / 4)
    vid_clk_set(pclk >> 2);

    // Clock recovery
    printf("VTB: start clock recovery\n");
    prt_vtb_cr_set_p_gain(&vtb, DP_APP_CR_P_GAIN);
    prt_vtb_cr_set_i_gain(&vtb, DP_APP_CR_I_GAIN);
    prt_vtb_cr(&vtb, &vtb_tp, vtb_preset);
    dp_app.rx.cr = true;

    printf("DPTX: Set MSA...");
    printf((prt_dptx_msa_set(&dptx, &dp_tp, 0)) ? "ok\n" : "error\n");

    printf("DPTX: Start video...");
    if (prt_dptx_vid_str(&dptx, 0)) {
        printf("ok\n");
    } else {
        printf("error\n");
        return PRT_STA_FAIL;
    }

    return PRT_STA_OK;
}


static void show_menu(void) {
    printf("\nCommands\n");
    printf("--------\n");

    printf("\n__DPTX__\n");
    printf("q - Ping\n");
    printf("e - Status\n");

    printf("\n__DPRX__\n");
    printf("a - Ping\n");
    printf("d - Status\n");
    printf("f - HPD pulse\n");

    printf("\n__VTB__\n");
    printf("l - Status\n");


    printf("\n__Operation__\n");
    printf("z - Colorbar\n");
    printf("x - Pass-through\n");
    printf("\n");
}

int main(void) {
    prt_zu_tmr_init();
    prt_uart_init();

    // Colorbar format until the sink's EDID is read
    dp_app.tx.fmt = prt_dp_fmt_find(VTB_PRESET_1920X1080P60);

    // Print header
    printf("\n\n");
    printf("    __        __   __   ___ ___ ___  __  \n");
    printf("   |__)  /\\  |__) |__) |__   |   |  /  \\ \n");
    printf("   |    /~~\\ |  \\ |  \\ |___  |   |  \\__/ \n");
    printf("\n");
    printf("DisplayPort reference design v2.0.1\n");
    printf("(c) 2021 - 2026 by Parretto B.V.\n");
    printf("www.parretto.com\n");
    printf("Board: %s\n", DP_APP_BOARD);
    printf("Date: '%s'\n", __DATE__);
    printf("Time: '%s'\n", __TIME__);
    printf("\n");

    // Interrupts
    if (prt_zu_irq_init() != 0) {
        printf("Interrupt initialization failed\n");
        while (1) {
        }
    }

    // I2C and Tentiva
    prt_i2c_init(&i2c, I2C_BASE, I2C_BEAT);
    tentiva_init();

    // PHY
    prt_phy_amd_gth_init(&phy, PHY_BASE);

    // The transceiver PLLs were reset at power up, before the Tentiva had the reference clock.
    // Start both directions at HBR.
    printf("PHY TX HBR...");
    printf((prt_phy_amd_gth_tx_rate(&phy, PRT_PHY_AMD_GTH_LINERATE_2700) == PRT_STA_OK) ? "ok\n" : "error\n");
    printf("PHY RX HBR...");
    printf((prt_phy_amd_gth_rx_rate(&phy, PRT_PHY_AMD_GTH_LINERATE_2700) == PRT_STA_OK) ? "ok\n" : "error\n");

    // VTB
    vtb_init();

    // DPTX
    if (dptx_init() != 0) {
        while (1) {
        }
    }

    // DPRX
    if (dprx_init() != 0) {
        while (1) {
        }
    }

    show_menu();

    uint64_t dco_tmr = 0;
    uint32_t dco = 0;

    while (1) {
        // DP events
        prt_dp_evt_handler(&dptx);
        prt_dp_evt_handler(&dprx);

        // Print the log of the DP callbacks
        prt_log_print(&dp_app.log);

        // Colorbar event
        if (dp_app.tx.colorbar) {
            dp_app.tx.colorbar = false;

            // Read the EDID of a new sink
            if (dp_app.tx.edid_rd) {
                dp_app.tx.edid_rd = false;
                edid_read();
            }

            // Start colorbar in the format of the sink
            vtb_colorbar(true);
        }

        // Pass-through event
        if (dp_app.rx.pass) {
            dp_app.rx.pass = false;
            vtb_pass();
        }

        // Video clock recovery
        // The output of the VTB clock recovery steers the DCO of the Tentiva video clock.
        // Every update is an I2C transaction with the system controller, so only a changed
        // value is written, at most every DP_APP_DCO_PERIOD_US.
        if (dp_app.rx.cr && (prt_zu_tmr_us() >= dco_tmr)) {
            uint32_t co = (uint32_t)prt_vtb_get_cr_co(&vtb);
            dco_tmr = prt_zu_tmr_us() + DP_APP_DCO_PERIOD_US;
            if (co != dco) {
                dco = co;
                if (prt_tentiva_sc_dco(&tentiva, co) != PRT_STA_OK) {
                    printf("Tentiva: DCO error\n");
                    dp_app.rx.cr = false;
                }
            }
        }

        int c = (prt_uart_peek()) ? prt_uart_get_char() : -1;

        // Ignore line endings and control characters
        if ((c < 0x20) || (c > 0x7e)) {
            c = -1;
        }

        switch (c) {
        case -1:
            break;

        // DPTX
        case 'q':
            printf("DPTX: Ping...");
            printf((prt_dp_ping(&dptx)) ? "ok\n" : "error\n");
            break;

        case 'e':
            printf("DPTX: Status\n");
            prt_dp_sta(&dptx);
            break;


        // DPRX
        case 'a':
            printf("DPRX: Ping...");
            printf((prt_dp_ping(&dprx)) ? "ok\n" : "error\n");
            break;

        case 'd':
            printf("DPRX: Status\n");
            prt_dp_sta(&dprx);
            break;

        case 'f':
            printf("DPRX: HPD pulse...");
            printf((prt_dprx_hpd(&dprx, 3)) ? "ok\n" : "error\n");
            break;

        // VTB
        case 'l':
            vtb_status();
            break;

        // Colorbar
        case 'z':
            vtb_colorbar(false);
            break;

        // Pass-through
        case 'x':
            vtb_pass();
            break;


        default:
            printf("Unknown command\n");
            show_menu();
            break;
        }
    }

    return 0;
}
