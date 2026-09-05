`timescale 1ns / 1ps
`default_nettype none

// The first SDRAM milestone only starts the vendor controller and exposes its
// health signals. No frame transaction is issued from this module yet.
module sdram_init_probe (
    input  wire clk_50m,
    input  wire rst_n,
    output wire init_done,
    output wire init_ref_valid,
    output wire busy
);

wire mem_clk;
wire mem_clk_sft;

sys_pll u_sdram_pll (
    .refclk  (clk_50m),
    .reset   (~rst_n),
    .clk0_out(),
    .clk1_out(mem_clk),
    .clk2_out(mem_clk_sft)
);

sdram u_sdram (
    .Clk             (mem_clk),
    .Clk_sft         (mem_clk_sft),
    .Rst             (~rst_n),
    .Sdr_init_done   (init_done),
    .Sdr_init_ref_vld(init_ref_valid),
    .Sdr_busy        (busy),
    .App_wr_en       (1'b0),
    .App_wr_addr     (21'd0),
    .App_wr_dm       (4'd0),
    .App_wr_din      (32'd0),
    .App_rd_en       (1'b0),
    .App_rd_addr     (21'd0),
    .Sdr_rd_en       (),
    .Sdr_rd_dout     ()
);

endmodule

`default_nettype wire
