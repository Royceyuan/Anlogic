`timescale 1ns/1ps
module tb_secondary_offline_scene_control;
reg clk=0;always #10 clk=~clk;
reg rst=1,peer_alive=0,heartbeat_pulse=0,help_switch=0,guide_lease_valid=0,manual_mode=0;
reg [127:0] heartbeat_data=0;
reg [31:0] main_session=32'h1234,playback_round=0;
wire [7:0] file_id;
wire [31:0] generation,subtitle_position;
wire video_pause,show_help,show_emergency,guide_audio_enable;
wire [3:0] preload_target;
secondary_offline_scene_control dut(.*);
reg [31:0] before_generation;
task send;
    input [7:0] mode,id,phase,state;
    input emergency;
    begin
        @(negedge clk);heartbeat_data[127:120]=mode;heartbeat_data[119:112]=id;
        heartbeat_data[111:104]=phase;heartbeat_data[103:96]=state;
        heartbeat_data[95:88]={7'd0,emergency};heartbeat_pulse=1;
        @(negedge clk);heartbeat_pulse=0;@(negedge clk);
    end
endtask
initial begin
    repeat(3)@(negedge clk);rst=0;peer_alive=1;
    send(1,0,255,0,0);
    if(file_id!=255||guide_audio_enable)$fatal(1,"unauthorized guide sound");
    guide_lease_valid=1;#1;
    if(!guide_audio_enable||video_pause)$fatal(1,"guide lease");
    before_generation=generation;
    heartbeat_data[71]=1;heartbeat_data[11:8]=4;
    send(1,0,255,0,0);
    if(file_id!=255||preload_target!=4||generation!=before_generation)$fatal(1,"preload interrupted guide");
    help_switch=1;#1;
    if(!video_pause||guide_audio_enable||!show_help)$fatal(1,"guide help pause");
    help_switch=0;playback_round=1;send(2,0,0,1,0);
    if(file_id!=0||video_pause||guide_audio_enable)$fatal(1,"lecture entry");
    before_generation=generation;
    heartbeat_data[18:17]=1;heartbeat_data[63:32]=24000;send(2,0,1,1,0);
    heartbeat_data[18:17]=2;heartbeat_data[63:32]=72000;send(2,0,2,1,0);
    if(generation!=before_generation||file_id!=0||video_pause||subtitle_position!=72000)$fatal(1,"speed/phase restarted video");
    send(2,0,3,3,0);
    if(generation!=before_generation||file_id!=0)$fatal(1,"automatic image transition restarted video");
    send(2,0,2,2,0);
    if(!video_pause||guide_audio_enable)$fatal(1,"pause restored guide");
    send(2,0,2,1,0);help_switch=1;#1;
    if(video_pause||!show_help)$fatal(1,"lecture help changed video progress");
    send(2,0,2,1,1);
    if(file_id!=254||!show_emergency||show_help||guide_audio_enable||video_pause)$fatal(1,"emergency priority");
    peer_alive=0;#1;
    if(file_id!=254||!show_emergency||guide_audio_enable)$fatal(1,"disconnect cleared emergency");
    peer_alive=1;help_switch=0;send(1,0,255,0,0);
    if(file_id!=255||show_emergency||!guide_audio_enable)$fatal(1,"fresh state recovery");
    manual_mode=1;send(2,4,2,5,0);
    if(file_id!=255)$fatal(1,"manual browsing entered lecture film");
    before_generation=generation;
    send(2,4,3,3,0);
    if(file_id!=255||generation!=before_generation)$fatal(1,"manual image transition restarted guide");
    send(2,4,4,5,0);send(2,4,0,3,0);send(2,4,0,5,0);
    if(file_id!=255||generation!=before_generation)$fatal(1,"manual wraparound restarted guide");
    manual_mode=0;playback_round=2;send(2,4,0,1,0);
    if(file_id!=4||generation!=before_generation+1)$fatal(1,"leaving manual blocked automatic lecture");
    $display("PASS manual 5->3->5 transitions/wrap retain GUIDE epoch; automatic transitions retain exhibit epoch");
    guide_lease_valid=0;#1;if(guide_audio_enable)$fatal(1,"revoked lease still audible");
    $display("PASS guide/preload/manual, 1x video independent of 1x2x3x audio, pause/help, emergency and lease gating");
    $display("PASS tb_secondary_offline_scene_control");$finish;
end
initial begin #100000;$fatal(1,"timeout");end
endmodule
