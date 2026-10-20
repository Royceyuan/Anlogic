`timescale 1ns/1ps
module tb_mvid_scale2x #(parameter integer WIDTH=16,HEIGHT=4);
reg clk=0;always #5 clk=~clk;
reg rst_n=0,frame_begin=0,de=0,hs=1,vs=1;
reg [20:0] frame_base=21'd1843200;
reg [10:0] x=0;reg [9:0] y=0;
wire read_req,read_en,hs_o,vs_o,de_o,underflow;
wire [20:0] read_base,read_len;wire [15:0] pixel;
reg read_ack=0,fifo_empty=1,fifo_valid=0;
reg [31:0] fifo_data=0;
integer addr=0,left=0,sx,sy,repeat_frame,checked=0;
reg pending=0;reg [15:0] expected0=0,expected1=0;reg de0=0,de1=0;
mvid_scale2x #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) dut(.*);
function [15:0] sample;
    input integer address;
    begin sample=address^16'hace1;end
endfunction
always @(posedge clk) if(rst_n)begin
    if(de_o)begin if(pixel!==expected1)$fatal(1,"Scale mismatch got %h expected %h",pixel,expected1);checked=checked+1;end
    expected1<=expected0;
    expected0<=sample((y/2)*WIDTH+x/2);
end
always @(negedge clk)begin
    fifo_valid=0;
    if(read_req&&!read_ack&&left==0)begin
        read_ack=1;addr=(read_base-frame_base)*2;left=read_len;
        if(read_len!=WIDTH/2)$fatal(1,"Wrong line length");
    end else if(read_ack&&!read_req)begin read_ack=0;fifo_empty=0;end
    if(pending)begin fifo_valid=1;fifo_data={sample(addr),sample(addr+1)};addr=addr+2;left=left-1;pending=0;end
    else if(read_en)pending=1;
    if(left==0)fifo_empty=1;
end
initial begin
    repeat(5)@(negedge clk);rst_n=1;
    for(repeat_frame=0;repeat_frame<2;repeat_frame=repeat_frame+1)begin
        frame_begin=1;@(negedge clk);frame_begin=0;
        repeat(WIDTH*4+200)@(negedge clk);
        for(sy=0;sy<HEIGHT*2;sy=sy+1)begin
            for(sx=0;sx<WIDTH*2;sx=sx+1)begin de=1;x=sx;y=sy;@(negedge clk);end
            de=0;repeat(100)@(negedge clk);
        end
        repeat(5)@(negedge clk);
    end
    if(underflow||checked!=WIDTH*HEIGHT*8)$fatal(1,"Underflow=%b checked=%d",underflow,checked);
    $display("PASS 2x pixel/line duplication, two-line reuse, frame restart and high SDRAM base");$finish;
end
initial begin #50_000_000;$fatal(1,"Timeout");end
endmodule
