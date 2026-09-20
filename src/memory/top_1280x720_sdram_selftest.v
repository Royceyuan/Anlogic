`timescale 1ns / 1ps
`default_nettype none

// Hardware isolation probe: write a deterministic 960x540 RGB565 frame to
// the same SDRAM/FIFO path used by the 1280x720 media player, then read it
// through the production three-line scaler.  It deliberately has no TF/BMP
// logic, so its board result separates the SDRAM/display path from loading.
module top_1280x720_sdram_selftest #(
    parameter integer HOST_RESET_ON_BOARD_CLK = 0,
    parameter integer DIRECT_VIDEO_PATTERN = 0,
    parameter integer LINEBUF_REGISTER_READ = 0,
    parameter integer LINEBUF_NOREG_SYNC_READ = 0,
    parameter integer LOCAL_SOURCE = 0
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

localparam integer SOURCE_W = 960;
localparam integer SOURCE_H = 540;
localparam [20:0] FRAME_WORDS = 21'd259200;
localparam [2:0] W_WAIT_INIT = 3'd0;
localparam [2:0] W_REQUEST   = 3'd1;
localparam [2:0] W_SETTLE    = 3'd2;
localparam [2:0] W_STREAM    = 3'd3;
localparam [2:0] W_DRAIN     = 3'd4;
localparam [2:0] W_DONE      = 3'd5;
localparam integer LINEBUF_SYNC_READ =
    LINEBUF_REGISTER_READ || LINEBUF_NOREG_SYNC_READ;

wire mem_clk, mem_clk_sft, video_clk, video_clk_5x;
wire mem_rst_n, video_rst_n, host_rst_n, init_done, init_ref_valid, mem_busy;
wire write_rst_n = HOST_RESET_ON_BOARD_CLK ? host_rst_n : mem_rst_n;
wire write_req_ack, write_finish, write_fifo_full;
wire [31:0] frame_read_data;
reg [31:0] local_read_data;
reg local_read_valid;
reg [8:0] local_pair_x;
reg [9:0] local_y;
reg write_req;
reg frame_written;
reg frame_ready_toggle;
reg [2:0] write_state;
reg [18:0] write_count;
reg [5:0] write_settle_count;
reg [8:0] frame_pair_x;
reg [9:0] frame_y;
reg [25:0] heartbeat_count;

wire source_read_req;
wire frame_source_read_ack;
wire [20:0] source_read_base_addr;
wire [20:0] source_read_len;
wire frame_source_fifo_empty;
wire frame_source_fifo_valid;
wire source_read_en;
wire source_read_ack = LOCAL_SOURCE ? source_read_req : frame_source_read_ack;
wire source_fifo_empty = LOCAL_SOURCE ? 1'b0 : frame_source_fifo_empty;
wire source_fifo_valid = LOCAL_SOURCE ? local_read_valid : frame_source_fifo_valid;
wire [31:0] read_data = LOCAL_SOURCE ? local_read_data : frame_read_data;
wire [15:0] linebuf_pixel565;
wire linebuf_frame_ready;
wire linebuf_source_frame_done;
wire linebuf_underflow;
reg ready_ff1, ready_ff2, ready_seen;
reg linebuf_start_pulse, linebuf_start_pending;
reg local_source_started;
reg video_run;
reg underflow_seen;
reg [319:0] pixel_pipe;
reg [303:0] pixel_pipe_reg;

wire video_hs_i, video_vs_i, video_de_i, video_frame_tick;
wire [10:0] video_x_i;
wire [9:0] video_y_i;
// A registered line-buffer read needs the address for the first visible
// pixel already present during the preceding horizontal blanking interval.
// The timing generator exposes the last blanking coordinate at that edge;
// clamp only the registered-read diagnostic path to column zero so its first
// active pixel is not filled with the previous line's stale/blank value.
wire [10:0] linebuf_video_x =
    (LINEBUF_SYNC_READ && !video_de_i) ? 11'd0 : video_x_i;
