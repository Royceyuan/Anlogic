`timescale 1ns / 1ps
`default_nettype none

// Standalone 800x600 candidate. Keeping a separate wrapper lets the normal
// top module and the verified 640x480 bitstream remain unchanged.
module top_800x600 (
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
    .VIDEO_W(800),
    .VIDEO_H(600),
    .VIDEO_BURST_WORDS(128),
    .VIDEO_MODE_800(1),
    .ENABLE_OSD(1)
) u_top_800x600 (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw),
    .led(led), .seg_data(seg_data), .seg_sel(seg_sel),
    .sd_clk(sd_clk), .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

// v54: native 4:3 media candidate.  This deliberately keeps the established
// 800x600 HDMI timing but removes every 1280x720-specific stage: the TF BMP
// source, SDRAM frame, and displayed raster are all 800x600.
module top_800x600_native_v54 (
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
    .VIDEO_W(800), .VIDEO_H(600),
    .SOURCE_W(800), .SOURCE_H(600),
    .VIDEO_BURST_WORDS(128), .VIDEO_READ_BURST_WORDS(128),
    .VIDEO_MODE_800(1), .ADAPTIVE_BMP(0), .LINEBUF_SCALE(0),
    .ENABLE_OSD(0), .ENABLE_FADE(0), .VIDEO_SEQUENCE(0), .VIDEO_BIN(0)
) u_top_800x600_native_v54 (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw),
    .led(led), .seg_data(seg_data), .seg_sel(seg_sel),
    .sd_clk(sd_clk), .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

// v56 restores the existing user-facing controls on the hardware-proven v54
// native 800x600 data path.  It does not change SDRAM, FIFO, or HDMI timing.
module top_800x600_feature_v56 (
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
    .VIDEO_W(800), .VIDEO_H(600),
    .SOURCE_W(800), .SOURCE_H(600),
    .VIDEO_BURST_WORDS(100), .VIDEO_READ_BURST_WORDS(128),
    .VIDEO_MODE_800(1), .ADAPTIVE_BMP(0), .LINEBUF_SCALE(0),
    .ENABLE_OSD(1), .ENABLE_FADE(1), .VIDEO_SEQUENCE(0), .VIDEO_BIN(0),
    .VIDEO_FRAME_COUNT(10)
) u_top_800x600_feature_v56 (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw),
    .led(led), .seg_data(seg_data), .seg_sel(seg_sel),
    .sd_clk(sd_clk), .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

// v57: two-image refinement of v56.  The video and SDRAM path are identical;
// only user-facing OSD/input/image-count parameters differ.
module top_800x600_feature_v57 (
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
    .VIDEO_W(800), .VIDEO_H(600),
    .SOURCE_W(800), .SOURCE_H(600),
    .VIDEO_BURST_WORDS(128), .VIDEO_READ_BURST_WORDS(128),
    .VIDEO_MODE_800(1), .ADAPTIVE_BMP(0), .LINEBUF_SCALE(0),
    .ENABLE_OSD(1), .ENABLE_FADE(1), .VIDEO_SEQUENCE(0), .VIDEO_BIN(0),
    .VIDEO_FRAME_COUNT(2), .KEY_DEBOUNCE_BITS(17)
) u_top_800x600_feature_v57 (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw),
    .led(led), .seg_data(seg_data), .seg_sel(seg_sel),
    .sd_clk(sd_clk), .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

// Independent v58 candidate: adaptive 24-bit BMP loading into the same
// verified 800x600 continuous SDRAM/display path as v57.
module top_800x600_feature_v58 (
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
    .VIDEO_W(800), .VIDEO_H(600),
    .SOURCE_W(800), .SOURCE_H(600),
    // 400 words/row is exactly 25 x 16.  This avoids the vendor write FIFO's
    // uncompleted final short transaction, while the verified read path stays
    // at 128 words.
    .VIDEO_BURST_WORDS(128), .VIDEO_WRITE_BURST_WORDS(16),
    .VIDEO_READ_BURST_WORDS(128),
    .VIDEO_MODE_800(1), .ADAPTIVE_BMP(1), .ADAPTIVE_BLOCK_WRITER(0),
    .ENABLE_OSD(1), .ENABLE_FADE(1), .VIDEO_SEQUENCE(0), .VIDEO_BIN(0),
    .VIDEO_FRAME_COUNT(2), .KEY_DEBOUNCE_BITS(17)
) u_top_800x600_adaptive_v58 (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw),
    .led(led), .seg_data(seg_data), .seg_sel(seg_sel),
    .sd_clk(sd_clk), .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

