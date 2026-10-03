.section .text.init
.global _start
_start:
 la sp,__stack
 li t0,0xa000
 li t1,7
 addi t2,t1,5
 add t3,t2,t1
 sub t4,t3,t2
 bne t4,t1,fail
 sw t3,0(t0)
 lw t4,0(t0)
 add t5,t4,t1
 li t6,26
 bne t5,t6,fail
 // Alternating outcomes train the predictor and require wrong-path recovery.
 li s0,100
 li s1,0
loop:
 andi t1,s0,1
 beqz t1,even
 addi s1,s1,1
 j next
even:
 addi s1,s1,2
next:
 addi s0,s0,-1
 bnez s0,loop
 li t1,150
 bne s1,t1,fail
 // A branch following a load miss must squash the younger MMIO store.
 li t0,0xc000
 li t1,1
 sw t1,0(t0)
 li t2,0x80001000
 lw t3,0(t0)
 bnez t3,skip
 sw t1,0(t2)
skip:
 lw t3,0(t2)
 bnez t3,fail
 // Variable latency call/return + immediate load-use.
 call function
 li t1,52
 bne a0,t1,fail
 li t0,0x80002018
 li t1,1
 sw t1,0(t0)
1:j 1b
function:
 addi sp,sp,-16
 sw ra,12(sp)
 sw t5,8(sp)
 lw a0,8(sp)
 add a0,a0,a0
 lw ra,12(sp)
 addi sp,sp,16
 ret
fail:
 li t0,0x80002018
 li t1,0xdead0200
 sw t1,0(t0)
2:j 2b
