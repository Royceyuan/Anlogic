`timescale 1ns / 1ps
`default_nettype none

// Thin local wrapper around the proven Anlogic lab_ex_6 SDRAM/frame-path stack.
// The goal is to keep our project code talking in "whole frame" transactions,
// while the vendored modules keep handling burst scheduling and SDRAM access.
module anlogic_frame_store #(
    parameter integer MEM_DATA_BITS = 32,
    parameter integer ADDR_BITS     = 21,
    parameter integer BURST_BITS    = 9,
    parameter integer BURST_SIZE    = 256,
    parameter integer WRITE_BURST_SIZE = BURST_SIZE,
    parameter integer READ_BURST_SIZE  = BURST_SIZE,
    parameter READ_FIFO_OUTREG         = "NOREG",
    parameter integer READ_LOOP     = 1
)(
    input  wire                       mem_clk,
    input  wire                       mem_clk_sft,
    input  wire                       rst_n,
    output wire                       init_done,
    output wire                       init_ref_valid,
    output wire                       mem_busy,

    input  wire                       write_clk,
    input  wire                       write_req,
    output wire                       write_req_ack,
    output wire                       write_finish,
    output wire                       write_fifo_full,
    input  wire [ADDR_BITS-1:0]       write_base_addr,
    input  wire [ADDR_BITS-1:0]       write_len,
    input  wire                       write_en,
    input  wire [MEM_DATA_BITS-1:0]   write_data,

    input  wire                       read_clk,
    input  wire                       read_req,
    output wire                       read_req_ack,
    output wire                       read_finish,
    output wire                       read_fifo_valid,
    output wire                       read_fifo_empty,
    input  wire [ADDR_BITS-1:0]       read_base_addr,
    input  wire [ADDR_BITS-1:0]       read_len,
    input  wire                       read_en,
    output wire [MEM_DATA_BITS-1:0]   read_data
);

wire                     sdr_busy;
wire                     app_rd_en;
wire [ADDR_BITS-1:0]     app_rd_addr;
wire                     sdr_rd_en;
wire [MEM_DATA_BITS-1:0] sdr_rd_dout;
wire                     app_wr_en;
wire [ADDR_BITS-1:0]     app_wr_addr;
wire [MEM_DATA_BITS-1:0] app_wr_din;
wire [3:0]               app_wr_dm;

assign mem_busy = sdr_busy;

frame_read_write #(
    .MEM_DATA_BITS   (MEM_DATA_BITS),
    .READ_DATA_BITS  (MEM_DATA_BITS),
    .WRITE_DATA_BITS (MEM_DATA_BITS),
    .ADDR_BITS       (ADDR_BITS),
    .BURST_BITS      (BURST_BITS),
    .BURST_SIZE      (BURST_SIZE),
    .WRITE_BURST_SIZE(WRITE_BURST_SIZE),
    .READ_BURST_SIZE (READ_BURST_SIZE),
    .READ_LOOP       (READ_LOOP)
) u_frame_read_write (
    .rst             (~rst_n),
    .mem_clk         (mem_clk),
    .Sdr_init_done   (init_done),
    .Sdr_init_ref_vld(init_ref_valid),
    .Sdr_busy        (sdr_busy),

    .App_rd_en       (app_rd_en),
    .App_rd_addr     (app_rd_addr),
    .Sdr_rd_en       (sdr_rd_en),
    .Sdr_rd_dout     (sdr_rd_dout),

    .read_clk        (read_clk),
    .read_req        (read_req),
    .read_req_ack    (read_req_ack),
    .read_finish     (read_finish),
    .read_fifo_valid (read_fifo_valid),
    .read_fifo_empty (read_fifo_empty),
    .read_addr_0     (read_base_addr),
    .read_addr_1     ({ADDR_BITS{1'b0}}),
    .read_addr_2     ({ADDR_BITS{1'b0}}),
    .read_addr_3     ({ADDR_BITS{1'b0}}),
    .read_addr_index (2'd0),
    .read_len        (read_len),
    .read_en         (read_en),
    .read_data       (read_data),

    .App_wr_en       (app_wr_en),
    .App_wr_addr     (app_wr_addr),
    .App_wr_din      (app_wr_din),
    .App_wr_dm       (app_wr_dm),

    .write_clk       (write_clk),
    .write_req       (write_req),
    .write_req_ack   (write_req_ack),
    .write_finish    (write_finish),
    .write_fifo_full (write_fifo_full),
    .write_addr_0    (write_base_addr),
    .write_addr_1    ({ADDR_BITS{1'b0}}),
    .write_addr_2    ({ADDR_BITS{1'b0}}),
    .write_addr_3    ({ADDR_BITS{1'b0}}),
    .write_addr_index(2'd0),
    .write_len       (write_len),
    .write_en        (write_en),
    .write_data      (write_data)
);

sdram u_sdram (
    .Clk             (mem_clk),
    .Clk_sft         (mem_clk_sft),
    .Rst             (~rst_n),
    .Sdr_init_done   (init_done),
    .Sdr_init_ref_vld(init_ref_valid),
    .Sdr_busy        (sdr_busy),
    .App_wr_en       (app_wr_en),
    .App_wr_addr     (app_wr_addr),
    .App_wr_dm       (app_wr_dm),
    .App_wr_din      (app_wr_din),
    .App_rd_en       (app_rd_en),
    .App_rd_addr     (app_rd_addr),
    .Sdr_rd_en       (sdr_rd_en),
    .Sdr_rd_dout     (sdr_rd_dout)
);

endmodule

`default_nettype wire
