.section .text.init
.global _start
_start:
 .option push
 .option norelax
 la sp, __stack
 .option pop
 csrw mie, zero
 csrw mstatus, zero
 la t0, trap
 csrw mtvec, t0
 la t0, __bss_start
 la t1, __bss_end
1: bgeu t0,t1,2f
 sw zero,0(t0)
 addi t0,t0,4
 j 1b
2: call main
3: j 3b
.balign 4
trap:
 lui t0,0x80001
 li t1,0xed00
 sw t1,0(t0)
 j trap
// Keep the commit and final loop in one instruction-cache line. The bus
// controller drains this store before asserting CPU/cache reset.
.balign 32
.global boot_handoff
boot_handoff:
 li t0,0x80002020
 li t1,0x54464231
 sw t1,0(t0)
4: j 4b
