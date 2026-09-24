`timescale 1ns / 1ps
`default_nettype none

// v71 integrates the stable v69 user features on v70c's 960x540-to-720p
// bandwidth and BRAM/restart fixes. The existing 800x32 subtitle packet stays
// compatible and is centered inside the 1280-pixel output.
module top_1280x720_feature_v71_full_features (
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
    .SOURCE_W(960), .SOURCE_H(540),
    .VIDEO_BURST_WORDS(128),
    .VIDEO_WRITE_BURST_WORDS(16),
    .VIDEO_READ_BURST_WORDS(128),
    .VIDEO_MODE_1280(1),
    .ADAPTIVE_BMP(1),
    .ADAPTIVE_BMP_MAX_WIDTH(1920),
    .ADAPTIVE_BMP_MAX_HEIGHT(1080),
    .ADAPTIVE_BLOCK_WRITER(0),
    .ENABLE_OSD(1), .ENABLE_FADE(1),
    .VIDEO_SEQUENCE(0), .VIDEO_BIN(0),
    .PRELOAD_BOTH_IMAGES(0),
    .MULTI_IMAGE_BMP(1), .MULTI_FRAME_PRELOAD(1),
    .VIDEO_FRAME_COUNT(5), .KEY_DEBOUNCE_BITS(17),
    .LINEBUF_SCALE(1),
    .LINEBUF_REGISTER_READ(0),
    .LINEBUF_NOREG_SYNC_READ(1),
    .LINEBUF_V26_OUTPUT_PIPELINE(1),
    .LINEBUF_FIFO_RESPONSE_REGISTER(0),
    .ENABLE_SUBTITLE(1), .SUBTITLE_BPP(2),
    .SUBTITLE_PROTOCOL_VERSION(2), .SUBTITLE_BRAM_REGISTER_READ(0),
    .SUBTITLE_WIDTH(800), .SUBTITLE_X_START(240),
    .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_FRONT(5), .V_SYNC(5), .V_BACK(20)
) u_top_1280x720_v71 (
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
