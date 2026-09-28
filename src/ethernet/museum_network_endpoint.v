`timescale 1ns / 1ps
`default_nettype none

module museum_network_endpoint #(
    parameter integer MBP1_DIAG = 0,
    parameter integer LIGHT_UDP = 0,
    parameter integer MBP1_EXTERNAL_STATUS = 0,
    parameter integer MBP1_CONTROL = 0
) (
    input  wire       clk_50m,
    input  wire       key_reset_n,
    input  wire [1:0] debug_sel,
    input  wire       eth_rgmii_rx_clk,
    input  wire       eth_rgmii_rx_ctl,
    input  wire [3:0] eth_rgmii_rxd,
    output wire       eth_rgmii_tx_clk,
    output wire       eth_rgmii_tx_ctl,
    output wire [3:0] eth_rgmii_txd,
    output wire       eth_mdc,
    inout  wire       eth_mdio,
    output wire [3:0] led,
    output wire [7:0] seg_data,
    output wire [7:0] seg_sel,
    input  wire [7:0] main_mode,
    input  wire [127:0] heartbeat_payload,
    input  wire [63:0] playback_payload,
    input  wire [95:0] display_payload,
    input  wire        display_changed,
    input  wire [127:0] diagnostic_payload,
    output wire command_valid,
    output wire [7:0] command_type,
    output wire [31:0] command_seq,
    output wire [63:0] command_payload,
    input  wire command_done,
    input  wire [7:0] command_result,
    output wire peer_alive,
    output wire network_clk,
    output wire network_reset
);

localparam [47:0] LOCAL_MAC = 48'h02_48_58_34_20_01;
localparam [31:0] LOCAL_IP  = 32'hC0_A8_0A_01;
localparam [31:0] DEST_IP   = 32'hC0_A8_0A_02;
localparam [15:0] UDP_PORT  = 16'd5000;
localparam [1:0]  TRI_SPEED = 2'b10;

wire pll_reset;
wire clk_125_mac;
wire clk_125_udp;
wire clk_125_90;
wire clk_12_5;
wire clk_1_25;
wire clk_25;
wire udp_clk;
wire udp_clk_generated;
// ponytail: the fixed-peer control plane uses 50 MHz; revisit only if packet rate requires 125 MHz.
assign udp_clk = LIGHT_UDP ? clk_50m : udp_clk_generated;
wire sys_reset = pll_reset | ~key_reset_n;

clk_gen_rst_gen #(.DEVICE("EG4")) u_clk_gen (
    .reset(1'b0),
    .clk_in(clk_50m),
    .rst_out(pll_reset),
    .clk_125_out0(clk_125_mac),
    .clk_125_out1(clk_125_udp),
    .clk_125_out2(clk_125_90),
    .clk_12_5_out(clk_12_5),
    .clk_1_25_out(clk_1_25),
    .clk_25_out(clk_25)
);

udp_clk_gen #(.DEVICE("EG4")) u_udp_clk_gen (
    .reset(1'b0),
    .tri_speed(TRI_SPEED),
    .clk_125_in(clk_125_udp),
    .clk_12_5_in(clk_12_5),
    .clk_1_25_in(clk_1_25),
    .udp_clk_out(udp_clk_generated)
);

