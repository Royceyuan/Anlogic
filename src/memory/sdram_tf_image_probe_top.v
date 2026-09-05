`timescale 1ns / 1ps
`default_nettype none

// 640x480 RGB565 BIN -> SDRAM -> HDMI probe. The input stream is deliberately
// fixed to top-down raw pixels for this first full-frame hardware milestone.
// This dedicated top does not replace the stable BRAM top.v.
module top (
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

// Store two RGB565 pixels in each 32-bit SDRAM word.  This cuts the
// continuous read bandwidth in half while preserving the 640x480 output.
localparam integer FRAME_WORDS = 153600;

wire mem_clk;
wire mem_clk_sft;
wire video_clk;
wire video_clk_5x;
wire mem_rst_n;
wire video_rst_n;
wire init_done;
wire init_ref_valid;
wire mem_busy;

wire        write_req_ack;
wire        write_finish;
wire        write_fifo_full;
wire [31:0] read_data;
reg         write_req;
reg         frame_written;
reg         frame_ready_toggle;
reg [2:0]   write_state;
reg [18:0]  write_count;
reg [5:0]   write_settle_count;
reg [3:0]   status_code;
wire        write_en;
wire [31:0] write_data;

wire        sd_init_done;
wire        sd_sec_read;
wire [31:0] sd_sec_read_addr;
wire [7:0]  sd_sec_read_data;
wire        sd_sec_read_data_valid;
wire        sd_sec_read_end;
reg         image_load_start;
wire [18:0] image_wr_addr;
wire [15:0] image_wr_data;
wire        image_wr_en;
wire        image_load_busy;
wire        image_load_done;
wire        image_load_error;
wire [3:0]  image_load_status;
wire        packed_valid;
wire [31:0] packed_data;
wire        packer_overflow;

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

localparam [2:0] W_WAIT_INIT = 3'd0;
localparam [2:0] W_REQUEST   = 3'd1;
localparam [2:0] W_SETTLE    = 3'd2;
localparam [2:0] W_STREAM    = 3'd3;
localparam [2:0] W_DRAIN     = 3'd4;
localparam [2:0] W_DONE      = 3'd5;
localparam [2:0] W_ERROR     = 3'd6;

reset_sync u_mem_reset_sync (
    .clk    (mem_clk),
    .arst_n (key_n[0]),
    .srst_n (mem_rst_n)
);

wire write_rst_n;
reset_sync u_write_reset_sync (
    .clk    (clk_50m),
    .arst_n (key_n[0]),
    .srst_n (write_rst_n)
);

reset_sync u_video_reset_sync (
    .clk    (video_clk),
    .arst_n (key_n[0]),
    .srst_n (video_rst_n)
);

sys_pll u_sys_pll (
    .refclk   (clk_50m),
    .reset    (1'b0),
    .clk0_out (),
    .clk1_out (mem_clk),
    .clk2_out (mem_clk_sft)
);

video_pll u_video_pll (
    .refclk   (clk_50m),
    // video_rst_n is generated from video_clk, so it cannot be used to
    // release the PLL itself.  Use the already-running memory reset domain.
    .reset    (~mem_rst_n),
    .clk0_out (video_clk),
    .clk1_out (video_clk_5x)
);

sd_card_top u_sd_card_top (
    .clk                   (clk_50m),
    .rst                   (~write_rst_n),
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
    .sd_sec_write_data_req(),
    .sd_sec_write_end      ()
);

fat32_image_loader #(
    .IMAGE_WIDTH      (640),
    .IMAGE_HEIGHT     (480),
    .IMAGE_ADDR_BITS (19)
) u_fat32_image_loader (
    .clk                   (clk_50m),
    .rst_n                 (write_rst_n),
    .load_start            (image_load_start),
    .image_file_index      ({3'd0, sw[0]}),
    .bmp_mode              (1'b0),
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
    .busy                   (image_load_busy),
    .load_done              (image_load_done),
    .load_error             (image_load_error),
    .status_code            (image_load_status)
);

rgb565_stream_packer u_rgb565_stream_packer (
    .clk       (clk_50m),
    .rst_n     (write_rst_n),
    .in_valid  (image_wr_en),
    .in_pixel  (image_wr_data),
    .out_valid (packed_valid),
    .out_data  (packed_data),
    .out_ready ((write_state == W_STREAM) && !write_fifo_full),
    .overflow  (packer_overflow)
);

assign write_en   = (write_state == W_STREAM) && packed_valid && !write_fifo_full;
assign write_data = packed_data;

// Hold the request until the frame FIFO acknowledges it, then leave enough
// cycles for its asynchronous FIFO reset to release before streaming data.
always @(posedge clk_50m or negedge write_rst_n) begin
    if (!write_rst_n) begin
        write_req         <= 1'b0;
        frame_written     <= 1'b0;
        frame_ready_toggle<= 1'b0;
        write_state       <= W_WAIT_INIT;
        write_count       <= 19'd0;
        write_settle_count<= 6'd0;
        image_load_start  <= 1'b0;
    end else begin
        image_load_start <= 1'b0;
        case (write_state)
            W_WAIT_INIT: begin
                if (init_done && sd_init_done)
                    write_state <= W_REQUEST;
            end

            W_REQUEST: begin
                write_req <= 1'b1;
                if (write_req_ack) begin
                    write_req          <= 1'b0;
                    write_settle_count <= 6'd0;
                    write_count        <= 19'd0;
                    write_state        <= W_SETTLE;
                end
            end

            W_SETTLE: begin
                if (write_settle_count == 6'd63) begin
                    image_load_start <= 1'b1;
                    write_state <= W_STREAM;
                end else
                    write_settle_count <= write_settle_count + 6'd1;
            end

            W_STREAM: begin
                if (image_load_error || packer_overflow)
                    write_state <= W_ERROR;
                if (write_en) begin
                    if (write_count == FRAME_WORDS - 1) begin
                        write_state <= W_DRAIN;
                    end else begin
                        write_count <= write_count + 19'd1;
                    end
                end
            end

            W_DRAIN: begin
                if (write_finish) begin
                    frame_written      <= 1'b1;
                    frame_ready_toggle <= ~frame_ready_toggle;
                    write_state        <= W_DONE;
                end
            end

            W_DONE: begin
                write_state <= W_DONE;
            end

            W_ERROR: begin
                write_state <= W_ERROR;
            end

            default: begin
                write_state <= W_WAIT_INIT;
            end
        endcase
    end
end

always @(*) begin
    case (write_state)
        W_WAIT_INIT: status_code = 4'h0;
        W_REQUEST:   status_code = 4'h1;
        W_SETTLE:    status_code = 4'h2;
        W_STREAM:    status_code = 4'h3;
        W_DRAIN:     status_code = 4'h4;
        W_ERROR:     status_code = 4'hf;
        default:     status_code = 4'h5;
    endcase
end

wire        read_en;
wire        video_read_en;
wire        video_read_req;
wire        video_read_req_ack;
wire        video_read_finish;
wire        read_fifo_empty;
wire        video_hs_i;
wire        video_vs_i;
wire        video_de_i;
wire        video_frame_tick;
wire        video_hs;
wire        video_vs;
wire        video_de;
wire [23:0] video_rgb;
wire [9:0]  video_x_i;
wire [9:0]  video_y_i;
wire [11:0] video_rgb_12;
wire [11:0] video_rgb_adjusted_12;
wire [11:0] video_rgb_osd_12;
wire [23:0] video_rgb_post;
wire [9:0]  video_x_d;
wire [9:0]  video_y_d;

reg ready_ff1;
reg ready_ff2;
reg ready_seen;
reg read_req_r;
reg read_ack_ff1;
reg read_ack_ff2;
reg       video_run;
reg [25:0] heartbeat_count;
reg [11:0] read_prefill_count;
reg        read_accepted;
reg        read_ready;
reg        pair_phase;
reg        pair_word_valid;
reg        underflow_seen;
wire [23:0] unpacked_rgb;
wire [3:0] key_level_n;
wire [3:0] key_press_pulse;
wire [3:0] key_release_pulse;
reg        overlay_enable;
reg        overlay_enable_ff1;
reg        overlay_enable_ff2;
reg        brightness_enable_ff1;
reg        brightness_enable_ff2;
reg        contrast_enable_ff1;
reg        contrast_enable_ff2;
reg        image_index_ff1;
reg        image_index_ff2;
reg [209:0] video_x_delay;
reg [209:0] video_y_delay;

assign video_read_req = read_req_r;
assign read_en        = video_read_en && video_run && !pair_phase;
// The one-cycle read latency in video_delay makes phase=1 the first
// displayed half-word.  Keep the experimentally verified low/high order.
// The FIFO word becomes valid one clock after the request.  phase=1 is thus
// the first displayed half-word; the writer's first pixel is the high half.
assign unpacked_rgb   = pair_word_valid ?
                       (pair_phase ? expand_pixel565(read_data[31:16])
                                    : expand_pixel565(read_data[15:0]))
                       : 24'h000000;
assign video_x_d = video_x_delay[209:200];
assign video_y_d = video_y_delay[209:200];

// Keep the existing reset key separate from the three user controls.  The
// overlay state is held in the 50 MHz domain and synchronized into video.
key_debounce u_key_debounce (
    .clk              (clk_50m),
    .rst_n            (write_rst_n),
    .key_n            (key_n),
    .key_level_n      (key_level_n),
    .key_press_pulse  (key_press_pulse),
    .key_release_pulse(key_release_pulse)
);

always @(posedge clk_50m or negedge write_rst_n) begin
    if (!write_rst_n)
        overlay_enable <= 1'b1;
    else if (key_press_pulse[3])
        overlay_enable <= ~overlay_enable;
end

// The frame reader is requested once after the write is complete.  Its memory
// side loops over the completed frame, so the video side can remain aligned
// without clearing the FIFO at every frame boundary.
always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin
        ready_ff1     <= 1'b0;
        ready_ff2     <= 1'b0;
        ready_seen    <= 1'b0;
        read_req_r    <= 1'b0;
        read_ack_ff1  <= 1'b0;
        read_ack_ff2  <= 1'b0;
        read_prefill_count <= 12'd0;
        read_accepted <= 1'b0;
        read_ready    <= 1'b0;
        video_run     <= 1'b0;
        pair_phase    <= 1'b0;
        pair_word_valid <= 1'b0;
        underflow_seen <= 1'b0;
    end else begin
        ready_ff1    <= frame_ready_toggle;
        ready_ff2    <= ready_ff1;
        read_ack_ff1 <= video_read_req_ack;
        read_ack_ff2 <= read_ack_ff1;

        if (!video_run && !read_accepted && !read_ready &&
            (ready_ff2 != ready_seen)) begin
            ready_seen <= ready_ff2;
            read_req_r <= 1'b1;
        end else if (read_req_r && read_ack_ff2) begin
            read_req_r    <= 1'b0;
            read_prefill_count <= 12'd0;
            read_accepted <= 1'b1;
        end

        if (!video_run && read_accepted && !read_ready) begin
            if (read_prefill_count == 12'd2047)
                read_ready <= 1'b1;
            else
                read_prefill_count <= read_prefill_count + 12'd1;
        end

        // The frame reader loops in the memory domain.  Start consuming only
        // at a video frame boundary so FIFO word zero maps to pixel (0, 0).
        if (!video_run && read_ready && video_frame_tick) begin
            video_run       <= 1'b1;
            read_ready      <= 1'b0;
            pair_phase      <= 1'b0;
            pair_word_valid <= 1'b0;
        end else if (video_run && video_read_en) begin
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

video_timing_640x480_pclk u_video_timing (
    .clk        (video_clk),
    .rst_n      (video_rst_n),
    .hs         (video_hs_i),
    .vs         (video_vs_i),
    .de         (video_de_i),
    .x          (video_x_i),
    .y          (video_y_i),
    .frame_tick (video_frame_tick)
);

video_delay u_video_delay (
    .video_clk (video_clk),
    .rst       (~video_rst_n),
    .read_en   (video_read_en),
    .read_data (unpacked_rgb),
    .hs        (video_hs_i),
    .vs        (video_vs_i),
    .de        (video_de_i),
    .hs_r      (video_hs),
    .vs_r      (video_vs),
    .de_r      (video_de),
    .vout_data (video_rgb)
);

// video_delay delays timing by 20 pixel clocks. Delay coordinates by the same
// amount so the OSD panel tracks the actual HDMI pixel, not the source pixel.
always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin
        video_x_delay <= 210'd0;
        video_y_delay <= 210'd0;
        overlay_enable_ff1 <= 1'b0;
        overlay_enable_ff2 <= 1'b0;
        brightness_enable_ff1 <= 1'b0;
        brightness_enable_ff2 <= 1'b0;
        contrast_enable_ff1 <= 1'b0;
        contrast_enable_ff2 <= 1'b0;
        image_index_ff1 <= 1'b0;
        image_index_ff2 <= 1'b0;
    end else begin
        video_x_delay <= {video_x_delay[199:0], video_x_i};
        video_y_delay <= {video_y_delay[199:0], video_y_i};
        overlay_enable_ff1 <= overlay_enable;
        overlay_enable_ff2 <= overlay_enable_ff1;
        brightness_enable_ff1 <= sw[1];
        brightness_enable_ff2 <= brightness_enable_ff1;
        contrast_enable_ff1 <= sw[2];
        contrast_enable_ff2 <= contrast_enable_ff1;
        image_index_ff1 <= sw[0];
        image_index_ff2 <= image_index_ff1;
    end
end

assign video_rgb_12 = {video_rgb[23:20], video_rgb[15:12], video_rgb[7:4]};

rgb_adjust u_rgb_adjust (
    .de               (video_de),
    .rgb_in           (video_rgb_12),
    .brightness_enable(brightness_enable_ff2),
    .contrast_enable  (contrast_enable_ff2),
    .rgb_out          (video_rgb_adjusted_12)
);

osd_status u_osd_status (
    .de               (video_de),
    .x                (video_x_d),
    .y                (video_y_d),
    .rgb_in           (video_rgb_adjusted_12),
    .enable           (overlay_enable_ff2),
    .image_index      ({1'b0, image_index_ff2}),
    .auto_mode        (1'b0),
    .brightness_enable(brightness_enable_ff2),
    .contrast_enable  (contrast_enable_ff2),
    .rgb_out          (video_rgb_osd_12)
);

assign video_rgb_post = {
    video_rgb_osd_12[11:8], video_rgb_osd_12[11:8],
    video_rgb_osd_12[7:4],  video_rgb_osd_12[7:4],
    video_rgb_osd_12[3:0],  video_rgb_osd_12[3:0]
};

anlogic_frame_store #(
    .READ_LOOP       (1)
) u_frame_store (
    .mem_clk         (mem_clk),
    .mem_clk_sft     (mem_clk_sft),
    .rst_n           (mem_rst_n),
    .init_done       (init_done),
    .init_ref_valid  (init_ref_valid),
    .mem_busy        (mem_busy),
    .write_clk       (clk_50m),
    .write_req       (write_req),
    .write_req_ack   (write_req_ack),
    .write_finish    (write_finish),
    .write_fifo_full (write_fifo_full),
    .write_base_addr (21'd0),
    .write_len       (21'd153600),
    .write_en        (write_en),
    .write_data      (write_data),
    .read_clk        (video_clk),
    .read_req        (video_read_req),
    .read_req_ack    (video_read_req_ack),
    .read_finish     (video_read_finish),
    .read_fifo_valid (),
    .read_fifo_empty (read_fifo_empty),
    .read_base_addr  (21'd0),
    .read_len        (21'd153600),
    .read_en         (read_en),
    .read_data       (read_data)
);

always @(posedge mem_clk or negedge mem_rst_n) begin
    if (!mem_rst_n)
        heartbeat_count <= 26'd0;
    else
        heartbeat_count <= heartbeat_count + 26'd1;
end

seg_hex_display u_seg_hex_display (
    .clk     (mem_clk),
    .rst_n   (mem_rst_n),
    .value   ({status_code, write_count[11:0]}),
    .seg_data(seg_data),
    .seg_sel (seg_sel)
);

assign led[0] = heartbeat_count[25];
assign led[1] = init_done;
assign led[2] = frame_written;
// LED4 stays on only while video is running without a detected FIFO underflow.
assign led[3] = video_run && !underflow_seen;

assign vga_hs = video_hs;
assign vga_vs = video_vs;
assign vga_d  = video_rgb_osd_12;

hdmi_tx u_hdmi_tx (
    .PXLCLK_I    (video_clk),
    .PXLCLK_5X_I (video_clk_5x),
    .RST_N       (video_rst_n),
    .VGA_HS      (video_hs),
    .VGA_VS      (video_vs),
    .VGA_DE      (video_de),
    .VGA_RGB     (video_rgb_post),
    .HDMI_CLK_P  (hdmi1_clk_p),
    .HDMI_D2_P   (hdmi1_d2_p),
    .HDMI_D1_P   (hdmi1_d1_p),
    .HDMI_D0_P   (hdmi1_d0_p)
);

endmodule

`default_nettype wire
