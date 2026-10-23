`timescale 1ns/1ps
module tb_mvid2_reader;
localparam FB=512,PB=6400,PS=6656,RECORD=FB+PS;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,card_ready=1,next_frame=0,sd_done=0,sd_valid=0;
reg [7:0] sd_data=0,sd_error=0;
wire sd_start,byte_valid,pcm_valid,ready,frame_busy,frame_done;
wire [31:0] sd_lba,sd_blocks,frame_index,frame_count;
wire [7:0] byte_data,pcm_byte,error,stage;
wire [63:0] selected_stem="GUIDE   ";
reg [31:0] start_frame=0;
wire frame_has_audio;
wire [7:0] fs_sectors_per_cluster;
wire [31:0] fs_fat_start,fs_data_start,fs_root_cluster;
reg reader_valid=0,reader_done=0;
reg [7:0] reader_data=0;
// Match the AV top's registered, qualified movie-client interface.
always @(posedge clk)begin
    reader_valid<=rst_n&&sd_valid;reader_done<=rst_n&&sd_done;reader_data<=sd_data;
end
fat32_mvid_reader #(.WIDTH(16),.HEIGHT(16),.INPUT_VERSION(2),.DYNAMIC_STEM(1),.SEEK_ENABLE(1)) dut(
    .sd_valid(reader_valid),.sd_done(reader_done),.sd_data(reader_data),.*);
reg [7:0] disk[0:65535];
integer i,j,k,f,p,sector,bytes_seen=0,pcm_seen=0,frames_seen=0;
integer want_pcm=PB;
reg fail_audio=0;
reg [31:0] crc;
function [31:0] crc_byte;
    input [31:0] value;input [7:0] b;reg [31:0] c;integer n;
    begin c=value^b;for(n=0;n<8;n=n+1)c=(c>>1)^(c[0]?32'hedb88320:0);crc_byte=c;end
endfunction
task put16;input integer a;input [15:0] v;
    begin disk[a]=v;disk[a+1]=v>>8;end endtask
task put32;input integer a;input [31:0] v;
    begin disk[a]=v;disk[a+1]=v>>8;disk[a+2]=v>>16;disk[a+3]=v>>24;end endtask
task header_crc;
    begin crc=32'hffffffff;for(i=0;i<508;i=i+1)crc=crc_byte(crc,disk[7*512+i]);put32(7*512+508,~crc);end
endtask
task init_disk;
    begin
        for(i=0;i<65536;i=i+1)disk[i]=0;
        disk[0]=8'heb;put16(11,512);disk[13]=1;put16(14,1);disk[16]=1;
        put32(32,128);put32(36,1);put32(44,2);put16(510,16'haa55);
        // FAT at LBA1; root cluster2 at LBA2; fragmented file starts cluster7/LBA7.
        put32(512+2*4,32'h0fffffff);
        for(i=0;i<44;i=i+1)put32(512+(7+i*2)*4,i==43?32'h0fffffff:9+i*2);
        for(i=0;i<8;i=i+1)disk[1024+i]=selected_stem[63-i*8-:8];
        disk[1032]="B";disk[1033]="I";disk[1034]="N";disk[1035]=8'h20;
        put16(1024+26,7);put32(1024+28,512+3*RECORD+512);
        put32(7*512,32'h4449564d);put16(7*512+4,2);put16(7*512+6,512);
        put16(7*512+8,16);put16(7*512+10,16);put16(7*512+12,30);put16(7*512+14,1);
        put32(7*512+16,3);put32(7*512+20,FB);put32(7*512+24,1);put32(7*512+28,1);
        put32(7*512+32,3*RECORD);put32(7*512+40,RECORD);put32(7*512+44,48000);
        put16(7*512+48,1600);disk[7*512+50]=2;disk[7*512+51]=16;
        put32(7*512+52,PB);put32(7*512+56,PS);put32(7*512+60,512+3*RECORD);
        put32(7*512+72,1000);put32(7*512+76,255);put32(7*512+80,512);
        header_crc();
        for(f=0;f<3;f=f+1)for(p=0;p<RECORD;p=p+1)begin
            sector=1+(f*RECORD+p)/512;
            disk[(7+sector*2)*512+p%512]=p<FB?((p*7)^((f+1)*31)):
                p<FB+PB?((p-FB+f*17)&255):0;
        end
    end
endtask
always @(posedge clk) if(rst_n)begin
    if(byte_valid)begin
        if(byte_data!==(((bytes_seen*7)^((frames_seen%3+1)*31))&255))$fatal(1,"pixel mismatch");
        bytes_seen=bytes_seen+1;
    end
    if(pcm_valid)begin
        if(pcm_byte!==((pcm_seen+(frames_seen%3)*17)&255))$fatal(1,"PCM mismatch/padding emitted");
        pcm_seen=pcm_seen+1;
    end
    if(frame_done)begin
        if(bytes_seen!=FB||pcm_seen!=want_pcm)$fatal(1,"wrong provisional counts %0d %0d",bytes_seen,pcm_seen);
        bytes_seen=0;pcm_seen=0;frames_seen=frames_seen+1;
    end
end
initial forever begin
    @(negedge clk);
    if(sd_start)begin
        if(sd_blocks==0||sd_lba+sd_blocks>128)$fatal(1,"read out of bounds");
        for(j=0;j<sd_blocks*512;j=j+1)begin @(negedge clk);sd_valid=1;sd_data=disk[sd_lba*512+j];end
        @(negedge clk);sd_valid=0;
        repeat(3)@(negedge clk);
        if(fail_audio&&dut.operation==4&&dut.frame_position>=FB+PB)sd_error=8'ha3;
        sd_done=1;@(negedge clk);sd_done=0;
    end
end
task reset_reader;
    begin @(negedge clk);rst_n=0;sd_error=0;next_frame=0;bytes_seen=0;pcm_seen=0;frames_seen=0;
        repeat(5)@(negedge clk);rst_n=1;end
endtask
task frame;
    begin @(negedge clk);next_frame=1;@(negedge clk);next_frame=0;
        wait(frame_done||error);repeat(2)@(negedge clk);end
endtask
initial begin
    init_disk();reset_reader();wait(ready||error);
    if(error||frame_count!=3)$fatal(1,"v2 mount %h/%h",stage,error);
    for(k=0;k<5;k=k+1)begin frame();if(error)$fatal(1,"v2 read %h",error);end
    if(frames_seen!=5)$fatal(1,"v2 loop");
    $display("PASS MVID2 dynamic filename, fragmented FAT, interleaved PCM, padding exclusion and EOF loop");
    start_frame=2;reset_reader();wait(ready||error);frames_seen=2;
    #1;if(error||frame_index!=2||!frame_has_audio)$fatal(1,"Resume seek failed error=%h stage=%h frame=%d audio=%b",error,stage,frame_index,frame_has_audio);
    frame();frame();
    if(error||frame_index!=1)$fatal(1,"Resume/loop failed");
    $display("PASS fragmented file resume at frame two and normal EOF loop");
    start_frame=0;
    init_disk();want_pcm=0;
    put32(1024+28,512+3*FB+9216);
    put32(7*512+28,2);put32(7*512+32,3*FB);put32(7*512+40,FB);
    put32(7*512+44,0);put16(7*512+48,0);disk[7*512+50]=0;disk[7*512+51]=0;
    put32(7*512+52,0);put32(7*512+56,0);put32(7*512+60,512+3*FB);
    put32(7*512+68,1);put32(7*512+76,0);put32(7*512+80,9216);header_crc();
    for(f=0;f<3;f=f+1)for(p=0;p<FB;p=p+1)
        disk[(9+f*2)*512+p]=(p*7)^((f+1)*31);
    reset_reader();wait(ready||error);
    if(error)$fatal(1,"silent/caption v2 rejected %h",error);
    for(k=0;k<5;k=k+1)begin frame();if(error)$fatal(1,"silent v2 failed %h",error);end
    $display("PASS silent exhibit v2 with caption tail, zero PCM and loop");
    want_pcm=PB;
    init_disk();put32(7*512+40,RECORD+512);header_crc();reset_reader();wait(error);
    if(error!=7||ready)$fatal(1,"invalid stride accepted");
    $display("PASS CRC-valid invalid record stride rejected");
    // Low count bits and all lengths still describe the valid three-frame file.
    // Narrow arithmetic must not let this oversized count alias that file.
    init_disk();put32(7*512+16,32'h00800003);header_crc();reset_reader();wait(error||ready);
    if(error!=7||ready)$fatal(1,"oversized frame count aliased valid payload");
    $display("PASS CRC-valid oversized frame count rejected without truncation alias");
    init_disk();fail_audio=1;reset_reader();wait(ready||error);frame();
    if(error!=8'he0||frames_seen!=0)$fatal(1,"audio-tail CRC failure published frame");
    $display("PASS audio-tail transport failure blocks whole-frame publication");
    $display("PASS tb_mvid2_reader");$finish;
end
initial begin #8_000_000;$fatal(1,"timeout %h/%h",stage,error);end
endmodule
