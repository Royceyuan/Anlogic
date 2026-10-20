`timescale 1ns/1ps
`default_nettype none
// Atomic two-slot ownership: writing -> SDRAM drained + SD CRC done ->
// 30 Hz due -> vertical blank handover -> old display slot can be reused.
module mvid_frame_control #(
    parameter integer CLOCK_HZ=100_000_000,FRAME_BYTES=460800,
    parameter integer VIDEO_BASE=1843200
)(
    input wire clk,rst_n,pause,
    input wire file_ready,movie_done,byte_valid,
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
localparam WAIT_FILE=0,ACK=1,ACK_LOW=2,LOAD=3,FLUSH=4,DUE=5,HANDOVER=6,FAILED=7;
reg [2:0] state;
reg slot,published_slot,publish_toggle,finished_seen,movie_seen;
reg [1:0] ack_sync,finish_sync,display_ack_sync;
reg display_ack,display_slot;
reg [1:0] toggle_sync,slot_sync,pause_sync;
reg [26:0] rate_phase;
reg due;
reg [23:0] bytes_received;
reg [23:0] pack;
assign write_len=FRAME_BYTES/4;
assign write_base=VIDEO_BASE+(slot?FRAME_BYTES/4:0);
assign display_base=VIDEO_BASE+(display_slot?FRAME_BYTES/4:0);
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        state<=WAIT_FILE;slot<=0;published_slot<=0;publish_toggle<=0;
        ack_sync<=0;finish_sync<=0;display_ack_sync<=0;movie_start<=0;write_req<=0;
        write_en<=0;write_data<=0;error<=0;rate_phase<=0;due<=1;
        bytes_received<=0;pack<=0;finished_seen<=0;movie_seen<=0;
    end else begin
        ack_sync<={ack_sync[0],write_ack};finish_sync<={finish_sync[0],write_finish};
        display_ack_sync<={display_ack_sync[0],display_ack};movie_start<=0;write_en<=0;
        if(!pause)begin
            if(rate_phase>=CLOCK_HZ-30)begin rate_phase<=rate_phase-(CLOCK_HZ-30);due<=1;end
            else rate_phase<=rate_phase+30;
        end
        if(write_en&&write_full)begin error<=1;state<=FAILED;end
        else if(input_error!=0)begin error<=2;state<=FAILED;end
        else case(state)
            WAIT_FILE:if(file_ready&&!pause)begin write_req<=1;finished_seen<=0;movie_seen<=0;state<=ACK;end
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
                if(finished_seen&&movie_seen)state<=DUE;
            end
            DUE:if(due&&!pause)begin
                published_slot<=slot;publish_toggle<=!publish_toggle;due<=0;state<=HANDOVER;
            end
            HANDOVER:if(display_ack_sync[1]==publish_toggle)begin slot<=!slot;state<=WAIT_FILE;end
            FAILED:begin write_req<=0;write_en<=0;end
        endcase
    end
end
always @(posedge pixel_clk or negedge pixel_rst_n)begin
    if(!pixel_rst_n)begin
        toggle_sync<=0;slot_sync<=0;pause_sync<=0;display_ack<=0;display_slot<=0;
        display_valid<=0;frame_begin<=0;displayed_frames<=0;
    end else begin
        toggle_sync<={toggle_sync[0],publish_toggle};slot_sync<={slot_sync[0],published_slot};
        pause_sync<={pause_sync[0],pause};frame_begin<=0;
        if(vblank)begin
            if(!pause_sync[1]&&toggle_sync[1]!=display_ack)begin
                display_slot<=slot_sync[1];display_ack<=toggle_sync[1];display_valid<=1;
                displayed_frames<=displayed_frames+1'b1;frame_begin<=1;
            end else if(display_valid)frame_begin<=1;
        end
    end
end
endmodule
`default_nettype wire
