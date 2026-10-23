`timescale 1ns/1ps
`default_nettype none
`ifndef OFFLINE_AV_ENABLE
`define OFFLINE_AV_ENABLE 0
`endif
// Stage 1 candidate: network-controlled MVID2 video. Audio remains intentionally
// disconnected until CRC-staged PCM, subtitle RAM and sound leases are integrated.
module top_secondary_offline_av(
    input wire clk_50m,
    input wire [3:0] sw,key_n,
    output wire [3:0] led,
    output wire [7:0] seg_data,seg_sel,
    output wire sd_clk,
    inout wire sd_cmd,
    inout wire [3:0] sd_dat,
    output wire hdmi_b_clk_p,hdmi_b_d0_p,hdmi_b_d1_p,hdmi_b_d2_p,
    input wire eth_rgmii_rx_clk,eth_rgmii_rx_ctl,
    input wire [3:0] eth_rgmii_rxd,
    output wire eth_rgmii_tx_clk,eth_rgmii_tx_ctl,
    output wire [3:0] eth_rgmii_txd,
    output wire eth_mdc,
    inout wire eth_mdio
);
wire application_clk,network_reset,peer_alive,manual_supported;
EG_LOGIC_BUFG u_clock(.i(clk_50m),.o(application_clk));
wire heartbeat_pulse,display_pulse,control_request,control_ready;
wire [127:0] heartbeat_data;
wire [95:0] display_data;
wire [31:0] peer_session;
wire [7:0] control_type;
wire [63:0] control_payload;
wire [3:0] help_switches;
wire guide_lease_valid,audio_supported,output_muted,guide_audio_enable,show_emergency;
top_secondary_main5e_netdiag #(.SECONDARY_CLIENT(1),.OFFLINE_AUDIO(`OFFLINE_AV_ENABLE)) u_network(
    .clk_50m(application_clk),.key_reset_n(1'b1),.debug_sel(2'b11),
    .shared_eth_clk(1'b0),.shared_eth_clk_90(1'b0),.shared_clock_locked(1'b0),
    .eth_rgmii_rx_clk(eth_rgmii_rx_clk),.eth_rgmii_rx_ctl(eth_rgmii_rx_ctl),.eth_rgmii_rxd(eth_rgmii_rxd),
    .eth_rgmii_tx_clk(eth_rgmii_tx_clk),.eth_rgmii_tx_ctl(eth_rgmii_tx_ctl),.eth_rgmii_txd(eth_rgmii_txd),
    .eth_mdc(eth_mdc),.eth_mdio(eth_mdio),.led(),.seg_data(),.seg_sel(),
    .main_mode(8'd0),.heartbeat_payload(128'd0),.playback_payload(64'd0),.display_payload(96'd0),
    .display_changed(1'b0),.diagnostic_payload(128'd0),.command_done(1'b0),.command_result(8'd0),
    .command_valid(),.command_type(),.command_seq(),.command_payload(),
    .peer_alive(peer_alive),.client_peer_session(peer_session),.network_clk(),.network_reset(network_reset),
    .client_heartbeat_pulse(heartbeat_pulse),.client_heartbeat_data(heartbeat_data),
    .client_display_pulse(display_pulse),.client_display_data(display_data),
    .client_diagnostic_pulse(),.client_diagnostic_data(),
    .client_control_request(control_request),.client_control_type(control_type),.client_control_payload(control_payload),
    .client_control_ready(control_ready),.client_manual_supported(manual_supported),.client_control_done(),.client_control_result(),
    .client_output_muted(output_muted),.client_guide_lease_valid(guide_lease_valid),.client_audio_supported(audio_supported));
secondary_main5e_keys u_keys(.clk(application_clk),.rst(network_reset),.sw(sw),.key_n(key_n),
    .heartbeat_pulse(heartbeat_pulse),.heartbeat_data(heartbeat_data),.display_pulse(display_pulse),.display_data(display_data),
    .control_ready(control_ready),.control_request(control_request),.peer_alive(peer_alive),.manual_supported(manual_supported),
    .control_type(control_type),.control_payload(control_payload),.manual_mode(),.manual_next(),.help_switches(help_switches));

// Compatibility with the existing main heartbeat: observe entry or monotonic
// progress rewind. A future explicit round field replaces this inference for
// restart events that are entirely invisible between two heartbeat packets.
reg lecture_seen;
reg manual_reported;
reg [7:0] last_id,last_phase;
reg [31:0] last_position,round_counter;
wire lecture_now=!manual_reported&&heartbeat_data[127:120]==2&&heartbeat_data[119:112]<=4&&
    heartbeat_data[111:104]<=4&&heartbeat_data[103:96]>=1&&heartbeat_data[103:96]<=3;
wire new_round=lecture_now&&(!lecture_seen||last_id!=heartbeat_data[119:112]||
    heartbeat_data[111:104]<last_phase||
    (heartbeat_data[111:104]==last_phase&&heartbeat_data[63:32]<last_position));
// State 3 is an image transition in BOTH modes. Retain the explicit applied
// manual bit across that transient; state 5 also establishes it before the
// first display-status response has arrived.
always @(posedge application_clk or posedge network_reset)
    if(network_reset)manual_reported<=0;
    else if(heartbeat_pulse&&peer_alive&&heartbeat_data[103:96]==5)manual_reported<=1;
    else if(display_pulse&&peer_alive)manual_reported<=display_data[42];
always @(posedge application_clk or posedge network_reset)
    if(network_reset)begin lecture_seen<=0;last_id<=255;last_phase<=255;last_position<=0;round_counter<=0;end
    else if(heartbeat_pulse&&peer_alive)begin
        lecture_seen<=lecture_now;last_id<=heartbeat_data[119:112];last_phase<=heartbeat_data[111:104];
        last_position<=heartbeat_data[63:32];if(new_round)round_counter<=round_counter+1'b1;
    end
wire [7:0] file_id;
wire [31:0] generation,subtitle_position;
wire video_pause;
wire [31:0] playback_round=`OFFLINE_AV_ENABLE&&audio_supported?{19'd0,heartbeat_data[31:19]}:
    round_counter+{31'd0,new_round};
secondary_offline_scene_control #(.OSD_SWITCH(`OFFLINE_AV_ENABLE)) u_scene(.clk(application_clk),.rst(network_reset),.peer_alive(peer_alive),
    .heartbeat_pulse(heartbeat_pulse),.heartbeat_data(heartbeat_data),.help_switch(help_switches[3]),
    .guide_lease_valid(guide_lease_valid),.manual_mode(manual_reported),.main_session(peer_session),.playback_round(playback_round),
    .file_id(file_id),.generation(generation),.subtitle_position(subtitle_position),.video_pause(video_pause),
    .show_help(),.show_emergency(show_emergency),.guide_audio_enable(guide_audio_enable),.preload_target());
