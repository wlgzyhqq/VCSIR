"""Separate CNN project/build directory; preserve image milestone project/bit."""
from pathlib import Path
import re,json,hashlib,shutil,argparse
ap=argparse.ArgumentParser();ap.add_argument('--build-dir',default='cnn64-90-synth');a=ap.parse_args()
R=Path(__file__).resolve().parents[1];D=R/a.build_dir;assert D.resolve().is_relative_to(R);D.mkdir(exist_ok=True)
assert not (D/'active.json').exists(),'CNN build is active; do not rewrite its snapshot'
s=(R/'rtl/final_top.v').read_text()
s=s.replace('riscv_top #(.PREDICT_ENABLE(PREDICT_ENABLE),','riscv_top #(.SUPPORT_LOAD_BYPASS(0),.PREDICT_ENABLE(PREDICT_ENABLE),')
s=s.replace('parameter CLK_HZ=50000000','parameter CLK_HZ=90000000')
old=' GTP_CLKBUFG u_cpu_clock(.CLKIN(clk),.CLKOUT(cpu_clk));'
assert old in s
s=s.replace(old,''' wire cpu_raw,cpu_lock;
 yolo_cpu_pll u_cpu_pll(.clkin1(clk),.clkout0(cpu_raw),.clkout1(),.pll_lock(cpu_lock));
 GTP_CLKBUFG u_cpu_clock(.CLKIN(cpu_raw),.CLKOUT(cpu_clk));''')
s=s.replace('always @(posedge cpu_clk or negedge rstn)\n if(!rstn)',
 'always @(posedge cpu_clk or negedge rstn or negedge cpu_lock)\n if(!rstn || !cpu_lock)')
# The DDR reference/APB clock is still board50, so release its reset there.
s=s.replace(' wire rst=!reset_release[1];',''' wire rst=!reset_release[1];
 reg [1:0] ref_release=0;
 always @(posedge clk or negedge rstn)
 if(!rstn)ref_release<=0;else ref_release<={ref_release[0],1'b1};
 wire ref_rst=!ref_release[1];''')
s=s.replace('.resetn(!rst)', '.resetn(!ref_rst)').replace('.apb_rst_n(!rst)', '.apb_rst_n(!ref_rst)')
masters=' wire [3:0] master_awready,master_arready,master_wready,master_rvalid;\n wire [1023:0] master_rdata;'
assert s.count(masters)==1;s=s.replace(masters,'')
needle=" assign lin_write_ok=0;assign lin_rdata=32'h434e4e30;"
replacement=masters+'''
 wire [27:0] n_awaddr,n_araddr;wire [3:0] n_len;wire n_awvalid,n_arvalid;wire [255:0] n_wdata;wire [31:0] n_wstrb;
 wire [27:0] x_awaddr,x_araddr;wire [3:0] x_len;wire x_awvalid,x_arvalid,x_awready,x_arready,x_rvalid,x_wready,x_fault;
 wire [255:0] x_wdata,x_rdata;wire [31:0] x_wstrb;
 yolo_cnn #(.MAC_LANES(8),.COMPUTE_HZ(90000000)) u_cnn(.clk(cpu_clk),.rst(rst),.cpu_addr(lin_addr),.cpu_wdata(lin_wdata),.cpu_wstrb(lin_wstrb),.cpu_we(lin_we),
 .cpu_write_ok(lin_write_ok),.cpu_rdata(lin_rdata),.ui_clk(cpu_clk),.ui_rst(rst),.arb_fault({2'b0,x_fault}),
 .araddr(x_araddr),.awaddr(x_awaddr),.len(x_len),.arvalid(x_arvalid),.awvalid(x_awvalid),
 .arready(x_arready),.awready(x_awready),.rvalid(x_rvalid),.wready(x_wready),
 .rdata(x_rdata),.wdata(x_wdata),.wstrb(x_wstrb));
 yolo_burst_cdc u_cnn_ddr_cdc(.s_clk(cpu_clk),.s_rst(rst),.d_clk(ddr_clk),.d_rst(!ddr_release[1]),.d_fault(dma_arb_fault),
 .s_araddr(x_araddr),.s_awaddr(x_awaddr),.s_len(x_len),.s_arvalid(x_arvalid),.s_awvalid(x_awvalid),
 .s_wdata(x_wdata),.s_wstrb(x_wstrb),.s_arready(x_arready),.s_awready(x_awready),.s_rvalid(x_rvalid),.s_wready(x_wready),.s_rdata(x_rdata),.fault(x_fault),
 .araddr(n_araddr),.awaddr(n_awaddr),.len(n_len),.arvalid(n_arvalid),.awvalid(n_awvalid),
 .arready(master_arready[3]),.awready(master_awready[3]),.rvalid(master_rvalid[3]),.wready(master_wready[3]),
 .rdata(master_rdata[1023:768]),.wdata(n_wdata),.wstrb(n_wstrb));'''
