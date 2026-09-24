`timescale 1ns / 1ps
`default_nettype none

// Pixel-domain demo graphics. The emergency page is ROM-free and remains
// available when TF media or the network is absent.
module secondary_page_overlay (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        de,
    input  wire [10:0] x,
    input  wire [9:0]  y,
    input  wire [10:0] pre_x,
    input  wire [9:0]  pre_y,
    input  wire [23:0] base_rgb,
    input  wire        emergency_50m,
    input  wire        emergency_bitmap_video,
    input  wire [1:0]  link_state_50m,
    input  wire [2:0]  master_artifact_50m,
    input  wire [7:0]  route_id_50m,
    input  wire        media_ready_50m,
    input  wire        media_error_50m,
    output reg  [23:0] rgb
);

reg emergency_ff1, emergency_ff2, emergency_frame;
reg emergency_bitmap_frame;
reg [1:0] link_ff1, link_ff2, link_frame;
reg [2:0] artifact_ff1, artifact_ff2, artifact_frame;
reg ready_ff1, ready_ff2, ready_frame;
reg error_ff1, error_ff2, error_frame;
reg emergency_title_pixel;
reg media_pixel, main_pixel, link_pixel, artifact_pixel;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        emergency_ff1 <= 1'b0; emergency_ff2 <= 1'b0; emergency_frame <= 1'b0;
        emergency_bitmap_frame <= 1'b0;
        link_ff1 <= 2'd0; link_ff2 <= 2'd0; link_frame <= 2'd0;
        artifact_ff1 <= 3'd7; artifact_ff2 <= 3'd7; artifact_frame <= 3'd7;
        ready_ff1 <= 1'b0; ready_ff2 <= 1'b0; ready_frame <= 1'b0;
        error_ff1 <= 1'b0; error_ff2 <= 1'b0; error_frame <= 1'b0;
        emergency_title_pixel <= 1'b0;
        media_pixel <= 1'b0; main_pixel <= 1'b0;
        link_pixel <= 1'b0; artifact_pixel <= 1'b0;
    end else begin
        emergency_ff1 <= emergency_50m; emergency_ff2 <= emergency_ff1;
        link_ff1 <= link_state_50m; link_ff2 <= link_ff1;
        artifact_ff1 <= master_artifact_50m; artifact_ff2 <= artifact_ff1;
        ready_ff1 <= media_ready_50m; ready_ff2 <= ready_ff1;
        error_ff1 <= media_error_50m; error_ff2 <= error_ff1;
        emergency_title_pixel <= word_pixel(pre_x,pre_y,11'd450,10'd48,4'd0);
        media_pixel <= word_pixel(pre_x,pre_y,11'd410,10'd312,
                                  error_frame ? 4'd9 : 4'd8);
        main_pixel <= word_pixel(pre_x,pre_y,11'd36,10'd680,4'd6);
        link_pixel <= word_pixel(pre_x,pre_y,11'd840,10'd680,link_word);
        artifact_pixel <= digit_pixel(pre_x,pre_y,artifact_frame);
        if (x == 11'd0 && y == 10'd0) begin
            emergency_frame <= emergency_ff2 || emergency_bitmap_video;
            emergency_bitmap_frame <= emergency_bitmap_video;
            link_frame <= link_ff2;
            artifact_frame <= artifact_ff2;
            ready_frame <= ready_ff2;
            error_frame <= error_ff2;
        end
    end
end

function [34:0] glyph;
    input [7:0] c;
    begin
        case (c)
            "A": glyph = {5'b01110,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
            "C": glyph = {5'b01111,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b01111};
            "D": glyph = {5'b11110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b11110};
            "E": glyph = {5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b11111};
            "G": glyph = {5'b01111,5'b10000,5'b10000,5'b10111,5'b10001,5'b10001,5'b01111};
            "I": glyph = {5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b11111};
            "K": glyph = {5'b10001,5'b10010,5'b10100,5'b11000,5'b10100,5'b10010,5'b10001};
            "L": glyph = {5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b11111};
            "M": glyph = {5'b10001,5'b11011,5'b10101,5'b10101,5'b10001,5'b10001,5'b10001};
            "N": glyph = {5'b10001,5'b11001,5'b10101,5'b10011,5'b10001,5'b10001,5'b10001};
            "O": glyph = {5'b01110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
            "R": glyph = {5'b11110,5'b10001,5'b10001,5'b11110,5'b10100,5'b10010,5'b10001};
            "S": glyph = {5'b01111,5'b10000,5'b10000,5'b01110,5'b00001,5'b00001,5'b11110};
            "T": glyph = {5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100};
            "U": glyph = {5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
            "W": glyph = {5'b10001,5'b10001,5'b10001,5'b10101,5'b10101,5'b10101,5'b01010};
            "X": glyph = {5'b10001,5'b10001,5'b01010,5'b00100,5'b01010,5'b10001,5'b10001};
            "Y": glyph = {5'b10001,5'b10001,5'b01010,5'b00100,5'b00100,5'b00100,5'b00100};
            "0": glyph = {5'b01110,5'b10001,5'b10011,5'b10101,5'b11001,5'b10001,5'b01110};
            "1": glyph = {5'b00100,5'b01100,5'b00100,5'b00100,5'b00100,5'b00100,5'b01110};
            "2": glyph = {5'b01110,5'b10001,5'b00001,5'b00010,5'b00100,5'b01000,5'b11111};
            "3": glyph = {5'b11110,5'b00001,5'b00001,5'b01110,5'b00001,5'b00001,5'b11110};
            "4": glyph = {5'b00010,5'b00110,5'b01010,5'b10010,5'b11111,5'b00010,5'b00010};
            default: glyph = 35'd0;
        endcase
    end
endfunction

function [7:0] word_char;
    input [3:0] word_id;
    input [3:0] index;
    begin
        word_char = " ";
        case (word_id)
            4'd0: case (index)
                0:word_char="E"; 1:word_char="M"; 2:word_char="E";
                3:word_char="R"; 4:word_char="G"; 5:word_char="E";
                6:word_char="N"; 7:word_char="C"; 8:word_char="Y";
            endcase
            4'd1: case (index)
                0:word_char="E"; 1:word_char="X"; 2:word_char="I"; 3:word_char="T";
            endcase
            4'd2: case (index)
                0:word_char="L"; 1:word_char="I"; 2:word_char="N"; 3:word_char="K";
                5:word_char="W"; 6:word_char="A"; 7:word_char="I"; 8:word_char="T";
            endcase
            4'd3: case (index)
                0:word_char="L"; 1:word_char="I"; 2:word_char="N"; 3:word_char="K";
                5:word_char="O"; 6:word_char="K";
            endcase
            4'd4: case (index)
                0:word_char="L"; 1:word_char="I"; 2:word_char="N"; 3:word_char="K";
                5:word_char="L"; 6:word_char="O"; 7:word_char="S"; 8:word_char="T";
            endcase
            4'd5: case (index)
                0:word_char="D"; 1:word_char="E"; 2:word_char="M"; 3:word_char="O";
                5:word_char="R"; 6:word_char="O"; 7:word_char="U";
                8:word_char="T"; 9:word_char="E";
            endcase
            4'd6: case (index)
                0:word_char="M"; 1:word_char="A"; 2:word_char="I"; 3:word_char="N";
            endcase
            4'd7: case (index)
                0:word_char="C"; 1:word_char="U"; 2:word_char="R";
                3:word_char="R"; 4:word_char="E"; 5:word_char="N"; 6:word_char="T";
            endcase
            4'd8: case (index)
                0:word_char="M"; 1:word_char="E"; 2:word_char="D";
                3:word_char="I"; 4:word_char="A"; 6:word_char="W";
                7:word_char="A"; 8:word_char="I"; 9:word_char="T";
            endcase
            4'd9: case (index)
                0:word_char="M"; 1:word_char="E"; 2:word_char="D";
                3:word_char="I"; 4:word_char="A"; 6:word_char="E";
                7:word_char="R"; 8:word_char="R"; 9:word_char="O"; 10:word_char="R";
            endcase
        endcase
    end
endfunction

function word_pixel;
    input [10:0] px;
    input [9:0] py;
    input [10:0] x0;
    input [9:0] y0;
    input [3:0] word_id;
    reg [10:0] dx;
    reg [9:0] dy;
    reg [3:0] index;
    reg [2:0] col, row;
    reg [34:0] bits;
    begin
        word_pixel = 1'b0;
        if (px >= x0 && py >= y0 && py < y0 + 10'd28) begin
            dx = px - x0;
            dy = py - y0;
            index = dx[8:5];
            col = dx[4:2];
            row = dy[4:2];
            bits = glyph(word_char(word_id, index));
            if (dx < 11'd384 && col < 3'd5 && row < 3'd7)
                word_pixel = bits[34 - row * 5 - col];
        end
    end
endfunction

function digit_pixel;
    input [10:0] px;
    input [9:0] py;
    input [2:0] digit;
    reg [34:0] bits;
    reg [2:0] col, row;
    begin
        digit_pixel = 1'b0;
        if (px >= 11'd185 && px < 11'd205 && py >= 10'd680 && py < 10'd708 &&
            digit <= 3'd4) begin
            col = (px - 11'd185) >> 2;
            row = (py - 10'd680) >> 2;
            bits = glyph(8'h30 + {5'd0,digit});
            digit_pixel = bits[34 - row * 5 - col];
        end
    end
endfunction

wire [3:0] link_word = (link_frame == 2'd1) ? 4'd3 :
                       (link_frame == 2'd2) ? 4'd4 : 4'd2;
always @(*) begin
    rgb = 24'h000000;
    if (de) begin
        if (emergency_frame) begin
            if (emergency_bitmap_frame) begin
                rgb = base_rgb;
            end else begin
                rgb = 24'h142033;
                if (y < 10'd128) rgb = 24'hA30F20;
                if (emergency_title_pixel || media_pixel) rgb = 24'hFFFFFF;
            end
        end else if (!ready_frame || error_frame) begin
            rgb = 24'h142033;
            if (y < 10'd110) rgb = 24'h765529;
            if (media_pixel) rgb = 24'hFFFFFF;
        end else begin
            rgb = base_rgb;
        end

        if (y >= 10'd665 && !emergency_frame &&
            (!ready_frame || error_frame)) begin
            rgb = 24'h0A1322;
            if (y < 10'd670) rgb = (link_frame == 2'd1) ? 24'h16835B :
                                   (link_frame == 2'd2) ? 24'hB62931 : 24'hD7A53B;
            if (main_pixel || link_pixel || artifact_pixel) rgb = 24'hFFFFFF;
        end
    end
end

endmodule

`default_nettype wire
