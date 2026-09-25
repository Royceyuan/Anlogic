`timescale 1ns / 1ps
`default_nettype none

// Main-board MBP1 control plane. UDP framing is supplied by the existing
// Ethernet stack; all application state here runs in the UDP clock domain.
module mbp1_main_endpoint #(
    parameter integer CLOCKS_PER_MS = 125000,
    parameter integer ENABLE_CONTROL = 0
) (
    input  wire         clk,
    input  wire         rst,
    input  wire [7:0]   rx_data,
    input  wire         rx_valid,
    input  wire [15:0]  rx_length,
    input  wire         tx_ready,
    input  wire         tx_ack,
    output wire         tx_request,
    output wire [7:0]   tx_data,
    output wire         tx_valid,
    output wire [15:0]  tx_length,
    input  wire [31:0]  local_boot_id,
    input  wire         phy_link,
    input  wire [7:0]   main_mode,
    input  wire [127:0] heartbeat_payload,
    input  wire [95:0]  display_payload,
    input  wire [127:0] diagnostic_payload,
    output reg          command_valid,
    output reg  [7:0]   command_type,
    output reg  [31:0]  command_seq,
    output reg  [63:0]  command_payload,
    input  wire         command_done,
    input  wire [7:0]   command_result,
    output wire         peer_alive,
    output wire [15:0]  crc_error_count,
    output wire [15:0]  drop_count,
    output reg  [15:0]  retry_count
);

wire packet_valid;
wire [7:0] packet_type, packet_flags;
wire [15:0] packet_payload_length;
wire [31:0] packet_seq, packet_boot_id, packet_uptime_ms;
wire [63:0] packet_payload;
reg send;
wire send_ready;
reg [7:0] send_type, send_flags;
reg [4:0] send_payload_length;
reg [31:0] send_seq, send_boot_id, send_uptime_ms;
reg [127:0] send_payload;

