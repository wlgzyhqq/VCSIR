// MES50HP PGL50H-6IFBG484, 50 MHz. All board pins from hardware manual.
module final_top #(parameter PREDICT_ENABLE=1, MEM_DELAY=0,
 parameter CLK_HZ=50000000, BAUD=115200, INIT_FILE="C:/Users/33791/Desktop/project/learn verilog/FINAL/firmware/demo.hex")(
 input clk, rstn, input [1:0] keys_n, input uart_rx,
 output uart_tx, output [7:0] led, inout [1:0] gpio,
 output [15:0] ddr3_addr,output [2:0] ddr3_ba,
 output ddr3_cas_n,ddr3_ck_n,ddr3_ck_p,ddr3_cke,ddr3_cs_n,
 output ddr3_odt,ddr3_ras_n,ddr3_reset_n,ddr3_we_n,
 output [3:0] ddr3_dm,inout [31:0] ddr3_dq,
 inout [3:0] ddr3_dqs_p,ddr3_dqs_n);
wire cpu_clk;
 GTP_CLKBUFG u_cpu_clock(.CLKIN(clk),.CLKOUT(cpu_clk));
 reg [1:0] reset_release=0;
 always @(posedge cpu_clk or negedge rstn)
 if(!rstn) reset_release<=0; else reset_release<={reset_release[0],1'b1};
 wire rst=!reset_release[1];
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
 assign led=boot_fault?8'he0:(!boot_done?(memory_ready?8'h40:8'h80):gpio_out[15:8]);
 reg [1:0] cpu_release;
 always @(posedge cpu_clk or posedge rst)
 if(rst) cpu_release<=0;else cpu_release<={cpu_release[0],boot_done && !boot_fault && memory_ready};
 wire cpu_rst=!cpu_release[1];
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
 final_ddr_bridge u_mem_bridge(.clk(cpu_clk),.rst(rst),.ddr_clk(ddr_clk),.ddr_rst(!ddr_release[1]),.init_done(ddr_init_done),
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
 riscv_top #(.PREDICT_ENABLE(PREDICT_ENABLE),.MEM_CACHE_ADDR_MIN(0),
 .MEM_CACHE_ADDR_MAX(32'h3fffffff)) u_cpu(
 .clk_i(cpu_clk),.rst_i(cpu_rst),.intr_i(ext_irq),.timer_intr_i(timer_irq),
 .soft_intr_i(soft_irq),.reset_vector_i(0)
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
