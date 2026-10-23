`timescale 1ns/1ps
`default_nettype none
// 50MHz business-state consumer. Video stays 1x; only subtitle_position follows
// the main audio clock. guide_lease_valid must come from the checked lease protocol,
// never directly from a switch or an unvalidated packet.
module secondary_offline_scene_control #(parameter integer OSD_SWITCH=0)(
    input wire clk,rst,peer_alive,heartbeat_pulse,
    input wire [127:0] heartbeat_data,
    input wire help_switch,guide_lease_valid,manual_mode,
    input wire [31:0] main_session,playback_round,
    output reg [7:0] file_id,
    output reg [31:0] generation,subtitle_position,
    output wire video_pause,show_help,show_emergency,guide_audio_enable,
    output reg [3:0] preload_target
);
reg seen,lecture,paused,emergency,recovering;
reg [31:0] session_seen,round_seen;
wire incoming_emergency=heartbeat_data[95:88]!=0;
wire incoming_lecture=!manual_mode&&heartbeat_data[127:120]==2&&heartbeat_data[119:112]<=4&&
    heartbeat_data[111:104]<=4&&
    (heartbeat_data[103:96]==1||heartbeat_data[103:96]==2||heartbeat_data[103:96]==3);
wire [7:0] incoming_id=incoming_emergency?8'hfe:incoming_lecture?heartbeat_data[119:112]:8'hff;
assign show_emergency=seen&&emergency;
assign show_help=!OSD_SWITCH&&help_switch&&!show_emergency;
assign video_pause=!show_emergency&&(!peer_alive||recovering||
    (file_id==8'hff ? (!OSD_SWITCH&&help_switch) : lecture&&paused));
assign guide_audio_enable=seen&&peer_alive&&guide_lease_valid&&file_id==8'hff&&
    !show_help&&!show_emergency&&!recovering;
always @(posedge clk or posedge rst) begin
    if(rst)begin
        seen<=0;lecture<=0;paused<=0;emergency<=0;recovering<=0;
        session_seen<=0;round_seen<=0;file_id<=8'hff;generation<=0;
        subtitle_position<=0;preload_target<=4'hf;
    end else if(heartbeat_pulse&&peer_alive)begin
        seen<=1;
        emergency<=incoming_emergency;
        recovering<=heartbeat_data[70];
        // Recovery does not turn an in-progress lecture into an audible guide.
        if(incoming_emergency||!heartbeat_data[70])begin
            if(!seen||incoming_id!=file_id||main_session!=session_seen||
                (incoming_lecture&&playback_round!=round_seen))generation<=generation+1'b1;
            file_id<=incoming_id;
            lecture<=incoming_lecture&&!incoming_emergency;
            paused<=incoming_lecture&&(heartbeat_data[103:96]==2||heartbeat_data[68]);
            session_seen<=main_session;round_seen<=playback_round;
        end
        subtitle_position<=heartbeat_data[63:32];
        preload_target<=heartbeat_data[71]&&heartbeat_data[11:8]<=4?heartbeat_data[11:8]:4'hf;
    end
end
endmodule
`default_nettype wire
