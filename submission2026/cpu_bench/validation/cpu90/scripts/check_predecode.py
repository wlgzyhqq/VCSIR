"""Evaluate production decoder expressions and abstract register-transition equivalence.
Not RTL simulation or an ISA/formal proof of the complete CPU.
"""
from pathlib import Path
import argparse,hashlib,json,random,re
ap=argparse.ArgumentParser();ap.add_argument('--raw',action='store_true');a=ap.parse_args()
R=Path(__file__).resolve().parents[1];D=R/'variants'/('cpu75-raw-predecode' if a.raw else 'cpu75-predecode')
defs=(R/'rtl/core/riscv_defs.v').read_text();macros={}
for n,w,base,val in re.findall(r'`define\s+(\w+)\s+(\d+)\s*\x27([hbd])([0-9a-fA-F_]+)',defs):
 macros[n]=int(val.replace('_',''),{'h':16,'b':2,'d':10}[base])
text=(R/'rtl/core/riscv_decoder.v').read_text()
exprs={}
for n,e in re.findall(r'(?:wire\s+|assign\s+)(\w+)\s*=\s*(.*?);',text,re.S):
 e=re.sub(r'`(\w+)',lambda m:str(macros[m[1]]),e)
 e=e.replace('&&',' and ').replace('||',' or ').replace('~(','not (')
 exprs[n]=compile(' '.join(e.split()),'<production decoder '+n+'>','eval')
names=['invalid','exec','lsu','branch','mul','div','csr','rd_valid']
def decode(v,f,op,m=1):
 env=dict(valid_i=v,fetch_fault_i=f,opcode_i=op,enable_muldiv_i=m)
 env['invalid_w']=bool(eval(exprs['invalid_w'],{'__builtins__':{}},env))
 return tuple(bool(eval(exprs[n+'_o'],{'__builtins__':{}},env)) for n in names)
assert decode(0,0,0)==(False,)*8
rng=random.Random(17031);old=(0,0,0);registered=(False,)*8;checked=0
ops=[v for n,v in macros.items() if n.startswith('INST_') and not n.endswith('_MASK')]
for i in range(50000):
 valid=rng.randrange(2);fault=rng.randrange(4);op=ops[i%len(ops)] if i%3==0 else rng.getrandbits(32)
 incoming=(valid,bool(fault),0 if fault else op)
 reset=i%503==0;squash=i%19==0;ready=rng.randrange(2) or not old[0]
 # Original: latch payload then combinatorially decode it.
 if reset or squash:old=(0,0,0)
 elif ready:old=incoming
 # Candidate: decode incoming payload then latch flags using identical enables.
 if reset or squash:registered=(False,)*8
 elif ready:registered=decode(1,0,op) if a.raw else decode(*incoming)
 observed=registered
 if a.raw:
  observed=list(registered)
  observed[0]=bool(old[0] and (old[1] or registered[0]))
  for bit in [1,2,3,4,5,7]:observed[bit]=bool(not old[1] and registered[bit])
  observed[6]=bool(old[1] or (registered[6] and not registered[0]) or observed[0])
  observed=tuple(observed)
 assert decode(*old)==observed,(i,old,registered,observed)
 checked+=1
t=(D/'rtl/core/riscv_decode.v').read_text();assert 'reg [74:0] buffer_q;' in t and 'buffer_q[66:0]' in t
for i,n in enumerate(names):
 assert f'.{n}_o(decoded_in[{i}])' in t
 if not a.raw:assert f'assign fetch_out_instr_{n}_o = buffer_q[{67+i}];' in t
if a.raw:
 assert ".valid_i(1'b1)" in t and ".fetch_fault_i(1'b0)" in t and '.opcode_i(fetch_in_instr_i)' in t
 assert 'buffer_q[66] && (buffered_fault || buffer_q[67])' in t
 assert 'buffered_fault || (buffer_q[73] && !buffer_q[67]) || fetch_out_instr_invalid_o' in t
report=dict(passed=True,transitions=checked,RTL_simulation=False,whole_CPU_formal_proof=False,board_test=False,
 scope='Production decoder expression evaluation and same-enable register-retiming identity; actual CPU regressions still required',
 source_sha256={str(p.relative_to(R)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [R/'rtl/core/riscv_decoder.v',D/'rtl/core/riscv_decode.v']})
(D/'output/reports/predecode-host.json').write_text(json.dumps(report,indent=2)+'\n')
print('Pure decoder / same register-enable transition equivalence PASS',checked,'; not whole-CPU proof')
