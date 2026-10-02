`timescale 1ns/1ps
module tb_viewport_request_equivalence;
reg clk=0,rst_n=0,test_pass=0;
reg [8:0] control=0;
reg [3:0] media=0;
reg frame=0;
reg [15:0] width_bcd=0,height_bcd=0;
reg signed [8:0] x=0,y=0;
wire [74:0] actual,expected;
integer n,pattern,checks=0;
always #5 clk=~clk;
`define INPUTS .clk(clk),.rst_n(rst_n),.ENABLE_MULTI_FRAME_PRELOAD(control[8]), \
 .ENABLE_MAIN5_REMOTE(control[7]),.video_run(control[6]), \
 .overview_enable_video(control[5]),.transition_active(control[4]), \
 .detail_zoom_2x_ff2(control[3]),.display_zoom_2x(control[2]), \
 .switch_pending(control[1]),.main5_pan_changed(control[0]), \
 .display_media_index(media),.display_frame_index(frame), \
 .display_source_width_bcd(width_bcd),.display_source_height_bcd(height_bcd), \
 .main5_pan_x_video(x),.main5_pan_y_video(y)
viewport_request_dut dut(`INPUTS,.result(actual));
viewport_request_ref reference(`INPUTS,.result(expected));
`undef INPUTS
always @(negedge clk) begin
 if(actual!==expected) $fatal(1,"viewport request mismatch control=%b actual=%h expected=%h",control,actual,expected);
 checks=checks+1;
end
initial begin
 repeat(3) @(negedge clk); #1 rst_n=1;
 // All request guard combinations and signed offsets, including -256/255.
 for(pattern=0;pattern<512;pattern=pattern+1)
   for(n=0;n<512;n=n+1) begin
     @(negedge clk); #1;control=pattern;x=n;y=511-n;
     media=$random;frame=$random;width_bcd=$random;height_bcd=$random;
   end
 // Back-to-back priority changes, held/no-op requests and repeated reset.
 for(n=0;n<50000;n=n+1) begin
   @(negedge clk); #1;
   control=$random;x=$random;y=$random;media=$random;frame=$random;
   width_bcd=$random;height_bcd=$random;
   if(n%101==0) begin #1 rst_n=0;#1 rst_n=1;end
 end
 repeat(4) @(negedge clk);
 test_pass=1;
 $display("PASS viewport request equivalence: %d cycles; 512 guards x 512 offsets plus random/reset",checks);
 $finish;
end
initial begin #4000000;$fatal(1,"viewport request watchdog");end
endmodule
