"""Move RF reads into the existing decode stage with WB-coherent operand latches."""
from pathlib import Path
import json,shutil,random,hashlib
R=Path(__file__).resolve().parents[1];S=R/'variants/cpu85-address';D=R/'variants/cpu85-rfread';assert not D.exists();D.mkdir()
j=json.loads((S/'output/reports/cpu-only-source.json').read_text())
for n in j['rtl_sources']:
 p=D/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(S/n,p)
for n in ['firmware','third_party','scripts','constraints']:shutil.copytree(S/n,D/n,ignore=shutil.ignore_patterns('__pycache__'))
shutil.copy2(S/'cpu_bench.pds',D/'cpu_bench.pds')
p=D/'rtl/core/riscv_core.v';t=p.read_text();a=t.index('generate if(EXTRA_DECODE_STAGE) begin:g_sideband_groups');b=t.index('wire predictor_update_w',a)
t=t[:a]+"""wire [4:0] rf_look_ra_w=EXTRA_DECODE_STAGE ? ((fetch_dec_fault_page_w || fetch_dec_fault_fetch_w)?5'b0:fetch_dec_instr_w[19:15]):rf_ra_copy_w;
wire [4:0] rf_look_rb_w=EXTRA_DECODE_STAGE ? ((fetch_dec_fault_page_w || fetch_dec_fault_fetch_w)?5'b0:fetch_dec_instr_w[24:20]):rf_rb_copy_w;
generate if(EXTRA_DECODE_STAGE) begin:g_metadata
 wire update_w=squash_decode_w || fetch_accept_w || !fetch_valid_w;
 wire [46:0] next_w=squash_decode_w ? 47'b0 : {branch_select((fetch_dec_fault_page_w || fetch_dec_fault_fetch_w)?32'b0:fetch_dec_instr_w),fetch_pred_next_w,rf_look_rb_w,rf_look_ra_w};
 wire [46:0] state_w;
 wire [11:0] local_update;
 genvar sg;
 for(sg=0;sg<12;sg=sg+1)begin:g
  localparam W=(sg==11)?3:4;
  GTP_LUT1 #(.INIT(2'h2)) u_enable(.I0(update_w),.Z(local_update[sg])) /* synthesis syn_noprune=1 */;
  reg [W-1:0] q /* synthesis syn_preserve=1 syn_allow_retiming=0 */;
  always @(posedge clk_i or posedge rst_i)
   if(rst_i)q<=0;
   else if(local_update[sg])q<=next_w[sg*4 +: W];
  assign state_w[sg*4 +: W]=q;
 end
 assign rf_ra_copy_w=state_w[4:0];assign rf_rb_copy_w=state_w[9:5];
 assign decode_pred_next_w=state_w[41:10];assign branch_select_w=state_w[46:42];
end else begin:g_sideband_direct
 assign rf_ra_copy_w=fetch_instr_w[19:15];assign rf_rb_copy_w=fetch_instr_w[24:20];
 assign decode_pred_next_w=fetch_pred_next_w;assign branch_select_w=branch_select(fetch_instr_w);
end endgenerate
assign rf_ra_hot_w=32'b1<<rf_ra_copy_w;assign rf_rb_hot_w=32'b1<<rf_rb_copy_w;
"""+t[b:]
needle='    ,.SUPPORT_DUAL_ISSUE(1)';assert needle in t;t=t.replace(needle,needle+'\n    ,.REGISTER_RF_READ(EXTRA_DECODE_STAGE)',1)
needle='    ,.rf_ra_idx_i(rf_ra_copy_w)';assert needle in t;t=t.replace(needle,needle+"""
    ,.rf_look_ra_i(rf_look_ra_w)
    ,.rf_look_rb_i(rf_look_rb_w)
    ,.rf_read_advance_i(fetch_accept_w || !fetch_valid_w)
    ,.rf_read_squash_i(squash_decode_w)""",1);p.write_text(t)
