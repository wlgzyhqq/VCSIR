"""PDS2025 XML flow driver, separate outputs and strict final timing gate."""
from pathlib import Path
import xml.etree.ElementTree as ET,json,hashlib,subprocess,os,time,datetime,re,shutil,argparse
ap=argparse.ArgumentParser();ap.add_argument('--build-dir',default='pds2025-cnn32-netlist');ap.add_argument('--tag',default='pds2025cnn32netlist');a=ap.parse_args();assert a.tag.isalnum()
R=Path(__file__).resolve().parents[1];D=R/a.build_dir;assert D.resolve().is_relative_to(R);O=R/'output/reports'/a.tag;O.mkdir(parents=True,exist_ok=True)
meta=json.loads((D/'inputs.json').read_text());P=Path(meta['project']);pds='D:/pango/PDS_2025.2-ads/bin/pds_shell.exe'
env=dict(os.environ);env['PANGO_LICENSE_FILE']=json.loads((R/'output/pds2025/configuration.json').read_text(encoding='utf-8-sig'))['licensePath']
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
for p,h in meta['sources'].items():assert sha(p)==h,('Input changed',p)
assert not (D/'active.json').exists()
def physical_options():
    root=ET.parse(P).getroot();task=root.find(".//task[@name='cmd_pnr']");assert task is not None
    return [(n.get('name'),n.get('value')) for n in task.findall('.//option')]
started=time.time();report=dict(started=datetime.datetime.now().isoformat(),tool_path=pds,tool_version='2025.2 build211867',
    logic_synthesis='2022.2-SP1-Lite GTP netlist, re-imported by2025',source_sha256=meta['sources'],pnr_options=physical_options(),
    netlist_sha256=meta['netlist_sha256'],bitstream='output/bitstream/yolo_'+a.tag+'.sbit',timing_qualified=False,board_verified=False,Flash_written=False,TF_written=False)
shutil.copy2(P,O/'project-at-start.pds')
def save():(O/'build.json').write_text(json.dumps(report,indent=2)+'\n')
try:
    with (D/'pds.log').open('wb') as out:
        p=subprocess.Popen([pds,'-project',P.name,'-run','gen_bit_stream'],cwd=D,env=env,stdout=out,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        report['pid']=p.pid;(D/'active.json').write_text(json.dumps({'pid':p.pid,'started':report['started']})+'\n');save();print('PDS2025_NETLIST_PID='+str(p.pid),flush=True);report['exit_code']=p.wait()
    log=(D/'pds.log').read_text(errors='replace');report['tool_errors']=re.findall(r'^E:.*$',log,re.M)
    for path,h in report['source_sha256'].items():assert sha(path)==h,('Input changed during2025 build',path)
    report['pnr_options_final']=physical_options()
    timings=sorted(D.glob('prj_tasks/**/final_top.rtr'),key=lambda p:p.stat().st_mtime)
    if report['exit_code']==0 and not report['tool_errors'] and not timings:
        with (D/'timing-driver.log').open('wb') as out:
            t=subprocess.run([pds,'-project',P.name,'-run','report_timing'],cwd=D,env=env,stdout=out,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        report['timing_exit_code']=t.returncode;report['tool_errors']+=re.findall(r'^E:.*$',(D/'timing-driver.log').read_text(errors='replace'),re.M)
        timings=sorted(D.glob('prj_tasks/**/final_top.rtr'),key=lambda p:p.stat().st_mtime)
    if timings:
        timing=timings[-1];report['timing_file']=str(timing.relative_to(R));text=timing.read_text(errors='replace');shutil.copy2(timing,O/'final_top.rtr');report['timing_sha256']=sha(timing)
        report['timing_qualified']=report['exit_code']==0 and not report['tool_errors'] and timing.stat().st_mtime>=started and 'All Constraints Met' in text and 'Timing analysis mode : multi corner' in text
    if report['timing_qualified']:
        bits=sorted(D.glob('prj_tasks/**/*.sbit'),key=lambda p:p.stat().st_mtime);assert bits and bits[-1].stat().st_mtime>=started
        report['bitstream_sha256']=sha(bits[-1]);shutil.copy2(bits[-1],R/report['bitstream'])
except BaseException as e:report['error']=repr(e);raise
finally:report['finished']=datetime.datetime.now().isoformat();save();(D/'active.json').unlink(missing_ok=True)
print('PDS2025 final multi-corner timing qualified:',report['timing_qualified'],flush=True)
raise SystemExit(0 if report['timing_qualified'] else 1)
