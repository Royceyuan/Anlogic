`timescale 1ns / 1ps
`default_nettype none

module top_main5b_mbp1_diag (
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
top_main5a_ethernet_diag #(.MBP1_DIAG(1)) u_diag (
    .clk_50m(clk_50m), .key_reset_n(key_reset_n), .debug_sel(debug_sel),
    .eth_rgmii_rx_clk(eth_rgmii_rx_clk),
    .eth_rgmii_rx_ctl(eth_rgmii_rx_ctl), .eth_rgmii_rxd(eth_rgmii_rxd),
    .eth_rgmii_tx_clk(eth_rgmii_tx_clk),
    .eth_rgmii_tx_ctl(eth_rgmii_tx_ctl), .eth_rgmii_txd(eth_rgmii_txd),
    .eth_mdc(eth_mdc), .eth_mdio(eth_mdio), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel)
);
endmodule
`default_nettype wire
