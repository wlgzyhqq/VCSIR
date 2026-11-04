`timescale 1ns/1ps
module tb_yolo_conv;
 reg clk=0,rst=1,start=0;
`ifdef YOLO_CDC_TEST
 always #5.555 clk=~clk;
 reg mem_clk=0;always #5 mem_clk=~mem_clk;
`else
 always #5 clk=~clk;wire mem_clk=clk;
`endif
 reg [8:0] width,height,out_width,out_height;reg [9:0] channels;
 reg [3:0] output_channels,kernel;reg [1:0] stride,padding;
 reg [11:0] weight_stride;reg [31:0] input_plane,output_plane;reg silu,out16;
 wire busy,done;wire [7:0] error;wire [31:0] cycles,read_bytes,write_bytes;
 wire [27:0] araddr,awaddr;wire [3:0] len;wire arvalid,awvalid;reg arready=0,awready=0,rvalid=0,wready=0;
 reg [255:0] rdata=0;wire [255:0] wdata;wire [31:0] wstrb;
`ifdef YOLO_CDC_TEST
 wire [27:0] x_araddr,x_awaddr;wire [3:0] x_len;wire x_arvalid,x_awvalid,x_arready,x_awready,x_rvalid,x_wready,bridge_fault;
 wire [255:0] x_rdata,x_wdata;wire [31:0] x_wstrb;
 yolo_burst_cdc bridge(.s_clk(clk),.s_rst(rst),.d_clk(mem_clk),.d_rst(rst),.d_fault(3'b0),
 .s_araddr(x_araddr),.s_awaddr(x_awaddr),.s_len(x_len),.s_arvalid(x_arvalid),.s_awvalid(x_awvalid),
 .s_wdata(x_wdata),.s_wstrb(x_wstrb),.s_arready(x_arready),.s_awready(x_awready),.s_rvalid(x_rvalid),.s_wready(x_wready),.s_rdata(x_rdata),.fault(bridge_fault),
 .d_araddr(araddr),.d_awaddr(awaddr),.d_len(len),.d_arvalid(arvalid),.d_awvalid(awvalid),
 .d_arready(arready),.d_awready(awready),.d_rvalid(rvalid),.d_wready(wready),.d_rdata(rdata),.d_wdata(wdata),.d_wstrb(wstrb));
`endif
 yolo_conv dut(.clk(clk),.rst(rst),.start(start),.arb_fault(3'b0),
 .input_base(32'h02000000),.output_base(32'h02080000),.weight_base(32'h02060000),
 .bias_base(32'h02070000),.mult_base(32'h02070100),.shift_base(32'h02070200),.lut_base(32'h02070300),
 .width(width),.height(height),.channels(channels),.out_width(out_width),.out_height(out_height),
 .output_channels(output_channels),.kernel(kernel),.stride(stride),.padding(padding),.weight_stride(weight_stride),
 .input_plane(input_plane),.output_plane(output_plane),.silu(silu),.out16(out16),.busy(busy),.done(done),.error(error),
 .cycles(cycles),.read_bytes(read_bytes),.write_bytes(write_bytes),
`ifdef YOLO_CDC_TEST
 .araddr(x_araddr),.awaddr(x_awaddr),.len(x_len),.arvalid(x_arvalid),.awvalid(x_awvalid),.arready(x_arready),.awready(x_awready),.rvalid(x_rvalid),.wready(x_wready),.rdata(x_rdata),.wdata(x_wdata),.wstrb(x_wstrb));
`else
 .araddr(araddr),.awaddr(awaddr),.len(len),
 .arvalid(arvalid),.awvalid(awvalid),.arready(arready),.awready(awready),.rvalid(rvalid),.wready(wready),.rdata(rdata),.wdata(wdata),.wstrb(wstrb));
`endif
 reg [7:0] mem[0:1048575];reg [7:0] expected[0:262143];
 reg [31:0] rng=32'h87652413;reg reading=0,writing=0;reg [31:0] address;reg [4:0] left;
 integer b;
 always @(negedge mem_clk)begin
  rng=rng^(rng<<13);rng=rng^(rng>>17);rng=rng^(rng<<5);
  arready=!reading&&!writing&&rng[0];awready=!reading&&!writing&&rng[1];rvalid=reading&&rng[2];wready=writing&&rng[3];
  if(reading)for(b=0;b<32;b=b+1)rdata[b*8+:8]=mem[address+b];
 end
 always @(posedge mem_clk)if(rst)begin reading<=0;writing<=0;end else begin
  if(arvalid&&arready)begin reading<=1;address<=(araddr<<2)-32'h02000000;left<=len+1;end
  if(awvalid&&awready)begin writing<=1;address<=(awaddr<<2)-32'h02000000;if(len!=0)$fatal(1,"write burst");end
  if(rvalid)begin if(left==1)reading<=0;else begin left<=left-1;address<=address+32;end end
  if(wready)begin
   for(integer j=0;j<32;j=j+1)if(wstrb[j])mem[address+j]<=wdata[j*8+:8];
   writing<=0;
  end
 end
 integer test_id,fd,got,size,i;integer cw,ch,cc,co,ck,cs,cp,cow,coh,cr,csi,cwi;reg [1023:0] filename;
 initial begin
  for(test_id=0;test_id<10;test_id=test_id+1)begin
   rst=1;repeat(4)@(negedge clk);start=0;
   for(i=0;i<1048576;i=i+1)mem[i]=8'ha5;
   $sformat(filename,"output/conv-vectors/%0d.mem",test_id);$readmemh(filename,mem);
   $sformat(filename,"output/conv-vectors/%0d.config",test_id);fd=$fopen(filename,"r");if(!fd)$fatal(1,"config missing");
   got=$fscanf(fd,"%d %d %d %d %d %d %d %d %d %d %d %d %d",cw,ch,cc,co,ck,cs,cp,cow,coh,cr,csi,cwi,size);$fclose(fd);if(got!=13)$fatal(1,"config invalid");
   $sformat(filename,"output/conv-vectors/%0d.expected",test_id);$readmemh(filename,expected,0,size-1);
   width=cw;height=ch;channels=cc;output_channels=co;kernel=ck;stride=cs;padding=cp;out_width=cow;out_height=coh;weight_stride=cr;
   silu=csi;out16=cwi;input_plane=cw*ch;output_plane=cow*coh*(cwi?2:1);
   rst=0;@(negedge clk);start=1;@(negedge clk);start=0;wait(done);@(negedge clk);
   if(error)$fatal(1,"case %0d error %0d",test_id,error);
   for(i=0;i<size;i=i+1)if(mem['h80000+i]!==expected[i])$fatal(1,"case %0d byte %0d got %h expected %h",test_id,i,mem['h80000+i],expected[i]);
   if(mem['h7ffff]!=8'ha5 || mem['h80000+size]!=8'ha5)$fatal(1,"write crossed output bounds");
   if(write_bytes!=size)$fatal(1,"byte counter");
   $display("conv case %0d PASS cycles=%0d read=%0d written=%0d",test_id,cycles,read_bytes,write_bytes);
  end
  $display("PASS convolution padding/stride/tails/K1152/SiLU LUT/Q10/masked writes under DDR stalls");$finish;
 end
 initial begin #1000000000;$fatal(1,"timeout state=%0d io=%0d",dut.state,dut.io_state);end
endmodule
