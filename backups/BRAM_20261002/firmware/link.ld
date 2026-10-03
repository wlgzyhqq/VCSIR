OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY { RAM (rwx) : ORIGIN = 0, LENGTH = 64K }
SECTIONS {
 .text : { *(.text.init) *(.text .text.*) } > RAM
 .rodata : { *(.rodata .rodata.*) } > RAM
 .data : { *(.data .data.*) *(.sdata .sdata.*) } > RAM
 . = ALIGN(16); __bss_start = .;
 .bss (NOLOAD) : { *(.bss .bss.*) *(.sbss .sbss.*) *(COMMON) } > RAM
 __bss_end = .; __stack = 0xff00;
 ASSERT(__bss_end < 0xe000, "Firmware overlaps reserved test area/stack")
}
