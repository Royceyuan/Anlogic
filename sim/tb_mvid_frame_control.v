`timescale 1ns/1ps
module tb_mvid_frame_control #(parameter integer FPS=30,SLOTS=2,PERFORMANCE=0,EXTRA_GAP=0);
reg clk=0,pixel_clk=0;always #5 clk=~clk;always #7 pixel_clk=~pixel_clk;
reg rst_n=0,pixel_rst_n=0,pause=0,file_ready=1,movie_done=0,byte_valid=0;
reg [7:0] byte_data=0,input_error=0;
wire movie_start,write_req,write_en,display_valid,frame_begin;
wire [20:0] write_base,write_len,display_base;
wire [31:0] write_data,displayed_frames;
wire [7:0] error;
reg write_ack=0,write_finish=0,write_full=0,vblank=0;
integer words=0,jobs=0,byte_number=0,blank_count=0,delay_done=0;
integer send_gap=0;
reg sending=0;
mvid_frame_control #(.CLOCK_HZ(30000),.FRAME_BYTES(512),.FPS(FPS),.SLOTS(SLOTS)) dut(.*);
integer start_frames,measured_frames;
integer stored_job[0:2];
integer last_displayed=0;
integer expected_phase=0;
always @(posedge clk)begin
    if(!rst_n)expected_phase=0;
    else if(!pause)expected_phase=(expected_phase+FPS)%30000;
    #1;if(dut.rate_phase!==expected_phase)$fatal(1,"Frame rate accumulator mismatch at %0d fps",FPS);
end
always @(negedge clk)if(rst_n)begin
    write_ack=write_req;
    write_finish=0;movie_done=0;byte_valid=0;
    if(movie_start)begin sending=1;byte_number=0;words=0;send_gap=0;jobs=jobs+1;end
    if(sending)begin
      if(send_gap>0)send_gap=send_gap-1;
      else begin
        byte_valid=1;byte_data=byte_number+jobs*17;byte_number=byte_number+1;
        if(byte_number%4==0)send_gap=EXTRA_GAP;
        if(byte_number==512)begin sending=0;delay_done=30;end
      end
    end else if(delay_done>0)begin
        delay_done=delay_done-1;
        if(delay_done==20)write_finish=1;
        if(delay_done==1)movie_done=1;
    end
end
always @(posedge clk)if(rst_n&&write_en)begin
    if(write_data!=={8'((words*4+jobs*17)&255),8'((words*4+1+jobs*17)&255),8'((words*4+2+jobs*17)&255),8'((words*4+3+jobs*17)&255)})
        $fatal(1,"RGB565-BE packing mismatch");
    if(write_len!=128)$fatal(1,"Wrong frame length");
    if(display_valid&&write_base==display_base)$fatal(1,"Writing displayed slot");
    if(dut.pending&&dut.slot==dut.published_slot)$fatal(1,"Writing offered slot before ACK");
    words=words+1;
    if(words==128)stored_job[dut.slot]=jobs;
end
always @(negedge pixel_clk)begin
    vblank=0;
    // Scaled 60.36Hz scan vs 30kHz timebase; frame load takes > one scan.
    if(blank_count==354)begin blank_count=0;vblank=1;end else blank_count=blank_count+1;
end
always @(posedge pixel_clk)if(pixel_rst_n)begin
    if(displayed_frames!=last_displayed)begin
        if(stored_job[dut.display_slot]!==displayed_frames)$fatal(1,"Published wrong frame or slot");
        last_displayed=displayed_frames;
    end
    if(frame_begin&&displayed_frames>0&&delay_done>1&&jobs==1)
        $fatal(1,"Published frame before CRC confirmation");
end
initial begin
    repeat(5)@(negedge clk);rst_n=1;pixel_rst_n=1;
    if(PERFORMANCE)begin
        wait(displayed_frames>=3);@(negedge clk);start_frames=displayed_frames;
        repeat(30000)@(negedge clk);measured_frames=displayed_frames-start_frames;
        if(SLOTS==3&&(measured_frames<FPS-1||measured_frames>FPS+1))$fatal(1,"Triple buffering did not sustain model %0dfps: %d",FPS,measured_frames);
        if(SLOTS==2&&(measured_frames<29||measured_frames>31))$fatal(1,"Unexpected two-slot reference cadence: %d",measured_frames);
        if(error!=0)$fatal(1,"Performance run error");
        $display("PASS scaled model: FPS=%0d SLOTS=%0d displayed=%0d in one model second (not a hardware measurement)",FPS,SLOTS,measured_frames);
        $finish;
    end
    wait(displayed_frames>=6);@(negedge clk);pause=1;
    repeat(1800)@(negedge clk);
    if(displayed_frames!=6)$fatal(1,"Pause changed display");
    pause=0;wait(displayed_frames>=7);
    @(negedge clk);input_error=8'ha3;
    repeat(1000)@(negedge clk);
    if(error!=2||displayed_frames!=7)$fatal(1,"Input error published new frame");
    $display("PASS %0d fps phase accumulator, BE packing, SDRAM drain + CRC gate, CDC handover, no front-slot writes, pause/resume, fault hold",FPS);$finish;
end
initial begin #1000000;$fatal(1,"Timeout");end
endmodule
