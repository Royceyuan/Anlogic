`timescale 1ns/1ps
`default_nettype none
module tb_secondary_page_switch;
localparam ENABLE_MULTI_FRAME_PRELOAD=1, SECONDARY_STREAMING=1, ENABLE_FADE=1;
localparam ENABLE_DUAL_FRAME_PRELOAD=0, ENABLE_MUSEUM_LECTURE=0, LINEBUF_SCALE=0;
localparam VIDEO_FRAME_COUNT=5, MODE_PRODUCT_SHOW=0;
reg video_clk=0, video_rst_n=0;
reg video_frame_tick=0, video_vblank_start=0, video_frame_start=0;
reg video_read_req_ack=0;
wire video_read_en=0, read_fifo_empty=0, linebuf_underflow=0, linebuf_frame_ready=0;
wire overview_enable_video=0, detail_zoom_2x=0, auto_mode=1;
wire [1:0] active_picture_style=0;
wire [2:0] selected_transition_mode=2, lecture_transition_mode=0;
wire [3:0] sw=0;
wire [2:0] ui_mode=0;
wire [3:0] desired_display_media_index;
reg checks_passed=0;
integer i;
always #5 video_clk=~video_clk;
`include "video_fsm.vh"
assign desired_display_media_index=preload_select_media_ff2;

task clocks(input integer n);
    integer k;
    begin for(k=0;k<n;k=k+1) begin @(posedge video_clk); #1; end end
endtask
task tick;
    begin
        @(negedge video_clk); video_frame_tick=1;
        clocks(1);
        @(negedge video_clk); video_frame_tick=0;
    end
endtask
task boundary;
    begin
        @(negedge video_clk); video_vblank_start=1;
        clocks(1);
        @(negedge video_clk); video_vblank_start=0;
    end
endtask
task refill;
    begin
        video_read_req_ack=1; clocks(2); video_read_req_ack=0;
        clocks(2050);
        @(negedge video_clk); video_frame_start=1;
        clocks(1);
        @(negedge video_clk); video_frame_start=0;
        if (!video_run) $fatal(1,"read prefill did not restart display");
    end
endtask
task reset_hero;
    begin
        @(negedge video_clk); video_rst_n=0;
        frame_ready_toggle=0; preload_select_media_index=0; preload_select_info_slot=2;
        published_frame_index=0; published_media_index=0;
        published_source_width_bcd=16'h1280; published_source_height_bcd=16'h0720;
        preload_select_frame_index=0; preload_select_source_width_bcd=16'h1280;
        preload_select_source_height_bcd=16'h0720;
        stream_tag0=0; stream_tag1=1; frame_valid=3; overview_cache_ready=0;
        transition_context=0;
        brightness_level=0; contrast_level=0; auto_speed_level=1;
        slideshow_paused=0; osd_panel_enable=0;
        clocks(3); @(negedge video_clk); video_rst_n=1; clocks(4);
        @(negedge video_clk); video_run=1;
    end
endtask
initial begin
    reset_hero();
    preload_select_media_index=5; clocks(4);
    if (!switch_pending || direct_switch_pending || transition_mode != 0 || !fade_out_active)
        $fatal(1,"lecture must select the existing fade path");
    for(i=0;i<15;i=i+1) begin
        tick(); boundary();
        if(display_media_index != 0 || !video_run) $fatal(1,"lecture switched before fade midpoint");
    end
    tick(); boundary();
    if(display_media_index != 5 || video_run || fade_level != 0)
        $fatal(1,"lecture did not switch while fully faded at vblank");
    refill();
    for(i=0;i<16;i=i+1) tick();
    if(fade_level != 16) $fatal(1,"lecture did not fade in completely");

    preload_select_media_index=6; clocks(4);
    if(!direct_switch_pending || fade_out_active) $fatal(1,"emergency must skip fade");
    boundary();
    if(display_media_index != 6 || fade_level != 16) $fatal(1,"emergency switch failed");
    refill();
    preload_select_media_index=0; clocks(4); boundary(); refill();
    if(display_media_index != 0 || fade_level != 16) $fatal(1,"emergency return failed");

    reset_hero(); preload_select_media_index=5; clocks(4); tick(); tick();
    preload_select_media_index=6; clocks(4); boundary();
    if(display_media_index != 6 || fade_level != 16)
        $fatal(1,"emergency failed to interrupt lecture fade");
    reset_hero(); preload_select_media_index=1; clocks(4);
    if(direct_switch_pending || transition_mode != 2 || !fade_out_active)
        $fatal(1,"carousel transition changed");
    checks_passed=1;
    $display("PASS: production page FSM lecture fade, emergency direct/preemption, carousel preserved");
    $finish;
end
initial begin #1000000; $fatal(1,"page switch watchdog"); end
endmodule
`default_nettype wire
