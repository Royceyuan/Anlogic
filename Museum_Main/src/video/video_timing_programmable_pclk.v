`timescale 1ns / 1ps
`default_nettype none

module video_timing_programmable_pclk #(
    parameter integer H_VISIBLE = 640,
    parameter integer H_FRONT   = 16,
    parameter integer H_SYNC    = 96,
    parameter integer H_BACK    = 48,
    parameter integer V_VISIBLE = 480,
    parameter integer V_FRONT   = 10,
    parameter integer V_SYNC    = 2,
    parameter integer V_BACK    = 33,
    parameter integer X_BITS    = (H_VISIBLE > 1023) ? 11 : 10
) (
    input  wire       clk,
    input  wire       rst_n,
    output reg        hs,
    output reg        vs,
    output reg        de,
    output reg [X_BITS-1:0] x,
    output reg [X_BITS-1:0] active_x,
    output reg [9:0]  y,
    output reg        frame_tick
);

localparam integer H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;

localparam integer V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;

// 800x600 uses a 1056-pixel horizontal total, which needs 11 bits. The
// output coordinates remain 10 bits because the visible width is below 1024.
reg [10:0] hcnt;
reg [9:0] vcnt;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        hcnt <= 11'd0;
        vcnt <= 10'd0;
        hs <= 1'b1;
        vs <= 1'b1;
        de <= 1'b0;
        x <= {X_BITS{1'b0}};
        active_x <= {X_BITS{1'b0}};
        y <= 10'd0;
        frame_tick <= 1'b0;
    end else begin
        frame_tick <= 1'b0;

        if (hcnt == H_TOTAL - 1) begin
            hcnt <= 11'd0;
            if (vcnt == V_TOTAL - 1) begin
                vcnt <= 10'd0;
                frame_tick <= 1'b1;
            end else begin
                vcnt <= vcnt + 10'd1;
            end
        end else begin
            hcnt <= hcnt + 11'd1;
        end

        x <= hcnt[X_BITS-1:0];
        active_x <= ((hcnt < H_VISIBLE) && (vcnt < V_VISIBLE)) ?
                    hcnt[X_BITS-1:0] : {X_BITS{1'b0}};
        y <= vcnt;
        de <= (hcnt < H_VISIBLE) && (vcnt < V_VISIBLE);
        hs <= ~((hcnt >= H_VISIBLE + H_FRONT) &&
                (hcnt < H_VISIBLE + H_FRONT + H_SYNC));
        vs <= ~((vcnt >= V_VISIBLE + V_FRONT) &&
                (vcnt < V_VISIBLE + V_FRONT + V_SYNC));
    end
end

endmodule

`default_nettype wire
