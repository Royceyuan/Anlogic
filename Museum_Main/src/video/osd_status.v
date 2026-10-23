`timescale 1ns / 1ps
`default_nettype none

// Fixed 5x7 status OSD. It consumes LUTs only and stays independent of the
// framebuffer implementation, so it can be retained after the SDRAM upgrade.
module osd_status (
    input  wire        de,
    input  wire [9:0]  x,
    input  wire [9:0]  y,
    input  wire [11:0] rgb_in,
    input  wire        enable,
    input  wire [3:0]  image_index,
    input  wire        auto_mode,
    input  wire [1:0]  brightness_level,
    input  wire [1:0]  contrast_level,
    input  wire [15:0] source_width_bcd,
    input  wire [15:0] source_height_bcd,
    output reg  [11:0] rgb_out
);

localparam [4:0] GLYPH_SPACE = 5'd0;
localparam [4:0] GLYPH_I     = 5'd1;
localparam [4:0] GLYPH_M     = 5'd2;
localparam [4:0] GLYPH_G     = 5'd3;
localparam [4:0] GLYPH_F     = 5'd4;
localparam [4:0] GLYPH_P     = 5'd5;
localparam [4:0] GLYPH_0     = 5'd6;
localparam [4:0] GLYPH_1     = 5'd7;
localparam [4:0] GLYPH_A     = 5'd8;
localparam [4:0] GLYPH_U     = 5'd9;
localparam [4:0] GLYPH_T     = 5'd10;
localparam [4:0] GLYPH_O     = 5'd11;
localparam [4:0] GLYPH_N     = 5'd12;
localparam [4:0] GLYPH_B     = 5'd13;
localparam [4:0] GLYPH_C     = 5'd14;
localparam [4:0] GLYPH_2     = 5'd15;
localparam [4:0] GLYPH_3     = 5'd16;
localparam [4:0] GLYPH_4     = 5'd17;
localparam [4:0] GLYPH_5     = 5'd18;
localparam [4:0] GLYPH_6     = 5'd19;
localparam [4:0] GLYPH_7     = 5'd20;
localparam [4:0] GLYPH_8     = 5'd21;
localparam [4:0] GLYPH_9     = 5'd22;
localparam [4:0] GLYPH_S     = 5'd23;
localparam [4:0] GLYPH_D     = 5'd24;
localparam [4:0] GLYPH_R     = 5'd25;
localparam [4:0] GLYPH_PERCENT= 5'd26;
localparam [4:0] GLYPH_X     = 5'd27;

function [4:0] glyph_digit;
    input [3:0] digit;
    begin
        case (digit)
            4'd0: glyph_digit = GLYPH_0;
            4'd1: glyph_digit = GLYPH_1;
            4'd2: glyph_digit = GLYPH_2;
            4'd3: glyph_digit = GLYPH_3;
            4'd4: glyph_digit = GLYPH_4;
            4'd5: glyph_digit = GLYPH_5;
            4'd6: glyph_digit = GLYPH_6;
            4'd7: glyph_digit = GLYPH_7;
            4'd8: glyph_digit = GLYPH_8;
            default: glyph_digit = GLYPH_9;
        endcase
    end
endfunction

