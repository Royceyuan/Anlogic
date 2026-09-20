`timescale 1ns / 1ps
`default_nettype none

// Single-frame transition effects.  The caller selects either the established
// fade path or the full-brightness path before this geometry-only mask.
module video_transition_mask #(
    parameter integer VIDEO_W = 800,
    parameter integer VIDEO_H = 600
) (
    input  wire [23:0] rgb_in,
    input  wire        de,
    input  wire [10:0] x,
    input  wire [9:0]  y,
    input  wire [2:0]  mode,
    input  wire [2:0]  origin_index,
    input  wire [5:0]  progress,
    input  wire        closing,
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
reg [10:0] panel_left;
reg [10:0] panel_right;

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

    // Museum mode 5 grows/shrinks from the selected 256-pixel overview
    // column.  All coefficients are powers-of-two sums to protect 75 MHz.
    case (origin_index)
        3'd0: begin panel_left = 11'd0;
                    panel_right = 11'd256 + {shape_step, 6'b0}; end
        3'd1: begin panel_left = 11'd256 - {2'b0, shape_step, 4'b0};
                    panel_right = 11'd512 + {1'b0, shape_step, 5'b0} +
                                  {2'b0, shape_step, 4'b0}; end
        3'd2: begin panel_left = 11'd512 - {1'b0, shape_step, 5'b0};
                    panel_right = 11'd768 + {1'b0, shape_step, 5'b0}; end
        3'd3: begin panel_left = 11'd768 - {1'b0, shape_step, 5'b0} -
                                 {2'b0, shape_step, 4'b0};
                    panel_right = 11'd1024 + {2'b0, shape_step, 4'b0}; end
        default: begin panel_left = 11'd1024 - {shape_step, 6'b0};
                       panel_right = 11'd1280; end
    endcase

    if (shape_step == 0)
        reveal = (mode == 3'b101) &&
                 (x >= panel_left) && (x < panel_right);
    else if (shape_step >= 16)
        reveal = 1'b1;
    else begin
        case (mode)
            3'b001: reveal = (x < h_limit);                       // wipe
            3'b010: reveal = (dx < center_half_w);                // curtain
            3'b011: reveal = (dx < center_half_w) &&
                            (dy < center_half_h);                 // zoom reveal
            3'b101: reveal = (x >= panel_left) && (x < panel_right);
            default: reveal = 1'b1;                               // fade
        endcase
    end

    if (mode == 3'b000)
        rgb_out = rgb_in;
    else if (!de)
        rgb_out = rgb_in;
    else if (!enable || reveal)
        rgb_out = rgb_in;
    else
        rgb_out = 24'h000000;
end

endmodule

`default_nettype wire