wire [12:0] direct_x_times3 = {2'b00, video_x_i} + ({2'b00, video_x_i} << 1);
wire [11:0] direct_y_times3 = {2'b00, video_y_i} + ({2'b00, video_y_i} << 1);
wire [15:0] direct_pixel565 = make_test_pixel565(direct_x_times3 >> 2,
                                                  direct_y_times3 >> 2);
wire video_hs, video_vs, video_de, video_read_en;
wire [23:0] video_rgb;
wire [23:0] video_rgb_out;
wire video_hs_out, video_vs_out, video_de_out;
reg hs_q, vs_q, de_q, hs_q_d, vs_q_d, de_q_d;
reg [23:0] rgb_q, rgb_q_d;
reg [3:0] status_code;

function [15:0] make_test_pixel565;
    input [9:0] px;
    input [9:0] py;
    reg [7:0] r;
    reg [7:0] g;
    reg [7:0] b;
    begin
        if (px < 10'd160) begin
            r = 8'hff; g = 8'hff; b = 8'hff;
        end else if (px < 10'd320) begin
            r = 8'hff; g = 8'hff; b = 8'h00;
        end else if (px < 10'd480) begin
            r = 8'h00; g = 8'hff; b = 8'hff;
        end else if (px < 10'd640) begin
            r = 8'h00; g = 8'hff; b = 8'h00;
        end else if (px < 10'd800) begin
            r = 8'hff; g = 8'h00; b = 8'hff;
        end else begin
            r = 8'hff; g = 8'h00; b = 8'h00;
        end
        if (py[6] || px[5] == py[5]) begin
            r = r >> 1;
            g = g >> 1;
            b = b >> 1;
        end
        make_test_pixel565 = {r[7:3], g[7:2], b[7:3]};
    end
endfunction

function [23:0] expand_pixel565;
    input [15:0] pixel;
    begin
        expand_pixel565 = {{pixel[15:11], pixel[15:13]},
                           {pixel[10:5], pixel[10:9]},
                           {pixel[4:0], pixel[4:2]}};
    end
endfunction

wire write_en = (write_state == W_STREAM) && !write_fifo_full;
wire [31:0] write_data = {
    make_test_pixel565({frame_pair_x, 1'b0}, frame_y),
    make_test_pixel565({frame_pair_x, 1'b1}, frame_y)
};

reset_sync u_mem_reset_sync (
    .clk(mem_clk), .arst_n(key_n[0]), .srst_n(mem_rst_n)
);
reset_sync u_host_reset_sync (
    .clk(clk_50m), .arst_n(key_n[0]), .srst_n(host_rst_n)
);
reset_sync u_video_reset_sync (
    .clk(video_clk), .arst_n(key_n[0]), .srst_n(video_rst_n)
);
sys_pll u_sys_pll (
    .refclk(clk_50m), .reset(1'b0), .clk0_out(),
    .clk1_out(mem_clk), .clk2_out(mem_clk_sft)
);
video_pll_75m u_video_pll (
    .refclk(clk_50m), .reset(HOST_RESET_ON_BOARD_CLK ? ~key_n[0] : ~mem_rst_n),
    .clk0_out(video_clk), .clk1_out(video_clk_5x)
);

// Optional source used only by the v25 isolation bit.  It preserves the
// scaler/BRAM/HDMI path while removing SDRAM and both asynchronous FIFOs.
always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin
        local_read_data  <= 32'd0;
        local_read_valid <= 1'b0;
        local_pair_x     <= 9'd0;
        local_y          <= 10'd0;
    end else begin
        local_read_valid <= source_read_en;
        if (linebuf_start_pulse) begin
            local_pair_x <= 9'd0;
            local_y      <= 10'd0;
        end
        if (source_read_en) begin
            local_read_data <= {
                make_test_pixel565({local_pair_x, 1'b0}, local_y),
                make_test_pixel565({local_pair_x, 1'b1}, local_y)
            };
            if (local_pair_x == SOURCE_W / 2 - 1) begin
                local_pair_x <= 9'd0;
                local_y      <= (local_y == SOURCE_H - 1) ? 10'd0 : local_y + 1'b1;
            end else begin
                local_pair_x <= local_pair_x + 1'b1;
            end
        end
    end
end

always @(posedge clk_50m or negedge write_rst_n) begin
    if (!write_rst_n) begin
        write_req <= 1'b0;
        frame_written <= 1'b0;
        frame_ready_toggle <= 1'b0;
        write_state <= W_WAIT_INIT;
        write_count <= 19'd0;
        write_settle_count <= 6'd0;
        frame_pair_x <= 9'd0;
        frame_y <= 10'd0;
    end else begin
        case (write_state)
            W_WAIT_INIT: if (init_done) write_state <= W_REQUEST;
            W_REQUEST: begin
                write_req <= 1'b1;
                if (write_req_ack) begin
                    write_req <= 1'b0;
                    write_settle_count <= 6'd0;
                    write_count <= 19'd0;
                    frame_pair_x <= 9'd0;
                    frame_y <= 10'd0;
                    write_state <= W_SETTLE;
                end
            end
            W_SETTLE: begin
                if (write_settle_count == 6'd63)
                    write_state <= W_STREAM;
                else
                    write_settle_count <= write_settle_count + 1'b1;
            end
            W_STREAM: if (write_en) begin
                if (write_count == FRAME_WORDS - 1) begin
                    write_state <= W_DRAIN;
                end else begin
                    write_count <= write_count + 1'b1;
                    if (frame_pair_x == SOURCE_W / 2 - 1) begin
                        frame_pair_x <= 9'd0;
                        frame_y <= frame_y + 1'b1;
                    end else begin
                        frame_pair_x <= frame_pair_x + 1'b1;
                    end
                end
            end
            W_DRAIN: if (write_finish) begin
                frame_written <= 1'b1;
                frame_ready_toggle <= ~frame_ready_toggle;
                write_state <= W_DONE;
            end
            default: write_state <= W_DONE;
        endcase
    end
end

always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin
        ready_ff1 <= 1'b0;
        ready_ff2 <= 1'b0;
        ready_seen <= 1'b0;
        linebuf_start_pulse <= 1'b0;
        linebuf_start_pending <= 1'b0;
        local_source_started <= 1'b0;
        video_run <= 1'b0;
        underflow_seen <= 1'b0;
        pixel_pipe <= 320'd0;
        pixel_pipe_reg <= 304'd0;
    end else begin
        linebuf_start_pulse <= 1'b0;
        if (LOCAL_SOURCE && !local_source_started) begin
            linebuf_start_pending <= 1'b1;
            local_source_started <= 1'b1;
        end
        if (linebuf_start_pending) begin
            linebuf_start_pulse <= 1'b1;
            linebuf_start_pending <= 1'b0;
        end
        ready_ff1 <= frame_ready_toggle;
        ready_ff2 <= ready_ff1;
        if (!video_run && ready_ff2 != ready_seen) begin
            ready_seen <= ready_ff2;
            linebuf_start_pending <= 1'b1;
        end
        // The scaler follows frame_fifo_read's continuous source loop.  Do
        // not clear the asynchronous FIFO at every display-frame boundary.
        if (DIRECT_VIDEO_PATTERN)
            video_run <= 1'b1;
        else if (!video_run && linebuf_frame_ready &&
            video_x_i == 11'd0 && video_y_i == 10'd0)
            video_run <= 1'b1;
        if (!DIRECT_VIDEO_PATTERN && video_run && linebuf_underflow)
            underflow_seen <= 1'b1;
        pixel_pipe <= {pixel_pipe[303:0],
                       (DIRECT_VIDEO_PATTERN ? direct_pixel565 : linebuf_pixel565)};
        pixel_pipe_reg <= {pixel_pipe_reg[287:0], linebuf_pixel565};
    end
end

anlogic_frame_store #(
    .READ_LOOP(1), .BURST_SIZE(32), .WRITE_BURST_SIZE(32),
    .READ_BURST_SIZE(64)
) u_frame_store (
    .mem_clk(mem_clk), .mem_clk_sft(mem_clk_sft), .rst_n(mem_rst_n),
    .init_done(init_done), .init_ref_valid(init_ref_valid), .mem_busy(mem_busy),
    .write_clk(clk_50m), .write_req(write_req), .write_req_ack(write_req_ack),
    .write_finish(write_finish), .write_fifo_full(write_fifo_full),
    .write_base_addr(21'd0), .write_len(FRAME_WORDS),
    .write_en(write_en), .write_data(write_data),
    .read_clk(video_clk), .read_req(source_read_req),
    .read_req_ack(frame_source_read_ack), .read_finish(),
    .read_fifo_valid(frame_source_fifo_valid),
    .read_fifo_empty(frame_source_fifo_empty), .read_base_addr(source_read_base_addr),
    .read_len(source_read_len), .read_en(source_read_en), .read_data(frame_read_data)
);

linebuf_scaler_960x540_to_1280x720 #(
    .SRC_W(SOURCE_W), .SRC_H(SOURCE_H), .DST_W(1280), .DST_H(720),
    .LINEBUF_REGISTER_READ(LINEBUF_REGISTER_READ),
    .LINEBUF_NOREG_SYNC_READ(LINEBUF_NOREG_SYNC_READ)
) u_linebuf_scaler (
    .clk(video_clk), .rst_n(video_rst_n), .source_start(linebuf_start_pulse),
    .zoom_2x(1'b0),
    .museum_recenter_active(1'b0), .museum_recenter_closing(1'b0),
    .museum_recenter_progress(8'd0), .museum_recenter_origin(3'd0),
    .source_base_addr(21'd0), .source_read_req(source_read_req),
    .source_read_ack(source_read_ack), .source_read_base_addr(source_read_base_addr),
    .source_read_len(source_read_len), .source_fifo_empty(source_fifo_empty),
    .source_fifo_valid(source_fifo_valid),
    .source_read_en(source_read_en), .source_read_data(read_data),
    .video_de(video_run ? video_de_i : 1'b0), .video_x(linebuf_video_x),
    .video_y(video_y_i), .pixel565(linebuf_pixel565),
    .frame_ready(linebuf_frame_ready), .source_frame_done(linebuf_source_frame_done),
    .underflow(linebuf_underflow)
);

video_timing_640x480_pclk #(
    .H_VISIBLE(1280), .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_VISIBLE(720), .V_FRONT(5), .V_SYNC(5), .V_BACK(20), .X_BITS(11)
) u_video_timing (
    .clk(video_clk), .rst_n(video_rst_n), .hs(video_hs_i), .vs(video_vs_i),
    .de(video_de_i), .x(video_x_i), .y(video_y_i), .frame_tick(video_frame_tick)
);

video_delay u_video_delay (
    .video_clk(video_clk), .rst(~video_rst_n), .read_en(video_read_en),
    .read_data(expand_pixel565(LINEBUF_SYNC_READ ?
                               pixel_pipe_reg[303:288] : pixel_pipe[319:304])),
    .hs(video_hs_i),
    .vs(video_vs_i), .de(video_de_i), .hs_r(video_hs), .vs_r(video_vs),
    .de_r(video_de), .vout_data(video_rgb)
);

always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin
        hs_q <= 1'b1; vs_q <= 1'b1; de_q <= 1'b0;
        hs_q_d <= 1'b1; vs_q_d <= 1'b1; de_q_d <= 1'b0;
        rgb_q <= 24'd0; rgb_q_d <= 24'd0;
    end else begin
        hs_q <= video_hs; vs_q <= video_vs; de_q <= video_de;
        hs_q_d <= hs_q; vs_q_d <= vs_q; de_q_d <= de_q;
        rgb_q <= video_rgb; rgb_q_d <= rgb_q;
    end
end

always @(posedge mem_clk or negedge mem_rst_n) begin
    if (!mem_rst_n)
        heartbeat_count <= 26'd0;
    else
        heartbeat_count <= heartbeat_count + 1'b1;
end

always @(*) begin
    if (underflow_seen)
        status_code = 4'hf;
    else
        status_code = {1'b0, write_state};
end

assign video_hs_out = hs_q_d;
assign video_vs_out = vs_q_d;
assign video_de_out = de_q_d;
assign video_rgb_out = rgb_q_d;
assign led[0] = heartbeat_count[25];
assign led[1] = init_done;
assign led[2] = frame_written;
assign led[3] = video_run && !underflow_seen;

seg_hex_display u_seg_hex_display (
    .clk(mem_clk), .rst_n(mem_rst_n),
    .value({status_code, 4'h0, write_count[7:4], write_count[3:0]}),
    .seg_data(seg_data), .seg_sel(seg_sel)
);

assign sd_clk = 1'b0;
assign sd_mosi = 1'b0;
assign sd_cs_n = 1'b1;
assign vga_hs = video_hs_out;
assign vga_vs = video_vs_out;
assign vga_d = {video_rgb_out[23:20], video_rgb_out[15:12], video_rgb_out[7:4]};

hdmi_tx u_hdmi_tx (
    .PXLCLK_I(video_clk), .PXLCLK_5X_I(video_clk_5x), .RST_N(video_rst_n),
    .VGA_HS(video_hs_out), .VGA_VS(video_vs_out), .VGA_DE(video_de_out),
    .VGA_RGB(video_rgb_out), .HDMI_CLK_P(hdmi1_clk_p),
    .HDMI_D2_P(hdmi1_d2_p), .HDMI_D1_P(hdmi1_d1_p), .HDMI_D0_P(hdmi1_d0_p)
);

endmodule

// v19: fixed RGB565 scaler self-test using the proven official SDRAM clock.
module top_1280x720_sdram_selftest_v19_reference (
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
top_1280x720_sdram_selftest #(
    .HOST_RESET_ON_BOARD_CLK(1)
) u_selftest (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk),
    .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v20: reloads the three line buffers every vertical blank and keeps RGB
// latency matched to the registered HDMI timing signals.
module top_1280x720_sdram_selftest_v20_reference (
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
top_1280x720_sdram_selftest #(
    .HOST_RESET_ON_BOARD_CLK(1)
) u_selftest (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk),
    .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v21: same HDMI raster and colour pattern as v20, with the source pixels
// generated directly in the video clock domain.  It isolates HDMI timing
// from SDRAM/FIFO/line-buffer frame scheduling.
module top_1280x720_sdram_direct_pattern_v21 (
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
top_1280x720_sdram_selftest #(
    .HOST_RESET_ON_BOARD_CLK(1),
    .DIRECT_VIDEO_PATTERN(1)
) u_selftest (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk),
    .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v22: reload the three line buffers at the delayed HDMI frame boundary.
module top_1280x720_sdram_selftest_v22_frame_boundary (
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
top_1280x720_sdram_selftest #(
    .HOST_RESET_ON_BOARD_CLK(1)
) u_selftest (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk),
    .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v23: continuous SDRAM/FIFO source loop with epoch-tagged line buffers.
module top_1280x720_sdram_selftest_v23_continuous_loop (
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
top_1280x720_sdram_selftest #(
    .HOST_RESET_ON_BOARD_CLK(1)
) u_selftest (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk),
    .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v24: use registered BRAM read data for the three output line buffers.
module top_1280x720_sdram_selftest_v24_bram_readreg (
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
top_1280x720_sdram_selftest #(
    .HOST_RESET_ON_BOARD_CLK(1),
    .LINEBUF_REGISTER_READ(1)
) u_selftest (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk),
    .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v25: line-buffer/scaler isolation with a video-clock-local source stream.
module top_1280x720_linebuf_local_pattern_v25 (
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
top_1280x720_sdram_selftest #(
    .HOST_RESET_ON_BOARD_CLK(1),
    .LOCAL_SOURCE(1)
) u_selftest (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk),
    .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v26: local source plus registered line-buffer BRAM read.
module top_1280x720_linebuf_local_bram_readreg_v26 (
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
top_1280x720_sdram_selftest #(
    .HOST_RESET_ON_BOARD_CLK(1),
    .LINEBUF_REGISTER_READ(1),
    .LOCAL_SOURCE(1)
) u_selftest (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk),
    .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

`default_nettype wire
