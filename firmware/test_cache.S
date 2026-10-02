.section .text.init
.global _start
_start:
 la sp,__stack
 // Line index = address[12:5]; addresses separated by 8192 share a set.
 li s0,0xa000
 li s1,0xc000
 li s2,0xe000
 li t0,0x11223344
 sw t0,0(s0)
 li t0,0x55667788
 sw t0,0(s1)
 li t0,0x7aabcdef
 sw t0,0(s2)
 // Third tag forces dirty replacement; refetch checks all three lines.
 lw t1,0(s0)
 li t0,0x11223344
 bne t0,t1,fail
 lw t1,0(s1)
 li t0,0x55667788
 bne t0,t1,fail
 lw t1,0(s2)
 li t0,0x7aabcdef
 bne t0,t1,fail
 li t0,0xaa
 sb t0,1(s0)
 li t0,0xbbcc
 sh t0,2(s0)
 lw t1,0(s0)
 li t0,0xbbccaa44
 bne t0,t1,fail
 // Three functions at the same I-cache set, distinct tags.
 li s3,20
 li s4,0
loop:
 call function_a
 add s4,s4,a0
 call function_b
 add s4,s4,a0
 call function_c
 add s4,s4,a0
 addi s3,s3,-1
 bnez s3,loop
 li t0,120
 bne s4,t0,fail
 fence iorw,iorw
 fence.i
 li t0,0x80002018
 li t1,1
 sw t1,0(t0)
1:j 1b
fail:
 li t0,0x80002018
 li t1,0xdead0100
 sw t1,0(t0)
2:j 2b
.org 0x2000
function_a:li a0,1;ret
.org 0x4000
function_b:li a0,2;ret
.org 0x6000
function_c:li a0,3;ret
