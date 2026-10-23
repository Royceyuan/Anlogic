`timescale 1ns/1ps
module tb_offline_osd_switch;
reg clk=0,rst=1,peer_alive=1,heartbeat_pulse=0,help_switch=0,guide_lease_valid=1,manual_mode=0;
reg [127:0] heartbeat_data=0;
reg [31:0] main_session=1,playback_round=0;
wire [7:0] file_id;
wire [31:0] generation,subtitle_position;
wire video_pause,show_help,show_emergency,guide_audio_enable;
wire [3:0] preload_target;
integer i;
reg [31:0] old_generation;
always #5 clk=~clk;
secondary_offline_scene_control #(.OSD_SWITCH(1)) dut(.*);
initial begin
    repeat(3)@(negedge clk);rst=0;
    heartbeat_data[127:120]=1;heartbeat_data[119:112]=0;heartbeat_data[111:104]=255;
    @(negedge clk);heartbeat_pulse=1;@(negedge clk);heartbeat_pulse=0;
    repeat(3)@(negedge clk);old_generation=generation;
    for(i=0;i<8;i=i+1)begin
        @(negedge clk);help_switch=!help_switch;#1;
        if(video_pause||show_help||!guide_audio_enable||file_id!=255||generation!=old_generation)
            $fatal(1,"SW4 retained old help/pause/mute/file control");
    end
    heartbeat_data[95:88]=1;heartbeat_pulse=1;@(negedge clk);heartbeat_pulse=0;#1;
    if(file_id!=254||!show_emergency||guide_audio_enable)$fatal(1,"Emergency priority");
    help_switch=1;#1;if(!show_emergency||video_pause)$fatal(1,"SW4 hid emergency");
    $display("PASS SW4 changes no media selection, pause, guide voice gate or emergency behavior in new target");$finish;
end
endmodule
