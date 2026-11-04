"""Volatile JTAG of timing-qualified CPU-only image; capture serial CoreMark."""
from pathlib import Path
import argparse,hashlib,json,re,subprocess,time
from serial_transport import Serial
R=Path(__file__).resolve().parents[1]
ap=argparse.ArgumentParser();ap.add_argument('--ports',nargs='+',default=['COM12','COM11']);a=ap.parse_args()
build=json.loads((R/'output/reports/cpu-only-build.json').read_text());assert build['exit_code']==0 and build['timing_qualified']
t=R/'report_timing/cpu_bench_top.rtr';assert 'All Constraints Met' in t.read_text() and 'Timing analysis mode : multi corner' in t.read_text()
for n,h in build['source_sha256'].items():
 if n!='cpu_bench.pds':assert hashlib.sha256((R/n).read_bytes()).hexdigest()==h,n
bit=R/'generate_bitstream/cpu_bench_top.sbit';sha=hashlib.sha256(bit.read_bytes()).hexdigest()
report=dict(passed=False,bitstream_sha256=sha,board_test=True,CPU_hz=90000000,timer_hz=90000000,TF_written=False,Flash_written=False,transcripts={},serial_errors={},footer_host_times={})
path=R/'output/reports/cpu-only-board.json'
def save():path.write_text(json.dumps(report,indent=2)+'\n')
save()
script=f'cfg_set_tcl_break -flag true\ncfg_connect -ip 127.0.0.1 -port 65420\ncfg_scan_chain\ncfg_assign_file -file {{{bit.as_posix()}}} -device_index 0\ncfg_program -device_index 0\ncfg_read_device_property -device_index 0 -mode 3\nexit\n'
log=R/'output/reports/cpu-only-jtag.log'
with log.open('wb') as f:
 p=subprocess.run(['D:/pango/PDS_2022.2-SP1-Lite/bin/cdt_cfg_shell.exe'],input=script.encode(),stdout=f,stderr=subprocess.STDOUT,timeout=55,creationflags=subprocess.CREATE_NO_WINDOW)
text=log.read_text(errors='replace');assert p.returncode==0 and not re.search(r'^E:',text,re.M) and 'Executing : cfg_program -device_index 0 successfully.' in text and re.search(r'Bit 12:\s+1\s+done',text),text[-2000:]
report['JTAG_programmed']=True;save();print('CPU-only image programmed',sha,flush=True)
ports={};data={}
try:
 for name in a.ports:
  try:ports[name]=Serial(name);data[name]=bytearray()
  except OSError as e:report['serial_errors'][name]=str(e)
 save();assert ports,'No requested serial port could be opened'
 deadline=time.monotonic()+240
 while time.monotonic()<deadline:
  for name,s in ports.items():
   chunk=s.read()
   if chunk:
    data[name].extend(chunk);print(name,chunk.decode('ascii','replace'),end='',flush=True)
    complete=re.findall(rb'@CM_RAW [0-9a-f ]+\r',data[name]);times=report['footer_host_times'].setdefault(name,[])
    while len(times)<len(complete):times.append(time.monotonic())
  if any(b'@CPU_ONLY PASS' in raw or b'@CPU_ONLY FAIL' in raw for raw in data.values()):break
 for name,raw in data.items():
  target=R/f'output/reports/cpu-only-{name}.log';target.write_bytes(raw);report['transcripts'][name]=target.relative_to(R).as_posix()
 candidates=[raw.decode('ascii','replace') for raw in data.values() if b'@CM_RAW' in raw];assert len(candidates)==1,'No unambiguous CPU benchmark output'
 raw=candidates[0];fields=[[int(v,16) for v in m.split()] for m in re.findall(r'@CM_RAW ([0-9a-f ]+)',raw)]
 assert len(fields)==2 and {f[1] for f in fields}=={0,1}
 runs=[]
 for f in fields:
  assert len(f)==8 and f[0]==1 and f[2]==3000 and f[3:5]==[90000000,90000000] and f[7]==1,f
  seconds=(f[5]+(f[6]<<32))/f[4];assert seconds>=10,seconds
  runs.append(dict(validation_seed=f[1],iterations=f[2],seconds=seconds,CoreMark=f[2]/seconds,CoreMark_per_MHz=f[2]/seconds/90,raw_fields=f))
 assert '@CPU_ONLY PASS' in raw
 active=next(name for name,buf in data.items() if b'@CM_RAW' in buf)
 times=report['footer_host_times'][active];assert len(times)==2
 wall=times[1]-times[0];report['second_run_host_seconds']=wall
 report['second_run_host_vs_timer_ratio']=wall/runs[1]['seconds']
 assert abs(wall/runs[1]['seconds']-1)<0.03,'Host time vs reported CPU-clock timer mismatch'
 report.update(passed=True,runs=runs)
 print('\nCPU-only actual CoreMark PASS',runs,flush=True)
finally:
 for s in ports.values():s.close()
 for name,raw in data.items():(R/f'output/reports/cpu-only-{name}.log').write_bytes(raw)
 save()
