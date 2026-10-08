`timescale 1ns / 1ps
`default_nettype none

// Clock-only board candidate: no HDMI reception or behavior changes.
module top_secondary_shared_clock (
    input wire clk_50m,
    input wire [3:0] sw, key_n,
    output wire [3:0] led,
    output wire [7:0] seg_data, seg_sel,
    output wire sd_clk, sd_mosi, sd_cs_n,
    input wire sd_miso,
    output wire hdmi1_clk_p, hdmi1_d2_p, hdmi1_d1_p, hdmi1_d0_p,
    input wire eth_rgmii_rx_clk, eth_rgmii_rx_ctl,
    input wire [3:0] eth_rgmii_rxd,
    output wire eth_rgmii_tx_clk, eth_rgmii_tx_ctl,
    output wire [3:0] eth_rgmii_txd,
    output wire eth_mdc,
    inout wire eth_mdio
);
top_secondary_main5e #(.SHARED_MEDIA_ETH_PLL(1)) u_terminal (
    .clk_50m(clk_50m), .sw(sw), .key_n(key_n), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel),
    .sd_clk(sd_clk), .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p),
    .eth_rgmii_rx_clk(eth_rgmii_rx_clk), .eth_rgmii_rx_ctl(eth_rgmii_rx_ctl),
    .eth_rgmii_rxd(eth_rgmii_rxd), .eth_rgmii_tx_clk(eth_rgmii_tx_clk),
    .eth_rgmii_tx_ctl(eth_rgmii_tx_ctl), .eth_rgmii_txd(eth_rgmii_txd),
    .eth_mdc(eth_mdc), .eth_mdio(eth_mdio)
);
endmodule
`default_nettype wire
