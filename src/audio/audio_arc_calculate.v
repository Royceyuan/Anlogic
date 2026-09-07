`default_nettype none

// HDMI audio clock-regeneration packets.  CTS is measured from the exact
// sample-valid cadence so it remains correct when the pixel PLL is not an
// integer multiple of 48 kHz.
module audio_arc_calculate #(
    parameter [19:0] ACR_N = 20'd6144
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        sample_valid,
    output reg         acr_valid,
    output reg [19:0]  acr_cts,
    output reg [19:0]  acr_n
);

localparam [7:0] AUDIO_DIV = ACR_N >> 7;
reg [7:0] div_count;
reg [19:0] cts_count;
wire acr_tick = sample_valid && (div_count == AUDIO_DIV - 1'b1);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        div_count <= 8'd0;
        cts_count <= 20'd0;
        acr_valid <= 1'b0;
        acr_cts   <= 20'd0;
        acr_n     <= 20'd0;
    end else begin
        acr_valid <= 1'b0;
        acr_cts   <= 20'd0;
        acr_n     <= 20'd0;
        if (sample_valid) begin
            if (div_count == AUDIO_DIV - 1'b1)
                div_count <= 8'd0;
            else
                div_count <= div_count + 1'b1;
        end
        if (acr_tick) begin
            acr_valid <= 1'b1;
            acr_cts   <= cts_count + 1'b1;
            acr_n     <= ACR_N;
            cts_count <= 20'd0;
        end else begin
            cts_count <= cts_count + 1'b1;
        end
    end
end

endmodule

`default_nettype wire
