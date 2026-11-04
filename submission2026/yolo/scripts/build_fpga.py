"""Bind all application inputs, run PDS, publish only final multi-corner pass."""
from pathlib import Path
import subprocess,json,hashlib,datetime,re,shutil,time
R=Path(__file__).resolve().parents[1];O=R/'output/reports';B=R/'build';B.mkdir(exist_ok=True)
project=R/'final_yolo.pds';source=re.findall(r'\(_file "([^"\n]+)"(?:\s*\+\s*"[^"\n]+")?\s*\(_format (?:verilog|fdc)\)',project.read_text(encoding='utf-8'))
source=[n for n in source if n.startswith(('rtl/','ipcore/','constraints/'))]
source+=['rtl/tf_boot_config.vh','final_yolo.pds'];source=list(dict.fromkeys(source));sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
started=time.time()
previous=json.loads((O/'build.json').read_text()) if (O/'build.json').exists() else {}
def pnr_options():
 s=project.read_text();begin=s.index('(_command cmd_pnr');depth=0;quoted=False
 for end in range(begin,len(s)):
  c=s[end]
  if c=='"':quoted=not quoted
  elif not quoted:
   if c=='(':depth+=1
   elif c==')':
    depth-=1
    if depth==0:break
 return re.findall(r'\(_option (\w+) \((\w+) ([^)]*)\)\)',s[begin:end+1])
all_options=lambda:re.findall(r'\(_option (\w+) \((\w+) ([^)]*)\)\)',project.read_text())
report=dict(started_at=datetime.datetime.now().isoformat(),source_sha256={n:sha(R/n) for n in source},pnr_options=pnr_options(),project_options=all_options(),TF_written=False,Flash_written=False,board_test=False)
with (B/'pds.log').open('wb') as log:
 p=subprocess.Popen(['D:/pango/PDS_2022.2-SP1-Lite/bin/pds_shell.exe','-project','final_yolo.pds','-run','gen_bit_stream'],cwd=R,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
 report['pid']=p.pid;(O/'build.json').write_text(json.dumps(report,indent=2)+'\n');print('YOLO_APP_PDS_PID='+str(p.pid),flush=True);report['exit_code']=p.wait()
report['finished_at']=datetime.datetime.now().isoformat()
for n,h in report['source_sha256'].items():
 if n!='final_yolo.pds':assert sha(R/n)==h,('Build inputs changed while PDS was running',n)
log_text=(B/'pds.log').read_text(errors='replace');report['tool_errors']=re.findall(r'^E:.*$',log_text,re.M)
assert pnr_options()==report['pnr_options'],'PnR options changed during build'
report['project_options_final']=all_options()
keys=lambda d:set(d)-{'final_yolo.pds'}
reusable=previous.get('timing_qualified',False) and previous.get('project_options_final')==report['project_options']==report['project_options_final'] and keys(previous.get('source_sha256',{}))==keys(report['source_sha256']) and all(previous.get('source_sha256',{}).get(n)==h for n,h in report['source_sha256'].items() if n!='final_yolo.pds')
t=R/'report_timing/final_top.rtr';report['timing_qualified']=not report['tool_errors'] and (t.exists() and (t.stat().st_mtime>=started or reusable)) and t.exists() and 'All Constraints Met' in t.read_text() and 'Timing analysis mode : multi corner' in t.read_text()
if report['exit_code']==0 and report['timing_qualified']:
 report['timing_sha256']=sha(t)
 bit=R/'generate_bitstream/final_top.sbit';assert bit.exists() and (bit.stat().st_mtime>=started or reusable);report['bitstream_sha256']=sha(bit);shutil.copy2(bit,R/'output/bitstream/yolo_image_demo.sbit')
(O/'build.json').write_text(json.dumps(report,indent=2)+'\n');print('Application build exit',report['exit_code'],'timing qualified',report['timing_qualified'],flush=True)
raise SystemExit(report['exit_code'] or (0 if report['timing_qualified'] else 1))
