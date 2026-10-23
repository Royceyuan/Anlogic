`timescale 1ns/1ps
// Scaled clocks, four PCM pairs/frame: production ownership, quarantine and
// CDC blocks are connected exactly as in the AV top; no vendor RAM macro needed.
module tb_offline_av_pipeline;
reg clk=0,pixel_clk=0,rst_n=0,pause=0;
always #5 clk=~clk;always #7.142857 pixel_clk=~pixel_clk;
reg [7:0] requested_id=255;
reg [31:0] requested_generation=0;
wire stream_hold,stream_clear,reader_rst_n,stream_idle;
wire [63:0] selected_stem;
wire [7:0] active_id,frame_error;
wire [31:0] active_generation,front_epoch;
wire front_valid;
reg sd_busy=0,movie_busy=0,file_ready=0,movie_done=0,byte_valid=0,pcm_byte_valid=0;
reg [7:0] byte_data=0,pcm_byte=0;
wire movie_start,write_req,write_en,display_valid,frame_begin;
wire [20:0] write_base,write_len,display_base;
wire [31:0] write_data,displayed_frames;
reg write_ack=0,write_finish=0,vblank=0;
wire pcm_accept,pcm_request,pcm_valid,pcm_has_data;
wire [31:0] pcm_data,position,audio_data;
wire [1:0] pcm_error;
wire audio_valid,muted_ack,missed_reply;
integer opening=0,payload=0,delay_done=0,frame_serial=0,sample_index=0,blank_phase=0;
integer checked=0,last_sample=0,saved_position;
reg [31:0] frame_word;
wire consume=front_valid&&front_epoch==active_generation&&!pause&&!stream_hold&&file_ready;
secondary_offline_file_control files(.clk(clk),.rst_n(rst_n),.requested_id(requested_id),
    .requested_generation(requested_generation),.sd_busy(sd_busy),.sd_start(1'b0),.frame_idle(stream_idle),
    .movie_busy(movie_busy),.file_ready(file_ready),.stream_hold(stream_hold),.stream_clear(stream_clear),
    .reader_rst_n(reader_rst_n),.selected_stem(selected_stem),.active_id(active_id),.active_generation(active_generation));
mvid_frame_control #(.CLOCK_HZ(30000),.FRAME_BYTES(512),.FPS(30),.VIDEO_BASE(0),.SLOTS(3),.THIRD_BASE(256),.STREAM_CONTROL(1)) frames(
    .clk(clk),.rst_n(rst_n),.pause(pause),.stream_hold(stream_hold),.stream_clear(stream_clear),.stream_idle(stream_idle),
    .file_ready(file_ready&&pcm_accept),.frame_epoch(active_generation),.front_epoch(front_epoch),.front_valid(front_valid),
    .movie_done(movie_done),.byte_valid(byte_valid),.byte_data(byte_data),.input_error(8'd0),
    .movie_start(movie_start),.write_req(write_req),.write_en(write_en),.write_base(write_base),.write_len(write_len),
    .write_data(write_data),.write_ack(write_ack),.write_finish(write_finish),.write_full(1'b0),
    .pixel_clk(pixel_clk),.pixel_rst_n(rst_n),.vblank(vblank),.display_valid(display_valid),
    .frame_begin(frame_begin),.display_base(display_base),.displayed_frames(displayed_frames),.error(frame_error));
mvid_pcm_commit #(.SAMPLES_PER_FRAME(4)) pcm(.clk(clk),.rst_n(rst_n),.clear(stream_clear||!file_ready),
    .frame_begin(movie_start),.frame_has_audio(1'b1),.frame_done(movie_done),.frame_abort(1'b0),
    .pcm_valid(pcm_byte_valid),.pcm_byte(pcm_byte),.frame_accept(pcm_accept),
    .sample_req(pcm_request),.sample_valid(pcm_valid),.sample_has_data(pcm_has_data),.sample_data(pcm_data),.underflow(),.error(pcm_error));
offline_audio_output #(.PIXEL_HZ(21000),.SAMPLE_HZ(120),.MUTE_SAMPLES(4)) audio(
    .clk(clk),.rst_n(rst_n),.clear(stream_clear||!file_ready),.consume(consume),.unmute(1'b1),
    .epoch(active_generation),.total_samples(32'd0),.start_position(32'd0),.pcm_request(pcm_request),
    .pcm_valid(pcm_valid),.pcm_has_data(pcm_has_data),.pcm_data(pcm_data),.position(position),.muted_ack(muted_ack),
    .pixel_clk(pixel_clk),.pixel_rst_n(rst_n),.audio_valid(audio_valid),.audio_data(audio_data),.missed_reply(missed_reply));
always @(posedge clk or negedge reader_rst_n)
    if(!reader_rst_n)begin file_ready<=0;opening<=0;end
    else if(opening<10)opening<=opening+1;else file_ready<=1;
always @(negedge pixel_clk)begin
    vblank=0;if(blank_phase==349)begin blank_phase=0;vblank=1;end else blank_phase=blank_phase+1;
end
always @(negedge clk)if(rst_n)begin
    write_ack=write_req;write_finish=0;movie_done=0;byte_valid=0;pcm_byte_valid=0;
    if(movie_start)begin
        sd_busy=1;movie_busy=1;payload=1;frame_serial=frame_serial+1;
    end
    if(payload!=0)begin
        if(payload<=512)begin byte_valid=1;byte_data=payload;end
        else if(payload<=528)begin
            sample_index=(payload-513)/4;
            frame_word={8'(active_generation),8'h5a,16'(frame_serial*4+sample_index)};
            pcm_byte_valid=1;pcm_byte=frame_word>>((payload-513)%4*8);
        end
        payload=payload+1;
        if(payload==529)begin payload=0;delay_done=20;end
    end else if(delay_done!=0)begin
        delay_done=delay_done-1;
        if(delay_done==15)write_finish=1;
        if(delay_done==1)begin movie_done=1;movie_busy=0;sd_busy=0;end
    end
    if(frame_error||pcm_error)$fatal(1,"Integrated frame/PCM error %h/%h",frame_error,pcm_error);
end
always @(negedge pixel_clk)if(rst_n&&audio_valid&&audio_data!=0)begin
    if(audio_data[23:16]!=8'h5a)$fatal(1,"Stereo word was torn");
    if(audio_data[15:0]<=last_sample)$fatal(1,"Committed PCM reordered");
    if(front_epoch==1&&audio_data[31:24]!=1)$fatal(1,"Old epoch audio after new front");
    last_sample=audio_data[15:0];checked=checked+1;
end
initial begin
    repeat(5)@(negedge clk);rst_n=1;
    wait(checked>=12);
    @(negedge clk);pause=1;repeat(600)@(negedge clk);saved_position=position;
    repeat(1500)@(negedge clk);if(position!=saved_position)$fatal(1,"Pause advanced audio position");
    @(negedge clk);pause=0;wait(checked>=20);
    @(negedge clk);requested_id=0;requested_generation=1;
    wait(front_epoch==1);wait(checked>=28);
    if(missed_reply)$fatal(1,"Audio reply missed its deadline");
    $display("PASS integrated frame ownership/CRC-staged PCM/CDC: ordered samples, pause/resume, drained file switch, no old-epoch audio");$finish;
end
initial begin #1000000;$fatal(1,"AV integration timeout checked=%d state=%d frame=%d",checked,files.state,frames.state);end
endmodule
