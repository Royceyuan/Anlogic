`timescale 1ns / 1ps
`default_nettype none

// MBP1 byte-stream codec. One UDP datagram is one contiguous rx_valid burst.
// HOLD_TX_FIELDS=0 saves a register bank when the sender keeps send_* stable
// until send_ready returns high after TX. The default retains legacy timing.
// Payloads larger than 16 bytes are validated but only the first 16 bytes
// are exposed; the main-board command set never consumes more than 12.
module mbp1_codec #(
    parameter integer HOLD_TX_FIELDS = 1,
    parameter integer RX_PAYLOAD_BYTES = 8
) (
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
    output reg  [RX_PAYLOAD_BYTES*8-1:0] packet_payload,
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
reg [8:0] rx_crc_end_index;
reg [15:0] rx_crc, rx_crc_wire;
reg rx_header_ok;
wire [15:0] rx_index = rx_valid_d ? rx_count : 16'd0;
wire [15:0] rx_crc_base = rx_valid_d ? rx_crc : 16'hffff;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        rx_valid_d <= 1'b0;
        rx_count <= 16'd0;
        rx_expected_length <= 16'd0;
        rx_crc_end_index <= 9'd0;
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
                rx_crc_end_index <= rx_length[8:0] - 9'd2;
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
            if ((!rx_valid_d && rx_length >= 16'd22) ||
                (rx_valid_d && rx_index < {7'd0, rx_crc_end_index}))
                rx_crc <= crc_byte(rx_crc_base, rx_data);
            if (rx_valid_d && rx_index == {7'd0, rx_crc_end_index})
                rx_crc_wire[15:8] <= rx_data;
            if (rx_valid_d && rx_index == {7'd0, rx_crc_end_index} + 16'd1)
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
                16'd20: packet_payload[RX_PAYLOAD_BYTES*8-1-:8] <= rx_data;
                16'd21: packet_payload[RX_PAYLOAD_BYTES*8-9-:8] <= rx_data;
                16'd22: packet_payload[RX_PAYLOAD_BYTES*8-17-:8] <= rx_data;
                16'd23: packet_payload[RX_PAYLOAD_BYTES*8-25-:8] <= rx_data;
                16'd24: packet_payload[RX_PAYLOAD_BYTES*8-33-:8] <= rx_data;
                16'd25: packet_payload[RX_PAYLOAD_BYTES*8-41-:8] <= rx_data;
                16'd26: packet_payload[RX_PAYLOAD_BYTES*8-49-:8] <= rx_data;
                16'd27: packet_payload[RX_PAYLOAD_BYTES*8-57-:8] <= rx_data;
                16'd28: if(RX_PAYLOAD_BYTES>=12)packet_payload[RX_PAYLOAD_BYTES*8-65-:8]<=rx_data;
                16'd29: if(RX_PAYLOAD_BYTES>=12)packet_payload[RX_PAYLOAD_BYTES*8-73-:8]<=rx_data;
                16'd30: if(RX_PAYLOAD_BYTES>=12)packet_payload[RX_PAYLOAD_BYTES*8-81-:8]<=rx_data;
                16'd31: if(RX_PAYLOAD_BYTES>=12)packet_payload[RX_PAYLOAD_BYTES*8-89-:8]<=rx_data;
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
wire [7:0] active_type, active_flags;
wire [4:0] active_payload_length;
wire [31:0] active_seq, active_boot, active_uptime;
wire [127:0] active_payload;
generate if (HOLD_TX_FIELDS) begin : g_hold_tx
    reg [7:0] type_hold, flags_hold;
    reg [4:0] length_hold;
    reg [31:0] seq_hold, boot_hold, uptime_hold;
    reg [127:0] payload_hold;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            type_hold <= 0; flags_hold <= 0; length_hold <= 0;
            seq_hold <= 0; boot_hold <= 0; uptime_hold <= 0;
            payload_hold <= 0;
        end else if (send && send_ready && send_payload_length <= 5'd16) begin
            type_hold <= send_type; flags_hold <= send_flags;
            length_hold <= send_payload_length; seq_hold <= send_seq;
            boot_hold <= send_boot_id; uptime_hold <= send_uptime_ms;
            payload_hold <= send_payload;
        end
    end
    assign active_type = type_hold;
    assign active_flags = flags_hold;
    assign active_payload_length = length_hold;
    assign active_seq = seq_hold;
    assign active_boot = boot_hold;
    assign active_uptime = uptime_hold;
    assign active_payload = payload_hold;
end else begin : g_direct_tx
    assign active_type = send_type;
    assign active_flags = send_flags;
    assign active_payload_length = send_payload_length;
    assign active_seq = send_seq;
    assign active_boot = send_boot_id;
    assign active_uptime = send_uptime_ms;
    assign active_payload = send_payload;
end endgenerate
wire [15:0] tx_crc_next = crc_byte(tx_crc, tx_data);
assign send_ready = (tx_state == TX_IDLE);

function [7:0] packet_byte;
    input [5:0] index;
    input [7:0] msg_type, flags;
    input [4:0] payload_length;
    input [31:0] seq, boot, uptime;
    input [127:0] payload;
    reg [31:0] word_data;
    begin
        case (index[5:2])
            4'd0: word_data = {24'h4d4201, msg_type};
            4'd1: word_data = {flags, 16'h1400, 3'd0, payload_length};
            4'd2: word_data = seq;
            4'd3: word_data = boot;
            4'd4: word_data = uptime;
            4'd5: word_data = payload[127:96];
            4'd6: word_data = payload[95:64];
            4'd7: word_data = payload[63:32];
            4'd8: word_data = payload[31:0];
            default: word_data = 32'd0;
        endcase
        case (index[1:0])
            2'd0: packet_byte = word_data[31:24];
            2'd1: packet_byte = word_data[23:16];
            2'd2: packet_byte = word_data[15:8];
            2'd3: packet_byte = word_data[7:0];
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
    end else begin
        case (tx_state)
            TX_IDLE: if (send && send_payload_length <= 5'd16) begin
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
                if (tx_index < 6'd20 + active_payload_length)
                    tx_crc <= tx_crc_next;
                if (tx_index == 6'd21 + active_payload_length) begin
                    tx_valid <= 1'b0;
                    tx_state <= TX_IDLE;
                end else begin
                    tx_index <= tx_index + 6'd1;
                    if (tx_index + 6'd1 == 6'd20 + active_payload_length)
                        tx_data <= tx_crc_next[15:8];
                    else if (tx_index + 6'd1 == 6'd21 + active_payload_length)
                        tx_data <= tx_crc[7:0];
                    else
                        tx_data <= packet_byte(tx_index + 6'd1,
                            active_type, active_flags, active_payload_length,
                            active_seq, active_boot, active_uptime,
                            active_payload);
                end
            end
            default: tx_state <= TX_IDLE;
        endcase
    end
end

endmodule
`default_nettype wire
