/*
     __        __   __   ___ ___ ___  __
    |__)  /\  |__) |__) |__   |   |  /  \
    |    /~~\ |  \ |  \ |___  |   |  \__/


    Module: Zynq UltraScale+ Cortex-A53 exception vectors (EL3)
    (c) 2026 by Parretto B.V.

    The application runs in EL3 with SP_EL3, so the "current EL with SPx" vectors are used.
    The interrupts are GIC-400 group 0 interrupts, signaled as IRQ (FIQEn is not set).
    The IRQ handler saves the caller saved registers (also the SIMD registers, the C code may use them)
    and calls prt_zu_irq_dispatch.

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

    .section .text.prt_zu_vec, "ax"

// Unexpected exception: stay here, so the debugger shows where it went wrong
.macro vec_hang
    .balign 0x80
1:  wfe
    b   1b
.endm

// IRQ
.macro vec_irq
    .balign 0x80
    b   prt_zu_irq
.endm

    .balign 0x800
    .global prt_zu_vec_tbl
prt_zu_vec_tbl:
    // Current EL with SP_EL0
    vec_hang                // Synchronous
    vec_hang                // IRQ
    vec_hang                // FIQ
    vec_hang                // SError

    // Current EL with SPx
    vec_hang                // Synchronous
    vec_irq                 // IRQ
    vec_hang                // FIQ
    vec_hang                // SError

    // Lower EL AArch64
    vec_hang
    vec_hang
    vec_hang
    vec_hang

    // Lower EL AArch32
    vec_hang
    vec_hang
    vec_hang
    vec_hang

// IRQ handler
prt_zu_irq:
    // General purpose registers (x0-x18, x29, x30)
    sub     sp, sp, #(22 * 8)
    stp     x0, x1, [sp, #(0 * 8)]
    stp     x2, x3, [sp, #(2 * 8)]
    stp     x4, x5, [sp, #(4 * 8)]
    stp     x6, x7, [sp, #(6 * 8)]
    stp     x8, x9, [sp, #(8 * 8)]
    stp     x10, x11, [sp, #(10 * 8)]
    stp     x12, x13, [sp, #(12 * 8)]
    stp     x14, x15, [sp, #(14 * 8)]
    stp     x16, x17, [sp, #(16 * 8)]
    stp     x18, x29, [sp, #(18 * 8)]
    str     x30, [sp, #(20 * 8)]

    // SIMD registers (q0-q7, q16-q31) and the FP status and control
    sub     sp, sp, #(24 * 16 + 16)
    stp     q0, q1, [sp, #(0 * 16)]
    stp     q2, q3, [sp, #(2 * 16)]
    stp     q4, q5, [sp, #(4 * 16)]
    stp     q6, q7, [sp, #(6 * 16)]
    stp     q16, q17, [sp, #(8 * 16)]
    stp     q18, q19, [sp, #(10 * 16)]
    stp     q20, q21, [sp, #(12 * 16)]
    stp     q22, q23, [sp, #(14 * 16)]
    stp     q24, q25, [sp, #(16 * 16)]
    stp     q26, q27, [sp, #(18 * 16)]
    stp     q28, q29, [sp, #(20 * 16)]
    stp     q30, q31, [sp, #(22 * 16)]
    mrs     x0, fpsr
    mrs     x1, fpcr
    stp     x0, x1, [sp, #(24 * 16)]

    bl      prt_zu_irq_dispatch

    ldp     x0, x1, [sp, #(24 * 16)]
    msr     fpsr, x0
    msr     fpcr, x1
    ldp     q0, q1, [sp, #(0 * 16)]
    ldp     q2, q3, [sp, #(2 * 16)]
    ldp     q4, q5, [sp, #(4 * 16)]
    ldp     q6, q7, [sp, #(6 * 16)]
    ldp     q16, q17, [sp, #(8 * 16)]
    ldp     q18, q19, [sp, #(10 * 16)]
    ldp     q20, q21, [sp, #(12 * 16)]
    ldp     q22, q23, [sp, #(14 * 16)]
    ldp     q24, q25, [sp, #(16 * 16)]
    ldp     q26, q27, [sp, #(18 * 16)]
    ldp     q28, q29, [sp, #(20 * 16)]
    ldp     q30, q31, [sp, #(22 * 16)]
    add     sp, sp, #(24 * 16 + 16)

    ldp     x0, x1, [sp, #(0 * 8)]
    ldp     x2, x3, [sp, #(2 * 8)]
    ldp     x4, x5, [sp, #(4 * 8)]
    ldp     x6, x7, [sp, #(6 * 8)]
    ldp     x8, x9, [sp, #(8 * 8)]
    ldp     x10, x11, [sp, #(10 * 8)]
    ldp     x12, x13, [sp, #(12 * 8)]
    ldp     x14, x15, [sp, #(14 * 8)]
    ldp     x16, x17, [sp, #(16 * 8)]
    ldp     x18, x29, [sp, #(18 * 8)]
    ldr     x30, [sp, #(20 * 8)]
    add     sp, sp, #(22 * 8)
    eret
