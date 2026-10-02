`timescale 1ns/1ps
module tb_secondary_help_overlay;
reg clk=0, write_clk=0, rst_n=0, de=1;
always #5 clk=~clk;
always #7 write_clk=~write_clk;
reg [10:0] x=0, pre_x=0, col=0, row=0;
reg [9:0] y=0, pre_y=0;
reg [3:0] switches=0;
reg manual=0, overview=1, paused=0, emergency=0, bitmap=0, ready=0;
reg [1:0] link=1;
reg wr=0;
reg [15:0] pixel=0;
wire [23:0] rgb;
reg test_pass=0;
integer xx, yy, group_id, hits, checks=0;
reg [15:0] expected565;
reg [23:0] expected_rgb;
reg [255:0] codes, glyph;
reg [7:0] code;
secondary_help_overlay dut (
    .clk(clk), .rst_n(rst_n), .de(de), .x(x), .y(y), .pre_x(pre_x), .pre_y(pre_y),
    .base_rgb(24'h123456), .switches_50m(switches),
    .manual_50m(manual), .overview_50m(overview), .paused_50m(paused),
    .link_50m(link), .emergency_50m(emergency), .emergency_bitmap_video(bitmap),
    .background_ready_50m(ready), .write_clk(write_clk), .write_en(wr),
    .write_row(row), .write_col(col), .write_pixel(pixel), .rgb(rgb)
);
function [15:0] pattern;
    input integer u,v;
    begin pattern={u[4:0],v[5:0],(u[4:0]^v[4:0])}; end
endfunction
task frame;
    begin
        @(negedge clk); x=0; y=0; pre_x=0; pre_y=0;
        repeat(4) @(negedge clk);
        x=1200; y=650; pre_x=1200; pre_y=650;
    end
endtask
task sample;
    input integer u,v;
    begin
        @(negedge clk); pre_x=u; pre_y=v;
        @(posedge clk); #1; x=u; y=v; #1;
    end
endtask
task check;
    input condition;
    input [511:0] message;
    begin if(!condition) $fatal(1,"%0s x=%0d y=%0d actual=%h expected=%h",message,x,y,rgb,expected_rgb); end
endtask
initial begin
    repeat(3) @(negedge clk); rst_n=1;
    frame(); sample(500,400);
    check(rgb==24'h123456,"SW4=0 passthrough");
    switches=8; frame(); sample(1200,650);
    check(rgb==24'hf2eee1,"missing backdrop must use pale fallback");
    // Real help loads emit 1280x720; capture only one pixel in each 8x8 block.
    for(yy=0;yy<90;yy=yy+1) for(xx=0;xx<160;xx=xx+1) begin
        @(negedge write_clk); wr=1; row=yy*8; col=xx*8; pixel=pattern(xx,yy);
    end
    @(negedge write_clk); wr=0; ready=1;
    for(group_id=0;group_id<4;group_id=group_id+1) begin
        switches=8+group_id; frame(); hits=0;
        for(yy=0;yy<720;yy=yy+1) for(xx=0;xx<1280;xx=xx+1) begin
            sample(xx,yy);
            expected565=pattern(xx/8,yy/8);
            expected_rgb={expected565[15:11],expected565[15:13],
                          expected565[10:5],expected565[10:9],expected565[4:0],expected565[4:2]};
            if(xx>=64 && xx<1088 && yy>=48 && yy<624) begin
                codes=dut.help_line((yy-48)/32,group_id,0,0,1);
                code=codes >> (((xx-64)/32)*8);
                glyph=dut.help_font_init(code);
                if(glyph[(((yy-48)%32)/2)*16+15-(((xx-64)%32)/2)]) begin
                    hits=hits+1;
                    expected_rgb=(((yy-48)/32)==0 || ((yy-48)/32)==3 || ((yy-48)/32)==8) ?
                                 24'h5b4525 : 24'h23302e;
                end
            end
            check(rgb===expected_rgb,"backdrop/font pipeline pixel mismatch");
            checks=checks+1;
        end
        check(hits>20000,"Chinese and ASCII text must both be visible");
    end
    overview=0; manual=1; frame(); sample(64,48+10*32);
    check(dut.main_context==2,"manual main-key guide");
    manual=0; paused=1; frame();
    check(dut.main_context==1 && dut.controls_frame[4],"paused automatic guide");
    link=2; frame(); check(dut.controls_frame[3:2]==2,"lost-link indicator");
    // Switches update only at the frame boundary, never mid-scan.
    switches=0; repeat(4) @(negedge clk); sample(1200,650);
    check(rgb!=24'h123456,"page should hold until frame boundary");
    frame(); sample(1200,650); check(rgb==24'h123456,"SW4 exit");
    switches=8; emergency=1; frame(); sample(1200,650);
    check(rgb==24'h123456,"emergency must override help");
    emergency=0; bitmap=1; frame(); sample(1200,650);
    check(rgb==24'h123456,"hold emergency bitmap until media returns");
    bitmap=0; sample(1200,650); check(rgb!=24'h123456,"return to help without reload");
    de=0; #1; check(rgb==0,"blanking");
    test_pass=1;
    $display("PASS help overlay: %0d pixels, four groups, cached background, Chinese, emergency, context, frame switch",checks);
    $finish;
end
initial begin #100000000; $fatal(1,"timeout"); end
endmodule
