/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: UART receiver (Altera HPS)
    (c) 2026 by Parretto B.V.

    The receiver of the HPS UART0 is polled. Transmitting goes through printf of the Altera library.

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

#include "prt_uart.h"

bool prt_uart_peek(void) {
    return (PRT_UART_LSR & PRT_UART_LSR_DR) ? true : false;
}

uint8_t prt_uart_get_char(void) {
    while (!prt_uart_peek()) {
    }
    return (uint8_t)(PRT_UART_RBR & 0xffU);
}

uint8_t prt_uart_get_key(void) {
    uint8_t c;
    do {
        c = prt_uart_get_char();
    } while ((c < 0x20) || (c > 0x7e));
    return c;
}
