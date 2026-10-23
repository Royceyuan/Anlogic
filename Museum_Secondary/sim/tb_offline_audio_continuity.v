`timescale 1ns/1ps
// Actual 100MHz/75MHz/48kHz clocks. A frame becomes CRC-committed after a
// modeled 27ms card service interval, not an instantaneous PCM producer.
module tb_offline_audio_continuity;
reg clk=0,pixel_clk=0,rst_n=0,consume=0;
always #5 clk=~clk;always #6.666667 pixel_clk=~pixel_clk;
reg frame_begin=0,frame_done=0,pcm_valid=0;
reg [7:0] pcm_byte=0;
wire frame_accept,pcm_request,sample_valid,sample_has_data,underflow;
wire [31:0] sample_data,position,audio_data;
wire [1:0] error;
wire muted_ack,audio_valid,missed_reply;
mvid_pcm_commit pcm(.clk(clk),.rst_n(rst_n),.clear(1'b0),
    .frame_begin(frame_begin),.frame_has_audio(1'b1),.frame_done(frame_done),.frame_abort(1'b0),
    .pcm_valid(pcm_valid),.pcm_byte(pcm_byte),.frame_accept(frame_accept),
    .sample_req(pcm_request),.sample_valid(sample_valid),.sample_has_data(sample_has_data),
    .sample_data(sample_data),.underflow(underflow),.error(error));
offline_audio_output audio(.clk(clk),.rst_n(rst_n),.clear(1'b0),.consume(consume),.unmute(1'b1),
    .epoch(32'd0),.total_samples(32'd0),.start_position(32'd0),.pcm_request(pcm_request),
    .pcm_valid(sample_valid),.pcm_has_data(sample_has_data),.pcm_data(sample_data),.position(position),
    .muted_ack(muted_ack),.pixel_clk(pixel_clk),.pixel_rst_n(rst_n),
    .audio_valid(audio_valid),.audio_data(audio_data),.missed_reply(missed_reply));
function [31:0] sample_word;
input integer n;reg [15:0] left,right;
begin left=n%30000+1;right=-left;sample_word={right,left};end
endfunction
integer frame_number,p,s,checked=0;
reg started=0;
reg [31:0] word;
initial begin
    repeat(5)@(negedge clk);rst_n=1;
    for(frame_number=0;frame_number<5;frame_number=frame_number+1)begin
        wait(frame_accept);@(negedge clk);frame_begin=1;
        @(negedge clk);frame_begin=0;
        #26935001;@(negedge clk);
        for(s=0;s<1600;s=s+1)begin
            word=sample_word(frame_number*1600+s);
            for(p=0;p<4;p=p+1)begin pcm_valid=1;pcm_byte=word>>(p*8);@(negedge clk);end
        end
        pcm_valid=0;frame_done=1;@(negedge clk);frame_done=0;
        if(error||pcm.byte_count!=6400)$fatal(1,"Test source did not commit a complete PCM frame");
        repeat(4)@(negedge clk);consume=1;
    end
end
always @(negedge pixel_clk)if(rst_n&&audio_valid)begin
    if(audio_data!=0||started)begin
        started=1;
        if(audio_data!==sample_word(checked))$fatal(1,"PCM gap/repeat/swap at %d: %h",checked,audio_data);
        checked=checked+1;
        if(checked==4800)begin
            if(underflow||error||missed_reply)$fatal(1,"PCM/CDC starvation");
            $display("PASS 4800 exact signed stereo pairs, 100MHz/75MHz/48kHz, 27ms frame service, no gaps/repeats/underflow");$finish;
        end
    end
end
initial begin #200000000;$fatal(1,"Audio continuity timeout checked=%d produced=%d error=%d committed=%b loading=%b consume=%b position=%d",checked,frame_number,error,pcm.committed,pcm.loading,consume,position);end
endmodule
