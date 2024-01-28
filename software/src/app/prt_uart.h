/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: UART Peripheral Header
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

#pragma once

// Device structure
typedef struct {
  prt_u32 ctl; 			 // Control
  prt_u32 sta; 			 // Status
  prt_u32 tx; 	 	   // Transmit
  prt_u32 rx;        // Receive
} prt_uart_dev_struct;

// Data structure
typedef struct {
  volatile prt_uart_dev_struct *dev;
} prt_uart_ds_struct;

// The uart data structure is defined at main
extern prt_uart_ds_struct uart;

// Defines
#define PRT_UART_CTL_RUN 	          (1<<0)

#define PRT_UART_STA_TX_EP          (1<<0)
#define PRT_UART_STA_TX_FL          (1<<1)
#define PRT_UART_STA_TX_WRDS_SHIFT  2
#define PRT_UART_STA_RX_EP          (1<<8)
#define PRT_UART_STA_RX_FL          (1<<9)
#define PRT_UART_STA_RX_WRDS_SHIFT  10

// Prototypes
void prt_uart_init (prt_uart_ds_struct *uart, prt_u32 base);
void prt_uart_putchar (prt_u8 dat);
prt_u8 prt_uart_get_char (void);
prt_u16 prt_uart_get_dec_val (void);
prt_u16 prt_uart_get_hex_val (void);
prt_bool prt_uart_peek (void);