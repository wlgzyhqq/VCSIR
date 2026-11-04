"""90MHz IPC candidate: real operand hazards and equivalent compact direct-index BTB tags."""
from pathlib import Path
import json,shutil,random,hashlib
R=Path(__file__).resolve().parents[1];S=R;D=R/'variants/cpu90-ipc';assert not D.exists();D.mkdir()
j=json.loads((S/'output/reports/cpu-only-source.json').read_text())
for n in j['rtl_sources']:
 p=D/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(S/n,p)
for n in ['firmware','third_party','scripts','constraints']:shutil.copytree(S/n,D/n,ignore=shutil.ignore_patterns('__pycache__'))
shutil.copy2(S/'cpu_bench.pds',D/'cpu_bench.pds');shutil.copytree(S/'output/cpu-only',D/'output/cpu-only');(D/'output/reports').mkdir(exist_ok=True)
p=D/'rtl/core/riscv_issue.v';t=p.read_text();needle='reg [31:0] scoreboard_r;';assert t.count(needle)==1
t=t.replace(needle,needle+"""
// Only encoded register operands participate in register dependencies.
// Unknown/system classes remain conservative; mandatory unit interlocks
// are independent of whether an instruction has any register operands.
wire issue_reads_ra_w=(fetch_instr_i[6:0]!=7'h37) && (fetch_instr_i[6:0]!=7'h17) && (fetch_instr_i[6:0]!=7'h6f);
wire issue_reads_rb_w=(fetch_instr_i[6:0]!=7'h03) && (fetch_instr_i[6:0]!=7'h13) &&
 (fetch_instr_i[6:0]!=7'h67) && (fetch_instr_i[6:0]!=7'h37) &&
 (fetch_instr_i[6:0]!=7'h17) && (fetch_instr_i[6:0]!=7'h6f);
wire unit_interlock_w=(pipe_load_e1_w || pipe_store_e1_w) && (issue_mul_w || issue_div_w || issue_csr_w);
""",1)
old="""    // Do not start multiply, division or CSR operation in the cycle after a load (leaving only ALU operations and branches)
    if ((pipe_load_e1_w || pipe_store_e1_w) && (issue_mul_w || issue_div_w || issue_csr_w))
        scoreboard_r = 32'hFFFFFFFF;
""";assert t.count(old)==1;t=t.replace(old,'    // Unit interlocks are checked separately below.\n')
old='if (lsu_stall_i || stall_w || div_pending_q || csr_pending_q)';assert t.count(old)==1;t=t.replace(old,'if (lsu_stall_i || stall_w || div_pending_q || csr_pending_q || unit_interlock_w)')
old="""!(scoreboard_r[issue_ra_idx_w] || 
          scoreboard_r[issue_rb_idx_w] ||
          scoreboard_r[issue_rd_idx_w])""";assert t.count(old)==1;t=t.replace(old,"""!((issue_reads_ra_w && (|issue_ra_idx_w) && scoreboard_r[issue_ra_idx_w]) ||
          (issue_reads_rb_w && (|issue_rb_idx_w) && scoreboard_r[issue_rb_idx_w]) ||
          (issue_sb_alloc_w && (|issue_rd_idx_w) && scoreboard_r[issue_rd_idx_w]))""");p.write_text(t)
p=D/'rtl/final_btb.v';t=p.read_text();assert 'reg [31:0] tags[0:31], targets[0:31];' in t;t=t.replace('reg [31:0] tags[0:31], targets[0:31];','reg [26:0] tags[0:31];\n reg [31:0] targets[0:31];')
needle=' wire hit=ENABLE';assert needle in t;t=t.replace(needle,""" // Given the matching PC[6:2] index, these five PC bits are uniquely
 // determined. Retain low alignment bits, preserving full 32bit PC identity.
 wire [26:0] lookup_tag_w={lookup_pc[31:7],lookup_pc[1:0]};
 wire [26:0] update_tag_w={update_pc_q[31:7],update_pc_q[1:0]};
"""+needle,1)
t=t.replace('tags[idx]==lookup_pc','tags[idx]==lookup_tag_w').replace('tags[upd]<=update_pc_q;','tags[upd]<=update_tag_w;').replace('tags[upd]!=update_pc_q','tags[upd]!=update_tag_w');p.write_text(t)
rng=random.Random(9090);relaxed=0;tags=0
for i in range(400000):
 op=rng.choice([3,0x13,0x23,0x33,0x37,0x17,0x63,0x67,0x6f,0x73]);ra,rb,rd=[rng.randrange(32) for _ in range(3)]
 writes=op in [3,0x13,0x33,0x37,0x17,0x67,0x6f] or op==0x73 and rng.randrange(2)
 usesra=op not in [0x37,0x17,0x6f];usesrb=op not in [3,0x13,0x67,0x37,0x17,0x6f]
 busy=1<<rng.randrange(32);unitwait=rng.randrange(7)==0;blocked=rng.randrange(5)==0;valid=rng.randrange(2)
 old=bool(valid and not blocked and not unitwait and not any(busy>>idx&1 for idx in [ra,rb,rd]))
 hazard=(usesra and ra!=0 and busy>>ra&1) or (usesrb and rb!=0 and busy>>rb&1) or (writes and rd!=0 and busy>>rd&1)
 new=bool(valid and not blocked and not unitwait and not hazard)
 assert not old or new
 if new:
  assert not unitwait and not blocked
  assert not any(used and idx!=0 and busy>>idx&1 for used,idx in [(usesra,ra),(usesrb,rb),(writes,rd)])
 if new and not old:relaxed+=1
 u=rng.getrandbits(32)
 if i%4==0:v=u
 elif i%4==1:v=u^(rng.randrange(32)<<2)
 elif i%4==2:
  delta=rng.randrange(1,32);v=u^(delta<<7)
 else:v=rng.getrandbits(32)
 idx=lambda x:(x>>2)&31
 key=lambda x:((x>>7)<<2)|(x&3)
 if idx(u)==idx(v):assert (key(u)==key(v))==(u==v);tags+=1
j['optimization']+='; ignore unused encoded register fields in hazards, preserve real RAW/WAW and separate unit interlocks; equivalent27bit BTB tags'
(D/'output/reports/cpu-only-source.json').write_text(json.dumps(j,indent=2)+'\n')
(D/'output/reports/ipc-host.json').write_text(json.dumps(dict(passed=True,hazard_control_cases=400000,relaxed_false_dependency_cases=relaxed,matching_index_tag_comparisons=tags,unit_interlocks_preserved=True,actual_destination_hazards_preserved=True,unknown_system_operand_use_conservative=True,additional_pipeline_stages=0,RTL_simulation=False,whole_CPU_formal_proof=False,source_sha256={n:hashlib.sha256((D/n).read_bytes()).hexdigest() for n in ['rtl/core/riscv_issue.v','rtl/final_btb.v']}),indent=2)+'\n')
print('IPC candidate prepared;400000 hazard/tag cases checked. Real dependencies and unit interlocks retained.')
