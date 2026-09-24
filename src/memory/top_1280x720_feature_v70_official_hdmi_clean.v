`timescale 1ns / 1ps
`default_nettype none

// v70 is an independent 1280x720 bring-up candidate.  It reuses the same
// Anlogic HDMI transmitter as the official 31_hdmi_tx_display_B example,
// while keeping the current FAT32/BMP/adaptive-loader and SDRAM frame store.
// OSD, subtitle and transition logic are deliberately disabled here so a
// first 720p hardware test isolates the image/SDRAM/HDMI path.
module top_1280x720_feature_v70_official_hdmi_clean (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p,
    input wire uart_rxd, output wire uart_txd
);

museum_media_core #(
    .VIDEO_W(1280), .VIDEO_H(720),
    .SOURCE_W(1280), .SOURCE_H(720),
    .VIDEO_BURST_WORDS(128),
    .VIDEO_WRITE_BURST_WORDS(128),
    .VIDEO_READ_BURST_WORDS(128),
    .VIDEO_MODE_1280(1),
    .ADAPTIVE_BMP(1),
    .ADAPTIVE_BMP_MAX_WIDTH(1920),
    .ADAPTIVE_BMP_MAX_HEIGHT(1080),
    .ADAPTIVE_BLOCK_WRITER(0),
    .ENABLE_OSD(0), .ENABLE_FADE(0),
    .VIDEO_SEQUENCE(0), .VIDEO_BIN(0),
    // Two complete 1280x720 RGB565 frames fit in the 2M-word SDRAM.  Five
    // cached frames do not, so this candidate uses the existing fast
    // IMAGE0/IMAGE1 preload path.
    .PRELOAD_BOTH_IMAGES(1),
    .MULTI_IMAGE_BMP(1), .MULTI_FRAME_PRELOAD(0),
    .VIDEO_FRAME_COUNT(2), .KEY_DEBOUNCE_BITS(17),
    .LINEBUF_SCALE(0),
    .ENABLE_SUBTITLE(0), .SUBTITLE_BPP(2),
    .SUBTITLE_PROTOCOL_VERSION(2), .SUBTITLE_BRAM_REGISTER_READ(0),
    .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_FRONT(5), .V_SYNC(5), .V_BACK(20)
) u_top_1280x720_v70 (
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
