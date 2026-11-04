// Restoring integer square root of a normalized binary32 significand.
// Same rounding as vector_sqrt; no approximation, FMA or flush-to-zero.
module final_fp_sqrt(input clk,rst,start,input [31:0] a,
 output reg done,output reg [31:0] result,output reg [1:0] flags);
 localparam IDLE=0,NORMALIZE=1,SETUP=2,ITERATE=3,ROUND=4,PACK=5,DECODE=6,ITERATE_COMPARE=7,ITERATE_COMMIT=8;
 reg [3:0] state;
 // Local input stage breaks the caller-to-special-case result/CE path.
 // Input staging adds one cycle; three-phase restoring iterations add48 more
 // for positive finite inputs. Arithmetic, rounding and flags are unchanged.
 reg [31:0] operand;
 reg [24:0] mantissa;
 reg signed [10:0] exponent;
 reg [47:0] remainder,root,bit_value;
 reg [47:0] trial_hold,root_candidate,remainder_candidate /* synthesis syn_preserve=1 syn_allow_retiming=0 */;
 reg trial_accept /* synthesis syn_preserve=1 syn_allow_retiming=0 */;
 wire [31:0] sqrt_input_held /* synthesis syn_keep=1 */;
 genvar sqrt_input_bit;
 generate for(sqrt_input_bit=0;sqrt_input_bit<32;sqrt_input_bit=sqrt_input_bit+1)begin:g_sqrt_input_hold
  GTP_LUT1 #(.INIT(2'h2)) u_holdbuf(.I0(a[sqrt_input_bit]),.Z(sqrt_input_held[sqrt_input_bit])) /* synthesis syn_noprune=1 */;
 end endgenerate
 wire [47:0] trial=root+bit_value;
 always @(posedge clk or posedge rst)
 if(rst) begin
  state<=IDLE;done<=0;result<=0;flags<=0;mantissa<=0;exponent<=0;
  remainder<=0;root<=0;bit_value<=0;operand<=0;trial_hold<=0;root_candidate<=0;remainder_candidate<=0;trial_accept<=0;
 end else begin
  done<=0;
  case(state)
   IDLE:if(start) begin operand<=sqrt_input_held;flags<=0;state<=DECODE;end
   DECODE:begin
    flags<=0;
    if(operand[30:0]==0) begin result<=operand;done<=1;state<=IDLE;end
    else if(operand[31] || operand[30:23]==255) begin result<=32'h7fc00000;flags<=1;done<=1;state<=IDLE;end
    else begin
     mantissa<={1'b0,operand[30:23]!=0,operand[22:0]};
     exponent<=operand[30:23]==0?-11'sd126:$signed({3'b0,operand[30:23]})-11'sd127;
     state<=NORMALIZE;
    end
   end
   NORMALIZE:if(!mantissa[23]) begin mantissa<=mantissa<<1;exponent<=exponent-1'b1;end
    else begin
     if(exponent[0]) begin mantissa<=mantissa<<1;exponent<=exponent-1'b1;end
     state<=SETUP;
    end
   SETUP:begin remainder<={mantissa,23'b0};root<=0;bit_value<=48'h400000000000;state<=ITERATE;end
   ITERATE:begin
    trial_hold<=trial;root_candidate<=(root>>1)+bit_value;state<=ITERATE_COMPARE;
   end
   ITERATE_COMPARE:begin
    trial_accept<=remainder>=trial_hold;remainder_candidate<=remainder-trial_hold;
    state<=ITERATE_COMMIT;
   end
   ITERATE_COMMIT:begin
    if(trial_accept) begin remainder<=remainder_candidate;root<=root_candidate;end
    else root<=root>>1;
    bit_value<=bit_value>>2;
    if(bit_value==1) state<=ROUND;else state<=ITERATE;
   end
   ROUND:begin
    if(remainder>root) root<=root+1'b1;
    exponent<=(exponent>>>1)+11'sd127;state<=PACK;
   end
   PACK:begin
    if(root==48'h1000000) result<={1'b0,(exponent[7:0]+8'd1),23'b0};
    else result<={1'b0,exponent[7:0],root[22:0]};
    done<=1;state<=IDLE;
   end
   default:state<=IDLE;
  endcase
 end
endmodule