wire [31:0] main_position;
secondary_offline_main_timeline u_timeline(.clk(application_clk),.rst(network_reset),
    .peer_alive(peer_alive),.heartbeat_pulse(heartbeat_pulse),.heartbeat_data(heartbeat_data),
    .manual_mode(manual_reported),.position(main_position));
reg status_seen;
always @(posedge application_clk or posedge network_reset)
    if(network_reset)status_seen<=0;else if(heartbeat_pulse&&peer_alive)status_seen<=1;
wire [1:0] link_state=peer_alive?2'd1:status_seen?2'd2:2'd0;
wire [3:0] main_state=!status_seen?4'd0:show_emergency?4'd7:
    heartbeat_data[127:120]==4?4'd8:heartbeat_data[70]?4'd6:
    heartbeat_data[127:120]==0?4'd0:
    manual_reported&&heartbeat_data[127:120]==2&&heartbeat_data[103:96]!=0?4'd3:
    lecture_now?(heartbeat_data[103:96]==2||heartbeat_data[68]?4'd5:4'd4):
    heartbeat_data[127:120]==1&&heartbeat_data[69]?4'd2:4'd1;
wire [2:0] artifact=status_seen&&heartbeat_data[119:112]<=4?heartbeat_data[114:112]:3'd7;
wire [23:0] status_flags={8'd0,status_seen,heartbeat_data[18:17],artifact,main_state,
    link_state,show_emergency,help_switches[3],peer_alive&&lecture_now,guide_audio_enable};
top_secondary_tf_video #(.OFFLINE_LINK(1),.AV_ENABLE(`OFFLINE_AV_ENABLE)) u_video(
    .clk_50m(application_clk),.key_reset_n(1'b1),.key_pause_n(1'b1),
    .offline_control_rst_n(!network_reset),.offline_request({generation,file_id,video_pause}),
    .offline_status({main_position,status_flags}),.offline_muted_ack(output_muted),
    .sd_clk(sd_clk),.sd_cmd(sd_cmd),.sd_dat(sd_dat),.led(led),.seg_data(seg_data),.seg_sel(seg_sel),
    .hdmi_b_clk_p(hdmi_b_clk_p),.hdmi_b_d0_p(hdmi_b_d0_p),.hdmi_b_d1_p(hdmi_b_d1_p),.hdmi_b_d2_p(hdmi_b_d2_p));
endmodule
`default_nettype wire
