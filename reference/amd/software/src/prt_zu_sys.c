/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: Zynq UltraScale+ system calls of the C library
    (c) 2026 by Parretto B.V.

    stdout and stderr go to the UART, the heap is between the bss and the stack (see ocm.ld).
    The other system calls come from libnosys.
    Also prt_printf, the print function of the shared drivers.

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

#include <errno.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <sys/types.h>
#include "prt_uart.h"
#include "prt_printf.h"

extern char __heap_start[];
extern char __heap_end[];

int _write(int fd, const char *buf, int len) {
    (void)fd;
    for (int i = 0; i < len; i++) {
        if (buf[i] == '\n') {
            prt_uart_put_char('\r');
        }
        prt_uart_put_char((uint8_t)buf[i]);
    }
    return len;
}

void *_sbrk(ptrdiff_t incr) {
    static char *brk = __heap_start;
    char *prev = brk;

    if ((brk + incr) > __heap_end) {
        errno = ENOMEM;
        return (void *)-1;
    }

    brk += incr;
    return prev;
}

void prt_printf(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vprintf(fmt, args);
    va_end(args);
}
