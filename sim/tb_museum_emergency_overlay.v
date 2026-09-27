`timescale 1ns / 1ps
`default_nettype none
module tb_museum_emergency_overlay;
reg clk=0,rst_n=0,emergency=0,frame_tick=0,de=1;
reg [10:0] x=0;
reg [9:0] y=0;
reg [23:0] rgb=24'h123456;
wire [23:0] out;
wire alarm_valid;
wire signed [15:0] alarm_left,alarm_right;
integer valid_count=0;
integer changed_count=0;
integer positive_count=0;
integer negative_count=0;
integer px,py,dx,dy,arrow_dx,arrow_dy;
reg old_triangle,old_inner,old_arrow;
reg signed [15:0] previous_sample=0;
always #1 clk=~clk;

museum_emergency_overlay dut_overlay(
 .clk(clk),.rst_n(rst_n),.emergency(emergency),.frame_tick(frame_tick),
 .hs_i(1'b1),.vs_i(1'b1),.de_i(de),.x_i(x),.y_i(y),.rgb_i(rgb),
 .hs_o(),.vs_o(),.de_o(),.x_o(),.y_o(),.rgb_o(out));
emergency_alarm_48k #(.CLK_HZ(480_000)) dut_alarm(
 .clk(clk),.rst_n(rst_n),.enable(emergency),.sample_valid(alarm_valid),
 .sample_left(alarm_left),.sample_right(alarm_right));

always @(posedge clk) if(alarm_valid) begin
 valid_count=valid_count+1;
 if(alarm_left!==alarm_right || alarm_left > 16'sd8191 || alarm_left < -16'sd8191)
  $fatal(1,"invalid emergency PCM %h/%h",alarm_left,alarm_right);
 if(valid_count>1 && alarm_left!=previous_sample) changed_count=changed_count+1;
 if(alarm_left>0) positive_count=positive_count+1;
 if(alarm_left<0) negative_count=negative_count+1;
 previous_sample=alarm_left;
end

task check_pixel;
 input [10:0] px; input [9:0] py; input [23:0] expected;
 begin x=px;y=py;#1;if(out!==expected)$fatal(1,"pixel %0d,%0d=%h expected=%h",px,py,out,expected);end
endtask

initial begin
 #4;rst_n=1;#2;
 check_pixel(11'd500,10'd200,24'h123456);
 emergency=1;#2;
 check_pixel(11'd0,10'd300,24'hffffff);
 check_pixel(11'd100,10'd20,24'hffd000);
 check_pixel(11'd330,10'd140,24'hffd000);
 check_pixel(11'd330,10'd250,24'hffd000);
 check_pixel(11'd600,10'd360,24'hffffff);
 repeat(2000) @(posedge clk);
 if(valid_count<150)$fatal(1,"alarm sample rate too low count=%0d",valid_count);
 if(changed_count<100 || positive_count==0 || negative_count==0)
  $fatal(1,"alarm PCM did not vary with tone changed=%0d pos=%0d neg=%0d",
         changed_count,positive_count,negative_count);
 emergency=0;#2;
 check_pixel(11'd600,10'd360,24'h123456);
 repeat(20) @(posedge clk);
 if(alarm_valid || alarm_left!==0 || alarm_right!==0)
  $fatal(1,"alarm did not stop cleanly");
 // Exhaustive equivalence over all coordinate input bits, not just HDMI DE.
 for(py=0;py<1024;py=py+1) begin
  for(px=0;px<2048;px=px+1) begin
   x=px; y=py;
   dx=px>=330 ? px-330 : 330-px;
   dy=py>=140 ? py-140 : 0;
   arrow_dx=(1120-px)&1023;
   arrow_dy=py>=360 ? py-360 : 360-py;
   old_triangle=py>=140 && py<=430 && dx<=dy;
   old_inner=py>=176 && py<402 && dx+28<dy;
   old_arrow=px>=850 && px<=1120 && arrow_dy<=arrow_dx;
   #1;
   if(dut_overlay.triangle_hit!==old_triangle ||
      dut_overlay.triangle_inner!==old_inner || dut_overlay.arrow_head!==old_arrow)
    $fatal(1,"emergency geometry differs at %0d,%0d",px,py);
  end
 end
 $display("PASS emergency overlay priority, exclusive 48 kHz alarm and 2097152-coordinate equivalence");
 $finish;
end
endmodule
`default_nettype wire
