`timescale 1ns/1ps
module tb_main5_osd_equivalence;
reg clk=0,rst_n=0,hs=1,vs=1,de=0,enable=1,ready=0,we=0,zoom=0;
reg test_pass=0;
reg [10:0] x=0,addr=0;
reg [9:0] y=0;
reg [23:0] rgb=0;
reg [2:0] artifact=0,stage=0,effect=0;
reg [15:0] width_bcd=16'h1920,height_bcd=16'h1080;
reg [7:0] data=0;
wire [47:0] actual,expected;
integer i,px,py,scenario;
always #5 clk=~clk;
`define INPUTS .clk(clk),.rst_n(rst_n),.panel_enable(enable), \
 .hs_i(hs),.vs_i(vs),.de_i(de),.x_i(x),.y_i(y),.rgb_i(rgb), \
 .artifact(artifact),.stage(stage),.effect(effect), \
 .width_bcd(width_bcd),.height_bcd(height_bcd),.zoom_2x(zoom), \
 .name_ready(ready),.name_wr_clk(clk),.name_wr_en(we), \
 .name_wr_addr(addr),.name_wr_data(data)
museum_status_osd dut(`INPUTS,.hs_o(actual[47]),.vs_o(actual[46]),
 .de_o(actual[45]),.x_o(actual[44:34]),.y_o(actual[33:24]),.rgb_o(actual[23:0]));
museum_status_osd_ref ref_dut(`INPUTS,.hs_o(expected[47]),.vs_o(expected[46]),
 .de_o(expected[45]),.x_o(expected[44:34]),.y_o(expected[33:24]),.rgb_o(expected[23:0]));
`undef INPUTS
always @(negedge clk)
 if(rst_n && i>4 && actual!==expected)
   $fatal(1,"OSD mismatch input x=%d y=%d effect=%d stage=%d",x,y,effect,stage);
initial begin
 i=0;
 repeat(3) @(negedge clk);
 rst_n=1;
 for(i=0;i<2048;i=i+1) begin
   @(posedge clk); #1; we=1;addr=i;data=i^(i>>3);
 end
 @(posedge clk); #1;we=0;
 for(scenario=0;scenario<30;scenario=scenario+1) begin
   effect=scenario%5;stage=scenario/5;artifact=scenario%5;
   ready=scenario%2;zoom=(scenario/2)%2;
   for(py=0;py<80;py=py+1)
     for(px=0;px<1280;px=px+1) begin
       @(posedge clk); #1;x=px;y=py;de=1;rgb=px*123+py*317;
     end
 end
 for(i=5;i<100005;i=i+1) begin
   @(posedge clk); #1;
   x=$random;y=$random;de=$random;hs=$random;vs=$random;
   enable=$random;ready=$random;artifact=$random;stage=$random;
   effect=$random;zoom=$random;rgb=$random;width_bcd=$random;height_bcd=$random;
 end
 repeat(5) @(posedge clk);
 $display("PASS OSD equivalence: 30 complete top panels + 100000 random cycles");
 test_pass=1;
 $finish;
end
endmodule
