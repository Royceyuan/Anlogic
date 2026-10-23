`timescale 1ns/1ps
module tb_wav_cluster_address;
reg clk=0,rst_n=0,start=0,sd_valid=0,sd_end=0;
reg [7:0] sd_data=0,spc=1;
wire sd_read;
wire [31:0] sd_addr;
reg [31:0] file_cluster=3,lba=0;
reg serving=0,test_pass=0;
integer byte_no=0,power,offset,cycles;
reg [31:0] expected;
fat32_wav_streamer dut(.clk(clk),.rst_n(rst_n),.start(start),.restart(1'b0),
    .track_index(3'd0),.sd_init_done(1'b1),.sd_sec_read(sd_read),
    .sd_sec_read_addr(sd_addr),.sd_sec_read_data(sd_data),
    .sd_sec_read_data_valid(sd_valid),.sd_sec_read_end(sd_end),.fifo_almost_full(1'b0),
    .fifo_wr_en(),.fifo_wr_data(),.audio_ready(),.track_switch_ack(),.total_pcm_frames(),
    .stream_done(),.format_error(),.file_error(),.fs_geometry_ready(),.fs_sectors_per_cluster(),
    .fs_fat_start(),.fs_data_start(),.fs_root_cluster());
always #5 clk=~clk;
function [7:0] card_byte;
    input [31:0] addr;
    input integer index;
    begin
        card_byte=0;
        if(addr==0 && index==454)card_byte=1;
        if(addr==1)case(index)
            12:card_byte=2;
            13:card_byte=spc;
            14,16,36:card_byte=1;
            44:card_byte=2;
        endcase
        if(addr==3)case(index)
            0:card_byte="A"; 1:card_byte="U"; 2:card_byte="D";
            3:card_byte="I"; 4:card_byte="O"; 5:card_byte="0";
            6,7:card_byte=" "; 8:card_byte="W"; 9:card_byte="A"; 10:card_byte="V";
            20:card_byte=file_cluster[23:16]; 21:card_byte=file_cluster[31:24];
            26:card_byte=file_cluster[7:0]; 27:card_byte=file_cluster[15:8];
            28:card_byte=48;
        endcase
    end
endfunction
always @(negedge clk)begin
    sd_valid=0;sd_end=0;
    if(!rst_n)serving=0;
    else begin
        if(!serving && sd_read)begin serving=1;byte_no=0;lba=sd_addr;end
        if(serving)begin
            sd_valid=1;sd_data=card_byte(lba,byte_no);
            if(byte_no==511)begin sd_end=1;serving=0;end
            else byte_no=byte_no+1;
        end
    end
end
initial begin
    for(power=0;power<8;power=power+1)begin
        @(negedge clk);rst_n=0;start=0;spc=1<<power;file_cluster=65539+power*257;
        repeat(3)@(negedge clk);
        rst_n=1;start=1;cycles=0;
        while(!(sd_read && dut.state==8) && cycles<2000)begin
            @(posedge clk);#1;cycles=cycles+1;
        end
        expected=3+(file_cluster-2)*spc;
        if(cycles==2000 || sd_addr!==expected)
            $fatal(1,"WAV first data LBA: SPC=%0d actual=%h expected=%h",spc,sd_addr,expected);
        // Independent multiply-based oracle, including carry and wrap cases.
        for(offset=0;offset<spc;offset=offset+1)begin
            expected=32'hffffff00+(file_cluster-2)*spc+offset;
            if(dut.cluster_lba(file_cluster,32'hffffff00,offset)!==expected)
                $fatal(1,"WAV cluster/sector mapping: SPC=%0d offset=%0d",spc,offset);
        end
    end
    test_pass=1;
    $display("PASS WAV address all eight FAT32 cluster sizes, VBR capture and sector offsets");
    $finish;
end
endmodule
