`timescale 1ns / 1ps
`default_nettype none

// SDRAM read-path isolation.  The write transaction still uses the exact
// frame_read_write controller, but the returned SDRAM stream is compared
// before rfifo_32_32_512.  This separates the SDRAM/controller side from
// the asynchronous read FIFO side without involving BMP, OSD, or scaling.
module top_1280x720_sdram_direct_diag #(
    parameter integer DATA_DELAY = 0,
    parameter integer GUARD_MODE = 0,
    parameter integer PREPEND_DUMMY = 0,
    parameter integer FIXED_WRITE_LEN = 0,
    parameter integer OBSERVE_APP_WR = 0,
    parameter integer OBSERVE_PHY = 0,
    parameter integer PHY_CAPTURE_USE_SFT = 0,
    parameter integer PHY_CAPTURE_NEGEDGE = 0,
    parameter integer HOST_RESET_ON_BOARD_CLK = 0,
    parameter integer COMPARE_WRITE_STREAM = 0,
    parameter integer SIMPLE_PATTERN = 0,
    parameter integer SCAN_DELAYS = 0,
    parameter integer TEST_WORDS_PARAM = 1024
) (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p,
    output wire hdmi1_d1_p, output wire hdmi1_d0_p
);

localparam [20:0] TEST_WORDS = TEST_WORDS_PARAM;
localparam [20:0] WRITE_WORDS = FIXED_WRITE_LEN ? TEST_WORDS :
                                  (TEST_WORDS + PREPEND_DUMMY);
localparam [2:0] S_WAIT_INIT = 3'd0;
localparam [2:0] S_REQUEST   = 3'd1;
localparam [2:0] S_SETTLE    = 3'd2;
localparam [2:0] S_STREAM    = 3'd3;
localparam [2:0] S_DRAIN     = 3'd4;
localparam [2:0] S_READ_REQ  = 3'd5;
localparam [2:0] S_WAIT_READ = 3'd6;
localparam [2:0] S_DONE      = 3'd7;

wire mem_clk, mem_clk_sft, video_clk, video_clk_5x;
wire mem_rst_n, video_rst_n, host_rst_n, init_done, init_ref_valid, mem_busy;
wire diag_host_rst_n = HOST_RESET_ON_BOARD_CLK ? host_rst_n : mem_rst_n;
wire app_rd_en, sdr_rd_en, app_wr_en;
wire [20:0] app_rd_addr, app_wr_addr;
wire [31:0] app_wr_din, sdr_rd_dout;
wire [3:0] app_wr_dm;
wire phy_write_cmd;
wire [1:0] phy_ba;
wire [10:0] phy_addr;
wire [3:0] phy_dm;
wire [31:0] phy_dq;
wire phy_ras_n, phy_cas_n, phy_we_n;
wire phy_sdram_clk;
wire phy_capture_clk = PHY_CAPTURE_USE_SFT ?
                       (PHY_CAPTURE_NEGEDGE ? ~mem_clk_sft : mem_clk_sft) :
                       phy_sdram_clk;
