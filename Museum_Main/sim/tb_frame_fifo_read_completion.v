`timescale 1ns/1ps
module tb_frame_fifo_read_completion;
reg clk=0, rst=1, request=0, returned=0;
reg automatic_returns=0, return_pipeline=0;
wire response_valid=automatic_returns ? return_pipeline : returned;
wire ack, finish, busy, read_en;
integer commands=0, responses=0;
reg passed=0;
always #20 clk=~clk;
frame_fifo_read #(.BURST_SIZE(4), .LOOP_ENABLE(0)) dut (
    .rst(rst), .mem_clk(clk), .Sdr_init_done(1'b1),
    .Sdr_init_ref_vld(1'b0), .Sdr_busy(1'b0), .Sdr_rd_en(response_valid),
    .App_wr_busy(1'b0), .O_rd_busy(busy), .App_rd_en(read_en), .App_rd_addr(),
    .read_req(request), .read_req_ack(ack), .read_finish(finish),
    .read_addr_0(21'd0), .read_addr_1(21'd0), .read_addr_2(21'd0),
    .read_addr_3(21'd0), .read_addr_index(2'd0), .read_len(21'd7),
    .fifo_aclr(), .wrusedw(10'd0)
);
always @(posedge clk) begin
    if (rst) begin
        commands=0; responses=0; return_pipeline<=0;
    end else begin
        return_pipeline<=read_en;
        if (read_en) commands=commands+1;
        if (response_valid) responses=responses+1;
    end
end
task response;
    begin
        @(negedge clk); returned=1;
        @(negedge clk); returned=0;
    end
endtask
initial begin
    repeat(3) @(negedge clk); rst=0; request=1;
    wait(ack); @(negedge clk); request=0;
    wait(commands==4);
    response(); response(); response();
    // The final return may be delayed independently of issued commands.
    repeat(5) begin
        @(negedge clk);
        if (!busy || finish || commands!=4)
            $fatal(1,"read arbiter released before final data: cmd=%0d data=%0d", commands,responses);
    end
    response();
    wait(commands==7);
    response(); response();
    repeat(5) begin
        @(negedge clk);
        if (!busy || finish) $fatal(1,"partial burst released before final data");
    end
    response();
    wait(finish);
    if (commands!=7 || responses!=7) $fatal(1,"completion count mismatch");
    // Normal contiguous one-cycle returns must still complete both bursts.
    @(negedge clk); rst=1; automatic_returns=1;
    repeat(3) @(negedge clk); rst=0; request=1;
    wait(ack); @(negedge clk); request=0;
    wait(finish);
    if (commands!=7 || responses!=7) $fatal(1,"continuous completion count mismatch");
    passed=1;
    $display("PASS read completion: full and partial bursts retain ownership until last valid return");
    $finish;
end
initial begin #20000; $fatal(1,"read completion timeout"); end
endmodule
