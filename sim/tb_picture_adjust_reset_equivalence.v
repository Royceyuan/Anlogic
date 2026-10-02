`timescale 1ns/1ps
module tb_picture_adjust_reset_equivalence;
reg clk=0,rst_n=0,de=1,test_pass=0;
reg [23:0] rgb=0;
reg [2:0] b=0,c=0,s=0,t=0;
wire [23:0] actual,expected;
integer n,v,checks=0,resets=0;
always #5 clk=~clk;
`define INPUTS .clk(clk),.rst_n(rst_n),.de(de),.rgb_in(rgb), \
 .brightness_index(b),.contrast_index(c),.saturation_index(s),.temperature_index(t)
rgb888_picture_adjust dut(`INPUTS,.rgb_out(actual));
rgb888_picture_adjust_ref reference(`INPUTS,.rgb_out(expected));
`undef INPUTS
always @(negedge clk) begin
 if(actual!==expected) $fatal(1,"color/reset cycle mismatch n=%d rst=%b actual=%h expected=%h",n,rst_n,actual,expected);
 if(rst_n && dut.de_q && (dut.cr!==reference.cr || dut.cg!==reference.cg || dut.cb!==reference.cb))
   $fatal(1,"contrast/brightness width overflow");
 if(rst_n && dut.de_q2 && (dut.y_q!==reference.y_q || dut.dr_q!==reference.dr_q || dut.dg_q!==reference.dg_q || dut.db_q!==reference.db_q))
   $fatal(1,"luma/delta width overflow");
 checks=checks+1;
end
initial begin
 repeat(3) @(negedge clk);
 #1 rst_n=1;
 // All 4096 encoded parameter combinations and 256 levels per channel.
 // Green is a permutation; blue XOR covers every value as well.
 for(n=0;n<1048576;n=n+1) begin
   @(negedge clk); #1;
   b=n>>17;c=n>>14;s=n>>11;t=n>>8;v=n&255;
   rgb[23:16]=v;rgb[15:8]=v*37+(n>>8);rgb[7:0]=v^(n>>8);
   de=1;
 end
 // All RGB cube corners for each encoded parameter tuple (clamp extremes).
 for(n=0;n<32768;n=n+1) begin
   @(negedge clk); #1;
   b=n>>12;c=n>>9;s=n>>6;t=n>>3;
   rgb={{8{n[2]}},{8{n[1]}},{8{n[0]}}};de=1;
 end
 // Blanking and reset at every phase, including pulses shorter than a clock.
 for(n=0;n<200000;n=n+1) begin
   @(negedge clk); #1;
   rgb=$random;b=$random;c=$random;s=$random;t=$random;de=$random;
   if(n%97==0) begin
     #1 rst_n=0;resets=resets+1;
     #1;
     if(actual!==24'd0 || expected!==24'd0) $fatal(1,"asynchronous reset not black");
     #1 rst_n=1;
   end
   if(n%1009==0) begin
     #1 rst_n=0;resets=resets+1;
     repeat(3) @(negedge clk);
     #1 rst_n=1;
   end
 end
 // Continuous DE=1 immediately on release: no unknown/old data may leak.
 @(negedge clk); #1;rst_n=0;de=1;rgb=24'hffffff;b=6;c=4;s=5;t=6;
 #2 rst_n=1;
 repeat(8) @(negedge clk);
 if(actual!==expected || (^actual)===1'bx) $fatal(1,"post-reset flush failed");
 test_pass=1;
 $display("PASS picture pipeline equivalence: %d cycles, %d resets, 1081344 parameter/pixel vectors",checks,resets);
 $finish;
end
initial begin #20000000; $fatal(1,"reset equivalence watchdog"); end
endmodule
