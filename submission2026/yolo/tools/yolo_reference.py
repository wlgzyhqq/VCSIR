"""Pinned official YOLOv5n -> explicit operator graph and FP32 oracle.

No vendor source modifications. Loading pickle is restricted to the downloaded
official asset whose SHA256 is checked against our provenance record.
"""
from pathlib import Path
import os,sys,json,hashlib,time,argparse
os.environ['YOLOv5_AUTOINSTALL']='false'
R=Path(__file__).resolve().parents[1];V=R/'third_party/yolov5';sys.path.insert(0,str(V))
import numpy as np
import torch
import torch.nn.functional as F
import cv2
from PIL import Image,ImageDraw
from models.common import Conv,Bottleneck,C3,SPPF,Concat
from models.yolo import Detect
from utils.augmentations import letterbox
from utils.general import non_max_suppression
from model_size import SIZE
torch.set_num_threads(4)
def image_input(path,size=SIZE):
 bgr=cv2.imread(str(path));assert bgr is not None,path
 im,ratio,pad=letterbox(bgr,new_shape=(size,size),auto=False,stride=32)
 rgb=im[:,:,::-1].copy();x=torch.from_numpy(rgb.transpose(2,0,1).copy()).float()[None]/255
 return rgb,x,dict(original_shape=list(bgr.shape[:2]),ratio=list(ratio),pad=list(pad))
class Graph:
 def __init__(self,model):
  self.nodes=[];self.weights={};self.names=model.names;self.heads=[];self.detect=None
  outputs=[];prev=0
  for i,m in enumerate(model.model):
   src=([prev if f==-1 else outputs[f] for f in m.f] if isinstance(m.f,list) else prev if m.f==-1 else outputs[m.f])
   prev=self.expand(m,src,f'model.{i}');outputs.append(prev)
 def node(self,op,src,name,**attrs):
  i=len(self.nodes)+1;self.nodes.append(dict(id=i,op=op,inputs=src if isinstance(src,list) else [src],name=name,**attrs));return i
 def conv(self,m,x,name,activation='identity'):
  if isinstance(m,Conv):c=m.conv;activation='silu' if isinstance(m.act,torch.nn.SiLU) else 'identity';assert isinstance(m.act,(torch.nn.SiLU,torch.nn.Identity))
  else:c=m
  assert c.groups==1 and c.dilation==(1,1) and c.kernel_size[0]==c.kernel_size[1]
  i=self.node('conv',x,name,cin=c.in_channels,cout=c.out_channels,kernel=c.kernel_size[0],stride=c.stride[0],padding=c.padding[0],activation=activation)
  self.weights[f'n{i}_weight']=c.weight.detach().cpu().numpy().copy()
  self.weights[f'n{i}_bias']=c.bias.detach().cpu().numpy().copy() if c.bias is not None else np.zeros(c.out_channels,np.float32)
  return i
 def expand(self,m,x,name):
  if isinstance(m,Conv):return self.conv(m,x,name)
  if isinstance(m,Bottleneck):
   y=self.expand(m.cv1,x,name+'.cv1');y=self.expand(m.cv2,y,name+'.cv2');return self.node('add',[x,y],name+'.add') if m.add else y
  if type(m) is C3:
   y=self.expand(m.cv1,x,name+'.cv1')
   for i,b in enumerate(m.m):y=self.expand(b,y,name+f'.m.{i}')
   z=self.expand(m.cv2,x,name+'.cv2');y=self.node('concat',[y,z],name+'.concat');return self.expand(m.cv3,y,name+'.cv3')
  if isinstance(m,SPPF):
   a=self.expand(m.cv1,x,name+'.cv1');b=self.node('maxpool',a,name+'.pool1',kernel=5,padding=2);c=self.node('maxpool',b,name+'.pool2',kernel=5,padding=2);d=self.node('maxpool',c,name+'.pool3',kernel=5,padding=2)
   return self.expand(m.cv2,self.node('concat',[a,b,c,d],name+'.concat'),name+'.cv2')
  if isinstance(m,torch.nn.Upsample):return self.node('upsample',x,name,factor=2)
  if isinstance(m,Concat):assert m.d==1;return self.node('concat',x,name)
  if type(m) is Detect:
   self.detect=dict(classes=m.nc,anchors=(m.anchors*m.stride[:,None,None]).cpu().tolist(),strides=m.stride.cpu().tolist())
   self.heads=[self.conv(c,t,name+f'.head{i}') for i,(c,t) in enumerate(zip(m.m,x))];return self.heads
  raise TypeError((name,type(m)))
 def run(self,x,stats=None):
  values={0:x};pre={}
  for n in self.nodes:
   a=[values[i] for i in n['inputs']]
   if n['op']=='conv':
    w=torch.from_numpy(self.weights[f'n{n["id"]}_weight']);b=torch.from_numpy(self.weights[f'n{n["id"]}_bias'])
    y=F.conv2d(a[0],w,b,stride=n['stride'],padding=n['padding']);pre[n['id']]=y
    if stats is not None:stats[n['id']]['pre']=max(stats[n['id']].get('pre',0),float(y.abs().max()))
    if n['activation']=='silu':y=F.silu(y)
   elif n['op']=='add':y=a[0]+a[1]
   elif n['op']=='concat':y=torch.cat(a,1)
   elif n['op']=='maxpool':y=F.max_pool2d(a[0],5,stride=1,padding=2)
   elif n['op']=='upsample':y=F.interpolate(a[0],scale_factor=2,mode='nearest')
   else:raise ValueError(n)
   values[n['id']]=y;n['shape']=list(y.shape[1:])
   if stats is not None:stats[n['id']]['out']=max(stats[n['id']].get('out',0),float(y.abs().max()))
  return values,pre
 def decode(self,values):
  result=[]
  for i,h in enumerate(self.heads):
   raw=values[h];bs,_,ny,nx=raw.shape;y=raw.reshape(bs,3,self.detect['classes']+5,ny,nx).permute(0,1,3,4,2).contiguous().sigmoid()
   gy,gx=torch.meshgrid(torch.arange(ny),torch.arange(nx),indexing='ij');grid=torch.stack((gx,gy),2)[None,None]-.5
   anchors=torch.tensor(self.detect['anchors'][i])[None,:,None,None]
   xy=(y[...,:2]*2+grid)*self.detect['strides'][i];wh=(y[...,2:4]*2).square()*anchors
   result.append(torch.cat((xy,wh,y[...,4:]),-1).reshape(bs,-1,self.detect['classes']+5))
  return torch.cat(result,1)
