`timescale 1ns/1ps
module tb_fat32_mvid_reader #(parameter integer WIDTH=16,HEIGHT=16,SPC=1,FPS=30);
localparam FRAME_BYTES=WIDTH*HEIGHT*2,ROOT_LBA=3+8*SPC,HEADER_LBA=3+18*SPC;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,card_ready=1,next_frame=0,sd_done=0,sd_valid=0;
reg [7:0] sd_data=0,sd_error=0;
wire sd_start,byte_valid,ready,frame_busy,frame_done;
wire [31:0] sd_lba,sd_blocks,frame_index,frame_count;
wire [7:0] byte_data,error,stage;
fat32_mvid_reader #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.FPS(FPS)) dut(.*);
reg [7:0] disk[0:65535];
integer i,j,k,bytes_seen=0,frames_seen=0,requests=0;
integer clusters[0:6];
integer f,p,file_sector,physical_sector;
reg bad_transport=0,stop_server=0;
reg [31:0] mutated_crc;
function [31:0] crc32_byte;
    input [31:0] crc;input [7:0] value;reg [31:0] c;integer n;
    begin c=crc^value;for(n=0;n<8;n=n+1)c=(c>>1)^(c[0]?32'hedb88320:0);crc32_byte=c;end
endfunction
task put16;
    input integer p;input [15:0] value;
    begin disk[p]=value[7:0];disk[p+1]=value[15:8];end
endtask
task put32;
    input integer p;input [31:0] value;
    begin disk[p]=value[7:0];disk[p+1]=value[15:8];disk[p+2]=value[23:16];disk[p+3]=value[31:24];end
endtask
task create_disk;
    reg [31:0] crc;
    begin
        for(i=0;i<65536;i=i+1)disk[i]=0;
        // MBR -> LBA1 VBR. Root spans non-contiguous clusters 2 -> 10.
        disk[450]=8'h0c;put32(454,1);put16(510,16'haa55);
        disk[512]=8'heb;put16(512+11,512);disk[512+13]=SPC;
        put16(512+14,1);disk[512+16]=1;put32(512+32,127);
        put32(512+36,1);put32(512+44,2);put16(512+510,16'haa55);
        // FAT LBA2, data LBA3. Deliberately fragmented file clusters.
        put32(1024+2*4,10);put32(1024+10*4,32'h0fffffff);
        clusters[0]=20;clusters[1]=23;clusters[2]=30;clusters[3]=25;
        clusters[4]=40;clusters[5]=37;clusters[6]=50;
        for(i=0;i<6;i=i+1)put32(1024+clusters[i]*4,clusters[i+1]);
        put32(1024+50*4,32'h0fffffff);
        for(i=0;i<16*SPC;i=i+1)disk[3*512+i*32]=8'he5;
        disk[ROOT_LBA*512+0]="V";disk[ROOT_LBA*512+1]="I";disk[ROOT_LBA*512+2]="D";
        disk[ROOT_LBA*512+3]="E";disk[ROOT_LBA*512+4]="O";disk[ROOT_LBA*512+5]="0";
        disk[ROOT_LBA*512+6]=" ";disk[ROOT_LBA*512+7]=" ";disk[ROOT_LBA*512+8]="B";
        disk[ROOT_LBA*512+9]="I";disk[ROOT_LBA*512+10]="N";disk[ROOT_LBA*512+11]=8'h20;
        put16(ROOT_LBA*512+26,20);put32(ROOT_LBA*512+28,512+3*FRAME_BYTES);
        put32(HEADER_LBA*512,32'h4449564d);put16(HEADER_LBA*512+4,1);put16(HEADER_LBA*512+6,512);
        put16(HEADER_LBA*512+8,WIDTH);put16(HEADER_LBA*512+10,HEIGHT);
        put16(HEADER_LBA*512+12,FPS);put16(HEADER_LBA*512+14,1);
        put32(HEADER_LBA*512+16,3);put32(HEADER_LBA*512+20,FRAME_BYTES);
        put32(HEADER_LBA*512+24,1);put32(HEADER_LBA*512+32,3*FRAME_BYTES);
        crc=32'hffffffff;for(i=0;i<508;i=i+1)crc=crc32_byte(crc,disk[HEADER_LBA*512+i]);
        put32(HEADER_LBA*512+508,~crc);
        for(f=0;f<3;f=f+1)for(p=0;p<FRAME_BYTES;p=p+1)begin
            file_sector=1+(f*FRAME_BYTES+p)/512;
            physical_sector=3+(clusters[file_sector/SPC]-2)*SPC+file_sector%SPC;
            disk[physical_sector*512+p%512]=(p*7)^(f==0?8'h35:f==1?8'h67:8'h91);
        end
    end
endtask
always @(posedge clk) if(rst_n)begin
    if(byte_valid) begin
        case(frames_seen%3)
            0:if(byte_data!==(((bytes_seen*7)^8'h35)&255))$fatal(1,"Frame0 byte mismatch %d",bytes_seen);
            1:if(byte_data!==(((bytes_seen*7)^8'h67)&255))$fatal(1,"Frame1 byte mismatch");
            2:if(byte_data!==(((bytes_seen*7)^8'h91)&255))$fatal(1,"Frame2 byte mismatch");
        endcase
        bytes_seen=bytes_seen+1;
    end
    if(frame_done)begin
        if(bytes_seen!=FRAME_BYTES)$fatal(1,"Published incomplete frame: %d",bytes_seen);
        frames_seen=frames_seen+1;bytes_seen=0;
    end
end
// Block transport stand-in: validates filesystem independently of SD PHY.
initial forever begin
    @(negedge clk);
    if(sd_start&&!stop_server)begin
        requests=requests+1;
        if(sd_lba+sd_blocks>128||sd_blocks==0)$fatal(1,"Out-of-range disk read");
        for(j=0;j<sd_blocks*512;j=j+1)begin
            @(negedge clk);sd_valid=1;sd_data=disk[sd_lba*512+j];
        end
        @(negedge clk);sd_valid=0;
        repeat(4)@(negedge clk);
        if(bad_transport&&dut.operation==4)begin sd_error=8'ha3;sd_done=1;end
        else sd_done=1;
        @(negedge clk);sd_done=0;
    end
end
task reset_reader;
    begin
        @(negedge clk);rst_n=0;next_frame=0;sd_error=0;bytes_seen=0;frames_seen=0;
        repeat(5)@(negedge clk);rst_n=1;
    end
endtask
task get_frame;
    begin
        @(negedge clk);next_frame=1;@(negedge clk);next_frame=0;
        wait(frame_done||error!=0);@(negedge clk);@(negedge clk);
    end
endtask
initial begin
    create_disk();reset_reader();wait(ready||error!=0);
    if(error!=0||frame_count!=3)$fatal(1,"Mount/header failed %h %h",stage,error);
    for(k=0;k<5;k=k+1)begin get_frame();if(error!=0)$fatal(1,"Read failed %h",error);end
    if(frames_seen!=5)$fatal(1,"Loop did not deliver frames");
    $display("PASS MBR mount, fragmented root and video chains, all frame bytes, EOF loop");
    create_disk();disk[HEADER_LBA*512+40]=1;reset_reader();wait(error!=0);
    if(error!=7||ready)$fatal(1,"Bad header accepted");
    $display("PASS bad MVID header/CRC rejected");
    create_disk();disk[HEADER_LBA*512+508]=disk[HEADER_LBA*512+508]^1;
    reset_reader();wait(error!=0);
    if(error!=7||ready)$fatal(1,"Corrupt CRC32 accepted with otherwise valid header");
    $display("PASS isolated header CRC32 corruption rejected");
    create_disk();put16(HEADER_LBA*512+12,FPS==30?40:30);
    mutated_crc=32'hffffffff;
    for(i=0;i<508;i=i+1)mutated_crc=crc32_byte(mutated_crc,disk[HEADER_LBA*512+i]);
    put32(HEADER_LBA*512+508,~mutated_crc);
    reset_reader();wait(error!=0);
    if(error!=7||ready)$fatal(1,"Different frame rate accepted with valid CRC");
    $display("PASS mismatched frame rate rejected with valid CRC (expected %0d fps)",FPS);
    create_disk();put32(ROOT_LBA*512+28,512+2*FRAME_BYTES);reset_reader();wait(error!=0);
    if(error!=7)$fatal(1,"File size mismatch accepted");
    $display("PASS mismatched file length rejected");
    create_disk();put16(512+40,16'h0080);reset_reader();wait(ready||error!=0);
    if(error!=0||!ready)$fatal(1,"Explicit active FAT zero rejected");
    create_disk();put16(512+40,16'h0081);reset_reader();wait(error!=0);
    if(error!=3||ready)$fatal(1,"Out-of-range active FAT accepted");
    $display("PASS registered active FAT selection validation");
    create_disk();put32(1024+20*4,32'h0fffffff);reset_reader();wait(ready||error!=0);get_frame();
    if(error!=6||frames_seen!=0)$fatal(1,"Early FAT end accepted");
    $display("PASS premature FAT EOC rejected without publication");
    create_disk();bad_transport=1;reset_reader();wait(ready||error!=0);get_frame();
    if(error!=8'he0||frames_seen!=0)$fatal(1,"Transport CRC failure published a frame");
    $display("PASS transport failure after payload prevents frame publication");
    $display("PASS fat32_mvid_reader all checks");$finish;
end
initial begin #5_000_000;$fatal(1,"Timeout state=%h error=%h",stage,error);end
endmodule
