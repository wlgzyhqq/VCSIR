// FINAL dual AXI4 slave: shared 64 KiB block RAM and uncached MMIO.
module final_bus #(parameter MEM_DELAY=0, CLK_HZ=50000000, BAUD=115200,
 parameter INIT_FILE="firmware/demo.hex")(
 input clk,rst,input [31:0] gpio_input, output reg [31:0] gpio_out,gpio_dir,
 input uart_rx,output uart_tx, output ext_irq,timer_irq,soft_irq,
output reg  axi_i_awready,
output reg  axi_i_wready,
output reg  axi_i_bvalid,
output reg [1:0] axi_i_bresp,
output reg [3:0] axi_i_bid,
output reg  axi_i_arready,
output reg  axi_i_rvalid,
output reg [31:0] axi_i_rdata,
output reg [1:0] axi_i_rresp,
output reg [3:0] axi_i_rid,
output reg  axi_i_rlast,
output reg  axi_d_awready,
output reg  axi_d_wready,
output reg  axi_d_bvalid,
output reg [1:0] axi_d_bresp,
output reg [3:0] axi_d_bid,
output reg  axi_d_arready,
output reg  axi_d_rvalid,
output reg [31:0] axi_d_rdata,
output reg [1:0] axi_d_rresp,
output reg [3:0] axi_d_rid,
output reg  axi_d_rlast,
input wire  axi_i_awvalid,
input wire [31:0] axi_i_awaddr,
input wire [3:0] axi_i_awid,
input wire [7:0] axi_i_awlen,
input wire [1:0] axi_i_awburst,
input wire  axi_i_wvalid,
input wire [31:0] axi_i_wdata,
input wire [3:0] axi_i_wstrb,
input wire  axi_i_wlast,
input wire  axi_i_bready,
input wire  axi_i_arvalid,
input wire [31:0] axi_i_araddr,
input wire [3:0] axi_i_arid,
input wire [7:0] axi_i_arlen,
input wire [1:0] axi_i_arburst,
input wire  axi_i_rready,
input wire  axi_d_awvalid,
input wire [31:0] axi_d_awaddr,
input wire [3:0] axi_d_awid,
input wire [7:0] axi_d_awlen,
input wire [1:0] axi_d_awburst,
input wire  axi_d_wvalid,
input wire [31:0] axi_d_wdata,
input wire [3:0] axi_d_wstrb,
input wire  axi_d_wlast,
input wire  axi_d_bready,
input wire  axi_d_arvalid,
input wire [31:0] axi_d_araddr,
input wire [3:0] axi_d_arid,
input wire [7:0] axi_d_arlen,
input wire [1:0] axi_d_arburst,
input wire  axi_d_rready);
reg [31:0] ram[0:16383];
initial begin
 $readmemh(INIT_FILE,ram);
end
reg [31:0] i_addr,d_addr,w_addr;
reg [31:0] i_ram_q,d_ram_q;
reg i_active,d_active,w_active;
reg [7:0] i_left,d_left,w_left;
reg [3:0] i_id,d_id,w_id;
reg i_bad,d_bad,w_bad;
reg [7:0] i_delay,d_delay;
reg [15:0] random_q;
reg [63:0] mtime,mtimecmp;
reg msip,force_irq;
reg [31:0] gpio_irq_enable,gpio_pending,gpio_prev;
reg [31:0] completion_reg;
reg tx_start,rx_pop;
reg [7:0] tx_data;
wire tx_busy,rx_valid,rx_overrun;
wire [7:0] rx_data;
assign soft_irq=msip;
assign timer_irq=mtime>=mtimecmp;
assign ext_irq=force_irq || rx_valid || (|(gpio_pending & gpio_irq_enable));
final_uart #(.CLK_HZ(CLK_HZ),.BAUD(BAUD)) u_uart(
 .clk(clk),.rst(rst),.rx(uart_rx),.tx(uart_tx),.tx_start(tx_start),.tx_data(tx_data),
 .tx_busy(tx_busy),.rx_pop(rx_pop),.rx_data(rx_data),.rx_valid(rx_valid),.rx_overrun(rx_overrun));
wire [31:0] d_mmio =
 d_addr==32'h80000000 ? {24'b0,rx_data} :
 d_addr==32'h80000004 ? {29'b0,rx_overrun,rx_valid,tx_busy} :
 d_addr==32'h80001000 ? gpio_out :
 d_addr==32'h80001004 ? gpio_input :
 d_addr==32'h80001008 ? gpio_dir :
 d_addr==32'h8000100c ? gpio_irq_enable :
 d_addr==32'h80001010 ? gpio_pending :
 d_addr==32'h80002000 ? mtime[31:0] :
 d_addr==32'h80002004 ? mtime[63:32] :
 d_addr==32'h80002008 ? mtimecmp[31:0] :
 d_addr==32'h8000200c ? mtimecmp[63:32] :
 d_addr==32'h80002010 ? {31'b0,msip} :
 d_addr==32'h80002014 ? {31'b0,force_irq} :
 d_addr==32'h80002018 ? completion_reg : 0;
