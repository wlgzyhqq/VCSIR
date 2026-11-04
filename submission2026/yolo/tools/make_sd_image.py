"""Build and verify a raw image FILE; never opens physical disk devices."""
from pathlib import Path
import struct,json,zlib,hashlib,argparse
ap=argparse.ArgumentParser();ap.add_argument('--firmware',default='output/firmware/demo.bin');ap.add_argument('--output-dir',default='output/sd');a=ap.parse_args()
R=Path(__file__).resolve().parents[1];m=json.loads((R/'assets/manifest.json').read_text());O=R/a.output_dir;assert O.resolve().is_relative_to(R);O.mkdir(parents=True,exist_ok=True)
image=bytearray(m['total_sectors']*512);image[2048*512:2056*512]=(R/'assets/directory.bin').read_bytes()
for e in m['entries']:
 d=(R/e['path']).read_bytes();assert len(d)==e['bytes'] and zlib.crc32(d)==e['crc32'];start=e['lba']*512;image[start:start+len(d)]=d
fw=(R/a.firmware).read_bytes();assert len(fw)%4==0 and len(fw)<=0x1e000;padded=fw+bytes((-len(fw))%32)
h=bytearray(512);h[:8]=b'YOLBOOT1';struct.pack_into('<10I',h,8,1,512,2,len(fw),len(padded),65,0,0,zlib.crc32(fw),zlib.crc32(padded));h[48:80]=hashlib.sha256(fw).digest();struct.pack_into('<I',h,508,zlib.crc32(h[:508]));image[64*512:65*512]=h;image[65*512:65*512+len(padded)]=padded
p=O/'final_yolo.img';p.write_bytes(image)
report=dict(sha256=hashlib.sha256(image).hexdigest(),bytes=len(image),firmware_sha256=hashlib.sha256(fw).hexdigest(),model_sha256=m['model_sha256'],assets=m['entries'],physical_card_written=False,board_verified=False,precomputed_boxes=False)
(O/'manifest.json').write_text(json.dumps(report,indent=2)+'\n');print('Prepared TF image',p,'bytes',len(image),'SHA256',report['sha256'])
