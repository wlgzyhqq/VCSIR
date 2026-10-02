// Platform adapter for the pinned upstream riscv-tests scalar macros.
#ifndef FINAL_RISCV_TEST_H
#define FINAL_RISCV_TEST_H
#define RVTEST_RV32U
#define RVTEST_RV64U
#define RVTEST_CODE_BEGIN .section .text.init; .global _start; _start: la sp,__stack;
#define RVTEST_CODE_END
#define RVTEST_DATA_BEGIN .section .data; .align 4;
#define RVTEST_DATA_END
#define RVTEST_PASS li t0,0x80002018; li t1,1; sw t1,0(t0); 1: j 1b;
#define RVTEST_FAIL li t0,0x80002018; li t1,0xdead0000; or t1,t1,TESTNUM; sw t1,0(t0); 1: j 1b;
#define TESTNUM gp
#endif
