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
    input wire [1:0] mode, input wire panel_enable,
    input wire [1:0] auto_speed_level, input wire slideshow_paused,
    input wire [1:0] transition_theme, input wire [1:0] transition_context,
    input wire zoom_2x, input wire [1:0] picture_style,
    input wire [15:0] source_width_bcd, input wire [15:0] source_height_bcd,
    output wire [23:0] rgb_o
);

localparam [4:0] SP=0, I=1, M=2, G=3, A=4, U=5, T=6, O=7, N=8;
localparam [4:0] B=9, R=10, C=11, PCT=12, D0=13, D1=14, D2=15;
localparam [4:0] D3=16, D4=17, D5=18, D6=19, D7=20, D8=21, D9=22;
localparam [4:0] D=23, X=24, H=25, E=26, L=27, S=28, V=29, W=30, P=31;

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

function [4:0] mode_glyph;
    input [6:0] pos;
    input [1:0] ui_mode;
    begin
        mode_glyph=SP;
        case(ui_mode)
            2'b00: case(pos) // PRODUCT SHOW
                2:mode_glyph=P; 3:mode_glyph=R; 4:mode_glyph=O; 5:mode_glyph=D;
                6:mode_glyph=U; 7:mode_glyph=C; 8:mode_glyph=T; 10:mode_glyph=S;
                11:mode_glyph=H; 12:mode_glyph=O; 13:mode_glyph=W;
            endcase
            2'b01: case(pos) // SLIDESHOW
                2:mode_glyph=S; 3:mode_glyph=L; 4:mode_glyph=I; 5:mode_glyph=D;
                6:mode_glyph=E; 7:mode_glyph=S; 8:mode_glyph=H; 9:mode_glyph=O;
                10:mode_glyph=W;
            endcase
            2'b10: case(pos) // DETAIL VIEW
                2:mode_glyph=D; 3:mode_glyph=E; 4:mode_glyph=T; 5:mode_glyph=A;
                6:mode_glyph=I; 7:mode_glyph=L; 9:mode_glyph=V; 10:mode_glyph=I;
                11:mode_glyph=E; 12:mode_glyph=W;
            endcase
            default: case(pos) // AUDIO CONTROL
                2:mode_glyph=A; 3:mode_glyph=U; 4:mode_glyph=D; 5:mode_glyph=I;
                6:mode_glyph=O; 8:mode_glyph=C; 9:mode_glyph=O; 10:mode_glyph=N;
                11:mode_glyph=T; 12:mode_glyph=R; 13:mode_glyph=O; 14:mode_glyph=L;
            endcase
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
    input [1:0] ui_mode;
    input zoom;
    input [1:0] style;
    input [1:0] speed;
    input paused;
    input [1:0] theme;
    input [1:0] context;
    begin
        if (pos >= 2 && pos <= 14)
            cell_glyph=mode_glyph(pos, ui_mode);
        else begin
            cell_glyph=SP;
            case(pos)
                17:cell_glyph=I; 18:cell_glyph=M; 19:cell_glyph=G; 20:cell_glyph=digit(img);
                38:cell_glyph=A; 39:cell_glyph=U; 40:cell_glyph=D;
                41:cell_glyph=digit(audio_track);
                46:cell_glyph=D; 47:cell_glyph=I; 48:cell_glyph=M;
                50:cell_glyph=dim0; 51:cell_glyph=dim1; 52:cell_glyph=dim2;
                53:cell_glyph=dim3; 54:cell_glyph=dim4; 55:cell_glyph=dim5;
                56:cell_glyph=dim6; 57:cell_glyph=dim7; 58:cell_glyph=dim8;
                default:cell_glyph=SP;
            endcase
            case(ui_mode)
                2'b00: case(pos)
                    22:cell_glyph=T; 23:cell_glyph=H; 24:cell_glyph=M;
                    25:cell_glyph=digit(theme);
                    28:cell_glyph=C; 29:cell_glyph=T; 30:cell_glyph=X;
                    31:cell_glyph=digit(context);
                endcase
                2'b01: case(pos)
                    22:cell_glyph=S; 23:cell_glyph=P; 24:cell_glyph=D;
                    25:cell_glyph=digit((speed==2'd3)?4:speed);
                    26:cell_glyph=digit((speed==2'd0)?5:0); 27:cell_glyph=X;
                    30:cell_glyph=paused?P:R;
                    31:cell_glyph=paused?A:U;
                    32:cell_glyph=paused?U:N;
                endcase
                2'b10: case(pos)
                    22:cell_glyph=X; 23:cell_glyph=digit(zoom?2:1);
                    25:cell_glyph=S; 26:cell_glyph=digit(style);
                endcase
                default: case(pos)
                    22:cell_glyph=B; 23:cell_glyph=R;
                    25:cell_glyph=(br==2)?SP:D1;
                    26:cell_glyph=(br==0)?D0:D5; 27:cell_glyph=D0; 28:cell_glyph=PCT;
                    30:cell_glyph=C; 31:cell_glyph=T;
                    33:cell_glyph=(ct==2)?SP:D1;
                    34:cell_glyph=(ct==0)?D0:D5; 35:cell_glyph=D0; 36:cell_glyph=PCT;
                endcase
            endcase
        end
    end
endfunction

function [34:0] font_bitmap;
    input [4:0] glyph;
    begin
        case(glyph)
            I:   font_bitmap={5'b01110,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b01110};
            H:   font_bitmap={5'b10001,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
            M:   font_bitmap={5'b10001,5'b11011,5'b10101,5'b10101,5'b10001,5'b10001,5'b10001};
            G:   font_bitmap={5'b01110,5'b10001,5'b10000,5'b10111,5'b10001,5'b10001,5'b01110};
            A:   font_bitmap={5'b01110,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
            U:   font_bitmap={5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
            T:   font_bitmap={5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100};
            O:   font_bitmap={5'b01110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
            P:   font_bitmap={5'b11110,5'b10001,5'b10001,5'b11110,5'b10000,5'b10000,5'b10000};
            N:   font_bitmap={5'b10001,5'b11001,5'b10101,5'b10011,5'b10001,5'b10001,5'b10001};
            B:   font_bitmap={5'b11110,5'b10001,5'b10001,5'b11110,5'b10001,5'b10001,5'b11110};
            R:   font_bitmap={5'b11110,5'b10001,5'b10001,5'b11110,5'b10100,5'b10010,5'b10001};
            C:   font_bitmap={5'b01110,5'b10001,5'b10000,5'b10000,5'b10000,5'b10001,5'b01110};
            D:   font_bitmap={5'b11110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b11110};
            E:   font_bitmap={5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b11111};
            L:   font_bitmap={5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b11111};
            S:   font_bitmap={5'b01111,5'b10000,5'b10000,5'b01110,5'b00001,5'b00001,5'b11110};
            V:   font_bitmap={5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01010,5'b00100};
            W:   font_bitmap={5'b10001,5'b10001,5'b10001,5'b10101,5'b10101,5'b10101,5'b01010};
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
        panel_s1<=panel_enable&&(x_s0<11'd1280)&&(y_s0<10'd16);
        // x[9:3] deliberately remains a compact 7-bit glyph selector;
        // qualify x[10] so it cannot wrap and redraw the OSD at x=1024.
        glyph_active_s1<=!x_s0[10]&&(y_s0>=10'd4)&&(y_s0<10'd11)&&(x_s0[2:0]<3'd5)&&
                         (cell_glyph(x_s0[9:3],image_index,auto_mode,
                                      brightness_level,contrast_level,
                                      audio_track_index,mode,zoom_2x,picture_style,
                                      auto_speed_level,slideshow_paused,
                                      transition_theme,transition_context)!=SP);
        row_s1<=y_s0-10'd4;
        col_s1<=x_s0[2:0];
        glyph_s1<=cell_glyph(x_s0[9:3],image_index,auto_mode,
                              brightness_level,contrast_level,audio_track_index,mode,
                              zoom_2x,picture_style,auto_speed_level,slideshow_paused,
                              transition_theme,transition_context);
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
