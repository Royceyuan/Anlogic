`timescale 1ns / 1ps
`default_nettype none

// Final full-screen emergency layer. It replaces every normal active pixel;
// the audio visualizer is intentionally downstream so alarm bars remain red.
module museum_emergency_overlay (
    input wire clk, input wire rst_n, input wire emergency, input wire frame_tick,
    input wire hs_i, input wire vs_i, input wire de_i,
    input wire [10:0] x_i, input wire [9:0] y_i, input wire [23:0] rgb_i,
    output wire hs_o, output wire vs_o, output wire de_o,
    output wire [10:0] x_o, output wire [9:0] y_o, output reg [23:0] rgb_o
);

reg [4:0] flash_count;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        flash_count <= 5'd0;
    else if (!emergency)
        flash_count <= 5'd0;
    else if (frame_tick)
        flash_count <= flash_count + 1'b1;
end

wire [10:0] triangle_dx = (x_i >= 11'd330) ? x_i - 11'd330 : 11'd330 - x_i;
wire [9:0] triangle_dy = (y_i >= 10'd140) ? y_i - 10'd140 : 10'd0;
wire triangle_hit = y_i >= 10'd140 && y_i <= 10'd430 &&
                    triangle_dx <= triangle_dy;
wire triangle_inner = y_i >= 10'd176 && y_i < 10'd402 &&
                      triangle_dx + 11'd28 < triangle_dy;
wire exclamation_hit = (x_i >= 11'd315 && x_i <= 11'd345 &&
                         y_i >= 10'd225 && y_i <= 10'd340) ||
                        (x_i >= 11'd315 && x_i <= 11'd345 &&
                         y_i >= 10'd365 && y_i <= 10'd395);

wire [10:0] arrow_dx = 11'd1120 - x_i;
wire [9:0] arrow_dy = (y_i >= 10'd360) ? y_i - 10'd360 : 10'd360 - y_i;
wire arrow_shaft = x_i >= 11'd590 && x_i < 11'd930 &&
                   y_i >= 10'd320 && y_i <= 10'd400;
wire arrow_head = x_i >= 11'd850 && x_i <= 11'd1120 &&
                  arrow_dy <= arrow_dx[9:0];
wire border = x_i < 11'd18 || x_i >= 11'd1262 ||
              y_i < 10'd18 || y_i >= 10'd702;
wire hazard_band = y_i < 10'd82 || y_i >= 10'd638;
wire hazard_yellow = x_i[6] ^ y_i[5];

always @(*) begin
    rgb_o = rgb_i;
    if (emergency) begin
        if (!de_i)
            rgb_o = 24'h000000;
        else if (border)
            rgb_o = 24'hffffff;
        else if (hazard_band)
            rgb_o = hazard_yellow ? 24'hffd000 : 24'h111111;
        else if (triangle_hit && !triangle_inner)
            rgb_o = 24'hffd000;
        else if (exclamation_hit)
            rgb_o = 24'hffd000;
        else if (arrow_shaft || arrow_head)
            rgb_o = 24'hffffff;
        else
            rgb_o = flash_count[4] ? 24'h780000 : 24'h500000;
    end
end

assign hs_o = hs_i;
assign vs_o = vs_i;
assign de_o = de_i;
assign x_o = x_i;
assign y_o = y_i;

endmodule

// Local two-tone alarm. It cannot mix with lecture PCM because the top-level
// audio mux selects exactly one source while emergency is asserted.
module emergency_alarm_48k #(
    parameter integer CLK_HZ = 75_000_000,
    parameter integer SAMPLE_RATE_HZ = 48_000,
    parameter integer LEVEL_SHIFT = 2
) (
    input wire clk, input wire rst_n, input wire enable,
    output reg sample_valid,
    output reg signed [15:0] sample_left,
    output reg signed [15:0] sample_right
);

localparam [31:0] SAMPLE_TICK_THRESHOLD = CLK_HZ - SAMPLE_RATE_HZ;
localparam [63:0] PHASE_SCALE = 64'd4_294_967_296;
localparam [31:0] PHASE_STEP_LOW = (PHASE_SCALE * 64'd660) / SAMPLE_RATE_HZ;
localparam [31:0] PHASE_STEP_HIGH = (PHASE_SCALE * 64'd880) / SAMPLE_RATE_HZ;
localparam integer HALF_SECOND_SAMPLES = SAMPLE_RATE_HZ / 2;

reg [31:0] sample_acc;
reg [31:0] tone_phase;
reg [14:0] cadence_count;
reg tone_high;
wire [14:0] triangle_ramp = tone_phase[30] ? ~tone_phase[29:15] : tone_phase[29:15];
wire [14:0] attenuated_ramp = triangle_ramp >> LEVEL_SHIFT;
wire signed [15:0] triangle_level = $signed({1'b0, attenuated_ramp});

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sample_acc <= 32'd0;
        tone_phase <= 32'd0;
        cadence_count <= 15'd0;
        tone_high <= 1'b0;
        sample_valid <= 1'b0;
        sample_left <= 16'sd0;
        sample_right <= 16'sd0;
    end else begin
        sample_valid <= 1'b0;
        if (!enable) begin
            sample_acc <= 32'd0;
            tone_phase <= 32'd0;
            cadence_count <= 15'd0;
            tone_high <= 1'b0;
            sample_left <= 16'sd0;
            sample_right <= 16'sd0;
        end else if (sample_acc >= SAMPLE_TICK_THRESHOLD) begin
            sample_acc <= sample_acc - SAMPLE_TICK_THRESHOLD;
            tone_phase <= tone_phase + (tone_high ? PHASE_STEP_HIGH : PHASE_STEP_LOW);
            sample_valid <= 1'b1;
            sample_left <= tone_phase[31] ? -triangle_level : triangle_level;
            sample_right <= tone_phase[31] ? -triangle_level : triangle_level;
            if (cadence_count == HALF_SECOND_SAMPLES - 1) begin
                cadence_count <= 15'd0;
                tone_high <= ~tone_high;
            end else
                cadence_count <= cadence_count + 1'b1;
        end else begin
            sample_acc <= sample_acc + SAMPLE_RATE_HZ;
        end
    end
end

endmodule

`default_nettype wire
