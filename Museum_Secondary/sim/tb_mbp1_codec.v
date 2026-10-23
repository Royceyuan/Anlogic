`timescale 1ns / 1ps

module tb_mbp1_codec;
reg clk = 0;
always #5 clk = ~clk;
reg rst = 1;
reg [7:0] rx_data = 0;
reg rx_valid = 0;
reg [15:0] rx_length = 0;
wire packet_valid;
wire [7:0] packet_type, packet_flags;
wire [15:0] packet_payload_length, crc_error_count, drop_count;
wire [31:0] packet_seq, packet_boot_id, packet_uptime_ms;
wire [63:0] packet_payload;
wire [127:0] packet_payload_full;
wire packet_valid_full;
reg send = 0;
wire send_ready;
reg [7:0] send_type = 8'h04, send_flags = 8'h02;
reg [4:0] send_payload_length = 5'd8;
reg [31:0] send_seq = 32'h11223344;
reg [31:0] send_boot_id = 32'h55667788;
reg [31:0] send_uptime_ms = 32'h99aabbcc;
reg [127:0] send_payload = 128'h01020304050607080000000000000000;
wire tx_request, tx_valid;
wire [7:0] tx_data;
wire [15:0] tx_length;
reg tx_ack = 0;
reg tx_ready = 1;
reg [7:0] wire_bytes [0:278];
integer tx_seen = 0;
integer valid_seen = 0;
integer i;
reg [15:0] check_crc;

mbp1_codec dut (
    .clk(clk), .rst(rst), .rx_data(rx_data), .rx_valid(rx_valid),
    .rx_length(rx_length), .packet_valid(packet_valid),
    .packet_type(packet_type), .packet_flags(packet_flags),
    .packet_payload_length(packet_payload_length), .packet_seq(packet_seq),
    .packet_boot_id(packet_boot_id), .packet_uptime_ms(packet_uptime_ms),
    .packet_payload(packet_payload), .crc_error_count(crc_error_count),
    .drop_count(drop_count), .send(send), .send_ready(send_ready),
    .send_type(send_type), .send_flags(send_flags),
    .send_payload_length(send_payload_length), .send_seq(send_seq),
    .send_boot_id(send_boot_id), .send_uptime_ms(send_uptime_ms),
    .send_payload(send_payload), .tx_ready(tx_ready), .tx_ack(tx_ack),
    .tx_request(tx_request), .tx_data(tx_data), .tx_valid(tx_valid),
    .tx_length(tx_length)
);

mbp1_codec #(.RX_PAYLOAD_BYTES(16)) dut_full (
    .clk(clk), .rst(rst), .rx_data(rx_data), .rx_valid(rx_valid),
    .rx_length(rx_length), .packet_valid(packet_valid_full),
    .packet_type(), .packet_flags(), .packet_payload_length(),
    .packet_seq(), .packet_boot_id(), .packet_uptime_ms(),
    .packet_payload(packet_payload_full), .crc_error_count(), .drop_count(),
    .send(1'b0), .send_ready(), .send_type(8'd0), .send_flags(8'd0),
    .send_payload_length(5'd0), .send_seq(32'd0), .send_boot_id(32'd0),
    .send_uptime_ms(32'd0), .send_payload(128'd0),
    .tx_ready(1'b0), .tx_ack(1'b0), .tx_request(), .tx_data(),
    .tx_valid(), .tx_length()
);

function [15:0] crc_byte;
    input [15:0] prior;
    input [7:0] value;
    reg [15:0] c;
    integer b;
    begin
        c = prior ^ {value, 8'd0};
        for (b = 0; b < 8; b = b + 1)
            c = c[15] ? ((c << 1) ^ 16'h1021) : (c << 1);
        crc_byte = c;
    end
endfunction

always @(negedge clk) begin
    tx_ack = tx_request;
    if (tx_request) tx_ready = 0;
end
always @(posedge clk) begin
    if (tx_valid) begin
        wire_bytes[tx_seen] <= tx_data;
        tx_seen <= tx_seen + 1;
    end
    if (packet_valid) valid_seen <= valid_seen + 1;
end

task inject_captured;
    input integer count;
    integer n;
    begin
        @(negedge clk);
        rx_length = count;
        for (n = 0; n < count; n = n + 1) begin
            rx_data = wire_bytes[n];
            rx_valid = 1;
            @(negedge clk);
        end
        rx_valid = 0;
        repeat (3) @(negedge clk);
    end
endtask

initial begin
    repeat (3) @(negedge clk);
    rst = 0;
    send = 1;
    @(negedge clk);
    send = 0;
    wait (tx_seen == 30);
    repeat (2) @(negedge clk);
    if (tx_length !== 16'd30) $fatal(1, "TX length");
    check_crc = 16'hffff;
    for (i = 0; i < 28; i = i + 1)
        check_crc = crc_byte(check_crc, wire_bytes[i]);
    if ({wire_bytes[28], wire_bytes[29]} !== check_crc)
        $fatal(1, "TX CRC mismatch %04x", check_crc);
    inject_captured(30);
    if (valid_seen != 1 || packet_type !== 8'h04 ||
        packet_flags !== 8'h02 || packet_payload_length !== 16'd8 ||
        packet_seq !== 32'h11223344 ||
        packet_boot_id !== 32'h55667788 ||
        packet_payload !== 64'h0102030405060708)
        $fatal(1, "RX valid packet decode failed");

    wire_bytes[29] = wire_bytes[29] ^ 8'h01;
    inject_captured(30);
    if (valid_seen != 1 || crc_error_count !== 16'd1)
        $fatal(1, "bad CRC not rejected");
    wire_bytes[29] = wire_bytes[29] ^ 8'h01;
    wire_bytes[5] = 8'h15;
    inject_captured(30);
    if (valid_seen != 1 || drop_count !== 16'd1)
        $fatal(1, "bad header not rejected");
    wire_bytes[5] = 8'h14;
    inject_captured(29);
    if (valid_seen != 1 || drop_count !== 16'd2)
        $fatal(1, "truncated packet not rejected");

    wire_bytes[3] = 8'h31;
    wire_bytes[6] = 8'h01;
    wire_bytes[7] = 8'h00;
    for (i = 20; i < 276; i = i + 1)
        wire_bytes[i] = i;
    check_crc = 16'hffff;
    for (i = 0; i < 276; i = i + 1)
        check_crc = crc_byte(check_crc, wire_bytes[i]);
    wire_bytes[276] = check_crc[15:8];
    wire_bytes[277] = check_crc[7:0];
    inject_captured(278);
    if (valid_seen != 2 || packet_payload_length !== 16'd256 ||
        packet_payload_full !== 128'h1415161718191a1b1c1d1e1f20212223)
        $fatal(1, "maximum 256-byte payload rejected");
    wire_bytes[7] = 8'h01;
    wire_bytes[276] = 8'haa;
    check_crc = 16'hffff;
    for (i = 0; i < 277; i = i + 1)
        check_crc = crc_byte(check_crc, wire_bytes[i]);
    wire_bytes[277] = check_crc[15:8];
    wire_bytes[278] = check_crc[7:0];
    inject_captured(279);
    if (valid_seen != 2 || drop_count !== 16'd3)
        $fatal(1, "oversized 257-byte payload accepted");

    check_crc = 16'hffff;
    for (i = 0; i < 9; i = i + 1)
        check_crc = crc_byte(check_crc, 8'h31 + i);
    if (check_crc !== 16'h29b1) $fatal(1, "CRC standard vector");
    $display("PASS: MBP1 codec CRC, encode/decode and bad packet rejection");
    $finish;
end
initial begin
    #100000;
    $fatal(1, "timeout");
end
endmodule
