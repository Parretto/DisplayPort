//-----
// Lattice Utility Functions
//-----

// Includes
#include <stdbool.h>
#include <stdio.h>
#include "reg_access.h"
#include "gpio.h"
#include "gpio_regs.h"
#include "uart.h"
#include "iob.h"
#include "lsc_utils.h"

extern struct uart_instance uart;

//-----
// GPIO
//-----

// This function clears all PIO bits at start
void lsc_gpio_init (struct gpio_instance *this_gpio)
{
    reg_32b_write ( (this_gpio->base_address | GPIO_WR_DATA), 0);
}

// Lattice GPIO set
// This function sets a bit in the GPIO
void lsc_gpio_set (struct gpio_instance *this_gpio, uint32_t value)
{
    reg_32b_write ( (this_gpio->base_address | GPIO_SET_DATA), value);
}

// Lattice GPIO clear
// This function clears a bit in the GPIO
void lsc_gpio_clr (struct gpio_instance *this_gpio, uint32_t value)
{
    reg_32b_write ( (this_gpio->base_address | GPIO_CLEAR_DATA), value);
}

// Lattice GPIO read data
uint32_t lsc_gpio_read (struct gpio_instance *this_gpio)
{
	uint32_t value;

	reg_32b_read ((this_gpio->base_address | GPIO_RD_DATA), &value);
	return value;
}


//-----
// Delay
//-----

// Lattice delay
// This function waits about ms milliseconds in a busy loop
// (100 MHz CPU clock, about 12 clock cycles per loop).
void lsc_delay (uint32_t ms)
{
	volatile uint32_t cnt = ms * (100000 / 12);

	while (cnt--)
		continue;
}

//-----
// UART
//-----

// Register UART callbacks
void lsc_iob_init (void)
{
	iob_init (lsc_uart_putc, lsc_uart_getc, lsc_uart_flush);
}

// Lattice UART get character
// This function is non-blocking.
// It returns true when a character has been received.
bool lsc_uart_get_char (struct uart_instance *uart, unsigned char *c)
{
	char sta;
	sta = uart_getc (uart, c);

	if (sta == 0)
		return true;
	else
		return false;
}

// Lattice UART put character
static int lsc_uart_putc (char c, FILE *file)
{
          int ret = EOF;
          ret = uart_putc (&uart, c);
          if (c == '\n' && ret == 0)
               ret = uart_putc (&uart, '\r');
          return ret;
}

// Lattice UART get character
static int lsc_uart_getc (FILE *file)
{
     (void) file;
     return EOF;
}

// Lattice UART flush
static int lsc_uart_flush (FILE *file)
{
     (void) file;
     return 0;
}

