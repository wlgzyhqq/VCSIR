// 8N1 UART. Full RX FIFO drops NEW bytes; errors require explicit W1C.
// Cached head + clocked next-head read permit embedded-memory inference.
module final_uart #(parameter CLK_HZ=50000000, BAUD=115200,
 parameter RX_DEPTH=2048, RX_PTR_BITS=11)(
 input clk,rst,rx, input tx_start, input [7:0] tx_data,
 input rx_pop,rx_flush,clear_overrun,clear_framing,clear_stats,
 output reg tx, output tx_busy,
 output [7:0] rx_data, output rx_valid, output reg rx_overrun,rx_framing,
 output [15:0] rx_level, output reg [15:0] rx_highwater,
 output reg [31:0] rx_total,rx_drops,rx_frame_errors);
 localparam DIV=CLK_HZ/BAUD;
 localparam [RX_PTR_BITS:0] CAPACITY=RX_DEPTH;
 localparam [2:0] IDLE=0,START=1,DATA=2,STOP=3,WAIT_HIGH=4;
 reg [15:0] tx_count,rx_count;
 reg [3:0] tx_bits,rx_bits;
 reg [9:0] tx_shift;
 reg [7:0] rx_shift,head;
 reg rx_meta,rx_sync;
 reg [2:0] rx_state;
 reg [7:0] fifo [0:RX_DEPTH-1];
 reg [RX_PTR_BITS-1:0] rd_ptr,wr_ptr;
 reg [RX_PTR_BITS:0] count;
 wire [RX_PTR_BITS-1:0] rd_next=rd_ptr+1'b1;
 wire good_frame=rx_state==STOP && rx_count==0 && rx_sync;
 wire bad_frame=rx_state==STOP && rx_count==0 && !rx_sync;
 wire pop=rx_pop && count!=0 && !rx_flush;
 wire push=good_frame && (rx_flush || count<CAPACITY || pop);
 wire drop=good_frame && !push;
 wire [RX_PTR_BITS:0] next_count=rx_flush ? (push ? 1 : 0) :
                              count + (push ? 1'b1 : 1'b0) - (pop ? 1'b1 : 1'b0);
 assign tx_busy=tx_bits!=0;
 assign rx_valid=count!=0;
 assign rx_data=rx_valid ? head : 8'b0;
 assign rx_level=count;
 // Array contents are not reset; count marks invalid entries.
 always @(posedge clk) begin
   if(!rst && push) fifo[rx_flush ? {RX_PTR_BITS{1'b0}} : wr_ptr]<=rx_shift;
 end
 always @(posedge clk or posedge rst)
 if(rst) begin rd_ptr<=0;wr_ptr<=0;count<=0;head<=0;end
 else begin
   count<=next_count;
   if(rx_flush) begin
     rd_ptr<=0;wr_ptr<=push ? 1 : 0;head<=push ? rx_shift : 0;
   end else begin
     if(push) wr_ptr<=wr_ptr+1'b1;
     if(pop) rd_ptr<=rd_next;
     if(push && (count==0 || (pop && count==1))) head<=rx_shift;
     else if(pop && count>1) head<=fifo[rd_next];
     else if(pop) head<=0;
   end
 end
 always @(posedge clk or posedge rst)
 if(rst) begin
   rx_overrun<=0;rx_framing<=0;rx_total<=0;rx_drops<=0;
   rx_frame_errors<=0;rx_highwater<=0;
 end else begin
   if(clear_overrun) rx_overrun<=0;
   if(clear_framing) rx_framing<=0;
   if(drop) rx_overrun<=1; // new events win over clears
   if(bad_frame) rx_framing<=1;
   if(clear_stats) begin
     rx_total<=good_frame ? 1 : 0;rx_drops<=drop ? 1 : 0;
     rx_frame_errors<=bad_frame ? 1 : 0;rx_highwater<=next_count;
   end else begin
     if(good_frame && rx_total!=32'hffffffff) rx_total<=rx_total+1'b1;
     if(drop && rx_drops!=32'hffffffff) rx_drops<=rx_drops+1'b1;
     if(bad_frame && rx_frame_errors!=32'hffffffff) rx_frame_errors<=rx_frame_errors+1'b1;
     if(next_count>rx_highwater) rx_highwater<=next_count;
   end
 end
 always @(posedge clk or posedge rst)
 if(rst) begin
   tx<=1;tx_bits<=0;tx_count<=0;tx_shift<=10'h3ff;
   rx_meta<=1;rx_sync<=1;rx_count<=0;rx_bits<=0;rx_shift<=0;rx_state<=IDLE;
 end else begin
   rx_meta<=rx;rx_sync<=rx_meta;
   if(tx_start && !tx_busy) begin
     tx_shift<={1'b1,tx_data,1'b0};tx<=0;tx_bits<=10;tx_count<=DIV-1;
   end else if(tx_busy) begin
     if(tx_count!=0) tx_count<=tx_count-1'b1;
     else begin tx_count<=DIV-1;tx_shift<={1'b1,tx_shift[9:1]};
       tx_bits<=tx_bits-1'b1;tx<=tx_shift[1];end
   end
   case(rx_state)
    IDLE: if(!rx_sync) begin rx_state<=START;rx_count<=DIV/2-1;end
    START: if(rx_count!=0) rx_count<=rx_count-1'b1;
           else if(!rx_sync) begin rx_state<=DATA;rx_count<=DIV-1;rx_bits<=0;end
           else rx_state<=IDLE;
    DATA: if(rx_count!=0) rx_count<=rx_count-1'b1;
          else begin rx_shift[rx_bits]<=rx_sync;rx_count<=DIV-1;
            if(rx_bits==7) rx_state<=STOP;else rx_bits<=rx_bits+1'b1;end
    STOP: if(rx_count!=0) rx_count<=rx_count-1'b1;
          else rx_state<=rx_sync ? IDLE : WAIT_HIGH;
    WAIT_HIGH: if(rx_sync) rx_state<=IDLE;
    default: rx_state<=IDLE;
   endcase
 end
endmodule