p=D/'rtl/core/riscv_issue.v';t=p.read_text();t=t.replace(',parameter SUPPORT_REGFILE_XILINX = 0',',parameter SUPPORT_REGFILE_XILINX = 0\n    ,parameter REGISTER_RF_READ = 0',1)
t=t.replace(',input [4:0] rf_ra_idx_i,rf_rb_idx_i',',input [4:0] rf_ra_idx_i,rf_rb_idx_i\n    ,input [4:0] rf_look_ra_i,rf_look_rb_i\n    ,input rf_read_advance_i,rf_read_squash_i',1)
t=t.replace('wire [31:0] issue_ra_value_w;',"""wire [31:0] rf_raw_ra_w,rf_raw_rb_w;
wire [4:0] rf_read_ra_w=REGISTER_RF_READ ? rf_look_ra_i : rf_ra_idx_i;
wire [4:0] rf_read_rb_w=REGISTER_RF_READ ? rf_look_rb_i : rf_rb_idx_i;
wire [31:0] issue_ra_value_w;""",1)
t=t.replace('.ra_hot_i(rf_ra_hot_i)',".ra_hot_i(32'b1<<rf_read_ra_w)").replace('.rb_hot_i(rf_rb_hot_i)',".rb_hot_i(32'b1<<rf_read_rb_w)")
t=t.replace('.ra0_i(rf_ra_idx_i)','.ra0_i(rf_read_ra_w)').replace('.rb0_i(rf_rb_idx_i)','.rb0_i(rf_read_rb_w)').replace('.ra0_value_o(issue_ra_value_w)','.ra0_value_o(rf_raw_ra_w)').replace('.rb0_value_o(issue_rb_value_w)','.rb0_value_o(rf_raw_rb_w)')
needle='//-------------------------------------------------------------\n// Issue Slot 0';assert needle in t
t=t.replace(needle,"""// Decode-stage read snapshot. WB matches emulate the post-edge RF value,
// including a write arriving while decode is held for hazards/backpressure.
generate if(REGISTER_RF_READ)begin:g_rf_read
 reg [31:0] ra_q,rb_q;
 always @(posedge clk_i or posedge rst_i)
 if(rst_i)begin ra_q<=0;rb_q<=0;end
 else if(rf_read_squash_i)begin ra_q<=0;rb_q<=0;end
 else begin
  if(rf_read_advance_i)
   ra_q<=(pipe_rd_wb_w!=0 && pipe_rd_wb_w==rf_read_ra_w)?pipe_result_wb_w:rf_raw_ra_w;
  else if(pipe_rd_wb_w!=0 && pipe_rd_wb_w==issue_ra_idx_w)ra_q<=pipe_result_wb_w;
  if(rf_read_advance_i)
   rb_q<=(pipe_rd_wb_w!=0 && pipe_rd_wb_w==rf_read_rb_w)?pipe_result_wb_w:rf_raw_rb_w;
  else if(pipe_rd_wb_w!=0 && pipe_rd_wb_w==issue_rb_idx_w)rb_q<=pipe_result_wb_w;
 end
 assign issue_ra_value_w=ra_q;assign issue_rb_value_w=rb_q;
end else begin:g_rf_read_direct
 assign issue_ra_value_w=rf_raw_ra_w;assign issue_rb_value_w=rf_raw_rb_w;
end endgenerate

"""+needle,1);p.write_text(t)
rng=random.Random(859);rf=[0]*32;ra=rb=0;qa=qb=0
for n in range(500000):
 rst=rng.randrange(101)==0;squash=rng.randrange(13)==0;advance=rng.randrange(2);nr,nb=rng.randrange(32),rng.randrange(32);rd=rng.randrange(32);val=rng.getrandbits(32)
 if rst:rf=[0]*32;ra=rb=0;qa=qb=0
 else:
  if squash:qa=qb=0;ra=rb=0
  elif advance:
   qa=val if rd and rd==nr else rf[nr];qb=val if rd and rd==nb else rf[nb];ra,rb=nr,nb
  else:
   if rd and rd==ra:qa=val
   if rd and rd==rb:qb=val
  if rd:rf[rd]=val
 assert qa==rf[ra] and qb==rf[rb]
(D/'output/reports').mkdir(parents=True);j['optimization']+='; move RF read into existing decode stage with writeback-coherent operand snapshots, no extra pipeline cycle'
(D/'output/reports/cpu-only-source.json').write_text(json.dumps(j,indent=2)+'\n')
(D/'output/reports/rfread-host.json').write_text(json.dumps(dict(passed=True,dual_port_coherence_cycles=500000,RTL_simulation=False,whole_CPU_formal_proof=False,scope='RF operand snapshots equal asynchronous architectural RF reads after every edge, including WB and hold/squash/reset/x0',source_sha256={n:hashlib.sha256((D/n).read_bytes()).hexdigest() for n in ['rtl/core/riscv_core.v','rtl/core/riscv_issue.v']}),indent=2)+'\n')
print('CPU85 RF-read retiming prepared;500000 dual-port coherence cycles passed')
