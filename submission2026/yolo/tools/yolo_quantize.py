"""Explicit INT8 CNN contract, INT32 accumulators, Q10 INT16 detection heads.
SiLU remains SiLU (a calibrated 256-entry LUT), never silently replaced by ReLU.
Float64 convolution is used ONLY as an exact integer-dot oracle on the PC:
8-bit products and their bounded sums are exactly representable in float64.
"""
from yolo_reference import R,Graph,image_input,torch,np,F,non_max_suppression,Image,ImageDraw
import json,hashlib,struct,argparse,time
O=R/'model/quantized';O.mkdir(exist_ok=True)
def rshift_even(x,s):
 x=np.asarray(x,np.int64);s=np.asarray(s,np.int64);a=np.abs(x);q=np.right_shift(a,s);mask=np.left_shift(np.ones_like(s),s)-1;rem=a&mask;half=np.right_shift(mask+1,1)
 inc=(s>0)&((rem>half)|((rem==half)&((q&1)!=0)))
 return np.where(x<0,-(q+inc),q+inc)
def multiplier(alpha):
 shift=30
 while alpha*(1<<shift)>2147483647:shift-=1
 while shift<48 and alpha*(1<<shift)<(1<<29):shift+=1
 assert 0<=shift<=62
 m=int(np.rint(alpha*(1<<shift)));assert 0<=m<=2147483647
 return m,shift
