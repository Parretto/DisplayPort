MEMORY
{
    ROM (x!rw)       : ORIGIN = 0x00000000, LENGTH = 0x040000 /* 256 KB */
    RAM (rw!x)       : ORIGIN = 0x10000000, LENGTH = 0x010000 /* 64 KB */
}

SECTIONS {
    .text :
    {
        . = ALIGN(4);
        *(.text)           /* .text sections (code) */
        *(.text*)          /* .text* sections (code) */
    } > ROM

    .data :
    {
        . = ALIGN(4);
        *(.sbss)
        *(.rodata*)
        *(.srodata*)
        *(.data)
        *(.sdata)
        *(.bss)
        *(.rela*)
    } > RAM

    /* this is to define the start of the heap, and make sure we have a minimum size */
    .heap :
    {
        . = ALIGN(4);
        _heap_start = .;    /* define a global symbol at heap start */
    } > RAM

    /* Stack Pointer - End of Memory */
    PROVIDE(__sp$ = ORIGIN(RAM) + LENGTH(RAM));
}
