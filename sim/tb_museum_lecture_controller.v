`timescale 1ns / 1ps
`default_nettype none

module tb_museum_lecture_controller;
reg clk = 0;
reg rst_n = 0;
reg enable = 1;
reg overview_ready = 0;
reg confirm = 0;
reg key_pause = 0;
reg key_return = 0;
reg [2:0] selected = 0;
reg preload_valid = 0;
reg [2:0] preload_index = 0;
reg audio_prepared = 0;
reg audio_frame_pulse = 0;
reg [31:0] audio_total_frames = 8;
reg audio_stream_done = 1;
reg load_accept = 0;
reg load_complete = 0;
reg load_error = 0;
wire load_request;
wire [1:0] load_slot;
wire load_detail;
wire [1:0] detail_index;
wire [2:0] artifact;
wire preloading, cache_ready, active, paused, finished;
wire audio_restart;
wire [1:0] display_slot;
wire media_error;

always #5 clk = ~clk;

museum_lecture_controller #(.CLOCK_HZ(2), .END_HOLD_SECONDS(1)) dut (
    .clk(clk), .rst_n(rst_n), .enable(enable), .overview_ready(overview_ready),
    .confirm_pulse(confirm), .key_pause(key_pause), .key_return(key_return),
    .selected_index(selected), .preload_valid(preload_valid),
    .preload_index(preload_index), .audio_prepared(audio_prepared),
    .audio_frame_pulse(audio_frame_pulse), .audio_total_frames(audio_total_frames),
    .audio_stream_done(audio_stream_done), .load_request(load_request),
    .load_accept(load_accept), .load_complete(load_complete), .load_error(load_error),
    .load_slot(load_slot), .load_detail(load_detail), .detail_index(detail_index),
    .artifact_index(artifact), .preloading(preloading), .cache_ready(cache_ready),
    .lecture_active(active), .lecture_paused(paused), .lecture_finished(finished),
    .audio_restart(audio_restart),
    .display_slot(display_slot), .media_error(media_error)
);

task pulse_accept;
begin
    @(negedge clk); load_accept = 1;
    @(negedge clk); load_accept = 0;
end
endtask

task pulse_complete;
begin
    @(negedge clk); load_complete = 1;
    @(negedge clk); load_complete = 0;
end
endtask

task pulse_audio;
begin
    @(negedge clk); audio_frame_pulse = 1;
    @(negedge clk); audio_frame_pulse = 0;
end
endtask

task load_four_slots;
integer slot;
begin
    for (slot = 0; slot < 4; slot = slot + 1) begin
        if (!load_request || load_slot != slot || load_detail != (slot != 0) ||
            detail_index != slot)
            $fatal(1, "bad background load request slot=%0d", slot);
        pulse_accept;
        pulse_complete;
    end
end
endtask

initial begin
    repeat (2) @(negedge clk);
    rst_n = 1;
    selected = 3'd2;
    preload_index = 3'd4;
    preload_valid = 1;
    repeat (2) @(negedge clk);
    if (preloading) $fatal(1, "preload began before overview was ready");
    overview_ready = 1;
    @(negedge clk);
    if (artifact != 3'd4) $fatal(1, "highlighted artifact not latched");
    load_four_slots;
    if (!cache_ready || active || preloading)
        $fatal(1, "background cache did not become ready");

    audio_prepared = 1;
    confirm = 1; @(negedge clk); confirm = 0;
    if (active) $fatal(1, "mismatched highlight entered cached artifact");
    selected = 3'd4;
    confirm = 1; @(negedge clk); confirm = 0;
    if (!active || display_slot != 0)
        $fatal(1, "prepared lecture did not start immediately");

    pulse_audio; pulse_audio;
    if (display_slot != 1) $fatal(1, "quarter-time detail 1 missing");
    key_pause = 1; @(negedge clk); key_pause = 0;
    if (!paused) $fatal(1, "pause missing");
    pulse_audio;
    if (display_slot != 1) $fatal(1, "paused timeline advanced");
    key_pause = 1; @(negedge clk); key_pause = 0;
    if (paused) $fatal(1, "resume missing");
    pulse_audio; pulse_audio;
    if (display_slot != 2) $fatal(1, "half-time detail 2 missing");
    pulse_audio; pulse_audio;
    if (display_slot != 3) $fatal(1, "three-quarter detail 3 missing");
    pulse_audio; pulse_audio;
    if (!finished || display_slot != 3) $fatal(1, "audio-driven finish missing");
    repeat (2) @(negedge clk);
    if (active || !audio_restart)
        $fatal(1, "automatic overview return/restart missing");

    // The same cached artifact can start again, and KEY3 returns immediately.
    confirm = 1; @(negedge clk); confirm = 0;
    if (!active) $fatal(1, "cached replay did not start");
    key_return = 1; @(negedge clk); key_return = 0;
    if (active || !audio_restart) $fatal(1, "KEY3 return/restart missing");

    // Changing highlight starts a new cache transaction; a missing file is sticky.
    selected = 3'd2; preload_index = 3'd2; audio_prepared = 0;
    @(negedge clk);
    if (!preloading || artifact != 3'd2) $fatal(1, "selection did not trigger preload");
    pulse_accept;
    @(negedge clk); load_error = 1;
    @(negedge clk); load_error = 0;
    if (!media_error || preloading || cache_ready)
        $fatal(1, "missing asset error was not sticky");
    repeat (3) @(negedge clk);
    if (preloading) $fatal(1, "failed artifact retried forever");

    $display("PASS tb_museum_lecture_controller");
    $finish;
end
endmodule

`default_nettype wire
