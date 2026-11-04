"""Render real trace CSVs; original VCD/CSV/raw capture remain inspectable."""
from pathlib import Path
import csv,json,argparse
from PIL import Image,ImageDraw,ImageFont
ap=argparse.ArgumentParser();ap.add_argument('--region',choices=['entry','inner'],default='entry');a=ap.parse_args()
R=Path(__file__).resolve().parents[1]/'output/validation'/('coremark-captures' if a.region=='entry' else 'coremark-inner-captures')
font=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',16)
small=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',13)
for folder in R.iterdir():
 if not folder.is_dir():continue
 p=folder/'samples.csv'
 if not p.exists():continue
 rows=[{k:int(v) for k,v in r.items()} for r in csv.DictReader(p.open())];report=json.loads((folder/'report.json').read_text())
 names=['issue','fetch_valid','E1_valid','E2_valid','WB_valid','retired','global_stall','lsu_stall','decode_wait','unit_interlock','redirect','E1_mul','decoded_branch','decoded_lsu','I_ARVALID','I_ARREADY','I_RVALID','D_ARVALID','D_ARREADY','D_RVALID']
 img=Image.new('RGB',(1900,1000),'#101820');d=ImageDraw.Draw(img)
 d.text((20,12),f"REAL FPGA CAPTURE | {folder.name.upper()} | 90 MHz | trigger {report['trigger_symbol']} @ 0x{report['trigger_pc']:08x}",font=font,fill='white')
 d.text((20,40),'256 consecutive clock samples; 11.111 ns/clock. Passive on-chip analyzer; UART export. NOT simulation.',font=font,fill='#b9c8d5')
 x0=220;dx=6;top=110;dy=35
 for i in range(0,257,16):
  x=x0+i*dx;d.line((x,90,x,top+dy*len(names)),fill='#293847');d.text((x-6,78),str(i),font=small,fill='#92a7b8')
 for j,name in enumerate(names):
  y=top+j*dy;d.text((15,y+4),name,font=font,fill='#d7e2ed')
  last=None
  for i,r in enumerate(rows):
   v=r[name];yy=y+22-v*18;x=x0+i*dx
   if last is not None:d.line((x,last,x,yy),fill='#5ee8a1',width=2)
   d.line((x,yy,x+dx,yy),fill='#5ee8a1',width=2);last=yy
 # The matching PC identifies actual trigger; no invented annotation.
 matches=[i for i,r in enumerate(rows) if r['issue'] and r['decode_pc']==report['trigger_pc']]
 for i in matches[:1]:
  x=x0+i*dx;d.line((x,96,x,top+dy*len(names)),fill='#ffc757',width=2)
 d.text((20,835),f"Window: issued={report['trace']['counts']['issue']}, retired={report['trace']['counts']['retired']}, redirects={report['trace']['counts']['redirect']}, CPI={report['trace']['window_CPI']:.3f}",font=font,fill='white')
 d.text((20,865),'Window CPI includes pre-trigger code and misses; it is NOT the whole benchmark CPI.',font=font,fill='#b9c8d5')
 d.text((20,895),'Full PC/opcode/writeback and AXI details: samples.csv and capture.vcd in this directory.',font=font,fill='#b9c8d5')
 d.text((20,925),'Raw capture SHA256: '+report['trace']['raw_sha256'],font=small,fill='#b9c8d5')
 img.save(folder/'waveform.png')
 print(folder.name,'rendered')
