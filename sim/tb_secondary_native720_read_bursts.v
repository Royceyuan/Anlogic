`timescale 1ns/1ps
`default_nettype none

// A 1280-pixel row is 640 words. Check the production SDRAM request
// scheduler and asynchronous FIFO across each configured burst boundary.
module tb_secondary_native720_read_bursts #(
    parameter integer READ_BURST = 128
);
reg mem_clk = 0, video_clk = 0, rst_n = 0;
reg read_req = 0, consume = 0;
reg sdr_rd_en = 0;
reg [31:0] sdr_rd_dout = 0;
wire app_rd_en, read_req_ack, read_fifo_valid, read_fifo_empty;
wire [20:0] app_rd_addr;
wire [31:0] read_data;
integer words_seen = 0, address_seen = 0;
always #10 mem_clk = ~mem_clk;
always #6.666 video_clk = ~video_clk;

frame_read_write #(
    .BURST_SIZE(128), .READ_BURST_SIZE(READ_BURST), .WRITE_BURST_SIZE(16),
    .READ_FIFO_OUTREG("NOREG"), .READ_LOOP(0)
) dut (
    .rst(~rst_n), .mem_clk(mem_clk), .Sdr_init_done(1'b1),
    .Sdr_init_ref_vld(1'b1), .Sdr_busy(1'b0),
    .App_rd_en(app_rd_en), .App_rd_addr(app_rd_addr),
    .Sdr_rd_en(sdr_rd_en), .Sdr_rd_dout(sdr_rd_dout),
    .read_clk(video_clk), .read_req(read_req), .read_req_ack(read_req_ack),
    .read_finish(), .read_fifo_valid(read_fifo_valid),
    .read_fifo_empty(read_fifo_empty), .read_addr_0(21'd0),
    .read_addr_1(21'd0), .read_addr_2(21'd0), .read_addr_3(21'd0),
    .read_addr_index(2'd0), .read_len(21'd640),
    .read_en(consume && !read_fifo_empty), .read_data(read_data),
    .App_wr_en(), .App_wr_addr(), .App_wr_din(), .App_wr_dm(),
    .write_clk(mem_clk), .write_req(1'b0), .write_req_ack(),
    .write_finish(), .write_fifo_full(),
    .write_addr_0(21'd0), .write_addr_1(21'd0),
    .write_addr_2(21'd0), .write_addr_3(21'd0),
    .write_addr_index(2'd0), .write_len(21'd0),
    .write_en(1'b0), .write_data(32'd0)
);

always @(posedge mem_clk) begin
    sdr_rd_en <= app_rd_en;
    if (app_rd_en) begin
        if (app_rd_addr !== address_seen)
            $fatal(1, "SDRAM address %0d, expected %0d", app_rd_addr, address_seen);
        sdr_rd_dout <= 32'hA5000000 + app_rd_addr;
        address_seen <= address_seen + 1;
    end
end

always @(posedge video_clk) begin
    if (read_fifo_valid) begin
        if (read_data !== 32'hA5000000 + words_seen)
            $fatal(1, "pixel pair word %0d, got %h", words_seen, read_data);
        words_seen <= words_seen + 1;
        if (words_seen == 639) begin
            if (address_seen != 640) $fatal(1, "address count %0d", address_seen);
            $display("PASS: 640 ordered words with %0d-word SDRAM bursts", READ_BURST);
            $finish;
        end
    end
end

initial begin
    repeat (4) @(negedge mem_clk);
    rst_n = 1;
    @(negedge video_clk); read_req = 1;
    wait (read_req_ack);
    @(negedge video_clk); read_req = 0;
    repeat (250) @(negedge video_clk);
    consume = 1;
end
initial begin
    #1000000;
    $fatal(1, "timeout after %0d returned words", words_seen);
end
endmodule

`default_nettype wire
