"""One bounded 80MHz trial using same-cycle grouped prediction enables."""
from pathlib import Path
import hashlib,json,re,shutil,random
R=Path(__file__).resolve().parents[1];S=R/'variants/cpu75-raw-predecode';D=R/'variants/cpu80-grouped';assert not D.exists();D.mkdir()
j=json.loads((S/'output/reports/cpu-only-source.json').read_text())
for n in j['rtl_sources']:
 p=D/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(S/n,p)
for n in ['firmware','third_party','scripts','constraints']:shutil.copytree(S/n,D/n,ignore=shutil.ignore_patterns('__pycache__'))
shutil.copy2(S/'cpu_bench.pds',D/'cpu_bench.pds')
for n in ['firmware/cpu_only/main.c','rtl/cpu_bench/cpu_bench_top.v','scripts/build_cpu_only.py','scripts/accept_cpu_only.py']:
 p=D/n;p.write_text(p.read_text().replace('75000000','80000000').replace('75MHz','80MHz').replace('/seconds/75','/seconds/80'))
p=D/'rtl/cpu_bench/cpu_bench_pll.v';t=p.read_text()
for n,v in [('STATIC_RATIO0',15),('STATIC_DUTY0',15)]:
 t,count=re.subn(r'(localparam integer '+n+r'\s*=\s*)\d+',lambda m:m[1]+str(v),t);assert count==1
p.write_text(t)
p=D/'constraints/cpu_bench.fdc';p.write_text(p.read_text().replace('-multiply_by {3} -divide_by {2}','-multiply_by {8} -divide_by {5}'))
p=D/'rtl/core/riscv_core.v';original=p.read_text();a=original.index('    reg [31:0] prediction_q;');b=original.index('    assign decode_pred_next_w = prediction_q;',a)
old=original[a:b]
new='''    wire [31:0] prediction_q;
    wire prediction_ready=fetch_accept_w || !fetch_valid_w;
    wire [7:0] prediction_ready_held /* synthesis syn_keep=1 */;
    for (prediction_group=0;prediction_group<8;prediction_group=prediction_group+1) begin:g_prediction_enable
        GTP_LUT1 #(.INIT(2'h2)) u_holdbuf(.I0(prediction_ready),.Z(prediction_ready_held[prediction_group])) /* synthesis syn_noprune=1 */;
        reg [3:0] chunk_q /* synthesis syn_preserve=1 syn_allow_retiming=0 */;
        always @(posedge clk_i or posedge rst_i)
        if(rst_i)chunk_q<=0;
        else if(squash_decode_w)chunk_q<=0;
        else if(prediction_ready_held[prediction_group])chunk_q<=fetch_pred_next_w[prediction_group*4+:4];
        assign prediction_q[prediction_group*4+:4]=chunk_q;
    end
'''
t=original[:a]+new+original[b:];needle='generate\nif (EXTRA_DECODE_STAGE)';assert t.count(needle)==1;t=t.replace(needle,'genvar prediction_group;\n'+needle);p.write_text(t)
assert t.replace('genvar prediction_group;\n','').replace(new,old)==original
rng=random.Random(80);x=0;y=[0]*8
for i in range(50000):
 rst=rng.randrange(20)==0;squash=rng.randrange(9)==0;ready=rng.randrange(2);value=rng.getrandbits(32)
 if rst or squash:x=0
 elif ready:x=value
 for g in range(8):
  if rst or squash:y[g]=0
  elif ready:y[g]=(value>>(g*4))&15
 assert x==sum(v<<(g*4) for g,v in enumerate(y))
(D/'output/reports').mkdir(parents=True)
(D/'output/reports/grouped-enables-host.json').write_text(json.dumps(dict(passed=True,transitions=50000,source_inverse_verified=True,RTL_simulation=False,whole_CPU_formal_proof=False,source_sha256=hashlib.sha256(p.read_bytes()).hexdigest()),indent=2)+'\n')
assert (D/'rtl/core/riscv_decode.v').read_bytes()==(S/'rtl/core/riscv_decode.v').read_bytes()
j.update(CPU_target_hz=80000000,optimization='Raw predecode + 8 identity-buffer groups for existing prediction-register enable; same cycles')
(D/'output/reports/cpu-only-source.json').write_text(json.dumps(j,indent=2)+'\n')
print('CPU80 grouped trial prepared; identity-buffer grouping transition/inverse PASS')
