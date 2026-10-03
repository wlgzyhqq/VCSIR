// FINAL: 32-entry direct-mapped BTB, two-bit saturating direction counters.
// Prediction metadata is captured at fetch acceptance, never recomputed at EX.
module final_btb #(parameter ENABLE=1)(
 input clk, rst, invalidate, input [31:0] lookup_pc,
 output [31:0] next_pc, input update, input [31:0] update_pc,
 input taken, input [31:0] target);
 reg [31:0] tags[0:31], targets[0:31];
 reg [1:0] counters[0:31];
 reg [31:0] valid;
 wire [4:0] idx=lookup_pc[6:2], upd=update_pc[6:2];
 wire hit=ENABLE && valid[idx] && tags[idx]==lookup_pc && counters[idx][1];
 assign next_pc=hit ? targets[idx] : lookup_pc+4;
 integer i;
 always @(posedge clk or posedge rst)
 if(rst) begin
   valid<=0;
   for(i=0;i<32;i=i+1) begin tags[i]<=0; targets[i]<=0; counters[i]<=1; end
 end else if(invalidate) valid<=0;
 else if(update && target[1:0]==0) begin
   valid[upd]<=1;
   tags[upd]<=update_pc; targets[upd]<=target;
   if(!valid[upd] || tags[upd]!=update_pc) counters[upd]<=taken?2:1;
   else if(taken && counters[upd]!=3) counters[upd]<=counters[upd]+1'b1;
   else if(!taken && counters[upd]!=0) counters[upd]<=counters[upd]-1'b1;
 end
endmodule
