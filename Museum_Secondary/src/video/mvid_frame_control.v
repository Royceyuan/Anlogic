`timescale 1ns/1ps
`default_nettype none
// Owned slots: writing -> SDRAM drained + SD CRC done -> queued ->
// FPS due -> vertical blank handover -> old display slot can be reused.
module mvid_frame_control #(
    parameter integer CLOCK_HZ=100_000_000,FRAME_BYTES=460800,FPS=30,
    parameter integer VIDEO_BASE=1843200,SLOTS=2,THIRD_BASE=0,STREAM_CONTROL=0
)(
    input wire clk,rst_n,pause,
    input wire stream_hold,stream_clear,
    output wire stream_idle,
    input wire file_ready,movie_done,byte_valid,
    input wire [31:0] frame_epoch,
    output reg [31:0] front_epoch,
    output reg front_valid,
    input wire [7:0] byte_data,input_error,
    output reg movie_start,
    output reg write_req,write_en,
    output wire [20:0] write_base,write_len,
    output reg [31:0] write_data,
    input wire write_ack,write_finish,write_full,
    input wire pixel_clk,pixel_rst_n,vblank,
    output reg display_valid,frame_begin,
    output wire [20:0] display_base,
    output reg [31:0] displayed_frames,
    output reg [7:0] error
);
localparam WAIT_FILE=0,ACK=1,ACK_LOW=2,LOAD=3,FLUSH=4,FAILED=7;
reg [2:0] state;
reg [1:0] slot,published_slot;
reg publish_toggle,finished_seen,movie_seen;
reg [1:0] ack_sync,finish_sync,display_ack_sync;
reg display_ack;
reg [1:0] display_slot,front_slot,next_publish;
reg [2:0] occupied,ready_slots;
reg pending;
reg [31:0] published_epoch;
reg [1:0] toggle_sync,slot_meta,slot_sync,pause_sync;
reg [26:0] rate_phase;
reg due;
reg [23:0] bytes_received;
reg [23:0] pack;
wire hold_stream=STREAM_CONTROL&&stream_hold;
wire clear_stream=STREAM_CONTROL&&stream_clear;
assign stream_idle=state==WAIT_FILE&&!pending&&!movie_start&&!write_en;
assign write_len=FRAME_BYTES/4;
function [20:0] slot_base;
    input [1:0] index;
    begin slot_base=index==2?THIRD_BASE:VIDEO_BASE+(index==1?FRAME_BYTES/4:0);end
endfunction
function [1:0] next_slot;
    input [1:0] index;
    begin next_slot=index==SLOTS-1?0:index+1'b1;end
endfunction
assign write_base=slot_base(slot);
assign display_base=slot_base(display_slot);
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        state<=WAIT_FILE;slot<=0;published_slot<=0;publish_toggle<=0;
        ack_sync<=0;finish_sync<=0;display_ack_sync<=0;movie_start<=0;write_req<=0;
        write_en<=0;write_data<=0;error<=0;rate_phase<=0;due<=1;
        bytes_received<=0;pack<=0;finished_seen<=0;movie_seen<=0;
        occupied<=0;ready_slots<=0;front_slot<=0;next_publish<=0;front_valid<=0;pending<=0;
        front_epoch<=0;published_epoch<=0;
    end else begin
        ack_sync<={ack_sync[0],write_ack};finish_sync<={finish_sync[0],write_finish};
        display_ack_sync<={display_ack_sync[0],display_ack};movie_start<=0;write_en<=0;
        if(!pause)begin
            if(rate_phase>=CLOCK_HZ-FPS)begin rate_phase<=rate_phase-(CLOCK_HZ-FPS);due<=1;end
            else rate_phase<=rate_phase+FPS;
        end
        // A published slot stays owned until the pixel domain confirms it.
        if(pending&&display_ack_sync[1]==publish_toggle)begin
            if(STREAM_CONTROL&&(!front_valid||front_epoch!=published_epoch))begin
                rate_phase<=0;due<=0;
            end
            if(front_valid)occupied[front_slot]<=0;
            front_slot<=published_slot;front_valid<=1;pending<=0;front_epoch<=published_epoch;
        end
        if(!pending&&due&&!pause&&!hold_stream&&ready_slots[next_publish]&&
                error==0&&input_error==0&&!(write_en&&write_full))begin
            published_slot<=next_publish;publish_toggle<=!publish_toggle;published_epoch<=frame_epoch;
            ready_slots[next_publish]<=0;next_publish<=next_slot(next_publish);
            pending<=1;due<=0;
        end
        if(write_en&&write_full)begin error<=1;state<=FAILED;end
        else if(input_error!=0)begin error<=2;state<=FAILED;end
        else case(state)
            WAIT_FILE:if(file_ready&&!pause&&!hold_stream&&!occupied[slot])begin
                occupied[slot]<=1;write_req<=1;finished_seen<=0;movie_seen<=0;state<=ACK;
            end
            ACK:if(ack_sync[1])begin write_req<=0;state<=ACK_LOW;end
            ACK_LOW:if(!ack_sync[1])begin
                bytes_received<=0;movie_start<=1;state<=LOAD;
            end
            LOAD,FLUSH:begin
                if(finish_sync[1])finished_seen<=1;
                if(byte_valid&&state==LOAD)begin
                    if(bytes_received>=FRAME_BYTES)begin error<=3;state<=FAILED;end
                    else begin
                        pack<={pack[15:0],byte_data};bytes_received<=bytes_received+1'b1;
                        if(bytes_received[1:0]==3)begin write_en<=1;write_data<={pack,byte_data};end
                    end
                end
                if(movie_done)begin
                    if(bytes_received!=FRAME_BYTES)begin error<=4;state<=FAILED;end
                    else begin movie_seen<=1;state<=FLUSH;end
                end
                if(finished_seen&&movie_seen)begin
                    ready_slots[slot]<=1;slot<=next_slot(slot);state<=WAIT_FILE;
                end
            end
            FAILED:begin write_req<=0;write_en<=0;end
        endcase
        // Only after SD/SDRAM drainage and pixel-domain acknowledgement: discard
        // queued old-file frames, but NEVER release the currently scanned slot.
        if(clear_stream&&stream_idle)begin
            slot<=front_valid&&front_slot==0?1:0;
            next_publish<=front_valid&&front_slot==0?1:0;
            occupied<=front_valid?(3'b001<<front_slot):0;
            ready_slots<=0;rate_phase<=0;due<=1;state<=WAIT_FILE;
            bytes_received<=0;finished_seen<=0;movie_seen<=0;
            movie_start<=0;write_req<=0;write_en<=0;
        end
    end
end
always @(posedge pixel_clk or negedge pixel_rst_n)begin
    if(!pixel_rst_n)begin
        toggle_sync<=0;slot_meta<=0;slot_sync<=0;pause_sync<=0;display_ack<=0;display_slot<=0;
        display_valid<=0;frame_begin<=0;displayed_frames<=0;
    end else begin
        toggle_sync<={toggle_sync[0],publish_toggle};slot_meta<=published_slot;slot_sync<=slot_meta;
        pause_sync<={pause_sync[0],pause};frame_begin<=0;
        if(vblank)begin
            if((!pause_sync[1]||STREAM_CONTROL)&&toggle_sync[1]!=display_ack)begin
                display_slot<=slot_sync;display_ack<=toggle_sync[1];display_valid<=1;
                displayed_frames<=displayed_frames+1'b1;frame_begin<=1;
            end else if(display_valid)frame_begin<=1;
        end
    end
end
endmodule
`default_nettype wire
