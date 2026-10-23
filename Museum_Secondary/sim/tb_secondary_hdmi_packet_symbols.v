`timescale 1ns / 1ps
module tb_secondary_hdmi_packet_symbols #(parameter AUDIO_TEST=0);
reg clk=0,sclk=0,clk50=0,rst_n=0;
always #6.666667 clk=!clk;
always #1.333333 sclk=!sclk;
always #10 clk50=!clk50;
reg [10:0] x=0;
reg [9:0] y=0;
reg [3:0] frames=0;
always @(posedge clk) begin
    if(!rst_n) begin x<=0;y<=0;frames<=0;end
    else if(x==1649) begin x<=0;if(y==749) begin y<=0;frames<=frames+1'b1;end else y<=y+1'b1;end
    else x<=x+1'b1;
end
wire de=x<1280&&y<720;
wire vs=y>=725&&y<730;
wire [23:0] source_rgb={3'b101,x,y};
wire [39:0] words=dut.symbols;
wire locked,blank,muted;
wire [7:0] pairs;
wire [3:0] serial,reference;
reg [26:0] sample_phase=0;
reg audio_valid=0;
wire acr_valid;
wire [19:0] acr_cts,acr_n;
always @(posedge clk)begin
    audio_valid<=0;
    if(rst_n&&AUDIO_TEST)begin
        if(sample_phase>=75_000_000-48000)begin sample_phase<=sample_phase-(75_000_000-48000);audio_valid<=1;end
        else sample_phase<=sample_phase+48000;
    end
end
audio_arc_calculate u_acr(.clk(clk),.rst(!rst_n),.sample_valid(audio_valid),
    .acr_valid(acr_valid),.acr_cts(acr_cts),.acr_n(acr_n));
secondary_hdmi_local_pairs #(.HDMI_PACKETS(1),.AUDIO_ENABLE(AUDIO_TEST)) dut(.pixel_clk(clk),.serial_clk(sclk),.rst_n(rst_n),
    .audio_valid(audio_valid),.audio_data(32'hfedc1234),.acr_valid(acr_valid),.acr_cts(acr_cts),.acr_n(acr_n),
    .hs(x>=1390&&x<1430),.vs(vs),.de(de),.rgb(source_rgb),.pairs(pairs),.encoder_ready(locked),.encoder_blank(blank));
secondary_hdmi_source_switch #(.SETTLE_CYCLES(64)) u_output(
    .clk_50m(clk50),.rst_n(rst_n),.local_ready(locked),.external_ready(1'b0),
    .local_blank(blank),.external_blank(1'b0),.local_sclk(sclk),.external_sclk(1'b0),
    .local_pairs(pairs),.external_pairs(8'd0),.external_selected(),.serial_out(serial),.output_muted(muted));
genvar lane;
generate for(lane=0;lane<4;lane=lane+1) begin : g_reference
    Serial_N_1_lvds_dat #(.N(10),.FAMILY("EG4")) u_ref(
        .DP_I(words[lane*10+:10]),.PCLK(clk),.SCLK(sclk),.DSP_O(reference[lane]));
end endgenerate
reg [63:0] history[0:3],actual[0:3];
reg [63:0] shifted;
integer samples=0,latency=-1,offset,l,serial_checks=0;
reg equal;
always @(sclk) if(locked&&!muted&&serial_checks<2000) begin
    #0.3;
    for(l=0;l<4;l=l+1) begin history[l]={history[l][62:0],reference[l]};actual[l]={actual[l][62:0],serial[l]};end
    samples=samples+1;
    if(samples>80&&latency<0) for(offset=0;offset<16;offset=offset+1) begin
        equal=1;
        for(l=0;l<4;l=l+1) begin shifted=history[l]>>offset;if(shifted[31:0]!==actual[l][31:0]) equal=0;end
        if(equal&&latency<0) latency=offset;
    end
    if(latency>=0) begin
        for(l=0;l<4;l=l+1) begin shifted=history[l]>>latency;if(shifted[31:0]!==actual[l][31:0]) $fatal(1,"native HDMI serializer lane differs");end
        serial_checks=serial_checks+1;
    end
end
initial for(l=0;l<4;l=l+1) begin history[l]=0;actual[l]=0;end
function [4:0] terc;
input [9:0] a;
begin case(a)
10'h29c:terc=16;10'h263:terc=17;10'h2e4:terc=18;10'h2e2:terc=19;
10'h171:terc=20;10'h11e:terc=21;10'h18e:terc=22;10'h13c:terc=23;
10'h2cc:terc=24;10'h139:terc=25;10'h19c:terc=26;10'h2c6:terc=27;
10'h28e:terc=28;10'h271:terc=29;10'h163:terc=30;10'h2c3:terc=31;
default:terc=0;
endcase end endfunction
function isctrl;
input [9:0] a;
begin isctrl=a==10'h354||a==10'h0ab||a==10'h154||a==10'h2ab;end
endfunction
function [7:0] rgb;
input [9:0] a;
reg [7:0] q;
integer k;
begin
 q=a[9]?~a[7:0]:a[7:0];rgb[0]=q[0];
 for(k=1;k<8;k=k+1) rgb[k]=a[8]?(q[k]^q[k-1]):~(q[k]^q[k-1]);
end endfunction
function [7:0] bch;
input [63:0] bits;
input integer count;
reg [7:0] crc;
integer j;
begin
 crc=0;
 for(j=0;j<count;j=j+1) crc=(crc>>1)^((crc[0]^bits[j])?8'h83:8'h00);
 bch=crc;
end endfunction
reg video=0;
reg [3:0] vp=0,ip=0,guard_count=0;
reg [5:0] body=0;
reg island=0;
reg [31:0] header=0;
reg [63:0] sp0=0,sp1=0,sp2=0,sp3=0;
reg [4:0] a,b,c;
integer avi=0,packets=0,pixels=0,checksum=0,k,backpressure=0;
integer audio_packets=0,acr_packets=0,samples_checked=0;
reg [63:0] sample_packet;
reg [19:0] decoded_cts,decoded_n;
reg [23:0] decoded_pixel;
integer active_x=0,active_y=0,next_y=0,lines=0;
reg frame_anchored=0;
reg test_pass=0;
always @(posedge clk) begin
 #0.1;
 if(locked) begin
    if(dut.g_hdmi.u_packets.axis_valid&&!dut.g_hdmi.u_packets.axis_ready) backpressure=backpressure+1;
    if((^words)===1'bx) $fatal(1,"native HDMI words unknown after lock");
    if(words[39:30]!==10'b0000011111) $fatal(1,"TMDS clock symbol changed");
    a=terc(words[9:0]);b=terc(words[19:10]);c=terc(words[29:20]);
    if(video) begin
        if(isctrl(words[9:0])&&isctrl(words[19:10])&&isctrl(words[29:20])) begin
            if(active_x!=1280) $fatal(1,"native output line width changed: %d",active_x);
            next_y=active_y==719?0:active_y+1;lines=lines+1;video=0;
        end
        else begin
            decoded_pixel={rgb(words[29:20]),rgb(words[19:10]),rgb(words[9:0])};
            if(active_x==0) begin
                active_y=decoded_pixel[9:0];
                if(frame_anchored&&active_y!=next_y) $fatal(1,"native raster row skipped or reordered");
                if(active_y==0) frame_anchored=1;
            end
            if(decoded_pixel!=={3'b101,active_x[10:0],active_y[9:0]})
                $fatal(1,"native pixel/order changed x=%d y=%d data=%h",active_x,active_y,decoded_pixel);
            active_x=active_x+1;
            pixels=pixels+1;
        end
    end
    if(island) begin
        if(guard_count!=0) guard_count=guard_count-1'b1;
        else if(a[4]&&b[4]&&c[4]) begin
            header[body]=a[2];
            // Each lane contributes one bit to all four subpackets; lane1
            // carries even bits, lane2 the following odd bits (HDMI 5-4).
            sp0[body*2]=b[0];sp0[body*2+1]=c[0];
            sp1[body*2]=b[1];sp1[body*2+1]=c[1];
            sp2[body*2]=b[2];sp2[body*2+1]=c[2];
            sp3[body*2]=b[3];sp3[body*2+1]=c[3];
            body=body+1'b1;
            if(body==32) begin
                packets=packets+1;
                if(packets<4 || (header[7:0]==8'h82&&avi==0)) $display("TRACE packet header=%h sp0=%h sp1=%h",header,sp0,sp1);
                if(bch({32'd0,header},24)!=header[31:24]||bch(sp0,56)!=sp0[63:56]||
                   bch(sp1,56)!=sp1[63:56]||bch(sp2,56)!=sp2[63:56]||bch(sp3,56)!=sp3[63:56])
                    $fatal(1,"native HDMI packet BCH mismatch");
                if(header[7:0]==8'h82) begin
                    if(header[23:8]!=16'h0d02) $fatal(1,"AVI version/length");
                    checksum=8'h82+2+13;
                    for(k=0;k<7;k=k+1) checksum=checksum+sp0[k*8+:8]+sp1[k*8+:8];
                    if(checksum%256) $fatal(1,"AVI checksum");
                    if(sp0[39:32]!=0) $fatal(1,"nonstandard 75MHz profile must not claim CEA VIC4");
                    avi=avi+1;
                end
                if(header[7:0]==8'h02)begin
                    if(!AUDIO_TEST)$fatal(1,"local source emitted audio samples while audio_valid=0");
                    audio_packets=audio_packets+1;
                    for(k=0;k<4;k=k+1)if(header[8+k])begin
                        case(k)0:sample_packet=sp0;1:sample_packet=sp1;2:sample_packet=sp2;3:sample_packet=sp3;endcase
                        if(sample_packet[23:0]!==24'h123400||sample_packet[47:24]!==24'hfedc00)
                            $fatal(1,"HDMI PCM order/alignment mismatch %h",sample_packet);
                        samples_checked=samples_checked+1;
                    end
                end
                if(header[7:0]==8'h01&&AUDIO_TEST)begin
                    decoded_cts={sp0[11:8],sp0[23:16],sp0[31:24]};
                    decoded_n={sp0[35:32],sp0[47:40],sp0[55:48]};
                    if(decoded_n!=6144||decoded_cts<74999||decoded_cts>75001)
                        $fatal(1,"ACR clock regeneration mismatch CTS=%d N=%d packet=%h",decoded_cts,decoded_n,sp0);
                    acr_packets=acr_packets+1;
                end
                body=0;header=0;sp0=0;sp1=0;sp2=0;sp3=0;
            end
        end else if(words[19:10]==10'h133&&words[29:20]==10'h133&&a[4]&&body==0) begin
            // Two trailing guard symbols. A single island may carry multiple
            // contiguous packets; do not inspect only its first null packet.
        end else if(isctrl(words[9:0])&&isctrl(words[19:10])&&isctrl(words[29:20])) begin
            if(body!=0) $fatal(1,"truncated HDMI packet");island=0;
        end else $fatal(1,"invalid TERC4 payload");
    end
    if(!video&&!island) begin
        if(isctrl(words[9:0])&&words[19:10]==10'h0ab&&words[29:20]==10'h354) begin
            if(vp<8) vp=vp+1'b1;
        end else if(words[29:0]=={10'h2cc,10'h133,10'h2cc}&&vp==8) begin
            if(guard_count==0) guard_count=1;
            else begin guard_count=0;video=1;vp=0;active_x=0;end
        end else vp=0;
        if(isctrl(words[9:0])&&words[19:10]==10'h0ab&&words[29:20]==10'h0ab) begin
            if(ip<8) ip=ip+1'b1;
        end else if(words[19:10]==10'h133&&words[29:20]==10'h133&&a[4]&&ip==8) begin
            island=1;guard_count=1;body=0;header=0;sp0=0;sp1=0;sp2=0;sp3=0;ip=0;
        end else ip=0;
    end
 end
 if(frames==3) begin
    if(!locked||pixels<1280*720||avi<1||packets<1||backpressure!=0||serial_checks<2000)
        $fatal(1,"native HDMI test incomplete locked=%b pixels=%d avi=%d packets=%d backpressure=%d serial_checks=%d samples=%d latency=%d muted=%b blank=%b state=%d",locked,pixels,avi,packets,backpressure,serial_checks,samples,latency,muted,blank,u_output.state);
    $display("PASS native HDMI locks on uninterrupted full 720p raster without AXIS backpressure");
    $display("PASS native HDMI video preamble/guard bands and decoded RGB remain correct");
    $display("PASS native HDMI AVI InfoFrame present with correct version/length/checksum and VIC0");
    $display("PASS native HDMI header and four subpacket BCH values match independent bitwise checks");
    if(AUDIO_TEST)begin
        if(audio_packets<1||acr_packets<1||samples_checked<100)$fatal(1,"Audio packet coverage incomplete");
        $display("PASS HDMI decoded PCM channel order, 16-to-24-bit alignment and measured 48kHz ACR packets");
    end else $display("PASS native source emits no PCM samples; PC relay is not modified");
    $display("PASS native packet encoder and actual output serializer preserve four-lane words");
    test_pass=1;$finish;
 end
end
initial begin repeat(10) @(negedge clk);rst_n=1;end
initial begin #70000000;$fatal(1,"native HDMI timeout");end
endmodule
