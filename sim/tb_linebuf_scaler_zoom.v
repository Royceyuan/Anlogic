`timescale 1ns / 1ps
`default_nettype none

module tb_linebuf_scaler_zoom;
reg clk=0, rst_n=0, source_start=0, zoom_2x=0;
reg [10:0] video_x=0;
reg [9:0] video_y=0;
wire [20:0] source_read_base_addr, source_read_len;
wire [10:0] source_x = dut.source_x;
wire [9:0] source_y = dut.source_y;

always #5 clk=~clk;

linebuf_scaler_960x540_to_1280x720 dut (
    .clk(clk), .rst_n(rst_n), .source_start(source_start), .zoom_2x(zoom_2x),
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
    @(negedge clk); zoom_2x=0; source_start=1;
    @(posedge clk); #1; source_start=0;
    if (source_read_base_addr !== 21'd1000 || source_read_len !== 21'd259200) begin
        $display("FAIL normal read range base=%0d len=%0d",source_read_base_addr,source_read_len);
        $finish;
    end
    check_map(0,0,0,0);
    check_map(1279,719,959,539);
    $display("PASS linebuf fixed-center 1x/2x mapping");
    $finish;
end
endmodule

`default_nettype wire
