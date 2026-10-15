/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: UART (Zynq UltraScale+ PS UART0)
    (c) 2026 by Parretto B.V.

    The Cadence UART of the PS. psu_init only enables its clock and releases its reset,
    the application sets the baud rate and the frame format.
    The UART pins are routed over EMIO to the Tentiva.

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

// UART0
#define UART_BASE           0xFF000000UL
#define UART_CR             (*(volatile uint32_t *)(UART_BASE + 0x00UL))    // Control
#define UART_MR             (*(volatile uint32_t *)(UART_BASE + 0x04UL))    // Mode
#define UART_IDR            (*(volatile uint32_t *)(UART_BASE + 0x0CUL))    // Interrupt disable
#define UART_BAUDGEN        (*(volatile uint32_t *)(UART_BASE + 0x18UL))    // Baud rate generator
#define UART_SR             (*(volatile uint32_t *)(UART_BASE + 0x2CUL))    // Channel status
#define UART_FIFO           (*(volatile uint32_t *)(UART_BASE + 0x30UL))    // TX and RX FIFO
#define UART_BAUDDIV        (*(volatile uint32_t *)(UART_BASE + 0x34UL))    // Baud rate divider

#define UART_CR_RXRST       (1U << 0)
#define UART_CR_TXRST       (1U << 1)
#define UART_CR_RXEN        (1U << 2)
#define UART_CR_RXDIS       (1U << 3)
#define UART_CR_TXEN        (1U << 4)
#define UART_CR_TXDIS       (1U << 5)
#define UART_CR_STPBRK      (1U << 8)

#define UART_MR_8N1         (4U << 3)       // 8 data bits, no parity, 1 stop bit

#define UART_SR_RXEMPTY     (1U << 1)
#define UART_SR_TXEMPTY     (1U << 3)
#define UART_SR_TXFULL      (1U << 4)
#define UART_SR_TACTIVE     (1U << 11)

// 115200 baud from 100 MHz: 100 MHz / (124 * (6 + 1)) = 115207 baud
#define UART_CD             124U
#define UART_BDIV           6U

void prt_uart_init(void) {
    UART_CR = UART_CR_TXDIS | UART_CR_RXDIS;
    UART_IDR = 0x1fffU;
    UART_MR = UART_MR_8N1;
    UART_BAUDGEN = UART_CD;
    UART_BAUDDIV = UART_BDIV;
    UART_CR = UART_CR_TXRST | UART_CR_RXRST;
    while (UART_CR & (UART_CR_TXRST | UART_CR_RXRST)) {
    }
    UART_CR = UART_CR_TXEN | UART_CR_RXEN | UART_CR_STPBRK;
}

void prt_uart_put_char(uint8_t c) {
    while (UART_SR & UART_SR_TXFULL) {
    }
    UART_FIFO = c;
}

void prt_uart_drain(void) {
    while (!(UART_SR & UART_SR_TXEMPTY) || (UART_SR & UART_SR_TACTIVE)) {
    }
}

bool prt_uart_peek(void) {
    return (UART_SR & UART_SR_RXEMPTY) ? false : true;
}

uint8_t prt_uart_get_char(void) {
    while (!prt_uart_peek()) {
    }
    return (uint8_t)(UART_FIFO & 0xffU);
}

uint8_t prt_uart_get_key(void) {
    uint8_t c;
    do {
        c = prt_uart_get_char();
    } while ((c < 0x20) || (c > 0x7e));
    return c;
}
