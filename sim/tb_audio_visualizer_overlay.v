`timescale 1ns/1ps
`default_nettype none

module tb_audio_visualizer_overlay;
reg clk = 0, rst_n = 0, sample_valid = 0, frame_tick = 0;
reg pause = 0;
reg signed [15:0] sample_left = 0, sample_right = 0;
reg de_i = 0;
reg [10:0] x_i = 0;
reg [9:0] y_i = 0;
reg [23:0] rgb_i = 0;
wire hs_o, vs_o, de_o;
wire [10:0] x_o;
wire [9:0] y_o;
wire [23:0] rgb_o;

audio_visualizer_overlay dut (
    .clk(clk), .rst_n(rst_n), .sample_valid(sample_valid),
    .sample_left(sample_left), .sample_right(sample_right), .pause(pause),
    .frame_tick(frame_tick),
    .hs_i(1'b1), .vs_i(1'b1), .de_i(de_i), .x_i(x_i), .y_i(y_i), .rgb_i(rgb_i),
    .hs_o(hs_o), .vs_o(vs_o), .de_o(de_o), .x_o(x_o), .y_o(y_o), .rgb_o(rgb_o)
);
always #5 clk = ~clk;
task play;
    input signed [15:0] value;
    begin
        @(negedge clk); sample_left = value; sample_right = value; sample_valid = 1;
        @(negedge clk); sample_valid = 0;
    end
endtask
integer i;
initial begin
    repeat (2) @(posedge clk); rst_n = 1;
    // Bar 0 is a 12-sample peak group.  8192 is capped at 50 pixels.
    for (i=0; i<11; i=i+1) play(16'sd1024);
    play(-16'sd8192);
    repeat (2) @(posedge clk);
    if (dut.u_bar_ram.memory[64] != 8'd50 || dut.bar_index != 6'd1)
        $fatal(1, "first fixed bar peak was not captured");
    pause = 1;
    for (i=0; i<14; i=i+1) play(16'sd8192);
    if (dut.bar_index != 6'd1) $fatal(1, "paused visualizer advanced");
    pause = 0;
    @(negedge clk); de_i = 1; x_i = 11'd128; y_i = 10'd688; rgb_i = 24'h123456;
    repeat (3) @(posedge clk);
    if (rgb_o != 24'h123456) $fatal(1, "subtitle pixel was modified");
    $display("PASS tb_audio_visualizer_overlay");
    $finish;
end
endmodule

`default_nettype wire
