`timescale 1ns/1ps
`default_nettype none

module tb_audio_goertzel8;
reg clk = 0, rst = 1, sample_valid = 0, frame_tick = 0;
reg signed [15:0] sample_left = 0, sample_right = 0;
wire [7:0] b0,b1,b2,b3,b4,b5,b6,b7;
integer n;
integer b6_peak;

audio_goertzel8 dut (.clk(clk), .rst(rst), .sample_valid(sample_valid),
    .sample_left(sample_left), .sample_right(sample_right), .frame_tick(frame_tick),
    .bar0(b0),.bar1(b1),.bar2(b2),.bar3(b3),.bar4(b4),.bar5(b5),.bar6(b6),.bar7(b7));
always #5 clk = ~clk;
task send_sample;
    input signed [15:0] value;
    begin
        @(negedge clk); sample_left = value; sample_right = value; sample_valid = 1;
        @(negedge clk); sample_valid = 0;
        repeat (8) @(negedge clk);
    end
endtask
initial begin
    repeat (2) @(posedge clk); rst = 0;
    // 12 kHz at 48 kHz: 0, +A, 0, -A.  Bin 6 must dominate after 256 samples.
    for (n=0; n<256; n=n+1) begin
        case (n[1:0])
            2'd1: send_sample(16'sd12000);
            2'd3: send_sample(-16'sd12000);
            default: send_sample(16'sd0);
        endcase
    end
    repeat (30) @(posedge clk);
    @(negedge clk); frame_tick = 1;
    @(negedge clk); frame_tick = 0;
    repeat (2) @(posedge clk);
    if (b6 == 0 || b6 <= b5 || b6 <= b7) $fatal(1, "12 kHz bin did not dominate: %0d %0d %0d", b5,b6,b7);
    b6_peak = b6;
    for (n=0; n<256; n=n+1) send_sample(16'sd0);
    repeat (30) @(posedge clk);
    @(negedge clk); frame_tick = 1;
    @(negedge clk); frame_tick = 0;
    repeat (2) @(posedge clk);
    if (b6 >= b6_peak) $fatal(1, "12 kHz bar did not decay: %0d", b6);
    $display("PASS tb_audio_goertzel8");
    $finish;
end
endmodule

`default_nettype wire
