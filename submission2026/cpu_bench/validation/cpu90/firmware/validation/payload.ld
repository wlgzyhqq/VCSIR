OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY { RAM (rwx) : ORIGIN = 0x2000, LENGTH = 48K }
SECTIONS {
 .text : { KEEP(*(.text.init)) *(.text .text.*) } > RAM
 .rodata : { *(.rodata .rodata.*) } > RAM
 .data : { *(.data .data.*) . = ALIGN(4); } > RAM
 .bss (NOLOAD) : { __bss_start = .; *(.bss .bss.*) *(COMMON) . = ALIGN(4); __bss_end = .; } > RAM
 __stack = 0xfff0;
 __test_return = 0x100;
 ASSERT(__bss_end < 0xe000,"payload overlaps stack region")
}
