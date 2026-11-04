OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY {
 CODE (rwx) : ORIGIN = 0x03c00000, LENGTH = 8K
 DATA (rw) : ORIGIN = 0x03c08000, LENGTH = 24K
}
SECTIONS {
 .text : { *(.text.init) *(.text .text.*) } > CODE
 .rodata : { *(.rodata .rodata.*) } > CODE
 .data : { *(.data .data.*) *(.sdata .sdata.*) } > CODE
 .bss (NOLOAD) : { __bss_start = .; *(.bss .bss.*) *(.sbss .sbss.*) *(COMMON) . = ALIGN(4); __bss_end = .; } > DATA
 __stack = 0x03c0ff00;
 ASSERT(__bss_end < 0x03c0e000, "Stage0 data overlaps stack")
 ASSERT(SIZEOF(.text)+SIZEOF(.rodata)+SIZEOF(.data) <= 8192, "Stage0 exceeds 8 KiB ROM budget")
}
