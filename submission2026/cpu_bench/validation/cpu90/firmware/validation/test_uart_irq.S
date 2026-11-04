.section .text.init
.global _start
_start:
 la sp,__stack
 csrw mie,zero
 csrci mstatus,8
 la t0,handler
 csrw mtvec,t0
 li s0,0
 li s1,0x80000000
 li t0,0x800
 csrw mie,t0
 csrsi mstatus,8
1: beqz s0,1b
 csrci mstatus,8
 csrw mie,zero
 li t0,1
 bne s0,t0,fail
 li t0,0x5a
 bne t0,s2,fail
 lw t0,4(s1)
 andi t0,t0,6
 bnez t0,fail
 li a0,1
 j __test_return
handler:
 addi sp,sp,-16
 sw t0,0(sp)
 sw t1,4(sp)
 csrr t0,mcause
 li t1,0x8000000b
 bne t0,t1,fail
 lw t0,4(s1)
 andi t0,t0,6
 li t1,2
 bne t0,t1,fail
 lw s2,0(s1)
 addi s0,s0,1
 lw t0,0(sp)
 lw t1,4(sp)
 addi sp,sp,16
 mret
fail:li a0,0xdead0c01;j __test_return
