`timescale 1ns/1ps
`default_nettype none

module tb_fat32_wav_streamer;
reg clk = 0, rst_n = 0, start = 0, sd_init_done = 1;
wire sd_read;
wire [31:0] sd_addr;
reg [7:0] sd_data = 0;
reg sd_valid = 0, sd_end = 0;
wire fifo_wr;
wire [31:0] fifo_data;
wire ready, format_error, file_error;
reg [7:0] sector [0:6][0:511];
reg serving = 0;
integer byte_no = 0, lba = 0, writes = 0, seen_lba6 = 0;
reg ready_seen = 0, ready_dropped = 0;

fat32_wav_streamer dut (.clk(clk), .rst_n(rst_n), .start(start), .sd_init_done(sd_init_done),
    .sd_sec_read(sd_read), .sd_sec_read_addr(sd_addr), .sd_sec_read_data(sd_data),
    .sd_sec_read_data_valid(sd_valid), .sd_sec_read_end(sd_end), .fifo_almost_full(1'b0),
    .fifo_wr_en(fifo_wr), .fifo_wr_data(fifo_data), .audio_ready(ready),
    .format_error(format_error), .file_error(file_error));
always #5 clk = ~clk;
always @(negedge clk) begin
    sd_valid = 0; sd_end = 0;
    if (!serving && sd_read) begin
        serving = 1; byte_no = 0; lba = sd_addr;
        if (sd_addr == 6) seen_lba6 = 1;
    end
    if (serving) begin
        sd_valid = 1; sd_data = sector[lba][byte_no];
        if (byte_no == 511) begin sd_end = 1; serving = 0; end
        else byte_no = byte_no + 1;
    end
end
always @(posedge clk) if (fifo_wr) begin
    if ((writes == 0 || writes == 128) && fifo_data != 32'h4433_2211) $fatal(1, "first WAV PCM frame order");
    if ((writes == 1 || writes == 129) && fifo_data != 32'h8877_6655) $fatal(1, "second WAV PCM frame order");
    writes = writes + 1;
end
always @(posedge clk) begin
    if (!rst_n) begin
        ready_seen <= 1'b0;
        ready_dropped <= 1'b0;
    end else begin
        if (ready_seen && !ready) ready_dropped <= 1'b1;
        if (ready) ready_seen <= 1'b1;
    end
end
integer i;
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
    // Root entry AUDIO.WAV: two linked clusters, canonical header plus 512 bytes.
    sector[3][0]="A"; sector[3][1]="U"; sector[3][2]="D"; sector[3][3]="I"; sector[3][4]="O";
    sector[3][5]=" "; sector[3][6]=" "; sector[3][7]=" "; sector[3][8]="W"; sector[3][9]="A"; sector[3][10]="V";
    sector[3][26]=4; sector[3][28]=44; sector[3][29]=2;
    sector[2][16]=5;
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
    repeat (4000) @(posedge clk);
    if (!ready || ready_dropped || format_error || file_error || writes < 128 || !seen_lba6)
        $fatal(1, "fragmented WAV parse or loop failed");
    // Root-directory miss is a sticky file error, not a silent audio loop.
    @(negedge clk); rst_n = 0; start = 0; serving = 0; sector[3][0] = 0;
    repeat (3) @(posedge clk); rst_n = 1; start = 1;
    repeat (1900) @(posedge clk);
    if (!file_error || format_error) $fatal(1, "missing AUDIO.WAV was not reported");
    // A malformed standard header is explicitly rejected.
    @(negedge clk); rst_n = 0; start = 0; serving = 0; sector[3][0] = "A"; sector[5][8] = "X";
    repeat (3) @(posedge clk); rst_n = 1; start = 1;
    repeat (2600) @(posedge clk);
    if (!format_error) $fatal(1, "invalid WAV header was not reported");
    $display("PASS tb_fat32_wav_streamer");
    $finish;
end
endmodule

`default_nettype wire
