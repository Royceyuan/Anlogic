`timescale 1ns / 1ps
`default_nettype none

// Loads IMAGE0.BIN/IMAGE1.BIN or IMAGE0.BMP..IMAGE9.BMP from the FAT32 root
// when the multi-image BMP option is enabled.
// Sequence mode uses FRAME000.BIN/FRAME001.BIN or the matching BMP names.
// BIN files are big-endian RGB565. BMP files are 24-bit uncompressed images
// from 16x16 through the configured source limit. They are sampled into the
// row store and then written to the SDRAM frame; no full-size source buffer is
// required.
module fat32_image_loader #(
    parameter integer IMAGE_WIDTH  = 160,
    parameter integer IMAGE_HEIGHT = 120,
    parameter integer HIRES_WIDTH  = IMAGE_WIDTH,
    parameter integer HIRES_HEIGHT = IMAGE_HEIGHT,
    parameter integer IMAGE_ADDR_BITS = 15,
    parameter integer BMP_MAX_WIDTH  = 1024,
    parameter integer BMP_MAX_HEIGHT = 768,
    parameter integer ADAPTIVE_BMP   = 0,
    parameter integer MULTI_IMAGE_BMP = 0,
    parameter [15:0] ADAPTIVE_BACKGROUND_RGB565 = 16'h0000,
    // v72: replace the fixed 960/540 products with shifts and additions.
    // Disabled by default so existing release candidates keep their netlist.
    parameter integer RESOURCE_OPT_CONSTANT_MULT = 0
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        hires_frame,
    input  wire        load_start,
    input  wire [3:0]  image_file_index,
    input  wire        museum_detail_mode,
    input  wire [2:0]  museum_artifact_index,
    input  wire [1:0]  museum_detail_index,
    input  wire        bmp_mode,
    input  wire        sequence_mode,

    input  wire        sd_init_done,
    output reg         sd_sec_read,
    output reg [31:0]  sd_sec_read_addr,
    input  wire [7:0]  sd_sec_read_data,
    input  wire        sd_sec_read_data_valid,
    input  wire        sd_sec_read_end,

    // The SD core cannot be stopped part-way through a 512-byte sector.
    // This gate is sampled only between image sectors so a downstream
    // row-store can drain completed lines before more BMP pixels arrive.
    input  wire        image_continue,

    output reg         image_wr_en,
    output reg [IMAGE_ADDR_BITS-1:0] image_wr_addr,
    output reg [15:0]  image_wr_data,
    // Explicit coordinates avoid making the SDRAM integration derive a
    // non-power-of-two row address from image_wr_addr.
    output reg [10:0]  image_wr_row,
    output reg [10:0]  image_wr_col,
    output reg         busy,
    output reg         load_done,
    output reg         load_error,
    output reg [3:0]   status_code,
    // Latched only when an image transaction fails; retained for board diagnosis.
    output reg [3:0]   error_stage,
    // Original BMP dimensions, captured from the validated header.  These
    // remain stable until the next accepted image load.
    output reg [15:0]  bmp_source_width,
    output reg [15:0]  bmp_source_height
);

localparam integer BIN_IMAGE_BYTES  = IMAGE_WIDTH * IMAGE_HEIGHT * 2;
wire [31:0] target_width = hires_frame ? HIRES_WIDTH : IMAGE_WIDTH;
wire [31:0] target_height = hires_frame ? HIRES_HEIGHT : IMAGE_HEIGHT;
localparam integer BMP_HEADER_BYTES = 54;
localparam integer BMP_MAX_FILE_BYTES = BMP_HEADER_BYTES +
                                        BMP_MAX_WIDTH * BMP_MAX_HEIGHT * 3 +
                                        BMP_MAX_HEIGHT * 3;

function [31:0] mul_image_width;
    input [31:0] value;
    begin
        if (HIRES_WIDTH != IMAGE_WIDTH && hires_frame && HIRES_WIDTH == 1280)
            mul_image_width = (value << 10) + (value << 8);
        else if (RESOURCE_OPT_CONSTANT_MULT && (IMAGE_WIDTH == 960))
            mul_image_width = (value << 10) - (value << 6);
        else
            mul_image_width = value * IMAGE_WIDTH;
    end
endfunction

function [31:0] mul_image_height;
    input [31:0] value;
    begin
        if (HIRES_HEIGHT != IMAGE_HEIGHT && hires_frame && HIRES_HEIGHT == 720)
            mul_image_height = (value << 9) + (value << 7) +
                               (value << 6) + (value << 4);
        else if (RESOURCE_OPT_CONSTANT_MULT && (IMAGE_HEIGHT == 540))
            mul_image_height = (value << 9) + (value << 4) +
                               (value << 3) + (value << 2);
        else
            mul_image_height = value * IMAGE_HEIGHT;
    end
endfunction

localparam [4:0] S_WAIT_CARD = 5'd0;
localparam [4:0] S_WAIT_GO   = 5'd1;
localparam [4:0] S_REQ_LBA0  = 5'd2;
localparam [4:0] S_WAIT_LBA0 = 5'd3;
localparam [4:0] S_REQ_VBR   = 5'd4;
localparam [4:0] S_WAIT_VBR  = 5'd5;
localparam [4:0] S_REQ_ROOT  = 5'd6;
localparam [4:0] S_WAIT_ROOT = 5'd7;
localparam [4:0] S_REQ_IMAGE = 5'd8;
localparam [4:0] S_WAIT_IMAGE= 5'd9;
localparam [4:0] S_REQ_FAT   = 5'd10;
localparam [4:0] S_WAIT_FAT  = 5'd11;
localparam [4:0] S_DONE      = 5'd12;
localparam [4:0] S_ERROR     = 5'd13;
localparam [4:0] S_WAIT_IMAGE_DRAIN = 5'd14;
localparam [4:0] S_ADAPT_WAIT = 5'd15;
localparam [4:0] S_ADAPT_CALC = 5'd16;
localparam [4:0] S_ADAPT_LOAD = 5'd17;
localparam [4:0] S_ADAPT_ACTIVE = 5'd18;
localparam [4:0] S_ADAPT_BLACK = 5'd19;

localparam [3:0] ERR_NONE     = 4'd0;
localparam [3:0] ERR_VOLUME   = 4'd1;
localparam [3:0] ERR_ROOT     = 4'd2;
localparam [3:0] ERR_BMP      = 4'd3;
localparam [3:0] ERR_ROW_FIFO = 4'd4;
localparam [3:0] ERR_INCOMPLETE = 4'd5;
localparam [3:0] ERR_FAT      = 4'd6;
localparam [3:0] ERR_INTERNAL = 4'd7;

reg [4:0] state;
reg [8:0] sector_byte_index;

reg [31:0] partition_start;
reg [31:0] volume_start;
reg [15:0] bpb_bytes_per_sector;
reg [7:0]  bpb_sectors_per_cluster;
reg [15:0] bpb_reserved_sectors;
reg [7:0]  bpb_num_fats;
reg [31:0] bpb_sectors_per_fat;
reg [31:0] bpb_root_cluster;
reg [31:0] fat_start;
reg [31:0] data_start;
reg [3:0]  cluster_shift;

reg        entry_name_match;
reg        entry_deleted;
reg [7:0]  entry_attr;
reg [15:0] entry_cluster_hi;
reg [15:0] entry_cluster_lo;
reg [31:0] entry_file_size;
reg        file_found;
reg [31:0] file_cluster;
reg [31:0] file_size;
reg [7:0]  root_sector_index;

reg [31:0] current_cluster;
reg [7:0]  sector_in_cluster;
reg [8:0]  fat_byte_offset;
reg [31:0] fat_next_cluster;

