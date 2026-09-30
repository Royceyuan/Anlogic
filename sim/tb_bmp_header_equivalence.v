`timescale 1ns/1ps
module tb_bmp_header_equivalence #(parameter integer ADAPTIVE_MODE=1);
reg clk=0, rst_n=0, valid=0, sector_end=0;
reg [7:0] data=0;
reg [7:0] header[0:53];
reg passed=0;
integer i, index, value, trial=0;
reg [7:0] saved;
always #5 clk=~clk;

`define LOADER_PORTS .clk(clk),.rst_n(rst_n),.load_start(1'b0), \
    .image_file_index(4'd0),.museum_detail_mode(1'b0), \
    .museum_artifact_index(3'd0),.museum_detail_index(2'd0), \
    .bmp_mode(1'b1),.sequence_mode(1'b0),.sd_init_done(1'b1), \
    .sd_sec_read_data(data),.sd_sec_read_data_valid(valid), \
    .sd_sec_read_end(sector_end),.image_continue(1'b1), \
    .sd_sec_read(),.sd_sec_read_addr(),.image_wr_en(),.image_wr_addr(), \
    .image_wr_data(),.image_wr_row(),.image_wr_col(),.busy(),.load_done(), \
    .load_error(),.status_code(),.error_stage(),.bmp_source_width(),.bmp_source_height()
fat32_image_loader #(.IMAGE_WIDTH(16),.IMAGE_HEIGHT(16),.ADAPTIVE_BMP(ADAPTIVE_MODE),
    .BMP_MAX_WIDTH(1920),.BMP_MAX_HEIGHT(1080)) dut (`LOADER_PORTS);
fat32_image_loader_reference #(.IMAGE_WIDTH(16),.IMAGE_HEIGHT(16),.ADAPTIVE_BMP(ADAPTIVE_MODE),
    .BMP_MAX_WIDTH(1920),.BMP_MAX_HEIGHT(1080)) reference (`LOADER_PORTS);
`undef LOADER_PORTS

// All public outputs, including the cycle on which invalid BMPs are rejected.
always @(posedge clk) begin
    #1;
    if(rst_n && {dut.sd_sec_read,dut.sd_sec_read_addr,dut.image_wr_en,
       dut.image_wr_addr,dut.image_wr_data,dut.image_wr_row,dut.image_wr_col,
       dut.busy,dut.load_done,dut.load_error,dut.status_code,dut.error_stage,
       dut.bmp_source_width,dut.bmp_source_height} !==
       {reference.sd_sec_read,reference.sd_sec_read_addr,reference.image_wr_en,
       reference.image_wr_addr,reference.image_wr_data,reference.image_wr_row,
       reference.image_wr_col,reference.busy,reference.load_done,reference.load_error,
       reference.status_code,reference.error_stage,reference.bmp_source_width,
       reference.bmp_source_height}) $fatal(1,"public BMP outputs differ trial=%d",trial);
end

task read_header;
    begin
        // Enter the established accepted-root-file path, without resetting
        // between trials: this also tests clearing a previous malformed file.
        @(negedge clk);
        force dut.state=5'd7; force reference.state=5'd7;
        force dut.file_found=1; force reference.file_found=1;
        force dut.file_cluster=3; force reference.file_cluster=3;
        force dut.file_size=822; force reference.file_size=822;
        force dut.active_bmp_mode=1; force reference.active_bmp_mode=1;
        sector_end=1;
        @(negedge clk); sector_end=0;
        release dut.state; release reference.state;
        release dut.file_found; release reference.file_found;
        release dut.file_cluster; release reference.file_cluster;
        release dut.file_size; release reference.file_size;
        force dut.state=5'd9; force reference.state=5'd9;
        for(i=0;i<54;i=i+1) begin
            force dut.file_bytes_seen=i; force reference.file_bytes_seen=i;
            data=header[i]; valid=1;
            @(negedge clk); valid=0;
            // SD valid stalls must not alter the accumulated format result.
            repeat(i%3) @(negedge clk);
        end
        if(dut.bmp_header_valid!==reference.bmp_header_valid)
            $fatal(1,"header acceptance differs trial=%d",trial);
        force dut.file_bytes_seen=54; force reference.file_bytes_seen=54;
        data=0; valid=1;
        @(negedge clk); valid=0;
        release dut.file_bytes_seen; release reference.file_bytes_seen;
        release dut.state; release reference.state;
        repeat(2) @(negedge clk);
        trial=trial+1;
    end
endtask

initial begin
    for(i=0;i<54;i=i+1) header[i]=0;
    header[0]="B"; header[1]="M"; header[10]=54; header[14]=40;
    header[18]=16; header[22]=16; header[26]=1; header[28]=24;
    repeat(3) @(negedge clk); rst_n=1;
    read_header;
    // All 256 values of every fixed header byte, not only bit-flip cases.
    for(index=0;index<34;index=index+1)
        if(index==0 || index==1 || (index>=14 && index<=17) || index>=26) begin
            saved=header[index];
            for(value=0;value<256;value=value+1) begin
                header[index]=value;
                read_header;
                header[index]=saved;
                read_header;
            end
        end
    // Dynamic dimensions and offsets retain their original 32-bit checks.
    for(index=10;index<26;index=index+1)
        if(index<=13 || index>=18) begin
            saved=header[index];
            for(value=0;value<256;value=value+1) begin
                header[index]=value;
                read_header;
            end
            header[index]=saved;
            read_header;
        end
    $display("PASS BMP header/public-output equivalence: adaptive=%0d, %0d trials with SD stalls and valid reentry",ADAPTIVE_MODE,trial);
    passed=1;
    $finish;
end
endmodule
