/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: UART Peripheral Driver
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

// Includes
#include "prt_types.h"
#include "prt_uart.h"
#include "prt_printf.h"

// Initialize
void prt_uart_init (prt_uart_ds_struct *uart, prt_u32 base)
{
	// Base address
	uart->dev = (prt_uart_dev_struct *) base;

	// Start device
	uart->dev->ctl = PRT_UART_CTL_RUN;	
}

// Put character
void prt_uart_putchar (prt_u8 dat)
{
	// Variables
	volatile prt_uart_ds_struct *p;

	// Get uart data structure from main
	p = &uart;

	// Block if the fifo is full
	while (p->dev->sta & PRT_UART_STA_TX_FL);

	// Put character into TX FIFO
	p->dev->tx = dat;	
}

// Peek 
// This function is non-blocking
// This function return true when there are any characters in the RX fifo
prt_bool prt_uart_peek (void)
{
	// Variables
	volatile prt_uart_ds_struct *p;

	// Get uart data structure from main
	p = &uart;

	// Check RX fifo
	if (p->dev->sta & PRT_UART_STA_RX_EP)
		return PRT_FALSE;
	else
		return PRT_TRUE;
}

// Get character
// This function is blocking
prt_u8 prt_uart_get_char (void)
{
	// Variables
	volatile prt_uart_ds_struct *p;

	// Get uart data structure from main
	p = &uart;

	// Block if the fifo is empty
	while (p->dev->sta & PRT_UART_STA_RX_EP);

	// Get character from RX FIFO
	return p->dev->rx;	
}

// Get 16 bits value
// This function is blocking
prt_u16 prt_uart_get_dec_val (void)
{
	// Variables
	volatile prt_uart_ds_struct *p;
	prt_u16 val;
	prt_u8 chr;
	prt_u8 dat;

	// Get uart data structure from main
	p = &uart;

	val = 0;
	// Maximum 5 digits
	for (prt_u8 i = 0; i < 5; i++)
	{
		// Block if the fifo is empty
		while (p->dev->sta & PRT_UART_STA_RX_EP);

		// Get character from RX FIFO
		chr = p->dev->rx;

		// Echo character
		prt_printf ("%c", chr);

		// End of input
		if (chr == 13)
			break;

		// Digits 0-9
		dat = chr - 48;

		if (i != 0)
			val = val * 10;
		val += dat;
	}

	return val;
}

// Get 16 bits value
// This function is blocking
prt_u16 prt_uart_get_hex_val (void)
{
	// Variables
	volatile prt_uart_ds_struct *p;
	prt_u16 val;
	prt_u8 chr;
	prt_u8 dat;

	// Get uart data structure from main
	p = &uart;

	val = 0;
	// Maximum 5 digits
	for (prt_u8 i = 0; i < 5; i++)
	{
		// Block if the fifo is empty
		while (p->dev->sta & PRT_UART_STA_RX_EP);

		// Get character from RX FIFO
		chr = p->dev->rx;

		// Echo character
		prt_printf ("%c", chr);

		// End of input
		if (chr == 13)
			break;

		// Digits a-f		
		else if (chr >= 97)
			dat = chr - 87;

		// Digits 0-9
		else
			dat = chr - 48;

		if (i != 0)
			val = val * 16;
		val += dat;
	}

	return val;
}


