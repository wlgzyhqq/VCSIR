// Finite FP32 -> FP16, RNE. Sequential significand shift avoids a long barrel
// shift/exponent/rounding path. Preserves signed zero and subnormal halves.
module final_fp16_pack(input clk,rst,start,input [31:0] a,
 output reg done,output reg [15:0] result);
 localparam IDLE=0,DECODE=1,SHIFT=2,ROUND=3,END=4;
 reg [2:0] state;reg [31:0] av;reg [23:0] mantissa;
 reg [4:0] count,exponent;reg guard,sticky;
 wire [14:0] rounded={exponent,mantissa[9:0]}+(guard && (sticky || mantissa[0]));
 always @(posedge clk or posedge rst)
 if(rst) begin state<=IDLE;av<=0;mantissa<=0;count<=0;exponent<=0;guard<=0;sticky<=0;done<=0;result<=0;end
 else begin
  done<=0;
  case(state)
   IDLE:if(start) begin av<=a;state<=DECODE;end
   DECODE:begin
    if(av[30:23]>142) begin result<={av[31],15'h7c00};state<=END;end
    else if(av[30:23]<102) begin result<={av[31],15'b0};state<=END;end
    else begin
     mantissa<={1'b1,av[22:0]};guard<=0;sticky<=0;
     if(av[30:23]>=113) begin exponent<=av[30:23]-8'd112;count<=13;end
     else begin exponent<=0;count<=8'd126-av[30:23];end
     state<=SHIFT;
    end
   end
   SHIFT:begin
    mantissa<=mantissa>>1;sticky<=sticky|guard;guard<=mantissa[0];
    if(count==1) state<=ROUND;else count<=count-1'b1;
   end
   ROUND:begin result<={av[31],rounded};state<=END;end
   END:begin done<=1;state<=IDLE;end
   default:state<=IDLE;
  endcase
 end
endmodule
