`timescale 1ns/1ps
module tb_yolo_arbiter;
 reg clk=0,rst=1;always #5 clk=~clk;
 reg [111:0] mawa,mara;reg [15:0] mlen;reg [3:0] mawv,marv;wire [3:0] mawr,marr,mwr,mrv;
 reg [1023:0] mwd;reg [127:0] mws;wire [1023:0] mrd;
 wire [2:0] fault;wire [31:0] cg,dg,cwait;wire [27:0] awa,ara;wire [3:0] awlen,arlen;wire awv,arv;
 wire awr,arr,wr,rv,rlast,wlast;wire [255:0] wd;wire [31:0] ws;wire [255:0] rd;
 yolo_ddr_arbiter #(.WATCHDOG_BITS(8)) dut(.clk(clk),.rst(rst),.m_awaddr(mawa),.m_araddr(mara),.m_len(mlen),
 .m_awvalid(mawv),.m_arvalid(marv),.m_awready(mawr),.m_arready(marr),.m_wready(mwr),.m_rvalid(mrv),.m_wdata(mwd),.m_wstrb(mws),.m_rdata(mrd),
 .fault(fault),.cpu_grants(cg),.dma_grants(dg),.cpu_wait_max(cwait),.h_awaddr(awa),.h_araddr(ara),.h_awlen(awlen),.h_arlen(arlen),
 .h_awvalid(awv),.h_arvalid(arv),.h_awready(awr),.h_arready(arr),.h_wready(wr),.h_rvalid(rv),.h_rlast(rlast),.h_wlast(wlast),.h_wdata(wd),.h_wstrb(ws),.h_rdata(rd));
 reg [2:0] phase[0:3];reg [7:0] sequence_id[0:3];reg [3:0] beat_id[0:3];reg [3:0] burst_length[0:3];
 reg [255:0] memory[0:8191];reg native_active=0,native_write=0;reg [12:0] native_addr;reg [3:0] native_left;
 reg [15:0] rng=16'h55a3;reg bad_r=0,bad_w=0,stall_all=0;integer i,j;integer read_beats=0,write_beats=0;
 function [255:0] pattern;input integer id,seq,b;integer q;begin for(q=0;q<8;q=q+1)pattern[q*32+:32]=32'h80000000 | (id<<24) | (seq<<8) | (b<<4) | q;end endfunction
 assign awr=!native_active && rng[0] && !stall_all;assign arr=!native_active && rng[1] && !stall_all;
 assign wr=native_active && native_write && rng[2] && !stall_all;assign rv=native_active && !native_write && rng[3] && !stall_all;
 assign rd=memory[native_addr];assign rlast=bad_r?!(native_left==0):(native_left==0);assign wlast=bad_w?!(native_left==0):(native_left==0);
 always @*begin
  mawa=0;mara=0;mlen=0;mawv=0;marv=0;mwd=0;mws={128{1'b1}};
  for(integer m=0;m<4;m=m+1)begin
   mawa[m*28+:28]=m*28'h4000+((sequence_id[m]&7)*28'h80);mara[m*28+:28]=m*28'h4000+((sequence_id[m]&7)*28'h80);
   mlen[m*4+:4]=burst_length[m];mwd[m*256+:256]=pattern(m,sequence_id[m],beat_id[m]);
   if(sequence_id[m]<64)begin mawv[m]=phase[m]==0 && m!=2;marv[m]=(phase[m]==2 || (phase[m]==0 && m==2));end
  end
 end
 always @(posedge clk)begin
  if(rst)begin
   native_active<=0;native_write<=0;native_addr<=0;native_left<=0;rng<=16'h55a3;
   for(i=0;i<4;i=i+1)begin phase[i]<=0;sequence_id[i]<=0;beat_id[i]<=0;burst_length[i]<=i==0?0:15;end
  end else begin
   rng<={rng[14:0],rng[15]^rng[13]^rng[12]^rng[10]};
   if(awv && awr)begin native_active<=1;native_write<=1;native_addr<=awa[15:3];native_left<=awlen;end
   if(arv && arr)begin native_active<=1;native_write<=0;native_addr<=ara[15:3];native_left<=arlen;end
   if(wr && fault==0)begin memory[native_addr]<=wd;native_addr<=native_addr+1;native_left<=native_left-1;if(native_left==0)native_active<=0;write_beats<=write_beats+1;end
   if(rv && fault==0)begin native_addr<=native_addr+1;native_left<=native_left-1;if(native_left==0)native_active<=0;read_beats<=read_beats+1;end
   for(i=0;i<4;i=i+1)begin
    if(mawv[i] && mawr[i])begin phase[i]<=1;beat_id[i]<=0;end
    if(marv[i] && marr[i])begin phase[i]<=3;beat_id[i]<=0;end
    if(mwr[i])begin
     if(beat_id[i]==burst_length[i])begin phase[i]<=2;beat_id[i]<=0;end else beat_id[i]<=beat_id[i]+1;
    end
    if(mrv[i])begin
     if(!bad_r && !bad_w && mrd[i*256+:256] !== (i==2?256'b0:pattern(i,sequence_id[i],beat_id[i])))$fatal(1,"master%0d response mismatch seq%0d beat%0d",i,sequence_id[i],beat_id[i]);
     if(beat_id[i]==burst_length[i])begin
      phase[i]<=0;beat_id[i]<=0;sequence_id[i]<=sequence_id[i]+1;
      burst_length[i]<=i==0?0:(sequence_id[i]+1)&15;
     end else beat_id[i]<=beat_id[i]+1;
    end
   end
  end
 end
 task reset_all;begin @(negedge clk);rst=1;repeat(3)@(negedge clk);rst=0;end endtask
 initial begin
  for(j=0;j<8192;j=j+1)memory[j]=0;
  reset_all();wait(sequence_id[0]==64 && sequence_id[1]==64 && sequence_id[2]==64 && sequence_id[3]==64);
  if(fault!=0)$fatal(1,"unexpected arbiter fault");
  $display("Normal arbitration PASS read beats%0d write beats%0d CPU max wait%0d",read_beats,write_beats,cwait);
  bad_r=1;reset_all();wait(fault!=0);if(fault!=3)$fatal(1,"expected RLAST error3, got%0d",fault);
  bad_r=0;bad_w=1;reset_all();wait(fault!=0);if(fault!=2)$fatal(1,"expected WLAST error2, got%0d",fault);
  bad_w=0;stall_all=1;reset_all();wait(fault!=0);if(fault!=1)$fatal(1,"expected timeout1, got%0d",fault);
  $display("PASS arbiter: four simultaneous masters, masked ownership, variable0..15 bursts, random stalls, RLAST/WLAST errors, timeout quarantine");$finish;
 end
 initial begin #10000000;$fatal(1,"timeout");end
endmodule
