"""Pipeline predictor training and factor legality checks by base opcode."""
from pathlib import Path
import json,shutil,random,hashlib,re,collections
R=Path(__file__).resolve().parents[1];S=R/'variants/cpu85-cachecontrol';D=R/'variants/cpu85-decodepipe';assert not D.exists();D.mkdir()
j=json.loads((S/'output/reports/cpu-only-source.json').read_text())
for n in j['rtl_sources']:
 p=D/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(S/n,p)
for n in ['firmware','third_party','scripts','constraints']:shutil.copytree(S/n,D/n,ignore=shutil.ignore_patterns('__pycache__'))
shutil.copy2(S/'cpu_bench.pds',D/'cpu_bench.pds')
p=D/'rtl/core/riscv_decoder.v';t=p.read_text();defs={k:int(v,16) for k,v in re.findall(r"`define\s+(INST_\w+)\s+32'h([0-9a-fA-F]+)",(D/'rtl/core/riscv_defs.v').read_text())}
a=t.index('wire invalid_w =');b=t.index('assign invalid_o',a);old=t[a:b];names=re.findall(r'\(opcode_i & `INST_(\w+)_MASK\) == `INST_\1',old);assert len(names)>50 and len(names)==len(set(names))
M=set(['MUL','MULH','MULHSU','MULHU','DIV','DIVU','REM','REMU']);groups=collections.defaultdict(list)
for n in names:
 mask,val=defs['INST_'+n+'_MASK'],defs['INST_'+n];assert mask&127==127;groups[val&127].append((n,mask&0xffffff80,val&0xffffff80))
lines=[]
for op,terms in groups.items():
 expr=[]
 for n,m,v in terms:
  q="1'b1" if not m else f"((opcode_i & 32'h{m:08x}) == 32'h{v:08x})"
  if n in M:q='(enable_muldiv_i && '+q+')'
  expr.append(q)
 lines.append(f'wire legal_{op:02x} /* synthesis syn_keep=1 */ = '+' | '.join(expr)+';')
lines.append('wire legal_w = '+' | '.join(f"((opcode_i[6:0] == 7'h{op:02x}) && legal_{op:02x})" for op in groups)+';')
lines.append('wire invalid_w = valid_i && !legal_w;\n')
t=t[:a]+'\n'.join(lines)+'\n'+t[b:];p.write_text(t)
p=D/'rtl/final_btb.v';t=p.read_text();needle=' reg [31:0] tags[0:31], targets[0:31];';assert needle in t
t=t.replace(needle,""" // Training is delayed one cycle; retirement/control flow is unchanged.
 reg update_q,taken_q;
 reg [31:0] update_pc_q,target_q;
 always @(posedge clk or posedge rst)
 if(rst)begin update_q<=0;taken_q<=0;update_pc_q<=0;target_q<=0;end
 else if(invalidate)update_q<=0;
 else begin
  update_q<=update;
  if(update)begin taken_q<=taken;update_pc_q<=update_pc;target_q<=target;end
 end
"""+needle,1)
t=t.replace('upd=update_pc[6:2]','upd=update_pc_q[6:2]').replace('else if(update && target[1:0]==0)','else if(update_q && target_q[1:0]==0)').replace('tags[upd]<=update_pc; targets[upd]<=target;','tags[upd]<=update_pc_q; targets[upd]<=target_q;').replace('tags[upd]!=update_pc','tags[upd]!=update_pc_q').replace('counters[upd]<=taken?2:1','counters[upd]<=taken_q?2:1').replace('counter_step(counters[upd],taken)','counter_step(counters[upd],taken_q)');p.write_text(t)
# All existing absolute core includes referenced original FINAL; make this variant self-contained.
changed=[]
for n in j['rtl_sources']:
 p=D/n;txt=p.read_text();new=re.sub(r'(`include ")C:/Users/33791/Desktop/project/learn verilog/FINAL/',r'\1',txt)
 if new!=txt:p.write_text(new);changed.append(n)
rng=random.Random(8510);cases=0
for n in range(200000):
 if n%2:
  name=rng.choice(names);mask=defs['INST_'+name+'_MASK'];word=(rng.getrandbits(32)&~mask)|defs['INST_'+name]
  if n%7==0:word^=1<<rng.randrange(32)
 else:word=rng.getrandbits(32)
 for en in [False,True]:
  old=any((en or name not in M) and (word&defs['INST_'+name+'_MASK'])==defs['INST_'+name] for name in names)
  new=any((word&127)==op and any((en or name not in M) and (word&mask)==val for name,mask,val in terms) for op,terms in groups.items())
  assert old==new;cases+=1
(D/'output/reports').mkdir(parents=True);j['optimization']+='; one-cycle predictor training pipeline; base-opcode legality factoring; local include paths'
(D/'output/reports/cpu-only-source.json').write_text(json.dumps(j,indent=2)+'\n')
(D/'output/reports/decodepipe-host.json').write_text(json.dumps(dict(passed=True,legality_equivalence_cases=cases,legal_instruction_patterns=len(names),RTL_simulation=False,whole_CPU_formal_proof=False,predictor_training_latency_added=1,architectural_pipeline_cycles_added=0,local_include_files=changed,source_sha256={n:hashlib.sha256((D/n).read_bytes()).hexdigest() for n in ['rtl/core/riscv_decoder.v','rtl/final_btb.v']}),indent=2)+'\n')
print('CPU85 decoder/predictor candidate prepared;'+str(cases)+' legal instruction equivalence checks passed')
