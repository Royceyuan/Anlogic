`timescale 1ns/1ps
// Production burst reader and generated asynchronous FIFO at 25:75 MHz.
// SDRAM return latency/refresh are modeled; this is not an electrical model.
module tb_half_zoom_memory;
reg pclk=0,mclk=0,rst=1,start=0,half_zoom=1,double_zoom=0,de=0;
reg [10:0] x=0;
reg [9:0] y=0;
wire req,ack,pop,empty,valid,ready,underflow,aclr,command;
wire [20:0] base,len,address;
wire [31:0] data;
wire [15:0] pixel;
wire [8:0] used;
reg [3:0] returns=0;
reg [31:0] d0=0,d1=0,d2=0,d3=0;
integer refresh_phase=0,issued=0,source_word,sy,sx,errors=0;
reg passed=0;
reg [15:0] expected;
always #6.666667 pclk=~pclk;
always #20 mclk=~mclk;

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
frame_fifo_read #(.BURST_SIZE(128),.LOOP_ENABLE(1),.SKIP_ROW_WORDS(480)) reader (
    .rst(rst),.mem_clk(mclk),.read_skip_third_row(half_zoom),
    .Sdr_init_done(1'b1),.Sdr_init_ref_vld(1'b0),.Sdr_busy(1'b0),
    .Sdr_rd_en(returns[3]),.App_wr_busy(refresh_phase<6),.O_rd_busy(),
    .App_rd_en(command),.App_rd_addr(address),.read_req(req),.read_req_ack(ack),
    .read_finish(),.read_addr_0(base),.read_addr_1(21'd0),.read_addr_2(21'd0),
    .read_addr_3(21'd0),.read_addr_index(2'd0),.read_len(len),
    .fifo_aclr(aclr),.wrusedw({1'b0,used})
);
rfifo_32_32_512 fifo (
    .rst(rst|aclr),.clkw(mclk),.clkr(pclk),.we(returns[3]),.di(d3),.re(pop),
    .dout(data),.valid(valid),.empty_flag(empty),.full_flag(),.wrusedw(used),
    .rdusedw(),.afull(),.aempty()
);
always @(posedge mclk) begin
    refresh_phase <= refresh_phase==194 ? 0 : refresh_phase+1;
    returns <= {returns[2:0],command};
    d0<=pattern(address); d1<=d0; d2<=d1; d3<=d2;
    if(rst || aclr) begin issued<=0; returns<=0; end
    else if(command)begin
        source_word=base+(half_zoom ? (issued/960)*1440+issued%960 : issued);
        if(address!==source_word) $fatal(1,"SDRAM address %d expected %d",address,source_word);
        issued<=issued==len-1 ? 0 : issued+1;
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
    passed=1;
    $display("PASS 25/75 MHz production reader/FIFO, refresh gaps, half/normal/double/half, exact pixels and row-skip addresses");
    $finish;
end
initial begin #120000000; $fatal(1,"memory test timeout"); end
endmodule
