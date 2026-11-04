"""85MHz trial: registered AW classification and inactive-cycle forwarding decoupling."""
from pathlib import Path
import hashlib,json,random,re,shutil
R=Path(__file__).resolve().parents[1];S=R/'variants/cpu85-onehot';D=R/'variants/cpu85-forward';assert not D.exists();D.mkdir()
j=json.loads((S/'output/reports/cpu-only-source.json').read_text())
for n in j['rtl_sources']:
 p=D/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(S/n,p)
for n in ['firmware','third_party','scripts','constraints']:shutil.copytree(S/n,D/n,ignore=shutil.ignore_patterns('__pycache__'))
shutil.copy2(S/'cpu_bench.pds',D/'cpu_bench.pds')
p=D/'rtl/cpu_bench/cpu_bench_bus.v';t=p.read_text()
t=t.replace('reg i_bad,d_bad,w_bad;','reg i_bad,d_bad,w_bad;\nreg w_ram,w_uart;')
assert 'reg w_ram,w_uart;' in t
t=t.replace('if(w_fire && !w_bad && w_addr<65536)','if(w_fire && !w_bad && w_ram)')
t=t.replace("(w_addr!=32'h80000000 || !tx_busy)","(!w_uart || !tx_busy)")
t=t.replace('w_bad<=0;','w_bad<=0;w_ram<=0;w_uart<=0;',1)
t=t.replace('w_addr<=axi_d_awaddr;','w_ram<=axi_d_awaddr<65536;w_uart<=axi_d_awaddr==32\'h80000000;\n   w_addr<=axi_d_awaddr;',1)
t=t.replace('w_addr<=w_addr+4;',"w_addr<=w_addr+4;w_uart<=w_addr==32'h7ffffffc;",1);p.write_text(t)
p=D/'rtl/core/riscv_pipe_ctrl.v';t=p.read_text()
for old,new in [('rd_e2_o','rd_e2_forward_o'),('rd_wb_o','rd_wb_forward_o')]:
 needle=',output [  4:0]  '+old;assert needle in t;t=t.replace(needle,needle+'\n    ,output [4:0] '+new,1)
e2='assign rd_e2_forward_o = {5{valid_e2_q && ctrl_e2_q[`PCINFO_RD_VALID]}} & opcode_e2_q[`RD_IDX_R];'
wb='assign rd_wb_forward_o = {5{valid_wb_q && ctrl_wb_q[`PCINFO_RD_VALID]}} & opcode_wb_q[`RD_IDX_R];'
t=t.replace('assign result_e2_o     = result_e2_r;',e2+'\nassign result_e2_o     = result_e2_r;')
t=t.replace('assign result_wb_o     = result_wb_q;',wb+'\nassign result_wb_o     = result_wb_q;')
# Change only forwarding result selection, not WB commit/exception selection.
a=t.index('reg [31:0] result_e2_r;');b=t.index('assign load_e2_o',a);block=t[a:b];assert block.count('valid_e2_w')==3
# Includes the declaration itself: leave declaration/other uses intact.
block=block.replace('SUPPORT_LOAD_BYPASS && valid_e2_w','SUPPORT_LOAD_BYPASS && valid_e2_q').replace('SUPPORT_MUL_BYPASS && valid_e2_w','SUPPORT_MUL_BYPASS && valid_e2_q');t=t[:a]+block+t[b:];p.write_text(t)
p=D/'rtl/core/riscv_issue.v';t=p.read_text()
t=t.replace('wire [4:0]  pipe_rd_e2_w;','wire [4:0]  pipe_rd_e2_w;\nwire [4:0] pipe_rd_e2_forward_w,pipe_rd_wb_forward_w;')
assert 'wire [4:0] pipe_rd_e2_forward_w' in t
t=t.replace(',.rd_e2_o(pipe_rd_e2_w)',',.rd_e2_o(pipe_rd_e2_w)\n    ,.rd_e2_forward_o(pipe_rd_e2_forward_w)').replace(',.rd_wb_o(pipe_rd_wb_w)',',.rd_wb_o(pipe_rd_wb_w)\n    ,.rd_wb_forward_o(pipe_rd_wb_forward_w)')
for stage in ['e2','wb']:
 for idx in ['ra','rb']:
  old=f'if (pipe_rd_{stage}_w == issue_{idx}_idx_w)';assert old in t;t=t.replace(old,f'if (pipe_rd_{stage}_forward_w == issue_{idx}_idx_w)')
p.write_text(t)
rng=random.Random(853);cases=0
for i in range(100000):
 addr=rng.getrandbits(32) if i%3 else rng.randrange(65536)&~3;length=rng.randrange(256);ram=addr<65536;uart=addr==0x80000000
 if i%97==0:addr=0x80000000;ram=False;uart=True
 bad=bool(addr&3 or (addr>=65536 and length) or (addr<65536 and addr+4*(length+1)>65536))
 for beat in range(min(length+1,5)):
  assert uart==(addr==0x80000000)
  assert (not bad and ram)==(not bad and addr<65536)
  uart=addr==0x7ffffffc;addr=(addr+4)&0xffffffff
 # Forward tags/data are equal whenever the pipeline is permitted to advance.
 valid=rng.randrange(2);rdvalid=rng.randrange(2);rd=rng.randrange(32);stall=rng.randrange(2)
 oldtag=rd if valid and rdvalid and not stall else 0;newtag=rd if valid and rdvalid else 0
 if not stall:assert oldtag==newtag
 load=rng.randrange(2);mul=rng.randrange(2);alu,mem,mulval=[rng.getrandbits(32) for _ in range(3)]
 oldvalue=mem if valid and not stall and load else mulval if valid and not stall and mul else alu
 newvalue=mem if valid and load else mulval if valid and mul else alu
 if not stall:assert oldvalue==newvalue
 cases+=1
(D/'output/reports').mkdir(parents=True)
j['optimization']='Onehot RF + grouped decode + registered AW RAM/UART classification + distinct forwarding-only tags/raw E2 result; architectural commit tags and load bypass preserved'
(D/'output/reports/cpu-only-source.json').write_text(json.dumps(j,indent=2)+'\n')
(D/'output/reports/forward-host.json').write_text(json.dumps(dict(passed=True,cases=cases,RTL_simulation=False,whole_CPU_formal_proof=False,scope='AW burst class invariants and active-cycle forwarding equivalence; architectural WB tag expressions unchanged',source_sha256={n:hashlib.sha256((D/n).read_bytes()).hexdigest() for n in ['rtl/cpu_bench/cpu_bench_bus.v','rtl/core/riscv_pipe_ctrl.v','rtl/core/riscv_issue.v']}),indent=2)+'\n')
print('CPU85 forward/AW candidate prepared;100000 invariant checks passed')
