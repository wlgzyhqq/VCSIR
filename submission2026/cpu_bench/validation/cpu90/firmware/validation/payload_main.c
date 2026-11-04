#include "../cpu_bench.h"
#define MMIO(a) (*(volatile uint32_t *)(a))
static void put(int c){while(MMIO(0x80000004u)&1u){}MMIO(0x80000000u)=(uint32_t)c;}
static uint64_t ticks(void){uint32_t h,l,h2;do{h=MMIO(0x80002004u);l=MMIO(0x80002000u);h2=MMIO(0x80002004u);}while(h!=h2);return ((uint64_t)h<<32)|l;}
static uint32_t misa(void){uint32_t v;__asm__ volatile("csrr %0,misa":"=r"(v));return v;}
extern int bench_entry_c(const cpu_bench_api *,uint32_t,uint32_t);
int validation_main(void){
 const cpu_bench_api api={CPU_BENCH_MAGIC,1,90000000u,90000000u,ticks,put,misa};
#ifdef VALIDATE_M
 return bench_entry_c(&api,1,0)?0xdead0901u:1;
#else
 int a=bench_entry_c(&api,3000,0);
 int b=bench_entry_c(&api,3000,1);
 return (a||b)?0xdead0902u:1;
#endif
}