// Independent v58 repair candidate: retain the whole adaptive transport but
// repeat column 797 at columns 798 and 799, avoiding the diagnosed narrow
// active-picture edge corruption without a visible black strip.
module top_800x600_feature_v58_edge_repair (
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
    .VIDEO_W(800), .VIDEO_H(600), .SOURCE_W(800), .SOURCE_H(600),
    .VIDEO_BURST_WORDS(128), .VIDEO_WRITE_BURST_WORDS(16),
    .VIDEO_READ_BURST_WORDS(128), .VIDEO_MODE_800(1),
    .ADAPTIVE_BMP(1), .ADAPTIVE_BLOCK_WRITER(0),
    .ENABLE_OSD(1), .ENABLE_FADE(1), .VIDEO_SEQUENCE(0), .VIDEO_BIN(0),
    .VIDEO_FRAME_COUNT(2), .KEY_DEBOUNCE_BITS(17),
    .RIGHT_EDGE_REPLICATE_COLUMNS(2)
) u_top_800x600_adaptive_v58_edge_repair (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw),
    .led(led), .seg_data(seg_data), .seg_sel(seg_sel),
    .sd_clk(sd_clk), .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

// v59: retain the hardware-verified v58 edge repair, then preload both
// IMAGE0.BMP and IMAGE1.BMP into the two SDRAM frames after reset.  KEY2
// selects the resident frame at a video boundary rather than rereading TF.
module top_800x600_feature_v59_preload (
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
    .VIDEO_W(800), .VIDEO_H(600), .SOURCE_W(800), .SOURCE_H(600),
    .VIDEO_BURST_WORDS(128), .VIDEO_WRITE_BURST_WORDS(16),
    .VIDEO_READ_BURST_WORDS(128), .VIDEO_MODE_800(1),
    .ADAPTIVE_BMP(1), .ADAPTIVE_BLOCK_WRITER(0),
    .ENABLE_OSD(1), .ENABLE_FADE(1), .VIDEO_SEQUENCE(0), .VIDEO_BIN(0),
    .PRELOAD_BOTH_IMAGES(1), .VIDEO_FRAME_COUNT(2), .KEY_DEBOUNCE_BITS(17),
    .RIGHT_EDGE_REPLICATE_COLUMNS(2)
) u_top_800x600_adaptive_v59_preload (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw),
    .led(led), .seg_data(seg_data), .seg_sel(seg_sel),
    .sd_clk(sd_clk), .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

// v60: retain v59's two-frame preload and edge repair while admitting
// 24-bit, uncompressed adaptive BMP inputs up to 1920x1080.  The output
// raster remains the verified 800x600 proportional nearest-neighbour fit.
module top_800x600_feature_v60_1080p (
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
    .VIDEO_W(800), .VIDEO_H(600), .SOURCE_W(800), .SOURCE_H(600),
    .VIDEO_BURST_WORDS(128), .VIDEO_WRITE_BURST_WORDS(16),
    .VIDEO_READ_BURST_WORDS(128), .VIDEO_MODE_800(1),
    .ADAPTIVE_BMP(1), .ADAPTIVE_BMP_MAX_WIDTH(1920),
    .ADAPTIVE_BMP_MAX_HEIGHT(1080), .ADAPTIVE_BLOCK_WRITER(0),
    .ENABLE_OSD(1), .ENABLE_FADE(1), .VIDEO_SEQUENCE(0), .VIDEO_BIN(0),
    .PRELOAD_BOTH_IMAGES(1), .VIDEO_FRAME_COUNT(2), .KEY_DEBOUNCE_BITS(17),
    .RIGHT_EDGE_REPLICATE_COLUMNS(2)
) u_top_800x600_adaptive_v60_1080p (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw),
    .led(led), .seg_data(seg_data), .seg_sel(seg_sel),
    .sd_clk(sd_clk), .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

