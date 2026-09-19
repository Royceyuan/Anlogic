`timescale 1ns / 1ps
`default_nettype none

// Border/placeholder overlay for the SDRAM-backed five-column overview.
// Picture pixels already come from the sixth 960x540 frame, so this block
// intentionally contains no thumbnail memory.
module museum_overview_overlay #(
    parameter integer VIDEO_W = 1280,
    parameter integer VIDEO_H = 720,
    parameter integer PANEL_COUNT = 5,
    parameter integer BORDER = 1,
    parameter integer HIGHLIGHT_WIDTH = 2
) (
    input  wire        video_clk,
    input  wire        video_rst_n,
    input  wire        video_frame_tick,
    input  wire        overview_enable,
    input  wire [2:0]  selected_index,
    input  wire        confirm_active,
    input  wire [4:0]  frame_valid,
    input  wire        hs_i,
    input  wire        vs_i,
    input  wire        de_i,
    input  wire [10:0] x_i,
    input  wire [9:0]  y_i,
    input  wire [23:0] rgb_i,
    output reg         hs_o,
    output reg         vs_o,
    output reg         de_o,
    output reg  [10:0] x_o,
    output reg  [9:0]  y_o,
    output reg  [23:0] rgb_o
);

localparam integer PANEL_W = VIDEO_W / PANEL_COUNT;

reg [4:0] frame_valid_at_boundary;
reg overview_d, border_d, border_highlight_d, confirm_d;
reg [2:0] panel_index_d;
reg [4:0] frame_valid_d;
reg [23:0] rgb_i_d;

wire [2:0] panel_index = x_i[10:8];
wire [7:0] panel_x = x_i[7:0];
wire panel_in_range = panel_index < PANEL_COUNT;
wire left_outer_border = panel_in_range && (panel_index == 0) &&
                         (panel_x < BORDER);
wire internal_separator = panel_in_range && (panel_index != 0) &&
                          (panel_x < BORDER);
wire right_outer_border = panel_in_range &&
                          (panel_index == PANEL_COUNT - 1) &&
                          (panel_x >= PANEL_W - BORDER);
wire selected_left_border = panel_in_range &&
                            (panel_index == selected_index) &&
                            (panel_x < HIGHLIGHT_WIDTH);
wire selected_right_inner = panel_in_range &&
                            (panel_index == selected_index) &&
                            (panel_x >= PANEL_W -
                             ((panel_index == PANEL_COUNT - 1) ?
                              HIGHLIGHT_WIDTH :
                              (HIGHLIGHT_WIDTH - BORDER)));
wire selected_right_shared = internal_separator &&
                             (selected_index + 1'b1 == panel_index);
wire selected_vertical_border = selected_left_border ||
                                selected_right_inner ||
                                selected_right_shared;
wire selected_horizontal_border = panel_in_range &&
                                  (panel_index == selected_index) &&
                                  ((y_i < HIGHLIGHT_WIDTH) ||
                                   (y_i >= VIDEO_H - HIGHLIGHT_WIDTH));
wire inside_border = left_outer_border || internal_separator ||
                     right_outer_border || selected_vertical_border ||
                     selected_horizontal_border;
wire border_highlight = selected_vertical_border ||
                        selected_horizontal_border;

always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin
        frame_valid_at_boundary <= 5'd0;
        overview_d       <= 1'b0;
        border_d         <= 1'b0;
        border_highlight_d <= 1'b0;
        confirm_d        <= 1'b0;
        panel_index_d    <= 3'd0;
        frame_valid_d    <= 5'd0;
        hs_o             <= 1'b1;
        vs_o             <= 1'b1;
        de_o             <= 1'b0;
        x_o              <= 11'd0;
        y_o              <= 10'd0;
        rgb_i_d          <= 24'd0;
    end else begin
        if (video_frame_tick)
            frame_valid_at_boundary <= frame_valid;
        overview_d       <= overview_enable;
        border_d         <= inside_border;
        border_highlight_d <= border_highlight;
        confirm_d        <= confirm_active;
        panel_index_d    <= panel_index;
        frame_valid_d    <= frame_valid_at_boundary;
        hs_o             <= hs_i;
        vs_o             <= vs_i;
        de_o             <= de_i;
        x_o              <= x_i;
        y_o              <= y_i;
        rgb_i_d          <= rgb_i;
    end
end

always @(*) begin
    if (!de_o)
        rgb_o = 24'h000000;
    else if (!overview_d)
        rgb_o = rgb_i_d;
    else if (border_d)
        rgb_o = border_highlight_d ?
                (confirm_d ? 24'h41d17d : 24'hf2c14e) : 24'h68727d;
    else if (y_o < 10'd16)
        rgb_o = rgb_i_d;
    else if (!frame_valid_d[panel_index_d])
        rgb_o = (x_o[4] ^ y_o[4]) ? 24'h4b2532 : 24'h261820;
    else
        rgb_o = rgb_i_d;
end

endmodule

`default_nettype wire
