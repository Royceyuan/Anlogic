`timescale 1ns/1ps
`default_nettype none
// Decode timing, never RGB/audio. Guard/TERC aliases in active RGB are not
// treated as islands without their preceding eight-character preamble.
module secondary_hdmi_pc_raster (
    input wire clk,rst_n,
    input wire [29:0] symbols,
    output wire ready,
    output wire [29:0] delayed_symbols,
    output wire hs,vs,de,
    output wire [10:0] x,
    output wire [9:0] y,
    output wire packet_data,keep_packet,pcm_packet,guard_band,
    output wire [4:0] packet_index,
    output wire [31:0] silent_flags
);
function [2:0] control;
input [9:0] code;
begin case(code)
    10'h354:control=4;10'h0ab:control=5;10'h154:control=6;10'h2ab:control=7;
    default:control=0;
endcase end endfunction
function [4:0] terc;
input [9:0] code;
begin case(code)
    10'h29c:terc=16;10'h263:terc=17;10'h2e4:terc=18;10'h2e2:terc=19;
    10'h171:terc=20;10'h11e:terc=21;10'h18e:terc=22;10'h13c:terc=23;
    10'h2cc:terc=24;10'h139:terc=25;10'h19c:terc=26;10'h2c6:terc=27;
    10'h28e:terc=28;10'h271:terc=29;10'h163:terc=30;10'h2c3:terc=31;
    default:terc=0;
