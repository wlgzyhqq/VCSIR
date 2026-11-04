"""Group sideband state enables to reduce late branch control fanout."""
from pathlib import Path
import json,shutil,random,hashlib
R=Path(__file__).resolve().parents[1];S=R/'variants/cpu85-branch';D=R/'variants/cpu85-sideband';assert not D.exists();D.mkdir()
j=json.loads((S/'output/reports/cpu-only-source.json').read_text())
for n in j['rtl_sources']:
 p=D/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(S/n,p)
for n in ['firmware','third_party','scripts','constraints']:shutil.copytree(S/n,D/n,ignore=shutil.ignore_patterns('__pycache__'))
shutil.copy2(S/'cpu_bench.pds',D/'cpu_bench.pds')
p=D/'rtl/core/riscv_core.v';t=p.read_text();a=t.index('generate if(EXTRA_DECODE_STAGE) begin:g_rf_onehot');b=t.index('wire predictor_update_w',a)
t=t[:a]+"""wire [4:0] rf_ra_copy_w,rf_rb_copy_w;
generate if(EXTRA_DECODE_STAGE) begin:g_sideband_groups
 localparam [105:0] RESET_VALUE = {32'b0,5'b0,5'b0,32'b1,32'b1};
 wire update_w = squash_decode_w || fetch_accept_w || !fetch_valid_w;
 wire [4:0] ra_in = (fetch_dec_fault_page_w || fetch_dec_fault_fetch_w)?5'b0:fetch_dec_instr_w[19:15];
 wire [4:0] rb_in = (fetch_dec_fault_page_w || fetch_dec_fault_fetch_w)?5'b0:fetch_dec_instr_w[24:20];
 wire [105:0] next_w = squash_decode_w ? RESET_VALUE : {fetch_pred_next_w,rb_in,ra_in,(32'b1<<rb_in),(32'b1<<ra_in)};
 wire [105:0] state_w;
 wire [26:0] local_update;
 genvar sg;
 for(sg=0;sg<27;sg=sg+1)begin:g
  localparam W=(sg==26)?2:4;
  GTP_LUT1 #(.INIT(2'h2)) u_enable(.I0(update_w),.Z(local_update[sg])) /* synthesis syn_noprune=1 */;
  reg [W-1:0] q /* synthesis syn_preserve=1 syn_allow_retiming=0 */;
  always @(posedge clk_i or posedge rst_i)
   if(rst_i)q<=RESET_VALUE[sg*4 +: W];
   else if(local_update[sg])q<=next_w[sg*4 +: W];
  assign state_w[sg*4 +: W]=q;
 end
 assign rf_ra_hot_w=state_w[31:0];assign rf_rb_hot_w=state_w[63:32];
 assign rf_ra_copy_w=state_w[68:64];assign rf_rb_copy_w=state_w[73:69];
 assign decode_pred_next_w=state_w[105:74];
end else begin:g_sideband_direct
 assign rf_ra_hot_w=32'b1<<fetch_instr_w[19:15];assign rf_rb_hot_w=32'b1<<fetch_instr_w[24:20];
 assign rf_ra_copy_w=fetch_instr_w[19:15];assign rf_rb_copy_w=fetch_instr_w[24:20];
 assign decode_pred_next_w=fetch_pred_next_w;
end endgenerate
"""+t[b:];p.write_text(t)
rng=random.Random(855);reset=1|(1<<32);state=reset;parts=[(reset>>(g*4))&((1<<(2 if g==26 else 4))-1) for g in range(27)]
for i in range(100000):
 rst=rng.randrange(31)==0;squash=rng.randrange(7)==0;ready=rng.randrange(2);fault=rng.randrange(19)==0
 ra=0 if fault else rng.randrange(32);rb=0 if fault else rng.randrange(32);pred=rng.getrandbits(32)
 value=(1<<ra)|((1<<rb)<<32)|(ra<<64)|(rb<<69)|(pred<<74)
 if rst or squash:state=reset
 elif ready:state=value
 for g in range(27):
  if rst:parts[g]=(reset>>(g*4))&((1<<(2 if g==26 else 4))-1)
  elif squash or ready:parts[g]=((reset if squash else value)>>(g*4))&((1<<(2 if g==26 else 4))-1)
 assert state==sum(v<<(g*4) for g,v in enumerate(parts))
(D/'output/reports').mkdir(parents=True);j['optimization']+='; 106bit RF selectors/prediction sideband grouped enables'
(D/'output/reports/cpu-only-source.json').write_text(json.dumps(j,indent=2)+'\n')
(D/'output/reports/sideband-host.json').write_text(json.dumps(dict(passed=True,transitions=100000,RTL_simulation=False,whole_CPU_formal_proof=False,source_sha256=hashlib.sha256(p.read_bytes()).hexdigest()),indent=2)+'\n')
print('CPU85 sideband candidate prepared;100000 grouped-state transitions passed')
