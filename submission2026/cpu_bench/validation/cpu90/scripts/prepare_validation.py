from pathlib import Path
import re,json
R=Path(__file__).resolve().parents[1]
if 'output [33:0] debug_o' in (R/'rtl/core/riscv_pipe_ctrl.v').read_text():
 raise SystemExit('Historical one-time bootstrap already applied. Build checked-in sources directly; do not regenerate.')
# Read-only observation ports, propagated explicitly rather than hierarchical probes.
p=R/'rtl/core/riscv_pipe_ctrl.v';s=p.read_text();s=s.replace('    ,output          stall_o','    ,output [33:0] debug_o\n    ,output          stall_o',1);s=s.replace('endmodule',"assign debug_o={valid_e2_q,valid_e1_q,pc_e2_q};\nendmodule");p.write_text(s)
p=R/'rtl/core/riscv_issue.v';s=p.read_text();s=s.replace('    ,output          retired_o','    ,output [223:0] debug_o\n    ,output          retired_o',1);s=s.replace('wire [31:0] scoreboard_r;', 'wire [31:0] scoreboard_r;')
s=s.replace('wire        pipe_squash_e1_e2_w;','wire        pipe_squash_e1_e2_w;\nwire [33:0] pipe_debug_w;')
s=s.replace(',.stall_o(pipe_stall_raw_w)',',.debug_o(pipe_debug_w)\n    ,.stall_o(pipe_stall_raw_w)')
assert '.debug_o(pipe_debug_w)' in s
s=s.replace('endmodule',"""wire [31:0] debug_flags_w={issue_invalid_w,pipe_squash_e1_e2_w,take_interrupt_i,pipe_rd_wb_w,
 (|csr_writeback_exception_o),issue_csr_w,issue_div_w,issue_mul_w,issue_branch_w,issue_lsu_w,
 pipe_mul_e2_w,pipe_load_e2_w,pipe_mul_e1_w,pipe_load_e1_w,retired_o,branch_csr_request_i,
 predictor_redirect_i,unit_interlock_w,(fetch_valid_i && !opcode_issue_r),csr_pending_q,div_pending_q,
 lsu_stall_i,stall_w,pipe_valid_wb_w,pipe_debug_w[33],pipe_debug_w[32],opcode_issue_r,fetch_valid_i};
assign debug_o={debug_flags_w,pipe_result_wb_w,pipe_pc_wb_w,pipe_debug_w[31:0],pipe_pc_e1_w,fetch_instr_i,fetch_pc_i};
endmodule""");p.write_text(s)
p=R/'rtl/core/riscv_core.v';s=p.read_text();s=s.replace('    ,output [ 31:0]  mem_d_addr_o','    ,output [223:0] debug_o\n    ,output [ 31:0]  mem_d_addr_o',1);s=s.replace(',.retired_o(retired_w)',',.debug_o(debug_o)\n    ,.retired_o(retired_w)',1);assert '.debug_o(debug_o)' in s;p.write_text(s)
p=R/'rtl/cache/riscv_top.v';s=p.read_text();s=s.replace('    ,output          axi_i_awvalid_o','    ,output [223:0] debug_o\n    ,output          axi_i_awvalid_o',1);s=s.replace(',.cpu_id_i(cpu_id_w)',',.cpu_id_i(cpu_id_w)\n    ,.debug_o(debug_o)',1);p.write_text(s)
# Diagnostic MMIO and uncached physical-RAM alias; not part of the score profile.
p=R/'rtl/cpu_bench/cpu_bench_bus.v';s=p.read_text();s=s.replace(' input clk,rst,input [31:0] gpio_input,'," input clk,rst,input [31:0] diag_rdata_i,input diag_delay_i,\n output [31:0] diag_addr_o,diag_waddr_o,diag_wdata_o,output diag_wr_o,\n input [31:0] gpio_input,")
s=s.replace('wire [31:0] d_mmio =',"""assign diag_addr_o=d_addr;assign diag_waddr_o=w_addr;assign diag_wdata_o=axi_d_wdata;
assign diag_wr_o=w_fire && !w_bad && w_addr>=32'h80004000 && w_addr<32'h80004200;
wire d_alias=d_addr>=32'h40000000 && d_addr<32'h40010000;
wire w_alias=w_addr>=32'h40000000 && w_addr<32'h40010000;
wire [31:0] d_mmio =
 (d_addr>=32'h80004000 && d_addr<32'h80004200)?diag_rdata_i :""")
