`timescale 1ns / 1ps
`default_nettype none

// Writes complete RGB565 rows into the existing frame-store transaction
// interface. Rows may arrive in either BMP orientation; the carried row
// number determines the SDRAM destination and no full frame is duplicated.
module bmp_sdram_row_writer #(
    parameter integer WIDTH       = 640,
    parameter integer HEIGHT      = 480,
    parameter integer ROW_BITS    = (HEIGHT <= 1) ? 1 : $clog2(HEIGHT),
    parameter integer ADDR_BITS   = 21,
    parameter integer WORDS_PER_ROW = WIDTH / 2,
    parameter integer BURST_WORDS  = WORDS_PER_ROW,
    parameter integer OVERVIEW_ENABLE = 0,
    parameter integer OVERVIEW_BRAM = 0,
    parameter integer ENABLE_ABORT = 0,
    parameter integer OVERVIEW_FRAME_COUNT = 5,
    parameter integer OVERVIEW_PANEL_WIDTH = WIDTH / OVERVIEW_FRAME_COUNT,
    parameter integer OVERVIEW_CROP_X0_0 = (WIDTH - OVERVIEW_PANEL_WIDTH) / 2,
    parameter integer OVERVIEW_CROP_X0_1 = (WIDTH - OVERVIEW_PANEL_WIDTH) / 2,
    parameter integer OVERVIEW_CROP_X0_2 = (WIDTH - OVERVIEW_PANEL_WIDTH) / 2,
    parameter integer OVERVIEW_CROP_X0_3 = (WIDTH - OVERVIEW_PANEL_WIDTH) / 2,
    parameter integer OVERVIEW_CROP_X0_4 = (WIDTH - OVERVIEW_PANEL_WIDTH) / 2
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    start,

    input  wire                    row_valid,
    input  wire [ROW_BITS-1:0]     row_index,
    input  wire [15:0]             row_pixel,
    input  wire                    row_last,
    output wire                    row_ready,

    input  wire [ADDR_BITS-1:0]    frame_base_addr,
    input  wire [ADDR_BITS-1:0]    overview_base_addr,
    input  wire [3:0]              overview_frame_index,

    output wire                    write_req,
    input  wire                    write_req_ack,
    output wire                    write_en,
    output wire [31:0]             write_data,
    output wire [ADDR_BITS-1:0]    write_base_addr,
    output wire [ADDR_BITS-1:0]    write_len,
    input  wire                    write_fifo_full,
    input  wire                    write_finish,
    input  wire                    abort,
    output wire                    abort_done,

    output reg                     frame_done,
    output reg                     error
);

localparam [2:0] S_IDLE   = 3'd0;
localparam [2:0] S_REQ    = 3'd1;
localparam [2:0] S_SETTLE = 3'd2;
localparam [2:0] S_STREAM = 3'd3;
localparam [2:0] S_DRAIN  = 3'd4;
localparam [2:0] S_DONE   = 3'd5;
localparam [2:0] S_ERROR  = 3'd6;

reg [2:0] state;
reg abort_seen;
wire abort_active = ENABLE_ABORT && abort;
wire packer_rst_n = rst_n && !(abort_active && !abort_seen);
assign abort_done = !abort_active || state == S_IDLE || state == S_DONE ||
                    state == S_ERROR;
reg [ROW_BITS-1:0] active_row;
reg [9:0] rows_done;
localparam integer BURSTS_PER_ROW = (WORDS_PER_ROW + BURST_WORDS - 1) / BURST_WORDS;
localparam integer BURST_INDEX_BITS = (BURSTS_PER_ROW <= 1) ? 1 : $clog2(BURSTS_PER_ROW);
reg [BURST_INDEX_BITS-1:0] burst_index;
reg [ADDR_BITS-1:0] burst_words_sent;
reg [5:0] settle_count;
reg overview_phase;
reg [3:0] active_overview_frame;
reg [10:0] active_crop_x0;
reg [10:0] row_pixel_index;
reg [10:0] overview_pixel_index;
wire [15:0] overview_pixel;

localparam integer OVERVIEW_WORDS_PER_ROW = OVERVIEW_PANEL_WIDTH / 2;
localparam integer OVERVIEW_BURSTS_PER_ROW =
    (OVERVIEW_WORDS_PER_ROW + BURST_WORDS - 1) / BURST_WORDS;

