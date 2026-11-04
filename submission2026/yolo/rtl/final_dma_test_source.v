// Explicit diagnostic producer/consumer, not a model accelerator. Constant
// result words 66770000..66770007 repeat each beat. Valid/ready every fourth UI
// cycle tests producer gaps and consumer backpressure through the real ports.
module final_dma_test_source(input clk,rst,input [1:0] enable,input result_ready,
 output reg result_valid,output [255:0] result_data,output stream_ready);
 reg [1:0] divider;
 always @(posedge clk or posedge rst) if(rst) divider<=0;else divider<=divider+1'b1;
 always @(posedge clk or posedge rst)
 if(rst) result_valid<=0;
 else if(!enable[0]) result_valid<=0;
 else if(result_valid && result_ready) result_valid<=0;
 else if(divider==0) result_valid<=1;
 assign result_data=256'h6677000766770006667700056677000466770003667700026677000166770000;
 assign stream_ready=!enable[1] || divider==0;
endmodule
