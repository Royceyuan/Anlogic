`timescale 1ns / 1ps
`default_nettype none

// Packs two consecutive RGB565 pixels into one 32-bit SDRAM word.
module rgb565_stream_packer (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    input  wire [15:0] in_pixel,
    output reg         out_valid,
    output reg  [31:0] out_data,
    input  wire        out_ready,
    output reg         overflow
);

reg        first_valid;
reg [15:0] first_pixel;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        first_valid <= 1'b0;
        first_pixel <= 16'd0;
        out_valid   <= 1'b0;
        out_data    <= 32'd0;
        overflow    <= 1'b0;
    end else begin
        if (out_valid && out_ready)
            out_valid <= 1'b0;

        if (in_valid) begin
            if (!first_valid) begin
                first_pixel <= in_pixel;
                first_valid <= 1'b1;
            end else if (!out_valid || out_ready) begin
                out_data    <= {first_pixel, in_pixel};
                out_valid   <= 1'b1;
                first_valid <= 1'b0;
            end else begin
                // The normal SD-to-SDRAM rate leaves ample margin. Keep an
                // explicit fault flag instead of silently losing a pixel.
                overflow <= 1'b1;
            end
        end
    end
end

endmodule

`default_nettype wire
