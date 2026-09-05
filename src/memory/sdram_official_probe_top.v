`timescale 1ns / 1ps
`default_nettype none

// Standalone SDRAM self-test using the unmodified official controller and its
// 125 MHz / 180-degree shifted clock pair. This top is never mixed with top.v.
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

wire mem_clk;
wire mem_clk_sft;
wire mem_rst_n;
wire init_done;
wire init_refresh_valid;
wire mem_busy;
wire app_wr_en;
wire [20:0] app_wr_addr;
wire [3:0] app_wr_dm;
wire [31:0] app_wr_data;
wire app_rd_en;
wire [20:0] app_rd_addr;
wire read_valid;
wire [31:0] read_data;
wire [3:0] test_status;
wire [31:0] captured_data;
wire test_pass;
wire test_fail;
reg [26:0] heartbeat_count;

// C1 is the controller clock; C2 is the same 125 MHz clock at 180 degrees
// and is sampled by the EG4 SDRAM hard macro inside the official IP.
sys_pll u_sys_pll (
    .refclk  (clk_50m),
    .reset   (1'b0),
    .clk0_out(),
    .clk1_out(mem_clk),
    .clk2_out(mem_clk_sft)
);

reset_sync u_reset_sync (
    .clk    (mem_clk),
    .arst_n (key_n[0]),
    .srst_n (mem_rst_n)
);

sdram u_sdram (
    .Clk               (mem_clk),
    .Clk_sft           (mem_clk_sft),
    .Rst               (~mem_rst_n),
    .Sdr_init_done     (init_done),
    .Sdr_init_ref_vld  (init_refresh_valid),
    .Sdr_busy          (mem_busy),
    .App_wr_en         (app_wr_en),
    .App_wr_addr       (app_wr_addr),
    .App_wr_dm         (app_wr_dm),
    .App_wr_din        (app_wr_data),
    .App_rd_en         (app_rd_en),
    .App_rd_addr       (app_rd_addr),
    .Sdr_rd_en         (read_valid),
    .Sdr_rd_dout       (read_data)
);

sdram_self_test u_sdram_self_test (
    .clk          (mem_clk),
    .rst_n        (mem_rst_n),
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

assign app_wr_dm = 4'b0000;

always @(posedge mem_clk or negedge mem_rst_n) begin
    if (!mem_rst_n)
        heartbeat_count <= 27'd0;
    else
        heartbeat_count <= heartbeat_count + 27'd1;
end

// LED1: heartbeat, LED2: official IP initialized, LED3: self-test passed,
// LED4: self-test failed. A passed test requires LED2 and LED3 lit.
assign led[0] = heartbeat_count[25];
assign led[1] = init_done;
assign led[2] = test_pass;
assign led[3] = test_fail;

seg_hex_display u_seg_hex_display (
    .clk     (mem_clk),
    .rst_n   (mem_rst_n),
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
