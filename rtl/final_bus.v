// FINAL dual AXI4 slave: external DDR3 line adapter and uncached MMIO.
module final_bus #(parameter MEM_DELAY=0, CLK_HZ=50000000, BAUD=115200,
 parameter INIT_FILE="firmware/demo.hex")(
 output mem_req_valid,input mem_req_ready,output mem_req_write,
 output [29:0] mem_req_addr,output [255:0] mem_req_data,output [31:0] mem_req_strb,
 input mem_rsp_valid,output mem_rsp_ready,input [255:0] mem_rsp_data,input mem_rsp_error,
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
// Main memory is exclusively external DDR3 [0, 1GiB). No RAM array here.
reg [31:0] i_addr,d_addr,w_addr,w_base;
reg i_active,d_active,w_active,i_filled,d_filled,w_collected;
reg [7:0] i_left,d_left,w_left;
reg [3:0] i_id,d_id,w_id;
reg i_bad,d_bad,w_bad;
reg [255:0] i_line,d_line,w_line;
reg [31:0] w_mask;
reg mem_busy,read_turn;
reg [1:0] mem_owner;
reg [63:0] mtime,mtimecmp;
reg msip,force_irq;
reg [31:0] gpio_irq_enable,gpio_pending,gpio_prev,completion_reg;
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
wire d_known=d_addr<32'h40000000 || d_addr==32'h80000000 || d_addr==32'h80000004 ||
 (d_addr>=32'h80001000 && d_addr<=32'h80001010) ||
 (d_addr>=32'h80002000 && d_addr<=32'h80002018);
wire w_known=w_addr<32'h40000000 || w_addr==32'h80000000 ||
 w_addr==32'h80001000 || w_addr==32'h80001008 || w_addr==32'h8000100c || w_addr==32'h80001010 ||
 (w_addr>=32'h80002000 && w_addr<=32'h80002018);
wire i_wait=i_active && !i_bad && !i_filled;
wire d_wait=d_active && d_addr<32'h40000000 && !d_bad && !d_filled;
wire w_wait=w_active && w_collected && !w_bad && w_base<32'h40000000;
wire choose_d=d_wait && (!i_wait || read_turn);
assign mem_req_valid=!mem_busy && (w_wait || i_wait || d_wait);
assign mem_req_write=w_wait;
assign mem_req_addr=w_wait?w_base[29:0]:(choose_d?d_addr[29:0]:i_addr[29:0]);
assign mem_req_data=w_line;
assign mem_req_strb=w_mask;
assign mem_rsp_ready=mem_busy;
wire w_fire=axi_d_wvalid && axi_d_wready;
always @* begin
 axi_i_awready=0;axi_i_wready=0;axi_i_bvalid=0;axi_i_bresp=2;axi_i_bid=0;
 axi_i_arready=!i_active && !axi_i_rvalid;
 axi_d_arready=!d_active && !axi_d_rvalid && !w_active && !axi_d_bvalid;
 axi_d_awready=!w_active && !axi_d_bvalid && !d_active && !axi_d_rvalid && !axi_d_arvalid;
 axi_d_wready=w_active && !w_collected && !axi_d_bvalid &&
  (w_addr!=32'h80000000 || !tx_busy);
end
integer b;
always @(posedge clk or posedge rst)
if(rst) begin
 i_addr<=0;d_addr<=0;w_addr<=0;w_base<=0;i_active<=0;d_active<=0;w_active<=0;
 i_filled<=0;d_filled<=0;w_collected<=0;
 i_left<=0;d_left<=0;w_left<=0;i_id<=0;d_id<=0;w_id<=0;
 i_bad<=0;d_bad<=0;w_bad<=0;i_line<=0;d_line<=0;w_line<=0;w_mask<=0;
 mem_busy<=0;mem_owner<=0;read_turn<=0;
 axi_i_rvalid<=0;axi_i_rdata<=0;axi_i_rresp<=0;axi_i_rid<=0;axi_i_rlast<=0;
 axi_d_rvalid<=0;axi_d_rdata<=0;axi_d_rresp<=0;axi_d_rid<=0;axi_d_rlast<=0;
 axi_d_bvalid<=0;axi_d_bresp<=0;axi_d_bid<=0;
 mtime<=0;mtimecmp<=64'hffffffffffffffff;msip<=0;force_irq<=0;
 gpio_out<=0;gpio_dir<=0;gpio_irq_enable<=0;gpio_pending<=0;gpio_prev<=0;
 completion_reg<=0;tx_start<=0;tx_data<=0;rx_pop<=0;
end else begin
 mtime<=mtime+1'b1;tx_start<=0;rx_pop<=0;
 gpio_prev<=gpio_input;gpio_pending<=gpio_pending | (gpio_input & ~gpio_prev);
 if(mem_req_valid && mem_req_ready) begin
  mem_busy<=1;mem_owner<=w_wait?2:(choose_d?1:0);
  if(!w_wait) read_turn<=!choose_d;
 end
 if(mem_rsp_valid && mem_rsp_ready) begin
  mem_busy<=0;
  case(mem_owner)
   0:begin i_line<=mem_rsp_data;i_filled<=1;i_bad<=mem_rsp_error;end
   1:begin d_line<=mem_rsp_data;d_filled<=1;d_bad<=mem_rsp_error;end
   2:begin
    w_active<=0;w_collected<=0;axi_d_bvalid<=1;axi_d_bid<=w_id;
    axi_d_bresp<=mem_rsp_error?2:0;
   end
  endcase
 end
 if(axi_i_arvalid && axi_i_arready) begin
  i_addr<=axi_i_araddr;i_left<=axi_i_arlen;i_id<=axi_i_arid;i_active<=1;i_filled<=0;
  i_bad<=axi_i_araddr>=32'h40000000 || axi_i_araddr[1:0]!=0 || axi_i_arburst!=1 ||
   axi_i_arlen>7 || ({1'b0,axi_i_araddr[4:2]}+axi_i_arlen)>7;
 end
 if(i_active && !axi_i_rvalid && (i_filled || i_bad)) begin
  axi_i_rvalid<=1;axi_i_rdata<=i_bad?0:i_line[i_addr[4:2]*32+:32];
  axi_i_rresp<=i_bad?2:0;axi_i_rid<=i_id;axi_i_rlast<=i_left==0;
 end
 if(axi_i_rvalid && axi_i_rready) begin
  axi_i_rvalid<=0;
  if(i_left==0) i_active<=0;
  else begin i_left<=i_left-1'b1;i_addr<=i_addr+4;end
 end
 if(axi_d_arvalid && axi_d_arready) begin
  d_addr<=axi_d_araddr;d_left<=axi_d_arlen;d_id<=axi_d_arid;d_active<=1;d_filled<=0;
  d_bad<=axi_d_araddr[1:0]!=0 || axi_d_arburst!=1 ||
   (axi_d_araddr>=32'h40000000 && axi_d_arlen!=0) ||
   (axi_d_araddr<32'h40000000 && (axi_d_arlen>7 ||
    ({1'b0,axi_d_araddr[4:2]}+axi_d_arlen)>7));
 end
 if(d_active && !axi_d_rvalid && (d_filled || d_bad || d_addr>=32'h40000000)) begin
  axi_d_rvalid<=1;axi_d_rdata<=d_bad?0:(d_addr<32'h40000000 ? d_line[d_addr[4:2]*32+:32]:d_mmio);
  axi_d_rresp<=d_bad || !d_known?2:0;axi_d_rid<=d_id;axi_d_rlast<=d_left==0;
  if(d_addr==32'h80000000 && !d_bad) rx_pop<=1;
 end
 if(axi_d_rvalid && axi_d_rready) begin
  axi_d_rvalid<=0;
  if(d_left==0) d_active<=0;
  else begin d_left<=d_left-1'b1;d_addr<=d_addr+4;end
 end
 if(axi_d_awvalid && axi_d_awready) begin
  w_addr<=axi_d_awaddr;w_base<=axi_d_awaddr;w_left<=axi_d_awlen;
  w_id<=axi_d_awid;w_active<=1;w_collected<=0;w_line<=0;w_mask<=0;
  w_bad<=axi_d_awaddr[1:0]!=0 || axi_d_awburst!=1 ||
   (axi_d_awaddr>=32'h40000000 && axi_d_awlen!=0) ||
   (axi_d_awaddr<32'h40000000 && (axi_d_awlen>7 ||
    ({1'b0,axi_d_awaddr[4:2]}+axi_d_awlen)>7));
 end
 if(axi_d_bvalid && axi_d_bready) axi_d_bvalid<=0;
 if(w_fire) begin
  if(!w_bad && w_known) begin
   if(w_base<32'h40000000) begin
    w_line[w_addr[4:2]*32+:32]<=axi_d_wdata;
    w_mask[w_addr[4:2]*4+:4]<=axi_d_wstrb;
   end else begin
    for(b=0;b<4;b=b+1) if(axi_d_wstrb[b]) case(w_addr)
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
    if(axi_d_wstrb[0]) case(w_addr)
     32'h80000000:begin tx_start<=1;tx_data<=axi_d_wdata[7:0];end
     32'h80002010:msip<=axi_d_wdata[0];
     32'h80002014:force_irq<=axi_d_wdata[0];
    endcase
   end
  end
  if(w_left==0 || axi_d_wlast) begin
   if(!w_bad && w_known && w_base<32'h40000000 && (axi_d_wlast==(w_left==0))) w_collected<=1;
   else begin
    w_active<=0;axi_d_bvalid<=1;axi_d_bid<=w_id;
    axi_d_bresp<=w_bad || !w_known || (axi_d_wlast!=(w_left==0))?2:0;
   end
  end else begin w_left<=w_left-1'b1;w_addr<=w_addr+4;end
 end
end

endmodule
