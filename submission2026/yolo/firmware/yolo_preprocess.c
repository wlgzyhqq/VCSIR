#include "platform.h"
#include "yolo_network.h"
static uint32_t quantize(uint32_t c){
 // round(c*127/255), no half-way ties for integer c0..255. Exact divide255
 // identity over x0..32512; no floating-point or general division needed.
 uint32_t x=(c<<7)-c+127u;return (x+1u+(x>>8))>>8;
}
static uint32_t red8(uint32_t px){uint32_t v=(px>>11)&31u;return (v<<3)|(v>>2);}
static uint32_t green8(uint32_t px){uint32_t v=(px>>5)&63u;return (v<<2)|(v>>4);}
static uint32_t blue8(uint32_t px){uint32_t v=px&31u;return (v<<3)|(v>>2);}
/* 320x320 RGB565 display image -> 160x160x3 INT8 CHW network input.
   Expand 5/6-bit components by bit replication, average each 2x2 block with
   (a+b+c+d+2)>>2, then round(v*127/255). Identical to tools/net_input.py. */
uint32_t yolo_prepare_rgb565(uint32_t src,uint32_t dst){
#ifndef YOLO_HOST_TEST
 if((src&3u)||(dst&31u)||src<0x02000000u||dst<0x02000000u||src>0x3ffce000u||dst>0x3ffb5000u)return 1;
 if(src<dst+76800u&&dst<src+204800u)return 2;
#endif
 const volatile uint32_t *pixels=(const volatile uint32_t *)(uintptr_t)src;
 volatile uint32_t *red=(volatile uint32_t *)(uintptr_t)dst,*green=red+6400u,*blue=red+12800u;
 uint32_t out=0;
 for(uint32_t y=0;y<160u;y++){
  const volatile uint32_t *row0=pixels+(y*2u)*160u,*row1=row0+160u;
  for(uint32_t x=0;x<160u;x+=4u){
   uint32_t rw=0,gw=0,bw=0;
   for(uint32_t j=0;j<4u;j++){
    uint32_t w0=row0[x+j],w1=row1[x+j];
    uint32_t a0=w0&0xffffu,a1=w0>>16,b0=w1&0xffffu,b1=w1>>16;
    uint32_t r=(red8(a0)+red8(a1)+red8(b0)+red8(b1)+2u)>>2;
    uint32_t g=(green8(a0)+green8(a1)+green8(b0)+green8(b1)+2u)>>2;
    uint32_t b=(blue8(a0)+blue8(a1)+blue8(b0)+blue8(b1)+2u)>>2;
    rw|=quantize(r)<<(j*8u);gw|=quantize(g)<<(j*8u);bw|=quantize(b)<<(j*8u);
   }
   red[out]=rw;green[out]=gw;blue[out]=bw;out++;
  }
 }
 fence_memory();return 0;
}
