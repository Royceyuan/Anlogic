`timescale 1ns / 1ps

module tb_museum_overview_overlay;
reg wr_clk = 1'b0;
reg video_clk = 1'b0;
reg wr_rst_n = 1'b0;
reg video_rst_n = 1'b0;
reg wr_start = 1'b0;
reg [3:0] wr_frame_index = 4'd0;
reg wr_valid = 1'b0;
reg [10:0] wr_row = 11'd0;
reg [10:0] wr_col = 11'd0;
reg [15:0] wr_pixel = 16'd0;
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

museum_overview_overlay #(
    .SOURCE_W(4), .SOURCE_H(4), .THUMB_W(2), .THUMB_H(2),
    .DISPLAY_SCALE(2), .PANEL_X0(4), .PANEL_PITCH(8),
    .PANEL_Y0(20), .BORDER(1)
) dut (
    .wr_clk(wr_clk), .wr_rst_n(wr_rst_n), .wr_start(wr_start),
    .wr_frame_index(wr_frame_index), .wr_valid(wr_valid),
    .wr_row(wr_row), .wr_col(wr_col), .wr_pixel(wr_pixel),
    .video_clk(video_clk), .video_rst_n(video_rst_n),
    .overview_enable(overview_enable), .selected_index(selected_index),
    .confirm_active(confirm_active), .frame_valid(frame_valid),
    .hs_i(hs_i), .vs_i(vs_i), .de_i(de_i), .x_i(x_i), .y_i(y_i),
    .rgb_i(rgb_i), .hs_o(hs_o), .vs_o(vs_o), .de_o(de_o),
    .x_o(x_o), .y_o(y_o), .rgb_o(rgb_o)
);

always #10 wr_clk = ~wr_clk;
always #7 video_clk = ~video_clk;

task write_sample;
    input [10:0] row_value;
    input [10:0] col_value;
    input [15:0] pixel_value;
    begin
        @(negedge wr_clk);
        wr_row = row_value; wr_col = col_value;
        wr_pixel = pixel_value; wr_valid = 1'b1;
        @(negedge wr_clk); wr_valid = 1'b0;
    end
endtask

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
    repeat (3) @(posedge wr_clk);
    wr_rst_n = 1'b1;
    video_rst_n = 1'b1;

    @(negedge wr_clk); wr_start = 1'b1; wr_frame_index = 0;
    @(negedge wr_clk); wr_start = 1'b0;
    write_sample(0, 0, 16'hf800);
    write_sample(0, 2, 16'h07e0);
    write_sample(2, 0, 16'h001f);
    write_sample(2, 2, 16'hffff);

    check_pixel(4, 20, 24'hff0000);
    check_pixel(6, 20, 24'h00ff00);
    check_pixel(3, 20, 24'hf2c14e);
    confirm_active = 1'b1;
    check_pixel(3, 20, 24'h41d17d);
    confirm_active = 1'b0;
    check_pixel(12, 20, 24'h4b2532);

    overview_enable = 1'b0;
    check_pixel(10, 30, 24'h123456);

    $display("PASS museum_overview_overlay cache, border, invalid placeholder, bypass");
    $finish;
end

endmodule