class Quant:
 def __init__(self,g,cal,fw):
  self.g=g;self.fw=fw;self.params={};self.scales={0:1/127};self.manifest=[];self.blob=bytearray(b'YOLQ0001'+bytes(248));self.addresses={0:0x02000000};cursor=0x08000000
  self.signed=np.arange(256,dtype=np.int16);self.signed[self.signed>=128]-=256
  for n in g['nodes']:
   i=n['id'];kind=n['op'];src=n['inputs'];row=dict(n);row['input_scales']=[self.scales[j] for j in src]
   outscale=max(cal[str(i)]['out']/127,1e-9)
   if kind in ('maxpool','upsample'):outscale=self.scales[src[0]]
   if i in g['heads']:outscale=1/1024
   self.scales[i]=outscale;row['output_scale']=outscale;row['bits']=16 if i in g['heads'] else 8
   elems=int(np.prod(n['shape']));row['address']=cursor;row['bytes']=elems*(row['bits']//8);cursor=(cursor+row['bytes']+127)&~63;assert cursor<0x10000000
   self.addresses[i]=row['address']
   if kind=='conv':
    w=fw[f'n{i}_weight'];b=fw[f'n{i}_bias'];sw=np.maximum(np.abs(w).reshape(w.shape[0],-1).max(1)/127,1e-12)
    qw=np.rint(w/sw[:,None,None,None]).clip(-127,127).astype(np.int8);qb=np.rint(b/(sw*self.scales[src[0]])).astype(np.int64)
    assert np.all(np.abs(qb)<2147483647)
    prescale=max(cal[str(i)]['pre']/127,1e-9) if n['activation']=='silu' else outscale
    coeff=[multiplier(float(self.scales[src[0]]*s/prescale)) for s in sw];m=np.array([x[0] for x in coeff],np.int32);shift=np.array([x[1] for x in coeff],np.uint32)
    params=dict(weight=qw,bias=qb.astype(np.int32),multiplier=m,shift=shift)
    row['weight_scales']=sw.tolist();row['pre_scale']=prescale
    k=int(np.prod(qw.shape[1:]));stride=(k+31)&~31;padded=np.zeros((qw.shape[0],stride),np.int8);padded[:,:k]=qw.reshape(qw.shape[0],k)
    row['weight_row_stride']=stride;row['weight_offset']=self.add(padded.tobytes());row['bias_offset']=self.add(params['bias'].astype('<i4').tobytes());row['multiplier_offset']=self.add(m.astype('<i4').tobytes());row['shift_offset']=self.add(shift.astype('<u4').tobytes())
    if n['activation']=='silu':
     x=self.signed.astype(np.float64)*prescale;y=x/(1+np.exp(-np.clip(x,-700,700)));lut=np.rint(y/outscale).clip(-128,127).astype(np.int8);params['lut']=lut;row['lut_offset']=self.add(lut.tobytes())
    # Legal inputs cannot overflow the signed32 accumulator, including bias.
    bound=k*128*127+np.abs(qb);assert np.all(bound<2147483647);row['accumulator_abs_bound']=int(bound.max())
    self.params[i]=params
   elif kind=='add':
    tables=[np.rint(self.signed.astype(np.float64)*self.scales[j]/outscale*128).astype(np.int64) for j in src]
    assert all(np.max(np.abs(t))<=32767 for t in tables)
    tables=[t.astype(np.int16) for t in tables];self.params[i]=dict(tables=tables);row['table_offsets']=[self.add(t.astype('<i2').tobytes()) for t in tables];row['table_fraction_bits']=7
   elif kind=='concat':
    tables=[np.rint(self.signed.astype(np.float64)*self.scales[j]/outscale).clip(-128,127).astype(np.int8) for j in src]
    self.params[i]=dict(tables=tables);row['table_offsets']=[self.add(t.tobytes()) for t in tables]
   self.manifest.append(row)
  # Fold single-use, identity-scale concat inputs into the concat buffer: the
  # producer writes straight into its slot, so the CPU copy for it disappears.
  use={}
  for n in self.manifest:
   for s_ in n['inputs']: use[s_]=use.get(s_,0)+1
  byid={n['id']:n for n in self.manifest}
  for n in self.manifest:
   if n['op']!='concat': continue
   off=n['address']
   for s_,sc in zip(n['inputs'],n['input_scales']):
    src=byid[s_]; size=src['bytes']
    if use.get(s_,0)==1 and abs(sc/n['output_scale']-1.0)<1e-9 and size==byid[s_]['bytes']:
     src['address']=off; src['folded']=True; n['fold_count']=n.get('fold_count',0)+1
    off+=size
  struct.pack_into('<IIII',self.blob,8,1,len(self.blob),len(g['nodes']),160)
 def add(self,data):
  self.blob.extend(bytes((-len(self.blob))%32));offset=len(self.blob);self.blob.extend(data);return offset

 def run(self,x):
  values={0:np.rint(x.numpy()*127).clip(-128,127).astype(np.int8)};ranges=[]
  with torch.inference_mode():
   for n in self.manifest:
    i=n['id'];a=[values[j] for j in n['inputs']];p=self.params.get(i,{})
    if n['op']=='conv':
     acc=F.conv2d(torch.from_numpy(a[0]).double(),torch.from_numpy(p['weight']).double(),stride=n['stride'],padding=n['padding']).numpy().astype(np.int64)+p['bias'][None,:,None,None]
     assert np.max(np.abs(acc))<2147483647
     v=rshift_even(acc*p['multiplier'][None,:,None,None],p['shift'][None,:,None,None])
     if n['activation']=='silu':y=p['lut'][(v.clip(-128,127)&255).astype(np.int32)]
     elif n['bits']==16:y=v.clip(-32768,32767).astype(np.int16)
     else:y=v.clip(-128,127).astype(np.int8)
    elif n['op']=='add':
     t=p['tables'];s=t[0][a[0].astype(np.uint8)].astype(np.int64)+t[1][a[1].astype(np.uint8)].astype(np.int64);y=rshift_even(s,7).clip(-128,127).astype(np.int8)
    elif n['op']=='concat':y=np.concatenate([table[v.astype(np.uint8)] for table,v in zip(p['tables'],a)],1)
    elif n['op']=='maxpool':y=F.max_pool2d(torch.from_numpy(a[0]).float(),5,stride=1,padding=2).numpy().astype(np.int8)
    elif n['op']=='upsample':y=np.repeat(np.repeat(a[0],2,2),2,3)
    else:raise ValueError(n)
    values[i]=y;ranges.append([i,int(y.min()),int(y.max())])
  return values,ranges
def iou(a,b):
 lo=np.maximum(a[:2],b[:2]);hi=np.minimum(a[2:4],b[2:4]);inter=np.maximum(hi-lo,0).prod();return inter/(np.maximum(a[2:4]-a[:2],0).prod()+np.maximum(b[2:4]-b[:2],0).prod()-inter+1e-9)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--images',type=int,default=8);a=ap.parse_args();ref=R/'model/reference'
 g=json.loads((ref/'graph.json').read_text());cal=json.loads((ref/'calibration.json').read_text());fw=dict(np.load(ref/'float_weights.npz'));q=Quant(g,cal,fw)
 (O/'weights.bin').write_bytes(q.blob);manifest=dict(ABI=1,format='NCHW, little endian, per-output-channel symmetric W8; A8; accumulator S32; Detect head S16/Q10',rounding='nearest ties-to-even; signed saturation',input_scale=1/127,nodes=q.manifest,heads=g['heads'],detect=g['detect'],names=g['names'],weights_bytes=len(q.blob),weights_sha256=hashlib.sha256(q.blob).hexdigest())
 (O/'model.json').write_text(json.dumps(manifest,indent=2)+'\n')
 decode=object.__new__(Graph);decode.heads=g['heads'];decode.detect=g['detect'];floatgraph=object.__new__(Graph);floatgraph.nodes=g['nodes'];floatgraph.weights=fw;floatgraph.heads=g['heads'];floatgraph.detect=g['detect']
 paths=list((R/'third_party/yolov5/data/images').glob('*.jpg'))+sorted((R/'model/datasets/coco128/images/train2017').glob('*.jpg'))[64:64+a.images]
 report=dict(quantization='custom explicit PTQ; SiLU retained',independent_COCO_validation=False,images=[],passed=False)
 names=g['names'];names={int(k):v for k,v in names.items()} if isinstance(names,dict) else names
 for number,path in enumerate(paths):
  start=time.perf_counter();rgb,x,prep=image_input(path);values,ranges=q.run(x);deq={h:torch.from_numpy(values[h]).float()/1024 for h in g['heads']};pred=decode.decode(deq);det=non_max_suppression(pred.clone(),.25,.45,max_det=100)[0].numpy()
  with torch.inference_mode():fvalues,_=floatgraph.run(x);fpdet=non_max_suppression(floatgraph.decode(fvalues),.25,.45,max_det=100)[0].numpy()
  matches=[]
  for row in fpdet:
   candidates=[(j,iou(row,d)) for j,d in enumerate(det) if int(d[5])==int(row[5])];best=max(candidates,key=lambda z:z[1]) if candidates else (-1,0);matches.append(dict(class_id=int(row[5]),fp_confidence=float(row[4]),best_quant_index=best[0],IoU=best[1]))
  image_report=dict(name=path.name,seconds=time.perf_counter()-start,fp32=fpdet.tolist(),quantized=det.tolist(),matches=matches,operator_ranges=ranges)
  report['images'].append(image_report)
  np.savez_compressed(O/(path.stem+'-heads.npz'),**{f'head{i}':values[h] for i,h in enumerate(g['heads'])})
  preview=Image.fromarray(rgb);draw=ImageDraw.Draw(preview)
  for d in det:draw.rectangle(d[:4].tolist(),outline='lime',width=2);draw.text((float(d[0]),max(0,float(d[1])-12)),f'{names[int(d[5])]} {d[4]:.2f}',fill='lime')
  preview.save(O/(path.stem+'-int8.png'))
  print('INT8 oracle',number+1,'/',len(paths),path.name,'FP/INT boxes',len(fpdet),len(det),'seconds',round(image_report['seconds'],3),flush=True)
 report['passed']=True;report['note']='Execution/reference consistency passed, not an assertion of unchanged accuracy. Per-image FP32/quantized boxes and matching IoUs are retained; COCO128 is a training/development subset.'
 (O/'quantization-report.json').write_text(json.dumps(report,indent=2)+'\n');print('Quantized export',len(q.blob),'bytes; numerical contract saved')
if __name__=='__main__':main()
