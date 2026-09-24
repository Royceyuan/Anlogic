`timescale 1ns / 1ps
`default_nettype none

module tb_secondary_page_overlay;
reg clk = 1'b0;
reg rst_n = 1'b0;
reg de = 1'b1;
reg [10:0] x = 11'd500;
reg [9:0] y = 10'd400;
reg [10:0] pre_x = 11'd500;
reg [9:0] pre_y = 10'd400;
reg [23:0] base_rgb = 24'h123456;
reg emergency_50m = 1'b0;
reg emergency_bitmap_video = 1'b0;
reg [1:0] link_state_50m = 2'd0;
reg [2:0] master_artifact_50m = 3'd7;
reg [7:0] route_id_50m = 8'd0;
reg media_ready_50m = 1'b0;
reg media_error_50m = 1'b0;
wire [23:0] rgb;

always #5 clk = ~clk;
secondary_page_overlay dut (
    .clk(clk), .rst_n(rst_n), .de(de), .x(x), .y(y),
    .pre_x(pre_x), .pre_y(pre_y),
    .base_rgb(base_rgb), .emergency_50m(emergency_50m),
    .emergency_bitmap_video(emergency_bitmap_video),
    .link_state_50m(link_state_50m),
    .master_artifact_50m(master_artifact_50m),
    .route_id_50m(route_id_50m),
    .media_ready_50m(media_ready_50m),
    .media_error_50m(media_error_50m), .rgb(rgb)
);

task step;
    input integer count;
    integer i;
    begin for (i=0;i<count;i=i+1) begin @(posedge clk); #1; end end
endtask
task frame;
    begin
        x = 0; y = 0; pre_x = 0; pre_y = 0; step(1);
        x = 500; y = 400; pre_x = 500; pre_y = 400; #1;
    end
endtask
task check;
    input condition;
    input [255:0] reason;
    begin if (!condition) begin $display("FAIL: %0s", reason); $fatal(1); end end
endtask

initial begin
    step(2);
    @(negedge clk); rst_n = 1'b1;
    media_ready_50m = 1'b1;
    step(4); frame();
    check(rgb == base_rgb, "normal page passes cached image");
    link_state_50m = 2'd1;
    step(4); frame();
    x = 50; y = 667; #1;
    check(rgb == base_rgb, "normal image fills bottom edge");

    emergency_50m = 1'b1;
    media_ready_50m = 1'b0;
    media_error_50m = 1'b1;
    step(4); frame();
    x = 50; y = 667; #1;
    check(rgb == 24'h142033, "emergency wait has no link footer");
    x = 250; y = 388; #1;
    check(rgb == 24'h142033, "emergency wait has no old route marker");
    x = 1100; y = 320; #1;
    check(rgb == 24'h142033, "emergency wait has no old exit block");
    pre_x = 450; pre_y = 48; step(1);
    x = 450; y = 48; #1;
    check(rgb == 24'hFFFFFF, "pipelined emergency title pixel");

    emergency_bitmap_video = 1'b1;
    step(4); frame();
    x = 50; y = 667; #1;
    check(rgb == base_rgb, "SD emergency bitmap keeps its lower safety text");
    emergency_50m = 1'b0;
    step(4); frame();
    check(rgb == base_rgb, "SD bitmap held until the media slot changes");
    emergency_bitmap_video = 1'b0;

    step(4); frame();
    x = 500; y = 400; #1;
    check(rgb == 24'h142033, "media error placeholder");
    pre_x = 410; pre_y = 312; step(1);
    x = 410; y = 312; #1;
    check(rgb == 24'hFFFFFF, "pipelined media error text");
    $display("PASS: SECONDARY emergency bitmap, wait and media placeholders");
    $finish;
end
endmodule

`default_nettype wire
