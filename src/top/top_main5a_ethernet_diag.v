`timescale 1ns / 1ps
`default_nettype none

module top_main5a_ethernet_diag (
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
    output wire [7:0] seg_sel
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
    .udp_clk_out(udp_clk)
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

temac_block #(.DEVICE("EG4")) u_temac (
    .reset(1'b0),
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
    .rd_clk(tx_clk), .rd_sreset(1'b0), .rd_enable(tx_clk_en),
    .tx_data(tx_data), .tx_data_valid(tx_valid), .tx_ack(tx_ready),
    .tx_collision(tx_collision), .tx_retransmit(tx_retransmit), .overflow(),
    .wr_clk(udp_clk), .wr_sreset(1'b0), .wr_data(temac_tx_data),
    .wr_sof_n(temac_tx_sof), .wr_eof_n(temac_tx_eof),
    .wr_src_rdy_n(temac_tx_valid), .wr_dst_rdy_n(temac_tx_ready), .wr_fifo_status()
);

rx_client_fifo #(.DEVICE("EG4")) u_rx_fifo (
    .wr_clk(rx_clk), .wr_enable(rx_clk_en), .wr_sreset(1'b0),
    .rx_data(rx_data), .rx_data_valid(rx_valid), .rx_good_frame(rx_good),
    .rx_bad_frame(rx_bad), .overflow(),
    .rd_clk(udp_clk), .rd_sreset(1'b0), .rd_data_out(temac_rx_data),
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

udp_echo_buffer u_echo (
    .clk(udp_clk), .rst(sys_reset),
    .rx_data(app_rx_data), .rx_valid(app_rx_valid), .rx_length(app_rx_length),
    .tx_ready(udp_tx_ready), .tx_ack(app_tx_ack),
    .tx_request(app_tx_request), .tx_data(app_tx_data),
    .tx_valid(app_tx_valid), .tx_length(app_tx_length)
);

udp_ip_protocol_stack #(
    .DEVICE("EG4"),
    .LOCAL_UDP_PORT_NUM(UDP_PORT),
    .LOCAL_IP_ADDRESS(LOCAL_IP),
    .LOCAL_MAC_ADDRESS(LOCAL_MAC)
) u_udp_stack (
    .udp_rx_clk(udp_clk), .udp_tx_clk(udp_clk), .reset(1'b0),
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
always @(posedge udp_clk or posedge sys_reset) begin
    if (sys_reset) begin
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

wire phy_link = phy_status[10];
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
