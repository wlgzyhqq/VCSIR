"""85MHz trial: parallel branch predicates and shared ordered comparison."""
from pathlib import Path
import hashlib,json,random,re,shutil
R=Path(__file__).resolve().parents[1];S=R/'variants/cpu85-forward';D=R/'variants/cpu85-branch';assert not D.exists();D.mkdir()
j=json.loads((S/'output/reports/cpu-only-source.json').read_text())
for n in j['rtl_sources']:
 p=D/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(S/n,p)
for n in ['firmware','third_party','scripts','constraints']:shutil.copytree(S/n,D/n,ignore=shutil.ignore_patterns('__pycache__'))
shutil.copy2(S/'cpu_bench.pds',D/'cpu_bench.pds')
p=D/'rtl/core/riscv_exec.v';t=p.read_text();a=t.index('reg        branch_r;');b=t.index('reg        branch_taken_q;',a);block=t[a:b]
block=re.sub(r'    branch_taken_r  = 1\'b0;','',block)
block=re.sub(r'        branch_taken_r\s*=.*?;','',block)
block=block.replace('reg        branch_taken_r;',"""wire branch_eq_w = (opcode_ra_operand_i == opcode_rb_operand_i);
wire branch_ltu_w = less_than_unsigned_chunks(opcode_ra_operand_i, opcode_rb_operand_i);
wire branch_lts_w = (opcode_ra_operand_i[31] ^ opcode_rb_operand_i[31]) ? opcode_ra_operand_i[31] : branch_ltu_w;
wire branch_taken_r =
    ((opcode_opcode_i & `INST_JAL_MASK) == `INST_JAL) |
    ((opcode_opcode_i & `INST_JALR_MASK) == `INST_JALR) |
    (((opcode_opcode_i & `INST_BEQ_MASK) == `INST_BEQ) & branch_eq_w) |
    (((opcode_opcode_i & `INST_BNE_MASK) == `INST_BNE) & ~branch_eq_w) |
    (((opcode_opcode_i & `INST_BLT_MASK) == `INST_BLT) & branch_lts_w) |
    (((opcode_opcode_i & `INST_BGE_MASK) == `INST_BGE) & ~branch_lts_w) |
    (((opcode_opcode_i & `INST_BLTU_MASK) == `INST_BLTU) & branch_ltu_w) |
    (((opcode_opcode_i & `INST_BGEU_MASK) == `INST_BGEU) & ~branch_ltu_w);""")
t=t[:a]+block+t[b:];p.write_text(t)
# Independent RV32 signed/unsigned branch truth table; exhaustive subtype and edge pairs plus random data.
rng=random.Random(854);count=0
edges=[0,1,0xffffffff,0x80000000,0x7fffffff,0x80000001,0xfffffffe,0x7ffffffe]
for i in range(100000):
 x,y=(edges[i//8],edges[i%8]) if i<64 else (rng.getrandbits(32),rng.getrandbits(32))
 sx=x-(1<<32) if x>>31 else x;sy=y-(1<<32) if y>>31 else y
 eq=x==y;ltu=x<y;lts=bool(x>>31) if (x^y)>>31 else ltu
 old=[eq,not eq,sx<sy,sx>sy or eq,ltu,not ltu]
 new=[eq,not eq,lts,not lts,ltu,not ltu]
 assert old==new
 count+=6
(D/'output/reports').mkdir(parents=True)
j['optimization']+='; branch taken parallel predicates with shared signed/unsigned less-than and inverted BGE'
(D/'output/reports/cpu-only-source.json').write_text(json.dumps(j,indent=2)+'\n')
(D/'output/reports/branch-host.json').write_text(json.dumps(dict(passed=True,predicate_cases=count,RTL_simulation=False,whole_CPU_formal_proof=False,source_sha256=hashlib.sha256(p.read_bytes()).hexdigest()),indent=2)+'\n')
print('CPU85 branch candidate prepared;600000 predicate checks passed')
