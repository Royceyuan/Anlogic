`timescale 1ns / 1ps
module tb_museum_status_osd;
reg clk=0,rst_n=0,hs=1,vs=1,de=1,name_ready=0,name_we=0,zoom_2x=0;
reg panel_enable=1;
reg [10:0] x=0,name_addr=0;
reg [9:0] y=0;
reg [7:0] name_data=0;
wire hs_o,vs_o,de_o;
wire [10:0] x_o;
wire [9:0] y_o;
wire [23:0] rgb_o;
always #5 clk=~clk;
museum_status_osd dut(
    .clk(clk),.rst_n(rst_n),.panel_enable(panel_enable),.hs_i(hs),.vs_i(vs),.de_i(de),
    .x_i(x),.y_i(y),.rgb_i(24'h808080),
    .artifact(3'd0),.stage(3'd0),.effect(2'd0),
    .width_bcd(16'h1920),.height_bcd(16'h1080),
    .zoom_2x(zoom_2x),
    .name_ready(name_ready),.name_wr_clk(clk),.name_wr_en(name_we),
    .name_wr_addr(name_addr),.name_wr_data(name_data),
    .hs_o(hs_o),.vs_o(vs_o),.de_o(de_o),.x_o(x_o),.y_o(y_o),.rgb_o(rgb_o)
);
task check;
 input [10:0] px;
 input [9:0] py;
 input [23:0] expected;
 begin
  @(negedge clk);x=px;y=py;
  repeat(3) @(posedge clk);
  #1;
  if(x_o!==px || y_o!==py || rgb_o!==expected)
   $fatal(1,"OSD pixel (%d,%d) got (%d,%d) %h expected %h",
          px,py,x_o,y_o,rgb_o,expected);
 end
endtask
initial begin
 repeat(3) @(negedge clk);rst_n=1;
 check(11'd187,10'd20,24'hffffff); // fallback 文 glyph from shared BRAM
 @(negedge clk);name_addr=0;name_data=8'h80;name_we=1;
 @(negedge clk);name_we=0;name_ready=1;
 repeat(3) @(negedge clk);
 check(11'd150,10'd20,24'h808080);
 check(11'd400,10'd20,24'h404040);
 check(11'd180,10'd20,24'hffffff);
 check(11'd181,10'd20,24'h404040);
 check(11'd544,10'd20,24'hffffff); // 总览 glyph
 check(11'd183,10'd44,24'hffffff); // 标准 glyph
 check(11'd869,10'd45,24'h404040); // ZOOM1x digit
 zoom_2x=1;
 check(11'd869,10'd45,24'hffffff); // ZOOM2x digit
 panel_enable=0;
 check(11'd400,10'd20,24'h808080); // disabled panel stays aligned and transparent
 $display("PASS tb_museum_status_osd enable, TF name, pixel alignment");
 $finish;
end
endmodule
