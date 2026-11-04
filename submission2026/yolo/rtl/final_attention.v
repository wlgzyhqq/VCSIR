// RND2: finite FP32 QK/PV, stable softmax and split-half RoPE.
// Entire KV stays in DDR. Each 128-word K/V token is buffered once and
// reused by 14 query heads (7 heads per KV head). No FMA/reordered sum.
// Ops20..31 are private to the production vector driver's DMA sequences.
module final_attention(input clk,rst,start,input [4:0] op,input [31:0] length,
 input stream_valid,output stream_ready,input [255:0] stream_data,input [31:0] stream_keep,
 output result_valid,input result_ready,output [255:0] result_data,
 output reg done,output reg [31:0] error);
 localparam IDLE=0,CLEAR=1,RX=2,RX_WRITE=3,LOAD=4,CAPTURE=5,EXEC=6,WAIT_FP=7,
  WRITE=8,WRITE_B=9,NEXT=10,OUT_READ=11,OUT_CAPTURE=12,OUT=13,FINISH=14,ISSUE_TRUNC=15,CHECK_FP=16,SOFT_MAX=17,SOFT_SUB=18;
 reg [4:0] state;reg [4:0] mode;reg [6:0] pc,ret;
 // All admitted receive lengths are positive multiples of64, at most65536 words.
 reg [9:0] n_tokens;
 reg [10:0] expected_groups;
 wire [16:0] expected_words={expected_groups,6'b0};
 reg [16:0] rx_index;
 reg [31:0] out_words,out_offset;
 reg rx_final_beat /* synthesis syn_preserve=1, syn_allow_retiming=0 */;
 reg [12:0] clear_index;reg [8:0] token,soft_index;
 reg [3:0] head;reg [5:0] component;reg [2:0] lane,out_lane;
 reg [1:0] soft_phase;reg rope_second;
 reg q_valid,s_valid,p_valid,c_valid,coeff_valid,rope_valid;
 reg [31:0] s_length,p_length,c_length,rope_length;
 reg [255:0] rx_hold,output_hold;
 wire [223:0] rx_shift_guarded /* synthesis syn_keep=1 */;
 genvar rx_shift_bit;
 generate for(rx_shift_bit=0;rx_shift_bit<224;rx_shift_bit=rx_shift_bit+1)begin:g_attention_rx_shift_hold
  GTP_LUT1 #(.INIT(2'h2)) u_holdbuf(.I0(rx_hold[rx_shift_bit+32]),.Z(rx_shift_guarded[rx_shift_bit])) /* synthesis syn_noprune=1 */;
 end endgenerate
 reg [31:0] qmem[0:1023] /* synthesis syn_ramstyle="block_ram" */;
 reg [31:0] cmem[0:1023] /* synthesis syn_ramstyle="block_ram" */;
 reg [31:0] smem[0:8191] /* synthesis syn_ramstyle="block_ram" */;
 reg [31:0] pmem[0:8191] /* synthesis syn_ramstyle="block_ram" */;
 reg [31:0] kv_buffer[0:127] /* synthesis syn_ramstyle="block_ram" */;
 reg [31:0] cosmem[0:31] /* synthesis syn_ramstyle="block_ram" */;
 reg [31:0] sinmem[0:31] /* synthesis syn_ramstyle="block_ram" */;
 reg [31:0] qq,cq,sq,pq,kvq,cosq,sinq;
 reg [31:0] soft_score /* synthesis syn_preserve=1 syn_allow_retiming=0 */;
 wire [12:0] out_address=out_offset[12:0]+out_lane;
 wire [9:0] q_address=mode==29?out_address[9:0]:mode==27?
  ({head,6'b0}+{5'b0,component[4:0]}+(rope_second?10'd32:10'd0)):{head,component};
 wire [9:0] c_address=mode==26?out_address[9:0]:{head,component};
 wire [12:0] s_address=mode==24?out_address:{head,soft_index};
 wire [12:0] p_address=mode==25?out_address:{head,(mode==23?token:soft_index)};
 wire [6:0] kv_address={head>=7,component};
 reg [31:0] x,y,v,t,r,p,e,nfloat,acc,maximum,cosine,sine,rope_first;
 reg signed [31:0] exponent;
 reg [2:0] coefficient;
 reg fp_start,div_start,division;
 reg [1:0] return_flags /* synthesis syn_preserve=1 syn_allow_retiming=0 */;
 reg return_sign /* synthesis syn_preserve=1 syn_allow_retiming=0 */;reg [1:0] fp_op;reg [31:0] fa,fb;
 wire fp_done,div_done,fp_busy,div_busy;wire [31:0] fp_result,div_result;
 wire [1:0] fp_flags,div_flags;
 final_fp32 #(.REGISTER_MULT_OPERANDS(1)) u_fp(.clk(clk),.rst(rst),.start(fp_start),.operation(fp_op),
  .a(fa),.b(fb),.busy(fp_busy),.done(fp_done),.result(fp_result),.flags(fp_flags));
 final_fp_div u_div(.clk(clk),.rst(rst),.start(div_start),.a(fa),.b(fb),
  .busy(div_busy),.done(div_done),.result(div_result),.flags(div_flags));
 wire arithmetic_done=division?div_done:fp_done;
 wire [31:0] arithmetic_result=division?div_result:fp_result;
 wire [1:0] arithmetic_flags=division?div_flags:fp_flags;
 assign stream_ready=state==RX;
 assign result_valid=state==OUT;
 assign result_data=output_hold;
 function greater;
  input [31:0] a,b;
  begin greater=!(a[30:0]==0 && b[30:0]==0) &&
   (a[31]!=b[31]?!a[31]:a[31]?(a[30:0]<b[30:0]):(a[30:0]>b[30:0]));end
 endfunction
 function [31:0] integer_trunc;
  input [31:0] f;reg [31:0] magnitude;integer exp;
  begin
   exp=f[30:23]-127;
   if(exp<0)magnitude=0;else if(exp>30)magnitude=32'h7fffffff;
   else if(exp>=23)magnitude={8'b0,1'b1,f[22:0]}<<(exp-23);
   else magnitude={8'b0,1'b1,f[22:0]}>>(23-exp);
   integer_trunc=f[31]?(~magnitude+1'b1):magnitude;
  end
 endfunction
 function [31:0] coeff;
  input [2:0] i;
  begin case(i)
   0:coeff=32'h3ab60b61;1:coeff=32'h3c088889;2:coeff=32'h3d2aaaab;
   3:coeff=32'h3e2aaaab;4:coeff=32'h3f000000;default:coeff=32'h3f800000;
  endcase end
 endfunction
 task issue;
  input [2:0] kind;input [31:0] a,b;input [6:0] target;
  begin fa<=a;fb<=b;division<=kind==4;fp_op<=kind[1:0];
   fp_start<=kind!=4;div_start<=kind==4;ret<=target;state<=WAIT_FP;end
 endtask
 task fail;
  input [31:0] code;
  begin
   error<=code;q_valid<=0;s_valid<=0;p_valid<=0;c_valid<=0;rope_valid<=0;
   // Preserve the DMA stream contract even after a rejected token.
   if(rx_index<expected_words)state<=RX;else state<=FINISH;
  end
 endtask
 wire rx_visible=(mode!=30 && mode!=31) || rx_index[8:0]<n_tokens;
 wire rx_bad=rx_visible && rx_hold[30:23]==255;
 wire q_we=(state==RX_WRITE && (mode==20 || mode==27)) || (state==WRITE && mode==27) || state==WRITE_B;
 wire [9:0] q_wa=state==RX_WRITE?rx_index[9:0]:{head,(state==WRITE_B),component[4:0]};
 wire [31:0] q_wd=state==RX_WRITE?rx_hold[31:0]:state==WRITE_B?v:rope_first;
 wire c_we=(state==CLEAR && mode==23) || (state==WRITE && mode==23);
 wire [9:0] c_wa=state==CLEAR?clear_index[9:0]:{head,component};
 wire s_we=(state==RX_WRITE && mode==30) || (state==CLEAR && mode==21) || (state==WRITE && mode==21);
 wire [12:0] s_wa=state==RX_WRITE?rx_index[12:0]:state==CLEAR?clear_index:{head,token};
 wire p_we=(state==RX_WRITE && mode==31) || (state==CLEAR && mode==22) || (state==WRITE && mode==22);
 wire [12:0] p_wa=state==RX_WRITE?rx_index[12:0]:state==CLEAR?clear_index:{head,soft_index};
 // Dedicated synchronous memory ports; controller states wait for reads.
 always @(posedge clk) begin
  qq<=qmem[q_address];cq<=cmem[c_address];sq<=smem[s_address];pq<=pmem[p_address];
  kvq<=kv_buffer[kv_address];cosq<=cosmem[component[4:0]];sinq<=sinmem[component[4:0]];
  if(!rst) begin
   if(state==RX_WRITE) begin
    if(mode==21 || mode==23)kv_buffer[rx_index[6:0]]<=rx_hold[31:0];
    if(mode==28 && !rx_index[5])cosmem[rx_index[4:0]]<=rx_hold[31:0];
    if(mode==28 && rx_index[5])sinmem[rx_index[4:0]]<=rx_hold[31:0];
   end
   if(q_we)qmem[q_wa]<=q_wd;
   if(c_we)cmem[c_wa]<=state==CLEAR?32'b0:v;
   if(s_we)smem[s_wa]<=state==RX_WRITE?rx_hold[31:0]:state==CLEAR?32'b0:v;
   if(p_we)pmem[p_wa]<=state==RX_WRITE?rx_hold[31:0]:state==CLEAR?32'b0:soft_phase==1?e:v;
  end
 end
 wire [31:0] output_word=mode==24?sq:mode==25?pq:mode==26?cq:qq;
 genvar attention_output_lane;
 generate for(attention_output_lane=0;attention_output_lane<8;attention_output_lane=attention_output_lane+1)begin:g_attention_output_lane
  always @(posedge clk or posedge rst)
   if(rst)output_hold[attention_output_lane*32+:32]<=0;
   else if(state==OUT_CAPTURE && out_lane==attention_output_lane)
    output_hold[attention_output_lane*32+:32]<=output_word;
 end endgenerate
 always @(posedge clk or posedge rst)
 if(rst)begin
  state<=IDLE;mode<=0;pc<=0;ret<=0;n_tokens<=0;expected_groups<=0;rx_index<=0;rx_final_beat<=0;
  out_words<=0;out_offset<=0;clear_index<=0;token<=0;soft_index<=0;head<=0;component<=0;
  lane<=0;out_lane<=0;soft_phase<=0;rope_second<=0;
  q_valid<=0;s_valid<=0;p_valid<=0;c_valid<=0;coeff_valid<=0;rope_valid<=0;
  s_length<=0;p_length<=0;c_length<=0;rope_length<=0;rx_hold<=0;
  x<=0;y<=0;v<=0;t<=0;r<=0;p<=0;e<=0;nfloat<=0;acc<=0;maximum<=0;soft_score<=0;
  cosine<=0;sine<=0;rope_first<=0;exponent<=0;coefficient<=0;
  return_flags<=0;return_sign<=0;
  fp_start<=0;div_start<=0;division<=0;fp_op<=0;fa<=0;fb<=0;done<=0;error<=0;
 end else begin
  fp_start<=0;div_start<=0;done<=0;
  case(state)
   IDLE:if(start)begin
    mode<=op;n_tokens<=length[9:0];error<=0;rx_index<=0;expected_groups<=0;rx_final_beat<=0;head<=0;component<=0;
    token<=0;soft_index<=0;clear_index<=0;lane<=0;out_lane<=0;out_offset<=0;
    acc<=0;maximum<=0;soft_phase<=0;rope_second<=0;
    case(op)
     20:if(length==896)begin q_valid<=0;rope_valid<=0;expected_groups<=11'd14;state<=RX;end
       else begin error<=1;state<=FINISH;end
     21:if(q_valid && length>=1 && length<=512)begin
       s_valid<=0;p_valid<=0;c_valid<=0;expected_groups<=length<<1;state<=CLEAR;
      end else begin error<=1;state<=FINISH;end
     22:if(s_valid && length==s_length)begin p_valid<=0;c_valid<=0;state<=CLEAR;end
       else begin error<=1;state<=FINISH;end
     23:if(p_valid && length==p_length)begin c_valid<=0;expected_groups<=length<<1;state<=CLEAR;end
       else begin error<=1;state<=FINISH;end
     24:if(s_valid && length==s_length)begin out_words<=7168;state<=OUT_READ;end
       else begin error<=1;state<=FINISH;end
     25:if(p_valid && length==p_length)begin out_words<=7168;state<=OUT_READ;end
       else begin error<=1;state<=FINISH;end
     26:if(c_valid && length==c_length)begin out_words<=896;state<=OUT_READ;end
       else begin error<=1;state<=FINISH;end
     27:if(coeff_valid && length>=64 && length<=896 && length[5:0]==0)begin
       q_valid<=0;rope_valid<=0;expected_groups<=length>>6;state<=RX;
      end else begin error<=1;state<=FINISH;end
     28:if(length==64)begin coeff_valid<=0;expected_groups<=11'd1;state<=RX;end
       else begin error<=1;state<=FINISH;end
     29:if(rope_valid && length==rope_length)begin out_words<=length;state<=OUT_READ;end
       else begin error<=1;state<=FINISH;end
     30,31:if(length>=1 && length<=512)begin
       expected_groups<=11'd112;state<=RX;
       if(op==30)begin s_valid<=0;p_valid<=0;c_valid<=0;end else begin p_valid<=0;c_valid<=0;end
      end else begin error<=1;state<=FINISH;end
     default:begin error<=1;state<=FINISH;end
    endcase
   end
   CLEAR:if(clear_index==(mode==23?13'd895:13'd7167))begin
    clear_index<=0;if(mode==22)state<=LOAD;else state<=RX;
   end else clear_index<=clear_index+1'b1;
   RX:if(stream_valid)begin
    if(stream_keep!=32'hffffffff)error<=3;
    rx_hold<=stream_data;rx_final_beat<=rx_index+17'd8==expected_words;lane<=0;state<=RX_WRITE;
   end
   RX_WRITE:begin
    if(rx_bad)error<=3;
    rx_hold<={32'b0,rx_shift_guarded};rx_index<=rx_index+1'b1;
    if(rx_final_beat && lane==7)begin
     if(error!=0 || rx_bad)state<=FINISH;
     else case(mode)
      20:begin q_valid<=1;state<=FINISH;end
      28:begin coeff_valid<=1;state<=FINISH;end
      30:begin s_valid<=1;s_length<=n_tokens;state<=FINISH;end
      31:begin p_valid<=1;p_length<=n_tokens;state<=FINISH;end
      default:begin head<=0;component<=0;acc<=0;state<=LOAD;end
     endcase
    end else if(lane==7)begin
     if((mode==21 || mode==23) && rx_index[6:0]==127 && error==0 && !rx_bad)begin
      head<=0;component<=0;acc<=0;state<=LOAD;
     end else state<=RX;
    end else lane<=lane+1'b1;
   end
   LOAD:state<=CAPTURE;
   CAPTURE:case(mode)
    21:issue(1,qq,kvq,1);
    23:begin acc<=cq;issue(1,kvq,pq,10);end
    22:case(soft_phase)
     0:begin soft_score<=sq;state<=SOFT_MAX;end
     1:begin soft_score<=sq;state<=SOFT_SUB;end
     default:issue(4,pq,acc,66);
    endcase
    27:if(!rope_second)begin x<=qq;cosine<=cosq;sine<=sinq;rope_second<=1;state<=LOAD;end
       else begin y<=qq;rope_second<=0;issue(1,x,cosine,70);end
    default:fail(1);
   endcase
   SOFT_MAX:begin
    if(soft_index==0 || greater(soft_score,maximum))maximum<=soft_score;
    if({1'b0,soft_index}+10'd1==n_tokens)begin soft_index<=0;soft_phase<=1;acc<=0;end
    else soft_index<=soft_index+1'b1;
    state<=LOAD;
   end
   SOFT_SUB:issue(0,soft_score,{~maximum[31],maximum[30:0]},50);
   ISSUE_TRUNC:issue(2,exponent,0,53);
   WAIT_FP:if(arithmetic_done)begin
    return_flags<=arithmetic_flags;return_sign<=arithmetic_result[31];state<=CHECK_FP;
   end
   CHECK_FP:begin
    // Both producer units hold result until the next start/reset. No issue
    // occurs in WAIT_FP/CHECK_FP, so result is the same word sampled at done.
    // Retain the frozen negative-overflow exp(-Inf) exception exactly.
    if(return_flags!=0 && !(mode==22 && ret==50 && return_flags==2 && return_sign))fail(4);
    else begin v<=arithmetic_result;pc<=ret;state<=EXEC;end
   end
   EXEC:case(pc)
    1:issue(0,acc,v,2);
    2:begin acc<=v;if(component==63)issue(1,v,32'h3e000000,3);
      else begin component<=component+1'b1;state<=LOAD;end end
    3:state<=WRITE;
    10:issue(0,acc,v,11);
    11:state<=WRITE;
    50:begin
     x<=v;
     if(v[31] && v[30:0]>=31'h42d00000)begin e<=0;issue(0,acc,0,65);end
     else if(v[30:0]==0)begin e<=32'h3f800000;issue(0,acc,32'h3f800000,65);end
     else issue(1,v,32'h3fb8aa3b,51);
    end
    51:issue(0,v,32'hbf000000,52);
    52:begin exponent<=integer_trunc(v);state<=ISSUE_TRUNC;end
    53:begin nfloat<=v;issue(1,v,32'h3f317200,54);end
    54:issue(0,x,{~v[31],v[30:0]},55);
    55:begin t<=v;issue(1,nfloat,32'h35bfbe8e,56);end
    56:issue(0,t,{~v[31],v[30:0]},57);
    57:begin r<=v;p<=32'h39500d01;coefficient<=0;pc<=58;end
    58:issue(1,r,p,59);
    59:issue(0,coeff(coefficient),v,60);
    60:begin p<=v;if(coefficient==6)pc<=61;else begin coefficient<=coefficient+1'b1;pc<=58;end end
    61:if(exponent < -126)issue(1,p,((exponent+151)<<23),62);
       else issue(1,p,((exponent+127)<<23),63);
    62:issue(1,v,32'h33800000,63);
    63:begin e<=v;issue(0,acc,v,65);end
    65:begin acc<=v;state<=WRITE;end
    66:state<=WRITE;
    70:begin t<=v;issue(1,y,sine,71);end
    71:issue(0,t,{~v[31],v[30:0]},72);
    72:begin rope_first<=v;issue(1,x,sine,73);end
    73:begin t<=v;issue(1,y,cosine,74);end
    74:issue(0,t,v,75);
    75:state<=WRITE;
    default:fail(1);
   endcase
   WRITE:case(mode)
    21:begin
     if(head==13)begin
      if({1'b0,token}+10'd1==n_tokens)begin s_valid<=1;s_length<=n_tokens;state<=FINISH;end
      else begin token<=token+1'b1;state<=RX;end
     end else begin head<=head+1'b1;component<=0;acc<=0;state<=LOAD;end
    end
    23:begin
     if(component==63)begin
      component<=0;
      if(head==13)begin
       if({1'b0,token}+10'd1==n_tokens)begin c_valid<=1;c_length<=n_tokens;state<=FINISH;end
       else begin token<=token+1'b1;state<=RX;end
      end else begin head<=head+1'b1;state<=LOAD;end
     end else begin component<=component+1'b1;state<=LOAD;end
    end
    22:begin
     if({1'b0,soft_index}+10'd1==n_tokens)begin
      soft_index<=0;
      if(soft_phase==1)begin soft_phase<=2;state<=LOAD;end
      else if(head==13)begin p_valid<=1;p_length<=n_tokens;state<=FINISH;end
      else begin head<=head+1'b1;soft_phase<=0;maximum<=0;state<=LOAD;end
     end else begin soft_index<=soft_index+1'b1;state<=LOAD;end
    end
    27:state<=WRITE_B;
    default:fail(1);
   endcase
   WRITE_B:if(component==31)begin
    component<=0;
    if((({28'b0,head}+32'd1)<<6)==n_tokens)begin
     rope_valid<=1;rope_length<=n_tokens;q_valid<=n_tokens==896;state<=FINISH;
    end else begin head<=head+1'b1;state<=LOAD;end
   end else begin component<=component+1'b1;state<=LOAD;end
   OUT_READ:state<=OUT_CAPTURE;
   OUT_CAPTURE:begin
    if(out_lane==7)state<=OUT;else begin out_lane<=out_lane+1'b1;state<=OUT_READ;end
   end
   OUT:if(result_ready)begin
    if(out_offset+8==out_words)state<=FINISH;
    else begin out_offset<=out_offset+8;out_lane<=0;state<=OUT_READ;end
   end
   FINISH:begin done<=1;state<=IDLE;end
   default:state<=IDLE;
  endcase
 end
endmodule
