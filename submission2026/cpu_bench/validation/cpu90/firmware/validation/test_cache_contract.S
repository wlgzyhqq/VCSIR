.section .text.init
.global _start
_start:
 la sp,__stack
 li s0,0xa000
 li s1,0xc000
 li s2,0xe000
 li s3,0x80004100
 # Warm two dirty lines with the same set index, distinct tags.
 li t0,0x11223344
 sw t0,0(s0)
 li t0,0x55667788
 sw t0,0(s1)
 lw t0,0(s0)
 lw t0,0(s1)
 lw s4,28(s3)
 li t2,40
1: lw t0,0(s0)
 lw t1,0(s1)
 addi t2,t2,-1
 bnez t2,1b
 lw t0,28(s3)
 sub t0,t0,s4
 li t1,0xd800
 sw t0,0(t1)
 bnez t0,fail_d
 # Third same-set line must cause a dirty 8-beat writeback.
 lw s4,32(s3)
 li t0,0xabcdef01
 sw t0,0(s2)
 lw t0,0(s0)
 lw t0,0(s1)
 lw t0,0(s2)
 lw t0,32(s3)
 sub t0,t0,s4
 sw t0,4(t1)
 beqz t0,fail_evict
 # Byte enables and FENCE.I dirty data writeback to physical memory.
 li t0,0xaa
 sb t0,1(s0)
 li t0,0xbbcc
 sh t0,2(s0)
 fence.i
 li t0,0x4000a000
 lw t2,0(t0)
 li t0,0xbbccaa44
 bne t0,t2,fail_bytes
 # Two same-set instruction lines stay resident together.
 call function_a
 call function_b
 lw s4,24(s3)
 li s5,40
 li s6,0
2: call function_a
 add s6,s6,a0
 call function_b
 add s6,s6,a0
 addi s5,s5,-1
 bnez s5,2b
 lw t0,24(s3)
 sub t0,t0,s4
 li t1,0xd800
 sw t0,8(t1)
 bnez t0,fail_i
 li t0,120
 bne t0,s6,fail_i
 # A third same-set instruction line forces a refill.
 call function_c
 call function_a
 call function_b
 lw t0,24(s3)
 sub t0,t0,s4
 sw t0,12(t1)
 beqz t0,fail_evict
 li a0,1
 j __test_return
fail_d:li a0,0xdead0601;j __test_return
fail_evict:li a0,0xdead0602;j __test_return
fail_bytes:li a0,0xdead0603;j __test_return
fail_i:li a0,0xdead0604;j __test_return
.org 0x2000
function_a:li a0,1;ret
.org 0x4000
function_b:li a0,2;ret
.org 0x6000
function_c:li a0,3;ret
