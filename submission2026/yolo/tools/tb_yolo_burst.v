`timescale 1ns/1ps
module tb_yolo_burst;
 reg sc=0,dc=0,sr=1,dr=1;always #5.555 sc=~sc;always #5 dc=~dc;
 reg [2:0] df=0;reg [27:0] sa=0,sw=0;reg [3:0] sl=0;reg sar=0,saw=0;
 reg [255:0] sd=0;reg [31:0] sm=0;
 wire sarready,sawready,swready,srv,fault;wire [255:0] srd;
 wire [27:0] da,dw;wire [3:0] dl;wire dar,daw;wire [255:0] wd;wire [31:0] wm;
 reg daready=0,dawready=0,wready=0,rv=0;reg [255:0] rd=0;
 yolo_burst_cdc #(.WATCHDOG_BITS(12)) dut(sc,sr,dc,dr,df,sa,sw,sl,sar,saw,sd,sm,
  sarready,sawready,swready,srv,srd,fault,da,dw,dl,dar,daw,wd,wm,daready,dawready,wready,rv,rd);
 function [255:0] pattern(input integer address,input integer beat);
  integer j;begin for(j=0;j<8;j=j+1)pattern[j*32+:32]=(address*32'h9e3779b9)^(beat*31+j*65537);end
 endfunction
 integer rn=0,wn=0,raddr=0,waddr=0,rl=0,wl=0,writes=0,reads=0;
 reg reading=0,writing=0,enable=1;integer seed=548;
 // Response words are registered. Native write transfers occur only on ready.
 always @(negedge dc)begin
  daready=enable&&!reading&&!writing&&($random(seed)&3)!=0;
  dawready=enable&&!reading&&!writing&&($random(seed)&3)!=0;
  wready=enable&&writing&&($random(seed)&3)!=0;
  rv=enable&&reading&&($random(seed)&3)!=0;
  rd=pattern(raddr,rn);
 end
 always @(posedge dc)if(!dr)begin
  if(dar&&daready)begin if(reading||writing)$fatal(1,"overlap read");raddr=da;rl=dl;rn=0;reading=1;end
  else if(rv)begin reads=reads+1;if(rn==rl)reading=0;else rn=rn+1;end
  if(daw&&dawready)begin if(reading||writing)$fatal(1,"overlap write");waddr=dw;wl=dl;wn=0;writing=1;end
  else if(wready)begin
   if(wd!==pattern(waddr,wn)||wm!==(32'hf0ff00aa^wn))$fatal(1,"bad write addr=%h beat=%0d",waddr,wn);
   writes=writes+1;if(wn==wl)writing=0;else wn=wn+1;
  end
 end
 integer n,k,base,expected_writes;
 initial begin
  repeat(5)@(negedge sc);sr=0;dr=0;
  for(k=0;k<8;k=k+1)for(n=0;n<16;n=n+1)begin
   base=4096+k*1024+n*32;
   @(negedge sc);sw=base;sl=n;saw=1;
   do @(posedge sc);while(!sawready);
   @(negedge sc);saw=0;expected_writes=writes+n+1;
   for(integer i=0;i<=n;i=i+1)begin
    sd=pattern(base,i);sm=32'hf0ff00aa^i;
    do @(posedge sc);while(!swready);
    if(i==n&&writes!=expected_writes)$fatal(1,"source completion before DDR commit");
    @(negedge sc);
   end
   sa=base;sl=n;sar=1;
   do @(posedge sc);while(!sarready);
   @(negedge sc);sar=0;
   for(integer i=0;i<=n;i=i+1)begin
    do @(negedge sc);while(!srv);
    if(srd!==pattern(base,i))$fatal(1,"bad read addr=%h beat=%0d",base,i);
   end
  end
  // Stall a command until the watchdog trips, then deliver a late response.
  @(negedge sc);enable=0;sa=555;sl=0;sar=1;
  do @(posedge sc);while(!sarready);
  @(negedge sc);sar=0;
  wait(fault);repeat(4)@(negedge sc);
  enable=1;repeat(30)begin @(negedge sc);if(srv||sarready||sawready||swready)$fatal(1,"fault quarantine failed");end
  $display("PASS burst CDC 90/100MHz: all lengths 1..16, 1088 read/write beats, randomized stalls, deferred commit, timeout/late quarantine");$finish;
 end
 initial begin #2000000;$display("ss=%d ds=%d req=%b ack=%b fault=%b n=%d k=%d reads=%d writes=%d",dut.ss,dut.ds,dut.request,dut.acknowledge,fault,n,k,reads,writes);$fatal(1,"test timeout");end
endmodule
