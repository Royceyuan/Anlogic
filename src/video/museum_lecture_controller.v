`timescale 1ns / 1ps
`default_nettype none

module museum_lecture_controller #(
    parameter integer CLOCK_HZ = 50_000_000,
    parameter integer END_HOLD_SECONDS = 5
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire        overview_ready,
    input  wire        confirm_pulse,
    input  wire        key_pause,
    input  wire        key_return,
    input  wire [2:0]  selected_index,
    input  wire        preload_valid,
    input  wire [2:0]  preload_index,
    input  wire        audio_prepared,
    input  wire        audio_frame_pulse,
    input  wire [31:0] audio_total_frames,
    input  wire        audio_stream_done,
    output reg         load_request,
    input  wire        load_accept,
    input  wire        load_complete,
    input  wire        load_error,
    output reg  [1:0]  load_slot,
    output wire        load_detail,
    output wire [1:0]  detail_index,
    output reg  [2:0]  artifact_index,
    output reg         preloading,
    output reg         cache_ready,
    output reg         lecture_active,
    output reg         lecture_paused,
    output reg         lecture_finished,
    output reg         audio_restart,
    output reg  [1:0]  display_slot,
    output reg         media_error
);

localparam [31:0] END_HOLD_CYCLES = CLOCK_HZ * END_HOLD_SECONDS;

reg waiting_for_load;
reg [31:0] audio_frames_played;
reg [31:0] end_hold_count;

wire [31:0] audio_quarter = audio_total_frames >> 2;
wire [31:0] audio_half = audio_total_frames >> 1;
wire [31:0] audio_three_quarters = audio_half + audio_quarter;
wire [31:0] next_audio_frame = audio_frames_played + 1'b1;

assign load_detail = (load_slot != 2'd0);
assign detail_index = load_slot;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        load_request        <= 1'b0;
        waiting_for_load    <= 1'b0;
        load_slot           <= 2'd0;
        artifact_index      <= 3'd0;
        preloading          <= 1'b0;
        cache_ready         <= 1'b0;
        lecture_active      <= 1'b0;
        lecture_paused      <= 1'b0;
        lecture_finished    <= 1'b0;
        audio_restart       <= 1'b0;
        display_slot        <= 2'd0;
        media_error         <= 1'b0;
        audio_frames_played <= 32'd0;
        end_hold_count      <= 32'd0;
    end else begin
        audio_restart <= 1'b0;
        // Load the switch-selected artifact while the stable composite overview
        // remains visible. Confirmation only starts already-prepared media.
        if (enable && overview_ready && preload_valid && !lecture_active && !preloading &&
            ((!cache_ready || artifact_index != preload_index) &&
             (!media_error || artifact_index != preload_index))) begin
            artifact_index   <= preload_index;
            load_slot        <= 2'd0;
            load_request     <= 1'b1;
            waiting_for_load <= 1'b0;
            preloading       <= 1'b1;
            cache_ready      <= 1'b0;
            media_error      <= 1'b0;
        end

        if (preloading && load_request && load_accept) begin
            load_request     <= 1'b0;
            waiting_for_load <= 1'b1;
        end

        if (preloading && waiting_for_load && load_error) begin
            waiting_for_load <= 1'b0;
            preloading       <= 1'b0;
            cache_ready      <= 1'b0;
            media_error      <= 1'b1;
        end else if (preloading && waiting_for_load && load_complete) begin
            waiting_for_load <= 1'b0;
            if (load_slot == 2'd3) begin
                if (preload_valid && preload_index == artifact_index) begin
                    preloading  <= 1'b0;
                    cache_ready <= 1'b1;
                end else if (preload_valid) begin
                    artifact_index <= preload_index;
                    load_slot      <= 2'd0;
                    load_request   <= 1'b1;
                    cache_ready    <= 1'b0;
                end else begin
                    preloading  <= 1'b0;
                    cache_ready <= 1'b0;
                end
            end else begin
                load_slot    <= load_slot + 1'b1;
                load_request <= 1'b1;
            end
        end

        if (!lecture_active && enable && preload_valid && cache_ready &&
            artifact_index == selected_index && audio_prepared && confirm_pulse) begin
            lecture_active      <= 1'b1;
            lecture_paused      <= 1'b0;
            lecture_finished    <= 1'b0;
            display_slot        <= 2'd0;
            audio_frames_played <= 32'd0;
            end_hold_count      <= 32'd0;
        end

        if (lecture_active) begin
            if (key_return) begin
                audio_restart       <= 1'b1;
                lecture_active      <= 1'b0;
                lecture_paused      <= 1'b0;
                lecture_finished    <= 1'b0;
                display_slot        <= 2'd0;
                audio_frames_played <= 32'd0;
                end_hold_count      <= 32'd0;
            end else if (!lecture_finished) begin
                if (key_pause)
                    lecture_paused <= ~lecture_paused;

                if (audio_frame_pulse && !lecture_paused) begin
                    audio_frames_played <= next_audio_frame;
                    if (next_audio_frame >= audio_three_quarters)
                        display_slot <= 2'd3;
                    else if (next_audio_frame >= audio_half)
                        display_slot <= 2'd2;
                    else if (next_audio_frame >= audio_quarter)
                        display_slot <= 2'd1;

                    if (audio_stream_done && audio_total_frames != 0 &&
                        next_audio_frame >= audio_total_frames) begin
                        lecture_finished <= 1'b1;
                        lecture_paused   <= 1'b0;
                        display_slot     <= 2'd3;
                        end_hold_count   <= 32'd0;
                    end
                end
            end else if (END_HOLD_CYCLES <= 1 ||
                         end_hold_count == END_HOLD_CYCLES - 1'b1) begin
                audio_restart       <= 1'b1;
                lecture_active      <= 1'b0;
                lecture_finished    <= 1'b0;
                display_slot        <= 2'd0;
                audio_frames_played <= 32'd0;
                end_hold_count      <= 32'd0;
            end else begin
                end_hold_count <= end_hold_count + 1'b1;
            end
        end
    end
end

endmodule

`default_nettype wire
