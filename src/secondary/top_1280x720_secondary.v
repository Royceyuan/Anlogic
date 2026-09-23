`timescale 1ns / 1ps
`default_nettype none

// SECONDARY-0: local HDMI diagnostic only. No media or network dependency.
module top_1280x720_secondary (
    input  wire       clk_50m,
    input  wire       key_reset_n,
    output wire [1:0] led,
    output wire [7:0] seg_data,
    output wire [7:0] seg_sel,
    output wire       hdmi1_clk_p,
    output wire       hdmi1_d2_p,
    output wire       hdmi1_d1_p,
    output wire       hdmi1_d0_p
);

wire video_clk;
wire video_clk_5x;
wire video_rst_n;
wire video_hs;
wire video_vs;
wire video_de;
wire [10:0] video_x;
wire [9:0] video_y;
wire [23:0] video_rgb;
reg [25:0] heartbeat;

video_pll_75m u_video_pll (
    .refclk(clk_50m), .reset(~key_reset_n),
    .clk0_out(video_clk), .clk1_out(video_clk_5x)
);

reset_sync u_video_reset (
    .clk(video_clk), .arst_n(key_reset_n), .srst_n(video_rst_n)
);

video_timing_1280x720_pclk u_video_timing (
    .clk(video_clk), .rst_n(video_rst_n),
    .hs(video_hs), .vs(video_vs), .de(video_de),
    .x(video_x), .y(video_y), .frame_tick()
);

hdmi_1280x720_pattern u_pattern (
    .de(video_de), .x(video_x), .y(video_y), .rgb(video_rgb)
);

hdmi_tx u_hdmi_tx (
    .PXLCLK_I(video_clk), .PXLCLK_5X_I(video_clk_5x), .RST_N(video_rst_n),
    .VGA_HS(video_hs), .VGA_VS(video_vs), .VGA_DE(video_de),
    .VGA_RGB(video_rgb), .HDMI_CLK_P(hdmi1_clk_p),
    .HDMI_D2_P(hdmi1_d2_p), .HDMI_D1_P(hdmi1_d1_p),
    .HDMI_D0_P(hdmi1_d0_p)
);

always @(posedge clk_50m or negedge key_reset_n) begin
    if (!key_reset_n)
        heartbeat <= 26'd0;
    else
        heartbeat <= heartbeat + 1'b1;
end

assign led[0] = heartbeat[25];
assign led[1] = video_rst_n;

// The seven-segment glyph for hexadecimal 5 also reads as S: "S000".
seg_hex_display u_stage_code (
    .clk(clk_50m), .rst_n(key_reset_n), .value(16'h5000),
    .seg_data(seg_data), .seg_sel(seg_sel)
);

endmodule

`default_nettype wire
