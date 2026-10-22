OUTPUT_ARCH(riscv)
ENTRY(_start)

/* Match riscv-mini's PC_START and the 512 KiB elf2hex image. */
MEMORY {
    RAM (rwx) : ORIGIN = 0x200, LENGTH = 0x7fe00
}

SECTIONS {
    .text : {
        KEEP(*(.text.start))
        *(.text .text.*)
    } > RAM
    .rodata : { *(.rodata .rodata.*) } > RAM
    .data : { *(.data .data.* .sdata .sdata.*) } > RAM
    .bss (NOLOAD) : {
        . = ALIGN(4);
        __bss_start = .;
        *(.bss .bss.* .sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM
    __stack_top = ORIGIN(RAM) + LENGTH(RAM);
    ASSERT(__bss_end <= __stack_top - 0x1000, "Insufficient stack space")
}
