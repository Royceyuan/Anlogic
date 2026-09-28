`timescale 1ns/1ps
module tb_secondary_main5e_engineering_overlay;
reg clk=0, rst_n=0, enable=0;
always #5 clk=~clk;
reg [10:0] x=0,pre_x=0;
reg [9:0] y=0,pre_y=0;
wire [23:0] rgb;
secondary_main5e_engineering_overlay dut (
    .clk(clk), .rst_n(rst_n), .de(1'b1),
    .x(x), .y(y), .pre_x(pre_x), .pre_y(pre_y),
    .base_rgb(24'habcdef), .enable_50m(enable),
    .link_50m(1'b1),
    .heartbeat_50m(128'h010200010000008000000000000023f3),
    .display_50m(96'h000302030301000000000000),
    .diagnostic_50m(128'h010302010f0700000000000000000000),
    .result_50m(8'd0), .rgb(rgb)
);
initial begin
    repeat(3) @(negedge clk); rst_n=1;
    repeat(3) @(negedge clk);
    if(rgb!==24'habcdef) $fatal(1,"disabled page changed media");
    enable=1;
    repeat(3) @(negedge clk);
    x=0;y=0;
    @(negedge clk);
    x=100;y=150;pre_x=100;pre_y=150;
    @(negedge clk);
    if(rgb!==24'h1c3047) $fatal(1,"engineering background");
    x=80;y=54;pre_x=80;pre_y=54;
    @(negedge clk);
    if(rgb!==24'hffe0a6) $fatal(1,"engineering title glyph");
    if(!dut.hex_pixel_at(11'd488,11'd480,10'd132,10'd132,16'h1234,3'd4) ||
       !dut.hex_pixel_at(11'd516,11'd480,10'd132,10'd132,16'h1234,3'd4) ||
       !dut.hex_pixel_at(11'd544,11'd480,10'd132,10'd132,16'h1234,3'd4) ||
       !dut.hex_pixel_at(11'd588,11'd480,10'd132,10'd132,16'h1234,3'd4) ||
       dut.hex_pixel_at(11'd608,11'd480,10'd132,10'd132,16'h1234,3'd4))
        $fatal(1,"engineering hex positions");
    enable=0;
    repeat(3) @(negedge clk);
    x=0;y=0;
    @(negedge clk);
    if(rgb!==24'habcdef) $fatal(1,"engineering page did not close");
    $display("PASS tb_secondary_main5e_engineering_overlay");
    $finish;
end
initial begin #10000; $fatal(1,"timeout"); end
endmodule
