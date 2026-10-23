`timescale 1ns / 1ps
`default_nettype none

module tb_linebuf_scaler_zoom_stream #(parameter MEMORY_LIMIT = 0);
reg clk=0, rst_n=0, source_start=0, zoom_2x=0, video_de=0;
reg zoom_half=0;
reg [10:0] video_x=0;
reg [9:0] video_y=0;
reg signed [15:0] pan_x=0, pan_y=0;
wire [20:0] source_read_base;
reg test_pass=0;
wire source_read_req;
wire source_read_ack;
wire source_read_en;
wire [20:0] source_read_len;
reg source_fifo_valid=0;
integer memory_phase=0, fifo_available=512;
wire fifo_empty = MEMORY_LIMIT && fifo_available==0;
wire memory_arrival = memory_phase==2 && fifo_available<512;
reg [31:0] source_read_data=0;
integer fifo_word=0;
integer timeout;
integer misses=0;
integer pixel_mismatches=0;
integer selected_row;
integer selected_column;
reg [15:0] expected_pixel;

always #5 clk=~clk;
assign source_read_ack=source_read_req;

wire timing_de;
wire [10:0] timing_x, timing_active_x;
video_timing_programmable_pclk #(
    .H_VISIBLE(1280), .H_FRONT(110), .H_SYNC(40), .H_BACK(220),
    .V_VISIBLE(720), .V_FRONT(5), .V_SYNC(5), .V_BACK(20)
) timing_check (
    .clk(clk), .rst_n(rst_n), .de(timing_de), .x(timing_x),
    .active_x(timing_active_x), .hs(), .vs(), .y(), .frame_tick()
);
always @(negedge clk)
    if(rst_n && timing_active_x !== (timing_de ? timing_x : 11'd0))
        $fatal(1,"Registered active X changed raster alignment");

function [31:0] make_word;
    input integer word_index;
    integer row;
    integer column;
    reg [15:0] hi;
    reg [15:0] lo;
    begin
        row=word_index/480;
        column=(word_index%480)*2;
        hi=16'h8000|((row<<5)+column);
        lo=16'h8000|((row<<5)+column+1);
        make_word={hi,lo};
    end
endfunction

linebuf_scaler_960x540_to_1280x720 #(
    .LINEBUF_NOREG_SYNC_READ(1), .FIFO_RESPONSE_REGISTER(1), .ENABLE_PAN(1)
) dut (
    .clk(clk), .rst_n(rst_n), .source_start(source_start), .zoom_2x(zoom_2x),
    .zoom_half(zoom_half),
    .pan_x(pan_x), .pan_y(pan_y),
    .museum_recenter_active(1'b0), .museum_recenter_closing(1'b0),
    .museum_recenter_progress(8'd0), .museum_recenter_origin(3'd0),
    .source_base_addr(21'd0), .source_read_req(source_read_req),
    .source_read_ack(source_read_ack), .source_read_base_addr(source_read_base),
    .source_read_len(source_read_len), .source_fifo_empty(fifo_empty),
    .source_fifo_valid(source_fifo_valid), .source_read_en(source_read_en),
    .source_read_data(source_read_data), .video_de(video_de), .video_x(video_x),
    .video_y(video_y), .pixel565(), .frame_ready(), .source_frame_done(),
    .underflow()
);

always @(posedge clk) begin
    // Optimistic upper bound: 25 MHz memory / 75 MHz pixels, no refresh
    // or arbitration penalty, and an already full 512-word read FIFO.
    memory_phase <= memory_phase==2 ? 0 : memory_phase+1;
    if(source_start) fifo_available<=512;
    else if(MEMORY_LIMIT) fifo_available<=fifo_available+memory_arrival-source_read_en;
    source_fifo_valid <= source_read_en;
    if (source_start)
        fifo_word <= 0;
    else if (source_read_en) begin
        source_read_data <= make_word((zoom_half ?
                            (fifo_word/960)*1440+(fifo_word%960) : fifo_word)+source_read_base);
        if (fifo_word == source_read_len-1)
            fifo_word <= 0;
        else
            fifo_word <= fifo_word+1;
    end
end

always @(posedge clk)
    if (video_de && dut.in_picture && !dut.source_row_hit && misses<8) begin
        $display("MISS x=%0d y=%0d src_y=%0d tags=%0d,%0d,%0d valid=%b",
                 video_x,video_y,dut.source_y,dut.slot_tag0,dut.slot_tag1,
                 dut.slot_tag2,dut.slot_valid);
        misses=misses+1;
    end

always @(posedge clk) begin
    #1;
    if (video_de) begin
        if(video_x==0 &&
           ((dut.slot_valid[0] && ((dut.slot_tag0<dut.source_y)!=(dut.slot_key0<dut.scaled_source_y))) ||
            (dut.slot_valid[1] && ((dut.slot_tag1<dut.source_y)!=(dut.slot_key1<dut.scaled_source_y))) ||
            (dut.slot_valid[2] && ((dut.slot_tag2<dut.source_y)!=(dut.slot_key2<dut.scaled_source_y)))))
            $fatal(1,"Row retirement key differs from source-row comparison");
        if(dut.source_row_hit !== (dut.in_picture &&
            ((dut.slot_valid[0] && dut.slot_epoch[0]==dut.display_epoch && dut.slot_tag0==dut.mapped_y[9:0]) ||
             (dut.slot_valid[1] && dut.slot_epoch[1]==dut.display_epoch && dut.slot_tag1==dut.mapped_y[9:0]) ||
             (dut.slot_valid[2] && dut.slot_epoch[2]==dut.display_epoch && dut.slot_tag2==dut.mapped_y[9:0]))))
            $fatal(1,"Row-key lookup differs from original tag/origin comparison");
        selected_row=(video_y*3)/(zoom_2x ? 8 : 4)+(zoom_2x ? 135 : 0);
        selected_column=(video_x*3)/(zoom_2x ? 8 : 4)+(zoom_2x ? 240 : 0);
        if(zoom_half)begin
            selected_row=((video_y-180)*3)/2;
            selected_column=((video_x-320)*3)/2;
        end
        selected_row=selected_row+$signed(pan_y);
        selected_column=selected_column+$signed(pan_x);
        expected_pixel=(selected_row<0 || selected_row>=540 ||
                        selected_column<0 || selected_column>=960 ||
                        (zoom_half && (video_x<320 || video_x>=960 || video_y<180 || video_y>=540))) ? 0 :
                        16'h8000|((selected_row<<5)+selected_column);
        if (dut.pixel565 !== expected_pixel && pixel_mismatches<8) begin
            $display("PIXEL MISS xy=%0d,%0d got=%h expected=%h tag=%0d x=%0d",
                     video_x,video_y,dut.pixel565,expected_pixel,
                     selected_row,dut.source_x_d);
            pixel_mismatches=pixel_mismatches+1;
        end
    end
end

task begin_stream;
    input zoom;
    begin
        @(negedge clk); zoom_2x=zoom; source_start=1;
        @(negedge clk); source_start=0;
        timeout=0;
        while (!dut.frame_ready && timeout<20000) begin
            @(posedge clk); timeout=timeout+1;
        end
        if (!dut.frame_ready) begin
            $display("FAIL stream zoom=%b did not prefill",zoom);
            $finish;
        end
    end
endtask

task scan_frame;
    integer x;
    integer y;
    begin
        for (y=0;y<720;y=y+1)begin
            for (x=0;x<1280;x=x+1) begin
                @(negedge clk); video_de=1; video_x=x; video_y=y;
            end
            if(zoom_half)begin
                @(negedge clk);video_de=0;repeat(369)@(negedge clk);
            end
        end
        @(negedge clk); video_de=0; video_x=0; video_y=0;
    end
endtask

initial begin
    repeat(3) @(posedge clk); rst_n=1;
    if(MEMORY_LIMIT)begin
        zoom_half=1;
        begin_stream(0); scan_frame;
        if(dut.underflow || pixel_mismatches) $fatal(1,"0.5x exceeds 25 MHz memory bandwidth");
        test_pass=1;
        $display("PASS half zoom with 25:75 MHz read bandwidth limit");
        $finish;
    end
    begin_stream(0);
    scan_frame;
    if (dut.underflow || pixel_mismatches != 0) begin
        $display("FAIL normal stream underflow=%b pixels=%0d",dut.underflow,pixel_mismatches);
        $finish;
    end
    begin_stream(1);
    misses=0;
    pixel_mismatches=0;
    scan_frame;
    scan_frame;
    if (dut.underflow || pixel_mismatches != 0) begin
        $display("FAIL zoom stream underflow=%b pixels=%0d",dut.underflow,pixel_mismatches);
        $finish;
    end
    $display("PASS zoom stream has no row-cache underflow");
    pan_x=20; pan_y=40;
    begin_stream(0); scan_frame; scan_frame;
    if(dut.underflow || pixel_mismatches) $fatal(1,"positive 1x pan stream");
    pan_x=-40; pan_y=-20;
    begin_stream(0); scan_frame; scan_frame;
    if(dut.underflow || pixel_mismatches) $fatal(1,"negative 1x pan stream");
    pan_x=240; pan_y=135;
    begin_stream(0); scan_frame; scan_frame;
    if(dut.underflow || pixel_mismatches) $fatal(1,"1x positive edge stream");
    pan_x=-240; pan_y=-135;
    begin_stream(0); scan_frame; scan_frame;
    if(dut.underflow || pixel_mismatches) $fatal(1,"1x negative edge stream");
    pan_x=240; pan_y=135;
    begin_stream(1); scan_frame; scan_frame;
    if(dut.underflow || pixel_mismatches) $fatal(1,"2x edge pan stream");
    test_pass=1;
    $display("PASS 1x/2x pan continuous frames, 20/40 pixels and edge");
    pan_x=0;pan_y=0;zoom_half=1;
    begin_stream(0); scan_frame; scan_frame;
    if(dut.underflow || pixel_mismatches) $fatal(1,"0.5x continuous frames");
    $display("PASS 0.5x centered 640x360, exact pixels, two frames without underflow");
    $finish;
end
endmodule

`default_nettype wire
