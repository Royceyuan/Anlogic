`timescale 1ns / 1ps
`default_nettype none

// Final full-screen emergency layer. It replaces every normal active pixel;
// the audio visualizer is intentionally downstream so alarm bars remain red.
module museum_emergency_overlay #(
    parameter integer PIPELINED = 0
) (
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

// Half-plane tests share two diagonals; avoid abs -> add -> compare chains.
// 12 bits cover the entire input range, including blanking coordinates.
wire [11:0] diagonal_sum = {1'b0,x_i} + {2'b00,y_i};
wire signed [11:0] diagonal_difference = $signed({1'b0,x_i}) - $signed({2'b00,y_i});
wire triangle_hit = y_i >= 10'd140 && y_i <= 10'd430 &&
                    diagonal_sum >= 12'd470 && diagonal_difference <= 12'sd190;
wire triangle_inner = y_i >= 10'd176 && y_i < 10'd402 &&
                      diagonal_sum > 12'd498 && diagonal_difference < 12'sd162;
wire exclamation_hit = (x_i >= 11'd315 && x_i <= 11'd345 &&
                         y_i >= 10'd225 && y_i <= 10'd340) ||
                        (x_i >= 11'd315 && x_i <= 11'd345 &&
                         y_i >= 10'd365 && y_i <= 10'd395);

wire arrow_shaft = x_i >= 11'd590 && x_i < 11'd930 &&
                   y_i >= 10'd320 && y_i <= 10'd400;
wire arrow_head = x_i >= 11'd850 && x_i <= 11'd1120 &&
                  diagonal_sum <= 12'd1480 && diagonal_difference <= 12'sd760;
wire border = x_i < 11'd18 || x_i >= 11'd1262 ||
              y_i < 10'd18 || y_i >= 10'd702;
wire hazard_band = y_i < 10'd82 || y_i >= 10'd638;
wire hazard_yellow = x_i[6] ^ y_i[5];
wire [7:0] geometry;
wire pixel_de, pixel_emergency, pixel_flash;
wire [23:0] pixel_rgb;
generate
    if (PIPELINED) begin : g_geometry_pipe
        reg [7:0] geometry_q;
        reg hs_q, vs_q, de_q, emergency_q, flash_q;
        reg [10:0] x_q;
        reg [9:0] y_q;
        reg [23:0] rgb_q;
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                geometry_q <= 8'd0;
                hs_q <= 1'b1; vs_q <= 1'b1; de_q <= 1'b0;
                emergency_q <= 1'b0; flash_q <= 1'b0;
                x_q <= 11'd0; y_q <= 10'd0; rgb_q <= 24'd0;
            end else begin
                geometry_q <= {triangle_hit, triangle_inner, exclamation_hit,
                               arrow_shaft, arrow_head, border, hazard_band, hazard_yellow};
                hs_q <= hs_i; vs_q <= vs_i; de_q <= de_i;
                emergency_q <= emergency; flash_q <= flash_count[4];
                x_q <= x_i; y_q <= y_i; rgb_q <= rgb_i;
            end
        end
        assign geometry = geometry_q;
        assign pixel_de = de_q;
        assign pixel_emergency = emergency_q;
        assign pixel_flash = flash_q;
        assign pixel_rgb = rgb_q;
        assign hs_o = hs_q; assign vs_o = vs_q; assign de_o = de_q;
        assign x_o = x_q; assign y_o = y_q;
    end else begin : g_geometry_direct
        assign geometry = {triangle_hit, triangle_inner, exclamation_hit,
                           arrow_shaft, arrow_head, border, hazard_band, hazard_yellow};
        assign pixel_de = de_i;
        assign pixel_emergency = emergency;
        assign pixel_flash = flash_count[4];
        assign pixel_rgb = rgb_i;
        assign hs_o = hs_i; assign vs_o = vs_i; assign de_o = de_i;
        assign x_o = x_i; assign y_o = y_i;
    end
endgenerate
// Parallel palette enables preserve layer priority without cascading wide
// RGB muxes after the diagonal comparisons (a video-clock timing bottleneck).
wire symbol_yellow = (geometry[7] && !geometry[6]) || geometry[5];
wire select_white = pixel_de && (geometry[2] ||
                    (!geometry[1] && !symbol_yellow && (geometry[4] || geometry[3])));
wire select_yellow = pixel_de && !geometry[2] &&
                     (geometry[1] ? geometry[0] : symbol_yellow);
wire select_dark = pixel_de && !geometry[2] && geometry[1] && !geometry[0];
wire select_red = pixel_de && !geometry[2] && !geometry[1] && !symbol_yellow &&
                  !geometry[4] && !geometry[3];

always @(*) begin
    rgb_o = pixel_rgb;
    if (pixel_emergency)
        rgb_o = ({24{select_white}} & 24'hffffff) |
                ({24{select_yellow}} & 24'hffd000) |
                ({24{select_dark}} & 24'h111111) |
                ({24{select_red}} & (pixel_flash ? 24'h780000 : 24'h500000));
end

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
