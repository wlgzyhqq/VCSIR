`timescale 1ns/1ps
module tb_yolo_video;
 reg clk=0,ui_clk=0,pixel_clk=0,rst=1,ui_rst=1,pixel_rstn=0;
 always #5.555 clk=~clk;always #5 ui_clk=~ui_clk;always #6.737 pixel_clk=~pixel_clk;
 reg [31:0] cpu_addr=0,cpu_wdata=0;reg [3:0] cpu_wstrb=15;reg cpu_we=0;
 wire write_ok;wire [31:0] cpu_rdata;wire [27:0] araddr,v_araddr;wire [3:0] arlen,v_arlen;wire arvalid,v_arvalid,v_arready,v_rvalid;wire [255:0] v_rdata;
 reg arready=0,rvalid=0;reg [255:0] rdata=0;
 reg [11:0] x=0,y=0;reg hs=0,vs=0,de=0;wire hs_out,vs_out,de_out;wire [23:0] rgb;
 yolo_video dut(.clk(clk),.rst(rst),.cpu_addr(cpu_addr),.cpu_wdata(cpu_wdata),.cpu_wstrb(cpu_wstrb),.cpu_we(cpu_we),
 .cpu_write_ok(write_ok),.cpu_rdata(cpu_rdata),.ui_clk(ui_clk),.ui_rst(ui_rst),.arb_fault(3'b0),
 .araddr(v_araddr),.arlen(v_arlen),.arvalid(v_arvalid),.arready(v_arready),.rvalid(v_rvalid),.rdata(v_rdata),
 .pixel_clk(pixel_clk),.pixel_rstn(pixel_rstn),.act_x(x),.act_y(y),.hs_in(hs),.vs_in(vs),.de_in(de),
 .hs_out(hs_out),.vs_out(vs_out),.de_out(de_out),.rgb_out(rgb));
 reg [3:0] left;
 wire [3:0] master_arready,master_rvalid;wire [1023:0] master_rdata;wire [2:0] fabric_fault;
 reg [3:0] waiting=0;reg [3:0] remain[0:3];
 wire cnn_arvalid,cnn_ready,cnn_rvalid,cnn_fault;wire [27:0] cnn_addr;wire [3:0] cnn_len;wire [255:0] cnn_data;
 reg cnn_pending=0;reg [3:0] cnn_left=0;integer cnn_beats=0;
 yolo_burst_cdc cnn_bridge(.s_clk(clk),.s_rst(rst),.d_clk(ui_clk),.d_rst(ui_rst),.d_fault(fabric_fault),
 .s_araddr(28'h00c0000),.s_awaddr(28'b0),.s_len(4'd15),.s_arvalid(!cnn_pending),.s_awvalid(1'b0),.s_wdata(256'b0),.s_wstrb(32'b0),
 .s_arready(cnn_ready),.s_awready(),.s_wready(),.s_rvalid(cnn_rvalid),.s_rdata(cnn_data),.fault(cnn_fault),
 .d_araddr(cnn_addr),.d_awaddr(),.d_len(cnn_len),.d_arvalid(cnn_arvalid),.d_awvalid(),.d_wdata(),.d_wstrb(),
 .d_arready(master_arready[3]),.d_awready(1'b0),.d_wready(1'b0),.d_rvalid(master_rvalid[3]),.d_rdata(master_rdata[1023:768]));
 always @(posedge clk)if(rst)begin cnn_pending<=0;cnn_left<=0;end else begin
  if(!cnn_pending&&cnn_ready)begin cnn_pending<=1;cnn_left<=15;end
  if(cnn_rvalid)begin
   if(cnn_data!=={16{16'h55aa}})$fatal(1,"CNN CDC read corrupted under video contention");
   cnn_beats<=cnn_beats+1;
   if(cnn_left==0)cnn_pending<=0;else cnn_left<=cnn_left-1'b1;
  end
 end
 wire [3:0] master_arvalid={cnn_arvalid,v_arvalid,~waiting[1],~waiting[0]};
 assign v_arready=master_arready[2];assign v_rvalid=master_rvalid[2];assign v_rdata=master_rdata[767:512];
 yolo_ddr_arbiter fabric(.clk(ui_clk),.rst(ui_rst),.m_awaddr(112'b0),.m_araddr({cnn_addr,v_araddr,28'h0080000,28'h0040000}),
 .m_len({cnn_len,v_arlen,4'd15,4'd0}),.m_awvalid(4'b0),.m_arvalid(master_arvalid),.m_awready(),.m_arready(master_arready),.m_wready(),.m_rvalid(master_rvalid),
 .m_wdata(1024'b0),.m_wstrb(128'b0),.m_rdata(master_rdata),.fault(fabric_fault),.cpu_grants(),.dma_grants(),.cpu_wait_max(),
 .h_awaddr(),.h_araddr(araddr),.h_awlen(),.h_arlen(arlen),.h_awvalid(),.h_arvalid(arvalid),.h_awready(1'b0),.h_arready(arready),
 .h_wready(1'b0),.h_rvalid(rvalid),.h_rlast(left==0),.h_wlast(1'b0),.h_wdata(),.h_wstrb(),.h_rdata(rdata));
 always @(posedge ui_clk)begin
  if(ui_rst)begin waiting<=0;for(integer t=0;t<4;t=t+1)remain[t]<=0;end
  else for(integer t=0;t<2;t=t+1)begin
   if(master_arvalid[t] && master_arready[t])begin waiting[t]<=1;remain[t]<=t==0?0:15;end
   if(master_rvalid[t])begin if(remain[t]==0)waiting[t]<=0;else remain[t]<=remain[t]-1;end
  end
 end
 reg [15:0] rng=16'hace1;reg pending=0;reg [31:0] address;integer k;
 integer bursts=0;
 function [15:0] memory_pixel;input [31:0] byte_addr;integer offset,px,py,version;begin
  if(byte_addr<32'h38000000)memory_pixel=16'h55aa;else begin
  version=byte_addr>=32'h38040000;offset=byte_addr-(version?32'h38040000:32'h38000000);
  px=(offset/2)%320;py=(offset/2)/320;
  memory_pixel={5'((px+version*7)&31),6'(py&63),5'((px^py)&31)};
  end
 end endfunction
 always @(negedge ui_clk)begin
  rng<={rng[14:0],rng[15]^rng[13]^rng[12]^rng[10]};
  arready<=!pending && rng[0];rvalid<=0;
  if(pending && rng[1])begin
   rvalid<=1;
   for(k=0;k<16;k=k+1)rdata[k*16+:16]<=memory_pixel(address+k*2);
  end
 end
 always @(posedge ui_clk)begin
  if(!ui_rst)begin
   if(arvalid && arready)begin
    if(araddr[2:0]!=0 || (arlen!=15 && arlen!=3 && arlen!=0))$fatal(1,"bad burst alignment/length");
    address<={araddr,2'b0};left<=arlen;pending<=1;bursts<=bursts+1;
   end
   if(rvalid && pending)begin address<=address+32;if(left==0)pending<=0;else left<=left-1;end
  end
 end
 task write_reg;input [31:0] a,v;begin
  @(negedge clk);cpu_addr=a;cpu_wdata=v;cpu_we=1;
  #1;if(!write_ok)$fatal(1,"MMIO rejected %h",a);
  @(negedge clk);cpu_we=0;
 end endtask
 reg checking=0;reg version_expected=0,boxes_expected=1;
 reg [23:0] exp0,exp1,exp2;reg d0,d1,d2;reg [11:0] x0,x1,x2,y0,y1,y2;
 integer checked=0;reg [15:0] p;integer sx,sy;
 always @(posedge pixel_clk)begin
  d0<=de;d1<=d0;d2<=d1;x0<=x;x1<=x0;x2<=x1;y0<=y;y1<=y0;y2<=y1;
  exp0<=24'h102032;
  if(de && x<640 && y>=40 && y<680)begin
   sx=x/2;sy=(y-40)/2;p=memory_pixel((version_expected?32'h38040000:32'h38000000)+sy*640+sx*2);
   if(boxes_expected && sx>=10 && sx<=100 && sy>=20 && sy<=200 && (sx==10 || sx==100 || sy==20 || sy==200))exp0<=24'h00ff30;
   else exp0<={p[15:11],p[15:13],p[10:5],p[10:9],p[4:0],p[4:2]};
  end
  exp1<=exp0;exp2<=exp1;
  #1;
  if(checking)begin
   if(de_out!==d2)$fatal(1,"DE pipeline mismatch");
   if(d2 && x2<640 && y2>=40 && y2<680)begin
    checked=checked+1;
    if(rgb!==exp2)$fatal(1,"pixel mismatch x%0d y%0d expected %h got %h",x2,y2,exp2,rgb);
   end
  end
 end
 task blank_vs;begin
  repeat(8)@(negedge pixel_clk);
  @(negedge pixel_clk);de=0;vs=1;
  repeat(20)@(negedge pixel_clk);vs=0;
  repeat(1200)@(negedge pixel_clk);
 end endtask
 task frame;integer row,col;begin
  for(row=0;row<720;row=row+1)for(col=0;col<700;col=col+1)begin
   @(negedge pixel_clk);y=row;x=col;de=col<640;hs=col<40;
  end
  @(negedge pixel_clk);de=0;repeat(20)@(negedge pixel_clk);
 end endtask
 initial begin
  repeat(8)@(negedge clk);rst=0;ui_rst=0;pixel_rstn=1;repeat(10)@(negedge clk);
  write_reg(32'h8000700c,32'h38000000);write_reg(32'h80007024,0);
  write_reg(32'h80007028,(20<<16)|10);write_reg(32'h8000702c,(200<<16)|100);write_reg(32'h80007020,1);write_reg(32'h80007008,1);
  blank_vs();checking=1;
  fork
   frame();
   begin
    wait(y==200 && x==100);write_reg(32'h8000700c,32'h38040000);write_reg(32'h80007020,0);write_reg(32'h80007008,1);
   end
  join
  checking=0;version_expected=1;boxes_expected=0;blank_vs();checking=1;frame();checking=0;
  if(dut.underflow_counter!==0 || dut.ui_error!==0 || fabric_fault!==0 || cnn_fault || cnn_beats<1000)$fatal(1,"underflow/error %d CNN beats%d",dut.underflow_counter,cnn_beats);
  if(checked!=819200)$fatal(1,"missing pixels %d",checked);
  $display("PASS video: %0d pixels, %0d bursts, three independent clocks, continuous CPU/DMA/CNN read contention, stalled reads, VS-atomic image/box commit",checked,bursts);$finish;
 end
 initial begin #100000000;$fatal(1,"timeout");end
endmodule
