`timescale 1ns / 1ps
module tb_museum_status_osd;
reg test_pass=0;
integer font_addr;
integer row,col;
reg [15:0] expected_row;
reg clk=0,rst_n=0,hs=1,vs=1,de=1,name_ready=0,name_we=0,zoom_2x=0;
reg panel_enable=1;
reg manual_mode=0;
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
    .manual_mode(manual_mode),
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
 // Compare every pixel, including odd rows lost by the former 8x8 sampling.
 for(row=0;row<16;row=row+1) begin
  expected_row=dut.chinese_row(18,row);
  for(col=0;col<16;col=col+1)
   check(22+col,12+row,expected_row[15-col] ? 24'hffffff : 24'h404040);
 end
 for(row=0;row<16;row=row+1) begin
  expected_row=dut.chinese_row(9,row);
  for(col=0;col<16;col=col+1)
   check(22+col,32+row,expected_row[15-col] ? 24'hffffff : 24'h404040);
 end
 // Exercise every name byte and row through the actual RAM/output pipeline.
 for(font_addr=0;font_addr<2;font_addr=font_addr+1) begin
  manual_mode=font_addr;
  for(row=0;row<16;row=row+1) begin
   expected_row=dut.chinese_row(manual_mode ? 22 : 20,row);
   for(col=0;col<16;col=col+1)
    check(332+col,12+row,expected_row[15-col] ? 24'hffffff : 24'h404040);
   expected_row=dut.chinese_row(21,row);
   for(col=0;col<16;col=col+1)
    check(348+col,12+row,expected_row[15-col] ? 24'hffffff : 24'h404040);
  end
 end
 manual_mode=0;
 for(font_addr=0;font_addr<320;font_addr=font_addr+1) begin
  @(negedge clk);name_addr=font_addr;name_data=8'ha5 ^ font_addr;name_we=1;
 end
 @(negedge clk);name_we=0;name_ready=1;
 repeat(3) @(negedge clk);
 for(row=0;row<16;row=row+1)
  for(col=0;col<160;col=col+1) begin
   expected_row=(8'ha5 ^ (row*20+col/8)) & 255;
   check(22+col,12+row,expected_row[7-col%8] ? 24'hffffff : 24'h404040);
  end
 @(negedge clk);name_addr=0;name_data=8'h80;name_we=1;
 @(negedge clk);name_we=0;name_ready=1;
 repeat(3) @(negedge clk);
 check(11'd11,10'd20,24'h808080);  // left of compact panel
 check(11'd400,10'd20,24'h404040); // compact panel background
 check(11'd22,10'd12,24'hffffff);  // native TF name bit
 check(11'd23,10'd12,24'h404040);
 check(11'd206,10'd12,24'hffffff); // 总览 glyph
 check(11'd25,10'd32,24'hffffff);  // 标准 glyph
 check(11'd365,10'd33,24'h404040); // ZOOM1x digit
 zoom_2x=1;
 check(11'd365,10'd33,24'hffffff); // ZOOM2x digit
 effect=3'd4;
 check(11'd24,10'd32,24'hffffff); // CUSTOM first C
 check(11'd23,10'd32,24'h404040);
 if(dut.percent_bcd(0,0)!==12'h019 || dut.percent_bcd(0,3)!==0 ||
    dut.percent_bcd(1,2)!==12'h100 || dut.percent_bcd(2,0)!==0 ||
    dut.percent_bcd(3,6)!==12'h100) $fatal(1,"percentage LUT");
 check(11'd13,10'd56,24'hffffff); // B label in third row
 check(11'd30,10'd66,24'h404040); // compact extended panel background
 check(11'd30,10'd68,24'h808080); // below panel
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
