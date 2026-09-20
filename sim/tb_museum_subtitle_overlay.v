`timescale 1ns / 1ps
module tb_museum_subtitle_overlay;
reg clk50=0,vclk=0,rst50=0,vrst=0,active=0,finished=0,frame_tick=0;
reg hs=1,vs=1,de=1;
reg [2:0] track=0;
reg [31:0] audio_frame=0;
reg [10:0] x=0;
reg [9:0] y=680;
reg [23:0] rgb=24'h345678;
wire hs_o,vs_o,de_o;
wire [10:0] x_o;
wire [9:0] y_o;
wire [23:0] rgb_o;
always #10 clk50=~clk50;
always #5 vclk=~vclk;
museum_subtitle_overlay dut(
 .clk_50m(clk50),.rst_n_50m(rst50),.lecture_active(active),
 .lecture_finished(finished),.track_index(track),.audio_frame_index(audio_frame),
 .video_clk(vclk),.video_rst_n(vrst),.video_frame_tick(frame_tick),
 .hs_i(hs),.vs_i(vs),.de_i(de),.x_i(x),.y_i(y),.rgb_i(rgb),
 .hs_o(hs_o),.vs_o(vs_o),.de_o(de_o),.x_o(x_o),.y_o(y_o),.rgb_o(rgb_o));
initial begin
 repeat(3)@(negedge clk50);rst50=1;vrst=1;active=1;audio_frame=32'd20000;
 repeat(6)@(negedge clk50);
 repeat(8)@(negedge vclk);
 if(rgb_o!==24'h101820)$fatal(1,"subtitle bar missing: %h",rgb_o);
 active=0;repeat(6)@(negedge clk50);repeat(8)@(negedge vclk);
 if(rgb_o!==rgb)$fatal(1,"inactive subtitle changed image: %h",rgb_o);
 $display("PASS tb_museum_subtitle_overlay");$finish;
end
endmodule
