`timescale 1ns / 1ps
`default_nettype none

// Every output pixel is checked against the exact DDA sample position. Source
// dimensions and BMP orientation are parameters so one compiled test covers
// the adaptive input range without duplicating a large FAT32 disk model.
module tb_fat32_bmp_adaptive_loader #(
    parameter integer IMAGE_W = 640,
    parameter integer IMAGE_H = 480,
    parameter integer IMAGE_ADDR_BITS = 19,
    parameter integer ADAPTIVE_MODE = 1,
    parameter integer DIAG_PATTERN = 0,
    parameter integer SOURCE_W = 641,
    parameter integer SOURCE_H = 481,
    parameter integer TOP_DOWN = 0,
    parameter integer BITS_PER_PIXEL = 24,
    parameter integer COMPRESSION = 0,
    parameter integer EXPECT_ERROR = 0,
    parameter integer USE_BLOCK_WRITER = 0,
    parameter integer BMP_MAX_WIDTH = 1280,
    parameter integer BMP_MAX_HEIGHT = 720,
    parameter integer DISK_BYTES = 4194304,
    parameter integer IMAGE_INDEX = 0,
    parameter integer MULTI_IMAGE_BMP = 0,
    parameter integer MUSEUM_DETAIL = 0,
    parameter integer ARTIFACT_INDEX = 0,
    parameter integer DETAIL_INDEX = 1,
    parameter integer RESOURCE_OPT_CONSTANT_MULT = 0,
    parameter ADAPTIVE_RAM_IMPLEMENT = "9K"
);

localparam integer IMAGE_PIXELS = IMAGE_W * IMAGE_H;
localparam integer FRAME_WORDS = IMAGE_PIXELS / 2;
localparam integer ROW_BYTES = SOURCE_W * 3;
localparam integer ROW_PADDING = (4 - (ROW_BYTES & 3)) & 3;
localparam integer ROW_STRIDE = ROW_BYTES + ROW_PADDING;
localparam integer BMP_FILE_BYTES = 54 + SOURCE_H * ROW_STRIDE;
localparam signed [31:0] BMP_HEIGHT = TOP_DOWN ? -SOURCE_H : SOURCE_H;
localparam integer VOLUME_LBA = 2048;
localparam integer FAT_LBA = VOLUME_LBA + 32;
localparam integer DATA_LBA = VOLUME_LBA + 32 + 2;
localparam integer ROOT_LBA = DATA_LBA;
localparam integer FIRST_CLUSTER = 3;
localparam integer SECTORS_PER_CLUSTER = 64;
localparam integer FILE_SECTORS = (BMP_FILE_BYTES + 511) / 512;
localparam integer FILE_CLUSTERS = (FILE_SECTORS + SECTORS_PER_CLUSTER - 1) /
                                   SECTORS_PER_CLUSTER;

reg clk = 1'b0;
reg rst_n = 1'b0;
reg load_start = 1'b0;
reg sd_init_done = 1'b0;
reg [7:0] sd_sec_read_data = 8'd0;
reg sd_sec_read_data_valid = 1'b0;
reg sd_sec_read_end = 1'b0;
wire sd_sec_read;
wire [31:0] sd_sec_read_addr;
wire image_wr_en;
wire [IMAGE_ADDR_BITS-1:0] image_wr_addr;
wire [15:0] image_wr_data;
wire [10:0] image_wr_row;
wire [10:0] image_wr_col;
wire busy;
wire load_done;
wire load_error;
wire [3:0] status_code;
wire [15:0] image_source_width;
wire [15:0] image_source_height;
wire row_valid;
wire [10:0] row_index;
wire [15:0] row_pixel;
wire row_last;
wire row_ready;
wire row_input_continue;
wire row_overflow;
wire write_req;
wire write_req_ack;
wire write_en;
wire [31:0] write_data;
wire [20:0] write_base_addr;
wire [20:0] write_len;
wire write_fifo_full = 1'b0;
reg write_finish = 1'b0;
wire frame_done;
wire writer_error;
integer frame_write_count;
integer frame_error_count;
integer frame_fake_count;
integer frame_fake_base;
reg frame_req_seen;

