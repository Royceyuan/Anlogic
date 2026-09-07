`timescale 1ns/1ps
`default_nettype none

module tb_audio_pcm_player_48k;
reg clk = 0, rst = 1;
reg [31:0] fifo_data = 32'h2222_1111;
reg fifo_valid = 1, fifo_empty = 0;
reg [8:0] fifo_used = 2;
wire fifo_rd_en, sample_valid, active, underflow;
wire signed [15:0] sample_left, sample_right;
integer samples = 0;

audio_pcm_player_48k #(.PIXEL_CLK_HZ(100), .SAMPLE_RATE_HZ(10), .START_FRAMES(2), .UNDERFLOW_TICKS(2)) dut (
    .clk(clk), .rst(rst), .fifo_data(fifo_data), .fifo_valid(fifo_valid),
    .fifo_empty(fifo_empty), .fifo_used(fifo_used), .fifo_rd_en(fifo_rd_en),
    .sample_valid(sample_valid), .sample_left(sample_left), .sample_right(sample_right),
    .active(active), .underflow(underflow)
);
always #5 clk = ~clk;
always @(posedge clk) if (sample_valid) begin
    #1;
    if (samples == 0 && {sample_right,sample_left} != 32'h2222_1111) $fatal(1, "first PCM frame byte order");
    if (samples == 1 && {sample_right,sample_left} != 32'h4444_3333) $fatal(1, "second PCM frame byte order");
    samples = samples + 1;
    fifo_data = 32'h4444_3333;
    if (samples == 2) fifo_empty = 1;
end
initial begin
    repeat (3) @(posedge clk); rst = 0;
    repeat (45) @(posedge clk);
    if (samples != 2 || !underflow) $fatal(1, "48 kHz player sustained-underflow behavior");
    $display("PASS tb_audio_pcm_player_48k");
    $finish;
end
endmodule

`default_nettype wire
