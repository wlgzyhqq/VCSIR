"""Capture branch comparator selects alongside existing decode sideband."""
from pathlib import Path
import json,shutil,random,hashlib
R=Path(__file__).resolve().parents[1];S=R/'variants/cpu85-sideband';D=R/'variants/cpu85-branchdecode';assert not D.exists();D.mkdir()
j=json.loads((S/'output/reports/cpu-only-source.json').read_text())
for n in j['rtl_sources']:
 p=D/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(S/n,p)
for n in ['firmware','third_party','scripts','constraints']:shutil.copytree(S/n,D/n,ignore=shutil.ignore_patterns('__pycache__'))
shutil.copy2(S/'cpu_bench.pds',D/'cpu_bench.pds')
p=D/'rtl/core/riscv_core.v';t=p.read_text();t=t.replace('wire [4:0] rf_ra_copy_w,rf_rb_copy_w;',"""wire [4:0] rf_ra_copy_w,rf_rb_copy_w;
wire [4:0] branch_select_w;
function [4:0] branch_select;
 input [31:0] instr;
 begin
 branch_select[4]=((instr & 32'h7f)==32'h6f)||((instr & 32'h707f)==32'h67);
 branch_select[3]=((instr & 32'h707f)==32'h6063)||((instr & 32'h707f)==32'h7063);
 branch_select[2]=((instr & 32'h707f)==32'h4063)||((instr & 32'h707f)==32'h5063);
 branch_select[1]=((instr & 32'h707f)==32'h63)||((instr & 32'h707f)==32'h1063);
 branch_select[0]=instr[12];
 end
endfunction""")
t=t.replace('[105:0]','[110:0]').replace("{32'b0,5'b0,5'b0,32'b1,32'b1}","{5'b0,32'b0,5'b0,5'b0,32'b1,32'b1}")
t=t.replace('{fetch_pred_next_w,rb_in,ra_in,',"{branch_select((fetch_dec_fault_page_w || fetch_dec_fault_fetch_w)?32'b0:fetch_dec_instr_w),fetch_pred_next_w,rb_in,ra_in,")
t=t.replace('[26:0] local_update','[27:0] local_update').replace('sg<27','sg<28').replace('(sg==26)?2:4','(sg==27)?3:4')
t=t.replace('assign decode_pred_next_w=state_w[105:74];','assign decode_pred_next_w=state_w[105:74];assign branch_select_w=state_w[110:106];')
t=t.replace('assign decode_pred_next_w=fetch_pred_next_w;','assign decode_pred_next_w=fetch_pred_next_w;assign branch_select_w=branch_select(fetch_instr_w);')
t=t.replace(',.opcode_opcode_i(opcode_opcode_w)',',.opcode_opcode_i(opcode_opcode_w)\n    ,.branch_select_i(branch_select_w)',1);p.write_text(t)
p=D/'rtl/core/riscv_exec.v';t=p.read_text();t=t.replace(',input           opcode_valid_i',',input [4:0] branch_select_i\n    ,input           opcode_valid_i',1)
a=t.index('wire branch_taken_r =');b=t.index('reg [31:0] branch_target_r;',a)
t=t[:a]+"""wire branch_taken_r = branch_select_i[4] |
 (branch_select_i[1] & (branch_eq_w ^ branch_select_i[0])) |
 (branch_select_i[2] & (branch_lts_w ^ branch_select_i[0])) |
 (branch_select_i[3] & (branch_ltu_w ^ branch_select_i[0]));
"""+t[b:];p.write_text(t)
rng=random.Random(856)
for i in range(100000):
 instr=rng.getrandbits(32) if i%2 else ((rng.getrandbits(32)&~0x707f)|rng.choice([0x6f,0x67,0x63,0x1063,0x4063,0x5063,0x6063,0x7063]))
 x,y=rng.getrandbits(32),rng.getrandbits(32);sx=x-(1<<32) if x>>31 else x;sy=y-(1<<32) if y>>31 else y
 jump=(instr&0x7f)==0x6f or (instr&0x707f)==0x67
 typ=instr&0x707f;eq=typ in [0x63,0x1063];sg=typ in [0x4063,0x5063];un=typ in [0x6063,0x7063];inv=bool(instr&0x1000)
 old=jump or {0x63:x==y,0x1063:x!=y,0x4063:sx<sy,0x5063:sx>=sy,0x6063:x<y,0x7063:x>=y}.get(typ,False)
 new=jump or eq and ((x==y)^inv) or sg and ((sx<sy)^inv) or un and ((x<y)^inv)
 assert bool(old)==bool(new)
(D/'output/reports').mkdir(parents=True);j['optimization']+='; 5bit predecoded branch comparator select in existing decode stage'
(D/'output/reports/cpu-only-source.json').write_text(json.dumps(j,indent=2)+'\n')
(D/'output/reports/branchdecode-host.json').write_text(json.dumps(dict(passed=True,random_instructions_and_operands=100000,RTL_simulation=False,whole_CPU_formal_proof=False,source_sha256={n:hashlib.sha256((D/n).read_bytes()).hexdigest() for n in ['rtl/core/riscv_core.v','rtl/core/riscv_exec.v']}),indent=2)+'\n')
print('CPU85 branch predecode prepared;100000 instruction/operand checks passed')
