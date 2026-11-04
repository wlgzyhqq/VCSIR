.section .text.init
.global _start
_start:
 la sp,__stack
 csrw mscratch,zero
 li t0,0x80001000
 sw zero,0(t0)
 # Wrong-path faults, CSR changes and MMIO must never commit.
 li s0,128
1: li t1,0xa000
 li t2,1
 sw t2,0(t1)
 lw t3,0(t1)
 bnez t3,2f
 .word 0xffffffff
 li t4,0x90000000
 lw t5,0(t4)
 csrw mscratch,t2
 sw t2,0(t0)
2: lw t4,0(t0)
 bnez t4,fail
 csrr t4,mscratch
 bnez t4,fail
 # Immediate pseudo-rs2 matches a pending load's rd; no semantic operand.
 lw t5,0(t1)
 addi t6,zero,30
 li t4,30
 bne t6,t4,fail
 # Real load-use, consecutive writes, forwarding and x0.
 lw t5,0(t1)
 add t6,t5,t5
 addi t6,t6,8
 addi t6,t6,1
 li t4,11
 bne t6,t4,fail
 addi zero,t6,7
 bnez zero,fail
 addi s0,s0,-1
 bnez s0,1b
 # JALR must clear bit zero, and preserve link for return.
 la t0,subroutine
 ori t0,t0,1
 jalr ra,t0,0
 li t0,0x1234
 bne a0,t0,fail
 # Non-taken branch with misaligned target must not trap.
 .word 0x00001163
 li a0,1
 j __test_return
subroutine:li a0,0x1234;ret
fail:li a0,0xdead0701;j __test_return
