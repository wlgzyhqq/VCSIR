module cpu_validation_diag(input clk,rst,input [223:0] core_debug,input [31:0] read_addr,write_addr,write_data,input write_en,output reg [31:0] read_data,output reg warm_reset,output reg delay_mode,
input  axi_i_awready,
input  axi_i_wready,
input  axi_i_bvalid,
input [1:0] axi_i_bresp,
input [3:0] axi_i_bid,
input  axi_i_arready,
input  axi_i_rvalid,
input [31:0] axi_i_rdata,
input [1:0] axi_i_rresp,
input [3:0] axi_i_rid,
input  axi_i_rlast,
input  axi_d_awready,
input  axi_d_wready,
input  axi_d_bvalid,
input [1:0] axi_d_bresp,
input [3:0] axi_d_bid,
input  axi_d_arready,
input  axi_d_rvalid,
input [31:0] axi_d_rdata,
input [1:0] axi_d_rresp,
input [3:0] axi_d_rid,
input  axi_d_rlast,
input  axi_i_awvalid,
input [31:0] axi_i_awaddr,
input [3:0] axi_i_awid,
input [7:0] axi_i_awlen,
input [1:0] axi_i_awburst,
input  axi_i_wvalid,
input [31:0] axi_i_wdata,
input [3:0] axi_i_wstrb,
input  axi_i_wlast,
input  axi_i_bready,
input  axi_i_arvalid,
input [31:0] axi_i_araddr,
input [3:0] axi_i_arid,
input [7:0] axi_i_arlen,
input [1:0] axi_i_arburst,
input  axi_i_rready,
input  axi_d_awvalid,
input [31:0] axi_d_awaddr,
input [3:0] axi_d_awid,
input [7:0] axi_d_awlen,
input [1:0] axi_d_awburst,
input  axi_d_wvalid,
input [31:0] axi_d_wdata,
input [3:0] axi_d_wstrb,
input  axi_d_wlast,
input  axi_d_bready,
input  axi_d_arvalid,
input [31:0] axi_d_araddr,
input [3:0] axi_d_arid,
input [7:0] axi_d_arlen,
input [1:0] axi_d_arburst,
input  axi_d_rready);

reg [31:0] cycle_q,trigger_pc_q,trigger_mask_q,watchdog_limit_q,watchdog_q,last_pc_q,last_reason_q;
reg [3:0] reset_count_q;

reg [7:0] write_index_q,read_index_q;
reg [3:0] read_word_q;
reg [8:0] sample_count_q;
reg armed_q,triggered_q,frozen_q,metrics_enabled_q;
reg [8:0] post_q;
reg [383:0] samples[0:255];
reg [383:0] sample_read_q;
wire iar=axi_i_arvalid&&axi_i_arready,ir=axi_i_rvalid&&axi_i_rready;
wire dar=axi_d_arvalid&&axi_d_arready,dr=axi_d_rvalid&&axi_d_rready;
wire aw=axi_d_awvalid&&axi_d_awready,ww=axi_d_wvalid&&axi_d_wready,bb=axi_d_bvalid&&axi_d_bready;
wire [31:0] axi_flags={15'b0,axi_d_bready,axi_d_bvalid,axi_d_wlast,axi_d_wready,axi_d_wvalid,
 axi_d_awready,axi_d_awvalid,axi_d_rlast,axi_d_rready,axi_d_rvalid,axi_d_arready,axi_d_arvalid,
 axi_i_rlast,axi_i_rready,axi_i_rvalid,axi_i_arready,axi_i_arvalid};
