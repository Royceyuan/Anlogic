`timescale 1ns / 1ps

module tb_museum_overview_controller;
reg ctrl_clk = 1'b0;
reg video_clk = 1'b0;
reg ctrl_rst_n = 1'b0;
reg video_rst_n = 1'b0;
reg enable = 1'b0;
reg media_ready = 1'b0;
reg key_confirm = 1'b0;
reg key_previous = 1'b0;
reg key_next = 1'b0;
reg recover_select = 1'b0;
reg [2:0] recover_index = 3'd0;
reg video_frame_tick = 1'b0;
wire [2:0] selected_index_ctrl;
wire confirm_pulse;
wire enable_video;
wire [2:0] selected_index_video;
wire confirm_active_video;

museum_overview_controller #(
    .ITEM_COUNT(5), .CONFIRM_FLASH_FRAMES(3)
) dut (
    .ctrl_clk(ctrl_clk), .ctrl_rst_n(ctrl_rst_n),
    .enable(enable), .media_ready(media_ready),
    .key_confirm(key_confirm), .key_previous(key_previous), .key_next(key_next),
    .recover_select(recover_select), .recover_index(recover_index),
    .selected_index_ctrl(selected_index_ctrl), .confirm_pulse(confirm_pulse),
    .video_clk(video_clk), .video_rst_n(video_rst_n),
    .video_frame_tick(video_frame_tick), .enable_video(enable_video),
    .selected_index_video(selected_index_video),
    .confirm_active_video(confirm_active_video)
);

always #10 ctrl_clk = ~ctrl_clk;
always #7 video_clk = ~video_clk;

task ctrl_pulse;
    input integer key_id;
    begin
        @(negedge ctrl_clk);
        if (key_id == 0) key_confirm = 1'b1;
        if (key_id == 1) key_previous = 1'b1;
        if (key_id == 2) key_next = 1'b1;
        @(negedge ctrl_clk);
        key_confirm = 1'b0;
        key_previous = 1'b0;
        key_next = 1'b0;
    end
endtask

task frame_tick;
    begin
        @(negedge video_clk); video_frame_tick = 1'b1;
        @(negedge video_clk); video_frame_tick = 1'b0;
        #1;
    end
endtask

initial begin
    repeat (3) @(posedge ctrl_clk);
    ctrl_rst_n = 1'b1;
    video_rst_n = 1'b1;
    enable = 1'b1;

    ctrl_pulse(1);
    if (selected_index_ctrl != 4)
        $fatal(1, "previous wrap failed: %0d", selected_index_ctrl);
    if (selected_index_video != 0)
        $fatal(1, "video selection changed outside frame boundary");

    repeat (4) @(posedge video_clk);
    frame_tick;
    if (!enable_video || selected_index_video != 4)
        $fatal(1, "frame-boundary selection publish failed");

    ctrl_pulse(2);
    if (selected_index_ctrl != 0)
        $fatal(1, "next wrap failed: %0d", selected_index_ctrl);

    ctrl_pulse(0);
    if (confirm_pulse || confirm_active_video)
        $fatal(1, "confirmation was accepted before media ready");

    media_ready = 1'b1;
    @(negedge ctrl_clk); key_confirm = 1'b1;
    @(posedge ctrl_clk); #1;
    if (!confirm_pulse)
        $fatal(1, "ready confirmation pulse missing");
    @(negedge ctrl_clk); key_confirm = 1'b0;
    repeat (4) @(posedge video_clk);
    frame_tick;
    if (!confirm_active_video)
        $fatal(1, "confirmation feedback did not reach video domain");

    @(negedge ctrl_clk); recover_index=3'd3; recover_select=1'b1;
    @(negedge ctrl_clk); recover_select=1'b0;
    if (selected_index_ctrl!=3) $fatal(1,"recovery did not follow switch");
    repeat(4) @(posedge video_clk); frame_tick;
    if (selected_index_video!=3) $fatal(1,"recovery selection did not publish");
    @(negedge ctrl_clk); recover_index=3'd7; recover_select=1'b1;
    @(negedge ctrl_clk); recover_select=1'b0;
    if (selected_index_ctrl!=0) $fatal(1,"invalid recovery switch not clamped");

    $display("PASS museum_overview_controller wrap, gate, and frame-boundary CDC");
    $finish;
end

endmodule
