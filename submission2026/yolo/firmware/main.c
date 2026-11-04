#include "platform.h"
#include "storage.h"
#include "assets_contract.h"
#include "video_contract.h"
#ifdef YOLO_INFERENCE
#include "yolo_network.h"
static YoloBox detections[16];
static uint32_t detection_count,result_valid,inference_fatal,profile[85][3],last_prepare_ms,last_network_ms,last_decode_ms,last_mode;
static void run_inference(uint32_t verify);
/* Model output is Q4 in 160x160 network space; the panel shows the 320x320
   frame the network was downsampled from, so scale by two. */
static int32_t pixel_coordinate(int32_t x){x=(x+8)>>3;return x<0?0:(x>319?319:x);}
#endif
#define VID(n) REG(0x80007000u+((n)<<2))
static uint32_t image_index,display_mask,loaded_mask,back_page=1,storage_ok;
static uint32_t display_addr,video_asset=0xffffffffu,video_page,video_frame_index;
static uint8_t directory[4096];
static uint64_t now(void){uint32_t h,l,h2;do{h=MTIME_HI;l=MTIME_LO;h2=MTIME_HI;}while(h!=h2);return ((uint64_t)h<<32)|l;}
static uint32_t crcbyte(uint32_t c,uint8_t b){c^=b;for(uint32_t k=0;k<8;k++)c=(c>>1)^((0u-(c&1u))&0xedb88320u);return c;}
static void hex(uint32_t x){for(uint32_t i=8;i;i--)putchar_uart("0123456789abcdef"[(x>>((i-1)*4))&15]);}
static uint32_t word(const uint8_t *p){return p[0]|((uint32_t)p[1]<<8)|((uint32_t)p[2]<<16)|((uint32_t)p[3]<<24);}
static int wait_video(void){uint64_t t=now();while((VID(1)&1u)||!(VID(1)&2u))if(now()-t>CPU_CLOCK_HZ)return 0;return 1;}
static void text_line(uint32_t row,const char *s){
 volatile uint32_t *p=(volatile uint32_t *)(uintptr_t)(0x80010000u+back_page*0x4000u+row*40u*4u);
 uint32_t i=0;while(i<40u&&s[i]){p[i]=0x0f00u|(uint8_t)s[i];i++;}while(i<40u)p[i++]=0x0f20u;
}
#ifdef YOLO_INFERENCE
static void text_time(uint32_t row,const char *label,uint32_t ms){
 char line[41],digits[10];uint32_t used=0,n=0;
 while(*label&&used<22)line[used++]=*label++;
 do{digits[n++]=(char)('0'+ms%10);ms/=10;}while(ms&&n<10);
 while(n)line[used++]=digits[--n];
 line[used++]=' ';line[used++]='m';line[used++]='s';line[used]=0;text_line(row,line);
}
#endif
static void draw_boxes(void){
 if(!wait_video())return;
 back_page=(((VID(1)>>3)&1u)^1u);
 VID(8)=0;
#ifdef YOLO_INFERENCE
 if(result_valid){
  for(uint32_t i=0;i<detection_count;i++){
   const YoloBox *b=&detections[i];VID(9)=i;
   VID(10)=(uint32_t)pixel_coordinate(b->x1)|((uint32_t)pixel_coordinate(b->y1)<<16);
   VID(11)=(uint32_t)pixel_coordinate(b->x2)|((uint32_t)pixel_coordinate(b->y2)<<16);
   char line[41];const char *label=yolo_label(b->label);uint32_t used=0;
   while(label[used]&&used<29){line[used]=label[used];used++;}
   uint32_t percent=((uint32_t)b->score*100u+16384u)>>15;
   line[used++]=' ';if(percent==100){line[used++]='1';line[used++]='0';line[used++]='0';}
   else{line[used++]=(char)('0'+percent/10u);line[used++]=(char)('0'+percent%10u);}
   line[used++]='%';line[used]=0;text_line(23+i,line);
  }
  VID(8)=detection_count;
 }
#endif
}
static uint32_t panel_quiet;
static void screen(const char *state){
 /* Full-panel redraws re-point the display at the still image, so they are
    suppressed while the video player owns the frame base. */
 if(panel_quiet)return;
 if(!wait_video()){return;}
 back_page=(((VID(1)>>3)&1u)^1u);
 for(uint32_t y=0;y<45;y++)text_line(y,"");
 text_line(0,"RISC-V / FPGA YOLO TERMINAL");text_line(2,"YOLOv5n v7.0 - INT8 CNN");text_line(4,"320x320 INPUT, HDMI 720p");text_line(6,state);
#ifdef YOLO_INFERENCE
 text_line(8,"BOARD INT8 CNN / RV32IM CONTROL");text_line(9,"CPU RGB565 -> INT8/CHW");
 if(result_valid){text_time(20,"CPU PREP: ",last_prepare_ms);text_time(21,last_mode?"CNN+OPS+CRC: ":"CNN+OPS: ",last_network_ms);text_time(22,"DECODE+NMS: ",last_decode_ms);}
#else
 text_line(8,"IMAGE DISPLAY MILESTONE");text_line(9,"INFERENCE NOT CONNECTED YET");
#endif
 text_line(12,assets[image_index*2u].name);text_line(15,"KEY2: NEXT  KEY3: PREVIOUS");
 text_line(17,"TF -> CRC -> DDR -> HDMI");text_line(19,"UNANNOTATED IMAGE - NO STORED BOXES");
 draw_boxes();
 display_addr=assets[image_index*2u].dst;VID(3)=display_addr;fence_memory();VID(2)=4u|(back_page<<1)|((display_mask>>image_index)&1u);
}

