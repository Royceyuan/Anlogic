`timescale 1ns / 1ps
`default_nettype none
// Integrated candidate: A receives PC HDMI, B is the only display output.
// UART authorizes AV; emergency revokes ordinary AV, allowing only CMD06 AV.
module top_secondary_hdmi_museum #(
    // ponytail: frequency/polarity matching, not phase-locked seamless output.
    // Zero restores the original 74.25 MHz EDID and local sync polarity.
    parameter integer MATCH_PC_TIMING=1,
    // Native HDMI stream candidate. Zero restores the previous DVI encoder;
    // no PC payload, clocks or source-authorization rules are changed here.
    parameter integer LOCAL_HDMI_PACKETS=1,
    parameter integer COMMON_OUTPUT=1
)(
    input wire clk_50m,
    input wire uart_rxd,
    output wire uart_txd,
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
wire native_pclk,native_sclk,native_clock_ready,common_pclk,common_sclk,carrier_stable,pc_carrier;
wire scan_ready,scan_hs,scan_vs,scan_de;
wire [10:0] scan_x;
wire [9:0] scan_y;
wire [23:0] local_rgb;
wire application_clock;
wire [7:0] pc_artifact,pc_state,pc_phase;
wire pc_link_armed;
// One explicit root GCLK feeds both application registers and PLL references;
// do not let an unbuffered PLL reference bypass the application clock tree.
EG_LOGIC_BUFG u_application_clock(.i(clk_50m),.o(application_clock));
top_secondary_main5e #(.SHARED_MEDIA_ETH_PLL(1),.EXTERNAL_HDMI_PHY(1),.LINKED_VIDEO(1),.SHARED_VIDEO_RASTER(COMMON_OUTPUT)) u_terminal(
    .clk_50m(application_clock),.sw(sw),.key_n(key_n),.led(led),.seg_data(seg_data),.seg_sel(seg_sel),
    .shared_video_clk(common_pclk),.shared_serial_clk(common_sclk),
    .shared_clock_stable(carrier_stable),
    .shared_raster_valid(scan_ready),.shared_raster_hs(~scan_hs),.shared_raster_vs(~scan_vs),
    .shared_raster_de(scan_de),.shared_raster_x(scan_x),.shared_raster_y(scan_y),
    .native_video_clk(native_pclk),.native_serial_clk(native_sclk),.native_clock_ready(native_clock_ready),
    .sd_clk(sd_clk),.sd_mosi(sd_mosi),.sd_miso(sd_miso),.sd_cs_n(sd_cs_n),
    .hdmi1_clk_p(),.hdmi1_d0_p(),.hdmi1_d1_p(),.hdmi1_d2_p(),
    .local_video_clk(local_pclk),.local_serial_clk(local_sclk),.local_video_rst_n(local_ready),
    .local_hs(local_hs),.local_vs(local_vs),.local_de(local_de),.local_rgb(local_rgb),
    .pc_artifact(pc_artifact),.pc_state(pc_state),.pc_phase(pc_phase),
    .pc_link_armed(pc_link_armed),
    .eth_rgmii_rx_clk(eth_rgmii_rx_clk),.eth_rgmii_rx_ctl(eth_rgmii_rx_ctl),.eth_rgmii_rxd(eth_rgmii_rxd),
    .eth_rgmii_tx_clk(eth_rgmii_tx_clk),.eth_rgmii_tx_ctl(eth_rgmii_tx_ctl),.eth_rgmii_txd(eth_rgmii_txd),
    .eth_mdc(eth_mdc),.eth_mdio(eth_mdio));
wire external_sclk,external_ready,external_blank,rst_n;
wire [7:0] external_pairs,local_pairs;
wire external_selected,output_muted,pc_play_enabled;
wire capture_clk,recovered_pclk,rx_symbols_valid;
wire [29:0] rx_symbols;
top_secondary_hdmi_relay_diag #(.USE_OFFICIAL_EDID(1),.REQUIRE_SINK_HPD(0),.EXTERNAL_TRANSMITTER(1),.MATCH_LOCAL_CLOCK_EDID(MATCH_PC_TIMING)) u_relay(
    .clk_50m(application_clock),.hdmi_b_clk_p(hdmi_a_clk_p),
    .hdmi_b_d0_p(hdmi_a_d0_p),.hdmi_b_d1_p(hdmi_a_d1_p),.hdmi_b_d2_p(hdmi_a_d2_p),
    .hdmi_b_scl(hdmi_a_scl),.hdmi_b_sda(hdmi_a_sda),.hdmi_b_hpd(hdmi_a_hpd),.hdmi_a_hpd(hdmi_b_hpd),
    .hdmi1_clk_p(),.hdmi1_d0_p(),.hdmi1_d1_p(),.hdmi1_d2_p(),.led(),.seg_data(),.seg_sel(),
    .relay_sclk(external_sclk),.relay_valid(external_ready),.relay_blank(external_blank),.relay_pairs(external_pairs),.application_rst_n(rst_n),
    .relay_capture_clk(capture_clk),.relay_pixel_clk(recovered_pclk),.relay_symbols_valid(rx_symbols_valid),.relay_symbols(rx_symbols));
