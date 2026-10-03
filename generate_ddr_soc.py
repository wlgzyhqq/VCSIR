"""Run after generate_soc.py: replace the BRAM backend and add board DDR IP."""
from pathlib import Path
import re, xml.etree.ElementTree as ET
root=Path(__file__).resolve().parent
ip=root/'ipcore/ddr3_test'
if not (ip/'ddr3_test.idf').exists():raise RuntimeError('Import the board DDR3 IP first')
# The board wrapper originally releases the controller reset on ref_clk.
# Keep PHY/PLL startup in that domain, but release the controller on its own
# running 100 MHz clock. Async assertion still works while that clock stops.
wrapper=ip/'ddr3_test.v'
ws=wrapper.read_text()
if 'u_controller_reset_sync' not in ws:
 ws=ws.replace('wire                              ddr_rstn;', '''wire                              ddr_rstn;
wire                              controller_rstn;
ipsxb_rst_sync_v1_1 u_controller_reset_sync(
 .clk(ddrphy_clkin),.rst_n(ddr_rstn),.sig_async(1'b1),
 .sig_synced(controller_rstn));''')
 ws=ws.replace('.rst_n              (ddr_rstn          ),', '.rst_n              (controller_rstn   ),')
 wrapper.write_text(ws)
# Gate training status is a persistent level from the UI clock domain.
# Synchronize it before the reference-domain reset/retraining state machine.
phywrapper=ip/'ddr3_test_ddrphy_top.v'
ps=phywrapper.read_text()
if 'gate_error_ref_meta' not in ps:
 ps=ps.replace('ipsxb_ddrphy_reset_ctrl_v1_4  ddrphy_reset_ctrl(', '''(* ASYNC_REG="TRUE" *) reg gate_error_ref_meta,gate_error_ref_sync;
always @(posedge ref_clk or negedge ddr_rstn)
 if(!ddr_rstn) begin gate_error_ref_meta<=0;gate_error_ref_sync<=0;end
 else begin gate_error_ref_meta<=gate_check_error;gate_error_ref_sync<=gate_error_ref_meta;end
ipsxb_ddrphy_reset_ctrl_v1_4  ddrphy_reset_ctrl(''')
 ps=ps.replace('.gate_check_error         (gate_check_error        ),', '.gate_check_error         (gate_error_ref_sync     ),')
 phywrapper.write_text(ps)
# Embed only the actual executable bytes as LUT constants, not 64 KiB RAM.
image=(root/'build/firmware/demo.bin').read_bytes()
image+=b'\0'*((-len(image))%32)
lines=['// Generated from demo.bin; little-endian 32-byte DDR bursts.',
 f'localparam BOOT_LINES={len(image)//32};',
 'function [255:0] boot_line;', ' input [15:0] index;',' begin case(index)']
