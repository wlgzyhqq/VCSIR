// FINAL: 32-entry direct-mapped BTB, two-bit saturating direction counters.
// Prediction metadata is captured at fetch acceptance, never recomputed at EX.
module final_btb #(parameter ENABLE=1)(
 input clk, rst, invalidate, input [31:0] lookup_pc,
 output [31:0] next_pc, input update, input [31:0] update_pc,
 input taken, input [31:0] target);
 // Training is delayed one cycle; retirement/control flow is unchanged.
 reg update_q,taken_q;
 reg [31:0] update_pc_q,target_q;
 always @(posedge clk or posedge rst)
 if(rst)begin update_q<=0;taken_q<=0;update_pc_q<=0;target_q<=0;end
 else if(invalidate)update_q<=0;
 else begin
  update_q<=update;
  if(update)begin taken_q<=taken;update_pc_q<=update_pc;target_q<=target;end
 end
 reg [26:0] tags[0:31];
 reg [31:0] targets[0:31];
 reg [1:0] counters[0:31];
 reg [31:0] valid;
 wire [4:0] idx=lookup_pc[6:2], upd=update_pc_q[6:2];
 // Given the matching PC[6:2] index, these five PC bits are uniquely
 // determined. Retain low alignment bits, preserving full 32bit PC identity.
 wire [26:0] lookup_tag_w={lookup_pc[31:7],lookup_pc[1:0]};
 wire [26:0] update_tag_w={update_pc_q[31:7],update_pc_q[1:0]};
 wire hit=ENABLE && valid[idx] && tags[idx]==lookup_tag_w && counters[idx][1];
 assign next_pc=hit ? targets[idx] : lookup_pc+4;
 // Identical two-bit saturation, with taken in the data path rather than
 // the clock enable. Each next bit is a three-input Boolean function.
 function [1:0] counter_step;
 input [1:0] c;input t;
 begin
  counter_step[1]=(c[1]&c[0]) | (t&(c[1]|c[0]));
  counter_step[0]=(c[1]&t) | (~c[0]&(c[1]|t));
 end
 endfunction
 integer i;
 always @(posedge clk or posedge rst)
 if(rst) begin
   valid<=0;
   for(i=0;i<32;i=i+1) begin tags[i]<=0; targets[i]<=0; counters[i]<=1; end
 end else if(invalidate) valid<=0;
 else if(update_q && target_q[1:0]==0) begin
   valid[upd]<=1;
   tags[upd]<=update_tag_w; targets[upd]<=target_q;
   if(!valid[upd] || tags[upd]!=update_tag_w) counters[upd]<=taken_q?2:1;
   else counters[upd]<=counter_step(counters[upd],taken_q);
 end
endmodule
