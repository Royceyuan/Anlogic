`default_nettype none

// Pull one stereo PCM frame from the asynchronous TF-card FIFO at a stable
// 48 kHz average rate in the HDMI pixel-clock domain.
module audio_pcm_player_48k #(
    parameter integer PIXEL_CLK_HZ = 75_000_000,
    parameter integer SAMPLE_RATE_HZ = 48_000,
    parameter integer START_FRAMES = 256,
    parameter integer UNDERFLOW_TICKS = 64
) (
    input  wire                clk,
    input  wire                rst,
    input  wire [31:0]         fifo_data,
    input  wire                fifo_valid,
    input  wire                fifo_empty,
    input  wire [8:0]          fifo_used,
    input  wire                paused,
    input  wire                switch_mute,
    output reg                 fifo_rd_en,
    output reg                 sample_valid,
    output reg signed [15:0]   sample_left,
    output reg signed [15:0]   sample_right,
    output reg                 active,
    output reg                 underflow
);

reg [26:0] sample_acc;
reg [6:0] underflow_ticks;
wire [27:0] sample_acc_next = {1'b0, sample_acc} + SAMPLE_RATE_HZ;
wire sample_tick = sample_acc_next >= PIXEL_CLK_HZ;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        sample_acc   <= 27'd0;
        fifo_rd_en   <= 1'b0;
        sample_valid <= 1'b0;
        sample_left  <= 16'sd0;
        sample_right <= 16'sd0;
        active       <= 1'b0;
        underflow    <= 1'b0;
        underflow_ticks <= 7'd0;
    end else begin
        fifo_rd_en   <= 1'b0;
        sample_valid <= 1'b0;
        if (!paused && !active && fifo_used >= START_FRAMES)
            active <= 1'b1;

        if (sample_tick)
            sample_acc <= sample_acc_next - PIXEL_CLK_HZ;
        else
            sample_acc <= sample_acc_next[26:0];

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
        end else if (sample_tick && active) begin
            if (!fifo_empty && fifo_valid) begin
                fifo_rd_en   <= 1'b1;
                sample_valid <= 1'b1;
                sample_left  <= fifo_data[15:0];
                sample_right <= fifo_data[31:16];
                underflow_ticks <= 7'd0;
                underflow <= 1'b0;
            end else begin
                sample_valid <= 1'b1;
                sample_left  <= 16'sd0;
                sample_right <= 16'sd0;
                if (underflow_ticks >= UNDERFLOW_TICKS - 1)
                    underflow <= 1'b1;
                else
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
