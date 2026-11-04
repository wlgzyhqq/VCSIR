// DMA6: 50 MHz MMIO mailbox, 100 MHz bounded-burst engine and 512-byte buffer.
// CPU holds command payload until completion; UI holds results until next start.
module final_dma(
 input clk,rst,input ui_clk,ui_rst,
 input [31:0] addr,wdata,input [3:0] wstrb,input we,
 output write_ok,output reg [31:0] rdata,
 output [27:0] awaddr,araddr,output [3:0] burst_len,
 output awvalid,arvalid,input awready,arready,wready,rvalid,
 output [255:0] wrdata,output [31:0] wrstrb,input [255:0] rddata,input [2:0] arb_fault,
 input [31:0] cpu_grants,dma_grants,cpu_wait_max,
 // Accelerator interfaces are in ui_clk. RX can be backpressured after DDR
 // data is safely buffered. TX must fill a complete burst before issuing AW.
 output stream_valid,input stream_ready,output [255:0] stream_data,output [31:0] stream_keep,
 input result_valid,output result_ready,input [255:0] result_data,
 output [1:0] diagnostic_control,output storage_selected,verification_selected,linear_input_selected,linear_output_selected
);
 localparam IDLE=0,PLAN=1,AR=2,RD=3,AW=4,WD=5,VERIFY_AR=6,VERIFY_RD=7,
            FILL=8,STREAM=9,RESULT=10,FINISH=11,BUFFER_READY=12,
            BOUND_SRC=13,BOUND_DST=14,DESCRIBE=15,CHECK=16,VALIDATE=17,VERIFY_DRAIN=18,VERIFY_CHECK=19;
 localparam COPY=1,READ_STREAM=2,FILL_PATTERN=3,WRITE_STREAM=4;
 reg [31:0] config_src,config_dst,config_length,config_op,config_seed,config_limit;
 reg [31:0] cmd_src_hold,cmd_dst_hold,cmd_length_hold,cmd_op_hold,cmd_seed_hold,cmd_limit_hold;
 reg request_toggle,busy,done;
 reg [31:0] rejected,status_error,status_bytes,status_cycles,status_read,status_written,status_checksum;
 reg ack_toggle;
 reg [31:0] res_error_hold,res_bytes_hold,res_cycles_hold,res_read_hold,res_written_hold,res_checksum_hold;
 reg [31:0] res_cpu_hold,res_dma_hold,res_wait_hold,res_fault_hold;
 reg [31:0] status_cpu,status_dma,status_wait,status_fault,cpu_begin,dma_begin;
 (* ASYNC_REG="TRUE" *) reg ack_meta,ack_sync,abort_meta,abort_sync,req_meta,req_sync;
 reg abort_toggle,abort_seen,request_seen,abort_epoch_hold;
 assign write_ok=addr[7:2]>=1 && addr[7:2]<=7 && wstrb==4'b1111;
 always @* begin
  case(addr[7:2])
   0:rdata=32'h444d4136;
   1:rdata={29'b0,(status_error!=0),done,busy};
   2:rdata=config_src;3:rdata=config_dst;4:rdata=config_length;5:rdata=config_op;
   6:rdata=config_seed;7:rdata=config_limit;8:rdata=status_error;9:rdata=status_bytes;
   10:rdata=status_cycles;11:rdata=status_read;12:rdata=status_written;
   13:rdata=status_checksum;14:rdata=rejected;15:rdata=32'd100000000;
   16:rdata=status_cpu;17:rdata=status_dma;18:rdata=status_wait;19:rdata=status_fault;
   default:rdata=0;
  endcase
 end
 always @(posedge clk or posedge rst)
 if(rst) begin
  config_src<=0;config_dst<=0;config_length<=0;config_op<=0;config_seed<=0;config_limit<=1000000;
  cmd_src_hold<=0;cmd_dst_hold<=0;cmd_length_hold<=0;cmd_op_hold<=0;cmd_seed_hold<=0;cmd_limit_hold<=0;
  request_toggle<=0;busy<=0;done<=0;rejected<=0;status_error<=0;status_bytes<=0;
  status_cycles<=0;status_read<=0;status_written<=0;status_checksum<=0;
  status_cpu<=0;status_dma<=0;status_wait<=0;status_fault<=0;
  ack_meta<=0;ack_sync<=0;abort_toggle<=0;abort_epoch_hold<=0;
 end else begin
  ack_meta<=ack_toggle;ack_sync<=ack_meta;
  if(busy && ack_sync==request_toggle) begin
   busy<=0;done<=1;status_error<=res_error_hold;status_bytes<=res_bytes_hold;
   status_cycles<=res_cycles_hold;status_read<=res_read_hold;status_written<=res_written_hold;
   status_checksum<=res_checksum_hold;
   status_cpu<=res_cpu_hold;status_dma<=res_dma_hold;status_wait<=res_wait_hold;status_fault<=res_fault_hold;
  end
  if(we && write_ok) begin
   if(addr[7:2]==1) begin
    if(wdata[1]) done<=0;
    if(wdata[2] && busy) begin abort_toggle<=~abort_toggle;abort_epoch_hold<=request_toggle;end
    if(wdata[0]) begin
     if(busy) rejected<=rejected+1'b1;
     else begin
      cmd_src_hold<=config_src;cmd_dst_hold<=config_dst;cmd_length_hold<=config_length;
      cmd_op_hold<=config_op;cmd_seed_hold<=config_seed;cmd_limit_hold<=config_limit;
      request_toggle<=~request_toggle;busy<=1;done<=0;status_error<=0;
     end
    end
   end else if(addr[7:2]>=2 && addr[7:2]<=7) begin
    if(busy) rejected<=rejected+1'b1;
    else case(addr[7:2])
     2:config_src<=wdata;3:config_dst<=wdata;4:config_length<=wdata;
     5:config_op<=wdata;6:config_seed<=wdata;7:config_limit<=wdata;
    endcase
   end
  end
 end
 reg [4:0] state;
 reg [31:0] native_src,native_dst,native_left,native_op,native_seed,native_limit;
 reg [31:0] cycles,read_bytes,written_bytes,completed_bytes,checksum;
 // Six direct counters plus low5 error/low3 fault bits have held-result protection.
 wire [167:0] result_tail_raw={error[4:0],arb_fault,cpu_wait_max,checksum,written_bytes,cycles,completed_bytes};
 wire [167:0] result_tail_guarded /* synthesis syn_keep=1 */;
 genvar tail_mail_bit;
 generate for(tail_mail_bit=0;tail_mail_bit<168;tail_mail_bit=tail_mail_bit+1)begin:g_dma_tail_mail_hold
  GTP_LUT1 #(.INIT(2'h2)) u_holdbuf(.I0(result_tail_raw[tail_mail_bit]),.Z(result_tail_guarded[tail_mail_bit])) /* synthesis syn_noprune=1 */;
 end endgenerate
 wire [31:0] read_bytes_guarded /* synthesis syn_keep=1 */;
 genvar read_mail_bit;
 generate for(read_mail_bit=0;read_mail_bit<32;read_mail_bit=read_mail_bit+1)begin:g_dma_read_mail_hold
  GTP_LUT1 #(.INIT(2'h2)) u_holdbuf(.I0(read_bytes[read_mail_bit]),.Z(read_bytes_guarded[read_mail_bit])) /* synthesis syn_noprune=1 */;
 end endgenerate
 reg [23:0] wait_cycles;
 reg wait_carry8,wait_carry16 /* synthesis syn_preserve=1 syn_allow_retiming=0 */;
 reg [9:0] block_bytes;
 reg [3:0] beats_last,index;
 reg abort_valid,abort_epoch_seen,verify_bad;
 reg verify_sample_valid,verify_sample_bad;
 reg verify_reduce_valid;
 reg [7:0] verify_sample_lanes;
 integer verify_lane;
 wire abort_pending=abort_valid && abort_epoch_seen==request_seen;
 reg [31:0] tail_mask;
 reg [31:0] error;
 // 16 words, 256 bits each; at most one burst can arrive without backpressure.
 // Deliberately no reset/clear: each active entry is overwritten before use.
 reg [255:0] buffer [0:15] /* synthesis syn_ramstyle = "block_ram" */;
 reg [255:0] buffer_word;
 reg [9:0] plan_bytes;
 reg [12:0] src_room,dst_room;
 always @* begin
  src_room=13'd4096-{1'b0,native_src[11:0]};
  dst_room=13'd4096-{1'b0,native_dst[11:0]};
  plan_bytes=native_left>512?10'd512:native_left[9:0];
 end
 wire [10:0] rounded_plan={1'b0,block_bytes}+11'd31;
 wire [31:0] byte_mask=index==beats_last?tail_mask:32'hffffffff;
 wire [31:0] pattern_base=(native_dst>>2)+{26'b0,index,3'b0};
 wire [255:0] pattern_data={native_seed^(pattern_base+7),native_seed^(pattern_base+6),
  native_seed^(pattern_base+5),native_seed^(pattern_base+4),native_seed^(pattern_base+3),
  native_seed^(pattern_base+2),native_seed^(pattern_base+1),native_seed^pattern_base};
 assign awaddr=native_dst[29:2];
 assign araddr=(state==VERIFY_AR || state==VERIFY_RD)?native_dst[29:2]:native_src[29:2];
 assign burst_len=beats_last;
 // Bit 8 injects a pre-issue timeout. It never cancels accepted native traffic.
 assign awvalid=state==AW && !native_op[8];
 assign arvalid=(state==AR || state==VERIFY_AR) && !native_op[8];
 assign wrdata=buffer_word;
 assign wrstrb=byte_mask;
 assign stream_valid=state==STREAM;
 assign stream_data=buffer_word;
 assign stream_keep=byte_mask;
 assign result_ready=state==RESULT;
 assign diagnostic_control={native_op[10],native_op[9]};
 assign storage_selected=native_op[11] && native_op[7:0]==WRITE_STREAM;
 assign linear_input_selected=native_op[12] && native_op[7:0]==READ_STREAM;
 assign linear_output_selected=native_op[12] && native_op[7:0]==WRITE_STREAM;
 assign verification_selected=native_op[11] && native_op[7:0]==READ_STREAM;
 wire read_event=(state==RD || (state==AR && arready)) && rvalid;
 wire verify_event=(state==VERIFY_RD || (state==VERIFY_AR && arready)) && rvalid;
 wire write_event=(state==WD || (state==AW && awready)) && wready;
 reg [255:0] expanded_mask;
 integer b;
 integer m;
 always @* for(b=0;b<32;b=b+1) expanded_mask[b*8+:8]={8{byte_mask[b]}};
 wire [255:0] masked_stream=buffer_word & expanded_mask;
 wire [31:0] stream_xor=masked_stream[31:0]^masked_stream[63:32]^masked_stream[95:64]^
  masked_stream[127:96]^masked_stream[159:128]^masked_stream[191:160]^
  masked_stream[223:192]^masked_stream[255:224];
 reg [32:0] src_end,dst_end;
 reg bad_format;
 wire needs_src=native_op[7:0]==COPY || native_op[7:0]==READ_STREAM;
 wire needs_dst=native_op[7:0]!=READ_STREAM;
 wire bad_command=bad_format || (needs_src && src_end>33'h040000000) ||
  (needs_dst && dst_end>33'h040000000) ||
  (native_op[7:0]==COPY && {1'b0,native_src}<dst_end && {1'b0,native_dst}<src_end);
 wire advance_buffer=write_event || verify_event || (state==STREAM && stream_ready);
 wire [3:0] buffer_read_index=advance_buffer?(index==beats_last?4'b0:index+1'b1):
                            (state==RD || state==AR || state==FILL || state==RESULT ? 4'b0:index);
 wire buffer_we=read_event || state==FILL || (state==RESULT && result_valid);
 // Select by receive state, not read_event (which contains late fault/valid).
 // When buffer_we is asserted, RD/AR writes rddata, FILL writes pattern_data,
 // RESULT writes result_data. Outside those writes the RAM input is unused.
 wire [255:0] buffer_input=(state==RD || state==AR)?rddata:(state==FILL?pattern_data:result_data);
 // One synchronous read port with look-ahead and one write port. The RAM has
 // no reset. BUFFER_READY provides a warm-up edge after the last captured beat.
 always @(posedge ui_clk) begin
  buffer_word<=buffer[buffer_read_index];
  if(!ui_rst && buffer_we) buffer[index]<=buffer_input;
 end
 always @(posedge ui_clk or posedge ui_rst)
 if(ui_rst) begin
  req_meta<=0;req_sync<=0;request_seen<=0;ack_toggle<=0;abort_meta<=0;abort_sync<=0;abort_seen<=0;
  state<=IDLE;native_src<=0;native_dst<=0;native_left<=0;native_op<=0;native_seed<=0;native_limit<=0;
  cycles<=0;read_bytes<=0;written_bytes<=0;completed_bytes<=0;checksum<=0;wait_cycles<=0;wait_carry8<=0;wait_carry16<=0;
  block_bytes<=0;beats_last<=0;index<=0;abort_valid<=0;abort_epoch_seen<=0;verify_bad<=0;error<=0;
  verify_sample_valid<=0;verify_sample_bad<=0;verify_reduce_valid<=0;verify_sample_lanes<=0;
  src_end<=0;dst_end<=0;bad_format<=0;tail_mask<=0;
  res_error_hold<=0;res_bytes_hold<=0;res_cycles_hold<=0;res_read_hold<=0;res_written_hold<=0;res_checksum_hold<=0;
  res_cpu_hold<=0;res_dma_hold<=0;res_wait_hold<=0;res_fault_hold<=0;cpu_begin<=0;dma_begin<=0;
 end else begin
  req_meta<=request_toggle;req_sync<=req_meta;abort_meta<=abort_toggle;abort_sync<=abort_meta;
  // Pipeline the full-width compare independently of address/count commit.
  verify_sample_valid<=verify_event;
  verify_reduce_valid<=verify_sample_valid;
  if(verify_event)
   for(verify_lane=0;verify_lane<8;verify_lane=verify_lane+1)
    verify_sample_lanes[verify_lane]<=|((rddata[verify_lane*32+:32]^buffer_word[verify_lane*32+:32]) & expanded_mask[verify_lane*32+:32]);
  if(verify_sample_valid) verify_sample_bad<=|verify_sample_lanes;
  if(verify_reduce_valid) verify_bad<=verify_bad|verify_sample_bad;
  if(state!=IDLE && state!=FINISH) begin cycles<=cycles+1'b1;wait_cycles[7:0]<=wait_cycles[7:0]+8'd1;
   wait_cycles[15:8]<=wait_cycles[15:8]+{7'b0,wait_carry8};
   wait_cycles[23:16]<=wait_cycles[23:16]+{7'b0,wait_carry16};
   wait_carry8<=wait_cycles[7:0]==8'hfe;wait_carry16<=wait_cycles[15:0]==16'hfffe;end
  case(state)
   IDLE:if(req_sync!=request_seen) begin
    request_seen<=req_sync;native_src<=cmd_src_hold;native_dst<=cmd_dst_hold;
    native_left<=cmd_length_hold;native_op<=cmd_op_hold;native_seed<=cmd_seed_hold;native_limit<=cmd_limit_hold;
    cycles<=0;read_bytes<=0;written_bytes<=0;completed_bytes<=0;checksum<=0;
    wait_cycles<=0;wait_carry8<=0;wait_carry16<=0;error<=0;
    if(abort_epoch_seen!=req_sync) abort_valid<=0;
    cpu_begin<=cpu_grants;dma_begin<=dma_grants;
    state<=CHECK;
   end
   CHECK:begin
    src_end<={1'b0,native_src}+{1'b0,native_left};
    dst_end<={1'b0,native_dst}+{1'b0,native_left};
    bad_format<=native_left==0 || native_left>32'h01000000 || native_op[7:0]<1 || native_op[7:0]>4 ||
     (native_op & 32'hffffe000)!=0 || (native_op[9] && native_op[7:0]!=WRITE_STREAM) ||
     (native_op[12] && ((native_op[7:0]!=WRITE_STREAM && native_op[7:0]!=READ_STREAM) || native_op[11] || native_op[9] || native_op[10])) ||
     (native_op[11] && ((native_op[7:0]!=WRITE_STREAM && native_op[7:0]!=READ_STREAM) || native_op[9] || native_op[10])) ||
     (native_op[10] && native_op[7:0]!=READ_STREAM) || native_limit<32 || native_limit>32'h00ffffff ||
     (needs_src && (native_src[4:0]!=0 || native_src<32'h02000000)) ||
     (needs_dst && (native_dst[4:0]!=0 || native_dst<32'h02000000));
    state<=VALIDATE;
   end
   VALIDATE:if(bad_command) begin error<=1;state<=FINISH;end else state<=PLAN;
   PLAN:begin
    wait_cycles<=0;wait_carry8<=0;wait_carry16<=0;block_bytes<=plan_bytes;
    index<=0;verify_bad<=0;
    if(abort_pending) begin error<=3;state<=FINISH;end
    else state<=BOUND_SRC;
   end
   BOUND_SRC:begin
    if(needs_src && src_room<block_bytes) block_bytes<=src_room[9:0];
    state<=BOUND_DST;
   end
   BOUND_DST:begin
    if(needs_dst && dst_room<block_bytes) block_bytes<=dst_room[9:0];
    state<=DESCRIBE;
   end
   DESCRIBE:begin
    beats_last<=rounded_plan[8:5]-1'b1;
    for(m=0;m<32;m=m+1) tail_mask[m]<=block_bytes[4:0]==0 || block_bytes[4:0]>m;
    if(native_op[7:0]==COPY || native_op[7:0]==READ_STREAM) state<=AR;
    else if(native_op[7:0]==FILL_PATTERN) state<=FILL;
    else state<=RESULT;
   end
   AR:if(arready) begin state<=RD;wait_cycles<=0;wait_carry8<=0;wait_carry16<=0;end
   AW:if(awready) begin state<=WD;wait_cycles<=0;wait_carry8<=0;wait_carry16<=0;end
   VERIFY_AR:if(arready) begin state<=VERIFY_RD;wait_cycles<=0;wait_carry8<=0;wait_carry16<=0;end
   FILL:begin
    wait_cycles<=0;wait_carry8<=0;wait_carry16<=0;
    if(index==beats_last) begin index<=0;state<=BUFFER_READY;end else index<=index+1'b1;
   end
   RESULT:if(result_valid) begin
    wait_cycles<=0;wait_carry8<=0;wait_carry16<=0;
    if(index==beats_last) begin index<=0;state<=BUFFER_READY;end else index<=index+1'b1;
   end
   BUFFER_READY:state<=native_op[7:0]==READ_STREAM?STREAM:AW;
   STREAM:if(stream_ready) begin
    checksum<=checksum^stream_xor;wait_cycles<=0;wait_carry8<=0;wait_carry16<=0;
    if(index==beats_last) begin
     completed_bytes<=completed_bytes+block_bytes;
     native_src<=native_src+block_bytes;native_left<=native_left-block_bytes;
     index<=0;state<=native_left==block_bytes?FINISH:PLAN;
    end else index<=index+1'b1;
   end
   VERIFY_DRAIN:begin
    // Drain lane capture and reduction before committing the block.
    wait_cycles<=0;wait_carry8<=0;wait_carry16<=0;state<=VERIFY_CHECK;
   end
   VERIFY_CHECK:begin
    // verify_bad covers preceding beats; sampled_bad is the final beat.
    wait_cycles<=0;wait_carry8<=0;wait_carry16<=0;
    if(verify_bad || verify_sample_bad) begin error<=4;state<=FINISH;end
    else begin
     completed_bytes<=completed_bytes+block_bytes;
     native_src<=native_src+block_bytes;native_dst<=native_dst+block_bytes;
     native_left<=native_left-block_bytes;state<=native_left==block_bytes?FINISH:PLAN;
    end
   end
   FINISH:begin
    res_error_hold<={27'b0,result_tail_guarded[167:163]};res_bytes_hold<=result_tail_guarded[31:0];res_cycles_hold<=result_tail_guarded[63:32];
    res_read_hold<=read_bytes_guarded;res_written_hold<=result_tail_guarded[95:64];res_checksum_hold<=result_tail_guarded[127:96];
    res_cpu_hold<=cpu_grants-cpu_begin;res_dma_hold<=dma_grants-dma_begin;
    res_wait_hold<=result_tail_guarded[159:128];res_fault_hold<={29'b0,result_tail_guarded[162:160]};
    ack_toggle<=request_seen;state<=IDLE;abort_valid<=0;
   end
   default:begin end
  endcase
  if(read_event) begin
   read_bytes<=read_bytes+32;wait_cycles<=0;wait_carry8<=0;wait_carry16<=0;
   if(index==beats_last) begin index<=0;state<=BUFFER_READY;end
   else index<=index+1'b1;
  end
  if(write_event) begin
   written_bytes<=written_bytes+32;wait_cycles<=0;wait_carry8<=0;wait_carry16<=0;
   if(index==beats_last) begin index<=0;state<=VERIFY_AR;end else index<=index+1'b1;
  end
  if(verify_event) begin
   read_bytes<=read_bytes+32;wait_cycles<=0;wait_carry8<=0;wait_carry16<=0;
   if(index==beats_last) begin
    index<=0;
    state<=VERIFY_DRAIN;
   end else index<=index+1'b1;
  end
  // Pre-issue injection / stream waits are recoverable. A request already
  // presented to the arbiter cannot be withdrawn: wait for arbiter quarantine.
  if(state!=IDLE && state!=FINISH && {8'b0,wait_cycles}>=native_limit &&
     (state==STREAM || state==RESULT || native_op[8])) begin error<=2;state<=FINISH;end
  if(arb_fault!=0 && state!=IDLE && state!=FINISH) begin error<=32'h10+arb_fault;state<=FINISH;end
  if(abort_pending && (state==STREAM || state==RESULT)) begin error<=3;state<=FINISH;end
  // Associate an abort with its command generation, including one that is
  // still crossing the mailbox. A late abort cannot cancel the next command.
  if(abort_sync!=abort_seen) begin
   abort_seen<=abort_sync;abort_epoch_seen<=abort_epoch_hold;abort_valid<=1;
  end
 end
endmodule