function [4:0] glyph_row;
    input [4:0] glyph;
    input [2:0] row;
    begin
        glyph_row = 5'b00000;
        case (glyph)
            GLYPH_I: begin
                case (row)
                    3'd0: glyph_row = 5'b01110;
                    3'd1: glyph_row = 5'b00100;
                    3'd2: glyph_row = 5'b00100;
                    3'd3: glyph_row = 5'b00100;
                    3'd4: glyph_row = 5'b00100;
                    3'd5: glyph_row = 5'b00100;
                    default: glyph_row = 5'b01110;
                endcase
            end
            GLYPH_M: begin
                case (row)
                    3'd0: glyph_row = 5'b10001;
                    3'd1: glyph_row = 5'b11011;
                    3'd2: glyph_row = 5'b10101;
                    3'd3: glyph_row = 5'b10101;
                    3'd4: glyph_row = 5'b10001;
                    3'd5: glyph_row = 5'b10001;
                    default: glyph_row = 5'b10001;
                endcase
            end
            GLYPH_G: begin
                case (row)
                    3'd0: glyph_row = 5'b01110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10000;
                    3'd3: glyph_row = 5'b10111;
                    3'd4: glyph_row = 5'b10001;
                    3'd5: glyph_row = 5'b10001;
                    default: glyph_row = 5'b01110;
                endcase
            end
            GLYPH_F: begin
                case (row)
                    3'd0: glyph_row = 5'b11111;
                    3'd1: glyph_row = 5'b10000;
                    3'd2: glyph_row = 5'b10000;
                    3'd3: glyph_row = 5'b11110;
                    3'd4: glyph_row = 5'b10000;
                    3'd5: glyph_row = 5'b10000;
                    default: glyph_row = 5'b10000;
                endcase
            end
            GLYPH_P: begin
                case (row)
                    3'd0: glyph_row = 5'b11110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001;
                    3'd3: glyph_row = 5'b11110;
                    3'd4: glyph_row = 5'b10000;
                    3'd5: glyph_row = 5'b10000;
                    default: glyph_row = 5'b10000;
                endcase
            end
            GLYPH_0: begin
                case (row)
                    3'd0: glyph_row = 5'b01110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10011;
                    3'd3: glyph_row = 5'b10101;
                    3'd4: glyph_row = 5'b11001;
                    3'd5: glyph_row = 5'b10001;
                    default: glyph_row = 5'b01110;
                endcase
            end
            GLYPH_1: begin
                case (row)
                    3'd0: glyph_row = 5'b00100;
                    3'd1: glyph_row = 5'b01100;
                    3'd2: glyph_row = 5'b00100;
                    3'd3: glyph_row = 5'b00100;
                    3'd4: glyph_row = 5'b00100;
                    3'd5: glyph_row = 5'b00100;
                    default: glyph_row = 5'b01110;
                endcase
            end
            GLYPH_A: begin
                case (row)
                    3'd0: glyph_row = 5'b01110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001;
                    3'd3: glyph_row = 5'b11111;
                    3'd4: glyph_row = 5'b10001;
                    3'd5: glyph_row = 5'b10001;
                    default: glyph_row = 5'b10001;
                endcase
            end
            GLYPH_U: begin
                case (row)
                    3'd0: glyph_row = 5'b10001;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001;
                    3'd3: glyph_row = 5'b10001;
                    3'd4: glyph_row = 5'b10001;
                    3'd5: glyph_row = 5'b10001;
                    default: glyph_row = 5'b01110;
                endcase
            end
            GLYPH_T: begin
                case (row)
                    3'd0: glyph_row = 5'b11111;
                    3'd1: glyph_row = 5'b00100;
                    3'd2: glyph_row = 5'b00100;
                    3'd3: glyph_row = 5'b00100;
                    3'd4: glyph_row = 5'b00100;
                    3'd5: glyph_row = 5'b00100;
                    default: glyph_row = 5'b00100;
                endcase
            end
            GLYPH_O: begin
                case (row)
                    3'd0: glyph_row = 5'b01110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001;
                    3'd3: glyph_row = 5'b10001;
                    3'd4: glyph_row = 5'b10001;
                    3'd5: glyph_row = 5'b10001;
                    default: glyph_row = 5'b01110;
                endcase
            end
            GLYPH_N: begin
                case (row)
                    3'd0: glyph_row = 5'b10001;
                    3'd1: glyph_row = 5'b11001;
                    3'd2: glyph_row = 5'b10101;
                    3'd3: glyph_row = 5'b10011;
                    3'd4: glyph_row = 5'b10001;
                    3'd5: glyph_row = 5'b10001;
                    default: glyph_row = 5'b10001;
                endcase
            end
            GLYPH_B: begin
                case (row)
                    3'd0: glyph_row = 5'b11110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001;
                    3'd3: glyph_row = 5'b11110;
                    3'd4: glyph_row = 5'b10001;
                    3'd5: glyph_row = 5'b10001;
                    default: glyph_row = 5'b11110;
                endcase
            end
            GLYPH_C: begin
                case (row)
                    3'd0: glyph_row = 5'b01110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10000;
                    3'd3: glyph_row = 5'b10000;
                    3'd4: glyph_row = 5'b10000;
                    3'd5: glyph_row = 5'b10001;
                    default: glyph_row = 5'b01110;
                endcase
            end
            GLYPH_2: begin
                case (row)
                    3'd0: glyph_row = 5'b01110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b00001;
                    3'd3: glyph_row = 5'b00110;
                    3'd4: glyph_row = 5'b01000;
                    3'd5: glyph_row = 5'b10000;
                    default: glyph_row = 5'b11111;
                endcase
            end
            GLYPH_3: begin
                case (row)
                    3'd0: glyph_row = 5'b11110;
                    3'd1: glyph_row = 5'b00001;
                    3'd2: glyph_row = 5'b00001;
                    3'd3: glyph_row = 5'b01110;
                    3'd4: glyph_row = 5'b00001;
                    3'd5: glyph_row = 5'b00001;
                    default: glyph_row = 5'b11110;
                endcase
            end
            GLYPH_4: begin
                case (row)
                    3'd0: glyph_row = 5'b00110;
                    3'd1: glyph_row = 5'b01010;
                    3'd2: glyph_row = 5'b10010;
                    3'd3: glyph_row = 5'b11111;
                    3'd4: glyph_row = 5'b00010;
                    3'd5: glyph_row = 5'b00010;
                    default: glyph_row = 5'b00010;
                endcase
            end
            GLYPH_5: begin
                case (row)
                    3'd0: glyph_row = 5'b11111;
                    3'd1: glyph_row = 5'b10000;
                    3'd2: glyph_row = 5'b10000;
                    3'd3: glyph_row = 5'b11110;
                    3'd4: glyph_row = 5'b00001;
                    3'd5: glyph_row = 5'b00001;
                    default: glyph_row = 5'b11110;
                endcase
            end
            GLYPH_6: begin
                case (row)
                    3'd0: glyph_row = 5'b01110;
                    3'd1: glyph_row = 5'b10000;
                    3'd2: glyph_row = 5'b10000;
                    3'd3: glyph_row = 5'b11110;
                    3'd4: glyph_row = 5'b10001;
                    3'd5: glyph_row = 5'b10001;
                    default: glyph_row = 5'b01110;
                endcase
            end
            GLYPH_7: begin
                case (row)
                    3'd0: glyph_row = 5'b11111;
                    3'd1: glyph_row = 5'b00001;
                    3'd2: glyph_row = 5'b00010;
                    3'd3: glyph_row = 5'b00100;
                    3'd4: glyph_row = 5'b01000;
                    3'd5: glyph_row = 5'b01000;
                    default: glyph_row = 5'b01000;
                endcase
            end
            GLYPH_8: begin
                case (row)
                    3'd0: glyph_row = 5'b01110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001;
                    3'd3: glyph_row = 5'b01110;
                    3'd4: glyph_row = 5'b10001;
                    3'd5: glyph_row = 5'b10001;
                    default: glyph_row = 5'b01110;
                endcase
            end
            GLYPH_9: begin
                case (row)
                    3'd0: glyph_row = 5'b01110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001;
                    3'd3: glyph_row = 5'b01111;
                    3'd4: glyph_row = 5'b00001;
                    3'd5: glyph_row = 5'b00001;
                    default: glyph_row = 5'b01110;
                endcase
            end
            GLYPH_S: begin
                case (row)
                    3'd0: glyph_row = 5'b01111;
                    3'd1: glyph_row = 5'b10000;
                    3'd2: glyph_row = 5'b10000;
                    3'd3: glyph_row = 5'b01110;
                    3'd4: glyph_row = 5'b00001;
                    3'd5: glyph_row = 5'b00001;
                    default: glyph_row = 5'b11110;
                endcase
            end
            GLYPH_D: begin
                case (row)
                    3'd0: glyph_row = 5'b11110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001;
                    3'd3: glyph_row = 5'b10001;
                    3'd4: glyph_row = 5'b10001;
                    3'd5: glyph_row = 5'b10001;
                    default: glyph_row = 5'b11110;
                endcase
            end
            GLYPH_R: begin
                case (row)
                    3'd0: glyph_row = 5'b11110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001;
                    3'd3: glyph_row = 5'b11110;
                    3'd4: glyph_row = 5'b10100;
                    3'd5: glyph_row = 5'b10010;
                    default: glyph_row = 5'b10001;
                endcase
            end
            GLYPH_PERCENT: begin
                case (row)
                    3'd0: glyph_row = 5'b11001;
                    3'd1: glyph_row = 5'b11010;
                    3'd2: glyph_row = 5'b00100;
                    3'd3: glyph_row = 5'b01000;
                    3'd4: glyph_row = 5'b10110;
                    3'd5: glyph_row = 5'b10011;
                    default: glyph_row = 5'b00000;
                endcase
            end
            GLYPH_X: begin
                case (row)
                    3'd0: glyph_row = 5'b10001;
                    3'd1: glyph_row = 5'b01010;
                    3'd2: glyph_row = 5'b00100;
                    3'd3: glyph_row = 5'b00100;
                    3'd4: glyph_row = 5'b00100;
                    3'd5: glyph_row = 5'b01010;
                    default: glyph_row = 5'b10001;
                endcase
            end
            default: glyph_row = 5'b00000;
        endcase
    end
