`timescale 1ns / 1ps
`default_nettype none

// Main-board telemetry drives the 720p display; local keys send absolute
// display and viewport requests over MBP1.
module top_secondary_main5e (
    input wire clk_50m,
    input wire [3:0] sw,
    input wire [3:0] key_n,
    output wire [3:0] led,
    output wire [7:0] seg_data,
    output wire [7:0] seg_sel,
    output wire sd_clk,
    output wire sd_mosi,
    input wire sd_miso,
    output wire sd_cs_n,
    output wire hdmi1_clk_p,
    output wire hdmi1_d2_p,
    output wire hdmi1_d1_p,
    output wire hdmi1_d0_p,
    input wire eth_rgmii_rx_clk,
    input wire eth_rgmii_rx_ctl,
    input wire [3:0] eth_rgmii_rxd,
    output wire eth_rgmii_tx_clk,
    output wire eth_rgmii_tx_ctl,
    output wire [3:0] eth_rgmii_txd,
    output wire eth_mdc,
    inout wire eth_mdio
);
wire network_reset;
wire heartbeat_pulse;
wire [127:0] heartbeat_data;
wire display_pulse, diagnostic_pulse;
wire [95:0] display_data;
wire [127:0] diagnostic_data;
wire cmd_valid;
wire [7:0] cmd_type, cmd_artifact_id, cmd_mode, cmd_lecture_phase;
wire cmd_emergency_active;
wire [2:0] cmd_result;
wire control_request, control_ready, control_done;
wire peer_alive, manual_supported;
wire [7:0] control_type, control_result;
wire [63:0] control_payload;
wire manual_mode, manual_next;
wire [3:0] help_switches;
wire [7:0] media_seg_data, media_seg_sel;
assign seg_data = media_seg_data;
assign seg_sel = media_seg_sel;

top_secondary_main5e_netdiag #(.SECONDARY_CLIENT(1)) u_network (
    .clk_50m(clk_50m), .key_reset_n(1'b1), .debug_sel(2'b11),
    .eth_rgmii_rx_clk(eth_rgmii_rx_clk),
    .eth_rgmii_rx_ctl(eth_rgmii_rx_ctl), .eth_rgmii_rxd(eth_rgmii_rxd),
    .eth_rgmii_tx_clk(eth_rgmii_tx_clk),
    .eth_rgmii_tx_ctl(eth_rgmii_tx_ctl), .eth_rgmii_txd(eth_rgmii_txd),
    .eth_mdc(eth_mdc), .eth_mdio(eth_mdio),
    .led(), .seg_data(), .seg_sel(),
    .main_mode(8'd0), .heartbeat_payload(128'd0),
    .playback_payload(64'd0), .display_payload(96'd0),
    .display_changed(1'b0), .diagnostic_payload(128'd0),
    .command_done(1'b0), .command_result(8'd0),
    .command_valid(), .command_type(), .command_seq(),
    .command_payload(), .peer_alive(peer_alive), .network_clk(),
    .network_reset(network_reset),
    .client_heartbeat_pulse(heartbeat_pulse),
    .client_heartbeat_data(heartbeat_data),
    .client_display_pulse(display_pulse),
    .client_display_data(display_data),
    .client_diagnostic_pulse(diagnostic_pulse),
    .client_diagnostic_data(diagnostic_data),
    .client_control_request(control_request),
    .client_control_type(control_type),
    .client_control_payload(control_payload),
    .client_control_ready(control_ready),
    .client_manual_supported(manual_supported),
    .client_control_done(control_done),
    .client_control_result(control_result)
);
secondary_main5e_keys u_keys (
    .clk(clk_50m), .rst(network_reset), .sw(sw), .key_n(key_n),
    .heartbeat_pulse(heartbeat_pulse), .heartbeat_data(heartbeat_data),
    .display_pulse(display_pulse), .display_data(display_data),
    .control_ready(control_ready), .control_request(control_request),
    .peer_alive(peer_alive), .manual_supported(manual_supported),
    .control_type(control_type), .control_payload(control_payload),
    .manual_mode(manual_mode), .manual_next(manual_next),
    .help_switches(help_switches)
);
secondary_main5e_status_adapter u_status_adapter (
    .clk(clk_50m), .rst(network_reset),
    .heartbeat_pulse(heartbeat_pulse), .heartbeat_data(heartbeat_data),
    .cmd_valid(cmd_valid), .cmd_type(cmd_type),
    .cmd_artifact_id(cmd_artifact_id), .cmd_mode(cmd_mode),
    .cmd_lecture_phase(cmd_lecture_phase),
    .cmd_emergency_active(cmd_emergency_active)
);

