`timescale 1ns / 1ps
`default_nettype none

// Brightness transition for a completed frame switch. The level is 4..16 and
// is sampled in the video clock domain, so the pixel path has no frame-buffer
// handshake.
module video_fade (
    input  wire [23:0] rgb_in,
    input  wire [4:0]  level,
    output reg  [23:0] rgb_out
);

reg [12:0] red_scaled;
reg [12:0] green_scaled;
reg [12:0] blue_scaled;
reg [5:0] fade_scale;

always @(*) begin
    // Never reach pure black during a switch. The frame boundary is still
    // held until vertical blanking, so no half-updated frame is shown.
    fade_scale   = {1'b0, level};
    red_scaled   = {5'd0, rgb_in[23:16]} * fade_scale;
    green_scaled = {5'd0, rgb_in[15:8]}  * fade_scale;
    blue_scaled  = {5'd0, rgb_in[7:0]}   * fade_scale;
    rgb_out = {red_scaled[11:4], green_scaled[11:4], blue_scaled[11:4]};
end

endmodule

`default_nettype wire
