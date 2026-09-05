`timescale 1ns / 1ps
`default_nettype none

// v52 diagnostic-only full-frame reader.  The RGB565 expected value is an
// address-derived pattern emitted by scripts/make_sdram_diag_assets.ps1.
// `read_fifo_valid` is the authoritative beat qualifier for the NOREG FIFO.
module sdram_diag_readback_checker #(
    parameter integer SOURCE_W = 960,
    parameter integer SOURCE_H = 540,
    parameter integer ADDR_BITS = 21
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire read_req_ack,
    input wire read_fifo_empty,
    input wire read_fifo_valid,
    input wire [31:0] read_data,
    output reg read_req,
    output wire read_en,
    output reg active,
    output reg done,
    output reg pass,
    output reg fail,
    output reg [ADDR_BITS-1:0] first_error_addr,
    output reg [31:0] first_error_actual,
    output reg [31:0] first_error_expected
);

localparam integer FRAME_WORDS = (SOURCE_W * SOURCE_H) / 2;
reg [ADDR_BITS-1:0] pops_issued;
reg [ADDR_BITS-1:0] words_seen;
reg [10:0] pixel_x;
reg [10:0] pixel_y;

function [15:0] expected_pixel;
    input [10:0] x;
    input [10:0] y;
    reg [4:0] r;
    reg [5:0] g;
    reg [4:0] b;
    begin
        if ((x[5:0] == 6'd0) || (y[5:0] == 6'd0))
            expected_pixel = 16'hffff;
        else if ((x[3:0] == 4'd1) || (y[3:0] == 4'd1))
            expected_pixel = 16'h0000;
        else begin
            r = (x ^ {y[4:0], 1'b0}) & 5'h1f;
            g = (y ^ (x >> 2)) & 6'h3f;
            b = (x ^ y) & 5'h1f;
            expected_pixel = {r, g, b};
        end
    end
endfunction

wire [31:0] expected_word = {expected_pixel(pixel_x, pixel_y),
                              expected_pixel(pixel_x + 1'b1, pixel_y)};
assign read_en = active && (pops_issued < FRAME_WORDS) && !read_fifo_empty;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        read_req             <= 1'b0;
        active               <= 1'b0;
        done                 <= 1'b0;
        pass                 <= 1'b0;
        fail                 <= 1'b0;
        pops_issued          <= {ADDR_BITS{1'b0}};
        words_seen           <= {ADDR_BITS{1'b0}};
        pixel_x              <= 11'd0;
        pixel_y              <= 11'd0;
        first_error_addr     <= {ADDR_BITS{1'b0}};
        first_error_actual   <= 32'd0;
        first_error_expected <= 32'd0;
    end else begin
        if (start && !active && !done && !read_req)
            read_req <= 1'b1;
        if (read_req && read_req_ack) begin
            read_req <= 1'b0;
            active   <= 1'b1;
        end
        if (read_en)
            pops_issued <= pops_issued + 1'b1;
        if (active && read_fifo_valid) begin
            if ((read_data !== expected_word) && !fail) begin
                fail                 <= 1'b1;
                first_error_addr     <= words_seen;
                first_error_actual   <= read_data;
                first_error_expected <= expected_word;
            end
            if (pixel_x == SOURCE_W - 2) begin
                pixel_x <= 11'd0;
                pixel_y <= (pixel_y == SOURCE_H - 1) ? 11'd0 : pixel_y + 1'b1;
            end else begin
                pixel_x <= pixel_x + 2'd2;
            end
            if (words_seen == FRAME_WORDS - 1) begin
                active <= 1'b0;
                done   <= 1'b1;
                pass   <= !(fail || (read_data !== expected_word));
            end
            words_seen <= words_seen + 1'b1;
        end
    end
end
endmodule

`default_nettype wire
