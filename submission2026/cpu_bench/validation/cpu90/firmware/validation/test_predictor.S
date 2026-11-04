.section .text.init
.global _start
_start:
 la sp,__stack
 li s0,0x80004114
 # Warm exactly the same branch PCs before taking the measured interval.
 call workload
 lw s1,0(s0)
 call workload
 lw s2,0(s0)
 sub s2,s2,s1
 li t0,0xd900
 sw s2,0(t0)
 # 200 taken iterations should not cause 200 redirects with a trained BTB.
 li t1,30
 bgeu s2,t1,fail
 li a0,1
 j __test_return
workload:
 li t0,200
 li t1,0
1: addi t1,t1,1
 addi t0,t0,-1
 bnez t0,1b
 li t0,200
 bne t0,t1,fail
 ret
fail:li a0,0xdead0801;j __test_return
