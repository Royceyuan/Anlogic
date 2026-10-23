`timescale 1ns/1ps
module tb_mvid_pcm_commit;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,clear=0,frame_begin=0,frame_has_audio=1,frame_done=0,frame_abort=0,pcm_valid=0,sample_req=0;
reg [7:0] pcm_byte=0;
wire frame_accept,sample_valid,sample_has_data,underflow;
wire [31:0] sample_data;
wire [1:0] error;
mvid_pcm_commit #(.SAMPLES_PER_FRAME(4)) dut(.*);
integer i;
task start;input audio;
    begin @(negedge clk);if(!frame_accept)$fatal(1,"not ready for new frame");
        frame_has_audio=audio;frame_begin=1;@(negedge clk);frame_begin=0;end
endtask
task bytes;input integer base,count;integer k;
    begin for(k=0;k<count;k=k+1)begin pcm_valid=1;pcm_byte=base+k;@(negedge clk);end pcm_valid=0;end
endtask
task commit;
    begin frame_done=1;@(negedge clk);frame_done=0;end
endtask
task pop;input expected_valid;input [31:0] expected;
    begin sample_req=1;@(negedge clk);
        if(!sample_valid||sample_has_data!==expected_valid||sample_data!==expected)
            $fatal(1,"sample valid=%b data=%h expected=%h",sample_has_data,sample_data,expected);
        sample_req=0;@(negedge clk);end
endtask
task flush;
    begin clear=1;@(negedge clk);clear=0;@(negedge clk);end
endtask
initial begin
    repeat(3)@(negedge clk);rst_n=1;@(negedge clk);
    start(1);bytes(0,16);pop(0,0); // No release before transport CRC.
    commit();
    start(1);bytes(16,16);commit();
    if(frame_accept)$fatal(1,"full two-bank buffer accepted overwrite");
    for(i=0;i<8;i=i+1)pop(1,{8'(i*4+3),8'(i*4+2),8'(i*4+1),8'(i*4)});
    pop(0,0);
    $display("PASS PCM CRC quarantine, LE stereo sample order, two-bank backpressure and zero underflow");
    flush();start(1);bytes(32,16);frame_abort=1;frame_done=1;
    @(negedge clk);frame_abort=0;frame_done=0;pop(0,0);
    if(error||!frame_accept)$fatal(1,"abort leaked or locked provisional bank");
    start(0);commit();pop(0,0);
    if(error)$fatal(1,"silent exhibit frame rejected");
    start(1);bytes(80,16);commit();clear=1;sample_req=1;@(negedge clk);
    if(sample_valid||sample_has_data||sample_data)$fatal(1,"clear leaked queued audio");
    sample_req=0;clear=0;@(negedge clk);pop(0,0);
    $display("PASS CRC abort priority, silent exhibit frame and file-clear discard");
    flush();start(1);bytes(0,15);commit();
    if(error!=2)$fatal(1,"short PCM frame accepted");pop(0,0);
    flush();start(1);bytes(0,17);
    if(error!=2)$fatal(1,"long PCM frame accepted");pop(0,0);
    flush();start(1);bytes(0,16);pcm_valid=1;frame_done=1;@(negedge clk);pcm_valid=0;frame_done=0;
    if(error!=2)$fatal(1,"coincident excess byte/CRC completion accepted");pop(0,0);
    $display("PASS malformed PCM lengths rejected");
    $display("PASS tb_mvid_pcm_commit");$finish;
end
initial begin #100000;$fatal(1,"PCM test timeout");end
endmodule
