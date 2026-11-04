// Frozen acc32 * positive multiplier32; signed ties-even shift, saturation.
// Five short stages separate multiplication, abs, shifts, comparison and
// final16-bit saturation. SiLU lookup follows this module.
module yolo_requant(input clk,rst,valid,input signed [31:0] accumulator,
 input [30:0] multiplier,input [5:0] shift,input out16,
 output reg ready,output reg signed [15:0] value);
 reg signed [63:0] product;
 reg [63:0] magnitude,quotient,remainder,half;
 reg [5:0] amount0,amount1;reg [3:0] valid_pipe;
 reg wide0,wide1,wide2,wide3,negative1,negative2,negative3,shifted;
 reg [15:0] quotient_low;reg overflow,increment;
 wire [16:0] rounded={1'b0,quotient_low}+increment;
 wire [16:0] limit=wide3?(negative3?17'd32768:17'd32767):(negative3?17'd128:17'd127);
 wire [15:0] clipped=(overflow || rounded>limit)?limit[15:0]:rounded[15:0];
 always @(posedge clk)begin
  if(rst)begin
   valid_pipe<=0;ready<=0;value<=0;
   product<=0;magnitude<=0;quotient<=0;remainder<=0;half<=0;amount0<=0;amount1<=0;
   wide0<=0;wide1<=0;wide2<=0;wide3<=0;negative1<=0;negative2<=0;negative3<=0;shifted<=0;
   quotient_low<=0;overflow<=0;increment<=0;
  end
  else begin
   valid_pipe<={valid_pipe[2:0],valid};ready<=valid_pipe[3];
   if(valid)begin product<=accumulator*$signed({1'b0,multiplier});amount0<=shift;wide0<=out16;end
   if(valid_pipe[0])begin
    magnitude<=product[63]?(~product+64'd1):product;
    negative1<=product[63];amount1<=amount0;wide1<=wide0;
   end
   if(valid_pipe[1])begin
    quotient<=magnitude>>amount1;
    remainder<=magnitude&((64'd1<<amount1)-1'b1);
    half<=amount1==0?0:(64'd1<<(amount1-1'b1));shifted<=amount1!=0;
    negative2<=negative1;wide2<=wide1;
   end
   if(valid_pipe[2])begin
    increment<=shifted&&((remainder>half)||((remainder==half)&&quotient[0]));
    quotient_low<=quotient[15:0];overflow<=|quotient[63:16];negative3<=negative2;wide3<=wide2;
   end
   if(valid_pipe[3])value<=negative3?-$signed(clipped):$signed(clipped);
  end
 end
endmodule
