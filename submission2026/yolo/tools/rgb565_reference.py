"""Production input: displayed RGB565 -> CPU expansion/Q7 CHW -> frozen CNN.
Keep the original8-bit input reference separate; report colour conversion effect.
"""
from yolo_quantize import R,Quant,Graph,torch,np,non_max_suppression,iou
from net_input import board_input_int8
import json,zlib,hashlib,time
O=R/'model/golden-rgb565';O.mkdir(exist_ok=True)
ref=R/'model/reference';g=json.loads((ref/'graph.json').read_text());cal=json.loads((ref/'calibration.json').read_text());fw=dict(np.load(ref/'float_weights.npz'))
q=Quant(g,cal,fw);m=json.loads((R/'model/quantized/model.json').read_text());assert hashlib.sha256(q.blob).hexdigest()==m['weights_sha256']
decode=object.__new__(Graph);decode.heads=g['heads'];decode.detect=g['detect']
assets=json.loads((R/'assets/manifest.json').read_text());original=json.loads((R/'model/quantized/quantization-report.json').read_text());byname={i['name']:i['quantized'] for i in original['images']}
images=[]
for image in assets['images']:
    began=time.perf_counter();path=R/image['display'];packed=path.read_bytes();p=np.frombuffer(packed,dtype='<u2').reshape(320,320)
    x=torch.from_numpy(board_input_int8(p).astype(np.float32)/127.0).unsqueeze(0)
    values,_=q.run(x);out=O/f"image-{image['index']}";out.mkdir(exist_ok=True)
    tensors=[]
    for ident,v in values.items():
        if image['index']!=0 and ident not in g['heads']:continue
        raw=v.astype('<i2' if v.dtype.itemsize==2 else np.int8).tobytes();f=out/f'tensor-{ident:03d}.bin';f.write_bytes(raw)
        tensors.append(dict(id=ident,address=q.addresses[ident],bytes=len(raw),crc32=f'{zlib.crc32(raw):08x}',sha256=hashlib.sha256(raw).hexdigest(),file=str(f.relative_to(O))))
    det=non_max_suppression(decode.decode({h:torch.from_numpy(values[h]).float()/1024 for h in g['heads']}),.25,.45,max_det=100)[0].numpy()
    before=byname[image['source'].replace('\\','/').split('/')[-1]]
    match=[]
    for old in before:
        choices=[iou(np.asarray(old),d) for d in det if int(d[5])==int(old[5])];match.append(max(choices) if choices else 0)
    row=dict(index=image['index'],name=image['source'].replace('\\','/').split('/')[-1],RGB565_crc32=f'{zlib.crc32(packed):08x}',tensors=tensors,detections=det.tolist(),original_quantized_detections=before,original_best_IoUs=match,reference_seconds=time.perf_counter()-began)
    images.append(row);print('RGB565 production reference',image['index'],'boxes',len(before),'->',len(det),'seconds',round(row['reference_seconds'],2),flush=True)
report=dict(weights_sha256=m['weights_sha256'],input_contract='320x320 unannotated RGB565 LE display; expand5/6 by replication, 2x2 box average to 160x160, round(v*127/255); signed8 NCHW',images=images,board_verified=False,independent_COCO_validation=False)
(O/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
print('Production RGB565 references complete; original8-bit golden set unchanged')
