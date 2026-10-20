`timescale 1ns/1ps
`default_nettype none
// Two source lines. 360 rows use 2x vertical repetition; 480 rows use 3:2.
// Both 640-wide formats fill 1280x720; no full-size expanded frame is stored.
module mvid_scale2x #(
    parameter integer WIDTH=640,HEIGHT=360
)(
    input wire clk,rst_n,frame_begin,
    input wire [20:0] frame_base,
    input wire de,hs,vs,
    input wire [10:0] x,
    input wire [9:0] y,
    output reg read_req,
    output reg [20:0] read_base,
    output wire [20:0] read_len,
    input wire read_ack,fifo_empty,fifo_valid,
    input wire [31:0] fifo_data,
    output wire read_en,
    output reg hs_o,vs_o,de_o,
    output reg [15:0] pixel,
    output reg underflow
);
localparam IDLE=0,FREE=1,ACK=2,ACK_LOW=3,DRAIN=4;
reg [2:0] state;
reg [31:0] lines[0:1023];
reg [1:0] line_ready;
reg [8:0] line_tag0,line_tag1,load_row;
reg [8:0] word_index;
reg [20:0] base;
reg inflight;
reg [1:0] ack_sync;
reg [8:0] source_row;
reg [1:0] repeat_phase;
wire [8:0] scan_row=HEIGHT==480?source_row:(y>>1);
wire bank=scan_row[0];
wire last_repeat=HEIGHT==480?(repeat_phase!=0):y[0];
wire correct_line=line_ready[bank]&&((bank?line_tag1:line_tag0)==scan_row);
assign read_len=WIDTH/2;
assign read_en=state==DRAIN&&!fifo_empty&&!inflight;
// Synchronous RAM read; control and odd/even pixel selection follow it.
reg [31:0] word;
reg half_d,hs_d,vs_d,de_d,valid_d;
always @(posedge clk) begin
    if(state==DRAIN&&fifo_valid) lines[{load_row[0],word_index}]<=fifo_data;
    word<=lines[{bank,x[10:2]}];
    half_d<=x[1];hs_d<=hs;vs_d<=vs;de_d<=de;valid_d<=correct_line;
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin hs_o<=1;vs_o<=1;de_o<=0;pixel<=0;end
    else begin hs_o<=hs_d;vs_o<=vs_d;de_o<=de_d;
        pixel<=valid_d?(half_d?word[15:0]:word[31:16]):16'hf81f;
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state<=IDLE;line_ready<=0;line_tag0<=0;line_tag1<=0;load_row<=0;
        word_index<=0;base<=0;inflight<=0;read_req<=0;read_base<=0;underflow<=0;ack_sync<=0;
        source_row<=0;repeat_phase<=0;
    end else begin
        ack_sync<={ack_sync[0],read_ack};
        if(de&&!correct_line) underflow<=1;
        if(de&&x==WIDTH*2-1) begin
            if(last_repeat)line_ready[bank]<=0;
            if(HEIGHT==480)begin
                repeat_phase<=repeat_phase==2?0:repeat_phase+1'b1;
                if(last_repeat)source_row<=source_row+1'b1;
            end
        end
        if(frame_begin) begin
            if(state!=IDLE&&state!=FREE) underflow<=1;
            line_ready<=0;base<=frame_base;load_row<=0;read_req<=0;inflight<=0;state<=FREE;
            source_row<=0;repeat_phase<=0;
        end else case(state)
            FREE:if(load_row<HEIGHT&&!line_ready[load_row[0]]) begin
                read_base<=base+(WIDTH==640?(({12'd0,load_row}<<8)+({12'd0,load_row}<<6)):
                    load_row*(WIDTH/2));read_req<=1;state<=ACK;
            end
            ACK:if(ack_sync[1]) begin read_req<=0;state<=ACK_LOW;end
            ACK_LOW:if(!ack_sync[1]) begin word_index<=0;inflight<=0;state<=DRAIN;end
            DRAIN:begin
                if(read_en) inflight<=1;
                if(fifo_valid) begin
                    inflight<=0;
                    if(word_index==WIDTH/2-1) begin
                        line_ready[load_row[0]]<=1;
                        if(load_row[0]) line_tag1<=load_row;else line_tag0<=load_row;
                        load_row<=load_row+1'b1;state<=FREE;
                    end else word_index<=word_index+1'b1;
                end
            end
        endcase
    end
end
endmodule
`default_nettype wire
