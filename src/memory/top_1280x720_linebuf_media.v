`timescale 1ns / 1ps
`default_nettype none

// Independent 1280x720 media candidate. It keeps a 960x540 RGB565 frame in
// SDRAM and expands it at the output with the verified line-buffer scaler.
module top_1280x720_linebuf_media (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p
);

top #(
    // 960 RGB565 pixels are 480 32-bit words per SDRAM row.  The official
    // frame FIFO completes fixed-size bursts, so use 32 words: 480/32=15
    // exact bursts and no unsupported 32-word tail of a 64-word request.
    .VIDEO_W(1280), .VIDEO_H(720), .VIDEO_BURST_WORDS(32),
    .VIDEO_MODE_1280(1), .ENABLE_OSD(0), .ENABLE_FADE(1),
    .VIDEO_SEQUENCE(0), .VIDEO_BIN(0), .ADAPTIVE_BMP(1),
    .VIDEO_FRAME_COUNT(2), .SOURCE_W(960), .SOURCE_H(540),
    .LINEBUF_SCALE(1),
    .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_FRONT(5), .V_SYNC(5), .V_BACK(20)
) u_top (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk), .sd_mosi(sd_mosi),
    .sd_miso(sd_miso), .sd_cs_n(sd_cs_n), .vga_hs(vga_hs), .vga_vs(vga_vs),
    .vga_d(vga_d), .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

// v27: production media path with the verified registered line-buffer read.
// OSD and fade stay disabled until the raw BMP picture is board-accepted.
module top_1280x720_linebuf_media_bram_readreg_v27 (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p
);

top #(
    .VIDEO_W(1280), .VIDEO_H(720), .VIDEO_BURST_WORDS(32),
    .VIDEO_MODE_1280(1), .ENABLE_OSD(0), .ENABLE_FADE(0),
    .VIDEO_SEQUENCE(0), .VIDEO_BIN(0), .ADAPTIVE_BMP(1),
    .VIDEO_FRAME_COUNT(2), .SOURCE_W(960), .SOURCE_H(540),
    .LINEBUF_SCALE(1), .LINEBUF_REGISTER_READ(1),
    .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_FRONT(5), .V_SYNC(5), .V_BACK(20)
) u_top (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk), .sd_mosi(sd_mosi),
    .sd_miso(sd_miso), .sd_cs_n(sd_cs_n), .vga_hs(vga_hs), .vga_vs(vga_vs),
    .vga_d(vga_d), .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

// v28: registered line-buffer media path with the 20-clock pixel alignment
// and one-cycle line-tail completion used by the verified raster model.
module top_1280x720_linebuf_media_bram_readreg_v28 (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p
);

top #(
    .VIDEO_W(1280), .VIDEO_H(720), .VIDEO_BURST_WORDS(32),
    .VIDEO_MODE_1280(1), .ENABLE_OSD(0), .ENABLE_FADE(0),
    .VIDEO_SEQUENCE(0), .VIDEO_BIN(0), .ADAPTIVE_BMP(1),
    .VIDEO_FRAME_COUNT(2), .SOURCE_W(960), .SOURCE_H(540),
    .LINEBUF_SCALE(1), .LINEBUF_REGISTER_READ(1),
    .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_FRONT(5), .V_SYNC(5), .V_BACK(20)
) u_top (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk), .sd_mosi(sd_mosi),
    .sd_miso(sd_miso), .sd_cs_n(sd_cs_n), .vga_hs(vga_hs), .vga_vs(vga_vs),
    .vga_d(vga_d), .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

// v29: reproduce the board-clean v26 registered-BRAM/output pipeline while
// retaining the real TF/BMP/SDRAM media source used by v28.
module top_1280x720_linebuf_media_v26pipe_v29 (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p
);

