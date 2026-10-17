`timescale 1ns/1ps
`default_nettype none

module tb_fat32_wav_streamer #(parameter REUSE_GEOMETRY=1);
reg clk = 0, rst_n = 0, start = 0, restart=0, sd_init_done = 1;
reg [2:0] track_index = 0;
reg fifo_almost_full = 0;
wire sd_read;
wire [31:0] sd_addr;
reg [7:0] sd_data = 0;
reg sd_valid = 0, sd_end = 0;
wire fifo_wr;
wire [31:0] fifo_data;
wire ready, track_switch_ack, format_error, file_error;
wire [31:0] total_pcm_frames;
wire stream_done;
wire fs_geometry_ready;
wire [7:0] fs_sectors_per_cluster;
wire [31:0] fs_fat_start, fs_data_start, fs_root_cluster;
reg [7:0] sector [0:6][0:511];
reg serving = 0;
integer byte_no = 0, lba = 0, writes = 0, seen_lba6 = 0;
reg ready_seen = 0, ready_dropped = 0, track_switch_seen = 0;
integer mbr_reads=0, saved_mbr_reads;
reg check_geometry=0, geometry_changed=0;

fat32_wav_streamer #(.REUSE_GEOMETRY(REUSE_GEOMETRY)) dut (
    .clk(clk), .rst_n(rst_n), .start(start), .restart(restart),
    .track_index(track_index), .sd_init_done(sd_init_done),
    .sd_sec_read(sd_read), .sd_sec_read_addr(sd_addr), .sd_sec_read_data(sd_data),
    .sd_sec_read_data_valid(sd_valid), .sd_sec_read_end(sd_end), .fifo_almost_full(fifo_almost_full),
    .fifo_wr_en(fifo_wr), .fifo_wr_data(fifo_data), .audio_ready(ready),
    .track_switch_ack(track_switch_ack), .total_pcm_frames(total_pcm_frames),
    .stream_done(stream_done), .format_error(format_error), .file_error(file_error),
    .fs_geometry_ready(fs_geometry_ready),
    .fs_sectors_per_cluster(fs_sectors_per_cluster),
    .fs_fat_start(fs_fat_start), .fs_data_start(fs_data_start),
    .fs_root_cluster(fs_root_cluster));
always #5 clk = ~clk;
always @(negedge clk) begin
    sd_valid = 0; sd_end = 0;
    if (!serving && sd_read) begin
        serving = 1; byte_no = 0; lba = sd_addr;
        if(sd_addr==0) mbr_reads=mbr_reads+1;
        if (sd_addr == 6) seen_lba6 = 1;
    end
    if (serving) begin
        sd_valid = 1; sd_data = sector[lba][byte_no];
        if (byte_no == 511) begin sd_end = 1; serving = 0; end
        else byte_no = byte_no + 1;
    end
