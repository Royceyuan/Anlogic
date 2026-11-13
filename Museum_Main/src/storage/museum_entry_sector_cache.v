`timescale 1ns / 1ps
`default_nettype none

// Cache three WAV sectors (373 stereo samples) and the subtitle header/first
// cue for each artifact. Cache identity is scoped to the mounted card and
// invalidated on a hard card reset. Parsers still traverse FAT normally.
module museum_entry_sector_cache #(
    parameter integer WITH_SUBTITLE = 1
) (
    input wire clk, rst_n,
    input wire [2:0] track,
    input wire [3:0] audio_sector, subtitle_sector,
    input wire audio_req, subtitle_req,
    input wire [7:0] card_data,
    input wire audio_card_valid, subtitle_card_valid,
    input wire audio_card_end, subtitle_card_end,
    input wire allow_replay,
    output wire audio_replay, subtitle_replay,
    output wire replay_busy,
    output wire [7:0] audio_data, subtitle_data,
    output wire audio_valid, subtitle_valid,
    output wire audio_end, subtitle_end
);

function [3:0] audio_page;
    input [2:0] id;
    input [1:0] sector;
    begin audio_page = {id,1'b0} + id + sector; end
endfunction
function [6:0] subtitle_page;
    input [2:0] id;
    input [3:0] sector;
    begin subtitle_page = {id,4'b0} + sector; end
endfunction

wire [3:0] aw = audio_page(track,audio_sector[1:0]);
wire [6:0] sw = subtitle_page(track,subtitle_sector);
reg [4:0] audio_present, subtitle_present;
reg [1:0] audio_next;
reg [3:0] subtitle_next;
reg [2:0] fill_track;
reg [8:0] audio_fill_byte, subtitle_fill_byte;
reg [3:0] audio_read_page;
reg [6:0] subtitle_read_page;
reg [8:0] read_byte;
reg reading, owner_subtitle;
reg [1:0] replay_phase;
reg [7:0] replay_data;
reg end_audio_q, end_subtitle_q;

wire audio_hit = audio_req && audio_sector<3 && track<5 &&
                 audio_present[track];
wire subtitle_hit = WITH_SUBTITLE && subtitle_req && subtitle_sector<14 && track<5 &&
                    subtitle_present[track];
wire want_audio = audio_hit;
wire want_subtitle = !want_audio && subtitle_hit;
assign audio_replay = (reading && !owner_subtitle) ||
                      (!reading && allow_replay && want_audio);
assign subtitle_replay = (reading && owner_subtitle) ||
                         (!reading && allow_replay && want_subtitle);
assign replay_busy = reading || end_audio_q || end_subtitle_q;
wire request_held = owner_subtitle ? subtitle_req : audio_req;
wire replay_valid = reading && replay_phase==2 && request_held;
wire replay_end = replay_valid && read_byte==9'd511;
wire [7:0] audio_q, subtitle_q;
wire write_audio = audio_card_valid && audio_sector<3 && track<5;
wire write_subtitle = WITH_SUBTITLE && subtitle_card_valid && subtitle_sector<14 && track<5;

assign audio_data = reading && !owner_subtitle ? replay_data : card_data;
assign subtitle_data = reading && owner_subtitle ? replay_data : card_data;
assign audio_valid = audio_card_valid || (replay_valid && !owner_subtitle);
assign subtitle_valid = subtitle_card_valid || (replay_valid && owner_subtitle);
// The original parsers observe the end on the cycle after the last byte.
assign audio_end = audio_card_end || end_audio_q;
assign subtitle_end = subtitle_card_end || end_subtitle_q;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        audio_present<=0; subtitle_present<=0;
        fill_track<=0; audio_next<=0; subtitle_next<=0;
        audio_fill_byte<=0; subtitle_fill_byte<=0;
        audio_read_page<=0; subtitle_read_page<=0; read_byte<=0;
        reading<=0; owner_subtitle<=0; replay_phase<=0; replay_data<=0;
        end_audio_q<=0; end_subtitle_q<=0;
    end else begin
        end_audio_q<=0; end_subtitle_q<=0;
        if (track!=fill_track) begin
            fill_track<=track;
            audio_next<=0;
            subtitle_next<=0;
        end
        if (audio_card_end || !audio_req) audio_fill_byte<=0;
        else if (write_audio) audio_fill_byte<=audio_fill_byte+1'b1;
        if (subtitle_card_end || !subtitle_req) subtitle_fill_byte<=0;
        else if (write_subtitle) subtitle_fill_byte<=subtitle_fill_byte+1'b1;
        if (write_audio && audio_fill_byte==0 && audio_sector==0) begin
            audio_present[track]<=0;
            audio_next<=0;
        end
        if (write_subtitle && subtitle_fill_byte==0 && subtitle_sector==0) begin
            subtitle_present[track]<=0;
            subtitle_next<=0;
        end
        if (write_audio && audio_fill_byte==511 && audio_sector=={2'd0,audio_next}) begin
            audio_next<=audio_next+1'b1;
            if (audio_sector==2) audio_present[track]<=1;
        end
        if (write_subtitle && subtitle_fill_byte==511 && subtitle_sector==subtitle_next) begin
            subtitle_next<=subtitle_next+1'b1;
            if (subtitle_sector==13) subtitle_present[track]<=1;
        end
        if (!reading) begin
            if (allow_replay && (want_audio || want_subtitle) &&
                !end_audio_q && !end_subtitle_q) begin
                reading<=1; owner_subtitle<=want_subtitle;
                audio_read_page<=aw; subtitle_read_page<=sw;
                read_byte<=0; replay_phase<=0;
            end
        end else if (!request_held || replay_end) begin
            reading<=0;
            end_audio_q<=replay_end && !owner_subtitle;
            end_subtitle_q<=replay_end && owner_subtitle;
        end else if (replay_phase==2) begin
            read_byte<=read_byte+1'b1;
            replay_phase<=0;
        end else begin
            replay_phase<=replay_phase+1'b1;
            if (replay_phase==1) replay_data<=owner_subtitle ? subtitle_q : audio_q;
        end
    end
end

genvar bank;
wire [7:0] audio_banks [0:4];
wire [7:0] subtitle_first [0:4];
wire [7:0] subtitle_last [0:15];
generate
    subtitle_bitmap_ram u_audio_first (
        .wr_clk(clk),.wr_en(write_audio && !aw[3]),
        .wr_addr({aw[2:0],audio_fill_byte}),.wr_data(card_data),
        .rd_clk(clk),.rd_addr({audio_read_page[2:0],read_byte}),
        .rd_data(audio_banks[0]));
    for (bank=0;bank<4;bank=bank+1) begin:g_audio
        subtitle_bitmap_ram #(.ADDR_WIDTH(10),.DEPTH(1024),.IMPLEMENT("9K")) u_ram (
            .wr_clk(clk),.wr_en(write_audio && aw[3] && aw[2:1]==bank),
            .wr_addr({aw[0],audio_fill_byte}),.wr_data(card_data),
            .rd_clk(clk),.rd_addr({audio_read_page[0],read_byte}),
            .rd_data(audio_banks[bank+1]));
    end
    if (WITH_SUBTITLE) begin:g_subtitle
        for (bank=0;bank<5;bank=bank+1) begin:g_first
            subtitle_bitmap_ram u_ram (
                .wr_clk(clk),.wr_en(write_subtitle && !sw[3] && sw[6:4]==bank),
                .wr_addr({sw[2:0],subtitle_fill_byte}),.wr_data(card_data),
                .rd_clk(clk),.rd_addr({subtitle_read_page[2:0],read_byte}),
                .rd_data(subtitle_first[bank]));
        end
        for (bank=0;bank<15;bank=bank+1) begin:g_last
            localparam [2:0] TRACK = bank/3;
            localparam [1:0] PAIR = bank%3;
            subtitle_bitmap_ram #(.ADDR_WIDTH(10),.DEPTH(1024),.IMPLEMENT("9K")) u_ram (
                .wr_clk(clk),.wr_en(write_subtitle && sw[3] && sw[6:4]==TRACK && sw[2:1]==PAIR),
                .wr_addr({sw[0],subtitle_fill_byte}),.wr_data(card_data),
                .rd_clk(clk),.rd_addr({subtitle_read_page[0],read_byte}),
                .rd_data(subtitle_last[bank]));
        end
    end
endgenerate
wire [3:0] subtitle_pair = {subtitle_read_page[6:4],1'b0} +
                           subtitle_read_page[6:4] + subtitle_read_page[2:1];
assign audio_q = audio_read_page[3] ? audio_banks[1+audio_read_page[2:1]] : audio_banks[0];
assign subtitle_q = !WITH_SUBTITLE ? 8'd0 : subtitle_read_page[3] ?
    subtitle_last[subtitle_pair] : subtitle_first[subtitle_read_page[6:4]];
endmodule

`default_nettype wire
