`timescale 1ns / 1ps
`default_nettype none

// Standalone burst-frame experiment. The formal TF/HDMI player is unchanged.
// A generated 640x480 test frame is written to the official SDRAM burst path,
// then read back through the video-side FIFO and displayed on HDMI.
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
reg [8:0]   frame_pair_x;
reg [8:0]   frame_y;
reg [3:0]   status_code;
wire        write_en;
wire [31:0] write_data;

function [15:0] make_test_pixel565;
    input [9:0] px;
    input [8:0] py;
    reg [7:0] r;
    reg [7:0] g;
    reg [7:0] b;
    begin
        if (py < 9'd240) begin
            if (px < 10'd320) begin
                r = 8'hff; g = 8'h00; b = 8'h00;
            end else begin
                r = 8'h00; g = 8'hff; b = 8'h00;
            end
        end else begin
            if (px < 10'd320) begin
                r = 8'h00; g = 8'h00; b = 8'hff;
            end else begin
                r = 8'hff; g = 8'hff; b = 8'h00;
            end
        end
        make_test_pixel565 = {r[7:3], g[7:2], b[7:3]};
    end
endfunction

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

reset_sync u_mem_reset_sync (
    .clk    (mem_clk),
    .arst_n (key_n[0]),
    .srst_n (mem_rst_n)
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

// The SDRAM writer drains an asynchronous 512-word FIFO.  Do not advance the
// generated frame while that FIFO is full, otherwise pixels are silently lost
// and the writer can never reach its requested frame length.
assign write_en   = (write_state == W_STREAM) && !write_fifo_full;
assign write_data = {
    make_test_pixel565({frame_pair_x, 1'b1}, frame_y),
    make_test_pixel565({frame_pair_x, 1'b0}, frame_y)
};

// Hold the request until the frame FIFO acknowledges it, then leave enough
// cycles for its asynchronous FIFO reset to release before streaming data.
always @(posedge mem_clk or negedge mem_rst_n) begin
    if (!mem_rst_n) begin
        write_req         <= 1'b0;
        frame_written     <= 1'b0;
        frame_ready_toggle<= 1'b0;
        write_state       <= W_WAIT_INIT;
        write_count       <= 19'd0;
        write_settle_count<= 6'd0;
        frame_pair_x      <= 9'd0;
        frame_y           <= 9'd0;
    end else begin
        case (write_state)
            W_WAIT_INIT: begin
                if (init_done)
                    write_state <= W_REQUEST;
            end

            W_REQUEST: begin
                write_req <= 1'b1;
                if (write_req_ack) begin
                    write_req          <= 1'b0;
                    write_settle_count <= 6'd0;
                    write_count        <= 19'd0;
                    frame_pair_x       <= 9'd0;
                    frame_y            <= 9'd0;
                    write_state        <= W_SETTLE;
                end
            end

            W_SETTLE: begin
                if (write_settle_count == 6'd63)
                    write_state <= W_STREAM;
                else
                    write_settle_count <= write_settle_count + 6'd1;
            end

            W_STREAM: begin
                if (write_en) begin
                    if (write_count == FRAME_WORDS - 1) begin
                        write_state <= W_DRAIN;
                    end else begin
                        write_count <= write_count + 19'd1;
                        if (frame_pair_x == 9'd319) begin
                            frame_pair_x <= 9'd0;
                            frame_y <= frame_y + 9'd1;
                        end else begin
                            frame_pair_x <= frame_pair_x + 9'd1;
                        end
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

assign video_read_req = read_req_r;
assign read_en        = video_read_en && video_run && !pair_phase;
// The one-cycle FIFO read latency makes phase=1 the first displayed half-word.
// The writer stores the first raster pixel in [31:16], so emit high then low.
assign unpacked_rgb   = pair_word_valid ?
                       (pair_phase ? expand_pixel565(read_data[31:16])
                                    : expand_pixel565(read_data[15:0]))
                       : 24'h000000;

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
    .x          (),
    .y          (),
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

anlogic_frame_store #(
    .READ_LOOP       (1)
) u_frame_store (
    .mem_clk         (mem_clk),
    .mem_clk_sft     (mem_clk_sft),
    .rst_n           (mem_rst_n),
    .init_done       (init_done),
    .init_ref_valid  (init_ref_valid),
    .mem_busy        (mem_busy),
    .write_clk       (mem_clk),
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

assign sd_clk  = 1'b0;
assign sd_mosi = 1'b0;
assign sd_cs_n = 1'b1;

assign vga_hs = video_hs;
assign vga_vs = video_vs;
assign vga_d  = {video_rgb[23:20], video_rgb[15:12], video_rgb[7:4]};

hdmi_tx u_hdmi_tx (
    .PXLCLK_I    (video_clk),
    .PXLCLK_5X_I (video_clk_5x),
    .RST_N       (video_rst_n),
    .VGA_HS      (video_hs),
    .VGA_VS      (video_vs),
    .VGA_DE      (video_de),
    .VGA_RGB     (video_rgb),
    .HDMI_CLK_P  (hdmi1_clk_p),
    .HDMI_D2_P   (hdmi1_d2_p),
    .HDMI_D1_P   (hdmi1_d1_p),
    .HDMI_D0_P   (hdmi1_d0_p)
);

endmodule

`default_nettype wire
