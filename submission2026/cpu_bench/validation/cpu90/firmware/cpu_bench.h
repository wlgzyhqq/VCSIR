#ifndef FINAL_CPU_BENCH_H
#define FINAL_CPU_BENCH_H
#include <stdint.h>
#define CPU_BENCH_MAGIC 0x434d4231u
typedef struct {
 uint32_t magic,version,cpu_hz,timer_hz;
 uint64_t (*ticks)(void);
 void (*putc)(int);
 uint32_t (*misa)(void);
} cpu_bench_api;
uint32_t cpu_bench_misa(void);
int cpu_bench_run(uint32_t iterations,uint32_t validation);
#endif
