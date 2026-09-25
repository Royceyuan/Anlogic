`timescale 1ns / 1ps
`default_nettype none

// MAIN-5 image-only adjustment: contrast -> brightness -> saturation ->
// temperature -> final clamp. OSD/subtitles/waveform are added later.
module rgb888_adjust_main5 (
    input  wire        de,
    input  wire [23:0] rgb_in,
    input  wire [2:0]  brightness_index,
    input  wire [2:0]  contrast_index,
    input  wire [2:0]  saturation_index,
    input  wire [2:0]  temperature_index,
    output wire [23:0] rgb_out
);

function signed [11:0] contrast;
    input [7:0] value;
    input [2:0] level;
    reg signed [11:0] d;
    reg signed [15:0] product;
    reg [2:0] factor;
    begin
        d = $signed({4'd0, value}) - 12'sd128;
        case (level)
            3'd0: factor = 3'd2;
            3'd1: factor = 3'd3;
            3'd3: factor = 3'd5;
            3'd4: factor = 3'd6;
            default: factor = 3'd4;
        endcase
        product = d * $signed({1'b0, factor});
        contrast = 12'sd128 + (product >>> 2) +
                   ((level == 3'd1) && (d[1:0] != 2'd0));
    end
endfunction

function signed [11:0] saturate;
    input signed [11:0] channel;
    input signed [11:0] luma;
    input [2:0] level;
    reg signed [11:0] d;
    reg signed [15:0] product;
    reg [2:0] factor;
    begin
        d = channel - luma;
        case (level)
            3'd0: factor = 3'd0;
            3'd1: factor = 3'd2;
            3'd2: factor = 3'd3;
            3'd4: factor = 3'd5;
            3'd5: factor = 3'd6;
            default: factor = 3'd4;
        endcase
        product = d * $signed({1'b0, factor});
        saturate = luma + (product >>> 2) +
                   ((level == 3'd2) && (d[1:0] != 2'd0));
    end
endfunction

function [7:0] clip;
    input signed [11:0] value;
    begin
        if (value < 12'sd0) clip = 8'd0;
        else if (value > 12'sd255) clip = 8'd255;
        else clip = value[7:0];
    end
endfunction

reg signed [11:0] brightness_offset, temperature_offset;
always @* begin
    case (brightness_index)
        3'd0: brightness_offset = -12'sd48;
        3'd1: brightness_offset = -12'sd32;
        3'd2: brightness_offset = -12'sd16;
        3'd4: brightness_offset = 12'sd16;
        3'd5: brightness_offset = 12'sd32;
        3'd6: brightness_offset = 12'sd48;
        default: brightness_offset = 12'sd0;
    endcase
    case (temperature_index)
        3'd0: temperature_offset = -12'sd24;
        3'd1: temperature_offset = -12'sd16;
        3'd2: temperature_offset = -12'sd8;
        3'd4: temperature_offset = 12'sd8;
        3'd5: temperature_offset = 12'sd16;
        3'd6: temperature_offset = 12'sd24;
        default: temperature_offset = 12'sd0;
    endcase
end

wire signed [11:0] cr = contrast(rgb_in[23:16], contrast_index) + brightness_offset;
wire signed [11:0] cg = contrast(rgb_in[15:8], contrast_index) + brightness_offset;
wire signed [11:0] cb = contrast(rgb_in[7:0], contrast_index) + brightness_offset;
wire signed [11:0] y = (cr >>> 2) + (cg >>> 1) + (cb >>> 2);
wire signed [11:0] sr = saturate(cr, y, saturation_index) + temperature_offset;
wire signed [11:0] sg = saturate(cg, y, saturation_index);
wire signed [11:0] sb = saturate(cb, y, saturation_index) - temperature_offset;
assign rgb_out = de ? {clip(sr), clip(sg), clip(sb)} : 24'd0;

endmodule
`default_nettype wire
