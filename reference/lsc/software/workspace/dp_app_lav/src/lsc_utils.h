#ifndef __LSC_UTILS__
#define __LSC_UTILS__

// Prototypes
void lsc_gpio_init (struct gpio_instance *this_gpio);
void lsc_gpio_set( struct gpio_instance *this_gpio, uint32_t value);
void lsc_gpio_clr (struct gpio_instance *this_gpio, uint32_t value);
uint32_t lsc_gpio_read (struct gpio_instance *this_gpio);

void lsc_delay (uint32_t ms);

void lsc_iob_init (void);
bool lsc_uart_get_char (struct uart_instance *uart, unsigned char *c);
static int lsc_uart_putc (char c, FILE *file);
static int lsc_uart_getc (FILE *file);
static int lsc_uart_flush (FILE *file);

#endif
