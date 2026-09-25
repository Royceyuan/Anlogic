`timescale 1ns / 1ps
`default_nettype none

// MBP1 byte-stream codec. One UDP datagram is one contiguous rx_valid burst.
// Payloads larger than 16 bytes are validated but only the first 16 bytes
// are exposed; the main-board command set never consumes more than 12.
module mbp1_codec (
    input  wire         clk,
    input  wire         rst,
    input  wire [7:0]   rx_data,
    input  wire         rx_valid,
    input  wire [15:0]  rx_length,
    output reg          packet_valid,
    output reg  [7:0]   packet_type,
    output reg  [7:0]   packet_flags,
    output reg  [15:0]  packet_payload_length,
    output reg  [31:0]  packet_seq,
    output reg  [31:0]  packet_boot_id,
    output reg  [31:0]  packet_uptime_ms,
    output reg  [63:0]  packet_payload,
    output reg  [15:0]  crc_error_count,
    output reg  [15:0]  drop_count,
    input  wire         send,
    output wire         send_ready,
    input  wire [7:0]   send_type,
    input  wire [7:0]   send_flags,
    input  wire [4:0]   send_payload_length,
    input  wire [31:0]  send_seq,
    input  wire [31:0]  send_boot_id,
    input  wire [31:0]  send_uptime_ms,
    input  wire [127:0] send_payload,
    input  wire         tx_ready,
    input  wire         tx_ack,
    output reg          tx_request,
    output reg  [7:0]   tx_data,
    output reg          tx_valid,
    output reg  [15:0]  tx_length
);

