/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: Zynq UltraScale+ interrupts header
    (c) 2026 by Parretto B.V.

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

#include <stdint.h>

// PL to PS interrupts (pl_ps_irq0[0] is GIC SPI 89, interrupt ID 121)
#define PRT_ZU_IRQ_PL(n)            (121U + (n))

typedef void (*prt_zu_irq_handler_t)(void *ctx);

// Initialize the GIC. The interrupts are enabled.
int32_t prt_zu_irq_init(void);

// Register a handler for a shared peripheral interrupt and enable it (level sensitive, routed to this core)
int32_t prt_zu_irq_register(uint32_t intid, prt_zu_irq_handler_t handler, void *ctx);

// Pending state of an interrupt (debug)
uint32_t prt_zu_irq_pending(uint32_t intid);
