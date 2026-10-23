`timescale 1ns/1ps
module tb_secondary_compact_waveform;
reg clk=0,rst_n=0,sample_valid=0,pause=0,frame_tick=0;
reg signed [15:0] sample_left=0,sample_right=0;
reg [10:0] x=0;reg [9:0] y=0;
wire [23:0] rgb;
integer n,side,l,r,height;
always #5 clk=~clk;
audio_visualizer_overlay #(.COMPACT(1)) dut(
    .clk(clk),.rst_n(rst_n),.sample_valid(sample_valid),.sample_left(sample_left),.sample_right(sample_right),
    .pause(pause),.emergency(1'b0),.frame_tick(frame_tick),.hs_i(1'b1),.vs_i(1'b1),.de_i(1'b1),
    .x_i(x),.y_i(y),.rgb_i(24'h123456),.hs_o(),.vs_o(),.de_o(),.x_o(),.y_o(),.rgb_o(rgb));
task pixel;input [10:0] xx;input [9:0] yy;input [23:0] expected;
begin @(negedge clk);x=xx;y=yy;repeat(4)@(negedge clk);if(rgb!==expected)$fatal(1,"Compact geometry x=%d y=%d got=%h expected=%h",xx,yy,rgb,expected);end endtask
initial begin
    for(side=0;side<3;side=side+1)for(n=0;n<65536;n=n+1)begin
        sample_left=n;sample_right=side==0?0:side==1?-sample_left:16'sd6400;#1;
        l=$signed(sample_left);r=$signed(sample_right);if(l<0)l=-l;if(r<0)r=-r;
        height=(l>r?l:r)>>8;if(height>25)height=25;
        if(dut.sample_height!==height[7:0])$fatal(1,"Compact PCM gain/clamp mismatch");
    end
    @(negedge clk);rst_n=1;sample_left=2560;sample_right=0;sample_valid=1;
    repeat(800)@(negedge clk);sample_valid=0;repeat(3)@(negedge clk);
    frame_tick=1;@(negedge clk);frame_tick=0;
    pixel(384,620,24'h4ec9e8);pixel(386,610,24'h4ec9e8);
    pixel(392,630,24'h5b7fff);pixel(383,620,24'h123456);
    pixel(387,620,24'h123456);pixel(896,620,24'h123456);
    pixel(384,609,24'h123456);pixel(384,631,24'h123456);
    pause=1;pixel(384,620,24'h123456);
    $display("PASS compact visualizer: full signed stereo PCM domain, half gain, 64 columns within 512x51, original colors, mute bypass");$finish;
end
endmodule