static void info(void){
 puts_uart("@YOLO_INFO ");uint32_t v[]={1,IMAGE_COUNT,image_index,display_mask,loaded_mask,storage_ok,VID(1),VID(5),VID(6),VID(7),REG(0x80004000u)};
 for(uint32_t i=0;i<sizeof(v)/sizeof(v[0]);i++){hex(v[i]);putchar_uart(' ');}puts_uart("\r\n");
}
static int validate_directory(void){
 puts_uart("@YOLO_DIR_DUMP magic=");hex(word(directory));puts_uart(" entries=");hex(word(directory+16));
 puts_uart(" dim=");hex(word(directory+28));puts_uart(" sha=");hex((uint32_t)directory[32]);
 uint32_t crc=0xffffffffu;for(uint32_t i=0;i<4092;i++)crc=crcbyte(crc,directory[i]);
 puts_uart(" crc=");hex(crc^0xffffffffu);puts_uart(" stored=");hex(word(directory+4092));puts_uart("\r\n");
 static const char magic[]="YOSD0001";for(uint32_t i=0;i<8;i++)if(directory[i]!=(uint8_t)magic[i])return 0;
 uint32_t c=0xffffffffu;for(uint32_t i=0;i<4092;i++)c=crcbyte(c,directory[i]);if((c^0xffffffffu)!=word(directory+4092))return 0;
 if(word(directory+8)!=1 || word(directory+12)!=4096 || word(directory+16)!=ASSET_COUNT || word(directory+20)!=IMAGE_COUNT || word(directory+28)!=160){
  puts_uart("@YOLO_DIR_DIAG abi=");hex(word(directory+8));puts_uart(" len=");hex(word(directory+12));
  puts_uart(" entries=");hex(word(directory+16));puts_uart(" images=");hex(word(directory+20));
  puts_uart(" dim=");hex(word(directory+28));puts_uart(" expect=");hex((uint32_t)ASSET_COUNT);puts_uart("\r\n");return 0;}
 for(uint32_t i=0;i<32;i++)if(directory[32+i]!=model_sha[i])return 0;
 for(uint32_t i=0;i<ASSET_COUNT;i++){
  const Asset *a=&assets[i];uint32_t v[]={a->kind,a->index,a->lba,a->bytes,a->dst,a->crc,a->dtype,0};
  for(uint32_t j=0;j<8;j++)if(word(directory+64+i*64+j*4)!=v[j])return 0;
  if((uint64_t)a->lba+(((uint64_t)a->bytes+511)>>9)>storage_capacity())return 0;
 }
 return 1;
}
static int load_card(void){
 display_mask=0;loaded_mask=0;screen("LOADING CARD - IMAGE DISABLED");if(!wait_video())return 0;
 if(!storage_init()){puts_uart("@YOLO_CARD_ERROR init\r\n");return 0;}
 for(uint32_t i=0;i<8;i++)if(!storage_sector(2048+i,directory+i*512)){puts_uart("@YOLO_CARD_ERROR directory read\r\n");return 0;}
 if(!validate_directory()){puts_uart("@YOLO_CARD_ERROR version/length/CRC/model mismatch\r\n");return 0;}
 for(uint32_t i=0;i<ASSET_COUNT;i++){
  const Asset *a=&assets[i];uint64_t begun=now();
  if(a->kind==4){loaded_mask|=1u<<i;continue;} /* video frames load on demand */
  if(!storage_load(a->lba,a->bytes,a->dst,a->crc)){puts_uart("@YOLO_ASSET_FAIL ");hex(i);puts_uart("\r\n");return 0;}
  loaded_mask|=1u<<i;if(a->kind==1)display_mask|=1u<<a->index;
  puts_uart("@YOLO_ASSET_OK ");hex(i);putchar_uart(' ');hex(a->bytes);putchar_uart(' ');hex(a->crc);putchar_uart(' ');hex((uint32_t)(now()-begun));puts_uart("\r\n");
  if(i==0)screen("LOADING REMAINING ASSETS...");
 }
 return 1;
}
static uint32_t number(const char *s){uint32_t n=0;for(uint32_t i=0;s[i];i++){uint32_t d=(uint8_t)s[i];if(d>='0'&&d<='9')d-='0';else if(d>='a'&&d<='f')d=d-'a'+10;else if(d>='A'&&d<='F')d=d-'A'+10;else break;n=(n<<4)|d;}return n;}
static void select_image(uint32_t n){if(n<IMAGE_COUNT && (display_mask&(1u<<n))){image_index=n;
#ifdef YOLO_INFERENCE
 result_valid=0;
#endif
 screen("IMAGE READY - PIXEL PATH VERIFIED");info();
#ifdef YOLO_INFERENCE
 run_inference(0);
#endif
 }else puts_uart("@YOLO_IMAGE_NOT_LOADED\r\n");}
