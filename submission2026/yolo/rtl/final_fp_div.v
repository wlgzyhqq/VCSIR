// Finite binary32 division, round-to-nearest-even, gradual underflow.
// Iterative radix-2 significand division; no vendor floating-point IP.
module final_fp_div(input clk,rst,start,input [31:0] a,b,
 output busy,output reg done,output reg [31:0] result,output reg [1:0] flags);
 wire [31:0] input_a_held,input_b_held /* synthesis syn_keep=1 */;
 genvar input_hold_bit;
 generate for(input_hold_bit=0;input_hold_bit<32;input_hold_bit=input_hold_bit+1)begin:g_arith_input_hold
  GTP_LUT1 #(.INIT(2'h2)) u_a(.I0(a[input_hold_bit]),.Z(input_a_held[input_hold_bit])) /* synthesis syn_noprune=1 */;
  GTP_LUT1 #(.INIT(2'h2)) u_b(.I0(b[input_hold_bit]),.Z(input_b_held[input_hold_bit])) /* synthesis syn_noprune=1 */;
 end endgenerate
 localparam IDLE=0,DECODE=1,NA=2,NB=3,PREP=4,DIVIDE=5,UNDER=6,ROUND=7,PACK=8,END=9;
 reg [3:0] state;reg [31:0] av,bv;reg sign;
 reg [23:0] ma,mb;reg signed [10:0] ea,eb,ez;
 reg [24:0] rem;reg [26:0] quotient,z;reg [24:0] rounded;
 reg [5:0] count;
 wire take=rem>={1'b0,mb};
 wire [24:0] residue=take?rem-{1'b0,mb}:rem;
 wire [26:0] next_q={quotient[25:0],take};
 wire [23:0] sig=rounded[24]?rounded[24:1]:rounded[23:0];
 wire signed [10:0] exponent=ez+(rounded[24]?11'sd1:11'sd0);
 wire [10:0] biased=exponent+11'sd127;
 assign busy=state!=IDLE;
 function [26:0] jam;
  input [26:0] v;input [10:0] n;reg [26:0] t;
  begin
   if(n==0) jam=v;
   else if(n>=27) jam={26'b0,|v};
   else begin t=v>>n;t[0]=t[0]|(|(v & ~(27'h7ffffff<<n)));jam=t;end
  end
 endfunction
 always @(posedge clk or posedge rst)
 if(rst) begin
  state<=IDLE;done<=0;result<=0;flags<=0;av<=0;bv<=0;sign<=0;
  ma<=0;mb<=0;ea<=0;eb<=0;ez<=0;rem<=0;quotient<=0;z<=0;rounded<=0;count<=0;
 end else begin
  done<=0;
  case(state)
   IDLE:if(start) begin av<=input_a_held;bv<=input_b_held;flags<=0;sign<=input_a_held[31]^input_b_held[31];state<=DECODE;end
   DECODE:begin
    if(av[30:23]==255 || bv[30:23]==255 || bv[30:0]==0) begin
     result<=32'h7fc00000;flags<=1;state<=END;
    end else if(av[30:0]==0) begin result<={sign,31'b0};state<=END;end
    else begin
     ma<={av[30:23]!=0,av[22:0]};mb<={bv[30:23]!=0,bv[22:0]};
     ea<=av[30:23]==0?-11'sd126:$signed({3'b0,av[30:23]})-11'sd127;
     eb<=bv[30:23]==0?-11'sd126:$signed({3'b0,bv[30:23]})-11'sd127;
     state<=NA;
    end
   end
   NA:if(!ma[23]) begin ma<=ma<<1;ea<=ea-11'sd1;end else state<=NB;
   NB:if(!mb[23]) begin mb<=mb<<1;eb<=eb-11'sd1;end else state<=PREP;
   PREP:begin
    rem<=ma<mb?{ma,1'b0}:{1'b0,ma};ez<=ea-eb-(ma<mb?11'sd1:11'sd0);
    quotient<=0;count<=26;state<=DIVIDE;
   end
   DIVIDE:begin
    quotient<=next_q;rem<=residue<<1;
    if(count==0) begin z<={next_q[26:1],next_q[0]|(|residue)};state<=UNDER;end
    else count<=count-1'b1;
   end
   UNDER:begin
    if(ez < -11'sd126) begin z<=jam(z,-11'sd126-ez);ez<=-11'sd126;end
    state<=ROUND;
   end
   ROUND:begin rounded<={1'b0,z[26:3]}+(z[2] && (z[1] || z[0] || z[3]));state<=PACK;end
   PACK:begin
    if(exponent>127) begin result<={sign,8'hff,23'b0};flags<=2;end
    else result<={sign,(sig[23]?biased[7:0]:8'b0),sig[22:0]};
    state<=END;
   end
   END:begin done<=1;state<=IDLE;end
   default:state<=IDLE;
  endcase
 end
endmodule
