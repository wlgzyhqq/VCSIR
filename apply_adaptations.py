"""Additional platform/ISA adaptations; run after setup_project.py."""
from pathlib import Path
import subprocess, sys, re
root=Path(__file__).resolve().parent
def change(name,fn):
 p=root/name;p.write_text(fn(p.read_text()))
# Keep precise branch next-PC bookkeeping distinct from prediction recovery.
# CSR counters count WB retirement, not instructions that trap.
change('rtl/core/riscv_issue.v',lambda s:s.replace(',output          fetch_accept_o', ',output          retired_o\n    ,output          fetch_accept_o').replace('assign fetch_accept_o', 'assign retired_o = pipe_valid_wb_w && !(|csr_writeback_exception_o);\nassign fetch_accept_o',1))
change('rtl/core/riscv_core.v',lambda s:s.replace('wire [31:0] fetch_pred_next_w;', 'wire retired_w;\nwire [31:0] fetch_pred_next_w;').replace(',.intr_i(intr_i)', ',.retired_i(retired_w)\n    ,.intr_i(intr_i)').replace(',.fetch_accept_o(fetch_accept_w)', ',.retired_o(retired_w)\n    ,.fetch_accept_o(fetch_accept_w)'))
change('rtl/core/riscv_csr.v',lambda s:s.replace(',input           intr_i', ',input           retired_i\n    ,input           intr_i').replace(',.ext_intr_i(intr_i)', ',.retired_i(retired_i)\n    ,.ext_intr_i(intr_i)'))
p=root/'rtl/core/riscv_csr.v';s=p.read_text()
decl='''reg csr_known_r;
always @* begin
 case(opcode_opcode_i[31:20])
  12'h300,12'h301,12'h302,12'h303,12'h304,12'h305,
  12'h340,12'h341,12'h342,12'h343,12'h344,
  12'hb00,12'hb80,12'hb02,12'hb82,12'hc00,12'hc80,
  12'hc01,12'hc81,12'hc02,12'hc82,12'hf14:
     csr_known_r=1;
  default:csr_known_r=0;
 endcase
end
'''
s=s.replace('reg         csr_fault_r;', 'reg         csr_fault_r;\n'+decl)
s=s.replace('((csr_write_r && csr_readonly_r) || (current_priv_w < csr_priv_r))', '(!csr_known_r || (csr_write_r && csr_readonly_r) || (current_priv_w < csr_priv_r))')
s=s.replace('SUPPORT_SUPER ? (opcode_valid_i && (set_r | clr_r) &&', '(opcode_valid_i && (set_r | clr_r) &&').replace('(current_priv_w < csr_priv_r))) : 1\'b0;', '(current_priv_w < csr_priv_r)));')
s=s.replace('eret_w && (current_priv_w < eret_priv_w)', 'eret_w && (eret_priv_w != `PRIV_MACHINE)')
p.write_text(s)
def regfile(s):
 s=s.replace(',input           ext_intr_i', ',input           retired_i\n    ,input           ext_intr_i')
 s=s.replace('reg [31:0] rdata_r;', '''reg [63:0] cycle_count, instret_count;
always @(posedge clk_i or posedge rst_i)
if(rst_i) begin cycle_count<=0;instret_count<=0;end
else begin
 cycle_count<=cycle_count+1'b1;
 if(retired_i) instret_count<=instret_count+1'b1;
 if(csr_waddr_i==12'hb00 && !(|exception_i)) cycle_count[31:0]<=csr_wdata_i;
 if(csr_waddr_i==12'hb80 && !(|exception_i)) cycle_count[63:32]<=csr_wdata_i;
 if(csr_waddr_i==12'hb02 && !(|exception_i)) instret_count[31:0]<=csr_wdata_i;
 if(csr_waddr_i==12'hb82 && !(|exception_i)) instret_count[63:32]<=csr_wdata_i;
end
reg [31:0] rdata_r;''')
 s=s.replace("csr_sr_q           <= 32'b0;", "csr_sr_q           <= 32'h00001800;")
 s=s.replace('csr_sr_q           <= csr_sr_r;', "csr_sr_q           <= (csr_sr_r & 32'h00000088) | 32'h00001800;")
 s=s.replace('`CSR_MCYCLE,\n    `CSR_MTIME:    rdata_r = csr_mcycle_q;', "12'hb00,12'hc00: rdata_r=cycle_count[31:0];\n    12'hb80,12'hc80: rdata_r=cycle_count[63:32];\n    12'hb02,12'hc02: rdata_r=instret_count[31:0];\n    12'hb82,12'hc82: rdata_r=instret_count[63:32];\n    `CSR_MTIME: rdata_r=csr_mcycle_q;")
 old='''if (interrupt_o[`IRQ_M_SOFT])
                csr_mcause_r = `MCAUSE_INTERRUPT + 32'd`IRQ_M_SOFT;
            else if (interrupt_o[`IRQ_M_TIMER])
                csr_mcause_r = `MCAUSE_INTERRUPT + 32'd`IRQ_M_TIMER;
            else if (interrupt_o[`IRQ_M_EXT])
                csr_mcause_r = `MCAUSE_INTERRUPT + 32'd`IRQ_M_EXT;'''
 new='''if (interrupt_o[`IRQ_M_EXT])
                csr_mcause_r = `MCAUSE_INTERRUPT + 32'd`IRQ_M_EXT;
            else if (interrupt_o[`IRQ_M_SOFT])
                csr_mcause_r = `MCAUSE_INTERRUPT + 32'd`IRQ_M_SOFT;
            else if (interrupt_o[`IRQ_M_TIMER])
                csr_mcause_r = `MCAUSE_INTERRUPT + 32'd`IRQ_M_TIMER;'''
 assert old in s;s=s.replace(old,new)
 return s
change('rtl/core/riscv_csr_regfile.v',regfile)
change('rtl/core/riscv_defs.v',lambda s:s.replace('CSR_MEPC_MASK   32\'hFFFFFFFF','CSR_MEPC_MASK   32\'hFFFFFFFC').replace('CSR_MEPC_MASK     32\'hFFFFFFFF','CSR_MEPC_MASK     32\'hFFFFFFFC'))
# AXI ID is a four-bit field, even though the configuration parameter is integer.
change('rtl/cache/dcache_axi.v',lambda s:s.replace('.inport_id_i(AXI_ID)', '.inport_id_i(AXI_ID[3:0])'))
# In FINAL both dcache instances tie wr0_i to zero. Specialize the read-only
# CPU port before PDS inference; the refill/store port remains the sole writer.
def cache_ram(s):
 start=s.index('    if (wr0_i[0])')
 end=s.index('    ram_read0_q', start)
 s=s[:start]+s[end:]
 return s
change('rtl/cache/dcache_core_data_ram.v',cache_ram)
subprocess.run([sys.executable,str(root/'sim/fix_includes.py')],check=True)
print('Applied CSR validation/counters, retirement wiring and four-bit AXI ID.')