wire local_encoder_ready,local_encoder_blank;
wire [39:0] local_symbols;
secondary_hdmi_local_pairs #(.HDMI_PACKETS(COMMON_OUTPUT?0:LOCAL_HDMI_PACKETS)) u_local(
    .pixel_clk(local_pclk),.serial_clk(local_sclk),.rst_n(local_ready),
    .hs(MATCH_PC_TIMING ? ~local_hs : local_hs),.vs(MATCH_PC_TIMING ? ~local_vs : local_vs),
    .de(local_de),.rgb(local_rgb),.pairs(local_pairs),.encoder_ready(local_encoder_ready),.encoder_blank(local_encoder_blank),.symbols(local_symbols));
wire input_available;
secondary_video_uart_control #(.MUSEUM_LINK(1)) u_pc_video(
    .clk(application_clock),.rst_n(rst_n),.uart_rxd(uart_rxd),.uart_txd(uart_txd),
    .input_ready(input_available),.external_selected(external_selected),
    .output_muted(output_muted),.play_enabled(pc_play_enabled),
    .link_armed(pc_link_armed),
    .museum_artifact(pc_artifact),.museum_state(pc_state),.museum_phase(pc_phase));
generate if(!COMMON_OUTPUT) begin:g_legacy
assign common_pclk=local_pclk;assign common_sclk=local_sclk;
assign scan_ready=0;assign {scan_hs,scan_vs,scan_de,scan_x,scan_y}=0;
assign input_available=external_ready;
secondary_hdmi_source_switch u_switch(
    .clk_50m(application_clock),.rst_n(rst_n),.local_ready(local_ready&&local_encoder_ready),.external_ready(external_ready&&pc_play_enabled),
    .local_blank(local_encoder_blank),.external_blank(external_blank),
    .local_sclk(local_sclk),.external_sclk(external_sclk),.local_pairs(local_pairs),.external_pairs(external_pairs),
    .external_selected(external_selected),.output_muted(output_muted),
    .serial_out({hdmi_b_clk_p,hdmi_b_d2_p,hdmi_b_d1_p,hdmi_b_d0_p}));
end else begin:g_common
wire buffer_valid,buffer_fault;
wire [29:0] buffered_words,raster_words;
wire packet_data,keep_packet,pcm_packet,guard_band,raster_locked;
wire [4:0] packet_index;
wire [31:0] silent_flags;
reg [1:0] buffer_fault_ff;
reg [3:0] receiver_reset_cycles;
// A transient FIFO fault is sticky until reset, even if HDMI stays locked.
// Restart only capture/parsing; UART sees not-ready and revokes the old lease.
always @(posedge application_clock or negedge rst_n)
    if(!rst_n) begin buffer_fault_ff<=0;receiver_reset_cycles<=0;end
    else begin
        buffer_fault_ff<={buffer_fault_ff[0],buffer_fault};
        if(receiver_reset_cycles!=0) receiver_reset_cycles<=receiver_reset_cycles-1'b1;
        else if(buffer_fault_ff[1]) receiver_reset_cycles<=15;
    end
wire receiver_epoch=rst_n&&carrier_stable&&pc_carrier&&external_ready&&receiver_reset_cycles==0;
secondary_hdmi_symbol_buffer u_buffer(.rst_n(receiver_epoch),.write_clk(capture_clk),.read_clk(common_pclk),
    .input_valid(rx_symbols_valid),.input_symbols(rx_symbols),
    .output_symbols(buffered_words),.output_valid(buffer_valid),.fault(buffer_fault));