wire read_req_ack, read_finish;
wire write_req_ack, write_finish, write_fifo_full;
wire read_fifo_valid, read_fifo_empty;
wire [31:0] read_data;
reg write_req, read_req;
reg [2:0] state;
reg [5:0] settle_count;
reg [10:0] write_count;
reg write_done;
reg [10:0] direct_count;
reg [9:0] first_fail_index;
reg [31:0] first_fail_actual;
reg [31:0] first_words [0:7];
reg [31:0] app_wr_first_words [0:3];
reg [9:0] app_wr_first_addrs [0:3];
reg [2:0] app_wr_capture_count;
reg app_wr_capture_done;
reg [2:0] phy_cmd_capture_count;
reg phy_cmd_capture_done;
reg [10:0] phy_cmd_first_addr [0:3];
reg [1:0] phy_cmd_first_ba [0:3];
reg [3:0] phy_cmd_first_dm [0:3];
reg [2:0] phy_dq_capture_count;
reg phy_dq_capture_active, phy_dq_capture_done;
reg [31:0] phy_dq_first_words [0:3];
reg [3:0] phy_dq_first_dm [0:3];
reg [3:0] phy_write_seen_count;
reg phy_capture_toggle;
reg phy_capture_toggle_m1, phy_capture_toggle_m2, phy_capture_toggle_seen;
reg direct_error, direct_done;
reg [25:0] heartbeat_count;
reg [3:0] status_code;
reg [31:0] sdr_rd_dout_q;
reg [31:0] sdr_rd_dout_q2, sdr_rd_dout_q3;
reg scan_error0, scan_error1, scan_error2, scan_error3;
wire [23:0] diag_rgb;
wire video_hs_i, video_vs_i, video_de_i;
wire drain_read_en = (state == S_WAIT_READ) && !read_fifo_empty;
wire [31:0] sdr_rd_dout_aligned = (DATA_DELAY == 0) ? sdr_rd_dout :
                                   (DATA_DELAY == 1) ? sdr_rd_dout_q :
                                   (DATA_DELAY == 2) ? sdr_rd_dout_q2 : sdr_rd_dout_q3;
wire scan_error_any = scan_error0 && scan_error1 && scan_error2 && scan_error3;
wire raw_diag_error = SCAN_DELAYS ? scan_error_any : direct_error;
wire [2:0] capture_page = heartbeat_count[25:23];
wire [1:0] app_capture_page = heartbeat_count[24:23];
wire [31:0] app_observe_value = sw[0] ?
                                 {22'd0, app_wr_first_addrs[app_capture_page]} :
                                 app_wr_first_words[app_capture_page];
wire [2:0] phy_observe_page = heartbeat_count[25:23];
wire [2:0] observe_mode = sw[2:0];
reg [15:0] phy_observe_value;
wire [31:0] expected_first_fail = expected_read_word({1'b0, first_fail_index});

always @(*) begin
    case (observe_mode)
        3'b000: phy_observe_value = {2'b00, app_capture_page,
                                      app_wr_first_words[app_capture_page][11:0]};
        3'b001: phy_observe_value = {2'b00, app_capture_page,
                                      2'b00, app_wr_first_addrs[app_capture_page]};
        3'b010: phy_observe_value = {2'b00, phy_observe_page[1:0],
                                      phy_dq_first_words[phy_observe_page[1:0]][11:0]};
        3'b011: phy_observe_value = {2'b00, phy_observe_page[1:0], 8'h00,
                                      phy_dq_first_dm[phy_observe_page[1:0]]};
        3'b100: phy_observe_value = {2'b00, phy_observe_page[1:0],
                                      phy_cmd_first_ba[phy_observe_page[1:0]],
                                      phy_cmd_first_addr[phy_observe_page[1:0]][9:0]};
        3'b101: phy_observe_value = {4'h5, phy_write_seen_count,
                                      phy_cmd_capture_count[1:0],
                                      phy_dq_capture_count[1:0],
                                      phy_cmd_capture_done, phy_dq_capture_done,
                                      2'b00};
        3'b110: phy_observe_value = {4'h6, 1'b0, phy_write_cmd,
                                      phy_ras_n, phy_cas_n, phy_we_n,
                                      state, 4'h0};
        default: begin
            case (phy_observe_page)
                3'd0: phy_observe_value = 16'h15A5;
                3'd1: phy_observe_value = {6'd0, first_fail_index};
                3'd2: phy_observe_value = first_fail_actual[15:0];
                3'd3: phy_observe_value = expected_first_fail[15:0];
                default: phy_observe_value = 16'hD00F;
            endcase
        end
    endcase
end

function [31:0] expected_word;
    input [10:0] index;
    begin
        if (GUARD_MODE && index == 11'd0)
            expected_word = 32'h5A5A0ABC;
        else if (GUARD_MODE)
            expected_word = 32'hA5000000 | (index[9:0] - 10'd1);
        else
            expected_word = 32'hA5000000 | index[9:0];
    end
endfunction

