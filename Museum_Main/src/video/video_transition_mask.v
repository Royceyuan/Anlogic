`timescale 1ns / 1ps
`default_nettype none

// Single-frame transition effects.  The caller selects either the established
// fade path or the full-brightness path before this geometry-only mask.
module video_transition_mask #(
    parameter integer VIDEO_W = 800,
    parameter integer VIDEO_H = 600,
    parameter integer PIPE_MASK_3 = 0
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [23:0] rgb_in,
    input  wire        de,
    input  wire [10:0] x,
    input  wire [9:0]  y,
    input  wire [2:0]  mode,
    input  wire [2:0]  origin_index,
    input  wire [7:0]  progress,
    input  wire        closing,
    input  wire        overview_source,
    input  wire        enable,
    output reg  [23:0] rgb_out
);

reg [4:0] phase_step;
reg [4:0] shape_step;
reg reveal;
reg [10:0] h_limit;
reg [9:0] v_limit;
reg [10:0] center_half_w;
reg [9:0] center_half_h;
reg [10:0] dx;
reg [9:0] dy;
reg [11:0] diamond_distance;
reg [10:0] diamond_limit;
reg [10:0] panel_left;
reg [10:0] panel_right;
reg [6:0] museum_step;
reg [6:0] museum_fade_level;
reg [10:0] panel_left_next;
reg [10:0] panel_right_next;
reg [6:0] museum_fade_level_next;
reg [5:0] museum_fade_threshold;
reg pass_pixel;
wire pass_pixel_aligned;
reg [5:0] band_step;
reg [13:0] band_scaled;
reg [9:0] band_limit;

