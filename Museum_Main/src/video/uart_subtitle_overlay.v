`timescale 1ns / 1ps
`default_nettype none

// v66 subtitle transport.  The host owns UTF-8/font rendering; this block
// accepts the resulting 800x32 one-bit image and swaps it only at a frame edge.
module uart_subtitle_overlay #(
    parameter integer WIDTH = 800,
    parameter integer HEIGHT = 32,
    parameter integer X_START = 0,
    parameter integer Y_START = 568,
    parameter integer DISPLAY_WIDTH = WIDTH,
    parameter integer FULL_WIDTH_SCROLL = 0,
    parameter integer UART_DIV = 434,
    parameter integer BITS_PER_PIXEL = 1,
    parameter integer PROTOCOL_VERSION = 1,
    parameter integer BRAM_REGISTER_READ = 0,
    parameter integer RESOURCE_OPT_ADDR = 0,
    parameter integer BITMAP_BYTES = (WIDTH * HEIGHT * BITS_PER_PIXEL) / 8
) (
    input  wire        clk_50m,
    input  wire        rst_n_50m,
    input  wire        uart_rxd,
    output wire        uart_txd,
    input  wire        video_clk,
    input  wire        video_rst_n,
    input  wire        video_frame_tick,
    input  wire        hs_i,
    input  wire        vs_i,
    input  wire        de_i,
    input  wire [10:0] x_i,
    input  wire [9:0]  y_i,
    input  wire [23:0] rgb_i,
    output reg         hs_o,
    output reg         vs_o,
    output reg         de_o,
    output reg  [23:0] rgb_o
);

localparam [15:0] CRC_INIT = 16'hffff;
localparam integer PIXELS_PER_BYTE = 8 / BITS_PER_PIXEL;
localparam integer RAM_ADDR_WIDTH = (BITMAP_BYTES <= 4096) ? 12 : 13;
localparam [15:0] EXPECTED_WIDTH = WIDTH;
localparam [7:0]  EXPECTED_HEIGHT = HEIGHT;
localparam [15:0] EXPECTED_LENGTH = BITMAP_BYTES;
localparam [3:0] P_SYNC0 = 4'd0, P_SYNC1 = 4'd1, P_HEADER = 4'd2,
                 P_PAYLOAD = 4'd3, P_CRC0 = 4'd4, P_CRC1 = 4'd5;
localparam [2:0] R_NONE = 3'd0, R_OK = 3'd1, R_CRC = 3'd2,
                 R_BUSY = 3'd3, R_FMT = 3'd4, R_TIMEOUT = 3'd5;

