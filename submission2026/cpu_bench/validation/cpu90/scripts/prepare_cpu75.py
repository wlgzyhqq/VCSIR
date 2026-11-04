"""Independent 75MHz predecode experiment; keep measured root baseline intact."""
from pathlib import Path
import hashlib,json,re,shutil
R=Path(__file__).resolve().parents[1];D=R/'variants/cpu75-predecode';assert not D.exists();D.mkdir(parents=True)
source=json.loads((R/'output/reports/cpu-only-source.json').read_text())
for n in source['rtl_sources']:
 p=D/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(R/n,p)
for name in ['firmware/cpu_only','firmware/cpu_bench.h','firmware/runtime.c','third_party/coremark']:
 p=R/name;q=D/name;q.parent.mkdir(parents=True,exist_ok=True)
 if p.is_dir():shutil.copytree(p,q,ignore=shutil.ignore_patterns('__pycache__'))
 else:shutil.copy2(p,q)
(D/'scripts').mkdir()
for n in ['build_cpu_only.py','run_cpu_only.py','serial_transport.py','accept_cpu_only.py']:
 t=(R/'scripts'/n).read_text();t=t.replace('50000000','75000000')
 if n=='accept_cpu_only.py':t=t.replace('/seconds/50','/seconds/75')
 (D/'scripts'/n).write_text(t)
p=D/'firmware/cpu_only/main.c';p.write_text(p.read_text().replace('50000000','75000000').replace('50MHz','75MHz'))
# Clock wrapper is the existing licensed Pango PLL wrapper, only ratios change.
pll=(R/'rtl/final_hdmi_pll.v').read_text().replace('module final_hdmi_pll','module cpu_bench_pll')
for n,v in [('STATIC_RATIOI',1),('STATIC_RATIO0',16),('STATIC_RATIOF',24),('STATIC_DUTY0',16)]:
 pll,count=re.subn(r'(localparam integer '+n+r'\s*=\s*)\d+',lambda m:m[1]+str(v),pll);assert count==1,n
(D/'rtl/cpu_bench/cpu_bench_pll.v').write_text(pll)
source['rtl_sources'].append('rtl/cpu_bench/cpu_bench_pll.v')
p=D/'rtl/cpu_bench/cpu_bench_top.v';top=p.read_text().replace('CLK_HZ=50000000','CLK_HZ=75000000')
top=top.replace('inout [1:0] gpio);','''inout [1:0] gpio);
 wire pll_clk,pll_lock,cpu_clk;
 cpu_bench_pll u_cpu_pll(.clkin1(clk),.clkout0(pll_clk),.clkout1(),.pll_lock(pll_lock));
 GTP_CLKBUFG u_cpu_clock(.CLKIN(pll_clk),.CLKOUT(cpu_clk));
 wire arst=!rstn || !pll_lock;''')
top=top.replace('posedge clk','posedge cpu_clk').replace('or negedge rstn','or posedge arst').replace('if(!rstn)','if(arst)').replace('.clk_i(clk)','.clk_i(cpu_clk)').replace('.clk(clk)','.clk(cpu_clk)');p.write_text(top)
# Move the existing pure decoder across the SAME register boundary, not add a stage.
p=D/'rtl/core/riscv_decode.v';t=p.read_text();start=t.index('if (EXTRA_DECODE_STAGE)');end=t.index('// Straight through decode',start);head=t[:start];block=t[start:end];tail=t[end:]
assert block.count('reg [66:0]  buffer_q;')==1
flags=['invalid','exec','lsu','branch','mul','div','csr','rd_valid']
block=block.replace('reg [66:0]  buffer_q;','reg [74:0] buffer_q;\n    wire [7:0] decoded_in;')
block=block.replace("buffer_q <= 67'b0;","buffer_q <= 75'b0;")
block=block.replace('buffer_q <= {fetch_in_valid_i,','buffer_q <= {decoded_in, fetch_in_valid_i,')
block=block.replace('} = buffer_q;','} = buffer_q[66:0];')
block=block.replace('.valid_i(fetch_out_valid_o)','.valid_i(fetch_in_valid_i)').replace('.fetch_fault_i(fetch_out_fault_page_o | fetch_out_fault_fetch_o)','.fetch_fault_i(fetch_in_fault_page_i | fetch_in_fault_fetch_i)').replace('.opcode_i(fetch_out_instr_o)','.opcode_i(fetch_in_instr_w)')
for i,n in enumerate(flags):
 old='.'+n+'_o(fetch_out_instr_'+n+'_o)';assert old in block,n
 block=block.replace(old,'.'+n+'_o(decoded_in['+str(i)+'])')
 block=block.replace('    riscv_decoder\n','    assign fetch_out_instr_'+n+'_o = buffer_q['+str(67+i)+'];\n    riscv_decoder\n',1)
t=head+block+tail;p.write_text(t)
# Keep all board pin constraints and real clock checks; no core false paths.
fdc=(R/'constraints/cpu_bench.fdc').read_text()+'''
create_generated_clock -name {cpu_clk} -source [get_ports {clk}] -master_clock [get_clocks {sys_clk}] -multiply_by {3} -divide_by {2} [get_pins {u_cpu_pll/u_pll_e3/CLKOUT0}]
set_clock_uncertainty {0.200} [get_clocks {cpu_clk}] -setup -hold
set_false_path -from [get_pins {u_cpu_pll/u_pll_e3/LOCK}] -to [get_cells -hierarchical {*reset_release*}]
'''
(D/'constraints').mkdir();(D/'constraints/cpu_bench.fdc').write_text(fdc)
t=(R/'cpu_bench.pds').read_text();t,count=re.subn(r'(\(_widget wgt_my_design_src\s+\(_input)',r'\1\n (_file "rtl/cpu_bench/cpu_bench_pll.v" (_format verilog) (_timespec "2026-10-31T00:00:00"))',t,count=1);assert count==1
(D/'cpu_bench.pds').write_text(t)
(D/'output/reports').mkdir(parents=True)
source.update(CPU_target_hz=75000000,CPU_core_changed=True,optimization='Pure instruction-class decode moved before existing buffer, 8 decoded flags registered with same payload/enable/reset/squash',board_test=False)
(D/'output/reports/cpu-only-source.json').write_text(json.dumps(source,indent=2)+'\n')
print('Independent CPU75 predecode candidate prepared; no baseline inputs changed')
