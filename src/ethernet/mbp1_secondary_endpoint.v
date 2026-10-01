`timescale 1ns / 1ps
`default_nettype none

// Secondary MBP1 state receiver. The fixed UDP layer checks peer IP/port;
// the codec checks exact frame length, header and CRC before packet_valid.
module mbp1_secondary_endpoint #(
    parameter integer CLOCKS_PER_MS = 50000
) (
    input wire clk,
    input wire rst,
    input wire phy_link,
    input wire [31:0] local_boot_id,
    input wire [7:0] rx_data,
    input wire rx_valid,
    input wire [15:0] rx_length,
    input wire tx_ready,
    input wire tx_ack,
    output wire tx_request,
    output wire [7:0] tx_data,
    output wire tx_valid,
    output wire [15:0] tx_length,
    output wire peer_alive,
    output wire manual_supported,
    output reg heartbeat_pulse,
    output reg [127:0] heartbeat_data,
    output reg display_pulse,
    output reg [95:0] display_data,
    output reg diagnostic_pulse,
    output reg [127:0] diagnostic_data,
    input wire control_request,
    input wire [7:0] control_type,
    input wire [63:0] control_payload,
    output wire control_ready,
    output reg control_done,
    output reg [7:0] control_result,
    output wire [15:0] crc_error_count,
    output wire [15:0] drop_count
);

wire packet_valid;
wire [7:0] packet_type, packet_flags;
wire [15:0] packet_payload_length;
wire [31:0] packet_seq, packet_boot_id, packet_uptime_ms;
wire [127:0] packet_payload;
reg send;
wire send_ready;
reg [7:0] send_type, send_flags;
reg [4:0] send_payload_length;
reg [31:0] send_seq, send_boot_id, send_uptime_ms;
reg [127:0] send_payload;

mbp1_codec #(.HOLD_TX_FIELDS(0), .RX_PAYLOAD_BYTES(16)) u_codec (
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

function seq_newer;
    input [31:0] candidate, previous;
    reg [31:0] delta;
    begin
        delta = candidate - previous;
        seq_newer = delta != 0 && !delta[31];
    end
endfunction

localparam integer DIV_BITS = CLOCKS_PER_MS <= 1 ? 1 : $clog2(CLOCKS_PER_MS);
reg [DIV_BITS-1:0] ms_divider;
wire ms_tick = ms_divider == CLOCKS_PER_MS - 1;
reg [31:0] uptime_ms, next_seq;
reg [10:0] heartbeat_age_ms;
reg [8:0] heartbeat_period_ms;
reg [1:0] tx_gap_ms;
reg phy_link_d;
reg [31:0] peer_boot_id;
reg peer_boot_seen;
reg hello_seen;
reg peer_manual_cap;
reg [31:0] last_hello_seq;
reg hb_seen, display_seen, diag_seen;
reg [31:0] hb_seq, display_seq, diag_seq;
reg hello_pending, hello_waiting, query_pending, query_waiting;
reg [31:0] hello_seq, query_seq;
reg [6:0] hello_wait_ms, query_wait_ms;
reg [3:0] hello_attempts, query_attempts;
reg heartbeat_pending;
reg ack_pending;
reg [31:0] ack_seq;
reg [7:0] ack_type, ack_result;
wire new_boot = !peer_boot_seen || peer_boot_id != packet_boot_id;
wire heartbeat_fields_ok =
    (packet_payload[119:112] <= 8'd4 || packet_payload[119:112] == 8'hff) &&
    (packet_payload[111:104] <= 8'd4 || packet_payload[111:104] == 8'hff) &&
    packet_payload[103:96] <= 8'd5 && packet_payload[95:88] <= 8'd1 &&
    (packet_payload[11:8] <= 4'd4 || packet_payload[11:8] == 4'hf);
wire display_fields_ok =
    (packet_payload[127:120] <= 8'd3 || packet_payload[127:120] == 8'hff) &&
    packet_payload[119:112] <= 8'd6 && packet_payload[111:104] <= 8'd4 &&
    packet_payload[103:96] <= 8'd5 && packet_payload[95:88] <= 8'd6 &&
    (packet_payload[87:80] == 8'd1 || packet_payload[87:80] == 8'd2) &&
    (packet_payload[71:64] <= 8'd4 || packet_payload[71:64] == 8'hff);
