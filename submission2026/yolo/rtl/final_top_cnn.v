// MES50HP PGL50H-6IFBG484, 50 MHz. All board pins from hardware manual.
module final_top #(parameter PREDICT_ENABLE=1, MEM_DELAY=0,
 parameter CLK_HZ=90000000, BAUD=115200, INIT_FILE="firmware/demo.hex")(
 input clk, rstn, input [1:0] keys_n, input uart_rx,
 output uart_tx, output [7:0] led, inout [1:0] gpio,
 output [15:0] ddr3_addr,output [2:0] ddr3_ba,
 output ddr3_cas_n,ddr3_ck_n,ddr3_ck_p,ddr3_cke,ddr3_cs_n,
 output ddr3_odt,ddr3_ras_n,ddr3_reset_n,ddr3_we_n,
 output [3:0] ddr3_dm,inout [31:0] ddr3_dq,
 inout [3:0] ddr3_dqs_p,ddr3_dqs_n,
 output hdmi_pclk,hdmi_hs,hdmi_vs,hdmi_de,output [23:0] hdmi_data,
 output hdmi_rstn,inout hdmi_scl,hdmi_sda,
 output sd_clk,sd_cmd,sd_cs_n,input sd_d0,sd_detect_n);
wire cpu_clk;
 wire cpu_raw,cpu_lock;
 yolo_cpu_pll u_cpu_pll(.clkin1(clk),.clkout0(cpu_raw),.clkout1(),.pll_lock(cpu_lock));
 GTP_CLKBUFG u_cpu_clock(.CLKIN(cpu_raw),.CLKOUT(cpu_clk));
 reg [1:0] reset_release=0;
 always @(posedge cpu_clk or negedge rstn or negedge cpu_lock)
 if(!rstn || !cpu_lock) reset_release<=0; else reset_release<={reset_release[0],1'b1};
 wire rst=!reset_release[1];
 reg [1:0] ref_release=0;
 always @(posedge clk or negedge rstn)
 if(!rstn)ref_release<=0;else ref_release<={ref_release[0],1'b1};
 wire ref_rst=!ref_release[1];
 reg [1:0] key_meta,key_sync,gpio_meta,gpio_sync;
 always @(posedge cpu_clk) begin
   if(rst) begin key_meta<=3; key_sync<=3; gpio_meta<=0; gpio_sync<=0; end
   else begin key_meta<=keys_n; key_sync<=key_meta;
     gpio_meta<=gpio; gpio_sync<=gpio_meta; end
 end
 wire [31:0] gpio_out,gpio_dir;
 wire [31:0] gpio_input={22'b0,~key_sync,6'b0,gpio_sync};
 assign gpio[0]=gpio_dir[0]?gpio_out[0]:1'bz;
 assign gpio[1]=gpio_dir[1]?gpio_out[1]:1'bz;
 wire boot_done,boot_fault,memory_ready,ddr_clk,ddr_init_done,ddr_pll_lock;
 wire boot_request,bus_quiet,boot_main;wire [31:0] boot_bytes,boot_copied_bytes;
 assign led=boot_fault?8'he0:(!boot_done?(memory_ready?8'h40:8'h80):gpio_out[15:8]);
 reg [1:0] cpu_release;
 always @(posedge cpu_clk or posedge rst)
 if(rst) cpu_release<=0;else cpu_release<={cpu_release[0],boot_done && !boot_fault && memory_ready};
 wire cpu_rst=!cpu_release[1] || !boot_done;
 wire [31:0] hdmi_control,hdmi_status;
 wire [63:0] hdmi_measurement;
 wire [31:0] terminal_addr,terminal_wdata,terminal_rdata;
 wire [3:0] terminal_wstrb;
 wire terminal_we,terminal_write_ok;
 reg [1:0] ddr_release=0;wire [2:0] dma_arb_fault;
 wire [27:0] v_araddr;wire [3:0] v_len;wire v_arvalid,v_arready,v_rvalid;wire [255:0] v_rdata;
 final_hdmi #(.CPU_HZ(CLK_HZ)) u_hdmi(.ref_clk(clk),.ui_clk(ddr_clk),.ui_rst(!ddr_release[1]),.arb_fault(dma_arb_fault),
 .video_araddr(v_araddr),.video_arlen(v_len),.video_arvalid(v_arvalid),.video_arready(v_arready),.video_rvalid(v_rvalid),.video_rdata(v_rdata),.clk(cpu_clk),.rst(rst),.control(hdmi_control),
 .terminal_addr(terminal_addr),.terminal_wdata(terminal_wdata),.terminal_wstrb(terminal_wstrb),
 .terminal_we(terminal_we),.terminal_write_ok(terminal_write_ok),.terminal_rdata(terminal_rdata),
 .boot_done(boot_done),.boot_fault(boot_fault),.memory_ready(memory_ready),
 .status(hdmi_status),.measurement(hdmi_measurement),.hdmi_pclk(hdmi_pclk),.hdmi_hs(hdmi_hs),.hdmi_vs(hdmi_vs),
 .hdmi_de(hdmi_de),.hdmi_data(hdmi_data),.hdmi_rstn(hdmi_rstn),
 .hdmi_scl(hdmi_scl),.hdmi_sda(hdmi_sda));
 wire ext_irq,timer_irq,soft_irq;
 wire  axi_i_awready;
wire  axi_i_wready;
wire  axi_i_bvalid;
wire [1:0] axi_i_bresp;
wire [3:0] axi_i_bid;
wire  axi_i_arready;
wire  axi_i_rvalid;
wire [31:0] axi_i_rdata;
wire [1:0] axi_i_rresp;
wire [3:0] axi_i_rid;
wire  axi_i_rlast;
wire  axi_d_awready;
wire  axi_d_wready;
wire  axi_d_bvalid;
wire [1:0] axi_d_bresp;
wire [3:0] axi_d_bid;
wire  axi_d_arready;
wire  axi_d_rvalid;
wire [31:0] axi_d_rdata;
wire [1:0] axi_d_rresp;
wire [3:0] axi_d_rid;
wire  axi_d_rlast;
wire  axi_i_awvalid;
wire [31:0] axi_i_awaddr;
wire [3:0] axi_i_awid;
wire [7:0] axi_i_awlen;
wire [1:0] axi_i_awburst;
wire  axi_i_wvalid;
wire [31:0] axi_i_wdata;
wire [3:0] axi_i_wstrb;
wire  axi_i_wlast;
wire  axi_i_bready;
wire  axi_i_arvalid;
wire [31:0] axi_i_araddr;
wire [3:0] axi_i_arid;
wire [7:0] axi_i_arlen;
wire [1:0] axi_i_arburst;
wire  axi_i_rready;
wire  axi_d_awvalid;
wire [31:0] axi_d_awaddr;
wire [3:0] axi_d_awid;
wire [7:0] axi_d_awlen;
wire [1:0] axi_d_awburst;
wire  axi_d_wvalid;
wire [31:0] axi_d_wdata;
wire [3:0] axi_d_wstrb;
wire  axi_d_wlast;
wire  axi_d_bready;
wire  axi_d_arvalid;
wire [31:0] axi_d_araddr;
wire [3:0] axi_d_arid;
wire [7:0] axi_d_arlen;
wire [1:0] axi_d_arburst;
wire  axi_d_rready;

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
 final_ddr_boot u_boot(.clk(cpu_clk),.rst(rst),.memory_ready(memory_ready),
  .handoff_request(boot_request),.bus_quiet(bus_quiet),.handoff_bytes(boot_bytes),
  .main_booted(boot_main),.copied_bytes(boot_copied_bytes),
  .req_valid(boot_req_valid),.req_ready(boot_req_ready),.req_write(boot_req_write),
  .req_addr(boot_req_addr),.req_data(boot_req_data),.req_strb(boot_req_strb),
  .rsp_valid(boot_rsp_valid),.rsp_ready(boot_rsp_ready),.rsp_data(mem_rsp_data),.rsp_error(mem_rsp_error),
  .done(boot_done),.fault(boot_fault));
 wire [31:0] lin_addr,lin_wdata,lin_rdata;wire [3:0] lin_wstrb;wire lin_we,lin_write_ok;
 wire lin_input_selected,lin_output_selected,lin_stream_ready,lin_result_valid;wire [255:0] lin_result_data;
 wire [31:0] dma_addr,dma_wdata,dma_rdata;
 wire [3:0] dma_wstrb;
 wire dma_we,dma_write_ok;
 wire [31:0] sd_addr,sd_wdata,sd_rdata;wire [3:0] sd_wstrb;
 wire sd_we,sd_write_ok,sd_result_valid,sd_result_ready,dma_storage_selected,dma_verification_selected;
 wire [255:0] sd_result_data;
 wire sd_verify_ready,dma_verify_valid;wire [255:0] dma_verify_data;wire [31:0] dma_verify_keep;
 wire [27:0] c_awaddr,c_araddr,d_awaddr,d_araddr;
 wire c_awvalid,c_awready,c_arvalid,c_arready,c_wready,c_rvalid;
 wire d_awvalid,d_awready,d_arvalid,d_arready,d_wready,d_rvalid;
 wire [255:0] c_wdata,c_rdata,d_wdata,d_rdata;
 wire [31:0] c_wstrb,d_wstrb;
 wire [3:0] d_len,h_awlen,h_arlen;
 wire h_rlast,h_wlast;
 wire [31:0] dma_cpu_grants,dma_native_grants,dma_cpu_wait_max;
 wire [1:0] dma_diagnostic_control;
 wire dma_result_valid,dma_result_ready,dma_stream_ready;
 wire [255:0] dma_result_data;
 wire [27:0] h_awaddr,h_araddr;
 wire h_awvalid,h_awready,h_arvalid,h_arready,h_wready,h_rvalid;
 wire [255:0] h_wdata,h_rdata;
 wire [31:0] h_wstrb;
 always @(posedge ddr_clk or posedge rst)
 if(rst) ddr_release<=0;else ddr_release<={ddr_release[0],ddr_init_done};
 final_ddr_bridge u_mem_bridge(.clk(cpu_clk),.rst(rst),.ddr_clk(ddr_clk),.ddr_rst(!ddr_release[1]),.init_done(ddr_init_done),
  .req_valid(boot_done?bus_req_valid:boot_req_valid),.req_ready(mem_req_ready),
  .req_write(boot_done?bus_req_write:boot_req_write),
  .req_addr(boot_done?bus_req_addr:boot_req_addr),.req_data(boot_done?bus_req_data:boot_req_data),
  .req_strb(boot_done?bus_req_strb:boot_req_strb),
  .rsp_valid(mem_rsp_valid),.rsp_ready(mem_rsp_ready),.rsp_data(mem_rsp_data),.rsp_error(mem_rsp_error),.ready(memory_ready),
  .h_awaddr(c_awaddr),.h_awvalid(c_awvalid),.h_awready(c_awready),
  .h_wdata(c_wdata),.h_wstrb(c_wstrb),.h_wready(c_wready),
  .h_araddr(c_araddr),.h_arvalid(c_arvalid),.h_arready(c_arready),.h_rdata(c_rdata),.h_rvalid(c_rvalid));
 final_dma u_dma(.clk(cpu_clk),.rst(rst),.ui_clk(ddr_clk),.ui_rst(!ddr_release[1]),
  .addr(dma_addr),.wdata(dma_wdata),.wstrb(dma_wstrb),.we(dma_we),.write_ok(dma_write_ok),.rdata(dma_rdata),
  .awaddr(d_awaddr),.araddr(d_araddr),.burst_len(d_len),.awvalid(d_awvalid),.arvalid(d_arvalid),
  .awready(d_awready),.arready(d_arready),.wready(d_wready),.rvalid(d_rvalid),
  .wrdata(d_wdata),.wrstrb(d_wstrb),.rddata(d_rdata),.arb_fault(dma_arb_fault),
  .cpu_grants(dma_cpu_grants),.dma_grants(dma_native_grants),.cpu_wait_max(dma_cpu_wait_max),
  .stream_valid(dma_verify_valid),.stream_ready(lin_input_selected?lin_stream_ready:(dma_verification_selected?sd_verify_ready:dma_stream_ready)),
  .stream_data(dma_verify_data),.stream_keep(dma_verify_keep),
  .result_valid(lin_output_selected?lin_result_valid:(dma_storage_selected?sd_result_valid:dma_result_valid)),.result_ready(dma_result_ready),
  .result_data(lin_output_selected?lin_result_data:(dma_storage_selected?sd_result_data:dma_result_data)),
  .diagnostic_control(dma_diagnostic_control),.storage_selected(dma_storage_selected),.verification_selected(dma_verification_selected),
  .linear_input_selected(lin_input_selected),.linear_output_selected(lin_output_selected));
 final_dma_test_source u_dma_test_source(.clk(ddr_clk),.rst(!ddr_release[1]),
  .enable(dma_diagnostic_control),.result_ready(dma_result_ready && !dma_storage_selected && !lin_output_selected),.result_valid(dma_result_valid),.result_data(dma_result_data),
  .stream_ready(dma_stream_ready));
 // LLM engines removed. CNN MMIO/DDR master will occupy this dedicated interface.
 assign lin_stream_ready=0;assign lin_result_valid=0;assign lin_result_data=0;
 wire [3:0] master_awready,master_arready,master_wready,master_rvalid;
 wire [1023:0] master_rdata;
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
 .d_araddr(n_araddr),.d_awaddr(n_awaddr),.d_len(n_len),.d_arvalid(n_arvalid),.d_awvalid(n_awvalid),
 .d_arready(master_arready[3]),.d_awready(master_awready[3]),.d_rvalid(master_rvalid[3]),.d_wready(master_wready[3]),
 .d_rdata(master_rdata[1023:768]),.d_wdata(n_wdata),.d_wstrb(n_wstrb));
 assign sd_result_ready=dma_result_ready && dma_storage_selected;
 final_sd u_sd(.clk(cpu_clk),.rst(rst),.ui_clk(ddr_clk),.ui_rst(!ddr_release[1]),
  .addr(sd_addr),.wdata(sd_wdata),.wstrb(sd_wstrb),.we(sd_we),.write_ok(sd_write_ok),.rdata(sd_rdata),
  .sd_clk(sd_clk),.sd_cmd(sd_cmd),.sd_cs_n(sd_cs_n),.sd_d0(sd_d0),.sd_detect_n(sd_detect_n),
  .stream_valid(sd_result_valid),.stream_ready(sd_result_ready),.stream_data(sd_result_data),
  .verify_valid(dma_verify_valid && dma_verification_selected),.verify_ready(sd_verify_ready),
  .verify_data(dma_verify_data),.verify_keep(dma_verify_keep));

 assign c_awready=master_awready[0];assign d_awready=master_awready[1];
 assign c_arready=master_arready[0];assign d_arready=master_arready[1];assign v_arready=master_arready[2];
 assign c_wready=master_wready[0];assign d_wready=master_wready[1];
 assign c_rvalid=master_rvalid[0];assign d_rvalid=master_rvalid[1];assign v_rvalid=master_rvalid[2];
 assign c_rdata=master_rdata[255:0];assign d_rdata=master_rdata[511:256];assign v_rdata=master_rdata[767:512];
 yolo_ddr_arbiter u_ddr_arbiter(.clk(ddr_clk),.rst(!ddr_release[1]),
 .m_awaddr({n_awaddr,28'b0,d_awaddr,c_awaddr}),.m_araddr({n_araddr,v_araddr,d_araddr,c_araddr}),
 .m_len({n_len,v_len,d_len,4'b0}),.m_awvalid({n_awvalid,1'b0,d_awvalid,c_awvalid}),.m_arvalid({n_arvalid,v_arvalid,d_arvalid,c_arvalid}),
 .m_awready(master_awready),.m_arready(master_arready),.m_wready(master_wready),.m_rvalid(master_rvalid),
 .m_wdata({n_wdata,256'b0,d_wdata,c_wdata}),.m_wstrb({n_wstrb,32'b0,d_wstrb,c_wstrb}),.m_rdata(master_rdata),
 .fault(dma_arb_fault),.cpu_grants(dma_cpu_grants),.dma_grants(dma_native_grants),.cpu_wait_max(dma_cpu_wait_max),
 .h_awaddr(h_awaddr),.h_araddr(h_araddr),.h_awlen(h_awlen),.h_arlen(h_arlen),
 .h_awvalid(h_awvalid),.h_arvalid(h_arvalid),.h_awready(h_awready),.h_arready(h_arready),
 .h_wready(h_wready),.h_rvalid(h_rvalid),.h_rlast(h_rlast),.h_wlast(h_wlast),
 .h_wdata(h_wdata),.h_wstrb(h_wstrb),.h_rdata(h_rdata));
 // 4Gbit x16 devices: 15 row + 10 column + 3 bank bits; 32-bit combined bus.
 assign ddr3_addr[15]=1'b0;
 ddr3_test u_ddr(.ref_clk(clk),.resetn(!ref_rst),.ddr_init_done(ddr_init_done),
  .ddrphy_clkin(ddr_clk),.pll_lock(ddr_pll_lock),
  .axi_awaddr(h_awaddr),.axi_awuser_ap(1'b0),.axi_awuser_id(4'b0),.axi_awlen(h_awlen),
  .axi_awready(h_awready),.axi_awvalid(h_awvalid),.axi_wdata(h_wdata),.axi_wstrb(h_wstrb),.axi_wready(h_wready),
  .axi_araddr(h_araddr),.axi_aruser_ap(1'b0),.axi_aruser_id(4'b0),.axi_arlen(h_arlen),
  .axi_arready(h_arready),.axi_arvalid(h_arvalid),.axi_rdata(h_rdata),.axi_rvalid(h_rvalid),.axi_rlast(h_rlast),.axi_wusero_last(h_wlast),
  .apb_clk(clk),.apb_rst_n(!ref_rst),.apb_sel(1'b0),.apb_enable(1'b0),.apb_addr(8'b0),.apb_write(1'b0),.apb_wdata(16'b0),
  .force_ck_dly_en(1'b0),.force_ck_dly_set_bin(8'b0),.init_read_clk_ctrl(2'b0),.init_slip_step(4'b0),
  .force_read_clk_ctrl(1'b0),.ddrphy_gate_update_en(1'b0),.rd_fake_stop(1'b0),
  .mem_rst_n(ddr3_reset_n),.mem_ck(ddr3_ck_p),.mem_ck_n(ddr3_ck_n),.mem_cke(ddr3_cke),
  .mem_cs_n(ddr3_cs_n),.mem_ras_n(ddr3_ras_n),.mem_cas_n(ddr3_cas_n),.mem_we_n(ddr3_we_n),.mem_odt(ddr3_odt),
  .mem_a(ddr3_addr[14:0]),.mem_ba(ddr3_ba),.mem_dqs(ddr3_dqs_p),.mem_dqs_n(ddr3_dqs_n),.mem_dq(ddr3_dq),.mem_dm(ddr3_dm));
 riscv_top #(.SUPPORT_LOAD_BYPASS(0),.PREDICT_ENABLE(PREDICT_ENABLE),.MEM_CACHE_ADDR_MIN(0),
 .MEM_CACHE_ADDR_MAX(32'h01ffffff)) u_cpu(
 .clk_i(cpu_clk),.rst_i(cpu_rst),.intr_i(ext_irq),.timer_intr_i(timer_irq),
 .soft_intr_i(soft_irq),.reset_vector_i(boot_main?32'b0:32'h03c00000)
 ,.axi_i_awready_i(axi_i_awready)
,.axi_i_wready_i(axi_i_wready)
,.axi_i_bvalid_i(axi_i_bvalid)
,.axi_i_bresp_i(axi_i_bresp)
,.axi_i_bid_i(axi_i_bid)
,.axi_i_arready_i(axi_i_arready)
,.axi_i_rvalid_i(axi_i_rvalid)
,.axi_i_rdata_i(axi_i_rdata)
,.axi_i_rresp_i(axi_i_rresp)
,.axi_i_rid_i(axi_i_rid)
,.axi_i_rlast_i(axi_i_rlast)
,.axi_d_awready_i(axi_d_awready)
,.axi_d_wready_i(axi_d_wready)
,.axi_d_bvalid_i(axi_d_bvalid)
,.axi_d_bresp_i(axi_d_bresp)
,.axi_d_bid_i(axi_d_bid)
,.axi_d_arready_i(axi_d_arready)
,.axi_d_rvalid_i(axi_d_rvalid)
,.axi_d_rdata_i(axi_d_rdata)
,.axi_d_rresp_i(axi_d_rresp)
,.axi_d_rid_i(axi_d_rid)
,.axi_d_rlast_i(axi_d_rlast)
,.axi_i_awvalid_o(axi_i_awvalid)
,.axi_i_awaddr_o(axi_i_awaddr)
,.axi_i_awid_o(axi_i_awid)
,.axi_i_awlen_o(axi_i_awlen)
,.axi_i_awburst_o(axi_i_awburst)
,.axi_i_wvalid_o(axi_i_wvalid)
,.axi_i_wdata_o(axi_i_wdata)
,.axi_i_wstrb_o(axi_i_wstrb)
,.axi_i_wlast_o(axi_i_wlast)
,.axi_i_bready_o(axi_i_bready)
,.axi_i_arvalid_o(axi_i_arvalid)
,.axi_i_araddr_o(axi_i_araddr)
,.axi_i_arid_o(axi_i_arid)
,.axi_i_arlen_o(axi_i_arlen)
,.axi_i_arburst_o(axi_i_arburst)
,.axi_i_rready_o(axi_i_rready)
,.axi_d_awvalid_o(axi_d_awvalid)
,.axi_d_awaddr_o(axi_d_awaddr)
,.axi_d_awid_o(axi_d_awid)
,.axi_d_awlen_o(axi_d_awlen)
,.axi_d_awburst_o(axi_d_awburst)
,.axi_d_wvalid_o(axi_d_wvalid)
,.axi_d_wdata_o(axi_d_wdata)
,.axi_d_wstrb_o(axi_d_wstrb)
,.axi_d_wlast_o(axi_d_wlast)
,.axi_d_bready_o(axi_d_bready)
,.axi_d_arvalid_o(axi_d_arvalid)
,.axi_d_araddr_o(axi_d_araddr)
,.axi_d_arid_o(axi_d_arid)
,.axi_d_arlen_o(axi_d_arlen)
,.axi_d_arburst_o(axi_d_arburst)
,.axi_d_rready_o(axi_d_rready));
 final_bus #(.MEM_DELAY(MEM_DELAY),.CLK_HZ(CLK_HZ),.BAUD(BAUD),.INIT_FILE(INIT_FILE)) u_bus(
 .bus_quiet(bus_quiet),.boot_request(boot_request),.boot_bytes(boot_bytes),
 .boot_main(boot_main),.boot_fault(boot_fault),.boot_copied_bytes(boot_copied_bytes),
 .lin_addr(lin_addr),.lin_wdata(lin_wdata),.lin_wstrb(lin_wstrb),.lin_we(lin_we),
 .lin_write_ok(lin_write_ok),.lin_rdata(lin_rdata),
 .dma_addr(dma_addr),.dma_wdata(dma_wdata),.dma_wstrb(dma_wstrb),
 .dma_we(dma_we),.dma_write_ok(dma_write_ok),.dma_rdata(dma_rdata),
 .sd_addr(sd_addr),.sd_wdata(sd_wdata),.sd_wstrb(sd_wstrb),.sd_we(sd_we),
 .sd_write_ok(sd_write_ok),.sd_rdata(sd_rdata),
 .terminal_addr(terminal_addr),.terminal_wdata(terminal_wdata),.terminal_wstrb(terminal_wstrb),
 .terminal_we(terminal_we),.terminal_write_ok(terminal_write_ok),.terminal_rdata(terminal_rdata),
 .hdmi_status(hdmi_status),.hdmi_measurement(hdmi_measurement),.hdmi_control(hdmi_control),
 .mem_req_valid(bus_req_valid),.mem_req_ready(bus_req_ready),.mem_req_write(bus_req_write),
 .mem_req_addr(bus_req_addr),.mem_req_data(bus_req_data),.mem_req_strb(bus_req_strb),
 .mem_rsp_valid(bus_rsp_valid),.mem_rsp_ready(bus_rsp_ready),.mem_rsp_data(mem_rsp_data),.mem_rsp_error(mem_rsp_error),
 .clk(cpu_clk),.rst(cpu_rst),.gpio_input(gpio_input),.gpio_out(gpio_out),.gpio_dir(gpio_dir),
 .uart_rx(uart_rx),.uart_tx(uart_tx),.ext_irq(ext_irq),.timer_irq(timer_irq),.soft_irq(soft_irq),
 .axi_i_awready(axi_i_awready),
.axi_i_wready(axi_i_wready),
.axi_i_bvalid(axi_i_bvalid),
.axi_i_bresp(axi_i_bresp),
.axi_i_bid(axi_i_bid),
.axi_i_arready(axi_i_arready),
.axi_i_rvalid(axi_i_rvalid),
.axi_i_rdata(axi_i_rdata),
.axi_i_rresp(axi_i_rresp),
.axi_i_rid(axi_i_rid),
.axi_i_rlast(axi_i_rlast),
.axi_d_awready(axi_d_awready),
.axi_d_wready(axi_d_wready),
.axi_d_bvalid(axi_d_bvalid),
.axi_d_bresp(axi_d_bresp),
.axi_d_bid(axi_d_bid),
.axi_d_arready(axi_d_arready),
.axi_d_rvalid(axi_d_rvalid),
.axi_d_rdata(axi_d_rdata),
.axi_d_rresp(axi_d_rresp),
.axi_d_rid(axi_d_rid),
.axi_d_rlast(axi_d_rlast),
.axi_i_awvalid(axi_i_awvalid),
.axi_i_awaddr(axi_i_awaddr),
.axi_i_awid(axi_i_awid),
.axi_i_awlen(axi_i_awlen),
.axi_i_awburst(axi_i_awburst),
.axi_i_wvalid(axi_i_wvalid),
.axi_i_wdata(axi_i_wdata),
.axi_i_wstrb(axi_i_wstrb),
.axi_i_wlast(axi_i_wlast),
.axi_i_bready(axi_i_bready),
.axi_i_arvalid(axi_i_arvalid),
.axi_i_araddr(axi_i_araddr),
.axi_i_arid(axi_i_arid),
.axi_i_arlen(axi_i_arlen),
.axi_i_arburst(axi_i_arburst),
.axi_i_rready(axi_i_rready),
.axi_d_awvalid(axi_d_awvalid),
.axi_d_awaddr(axi_d_awaddr),
.axi_d_awid(axi_d_awid),
.axi_d_awlen(axi_d_awlen),
.axi_d_awburst(axi_d_awburst),
.axi_d_wvalid(axi_d_wvalid),
.axi_d_wdata(axi_d_wdata),
.axi_d_wstrb(axi_d_wstrb),
.axi_d_wlast(axi_d_wlast),
.axi_d_bready(axi_d_bready),
.axi_d_arvalid(axi_d_arvalid),
.axi_d_araddr(axi_d_araddr),
.axi_d_arid(axi_d_arid),
.axi_d_arlen(axi_d_arlen),
.axi_d_arburst(axi_d_arburst),
.axi_d_rready(axi_d_rready));
endmodule