wire [31:0] lengths={{delay_mode,1'b0,axi_i_rresp,axi_d_rresp,axi_d_bresp},axi_d_awlen,axi_d_arlen,axi_i_arlen};
wire [383:0] sample_w={lengths,axi_flags,(axi_d_arvalid?axi_d_araddr:axi_d_awaddr),axi_i_araddr,core_debug,cycle_q};
wire match_pc=core_debug[193] && (((core_debug[31:0]^trigger_pc_q)&trigger_mask_q)==0);
wire watchdog_expired=watchdog_q==1;
always @(posedge clk)begin
 sample_read_q<=samples[read_index_q];
 if(armed_q && !warm_reset) samples[write_index_q]<=sample_w;
end
integer k;
always @(posedge clk or posedge rst)
if(rst)begin
 cycle_q<=0;trigger_pc_q<=0;trigger_mask_q<=32'hffffffff;watchdog_limit_q<=270000000;watchdog_q<=0;
 warm_reset<=0;reset_count_q<=0;last_pc_q<=0;last_reason_q<=0;delay_mode<=0;read_index_q<=0;read_word_q<=0;
 write_index_q<=0;sample_count_q<=0;armed_q<=0;triggered_q<=0;frozen_q<=0;post_q<=0;metrics_enabled_q<=0;
end else begin
 cycle_q<=cycle_q+1;
 if(reset_count_q!=0)begin reset_count_q<=reset_count_q-1'b1;if(reset_count_q==1)warm_reset<=0;end
 if(watchdog_q!=0)watchdog_q<=watchdog_q-1;
 if(armed_q && !warm_reset)begin
  write_index_q<=write_index_q+1;
  if(sample_count_q<256)sample_count_q<=sample_count_q+1;
  if(!triggered_q && match_pc)begin triggered_q<=1;post_q<=127;end
  else if(triggered_q)begin
   if(post_q==0)begin armed_q<=0;frozen_q<=1;end else post_q<=post_q-1;
  end
 end
 if(watchdog_expired)begin
  warm_reset<=1;reset_count_q<=8;last_pc_q<=core_debug[31:0];last_reason_q<=1;metrics_enabled_q<=0;
  armed_q<=0;frozen_q<=1;
 end
 if(write_en)case(write_addr[8:0])
  9'h000:begin
   if(write_data[0])begin armed_q<=1;triggered_q<=write_data[1];frozen_q<=0;post_q<=255;write_index_q<=0;sample_count_q<=0;end
   if(write_data[2])begin armed_q<=0;triggered_q<=0;frozen_q<=0;end
   if(write_data[3])begin warm_reset<=1;reset_count_q<=8;last_pc_q<=core_debug[31:0];last_reason_q<=2;watchdog_q<=0;metrics_enabled_q<=0;armed_q<=0;end
  end
  9'h008:trigger_pc_q<=write_data;
  9'h00c:trigger_mask_q<=write_data;
  9'h010:begin read_index_q<=write_data[7:0];read_word_q<=write_data[11:8];end
  9'h018:delay_mode<=write_data[0];
  9'h01c:watchdog_limit_q<=write_data;
  9'h020:watchdog_q<=write_data[0]?watchdog_limit_q:0;
  9'h024:metrics_enabled_q<=write_data[0];
 endcase
end
reg [31:0] counters[0:31];
reg ir_active,dr_active,w_active,b_pending,ir_ram,dr_ram,w_ram;
reg [8:0] ir_left,dr_left,w_left;
reg [3:0] ir_id,dr_id,w_id;
wire protocol_bad=(iar && ir_active)||(dar && dr_active)||(aw && b_pending)||
 (ir && (!ir_active || axi_i_rid!=ir_id || axi_i_rlast!=(ir_left==1)))||
 (dr && (!dr_active || axi_d_rid!=dr_id || axi_d_rlast!=(dr_left==1)))||
 (ww && (!w_active || axi_d_wlast!=(w_left==1)))||
 (bb && (!b_pending || w_active || axi_d_bid!=w_id))||
 (iar && (axi_i_arburst!=1 || axi_i_arlen!=7))||
 (dar && (axi_d_arburst!=1 || (axi_d_arlen!=0 && axi_d_arlen!=7)))||
 (aw && (axi_d_awburst!=1 || (axi_d_awlen!=0 && axi_d_awlen!=7)));
always @(posedge clk or posedge rst)
if(rst)begin ir_active<=0;dr_active<=0;w_active<=0;b_pending<=0;ir_left<=0;dr_left<=0;w_left<=0;ir_id<=0;dr_id<=0;w_id<=0;ir_ram<=0;dr_ram<=0;w_ram<=0;end
else if(warm_reset)begin ir_active<=0;dr_active<=0;w_active<=0;b_pending<=0;end
else begin
 if(iar)begin ir_active<=1;ir_left<={1'b0,axi_i_arlen}+1'b1;ir_id<=axi_i_arid;ir_ram<=axi_i_araddr<65536;end
 if(dar)begin dr_active<=1;dr_left<={1'b0,axi_d_arlen}+1'b1;dr_id<=axi_d_arid;dr_ram<=axi_d_araddr<65536;end
 if(aw)begin w_active<=1;b_pending<=1;w_left<={1'b0,axi_d_awlen}+1'b1;w_id<=axi_d_awid;w_ram<=axi_d_awaddr<65536;end
 if(ir)begin ir_left<=ir_left-1'b1;if(axi_i_rlast)ir_active<=0;end
 if(dr)begin dr_left<=dr_left-1'b1;if(axi_d_rlast)dr_active<=0;end
 if(ww)begin w_left<=w_left-1'b1;if(axi_d_wlast)w_active<=0;end
 if(bb)b_pending<=0;
end
reg held_ia;reg [45:0] previous_ia;
reg held_ir;reg [38:0] previous_ir;
reg held_da;reg [45:0] previous_da;
reg held_dr;reg [38:0] previous_dr;
reg held_aw;reg [45:0] previous_aw;
reg held_ww;reg [36:0] previous_ww;
reg held_bb;reg [5:0] previous_bb;
wire stability_bad=(held_ia && (!axi_i_arvalid || {axi_i_araddr,axi_i_arid,axi_i_arlen,axi_i_arburst}!=previous_ia)) ||
 (held_ir && (!axi_i_rvalid || {axi_i_rdata,axi_i_rid,axi_i_rresp,axi_i_rlast}!=previous_ir)) ||
 (held_da && (!axi_d_arvalid || {axi_d_araddr,axi_d_arid,axi_d_arlen,axi_d_arburst}!=previous_da)) ||
 (held_dr && (!axi_d_rvalid || {axi_d_rdata,axi_d_rid,axi_d_rresp,axi_d_rlast}!=previous_dr)) ||
 (held_aw && (!axi_d_awvalid || {axi_d_awaddr,axi_d_awid,axi_d_awlen,axi_d_awburst}!=previous_aw)) ||
 (held_ww && (!axi_d_wvalid || {axi_d_wdata,axi_d_wstrb,axi_d_wlast}!=previous_ww)) ||
 (held_bb && (!axi_d_bvalid || {axi_d_bid,axi_d_bresp}!=previous_bb));
always @(posedge clk or posedge rst) if(rst)begin held_ia<=0;previous_ia<=0;end else if(warm_reset)held_ia<=0;else begin held_ia<=axi_i_arvalid&&!axi_i_arready;previous_ia<={axi_i_araddr,axi_i_arid,axi_i_arlen,axi_i_arburst};end
always @(posedge clk or posedge rst) if(rst)begin held_ir<=0;previous_ir<=0;end else if(warm_reset)held_ir<=0;else begin held_ir<=axi_i_rvalid&&!axi_i_rready;previous_ir<={axi_i_rdata,axi_i_rid,axi_i_rresp,axi_i_rlast};end
always @(posedge clk or posedge rst) if(rst)begin held_da<=0;previous_da<=0;end else if(warm_reset)held_da<=0;else begin held_da<=axi_d_arvalid&&!axi_d_arready;previous_da<={axi_d_araddr,axi_d_arid,axi_d_arlen,axi_d_arburst};end
always @(posedge clk or posedge rst) if(rst)begin held_dr<=0;previous_dr<=0;end else if(warm_reset)held_dr<=0;else begin held_dr<=axi_d_rvalid&&!axi_d_rready;previous_dr<={axi_d_rdata,axi_d_rid,axi_d_rresp,axi_d_rlast};end
always @(posedge clk or posedge rst) if(rst)begin held_aw<=0;previous_aw<=0;end else if(warm_reset)held_aw<=0;else begin held_aw<=axi_d_awvalid&&!axi_d_awready;previous_aw<={axi_d_awaddr,axi_d_awid,axi_d_awlen,axi_d_awburst};end
always @(posedge clk or posedge rst) if(rst)begin held_ww<=0;previous_ww<=0;end else if(warm_reset)held_ww<=0;else begin held_ww<=axi_d_wvalid&&!axi_d_wready;previous_ww<={axi_d_wdata,axi_d_wstrb,axi_d_wlast};end
always @(posedge clk or posedge rst) if(rst)begin held_bb<=0;previous_bb<=0;end else if(warm_reset)held_bb<=0;else begin held_bb<=axi_d_bvalid&&!axi_d_bready;previous_bb<={axi_d_bid,axi_d_bresp};end
always @(posedge clk or posedge rst)
if(rst)begin for(k=0;k<32;k=k+1)counters[k]<=0;end
else if(write_en && write_addr[8:0]==9'h024 && write_data[1])begin for(k=0;k<32;k=k+1)counters[k]<=0;end
else if(metrics_enabled_q && !warm_reset)begin
 counters[0]<=counters[0]+core_debug[193];
 counters[1]<=counters[1]+core_debug[205];
 counters[2]<=counters[2]+1;
 counters[3]<=counters[3]+core_debug[197];
 counters[4]<=counters[4]+core_debug[198];
 counters[5]<=counters[5]+core_debug[203];
 counters[6]<=counters[6]+(iar && axi_i_araddr<65536);
 counters[7]<=counters[7]+(dar && axi_d_araddr<65536);
 counters[8]<=counters[8]+(aw && axi_d_awaddr<65536);
 counters[9]<=counters[9]+(ir && ir_ram);
 counters[10]<=counters[10]+(dr && dr_ram);
 counters[11]<=counters[11]+(ww && w_ram);
 counters[12]<=counters[12]+(protocol_bad||stability_bad);
 counters[13]<=counters[13]+(bb && axi_d_bresp!=0);
 counters[14]<=counters[14]+((ir && axi_i_rresp!=0)||(dr && axi_d_rresp!=0));
 counters[15]<=counters[15]+(axi_i_arvalid&&!axi_i_arready);
 counters[16]<=counters[16]+(axi_d_arvalid&&!axi_d_arready);
 counters[17]<=counters[17]+(axi_d_awvalid&&!axi_d_awready);
 counters[18]<=counters[18]+(axi_d_wvalid&&!axi_d_wready);
 counters[19]<=counters[19]+((axi_i_rvalid&&!axi_i_rready)||(axi_d_rvalid&&!axi_d_rready));
 counters[20]<=counters[20]+core_debug[215];
end
always @*begin
 read_data=0;
 case(read_addr[8:0])
  9'h000:read_data=0;
  9'h004:read_data={write_index_q,7'b0,sample_count_q,5'b0,frozen_q,triggered_q,armed_q};
  9'h008:read_data=trigger_pc_q;
  9'h00c:read_data=trigger_mask_q;
  9'h010:read_data={20'b0,read_word_q,read_index_q};
  9'h014:read_data=read_word_q<12 ? sample_read_q[read_word_q*32+:32] : 0;
  9'h018:read_data={31'b0,delay_mode};
  9'h01c:read_data=watchdog_limit_q;
  9'h020:read_data=watchdog_q;
  9'h024:read_data={31'b0,metrics_enabled_q};
  9'h02c:read_data=last_pc_q;
  9'h030:read_data=last_reason_q;
  9'h03c:read_data=32'h56414c33;
  default:if(read_addr[8:7]==2'b10)read_data=counters[read_addr[6:2]];
 endcase
end
endmodule
