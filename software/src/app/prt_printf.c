/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Printf implementation
    (c) 2021, 2022 by Parretto B.V.

    History
    =======
    v1.0 - Initial release

    License
    =======
    This License will apply to the use of the IP-core (as defined in the License). 
    Please read the License carefully so that you know what your rights and obligations are when using the IP-core.
    The acceptance of this License constitutes a valid and binding agreement between Parretto and you for the use of the IP-core. 
    If you download and/or make any use of the IP-core you agree to be bound by this License. 
    The License is available for download and print at www.parretto.com/license.html
    Parretto grants you, as the Licensee, a free, non-exclusive, non-transferable, limited right to use the IP-core 
    solely for internal business purposes for the term and conditions of the License. 
    You are also allowed to create Modifications for internal business purposes, but explicitly only under the conditions of art. 3.2.
    You are, however, obliged to pay the License Fees to Parretto for the use of the IP-core, or any Modification, in, or embodied in, 
    a physical or non-tangible product or service that has substantial commercial, industrial or non-consumer uses. 
*/

#include <stdarg.h>
#include "prt_types.h"
#include "prt_uart.h"
#include "prt_printf.h"

// Printf
void prt_printf (const char* fmt, ... )
{
	va_list args;
	va_start(args, fmt);
    const char *w;
    char c;

    /* Process format string. */
    w = fmt;
    while ((c = *w++) != 0)
    {
        /* If not a format escape character, just print  */
        /* character.  Otherwise, process format string. */
        if (c != '%')
        {
            prt_uart_putchar (c);
        }
        else
        {
            /* Get format character.  If none     */
            /* available, processing is complete. */
            if ((c = *w++) != 0)
            {
                if (c == '%')
                {
                    /* Process "%" escape sequence. */
                    prt_uart_putchar (c);
                } 

                // Character
                else if (c == 'c')
                {
                    prt_u32 v = va_arg(args, int);
                    prt_uart_putchar (v);
                }

                // HEX
                else if (c == 'x')
                {
                    /* Process hexadecimal number format. */
                    prt_u32 v = va_arg(args, int);
                    prt_u32 digit;
                    prt_u32 digit_shift;
                    prt_bool loop_exit = PRT_FALSE;

                    /* If the number value is zero, just print and continue. */
                    if (v == 0)
                    {
                        prt_uart_putchar ('0');
                        continue;
                    }

                    /* Find first non-zero digit. */
                    digit_shift = 28;
                    while (!(v & (0xF << digit_shift)))
                        digit_shift -= 4;

                    /* Print digits. */
                    do 
                    {
                        digit = (v & (0xF << digit_shift)) >> digit_shift;
                        if (digit <= 9)
                            c = '0' + digit;
                        else
                            c = 'a' + digit - 10;
                        prt_uart_putchar (c);

                        if (digit_shift == 0)
                            loop_exit = PRT_TRUE;
                        else
                           digit_shift -= 4; 

                    } while (loop_exit == PRT_FALSE);
                }

                // Decimal
                else if (c == 'd')
                {
                    /* Process decimal number format. */
                    unsigned long v = va_arg(args, int);
                    char s[12];
                    prt_u8 i = 0;
                    prt_printf_itoa (v, &s[0], 10);

                    while (s[i] != 0)
                      prt_uart_putchar (s[i++]);
                }

                // String
                else if (c == 's')
                {
                    /* Process string format. */
                    char *s = va_arg(args, char *);

                    while (*s)
                      prt_uart_putchar (*s++);
                }
            }
            else
            {
                break;
            }
        }
    }
}


// Implementation of itoa()
void prt_printf_itoa (int num, char *s, int base)
{
   static prt_u32 subtractors[] = {1000000000, 100000000, 10000000, 1000000, 100000, 10000, 1000, 100, 10, 1};
   char n; 
   prt_u32 *sub = subtractors;
   prt_u8  i = base; 
   
   while (i > 1 && num < *sub) {
       i--;
       sub++;
   }
   
   while (i--) {
       n = '0';
       while (num >= *sub) {
           num -= *sub;
           n++;
       }
       *s++ = n;
       sub++;
   }
   *s = 0;
}