reg [7:0] disk [0:DISK_BYTES-1];
reg [IMAGE_PIXELS-1:0] written;
integer i;
integer j;
integer file_byte;
integer pixel_byte;
integer source_pixel;
integer source_x;
integer source_y;
integer source_lba;
integer write_count;
integer error_count;
integer missing_count;

always #10 clk = ~clk;

fat32_image_loader #(
    .IMAGE_WIDTH(IMAGE_W),
    .IMAGE_HEIGHT(IMAGE_H),
    .IMAGE_ADDR_BITS(IMAGE_ADDR_BITS),
    .ADAPTIVE_BMP(ADAPTIVE_MODE),
    .BMP_MAX_WIDTH(BMP_MAX_WIDTH),
    .MULTI_IMAGE_BMP(MULTI_IMAGE_BMP),
    .RESOURCE_OPT_CONSTANT_MULT(RESOURCE_OPT_CONSTANT_MULT),
    .ADAPTIVE_RAM_IMPLEMENT(ADAPTIVE_RAM_IMPLEMENT),
    .BMP_MAX_HEIGHT(BMP_MAX_HEIGHT)
) dut (
    .clk                    (clk),
    .rst_n                  (rst_n),
    .load_start             (load_start),
    .image_file_index       (IMAGE_INDEX[3:0]),
    .museum_detail_mode     (MUSEUM_DETAIL != 0),
    .museum_artifact_index  (ARTIFACT_INDEX[2:0]),
    .museum_detail_index    (DETAIL_INDEX[1:0]),
    .bmp_mode               (1'b1), .sequence_mode(1'b0),
    .sd_init_done           (sd_init_done),
    .sd_sec_read            (sd_sec_read),
    .sd_sec_read_addr       (sd_sec_read_addr),
    .sd_sec_read_data       (sd_sec_read_data),
    .sd_sec_read_data_valid (sd_sec_read_data_valid),
    .sd_sec_read_end        (sd_sec_read_end),
    .image_continue         (row_input_continue),
    .image_wr_en            (image_wr_en),
    .image_wr_addr          (image_wr_addr),
    .image_wr_data          (image_wr_data),
    .image_wr_row           (image_wr_row),
    .image_wr_col           (image_wr_col),
    .busy                   (busy),
    .load_done              (load_done),
    .load_error             (load_error),
    .error_stage            (),
    .status_code            (status_code),
    .bmp_source_width       (image_source_width),
    .bmp_source_height      (image_source_height)
);

bmp_row_buffer #(
    .WIDTH(IMAGE_W), .HEIGHT(IMAGE_H), .COL_BITS(11), .ROW_BITS(11)
) u_rows (
    .clk(clk), .rst_n(rst_n), .in_valid(image_wr_en),
    .in_row(image_wr_row), .in_col(image_wr_col), .in_pixel(image_wr_data),
    .overflow(row_overflow), .out_valid(row_valid), .out_row(row_index),
    .out_pixel(row_pixel), .out_last(row_last), .out_ready(row_ready),
    .out_row_done(), .input_continue(row_input_continue)
);

