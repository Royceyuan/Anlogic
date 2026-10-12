`timescale 1ns / 1ps
module tb_secondary_hdmi_frame_handoff;
reg clk=0,rst_n=0,request_pc=0,local_ready=1,pc_ready=1;
always #6.666667 clk=!clk;
reg [10:0] x=0;
reg [9:0] y=0;
always @(posedge clk) begin
    if(!rst_n) begin x<=0;y<=0;end
    else if(x==1649) begin x<=0;y<=y==749?0:y+1'b1;end
    else x<=x+1'b1;
end
reg aligned_fixture=0,block_control=0;
wire local_frame_tick=x==0&&y==720;
wire pc_frame_tick=aligned_fixture?local_frame_tick:x==100&&y==720;
wire local_vblank=y>=720,pc_vblank=y>=720;
wire local_control=!block_control,pc_control=!block_control;
wire phase_aligned,external_selected,pc_payload_allowed;
secondary_hdmi_frame_handoff dut(.*);
reg test_pass=0;
reg committed_in_blank=0;
always @(posedge clk) committed_in_blank=local_vblank&&pc_vblank&&local_control&&pc_control;
always @(external_selected) if(rst_n && external_selected && !committed_in_blank)
    $fatal(1,"grant switched during active video/preamble/island");
always @(pc_payload_allowed) if(pc_payload_allowed &&
    (!request_pc || !pc_ready || !local_ready || !phase_aligned))
    $fatal(1,"PC payload escaped authorization/alignment guard");
real requested_at,selected_at;
task request_at;
input integer tx,ty;
begin
    wait(x==tx && y==ty);@(negedge clk);
    requested_at=$realtime;request_pc=1;
    wait(pc_payload_allowed);selected_at=$realtime;
    if(selected_at-requested_at>1650*750*13.333334+40)
        $fatal(1,"aligned handoff exceeded one frame");
    $display("MEASURE aligned_request_to_grant_ms=%0.6f (native picture may remain visible; not blackout)",(selected_at-requested_at)/1000000.0);
end endtask
initial begin
    #100;rst_n=1;request_pc=1;
    wait(y==721);#100;
    if(phase_aligned || external_selected || pc_payload_allowed)
        $fatal(1,"independent frame phase was treated as genlocked");
    $display("PASS misaligned frame starts refuse PC; common clock alone is insufficient");
    // The test fixture now supplies coincident raster markers. This does NOT
    // implement the missing native-renderer genlock in the real top level.
    aligned_fixture=1;request_pc=0;
    wait(y==719 && x==1640);block_control=1;request_pc=1;
    wait(y==720 && x==20);#1;
    if(!phase_aligned || external_selected)
        $fatal(1,"grant did not wait for ordinary control after frame alignment");
    @(negedge clk);block_control=0;
    wait(pc_payload_allowed);
    $display("PASS aligned vertical-blank handoff waits out a packet/preamble interval");
    wait(y==10);@(negedge clk);request_pc=0;
    #0.001;if(pc_payload_allowed) $fatal(1,"STOP extended PC lease to frame boundary");
    wait(!external_selected);
    $display("PASS immediate payload inhibit and later vertical-blank bookkeeping");
    request_at(100,1);
    @(negedge clk);request_pc=0;wait(!external_selected);
    request_at(100,719);
    @(negedge clk);pc_ready=0;
    #0.001;if(pc_payload_allowed) $fatal(1,"source loss still admits PC payload");
    repeat(2) @(posedge clk);#1;
    if(phase_aligned) $fatal(1,"source loss retained stale alignment");
    request_pc=0;pc_ready=1;
    repeat(20) @(posedge clk);
    if(pc_payload_allowed) $fatal(1,"reconnect reused a stale lease");
    $display("PASS input loss invalidates phase and cannot reuse revoked lease");
    rst_n=0;#1;
    if(pc_payload_allowed || external_selected || phase_aligned) $fatal(1,"reset failed");
    $display("PASS reset immediately clears handoff and payload permission");
    test_pass=1;$finish;
end
initial begin #150000000;$fatal(1,"frame handoff timeout");end
endmodule
