`timescale 1ns/1ps
module tb_yolo_bus;
 wire  bus_quiet;
 wire  boot_request;
 wire [31:0] boot_bytes;
 reg  boot_main;
 reg  boot_fault;
 reg [31:0] boot_copied_bytes;
 wire [31:0] lin_addr;
 wire [31:0] lin_wdata;
 wire [3:0] lin_wstrb;
 wire  lin_we;
 reg  lin_write_ok;
 wire [31:0] lin_rdata;
 wire [31:0] dma_addr;
 wire [31:0] dma_wdata;
 wire [3:0] dma_wstrb;
 wire  dma_we;
 reg  dma_write_ok;
 wire [31:0] dma_rdata;
 wire [31:0] sd_addr;
 wire [31:0] sd_wdata;
 wire [3:0] sd_wstrb;
 wire  sd_we;
 reg  sd_write_ok;
 wire [31:0] sd_rdata;
 wire [31:0] terminal_addr;
 wire [31:0] terminal_wdata;
 wire [3:0] terminal_wstrb;
 wire  terminal_we;
 reg  terminal_write_ok;
 wire [31:0] terminal_rdata;
 wire  mem_req_valid;
 reg  mem_req_ready;
 wire  mem_req_write;
 wire [29:0] mem_req_addr;
 wire [255:0] mem_req_data;
 wire [31:0] mem_req_strb;
 reg  mem_rsp_valid;
 wire  mem_rsp_ready;
 reg [255:0] mem_rsp_data;
 reg  mem_rsp_error;
 reg [31:0] hdmi_status;
 reg [63:0] hdmi_measurement;
 wire [31:0] hdmi_control;
 reg  clk;
 reg  rst;
 reg [31:0] gpio_input;
 wire [31:0] gpio_out;
 wire [31:0] gpio_dir;
 reg  uart_rx;
 wire  uart_tx;
 wire  ext_irq;
 wire  timer_irq;
 wire  soft_irq;
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
 reg  axi_i_awvalid;
 reg [31:0] axi_i_awaddr;
 reg [3:0] axi_i_awid;
 reg [7:0] axi_i_awlen;
 reg [1:0] axi_i_awburst;
 reg  axi_i_wvalid;
 reg [31:0] axi_i_wdata;
 reg [3:0] axi_i_wstrb;
 reg  axi_i_wlast;
 reg  axi_i_bready;
 reg  axi_i_arvalid;
 reg [31:0] axi_i_araddr;
 reg [3:0] axi_i_arid;
 reg [7:0] axi_i_arlen;
 reg [1:0] axi_i_arburst;
 reg  axi_i_rready;
 reg  axi_d_awvalid;
 reg [31:0] axi_d_awaddr;
 reg [3:0] axi_d_awid;
 reg [7:0] axi_d_awlen;
 reg [1:0] axi_d_awburst;
 reg  axi_d_wvalid;
 reg [31:0] axi_d_wdata;
 reg [3:0] axi_d_wstrb;
 reg  axi_d_wlast;
 reg  axi_d_bready;
 reg  axi_d_arvalid;
 reg [31:0] axi_d_araddr;
 reg [3:0] axi_d_arid;
 reg [7:0] axi_d_arlen;
 reg [1:0] axi_d_arburst;
 reg  axi_d_rready;
 final_bus #(.CLK_HZ(90000000),.BAUD(9000000)) dut(.bus_quiet(bus_quiet),.boot_request(boot_request),.boot_bytes(boot_bytes),.boot_main(boot_main),.boot_fault(boot_fault),.boot_copied_bytes(boot_copied_bytes),.lin_addr(lin_addr),.lin_wdata(lin_wdata),.lin_wstrb(lin_wstrb),.lin_we(lin_we),.lin_write_ok(lin_write_ok),.lin_rdata(lin_rdata),.dma_addr(dma_addr),.dma_wdata(dma_wdata),.dma_wstrb(dma_wstrb),.dma_we(dma_we),.dma_write_ok(dma_write_ok),.dma_rdata(dma_rdata),.sd_addr(sd_addr),.sd_wdata(sd_wdata),.sd_wstrb(sd_wstrb),.sd_we(sd_we),.sd_write_ok(sd_write_ok),.sd_rdata(sd_rdata),.terminal_addr(terminal_addr),.terminal_wdata(terminal_wdata),.terminal_wstrb(terminal_wstrb),.terminal_we(terminal_we),.terminal_write_ok(terminal_write_ok),.terminal_rdata(terminal_rdata),.mem_req_valid(mem_req_valid),.mem_req_ready(mem_req_ready),.mem_req_write(mem_req_write),.mem_req_addr(mem_req_addr),.mem_req_data(mem_req_data),.mem_req_strb(mem_req_strb),.mem_rsp_valid(mem_rsp_valid),.mem_rsp_ready(mem_rsp_ready),.mem_rsp_data(mem_rsp_data),.mem_rsp_error(mem_rsp_error),.hdmi_status(hdmi_status),.hdmi_measurement(hdmi_measurement),.hdmi_control(hdmi_control),.clk(clk),.rst(rst),.gpio_input(gpio_input),.gpio_out(gpio_out),.gpio_dir(gpio_dir),.uart_rx(uart_rx),.uart_tx(uart_tx),.ext_irq(ext_irq),.timer_irq(timer_irq),.soft_irq(soft_irq),.axi_i_awready(axi_i_awready),.axi_i_wready(axi_i_wready),.axi_i_bvalid(axi_i_bvalid),.axi_i_bresp(axi_i_bresp),.axi_i_bid(axi_i_bid),.axi_i_arready(axi_i_arready),.axi_i_rvalid(axi_i_rvalid),.axi_i_rdata(axi_i_rdata),.axi_i_rresp(axi_i_rresp),.axi_i_rid(axi_i_rid),.axi_i_rlast(axi_i_rlast),.axi_d_awready(axi_d_awready),.axi_d_wready(axi_d_wready),.axi_d_bvalid(axi_d_bvalid),.axi_d_bresp(axi_d_bresp),.axi_d_bid(axi_d_bid),.axi_d_arready(axi_d_arready),.axi_d_rvalid(axi_d_rvalid),.axi_d_rdata(axi_d_rdata),.axi_d_rresp(axi_d_rresp),.axi_d_rid(axi_d_rid),.axi_d_rlast(axi_d_rlast),.axi_i_awvalid(axi_i_awvalid),.axi_i_awaddr(axi_i_awaddr),.axi_i_awid(axi_i_awid),.axi_i_awlen(axi_i_awlen),.axi_i_awburst(axi_i_awburst),.axi_i_wvalid(axi_i_wvalid),.axi_i_wdata(axi_i_wdata),.axi_i_wstrb(axi_i_wstrb),.axi_i_wlast(axi_i_wlast),.axi_i_bready(axi_i_bready),.axi_i_arvalid(axi_i_arvalid),.axi_i_araddr(axi_i_araddr),.axi_i_arid(axi_i_arid),.axi_i_arlen(axi_i_arlen),.axi_i_arburst(axi_i_arburst),.axi_i_rready(axi_i_rready),.axi_d_awvalid(axi_d_awvalid),.axi_d_awaddr(axi_d_awaddr),.axi_d_awid(axi_d_awid),.axi_d_awlen(axi_d_awlen),.axi_d_awburst(axi_d_awburst),.axi_d_wvalid(axi_d_wvalid),.axi_d_wdata(axi_d_wdata),.axi_d_wstrb(axi_d_wstrb),.axi_d_wlast(axi_d_wlast),.axi_d_bready(axi_d_bready),.axi_d_arvalid(axi_d_arvalid),.axi_d_araddr(axi_d_araddr),.axi_d_arid(axi_d_arid),.axi_d_arlen(axi_d_arlen),.axi_d_arburst(axi_d_arburst),.axi_d_rready(axi_d_rready));

 reg clkgen=0;always #5.555 clkgen=~clkgen;
 always @* clk=clkgen;
 assign sd_rdata=sd_addr^32'h55aa1234;
 assign dma_rdata=dma_addr^32'h99aa1234;
 assign lin_rdata=lin_addr^32'h77aa1234;
 reg [31:0] text_q;always @(posedge clk)text_q<=terminal_addr^32'h44332211;
 assign terminal_rdata=text_q;
 reg [255:0] memory_line=0;
 always @(posedge clk)begin
  if(rst)mem_rsp_valid<=0;
  else begin
   if(mem_rsp_valid&&mem_rsp_ready)mem_rsp_valid<=0;
   if(mem_req_valid&&mem_req_ready)begin
    mem_rsp_valid<=1;
    if(mem_req_write)begin memory_line<=mem_req_data;if(mem_req_strb!==32'hffffffff)$fatal(1,"bad write mask");end
    else mem_rsp_data<=memory_line;
   end
  end
 end
 integer swrites=0;
 always @(posedge clk)if(sd_we)begin
  if(sd_addr!==32'h80006004||sd_wdata!==32'habcdef12||sd_wstrb!==15)$fatal(1,"bad shared write address/data");swrites=swrites+1;
 end
 task read_word(input [31:0] address,input [31:0] expected,input [1:0] response);begin
  @(negedge clk);axi_d_araddr=address;axi_d_arvalid=1;
  do @(posedge clk);while(!axi_d_arready);
  @(negedge clk);axi_d_arvalid=0;
  do @(negedge clk);while(!axi_d_rvalid);
  repeat(4)begin
   if(axi_d_rdata!==expected||axi_d_rresp!==response||!axi_d_rlast||axi_d_rid!=5)$fatal(1,"read %h got%h expected%h resp%h",address,axi_d_rdata,expected,axi_d_rresp);
   @(negedge clk);
  end
  axi_d_rready=1;@(negedge clk);axi_d_rready=0;
 end endtask
 task write_words(input [31:0] address,input integer count);begin
  @(negedge clk);axi_d_awaddr=address;axi_d_awlen=count-1;axi_d_awvalid=1;
  do @(posedge clk);while(!axi_d_awready);
  @(negedge clk);axi_d_awvalid=0;
  for(integer i=0;i<count;i=i+1)begin
   axi_d_wdata=count==1?32'habcdef12:32'h12480000+i;axi_d_wvalid=1;axi_d_wlast=i==count-1;
   do @(posedge clk);while(!axi_d_wready);
   @(negedge clk);
  end
  axi_d_wvalid=0;
  do @(negedge clk);while(!axi_d_bvalid);
  if(axi_d_bresp!==0||axi_d_bid!==7)$fatal(1,"write response");
  axi_d_bready=1;@(negedge clk);axi_d_bready=0;
 end endtask
 initial begin
 boot_main=0;
 boot_fault=0;
 boot_copied_bytes=0;
 lin_write_ok=0;
 dma_write_ok=0;
 sd_write_ok=0;
 terminal_write_ok=0;
 mem_req_ready=0;
 mem_rsp_valid=0;
 mem_rsp_data=0;
 mem_rsp_error=0;
 hdmi_status=0;
 hdmi_measurement=0;
 clk=0;
 rst=0;
 gpio_input=0;
 uart_rx=0;
 axi_i_awvalid=0;
 axi_i_awaddr=0;
 axi_i_awid=0;
 axi_i_awlen=0;
 axi_i_awburst=0;
 axi_i_wvalid=0;
 axi_i_wdata=0;
 axi_i_wstrb=0;
 axi_i_wlast=0;
 axi_i_bready=0;
 axi_i_arvalid=0;
 axi_i_araddr=0;
 axi_i_arid=0;
 axi_i_arlen=0;
 axi_i_arburst=0;
 axi_i_rready=0;
 axi_d_awvalid=0;
 axi_d_awaddr=0;
 axi_d_awid=0;
 axi_d_awlen=0;
 axi_d_awburst=0;
 axi_d_wvalid=0;
 axi_d_wdata=0;
 axi_d_wstrb=0;
 axi_d_wlast=0;
 axi_d_bready=0;
 axi_d_arvalid=0;
 axi_d_araddr=0;
 axi_d_arid=0;
 axi_d_arlen=0;
 axi_d_arburst=0;
 axi_d_rready=0;
 rst=1;uart_rx=1;boot_main=1;lin_write_ok=1;sd_write_ok=1;dma_write_ok=1;terminal_write_ok=1;
 mem_req_ready=1;hdmi_status=32'h345678;axi_d_arburst=1;axi_d_awburst=1;axi_d_arid=5;axi_d_awid=7;axi_d_wstrb=15;
 repeat(5)@(negedge clk);rst=0;
 repeat(3)begin
  read_word(32'h8000002c,90000000,0);
  read_word(32'h80003004,32'h345678,0);
  read_word(32'h80004058,32'h80004058^32'h77aa1234,0);
  read_word(32'h8000501c,32'h8000501c^32'h99aa1234,0);
  read_word(32'h80006020,32'h80006020^32'h55aa1234,0);
  read_word(32'h80010020,32'h80010020^32'h44332211,0);
  read_word(32'h80007010,32'h80007010^32'h44332211,0);
  read_word(32'h80008000,0,2);
  write_words(32'h80006004,1);
 end
 write_words(32'h02001000,8);
 for(integer i=0;i<8;i=i+1)read_word(32'h02001000+i*4,32'h12480000+i,0);
 if(swrites!=3)$fatal(1,"write duplicated/missing");
 $display("PASS CPU bus MMIO registered groups, synchronous text RAM, stable AXI backpressure, IDs/errors, shared write address and DDR line read/write");$finish;
 end
 initial begin #200000;$fatal(1,"timeout");end
endmodule
