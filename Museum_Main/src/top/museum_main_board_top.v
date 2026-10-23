`timescale 1ns/1ps
`default_nettype none
`ifndef MUSEUM_GUIDE_AUDIO
`define MUSEUM_GUIDE_AUDIO 0
`endif

// The same media entry remains authoritative; Ethernet adds status and, in
// MAIN-5D, validated frame-boundary display commands.
module museum_main_board_system #(
    parameter integer ENABLE_REMOTE_CONTROL = 1,
    parameter integer USE_FIXED_UDP = 1
) (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p, output wire hdmi1_ddc_scl, inout wire hdmi1_ddc_sda,
    input wire uart_rxd, output wire uart_txd,
    input wire eth_rgmii_rx_clk, input wire eth_rgmii_rx_ctl,
    input wire [3:0] eth_rgmii_rxd,
    output wire eth_rgmii_tx_clk, output wire eth_rgmii_tx_ctl,
    output wire [3:0] eth_rgmii_txd, output wire eth_mdc,
    inout wire eth_mdio
);

wire net_clk, net_rst;
wire [7:0] media_mode, net_mode;
wire [127:0] media_heartbeat, net_heartbeat;
wire [63:0] media_playback, net_playback;
wire [95:0] media_display, net_display;
wire media_display_changed;
wire [127:0] media_diagnostic, net_diagnostic;
wire net_command_valid, media_command_valid;
wire [7:0] net_command_type, media_command_type;
wire [31:0] net_command_seq;
wire [63:0] net_command_payload, media_command_payload;
wire net_command_done, media_command_done;
wire [7:0] net_command_result, media_command_result;
wire peer_alive;
wire secondary_audio_supported,secondary_muted_pulse,guide_audio_allowed;
wire [3:0] net_led;
wire [7:0] net_seg_data, net_seg_sel;

museum_display_subsystem #(
    .ENABLE_LOCAL_CONTROLS(1),
    .ENABLE_REMOTE_CONTROL(ENABLE_REMOTE_CONTROL),
    .ENABLE_GUIDE_AUDIO(`MUSEUM_GUIDE_AUDIO&&USE_FIXED_UDP)
) u_media (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel),
    .sd_clk(sd_clk), .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p),
    .hdmi1_ddc_scl(hdmi1_ddc_scl), .hdmi1_ddc_sda(hdmi1_ddc_sda),
    .uart_rxd(uart_rxd), .uart_txd(uart_txd),
    .remote_command_valid(media_command_valid),
    .secondary_audio_supported(secondary_audio_supported),.secondary_muted_pulse(secondary_muted_pulse),
    .guide_audio_allowed(guide_audio_allowed),
    .remote_command_type(media_command_type),
    .remote_command_payload(media_command_payload),
    .remote_command_done(media_command_done),
    .remote_command_result(media_command_result),
    .main5_mode(media_mode), .main5_heartbeat(media_heartbeat),
    .main5_playback(media_playback), .main5_display(media_display),
    .main5_display_changed(media_display_changed),
    .main5_diagnostic(media_diagnostic)
);

generate if (USE_FIXED_UDP) begin : g_same_clock
    assign net_mode = media_mode;
    assign net_heartbeat = media_heartbeat;
    assign net_playback = media_playback;
    assign net_display = media_display;
    assign net_diagnostic = media_diagnostic;
    assign media_command_valid = net_command_valid;
    assign media_command_type = net_command_type;
    assign media_command_payload = net_command_payload;
    assign net_command_done = media_command_done;
    assign net_command_result = media_command_result;
end else begin : g_clock_bridge
    mbp1_media_bridge u_bridge (
        .net_clk(net_clk), .media_clk(clk_50m), .rst(net_rst),
        .media_mode(media_mode), .media_heartbeat(media_heartbeat),
        .media_playback(media_playback), .media_display(media_display),
        .media_diagnostic(media_diagnostic),
        .net_mode(net_mode), .net_heartbeat(net_heartbeat),
        .net_playback(net_playback), .net_display(net_display),
        .net_diagnostic(net_diagnostic),
        .net_command_valid(net_command_valid),
        .net_command_type(net_command_type),
        .net_command_payload(net_command_payload),
        .net_command_done(net_command_done),
        .net_command_result(net_command_result),
        .media_command_valid(media_command_valid),
        .media_command_type(media_command_type),
        .media_command_payload(media_command_payload),
        .media_command_done(media_command_done),
        .media_command_result(media_command_result)
    );