for i in range(len(image)//32):
 lines.append(f" 16'd{i}:boot_line=256'h{int.from_bytes(image[i*32:(i+1)*32],'little'):064x};")
lines+=[' default:boot_line=0;',' endcase end','endfunction']
(root/'firmware/boot_image.vh').write_text('\n'.join(lines)+'\n')
p=root/'rtl/final_ddr_boot.v'
s=p.read_text();s=re.sub(r'`include "[^"]*boot_image.vh"',f'`include "{(root/"firmware/boot_image.vh").as_posix()}"',s);p.write_text(s)
# The generator has just recreated the old port header; replace its body.
p=root/'rtl/final_bus.v';s=p.read_text();header=s[:s.index('reg [31:0] ram')]
header=header.replace('// FINAL dual AXI4 slave: shared 64 KiB block RAM and uncached MMIO.',
 '// FINAL dual AXI4 slave: external DDR3 line adapter and uncached MMIO.')
header=header.replace('input clk,rst,', '''output mem_req_valid,input mem_req_ready,output mem_req_write,
 output [29:0] mem_req_addr,output [255:0] mem_req_data,output [31:0] mem_req_strb,
 input mem_rsp_valid,output mem_rsp_ready,input [255:0] mem_rsp_data,input mem_rsp_error,
 input clk,rst,''')
p.write_text(header+(root/'rtl/final_ddr_bus_body.vh').read_text()+'\nendmodule\n')
p=root/'rtl/final_top.v';s=p.read_text()
s=s.replace('output uart_tx, output [7:0] led, inout [1:0] gpio);', '''output uart_tx, output [7:0] led, inout [1:0] gpio,
 output [15:0] ddr3_addr,output [2:0] ddr3_ba,
 output ddr3_cas_n,ddr3_ck_n,ddr3_ck_p,ddr3_cke,ddr3_cs_n,
 output ddr3_odt,ddr3_ras_n,ddr3_reset_n,ddr3_we_n,
 output [3:0] ddr3_dm,inout [31:0] ddr3_dq,
 inout [3:0] ddr3_dqs_p,ddr3_dqs_n);''')
s=s.replace(' reg [1:0] reset_release=0;', '''wire cpu_clk;
 GTP_CLKBUFG u_cpu_clock(.CLKIN(clk),.CLKOUT(cpu_clk));
 reg [1:0] reset_release=0;''')
s=s.replace('assign led=gpio_out[15:8];', '''wire boot_done,boot_fault,memory_ready,ddr_clk,ddr_init_done,ddr_pll_lock;
 assign led=boot_fault?8'he0:(!boot_done?(memory_ready?8'h40:8'h80):gpio_out[15:8]);
 reg [1:0] cpu_release;
 always @(posedge clk or posedge rst)
 if(rst) cpu_release<=0;else cpu_release<={cpu_release[0],boot_done && !boot_fault && memory_ready};
 wire cpu_rst=!cpu_release[1];''')
s=s.replace('.MEM_CACHE_ADDR_MAX(32\'h0000ffff)', '.MEM_CACHE_ADDR_MAX(32\'h3fffffff)')
s=s.replace('.clk_i(clk),.rst_i(rst)', '.clk_i(clk),.rst_i(cpu_rst)')
s=s.replace('.clk(clk),.rst(rst),.gpio_input', '''.mem_req_valid(bus_req_valid),.mem_req_ready(bus_req_ready),.mem_req_write(bus_req_write),
 .mem_req_addr(bus_req_addr),.mem_req_data(bus_req_data),.mem_req_strb(bus_req_strb),
 .mem_rsp_valid(bus_rsp_valid),.mem_rsp_ready(bus_rsp_ready),.mem_rsp_data(mem_rsp_data),.mem_rsp_error(mem_rsp_error),
 .clk(clk),.rst(cpu_rst),.gpio_input''')
extra='''
 wire boot_req_valid,boot_req_ready,boot_req_write,boot_rsp_valid,boot_rsp_ready;
 wire bus_req_valid,bus_req_ready,bus_req_write,bus_rsp_valid,bus_rsp_ready;
 wire [29:0] boot_req_addr,bus_req_addr;
 wire [255:0] boot_req_data,bus_req_data,mem_rsp_data;
 wire [31:0] boot_req_strb,bus_req_strb;
 wire mem_req_ready,mem_rsp_valid,mem_rsp_ready,mem_rsp_error;
 assign boot_req_ready=!boot_done && mem_req_ready;
 assign bus_req_ready=boot_done && mem_req_ready;
 assign boot_rsp_valid=!boot_done && mem_rsp_valid;
 assign bus_rsp_valid=boot_done && mem_rsp_valid;
 assign mem_rsp_ready=boot_done?bus_rsp_ready:boot_rsp_ready;
 final_ddr_boot u_boot(.clk(clk),.rst(rst),.memory_ready(memory_ready),
  .req_valid(boot_req_valid),.req_ready(boot_req_ready),.req_write(boot_req_write),
  .req_addr(boot_req_addr),.req_data(boot_req_data),.req_strb(boot_req_strb),
  .rsp_valid(boot_rsp_valid),.rsp_ready(boot_rsp_ready),.rsp_data(mem_rsp_data),.rsp_error(mem_rsp_error),
  .done(boot_done),.fault(boot_fault));
 wire [27:0] h_awaddr,h_araddr;
 wire h_awvalid,h_awready,h_arvalid,h_arready,h_wready,h_rvalid;
 wire [255:0] h_wdata,h_rdata;
 wire [31:0] h_wstrb;
 reg [1:0] ddr_release=0;
 always @(posedge ddr_clk or posedge rst)
 if(rst) ddr_release<=0;else ddr_release<={ddr_release[0],ddr_init_done};
 final_ddr_bridge u_mem_bridge(.clk(clk),.rst(rst),.ddr_clk(ddr_clk),.ddr_rst(!ddr_release[1]),.init_done(ddr_init_done),
  .req_valid(boot_done?bus_req_valid:boot_req_valid),.req_ready(mem_req_ready),
  .req_write(boot_done?bus_req_write:boot_req_write),
  .req_addr(boot_done?bus_req_addr:boot_req_addr),.req_data(boot_done?bus_req_data:boot_req_data),
  .req_strb(boot_done?bus_req_strb:boot_req_strb),
  .rsp_valid(mem_rsp_valid),.rsp_ready(mem_rsp_ready),.rsp_data(mem_rsp_data),.rsp_error(mem_rsp_error),.ready(memory_ready),
  .h_awaddr(h_awaddr),.h_awvalid(h_awvalid),.h_awready(h_awready),
  .h_wdata(h_wdata),.h_wstrb(h_wstrb),.h_wready(h_wready),
  .h_araddr(h_araddr),.h_arvalid(h_arvalid),.h_arready(h_arready),.h_rdata(h_rdata),.h_rvalid(h_rvalid));
 // 4Gbit x16 devices: 15 row + 10 column + 3 bank bits; 32-bit combined bus.
 assign ddr3_addr[15]=1'b0;
 ddr3_test u_ddr(.ref_clk(clk),.resetn(!rst),.ddr_init_done(ddr_init_done),
  .ddrphy_clkin(ddr_clk),.pll_lock(ddr_pll_lock),
  .axi_awaddr(h_awaddr),.axi_awuser_ap(1'b0),.axi_awuser_id(4'b0),.axi_awlen(4'b0),
  .axi_awready(h_awready),.axi_awvalid(h_awvalid),.axi_wdata(h_wdata),.axi_wstrb(h_wstrb),.axi_wready(h_wready),
  .axi_araddr(h_araddr),.axi_aruser_ap(1'b0),.axi_aruser_id(4'b0),.axi_arlen(4'b0),
  .axi_arready(h_arready),.axi_arvalid(h_arvalid),.axi_rdata(h_rdata),.axi_rvalid(h_rvalid),
  .apb_clk(clk),.apb_rst_n(!rst),.apb_sel(1'b0),.apb_enable(1'b0),.apb_addr(8'b0),.apb_write(1'b0),.apb_wdata(16'b0),
  .force_ck_dly_en(1'b0),.force_ck_dly_set_bin(8'b0),.init_read_clk_ctrl(2'b0),.init_slip_step(4'b0),
  .force_read_clk_ctrl(1'b0),.ddrphy_gate_update_en(1'b0),.rd_fake_stop(1'b0),
  .mem_rst_n(ddr3_reset_n),.mem_ck(ddr3_ck_p),.mem_ck_n(ddr3_ck_n),.mem_cke(ddr3_cke),
  .mem_cs_n(ddr3_cs_n),.mem_ras_n(ddr3_ras_n),.mem_cas_n(ddr3_cas_n),.mem_we_n(ddr3_we_n),.mem_odt(ddr3_odt),
  .mem_a(ddr3_addr[14:0]),.mem_ba(ddr3_ba),.mem_dqs(ddr3_dqs_p),.mem_dqs_n(ddr3_dqs_n),.mem_dq(ddr3_dq),.mem_dm(ddr3_dm));
'''
# PDS dislikes forward declarations; place bridge wires before CPU and bus.
insert=s.index(' riscv_top #')
s=s[:insert]+extra+s[insert:]
# Explicit global buffer is necessary because HMIC_S has its own input buffer;
# otherwise PDS can leave the large CPU clock fanout on general routing.
s=s.replace('@(posedge clk', '@(posedge cpu_clk').replace('.clk_i(clk)', '.clk_i(cpu_clk)').replace('.clk(clk)', '.clk(cpu_clk)')
p.write_text(s)
# The board example's pins match manual table 2-4; only A15 needs adding.
ref=ip/'board-ddr3-reference.fdc'
fdc=ref.read_text()
fdc=fdc[fdc.index('###==== BEGIN "Generated Clocks"'):]
fdc=fdc.replace('I_ipsxb_ddr_top','u_ddr').replace('{ref_clk}','{sys_clk}').replace('[get_ports {sys_clk}]','[get_ports {clk}]')
# Do not inherit undefined free_clk groups, or accidentally cut all CPU timing.
fdc=re.sub(r'###==== BEGIN set_clock_group".*?###==== END "set_clock_group"','',fdc,flags=re.S)
mapping={'mem_a':'ddr3_addr','mem_ba':'ddr3_ba','mem_dq':'ddr3_dq','mem_dqs_n':'ddr3_dqs_n',
 'mem_dqs':'ddr3_dqs_p','mem_dm':'ddr3_dm','mem_cas_n':'ddr3_cas_n','mem_ck_n':'ddr3_ck_n',
 'mem_ck':'ddr3_ck_p','mem_cke':'ddr3_cke','mem_cs_n':'ddr3_cs_n','mem_odt':'ddr3_odt',
 'mem_ras_n':'ddr3_ras_n','mem_rst_n':'ddr3_reset_n','mem_we_n':'ddr3_we_n'}
fdc=re.sub(r'\b('+'|'.join(sorted(mapping,key=len,reverse=True))+r')\b',lambda m:mapping[m[0]],fdc)
# The example also constrains its own LEDs/UART/reset. Keep only DDR pads.
fdc='\n'.join(line for line in fdc.splitlines()
             if not ('define_attribute {p:' in line and '{p:ddr3_' not in line))+'\n'
# HSTL15_I / HSTL15D_I are the supported PGL50H PHY standards emitted by HMIC_S.
fdc+='''
define_attribute {p:ddr3_addr[15]} {PAP_IO_DIRECTION} {OUTPUT}
define_attribute {p:ddr3_addr[15]} {PAP_IO_LOC} {R7}
define_attribute {p:ddr3_addr[15]} {PAP_IO_VCCIO} {1.5}
define_attribute {p:ddr3_addr[15]} {PAP_IO_STANDARD} {HSTL15_I}
define_attribute {p:ddr3_addr[15]} {PAP_IO_DRIVE} {8}
define_attribute {p:ddr3_addr[15]} {PAP_IO_SLEW} {FAST}
# Only toggle synchronizer first stages are exempt from clock-domain timing.
set_false_path -to [get_cells -hierarchical {*u_mem_bridge*ack_meta*}]
set_false_path -to [get_cells -hierarchical {*u_mem_bridge*req_meta*}]
set_false_path -to [get_cells -hierarchical {*u_mem_bridge*init_meta*}]
# Only the asynchronous reset inputs of the two-stage reset synchronizers
# cross domains; all controller/bridge reset release paths remain timed.
set_false_path -from [get_cells -hierarchical {*u_ddr*u_ddrp_rstn_sync*}] -to [get_cells -hierarchical {*u_ddr*u_controller_reset_sync*}]
set_false_path -from [get_cells -hierarchical {*reset_release*}] -to [get_cells -hierarchical {*ddr_release*}]
# HMIC_S startup resets: the reference-clock state machine asserts/releases
# the DQS/IO reset while starting the divider, before training/user traffic.
# The original IP separates these clock domains. Limit exceptions to those
# startup reset sources and the async inputs of its reset synchronizers.
set_false_path -from [get_cells -hierarchical {*u_ddr*ddrphy_reset_ctrl*ddrphy_dqs_rst*}] -to [get_cells -hierarchical {*u_ddr*ddrphy_slice_top*}]
set_false_path -from [get_cells -hierarchical {*u_ddr*ddrphy_reset_ctrl*}] -to [get_cells -hierarchical {*u_ddr*ddrphy_reset_ctrl*u_ddrphy_rstn_sync*}]
set_false_path -from [get_cells -hierarchical {*u_ddr*ddrphy_reset_ctrl*}] -to [get_cells -hierarchical {*u_ddr*ddrphy_reset_ctrl*u_dll_rst_sync*}]
set_false_path -from [get_cells -hierarchical {*u_ddr*ddrphy_reset_ctrl*logic_rstn*}] -to [get_cells -hierarchical {*u_ddr*ddrphy_slice_top*u_logic_rstn_sync*}]
set_false_path -to [get_cells -hierarchical {*u_ddr*gate_error_ref_meta*}]
# Bundled payloads stay constant for the complete synchronized request/response.
set_max_delay 15.000 -datapath_only -from [get_cells -hierarchical {*u_mem_bridge*req_*hold*}] -to [get_cells -hierarchical {*u_mem_bridge*native_*}]
set_max_delay 15.000 -datapath_only -from [get_cells -hierarchical {*u_mem_bridge*rsp_*hold*}] -to [get_cells -hierarchical {*u_mem_bridge*rsp_data*}]
# Data is held until the round-trip toggle completes, so coincident clock-edge
# hold checks do not describe these asynchronous bundled-data transfers.
set_false_path -hold -from [get_cells -hierarchical {*u_mem_bridge*req_*hold*}] -to [get_cells -hierarchical {*u_mem_bridge*native_*}]
set_max_delay 15.000 -datapath_only -from [get_cells -hierarchical {*u_mem_bridge*req_write_hold*}] -to [get_cells -hierarchical {*u_mem_bridge*state*}]
set_false_path -hold -from [get_cells -hierarchical {*u_mem_bridge*req_write_hold*}] -to [get_cells -hierarchical {*u_mem_bridge*state*}]
set_false_path -hold -from [get_cells -hierarchical {*u_mem_bridge*rsp_*hold*}] -to [get_cells -hierarchical {*u_mem_bridge*rsp_data*}]
# HMIC_S example separates PHY IO/gate clocks from its controller domain.
set_clock_groups -asynchronous -group [get_clocks {sys_clk ddrphy_clkin}] -group [get_clocks {ioclk0}] -group [get_clocks {ioclk1}] -group [get_clocks {ioclk2}] -group [get_clocks {ioclk_gate_clk}]
'''
(root/'constraints/mes50hp_ddr3.fdc').write_text(fdc)
# Verify every DDR pin against a transcription of the hardware manual, not IDF.
expected={'ddr3_addr': 'N6 R4 P6 F3 V5 E4 V3 D2 U4 P5 P8 T4 P7 P4 T3 R7'.split(),
 'ddr3_ba':'F5 W4 N7'.split(),
 'ddr3_dq':'U1 U3 T2 Y2 T1 Y1 M7 W1 P1 M2 R1 M1 P2 L3 P3 N4 K4 K1 J3 L4 K3 M3 J1 M4 J6 F1 K7 F2 H5 H3 J4 G3'.split(),
 'ddr3_dqs_p':'V2 N3 M6 E3'.split(),'ddr3_dqs_n':'V1 N1 L6 E1'.split(),
 'ddr3_dm':'W3 L1 K2 G1'.split()}
locs=dict(re.findall(r'define_attribute \{p:([^}]+)\} \{PAP_IO_LOC\} \{([^}]+)\}',fdc))
for signal,pins in expected.items():
 for i,pin in enumerate(pins):assert locs[f'{signal}[{i}]']==pin,(signal,i,pin)
control={'ddr3_cas_n':'H8','ddr3_ck_n':'T5','ddr3_ck_p':'T6','ddr3_cke':'Y3',
 'ddr3_cs_n':'G6','ddr3_odt':'G7','ddr3_ras_n':'J7','ddr3_reset_n':'C1','ddr3_we_n':'H6'}
for signal,pin in control.items():assert locs[signal]==pin,(signal,pin)
assert len(set(locs.values()))==len(locs)
# Add actual IP synthesis source list; no simulation models or black boxes.
idf=ET.parse(ip/'ddr3_test.idf')
src=idf.find('./file_list/source')
if src is None:
 print([(x.tag,x.attrib) for x in idf.findall('./file_list/*')]);raise RuntimeError('No synthesis list in IDF')
files=[ip/x.attrib['pathname'] for x in src.findall('file')]
assert all(x.exists() for x in files)
p=root/'FINAL.pds';s=p.read_text()
entries=[]
for path in files:
 entries.append(f'                (_file "{path.relative_to(root).as_posix()}"\n                    (_format verilog)\n                    (_timespec "2026-10-02T17:00:00")\n                )')
widget='        (_widget wgt_my_design_src\n            (_input\n'
s=s.replace(widget,widget+'\n'.join(entries)+'\n')
widget='        (_widget wgt_import_logic_con_file\n            (_input\n'
s=s.replace(widget,widget+'                (_file "constraints/mes50hp_ddr3.fdc"\n                    (_format fdc)\n                    (_timespec "2026-10-02T17:00:00")\n                )\n')
# Import the reference clock before derived DDR clock constraints.
s=s.replace('constraints/mes50hp_ddr3.fdc','constraints/__ddr_second.fdc').replace('constraints/mes50hp.fdc','constraints/mes50hp_ddr3.fdc').replace('constraints/__ddr_second.fdc','constraints/mes50hp.fdc')
p.write_text(s)
print(f'DDR3 backend: 1 GiB, 32-bit physical bus, 256-bit UI; {len(image)} boot bytes; {len(locs)} DDR pins verified.')
