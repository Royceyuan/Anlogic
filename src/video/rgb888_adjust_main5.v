`timescale 1ns / 1ps
`default_nettype none

// MAIN-5 image-only adjustment: contrast -> brightness -> saturation ->
// temperature -> final clamp. OSD/subtitles/waveform are added later.
module rgb888_adjust_main5 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        de,
    input  wire [23:0] rgb_in,
    input  wire [2:0]  brightness_index,
    input  wire [2:0]  contrast_index,
    input  wire [2:0]  saturation_index,
    input  wire [2:0]  temperature_index,
    output reg  [23:0] rgb_out
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

function signed [11:0] saturate_delta;
    input signed [11:0] d;
    input signed [11:0] luma;
    input [2:0] factor;
    input round_up;
    reg signed [15:0] product;
    begin
        product = d * $signed({1'b0, factor});
        saturate_delta = luma + (product >>> 2) +
                         (round_up && (d[1:0] != 2'd0));
    end
endfunction

function [7:0] clip;
    input signed [11:0] value;
    begin
        // Signed 12-bit to unsigned 8-bit saturation needs no carry chain.
        if (value[11]) clip = 8'd0;
        else if (|value[10:8]) clip = 8'd255;
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

wire signed [11:0] cr_next = contrast(rgb_in[23:16], contrast_index) + brightness_offset;
wire signed [11:0] cg_next = contrast(rgb_in[15:8], contrast_index) + brightness_offset;
wire signed [11:0] cb_next = contrast(rgb_in[7:0], contrast_index) + brightness_offset;
reg signed [11:0] cr, cg, cb, temperature_offset_q;
reg [2:0] saturation_index_q;
reg de_q;
wire signed [11:0] y_next = (cr >>> 2) + (cg >>> 1) + (cb >>> 2);
reg signed [11:0] y_q, dr_q, dg_q, db_q, temperature_offset_q2;
reg [2:0] saturation_factor_q2;
reg saturation_round_q2;
reg de_q2;
wire signed [11:0] sr = saturate_delta(dr_q, y_q, saturation_factor_q2, saturation_round_q2) + temperature_offset_q2;
wire signed [11:0] sg = saturate_delta(dg_q, y_q, saturation_factor_q2, saturation_round_q2);
wire signed [11:0] sb = saturate_delta(db_q, y_q, saturation_factor_q2, saturation_round_q2) - temperature_offset_q2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cr <= 12'sd0;
        cg <= 12'sd0;
        cb <= 12'sd0;
        temperature_offset_q <= 12'sd0;
        saturation_index_q <= 3'd3;
        de_q <= 1'b0;
        y_q <= 12'sd0;
        dr_q <= 12'sd0;
        dg_q <= 12'sd0;
        db_q <= 12'sd0;
        temperature_offset_q2 <= 12'sd0;
        saturation_factor_q2 <= 3'd4;
        saturation_round_q2 <= 1'b0;
        de_q2 <= 1'b0;
        rgb_out <= 24'd0;
    end else begin
        cr <= cr_next;
        cg <= cg_next;
        cb <= cb_next;
        temperature_offset_q <= temperature_offset;
        saturation_index_q <= saturation_index;
        de_q <= de;
        y_q <= y_next;
        dr_q <= cr - y_next;
        dg_q <= cg - y_next;
        db_q <= cb - y_next;
        temperature_offset_q2 <= temperature_offset_q;
        // Decode alongside luma/delta registers, not in front of the DSP.
        case (saturation_index_q)
            3'd0: saturation_factor_q2 <= 3'd0;
            3'd1: saturation_factor_q2 <= 3'd2;
            3'd2: saturation_factor_q2 <= 3'd3;
            3'd4: saturation_factor_q2 <= 3'd5;
            3'd5: saturation_factor_q2 <= 3'd6;
            default: saturation_factor_q2 <= 3'd4;
        endcase
        saturation_round_q2 <= saturation_index_q == 3'd2;
        de_q2 <= de_q;
        rgb_out <= de_q2 ? {clip(sr), clip(sg), clip(sb)} : 24'd0;
    end
end

endmodule
`default_nettype wire
