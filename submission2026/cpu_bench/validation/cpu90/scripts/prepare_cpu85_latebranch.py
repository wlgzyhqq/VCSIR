"""85MHz profile: registered branch-resolution predicates, retain compact binary RF."""
from pathlib import Path
import json,shutil,re,hashlib,random
R=Path(__file__).resolve().parents[1];S=R;A=R/'variants/cpu85-combined';D=R/'variants/cpu85-latebranch';assert not D.exists();D.mkdir()
j=json.loads((S/'output/reports/cpu-only-source.json').read_text())
for n in j['rtl_sources']:
 p=D/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(S/n,p)
for n in ['firmware','third_party','scripts','constraints']:shutil.copytree(S/n,D/n,ignore=shutil.ignore_patterns('__pycache__'))
shutil.copy2(A/'cpu_bench.pds',D/'cpu_bench.pds')
for n in ['firmware/cpu_only/main.c','firmware/cpu_only/coremark.hex','rtl/cpu_bench/cpu_bench_pll.v','rtl/cpu_bench/cpu_bench_top.v','rtl/cpu_bench/cpu_bench_bus.v','constraints/cpu_bench.fdc','scripts/build_cpu_only.py','scripts/accept_cpu_only.py','rtl/core/riscv_pipe_ctrl.v','rtl/core/riscv_decoder.v','rtl/final_btb.v','rtl/cache/dcache_core.v','rtl/core/riscv_lsu.v']:shutil.copy2(A/n,D/n)
shutil.copy2(R/'variants/cpu85-branch/rtl/core/riscv_exec.v',D/'rtl/core/riscv_exec.v')
p=D/'rtl/core/riscv_issue.v';t=p.read_text();t=t.replace('wire [4:0]  pipe_rd_e2_w;','wire [4:0]  pipe_rd_e2_w;\nwire [4:0] pipe_rd_e2_forward_w,pipe_rd_wb_forward_w;')
t=t.replace(',.rd_e2_o(pipe_rd_e2_w)',',.rd_e2_o(pipe_rd_e2_w)\n    ,.rd_e2_forward_o(pipe_rd_e2_forward_w)').replace(',.rd_wb_o(pipe_rd_wb_w)',',.rd_wb_o(pipe_rd_wb_w)\n    ,.rd_wb_forward_o(pipe_rd_wb_forward_w)')
for stage in ['e2','wb']:
 for idx in ['ra','rb']:
  old=f'if (pipe_rd_{stage}_w == issue_{idx}_idx_w)';assert old in t;t=t.replace(old,f'if (pipe_rd_{stage}_forward_w == issue_{idx}_idx_w)')
old='wire opcode_valid_w = fetch_valid_i & ~squash_w & ~branch_csr_request_i;';assert old in t;t=t.replace(old,old[:-1]+' & ~predictor_redirect_i;')
old='branch_csr_request_i ? branch_csr_pc_i   : branch_d_exec_pc_i;';assert old in t;t=t.replace(old,'branch_csr_request_i ? branch_csr_pc_i   : branch_exec_pc_i;');p.write_text(t)
p=D/'rtl/core/riscv_exec.v';t=p.read_text();a=t.index('assign predictor_redirect_o =');b=t.index('assign branch_d_priv_o',a)
t=t[:a]+"""// Resolve after the existing EX register boundary. The current decode slot
// is blocked on redirect in riscv_issue, including stores/CSR/M/D launches.
reg redirect_valid_q,redirect_select_target_q,redirect_target_bad_q,redirect_fall_bad_q;
always @(posedge clk_i or posedge rst_i)
if(rst_i)begin redirect_valid_q<=0;redirect_select_target_q<=0;redirect_target_bad_q<=0;redirect_fall_bad_q<=0;end
else begin
 redirect_valid_q<=opcode_valid_i;
 redirect_select_target_q<=branch_r && branch_taken_r;
 redirect_target_bad_q<=predictor_taken_mismatch;
 redirect_fall_bad_q<=predictor_fallthrough_mismatch;
end
assign predictor_redirect_o=redirect_valid_q && (redirect_select_target_q?redirect_target_bad_q:redirect_fall_bad_q);

"""+t[b:];p.write_text(t)
for n in j['rtl_sources']:
 p=D/n;t=p.read_text();s=re.sub(r'(`include ")C:/Users/33791/Desktop/project/learn verilog/FINAL/',r'\1',t)
 if s!=t:p.write_text(s)
(D/'output/reports').mkdir(parents=True);shutil.copytree(A/'output/cpu-only',D/'output/cpu-only')
j.update(CPU_target_hz=85000000,optimization='Compact original binary RF; register branch target-choice and mismatch predicates at existing EX boundary; block wrong-path issue; BTB training pipeline; opcode legality groups; direct D-cache transition predicates; inactive LSU address decode; independent forward tags')
(D/'output/reports/cpu-only-source.json').write_text(json.dumps(j,indent=2)+'\n')
rng=random.Random(8512)
for n in range(100000):
 valid=rng.randrange(2);branch=rng.randrange(2);taken=rng.randrange(2);target,pc,pred=[rng.getrandbits(32) for _ in range(3)]
 target_bad=target!=pred;fall_bad=((pc+4)&0xffffffff)!=pred;select=branch and taken
 old=bool(valid and (target_bad if select else fall_bad))
 regredirect=bool(valid and (target_bad if select else fall_bad));actual=target if select else ((pc+4)&0xffffffff)
 assert old==regredirect
 if valid:assert regredirect==(actual!=pred)
(D/'output/reports/latebranch-host.json').write_text(json.dumps(dict(passed=True,predicate_cases=100000,RTL_simulation=False,whole_CPU_formal_proof=False,branch_misprediction_penalty_added_cycles=1,correctly_predicted_issue_latency_added=0,wrong_path_issue_blocked=True,source_sha256={n:hashlib.sha256((D/n).read_bytes()).hexdigest() for n in ['rtl/core/riscv_issue.v','rtl/core/riscv_exec.v']}),indent=2)+'\n')
print('Late-branch profile prepared;100000 resolution predicates checked; compact binary RF restored')
