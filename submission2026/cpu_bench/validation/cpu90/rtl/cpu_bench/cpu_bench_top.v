// MES50HP PGL50H-6IFBG484, 50 MHz. All board pins from hardware manual.
module cpu_bench_top #(parameter PREDICT_ENABLE=1, MEM_DELAY=0,
 parameter CLK_HZ=90000000, BAUD=115200, INIT_FILE="firmware/cpu_only/coremark.hex")(
 input clk, rstn, input [1:0] keys_n, input uart_rx,
 output uart_tx, output [7:0] led, inout [1:0] gpio);
 wire pll_clk,pll_lock,cpu_clk;
 cpu_bench_pll u_cpu_pll(.clkin1(clk),.clkout0(pll_clk),.clkout1(),.pll_lock(pll_lock));
 GTP_CLKBUFG u_cpu_clock(.CLKIN(pll_clk),.CLKOUT(cpu_clk));
 wire arst=!rstn || !pll_lock;
 reg [1:0] reset_release=0;
 always @(posedge cpu_clk or posedge arst)
 if(arst) reset_release<=0; else reset_release<={reset_release[0],1'b1};
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
 assign led=gpio_out[15:8];
 wire ext_irq,timer_irq,soft_irq;
wire [223:0] core_debug;wire diag_reset,diag_delay;wire cpu_arst=rst||diag_reset;reg [1:0] cpu_release=0;
 always @(posedge cpu_clk or posedge cpu_arst)if(cpu_arst)cpu_release<=0;else cpu_release<={cpu_release[0],1'b1};
 wire run_rst=!cpu_release[1];
wire [31:0] diag_rdata,diag_addr,diag_waddr,diag_wdata;wire diag_wr;
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
 riscv_top #(.PREDICT_ENABLE(PREDICT_ENABLE),.MEM_CACHE_ADDR_MIN(0),
 .MEM_CACHE_ADDR_MAX(32'h0000ffff)) u_cpu(
 .debug_o(core_debug),.clk_i(cpu_clk),.rst_i(run_rst),.intr_i(ext_irq),.timer_intr_i(timer_irq),
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
 cpu_bench_bus #(.MEM_DELAY(MEM_DELAY),.CLK_HZ(CLK_HZ),.BAUD(BAUD),.INIT_FILE(INIT_FILE)) u_bus(
 .clk(cpu_clk),.rst(run_rst),.diag_rdata_i(diag_rdata),.diag_delay_i(diag_delay),.diag_addr_o(diag_addr),.diag_waddr_o(diag_waddr),.diag_wdata_o(diag_wdata),.diag_wr_o(diag_wr),.gpio_input(gpio_input),.gpio_out(gpio_out),.gpio_dir(gpio_dir),
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
cpu_validation_diag u_diag(.clk(cpu_clk),.rst(rst),.core_debug(core_debug),.read_addr(diag_addr),.write_addr(diag_waddr),.write_data(diag_wdata),.write_en(diag_wr),.read_data(diag_rdata),.warm_reset(diag_reset),.delay_mode(diag_delay),
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