// v61: ten-image adaptive-BMP candidate. It keeps v60's 1920x1080 input
// limit, proportional 800x600 fit, edge repair and frame-boundary publish,
// while reloading IMAGE0.BMP through IMAGE9.BMP on KEY2/automatic advance.
// v60 remains the release baseline until this candidate passes its own gate.
module top_800x600_feature_v61_1080p_multi (
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
    .VIDEO_W(800), .VIDEO_H(600), .SOURCE_W(800), .SOURCE_H(600),
    .VIDEO_BURST_WORDS(128), .VIDEO_WRITE_BURST_WORDS(16),
    .VIDEO_READ_BURST_WORDS(128), .VIDEO_MODE_800(1),
    .ADAPTIVE_BMP(1), .ADAPTIVE_BMP_MAX_WIDTH(1920),
    .ADAPTIVE_BMP_MAX_HEIGHT(1080), .ADAPTIVE_BLOCK_WRITER(0),
    .ENABLE_OSD(1), .ENABLE_FADE(1), .VIDEO_SEQUENCE(0), .VIDEO_BIN(0),
    .PRELOAD_BOTH_IMAGES(0), .MULTI_IMAGE_BMP(1),
    .VIDEO_FRAME_COUNT(10), .KEY_DEBOUNCE_BITS(17),
    .RIGHT_EDGE_REPLICATE_COLUMNS(2)
) u_top_800x600_adaptive_v61_1080p_multi (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw),
    .led(led), .seg_data(seg_data), .seg_sel(seg_sel),
    .sd_clk(sd_clk), .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

// v62: five-image fast-carousel candidate. The five source frames are loaded
// once into independent SDRAM regions during startup; KEY2 then switches only
// at a video-frame boundary without another TF-card transfer.
module top_800x600_feature_v62_1080p_multi5 (
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
    .VIDEO_W(800), .VIDEO_H(600), .SOURCE_W(800), .SOURCE_H(600),
    .VIDEO_BURST_WORDS(128), .VIDEO_WRITE_BURST_WORDS(16),
    .VIDEO_READ_BURST_WORDS(128), .VIDEO_MODE_800(1),
    .ADAPTIVE_BMP(1), .ADAPTIVE_BMP_MAX_WIDTH(1920),
    .ADAPTIVE_BMP_MAX_HEIGHT(1080), .ADAPTIVE_BLOCK_WRITER(0),
    .ENABLE_OSD(1), .ENABLE_FADE(1), .VIDEO_SEQUENCE(0), .VIDEO_BIN(0),
    .PRELOAD_BOTH_IMAGES(0), .MULTI_IMAGE_BMP(1),
    .MULTI_FRAME_PRELOAD(1), .VIDEO_FRAME_COUNT(5), .KEY_DEBOUNCE_BITS(17),
    .RIGHT_EDGE_REPLICATE_COLUMNS(2)
) u_top_800x600_adaptive_v62_1080p_multi5 (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw),
    .led(led), .seg_data(seg_data), .seg_sel(seg_sel),
    .sd_clk(sd_clk), .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

// v63: v62 five-image fast carousel with the original BMP dimensions shown
// in the 800x600 OSD as DIM WxxxXHxxx.
module top_800x600_feature_v63_1080p_multi5_osd_dim (
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
    .VIDEO_W(800), .VIDEO_H(600), .SOURCE_W(800), .SOURCE_H(600),
    .VIDEO_BURST_WORDS(128), .VIDEO_WRITE_BURST_WORDS(16),
    .VIDEO_READ_BURST_WORDS(128), .VIDEO_MODE_800(1),
    .ADAPTIVE_BMP(1), .ADAPTIVE_BMP_MAX_WIDTH(1920),
    .ADAPTIVE_BMP_MAX_HEIGHT(1080), .ADAPTIVE_BLOCK_WRITER(0),
    .ENABLE_OSD(1), .ENABLE_FADE(1), .VIDEO_SEQUENCE(0), .VIDEO_BIN(0),
    .PRELOAD_BOTH_IMAGES(0), .MULTI_IMAGE_BMP(1),
    .MULTI_FRAME_PRELOAD(1), .VIDEO_FRAME_COUNT(5), .KEY_DEBOUNCE_BITS(17),
    .RIGHT_EDGE_REPLICATE_COLUMNS(2)
) u_top_800x600_adaptive_v63_1080p_multi5_osd_dim (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw),
    .led(led), .seg_data(seg_data), .seg_sel(seg_sel),
    .sd_clk(sd_clk), .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