top #(
    .VIDEO_W(1280), .VIDEO_H(720), .VIDEO_BURST_WORDS(32),
    .VIDEO_MODE_1280(1), .ENABLE_OSD(0), .ENABLE_FADE(0),
    .VIDEO_SEQUENCE(0), .VIDEO_BIN(0), .ADAPTIVE_BMP(1),
    .VIDEO_FRAME_COUNT(2), .SOURCE_W(960), .SOURCE_H(540),
    .LINEBUF_SCALE(1), .LINEBUF_REGISTER_READ(1),
    .LINEBUF_V26_OUTPUT_PIPELINE(1),
    .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_FRONT(5), .V_SYNC(5), .V_BACK(20)
) u_top (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk), .sd_mosi(sd_mosi),
    .sd_miso(sd_miso), .sd_cs_n(sd_cs_n), .vga_hs(vga_hs), .vga_vs(vga_vs),
    .vga_d(vga_d), .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

// v30: v29 media pipeline with 32-word SDRAM read prefetches.  Writes remain
// at 32 words; this candidate isolates only the board read-side burst size.
module top_1280x720_linebuf_media_fifo32_v30 (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p
);

top #(
    .VIDEO_W(1280), .VIDEO_H(720), .VIDEO_BURST_WORDS(32),
    .VIDEO_READ_BURST_WORDS(32),
    .VIDEO_MODE_1280(1), .ENABLE_OSD(0), .ENABLE_FADE(0),
    .VIDEO_SEQUENCE(0), .VIDEO_BIN(0), .ADAPTIVE_BMP(1),
    .VIDEO_FRAME_COUNT(2), .SOURCE_W(960), .SOURCE_H(540),
    .LINEBUF_SCALE(1), .LINEBUF_REGISTER_READ(1),
    .LINEBUF_V26_OUTPUT_PIPELINE(1),
    .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_FRONT(5), .V_SYNC(5), .V_BACK(20)
) u_top (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk), .sd_mosi(sd_mosi),
    .sd_miso(sd_miso), .sd_cs_n(sd_cs_n), .vga_hs(vga_hs), .vga_vs(vga_vs),
    .vga_d(vga_d), .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

// v31: v30 transaction size plus a registered read-FIFO BRAM output.  The
// scaler commits data only when FIFO valid is asserted, so it tolerates the
// additional valid cycle without altering image geometry or write traffic.
module top_1280x720_linebuf_media_fifo32_outreg_v31 (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p
);

top #(
    .VIDEO_W(1280), .VIDEO_H(720), .VIDEO_BURST_WORDS(32),
    .VIDEO_READ_BURST_WORDS(32), .VIDEO_READ_FIFO_OUTREG("OUTREG"),
    .VIDEO_MODE_1280(1), .ENABLE_OSD(0), .ENABLE_FADE(0),
    .VIDEO_SEQUENCE(0), .VIDEO_BIN(0), .ADAPTIVE_BMP(1),
    .VIDEO_FRAME_COUNT(2), .SOURCE_W(960), .SOURCE_H(540),
    .LINEBUF_SCALE(1), .LINEBUF_REGISTER_READ(1),
    .LINEBUF_V26_OUTPUT_PIPELINE(1),
    .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_FRONT(5), .V_SYNC(5), .V_BACK(20)
) u_top (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk), .sd_mosi(sd_mosi),
    .sd_miso(sd_miso), .sd_cs_n(sd_cs_n), .vga_hs(vga_hs), .vga_vs(vga_vs),
    .vga_d(vga_d), .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

// v32: retain v30's NOREG FIFO and commit each valid FIFO word to the line
// RAM one video clock later, after explicitly registering that word locally.
module top_1280x720_linebuf_media_fifo32_sample_v32 (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p
);

