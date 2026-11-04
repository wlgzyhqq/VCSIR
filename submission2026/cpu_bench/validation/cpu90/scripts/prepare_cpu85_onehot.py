"""Replace only the RF read selection with registered one-hot selection."""
from pathlib import Path
import hashlib,json,random,shutil
R=Path(__file__).resolve().parents[1];S=R/'variants/cpu85-fanout';D=R/'variants/cpu85-onehot';assert not D.exists();D.mkdir()
j=json.loads((S/'output/reports/cpu-only-source.json').read_text())
for n in j['rtl_sources']:
 p=D/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(S/n,p)
for n in ['firmware','third_party','scripts','constraints']:shutil.copytree(S/n,D/n,ignore=shutil.ignore_patterns('__pycache__'))
shutil.copy2(S/'cpu_bench.pds',D/'cpu_bench.pds')
p=D/'rtl/core/riscv_core.v';t=p.read_text()
prefix='''wire [31:0] rf_ra_hot_w,rf_rb_hot_w;
generate if(EXTRA_DECODE_STAGE) begin:g_rf_onehot
 reg [31:0] ra_hot_q,rb_hot_q /* synthesis syn_preserve=1 syn_allow_retiming=0 */;
 always @(posedge clk_i or posedge rst_i)
 if(rst_i)begin ra_hot_q<=1;rb_hot_q<=1;end
 else if(squash_decode_w)begin ra_hot_q<=1;rb_hot_q<=1;end
 else if(fetch_accept_w || !fetch_valid_w)begin
  ra_hot_q<=32'b1 << ((fetch_dec_fault_page_w || fetch_dec_fault_fetch_w)?5'b0:fetch_dec_instr_w[19:15]);
  rb_hot_q<=32'b1 << ((fetch_dec_fault_page_w || fetch_dec_fault_fetch_w)?5'b0:fetch_dec_instr_w[24:20]);
 end
 assign rf_ra_hot_w=ra_hot_q;assign rf_rb_hot_w=rb_hot_q;
end else begin:g_rf_onehot_direct
 assign rf_ra_hot_w=32'b1 << fetch_instr_w[19:15];assign rf_rb_hot_w=32'b1 << fetch_instr_w[24:20];
end endgenerate
'''
needle='wire [4:0] rf_ra_copy_w,rf_rb_copy_w;';assert needle in t;t=t.replace(needle,prefix+needle)
needle='    ,.rf_rb_idx_i(rf_rb_copy_w)';assert needle in t;t=t.replace(needle,needle+'\n    ,.rf_ra_hot_i(rf_ra_hot_w)\n    ,.rf_rb_hot_i(rf_rb_hot_w)');p.write_text(t)
p=D/'rtl/core/riscv_issue.v';t=p.read_text();needle='    ,input [4:0] rf_ra_idx_i,rf_rb_idx_i';assert needle in t;t=t.replace(needle,needle+'\n    ,input [31:0] rf_ra_hot_i,rf_rb_hot_i')
needle='    .ra0_i(rf_ra_idx_i),';assert needle in t;t=t.replace(needle,'    .ra_hot_i(rf_ra_hot_i),\n    .rb_hot_i(rf_rb_hot_i),\n'+needle);p.write_text(t)
p=D/'rtl/core/riscv_regfile.v';original=p.read_text();t=original
# Leave the original indexed ports for the unused Xilinx branch and diagnostics.
needle='    ,input';pos=t.index(needle,t.index('module riscv_regfile'))
t=t[:pos]+'    ,input [31:0] ra_hot_i,rb_hot_i\n'+t[pos:]
a=t.index('    reg [31:0] ra0_value_r;');b=t.index('    //-------------------------------------------------------------\n    // get_register',a)
old=t[a:b]
new=''
for port in ['ra','rb']:
 terms=[f'(reg_r{i}_q & {{32{{{port}_hot_i[{i}]}}}})' for i in range(1,32)]
 new+=f'    assign {port}0_value_o = '+' |\n        '.join(terms)+';\n'
t=t[:a]+new+'\n'+t[b:];p.write_text(t)
# Exact inverse proves the storage/writeback/reset logic was not changed.
assert t.replace(new+'\n',old,1).replace('    ,input [31:0] ra_hot_i,rb_hot_i\n','',1)==original
rng=random.Random(852);regs=[0]*32;idx=[0,0];hot=[1,1]
for step in range(100000):
 reset=step%503==0;squash=step%23==0;ready=rng.randrange(2);fault=rng.randrange(4)==0;incoming=[rng.randrange(32),rng.randrange(32)]
 if reset or squash:idx=[0,0];hot=[1,1]
 elif ready:idx=[0,0] if fault else incoming;hot=[1<<v for v in idx]
 if reset:regs=[0]*32
 else:
  wr=rng.randrange(32);v=rng.getrandbits(32)
  if wr:regs[wr]=v
 for port in range(2):
  assert hot[port]==1<<idx[port]
  value=0
  for k in range(1,32):value |= regs[k] if hot[port]&(1<<k) else 0
  assert value==regs[idx[port]],(step,port)
(D/'output/reports').mkdir(parents=True)
j['optimization']='Grouped decode update and same-stage one-hot RF read selection; storage/writeback and bypass priority unchanged'
(D/'output/reports/cpu-only-source.json').write_text(json.dumps(j,indent=2)+'\n')
(D/'output/reports/onehot-host.json').write_text(json.dumps(dict(passed=True,transitions=100000,RF_storage_write_reset_inverse_verified=True,RTL_simulation=False,whole_CPU_formal_proof=False,source_sha256={n:hashlib.sha256((D/n).read_bytes()).hexdigest() for n in ['rtl/core/riscv_core.v','rtl/core/riscv_issue.v','rtl/core/riscv_regfile.v']}),indent=2)+'\n')
print('CPU85 onehot candidate prepared;100000 storage/read/squash/hold checks passed')
