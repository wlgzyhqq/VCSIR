// Adapted from Meyesemi / Will pattern_vg.v (2023-01-29).
// Keep the reference one-register video output pipeline, extend pixel colours.
module final_hdmi_reference_pattern(input rstn,pix_clk,input [11:0] act_x,act_y,
 input [1:0] mode,input c_pass,input [3:0] flags,input [10:0] frame,
 input hs_in,vs_in,de_in,output reg hs_out,vs_out,de_out,output reg [23:0] rgb_out);
 reg [23:0] colour;
 always @* begin
  case(mode)
   0:begin
    if(act_x<160) colour=24'hffffff;else if(act_x<320) colour=24'hffff00;
    else if(act_x<480) colour=24'h00ffff;else if(act_x<640) colour=24'h00ff00;
    else if(act_x<800) colour=24'hff00ff;else if(act_x<960) colour=24'hff0000;
    else if(act_x<1120) colour=24'h0000ff;else colour=24'h000000;
   end
   1:colour=(act_x[5]^act_y[5])?24'hffffff:24'h202020;
   2:colour={act_x[10:3],act_y[9:2],8'h80};
   3:begin
    colour=24'h102030;
    if(act_x>={1'b0,frame} && act_x<({1'b0,frame}+12'd64) && act_y>=320 && act_y<384)
     colour=24'hffff00;
   end
  endcase
  if(act_y>=680 && act_y<712) begin
   if(act_x<320) colour=flags[0]?24'h00c040:24'hd09000;
   else if(act_x<640) colour=flags[2]?24'hff00ff:(flags[1]?24'h00c040:24'hd09000);
   else if(act_x<960) colour=c_pass?24'h00c040:24'hd09000;
   else colour=flags[3]?24'h00c040:24'hd09000;
   if(act_x<4 || (act_x>=320 && act_x<324) || (act_x>=640 && act_x<644) ||
      (act_x>=960 && act_x<964)) colour=0;
  end
 end
 always @(posedge pix_clk) begin
  hs_out<=hs_in;vs_out<=vs_in;de_out<=de_in;
  rgb_out<=rstn && de_in?colour:24'b0;
 end
endmodule
