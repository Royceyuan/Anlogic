`timescale 1ns/1ps
module tb_secondary_offline_main_timeline;
reg clk=0,rst=1,peer_alive=1,heartbeat_pulse=0,manual_mode=0;
reg [127:0] heartbeat_data=0;
wire [31:0] position;
always #5 clk=~clk;
secondary_offline_main_timeline #(.CLOCK_HZ(100),.SAMPLE_HZ(10)) dut(.*);
task anchor;
input [31:0] sample;
input [1:0] speed;
input [7:0] play_state;
begin
    @(negedge clk);heartbeat_data[127:120]=2;heartbeat_data[103:96]=play_state;
    heartbeat_data[63:32]=sample;heartbeat_data[18:17]=speed;heartbeat_pulse=1;
    @(negedge clk);heartbeat_pulse=0;
end endtask
initial begin
    repeat(3)@(negedge clk);rst=0;
    anchor(100,0,1);repeat(100)@(negedge clk);
    if(position!=110)$fatal(1,"1x extrapolation");
    anchor(200,1,1);repeat(100)@(negedge clk);
    if(position!=220)$fatal(1,"2x extrapolation");
    anchor(300,2,3);repeat(100)@(negedge clk);
    if(position!=330)$fatal(1,"3x automatic transition");
    anchor(400,2,2);repeat(100)@(negedge clk);
    if(position!=400)$fatal(1,"Paused timeline advanced");
    manual_mode=1;anchor(500,2,3);repeat(100)@(negedge clk);
    if(position!=500)$fatal(1,"Manual transition advanced");
    manual_mode=0;anchor(600,0,1);peer_alive=0;repeat(100)@(negedge clk);
    if(position!=600)$fatal(1,"Lost peer timeline advanced");
    peer_alive=1;anchor(10,0,1);repeat(10)@(negedge clk);
    if(position!=11)$fatal(1,"New anchor/restart failed");
    $display("PASS main subtitle sample timeline: 1x/2x/3x, pause, manual, loss, restart");$finish;
end
endmodule