endfunction

reg        glyph_active;
reg [4:0]  glyph;
reg [9:0]  glyph_start_x;
reg [2:0]  glyph_x;
reg [2:0]  glyph_y;
reg [4:0]  glyph_bits;
reg        text_pixel;
wire       in_panel;
wire       width_has_thousands = (source_width_bcd[15:12] != 0);
wire       width_has_hundreds  = (source_width_bcd[11:8] != 0);
wire       width_has_tens      = (source_width_bcd[7:4] != 0);
wire       height_has_thousands= (source_height_bcd[15:12] != 0);
wire       height_has_hundreds = (source_height_bcd[11:8] != 0);
wire       height_has_tens     = (source_height_bcd[7:4] != 0);
wire [2:0] width_digit_count = width_has_thousands ? 3'd4 :
                               width_has_hundreds ? 3'd3 :
                               width_has_tens ? 3'd2 : 3'd1;
wire [2:0] height_digit_count = height_has_thousands ? 3'd4 :
                                height_has_hundreds ? 3'd3 :
                                height_has_tens ? 3'd2 : 3'd1;
localparam [6:0] DIM_BASE       = 7'd36;
localparam [6:0] DIM_WIDTH_BASE = 7'd40;
wire [6:0] dim_x_pos = DIM_WIDTH_BASE + width_digit_count;
wire [6:0] dim_height_base = dim_x_pos + 7'd1;

