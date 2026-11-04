"""Check every frozen convolution/channel group against the hardware limits.
Also prove signed32 accumulation bounds from actual per-row weights/biases.
"""
from pathlib import Path
import json,struct,hashlib,math
R=Path(__file__).resolve().parents[1]
m=json.loads((R/'model/quantized/model.json').read_text());blob=(R/'model/quantized/weights.bin').read_bytes()
nodes={n['id']:n for n in m['nodes']};nodes[0]=dict(shape=[3,160,160]);rows=[]
for n in m['nodes']:
 assert n['bytes']==math.prod(n['shape'])*(n['bits']//8)
 if n['op']!='conv':continue
 ci,ih,iw=nodes[n['inputs'][0]]['shape'];co,oh,ow=n['shape'];k=n['kernel'];dot=ci*k*k;stride=n['weight_row_stride']
 assert ci==n['cin'] and 1<=ci<=512
 assert 1<=min(ih,iw,oh,ow) and max(ih,iw,oh,ow)<=320
 assert k in range(1,7) and n['stride'] in (1,2) and n['padding'] in range(4)
 assert oh==(ih+2*n['padding']-k)//n['stride']+1 and ow==(iw+2*n['padding']-k)//n['stride']+1
 assert dot<=1152 and dot<=stride<=2048 and stride%32==0
 assert ih*iw<=102400 and oh*ow*(n['bits']//8)<=204800
 assert (n['activation']=='silu')==(n['bits']==8)
 max_bound=0
 for oc in range(co):
  weights=blob[n['weight_offset']+oc*stride:n['weight_offset']+oc*stride+dot];assert len(weights)==dot
  bias=struct.unpack_from('<i',blob,n['bias_offset']+oc*4)[0]
  mult=struct.unpack_from('<I',blob,n['multiplier_offset']+oc*4)[0]
  shift=struct.unpack_from('<I',blob,n['shift_offset']+oc*4)[0]
  assert 0<mult<2**31 and 0<=shift<=48
  bound=abs(bias)+128*sum(abs(w if w<128 else w-256) for w in weights)
  assert bound<2**31,(n['id'],oc,bound)
  max_bound=max(max_bound,bound)
 for oc in range(0,co,8):
  count=min(8,co-oc);assert 1<=count<=8
  for key in ('bias_offset','multiplier_offset','shift_offset'):assert (n[key]+oc*4)%32==0
 rows.append(dict(node=n['id'],Cin=ci,Cout=co,input_hw=[ih,iw],output_hw=[oh,ow],kernel=k,K=dot,weight_stride=stride,groups=math.ceil(co/8),signed32_absolute_bound=max_bound))
report=dict(passed=True,model_sha256=hashlib.sha256((R/'model/quantized/model.json').read_bytes()).hexdigest(),weights_sha256=hashlib.sha256(blob).hexdigest(),hardware_limits=dict(Cin=512,K=1152,dimension=320,weight_stride=2048,output_channels_per_command=8),convolutions=rows,
 note='Static graph/actual-weight proof; not a substitute for board layer CRCs. Cin512 boundary covered by RTL fixture for actual node48.')
(R/'output/reports/model-hardware-contract.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS',len(rows),'convolutions,',sum(r['groups'] for r in rows),'channel groups; maxCin',max(r['Cin'] for r in rows),'maxK',max(r['K'] for r in rows),'all actual-weight signed32 bounds')
