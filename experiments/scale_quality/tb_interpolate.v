`timescale 1ns/1ps
module tb_interpolate;
reg clk=0, rst_n=0, start=0;
always #10 clk=~clk;
reg [15:0] a,b,c,d;
reg [7:0] x,y;
wire busy_h,busy_b,done_h,done_b;
wire [15:0] out_h,out_b;
rgb565_interpolate #(.BILINEAR(0)) h(clk,rst_n,start,a,b,c,d,x,y,busy_h,done_h,out_h);
rgb565_interpolate #(.BILINEAR(1)) v(clk,rst_n,start,a,b,c,d,x,y,busy_b,done_b,out_b);
integer i,j,k,seed=12345,checks=0,cycles;
reg [15:0] expect_h,expect_b;
reg seen_h,seen_b;
reg test_pass=0;
function [15:0] golden;
    input integer bilinear;
    input [15:0] aa,bb,cc,dd;
    input integer xx,yy;
    integer n,shift,mask,c0,c1,c2,c3,result;
    begin
        golden=0;
        for(n=0;n<3;n=n+1) begin
            shift=(n==0)?11:(n==1)?5:0;
            mask=(n==1)?63:31;
            c0=(aa>>shift)&mask; c1=(bb>>shift)&mask;
            c2=(cc>>shift)&mask; c3=(dd>>shift)&mask;
            // Independent convex-weight formula, not the RTL difference form.
            if(bilinear) result=(c0*(256-xx)*(256-yy)+c1*xx*(256-yy)+c2*(256-xx)*yy+c3*xx*yy+32768)>>16;
            else result=(c0*(256-xx)+c1*xx+128)>>8;
            golden=golden|(result<<shift);
        end
    end
endfunction
task check;
    begin
        expect_h=golden(0,a,b,c,d,x,y); expect_b=golden(1,a,b,c,d,x,y);
        @(negedge clk); start=1;
        @(negedge clk); start=0; seen_h=0; seen_b=0; cycles=0;
        // Noise/start while busy must not replace the accepted neighbourhood.
        a=~a; b=~b; c=~c; d=~d; x=~x; y=~y;
        while(!seen_b && cycles<30) begin
            @(negedge clk); cycles=cycles+1;
            start=(cycles==2);
            if(done_h) begin
                if(out_h!==expect_h || cycles!=9) $fatal(1,"horizontal mismatch/latency %d %h %h",cycles,out_h,expect_h);
                seen_h=1;
            end
            if(done_b) begin
                if(out_b!==expect_b || cycles!=27) $fatal(1,"bilinear mismatch/latency %d %h %h",cycles,out_b,expect_b);
                seen_b=1;
            end
        end
        start=0;
        if(!seen_h || !seen_b || busy_h || busy_b) $fatal(1,"timeout/busy");
        @(negedge clk);
        if(done_h || done_b || out_h!==expect_h || out_b!==expect_b) $fatal(1,"done pulse/output hold");
        checks=checks+1;
    end
endtask
initial begin
    repeat(3) @(negedge clk); rst_n=1;
    // All RGB565 constant colours preserve exactly at varying fractions.
    for(i=0;i<65536;i=i+1) begin
        a=i; b=i; c=i; d=i; x=i; y=i>>8; check;
    end
    // All fractions for an opposing RGB edge, including 0 and 255 endpoints.
    for(i=0;i<256;i=i+1) for(j=0;j<256;j=j+1) begin
        a=16'hf800; b=16'h07ff; c=16'h001f; d=16'hffe0; x=i; y=j; check;
    end
    for(i=0;i<10000;i=i+1) begin
        a=$random(seed); b=$random(seed); c=$random(seed); d=$random(seed);
        x=$random(seed); y=$random(seed); check;
    end
    // Abort at every bilinear processing cycle; immediately reuse afterwards.
    for(k=0;k<27;k=k+1) begin
        @(negedge clk); start=1;
        @(negedge clk); start=0;
        repeat(k) @(negedge clk);
        rst_n=0; @(negedge clk);
        if(busy_h || busy_b || done_h || done_b || out_h || out_b) $fatal(1,"reset failed");
        rst_n=1; a=16'hffff; b=0; c=0; d=16'hffff; x=128; y=128; check;
    end
    test_pass=1;
    $display("PASS interpolation: %d neighbourhoods, horizontal 9 cycles, bilinear 27 cycles, reset/busy/output hold",checks);
    $finish;
end
endmodule
