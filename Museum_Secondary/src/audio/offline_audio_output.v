`timescale 1ns/1ps
`default_nettype none
// One stereo pair crosses via a bundled request/reply handshake per 48k tick.
// Muting changes only PCM values: HDMI samples and ACR keep their cadence.
module offline_audio_output #(
    parameter integer PIXEL_HZ=75_000_000,SAMPLE_HZ=48000,MUTE_SAMPLES=64,FADE_ENABLE=0
)(
    input wire clk,rst_n,clear,consume,unmute,
    input wire [31:0] epoch,total_samples,start_position,
    output reg pcm_request,
    input wire pcm_valid,pcm_has_data,
    input wire [31:0] pcm_data,
    output reg [31:0] position,
    output wire muted_ack,
    input wire pixel_clk,pixel_rst_n,
    output reg audio_valid,
    output reg [31:0] audio_data,
    output reg missed_reply
);
wire [33:0] pixel_control;
secondary_offline_request_cdc #(.WIDTH(34),.INITIAL(34'd0)) u_control(
    .source_clk(clk),.source_rst_n(rst_n),.source_data({epoch,consume,unmute}),
    .target_clk(pixel_clk),.target_rst_n(pixel_rst_n),.target_data(pixel_control));
reg request,reply,request_seen,waiting;
reg [1:0] request_sync,reply_sync,muted_sync;
reg [31:0] reply_data,reply_epoch;
reg reply_has_data;
reg pixel_muted;
assign muted_ack=muted_sync[1];
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        request_sync<=0;request_seen<=0;waiting<=0;reply<=0;
        reply_data<=0;reply_epoch<=0;reply_has_data<=0;
        pcm_request<=0;position<=0;muted_sync<=0;
    end else begin
        request_sync<={request_sync[0],request};muted_sync<={muted_sync[0],pixel_muted};
        pcm_request<=0;
        if(waiting&&pcm_valid)begin
            waiting<=0;reply<=request_seen;reply_data<=pcm_data;
            reply_has_data<=pcm_has_data;reply_epoch<=epoch;
            if(pcm_has_data)position<=total_samples!=0&&position==total_samples-1'b1 ? 0 : position+1'b1;
        end else if(!waiting&&request_sync[1]!=request_seen)begin
            request_seen<=request_sync[1];
            if(consume)begin pcm_request<=1;waiting<=1;end
            else begin reply<=request_sync[1];reply_data<=0;reply_has_data<=0;reply_epoch<=epoch;end
        end
        if(clear)begin
            request_seen<=request_sync[1];reply<=request_sync[1];waiting<=0;
            pcm_request<=0;reply_data<=0;reply_has_data<=0;reply_epoch<=epoch;position<=start_position;
        end
    end
end
localparam PHASE_BITS=$clog2(PIXEL_HZ);
localparam MUTE_BITS=$clog2(MUTE_SAMPLES+1);
reg [PHASE_BITS-1:0] phase;
reg [MUTE_BITS-1:0] silent_count;
reg reply_seen,buffer_valid;
reg [31:0] buffer_data,buffer_epoch;
reg [8:0] fade_gain;
wire signed [25:0] faded_left=$signed(buffer_data[15:0])*$signed({1'b0,fade_gain});
wire signed [25:0] faded_right=$signed(buffer_data[31:16])*$signed({1'b0,fade_gain});
wire [31:0] played_data=FADE_ENABLE?{faded_right[23:8],faded_left[23:8]}:buffer_data;
wire sample_tick=phase>=PIXEL_HZ-SAMPLE_HZ;
wire allowed=pixel_control[1]&&pixel_control[0];
always @(posedge pixel_clk or negedge pixel_rst_n)begin
    if(!pixel_rst_n)begin
        phase<=0;request<=0;reply_sync<=0;reply_seen<=0;buffer_valid<=0;
        buffer_data<=0;buffer_epoch<=0;audio_valid<=0;audio_data<=0;
        silent_count<=0;pixel_muted<=0;missed_reply<=0;fade_gain<=0;
    end else begin
        reply_sync<={reply_sync[0],reply};audio_valid<=0;
        if(sample_tick)begin
            phase<=phase-(PIXEL_HZ-SAMPLE_HZ);audio_valid<=1;
            audio_data<=allowed&&buffer_valid&&buffer_epoch==pixel_control[33:2]?played_data:0;
            if(!allowed||buffer_epoch!=pixel_control[33:2])fade_gain<=0;
            else if(fade_gain<256)fade_gain<=fade_gain+1'b1;
            // Pause retains the one prefetched stereo pair. Muting alone
            // still consumes pairs, so the silent guide timeline stays live.
            if(pixel_control[1])begin
                buffer_valid<=0;
                if(reply_sync[1]==request)request<=!request;
                else missed_reply<=1;
            end
            if(!allowed)begin
                if(silent_count<MUTE_SAMPLES)silent_count<=silent_count+1'b1;
                if(silent_count==MUTE_SAMPLES-1)pixel_muted<=1;
            end else begin silent_count<=0;pixel_muted<=0;end
        end else phase<=phase+SAMPLE_HZ;
        // Capture after tick bookkeeping so a simultaneous reply is retained
        // for the next sample, never dropped by the buffer clear above.
        if(reply_sync[1]!=reply_seen)begin
            reply_seen<=reply_sync[1];buffer_data<=reply_data;
            buffer_epoch<=reply_epoch;buffer_valid<=reply_has_data;
        end
    end
end
endmodule
`default_nettype wire
