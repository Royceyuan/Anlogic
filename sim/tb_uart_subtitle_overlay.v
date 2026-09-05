`timescale 1ns / 1ps
`default_nettype none

module tb_uart_subtitle_overlay #(
    parameter integer BPP = 1,
    parameter integer BRAM_READ_REG = 0,
    parameter integer X_START = 0,
    parameter integer RESOURCE_OPT_ADDR = 0,
    parameter integer DISPLAY_WIDTH = 800,
    parameter integer FULL_WIDTH_SCROLL = 0
);
    reg clk_50m = 1'b0, video_clk = 1'b0;
    reg rst_n_50m = 1'b0, video_rst_n = 1'b0, uart_rxd = 1'b1;
    reg video_frame_tick = 1'b0, hs_i = 1'b1, vs_i = 1'b1, de_i = 1'b0;
    reg [10:0] x_i = 11'd0;
    reg [9:0] y_i = 10'd0;
    reg [23:0] rgb_i = 24'h123456;
    wire uart_txd, hs_o, vs_o, de_o;
    wire [23:0] rgb_o;
    integer failures = 0;

    always #10 clk_50m = ~clk_50m;
    always #12 video_clk = ~video_clk;

    uart_subtitle_overlay #(
        .UART_DIV(4), .BITS_PER_PIXEL(BPP), .PROTOCOL_VERSION(BPP),
        .X_START(X_START),
        .DISPLAY_WIDTH(DISPLAY_WIDTH),
        .FULL_WIDTH_SCROLL(FULL_WIDTH_SCROLL),
        .BRAM_REGISTER_READ(BRAM_READ_REG),
        .RESOURCE_OPT_ADDR(RESOURCE_OPT_ADDR),
        .BITMAP_BYTES(3200 * BPP)
    ) dut (
        .clk_50m(clk_50m), .rst_n_50m(rst_n_50m), .uart_rxd(uart_rxd), .uart_txd(uart_txd),
        .video_clk(video_clk), .video_rst_n(video_rst_n), .video_frame_tick(video_frame_tick),
        .hs_i(hs_i), .vs_i(vs_i), .de_i(de_i), .x_i(x_i), .y_i(y_i), .rgb_i(rgb_i),
        .hs_o(hs_o), .vs_o(vs_o), .de_o(de_o), .rgb_o(rgb_o)
    );

    function [15:0] crc16_next;
        input [15:0] crc_in;
        input [7:0] data_in;
        integer k;
        reg [15:0] c;
        begin
            c = crc_in ^ {data_in, 8'h00};
            for (k = 0; k < 8; k = k + 1)
                c = c[15] ? ((c << 1) ^ 16'h1021) : (c << 1);
            crc16_next = c;
        end
    endfunction

    function [7:0] payload_byte;
        input integer index;
        input scroll_packet;
        begin
            if (index == 0) begin
                if (BPP == 1)
                    payload_byte = scroll_packet ? 8'h40 : 8'h80;
                else
                    payload_byte = scroll_packet ? 8'h30 : 8'hc0;
            end
            else if (index == 1 && BPP == 2)
                payload_byte = 8'h6c; // pixels 4..7 = alpha 1,2,3,0
            else
                payload_byte = 8'h00;
        end
    endfunction

    task send_byte;
        input [7:0] value;
        integer b;
        begin
            uart_rxd = 1'b0; repeat (4) @(posedge clk_50m);
            for (b = 0; b < 8; b = b + 1) begin
                uart_rxd = value[b]; repeat (4) @(posedge clk_50m);
            end
            uart_rxd = 1'b1; repeat (4) @(posedge clk_50m);
        end
    endtask

    task send_packet;
        input scroll_packet;
        input corrupt_crc;
        integer i;
        reg [15:0] crc;
        reg [7:0] value;
        begin
            crc = 16'hffff;
            send_byte(8'h55); send_byte(8'haa);
            value = BPP; crc = crc16_next(crc, value); send_byte(value);
            value = scroll_packet ? 8'h03 : 8'h00; crc = crc16_next(crc, value); send_byte(value);
            value = 8'h20; crc = crc16_next(crc, value); send_byte(value);
            value = 8'h03; crc = crc16_next(crc, value); send_byte(value);
            value = 8'h20; crc = crc16_next(crc, value); send_byte(value);
            value = (3200 * BPP) & 8'hff; crc = crc16_next(crc, value); send_byte(value);
            value = (3200 * BPP) >> 8; crc = crc16_next(crc, value); send_byte(value);
            for (i = 0; i < 3200 * BPP; i = i + 1) begin
                value = payload_byte(i, scroll_packet);
                crc = crc16_next(crc, value);
                send_byte(value);
            end
            if (corrupt_crc) crc = crc ^ 16'h0001;
            send_byte(crc[7:0]); send_byte(crc[15:8]);
        end
    endtask

    task send_clear_packet;
        integer i;
        reg [15:0] crc;
        reg [7:0] value;
        begin
            crc = 16'hffff;
            send_byte(8'h55); send_byte(8'haa);
            value = BPP; crc = crc16_next(crc, value); send_byte(value);
            value = 8'h80; crc = crc16_next(crc, value); send_byte(value);
            value = 8'h20; crc = crc16_next(crc, value); send_byte(value);
            value = 8'h03; crc = crc16_next(crc, value); send_byte(value);
            value = 8'h20; crc = crc16_next(crc, value); send_byte(value);
            value = (3200 * BPP) & 8'hff; crc = crc16_next(crc, value); send_byte(value);
            value = (3200 * BPP) >> 8; crc = crc16_next(crc, value); send_byte(value);
            for (i = 0; i < 3200 * BPP; i = i + 1) begin
                value = 8'h00; crc = crc16_next(crc, value); send_byte(value);
            end
            send_byte(crc[7:0]); send_byte(crc[15:8]);
        end
    endtask

    task expect_tx_byte;
        input [7:0] expected;
        integer b;
        reg [7:0] received;
        begin
            @(negedge uart_txd);
            repeat (6) @(posedge clk_50m);
            for (b = 0; b < 8; b = b + 1) begin
                received[b] = uart_txd;
                repeat (4) @(posedge clk_50m);
            end
            if (received !== expected) begin
                $display("FAIL UART reply got=%h expected=%h", received, expected);
                failures = failures + 1;
            end
        end
    endtask

    task frame_tick;
        begin
            @(negedge video_clk); video_frame_tick = 1'b1;
            @(negedge video_clk); video_frame_tick = 1'b0;
        end
    endtask

    task sample_pixel;
        input [10:0] sample_x;
        input [9:0] sample_y;
        input [23:0] expected;
        begin
            @(negedge video_clk);
            de_i = 1'b1; x_i = sample_x; y_i = sample_y; rgb_i = 24'h123456;
            @(posedge video_clk); @(posedge video_clk); #1;
            if (rgb_o !== expected) begin
                $display("FAIL pixel x=%0d y=%0d got=%h expected=%h", sample_x, sample_y, rgb_o, expected);
                failures = failures + 1;
            end
            @(negedge video_clk); de_i = 1'b0;
        end
    endtask

    task check_cross_byte_pixels;
        integer x;
        reg [23:0] expected;
        begin
            for (x = 0; x < 9; x = x + 1) begin
                @(negedge video_clk);
                de_i = 1'b1; x_i = X_START + x; y_i = 10'd568; rgb_i = 24'h123456;
                @(posedge video_clk); #1;
                if (x > 0) begin
                    case (x - 1)
                        0: expected = 24'hdffcff;
                        4: expected = 24'h58636a;
                        5: expected = 24'ha0afb5;
                        6: expected = 24'hdffcff;
                        default: expected = 24'h101820;
                    endcase
                    if (rgb_o !== expected) begin
                        $display("FAIL cross-byte pixel x=%0d got=%h expected=%h", x - 1, rgb_o, expected);
                        failures = failures + 1;
                    end
                end
            end
            @(negedge video_clk); de_i = 1'b0;
        end
    endtask

    initial begin
        repeat (5) @(posedge clk_50m);
        rst_n_50m = 1'b1; video_rst_n = 1'b1;

        // No accepted packet: the image remains untouched.
        $display("TEST no packet");
        sample_pixel(11'd0, 10'd568, 24'h123456);
        $display("TEST static packet");
        send_packet(1'b0, 1'b0);
        expect_tx_byte("O"); expect_tx_byte("K");
        expect_tx_byte(8'h0d); expect_tx_byte(8'h0a);
        repeat (6) @(posedge video_clk);
        if (dut.subtitle_valid) begin $display("FAIL subtitle committed before frame edge"); failures = failures + 1; end
        frame_tick;
        sample_pixel(X_START, 10'd568, 24'hdffcff);
        sample_pixel(X_START + 1, 10'd568, 24'h101820);
        if (X_START != 0)
            sample_pixel(11'd0, 10'd568, 24'h101820);
        if (BPP == 2) begin
            $display("TEST cross-byte pixels");
            check_cross_byte_pixels;
        end

        // A bad CRC leaves the currently visible bank alone.
        $display("TEST CRC reject");
        send_packet(1'b0, 1'b1);
        repeat (6) @(posedge video_clk); frame_tick;
        sample_pixel(X_START, 10'd568, 24'hdffcff);

        // New scroll bank is atomic. The 720p resource-optimized mode moves
        // the existing 800-pixel bitmap across the complete display width.
        $display("TEST scroll packet");
        send_packet(1'b1, 1'b0);
        repeat (6) @(posedge video_clk); frame_tick;
        if (FULL_WIDTH_SCROLL) begin
            sample_pixel(DISPLAY_WIDTH - 1, 10'd568, 24'h101820);
            frame_tick;
            sample_pixel(DISPLAY_WIDTH - 1, 10'd568, 24'h101820);
            frame_tick;
            sample_pixel(DISPLAY_WIDTH - 1, 10'd568, 24'hdffcff);
            repeat (DISPLAY_WIDTH - 2) frame_tick;
            sample_pixel(11'd1, 10'd568, 24'hdffcff);
        end else begin
            sample_pixel(X_START + 1, 10'd568, 24'hdffcff);
            frame_tick;
            sample_pixel(X_START, 10'd568, 24'hdffcff);
        end

        $display("TEST clear packet");
        send_clear_packet;
        expect_tx_byte("O"); expect_tx_byte("K");
        expect_tx_byte(8'h0d); expect_tx_byte(8'h0a);
        repeat (6) @(posedge video_clk); frame_tick;
        sample_pixel(X_START, 10'd568, 24'h123456);

        if (failures == 0) $display("PASS uart_subtitle_overlay");
        else $display("FAIL uart_subtitle_overlay failures=%0d", failures);
        $finish;
    end
endmodule

`default_nettype wire
