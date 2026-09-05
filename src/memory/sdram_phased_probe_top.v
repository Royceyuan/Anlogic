`timescale 1ns / 1ps
`default_nettype none

// Standalone timing experiment. This top is not part of the formal player.
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

wire ctrl_clk;
wire sdram_clk;
wire rst_n;
wire init_done;
wire mem_busy;
wire app_wr_en;
wire [20:0] app_wr_addr;
wire [31:0] app_wr_data;
wire app_rd_en;
wire [20:0] app_rd_addr;
wire read_valid;
wire [31:0] read_data;
wire [3:0] test_status;
wire [31:0] captured_data;
wire test_pass;
wire test_fail;
reg [25:0] heartbeat_count;

sdram_pll_50m_phased u_sdram_pll (
    .refclk  (clk_50m),
    .reset   (1'b0),
    .clk0_out(ctrl_clk),
    .clk1_out(sdram_clk),
    .clk2_out()
);

reset_sync u_reset_sync (
    .clk    (ctrl_clk),
    .arst_n (key_n[0]),
    .srst_n (rst_n)
);

sdram_native_50m #(
    .USE_SEPARATE_SDRAM_CLK(1)
) u_sdram_native_50m (
    .clk        (ctrl_clk),
    .sdram_clk  (sdram_clk),
    .rst_n      (rst_n),
    .app_wr_en  (app_wr_en),
    .app_wr_addr(app_wr_addr),
    .app_wr_data(app_wr_data),
    .app_rd_en  (app_rd_en),
    .app_rd_addr(app_rd_addr),
    .init_done  (init_done),
    .busy       (mem_busy),
    .read_valid (read_valid),
    .read_data  (read_data)
);

sdram_self_test u_sdram_self_test (
    .clk          (ctrl_clk),
    .rst_n        (rst_n),
    .init_done    (init_done),
    .mem_busy     (mem_busy),
    .app_wr_en    (app_wr_en),
    .app_wr_addr  (app_wr_addr),
    .app_wr_data  (app_wr_data),
    .app_rd_en    (app_rd_en),
    .app_rd_addr  (app_rd_addr),
    .read_valid   (read_valid),
    .read_data    (read_data),
    .status       (test_status),
    .captured_data(captured_data),
    .pass         (test_pass),
    .fail         (test_fail)
);

always @(posedge ctrl_clk or negedge rst_n) begin
    if (!rst_n)
        heartbeat_count <= 26'd0;
    else
        heartbeat_count <= heartbeat_count + 26'd1;
end

assign led[0] = heartbeat_count[24];
assign led[1] = init_done;
assign led[2] = test_pass;
assign led[3] = test_fail;

seg_hex_display u_seg_hex_display (
    .clk     (ctrl_clk),
    .rst_n   (rst_n),
    .value   ({test_status, captured_data[11:0]}),
    .seg_data(seg_data),
    .seg_sel (seg_sel)
);

assign sd_clk      = 1'b0;
assign sd_mosi     = 1'b0;
assign sd_cs_n     = 1'b1;
assign vga_hs      = 1'b1;
assign vga_vs      = 1'b1;
assign vga_d       = 12'd0;
assign hdmi1_clk_p = 1'b0;
assign hdmi1_d2_p  = 1'b0;
assign hdmi1_d1_p  = 1'b0;
assign hdmi1_d0_p  = 1'b0;

endmodule

`default_nettype wire