top #(
    .VIDEO_W(1280), .VIDEO_H(720), .VIDEO_BURST_WORDS(32),
    .VIDEO_READ_BURST_WORDS(32),
    .VIDEO_MODE_1280(1), .ENABLE_OSD(0), .ENABLE_FADE(0),
    .VIDEO_SEQUENCE(0), .VIDEO_BIN(0), .ADAPTIVE_BMP(1),
    .VIDEO_FRAME_COUNT(2), .SOURCE_W(960), .SOURCE_H(540),
    .LINEBUF_SCALE(1), .LINEBUF_REGISTER_READ(1),
    .LINEBUF_V26_OUTPUT_PIPELINE(1),
    .LINEBUF_FIFO_RESPONSE_REGISTER(1),
    .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_FRONT(5), .V_SYNC(5), .V_BACK(20)
) u_top (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk), .sd_mosi(sd_mosi),
    .sd_miso(sd_miso), .sd_cs_n(sd_cs_n), .vga_hs(vga_hs), .vga_vs(vga_vs),
    .vga_d(vga_d), .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

// v33: retain v32's FIFO response sampling and halve only the SDRAM read
// burst.  A 960-pixel source row is 480 words, so 16 words divides it exactly.
module top_1280x720_linebuf_media_fifo16_sample_v33 (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p
);

top #(
    .VIDEO_W(1280), .VIDEO_H(720), .VIDEO_BURST_WORDS(32),
    .VIDEO_READ_BURST_WORDS(16),
    .VIDEO_MODE_1280(1), .ENABLE_OSD(0), .ENABLE_FADE(0),
    .VIDEO_SEQUENCE(0), .VIDEO_BIN(0), .ADAPTIVE_BMP(1),
    .VIDEO_FRAME_COUNT(2), .SOURCE_W(960), .SOURCE_H(540),
    .LINEBUF_SCALE(1), .LINEBUF_REGISTER_READ(1),
    .LINEBUF_V26_OUTPUT_PIPELINE(1),
    .LINEBUF_FIFO_RESPONSE_REGISTER(1),
    .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_FRONT(5), .V_SYNC(5), .V_BACK(20)
) u_top (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk), .sd_mosi(sd_mosi),
    .sd_miso(sd_miso), .sd_cs_n(sd_cs_n), .vga_hs(vga_hs), .vga_vs(vga_vs),
    .vga_d(vga_d), .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

// v34: 24-word reads retain a 32-word path's throughput margin while making
// each SDRAM read transaction shorter.  The source row is exactly 20 bursts.
module top_1280x720_linebuf_media_fifo24_v34 (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p
);

top #(
    .VIDEO_W(1280), .VIDEO_H(720), .VIDEO_BURST_WORDS(32),
    .VIDEO_READ_BURST_WORDS(24),
    .VIDEO_MODE_1280(1), .ENABLE_OSD(0), .ENABLE_FADE(0),
    .VIDEO_SEQUENCE(0), .VIDEO_BIN(0), .ADAPTIVE_BMP(1),
    .VIDEO_FRAME_COUNT(2), .SOURCE_W(960), .SOURCE_H(540),
    .LINEBUF_SCALE(1), .LINEBUF_REGISTER_READ(1),
    .LINEBUF_V26_OUTPUT_PIPELINE(1),
    .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_FRONT(5), .V_SYNC(5), .V_BACK(20)
) u_top (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk), .sd_mosi(sd_mosi),
    .sd_miso(sd_miso), .sd_cs_n(sd_cs_n), .vga_hs(vga_hs), .vga_vs(vga_vs),
    .vga_d(vga_d), .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

// v35: v30's known full-frame read schedule with the routed official 125 MHz
// SDRAM PLL, replacing only the 25 MHz bandwidth-limited PLL implementation.
module top_1280x720_linebuf_media_fifo32_ref125_v35 (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p
);

top #(
    .VIDEO_W(1280), .VIDEO_H(720), .VIDEO_BURST_WORDS(32),
    .VIDEO_READ_BURST_WORDS(32),
    .VIDEO_MODE_1280(1), .ENABLE_OSD(0), .ENABLE_FADE(0),
    .VIDEO_SEQUENCE(0), .VIDEO_BIN(0), .ADAPTIVE_BMP(1),
    .VIDEO_FRAME_COUNT(2), .SOURCE_W(960), .SOURCE_H(540),
    .LINEBUF_SCALE(1), .LINEBUF_REGISTER_READ(1),
    .LINEBUF_V26_OUTPUT_PIPELINE(1),
    .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_FRONT(5), .V_SYNC(5), .V_BACK(20)
) u_top (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk), .sd_mosi(sd_mosi),
    .sd_miso(sd_miso), .sd_cs_n(sd_cs_n), .vga_hs(vga_hs), .vga_vs(vga_vs),
    .vga_d(vga_d), .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

