`timescale 1ns / 1ps
`default_nettype none

module museum_lecture_controller #(
    parameter integer CLOCK_HZ = 50_000_000,
    parameter integer ENABLE_MANUAL = 0,
    parameter integer REUSE_OVERVIEW_SLOTS = 0
)(
    input  wire clk, input wire rst_n, input wire enable, input wire overview_ready,
    input  wire confirm_pulse, input wire key_pause, input wire key_return,
    input  wire manual_set, input wire manual_value,
    input  wire manual_image_set, input wire [1:0] manual_image,
    output reg manual_mode, output wire manual_cache_ready,
    input  wire [2:0] selected_index, input wire preload_valid,
    input  wire [2:0] preload_index, input wire audio_prepared,
    input  wire [4:0] full_home_valid,
    input  wire overview_displayed, input wire loading_allowed,
    input  wire audio_frame_pulse, input wire [31:0] audio_total_frames,
    input  wire audio_stream_done, input wire audio_drained,
    input  wire scene_timing_valid,
    input  wire [31:0] scene_cut1, input wire [31:0] scene_cut2,
    input  wire [31:0] scene_cut3, input wire [31:0] scene_cut4,
    input  wire [2:0] displayed_frame_slot,
    input  wire display_transition_busy,
    output reg load_request, input wire load_accept, input wire load_complete,
    input  wire load_error, output reg [1:0] load_slot,
    output reg [2:0] load_frame_slot, output reg [2:0] load_artifact_index,
    output wire load_detail, output wire [1:0] detail_index,
    output reg [2:0] artifact_index, output reg preloading, output reg cache_ready,
    output reg lecture_active, output reg lecture_paused, output reg lecture_finished,
    output reg audio_restart, output reg [1:0] display_slot,
    output wire [2:0] display_frame_slot, output reg media_error,
    output wire [31:0] audio_frame_index, output reg final_full_active,
    output wire [3:0] cached_artifact, output wire waiting_for_image
);

localparam [31:0] END_HOLD_CYCLES = (CLOCK_HZ * 6) / 5;
localparam integer HOLD_BITS = END_HOLD_CYCLES>1 ? $clog2(END_HOLD_CYCLES) : 1;
reg waiting_for_load, loading_next, queued_valid, queued_ready, retry_used;
reg [1:0] next_load_step;
reg [2:0] queued_artifact, current_full_slot, next_full_slot;
reg current_cache_intact;
reg return_full_pending, final_full_hold;
reg [31:0] audio_frames_played;
reg [HOLD_BITS-1:0] end_hold_count;
reg [31:0] audio_fifth;
reg [3:1] ready_details, restored_details;
reg [4:0] failed_home;
wire [31:0] audio_two_fifths = audio_fifth << 1;
wire [31:0] audio_three_fifths = audio_two_fifths + audio_fifth;
wire [31:0] audio_four_fifths = audio_fifth << 2;
wire [31:0] next_audio_frame = audio_frames_played + 1'b1;
wire [31:0] cut1 = scene_timing_valid ? scene_cut1 : audio_fifth;
wire [31:0] cut2 = scene_timing_valid ? scene_cut2 : audio_two_fifths;
wire [31:0] cut3 = scene_timing_valid ? scene_cut3 : audio_three_fifths;
wire [31:0] cut4 = scene_timing_valid ? scene_cut4 : audio_four_fifths;

