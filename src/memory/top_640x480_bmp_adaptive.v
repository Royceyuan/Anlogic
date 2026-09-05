`timescale 1ns / 1ps
`default_nettype none

// Isolated adaptive BMP candidate. The verified RGB565 sequence top remains
// unchanged and is still the rollback image for the board.
module top_640x480_bmp_adaptive (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p
);

top #(
    .VIDEO_W(640), .VIDEO_H(480), .VIDEO_BURST_WORDS(64),
    .ENABLE_OSD(1), .ENABLE_FADE(1), .VIDEO_SEQUENCE(0), .VIDEO_BIN(0),
    .VIDEO_FRAME_COUNT(2),
    .ADAPTIVE_BMP(1)
) u_top (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk), .sd_mosi(sd_mosi),
    .sd_miso(sd_miso), .sd_cs_n(sd_cs_n), .vga_hs(vga_hs), .vga_vs(vga_vs),
    .vga_d(vga_d), .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

`default_nettype wire