wire rx_clk_0;
wire rx_clk_90;
rx_pll u_rx_pll (
    .refclk(eth_rgmii_rx_clk),
    .reset(1'b0),
    .clk0_out(rx_clk_0),
    .clk1_out(rx_clk_90)
);

wire rx_clk;
wire rx_clk_en;
wire [7:0] rx_data;
wire rx_valid;
wire rx_good;
wire rx_bad;
wire tx_clk;
wire tx_clk_en;
wire [7:0] tx_data;
wire tx_valid;
wire tx_ready;
wire tx_collision;
wire tx_retransmit;
wire inband_link;
wire [1:0] inband_speed;
wire inband_duplex;

reg [2:0] udp_reset_pipe = 3'b111;
reg [2:0] tx_reset_pipe = 3'b111;
reg [2:0] rx_reset_pipe = 3'b111;
always @(posedge udp_clk or posedge sys_reset) begin
    if (sys_reset) udp_reset_pipe <= 3'b111;
    else udp_reset_pipe <= {udp_reset_pipe[1:0], 1'b0};
end
always @(posedge tx_clk or posedge sys_reset) begin
    if (sys_reset) tx_reset_pipe <= 3'b111;
    else tx_reset_pipe <= {tx_reset_pipe[1:0], 1'b0};
end
always @(posedge rx_clk or posedge sys_reset) begin
    if (sys_reset) rx_reset_pipe <= 3'b111;
    else rx_reset_pipe <= {rx_reset_pipe[1:0], 1'b0};
end
wire udp_reset = udp_reset_pipe[2];
assign network_clk = udp_clk;
assign network_reset = udp_reset;
wire tx_reset = tx_reset_pipe[2];
wire rx_reset = rx_reset_pipe[2];

temac_block #(.DEVICE("EG4")) u_temac (
    .reset(sys_reset),
    .gtx_clk(clk_125_udp),
    .gtx_clk_90(clk_125_90),
    .rx_clk(rx_clk),
    .rx_clk_en(rx_clk_en),
    .rx_data(rx_data),
    .rx_data_valid(rx_valid),
    .rx_correct_frame(rx_good),
    .rx_error_frame(rx_bad),
    .rx_status_vector(),
    .rx_status_vld(),
    .tx_clk(tx_clk),
    .tx_clk_en(tx_clk_en),
    .tx_data(tx_data),
    .tx_data_en(tx_valid),
    .tx_rdy(tx_ready),
    .tx_stop(1'b0),
    .tx_collision(tx_collision),
    .tx_retransmit(tx_retransmit),
    .tx_ifg_val(8'd0),
    .tx_status_vector(),
    .tx_status_vld(),
    .tri_speed(),
    .pause_req(1'b0),
    .pause_val(16'd0),
    .pause_source_addr(48'h5A_F1_F2_F3_F4_F5),
    .unicast_address({LOCAL_MAC[7:0], LOCAL_MAC[15:8], LOCAL_MAC[23:16],
                      LOCAL_MAC[31:24], LOCAL_MAC[39:32], LOCAL_MAC[47:40]}),
    .s_axi_aclk(clk_50m),
    .s_axi_awaddr(8'd0), .s_axi_awvalid(1'b0), .s_axi_awready(),
    .s_axi_wdata(32'd0), .s_axi_wvalid(1'b0), .s_axi_wready(),
    .s_axi_bresp(), .s_axi_bvalid(), .s_axi_bready(1'b1),
    .s_axi_araddr(8'd0), .s_axi_arvalid(1'b0), .s_axi_arready(),
    .s_axi_rdata(), .s_axi_rresp(), .s_axi_rvalid(), .s_axi_rready(1'b1),
    .mac_cfg_vector({1'b0, 2'b00, TRI_SPEED, 8'b00000010, 7'b0000010}),
    .rgmii_txd(eth_rgmii_txd),
    .rgmii_tx_ctl(eth_rgmii_tx_ctl),
    .rgmii_txc(eth_rgmii_tx_clk),
    .rgmii_rxd(eth_rgmii_rxd),
    .rgmii_rx_ctl(eth_rgmii_rx_ctl),
    .rgmii_rxc(rx_clk_90),
    .inband_link_status(inband_link),
    .inband_clock_speed(inband_speed),
    .inband_duplex_status(inband_duplex),
    .mdio_i(1'b0), .mdio_o(), .mdio_oen(), .mdio_clk()
);

wire temac_tx_ready;
wire temac_tx_valid;
wire [7:0] temac_tx_data;
wire temac_tx_sof;
wire temac_tx_eof;
wire temac_rx_ready;
wire temac_rx_valid_n;
wire [7:0] temac_rx_data;
wire temac_rx_sof;
wire temac_rx_eof;

tx_client_fifo #(.DEVICE("EG4")) u_tx_fifo (
    .rd_clk(tx_clk), .rd_sreset(tx_reset), .rd_enable(tx_clk_en),
    .tx_data(tx_data), .tx_data_valid(tx_valid), .tx_ack(tx_ready),
    .tx_collision(tx_collision), .tx_retransmit(tx_retransmit), .overflow(),
    .wr_clk(udp_clk), .wr_sreset(udp_reset), .wr_data(temac_tx_data),
    .wr_sof_n(temac_tx_sof), .wr_eof_n(temac_tx_eof),
    .wr_src_rdy_n(temac_tx_valid), .wr_dst_rdy_n(temac_tx_ready), .wr_fifo_status()
);

rx_client_fifo #(.DEVICE("EG4")) u_rx_fifo (
    .wr_clk(rx_clk), .wr_enable(rx_clk_en), .wr_sreset(rx_reset),
    .rx_data(rx_data), .rx_data_valid(rx_valid), .rx_good_frame(rx_good),
    .rx_bad_frame(rx_bad), .overflow(),
    .rd_clk(udp_clk), .rd_sreset(udp_reset), .rd_data_out(temac_rx_data),
    .rd_sof_n(temac_rx_sof), .rd_eof_n(temac_rx_eof),
    .rd_src_rdy_n(temac_rx_valid_n), .rd_dst_rdy_n(temac_rx_ready), .rx_fifo_status()
);

wire udp_tx_ready;
wire app_tx_ack;
wire app_tx_request;
wire app_tx_valid;
wire [7:0] app_tx_data;
wire [15:0] app_tx_length;
wire app_rx_valid;
wire [7:0] app_rx_data;
wire [15:0] app_rx_length;
wire [15:0] app_rx_port;
wire ip_rx_error;
wire arp_error;
wire phy_link = phy_status[10];

wire [7:0] endpoint_mode = MBP1_EXTERNAL_STATUS ? main_mode : 8'd1;
wire [127:0] endpoint_heartbeat = MBP1_EXTERNAL_STATUS ? heartbeat_payload : {8'd1, 120'd0};
wire [63:0] endpoint_playback = MBP1_EXTERNAL_STATUS ? playback_payload : 64'd0;
wire [95:0] endpoint_display = MBP1_EXTERNAL_STATUS ? display_payload : 96'd0;
wire [127:0] endpoint_diagnostic;
generate if (MBP1_DIAG) begin : g_mbp1
    reg [31:0] free_run = 32'd0;
    reg [31:0] boot_id = 32'h500b0001;
    wire [15:0] mbp_crc_errors, mbp_drops, mbp_retries;
    always @(posedge clk_50m) begin
        free_run <= free_run + 32'd1;
        if (sys_reset) boot_id <= free_run ^ 32'h500b0001;
    end
    assign endpoint_diagnostic = MBP1_EXTERNAL_STATUS ?
                                 {{7'd0, phy_link},
                                  inband_speed == 2'b10 ? 8'd3 :
                                  inband_speed == 2'b01 ? 8'd2 : 8'd1,
                                  inband_duplex ? 8'd2 : 8'd1,
                                  diagnostic_payload[103:64], mbp_crc_errors,
                                  mbp_drops, mbp_retries, 16'd0} :
                                 {{7'd0, phy_link}, 8'd3, 8'd2,
                                    40'd0, mbp_crc_errors, mbp_drops,
                                    mbp_retries, 16'd0};
    mbp1_main_endpoint #(.CLOCKS_PER_MS(LIGHT_UDP ? 50000 : 125000),
                          .ENABLE_CONTROL(MBP1_CONTROL),
                          .ENABLE_PLAYBACK(MBP1_EXTERNAL_STATUS),
                          .HOLD_TX_FIELDS(!MBP1_EXTERNAL_STATUS)) u_mbp1 (
        .clk(udp_clk), .rst(udp_reset),
        .rx_data(app_rx_data), .rx_valid(app_rx_valid), .rx_length(app_rx_length),
        .tx_ready(udp_tx_ready), .tx_ack(app_tx_ack),
        .tx_request(app_tx_request), .tx_data(app_tx_data),
        .tx_valid(app_tx_valid), .tx_length(app_tx_length),
        .local_boot_id(boot_id), .phy_link(phy_link), .main_mode(endpoint_mode),
        .heartbeat_payload(endpoint_heartbeat), .display_payload(endpoint_display),
        .display_changed(MBP1_EXTERNAL_STATUS && display_changed),
        .playback_payload(endpoint_playback),
        .diagnostic_payload(endpoint_diagnostic),
        .command_valid(command_valid), .command_type(command_type),
        .command_seq(command_seq), .command_payload(command_payload),
        .command_done(MBP1_CONTROL ? command_done : 1'b0),
        .command_result(MBP1_CONTROL ? command_result : 8'd0),
        .peer_alive(peer_alive), .crc_error_count(mbp_crc_errors),
        .drop_count(mbp_drops), .retry_count(mbp_retries)
    );
end else begin : g_echo
    assign command_valid = 1'b0;
    assign command_type = 8'd0;
    assign command_seq = 32'd0;
    assign command_payload = 64'd0;
    assign peer_alive = 1'b0;
    assign endpoint_diagnostic = 128'd0;
    udp_echo_buffer u_echo (
        .clk(udp_clk), .rst(udp_reset),
        .rx_data(app_rx_data), .rx_valid(app_rx_valid), .rx_length(app_rx_length),
        .tx_ready(udp_tx_ready), .tx_ack(app_tx_ack),
        .tx_request(app_tx_request), .tx_data(app_tx_data),
        .tx_valid(app_tx_valid), .tx_length(app_tx_length)
    );
end endgenerate

generate if (LIGHT_UDP) begin : g_light_udp
mbp1_fixed_udp u_udp_stack (
    .clk(udp_clk), .rst(udp_reset),
    .mac_rx_data(temac_rx_data), .mac_rx_valid(~temac_rx_valid_n),
    .mac_rx_sof_n(temac_rx_sof), .mac_rx_eof_n(temac_rx_eof),
    .mac_rx_ready_n(temac_rx_ready),
    .mac_tx_data(temac_tx_data), .mac_tx_valid_n(temac_tx_valid),
    .mac_tx_sof_n(temac_tx_sof), .mac_tx_eof_n(temac_tx_eof),
    .mac_tx_ready_n(temac_tx_ready),
    .app_rx_data(app_rx_data), .app_rx_valid(app_rx_valid),
    .app_rx_length(app_rx_length),
    .app_tx_request(app_tx_request), .app_tx_data(app_tx_data),
    .app_tx_valid(app_tx_valid), .app_tx_length(app_tx_length),
    .app_tx_ready(udp_tx_ready), .app_tx_ack(app_tx_ack)
);
assign app_rx_port = UDP_PORT;
assign ip_rx_error = 1'b0;
assign arp_error = 1'b0;
end else begin : g_official_udp
udp_ip_protocol_stack #(
    .DEVICE("EG4"),
    .LOCAL_UDP_PORT_NUM(UDP_PORT),
    .LOCAL_IP_ADDRESS(LOCAL_IP),
    .LOCAL_MAC_ADDRESS(LOCAL_MAC)
) u_udp_stack (
    .udp_rx_clk(udp_clk), .udp_tx_clk(udp_clk), .reset(udp_reset),
    .input_local_udp_port_num(UDP_PORT), .input_local_udp_port_num_valid(1'b0),
    .udp2app_tx_ready(udp_tx_ready), .udp2app_tx_ack(app_tx_ack),
    .app_tx_request(app_tx_request), .app_tx_data_valid(app_tx_valid),
    .app_tx_data(app_tx_data), .app_tx_data_length(app_tx_length),
    .app_rx_data_valid(app_rx_valid), .app_rx_data(app_rx_data),
    .app_rx_data_length(app_rx_length), .app_rx_port_num(app_rx_port),
    .app_tx_dst_port(UDP_PORT), .ip_tx_dst_address(DEST_IP),
    .input_local_ip_address(LOCAL_IP), .input_local_ip_address_valid(1'b0),
    .temac_rx_ready(temac_rx_ready), .temac_rx_valid(~temac_rx_valid_n),
    .temac_rx_data(temac_rx_data), .temac_rx_sof(temac_rx_sof), .temac_rx_eof(temac_rx_eof),
    .temac_tx_ready(temac_tx_ready), .temac_tx_valid(temac_tx_valid),
    .temac_tx_data(temac_tx_data), .temac_tx_sof(temac_tx_sof), .temac_tx_eof(temac_tx_eof),
    .ip_rx_error(ip_rx_error), .arp_request_no_reply_error(arp_error)
);
end endgenerate

wire mdio_drive_low;
wire [15:0] phy_id1;
wire [15:0] phy_id2;
wire [15:0] phy_status;
wire mdio_valid;
assign eth_mdio = mdio_drive_low ? 1'b0 : 1'bz;

mdio_clause22_monitor u_mdio (
    .clk(clk_50m), .rst(sys_reset), .mdio_i(eth_mdio),
    .mdc(eth_mdc), .mdio_drive_low(mdio_drive_low),
    .phy_id1(phy_id1), .phy_id2(phy_id2), .phy_status(phy_status),
    .sample_valid(mdio_valid)
);

reg [25:0] heartbeat_count;
reg rx_valid_d;
reg rx_toggle;
reg tx_toggle;
reg [7:0] rx_packet_count;
reg [7:0] tx_packet_count;
always @(posedge udp_clk or posedge udp_reset) begin
    if (udp_reset) begin
        rx_valid_d <= 1'b0;
        rx_toggle <= 1'b0;
        tx_toggle <= 1'b0;
        rx_packet_count <= 8'd0;
        tx_packet_count <= 8'd0;
    end else begin
        rx_valid_d <= app_rx_valid;
        if (!rx_valid_d && app_rx_valid) begin
            rx_toggle <= ~rx_toggle;
            rx_packet_count <= rx_packet_count + 8'd1;
        end
        if (app_tx_ack) begin
            tx_toggle <= ~tx_toggle;
            tx_packet_count <= tx_packet_count + 8'd1;
        end
    end
end

always @(posedge clk_50m or posedge sys_reset) begin
    if (sys_reset)
        heartbeat_count <= 26'd0;
    else
        heartbeat_count <= heartbeat_count + 26'd1;
end

assign led = ~{tx_toggle, rx_toggle, phy_link, heartbeat_count[25]};

reg [15:0] display_value;
always @(*) begin
    case (debug_sel)
        2'b00: display_value = phy_id1;
        2'b01: display_value = phy_id2;
        2'b10: display_value = phy_status;
        default: display_value = {rx_packet_count, tx_packet_count};
    endcase
end

seg_hex_display u_seg (
    .clk(clk_50m), .rst_n(~sys_reset), .value(display_value),
    .seg_data(seg_data), .seg_sel(seg_sel)
);

endmodule

`default_nettype wire
