#ifndef FINAL_TF_BOOT_FORMAT_H
#define FINAL_TF_BOOT_FORMAT_H
#include <stdint.h>
#define TF_BOOT_HEADER_LBA 64u
#define TF_BOOT_PAYLOAD_LBA 65u
#define TF_BOOT_ABI 2u
#define TF_BOOT_STAGE 0x03d00000u
#define TF_BOOT_LIMIT 0x0001e000u
static uint32_t boot_crc_byte(uint32_t c,uint8_t b) {
 c^=b;for(uint32_t i=0;i<8u;i++)c=(c>>1)^((0u-(c&1u))&0xedb88320u);return c;
}
static uint32_t boot_crc(const uint8_t *p,uint32_t n) {
 uint32_t c=0xffffffffu;for(uint32_t i=0;i<n;i++)c=boot_crc_byte(c,p[i]);return c^0xffffffffu;
}
static uint32_t boot_word(const uint8_t *h,uint32_t off) {
 return (uint32_t)h[off]|((uint32_t)h[off+1]<<8)|((uint32_t)h[off+2]<<16)|((uint32_t)h[off+3]<<24);
}
// Fixed source/destination/entry prevent a corrupt header from writing any
// working region. CRC provides integrity, not cryptographic authentication.
static uint32_t boot_header_validate(const uint8_t *h,uint64_t sectors) {
 static const uint8_t magic[8]={'Y','O','L','B','O','O','T','1'};
 for(uint32_t i=0;i<8;i++)if(h[i]!=magic[i])return 0x101;
 if(boot_crc(h,508)!=boot_word(h,508))return 0x102;
 if(boot_word(h,8)!=1u || boot_word(h,12)!=512u || boot_word(h,16)!=TF_BOOT_ABI)return 0x103;
 uint32_t n=boot_word(h,20),padded=boot_word(h,24);
 if(!n || (n&3u) || n>TF_BOOT_LIMIT || padded!=((n+31u)&~31u))return 0x104;
 if(boot_word(h,28)!=TF_BOOT_PAYLOAD_LBA || boot_word(h,32)!=0 || boot_word(h,36)!=0)return 0x105;
 uint32_t end=TF_BOOT_PAYLOAD_LBA+((padded+511u)>>9);
 if(end>2048u || end>sectors)return 0x106;
 for(uint32_t i=80;i<508;i++)if(h[i])return 0x107;
 return 0;
}
#endif
