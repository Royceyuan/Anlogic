`timescale 1ns / 1ps
module tb_museum_status_osd;
reg test_pass=0;
integer font_addr;
reg clk=0,rst_n=0,hs=1,vs=1,de=1,name_ready=0,name_we=0,zoom_2x=0;
reg panel_enable=1;
reg [2:0] effect=0;
reg [10:0] x=0,name_addr=0;
reg [9:0] y=0;
reg [7:0] name_data=0;
wire hs_o,vs_o,de_o;
wire [10:0] x_o;
wire [9:0] y_o;
wire [23:0] rgb_o;
always #5 clk=~clk;
museum_status_osd #(.SHOW_PERCENT(1)) dut(
    .clk(clk),.rst_n(rst_n),.panel_enable(panel_enable),.hs_i(hs),.vs_i(vs),.de_i(de),
    .x_i(x),.y_i(y),.rgb_i(24'h808080),
    .artifact(3'd0),.stage(3'd0),.effect(effect),
    .width_bcd(16'h1920),.height_bcd(16'h1080),
    .zoom_2x(zoom_2x),
    .brightness_index(3'd0),.contrast_index(3'd2),
    .saturation_index(3'd3),.temperature_index(3'd6),
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
 check(11'd25,10'd12,24'hffffff); // compact fallback 文 glyph
 @(negedge clk);name_addr=0;name_data=8'h80;name_we=1;
 @(negedge clk);name_we=0;name_ready=1;
 repeat(3) @(negedge clk);
 check(11'd11,10'd20,24'h808080);  // left of compact panel
 check(11'd400,10'd20,24'h404040); // compact panel background
 check(11'd22,10'd12,24'hffffff);  // downsampled TF name bit pair
 check(11'd23,10'd12,24'h404040);
 check(11'd204,10'd12,24'hffffff); // 总览 glyph
 check(11'd23,10'd24,24'hffffff);  // 标准 glyph
 check(11'd365,10'd25,24'h404040); // ZOOM1x digit
 zoom_2x=1;
 check(11'd365,10'd25,24'hffffff); // ZOOM2x digit
 effect=3'd4;
 check(11'd24,10'd24,24'hffffff); // CUSTOM first C
 check(11'd23,10'd24,24'h404040);
 if(dut.percent_bcd(0,0)!==12'h019 || dut.percent_bcd(0,3)!==0 ||
    dut.percent_bcd(1,2)!==12'h100 || dut.percent_bcd(2,0)!==0 ||
    dut.percent_bcd(3,6)!==12'h100) $fatal(1,"percentage LUT");
 check(11'd13,10'd40,24'hffffff); // B label in third row
 check(11'd30,10'd50,24'h404040); // compact extended panel background
 check(11'd492,10'd20,24'h808080); // right edge is outside panel
 panel_enable=0;
 check(11'd400,10'd20,24'h808080); // disabled panel stays aligned and transparent
 // Also exercised with the vendor BRAM model: check initialization packing
 // and every row, including unused glyph addresses, at the real read latency.
 for(font_addr=0;font_addr<512;font_addr=font_addr+1) begin
  @(negedge clk);
  force dut.glyph_s0=font_addr[8:4];
  force dut.glyph_row_s0=font_addr[3:0];
  @(posedge clk); #1;
  if(dut.glyph_row_s1!==dut.chinese_row(font_addr[8:4],font_addr[3:0]))
   $fatal(1,"font ROM address %d",font_addr);
 end
 release dut.glyph_s0; release dut.glyph_row_s0;
 for(font_addr=0;font_addr<256;font_addr=font_addr+1) begin
  @(negedge clk);
  force dut.chosen_ascii=font_addr[7:3];
  force dut.local_y={1'b0,font_addr[2:0]};
  @(posedge clk); #1;
  if(dut.ascii_bits!==dut.ascii_row(font_addr[7:3],font_addr[2:0]))
   $fatal(1,"ASCII ROM address %d",font_addr);
 end
 release dut.chosen_ascii; release dut.local_y;
 test_pass=1;
 $display("PASS tb_museum_status_osd enable, TF name, pixel alignment");
 $finish;
end
endmodule
