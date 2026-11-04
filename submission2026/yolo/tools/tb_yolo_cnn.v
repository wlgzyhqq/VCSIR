`timescale 1ns/1ps
module tb_yolo_cnn;
 reg clk=0,ui_clk=0,rst=1,ui_rst=1;always #9.7 clk=~clk;always #5 ui_clk=~ui_clk;
 reg [31:0] addr=0,data=0;reg [3:0] strb=15;reg we=0;wire write_ok;wire [31:0] response;
 wire [27:0] araddr,awaddr;wire [3:0] len;wire arvalid,awvalid;reg arready=0,awready=0,rvalid=0,wready=0;
 reg [255:0] rdata=0;wire [255:0] wdata;wire [31:0] wstrb;
 yolo_cnn #(.WATCHDOG_BITS(8)) dut(.clk(clk),.rst(rst),.cpu_addr(addr),.cpu_wdata(data),.cpu_wstrb(strb),.cpu_we(we),.cpu_write_ok(write_ok),.cpu_rdata(response),
 .ui_clk(ui_clk),.ui_rst(ui_rst),.arb_fault(3'b0),.araddr(araddr),.awaddr(awaddr),.len(len),.arvalid(arvalid),.awvalid(awvalid),
 .arready(arready),.awready(awready),.rvalid(rvalid),.wready(wready),.rdata(rdata),.wdata(wdata),.wstrb(wstrb));
 reg [7:0] mem[0:1048575],expected[0:1023];
 reg [31:0] rng=32'h45672395;reg reading=0,writing=0,drop_reads=0;reg [31:0] address;reg [4:0] left;
 integer bursts=0,writes=0;
 always @(negedge ui_clk)begin
  rng=rng^(rng<<13);rng=rng^(rng>>17);rng=rng^(rng<<5);
  arready=!reading&&!writing&&rng[0];awready=!reading&&!writing&&rng[1];rvalid=reading&&!drop_reads&&rng[2];wready=writing&&rng[3];
  if(reading)for(integer b=0;b<32;b=b+1)rdata[b*8+:8]=mem[address+b];
 end
 always @(posedge ui_clk)if(ui_rst)begin reading<=0;writing<=0;end else begin
  if(arvalid&&arready)begin reading<=1;address<=(araddr<<2)-32'h02000000;left<=len+1;bursts<=bursts+1;end
  if(awvalid&&awready)begin writing<=1;address<=(awaddr<<2)-32'h02000000;writes<=writes+1;end
  if(rvalid)begin if(left==1)reading<=0;else begin left<=left-1;address<=address+32;end end
  if(wready)begin for(integer j=0;j<32;j=j+1)if(wstrb[j])mem[address+j]<=wdata[j*8+:8];writing<=0;end
 end
 task wr(input [7:0] offset,input [31:0] value,input accept);begin
  @(negedge clk);addr=32'h80004000+offset;data=value;we=1;#1;if(write_ok!==accept)$fatal(1,"write acceptance %h",offset);
  @(negedge clk);we=0;
 end endtask
 task complete(input [31:0] code);begin
  @(negedge clk);addr=32'h80004004;#1;
  while(response[0])begin @(negedge clk);#1;end
  if(!response[1])$fatal(1,"completion not sticky");
  addr=32'h80004050;#1;if(response!==code)$fatal(1,"error got%h expected%h",response,code);
 end endtask
 integer i,before_reads,before_writes;
 initial begin
  for(i=0;i<1048576;i=i+1)mem[i]=8'ha5;
  $readmemh("output/conv-vectors/0.mem",mem);$readmemh("output/conv-vectors/0.expected",expected,0,440);
  repeat(6)@(negedge clk);rst=0;ui_rst=0;
  wr('h0c,'h02000000,1);wr('h10,'h02080000,1);wr('h14,'h02060000,1);
  wr('h18,'h02070000,1);wr('h1c,'h02070100,1);wr('h20,'h02070200,1);wr('h24,'h02070300,1);
  wr('h28,{16'd7,16'd9},1);wr('h2c,{16'd7,16'd3},1);wr('h30,{16'd7,16'd9},1);
  wr('h34,32'h01010103,1);wr('h38,32,1);wr('h3c,63,1);wr('h40,63,1);
  wr(8,1,1);wr('h28,0,0); // Busy overwrite must be rejected, held command intact.
  complete(0);
  for(i=0;i<441;i=i+1)if(mem['h80000+i]!==expected[i])$fatal(1,"mailbox result byte%0d",i);
  addr=32'h80004054;#1;if(response!=1)$fatal(1,"rejected overwrite not counted");
  before_reads=bursts;before_writes=writes;
  wr('h28,32'h02070009,1);wr(8,1,1);complete(16);
  if(bursts!=before_reads||writes!=before_writes)$fatal(1,"invalid reserved fields issued DMA");
  wr('h28,{16'd7,16'd9},1);wr('h0c,0,1);wr(8,1,1);complete(1);
  if(bursts!=before_reads||writes!=before_writes)$fatal(1,"invalid address issued DMA");
  wr('h0c,'h02000000,1);drop_reads=1;wr(8,1,1);complete(2);
  before_reads=bursts;before_writes=writes;drop_reads=0;
  repeat(100)@(negedge clk); // Late old beat is ignored after the timeout.
  wr(8,1,1);complete(2);
  if(bursts!=before_reads||writes!=before_writes)$fatal(1,"quarantined interface restarted without reset");
  $display("PASS CNN asynchronous command/result mailbox, busy rejection, real integer output, reserved/address checks, timeout quarantine and late beat");$finish;
 end
 initial begin #2000000;$fatal(1,"test timeout");end
endmodule
