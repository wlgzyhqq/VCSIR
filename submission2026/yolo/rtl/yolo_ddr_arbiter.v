// HMIC_S native controller: one transaction outstanding; no RREADY/BRESP.
// Four masters: CPU, storage DMA, video read, CNN. Video has deadline priority;
// all accepted bursts remain atomic (at most16 beats =512 bytes).
module yolo_ddr_arbiter #(parameter WATCHDOG_BITS=24)(input clk,rst,
 input [111:0] m_awaddr,m_araddr,input [15:0] m_len,
 input [3:0] m_awvalid,m_arvalid,output [3:0] m_awready,m_arready,m_wready,m_rvalid,
 input [1023:0] m_wdata,input [127:0] m_wstrb,output [1023:0] m_rdata,
 output reg [2:0] fault,output [31:0] cpu_grants,dma_grants,output reg [31:0] cpu_wait_max,
 output [27:0] h_awaddr,h_araddr,output [3:0] h_awlen,h_arlen,
 output h_awvalid,h_arvalid,input h_awready,h_arready,h_wready,h_rvalid,h_rlast,h_wlast,
 output [255:0] h_wdata,output [31:0] h_wstrb,input [255:0] h_rdata);
 localparam IDLE=0,ADDR=1,DATA=2,LOCKED=3;
 reg [1:0] state,owner,turn;reg writing;reg [3:0] remaining;
 reg [WATCHDOG_BITS-1:0] watchdog;reg [31:0] grants[0:3];reg [23:0] cpu_wait;
 wire [3:0] requests=m_awvalid|m_arvalid;
 reg [1:0] selected;reg found;integer i;reg [1:0] candidate;
 always @*begin
  selected=turn;found=0;candidate=0;
  if(requests[2])begin selected=2;found=1;end
  else for(i=0;i<4;i=i+1)begin
   candidate=turn+i;
   if(!found && requests[candidate])begin selected=candidate;found=1;end
  end
 end
 assign h_awaddr=m_awaddr[owner*28+:28];assign h_araddr=m_araddr[owner*28+:28];
 assign h_awlen=m_len[owner*4+:4];assign h_arlen=m_len[owner*4+:4];
 assign h_awvalid=state==ADDR && writing && !fault;
 assign h_arvalid=state==ADDR && !writing && !fault;
 assign h_wdata=m_wdata[owner*256+:256];assign h_wstrb=m_wstrb[owner*32+:32];
 wire accepted=state==ADDR && (writing?h_awready:h_arready);
 wire data_window=(state==DATA || accepted) && !fault;
 wire beat=data_window && (writing?h_wready:h_rvalid);
 // Registered read return breaks DDR PHY -> consumer reduction/mux paths.
 // HMIC has no RREADY: every beat is delivered exactly one cycle later,
 // including back-to-back beats and the previous owner's last beat while a
 // following address is being selected. Owner is pipelined with the data.
 reg return_valid;reg [1:0] return_owner;
 (* syn_preserve=1 *) reg [255:0] return_data;
 always @(posedge clk)begin
  if(rst)return_valid<=0;else return_valid<=beat&&!writing;
  if(beat&&!writing)begin return_data<=h_rdata;return_owner<=owner;end
 end
 genvar g;
 generate for(g=0;g<4;g=g+1)begin:route
  assign m_awready[g]=h_awvalid && owner==g && h_awready;
  assign m_arready[g]=h_arvalid && owner==g && h_arready;
  assign m_wready[g]=data_window && writing && owner==g && h_wready;
  assign m_rvalid[g]=return_valid && return_owner==g && !fault;
  assign m_rdata[g*256+:256]=return_data;
 end endgenerate
 assign cpu_grants=grants[0];assign dma_grants=grants[1];
 integer k;
 always @(posedge clk or posedge rst)
 if(rst)begin
  state<=IDLE;owner<=0;turn<=0;writing<=0;remaining<=0;watchdog<=0;fault<=0;cpu_wait<=0;cpu_wait_max<=0;
  for(k=0;k<4;k=k+1)grants[k]<=0;
 end else begin
  if(!requests[0] || (state!=IDLE && owner==0))cpu_wait<=0;
  else if(!(&cpu_wait))cpu_wait<=cpu_wait+1'b1;
  if(state==IDLE)watchdog<=0;else if(state!=LOCKED)watchdog<=watchdog+1'b1;
  case(state)
   IDLE:if(found)begin
    owner<=selected;writing<=m_awvalid[selected];remaining<=m_len[selected*4+:4];state<=ADDR;
    // Independent constant-index increments avoid a four-way counter-data
    // mux before a32-bit carry chain on the request arbitration path.
    for(k=0;k<4;k=k+1)if(selected==k)grants[k]<=grants[k]+1'b1;
    if(selected==0 && cpu_wait>cpu_wait_max)cpu_wait_max<=cpu_wait;
   end
   ADDR:if(accepted)state<=DATA;
   LOCKED:state<=LOCKED;
   default:begin end
  endcase
  if(beat)begin
   if((writing?h_wlast:h_rlast)!=(remaining==0))begin fault<=writing?2:3;state<=LOCKED;end
   else if(remaining==0)begin state<=IDLE;turn<=owner+1'b1;end
   else remaining<=remaining-1'b1;
  end
  if(state!=IDLE && state!=LOCKED && &watchdog)begin fault<=1;state<=LOCKED;end
 end
endmodule
