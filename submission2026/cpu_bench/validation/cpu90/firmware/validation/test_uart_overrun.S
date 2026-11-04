.section .text.init
.global _start
_start:
 la sp,__stack
 csrw mie,zero
 csrci mstatus,8
 li s0,0x80000000
 li t0,0x80002000
 lw t1,0(t0)
 # Hold RX unread for about 111 ms; host sends 256 bytes in about 22 ms.
 li t2,10000000
1: lw t3,0(t0)
 sub t3,t3,t1
 bltu t3,t2,1b
 lw t0,4(s0)
 li t1,0xdb00
 sw t0,0(t1)
 andi t0,t0,6
 li t2,6
 bne t0,t2,fail
 lw t0,0(s0)
 sw t0,4(t1)
 li t2,255
 bne t0,t2,fail
 lw t0,4(s0)
 andi t0,t0,6
 bnez t0,fail
 li a0,1
 j __test_return
fail:li a0,0xdead0d01;j __test_return
