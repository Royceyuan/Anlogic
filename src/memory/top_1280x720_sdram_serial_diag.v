`timescale 1ns / 1ps
`default_nettype none

// Serialized SDRAM boundary diagnostic.  Each probe is one application write,
// a complete busy interval, one application read, and a read-valid compare.
// This deliberately avoids assuming that consecutive writes can be accepted.
module top_1280x720_sdram_serial_diag (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p
);

localparam [3:0] S_WAIT_INIT = 4'd0;
localparam [3:0] S_WRITE     = 4'd1;
localparam [3:0] S_WAIT_WR   = 4'd2;
localparam [3:0] S_READ      = 4'd3;
localparam [3:0] S_WAIT_RD   = 4'd4;
localparam [3:0] S_PASS      = 4'd5;
localparam [3:0] S_FAIL      = 4'd6;
localparam integer PROBE_COUNT = 5;

wire mem_clk, mem_clk_sft, mem_rst_n, init_done, init_ref_valid, mem_busy, read_valid;
wire app_wr_en, app_rd_en;
wire [20:0] app_wr_addr, app_rd_addr;
wire [31:0] app_wr_data, read_data;
wire [3:0] state;
reg [3:0] state_r;
reg [2:0] probe_r;
reg [10:0] fail_addr_r;
reg [31:0] actual_r, expected_r;
reg busy_seen;
reg [25:0] heartbeat_count;
wire [10:0] probe_addr;
wire [31:0] probe_data;
wire [15:0] display_value;
wire video_clk, video_clk_5x, video_hs_i, video_vs_i, video_de_i;
wire [23:0] diag_rgb;

function [10:0] probe_address(input [2:0] index);
    begin
        case (index)
            3'd0: probe_address = 11'd0;
            3'd1: probe_address = 11'd479;
            3'd2: probe_address = 11'd480;
            3'd3: probe_address = 11'd511;
            default: probe_address = 11'd512;
        endcase
    end
endfunction

