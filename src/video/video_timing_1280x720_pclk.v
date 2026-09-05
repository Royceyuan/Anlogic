`timescale 1ns / 1ps
`default_nettype none

// CEA-like 1280x720 timing. The 75 MHz candidate is close to the standard
// 74.25 MHz clock and is isolated until the monitor accepts it.
module video_timing_1280x720_pclk #(
    parameter integer H_VISIBLE = 1280,
    parameter integer H_FRONT   = 110,
    parameter integer H_SYNC    = 40,
    parameter integer H_BACK    = 220,
    parameter integer V_VISIBLE = 720,
    parameter integer V_FRONT   = 5,
    parameter integer V_SYNC    = 5,
    parameter integer V_BACK    = 20
) (
    input  wire        clk,
    input  wire        rst_n,
    output reg         hs,
    output reg         vs,
    output reg         de,
    output reg  [10:0] x,
    output reg  [9:0]  y,
    output reg         frame_tick
);

localparam integer H_TOTAL = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;
localparam integer V_TOTAL = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;

reg [10:0] hcnt;
reg [9:0]  vcnt;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        hcnt      <= 11'd0;
        vcnt      <= 10'd0;
        hs        <= 1'b1;
        vs        <= 1'b1;
        de        <= 1'b0;
        x         <= 11'd0;
        y         <= 10'd0;
        frame_tick<= 1'b0;
    end else begin
        frame_tick <= 1'b0;
        if (hcnt == H_TOTAL - 1) begin
            hcnt <= 11'd0;
            if (vcnt == V_TOTAL - 1) begin
                vcnt       <= 10'd0;
                frame_tick <= 1'b1;
            end else begin
                vcnt <= vcnt + 10'd1;
            end
        end else begin
            hcnt <= hcnt + 11'd1;
        end

        x  <= hcnt;
        y  <= vcnt;
        de <= (hcnt < H_VISIBLE) && (vcnt < V_VISIBLE);
        hs <= ~((hcnt >= H_VISIBLE + H_FRONT) &&
                (hcnt < H_VISIBLE + H_FRONT + H_SYNC));
        vs <= ~((vcnt >= V_VISIBLE + V_FRONT) &&
                (vcnt < V_VISIBLE + V_FRONT + V_SYNC));
    end
end

endmodule

`default_nettype wire
