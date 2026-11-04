"""90MHz trial: speculative writes to unoccupied request FIFO slots; no new stage."""
from pathlib import Path
import hashlib,json,random,shutil,re
R=Path(__file__).resolve().parents[1];D=R/'variants/cpu90-specwrite';assert not D.exists();D.mkdir()
j=json.loads((R/'output/reports/cpu-only-source.json').read_text())
for n in j['rtl_sources']:
 p=D/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(R/n,p)
for n in ['firmware','third_party','scripts','constraints']:shutil.copytree(R/n,D/n,ignore=shutil.ignore_patterns('__pycache__'))
shutil.copy2(R/'cpu_bench.pds',D/'cpu_bench.pds')
for n in ['firmware/cpu_only/main.c','rtl/cpu_bench/cpu_bench_top.v','scripts/build_cpu_only.py','scripts/accept_cpu_only.py']:
 p=D/n;p.write_text(p.read_text().replace('85000000','90000000').replace('85MHz','90MHz').replace('/seconds/85','/seconds/90'))
p=D/'rtl/cpu_bench/cpu_bench_pll.v';t=p.read_text();t,n=re.subn(r'(localparam integer STATIC_RATIOF\s*=\s*)17;',r'\g<1>18;',t);assert n==1;p.write_text(t)
p=D/'constraints/cpu_bench.fdc';t=p.read_text();assert '-multiply_by {17} -divide_by {10}' in t;p.write_text(t.replace('-multiply_by {17} -divide_by {10}','-multiply_by {18} -divide_by {10}'))
p=D/'rtl/cache/dcache_axi.v';t=p.read_text();old="""    // Push
    if (push_i & accept_o)
    begin
        ram_q[wr_ptr_q] <= data_in_i;
        wr_ptr_q        <= wr_ptr_q + 1;
    end""";new="""    // wr_ptr points to a free slot whenever accept_o is true. Capture the
    // candidate payload speculatively; only a real accepted push advances
    // occupancy/pointers. No live queued entry is overwritten when full.
    // This removes late cache request-valid logic from the wide RAM CE.
    if (accept_o)
        ram_q[wr_ptr_q] <= data_in_i;
    if (push_i & accept_o)
        wr_ptr_q <= wr_ptr_q + 1;""";assert t.count(old)==1;t=t.replace(old,new);p.write_text(t)
rng=random.Random(9001);checks=0
for depth in [2,4,8]:
 oldmem=[None]*depth;newmem=[None]*depth;rd=wr=count=0;queue=[]
 for cycle in range(170000):
  reset=rng.randrange(97)==0;push=rng.randrange(2);pop=rng.randrange(2);data=rng.getrandbits(77)
  ready=count!=depth;valid=count!=0
  assert ready==(len(queue)<depth) and valid==bool(queue)
  if valid:assert oldmem[rd]==newmem[rd]==queue[0]
  if reset:rd=wr=count=0;queue=[]
  else:
   if ready:newmem[wr]=data
   if push and ready:oldmem[wr]=data;wr=(wr+1)%depth;queue.append(data)
   if pop and valid:rd=(rd+1)%depth;queue.pop(0)
   count+=int(push and ready)-int(pop and valid)
  for k in range(count):assert oldmem[(rd+k)%depth]==newmem[(rd+k)%depth]==queue[k]
  checks+=1
# Inductive occupancy invariant for every consistent ring-pointer/count state.
exhaustive=0
for depth in [2,4,8]:
 for rd in range(depth):
  for count in range(depth+1):
   wr=(rd+count)%depth
   for push in [0,1]:
    for pop in [0,1]:
     om=list(range(depth));nm=om.copy();ready=count<depth;valid=count>0;data=1000
     if ready:nm[wr]=data
     if push and ready:om[wr]=data
     nr=(rd+int(pop and valid))%depth;nc=count+int(push and ready)-int(pop and valid)
     assert all(om[(nr+k)%depth]==nm[(nr+k)%depth] for k in range(nc))
     exhaustive+=1
(D/'output/reports').mkdir(parents=True);j.update(base='accepted85MHz delivery',CPU_target_hz=90000000,optimization='85MHz architecture unchanged; speculative payload writes to free existing request FIFO slots remove request-valid from wide CE; unchanged accepted-push/pop timing',additional_pipeline_stages=0)
(D/'output/reports/cpu-only-source.json').write_text(json.dumps(j,indent=2)+'\n')
(D/'output/reports/fifo-specwrite-host.json').write_text(json.dumps(dict(passed=True,random_cycles=checks,exhaustive_pointer_count_control_states=exhaustive,depths=[2,4,8],width=77,observable_queue_and_handshakes_identical=True,invalid_payload_may_differ=True,RTL_simulation=False,whole_CPU_formal_proof=False,additional_pipeline_stages=0,source_sha256=hashlib.sha256(p.read_bytes()).hexdigest()),indent=2)+'\n')
print('90MHz candidate prepared;'+str(checks)+' random FIFO cycles and'+str(exhaustive)+' pointer/count cases passed; no new stage')
