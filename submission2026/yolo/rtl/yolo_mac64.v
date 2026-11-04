// Configurable output channels x 8 spatial positions; W8/A8, S32 accumulator.
// BANKS accumulator banks let PXGROUP output tiles accumulate at the same time,
// so one fetched input window serves PXGROUP tiles instead of one. BANKS=1 keeps
// the original single-tile behaviour used by the standalone math tests.
// One registered multiplier stage, then registered accumulation. Caller drains
// the pipeline before observing accumulators or clearing for another tile.
// No saturation here: software proves K*128*127+abs(bias) < 2^31.
module yolo_mac64 #(parameter OC_LANES=8,parameter BANKS=1)(input clk,rst,clear,
 input [2:0] clear_bank,input [2:0] bank,input valid,
 input [OC_LANES*8-1:0] weights,input [63:0] activations,
 input [OC_LANES*32-1:0] biases,output [OC_LANES*256-1:0] accumulators,output reg pending);
 reg signed [31:0] acc[0:BANKS*OC_LANES*8-1];
 genvar b,o,p;
 generate for(b=0;b<BANKS;b=b+1)begin:bn
  for(o=0;o<OC_LANES;o=o+1)begin:oc
   for(p=0;p<8;p=p+1)begin:px
    reg signed [15:0] product;
    wire signed [7:0] w=weights[o*8+:8],a=activations[p*8+:8];
    wire sel_clear=clear&&(clear_bank==b);
    wire sel_acc=pending&&(bank==b);
    always @(posedge clk)begin
     if(valid)product<=w*a;
     if(rst)acc[b*OC_LANES*8+o*8+p]<=0;
     else if(sel_clear)acc[b*OC_LANES*8+o*8+p]<=0;
     else if(sel_acc)acc[b*OC_LANES*8+o*8+p]<=acc[b*OC_LANES*8+o*8+p]+{{16{product[15]}},product};
    end
   end
  end
 end endgenerate
 genvar mo,mp;
 generate for(mo=0;mo<OC_LANES;mo=mo+1)begin:moc
  for(mp=0;mp<8;mp=mp+1)begin:mpx
   assign accumulators[(mo*8+mp)*32+:32]=acc[bank*OC_LANES*8+mo*8+mp];
  end
 end endgenerate
 always @(posedge clk)if(rst||clear)pending<=0;else pending<=valid;
endmodule
