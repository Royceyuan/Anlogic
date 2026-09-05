`timescale 1ns / 1ps
`default_nettype none

// HDMI-only 1280x720 candidate. It deliberately has no TF or SDRAM path.
module top_1280x720_pattern (
    input  wire        clk_50m,
    input  wire [3:0]  key_n,
    input  wire [3:0]  sw,
    output wire [3:0]  led,
    output wire [7:0]  seg_data,
    output wire [7:0]  seg_sel,
    output wire        sd_clk,
    output wire        sd_mosi,
    input  wire        sd_miso,
    output wire        sd_cs_n,
    output wire        vga_hs,
    output wire        vga_vs,
    output wire [11:0] vga_d,
    output wire        hdmi1_clk_p,
    output wire        hdmi1_d2_p,
    output wire        hdmi1_d1_p,
    output wire        hdmi1_d0_p
);

wire video_clk;
wire video_clk_5x;
wire video_rst_n;
wire video_hs;
wire video_vs;
wire video_de;
wire [10:0] video_x;
wire [9:0]  video_y;
wire [23:0] video_rgb;
reg [25:0] heartbeat;

reset_sync u_video_reset (
    .clk(video_clk), .arst_n(key_n[0]), .srst_n(video_rst_n)
);

video_pll_75m u_video_pll (
    .refclk(clk_50m), .reset(~key_n[0]),
    .clk0_out(video_clk), .clk1_out(video_clk_5x)
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

always @(posedge clk_50m or negedge key_n[0]) begin
    if (!key_n[0])
        heartbeat <= 26'd0;
    else
        heartbeat <= heartbeat + 1'b1;
end

assign led[0] = heartbeat[25];
assign led[1] = video_rst_n;
assign led[2] = video_de;
assign led[3] = 1'b1;
assign seg_data = 8'h00;
assign seg_sel  = 8'h00;
assign sd_clk   = 1'b0;
assign sd_mosi  = 1'b0;
assign sd_cs_n  = 1'b1;
assign vga_hs   = video_hs;
assign vga_vs   = video_vs;
assign vga_d    = video_rgb[23:12];

endmodule

`default_nettype wire
