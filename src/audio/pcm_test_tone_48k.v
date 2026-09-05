`timescale 1ns / 1ps
`default_nettype none

// Deterministic 48 kHz PCM source for the future HDMI-audio path.
// The square wave is intentionally simple: it is an electrical/data-path
// smoke source, not the final music player.
module pcm_test_tone_48k #(
    parameter integer CLK_HZ        = 50_000_000,
    parameter integer SAMPLE_RATE_HZ = 48_000,
    parameter integer TONE_FREQ_HZ   = 1_000,
    parameter [15:0]  AMPLITUDE      = 16'h3000
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               enable,
    output reg                sample_valid,
    output reg signed [15:0]  sample_left,
    output reg signed [15:0]  sample_right,
    output reg        [15:0]  sample_level,
    output reg        [31:0]  sample_count
);

localparam [31:0] SAMPLE_TICK_THRESHOLD = CLK_HZ - SAMPLE_RATE_HZ;
localparam [63:0] PHASE_SCALE           = 64'd4_294_967_296;
localparam [31:0] TONE_PHASE_STEP       =
                    (PHASE_SCALE * TONE_FREQ_HZ) / SAMPLE_RATE_HZ;

reg [31:0] sample_acc;
reg [31:0] tone_phase;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sample_acc   <= 32'd0;
        tone_phase   <= 32'd0;
        sample_valid <= 1'b0;
        sample_left  <= 16'sd0;
        sample_right <= 16'sd0;
        sample_level <= 16'd0;
        sample_count <= 32'd0;
    end else begin
        sample_valid <= 1'b0;

        if (!enable) begin
            sample_acc   <= 32'd0;
            tone_phase   <= 32'd0;
            sample_left  <= 16'sd0;
            sample_right <= 16'sd0;
            sample_level <= 16'd0;
            sample_count <= 32'd0;
        end else if (sample_acc >= SAMPLE_TICK_THRESHOLD) begin
            // Fractional divider: the average output rate is exactly
            // SAMPLE_RATE_HZ, with only a one-clock placement jitter.
            sample_acc   <= sample_acc - SAMPLE_TICK_THRESHOLD;
            sample_valid <= 1'b1;
            tone_phase   <= tone_phase + TONE_PHASE_STEP;
            sample_count <= sample_count + 32'd1;
            sample_level <= AMPLITUDE;

            if (tone_phase[31]) begin
                sample_left  <= -AMPLITUDE;
                sample_right <= -AMPLITUDE;
            end else begin
                sample_left  <= AMPLITUDE;
                sample_right <= AMPLITUDE;
            end
        end else begin
            sample_acc <= sample_acc + SAMPLE_RATE_HZ;
        end
    end
end

endmodule

`default_nettype wire
