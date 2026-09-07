`timescale 1ns/1ps
`default_nettype none

module tb_video_rgb_to_axis_1280x720;
reg clk = 0, rst = 1, vs = 0, de = 0;
reg [23:0] rgb = 0;
wire user, valid, last;
wire [23:0] data;
integer pixels = 0, lasts = 0, users = 0;

video_rgb_to_axis_1280x720 dut (.clk(clk), .rst(rst), .vs_i(vs), .de_i(de), .rgb_i(rgb),
    .axis_user(user), .axis_valid(valid), .axis_last(last), .axis_data(data));
always #5 clk = ~clk;
always @(posedge clk) begin
    #1;
    if (valid) pixels = pixels + 1;
    if (user) users = users + 1;
    if (last) begin
        lasts = lasts + 1;
        if (pixels != 1280) $fatal(1, "TLAST not on 1280th pixel: %0d", pixels);
    end
end
integer n;
initial begin
    repeat (2) @(negedge clk); rst = 0;
    @(negedge clk); vs = 1;
    @(negedge clk); vs = 0;
    @(negedge clk); de = 1;
    for (n=0; n<1280; n=n+1) begin rgb = n; @(negedge clk); end
    de = 0;
    repeat (3) @(posedge clk);
    if (pixels != 1280 || lasts != 1 || users != 1) $fatal(1, "AXIS framing mismatch");
    $display("PASS tb_video_rgb_to_axis_1280x720");
    $finish;
end
endmodule

`default_nettype wire
