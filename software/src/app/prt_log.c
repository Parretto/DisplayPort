/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: Log buffer. This is used to log the messages during an event

    (c) 2021 - 2023 by Parretto B.V.

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

// Includes
#include <stdint.h>
#include <stdbool.h>
#include <stdarg.h>
#include "prt_types.h"
#include "prt_uart.h"
#include "prt_printf.h"
#include "prt_log.h"

// Initialize
void prt_log_init (prt_log_ds_struct *log)
{
    log->head = 0;
    log->tail = 0;
}

// Head increment
void prt_log_head_inc (prt_log_ds_struct *log)
{
    if (log->head == 1023)
        log->head = 0;
    else
        log->head++;
}

// Tail increment
void prt_log_tail_inc (prt_log_ds_struct *log)
{
    if (log->tail == 1023)
        log->tail = 0;
    else
        log->tail++;
}

// Put
void prt_log_put (prt_log_ds_struct *log, char dat)
{   
    // Put character in buffer
    log->buf[log->head] = dat;
    
    // Increment head pointer
    prt_log_head_inc (log);
}

// Get
char prt_log_get (prt_log_ds_struct *log)
{
    char dat;

    // Get character in buffer
    dat = log->buf[log->tail];
    
    // Increment tail pointer
    prt_log_tail_inc (log);

    return dat;
}

// Empty
bool prt_log_empty (prt_log_ds_struct *log)
{
    if (log->head == log->tail) 
        return true;
    else
        return false;
}

// Print
void prt_log_print (prt_log_ds_struct *log)
{
    char dat;

    while (prt_log_empty (log) == false)
    {
        dat = prt_log_get (log);
        prt_uart_putchar (dat);
    }
}

// sprintf 
void prt_log_sprintf (prt_log_ds_struct *log, const char* fmt, ... )
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
            prt_log_put (log, c);
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
                    prt_log_put (log, c);
                } 

                // Character
                else if (c == 'c')
                {
                    uint32_t v = va_arg(args, int);
                    prt_log_put (log, v);
                }

                // HEX
                else if (c == 'x')
                {
                    /* Process hexadecimal number format. */
                    uint32_t v = va_arg(args, int);
                    uint32_t digit;
                    uint32_t digit_shift;
                    bool loop_exit = false;

                    /* If the number value is zero, just print and continue. */
                    if (v == 0)
                    {
                        prt_log_put (log, '0');
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
                        prt_log_put (log, c);

                        if (digit_shift == 0)
                            loop_exit = true;
                        else
                           digit_shift -= 4; 

                    } while (loop_exit == false);
                }

                // Decimal
                else if (c == 'd')
                {
                    /* Process decimal number format. */
                    unsigned long v = va_arg(args, int);
                    char s[12];
                    uint8_t i = 0;
                    prt_log_itoa (v, &s[0], 10);

                    while (s[i] != 0)
                      prt_log_put (log, s[i++]);
                }

                // String
                else if (c == 's')
                {
                    /* Process string format. */
                    char *s = va_arg(args, char *);

                    while (*s)
                      prt_log_put (log, *s++);
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
void prt_log_itoa (int num, char *s, int base)
{
   static uint32_t subtractors[] = {1000000000, 100000000, 10000000, 1000000, 100000, 10000, 1000, 100, 10, 1};
   char n; 
   uint32_t *sub = subtractors;
   uint8_t  i = base; 
   
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