top_v66 #(
    .VIDEO_W(1280), .VIDEO_H(720), .SOURCE_W(1280), .SOURCE_H(720),
    .VIDEO_BURST_WORDS(128), .VIDEO_WRITE_BURST_WORDS(16),
    .VIDEO_READ_BURST_WORDS(128), .VIDEO_MODE_1280(1),
    .ADAPTIVE_BMP(1), .ADAPTIVE_BMP_MAX_WIDTH(1280),
    .ADAPTIVE_BMP_MAX_HEIGHT(720),
    .ADAPTIVE_BACKGROUND_RGB565(16'h18E3), .ADAPTIVE_BLOCK_WRITER(0),
    .ENABLE_OSD(0), .ENABLE_FADE(1), .VIDEO_SEQUENCE(0), .VIDEO_BIN(0),
    .MULTI_IMAGE_BMP(1), .MULTI_FRAME_PRELOAD(1), .VIDEO_FRAME_COUNT(5),
    .FORCE_SEQUENCE_AUTO(1), .AUTO_PERIOD_CYCLES(250_000_000),
    .LINEBUF_SCALE(0), .SECONDARY_STREAMING(1),
    .SECONDARY_ENGINEERING(0), .SECONDARY_HELP(1),
    .RESOURCE_OPT_CONSTANT_MULT(1),
    .ENABLE_SUBTITLE(0), .ENABLE_AUDIO_VISUALIZER(0),
    .ENABLE_MUSEUM_OVERVIEW(0), .ENABLE_MUSEUM_LECTURE(0),
    .ENABLE_SECONDARY(1),
    .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_FRONT(5), .V_SYNC(5), .V_BACK(20)
) u_display (
    .clk_50m(clk_50m), .key_n(4'b1111), .sw(4'b0001),
    .led(led), .seg_data(media_seg_data), .seg_sel(media_seg_sel),
    .sd_clk(sd_clk), .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(), .vga_vs(), .vga_d(),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p),
    .hdmi1_ddc_scl(), .hdmi1_ddc_sda(),
    .uart_rxd(1'b1), .uart_txd(),
    .secondary_cmd_valid(cmd_valid), .secondary_cmd_type(cmd_type),
    .secondary_cmd_artifact_id(cmd_artifact_id),
    .secondary_cmd_confirmed(1'b0), .secondary_cmd_mode(cmd_mode),
    .secondary_cmd_lecture_phase(cmd_lecture_phase),
    .secondary_cmd_lecture_reason(8'd0),
    .secondary_cmd_emergency_id(16'd0),
    .secondary_cmd_route_id(8'd0),
    .secondary_cmd_emergency_active(cmd_emergency_active),
    .secondary_cmd_result(cmd_result),
    .secondary_manual_mode(manual_mode),
    .secondary_manual_next(manual_next),
    .secondary_help_switches(help_switches),
    .secondary_eng_enable(1'b0),
    .secondary_eng_link(1'b0),
    .secondary_eng_heartbeat(heartbeat_data),
    .secondary_eng_display(display_data),
    .secondary_eng_diagnostic(diagnostic_data),
    .secondary_eng_result(control_result)
);
endmodule

`default_nettype wire