// A power-of-two character grid avoids a long priority chain in the 75 MHz
// 1280x720 path. The status bar intentionally reserves the top display row.
assign in_panel = (y[9:5] == 5'd0);

always @(*) begin
    glyph_active  = 1'b0;
    glyph         = GLYPH_SPACE;
    glyph_start_x = {x[9:3], 3'b000};

    // IMGx MAN/AUTO BR xxx% CT xxx%, one character per eight-pixel cell.
    if (y[9:3] == 7'd1) begin
        // x[7:3] repeated the 32-character status text every 256 pixels.
        // The 800-pixel mode needs the full horizontal cell index.
        if (x[9:3] >= DIM_BASE) begin
            // Keep DIM to the right of the control fields, then pack the
            // decimal digits without leading-zero gaps: DIM 717X527.
            case (x[9:3])
                7'd36: begin glyph_active = 1'b1; glyph = GLYPH_D; end
                7'd37: begin glyph_active = 1'b1; glyph = GLYPH_I; end
                7'd38: begin glyph_active = 1'b1; glyph = GLYPH_M; end
                default: begin
                    if ((x[9:3] >= DIM_WIDTH_BASE) && (x[9:3] < dim_x_pos)) begin
                        glyph_active = 1'b1;
                        case (width_digit_count)
                            3'd4: case (x[9:3] - DIM_WIDTH_BASE)
                                7'd0: glyph = glyph_digit(source_width_bcd[15:12]);
                                7'd1: glyph = glyph_digit(source_width_bcd[11:8]);
                                7'd2: glyph = glyph_digit(source_width_bcd[7:4]);
                                default: glyph = glyph_digit(source_width_bcd[3:0]);
                            endcase
                            3'd3: case (x[9:3] - DIM_WIDTH_BASE)
                                7'd0: glyph = glyph_digit(source_width_bcd[11:8]);
                                7'd1: glyph = glyph_digit(source_width_bcd[7:4]);
                                default: glyph = glyph_digit(source_width_bcd[3:0]);
                            endcase
                            3'd2: begin
                                if ((x[9:3] - DIM_WIDTH_BASE) == 0)
                                    glyph = glyph_digit(source_width_bcd[7:4]);
                                else
                                    glyph = glyph_digit(source_width_bcd[3:0]);
                            end
                            default: glyph = glyph_digit(source_width_bcd[3:0]);
                        endcase
                    end else if (x[9:3] == dim_x_pos) begin
                        glyph_active = 1'b1;
                        glyph = GLYPH_X;
                    end else if ((x[9:3] > dim_x_pos) &&
                                 (x[9:3] < dim_height_base + height_digit_count)) begin
                        glyph_active = 1'b1;
                        case (height_digit_count)
                            3'd4: case (x[9:3] - dim_height_base)
                                7'd0: glyph = glyph_digit(source_height_bcd[15:12]);
                                7'd1: glyph = glyph_digit(source_height_bcd[11:8]);
                                7'd2: glyph = glyph_digit(source_height_bcd[7:4]);
                                default: glyph = glyph_digit(source_height_bcd[3:0]);
                            endcase
                            3'd3: case (x[9:3] - dim_height_base)
                                7'd0: glyph = glyph_digit(source_height_bcd[11:8]);
                                7'd1: glyph = glyph_digit(source_height_bcd[7:4]);
                                default: glyph = glyph_digit(source_height_bcd[3:0]);
                            endcase
                            3'd2: begin
                                if ((x[9:3] - dim_height_base) == 0)
                                    glyph = glyph_digit(source_height_bcd[7:4]);
                                else
                                    glyph = glyph_digit(source_height_bcd[3:0]);
                            end
                            default: glyph = glyph_digit(source_height_bcd[3:0]);
                        endcase
                    end
                end
            endcase
        end else begin
        case (x[9:3])
            5'd2:  begin glyph_active = 1'b1; glyph = GLYPH_I; end
            5'd3:  begin glyph_active = 1'b1; glyph = GLYPH_M; end
            5'd4:  begin glyph_active = 1'b1; glyph = GLYPH_G; end
            5'd5:  begin glyph_active = 1'b1; case (image_index)
                        4'd0: glyph = GLYPH_0; 4'd1: glyph = GLYPH_1;
                        4'd2: glyph = GLYPH_2; 4'd3: glyph = GLYPH_3;
                        4'd4: glyph = GLYPH_4; 4'd5: glyph = GLYPH_5;
                        4'd6: glyph = GLYPH_6; 4'd7: glyph = GLYPH_7;
                        4'd8: glyph = GLYPH_8; 4'd9: glyph = GLYPH_9;
                        default: glyph = GLYPH_0;
                    endcase end
            5'd7:  begin glyph_active = 1'b1; glyph = auto_mode ? GLYPH_A : GLYPH_M; end
            5'd8:  begin glyph_active = 1'b1; glyph = auto_mode ? GLYPH_U : GLYPH_A; end
            5'd9:  begin glyph_active = 1'b1; glyph = auto_mode ? GLYPH_T : GLYPH_N; end
            5'd10: begin glyph_active = auto_mode; glyph = auto_mode ? GLYPH_O : GLYPH_SPACE; end
            5'd12: begin glyph_active = 1'b1; glyph = GLYPH_B; end
            5'd13: begin glyph_active = 1'b1; glyph = GLYPH_R; end
            5'd15: begin glyph_active = brightness_level != 2'd2; glyph = GLYPH_1; end
            5'd16: begin glyph_active = 1'b1; glyph = (brightness_level == 2'd0) ? GLYPH_0 : GLYPH_5; end
            5'd17: begin glyph_active = 1'b1; glyph = GLYPH_0; end
            5'd18: begin glyph_active = 1'b1; glyph = GLYPH_PERCENT; end
            5'd20: begin glyph_active = 1'b1; glyph = GLYPH_C; end
            5'd21: begin glyph_active = 1'b1; glyph = GLYPH_T; end
            5'd23: begin glyph_active = contrast_level != 2'd2; glyph = GLYPH_1; end
            5'd24: begin glyph_active = 1'b1; glyph = (contrast_level == 2'd0) ? GLYPH_0 : GLYPH_5; end
            5'd25: begin glyph_active = 1'b1; glyph = GLYPH_0; end
            5'd26: begin glyph_active = 1'b1; glyph = GLYPH_PERCENT; end
            default: begin end
        endcase
        end
    end

    glyph_x = x[2:0];
    glyph_y = (y[9:3] == 7'd1) ? y[2:0] : 3'd7;
    glyph_bits = glyph_row(glyph, glyph_y);
    text_pixel = 1'b0;
    if (glyph_active && (y[9:3] == 7'd1) &&
        (glyph_x < 3'd5) && (glyph_y < 3'd7))
        text_pixel = glyph_bits[4 - glyph_x];

    if (!de)
        rgb_out = 12'h000;
    else if (enable && in_panel)
        rgb_out = text_pixel ? 12'hFFF : 12'h222;
    else
        rgb_out = rgb_in;
end

endmodule

`default_nettype wire
