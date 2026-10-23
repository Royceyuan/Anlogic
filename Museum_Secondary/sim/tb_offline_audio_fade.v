`timescale 1ns/1ps
module tb_offline_audio_fade;
reg clk=0,pixel_clk=0,rst_n=0,pixel_rst_n=0,clear=0,consume=1,unmute=1;
reg [31:0] epoch=1,total_samples=10000,start_position=0,pcm_data=32'h80004000;
reg pcm_valid=0,pcm_has_data=0;
wire pcm_request,muted_ack,audio_valid,missed_reply;
wire [31:0] position,audio_data;
integer ticks=0,last_value=0,nonzero=0;
reg checking=1;
always #5 clk=~clk;always #7 pixel_clk=~pixel_clk;
offline_audio_output #(.PIXEL_HZ(4000),.SAMPLE_HZ(8),.MUTE_SAMPLES(4),.FADE_ENABLE(1)) dut(.*);
always @(posedge clk)begin pcm_valid<=pcm_request;pcm_has_data<=pcm_request;end
always @(negedge pixel_clk)if(audio_valid)begin
    ticks=ticks+1;
    if(checking&&audio_data!=0)begin
        if($signed(audio_data[15:0])<last_value||audio_data[15:0]>16384)
            $fatal(1,"Fade not monotonic/bounded");
        if($signed(audio_data[31:16])!=-2*$signed(audio_data[15:0]))$fatal(1,"Signed stereo gain mismatch");
        last_value=audio_data[15:0];nonzero=nonzero+1;
    end
end
initial begin
    repeat(4)@(negedge clk);rst_n=1;pixel_rst_n=1;
    wait(ticks>=270);@(negedge pixel_clk);
    if(last_value!=16384||nonzero<250||missed_reply)$fatal(1,"Fade never reached unity");
    checking=0;unmute=0;wait(muted_ack);repeat(1000)@(negedge pixel_clk);
    if(audio_data!=0)$fatal(1,"Mute emitted nonzero sample");
    $display("PASS signed stereo short fade-in reaches unity; revoke outputs zero PCM");$finish;
end
initial begin #3000000;$fatal(1,"Fade timeout");end
endmodule