// v36: v30's 32-word bandwidth, with each SDRAM burst closed only after its
// actual return words arrive rather than after a fixed controller delay.
module top_1280x720_linebuf_media_fifo32_response_v36 (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p
);

top #(
    .VIDEO_W(1280), .VIDEO_H(720), .VIDEO_BURST_WORDS(32),
    .VIDEO_READ_BURST_WORDS(32),
    .VIDEO_MODE_1280(1), .ENABLE_OSD(0), .ENABLE_FADE(0),
    .VIDEO_SEQUENCE(0), .VIDEO_BIN(0), .ADAPTIVE_BMP(1),
    .VIDEO_FRAME_COUNT(2), .SOURCE_W(960), .SOURCE_H(540),
    .LINEBUF_SCALE(1), .LINEBUF_REGISTER_READ(1),
    .LINEBUF_V26_OUTPUT_PIPELINE(1),
    .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_FRONT(5), .V_SYNC(5), .V_BACK(20)
) u_top (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk), .sd_mosi(sd_mosi),
    .sd_miso(sd_miso), .sd_cs_n(sd_cs_n), .vga_hs(vga_hs), .vga_vs(vga_vs),
    .vga_d(vga_d), .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v37: v36 read controller with the SDRAM hard macro sample clock corrected
// to 180 degrees from the 25 MHz controller clock.
module top_1280x720_linebuf_media_fifo32_phase180_v37 (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p
);

top #(
    .VIDEO_W(1280), .VIDEO_H(720), .VIDEO_BURST_WORDS(32),
    .VIDEO_READ_BURST_WORDS(32),
    .VIDEO_MODE_1280(1), .ENABLE_OSD(0), .ENABLE_FADE(0),
    .VIDEO_SEQUENCE(0), .VIDEO_BIN(0), .ADAPTIVE_BMP(1),
    .VIDEO_FRAME_COUNT(2), .SOURCE_W(960), .SOURCE_H(540),
    .LINEBUF_SCALE(1), .LINEBUF_REGISTER_READ(1),
    .LINEBUF_V26_OUTPUT_PIPELINE(1),
    .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_FRONT(5), .V_SYNC(5), .V_BACK(20)
) u_top (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk), .sd_mosi(sd_mosi),
    .sd_miso(sd_miso), .sd_cs_n(sd_cs_n), .vga_hs(vga_hs), .vga_vs(vga_vs),
    .vga_d(vga_d), .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v38: v37's corrected 180-degree SDRAM clock plus deterministic FIFO/video
// reset release after SDRAM initialization.
module top_1280x720_linebuf_media_fifo32_phase180_reset_v38 (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p
);

top #(
    .VIDEO_W(1280), .VIDEO_H(720), .VIDEO_BURST_WORDS(32),
    .VIDEO_READ_BURST_WORDS(32),
    .VIDEO_MODE_1280(1), .ENABLE_OSD(0), .ENABLE_FADE(0),
    .VIDEO_SEQUENCE(0), .VIDEO_BIN(0), .ADAPTIVE_BMP(1),
    .VIDEO_FRAME_COUNT(2), .SOURCE_W(960), .SOURCE_H(540),
    .LINEBUF_SCALE(1), .LINEBUF_REGISTER_READ(1),
    .LINEBUF_V26_OUTPUT_PIPELINE(1),
    .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_FRONT(5), .V_SYNC(5), .V_BACK(20)
) u_top (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk), .sd_mosi(sd_mosi),
    .sd_miso(sd_miso), .sd_cs_n(sd_cs_n), .vga_hs(vga_hs), .vga_vs(vga_vs),
    .vga_d(vga_d), .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v40: IMAGE0.BMP is already 960x540.  Bypass the adaptive BMP scaler and
