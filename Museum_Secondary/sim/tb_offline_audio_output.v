`timescale 1ns/1ps
module tb_offline_audio_output;
reg clk=0,pixel_clk=0;always #5 clk=~clk;always #7 pixel_clk=~pixel_clk;
reg rst_n=0,pixel_rst_n=0,clear=0,consume=0,unmute=0;
reg [31:0] epoch=1,total_samples=1000,pcm_data=0;
reg [31:0] start_position=0;
reg pcm_valid=0,pcm_has_data=0;
wire pcm_request,muted_ack,audio_valid,missed_reply;
wire [31:0] position,audio_data;
integer sample_number=0,ticks=0,requests=0,received=0,last_value=0,previous_tick=0,cycles=0;
reg check_muted=1;
offline_audio_output #(.PIXEL_HZ(4000),.SAMPLE_HZ(8),.MUTE_SAMPLES(4)) dut(.*);
always @(posedge clk)begin
    pcm_valid<=pcm_request;pcm_has_data<=pcm_request;
    if(pcm_request)begin sample_number<=sample_number+1;pcm_data<={16'habcd,16'(sample_number+1)};requests<=requests+1;end
end
always @(negedge pixel_clk)begin
    cycles=cycles+1;
    if(audio_valid)begin
        ticks=ticks+1;
        if(previous_tick!=0&&cycles-previous_tick!=500)$fatal(1,"Sample clock discontinuity");
        previous_tick=cycles;
        if(check_muted&&audio_data!=0)$fatal(1,"Muted output leaked");
        if(audio_data!=0)begin
            if(audio_data[31:16]!=16'habcd||audio_data[15:0]<=last_value)$fatal(1,"PCM pair reordered/torn");
            last_value=audio_data[15:0];received=received+1;
        end
    end
end
task wait_ticks;
input integer count;
integer target;
begin target=ticks+count;wait(ticks>=target);@(negedge pixel_clk);end endtask
initial begin
    repeat(5)@(negedge clk);rst_n=1;pixel_rst_n=1;
    wait_ticks(6);if(!muted_ack||requests!=0)$fatal(1,"Initial mute/pause failed");
    consume=1;unmute=1;check_muted=0;wait_ticks(10);
    if(received<7||position<8||missed_reply)$fatal(1,"Audio handshake did not stream");
    begin:pause_continuity
        integer before_resume;
        consume=0;wait_ticks(3);before_resume=last_value;
        wait_ticks(4);
        if(last_value!=before_resume)$fatal(1,"Paused output advanced samples");
        consume=1;
        wait(last_value!=before_resume);@(negedge pixel_clk);
        if(last_value!=before_resume+1)$fatal(1,"Pause/resume dropped prefetched PCM");
    end
    unmute=0;wait_ticks(6);check_muted=1;
    if(!muted_ack)$fatal(1,"No applied zero-PCM acknowledgement");
    begin:paused
        integer saved;
        consume=0;wait_ticks(3);saved=position;wait_ticks(4);
        if(position!=saved)$fatal(1,"Paused sample position advanced");
    end
    @(negedge clk);clear=1;epoch=2;@(negedge clk);clear=0;
    wait_ticks(3);if(position!=0)$fatal(1,"Clear position failed");
    consume=1;unmute=1;check_muted=0;wait_ticks(8);
    if(missed_reply||received<12)$fatal(1,"No recovery after clear");
    $display("PASS audio CDC: exact sample cadence, stereo order, zero-PCM mute, pause, epoch clear, recovery");$finish;
end
initial begin #500000;$fatal(1,"Audio timeout");end
endmodule
