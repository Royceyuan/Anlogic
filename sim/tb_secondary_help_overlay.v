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
reg [23:0] base_rgb=24'h123456;
reg test_pass=0;
integer xx, yy, group_id, hits, left_hits, right_hits, side, dx, dy, checks=0;
reg [15:0] expected565;
reg [23:0] expected_rgb;
reg [287:0] codes;
reg [255:0] glyph;
reg [8:0] glyph_cell;
secondary_help_overlay dut (
    .clk(clk), .rst_n(rst_n), .de(de), .x(x), .y(y), .pre_x(pre_x), .pre_y(pre_y),
    .base_rgb(base_rgb), .switches_50m(switches),
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
        @(posedge clk); #1; x=u; y=v;
        @(posedge clk); #1;
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
        switches=8+group_id; frame(); hits=0; left_hits=0; right_hits=0;
        for(yy=0;yy<720;yy=yy+1) for(xx=0;xx<1280;xx=xx+1) begin
            sample(xx,yy);
            expected565=pattern(xx/8,yy/8);
            expected_rgb={expected565[15:11],expected565[15:13],
                          expected565[10:5],expected565[10:9],expected565[4:0],expected565[4:2]};
            if(((xx>=32 && xx<624) || (xx>=656 && xx<1248)) && yy>=80 && yy<640)
                expected_rgb=24'hf7f5ec;
            if(xx>=664 && xx<1240 && yy>=120+group_id*96 && yy<216+group_id*96)
                expected_rgb=24'he5eae1;
            if(xx>=32 && xx<1248 && yy>=656 && yy<704)
                expected_rgb=24'he5eae1;
            if(((xx>=64 && xx<576) || (xx>=672 && xx<1184)) && yy>=24 && yy<696) begin
                side=xx>=640;
                dx=xx-(side ? 672 : 64); dy=yy-24;
                codes=dut.help_line(dy/32,side,0,0,1);
                glyph_cell=codes >> ((dx/16)*9);
                glyph=dut.help_font_init(glyph_cell[7:0]*4+((dy%32)/8));
                if(glyph[((dy%8)*2+glyph_cell[8])*16+15-(dx%16)]) begin
                    hits=hits+1;
                    if(side) right_hits=right_hits+1; else left_hits=left_hits+1;
                    expected_rgb=24'h23302e;
                end
            end
            check(rgb===expected_rgb,"backdrop/font pipeline pixel mismatch");
            checks=checks+1;
        end
        check(hits>20000,"Chinese and ASCII text must both be visible");
        check(left_hits>10000 && right_hits>10000,"both board columns must contain text");
    end
    check(dut.help_line(4,0,0,0,1)==dut.help_line(4,0,2,0,1),"all main modes remain visible");
    check(dut.help_line(3,1,0,0,1)!=0 && dut.help_line(12,1,0,0,1)!=0,"all four remote groups visible");
    check(dut.help_line(19,0,0,0,1)==0,"spaced footer above communication");
    overview=0; manual=1; frame(); sample(64,24+20*32);
    check(dut.main_context==2,"manual main-key guide");
    manual=0; paused=1; frame();
    check(dut.main_context==1 && dut.controls_frame[4],"paused automatic guide");
    link=2; frame(); check(dut.controls_frame[3:2]==2,"lost-link indicator");
    check(dut.help_line(20,0,1,1,2)!=dut.help_line(20,0,1,1,1),"bottom link changes on loss");
    check(dut.help_line(20,1,1,1,1)!=dut.help_line(20,1,1,0,1),"bottom pause status changes");
    // Switches update only at the frame boundary, never mid-scan.
    switches=0; repeat(4) @(negedge clk); sample(1200,650);
    check(rgb!=24'h123456,"page should hold until frame boundary");
    frame(); sample(1200,650); check(rgb==24'h123456,"SW4 exit");
    // Continuous normal pixels and blanking are delayed together, not only
    // stationary samples used by the exhaustive glyph checker.
    for(xx=0;xx<1280;xx=xx+1) begin
        @(negedge clk); base_rgb=24'h100000+xx; de=xx[0];
        @(posedge clk); #1;
        check(rgb==(xx[0] ? 24'h100000+xx : 0),"normal pixel/DE pipeline");
    end
    @(negedge clk); base_rgb=24'h123456; de=1;
    switches=8; emergency=1; frame(); sample(1200,650);
    check(rgb==24'h123456,"emergency must override help");
    emergency=0; bitmap=1; frame(); sample(1200,650);
    check(rgb==24'h123456,"hold emergency bitmap until media returns");
    bitmap=0; sample(1200,650); check(rgb!=24'h123456,"return to help without reload");
    de=0; sample(1200,650); check(rgb==0,"blanking");
    test_pass=1;
    $display("PASS help overlay: %0d pixels, native split glyphs, two columns, four groups, bottom status, emergency, frame switch",checks);
    $finish;
end
initial begin #100000000; $fatal(1,"timeout"); end
endmodule
