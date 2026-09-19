`timescale 1ns / 1ps
`default_nettype none

module museum_overview_overlay #(
    parameter integer SOURCE_W = 960,
    parameter integer SOURCE_H = 540,
    parameter integer THUMB_W = 48,
    parameter integer THUMB_H = 27,
    parameter integer DISPLAY_SCALE = 8,
    parameter integer PANEL_X0 = 32,
    parameter integer PANEL_PITCH = 416,
    parameter integer PANEL_Y0 = 24,
    parameter integer SECOND_ROW_X0 = 240,
    parameter integer SECOND_ROW_Y0 = 480,
    parameter integer BORDER = 4
) (
    input  wire        wr_clk,
    input  wire        wr_rst_n,
    input  wire        wr_start,
    input  wire [3:0]  wr_frame_index,
    input  wire        wr_valid,
    input  wire [10:0] wr_row,
    input  wire [10:0] wr_col,
    input  wire [15:0] wr_pixel,

    input  wire        video_clk,
    input  wire        video_rst_n,
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

localparam integer FRAME_COUNT = 5;
localparam integer THUMB_PIXELS = THUMB_W * THUMB_H;
localparam integer MEM_DEPTH = FRAME_COUNT * THUMB_PIXELS;
localparam integer MEM_ADDR_BITS = (MEM_DEPTH <= 2) ? 1 : $clog2(MEM_DEPTH);
localparam integer ROW_STEP = SOURCE_H / THUMB_H;
localparam integer COL_STEP = SOURCE_W / THUMB_W;
localparam integer DISPLAY_W = THUMB_W * DISPLAY_SCALE;
localparam integer DISPLAY_H = THUMB_H * DISPLAY_SCALE;

reg [15:0] thumbnail_mem [0:MEM_DEPTH-1];
reg [10:0] wr_target_row, wr_target_col;
reg [5:0] wr_thumb_col;
reg [4:0] wr_thumb_row;
reg [2:0] wr_active_frame;
reg       wr_row_seen;
reg       wr_row_ascending;
reg       wr_sample_row;

function [MEM_ADDR_BITS-1:0] frame_base;
    input [2:0] frame_index;
    begin
        frame_base = frame_index * THUMB_PIXELS;
    end
endfunction

always @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
        wr_target_row   <= 11'd0;
        wr_target_col   <= 11'd0;
        wr_thumb_col    <= 6'd0;
        wr_thumb_row    <= 5'd0;
        wr_active_frame <= 3'd0;
        wr_row_seen     <= 1'b0;
        wr_row_ascending<= 1'b1;
        wr_sample_row   <= 1'b0;
    end else if (wr_start) begin
        wr_active_frame <= wr_frame_index[2:0];
        wr_target_row   <= 11'd0;
        wr_target_col   <= 11'd0;
        wr_thumb_col    <= 6'd0;
        wr_thumb_row    <= 5'd0;
        wr_row_seen     <= 1'b0;
        wr_row_ascending<= 1'b1;
        wr_sample_row   <= 1'b0;
    end else if (wr_valid && wr_active_frame < FRAME_COUNT &&
                 (wr_row_seen || wr_col == 0)) begin
        // The loader emits complete destination rows, but a normal BMP emits
        // them bottom-up. Detect that order once, then sample every ROW_STEP
        // destination row without assuming that rows arrive in ascending Y.
        if (wr_col == 0) begin
            if (!wr_row_seen) begin
                wr_row_seen      <= 1'b1;
                wr_row_ascending <= (wr_row < SOURCE_H / 2);
                wr_target_row    <= wr_row;
                wr_sample_row    <= 1'b1;
                wr_target_col    <= COL_STEP;
                wr_thumb_col     <= 6'd1;
                wr_thumb_row     <= (wr_row < SOURCE_H / 2) ? 5'd0 : THUMB_H - 1;
                thumbnail_mem[frame_base(wr_active_frame) +
                              (((wr_row < SOURCE_H / 2) ? 0 : THUMB_H - 1) * THUMB_W)] <= wr_pixel;
            end else begin
                wr_sample_row <= (wr_row == wr_target_row);
                wr_target_col <= (wr_row == wr_target_row) ? COL_STEP : 11'd0;
                wr_thumb_col  <= (wr_row == wr_target_row) ? 6'd1 : 6'd0;
                if (wr_row == wr_target_row)
                    thumbnail_mem[frame_base(wr_active_frame) +
                                  (wr_thumb_row * THUMB_W)] <= wr_pixel;
            end
        end else if (wr_sample_row && wr_col == wr_target_col &&
                     wr_thumb_col < THUMB_W) begin
            thumbnail_mem[frame_base(wr_active_frame) +
                          (wr_thumb_row * THUMB_W) + wr_thumb_col] <= wr_pixel;
            if (wr_thumb_col == THUMB_W - 1) begin
                wr_thumb_col  <= 6'd0;
                wr_target_col <= SOURCE_W;
            end else begin
                wr_thumb_col  <= wr_thumb_col + 1'b1;
                wr_target_col <= wr_target_col + COL_STEP;
            end
        end

        if (wr_col == SOURCE_W - 1) begin
            if (wr_sample_row) begin
                if (wr_row_ascending)
                    wr_target_row <= wr_row + ROW_STEP;
                else
                    wr_target_row <= wr_row - ROW_STEP;
                if (wr_row_ascending)
                    wr_thumb_row <= wr_thumb_row + 1'b1;
                else
                    wr_thumb_row <= wr_thumb_row - 1'b1;
            end
            wr_sample_row <= 1'b0;
        end else begin
            // Keep the current sample-row state while the loader streams the
            // remaining pixels of this source row.
        end
    end
end

reg inside_thumb;
reg inside_border;
reg [2:0] panel_index;
reg [10:0] panel_x;
reg [9:0] panel_y;
reg [10:0] local_x;
reg [9:0] local_y;
reg [MEM_ADDR_BITS-1:0] read_addr;
integer panel_iter;

always @(*) begin
    inside_thumb = 1'b0;
    inside_border = 1'b0;
    panel_index = 3'd0;
    panel_x = 11'd0;
    panel_y = 10'd0;
    local_x = 11'd0;
    local_y = 10'd0;
    read_addr = {MEM_ADDR_BITS{1'b0}};
    for (panel_iter = 0; panel_iter < FRAME_COUNT; panel_iter = panel_iter + 1) begin
        if (panel_iter < 3) begin
            panel_x = PANEL_X0 + panel_iter * PANEL_PITCH;
            panel_y = PANEL_Y0;
        end else begin
            panel_x = SECOND_ROW_X0 + (panel_iter - 3) * PANEL_PITCH;
            panel_y = SECOND_ROW_Y0;
        end
        if (x_i >= panel_x - BORDER && x_i < panel_x + DISPLAY_W + BORDER &&
            y_i >= panel_y - BORDER && y_i < panel_y + DISPLAY_H + BORDER) begin
            panel_index = panel_iter[2:0];
            inside_border = 1'b1;
            if (x_i >= panel_x && x_i < panel_x + DISPLAY_W &&
                y_i >= panel_y && y_i < panel_y + DISPLAY_H) begin
                inside_thumb = 1'b1;
                inside_border = 1'b0;
                local_x = (x_i - panel_x) >> $clog2(DISPLAY_SCALE);
                local_y = (y_i - panel_y) >> $clog2(DISPLAY_SCALE);
                read_addr = frame_base(panel_iter[2:0]) +
                            local_y * THUMB_W + local_x;
            end
        end
    end
end

reg [15:0] read_pixel;
reg overview_d, inside_thumb_d, inside_border_d, confirm_d;
reg [2:0] panel_index_d, selected_index_d;
reg [4:0] frame_valid_d;
reg [23:0] rgb_i_d;

function [23:0] rgb565_to_rgb888;
    input [15:0] pixel;
    begin
        rgb565_to_rgb888 = {pixel[15:11], pixel[15:13],
                            pixel[10:5], pixel[10:9],
                            pixel[4:0], pixel[4:2]};
    end
endfunction

always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin
        read_pixel       <= 16'd0;
        overview_d       <= 1'b0;
        inside_thumb_d   <= 1'b0;
        inside_border_d  <= 1'b0;
        confirm_d        <= 1'b0;
        panel_index_d    <= 3'd0;
        selected_index_d <= 3'd0;
        frame_valid_d    <= 5'd0;
        hs_o             <= 1'b1;
        vs_o             <= 1'b1;
        de_o             <= 1'b0;
        x_o              <= 11'd0;
        y_o              <= 10'd0;
        rgb_i_d          <= 24'd0;
    end else begin
        read_pixel       <= thumbnail_mem[read_addr];
        overview_d       <= overview_enable;
        inside_thumb_d   <= inside_thumb;
        inside_border_d  <= inside_border;
        confirm_d        <= confirm_active;
        panel_index_d    <= panel_index;
        selected_index_d <= selected_index;
        frame_valid_d    <= frame_valid;
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
    else if (!overview_d || y_o < 10'd16)
        rgb_o = rgb_i_d;
    else if (inside_border_d)
        rgb_o = (panel_index_d == selected_index_d) ?
                (confirm_d ? 24'h41d17d : 24'hf2c14e) : 24'h68727d;
    else if (inside_thumb_d)
        rgb_o = frame_valid_d[panel_index_d] ?
                rgb565_to_rgb888(read_pixel) :
                ((x_o[4] ^ y_o[4]) ? 24'h4b2532 : 24'h261820);
    else
        rgb_o = 24'h101820;
end

endmodule

`default_nettype wire