mbp1_codec u_codec (
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

reg [31:0] next_seq, uptime_ms;
reg [31:0] peer_boot_id;
reg peer_boot_seen;
reg [15:0] heartbeat_age_ms;
assign peer_alive = phy_link && peer_boot_seen &&
                    (heartbeat_age_ms < 16'd2000);

reg [31:0] ms_divider;
reg [9:0] snapshot_ms;
reg [6:0] hello_wait_ms;
reg [3:0] hello_attempts;
reg hello_pending, hello_waiting;
reg [31:0] hello_seq;
reg heartbeat_pending, display_pending, diagnostic_pending;
reg ack_pending;
reg [31:0] ack_seq;
reg [7:0] ack_type, ack_result;
reg last_command_valid;
reg [31:0] last_command_boot, last_command_seq;
reg [7:0] last_command_type, last_command_result;

wire ms_tick = (ms_divider == CLOCKS_PER_MS - 1);
wire is_command = packet_type == 8'h13 || packet_type == 8'h14 ||
                  packet_type == 8'h15;
wire command_length_ok = (packet_type == 8'h13 &&
                          packet_payload_length == 16'd4) ||
                         ((packet_type == 8'h14 || packet_type == 8'h15) &&
                          packet_payload_length == 16'd8);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        ms_divider <= 32'd0;
        uptime_ms <= 32'd0;
        snapshot_ms <= 10'd0;
        heartbeat_age_ms <= 16'd2000;
        hello_wait_ms <= 7'd0;
        hello_attempts <= 4'd0;
        hello_pending <= 1'b1;
        hello_waiting <= 1'b0;
        hello_seq <= 32'd0;
        heartbeat_pending <= 1'b0;
        display_pending <= 1'b0;
        diagnostic_pending <= 1'b0;
        ack_pending <= 1'b0;
        ack_seq <= 32'd0;
        ack_type <= 8'd0;
        ack_result <= 8'd0;
        next_seq <= 32'd1;
        peer_boot_id <= 32'd0;
        peer_boot_seen <= 1'b0;
        command_valid <= 1'b0;
        command_type <= 8'd0;
        command_seq <= 32'd0;
        command_payload <= 64'd0;
        last_command_valid <= 1'b0;
        last_command_boot <= 32'd0;
        last_command_seq <= 32'd0;
        last_command_type <= 8'd0;
        last_command_result <= 8'd0;
        retry_count <= 16'd0;
        send <= 1'b0;
        send_type <= 8'd0;
        send_flags <= 8'd0;
        send_payload_length <= 5'd0;
        send_seq <= 32'd0;
        send_boot_id <= 32'd0;
        send_uptime_ms <= 32'd0;
        send_payload <= 128'd0;
    end else begin
        send <= 1'b0;
        if (ms_tick) begin
            ms_divider <= 32'd0;
            uptime_ms <= uptime_ms + 32'd1;
            if (heartbeat_age_ms < 16'd2000)
                heartbeat_age_ms <= heartbeat_age_ms + 16'd1;
            if (snapshot_ms == 10'd999) begin
                snapshot_ms <= 10'd0;
                heartbeat_pending <= 1'b1;
                display_pending <= 1'b1;
                diagnostic_pending <= 1'b1;
            end else begin
                snapshot_ms <= snapshot_ms + 10'd1;
                if (snapshot_ms == 10'd499) begin
                    heartbeat_pending <= 1'b1;
                    display_pending <= 1'b1;
                end
            end
            if (hello_waiting && hello_wait_ms == 7'd99) begin
                hello_wait_ms <= 7'd0;
                if (hello_attempts < 4'd10) begin
                    hello_pending <= 1'b1;
                    if (retry_count != 16'hffff)
                        retry_count <= retry_count + 16'd1;
                end else
                    hello_waiting <= 1'b0;
            end else if (hello_waiting)
                hello_wait_ms <= hello_wait_ms + 7'd1;
        end else
            ms_divider <= ms_divider + 32'd1;

        if (command_done && command_valid) begin
            command_valid <= 1'b0;
            last_command_valid <= 1'b1;
            last_command_boot <= peer_boot_id;
            last_command_seq <= command_seq;
            last_command_type <= command_type;
            last_command_result <= command_result;
            ack_pending <= 1'b1;
            ack_seq <= command_seq;
            ack_type <= command_type;
            ack_result <= command_result;
            if (command_result == 8'd0) display_pending <= 1'b1;
        end

        if (packet_valid) begin
            if (!peer_boot_seen || peer_boot_id != packet_boot_id) begin
                peer_boot_seen <= 1'b1;
                peer_boot_id <= packet_boot_id;
                last_command_valid <= 1'b0;
                heartbeat_age_ms <= 16'd2000;
                hello_pending <= 1'b1;
            end
            if (packet_type == 8'h04 && packet_payload_length == 16'd8 &&
                packet_payload[31:24] == 8'h01 &&
                packet_payload[63:32] == hello_seq &&
                packet_payload[23:16] == 8'd0)
                hello_waiting <= 1'b0;
            else if (packet_type == 8'h02 &&
                     packet_payload_length == 16'd16)
                heartbeat_age_ms <= 16'd0;
            else if (packet_type != 8'h04 && packet_flags[0]) begin
                ack_seq <= packet_seq;
                ack_type <= packet_type;
                ack_pending <= 1'b1;
                ack_result <= 8'd0;
                if (packet_type == 8'h01) begin
                    if (packet_payload_length != 16'd12 ||
                        packet_payload[63:56] != 8'h02 ||
                        packet_payload[55:48] != 8'h02 ||
                        packet_payload[47:40] > 8'h01 ||
                        packet_payload[39:32] < 8'h01)
                        ack_result <= 8'd5;
                    else begin
                        display_pending <= 1'b1;
                        diagnostic_pending <= 1'b1;
                    end
                end else if (packet_type == 8'h03) begin
                    if (packet_payload_length != 16'd0)
                        ack_result <= 8'd2;
                    else begin
                        heartbeat_pending <= 1'b1;
                        display_pending <= 1'b1;
                        diagnostic_pending <= 1'b1;
                    end
                end else if (is_command) begin
                    if (!command_length_ok)
                        ack_result <= 8'd2;
                    else if (!ENABLE_CONTROL)
                        ack_result <= 8'd3;
                    else if (command_valid) begin
                        if (command_seq == packet_seq &&
                            peer_boot_id == packet_boot_id)
                            ack_pending <= 1'b0;
                        else
                            ack_result <= 8'd4;
                    end else if (last_command_valid &&
                                 last_command_boot == packet_boot_id &&
                                 last_command_seq == packet_seq &&
                                 last_command_type == packet_type)
                        ack_result <= last_command_result;
                    else if (last_command_valid &&
                             last_command_boot == packet_boot_id &&
                             (packet_seq - last_command_seq) > 32'h7fffffff)
                        ack_result <= 8'd5;
                    else begin
                        ack_pending <= 1'b0;
                        command_valid <= 1'b1;
                        command_type <= packet_type;
                        command_seq <= packet_seq;
                        command_payload <= packet_payload;
                    end
                end else
                    ack_result <= 8'd3;
            end
        end

        // An ACK outranks periodic telemetry. Never launch on a receive or
        // command-completion cycle so a new ACK cannot be cleared by launch.
        if (!packet_valid && !command_done && !send && send_ready && tx_ready) begin
            send_boot_id <= local_boot_id;
            send_uptime_ms <= uptime_ms;
            send_flags <= 8'd0;
            send_seq <= next_seq;
            if (ack_pending) begin
                send <= 1'b1;
                send_type <= 8'h04;
                send_flags <= 8'h02;
                send_payload_length <= 5'd8;
                send_payload <= {ack_seq, ack_type, ack_result, main_mode,
                                 8'd0, 64'd0};
                ack_pending <= 1'b0;
                next_seq <= next_seq + 32'd1;
            end else if (hello_pending) begin
                send <= 1'b1;
                send_type <= 8'h01;
                send_flags <= hello_waiting ? 8'h05 : 8'h01;
                send_payload_length <= 5'd12;
                send_payload <= {8'h01, 8'h01, 8'h01, 8'h01,
                                 32'h00050001, 32'h0000007f, 32'd0};
                if (!hello_waiting) begin
                    hello_seq <= next_seq;
                    next_seq <= next_seq + 32'd1;
                    hello_attempts <= 4'd1;
                    send_seq <= next_seq;
                end else begin
                    send_seq <= hello_seq;
                    hello_attempts <= hello_attempts + 4'd1;
                end
                hello_waiting <= 1'b1;
                hello_wait_ms <= 7'd0;
                hello_pending <= 1'b0;
            end else if (heartbeat_pending) begin
                send <= 1'b1;
                send_type <= 8'h02;
                send_payload_length <= 5'd16;
                send_payload <= heartbeat_payload;
                heartbeat_pending <= 1'b0;
                next_seq <= next_seq + 32'd1;
            end else if (display_pending) begin
                send <= 1'b1;
                send_type <= 8'h16;
                send_payload_length <= 5'd12;
                send_payload <= {display_payload, 32'd0};
                display_pending <= 1'b0;
                next_seq <= next_seq + 32'd1;
            end else if (diagnostic_pending) begin
                send <= 1'b1;
                send_type <= 8'h31;
                send_payload_length <= 5'd16;
                send_payload <= diagnostic_payload;
                diagnostic_pending <= 1'b0;
                next_seq <= next_seq + 32'd1;
            end
        end
    end
end

endmodule
`default_nettype wire
