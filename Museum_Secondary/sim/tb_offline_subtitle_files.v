`timescale 1ns/1ps
// Read-only replay of the actual TF files through the production subtitle FSM.
// Synthetic FAT32 uses eight sectors/cluster; every cue crosses cluster edges.
module tb_offline_subtitle_files;
reg clk=0, vclk=0, rst=0, start=0, active=0, tick=0;
reg [2:0] track=0;
reg [31:0] audio_frame=0;
wire request, ready, format_error, file_error;
wire [31:0] address;
reg [7:0] data=0;
reg valid=0, done=0, reading=0, seen=0;
reg [31:0] sector=0;
integer byte_no=0, file_size, fd, count, cue, timeout, frames=0;
reg [7:0] file_data[0:399999];
reg test_pass=0;
always #5 clk=~clk;
always #7 vclk=~vclk;
always @(posedge vclk) begin
    frames<=frames+1;
    tick<=frames%64==0;
end
museum_subtitle_overlay #(.PIPE_RAM_OUTPUT(1)) dut (
    .clk_50m(clk),.rst_n_50m(rst),.start(start),.restart(1'b0),
    .lecture_active(active),.lecture_paused(1'b0),.lecture_finished(1'b0),
    .track_index(track),.audio_frame_index(audio_frame),.sd_init_done(1'b1),
    .fs_geometry_ready(1'b1),.fs_sectors_per_cluster(8'd8),
    .fs_fat_start(32'd33),.fs_data_start(32'd35),.fs_root_cluster(32'd2),
    .sd_sec_read(request),.sd_sec_read_addr(address),.sd_sec_read_data(data),
    .sd_sec_read_data_valid(valid),.sd_sec_read_end(done),
    .subtitle_ready(ready),.format_error(format_error),.file_error(file_error),
    .video_clk(vclk),.video_rst_n(rst),.video_frame_tick(tick),
    .hs_i(1'b1),.vs_i(1'b1),.de_i(1'b0),.x_i(11'd0),.y_i(10'd0),.rgb_i(24'd0)
);
function [7:0] disk_byte;
    input integer lba, offset;
    integer cluster, fat_value, position;
    begin
        disk_byte=0;
        if(lba==33) begin
            cluster=offset/4;
            fat_value=(cluster>=3 && cluster<3+(file_size+4095)/4096-1) ? cluster+1 : 32'h0fffffff;
            disk_byte=fat_value>>((offset%4)*8);
        end else if(lba==35) begin
            case(offset)
                0:disk_byte="S"; 1:disk_byte="U"; 2:disk_byte="B";
                3:disk_byte="0"+track;
                4,5,6,7:disk_byte=" ";
                8:disk_byte="B"; 9:disk_byte="I"; 10:disk_byte="N";
                11:disk_byte=8'h20; 26:disk_byte=3;
                28,29,30,31:disk_byte=file_size>>((offset-28)*8);
            endcase
        end else if(lba>=43) begin
            position=(lba-43)*512+offset;
            if(position<file_size) disk_byte=file_data[position];
        end
    end
endfunction
always @(posedge clk) begin
    valid<=0; done<=0;
    if(!rst) begin reading<=0; seen<=0; end
    else begin
        if(!request) seen<=0;
        if(!reading && request && !seen) begin
            reading<=1; seen<=1; sector<=address; byte_no<=0;
        end else if(reading) begin
            valid<=1; data<=disk_byte(sector,byte_no);
            if(byte_no==511) begin reading<=0; done<=1; end
            else byte_no<=byte_no+1;
        end
    end
end
initial begin
    for(count=0;count<6;count=count+1) begin
        @(negedge clk); rst=0; start=0; active=0; track=count; audio_frame=0;
        fd=$fopen($sformatf("tools/OfflineVideo/packages/subtitles/SUB%0d.BIN",count),"rb");
        if(!fd) $fatal(1,"Generate the six local SUB tracks before replay; TF is not accessed");
        file_size=$fread(file_data,fd); $fclose(fd);
        repeat(8) @(negedge clk);
        rst=1; start=1; timeout=0;
        if(count==0)begin
            wait(dut.state==5&&dut.data_address_step==2);
            @(negedge clk);track=1;
            @(negedge clk);
            if(dut.data_address_step!=0||request)$fatal(1,"Track change kept stale address calculation");
            track=0;@(negedge clk);
            if(dut.data_address_step!=0||request)$fatal(1,"Second track change kept stale address calculation");
        end
        while(!ready && !format_error && !file_error && timeout<500000) begin
            @(negedge clk); timeout=timeout+1;
        end
        if(!ready || format_error || file_error) $fatal(1,"SUB%0d header/first cue failed state=%0d",count,dut.state);
        active=1; timeout=0;
        while(dut.state!=14 && !format_error && !file_error && timeout<1000000) begin
            @(negedge clk); timeout=timeout+1;
            if(dut.cue_ready) audio_frame=dut.cue_start+1;
        end
        if(dut.state!=14 || format_error || file_error)
            $fatal(1,"SUB%0d failed cue=%0d state=%0d payload=%0d",count,dut.cue_index,dut.state,dut.payload_count);
        $display("PASS TF SUB%0d: %0d bytes, %0d cues, complete FAT-crossing replay",count,file_size,dut.cue_count);
    end
    test_pass=1;
    $finish;
end
initial begin #100000000;$fatal(1,"Subtitle replay timeout");end
endmodule