wire d_known=d_addr<65536 || d_addr==32'h80000000 || d_addr==32'h80000004 ||
 (d_addr>=32'h80001000 && d_addr<=32'h80001010) ||
 (d_addr>=32'h80002000 && d_addr<=32'h80002018);
wire w_known=w_addr<65536 || w_addr==32'h80000000 ||
 w_addr==32'h80001000 || w_addr==32'h80001008 || w_addr==32'h8000100c || w_addr==32'h80001010 ||
 (w_addr>=32'h80002000 && w_addr<=32'h80002018);
wire w_fire=axi_d_wvalid && axi_d_wready;
wire [13:0] d_ram_addr=w_active?w_addr[15:2]:d_addr[15:2];
// Separate synchronous read ports permit Pango true-dual-port block RAM inference.
always @(posedge clk) i_ram_q<=ram[i_addr[15:2]];
always @(posedge clk) begin
 d_ram_q<=ram[d_ram_addr];
 if(w_fire && !w_bad && w_addr<65536) begin
   if(axi_d_wstrb[0]) ram[d_ram_addr][7:0]<=axi_d_wdata[7:0];
   if(axi_d_wstrb[1]) ram[d_ram_addr][15:8]<=axi_d_wdata[15:8];
   if(axi_d_wstrb[2]) ram[d_ram_addr][23:16]<=axi_d_wdata[23:16];
   if(axi_d_wstrb[3]) ram[d_ram_addr][31:24]<=axi_d_wdata[31:24];
 end
