`timescale 1ns / 1ps
`default_nettype none

// Self-contained timed Chinese subtitles. Text/timing and the reduced 16x16
// glyph set are generated from the five SRT files and initialized in BRAM.
module museum_subtitle_overlay #(
    parameter integer VIDEO_W = 1280,
    parameter integer VIDEO_H = 720
)(
    input wire clk_50m, input wire rst_n_50m,
    input wire lecture_active, input wire lecture_finished,
    input wire [2:0] track_index, input wire [31:0] audio_frame_index,
    input wire video_clk, input wire video_rst_n, input wire video_frame_tick,
    input wire hs_i, input wire vs_i, input wire de_i,
    input wire [10:0] x_i, input wire [9:0] y_i, input wire [23:0] rgb_i,
    output reg hs_o, output reg vs_o, output reg de_o,
    output reg [10:0] x_o, output reg [9:0] y_o, output reg [23:0] rgb_o
);

`include "src/video/museum_subtitle_data.vh"

localparam [9:0] Y_START = VIDEO_H - 44;
localparam [11:0] SCROLL_STEP = 12'd16;

reg [5:0] cue_index;
reg [2:0] active_track;
wire [7:0] cue_key = {active_track, cue_index[4:0]};
wire [31:0] cue_start = museum_cue_start(cue_key);
wire [31:0] cue_end = museum_cue_end(cue_key);
wire [11:0] cue_offset = museum_cue_offset(cue_key);
wire [5:0] cue_length = museum_cue_length(cue_key);
wire cue_visible = lecture_active && !lecture_finished &&
                   audio_frame_index >= cue_start && audio_frame_index < cue_end;

always @(posedge clk_50m or negedge rst_n_50m) begin
    if (!rst_n_50m) begin
        cue_index <= 0;
        active_track <= 0;
    end else if (!lecture_active || track_index != active_track) begin
        cue_index <= 0;
        active_track <= track_index;
    end else if (audio_frame_index >= cue_end &&
                 cue_index + 1'b1 < museum_cue_count(active_track)) begin
        cue_index <= cue_index + 1'b1;
    end
end

reg [7:0] cue_key_v1, cue_key_v2, cue_key_seen;
reg [11:0] cue_offset_v1, cue_offset_v2;
reg [5:0] cue_length_v1, cue_length_v2;
reg cue_visible_v1, cue_visible_v2;
reg [11:0] scroll_x;
wire [11:0] text_width = {cue_length_v2, 5'b00000};
wire [11:0] center_x = (text_width < VIDEO_W) ?
                        (VIDEO_W - text_width) >> 1 : 12'd0;

reg [8:0] text_rom [0:MUSEUM_TEXT_COUNT-1];
reg [15:0] glyph_rom [0:MUSEUM_GLYPH_ROWS-1];
initial begin
`ifdef SIM
    $readmemh("../src/video/museum_subtitle_text.mem", text_rom);
    $readmemh("../src/video/museum_subtitle_glyphs.mem", glyph_rom);
`else
    $readmemh("museum_subtitle_text.mem", text_rom);
    $readmemh("museum_subtitle_glyphs.mem", glyph_rom);
`endif
end

reg hs_s0, vs_s0, de_s0, hs_s1, vs_s1, de_s1, hs_s2, vs_s2, de_s2;
reg [10:0] x_s0, x_s1, x_s2;
reg [9:0] y_s0, y_s1, y_s2;
reg [23:0] rgb_s0, rgb_s1, rgb_s2;
reg bar_s0, bar_s1, bar_s2, glyph_s0, glyph_s1, glyph_s2;
reg [11:0] text_addr_s0;
reg [3:0] glyph_row_s0, glyph_row_s1;
reg [3:0] glyph_col_s0, glyph_col_s1, glyph_col_s2;
reg [8:0] text_glyph_s1;
reg [15:0] glyph_bits_s2;
reg [11:0] relative_x;
reg [5:0] char_position;

always @(*) begin
    relative_x = (x_i >= scroll_x) ? x_i - scroll_x : 12'd0;
    char_position = relative_x[10:5];
end