s=s.replace('wire d_known=d_addr<65536 ||',"wire d_known=d_addr<65536 || d_alias || (d_addr>=32'h80004000 && d_addr<32'h80004200) ||")
s=s.replace('wire w_known=w_addr<65536 ||',"wire w_known=w_addr<65536 || w_alias || (w_addr>=32'h80004000 && w_addr<32'h80004200) ||")
s=s.replace('axi_i_arready=!i_active && !axi_i_rvalid;','axi_i_arready=!i_active && !axi_i_rvalid && (!diag_delay_i || random_q[3]);')
s=s.replace('axi_d_arready=!d_active && !axi_d_rvalid && !w_active && !axi_d_bvalid;','axi_d_arready=!d_active && !axi_d_rvalid && !w_active && !axi_d_bvalid && (!diag_delay_i || random_q[4]);')
s=s.replace('!axi_d_arvalid;','!axi_d_arvalid && (!diag_delay_i || random_q[5]);',1)
s=s.replace('MEM_DELAY==0 || random_q','(MEM_DELAY==0 && !diag_delay_i) || random_q')
s=s.replace('<=2+MEM_DELAY;','<=2+MEM_DELAY+(diag_delay_i?5:0);')
s=s.replace("w_ram<=axi_d_awaddr<65536;","w_ram<=axi_d_awaddr<65536 || (axi_d_awaddr>=32'h40000000 && axi_d_awaddr<32'h40010000);")
s=s.replace('d_addr<65536?d_ram_q:d_mmio','(d_addr<65536 || d_alias)?d_ram_q:d_mmio');p.write_text(s)
# Connect all AXI signals to the passive sampler.
ports={}
for line in s.splitlines():
 m=re.match(r'(?:input wire|output reg)\s*(\[[^]]+\])?\s*(axi_[id]_\w+)[,)]',line)
 if m:ports[m[2]]=m[1] or ''
# Remaining handshakes are covered by the same pattern, assert all mandatory names.
assert len(ports)>50,len(ports)
p=R/'rtl/cpu_bench/cpu_bench_top.v';s=p.read_text();s=s.replace('wire ext_irq,timer_irq,soft_irq;',"wire ext_irq,timer_irq,soft_irq;\nwire [223:0] core_debug;wire diag_reset,diag_delay;wire run_rst=rst||diag_reset;\nwire [31:0] diag_rdata,diag_addr,diag_waddr,diag_wdata;wire diag_wr;")
s=s.replace('.rst_i(rst)', '.rst_i(run_rst)').replace('.clk(cpu_clk),.rst(rst)', '.clk(cpu_clk),.rst(run_rst)')
s=s.replace('.clk_i(cpu_clk),.rst_i(run_rst),','.debug_o(core_debug),.clk_i(cpu_clk),.rst_i(run_rst),',1)
# Insert diagnostic bus ports at the bus instance.
needle='.gpio_input(gpio_input)';assert needle in s;s=s.replace(needle,'.diag_rdata_i(diag_rdata),.diag_delay_i(diag_delay),.diag_addr_o(diag_addr),.diag_waddr_o(diag_waddr),.diag_wdata_o(diag_wdata),.diag_wr_o(diag_wr),'+needle,1)
inst='cpu_validation_diag u_diag(.clk(cpu_clk),.rst(rst),.core_debug(core_debug),.read_addr(diag_addr),.write_addr(diag_waddr),.write_data(diag_wdata),.write_en(diag_wr),.read_data(diag_rdata),.warm_reset(diag_reset),.delay_mode(diag_delay),\n'+',\n'.join('.'+n+'('+n+')' for n in ports)+');\n'
s=s.replace('endmodule',inst+'endmodule');p.write_text(s)
(R/'output/reports/diag-axi-ports.json').write_text(json.dumps(ports,indent=2))
j=json.loads((R/'output/reports/cpu-only-source.json').read_text());j['rtl_sources'].append('rtl/cpu_bench/cpu_validation_diag.v');(R/'output/reports/cpu-only-source.json').write_text(json.dumps(j,indent=2)+'\n')
p=R/'cpu_bench.pds';s=p.read_text();# add one source entry based on existing top-source XML line
lines=s.splitlines();line=next(x for x in lines if 'cpu_bench_top.v' in x);new=line.replace('cpu_bench_top.v','cpu_validation_diag.v');s=s.replace(line,line+'\n'+new,1);p.write_text(s)
print('Diagnostic observation and memory interface prepared;',len(ports),'AXI signals')
