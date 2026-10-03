// 8N1 UART, default 115200 baud at 50 MHz. Single-byte RX holding register.
module final_uart #(parameter CLK_HZ=50000000, BAUD=115200)(
 input clk,rst,rx, input tx_start, input [7:0] tx_data,
 input rx_pop, output reg tx, output tx_busy,
 output reg [7:0] rx_data, output reg rx_valid, output reg rx_overrun);
 localparam DIV=CLK_HZ/BAUD;
 reg [15:0] tx_count,rx_count;
 reg [3:0] tx_bits,rx_bits;
 reg [9:0] tx_shift;
 reg [7:0] rx_shift;
 reg rx_meta,rx_sync;
 reg [1:0] rx_state;
 assign tx_busy=tx_bits!=0;
 always @(posedge clk or posedge rst)
 if(rst) begin
   tx<=1; tx_bits<=0; tx_count<=0; tx_shift<=10'h3ff;
   rx_meta<=1; rx_sync<=1; rx_count<=0; rx_bits<=0;
   rx_shift<=0; rx_data<=0; rx_valid<=0; rx_state<=0; rx_overrun<=0;
 end else begin
   rx_meta<=rx; rx_sync<=rx_meta;
   if(rx_pop) begin rx_valid<=0; rx_overrun<=0; end
   if(tx_start && !tx_busy) begin
     tx_shift<={1'b1,tx_data,1'b0}; tx<=0; tx_bits<=10; tx_count<=DIV-1;
   end else if(tx_busy) begin
     if(tx_count!=0) tx_count<=tx_count-1'b1;
     else begin tx_count<=DIV-1; tx_shift<={1'b1,tx_shift[9:1]};
       tx_bits<=tx_bits-1'b1; tx<=tx_shift[1]; end
   end
   case(rx_state)
   0: if(!rx_sync) begin rx_state<=1; rx_count<=DIV/2-1; end
   1: if(rx_count!=0) rx_count<=rx_count-1'b1;
      else if(!rx_sync) begin rx_state<=2; rx_count<=DIV-1; rx_bits<=0; end
      else rx_state<=0;
   2: if(rx_count!=0) rx_count<=rx_count-1'b1;
      else begin rx_shift[rx_bits]<=rx_sync; rx_count<=DIV-1;
        if(rx_bits==7) rx_state<=3; else rx_bits<=rx_bits+1'b1; end
   3: if(rx_count!=0) rx_count<=rx_count-1'b1;
      else begin rx_state<=0;
        if(rx_sync) begin rx_data<=rx_shift; rx_valid<=1;
          if(rx_valid && !rx_pop) rx_overrun<=1; end end
   endcase
 end
endmodule