def load():
 p=R/'model/source/yolov5n-v7.0.pt';proof=json.loads((p.parent/'provenance.json').read_text())
 assert hashlib.sha256(p.read_bytes()).hexdigest()==proof[p.name]['sha256']
 model=torch.load(p,map_location='cpu',weights_only=False)['model'].float().eval();model.fuse().eval()
 return model,Graph(model)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--calibrate',type=int,default=64);a=ap.parse_args();O=R/'model/reference';O.mkdir(exist_ok=True)
 model,g=load();report=dict(model='official YOLOv5n v7.0',input=[1,3,SIZE,SIZE],pytorch=torch.__version__,calibration_dataset='COCO128 training subset; development/calibration only',images=[])
 stats={n['id']:{} for n in g.nodes};paths=sorted((R/'model/datasets/coco128/images/train2017').glob('*.jpg'))[:a.calibrate]
 assert paths,'Download calibration images first'
 with torch.inference_mode():
  for i,path in enumerate(paths):
   rgb,x,prep=image_input(path);values,pre=g.run(x,stats);pred=g.decode(values);official=model(x)[0];err=float((pred-official).abs().max());assert err<0.001,(path,err)
   det=non_max_suppression(pred.clone(),.25,.45,max_det=100)[0].cpu().numpy()
   if i<8:
    preview=Image.fromarray(rgb);draw=ImageDraw.Draw(preview)
    for row in det:
     box=row[:4].tolist();draw.rectangle(box,outline='lime',width=2);draw.text((box[0],max(0,box[1]-12)),f'{model.names[int(row[5])]} {row[4]:.2f}',fill='lime')
    preview.save(O/(path.stem+'-fp32.png'));np.save(O/(path.stem+'-input.npy'),x.numpy());np.savez_compressed(O/(path.stem+'-heads.npz'),**{f'head{j}':values[h].numpy() for j,h in enumerate(g.heads)})
   report['images'].append(dict(name=path.name,max_decoded_error_vs_official=err,detections=det.tolist(),preprocess=prep))
   if i%8==0:print('FP32 reference/calibration',i+1,'/',len(paths),'max error',err,flush=True)
 np.savez(O/'float_weights.npz',**g.weights)
 graph=dict(nodes=g.nodes,heads=g.heads,detect=g.detect,names=g.names,input_scale=1/127)
 (O/'graph.json').write_text(json.dumps(graph,indent=2)+'\n');(O/'calibration.json').write_text(json.dumps(stats,indent=2)+'\n');report['operator_count']=len(g.nodes);report['passed']=True
 (O/'fp32-report.json').write_text(json.dumps(report,indent=2)+'\n');print('FP32 graph verified',len(g.nodes),'operators',len(paths),'images',flush=True)
if __name__=='__main__':main()