assign state = state_r;
assign probe_addr = probe_address(probe_r);
assign probe_data = 32'h5A000000 + probe_addr;
assign app_wr_en = (state_r == S_WRITE) && init_done && !mem_busy;
assign app_wr_addr = {10'd0, probe_addr};
assign app_wr_data = probe_data;
assign app_rd_en = (state_r == S_READ) && init_done && !mem_busy;
assign app_rd_addr = {10'd0, probe_addr};

reset_sync u_mem_reset_sync (.clk(mem_clk), .arst_n(key_n[0]), .srst_n(mem_rst_n));
sys_pll u_sys_pll (.refclk(clk_50m), .reset(1'b0), .clk0_out(),
                   .clk1_out(mem_clk), .clk2_out(mem_clk_sft));

sdram u_sdram (
    .Clk(mem_clk), .Clk_sft(mem_clk_sft), .Rst(~mem_rst_n),
    .Sdr_init_done(init_done), .Sdr_init_ref_vld(init_ref_valid), .Sdr_busy(mem_busy),
    .App_wr_en(app_wr_en), .App_wr_addr(app_wr_addr), .App_wr_dm(4'b0000),
    .App_wr_din(app_wr_data), .App_rd_en(app_rd_en), .App_rd_addr(app_rd_addr),
    .Sdr_rd_en(read_valid), .Sdr_rd_dout(read_data),
    .dbg_write_cmd(), .dbg_ba(), .dbg_addr(), .dbg_dm(), .dbg_dq(),
    .dbg_ras_n(), .dbg_cas_n(), .dbg_we_n(), .dbg_sdram_clk()
);

always @(posedge mem_clk or negedge mem_rst_n) begin
    if (!mem_rst_n) begin
        state_r     <= S_WAIT_INIT;
        probe_r     <= 3'd0;
        fail_addr_r <= 11'd0;
        actual_r    <= 32'd0;
        expected_r  <= 32'd0;
        busy_seen   <= 1'b0;
    end else begin
        case (state_r)
            S_WAIT_INIT: if (init_done) begin
                probe_r <= 3'd0;
                busy_seen <= 1'b0;
                state_r <= S_WRITE;
            end
            S_WRITE: if (app_wr_en) begin
                busy_seen <= 1'b0;
                state_r <= S_WAIT_WR;
            end
            S_WAIT_WR: begin
                if (mem_busy) busy_seen <= 1'b1;
                else if (busy_seen) begin
                    busy_seen <= 1'b0;
                    state_r <= S_READ;
                end
            end
            S_READ: if (app_rd_en) state_r <= S_WAIT_RD;
            S_WAIT_RD: if (read_valid) begin
                actual_r <= read_data;
                expected_r <= probe_data;
                if (read_data !== probe_data) begin
                    fail_addr_r <= probe_addr;
                    state_r <= S_FAIL;
                end else if (probe_r == PROBE_COUNT - 1) begin
                    state_r <= S_PASS;
                end else begin
                    probe_r <= probe_r + 1'b1;
                    state_r <= S_WRITE;
                end
            end
            default: state_r <= state_r;
        endcase
    end
end

always @(posedge mem_clk or negedge mem_rst_n)
    if (!mem_rst_n) heartbeat_count <= 26'd0;
    else heartbeat_count <= heartbeat_count + 1'b1;

assign led[0] = heartbeat_count[25];
assign led[1] = init_done;
assign led[2] = (state_r == S_PASS);
assign led[3] = (state_r == S_FAIL);

assign display_value = (sw == 4'b0000) ?
                      ((state_r == S_FAIL) ? 16'hDEAD :
                       (state_r == S_PASS) ? 16'hD0A5 :
                       !init_done ? 16'hD000 : 16'hD001) :
                      (sw == 4'b0001) ? {5'd0, fail_addr_r} :
                      (sw == 4'b0010) ? actual_r[15:0] :
                      (sw == 4'b0011) ? expected_r[15:0] :
                      (sw == 4'b0100) ? actual_r[31:16] :
                      (sw == 4'b0101) ? expected_r[31:16] :
                      (sw == 4'b0110) ? {5'd0, probe_addr} :
                      {13'd0, probe_r};

seg_hex_display u_seg_hex_display (
    .clk(mem_clk), .rst_n(mem_rst_n), .value(display_value),
    .seg_data(seg_data), .seg_sel(seg_sel)
);

video_pll_75m u_video_pll (
    .refclk(clk_50m), .reset(~key_n[0]), .clk0_out(video_clk), .clk1_out(video_clk_5x)
);
video_timing_1280x720_pclk u_video_timing (
    .clk(video_clk), .rst_n(key_n[0]), .hs(video_hs_i), .vs(video_vs_i),
    .de(video_de_i), .x(), .y(), .frame_tick()
);

assign diag_rgb = (state_r == S_FAIL) ? 24'hFF0000 :
                  (state_r == S_PASS) ? 24'h00FF00 : 24'h0000FF;
assign vga_hs = video_hs_i;
assign vga_vs = video_vs_i;
assign vga_d = {diag_rgb[23:20], diag_rgb[15:12], diag_rgb[7:4]};

hdmi_tx u_hdmi_tx (
    .PXLCLK_I(video_clk), .PXLCLK_5X_I(video_clk_5x), .RST_N(key_n[0]),
    .VGA_HS(video_hs_i), .VGA_VS(video_vs_i), .VGA_DE(video_de_i), .VGA_RGB(diag_rgb),
    .HDMI_CLK_P(hdmi1_clk_p), .HDMI_D2_P(hdmi1_d2_p), .HDMI_D1_P(hdmi1_d1_p),
    .HDMI_D0_P(hdmi1_d0_p)
);

assign sd_clk = 1'b0;
assign sd_mosi = 1'b0;
assign sd_cs_n = 1'b1;

endmodule
`default_nettype wire
