// One outstanding 32-byte transaction. Bundled-data toggle CDC, 50 -> 100 MHz.
// Request payload is held until response; response payload until the next request.
module final_ddr_bridge(
 input clk,rst,input ddr_clk,input ddr_rst,input init_done,
 input req_valid,output req_ready,input req_write,input [29:0] req_addr,
 input [255:0] req_data,input [31:0] req_strb,
 output reg rsp_valid,input rsp_ready,output reg [255:0] rsp_data,output reg rsp_error,
 output reg ready,
 output [27:0] h_awaddr,output h_awvalid,input h_awready,
 output [255:0] h_wdata,output [31:0] h_wstrb,input h_wready,
 output [27:0] h_araddr,output h_arvalid,input h_arready,
 input [255:0] h_rdata,input h_rvalid
);
 reg req_toggle,req_busy;
 reg [29:0] req_addr_hold;
 reg req_write_hold;
 reg [255:0] req_data_hold;
 reg [31:0] req_strb_hold;
 reg ack_toggle;
 reg [255:0] rsp_data_hold;
 reg rsp_error_hold;
 (* ASYNC_REG="TRUE" *) reg ack_meta,ack_sync,init_meta,init_sync;
 assign req_ready=ready && !req_busy && !rsp_valid;
 always @(posedge clk or posedge rst)
 if(rst) begin
  req_toggle<=0;req_busy<=0;req_addr_hold<=0;req_write_hold<=0;
  req_data_hold<=0;req_strb_hold<=0;rsp_valid<=0;rsp_data<=0;rsp_error<=0;
  ack_meta<=0;ack_sync<=0;init_meta<=0;init_sync<=0;ready<=0;
 end else begin
  ack_meta<=ack_toggle;ack_sync<=ack_meta;
  init_meta<=init_done;init_sync<=init_meta;ready<=init_sync;
  if(rsp_valid && rsp_ready) rsp_valid<=0;
  if(req_valid && req_ready) begin
   req_addr_hold<=req_addr;req_write_hold<=req_write;
   req_data_hold<=req_data;req_strb_hold<=req_strb;
   req_toggle<=~req_toggle;req_busy<=1;
  end
  if(req_busy && ack_sync==req_toggle) begin
   rsp_data<=rsp_data_hold;rsp_error<=rsp_error_hold;
   rsp_valid<=1;req_busy<=0;
  end
 end
 (* ASYNC_REG="TRUE" *) reg req_meta,req_sync;
 reg req_seen;
 reg [2:0] state;
 reg [27:0] native_addr;
 reg [255:0] native_data;
 reg [31:0] native_strb;
 reg [23:0] watchdog;
 localparam IDLE=0,AW=1,WD=2,AR=3,RD=4;
 // HMIC_S addresses are DDR 32-bit word addresses, not byte addresses.
 // Each 256-bit UI beat is one physical BL8 transfer; address column[2:0]=0.
 assign h_awaddr=native_addr;
 assign h_araddr=native_addr;
 assign h_awvalid=state==AW;
 assign h_arvalid=state==AR;
 assign h_wdata=native_data;
 assign h_wstrb=native_strb;
 always @(posedge ddr_clk or posedge ddr_rst)
 if(ddr_rst) begin
  req_meta<=0;req_sync<=0;req_seen<=0;ack_toggle<=0;state<=IDLE;
  native_addr<=0;native_data<=0;native_strb<=0;
  rsp_data_hold<=0;rsp_error_hold<=0;watchdog<=0;
 end else if(!init_done) begin
  req_meta<=0;req_sync<=0;req_seen<=0;ack_toggle<=0;state<=IDLE;watchdog<=0;
 end else begin
  req_meta<=req_toggle;req_sync<=req_meta;
  if(state==IDLE) watchdog<=0;else watchdog<=watchdog+1'b1;
  case(state)
   IDLE: if(req_sync!=req_seen) begin
    req_seen<=req_sync;
    native_addr<={req_addr_hold[29:5],3'b0};
    native_data<=req_data_hold;native_strb<=req_strb_hold;
    rsp_error_hold<=0;
    state<=req_write_hold?AW:AR;
   end
   AW: if(h_awready) begin
    if(h_wready) begin ack_toggle<=req_seen;state<=IDLE;end
    else state<=WD;
   end
   WD: if(h_wready) begin ack_toggle<=req_seen;state<=IDLE;end
   AR: if(h_arready) begin
    if(h_rvalid) begin rsp_data_hold<=h_rdata;ack_toggle<=req_seen;state<=IDLE;end
    else state<=RD;
   end
   RD: if(h_rvalid) begin rsp_data_hold<=h_rdata;ack_toggle<=req_seen;state<=IDLE;end
   5:state<=5;
   default:state<=IDLE;
  endcase
  // Stop issuing after timeout until reset; an old native read must not be
  // misinterpreted as the response to a later command.
  if(state!=IDLE && state!=5 && &watchdog) begin
   rsp_error_hold<=1;ack_toggle<=req_seen;state<=5;
  end
 end
endmodule