end
always @* begin
 axi_i_awready=0; axi_i_wready=0; axi_i_bvalid=0; axi_i_bresp=2; axi_i_bid=0;
 axi_i_arready=!i_active && !axi_i_rvalid;
 // Read and write share one physical D RAM port; AR has priority when idle.
 axi_d_arready=!d_active && !axi_d_rvalid && !w_active && !axi_d_bvalid;
 axi_d_awready=!w_active && !axi_d_bvalid && !d_active && !axi_d_rvalid && !axi_d_arvalid;
 axi_d_wready=w_active && !axi_d_bvalid &&
   (MEM_DELAY==0 || random_q[0]) &&
   (w_addr!=32'h80000000 || !tx_busy);
end
integer b;
always @(posedge clk or posedge rst)
if(rst) begin
 i_addr<=0;d_addr<=0;w_addr<=0;i_active<=0;d_active<=0;w_active<=0;
 i_left<=0;d_left<=0;w_left<=0;i_id<=0;d_id<=0;w_id<=0;
 i_bad<=0;d_bad<=0;w_bad<=0;i_delay<=0;d_delay<=0;random_q<=16'hace1;
 axi_i_rvalid<=0;axi_i_rdata<=0;axi_i_rresp<=0;axi_i_rid<=0;axi_i_rlast<=0;
 axi_d_rvalid<=0;axi_d_rdata<=0;axi_d_rresp<=0;axi_d_rid<=0;axi_d_rlast<=0;
 axi_d_bvalid<=0;axi_d_bresp<=0;axi_d_bid<=0;
 mtime<=0;mtimecmp<=64'hffffffffffffffff;msip<=0;force_irq<=0;
 gpio_out<=0;gpio_dir<=0;gpio_irq_enable<=0;gpio_pending<=0;gpio_prev<=0;
 completion_reg<=0;tx_start<=0;tx_data<=0;rx_pop<=0;
end else begin
 random_q<={random_q[14:0],random_q[15]^random_q[13]^random_q[12]^random_q[10]};
 mtime<=mtime+1'b1;tx_start<=0;rx_pop<=0;
 gpio_prev<=gpio_input;gpio_pending<=gpio_pending | (gpio_input & ~gpio_prev);
 if(axi_i_arvalid && axi_i_arready) begin
   i_addr<=axi_i_araddr;i_left<=axi_i_arlen;i_id<=axi_i_arid;i_active<=1;
   i_bad<=axi_i_araddr>=65536 || axi_i_araddr[1:0]!=0 || axi_i_arburst!=1 ||
     ({1'b0,axi_i_araddr}+(({25'b0,axi_i_arlen}+1)<<2))>65536;
   i_delay<=2+MEM_DELAY;
 end
 if(i_active && !axi_i_rvalid) begin
   if(i_delay!=0) i_delay<=i_delay-1'b1;
   else if(MEM_DELAY==0 || random_q[1]) begin
     axi_i_rvalid<=1;axi_i_rdata<=i_bad?0:i_ram_q;axi_i_rresp<=i_bad?2:0;
     axi_i_rid<=i_id;axi_i_rlast<=i_left==0;
   end
 end
 if(axi_i_rvalid && axi_i_rready) begin
   axi_i_rvalid<=0;
   if(i_left==0) i_active<=0;
   else begin i_left<=i_left-1'b1;i_addr<=i_addr+4;i_delay<=2; end
 end
 if(axi_d_arvalid && axi_d_arready) begin
   d_addr<=axi_d_araddr;d_left<=axi_d_arlen;d_id<=axi_d_arid;d_active<=1;
   d_bad<=axi_d_araddr[1:0]!=0 || axi_d_arburst!=1 ||
    (axi_d_araddr>=65536 && axi_d_arlen!=0) ||
    (axi_d_araddr<65536 && ({1'b0,axi_d_araddr}+(({25'b0,axi_d_arlen}+1)<<2))>65536);
   d_delay<=2+MEM_DELAY;
 end
 if(d_active && !axi_d_rvalid) begin
   if(d_delay!=0) d_delay<=d_delay-1'b1;
   else if(MEM_DELAY==0 || random_q[2]) begin
     axi_d_rvalid<=1;axi_d_rdata<=d_addr<65536?d_ram_q:d_mmio;
     axi_d_rresp<=d_bad || !d_known?2:0;axi_d_rid<=d_id;axi_d_rlast<=d_left==0;
     if(d_addr==32'h80000000 && !d_bad) rx_pop<=1;
   end
 end
 if(axi_d_rvalid && axi_d_rready) begin
   axi_d_rvalid<=0;
   if(d_left==0) d_active<=0;
   else begin d_left<=d_left-1'b1;d_addr<=d_addr+4;d_delay<=2;end
 end
 if(axi_d_awvalid && axi_d_awready) begin
   w_addr<=axi_d_awaddr;w_left<=axi_d_awlen;w_id<=axi_d_awid;w_active<=1;
   w_bad<=axi_d_awaddr[1:0]!=0 || axi_d_awburst!=1 ||
    (axi_d_awaddr>=65536 && axi_d_awlen!=0) ||
    (axi_d_awaddr<65536 && ({1'b0,axi_d_awaddr}+(({25'b0,axi_d_awlen}+1)<<2))>65536);
 end
 if(axi_d_bvalid && axi_d_bready) axi_d_bvalid<=0;
 if(w_fire) begin
   if(!w_bad && w_known) begin
    for(b=0;b<4;b=b+1) if(axi_d_wstrb[b]) begin
     case(w_addr)
      32'h80001000:gpio_out[b*8+:8]<=axi_d_wdata[b*8+:8];
      32'h80001008:gpio_dir[b*8+:8]<=axi_d_wdata[b*8+:8];
      32'h8000100c:gpio_irq_enable[b*8+:8]<=axi_d_wdata[b*8+:8];
      32'h80001010:gpio_pending[b*8+:8]<=
        (gpio_pending[b*8+:8] & ~axi_d_wdata[b*8+:8]) | (gpio_input[b*8+:8] & ~gpio_prev[b*8+:8]);
      32'h80002000:mtime[b*8+:8]<=axi_d_wdata[b*8+:8];
      32'h80002004:mtime[32+b*8+:8]<=axi_d_wdata[b*8+:8];
      32'h80002008:mtimecmp[b*8+:8]<=axi_d_wdata[b*8+:8];
      32'h8000200c:mtimecmp[32+b*8+:8]<=axi_d_wdata[b*8+:8];
      32'h80002018:completion_reg[b*8+:8]<=axi_d_wdata[b*8+:8];
     endcase
    end
    if(axi_d_wstrb[0]) case(w_addr)
     32'h80000000:begin tx_start<=1;tx_data<=axi_d_wdata[7:0];end
     32'h80002010:msip<=axi_d_wdata[0];
     32'h80002014:force_irq<=axi_d_wdata[0];
    endcase
   end
   if(w_left==0 || axi_d_wlast) begin
    w_active<=0;axi_d_bvalid<=1;axi_d_bid<=w_id;
    axi_d_bresp<=w_bad || !w_known || (axi_d_wlast!=(w_left==0))?2:0;
   end else begin w_left<=w_left-1'b1;w_addr<=w_addr+4;
     if(!w_known) w_bad<=1; end
 end
end

endmodule
