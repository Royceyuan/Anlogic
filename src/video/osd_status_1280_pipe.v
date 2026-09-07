`timescale 1ns / 1ps
`default_nettype none

// Two-cycle 5x7 status OSD for the 75 MHz 1280x720 path.
// Dimension digits are pre-encoded outside the pixel decision path; stage 1
// selects one glyph and stage 2 performs the small font-ROM lookup.
module osd_status_1280_pipe (
    input wire clk, input wire rst_n, input wire de_i,
    input wire [10:0] x_i, input wire [9:0] y_i, input wire [23:0] rgb_i,
    input wire [3:0] image_index, input wire auto_mode,
    input wire [1:0] brightness_level, input wire [1:0] contrast_level,
    input wire [1:0] audio_track_index,
    input wire [15:0] source_width_bcd, input wire [15:0] source_height_bcd,
    output wire [23:0] rgb_o
);

localparam [4:0] SP=0, I=1, M=2, G=3, A=4, U=5, T=6, O=7, N=8;
localparam [4:0] B=9, R=10, C=11, PCT=12, D0=13, D1=14, D2=15;
localparam [4:0] D3=16, D4=17, D5=18, D6=19, D7=20, D8=21, D9=22;
localparam [4:0] D=23, X=24;

reg [4:0] dim0, dim1, dim2, dim3, dim4, dim5, dim6, dim7, dim8;
reg de_s0;
reg [10:0] x_s0;
reg [9:0] y_s0;
reg [23:0] rgb_s0;
reg de_s1, panel_s1, glyph_active_s1;
reg [2:0] row_s1, col_s1;
reg [4:0] glyph_s1;
reg [23:0] rgb_s1;
reg de_s2, panel_s2, text_s2;
reg [23:0] rgb_s2;
reg [4:0] font_bits;

function [4:0] digit;
    input [3:0] n;
    begin
        case(n)
            0:digit=D0; 1:digit=D1; 2:digit=D2; 3:digit=D3; 4:digit=D4;
            5:digit=D5; 6:digit=D6; 7:digit=D7; 8:digit=D8; default:digit=D9;
        endcase
    end
endfunction

function [4:0] cell_glyph;
    input [6:0] pos;
    input [3:0] img;
    input mode;
    input [1:0] br;
    input [1:0] ct;
    input [1:0] audio_track;
    begin
        cell_glyph=SP;
        case(pos)
            2:cell_glyph=I; 3:cell_glyph=M; 4:cell_glyph=G; 5:cell_glyph=digit(img);
            7:cell_glyph=mode?A:M; 8:cell_glyph=mode?U:A;
            9:cell_glyph=mode?T:N; 10:cell_glyph=mode?O:SP;
            12:cell_glyph=B; 13:cell_glyph=R;
            15:cell_glyph=(br==2)?SP:D1; 16:cell_glyph=(br==0)?D0:D5;
            17:cell_glyph=D0; 18:cell_glyph=PCT;
            20:cell_glyph=C; 21:cell_glyph=T;
            23:cell_glyph=(ct==2)?SP:D1; 24:cell_glyph=(ct==0)?D0:D5;
            25:cell_glyph=D0; 26:cell_glyph=PCT;
            28:cell_glyph=A; 29:cell_glyph=U; 30:cell_glyph=D;
            31:cell_glyph=digit(audio_track);
            36:cell_glyph=D; 37:cell_glyph=I; 38:cell_glyph=M;
            40:cell_glyph=dim0; 41:cell_glyph=dim1; 42:cell_glyph=dim2;
            43:cell_glyph=dim3; 44:cell_glyph=dim4; 45:cell_glyph=dim5;
            46:cell_glyph=dim6; 47:cell_glyph=dim7; 48:cell_glyph=dim8;
            default:cell_glyph=SP;
        endcase
    end
endfunction

