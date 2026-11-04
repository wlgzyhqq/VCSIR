// 720p video/PLL/MS7210 path adopted from the board-verified reference check.
// CPU control changes colours only; reference sync timing and sampling are kept.
module final_hdmi #(parameter CPU_HZ=50000000)(input clk,ref_clk,rst,input [31:0] control,
 input [31:0] terminal_addr,terminal_wdata,input [3:0] terminal_wstrb,input terminal_we,
 output terminal_write_ok,output [31:0] terminal_rdata,
 input boot_done,boot_fault,memory_ready,output [31:0] status,output [63:0] measurement,
 input ui_clk,ui_rst,input [2:0] arb_fault,output [27:0] video_araddr,output [3:0] video_arlen,output video_arvalid,
 input video_arready,video_rvalid,input [255:0] video_rdata,
 output hdmi_pclk,hdmi_hs,hdmi_vs,hdmi_de,output [23:0] hdmi_data,
 output hdmi_rstn,inout hdmi_scl,hdmi_sda);
 wire pixel_raw,pixel_clk,cfg_raw,cfg_clk,pixel_lock,init_cfg;
 final_hdmi_pll u_pixel_pll(.clkin1(ref_clk),.clkout0(pixel_raw),.clkout1(cfg_raw),.pll_lock(pixel_lock));
 GTP_CLKBUFG u_pixel_clock(.CLKIN(pixel_raw),.CLKOUT(pixel_clk));
 GTP_CLKBUFG u_cfg_clock(.CLKIN(cfg_raw),.CLKOUT(cfg_clk));
 (* ASYNC_REG="TRUE" *) reg [1:0] cfg_release;
 always @(posedge cfg_clk or posedge rst or negedge pixel_lock)
  if(rst || !pixel_lock) cfg_release<=0;else cfg_release<={cfg_release[0],1'b1};
 reg [15:0] cfg_reset_count=0;
 always @(posedge cfg_clk)
  if(!cfg_release[1]) cfg_reset_count<=0;
  else if(cfg_reset_count!=16'h2710) cfg_reset_count<=cfg_reset_count+1'b1;
 assign hdmi_rstn=(cfg_reset_count==16'h2710);
 // Same controller and I2C implementation as the successful reference image.
 // Its unused HDMI receiver interface is disconnected and removed in synthesis.
 ms72xx_ctl u_config(.clk(cfg_clk),.rst_n(hdmi_rstn),.init_over(init_cfg),
  .iic_tx_scl(hdmi_scl),.iic_tx_sda(hdmi_sda),.iic_scl(),.iic_sda());
 (* ASYNC_REG="TRUE" *) reg lock_meta,lock_sync,ready_meta,ready_sync;
 reg [26:0] init_wait;
 always @(posedge clk) begin
  if(rst) begin lock_meta<=0;lock_sync<=0;ready_meta<=0;ready_sync<=0;init_wait<=0;end
  else begin
   lock_meta<=pixel_lock;lock_sync<=lock_meta;ready_meta<=init_cfg;ready_sync<=ready_meta;
   if(ready_sync) init_wait<=0;
   else if(init_wait!=CPU_HZ) init_wait<=init_wait+1'b1;
  end
 end
 assign status={29'b0,(init_wait==CPU_HZ),ready_sync,lock_sync};
 // Retired VGA detector MMIO is reserved, read-as-zero in this implementation.
 assign measurement=0;
 (* ASYNC_REG="TRUE" *) reg [1:0] pixel_release;
 always @(posedge pixel_clk or negedge hdmi_rstn)
  if(!hdmi_rstn) pixel_release<=0;else pixel_release<={pixel_release[0],1'b1};
 wire pixel_rstn=pixel_release[1];
 wire hs_in,vs_in,de_in;
 wire [11:0] act_x,act_y;
 sync_vg #(.X_BITS(12),.Y_BITS(12),.H_TOTAL(1650),.H_FP(110),.H_BP(220),
  .H_SYNC(40),.H_ACT(1280),.V_TOTAL(750),.V_FP(5),.V_BP(20),.V_SYNC(5),.V_ACT(720))
 u_timing(.clk(pixel_clk),.rstn(pixel_rstn),.hs_out(hs_in),.vs_out(vs_in),
  .de_out(de_in),.x_act(act_x),.y_act(act_y));
 reg [31:0] control_hold,frame_control;
 reg request_toggle,acknowledge_toggle;
 (* ASYNC_REG="TRUE" *) reg ack_meta,ack_sync,req_meta,req_sync;
 always @(posedge clk) begin
  if(rst || !lock_sync) begin control_hold<=0;request_toggle<=0;ack_meta<=0;ack_sync<=0;end
  else begin
   ack_meta<=acknowledge_toggle;ack_sync<=ack_meta;
   if(ack_sync==request_toggle && control_hold!=control) begin
    control_hold<=control;request_toggle<=!request_toggle;
   end
  end
 end
 (* ASYNC_REG="TRUE" *) reg [3:0] flags_meta,flags_sync;
 reg [3:0] frame_flags;
 reg vs_previous;
 reg [10:0] frame;
 always @(posedge pixel_clk) begin
  if(!pixel_rstn) begin
   req_meta<=0;req_sync<=0;acknowledge_toggle<=0;frame_control<=0;
   flags_meta<=0;flags_sync<=0;frame_flags<=0;vs_previous<=0;frame<=0;
  end else begin
   req_meta<=request_toggle;req_sync<=req_meta;
   flags_meta<={init_cfg,boot_fault,boot_done,memory_ready};flags_sync<=flags_meta;
   vs_previous<=vs_in;
   if(vs_in && !vs_previous) begin
    frame_flags<=flags_sync;frame<=frame==1215?0:frame+1'b1;
    if(req_sync!=acknowledge_toggle) begin frame_control<=control_hold;acknowledge_toggle<=req_sync;end
   end
  end
 end
 yolo_video u_video(.clk(clk),.rst(rst),.cpu_addr(terminal_addr),.cpu_wdata(terminal_wdata),
 .cpu_wstrb(terminal_wstrb),.cpu_we(terminal_we),.cpu_write_ok(terminal_write_ok),.cpu_rdata(terminal_rdata),
 .ui_clk(ui_clk),.ui_rst(ui_rst),.arb_fault(arb_fault),.araddr(video_araddr),.arlen(video_arlen),.arvalid(video_arvalid),
 .arready(video_arready),.rvalid(video_rvalid),.rdata(video_rdata),
 .pixel_clk(pixel_clk),.pixel_rstn(pixel_rstn),.act_x(act_x),.act_y(act_y),.hs_in(hs_in),.vs_in(vs_in),.de_in(de_in),
 .hs_out(hdmi_hs),.vs_out(hdmi_vs),.de_out(hdmi_de),.rgb_out(hdmi_data));
 // Reference PA=04 samples the falling edge. Shared buffer drives video and pad.
 assign hdmi_pclk=pixel_clk;
endmodule
