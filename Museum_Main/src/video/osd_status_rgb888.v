`timescale 1ns / 1ps
`default_nettype none

// RGB888 version of the diagnostic panel. Keeping it separate from the
// existing RGB444 module avoids changing the previously verified interface.
module osd_status_rgb888 (
    input  wire        de,
    input  wire [9:0]  x,
    input  wire [9:0]  y,
    input  wire [23:0] rgb_in,
    input  wire        enable,
    input  wire [3:0]  image_index,
    input  wire        auto_mode,
    input  wire [1:0]  brightness_level,
    input  wire [1:0]  contrast_level,
    input  wire [15:0] source_width_bcd,
    input  wire [15:0] source_height_bcd,
    output reg  [23:0] rgb_out
);

wire [11:0] panel_rgb;

osd_status u_osd_status_12 (
    .de(de), .x(x), .y(y), .rgb_in(rgb_in[23:12]),
    .enable(enable), .image_index(image_index), .auto_mode(auto_mode),
    .brightness_level(brightness_level), .contrast_level(contrast_level),
    .source_width_bcd(source_width_bcd), .source_height_bcd(source_height_bcd),
    .rgb_out(panel_rgb)
);

always @(*) begin
    if (!de)
        rgb_out = 24'h000000;
    else if (enable && (y[9:5] == 5'd0))
        rgb_out = {panel_rgb[11:8], panel_rgb[11:8],
                   panel_rgb[7:4], panel_rgb[7:4],
                   panel_rgb[3:0], panel_rgb[3:0]};
    else
        rgb_out = rgb_in;
end

endmodule

`default_nettype wire
