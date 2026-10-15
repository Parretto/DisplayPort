/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: Log (Zynq UltraScale+)
    (c) 2026 by Parretto B.V.

    The DP callbacks run in the interrupt handler, they write to the log buffer.
    The main loop prints the log buffer with printf.

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

#define PRT_LOG_SIZE    4096U       // Buffer size

typedef struct {
    char buf[PRT_LOG_SIZE];         // Buffer
    volatile uint32_t head;             // Write index (interrupt handler)
    volatile uint32_t tail;             // Read index (main loop)
} prt_log_ds_struct;

// Format a message into the log. When the buffer is full the rest of the message is lost.
void prt_log_sprintf(prt_log_ds_struct *log, const char *fmt, ...);

// Print the log
void prt_log_print(prt_log_ds_struct *log);
