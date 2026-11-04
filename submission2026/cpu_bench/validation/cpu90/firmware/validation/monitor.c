#include <stdint.h>
#define REG(a) (*(volatile uint32_t *)(a))
#define DBG 0x80004000u
static uint32_t loaded;
extern void monitor_trap_entry(void);
static void put(int c){while(REG(0x80000004u)&1){} REG(0x80000000u)=(uint8_t)c;}
static int get(void){while(!(REG(0x80000004u)&2)){}return REG(0x80000000u)&255;}
static uint32_t word(void){uint32_t a=0;for(int i=0;i<4;i++)a|=(uint32_t)get()<<(8*i);return a;}
static void text(const char*s){while(*s)put(*s++);}
static void hex(uint32_t x){for(int i=7;i>=0;i--){int v=(x>>(4*i))&15;put(v<10?'0'+v:'a'+v-10);}}
static uint32_t crcbyte(uint32_t c,uint32_t b){c^=b;for(int i=0;i<8;i++)c=(c>>1)^((0u-(c&1))&0xedb88320u);return c;}
static void safe(void){
 __asm__ volatile("csrw mie,zero; csrci mstatus,8":::"memory");
 REG(0x80002010u)=0;REG(0x80002014u)=0;
 REG(0x80002008u)=0xffffffff;REG(0x8000200cu)=0xffffffff;
 REG(0x8000100cu)=0;REG(0x80001010u)=0xffffffff;
 REG(DBG+0x20)=0;
 __asm__ volatile("csrw mtvec,%0"::"r"(monitor_trap_entry):"memory");
}
__attribute__((noreturn)) static void loop(void){
 for(;;){int c=get();
  if(c=='L'){
   uint32_t n=word(),expected=word(),crc=~0u;
   if(n==0||n>0xc000u){text("@BADLEN\r\n");continue;}
   for(uint32_t i=0;i<n;i++){uint32_t b=get();*(volatile uint8_t*)(0x40002000u+i)=b;crc=crcbyte(crc,b);}
   uint32_t mem=~0u;for(uint32_t i=0;i<n;i++)mem=crcbyte(mem,*(volatile uint8_t*)(0x40002000u+i));
   loaded=((~crc)==expected && (~mem)==expected)?n:0;
   text("@LOAD ");hex(n);put(' ');hex(~crc);put(' ');hex(~mem);put(' ');hex(REG(0x80000004u));text("\r\n");
  }else if(c=='R'){
   if(!loaded){text("@NOIMAGE\r\n");continue;}
   safe();REG(0x80002018u)=0;__asm__ volatile("fence.i":::"memory");
   text("@RUN\r\n");REG(DBG+0x24)=3;REG(DBG+0x20)=1;
   __asm__ volatile("li t0,0x2000; jr t0":::"memory");__builtin_unreachable();
  }else if(c=='Q'){
   uint32_t a=word();text("@READ ");hex(a);put(' ');hex(REG(a));text("\r\n");
  }else if(c=='W'){
   uint32_t a=word(),v=word();REG(a)=v;text("@WRITE ");hex(a);put(' ');hex(v);text("\r\n");
  }else if(c=='E'){
   uint32_t n=word();if(n>0xc000u){text("@BADLEN\r\n");continue;}
   uint32_t crc=~0u;for(uint32_t i=0;i<n;i++){uint32_t b=get();*(volatile uint8_t*)(0x40002000u+i)=b;crc=crcbyte(crc,b);}
   text("@ECHO ");hex(n);put(' ');hex(~crc);text("\r\n");
   for(uint32_t i=0;i<n;i++)put(*(volatile uint8_t*)(0x40002000u+i));text("\r\n@ECHOEND\r\n");loaded=0;
  }else if(c=='T'){
   uint32_t status=REG(DBG+4),n=(status>>8)&511;
   text("@TRACE ");hex(n);put(' ');hex(status);text("\r\n");
   for(uint32_t i=0;i<n;i++)for(uint32_t w=0;w<12;w++){
    REG(DBG+0x10)=i|(w<<8);__asm__ volatile("fence iorw,iorw"::: "memory");uint32_t a=REG(DBG+0x14);
    for(int k=0;k<4;k++)put(a>>(8*k));
   }text("\r\n@TRACEEND\r\n");
  }else if(c=='M'){
   text("@METRICS ");for(uint32_t i=0;i<32;i++){hex(REG(DBG+0x100+4*i));put(' ');}text("\r\n");
  }else if(c=='Z'){
   REG(DBG)=8;for(;;){}
  }else if(c=='P')text("@PONG VAL3\r\n");
 }
}
__attribute__((noreturn)) void monitor_boot(void){safe();REG(DBG+0x1c)=270000000u;REG(DBG+0x24)=0;
 text("\r\n@MONBOOT VAL3 ");hex(REG(DBG+0x30));put(' ');hex(REG(DBG+0x2c));text("\r\n");loop();}
__attribute__((noreturn)) void monitor_done(uint32_t value){REG(DBG+0x24)=0;REG(DBG+0x20)=0;safe();text("@RESULT ");hex(value);put(' ');hex(REG(0x80000004u));text("\r\n");loop();}
__attribute__((noreturn)) void monitor_trapped(uint32_t cause,uint32_t pc,uint32_t val){REG(DBG+0x24)=0;REG(DBG+0x20)=0;safe();text("@TRAP ");hex(cause);put(' ');hex(pc);put(' ');hex(val);text("\r\n");loop();}
