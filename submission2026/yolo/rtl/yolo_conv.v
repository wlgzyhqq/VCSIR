// One NCHW convolution output-channel group (1..8 channels). PXGROUP output
// tiles of eight spatial positions share each fetched input window, so one
// 32-byte-granular burst feeds PXGROUP*8 pixels instead of eight. That is the
// measured bottleneck: the original engine issued one 64-byte read per tile and
// spent about 59 cycles per burst for about 9 cycles of MAC work.
// Config must remain stable while busy. Native addresses are byte_address/4,
// 32-byte aligned, with one outstanding burst and no RREADY or write response.
module yolo_conv #(parameter WATCHDOG_BITS=24,MAC_LANES=8,PXGROUP=2)(input clk,rst,start,input [2:0] arb_fault,
 input [31:0] input_base,output_base,weight_base,bias_base,mult_base,shift_base,lut_base,
 input [8:0] width,height,out_width,out_height,input [9:0] channels,
 input [3:0] output_channels,kernel,input [1:0] stride,padding,
 input [11:0] weight_stride,input [31:0] input_plane,output_plane,
 input silu,out16,input cache_use,cache_load,output reg busy,done,output reg [7:0] error,
 output reg [31:0] cycles,read_bytes,write_bytes,
 output [27:0] araddr,awaddr,output [3:0] len,output arvalid,awvalid,
 input arready,awready,rvalid,wready,input [255:0] rdata,
 output [255:0] wdata,output [31:0] wstrb);
 localparam SPAN=PXGROUP*8-1;
 localparam I_IDLE=0,I_AR=1,I_RD=2,I_AW=3,I_WD=4,I_LOCK=5;
 reg [2:0] io_state;reg io_go,io_write;reg [31:0] io_address;
 reg [3:0] io_len,io_beat;reg [255:0] io_data;reg [31:0] io_mask;
 reg io_done;reg [WATCHDOG_BITS-1:0] watchdog;reg io_fault;
 reg [255:0] packet[0:15] /* synthesis syn_ramstyle="block_ram" */;
 localparam CACHE_WORDS=1024;
 reg [255:0] cache[0:CACHE_WORDS-1] /* synthesis syn_ramstyle="block_ram" */;
 reg [1:0] cache_wcnt;reg [11:0] cache_raddr;reg [255:0] cache_q;reg cache_loading;reg [11:0] cache_base;reg [18:0] cache_lo;
 reg [255:0] packet_q,head0,head1,head2,head3;reg [8:0] byte_index;
 assign araddr=io_address[29:2];assign awaddr=io_address[29:2];assign len=io_len;
 assign arvalid=io_state==I_AR;assign awvalid=io_state==I_AW;
 assign wdata=io_data;assign wstrb=io_mask;
 wire reading=(io_state==I_RD)||(arvalid&&arready);
 wire writing=(io_state==I_WD)||(awvalid&&awready);
 always @(posedge clk)begin
  packet_q<=packet[byte_index[8:5]];
  cache_q<=cache[cache_raddr];
  if(reading&&rvalid)begin
   packet[io_beat]<=rdata;
   if(cache_loading)cache[cache_base+io_beat]<=rdata;
  end
 end
 always @(posedge clk)begin
  if(rst)begin io_state<=I_IDLE;io_done<=0;io_beat<=0;watchdog<=0;io_fault<=0;end
  else begin
   io_done<=0;
   if(io_state==I_IDLE)watchdog<=0;else watchdog<=watchdog+1'b1;
   case(io_state)
    I_IDLE:if(io_go)begin io_state<=io_write?I_AW:I_AR;io_beat<=0;end
    I_AR:if(arready)io_state<=I_RD;
    I_AW:if(awready)io_state<=I_WD;
    default:begin end
   endcase
   if(reading&&rvalid)begin
    if(io_beat==io_len)begin io_done<=1;io_state<=I_IDLE;end else io_beat<=io_beat+1'b1;
   end
   if(writing&&wready)begin io_done<=1;io_state<=I_IDLE;end
   // A late native beat must never be interpreted as a subsequent command.
   if(arb_fault!=0 || (io_state!=I_IDLE&&io_state!=I_LOCK&&(&watchdog)))begin io_fault<=1;io_state<=I_LOCK;end
  end
 end
 reg signed [7:0] weights[0:7][0:2047] /* synthesis syn_ramstyle="block_ram" */;
 reg [7:0] lut[0:255] /* synthesis syn_ramstyle="block_ram" */;
 reg [63:0] weight_q;reg [7:0] lut_q;
 reg [31:0] biases[0:7],multipliers[0:7];reg [5:0] shifts[0:7];
 reg [10:0] weight_index;reg [2:0] load_oc,oc,pixel,bank;reg [11:0] loaded,chunk_bytes;
 reg [2:0] section;reg [8:0] row_y,tile_x,ci;reg [3:0] ky,kx;
 reg [31:0] plane_offset;reg row_valid;reg signed [10:0] window_offset;
 reg [127:0] packed_values;reg [511:0] write_buffer;reg [63:0] write_mask;
 reg [31:0] write_address;
 reg upper_half;
 reg [31:0] plane_address,weight_row_base;
 reg signed [21:0] row_offset_q;reg signed [11:0] origin_q;reg [31:0] xmin_q;
 reg [4:0] output_offset;
 // One burst covers every tile of the group plus the kernel halo.
 wire [3:0] banks_max=PXGROUP;
 wire [9:0] px_left=out_width-tile_x;
 wire [4:0] need_banks=(px_left+9'd7)>>3;
 wire [3:0] banks=need_banks>banks_max?banks_max:need_banks[3:0];
 wire [9:0] fetch_need=10'd32+({6'b0,kernel}-10'd1)+(({4'b0,banks}*10'd8)-10'd1)*((stride==2)?10'd2:10'd1);
 wire [4:0] fetch_beats=(fetch_need+10'd31)>>5;
 wire [9:0] fetch_bytes=fetch_beats*10'd32;
 wire [1023:0] window_data={head3,head2,head1,head0};
 reg [5:0] state;
 localparam IDLE=0,VALIDATE=1,META=2,META_WAIT=3,LUT_WAIT=4,LUT_LOAD=5,LUT_GAP=6,
 WREQ=7,WWAIT=8,WLOAD=9,WGAP=10,GCLEAR=11,FETCH=12,FWAIT=13,MWAIT=14,MPROD=15,MADD=16,
 QSTART=17,QWAIT=18,QPACK=19,WSET=20,WSTART=21,WDONE=22,NEXT=23,FINISH=24,FAIL=25,APREP=26,WADDR=27,WSHIFT=28,QISSUE=29,
 GCLR=30,QNEXT=31,CLOAD_A=32,CLOAD_B=33,CRD=34,CRW=39,CRC=40,CLIMIT=41;
 integer g;
 wire [255:0] bias_vector={biases[7],biases[6],biases[5],biases[4],biases[3],biases[2],biases[1],biases[0]};
 reg [63:0] activation_vector,activation_q;wire [MAC_LANES*256-1:0] sums;wire mac_pending;
 wire [MAC_LANES*8-1:0] active_weights=MAC_LANES==4?(upper_half?weight_q[63:32]:weight_q[31:0]):weight_q;
 wire [MAC_LANES*32-1:0] active_biases=MAC_LANES==4?(upper_half?bias_vector[255:128]:bias_vector[127:0]):bias_vector;
 yolo_mac64 #(.OC_LANES(MAC_LANES),.BANKS(PXGROUP)) mac(.clk(clk),.rst(rst),.clear(state==GCLR),.clear_bank(bank),.bank(bank),
  .valid(state==MPROD),.weights(active_weights),.activations(activation_q),.biases(active_biases),.accumulators(sums),.pending(mac_pending));
 wire qready;wire signed [15:0] qvalue;
 wire [2:0] accumulator_oc=MAC_LANES==4?{1'b0,oc[1:0]}:oc;
 reg signed [31:0] q_accumulator;reg [30:0] q_multiplier;reg [5:0] q_shift;
 yolo_requant requant(.clk(clk),.rst(rst),.valid(state==QISSUE),.accumulator(q_accumulator),
  .multiplier(q_multiplier),.shift(q_shift),.out16(out16),.ready(qready),.value(qvalue));
 reg signed [15:0] quantized;
 integer weight_bank;
 always @(posedge clk)begin
  for(weight_bank=0;weight_bank<8;weight_bank=weight_bank+1)weight_q[weight_bank*8+:8]<=weights[weight_bank][weight_index];
  if(state==MWAIT)activation_q<=activation_vector;
  lut_q<=lut[qvalue[7:0]];
  if(state==WLOAD)weights[load_oc][loaded+{3'b0,byte_index}]<=packet_q[byte_index[4:0]*8+:8];
  if(state==LUT_LOAD)lut[byte_index[7:0]]<=packet_q[byte_index[4:0]*8+:8];
 end
 // Explicit widths prevent address arithmetic from consuming 32x32 DSPs.
 // Valid strides are1/2, widths/heights <=320, plane bytes <=204800.
 wire signed [11:0] iy=($signed({3'b0,row_y})<<<(stride==2?1:0))+$signed({1'b0,ky})-$signed({1'b0,padding});
 wire signed [11:0] origin=($signed({3'b0,tile_x})<<<(stride==2?1:0))-$signed({1'b0,padding});
 wire [31:0] xmin=origin<0?0:{20'b0,origin};
 wire signed [21:0] row_offset=iy*$signed({1'b0,width});
 wire [20:0] output_channel_offset=oc*output_plane[17:0];
 wire [14:0] weight_channel_offset=load_oc*weight_stride;
 wire [31:0] window_address=plane_address+{{10{row_offset_q[21]}},row_offset_q}+xmin_q;
 wire [8:0] bank_x=tile_x+bank*9'd8;
 wire [8:0] valid_pixels=(out_width-bank_x>=9'd8)?9'd8:(out_width-bank_x);
 wire [4:0] output_bytes=valid_pixels<<(out16?1:0);
 wire [17:0] output_pixel=row_y*out_width+tile_x+bank*9'd8;
 wire [31:0] output_write=output_base+{11'b0,output_channel_offset}+({14'b0,output_pixel}<<(out16?1:0));
 reg [31:0] cache_total;
 wire [18:0] cache_chunk=(cache_total-cache_lo>32'd512)?19'd512:(cache_total-cache_lo);
 wire [31:0] cache_off=window_address-input_base;
 wire [5:0] kernel_squared=kernel==1?1:(kernel==2?4:(kernel==3?9:(kernel==4?16:(kernel==5?25:(kernel==6?36:0)))));
 wire [14:0] dot_length=channels*kernel_squared;
 reg signed [15:0] ix_calc,pos_calc,pix_off;
 integer px;
 always @*begin
  activation_vector=0;ix_calc=0;pos_calc=0;
  for(px=0;px<8;px=px+1)begin
   pix_off=(bank*8+px)*(stride==2?2:1);
   ix_calc=$signed(origin_q)+$signed({12'b0,kx})+pix_off;
   pos_calc=$signed(window_offset)+$signed({12'b0,kx})+pix_off;
   if(row_valid && (tile_x+bank*8+px)<out_width && ix_calc>=0 && ix_calc<width && pos_calc>=0 && pos_calc<fetch_bytes)
    activation_vector[px*8+:8]=window_data[pos_calc[7:0]*8+:8];
  end
 end
 reg [127:0] pack_next;reg [15:0] packed_element;
 always @*begin
  pack_next=packed_values;packed_element=silu?{{8{lut_q[7]}},lut_q}:quantized;
  if(out16)pack_next[pixel*16+:16]=packed_element;
  else pack_next[pixel*8+:8]=packed_element[7:0];
 end
 always @(posedge clk)begin
  if(rst)begin
   state<=IDLE;busy<=0;done<=0;error<=0;cycles<=0;read_bytes<=0;write_bytes<=0;
   io_go<=0;io_write<=0;io_address<=0;io_len<=0;io_data<=0;io_mask<=0;byte_index<=0;
   section<=0;load_oc<=0;loaded<=0;chunk_bytes<=0;weight_index<=0;oc<=0;pixel<=0;bank<=0;
   row_y<=0;tile_x<=0;ci<=0;ky<=0;kx<=0;plane_offset<=0;row_valid<=0;window_offset<=0;
   packed_values<=0;write_buffer<=0;write_mask<=0;write_address<=0;quantized<=0;upper_half<=0;
   cache_loading<=0;cache_wcnt<=0;cache_lo<=0;cache_base<=0;cache_raddr<=0;cache_total<=0;
   head0<=0;head1<=0;head2<=0;head3<=0;
   plane_address<=0;weight_row_base<=0;row_offset_q<=0;origin_q<=0;xmin_q<=0;output_offset<=0;
   for(g=0;g<8;g=g+1)begin biases[g]<=0;multipliers[g]<=0;shifts[g]<=0;end
  end else begin
   io_go<=0;done<=0;if(busy)cycles<=cycles+1'b1;
   if(reading&&rvalid)begin
    if(io_beat==0)head0<=rdata;if(io_beat==1)head1<=rdata;
    if(io_beat==2)head2<=rdata;if(io_beat==3)head3<=rdata;
   end
   case(state)
    IDLE:if(start)begin busy<=1;error<=0;cycles<=0;read_bytes<=0;write_bytes<=0;state<=VALIDATE;end
    VALIDATE:begin
     if(!width||!height||width>320||height>320||!out_width||!out_height||out_width>320||out_height>320||
        !channels||channels>512||!output_channels||output_channels>8||!kernel||kernel>6||!stride||stride>2||
        dot_length>1152||weight_stride<dot_length||weight_stride>2048||weight_stride[4:0]!=0||
        (silu&&out16)||input_base<32'h02000000||output_base<32'h02000000||weight_base<32'h02000000||
        input_base>=32'h3c000000||output_base>=32'h3c000000||weight_base>=32'h3ff00000||
        bias_base<32'h02000000||bias_base>=32'h3ffffe00||mult_base<32'h02000000||mult_base>=32'h3ffffe00||
        shift_base<32'h02000000||shift_base>=32'h3ffffe00||(silu&&(lut_base<32'h02000000||lut_base>=32'h3ffffe00))||
        input_plane>102400||output_plane>204800||input_plane==0||output_plane==0||
        bias_base[4:0]!=0||mult_base[4:0]!=0||shift_base[4:0]!=0||lut_base[4:0]!=0||weight_base[4:0]!=0)
      begin error<=1;state<=FAIL;end
     else if(cache_load)begin cache_total<={22'b0,channels}*input_plane;state<=CLIMIT;end
     else begin section<=0;state<=META;end
    end
    META:begin
     io_address<=section==0?bias_base:(section==1?mult_base:(section==2?shift_base:lut_base));
     io_len<=section==3?7:0;io_write<=0;io_go<=1;state<=META_WAIT;
    end
    META_WAIT:if(io_done)begin
     read_bytes<=read_bytes+(section==3?256:32);
     if(section==3)begin byte_index<=0;state<=LUT_WAIT;end
     else begin
      for(g=0;g<8;g=g+1)begin
       if(section==0)biases[g]<=head0[g*32+:32];
       if(section==1)multipliers[g]<=head0[g*32+:32];
       if(section==2)shifts[g]<=head0[g*32+:6];
      end
      if(section==2&&!silu)begin load_oc<=0;loaded<=0;state<=WADDR;end
      else begin section<=section+1'b1;state<=META;end
     end
    end
    LUT_WAIT:state<=LUT_LOAD;
    LUT_LOAD:if(byte_index==255)begin load_oc<=0;loaded<=0;state<=WADDR;end
     else begin byte_index<=byte_index+1'b1;state<=LUT_GAP;end
    LUT_GAP:state<=LUT_LOAD;
    WADDR:begin weight_row_base<=weight_base+{17'b0,weight_channel_offset};state<=WREQ;end
    WREQ:begin
     chunk_bytes<=weight_stride-loaded>512?12'd512:weight_stride-loaded;
     io_address<=weight_row_base+loaded;
     io_len<=weight_stride-loaded>512?4'd15:((weight_stride-loaded)>>5)-1'b1;
     io_write<=0;io_go<=1;state<=WWAIT;
    end
    WWAIT:if(io_done)begin byte_index<=0;read_bytes<=read_bytes+chunk_bytes;state<=WGAP;end
    WGAP:state<=WLOAD;
    WLOAD:if({3'b0,byte_index}+1==chunk_bytes)begin
     if(loaded+chunk_bytes==weight_stride)begin
      loaded<=0;
      if(load_oc+1==output_channels)begin row_y<=0;tile_x<=0;upper_half<=0;state<=GCLEAR;end
      else begin load_oc<=load_oc+1'b1;state<=WADDR;end
     end else begin loaded<=loaded+chunk_bytes;state<=WREQ;end
    end else begin byte_index<=byte_index+1'b1;state<=WGAP;end
    GCLEAR:begin bank<=0;state<=GCLR;end
    GCLR:if(bank+1==banks)begin bank<=0;ci<=0;ky<=0;kx<=0;weight_index<=0;plane_offset<=0;state<=APREP;end
     else bank<=bank+1'b1;
    CLIMIT:if(cache_total>32'd32768)begin error<=1;busy<=0;state<=IDLE;end
     else begin cache_loading<=1'b1;cache_lo<=0;state<=CLOAD_A;end
    CLOAD_A:begin
     io_address<=input_base+{13'b0,cache_lo};io_len<=((cache_chunk+19'd31)>>5)-1'b1;io_write<=0;io_go<=1;
     cache_base<=cache_lo[17:5];state<=CLOAD_B;
    end
    CLOAD_B:if(io_done)begin
     read_bytes<=read_bytes+{13'b0,cache_chunk};
     if(cache_lo+cache_chunk>=cache_total)begin cache_loading<=1'b0;cache_lo<=0;section<=0;state<=META;end
     else begin cache_lo<=cache_lo+cache_chunk;state<=CLOAD_A;end
    end
    CRW:state<=CRC;
    CRC:begin
     case(cache_wcnt)2'd0:head0<=cache_q;2'd1:head1<=cache_q;2'd2:head2<=cache_q;default:head3<=cache_q;endcase
     cache_raddr<=cache_raddr+1'b1;
     if({3'b0,cache_wcnt}+5'd1>=fetch_beats)state<=MWAIT;else begin cache_wcnt<=cache_wcnt+1'b1;state<=CRW;end
    end
    APREP:begin
     plane_address<=input_base+plane_offset;row_offset_q<=row_offset;origin_q<=origin;xmin_q<=xmin;
      cache_raddr<=(plane_offset+{{10{row_offset[21]}},row_offset}+xmin)>>5;state<=FETCH;
    end
    FETCH:begin
     row_valid<=iy>=0&&iy<height;window_offset<=$signed({1'b0,window_address[4:0]})+origin_q-$signed({1'b0,xmin_q[10:0]});
     if(iy<0||iy>=height)state<=MWAIT;
     else if(cache_use)begin cache_wcnt<=2'd0;state<=CRC;end
     else begin io_address<={window_address[31:5],5'b0};io_len<=fetch_beats-1'b1;io_write<=0;io_go<=1;state<=FWAIT;end
    end
    FWAIT:if(io_done)begin read_bytes<=read_bytes+{22'b0,fetch_bytes};state<=MWAIT;end
    MWAIT:state<=MPROD;
    MPROD:state<=MADD;
    MADD:begin
     if(bank+1<banks)begin bank<=bank+1'b1;state<=MWAIT;end
     else begin
      bank<=0;
      if(kx+1<kernel)begin kx<=kx+1'b1;weight_index<=weight_index+1'b1;state<=MWAIT;end
      else begin
       kx<=0;weight_index<=weight_index+1'b1;
       if(ky+1<kernel)begin ky<=ky+1'b1;state<=APREP;end
       else if(ci+1<channels)begin ky<=0;ci<=ci+1'b1;plane_offset<=plane_offset+input_plane;state<=APREP;end
       else begin oc<=upper_half?3'd4:3'd0;pixel<=0;packed_values<=0;state<=QSTART;end
      end
     end
    end
    QSTART:if(bank_x>=out_width)state<=QNEXT;
     else begin
      q_accumulator<=sums[(accumulator_oc*8+pixel)*32+:32]+biases[oc];q_multiplier<=multipliers[oc][30:0];q_shift<=shifts[oc];state<=QISSUE;
     end
    QISSUE:state<=QWAIT;
    QWAIT:if(qready)begin quantized<=qvalue;state<=QPACK;end
    QPACK:begin packed_values<=pack_next;if(pixel==7)state<=WSET;else begin pixel<=pixel+1'b1;state<=QSTART;end end
    WSET:begin write_address<={output_write[31:5],5'b0};output_offset<=output_write[4:0];state<=WSHIFT;end
    WSHIFT:begin
     write_buffer<={384'b0,packed_values}<<(output_offset*8);
     write_mask<=((64'd1<<output_bytes)-1'b1)<<output_offset;state<=WSTART;
    end
    WSTART:begin io_address<=write_address;io_len<=0;io_write<=1;io_data<=write_buffer[255:0];io_mask<=write_mask[31:0];io_go<=1;state<=WDONE;end
    WDONE:if(io_done)begin
     if(write_mask[63:32]!=0)begin write_address<=write_address+32;write_buffer<={256'b0,write_buffer[511:256]};write_mask<={32'b0,write_mask[63:32]};state<=WSTART;end
     else begin
      write_bytes<=write_bytes+output_bytes;
      if(oc+1<output_channels&&(MAC_LANES==8||oc[1:0]!=3))begin oc<=oc+1'b1;pixel<=0;packed_values<=0;state<=QSTART;end
      else state<=QNEXT;
     end
    end
    QNEXT:if(bank+1<banks)begin bank<=bank+1'b1;oc<=upper_half?3'd4:3'd0;pixel<=0;packed_values<=0;state<=QSTART;end
     else begin
      bank<=0;
      if(MAC_LANES==4&&!upper_half&&output_channels>4)begin upper_half<=1;state<=GCLEAR;end
      else begin upper_half<=0;state<=NEXT;end
     end
    NEXT:begin
     if(tile_x+banks*9'd8<out_width)begin tile_x<=tile_x+banks*9'd8;state<=GCLEAR;end
     else if(row_y+1<out_height)begin tile_x<=0;row_y<=row_y+1'b1;state<=GCLEAR;end
     else state<=FINISH;
    end
    FINISH,FAIL:begin busy<=0;done<=1;state<=IDLE;end
    default:begin end
   endcase
   if(busy && io_fault)begin error<=2;state<=FAIL;end
  end
 end
endmodule
