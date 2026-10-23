`timescale 1ns / 1ps
module tb_museum_status_osd;
reg test_pass=0;
integer font_addr;
integer row,col;
integer control_case,control_char;
reg [4:0] expected_glyph;
reg [15:0] expected_row;
reg clk=0,rst_n=0,hs=1,vs=1,de=1,name_ready=0,name_we=0;
reg [1:0] zoom_2x=0;
reg panel_enable=1;
reg manual_mode=0;
reg [1:0] speed_index=0;
reg [2:0] effect=0;
reg [10:0] x=0,name_addr=0;
reg [9:0] y=0;
reg [7:0] name_data=0;
wire hs_o,vs_o,de_o;
wire [10:0] x_o;
wire [9:0] y_o;
wire [23:0] rgb_o;
always #5 clk=~clk;
// Region pipeline must follow exactly the same coordinates as the raster,
// including on the first cycle after moving between adjacent fields.
always @(posedge clk)begin : check_region_pipeline
 reg [2:0] expected_region;
 #1;
 expected_region=
  dut.x_s0>=12 && dut.x_s0<492 && dut.y_s0>=56 && dut.y_s0<64 ? 1 :
  dut.x_s0>=22 && dut.x_s0<182 && dut.y_s0>=12 && dut.y_s0<28 ? 2 :
  dut.x_s0>=202 && dut.x_s0<266 && dut.y_s0>=12 && dut.y_s0<28 ? 3 :
  dut.x_s0>=22 && dut.x_s0<70 && dut.y_s0>=32 && dut.y_s0<48 ? 4 :
  dut.x_s0>=202 && dut.x_s0<274 && dut.y_s0>=32 && dut.y_s0<40 ? 5 :
  dut.x_s0>=332 && dut.x_s0<396 && dut.y_s0>=32 && dut.y_s0<40 ? 6 :
  dut.x_s0>=412 && dut.x_s0<452 && dut.y_s0>=32 && dut.y_s0<40 ? 7 : 0;
 if(rst_n && dut.ascii_region_s0!==expected_region)$fatal(1,"OSD region/raster pipeline mismatch");
end
museum_status_osd #(.SHOW_PERCENT(1)) dut(
    .clk(clk),.rst_n(rst_n),.panel_enable(panel_enable),.hs_i(hs),.vs_i(vs),.de_i(de),
    .x_i(x),.y_i(y),.rgb_i(24'h808080),
    .artifact(3'd0),.stage(3'd0),.effect(effect),
    .width_bcd(16'h1920),.height_bcd(16'h1080),
    .zoom_2x(zoom_2x),
    .manual_mode(manual_mode),
    .speed_index(speed_index),
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
   $fatal(1,"OSD pixel (%d,%d) got (%d,%d) %h expected %h glyph=%d valid=%b col=%d bits=%b",
          px,py,x_o,y_o,rgb_o,expected,dut.ascii_s1,dut.ascii_valid_s1,dut.ascii_col_s1,dut.ascii_bits);
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
 check(11'd440,10'd32,24'h404040); // SPD1x digit left stroke
 speed_index=1;
 check(11'd440,10'd32,24'hffffff); // SPD2x
 speed_index=2;
 check(11'd440,10'd32,24'hffffff); // SPD3x
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
 zoom_2x=2;
 check(365,32,24'h404040);
 if(dut.chosen_ascii!==5'd0)$fatal(1,"half scale zero missing");
 check(373,32,24'h404040);
 if(dut.chosen_ascii!==5'd10)$fatal(1,"half scale decimal point missing");
 check(381,32,24'hffffff);
 if(dut.chosen_ascii!==5'd5)$fatal(1,"half scale five missing");
 check(389,32,24'h404040);
 if(dut.chosen_ascii!==5'd16)$fatal(1,"half scale x missing");
 // Exercise all columns, gaps and glyph rows of both controls together.
 for(control_case=0;control_case<9;control_case=control_case+1)begin
  zoom_2x=control_case/3;speed_index=control_case%3;
  for(row=0;row<7;row=row+1)
   for(col=0;col<120;col=col+1)begin
    expected_glyph=31;
    if(col<64)begin
     case(col/8)
      0:expected_glyph=17;1,2:expected_glyph=18;3:expected_glyph=19;
      4:expected_glyph=zoom_2x==2 ? 0 : zoom_2x==1 ? 2 : 1;
      5:expected_glyph=zoom_2x==2 ? 10 : 16;
      6:expected_glyph=zoom_2x==2 ? 5 : 31;
      7:expected_glyph=zoom_2x==2 ? 16 : 31;
     endcase
    end else if(col>=80)begin
     case((col-80)/8)
      0:expected_glyph=24;1:expected_glyph=29;2:expected_glyph=30;
      3:expected_glyph=speed_index+1;4:expected_glyph=16;
     endcase
    end
    expected_row=dut.ascii_row(expected_glyph,row);
    control_char=col%8;
    check(332+col,32+row,control_char>=1 && control_char<6 &&
          expected_row[5-control_char] ? 24'hffffff : 24'h404040);
   end
 end
 zoom_2x=0;
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
  if(font_addr[7:3]==31 && dut.ascii_bits!==5'd0)
   $fatal(1,"Blank glyph must be transparent at row %0d",font_addr[2:0]);
 end
 release dut.chosen_ascii; release dut.local_y;
 for(row=0;row<1024;row=row+1)begin
  @(negedge clk);y=row;
  @(posedge clk);#1;
  if(dut.local_y!==((row<28 ? row-12 : row<48 ? row-32 : row-56)&15))
   $fatal(1,"font row arithmetic changed y=%d",row);
 end
 test_pass=1;
 $display("PASS tb_museum_status_osd enable, TF name, pixel alignment");
 $finish;
end
endmodule