always @(*) begin
    phase_step = closing ? progress[4:0] :
                 ((progress >= 6'd16) ? progress[4:0] - 5'd16 : 5'd0);
    if (phase_step > 5'd16)
        phase_step = 5'd16;
    shape_step = closing ? (5'd16 - phase_step) : phase_step;

    // Sixteen geometry steps make both endpoints exact: the old source is
    // fully hidden at the midpoint and the new source starts fully hidden.
    // The active 1280x720 path uses shifts/adds instead of two video-rate
    // multipliers.  The generic fallback keeps the reusable 800x600 path.
    if (VIDEO_W == 1280)
        h_limit = {shape_step, 6'b0} + {2'b0, shape_step, 4'b0};
    else
        h_limit = (shape_step * VIDEO_W) >> 4;
    if (VIDEO_H == 720)
        v_limit = {shape_step, 5'b0} + {2'b0, shape_step, 3'b0} +
                  {3'b0, shape_step, 2'b0} + {5'b0, shape_step};
    else
        v_limit = (shape_step * VIDEO_H) >> 4;
    center_half_w = h_limit >> 1;
    center_half_h = v_limit >> 1;
    if (x >= (VIDEO_W / 2))
        dx = x - (VIDEO_W / 2);
    else
        dx = (VIDEO_W / 2) - x;
    if (y >= (VIDEO_H / 2))
        dy = y - (VIDEO_H / 2);
    else
        dy = (VIDEO_H / 2) - y;
    diamond_distance = {1'b0, dx} + {2'b0, dy};
    // Mode 7: 32 frames close, then 32 frames open, with plain black edges.
    band_step = closing ? ((progress < 32) ? 6'd32 - progress[5:0] : 6'd0) :
                          ((progress >= 64) ? 6'd32 :
                           (progress >= 32) ? progress[5:0] - 6'd32 : 6'd0);
    if (VIDEO_H == 720)
        band_scaled = {band_step, 5'b0} + {band_step, 3'b0} +
                      {band_step, 2'b0} + band_step; // radius = step * 45 / 4
    else
        band_scaled = (band_step * VIDEO_H) >> 4;
    band_limit = band_scaled >> 2;
    if (VIDEO_W == 1280 && VIDEO_H == 720)
        diamond_limit = {shape_step, 6'b0} - shape_step - (shape_step >> 1);
    else
        diamond_limit = (shape_step * ((VIDEO_W / 2) + (VIDEO_H / 2))) >> 4;

    // Museum mode 5 uses 128 frame steps.  With the overview source, the
    // selected panel moves to/from x=512 while the other panels fade.  With
    // the full-image source, the unchanged center crop reveals/contracts by
    // eight pixels per side per frame.
    museum_step = 7'd0;
    panel_left_next = 11'd512;
    panel_right_next = 11'd768;
    museum_fade_level_next = 7'd64;
    // Interleaved coordinate bits distribute each new brightness step over
    // an 8x8 cell instead of introducing a visible vertical wipe.
    museum_fade_threshold = {x[0], y[0], x[1], y[1], x[2], y[2]};
    if (overview_source) begin
        museum_step = closing ? progress[6:0] : 8'd128 - progress;
        if (museum_step > 7'd64)
            museum_step = 7'd64;
        museum_fade_level_next = 7'd64 - museum_step;
        case (origin_index)
            3'd0: panel_left_next = {museum_step, 3'b000};
            3'd1: panel_left_next = 11'd256 + {museum_step, 2'b00};
            3'd2: panel_left_next = 11'd512;
            3'd3: panel_left_next = 11'd768 - {museum_step, 2'b00};
            default: panel_left_next = 11'd1024 - {museum_step, 3'b000};
        endcase
        panel_right_next = panel_left_next + 11'd256;
    end else begin
        museum_step = closing ? 7'd64 - progress[6:0] :
                                progress[6:0] - 7'd64;
        if (museum_step > 7'd64)
            museum_step = closing ? 7'd64 : 7'd0;
        panel_left_next = 11'd512 - {museum_step, 3'b000};
        panel_right_next = 11'd768 + {museum_step, 3'b000};
    end

    if (PIPE_MASK_3 && (mode == 3'd1 || mode == 3'd2 || mode == 3'd3))
        reveal = 1'b0; // These comparisons are performed in pipeline stage 2.
    else if (mode == 3'd7)
        reveal = (band_step == 32) || (dy < band_limit);
    else if (mode == 3'b101)
        reveal = (x >= panel_left) && (x < panel_right);
    else if (shape_step == 0)
        reveal = 1'b0;
    else if (shape_step >= 16)
        reveal = 1'b1;
    else begin
        case (mode)
            3'b001: reveal = (x < h_limit);                       // wipe
            3'b010: reveal = (dx < center_half_w);                // curtain
            3'b011: reveal = (dx < center_half_w) &&
                            (dy < center_half_h);                 // zoom reveal
            3'b101: reveal = (x >= panel_left) && (x < panel_right);
            // The pipelined path spreads abs/add/compare across its existing
            // three clocks; the direct path retains the original geometry.
            3'b110: reveal = !PIPE_MASK_3 && (diamond_distance < diamond_limit);
            default: reveal = 1'b1;                               // fade
        endcase
    end

    pass_pixel = (mode == 3'b000) || !de || !enable || reveal ||
                 (mode == 3'b101 && overview_source &&
                  ({1'b0, museum_fade_threshold} < museum_fade_level));
end

generate
    if (PIPE_MASK_3) begin : g_pipe_mask
        reg pass_d1, pass_d2, pass_d3;
        reg [10:0] dx_d1, diamond_limit_d1, diamond_limit_d2;
        reg [9:0] dy_d1;
        reg [11:0] diamond_distance_d2;
        reg [2:0] mode_d1;
        reg diamond_mode_d2;
        reg [10:0] x_d1, linear_limit_d1;
        reg [9:0] vertical_limit_d1;
        reg shape_zero_d1;
        reg diamond_bypass_d1, diamond_bypass_d2;
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                pass_d1 <= 1'b0;
                pass_d2 <= 1'b0;
                pass_d3 <= 1'b0;
                dx_d1 <= 11'd0;
                dy_d1 <= 10'd0;
                diamond_limit_d1 <= 11'd0;
                diamond_limit_d2 <= 11'd0;
                diamond_distance_d2 <= 12'd0;
                mode_d1 <= 3'd0;
                x_d1 <= 11'd0;
                linear_limit_d1 <= 11'd0;
                vertical_limit_d1 <= 10'd0;
                shape_zero_d1 <= 1'b1;
                diamond_mode_d2 <= 1'b0;
                diamond_bypass_d1 <= 1'b0;
                diamond_bypass_d2 <= 1'b0;
            end else begin
                pass_d1 <= pass_pixel;
                // Split the linear masks across the same existing three clocks:
                // progress/limits first, pixel comparisons second, output third.
                case (mode_d1)
                    3'd1: pass_d2 <= diamond_bypass_d1 ||
                                    (!shape_zero_d1 && x_d1 < linear_limit_d1);
                    3'd2: pass_d2 <= diamond_bypass_d1 ||
                                    (!shape_zero_d1 && dx_d1 < linear_limit_d1);
                    3'd3: pass_d2 <= diamond_bypass_d1 ||
                                    (!shape_zero_d1 && dx_d1 < linear_limit_d1 &&
                                     dy_d1 < vertical_limit_d1);
                    default: pass_d2 <= pass_d1;
                endcase
                pass_d3 <= diamond_mode_d2 ?
                           (diamond_bypass_d2 || diamond_distance_d2 < diamond_limit_d2) :
                           pass_d2;
                dx_d1 <= dx;
                dy_d1 <= dy;
                diamond_limit_d1 <= diamond_limit;
                diamond_limit_d2 <= diamond_limit_d1;
                diamond_distance_d2 <= {1'b0, dx_d1} + {2'b0, dy_d1};
                mode_d1 <= mode;
                diamond_mode_d2 <= mode_d1 == 3'd6;
                x_d1 <= x;
                linear_limit_d1 <= mode == 3'd1 ? h_limit : center_half_w;
                vertical_limit_d1 <= center_half_h;
                shape_zero_d1 <= shape_step == 0;
                diamond_bypass_d1 <= !de || !enable || shape_step >= 16;
                diamond_bypass_d2 <= diamond_bypass_d1;
            end
        end
        assign pass_pixel_aligned = pass_d3;
    end else begin : g_direct_mask
        assign pass_pixel_aligned = pass_pixel;
    end
endgenerate

always @(*)
    rgb_out = pass_pixel_aligned ? rgb_in : 24'h000000;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        panel_left <= 11'd512;
        panel_right <= 11'd768;
        museum_fade_level <= 7'd64;
    end else begin
        panel_left <= panel_left_next;
        panel_right <= panel_right_next;
        museum_fade_level <= museum_fade_level_next;
    end
end

endmodule

`default_nettype wire