// v64: v63 carousel with compact, right-shifted source-dimension OSD.
module top_800x600_feature_v64_1080p_multi5_osd_dim (
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
    .VIDEO_W(800), .VIDEO_H(600), .SOURCE_W(800), .SOURCE_H(600),
    .VIDEO_BURST_WORDS(128), .VIDEO_WRITE_BURST_WORDS(16),
    .VIDEO_READ_BURST_WORDS(128), .VIDEO_MODE_800(1),
    .ADAPTIVE_BMP(1), .ADAPTIVE_BMP_MAX_WIDTH(1920),
    .ADAPTIVE_BMP_MAX_HEIGHT(1080), .ADAPTIVE_BLOCK_WRITER(0),
    .ENABLE_OSD(1), .ENABLE_FADE(1), .VIDEO_SEQUENCE(0), .VIDEO_BIN(0),
    .PRELOAD_BOTH_IMAGES(0), .MULTI_IMAGE_BMP(1),
    .MULTI_FRAME_PRELOAD(1), .VIDEO_FRAME_COUNT(5), .KEY_DEBOUNCE_BITS(17),
    .RIGHT_EDGE_REPLICATE_COLUMNS(2)
) u_top_800x600_adaptive_v64_1080p_multi5_osd_dim (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw),
    .led(led), .seg_data(seg_data), .seg_sel(seg_sel),
    .sd_clk(sd_clk), .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

// Diagnostic v58 variant: it only blacks the final 16 active pixels after
// the image pipeline.  This distinguishes a bad frame pixel from a spurious
// HDMI pixel outside the 800-pixel DE window; v58 itself is not modified.
module top_800x600_feature_v58_edge_probe (
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
    .VIDEO_W(800), .VIDEO_H(600), .SOURCE_W(800), .SOURCE_H(600),
    .VIDEO_BURST_WORDS(128), .VIDEO_WRITE_BURST_WORDS(16),
    .VIDEO_READ_BURST_WORDS(128), .VIDEO_MODE_800(1),
    .ADAPTIVE_BMP(1), .ADAPTIVE_BLOCK_WRITER(0),
    .ENABLE_OSD(1), .ENABLE_FADE(1), .VIDEO_SEQUENCE(0), .VIDEO_BIN(0),
    .VIDEO_FRAME_COUNT(2), .KEY_DEBOUNCE_BITS(17),
    .RIGHT_EDGE_MASK_COLUMNS(16)
) u_top_800x600_adaptive_v58_edge_probe (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw),
    .led(led), .seg_data(seg_data), .seg_sel(seg_sel),
    .sd_clk(sd_clk), .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

// v65: v64 five-image carousel with selectable switch-controlled transitions.
module top_800x600_feature_v65_1080p_multi5_transition (
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
    .VIDEO_W(800), .VIDEO_H(600), .SOURCE_W(800), .SOURCE_H(600),
    .VIDEO_BURST_WORDS(128), .VIDEO_WRITE_BURST_WORDS(16),
    .VIDEO_READ_BURST_WORDS(128), .VIDEO_MODE_800(1),
    .ADAPTIVE_BMP(1), .ADAPTIVE_BMP_MAX_WIDTH(1920),
    .ADAPTIVE_BMP_MAX_HEIGHT(1080), .ADAPTIVE_BLOCK_WRITER(0),
    .ENABLE_OSD(1), .ENABLE_FADE(1), .VIDEO_SEQUENCE(0), .VIDEO_BIN(0),
    .PRELOAD_BOTH_IMAGES(0), .MULTI_IMAGE_BMP(1),
    .MULTI_FRAME_PRELOAD(1), .VIDEO_FRAME_COUNT(5), .KEY_DEBOUNCE_BITS(17),
    .RIGHT_EDGE_REPLICATE_COLUMNS(2)
) u_top_800x600_adaptive_v65_1080p_multi5_transition (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw),
    .led(led), .seg_data(seg_data), .seg_sel(seg_sel),
    .sd_clk(sd_clk), .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);

endmodule

`default_nettype wire