generate
    if (USE_BLOCK_WRITER) begin : g_block_writer
        bmp_sdram_block_writer #(
            .WIDTH(IMAGE_W), .HEIGHT(IMAGE_H), .ADDR_BITS(21),
            .BLOCK_WORDS(128), .RESTARTABLE(1), .SECTOR_PIXELS(256)
        ) u_writer (
            .clk(clk), .rst_n(rst_n), .start(load_start),
            .row_valid(row_valid), .row_pixel(row_pixel), .row_ready(row_ready),
            .frame_base_addr(21'd0), .write_req(write_req),
            .write_req_ack(write_req_ack), .write_en(write_en),
            .write_data(write_data), .write_base_addr(write_base_addr),
            .write_len(write_len), .write_fifo_full(write_fifo_full),
            .write_finish(write_finish), .sector_continue(),
            .frame_done(frame_done), .error(writer_error)
        );
    end else begin : g_row_writer
        bmp_sdram_row_writer #(
            .WIDTH(IMAGE_W), .HEIGHT(IMAGE_H), .ROW_BITS(11), .ADDR_BITS(21),
            .WORDS_PER_ROW(IMAGE_W / 2), .BURST_WORDS(128)
        ) u_writer (
            .clk(clk), .rst_n(rst_n), .start(load_start),
            .row_valid(row_valid), .row_index(row_index), .row_pixel(row_pixel),
            .row_last(row_last), .row_ready(row_ready), .frame_base_addr(21'd0),
            .overview_base_addr(21'd0), .overview_frame_index(4'd0),
            .write_req(write_req), .write_req_ack(write_req_ack),
            .write_en(write_en), .write_data(write_data),
            .write_base_addr(write_base_addr), .write_len(write_len),
            .write_fifo_full(write_fifo_full), .write_finish(write_finish),
            .frame_done(frame_done), .error(writer_error)
        );
    end
endgenerate

assign write_req_ack = write_req;

task put_byte;
    input integer lba;
    input integer offset;
    input [7:0] value;
    begin
        disk[lba * 512 + offset] = value;
    end
endtask

task put_le32;
    input integer lba;
    input integer offset;
    input [31:0] value;
    begin
        put_byte(lba, offset, value[7:0]);
        put_byte(lba, offset + 1, value[15:8]);
        put_byte(lba, offset + 2, value[23:16]);
        put_byte(lba, offset + 3, value[31:24]);
    end
endtask

task put_fat32;
    input integer cluster;
    input [31:0] next_cluster;
    begin
        put_le32(FAT_LBA, cluster * 4, next_cluster);
    end
endtask

function integer lba_for_file_sector;
    input integer file_sector;
    begin
        lba_for_file_sector = DATA_LBA +
                              ((FIRST_CLUSTER + (file_sector / SECTORS_PER_CLUSTER) - 2) *
                               SECTORS_PER_CLUSTER) +
                              (file_sector % SECTORS_PER_CLUSTER);
    end
endfunction

function integer dda_source_position;
    input integer destination_index;
    input integer source_length;
    input integer destination_length;
    begin
        dda_source_position = (destination_index * source_length) /
                              destination_length;
    end
endfunction

function [7:0] source_blue;
    input integer x;
    input integer y;
    begin
        source_blue = DIAG_PATTERN ? ((x ^ y) & 31) << 3 : x[7:0];
    end
endfunction

function [7:0] source_green;
    input integer x;
    input integer y;
    begin
        source_green = DIAG_PATTERN ? ((y ^ (x >> 2)) & 63) << 2 : y[7:0];
    end
endfunction

function [7:0] source_red;
    input integer x;
    input integer y;
    begin
        source_red = DIAG_PATTERN ? ((x ^ (y << 1)) & 31) << 3 :
                                     (x + y) & 8'hff;
    end
endfunction

function [15:0] expected_pixel;
    input integer address;
    integer destination_x;
    integer destination_y;
    integer fit_w;
    integer fit_h;
    integer offset_x;
    integer offset_y;
    integer fit_x;
    integer fit_y;
    integer source_row_index;
    integer expected_x;
    integer expected_y;
    reg [7:0] red;
    reg [7:0] green;
    reg [7:0] blue;
    begin
        destination_x = address % IMAGE_W;
        destination_y = address / IMAGE_W;
        if (DIAG_PATTERN) begin
            if ((destination_x & 63) == 0 || (destination_y & 63) == 0)
                expected_pixel = 16'hffff;
            else if ((destination_x & 15) == 1 || (destination_y & 15) == 1)
                expected_pixel = 16'h0000;
            else begin
                red = ((destination_x ^ (destination_y << 1)) & 31) << 3;
                green = ((destination_y ^ (destination_x >> 2)) & 63) << 2;
                blue = ((destination_x ^ destination_y) & 31) << 3;
                expected_pixel = {red[7:3], green[7:2], blue[7:3]};
            end
        end else begin
        if (SOURCE_W * IMAGE_H >= SOURCE_H * IMAGE_W) begin
            fit_w = IMAGE_W;
            fit_h = (IMAGE_W * SOURCE_H) / SOURCE_W;
        end else begin
            fit_w = (IMAGE_H * SOURCE_W) / SOURCE_H;
            fit_h = IMAGE_H;
        end
        offset_x = (IMAGE_W - fit_w) / 2;
        offset_y = (IMAGE_H - fit_h) / 2;
        if (destination_x < offset_x || destination_x >= offset_x + fit_w ||
            destination_y < offset_y || destination_y >= offset_y + fit_h) begin
            expected_pixel = 16'h0000;
        end else begin
            fit_x = destination_x - offset_x;
            fit_y = destination_y - offset_y;
        // BMP rows arrive bottom-up, so display row zero comes from the
        // final DDA-selected source row.
            source_row_index = TOP_DOWN ? fit_y : (fit_h - 1 - fit_y);
            expected_x = dda_source_position(fit_x, SOURCE_W, fit_w);
            expected_y = dda_source_position(source_row_index, SOURCE_H, fit_h);
        red = source_red(expected_x, expected_y);
        green = source_green(expected_x, expected_y);
        blue = source_blue(expected_x, expected_y);
        expected_pixel = {red[7:3], green[7:2], blue[7:3]};
        end
        end
    end
endfunction

function [31:0] expected_word_addr;
    input integer address;
    begin
        expected_word_addr = {expected_pixel(address),
                              expected_pixel(address + 1)};
    end
endfunction

always @(posedge clk) begin
    write_finish <= 1'b0;
    if (write_req && !frame_req_seen) begin
        frame_fake_base  = write_base_addr;
        frame_fake_count = 0;
    end
    frame_req_seen <= write_req;
    if (write_en) begin
        frame_write_count = frame_write_count + 1;
        if (write_data !== expected_word_addr((frame_fake_base + frame_fake_count) * 2)) begin
            frame_error_count = frame_error_count + 1;
            if (frame_error_count < 4)
                $display("ROWPATH mismatch addr=%0d got=%h expected=%h",
                         frame_fake_base + frame_fake_count, write_data,
                         expected_word_addr((frame_fake_base + frame_fake_count) * 2));
        end
        frame_fake_count = frame_fake_count + 1;
        if (frame_fake_count == write_len)
            write_finish <= 1'b1;
    end
end

initial begin
    for (i = 0; i < DISK_BYTES; i = i + 1)
        disk[i] = 8'd0;

    // MBR and a minimal FAT32 boot record using 64-sector clusters.
    put_le32(0, 454, VOLUME_LBA);
    put_byte(VOLUME_LBA, 11, 8'h00);
    put_byte(VOLUME_LBA, 12, 8'h02);
    put_byte(VOLUME_LBA, 13, SECTORS_PER_CLUSTER);
    put_byte(VOLUME_LBA, 14, 8'd32);
    put_byte(VOLUME_LBA, 16, 8'd2);
    put_le32(VOLUME_LBA, 36, 32'd1);
    put_le32(VOLUME_LBA, 44, 32'd2);

    // Root entry: IMAGE#.BMP or the fixed MAIN-2 ART#D#.BMP slot.
    put_byte(ROOT_LBA, 0, MUSEUM_DETAIL ? "A" : "I");
    put_byte(ROOT_LBA, 1, MUSEUM_DETAIL ? "R" : "M");
    put_byte(ROOT_LBA, 2, MUSEUM_DETAIL ? "T" : "A");
    put_byte(ROOT_LBA, 3, MUSEUM_DETAIL ? ("0" + ARTIFACT_INDEX[2:0]) : "G");
    put_byte(ROOT_LBA, 4, MUSEUM_DETAIL ? "D" : "E");
    put_byte(ROOT_LBA, 5, "0" + (MUSEUM_DETAIL ? DETAIL_INDEX[1:0] : IMAGE_INDEX[3:0]));
    put_byte(ROOT_LBA, 6, " ");
    put_byte(ROOT_LBA, 7, " ");
    put_byte(ROOT_LBA, 8, "B");
    put_byte(ROOT_LBA, 9, "M");
    put_byte(ROOT_LBA, 10, "P");
    put_byte(ROOT_LBA, 11, 8'h20);
    put_le32(ROOT_LBA, 26, FIRST_CLUSTER);
    put_le32(ROOT_LBA, 28, BMP_FILE_BYTES);

    for (i = FIRST_CLUSTER; i < FIRST_CLUSTER + FILE_CLUSTERS - 1; i = i + 1)
        put_fat32(i, i + 1);
    put_fat32(FIRST_CLUSTER + FILE_CLUSTERS - 1, 32'h0fffffff);

    for (i = 0; i < FILE_SECTORS; i = i + 1) begin
        source_lba = lba_for_file_sector(i);
        for (j = 0; j < 512; j = j + 1) begin
            file_byte = i * 512 + j;
            if (file_byte == 0)
                put_byte(source_lba, j, "B");
            else if (file_byte == 1)
                put_byte(source_lba, j, "M");
            else if (file_byte >= 2 && file_byte <= 5)
                put_byte(source_lba, j, BMP_FILE_BYTES >> ((file_byte - 2) * 8));
            else if (file_byte == 10)
                put_byte(source_lba, j, 8'd54);
            else if (file_byte == 14)
                put_byte(source_lba, j, 8'd40);
            else if (file_byte >= 18 && file_byte <= 21)
                put_byte(source_lba, j, SOURCE_W >> ((file_byte - 18) * 8));
            else if (file_byte >= 22 && file_byte <= 25)
                put_byte(source_lba, j, BMP_HEIGHT >> ((file_byte - 22) * 8));
            else if (file_byte == 26)
                put_byte(source_lba, j, 8'd1);
            else if (file_byte >= 28 && file_byte <= 29)
                put_byte(source_lba, j,
                         BITS_PER_PIXEL >> ((file_byte - 28) * 8));
            else if (file_byte >= 30 && file_byte <= 33)
                put_byte(source_lba, j,
                         COMPRESSION >> ((file_byte - 30) * 8));
            else if (file_byte >= 54 && file_byte < BMP_FILE_BYTES) begin
                pixel_byte = file_byte - 54;
                if ((pixel_byte % ROW_STRIDE) < ROW_BYTES) begin
                    source_pixel = pixel_byte / ROW_STRIDE;
                    source_x = (pixel_byte % ROW_STRIDE) / 3;
                    source_y = source_pixel;
                    case ((pixel_byte % ROW_STRIDE) % 3)
                        0: put_byte(source_lba, j, source_blue(source_x, source_y));
                        1: put_byte(source_lba, j, source_green(source_x, source_y));
                        default: put_byte(source_lba, j, source_red(source_x, source_y));
                    endcase
                end
            end
        end
    end
end

always begin
    @(posedge sd_sec_read);
    for (i = 0; i < 512; i = i + 1) begin
        @(negedge clk);
        sd_sec_read_data = disk[sd_sec_read_addr * 512 + i];
        sd_sec_read_data_valid = 1'b1;
    end
    @(negedge clk);
    sd_sec_read_data_valid = 1'b0;
    sd_sec_read_end = 1'b1;
    @(negedge clk);
    sd_sec_read_end = 1'b0;
end

always @(negedge clk) begin
    if (image_wr_en) begin
        write_count = write_count + 1;
        if (image_wr_addr >= IMAGE_PIXELS) begin
            $display("Adaptive BMP: invalid write address %0d", image_wr_addr);
            error_count = error_count + 1;
        end else begin
            if (written[image_wr_addr]) begin
                $display("Adaptive BMP: duplicate write address %0d", image_wr_addr);
                error_count = error_count + 1;
            end
            written[image_wr_addr] = 1'b1;
            if (image_wr_data !== expected_pixel(image_wr_addr)) begin
                $display("Adaptive BMP: data mismatch addr=%0d got=%h expected=%h",
                         image_wr_addr, image_wr_data, expected_pixel(image_wr_addr));
                error_count = error_count + 1;
            end
        end
    end
end

initial begin
    written = {IMAGE_PIXELS{1'b0}};
    write_count = 0;
    error_count = 0;
    missing_count = 0;
    frame_write_count = 0;
    frame_error_count = 0;
    frame_fake_count = 0;
    frame_fake_base = 0;
    frame_req_seen = 1'b0;
    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    @(negedge clk);
    sd_init_done = 1'b1;
    @(negedge clk);
    load_start = 1'b1;
    @(negedge clk);
    load_start = 1'b0;

    if (EXPECT_ERROR)
        wait (load_error || load_done);
    else
        wait ((load_done || load_error) &&
              (frame_done || writer_error || row_overflow));
    repeat (2) @(posedge clk);
    for (i = 0; i < IMAGE_PIXELS; i = i + 1)
        if (!written[i])
            missing_count = missing_count + 1;

    if (EXPECT_ERROR) begin
        if (!load_error || load_done || write_count != 0) begin
            $display("Adaptive BMP invalid: FAIL done=%b error=%b writes=%0d status=%0d",
                     load_done, load_error, write_count, status_code);
            $stop;
        end
        $display("Adaptive BMP invalid: PASS bpp=%0d compression=%0d source=%0dx%0d",
                 BITS_PER_PIXEL, COMPRESSION, SOURCE_W, SOURCE_H);
        $finish;
    end

    if (!load_done || load_error || !frame_done || writer_error || row_overflow ||
        write_count != IMAGE_PIXELS || frame_write_count != FRAME_WORDS ||
        error_count != 0 || frame_error_count != 0 || missing_count != 0 ||
        image_source_width != SOURCE_W || image_source_height != SOURCE_H) begin
        $display("Adaptive BMP: FAIL done=%b error=%b frame_done=%b row_overflow=%b writes=%0d frame_words=%0d mismatches=%0d frame_mismatches=%0d missing=%0d status=%0d",
                 load_done, load_error, frame_done, row_overflow, write_count,
                 frame_write_count, error_count, frame_error_count,
                 missing_count, status_code);
        $stop;
    end

    $display("Adaptive BMP: PASS source=%0dx%0d top_down=%0d row_padding=%0d output=%0dx%0d",
             SOURCE_W, SOURCE_H, TOP_DOWN, ROW_PADDING, IMAGE_W, IMAGE_H);
    $finish;
end

initial begin
    // 1920x1080 transfers substantially more FAT32 sectors than the v58
    // range; retain the watchdog, but allow the large-input regression to
    // complete before declaring a transport timeout.
    #1500000000;
    $display("Adaptive BMP row path: TIMEOUT loader_done=%b load_error=%b frame_done=%b writes=%0d frame_words=%0d row_overflow=%b state=%0d status=%0d fifo=%0d src_row=%0d",
             load_done, load_error, frame_done, write_count, frame_write_count,
             row_overflow, dut.state, status_code, dut.adapt_fifo_count,
             dut.adapt_src_row);
    $finish;
end

endmodule

`default_nettype wire
