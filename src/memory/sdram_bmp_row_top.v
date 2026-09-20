`timescale 1ns / 1ps
`default_nettype none

// Independent candidate for the official media path:
// FAT32 -> BMP or RGB565 BIN -> row-addressed SDRAM -> HDMI.
// VIDEO_BIN selects the raw RGB565 path without changing the stable BMP path.
module top #(
    parameter integer VIDEO_W = 640,
    parameter integer VIDEO_H = 480,
    parameter integer VIDEO_BURST_WORDS = 256,
    // Keep write burst sizing independent so an adaptive row writer can use
    // an exact row divisor without changing the verified video read path.
    parameter integer VIDEO_WRITE_BURST_WORDS = VIDEO_BURST_WORDS,
    parameter integer VIDEO_READ_BURST_WORDS = 64,
    parameter VIDEO_READ_FIFO_OUTREG = "NOREG",
    // Diagnostic only: after all image processing, mask this many pixels at
    // the right edge of each active line.  Zero preserves normal output.
    parameter integer RIGHT_EDGE_MASK_COLUMNS = 0,
    // Board repair candidate: repeat the preceding good pixel over a narrow
    // right-edge corruption region.  Zero preserves normal output.
    parameter integer RIGHT_EDGE_REPLICATE_COLUMNS = 0,
    parameter integer VIDEO_MODE_800 = 0,
    parameter integer VIDEO_MODE_1024 = 0,
    parameter integer VIDEO_MODE_1280 = 0,
    parameter integer ENABLE_OSD = 0,
    parameter integer ENABLE_FADE = 0,
    parameter integer VIDEO_SEQUENCE = 0,
    parameter integer VIDEO_BIN = 0,
    parameter integer ADAPTIVE_BMP = 0,
    // Input-image admission limit for adaptive BMP.  The v59-safe defaults
    // preserve the established 1280x720 range; larger candidates must remain
    // within the 2048-pixel adaptive row RAM/FIFO depth.
    parameter integer ADAPTIVE_BMP_MAX_WIDTH = 1280,
    parameter integer ADAPTIVE_BMP_MAX_HEIGHT = 720,
    // Adaptive BMP can use the continuous block writer only when its input
    // stream is already raster ordered; the row writer is the safe default
    // for both top-down and bottom-up BMP orientation.
    parameter integer ADAPTIVE_BLOCK_WRITER = 0,
    // v59 candidate: load IMAGE0 first, then fill the unused second SDRAM
    // frame with IMAGE1.  KEY2 then selects an already valid frame instead
    // of starting another TF-card transfer.  Disabled by default so existing
    // tops retain their exact load-and-publish behavior.
    parameter integer PRELOAD_BOTH_IMAGES = 0,
    // v61 candidate: pass the complete IMAGE0..IMAGE9 index to the FAT32
    // short-name matcher. Zero preserves the v60 two-image wiring exactly.
    parameter integer MULTI_IMAGE_BMP = 0,
    // v62 candidate: keep up to five complete frames in separate SDRAM
    // regions so KEY2 can switch among cached images at a frame boundary.
    parameter integer MULTI_FRAME_PRELOAD = 0,
    parameter integer VIDEO_FRAME_COUNT = 10,
    parameter integer KEY_DEBOUNCE_BITS = 19,
    parameter integer SOURCE_W = VIDEO_W,
    parameter integer SOURCE_H = VIDEO_H,
    parameter integer LINEBUF_SCALE = 0,
    parameter integer LINEBUF_REGISTER_READ = 0,
    parameter integer LINEBUF_V26_OUTPUT_PIPELINE = 0,
    parameter integer LINEBUF_FIFO_RESPONSE_REGISTER = 0,
    // v52 only: read the just-written diagnostic frame back through the
    // production SDRAM/FIFO path before enabling normal video consumption.
    parameter integer READBACK_DIAG = 0,
    parameter integer H_FRONT = 16,
    parameter integer H_SYNC = 96,
    parameter integer H_BACK = 48,
    parameter integer V_FRONT = 10,
    parameter integer V_SYNC = 2,
    parameter integer V_BACK = 33
) (
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

localparam integer FRAME_WORDS = (SOURCE_W * SOURCE_H) / 2;
localparam [20:0] FRAME0_BASE  = 21'd0;
localparam [20:0] FRAME1_BASE  = FRAME_WORDS;
localparam [20:0] FRAME_LENGTH = FRAME_WORDS;

wire mem_clk;
wire mem_clk_sft;
wire video_clk;
wire video_clk_5x;
wire mem_rst_n;
wire video_rst_n;
wire init_done;
wire init_ref_valid;
wire mem_busy;
wire write_rst_n;

wire sd_init_done;
wire sd_sec_read;
wire [31:0] sd_sec_read_addr;
wire [7:0] sd_sec_read_data;
wire sd_sec_read_data_valid;
wire sd_sec_read_end;
reg image_load_start;
reg writer_start;
reg load_active;
reg load_reported;
reg writer_done_seen;
reg loader_done_seen;
reg writer_done_clear_seen;
reg loader_done_clear_seen;
reg [3:0] load_image_index;
reg [3:0] load_media_index;
reg [3:0] active_media_index;
reg [3:0] published_media_index;
reg load_frame_index;
reg [3:0] active_image_index;
reg published_frame_index;
reg [3:0] manual_image_index;
reg [1:0] brightness_level;
reg [1:0] contrast_level;
reg auto_mode_d;
reg [3:0] auto_image_index;
reg [27:0] auto_period_count;
reg [24:0] sequence_hold_count;
reg sequence_hold_done;
reg [4:0] frame_valid;
reg initial_frame_published;
reg preload_select_frame_index;
reg [15:0] frame_source_width_bcd [0:4];
reg [15:0] frame_source_height_bcd [0:4];
reg [15:0] published_source_width_bcd;
reg [15:0] published_source_height_bcd;
reg [15:0] preload_select_source_width_bcd;
reg [15:0] preload_select_source_height_bcd;

// SW4 enables a slow carousel. A new image is requested only after the
// previous frame has been published, so the active frame remains intact
// while the next BMP is read from the card.
localparam integer AUTO_PERIOD_CYCLES = 250_000_000;
// The TF transfer itself takes most of a second. Add a short dwell so the
// completed frame remains visible for about one second in total.
localparam integer SEQUENCE_HOLD_CYCLES = 25_000_000;

wire image_wr_en;
wire [20:0] image_wr_addr;
wire [15:0] image_wr_data;
wire [10:0] image_wr_row;
wire [10:0] image_wr_col;
wire image_load_busy;
wire image_load_done;
wire image_load_error;
wire [3:0] image_load_status;
wire [15:0] image_source_width;
wire [15:0] image_source_height;

wire row_valid;
wire [10:0] row_index;
wire [15:0] row_pixel;
wire row_last;
wire row_ready;
wire row_overflow;
wire row_input_continue;
wire bmp_row_input_continue;
wire bin_sector_continue;

wire write_req;
wire write_req_ack;
wire write_finish;
wire write_fifo_full;
wire write_en;
wire [31:0] write_data;
wire [20:0] write_base_addr;
wire [20:0] write_len;
wire [20:0] write_frame_base_addr;
wire frame_done;
wire writer_error;

wire [31:0] read_data;
wire video_read_req;
wire video_read_req_ack;
wire video_read_finish;
wire read_fifo_empty;
wire read_fifo_valid;
wire read_en;
wire video_read_en;
wire video_frame_tick;
wire video_vblank_start;
wire video_frame_start;
wire video_hs_i;
wire video_vs_i;
wire video_de_i;
wire [10:0] video_x_i;
wire [9:0] video_y_i;
wire video_hs;
wire video_vs;
wire video_de;
wire [23:0] video_rgb;
wire [23:0] video_adjusted_rgb;
wire [23:0] video_osd_rgb;
wire [23:0] video_faded_rgb;
wire [23:0] video_transition_rgb;
wire [23:0] video_osd_1280_rgb;
wire [23:0] video_output_rgb;
wire        video_hs_out;
wire        video_vs_out;
wire        video_de_out;
wire [23:0] video_rgb_out;
wire [10:0] video_x_delayed;
wire [9:0] video_y_delayed;
wire [23:0] unpacked_rgb;
wire [23:0] linebuf_rgb;
wire [15:0] linebuf_pixel565;
// video_delay delays HS/VS/DE by 20 clocks. Keep the line-buffer pixel on
// the same latency so the visible pixel and raster position remain aligned.
// Registered BRAM output is consumed one clock later in the source path, so
// it uses a 20-word pipe while the legacy NOREG path remains at 19 words.
reg  [303:0] linebuf_pixel565_pipe;
reg  [319:0] linebuf_pixel565_pipe_reg;
wire linebuf_source_start;
wire linebuf_source_read_req;
wire linebuf_source_read_ack;
wire [20:0] linebuf_source_read_base_addr;
wire [20:0] linebuf_source_read_len;
wire linebuf_source_read_en;
wire linebuf_frame_ready;
wire linebuf_source_frame_done;
wire linebuf_underflow;
wire linebuf_video_read_en;
wire [3:0] desired_image_index;
wire auto_mode;
wire [3:0] desired_media_index;
wire manual_image_pending;
wire load_request_pending;
localparam integer ENABLE_DUAL_FRAME_PRELOAD =
    PRELOAD_BOTH_IMAGES && !VIDEO_SEQUENCE && (VIDEO_FRAME_COUNT == 2);
localparam integer ENABLE_MULTI_FRAME_PRELOAD =
    MULTI_FRAME_PRELOAD && !VIDEO_SEQUENCE && (VIDEO_FRAME_COUNT <= 5);
localparam integer ENABLE_CACHED_PRELOAD =
    ENABLE_DUAL_FRAME_PRELOAD || ENABLE_MULTI_FRAME_PRELOAD;
wire preload_load_frame_index = !load_reported ? 1'b0 :
                                      (frame_valid[0] ? 1'b1 : 1'b0);
function [3:0] first_invalid_cached_index;
    input [4:0] valid;
    integer i;
    reg found;
    begin
        first_invalid_cached_index = 4'd0;
        found = 1'b0;
        for (i = 0; i < 5; i = i + 1) begin
            if (!found && !valid[i]) begin
                first_invalid_cached_index = i;
                found = 1'b1;
            end
        end
    end
endfunction
wire [3:0] load_start_image_index = ENABLE_MULTI_FRAME_PRELOAD ?
                                      first_invalid_cached_index(frame_valid) :
                                      (ENABLE_DUAL_FRAME_PRELOAD ?
                                       {3'd0, preload_load_frame_index} :
                                       desired_image_index);
wire [3:0] load_start_media_index = ENABLE_MULTI_FRAME_PRELOAD ?
                                      load_start_image_index :
                                      (ENABLE_DUAL_FRAME_PRELOAD ?
                                       {3'd0, preload_load_frame_index} :
                                       desired_media_index);

reg frame_ready_toggle;
reg [25:0] heartbeat_count;
reg ready_ff1;
reg ready_ff2;
reg ready_seen;
reg read_req_r;
reg linebuf_start_pulse;
reg linebuf_start_pending;
reg read_ack_ff1;
reg read_ack_ff2;
reg read_accepted;
reg read_ready;
reg video_run;
reg pair_phase;
reg pair_word_valid;
reg underflow_seen;
reg [11:0] read_prefill_count;
reg [3:0] status_code;
reg [230:0] video_x_pipe;
reg [209:0] video_y_pipe;
reg [23:0] video_right_edge_pixel;
reg published_frame_ff1;
reg published_frame_ff2;
reg [3:0] published_media_ff1;
reg [3:0] published_media_ff2;
reg [15:0] published_source_width_ff1;
reg [15:0] published_source_width_ff2;
reg [15:0] published_source_height_ff1;
reg [15:0] published_source_height_ff2;
reg preload_select_ff1;
reg preload_select_ff2;
reg [3:0] preload_select_media_index;
reg [3:0] preload_select_media_ff1;
reg [3:0] preload_select_media_ff2;
reg [15:0] preload_select_source_width_ff1;
reg [15:0] preload_select_source_width_ff2;
reg [15:0] preload_select_source_height_ff1;
reg [15:0] preload_select_source_height_ff2;
reg pending_frame_index;
reg [3:0] pending_media_index;
reg [15:0] pending_source_width_bcd;
reg [15:0] pending_source_height_bcd;
reg display_frame_index;
reg [3:0] display_media_index;
reg [15:0] display_source_width_bcd;
reg [15:0] display_source_height_bcd;
reg switch_pending;
reg auto_mode_ff1;
reg auto_mode_ff2;
reg [2:0] transition_mode_ff1;
reg [2:0] transition_mode_ff2;
reg [2:0] transition_mode;
reg [5:0] transition_progress;
reg [4:0] fade_level;
reg fade_out_active;
reg [1:0] brightness_level_ff1;
reg [1:0] brightness_level_ff2;
reg [1:0] contrast_level_ff1;
reg [1:0] contrast_level_ff2;
reg diag_ready_seen;
wire diag_start;
wire diag_read_req;
wire diag_read_en;
wire diag_active;
wire diag_done;
wire diag_pass;
wire diag_fail;
wire [20:0] diag_first_error_addr;
wire [31:0] diag_first_error_actual;
wire [31:0] diag_first_error_expected;
wire [15:0] normal_seg_value;
wire [15:0] diag_seg_value;

wire [3:0] key_press_pulse;

// Keep the last registered column addressed through horizontal blanking.  It
// remains available for the one boundary cycle where the 20-clock DE path
// outlives video_delay's data-valid pulse; blanking itself is still masked.
wire [10:0] linebuf_video_x =
    LINEBUF_REGISTER_READ ?
        (!video_de_i ?
            (LINEBUF_V26_OUTPUT_PIPELINE ? 11'd0 : VIDEO_W - 1) :
            video_x_i) :
        video_x_i;

assign auto_mode = sw[3];
assign desired_image_index = VIDEO_SEQUENCE ?
                             (auto_mode ? active_media_index : manual_image_index) :
                             (auto_mode ? auto_image_index : manual_image_index);
assign desired_media_index = VIDEO_SEQUENCE ? desired_image_index :
                             {3'd0, desired_image_index};
assign manual_image_pending = !auto_mode &&
                              (desired_media_index != published_media_index);
assign load_request_pending = ENABLE_MULTI_FRAME_PRELOAD ?
                              (frame_valid != 5'b11111) :
                             (ENABLE_DUAL_FRAME_PRELOAD ?
                              (frame_valid != 2'b11) :
                              ((!VIDEO_SEQUENCE &&
                               (desired_image_index != active_image_index)) ||
                              (VIDEO_SEQUENCE &&
                               (manual_image_pending ||
                                (auto_mode && sequence_hold_done)))));

function [20:0] frame_base_for_index;
    input [3:0] index;
    begin
        frame_base_for_index = index * FRAME_WORDS;
    end
endfunction

// Convert the parsed binary dimension once per loaded frame.  Keeping BCD in
// the memory clock domain avoids a divider on the 40 MHz pixel/OSD path.
function [15:0] binary_to_bcd4;
    input [15:0] value;
    integer i;
    reg [31:0] shift;
    begin
        shift = {16'd0, value};
        for (i = 0; i < 16; i = i + 1) begin
            if (shift[19:16] >= 4'd5) shift[19:16] = shift[19:16] + 4'd3;
            if (shift[23:20] >= 4'd5) shift[23:20] = shift[23:20] + 4'd3;
            if (shift[27:24] >= 4'd5) shift[27:24] = shift[27:24] + 4'd3;
            if (shift[31:28] >= 4'd5) shift[31:28] = shift[31:28] + 4'd3;
            shift = shift << 1;
        end
        binary_to_bcd4 = shift[31:16];
    end
endfunction

// Keep the target frame fixed for the entire load transaction.  The active
// load registers are already latched before the first row can arrive.
assign write_frame_base_addr = ENABLE_MULTI_FRAME_PRELOAD ?
                                frame_base_for_index(load_active ?
                                                     load_image_index :
                                                     load_start_image_index) :
                               ((VIDEO_SEQUENCE ?
                                 (load_active ? load_frame_index : ~published_frame_index) :
                                 (load_active ? load_frame_index : load_start_image_index[0])) ?
                                 FRAME1_BASE : FRAME0_BASE);

function [23:0] expand_pixel565;
    input [15:0] pixel;
    begin
        expand_pixel565 = {
            {pixel[15:11], pixel[15:13]},
            {pixel[10:5],  pixel[10:9]},
            {pixel[4:0],   pixel[4:2]}
        };
    end
endfunction

// The asynchronous FIFO presents the newly requested word one video clock
// after the request.  Consequently pair_phase=1 is the first visible half of
// that word.  The writer stores the first pixel in [31:16], so keep the
// original raster order here: high half first, low half second.
assign unpacked_rgb = LINEBUF_SCALE ?
                      expand_pixel565(LINEBUF_REGISTER_READ ?
                                       (LINEBUF_V26_OUTPUT_PIPELINE ?
                                        linebuf_pixel565_pipe[303:288] :
                                        linebuf_pixel565_pipe_reg[319:304]) :
                                       linebuf_pixel565_pipe[303:288]) :
                      (pair_word_valid ?
                       (pair_phase ? expand_pixel565(read_data[31:16])
                                    : expand_pixel565(read_data[15:0])) :
                       24'h000000);
assign video_read_req = READBACK_DIAG ? diag_read_req :
                        (LINEBUF_SCALE ? linebuf_source_read_req : read_req_r);
assign read_en = READBACK_DIAG ? diag_read_en :
                 (LINEBUF_SCALE ? linebuf_source_read_en :
                  (video_read_en && video_run && !pair_phase));
assign video_x_delayed = video_x_pipe[230:220];
assign video_y_delayed = video_y_pipe[209:200];
// Switch after the 20-clock video pipeline has drained the last visible
// pixel. The next frame has enough vertical blanking time to refill the FIFO.
assign video_vblank_start = !video_de_i &&
                            (video_x_i == VIDEO_W + 20 - 1) &&
                            (video_y_i == VIDEO_H - 1);
assign video_frame_start = (video_x_i == 0) && (video_y_i == 0);

reset_sync u_mem_reset_sync (
    .clk(mem_clk), .arst_n(key_n[0]), .srst_n(mem_rst_n)
);

key_debounce #(
    .DEBOUNCE_BITS    (KEY_DEBOUNCE_BITS)
) u_key_debounce (
    .clk              (clk_50m),
    .rst_n            (write_rst_n),
    .key_n            (key_n),
    .key_level_n      (),
    .key_press_pulse  (key_press_pulse),
    .key_release_pulse()
);

reset_sync u_write_reset_sync (
    .clk(clk_50m), .arst_n(key_n[0]), .srst_n(write_rst_n)
);

reset_sync u_video_reset_sync (
    // Keep the video/FIFO read side quiescent until the SDRAM controller has
    // completed its own initialization after each board reset.
    .clk(video_clk), .arst_n(key_n[0] && init_done), .srst_n(video_rst_n)
);

sys_pll u_sys_pll (
    .refclk(clk_50m), .reset(1'b0),
    .clk0_out(), .clk1_out(mem_clk), .clk2_out(mem_clk_sft)
);

generate
    if (VIDEO_MODE_1280) begin : g_video_pll_1280
        video_pll_75m u_video_pll (
            .refclk(clk_50m), .reset(~mem_rst_n),
            .clk0_out(video_clk), .clk1_out(video_clk_5x)
        );
    end else if (VIDEO_MODE_1024) begin : g_video_pll_1024
        video_pll_65m u_video_pll (
            .refclk(clk_50m), .reset(~mem_rst_n),
            .clk0_out(video_clk), .clk1_out(video_clk_5x)
        );
    end else if (VIDEO_MODE_800) begin : g_video_pll_800
        video_pll_40m u_video_pll (
            .refclk(clk_50m), .reset(~mem_rst_n),
            .clk0_out(video_clk), .clk1_out(video_clk_5x)
        );
    end else begin : g_video_pll_640
        video_pll u_video_pll (
            .refclk(clk_50m), .reset(~mem_rst_n),
            .clk0_out(video_clk), .clk1_out(video_clk_5x)
        );
    end
endgenerate

// Keep this mux after OSD/fade and before the HDMI encoder so a diagnostic
// bit can distinguish an active-video data error from pixels beyond DE.
assign video_output_rgb = (RIGHT_EDGE_MASK_COLUMNS != 0 && video_de &&
                           (video_x_delayed >= VIDEO_W - RIGHT_EDGE_MASK_COLUMNS)) ?
                          24'h000000 :
                          ((RIGHT_EDGE_REPLICATE_COLUMNS != 0 && video_de &&
                            (video_x_delayed >= VIDEO_W - RIGHT_EDGE_REPLICATE_COLUMNS)) ?
                           video_right_edge_pixel : video_osd_rgb);

sd_card_top u_sd_card_top (
    .clk(clk_50m), .rst(~write_rst_n),
    .SD_nCS(sd_cs_n), .SD_DCLK(sd_clk), .SD_MOSI(sd_mosi), .SD_MISO(sd_miso),
    .sd_init_done(sd_init_done), .sd_sec_read(sd_sec_read),
    .sd_sec_read_addr(sd_sec_read_addr), .sd_sec_read_data(sd_sec_read_data),
    .sd_sec_read_data_valid(sd_sec_read_data_valid),
    .sd_sec_read_end(sd_sec_read_end),
    .sd_sec_write(1'b0), .sd_sec_write_addr(32'd0),
    .sd_sec_write_data(8'd0), .sd_sec_write_data_req(), .sd_sec_write_end()
);

fat32_image_loader #(
    .IMAGE_WIDTH(SOURCE_W), .IMAGE_HEIGHT(SOURCE_H), .IMAGE_ADDR_BITS(21),
    .BMP_MAX_WIDTH(ADAPTIVE_BMP ? ADAPTIVE_BMP_MAX_WIDTH :
                   (VIDEO_MODE_1280 ? 1280 : 1024)),
    .BMP_MAX_HEIGHT(ADAPTIVE_BMP ? ADAPTIVE_BMP_MAX_HEIGHT :
                    (VIDEO_MODE_1280 ? 720 : 768)),
    .ADAPTIVE_BMP(ADAPTIVE_BMP),
    .MULTI_IMAGE_BMP(MULTI_IMAGE_BMP)
) u_fat32_image_loader (
    .clk(clk_50m), .rst_n(write_rst_n), .load_start(image_load_start),
    // On the exact start edge load_active is still low, so use the physical
    // switch for the new transaction; afterward keep the latched selection.
    .image_file_index(VIDEO_SEQUENCE ?
                      (load_active ? load_media_index : desired_media_index) :
                      (MULTI_IMAGE_BMP ?
                       (load_active ? load_image_index : load_start_image_index) :
                       {3'd0, (load_active ? load_image_index : load_start_image_index[0])})),
    .museum_detail_mode(1'b0),
    .museum_artifact_index(3'd0),
    .museum_detail_index(2'd0),
    .bmp_mode(VIDEO_BIN ? 1'b0 : 1'b1),
    .sequence_mode(VIDEO_SEQUENCE != 0),
    .sd_init_done(sd_init_done), .sd_sec_read(sd_sec_read),
    .sd_sec_read_addr(sd_sec_read_addr), .sd_sec_read_data(sd_sec_read_data),
    .sd_sec_read_data_valid(sd_sec_read_data_valid),
    .sd_sec_read_end(sd_sec_read_end),
    .image_continue(row_input_continue),
    .image_wr_en(image_wr_en), .image_wr_addr(image_wr_addr),
    .image_wr_data(image_wr_data), .image_wr_row(image_wr_row),
    .image_wr_col(image_wr_col), .busy(image_load_busy),
    .load_done(image_load_done), .load_error(image_load_error),
    .status_code(image_load_status),
    .bmp_source_width(image_source_width),
    .bmp_source_height(image_source_height)
);

assign row_input_continue = VIDEO_BIN ? bin_sector_continue :
                            bmp_row_input_continue;

generate
    if (!VIDEO_BIN) begin : g_bmp_row_input
        bmp_row_buffer #(
            .WIDTH(SOURCE_W), .HEIGHT(SOURCE_H), .COL_BITS(11), .ROW_BITS(11)
        ) u_bmp_row_buffer (
            .clk(clk_50m), .rst_n(write_rst_n), .in_valid(image_wr_en),
            .in_row(image_wr_row[10:0]), .in_col(image_wr_col[10:0]),
            .in_pixel(image_wr_data), .overflow(row_overflow),
            .out_valid(row_valid), .out_row(row_index), .out_pixel(row_pixel),
            .out_last(row_last), .out_ready(row_ready), .out_row_done(),
            .input_continue(bmp_row_input_continue)
        );
    end else begin : g_bin_direct_input
        // BIN pixels are already a linear raster. Skip the BMP row reorder
        // buffer; the block writer gates the next SD sector instead.
        assign row_valid = image_wr_en;
        assign row_index = 11'd0;
        assign row_pixel = image_wr_data;
        assign row_last = 1'b0;
        assign row_overflow = 1'b0;
        assign bmp_row_input_continue = 1'b0;
    end
endgenerate

generate
    if (ADAPTIVE_BMP && !ADAPTIVE_BLOCK_WRITER) begin : g_adaptive_row_writer
        bmp_sdram_row_writer #(
            .WIDTH(SOURCE_W), .HEIGHT(SOURCE_H), .ROW_BITS(11), .ADDR_BITS(21),
            .WORDS_PER_ROW(SOURCE_W / 2), .BURST_WORDS(VIDEO_WRITE_BURST_WORDS)
        ) u_bmp_sdram_row_writer (
            .clk(clk_50m), .rst_n(write_rst_n),
            .start(writer_start),
            .row_valid(row_valid), .row_index(row_index),
            .row_pixel(row_pixel), .row_last(row_last), .row_ready(row_ready),
            .frame_base_addr(write_frame_base_addr),
            .overview_base_addr(21'd0), .overview_frame_index(4'd0),
            .write_req(write_req), .write_req_ack(write_req_ack),
            .write_en(write_en), .write_data(write_data),
            .write_base_addr(write_base_addr), .write_len(write_len),
            .write_fifo_full(write_fifo_full), .write_finish(write_finish),
            .frame_done(frame_done), .error(writer_error)
        );
    end else begin : g_block_writer
        bmp_sdram_block_writer #(
            .WIDTH(SOURCE_W), .HEIGHT(SOURCE_H), .ADDR_BITS(21),
            .BLOCK_WORDS(VIDEO_WRITE_BURST_WORDS),
            .RESTARTABLE(1), .SECTOR_PIXELS(256)
        ) u_bmp_sdram_block_writer (
            .clk(clk_50m), .rst_n(write_rst_n),
            .row_valid(row_valid), .row_pixel(row_pixel), .row_ready(row_ready),
            .frame_base_addr(write_frame_base_addr),
            .start(writer_start),
            .write_req(write_req), .write_req_ack(write_req_ack),
            .write_en(write_en), .write_data(write_data),
            .write_base_addr(write_base_addr), .write_len(write_len),
            .write_fifo_full(write_fifo_full), .write_finish(write_finish),
            .sector_continue(bin_sector_continue),
            .frame_done(frame_done), .error(writer_error)
        );
    end
endgenerate

anlogic_frame_store #(
    .READ_LOOP(1),
    .BURST_SIZE(VIDEO_BURST_WORDS),
    .WRITE_BURST_SIZE(VIDEO_WRITE_BURST_WORDS),
    // This can be reduced independently for a board-specific read-path test.
    .READ_BURST_SIZE(VIDEO_READ_BURST_WORDS),
    .READ_FIFO_OUTREG(VIDEO_READ_FIFO_OUTREG)
) u_frame_store (
    .mem_clk(mem_clk), .mem_clk_sft(mem_clk_sft), .rst_n(mem_rst_n),
    .init_done(init_done), .init_ref_valid(init_ref_valid), .mem_busy(mem_busy),
    .write_clk(clk_50m), .write_req(write_req), .write_req_ack(write_req_ack),
    .write_finish(write_finish), .write_fifo_full(write_fifo_full),
    .write_base_addr(write_base_addr), .write_len(write_len),
    .write_en(write_en), .write_data(write_data),
    .read_clk(video_clk), .read_req(video_read_req),
    .read_req_ack(video_read_req_ack), .read_finish(video_read_finish),
    .read_fifo_valid(read_fifo_valid), .read_fifo_empty(read_fifo_empty),
    .read_base_addr(READBACK_DIAG ? (published_frame_ff2 ? FRAME1_BASE : FRAME0_BASE) :
                    (LINEBUF_SCALE ? linebuf_source_read_base_addr :
                    (ENABLE_MULTI_FRAME_PRELOAD ?
                     frame_base_for_index(display_media_index) :
                     (display_frame_index ? FRAME1_BASE : FRAME0_BASE)))),
    .read_len(READBACK_DIAG ? FRAME_LENGTH :
              (LINEBUF_SCALE ? linebuf_source_read_len : FRAME_LENGTH)),
    .read_en(read_en),
    .read_data(read_data)
);

generate
    if (LINEBUF_SCALE) begin : g_linebuf_scaler
        linebuf_scaler_960x540_to_1280x720 #(
            .SRC_W(SOURCE_W), .SRC_H(SOURCE_H),
            .DST_W(VIDEO_W), .DST_H(VIDEO_H),
            .LINEBUF_REGISTER_READ(LINEBUF_REGISTER_READ),
            .FIFO_RESPONSE_REGISTER(LINEBUF_FIFO_RESPONSE_REGISTER)
        ) u_linebuf_scaler (
            .clk(video_clk), .rst_n(video_rst_n),
            .source_start(linebuf_start_pulse),
            .zoom_2x(1'b0),
            .museum_recenter_active(1'b0),
            .museum_recenter_closing(1'b0),
            .museum_recenter_progress(8'd0),
            .museum_recenter_origin(3'd0),
            .source_base_addr(ENABLE_MULTI_FRAME_PRELOAD ?
                              frame_base_for_index(display_media_index) :
                              (display_frame_index ? FRAME1_BASE : FRAME0_BASE)),
            .source_read_req(linebuf_source_read_req),
            .source_read_ack(linebuf_source_read_ack),
            .source_read_base_addr(linebuf_source_read_base_addr),
            .source_read_len(linebuf_source_read_len),
            .source_fifo_empty(read_fifo_empty),
            .source_fifo_valid(read_fifo_valid),
            .source_read_en(linebuf_source_read_en),
            .source_read_data(read_data),
            // Hold prefetched rows until video_run starts.  Without this
            // gate, the timing generator can release rows before the first
            // frame-start sample and linebuf_frame_ready is then missed.
            .video_de(video_run ? video_de_i : 1'b0),
            .video_x(linebuf_video_x), .video_y(video_y_i),
            .pixel565(linebuf_pixel565), .frame_ready(linebuf_frame_ready),
            .source_frame_done(linebuf_source_frame_done), .underflow(linebuf_underflow)
        );
        assign linebuf_source_read_ack = video_read_req_ack;
    end else begin : g_no_linebuf_scaler
        assign linebuf_source_read_req = 1'b0;
        assign linebuf_source_read_base_addr = 21'd0;
        assign linebuf_source_read_len = 21'd0;
        assign linebuf_source_read_ack = 1'b0;
        assign linebuf_source_read_en = 1'b0;
        assign linebuf_pixel565 = 16'd0;
        assign linebuf_frame_ready = 1'b0;
        assign linebuf_source_frame_done = 1'b0;
        assign linebuf_underflow = 1'b0;
    end
endgenerate

// This is deliberately outside the normal video state machine.  In v52 it
// owns the read FIFO from the moment a frame is published until every word is
// checked; all non-v52 builds elaborate the same inactive logic but retain
// their original read-request/read-enable mux inputs above.
assign diag_start = READBACK_DIAG && !diag_done &&
                    (ready_ff2 != diag_ready_seen);
always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n)
        diag_ready_seen <= 1'b0;
    else if (diag_start)
        diag_ready_seen <= ready_ff2;
end

generate
    if (READBACK_DIAG) begin : g_sdram_diag_readback
        sdram_diag_readback_checker #(
            .SOURCE_W(SOURCE_W), .SOURCE_H(SOURCE_H), .ADDR_BITS(21)
        ) u_sdram_diag_readback_checker (
            .clk(video_clk), .rst_n(video_rst_n), .start(diag_start),
            .read_req_ack(video_read_req_ack), .read_fifo_empty(read_fifo_empty),
            .read_fifo_valid(read_fifo_valid), .read_data(read_data),
            .read_req(diag_read_req), .read_en(diag_read_en), .active(diag_active),
            .done(diag_done), .pass(diag_pass), .fail(diag_fail),
            .first_error_addr(diag_first_error_addr),
            .first_error_actual(diag_first_error_actual),
            .first_error_expected(diag_first_error_expected)
        );
    end else begin : g_no_sdram_diag_readback
        assign diag_read_req            = 1'b0;
        assign diag_read_en             = 1'b0;
        assign diag_active              = 1'b0;
        assign diag_done                = 1'b0;
        assign diag_pass                = 1'b0;
        assign diag_fail                = 1'b0;
        assign diag_first_error_addr    = 21'd0;
        assign diag_first_error_actual  = 32'd0;
        assign diag_first_error_expected= 32'd0;
    end
endgenerate

// Start the first load, then reload only after SW1 requests the other image.
// The image and SDRAM frame are latched for the whole transaction so a switch
// moved during a load cannot redirect the writer into the active frame.
always @(posedge clk_50m or negedge write_rst_n) begin
    if (!write_rst_n) begin
        image_load_start <= 1'b0;
        writer_start     <= 1'b0;
        load_active      <= 1'b0;
        load_reported    <= 1'b0;
        writer_done_seen <= 1'b0;
        loader_done_seen <= 1'b0;
        writer_done_clear_seen <= 1'b0;
        loader_done_clear_seen <= 1'b0;
        load_image_index <= 1'b0;
        load_media_index <= 4'd0;
        active_media_index <= 4'd0;
        published_media_index <= 4'd0;
        load_frame_index <= 1'b0;
        active_image_index <= 1'b0;
        published_frame_index <= 1'b0;
        manual_image_index <= 4'd0;
        brightness_level <= 2'd0;
        contrast_level <= 2'd0;
        frame_ready_toggle <= 1'b0;
        auto_mode_d       <= 1'b0;
        auto_image_index  <= 4'd0;
        auto_period_count <= 28'd0;
        sequence_hold_count <= 25'd0;
        sequence_hold_done  <= 1'b0;
        frame_valid         <= 5'b00000;
        initial_frame_published <= 1'b0;
        preload_select_frame_index <= 1'b0;
        preload_select_media_index <= 4'd0;
        frame_source_width_bcd[0] <= 16'd0;
        frame_source_width_bcd[1] <= 16'd0;
        frame_source_width_bcd[2] <= 16'd0;
        frame_source_width_bcd[3] <= 16'd0;
        frame_source_width_bcd[4] <= 16'd0;
        frame_source_height_bcd[0] <= 16'd0;
        frame_source_height_bcd[1] <= 16'd0;
        frame_source_height_bcd[2] <= 16'd0;
        frame_source_height_bcd[3] <= 16'd0;
        frame_source_height_bcd[4] <= 16'd0;
        published_source_width_bcd <= 16'd0;
        published_source_height_bcd <= 16'd0;
        preload_select_source_width_bcd <= 16'd0;
        preload_select_source_height_bcd <= 16'd0;
    end else begin
        if (key_press_pulse[1] && !auto_mode) begin
            if (manual_image_index == VIDEO_FRAME_COUNT - 1)
                manual_image_index <= 4'd0;
            else
                manual_image_index <= manual_image_index + 1'b1;
        end

        if (key_press_pulse[2]) begin
            case (brightness_level)
                2'd0: brightness_level <= 2'd1;
                2'd1: brightness_level <= 2'd2;
                default: brightness_level <= 2'd0;
            endcase
        end

        if (key_press_pulse[3]) begin
            case (contrast_level)
                2'd0: contrast_level <= 2'd1;
                2'd1: contrast_level <= 2'd2;
                default: contrast_level <= 2'd0;
            endcase
        end

        auto_mode_d <= auto_mode;
        if (!auto_mode) begin
            auto_period_count <= 28'd0;
            auto_image_index  <= manual_image_index;
        end else if (!auto_mode_d) begin
            auto_period_count <= 28'd0;
            auto_image_index  <= active_image_index;
        end else if (auto_period_count == AUTO_PERIOD_CYCLES - 1) begin
            auto_period_count <= 28'd0;
            if (auto_image_index == VIDEO_FRAME_COUNT - 1)
                auto_image_index <= 4'd0;
            else
                auto_image_index <= auto_image_index + 1'b1;
        end else begin
            auto_period_count <= auto_period_count + 1'b1;
        end

        image_load_start <= 1'b0;
        writer_start <= 1'b0;

        // In preload mode this is a level CDC request, not a pulse: a key
        // pressed before IMAGE1 has finished loading is remembered by
        // desired_image_index and is applied immediately after its frame is
        // valid.  The video clock observes the stable selected frame through
        // a two-flop synchronizer below.
        if (ENABLE_MULTI_FRAME_PRELOAD && load_reported && !load_active &&
            frame_valid[desired_image_index]) begin
            preload_select_media_index <= desired_image_index;
            active_image_index <= desired_image_index;
            preload_select_source_width_bcd <= frame_source_width_bcd[desired_image_index];
            preload_select_source_height_bcd <= frame_source_height_bcd[desired_image_index];
        end else if (ENABLE_DUAL_FRAME_PRELOAD && load_reported && !load_active &&
                     frame_valid[desired_image_index[0]]) begin
            preload_select_frame_index <= desired_image_index[0];
            active_image_index <= {3'd0, desired_image_index[0]};
            preload_select_source_width_bcd <= frame_source_width_bcd[desired_image_index[0]];
            preload_select_source_height_bcd <= frame_source_height_bcd[desired_image_index[0]];
        end

        if (!load_active) begin
            if (!load_reported && init_done && sd_init_done) begin
                load_image_index <= load_start_image_index;
                load_frame_index <= VIDEO_SEQUENCE ? ~published_frame_index : load_start_image_index[0];
                load_media_index <= load_start_media_index;
                image_load_start <= 1'b1;
                writer_start     <= 1'b1;
                load_active      <= 1'b1;
                load_reported    <= 1'b0;
                writer_done_seen <= 1'b0;
                loader_done_seen <= 1'b0;
                writer_done_clear_seen <= 1'b0;
                loader_done_clear_seen <= 1'b0;
                sequence_hold_count <= 25'd0;
                sequence_hold_done  <= 1'b0;
            end else if (load_reported && load_request_pending) begin
                load_image_index <= load_start_image_index;
                load_frame_index <= VIDEO_SEQUENCE ? ~published_frame_index : load_start_image_index[0];
                load_media_index <= load_start_media_index;
                image_load_start <= 1'b1;
                writer_start     <= 1'b1;
                load_active      <= 1'b1;
                load_reported    <= 1'b0;
                writer_done_seen <= 1'b0;
                loader_done_seen <= 1'b0;
                writer_done_clear_seen <= 1'b0;
                loader_done_clear_seen <= 1'b0;
                sequence_hold_count <= 25'd0;
                sequence_hold_done  <= 1'b0;
            end else if (load_reported && VIDEO_SEQUENCE && auto_mode &&
                         !sequence_hold_done) begin
                if (sequence_hold_count == SEQUENCE_HOLD_CYCLES - 1) begin
                    sequence_hold_done <= 1'b1;
                end else begin
                    sequence_hold_count <= sequence_hold_count + 1'b1;
                end
            end
        end else begin
            // Both completion outputs are level-held. Do not accept a high
            // level until the restart pulse has cleared each old level.
            // They do not necessarily become low in the same cycle.
            if (!frame_done)
                writer_done_clear_seen <= 1'b1;
            if (!image_load_done)
                loader_done_clear_seen <= 1'b1;

            if (writer_done_clear_seen && frame_done)
                writer_done_seen <= 1'b1;
            if (loader_done_clear_seen && image_load_done)
                loader_done_seen <= 1'b1;

            if (!load_reported &&
                writer_done_clear_seen && loader_done_clear_seen &&
                (writer_done_seen || frame_done) &&
                (loader_done_seen || image_load_done)) begin
            // Do not publish or accept another switch until both sides have
            // completed: the writer may finish its last SDRAM block before
            // the SD loader reaches S_DONE for the final sector.
            if (ENABLE_MULTI_FRAME_PRELOAD)
                frame_valid[load_image_index] <= 1'b1;
            else
                frame_valid[load_frame_index] <= 1'b1;
            if (ENABLE_MULTI_FRAME_PRELOAD || (load_image_index < 4'd5)) begin
                frame_source_width_bcd[load_image_index] <= binary_to_bcd4(image_source_width);
                frame_source_height_bcd[load_image_index] <= binary_to_bcd4(image_source_height);
            end
            if (!ENABLE_CACHED_PRELOAD || !initial_frame_published)
                active_image_index <= load_image_index;
            if (VIDEO_SEQUENCE) begin
                if (load_media_index == VIDEO_FRAME_COUNT - 1)
                    active_media_index <= 4'd0;
                else
                    active_media_index <= load_media_index + 1'b1;
            end
            // Only the initial frame is published while preloading.  IMAGE1
            // becomes valid in SDRAM but must not disturb IMAGE0 until KEY2
            // selects it at a video-frame boundary.
            if (!ENABLE_CACHED_PRELOAD || !initial_frame_published) begin
                published_frame_index <= load_frame_index;
                published_media_index <= VIDEO_SEQUENCE ? load_media_index : {3'd0, load_image_index};
                published_source_width_bcd <= binary_to_bcd4(image_source_width);
                published_source_height_bcd <= binary_to_bcd4(image_source_height);
                frame_ready_toggle    <= ~frame_ready_toggle;
                initial_frame_published <= 1'b1;
            end
            load_reported         <= 1'b1;
            load_active           <= 1'b0;
            sequence_hold_count   <= 25'd0;
        sequence_hold_done    <= 1'b0;
    end
        end
    end
end

always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin
        ready_ff1          <= 1'b0;
        ready_ff2          <= 1'b0;
        published_frame_ff1<= 1'b0;
        published_frame_ff2<= 1'b0;
        published_media_ff1<= 4'd0;
        published_media_ff2<= 4'd0;
        published_source_width_ff1 <= 16'd0;
        published_source_width_ff2 <= 16'd0;
        published_source_height_ff1 <= 16'd0;
        published_source_height_ff2 <= 16'd0;
        preload_select_ff1 <= 1'b0;
        preload_select_ff2 <= 1'b0;
        preload_select_media_ff1 <= 4'd0;
        preload_select_media_ff2 <= 4'd0;
        preload_select_source_width_ff1 <= 16'd0;
        preload_select_source_width_ff2 <= 16'd0;
        preload_select_source_height_ff1 <= 16'd0;
        preload_select_source_height_ff2 <= 16'd0;
        ready_seen         <= 1'b0;
        read_req_r         <= 1'b0;
        linebuf_start_pulse<= 1'b0;
        linebuf_start_pending <= 1'b0;
        read_ack_ff1       <= 1'b0;
        read_ack_ff2       <= 1'b0;
        read_accepted      <= 1'b0;
        read_ready         <= 1'b0;
        read_prefill_count <= 12'd0;
        video_run          <= 1'b0;
        pair_phase         <= 1'b0;
        pair_word_valid    <= 1'b0;
        underflow_seen     <= 1'b0;
        pending_frame_index<= 1'b0;
        pending_media_index <= 4'd0;
        pending_source_width_bcd <= 16'd0;
        pending_source_height_bcd <= 16'd0;
        display_frame_index<= 1'b0;
        display_media_index <= 4'd0;
        display_source_width_bcd <= 16'd0;
        display_source_height_bcd <= 16'd0;
        switch_pending     <= 1'b0;
        auto_mode_ff1      <= 1'b0;
        auto_mode_ff2      <= 1'b0;
        transition_mode_ff1 <= 3'b000;
        transition_mode_ff2 <= 3'b000;
        transition_mode    <= 3'b000;
        transition_progress <= 6'd36;
        brightness_level_ff1 <= 2'd0;
        brightness_level_ff2 <= 2'd0;
        contrast_level_ff1   <= 2'd0;
        contrast_level_ff2   <= 2'd0;
        fade_level         <= 5'd16;
        fade_out_active    <= 1'b0;
    end else begin
        linebuf_start_pulse <= 1'b0;
        if (linebuf_start_pending) begin
            linebuf_start_pulse <= 1'b1;
            linebuf_start_pending <= 1'b0;
        end
        ready_ff1    <= frame_ready_toggle;
        ready_ff2    <= ready_ff1;
        published_frame_ff1 <= published_frame_index;
        published_frame_ff2 <= published_frame_ff1;
        published_media_ff1 <= published_media_index;
        published_media_ff2 <= published_media_ff1;
        published_source_width_ff1 <= published_source_width_bcd;
        published_source_width_ff2 <= published_source_width_ff1;
        published_source_height_ff1 <= published_source_height_bcd;
        published_source_height_ff2 <= published_source_height_ff1;
        preload_select_ff1 <= preload_select_frame_index;
        preload_select_ff2 <= preload_select_ff1;
        preload_select_media_ff1 <= preload_select_media_index;
        preload_select_media_ff2 <= preload_select_media_ff1;
        preload_select_source_width_ff1 <= preload_select_source_width_bcd;
        preload_select_source_width_ff2 <= preload_select_source_width_ff1;
        preload_select_source_height_ff1 <= preload_select_source_height_bcd;
        preload_select_source_height_ff2 <= preload_select_source_height_ff1;
        auto_mode_ff1      <= auto_mode;
        auto_mode_ff2      <= auto_mode_ff1;
        transition_mode_ff1 <= sw[2:0];
        transition_mode_ff2 <= transition_mode_ff1;
        brightness_level_ff1 <= brightness_level;
        brightness_level_ff2 <= brightness_level_ff1;
        contrast_level_ff1   <= contrast_level;
        contrast_level_ff2   <= contrast_level_ff1;
        read_ack_ff1 <= video_read_req_ack;
        read_ack_ff2 <= read_ack_ff1;
        if (LINEBUF_SCALE && video_run && linebuf_underflow)
            underflow_seen <= 1'b1;

        // A new frame is remembered while the current frame continues to
        // display. The actual FIFO reset/request waits for frame_tick.
        if (ENABLE_MULTI_FRAME_PRELOAD && video_run &&
            (preload_select_media_ff2 != display_media_index)) begin
            pending_media_index <= preload_select_media_ff2;
            pending_frame_index <= preload_select_media_ff2[0];
            pending_source_width_bcd <= preload_select_source_width_ff2;
            pending_source_height_bcd <= preload_select_source_height_ff2;
            switch_pending <= 1'b1;
            if (!switch_pending)
                transition_mode <= transition_mode_ff2;
            if (!switch_pending)
                transition_progress <= 6'd0;
            if (ENABLE_FADE)
                fade_out_active <= 1'b1;
        end else if (ENABLE_DUAL_FRAME_PRELOAD && video_run &&
            (preload_select_ff2 != display_frame_index)) begin
            pending_frame_index <= preload_select_ff2;
            pending_media_index <= {3'd0, preload_select_ff2};
            pending_source_width_bcd <= preload_select_source_width_ff2;
            pending_source_height_bcd <= preload_select_source_height_ff2;
            switch_pending <= 1'b1;
            if (!switch_pending)
                transition_mode <= transition_mode_ff2;
            if (!switch_pending)
                transition_progress <= 6'd0;
            if (ENABLE_FADE)
                fade_out_active <= 1'b1;
        end else if (ENABLE_MULTI_FRAME_PRELOAD && video_run && switch_pending &&
                     (preload_select_media_ff2 == display_media_index)) begin
            switch_pending  <= 1'b0;
            fade_out_active <= 1'b0;
            fade_level      <= 5'd16;
            transition_progress <= 6'd36;
        end else if (ENABLE_DUAL_FRAME_PRELOAD && video_run && switch_pending &&
                     (preload_select_ff2 == display_frame_index)) begin
            // A second key press before the boundary cancels the obsolete
            // request instead of switching to a no-longer-selected frame.
            switch_pending  <= 1'b0;
            fade_out_active <= 1'b0;
            fade_level      <= 5'd16;
            transition_progress <= 6'd36;
        end else if (video_run && (ready_ff2 != ready_seen)) begin
            ready_seen <= ready_ff2;
            pending_frame_index <= published_frame_ff2;
            pending_media_index <= published_media_ff2;
            pending_source_width_bcd <= published_source_width_ff2;
            pending_source_height_bcd <= published_source_height_ff2;
            switch_pending <= 1'b1;
            transition_mode <= transition_mode_ff2;
            transition_progress <= 6'd0;
            if (ENABLE_FADE)
                fade_out_active <= 1'b1;
        end else if (!video_run && !read_accepted && !read_ready &&
                     (ready_ff2 != ready_seen)) begin
            ready_seen <= ready_ff2;
            display_frame_index <= published_frame_ff2;
            display_media_index <= published_media_ff2;
            display_source_width_bcd <= published_source_width_ff2;
            display_source_height_bcd <= published_source_height_ff2;
            read_req_r <= 1'b1;
            linebuf_start_pending <= LINEBUF_SCALE;
        end else if (read_req_r && read_ack_ff2) begin
            read_req_r    <= 1'b0;
            read_prefill_count <= 12'd0;
            read_accepted <= 1'b1;
        end

        if (video_run && switch_pending && video_vblank_start &&
            (!ENABLE_FADE || (fade_out_active && fade_level == 5'd4))) begin
            // Stop consuming at the visible-frame boundary. The FIFO is
            // refilled during vertical blanking, outside the active picture.
            video_run          <= 1'b0;
            read_accepted      <= 1'b0;
            read_ready         <= 1'b0;
            read_req_r         <= 1'b1;
            display_frame_index<= pending_frame_index;
            display_media_index<= pending_media_index;
            display_source_width_bcd <= pending_source_width_bcd;
            display_source_height_bcd <= pending_source_height_bcd;
            linebuf_start_pending <= LINEBUF_SCALE;
            switch_pending     <= 1'b0;
            pair_phase         <= 1'b0;
            pair_word_valid    <= 1'b0;
            fade_level         <= 5'd4;
            fade_out_active    <= 1'b0;
            transition_progress <= 6'd0;
        end

        if (!video_run && read_accepted && !read_ready) begin
            if (read_prefill_count == 12'd2047)
                read_ready <= 1'b1;
            else
                read_prefill_count <= read_prefill_count + 1'b1;
        end

        if (!LINEBUF_SCALE && !video_run && read_ready && video_frame_start) begin
            video_run       <= 1'b1;
            read_ready      <= 1'b0;
            pair_phase      <= 1'b0;
            pair_word_valid <= 1'b0;
        end else if (LINEBUF_SCALE && !video_run && linebuf_frame_ready &&
                     video_frame_start) begin
            video_run       <= 1'b1;
            read_ready      <= 1'b0;
        end else if (video_run && video_frame_tick && ENABLE_FADE) begin
            if (fade_out_active) begin
                if (fade_level > 5'd4)
                    fade_level <= fade_level - 1'b1;
            end else if (fade_level < 5'd16) begin
                fade_level <= fade_level + 1'b1;
            end
            if (!fade_out_active && (transition_mode != 3'b000) &&
                (transition_mode != 3'b111) &&
                (transition_progress < ((transition_mode == 3'b100) ? 6'd60 : 6'd36)))
                transition_progress <= transition_progress + 1'b1;
        end else if (video_run && video_read_en && !LINEBUF_SCALE) begin
            pair_phase <= ~pair_phase;
            if (!pair_phase) begin
                pair_word_valid <= !read_fifo_empty;
                if (read_fifo_empty)
                    underflow_seen <= 1'b1;
            end
        end

    if (!video_run)
        pair_word_valid <= 1'b0;
    end
end

video_timing_640x480_pclk #(
    .H_VISIBLE(VIDEO_W),
    .H_FRONT(H_FRONT),
    .H_SYNC(H_SYNC),
    .H_BACK(H_BACK),
    .V_VISIBLE(VIDEO_H),
    .V_FRONT(V_FRONT),
    .V_SYNC(V_SYNC),
    .V_BACK(V_BACK),
    .X_BITS(11)
) u_video_timing (
    .clk(video_clk), .rst_n(video_rst_n),
    .hs(video_hs_i), .vs(video_vs_i), .de(video_de_i),
    .x(video_x_i), .y(video_y_i), .frame_tick(video_frame_tick)
);

video_delay u_video_delay (
    .video_clk(video_clk), .rst(~video_rst_n), .read_en(video_read_en),
    .read_data(unpacked_rgb), .hs(video_hs_i), .vs(video_vs_i),
    .de(video_de_i), .hs_r(video_hs), .vs_r(video_vs), .de_r(video_de),
    .vout_data(video_rgb)
);

// Keep the pixel-domain controls after the SDRAM read pipeline. The timing
// coordinates use the same 20-clock delay as video_delay, so the OSD cannot
// drift relative to the displayed image.
always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin
        video_x_pipe <= 231'd0;
        video_y_pipe <= 210'd0;
        video_right_edge_pixel <= 24'h000000;
        linebuf_pixel565_pipe <= 304'd0;
        linebuf_pixel565_pipe_reg <= 320'd0;
    end else begin
        video_x_pipe <= {video_x_pipe[219:0], video_x_i};
        video_y_pipe <= {video_y_pipe[199:0], video_y_i};
        if (RIGHT_EDGE_REPLICATE_COLUMNS != 0 && video_de &&
            (video_x_delayed == VIDEO_W - RIGHT_EDGE_REPLICATE_COLUMNS - 1))
            video_right_edge_pixel <= video_osd_rgb;
        linebuf_pixel565_pipe <= {linebuf_pixel565_pipe[287:0], linebuf_pixel565};
        linebuf_pixel565_pipe_reg <= {linebuf_pixel565_pipe_reg[303:0], linebuf_pixel565};
    end
end

rgb888_adjust u_rgb888_adjust (
    .de               (video_de),
    .rgb_in           (video_rgb),
    .brightness_level (brightness_level_ff2),
    .contrast_level   (contrast_level_ff2),
    .picture_style    (2'd0),
    .rgb_out          (video_adjusted_rgb)
);

generate
    if (ENABLE_FADE) begin : g_video_fade
        video_fade u_video_fade (
            .rgb_in  (video_adjusted_rgb),
            .level   (((transition_mode == 3'b000) || (transition_mode == 3'b111)) ?
                      fade_level : 5'd16),
            .rgb_out (video_faded_rgb)
        );
    end else begin : g_video_no_fade
        assign video_faded_rgb = video_adjusted_rgb;
    end
endgenerate

video_transition_mask #(
    .VIDEO_W(VIDEO_W), .VIDEO_H(VIDEO_H)
) u_video_transition_mask (
    .clk           (video_clk),
    .rst_n         (video_rst_n),
    .rgb_in        (video_faded_rgb),
    .de            (video_de),
    .x             (video_x_delayed),
    .y             (video_y_delayed),
    .mode          (transition_mode),
    .origin_index  (3'd2),
    .progress      ({2'b0, transition_progress}),
    .closing       (fade_out_active),
    .overview_source(1'b0),
    .enable        (ENABLE_FADE && !fade_out_active &&
                    (transition_progress < ((transition_mode == 3'b100) ? 6'd60 : 6'd36))),
    .rgb_out       (video_transition_rgb)
);

generate
    if (ENABLE_OSD) begin : g_video_osd
        if (VIDEO_MODE_1280) begin : g_video_osd_1280
            osd_status_1280_pipe u_osd_status (
                .clk(video_clk), .rst_n(video_rst_n), .de_i(video_de),
                .x_i(video_x_delayed), .y_i(video_y_delayed),
                .rgb_i(video_transition_rgb), .image_index(display_media_index),
                .auto_mode(auto_mode_ff2), .brightness_level(brightness_level_ff2),
                .contrast_level(contrast_level_ff2), .audio_track_index(2'd0),
                .mode(2'd0), .panel_enable(1'b1),
                .auto_speed_level(2'd1), .slideshow_paused(1'b0),
                .transition_theme(2'd0), .transition_context(2'd0),
                .zoom_2x(1'b0), .picture_style(2'd0),
                .source_width_bcd(display_source_width_bcd),
                .source_height_bcd(display_source_height_bcd), .rgb_o(video_osd_1280_rgb)
            );
            assign video_osd_rgb = video_osd_1280_rgb;
        end else begin : g_video_osd_standard
            osd_status_rgb888 u_osd_status (
                .de               (video_de),
                .x                (video_x_delayed[9:0]),
                .y                (video_y_delayed),
                .rgb_in           (video_transition_rgb),
                .enable           (1'b1),
                .image_index      (display_media_index),
                .auto_mode        (auto_mode_ff2),
                .brightness_level (brightness_level_ff2),
                .contrast_level   (contrast_level_ff2),
                .source_width_bcd (display_source_width_bcd),
                .source_height_bcd(display_source_height_bcd),
                .rgb_out          (video_osd_rgb)
            );
        end
    end else begin : g_video_direct
        assign video_osd_rgb = video_adjusted_rgb;
    end
endgenerate

always @(posedge mem_clk or negedge mem_rst_n) begin
    if (!mem_rst_n)
        heartbeat_count <= 26'd0;
    else
        heartbeat_count <= heartbeat_count + 1'b1;
end

always @(*) begin
    if (row_overflow || writer_error || image_load_error)
        status_code = 4'hf;
    else if (frame_done)
        status_code = 4'h8;
    else
        status_code = image_load_status;
end

assign normal_seg_value = {status_code, 4'h0, row_index[3:0], image_load_status};
assign diag_seg_value = (row_overflow || writer_error || image_load_error || diag_fail) ?
                        ((diag_fail && sw == 4'b0001) ? diag_first_error_addr[15:0] :
                         (diag_fail && sw == 4'b0010) ? diag_first_error_actual[15:0] :
                         (diag_fail && sw == 4'b0011) ? diag_first_error_expected[15:0] :
                         (diag_fail && sw == 4'b0100) ? diag_first_error_actual[31:16] :
                         (diag_fail && sw == 4'b0101) ? diag_first_error_expected[31:16] :
                         16'hdead) :
                        ((!frame_done || image_load_busy || load_active) ? 16'hd000 :
                         (diag_done && diag_pass) ? 16'hd0a5 : 16'hd001);

seg_hex_display u_seg_hex_display (
    .clk(mem_clk), .rst_n(mem_rst_n),
    .value(READBACK_DIAG ? diag_seg_value : normal_seg_value),
    .seg_data(seg_data), .seg_sel(seg_sel)
);

assign led[0] = heartbeat_count[25];
assign led[1] = init_done;
assign led[2] = frame_done;
assign led[3] = READBACK_DIAG ?
                (diag_done && diag_pass && !diag_fail && !row_overflow &&
                 !writer_error && !image_load_error) :
                (video_run && !underflow_seen && !row_overflow && !writer_error);

// The 1280x720 path needs one registered boundary before the HDMI encoder.
// Pixel data and sync signals advance together, preserving raster alignment.
generate
    if (VIDEO_MODE_1280) begin : g_hdmi_output_register
        reg        hs_q;
        reg        vs_q;
        reg        de_q;
        reg        hs_q_d;
        reg        vs_q_d;
        reg        de_q_d;
        reg [23:0] rgb_q;
        reg [23:0] rgb_q_d;
        always @(posedge video_clk or negedge video_rst_n) begin
            if (!video_rst_n) begin
                hs_q  <= 1'b1;
                vs_q  <= 1'b1;
                de_q  <= 1'b0;
                hs_q_d <= 1'b1;
                vs_q_d <= 1'b1;
                de_q_d <= 1'b0;
                rgb_q <= 24'h000000;
                rgb_q_d <= 24'h000000;
            end else begin
                hs_q  <= video_hs;
                vs_q  <= video_vs;
                de_q  <= video_de;
                hs_q_d <= hs_q;
                vs_q_d <= vs_q;
                de_q_d <= de_q;
                rgb_q_d <= rgb_q;
                // Keep the last pixel through blanking.  video_delay drops
                // its data one cycle before de_q_d falls, so without this
                // hold the final active pixel of every line becomes black.
                if (LINEBUF_V26_OUTPUT_PIPELINE)
                    rgb_q <= video_osd_rgb;
                else if (video_de)
                    rgb_q <= video_osd_rgb;
            end
        end
        assign video_hs_out  = hs_q_d;
        assign video_vs_out  = vs_q_d;
        assign video_de_out  = de_q_d;
        // The delayed DE remains high for one boundary cycle after
        // video_delay has dropped its data.  In the registered line-buffer
        // raw-media path, the pipe still holds the final source pixel there;
        // use it for that one tail cycle so every visible column is complete.
        assign video_rgb_out = LINEBUF_V26_OUTPUT_PIPELINE ? rgb_q_d :
                               ((LINEBUF_SCALE && LINEBUF_REGISTER_READ &&
                                 !ENABLE_OSD && !ENABLE_FADE && de_q_d && !de_q) ?
                                unpacked_rgb : rgb_q);
    end else begin : g_hdmi_output_direct
        assign video_hs_out  = video_hs;
        assign video_vs_out  = video_vs;
        assign video_de_out  = video_de;
        assign video_rgb_out = video_output_rgb;
    end
endgenerate

assign vga_hs = video_hs_out;
assign vga_vs = video_vs_out;
assign vga_d  = video_rgb_out[23:12];

hdmi_tx u_hdmi_tx (
    .PXLCLK_I(video_clk), .PXLCLK_5X_I(video_clk_5x), .RST_N(video_rst_n),
    .VGA_HS(video_hs_out), .VGA_VS(video_vs_out), .VGA_DE(video_de_out),
    .VGA_RGB(video_rgb_out), .HDMI_CLK_P(hdmi1_clk_p),
    .HDMI_D2_P(hdmi1_d2_p), .HDMI_D1_P(hdmi1_d1_p), .HDMI_D0_P(hdmi1_d0_p)
);

endmodule

`default_nettype wire
