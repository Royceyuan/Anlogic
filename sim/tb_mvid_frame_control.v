`timescale 1ns/1ps
module tb_mvid_frame_control;
reg clk=0,pixel_clk=0;always #5 clk=~clk;always #7 pixel_clk=~pixel_clk;
reg rst_n=0,pixel_rst_n=0,pause=0,file_ready=1,movie_done=0,byte_valid=0;
reg [7:0] byte_data=0,input_error=0;
wire movie_start,write_req,write_en,display_valid,frame_begin;
wire [20:0] write_base,write_len,display_base;
wire [31:0] write_data,displayed_frames;
wire [7:0] error;
reg write_ack=0,write_finish=0,write_full=0,vblank=0;
integer words=0,jobs=0,byte_number=0,blank_count=0,delay_done=0;
reg sending=0;
mvid_frame_control #(.CLOCK_HZ(30000),.FRAME_BYTES(512)) dut(.*);
always @(negedge clk)if(rst_n)begin
    write_ack=write_req;
    write_finish=0;movie_done=0;byte_valid=0;
    if(movie_start)begin sending=1;byte_number=0;words=0;jobs=jobs+1;end
    if(sending)begin
        byte_valid=1;byte_data=byte_number;byte_number=byte_number+1;
        if(byte_number==512)begin sending=0;delay_done=30;end
    end else if(delay_done>0)begin
        delay_done=delay_done-1;
        if(delay_done==20)write_finish=1;
        if(delay_done==1)movie_done=1;
    end
end
always @(posedge clk)if(rst_n&&write_en)begin
    if(write_data!=={8'((words*4)&255),8'((words*4+1)&255),8'((words*4+2)&255),8'((words*4+3)&255)})
        $fatal(1,"RGB565-BE packing mismatch");
    if(write_len!=128)$fatal(1,"Wrong frame length");
    if(display_valid&&write_base==display_base)$fatal(1,"Writing displayed slot");
    words=words+1;
end
always @(negedge pixel_clk)begin
    vblank=0;
    if(blank_count==99)begin blank_count=0;vblank=1;end else blank_count=blank_count+1;
end
always @(posedge pixel_clk)if(pixel_rst_n)begin
    if(dut.display_ack!=dut.toggle_sync[1]&&display_valid&&dut.state==3)
        $fatal(1,"Unexpected in-flight publication");
    if(frame_begin&&displayed_frames>0&&delay_done>1&&jobs==1)
        $fatal(1,"Published frame before CRC confirmation");
end
initial begin
    repeat(5)@(negedge clk);rst_n=1;pixel_rst_n=1;
    wait(displayed_frames>=2);@(negedge clk);pause=1;
    repeat(1800)@(negedge clk);
    if(displayed_frames!=2)$fatal(1,"Pause changed display");
    pause=0;wait(displayed_frames>=3);
    @(negedge clk);input_error=8'ha3;
    repeat(1000)@(negedge clk);
    if(error!=2||displayed_frames!=3)$fatal(1,"Input error published new frame");
    $display("PASS BE packing, SDRAM drain + CRC gate, CDC handover, no front-slot writes, pause/resume, fault hold");$finish;
end
initial begin #150000;$fatal(1,"Timeout");end
endmodule
