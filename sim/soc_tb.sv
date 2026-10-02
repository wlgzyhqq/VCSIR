`timescale 1ns/1ps
module soc_tb;
reg clk=0,rstn=0; always #10 clk=~clk;
reg [1:0] keys=3;reg uart_rx=1;wire uart_tx;wire [7:0] led;tri [1:0] gpio;
parameter PREDICT_ENABLE=1;
final_top #(.PREDICT_ENABLE(PREDICT_ENABLE),.MEM_DELAY(3),.CLK_HZ(50000000),.BAUD(1000000)) dut(
 .clk(clk),.rstn(rstn),.keys_n(keys),.uart_rx(uart_rx),.uart_tx(uart_tx),.led(led),.gpio(gpio));
string image, wavefile;
integer cycles=0,retired=0,branches=0,mispredicts=0,istalls=0,dstalls=0;
integer ibursts=0,dbursts=0,wbursts=0,readbeats=0,writebeats=0;
integer uart_bytes=0;
reg [7:0] uart_byte;integer bitidx;
reg interactive=0;
reg i_hold=0,d_hold=0;reg [31:0] i_saved,d_saved;reg [6:0] i_ctrl,d_ctrl;
initial begin
 if(!$value$plusargs("image=%s",image)) $fatal(1,"missing +image");
 #1;$readmemh(image,dut.u_bus.ram);
 if($value$plusargs("wave=%s",wavefile)) begin
   $dumpfile(wavefile);$dumpvars(1,dut.u_cpu.u_core);
   $dumpvars(1,dut.u_cpu.u_core.u_fetch);
   $dumpvars(1,dut.u_cpu.u_core.u_exec);
   $dumpvars(1,dut.u_cpu.u_core.u_issue);
 end
 interactive=$test$plusargs("interactive");
 repeat(10) @(posedge clk);rstn<=1;
end
// Observe real serialized UART TX, not just a software/MMIO write.
initial forever begin
 @(negedge uart_tx);repeat(75) @(posedge clk);
 for(bitidx=0;bitidx<8;bitidx=bitidx+1) begin
   uart_byte[bitidx]=uart_tx;repeat(50) @(posedge clk);
 end
 if(uart_tx!==1) $fatal(1,"UART bad stop bit");
 uart_bytes=uart_bytes+1;$write("%c",uart_byte);
end
always @(posedge clk) if(rstn) begin
 cycles<=cycles+1;
 if(dut.u_cpu.u_core.u_issue.pipe_valid_wb_w) retired<=retired+1;
 if(dut.u_cpu.u_core.predictor_update_w) branches<=branches+1;
 if(dut.u_cpu.u_core.predictor_redirect_w) mispredicts<=mispredicts+1;
 if(dut.u_cpu.icache_rd_w && !dut.u_cpu.icache_accept_w) istalls<=istalls+1;
 if((dut.u_cpu.dcache_rd_w || |dut.u_cpu.dcache_wr_w) && !dut.u_cpu.dcache_accept_w) dstalls<=dstalls+1;
 if(dut.axi_i_arvalid && dut.axi_i_arready && dut.axi_i_arlen!=0) ibursts<=ibursts+1;
 if(dut.axi_d_arvalid && dut.axi_d_arready && dut.axi_d_arlen!=0) dbursts<=dbursts+1;
 if(dut.axi_d_awvalid && dut.axi_d_awready && dut.axi_d_awlen!=0) wbursts<=wbursts+1;
 if(dut.axi_d_rvalid && dut.axi_d_rready) readbeats<=readbeats+1;
 if(dut.axi_d_wvalid && dut.axi_d_wready) writebeats<=writebeats+1;
 // AXI data and response controls must remain stable under backpressure.
 if(i_hold && (!dut.axi_i_rvalid || dut.axi_i_rdata!==i_saved || {dut.axi_i_rresp,dut.axi_i_rid,dut.axi_i_rlast}!==i_ctrl))
   $fatal(1,"instruction AXI response changed under backpressure");
 if(d_hold && (!dut.axi_d_rvalid || dut.axi_d_rdata!==d_saved || {dut.axi_d_rresp,dut.axi_d_rid,dut.axi_d_rlast}!==d_ctrl))
   $fatal(1,"data AXI response changed under backpressure");
 i_hold<=dut.axi_i_rvalid && !dut.axi_i_rready;
 d_hold<=dut.axi_d_rvalid && !dut.axi_d_rready;
 i_saved<=dut.axi_i_rdata;d_saved<=dut.axi_d_rdata;
 i_ctrl<={dut.axi_i_rresp,dut.axi_i_rid,dut.axi_i_rlast};
 d_ctrl<={dut.axi_d_rresp,dut.axi_d_rid,dut.axi_d_rlast};
 if(cycles>600000) $fatal(1,"TIMEOUT pc=%h",dut.u_cpu.u_core.opcode_pc_w);
 if(dut.u_bus.completion_reg!=0 && dut.u_bus.completion_reg!=1)
   $fatal(1,"FAIL signature %h pc=%h",dut.u_bus.completion_reg,dut.u_cpu.u_core.opcode_pc_w);
end
initial begin
 wait(dut.u_bus.completion_reg==1);
 if(interactive) begin
   wait(!dut.u_bus.tx_busy);repeat(600) @(posedge clk);
   if(uart_bytes!=21) $fatal(1,"demo UART byte count %d",uart_bytes);
   keys=2;repeat(2000) @(posedge clk);
   if(led!==8'ha5) $fatal(1,"key did not update LEDs: %h",led);
   keys=3;repeat(2000) @(posedge clk);
   if(led!==1) $fatal(1,"key release did not update LEDs: %h",led);
 end
 $display("\nPASS cycles=%0d retired=%0d branches=%0d mispredicts=%0d istall=%0d dstall=%0d Ibursts=%0d Dbursts=%0d Wbursts=%0d Rbeats=%0d Wbeats=%0d",cycles,retired,branches,mispredicts,istalls,dstalls,ibursts,dbursts,wbursts,readbeats,writebeats);
 $finish;
end
endmodule