// its source-row RAM; retain the v39 SDRAM read/reset/phase corrections.
module top_1280x720_linebuf_media_fifo32_directbmp_v40 (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p
);

top #(
    .VIDEO_W(1280), .VIDEO_H(720), .VIDEO_BURST_WORDS(32),
    .VIDEO_READ_BURST_WORDS(32),
    .VIDEO_MODE_1280(1), .ENABLE_OSD(0), .ENABLE_FADE(0),
    .VIDEO_SEQUENCE(0), .VIDEO_BIN(0), .ADAPTIVE_BMP(0),
    .VIDEO_FRAME_COUNT(2), .SOURCE_W(960), .SOURCE_H(540),
    .LINEBUF_SCALE(1), .LINEBUF_REGISTER_READ(1),
    .LINEBUF_V26_OUTPUT_PIPELINE(1),
    .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_FRONT(5), .V_SYNC(5), .V_BACK(20)
) u_top (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk), .sd_mosi(sd_mosi),
    .sd_miso(sd_miso), .sd_cs_n(sd_cs_n), .vga_hs(vga_hs), .vga_vs(vga_vs),
    .vga_d(vga_d), .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v49: same v40 media/FIFO path, with the original board-proven 25 MHz
// SDRAM PLL phase restored for A/B verification.
module top_1280x720_linebuf_media_fifo32_original25_v49 (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p
);

top #(
    .VIDEO_W(1280), .VIDEO_H(720), .VIDEO_BURST_WORDS(32),
    .VIDEO_READ_BURST_WORDS(32),
    .VIDEO_MODE_1280(1), .ENABLE_OSD(0), .ENABLE_FADE(0),
    .VIDEO_SEQUENCE(0), .VIDEO_BIN(0), .ADAPTIVE_BMP(0),
    .VIDEO_FRAME_COUNT(2), .SOURCE_W(960), .SOURCE_H(540),
    .LINEBUF_SCALE(1), .LINEBUF_REGISTER_READ(1),
    .LINEBUF_V26_OUTPUT_PIPELINE(1),
    .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_FRONT(5), .V_SYNC(5), .V_BACK(20)
) u_top (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk), .sd_mosi(sd_mosi),
    .sd_miso(sd_miso), .sd_cs_n(sd_cs_n), .vga_hs(vga_hs), .vga_vs(vga_vs),
    .vga_d(vga_d), .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v50: retain the v40 1280x720 media path but restore the fixed-delay read
// scheduler used by the board-verified 640x480 SDRAM probe.  This is an A/B
// candidate for the read-return timing only; the HDMI timing and line buffer
// parameters remain unchanged.
module top_1280x720_linebuf_media_fifo32_legacyread_v50 (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p
);

top #(
    .VIDEO_W(1280), .VIDEO_H(720), .VIDEO_BURST_WORDS(32),
    .VIDEO_READ_BURST_WORDS(32),
    .VIDEO_MODE_1280(1), .ENABLE_OSD(0), .ENABLE_FADE(0),
    .VIDEO_SEQUENCE(0), .VIDEO_BIN(0), .ADAPTIVE_BMP(0),
    .VIDEO_FRAME_COUNT(2), .SOURCE_W(960), .SOURCE_H(540),
    .LINEBUF_SCALE(1), .LINEBUF_REGISTER_READ(1),
    .LINEBUF_V26_OUTPUT_PIPELINE(1),
    .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_FRONT(5), .V_SYNC(5), .V_BACK(20)
) u_top (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk), .sd_mosi(sd_mosi),
    .sd_miso(sd_miso), .sd_cs_n(sd_cs_n), .vga_hs(vga_hs), .vga_vs(vga_vs),
    .vga_d(vga_d), .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v51: direct 960x540 BMP media path with 128-word SDRAM transactions.
