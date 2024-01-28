/*
     __        __   __   ___ ___ ___  __  
    |__)  /\  |__) |__) |__   |   |  /  \ 
    |    /~~\ |  \ |  \ |___  |   |  \__/ 


    Module: DP Interrupt Driver
    (c) 2021 - 2023 by Parretto B.V.

    History
    =======
    v1.0 - Initial release
	v1.1 - Added interrupt handler define

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
#include "prt_dp_drv.h"
#include "prt_irq.h"

// Initialize
void prt_irq_init (void)
{
	// Variables 
	prt_u32 dat;

	// Set handler vector
	dat = (prt_u32)prt_irq_handler;

	asm volatile (
			"csrw mtvec, %0" 
			:					// Output register
			: "r" (dat) 			// Input register
		);

	// mstatus register
	// Enable interrupts (mie)
	dat = PRT_IRQ_MSTATUS_MIE;
	asm volatile (
			"csrw mstatus, %0" 
			:					// Output register
			: "r" (dat) 			// Input register
		);

	// mie register
	// Enable external interrupt (meie)
	dat = PRT_IRQ_MIE_MEIE;
	asm volatile (
		"csrw mie, %0" 
			:					// Output register
			: "r" (dat) 			// Input register
		);
}

// Interrupt Handler
void prt_irq_handler (void)
{
	// DPTX interrupt handler
	#ifdef PRT_IRQ_DPTX
		prt_dp_irq_handler (&dptx);
	#endif

	// DPRX interrupt handler
	#ifdef PRT_IRQ_DPRX
		prt_dp_irq_handler (&dprx);
	#endif
}

