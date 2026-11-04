#include "platform.h"
#include "yolo_network.h"
typedef struct {
 uint16_t id,op,nin,c,h,w,cin,ih,iw,kernel,stride,pad,bits,silu;
 uint32_t dst,src[4],size[4],table[4],weights,bias,mult,shift,lut,weight_stride;
} YoloNode;
typedef struct {uint32_t address;uint16_t w,h,stride,anchors[6];} YoloHead;
#include "model_tables.h"
#define CNN(o) REG(0x80004000u+(o))
static int16_t table_a[256],table_b[256];
static int8_t plane[1024],plane2[1024];
static uint32_t ticks(void){return MTIME_LO;}
static uint32_t source(uint32_t addr,uint32_t input){return addr==0x02000000u?input:addr;}
uint32_t yolo_tensor_crc(uint32_t addr,uint32_t size){
 const volatile uint32_t *p=(const volatile uint32_t *)(uintptr_t)addr;uint32_t c=~0u;
 for(uint32_t i=0;i<size;i+=4){uint32_t v=*p++;uint32_t count=size-i<4?size-i:4;
  for(uint32_t j=0;j<count;j++){c^=v&255u;v>>=8;for(uint32_t b=0;b<8;b++)c=(c>>1)^((0u-(c&1u))&0xedb88320u);}}
 return ~c;
}
static int32_t round_q7(int32_t x){
 uint32_t a=x<0?(uint32_t)-x:(uint32_t)x,q=a>>7,rem=a&127u;
 if(rem>64u||(rem==64u&&(q&1u)))q++;
 return x<0?-(int32_t)q:(int32_t)q;
}
static uint8_t clamp8(int32_t x){return (uint8_t)(x>127?127:(x< -128?-128:x));}
static void load_table(uint32_t addr,int16_t *dst,uint32_t wide){
 const volatile uint32_t *p=(const volatile uint32_t *)(uintptr_t)addr;
 for(uint32_t i=0;i<256;){uint32_t v=*p++;for(uint32_t j=0;j<(wide?2u:4u);j++,i++){
  dst[i]=wide?(int16_t)(v&65535u):(int8_t)(v&255u);v>>=wide?16:8;}}
}
static uint32_t conv(const YoloNode *n,uint32_t input){
 uint32_t ip=(uint32_t)n->iw*n->ih,op=(uint32_t)n->w*n->h*(n->bits/8u);
 if(CNN(0)!=0x59434e31u)return 1;
 for(uint32_t oc=0;oc<n->c;oc+=8){
  if(CNN(4)&1u)return 2;
  uint32_t count=n->c-oc<8?n->c-oc:8;
  uint32_t cacheable=((uint32_t)n->cin*ip)<=32768u;
  uint32_t cache_bits=cacheable?(1u<<26)|((oc==0)?(1u<<27):0u):0u;
  const uint32_t cfg[]={source(n->src[0],input),n->dst+oc*op,n->weights+oc*n->weight_stride,
   n->bias+oc*4,n->mult+oc*4,n->shift+oc*4,n->lut,
   n->iw|((uint32_t)n->ih<<16),n->cin|(count<<16),n->w|((uint32_t)n->h<<16),
   n->kernel|((uint32_t)n->stride<<8)|((uint32_t)n->pad<<16)|((uint32_t)n->silu<<24)|((uint32_t)(n->bits==16)<<25)|cache_bits,
   n->weight_stride,ip,op};
  for(uint32_t j=0;j<14;j++)CNN(12+j*4)=cfg[j];
  fence_memory();CNN(8)=1;uint32_t began=ticks();
  while(CNN(4)&1u)if(ticks()-began>(CPU_CLOCK_HZ*30u))return 3;
  if(!(CNN(4)&2u)||CNN(0x50))return 0x100u|CNN(0x50);
 }
 return 0;
}
static uint32_t pointwise(const YoloNode *n,uint32_t input){
 volatile uint32_t *dst=(volatile uint32_t *)(uintptr_t)n->dst;
 const volatile uint32_t *a=(const volatile uint32_t *)(uintptr_t)source(n->src[0],input);
 uint32_t bytes=(uint32_t)n->c*n->h*n->w;
 if(n->op==2){
  const volatile uint32_t *b=(const volatile uint32_t *)(uintptr_t)n->src[1];
  load_table(n->table[0],table_a,1);load_table(n->table[1],table_b,1);
  if(bytes&3u)return 1;
  for(uint32_t i=0;i<bytes;i+=4){uint32_t av=*a++,bv=*b++,v=0;
   for(uint32_t j=0;j<4;j++){v|=(uint32_t)clamp8(round_q7((int32_t)table_a[av&255u]+table_b[bv&255u]))<<(j*8);av>>=8;bv>>=8;}*dst++=v;}
 }else if(n->op==3){
  for(uint32_t s=0;s<n->nin;s++){
   a=(const volatile uint32_t *)(uintptr_t)n->src[s];
   /* Single-use identity-scale inputs are written straight into the concat
      buffer by their producer, so there is nothing left to copy. */
   if((uint32_t)n->src[s]==(uint32_t)(uintptr_t)dst){dst+=n->size[s]>>2;continue;}
   load_table(n->table[s],table_a,0);
   if(n->size[s]&3u)return 2;
   for(uint32_t i=0;i<n->size[s];i+=4){uint32_t av=*a++,v=0;for(uint32_t j=0;j<4;j++){v|=(uint32_t)(uint8_t)table_a[av&255u]<<(j*8);av>>=8;}*dst++=v;}
  }
 }else if(n->op==4){
  /* 5x5 stride-1 max pool with padding 2 (SPPF), any spatial size. */
  uint32_t area=(uint32_t)n->w*n->h;
  if(n->kernel!=5u||n->pad!=2u||area>1024u)return 3;
  const volatile uint8_t *src8=(const volatile uint8_t *)(uintptr_t)source(n->src[0],input);
  uint32_t word=0,count=0;
  for(uint32_t c=0;c<n->c;c++){
   for(uint32_t i=0;i<area;i++)plane[i]=(int8_t)src8[(uint32_t)c*area+i];
   /* Max is separable: horizontal 5-tap pass into plane2, then vertical 5-tap. */
   for(int32_t y=0;y<(int32_t)n->h;y++)for(int32_t x=0;x<(int32_t)n->w;x++){
    int32_t maximum=-128;
    for(int32_t kx=-2;kx<=2;kx++){
     int32_t ix=x+kx;
     if(ix>=0&&ix<(int32_t)n->w&&plane[y*(int32_t)n->w+ix]>maximum)maximum=plane[y*(int32_t)n->w+ix];}
    plane2[y*(int32_t)n->w+x]=(int8_t)maximum;
   }
   for(int32_t y=0;y<(int32_t)n->h;y++)for(int32_t x=0;x<(int32_t)n->w;x++){
    int32_t maximum=-128;
    for(int32_t ky=-2;ky<=2;ky++){
     int32_t iy=y+ky;
     if(iy>=0&&iy<(int32_t)n->h&&plane2[iy*(int32_t)n->w+x]>maximum)maximum=plane2[iy*(int32_t)n->w+x];}
    word|=(uint32_t)(uint8_t)maximum<<(count*8u);if(++count==4u){*dst++=word;word=0;count=0;}
   }
  }
  if(count)*dst++=word;
 }else if(n->op==5){
  /* nearest 2x upsample, any spatial size (row duplicated, column duplicated). */
  uint32_t length=(uint32_t)n->iw*n->ih;
  if(n->w!=n->iw*2u||n->h!=n->ih*2u||length>1024u)return 4;
  const volatile uint8_t *src8=(const volatile uint8_t *)(uintptr_t)source(n->src[0],input);
  uint32_t word=0,count=0;
  for(uint32_t c=0;c<n->c;c++){
   for(uint32_t i=0;i<length;i++)plane[i]=(int8_t)src8[(uint32_t)c*length+i];
   for(uint32_t y=0;y<n->h;y++){
    const int8_t *src=plane+(y>>1)*n->iw;
    for(uint32_t x=0;x<n->w;x++){
     word|=(uint32_t)(uint8_t)src[x>>1]<<(count*8u);if(++count==4u){*dst++=word;word=0;count=0;}
    }
   }
  }
  if(count)*dst++=word;
 }else return 5;
 return 0;
}
uint32_t yolo_input_bytes(void){return (uint32_t)model_nodes[0].cin*model_nodes[0].ih*model_nodes[0].iw;}
uint32_t yolo_infer(uint32_t input,YoloProgress progress,uint32_t verify_layers){
 if(input<0x02000000u||input>0x03000000u||(input&31u))return 0xffff0001u;
 for(uint32_t i=0;i<MODEL_NODE_COUNT;i++){
  const YoloNode *n=&model_nodes[i];uint32_t begin=ticks();
  uint32_t error=n->op==1?conv(n,input):pointwise(n,input);
  if(error)return ((uint32_t)n->id<<16)|error;
  fence_memory();uint32_t crc=verify_layers?yolo_tensor_crc(n->dst,(uint32_t)n->c*n->h*n->w*(n->bits/8u)):0;
  if(progress)progress(n->id,MODEL_NODE_COUNT,ticks()-begin,crc);
 }
 return 0;
}
const char *yolo_label(uint32_t label){return label<80?model_names[label]:"unknown";}
#ifdef YOLO_HOST_TEST
uint32_t yolo_test_pointwise(uint32_t index,uint32_t input){
 if(index>=MODEL_NODE_COUNT || model_nodes[index].op==1)return 0xffff;
 return pointwise(&model_nodes[index],input);
}
#endif
static uint16_t sigmoid(int32_t v){
 // Q10 -> 1/256 grid, signed nearest ties-to-even.
 uint32_t a=v<0?(uint32_t)-v:(uint32_t)v,q=a>>2,rem=a&3u;
 if(rem>2u||(rem==2u&&(q&1u)))q++;
 int32_t i=v<0?-(int32_t)q:(int32_t)q;if(i< -2048)i=-2048;if(i>2048)i=2048;return sigmoid_q15[i+2048];
}
static int32_t max32(int32_t a,int32_t b){return a>b?a:b;}
static int32_t min32(int32_t a,int32_t b){return a<b?a:b;}
static uint32_t overlap(const YoloBox *a,const YoloBox *b){
 int32_t w=min32(a->x2,b->x2)-max32(a->x1,b->x1),h=min32(a->y2,b->y2)-max32(a->y1,b->y1);
 if(w<=0||h<=0)return 0;
 uint32_t inter=(uint32_t)w*(uint32_t)h,area=(uint32_t)(a->x2-a->x1)*(uint32_t)(a->y2-a->y1)+(uint32_t)(b->x2-b->x1)*(uint32_t)(b->y2-b->y1)-inter;
 return (uint64_t)inter*100u>(uint64_t)area*45u;
}
// All 6300 anchors may enter NMS; no top100 truncation before suppression.
// Q4 coordinates fit signed16 for these fixed anchors (largest anchor373).
typedef struct {int16_t x1,y1,x2,y2;uint16_t score;uint8_t label,reserved;} Candidate;
static Candidate candidates[6300];
static uint32_t sort_keys[6300];
static void heap_sift(uint32_t root,uint32_t size){
 for(;;){uint32_t child=root*2u+1u;if(child>=size)return;
  if(child+1u<size&&sort_keys[child+1u]>sort_keys[child])child++;
  if(sort_keys[root]>=sort_keys[child])return;
  uint32_t t=sort_keys[root];sort_keys[root]=sort_keys[child];sort_keys[child]=t;root=child;}
}
uint32_t yolo_detect(YoloBox *boxes,uint32_t capacity){
 uint32_t count=0;
 for(uint32_t head=0;head<3;head++){
  const YoloHead *h=&model_heads[head];const volatile int16_t *p=(const volatile int16_t *)(uintptr_t)h->address;uint32_t plane_size=(uint32_t)h->w*h->h;
  for(uint32_t anchor=0;anchor<3;anchor++)for(uint32_t y=0;y<h->h;y++)for(uint32_t x=0;x<h->w;x++){
   uint32_t pos=anchor*85u*plane_size+y*h->w+x;int32_t obj=p[pos+4u*plane_size];
   if(obj< -1125)continue; // sigmoid(-1125/1024)<0.25, cannot pass joint score.
   int32_t best=-32768;uint32_t label=0;
   for(uint32_t c=0;c<80;c++){int32_t value=p[pos+(5u+c)*plane_size];if(value>best){best=value;label=c;}}
   uint32_t score=((uint32_t)sigmoid(obj)*sigmoid(best)+16384u)>>15;if(score<8192u)continue;
   uint32_t sx=sigmoid(p[pos]),sy=sigmoid(p[pos+plane_size]),sw=sigmoid(p[pos+2u*plane_size]),sh=sigmoid(p[pos+3u*plane_size]);
   // Q4 coordinates. Width/height use Q15 sigmoid, intermediate product is64.
   int32_t cx=(int32_t)((sx*h->stride+512u)>>10)+(int32_t)x*h->stride*16-(int32_t)h->stride*8;
   int32_t cy=(int32_t)((sy*h->stride+512u)>>10)+(int32_t)y*h->stride*16-(int32_t)h->stride*8;
   int32_t bw=(int32_t)(((uint64_t)sw*sw*h->anchors[anchor*2]+(1u<<23))>>24);
   int32_t bh=(int32_t)(((uint64_t)sh*sh*h->anchors[anchor*2+1]+(1u<<23))>>24);
   YoloBox b={cx-bw/2,cy-bh/2,cx+(bw+1)/2,cy+(bh+1)/2,(uint16_t)score,(uint8_t)label,0};
   if(!bw||!bh)continue;
   if(count>=6300)return 0;
   Candidate compact={(int16_t)b.x1,(int16_t)b.y1,(int16_t)b.x2,(int16_t)b.y2,b.score,b.label,0};
   candidates[count]=compact;sort_keys[count]=(score<<16)|(65535u-count);count++;
  }
 }
 for(uint32_t i=count/2u;i;i--)heap_sift(i-1u,count);
 for(uint32_t end=count;end>1;end--){uint32_t t=sort_keys[0];sort_keys[0]=sort_keys[end-1];sort_keys[end-1]=t;heap_sift(0,end-1);}
 uint32_t used=0;
 for(uint32_t cursor=count;cursor&&used<capacity;cursor--){
  const Candidate *c=&candidates[65535u-(sort_keys[cursor-1]&65535u)];YoloBox b={c->x1,c->y1,c->x2,c->y2,c->score,c->label,0};
  uint32_t suppressed=0;for(uint32_t j=0;j<used;j++)if(b.label==boxes[j].label&&overlap(&b,&boxes[j])){suppressed=1;break;}
  if(!suppressed)boxes[used++]=b;
 }
 return used;
}
