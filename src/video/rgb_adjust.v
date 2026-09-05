`timescale 1ns / 1ps
`default_nettype none

// Pixel-domain colour adjustment with four-bit RGB channels. The contrast
// curve is intentionally piecewise-linear so the video path uses no DSPs.
module rgb_adjust (
    input  wire        de,
    input  wire [11:0] rgb_in,
    input  wire        brightness_enable,
    input  wire        contrast_enable,
    output reg  [11:0] rgb_out
);

function [3:0] contrast_channel;
    input [3:0] value;
    begin
        // 1.5x contrast around code 8, clipped to the four-bit range.
        case (value)
            4'h0: contrast_channel = 4'h0;
            4'h1: contrast_channel = 4'h0;
            4'h2: contrast_channel = 4'h0;
            4'h3: contrast_channel = 4'h0;
            4'h4: contrast_channel = 4'h2;
            4'h5: contrast_channel = 4'h3;
            4'h6: contrast_channel = 4'h5;
            4'h7: contrast_channel = 4'h6;
            4'h8: contrast_channel = 4'h8;
            4'h9: contrast_channel = 4'h9;
            4'hA: contrast_channel = 4'hB;
            4'hB: contrast_channel = 4'hC;
            4'hC: contrast_channel = 4'hE;
            default: contrast_channel = 4'hF;
        endcase
    end
endfunction

function [3:0] brighten_channel;
    input [3:0] value;
    begin
        // Add one quarter-scale while retaining full white saturation.
        if (value >= 4'hB)
            brighten_channel = 4'hF;
        else
            brighten_channel = value + 4'h4;
    end
endfunction

reg [3:0] red;
reg [3:0] green;
reg [3:0] blue;

always @(*) begin
    if (contrast_enable) begin
        red   = contrast_channel(rgb_in[11:8]);
        green = contrast_channel(rgb_in[7:4]);
        blue  = contrast_channel(rgb_in[3:0]);
    end else begin
        red   = rgb_in[11:8];
        green = rgb_in[7:4];
        blue  = rgb_in[3:0];
    end

    if (brightness_enable) begin
        red   = brighten_channel(red);
        green = brighten_channel(green);
        blue  = brighten_channel(blue);
    end

    if (de)
        rgb_out = {red, green, blue};
    else
        rgb_out = 12'h000;
end

endmodule

`default_nettype wire
