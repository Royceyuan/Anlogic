`timescale 1ns/1ps
module tb_offline_file_switch;
reg clk=0,pixel_clk=0;always #5 clk=~clk;always #7 pixel_clk=~pixel_clk;
reg rst_n=0,pause=0;
reg [7:0] requested_id=255;
reg [31:0] requested_generation=0;
wire stream_hold,stream_clear,reader_rst_n,stream_idle;
wire [63:0] selected_stem;
wire [7:0] active_id,error;
wire [31:0] active_generation;
wire [31:0] frame_epoch=active_generation;
wire [31:0] front_epoch;
wire front_valid;
reg sd_busy=0,sd_start=0,movie_busy=0,file_ready=0;
wire movie_start,write_req,write_en,display_valid,frame_begin;
wire [20:0] write_base,write_len,display_base;
wire [31:0] write_data,displayed_frames;
reg write_ack=0,write_finish=0,write_full=0,vblank=0;
reg movie_done=0,byte_valid=0;
reg [7:0] byte_data=0;
wire [7:0] input_error=0;
wire pixel_rst_n=rst_n;
secondary_offline_file_control manager(.frame_idle(stream_idle),.*);
mvid_frame_control #(.CLOCK_HZ(30000),.FRAME_BYTES(512),.VIDEO_BASE(0),
    .SLOTS(3),.THIRD_BASE(256),.STREAM_CONTROL(1)) frames(
    .file_ready(file_ready),.movie_done(movie_done),.byte_valid(byte_valid),.byte_data(byte_data),
    .input_error(input_error),.*);
integer opening=0,remaining=0,drain=0,word_count=0,blank_count=0;
integer job_tag=0,slot_tag[0:2],published=0,saved_count,saved_base;
always @(posedge clk or negedge reader_rst_n)
    if(!reader_rst_n)begin file_ready<=0;opening<=0;end
    else if(!file_ready)begin
        if(opening==15)file_ready<=1;else opening<=opening+1;
    end
always @(negedge clk)if(rst_n)begin
    write_ack=write_req;write_finish=0;movie_done=0;byte_valid=0;
    if(movie_start)begin
        if(!file_ready)$fatal(1,"Start without mounted file");
        sd_busy=1;movie_busy=1;remaining=512;word_count=0;
        job_tag=active_generation*256+active_id;
    end
    if(remaining>0)begin
        byte_valid=1;byte_data=remaining;remaining=remaining-1;
        if(remaining==0)drain=20;
    end else if(drain>0)begin
        drain=drain-1;
        if(drain==15)write_finish=1;
        if(drain==1)begin sd_busy=0;movie_busy=0;movie_done=1;end
    end
end
always @(posedge clk)if(rst_n)begin
    if(!reader_rst_n&&sd_busy)$fatal(1,"Reader reset during SD transfer");
    if(stream_clear&&!stream_idle)$fatal(1,"Cleared before frame/CDC drainage");
    if(write_en)begin
        if(display_valid&&write_base==display_base)$fatal(1,"Overwriting scanned slot");
        if(frames.pending&&write_base==frames.slot_base(frames.published_slot))
            $fatal(1,"Overwriting offered slot");
        word_count=word_count+1;
        if(word_count==128)slot_tag[write_base/128]=job_tag;
    end
end
always @(negedge pixel_clk)begin
    vblank=0;
    if(blank_count==354)begin blank_count=0;vblank=1;end else blank_count=blank_count+1;
end
always @(posedge pixel_clk)if(rst_n&&displayed_frames!=published)begin
    if(slot_tag[display_base/128]<0)$fatal(1,"Unwritten frame published");
    published=displayed_frames;
end
task wait_tag;
    input integer expected;
    begin wait(display_valid&&slot_tag[display_base/128]==expected);
        repeat(5)@(negedge clk);
        if(!front_valid||front_epoch!=expected/256)$fatal(1,"Front epoch does not match displayed file");
        if(error)$fatal(1,"Frame engine error %h",error);
    end
endtask
initial begin
    slot_tag[0]=-1;slot_tag[1]=-1;slot_tag[2]=-1;
    repeat(5)@(negedge clk);rst_n=1;
    wait(displayed_frames>=3);wait(movie_busy);
    @(negedge clk);pause=1;requested_id=0;requested_generation=1;
    wait(stream_clear);@(negedge clk);saved_base=display_base;saved_count=displayed_frames;
    wait(active_id==0&&file_ready&&!stream_hold);
    repeat(2000)@(negedge clk);
    if(!display_valid||display_base!=saved_base||displayed_frames!=saved_count)
        $fatal(1,"Pause/switch blanked or changed the retained frame");
    if(selected_stem!="ART0    ")$fatal(1,"Wrong stem");
    pause=0;wait_tag(256);
    @(negedge clk);requested_id=1;requested_generation=2;
    wait(!reader_rst_n);
    @(negedge clk);requested_id=4;requested_generation=3;
    wait_tag(3*256+4);
    if(selected_stem!="ART4    ")$fatal(1,"Superseded target not replaced");
    @(negedge clk);requested_generation=4;
    wait_tag(4*256+4);
    @(negedge clk);requested_id=254;requested_generation=5;
    wait_tag(5*256+254);
    if(selected_stem!="EVAC    ")$fatal(1,"Emergency stem");
    @(negedge clk);requested_id=255;requested_generation=6;
    wait_tag(6*256+255);
    if(selected_stem!="GUIDE   ")$fatal(1,"Guide stem");
    $display("PASS file epoch drain, retained front frame, pause switch, supersession, same-ID restart and seven-file stems");
    $finish;
end
initial begin #3000000;$fatal(1,"File-switch timeout state %0d frame state %0d",manager.state,frames.state);end
endmodule
