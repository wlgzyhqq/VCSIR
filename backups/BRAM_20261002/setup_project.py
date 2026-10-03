"""Import pinned local BSD reference and apply documented FINAL adaptations."""
from pathlib import Path
import json, shutil, re
root = Path(__file__).resolve().parent
manifest = json.loads((root.parent/'reference-projects/sources.json').read_text(encoding='utf-8-sig'))
src = Path(next(x['path'] for x in manifest if x['name']=='ultraembedded-riscv'))
for folder in ['rtl/core','rtl/cache','firmware','sim','docs','constraints','build']:
    (root/folder).mkdir(parents=True, exist_ok=True)
for f in (src/'core/riscv').glob('*.v'):
    if f.name != 'riscv_xilinx_2r1w.v': shutil.copy2(f, root/'rtl/core'/f.name)
for f in (src/'top_cache_axi/src_v').glob('*.v'):
    shutil.copy2(f, root/'rtl/cache'/f.name)
def edit(name, fn):
    p=root/name; p.write_text(fn(p.read_text(encoding='utf-8')),encoding='utf-8')
# Five-stage baseline: IF, ID, E1(EX), E2(MEM), WB; no extra decode stage.
edit('rtl/cache/riscv_top.v',lambda s:s.replace('parameter CORE_ID', 'parameter PREDICT_ENABLE = 1\n    ,parameter CORE_ID').replace(',input           intr_i', ',input           timer_intr_i\n    ,input           soft_intr_i\n    ,input           intr_i').replace('.MEM_CACHE_ADDR_MIN(MEM_CACHE_ADDR_MIN)', '.SUPPORT_MULDIV(0)\n    ,.SUPPORT_SUPER(0)\n    ,.SUPPORT_MMU(0)\n    ,.EXTRA_DECODE_STAGE(0)\n    ,.PREDICT_ENABLE(PREDICT_ENABLE)\n    ,.MEM_CACHE_ADDR_MIN(MEM_CACHE_ADDR_MIN)',1).replace(',.intr_i(intr_i)', ',.timer_intr_i(timer_intr_i)\n    ,.soft_intr_i(soft_intr_i)\n    ,.intr_i(intr_i)'))
edit('rtl/core/riscv_core.v',lambda s:s.replace('parameter SUPPORT_MULDIV', 'parameter PREDICT_ENABLE = 1\n    ,parameter SUPPORT_MULDIV',1).replace(',input           intr_i', ',input           timer_intr_i\n    ,input           soft_intr_i\n    ,input           intr_i').replace('wire           mmu_lsu_writeback_w;', '''wire [31:0] fetch_pred_next_w;
wire predictor_update_w, predictor_taken_w;
wire [31:0] predictor_target_w;
wire predictor_redirect_w = exec_opcode_valid_w &&
    (predictor_target_w != fetch_pred_next_w);
wire           mmu_lsu_writeback_w;''').replace(',.opcode_pc_i(opcode_pc_w)', ',.opcode_pc_i(opcode_pc_w)\n    ,.predictor_update_o(predictor_update_w)\n    ,.predictor_taken_o(predictor_taken_w)\n    ,.predictor_target_o(predictor_target_w)',1).replace(',.branch_d_exec_request_i(branch_d_exec_request_w)', ',.predictor_redirect_i(predictor_redirect_w)\n    ,.branch_d_exec_request_i(branch_d_exec_request_w)').replace(',.branch_d_exec_pc_i(branch_d_exec_pc_w)', ',.branch_d_exec_pc_i(predictor_target_w)').replace(',.intr_i(intr_i)', ',.timer_intr_i(timer_intr_i)\n    ,.soft_intr_i(soft_intr_i)\n    ,.intr_i(intr_i)').replace('riscv_fetch\n#(\n     .SUPPORT_MMU(SUPPORT_MMU)', 'riscv_fetch\n#(\n     .PREDICT_ENABLE(PREDICT_ENABLE)\n    ,.SUPPORT_MMU(SUPPORT_MMU)').replace(',.fetch_accept_i(fetch_dec_accept_w)', ',.predictor_update_i(predictor_update_w)\n    ,.predictor_pc_i(opcode_pc_w)\n    ,.predictor_taken_i(predictor_taken_w)\n    ,.predictor_target_i(branch_d_exec_pc_w)\n    ,.fetch_pred_next_o(fetch_pred_next_w)\n    ,.fetch_accept_i(fetch_dec_accept_w)'))
edit('rtl/core/riscv_exec.v',lambda s:s.replace('module riscv_exec', 'module riscv_exec',1).replace(',output          branch_request_o', ',output          predictor_update_o\n    ,output          predictor_taken_o\n    ,output [31:0]   predictor_target_o\n    ,output          branch_request_o').replace('assign branch_d_pc_o      = branch_target_r;', '''assign branch_d_pc_o      = branch_target_r;
assign predictor_update_o = opcode_valid_i && branch_r;
assign predictor_taken_o = branch_taken_r;
assign predictor_target_o = branch_r && branch_taken_r ? branch_target_r : opcode_pc_i + 32'd4;'''))
edit('rtl/core/riscv_issue.v',lambda s:s.replace(',input           branch_d_exec_request_i', ',input           predictor_redirect_i\n    ,input           branch_d_exec_request_i').replace('branch_csr_request_i | branch_d_exec_request_i', 'branch_csr_request_i | predictor_redirect_i'))
# Prediction metadata travels with the accepted fetch and the skid buffer.
def fetch_patch(s):
    s=s.replace('parameter SUPPORT_MMU', 'parameter PREDICT_ENABLE = 1\n    ,parameter SUPPORT_MMU',1)
    s=s.replace(',input           fetch_accept_i', ',input           predictor_update_i\n    ,input [31:0]    predictor_pc_i\n    ,input           predictor_taken_i\n    ,input [31:0]    predictor_target_i\n    ,input           fetch_accept_i')
    s=s.replace(',output          fetch_valid_o', ',output [31:0]   fetch_pred_next_o\n    ,output          fetch_valid_o')
    s=s.replace('reg [31:0]  pc_d_q;', '''reg [31:0]  pc_d_q;
reg [31:0] pred_d_q;
wire [31:0] predicted_next_w;
final_btb #(.ENABLE(PREDICT_ENABLE)) u_btb (
    .clk(clk_i), .rst(rst_i), .invalidate(fetch_invalidate_i),
    .lookup_pc(pc_f_q), .next_pc(predicted_next_w),
    .update(predictor_update_i), .update_pc(predictor_pc_i),
    .taken(predictor_taken_i), .target(predictor_target_i));
always @(posedge clk_i or posedge rst_i)
if (rst_i) pred_d_q <= 0;
else if (icache_rd_o && icache_accept_i) pred_d_q <= predicted_next_w;''')
    s=s.replace("pc_f_q  <= {icache_pc_w[31:2],2'b0} + 32'd4;", 'pc_f_q  <= predicted_next_w;')
    s=s.replace('reg [65:0]  skid_buffer_q;', 'reg [97:0]  skid_buffer_q;').replace("66'b0", "98'b0")
    s=s.replace('skid_buffer_q <= {fetch_fault_page_o', 'skid_buffer_q <= {fetch_pred_next_o, fetch_fault_page_o')
    s=s.replace('assign fetch_valid_o', 'assign fetch_pred_next_o = skid_valid_q ? skid_buffer_q[97:66] : pred_d_q;\nassign fetch_valid_o',1)
    return s
