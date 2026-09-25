`timescale 1ns / 1ps
`default_nettype none

module tb_secondary_stream_carousel;
reg clk = 0, rst_n = 0, page_ready = 0, local_emergency = 0;
reg [2:0] displayed_artifact = 0;
reg cmd_valid = 0, cmd_confirmed = 0;
reg [7:0] cmd_type = 0, cmd_artifact_id = 0, cmd_lecture_phase = 0;
wire [2:0] page_index;
wire [2:0] master_artifact;
wire info_active;
always #5 clk = ~clk;

secondary_carousel_controller #(.PAGE_CYCLES(4), .STREAMING(1)) dut (
    .clk(clk), .rst_n(rst_n), .frame_valid(5'b00000),
    .page_ready(page_ready), .displayed_artifact(displayed_artifact),
    .local_emergency(local_emergency),
    .cmd_valid(cmd_valid), .cmd_type(cmd_type),
    .cmd_artifact_id(cmd_artifact_id), .cmd_confirmed(cmd_confirmed),
    .cmd_mode(8'd1), .cmd_lecture_phase(cmd_lecture_phase),
    .cmd_lecture_reason(8'd0), .cmd_emergency_id(16'd0),
    .cmd_route_id(8'd0), .cmd_emergency_active(1'b0),
    .page_index(page_index), .resume_page_index(),
    .emergency_active(), .link_state(),
    .master_artifact(master_artifact), .info_active(info_active), .info_artifact(),
    .active_route_id(), .cmd_result()
);

task step(input integer n);
    integer i;
    begin for (i = 0; i < n; i = i + 1) begin @(posedge clk); #1; end end
endtask

initial begin
    step(2); @(negedge clk); rst_n = 1;
    step(10);
    if (page_index != 0) $fatal(1, "unloaded first page advanced");
    @(negedge clk); page_ready = 1;
    step(4);
    if (page_index != 1) $fatal(1, "ready page did not advance");
    @(negedge clk); page_ready = 0;
    step(10);
    if (page_index != 1) $fatal(1, "missing page was skipped");
    @(negedge clk); page_ready = 1;
    step(4);
    if (page_index != 2) $fatal(1, "carousel did not resume");
    @(negedge clk); local_emergency = 1;
    step(4);
    if (page_index != 2) $fatal(1, "emergency reset the carousel page");
    @(negedge clk); local_emergency = 0;
    step(1);
    if (page_index != 2) $fatal(1, "carousel did not resume after emergency");
    displayed_artifact = 1;
    @(negedge clk);
    cmd_valid = 1; cmd_type = 8'h10; cmd_artifact_id = 8'd4; cmd_confirmed = 1;
    step(1);
    @(negedge clk); cmd_valid = 0;
    step(6);
    if (!info_active || page_index != 4) $fatal(1, "confirmed page did not hold");
    @(negedge clk); cmd_valid = 1; cmd_confirmed = 0; cmd_artifact_id = 8'd3;
    step(1);
    @(negedge clk); cmd_valid = 0;
    step(1);
    if (master_artifact != 3 || !info_active || page_index != 4)
        $fatal(1, "new preload selection interrupted the active introduction");
    @(negedge clk); local_emergency = 1;
    step(4);
    if (!info_active || page_index != 4) $fatal(1, "emergency lost the lecture page");
    @(negedge clk); local_emergency = 0;
    step(4);
    if (!info_active || page_index != 4) $fatal(1, "emergency return lost the lecture page");
    @(negedge clk); cmd_valid = 1; cmd_type = 8'h11; cmd_lecture_phase = 8'hff;
    step(1);
    @(negedge clk); cmd_valid = 0;
    step(1);
    if (info_active || page_index != 1)
        $fatal(1, "KEY3 did not return to the displayed carousel artifact");
    $display("PASS: streaming carousel waits for cached pages and holds information page");
    $finish;
end
endmodule

`default_nettype wire
