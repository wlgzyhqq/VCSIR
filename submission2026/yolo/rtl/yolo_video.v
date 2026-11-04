// 320x320 RGB565 DDR image -> 640x640 at (0,40), plus ASCII status panel.
// Two 640-byte line banks are written at100MHz and read at pixel clock.
// Pixel requests only a freed bank; UI acknowledges after ALL20 data beats.
// Configuration/boxes cross as a held request/ack mailbox committed in VS.
module yolo_video(input clk,rst,input [31:0] cpu_addr,cpu_wdata,input [3:0] cpu_wstrb,input cpu_we,
 output cpu_write_ok,output reg [31:0] cpu_rdata,
 input ui_clk,ui_rst,input [2:0] arb_fault,
 output [27:0] araddr,output [3:0] arlen,output arvalid,input arready,rvalid,input [255:0] rdata,
 input pixel_clk,pixel_rstn,input [11:0] act_x,act_y,input hs_in,vs_in,de_in,
 output reg hs_out,vs_out,de_out,output reg [23:0] rgb_out);
 reg [31:0] image_base;reg [2:0] control_hold,front_control;reg [4:0] box_count;reg [3:0] box_index;
 reg [17:0] box_lo[0:15],box_hi[0:15];reg [17:0] frame_lo[0:15],frame_hi[0:15];
 reg [4:0] frame_box_count;reg [31:0] frame_base;reg [2:0] frame_control;
 reg cfg_request,cfg_ack;
 (* ASYNC_REG="TRUE" *) reg cfg_req_meta,cfg_req_sync,cfg_ack_meta,cfg_ack_sync,pix_ready_meta,pix_ready_sync;
 reg [31:0] rejected,frame_counter,frame_gray,underflow_counter,underflow_gray;
 (* ASYNC_REG="TRUE" *) reg [31:0] frames_meta,frames_sync,underflow_meta,underflow_sync;
 reg [15:0] text_ram[0:4095] /* synthesis syn_ramstyle="block_ram" */;
 reg [15:0] cpu_text,text_q;
 wire text_address=cpu_addr>=32'h80010000 && cpu_addr<32'h80018000;
 wire text_valid=cpu_addr[13:2]<12'd1800;
 wire cfg_busy=cfg_request!=cfg_ack_sync;
 wire full_word=cpu_wstrb==15;
 wire config_address=cpu_addr>=32'h80007000 && cpu_addr<32'h80007040;
 assign cpu_write_ok=full_word && !cfg_busy && (
  (text_address && text_valid && cpu_addr[14]!=front_control[1]) ||
  cpu_addr==32'h8000700c || cpu_addr==32'h80007024 ||
  cpu_addr==32'h80007028 || cpu_addr==32'h8000702c ||
  (cpu_addr==32'h80007008 && pix_ready_sync && cpu_wdata[31:3]==0) ||
  (cpu_addr==32'h80007020 && cpu_wdata<=16));
 function [31:0] from_gray;input [31:0] a;reg [31:0] b;begin b=a^(a>>1);b=b^(b>>2);b=b^(b>>4);b=b^(b>>8);from_gray=b^(b>>16);end endfunction
 reg ui_error;
 (* ASYNC_REG="TRUE" *) reg error_meta,error_sync;
 always @*begin
  cpu_rdata=0;
  if(text_address)cpu_rdata=text_valid?{16'b0,cpu_text}:0;
  else case(cpu_addr[7:0])
   8'h00:cpu_rdata=32'h59564944;
   8'h04:cpu_rdata={25'b0,error_sync,(rejected!=0),front_control,pix_ready_sync,cfg_busy};
   8'h08:cpu_rdata={29'b0,control_hold};
   8'h0c:cpu_rdata=image_base;
   8'h14:cpu_rdata=from_gray(frames_sync);
   8'h18:cpu_rdata=from_gray(underflow_sync);
   8'h1c:cpu_rdata=rejected;
   8'h20:cpu_rdata={27'b0,box_count};
   8'h24:cpu_rdata={28'b0,box_index};
   8'h28:cpu_rdata={7'b0,box_lo[box_index][17:9],7'b0,box_lo[box_index][8:0]};
   8'h2c:cpu_rdata={7'b0,box_hi[box_index][17:9],7'b0,box_hi[box_index][8:0]};
   8'h30:cpu_rdata={16'd320,16'd320};
   8'h34:cpu_rdata=32'd1800;
   default:cpu_rdata=0;
  endcase
 end
 always @(posedge clk)begin
  cpu_text<=text_ram[{cpu_addr[14],cpu_addr[12:2]}];
  if(cpu_we && cpu_write_ok && text_address)text_ram[{cpu_addr[14],cpu_addr[12:2]}]<=cpu_wdata[15:0];
 end
 integer i;
 always @(posedge clk or posedge rst)
 if(rst)begin
  image_base<=32'h38000000;control_hold<=0;front_control<=0;box_count<=0;box_index<=0;cfg_request<=0;
  cfg_ack_meta<=0;cfg_ack_sync<=0;pix_ready_meta<=0;pix_ready_sync<=0;rejected<=0;
  frames_meta<=0;frames_sync<=0;underflow_meta<=0;underflow_sync<=0;error_meta<=0;error_sync<=0;
  for(i=0;i<16;i=i+1)begin box_lo[i]<=0;box_hi[i]<=0;end
 end else begin
  cfg_ack_meta<=cfg_ack;cfg_ack_sync<=cfg_ack_meta;pix_ready_meta<=pixel_rstn;pix_ready_sync<=pix_ready_meta;
  frames_meta<=frame_gray;frames_sync<=frames_meta;underflow_meta<=underflow_gray;underflow_sync<=underflow_meta;
  error_meta<=ui_error;error_sync<=error_meta;
  if(!cfg_busy)front_control<=control_hold;
  if(cpu_we)begin
   if(!cpu_write_ok)rejected<=rejected+1'b1;
   else if(!text_address)case(cpu_addr[7:0])
    8'h08:begin control_hold<=cpu_wdata[2:0];cfg_request<=!cfg_request;end
    8'h0c:if(cpu_wdata[4:0]==0 && cpu_wdata>=32'h02000000 && cpu_wdata<=32'h3ffc0000)image_base<=cpu_wdata;else rejected<=rejected+1'b1;
    8'h20:box_count<=cpu_wdata[4:0];
    8'h24:box_index<=cpu_wdata[3:0];
    8'h28:if(cpu_wdata[15:0]<320 && cpu_wdata[31:16]<320)box_lo[box_index]<={cpu_wdata[24:16],cpu_wdata[8:0]};else rejected<=rejected+1'b1;
    8'h2c:if(cpu_wdata[15:0]<320 && cpu_wdata[31:16]<320)box_hi[box_index]<={cpu_wdata[24:16],cpu_wdata[8:0]};else rejected<=rejected+1'b1;
    default:begin end
   endcase
  end
 end
 // Held pixel->UI line request, response payload remains stable until next line.
 reg line_request,line_ack,frame_epoch;
 reg [31:0] line_base_hold;reg [8:0] line_row_hold;reg line_epoch_hold;
 (* ASYNC_REG="TRUE" *) reg line_req_meta,line_req_sync,line_ack_meta,line_ack_sync;
 reg [8:0] response_row;reg response_epoch,response_good;
 reg [8:0] bank_row[0:1];reg [1:0] bank_valid,bank_epoch;
 reg ack_previous,vs_previous;reg [1:0] prime;
 wire [11:0] image_y=act_y-12'd40;
 wire [8:0] source_y=image_y[9:1];wire [8:0] source_x=act_x[9:1];
 wire image_area=de_in && act_x<640 && act_y>=40 && act_y<680 && frame_control[0];
 wire line_good=bank_valid[source_y[0]] && bank_row[source_y[0]]==source_y && bank_epoch[source_y[0]]==frame_epoch;
 wire line_idle=line_request==line_ack_sync;
 integer j;
 always @(posedge pixel_clk or negedge pixel_rstn)
 if(!pixel_rstn)begin
  cfg_req_meta<=0;cfg_req_sync<=0;cfg_ack<=0;frame_base<=0;frame_control<=0;frame_box_count<=0;
  line_request<=0;line_base_hold<=0;line_row_hold<=0;line_epoch_hold<=0;
  line_ack_meta<=0;line_ack_sync<=0;ack_previous<=0;bank_valid<=0;bank_epoch<=0;bank_row[0]<=0;bank_row[1]<=0;
  vs_previous<=0;prime<=0;frame_epoch<=0;frame_counter<=0;frame_gray<=0;underflow_counter<=0;underflow_gray<=0;
  for(j=0;j<16;j=j+1)begin frame_lo[j]<=0;frame_hi[j]<=0;end
 end else begin
  cfg_req_meta<=cfg_request;cfg_req_sync<=cfg_req_meta;
  line_ack_meta<=line_ack;line_ack_sync<=line_ack_meta;ack_previous<=line_ack_sync;vs_previous<=vs_in;
  if(line_ack_sync!=ack_previous)begin
   bank_valid[response_row[0]]<=response_good;bank_row[response_row[0]]<=response_row;bank_epoch[response_row[0]]<=response_epoch;
  end
  if(vs_in && !vs_previous)begin
   frame_counter<=frame_counter+1'b1;frame_gray<=(frame_counter+1'b1)^((frame_counter+1'b1)>>1);
   frame_epoch<=!frame_epoch;prime<=1;
   if(cfg_req_sync!=cfg_ack)begin
    frame_base<=image_base;frame_control<=control_hold;frame_box_count<=box_count;cfg_ack<=cfg_req_sync;
    for(j=0;j<16;j=j+1)begin frame_lo[j]<=box_lo[j];frame_hi[j]<=box_hi[j];end
   end
  end else if(prime!=0 && line_idle)begin
   if(frame_control[0])begin
    line_base_hold<=prime==1?frame_base:frame_base+32'd640;line_row_hold<=prime==1?0:1;line_epoch_hold<=frame_epoch;line_request<=!line_request;
    prime<=prime==1?2:0;
   end else prime<=0;
  end else if(image_area && act_x==639 && image_y[0] && source_y<318)begin
   if(line_idle)begin
    line_base_hold<=frame_base+(({23'b0,source_y}+32'd2)<<9)+(({23'b0,source_y}+32'd2)<<7);line_row_hold<=source_y+2;line_epoch_hold<=frame_epoch;line_request<=!line_request;
   end
  end
  // Count once per output scanline, never silently show stale-bank pixels.
  if(image_area && act_x==0 && !line_good)begin
   underflow_counter<=underflow_counter+1'b1;underflow_gray<=(underflow_counter+1'b1)^((underflow_counter+1'b1)>>1);
  end
 end
 // UI writes a complete 32-byte native beat to a dual-clock line RAM.
 reg [255:0] lines[0:63] /* synthesis syn_ramstyle="block_ram" */;
 reg [2:0] state;reg [31:0] byte_address,second_address;reg [4:0] chunk;reg [3:0] beat;
 reg [8:0] active_row;reg active_epoch;reg [19:0] timeout;
 localparam U_IDLE=0,U_AR=1,U_DATA=2,U_ERROR=3,U_COMMIT=4;
 assign araddr=byte_address[29:2];assign arlen=chunk==0?4'd15:4'd3;
 assign arvalid=state==U_AR && !ui_error;
 wire read_window=state==U_DATA || (state==U_AR && arready);
 wire [5:0] line_write_addr={active_row[0],5'b0}+{1'b0,chunk}+{2'b0,beat};
 reg line_we;reg [5:0] line_addr;reg [255:0] line_data;
 always @(posedge ui_clk)begin
  if(ui_rst)line_we<=0;
  else line_we<=rvalid && read_window && !ui_error;
  line_addr<=line_write_addr;line_data<=rdata;
  if(line_we)lines[line_addr]<=line_data;
 end
 always @(posedge ui_clk or posedge ui_rst)
 if(ui_rst)begin
  line_req_meta<=0;line_req_sync<=0;line_ack<=0;state<=U_IDLE;byte_address<=0;second_address<=0;chunk<=0;beat<=0;
  active_row<=0;active_epoch<=0;timeout<=0;ui_error<=0;response_row<=0;response_epoch<=0;response_good<=0;
 end else begin
  line_req_meta<=line_request;line_req_sync<=line_req_meta;
  if(state==U_IDLE)timeout<=0;else if(state!=U_ERROR)timeout<=timeout+1'b1;
  case(state)
   U_IDLE:if(line_req_sync!=line_ack)begin
    byte_address<=line_base_hold;second_address<=line_base_hold+32'd512;
    active_row<=line_row_hold;active_epoch<=line_epoch_hold;chunk<=0;beat<=0;state<=U_AR;
   end
   U_AR:if(arready)state<=U_DATA;
   U_COMMIT:begin response_row<=active_row;response_epoch<=active_epoch;response_good<=1;line_ack<=line_req_sync;state<=U_IDLE;end
   U_ERROR:state<=U_ERROR;
   default:begin end
  endcase
  if(rvalid && read_window && !ui_error)begin
   if(beat==arlen)begin
    beat<=0;
    if(chunk==0)begin chunk<=16;byte_address<=second_address;state<=U_AR;end
    else state<=U_COMMIT;
   end else beat<=beat+1'b1;
  end
  if((state!=U_IDLE && state!=U_ERROR && &timeout) || arb_fault!=0)begin
   ui_error<=1;state<=U_ERROR;response_row<=active_row;response_epoch<=active_epoch;response_good<=0;line_ack<=line_req_sync;
  end
 end
 // Synchronous RAM read, synchronous font read, aligned output registers.
 wire [5:0] line_read_addr={source_y[0],source_x[8:4]};
 wire [11:0] panel_x=act_x-12'd640;
 wire [10:0] text_index=({6'b0,act_y[9:4]}<<5)+({6'b0,act_y[9:4]}<<3)+{5'b0,panel_x[9:4]};
 reg [255:0] word_q;reg [3:0] element0;reg image0,good0,border0,panel0;
 reg [2:0] fy0,fx0,fx1;reg [2:0] sync0,sync1;reg [7:0] colours1;
 reg image1,good1,border1,panel1;reg [23:0] image_rgb1;
 wire [7:0] glyph;
 final_ascii_font u_font(.clk(pixel_clk),.character(text_q[6:0]),.row(fy0),.pixels(glyph));
 reg border;integer b;
 always @*begin
  border=0;
  for(b=0;b<16;b=b+1)
   if(b<frame_box_count && source_x>=frame_lo[b][8:0] && source_x<=frame_hi[b][8:0] &&
      source_y>=frame_lo[b][17:9] && source_y<=frame_hi[b][17:9] &&
      (source_x==frame_lo[b][8:0] || source_x==frame_hi[b][8:0] || source_y==frame_lo[b][17:9] || source_y==frame_hi[b][17:9]))border=1;
 end
 function [23:0] palette;input [3:0] c;begin case(c)
  0:palette=24'h102032;1:palette=24'hff5050;2:palette=24'h50ff50;3:palette=24'hffff50;
  4:palette=24'h5090ff;5:palette=24'hff50ff;6:palette=24'h50ffff;7:palette=24'hb0b0b0;
  default:palette=24'hffffff;
 endcase end endfunction
 wire [15:0] pixel565=word_q[element0*16+:16];
 always @(posedge pixel_clk)begin
  word_q<=lines[line_read_addr];text_q<=text_ram[{frame_control[1],text_index}];
 end
 always @(posedge pixel_clk or negedge pixel_rstn)
 if(!pixel_rstn)begin
  element0<=0;image0<=0;good0<=0;border0<=0;panel0<=0;fy0<=0;fx0<=0;fx1<=0;sync0<=0;sync1<=0;colours1<=0;
  image1<=0;good1<=0;border1<=0;panel1<=0;image_rgb1<=0;hs_out<=0;vs_out<=0;de_out<=0;rgb_out<=0;
 end else begin
  element0<=source_x[3:0];image0<=image_area;good0<=line_good;border0<=border;
  panel0<=de_in && act_x>=640 && act_x<1280 && act_y<720 && frame_control[2];
  fy0<=act_y[3:1];fx0<=panel_x[3:1];sync0<={hs_in,vs_in,de_in};
  image_rgb1<={pixel565[15:11],pixel565[15:13],pixel565[10:5],pixel565[10:9],pixel565[4:0],pixel565[4:2]};
  image1<=image0;good1<=good0;border1<=border0;panel1<=panel0;fx1<=fx0;colours1<=text_q[15:8];sync1<=sync0;
  hs_out<=sync1[2];vs_out<=sync1[1];de_out<=sync1[0];
  if(!sync1[0])rgb_out<=0;
  else if(panel1)rgb_out<=glyph[fx1]?palette(colours1[3:0]):palette(colours1[7:4]);
  else if(image1)rgb_out<=!good1?24'hff00ff:border1?24'h00ff30:image_rgb1;
  else rgb_out<=24'h102032;
 end
endmodule
