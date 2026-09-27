`timescale 1ns/1ps
module tb_main5_overview_ram_equivalence;
reg clk=0, rst_n=0, start=0, valid=0, full=0, abort=0;
reg [9:0] row=0;
reg [15:0] pixel=0;
reg [3:0] panel=0;
wire [1:0] ready, req, en, done, error, abort_done;
wire [31:0] data [0:1];
wire [20:0] addr [0:1], len [0:1];
reg finish=0;
integer cycle=0, words=0, col, pass;
always #10 clk=~clk;
genvar g;
generate for(g=0;g<2;g=g+1) begin : writers
    bmp_sdram_row_writer #(.WIDTH(960),.HEIGHT(2),.ROW_BITS(10),
        .BURST_WORDS(64),.OVERVIEW_ENABLE(1),.OVERVIEW_BRAM(g),
        .ENABLE_ABORT(1)) dut (
        .clk(clk),.rst_n(rst_n),.start(start),.row_valid(valid),
        .row_index(row),.row_pixel(pixel),.row_last(1'b0),.row_ready(ready[g]),
        .frame_base_addr(21'd0),.overview_base_addr(21'd4096),
        .overview_frame_index(panel),.write_req(req[g]),.write_req_ack(req[g]),
        .write_en(en[g]),.write_data(data[g]),.write_base_addr(addr[g]),
        .write_len(len[g]),.write_fifo_full(full),.write_finish(finish),
        .abort(abort),.abort_done(abort_done[g]),.frame_done(done[g]),.error(error[g]));
end endgenerate
always @(negedge clk) begin
    cycle=cycle+1;
    full=(cycle%7==0 || cycle%11==0);
    if(rst_n) begin
        if(ready[0]!==ready[1] || req[0]!==req[1] || en[0]!==en[1] ||
           done[0]!==done[1] || error[0]!==error[1] || abort_done[0]!==abort_done[1])
            $fatal(1,"control mismatch");
        if(req[0] && (addr[0]!==addr[1] || len[0]!==len[1]))
            $fatal(1,"transaction mismatch");
        if(en[0] && data[0]!==data[1]) $fatal(1,"pixel mismatch");
    end
end
always @(posedge clk) begin
    finish<=0;
    if(start) words<=0;
    else if(en[0]) begin
        if(words==len[0]-1) begin words<=0; finish<=1; end
        else words<=words+1;
    end
end
initial begin
    repeat(3) @(negedge clk);
    rst_n=1;
    for(pass=0;pass<5;pass=pass+1) begin
        @(negedge clk); start=1; panel=pass;
        @(negedge clk); start=0;
        for(row=0;row<2;row=row+1) begin
            for(col=0;col<960;col=col+1) begin
                @(negedge clk); valid=1; pixel=col+row*960+pass*1920;
                #1;
                while(!ready[0]) begin @(negedge clk); #1; end
                @(posedge clk);
            end
            @(negedge clk); valid=0;
            if(row==0) wait(writers[0].dut.state==0);
        end
        wait(done[0]);
    end
    @(negedge clk); start=1; row=0;
    @(negedge clk); start=0;
    for(col=0;col<20;col=col+1) begin
        @(negedge clk); valid=1; pixel=col;
        #1;
        while(!ready[0]) begin @(negedge clk); #1; end
        @(posedge clk);
    end
    @(negedge clk); valid=0; abort=1;
    wait(abort_done==2'b11);
    @(negedge clk);
    $display("PASS overview RAM equivalence: five panels, 960-pixel rows, short bursts, backpressure and abort drain");
    $finish;
end
initial begin #10000000; $fatal(1,"timeout"); end
endmodule
