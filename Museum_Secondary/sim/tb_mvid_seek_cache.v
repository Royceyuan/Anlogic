`timescale 1ns/1ps
// Production 640x480/30 PCM layout, virtual fragmented 1GB GUIDE file.
// Only metadata is served: seeking must not read the skipped video payload.
module tb_mvid_seek_cache;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,card_ready=1,next_frame=0,sd_done=0,sd_valid=0;
reg [7:0] sd_data=0,sd_error=0;
reg [31:0] start_frame=1700;
wire [63:0] selected_stem="GUIDE   ";
wire sd_start,ready,frame_busy,frame_done,byte_valid,pcm_valid,frame_has_audio;
wire [31:0] sd_lba,sd_blocks,frame_index,frame_count;
wire [7:0] byte_data,pcm_byte,error,stage,fs_sectors_per_cluster;
wire [31:0] fs_fat_start,fs_data_start,fs_root_cluster;
fat32_mvid_reader #(.HEIGHT(480),.INPUT_VERSION(2),.DYNAMIC_STEM(1),.SEEK_ENABLE(1)) dut(.*);
localparam DATA=2049,HEADER=DATA+5*64,RECORD=621056,FRAMES=1800;
reg [7:0] boot[0:511],root[0:511],header[0:511];
integer i,j,fat_reads=0,phase=0,cluster,seek_clusters,expected_reads;
reg [31:0] crc,value;
time opened;
function [31:0] crc_byte;
input [31:0] c0;input [7:0] b;reg [31:0] c;integer n;
begin c=c0^b;for(n=0;n<8;n=n+1)c=(c>>1)^(c[0]?32'hedb88320:0);crc_byte=c;end
endfunction
task put_header;input integer p;input [31:0] v;
begin header[p]=v;header[p+1]=v>>8;header[p+2]=v>>16;header[p+3]=v>>24;end endtask
initial forever begin
    @(negedge clk);
    if(sd_start)begin
        if(sd_blocks!=1)$fatal(1,"Seek read payload instead of FAT");
        if(sd_lba>=1&&sd_lba<DATA)fat_reads=fat_reads+1;
        for(j=0;j<512;j=j+1)begin
            @(negedge clk);sd_valid=1;
            if(sd_lba==0)sd_data=boot[j];
            else if(sd_lba==DATA)sd_data=root[j];
            else if(sd_lba==HEADER)sd_data=header[j];
            else if(sd_lba>=1&&sd_lba<DATA)begin
                cluster=(sd_lba-1)*128+j/4;
                value=cluster==2?32'h0fffffff:cluster+2;
                if(phase==2&&cluster==9)value=1; // invalid cached successor
                sd_data=value>>(8*(j%4));
            end else $fatal(1,"Unexpected seek LBA %d",sd_lba);
        end
        @(negedge clk);sd_valid=0;
        repeat(3)@(negedge clk);
        if(phase==1&&sd_lba>=1&&sd_lba<DATA)sd_error=8'ha3;
        sd_done=1;@(negedge clk);sd_done=0;
    end
end
task reset_reader;
begin @(negedge clk);rst_n=0;sd_error=0;fat_reads=0;
repeat(5)@(negedge clk);rst_n=1;opened=$time;end endtask
initial begin
    for(i=0;i<512;i=i+1)begin boot[i]=0;root[i]=0;header[i]=0;end
    boot[0]=8'heb;boot[12]=2;boot[13]=64;boot[14]=1;boot[16]=1;
    // 12,800,000 sectors, 2048-sector FAT, root cluster 2.
    value=12800000;for(i=0;i<4;i=i+1)boot[32+i]=value>>(8*i);
    boot[37]=8;boot[44]=2;boot[510]=8'h55;boot[511]=8'haa;
    for(i=0;i<8;i=i+1)root[i]=selected_stem[63-8*i-:8];
    root[8]="B";root[9]="I";root[10]="N";root[11]=8'h20;root[26]=7;
    value=512+FRAMES*RECORD+512;for(i=0;i<4;i=i+1)root[28+i]=value>>(8*i);
    put_header(0,32'h4449564d);put_header(4,32'h02000002);
    put_header(8,{16'd480,16'd640});put_header(12,{16'd1,16'd30});
    put_header(16,FRAMES);put_header(20,614400);put_header(24,1);put_header(28,1);
    put_header(32,FRAMES*RECORD);put_header(40,RECORD);put_header(44,48000);
    put_header(48,{8'd16,8'd2,16'd1600});put_header(52,6400);put_header(56,6656);
    put_header(60,512+FRAMES*RECORD);put_header(72,1000);put_header(76,255);put_header(80,512);
    crc=32'hffffffff;for(i=0;i<508;i=i+1)crc=crc_byte(crc,header[i]);put_header(508,~crc);
    reset_reader();wait(ready||error);#1;
    seek_clusters=(1+1700*1213)/64;
    expected_reads=((7+2*(seek_clusters-1))/128)-(7/128)+1;
    if(error||frame_index!=1700||dut.current_cluster!=7+2*seek_clusters||
        dut.cluster_sector!=(1+1700*1213)%64)$fatal(1,"Fragmented seek target mismatch %h",error);
    $display("Seek frame 1700: traversed=%0d FAT_reads=%0d cache_expected=%0d core_ns=%0d",seek_clusters,fat_reads,expected_reads,$time-opened);
`ifndef BASELINE
    if(fat_reads!=expected_reads)$fatal(1,"Repeated FAT sector requests were not eliminated");
`endif
    phase=1;reset_reader();wait(ready||error);#1;
    if(error!=8'he0||ready)$fatal(1,"Corrupt FAT transport was accepted");
    phase=2;reset_reader();wait(ready||error);#1;
    if(error!=6||ready)$fatal(1,"Invalid cached FAT successor was accepted");
    $display("PASS production-layout late resume, fragmented chain, FAT transport failure and invalid cached entry");$finish;
end
initial begin #300000000;$fatal(1,"Seek timeout");end
endmodule
