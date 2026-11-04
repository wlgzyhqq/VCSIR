"""Independent 85MHz candidate. Retain the accepted75MHz sources and artifacts."""
from pathlib import Path
import hashlib,json,random,re,shutil
R=Path(__file__).resolve().parents[1];D=R/'variants/cpu85-fanout';assert not D.exists();D.mkdir()
j=json.loads((R/'output/reports/cpu-only-source.json').read_text())
for n in j['rtl_sources']:
 p=D/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(R/n,p)
for n in ['firmware/cpu_only','third_party/coremark','scripts','constraints']:
 shutil.copytree(R/n,D/n,ignore=shutil.ignore_patterns('__pycache__'))
for n in ['firmware/cpu_bench.h','firmware/runtime.c','cpu_bench.pds']:
 p=D/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(R/n,p)
for n in ['firmware/cpu_only/main.c','rtl/cpu_bench/cpu_bench_top.v','scripts/build_cpu_only.py','scripts/accept_cpu_only.py']:
 p=D/n;p.write_text(p.read_text().replace('75000000','85000000').replace('75MHz','85MHz').replace('/seconds/75','/seconds/85'))
p=D/'rtl/cpu_bench/cpu_bench_pll.v';t=p.read_text()
for n,v in [('STATIC_RATIOF',17),('STATIC_RATIO0',10),('STATIC_DUTY0',10)]:
 t,count=re.subn(r'(localparam integer '+n+r'\s*=\s*)\d+',lambda m:m[1]+str(v),t);assert count==1
