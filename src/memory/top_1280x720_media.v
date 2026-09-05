`timescale 1ns / 1ps
`default_nettype none

// 1280x720 media candidate. The verified 800x600 wrapper remains separate.
module top_1280x720_media (
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

top #(
    .VIDEO_W(1280),
    .VIDEO_H(720),
    .VIDEO_BURST_WORDS(128),
    .VIDEO_MODE_1280(1),
    .ENABLE_OSD(0),
    .H_FRONT(110),
    .H_SYNC(40),
    .H_BACK(220),
    .V_FRONT(5),
    .V_SYNC(5),
    .V_BACK(20)
) u_top_1280x720 (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw),
    .led(led), .seg_data(seg_data), .seg_sel(seg_sel),
    .sd_clk(sd_clk), .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

`default_nettype wire