function [34:0] font_bitmap;
    input [4:0] glyph;
    begin
        case(glyph)
            I:   font_bitmap={5'b01110,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b01110};
            M:   font_bitmap={5'b10001,5'b11011,5'b10101,5'b10101,5'b10001,5'b10001,5'b10001};
            G:   font_bitmap={5'b01110,5'b10001,5'b10000,5'b10111,5'b10001,5'b10001,5'b01110};
            A:   font_bitmap={5'b01110,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
            U:   font_bitmap={5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
            T:   font_bitmap={5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100};
            O:   font_bitmap={5'b01110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
            N:   font_bitmap={5'b10001,5'b11001,5'b10101,5'b10011,5'b10001,5'b10001,5'b10001};
            B:   font_bitmap={5'b11110,5'b10001,5'b10001,5'b11110,5'b10001,5'b10001,5'b11110};
            R:   font_bitmap={5'b11110,5'b10001,5'b10001,5'b11110,5'b10100,5'b10010,5'b10001};
            C:   font_bitmap={5'b01110,5'b10001,5'b10000,5'b10000,5'b10000,5'b10001,5'b01110};
            D:   font_bitmap={5'b11110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b11110};
            X:   font_bitmap={5'b10001,5'b01010,5'b00100,5'b00100,5'b00100,5'b01010,5'b10001};
            PCT: font_bitmap={5'b11001,5'b11010,5'b00100,5'b01000,5'b10110,5'b10011,5'b00000};
            D0:  font_bitmap={5'b01110,5'b10001,5'b10011,5'b10101,5'b11001,5'b10001,5'b01110};
            D1:  font_bitmap={5'b00100,5'b01100,5'b00100,5'b00100,5'b00100,5'b00100,5'b01110};
            D2:  font_bitmap={5'b01110,5'b10001,5'b00001,5'b00110,5'b01000,5'b10000,5'b11111};
            D3:  font_bitmap={5'b11110,5'b00001,5'b00001,5'b01110,5'b00001,5'b00001,5'b11110};
            D4:  font_bitmap={5'b00110,5'b01010,5'b10010,5'b11111,5'b00010,5'b00010,5'b00010};
            D5:  font_bitmap={5'b11111,5'b10000,5'b10000,5'b11110,5'b00001,5'b00001,5'b11110};
            D6:  font_bitmap={5'b01110,5'b10000,5'b10000,5'b11110,5'b10001,5'b10001,5'b01110};
            D7:  font_bitmap={5'b11111,5'b00001,5'b00010,5'b00100,5'b01000,5'b01000,5'b01000};
            D8:  font_bitmap={5'b01110,5'b10001,5'b10001,5'b01110,5'b10001,5'b10001,5'b01110};
            D9:  font_bitmap={5'b01110,5'b10001,5'b10001,5'b01111,5'b00001,5'b00001,5'b01110};
            default:font_bitmap=35'd0;
        endcase
    end
endfunction

wire [34:0] bitmap_s1 = font_bitmap(glyph_s1);

// Pack widthXheight once per pixel clock. The source dimensions change only
// when a complete BMP is published, so these registered glyphs are stable
// throughout normal scanning.
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dim0<=SP; dim1<=SP; dim2<=SP; dim3<=SP; dim4<=SP;
        dim5<=SP; dim6<=SP; dim7<=SP; dim8<=SP;
    end else begin
        dim0<=SP; dim1<=SP; dim2<=SP; dim3<=SP; dim4<=SP;
        dim5<=SP; dim6<=SP; dim7<=SP; dim8<=SP;
        if (source_width_bcd[15:12] != 0) begin
            dim0<=digit(source_width_bcd[15:12]); dim1<=digit(source_width_bcd[11:8]);
            dim2<=digit(source_width_bcd[7:4]); dim3<=digit(source_width_bcd[3:0]); dim4<=X;
            if (source_height_bcd[15:12] != 0) begin
                dim5<=digit(source_height_bcd[15:12]); dim6<=digit(source_height_bcd[11:8]);
                dim7<=digit(source_height_bcd[7:4]); dim8<=digit(source_height_bcd[3:0]);
            end else if (source_height_bcd[11:8] != 0) begin
                dim5<=digit(source_height_bcd[11:8]); dim6<=digit(source_height_bcd[7:4]); dim7<=digit(source_height_bcd[3:0]);
            end else if (source_height_bcd[7:4] != 0) begin
                dim5<=digit(source_height_bcd[7:4]); dim6<=digit(source_height_bcd[3:0]);
            end else dim5<=digit(source_height_bcd[3:0]);
        end else if (source_width_bcd[11:8] != 0) begin
            dim0<=digit(source_width_bcd[11:8]); dim1<=digit(source_width_bcd[7:4]);
            dim2<=digit(source_width_bcd[3:0]); dim3<=X;
            if (source_height_bcd[15:12] != 0) begin
                dim4<=digit(source_height_bcd[15:12]); dim5<=digit(source_height_bcd[11:8]);
                dim6<=digit(source_height_bcd[7:4]); dim7<=digit(source_height_bcd[3:0]);
            end else if (source_height_bcd[11:8] != 0) begin
                dim4<=digit(source_height_bcd[11:8]); dim5<=digit(source_height_bcd[7:4]); dim6<=digit(source_height_bcd[3:0]);
            end else if (source_height_bcd[7:4] != 0) begin
                dim4<=digit(source_height_bcd[7:4]); dim5<=digit(source_height_bcd[3:0]);
            end else dim4<=digit(source_height_bcd[3:0]);
        end else if (source_width_bcd[7:4] != 0) begin
            dim0<=digit(source_width_bcd[7:4]); dim1<=digit(source_width_bcd[3:0]); dim2<=X;
            if (source_height_bcd[15:12] != 0) begin
                dim3<=digit(source_height_bcd[15:12]); dim4<=digit(source_height_bcd[11:8]);
                dim5<=digit(source_height_bcd[7:4]); dim6<=digit(source_height_bcd[3:0]);
            end else if (source_height_bcd[11:8] != 0) begin
                dim3<=digit(source_height_bcd[11:8]); dim4<=digit(source_height_bcd[7:4]); dim5<=digit(source_height_bcd[3:0]);
            end else if (source_height_bcd[7:4] != 0) begin
                dim3<=digit(source_height_bcd[7:4]); dim4<=digit(source_height_bcd[3:0]);
            end else dim3<=digit(source_height_bcd[3:0]);
        end else begin
            dim0<=digit(source_width_bcd[3:0]); dim1<=X;
            if (source_height_bcd[15:12] != 0) begin
                dim2<=digit(source_height_bcd[15:12]); dim3<=digit(source_height_bcd[11:8]);
                dim4<=digit(source_height_bcd[7:4]); dim5<=digit(source_height_bcd[3:0]);
            end else if (source_height_bcd[11:8] != 0) begin
                dim2<=digit(source_height_bcd[11:8]); dim3<=digit(source_height_bcd[7:4]); dim4<=digit(source_height_bcd[3:0]);
            end else if (source_height_bcd[7:4] != 0) begin
                dim2<=digit(source_height_bcd[7:4]); dim3<=digit(source_height_bcd[3:0]);
            end else dim2<=digit(source_height_bcd[3:0]);
        end
    end
end

always @(*) begin
    case(row_s1)
        0:font_bits=bitmap_s1[34:30];
        1:font_bits=bitmap_s1[29:25];
        2:font_bits=bitmap_s1[24:20];
        3:font_bits=bitmap_s1[19:15];
        4:font_bits=bitmap_s1[14:10];
        5:font_bits=bitmap_s1[9:5];
        default:font_bits=bitmap_s1[4:0];
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        de_s0<=1'b0; x_s0<=0; y_s0<=0; rgb_s0<=0;
        de_s1<=1'b0; panel_s1<=1'b0; glyph_active_s1<=1'b0;
        row_s1<=3'd0; col_s1<=3'd0; glyph_s1<=SP; rgb_s1<=24'd0;
        de_s2<=1'b0; panel_s2<=1'b0; text_s2<=1'b0; rgb_s2<=24'd0;
    end else begin
        de_s0<=de_i;
        x_s0<=x_i;
        y_s0<=y_i;
        rgb_s0<=rgb_i;
        de_s1<=de_s0;
        panel_s1<=(x_s0<11'd1280)&&(y_s0<10'd16);
        // x[9:3] deliberately remains a compact 7-bit glyph selector;
        // qualify x[10] so it cannot wrap and redraw the OSD at x=1024.
        glyph_active_s1<=!x_s0[10]&&(y_s0>=10'd4)&&(y_s0<10'd11)&&(x_s0[2:0]<3'd5)&&
                         (cell_glyph(x_s0[9:3],image_index,auto_mode,
                                     brightness_level,contrast_level,
                                     audio_track_index)!=SP);
        row_s1<=y_s0-10'd4;
        col_s1<=x_s0[2:0];
        glyph_s1<=cell_glyph(x_s0[9:3],image_index,auto_mode,
                             brightness_level,contrast_level,audio_track_index);
        rgb_s1<=rgb_s0;

        de_s2<=de_s1;
        panel_s2<=panel_s1;
        text_s2<=glyph_active_s1&&(row_s1<3'd7)&&font_bits[4-col_s1];
        rgb_s2<=rgb_s1;
    end
end

assign rgb_o=!de_s2?24'h000000:
             (panel_s2?(text_s2?24'hffffff:24'h222222):rgb_s2);

endmodule

`default_nettype wire
