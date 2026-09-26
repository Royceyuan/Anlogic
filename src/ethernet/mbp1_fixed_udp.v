`timescale 1ns / 1ps
`default_nettype none

// Fixed-address Ethernet/ARP/IPv4/UDP for the two-board MBP1 control link.
// TEMAC and its RX/TX clock-crossing FIFOs remain the official reference IP.
// No IP reassembly, options, routing, or generic socket table is needed here.
module mbp1_fixed_udp (
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  mac_rx_data,
    input  wire        mac_rx_valid,
    input  wire        mac_rx_sof_n,
    input  wire        mac_rx_eof_n,
    output wire        mac_rx_ready_n,
    output wire [7:0]  mac_tx_data,
    output wire        mac_tx_valid_n,
    output wire        mac_tx_sof_n,
    output wire        mac_tx_eof_n,
    input  wire        mac_tx_ready_n,
    output wire [7:0]  app_rx_data,
    output wire        app_rx_valid,
    output wire [15:0] app_rx_length,
    input  wire        app_tx_request,
    input  wire [7:0]  app_tx_data,
    input  wire        app_tx_valid,
    input  wire [15:0] app_tx_length,
    output wire        app_tx_ready,
    output reg         app_tx_ack
);

localparam [47:0] OUR_MAC = 48'h02_48_58_34_20_01;
localparam [31:0] OUR_IP = 32'hc0_a8_0a_01;
localparam [31:0] PEER_IP = 32'hc0_a8_0a_02;
localparam [15:0] PORT = 16'd5000;
assign mac_rx_ready_n = 1'b0;

reg [7:0] rx_data_q;
reg rx_valid_q, rx_sof_n_q, rx_eof_n_q;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        rx_data_q <= 8'd0;
        rx_valid_q <= 1'b0;
        rx_sof_n_q <= 1'b1;
        rx_eof_n_q <= 1'b1;
    end else begin
        rx_data_q <= mac_rx_data;
        rx_valid_q <= mac_rx_valid;
        rx_sof_n_q <= mac_rx_sof_n;
        rx_eof_n_q <= mac_rx_eof_n;
    end
end

