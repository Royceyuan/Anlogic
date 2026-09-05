`timescale 1ns / 1ps
`default_nettype none

module scaler_fit #(
    parameter integer DST_W = 640,
    parameter integer DST_H = 480,
    parameter integer SRC_W = 320,
    parameter integer SRC_H = 240
)(
    input  wire       de,
    input  wire [9:0] x,
    input  wire [9:0] y,
    output wire       fit_de,
    output wire [9:0] fit_x,
    output wire [9:0] fit_y,
    output wire [9:0] fit_w,
    output wire [9:0] fit_h,
    output wire [9:0] offset_x,
    output wire [9:0] offset_y
);

localparam integer FIT_BY_WIDTH = (SRC_W * DST_H >= SRC_H * DST_W);
localparam integer FIT_W_INT = FIT_BY_WIDTH ? DST_W : ((DST_H * SRC_W) / SRC_H);
localparam integer FIT_H_INT = FIT_BY_WIDTH ? ((DST_W * SRC_H) / SRC_W) : DST_H;
localparam integer FIT_W_SAFE = (FIT_W_INT < 1) ? 1 : FIT_W_INT;
localparam integer FIT_H_SAFE = (FIT_H_INT < 1) ? 1 : FIT_H_INT;
localparam integer OFFSET_X_INT = (DST_W - FIT_W_SAFE) / 2;
localparam integer OFFSET_Y_INT = (DST_H - FIT_H_SAFE) / 2;

wire in_window;
wire [10:0] rel_x;
wire [10:0] rel_y;
wire [20:0] scaled_x;
wire [20:0] scaled_y;

assign fit_w    = FIT_W_SAFE;
assign fit_h    = FIT_H_SAFE;
assign offset_x = OFFSET_X_INT;
assign offset_y = OFFSET_Y_INT;

assign in_window = de &&
                   (x >= offset_x) && (x < offset_x + fit_w) &&
                   (y >= offset_y) && (y < offset_y + fit_h);

assign rel_x = x - offset_x;
assign rel_y = y - offset_y;

assign scaled_x = in_window ? ((rel_x * SRC_W) / fit_w) : 21'd0;
assign scaled_y = in_window ? ((rel_y * SRC_H) / fit_h) : 21'd0;

assign fit_de = in_window;
assign fit_x  = scaled_x[9:0];
assign fit_y  = scaled_y[9:0];

endmodule

`default_nettype wire
