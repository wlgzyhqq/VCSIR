`timescale 1ns/1ps
module tb_yolo_math;
 reg clk=0,rst=1,clear=0,valid=0;
 always #5 clk=~clk;
 reg [63:0] weights=0,activations=0;reg [255:0] biases=0;
 wire [2047:0] sums;wire pending;
 yolo_mac64 mac(clk,rst,clear,3'd0,3'd0,valid,weights,activations,biases,sums,pending);
 reg qvalid=0,out16=0;reg signed [31:0] accumulator=0;
 reg [30:0] multiplier=0;reg [5:0] shift=0;wire ready;wire signed [15:0] value;
 yolo_requant rq(clk,rst,qvalid,accumulator,multiplier,shift,out16,ready,value);
 integer expected[0:63];integer i,o,p,k,w,a,n,checks=0;
 reg [31:0] rng=32'h5b8f3d21;
 task random_word;begin rng=rng^(rng<<13);rng=rng^(rng>>17);rng=rng^(rng<<5);end endtask
 task checkq(input signed [31:0] x,input [30:0] m,input [5:0] s,input wide);
  reg signed [63:0] product,answer;reg [63:0] absprod,q,rem,den;
  begin
   // Division-based independent oracle (RTL uses shifts/masks).
   product=$signed(x)*$signed({1'b0,m});absprod=product<0?-product:product;den=64'd1<<s;
   q=absprod/den;rem=absprod%den;
   if(rem*2>den || (rem*2==den && (q%2)==1))q=q+1;
   answer=product<0?-$signed(q):$signed(q);
   if(answer>(wide?32767:127))answer=wide?32767:127;
   if(answer<(wide?-32768:-128))answer=wide?-32768:-128;
   @(negedge clk);accumulator=x;multiplier=m;shift=s;out16=wide;qvalid=1;
   @(negedge clk);qvalid=0;
   while(!ready)@(negedge clk);
   if(value!==answer[15:0])$fatal(1,"requant x=%d m=%d s=%d got=%d expected=%d",x,m,s,value,answer);
   checks=checks+1;
  end
 endtask
 initial begin
  repeat(3)@(negedge clk);rst=0;
  // Maximum real dot length, plus all supported odd/tail lengths and bubbles.
  for(n=0;n<10;n=n+1)begin
   k=n==0?1152:(n==1?1:(n*31+1));
   for(o=0;o<8;o=o+1)begin random_word;biases[o*32+:32]=$signed(rng)%100000;
    for(p=0;p<8;p=p+1)expected[o*8+p]=$signed(biases[o*32+:32]);end
   @(negedge clk);clear=1;@(negedge clk);clear=0;
   for(i=0;i<k;i=i+1)begin
    for(o=0;o<8;o=o+1)begin random_word;weights[o*8+:8]=rng[7:0];end
    for(p=0;p<8;p=p+1)begin random_word;activations[p*8+:8]=rng[7:0];end
    for(o=0;o<8;o=o+1)for(p=0;p<8;p=p+1)begin
     w=$signed(weights[o*8+:8]);a=$signed(activations[p*8+:8]);expected[o*8+p]=expected[o*8+p]+w*a;end
    valid=1;@(negedge clk);valid=0;
    if(i%7==0)@(negedge clk);
   end
   repeat(3)@(negedge clk);
   for(o=0;o<64;o=o+1)if($signed(sums[o*32+:32])!==expected[o])$fatal(1,"MAC lane%0d",o);
  end
  for(i=-20;i<=20;i=i+1)begin checkq(i,1,1,0);checkq(i,1,2,1);end
  checkq(-2147483648,2147483647,48,1);checkq(2147483647,2147483647,48,0);
  checkq(-2147483648,0,0,1);checkq(-128,1,0,0);checkq(127,1,0,0);
  for(i=0;i<3000;i=i+1)begin
   random_word;accumulator=rng;random_word;multiplier=rng&32'h7fffffff;random_word;shift=rng%49;
   checkq(accumulator,multiplier,shift,i%2);
  end
  $display("PASS 64 signed MAC lanes, K<=1152 with bubbles; %0d ties-even/saturation cases",checks);$finish;
 end
 initial begin #20000000;$fatal(1,"timeout");end
endmodule