reg [31:0] file_bytes_seen;
reg [IMAGE_ADDR_BITS-1:0] image_pixels_seen;
reg        image_byte_high;
reg [7:0]  image_high_byte;
reg [10:0] bin_x;
reg [10:0] bin_y;
reg        active_bmp_mode;
reg        bmp_header_valid;
reg        bmp_top_down;
reg [7:0]  bmp_signature0;
reg [7:0]  bmp_signature1;
reg [31:0] bmp_data_offset;
reg [31:0] bmp_dib_size;
reg [31:0] bmp_width;
reg [31:0] bmp_height;
reg [15:0] bmp_planes;
reg [15:0] bmp_bits_per_pixel;
reg [31:0] bmp_compression;
reg [31:0] bmp_x;
reg [31:0] bmp_y;
reg [1:0]  bmp_component;
reg [7:0]  bmp_blue;
reg [7:0]  bmp_green;
reg [1:0]  bmp_padding_bytes;
reg        bmp_take_x;
reg        bmp_take_y;
reg [31:0] bmp_x_acc;
reg [31:0] bmp_y_acc;
reg [31:0] bmp_output_x;
reg [31:0] bmp_output_y;
reg [31:0] bmp_rows_done;
reg        image_resume_fat;

// Adaptive mode keeps only the bytes already read from the current SD
// sector plus one source row. The sector gate below prevents this FIFO from
// growing while a scaled destination row is being emitted.
// Keep the established 2048-pixel FIFO for v58/v59 inputs.  A 1920-pixel
// row can receive up to one more SD-sector fragment before S_ADAPT_LOAD takes
// ownership, so inputs above 1792 pixels use a 4096-pixel FIFO.  This keeps
// the source row contiguous rather than dropping the sector tail.
localparam integer ADAPT_FIFO_ADDR_BITS = (BMP_MAX_WIDTH > 1792) ? 12 : 11;
localparam integer ADAPT_FIFO_DEPTH = 1 << ADAPT_FIFO_ADDR_BITS;
reg [ADAPT_FIFO_ADDR_BITS-1:0] adapt_fifo_wr_ptr;
reg [ADAPT_FIFO_ADDR_BITS-1:0] adapt_fifo_rd_ptr;
reg [ADAPT_FIFO_ADDR_BITS:0] adapt_fifo_count;
wire [15:0] adapt_fifo_rd_data;
wire        adapt_fifo_wr_en;
wire [15:0] adapt_fifo_wr_data;
wire [15:0] adapt_row_mem_read;
wire        adapt_row_mem_write;
wire [10:0] adapt_row_mem_write_addr;
wire [15:0] adapt_row_mem_write_data;
reg [31:0] adapt_rows_received;
reg [31:0] adapt_src_row;
reg        adapt_row_valid;
reg        adapt_fifo_mode;
reg [31:0] adapt_q;
reg [31:0] adapt_out_col;
reg [31:0] adapt_load_col;
reg [31:0] adapt_v_next_src;
reg [31:0] adapt_v_d;
reg [31:0] adapt_v_acc;
reg [31:0] adapt_fit_w;
reg [31:0] adapt_fit_h;
reg [31:0] adapt_off_x;
reg [31:0] adapt_off_y;
reg [31:0] adapt_h_step;
reg [31:0] adapt_h_rem;
reg [31:0] adapt_h_src_x;
reg [31:0] adapt_h_acc;
reg [31:0] adapt_v_step;
reg [31:0] adapt_v_rem;
reg        adapt_calc_done;
reg [1:0]  adapt_calc_stage;
reg [5:0]  adapt_calc_bit;
reg [31:0] adapt_dividend;
reg [31:0] adapt_divisor;
reg [31:0] adapt_quotient;
reg [32:0] adapt_remainder;

wire [32:0] adapt_div_shift;
wire        adapt_div_ge;
wire [32:0] adapt_div_subtracted;
wire [31:0] adapt_div_quotient_next;
wire [31:0] adapt_div_remainder_next;
wire        adaptive_fit_by_width;

wire [31:0] expected_file_size;
wire [31:0] bmp_height_abs;
wire [31:0] bmp_dest_y;
wire [IMAGE_ADDR_BITS-1:0] bmp_dest_addr;
wire [31:0] bmp_x_acc_next;
wire [31:0] bmp_y_acc_next;
wire [1:0]  bmp_row_padding;

// The adaptive stream follows the BMP file-row order.  For a bottom-up BMP,
// active rows therefore map in reverse order, while the two black-border
// regions must be mapped to the unused rows on their corresponding sides.
// Using IMAGE_HEIGHT-1-adapt_q for every row is off by one when the centered
// fit leaves an odd number of border rows.
wire [31:0] adapt_dest_row = bmp_top_down ? adapt_q :
                             ((adapt_q < adapt_off_y) ?
                              (target_height - 1 - adapt_q) :
                              ((adapt_q >= adapt_off_y + adapt_fit_h) ?
                               (((adapt_q - (adapt_off_y + adapt_fit_h)) < adapt_off_y) ?
                                (adapt_q - (adapt_off_y + adapt_fit_h)) :
                                (adapt_off_y + adapt_fit_h +
                                 (adapt_q - (adapt_off_y + adapt_fit_h) - adapt_off_y))) :
                               (adapt_off_y + adapt_fit_h - 1 -
                                (adapt_q - adapt_off_y))));

