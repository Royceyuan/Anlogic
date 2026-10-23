`timescale 1ns/1ps
module tb_offline_sd_arbiter;
reg clk=0,rst_n=0;always #5 clk=~clk;
reg video_start=0,subtitle_start=0,card_busy=0,card_done=0,card_valid=0;
reg [31:0] video_lba=10,video_blocks=8,subtitle_lba=90;
reg [7:0] card_data=0,card_error=0;
wire video_valid,video_done,subtitle_valid,subtitle_done,card_start,busy;
wire [7:0] client_data;
wire [31:0] card_lba,card_blocks;
integer starts=0;
offline_sd_arbiter dut(.*);
always @(negedge clk)if(card_start)starts=starts+1;
task request_video;
begin @(negedge clk);video_start=1;@(negedge clk);video_start=0;end endtask
task wait_start;
input [31:0] lba,blocks;
begin
    wait(card_start);#1;
    if(card_lba!==lba||card_blocks!==blocks)$fatal(1,"Wrong grant %d %d",card_lba,card_blocks);
    @(negedge clk);card_busy=1;
end endtask
task byte_check;
input expected_owner;
begin
    @(negedge clk);card_valid=1;card_data=8'ha5;#1;
    if({subtitle_valid,video_valid}!==(expected_owner?2'b10:2'b01)||client_data!==8'ha5)
        $fatal(1,"Interleaved data");
    @(negedge clk);card_valid=0;
end endtask
task finish;
input expected_owner;
begin
    @(negedge clk);card_done=1;#1;
    if({subtitle_done,video_done}!==(expected_owner?2'b10:2'b01))$fatal(1,"Wrong completion");
    @(negedge clk);card_done=0;card_busy=0;
end endtask
initial begin
    repeat(4)@(negedge clk);rst_n=1;
    request_video;wait_start(10,8);
    @(negedge clk);subtitle_start=1;
    repeat(5)byte_check(0);
    if(starts!=1)$fatal(1,"Multi-block preempted");
    finish(0);wait_start(90,1);byte_check(1);finish(1);
    repeat(10)@(negedge clk);
    if(starts!=2||busy)$fatal(1,"Held subtitle level caused duplicate requests");
    subtitle_start=0;@(negedge clk);
    video_lba=20;subtitle_lba=100;video_start=1;subtitle_start=1;
    @(negedge clk);video_start=0;
    wait_start(20,8);byte_check(0);finish(0);
    wait_start(100,1);
    @(negedge clk);card_error=8'h91;card_done=1;card_valid=1;#1;
    if(subtitle_done||subtitle_valid||video_done||video_valid)$fatal(1,"CRC error published");
    @(negedge clk);card_done=0;card_busy=0;card_valid=0;
    repeat(5)@(negedge clk);
    if(starts!=4)$fatal(1,"Error launched another read");
    $display("PASS SD arbitration: uninterrupted blocks, bounded subtitle grant, level dedup, CRC suppression");$finish;
end
initial begin #30000;$fatal(1,"SD arbitration timeout");end
endmodule
