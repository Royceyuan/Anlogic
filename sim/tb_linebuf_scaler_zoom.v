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
    @(negedge clk); zoom_2x=0; source_start=1;
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
        end
    $display("PASS linebuf 1x/2x, pan and all 4096 recenter geometries");
    test_pass=1;
    $finish;
end
endmodule

`default_nettype wire
