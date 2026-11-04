"""2022 RTL synthesis compatibility driver. Physical routing uses2025 only."""
from pathlib import Path
import json,hashlib,re,subprocess,datetime,time,shutil,argparse
ap=argparse.ArgumentParser();ap.add_argument('--build-dir',default='cnn32-build');ap.add_argument('--tag',default='cnn32');ap.add_argument('--synth-only',action='store_true',default=True,help='Compatibility flag: this driver always stops after RTL synthesis');ap.add_argument('--pds',default='D:/pango/PDS_2022.2-SP1-Lite/bin/pds_shell.exe');a=ap.parse_args()
assert a.tag.isalnum()
R=Path(__file__).resolve().parents[1];D=R/a.build_dir;assert D.resolve().is_relative_to(R);O=R/'output/reports'/a.tag;O.mkdir(parents=True,exist_ok=True)
import os
env=dict(os.environ)
if '2025' in a.pds:
    config=json.loads((R/'output/pds2025/configuration.json').read_text(encoding='utf-8-sig'))
    env['PANGO_LICENSE_FILE']=config['licensePath'];assert Path(env['PANGO_LICENSE_FILE']).is_file()
meta=json.loads((D/'inputs.json').read_text());P=D/'final_yolo_cnn.pds'
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def options():
    text=P.read_text();begin=text.index('(_command cmd_pnr');depth=0;quoted=False
    for end in range(begin,len(text)):
        c=text[end]
        if c=='"':quoted=not quoted
        elif not quoted:
            if c=='(':depth+=1
            elif c==')':
                depth-=1
                if depth==0:break
    block=text[begin:end+1]
    return re.findall(r'\(_option (\w+) \((\w+) ([^)]*)\)\)',block)
for p,h in meta['sources'].items():assert sha(p)==h,('Snapshot modified',p)
assert not (D/'active.json').exists()
def widget(name):
    text=P.read_text();begin=text.index('(_widget '+name);depth=0;quoted=False
    for end in range(begin,len(text)):
        c=text[end]
        if c=='"':quoted=not quoted
        elif not quoted:
            if c=='(':depth+=1
            elif c==')':
                depth-=1
                if depth==0:return text[begin:end+1]
    raise ValueError(name)
source_paths=re.findall(r'\(_file "([^"\n]+)"(?:\s*\+\s*"[^"\n]+")?\s*\(_format (?:verilog|fdc)\)',widget('wgt_my_design_src')+widget('wgt_import_logic_con_file'))
source_paths=[str((Path(p) if Path(p).is_absolute() else D/p).resolve()) for p in source_paths]
assert len(source_paths)>100 and all(p in meta['sources'] for p in source_paths)
shutil.copy2(P,O/'project-at-start.pds');started=time.time()
report=dict(started=datetime.datetime.now().isoformat(),source_sha256=meta['sources'],pnr_options=options(),project=str(P),
            bitstream='output/bitstream/yolo_'+a.tag+'.sbit',board_verified=False,Flash_written=False,TF_written=False,timing_qualified=False)
report['tool_path']=a.pds;report['license_path']=env.get('PANGO_LICENSE_FILE')
version=subprocess.run([a.pds,'-version'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW,timeout=30)
report['tool_version']=version.stdout.decode(errors='replace').strip()
try:
    with (D/'pds.log').open('wb') as out:
        p=subprocess.Popen([a.pds,'-project',P.name,'-run','synthesize' if a.synth_only else 'gen_bit_stream'],cwd=D,env=env,stdout=out,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        report['pid']=p.pid;(D/'active.json').write_text(json.dumps({'pid':p.pid,'started':report['started']})+'\n')
        (O/'build.json').write_text(json.dumps(report,indent=2)+'\n');print('CNN_SOC_PDS_PID='+str(p.pid),flush=True);report['exit_code']=p.wait()
    for path,h in report['source_sha256'].items():assert sha(path)==h,('Snapshot changed during PDS build',path)
    assert options()==report['pnr_options'],'PnR options changed'
    t=D/'report_timing/final_top.rtr'
    text=(D/'pds.log').read_text(errors='replace');report['tool_errors']=re.findall(r'^E:.*$',text,re.M)
    if a.synth_only:
        net=D/'synthesize/final_top_syn.vm'
        report['synthesis_only']=True
        report['synthesis_passed']=report['exit_code']==0 and not report['tool_errors'] and net.is_file() and net.stat().st_mtime>=started
        if report['synthesis_passed']:report['netlist_sha256']=sha(net)
        print('RTL synthesis passed:',report['synthesis_passed'],flush=True)
        raise SystemExit(0 if report['synthesis_passed'] else 1)
    if report['exit_code']==0 and not report['tool_errors'] and (not t.exists() or t.stat().st_mtime<started):
        with (D/'timing-driver.log').open('wb') as out:
            r=subprocess.run([a.pds,'-project',P.name,'-run','report_timing'],cwd=D,env=env,stdout=out,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        report['timing_exit_code']=r.returncode
        report['tool_errors']+=re.findall(r'^E:.*$',(D/'timing-driver.log').read_text(errors='replace'),re.M)
    report['timing_qualified']=report['exit_code']==0 and not report['tool_errors'] and t.exists() and t.stat().st_mtime>=started and 'All Constraints Met' in t.read_text() and 'Timing analysis mode : multi corner' in t.read_text()
    if t.exists():shutil.copy2(t,O/'final_top.rtr')
    if report['timing_qualified']:
        bit=D/'generate_bitstream/final_top.sbit';assert bit.exists() and bit.stat().st_mtime>=started
        report['bitstream_sha256']=sha(bit);shutil.copy2(bit,R/report['bitstream'])
except Exception as e:report['error']=repr(e);raise
finally:
    report['finished']=datetime.datetime.now().isoformat();(O/'build.json').write_text(json.dumps(report,indent=2)+'\n');(D/'active.json').unlink(missing_ok=True)
print('CNN SoC final multi-corner timing qualified',report['timing_qualified'],flush=True)
raise SystemExit(0 if report['timing_qualified'] else 1)
