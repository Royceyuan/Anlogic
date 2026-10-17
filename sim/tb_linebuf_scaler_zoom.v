`timescale 1ns / 1ps
`default_nettype none

module tb_linebuf_scaler_zoom;
reg clk=0, rst_n=0, source_start=0, zoom_2x=0;
reg test_pass=0;
reg signed [15:0] pan_x=0, pan_y=0;
reg museum_active=0, museum_closing=0;
reg [7:0] museum_progress=0;
reg [2:0] museum_origin=0;
reg [10:0] video_x=0;
reg [9:0] video_y=0;
wire [20:0] source_read_base_addr, source_read_len;
wire [10:0] source_x = dut.source_x;
wire [9:0] source_y = dut.source_y;
integer direction, origin, progress, step, expected_left, expected_offset;
integer zoom_case, pan_case, column, expected_column;
integer row, expected_row, expected_source_row;
reg [9:0] old_first_row,old_row_count,old_last_row;

always #5 clk=~clk;

linebuf_scaler_960x540_to_1280x720 #(.ENABLE_PAN(1)) dut (
    .clk(clk), .rst_n(rst_n), .source_start(source_start), .zoom_2x(zoom_2x),
    .pan_x(pan_x), .pan_y(pan_y),
    .museum_recenter_active(museum_active), .museum_recenter_closing(museum_closing),
    .museum_recenter_progress(museum_progress), .museum_recenter_origin(museum_origin),
    .source_base_addr(21'd1000), .source_read_req(), .source_read_ack(1'b0),
    .source_read_base_addr(source_read_base_addr), .source_read_len(source_read_len),
    .source_fifo_empty(1'b1), .source_fifo_valid(1'b0), .source_read_en(),
    .source_read_data(32'd0), .video_de(1'b0), .video_x(video_x), .video_y(video_y),
    .pixel565(), .frame_ready(), .source_frame_done(), .underflow()
);

task check_map;
    input [10:0] x;
    input [9:0] y;
    input [10:0] want_x;
    input [9:0] want_y;
    begin
        video_x=x; video_y=y; #1;
        if (source_x !== want_x || source_y !== want_y) begin
            $display("FAIL zoom map x=%0d y=%0d got=%0d,%0d expected=%0d,%0d",
                     x,y,source_x,source_y,want_x,want_y);
            $finish;
        end
    end
endtask

