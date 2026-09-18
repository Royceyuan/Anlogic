`timescale 1ns / 1ps
`default_nettype none

module tb_osd_1280_dimensions;
reg clk=0, rst_n=0, de_i=0;
reg [10:0] x_i=0;
reg [9:0] y_i=0;
reg [23:0] rgb_i=24'h123456;
reg [1:0] mode=2'b00;
reg panel_enable=1'b1;
wire [23:0] rgb_o;
integer failures=0;
integer x, y;
reg [23:0] expected;
always #5 clk=~clk;

osd_status_1280_pipe dut (
    .clk(clk), .rst_n(rst_n), .de_i(de_i), .x_i(x_i), .y_i(y_i), .rgb_i(rgb_i),
    .image_index(4'd4), .auto_mode(1'b0), .brightness_level(2'd0),
    .contrast_level(2'd0), .audio_track_index(2'd0), .mode(mode),
    .panel_enable(panel_enable), .zoom_2x(1'b0), .picture_style(2'd0),
    .auto_speed_level(2'd1), .slideshow_paused(1'b0),
    .transition_theme(2'd0), .transition_context(2'd0),
    .source_width_bcd(16'h0717),
    .source_height_bcd(16'h0527), .rgb_o(rgb_o)
);

task sample;
    input [10:0] sx;
    input [9:0] sy;
    input [23:0] want;
    begin
        @(negedge clk);
        de_i=1'b1; x_i=sx; y_i=sy;
        expected=want;
        @(posedge clk); @(posedge clk); @(posedge clk); #1;
        if (rgb_o !== expected) begin
            if (failures < 16)
                $display("FAIL osd x=%0d y=%0d got=%h expected=%h",sx,sy,rgb_o,expected);
            failures=failures+1;
        end
    end
endtask

initial begin
    repeat(3) @(posedge clk); rst_n=1;
    // The slim panel covers the entire 1280-pixel active width.
    for (x=0; x<1280; x=x+1) begin
        sample(x,0,24'h222222);
        sample(x,15,24'h222222);
    end
    sample(11'd1000,10'd8,24'h222222);
    sample(11'd1279,10'd8,24'h222222);
    // x=1042 used to alias cell 2 (x[9:3]) and draw IMG a second time.
    sample(11'd1042,10'd4,24'h222222);
    sample(11'd1000,10'd16,24'h123456);
    sample(11'd1279,10'd31,24'h123456);
    // PRODUCT SHOW begins with P; AUDIO CONTROL begins with A.
    sample(11'd16,10'd4,24'hffffff);
    mode=2'b11;
    sample(11'd16,10'd4,24'h222222);
    panel_enable=1'b0;
    sample(11'd18,10'd4,24'h123456);
    if (failures==0) $display("PASS osd_1280_full_width_slim_5x7");
    else $display("FAIL osd_1280_dimensions failures=%0d",failures);
    $finish;
end
endmodule

`default_nettype wire
