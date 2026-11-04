OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY { RAM (rwx) : ORIGIN = 0, LENGTH = 8K }
SECTIONS {
 .text : { KEEP(*(.text.init)) *(.text .text.*) } > RAM
 .rodata : { *(.rodata .rodata.*) } > RAM
 .data : { *(.data .data.*) . = ALIGN(4); } > RAM
 .bss (NOLOAD) : { __bss_start = .; *(.bss .bss.*) *(COMMON) . = ALIGN(4); __bss_end = .; } > RAM
 __stack = 0xfff0;
 ASSERT(__bss_end < 0x2000,"monitor overlaps payload")
}
