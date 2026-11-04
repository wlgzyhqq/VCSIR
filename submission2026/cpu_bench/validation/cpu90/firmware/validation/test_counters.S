.section .text.init
.global _start
_start:
 li sp,0xfff0
 li s7,0xd000
 # Drain older instructions using a serialized CSR access before sampling.
 # Otherwise an issue-stage counter read includes unrelated older retirements.
 csrr zero,instret
 # A dummy CSR read also drains the END boundary. Delta counts first read,
 # eight NOPs and the final dummy read (10 instructions).
 csrr s0,instret
 .rept 8
 nop
 .endr
 csrr zero,instret
 csrr s1,instret
 sub s2,s1,s0
 sw s2,0(s7)
 li t0,10
 bne s2,t0,fail1
 # FENCE.I is a retiring instruction, not an architectural trap.
 csrr zero,instret
 csrr s0,instret
 fence.i
 csrr zero,instret
 csrr s1,instret
 sub s2,s1,s0
 sw s2,4(s7)
 li t0,3
 bne s2,t0,fail2
 # MRET must also retire exactly once.
 la t0,after_mret
 csrw mepc,t0
 csrr zero,instret
 csrr s0,instret
 mret
after_mret:
 csrr zero,instret
 csrr s1,instret
 sub s2,s1,s0
 sw s2,8(s7)
 li t0,3
 bne s2,t0,fail3
 # Writable 64bit machine counter and read-only aliases must agree.
 li t0,7
 csrw mcycleh,t0
 li t0,-16
 csrw mcycle,t0
 .rept 64
 nop
 .endr
 csrr t1,mcycleh
 sw t1,12(s7)
 li t0,8
 bne t0,t1,fail4
 csrr t0,cycleh
 bne t0,t1,fail4
 li t0,7
 csrw minstreth,t0
 li t0,-16
 csrw minstret,t0
 .rept 64
 nop
 .endr
 csrr t1,minstreth
 sw t1,16(s7)
 li t0,8
 bne t0,t1,fail5
 csrr t0,instreth
 bne t0,t1,fail5
 li a0,1
 j __test_return
fail1:li a0,0xdead0501;j __test_return
fail2:li a0,0xdead0502;j __test_return
fail3:li a0,0xdead0503;j __test_return
fail4:li a0,0xdead0504;j __test_return
fail5:li a0,0xdead0505;j __test_return
