`timescale 1ns / 1ps
module tb_rgb888_adjust_main5;
reg clk = 0;
reg rst_n = 0;
always #5 clk = ~clk;
reg de = 1;
reg [23:0] rgb = 24'h4080c0;
reg [2:0] b = 3, c = 2, s = 3, t = 3;
wire [23:0] out;
integer n;
function integer contrast_ref;
    input integer value, level;
    integer d;
    begin
        d = value - 128;
        case (level)
            0: contrast_ref = 128 + (d >>> 1);
            1: contrast_ref = 128 + d - (d >>> 2);
            3: contrast_ref = 128 + d + (d >>> 2);
            4: contrast_ref = 128 + d + (d >>> 1);
            default: contrast_ref = value;
        endcase
    end
endfunction
function integer sat_ref;
    input integer channel, luma, level;
    integer d;
    begin
        d = channel - luma;
        case (level)
            0: sat_ref = luma;
            1: sat_ref = luma + (d >>> 1);
            2: sat_ref = luma + d - (d >>> 2);
            4: sat_ref = luma + d + (d >>> 2);
            5: sat_ref = luma + d + (d >>> 1);
            default: sat_ref = channel;
        endcase
    end
endfunction
function [7:0] clip_ref;
    input integer value;
    begin
        if (value < 0) clip_ref = 0;
        else if (value > 255) clip_ref = 255;
        else clip_ref = value;
    end
endfunction
function [23:0] expected;
    input [23:0] pixel;
    input [2:0] bi, ci, si, ti;
    integer bo, toff, rr, gg, bb, yy;
    begin
        case (bi)
            0: bo=-48; 1: bo=-32; 2: bo=-16;
            4: bo=16; 5: bo=32; 6: bo=48;
            default: bo=0;
        endcase
        case (ti)
            0: toff=-24; 1: toff=-16; 2: toff=-8;
            4: toff=8; 5: toff=16; 6: toff=24;
            default: toff=0;
        endcase
        rr=contrast_ref(pixel[23:16],ci)+bo;
        gg=contrast_ref(pixel[15:8],ci)+bo;
        bb=contrast_ref(pixel[7:0],ci)+bo;
        yy=(rr >>> 2)+(gg >>> 1)+(bb >>> 2);
        expected={clip_ref(sat_ref(rr,yy,si)+toff),
                  clip_ref(sat_ref(gg,yy,si)),
                  clip_ref(sat_ref(bb,yy,si)-toff)};
    end
endfunction
rgb888_adjust_main5 dut (
    .clk(clk), .rst_n(rst_n),
    .de(de), .rgb_in(rgb), .brightness_index(b),
    .contrast_index(c), .saturation_index(s),
    .temperature_index(t), .rgb_out(out)
);
initial begin
    repeat (2) @(negedge clk); rst_n = 1;
    repeat (4) @(negedge clk);
    if (out !== rgb) $fatal(1, "standard preset changed source pixel");
    s = 0;
    repeat (4) @(negedge clk);
    if (out[23:16] !== out[15:8] || out[15:8] !== out[7:0])
        $fatal(1, "zero saturation is not grayscale");
    s = 3; t = 6;
    repeat (4) @(negedge clk);
    if (out !== 24'h5880a8) $fatal(1, "warm color temperature incorrect");
    t = 3; b = 0; rgb = 24'h080810;
    repeat (4) @(negedge clk);
    if (out !== 24'h000000) $fatal(1, "negative brightness did not clip");
    b = 6; rgb = 24'hf8f8f8;
    repeat (4) @(negedge clk);
    if (out !== 24'hffffff) $fatal(1, "positive brightness did not clip");
    de = 0;
    repeat (4) @(negedge clk);
    if (out !== 24'h000000) $fatal(1, "blanking not black");
    de = 1;
    for (n=0;n<4000;n=n+1) begin
        rgb=$random; b=$random; c=$random; s=$random; t=$random;
        repeat (4) @(negedge clk);
        if (out !== expected(rgb,b,c,s,t))
            $fatal(1, "color mismatch rgb=%h b=%d c=%d s=%d t=%d out=%h ref=%h",
                   rgb,b,c,s,t,out,expected(rgb,b,c,s,t));
    end
    $display("PASS: MAIN5 color order and endpoints");
    $finish;
end
endmodule
