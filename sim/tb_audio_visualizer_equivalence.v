`timescale 1ns/1ps
`default_nettype none

// Compare both the pixel path and every logical RAM address with the board-pass
// source. The same bench runs with SIM and the vendor's physical RAM models.
module tb_audio_visualizer_equivalence;
reg clk=0, rd_clk=0, rst_n=0, sample_valid=0, pause=0, emergency=0, frame_tick=0;
reg hs=1, vs=1, de=0;
reg signed [15:0] left=0, right=0;
reg [10:0] x=0;
reg [9:0] y=0;
reg [23:0] rgb=0;
wire [47:0] pixels, reference_pixels;
reg wr_en=0;
reg [8:0] wr_addr=0, rd_addr=0;
reg [7:0] wr_data=0;
wire [7:0] ram_data, reference_ram_data;
integer i, pixel_checks=0, ram_checks=0, shown_frames=0;
reg ram_ready=0, test_pass=0;
reg [9:0] geometry_y=0;
reg [7:0] geometry_height=0;
always #5 clk=~clk;
always #7 rd_clk=~rd_clk;

audio_visualizer_overlay #(.ENABLE_EMERGENCY(1)) dut (
 .clk(clk),.rst_n(rst_n),.sample_valid(sample_valid),.sample_left(left),.sample_right(right),
 .pause(pause),.emergency(emergency),.frame_tick(frame_tick),
 .hs_i(hs),.vs_i(vs),.de_i(de),.x_i(x),.y_i(y),.rgb_i(rgb),
 .hs_o(pixels[47]),.vs_o(pixels[46]),.de_o(pixels[45]),
 .x_o(pixels[44:34]),.y_o(pixels[33:24]),.rgb_o(pixels[23:0]));
audio_visualizer_overlay_ref #(.ENABLE_EMERGENCY(1)) ref_dut (
 .clk(clk),.rst_n(rst_n),.sample_valid(sample_valid),.sample_left(left),.sample_right(right),
 .pause(pause),.emergency(emergency),.frame_tick(frame_tick),
 .hs_i(hs),.vs_i(vs),.de_i(de),.x_i(x),.y_i(y),.rgb_i(rgb),
 .hs_o(reference_pixels[47]),.vs_o(reference_pixels[46]),.de_o(reference_pixels[45]),
 .x_o(reference_pixels[44:34]),.y_o(reference_pixels[33:24]),.rgb_o(reference_pixels[23:0]));
audio_bar_ram ram (.wr_clk(clk),.wr_en(wr_en),.wr_addr(wr_addr),.wr_data(wr_data),
 .rd_clk(rd_clk),.rd_addr(rd_addr),.rd_data(ram_data));
audio_bar_ram_ref ref_ram (.wr_clk(clk),.wr_en(wr_en),.wr_addr(wr_addr),.wr_data(wr_data),
 .rd_clk(rd_clk),.rd_addr(rd_addr),.rd_data(reference_ram_data));

always @(negedge rd_clk) if(ram_ready) begin
 ram_checks=ram_checks+1;
 if(ram_data !== reference_ram_data)
  $fatal(1,"RAM mismatch addr=%d actual=%h reference=%h",rd_addr,ram_data,reference_ram_data);
end
always @(negedge clk) if(rst_n) begin
 pixel_checks=pixel_checks+1;
 if(pixels !== reference_pixels)
  $fatal(1,"visualizer pixel/sync mismatch cycle=%d",pixel_checks);
 if({dut.bar_index,dut.samples_in_bar,dut.peak_height,dut.display_bank,
     dut.frame_pending,dut.display_valid} !==
    {ref_dut.bar_index,ref_dut.samples_in_bar,ref_dut.peak_height,ref_dut.display_bank,
     ref_dut.frame_pending,ref_dut.display_valid})
  $fatal(1,"visualizer sample/bank state changed");
 if(frame_tick && dut.display_valid) shown_frames=shown_frames+1;
end
initial begin
 // Exhaustive geometry, including heights outside the producer's 2..50 range.
 force dut.display_valid=1;force ref_dut.display_valid=1;
 force dut.de_s2=1;force ref_dut.de_s2=1;
 force dut.x_s2=128;force ref_dut.x_s2=128;
 force dut.y_s2=geometry_y;force ref_dut.y_s2=geometry_y;
 force dut.bar_height_s2=geometry_height;force ref_dut.bar_height_s2=geometry_height;
 for(i=0;i<262144;i=i+1) begin
  geometry_y=i>>8;geometry_height=i;#1;
  if(dut.bar_hit !== ref_dut.bar_hit)
   $fatal(1,"bar geometry mismatch y=%d height=%d",geometry_y,geometry_height);
 end
 release dut.display_valid;release ref_dut.display_valid;
 release dut.de_s2;release ref_dut.de_s2;
 release dut.x_s2;release ref_dut.x_s2;
 release dut.y_s2;release ref_dut.y_s2;
 release dut.bar_height_s2;release ref_dut.bar_height_s2;
 repeat(2) @(negedge clk);
 // Fill and read every logical address using separate write/read clocks.
 for(i=0;i<512;i=i+1) begin
  @(negedge clk);wr_en=1;wr_addr=i;wr_data=i^(i>>8);
 end
 @(negedge clk);wr_en=0;
 repeat(3) @(negedge rd_clk);
 ram_ready=1;
 for(i=0;i<512;i=i+1) begin
  @(negedge rd_clk);rd_addr=i;
  @(negedge rd_clk);
  if(ram_data !== ((i^(i>>8))&255)) $fatal(1,"RAM address/data lost at %d",i);
 end
 @(negedge clk);rst_n=1;
 for(i=0;i<100000;i=i+1) begin
  @(negedge clk);#1;
  // Distinct adjacent heights catch a wrong bar address; full-range random
  // PCM alone would saturate almost every peak group to the same height.
  if(i%8192<6000) begin left=((i/23)%51)*128;right=-left;end
  else begin left=$random;right=$random;end
  sample_valid=($random & 3)!=0;
  frame_tick=(i%101)==0;pause=(i%16000)>=15000;
  emergency=(i%11000)>=5500;de=($random & 7)!=0;
  hs=$random;vs=$random;rgb=$random;
  x=i%2048;y=(i%2)==0 ? i%1024 : 540+(i%121);
  wr_en=(i%3)==0;wr_addr=i;wr_data=$random;rd_addr=i+137;
  if(i==48000 || i==72000) rst_n=0;
  if(i==48005 || i==72005) rst_n=1;
 end
 @(negedge clk);sample_valid=0;wr_en=0;
 repeat(5) @(negedge clk);
 if(pixel_checks<99000 || ram_checks<70000 || shown_frames<100)
  $fatal(1,"insufficient equivalence coverage pixels=%d ram=%d frames=%d",pixel_checks,ram_checks,shown_frames);
 $display("PASS audio visualizer equivalence geometry=262144 pixels=%d ram=%d visible_ticks=%d",pixel_checks,ram_checks,shown_frames);
 test_pass=1;$finish;
end
initial begin #2000000;$fatal(1,"equivalence timeout");end
endmodule
`default_nettype wire