assign load_detail = (load_slot != 2'd0);
assign detail_index = load_slot;
// Keep the selected full view at home. Use the first three other slots.
function [2:0] detail_frame_slot;
    input [2:0] full_slot;
    input [1:0] detail;
    reg [2:0] candidate;
    begin
        candidate = {1'b0,detail} - 1'b1;
        detail_frame_slot = candidate < full_slot ? candidate : candidate + 1'b1;
    end
endfunction

assign display_frame_slot = (display_slot == 2'd0) ? current_full_slot :
    REUSE_OVERVIEW_SLOTS ? detail_frame_slot(current_full_slot,display_slot) :
                           {1'b0,display_slot};
reg [1:0] next_detail;
reg next_is_final, next_is_end;
always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
        next_detail<=0;
        next_is_final<=0;
        next_is_end<=0;
    end else begin
        next_is_final<=next_audio_frame>=cut4;
        next_is_end<=audio_total_frames!=0 && next_audio_frame>=audio_total_frames;
        next_detail<=next_audio_frame>=cut4 ? 2'd0 :
                     next_audio_frame>=cut3 ? 2'd3 :
                     next_audio_frame>=cut2 ? 2'd2 :
                     next_audio_frame>=cut1 ? 2'd1 : 2'd0;
    end
assign waiting_for_image = REUSE_OVERVIEW_SLOTS && lecture_active &&
    !lecture_finished && !manual_mode && next_detail!=0 &&
    !ready_details[next_detail] && next_detail!=display_slot;
assign audio_frame_index = audio_frames_played;
// Image cache only: background audio/subtitles may still need preparation.
assign cached_artifact = queued_ready ? {1'b0, queued_artifact} :
                         cache_ready && current_cache_intact ? {1'b0, artifact_index} : 4'hf;
wire [1:0] next_manual_image = display_slot + 2'd1;
assign manual_cache_ready = REUSE_OVERVIEW_SLOTS ?
    cache_ready && displayed_frame_slot==display_frame_slot && !display_transition_busy &&
    (next_manual_image==0 || ready_details[next_manual_image]) :
    cache_ready && current_cache_intact && !preloading;

reg [1:0] detail_to_load;
reg [2:0] home_to_restore;
integer home;
wire [4:0] restore_candidates = ~full_home_valid & ~failed_home;
wire can_restore_while_playing = lecture_active &&
    (displayed_frame_slot == display_frame_slot) && !display_transition_busy;
reg auto_return_error;
always @(posedge clk or negedge rst_n)
    if (!rst_n) auto_return_error<=0;
    else auto_return_error<=REUSE_OVERVIEW_SLOTS && media_error && !lecture_finished;
always @* begin
    detail_to_load = 0;
    if (lecture_active) begin
        if (!ready_details[3] && !final_full_active)
            detail_to_load = 3;
        if (!ready_details[2] && display_slot<=2 && !final_full_active)
            detail_to_load = 2;
        if (!ready_details[1] && display_slot<=1 && !final_full_active)
            detail_to_load = 1;
    end
    home_to_restore = 7;
    if (can_restore_while_playing) begin
        if (ready_details[3] && !restored_details[3] && final_full_active &&
            restore_candidates[detail_frame_slot(current_full_slot,3)])
            home_to_restore = detail_frame_slot(current_full_slot,3);
        if (ready_details[2] && !restored_details[2] && (display_slot>2 || final_full_active) &&
            restore_candidates[detail_frame_slot(current_full_slot,2)])
            home_to_restore = detail_frame_slot(current_full_slot,2);
        if (ready_details[1] && !restored_details[1] && (display_slot>1 || final_full_active) &&
            restore_candidates[detail_frame_slot(current_full_slot,1)])
            home_to_restore = detail_frame_slot(current_full_slot,1);
    end else if (!lecture_active && overview_displayed) begin
        for (home=4; home>=0; home=home-1)
            if (restore_candidates[home])
                home_to_restore = home[2:0];
        if (preload_valid && !full_home_valid[preload_index] && !failed_home[preload_index])
            home_to_restore = preload_index;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        load_request<=0; waiting_for_load<=0; load_slot<=0; load_frame_slot<=0;
        load_artifact_index<=0; artifact_index<=0; preloading<=0; cache_ready<=0;
        lecture_active<=0; lecture_paused<=0; lecture_finished<=0; audio_restart<=0;
        display_slot<=0; media_error<=0; loading_next<=0; next_load_step<=0;
        queued_artifact<=0; queued_valid<=0; queued_ready<=0; retry_used<=0;
        current_full_slot<=0; next_full_slot<=4; current_cache_intact<=1;
        return_full_pending<=0; final_full_hold<=0;
        final_full_active<=0;
        audio_frames_played<=0; end_hold_count<=0;
        audio_fifth<=0;
        manual_mode<=0;
        ready_details<=0;
        restored_details<=0;
        failed_home<=0;
    end else begin
        audio_restart <= 1'b0;
        if (ENABLE_MANUAL && manual_set && (!REUSE_OVERVIEW_SLOTS || !lecture_active)) begin
            manual_mode <= manual_value;
            if (manual_value && !manual_mode) begin
                audio_restart<=1; lecture_paused<=0; audio_frames_played<=0;
            end
        end
        if (!lecture_active)
            // 0.19921875x: a shallow shift/add approximation avoids a
            // 32-bit constant divider while keeping phase error below 0.4%.
            audio_fifth <= (audio_total_frames >> 2) -
                           (audio_total_frames >> 4) +
                           (audio_total_frames >> 7) +
                           (audio_total_frames >> 8);

        if (REUSE_OVERVIEW_SLOTS) begin
            if (!lecture_active && preload_valid && artifact_index!=preload_index &&
                !preloading) begin
                artifact_index<=preload_index;
                current_full_slot<=preload_index;
                ready_details<=0;
                restored_details<=0;
                failed_home<=0;
                media_error<=0;
                cache_ready<=0;
            end else if (!lecture_active)
                cache_ready<=full_home_valid[artifact_index];
            if ((!preload_valid && !lecture_active) || key_return)
                failed_home<=0;

            if (!preloading && loading_allowed && overview_ready &&
                !(manual_set && manual_value) &&
                !(preload_valid && !lecture_active && artifact_index!=preload_index)) begin
                if (detail_to_load!=0 && !lecture_finished) begin
                    load_slot<=detail_to_load;
                    load_frame_slot<=detail_frame_slot(current_full_slot,detail_to_load);
                    load_artifact_index<=artifact_index;
                    load_request<=1;
                    preloading<=1;
                    retry_used<=0;
                end else if (home_to_restore<5 && !(lecture_active && waiting_for_image)) begin
                    load_slot<=0;
                    load_frame_slot<=home_to_restore;
                    load_artifact_index<=home_to_restore;
                    load_request<=1;
                    preloading<=1;
                    retry_used<=0;
                    if (home_to_restore==detail_frame_slot(current_full_slot,1)) restored_details[1]<=1;
                    if (home_to_restore==detail_frame_slot(current_full_slot,2)) restored_details[2]<=1;
                    if (home_to_restore==detail_frame_slot(current_full_slot,3)) restored_details[3]<=1;
                end
            end
            if (load_request && !loading_allowed) begin
                load_request<=0;
                preloading<=0;
            end else if (load_request && load_accept) begin
                load_request<=0;
                waiting_for_load<=1;
            end
            if (waiting_for_load && (load_complete || load_error)) begin
                waiting_for_load<=0;
                preloading<=0;
                if (load_error && !retry_used && loading_allowed) begin
                    load_request<=1;
                    preloading<=1;
                    retry_used<=1;
                end else if (load_error && loading_allowed) begin
                    if (load_slot==0)
                        failed_home[load_frame_slot]<=1;
                    else if (load_artifact_index==artifact_index)
                        media_error<=1;
                end else if (load_complete && load_slot!=0 && load_artifact_index==artifact_index)
                    ready_details[load_slot]<=1;
            end
        end else begin
        if (enable && overview_ready && preload_valid && !lecture_active && !preloading &&
            ((!cache_ready || artifact_index != preload_index) &&
             (!media_error || artifact_index != preload_index))) begin
            artifact_index<=preload_index; load_artifact_index<=preload_index;
            load_slot<=0; load_frame_slot<=0; load_request<=1; waiting_for_load<=0;
            preloading<=1; loading_next<=0; cache_ready<=0; media_error<=0;
            retry_used<=0;
            current_full_slot<=0; next_full_slot<=4; current_cache_intact<=1;
        end

        // Slots 0/4 ping-pong as the full-view buffer. Detail slots 1/2/3
        // are overwritten only after the video domain has left each detail.
        if (lecture_active && preload_valid && preload_index != artifact_index &&
            !queued_valid && !preloading && !manual_mode &&
            !(ENABLE_MANUAL && manual_set && manual_value)) begin
            queued_artifact<=preload_index; queued_valid<=1; queued_ready<=0;
            next_full_slot<=(current_full_slot==0)?4:0; next_load_step<=0;
            load_artifact_index<=preload_index; load_slot<=0;
            load_frame_slot<=(current_full_slot==0)?4:0;
            load_request<=1; waiting_for_load<=0; preloading<=1; loading_next<=1;
            media_error<=0;
        end

        if (preloading && loading_next && !load_request && !waiting_for_load) begin
            if (next_load_step==1 && (!lecture_active || displayed_frame_slot==2)) begin
                load_slot<=1; load_frame_slot<=1; load_request<=1;
            end else if (next_load_step==2 && (!lecture_active || displayed_frame_slot==3)) begin
                load_slot<=2; load_frame_slot<=2; load_request<=1;
            end else if (next_load_step==3 &&
                         (!lecture_active || displayed_frame_slot==current_full_slot)) begin
                load_slot<=3; load_frame_slot<=3; load_request<=1;
            end
        end

        if (preloading && load_request && load_accept) begin
            load_request<=0; waiting_for_load<=1;
            if (loading_next && load_slot!=0)
                current_cache_intact<=0;
        end

        if (preloading && waiting_for_load && load_error) begin
            waiting_for_load<=0;
            if (!loading_next && !retry_used && preload_valid &&
                preload_index==artifact_index) begin
                load_slot<=0; load_frame_slot<=0; load_request<=1;
                retry_used<=1; media_error<=0;
            end else begin
                preloading<=0; load_request<=0; media_error<=1;
                if (loading_next) begin
                    queued_valid<=0; queued_ready<=0; loading_next<=0;
                end else cache_ready<=0;
            end
        end else if (preloading && waiting_for_load && load_complete) begin
            waiting_for_load<=0;
            if (loading_next) begin
                if (!preload_valid || preload_index==artifact_index) begin
                    preloading<=0; loading_next<=0; queued_valid<=0; queued_ready<=0;
                end else if (preload_index!=queued_artifact) begin
                    queued_artifact<=preload_index; load_artifact_index<=preload_index;
                    next_load_step<=0; load_slot<=0; load_frame_slot<=next_full_slot;
                    load_request<=1; queued_ready<=0;
                end else if (next_load_step==3) begin
                    preloading<=0; loading_next<=0;
                    if (lecture_active) begin
                        queued_ready<=1;
                    end else begin
                        artifact_index<=queued_artifact;
                        current_full_slot<=next_full_slot;
                        cache_ready<=1; current_cache_intact<=1;
                        queued_valid<=0; queued_ready<=0;
                    end
                end else next_load_step<=next_load_step+1'b1;
            end else if (load_slot==3) begin
                if (preload_valid && preload_index==artifact_index) begin
                    preloading<=0; cache_ready<=1; current_cache_intact<=1;
                end else if (preload_valid) begin
                    artifact_index<=preload_index; load_artifact_index<=preload_index;
                    load_slot<=0; load_frame_slot<=0; load_request<=1; cache_ready<=0;
                end else begin preloading<=0; cache_ready<=0; end
            end else begin
                load_slot<=load_slot+1'b1; load_frame_slot<=load_frame_slot+1'b1;
                load_request<=1;
            end
        end
        end

        if (!lecture_active && enable && preload_valid && cache_ready &&
            artifact_index==selected_index && (audio_prepared || manual_mode) && confirm_pulse &&
            (!REUSE_OVERVIEW_SLOTS || full_home_valid[artifact_index]) &&
            !(ENABLE_MANUAL && manual_set)) begin
            lecture_active<=1; lecture_paused<=0; lecture_finished<=0; display_slot<=0;
            audio_frames_played<=0; end_hold_count<=0; queued_valid<=0; queued_ready<=0;
            return_full_pending<=0; final_full_hold<=0;
            final_full_active<=0;
        end

        if (lecture_active) begin
            if (key_return || (auto_return_error && !lecture_finished) ||
                (!REUSE_OVERVIEW_SLOTS && ENABLE_MANUAL && manual_set && !manual_value && manual_mode)) begin
                audio_restart<=1; lecture_paused<=0; lecture_finished<=1;
                display_slot<=0; audio_frames_played<=0; end_hold_count<=0;
                return_full_pending<=1; final_full_hold<=0;
                final_full_active<=1;
            end else if (!lecture_finished &&
                         (manual_mode || (!REUSE_OVERVIEW_SLOTS && ENABLE_MANUAL &&
                                         manual_set && manual_value))) begin
                if (ENABLE_MANUAL && manual_image_set &&
                    (!REUSE_OVERVIEW_SLOTS ||
                     (manual_cache_ready && manual_image==next_manual_image))) begin
                    display_slot<=manual_image;
                    if (REUSE_OVERVIEW_SLOTS && next_manual_image==0) begin
                        lecture_finished<=1;
                        return_full_pending<=1;
                        final_full_active<=1;
                    end else if (!REUSE_OVERVIEW_SLOTS) final_full_active<=0;
                end
            end else if (!lecture_finished) begin
                if (key_pause) lecture_paused<=~lecture_paused;
                if (audio_frame_pulse && !lecture_paused) begin
                    audio_frames_played<=next_audio_frame;
                    if (REUSE_OVERVIEW_SLOTS ? next_is_end :
                        (audio_total_frames!=0 && next_audio_frame>=audio_total_frames)) begin
                        lecture_finished<=1; lecture_paused<=0; display_slot<=0;
                        end_hold_count<=0; return_full_pending<=1;
                        final_full_hold<=1;
                        final_full_active<=1;
                    end else if (REUSE_OVERVIEW_SLOTS && !waiting_for_image) begin
                        display_slot<=next_detail;
                        final_full_active<=next_is_final;
                    end else if (!REUSE_OVERVIEW_SLOTS && next_audio_frame>=cut4) begin
                        display_slot<=0;
                        final_full_active<=1;
                    end else if (!REUSE_OVERVIEW_SLOTS && next_audio_frame>=cut3) begin
                        display_slot<=3; final_full_active<=0;
                    end else if (!REUSE_OVERVIEW_SLOTS && next_audio_frame>=cut2) begin
                        display_slot<=2; final_full_active<=0;
                    end else if (!REUSE_OVERVIEW_SLOTS && next_audio_frame>=cut1) begin
                        display_slot<=1; final_full_active<=0;
                    end else if (!REUSE_OVERVIEW_SLOTS) begin
                        display_slot<=0;
                        final_full_active<=0;
                    end
                end
            end else if (key_pause && final_full_hold) begin
                lecture_paused<=~lecture_paused;
            end else if (lecture_paused && final_full_hold) begin
                end_hold_count<=end_hold_count;
            end else if (return_full_pending &&
                         displayed_frame_slot==current_full_slot &&
                         !display_transition_busy && final_full_hold) begin
                return_full_pending<=0; end_hold_count<=0;
            end else if ((!return_full_pending && final_full_hold &&
                          (END_HOLD_CYCLES<=1 ||
                           end_hold_count==END_HOLD_CYCLES-1'b1)) ||
                         (return_full_pending &&
                          displayed_frame_slot==current_full_slot &&
                          !display_transition_busy && !final_full_hold)) begin
                audio_restart<=1; lecture_active<=0; lecture_finished<=0;
                display_slot<=0; audio_frames_played<=0; end_hold_count<=0;
                return_full_pending<=0; final_full_hold<=0;
                final_full_active<=0;
                if (REUSE_OVERVIEW_SLOTS) begin
                    media_error<=0;
                    ready_details<=0;
                    restored_details<=0;
                end else if (queued_ready && preload_valid && preload_index==queued_artifact) begin
                    artifact_index<=queued_artifact; current_full_slot<=next_full_slot;
                    cache_ready<=1; current_cache_intact<=1;
                    queued_valid<=0; queued_ready<=0;
                    preloading<=0; loading_next<=0;
                    load_request<=0; waiting_for_load<=0;
                end else if (queued_valid && preload_valid &&
                             preload_index==queued_artifact) begin
                    cache_ready<=0;
                end else begin
                    if (!current_cache_intact ||
                        (preload_valid && preload_index!=artifact_index))
                    cache_ready<=0;
                    preloading<=0; loading_next<=0;
                    load_request<=0; waiting_for_load<=0;
                    queued_valid<=0; queued_ready<=0;
                end
            end else if (!return_full_pending && final_full_hold)
                end_hold_count<=end_hold_count+1'b1;
        end
    end
end
endmodule
`default_nettype wire
