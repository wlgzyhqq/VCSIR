"""Generate explicit AXI signal wiring and reproducible board/PDS constraints."""
from pathlib import Path
import re, shutil
root=Path(__file__).resolve().parent
text=(root/'rtl/cache/riscv_top.v').read_text()
ports=re.findall(r'(input|output)\s*(\[\s*\d+:\s*\d+\])?\s+(axi_[id]_\w+)_[io]',text)
def width(w):return re.sub(r'\s+','',w) if w else ''
decl='\n'.join(f'wire {width(w)} {n};' for d,w,n in ports)
connect='\n'.join(f',.{n}_{"i" if d=="input" else "o"}({n})' for d,w,n in ports)
busports=',\n'.join(f'{"output reg" if d=="input" else "input wire"} {width(w)} {n}' for d,w,n in ports)
busconnect=',\n'.join(f'.{n}({n})' for d,w,n in ports)
top=f'''// MES50HP PGL50H-6IFBG484, 50 MHz. All board pins from hardware manual.
module final_top #(parameter PREDICT_ENABLE=1, MEM_DELAY=0,
 parameter CLK_HZ=50000000, BAUD=115200, INIT_FILE="firmware/demo.hex")(
 input clk, rstn, input [1:0] keys_n, input uart_rx,
 output uart_tx, output [7:0] led, inout [1:0] gpio);
 reg [1:0] reset_release=0;
 always @(posedge clk or negedge rstn)
 if(!rstn) reset_release<=0; else reset_release<={{reset_release[0],1'b1}};
 wire rst=!reset_release[1];
 reg [1:0] key_meta,key_sync,gpio_meta,gpio_sync;
 always @(posedge clk) begin
   if(rst) begin key_meta<=3; key_sync<=3; gpio_meta<=0; gpio_sync<=0; end
   else begin key_meta<=keys_n; key_sync<=key_meta;
     gpio_meta<=gpio; gpio_sync<=gpio_meta; end
 end
 wire [31:0] gpio_out,gpio_dir;
 wire [31:0] gpio_input={{22'b0,~key_sync,6'b0,gpio_sync}};
 assign gpio[0]=gpio_dir[0]?gpio_out[0]:1'bz;
 assign gpio[1]=gpio_dir[1]?gpio_out[1]:1'bz;
 assign led=gpio_out[15:8];
 wire ext_irq,timer_irq,soft_irq;
 {decl}
 riscv_top #(.PREDICT_ENABLE(PREDICT_ENABLE),.MEM_CACHE_ADDR_MIN(0),
 .MEM_CACHE_ADDR_MAX(32'h0000ffff)) u_cpu(
 .clk_i(clk),.rst_i(rst),.intr_i(ext_irq),.timer_intr_i(timer_irq),
 .soft_intr_i(soft_irq),.reset_vector_i(0)
 {connect});
 final_bus #(.MEM_DELAY(MEM_DELAY),.CLK_HZ(CLK_HZ),.BAUD(BAUD),.INIT_FILE(INIT_FILE)) u_bus(
 .clk(clk),.rst(rst),.gpio_input(gpio_input),.gpio_out(gpio_out),.gpio_dir(gpio_dir),
 .uart_rx(uart_rx),.uart_tx(uart_tx),.ext_irq(ext_irq),.timer_irq(timer_irq),.soft_irq(soft_irq),
 {busconnect});
endmodule
'''
(root/'rtl/final_top.v').write_text(top)
body=(root/'rtl/final_bus_body.vh').read_text()
(root/'rtl/final_bus.v').write_text('''// FINAL dual AXI4 slave: shared 64 KiB block RAM and uncached MMIO.
module final_bus #(parameter MEM_DELAY=0, CLK_HZ=50000000, BAUD=115200,
 parameter INIT_FILE="firmware/demo.hex")(
 input clk,rst,input [31:0] gpio_input, output reg [31:0] gpio_out,gpio_dir,
 input uart_rx,output uart_tx, output ext_irq,timer_irq,soft_irq,
'''+busports+');\n'+body+'\nendmodule\n')
# Use absolute initialization path in FPGA wrapper; simulator overrides it.
p=root/'rtl/final_top.v'; p.write_text(p.read_text().replace('INIT_FILE="firmware/demo.hex"','INIT_FILE="'+(root/'firmware/demo.hex').as_posix()+'"'))
pins=[('clk','P20','INPUT'),('rstn','K18','INPUT'),('keys_n[0]','L15','INPUT'),('keys_n[1]','J17','INPUT'),('uart_rx','R8','INPUT'),('uart_tx','R9','OUTPUT')]
pins += [(f'led[{i}]',p,'OUTPUT') for i,p in enumerate(['B2','A2','B3','A3','C5','A5','F7','F8'])]
pins += [('gpio[0]','AB13','INOUT'),('gpio[1]','Y13','INOUT')]
lines=['# MES50HP manual tables 2-3 / 3-5 / 3-8 / 3-9 / 3-12.', '# KEY1=reset, KEY2/KEY3=GPIO inputs. J8 pins3/4=GPIO. Default 3.3V.']
for port,pin,d in pins:
    for a,v in [('PAP_IO_DIRECTION',d),('PAP_IO_LOC',pin),('PAP_IO_VCCIO','3.3'),('PAP_IO_STANDARD','LVCMOS33'),('PAP_IO_NONE','TRUE')]:
        lines.append(f'define_attribute {{p:{port}}} {{{a}}} {{{v}}}')
    if d!='INPUT':
        lines += [f'define_attribute {{p:{port}}} {{PAP_IO_DRIVE}} {{8}}', f'define_attribute {{p:{port}}} {{PAP_IO_SLEW}} {{SLOW}}']
lines+=['create_clock -name {sys_clk} -period {20.000} -waveform {0 10} [get_ports {clk}]',
 'set_false_path -from [get_ports {rstn}]',
 'set_false_path -from [get_ports {keys_n[*]}] -to [get_cells -hierarchical {*key_meta*}]',
 'set_false_path -from [get_ports {gpio[*]}] -to [get_cells -hierarchical {*gpio_meta*}]',
 'set_false_path -from [get_ports {uart_rx}] -to [get_cells -hierarchical {*rx_meta*}]']
(root/'constraints/mes50hp.fdc').write_text('\n'.join(lines)+'\n')
project=root/'FINAL.pds'; backup=root/'FINAL.pds.before-implementation.bak'
if not backup.exists():shutil.copy2(project,backup)
s=backup.read_text(); files=sorted((root/'rtl').rglob('*.v'))
entries=[]
for f in files:
    marker=' + "final_top"' if f.name=='final_top.v' else ''
    entries.append(f'                (_file "{f.relative_to(root).as_posix()}"{marker}\n                    (_format verilog)\n                    (_timespec "2026-10-02T12:00:00")\n                )')
s=s.replace('        (_widget wgt_my_design_src\n        )','        (_widget wgt_my_design_src\n            (_input\n'+'\n'.join(entries)+'\n            )\n        )')
s=s.replace('        (_widget wgt_import_logic_con_file\n        )','        (_widget wgt_import_logic_con_file\n            (_input\n                (_file "constraints/mes50hp.fdc"\n                    (_format fdc)\n                    (_timespec "2026-10-02T12:00:00")\n                )\n            )\n        )')
project.write_text(s); (root/'sources.f').write_text('\n'.join(f.as_posix() for f in files)+'\n')
print(f'Configured {len(files)} RTL sources, {len(pins)} physical IO bits.')
