.section .text.init
.global _start, __test_return, monitor_trap_entry
_start:
 .option push
 .option norelax
 la sp,__stack
 .option pop
 la t0,__bss_start
 la t1,__bss_end
1: bgeu t0,t1,2f
 sw zero,0(t0)
 addi t0,t0,4
 j 1b
2: j monitor_boot
.org 0x100
__test_return:
 csrw mie,zero
 csrci mstatus,8
 li sp,0xfff0
 j monitor_done
.balign 4
monitor_trap_entry:
 csrr a0,mcause
 csrr a1,mepc
 csrr a2,mtval
 csrw mie,zero
 csrci mstatus,8
 li sp,0xfff0
 j monitor_trapped