function [15:0] crc_byte;
    input [15:0] prior;
    input [7:0] value;
    reg [15:0] c;
    integer bit_index;
    begin
        c = prior ^ {value, 8'h00};
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
            c = c[15] ? ((c << 1) ^ 16'h1021) : (c << 1);
        crc_byte = c;
    end
endfunction

reg rx_valid_d;
reg [15:0] rx_count, rx_expected_length;
reg [15:0] rx_crc, rx_crc_wire;
reg rx_header_ok;
wire [15:0] rx_index = rx_valid_d ? rx_count : 16'd0;
wire [15:0] rx_crc_base = rx_valid_d ? rx_crc : 16'hffff;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        rx_valid_d <= 1'b0;
        rx_count <= 16'd0;
        rx_expected_length <= 16'd0;
        rx_crc <= 16'hffff;
        rx_crc_wire <= 16'd0;
        rx_header_ok <= 1'b0;
        packet_valid <= 1'b0;
        packet_type <= 8'd0;
        packet_flags <= 8'd0;
        packet_payload_length <= 16'd0;
        packet_seq <= 32'd0;
        packet_boot_id <= 32'd0;
        packet_uptime_ms <= 32'd0;
        packet_payload <= 64'd0;
        crc_error_count <= 16'd0;
        drop_count <= 16'd0;
    end else begin
        rx_valid_d <= rx_valid;
        packet_valid <= 1'b0;
        if (rx_valid) begin
            if (!rx_valid_d) begin
                rx_expected_length <= rx_length;
                rx_header_ok <= (rx_data == 8'h4d);
                packet_payload <= 64'd0;
                packet_seq <= 32'd0;
                packet_boot_id <= 32'd0;
                packet_uptime_ms <= 32'd0;
                packet_payload_length <= 16'd0;
                rx_crc_wire <= 16'd0;
            end
            if (rx_index != 16'hffff)
                rx_count <= rx_index + 16'd1;
            if (rx_index < rx_length - 16'd2 && rx_length >= 16'd22)
                rx_crc <= crc_byte(rx_crc_base, rx_data);
            if (rx_index == rx_length - 16'd2 && rx_length >= 16'd22)
                rx_crc_wire[15:8] <= rx_data;
            if (rx_index == rx_length - 16'd1 && rx_length >= 16'd22)
                rx_crc_wire[7:0] <= rx_data;
            case (rx_index)
                16'd1:  if (rx_data != 8'h42) rx_header_ok <= 1'b0;
                16'd2:  if (rx_data != 8'h01) rx_header_ok <= 1'b0;
                16'd3:  packet_type <= rx_data;
                16'd4:  begin
                    packet_flags <= rx_data;
                    if (rx_data[7:3] != 5'd0) rx_header_ok <= 1'b0;
                end
                16'd5:  if (rx_data != 8'h14) rx_header_ok <= 1'b0;
                16'd6:  packet_payload_length[15:8] <= rx_data;
                16'd7:  packet_payload_length[7:0] <= rx_data;
                16'd8:  packet_seq[31:24] <= rx_data;
                16'd9:  packet_seq[23:16] <= rx_data;
                16'd10: packet_seq[15:8] <= rx_data;
                16'd11: packet_seq[7:0] <= rx_data;
                16'd12: packet_boot_id[31:24] <= rx_data;
                16'd13: packet_boot_id[23:16] <= rx_data;
                16'd14: packet_boot_id[15:8] <= rx_data;
                16'd15: packet_boot_id[7:0] <= rx_data;
                16'd16: packet_uptime_ms[31:24] <= rx_data;
                16'd17: packet_uptime_ms[23:16] <= rx_data;
                16'd18: packet_uptime_ms[15:8] <= rx_data;
                16'd19: packet_uptime_ms[7:0] <= rx_data;
                16'd20: packet_payload[63:56] <= rx_data;
                16'd21: packet_payload[55:48] <= rx_data;
                16'd22: packet_payload[47:40] <= rx_data;
                16'd23: packet_payload[39:32] <= rx_data;
                16'd24: packet_payload[31:24] <= rx_data;
                16'd25: packet_payload[23:16] <= rx_data;
                16'd26: packet_payload[15:8] <= rx_data;
                16'd27: packet_payload[7:0] <= rx_data;
                default: begin end
            endcase
        end else if (rx_valid_d) begin
            if (rx_expected_length < 16'd22 || rx_expected_length > 16'd278 ||
                rx_count != rx_expected_length ||
                packet_payload_length > 16'd256 ||
                packet_payload_length + 16'd22 != rx_expected_length ||
                !rx_header_ok) begin
                if (drop_count != 16'hffff) drop_count <= drop_count + 16'd1;
            end else if (rx_crc != rx_crc_wire) begin
                if (crc_error_count != 16'hffff)
                    crc_error_count <= crc_error_count + 16'd1;
            end else begin
                packet_valid <= 1'b1;
            end
            rx_count <= 16'd0;
            rx_crc <= 16'hffff;
        end
    end
end

localparam TX_IDLE = 2'd0, TX_ACK = 2'd1, TX_SEND = 2'd2;
reg [1:0] tx_state;
reg [5:0] tx_index;
reg [15:0] tx_crc;
reg [7:0] tx_type_hold, tx_flags_hold;
reg [4:0] tx_payload_length_hold;
reg [31:0] tx_seq_hold, tx_boot_hold, tx_uptime_hold;
reg [127:0] tx_payload_hold;
wire [15:0] tx_crc_next = crc_byte(tx_crc, tx_data);
assign send_ready = (tx_state == TX_IDLE);

function [7:0] packet_byte;
    input [5:0] index;
    input [7:0] msg_type, flags;
    input [4:0] payload_length;
    input [31:0] seq, boot, uptime;
    input [127:0] payload;
    begin
        case (index)
            6'd0: packet_byte = 8'h4d;
            6'd1: packet_byte = 8'h42;
            6'd2: packet_byte = 8'h01;
            6'd3: packet_byte = msg_type;
            6'd4: packet_byte = flags;
            6'd5: packet_byte = 8'h14;
            6'd6: packet_byte = 8'h00;
            6'd7: packet_byte = {3'd0, payload_length};
            6'd8: packet_byte = seq[31:24];
            6'd9: packet_byte = seq[23:16];
            6'd10: packet_byte = seq[15:8];
            6'd11: packet_byte = seq[7:0];
            6'd12: packet_byte = boot[31:24];
            6'd13: packet_byte = boot[23:16];
            6'd14: packet_byte = boot[15:8];
            6'd15: packet_byte = boot[7:0];
            6'd16: packet_byte = uptime[31:24];
            6'd17: packet_byte = uptime[23:16];
            6'd18: packet_byte = uptime[15:8];
            6'd19: packet_byte = uptime[7:0];
            6'd20: packet_byte = payload[127:120];
            6'd21: packet_byte = payload[119:112];
            6'd22: packet_byte = payload[111:104];
            6'd23: packet_byte = payload[103:96];
            6'd24: packet_byte = payload[95:88];
            6'd25: packet_byte = payload[87:80];
            6'd26: packet_byte = payload[79:72];
            6'd27: packet_byte = payload[71:64];
            6'd28: packet_byte = payload[63:56];
            6'd29: packet_byte = payload[55:48];
            6'd30: packet_byte = payload[47:40];
            6'd31: packet_byte = payload[39:32];
            6'd32: packet_byte = payload[31:24];
            6'd33: packet_byte = payload[23:16];
            6'd34: packet_byte = payload[15:8];
            6'd35: packet_byte = payload[7:0];
            default: packet_byte = 8'h00;
        endcase
    end
endfunction

always @(posedge clk or posedge rst) begin
    if (rst) begin
        tx_state <= TX_IDLE;
        tx_request <= 1'b0;
        tx_data <= 8'd0;
        tx_valid <= 1'b0;
        tx_length <= 16'd0;
        tx_index <= 6'd0;
        tx_crc <= 16'hffff;
        tx_type_hold <= 8'd0;
        tx_flags_hold <= 8'd0;
        tx_payload_length_hold <= 5'd0;
        tx_seq_hold <= 32'd0;
        tx_boot_hold <= 32'd0;
        tx_uptime_hold <= 32'd0;
        tx_payload_hold <= 128'd0;
    end else begin
        case (tx_state)
            TX_IDLE: if (send && send_payload_length <= 5'd16) begin
                tx_type_hold <= send_type;
                tx_flags_hold <= send_flags;
                tx_payload_length_hold <= send_payload_length;
                tx_seq_hold <= send_seq;
                tx_boot_hold <= send_boot_id;
                tx_uptime_hold <= send_uptime_ms;
                tx_payload_hold <= send_payload;
                tx_length <= 16'd22 + send_payload_length;
                tx_index <= 6'd0;
                tx_crc <= 16'hffff;
                tx_data <= 8'h4d;
                tx_state <= TX_ACK;
            end
            TX_ACK: begin
                if (tx_ready) tx_request <= 1'b1;
                if (tx_ack) begin
                    tx_request <= 1'b0;
                    tx_valid <= 1'b1;
                    tx_state <= TX_SEND;
                end
            end
            TX_SEND: begin
                if (tx_index < 6'd20 + tx_payload_length_hold)
                    tx_crc <= tx_crc_next;
                if (tx_index == 6'd21 + tx_payload_length_hold) begin
                    tx_valid <= 1'b0;
                    tx_state <= TX_IDLE;
                end else begin
                    tx_index <= tx_index + 6'd1;
                    if (tx_index + 6'd1 == 6'd20 + tx_payload_length_hold)
                        tx_data <= tx_crc_next[15:8];
                    else if (tx_index + 6'd1 == 6'd21 + tx_payload_length_hold)
                        tx_data <= tx_crc[7:0];
                    else
                        tx_data <= packet_byte(tx_index + 6'd1,
                            tx_type_hold, tx_flags_hold, tx_payload_length_hold,
                            tx_seq_hold, tx_boot_hold, tx_uptime_hold,
                            tx_payload_hold);
                end
            end
            default: tx_state <= TX_IDLE;
        endcase
    end
end

endmodule
`default_nettype wire
