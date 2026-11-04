// Small standalone TF loader. No model, font, soft float or runtime drivers.
#include "../platform.h"
#include "../sd_spi_protocol.h"
#include "boot_format.h"
#define SD(n) REG(0x80006000u+((n)<<2))
#define DMA(n) REG(0x80005000u+((n)<<2))
static uint32_t divider,select_n,last_error;
static uint64_t sectors;
static uint8_t header[512],csd[16];
extern void boot_handoff(void) __attribute__((noreturn));
static uint64_t now(void) {
 uint32_t h,l,h2;do{h=MTIME_HI;l=MTIME_LO;h2=MTIME_HI;}while(h!=h2);return ((uint64_t)h<<32)|l;
}
static void hex(uint32_t x){static const char d[]="0123456789abcdef";for(uint32_t i=8;i;i--)putchar_uart(d[(x>>((i-1u)<<2))&15u]);}
static void line(const char *s,uint32_t v){puts_uart(s);hex(v);puts_uart("\r\n");}
static int exec(uint32_t op,uint32_t arg,uint32_t seed,uint32_t index) {
 SD(2)=op;SD(3)=arg;SD(4)=divider;SD(5)=select_n;SD(6)=seed;SD(7)=index;
 fence_memory();SD(1)=3;uint64_t t=now();
 while(SD(1)&1u)if(now()-t>(CPU_CLOCK_HZ/2u))return 0;
 last_error=SD(9);return !last_error;
}
static int byte(uint8_t tx,uint8_t *rx){if(!exec(1,tx,0,0))return 0;*rx=(uint8_t)SD(8);return 1;}
static int dummy(void){uint8_t v;return byte(255,&v);}
static int deselect(void){select_n=1;return dummy();}
static uint8_t crc7(const uint8_t *p){uint8_t c=0;for(uint32_t i=0;i<5;i++)for(uint32_t b=0;b<8;b++){uint8_t m=((c>>6)^(p[i]>>(7u-b)))&1u;c=(uint8_t)((c<<1)&127u);if(m)c^=9u;}return (uint8_t)((c<<1)|1u);}
static int command(uint32_t id,uint32_t arg,uint8_t *r){
 uint8_t p[6]={(uint8_t)(64u|id),(uint8_t)(arg>>24),(uint8_t)(arg>>16),(uint8_t)(arg>>8),(uint8_t)arg,0},v;
 p[5]=crc7(p);select_n=0;if(id!=12 && !dummy())return 0;
 for(uint32_t i=0;i<6;i++)if(!byte(p[i],&v))return 0;
 if(id==12 && !dummy())return 0;
 for(uint32_t i=0;i<32;i++){if(!byte(255,&v))return 0;if(!(v&128u)){*r=v;return 1;}}return 0;
}
static uint16_t crc16(uint16_t c,uint8_t b){c^=(uint16_t)b<<8;for(uint32_t i=0;i<8;i++)c=(uint16_t)((c<<1)^((c&0x8000u)?0x1021u:0u));return c;}
static int init_card(void){
 uint8_t r,v;divider=200;select_n=1;
 if(SD(14)&1u)return 0;
 uint64_t t=now();while(now()-t<100000u){}
 for(uint32_t i=0;i<16;i++)if(!dummy())return 0;
 if(!command(0,0,&r)||r!=1||!deselect())return 0;
 if(!command(8,0x1aa,&r)||r!=1)return 0;
 uint32_t echo=0;for(uint32_t i=0;i<4;i++){if(!byte(255,&v))return 0;echo=(echo<<8)|v;}
 if(!sd_cmd8_echo_valid(echo)||!deselect())return 0;
 t=now();do{
  if(!command(55,0,&r)||(r!=0&&r!=1)||!deselect()||!command(41,0x40000000u,&r)||!deselect())return 0;
  if(r>1||now()-t>(CPU_CLOCK_HZ*2u))return 0;
 }while(r);
 if(!command(58,0,&r)||r)return 0;
 uint32_t ocr=0;for(uint32_t i=0;i<4;i++){if(!byte(255,&v))return 0;ocr=(ocr<<8)|v;}
 if((ocr&0xc0000000u)!=0xc0000000u||!(ocr&0x00ff8000u)||!deselect())return 0;
 if(!command(59,1,&r)||r||!deselect()||!command(9,0,&r)||r)return 0;
 t=now();do{if(!byte(255,&v)||now()-t>(CPU_CLOCK_HZ/10u))return 0;}while(v==255);
 if(v!=254)return 0;
 uint16_t c=0,got;for(uint32_t i=0;i<16;i++){if(!byte(255,&csd[i]))return 0;c=crc16(c,csd[i]);}
 if(!byte(255,&v))return 0;
 got=(uint16_t)v<<8;
 if(!byte(255,&v))return 0;
 got|=v;
 if(c!=got||(csd[0]>>6)!=1||!deselect())return 0;
 uint32_t size=((uint32_t)(csd[7]&63u)<<16)|((uint32_t)csd[8]<<8)|csd[9];
 sectors=((uint64_t)size+1u)<<10;divider=4;return 1;
}
static int stop_read(void){
 uint8_t r,v;int ok=command(12,0,&r)&&r==0;uint64_t t=now();
 if(ok)do{if(!byte(255,&v)||now()-t>(CPU_CLOCK_HZ/2u)){ok=0;break;}}while(v==0);
 int end=deselect();return ok&&end;
}
static uint32_t load(uint32_t inject){
 uint8_t r;if(!init_card())return 0x201;
 if(!command(17,TF_BOOT_HEADER_LBA,&r)||r||!exec(2,512,0xffffffffu,0))return 0x202;
 for(uint32_t i=0;i<128;i++){
  if(!exec(3,0,0,i))return 0x203;
  uint32_t w=SD(8);for(uint32_t j=0;j<4;j++)header[(i<<2)+j]=(uint8_t)(w>>(j<<3));
 }
 if(!deselect())return 0x204;
 uint32_t why=boot_header_validate(header,sectors);if(why)return why;
 uint32_t bytes=boot_word(header,20),padded=boot_word(header,24);
 if(!command(18,TF_BOOT_PAYLOAD_LBA,&r)||r)return 0x205;
 DMA(2)=0;DMA(3)=TF_BOOT_STAGE;DMA(4)=padded;DMA(5)=0x804;DMA(6)=0;DMA(7)=0xffffffu;
 SD(2)=258;SD(3)=padded;SD(4)=divider;SD(5)=0;SD(6)=0xffffffffu;SD(7)=0;
 fence_memory();DMA(1)=3;SD(1)=3;uint64_t t=now();
 while((SD(1)&1u)||(DMA(1)&1u))if(now()-t>(CPU_CLOCK_HZ*2u)){DMA(1)=4;return 0x206;}
 uint32_t bad=SD(9)|DMA(8),got=SD(10)^0xffffffffu,received=SD(12),written=DMA(9);
 if(!stop_read())return 0x207;
 if(bad||received!=padded||written!=padded||got!=boot_word(header,44))return 0x208;
 if(inject)REG(TF_BOOT_STAGE)^=1u; // Explicit UART diagnostic; never writes TF.
 uint32_t raw=0xffffffffu,pad=0xffffffffu;
 for(uint32_t i=0;i<padded;i++){
  uint8_t b=*(volatile uint8_t *)(uintptr_t)(TF_BOOT_STAGE+i);
  pad=boot_crc_byte(pad,b);if(i<bytes)raw=boot_crc_byte(raw,b);else if(b)return 0x209;
 }
 if((raw^0xffffffffu)!=boot_word(header,40)||(pad^0xffffffffu)!=boot_word(header,44))return 0x20a;
 line("@BOOT0_FW_BYTES ",bytes);line("@BOOT0_CRC ",raw^0xffffffffu);
 REG(0x03c10000u)=0x54464231u;REG(0x03c10004u)=bytes;REG(0x03c10008u)=raw^0xffffffffu;
 REG(0x8000201cu)=padded;fence_memory();return 0;
}
static uint32_t uart_word(void){uint32_t v=0;for(uint32_t i=0;i<4;i++){uint64_t t=now();while(!(UART_STATUS&2u))if(now()-t>(CPU_CLOCK_HZ*3u))return 0;v|=(UART_DATA&255u)<<(8*i);}return v;}
static uint32_t uart_recovery(void){
 uint32_t bytes=uart_word(),expected=uart_word();if(!bytes || (bytes&3u) || bytes>TF_BOOT_LIMIT)return 0x220;
 puts_uart("@BOOT0_UART_READY\r\n");uint32_t crc=0xffffffffu;
 for(uint32_t i=0;i<bytes;i++){
  uint64_t t=now();while(!(UART_STATUS&2u))if(now()-t>(CPU_CLOCK_HZ*3u))return 0x221;
  if(UART_STATUS&12u)return 0x222;
  uint8_t b=(uint8_t)UART_DATA;*(volatile uint8_t *)(uintptr_t)(TF_BOOT_STAGE+i)=b;crc=boot_crc_byte(crc,b);
 }
 if((crc^0xffffffffu)!=expected)return 0x223;
 uint32_t padded=(bytes+31u)&~31u;for(uint32_t i=bytes;i<padded;i++)*(volatile uint8_t *)(uintptr_t)(TF_BOOT_STAGE+i)=0;
 crc=0xffffffffu;for(uint32_t i=0;i<bytes;i++)crc=boot_crc_byte(crc,*(volatile uint8_t *)(uintptr_t)(TF_BOOT_STAGE+i));
 if((crc^0xffffffffu)!=expected)return 0x224;
 REG(0x8000201cu)=padded;fence_memory();puts_uart("@BOOT0_UART_VERIFIED volatile recovery; TF unchanged\r\n");while(UART_STATUS&1u){}boot_handoff();
}
int main(void){
 GPIO_DIR=3;GPIO_OUT=0x4200;UART_CONTROL=15;
 puts_uart("@BOOT0_READY v1 TF firmware; h=hold, c=CRC fault test, r=retry u=UART recovery\r\n");
 uint64_t t=now();uint32_t inject=0,hold=0;
 while(now()-t<(CPU_CLOCK_HZ/2u)){if(UART_STATUS&2u){uint32_t c=UART_DATA;if(c=='h')hold=1;if(c=='c')inject=1;}}
 if(hold){puts_uart("@BOOT0_HELD\r\n");for(;;)if(UART_STATUS&2u){uint32_t c=UART_DATA;if(c=='u'){uint32_t why=uart_recovery();line("@BOOT0_UART_ERROR ",why);}if(c=='r'||c=='c'){inject=c=='c';break;}}}
 for(;;){
  uint64_t begun=now();uint32_t why=load(inject);
  if(!why){uint64_t dt=now()-begun;line("@BOOT0_TICKS_LO ",(uint32_t)dt);line("@BOOT0_TICKS_HI ",(uint32_t)(dt>>32));puts_uart("@BOOT0_VERIFIED CPU reset handoff\r\n");while(UART_STATUS&1u){}boot_handoff();}
  deselect();GPIO_OUT=0xec00;line("@BOOT0_ERROR ",why);line("@BOOT0_SD_ERROR ",last_error);
  puts_uart("@BOOT0_WAIT_RETRY r=reload c=CRC fault test; TF unchanged\r\n");
  for(;;)if(UART_STATUS&2u){uint32_t c=UART_DATA;if(c=='u'){uint32_t why=uart_recovery();line("@BOOT0_UART_ERROR ",why);}if(c=='r'||c=='c'){inject=c=='c';break;}}
 }
}
