OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY { RAM (rwx) : ORIGIN = 0, LENGTH = 64K }
SECTIONS {
 .text : { KEEP(*(.text.init)) *(.text .text.*) } > RAM
 .rodata : { *(.rodata .rodata.*) } > RAM
 .data : { *(.data .data.*) *(.sdata .sdata.*) . = ALIGN(4); __image_end = .; } > RAM
 .bss (NOLOAD) : { __bss_start = .; *(.bss .bss.*) *(.sbss .sbss.*) *(COMMON) . = ALIGN(4); __bss_end = .; } > RAM
 __stack = 0xfff0;
 ASSERT(__bss_end < 0xe000,"Reserve 8KiB stack")
}