secondary_hdmi_pc_raster u_raster(.clk(common_pclk),.rst_n(receiver_epoch&&buffer_valid&&!buffer_fault),
    .symbols(buffered_words),.ready(raster_locked),.delayed_symbols(raster_words),
    .hs(scan_hs),.vs(scan_vs),.de(scan_de),.x(scan_x),.y(scan_y),
    .packet_data(packet_data),.keep_packet(keep_packet),.pcm_packet(pcm_packet),.guard_band(guard_band),
    .packet_index(packet_index),.silent_flags(silent_flags));
assign scan_ready=receiver_epoch&&buffer_valid&&raster_locked&&!buffer_fault;
wire [39:0] composed;
wire selected_pixel,aligned;
secondary_hdmi_common_symbols u_compositor(.clk(common_pclk),.rst_n(scan_ready),
    .request_pc(pc_play_enabled),.pc_ready(scan_ready),.pc_symbols(raster_words),.local_symbols(local_symbols[29:0]),
    .pc_hs(scan_hs),.pc_vs(scan_vs),.pc_de(scan_de),.packet_data(packet_data),
    .keep_packet(keep_packet),.pcm_packet(pcm_packet),.guard_band(guard_band),.packet_index(packet_index),.silent_flags(silent_flags),
    .symbols(composed),.external_selected(selected_pixel),.aligned(aligned));
reg [39:0] chosen_symbols={10'b0000011111,10'h354,10'h354,10'h354};
// Finish source qualification/muxing in the pixel domain, before the
// 375MHz shifter. No combinational fault/scan mux crosses into that shifter.
always @(posedge common_pclk) chosen_symbols<=scan_ready?composed:local_symbols;
wire [7:0] common_pairs;
secondary_hdmi_symbol_pairs u_serializer(.pixel_clk(common_pclk),.serial_clk(common_sclk),
    .symbols(chosen_symbols),.pairs(common_pairs));
reg [1:0] selected_ff,available_ff;
always @(posedge application_clock or negedge rst_n)
    if(!rst_n) begin selected_ff<=0;available_ff<=0;end
    else begin selected_ff<={selected_ff[0],selected_pixel};available_ff<={available_ff[0],scan_ready&&aligned};end
assign external_selected=selected_ff[1];
assign input_available=external_ready&&available_ff[1];
wire phy_ready=rst_n&&carrier_stable&&local_ready&&(!pc_carrier || (scan_ready&&aligned));
wire phy_epoch=rst_n&&carrier_stable;
reg pixel_phy_ready=0;
always @(posedge common_pclk or negedge phy_epoch)
    if(!phy_epoch) pixel_phy_ready<=0;else pixel_phy_ready<=phy_ready;
reg [1:0] serial_phy_ready=0;
always @(posedge common_sclk or negedge phy_epoch)
    if(!phy_epoch) serial_phy_ready<=0;else serial_phy_ready<={serial_phy_ready[0],pixel_phy_ready};
reg [3:0] release_reset=4'hf;
always @(posedge common_sclk or negedge phy_epoch)
    if(!phy_epoch) release_reset<=4'hf;
    else if(!serial_phy_ready[1]) release_reset<=4'hf;
    else release_reset<={release_reset[2:0],1'b0};
assign output_muted=release_reset[3];
genvar lane;
wire [3:0] serial_out;
assign {hdmi_b_clk_p,hdmi_b_d2_p,hdmi_b_d1_p,hdmi_b_d0_p}=serial_out;
for(lane=0;lane<4;lane=lane+1) begin:g_output
    EG_LOGIC_ODDR u_output(.q(serial_out[lane]),
        .clk(common_sclk),.rst(lane==3?!rst_n:output_muted),
        .d0(common_pairs[lane*2]),.d1(common_pairs[lane*2+1]));
end
end endgenerate
generate if(COMMON_OUTPUT) begin:g_carrier
secondary_hdmi_carrier_clock u_carrier(.clk_50m(application_clock),.rst_n(rst_n),
    .native_ready(native_clock_ready),.pc_ready(external_ready),.native_pixel_clk(native_pclk),.native_serial_clk(native_sclk),
    .pc_pixel_clk(recovered_pclk),.pc_serial_clk(external_sclk),.pixel_clk(common_pclk),.serial_clk(common_sclk),
    .pc_clock_selected(pc_carrier),.stable(carrier_stable));
end endgenerate
endmodule
`default_nettype wire
