"""Clone the independent predecode experiment for bounded clock/control trials."""
from pathlib import Path
import argparse,json,re,shutil
R=Path(__file__).resolve().parents[1];ap=argparse.ArgumentParser();ap.add_argument('--kind',choices=['70','75raw'],required=True);a=ap.parse_args()
S=R/'variants/cpu75-predecode';D=R/'variants'/('cpu70-predecode' if a.kind=='70' else 'cpu75-raw-predecode');assert not D.exists();D.mkdir()
j=json.loads((S/'output/reports/cpu-only-source.json').read_text())
for n in j['rtl_sources']:
 p=D/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(S/n,p)
for n in ['firmware','third_party','scripts','constraints']:
 shutil.copytree(S/n,D/n,ignore=shutil.ignore_patterns('__pycache__'))
shutil.copy2(S/'cpu_bench.pds',D/'cpu_bench.pds')
if a.kind=='70':
 for n in ['firmware/cpu_only/main.c','rtl/cpu_bench/cpu_bench_top.v','scripts/build_cpu_only.py','scripts/accept_cpu_only.py']:
  p=D/n;t=p.read_text().replace('75000000','70000000').replace('75MHz','70MHz').replace('/seconds/75','/seconds/70');p.write_text(t)
 p=D/'rtl/cpu_bench/cpu_bench_pll.v';t=p.read_text()
 for n,v in [('STATIC_RATIO0',20),('STATIC_DUTY0',20),('STATIC_RATIOF',28)]:t,count=re.subn(r'(localparam integer '+n+r'\s*=\s*)\d+',lambda m:m[1]+str(v),t);assert count==1
 p.write_text(t)
 p=D/'constraints/cpu_bench.fdc';p.write_text(p.read_text().replace('-multiply_by {3} -divide_by {2}','-multiply_by {7} -divide_by {5}'))
 j['CPU_target_hz']=70000000
else:
 p=D/'rtl/core/riscv_decode.v';t=p.read_text();s=t.index('if (EXTRA_DECODE_STAGE)');e=t.index('// Straight through decode',s);block=t[s:e]
 block=block.replace('.valid_i(fetch_in_valid_i)',".valid_i(1'b1)").replace('.fetch_fault_i(fetch_in_fault_page_i | fetch_in_fault_fetch_i)',".fetch_fault_i(1'b0)").replace('.opcode_i(fetch_in_instr_w)','.opcode_i(fetch_in_instr_i)')
 block=block.replace('wire [7:0] decoded_in;','wire [7:0] decoded_in;\n    wire buffered_fault=buffer_q[65] || buffer_q[64];')
 block=block.replace('assign fetch_out_instr_invalid_o = buffer_q[67];','assign fetch_out_instr_invalid_o = buffer_q[66] && (buffered_fault || buffer_q[67]);')
 block=block.replace('assign fetch_out_instr_csr_o = buffer_q[73];','assign fetch_out_instr_csr_o = buffered_fault || (buffer_q[73] && !buffer_q[67]) || fetch_out_instr_invalid_o;')
 for n,bit in [('exec',68),('lsu',69),('branch',70),('mul',71),('div',72),('rd_valid',74)]:block=block.replace(f'assign fetch_out_instr_{n}_o = buffer_q[{bit}];',f'assign fetch_out_instr_{n}_o = !buffered_fault && buffer_q[{bit}];')
 p.write_text(t[:s]+block+t[e:]);j['optimization']='Raw instruction classification before buffer; validity/fetch-fault gating after same buffer, preserving old observable flags'
(D/'output/reports').mkdir(parents=True);(D/'output/reports/cpu-only-source.json').write_text(json.dumps(j,indent=2)+'\n')
print('Prepared',D.relative_to(R))
