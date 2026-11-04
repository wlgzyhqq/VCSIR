"""Independent parser for a regular image FILE, never a physical card writer."""
from pathlib import Path
import struct, zlib, hashlib, json,argparse

R = Path(__file__).resolve().parents[1]
def verify(path,firmware_path=None):
    path = Path(path).resolve()
    assert path.is_file() and path.suffix == '.img'
    data = path.read_bytes()
    u32 = lambda p, o: struct.unpack_from('<I', p, o)[0]
    h = data[64*512:65*512]
    assert h[:8] == b'YOLBOOT1' and zlib.crc32(h[:508]) == u32(h,508)
    assert [u32(h,i) for i in (8,12,16,28,32,36)] == [1,512,2,65,0,0]
    n, padded = u32(h,20), u32(h,24)
    assert 0 < n <= 0x1e000 and n%4 == 0 and padded == (n+31)&~31
    fw = data[65*512:65*512+n]
    assert zlib.crc32(fw) == u32(h,40)
    assert zlib.crc32(data[65*512:65*512+padded]) == u32(h,44)
    assert hashlib.sha256(fw).digest() == h[48:80] and not any(h[80:508])
    assert fw == (Path(firmware_path) if firmware_path else R/'output/firmware/demo.bin').read_bytes()
    d = data[2048*512:2056*512]
    assert d[:8] == b'YOSD0001' and zlib.crc32(d[:4092]) == u32(d,4092)
    assert u32(d,8)==1 and u32(d,12)==4096 and u32(d,28)==160
    manifest=json.loads((R/'assets/manifest.json').read_text())
    assert u32(d,16)==len(manifest['entries']) and u32(d,20)==manifest['image_count']
    assert d[32:64].hex() == manifest['model_sha256']
    disk=[(64*512,65*512+padded),(2048*512,2056*512)]
    memory=[]; results=[]
    for i, e in enumerate(manifest['entries']):
        kind,index,lba,size,dst,crc,dtype,reserved=struct.unpack_from('<8I',d,64+i*64)
        assert [kind,index,lba,size,dst,crc,dtype,reserved] == [e[k] for k in ('kind','index','lba','bytes','dst','crc32','dtype')]+[0]
        assert lba>=4096 and lba%8==0 and size>0 and dst%32==0
        end=lba*512+size; assert end<=len(data)
        content=data[lba*512:end]
        assert zlib.crc32(content)==crc and content==(R/e['path']).read_bytes()
        if kind==1: assert size==320*320*2 and dtype==1
        elif kind==2: assert size==160*160*3 and dtype==2
        elif kind==4: assert dtype==4 and size%204800==0
        else: assert kind==3 and hashlib.sha256(content).digest()==d[32:64]
        disk.append((lba*512,end))
        if kind!=4: memory.append((dst,dst+size))  # video streams from card, not resident
        results.append(dict(index=i,bytes=size,crc32=f'{crc:08x}',passed=True))
    for ranges in (disk,memory):
        s=sorted(ranges)
        assert all(a[1]<=b[0] for a,b in zip(s,s[1:])), 'Overlapping regions'
    assert not any(data[:512]), 'Raw format: sector 0 must be blank'
    return dict(passed=True,image=str(path),sha256=hashlib.sha256(data).hexdigest(),bytes=len(data),
                assets=results,physical_card_verified=False,board_verified=False,
                note='File integrity only; not evidence of a successful physical-card write or inference.')
if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--image',default='output/sd/final_yolo.img');ap.add_argument('--firmware',default='output/firmware/demo.bin');a=ap.parse_args()
    result=verify(R/a.image,R/a.firmware)
    (Path(result['image']).parent/'verification.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='assets'},indent=2))