function [10:0] crop_x0_for_frame;
    input [3:0] index;
    begin
        case (index)
            4'd0: crop_x0_for_frame = OVERVIEW_CROP_X0_0;
            4'd1: crop_x0_for_frame = OVERVIEW_CROP_X0_1;
            4'd2: crop_x0_for_frame = OVERVIEW_CROP_X0_2;
            4'd3: crop_x0_for_frame = OVERVIEW_CROP_X0_3;
            default: crop_x0_for_frame = OVERVIEW_CROP_X0_4;
        endcase
    end
endfunction

wire pack_in_ready;
wire pack_out_valid;
wire [31:0] pack_out_data;
wire pack_out_ready;
wire pack_in_valid;
wire normal_pixel_fire;
wire overview_pixel_fire;
wire [ADDR_BITS-1:0] phase_words_per_row = overview_phase ?
                                                    OVERVIEW_WORDS_PER_ROW :
                                                    WORDS_PER_ROW;
wire [BURST_INDEX_BITS:0] phase_bursts_per_row = overview_phase ?
                                                    OVERVIEW_BURSTS_PER_ROW :
                                                    BURSTS_PER_ROW;

assign write_req      = (state == S_REQ);
assign write_base_addr = overview_phase ?
                         (overview_base_addr + active_row * WORDS_PER_ROW +
                          active_overview_frame * OVERVIEW_WORDS_PER_ROW +
                          burst_index * BURST_WORDS) :
                         (frame_base_addr + active_row * WORDS_PER_ROW +
                          burst_index * BURST_WORDS);
// The final burst can be shorter than BURST_WORDS (e.g. 480 words per
// 960-pixel row with 64-word bursts).  Request only the remaining words;
// otherwise the packer waits for pixels that do not exist and the frame
// can never complete.
assign write_len      = ((burst_index + 1) * BURST_WORDS <= phase_words_per_row) ?
                         BURST_WORDS :
                         (phase_words_per_row - burst_index * BURST_WORDS);

assign pack_out_ready = (state == S_STREAM) && !write_fifo_full;
assign pack_in_valid  = abort_active ? (state == S_STREAM) : overview_phase ?
                        ((state == S_STREAM) &&
                         (overview_pixel_index < OVERVIEW_PANEL_WIDTH)) :
                        (row_valid && row_ready);
assign row_ready      = !abort_active && !overview_phase && (state == S_STREAM) &&
                        !write_fifo_full && pack_in_ready;
assign write_en       = (state == S_STREAM) && pack_out_valid && !write_fifo_full;
assign write_data     = pack_out_data;
assign normal_pixel_fire = !overview_phase && pack_in_valid && pack_in_ready;
assign overview_pixel_fire = overview_phase && pack_in_valid && pack_in_ready;

wire overview_store = rst_n && !start && normal_pixel_fire && OVERVIEW_ENABLE &&
                      active_overview_frame < OVERVIEW_FRAME_COUNT &&
                      row_pixel_index >= active_crop_x0 &&
                      row_pixel_index < active_crop_x0 + OVERVIEW_PANEL_WIDTH;
localparam integer PANEL_ADDR_BITS = OVERVIEW_PANEL_WIDTH <= 1 ? 1 : $clog2(OVERVIEW_PANEL_WIDTH);
wire [PANEL_ADDR_BITS-1:0] overview_write_index = row_pixel_index - active_crop_x0;
generate
if (OVERVIEW_ENABLE && OVERVIEW_BRAM) begin : g_overview_bram
    al_dp_ram16 #(.ADDR_WIDTH(PANEL_ADDR_BITS), .DEPTH(1 << PANEL_ADDR_BITS),
                  .IMPLEMENT("32K")) u_line (
        .clk(clk), .wr_en(overview_store), .wr_addr(overview_write_index),
        .wr_data(row_pixel), .rd_addr(overview_pixel_index[PANEL_ADDR_BITS-1:0]),
        .rd_data(overview_pixel));
end else begin : g_overview_distributed
    reg [15:0] overview_line [0:OVERVIEW_PANEL_WIDTH-1];
    always @(posedge clk)
        if (rst_n && !start && overview_store)
            overview_line[overview_write_index] <= row_pixel;
    assign overview_pixel = overview_line[overview_pixel_index];
end
endgenerate

