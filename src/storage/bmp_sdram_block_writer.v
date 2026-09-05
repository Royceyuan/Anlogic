`timescale 1ns / 1ps
`default_nettype none

// The official frame FIFO completes writes only in 256-word bursts. This
// writer collects a continuous raster block of 512 RGB565 pixels, then sends
// exactly one 256-word transaction. Blocks are contiguous in SDRAM, so the
// existing linear HDMI reader remains unchanged.
module bmp_sdram_block_writer #(
    parameter integer WIDTH        = 640,
    parameter integer HEIGHT       = 480,
    parameter integer ADDR_BITS    = 21,
    parameter integer BLOCK_WORDS  = 256,
    parameter integer PIXELS_PER_BLOCK = BLOCK_WORDS * 2,
    parameter integer TOTAL_WORDS  = (WIDTH * HEIGHT) / 2,
    parameter integer BLOCK_COUNT  = TOTAL_WORDS / BLOCK_WORDS,
    parameter integer RESTARTABLE  = 0,
    parameter integer SECTOR_PIXELS = 256
)(
    input  wire                    clk,
    input  wire                    rst_n,

    input  wire                    row_valid,
    input  wire [15:0]             row_pixel,
    output wire                    row_ready,

    // Address is measured in 32-bit SDRAM words and stays stable per load.
    input  wire [ADDR_BITS-1:0]    frame_base_addr,
    input  wire                    start,

    output wire                    write_req,
    input  wire                    write_req_ack,
    output wire                    write_en,
    output wire [31:0]             write_data,
    output wire [ADDR_BITS-1:0]    write_base_addr,
    output wire [ADDR_BITS-1:0]    write_len,
    input  wire                    write_fifo_full,
    input  wire                    write_finish,

    // High only when another complete 512-byte SD sector can be accepted.
    output wire                    sector_continue,
    output reg                     frame_done,
    output reg                     error
);

localparam [2:0] S_FILL   = 3'd0;
localparam [2:0] S_REQ    = 3'd1;
localparam [2:0] S_SETTLE = 3'd2;
localparam [2:0] S_STREAM = 3'd3;
localparam [2:0] S_DRAIN  = 3'd4;
localparam [2:0] S_DONE   = 3'd5;
localparam [2:0] S_ERROR  = 3'd6;
localparam [2:0] S_IDLE   = 3'd7;

reg [2:0] state;
reg [$clog2(PIXELS_PER_BLOCK)-1:0] fill_count;
reg [$clog2(PIXELS_PER_BLOCK+1)-1:0] read_count;
reg [$clog2(BLOCK_COUNT)-1:0] block_index;
reg [$clog2(BLOCK_WORDS)-1:0] words_sent;
reg [5:0] settle_count;

wire pack_in_ready;
wire pack_out_valid;
wire [31:0] pack_out_data;
wire pack_out_ready;
wire pack_in_valid;
wire [8:0] block_mem_wr_addr;
wire [8:0] block_mem_rd_addr;
wire [15:0] block_mem_rd_data;

assign row_ready       = (state == S_FILL);
assign sector_continue = (state == S_FILL) &&
                         (fill_count <= PIXELS_PER_BLOCK - SECTOR_PIXELS);
assign write_req       = (state == S_REQ);
assign write_base_addr = frame_base_addr + block_index * BLOCK_WORDS;
assign write_len       = BLOCK_WORDS;
assign pack_out_ready  = (state == S_STREAM) && !write_fifo_full;
assign pack_in_valid   = (state == S_STREAM) &&
                         (read_count < PIXELS_PER_BLOCK) && pack_in_ready;
assign write_en        = (state == S_STREAM) && pack_out_valid &&
                         !write_fifo_full;
assign write_data      = pack_out_data;
assign block_mem_wr_addr = fill_count;
assign block_mem_rd_addr = read_count;

// The stable 640x480 profile uses 512 pixels per block. Keep this RAM
// interface fixed to that profile so TD cannot turn the buffer into LUTs.
al_dp_ram16 #(.ADDR_WIDTH(9), .DEPTH(512)) u_block_mem (
    .clk     (clk),
    .wr_en   ((state == S_FILL) && row_valid),
    .wr_addr (block_mem_wr_addr),
    .wr_data (row_pixel),
    .rd_addr (block_mem_rd_addr),
    .rd_data (block_mem_rd_data)
);

rgb565_stream_packer_ready u_packer (
    .clk       (clk),
    .rst_n     (rst_n),
    .in_valid  (pack_in_valid),
    .in_ready  (pack_in_ready),
    .in_pixel  (block_mem_rd_data),
    .out_valid (pack_out_valid),
    .out_data  (pack_out_data),
    .out_ready (pack_out_ready)
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state       <= RESTARTABLE ? S_IDLE : S_FILL;
        fill_count  <= {($clog2(PIXELS_PER_BLOCK)){1'b0}};
        read_count  <= {($clog2(PIXELS_PER_BLOCK+1)){1'b0}};
        block_index <= {($clog2(BLOCK_COUNT)){1'b0}};
        words_sent  <= {($clog2(BLOCK_WORDS)){1'b0}};
        settle_count <= 6'd0;
        frame_done  <= 1'b0;
        error       <= 1'b0;
    end else if (RESTARTABLE && start) begin
        state        <= S_FILL;
        fill_count   <= {($clog2(PIXELS_PER_BLOCK)){1'b0}};
        read_count   <= {($clog2(PIXELS_PER_BLOCK+1)){1'b0}};
        block_index  <= {($clog2(BLOCK_COUNT)){1'b0}};
        words_sent   <= {($clog2(BLOCK_WORDS)){1'b0}};
        settle_count <= 6'd0;
        frame_done   <= 1'b0;
        error        <= 1'b0;
    end else begin
        case (state)
            S_IDLE: begin
                state <= S_IDLE;
            end
            S_FILL: begin
                if (row_valid) begin
                    if (fill_count == PIXELS_PER_BLOCK - 1) begin
                        fill_count <= {($clog2(PIXELS_PER_BLOCK)){1'b0}};
                        state <= S_REQ;
                    end else begin
                        fill_count <= fill_count + 1'b1;
                    end
                end
            end

            S_REQ: begin
                if (write_req_ack) begin
                    // The official write FIFO is asynchronously cleared
                    // while write_req_ack is asserted. Match the official
                    // example's release delay before placing pixel data in it.
                    settle_count <= 6'd0;
                    state <= S_SETTLE;
                end
            end

            S_SETTLE: begin
                if (settle_count == 6'd63) begin
                    read_count <= {($clog2(PIXELS_PER_BLOCK+1)){1'b0}};
                    words_sent <= {($clog2(BLOCK_WORDS)){1'b0}};
                    state <= S_STREAM;
                end else begin
                    settle_count <= settle_count + 1'b1;
                end
            end

            S_STREAM: begin
                if (pack_in_valid)
                    read_count <= read_count + 1'b1;

                if (write_en) begin
                    if (words_sent == BLOCK_WORDS - 1)
                        state <= S_DRAIN;
                    else
                        words_sent <= words_sent + 1'b1;
                end
            end

            S_DRAIN: begin
                if (write_finish) begin
                    if (block_index == BLOCK_COUNT - 1) begin
                        frame_done <= 1'b1;
                        state <= S_DONE;
                    end else begin
                        block_index <= block_index + 1'b1;
                        state <= S_FILL;
                    end
                end
            end

            S_DONE: state <= S_DONE;

            S_ERROR: begin
                error <= 1'b1;
                state <= S_ERROR;
            end

            default: state <= S_ERROR;
        endcase
    end
end

endmodule

`default_nettype wire
