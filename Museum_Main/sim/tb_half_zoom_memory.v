`timescale 1ns/1ps
// Production SDRAM scheduler and asynchronous FIFOs at 25/50/75 MHz.
// SDRAM return latency/refresh are modeled; this is not an electrical model.
module tb_half_zoom_memory;
localparam READ_LATENCY = 22;
reg pclk=0,mclk=0,wclk=0,rst=1,start=0,half_zoom=1,double_zoom=0,de=0;
reg [10:0] x=0;
reg [9:0] y=0;
wire req,ack,pop,empty,valid,ready,underflow,command;
wire write_ack,write_finish,write_full,write_command;
wire [20:0] base,len,address,write_address;
wire [31:0] data,write_payload;
wire [15:0] pixel;
reg [READ_LATENCY-1:0] returns=0;
reg [31:0] read_pipeline [0:READ_LATENCY-1];
integer delay_slot;
reg write_req=0,write_en=0;
reg [31:0] write_data=0;
integer refresh_phase=0,issued=0,source_word,sy,sx,errors=0;
integer write_word=0,written=0,half_writes=0;
reg passed=0;
reg [15:0] expected;
always #6.666667 pclk=~pclk;
always #20 mclk=~mclk;
always #10 wclk=~wclk;

function [31:0] pattern;
    input integer word_index;
    integer row,col;
    reg [15:0] hi,lo;
    begin
        row=word_index/480; col=(word_index%480)*2;
        hi=16'h8000|((row<<5)+col); lo=16'h8000|((row<<5)+col+1);
        pattern={hi,lo};
    end
endfunction

linebuf_scaler_960x540_to_1280x720 #(.LINEBUF_NOREG_SYNC_READ(1)) dut (
    .clk(pclk),.rst_n(!rst),.source_start(start),.zoom_2x(double_zoom),.zoom_half(half_zoom),
    .pan_x(16'd0),.pan_y(16'd0),.museum_recenter_active(1'b0),
    .museum_recenter_closing(1'b0),.museum_recenter_progress(8'd0),.museum_recenter_origin(3'd0),
    .source_base_addr(21'd0),.source_read_req(req),.source_read_ack(ack),
    .source_read_base_addr(base),.source_read_len(len),.source_fifo_empty(empty),
    .source_fifo_valid(valid),.source_read_en(pop),.source_read_data(data),
    .video_de(de),.video_x(x),.video_y(y),.pixel565(pixel),.frame_ready(ready),
    .source_frame_done(),.underflow(underflow)
);
frame_read_write #(.WRITE_BURST_SIZE(16),.READ_BURST_SIZE(128),
    .READ_LOOP(1),.READ_SKIP_ROW_WORDS(480)) store (
    .rst(rst),.mem_clk(mclk),.Sdr_init_done(1'b1),.Sdr_init_ref_vld(1'b0),
    .Sdr_busy(refresh_phase<6),
    .App_rd_en(command),.App_rd_addr(address),
    .Sdr_rd_en(returns[READ_LATENCY-1]),.Sdr_rd_dout(read_pipeline[READ_LATENCY-1]),
    .read_clk(pclk),.read_req(req),.read_skip_third_row(half_zoom),.read_req_ack(ack),
    .read_finish(),.read_fifo_valid(valid),.read_fifo_empty(empty),
    .read_addr_0(base),.read_addr_1(21'd0),.read_addr_2(21'd0),.read_addr_3(21'd0),
    .read_addr_index(2'd0),.read_len(len),.read_en(pop),.read_data(data),
    .App_wr_en(write_command),.App_wr_addr(write_address),.App_wr_din(write_payload),
    .App_wr_dm(),.write_clk(wclk),.write_req(write_req),.write_req_ack(write_ack),
    .write_finish(write_finish),.write_fifo_full(write_full),
    .write_addr_0(21'd1048576),.write_addr_1(21'd0),.write_addr_2(21'd0),
    .write_addr_3(21'd0),.write_addr_index(2'd0),.write_len(21'd16),
    .write_en(write_en),.write_data(write_data)
);
// Approximate the background TF writer with the production burst length
// and its request-to-FIFO delay. Writes target a separate SDRAM frame.
initial begin
    wait(de);
    forever begin
        @(negedge wclk); write_req=1;
        wait(write_ack);
        @(negedge wclk); write_req=0;
        repeat(64) @(negedge wclk);
        for(write_word=0;write_word<16;write_word=write_word+1) begin
            while(write_full) @(negedge wclk);
            write_data=32'h12340000+write_word; write_en=1;
            @(negedge wclk); write_en=0;
        end
        wait(write_finish);
        #32000;
    end
end
always @(posedge mclk) begin
    refresh_phase <= refresh_phase==194 ? 0 : refresh_phase+1;
    returns <= {returns[READ_LATENCY-2:0],command};
    read_pipeline[0] <= pattern(address);
    for(delay_slot=1;delay_slot<READ_LATENCY;delay_slot=delay_slot+1)
        read_pipeline[delay_slot] <= read_pipeline[delay_slot-1];
    if(rst || ack) begin issued<=0; returns<=0; end
    else if(command)begin
        source_word=base+(half_zoom ? (issued/960)*1440+issued%960 : issued);
        if(address!==source_word) $fatal(1,"SDRAM address %d expected %d",address,source_word);
        issued<=issued==len-1 ? 0 : issued+1;
    end
    if(write_command) begin
        if(command || write_address!=1048576+written%16 ||
           write_payload!==(32'h12340000+written%16))
            $fatal(1,"invalid concurrent write at word %0d",written);
        written=written+1;
        if(half_zoom && de) half_writes=half_writes+1;
    end
end
always @(posedge pclk)begin
    #1;
    if(de)begin
        sy=half_zoom ? ((y-180)*3)/2 : double_zoom ? (y*3)/8+135 : (y*3)/4;
        sx=half_zoom ? ((x-320)*3)/2 : double_zoom ? (x*3)/8+240 : (x*3)/4;
        expected=half_zoom && (x<320 || x>=960 || y<180 || y>=540) ? 0 :
                 16'h8000|((sy<<5)+sx);
        if(pixel!==expected)begin
            if(errors<8)$display("MISS (%0d,%0d) got %h expected %h",x,y,pixel,expected);
            errors=errors+1;
        end
    end
end
task prepare;
    begin
        @(negedge pclk);de=0;start=1;
        @(negedge pclk);start=0;
        wait(ready);
    end
endtask
task raster;
    integer xx,yy;
    begin
        for(yy=0;yy<750;yy=yy+1)
            for(xx=0;xx<1650;xx=xx+1)begin
                @(negedge pclk);x=xx;y=yy;de=xx<1280 && yy<720;
            end
        @(negedge pclk);de=0;
        if(errors || underflow)$fatal(1,"raster errors=%0d underflow=%b half=%b",errors,underflow,half_zoom);
    end
endtask
initial begin
    repeat(10)@(negedge mclk);rst=0;
    prepare; raster; raster;
    half_zoom=0;prepare;raster;
    double_zoom=1;prepare;raster;
    double_zoom=0;half_zoom=1;prepare;raster;
    if(half_writes==0) $fatal(1,"half zoom did not exercise concurrent writes");
    passed=1;
    $display("PASS production SDRAM arbitration, concurrent writes and exact half/normal/double/half pixels");
    $finish;
end
initial begin #120000000; $fatal(1,"memory test timeout"); end
endmodule
