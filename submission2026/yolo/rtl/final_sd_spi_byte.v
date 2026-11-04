// SPI mode 0. Divider is UI cycles per half SCK period (4 => 12.5 MHz).
// SD DO changes after a falling SCK edge, and is sampled at the next rise.
module final_sd_spi_byte #(parameter PREPARED_DIVIDER=0)(input clk,rst,start,input [7:0] tx,
 input [15:0] divider,prepared_ticks,input miso,output reg sck,mosi,busy,done,
 output reg [7:0] rx);
 reg [15:0] ticks,half_reload;
 // Default interface retains the original clamp. The SD parent opts into
 // prepared mode only after checking divider>=4, with divider-1 captured
 // alongside the command. Both branches preserve every SCK edge/cycle.
 wire [15:0] requested_reload=PREPARED_DIVIDER?prepared_ticks:(divider<4?16'd3:divider-16'd1);
 wire [15:0] reload_input_held,reload_period_held /* synthesis syn_keep=1 */;
 genvar divider_hold_bit;
 generate for(divider_hold_bit=0;divider_hold_bit<16;divider_hold_bit=divider_hold_bit+1)begin:g_spi_divider_input_hold
  GTP_LUT1 #(.INIT(2'h2)) u_holdbuf(.I0(requested_reload[divider_hold_bit]),.Z(reload_input_held[divider_hold_bit])) /* synthesis syn_noprune=1 */;
 end
 for(divider_hold_bit=0;divider_hold_bit<16;divider_hold_bit=divider_hold_bit+1)begin:g_spi_divider_period_hold
  GTP_LUT1 #(.INIT(2'h2)) u_holdbuf(.I0(half_reload[divider_hold_bit]),.Z(reload_period_held[divider_hold_bit])) /* synthesis syn_noprune=1 */;
 end endgenerate
 reg [2:0] bit_index;
 reg [7:0] tx_shift,rx_shift;
 wire [7:0] rx_guarded /* synthesis syn_keep=1 */;
 genvar rx_hold_bit;
 generate for(rx_hold_bit=0;rx_hold_bit<8;rx_hold_bit=rx_hold_bit+1)begin:g_spi_rx_hold
  GTP_LUT1 #(.INIT(2'h2)) u_holdbuf(.I0(rx_shift[rx_hold_bit]),.Z(rx_guarded[rx_hold_bit])) /* synthesis syn_noprune=1 */;
 end endgenerate
 always @(posedge clk or posedge rst)
 if(rst) begin sck<=0;mosi<=1;busy<=0;done<=0;rx<=0;
  ticks<=0;half_reload<=199;bit_index<=0;tx_shift<=0;rx_shift<=0;end
 else begin
  done<=0;
  if(!busy && start) begin
   busy<=1;sck<=0;mosi<=tx[7];tx_shift<=tx;rx_shift<=0;bit_index<=0;
   half_reload<=reload_input_held;ticks<=reload_input_held;
  end else if(busy) begin
   if(ticks!=0) ticks<=ticks-1'b1;
   else begin
    ticks<=reload_period_held;
    if(!sck) begin sck<=1;rx_shift<={rx_shift[6:0],miso};end
    else begin
     sck<=0;
     if(bit_index==7) begin busy<=0;done<=1;rx<=rx_guarded;mosi<=1;end
     else begin bit_index<=bit_index+1'b1;tx_shift<={tx_shift[6:0],1'b1};mosi<=tx_shift[6];end
    end
   end
  end
 end
endmodule
