`timescale 1ns/1ps
module tb_yolo_cpu;

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
 final_bus #(.CLK_HZ(90000000),.BAUD(9000000)) dut(.bus_quiet(bus_quiet),.boot_request(boot_request),.boot_bytes(boot_bytes),.boot_main(boot_main),.boot_fault(boot_fault),.boot_copied_bytes(boot_copied_bytes),.lin_addr(lin_addr),.lin_wdata(lin_wdata),.lin_wstrb(lin_wstrb),.lin_we(lin_we),.lin_write_ok(lin_write_ok),.lin_rdata(lin_rdata),.dma_addr(dma_addr),.dma_wdata(dma_wdata),.dma_wstrb(dma_wstrb),.dma_we(dma_we),.dma_write_ok(dma_write_ok),.dma_rdata(dma_rdata),.sd_addr(sd_addr),.sd_wdata(sd_wdata),.sd_wstrb(sd_wstrb),.sd_we(sd_we),.sd_write_ok(sd_write_ok),.sd_rdata(sd_rdata),.terminal_addr(terminal_addr),.terminal_wdata(terminal_wdata),.terminal_wstrb(terminal_wstrb),.terminal_we(terminal_we),.terminal_write_ok(terminal_write_ok),.terminal_rdata(terminal_rdata),.mem_req_valid(mem_req_valid),.mem_req_ready(mem_req_ready),.mem_req_write(mem_req_write),.mem_req_addr(mem_req_addr),.mem_req_data(mem_req_data),.mem_req_strb(mem_req_strb),.mem_rsp_valid(mem_rsp_valid),.mem_rsp_ready(mem_rsp_ready),.mem_rsp_data(mem_rsp_data),.mem_rsp_error(mem_rsp_error),.hdmi_status(hdmi_status),.hdmi_measurement(hdmi_measurement),.hdmi_control(hdmi_control),.clk(clk),.rst(rst),.gpio_input(gpio_input),.gpio_out(gpio_out),.gpio_dir(gpio_dir),.uart_rx(uart_rx),.uart_tx(uart_tx),.ext_irq(ext_irq),.timer_irq(timer_irq),.soft_irq(soft_irq),.axi_i_awready(axi_i_awready),.axi_i_wready(axi_i_wready),.axi_i_bvalid(axi_i_bvalid),.axi_i_bresp(axi_i_bresp),.axi_i_bid(axi_i_bid),.axi_i_arready(axi_i_arready),.axi_i_rvalid(axi_i_rvalid),.axi_i_rdata(axi_i_rdata),.axi_i_rresp(axi_i_rresp),.axi_i_rid(axi_i_rid),.axi_i_rlast(axi_i_rlast),.axi_d_awready(axi_d_awready),.axi_d_wready(axi_d_wready),.axi_d_bvalid(axi_d_bvalid),.axi_d_bresp(axi_d_bresp),.axi_d_bid(axi_d_bid),.axi_d_arready(axi_d_arready),.axi_d_rvalid(axi_d_rvalid),.axi_d_rdata(axi_d_rdata),.axi_d_rresp(axi_d_rresp),.axi_d_rid(axi_d_rid),.axi_d_rlast(axi_d_rlast),.axi_i_awvalid(axi_i_awvalid),.axi_i_awaddr(axi_i_awaddr),.axi_i_awid(axi_i_awid),.axi_i_awlen(axi_i_awlen),.axi_i_awburst(axi_i_awburst),.axi_i_wvalid(axi_i_wvalid),.axi_i_wdata(axi_i_wdata),.axi_i_wstrb(axi_i_wstrb),.axi_i_wlast(axi_i_wlast),.axi_i_bready(axi_i_bready),.axi_i_arvalid(axi_i_arvalid),.axi_i_araddr(axi_i_araddr),.axi_i_arid(axi_i_arid),.axi_i_arlen(axi_i_arlen),.axi_i_arburst(axi_i_arburst),.axi_i_rready(axi_i_rready),.axi_d_awvalid(axi_d_awvalid),.axi_d_awaddr(axi_d_awaddr),.axi_d_awid(axi_d_awid),.axi_d_awlen(axi_d_awlen),.axi_d_awburst(axi_d_awburst),.axi_d_wvalid(axi_d_wvalid),.axi_d_wdata(axi_d_wdata),.axi_d_wstrb(axi_d_wstrb),.axi_d_wlast(axi_d_wlast),.axi_d_bready(axi_d_bready),.axi_d_arvalid(axi_d_arvalid),.axi_d_araddr(axi_d_araddr),.axi_d_arid(axi_d_arid),.axi_d_arlen(axi_d_arlen),.axi_d_arburst(axi_d_arburst),.axi_d_rready(axi_d_rready));


 riscv_top #(.SUPPORT_LOAD_BYPASS(0),.MEM_CACHE_ADDR_MIN(0),.MEM_CACHE_ADDR_MAX(32'h01ffffff)) cpu(
 .clk_i(clk),.rst_i(rst),.intr_i(ext_irq),.timer_intr_i(timer_irq),.soft_intr_i(soft_irq),.reset_vector_i(32'h2000),.axi_i_awready_i(axi_i_awready),.axi_i_wready_i(axi_i_wready),.axi_i_bvalid_i(axi_i_bvalid),.axi_i_bresp_i(axi_i_bresp),.axi_i_bid_i(axi_i_bid),.axi_i_arready_i(axi_i_arready),.axi_i_rvalid_i(axi_i_rvalid),.axi_i_rdata_i(axi_i_rdata),.axi_i_rresp_i(axi_i_rresp),.axi_i_rid_i(axi_i_rid),.axi_i_rlast_i(axi_i_rlast),.axi_d_awready_i(axi_d_awready),.axi_d_wready_i(axi_d_wready),.axi_d_bvalid_i(axi_d_bvalid),.axi_d_bresp_i(axi_d_bresp),.axi_d_bid_i(axi_d_bid),.axi_d_arready_i(axi_d_arready),.axi_d_rvalid_i(axi_d_rvalid),.axi_d_rdata_i(axi_d_rdata),.axi_d_rresp_i(axi_d_rresp),.axi_d_rid_i(axi_d_rid),.axi_d_rlast_i(axi_d_rlast),.axi_i_awvalid_o(axi_i_awvalid),.axi_i_awaddr_o(axi_i_awaddr),.axi_i_awid_o(axi_i_awid),.axi_i_awlen_o(axi_i_awlen),.axi_i_awburst_o(axi_i_awburst),.axi_i_wvalid_o(axi_i_wvalid),.axi_i_wdata_o(axi_i_wdata),.axi_i_wstrb_o(axi_i_wstrb),.axi_i_wlast_o(axi_i_wlast),.axi_i_bready_o(axi_i_bready),.axi_i_arvalid_o(axi_i_arvalid),.axi_i_araddr_o(axi_i_araddr),.axi_i_arid_o(axi_i_arid),.axi_i_arlen_o(axi_i_arlen),.axi_i_arburst_o(axi_i_arburst),.axi_i_rready_o(axi_i_rready),.axi_d_awvalid_o(axi_d_awvalid),.axi_d_awaddr_o(axi_d_awaddr),.axi_d_awid_o(axi_d_awid),.axi_d_awlen_o(axi_d_awlen),.axi_d_awburst_o(axi_d_awburst),.axi_d_wvalid_o(axi_d_wvalid),.axi_d_wdata_o(axi_d_wdata),.axi_d_wstrb_o(axi_d_wstrb),.axi_d_wlast_o(axi_d_wlast),.axi_d_bready_o(axi_d_bready),.axi_d_arvalid_o(axi_d_arvalid),.axi_d_araddr_o(axi_d_araddr),.axi_d_arid_o(axi_d_arid),.axi_d_arlen_o(axi_d_arlen),.axi_d_arburst_o(axi_d_arburst),.axi_d_rready_o(axi_d_rready));
 reg c=0;always #5.555 c=~c;always @* clk=c;
 reg [31:0] memory[0:262143];reg [255:0] pending_data;integer delay=0,stalls=0,cycles=0;reg pending=0;
 reg [1023:0] file_name;integer misaligned_test=0;
 assign sd_rdata=0;assign dma_rdata=0;assign lin_rdata=0;assign terminal_rdata=0;
 always @(posedge clk)begin
  if(rst)begin mem_rsp_valid<=0;pending<=0;cycles<=0;end
  else begin
   cycles<=cycles+1;
   // The original board harness accepts ma_data as an EEI misalignment
   // exception, not native unaligned support. Observe the same policy here.
   if(misaligned_test&&cpu.u_core.u_csr.u_csrfile.csr_mcause_q==4)begin
    if(cpu.u_core.u_csr.u_csrfile.csr_mepc_q!=32'h2018||!cpu.u_core.u_csr.u_csrfile.csr_mtval_q[0])$fatal(1,"wrong misaligned exception");
    $display("PASS CPU expected EEI misaligned-load exception, not native unaligned support");$finish;
   end
   if(mem_rsp_valid&&mem_rsp_ready)mem_rsp_valid<=0;
   if(pending)begin
    if(delay==0)begin mem_rsp_valid<=1;mem_rsp_data<=pending_data;pending<=0;end else delay<=delay-1;
   end
   if(mem_req_valid&&mem_req_ready)begin
    if(mem_req_addr>=32'h100000)$fatal(1,"test memory out of range %h",mem_req_addr);
    for(integer i=0;i<8;i=i+1)begin
     pending_data[i*32+:32]<=memory[(mem_req_addr>>2)+i];
     for(integer j=0;j<4;j=j+1)if(mem_req_write&&mem_req_strb[i*4+j])memory[(mem_req_addr>>2)+i][j*8+:8]<=mem_req_data[i*32+j*8+:8];
    end
    pending<=1;delay<=stalls?((cycles%7)+1):0;
   end
   if(dut.completion_reg!=0)begin
    if(dut.completion_reg!=1)$fatal(1,"CPU result=%h pc=%h",dut.completion_reg,cpu.u_core.u_fetch.pc_f_q);
    $display("PASS CPU no-load-bypass result1 cycles=%0d stalls=%0d",cycles,stalls);$finish;
   end
   if(cycles>3000000)$fatal(1,"CPU timeout");
  end
 end
 always @*mem_req_ready=!pending&&!mem_rsp_valid;
 initial begin
 boot_main=0;
 boot_fault=0;
 boot_copied_bytes=0;
 lin_write_ok=0;
 dma_write_ok=0;
 sd_write_ok=0;
 terminal_write_ok=0;
 mem_rsp_error=0;
 hdmi_status=0;
 hdmi_measurement=0;
 rst=0;
 gpio_input=0;
 uart_rx=0;
 rst=1;uart_rx=1;boot_main=1;mem_rsp_error=0;
 if(!$value$plusargs("image=%s",file_name))$fatal(1,"missing image");
 if($value$plusargs("stalls=%d",stalls))begin end
 if($value$plusargs("misaligned=%d",misaligned_test))begin end
 for(integer i=0;i<262144;i=i+1)memory[i]=0;
 // Existing payloads return a0 to the monitor entry at0x100. A minimal
 // return stub publishes a0 through this SoC's actual completion register.
 memory[64]=32'h800022b7;memory[65]=32'h00a2ac23;memory[66]=32'h0000006f;
 $readmemh(file_name,memory,2048);
 repeat(10)@(negedge clk);rst=0;
 end
endmodule
