/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: UART header (Zynq UltraScale+ PS UART0)
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

#include <stdbool.h>
#include <stdint.h>

// Initialize the UART (115200 baud, 8N1). The reference clock is 100 MHz (see dp_soc_zu4cg.tcl).
void prt_uart_init(void);

// Send a character
void prt_uart_put_char(uint8_t c);

// Wait until all characters are sent
void prt_uart_drain(void);

// Is there a character?
bool prt_uart_peek(void);

// Wait for a character
uint8_t prt_uart_get_char(void);

// Wait for a key (a printable character, the line endings of the terminal are skipped)
uint8_t prt_uart_get_key(void);