reg [8:0] rx_index;
reg [47:0] rx_src_mac;
reg [15:0] rx_ether_type, rx_arp_op;
reg [7:0] rx_ip_version, rx_ip_flags_hi, rx_ip_flags_lo, rx_ip_proto;
reg [31:0] rx_src_ip, rx_dst_ip, rx_arp_target_ip;
reg [15:0] rx_src_port, rx_dst_port, rx_udp_length;
reg rx_udp_accepted, arp_reply_pending, peer_mac_seen;
reg arp_reply_taken;
reg [47:0] peer_mac;
wire [8:0] rx_position = !rx_sof_n_q ? 9'd0 : rx_index;
wire [15:0] rx_payload_length = rx_udp_length - 16'd8;
assign app_rx_data = rx_data_q;
assign app_rx_length = rx_payload_length;
assign app_rx_valid = rx_valid_q && rx_udp_accepted &&
                      rx_position >= 9'd42 &&
                      {7'd0, rx_position} < 16'd42 + rx_payload_length;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        rx_index <= 9'd0;
        rx_src_mac <= 48'd0;
        rx_ether_type <= 16'd0;
        rx_arp_op <= 16'd0;
        rx_ip_version <= 8'd0;
        rx_ip_flags_hi <= 8'd0;
        rx_ip_flags_lo <= 8'd0;
        rx_ip_proto <= 8'd0;
        rx_src_ip <= 32'd0;
        rx_dst_ip <= 32'd0;
        rx_arp_target_ip <= 32'd0;
        rx_src_port <= 16'd0;
        rx_dst_port <= 16'd0;
        rx_udp_length <= 16'd0;
        rx_udp_accepted <= 1'b0;
        arp_reply_pending <= 1'b0;
        peer_mac_seen <= 1'b0;
        peer_mac <= 48'd0;
    end else begin
      if (arp_reply_taken) arp_reply_pending <= 1'b0;
      if (rx_valid_q) begin
        rx_index <= rx_position + 9'd1;
        if (!rx_sof_n_q) rx_udp_accepted <= 1'b0;
        case (rx_position)
            9'd6, 9'd7, 9'd8, 9'd9, 9'd10, 9'd11:
                rx_src_mac <= {rx_src_mac[39:0], rx_data_q};
            9'd12, 9'd13: rx_ether_type <= {rx_ether_type[7:0], rx_data_q};
            9'd14: rx_ip_version <= rx_data_q;
            9'd20: begin
                rx_arp_op <= {rx_arp_op[7:0], rx_data_q};
                rx_ip_flags_hi <= rx_data_q;
            end
            9'd21: begin
                rx_arp_op <= {rx_arp_op[7:0], rx_data_q};
                rx_ip_flags_lo <= rx_data_q;
            end
            9'd23: rx_ip_proto <= rx_data_q;
            9'd26, 9'd27, 9'd28, 9'd29:
                rx_src_ip <= {rx_src_ip[23:0], rx_data_q};
            9'd30, 9'd31, 9'd32, 9'd33:
                rx_dst_ip <= {rx_dst_ip[23:0], rx_data_q};
            9'd34, 9'd35: rx_src_port <= {rx_src_port[7:0], rx_data_q};
            9'd36, 9'd37: rx_dst_port <= {rx_dst_port[7:0], rx_data_q};
            9'd38, 9'd39: rx_udp_length <= {rx_udp_length[7:0], rx_data_q};
            default: begin end
        endcase
        if (rx_position >= 9'd38 && rx_position <= 9'd41)
            rx_arp_target_ip <= {rx_arp_target_ip[23:0], rx_data_q};
        if (rx_position == 9'd41) begin
            if (rx_ether_type == 16'h0800 && rx_ip_version == 8'h45 &&
                rx_ip_flags_hi[5:0] == 6'd0 && rx_ip_flags_lo == 8'd0 &&
                rx_ip_proto == 8'd17 && rx_src_ip == PEER_IP &&
                rx_dst_ip == OUR_IP && rx_src_port == PORT &&
                rx_dst_port == PORT && rx_udp_length >= 16'd8 &&
                rx_udp_length <= 16'd286) begin
                rx_udp_accepted <= 1'b1;
                peer_mac <= rx_src_mac;
                peer_mac_seen <= 1'b1;
            end else if (rx_ether_type == 16'h0806 && rx_arp_op == 16'h0001 &&
                         {rx_arp_target_ip[23:0], rx_data_q} == OUR_IP) begin
                peer_mac <= rx_src_mac;
                peer_mac_seen <= 1'b1;
                arp_reply_pending <= 1'b1;
            end
        end
        if (!rx_eof_n_q) rx_udp_accepted <= 1'b0;
      end
    end
end

localparam [2:0] TX_IDLE = 3'd0, TX_COLLECT = 3'd1, TX_WAIT = 3'd2,
                 TX_ARP = 3'd3, TX_UDP = 3'd4;
reg [2:0] tx_state;
reg [8:0] tx_index;
reg [5:0] tx_payload_read_index;
reg [6:0] tx_count;
reg [5:0] tx_payload_length;
reg [7:0] tx_payload [0:63];
reg [47:0] tx_peer_mac;
reg [7:0] tx_byte_reg;
wire [15:0] udp_length = 16'd8 + {10'd0, tx_payload_length};
wire [15:0] ip_length = 16'd20 + udp_length;
wire [19:0] ip_sum = 20'h4500 + {4'd0, ip_length} + 20'h4000 +
                     20'h4011 + 20'hc0a8 + 20'h0a01 + 20'hc0a8 + 20'h0a02;
wire [16:0] ip_fold = {1'b0, ip_sum[15:0]} + {13'd0, ip_sum[19:16]};
wire [15:0] ip_checksum = ~({ip_fold[15:0]} + {15'd0, ip_fold[16]});
wire [8:0] tx_frame_length = (tx_state == TX_ARP ||
                              9'd42 + {3'd0, tx_payload_length} < 9'd60) ?
                              9'd60 : 9'd42 + {3'd0, tx_payload_length};
assign app_tx_ready = tx_state == TX_IDLE && peer_mac_seen && !arp_reply_pending;
assign mac_tx_valid_n = !(tx_state == TX_ARP || tx_state == TX_UDP);
assign mac_tx_sof_n = !((tx_state == TX_ARP || tx_state == TX_UDP) && tx_index == 0);
assign mac_tx_eof_n = !((tx_state == TX_ARP || tx_state == TX_UDP) &&
                        tx_index == tx_frame_length - 9'd1);

function [7:0] mac_byte;
    input [47:0] value;
    input [2:0] index;
    begin
        case (index)
            3'd0: mac_byte = value[47:40];
            3'd1: mac_byte = value[39:32];
            3'd2: mac_byte = value[31:24];
            3'd3: mac_byte = value[23:16];
            3'd4: mac_byte = value[15:8];
            default: mac_byte = value[7:0];
        endcase
    end
endfunction

wire [8:0] tx_lookup_index = tx_index + 9'd1;
reg [7:0] tx_byte;
always @* begin
    tx_byte = 8'd0;
    if (tx_lookup_index < 9'd6) tx_byte = mac_byte(tx_peer_mac, tx_lookup_index[2:0]);
    else if (tx_lookup_index < 9'd12) tx_byte = mac_byte(OUR_MAC, tx_lookup_index[2:0] - 3'd6);
    else if (tx_state == TX_ARP) begin
        case (tx_lookup_index)
            9'd12: tx_byte = 8'h08; 9'd13: tx_byte = 8'h06;
            9'd14: tx_byte = 8'h00; 9'd15: tx_byte = 8'h01;
            9'd16: tx_byte = 8'h08; 9'd17: tx_byte = 8'h00;
            9'd18: tx_byte = 8'h06; 9'd19: tx_byte = 8'h04;
            9'd20: tx_byte = 8'h00; 9'd21: tx_byte = 8'h02;
            9'd22, 9'd23, 9'd24, 9'd25, 9'd26, 9'd27:
                tx_byte = mac_byte(OUR_MAC, tx_lookup_index[2:0] - 3'd6);
            9'd28: tx_byte = OUR_IP[31:24];
            9'd29: tx_byte = OUR_IP[23:16];
            9'd30: tx_byte = OUR_IP[15:8];
            9'd31: tx_byte = OUR_IP[7:0];
            9'd32, 9'd33, 9'd34, 9'd35, 9'd36, 9'd37:
                tx_byte = mac_byte(tx_peer_mac, tx_lookup_index[2:0]);
            9'd38: tx_byte = PEER_IP[31:24];
            9'd39: tx_byte = PEER_IP[23:16];
            9'd40: tx_byte = PEER_IP[15:8];
            9'd41: tx_byte = PEER_IP[7:0];
            default: tx_byte = 8'd0;
        endcase
    end else begin
        case (tx_lookup_index)
            9'd12: tx_byte = 8'h08; 9'd13: tx_byte = 8'h00;
            9'd14: tx_byte = 8'h45; 9'd15: tx_byte = 8'h00;
            9'd16: tx_byte = ip_length[15:8];
            9'd17: tx_byte = ip_length[7:0];
            9'd20: tx_byte = 8'h40;
            9'd22: tx_byte = 8'h40;
            9'd23: tx_byte = 8'h11;
            9'd24: tx_byte = ip_checksum[15:8];
            9'd25: tx_byte = ip_checksum[7:0];
            9'd26: tx_byte = OUR_IP[31:24];
            9'd27: tx_byte = OUR_IP[23:16];
            9'd28: tx_byte = OUR_IP[15:8];
            9'd29: tx_byte = OUR_IP[7:0];
            9'd30: tx_byte = PEER_IP[31:24];
            9'd31: tx_byte = PEER_IP[23:16];
            9'd32: tx_byte = PEER_IP[15:8];
            9'd33: tx_byte = PEER_IP[7:0];
            9'd34: tx_byte = PORT[15:8];
            9'd35: tx_byte = PORT[7:0];
            9'd36: tx_byte = PORT[15:8];
            9'd37: tx_byte = PORT[7:0];
            9'd38: tx_byte = udp_length[15:8];
            9'd39: tx_byte = udp_length[7:0];
            default: if (tx_lookup_index >= 9'd42 && tx_lookup_index < 9'd42 +
                         {3'd0, tx_payload_length})
                tx_byte = tx_payload[tx_payload_read_index];
        endcase
    end
end
assign mac_tx_data = tx_byte_reg;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        tx_state <= TX_IDLE;
        tx_index <= 9'd0;
        tx_payload_read_index <= 6'd0;
        tx_count <= 7'd0;
        tx_payload_length <= 6'd0;
        tx_peer_mac <= 48'd0;
        tx_byte_reg <= 8'd0;
        app_tx_ack <= 1'b0;
        arp_reply_taken <= 1'b0;
    end else begin
        app_tx_ack <= 1'b0;
        arp_reply_taken <= 1'b0;
        case (tx_state)
            TX_IDLE: begin
                if (arp_reply_pending) begin
                    tx_peer_mac <= peer_mac;
                    tx_byte_reg <= peer_mac[47:40];
                    arp_reply_taken <= 1'b1;
                    tx_index <= 9'd0;
                    tx_state <= TX_ARP;
                end else if (app_tx_request && peer_mac_seen &&
                             app_tx_length >= 16'd22 && app_tx_length <= 16'd64) begin
                    tx_payload_length <= app_tx_length[5:0];
                    tx_peer_mac <= peer_mac;
                    tx_count <= 7'd0;
                    app_tx_ack <= 1'b1;
                    tx_state <= TX_COLLECT;
                end
            end
            TX_COLLECT: if (app_tx_valid) begin
                tx_payload[tx_count[5:0]] <= app_tx_data;
                tx_count <= tx_count + 7'd1;
                if (tx_count == {1'b0, tx_payload_length} - 7'd1)
                    tx_state <= TX_WAIT;
            end
            TX_WAIT: begin
                tx_index <= 9'd0;
                tx_payload_read_index <= 6'd0;
                tx_byte_reg <= tx_peer_mac[47:40];
                tx_state <= TX_UDP;
            end
            TX_ARP, TX_UDP: if (!mac_tx_ready_n) begin
                if (tx_index == tx_frame_length - 9'd1)
                    tx_state <= TX_IDLE;
                else begin
                    tx_index <= tx_index + 9'd1;
                    if (tx_state == TX_UDP && tx_index >= 9'd41)
                        tx_payload_read_index <= tx_payload_read_index + 6'd1;
                    tx_byte_reg <= tx_byte;
                end
            end
            default: tx_state <= TX_IDLE;
        endcase
    end
end

endmodule
`default_nettype wire