end endgenerate

museum_network_endpoint #(
    .MBP1_DIAG(1), .LIGHT_UDP(USE_FIXED_UDP), .MBP1_EXTERNAL_STATUS(1),
    .MBP1_CONTROL(ENABLE_REMOTE_CONTROL),.ENABLE_GUIDE_AUDIO(`MUSEUM_GUIDE_AUDIO&&USE_FIXED_UDP)
) u_net (
    .clk_50m(clk_50m), .key_reset_n(1'b1), .debug_sel(2'd0),
    .eth_rgmii_rx_clk(eth_rgmii_rx_clk),
    .eth_rgmii_rx_ctl(eth_rgmii_rx_ctl), .eth_rgmii_rxd(eth_rgmii_rxd),
    .eth_rgmii_tx_clk(eth_rgmii_tx_clk),
    .eth_rgmii_tx_ctl(eth_rgmii_tx_ctl), .eth_rgmii_txd(eth_rgmii_txd),
    .eth_mdc(eth_mdc), .eth_mdio(eth_mdio),
    .led(net_led), .seg_data(net_seg_data), .seg_sel(net_seg_sel),
    .main_mode(net_mode), .heartbeat_payload(net_heartbeat),
    .playback_payload(net_playback), .display_payload(net_display),
    .diagnostic_payload(net_diagnostic),
    .display_changed(USE_FIXED_UDP ? media_display_changed : 1'b0),
    .command_valid(net_command_valid), .command_type(net_command_type),
    .command_seq(net_command_seq), .command_payload(net_command_payload),
    .command_done(net_command_done), .command_result(net_command_result),
    .guide_allowed(guide_audio_allowed),.peer_audio_supported(secondary_audio_supported),.guide_muted_pulse(secondary_muted_pulse),
    .peer_alive(peer_alive), .network_clk(net_clk), .network_reset(net_rst)
);
endmodule

module dual_fpga_museum_terminal_main_board (
    input wire clk_50m, input wire [3:0] key_n, input wire [3:0] sw,
    output wire [3:0] led, output wire [7:0] seg_data, output wire [7:0] seg_sel,
    output wire sd_clk, output wire sd_mosi, input wire sd_miso, output wire sd_cs_n,
    output wire vga_hs, output wire vga_vs, output wire [11:0] vga_d,
    output wire hdmi1_clk_p, output wire hdmi1_d2_p, output wire hdmi1_d1_p,
    output wire hdmi1_d0_p, output wire hdmi1_ddc_scl, inout wire hdmi1_ddc_sda,
    input wire uart_rxd, output wire uart_txd,
    input wire eth_rgmii_rx_clk, input wire eth_rgmii_rx_ctl,
    input wire [3:0] eth_rgmii_rxd,
    output wire eth_rgmii_tx_clk, output wire eth_rgmii_tx_ctl,
    output wire [3:0] eth_rgmii_txd, output wire eth_mdc,
    inout wire eth_mdio
);
museum_main_board_system u_system (
    .clk_50m(clk_50m), .key_n(key_n), .sw(sw), .led(led),
    .seg_data(seg_data), .seg_sel(seg_sel),
    .sd_clk(sd_clk), .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_d(vga_d),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p),
    .hdmi1_ddc_scl(hdmi1_ddc_scl), .hdmi1_ddc_sda(hdmi1_ddc_sda),
    .uart_rxd(uart_rxd), .uart_txd(uart_txd),
    .eth_rgmii_rx_clk(eth_rgmii_rx_clk),
    .eth_rgmii_rx_ctl(eth_rgmii_rx_ctl), .eth_rgmii_rxd(eth_rgmii_rxd),
    .eth_rgmii_tx_clk(eth_rgmii_tx_clk),
    .eth_rgmii_tx_ctl(eth_rgmii_tx_ctl), .eth_rgmii_txd(eth_rgmii_txd),
    .eth_mdc(eth_mdc), .eth_mdio(eth_mdio)
);
endmodule
`default_nettype wire
