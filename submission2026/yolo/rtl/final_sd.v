// SD7: held MMIO mailbox (CPU50/UI100), SPI block CRC16 and file CRC32.
// Read only: no SD write command exists in the hardware/firmware API.
module final_sd(input clk,rst,ui_clk,ui_rst,
 input [31:0] addr,wdata,input [3:0] wstrb,input we,
 output write_ok,output reg [31:0] rdata,
 output sd_clk,sd_cmd,sd_cs_n,input sd_d0,sd_detect_n,
 output stream_valid,input stream_ready,output [255:0] stream_data,
 input verify_valid,input [255:0] verify_data,input [31:0] verify_keep,output verify_ready);
 localparam IDLE=0,CHECK=1,RAW=2,RAW_WAIT=3,TOKEN=4,TOKEN_WAIT=5,
  DATA=6,DATA_WAIT=7,CRC_HI=8,CRC_HI_WAIT=9,CRC_LO=10,CRC_LO_WAIT=11,
  RAM_WAIT=12,STREAM=13,WORD_READ=14,WORD_WAIT=15,FINISH=16,
  VERIFY_WAIT=17,VERIFY_BYTES=18,PREP=19;
 reg [31:0] config_op,config_arg,config_div,config_cs,config_seed,config_index;
 reg [31:0] cmd_op_hold,cmd_arg_hold,cmd_div_hold,cmd_cs_hold,cmd_seed_hold,cmd_index_hold;
 reg request_toggle,busy,done;
 reg [31:0] rejected,status_value,status_error,status_crc,status_blocks,status_bytes;
 reg [31:0] status_cycles_lo,status_cycles_hi;
 (* ASYNC_REG="TRUE" *) reg req_meta,req_sync,ack_meta,ack_sync,detect_meta,detect_sync;
 reg ack_toggle,request_seen;
 reg [31:0] res_value_hold,res_error_hold,res_crc_hold,res_blocks_hold,res_bytes_hold;
 reg [31:0] res_cycles_lo_hold,res_cycles_hi_hold;
 assign write_ok=wstrb==15 && addr[7:2]>=1 && addr[7:2]<=7;
 always @* case(addr[7:2])
  0:rdata=32'h53443731;1:rdata={29'b0,status_error!=0,done,busy};
  2:rdata=config_op;3:rdata=config_arg;4:rdata=config_div;5:rdata=config_cs;
  6:rdata=config_seed;7:rdata=config_index;8:rdata=status_value;9:rdata=status_error;
  10:rdata=status_crc;11:rdata=status_blocks;12:rdata=status_bytes;13:rdata=rejected;
  14:rdata={31'b0,detect_sync};15:rdata=100000000;
  16:rdata=status_cycles_lo;17:rdata=status_cycles_hi;default:rdata=0;
 endcase
 always @(posedge clk or posedge rst)
 if(rst) begin
  config_op<=1;config_arg<=255;config_div<=200;config_cs<=1;
  config_seed<=32'hffffffff;config_index<=0;
  cmd_op_hold<=0;cmd_arg_hold<=0;cmd_div_hold<=200;cmd_cs_hold<=1;
  cmd_seed_hold<=32'hffffffff;cmd_index_hold<=0;
  request_toggle<=0;busy<=0;done<=0;rejected<=0;
  status_value<=0;status_error<=0;status_crc<=0;status_blocks<=0;status_bytes<=0;
  status_cycles_lo<=0;status_cycles_hi<=0;ack_meta<=0;ack_sync<=0;
  detect_meta<=1;detect_sync<=1;
 end else begin
  ack_meta<=ack_toggle;ack_sync<=ack_meta;
  detect_meta<=sd_detect_n;detect_sync<=detect_meta;
  if(busy && ack_sync==request_toggle) begin
   busy<=0;done<=1;status_value<=res_value_hold;status_error<=res_error_hold;
   status_crc<=res_crc_hold;status_blocks<=res_blocks_hold;status_bytes<=res_bytes_hold;
   status_cycles_lo<=res_cycles_lo_hold;status_cycles_hi<=res_cycles_hi_hold;
  end
  if(we && write_ok) begin
   if(addr[7:2]==1) begin
    if(wdata[1]) done<=0;
    if(wdata[0]) begin
     if(busy) rejected<=rejected+1'b1;
     else begin
      cmd_op_hold<=config_op;cmd_arg_hold<=config_arg;cmd_div_hold<=config_div;
      cmd_cs_hold<=config_cs;cmd_seed_hold<=config_seed;cmd_index_hold<=config_index;
      request_toggle<=~request_toggle;busy<=1;done<=0;status_error<=0;
     end
    end
   end else if(busy) rejected<=rejected+1'b1;
   else case(addr[7:2])
    2:config_op<=wdata;3:config_arg<=wdata;4:config_div<=wdata;
    5:config_cs<=wdata;6:config_seed<=wdata;7:config_index<=wdata;
   endcase
  end
 end
 reg [4:0] state;
 reg [31:0] native_op,native_arg,native_seed,native_index;
 reg [15:0] native_div;
 reg [15:0] native_div_ticks /* synthesis syn_preserve=1 syn_allow_retiming=0 */;
 reg chip_select;
 assign sd_cs_n=chip_select;
 reg spi_start;reg [7:0] spi_tx;
 wire spi_busy,spi_done;wire [7:0] spi_rx;
 final_sd_spi_byte #(.PREPARED_DIVIDER(1)) u_spi(.clk(ui_clk),.rst(ui_rst),.start(spi_start),.tx(spi_tx),
  .divider(native_div),.prepared_ticks(native_div_ticks),.miso(sd_d0),.sck(sd_clk),.mosi(sd_cmd),
  .busy(spi_busy),.done(spi_done),.rx(spi_rx));
 // ADS Synthesis User Guide 5.16: force the synchronous sector buffer to
 // block RAM; shallow distributed RAM WD hold paths failed routed STA.
 reg [255:0] buffer [0:15] /* synthesis syn_ramstyle = "block_ram" */;
 reg [255:0] pack_shift,buffer_word;
 // Physical hold buffers preserve every SD write bit and break short RAM data paths.
 wire [255:0] buffer_write_raw={spi_rx,pack_shift[255:8]};
 wire [255:0] buffer_write_held /* synthesis syn_keep=1 */;
 genvar sd_hold_bit;
 generate for(sd_hold_bit=0;sd_hold_bit<256;sd_hold_bit=sd_hold_bit+1)begin:g_sd_data_hold
  GTP_LUT1 #(.INIT(2'h2)) u_holdbuf(.I0(buffer_write_raw[sd_hold_bit]),.Z(buffer_write_held[sd_hold_bit])) /* synthesis syn_noprune=1 */;
 end endgenerate
 reg [8:0] byte_index;
 reg [3:0] beat_index,beat_last;
 reg [15:0] block_crc;reg [7:0] received_crc_hi;
 wire [15:0] block_crc_guarded /* synthesis syn_keep=1 */;
 genvar block_crc_bit;
 generate for(block_crc_bit=0;block_crc_bit<16;block_crc_bit=block_crc_bit+1)begin:g_sd_block_crc_hold
  GTP_LUT1 #(.INIT(2'h2)) u_holdbuf(.I0(block_crc[block_crc_bit]),.Z(block_crc_guarded[block_crc_bit])) /* synthesis syn_noprune=1 */;
 end endgenerate
 reg [24:0] remaining; // CHECK permits at most16MiB; STREAM subtracts only above512.
 reg [15:0] blocks; // ceil(16MiB/512) is32768.
 reg [24:0] bytes_received;
 reg [31:0] file_crc,error,value;
 wire [31:0] blocks_extended={16'b0,blocks};
 wire [31:0] blocks_guarded /* synthesis syn_keep=1 */;
 genvar blocks_hold_bit;
 generate for(blocks_hold_bit=0;blocks_hold_bit<32;blocks_hold_bit=blocks_hold_bit+1)begin:g_sd_blocks_hold
  GTP_LUT1 #(.INIT(2'h2)) u_holdbuf(.I0(blocks_extended[blocks_hold_bit]),.Z(blocks_guarded[blocks_hold_bit])) /* synthesis syn_noprune=1 */;
 end endgenerate
 reg [63:0] cycles;
 wire [191:0] result_mail_raw={cycles,7'b0,bytes_received,file_crc,error,value};
 wire [191:0] result_mail_guarded /* synthesis syn_keep=1 */;
 genvar result_mail_bit;
 generate for(result_mail_bit=0;result_mail_bit<192;result_mail_bit=result_mail_bit+1)begin:g_sd_result_hold
  if(result_mail_bit>=35 && result_mail_bit<=63)begin:g_error_upper
   assign result_mail_guarded[result_mail_bit]=result_mail_raw[result_mail_bit];
  end else begin:g_dynamic
   GTP_LUT1 #(.INIT(2'h2)) u_holdbuf(.I0(result_mail_raw[result_mail_bit]),.Z(result_mail_guarded[result_mail_bit])) /* synthesis syn_noprune=1 */;
  end
 end endgenerate

 reg [23:0] wait_cycles;
 reg wait_carry8,wait_carry16 /* synthesis syn_preserve=1 syn_allow_retiming=0 */;
 reg buffer_valid;
 reg [31:0] verify_mask;
 reg [23:0] verify_last_index;
 reg [4:0] verify_index;
 function [15:0] crc16_byte;
 input [15:0] c;input [7:0] d;
 reg [15:0] v;integer i;begin
 v=c^{d,8'b0};for(i=0;i<8;i=i+1) v=v[15]?(v<<1)^16'h1021:v<<1;
 crc16_byte=v;end endfunction
 function [31:0] crc32_byte;
 input [31:0] c;input [7:0] d;
 reg [31:0] v;integer i;begin
 v=c^{24'b0,d};for(i=0;i<8;i=i+1) v=v[0]?(v>>1)^32'hedb88320:v>>1;
 crc32_byte=v;end endfunction
 assign stream_valid=state==STREAM;
 assign stream_data=buffer_word;
 assign verify_ready=state==VERIFY_WAIT;
 wire [3:0] ram_read_index=state==WORD_READ?native_index[6:3]:
  ((state==STREAM && stream_ready)?beat_index+1'b1:beat_index);
 always @(posedge ui_clk) begin
  buffer_word<=buffer[ram_read_index];
  if(state==DATA_WAIT && spi_done && byte_index[4:0]==31)
   buffer[byte_index[8:5]]<=buffer_write_held;
 end
 always @(posedge ui_clk or posedge ui_rst)
 if(ui_rst) begin
  req_meta<=0;req_sync<=0;ack_toggle<=0;request_seen<=0;state<=IDLE;
  native_op<=0;native_arg<=0;native_seed<=0;native_index<=0;native_div<=200;native_div_ticks<=199;
  chip_select<=1;spi_start<=0;spi_tx<=255;pack_shift<=0;byte_index<=0;
  beat_index<=0;beat_last<=0;block_crc<=0;received_crc_hi<=0;
  remaining<=0;file_crc<=0;blocks<=0;bytes_received<=0;error<=0;value<=0;
  cycles<=0;wait_cycles<=0;wait_carry8<=0;wait_carry16<=0;buffer_valid<=0;verify_mask<=0;verify_index<=0;verify_last_index<=0;
  res_value_hold<=0;res_error_hold<=0;res_crc_hold<=0;res_blocks_hold<=0;
  res_bytes_hold<=0;res_cycles_lo_hold<=0;res_cycles_hi_hold<=0;
 end else begin
  req_meta<=request_toggle;req_sync<=req_meta;spi_start<=0;
  if(state!=IDLE && state!=FINISH) begin
   cycles<=cycles+1'b1;
   wait_cycles[7:0]<=wait_cycles[7:0]+8'd1;
   wait_cycles[15:8]<=wait_cycles[15:8]+{7'b0,wait_carry8};
   wait_cycles[23:16]<=wait_cycles[23:16]+{7'b0,wait_carry16};
   wait_carry8<=wait_cycles[7:0]==8'hfe;wait_carry16<=wait_cycles[15:0]==16'hfffe;
  end
  case(state)
   IDLE:if(req_sync!=request_seen) begin
    request_seen<=req_sync;native_op<=cmd_op_hold;native_arg<=cmd_arg_hold;
    native_div<=cmd_div_hold[15:0];native_div_ticks<=cmd_div_hold[15:0]-16'd1;chip_select<=cmd_cs_hold[0];
    native_seed<=cmd_seed_hold;native_index<=cmd_index_hold;
    error<=0;value<=0;blocks<=0;bytes_received<=0;cycles<=0;wait_cycles<=0;wait_carry8<=0;wait_carry16<=0;
    state<=CHECK;
   end
   CHECK:begin
    if(native_div<4 || (native_op!=1 && native_op!=2 && native_op!=3 && native_op!=4 && native_op!=258)) begin error<=1;state<=FINISH;end
    else if(native_op==1) state<=RAW;
    else if(native_op==3) begin
     if(!buffer_valid || native_index>=128) begin error<=1;state<=FINISH;end
     else state<=WORD_READ;
    end else if(native_arg==0 || native_arg>32'h01000000 || (native_op==2 && native_arg!=512)) begin error<=1;state<=FINISH;end
    else state<=PREP;
   end
   // Separate parameter validation from the 32-bit counter load enable.
   PREP:begin
    remaining<=native_arg[24:0];file_crc<=native_seed;buffer_valid<=0;
    verify_last_index<=native_arg-32'd1;
    state<=native_op==4?VERIFY_WAIT:TOKEN;
   end
   RAW:begin spi_tx<=native_arg[7:0];spi_start<=1;state<=RAW_WAIT;end
   RAW_WAIT:if(spi_done) begin value<={24'b0,spi_rx};state<=FINISH;end
   TOKEN:begin spi_tx<=255;spi_start<=1;state<=TOKEN_WAIT;end
   TOKEN_WAIT:if(spi_done) begin
    if(spi_rx==254) begin byte_index<=0;pack_shift<=0;block_crc<=0;wait_cycles<=0;wait_carry8<=0;wait_carry16<=0;state<=DATA;end
    else if(spi_rx!=255) begin error<=3;value<={24'b0,spi_rx};state<=FINISH;end
    else state<=TOKEN;
   end
   DATA:begin spi_tx<=255;spi_start<=1;state<=DATA_WAIT;end
   DATA_WAIT:if(spi_done) begin
    pack_shift<=buffer_write_held;block_crc<=crc16_byte(block_crc_guarded,spi_rx);
    if({23'b0,byte_index}<remaining) begin
     file_crc<=crc32_byte(result_mail_guarded[95:64],spi_rx);bytes_received<=bytes_received+1'b1;
    end
    wait_cycles<=0;wait_carry8<=0;wait_carry16<=0;
    if(byte_index==511) state<=CRC_HI;
    else begin byte_index<=byte_index+1'b1;state<=DATA;end
   end
   CRC_HI:begin spi_tx<=255;spi_start<=1;state<=CRC_HI_WAIT;end
   CRC_HI_WAIT:if(spi_done) begin received_crc_hi<=spi_rx;state<=CRC_LO;end
   CRC_LO:begin spi_tx<=255;spi_start<=1;state<=CRC_LO_WAIT;end
   CRC_LO_WAIT:if(spi_done) begin
    if({received_crc_hi,spi_rx}!=block_crc) begin error<=4;state<=FINISH;end
    else begin
     blocks<=blocks+1'b1;buffer_valid<=1;beat_index<=0;wait_cycles<=0;wait_carry8<=0;wait_carry16<=0;
     beat_last<=remaining>=512?4'd15:(remaining[8:0]-1'b1)>>5;
     if(native_op==2) state<=FINISH;else state<=RAM_WAIT;
    end
   end
   RAM_WAIT:state<=STREAM;
   STREAM:if(stream_ready) begin
    wait_cycles<=0;wait_carry8<=0;wait_carry16<=0;
    if(beat_index==beat_last) begin
     if(remaining<=512) state<=FINISH;
     else begin remaining<=remaining-512;buffer_valid<=0;state<=TOKEN;end
    end else beat_index<=beat_index+1'b1;
   end
   WORD_READ:state<=WORD_WAIT;
   WORD_WAIT:begin value<=buffer_word>>(native_index[2:0]*32);state<=FINISH;end
   VERIFY_WAIT:if(verify_valid) begin
    pack_shift<=verify_data;verify_mask<=verify_keep;verify_index<=0;wait_cycles<=0;wait_carry8<=0;wait_carry16<=0;
    state<=VERIFY_BYTES;
   end
   VERIFY_BYTES:begin
    wait_cycles<=0;wait_carry8<=0;wait_carry16<=0;pack_shift<={8'b0,buffer_write_held[247:0]};verify_mask<=verify_mask>>1;
    if(verify_mask[0]) begin
     file_crc<=crc32_byte(result_mail_guarded[95:64],pack_shift[7:0]);bytes_received<=bytes_received+1'b1;
     if(bytes_received>=native_arg) begin error<=5;state<=FINISH;end
     else if(bytes_received==verify_last_index) begin
      // No asserted mask bits may follow the requested final byte.
      if(verify_mask[31:1]!=0) error<=5;
      state<=FINISH;
     end else if(verify_index==31) state<=VERIFY_WAIT;
    end else if(bytes_received<native_arg) begin error<=5;state<=FINISH;end
    else state<=FINISH;
    verify_index<=verify_index+1'b1;
   end
   FINISH:begin
    res_value_hold<=result_mail_guarded[31:0];res_error_hold<=result_mail_guarded[63:32];res_crc_hold<=result_mail_guarded[95:64];
    res_blocks_hold<=blocks_guarded;res_bytes_hold<=result_mail_guarded[127:96];
    res_cycles_lo_hold<=result_mail_guarded[159:128];res_cycles_hi_hold<=result_mail_guarded[191:160];
    ack_toggle<=request_seen;state<=IDLE;
   end
  endcase
  // Bounded absence of token/data/consumer; failure leaves CS for firmware CMD12.
  if(state!=IDLE && state!=FINISH && wait_cycles==24'd10000000) begin error<=2;state<=FINISH;end
 end
endmodule