function [15:0] crc16_next;
    input [15:0] crc_in;
    input [7:0] data_in;
    integer i;
    reg [15:0] c;
    begin
        c = crc_in ^ {data_in, 8'h00};
        for (i = 0; i < 8; i = i + 1)
            c = c[15] ? ((c << 1) ^ 16'h1021) : (c << 1);
        crc16_next = c;
    end
endfunction

function [3:0] reply_length;
    input [2:0] code;
    begin
        case (code)
            R_OK: reply_length = 4'd4;       // OK\r\n
            R_CRC: reply_length = 4'd8;      // CRCERR\r\n
            R_BUSY: reply_length = 4'd6;     // BUSY\r\n
            R_FMT: reply_length = 4'd8;      // FMTERR\r\n
            default: reply_length = 4'd9;    // TIMEOUT\r\n
        endcase
    end
endfunction

function [7:0] reply_char;
    input [2:0] code;
    input [3:0] pos;
    begin
        case (code)
            R_OK: case (pos)
                0: reply_char = "O"; 1: reply_char = "K";
                2: reply_char = 8'h0d; default: reply_char = 8'h0a;
            endcase
            R_CRC: case (pos)
                0: reply_char = "C"; 1: reply_char = "R"; 2: reply_char = "C";
                3: reply_char = "E"; 4: reply_char = "R"; 5: reply_char = "R";
                6: reply_char = 8'h0d; default: reply_char = 8'h0a;
            endcase
            R_BUSY: case (pos)
                0: reply_char = "B"; 1: reply_char = "U"; 2: reply_char = "S";
                3: reply_char = "Y"; 4: reply_char = 8'h0d; default: reply_char = 8'h0a;
            endcase
            R_FMT: case (pos)
                0: reply_char = "F"; 1: reply_char = "M"; 2: reply_char = "T";
                3: reply_char = "E"; 4: reply_char = "R"; 5: reply_char = "R";
                6: reply_char = 8'h0d; default: reply_char = 8'h0a;
            endcase
            default: case (pos)
                0: reply_char = "T"; 1: reply_char = "I"; 2: reply_char = "M";
                3: reply_char = "E"; 4: reply_char = "O"; 5: reply_char = "U";
                6: reply_char = "T"; 7: reply_char = 8'h0d; default: reply_char = 8'h0a;
            endcase
        endcase
    end
endfunction

wire [7:0] rx_data;
wire       rx_valid;
reg        tx_valid;
reg [7:0]  tx_data;
wire       tx_ready;

uart_subtitle_rx #(.BAUD_DIV(UART_DIV)) u_rx (
    .clk(clk_50m), .rst_n(rst_n_50m), .rxd(uart_rxd),
    .data(rx_data), .valid(rx_valid)
);
uart_subtitle_tx #(.BAUD_DIV(UART_DIV)) u_tx (
    .clk(clk_50m), .rst_n(rst_n_50m), .data(tx_data), .valid(tx_valid),
    .ready(tx_ready), .txd(uart_txd)
);

reg [RAM_ADDR_WIDTH-1:0] write_addr;
reg [7:0]  write_data;
reg        write_enable;
reg        write_bank;
wire [7:0] bitmap0_q;
wire [7:0] bitmap1_q;

reg [3:0] parser_state;
reg [2:0] header_count;
reg [13:0] payload_count;
reg [15:0] crc_work;
reg [7:0] crc_low;
reg [7:0] header_version;
reg [7:0] header_mode;
reg [15:0] header_width;
reg [7:0] header_height;
reg [15:0] header_length;
reg header_good;
reg [24:0] idle_count;
reg commit_pending;
reg commit_toggle;
reg [7:0] commit_mode;
reg [15:0] commit_width;
reg ack_sync1, ack_sync2, ack_seen;
reg ack_toggle;
reg [2:0] response_pending;
reg [2:0] response_code;
reg [3:0] response_pos;
reg response_active;
reg tx_wait_busy;

