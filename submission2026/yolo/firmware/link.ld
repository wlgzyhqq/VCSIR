OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY {
 RAM (rwx) : ORIGIN = 0, LENGTH = 120K
 PRIVATE_DATA (rw) : ORIGIN = 0x00200000, LENGTH = 128K
}
SECTIONS {
 .text : { *(.text.init) *(.text .text.*) } > RAM
 .rodata : { *(.rodata .rodata.*) } > RAM
 .data : { *(.data .data.*) *(.sdata .sdata.*) } > RAM
 .bss ORIGIN(PRIVATE_DATA) (NOLOAD) : {
  __bss_start = .;
  *(.bss .bss.*) *(.sbss .sbss.*) *(COMMON)
  . = ALIGN(4); __bss_end = .;
 } > PRIVATE_DATA
 __stack = 0x1ff00;
 __bss_limit = ORIGIN(PRIVATE_DATA)+LENGTH(PRIVATE_DATA);
 ASSERT(__bss_end < __bss_limit, "Firmware BSS exceeds its private DDR region")
 ASSERT(SIZEOF(.text)+SIZEOF(.rodata)+SIZEOF(.data) < 0x1e000, "Firmware overlaps reserved stack area")
}
