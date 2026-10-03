// Configuration-time program constants, not a CPU-addressable main memory.
// Copy image to external DDR and read back every line before releasing the CPU.
module final_ddr_boot(input clk,rst,input memory_ready,
 output req_valid,input req_ready,output req_write,output [29:0] req_addr,
 output [255:0] req_data,output [31:0] req_strb,
 input rsp_valid,output rsp_ready,input [255:0] rsp_data,input rsp_error,
 output reg done,output reg fault);
 `include "C:/Users/33791/Desktop/project/learn verilog/FINAL/firmware/boot_image.vh"
 reg [2:0] state;
 reg [15:0] line_index;
 localparam WAIT=0,WRITE=1,WRITE_WAIT=2,READ=3,READ_WAIT=4,FINISHED=5;
 assign req_valid=(state==WRITE || state==READ) && !fault;
 assign req_write=state==WRITE;
 assign req_addr={9'b0,line_index,5'b0};
 assign req_data=boot_line(line_index);
 assign req_strb=32'hffffffff;
 assign rsp_ready=state==WRITE_WAIT || state==READ_WAIT;
 always @(posedge clk or posedge rst)
 if(rst) begin state<=WAIT;line_index<=0;done<=0;fault<=0;end
 else if(state!=WAIT && !memory_ready) begin done<=0;fault<=1;end
 else if(!fault) case(state)
  WAIT:if(memory_ready) state<=WRITE;
  WRITE:if(req_ready) state<=WRITE_WAIT;
  WRITE_WAIT:if(rsp_valid) begin
   if(rsp_error) fault<=1;else state<=READ;
  end
  READ:if(req_ready) state<=READ_WAIT;
  READ_WAIT:if(rsp_valid) begin
   if(rsp_error || rsp_data!=boot_line(line_index)) fault<=1;
   else if(line_index==BOOT_LINES-1) begin done<=1;state<=FINISHED;end
   else begin line_index<=line_index+1'b1;state<=WRITE;end
  end
  default:state<=FINISHED;
 endcase
endmodule
