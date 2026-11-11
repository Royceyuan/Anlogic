`timescale 1ns / 1ps
module tb_museum_writer_abort;
reg write_clk=0,mem_clk=0,read_clk=0,rst_n=0;
reg row_valid=0,abort=0,read_req=0,controller_busy=1;
reg passed=0;
always #10 write_clk=~write_clk;
always #20 mem_clk=~mem_clk;
always #6.667 read_clk=~read_clk;

wire row_ready,write_req,write_ack,write_en,write_full,write_finish;
wire abort_done,frame_done,error,read_ack,read_empty;
wire [31:0] write_data,mem_write_data;
wire [20:0] write_base,write_len,mem_write_addr,mem_read_addr;
wire mem_write,mem_read;
reg [3:0] read_return=0;
integer queued=0,written=0,read_words=0;
integer tick=0,last_write=-100,last_return=-100;

bmp_sdram_row_writer #(
    .WIDTH(32),.HEIGHT(1),.ROW_BITS(1),.ADDR_BITS(21),
    .WORDS_PER_ROW(16),.BURST_WORDS(16),.ENABLE_ABORT(1)
) writer (
    .clk(write_clk),.rst_n(rst_n),.start(1'b0),
    .row_valid(row_valid),.row_index(1'b0),.row_pixel(16'h1234),
    .row_last(1'b0),.row_ready(row_ready),
    .frame_base_addr(21'd0),.overview_base_addr(21'd0),
    .overview_frame_index(4'hf),
    .write_req(write_req),.write_req_ack(write_ack),
    .write_en(write_en),.write_data(write_data),
    .write_base_addr(write_base),.write_len(write_len),
    .write_fifo_full(write_full),.write_finish(write_finish),
    .abort(abort),.abort_done(abort_done),.frame_done(frame_done),.error(error)
);

frame_read_write #(.WRITE_BURST_SIZE(16),.READ_BURST_SIZE(128),.READ_LOOP(0)) store (
    .rst(!rst_n),.mem_clk(mem_clk),.Sdr_init_done(1'b1),
    .Sdr_init_ref_vld(1'b0),.Sdr_busy(controller_busy),
    .App_rd_en(mem_read),.App_rd_addr(mem_read_addr),
    .Sdr_rd_en(read_return[3]),.Sdr_rd_dout(32'h89abcdef),
    .read_clk(read_clk),.read_req(read_req),.read_skip_third_row(1'b0),
    .read_req_ack(read_ack),.read_finish(),.read_fifo_valid(),.read_fifo_empty(read_empty),
    .read_addr_0(21'd1024),.read_addr_1(21'd0),.read_addr_2(21'd0),.read_addr_3(21'd0),
    .read_addr_index(2'd0),.read_len(21'd384),.read_en(!read_empty),.read_data(),
    .App_wr_en(mem_write),.App_wr_addr(mem_write_addr),.App_wr_din(mem_write_data),.App_wr_dm(),
    .write_clk(write_clk),.write_req(write_req),.write_req_ack(write_ack),
    .write_finish(write_finish),.write_fifo_full(write_full),
    .write_addr_0(write_base),.write_addr_1(21'd0),.write_addr_2(21'd0),.write_addr_3(21'd0),
    .write_addr_index(2'd0),.write_len(write_len),.write_en(write_en),.write_data(write_data)
);

always @(posedge write_clk) if (rst_n && write_en) begin
    queued=queued+1;
    if (queued==1) abort<=1'b1;
end

always @(posedge mem_clk) if (rst_n) begin
    tick=tick+1;
    // SDRAM accepts no new command during refresh or write recovery.
    // A dropped read leaves the read arbiter waiting for a missing word.
    read_return<={read_return[2:0],mem_read && !controller_busy && tick-last_write>8};
    if (mem_read) begin
        if (mem_read_addr!=1024+read_words) $fatal(1,"read address gap");
        read_words=read_words+1;
    end
    if (read_return[3]) last_return=tick;
    if (mem_write) begin
        if (controller_busy || tick-last_return<=8 || mem_read)
            $fatal(1,"write started before SDRAM was available");
        if (mem_write_addr!=written) $fatal(1,"write address gap");
        if (mem_write_data!==(written==0 ? 32'h12341234 : 32'd0))
            $fatal(1,"unexpected write payload at word %0d: %h",written,mem_write_data);
        written=written+1;
        last_write=tick;
    end
end

initial begin
    repeat (5) @(negedge mem_clk);
    rst_n=1'b1;
    read_req=1'b1;
    wait (read_ack);
    @(negedge read_clk); read_req=1'b0;
    row_valid=1'b1;
    repeat (6) @(negedge mem_clk);
    controller_busy=1'b0;
    // A refresh can start after the read arbiter grants a burst, but
    // before the first registered command reaches the SDRAM controller.
    wait (store.O_rd_busy);
    @(negedge mem_clk); controller_busy=1'b1;
    repeat (4) @(negedge mem_clk);
    controller_busy=1'b0;
    wait (abort && queued==16);
    wait (store.frame_fifo_write_m0.state==3);
    @(negedge mem_clk); controller_busy=1'b1;
    repeat (4) @(negedge mem_clk);
    controller_busy=1'b0;
    wait (abort_done);
    if (written!=16 || read_words!=384 || frame_done || error)
        $fatal(1,"aborted burst did not drain exactly once");
    passed=1'b1;
    $display("PASS writer abort across late SDRAM busy and read/write turnaround");
    $finish;
end

initial begin
    #100000;
    $fatal(1,"E507 reproduction: abort did not complete, queued=%0d written=%0d reads=%0d",
           queued,written,read_words);
end
endmodule
