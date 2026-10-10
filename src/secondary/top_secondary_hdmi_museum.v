`timescale 1ns / 1ps
`default_nettype none
// Integrated candidate: A receives PC HDMI, B is the only display output.
// External AV has priority. The original local terminal keeps running.
module top_secondary_hdmi_museum(
    input wire clk_50m,
    input wire [3:0] sw,key_n,
    output wire [3:0] led,
    output wire [7:0] seg_data,seg_sel,
    output wire sd_clk,sd_mosi,sd_cs_n,
    input wire sd_miso,
    input wire hdmi_a_clk_p,hdmi_a_d0_p,hdmi_a_d1_p,hdmi_a_d2_p,hdmi_a_scl,
    inout wire hdmi_a_sda,
    output wire hdmi_a_hpd,
    input wire hdmi_b_hpd,
    output wire hdmi_b_clk_p,hdmi_b_d0_p,hdmi_b_d1_p,hdmi_b_d2_p,
    input wire eth_rgmii_rx_clk,eth_rgmii_rx_ctl,
    input wire [3:0] eth_rgmii_rxd,
    output wire eth_rgmii_tx_clk,eth_rgmii_tx_ctl,
    output wire [3:0] eth_rgmii_txd,
    output wire eth_mdc,
    inout wire eth_mdio
);
wire local_pclk,local_sclk,local_ready,local_hs,local_vs,local_de;
wire [23:0] local_rgb;
wire application_clock;
// One explicit root GCLK feeds both application registers and PLL references;
// do not let an unbuffered PLL reference bypass the application clock tree.
EG_LOGIC_BUFG u_application_clock(.i(clk_50m),.o(application_clock));
top_secondary_main5e #(.SHARED_MEDIA_ETH_PLL(1),.EXTERNAL_HDMI_PHY(1)) u_terminal(
    .clk_50m(application_clock),.sw(sw),.key_n(key_n),.led(led),.seg_data(seg_data),.seg_sel(seg_sel),
    .sd_clk(sd_clk),.sd_mosi(sd_mosi),.sd_miso(sd_miso),.sd_cs_n(sd_cs_n),
    .hdmi1_clk_p(),.hdmi1_d0_p(),.hdmi1_d1_p(),.hdmi1_d2_p(),
    .local_video_clk(local_pclk),.local_serial_clk(local_sclk),.local_video_rst_n(local_ready),
    .local_hs(local_hs),.local_vs(local_vs),.local_de(local_de),.local_rgb(local_rgb),
    .eth_rgmii_rx_clk(eth_rgmii_rx_clk),.eth_rgmii_rx_ctl(eth_rgmii_rx_ctl),.eth_rgmii_rxd(eth_rgmii_rxd),
    .eth_rgmii_tx_clk(eth_rgmii_tx_clk),.eth_rgmii_tx_ctl(eth_rgmii_tx_ctl),.eth_rgmii_txd(eth_rgmii_txd),
    .eth_mdc(eth_mdc),.eth_mdio(eth_mdio));
wire external_sclk,external_ready,external_blank,rst_n;
wire [7:0] external_pairs,local_pairs;
top_secondary_hdmi_relay_diag #(.USE_OFFICIAL_EDID(1),.REQUIRE_SINK_HPD(0),.EXTERNAL_TRANSMITTER(1)) u_relay(
    .clk_50m(application_clock),.hdmi_b_clk_p(hdmi_a_clk_p),
    .hdmi_b_d0_p(hdmi_a_d0_p),.hdmi_b_d1_p(hdmi_a_d1_p),.hdmi_b_d2_p(hdmi_a_d2_p),
    .hdmi_b_scl(hdmi_a_scl),.hdmi_b_sda(hdmi_a_sda),.hdmi_b_hpd(hdmi_a_hpd),.hdmi_a_hpd(hdmi_b_hpd),
    .hdmi1_clk_p(),.hdmi1_d0_p(),.hdmi1_d1_p(),.hdmi1_d2_p(),.led(),.seg_data(),.seg_sel(),
    .relay_sclk(external_sclk),.relay_valid(external_ready),.relay_blank(external_blank),.relay_pairs(external_pairs),.application_rst_n(rst_n));
secondary_hdmi_local_pairs u_local(
    .pixel_clk(local_pclk),.serial_clk(local_sclk),.rst_n(local_ready),
    .hs(local_hs),.vs(local_vs),.de(local_de),.rgb(local_rgb),.pairs(local_pairs));
wire external_selected,output_muted;
secondary_hdmi_source_switch u_switch(
    .clk_50m(application_clock),.rst_n(rst_n),.local_ready(local_ready),.external_ready(external_ready),
    .local_blank(!local_de),.external_blank(external_blank),
    .local_sclk(local_sclk),.external_sclk(external_sclk),.local_pairs(local_pairs),.external_pairs(external_pairs),
    .external_selected(external_selected),.output_muted(output_muted),
    .serial_out({hdmi_b_clk_p,hdmi_b_d2_p,hdmi_b_d1_p,hdmi_b_d0_p}));
endmodule
`default_nettype wire
