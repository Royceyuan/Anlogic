`timescale 1ns / 1ps
`default_nettype none

// SECONDARY-1/2/3 local terminal. Future MBP1 receiver drives the decoded
// command wires below; the display and emergency control do not depend on it.
module top_1280x720_secondary_local (
    input  wire       clk_50m,
    input  wire       emergency_sw,
    input  wire [2:0] exhibit_sw,
    input  wire [3:0] key_n,
    output wire [3:0] led,
    output wire [7:0] seg_data,
    output wire [7:0] seg_sel,
    output wire       sd_clk,
    output wire       sd_mosi,
    input  wire       sd_miso,
    output wire       sd_cs_n,
    output wire       hdmi1_clk_p,
    output wire       hdmi1_d2_p,
    output wire       hdmi1_d1_p,
    output wire       hdmi1_d0_p
);

// Local preview uses the same parsed-command interface as the future receiver.
// KEY1 preloads SW1..SW3 (0..4) without changing the carousel;
// KEY2 confirms the same selection; KEY3 returns to the carousel.
wire local_rst_n;
wire [3:0] key_press;
reg [2:0] sw_ff1, sw_ff2;
reset_sync u_local_reset (.clk(clk_50m), .arst_n(1'b1), .srst_n(local_rst_n));
key_debounce u_local_keys (
    .clk(clk_50m), .rst_n(local_rst_n), .key_n(key_n),
    .key_level_n(), .key_press_pulse(key_press), .key_release_pulse()
);
always @(posedge clk_50m) begin
    sw_ff1 <= exhibit_sw;
    sw_ff2 <= sw_ff1;
end
wire preload_pulse = key_press[0] && (sw_ff2 <= 3'd4);
wire confirm_pulse = key_press[1] && (sw_ff2 <= 3'd4);
wire return_pulse = key_press[2];
wire        cmd_valid = preload_pulse || confirm_pulse || return_pulse;
wire [7:0]  cmd_type = return_pulse ? 8'h11 : 8'h10;
wire [7:0]  cmd_artifact_id = (preload_pulse || confirm_pulse) ?
                              {5'd0, sw_ff2} : 8'hff;
wire        cmd_confirmed = confirm_pulse;
wire [7:0]  cmd_mode = 8'd1;
wire [7:0]  cmd_lecture_phase = return_pulse ? 8'hff : 8'd0;
wire [7:0]  cmd_lecture_reason = return_pulse ? 8'd1 : 8'd0;
wire [15:0] cmd_emergency_id = 16'd0;
wire [7:0]  cmd_route_id = 8'd0;
wire        cmd_emergency_active = 1'b0;
wire [2:0]  cmd_result;

top_v66 #(
    .VIDEO_W(1280), .VIDEO_H(720), .SOURCE_W(960), .SOURCE_H(540),
    .VIDEO_BURST_WORDS(128), .VIDEO_WRITE_BURST_WORDS(16),
    .VIDEO_READ_BURST_WORDS(128), .VIDEO_MODE_1280(1),
    .ADAPTIVE_BMP(1), .ADAPTIVE_BMP_MAX_WIDTH(1920),
    .ADAPTIVE_BMP_MAX_HEIGHT(1080),
    .ADAPTIVE_BACKGROUND_RGB565(16'h18E3), .ADAPTIVE_BLOCK_WRITER(0),
    .ENABLE_OSD(0), .ENABLE_FADE(1), .VIDEO_SEQUENCE(0), .VIDEO_BIN(0),
    .MULTI_IMAGE_BMP(1), .MULTI_FRAME_PRELOAD(1), .VIDEO_FRAME_COUNT(5),
    .FORCE_SEQUENCE_AUTO(1), .AUTO_PERIOD_CYCLES(250_000_000),
    .LINEBUF_SCALE(1), .LINEBUF_NOREG_SYNC_READ(1),
    .LINEBUF_V26_OUTPUT_PIPELINE(1),
    .RESOURCE_OPT_CONSTANT_MULT(1),
    .ENABLE_SUBTITLE(0), .ENABLE_AUDIO_VISUALIZER(0),
    .ENABLE_MUSEUM_OVERVIEW(0), .ENABLE_MUSEUM_LECTURE(0),
    .ENABLE_SECONDARY(1),
    .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_FRONT(5), .V_SYNC(5), .V_BACK(20)
) u_secondary_core (
    .clk_50m(clk_50m), .key_n(4'b1111),
    .sw({emergency_sw, 1'b0, 2'b01}),
    .led(led), .seg_data(seg_data), .seg_sel(seg_sel),
    .sd_clk(sd_clk), .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
    .vga_hs(), .vga_vs(), .vga_d(),
    .hdmi1_clk_p(hdmi1_clk_p), .hdmi1_d2_p(hdmi1_d2_p),
    .hdmi1_d1_p(hdmi1_d1_p), .hdmi1_d0_p(hdmi1_d0_p),
    .hdmi1_ddc_scl(), .hdmi1_ddc_sda(),
    .uart_rxd(1'b1), .uart_txd(),
    .secondary_cmd_valid(cmd_valid), .secondary_cmd_type(cmd_type),
    .secondary_cmd_artifact_id(cmd_artifact_id),
    .secondary_cmd_confirmed(cmd_confirmed),
    .secondary_cmd_mode(cmd_mode),
    .secondary_cmd_lecture_phase(cmd_lecture_phase),
    .secondary_cmd_lecture_reason(cmd_lecture_reason),
    .secondary_cmd_emergency_id(cmd_emergency_id),
    .secondary_cmd_route_id(cmd_route_id),
    .secondary_cmd_emergency_active(cmd_emergency_active),
    .secondary_cmd_result(cmd_result)
);

endmodule

`default_nettype wire