assign expected_file_size = active_bmp_mode ? file_size : BIN_IMAGE_BYTES;
assign bmp_height_abs = bmp_height[31] ? (~bmp_height + 32'd1) : bmp_height;
assign bmp_dest_y = bmp_top_down ? bmp_output_y : (target_height - 1 - bmp_output_y);
assign bmp_dest_addr = mul_image_width(bmp_dest_y) + bmp_output_x;
assign bmp_x_acc_next = bmp_x_acc + target_width;
assign bmp_y_acc_next = bmp_y_acc + target_height;
assign bmp_row_padding = (4 - ((bmp_width * 3) & 32'd3)) & 32'd3;

assign adapt_div_shift = {adapt_remainder[31:0], adapt_dividend[31]};
assign adapt_div_ge = (adapt_div_shift >= {1'b0, adapt_divisor});
assign adapt_div_subtracted = adapt_div_ge ?
                              (adapt_div_shift - {1'b0, adapt_divisor}) :
                              adapt_div_shift;
assign adapt_div_quotient_next = adapt_div_ge ?
                                  (adapt_quotient | (32'd1 << adapt_calc_bit)) :
                                  adapt_quotient;
assign adapt_div_remainder_next = adapt_div_subtracted[31:0];
assign adaptive_fit_by_width = (mul_image_height(bmp_width) >=
                                mul_image_width(bmp_height_abs));
assign adapt_row_mem_write = ADAPTIVE_BMP &&
                             ((active_bmp_mode && sd_sec_read_data_valid &&
                               (file_bytes_seen >= bmp_data_offset) &&
                               (bmp_padding_bytes == 0) &&
                               (bmp_component == 2'd2) && !adapt_fifo_mode) ||
                              (state == S_ADAPT_LOAD && adapt_fifo_count != 0));
assign adapt_row_mem_write_addr = (state == S_ADAPT_LOAD) ?
                                  adapt_load_col[10:0] : bmp_x[10:0];
assign adapt_row_mem_write_data = (state == S_ADAPT_LOAD) ?
                                  adapt_fifo_rd_data :
                                  {sd_sec_read_data[7:3],
                                   bmp_green[7:2], bmp_blue[7:3]};
assign adapt_fifo_wr_en = active_bmp_mode && sd_sec_read_data_valid &&
                          (file_bytes_seen >= bmp_data_offset) &&
                          (bmp_padding_bytes == 0) &&
                          (bmp_component == 2'd2) && adapt_fifo_mode &&
                          (adapt_fifo_count != ADAPT_FIFO_DEPTH - 1);
assign adapt_fifo_wr_data = {sd_sec_read_data[7:3],
                             bmp_green[7:2], bmp_blue[7:3]};

generate
    if (ADAPTIVE_BMP) begin : g_adaptive_row_ram
        al_dp_ram16 #(.ADDR_WIDTH(ADAPT_FIFO_ADDR_BITS), .DEPTH(ADAPT_FIFO_DEPTH))
        u_adaptive_fifo (
            .clk(clk), .wr_en(adapt_fifo_wr_en),
            .wr_addr(adapt_fifo_wr_ptr), .wr_data(adapt_fifo_wr_data),
            .rd_addr(adapt_fifo_rd_ptr), .rd_data(adapt_fifo_rd_data)
        );

        adaptive_row_ram #(.ADDR_WIDTH(11), .DATA_DEPTH(BMP_MAX_WIDTH))
        u_adaptive_row_ram (
            .clk(clk), .wr_en(adapt_row_mem_write),
            .wr_addr(adapt_row_mem_write_addr), .wr_data(adapt_row_mem_write_data),
            .rd_addr(adapt_h_src_x[10:0]), .rd_data(adapt_row_mem_read)
        );
    end
endgenerate

function [7:0] expected_name_byte;
    input [3:0] index;
    input [3:0] file_index;
    input       select_bmp;
    input       select_sequence;
    input       select_museum_detail;
    input [2:0] artifact_index;
    input [1:0] detail_index;
    begin
        if (select_museum_detail) begin
            case (index)
                4'd0: expected_name_byte = "A";
                4'd1: expected_name_byte = "R";
                4'd2: expected_name_byte = "T";
                4'd3: expected_name_byte = "0" + artifact_index;
                4'd4: expected_name_byte = "D";
                4'd5: expected_name_byte = "0" + detail_index;
                4'd6, 4'd7: expected_name_byte = " ";
                4'd8: expected_name_byte = "B";
                4'd9: expected_name_byte = "M";
                default: expected_name_byte = "P";
            endcase
        end else if (select_sequence) begin
            case (index)
                4'd0: expected_name_byte = "F";
                4'd1: expected_name_byte = "R";
                4'd2: expected_name_byte = "A";
                4'd3: expected_name_byte = "M";
                4'd4: expected_name_byte = "E";
                4'd5: expected_name_byte = "0";
                4'd6: expected_name_byte = "0";
                4'd7: expected_name_byte = "0" + file_index;
                4'd8: expected_name_byte = "B";
                4'd9: expected_name_byte = select_bmp ? "M" : "I";
                default: expected_name_byte = select_bmp ? "P" : "N";
            endcase
        end else begin
            case (index)
                4'd0: expected_name_byte = "I";
                4'd1: expected_name_byte = "M";
                4'd2: expected_name_byte = "A";
                4'd3: expected_name_byte = "G";
                4'd4: expected_name_byte = "E";
                // IMAGE0.BMP through IMAGE9.BMP, plus the secondary screen's
                // IMAGEA.BMP emergency and IMAGEB.BMP help background. Keep
                // the old bit-0 behavior by default; v61 opts into the full
                // four-bit index without changing v60's synthesized path.
                4'd5: expected_name_byte = (MULTI_IMAGE_BMP && file_index == 4'd10) ?
                                            "A" : (MULTI_IMAGE_BMP && file_index == 4'd11) ?
                                            "B" : ("0" +
                                            (MULTI_IMAGE_BMP ? file_index :
                                                               file_index[0]));
                4'd6, 4'd7: expected_name_byte = " ";
                4'd8: expected_name_byte = "B";
                4'd9: expected_name_byte = select_bmp ? "M" : "I";
                default: expected_name_byte = select_bmp ? "P" : "N";
            endcase
        end
    end
endfunction

function [3:0] sectors_per_cluster_shift;
    input [7:0] sectors_per_cluster;
    begin
        case (sectors_per_cluster)
            8'd1:   sectors_per_cluster_shift = 4'd0;
            8'd2:   sectors_per_cluster_shift = 4'd1;
            8'd4:   sectors_per_cluster_shift = 4'd2;
            8'd8:   sectors_per_cluster_shift = 4'd3;
            8'd16:  sectors_per_cluster_shift = 4'd4;
            8'd32:  sectors_per_cluster_shift = 4'd5;
            8'd64:  sectors_per_cluster_shift = 4'd6;
            8'd128: sectors_per_cluster_shift = 4'd7;
            default: sectors_per_cluster_shift = 4'hf;
        endcase
    end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state                <= S_WAIT_CARD;
        sector_byte_index    <= 9'd0;
        sd_sec_read          <= 1'b0;
        sd_sec_read_addr     <= 32'd0;
        image_wr_en          <= 1'b0;
        image_wr_addr        <= {IMAGE_ADDR_BITS{1'b0}};
        image_wr_data        <= 16'd0;
        image_wr_row         <= 11'd0;
        image_wr_col         <= 11'd0;
        busy                 <= 1'b0;
        load_done            <= 1'b0;
        load_error           <= 1'b0;
        status_code          <= 4'd0;
        error_stage          <= ERR_NONE;
        bmp_source_width     <= 16'd0;
        bmp_source_height    <= 16'd0;
        partition_start      <= 32'd0;
        volume_start         <= 32'd0;
        bpb_bytes_per_sector <= 16'd0;
        bpb_sectors_per_cluster <= 8'd0;
        bpb_reserved_sectors <= 16'd0;
        bpb_num_fats         <= 8'd0;
        bpb_sectors_per_fat  <= 32'd0;
        bpb_root_cluster     <= 32'd0;
        fat_start            <= 32'd0;
        data_start           <= 32'd0;
        cluster_shift        <= 4'd0;
        entry_name_match     <= 1'b0;
        entry_deleted        <= 1'b0;
        entry_attr           <= 8'd0;
        entry_cluster_hi     <= 16'd0;
        entry_cluster_lo     <= 16'd0;
        entry_file_size      <= 32'd0;
        file_found           <= 1'b0;
        file_cluster         <= 32'd0;
        file_size            <= 32'd0;
        root_sector_index    <= 8'd0;
        current_cluster      <= 32'd0;
        sector_in_cluster    <= 8'd0;
        fat_byte_offset      <= 9'd0;
        fat_next_cluster     <= 32'd0;
        file_bytes_seen      <= 20'd0;
        image_pixels_seen    <= {IMAGE_ADDR_BITS{1'b0}};
        image_byte_high      <= 1'b0;
        image_high_byte      <= 8'd0;
        bin_x                <= 11'd0;
        bin_y                <= 11'd0;
        active_bmp_mode      <= 1'b0;
        bmp_header_valid     <= 1'b0;
        bmp_top_down         <= 1'b0;
        bmp_signature0       <= 8'd0;
        bmp_signature1       <= 8'd0;
        bmp_data_offset      <= 32'd0;
        bmp_dib_size         <= 32'd0;
        bmp_width            <= 32'd0;
        bmp_height           <= 32'd0;
        bmp_planes           <= 16'd0;
        bmp_bits_per_pixel   <= 16'd0;
        bmp_compression      <= 32'd0;
        bmp_x                <= 32'd0;
        bmp_y                <= 32'd0;
        bmp_component        <= 2'd0;
        bmp_blue             <= 8'd0;
        bmp_green            <= 8'd0;
        bmp_padding_bytes    <= 2'd0;
        bmp_take_x           <= 1'b1;
        bmp_take_y           <= 1'b1;
        bmp_x_acc            <= 32'd0;
        bmp_y_acc            <= 32'd0;
        bmp_output_x         <= 32'd0;
        bmp_output_y         <= 32'd0;
        bmp_rows_done        <= 32'd0;
        image_resume_fat     <= 1'b0;
        adapt_fifo_wr_ptr    <= {ADAPT_FIFO_ADDR_BITS{1'b0}};
        adapt_fifo_rd_ptr    <= {ADAPT_FIFO_ADDR_BITS{1'b0}};
        adapt_fifo_count     <= {(ADAPT_FIFO_ADDR_BITS + 1){1'b0}};
        adapt_rows_received  <= 32'd0;
        adapt_src_row        <= 32'd0;
        adapt_row_valid      <= 1'b0;
        adapt_fifo_mode      <= 1'b0;
        adapt_q              <= 32'd0;
        adapt_out_col        <= 32'd0;
        adapt_load_col       <= 32'd0;
        adapt_v_next_src     <= 32'd0;
        adapt_v_d             <= 32'd0;
        adapt_v_acc           <= 32'd0;
        adapt_fit_w           <= 32'd0;
        adapt_fit_h           <= 32'd0;
        adapt_off_x           <= 32'd0;
        adapt_off_y           <= 32'd0;
        adapt_h_step          <= 32'd0;
        adapt_h_rem           <= 32'd0;
        adapt_h_src_x         <= 32'd0;
        adapt_h_acc            <= 32'd0;
        adapt_v_step          <= 32'd0;
        adapt_v_rem           <= 32'd0;
        adapt_calc_done       <= 1'b0;
        adapt_calc_stage      <= 2'd0;
        adapt_calc_bit        <= 6'd0;
        adapt_dividend        <= 32'd0;
        adapt_divisor         <= 32'd0;
        adapt_quotient        <= 32'd0;
        adapt_remainder       <= 33'd0;
    end else begin
        image_wr_en <= 1'b0;

        case (state)
            S_WAIT_CARD: begin
                status_code <= 4'd1;
                if (sd_init_done)
                    state <= S_WAIT_GO;
            end

            S_WAIT_GO: begin
                status_code <= 4'd2;
                if (load_start) begin
                    busy             <= 1'b1;
                    load_done        <= 1'b0;
                    load_error       <= 1'b0;
                    error_stage      <= ERR_NONE;
                    partition_start  <= 32'd0;
                    active_bmp_mode  <= bmp_mode;
                    bmp_header_valid <= 1'b0;
                    state            <= S_REQ_LBA0;
                end
            end

            S_REQ_LBA0: begin
                status_code       <= 4'd3;
                sd_sec_read_addr  <= 32'd0;
                sector_byte_index <= 9'd0;
                sd_sec_read       <= 1'b1;
                state             <= S_WAIT_LBA0;
            end

            S_WAIT_LBA0, S_WAIT_VBR: begin
                if (sd_sec_read_data_valid) begin
                    if (sector_byte_index == 9'd11)
                        bpb_bytes_per_sector[7:0] <= sd_sec_read_data;
                    else if (sector_byte_index == 9'd12)
                        bpb_bytes_per_sector[15:8] <= sd_sec_read_data;
                    else if (sector_byte_index == 9'd13)
                        bpb_sectors_per_cluster <= sd_sec_read_data;
                    else if (sector_byte_index == 9'd14)
                        bpb_reserved_sectors[7:0] <= sd_sec_read_data;
                    else if (sector_byte_index == 9'd15)
                        bpb_reserved_sectors[15:8] <= sd_sec_read_data;
                    else if (sector_byte_index == 9'd16)
                        bpb_num_fats <= sd_sec_read_data;
                    else if (sector_byte_index == 9'd36)
                        bpb_sectors_per_fat[7:0] <= sd_sec_read_data;
                    else if (sector_byte_index == 9'd37)
                        bpb_sectors_per_fat[15:8] <= sd_sec_read_data;
                    else if (sector_byte_index == 9'd38)
                        bpb_sectors_per_fat[23:16] <= sd_sec_read_data;
                    else if (sector_byte_index == 9'd39)
                        bpb_sectors_per_fat[31:24] <= sd_sec_read_data;
                    else if (sector_byte_index == 9'd44)
                        bpb_root_cluster[7:0] <= sd_sec_read_data;
                    else if (sector_byte_index == 9'd45)
                        bpb_root_cluster[15:8] <= sd_sec_read_data;
                    else if (sector_byte_index == 9'd46)
                        bpb_root_cluster[23:16] <= sd_sec_read_data;
                    else if (sector_byte_index == 9'd47)
                        bpb_root_cluster[31:24] <= sd_sec_read_data;

                    if (state == S_WAIT_LBA0) begin
                        if (sector_byte_index == 9'd454)
                            partition_start[7:0] <= sd_sec_read_data;
                        else if (sector_byte_index == 9'd455)
                            partition_start[15:8] <= sd_sec_read_data;
                        else if (sector_byte_index == 9'd456)
                            partition_start[23:16] <= sd_sec_read_data;
                        else if (sector_byte_index == 9'd457)
                            partition_start[31:24] <= sd_sec_read_data;
                    end
                    sector_byte_index <= sector_byte_index + 9'd1;
                end

                if (sd_sec_read_end) begin
                    sd_sec_read <= 1'b0;
                    if (bpb_bytes_per_sector == 16'd512 &&
                        sectors_per_cluster_shift(bpb_sectors_per_cluster) != 4'hf &&
                        bpb_num_fats != 8'd0 && bpb_sectors_per_fat != 32'd0 &&
                        bpb_root_cluster >= 32'd2) begin
                        cluster_shift <= sectors_per_cluster_shift(bpb_sectors_per_cluster);
                        fat_start <= volume_start + bpb_reserved_sectors;
                        data_start <= volume_start + bpb_reserved_sectors +
                                      (bpb_num_fats * bpb_sectors_per_fat);
                        root_sector_index <= 8'd0;
                        file_found <= 1'b0;
                        state <= S_REQ_ROOT;
                    end else if (state == S_WAIT_LBA0 && partition_start != 32'd0) begin
                        volume_start <= partition_start;
                        state <= S_REQ_VBR;
                    end else begin
                        error_stage <= ERR_VOLUME;
                        state <= S_ERROR;
                    end
                end
            end

            S_REQ_VBR: begin
                status_code       <= 4'd4;
                sd_sec_read_addr  <= volume_start;
                sector_byte_index <= 9'd0;
                sd_sec_read       <= 1'b1;
                state             <= S_WAIT_VBR;
            end

            S_REQ_ROOT: begin
                status_code       <= 4'd5;
                sd_sec_read_addr  <= data_start +
                                     ((bpb_root_cluster - 32'd2) << cluster_shift) +
                                     root_sector_index;
                sector_byte_index <= 9'd0;
                sd_sec_read       <= 1'b1;
                state             <= S_WAIT_ROOT;
            end

            S_WAIT_ROOT: begin
                if (sd_sec_read_data_valid) begin
                    if (sector_byte_index[4:0] == 5'd0) begin
                        entry_name_match <= (sd_sec_read_data == expected_name_byte(
                                            4'd0, image_file_index, active_bmp_mode,
                                            sequence_mode, museum_detail_mode,
                                            museum_artifact_index, museum_detail_index));
                        entry_deleted <= (sd_sec_read_data == 8'h00 || sd_sec_read_data == 8'he5);
                    end else if (sector_byte_index[4:0] < 5'd11) begin
                        entry_name_match <= entry_name_match &&
                                            (sd_sec_read_data == expected_name_byte(
                                             sector_byte_index[3:0], image_file_index,
                                             active_bmp_mode, sequence_mode,
                                             museum_detail_mode, museum_artifact_index,
                                             museum_detail_index));
                    end else if (sector_byte_index[4:0] == 5'd11) begin
                        entry_attr <= sd_sec_read_data;
                    end else if (sector_byte_index[4:0] == 5'd20) begin
                        entry_cluster_hi[7:0] <= sd_sec_read_data;
                    end else if (sector_byte_index[4:0] == 5'd21) begin
                        entry_cluster_hi[15:8] <= sd_sec_read_data;
                    end else if (sector_byte_index[4:0] == 5'd26) begin
                        entry_cluster_lo[7:0] <= sd_sec_read_data;
                    end else if (sector_byte_index[4:0] == 5'd27) begin
                        entry_cluster_lo[15:8] <= sd_sec_read_data;
                    end else if (sector_byte_index[4:0] == 5'd28) begin
                        entry_file_size[7:0] <= sd_sec_read_data;
                    end else if (sector_byte_index[4:0] == 5'd29) begin
                        entry_file_size[15:8] <= sd_sec_read_data;
                    end else if (sector_byte_index[4:0] == 5'd30) begin
                        entry_file_size[23:16] <= sd_sec_read_data;
                    end else if (sector_byte_index[4:0] == 5'd31) begin
                        if (entry_name_match && !entry_deleted &&
                            entry_attr != 8'h0f && entry_attr != 8'h08) begin
                            file_found <= 1'b1;
                            file_cluster <= {entry_cluster_hi, entry_cluster_lo};
                            file_size <= {sd_sec_read_data, entry_file_size[23:0]};
                        end
                    end
                    sector_byte_index <= sector_byte_index + 9'd1;
                end

                if (sd_sec_read_end) begin
                    sd_sec_read <= 1'b0;
                    if (file_found) begin
                        if (file_cluster >= 32'd2 &&
                            ((!active_bmp_mode && file_size == BIN_IMAGE_BYTES) ||
                             (active_bmp_mode && file_size >= BMP_HEADER_BYTES &&
                              file_size <= BMP_MAX_FILE_BYTES))) begin
                            current_cluster   <= file_cluster;
                            sector_in_cluster <= 8'd0;
                            file_bytes_seen   <= 32'd0;
                            image_pixels_seen <= {IMAGE_ADDR_BITS{1'b0}};
                            image_byte_high   <= 1'b0;
                            bin_x             <= 11'd0;
                            bin_y             <= 11'd0;
                            bmp_header_valid  <= 1'b0;
                            bmp_top_down      <= 1'b0;
                            bmp_x             <= 32'd0;
                            bmp_y             <= 32'd0;
                            bmp_component     <= 2'd0;
                            bmp_padding_bytes <= 2'd0;
                            bmp_take_x        <= 1'b1;
                            bmp_take_y        <= 1'b1;
                            bmp_x_acc         <= 32'd0;
                            bmp_y_acc         <= 32'd0;
                            bmp_output_x      <= 32'd0;
                            bmp_output_y      <= 32'd0;
                            bmp_rows_done     <= 32'd0;
                            adapt_fifo_wr_ptr   <= {ADAPT_FIFO_ADDR_BITS{1'b0}};
                            adapt_fifo_rd_ptr   <= {ADAPT_FIFO_ADDR_BITS{1'b0}};
                            adapt_fifo_count    <= {(ADAPT_FIFO_ADDR_BITS + 1){1'b0}};
                            adapt_rows_received <= 32'd0;
                            adapt_src_row       <= 32'd0;
                            adapt_row_valid     <= 1'b0;
                            adapt_fifo_mode     <= 1'b0;
                            adapt_q             <= 32'd0;
                            adapt_out_col       <= 32'd0;
                            adapt_load_col      <= 32'd0;
                            adapt_v_next_src    <= 32'd0;
                            adapt_v_d            <= 32'd0;
                            adapt_v_acc          <= 32'd0;
                            state             <= S_REQ_IMAGE;
                        end else begin
                            error_stage <= ERR_ROOT;
                            state <= S_ERROR;
                        end
                    end else if (root_sector_index + 8'd1 < bpb_sectors_per_cluster) begin
                        root_sector_index <= root_sector_index + 8'd1;
                        state <= S_REQ_ROOT;
                    end else begin
                        error_stage <= ERR_ROOT;
                        state <= S_ERROR;
                    end
                end
            end

            S_REQ_IMAGE: begin
                status_code       <= 4'd6;
                sd_sec_read_addr  <= data_start +
                                     ((current_cluster - 32'd2) << cluster_shift) +
                                     sector_in_cluster;
                sector_byte_index <= 9'd0;
                sd_sec_read       <= 1'b1;
                state             <= S_WAIT_IMAGE;
            end

            S_WAIT_IMAGE: begin
                if (sd_sec_read_data_valid && file_bytes_seen < expected_file_size) begin
                    if (active_bmp_mode) begin
                        if (file_bytes_seen < BMP_HEADER_BYTES) begin
                            case (file_bytes_seen)
                                32'd0:  bmp_signature0 <= sd_sec_read_data;
                                32'd1:  bmp_signature1 <= sd_sec_read_data;
                                32'd10: bmp_data_offset[7:0] <= sd_sec_read_data;
                                32'd11: bmp_data_offset[15:8] <= sd_sec_read_data;
                                32'd12: bmp_data_offset[23:16] <= sd_sec_read_data;
                                32'd13: bmp_data_offset[31:24] <= sd_sec_read_data;
                                32'd14: bmp_dib_size[7:0] <= sd_sec_read_data;
                                32'd15: bmp_dib_size[15:8] <= sd_sec_read_data;
                                32'd16: bmp_dib_size[23:16] <= sd_sec_read_data;
                                32'd17: bmp_dib_size[31:24] <= sd_sec_read_data;
                                32'd18: bmp_width[7:0] <= sd_sec_read_data;
                                32'd19: bmp_width[15:8] <= sd_sec_read_data;
                                32'd20: bmp_width[23:16] <= sd_sec_read_data;
                                32'd21: bmp_width[31:24] <= sd_sec_read_data;
                                32'd22: bmp_height[7:0] <= sd_sec_read_data;
                                32'd23: bmp_height[15:8] <= sd_sec_read_data;
                                32'd24: bmp_height[23:16] <= sd_sec_read_data;
                                32'd25: bmp_height[31:24] <= sd_sec_read_data;
                                32'd26: bmp_planes[7:0] <= sd_sec_read_data;
                                32'd27: bmp_planes[15:8] <= sd_sec_read_data;
                                32'd28: bmp_bits_per_pixel[7:0] <= sd_sec_read_data;
                                32'd29: bmp_bits_per_pixel[15:8] <= sd_sec_read_data;
                                32'd30: bmp_compression[7:0] <= sd_sec_read_data;
                                32'd31: bmp_compression[15:8] <= sd_sec_read_data;
                                32'd32: bmp_compression[23:16] <= sd_sec_read_data;
                                32'd33: bmp_compression[31:24] <= sd_sec_read_data;
                                default: begin end
                            endcase

                            if (file_bytes_seen == BMP_HEADER_BYTES - 1) begin
                                bmp_header_valid <=
                                    (bmp_signature0 == "B") &&
                                    (bmp_signature1 == "M") &&
                                    (bmp_data_offset >= BMP_HEADER_BYTES) &&
                                    (bmp_dib_size == 32'd40) &&
                                    ((ADAPTIVE_BMP && bmp_width >= 32'd16) ||
                                     (!ADAPTIVE_BMP && bmp_width >= IMAGE_WIDTH)) &&
                                    (bmp_width <= BMP_MAX_WIDTH) &&
                                    ((ADAPTIVE_BMP && bmp_height_abs >= 32'd16) ||
                                     (!ADAPTIVE_BMP && bmp_height_abs >= IMAGE_HEIGHT)) &&
                                    (bmp_height_abs <= BMP_MAX_HEIGHT) &&
                                    (bmp_planes == 16'd1) &&
                                    (bmp_bits_per_pixel == 16'd24) &&
                                    (bmp_compression == 32'd0);
                                bmp_top_down <= bmp_height[31];
                                bmp_source_width  <= bmp_width[15:0];
                                bmp_source_height <= bmp_height_abs[15:0];
                                if (ADAPTIVE_BMP) begin
                                    adapt_fit_w       <= 32'd0;
                                    adapt_fit_h       <= 32'd0;
                                    adapt_off_x       <= 32'd0;
                                    adapt_off_y       <= 32'd0;
                                    adapt_h_step      <= 32'd0;
                                    adapt_h_rem       <= 32'd0;
                                    adapt_v_step      <= 32'd0;
                                    adapt_v_rem       <= 32'd0;
                                    adapt_calc_done   <= 1'b0;
                                    adapt_calc_stage  <= 2'd0;
                                    adapt_calc_bit    <= 6'd0;
                                    adapt_dividend    <= 32'd0;
                                    adapt_divisor     <= 32'd0;
                                    adapt_quotient    <= 32'd0;
                                    adapt_remainder   <= 33'd0;
                                    adapt_v_next_src  <= 32'd0;
                                    adapt_v_d          <= 32'd0;
                                    adapt_v_acc        <= 32'd0;
                                    adapt_q            <= 32'd0;
                                    adapt_src_row      <= 32'd0;
                                    adapt_rows_received<= 32'd0;
                                    adapt_row_valid    <= 1'b0;
                                    adapt_fifo_mode    <= 1'b0;
                                    adapt_fifo_wr_ptr  <= {ADAPT_FIFO_ADDR_BITS{1'b0}};
                                    adapt_fifo_rd_ptr  <= {ADAPT_FIFO_ADDR_BITS{1'b0}};
                                    adapt_fifo_count   <= {(ADAPT_FIFO_ADDR_BITS + 1){1'b0}};
                                end
                            end
                        end else if (!bmp_header_valid) begin
                            error_stage <= ERR_BMP;
                            state <= S_ERROR;
                        end else if (file_bytes_seen < bmp_data_offset) begin
                            // Standard 24-bit BMPs normally use offset 54, but
                            // accepting a later offset also handles legal header
                            // extensions before the pixel array.
                        end else if (ADAPTIVE_BMP) begin
                            // Adaptive mode stores source pixels first. This
                            // is deliberately sector-paced: the next sector
                            // is not requested until the FIFO has yielded a
                            // complete source row and its destination rows.
                            if (bmp_padding_bytes != 2'd0) begin
                                bmp_padding_bytes <= bmp_padding_bytes - 1'b1;
                            end else begin
                                case (bmp_component)
                                    2'd0: begin
                                        bmp_blue     <= sd_sec_read_data;
                                        bmp_component<= 2'd1;
                                    end
                                    2'd1: begin
                                        bmp_green    <= sd_sec_read_data;
                                        bmp_component<= 2'd2;
                                    end
                                    default: begin
                                        if (adapt_fifo_mode) begin
                                            if (adapt_fifo_count == ADAPT_FIFO_DEPTH - 1) begin
                                                error_stage <= ERR_ROW_FIFO;
                                                state <= S_ERROR;
                                            end else begin
                                                adapt_fifo_wr_ptr <= adapt_fifo_wr_ptr + 1'b1;
                                                adapt_fifo_count  <= adapt_fifo_count + 1'b1;
                                            end
                                        end else begin
                                        end
                                        bmp_component <= 2'd0;
                                        if (bmp_x == bmp_width - 1) begin
                                            bmp_x <= 32'd0;
                                            bmp_padding_bytes <= bmp_row_padding;
                                            adapt_rows_received <= adapt_rows_received + 1'b1;
                                            if (!adapt_fifo_mode) begin
                                                adapt_row_valid <= 1'b1;
                                                adapt_fifo_mode <= 1'b1;
                                            end
                                        end else begin
                                            bmp_x <= bmp_x + 1'b1;
                                        end
                                    end
                                endcase
                            end
                        end else begin
                            if (bmp_padding_bytes != 2'd0) begin
                                bmp_padding_bytes <= bmp_padding_bytes - 2'd1;
                            end else begin
                                case (bmp_component)
                                    2'd0: begin
                                        bmp_blue <= sd_sec_read_data;
                                        bmp_component <= 2'd1;
                                    end
                                    2'd1: begin
                                        bmp_green <= sd_sec_read_data;
                                        bmp_component <= 2'd2;
                                    end
                                    default: begin
                                        if (bmp_take_x && bmp_take_y) begin
                                            image_wr_en   <= 1'b1;
                                            image_wr_addr <= bmp_dest_addr;
                                            image_wr_row  <= bmp_dest_y[10:0];
                                            image_wr_col  <= bmp_output_x[10:0];
                                            image_wr_data <= {sd_sec_read_data[7:3],
                                                              bmp_green[7:2],
                                                              bmp_blue[7:3]};
                                            bmp_output_x <= bmp_output_x + 32'd1;
                                        end

                                        bmp_component <= 2'd0;
                                        if (bmp_x == bmp_width - 1) begin
                                            bmp_x <= 32'd0;
                                            bmp_padding_bytes <= bmp_row_padding;
                                            bmp_rows_done <= bmp_rows_done + 32'd1;
                                            bmp_output_x <= 32'd0;

                                            if (bmp_take_y)
                                                bmp_output_y <= bmp_output_y + 32'd1;

                                            if (bmp_y == bmp_height_abs - 1)
                                                bmp_y <= 32'd0;
                                            else
                                                bmp_y <= bmp_y + 32'd1;

                                            // DDA sampling emits row zero, then
                                            // evenly distributes the remaining
                                            // IMAGE_HEIGHT - 1 rows without a
                                            // divider or a full-size buffer.
                                            if (bmp_y_acc_next >= bmp_height_abs) begin
                                                bmp_take_y <= 1'b1;
                                                bmp_y_acc <= bmp_y_acc_next - bmp_height_abs;
                                            end else begin
                                                bmp_take_y <= 1'b0;
                                                bmp_y_acc <= bmp_y_acc_next;
                                            end
                                            bmp_take_x <= 1'b1;
                                            bmp_x_acc <= 32'd0;
                                        end else begin
                                            bmp_x <= bmp_x + 32'd1;
                                            if (bmp_x_acc_next >= bmp_width) begin
                                                bmp_take_x <= 1'b1;
                                                bmp_x_acc <= bmp_x_acc_next - bmp_width;
                                            end else begin
                                                bmp_take_x <= 1'b0;
                                                bmp_x_acc <= bmp_x_acc_next;
                                            end
                                        end
                                    end
                                endcase
                            end
                        end
                    end else begin
                        if (!image_byte_high) begin
                            image_high_byte <= sd_sec_read_data;
                            image_byte_high <= 1'b1;
                        end else begin
                            image_wr_en       <= 1'b1;
                            image_wr_addr     <= image_pixels_seen;
                            image_wr_data     <= {image_high_byte, sd_sec_read_data};
                            image_wr_row      <= bin_y;
                            image_wr_col      <= bin_x;
                            image_pixels_seen <= image_pixels_seen + 1'b1;
                            image_byte_high   <= 1'b0;
                            if (bin_x == IMAGE_WIDTH - 1) begin
                                bin_x <= 11'd0;
                                if (bin_y == IMAGE_HEIGHT - 1)
                                    bin_y <= 11'd0;
                                else
                                    bin_y <= bin_y + 1'b1;
                            end else begin
                                bin_x <= bin_x + 1'b1;
                            end
                        end
                    end
                    file_bytes_seen <= file_bytes_seen + 32'd1;
                end

                if (sd_sec_read_end) begin
                    sd_sec_read <= 1'b0;
                    if (active_bmp_mode && ADAPTIVE_BMP) begin
                        image_resume_fat <= (sector_in_cluster + 8'd1 >= bpb_sectors_per_cluster);
                        if (!adapt_calc_done) begin
                            adapt_calc_stage <= 2'd0;
                            adapt_calc_bit   <= 6'd31;
                            adapt_quotient   <= 32'd0;
                            adapt_remainder  <= 33'd0;
                            if (adaptive_fit_by_width) begin
                                adapt_dividend <= mul_image_width(bmp_height_abs);
                                adapt_divisor  <= bmp_width;
                            end else begin
                                adapt_dividend <= mul_image_height(bmp_width);
                                adapt_divisor  <= bmp_height_abs;
                            end
                            state <= S_ADAPT_CALC;
                        end else begin
                            state <= S_ADAPT_WAIT;
                        end
                    end else if (file_bytes_seen == expected_file_size &&
                        ((active_bmp_mode && bmp_header_valid && bmp_component == 2'd0 &&
                          bmp_padding_bytes == 2'd0 && bmp_rows_done == bmp_height_abs &&
                          bmp_output_y == target_height) ||
                         (!active_bmp_mode && !image_byte_high))) begin
                        load_done <= 1'b1;
                        busy <= 1'b0;
                        state <= S_DONE;
                    end else if (sector_in_cluster + 8'd1 < bpb_sectors_per_cluster) begin
                        // Do not start another SD sector until the row store
                        // has absorbed every completed line from this one.
                        image_resume_fat <= 1'b0;
                        state <= S_WAIT_IMAGE_DRAIN;
                    end else begin
                        image_resume_fat <= 1'b1;
                        state <= S_WAIT_IMAGE_DRAIN;
                    end
                end
            end

            S_WAIT_IMAGE_DRAIN: begin
                status_code <= 4'd6;
                sd_sec_read <= 1'b0;
                if (image_continue) begin
                    if (image_resume_fat) begin
                        fat_byte_offset <= {current_cluster[6:0], 2'b00};
                        fat_next_cluster <= 32'd0;
                        state <= S_REQ_FAT;
                    end else begin
                        sector_in_cluster <= sector_in_cluster + 8'd1;
                        state <= S_REQ_IMAGE;
                    end
                end
            end

            S_ADAPT_WAIT: begin
                status_code <= 4'd6;
                sd_sec_read <= 1'b0;
                if (!bmp_header_valid || adapt_fit_w == 0 || adapt_fit_h == 0) begin
                    error_stage <= ERR_BMP;
                    state <= S_ERROR;
                end else if (adapt_q >= target_height) begin
                    load_done <= 1'b1;
                    busy      <= 1'b0;
                    state     <= S_DONE;
                end else if ((adapt_q < adapt_off_y) ||
                             (adapt_q >= adapt_off_y + adapt_fit_h)) begin
                    if (image_continue) begin
                        adapt_out_col <= 32'd0;
                        state <= S_ADAPT_BLACK;
                    end
                end else if (adapt_row_valid) begin
                    if (adapt_v_next_src == adapt_src_row) begin
                        if (image_continue) begin
                            adapt_out_col   <= 32'd0;
                            adapt_h_src_x   <= 32'd0;
                            adapt_h_acc     <= 32'd0;
                            state           <= S_ADAPT_ACTIVE;
                        end
                    end else begin
                        adapt_row_valid <= 1'b0;
                        adapt_load_col  <= 32'd0;
                    end
                end else if (adapt_src_row >= bmp_height_abs) begin
                    if (file_bytes_seen == expected_file_size &&
                        adapt_fifo_count == 0) begin
                        error_stage <= ERR_INCOMPLETE;
                        state <= S_ERROR;
                    end else if (image_continue) begin
                        if (image_resume_fat) begin
                            fat_byte_offset <= {current_cluster[6:0], 2'b00};
                            fat_next_cluster <= 32'd0;
                            state <= S_REQ_FAT;
                        end else begin
                            sector_in_cluster <= sector_in_cluster + 1'b1;
                            state <= S_REQ_IMAGE;
                        end
                    end
                // A TF sector may finish in the middle of a source BMP row.
                // Do not drain that fragment: wait until the FIFO contains a
                // whole row, then load exactly bmp_width pixels into the row
                // RAM.  Draining any nonzero fragment loses row alignment and
                // eventually trips S_ERROR with a small FIFO residue.
                end else if (!adapt_row_valid && adapt_fifo_count >= bmp_width) begin
                    if (image_continue) begin
                        state <= S_ADAPT_LOAD;
                    end
                end else if (file_bytes_seen == expected_file_size) begin
                    error_stage <= ERR_INCOMPLETE;
                    state <= S_ERROR;
                end else if (image_continue) begin
                    if (image_resume_fat) begin
                        fat_byte_offset <= {current_cluster[6:0], 2'b00};
                        fat_next_cluster <= 32'd0;
                        state <= S_REQ_FAT;
                    end else begin
                        sector_in_cluster <= sector_in_cluster + 1'b1;
                        state <= S_REQ_IMAGE;
                    end
                end
            end

            S_ADAPT_CALC: begin
                status_code <= 4'd6;
                // One restoring-division bit per clock keeps the scaling
                // setup out of the pixel path and avoids a large divider.
                adapt_dividend <= {adapt_dividend[30:0], 1'b0};
                adapt_remainder <= {1'b0, adapt_div_remainder_next};
                adapt_quotient <= adapt_div_quotient_next;
                if (adapt_calc_bit == 0) begin
                    case (adapt_calc_stage)
                        2'd0: begin
                            if (adaptive_fit_by_width) begin
                                adapt_fit_w <= target_width;
                                adapt_fit_h <= adapt_div_quotient_next;
                                adapt_off_x <= 32'd0;
                                adapt_off_y <= (target_height - adapt_div_quotient_next) >> 1;
                                adapt_dividend <= bmp_width;
                                adapt_divisor  <= target_width;
                            end else begin
                                adapt_fit_w <= adapt_div_quotient_next;
                                adapt_fit_h <= target_height;
                                adapt_off_x <= (target_width - adapt_div_quotient_next) >> 1;
                                adapt_off_y <= 32'd0;
                                adapt_dividend <= bmp_width;
                                adapt_divisor  <= adapt_div_quotient_next;
                            end
                            adapt_calc_stage <= 2'd1;
                            adapt_calc_bit   <= 6'd31;
                            adapt_quotient   <= 32'd0;
                            adapt_remainder  <= 33'd0;
                        end
                        2'd1: begin
                            adapt_h_step <= adapt_div_quotient_next;
                            adapt_h_rem  <= adapt_div_remainder_next;
                            adapt_dividend <= bmp_height_abs;
                            adapt_divisor <= adapt_fit_h;
                            adapt_calc_stage <= 2'd2;
                            adapt_calc_bit   <= 6'd31;
                            adapt_quotient   <= 32'd0;
                            adapt_remainder  <= 33'd0;
                        end
                        default: begin
                            adapt_v_step    <= adapt_div_quotient_next;
                            adapt_v_rem     <= adapt_div_remainder_next;
                            adapt_calc_done <= 1'b1;
                            state <= S_ADAPT_WAIT;
                        end
                    endcase
                end else begin
                    adapt_calc_bit <= adapt_calc_bit - 1'b1;
                end
            end

            S_ADAPT_LOAD: begin
                status_code <= 4'd6;
                if (adapt_fifo_count == 0) begin
                    state <= S_ADAPT_WAIT;
                end else begin
                    adapt_fifo_rd_ptr <= adapt_fifo_rd_ptr + 1'b1;
                    adapt_fifo_count  <= adapt_fifo_count - 1'b1;
                    if (adapt_load_col == bmp_width - 1) begin
                        adapt_load_col  <= 32'd0;
                        adapt_src_row   <= adapt_src_row + 1'b1;
                        adapt_row_valid <= 1'b1;
                        state           <= S_ADAPT_WAIT;
                    end else begin
                        adapt_load_col <= adapt_load_col + 1'b1;
                    end
                end
            end

            S_ADAPT_ACTIVE: begin
                status_code    <= 4'd6;
                image_wr_en    <= 1'b1;
                image_wr_row   <= adapt_dest_row[10:0];
                image_wr_col   <= adapt_out_col[10:0];
                image_wr_addr  <= mul_image_width(adapt_dest_row) + adapt_out_col;
                if ((adapt_out_col < adapt_off_x) ||
                    (adapt_out_col >= adapt_off_x + adapt_fit_w)) begin
                    image_wr_data <= ADAPTIVE_BACKGROUND_RGB565;
                end else begin
                    image_wr_data <= adapt_row_mem_read;
                    adapt_h_src_x <= adapt_h_src_x + adapt_h_step;
                    if (adapt_h_acc + adapt_h_rem >= adapt_fit_w) begin
                        adapt_h_acc   <= adapt_h_acc + adapt_h_rem - adapt_fit_w;
                        adapt_h_src_x <= adapt_h_src_x + adapt_h_step + 1'b1;
                    end else begin
                        adapt_h_acc <= adapt_h_acc + adapt_h_rem;
                    end
                end

                if (adapt_out_col == target_width - 1) begin
                    adapt_out_col <= 32'd0;
                    adapt_q       <= adapt_q + 1'b1;
                    if (adapt_v_d == adapt_fit_h - 1) begin
                        adapt_v_d         <= adapt_fit_h;
                        adapt_v_next_src  <= bmp_height_abs;
                        adapt_v_acc       <= 32'd0;
                        adapt_src_row     <= bmp_height_abs;
                        adapt_row_valid   <= 1'b0;
                    end else begin
                        adapt_v_d <= adapt_v_d + 1'b1;
                        if (adapt_v_acc + adapt_v_rem >= adapt_fit_h) begin
                            adapt_v_acc      <= adapt_v_acc + adapt_v_rem - adapt_fit_h;
                            adapt_v_next_src <= adapt_v_next_src + adapt_v_step + 1'b1;
                        end else begin
                            adapt_v_acc <= adapt_v_acc + adapt_v_rem;
                            adapt_v_next_src <= adapt_v_next_src + adapt_v_step;
                        end
                        if (adapt_v_next_src != adapt_src_row)
                            adapt_row_valid <= 1'b0;
                    end
                    state <= S_ADAPT_WAIT;
                end else begin
                    adapt_out_col <= adapt_out_col + 1'b1;
                end
            end

            S_ADAPT_BLACK: begin
                status_code   <= 4'd6;
                image_wr_en   <= 1'b1;
                image_wr_row  <= adapt_dest_row[10:0];
                image_wr_col  <= adapt_out_col[10:0];
                image_wr_addr <= mul_image_width(adapt_dest_row) + adapt_out_col;
                image_wr_data <= ADAPTIVE_BACKGROUND_RGB565;
                if (adapt_out_col == target_width - 1) begin
                    adapt_out_col <= 32'd0;
                    adapt_q       <= adapt_q + 1'b1;
                    state         <= S_ADAPT_WAIT;
                end else begin
                    adapt_out_col <= adapt_out_col + 1'b1;
                end
            end

            S_REQ_FAT: begin
                status_code       <= 4'd7;
                sd_sec_read_addr  <= fat_start + (current_cluster >> 7);
                sector_byte_index <= 9'd0;
                sd_sec_read       <= 1'b1;
                state             <= S_WAIT_FAT;
            end

            S_WAIT_FAT: begin
                if (sd_sec_read_data_valid) begin
                    if (sector_byte_index == fat_byte_offset)
                        fat_next_cluster[7:0] <= sd_sec_read_data;
                    else if (sector_byte_index == fat_byte_offset + 9'd1)
                        fat_next_cluster[15:8] <= sd_sec_read_data;
                    else if (sector_byte_index == fat_byte_offset + 9'd2)
                        fat_next_cluster[23:16] <= sd_sec_read_data;
                    else if (sector_byte_index == fat_byte_offset + 9'd3)
                        fat_next_cluster[31:24] <= sd_sec_read_data;
                    sector_byte_index <= sector_byte_index + 9'd1;
                end

                if (sd_sec_read_end) begin
                    sd_sec_read <= 1'b0;
                    if (fat_next_cluster[27:0] >= 28'd2 &&
                        fat_next_cluster[27:0] < 28'hffffff8) begin
                        current_cluster <= {4'd0, fat_next_cluster[27:0]};
                        sector_in_cluster <= 8'd0;
                        state <= S_REQ_IMAGE;
                    end else begin
                        error_stage <= ERR_FAT;
                        state <= S_ERROR;
                    end
                end
            end

            S_DONE: begin
                status_code <= 4'd8;
                sd_sec_read <= 1'b0;
                if (load_start) begin
                    busy            <= 1'b1;
                    load_done       <= 1'b0;
                    load_error      <= 1'b0;
                    error_stage     <= ERR_NONE;
                    active_bmp_mode <= bmp_mode;
                    bmp_header_valid <= 1'b0;
                    partition_start <= 32'd0;
                    volume_start    <= 32'd0;
                    bpb_bytes_per_sector <= 16'd0;
                    bpb_sectors_per_cluster <= 8'd0;
                    bpb_reserved_sectors <= 16'd0;
                    bpb_num_fats    <= 8'd0;
                    bpb_sectors_per_fat <= 32'd0;
                    bpb_root_cluster <= 32'd0;
                    fat_start       <= 32'd0;
                    data_start      <= 32'd0;
                    file_found      <= 1'b0;
                    root_sector_index <= 8'd0;
                    state           <= S_REQ_LBA0;
                end
            end

            S_ERROR: begin
                status_code <= 4'd15;
                sd_sec_read <= 1'b0;
                if (load_start) begin
                    busy            <= 1'b1;
                    load_done       <= 1'b0;
                    load_error      <= 1'b0;
                    error_stage     <= ERR_NONE;
                    active_bmp_mode <= bmp_mode;
                    bmp_header_valid <= 1'b0;
                    partition_start <= 32'd0;
                    volume_start    <= 32'd0;
                    bpb_bytes_per_sector <= 16'd0;
                    bpb_sectors_per_cluster <= 8'd0;
                    bpb_reserved_sectors <= 16'd0;
                    bpb_num_fats    <= 8'd0;
                    bpb_sectors_per_fat <= 32'd0;
                    bpb_root_cluster <= 32'd0;
                    fat_start       <= 32'd0;
                    data_start      <= 32'd0;
                    file_found      <= 1'b0;
                    root_sector_index <= 8'd0;
                    state           <= S_REQ_LBA0;
                end else begin
                    busy       <= 1'b0;
                    load_error <= 1'b1;
                end
            end

            default: begin
                error_stage <= ERR_INTERNAL;
                state <= S_ERROR;
            end
        endcase
    end
end

endmodule

`default_nettype wire
