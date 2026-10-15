/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: Zynq UltraScale+ Cortex-A53 start up (EL3)
    (c) 2026 by Parretto B.V.

    The debugger loads the application into the on-chip memory and starts Cortex-A53 #0 at _start,
    in EL3 (AArch64) after psu_init. There is no boot loader.
    The start up sets the stack and the exception vectors, enables the FP/SIMD unit, routes the
    interrupts to EL3, clears the bss, turns on the MMU and the caches and calls main.

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

    .section .text.prt_zu_start, "ax"
    .global _start
_start:
    // Interrupts masked until the GIC is set up
    msr     daifset, #0xf

    // Stack
    ldr     x0, =__stack_top
    mov     sp, x0

    // Exception vectors
    ldr     x0, =prt_zu_vec_tbl
    msr     vbar_el3, x0

    // FP/SIMD not trapped (the C library uses the SIMD registers)
    msr     cptr_el3, xzr

    // Secure state, IRQ, FIQ and external aborts are taken in EL3
    mov     x0, #((1 << 1) | (1 << 2) | (1 << 3))
    msr     scr_el3, x0
    isb

    // Clear bss
    ldr     x0, =__bss_start
    ldr     x1, =__bss_end
1:  cmp     x0, x1
    b.hs    2f
    str     xzr, [x0], #8
    b       1b
2:
    // MMU and caches (before any C library code: without the MMU all memory is device memory,
    // where unaligned accesses fault)
    bl      prt_zu_mmu_init

    bl      main

    // main does not return
3:  wfe
    b       3b