// A 960x540 RGB565 frame is 259200 words, exactly 2025 blocks of 128 words;
// this keeps every frame transaction whole while reducing the transaction
// count substantially versus the 32-word A/B candidates.  The current
// reset-aware/dynamic-return frame store remains in use.
module top_1280x720_linebuf_media_fifo128_v51 (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p
);

top #(
    .VIDEO_W(1280), .VIDEO_H(720), .VIDEO_BURST_WORDS(128),
    .VIDEO_READ_BURST_WORDS(128),
    .VIDEO_MODE_1280(1), .ENABLE_OSD(0), .ENABLE_FADE(0),
    .VIDEO_SEQUENCE(0), .VIDEO_BIN(0), .ADAPTIVE_BMP(0),
    .VIDEO_FRAME_COUNT(2), .SOURCE_W(960), .SOURCE_H(540),
    .LINEBUF_SCALE(1), .LINEBUF_REGISTER_READ(1),
    .LINEBUF_V26_OUTPUT_PIPELINE(1),
    .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_FRONT(5), .V_SYNC(5), .V_BACK(20)
) u_top (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk), .sd_mosi(sd_mosi),
    .sd_miso(sd_miso), .sd_cs_n(sd_cs_n), .vga_hs(vga_hs), .vga_vs(vga_vs),
    .vga_d(vga_d), .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v52: v51's exact 960x540 / 128-word transport, with video timing left
// untouched.  Before a picture is allowed to consume the production read
// FIFO, the matching address-derived diagnostic BMP is read back in full.
// LED4 and the Dxxx display are owned by READBACK_DIAG in this build.
module top_1280x720_linebuf_media_fifo128_v52_diag (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p
);

top #(
    .VIDEO_W(1280), .VIDEO_H(720), .VIDEO_BURST_WORDS(128),
    .VIDEO_READ_BURST_WORDS(128), .VIDEO_MODE_1280(1),
    .ENABLE_OSD(0), .ENABLE_FADE(0), .VIDEO_SEQUENCE(0), .VIDEO_BIN(0),
    .ADAPTIVE_BMP(0), .VIDEO_FRAME_COUNT(2), .SOURCE_W(960), .SOURCE_H(540),
    .LINEBUF_SCALE(1), .LINEBUF_REGISTER_READ(1),
    .LINEBUF_V26_OUTPUT_PIPELINE(1), .READBACK_DIAG(1),
    .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_FRONT(5), .V_SYNC(5), .V_BACK(20)
) u_top (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk), .sd_mosi(sd_mosi),
    .sd_miso(sd_miso), .sd_cs_n(sd_cs_n), .vga_hs(vga_hs), .vga_vs(vga_vs),
    .vga_d(vga_d), .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v53 candidate: native 1280x720 BMP storage and direct RGB565 output.  It
// intentionally contains no scaler and uses 128-word transactions: 640 words
// per line is exactly five bursts; two frames need 921600 of the 21-bit words.
module top_1280x720_media_fifo128_v53_native (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p
);

top #(
    .VIDEO_W(1280), .VIDEO_H(720), .VIDEO_BURST_WORDS(128),
    .VIDEO_READ_BURST_WORDS(128), .VIDEO_MODE_1280(1),
    .ENABLE_OSD(0), .ENABLE_FADE(0), .VIDEO_SEQUENCE(0), .VIDEO_BIN(0),
    .ADAPTIVE_BMP(0), .VIDEO_FRAME_COUNT(2), .SOURCE_W(1280), .SOURCE_H(720),
    .LINEBUF_SCALE(0), .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_FRONT(5), .V_SYNC(5), .V_BACK(20)
) u_top (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk), .sd_mosi(sd_mosi),
    .sd_miso(sd_miso), .sd_cs_n(sd_cs_n), .vga_hs(vga_hs), .vga_vs(vga_vs),
    .vga_d(vga_d), .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

`default_nettype wire
