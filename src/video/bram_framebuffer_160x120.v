`timescale 1ns / 1ps
`default_nettype none

// A small, dual-clock RGB565 framebuffer for the first TF-to-HDMI milestone.
// A 160x120 source is expanded by exactly 4x to the 640x480 HDMI timing.
module bram_framebuffer_160x120 #(
    parameter integer IMAGE_WIDTH  = 160,
    parameter integer IMAGE_HEIGHT = 120
)(
    input  wire        wr_clk,
    input  wire        wr_en,
    input  wire [14:0] wr_addr,
    input  wire [15:0] wr_data,

    input  wire        rd_clk,
    input  wire        rd_de,
    input  wire [9:0]  rd_x,
    input  wire [9:0]  rd_y,
    output reg  [11:0] rgb
);

reg [15:0] framebuffer [0:IMAGE_WIDTH*IMAGE_HEIGHT-1];
reg [15:0] read_data;
// 160 source columns require 8 bits. The linear address needs 15 bits:
// 160 * 119 + 159 = 19199. Keep the additions at this width so addresses
// starting at 16384 do not wrap back to the first image row.
wire [7:0] source_x;
wire [6:0] source_y;
wire [14:0] source_addr;

assign source_x = rd_x[9:2];
assign source_y = rd_y[8:2];
assign source_addr = {3'd0, source_y, 5'd0} +
                     {1'd0, source_y, 7'd0} + source_x;

always @(posedge wr_clk) begin
    if (wr_en)
        framebuffer[wr_addr] <= wr_data;
end

always @(posedge rd_clk) begin
    if (rd_de && source_x < IMAGE_WIDTH && source_y < IMAGE_HEIGHT) begin
        read_data <= framebuffer[source_addr];
        rgb <= {read_data[15:12], read_data[10:7], read_data[4:1]};
    end else begin
        rgb <= 12'h000;
    end
end

endmodule

`default_nettype wire
