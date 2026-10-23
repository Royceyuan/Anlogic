`timescale 1ns/1ps
// Arbitration contract test with real vendor CDC FIFOs, not a physical SDRAM model.
module tb_mvid_sdram_turnaround;
parameter GUARD=8, CHECK_BUSY=1;
reg mem_clk=0,write_clk=0,read_clk=0,rst=1,busy=CHECK_BUSY;
always #10 mem_clk=~mem_clk;
always #5 write_clk=~write_clk;
always #6.667 read_clk=~read_clk;
reg write_req=0,read_req=0,write_en=0;
reg [31:0] write_data=0;
wire write_ack,read_ack,write_finish,read_finish,full,empty,valid;
wire wr,rd;wire [20:0] wa,ra;wire [31:0] wd,data;
wire [3:0] dm;
reg [3:0] pending=0;
reg [31:0] returned[0:3];
integer cycles=0,last_write=-100,last_read=-100,last_return=-100;
integer writes=0,reads=0,received=0,write_bursts=0,read_bursts=0,j,i;
integer read_to_write=0,write_to_read=0;
reg was_write=0,was_read=0,consume=0;
wire read_en=consume&&!empty;
frame_read_write #(.WRITE_BURST_SIZE(64),.READ_BURST_SIZE(64),
    .READ_LOOP(0),.TURNAROUND_CYCLES(GUARD)) dut(
    .rst(rst),.mem_clk(mem_clk),.Sdr_init_done(1'b1),.Sdr_init_ref_vld(1'b0),.Sdr_busy(busy),
    .App_rd_en(rd),.App_rd_addr(ra),.Sdr_rd_en(pending[3]),.Sdr_rd_dout(returned[3]),
    .read_clk(read_clk),.read_req(read_req),.read_req_ack(read_ack),.read_finish(read_finish),
    .read_addr_0(21'd1024),.read_addr_1(21'd0),.read_addr_2(21'd0),.read_addr_3(21'd0),
    .read_addr_index(2'd0),.read_len(21'd512),.read_en(read_en),.read_data(data),
    .read_fifo_valid(valid),.read_fifo_empty(empty),
    .App_wr_en(wr),.App_wr_addr(wa),.App_wr_din(wd),.App_wr_dm(dm),
    .write_clk(write_clk),.write_req(write_req),.write_req_ack(write_ack),.write_finish(write_finish),
    .write_fifo_full(full),.write_addr_0(21'd0),.write_addr_1(21'd0),
    .write_addr_2(21'd0),.write_addr_3(21'd0),.write_addr_index(2'd0),
    .write_len(21'd512),.write_en(write_en),.write_data(write_data));
always @(posedge mem_clk) begin
    if(rst) pending<=0;
    else begin
        cycles=cycles+1;
        pending<=(pending<<1)|rd;
        returned[0]<=32'hface0000+(ra-1024);
        for(j=1;j<4;j=j+1) returned[j]<=returned[j-1];
        if(wr&&rd)$fatal(1,"Overlapping read/write commands");
        if(busy&&(wr||rd))$fatal(1,"Started command while controller busy");
        if(wr)begin
            if(!was_write)begin
                write_bursts=write_bursts+1;
                if(last_return>=0)read_to_write=read_to_write+1;
                if(cycles-last_read<=8||cycles-last_return<=8)
                    $fatal(1,"Missing read-to-write guard");
            end
            if(wa!==writes)$fatal(1,"Write address gap: %d %d",wa,writes);
            writes=writes+1;last_write=cycles;
        end
        if(rd)begin
            if(!was_read)begin
                read_bursts=read_bursts+1;
                if(last_write>=0)write_to_read=write_to_read+1;
                if(cycles-last_write<=8)$fatal(1,"Missing write-to-read guard");
            end
            if(ra!==1024+reads)$fatal(1,"Read address gap");
            reads=reads+1;last_read=cycles;
        end
        if(pending[3])last_return=cycles;
        was_write=wr;was_read=rd;
    end
end
always @(posedge read_clk) if(!rst&&valid)begin
    if(data!==(32'hface0000+received))$fatal(1,"FIFO payload mismatch at %d: %h",received,data);
    received=received+1;
end
initial begin
    repeat(5)@(negedge mem_clk);rst=0;
    fork
        begin
            @(negedge write_clk);write_req=1;
            wait(write_ack);@(negedge write_clk);write_req=0;
            repeat(12)@(negedge write_clk);
            for(i=0;i<512;i=i+1)begin
                // Model the TF producer's inter-block gap so both directions contend.
                if(i==256)repeat(800)@(negedge write_clk);
                while(full)@(negedge write_clk);
                write_en=1;write_data=i;@(negedge write_clk);write_en=0;
            end
        end
        begin
            @(negedge read_clk);read_req=1;
            wait(read_ack);@(negedge read_clk);read_req=0;
            repeat(12)@(negedge read_clk);consume=1;
        end
        begin repeat(60)@(negedge mem_clk);busy=0;end
    join
    wait(received==512&&writes==512);
    repeat(20)@(negedge mem_clk);
    if(reads!=512||write_bursts!=8||read_bursts!=8)$fatal(1,"Unexpected burst/word count");
    if(read_to_write==0||write_to_read==0)$fatal(1,"Both switching directions must be exercised");
    $display("PASS SDRAM arbitration guard=%0d, 512 read/write words, real CDC FIFO payload verified",GUARD);
    $finish;
end
initial begin #300000;$fatal(1,"Timeout wr=%d rd=%d received=%d",writes,reads,received);end
endmodule