replacement=replacement.replace('.araddr(n_', '.d_araddr(n_').replace('.awaddr(n_', '.d_awaddr(n_').replace('.len(n_', '.d_len(n_').replace('.arvalid(n_', '.d_arvalid(n_').replace('.awvalid(n_', '.d_awvalid(n_')
for port in ('arready','awready','rvalid','wready','rdata'):
 replacement=replacement.replace('.'+port+'(master_', '.d_'+port+'(master_')
replacement=replacement.replace('.wdata(n_wdata)', '.d_wdata(n_wdata)').replace('.wstrb(n_wstrb)', '.d_wstrb(n_wstrb)')
assert needle in s;s=s.replace(needle,replacement)
for a,b in [
 (".m_awaddr({28'b0,28'b0,d_awaddr,c_awaddr})",".m_awaddr({n_awaddr,28'b0,d_awaddr,c_awaddr})"),
 (".m_araddr({28'b0,v_araddr,d_araddr,c_araddr})",".m_araddr({n_araddr,v_araddr,d_araddr,c_araddr})"),
 (".m_len({4'b0,v_len,d_len,4'b0})",".m_len({n_len,v_len,d_len,4'b0})"),
 (".m_awvalid({2'b0,d_awvalid,c_awvalid})",".m_awvalid({n_awvalid,1'b0,d_awvalid,c_awvalid})"),
 (".m_arvalid({1'b0,v_arvalid,d_arvalid,c_arvalid})",".m_arvalid({n_arvalid,v_arvalid,d_arvalid,c_arvalid})"),
 (".m_wdata({512'b0,d_wdata,c_wdata})",".m_wdata({n_wdata,256'b0,d_wdata,c_wdata})"),
 (".m_wstrb({64'b0,d_wstrb,c_wstrb})",".m_wstrb({n_wstrb,32'b0,d_wstrb,c_wstrb})")]:
    assert a in s,a;s=s.replace(a,b)
(R/'rtl/final_top_cnn.v').write_text(s)
p=(R/'final_yolo.pds').read_text();assert p.startswith('(_flow')
p=re.sub(r'\(_option gplace_seed \(_integer \d+\)\)','(_option gplace_seed (_integer 17))',p)
for key,value in [('fix_hold_violation_threshold',200),('fix_hold_violation_threshold_for_clock_path_cross_srb',500),('fix_hold_violation_threshold_for_clk_tree',200)]:
    p=re.sub(r'\(_option '+key+r' \(_integer \d+\)\)',f'(_option {key} (_integer {value}))',p)
marker='(_file "rtl/final_top.v" + "final_top"'
assert p.count(marker)==1
entries=''.join('(_file "rtl/'+n+'" (_format verilog) (_timespec "2026-11-01T20:00:00"))\n' for n in ('yolo_cnn.v','yolo_conv.v','yolo_mac64.v','yolo_requant.v','yolo_burst_cdc.v','yolo_cpu_pll.v'))
p=p.replace(marker,entries+'(_file "rtl/final_top_cnn.v" + "final_top"')
needle='(_file "constraints/mes50hp_sd.fdc"'
assert p.count(needle)==1;p=p.replace(needle,'(_file "constraints/cnn90.fdc" (_format fdc) (_timespec "2026-11-01T20:00:00"))\n'+needle)
p=re.sub(r'\(_file "((?:rtl|ipcore|constraints)/[^"\n]+)"',lambda m:'(_file "'+(R/m[1]).as_posix()+'"',p)
inputs=re.findall(r'\(_file "([^"\n]+)"(?:\s*\+\s*"[^"\n]+")?\s*\(_format (?:verilog|fdc)\)',p)
inputs=list(dict.fromkeys(Path(n) for n in inputs if Path(n).is_absolute()))
S=D/'source';actual=[];original={}
for f in list(inputs):
    if f.suffix not in ('.v','.vp'):continue
    for name in re.findall(rb'`include\s+"([^"\n]+)"',f.read_bytes()):
        rel=Path(name.decode('ascii'));src=rel if rel.is_absolute() else R/rel
        if src.is_file() and src.is_relative_to(R):
            inputs.append(src)
            if not rel.is_absolute():
                dst=D/rel;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst);actual.append(dst)
for f in dict.fromkeys(inputs):
    assert f.is_relative_to(R)
    dst=S/f.relative_to(R);dst.parent.mkdir(parents=True,exist_ok=True)
    content=f.read_bytes().replace(R.as_posix().encode(),S.as_posix().encode())
    dst.write_bytes(content);actual.append(dst);original[str(f.relative_to(R))]=hashlib.sha256(f.read_bytes()).hexdigest()
    p=p.replace('"'+f.as_posix()+'"','"'+dst.as_posix()+'"')
(D/'final_yolo_cnn.pds').write_text(p)
report=dict(project=str(D/'final_yolo_cnn.pds'),sources={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in actual},original_source_sha256=original,image_project_modified=False,board_verified=False)
(D/'inputs.json').write_text(json.dumps(report,indent=2)+'\n')
print('Prepared isolated CNN project',len(actual),'snapshot inputs; image project/source and TF image unchanged')
