`timescale 1ns / 1ps

module tb_museum_overview_overlay;
reg video_clk = 1'b0;
reg video_rst_n = 1'b0;
reg video_frame_tick = 1'b0;
reg overview_enable = 1'b1;
reg [2:0] selected_index = 3'd0;
reg confirm_active = 1'b0;
reg [4:0] frame_valid = 5'b00001;
reg hs_i = 1'b1, vs_i = 1'b1, de_i = 1'b1;
reg [10:0] x_i = 11'd0;
reg [9:0] y_i = 10'd0;
reg [23:0] rgb_i = 24'h123456;
wire hs_o, vs_o, de_o;
wire [10:0] x_o;
wire [9:0] y_o;
wire [23:0] rgb_o;

museum_overview_overlay dut (
    .video_clk(video_clk), .video_rst_n(video_rst_n),
    .video_frame_tick(video_frame_tick),
    .overview_enable(overview_enable), .selected_index(selected_index),
    .confirm_active(confirm_active), .frame_valid(frame_valid),
    .hs_i(hs_i), .vs_i(vs_i), .de_i(de_i), .x_i(x_i), .y_i(y_i),
    .rgb_i(rgb_i), .hs_o(hs_o), .vs_o(vs_o), .de_o(de_o),
    .x_o(x_o), .y_o(y_o), .rgb_o(rgb_o)
);

always #7 video_clk = ~video_clk;

task check_pixel;
    input [10:0] x_value;
    input [9:0] y_value;
    input [23:0] expected;
    begin
        @(negedge video_clk); x_i = x_value; y_i = y_value;
        @(posedge video_clk); #1;
        if (rgb_o !== expected)
            $fatal(1, "pixel (%0d,%0d) got %h expected %h", x_value, y_value,
                   rgb_o, expected);
    end
endtask

initial begin
    repeat (3) @(posedge video_clk);
    video_rst_n = 1'b1;

    @(negedge video_clk); video_frame_tick = 1'b1;
    @(negedge video_clk); video_frame_tick = 1'b0;
    repeat (2) @(posedge video_clk);

    check_pixel(10, 20, 24'h123456);
    check_pixel(0, 20, 24'hf2c14e);
    check_pixel(254, 20, 24'h123456);
    check_pixel(255, 20, 24'hf2c14e);
    check_pixel(256, 20, 24'hf2c14e);
    check_pixel(257, 20, 24'h000000);
    confirm_active = 1'b1;
    check_pixel(255, 8, 24'h41d17d);
    confirm_active = 1'b0;
    check_pixel(260, 20, 24'h000000);
    check_pixel(276, 20, 24'h000000);
    check_pixel(512, 8, 24'h68727d);

    // The top OSD strip passes through except at the continuous separator.
    check_pixel(260, 8, 24'h123456);

    // A completed panel is published only at the next display frame.
    frame_valid = 5'b00011;
    check_pixel(260, 20, 24'h000000);
    @(negedge video_clk); video_frame_tick = 1'b1;
    @(negedge video_clk); video_frame_tick = 1'b0;
    check_pixel(260, 20, 24'h123456);
    check_pixel(780, 20, 24'h000000);

    overview_enable = 1'b0;
    check_pixel(260, 20, 24'h123456);

    $display("PASS museum_overview_overlay borders, frame-boundary validity, bypass");
    $finish;
end

endmodule