static void video_overlay(uint32_t k){
 char line[41];uint32_t used=0,n=0,digits[3];
 /* Sync the text page exactly like screen() does before touching it. */
 if(!wait_video())return;
 back_page=(((VID(1)>>3)&1u)^1u);
 const char *p="FRAME ";while(*p)line[used++]=*p++;
 uint32_t v=k+1u;do{digits[n++]=v%10u;v/=10u;}while(v&&n<3);
 for(uint32_t i=n;i;i--)line[used++]=(char)('0'+digits[i-1]);
 line[used++]='/';v=VIDEO_FRAME_COUNT;n=0;do{digits[n++]=v%10u;v/=10u;}while(v&&n<3);
 for(uint32_t i=n;i;i--)line[used++]=(char)('0'+digits[i-1]);
 line[used++]=' ';p=video_clips[video_frame_clip[k]];while(*p&&used<39)line[used++]=*p++;
 line[used]=0;text_line(13,line);
 text_line(16,"LIVE DETECTION 160x160 INT8");
}
static uint32_t video_begin(void){
 for(uint32_t i=0;i<ASSET_COUNT;i++)if(assets[i].kind==4){video_asset=i;break;}
 if(video_asset==0xffffffffu)return 0;
 video_page=0;video_frame_index=0;
 return 1;
}
static void play_video(uint32_t frames){
 if(video_asset==0xffffffffu){puts_uart("@YOLO_NO_VIDEO\r\n");return;}
 panel_quiet=1;
 const Asset *a=&assets[video_asset];
 uint32_t sectors=VIDEO_FRAME_BYTES/512u;
 puts_uart("@YOLO_VIDEO_BEGIN ");hex(VIDEO_FRAME_COUNT);puts_uart("\r\n");
 for(uint32_t k=0;;k++){
  if(k>=frames)k=0; /* reel loops until the operator stops it */
  uint32_t index=frames==VIDEO_FRAME_COUNT?k:(video_frame_index%VIDEO_FRAME_COUNT);
  uint32_t addr=0x38200000u+(video_page<<18);
  video_page^=1u;video_frame_index=index+1u;
  if(!storage_load_fast(a->lba+index*sectors,VIDEO_FRAME_BYTES,addr,video_frame_crc[index])){
   puts_uart("@YOLO_VIDEO_LOAD_FAIL\r\n");screen("VIDEO FRAME CRC ERROR");return;}
  /* The video module only accepts a control write while the configuration
     channel is idle; without this wait the new frame base is never latched. */
  /* Infer on the freshly loaded buffer first, then hand it to the display at
     the same instant its boxes become valid. Otherwise the panel shows a new
     frame carrying the previous frame's boxes. */
  display_addr=addr;
  run_inference(0);
  /* Boxes first: the video core latches box_count together with the frame
     base when the configuration is accepted, so writing them afterwards would
     show the previous frame's count. */
  draw_boxes();
  if(!wait_video())return;
  for(uint32_t tries=0;tries<64u;tries++){VID(3)=addr;fence_memory();if(VID(3)==addr)break;}
  fence_memory();VID(2)=4u|(back_page<<1)|1u; /* per-frame boxes; the full panel stays suppressed */
  if((index%10u)==0u)video_overlay(index);
  if(UART_STATUS&2u){uint32_t c=UART_DATA&255u;if(c=='x'||c=='X'){panel_quiet=0;puts_uart("@YOLO_VIDEO_STOP\r\n");return;}}
 }
 panel_quiet=0;puts_uart("@YOLO_VIDEO_END\r\n");
}
static void upload(uint32_t id){
 if(id>=ASSET_COUNT){puts_uart("@YOLO_BAD_ASSET\r\n");return;}const Asset *a=&assets[id];
#ifdef YOLO_INFERENCE
 result_valid=0;
#endif
 if(a->kind==1 && a->index==image_index){display_mask&=~(1u<<image_index);screen("UPLOADING IMAGE - WAIT CRC");if(!wait_video())return;}
 puts_uart("@YOLO_UP_READY ");hex(id);putchar_uart(' ');hex(a->bytes);puts_uart("\r\n");uint32_t c=0xffffffffu;
 for(uint32_t i=0;i<a->bytes;i++){
  uint64_t t=now();while(!(UART_STATUS&2u))if(now()-t>(CPU_CLOCK_HZ*3u)){puts_uart("@YOLO_UP_TIMEOUT\r\n");return;}
  if(UART_STATUS&12u){puts_uart("@YOLO_UP_UART_ERROR\r\n");return;}
  uint8_t b=(uint8_t)UART_DATA;*(volatile uint8_t *)(uintptr_t)(a->dst+i)=b;c=crcbyte(c,b);
 }
 if((c^0xffffffffu)!=a->crc||!storage_crc(a->dst,a->bytes,a->crc)){puts_uart("@YOLO_UP_CRC_FAIL\r\n");return;}
 loaded_mask|=1u<<id;if(a->kind==1)display_mask|=1u<<a->index;
 screen("UART ASSET CRC VERIFIED");puts_uart("@YOLO_UP_OK ");hex(id);puts_uart("\r\n");
}
#ifdef YOLO_INFERENCE
static void progress(uint32_t node,uint32_t total,uint32_t ticks,uint32_t crc){
 (void)total;if(node&&node<=85){profile[node-1][0]=node;profile[node-1][1]=ticks;profile[node-1][2]=crc;}
}
static void run_inference(uint32_t mode){
 if(inference_fatal){puts_uart("@YOLO_FATAL_RESET_REQUIRED\r\n");return;}
 uint32_t verify=mode!=0,stored_input=mode==1;
 uint32_t required=(1u<<(ASSET_COUNT-1u))|(display_addr==assets[image_index*2u].dst?(1u<<(image_index*2u+stored_input)):0u);
 if((loaded_mask&required)!=required){puts_uart("@YOLO_NETWORK_ASSETS_MISSING\r\n");return;}
 result_valid=0;detection_count=0;screen("RUNNING CNN... PLEASE WAIT");
 uint32_t input=assets[image_index*2u+1u].dst,prepare_ticks=0;
 if(!stored_input){
  input=0x02800000u;uint64_t began=now();uint32_t error=yolo_prepare_rgb565(display_addr,input);prepare_ticks=(uint32_t)(now()-began);
  if(error){puts_uart("@YOLO_PREPARE_ERROR\r\n");screen("IMAGE PREPROCESS ERROR");return;}
 }
 uint32_t input_bytes=yolo_input_bytes();
  uint32_t input_crc=verify?yolo_tensor_crc(input,input_bytes):0;
 puts_uart("@YOLO_PREPARE ");uint32_t prep[]={image_index,mode,prepare_ticks,input_crc,input};for(uint32_t j=0;j<5;j++){hex(prep[j]);putchar_uart(' ');}puts_uart("\r\n");
 puts_uart("@YOLO_INFER_BEGIN ");hex(image_index);putchar_uart(' ');hex(mode);puts_uart("\r\n");
 uint64_t began=now();uint32_t error=yolo_infer(input,progress,verify);uint64_t elapsed=now()-began;
 if(error){inference_fatal=1;puts_uart("@YOLO_INFER_ERROR ");hex(error);puts_uart(" RESET REQUIRED\r\n");screen("CNN ERROR - RESET REQUIRED");return;}
 uint64_t decode_begin=now();detection_count=yolo_detect(detections,16);uint32_t decode_ticks=(uint32_t)(now()-decode_begin);result_valid=1;
 last_prepare_ms=prepare_ticks/(CPU_CLOCK_HZ/1000u);last_network_ms=(uint32_t)(elapsed/(CPU_CLOCK_HZ/1000u));last_decode_ms=decode_ticks/(CPU_CLOCK_HZ/1000u);last_mode=mode;
 puts_uart("@YOLO_RESULT ");hex(image_index);putchar_uart(' ');hex((uint32_t)elapsed);putchar_uart(' ');hex((uint32_t)(elapsed>>32));putchar_uart(' ');hex(decode_ticks);putchar_uart(' ');hex(detection_count);putchar_uart(' ');hex(mode);putchar_uart(' ');hex(prepare_ticks);puts_uart("\r\n");
 for(uint32_t i=0;i<detection_count;i++){
  const YoloBox *b=&detections[i];uint32_t values[]={image_index,b->label,b->score,(uint32_t)b->x1,(uint32_t)b->y1,(uint32_t)b->x2,(uint32_t)b->y2};puts_uart("@YOLO_BOX ");
  for(uint32_t j=0;j<7;j++){hex(values[j]);putchar_uart(' ');}puts_uart(yolo_label(b->label));puts_uart("\r\n");
 }
 if(verify)for(uint32_t i=0;i<85;i++){
  puts_uart("@YOLO_LAYER ");for(uint32_t j=0;j<3;j++){hex(profile[i][j]);putchar_uart(' ');}puts_uart("\r\n");
 }
 screen("DETECTION COMPLETE");puts_uart("@YOLO_RESULT_READY\r\n");
}
#endif
int main(void){
 GPIO_DIR=3;GPIO_OUT=0x4300;UART_CONTROL=15;
#ifdef YOLO_INFERENCE
 puts_uart("\r\n@YOLO_BOOT INTEGER CNN INFERENCE v2\r\n");
 puts_uart("@YOLO_HW ");hex(UART_CLOCK_HZ);putchar_uart(' ');
 hex(REG(0x8000405cu));putchar_uart(' ');hex(REG(0x80004058u));puts_uart("\r\n");
#else
 puts_uart("\r\n@YOLO_BOOT IMAGE MILESTONE v1 - NO INFERENCE CLAIM\r\n");
#endif
 screen("INITIALIZING TF CARD...");storage_ok=load_card();screen(storage_ok?"TF ASSETS VERIFIED":"CARD ERROR - UART RECOVERY AVAILABLE");info();puts_uart("@YOLO_READY\r\n");
#ifdef YOLO_INFERENCE
 if(storage_ok)run_inference(0);
 if(storage_ok&&video_begin())play_video(VIDEO_FRAME_COUNT);
#endif
 char line[80];uint32_t used=0,last_keys=0;uint64_t key_time=0;
 for(;;){
  uint32_t keys=(GPIO_IN>>8)&3u;
  if(keys && !last_keys && now()-key_time>(CPU_CLOCK_HZ/5u)){key_time=now();select_image(keys&1u?(image_index+1u)%IMAGE_COUNT:(image_index+IMAGE_COUNT-1u)%IMAGE_COUNT);}last_keys=keys;
  if(UART_STATUS&2u){uint32_t c=UART_DATA&255u;
   if(c=='\r'||c=='\n'){
    if(used){line[used]=0;
#ifdef YOLO_INFERENCE
     if(line[0]=='g'||line[0]=='v'||line[0]=='w'){run_inference(line[0]=='v'?1:(line[0]=='w'?2:0));used=0;continue;}
     if(line[0]=='r')result_valid=0;
#endif
     if(line[0]=='i')info();else if(line[0]=='n')select_image((image_index+1u)%IMAGE_COUNT);else if(line[0]=='p')select_image((image_index+IMAGE_COUNT-1u)%IMAGE_COUNT);else if(line[0]=='s')select_image(number(line+1));else if(line[0]=='u')upload(number(line+1));else if(line[0]=='r'){storage_ok=load_card();screen(storage_ok?"TF ASSETS VERIFIED":"CARD LOAD ERROR");info();}else if(line[0]=='m')play_video(VIDEO_FRAME_COUNT);else if(line[0]=='d'){puts_uart("@YOLO_VDEC status=");hex(VID(1));puts_uart(" base=");hex(VID(3));puts_uart(" frames=");hex(VID(5));puts_uart(" underflow=");hex(VID(6));puts_uart(" rejected=");hex(VID(7));puts_uart("\r\n");}else puts_uart("@YOLO_COMMAND_ERROR\r\n");used=0;}
   }else if(used<sizeof(line)-1)line[used++]=(char)c;
  }
 }
}
