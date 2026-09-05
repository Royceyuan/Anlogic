`timescale 1ns / 1ps
`default_nettype none

// v70b fixes v70's guaranteed SDRAM read underflow.  The HDMI raster remains
// 1280x720, but the frame store is 960x540 RGB565 and the proven 3:4 line
// buffer expands it to the output raster.  At 60.6 frames/s this reduces the
// average SDRAM demand from about 27.93 Mword/s to 15.71 Mword/s, which fits
// the established 25 MHz SDRAM user clock without changing its clocking.
module top_1280x720_feature_v70b_bandwidth_fix (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p,
    input wire uart_rxd, output wire uart_txd
);

top_v66 #(
    .VIDEO_W(1280), .VIDEO_H(720),
    .SOURCE_W(960), .SOURCE_H(540),
    .VIDEO_BURST_WORDS(128),
    // 480 words per stored row is exactly 30 verified 16-word writes.
    .VIDEO_WRITE_BURST_WORDS(16),
    .VIDEO_READ_BURST_WORDS(128),
    .VIDEO_MODE_1280(1),
    .ADAPTIVE_BMP(1),
    .ADAPTIVE_BMP_MAX_WIDTH(1920),
    .ADAPTIVE_BMP_MAX_HEIGHT(1080),
    .ADAPTIVE_BLOCK_WRITER(0),
    .ENABLE_OSD(0), .ENABLE_FADE(0),
    .VIDEO_SEQUENCE(0), .VIDEO_BIN(0),
    .PRELOAD_BOTH_IMAGES(1),
    .MULTI_IMAGE_BMP(1), .MULTI_FRAME_PRELOAD(0),
    .VIDEO_FRAME_COUNT(2), .KEY_DEBOUNCE_BITS(17),
    // Reuse the hardware-isolated v26/v28/v51 line-buffer alignment path.
    .LINEBUF_SCALE(1),
    .LINEBUF_REGISTER_READ(1),
    .LINEBUF_V26_OUTPUT_PIPELINE(1),
    .LINEBUF_FIFO_RESPONSE_REGISTER(0),
    .ENABLE_SUBTITLE(0), .SUBTITLE_BPP(2),
    .SUBTITLE_PROTOCOL_VERSION(2), .SUBTITLE_BRAM_REGISTER_READ(0),
    .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_FRONT(5), .V_SYNC(5), .V_BACK(20)
) u_top_1280x720_v70b (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel),
    .sd_clk(sd_clk), .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p),
    .uart_rxd(uart_rxd), .uart_txd(uart_txd)
);
endmodule

`default_nettype wire