p.write_text(t)
p=D/'constraints/cpu_bench.fdc';p.write_text(p.read_text().replace('-multiply_by {3} -divide_by {2}','-multiply_by {17} -divide_by {10}'))
# Group the entire75-bit decode buffer, including synchronous squash in update/data.
p=D/'rtl/core/riscv_decode.v';original=p.read_text();a=original.index('    reg [74:0] buffer_q;');b=original.index('    assign {fetch_out_valid_o,',a);old=original[a:b]
new='''    wire [74:0] buffer_q;
    wire [7:0] decoded_in;
    wire buffered_fault=buffer_q[65] || buffer_q[64];
    wire buffer_update=squash_decode_i || fetch_out_accept_i || !fetch_out_valid_o;
    wire [74:0] buffer_next=squash_decode_i ? 75'b0 : {decoded_in,fetch_in_valid_i,fetch_in_fault_page_i,fetch_in_fault_fetch_i,fetch_in_instr_w,fetch_in_pc_i};
    wire [18:0] buffer_update_local /* synthesis syn_keep=1 */;
    for (decode_group=0;decode_group<19;decode_group=decode_group+1) begin:g_decode_groups
        localparam integer BITS=decode_group==18?3:4;
        GTP_LUT1 #(.INIT(2'h2)) u_enable(.I0(buffer_update),.Z(buffer_update_local[decode_group])) /* synthesis syn_noprune=1 */;
        reg [BITS-1:0] state_q /* synthesis syn_preserve=1 syn_allow_retiming=0 */;
        always @(posedge clk_i or posedge rst_i)
        if(rst_i)state_q<=0;
        else if(buffer_update_local[decode_group])state_q<=buffer_next[decode_group*4+:BITS];
        assign buffer_q[decode_group*4+:BITS]=state_q;
    end

'''
t=original[:a]+new+original[b:];needle='generate\nif (EXTRA_DECODE_STAGE)';assert needle in t;t=t.replace(needle,'genvar decode_group;\n'+needle,1);p.write_text(t)
assert t.replace('genvar decode_group;\n','').replace(new,old)==original
# Dedicated same-boundary index copies feed only RF read muxes. Other consumers
# retain the original instruction field. No architectural index or bypass change.
p=D/'rtl/core/riscv_core.v';t=p.read_text();needle='generate\nif (EXTRA_DECODE_STAGE)';assert needle in t
addition='''wire [4:0] rf_ra_copy_w,rf_rb_copy_w;
generate if(EXTRA_DECODE_STAGE) begin:g_rf_index_copies
 reg [4:0] ra_q,rb_q /* synthesis syn_preserve=1 syn_allow_retiming=0 */;
 always @(posedge clk_i or posedge rst_i)
 if(rst_i)begin ra_q<=0;rb_q<=0;end
 else if(squash_decode_w)begin ra_q<=0;rb_q<=0;end
 else if(fetch_accept_w || !fetch_valid_w)begin
  ra_q<=(fetch_dec_fault_page_w || fetch_dec_fault_fetch_w)?5'b0:fetch_dec_instr_w[19:15];
  rb_q<=(fetch_dec_fault_page_w || fetch_dec_fault_fetch_w)?5'b0:fetch_dec_instr_w[24:20];
 end
 assign rf_ra_copy_w=ra_q;assign rf_rb_copy_w=rb_q;
end else begin:g_rf_index_direct
 assign rf_ra_copy_w=fetch_instr_w[19:15];assign rf_rb_copy_w=fetch_instr_w[24:20];
end endgenerate
'''
t=t.replace(needle,addition+'\n'+needle,1)
needle='    ,.fetch_instr_i(fetch_instr_w)';assert t.count(needle)==1;t=t.replace(needle,needle+'\n    ,.rf_ra_idx_i(rf_ra_copy_w)\n    ,.rf_rb_idx_i(rf_rb_copy_w)')
p.write_text(t)
p=D/'rtl/core/riscv_issue.v';t=p.read_text();needle='    ,input  [ 31:0]  fetch_instr_i';assert t.count(needle)==1;t=t.replace(needle,needle+'\n    ,input [4:0] rf_ra_idx_i,rf_rb_idx_i')
assert t.count('.ra0_i(issue_ra_idx_w)')==1 and t.count('.rb0_i(issue_rb_idx_w)')==1
t=t.replace('.ra0_i(issue_ra_idx_w)','.ra0_i(rf_ra_idx_i)').replace('.rb0_i(issue_rb_idx_w)','.rb0_i(rf_rb_idx_i)');p.write_text(t)
rng=random.Random(8501);state=0;parts=[0]*19;ra=rb=0
for i in range(100000):
 rst=i%211==0;squash=i%17==0;ready=bool(rng.randrange(2)) or not ((state>>66)&1);value=rng.getrandbits(75)
 fault=(value>>64)&3
 if fault:value &= ~(((1<<32)-1)<<32)
 if rst or squash:state=0
 elif ready:state=value
 update=squash or ready;next_value=0 if squash else value
 for g in range(19):
  if rst:parts[g]=0
  elif update:parts[g]=(next_value>>(g*4))&((1<<(3 if g==18 else 4))-1)
 if rst or squash:ra=rb=0
 elif ready:ra=(value>>47)&31;rb=(value>>52)&31
 assert state==sum(v<<(g*4) for g,v in enumerate(parts))
 assert ra==(state>>47)&31 and rb==(state>>52)&31
(D/'output/reports').mkdir(parents=True)
j.update(CPU_target_hz=85000000,optimization='75-bit grouped update with squash-as-zero-data + dedicated same-stage RF read index copies; no added cycle',board_test=False)
(D/'output/reports/cpu-only-source.json').write_text(json.dumps(j,indent=2)+'\n')
(D/'output/reports/fanout-host.json').write_text(json.dumps(dict(passed=True,transitions=100000,RTL_simulation=False,whole_CPU_formal_proof=False,decode_inverse_verified=True,source_sha256={n:hashlib.sha256((D/n).read_bytes()).hexdigest() for n in ['rtl/core/riscv_decode.v','rtl/core/riscv_core.v','rtl/core/riscv_issue.v']}),indent=2)+'\n')
print('CPU85 candidate prepared;100000 abstract grouped-buffer/index-copy checks passed')
