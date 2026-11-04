"""Direct D-cache transition predicates shorten tag-to-data RAM address control."""
from pathlib import Path
import json,shutil,itertools,hashlib
R=Path(__file__).resolve().parents[1];S=R/'variants/cpu85-rfread';D=R/'variants/cpu85-cachecontrol';assert not (D/'build').exists();D.mkdir(exist_ok=True)
j=json.loads((S/'output/reports/cpu-only-source.json').read_text())
for n in j['rtl_sources']:
 p=D/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(S/n,p)
for n in ['firmware','third_party','scripts','constraints']:shutil.copytree(S/n,D/n,dirs_exist_ok=True,ignore=shutil.ignore_patterns('__pycache__'))
shutil.copy2(S/'cpu_bench.pds',D/'cpu_bench.pds')
p=D/'rtl/cache/dcache_core.v';t=p.read_text();needle='reg [CACHE_DATA_ADDR_W-1:0] data_addr_x_r;';assert needle in t
t=t.replace(needle,"""// Equivalent to next_state comparisons, without decoding the full next-state FSM.
wire enter_evict_w =
 ((state_q == STATE_FLUSH) && tag_dirty_any_m_w && evict_way_w) ||
 ((state_q == STATE_LOOKUP) && (mem_rd_m_q || (|mem_wr_m_q)) && !tag_hit_any_m_w && evict_way_r) ||
 ((state_q == STATE_WRITEBACK) && tag_hit_and_dirty_m_w);
wire enter_refill_w =
 ((state_q == STATE_LOOKUP) && (mem_rd_m_q || (|mem_wr_m_q)) && !tag_hit_any_m_w && !evict_way_r) ||
 ((state_q == STATE_EVICT_WAIT) && pmem_ack_w && !mem_writeback_m_q && !flushing_q);
"""+needle,1)
old='state_q != STATE_EVICT && next_state_r == STATE_EVICT';assert t.count(old)==4;t=t.replace(old,'enter_evict_w')
old='state_q != STATE_REFILL && next_state_r == STATE_REFILL';assert t.count(old)==2;t=t.replace(old,'enter_refill_w');p.write_text(t)
cases=0
for state in range(16):
 for flags in itertools.product([False,True],repeat=13):
  access,hit,dirty,way,flushing,hitdirty,ack,writeback,last,accept,flush,invalidate,wb=flags
  evict=(flushing or not hit) and way;nxt=state
  if state==0:
   if last:nxt=3
  elif state==1:nxt=2
  elif state==2:
   if dirty:
    if evict:nxt=7
   elif last:nxt=3
   else:nxt=1
  elif state==3:
   if access and not hit:nxt=7 if evict else 6
   elif wb and accept:nxt=10
   elif flush and accept:nxt=1
   elif invalidate and accept:nxt=9
  elif state==6:
   if ack and last:nxt=5 if writeback else 4
  elif state in [4,5]:nxt=3
  elif state==7:
   if accept and last:nxt=8
  elif state==8:
   if ack and writeback:nxt=3
   elif ack and flushing:nxt=1
   elif ack:nxt=6
  elif state==10:nxt=7 if hitdirty else 3
  elif state==9:nxt=3
  newev=(state==2 and dirty and evict) or (state==3 and access and not hit and way) or (state==10 and hitdirty)
  newref=(state==3 and access and not hit and not way) or (state==8 and ack and not writeback and not flushing)
  assert bool(state!=7 and nxt==7)==bool(newev)
  assert bool(state!=6 and nxt==6)==bool(newref)
  cases+=1
(D/'output/reports').mkdir(parents=True);j['optimization']+='; D-cache direct enter-evict/refill predicates, unchanged transition FSM'
(D/'output/reports/cpu-only-source.json').write_text(json.dumps(j,indent=2)+'\n')
(D/'output/reports/cachecontrol-host.json').write_text(json.dumps(dict(passed=True,exhaustive_state_and_boolean_combinations=cases,RTL_simulation=False,whole_CPU_formal_proof=False,scope='All16 state encodings and8192 combinations of independent boolean FSM inputs; predicates equal next-state tests',source_sha256=hashlib.sha256(p.read_bytes()).hexdigest()),indent=2)+'\n')
print('CPU85 cache control prepared;'+str(cases)+' exhaustive transition predicate checks passed')
