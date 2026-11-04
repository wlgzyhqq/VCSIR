// HMIC_S simplified AXI: no WVALID, RREADY or write response channel.
// One native transaction outstanding. Round robin CPU/DMA, max DMA 16 beats.
// A granted address and its complete data transfer retain ownership.
module final_ddr_arbiter(
 input clk,rst,
 input [27:0] c_awaddr,c_araddr,input c_awvalid,c_arvalid,
 output c_awready,c_arready,c_wready,c_rvalid,
 input [255:0] c_wdata,input [31:0] c_wstrb,output [255:0] c_rdata,
 input [27:0] d_awaddr,d_araddr,input [3:0] d_len,input d_awvalid,d_arvalid,
 output d_awready,d_arready,d_wready,d_rvalid,
 input [255:0] d_wdata,input [31:0] d_wstrb,output [255:0] d_rdata,
 output reg [2:0] fault,
 output reg [31:0] cpu_grants,dma_grants,cpu_wait_max,
 output [27:0] h_awaddr,h_araddr,output [3:0] h_awlen,h_arlen,
 output h_awvalid,h_arvalid,input h_awready,h_arready,h_wready,h_rvalid,h_rlast,h_wlast,
 output [255:0] h_wdata,output [31:0] h_wstrb,input [255:0] h_rdata
);
 localparam IDLE=0,ADDR=1,DATA=2,LOCKED=3;
 reg [1:0] state;
 reg owner,writing,turn;
 reg [3:0] left_beats;
 reg [23:0] watchdog;
 reg [23:0] cpu_wait;
 reg watchdog_carry8,watchdog_carry16,cpu_wait_carry8,cpu_wait_carry16 /* synthesis syn_preserve=1 syn_allow_retiming=0 */;
 wire addr_fire=(writing?h_awready:h_arready) && state==ADDR;
 wire data_window=(state==DATA || addr_fire) && fault==0;
 wire data_fire=data_window && (writing?h_wready:h_rvalid);
 assign h_awaddr=owner?d_awaddr:c_awaddr;
 assign h_araddr=owner?d_araddr:c_araddr;
 assign h_awlen=owner?d_len:4'b0;
 assign h_arlen=owner?d_len:4'b0;
 assign h_awvalid=state==ADDR && writing && fault==0;
 assign h_arvalid=state==ADDR && !writing && fault==0;
 assign h_wdata=owner?d_wdata:c_wdata;
 assign h_wstrb=owner?d_wstrb:c_wstrb;
 assign c_awready=h_awvalid && !owner && h_awready;
 assign d_awready=h_awvalid && owner && h_awready;
 assign c_arready=h_arvalid && !owner && h_arready;
 assign d_arready=h_arvalid && owner && h_arready;
 assign c_wready=data_window && writing && !owner && h_wready;
 assign d_wready=data_window && writing && owner && h_wready;
 assign c_rvalid=data_window && !writing && !owner && h_rvalid;
 assign d_rvalid=data_window && !writing && owner && h_rvalid;
 assign c_rdata=h_rdata;
 assign d_rdata=h_rdata;
 wire c_req=c_awvalid || c_arvalid;
 wire d_req=d_awvalid || d_arvalid;
 wire choose_d=d_req && (!c_req || turn);
 always @(posedge clk or posedge rst)
 if(rst) begin state<=IDLE;owner<=0;writing<=0;turn<=0;left_beats<=0;watchdog<=0;watchdog_carry8<=0;watchdog_carry16<=0;fault<=0;
  cpu_grants<=0;dma_grants<=0;cpu_wait_max<=0;cpu_wait<=0;cpu_wait_carry8<=0;cpu_wait_carry16<=0;end
 else begin
  if(!c_req || (state!=IDLE && !owner))begin cpu_wait<=0;cpu_wait_carry8<=0;cpu_wait_carry16<=0;end
  else if(!(&cpu_wait))begin
   cpu_wait[7:0]<=cpu_wait[7:0]+8'd1;
   cpu_wait[15:8]<=cpu_wait[15:8]+{7'b0,cpu_wait_carry8};
   cpu_wait[23:16]<=cpu_wait[23:16]+{7'b0,cpu_wait_carry16};
   cpu_wait_carry8<=cpu_wait[7:0]==8'hfe;cpu_wait_carry16<=cpu_wait[15:0]==16'hfffe;
  end
  if(state==IDLE)begin watchdog<=0;watchdog_carry8<=0;watchdog_carry16<=0;end
  else if(state!=LOCKED)begin
   watchdog[7:0]<=watchdog[7:0]+8'd1;
   watchdog[15:8]<=watchdog[15:8]+{7'b0,watchdog_carry8};
   watchdog[23:16]<=watchdog[23:16]+{7'b0,watchdog_carry16};
   watchdog_carry8<=watchdog[7:0]==8'hfe;watchdog_carry16<=watchdog[15:0]==16'hfffe;
  end
  case(state)
   IDLE:if(c_req || d_req) begin
    owner<=choose_d;writing<=choose_d?d_awvalid:c_awvalid;
    left_beats<=choose_d?d_len:0;state<=ADDR;
    if(choose_d) dma_grants<=dma_grants+1'b1;
    else begin cpu_grants<=cpu_grants+1'b1;if(cpu_wait>cpu_wait_max) cpu_wait_max<=cpu_wait;end
   end
   ADDR:if(addr_fire) state<=DATA;
   LOCKED:state<=LOCKED;
   default:begin end
  endcase
  if(data_fire) begin
   // Last flags belong to this transfer, not a software inferred completion.
   if((writing?h_wlast:h_rlast)!=(left_beats==0)) begin
    fault<=writing?3'd2:3'd3;state<=LOCKED;
   end else if(left_beats==0) begin state<=IDLE;turn<=!owner;end
   else left_beats<=left_beats-1'b1;
  end
  // Controller has no cancellation/backpressure. Quarantine after timeout;
  // late beats must never become the next transaction's response. Reset only.
  if(state!=IDLE && state!=LOCKED && &watchdog) begin fault<=1;state<=LOCKED;end
 end
endmodule