always @(posedge clk_50m or negedge rst_n_50m) begin
    if (!rst_n_50m) begin
        parser_state <= P_SYNC0;
        header_count <= 3'd0;
        payload_count <= 14'd0;
        crc_work <= CRC_INIT;
        crc_low <= 8'd0;
        header_version <= 8'd0;
        header_mode <= 8'd0;
        header_width <= 16'd0;
        header_height <= 8'd0;
        header_length <= 16'd0;
        header_good <= 1'b0;
        idle_count <= 25'd0;
        commit_pending <= 1'b0;
        commit_toggle <= 1'b0;
        commit_mode <= 8'd0;
        commit_width <= EXPECTED_WIDTH;
        write_enable <= 1'b0;
        write_addr <= 12'd0;
        write_data <= 8'd0;
        write_bank <= 1'b1;
        ack_sync1 <= 1'b0;
        ack_sync2 <= 1'b0;
        ack_seen <= 1'b0;
        response_pending <= R_NONE;
        response_code <= R_NONE;
        response_pos <= 4'd0;
        response_active <= 1'b0;
        tx_wait_busy <= 1'b0;
        tx_valid <= 1'b0;
        tx_data <= 8'd0;
    end else begin
        write_enable <= 1'b0;
        tx_valid <= 1'b0;
        ack_sync1 <= ack_toggle;
        ack_sync2 <= ack_sync1;
        if (ack_sync2 != ack_seen) begin
            ack_seen <= ack_sync2;
            commit_pending <= 1'b0;
            write_bank <= ~write_bank;
        end

        if (!response_active && response_pending != R_NONE) begin
            response_active <= 1'b1;
            response_code <= response_pending;
            response_pos <= 4'd0;
            response_pending <= R_NONE;
            tx_wait_busy <= 1'b0;
        end else if (response_active) begin
            // uart_subtitle_tx samples valid on its clock edge.  Hold off
            // until it has visibly left ready, otherwise consecutive reply
            // bytes collapse into one pulse (the former "O" only response).
            if (tx_wait_busy && !tx_ready)
                tx_wait_busy <= 1'b0;
            else if (!tx_wait_busy && tx_ready) begin
                tx_valid <= 1'b1;
                tx_data <= reply_char(response_code, response_pos);
                tx_wait_busy <= 1'b1;
                if (response_pos == reply_length(response_code) - 1'b1)
                    response_active <= 1'b0;
                else
                    response_pos <= response_pos + 1'b1;
            end
        end

        if (rx_valid) begin
            idle_count <= 25'd0;
            case (parser_state)
                P_SYNC0: begin
                    if (rx_data == 8'h55) parser_state <= P_SYNC1;
                end
                P_SYNC1: begin
                    if (rx_data == 8'haa) begin
                        parser_state <= P_HEADER;
                        header_count <= 3'd0;
                        crc_work <= CRC_INIT;
                    end else if (rx_data != 8'h55)
                        parser_state <= P_SYNC0;
                end
                P_HEADER: begin
                    crc_work <= crc16_next(crc_work, rx_data);
                    case (header_count)
                        3'd0: header_version <= rx_data;
                        3'd1: header_mode <= rx_data;
                        3'd2: header_width[7:0] <= rx_data;
                        3'd3: header_width[15:8] <= rx_data;
                        3'd4: header_height <= rx_data;
                        3'd5: header_length[7:0] <= rx_data;
                        default: begin
                            header_length[15:8] <= rx_data;
                            // In full-width scroll mode the width field is the
                            // rendered text width.  Static subtitles and older
                            // senders keep the original fixed 800-pixel value.
                            header_good <= (header_version == PROTOCOL_VERSION) &&
                                           ((FULL_WIDTH_SCROLL && header_mode[0]) ?
                                            ((header_width >= 16'd1) &&
                                             (header_width <= EXPECTED_WIDTH)) :
                                            (header_width == EXPECTED_WIDTH)) &&
                                           (header_height == EXPECTED_HEIGHT) &&
                                           (header_length[7:0] == EXPECTED_LENGTH[7:0]) &&
                                           (rx_data == EXPECTED_LENGTH[15:8]);
                            payload_count <= 14'd0;
                            parser_state <= P_PAYLOAD;
                        end
                    endcase
                    if (header_count != 3'd6)
                        header_count <= header_count + 1'b1;
                end
                P_PAYLOAD: begin
                    crc_work <= crc16_next(crc_work, rx_data);
                    if (header_good && !commit_pending) begin
                        write_enable <= 1'b1;
                        write_addr <= payload_count[RAM_ADDR_WIDTH-1:0];
                        write_data <= rx_data;
                    end
                    if (payload_count == BITMAP_BYTES - 1)
                        parser_state <= P_CRC0;
                    else
                        payload_count <= payload_count + 1'b1;
                end
                P_CRC0: begin
                    crc_low <= rx_data;
                    parser_state <= P_CRC1;
                end
                default: begin
                    parser_state <= P_SYNC0;
                    if (!header_good)
                        response_pending <= R_FMT;
                    else if (commit_pending)
                        response_pending <= R_BUSY;
                    else if ({rx_data, crc_low} != crc_work)
                        response_pending <= R_CRC;
                    else begin
                        commit_mode <= header_mode;
                        commit_width <= header_width;
                        commit_pending <= 1'b1;
                        commit_toggle <= ~commit_toggle;
                        response_pending <= R_OK;
                    end
                end
            endcase
        end else if (parser_state != P_SYNC0) begin
            if (idle_count == 25_000_000 - 1'b1) begin
                parser_state <= P_SYNC0;
                response_pending <= R_TIMEOUT;
                idle_count <= 25'd0;
            end else
                idle_count <= idle_count + 1'b1;
        end
    end
end

reg commit_sync1, commit_sync2, commit_seen;
reg active_bank;
reg subtitle_valid;
reg scroll_enable;
reg [2:0] scroll_step;
reg [10:0] scroll_width;
reg [11:0] scroll_offset;
reg [11:0] next_scroll_offset;
reg [11:0] scroll_position;
reg [10:0] mapped_x;
reg mapped_valid;
reg [10:0] static_mapped_x;
reg static_mapped_valid;
reg [10:0] full_scroll_mapped_x;
reg full_scroll_mapped_valid;
reg mapped_valid_q;
reg [9:0] subtitle_row;
reg [RAM_ADDR_WIDTH-1:0] read_addr;
reg [7:0] read_byte;
reg [23:0] rgb_q;
reg [10:0] x_q;
reg [9:0] y_q;
reg [2:0] pixel_index_q;
reg [1:0] pixel_alpha;
reg [23:0] subtitle_rgb;
// EG_LOGIC_BRAM's NOREG port still has its synchronous array-read cycle.
// Its output therefore matches pixel_index_q directly.  Do not add a second
// fabric register here: that was the source of the four-pixel glyph tearing.
wire [7:0] active_bitmap_q = active_bank ? bitmap1_q : bitmap0_q;
wire [7:0] pixel_byte = active_bitmap_q;

// The 4K depth is intentional: EG_LOGIC_BRAM needs a power-of-two address
// range.  Only bytes 0..3199 are written/read for the fixed 800x32 bitmap.
subtitle_bitmap_ram #(
    .ADDR_WIDTH(RAM_ADDR_WIDTH), .DEPTH(1 << RAM_ADDR_WIDTH),
    .REGISTER_READ(BRAM_REGISTER_READ)
) u_bitmap0 (
    .wr_clk(clk_50m), .wr_en(write_enable && !write_bank),
    .wr_addr(write_addr), .wr_data(write_data),
    .rd_clk(video_clk), .rd_addr(read_addr), .rd_data(bitmap0_q)
);
subtitle_bitmap_ram #(
    .ADDR_WIDTH(RAM_ADDR_WIDTH), .DEPTH(1 << RAM_ADDR_WIDTH),
    .REGISTER_READ(BRAM_REGISTER_READ)
) u_bitmap1 (
    .wr_clk(clk_50m), .wr_en(write_enable && write_bank),
    .wr_addr(write_addr), .wr_data(write_data),
    .rd_clk(video_clk), .rd_addr(read_addr), .rd_data(bitmap1_q)
);

always @(*) begin
    next_scroll_offset = scroll_offset + {9'd0, scroll_step};
    if (FULL_WIDTH_SCROLL) begin
        // Keep two copies of the text one display-width apart.  The second
        // copy enters at the right edge as the first leaves the left edge.
        if (next_scroll_offset >= 2 * DISPLAY_WIDTH)
            next_scroll_offset = next_scroll_offset - (2 * DISPLAY_WIDTH);
    end else if (next_scroll_offset >= WIDTH)
        next_scroll_offset = next_scroll_offset - WIDTH;

    scroll_position = {1'b0, x_i} + scroll_offset;
    if (FULL_WIDTH_SCROLL) begin
        // Keep the static and scrolling address calculations independent.
        // Selecting between their finished results keeps scroll_enable off
        // the BRAM address adder chain at the 75 MHz video clock.
        static_mapped_valid = (x_i >= X_START) && (x_i < X_START + WIDTH);
        static_mapped_x = static_mapped_valid ? {1'b0, x_i - X_START} : 11'd0;
        full_scroll_mapped_valid = (x_i < DISPLAY_WIDTH) &&
                                   (((scroll_position >= DISPLAY_WIDTH) &&
                                     (scroll_position < DISPLAY_WIDTH + scroll_width)) ||
                                    ((scroll_position >= 2 * DISPLAY_WIDTH) &&
                                     (scroll_position < 2 * DISPLAY_WIDTH + scroll_width)));
        if ((scroll_position >= DISPLAY_WIDTH) &&
            (scroll_position < DISPLAY_WIDTH + scroll_width))
            full_scroll_mapped_x = scroll_position - DISPLAY_WIDTH;
        else if ((scroll_position >= 2 * DISPLAY_WIDTH) &&
                 (scroll_position < 2 * DISPLAY_WIDTH + scroll_width))
            full_scroll_mapped_x = scroll_position - (2 * DISPLAY_WIDTH);
        else
            full_scroll_mapped_x = 11'd0;
        mapped_valid = scroll_enable ? full_scroll_mapped_valid : static_mapped_valid;
        mapped_x = scroll_enable ? full_scroll_mapped_x : static_mapped_x;
    end else begin
        mapped_valid = (x_i >= X_START) && (x_i < X_START + WIDTH);
        mapped_x = mapped_valid ? ({1'b0, x_i - X_START} +
                   (scroll_enable ? scroll_offset[10:0] : 11'd0)) : 11'd0;
        if (mapped_x >= WIDTH)
            mapped_x = mapped_x - WIDTH;
    end
    subtitle_row = y_i - Y_START;
    if (RESOURCE_OPT_ADDR && ((WIDTH / PIXELS_PER_BYTE) == 100))
        read_addr = (subtitle_row << 6) + (subtitle_row << 5) +
                    (subtitle_row << 2) + mapped_x[9:3];
    else if (RESOURCE_OPT_ADDR && ((WIDTH / PIXELS_PER_BYTE) == 200))
        read_addr = (subtitle_row << 7) + (subtitle_row << 6) +
                    (subtitle_row << 3) + mapped_x[9:2];
    else
        read_addr = (subtitle_row * (WIDTH / PIXELS_PER_BYTE)) +
                    ((BITS_PER_PIXEL == 1) ? mapped_x[9:3] : mapped_x[9:2]);
    if (BITS_PER_PIXEL == 1)
        pixel_alpha = pixel_byte[7 - pixel_index_q] ? 2'd3 : 2'd0;
    else begin
        case (pixel_index_q[1:0])
            2'd0: pixel_alpha = pixel_byte[7:6];
            2'd1: pixel_alpha = pixel_byte[5:4];
            2'd2: pixel_alpha = pixel_byte[3:2];
            default: pixel_alpha = pixel_byte[1:0];
        endcase
    end
    case (pixel_alpha)
        2'd0: subtitle_rgb = 24'h101820;
        2'd1: subtitle_rgb = 24'h58636a;
        2'd2: subtitle_rgb = 24'ha0afb5;
        default: subtitle_rgb = 24'hdffcff;
    endcase
end

always @(posedge video_clk or negedge video_rst_n) begin
    if (!video_rst_n) begin
        commit_sync1 <= 1'b0;
        commit_sync2 <= 1'b0;
        commit_seen <= 1'b0;
        active_bank <= 1'b0;
        subtitle_valid <= 1'b0;
        scroll_enable <= 1'b0;
        scroll_step <= 3'd1;
        scroll_width <= WIDTH;
        scroll_offset <= 12'd0;
        ack_toggle <= 1'b0;
        hs_o <= 1'b1;
        vs_o <= 1'b1;
        de_o <= 1'b0;
        rgb_o <= 24'h000000;
        rgb_q <= 24'h000000;
        x_q <= 11'd0;
        y_q <= 10'd0;
        pixel_index_q <= 3'd0;
        mapped_valid_q <= 1'b0;
        read_byte <= 8'd0;
    end else begin
        commit_sync1 <= commit_toggle;
        commit_sync2 <= commit_sync1;
        if (video_frame_tick) begin
            if (commit_sync2 != commit_seen) begin
                commit_seen <= commit_sync2;
                active_bank <= ~active_bank;
                subtitle_valid <= !commit_mode[7];
                scroll_enable <= !commit_mode[7] && commit_mode[0];
                scroll_step <= (commit_mode[3:1] == 3'd0) ? 3'd1 : commit_mode[3:1];
                scroll_width <= (FULL_WIDTH_SCROLL && commit_mode[0]) ?
                                commit_width[10:0] : WIDTH;
                scroll_offset <= 12'd0;
                ack_toggle <= ~ack_toggle;
            end else if (subtitle_valid && scroll_enable)
                scroll_offset <= next_scroll_offset;
        end

        hs_o <= hs_i;
        vs_o <= vs_i;
        de_o <= de_i;
        rgb_q <= rgb_i;
        x_q <= x_i;
        y_q <= y_i;
        pixel_index_q <= (BITS_PER_PIXEL == 1) ? {1'b0, mapped_x[2:0]} :
                                                    {1'b0, mapped_x[1:0]};
        mapped_valid_q <= mapped_valid;
        read_byte <= 8'd0;

        if (de_o && subtitle_valid && y_q >= Y_START && y_q < Y_START + HEIGHT) begin
            if (mapped_valid_q)
                rgb_o <= subtitle_rgb;
            else
                rgb_o <= 24'h101820;
        end
        else
            rgb_o <= rgb_q;
    end
end

endmodule

module subtitle_bitmap_ram #(
    parameter integer ADDR_WIDTH = 12,
    parameter integer DEPTH = 4096,
    parameter integer REGISTER_READ = 0
) (
    input wire wr_clk, input wire wr_en, input wire [ADDR_WIDTH-1:0] wr_addr,
    input wire [7:0] wr_data, input wire rd_clk, input wire [ADDR_WIDTH-1:0] rd_addr,
    output wire [7:0] rd_data
);
`ifdef SIM
    reg [7:0] memory [0:DEPTH-1];
    reg [7:0] rd_array_q;
    reg [7:0] rd_data_q;
    always @(posedge wr_clk) if (wr_en) memory[wr_addr] <= wr_data;
    // Matches the vendor EG_LOGIC_BRAM model: the array read is synchronous
    // even with REGMODE_B="NOREG"; OUTREG adds a second output register.
    always @(posedge rd_clk) begin
        rd_array_q <= memory[rd_addr];
        if (REGISTER_READ)
            rd_data_q <= rd_array_q;
    end
    assign rd_data = REGISTER_READ ? rd_data_q : rd_array_q;
`else
    wire [7:0] unused_a;
    EG_LOGIC_BRAM #(
        .DATA_WIDTH_A(8), .DATA_WIDTH_B(8),
        .ADDR_WIDTH_A(ADDR_WIDTH), .ADDR_WIDTH_B(ADDR_WIDTH),
        .DATA_DEPTH_A(DEPTH), .DATA_DEPTH_B(DEPTH),
        .BYTE_ENABLE(0), .BYTE_A(1), .BYTE_B(1), .MODE("DP"),
        .REGMODE_A("NOREG"), .REGMODE_B(REGISTER_READ ? "OUTREG" : "NOREG"),
        .WRITEMODE_A("NORMAL"), .WRITEMODE_B("NORMAL"),
        .RESETMODE("SYNC"), .DEBUGGABLE("NO"), .PACKABLE("NO"),
        .FORCE_KEEP("OFF"), .INIT_FILE("NONE"), .FILL_ALL("NONE"),
        // One 4Kx8 subtitle bank fits a single 32K block, preserving the
        // scarce 9K blocks for later streaming/audio FIFOs.
        .IMPLEMENT("32K")
    ) u_ram (
        .doa(unused_a), .dob(rd_data), .dia(wr_data), .dib(8'd0),
        .cea(wr_en), .ocea(1'b0), .clka(wr_clk), .wea(wr_en), .rsta(1'b0),
        .ceb(1'b1), .oceb(1'b1), .clkb(rd_clk), .web(1'b0), .rstb(1'b0),
        .bea(1'b1), .beb(1'b1), .addra(wr_addr), .addrb(rd_addr)
    );
`endif
endmodule

module uart_subtitle_rx #(
    parameter integer BAUD_DIV = 434
) (
    input wire clk, input wire rst_n, input wire rxd,
    output reg [7:0] data, output reg valid
);
localparam [1:0] RX_IDLE = 2'd0, RX_START = 2'd1, RX_DATA = 2'd2, RX_STOP = 2'd3;
reg [1:0] state;
reg rxd_meta, rxd_sync, rxd_prev;
reg [12:0] count;
reg [2:0] bit_count;
reg [7:0] shift;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= RX_IDLE; rxd_meta <= 1'b1; rxd_sync <= 1'b1; rxd_prev <= 1'b1;
        count <= 13'd0; bit_count <= 3'd0; shift <= 8'd0; data <= 8'd0; valid <= 1'b0;
    end else begin
        rxd_meta <= rxd; rxd_sync <= rxd_meta; rxd_prev <= rxd_sync; valid <= 1'b0;
        case (state)
            RX_IDLE: if (rxd_prev && !rxd_sync) begin state <= RX_START; count <= 13'd0; end
            RX_START: if (count == (BAUD_DIV / 2) - 1) begin
                count <= 13'd0;
                if (!rxd_sync) begin state <= RX_DATA; bit_count <= 3'd0; end
                else state <= RX_IDLE;
            end else count <= count + 1'b1;
            RX_DATA: if (count == BAUD_DIV - 1) begin
                count <= 13'd0; shift[bit_count] <= rxd_sync;
                if (bit_count == 3'd7) state <= RX_STOP;
                else bit_count <= bit_count + 1'b1;
            end else count <= count + 1'b1;
            default: if (count == BAUD_DIV - 1) begin
                count <= 13'd0; state <= RX_IDLE;
                if (rxd_sync) begin data <= shift; valid <= 1'b1; end
            end else count <= count + 1'b1;
        endcase
    end
end
endmodule

module uart_subtitle_tx #(
    parameter integer BAUD_DIV = 434
) (
    input wire clk, input wire rst_n, input wire [7:0] data, input wire valid,
    output wire ready, output reg txd
);
reg busy;
reg [12:0] count;
reg [3:0] bit_count;
reg [7:0] data_q;
assign ready = !busy;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin busy <= 1'b0; count <= 13'd0; bit_count <= 4'd0; data_q <= 8'd0; txd <= 1'b1; end
    else if (!busy) begin
        txd <= 1'b1;
        if (valid) begin busy <= 1'b1; data_q <= data; count <= 13'd0; bit_count <= 4'd0; txd <= 1'b0; end
    end else if (count == BAUD_DIV - 1) begin
        count <= 13'd0;
        if (bit_count < 4'd8) begin txd <= data_q[bit_count]; bit_count <= bit_count + 1'b1; end
        else if (bit_count == 4'd8) begin txd <= 1'b1; bit_count <= 4'd9; end
        else begin busy <= 1'b0; txd <= 1'b1; end
    end else count <= count + 1'b1;
end
endmodule

`default_nettype wire
