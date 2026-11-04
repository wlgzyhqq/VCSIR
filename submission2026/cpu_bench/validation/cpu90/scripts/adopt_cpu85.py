"""Adopt a measured 85MHz source/bitstream pair; retain accepted CPU-only75 snapshot."""
from pathlib import Path
import hashlib,json,re,shutil,datetime,argparse
R=Path(__file__).resolve().parents[1]
ap=argparse.ArgumentParser();ap.add_argument('variant');args=ap.parse_args();S=(R/'variants'/args.variant).resolve();assert S.parent==R/'variants'
read=lambda p:json.loads(p.read_text(encoding='utf-8'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
board=read(S/'output/reports/cpu-only-board.json');build=read(S/'output/reports/cpu-only-build.json')
assert board['passed'] and board['CPU_hz']==85000000 and build['timing_qualified'] and build['exit_code']==0
assert abs(board['second_run_host_vs_timer_ratio']-1)<.03
bit=S/'generate_bitstream/cpu_bench_top.sbit';assert sha(bit)==board['bitstream_sha256']
timing=S/'report_timing/cpu_bench_top.rtr';assert 'All Constraints Met' in timing.read_text() and 'Timing analysis mode : multi corner' in timing.read_text()
assert '85.000 MHz' in timing.read_text()
for n,h in build['source_sha256'].items():
 if n!='cpu_bench.pds':assert sha(S/n)==h,n
# Assert the frozen old baseline remains recoverable before replacing defaults.
baseline=R/'baseline/cpu-only50';snap=read(baseline/'snapshot.json')
for row in snap['files']:assert sha(baseline/row['file'])==row['sha256']
# Freeze the currently accepted 75MHz delivery before adopting faster source.
old_delivery=read(R/'output/reports/cpu-only-delivery.json')
assert old_delivery['CPU_hz']==75000000
assert board['runs'][0]['CoreMark'] > old_delivery['runs'][0]['CoreMark'], '85MHz score does not exceed accepted75MHz'
saved=R/'baseline/cpu-only75';assert not saved.exists()
saved.mkdir(parents=True)
rows=[]
names=set(old_delivery['files'])|{'output/reports/cpu-only-delivery.json','CPU_ONLY_RESULTS.md','README.md'}
for n in sorted(names):
 p=R/n
 assert p.is_file(),n
 q=saved/n;q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,q)
 rows.append(dict(file=n,sha256=sha(q)))
(saved/'snapshot.json').write_text(json.dumps(dict(files=rows,CPU_hz=75000000,board_verified=True),indent=2)+'\n')
files={}
def copy(src,name):
 p=R/name;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,p);assert sha(src)==sha(p)
 files[name]=dict(source=src.relative_to(R).as_posix(),sha256=sha(p))
for n in build['source_sha256']:
 copy(S/n,n)
copy(S/'cpu_bench.pds','final2.pds')
for folder in ['firmware/cpu_only','output/cpu-only','output/reports','compile','synthesize','device_map','place_route','report_timing','generate_netlist','generate_bitstream','report_power']:
 if not (S/folder).exists():continue
 for p in (S/folder).rglob('*'):
  if p.is_file() and p.suffix not in ['.lock','.pyc']:copy(p,folder+'/'+p.relative_to(S/folder).as_posix())
for n in ['build_cpu_only.py','run_cpu_only.py','accept_cpu_only.py','serial_transport.py']:copy(S/'scripts'/n,'scripts/'+n)
copy(S/'build/cpu-only-pds.log','build/cpu-only-pds.log')
copy(bit,'output/bitstream/cpu_only_85MHz.sbit')
def resource(path):
 result={}
 for line in path.read_text().splitlines():
  if not line.startswith('|'):continue
  row=[v.strip() for v in line.strip('|').split('|')]
  if len(row)<3 or not re.fullmatch(r'\d+(?:\.\d+)?',row[1]):continue
  key=row[0].removeprefix('Use of ')
  if key in ['LUT','FF']:result[key]=result.get(key,0)+float(row[1])
  elif row[0].startswith('Use of '):result[key]=float(row[1])
 return result
physical=resource(S/'place_route/cpu_bench_top.prr')
row=next(line for line in (S/'synthesize/cpu_bench_top.snr').read_text().splitlines() if line.startswith('| + u_cpu '))
v=[s.strip() for s in row.strip('|').split('|')]
core=dict(LUT=int(v[1]),FF=int(v[2]),APM=float(v[4]),DRM=float(v[5]),scope='u_cpu including I/D caches; SYNTHESIS hierarchy, not a post-route per-instance attribution')
old=read(baseline/'output/reports/cpu-only-board.json')
report=dict(passed=True,adopted_at=datetime.datetime.now().isoformat(),CPU_hz=85000000,timer_hz=85000000,
 bitstream='output/bitstream/cpu_only_85MHz.sbit',sha256=sha(bit),firmware_sha256=sha(S/'output/cpu-only/coremark.bin'),
 runs=board['runs'],baseline_runs=old['runs'],score_speedup=board['runs'][0]['CoreMark']/old['runs'][0]['CoreMark'],
 performance_cycles_identical=board['runs'][0]['raw_fields'][5:7]==old['runs'][0]['raw_fields'][5:7],
 physical_minimal_system_resources=physical,CPU_with_caches_synthesis_resources=core,
 CoreMark_per_CPU_synthesis_LUT=board['runs'][0]['CoreMark']/core['LUT'],
 timing='All Constraints Met',setup_slack_ns=float(re.search(r'cpu_clk\s+85\.000 MHz\s+([0-9.]+) MHz\s+[0-9.]+\s+[0-9.]+\s+(-?[0-9.]+)',timing.read_text())[2]),tool_estimated_Fmax_MHz=float(re.search(r'cpu_clk\s+85\.000 MHz\s+([0-9.]+) MHz',timing.read_text())[1]),highest_board_verified_MHz=85,
 host_vs_timer_ratio=board['second_run_host_vs_timer_ratio'],files=files,
 branch_misprediction_penalty_added_cycles=1,predictor_training_latency_added_cycles=1,
 baseline75_runs=old_delivery['runs'],speedup_over75=board['runs'][0]['CoreMark']/old_delivery['runs'][0]['CoreMark'],
 rejected_trials=[dict(name=p.name,downloaded=False) for p in (R/'variants').glob('cpu85-*') if p.resolve()!=S],
 board_validation_scope='CoreMark performance and validation seeds, official CRCs and >=10s, host elapsed vs timer; not a newly completed exhaustive ISA/interrupt regression',
 original_FINAL_changed=False,TF_written=False,Flash_written=False)
(R/'output/reports/cpu-only-delivery.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Adopted measured CPU-only85:',report['sha256'],physical,core,flush=True)
