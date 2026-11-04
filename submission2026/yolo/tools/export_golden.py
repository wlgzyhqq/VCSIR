"""Full per-operator raw reference files; test data stays on PC, not on TF."""
from yolo_quantize import R,Quant,image_input,np
import json,zlib,hashlib
O=R/'model/golden';O.mkdir(exist_ok=True)
ref=R/'model/reference';g=json.loads((ref/'graph.json').read_text());cal=json.loads((ref/'calibration.json').read_text());fw=dict(np.load(ref/'float_weights.npz'))
q=Quant(g,cal,fw);frozen=json.loads((R/'model/quantized/model.json').read_text());assert hashlib.sha256(q.blob).hexdigest()==frozen['weights_sha256']
path=R/'third_party/yolov5/data/images/bus.jpg';_,x,_=image_input(path);values,_=q.run(x)
rows=[]
for i,v in values.items():
    data=v.astype('<i2' if v.dtype.itemsize==2 else np.int8).tobytes();p=O/f'tensor-{i:03d}.bin';p.write_bytes(data)
    rows.append(dict(id=i,address=q.addresses[i],shape=list(v.shape),bits=v.dtype.itemsize*8,bytes=len(data),crc32=f'{zlib.crc32(data):08x}',sha256=hashlib.sha256(data).hexdigest(),file=p.name))
    if i:print('golden tensor',i,len(data),flush=True)
report=dict(input_image=str(path.relative_to(R)),weights_sha256=frozen['weights_sha256'],tensors=rows,board_verified=False)
(O/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
print('Exported all',len(values),'tensors including input; no golden outputs added to card')
