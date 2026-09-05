`timescale 1ns / 1ps
`default_nettype none

module test_pattern #(
    parameter integer IMG_W = 320,
    parameter integer IMG_H = 240
)(
    input  wire       de,
    input  wire [2:0] state_code,
    input  wire [7:0] image_index,
    input  wire       overlay_enable,
    input  wire [9:0] x,
    input  wire [9:0] y,
    output reg  [11:0] rgb
);

localparam integer BORDER_X_INT = (IMG_W >= 40) ? (IMG_W / 40) : 1;
localparam integer BORDER_Y_INT = (IMG_H >= 30) ? (IMG_H / 30) : 1;
localparam integer OVERLAY_H_INT = (IMG_H >= 15) ? (IMG_H / 15) : 1;

wire [9:0] border_x;
wire [9:0] border_y;
wire [9:0] overlay_h;
wire [9:0] right_border;
wire [9:0] bottom_border;

assign border_x = BORDER_X_INT;
assign border_y = BORDER_Y_INT;
assign overlay_h = OVERLAY_H_INT;
assign right_border = IMG_W - BORDER_X_INT;
assign bottom_border = IMG_H - BORDER_Y_INT;

always @(*) begin
    if (!de) begin
        rgb = 12'h000;
    end else if (overlay_enable && (y < overlay_h)) begin
        case (state_code)
            3'd1: rgb = 12'h444;
            3'd2: rgb = 12'h0F0;
            3'd3: rgb = 12'h00F;
            default: rgb = 12'hF00;
        endcase
    end else if ((x < border_x) || (x >= right_border) ||
                 (y < border_y) || (y >= bottom_border)) begin
        rgb = 12'hFFF;
    end else begin
        case (state_code)
            3'd1: rgb = {x[8:5], y[8:5], image_index[7:4]};
            3'd2: rgb = {image_index[3:0], x[8:5], y[8:5]};
            3'd3: rgb = {y[8:5], image_index[7:4], x[8:5]};
            default: rgb = {x[8:5] ^ image_index[3:0], y[8:5], image_index[7:4]};
        endcase
    end
end

endmodule

`default_nettype wire
