#include "../cpu_bench.h"
#define MMIO(a) (*(volatile uint32_t *)(a))
static void put(int c){while(MMIO(0x80000004u)&1u){} MMIO(0x80000000u)=(uint32_t)c;}
static uint64_t ticks(void){uint32_t h,l,h2;do{h=MMIO(0x80002004u);l=MMIO(0x80002000u);h2=MMIO(0x80002004u);}while(h!=h2);return ((uint64_t)h<<32)|l;}
static uint32_t misa(void){uint32_t v;__asm__ volatile("csrr %0,misa":"=r"(v));return v;}
extern int bench_entry_c(const cpu_bench_api *,uint32_t,uint32_t);
void bench_boot(void){
 const cpu_bench_api api={CPU_BENCH_MAGIC,1,90000000u,90000000u,ticks,put,misa};
 const char *s="\r\nFINAL2 CPU ONLY 90MHz RV32IM RAM64K\r\n";while(*s)put(*s++);
 int a=bench_entry_c(&api,3000,0);int b=bench_entry_c(&api,3000,1);
 MMIO(0x80001000u)=(a||b)?0xee00u:0x5500u;
 s=(a||b)?"\r\n@CPU_ONLY FAIL\r\n":"\r\n@CPU_ONLY PASS\r\n";while(*s)put(*s++);
 for(;;)__asm__ volatile("wfi");
}
