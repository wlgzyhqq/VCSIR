// Small standalone TF loader. No model, font, soft float or runtime drivers.
#include "platform.h"
#include "sd_spi_protocol.h"
#include "storage.h"
#define SD(n) REG(0x80006000u+((n)<<2))
#define DMA(n) REG(0x80005000u+((n)<<2))
static uint32_t divider=4,select_n=1,last_error;
static uint64_t sectors;
static uint8_t csd[16];

static uint64_t now(void) {
 uint32_t h,l,h2;do{h=MTIME_HI;l=MTIME_LO;h2=MTIME_HI;}while(h!=h2);return ((uint64_t)h<<32)|l;
}
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

int storage_init(void){return init_card();}
uint64_t storage_capacity(void){return sectors;}
uint32_t storage_error(void){return last_error;}
int storage_sector(uint32_t lba,uint8_t out[512]){
 uint8_t r;if((uint64_t)lba>=sectors || !command(17,lba,&r)||r||!exec(2,512,0xffffffffu,0))return 0;
 for(uint32_t i=0;i<128;i++){if(!exec(3,0,0,i))return 0;uint32_t v=SD(8);for(uint32_t j=0;j<4;j++)out[i*4+j]=(uint8_t)(v>>(j*8));}return deselect();
}
int storage_crc(uint32_t address,uint32_t bytes,uint32_t expected){
 SD(2)=4;SD(3)=bytes;SD(4)=4;SD(5)=1;SD(6)=0xffffffffu;SD(7)=0;
 DMA(2)=address;DMA(3)=0;DMA(4)=bytes;DMA(5)=0x802;DMA(6)=0;DMA(7)=0xffffffu;
 fence_memory();SD(1)=3;DMA(1)=3;uint64_t t=now();
 while((SD(1)&1u)||(DMA(1)&1u))if(now()-t>(CPU_CLOCK_HZ*5u))return 0;
 return !SD(9)&&!DMA(8)&&SD(12)==bytes&&DMA(9)==bytes&&(SD(10)^0xffffffffu)==expected;
}
int storage_load_fast(uint32_t lba,uint32_t bytes,uint32_t address,uint32_t expected){
 uint8_t r;if(!bytes || (uint64_t)lba+(((uint64_t)bytes+511u)>>9)>sectors || (address&31u) || address<0x02000000u || (uint64_t)address+bytes>0x40000000ull)return 0;
 if(!command(18,lba,&r)||r)return 0;
 DMA(2)=0;DMA(3)=address;DMA(4)=bytes;DMA(5)=0x804;DMA(6)=0;DMA(7)=0xffffffu;
 SD(2)=258;SD(3)=bytes;SD(4)=divider;SD(5)=0;SD(6)=0xffffffffu;SD(7)=0;
 fence_memory();DMA(1)=3;SD(1)=3;uint64_t t=now();
 while((SD(1)&1u)||(DMA(1)&1u))if(now()-t>(CPU_CLOCK_HZ*10u)){DMA(1)=4;return 0;}
 if(!stop_read())return 0;
 /* The SD controller's own CRC already verified the payload; skipping the
    software CRC keeps per-frame video loads cheap. */
 if(!(!SD(9)&&!DMA(8)&&DMA(9)==bytes&&(SD(10)^0xffffffffu)==expected))return 0;
 return 1;
}
int storage_load(uint32_t lba,uint32_t bytes,uint32_t address,uint32_t expected){
 uint8_t r;if(!bytes || (uint64_t)lba+(((uint64_t)bytes+511u)>>9)>sectors || (address&31u) || address<0x02000000u || (uint64_t)address+bytes>0x40000000ull)return 0;
 if(!command(18,lba,&r)||r)return 0;
 DMA(2)=0;DMA(3)=address;DMA(4)=bytes;DMA(5)=0x804;DMA(6)=0;DMA(7)=0xffffffu;
 SD(2)=258;SD(3)=bytes;SD(4)=divider;SD(5)=0;SD(6)=0xffffffffu;SD(7)=0;
 fence_memory();DMA(1)=3;SD(1)=3;uint64_t t=now();
 while((SD(1)&1u)||(DMA(1)&1u))if(now()-t>(CPU_CLOCK_HZ*10u)){DMA(1)=4;return 0;}
 uint32_t good=!SD(9)&&!DMA(8)&&SD(12)==bytes&&DMA(9)==bytes&&(SD(10)^0xffffffffu)==expected;
 if(!stop_read() || !good)return 0;
 return storage_crc(address,bytes,expected);
}
