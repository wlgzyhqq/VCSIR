// One outstanding native-DDR burst. Both clocks must be reset together.
// Payload RAMs are owned by one side until the synchronized mailbox returns.
// Native writes have no WVALID: the requester holds each word until WREADY.
// The last source WREADY is delayed until the DDR accepted the final word.
module yolo_burst_cdc #(parameter WATCHDOG_BITS=24)(
 input s_clk,s_rst,d_clk,d_rst,input [2:0] d_fault,
 input [27:0] s_araddr,s_awaddr,input [3:0] s_len,
 input s_arvalid,s_awvalid,input [255:0] s_wdata,input [31:0] s_wstrb,
 output s_arready,s_awready,s_wready,output reg s_rvalid,
 output reg [255:0] s_rdata,output fault,
 output [27:0] d_araddr,d_awaddr,output [3:0] d_len,
 output d_arvalid,d_awvalid,output [255:0] d_wdata,output [31:0] d_wstrb,
 input d_arready,d_awready,d_wready,d_rvalid,input [255:0] d_rdata);
 localparam S_IDLE=0,S_WCOLLECT=1,S_WAIT=2,S_RPRIME=3,S_READ=4,S_WACK=5;
 reg [2:0] ss;
 reg [27:0] addr_hold;reg [3:0] len_hold;reg write_hold,request;
 reg [3:0] si;
 reg [255:0] read_ram[0:15] /* synthesis syn_ramstyle="block_ram" */;
 reg [287:0] write_ram[0:15] /* synthesis syn_ramstyle="block_ram" */;
 reg [255:0] read_q;reg [287:0] write_q;
 (* ASYNC_REG="TRUE" *) reg ack_meta,ack_sync,fault_meta,fault_sync;
 reg acknowledge,d_failed;
 assign fault=fault_sync;
 assign s_awready=ss==S_IDLE&&!fault_sync;
 assign s_arready=ss==S_IDLE&&!s_awvalid&&!fault_sync;
 assign s_wready=!fault_sync&&((ss==S_WCOLLECT&&si!=len_hold)||ss==S_WACK);
 always @(posedge s_clk) begin
  read_q<=read_ram[si];
  if(!s_rst&&!fault_sync&&ss==S_WCOLLECT)write_ram[si]<={s_wstrb,s_wdata};
 end
 always @(posedge s_clk) begin
  if(s_rst)begin ss<=S_IDLE;si<=0;addr_hold<=0;len_hold<=0;write_hold<=0;request<=0;
   ack_meta<=0;ack_sync<=0;fault_meta<=0;fault_sync<=0;s_rvalid<=0;s_rdata<=0;end
  else begin
   ack_meta<=acknowledge;ack_sync<=ack_meta;fault_meta<=d_failed;fault_sync<=fault_meta;s_rvalid<=0;
   if(!fault_sync)case(ss)
    S_IDLE:if(s_awvalid)begin addr_hold<=s_awaddr;len_hold<=s_len;write_hold<=1;si<=0;ss<=S_WCOLLECT;end
     else if(s_arvalid)begin addr_hold<=s_araddr;len_hold<=s_len;write_hold<=0;si<=0;request<=!request;ss<=S_WAIT;end
    S_WCOLLECT:if(si==len_hold)begin request<=!request;ss<=S_WAIT;end else si<=si+1'b1;
    S_WAIT:if(ack_sync==request)begin si<=0;ss<=write_hold?S_WACK:S_RPRIME;end
    S_RPRIME:ss<=S_READ;
    S_READ:begin s_rdata<=read_q;s_rvalid<=1;
     if(si==len_hold)ss<=S_IDLE;
     else begin si<=si+1'b1;ss<=S_RPRIME;end
    end
    S_WACK:ss<=S_IDLE;
    default:ss<=S_IDLE;
   endcase
  end
 end
 localparam D_IDLE=0,D_ISSUE=1,D_READ=2,D_WPRIME=3,D_WRITE=4,D_WLOAD=5;
 reg [2:0] ds;reg [27:0] address_d;reg [3:0] length_d,di;reg write_d;
 (* ASYNC_REG="TRUE" *) reg req_meta,req_sync;
 reg [WATCHDOG_BITS-1:0] watchdog;
 assign d_araddr=address_d;assign d_awaddr=address_d;assign d_len=length_d;
 assign d_arvalid=ds==D_ISSUE&&!write_d&&!d_failed;
 assign d_awvalid=ds==D_ISSUE&&write_d&&!d_failed;
 assign d_wdata=write_q[255:0];assign d_wstrb=write_q[287:256];
 always @(posedge d_clk)begin
  // Native DDR has no WVALID, so every accepted word must be followed by
  // the next word immediately. Synchronous RAM lookahead also holds on stalls.
  write_q<=write_ram[(ds==D_WRITE&&d_wready)?(di+4'd1):di];
  if(!d_rst&&!d_failed&&ds==D_READ&&d_rvalid)read_ram[di]<=d_rdata;
 end
 always @(posedge d_clk)begin
  if(d_rst)begin ds<=D_IDLE;di<=0;address_d<=0;length_d<=0;write_d<=0;req_meta<=0;req_sync<=0;
   acknowledge<=0;d_failed<=0;watchdog<=0;end
  else begin
   req_meta<=request;req_sync<=req_meta;
   if(ds==D_IDLE)watchdog<=0;else watchdog<=watchdog+1'b1;
   if(d_fault!=0||(ds!=D_IDLE&&(&watchdog)))d_failed<=1;
   if(!d_failed&&d_fault==0)case(ds)
    D_IDLE:if(req_sync!=acknowledge)begin address_d<=addr_hold;length_d<=len_hold;write_d<=write_hold;di<=0;ds<=D_ISSUE;end
    D_ISSUE:if(write_d?d_awready:d_arready)ds<=write_d?D_WRITE:D_READ;
    D_READ:if(d_rvalid)begin if(di==length_d)begin acknowledge<=req_sync;ds<=D_IDLE;end else di<=di+1'b1;end
    D_WPRIME:ds<=D_WRITE;
    D_WRITE:if(d_wready)begin if(di==length_d)begin acknowledge<=req_sync;ds<=D_IDLE;end
      else di<=di+1'b1;end
    D_WLOAD:ds<=D_WRITE;
    default:ds<=D_IDLE;
   endcase
  end
 end
endmodule
