`timescale 1ns/1ps
// Real 640x480 frame geometry and fragmented FAT32 sectors, generated on demand.
module tb_mvid_geometry;
localparam FRAME_BYTES=614400,FILE_SECTORS=2401,SPC=128,LAST_CLUSTER=39;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,card_ready=1,next_frame=0,sd_done=0,sd_valid=0;
reg [7:0] sd_data=0,sd_error=0;
wire sd_start,byte_valid,ready,frame_busy,frame_done;
wire [31:0] sd_lba,sd_blocks,frame_index,frame_count;
wire [7:0] byte_data,error,stage;
reg [7:0] header[0:511];
integer i,j,k,seen=0,frames=0,requests=0;
reg [31:0] crc;
fat32_mvid_reader #(.HEIGHT(480)) dut(.*);
function [31:0] crc_byte;
    input [31:0] c;input [7:0] b;
    reg [31:0] v;integer n;
    begin v=c^b;for(n=0;n<8;n=n+1)v=(v>>1)^(v[0]?32'hedb88320:0);crc_byte=v;end
endfunction
task put32;
    input integer p;input [31:0] v;
    begin header[p]=v;header[p+1]=v>>8;header[p+2]=v>>16;header[p+3]=v>>24;end
endtask
task header_crc;
    begin crc=32'hffffffff;for(i=0;i<508;i=i+1)crc=crc_byte(crc,header[i]);put32(508,~crc);end
endtask
function [7:0] disk_byte;
    input integer lba,offset;
    integer cluster,entry,value,sector,payload;
    begin
        disk_byte=0;
        if(lba==0)case(offset)
            0:disk_byte=8'heb;12:disk_byte=2;13:disk_byte=SPC;14:disk_byte=1;
            16:disk_byte=1;33:disk_byte=32;36:disk_byte=1;44:disk_byte=2;
            510:disk_byte=8'h55;511:disk_byte=8'haa;
        endcase
        else if(lba==1)begin
            entry=offset/4;value=0;
            if(entry==2||entry==LAST_CLUSTER)value=32'h0fffffff;
            else if(entry>=3&&entry<LAST_CLUSTER&&entry%2==1)value=entry+2;
            disk_byte=value>>((offset%4)*8);
        end else if(lba==2)case(offset)
            0:disk_byte="V";1:disk_byte="I";2:disk_byte="D";3:disk_byte="E";
            4:disk_byte="O";5:disk_byte="0";6,7:disk_byte=" ";8:disk_byte="B";
            9:disk_byte="I";10:disk_byte="N";11:disk_byte=8'h20;26:disk_byte=3;
            28,29,30,31:disk_byte=(512+2*FRAME_BYTES)>>((offset-28)*8);
        endcase
        else begin
            cluster=(lba-2)/SPC+2;
            if(cluster>=3&&cluster<=LAST_CLUSTER&&cluster%2==1)begin
                sector=(cluster-3)/2*SPC+(lba-2)%SPC;
                if(sector==0)disk_byte=header[offset];
                else begin
                    payload=(sector-1)*512+offset;
                    disk_byte=((payload%FRAME_BYTES)*7)^((payload/FRAME_BYTES)*17);
                end
            end
        end
    end
endfunction
always @(posedge clk)if(rst_n)begin
    if(byte_valid)begin
        if(byte_data!==(((seen*7)^((frames%2)*17))&255))$fatal(1,"Geometry byte mismatch frame=%0d offset=%0d",frames,seen);
        seen=seen+1;
    end
    if(frame_done)begin
        if(seen!=FRAME_BYTES)$fatal(1,"Geometry short frame %0d",seen);
        seen=0;frames=frames+1;
    end
end
initial forever begin
    @(negedge clk);
    if(sd_start)begin
        requests=requests+1;
        if(sd_blocks<1||sd_blocks>128||sd_lba+sd_blocks>8192)$fatal(1,"Geometry invalid request");
        for(j=0;j<sd_blocks*512;j=j+1)begin
            sd_data=disk_byte(sd_lba+j/512,j%512);sd_valid=1;@(negedge clk);
        end
        sd_valid=0;repeat(5)@(negedge clk);sd_done=1;@(negedge clk);sd_done=0;
    end
end
initial begin
    for(i=0;i<512;i=i+1)header[i]=0;
    put32(0,32'h4449564d);header[4]=1;header[7]=2;
    header[8]=8'h80;header[9]=2;header[10]=8'he0;header[11]=1;
    header[12]=30;header[14]=1;put32(16,2);put32(20,FRAME_BYTES);
    put32(24,1);put32(32,2*FRAME_BYTES);header_crc();
    repeat(5)@(negedge clk);rst_n=1;wait(ready||error!=0);
    if(error!=0||frame_count!=2)$fatal(1,"Geometry mount failed %h %h",stage,error);
    for(k=0;k<3;k=k+1)begin
        @(negedge clk);next_frame=1;@(negedge clk);next_frame=0;
        wait(frame_done||error!=0);repeat(3)@(negedge clk);
        if(error!=0)$fatal(1,"Geometry read failed %h %h",stage,error);
    end
    if(frames!=3)$fatal(1,"Geometry loop failed");
    $display("PASS real 640x480x30 header, 614400-byte frames, 128-sector clusters, fragmented file and EOF loop (%0d requests)",requests);
    header[10]=8'h68;header[11]=1;header_crc();
    @(negedge clk);rst_n=0;repeat(5)@(negedge clk);rst_n=1;wait(error!=0);
    if(error!=7||ready)$fatal(1,"360-line media accepted by 480-line build");
    $display("PASS 480-line build rejects valid-CRC 360-line media");$finish;
end
initial begin #100_000_000;$fatal(1,"Geometry timeout %h %h",stage,error);end
endmodule
