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
    input  wire [5:0]  progress,
    input  wire        closing,
    input  wire        enable,
    output reg  [23:0] rgb_out
);

reg [4:0] phase_step;
reg [4:0] shape_step;
reg reveal;
reg [15:0] h_scaled;
reg [14:0] v_scaled;
reg [10:0] h_limit;
reg [9:0] v_limit;
reg [10:0] center_half_w;
reg [9:0] center_half_h;
reg [10:0] dx;
reg [9:0] dy;

always @(*) begin
    phase_step = closing ? progress[4:0] :
                 ((progress >= 6'd16) ? progress[4:0] - 5'd16 : 5'd0);
    if (phase_step > 5'd16)
        phase_step = 5'd16;
    shape_step = closing ? (5'd16 - phase_step) : phase_step;

    // Sixteen geometry steps make both endpoints exact: the old source is
    // fully hidden at the midpoint and the new source starts fully hidden.
    h_scaled = shape_step * VIDEO_W;
    v_scaled = shape_step * VIDEO_H;
    h_limit = h_scaled >> 4;
    v_limit = v_scaled >> 4;
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

    if (shape_step == 0)
        reveal = 1'b0;
    else if (shape_step >= 16)
        reveal = 1'b1;
    else begin
        case (mode)
            3'b001: reveal = (x < h_limit);                       // wipe
            3'b010: reveal = (dx < center_half_w);                // curtain
            3'b011: reveal = (dx < center_half_w) &&
                            (dy < center_half_h);                 // zoom reveal
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