edit('rtl/core/riscv_fetch.v',fetch_patch)
# Expose three standard machine interrupt classes, with source-level pending.
edit('rtl/core/riscv_csr.v',lambda s:s.replace(',input           intr_i', ',input           timer_intr_i\n    ,input           soft_intr_i\n    ,input           intr_i').replace("wire timer_irq_w = 1'b0;", 'wire timer_irq_w = timer_intr_i;').replace(',.timer_intr_i(timer_irq_w)', ',.timer_intr_i(timer_irq_w)\n    ,.soft_intr_i(soft_intr_i)'))
def csr_patch(s):
    s=s.replace(',input           timer_intr_i', ',input           soft_intr_i\n    ,input           timer_intr_i')
    s=s.replace('csr_mip_r = csr_mip_r | csr_mip_next_r;', '''csr_mip_r = csr_mip_r | csr_mip_next_r;
    // Board interrupt sources are level sensitive; clearing the device clears MIP.
    csr_mip_r[`SR_IP_MEIP_R] = ext_intr_i;
    csr_mip_r[`SR_IP_MTIP_R] = timer_intr_i;
    csr_mip_r[`IRQ_M_SOFT] = soft_intr_i;''')
    # Implement direct and vectored mtvec, with aligned BASE.
    s=s.replace('branch_target_r = (irq_priv_q == `PRIV_MACHINE) ? csr_mtvec_q : csr_stvec_q;', '''branch_target_r = (irq_priv_q == `PRIV_MACHINE) ? {csr_mtvec_q[31:2],2'b0} : {csr_stvec_q[31:2],2'b0};
        if (irq_priv_q == `PRIV_MACHINE && csr_mtvec_q[1:0] == 1)
            branch_target_r = {csr_mtvec_q[31:2],2'b0} + ((csr_mcause_r & 32'h7fffffff) << 2);''')
    s=s.replace('branch_target_r = csr_mtvec_q;', "branch_target_r = {csr_mtvec_q[31:2],2'b0};")
    return s
edit('rtl/core/riscv_csr_regfile.v',csr_patch)
# Portable includes: PDS parses from several working directories.
for p in (root/'rtl').rglob('*.v'):
    s=p.read_text(encoding='utf-8'); s=s.replace('`include "riscv_defs.v"', '`include "'+(root/'rtl/core/riscv_defs.v').as_posix()+'"')
    p.write_text(s,encoding='utf-8')
# ModelSim/PDS require declarations before procedural references.
for name,items in {
 'rtl/cache/dcache_core.v':['tag_hit_any_m_w','flush_addr_q','tag0_hit_m_w','tag1_hit_m_w','data0_data_out_m_w','data1_data_out_m_w'],
 'rtl/cache/icache.v':['flush_addr_q'],
 'rtl/core/riscv_core.v':['exec_opcode_valid_w']}.items():
    p=root/name;s=p.read_text();decl=[]
    for item in items:
        m=re.search(r'(?m)^(wire|reg)\s+(?:\[[^\]]+\]\s+)?'+item+r'[^;]*;',s)
        assert m,(name,item)
        line=m.group(0);s=s[:m.start()]+s[m.end():]
        if '=' in line:
            left,right=line.split('=',1);decl.append(left.strip()+';')
            s=s.replace('endmodule','assign '+item+'='+right+'\nendmodule')
        else:decl.append(line.replace('[DCACHE_TAG_REQ_LINE_W-1:0] flush_addr_q','[7:0] flush_addr_q').replace('[ICACHE_TAG_REQ_LINE_W-1:0] flush_addr_q','[7:0] flush_addr_q'))
    s=s.replace(');',');\n'+'\n'.join(decl),1);p.write_text(s)
print('Imported BSD reference; patched predictor and machine interrupts.')
