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

// Compare every link-text pixel and its clipping edges against the original
// generic word renderer. The registered mask must retain its one-cycle delay.
task check_link_masks;
    integer state, px, py;
    reg [3:0] word_id;
    reg expected;
    begin
        for (state=0; state<4; state=state+1) begin
            link_state_50m = state;
            step(4); frame();
            word_id = (state == 1) ? 4'd3 : (state == 2) ? 4'd4 : 4'd2;
            for (py=679; py<=708; py=py+1) begin
                for (px=0; px<2048; px=px+1) begin
                    @(negedge clk);
                    pre_x = px; pre_y = py;
                    expected = dut.word_pixel(pre_x,pre_y,11'd840,10'd680,word_id);
                    step(1);
                    if (dut.link_pixel !== expected) begin
                        $display("FAIL: link mask state=%0d x=%0d y=%0d",state,px,py);
                        $fatal(1);
                    end
                end
            end
        end
        $display("PASS: all four link states preserve 245760 pixels and one-cycle timing");
    end
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
    step(4); frame();
    check(rgb == base_rgb, "hold current image until emergency bitmap switches");

    emergency_bitmap_video = 1'b1;
    step(4); frame();
    x = 50; y = 667; #1;
    check(rgb == base_rgb, "SD emergency bitmap keeps its lower safety text");
    x = 500; y = 275; base_rgb = 24'hFC2802; #1;
    check(rgb == 24'hFF7350, "new red evacuation route brightens");
    x = 433; y = 290; base_rgb = 24'hE70000; #1;
    check(rgb == 24'hFF7350, "new current-location marker brightens");
    x = 780; y = 577; base_rgb = 24'h016B2F; #1;
    check(rgb == 24'h52ED79, "new lower-right exit brightens");
    x = 950; y = 225; base_rgb = 24'h016B2F; #1;
    check(rgb == base_rgb, "legend outside map is unchanged");
    x = 500; y = 300; base_rgb = 24'hE8E2DA; #1;
    check(rgb == base_rgb, "museum floor plan is unchanged");
    repeat (30) frame();
    x = 500; y = 275; base_rgb = 24'hFC2802; #1;
    check(rgb == base_rgb, "route returns to original color after thirty frames");
    repeat (30) frame();
    check(rgb == 24'hFF7350, "route brightens again without reloading bitmap");
    base_rgb = 24'h123456;
    emergency_50m = 1'b0;
    step(4); frame();
    check(rgb == base_rgb, "SD bitmap held until the media slot changes");
    emergency_bitmap_video = 1'b0;
    media_ready_50m = 1'b0;
    media_error_50m = 1'b1;
    step(4); frame();
    x = 500; y = 400; #1;
    check(rgb == 24'h142033, "media error placeholder");
    pre_x = 410; pre_y = 312; step(1);
    x = 410; y = 312; #1;
    check(rgb == 24'hFFFFFF, "pipelined media error text");
    check_link_masks();
    $display("PASS: SECONDARY emergency bitmap, wait and media placeholders");
    $finish;
end
endmodule

`default_nettype wire
