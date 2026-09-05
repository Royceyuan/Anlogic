`timescale 1ns / 1ps
`default_nettype none

// Isolated 1024x768 candidate. The verified 800x600 top remains unchanged.
module top_1024x768 (
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
    .VIDEO_W(1024),
    .VIDEO_H(768),
    .VIDEO_BURST_WORDS(128),
    .VIDEO_MODE_1024(1),
    .H_FRONT(24),
    .H_SYNC(136),
    .H_BACK(160),
    .V_FRONT(3),
    .V_SYNC(6),
    .V_BACK(29)
) u_top_1024x768 (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw),
    .led(led), .seg_data(seg_data), .seg_sel(seg_sel),
    .sd_clk(sd_clk), .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

// v55: native 4:3 media candidate based only on the hardware-proven v54
// structure.  The source BMP, SDRAM frame, and HDMI raster are all 1024x768.
module top_1024x768_native_v55 (
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
    .VIDEO_W(1024), .VIDEO_H(768),
    .SOURCE_W(1024), .SOURCE_H(768),
    .VIDEO_BURST_WORDS(128), .VIDEO_READ_BURST_WORDS(128),
    .VIDEO_MODE_1024(1), .ADAPTIVE_BMP(0), .LINEBUF_SCALE(0),
    .ENABLE_OSD(0), .ENABLE_FADE(0), .VIDEO_SEQUENCE(0), .VIDEO_BIN(0),
    .H_FRONT(24), .H_SYNC(136), .H_BACK(160),
    .V_FRONT(3), .V_SYNC(6), .V_BACK(29)
) u_top_1024x768_native_v55 (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw),
    .led(led), .seg_data(seg_data), .seg_sel(seg_sel),
    .sd_clk(sd_clk), .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

`default_nettype wire
