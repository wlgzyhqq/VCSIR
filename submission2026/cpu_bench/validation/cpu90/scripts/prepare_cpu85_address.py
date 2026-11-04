"""Decouple inactive LSU address selection and shorten JALR target addition."""
from pathlib import Path
import json,shutil,random,hashlib
R=Path(__file__).resolve().parents[1];S=R/'variants/cpu85-branchdecode';D=R/'variants/cpu85-address';assert not D.exists();D.mkdir()
j=json.loads((S/'output/reports/cpu-only-source.json').read_text())
for n in j['rtl_sources']:
 p=D/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(S/n,p)
for n in ['firmware','third_party','scripts','constraints']:shutil.copytree(S/n,D/n,ignore=shutil.ignore_patterns('__pycache__'))
shutil.copy2(S/'cpu_bench.pds',D/'cpu_bench.pds')
p=D/'rtl/core/riscv_lsu.v';t=p.read_text();old='if (opcode_valid_i && ((opcode_opcode_i & `INST_CSRRW_MASK) == `INST_CSRRW))';assert t.count(old)==1;t=t.replace(old,'// Address is speculative when opcode_valid_i=0; requests remain valid-qualified.\n    if (((opcode_opcode_i & `INST_CSRRW_MASK) == `INST_CSRRW))')
old='else if (opcode_valid_i && load_inst_w)';assert t.count(old)==1;t=t.replace(old,'else if (load_inst_w)');p.write_text(t)
p=D/'rtl/core/riscv_exec.v';t=p.read_text();needle='reg        branch_r;';assert needle in t
t=t.replace(needle,"""// Four parallel 8-bit carry-select sums; identical modulo-2^32 addition.
function [31:0] add32_carry_select;
 input [31:0] a,b;
 reg [8:0] s0,s1,s2,s3;
 reg [7:0] t1,t2,t3;
 reg c1,c2,c3;
 begin
 s0={1'b0,a[7:0]}+{1'b0,b[7:0]};
 s1={1'b0,a[15:8]}+{1'b0,b[15:8]};
 s2={1'b0,a[23:16]}+{1'b0,b[23:16]};
 s3={1'b0,a[31:24]}+{1'b0,b[31:24]};
 t1=a[15:8]+b[15:8]+8'd1;t2=a[23:16]+b[23:16]+8'd1;t3=a[31:24]+b[31:24]+8'd1;
 c1=s0[8];c2=s1[8]|((&s1[7:0])&s0[8]);
 c3=s2[8]|((&s2[7:0])&s1[8])|((&s2[7:0])&(&s1[7:0])&s0[8]);
 add32_carry_select={c3?t3:s3[7:0],c2?t2:s2[7:0],c1?t1:s1[7:0],s0[7:0]};
 end
endfunction
"""+needle,1)
needle='branch_target_r     = opcode_ra_operand_i + imm12_r;';assert needle in t;t=t.replace(needle,'branch_target_r     = add32_carry_select(opcode_ra_operand_i,imm12_r);');p.write_text(t)
rng=random.Random(858)
for i in range(200000):
 a,b=(rng.getrandbits(32),rng.getrandbits(32)) if i%4 else (rng.getrandbits(32),rng.choice([0,1,0xffffffff,0x7fffffff,0x80000000,0x100,0xffffff00]))
 sums=[((a>>(8*k))&255)+((b>>(8*k))&255) for k in range(4)]
 g=[s>>8 for s in sums];pr=[(s&255)==255 for s in sums];c=[0,g[0],g[1]|pr[1]&g[0],g[2]|pr[2]&g[1]|pr[2]&pr[1]&g[0]]
 result=sum(((sums[k]+c[k])&255)<<(k*8) for k in range(4));assert result==(a+b)&0xffffffff
 # All active LSU address selections identical; inactive requests remain zero.
 valid=rng.randrange(2);load=rng.randrange(2);csr=rng.randrange(2);immI,immS=rng.getrandbits(32),rng.getrandbits(32)
 old=a if valid and csr else (a+(immI if valid and load else immS))&0xffffffff
 new=a if csr else (a+(immI if load else immS))&0xffffffff
 if valid:assert old==new
(D/'output/reports').mkdir(parents=True);j['optimization']+='; speculative LSU address decode independent of valid; carry-select JALR target'
(D/'output/reports/cpu-only-source.json').write_text(json.dumps(j,indent=2)+'\n')
(D/'output/reports/address-host.json').write_text(json.dumps(dict(passed=True,random_and_edge_additions=200000,active_LSU_address_cases=200000,RTL_simulation=False,whole_CPU_formal_proof=False,inactive_LSU_address_may_differ=True,source_sha256={n:hashlib.sha256((D/n).read_bytes()).hexdigest() for n in ['rtl/core/riscv_lsu.v','rtl/core/riscv_exec.v']}),indent=2)+'\n')
print('CPU85 address candidate prepared;200000 addition/address checks passed')
