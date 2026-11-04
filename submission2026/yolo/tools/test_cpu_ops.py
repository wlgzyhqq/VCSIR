"""Run production C pointwise/decoder on Windows with exact DDR virtual addresses."""
from pathlib import Path
import ctypes as C,json,subprocess,os,zlib,zipfile,struct,ast
R=Path(__file__).resolve().parents[1];O=R/'output/reference';O.mkdir(exist_ok=True)
env=dict(os.environ);env['PATH']='C:/msys64/ucrt64/bin'+os.pathsep+env.get('PATH','')
subprocess.run(['C:/msys64/ucrt64/bin/gcc.exe','-shared','-O2','-DYOLO_HOST_TEST','-Wall','-Wextra','-Werror','-Wl,--export-all-symbols','firmware/yolo_network.c','firmware/yolo_preprocess.c','-o',str(O/'yolo_cpu.dll')],cwd=R,env=env,check=True)
k=C.WinDLL('kernel32',use_last_error=True);k.VirtualAlloc.argtypes=[C.c_void_p,C.c_size_t,C.c_ulong,C.c_ulong];k.VirtualAlloc.restype=C.c_void_p
k.VirtualFree.argtypes=[C.c_void_p,C.c_size_t,C.c_ulong];k.VirtualFree.restype=C.c_int
regions=[]
try:
    for address,size in [(0x02000000,0x100000),(0x04000000,0x400000),(0x08000000,0x1000000)]:
        got=k.VirtualAlloc(address,size,0x3000,4)
        if got!=address:raise C.WinError(C.get_last_error())
        regions.append(address)
    m=json.loads((R/'model/quantized/model.json').read_text());g=json.loads((R/'model/golden/manifest.json').read_text());expected={}
    for t in g['tensors']:
        b=(R/'model/golden'/t['file']).read_bytes();assert zlib.crc32(b)==int(t['crc32'],16);expected[t['id']]=b;C.memmove(t['address'],b,len(b))
    b=(R/'model/quantized/weights.bin').read_bytes();C.memmove(0x04000000,b,len(b))
    dll=C.CDLL(str(O/'yolo_cpu.dll'));dll.yolo_test_pointwise.argtypes=[C.c_uint32,C.c_uint32];dll.yolo_test_pointwise.restype=C.c_uint32
    rows=[]
    for i,n in enumerate(m['nodes']):
        if n['op']=='conv':continue
        address=n['address'];data=expected[n['id']];C.memset(address-32,0xa5,len(data)+64)
        code=dll.yolo_test_pointwise(i,0x02000000);assert code==0,(n['id'],code)
        got=C.string_at(address,len(data));assert got==data,(n['id'],next((j for j,(a,b) in enumerate(zip(got,data)) if a!=b),None))
        assert C.string_at(address-32,32)==bytes([0xa5])*32 and C.string_at(address+len(data),32)==bytes([0xa5])*32
        rows.append(dict(id=n['id'],op=n['op'],bytes=len(data),crc32=f'{zlib.crc32(got):08x}',passed=True))
    # Exercise every RGB565 value at least once, with packed32 reads/writes.
    packed=b''.join(struct.pack('<H',i%65536) for i in range(102400));C.memmove(0x02080000,packed,len(packed))
    dll.yolo_prepare_rgb565.argtypes=[C.c_uint32,C.c_uint32];dll.yolo_prepare_rgb565.restype=C.c_uint32
    assert dll.yolo_prepare_rgb565(0x02080000,0x02000000)==0
    ref=[bytearray(),bytearray(),bytearray()]
    for i in range(102400):
        p=i%65536;r5=p>>11;g6=(p>>5)&63;b5=p&31
        for buf,c in zip(ref,[(r5<<3)|(r5>>2),(g6<<2)|(g6>>4),(b5<<3)|(b5>>2)]):buf.append(round(c*127/255))
    assert C.string_at(0x02000000,307200)==b''.join(ref)
    assert dll.yolo_prepare_rgb565(0x02000000,0x02000000)==2
    class Box(C.Structure):_fields_=[('x1',C.c_int32),('y1',C.c_int32),('x2',C.c_int32),('y2',C.c_int32),('score',C.c_uint16),('label',C.c_uint8),('reserved',C.c_uint8)]
    dll.yolo_detect.argtypes=[C.POINTER(Box),C.c_uint32];dll.yolo_detect.restype=C.c_uint32
    boxes=(Box*16)();count=dll.yolo_detect(boxes,16)
    detections=[dict(xyxy_q4=[b.x1,b.y1,b.x2,b.y2],score_q15=b.score,label=b.label) for b in boxes[:count]]
    q=json.loads((R/'model/quantized/quantization-report.json').read_text());fp=next(i for i in q['images'] if i['name']=='bus.jpg')['quantized']
    assert len(fp)==len(detections),(fp,detections)
    errors=[]
    for a,b in zip(fp,detections):
        pixel_error=max(abs(x-y/16) for x,y in zip(a[:4],b['xyxy_q4']));score_error=abs(a[4]-b['score_q15']/32768)
        # Conservative analytic envelope: sigmoid error <=1/2048+1/32768,
        # then Q4 coordinates, max anchor373 and stride32. NMS decisions at
        # thresholds can still change; this image test is not an mAP claim.
        assert int(a[5])==b['label'] and pixel_error<1.0 and score_error<.0011,(a,b)
        errors.append(dict(pixel_error=pixel_error,score_error=score_error))
    image_checks=[];byid={n['id']:n for n in m['nodes']}
    for item in q['images']:
        with zipfile.ZipFile(R/'model/quantized'/(Path(item['name']).stem+'-heads.npz')) as z:
            for i,h in enumerate(m['heads']):
                raw=z.read(f'head{i}.npy');assert raw[:8]==b'\x93NUMPY\x01\x00'
                header_size=struct.unpack_from('<H',raw,8)[0];header=ast.literal_eval(raw[10:10+header_size].decode())
                assert header['descr']=='<i2' and not header['fortran_order']
                data=raw[10+header_size:];assert len(data)==byid[h]['bytes'];C.memmove(byid[h]['address'],data,len(data))
        outputs=(Box*100)();n=dll.yolo_detect(outputs,100);assert n==len(item['quantized']),(item['name'],n,len(item['quantized']))
        remaining=list(outputs[:n]);max_pixel=0.;max_score=0.
        for ref in item['quantized']:
            choices=[(max(abs(float(x)-y/16) for x,y in zip(ref[:4],[b.x1,b.y1,b.x2,b.y2])),i,b) for i,b in enumerate(remaining) if b.label==int(ref[5])]
            assert choices,item['name'];pixel_error,i,b=min(choices,key=lambda p:p[0]);score_error=abs(float(ref[4])-b.score/32768)
            assert pixel_error<1 and score_error<.0011,(item['name'],ref,pixel_error,score_error)
            remaining.pop(i);max_pixel=max(max_pixel,pixel_error);max_score=max(max_score,score_error)
        image_checks.append(dict(name=item['name'],boxes=n,max_coordinate_error=max_pixel,max_score_error=max_score,passed=True))
    rgb_checks=[];rgb_refs=json.loads((R/'model/golden-rgb565/manifest.json').read_text())
    for item in rgb_refs['images']:
        tensors={t['id']:t for t in item['tensors']}
        for h in m['heads']:
            data=(R/'model/golden-rgb565'/tensors[h]['file']).read_bytes();C.memmove(byid[h]['address'],data,len(data))
        outputs=(Box*100)();n=dll.yolo_detect(outputs,100);remaining=list(outputs[:n]);assert n==len(item['detections']),(item['name'],n,len(item['detections']))
        max_pixel=0.;max_score=0.
        for ref in item['detections']:
            choices=[(max(abs(float(x)-y/16) for x,y in zip(ref[:4],[b.x1,b.y1,b.x2,b.y2])),i,b) for i,b in enumerate(remaining) if b.label==int(ref[5])]
            assert choices,item['name'];err,i,b=min(choices,key=lambda p:p[0]);score_err=abs(float(ref[4])-b.score/32768)
            assert err<1 and score_err<.0011,(item['name'],ref,err,score_err);remaining.pop(i);max_pixel=max(max_pixel,err);max_score=max(max_score,score_err)
        rgb_checks.append(dict(index=item['index'],name=item['name'],boxes=n,max_coordinate_error=max_pixel,max_score_error=max_score,passed=True))
    # All 6300 anchors pass objectness; exercise the full candidate capacity.
    for h in m['heads']:
        node=byid[h];_,hh,ww=node['shape'];plane=hh*ww;raw=bytearray(b'\x00\x80'*(node['bytes']//2))
        for anchor in range(3):
            base=anchor*85*plane*2;raw[base:base+4*plane*2]=bytes(4*plane*2)
            raw[base+4*plane*2:base+6*plane*2]=b'\xff\x7f'*(2*plane)
        C.memmove(node['address'],bytes(raw),len(raw))
    outputs=(Box*100)();assert dll.yolo_detect(outputs,100)==100
    for h in m['heads']:
        node=byid[h];C.memmove(node['address'],b'\x00\x80'*(node['bytes']//2),node['bytes'])
    assert dll.yolo_detect(outputs,100)==0
    import hashlib
    dependencies=['firmware/yolo_network.c','firmware/yolo_network.h','firmware/yolo_preprocess.c','firmware/model_tables.h','firmware/platform.h','tools/test_cpu_ops.py','model/quantized/model.json','model/golden-rgb565/manifest.json']
    (O/'cpu-operators.json').write_text(json.dumps(dict(passed=True,board_verified=False,source_sha256={p:hashlib.sha256((R/p).read_bytes()).hexdigest() for p in dependencies},operators=rows,all_65536_RGB565_colours=True,detections=detections,reference_boxes=fp,decode_errors=errors,images=image_checks,RGB565_images=rgb_checks,stress_all_6300_candidates=True,empty_output=True,coordinate_error_envelope_pixels=1.0,score_error_envelope=.0011),indent=2)+'\n')
    print('PASS production C:',len(rows),'pointwise operators bit-exact;',count,'integer-decoded boxes; max coordinate error',max(e['pixel_error'] for e in errors),'pixels; max score error',max(e['score_error'] for e in errors))
    print('PASS',len(image_checks),'image decodes, all6300 candidate stress, and empty output')
    print('PASS',len(rgb_checks),'production RGB565 image decodes')
finally:
    for p in regions:k.VirtualFree(p,0,0x8000)
