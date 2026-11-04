// Platform adaptation only. The six official algorithm/header files are copied
// byte-for-byte and checked against their published coremark.md5 file.
#include "coremark.h"
#include "../../cpu_bench.h"
#include <stdarg.h>
#ifndef COREMARK_REQUIRE_M
#define COREMARK_REQUIRE_M 0
#endif
volatile ee_s32 seed1_volatile,seed2_volatile,seed3_volatile=0x66;
volatile ee_s32 seed4_volatile,seed5_volatile;
ee_u32 default_num_contexts=1;
static const cpu_bench_api *api;
static uint64_t start_ticks,stop_ticks;
static uint32_t validated,errors,actual_iterations;
static void emit(char c) {if(c=='\n')api->putc('\r');api->putc(c);}
static void string(const char *s) {while(*s)emit(*s++);}
static int contains(const char *s,const char *needle) {
 for(;*s;s++){const char *a=s,*b=needle;while(*a && *b && *a==*b){a++;b++;}if(!*b)return 1;}return 0;
}
static void number(uint32_t n,uint32_t base,uint32_t width,char pad) {
 char b[32];uint32_t i=0;do {b[i++]="0123456789abcdef"[n%base];n/=base;}while(n);
 while(width>i){emit(pad);width--;}while(i)emit(b[--i]);
}
int ee_printf(const char *fmt,...) {
 if(contains(fmt,"Correct operation validated."))validated=1;
 if(contains(fmt,"ERROR") || contains(fmt,"Errors detected") || contains(fmt,"Cannot validate"))errors++;
 va_list args;va_start(args,fmt);
 if(contains(fmt,"Iterations       :")) {va_list copy;va_copy(copy,args);actual_iterations=(uint32_t)va_arg(copy,unsigned long);va_end(copy);}
 while(*fmt) {
  if(*fmt!='%'){emit(*fmt++);continue;}
  fmt++;uint32_t width=0;char pad=' ';if(*fmt=='0'){pad='0';fmt++;}
  while(*fmt>='0' && *fmt<='9'){width=width*10u+(uint32_t)(*fmt++-'0');}
  int islong=*fmt=='l';if(islong)fmt++;
  switch(*fmt++) {
   case '%':emit('%');break;
   case 's':string(va_arg(args,const char *));break;
   case 'c':emit((char)va_arg(args,int));break;
   case 'd':{int32_t n=islong?(int32_t)va_arg(args,long):va_arg(args,int);if(n<0)emit('-');number(n<0?0u-(uint32_t)n:(uint32_t)n,10,width,pad);break;}
   case 'u':number(islong?(uint32_t)va_arg(args,unsigned long):va_arg(args,unsigned),10,width,pad);break;
   case 'x':number(islong?(uint32_t)va_arg(args,unsigned long):va_arg(args,unsigned),16,width,pad);break;
   case 'f':{double n=va_arg(args,double);if(n<0){emit('-');n=-n;}uint32_t whole=(uint32_t)n;uint32_t frac=(uint32_t)((n-whole)*1000000.0+0.5);if(frac==1000000u){whole++;frac=0;}number(whole,10,0,' ');emit('.');number(frac,10,6,'0');break;}
   default:errors++;string("[unsupported format]");break;
  }
 }
 va_end(args);return 0;
}
void start_time(void) {start_ticks=api->ticks();}
void stop_time(void) {stop_ticks=api->ticks();}
CORE_TICKS get_time(void) {
 uint64_t micros=(stop_ticks-start_ticks)*1000000u/api->timer_hz;
 if(micros>0xffffffffu)errors++;
 return (uint32_t)micros;
}
secs_ret time_in_secs(CORE_TICKS ticks) {return (double)ticks/1000000.0;}
void portable_init(core_portable *p,int *argc,char *argv[]) {(void)argc;(void)argv;p->portable_id=1;default_num_contexts=1;}
void portable_fini(core_portable *p) {p->portable_id=0;}
extern int main(void);
int bench_entry_c(const cpu_bench_api *interface,uint32_t iterations,uint32_t validation) {
 if(!interface || interface->magic!=CPU_BENCH_MAGIC || interface->version!=1u ||
    !interface->cpu_hz || !interface->timer_hz || validation>1u)return 1;
 api=interface;errors=validated=actual_iterations=0;
 if(COREMARK_REQUIRE_M && !(api->misa()&(1u<<12)))return 1;
 seed1_volatile=seed2_volatile=validation?0x3415:0;
 seed3_volatile=0x66;seed4_volatile=(ee_s32)iterations;seed5_volatile=0;
 main();
 uint64_t elapsed=stop_ticks-start_ticks;
 ee_printf("@CM_RAW %08x %08x %08x %08x %08x %08x %08x %08x\n",
  COREMARK_REQUIRE_M,validation,actual_iterations,api->cpu_hz,api->timer_hz,
  (uint32_t)elapsed,(uint32_t)(elapsed>>32),validated && !errors);
 return !validated || errors!=0;
}