initial begin
    // Compare the shortened read-end expression with the previous truncated
    // arithmetic over every encoded signed pan, including out-of-range values.
    for(zoom_case=0;zoom_case<2;zoom_case=zoom_case+1)
      for(pan_case=-32768;pan_case<32768;pan_case=pan_case+1) begin
        zoom_2x=zoom_case;pan_y=pan_case;#1;
        old_first_row=zoom_case ? 135+pan_case : pan_case<0 ? 0 : pan_case;
        old_row_count=zoom_case ? 270 : 540-(pan_case<0 ? -pan_case : pan_case);
        old_last_row=old_first_row+old_row_count-1;
        if(dut.last_row!==old_last_row || dut.row_count!==old_row_count)
            $fatal(1,"read extent changed zoom=%d pan=%d",zoom_case,pan_case);
      end
    zoom_2x=0;pan_y=0;
    repeat(3) @(posedge clk); rst_n=1;
    @(negedge clk); zoom_2x=1; source_start=1;
    @(posedge clk); #1; source_start=0;
    if (source_read_base_addr !== 21'd65800 || source_read_len !== 21'd129600) begin
        $display("FAIL zoom read range base=%0d len=%0d",source_read_base_addr,source_read_len);
        $finish;
    end
    check_map(0,0,240,135);
    check_map(640,360,480,270);
    check_map(1279,719,719,404);
    @(negedge clk); pan_x=16'sd32; pan_y=-16'sd16; source_start=1;
    @(posedge clk); #1; source_start=0;
    if (source_read_base_addr !== 21'd58120 || source_read_len !== 21'd129600)
        $fatal(1,"pan read range");
    check_map(0,0,272,119);
    check_map(1279,719,751,388);
    @(negedge clk); zoom_2x=0; pan_x=0; pan_y=0; source_start=1;
    @(posedge clk); #1; source_start=0;
    if (source_read_base_addr !== 21'd1000 || source_read_len !== 21'd259200) begin
        $display("FAIL normal read range base=%0d len=%0d",source_read_base_addr,source_read_len);
        $finish;
    end
    check_map(0,0,0,0);
    check_map(1279,719,959,539);
    museum_active=1; museum_closing=1; museum_origin=3;
    museum_progress=0;
    @(posedge clk); #1;
    check_map(768,0,576,0);
    check_map(1023,0,767,0);
    museum_progress=64;
    @(posedge clk); #1;
    check_map(512,0,576,0);
    check_map(767,0,767,0);
    check_map(0,0,0,0);
    museum_closing=0; museum_progress=128;
    @(posedge clk); #1;
    check_map(768,0,576,0);
    // Exhaust the full input domain, including inactive/clamped progress.
    for (direction=0; direction<2; direction=direction+1)
      for (origin=0; origin<8; origin=origin+1)
        for (progress=0; progress<256; progress=progress+1) begin
          @(negedge clk);
          museum_closing=direction; museum_origin=origin;
          museum_progress=progress;
          step=(direction ? progress : 128-progress) & 127;
          if(step>64) step=64;
          case(origin)
            0:begin expected_left=8*step; expected_offset=-6*step; end
            1:begin expected_left=256+4*step; expected_offset=-3*step; end
            2:begin expected_left=512; expected_offset=0; end
            3:begin expected_left=768-4*step; expected_offset=3*step; end
            default:begin expected_left=1024-8*step; expected_offset=6*step; end
          endcase
          @(posedge clk); #1;
          if(dut.museum_panel_left!==expected_left[10:0] ||
             dut.museum_source_offset!==expected_offset[11:0])
            $fatal(1,"geometry mismatch dir=%d origin=%d progress=%d",
                   direction,origin,progress);
          for(column=expected_left-1;column<=expected_left+256;column=column+1) begin
            video_x=column; #1;
            expected_column=video_x*3/4;
            if(video_x>=expected_left && video_x<expected_left+256)
                expected_column=expected_column+expected_offset;
            if(source_x!==expected_column[10:0])
                $fatal(1,"recenter X mismatch dir=%d origin=%d progress=%d x=%d",
                       direction,origin,progress,video_x);
          end
        end
    museum_active=0;
    // All encoded columns and every legal horizontal pan position. Capture
    // the origin once; per-pixel results must match the previous expression.
    for (zoom_case=0; zoom_case<2; zoom_case=zoom_case+1)
      for (pan_case=-(zoom_case ? 240 : 480);
           pan_case<=(zoom_case ? 240 : 480); pan_case=pan_case+1) begin
        @(negedge clk); zoom_2x=zoom_case; pan_x=pan_case; source_start=1;
        @(posedge clk); #1; source_start=0;
        for (column=0; column<2048; column=column+1) begin
          video_x=column; #1;
          expected_column=pan_case+(zoom_case ? 240+column*3/8 : column*3/4);
          if (source_x!==expected_column[10:0])
            $fatal(1,"X origin mismatch zoom=%d pan=%d x=%d",zoom_case,pan_case,column);
        end
      end
    // All encoded Y origins and raster rows, not just valid visible pans.
    pan_x=0;video_x=0;
    for (zoom_case=0; zoom_case<2; zoom_case=zoom_case+1)
      for (pan_case=-512; pan_case<512; pan_case=pan_case+1) begin
        @(negedge clk);zoom_2x=zoom_case;pan_y=pan_case;source_start=1;
        @(posedge clk);#1;source_start=0;
        // Controls may change during a frame; only source_start captures them.
        @(negedge clk);zoom_2x=!zoom_case;pan_y=~pan_case;
        for(row=0;row<1024;row=row+1) begin
          video_y=row;#1;
          expected_row=(zoom_case ? ((135+pan_case)&1023)+row*3/8 :
                                    pan_case+row*3/4)&2047;
          expected_source_row=(expected_row&1024) ? 0 : expected_row&1023;
          if(dut.mapped_y!==expected_row[10:0] || source_y!==expected_source_row[9:0] ||
             dut.in_picture!==((expected_row&1024)==0 && expected_row<540))
            $fatal(1,"Y mapping mismatch zoom=%d pan=%d y=%d",zoom_case,pan_case,row);
        end
      end
    $display("PASS linebuf 1x/2x, all legal X pan/columns, 4096 recenter geometries, 2097152 Y mappings");
    test_pass=1;
    $finish;
end
endmodule

`default_nettype wire
