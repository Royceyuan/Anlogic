`timescale 1ns / 1ps
`default_nettype none

// Two RGB565 pixels become one 32-bit word. Unlike the original bring-up
// packer, this variant exposes input back-pressure for row transactions.
module rgb565_stream_packer_ready (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    output wire        in_ready,
    input  wire [15:0] in_pixel,
    output reg         out_valid,
    output reg  [31:0] out_data,
    input  wire        out_ready
);

reg        first_valid;
reg [15:0] first_pixel;

assign in_ready = !first_valid || !out_valid || out_ready;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        first_valid <= 1'b0;
        first_pixel <= 16'd0;
        out_valid   <= 1'b0;
        out_data    <= 32'd0;
    end else begin
        if (out_valid && out_ready)
            out_valid <= 1'b0;

        if (in_valid && in_ready) begin
            if (!first_valid) begin
                first_pixel <= in_pixel;
                first_valid <= 1'b1;
            end else begin
                out_data    <= {first_pixel, in_pixel};
                out_valid   <= 1'b1;
                first_valid <= 1'b0;
            end
        end
    end
end

endmodule

`default_nettype wire
