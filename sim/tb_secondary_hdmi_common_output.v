`timescale 1ns/1ps
module tb_secondary_hdmi_common_output;
reg clk=0,clk50=0,rst_n=0,request_pc=0,clock_stable=0;
always #6.666667 clk=!clk;
always #10 clk50=!clk50;
reg [10:0] sx=0;
reg [9:0] sy=0;
always @(posedge clk)
    if(!rst_n) begin sx<=0;sy<=0;end
    else if(sx==1649) begin sx<=0;sy<=sy==749?0:sy+1'b1;end
    else sx<=sx+1'b1;
function [9:0] ctrl;
input [1:0] n;
begin case(n) 0:ctrl=10'h354;1:ctrl=10'h0ab;2:ctrl=10'h154;3:ctrl=10'h2ab;endcase end endfunction
function [9:0] terc;
input [3:0] n;
begin case(n)
    0:terc=10'h29c;1:terc=10'h263;2:terc=10'h2e4;3:terc=10'h2e2;
    4:terc=10'h171;5:terc=10'h11e;6:terc=10'h18e;7:terc=10'h13c;
    8:terc=10'h2cc;9:terc=10'h139;10:terc=10'h19c;11:terc=10'h2c6;
    12:terc=10'h28e;13:terc=10'h271;14:terc=10'h163;15:terc=10'h2c3;
endcase end endfunction
function [3:0] un_terc;
input [9:0] n;
integer k;
begin un_terc=0;for(k=0;k<16;k=k+1) if(n==terc(k[3:0])) un_terc=k[3:0];end endfunction
function [7:0] bch56;
input [55:0] data;
integer k;
reg [7:0] c;
begin c=0;for(k=0;k<56;k=k+1) c=(c>>1)^((c[0]^data[k])?8'h83:0);bch56=c;end endfunction
reg [29:0] source_words;
reg [31:0] hdr;
reg [63:0] sp_word[0:3];
reg [55:0] data;
reg [23:0] left_sample,right_sample;
reg [7:0] flags;
reg [3:0] b,g,r;
integer n,k;
always @* begin
    b=0;g=0;r=0;hdr=0;data=0;left_sample=0;right_sample=0;flags=0;n=0;
    source_words={10'h354,10'h354,ctrl({sy>=725&&sy<730,sx>=1390&&sx<1430})};
    for(k=0;k<4;k=k+1) sp_word[k]=0;
    if(sx<1280 && sy<720) source_words={10'h133,10'h133,10'h28e};
    else if(sx>=1288 && sx<1296)
        source_words={10'h0ab,10'h0ab,ctrl({sy>=725&&sy<730,sx>=1390&&sx<1430})};
    else if(sx==1296||sx==1297||sx==1362||sx==1363)
        source_words={10'h133,10'h133,terc({2'b11,sy>=725&&sy<730,sx>=1390&&sx<1430})};
    else if(sx>=1298 && sx<1362) begin
        n=(sx-1298)%32;
        // First packet AVI; second layout-0 four-sample LPCM. Payload sample
        // cadence is accelerated, not a 48kHz acoustic playback test.
        hdr=sx<1330?32'he40d0282:32'hd0000f02;
        for(k=0;k<4;k=k+1) begin
            if(sx<1330) data=k==0?56'h080067:0;
            else begin
                left_sample=24'h123456+k;right_sample=24'h654321+k;
                flags={^(right_sample)^1'b1,3'b100,^(left_sample)^1'b1,3'b100};
                data={flags,right_sample,left_sample};
            end
            sp_word[k]={bch56(data),data};
            g[k]=sp_word[k][2*n];r[k]=sp_word[k][2*n+1];
        end
        b={1'b1,hdr[n],sy>=725&&sy<730,sx>=1390&&sx<1430};
        source_words={terc(r),terc(g),terc(b)};
    end else if(sx>=1640 && sx<1648 && (sy<719||sy==749))
        source_words={10'h354,10'h0ab,10'h354};
    else if(sx>=1648 && (sy<719||sy==749)) source_words={10'h2cc,10'h133,10'h2cc};
end
wire ready,hs,vs,de,packet_data,keep_packet,pcm_packet,guard_band;
wire [10:0] x;
wire [9:0] y;
wire [29:0] pc_words;
wire [4:0] packet_index;
wire [31:0] silent_flags;
secondary_hdmi_pc_raster u_raster(.clk(clk),.rst_n(rst_n&&clock_stable),.symbols(source_words),
    .ready(ready),.delayed_symbols(pc_words),.hs(hs),.vs(vs),.de(de),.x(x),.y(y),
    .packet_data(packet_data),.keep_packet(keep_packet),.pcm_packet(pcm_packet),.guard_band(guard_band),
    .packet_index(packet_index),.silent_flags(silent_flags));
wire native_hs,native_vs,native_de,native_rst;
wire [23:0] native_rgb;
top_v66 #(.VIDEO_W(1280),.VIDEO_H(720),.SOURCE_W(1280),.SOURCE_H(720),.VIDEO_MODE_1280(1),
    .ADAPTIVE_BMP(1),.MULTI_IMAGE_BMP(1),.ENABLE_FADE(1),
    .SHARED_VIDEO_RASTER(1),.EXTERNAL_HDMI_PHY(1),.ENABLE_SECONDARY(1),.SECONDARY_HELP(1),
    .MULTI_FRAME_PRELOAD(1),.VIDEO_FRAME_COUNT(5),.SECONDARY_STREAMING(1),
    .H_FRONT(110),.H_SYNC(40),.H_BACK(220),.V_FRONT(5),.V_SYNC(5),.V_BACK(20)) u_display(
    .clk_50m(clk50),.key_n(4'hf),.sw(0),.shared_video_clk(clk),.shared_serial_clk(clk),
    .shared_clock_stable(clock_stable),
    .shared_raster_valid(ready),.shared_raster_hs(~hs),.shared_raster_vs(~vs),.shared_raster_de(de),
    .shared_raster_x(x),.shared_raster_y(y),.local_hs(native_hs),.local_vs(native_vs),
    .local_de(native_de),.local_rgb(native_rgb),.local_video_rst_n(native_rst),
    .secondary_cmd_valid(0),.secondary_cmd_type(0),.secondary_cmd_artifact_id(0),.secondary_cmd_mode(0),
    .secondary_cmd_emergency_active(0),.secondary_cmd_lecture_phase(0),.secondary_eng_heartbeat(0),
    .secondary_eng_display(0),.secondary_eng_diagnostic(0),.secondary_eng_result(0),
    .secondary_manual_mode(0),.secondary_manual_next(0),.secondary_help_switches(0),.secondary_eng_enable(0),
    .secondary_eng_link(0),.uart_rxd(1));
wire [29:0] local_words;
TMDSEncoder u_b(.D_I(native_rgb[7:0]),.C0_I(~native_hs),.C1_I(~native_vs),.DE_I(native_de),.CLK_I(clk),.RST_I(native_rst),.D_O(local_words[9:0]));
TMDSEncoder u_g(.D_I(native_rgb[15:8]),.C0_I(1'b0),.C1_I(1'b0),.DE_I(native_de),.CLK_I(clk),.RST_I(native_rst),.D_O(local_words[19:10]));
TMDSEncoder u_r(.D_I(native_rgb[23:16]),.C0_I(1'b0),.C1_I(1'b0),.DE_I(native_de),.CLK_I(clk),.RST_I(native_rst),.D_O(local_words[29:20]));
wire [39:0] out_words;
wire selected,aligned;
secondary_hdmi_common_symbols u_output(.clk(clk),.rst_n(rst_n&&ready),.request_pc(request_pc),.pc_ready(ready),
    .pc_symbols(pc_words),.local_symbols(local_words),.pc_hs(hs),.pc_vs(vs),.pc_de(de),
    .packet_data(packet_data),.keep_packet(keep_packet),.pcm_packet(pcm_packet),.guard_band(guard_band),
    .packet_index(packet_index),.silent_flags(silent_flags),.symbols(out_words),.external_selected(selected),.aligned(aligned));
reg [10:0] expected_x[0:8];
reg [9:0] expected_y[0:8];
reg [29:0] source_pipe[0:37];
integer j;
always @(posedge clk) begin
    expected_x[0]<=sx;expected_y[0]<=sy;source_pipe[0]<=source_words;
    for(j=1;j<9;j=j+1) begin expected_x[j]<=expected_x[j-1];expected_y[j]<=expected_y[j-1];end
    for(j=1;j<38;j=j+1) source_pipe[j]<=source_pipe[j-1];
end
integer raster_checks=0,pass_words=0,native_words=0,silent_packets=0,avi_packets=0;
reg checking=0,local_de_delay[0:2];
reg permission_d,packet_d,pcm_d,keep_d,video_d;
reg [4:0] index_d;
reg [29:0] native_d;
reg [31:0] out_header;
reg [63:0] out_sp[0:3];
reg [3:0] ob,og,orr;
always @(posedge clk) begin
    permission_d=u_output.allow_pc;native_d=local_words;
    packet_d=u_output.t[8];pcm_d=u_output.t[10];keep_d=u_output.t[9];index_d=u_output.t[7:3];video_d=u_output.t[2];
    local_de_delay[0]<=native_de;local_de_delay[1]<=local_de_delay[0];local_de_delay[2]<=local_de_delay[1];
    #1;
    if(ready && sy>730 && raster_checks<100000) begin
        if(x!==expected_x[8] || y!==expected_y[8]) $fatal(1,"raster mismatch x=%d y=%d expected=%d,%d",x,y,expected_x[8],expected_y[8]);
        if(de!==(x<1280&&y<720)) $fatal(1,"raster DE mismatch");
        raster_checks=raster_checks+1;
    end
    if(checking) begin
        if(!aligned) $fatal(1,"real native pipeline lost phase alignment");
        if((^out_words)===1'bx || out_words[39:30]!==10'b0000011111) $fatal(1,"invalid output/clock symbol");
        if(permission_d) begin
            if(out_words[29:0]!==source_pipe[37]) $fatal(1,"authorized AV changed got=%h expected=%h",out_words[29:0],source_pipe[37]);
            pass_words=pass_words+1;
        end else if(video_d) begin
            if(out_words[29:0]!==native_d) $fatal(1,"native pixels misaligned/PC leak");
            native_words=native_words+1;
        end
        if(packet_d && !permission_d) begin
            ob=un_terc(out_words[9:0]);og=un_terc(out_words[19:10]);orr=un_terc(out_words[29:20]);
            out_header[index_d]=ob[2];
            for(j=0;j<4;j=j+1) begin out_sp[j][index_d*2]=og[j];out_sp[j][index_d*2+1]=orr[j];end
            if(index_d==31 && silent_packets<3) $display("TRACE packet header=%h keep=%b pcm=%b raster_header=%h",out_header,keep_d,pcm_d,u_raster.header);
            if(index_d==31 && pcm_d) begin
                if(out_header[7:0]!=2) $fatal(1,"PCM header changed");
                for(j=0;j<4;j=j+1) begin
                    if(out_sp[j][47:0]!==0 || out_sp[j][63:56]!==bch56(out_sp[j][55:0]))
                        $fatal(1,"silent PCM samples/BCH wrong sp=%0d data=%h",j,out_sp[j]);
                    if(out_sp[j][51]!==^out_sp[j][50:48] || out_sp[j][55]!==^out_sp[j][54:52]) $fatal(1,"silent PCM parity wrong");
                end
                silent_packets=silent_packets+1;
            end else if(index_d==31 && keep_d && out_header[7:0]==8'h82) avi_packets=avi_packets+1;
        end
    end
end
reg test_pass=0;
initial begin
    #100;rst_n=1;clock_stable=1;
    force u_display.frame_ready_toggle=1;
    force u_display.published_media_index=0;
    force u_display.published_frame_index=0;
    force u_display.frame_valid=5'b00001;
    #500;
    release u_display.frame_ready_toggle;
    release u_display.published_media_index;
    release u_display.published_frame_index;
    release u_display.frame_valid;
    wait(aligned);wait(sx==100 && sy==740);checking=1;
    wait(sx==100 && sy==5);
    if(raster_checks<1000 || native_words<1000 || silent_packets<5 || avi_packets<5)
        $fatal(1,"native/silent carrier insufficient raster=%0d native=%0d pcm=%0d avi=%0d",raster_checks,native_words,silent_packets,avi_packets);
    $display("PASS PC raster matches complete 1650x750 source and actual native 25+3-stage pipeline");
    $display("PASS native image replaces unauthorized PC pixels while AVI and silent LPCM/BCH remain valid");
    request_pc=1;wait(selected);wait(sx==100 && sy==5);
    if(pass_words<1000) $fatal(1,"PC grant never passed actual AV words");
    $display("PASS authorized video/audio/header/BCH bit-exact with common clock, no output reset");
    // Revoke in ordinary control, so this test checks complete silent packets;
    // mid-packet cancellation is separately tested as an intentional discard.
    wait(sx==1380);@(negedge clk);request_pc=0;
    wait(!selected);wait(sx==100 && sy==740);
    $display("PASS STOP restores native without changing raster/carrier or publication tags");
    if(u_display.frame_ready_toggle!==1 || u_display.published_media_index!==0) $fatal(1,"media state was reset");
    checking=0;
    wait(sy==726 && sx==100);
    force u_display.frame_ready_toggle=0;
    force u_display.initial_frame_published=1;
    #40;
    release u_display.frame_ready_toggle;release u_display.initial_frame_published;
    clock_stable=0;
    #300;
    force u_display.video_read_req_ack=1;
    clock_stable=1;
    repeat(20) @(posedge clk);
    if(u_display.read_req_r) $fatal(1,"cached recovery accepted old read ACK");
    release u_display.video_read_req_ack;
    wait(u_display.read_req_r);
    wait(u_display.video_run);
    if(u_display.frame_ready_toggle!==0 || !u_display.initial_frame_published)
        $fatal(1,"clock recovery reset cached publication");
    $display("PASS clock-epoch recovery drains old read ACK and resumes cached toggle ZERO without TF reload");
    wait(aligned);wait(sx==100 && sy==740);checking=1;
    wait(sx==100 && sy==5);
    checking=0;rst_n=0;
    $display("PASS shared raster changes preserve media publication and do not reset SDRAM/TF");
    test_pass=1;$finish;
end
initial begin #120000000;$fatal(1,"common output timeout ready=%b aligned=%b selected=%b",ready,aligned,selected);end
endmodule
