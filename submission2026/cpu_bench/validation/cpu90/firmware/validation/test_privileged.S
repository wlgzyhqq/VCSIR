.section .text.init
.global _start
.macro EXPECT cause, value, instruction
 li s1,\cause
 li s4,\value
 la s2,9f
 la s3,8f
 li s6,0
8: \instruction
 j fail
9:
.endm
_start:
 li sp,0xfff0
 csrw mie,zero
 csrci mstatus,8
 la t0,v0
 csrw mtvec,t0
 li s0,0
 li s7,0
 li t4,0x5a5a55a5
 li t5,0x80012345
 EXPECT 11,0,ecall
 EXPECT 3,0,ebreak
 li s1,2
 la s2,after_bad
 la s3,bad
 lw s4,0(s3)
bad: .word 0xffffffff
 j fail
after_bad:
 li s1,2
 la s2,after_csr
 la s3,bad_csr
 lw s4,0(s3)
bad_csr: csrr t0,0x777
 j fail
after_csr:
 li s1,2
 la s2,after_ro
 la s3,bad_ro
 lw s4,0(s3)
bad_ro: csrw cycle,zero
 j fail
after_ro:
 li t0,0xa001
 EXPECT 4,0xa001,"lh t1,0(t0)"
 EXPECT 4,0xa001,"lw t1,0(t0)"
 EXPECT 6,0xa001,"sh t1,0(t0)"
 EXPECT 6,0xa001,"sw t1,0(t0)"
 li t0,0xa002
 EXPECT 4,0xa002,"lw t1,0(t0)"
 EXPECT 6,0xa002,"sw t1,0(t0)"
 li t0,0xa003
 EXPECT 4,0xa003,"lw t1,0(t0)"
 EXPECT 6,0xa003,"sw t1,0(t0)"
 li t0,0x90000000
 EXPECT 5,0x90000000,"lw t1,0(t0)"
 EXPECT 7,0x90000000,"sw t1,0(t0)"
 # The faulting branch PC is mepc, while its bad target is mtval.
 li s1,0
 la s2,after_bad_jump
 la s3,bad_jump
 li s4,2
bad_jump: jal zero,2
 j fail
after_bad_jump:
 li s1,1
 la s2,after_fetch
 li s3,0x90000000
 li s4,0x90000000
 li t0,0x90000000
 jalr zero,0(t0)
 j fail
after_fetch:
 li t0,17
 bne s0,t0,fail
 # CSR operations and read-only zero-source reads.
 li t0,0x55
 csrrw t1,mscratch,t0
 csrrs t1,mscratch,zero
 bne t0,t1,fail
 li t0,0x80
 csrrs t1,mscratch,t0
 csrrc t1,mscratch,t0
 csrrwi t1,mscratch,3
 csrrsi t1,mscratch,4
 csrrci t1,mscratch,1
 csrr t1,mscratch
 li t0,6
 bne t0,t1,fail
 csrr t0,cycle
 csrr t0,instret
 # Global enable with a masked source must not take an interrupt.
 li s3,0
 li s4,0
 li s1,0x80000003
 li s6,0
 csrw mie,zero
 csrsi mstatus,8
 li t0,0x80002010
 li t1,1
 sw t1,0(t0)
 li t2,100
1: addi t2,t2,-1
 bnez t2,1b
 li t0,17
 bne s0,t0,fail
 csrr t0,mip
 andi t0,t0,8
 beqz t0,fail
 li t0,8
 csrw mie,t0
2: li t0,18
 bltu s0,t0,2b
 csrci mstatus,8
 # Vectored timer interrupt must enter slot7, not the base slot.
 la t0,vectors
 ori t0,t0,1
 csrw mtvec,t0
 li s1,0x80000007
 li s6,7
 li t0,128
 csrw mie,t0
 li t0,0x80002000
 lw t1,0(t0)
 li t2,5000
 add t1,t1,t2
 sw t1,8(t0)
 sw zero,12(t0)
 csrsi mstatus,8
3: li t0,19
 bltu s0,t0,3b
 csrci mstatus,8
 # External vectored source11.
 li s1,0x8000000b
 li s6,11
 li t0,0x800
 csrw mie,t0
 li t0,0x80002014
 li t1,1
 sw t1,0(t0)
 csrsi mstatus,8
4: li t0,20
 bltu s0,t0,4b
 csrci mstatus,8
 # Simultaneous sources: external > software > timer.
 li s7,1
 li s1,0x8000000b
 li s6,11
 li t0,0x80002008
 sw zero,0(t0)
 sw zero,4(t0)
 li t0,0x80002010
 li t1,1
 sw t1,0(t0)
 sw t1,4(t0)
 li t0,0x888
 csrw mie,t0
 csrsi mstatus,8
5: li t0,23
 bltu s0,t0,5b
 csrci mstatus,8
 csrw mie,zero
 li t0,0x5a5a55a5
 bne t0,t4,fail
 li t0,0x80012345
 bne t0,t5,fail
 li a0,1
 j __test_return
.balign 256
vectors:
 j v0
 j v1
 j v2
 j v3
 j v4
 j v5
 j v6
 j v7
 j v8
 j v9
 j v10
 j v11
 j v12
 j v13
 j v14
 j v15
.macro ENTRY n
v\n:
 addi sp,sp,-32
 sw t0,0(sp)
 sw t1,4(sp)
 sw t2,8(sp)
 li t0,\n
 sw t0,12(sp)
 j handler
.endm
ENTRY 0
ENTRY 1
ENTRY 2
ENTRY 3
ENTRY 4
ENTRY 5
ENTRY 6
ENTRY 7
ENTRY 8
ENTRY 9
ENTRY 10
ENTRY 11
ENTRY 12
ENTRY 13
ENTRY 14
ENTRY 15
handler:
 li t2,0xd000
 slli t1,s0,5
 add t2,t2,t1
 csrr t0,mcause
 sw t0,0(t2)
 csrr t0,mepc
 sw t0,4(t2)
 csrr t0,mtval
 sw t0,8(t2)
 csrr t0,mstatus
 sw t0,12(t2)
 csrr t0,mie
 sw t0,16(t2)
 csrr t0,mip
 sw t0,20(t2)
 lw t0,12(sp)
 sw t0,24(t2)
 sw sp,28(t2)
 bne t0,s6,fail
 csrr t0,mcause
 bne t0,s1,fail
 csrr t1,mstatus
 andi t1,t1,8
 bnez t1,fail
 csrr t1,mtval
 bne t1,s4,fail
 bltz t0,irq
 csrr t0,mepc
 bne t0,s3,fail
 csrw mepc,s2
 j complete
irq:
 csrr t1,mstatus
 andi t1,t1,128
 beqz t1,fail
 li t1,0x8000000b
 beq t0,t1,ext
 li t1,0x80000003
 beq t0,t1,soft
 li t1,0x80002008
 li t0,-1
 sw t0,0(t1)
 sw t0,4(t1)
 li s7,0
 j complete
ext:
 li t1,0x80002014
 sw zero,0(t1)
 beqz s7,complete
 li s1,0x80000003
 li s6,3
 j complete
soft:
 li t1,0x80002010
 sw zero,0(t1)
 beqz s7,complete
 li s1,0x80000007
 li s6,7
complete:
 addi s0,s0,1
 lw t0,0(sp)
 lw t1,4(sp)
 lw t2,8(sp)
 addi sp,sp,32
 mret
fail:
 li a0,0xdead0400
 or a0,a0,s0
 j __test_return
