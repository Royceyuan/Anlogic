`timescale 1ns / 1ps
`default_nettype none

// Minimal physical SDRAM loopback.  It deliberately bypasses frame FIFOs and
// burst scheduling: one fixed word is written and read at address zero.
module top_1280x720_sdram_single_loopback_diag (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p,
    output wire hdmi1_d1_p, output wire hdmi1_d0_p
);
wire mem_clk, mem_clk_sft, video_clk, video_clk_5x;
wire mem_rst_n, init_done, init_ref_valid, mem_busy;
wire app_wr_en, app_rd_en, read_valid;
wire [20:0] app_wr_addr, app_rd_addr;
wire [31:0] app_wr_data, read_data, captured_data;
wire [3:0] test_status;
wire test_pass, test_fail;
reg [25:0] heartbeat_count;
wire video_hs_i, video_vs_i, video_de_i;
wire [23:0] diag_rgb = test_fail ? 24'hFF0000 :
                        test_pass ? 24'h00FF00 : 24'h0000FF;

sys_pll u_sys_pll (
    .refclk(clk_50m), .reset(1'b0), .clk0_out(),
    .clk1_out(mem_clk), .clk2_out(mem_clk_sft)
);
reset_sync u_mem_reset_sync (.clk(mem_clk), .arst_n(key_n[0]), .srst_n(mem_rst_n));

sdram u_sdram (
    .Clk(mem_clk), .Clk_sft(mem_clk_sft), .Rst(~mem_rst_n),
    .Sdr_init_done(init_done), .Sdr_init_ref_vld(init_ref_valid),
    .Sdr_busy(mem_busy), .App_wr_en(app_wr_en), .App_wr_addr(app_wr_addr),
    .App_wr_dm(4'b0000), .App_wr_din(app_wr_data), .App_rd_en(app_rd_en),
    .App_rd_addr(app_rd_addr), .Sdr_rd_en(read_valid), .Sdr_rd_dout(read_data),
    .dbg_write_cmd(), .dbg_ba(), .dbg_addr(), .dbg_dm(), .dbg_dq(),
    .dbg_ras_n(), .dbg_cas_n(), .dbg_we_n(), .dbg_sdram_clk()
);

sdram_self_test #(.TEST_DATA(32'hA55A_3CC3)) u_loopback (
    .clk(mem_clk), .rst_n(mem_rst_n), .init_done(init_done), .mem_busy(mem_busy),
    .app_wr_en(app_wr_en), .app_wr_addr(app_wr_addr), .app_wr_data(app_wr_data),
    .app_rd_en(app_rd_en), .app_rd_addr(app_rd_addr), .read_valid(read_valid),
    .read_data(read_data), .status(test_status), .captured_data(captured_data),
    .pass(test_pass), .fail(test_fail)
);

video_pll_75m u_video_pll (
    .refclk(clk_50m), .reset(~key_n[0]), .clk0_out(video_clk), .clk1_out(video_clk_5x)
);
reset_sync u_video_reset_sync (.clk(video_clk), .arst_n(key_n[0]), .srst_n());
video_timing_1280x720_pclk u_video_timing (
    .clk(video_clk), .rst_n(key_n[0]), .hs(video_hs_i), .vs(video_vs_i),
    .de(video_de_i), .x(), .y(), .frame_tick()
);

always @(posedge mem_clk or negedge mem_rst_n) begin
    if (!mem_rst_n) heartbeat_count <= 26'd0;
    else heartbeat_count <= heartbeat_count + 1'b1;
end
assign led[0] = heartbeat_count[25];
assign led[1] = init_done;
assign led[2] = test_pass;
assign led[3] = test_fail;
assign sd_clk = 1'b0;
assign sd_mosi = 1'b0;
assign sd_cs_n = 1'b1;
assign vga_hs = video_hs_i;
assign vga_vs = video_vs_i;
assign vga_d = {diag_rgb[23:20], diag_rgb[15:12], diag_rgb[7:4]};

seg_hex_display u_seg_hex_display (
    .clk(mem_clk), .rst_n(mem_rst_n),
    .value({test_status, captured_data[11:0]}), .seg_data(seg_data), .seg_sel(seg_sel)
);

hdmi_tx u_hdmi_tx (
    .PXLCLK_I(video_clk), .PXLCLK_5X_I(video_clk_5x), .RST_N(key_n[0]),
    .VGA_HS(video_hs_i), .VGA_VS(video_vs_i), .VGA_DE(video_de_i), .VGA_RGB(diag_rgb),
    .HDMI_CLK_P(hdmi1_clk_p), .HDMI_D2_P(hdmi1_d2_p), .HDMI_D1_P(hdmi1_d1_p),
    .HDMI_D0_P(hdmi1_d0_p)
);
endmodule

`default_nettype wire