wire write_en = (state == S_STREAM) && !write_fifo_full;
function [31:0] write_word;
    input [10:0] index;
    begin
        if (SIMPLE_PATTERN) begin
            case (index[1:0])
                2'd0: write_word = 32'hA55A_F00D;
                2'd1: write_word = 32'h5AA5_0FF0;
                2'd2: write_word = 32'h33CC_CC33;
                default: write_word = 32'hCC33_33CC;
            endcase
        end else if (PREPEND_DUMMY && index == 11'd0)
            write_word = 32'hDEAD0FFF;
        else
            write_word = expected_word(index - PREPEND_DUMMY);
    end
endfunction
wire [31:0] write_data = write_word(write_count);

function [31:0] expected_read_word;
    input [10:0] index;
    begin
        expected_read_word = (COMPARE_WRITE_STREAM || SIMPLE_PATTERN) ? write_word(index) :
                                                  expected_word(index);
    end
endfunction

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
    .refclk(clk_50m), .reset(~key_n[0]),
    .clk0_out(video_clk), .clk1_out(video_clk_5x)
);

frame_read_write #(
    .MEM_DATA_BITS(32), .READ_DATA_BITS(32), .WRITE_DATA_BITS(32),
    .ADDR_BITS(21), .BURST_BITS(9), .BURST_SIZE(64),
    .WRITE_BURST_SIZE(32), .READ_BURST_SIZE(64), .READ_LOOP(1'b0)
) u_frame_read_write (
    .rst(~mem_rst_n), .mem_clk(mem_clk), .Sdr_init_done(init_done),
    .Sdr_init_ref_vld(init_ref_valid), .Sdr_busy(mem_busy),
    .App_rd_en(app_rd_en), .App_rd_addr(app_rd_addr),
    .Sdr_rd_en(sdr_rd_en), .Sdr_rd_dout(sdr_rd_dout_aligned),
    .read_clk(clk_50m), .read_req(read_req), .read_req_ack(read_req_ack),
    .read_finish(read_finish), .read_fifo_valid(read_fifo_valid),
    .read_fifo_empty(read_fifo_empty),
    .read_addr_0(21'd0), .read_addr_1(21'd0), .read_addr_2(21'd0),
    .read_addr_3(21'd0), .read_addr_index(2'd0), .read_len(TEST_WORDS),
    // Drain the FIFO only to prevent the controller from stopping at its
    // 512-word capacity; the diagnostic comparator below ignores this path.
    .read_en(drain_read_en), .read_data(read_data),
    .App_wr_en(app_wr_en), .App_wr_addr(app_wr_addr),
    .App_wr_din(app_wr_din), .App_wr_dm(app_wr_dm),
    .write_clk(clk_50m), .write_req(write_req), .write_req_ack(write_req_ack),
    .write_finish(write_finish), .write_fifo_full(write_fifo_full),
    .write_addr_0(21'd0), .write_addr_1(21'd0), .write_addr_2(21'd0),
    .write_addr_3(21'd0), .write_addr_index(2'd0), .write_len(WRITE_WORDS),
    .write_en(write_en), .write_data(write_data)
);

sdram u_sdram (
    .Clk(mem_clk), .Clk_sft(mem_clk_sft), .Rst(~mem_rst_n),
    .Sdr_init_done(init_done), .Sdr_init_ref_vld(init_ref_valid),
    .Sdr_busy(mem_busy), .App_wr_en(app_wr_en), .App_wr_addr(app_wr_addr),
    .App_wr_dm(app_wr_dm), .App_wr_din(app_wr_din), .App_rd_en(app_rd_en),
    .App_rd_addr(app_rd_addr), .Sdr_rd_en(sdr_rd_en),
    .Sdr_rd_dout(sdr_rd_dout), .dbg_write_cmd(phy_write_cmd),
    .dbg_ba(phy_ba), .dbg_addr(phy_addr), .dbg_dm(phy_dm), .dbg_dq(phy_dq),
    .dbg_ras_n(phy_ras_n), .dbg_cas_n(phy_cas_n), .dbg_we_n(phy_we_n),
    .dbg_sdram_clk(phy_sdram_clk)
);

// Write and read requests are kept in the board clock domain, matching the
// existing diagnostic.  Raw SDRAM data is checked in mem_clk below.
always @(posedge clk_50m or negedge diag_host_rst_n) begin
    if (!diag_host_rst_n) begin
        write_req <= 1'b0;
        read_req <= 1'b0;
        state <= S_WAIT_INIT;
        settle_count <= 6'd0;
        write_count <= 11'd0;
        write_done <= 1'b0;
    end else begin
        case (state)
            S_WAIT_INIT: if (init_done) state <= S_REQUEST;
            S_REQUEST: begin
                write_req <= 1'b1;
                if (write_req_ack) begin
                    write_req <= 1'b0;
                    settle_count <= 6'd0;
                    write_count <= 11'd0;
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
                if (write_count == WRITE_WORDS - 1)
                    state <= S_DRAIN;
                else
                    write_count <= write_count + 1'b1;
            end
            S_DRAIN: if (write_finish) begin
                write_done <= 1'b1;
                read_req <= 1'b1;
                state <= S_READ_REQ;
            end
            S_READ_REQ: if (read_req_ack) begin
                read_req <= 1'b0;
                state <= S_WAIT_READ;
            end
            S_WAIT_READ: if (direct_done) state <= S_DONE;
            default: state <= S_DONE;
        endcase
    end
end

// Sdr_rd_en is the controller's raw-return qualification.  The counter is
// deliberately before the asynchronous read FIFO, so a failure here cannot
// be attributed to FIFO empty/valid timing.
always @(posedge mem_clk or negedge mem_rst_n) begin
    if (!mem_rst_n) begin
        direct_count <= 11'd0;
        sdr_rd_dout_q <= 32'd0;
        sdr_rd_dout_q2 <= 32'd0;
        sdr_rd_dout_q3 <= 32'd0;
        scan_error0 <= 1'b0;
        scan_error1 <= 1'b0;
        scan_error2 <= 1'b0;
        scan_error3 <= 1'b0;
        first_fail_index <= 10'd0;
        first_fail_actual <= 32'd0;
        direct_error <= 1'b0;
        direct_done <= 1'b0;
        first_words[0] <= 32'd0;
        first_words[1] <= 32'd0;
        first_words[2] <= 32'd0;
        first_words[3] <= 32'd0;
        first_words[4] <= 32'd0;
        first_words[5] <= 32'd0;
        first_words[6] <= 32'd0;
        first_words[7] <= 32'd0;
        app_wr_first_words[0] <= 32'd0;
        app_wr_first_words[1] <= 32'd0;
        app_wr_first_words[2] <= 32'd0;
        app_wr_first_words[3] <= 32'd0;
        app_wr_first_addrs[0] <= 10'd0;
        app_wr_first_addrs[1] <= 10'd0;
        app_wr_first_addrs[2] <= 10'd0;
        app_wr_first_addrs[3] <= 10'd0;
        app_wr_capture_count <= 3'd0;
        app_wr_capture_done <= 1'b0;
        phy_capture_toggle_m1 <= 1'b0;
        phy_capture_toggle_m2 <= 1'b0;
        phy_capture_toggle_seen <= 1'b0;
    end else begin
        sdr_rd_dout_q <= sdr_rd_dout;
        sdr_rd_dout_q2 <= sdr_rd_dout_q;
        sdr_rd_dout_q3 <= sdr_rd_dout_q2;
        if (OBSERVE_APP_WR && !app_wr_capture_done && app_wr_en) begin
            app_wr_first_words[app_wr_capture_count[1:0]] <= app_wr_din;
            app_wr_first_addrs[app_wr_capture_count[1:0]] <= app_wr_addr[9:0];
            if (app_wr_capture_count == 3'd3)
                app_wr_capture_done <= 1'b1;
            else
                app_wr_capture_count <= app_wr_capture_count + 1'b1;
        end
        phy_capture_toggle_m1 <= phy_capture_toggle;
        phy_capture_toggle_m2 <= phy_capture_toggle_m1;
        if (phy_capture_toggle_m2 != phy_capture_toggle_seen)
            phy_capture_toggle_seen <= phy_capture_toggle_m2;
        if (!direct_done && sdr_rd_en) begin
        if (SCAN_DELAYS) begin
            if (sdr_rd_dout !== expected_read_word(direct_count))
                scan_error0 <= 1'b1;
            if (sdr_rd_dout_q !== expected_read_word(direct_count))
                scan_error1 <= 1'b1;
            if (sdr_rd_dout_q2 !== expected_read_word(direct_count))
                scan_error2 <= 1'b1;
            if (sdr_rd_dout_q3 !== expected_read_word(direct_count))
                scan_error3 <= 1'b1;
        end
        if (direct_count < 11'd8)
            first_words[direct_count[2:0]] <= sdr_rd_dout_aligned;
        if (sdr_rd_dout_aligned !== expected_read_word(direct_count)) begin
            direct_error <= 1'b1;
            if (!direct_error)
                first_fail_index <= direct_count[9:0];
            if (!direct_error)
                first_fail_actual <= sdr_rd_dout_aligned;
        end
        if (direct_count == TEST_WORDS - 1) begin
            direct_done <= 1'b1;
        end else begin
            direct_count <= direct_count + 1'b1;
        end
        end
    end
end

// Capture the physical SDRAM write bus in the clock domain that actually
// drives the device.  The captured bundle remains stable before the toggle
// crosses back to mem_clk.
always @(posedge phy_capture_clk or negedge mem_rst_n) begin
    if (!mem_rst_n) begin
        phy_write_seen_count <= 4'd0;
        phy_cmd_capture_count <= 3'd0;
        phy_cmd_capture_done <= 1'b0;
        phy_dq_capture_count <= 3'd0;
        phy_dq_capture_active <= 1'b0;
        phy_dq_capture_done <= 1'b0;
        phy_capture_toggle <= 1'b0;
        phy_cmd_first_addr[0] <= 11'd0; phy_cmd_first_addr[1] <= 11'd0;
        phy_cmd_first_addr[2] <= 11'd0; phy_cmd_first_addr[3] <= 11'd0;
        phy_cmd_first_ba[0] <= 2'd0; phy_cmd_first_ba[1] <= 2'd0;
        phy_cmd_first_ba[2] <= 2'd0; phy_cmd_first_ba[3] <= 2'd0;
        phy_cmd_first_dm[0] <= 4'd0; phy_cmd_first_dm[1] <= 4'd0;
        phy_cmd_first_dm[2] <= 4'd0; phy_cmd_first_dm[3] <= 4'd0;
        phy_dq_first_words[0] <= 32'd0; phy_dq_first_words[1] <= 32'd0;
        phy_dq_first_words[2] <= 32'd0; phy_dq_first_words[3] <= 32'd0;
        phy_dq_first_dm[0] <= 4'd0; phy_dq_first_dm[1] <= 4'd0;
        phy_dq_first_dm[2] <= 4'd0; phy_dq_first_dm[3] <= 4'd0;
    end else if (OBSERVE_PHY && init_done) begin
        if (phy_write_cmd && phy_write_seen_count != 4'hF)
            phy_write_seen_count <= phy_write_seen_count + 1'b1;
        if (!phy_cmd_capture_done && phy_write_cmd) begin
            phy_cmd_first_addr[phy_cmd_capture_count[1:0]] <= phy_addr;
            phy_cmd_first_ba[phy_cmd_capture_count[1:0]] <= phy_ba;
            phy_cmd_first_dm[phy_cmd_capture_count[1:0]] <= phy_dm;
            if (phy_cmd_capture_count == 3'd3)
                phy_cmd_capture_done <= 1'b1;
            else
                phy_cmd_capture_count <= phy_cmd_capture_count + 1'b1;
        end
        if (!phy_dq_capture_done) begin
            if (phy_write_cmd && !phy_dq_capture_active) begin
                phy_dq_first_words[0] <= phy_dq;
                phy_dq_first_dm[0] <= phy_dm;
                phy_dq_capture_count <= 3'd1;
                phy_dq_capture_active <= 1'b1;
            end else if (phy_dq_capture_active) begin
                phy_dq_first_words[phy_dq_capture_count[1:0]] <= phy_dq;
                phy_dq_first_dm[phy_dq_capture_count[1:0]] <= phy_dm;
                if (phy_dq_capture_count == 3'd3) begin
                    phy_dq_capture_done <= 1'b1;
                    phy_dq_capture_active <= 1'b0;
                    phy_capture_toggle <= ~phy_capture_toggle;
                end else begin
                    phy_dq_capture_count <= phy_dq_capture_count + 1'b1;
                end
            end
        end
    end
end

video_timing_1280x720_pclk u_video_timing (
    .clk(video_clk), .rst_n(video_rst_n), .hs(video_hs_i), .vs(video_vs_i),
    .de(video_de_i), .x(), .y(), .frame_tick()
);

assign diag_rgb = !direct_done ? 24'h0000FF :
                  (SCAN_DELAYS ?
                   (!scan_error0 ? 24'h00FF00 : !scan_error1 ? 24'h00FFFF :
                    !scan_error2 ? 24'hFFFF00 : !scan_error3 ? 24'hFF00FF :
                                    24'hFF0000) :
                   (direct_error ? 24'hFF0000 : 24'h00FF00));
assign vga_d = {diag_rgb[23:20], diag_rgb[15:12], diag_rgb[7:4]};
assign vga_hs = video_hs_i;
assign vga_vs = video_vs_i;

always @(*) begin
    if (direct_done && raw_diag_error)
        status_code = 4'hE;
    else if (direct_done)
        status_code = 4'hC;
    else if (write_done)
        status_code = 4'h4;
    else
        status_code = {1'b0, state};
end

seg_hex_display u_seg_hex_display (
    .clk(mem_clk), .rst_n(mem_rst_n),
    .value(OBSERVE_PHY ? phy_observe_value :
           OBSERVE_APP_WR && app_wr_capture_done ?
           {2'b00, app_capture_page, app_observe_value[11:0]} :
           raw_diag_error ?
           {1'b0, capture_page, first_words[capture_page][11:0]} :
           {status_code, {2'b00, direct_count[9:0]}}),
    .seg_data(seg_data), .seg_sel(seg_sel)
);

always @(posedge mem_clk or negedge mem_rst_n) begin
    if (!mem_rst_n)
        heartbeat_count <= 26'd0;
    else
        heartbeat_count <= heartbeat_count + 1'b1;
end

assign led[0] = heartbeat_count[25];
assign led[1] = init_done;
assign led[2] = write_done;
assign led[3] = direct_done && !raw_diag_error;
assign sd_clk = 1'b0;
assign sd_mosi = 1'b0;
assign sd_cs_n = 1'b1;

hdmi_tx u_hdmi_tx (
    .PXLCLK_I(video_clk), .PXLCLK_5X_I(video_clk_5x), .RST_N(video_rst_n),
    .VGA_HS(video_hs_i), .VGA_VS(video_vs_i), .VGA_DE(video_de_i),
    .VGA_RGB(diag_rgb), .HDMI_CLK_P(hdmi1_clk_p),
    .HDMI_D2_P(hdmi1_d2_p), .HDMI_D1_P(hdmi1_d1_p), .HDMI_D0_P(hdmi1_d0_p)
);

endmodule

// v18: retain the v17 physical write stream, including its required dummy
// word, and compare the SDRAM readback against that same stream.
module top_1280x720_sdram_direct_diag_v18_reference (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p,
    output wire hdmi1_d1_p, output wire hdmi1_d0_p
);
top_1280x720_sdram_direct_diag #(
    .GUARD_MODE(1), .PREPEND_DUMMY(1), .FIXED_WRITE_LEN(1),
    .OBSERVE_APP_WR(1), .OBSERVE_PHY(1), .HOST_RESET_ON_BOARD_CLK(1),
    .COMPARE_WRITE_STREAM(1)
) u_diag (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk),
    .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v43: 125 MHz raw-readback test with only a four-word repeating pattern.
// This removes the diagnostic's long arithmetic path from the SDRAM clock,
// while still detecting both bit corruption and word-boundary displacement.
module top_1280x720_sdram_direct_diag_v43_light (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p,
    output wire hdmi1_d1_p, output wire hdmi1_d0_p
);
top_1280x720_sdram_direct_diag #(
    .FIXED_WRITE_LEN(1), .HOST_RESET_ON_BOARD_CLK(1),
    .COMPARE_WRITE_STREAM(1), .SIMPLE_PATTERN(1), .TEST_WORDS_PARAM(64)
) u_diag (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk),
    .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v44: same compact raw-return test, but samples the controller data one
// mem_clk later while retaining Sdr_rd_en as the return qualifier.
module top_1280x720_sdram_direct_diag_v44_delay1 (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p,
    output wire hdmi1_d1_p, output wire hdmi1_d0_p
);
top_1280x720_sdram_direct_diag #(
    .DATA_DELAY(1), .FIXED_WRITE_LEN(1), .HOST_RESET_ON_BOARD_CLK(1),
    .COMPARE_WRITE_STREAM(1), .SIMPLE_PATTERN(1), .TEST_WORDS_PARAM(64)
) u_diag (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk),
    .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v45: one-board-test sweep of raw data aligned at 0, 1, 2, and 3 mem_clk.
module top_1280x720_sdram_direct_diag_v45_delay_sweep (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p,
    output wire hdmi1_d1_p, output wire hdmi1_d0_p
);
top_1280x720_sdram_direct_diag #(
    .FIXED_WRITE_LEN(1), .HOST_RESET_ON_BOARD_CLK(1),
    .COMPARE_WRITE_STREAM(1), .SIMPLE_PATTERN(1), .SCAN_DELAYS(1),
    .TEST_WORDS_PARAM(64)
) u_diag (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk),
    .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v17: official 125 MHz/180-degree clock with a reset released in the
// request producer's own clock domain.
module top_1280x720_sdram_direct_diag_v17_reference (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p,
    output wire hdmi1_d1_p, output wire hdmi1_d0_p
);
top_1280x720_sdram_direct_diag #(
    .GUARD_MODE(1), .PREPEND_DUMMY(1), .FIXED_WRITE_LEN(1),
    .OBSERVE_APP_WR(1), .OBSERVE_PHY(1), .HOST_RESET_ON_BOARD_CLK(1)
) u_diag (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk),
    .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

module top_1280x720_sdram_direct_diag_dly (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p,
    output wire hdmi1_d1_p, output wire hdmi1_d0_p
);
top_1280x720_sdram_direct_diag #(.DATA_DELAY(1)) u_diag (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk),
    .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

module top_1280x720_sdram_direct_diag_guard (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p,
    output wire hdmi1_d1_p, output wire hdmi1_d0_p
);
top_1280x720_sdram_direct_diag #(.GUARD_MODE(1)) u_diag (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk),
    .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

module top_1280x720_sdram_direct_diag_dummy (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p,
    output wire hdmi1_d1_p, output wire hdmi1_d0_p
);
top_1280x720_sdram_direct_diag #(.GUARD_MODE(1), .PREPEND_DUMMY(1)) u_diag (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk),
    .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v10: prepend the dummy while keeping the original 1024-word transaction
// length, so burst alignment remains identical to the baseline diagnostic.
module top_1280x720_sdram_direct_diag_dummy_fixed (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p,
    output wire hdmi1_d1_p, output wire hdmi1_d0_p
);
top_1280x720_sdram_direct_diag #(
    .GUARD_MODE(1), .PREPEND_DUMMY(1), .FIXED_WRITE_LEN(1)
) u_diag (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk),
    .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v11: observe the first four beats actually presented to the SDRAM port.
// sw[0]=0 shows App_wr_din low 12 bits; sw[0]=1 shows App_wr_addr low 12 bits.
module top_1280x720_sdram_direct_diag_write_obs (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p,
    output wire hdmi1_d1_p, output wire hdmi1_d0_p
);
top_1280x720_sdram_direct_diag #(
    .GUARD_MODE(1), .OBSERVE_APP_WR(1)
) u_diag (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk),
    .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v12: observe the same fixed-length dummy/guard pattern as v10.
module top_1280x720_sdram_direct_diag_write_obs_fixed (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p,
    output wire hdmi1_d1_p, output wire hdmi1_d0_p
);
top_1280x720_sdram_direct_diag #(
    .GUARD_MODE(1), .PREPEND_DUMMY(1), .FIXED_WRITE_LEN(1), .OBSERVE_APP_WR(1)
) u_diag (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk),
    .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v13: add physical SDRAM-bus observation while keeping the v12 transaction.
// sw[2:0]: 000 App data, 001 App address, 010 physical DQ, 011 physical DQM,
//          100 physical WRITE command address/bank.
module top_1280x720_sdram_direct_diag_phy_obs (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p,
    output wire hdmi1_d1_p, output wire hdmi1_d0_p
);
top_1280x720_sdram_direct_diag #(
    .GUARD_MODE(1), .PREPEND_DUMMY(1), .FIXED_WRITE_LEN(1),
    .OBSERVE_APP_WR(1), .OBSERVE_PHY(1)
) u_diag (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk),
    .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v15: capture the raw write bus on the generated SDRAM clock.
module top_1280x720_sdram_direct_diag_v15 (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p,
    output wire hdmi1_d1_p, output wire hdmi1_d0_p
);
top_1280x720_sdram_direct_diag #(
    .GUARD_MODE(1), .PREPEND_DUMMY(1), .FIXED_WRITE_LEN(1),
    .OBSERVE_APP_WR(1), .OBSERVE_PHY(1)
) u_diag (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk),
    .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v15b: fallback observation phase, using the controller's shifted clock.
module top_1280x720_sdram_direct_diag_v15b (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p,
    output wire hdmi1_d1_p, output wire hdmi1_d0_p
);
top_1280x720_sdram_direct_diag #(
    .GUARD_MODE(1), .PREPEND_DUMMY(1), .FIXED_WRITE_LEN(1),
    .OBSERVE_APP_WR(1), .OBSERVE_PHY(1), .PHY_CAPTURE_USE_SFT(1)
) u_diag (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk),
    .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v15c: last phase check, sampling on mem_clk_sft falling edge.
module top_1280x720_sdram_direct_diag_v15c (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p,
    output wire hdmi1_d1_p, output wire hdmi1_d0_p
);
top_1280x720_sdram_direct_diag #(
    .GUARD_MODE(1), .PREPEND_DUMMY(1), .FIXED_WRITE_LEN(1),
    .OBSERVE_APP_WR(1), .OBSERVE_PHY(1), .PHY_CAPTURE_USE_SFT(1),
    .PHY_CAPTURE_NEGEDGE(1)
) u_diag (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk),
    .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v16_31: boundary probe; compare exactly one word before a 32-word burst.
module top_1280x720_sdram_direct_diag_v16_31 (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p,
    output wire hdmi1_d1_p, output wire hdmi1_d0_p
);
top_1280x720_sdram_direct_diag #(
    .GUARD_MODE(1), .PREPEND_DUMMY(0), .FIXED_WRITE_LEN(1),
    .OBSERVE_APP_WR(1), .OBSERVE_PHY(1), .PHY_CAPTURE_USE_SFT(1),
    .PHY_CAPTURE_NEGEDGE(1), .TEST_WORDS_PARAM(31)
) u_diag (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk),
    .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

// v16_32: exact one 32-word burst, with no prepended dummy word.
module top_1280x720_sdram_direct_diag_v16_32 (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p,
    output wire hdmi1_d1_p, output wire hdmi1_d0_p
);
top_1280x720_sdram_direct_diag #(
    .GUARD_MODE(1), .PREPEND_DUMMY(0), .FIXED_WRITE_LEN(1),
    .OBSERVE_APP_WR(1), .OBSERVE_PHY(1), .PHY_CAPTURE_USE_SFT(1),
    .PHY_CAPTURE_NEGEDGE(1), .TEST_WORDS_PARAM(32)
) u_diag (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel), .sd_clk(sd_clk),
    .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p)
);
endmodule

`default_nettype wire
