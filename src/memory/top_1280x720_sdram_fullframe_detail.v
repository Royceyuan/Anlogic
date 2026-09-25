`timescale 1ns / 1ps
`default_nettype none

// Detailed readback diagnostic. Exhibit switches select the captured first
// mismatch and the total mismatch count without changing the SDRAM traffic.
module top_1280x720_sdram_fullframe_detail (
    input wire clk_50m, input wire [3:0] key_n,
    input wire emergency_sw, input wire [2:0] exhibit_sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p,
    output wire hdmi1_d1_p, output wire hdmi1_d0_p
);

localparam [20:0] TEST_WORDS = 21'd460800;
localparam [2:0] S_WAIT_INIT = 3'd0;
localparam [2:0] S_REQUEST   = 3'd1;
localparam [2:0] S_SETTLE    = 3'd2;
localparam [2:0] S_STREAM    = 3'd3;
localparam [2:0] S_DRAIN     = 3'd4;
localparam [2:0] S_READ_REQ  = 3'd5;
localparam [2:0] S_READ      = 3'd6;
localparam [2:0] S_PASS      = 3'd7;

wire mem_clk, mem_clk_sft, video_clk, video_clk_5x;
wire mem_rst_n, video_rst_n, init_done, init_ref_valid, mem_busy;
wire write_req_ack, write_finish, write_fifo_full;
wire read_req_ack, read_fifo_valid, read_fifo_empty;
wire [31:0] read_data;
reg write_req, read_req, read_active;
reg [2:0] state;
reg [5:0] settle_count;
reg [18:0] write_count;
reg [18:0] read_count;
reg [18:0] first_error_word;
reg [31:0] first_error_actual;
reg [15:0] error_count;
reg read_error, write_done, read_done;
reg [25:0] heartbeat_count;
reg [15:0] display_value;
wire write_en = (state == S_STREAM) && !write_fifo_full;
wire [31:0] write_data = 32'hA5000000 + write_count;
wire [23:0] diag_rgb;
wire video_hs_i, video_vs_i, video_de_i;

