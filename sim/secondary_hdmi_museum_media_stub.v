`timescale 1ns / 1ps
// Only for HDMI integration simulation. Real media/network are independently
// regressed; this model proves the top does not reset/stop them on source loss.
module top_secondary_main5e #(
    parameter SHARED_MEDIA_ETH_PLL=0,EXTERNAL_HDMI_PHY=0
)(
    input wire clk_50m,
    input wire [3:0] sw,key_n,
    output wire [3:0] led,
    output wire [7:0] seg_data,seg_sel,
    output wire sd_clk,sd_mosi,sd_cs_n,
    input wire sd_miso,
    output wire hdmi1_clk_p,hdmi1_d0_p,hdmi1_d1_p,hdmi1_d2_p,
    output wire local_video_clk,local_serial_clk,local_video_rst_n,
    output wire local_hs,local_vs,local_de,
    output wire [23:0] local_rgb,
    output wire [7:0] pc_artifact,pc_state,pc_phase,
    input wire eth_rgmii_rx_clk,eth_rgmii_rx_ctl,
    input wire [3:0] eth_rgmii_rxd,
    output wire eth_rgmii_tx_clk,eth_rgmii_tx_ctl,
    output wire [3:0] eth_rgmii_txd,
    output wire eth_mdc,
    inout wire eth_mdio
);
reg pixel_clk=0,serial_clk=0;
always #6.666667 pixel_clk=!pixel_clk;
always #1.333333 serial_clk=!serial_clk;
assign local_video_clk=pixel_clk;
assign local_serial_clk=serial_clk;
assign local_video_rst_n=1;
assign local_hs=0;assign local_vs=0;assign local_de=0;assign local_rgb=24'h123456;
assign pc_artifact=0;assign pc_state=8'h03;assign pc_phase=0;
assign led=0;assign seg_data=0;assign seg_sel=0;
assign {sd_clk,sd_mosi,sd_cs_n}=3'b001;
assign {hdmi1_clk_p,hdmi1_d0_p,hdmi1_d1_p,hdmi1_d2_p}=0;
assign eth_rgmii_tx_clk=clk_50m;assign eth_rgmii_tx_ctl=0;assign eth_rgmii_txd=0;assign eth_mdc=0;assign eth_mdio=1'bz;
integer background_ticks=0;
always @(posedge clk_50m) background_ticks=background_ticks+1;
endmodule
