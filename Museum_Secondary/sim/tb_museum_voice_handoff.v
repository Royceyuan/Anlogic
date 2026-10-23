`timescale 1ns/1ps
module tb_museum_voice_handoff;
reg clk=0,rst_n=0,request=0,need_handoff=1,abort=0,muted_pulse=0;
wire pending,confirm;
integer confirmations=0,i;
always #5 clk=~clk;
museum_voice_handoff #(.CLOCK_HZ(1000),.TIMEOUT_MS(20)) dut(.*);
always @(negedge clk)if(confirm)confirmations=confirmations+1;
task enter;
begin @(negedge clk);request=1;@(negedge clk);request=0;#1;end endtask
initial begin
    repeat(3)@(negedge clk);rst_n=1;
    enter();if(!pending||confirm)$fatal(1,"Entry did not wait for mute");
    repeat(4)@(negedge clk);muted_pulse=1;@(negedge clk);muted_pulse=0;
    repeat(3)@(negedge clk);if(pending||confirmations!=1)$fatal(1,"Applied mute did not release entry once");
    enter();repeat(25)@(negedge clk);
    if(pending||confirmations!=2)$fatal(1,"Bounded fallback failed");
    enter();abort=1;repeat(3)@(negedge clk);abort=0;muted_pulse=1;
    repeat(3)@(negedge clk);muted_pulse=0;
    if(confirmations!=2)$fatal(1,"Cancelled intent released on late ACK");
    need_handoff=0;enter();repeat(3)@(negedge clk);
    if(confirmations!=3)$fatal(1,"Manual/legacy entry blocked");
    $display("PASS voice handoff: mute before entry, timeout fallback, abort, late ACK, manual/legacy");$finish;
end
endmodule