always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin
        cue_key_v1<=0; cue_key_v2<=0; cue_key_seen<=8'hff;
        cue_offset_v1<=0; cue_offset_v2<=0; cue_length_v1<=0; cue_length_v2<=0;
        cue_visible_v1<=0; cue_visible_v2<=0; scroll_x<=VIDEO_W;
        hs_s0<=1; vs_s0<=1; de_s0<=0; hs_s1<=1; vs_s1<=1; de_s1<=0;
        hs_s2<=1; vs_s2<=1; de_s2<=0; hs_o<=1; vs_o<=1; de_o<=0;
        x_s0<=0; x_s1<=0; x_s2<=0; x_o<=0;
        y_s0<=0; y_s1<=0; y_s2<=0; y_o<=0;
        rgb_s0<=0; rgb_s1<=0; rgb_s2<=0; rgb_o<=0;
        bar_s0<=0; bar_s1<=0; bar_s2<=0;
        glyph_s0<=0; glyph_s1<=0; glyph_s2<=0;
        text_addr_s0<=0; glyph_row_s0<=0; glyph_row_s1<=0;
        glyph_col_s0<=0; glyph_col_s1<=0; glyph_col_s2<=0;
        text_glyph_s1<=0; glyph_bits_s2<=0;
    end else begin
        cue_key_v1 <= cue_key;
        cue_key_v2 <= cue_key_v1;
        cue_offset_v1 <= cue_offset;
        cue_offset_v2 <= cue_offset_v1;
        cue_length_v1 <= cue_length;
        cue_length_v2 <= cue_length_v1;
        cue_visible_v1 <= cue_visible;
        cue_visible_v2 <= cue_visible_v1;
        if (video_frame_tick) begin
            if (cue_key_v2 != cue_key_seen) begin
                cue_key_seen <= cue_key_v2;
                scroll_x <= VIDEO_W;
            end else if (cue_visible_v2 && scroll_x > center_x) begin
                if (scroll_x - center_x <= SCROLL_STEP)
                    scroll_x <= center_x;
                else
                    scroll_x <= scroll_x - SCROLL_STEP;
            end
        end

        hs_s0<=hs_i; vs_s0<=vs_i; de_s0<=de_i;
        x_s0<=x_i; y_s0<=y_i; rgb_s0<=rgb_i;
        bar_s0 <= de_i && cue_visible_v2 && y_i>=Y_START && y_i<Y_START+32;
        glyph_s0 <= de_i && cue_visible_v2 && y_i>=Y_START && y_i<Y_START+32 &&
                    x_i>=scroll_x && char_position<cue_length_v2;
        text_addr_s0 <= cue_offset_v2 + char_position;
        glyph_row_s0 <= (y_i - Y_START) >> 1;
        glyph_col_s0 <= relative_x[4:1];

        hs_s1<=hs_s0; vs_s1<=vs_s0; de_s1<=de_s0;
        x_s1<=x_s0; y_s1<=y_s0; rgb_s1<=rgb_s0;
        bar_s1<=bar_s0; glyph_s1<=glyph_s0;
        glyph_row_s1<=glyph_row_s0; glyph_col_s1<=glyph_col_s0;
        text_glyph_s1 <= text_rom[text_addr_s0];

        hs_s2<=hs_s1; vs_s2<=vs_s1; de_s2<=de_s1;
        x_s2<=x_s1; y_s2<=y_s1; rgb_s2<=rgb_s1;
        bar_s2<=bar_s1; glyph_s2<=glyph_s1; glyph_col_s2<=glyph_col_s1;
        glyph_bits_s2 <= glyph_rom[{text_glyph_s1, 4'b0000} + glyph_row_s1];

        hs_o<=hs_s2; vs_o<=vs_s2; de_o<=de_s2; x_o<=x_s2; y_o<=y_s2;
        if (!de_s2)
            rgb_o <= 24'h000000;
        else if (glyph_s2 && glyph_bits_s2[15-glyph_col_s2])
            rgb_o <= 24'hFFF1C7;
        else if (bar_s2)
            rgb_o <= 24'h101820;
        else
            rgb_o <= rgb_s2;
    end
end

endmodule

`default_nettype wire