endcase end endfunction
wire [2:0] cb=control(symbols[9:0]),cg=control(symbols[19:10]),cr=control(symbols[29:20]);
wire [4:0] tb=terc(symbols[9:0]),tg=terc(symbols[19:10]),tr=terc(symbols[29:20]);
wire controls=cb[2]&&cg[2]&&cr[2];
reg [3:0] video_pre,island_pre;
reg [1:0] guard;
reg video_active,island_active;
wire video_guard=video_pre==8 && symbols=={10'h2cc,10'h133,10'h2cc};
wire island_guard=(island_pre==8 || island_active) && tb[4] &&
    symbols[29:10]=={10'h133,10'h133};
wire active_now=video_active && !controls;
wire packet_now=island_active && tb[4]&&tg[4]&&tr[4];
reg [4:0] packet_count;
reg [7:0] header;
reg [31:0] flags_work,flags_complete;
reg header_keep,header_pcm;
reg sync_h,sync_v,anchor,seen_v_low;
reg locked;
reg [8:0] locked_pipe;
assign ready=locked_pipe[8];
reg [10:0] hpos;
reg [9:0] vpos;
wire sync_valid=controls || (island_active&&tb[4]) || island_guard;
wire next_h=controls?cb[0]:tb[0],next_v=controls?cb[1]:tb[1];
wire h_rise=sync_valid && next_h && !sync_h;
wire v_rise=seen_v_low && sync_valid && next_v && !sync_v;
// Metadata and raw words share this pipeline. Nine cycles allow the first
// header byte to be known BEFORE its first buffered payload symbol leaves.
reg [29:0] word_pipe[0:8];
reg [26:0] meta_pipe[0:8];
reg [6:0] packet_pipe[0:8];
reg emit_keep,emit_pcm;
integer i;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        video_pre<=0;island_pre<=0;guard<=0;video_active<=0;island_active<=0;
        packet_count<=0;header<=0;header_keep<=0;header_pcm<=0;
        flags_work<=0;flags_complete<=0;sync_h<=0;sync_v<=0;anchor<=0;seen_v_low<=0;
        hpos<=0;vpos<=0;locked<=0;locked_pipe<=0;emit_keep<=0;emit_pcm<=0;
        for(i=0;i<9;i=i+1) begin word_pipe[i]<=0;meta_pipe[i]<=0;packet_pipe[i]<=0;end
    end else begin
        if(sync_valid) begin sync_h<=next_h;sync_v<=next_v;end
        if(sync_valid && !next_v) seen_v_low<=1;
        if(v_rise) anchor<=1;
        // HS rising is the unambiguous x=1390 reference. First HS after VS
        // rising anchors y=725; active-video aliases never change this sync.
        if(h_rise) begin
            hpos<=1391;
            if(anchor || v_rise) begin vpos<=725;locked<=1;anchor<=0;end
        end else if(hpos==1649) begin hpos<=0;vpos<=vpos==749?0:vpos+1'b1;end
        else hpos<=hpos+1'b1;
        if(controls) begin
            video_active<=0;island_active<=0;guard<=0;packet_count<=0;
            if(cg==5 && cr==4) begin if(video_pre<8) video_pre<=video_pre+1'b1;end else video_pre<=0;
            if(cg==5 && cr==5) begin if(island_pre<8) island_pre<=island_pre+1'b1;end else island_pre<=0;
        end else begin
            if(video_guard) begin
                if(guard==1) begin video_active<=1;video_pre<=0;guard<=0;end
                else guard<=guard+1'b1;
            end else if(island_guard && !island_active) begin
                if(guard==1) begin island_active<=1;island_pre<=0;guard<=0;packet_count<=0;end
                else guard<=guard+1'b1;
            end else begin video_pre<=0;island_pre<=0;guard<=0;end
            if(packet_now) begin
                packet_count<=packet_count+1'b1;
                if(packet_count<8) header[packet_count[2:0]]<=tb[2];
                if(packet_count==7) begin
                    header_keep<={tb[2],header[6:0]}==8'h82 || {tb[2],header[6:0]}==8'h83 ||
                                 {tb[2],header[6:0]}==8'h03 || {tb[2],header[6:0]}==8'h81 ||
                                 {tb[2],header[6:0]}==8'h01;
                    header_pcm<={tb[2],header[6:0]}==8'h02;
                end
                if(packet_count>=24 && packet_count<=27)
                    for(i=0;i<4;i=i+1) begin
                        flags_work[i*8+(packet_count-24)*2]<=tg[i];
                        flags_work[i*8+(packet_count-24)*2+1]<=tr[i];
                    end
                if(packet_count==28) flags_complete<=flags_work;
            end
        end
        word_pipe[0]<=symbols;
        meta_pipe[0]<={sync_valid?next_v:sync_v,sync_valid?next_h:sync_h,
                      !h_rise&&hpos<1280&&vpos<720,
                      h_rise?11'd1390:hpos,(h_rise&&(anchor||v_rise))?10'd725:vpos,3'd0};
        packet_pipe[0]<={video_guard||island_guard,packet_now,packet_count};
        locked_pipe<={locked_pipe[7:0],locked||(h_rise&&(anchor||v_rise))};
        for(i=1;i<9;i=i+1) begin
            word_pipe[i]<=word_pipe[i-1];meta_pipe[i]<=meta_pipe[i-1];packet_pipe[i]<=packet_pipe[i-1];
        end
        if(packet_pipe[8][5] && packet_pipe[8][4:0]==0) begin emit_keep<=header_keep;emit_pcm<=header_pcm;end
    end
end
assign delayed_symbols=word_pipe[8];
assign {vs,hs,de,x,y}=meta_pipe[8][26:3];
assign packet_data=packet_pipe[8][5];
assign guard_band=packet_pipe[8][6];
assign packet_index=packet_pipe[8][4:0];
wire first_packet_word=packet_pipe[8][5]&&packet_pipe[8][4:0]==0;
assign keep_packet=first_packet_word?header_keep:emit_keep;
assign pcm_packet=first_packet_word?header_pcm:emit_pcm;
// Layout-0 LPCM flags, with parity recomputed for ZERO 24-bit samples.
genvar sp;
generate for(sp=0;sp<4;sp=sp+1) begin:g_flags
    wire [7:0] f=flags_complete[sp*8+:8];
    assign silent_flags[sp*8+:8]={^f[6:4],f[6:4],^f[2:0],f[2:0]};
end endgenerate
endmodule
`default_nettype wire