rgb565_stream_packer_ready u_packer (
    .clk       (clk),
    .rst_n     (packer_rst_n),
    .in_valid  (pack_in_valid),
    .in_ready  (pack_in_ready),
    .in_pixel  (abort_active ? 16'd0 : overview_phase ?
                ((overview_pixel_index < OVERVIEW_PANEL_WIDTH) ?
                 overview_pixel : 16'd0) : row_pixel),
    .out_valid (pack_out_valid),
    .out_data  (pack_out_data),
    .out_ready (pack_out_ready)
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        abort_seen <= 1'b0;
        state       <= S_IDLE;
        active_row  <= {ROW_BITS{1'b0}};
        rows_done   <= 10'd0;
        burst_index <= {BURST_INDEX_BITS{1'b0}};
        burst_words_sent <= {ADDR_BITS{1'b0}};
        settle_count <= 6'd0;
        overview_phase <= 1'b0;
        active_overview_frame <= 4'd0;
        active_crop_x0 <= 11'd0;
        row_pixel_index <= 11'd0;
        overview_pixel_index <= 11'd0;
        frame_done  <= 1'b0;
        error       <= 1'b0;
    end else if (start) begin
        abort_seen <= 1'b0;
        state        <= S_IDLE;
        active_row   <= {ROW_BITS{1'b0}};
        rows_done    <= 10'd0;
        burst_index <= {BURST_INDEX_BITS{1'b0}};
        burst_words_sent <= {ADDR_BITS{1'b0}};
        settle_count <= 6'd0;
        overview_phase <= 1'b0;
        active_overview_frame <= overview_frame_index;
        active_crop_x0 <= crop_x0_for_frame(overview_frame_index);
        row_pixel_index <= 11'd0;
        overview_pixel_index <= 11'd0;
        frame_done   <= 1'b0;
        error        <= 1'b0;
    end else begin
        abort_seen <= abort_active;
        case (state)
            S_IDLE: begin
                if (row_valid && !abort_active) begin
                    active_row <= row_index;
                    burst_index <= {BURST_INDEX_BITS{1'b0}};
                    burst_words_sent <= {ADDR_BITS{1'b0}};
                    overview_phase <= 1'b0;
                    row_pixel_index <= 11'd0;
                    overview_pixel_index <= 11'd0;
                    state      <= S_REQ;
                end
            end

            S_REQ: begin
                if (write_req_ack) begin
                    settle_count <= 6'd0;
                    state <= S_SETTLE;
                end
            end

            S_SETTLE: begin
                if (settle_count == 6'd63) begin
                    state <= S_STREAM;
                end else begin
                    settle_count <= settle_count + 1'b1;
                end
            end

            S_STREAM: begin
                if (normal_pixel_fire) begin
                    row_pixel_index <= row_pixel_index + 1'b1;
                end
                if (overview_pixel_fire)
                    overview_pixel_index <= overview_pixel_index + 1'b1;
                if (write_en) begin
                    if (burst_words_sent == write_len - 1) begin
                        state <= S_DRAIN;
                    end else begin
                        // The current request is exactly burst_words long.
                        // The next request is opened only after the frame
                        // FIFO reports that this one has finished.
                        burst_words_sent <= burst_words_sent + 1'b1;
                    end
                end
            end

            S_DRAIN: begin
                if (write_finish) begin
                    burst_words_sent <= {ADDR_BITS{1'b0}};
                    if (abort_active) begin
                        state <= S_IDLE;
                    end else if (burst_index == phase_bursts_per_row - 1) begin
                        burst_index <= {BURST_INDEX_BITS{1'b0}};
                        if (!overview_phase && OVERVIEW_ENABLE &&
                            active_overview_frame < OVERVIEW_FRAME_COUNT) begin
                            overview_phase <= 1'b1;
                            overview_pixel_index <= 11'd0;
                            state <= S_REQ;
                        end else begin
                            overview_phase <= 1'b0;
                            if (rows_done == HEIGHT - 1) begin
                                frame_done <= 1'b1;
                                state      <= S_DONE;
                            end else begin
                                rows_done <= rows_done + 1'b1;
                                state     <= S_IDLE;
                            end
                        end
                    end else begin
                        burst_index <= burst_index + 1'b1;
                        state <= S_REQ;
                    end
                end
            end

            S_DONE: begin
                state <= S_DONE;
            end

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
