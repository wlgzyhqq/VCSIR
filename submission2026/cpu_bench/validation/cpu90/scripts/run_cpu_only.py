"""Build the independent CPU-only project and bind its inputs. No programming."""
from pathlib import Path
import hashlib,json,subprocess,datetime
R=Path(__file__).resolve().parents[1];B=R/'build';B.mkdir(exist_ok=True)
report=json.loads((R/'output/reports/cpu-only-source.json').read_text())
inputs=report['rtl_sources']+['constraints/cpu_bench.fdc','cpu_bench.pds','firmware/cpu_only/coremark.hex']
report.update(started_at=datetime.datetime.now().isoformat(),source_sha256={n:hashlib.sha256((R/n).read_bytes()).hexdigest() for n in inputs},FPGA_programmed=False,TF_written=False,Flash_written=False)
path=R/'output/reports/cpu-only-build.json'
with (B/'cpu-only-pds.log').open('wb') as log:
 p=subprocess.Popen(['D:/pango/PDS_2022.2-SP1-Lite/bin/pds_shell.exe','-project','cpu_bench.pds','-run','gen_bit_stream'],cwd=R,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
 report['parent_pid']=p.pid;path.write_text(json.dumps(report,indent=2)+'\n');print('CPU_ONLY_PDS_PID='+str(p.pid),flush=True)
 report['exit_code']=p.wait()
timing=R/'report_timing/cpu_bench_top.rtr';report['timing_qualified']=timing.exists() and 'All Constraints Met' in timing.read_text() and 'Timing analysis mode : multi corner' in timing.read_text()
report['board_test']=False;report['finished_at']=datetime.datetime.now().isoformat();path.write_text(json.dumps(report,indent=2)+'\n')
print('CPU-only build exit',report['exit_code'],'timing qualified',report['timing_qualified'],'NOT board tested',flush=True)
raise SystemExit(report['exit_code'] or (0 if report['timing_qualified'] else 1))
