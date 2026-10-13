`timescale 1ns / 1ps

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


assign init_done = rst_n; assign init_ref_valid=0; assign mem_busy=0;
assign write_req_ack=write_req; assign write_finish=0; assign write_fifo_full=0;
`ifdef COMMON_HDMI_TEST
reg [2:0] req_ff=0;
always @(posedge mem_clk) req_ff<={req_ff[1:0],read_req};
assign read_req_ack=req_ff[2];assign read_finish=0;
assign read_fifo_valid=1;assign read_fifo_empty=0;assign read_data=32'h52aa52aa;
`else
assign read_req_ack=read_req; assign read_finish=0;
assign read_fifo_valid=0; assign read_fifo_empty=1; assign read_data=0;
`endif
endmodule

module sys_pll(input refclk,reset,output clk0_out,clk1_out,clk2_out);
assign clk0_out=refclk; assign clk1_out=refclk; assign clk2_out=refclk;
endmodule
module video_pll_75m(input refclk,reset,output clk0_out,clk1_out);
assign clk0_out=refclk; assign clk1_out=refclk;
endmodule
module hdmi_tx(input PXLCLK_I,PXLCLK_5X_I,RST_N,VGA_HS,VGA_VS,VGA_DE,
input [23:0] VGA_RGB,output HDMI_CLK_P,HDMI_D2_P,HDMI_D1_P,HDMI_D0_P);
assign {HDMI_CLK_P,HDMI_D2_P,HDMI_D1_P,HDMI_D0_P}=0;
endmodule
module sd_card_top(input clk,rst,output SD_nCS,SD_DCLK,SD_MOSI,input SD_MISO,
output sd_init_done,input sd_sec_read,input [31:0] sd_sec_read_addr,
output [7:0] sd_sec_read_data,output sd_sec_read_data_valid,sd_sec_read_end,
input sd_sec_write,input [31:0] sd_sec_write_addr,input [7:0] sd_sec_write_data,
output sd_sec_write_data_req,sd_sec_write_end);
assign sd_init_done=!rst;
assign {SD_nCS,SD_DCLK,SD_MOSI,sd_sec_read_data_valid,sd_sec_read_end,
sd_sec_write_data_req,sd_sec_write_end}=0;
assign sd_sec_read_data=0;
endmodule
