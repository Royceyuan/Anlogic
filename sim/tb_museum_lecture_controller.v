`timescale 1ns / 1ps
`default_nettype none
module tb_museum_lecture_controller;
reg clk=0,rst_n=0,enable=1,overview_ready=0,confirm=0,key_pause=0,key_return=0;
reg preload_valid=0,audio_prepared=0,audio_frame_pulse=0,audio_stream_done=0;
reg audio_drained=0,load_accept=0,load_complete=0,load_error=0;
reg display_transition_busy=0;
reg scene_timing_valid=1;
reg [31:0] scene_cut1=1,scene_cut2=3,scene_cut3=4,scene_cut4=5;
reg [2:0] selected=0,preload_index=0,displayed_frame_slot=5;
reg [31:0] audio_total_frames=7;
wire load_request,load_detail,preloading,cache_ready,active,paused,finished;
wire audio_restart,media_error;
wire final_full_active;
wire [31:0] audio_frame_index;
wire [1:0] load_slot,detail_index,display_slot;
wire [2:0] load_frame_slot,load_artifact,artifact,display_frame_slot;
always #5 clk=~clk;
museum_lecture_controller #(.CLOCK_HZ(2)) dut(
 .clk(clk),.rst_n(rst_n),.enable(enable),.overview_ready(overview_ready),
 .confirm_pulse(confirm),.key_pause(key_pause),.key_return(key_return),
 .selected_index(selected),.preload_valid(preload_valid),.preload_index(preload_index),
 .audio_prepared(audio_prepared),.audio_frame_pulse(audio_frame_pulse),
 .audio_total_frames(audio_total_frames),.audio_stream_done(audio_stream_done),
 .audio_drained(audio_drained),.displayed_frame_slot(displayed_frame_slot),
 .scene_timing_valid(scene_timing_valid),
 .scene_cut1(scene_cut1),.scene_cut2(scene_cut2),.scene_cut3(scene_cut3),.scene_cut4(scene_cut4),
 .display_transition_busy(display_transition_busy),
 .load_request(load_request),.load_accept(load_accept),.load_complete(load_complete),
 .load_error(load_error),.load_slot(load_slot),.load_frame_slot(load_frame_slot),
 .load_artifact_index(load_artifact),.load_detail(load_detail),.detail_index(detail_index),
 .artifact_index(artifact),.preloading(preloading),.cache_ready(cache_ready),
 .lecture_active(active),.lecture_paused(paused),.lecture_finished(finished),
 .audio_restart(audio_restart),.display_slot(display_slot),
 .display_frame_slot(display_frame_slot),.media_error(media_error),
 .audio_frame_index(audio_frame_index),.final_full_active(final_full_active));
task accept_complete; begin
 @(negedge clk);load_accept=1; @(negedge clk);load_accept=0;
 @(negedge clk);load_complete=1; @(negedge clk);load_complete=0;
end endtask
task pulse_audio; begin
 @(negedge clk);audio_frame_pulse=1; @(negedge clk);audio_frame_pulse=0;
end endtask
task check_load;
 input [1:0] logical; input [2:0] physical; input [2:0] art;
 begin
  if(!load_request||load_slot!=logical||load_frame_slot!=physical||
     load_artifact!=art||load_detail!=(logical!=0)||detail_index!=logical)
   $fatal(1,"bad load logical=%0d physical=%0d art=%0d",logical,physical,art);
  accept_complete;
 end
endtask
integer i;
initial begin
 repeat(2)@(negedge clk);rst_n=1;selected=4;preload_index=4;preload_valid=1;
 repeat(2)@(negedge clk);if(preloading)$fatal(1,"early preload");
 overview_ready=1;@(negedge clk);
 for(i=0;i<4;i=i+1)check_load(i,i,4);
 if(!cache_ready||preloading)$fatal(1,"initial cache not ready");
 audio_prepared=1;confirm=1;@(negedge clk);confirm=0;
 if(!active||display_frame_slot!=0)$fatal(1,"lecture start failed");
 key_pause=1;@(negedge clk);key_pause=0;if(!paused)$fatal(1,"pause failed");
 key_pause=1;@(negedge clk);key_pause=0;if(paused)$fatal(1,"resume failed");
 preload_index=2;@(negedge clk);check_load(0,4,2);
 pulse_audio;displayed_frame_slot=1;repeat(2)@(negedge clk);
 if(load_request)$fatal(1,"detail 1 overwritten while displayed");
 pulse_audio;pulse_audio;displayed_frame_slot=2;repeat(2)@(negedge clk);check_load(1,1,2);
 pulse_audio;displayed_frame_slot=3;repeat(2)@(negedge clk);check_load(2,2,2);
 if(!preloading)$fatal(1,"detail 3 preload started before returning to full");
 pulse_audio;
 if(display_frame_slot!=0||!final_full_active||finished)
  $fatal(1,"final full view did not start before audio end");
 displayed_frame_slot=0;display_transition_busy=1;repeat(2)@(negedge clk);check_load(3,3,2);
 display_transition_busy=0;
 audio_stream_done=0;audio_drained=0;pulse_audio;
 if(finished)$fatal(1,"finished before final PCM frame");
 pulse_audio;
 if(!finished||display_frame_slot!=0)$fatal(1,"final PCM did not return to full view");
 repeat(3)@(negedge clk);
 if(!active||display_frame_slot!=0)$fatal(1,"final full-view hold was short");
 @(negedge clk);
 if(active||artifact!=2||display_frame_slot!=4||!audio_restart)
  $fatal(1,"auto return/promotion failed");
 audio_stream_done=0;audio_drained=0;selected=2;confirm=1;@(negedge clk);confirm=0;
 if(!active)$fatal(1,"promoted cache start failed");
 audio_total_frames=6;scene_cut1=1;scene_cut2=2;scene_cut3=3;scene_cut4=4;
 pulse_audio;if(display_slot!=1)$fatal(1,"script detail 1 failed");
 pulse_audio;if(display_slot!=2)$fatal(1,"script detail 2 failed");
 pulse_audio;if(display_slot!=3)$fatal(1,"script detail 3 failed");
 pulse_audio;if(display_slot!=0||!final_full_active)$fatal(1,"script final full view failed");
 displayed_frame_slot=3;
 key_return=1;@(negedge clk);key_return=0;
 if(!active||!finished||!audio_restart)$fatal(1,"key return did not request full view");
 display_transition_busy=1;displayed_frame_slot=4;repeat(2)@(negedge clk);
 if(!active)$fatal(1,"key return skipped full-view transition");
 display_transition_busy=0;@(negedge clk);
 if(active)$fatal(1,"key return failed");

 // Returning after only the spare full-view preload must continue with the
 // three missing details instead of discarding progress.
 selected=2;confirm=1;@(negedge clk);confirm=0;
 if(!active)$fatal(1,"second lecture start failed");
 displayed_frame_slot=4;preload_index=1;@(negedge clk);check_load(0,0,1);
 key_return=1;@(negedge clk);key_return=0;
 @(negedge clk);
 if(active||!preloading||!dut.queued_valid)
  $fatal(1,"partial preload was discarded on return");
 repeat(2)@(negedge clk);check_load(1,1,1);
 repeat(2)@(negedge clk);check_load(2,2,1);
 repeat(2)@(negedge clk);check_load(3,3,1);
 if(preloading||!cache_ready||artifact!=1||display_frame_slot!=0)
  $fatal(1,"partial preload did not finish and promote in overview");
 $display("PASS tb_museum_lecture_controller");$finish;
end
endmodule
`default_nettype wire