assign peer_alive = phy_link && peer_boot_seen && heartbeat_age_ms < 11'd2000;
assign manual_supported = peer_alive && hello_seen && peer_manual_cap;
reg control_pending, control_waiting, control_sent;
reg control_ack_ok, control_status_ok;
reg [7:0] active_control_type;
reg [63:0] active_control_payload;
reg [31:0] active_control_seq;
reg [3:0] control_attempts;
reg [12:0] control_age_ms;
reg control_hb_fresh, control_display_fresh;
wire manual_control = active_control_type == 8'h17 || active_control_type == 8'h18;
wire [12:0] status_timeout_ms = manual_control ? 13'd8000 : 13'd1500;
wire manual_status_match = control_hb_fresh && control_display_fresh &&
    heartbeat_data[95:88] == 0 && !heartbeat_data[70] &&
    display_data[39:32] == heartbeat_data[111:104] &&
    ((active_control_type == 8'h17 &&
      display_data[42] == active_control_payload[56] &&
      ((active_control_payload[56] &&
        ((heartbeat_data[103:96] == 0 && heartbeat_data[111:104] == 8'hff) ||
         (heartbeat_data[103:96] == 5 && heartbeat_data[111:104] <= 4))) ||
       (!active_control_payload[56] && heartbeat_data[103:96] == 0 &&
        heartbeat_data[111:104] == 8'hff))) ||
     (active_control_type == 8'h18 && display_data[42] &&
      heartbeat_data[103:96] == 5 &&
      heartbeat_data[119:112] == active_control_payload[63:56] &&
      (heartbeat_data[111:104] == active_control_payload[55:48] ||
       (active_control_payload[55:48] == 0 && heartbeat_data[111:104] == 4))));
wire control_status_match =
    (active_control_type == 8'h13 &&
     packet_payload[127:120] == active_control_payload[63:56]) ||
    (active_control_type == 8'h14 &&
     packet_payload[127:120] == 8'hff &&
     packet_payload[119:88] == active_control_payload[63:32]) ||
    (active_control_type == 8'h15 &&
     heartbeat_data[119:112] == active_control_payload[63:56] &&
     packet_payload[71:64] == active_control_payload[55:48] &&
     packet_payload[87:80] == active_control_payload[47:40] &&
     packet_payload[63:32] == active_control_payload[31:0]);
assign control_ready = peer_alive && hb_seen && display_seen && !control_waiting;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        ms_divider <= 0; uptime_ms <= 0; next_seq <= 32'd1;
        heartbeat_age_ms <= 11'd2000; heartbeat_period_ms <= 0;
        tx_gap_ms <= 0; phy_link_d <= 0;
        peer_boot_id <= 0; peer_boot_seen <= 0;
        hello_seen <= 0; last_hello_seq <= 0;
        peer_manual_cap <= 0;
        hb_seen <= 0; display_seen <= 0; diag_seen <= 0;
        hb_seq <= 0; display_seq <= 0; diag_seq <= 0;
        hello_pending <= 1; hello_waiting <= 0;
        query_pending <= 0; query_waiting <= 0;
        hello_seq <= 0; query_seq <= 0;
        hello_wait_ms <= 0; query_wait_ms <= 0;
        hello_attempts <= 0; query_attempts <= 0;
        heartbeat_pending <= 0; ack_pending <= 0;
        ack_seq <= 0; ack_type <= 0; ack_result <= 0;
        control_pending <= 0; control_waiting <= 0; control_sent <= 0;
        control_ack_ok <= 0; control_status_ok <= 0;
        active_control_type <= 0; active_control_payload <= 0;
        active_control_seq <= 0; control_attempts <= 0;
        control_age_ms <= 0; control_done <= 0; control_result <= 0;
        control_hb_fresh <= 0; control_display_fresh <= 0;
        heartbeat_pulse <= 0; heartbeat_data <= 0;
        display_pulse <= 0; display_data <= 0;
        diagnostic_pulse <= 0; diagnostic_data <= 0;
        send <= 0; send_type <= 0; send_flags <= 0;
        send_payload_length <= 0; send_seq <= 0;
        send_boot_id <= 0; send_uptime_ms <= 0; send_payload <= 0;
    end else begin
        phy_link_d <= phy_link;
        heartbeat_pulse <= 0;
        display_pulse <= 0;
        diagnostic_pulse <= 0;
        send <= 0;
        control_done <= 0;
        // ACK accepts the request; only fresh applied telemetry completes it.
        if (control_waiting && control_ack_ok &&
            (manual_control ? manual_status_match : control_status_ok)) begin
            control_waiting <= 0; control_pending <= 0;
            control_done <= 1; control_result <= 0;
        end
        if (ms_tick) begin
            ms_divider <= 0;
            uptime_ms <= uptime_ms + 32'd1;
            if (tx_gap_ms != 0) tx_gap_ms <= tx_gap_ms - 2'd1;
            if (heartbeat_age_ms < 11'd2000)
                heartbeat_age_ms <= heartbeat_age_ms + 11'd1;
            if (heartbeat_period_ms == 9'd499) begin
                heartbeat_period_ms <= 0;
                heartbeat_pending <= 1;
            end else heartbeat_period_ms <= heartbeat_period_ms + 9'd1;
            if (hello_waiting && hello_wait_ms == 7'd99) begin
                hello_wait_ms <= 0;
                if (hello_attempts < 4'd10) hello_pending <= 1;
                else hello_waiting <= 0;
            end else if (hello_waiting) hello_wait_ms <= hello_wait_ms + 7'd1;
            if (query_waiting && query_wait_ms == 7'd99) begin
                query_wait_ms <= 0;
                if (query_attempts < 4'd10) query_pending <= 1;
                else query_waiting <= 0;
            end else if (query_waiting) query_wait_ms <= query_wait_ms + 7'd1;
            if (control_waiting && control_sent) begin
                if (control_age_ms < status_timeout_ms)
                    control_age_ms <= control_age_ms + 13'd1;
                if (!control_ack_ok && control_age_ms == 13'd99) begin
                    if (control_attempts < 4'd10) control_pending <= 1;
                    else begin
                        control_waiting <= 0; control_pending <= 0;
                        control_done <= 1; control_result <= 8'hfe;
                        query_pending <= 1;
                    end
                end else if (control_ack_ok && control_age_ms == status_timeout_ms - 1'b1) begin
                    control_waiting <= 0; control_pending <= 0;
                    control_done <= 1; control_result <= 8'hfd;
                    query_pending <= 1;
                end
            end
        end else ms_divider <= ms_divider + 1'b1;

        if ((phy_link_d && !phy_link) ||
            (ms_tick && heartbeat_age_ms == 11'd1999)) begin
            peer_boot_seen <= 0;
            hello_seen <= 0;
            peer_manual_cap <= 0;
            hb_seen <= 0; display_seen <= 0; diag_seen <= 0;
            hello_pending <= 1; hello_waiting <= 0;
            query_pending <= 0; query_waiting <= 0;
            control_waiting <= 0; control_pending <= 0;
            if (control_waiting) begin control_done <= 1; control_result <= 8'hfc; end
        end
        if (packet_valid) begin
            if (new_boot) begin
                peer_boot_seen <= 1;
                peer_boot_id <= packet_boot_id;
                hello_seen <= 0;
                peer_manual_cap <= 0;
                hb_seen <= 0; display_seen <= 0; diag_seen <= 0;
                heartbeat_age_ms <= 11'd2000;
                hello_pending <= 1; hello_waiting <= 0;
                query_pending <= 1; query_waiting <= 0;
                control_waiting <= 0; control_pending <= 0;
                if (control_waiting) begin control_done <= 1; control_result <= 8'hfc; end
            end
            case (packet_type)
                8'h01: if (packet_flags[0]) begin
                    ack_pending <= 1; ack_seq <= packet_seq;
                    ack_type <= packet_type;
                    ack_result <= (packet_payload_length == 16'd12 &&
                                   packet_payload[127:96] == 32'h01010101) ? 8'd0 : 8'd5;
                    if (packet_payload_length == 16'd12 &&
                        packet_payload[127:96] == 32'h01010101) begin
                        peer_manual_cap <= packet_payload[41];
                        query_pending <= 1;
                        if (new_boot || !hello_seen ||
                            last_hello_seq != packet_seq) begin
                            hello_seen <= 1;
                            last_hello_seq <= packet_seq;
                            hb_seen <= 0; display_seen <= 0; diag_seen <= 0;
                            control_waiting <= 0; control_pending <= 0;
                            if (control_waiting) begin control_done <= 1; control_result <= 8'hfc; end
                            hello_pending <= 1; hello_waiting <= 0;
                            heartbeat_age_ms <= 11'd2000;
                        end
                    end
                end
                8'h02: if (packet_payload_length == 16'd16 && heartbeat_fields_ok &&
                             (new_boot || !hb_seen || seq_newer(packet_seq, hb_seq))) begin
                    heartbeat_pulse <= 1;
                    heartbeat_data <= packet_payload;
                    hb_seq <= packet_seq; hb_seen <= 1;
                    heartbeat_age_ms <= 0;
                    if (!new_boot && control_waiting && control_sent)
                        control_hb_fresh <= !(active_control_type == 8'h17 &&
                            !active_control_payload[56] && control_age_ms < 13'd100);
                    if (control_waiting &&
                        (packet_payload[95:88] != 8'd0 ||
                         (packet_payload[70] && !(active_control_type == 8'h17 &&
                                                  !active_control_payload[56])) ||
                         (active_control_type == 8'h15 &&
                          (packet_payload[119:112] != active_control_payload[63:56] ||
                           packet_payload[111:104] != active_control_payload[55:48])) ||
                         (active_control_type == 8'h18 &&
                          (packet_payload[119:112] != active_control_payload[63:56] ||
                           packet_payload[111:104] == 8'hff)))) begin
                        control_waiting <= 0; control_pending <= 0;
                        control_done <= 1; control_result <= 8'hfc;
                    end
                end
                8'h04: if (packet_payload_length == 16'd8) begin
                    if (packet_payload[87:80] == 8'd0 &&
                        packet_payload[95:88] == 8'h01 &&
                        packet_payload[127:96] == hello_seq) begin
                        hello_waiting <= 0;
                        query_pending <= 1;
                    end
                    if (packet_payload[87:80] == 8'd0 &&
                        packet_payload[95:88] == 8'h03 &&
                        packet_payload[127:96] == query_seq)
                        query_waiting <= 0;
                    if (!new_boot && control_waiting && control_sent &&
                        packet_payload[95:88] == active_control_type &&
                        packet_payload[127:96] == active_control_seq) begin
                        if (packet_payload[87:80] == 8'd0) begin
                            control_ack_ok <= 1;
                            control_pending <= 0;
                            if (!manual_control && control_status_ok) begin
                                control_waiting <= 0; control_pending <= 0;
                                control_done <= 1; control_result <= 0;
                            end
                        end else begin
                            control_waiting <= 0; control_pending <= 0;
                            control_done <= 1;
                            control_result <= packet_payload[87:80];
                            query_pending <= 1;
                        end
                    end
                end
                8'h12: if (packet_flags[0]) begin
                    ack_pending <= 1; ack_seq <= packet_seq;
                    ack_type <= packet_type;
                    ack_result <= packet_payload_length == 16'd8 ? 8'd0 : 8'd2;
                end
                8'h16: if (packet_payload_length == 16'd12 && display_fields_ok &&
                             (new_boot || !display_seen || seq_newer(packet_seq, display_seq))) begin
                    display_pulse <= 1;
                    display_data <= packet_payload[127:32];
                    display_seq <= packet_seq; display_seen <= 1;
                    if (control_waiting && control_sent && !new_boot)
                        control_display_fresh <= 1;
                    if (control_waiting && control_sent &&
                        !new_boot && control_status_match) begin
                        control_status_ok <= 1;
                        if (control_ack_ok) begin
                            control_waiting <= 0; control_pending <= 0;
                            control_done <= 1; control_result <= 0;
                        end
                    end
                end
                8'h31: if (packet_payload_length == 16'd16 &&
                             (new_boot || !diag_seen || seq_newer(packet_seq, diag_seq))) begin
                    diagnostic_pulse <= 1;
                    diagnostic_data <= packet_payload;
                    diag_seq <= packet_seq; diag_seen <= 1;
                end
                default: if (packet_flags[0] && !packet_flags[1]) begin
                    ack_pending <= 1; ack_seq <= packet_seq;
                    ack_type <= packet_type; ack_result <= 8'd3;
                end
            endcase
        end
        if (control_request && control_ready &&
            (control_type == 8'h13 || control_type == 8'h14 ||
             control_type == 8'h15 ||
             (manual_supported && (control_type == 8'h17 || control_type == 8'h18)))) begin
            active_control_type <= control_type;
            active_control_payload <= control_payload;
            active_control_seq <= next_seq;
            next_seq <= next_seq + 32'd1;
            control_pending <= 1; control_waiting <= 1;
            control_sent <= 0; control_ack_ok <= 0;
            control_status_ok <= 0; control_attempts <= 0;
            control_age_ms <= 0;
            control_hb_fresh <= 0; control_display_fresh <= 0;
        end
        if (phy_link && !(ms_tick && heartbeat_age_ms == 11'd1999) &&
            !packet_valid && !control_request && !send && send_ready && tx_ready &&
            tx_gap_ms == 0 && (ack_pending || hello_pending ||
                               query_pending || heartbeat_pending ||
                               control_pending)) begin
            send <= 1; tx_gap_ms <= 2'd2;
            send_seq <= next_seq;
            send_boot_id <= local_boot_id;
            send_uptime_ms <= uptime_ms;
            send_flags <= 0;
            send_payload <= 0;
            if (ack_pending) begin
                send_type <= 8'h04; send_flags <= 8'h02;
                send_payload_length <= 5'd8;
                send_payload <= {ack_seq, ack_type, ack_result, 8'd0, 8'd0, 64'd0};
                ack_pending <= 0; next_seq <= next_seq + 32'd1;
            end else if (hello_pending) begin
                send_type <= 8'h01;
                send_flags <= hello_waiting ? 8'h05 : 8'h01;
                send_payload_length <= 5'd12;
                send_payload <= {32'h02020101, 32'h00050002, 32'h00000200, 32'd0};
                if (hello_waiting) begin
                    send_seq <= hello_seq;
                    hello_attempts <= hello_attempts + 4'd1;
                end else begin
                    hello_seq <= next_seq;
                    next_seq <= next_seq + 32'd1;
                    hello_attempts <= 4'd1;
                end
                hello_pending <= 0; hello_waiting <= 1; hello_wait_ms <= 0;
            end else if (query_pending) begin
                send_type <= 8'h03;
                send_flags <= query_waiting ? 8'h05 : 8'h01;
                send_payload_length <= 5'd0;
                if (query_waiting) begin
                    send_seq <= query_seq;
                    query_attempts <= query_attempts + 4'd1;
                end else begin
                    query_seq <= next_seq;
                    next_seq <= next_seq + 32'd1;
                    query_attempts <= 4'd1;
                end
                query_pending <= 0; query_waiting <= 1; query_wait_ms <= 0;
            end else if (control_pending) begin
                send_type <= active_control_type;
                send_flags <= control_attempts == 0 ? 8'h01 : 8'h05;
                send_payload_length <= (active_control_type == 8'h13 || manual_control) ? 5'd4 : 5'd8;
                send_payload <= {active_control_payload, 64'd0};
                send_seq <= active_control_seq;
                control_pending <= 0; control_sent <= 1;
                control_attempts <= control_attempts + 4'd1;
                control_age_ms <= 0;
            end else begin
                send_type <= 8'h02;
                send_payload_length <= 5'd16;
                heartbeat_pending <= 0;
                next_seq <= next_seq + 32'd1;
            end
        end
    end
end
endmodule

`default_nettype wire
