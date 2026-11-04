// Stage0 only is embedded. Main firmware is verified in uncached staging DDR
// by stage0, then this controller copies it with the CPU and caches in reset.
module final_ddr_boot(input clk,rst,input memory_ready,
 input handoff_request,bus_quiet,input [31:0] handoff_bytes,
 output reg main_booted,output [31:0] copied_bytes,
 output req_valid,input req_ready,output req_write,output [29:0] req_addr,
 output [255:0] req_data,output [31:0] req_strb,
 input rsp_valid,output rsp_ready,input [255:0] rsp_data,input rsp_error,
 output reg done,output reg fault);
 `include "rtl/tf_boot_config.vh"
 localparam WAIT=0,LOAD_WAIT=1,LOAD_CAPTURE=2,WRITE=3,WRITE_WAIT=4,
  READ=5,READ_WAIT=6,CHECK_READ=7,RUN=8,SOURCE=9,SOURCE_WAIT=10;
 reg [3:0] state;reg [15:0] line_index,line_count;
 reg [8:0] readback_bad;reg [2:0] word_index;
 reg [255:0] line_data;wire [31:0] prefix_word;
 reg [24:0] watchdog;
 final_boot_prefix u_prefix(.clk(clk),.addr({line_index[5:0],word_index}),
  .bank(line_index[10:6]),.data(prefix_word));
 assign copied_bytes={11'b0,line_index,5'b0};
 assign req_valid=(state==WRITE || state==READ || state==SOURCE) && !fault;
 assign req_write=state==WRITE;
 assign req_addr=(state==SOURCE?30'h03d00000:(main_booted?30'b0:30'h03c00000))+{9'b0,line_index,5'b0};
 assign req_data=line_data;assign req_strb=32'hffffffff;
 assign rsp_ready=state==WRITE_WAIT || state==READ_WAIT || state==SOURCE_WAIT;
 integer part;
 always @(posedge clk or posedge rst)
 if(rst)begin
  state<=WAIT;line_index<=0;line_count<=TF_STAGE0_LINES;word_index<=0;line_data<=0;
  readback_bad<=0;done<=0;fault<=0;main_booted<=0;watchdog<=0;
 end else if(state!=WAIT && !memory_ready)begin done<=0;fault<=1;end
 else if(!fault)begin
  if(state==WAIT || state==RUN)watchdog<=0;
  else watchdog<=watchdog+1'b1;
  if(watchdog==25'd25000000)begin done<=0;fault<=1;end
  else case(state)
   WAIT:if(memory_ready)state<=LOAD_WAIT;
   LOAD_WAIT:state<=LOAD_CAPTURE;
   LOAD_CAPTURE:begin
    line_data[word_index*32+:32]<=prefix_word;
    if(word_index==7)state<=WRITE;
    else begin word_index<=word_index+1'b1;state<=LOAD_WAIT;end
   end
   WRITE:if(req_ready)state<=WRITE_WAIT;
   WRITE_WAIT:if(rsp_valid)begin if(rsp_error)begin fault<=1;done<=0;end else state<=READ;end
   READ:if(req_ready)state<=READ_WAIT;
   READ_WAIT:if(rsp_valid)begin
    readback_bad[8]<=rsp_error;
    for(part=0;part<8;part=part+1)readback_bad[part]<=rsp_data[part*32+:32]!=line_data[part*32+:32];
    state<=CHECK_READ;
   end
   CHECK_READ:if(|readback_bad)begin fault<=1;done<=0;end
    else if(line_index+1'b1==line_count)begin line_index<=line_count;done<=1;state<=RUN;end
    else begin
     line_index<=line_index+1'b1;word_index<=0;state<=main_booted?SOURCE:LOAD_WAIT;
    end
   RUN:if(handoff_request && !main_booted && bus_quiet)begin
    if(handoff_bytes==0 || handoff_bytes>32'h0001e000 || handoff_bytes[4:0]!=0)begin fault<=1;done<=0;end
    else begin
     // Quiescence includes outstanding responses and current AXI valids.
     // Top asserts CPU/cache reset immediately when done falls.
     main_booted<=1;done<=0;line_index<=0;line_count<=handoff_bytes[20:5];state<=SOURCE;
    end
   end
   SOURCE:if(req_ready)state<=SOURCE_WAIT;
   SOURCE_WAIT:if(rsp_valid)begin
    if(rsp_error)begin fault<=1;done<=0;end
    else begin line_data<=rsp_data;state<=WRITE;end
   end
   default:begin fault<=1;done<=0;end
  endcase
 end
endmodule
