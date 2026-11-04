.section .text.init
.global _start
_start:
 la sp,__stack
 csrw mie,zero
 csrci mstatus,8
 la t0,handler
 csrw mtvec,t0
 li s0,0
 li s1,0x80001000
 sw zero,0(s1)
 li t0,3
 sw t0,8(s1)
 li t0,30
1: addi t0,t0,-1
 bnez t0,1b
 li t0,-1
 sw t0,16(s1)
 li t0,1
 sw t0,12(s1)
 li t0,0x800
 csrw mie,t0
 csrsi mstatus,8
 # Output pad0 is observed through the actual FPGA I/O input synchronizers.
 li t0,1
 sw t0,0(s1)
2: beqz s0,2b
 csrci mstatus,8
 csrw mie,zero
 lw t0,4(s1)
 andi t0,t0,3
 li t1,1
 bne t0,t1,fail
 lw t0,16(s1)
 andi t0,t0,1
 bnez t0,fail
 sw zero,0(s1)
 sw zero,8(s1)
 li a0,1
 j __test_return
handler:
 addi sp,sp,-16
 sw t0,0(sp)
 sw t1,4(sp)
 csrr t0,mcause
 li t1,0x8000000b
 bne t0,t1,fail
 lw t0,16(s1)
 andi t0,t0,1
 beqz t0,fail
 sw t0,16(s1)
 sw zero,12(s1)
 addi s0,s0,1
 lw t0,0(sp)
 lw t1,4(sp)
 addi sp,sp,16
 mret
fail:li a0,0xdead0b01;j __test_return
