`timescale 1ns / 1ps
`default_nettype none
// Temporary A-input/B-output audio/video candidate. No museum integration.
module top_secondary_hdmi_av_diag(
    input wire clk_50m,
    input wire hdmi_a_clk_p,hdmi_a_d0_p,hdmi_a_d1_p,hdmi_a_d2_p,hdmi_a_scl,
    inout wire hdmi_a_sda,
    output wire hdmi_a_hpd,
    input wire hdmi_b_hpd,
    output wire hdmi_b_clk_p,hdmi_b_d0_p,hdmi_b_d1_p,hdmi_b_d2_p,
    output wire [3:0] led,
    output wire [7:0] seg_data,seg_sel
);
// Logical RX/TX port names in the shared diagnostic predate this port trial.
// Official sender has no sink-HPD gate. Keep observed B HPD diagnostic-only:
// the loopback tests show it is not a reliable presence signal yet.
top_secondary_hdmi_relay_diag #(.USE_OFFICIAL_EDID(1),.REQUIRE_SINK_HPD(0)) u_relay(
    .clk_50m(clk_50m),
    .hdmi_b_clk_p(hdmi_a_clk_p),.hdmi_b_d0_p(hdmi_a_d0_p),
    .hdmi_b_d1_p(hdmi_a_d1_p),.hdmi_b_d2_p(hdmi_a_d2_p),
    .hdmi_b_scl(hdmi_a_scl),.hdmi_b_sda(hdmi_a_sda),.hdmi_b_hpd(hdmi_a_hpd),
    .hdmi_a_hpd(hdmi_b_hpd),
    .hdmi1_clk_p(hdmi_b_clk_p),.hdmi1_d0_p(hdmi_b_d0_p),
    .hdmi1_d1_p(hdmi_b_d1_p),.hdmi1_d2_p(hdmi_b_d2_p),
    .led(led),.seg_data(seg_data),.seg_sel(seg_sel));
endmodule
`default_nettype wire
