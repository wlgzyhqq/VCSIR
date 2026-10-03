.section .text.init
.global _start
.macro expect_sync cause, insn
 li t6,\cause
 la s1,9f
 la s2,8f
8: \insn
 j fail
9:
.endm
_start:
 la sp,__stack
 la t0,trap_handler
 csrw mtvec,t0
 li s0,0
 expect_sync 11, ecall
 expect_sync 3, ebreak
 li t6,2
 la s1,after_illegal
 la s2,illegal_pc
illegal_pc:.word 0xffffffff
 j fail
after_illegal:
 li t6,2
 la s1,after_csr
 la s2,unknown_csr_pc
unknown_csr_pc:csrr t0,0x777
 j fail
after_csr:
 li t6,2
 la s1,after_readonly
 la s2,readonly_pc
readonly_pc:csrw cycle,zero
 j fail
after_readonly:
 li t0,0xa001
 expect_sync 4, "lw t1,0(t0)"
 expect_sync 6, "sw t1,0(t0)"
 li t0,0x90000000
 expect_sync 5, "lw t1,0(t0)"
 expect_sync 7, "sw t1,0(t0)"
 li t6,0
 la s1,after_jump
 la s2,bad_jump
bad_jump: jal zero,2
 j fail
after_jump:
 // Instruction access fault at an unmapped target.
 li t6,1
 la s1,after_fetch_fault
 li s2,0x90000000
 li t0,0x90000000
 jalr zero,0(t0)
 j fail
after_fetch_fault:
 li t0,11
 bne s0,t0,fail
 // All six CSR operations, with read-after-write serialization.
 li t0,0x55
 csrrw t1,mscratch,t0
 csrrs t1,mscratch,zero
 bne t1,t0,fail
 li t2,0x80
 csrrs t1,mscratch,t2
 csrrc t1,mscratch,t2
 csrrwi t1,mscratch,3
 csrrsi t1,mscratch,4
 csrrci t1,mscratch,1
 csrr t1,mscratch
 li t0,6
 bne t1,t0,fail
 // Software interrupt, direct mode.
 li t6,0x80000003
 li s2,0
 li t0,8
 csrw mie,t0
 csrsi mstatus,8
 li t0,0x80002010
 li t1,1
 sw t1,0(t0)
1:li t0,12
 bltu s0,t0,1b
 csrci mstatus,8
 // Timer interrupt, vectored mode.
 la t0,trap_vectors
 ori t0,t0,1
 csrw mtvec,t0
 li t6,0x80000007
 li t0,128
 csrw mie,t0
 li t0,0x80002000
 lw t1,0(t0)
 addi t1,t1,1000
 sw t1,8(t0)
 sw zero,12(t0)
 csrsi mstatus,8
2:li t0,13
 bltu s0,t0,2b
 csrci mstatus,8
 // External interrupt via board peripheral test source, vectored mode.
 li t6,0x8000000b
 li t0,0x800
 csrw mie,t0
 li t0,0x80002014
 li t1,1
 sw t1,0(t0)
 csrsi mstatus,8
3:li t0,14
 bltu s0,t0,3b
 csrr t0,mstatus
 andi t0,t0,8
 beqz t0,fail
 csrci mstatus,8
 li t0,0x80002018
 li t1,1
 sw t1,0(t0)
4:j 4b
.balign 256
trap_vectors:
.rept 16
 j trap_handler
.endr
.balign 4
trap_handler:
 addi sp,sp,-16
 sw t0,0(sp)
 sw t1,4(sp)
 sw t2,8(sp)
 csrr t0,mcause
 bne t0,t6,fail
 csrr t1,mstatus
 andi t1,t1,8
 bnez t1,fail
 bltz t0,interrupt_handler
 csrr t0,mepc
 bne t0,s2,fail
 csrw mepc,s1
 j done
interrupt_handler:
 li t0,0x80002010
 sw zero,0(t0)
 sw zero,4(t0)
 li t0,0x80002008
 li t1,-1
 sw t1,0(t0)
 sw t1,4(t0)
done:
 addi s0,s0,1
 lw t0,0(sp)
 lw t1,4(sp)
 lw t2,8(sp)
 addi sp,sp,16
 mret
fail:
 li t0,0x80002018
 li t1,0xdead0300
 or t1,t1,s0
 sw t1,0(t0)
5:j 5b
