`timescale 1ns/1ps
// Real vendor CDC FIFOs and arbitration; abstract SDRAM latency, not electrical timing.
module tb_mvid_scan_concurrent;
reg mem_clk=0,write_clk=0,read_clk=0,rst=1;
always #10 mem_clk=~mem_clk;
always #5 write_clk=~write_clk;
always #6.667 read_clk=~read_clk;
reg write_req=0,write_en=0,frame_begin=0;
reg [31:0] write_data=0;
wire write_ack,write_finish,read_req,read_ack,read_en,full,empty,valid;
wire wr,rd;wire [20:0] wa,ra,read_base,read_len;wire [31:0] wd,data;
wire [3:0] dm;
reg [3:0] pending=0;
reg [31:0] returned[0:3],memory[0:307199];
integer i,j,sx,sy,refresh=0,writes=0,checked=0;
reg [10:0] x=0;reg [9:0] y=0;
reg de=0,hs=1,vs=1;
wire hs_o,vs_o,de_o,underflow;wire [15:0] pixel;
reg [15:0] expected0=0,expected1=0;
wire busy=refresh<22;
function [15:0] sample;
    input integer p;
    begin sample=(p*73)^(p>>7)^16'hace1;end
endfunction
frame_read_write #(.WRITE_BURST_SIZE(128),.READ_BURST_SIZE(64),.READ_LOOP(0),.TURNAROUND_CYCLES(8)) dut(
    .rst(rst),.mem_clk(mem_clk),.Sdr_init_done(1'b1),.Sdr_init_ref_vld(1'b0),.Sdr_busy(busy),
    .App_rd_en(rd),.App_rd_addr(ra),.Sdr_rd_en(pending[3]),.Sdr_rd_dout(returned[3]),
    .read_clk(read_clk),.read_req(read_req),.read_req_ack(read_ack),.read_finish(),
    .read_addr_0(read_base),.read_addr_1(21'd0),.read_addr_2(21'd0),.read_addr_3(21'd0),
    .read_addr_index(2'd0),.read_len(read_len),.read_en(read_en),.read_data(data),
    .read_fifo_valid(valid),.read_fifo_empty(empty),
    .App_wr_en(wr),.App_wr_addr(wa),.App_wr_din(wd),.App_wr_dm(dm),
    .write_clk(write_clk),.write_req(write_req),.write_req_ack(write_ack),.write_finish(write_finish),
    .write_fifo_full(full),.write_addr_0(21'd153600),.write_addr_1(21'd0),
    .write_addr_2(21'd0),.write_addr_3(21'd0),.write_addr_index(2'd0),
    .write_len(21'd153600),.write_en(write_en),.write_data(write_data));
mvid_scale2x #(.HEIGHT(480)) scale(
    .clk(read_clk),.rst_n(!rst),.frame_begin(frame_begin),.frame_base(21'd0),
    .de(de),.hs(hs),.vs(vs),.x(x),.y(y),.read_req(read_req),.read_base(read_base),.read_len(read_len),
    .read_ack(read_ack),.fifo_empty(empty),.fifo_valid(valid),.fifo_data(data),.read_en(read_en),
    .hs_o(hs_o),.vs_o(vs_o),.de_o(de_o),.pixel(pixel),.underflow(underflow));
always @(posedge mem_clk)if(!rst)begin
    // Approx. 0.44us refresh hold every 15.62us; never cut a started burst.
    if(refresh==780)begin
        if(!wr&&!rd&&pending==0)refresh<=0;
    end else refresh<=refresh+1;
    pending<=(pending<<1)|rd;
    if(rd)begin
        if(ra>=153600)$fatal(1,"Scan entered background slot");
        returned[0]<=memory[ra];
    end
    for(j=1;j<4;j=j+1)returned[j]<=returned[j-1];
    if(wr)begin
        if(wa<153600||wa>=307200)$fatal(1,"Write escaped background slot");
        if(wd!=={sample((wa-153600)*2),sample((wa-153600)*2+1)})$fatal(1,"Background write payload mismatch");
        memory[wa]<=wd;writes=writes+1;
    end
    if(wr&&rd)$fatal(1,"Overlapping SDRAM directions");
end
always @(posedge read_clk)if(!rst)begin
    if(de_o)begin
        if(pixel!==expected1)$fatal(1,"Concurrent pixel mismatch %0d got=%h expected=%h",checked,pixel,expected1);
        checked=checked+1;
    end
    if(underflow)$fatal(1,"Concurrent scan underflow at x=%0d y=%0d",x,y);
    expected1<=expected0;expected0<=sample((y*2/3)*640+x/2);
end
initial begin
    for(i=0;i<153600;i=i+1)memory[i]={sample(i*2),sample(i*2+1)};
    repeat(5)@(negedge mem_clk);rst=0;
    fork
        begin
            @(negedge write_clk);write_req=1;wait(write_ack);@(negedge write_clk);write_req=0;
            repeat(12)@(negedge write_clk);
            for(i=0;i<153600;i=i+1)begin
                if(full)$fatal(1,"Video write FIFO overflow");
                write_en=1;write_data={sample(i*2),sample(i*2+1)};
                @(negedge write_clk);write_en=0;
                // 4 bytes / 170ns = 23.53MB/s; faster than target video load.
                repeat(16)@(negedge write_clk);
            end
        end
        begin
            @(negedge read_clk);frame_begin=1;@(negedge read_clk);frame_begin=0;
            repeat(30*1650)@(negedge read_clk);
            for(sy=0;sy<720;sy=sy+1)begin
                y=sy;
                for(sx=0;sx<1280;sx=sx+1)begin x=sx;de=1;@(negedge read_clk);end
                de=0;repeat(370)@(negedge read_clk);
            end
            repeat(5)@(negedge read_clk);
        end
    join
    wait(write_finish);repeat(20)@(negedge mem_clk);
    if(checked!=1280*720||writes!=153600)$fatal(1,"Concurrent counts pixels=%0d writes=%0d",checked,writes);
    $display("PASS 640x480 concurrent write + 1280x720 scan, 921600 exact pixels, real CDC FIFOs, guard=8 and refresh holds");$finish;
end
initial begin #40_000_000;$fatal(1,"Concurrent scan timeout");end
endmodule
