`timescale 1ns / 1ps
`default_nettype none

module tb_rgb888_adjust_styles;
reg [1:0] style=0;
wire [23:0] rgb_out;
reg [23:0] seen [0:3];
integer i;

rgb888_adjust dut (
    .de(1'b1), .rgb_in(24'h806040), .brightness_level(2'd0),
    .contrast_level(2'd0), .picture_style(style), .rgb_out(rgb_out)
);

initial begin
    for (i=0;i<4;i=i+1) begin
        style=i; #1; seen[i]=rgb_out;
    end
    if (seen[0]===seen[1] || seen[0]===seen[2] || seen[0]===seen[3] ||
        seen[1]===seen[2] || seen[1]===seen[3] || seen[2]===seen[3]) begin
        $display("FAIL styles not distinct %h %h %h %h",seen[0],seen[1],seen[2],seen[3]);
        $finish;
    end
    $display("PASS rgb style outputs %h %h %h %h",seen[0],seen[1],seen[2],seen[3]);
    $finish;
end
endmodule

`default_nettype wire
