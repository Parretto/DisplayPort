/*
    DP application linker script
    Zynq UltraScale+ Cortex-A53, on-chip memory (256 KB)
    (c) 2026 by Parretto B.V.
*/

ENTRY(_start)

STACK_SIZE = 16K;
HEAP_SIZE = 24K;

MEMORY
{
    OCM (rwx) : ORIGIN = 0xFFFC0000, LENGTH = 256K
}

SECTIONS
{
    .text : {
        KEEP(*(.text.prt_zu_start))
        *(.text.prt_zu_vec)
        *(.text .text.*)
    } > OCM

    .rodata : ALIGN(16) {
        *(.rodata .rodata.*)
    } > OCM

    .data : ALIGN(16) {
        *(.data .data.*)
        *(.sdata .sdata.*)
    } > OCM

    .init_array : ALIGN(8) {
        PROVIDE_HIDDEN(__init_array_start = .);
        KEEP(*(SORT(.init_array.*)))
        KEEP(*(.init_array))
        PROVIDE_HIDDEN(__init_array_end = .);
    } > OCM

    .bss (NOLOAD) : ALIGN(16) {
        __bss_start = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(16);
        __bss_end = .;
    } > OCM

    .heap (NOLOAD) : ALIGN(16) {
        __heap_start = .;
        . += HEAP_SIZE;
        __heap_end = .;
    } > OCM

    .stack (NOLOAD) : ALIGN(16) {
        . += STACK_SIZE;
        __stack_top = .;
    } > OCM

    /DISCARD/ : {
        *(.comment)
    }
}
