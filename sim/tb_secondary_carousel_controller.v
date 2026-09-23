`timescale 1ns / 1ps
`default_nettype none

module tb_secondary_carousel_controller;
reg clk = 1'b0;
reg rst_n = 1'b0;
reg [4:0] frame_valid = 5'd0;
reg local_emergency = 1'b0;
reg cmd_valid = 1'b0;
reg [7:0] cmd_type = 8'd0;
reg [7:0] cmd_artifact_id = 8'hff;
reg [15:0] cmd_emergency_id = 16'd0;
reg [7:0] cmd_route_id = 8'd0;
reg cmd_emergency_active = 1'b0;
wire [2:0] page_index;
wire emergency_active;
wire [1:0] link_state;
wire [2:0] master_artifact;
wire [7:0] active_route_id;
wire [2:0] cmd_result;

always #5 clk = ~clk;
secondary_carousel_controller #(.PAGE_CYCLES(8), .LINK_TIMEOUT_CYCLES(6)) dut (
    .clk(clk), .rst_n(rst_n), .frame_valid(frame_valid),
    .local_emergency(local_emergency), .cmd_valid(cmd_valid),
    .cmd_type(cmd_type), .cmd_artifact_id(cmd_artifact_id),
    .cmd_emergency_id(cmd_emergency_id), .cmd_route_id(cmd_route_id),
    .cmd_emergency_active(cmd_emergency_active),
    .page_index(page_index), .emergency_active(emergency_active),
    .link_state(link_state), .master_artifact(master_artifact),
    .active_route_id(active_route_id), .cmd_result(cmd_result)
);

task step;
    input integer count;
    integer i;
    begin
        for (i=0; i<count; i=i+1) begin @(posedge clk); #1; end
    end
endtask

task check;
    input condition;
    input [255:0] reason;
    begin
        if (!condition) begin $display("FAIL: %0s", reason); $fatal(1); end
    end
endtask

task send_cmd;
    input [7:0] kind;
    input [7:0] artifact;
    input [15:0] event_id;
    input active;
    input [2:0] expected_result;
    begin
        @(negedge clk);
        cmd_valid = 1'b1;
        cmd_type = kind;
        cmd_artifact_id = artifact;
        cmd_emergency_id = event_id;
        cmd_route_id = 8'd0;
        cmd_emergency_active = active;
        #1;
        check(cmd_result == expected_result, "command result");
        step(1);
        @(negedge clk);
        cmd_valid = 1'b0;
    end
endtask

integer i;
initial begin
    step(2);
    @(negedge clk); rst_n = 1'b1;
    frame_valid = 5'b01111;
    step(24);
    check(page_index == 0, "no carousel before five valid images");
    check(link_state == 2, "heartbeat timeout");

    @(negedge clk); frame_valid = 5'b11111;
    step(8);
    check(page_index == 1, "five-second tick");
    send_cmd(8'h10, 8'd3, 16'd0, 1'b0, 3'd0);
    check(master_artifact == 3, "main artifact status");
    check(page_index == 1, "main selection cannot move local page");
    for (i=2; i<=4; i=i+1) begin
        step(8);
        check(page_index == i, "ordered carousel");
    end
    step(8);
    check(page_index == 0, "carousel wrap");

    send_cmd(8'h20, 8'hff, 16'd42, 1'b1, 3'd0);
    step(2);
    check(emergency_active && page_index == 0, "remote emergency priority");
    send_cmd(8'h21, 8'hff, 16'd41, 1'b0, 3'd5);
    check(emergency_active, "old event cannot clear emergency");
    step(9);
    check(link_state == 2 && emergency_active, "link loss retains emergency");
    send_cmd(8'h02, 8'd4, 16'd42, 1'b1, 3'd0);
    check(link_state == 1 && emergency_active, "heartbeat resynchronizes link");
    send_cmd(8'h21, 8'hff, 16'd42, 1'b0, 3'd0);
    step(1);
    check(!emergency_active && page_index == 0, "matching clear restarts page zero");

    @(negedge clk); local_emergency = 1'b1;
    step(4);
    check(emergency_active && page_index == 0, "local emergency switch");
    @(negedge clk); local_emergency = 1'b0;
    step(4);
    check(!emergency_active && page_index == 0, "local clear restarts page zero");
    send_cmd(8'h10, 8'd9, 16'd0, 1'b0, 3'd5);
    check(master_artifact == 4, "invalid artifact ignored");
    $display("PASS: SECONDARY local carousel, command isolation, emergency ID and link timeout");
    $finish;
end
endmodule

`default_nettype wire
