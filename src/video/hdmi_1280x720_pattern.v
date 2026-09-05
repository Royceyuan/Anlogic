`timescale 1ns / 1ps
`default_nettype none

module hdmi_1280x720_pattern (
    input  wire        de,
    input  wire [10:0] x,
    input  wire [9:0]  y,
    output reg  [23:0] rgb
);

always @(*) begin
    if (!de) begin
        rgb = 24'h000000;
    end else if (y < 10'd32) begin
        rgb = 24'hFFFFFF;
    end else begin
        case (x[10:8])
            3'd0: rgb = 24'hFFFFFF;
            3'd1: rgb = 24'hFFFF00;
            3'd2: rgb = 24'h00FFFF;
            3'd3: rgb = 24'h00FF00;
            3'd4: rgb = 24'hFF00FF;
            3'd5: rgb = 24'hFF0000;
            3'd6: rgb = 24'h0000FF;
            default: rgb = 24'h000000;
        endcase

        // Thin alignment lines make scaling and timing artifacts obvious.
        if ((x == 11'd0) || (x == 11'd639) || (x == 11'd640) ||
            (x == 11'd1279) || (y == 10'd359) || (y == 10'd360))
            rgb = 24'hFFFFFF;
    end
end

endmodule

`default_nettype wire
