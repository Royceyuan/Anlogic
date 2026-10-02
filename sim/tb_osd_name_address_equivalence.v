`timescale 1ns/1ps
module tb_osd_name_address_equivalence;
parameter SHOW_PERCENT=1;
reg clk=0,rst_n=0,hs=1,vs=1,de=0,enable=1,ready=0,we=0,zoom=0,manual=0;
reg test_pass=0;
reg [10:0] x=0,addr=0;
reg [9:0] y=0;
reg [23:0] rgb=0;
reg [2:0] artifact=0,stage=0,effect=0,b=0,c=0,s=0,t=0;
reg [15:0] width_bcd=16'h1920,height_bcd=16'h1080;
reg [7:0] data=0;
wire [47:0] actual,expected;
integer i,px,py,scenario,checks=0;
always #5 clk=~clk;
`define INPUTS .clk(clk),.rst_n(rst_n),.panel_enable(enable), \
 .hs_i(hs),.vs_i(vs),.de_i(de),.x_i(x),.y_i(y),.rgb_i(rgb), \
 .artifact(artifact),.stage(stage),.effect(effect), \
 .width_bcd(width_bcd),.height_bcd(height_bcd),.zoom_2x(zoom),.manual_mode(manual), \
 .brightness_index(b),.contrast_index(c),.saturation_index(s),.temperature_index(t), \
 .name_ready(ready),.name_wr_clk(clk),.name_wr_en(we), \
 .name_wr_addr(addr),.name_wr_data(data)
museum_status_osd #(.SHOW_PERCENT(SHOW_PERCENT)) dut(`INPUTS,.hs_o(actual[47]),.vs_o(actual[46]),
 .de_o(actual[45]),.x_o(actual[44:34]),.y_o(actual[33:24]),.rgb_o(actual[23:0]));
museum_status_osd_ref #(.SHOW_PERCENT(SHOW_PERCENT)) ref_dut(`INPUTS,.hs_o(expected[47]),.vs_o(expected[46]),
 .de_o(expected[45]),.x_o(expected[44:34]),.y_o(expected[33:24]),.rgb_o(expected[23:0]));
`undef INPUTS
always @(negedge clk) if(rst_n) begin
 if(actual!==expected || dut.name_rd_addr!==ref_dut.name_rd_addr)
   $fatal(1,"OSD/name address mismatch at x=%d y=%d artifact=%d: %h/%h addr %d/%d",
       x,y,artifact,actual,expected,dut.name_rd_addr,ref_dut.name_rd_addr);
 checks=checks+1;
end
initial begin
 repeat(3) @(negedge clk);
 rst_n=1;
 for(i=0;i<2048;i=i+1) begin
   @(posedge clk); #1; we=1;addr=i;data=i^(i>>3)^(i>>8);
 end
 @(posedge clk); #1;we=0;
 // All artifact encodings, ready/fallback, names including x=128..159,
 // every OSD row and character boundary, with changing video RGB.
 for(scenario=0;scenario<16;scenario=scenario+1) begin
   artifact=scenario%8;ready=scenario/8;stage=scenario%8;
   effect=scenario%8;zoom=scenario%2;manual=(scenario/2)%2;
   b=scenario%8;c=(scenario+1)%8;s=(scenario+2)%8;t=(scenario+3)%8;
   for(py=0;py<72;py=py+1)
     for(px=0;px<512;px=px+1) begin
       @(posedge clk); #1;x=px;y=py;de=1;rgb=px*123+py*317;
     end
 end
 for(i=0;i<100000;i=i+1) begin
   @(posedge clk); #1;
   x=$random;y=$random;de=$random;hs=$random;vs=$random;
   enable=$random;ready=$random;artifact=$random;stage=$random;
   effect=$random;zoom=$random;manual=$random;rgb=$random;
   width_bcd=$random;height_bcd=$random;b=$random;c=$random;s=$random;t=$random;
   we=$random;addr=$random;data=$random;
   if(i==49996) rst_n=0;
   if(i==50000) rst_n=1;
 end
 @(posedge clk); #1;we=0;
 repeat(5) @(posedge clk);
 $display("PASS OSD address equivalence SHOW_PERCENT=%d: %d cycles",SHOW_PERCENT,checks);
 test_pass=1;
 $finish;
end
initial begin
 #10000000;
 $fatal(1,"OSD equivalence watchdog");
end
endmodule
