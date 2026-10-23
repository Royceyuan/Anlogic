`timescale 1ns/1ps
`default_nettype none
// Status and drawing gates latch at blanking; media clocks never depend on SW4.
module secondary_offline_overlay(
    input wire clk,rst_n,frame_tick,
    input wire [23:0] status,
    input wire audio_valid,
    input wire [31:0] audio_data,
    output wire visible,
    input wire hs,vs,de,
    input wire [10:0] x,
    input wire [9:0] y,
    input wire [23:0] rgb,
    output reg hs_o,vs_o,de_o,
    output reg [23:0] rgb_o
);
`include "src/secondary/secondary_offline_font.vh"
reg [23:0] applied;
assign visible=!applied[2];
wire emergency=applied[3];
reg [167:0] line0,line1,line2,line3,text_line;
reg [2:0] text_row;
reg text_valid;
reg [10:0] text_x;
reg [9:0] text_y;
reg [3:0] col_q;
wire [6:0] glyph_code=text_line[(text_x[8:4])*7+:7];
wire [15:0] glyph_bits;
reg [10:0] glyph_address;
secondary_offline_font u_font(.clk(clk),.address(glyph_address),.data(glyph_bits));
wire wave_hs,wave_vs,wave_de;
wire [10:0] wave_x;
wire [9:0] wave_y;
wire [23:0] visualizer_rgb;
reg [23:0] base_rgb_s1,base_rgb_s2;
// Reuse the main-board visualizer with half-size geometry. Keep PCM history running
// while SW4 hides only the drawing; the bypass has the same two-pixel delay.
audio_visualizer_overlay #(.COMPACT(1)) u_wave(
    .clk(clk),.rst_n(rst_n),.sample_valid(audio_valid),
    .sample_left(audio_data[15:0]),.sample_right(audio_data[31:16]),
    .pause(!applied[0]||emergency),.emergency(1'b0),.frame_tick(frame_tick),
    .hs_i(hs),.vs_i(vs),.de_i(de),.x_i(x),.y_i(y),.rgb_i(rgb),
    .hs_o(wave_hs),.vs_o(wave_vs),.de_o(wave_de),.x_o(wave_x),.y_o(wave_y),.rgb_o(visualizer_rgb));
wire [23:0] wave_rgb=visible?visualizer_rgb:base_rgb_s2;
always @*begin
    text_valid=0;text_x=0;text_y=0;text_row=0;text_line=0;
    if(emergency)begin
        // EVAC already contains its own instruction layout. RTL text is the
        // immediate fallback only, while a complete EVAC front is unavailable.
        if(!applied[16])begin
        if(wave_x>=512&&wave_x<768&&wave_y>=80&&wave_y<112)begin
            text_valid=1;text_x=(wave_x-512)>>1;text_y=(wave_y-80)>>1;text_row=3;
        end else if(wave_x>=272&&wave_x<1008&&wave_y>=160&&wave_y<192)begin
            text_valid=1;text_x=(wave_x-272)>>1;text_y=(wave_y-160)>>1;text_row=4;
        end else if(wave_x>=272&&wave_x<1008&&wave_y>=208&&wave_y<240)begin
            text_valid=1;text_x=(wave_x-272)>>1;text_y=(wave_y-208)>>1;text_row=5;
        end
        text_line=offline_line(text_row,applied);
        end
    end else if(visible&&wave_x>=880&&wave_x<1264&&wave_y>=24&&wave_y<112)begin
        text_x=wave_x-880;text_y=(wave_y-24)%24;
        if(text_y<16)begin
            text_valid=1;
            if(wave_y<48)text_line=line0;else if(wave_y<72)text_line=line1;
            else if(wave_y<96)text_line=line2;else text_line=line3;
        end
    end
end
reg hs_q,vs_q,de_q,text_q,osd_q,emergency_q,emergency_ready_q,visible_q;
reg [23:0] rgb_q;
reg hs_s2,vs_s2,de_s2,text_s2,osd_s2,emergency_s2,emergency_ready_s2,visible_s2;
reg [23:0] rgb_s2;
reg [3:0] col_s2;
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        applied<=0;line0<=0;line1<=0;line2<=0;line3<=0;base_rgb_s1<=0;base_rgb_s2<=0;
        hs_q<=1;vs_q<=1;de_q<=0;text_q<=0;col_q<=0;rgb_q<=0;
        osd_q<=0;emergency_q<=0;emergency_ready_q<=0;visible_q<=1;
        glyph_address<=0;hs_s2<=1;vs_s2<=1;de_s2<=0;text_s2<=0;col_s2<=0;rgb_s2<=0;
        osd_s2<=0;emergency_s2<=0;emergency_ready_s2<=0;visible_s2<=1;
        hs_o<=1;vs_o<=1;de_o<=0;rgb_o<=0;
    end else begin
        if(frame_tick)begin
            applied<=status;line0<=offline_line(0,status);line1<=offline_line(1,status);
            line2<=offline_line(2,status);line3<=offline_line(6,status);
        end
        base_rgb_s1<=rgb;base_rgb_s2<=base_rgb_s1;
        hs_q<=wave_hs;vs_q<=wave_vs;de_q<=wave_de;rgb_q<=wave_rgb;
        text_q<=text_valid;col_q<=text_x[3:0];
        glyph_address<={glyph_code,text_y[3:0]};
        osd_q<=wave_x>=868&&wave_x<1276&&wave_y>=12&&wave_y<124;
        emergency_q<=emergency;emergency_ready_q<=applied[16];visible_q<=visible;
        hs_s2<=hs_q;vs_s2<=vs_q;de_s2<=de_q;text_s2<=text_q;col_s2<=col_q;rgb_s2<=rgb_q;
        osd_s2<=osd_q;emergency_s2<=emergency_q;emergency_ready_s2<=emergency_ready_q;visible_s2<=visible_q;
        hs_o<=hs_s2;vs_o<=vs_s2;de_o<=de_s2;
        if(!de_s2)rgb_o<=0;
        else if(text_s2&&glyph_bits[15-col_s2])rgb_o<=24'hfff5dc;
        else if(emergency_s2)rgb_o<=emergency_ready_s2?rgb_s2:24'h471010;
        else if(visible_s2&&osd_s2)rgb_o<={1'b0,rgb_s2[23:17],1'b0,rgb_s2[15:9],1'b0,rgb_s2[7:1]};
        else rgb_o<=rgb_s2;
    end
end
endmodule
`default_nettype wire
