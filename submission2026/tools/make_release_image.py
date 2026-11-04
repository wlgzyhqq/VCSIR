"""Create a TF image from the exact compiled asset contract, never a physical disk."""
from pathlib import Path
import argparse,json,re,struct,zlib,hashlib
ap=argparse.ArgumentParser();ap.add_argument('--root',type=Path,required=True);ap.add_argument('--out',type=Path,required=True);a=ap.parse_args();r=a.root.resolve()
text=(r/'yolo/firmware/assets_contract.h').read_text();rows=re.findall(r'\{((?:0x[0-9a-f]+u,){7})"([^"]+)"\}',text)
old=json.loads((r/'yolo/assets/manifest.json').read_text()); paths={(x['kind'],x['index']):x['path'] for x in old['entries']};paths[(4,0)]='assets/video/frames.rgb565'
entries=[]
for row,name in rows:
 vals=[int(x.rstrip('u'),16) for x in row.rstrip(',').split(',')];kind,index,lba,size,dst,crc,dtype=vals;data=(r/'yolo'/paths[kind,index]).read_bytes();assert len(data)==size and zlib.crc32(data)==crc,(name,len(data),size)
 entries.append((vals,name,data))
assert len(entries)==18
end=max(v[2]*512+len(data) for v,n,data in entries);blob=bytearray((end+511)//512*512)
header=bytearray(4096);header[:8]=b'YOSD0001';struct.pack_into('<6I',header,8,1,4096,len(entries),8,entries[-1][0][5],160);header[32:64]=bytes.fromhex(old['model_sha256'])
for i,(v,name,data) in enumerate(entries):
 off=64+i*64;struct.pack_into('<8I',header,off,*v,0);header[off+32:off+64]=name.encode()[:31].ljust(32,b'\0');blob[v[2]*512:v[2]*512+len(data)]=data
struct.pack_into('<I',header,4092,zlib.crc32(header[:4092]));blob[2048*512:2056*512]=header
fw=(r/'yolo/output/inference-fw/demo.bin').read_bytes();assert zlib.crc32(fw)==0x56d0cd28
padded=fw+bytes((-len(fw))%32);h=bytearray(512);h[:8]=b'YOLBOOT1';struct.pack_into('<10I',h,8,1,512,2,len(fw),len(padded),65,0,0,zlib.crc32(fw),zlib.crc32(padded));h[48:80]=hashlib.sha256(fw).digest();struct.pack_into('<I',h,508,zlib.crc32(h[:508]));blob[64*512:65*512]=h;blob[65*512:65*512+len(padded)]=padded
a.out.parent.mkdir(parents=True,exist_ok=True);a.out.write_bytes(blob)
report=dict(bytes=len(blob),sha256=hashlib.sha256(blob).hexdigest(),firmware_crc32=f'{zlib.crc32(fw):08x}',directory_crc32=f'{zlib.crc32(header[:4092]):08x}',entries=18,video_frames=240,all_asset_crc_verified=True,physical_card_written=False)
a.out.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
