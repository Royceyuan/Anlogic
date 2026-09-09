`timescale 1ns / 1ps
`default_nettype none

// Full RGB888 post-processing. The arithmetic is shifts and additions only,
// so enabling image adjustment does not consume a DSP block.
module rgb888_adjust (
    input  wire        de,
    input  wire [23:0] rgb_in,
    input  wire [1:0]  brightness_level,
    input  wire [1:0]  contrast_level,
    input  wire [1:0]  picture_style,
    output reg  [23:0] rgb_out
);

function [7:0] contrast_channel;
    input [7:0] value;
    input [1:0] level;
    reg [9:0] scaled;
    begin
        // Level 0 is neutral, level 1 is 150%, and level 2 is 50%.
        case (level)
            2'd2: begin
                scaled = {2'b00, value} + 10'd128;
                contrast_channel = scaled >> 1;
            end
            2'd1: begin
                scaled = ({2'b00, value} << 1) + {2'b00, value};
                if (value < 8'd86)
                    contrast_channel = 8'd0;
                else if (value > 8'd170)
                    contrast_channel = 8'd255;
                else
                    contrast_channel = (scaled >> 1) - 8'd64;
            end
            default: contrast_channel = value;
        endcase
    end
endfunction

function [7:0] brighten_channel;
    input [7:0] value;
    begin
        brighten_channel = ({1'b0, value} + ({1'b0, value} >> 1) > 9'd255) ?
                            8'd255 : ({1'b0, value} + ({1'b0, value} >> 1));
    end
endfunction

function [7:0] high_contrast_channel;
    input [7:0] value;
    begin
        if (value < 8'd64)
            high_contrast_channel = 8'd0;
        else if (value > 8'd191)
            high_contrast_channel = 8'd255;
        else
            high_contrast_channel = (value << 1) - 8'd128;
    end
endfunction

reg [7:0] red;
reg [7:0] green;
reg [7:0] blue;

always @(*) begin
    red   = contrast_channel(rgb_in[23:16], contrast_level);
    green = contrast_channel(rgb_in[15:8], contrast_level);
    blue  = contrast_channel(rgb_in[7:0], contrast_level);

    case (brightness_level)
        2'd2: begin
            red   = red >> 1;
            green = green >> 1;
            blue  = blue >> 1;
        end
        2'd1: begin
            red   = brighten_channel(red);
            green = brighten_channel(green);
            blue  = brighten_channel(blue);
        end
        default: begin end
    endcase

    case (picture_style)
        2'd1: begin
            red   = brighten_channel(contrast_channel(red, 2'd1));
            green = brighten_channel(contrast_channel(green, 2'd1));
            blue  = brighten_channel(contrast_channel(blue, 2'd1));
        end
        2'd2: begin
            red   = contrast_channel(red, 2'd2);
            green = contrast_channel(green, 2'd2);
            blue  = contrast_channel(blue, 2'd2);
        end
        2'd3: begin
            red   = high_contrast_channel(red);
            green = high_contrast_channel(green);
            blue  = high_contrast_channel(blue);
        end
        default: begin end
    endcase

    rgb_out = de ? {red, green, blue} : 24'h000000;
end

endmodule

`default_nettype wire
