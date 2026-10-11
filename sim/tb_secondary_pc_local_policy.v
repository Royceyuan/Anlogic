`timescale 1ns/1ps
module tb_secondary_pc_local_policy;
reg armed=0;
reg [7:0] state=1,kind=2,mode=1;
wire hold;
wire [7:0] shown;
secondary_pc_local_policy #(.ENABLE(1)) dut(.armed(armed),.main_state(state),.cmd_type(kind),.cmd_mode(mode),.hold_carousel(hold),.display_mode(shown));
wire old_hold;
reg [7:0] hb_mode=3,hb_emergency=1,hb_error=0;
reg hb_busy=1;
wire recovery;
secondary_pc_recovery_decode recovery_decode(.mode(hb_mode),.emergency(hb_emergency),
    .error(hb_error),.app_busy(hb_busy),.recovery(recovery));
wire [7:0] old_shown;
secondary_pc_local_policy legacy(.armed(armed),.main_state(state),.cmd_type(kind),.cmd_mode(mode),.hold_carousel(old_hold),.display_mode(old_shown));
reg clk=0,rst_n=0,valid=0,test_pass=0;
always #5 clk=~clk;
wire info;
wire [2:0] page;
secondary_carousel_controller #(.PAGE_CYCLES(12),.STREAMING(1)) carousel(
    .clk(clk),.rst_n(rst_n),.frame_valid(5'b11111),.page_ready(1'b1),.displayed_artifact(3'd0),
    .local_emergency(1'b0),.manual_mode(hold),.manual_next(1'b0),.cmd_valid(valid),.cmd_type(kind),
    .cmd_artifact_id(8'd2),.cmd_confirmed(1'b0),.cmd_mode(shown),.cmd_lecture_phase(8'd0),
    .cmd_lecture_reason(8'd0),.cmd_emergency_id(16'd0),.cmd_route_id(8'd0),.cmd_emergency_active(1'b0),
    .page_index(page),.info_active(info),.resume_page_index(),.emergency_active(),.link_state(),
    .master_artifact(),.preload_artifact(),.info_artifact(),.active_route_id(),.cmd_result());
initial begin
    #1;if(recovery) $fatal(1,"real MAIN-4 emergency/busy heartbeat blocked emergency video");
    hb_error=3;#1;if(!recovery) $fatal(1,"genuine media error suppressed by emergency");
    hb_error=0;hb_mode=1;hb_emergency=0;#1;if(!recovery) $fatal(1,"post-emergency/KEY4 recovery not blocked");
    hb_busy=0;#1;if(recovery) $fatal(1,"normal overview marked recovering");
    hb_mode=0;#1;if(!recovery) $fatal(1,"startup not blocked");
    hb_mode=4;hb_emergency=1;#1;if(!recovery) $fatal(1,"fault mode bypassed recovery");
    hb_mode=3;hb_error=0;hb_busy=1;#1;if(recovery) $fatal(1,"valid emergency did not recover eligibility");
    $display("PASS actual MAIN-4 emergency busy semantics; real fault/startup/exit recovery blocked");
    #1;armed=1;#1;if(hold||shown!=1) $fatal(1,"overview carousel frozen by prewarm");
    mode=2;#1;if(shown!=1) $fatal(1,"first heartbeat raced exported state and loaded intro");
    state=3;#1;if(!hold||shown!=1) $fatal(1,"intro flash or cache replacement before PC video");
    if(old_hold||old_shown!=2) $fatal(1,"legacy entry changed");
    state=7;#1;if(!hold||shown!=1) $fatal(1,"pause discarded return cache");
    state=8'h23;#1;if(!hold||shown!=1) $fatal(1,"transition discarded return cache");
    state=8'h0b;#1;if(hold||shown!=2) $fatal(1,"emergency suppressed by warm hint");
    state=8'h43;#1;if(hold) $fatal(1,"recovery blocked");
    state=2;#1;if(hold) $fatal(1,"stale main state covered local UI");
    state=3;armed=0;#1;if(hold||shown!=2) $fatal(1,"fallback intro not restored");
    armed=1;state=1;mode=1;#1;if(hold||shown!=1) $fatal(1,"return started intro load");
    @(negedge clk);rst_n=1;state=1;mode=2;valid=1;
    @(negedge clk);valid=0;state=3;
    repeat(30) @(negedge clk);
    if(info||page!=0) $fatal(1,"actual carousel loaded intro or advanced while video covered it");
    state=1;mode=1;valid=1;@(negedge clk);valid=0;
    repeat(13) @(negedge clk);
    if(info||page!=1) $fatal(1,"return did not resume cached carousel");
    test_pass=1;
    $display("PASS local return cache retained; no intro flash; overview, fallback and emergency unchanged");$finish;
end
initial begin #10000;$fatal(1,"policy test timeout");end
endmodule
