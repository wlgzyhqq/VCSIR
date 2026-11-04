"""Small exact integer convolution fixtures, no ML framework in the oracle."""
from pathlib import Path
import random,struct,json
R=Path(__file__).resolve().parents[1];O=R/'output/conv-vectors';O.mkdir(exist_ok=True)
r=random.Random(732641)
def rounded(x,s):
    q,rem=divmod(abs(x),1<<s)
    if rem*2>1<<s or (rem*2==1<<s and q%2):q+=1
    return -q if x<0 else q
cases=[(9,7,3,7,3,1,1,True,False),(11,9,5,3,1,1,0,False,False),
       (10,10,3,8,6,2,2,True,False),(3,3,128,8,3,1,0,False,True),
       (9,5,2,7,1,1,0,False,True),(5,5,1,1,5,1,2,True,False)]
metadata=[]
for num,(w,h,ci,co,k,st,pad,silu,wide) in enumerate(cases):
    ow=(w+2*pad-k)//st+1;oh=(h+2*pad-k)//st+1;dot=ci*k*k;row=(dot+31)&~31
    a=[r.randrange(-128,128) for _ in range(w*h*ci)]
    weights=[[r.randrange(-127,128) for _ in range(dot)] for _ in range(co)]
    bias=[r.randrange(-100000,100001) for _ in range(8)]
    mult=[r.randrange(1<<28,1<<30) for _ in range(8)]
    shift=[r.randrange(25,39) for _ in range(8)]
    lut=[r.randrange(-128,128) for _ in range(256)]
    expected=[]
    for oc in range(co):
        for y in range(oh):
            for x in range(ow):
                acc=bias[oc];wi=0
                for c in range(ci):
                    for ky in range(k):
                        iy=y*st+ky-pad
                        for kx in range(k):
                            ix=x*st+kx-pad
                            if 0<=ix<w and 0<=iy<h:acc+=a[c*w*h+iy*w+ix]*weights[oc][wi]
                            wi+=1
                v=rounded(acc*mult[oc],shift[oc]);v=max(-32768 if wide else -128,min(32767 if wide else 127,v))
                if silu:v=lut[v&255]
                expected.extend(struct.pack('<h',v) if wide else bytes([v&255]))
    parts={0:bytes(x&255 for x in a),0x60000:b''.join(bytes(v&255 for v in ws)+bytes(row-dot) for ws in weights),
           0x70000:struct.pack('<8i',*bias),0x70100:struct.pack('<8I',*mult),0x70200:struct.pack('<8I',*shift),0x70300:bytes(v&255 for v in lut)}
    (O/f'{num}.mem').write_text(''.join(f'@{off:08x}\n'+''.join(f'{b:02x}\n' for b in data) for off,data in parts.items()))
    (O/f'{num}.expected').write_text(''.join(f'{b:02x}\n' for b in expected))
    (O/f'{num}.config').write_text(f'{w} {h} {ci} {co} {k} {st} {pad} {ow} {oh} {row} {int(silu)} {int(wide)} {len(expected)}\n')
    metadata.append(dict(case=num,width=w,height=h,Cin=ci,Cout=co,kernel=k,stride=st,padding=pad,output=[co,oh,ow],silu=silu,out16=wide,dot_length=dot))
model=json.loads((R/'model/quantized/model.json').read_text());nodes={n['id']:n for n in model['nodes']};nodes[0]=dict(shape=[3,160,160])
blob=(R/'model/quantized/weights.bin').read_bytes()
deep=next(n['id'] for n in model['nodes'] if n['op']=='conv' and n['cin']*n['kernel']**2==1152)
for num,(node_id,oc_start,co) in enumerate([(1,0,8),(85,248,7),(deep,0,8),(48,0,8)],start=len(cases)):
    n=nodes[node_id];src=n['inputs'][0];ci,h,w=nodes[src]['shape'];_,oh,ow=n['shape'];wide=n['bits']==16;row=n['weight_row_stride']
    source=(R/f'model/golden/tensor-{src:03d}.bin').read_bytes();assert len(source)<=0x60000
    def section(key,length,offset=0):
        start=n[key]+offset;return blob[start:start+length]
    parts={0:source,0x60000:section('weight_offset',co*row,oc_start*row),
           0x70000:section('bias_offset',32,oc_start*4),0x70100:section('multiplier_offset',32,oc_start*4),0x70200:section('shift_offset',32,oc_start*4)}
    if n['activation']=='silu':parts[0x70300]=section('lut_offset',256)
    raw=(R/f'model/golden/tensor-{node_id:03d}.bin').read_bytes();size=co*ow*oh*(2 if wide else 1);start=oc_start*ow*oh*(2 if wide else 1);expected=raw[start:start+size]
    (O/f'{num}.mem').write_text(''.join(f'@{off:08x}\n'+''.join(f'{b:02x}\n' for b in data) for off,data in parts.items()))
    (O/f'{num}.expected').write_text(''.join(f'{b:02x}\n' for b in expected))
    (O/f'{num}.config').write_text(f"{w} {h} {ci} {co} {n['kernel']} {n['stride']} {n['padding']} {ow} {oh} {row} {int(n['activation']=='silu')} {int(wide)} {size}\n")
    metadata.append(dict(case=num,actual_node_id=node_id,oc_start=oc_start,output_channels=co,output_bytes=size))
(O/'cases.json').write_text(json.dumps(metadata,indent=2)+'\n')
print('Generated',len(metadata),'cases, including full-size real first layer, head tail and maximum-K layer')
