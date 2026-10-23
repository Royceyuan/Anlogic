`default_nettype none

// Pull one stereo PCM frame from the asynchronous TF-card FIFO at a stable
// 48 kHz average rate in the HDMI pixel-clock domain.
module audio_pcm_player_48k #(
    parameter integer PIXEL_CLK_HZ = 75_000_000,
    parameter integer SAMPLE_RATE_HZ = 48_000,
    parameter integer START_FRAMES = 256,
    parameter integer UNDERFLOW_TICKS = 64,
    parameter integer ENABLE_SPEED = 0
) (
    input  wire                clk,
    input  wire                rst,
    input  wire [31:0]         fifo_data,
    input  wire                fifo_valid,
    input  wire                fifo_empty,
    input  wire [8:0]          fifo_used,
    input  wire                paused,
    input  wire                switch_mute,
    input  wire [1:0]          speed_index, // 0/1/2 = 1x/2x/3x; output stays 48 kHz
    output reg                 fifo_rd_en,
    output reg                 sample_valid,
    output reg signed [15:0]   sample_left,
    output reg signed [15:0]   sample_right,
    output reg                 frame_consumed_toggle,
    output reg                 active,
    output reg                 underflow
);

// Divide both constants by their GCD; the sample edges are unchanged.
// At 75 MHz / 48 kHz this reduces the phase state from 27 bits to 12.
function integer rate_gcd;
    input integer a, b;
    integer remainder;
    begin
        while (b != 0) begin
            remainder = a % b;
            a = b;
            b = remainder;
        end
        rate_gcd = a;
    end
endfunction
localparam integer RATE_UNIT = rate_gcd(PIXEL_CLK_HZ, SAMPLE_RATE_HZ);
localparam integer PHASE_MODULUS = PIXEL_CLK_HZ / RATE_UNIT;
localparam integer PHASE_STEP = SAMPLE_RATE_HZ / RATE_UNIT;
localparam integer PHASE_WIDTH = (PHASE_MODULUS > 1) ? $clog2(PHASE_MODULUS) : 1;
reg [PHASE_WIDTH-1:0] sample_acc;
reg [1:0] sample_subtick;
reg [6:0] underflow_ticks;
wire [PHASE_WIDTH:0] sample_acc_next = {1'b0, sample_acc} +
                                     PHASE_STEP * (ENABLE_SPEED ? 3 : 1);
wire phase_tick = sample_acc_next >= PHASE_MODULUS;
wire sample_tick = phase_tick && (!ENABLE_SPEED || sample_subtick == 2);
// Three spaced read opportunities per output sample keep the existing
// consumed-frame toggle CDC safe. 1x retains the original output/read edges.
wire source_tick = sample_tick || (ENABLE_SPEED && phase_tick &&
                   (speed_index == 2 || (speed_index == 1 && sample_subtick == 1)));

always @(posedge clk or posedge rst) begin
    if (rst) begin
        sample_acc   <= 0;
        sample_subtick <= 0;
        fifo_rd_en   <= 1'b0;
        sample_valid <= 1'b0;
        sample_left  <= 16'sd0;
        sample_right <= 16'sd0;
        frame_consumed_toggle <= 1'b0;
        active       <= 1'b0;
        underflow    <= 1'b0;
        underflow_ticks <= 7'd0;
    end else begin
        fifo_rd_en   <= 1'b0;
        sample_valid <= 1'b0;
        if (!paused && !active && fifo_used >= START_FRAMES)
            active <= 1'b1;

        if (phase_tick)
            sample_acc <= sample_acc_next - PHASE_MODULUS;
        else
            sample_acc <= sample_acc_next[PHASE_WIDTH-1:0];
        if (ENABLE_SPEED && phase_tick)
            sample_subtick <= sample_subtick == 2 ? 0 : sample_subtick + 1'b1;
        if (sample_tick)
            sample_valid <= 1'b1;

        if (switch_mute) begin
            sample_left  <= 16'sd0;
            sample_right <= 16'sd0;
            active       <= 1'b0;
            underflow_ticks <= 7'd0;
            underflow <= 1'b0;
            if (sample_tick)
                sample_valid <= 1'b1;
        end else if (paused) begin
            sample_left  <= 16'sd0;
            sample_right <= 16'sd0;
            if (sample_tick)
                sample_valid <= 1'b1;
            underflow_ticks <= 7'd0;
            underflow <= 1'b0;
        end else if (source_tick && active) begin
            if (!fifo_empty && fifo_valid) begin
                fifo_rd_en   <= 1'b1;
                frame_consumed_toggle <= ~frame_consumed_toggle;
                sample_left  <= fifo_data[15:0];
                sample_right <= fifo_data[31:16];
                underflow_ticks <= 7'd0;
                underflow <= 1'b0;
            end else begin
                sample_left  <= 16'sd0;
                sample_right <= 16'sd0;
                if (sample_tick && underflow_ticks >= UNDERFLOW_TICKS - 1)
                    underflow <= 1'b1;
                else if (sample_tick)
                    underflow_ticks <= underflow_ticks + 1'b1;
            end
        end else if (sample_tick) begin
            // Keep HDMI audio packets continuous while the initial/new track
            // is buffering; the payload becomes PCM once START_FRAMES exists.
            sample_valid <= 1'b1;
            sample_left  <= 16'sd0;
            sample_right <= 16'sd0;
        end
    end
end

endmodule

`default_nettype wire
