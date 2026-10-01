`timescale 1ns/1ps
module tb_video_light_band;
    reg clk=0, rst_n=0, de=1, enable=1, closing=0;
    reg [10:0] x=0;
    reg [9:0] y=0;
    reg [2:0] mode=7;
    reg [7:0] progress=0;
    reg [23:0] rgb=24'h123456;
    wire [23:0] direct_rgb, piped_rgb;
    reg [23:0] e0=0,e1=0,e2=0,expected;
    integer p,r,c,d,step,radius,phase,abs_x,limit,edge_x,k,m;
    reg passed=0;
    always #5 clk=~clk;
    video_transition_mask #(.VIDEO_W(1280),.VIDEO_H(720)) direct (
        .clk(clk),.rst_n(rst_n),.rgb_in(rgb),.de(de),.x(x),.y(y),
        .mode(mode),.origin_index(3'd0),.progress(progress),.closing(closing),
        .overview_source(1'b0),.enable(enable),.rgb_out(direct_rgb));
    video_transition_mask #(.VIDEO_W(1280),.VIDEO_H(720),.PIPE_MASK_3(1)) piped (
        .clk(clk),.rst_n(rst_n),.rgb_in(rgb),.de(de),.x(x),.y(y),
        .mode(mode),.origin_index(3'd0),.progress(progress),.closing(closing),
        .overview_source(1'b0),.enable(enable),.rgb_out(piped_rgb));
    task check;
        begin
            step=closing ? (progress<32 ? 32-progress : 0) :
                 (progress>=64 ? 32 : progress>=32 ? progress-32 : 0);
            radius=step*360/32;
            d=y>=360 ? y-360 : 360-y;
            expected=rgb;
            if(enable && de && mode==7) begin
                if(step==32) expected=rgb;
                else expected=d<radius ? rgb : 0;
            end else if(enable && de && mode==6) begin
                phase=closing ? (progress & 31) :
                      progress>=16 ? ((progress & 31)-16)&31 : 0;
                if(phase>16) phase=16;
                step=closing ? 16-phase : phase;
                limit=step*64-step-(step/2);
                abs_x=x>=640 ? x-640 : 640-x;
                expected=(step>=16 || (step!=0 && abs_x+d<limit)) ? rgb : 0;
            end else if(enable && de && mode>=1 && mode<=3) begin
                phase=closing ? (progress & 31) :
                      progress>=16 ? ((progress & 31)-16)&31 : 0;
                if(phase>16) phase=16;
                step=closing ? 16-phase : phase;
                abs_x=x>=640 ? x-640 : 640-x;
                if(step==0) expected=0;
                else if(step<16) begin
                    if(mode==1) expected=x<step*80 ? rgb : 0;
                    else if(mode==2) expected=abs_x<step*40 ? rgb : 0;
                    else expected=(abs_x<step*40 && d<(step*45)/2) ? rgb : 0;
                end
            end
            #1;
            if(direct_rgb!==expected) $fatal(1,"band geometry p=%0d y=%0d close=%b",progress,y,closing);
            @(posedge clk);
            e2=e1; e1=e0; e0=expected;
            #1;
            if(piped_rgb!==e2) $fatal(1,"band pixel pipeline misaligned");
        end
    endtask
    initial begin
        repeat(3) @(negedge clk);
        rst_n=1;
        // Every row at every animation step; alternate left/right screen edges.
        for(c=0;c<2;c=c+1)
          for(p=0;p<=64;p=p+1)
            for(r=0;r<720;r=r+1) begin
                @(negedge clk); closing=c; progress=p; y=r; x=r[0] ? 1279 : 0;
                check;
            end
        // Compare direct and pipelined diamond geometry at every scan row
        // around both exact boundaries, including the hidden/full endpoints.
        mode=6;
        for(c=0;c<2;c=c+1)
          for(p=0;p<=32;p=p+1)
            for(r=0;r<720;r=r+1)
              for(k=0;k<7;k=k+1) begin
                @(negedge clk); closing=c; progress=p; y=r;
                step=c ? 16-(p>16 ? 16 : p) : (p<16 ? 0 : p-16);
                limit=step*64-step-(step/2);
                d=r>=360 ? r-360 : 360-r;
                edge_x=limit-d;
                case(k)
                    0:x=0; 1:x=1279; 2:x=640;
                    3:x=(640-edge_x-1)&2047; 4:x=(640-edge_x)&2047;
                    5:x=(640+edge_x-1)&2047; default:x=(640+edge_x)&2047;
                endcase
                check;
              end
        for(p=0;p<2048;p=p+1) begin
            @(negedge clk);
            progress=p&255; closing=p[8]; x=$random; y=$random;
            de=p[9]; enable=p[10];
            check;
        end
        // Linear masks share the original three-cycle latency, including
        // changing mode/progress, exact boundaries and blanking coordinates.
        de=1; enable=1;
        for(m=1;m<=3;m=m+1)
          for(c=0;c<2;c=c+1)
            for(p=0;p<=32;p=p+1)
              for(r=0;r<720;r=r+1)
                for(k=0;k<3;k=k+1) begin
                    @(negedge clk); mode=m;closing=c;progress=p;y=r;
                    step=c ? 16-(p>16 ? 16 : p) : (p<16 ? 0 : p-16);
                    case(k)
                        0:x=step*80;
                        1:x=(640-step*40-1)&2047;
                        default:x=(640+step*40)&2047;
                    endcase
                    check;
                end
        for(p=0;p<4096;p=p+1) begin
            @(negedge clk);mode=p%4;progress=p&255;closing=p[8];
            x=$random;y=$random;de=p[9];enable=p[10];check;
        end
        mode=7; de=1; enable=1;
        // The midpoint and adjacent boundary pixels must be black, even with
        // a nonblack source. Flush before testing a missing source RGB.
        repeat(3) begin @(negedge clk); progress=32; y=360; check; end
        for(r=359;r<=361;r=r+1) begin @(negedge clk); y=r; check; end
        @(negedge clk); rgb=0;
        repeat(20) begin check; @(negedge clk); end
        enable=0;
        repeat(4) begin check; @(negedge clk); end
        enable=1; de=0;
        repeat(4) begin check; @(negedge clk); end
        $display("PASS black-edge/diamond geometry, no midpoint light, blanking and 3-cycle alignment");
        passed=1;
        $finish;
    end
endmodule
