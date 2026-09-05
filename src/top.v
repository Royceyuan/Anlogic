`timescale 1ns / 1ps
`default_nettype none

module top #(
    parameter integer COUNTER_BITS = 26,
    parameter integer HEARTBEAT_BIT = 24,
    // The fallback test pattern is also a full 640x480 video frame.  The
    // loaded BMP path remains sampled into the 160x120 BRAM and expanded by
    // the framebuffer, so these parameters do not change its storage use.
    parameter integer IMAGE_W = 640,
    parameter integer IMAGE_H = 480
)(
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

wire rst_n;
wire [3:0] key_level_n;
wire [3:0] key_press_pulse;
wire [3:0] key_release_pulse;
wire       frame_tick;
wire [9:0] vga_x;
wire [9:0] vga_y;
wire       vga_de;
wire       vga_hs_i;
wire       vga_vs_i;
wire [11:0] vga_rgb;
wire       fit_de;
wire [9:0] fit_x;
wire [9:0] fit_y;
wire       hdmi_rst_n;
wire       hdmi_pixel_clk;
wire       hdmi_pixel_clk_5x;
wire       hdmi_frame_tick;
wire       hdmi_de;
wire       hdmi_hs;
wire       hdmi_vs;
wire [9:0] hdmi_x;
wire [9:0] hdmi_y;
wire       hdmi_fit_de;
wire [9:0] hdmi_fit_x;
wire [9:0] hdmi_fit_y;
wire [11:0] hdmi_rgb_12;
wire [23:0] hdmi_rgb_24;
wire [11:0] hdmi_test_rgb_12;
wire [11:0] image_rgb_12;
wire [11:0] hdmi_source_rgb_12;
wire [11:0] hdmi_adjusted_rgb_12;
wire [11:0] hdmi_osd_rgb_12;
reg         hdmi_hs_d;
reg         hdmi_vs_d;
reg         hdmi_de_d;
reg  [9:0]  hdmi_x_d;
reg  [9:0]  hdmi_y_d;
reg  [11:0] hdmi_test_rgb_d;
wire [3:0]  status_code;
wire [7:0]  image_index;
wire        overlay_enable;
wire        auto_mode;
wire        sd_init_done;
wire        sd_sec_read;
wire [31:0] sd_sec_read_addr;
wire [7:0]  sd_sec_read_data;
wire        sd_sec_read_data_valid;
wire        sd_sec_read_end;
wire        image_wr_en;
wire [14:0] image_wr_addr;
wire [15:0] image_wr_data;
wire        image_load_busy;
wire        image_load_done;
wire        image_load_error;
wire [3:0]  image_load_status;
wire [1:0]  image_file_index;
reg  [1:0]  requested_image_index;
reg         requested_bmp_mode;
reg         sd_init_done_d;
reg         image_load_start;
reg  [3:0]  status_code_hdmi_ff1;
reg  [3:0]  status_code_hdmi_ff2;
reg  [7:0]  image_index_hdmi_ff1;
reg  [7:0]  image_index_hdmi_ff2;
reg         overlay_enable_hdmi_ff1;
reg         overlay_enable_hdmi_ff2;
reg         auto_mode_hdmi_ff1;
reg         auto_mode_hdmi_ff2;
reg         brightness_enable_hdmi_ff1;
reg         brightness_enable_hdmi_ff2;
reg         contrast_enable_hdmi_ff1;
reg         contrast_enable_hdmi_ff2;
reg         image_load_done_hdmi_ff1;
reg         image_load_done_hdmi_ff2;
reg         image_load_busy_hdmi_ff1;
reg         image_load_busy_hdmi_ff2;
reg         image_display_enable;

reset_sync u_reset_sync (
    .clk    (clk_50m),
    .arst_n (key_n[0]),
    .srst_n (rst_n)
);

key_debounce u_key_debounce (
    .clk              (clk_50m),
    .rst_n            (rst_n),
    .key_n            (key_n),
    .key_level_n      (key_level_n),
    .key_press_pulse  (key_press_pulse),
    .key_release_pulse(key_release_pulse)
);

reset_sync u_hdmi_reset_sync (
    .clk    (hdmi_pixel_clk),
    .arst_n (key_n[0]),
    .srst_n (hdmi_rst_n)
);

video_timing_640x480 u_video_timing (
    .clk        (clk_50m),
    .rst_n      (rst_n),
    .hs         (vga_hs_i),
    .vs         (vga_vs_i),
    .de         (vga_de),
    .x          (vga_x),
    .y          (vga_y),
    .frame_tick (frame_tick)
);

control_fsm u_control_fsm (
    .clk               (clk_50m),
    .rst_n             (rst_n),
    .frame_tick        (frame_tick),
    .media_ready       (1'b1),
    .error_in          (1'b0),
    .key_next_pulse    (key_press_pulse[1]),
    .key_prev_pulse    (key_press_pulse[2]),
    .key_overlay_pulse (key_press_pulse[3]),
    .sw_auto           (sw[0]),
    .status_code       (status_code),
    .image_index       (image_index),
    .overlay_enable    (overlay_enable),
    .auto_mode         (auto_mode)
);

assign image_file_index = requested_image_index;

// Generate one load request after card initialization and after a debounced
// image-index change. The requested index stays stable during the load.
always @(posedge clk_50m or negedge rst_n) begin
    if (!rst_n) begin
        requested_image_index <= 2'd0;
        requested_bmp_mode    <= 1'b0;
        sd_init_done_d        <= 1'b0;
        image_load_start      <= 1'b0;
    end else begin
        image_load_start <= 1'b0;
        sd_init_done_d   <= sd_init_done;

        if (sd_init_done && !sd_init_done_d) begin
            requested_image_index <= image_index[1:0];
            requested_bmp_mode    <= sw[3];
            image_load_start      <= 1'b1;
        end else if (sd_init_done && !image_load_busy &&
                     (image_index[1:0] != requested_image_index ||
                      sw[3] != requested_bmp_mode)) begin
            requested_image_index <= image_index[1:0];
            requested_bmp_mode    <= sw[3];
            image_load_start      <= 1'b1;
        end
    end
end

seg_hex_display u_seg_hex_display (
    .clk      (clk_50m),
    .rst_n    (rst_n),
    .value    ({4'h0, image_load_status, image_index}),
    .seg_data (seg_data),
    .seg_sel  (seg_sel)
);

video_pll u_hdmi_video_pll (
    .refclk   (clk_50m),
    .reset    (~rst_n),
    .clk0_out (hdmi_pixel_clk),
    .clk1_out (hdmi_pixel_clk_5x)
);

sd_card_top u_sd_card_top (
    .clk                   (clk_50m),
    .rst                   (~rst_n),
    .SD_nCS                (sd_cs_n),
    .SD_DCLK               (sd_clk),
    .SD_MOSI               (sd_mosi),
    .SD_MISO               (sd_miso),
    .sd_init_done          (sd_init_done),
    .sd_sec_read           (sd_sec_read),
    .sd_sec_read_addr      (sd_sec_read_addr),
    .sd_sec_read_data      (sd_sec_read_data),
    .sd_sec_read_data_valid(sd_sec_read_data_valid),
    .sd_sec_read_end       (sd_sec_read_end),
    .sd_sec_write          (1'b0),
    .sd_sec_write_addr     (32'd0),
    .sd_sec_write_data     (8'd0),
    .sd_sec_write_data_req (),
    .sd_sec_write_end      ()
);

fat32_image_loader u_fat32_image_loader (
    .clk                   (clk_50m),
    .rst_n                 (rst_n),
    .load_start            (image_load_start),
    .image_file_index      ({2'd0, image_file_index}),
    .bmp_mode              (requested_bmp_mode),
    .sequence_mode         (1'b0),
    .sd_init_done          (sd_init_done),
    .sd_sec_read           (sd_sec_read),
    .sd_sec_read_addr      (sd_sec_read_addr),
    .sd_sec_read_data      (sd_sec_read_data),
    .sd_sec_read_data_valid(sd_sec_read_data_valid),
    .sd_sec_read_end       (sd_sec_read_end),
    .image_continue        (1'b1),
    .image_wr_en           (image_wr_en),
    .image_wr_addr         (image_wr_addr),
    .image_wr_data         (image_wr_data),
    .busy                  (image_load_busy),
    .load_done             (image_load_done),
    .load_error            (image_load_error),
    .status_code           (image_load_status)
);

video_timing_640x480_pclk u_hdmi_timing ( 
    .clk        (hdmi_pixel_clk),
    .rst_n      (hdmi_rst_n),
    .hs         (hdmi_hs),
    .vs         (hdmi_vs),
    .de         (hdmi_de),
    .x          (hdmi_x),
    .y          (hdmi_y),
    .frame_tick (hdmi_frame_tick)
);

always @(posedge hdmi_pixel_clk or negedge hdmi_rst_n) begin
    if (!hdmi_rst_n) begin
        status_code_hdmi_ff1 <= 4'd0;
        status_code_hdmi_ff2 <= 4'd0;
        image_index_hdmi_ff1 <= 8'd0;
        image_index_hdmi_ff2 <= 8'd0;
        overlay_enable_hdmi_ff1 <= 1'b0;
        overlay_enable_hdmi_ff2 <= 1'b0;
        auto_mode_hdmi_ff1 <= 1'b0;
        auto_mode_hdmi_ff2 <= 1'b0;
        brightness_enable_hdmi_ff1 <= 1'b0;
        brightness_enable_hdmi_ff2 <= 1'b0;
        contrast_enable_hdmi_ff1 <= 1'b0;
        contrast_enable_hdmi_ff2 <= 1'b0;
        image_load_done_hdmi_ff1 <= 1'b0;
        image_load_done_hdmi_ff2 <= 1'b0;
        image_load_busy_hdmi_ff1 <= 1'b0;
        image_load_busy_hdmi_ff2 <= 1'b0;
        image_display_enable <= 1'b0;
        hdmi_hs_d <= 1'b1;
        hdmi_vs_d <= 1'b1;
        hdmi_de_d <= 1'b0;
        hdmi_x_d <= 10'd0;
        hdmi_y_d <= 10'd0;
        hdmi_test_rgb_d <= 12'h000;
    end else begin
        status_code_hdmi_ff1 <= status_code;
        status_code_hdmi_ff2 <= status_code_hdmi_ff1;
        image_index_hdmi_ff1 <= image_index;
        image_index_hdmi_ff2 <= image_index_hdmi_ff1;
        overlay_enable_hdmi_ff1 <= overlay_enable;
        overlay_enable_hdmi_ff2 <= overlay_enable_hdmi_ff1;
        auto_mode_hdmi_ff1 <= auto_mode;
        auto_mode_hdmi_ff2 <= auto_mode_hdmi_ff1;
        brightness_enable_hdmi_ff1 <= sw[1];
        brightness_enable_hdmi_ff2 <= brightness_enable_hdmi_ff1;
        contrast_enable_hdmi_ff1 <= sw[2];
        contrast_enable_hdmi_ff2 <= contrast_enable_hdmi_ff1;
        image_load_done_hdmi_ff1 <= image_load_done;
        image_load_done_hdmi_ff2 <= image_load_done_hdmi_ff1;
        image_load_busy_hdmi_ff1 <= image_load_busy;
        image_load_busy_hdmi_ff2 <= image_load_busy_hdmi_ff1;

        // The framebuffer uses a synchronous read. Its RGB output belongs to
        // the previous pixel, so delay the HDMI timing signals by one pixel
        // clock to keep DE/HS/VS aligned with the pixel data.
        hdmi_hs_d <= hdmi_hs;
        hdmi_vs_d <= hdmi_vs;
        hdmi_de_d <= hdmi_de;
        hdmi_x_d <= hdmi_x;
        hdmi_y_d <= hdmi_y;
        hdmi_test_rgb_d <= hdmi_test_rgb_12;

        // Keep the current framebuffer visible while a later image is being
        // loaded. This avoids a bright test-pattern flash on every switch;
        // the single framebuffer may show a very short partial update until
        // the sequential loader finishes.
        if (!image_display_enable && hdmi_frame_tick && image_load_done_hdmi_ff2)
            image_display_enable <= 1'b1;
    end
end

scaler_fit #(
    .DST_W(640),
    .DST_H(480),
    .SRC_W(IMAGE_W),
    .SRC_H(IMAGE_H)
) u_hdmi_scaler_fit (
    .de      (hdmi_de),
    .x       (hdmi_x),
    .y       (hdmi_y),
    .fit_de  (hdmi_fit_de),
    .fit_x   (hdmi_fit_x),
    .fit_y   (hdmi_fit_y),
    .fit_w   (),
    .fit_h   (),
    .offset_x(),
    .offset_y()
);

test_pattern u_hdmi_test_pattern (
    .de            (hdmi_fit_de),
    .state_code    (status_code_hdmi_ff2[2:0]),
    .image_index   (image_index_hdmi_ff2),
    .overlay_enable(overlay_enable_hdmi_ff2),
    .x             (hdmi_fit_x),
    .y             (hdmi_fit_y),
    .rgb           (hdmi_test_rgb_12)
);

bram_framebuffer_160x120 u_bram_framebuffer_160x120 (
    .wr_clk  (clk_50m),
    .wr_en   (image_wr_en),
    .wr_addr (image_wr_addr),
    .wr_data (image_wr_data),
    .rd_clk  (hdmi_pixel_clk),
    .rd_de   (hdmi_de),
    .rd_x    (hdmi_x),
    .rd_y    (hdmi_y),
    .rgb     (image_rgb_12)
);

// The post-process path is after the framebuffer source. It therefore stays
// unchanged when BRAM is replaced with the final SDRAM double buffer.
assign hdmi_source_rgb_12 = image_display_enable ? image_rgb_12 : hdmi_test_rgb_d;

rgb_adjust u_rgb_adjust (
    .de               (hdmi_de_d),
    .rgb_in           (hdmi_source_rgb_12),
    .brightness_enable(brightness_enable_hdmi_ff2),
    .contrast_enable  (contrast_enable_hdmi_ff2),
    .rgb_out          (hdmi_adjusted_rgb_12)
);

osd_status u_osd_status (
    .de               (hdmi_de_d),
    .x                (hdmi_x_d),
    .y                (hdmi_y_d),
    .rgb_in           (hdmi_adjusted_rgb_12),
    .enable           (overlay_enable_hdmi_ff2 && image_display_enable),
    .image_index      (image_index_hdmi_ff2[1:0]),
    .auto_mode        (auto_mode_hdmi_ff2),
    .brightness_enable(brightness_enable_hdmi_ff2),
    .contrast_enable  (contrast_enable_hdmi_ff2),
    .rgb_out          (hdmi_osd_rgb_12)
);

assign hdmi_rgb_12 = hdmi_osd_rgb_12;

assign hdmi_rgb_24 = {
    hdmi_rgb_12[11:8], hdmi_rgb_12[11:8],
    hdmi_rgb_12[7:4],  hdmi_rgb_12[7:4],
    hdmi_rgb_12[3:0],  hdmi_rgb_12[3:0]
};

hdmi_tx u_hdmi_tx (
    .PXLCLK_I   (hdmi_pixel_clk),
    .PXLCLK_5X_I(hdmi_pixel_clk_5x),
    .RST_N      (hdmi_rst_n),
    .VGA_HS     (hdmi_hs_d),
    .VGA_VS     (hdmi_vs_d),
    .VGA_DE     (hdmi_de_d),
    .VGA_RGB    (hdmi_rgb_24),
    .HDMI_CLK_P (hdmi1_clk_p),
    .HDMI_D2_P  (hdmi1_d2_p),
    .HDMI_D1_P  (hdmi1_d1_p),
    .HDMI_D0_P  (hdmi1_d0_p)
);

scaler_fit #(
    .DST_W(640),
    .DST_H(480),
    .SRC_W(IMAGE_W),
    .SRC_H(IMAGE_H)
) u_scaler_fit (
    .de      (vga_de),
    .x       (vga_x),
    .y       (vga_y),
    .fit_de  (fit_de),
    .fit_x   (fit_x),
    .fit_y   (fit_y),
    .fit_w   (),
    .fit_h   (),
    .offset_x(),
    .offset_y()
);

test_pattern u_test_pattern (
    .de            (fit_de),
    .state_code    (status_code[2:0]),
    .image_index   (image_index),
    .overlay_enable(overlay_enable),
    .x             (fit_x),
    .y             (fit_y),
    .rgb           (vga_rgb)
);

// Skeleton-only heartbeat so we can confirm clock/input wiring before the
// real multimedia pipeline is connected.
reg [COUNTER_BITS-1:0] heartbeat_cnt = {COUNTER_BITS{1'b0}};

always @(posedge clk_50m) begin
    heartbeat_cnt <= heartbeat_cnt + {{COUNTER_BITS-1{1'b0}}, 1'b1};
end

assign led[0] = heartbeat_cnt[HEARTBEAT_BIT];
assign led[1] = sd_init_done;
assign led[2] = image_load_busy;
assign led[3] = image_load_done;

assign vga_hs = hdmi_hs;
assign vga_vs = hdmi_vs;
assign vga_d  = hdmi_rgb_12;

endmodule

module video_timing_640x480_pclk (
    input  wire       clk,
    input  wire       rst_n,
    output reg        hs,
    output reg        vs,
    output reg        de,
    output reg [9:0]  x,
    output reg [9:0]  y,
    output reg        frame_tick
);

localparam integer H_VISIBLE = 640;
localparam integer H_FRONT   = 16;
localparam integer H_SYNC    = 96;
localparam integer H_BACK    = 48;
localparam integer H_TOTAL   = 800;

localparam integer V_VISIBLE = 480;
localparam integer V_FRONT   = 10;
localparam integer V_SYNC    = 2;
localparam integer V_BACK    = 33;
localparam integer V_TOTAL   = 525;

reg [9:0] hcnt;
reg [9:0] vcnt;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        hcnt <= 10'd0;
        vcnt <= 10'd0;
        hs <= 1'b1;
        vs <= 1'b1;
        de <= 1'b0;
        x <= 10'd0;
        y <= 10'd0;
        frame_tick <= 1'b0;
    end else begin
        frame_tick <= 1'b0;

        if (hcnt == H_TOTAL - 1) begin
            hcnt <= 10'd0;
            if (vcnt == V_TOTAL - 1) begin
                vcnt <= 10'd0;
                frame_tick <= 1'b1;
            end else begin
                vcnt <= vcnt + 10'd1;
            end
        end else begin
            hcnt <= hcnt + 10'd1;
        end

        x <= hcnt;
        y <= vcnt;
        de <= (hcnt < H_VISIBLE) && (vcnt < V_VISIBLE);
        hs <= ~((hcnt >= H_VISIBLE + H_FRONT) &&
                (hcnt < H_VISIBLE + H_FRONT + H_SYNC));
        vs <= ~((vcnt >= V_VISIBLE + V_FRONT) &&
                (vcnt < V_VISIBLE + V_FRONT + V_SYNC));
    end
end

endmodule

`default_nettype wire
