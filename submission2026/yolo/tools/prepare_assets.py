"""Prepare raw unannotated display/input assets; never stores detector boxes."""
from yolo_reference import R,image_input,np
from net_input import board_input_int8
import json,zlib,hashlib,struct
Q=json.loads((R/'model/quantized/model.json').read_text());O=R/'assets/images';O.mkdir(exist_ok=True)
paths=list((R/'third_party/yolov5/data/images').glob('*.jpg'))+sorted((R/'model/datasets/coco128/images/train2017').glob('*.jpg'))[64:70]
entries=[];lba=4096;images=[]
def add(path,kind,index,dst,name,dtype):
 global lba
 data=path.read_bytes();lba=(lba+7)&~7
 e=dict(path=path.relative_to(R).as_posix(),kind=kind,index=index,lba=lba,bytes=len(data),dst=dst,crc32=zlib.crc32(data),dtype=dtype,name=name,sha256=hashlib.sha256(data).hexdigest())
 entries.append(e);lba+=(len(data)+511)//512;return e
for i,path in enumerate(paths):
 rgb,x,prep=image_input(path,size=320);a=rgb.astype(np.uint16);packed=((a[:,:,0]>>3)<<11)|((a[:,:,1]>>2)<<5)|(a[:,:,2]>>3)
 display=O/(path.stem+'.rgb565.bin');display.write_bytes(packed.astype('<u2').tobytes())
 inp=O/(path.stem+'.i8.bin');inp.write_bytes(board_input_int8(packed).tobytes())
 d=add(display,1,i,0x38000000+i*0x40000,path.stem,1);q=add(inp,2,i,0x02000000+i*0x80000,path.stem,2)
 images.append(dict(index=i,source=path.relative_to(R).as_posix(),preprocess=prep,display=d['path'],input=q['path']))
add(R/'model/quantized/weights.bin',3,0,0x04000000,'yolov5n-int8',3)
video_meta=None
vp=R/'assets/video/frames.rgb565'
if vp.exists():
    vm=json.loads((R/'assets/video/manifest.json').read_text())
    video_meta=vm
    add(vp,4,0,0,'video',4)
assert len(entries)<=32 and len(images)<=15
header=bytearray(4096);header[:8]=b'YOSD0001';struct.pack_into('<6I',header,8,1,4096,len(entries),len(images),entries[-1]['crc32'],160);header[32:64]=bytes.fromhex(Q['weights_sha256'])
for i,e in enumerate(entries):
 off=64+i*64;struct.pack_into('<8I',header,off,e['kind'],e['index'],e['lba'],e['bytes'],e['dst'],e['crc32'],e['dtype'],0);header[off+32:off+64]=e['name'].encode('ascii')[:31].ljust(32,b'\0')
struct.pack_into('<I',header,4092,zlib.crc32(header[:4092]));(R/'assets/directory.bin').write_bytes(header)
manifest=dict(ABI=1,image_count=len(images),images=images,entries=entries,total_sectors=lba,model_sha256=Q['weights_sha256'],preprocessing='Official v7 letterbox320, RGB, CHW signed8 round(rgb/255*127); display same unannotated input RGB565 LE',precomputed_boxes_in_card=False)
(R/'assets/manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
c=['#ifndef YOLO_ASSETS_CONTRACT_H','#define YOLO_ASSETS_CONTRACT_H','#include <stdint.h>',f'#define IMAGE_COUNT {len(images)}u',f'#define ASSET_COUNT {len(entries)}u','typedef struct {uint32_t kind,index,lba,bytes,dst,crc,dtype; const char *name;} Asset;', 'static const Asset assets[ASSET_COUNT]={']
for e in entries:c.append('{'+','.join(f'0x{e[k]:08x}u' for k in ['kind','index','lba','bytes','dst','crc32','dtype'])+',"'+e['name']+'"},')
c+=['};','static const uint8_t model_sha[32]={'+','.join('0x'+Q['weights_sha256'][i:i+2] for i in range(0,64,2))+'};','#endif'];(R/'firmware/assets_contract.h').write_text('\n'.join(c)+'\n')
if video_meta:
    clips=video_meta['clips']; crcs=[int(f['crc32'],16) for f in video_meta['frames']]
    clipidx=[clips.index(f['clip']) for f in video_meta['frames']]
    h=['#ifndef YOLO_VIDEO_CONTRACT_H','#define YOLO_VIDEO_CONTRACT_H','#include <stdint.h>',
       f"#define VIDEO_FRAME_COUNT {video_meta['frame_count']}u",
       f"#define VIDEO_FRAME_BYTES {video_meta['frame_bytes']}u",
       f"#define VIDEO_SIZE {video_meta['size']}u",
       f"#define VIDEO_CLIP_COUNT {len(clips)}u",
       'static const char *const video_clips[]={'+','.join('"%s"'%c for c in clips)+'};',
       'static const unsigned char video_frame_clip[]={'+','.join(str(c) for c in clipidx)+'};',
       'static const unsigned int video_frame_crc[]={'+','.join('0x%08xu'%c for c in crcs)+'};',
       '#endif']
    (R/'firmware/video_contract.h').write_text('\n'.join(h)+'\n')
print('Prepared',len(images),'unannotated image pairs and weights;',lba*512,'byte card image; no boxes included')
