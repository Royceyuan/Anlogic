`timescale 1ns / 1ps
`default_nettype none

module video_timing_640x480 (
    input  wire       clk,
    input  wire       rst_n,
    output reg        hs,
    output reg        vs,
    output reg        de,
    output reg [9:0]  x,
    output reg [9:0]  y,
    output reg        frame_tick
);

localparam integer H_VISIBLE = 640;
localparam integer H_FRONT   = 16;
localparam integer H_SYNC    = 96;
localparam integer H_BACK    = 48;
localparam integer H_TOTAL   = 800;

localparam integer V_VISIBLE = 480;
localparam integer V_FRONT   = 10;
localparam integer V_SYNC    = 2;
localparam integer V_BACK    = 33;
localparam integer V_TOTAL   = 525;

reg        pix_phase;
reg [9:0]  hcnt;
reg [9:0]  vcnt;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pix_phase <= 1'b0;
    end else begin
        pix_phase <= ~pix_phase;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        hcnt <= 10'd0;
        vcnt <= 10'd0;
        hs <= 1'b1;
        vs <= 1'b1;
        de <= 1'b0;
        x <= 10'd0;
        y <= 10'd0;
        frame_tick <= 1'b0;
    end else begin
        frame_tick <= 1'b0;
        if (pix_phase) begin
            if (hcnt == H_TOTAL - 1) begin
                hcnt <= 10'd0;
                if (vcnt == V_TOTAL - 1) begin
                    vcnt <= 10'd0;
                    frame_tick <= 1'b1;
                end else begin
                    vcnt <= vcnt + 10'd1;
                end
            end else begin
                hcnt <= hcnt + 10'd1;
            end

            x <= hcnt;
            y <= vcnt;
            de <= (hcnt < H_VISIBLE) && (vcnt < V_VISIBLE);
            hs <= ~((hcnt >= H_VISIBLE + H_FRONT) &&
                    (hcnt < H_VISIBLE + H_FRONT + H_SYNC));
            vs <= ~((vcnt >= V_VISIBLE + V_FRONT) &&
                    (vcnt < V_VISIBLE + V_FRONT + V_SYNC));
        end
    end
end

endmodule

`default_nettype wire