end
always @(posedge clk) if (fifo_wr) begin
    if (writes%128 == 0 && fifo_data != 32'h4433_2211) $fatal(1, "first WAV PCM frame order");
    if (writes%128 == 1 && fifo_data != 32'h8877_6655) $fatal(1, "second WAV PCM frame order");
    writes = writes + 1;
end
always @(posedge clk) begin
    if(check_geometry && (!fs_geometry_ready || fs_fat_start!=2 || fs_data_start!=3 ||
                          fs_root_cluster!=2 || fs_sectors_per_cluster!=1))
        geometry_changed<=1;
    if (!rst_n) begin
        ready_seen <= 1'b0;
        ready_dropped <= 1'b0;
        track_switch_seen <= 1'b0;
    end else begin
        if (ready_seen && !ready) ready_dropped <= 1'b1;
        if (ready) ready_seen <= 1'b1;
        if (track_switch_ack) track_switch_seen <= 1'b1;
    end
end
integer i, timeout;
initial begin
    for (i=0; i<512; i=i+1) begin
        sector[0][i] = 0; sector[1][i] = 0; sector[2][i] = 0;
        sector[3][i] = 0; sector[4][i] = 0; sector[5][i] = 0; sector[6][i] = 0;
    end
    // MBR: first partition begins at sector 1.
    sector[0][454]=1;
    // FAT32 VBR: one-sector clusters, FAT at LBA2, data at LBA3, root cluster 2.
    sector[1][11]=0; sector[1][12]=2; sector[1][13]=1; sector[1][14]=1;
    sector[1][16]=1; sector[1][36]=1; sector[1][44]=2;
    // Root cluster 2 points at cluster 3; AUDIO0.WAV deliberately lives in
    // that second root cluster.  Its data occupies linked clusters 4 and 5.
    sector[2][8]=3; sector[2][16]=5;
    sector[4][0]="A"; sector[4][1]="U"; sector[4][2]="D"; sector[4][3]="I"; sector[4][4]="O";
    sector[4][5]="0"; sector[4][6]=" "; sector[4][7]=" "; sector[4][8]="W"; sector[4][9]="A"; sector[4][10]="V";
    sector[4][26]=4; sector[4][28]=44; sector[4][29]=2;
    sector[5][0]="R"; sector[5][1]="I"; sector[5][2]="F"; sector[5][3]="F";
    sector[5][8]="W"; sector[5][9]="A"; sector[5][10]="V"; sector[5][11]="E";
    sector[5][12]="f"; sector[5][13]="m"; sector[5][14]="t"; sector[5][15]=" "; sector[5][16]=16;
    sector[5][20]=1; sector[5][22]=2; sector[5][24]=8'h80; sector[5][25]=8'hbb;
    sector[5][28]=0; sector[5][29]=8'hee; sector[5][30]=2; sector[5][32]=4; sector[5][34]=16;
    sector[5][36]="d"; sector[5][37]="a"; sector[5][38]="t"; sector[5][39]="a"; sector[5][40]=0; sector[5][41]=2;
    sector[5][44]=8'h11; sector[5][45]=8'h22; sector[5][46]=8'h33; sector[5][47]=8'h44;
    sector[5][48]=8'h55; sector[5][49]=8'h66; sector[5][50]=8'h77; sector[5][51]=8'h88;
    sector[6][0]=8'h99; sector[6][1]=8'haa; sector[6][2]=8'hbb; sector[6][3]=8'hcc;
    repeat (3) @(posedge clk); rst_n = 1; start = 1;
    repeat (6000) @(posedge clk);
    if (!ready || ready_dropped || format_error || file_error || writes != 128 ||
        !seen_lba6 || !stream_done || total_pcm_frames != 128)
        $fatal(1, "fragmented WAV parse or completion failed");
    // The active sector completes before the selector restarts at AUDIO1.WAV.
    @(negedge clk); track_index = 1; sector[4][5] = "1";
    repeat (6000) @(posedge clk);
    if (!track_switch_seen || !ready || format_error || file_error) begin
        $fatal(1, "AUDIO1.WAV selection failed");
    end
    // Silent/manual -> automatic restarts readers, not the card/image cache.
    // Re-reading VBR here used to transiently invalidate shared subtitle geometry.
    @(negedge clk); start=0;restart=1;check_geometry=1;saved_mbr_reads=mbr_reads;
    repeat(10)@(posedge clk);
    @(negedge clk);restart=0;start=1;
    repeat(6000)@(posedge clk);
    if(!ready || !stream_done || writes!=384 || format_error || file_error)
        $fatal(1,"light WAV rearm failed");
    if(REUSE_GEOMETRY && (geometry_changed || mbr_reads!=saved_mbr_reads))
        $fatal(1,"light rearm invalidated shared FAT geometry or reread MBR");
    check_geometry=0;
    // Returning from manual browsing leaves an unconsumed WAV in the FIFO.
    // A new artifact must switch even when backpressure prevents another sector.
    @(negedge clk); rst_n=0;start=0;track_index=4;sector[4][5]="4";writes=0;
    repeat(3)@(negedge clk);rst_n=1;start=1;
    timeout=0;
    while(!ready && timeout<6000)begin @(negedge clk);timeout=timeout+1;end
    if(!ready)$fatal(1,"AUDIO4 setup failed");
    fifo_almost_full=1;
    timeout=0;
    while((dut.state!=5'd7 || sd_read) && timeout<2000)begin
        @(negedge clk);timeout=timeout+1;
    end
    if(dut.state!=5'd7 || sd_read)$fatal(1,"did not reach sector-boundary FIFO stall");
    repeat(10)@(negedge clk);
    track_index=0;sector[4][5]="0";
    timeout=0;
    while(!track_switch_ack && timeout<20)begin @(negedge clk);timeout=timeout+1;end
    if(!track_switch_ack || ready || total_pcm_frames!=0 || stream_done)
        $fatal(1,"full FIFO blocked AUDIO4->AUDIO0 switch/retained stale ready");
    // The production ACK resets the FIFO; model that release without a KEY4.
    fifo_almost_full=0;writes=0;
    repeat(6000)@(negedge clk);
    if(!ready || !stream_done || writes!=128 || format_error || file_error || dut.active_track!=0)
        $fatal(1,"AUDIO0 did not prepare after full-FIFO switch");
    $display("PASS full-FIFO artifact switch AUDIO4->AUDIO0 without reset");
    // Root-directory miss is a sticky file error, not a silent audio loop.
    @(negedge clk); rst_n = 0; start = 0; track_index = 0; sector[4][0] = 0;
    repeat (520) @(posedge clk); serving = 0;
    repeat (3) @(posedge clk); rst_n = 1; start = 1;
    repeat (3500) @(posedge clk);
    if (!file_error || format_error) $fatal(1, "missing AUDIO0.WAV was not reported");
    // A malformed standard header is explicitly rejected.
    @(negedge clk); rst_n = 0; start = 0; sector[4][0] = "A"; sector[4][5] = "0"; sector[5][8] = "X";
    repeat (520) @(posedge clk); serving = 0;
    repeat (3) @(posedge clk); rst_n = 1; start = 1;
    repeat (4500) @(posedge clk);
    if (!format_error) $fatal(1, "invalid WAV header was not reported");
    $display("PASS tb_fat32_wav_streamer");
    $finish;
end
endmodule

`default_nettype wire