reset_sync u_mem_reset_sync (.clk(mem_clk), .arst_n(key_n[0]), .srst_n(mem_rst_n));
reset_sync u_video_reset_sync (.clk(video_clk), .arst_n(key_n[0]), .srst_n(video_rst_n));
sys_pll u_sys_pll (.refclk(clk_50m), .reset(1'b0), .clk0_out(),
                   .clk1_out(mem_clk), .clk2_out(mem_clk_sft));
// Keep the video reset/clock path identical to the already board-verified
// HDMI-only 1280x720 probe.  The SDRAM diagnostic must not introduce a
// second reset dependency while it is isolating the memory path.
video_pll_75m u_video_pll (.refclk(clk_50m), .reset(~key_n[0]),
                           .clk0_out(video_clk), .clk1_out(video_clk_5x));

always @(posedge clk_50m or negedge mem_rst_n) begin
    if (!mem_rst_n) begin
        write_req <= 1'b0;
        read_req <= 1'b0;
        read_active <= 1'b0;
        state <= S_WAIT_INIT;
        settle_count <= 6'd0;
        write_count <= 19'd0;
        read_count <= 19'd0;
        first_error_word <= 19'd0;
        first_error_actual <= 32'd0;
        error_count <= 16'd0;
        read_error <= 1'b0;
        write_done <= 1'b0;
        read_done <= 1'b0;
    end else begin
        case (state)
            S_WAIT_INIT: if (init_done) state <= S_REQUEST;
            S_REQUEST: begin
                write_req <= 1'b1;
                if (write_req_ack) begin
                    write_req <= 1'b0;
                    settle_count <= 6'd0;
                    write_count <= 19'd0;
                    state <= S_SETTLE;
                end
            end
            S_SETTLE: begin
                if (settle_count == 6'd63)
                    state <= S_STREAM;
                else
                    settle_count <= settle_count + 1'b1;
            end
            S_STREAM: if (write_en) begin
                if (write_count == TEST_WORDS - 1) begin
                    state <= S_DRAIN;
                end else begin
                    write_count <= write_count + 1'b1;
                end
            end
            S_DRAIN: if (write_finish) begin
                write_done <= 1'b1;
                read_req <= 1'b1;
                state <= S_READ_REQ;
            end
            S_READ_REQ: if (read_req_ack) begin
                read_req <= 1'b0;
                read_active <= 1'b1;
                read_count <= 19'd0;
                state <= S_READ;
            end
            S_READ: if (read_fifo_valid) begin
                if (read_data !== (32'hA5000000 + read_count)) begin
                    if (error_count != 16'hffff)
                        error_count <= error_count + 1'b1;
                    if (!read_error) begin
                        read_error <= 1'b1;
                        first_error_word <= read_count;
                        first_error_actual <= read_data;
                    end
                end
                if (read_count == TEST_WORDS - 1) begin
                    read_active <= 1'b0;
                    read_done <= 1'b1;
                    state <= S_PASS;
                end else begin
                    read_count <= read_count + 1'b1;
                end
            end
            default: state <= S_PASS;
        endcase
    end
end

anlogic_frame_store #(
    .READ_LOOP(0), .BURST_SIZE(128), .WRITE_BURST_SIZE(16),
    .READ_BURST_SIZE(128)
) u_frame_store (
    .mem_clk(mem_clk), .mem_clk_sft(mem_clk_sft), .rst_n(mem_rst_n),
    .init_done(init_done), .init_ref_valid(init_ref_valid), .mem_busy(mem_busy),
    .write_clk(clk_50m), .write_req(write_req), .write_req_ack(write_req_ack),
    .write_finish(write_finish), .write_fifo_full(write_fifo_full),
    .write_base_addr(21'd0), .write_len(TEST_WORDS), .write_en(write_en),
    .write_data(write_data), .read_clk(clk_50m), .read_req(read_req),
    .read_req_ack(read_req_ack), .read_finish(), .read_fifo_valid(read_fifo_valid),
    .read_fifo_empty(read_fifo_empty), .read_base_addr(21'd0),
    .read_len(TEST_WORDS), .read_en(read_active && !read_fifo_empty),
    .read_data(read_data)
);

video_timing_1280x720_pclk u_video_timing (
    .clk(video_clk), .rst_n(video_rst_n), .hs(video_hs_i), .vs(video_vs_i),
    .de(video_de_i), .x(), .y(), .frame_tick()
);

assign diag_rgb = !read_done ? 24'h0000FF :
                  (read_error ? 24'hFF0000 : 24'h00FF00);
assign sd_clk = 1'b0;
assign sd_mosi = 1'b0;
assign sd_cs_n = 1'b1;

always @(posedge mem_clk or negedge mem_rst_n) begin
    if (!mem_rst_n)
        heartbeat_count <= 26'd0;
    else
        heartbeat_count <= heartbeat_count + 1'b1;
end

seg_hex_display u_seg_hex_display (
    .clk(mem_clk), .rst_n(mem_rst_n),
    .value(display_value),
    .seg_data(seg_data), .seg_sel(seg_sel)
);
assign led[0] = heartbeat_count[25];
assign led[1] = init_done;
assign led[2] = write_done;
assign led[3] = read_done && !read_error;

always @(*) begin
    case (exhibit_sw)
        3'd0: display_value = first_error_word[15:0];
        3'd1: display_value = {13'd0, first_error_word[18:16]};
        3'd2: display_value = first_error_actual[15:0];
        3'd3: display_value = first_error_actual[31:16];
        3'd4: display_value = (32'hA5000000 + first_error_word) & 16'hffff;
        3'd5: display_value = (32'hA5000000 + first_error_word) >> 16;
        3'd6: display_value = error_count;
        default: display_value = 16'hD123;
    endcase
end

hdmi_tx u_hdmi_tx (
    .PXLCLK_I(video_clk), .PXLCLK_5X_I(video_clk_5x), .RST_N(video_rst_n),
    .VGA_HS(video_hs_i), .VGA_VS(video_vs_i), .VGA_DE(video_de_i),
    .VGA_RGB(diag_rgb), .HDMI_CLK_P(hdmi1_clk_p), .HDMI_D2_P(hdmi1_d2_p),
    .HDMI_D1_P(hdmi1_d1_p), .HDMI_D0_P(hdmi1_d0_p)
);

endmodule

`default_nettype wire
