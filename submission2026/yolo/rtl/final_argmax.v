// One-pass finite binary32 argmax. Equal values (including signed zeros)
// retain the first index. Errors drain the prescribed stream before done.
module final_argmax(input clk,rst,start,input [31:0] length,
 input stream_valid,output stream_ready,input [255:0] stream_data,input [31:0] stream_keep,
 output reg done,output reg [31:0] error,index);
 reg active,held;reg [255:0] beat;reg [17:0] remaining,position;reg [31:0] maximum;
 reg [3:0] lanes;reg [31:0] expected_keep;
 wire [31:0] value=beat[31:0];
 wire both_zero=(value[30:0]==0 && maximum[30:0]==0);
 wire greater=!both_zero && (value[31]!=maximum[31]?!value[31]:
                value[31]?(value[30:0]<maximum[30:0]):(value[30:0]>maximum[30:0]));
 assign stream_ready=active && !held;
 always @* begin
  if(remaining>=8) expected_keep=32'hffffffff;
  else case(remaining[2:0])
   1:expected_keep=32'h0000000f;2:expected_keep=32'h000000ff;
   3:expected_keep=32'h00000fff;4:expected_keep=32'h0000ffff;
   5:expected_keep=32'h000fffff;6:expected_keep=32'h00ffffff;
   7:expected_keep=32'h0fffffff;default:expected_keep=0;
  endcase
 end
 always @(posedge clk or posedge rst)
 if(rst)begin active<=0;held<=0;beat<=0;remaining<=0;position<=0;maximum<=0;lanes<=0;done<=0;error<=0;index<=0;end
 else begin
  done<=0;
  if(start && !active)begin
   held<=0;remaining<=length;position<=0;maximum<=0;index<=0;error<=0;
   if(length==0 || length>151936)begin error<=1;done<=1;end else active<=1;
  end else if(active)begin
   if(stream_valid && stream_ready)begin
    beat<=stream_data;lanes<=remaining>=8?4'd8:{1'b0,remaining[2:0]};held<=1;
    if(stream_keep!=expected_keep) error<=3;
   end
   if(held)begin
    if(value[30:23]==255)error<=3;
    else if(position==0 || greater)begin maximum<=value;index<=position;end
    beat<=beat>>32;position<=position+1'b1;remaining<=remaining-1'b1;lanes<=lanes-1'b1;
    if(lanes==1)held<=0;
    if(remaining==1)begin active<=0;held<=0;done<=1;end
   end
  end
 end
endmodule
