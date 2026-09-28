`timescale 1ns / 1ps
`default_nettype none

// Only actual board pins reach bitgen; all diagnostic application signals
// remain inside the test design.
module top_secondary_main5e_netdiag_board (
    input wire clk_50m,
    input wire key_reset_n,
    input wire eth_rgmii_rx_clk,
    input wire eth_rgmii_rx_ctl,
    input wire [3:0] eth_rgmii_rxd,
    output wire eth_rgmii_tx_clk,
    output wire eth_rgmii_tx_ctl,
    output wire [3:0] eth_rgmii_txd,
    output wire eth_mdc,
    inout wire eth_mdio,
    output wire [3:0] led,
    output wire [7:0] seg_data,
    output wire [7:0] seg_sel
);
top_secondary_main5e_netdiag u_diag (
    .clk_50m(clk_50m), .key_reset_n(key_reset_n), .debug_sel(2'b11),
    .eth_rgmii_rx_clk(eth_rgmii_rx_clk),
    .eth_rgmii_rx_ctl(eth_rgmii_rx_ctl), .eth_rgmii_rxd(eth_rgmii_rxd),
    .eth_rgmii_tx_clk(eth_rgmii_tx_clk),
    .eth_rgmii_tx_ctl(eth_rgmii_tx_ctl), .eth_rgmii_txd(eth_rgmii_txd),
    .eth_mdc(eth_mdc), .eth_mdio(eth_mdio), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel),
    .main_mode(8'd0), .heartbeat_payload(128'd0),
    .playback_payload(64'd0), .display_payload(96'd0),
    .display_changed(1'b0), .diagnostic_payload(128'd0),
    .command_done(1'b0), .command_result(8'd0),
    .command_valid(), .command_type(), .command_seq(),
    .command_payload(), .peer_alive(), .network_clk(), .network_reset(),
    .client_control_request(1'b0), .client_control_type(8'd0),
    .client_control_payload(64'd0), .client_control_ready(),
    .client_control_done(), .client_control_result(),
    .client_heartbeat_pulse(), .client_heartbeat_data(),
    .client_display_pulse(), .client_display_data(),
    .client_diagnostic_pulse(), .client_diagnostic_data()
);
endmodule

`default_nettype wire
