// VFN: one 32-element tile. Operations 10 SiLU,11 MUL,12 Q8,13 fused,14 output.
// DMA input is 128 bytes A then (MUL/fused only) 128 bytes B. Output is
// 128 float bytes or 34 Q8 bytes (FP16 scale + signed bytes), little endian.
// Two synchronous RAM tiles, shared arithmetic, frozen non-FMA order.
module final_ffn_tile(input clk,rst,start,input [4:0] op,input [31:0] control,length,
 input stream_valid,output stream_ready,input [255:0] stream_data,input [31:0] stream_keep,
 output result_valid,input result_ready,output [255:0] result_data,
 output reg done,output reg [31:0] error);
 localparam IDLE=0,RX=1,LOAD=2,EXEC=3,WAIT_FP=4,SAVE=5,QBEGIN=6,QEXEC=7,
  QSAVE=8,OUT_PREP=9,OUT=10,FINISH=11,QWRITE=12,WAIT_HALF=13,QREAD=14,
  RX_WRITE=15,LOAD_CAPTURE=16,MAX_READ=17,QWAIT=18,OUT_READ=19,OUT_PACK=20,WAIT_SQRT=21,ISSUE_TRUNC=22,RMS_TILE_END=23,ISSUE_RMS_LENGTH=24,RMS_BEGIN=25;
 reg [4:0] state;reg [4:0] mode,index;reg [2:0] rx_index,out_index,rx_lane,out_lane;
 reg [6:0] pc,ret;
 reg [31:0] values[0:31] /* synthesis syn_ramstyle="block_ram" */;
 reg [31:0] second[0:31] /* synthesis syn_ramstyle="block_ram" */;
 reg [31:0] values_q,second_q;
 reg [255:0] rx_hold;
 wire [223:0] rx_shift_guarded /* synthesis syn_keep=1 */;
 genvar rx_shift_bit;
 generate for(rx_shift_bit=0;rx_shift_bit<224;rx_shift_bit=rx_shift_bit+1)begin:g_vfn_rx_shift_hold
  GTP_LUT1 #(.INIT(2'h2)) u_holdbuf(.I0(rx_hold[rx_shift_bit+32]),.Z(rx_shift_guarded[rx_shift_bit])) /* synthesis syn_noprune=1 */;
 end endgenerate
 reg [31:0] x,y,v,t,r,p,e,nfloat,maximum,d,inverse;
 reg [31:0] rms_sum,rms_factor,rms_control;
 // Accepted length<=4864; a partially completed continuation can reach4895.
 reg [12:0] rms_length,rms_count;
 reg rms_command_ok /* synthesis syn_preserve=1 syn_allow_retiming=0 */;
 reg [12:0] rms_requested_length /* synthesis syn_preserve=1 syn_allow_retiming=0 */;
 reg rms_valid,sqrt_start;wire sqrt_done;wire [31:0] sqrt_result;wire [1:0] sqrt_flags;
 final_fp_sqrt u_sqrt(.clk(clk),.rst(rst),.start(sqrt_start),.a(v),
  .done(sqrt_done),.result(sqrt_result),.flags(sqrt_flags));
 wire [4:0] ram_read_index=(state==OUT_READ || state==OUT_PACK)?{out_index[1:0],out_lane}:index;
 wire [4:0] ram_write_index=state==SAVE?index:{rx_index[1:0],rx_lane};
 wire [4:0] ram_write_address_held /* synthesis syn_keep=1 */;
 genvar write_address_bit;
 generate for(write_address_bit=0;write_address_bit<5;write_address_bit=write_address_bit+1)begin:g_vfn_write_address_hold
  GTP_LUT1 #(.INIT(2'h2)) u_holdbuf(.I0(ram_write_index[write_address_bit]),.Z(ram_write_address_held[write_address_bit])) /* synthesis syn_noprune=1 */;
 end endgenerate
 wire [31:0] ram_write_data=state==SAVE?v:rx_hold[31:0];
 // Read-before-write is intentional. Controller wait states consume only a
 // subsequent read of the committed address; RAM contents are not reset.
 always @(posedge clk) begin
  values_q<=values[ram_read_index];second_q<=second[ram_read_index];
  if(!rst) begin
   if(state==SAVE || (state==RX_WRITE && !rx_index[2])) values[ram_write_address_held]<=ram_write_data;
   if(state==RX_WRITE && rx_index[2]) second[ram_write_address_held]<=ram_write_data;
  end
 end
 reg [7:0] quantized[0:31];reg [15:0] scale;
 wire [255:0] quantized_packed_held /* synthesis syn_keep=1 */;
 wire [15:0] scale_output_held /* synthesis syn_keep=1 */;
 genvar packed_bit,scale_output_bit;
 generate for(packed_bit=0;packed_bit<256;packed_bit=packed_bit+1)begin:g_quantized_output_hold
  GTP_LUT1 #(.INIT(2'h2)) u_holdbuf(.I0(quantized[packed_bit/8][packed_bit%8]),.Z(quantized_packed_held[packed_bit])) /* synthesis syn_noprune=1 */;
 end
 for(scale_output_bit=0;scale_output_bit<16;scale_output_bit=scale_output_bit+1)begin:g_scale_output_hold
  GTP_LUT1 #(.INIT(2'h2)) u_holdbuf(.I0(scale[scale_output_bit]),.Z(scale_output_held[scale_output_bit])) /* synthesis syn_noprune=1 */;
 end endgenerate
 reg [7:0] quant_hold;
 wire [7:0] quant_hold_guarded /* synthesis syn_keep=1 */;
 genvar quant_hold_bit;
 generate for(quant_hold_bit=0;quant_hold_bit<8;quant_hold_bit=quant_hold_bit+1)begin:g_quant_hold
  GTP_LUT1 #(.INIT(2'h2)) u_holdbuf(.I0(quant_hold[quant_hold_bit]),.Z(quant_hold_guarded[quant_hold_bit])) /* synthesis syn_noprune=1 */;
 end endgenerate
 reg signed [31:0] n;
 reg [2:0] coefficient;
 reg valid,packed,rx_bad,fp_start,div_start,division;
 reg x_zero,inverse_zero,inverse_nonfinite;
 reg d_zero,x_saturated,scale_nonfinite,v_abs_saturated,v_unsigned_saturated /* synthesis syn_preserve=1 syn_allow_retiming=0 */;
 reg [1:0] fp_op;
 reg [31:0] fa /* synthesis syn_preserve=1 syn_allow_retiming=0 */;
 reg [31:0] fb /* synthesis syn_preserve=1 syn_allow_retiming=0 */;
 reg [31:0] operand_a,operand_b;wire [31:0] fp_result,div_result;
 wire fp_done,div_done,fp_busy,div_busy;wire [1:0] fp_flags,div_flags;
 reg [255:0] output_hold;
 reg half_start;reg [31:0] half_arg;wire half_done;wire [15:0] half_result;
 final_fp16_pack u_half(.clk(clk),.rst(rst),.start(half_start),.a(half_arg),.done(half_done),.result(half_result));
 final_fp32 #(.REGISTER_MULT_OPERANDS(1),.P10_HOLD_BUFFER(1)) u_fp(.clk(clk),.rst(rst),.start(fp_start),.operation(fp_op),
  .a(fa),.b(fb),.busy(fp_busy),.done(fp_done),.result(fp_result),.flags(fp_flags));
 final_fp_div u_div(.clk(clk),.rst(rst),.start(div_start),.a(fa),.b(fb),
  .busy(div_busy),.done(div_done),.result(div_result),.flags(div_flags));
 assign stream_ready=state==RX;
 assign result_valid=state==OUT;
 assign result_data=output_hold;
 wire arithmetic_done=division?div_done:fp_done;
 wire [31:0] arithmetic_result=division?div_result:fp_result;
 wire [1:0] arithmetic_flags=division?div_flags:fp_flags;
 function [31:0] integer_trunc;
  input [31:0] f;reg [31:0] magnitude;integer exponent;
  begin
   exponent=f[30:23]-127;
   if(exponent<0) magnitude=0;
   else if(exponent>30) magnitude=32'h7fffffff;
   else if(exponent>=23) magnitude={8'b0,1'b1,f[22:0]}<<(exponent-23);
   else magnitude={8'b0,1'b1,f[22:0]}>>(23-exponent);
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
 // Registered operand selection is independent of data-dependent issue enables.
 // FP/division units latch these registers only on start, at the following edge.
 always @* begin
  operand_a=0;operand_b=0;
  if(state==ISSUE_TRUNC)begin operand_a=n;operand_b=0;end
  else if(state==ISSUE_RMS_LENGTH)begin operand_a=rms_length;operand_b=0;end
  else case(pc)
    0:begin operand_a={1'b1,x[30:0]};operand_b=32'h3fb8aa3b;end
    1:begin operand_a=v;operand_b=32'hbf000000;end
    3:begin operand_a=v;operand_b=32'h3f317200;end
    4:begin operand_a={1'b1,x[30:0]};operand_b={~v[31],v[30:0]};end
    5:begin operand_a=nfloat;operand_b=32'h35bfbe8e;end
    6:begin operand_a=t;operand_b={~v[31],v[30:0]};end
    8:begin operand_a=r;operand_b=p;end
    9:begin operand_a=coeff(coefficient);operand_b=v;end
    11:begin operand_a=p;operand_b=(n < -126)?(((n+151)<<23)):(((n+127)<<23));end
    12:begin operand_a=v;operand_b=32'h33800000;end
    20:begin operand_a=32'h3f800000;operand_b=e;end
    21:begin operand_a=(x[31] && !x_zero)?(e):(x);operand_b=v;end
    22:begin operand_a=x;operand_b=v;end
    23:begin operand_a=v;operand_b=y;end
    40:begin operand_a=x;operand_b=y;end
    41:begin operand_a=x;operand_b=y;end
    80:begin operand_a=x;operand_b=x;end
    81:begin operand_a=rms_sum;operand_b=v;end
    83:begin operand_a=rms_sum;operand_b=v;end
    84:begin operand_a=v;operand_b=32'h358637bd;end
    86:begin operand_a=32'h3f800000;operand_b=v;end
    90:begin operand_a=x;operand_b=rms_factor;end
    91:begin operand_a=v;operand_b=y;end
    51:begin operand_a=maximum;operand_b=32'h42fe0000;end
    53:begin operand_a=32'h3f800000;operand_b=d;end
    57:begin operand_a=x;operand_b=inverse;end
    58:begin operand_a={1'b0,v[30:0]};operand_b=32'h3f000000;end
    default:begin operand_a=0;operand_b=0;end
  endcase
 end
 task issue;
  input [2:0] kind;input [6:0] target;
  begin
   division<=kind==4;fp_op<=kind[1:0];
   fp_start<=kind!=4;div_start<=kind==4;ret<=target;state<=WAIT_FP;
  end
 endtask
 task fail;
  input [31:0] code;
  begin error<=code;valid<=0;rms_valid<=0;state<=FINISH;end
 endtask
 integer j;
 reg [31:0] qmag;
 always @(posedge clk or posedge rst)
 if(rst) begin
  state<=IDLE;mode<=0;index<=0;rx_index<=0;out_index<=0;rx_lane<=0;out_lane<=0;rx_hold<=0;pc<=0;ret<=0;
  scale<=0;quant_hold<=0;x<=0;y<=0;v<=0;t<=0;r<=0;p<=0;e<=0;nfloat<=0;maximum<=0;d<=0;inverse<=0;n<=0;
  x_zero<=1;inverse_zero<=1;inverse_nonfinite<=0;d_zero<=1;x_saturated<=0;scale_nonfinite<=0;v_abs_saturated<=0;v_unsigned_saturated<=0;
  coefficient<=0;valid<=0;packed<=0;rx_bad<=0;fp_start<=0;div_start<=0;division<=0;
  fp_op<=0;fa<=0;fb<=0;output_hold<=0;done<=0;error<=0;half_start<=0;half_arg<=0;
  rms_sum<=0;rms_factor<=0;rms_length<=0;rms_count<=0;rms_control<=0;rms_valid<=0;sqrt_start<=0;rms_command_ok<=0;rms_requested_length<=0;
 end else begin
  fp_start<=0;div_start<=0;done<=0;half_start<=0;sqrt_start<=0;
  fa<=operand_a;fb<=operand_b;
  case(state)
   IDLE:if(start) begin
    mode<=op;error<=0;index<=0;rx_index<=0;out_index<=0;maximum<=0;rx_bad<=0;
    if(op==14) begin if(valid) state<=OUT_PREP;else fail(1);end
    else if(op==15) begin
     valid<=0;rms_valid<=0;rms_control<=control;
     rms_command_ok<=!(length==0 || length>4864 || length[4:0]!=0 || control>3 ||
        (!control[0] && (rms_length!=length || rms_count==0 || rms_count>=length)));
     rms_requested_length<=length[12:0];state<=RMS_BEGIN;
    end
    else if(op==16 || op==17) begin
     if(!rms_valid) fail(1);
     else begin valid<=0;packed<=op==16;state<=RX;end
    end
    else if((op>=10 && op<=13) || op==18) begin valid<=0;packed<=op==12 || op==13;state<=RX;end
    else fail(1);
   end
   RMS_BEGIN:begin
    if(!rms_command_ok) fail(1);
    else begin
     if(rms_control[0]) begin rms_sum<=0;rms_count<=0;rms_length<=rms_requested_length;end
     state<=RX;
    end
   end
   RX:if(stream_valid) begin
    if(stream_keep!=32'hffffffff) rx_bad<=1;
    for(j=0;j<8;j=j+1)
     if(stream_data[j*32+23+:8]==255) rx_bad<=1;
    rx_hold<=stream_data;rx_lane<=0;state<=RX_WRITE;
   end
   RX_WRITE:begin
    rx_hold<={32'b0,rx_shift_guarded};
    if(rx_lane==7) begin
     if(rx_index==((mode==11 || mode==13 || mode==16 || mode==17 || mode==18)?7:3)) state<=LOAD;
     else begin rx_index<=rx_index+1'b1;state<=RX;end
    end else rx_lane<=rx_lane+1'b1;
   end
   LOAD:state<=LOAD_CAPTURE;
   LOAD_CAPTURE:begin
    if(rx_bad) fail(3);
    else begin
     x<=values_q;x_zero<=values_q[30:0]==0;x_saturated<=values_q[30:0]>=31'h42d00000;y<=second_q;pc<=mode==15?80:(mode==16 || mode==17)?90:mode==18?41:mode==11?40:0;
     if(mode==12) begin index<=0;maximum<=0;pc<=50;end
     state<=EXEC;
    end
   end
   WAIT_FP:if(arithmetic_done) begin
    // Reciprocal of a subnormal Q8 scale and a clipped quant product may
    // overflow intentionally; vector_quant clips these to +/-127.
    if(arithmetic_flags!=0 && !((ret==56 || ret==58) && arithmetic_flags==2)) fail(4);
    else begin v<=arithmetic_result;v_abs_saturated<=arithmetic_result[30:0]>=31'h42fe0000;v_unsigned_saturated<=arithmetic_result>=32'h42fe0000;pc<=ret;state<=EXEC;end
   end
   EXEC:case(pc)
    0:begin
     if(x_saturated) begin e<=0;pc<=20;end
     else issue(1,1);
    end
    1:issue(0,2);
    2:begin n<=integer_trunc(v);state<=ISSUE_TRUNC;end
    3:begin nfloat<=v;issue(1,4);end
    4:issue(0,5);
    5:begin t<=v;issue(1,6);end
    6:issue(0,7);
    7:begin r<=v;p<=32'h39500d01;coefficient<=0;pc<=8;end
    8:issue(1,9);
    9:issue(0,10);
    10:begin
     p<=v;
     if(coefficient==6) pc<=11;
     else begin coefficient<=coefficient+1'b1;pc<=8;end
    end
    11:begin
     if(n < -126) issue(1,12);
     else issue(1,13);
    end
    12:issue(1,13);
    13:begin e<=v;pc<=20;end
    20:issue(0,21);
    21:if(x[31] && !x_zero) issue(4,22);else issue(4,23);
    22:issue(1,23);
    23:if(mode==13) issue(1,24);else state<=SAVE;
    24:state<=SAVE;
    40:issue(1,24);
    41:issue(0,24);
    // Sequential FP32 accumulation exactly preserves the software sum order.
    80:issue(1,81);
    81:issue(0,82);
    82:begin
     rms_sum<=v;rms_count<=rms_count+1'b1;
     if(index==31) state<=RMS_TILE_END;
     else begin index<=index+1'b1;state<=LOAD;end
    end
    83:issue(4,84);
    84:issue(0,85); // epsilon = binary32 1e-6
    85:begin sqrt_start<=1;state<=WAIT_SQRT;end
    86:issue(4,87);
    87:begin rms_factor<=v;rms_valid<=1;state<=FINISH;end
    90:issue(1,91);
    91:issue(1,24);
    // Q8 max is taken from the FP32 values, not the rounded FP16 scale.
    50:state<=MAX_READ;
    51:issue(4,52);
    52:begin d<=v;d_zero<=v[30:0]==0;half_arg<=v;half_start<=1;state<=WAIT_HALF;end
    53:begin
     if(scale_nonfinite) fail(5);
     else if(d_zero) begin inverse<=0;inverse_zero<=1;inverse_nonfinite<=0;state<=QREAD;end
     else issue(4,56);
    end
    56:begin inverse<=v;inverse_zero<=v[30:0]==0;inverse_nonfinite<=v[30:23]==255;state<=QREAD;end
    57:begin
     if(inverse_zero || x_zero) begin quant_hold<=0;state<=QWRITE;end
     else if(inverse_nonfinite) begin quant_hold<=x[31]?-8'sd127:8'sd127;state<=QWRITE;end
     else issue(1,58);
    end
    58:begin
     t<=v;
     if(v_abs_saturated) begin quant_hold<=v[31]?-8'sd127:8'sd127;state<=QWRITE;end
     else issue(0,59);
    end
    59:begin
     qmag=v_unsigned_saturated ? 32'd127 : integer_trunc(v);
     quant_hold<=t[31]?(~qmag[7:0]+8'd1):qmag[7:0];state<=QWRITE;
    end
    default:fail(1);
   endcase
   RMS_TILE_END:begin
    // rms_count already includes this element; separate validation from issue.
    if(rms_control[1]) begin
     if(rms_count!=rms_length) fail(1);
     else state<=ISSUE_RMS_LENGTH;
    end else if(rms_count>=rms_length) fail(1);
    else state<=FINISH;
   end
   ISSUE_RMS_LENGTH:issue(2,83);
   ISSUE_TRUNC:issue(2,3);
   WAIT_HALF:if(half_done) begin scale<=half_result;scale_nonfinite<=half_result[14:10]==31;pc<=53;state<=EXEC;end
   WAIT_SQRT:if(sqrt_done) begin
    if(sqrt_flags!=0) fail(4);
    else begin v<=sqrt_result;v_abs_saturated<=sqrt_result[30:0]>=31'h42fe0000;v_unsigned_saturated<=sqrt_result>=32'h42fe0000;pc<=86;state<=EXEC;end
   end
   SAVE:begin
    // Single RAM write occurs in the dedicated memory process above.
    if(index==31) begin
     index<=0;
     if(mode==13 || mode==16) begin pc<=50;maximum<=0;state<=EXEC;end
     else begin valid<=1;state<=FINISH;end
    end else begin index<=index+1'b1;state<=LOAD;end
   end
   MAX_READ:begin
    if(values_q[30:0]>maximum[30:0]) maximum<={1'b0,values_q[30:0]};
    if(index==31) begin index<=0;pc<=51;end
    else begin index<=index+1'b1;pc<=50;end
    state<=EXEC;
   end
   QREAD:state<=QWAIT;
   QWAIT:begin x<=values_q;x_zero<=values_q[30:0]==0;x_saturated<=values_q[30:0]>=31'h42d00000;pc<=57;state<=EXEC;end
   QWRITE:begin quantized[index]<=quant_hold_guarded;state<=QSAVE;end
   QSAVE:if(index==31) begin valid<=1;state<=FINISH;end
    else begin index<=index+1'b1;state<=QREAD;end
   OUT_PREP:begin
    output_hold<=0;
    if(packed) begin
     if(out_index==0) begin
      output_hold[15:0]<=scale_output_held;
      for(j=0;j<30;j=j+1) output_hold[16+j*8+:8]<=quantized_packed_held[j*8+:8];
     end else output_hold[15:0]<=quantized_packed_held[255:240];
     state<=OUT;
    end else begin out_lane<=0;state<=OUT_READ;end
   end
   OUT_READ:state<=OUT_PACK;
   OUT_PACK:begin
    output_hold[out_lane*32+:32]<=values_q;
    if(out_lane==7) state<=OUT;
    else begin out_lane<=out_lane+1'b1;state<=OUT_READ;end
   end
   OUT:if(result_ready) begin
    if(out_index==(packed?1:3)) state<=FINISH;
    else begin out_index<=out_index+1'b1;state<=OUT_PREP;end
   end
   FINISH:begin done<=1;state<=IDLE;end
   default:state<=IDLE;
  endcase
 end
endmodule
