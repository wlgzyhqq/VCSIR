// CPU50MHz -> UI100MHz held command/result mailboxes. A command contains one
// 1..8-output-channel convolution group. Shared DDR buffers are uncached.
module yolo_cnn #(parameter WATCHDOG_BITS=24,MAC_LANES=8,COMPUTE_HZ=90000000)(input clk,rst,input [31:0] cpu_addr,cpu_wdata,input [3:0] cpu_wstrb,input cpu_we,
 output cpu_write_ok,output reg [31:0] cpu_rdata,input ui_clk,ui_rst,input [2:0] arb_fault,
 output [27:0] araddr,awaddr,output [3:0] len,output arvalid,awvalid,input arready,awready,rvalid,wready,
 input [255:0] rdata,output [255:0] wdata,output [31:0] wstrb);
 reg [31:0] config_shadow[0:13],cmd_hold[0:13],config_ui[0:13];
 reg request,ack,ack_seen,request_seen,completed;reg [31:0] rejected;
 (* ASYNC_REG="TRUE" *)reg req_meta,req_sync,ack_meta,ack_sync;
 reg [31:0] result_cycles_hold,result_reads_hold,result_writes_hold,result_error_hold;
 reg [31:0] status_cycles,status_reads,status_writes,status_error;
 wire busy=request!=ack_seen;wire [7:0] offset=cpu_addr[7:0];
 wire selected=cpu_addr[31:8]==24'h800040;
 wire config_address=offset>=8'h0c && offset<=8'h40 && offset[1:0]==0;
 assign cpu_write_ok=selected && cpu_wstrb==15 && !busy &&
  (config_address || (offset==8'h08 && cpu_wdata==1));
 always @*begin
  cpu_rdata=0;
  if(!selected)cpu_rdata=0;
  else if(config_address)cpu_rdata=config_shadow[(offset-12)>>2];
  else case(offset)
   0:cpu_rdata=32'h59434e31;
   4:cpu_rdata={28'b0,(rejected!=0),(status_error!=0),completed,busy};
   8'h44:cpu_rdata=status_cycles;
   8'h48:cpu_rdata=status_reads;
   8'h4c:cpu_rdata=status_writes;
   8'h50:cpu_rdata=status_error;
   8'h54:cpu_rdata=rejected;
   8'h58:cpu_rdata=MAC_LANES*8;
   8'h5c:cpu_rdata=COMPUTE_HZ;
   default:begin end
  endcase
 end
 integer i;
 always @(posedge clk)begin
  if(rst)begin
   request<=0;ack_seen<=0;ack_meta<=0;ack_sync<=0;completed<=0;rejected<=0;
   status_cycles<=0;status_reads<=0;status_writes<=0;status_error<=0;
   for(i=0;i<14;i=i+1)begin config_shadow[i]<=0;cmd_hold[i]<=0;end
  end else begin
   ack_meta<=ack;ack_sync<=ack_meta;
   if(ack_sync!=ack_seen)begin
    status_cycles<=result_cycles_hold;status_reads<=result_reads_hold;
    status_writes<=result_writes_hold;status_error<=result_error_hold;completed<=1;ack_seen<=ack_sync;
   end
   if(cpu_we)begin
    if(!cpu_write_ok)rejected<=rejected+1'b1;
    else if(config_address)config_shadow[(offset-12)>>2]<=cpu_wdata;
    else begin for(i=0;i<14;i=i+1)cmd_hold[i]<=config_shadow[i];request<=!request;completed<=0;status_error<=0;end
   end
  end
 end
 reg [1:0] state;reg core_start;wire core_busy,core_done;wire [7:0] core_error;
 wire [31:0] core_cycles,core_reads,core_writes;
 integer j;
 always @(posedge ui_clk)begin
  if(ui_rst)begin
   req_meta<=0;req_sync<=0;request_seen<=0;ack<=0;state<=0;core_start<=0;
   result_cycles_hold<=0;result_reads_hold<=0;result_writes_hold<=0;result_error_hold<=0;
   for(j=0;j<14;j=j+1)config_ui[j]<=0;
  end else begin
   req_meta<=request;req_sync<=req_meta;core_start<=0;
   case(state)
    0:if(req_sync!=request_seen)begin
     for(j=0;j<14;j=j+1)config_ui[j]<=cmd_hold[j];request_seen<=req_sync;state<=1;
    end
    1:begin
     if((config_ui[7]&32'hfe00fe00)!=0 || (config_ui[8]&32'hfff0fc00)!=0 ||
        (config_ui[9]&32'hfe00fe00)!=0 || (config_ui[10]&32'hf0fcfcf0)!=0 || (config_ui[11]&32'hfffff000)!=0)begin
      result_cycles_hold<=0;result_reads_hold<=0;result_writes_hold<=0;result_error_hold<=16;ack<=request_seen;state<=0;
     end else begin core_start<=1;state<=2;end
    end
    2:if(core_done)begin
     result_cycles_hold<=core_cycles;result_reads_hold<=core_reads;
     result_writes_hold<=core_writes;result_error_hold<={24'b0,core_error};ack<=request_seen;state<=0;
    end
    default:state<=0;
   endcase
  end
 end
 yolo_conv #(.WATCHDOG_BITS(WATCHDOG_BITS),.MAC_LANES(MAC_LANES)) conv(.clk(ui_clk),.rst(ui_rst),.start(core_start),.arb_fault(arb_fault),
 .input_base(config_ui[0]),.output_base(config_ui[1]),.weight_base(config_ui[2]),
 .bias_base(config_ui[3]),.mult_base(config_ui[4]),.shift_base(config_ui[5]),.lut_base(config_ui[6]),
 .width(config_ui[7][8:0]),.height(config_ui[7][24:16]),.channels(config_ui[8][9:0]),.output_channels(config_ui[8][19:16]),
 .out_width(config_ui[9][8:0]),.out_height(config_ui[9][24:16]),
 .kernel(config_ui[10][3:0]),.stride(config_ui[10][9:8]),.padding(config_ui[10][17:16]),
 .silu(config_ui[10][24]),.out16(config_ui[10][25]),.cache_use(config_ui[10][26]),.cache_load(config_ui[10][27]),.weight_stride(config_ui[11][11:0]),
 .input_plane(config_ui[12]),.output_plane(config_ui[13]),
 .busy(core_busy),.done(core_done),.error(core_error),.cycles(core_cycles),.read_bytes(core_reads),.write_bytes(core_writes),
 .araddr(araddr),.awaddr(awaddr),.len(len),.arvalid(arvalid),.awvalid(awvalid),.arready(arready),.awready(awready),.rvalid(rvalid),.wready(wready),
 .rdata(rdata),.wdata(wdata),.wstrb(wstrb));
endmodule
